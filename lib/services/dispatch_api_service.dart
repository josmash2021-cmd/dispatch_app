import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// HTTP client for the Cruise FastAPI backend with API-key + HMAC signing.
/// Used by the dispatch admin panel to sync operations with the backend.
class DispatchApiService {
  static const String _defaultTunnelUrl =
      'https://cruiseapp2-production.up.railway.app';

  static const String _serverUrlPrefKey = 'dispatch_server_url';

  static String _activeUrl = _defaultTunnelUrl;
  static String get activeServerUrl => _activeUrl;

  // Simple cache for user details to reduce API calls
  static final Map<String, _CacheEntry> _cache = {};
  static const Duration _cacheDuration = Duration(seconds: 30);

  // ── Connection Status ───────────────────────────────────
  static bool _isOnline = true;
  static bool get isOnline => _isOnline;
  static final StreamController<bool> _onlineController =
      StreamController<bool>.broadcast();
  static Stream<bool> get onlineStream => _onlineController.stream;

  static void _setOnline(bool value) {
    if (_isOnline != value) {
      _isOnline = value;
      _onlineController.add(value);
      debugPrint('[DispatchApi] backend ${value ? "ONLINE" : "OFFLINE"}}');
    }
  }

  static const String _apiKey =
      'HWB88VurhLM-1GdVML2PT92iqNSbeJ52TU1VO37MBZS6RYlyWvfIpaTdD54GT_5u';
  static const String _hmacSecret =
      'qUDmTNu1Dxxg_xo7kaUfRba4XiU_5H1ZhkUMDuVrD2dLQ2ImT8JXZ5FgUyXpSJ5h';

  /// Load persisted server URL. Call once before runApp().
  static Future<void> init() async {
    _activeUrl = _defaultTunnelUrl;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_serverUrlPrefKey, _activeUrl);
    debugPrint('[DispatchApi] active URL: $_activeUrl');
    // Probe Railway in background to confirm connectivity
    probeAndSetBestUrl()
        .then((url) {
          if (url != null) {
            debugPrint('[DispatchApi] probe reachable: $url');
            _setOnline(true);
          } else {
            debugPrint('[DispatchApi] probe: Railway unreachable');
            _setOnline(false);
          }
        })
        .catchError((_) { _setOnline(false); });
  }

  /// Persist a new server URL.
  static Future<void> setServerUrl(String url) async {
    _activeUrl = url.trimRight().replaceAll(RegExp(r'/+$'), '');
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_serverUrlPrefKey, _activeUrl);
    debugPrint('[DispatchApi] server URL updated → $_activeUrl');
  }

  /// Probe Railway to confirm it is reachable.
  static Future<String?> probeAndSetBestUrl({
    Duration timeout = const Duration(seconds: 6),
  }) async {
    try {
      final res = await http
          .get(
            Uri.parse('$_defaultTunnelUrl/health'),
            headers: {'Accept': 'application/json'},
          )
          .timeout(timeout);
      if (res.statusCode == 200) {
        await setServerUrl(_defaultTunnelUrl);
        return _defaultTunnelUrl;
      }
    } catch (_) {}
    return null;
  }

  // ── HMAC Signing ───────────────────────────────────────

  static String _generateNonce() {
    final rng = Random.secure();
    final bytes = List<int>.generate(16, (_) => rng.nextInt(256));
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  static String _computeSignature(String timestamp, String nonce) {
    final key = utf8.encode(_hmacSecret);
    final data = utf8.encode('$_apiKey:$timestamp:$nonce:dispatch');
    final hmacSha256 = Hmac(sha256, key);
    return hmacSha256.convert(data).toString();
  }

  static Map<String, String> _headers() {
    final timestamp = (DateTime.now().millisecondsSinceEpoch ~/ 1000)
        .toString();
    final nonce = _generateNonce();
    final signature = _computeSignature(timestamp, nonce);
    return {
      'Content-Type': 'application/json',
      'X-API-Key': _apiKey,
      'X-Timestamp': timestamp,
      'X-Nonce': nonce,
      'X-Signature': signature,
      'X-Device-FP': 'dispatch-admin-app',
      'X-Client-Version': '1.0.0',
    };
  }

  // ── Retry helper ────────────────────────────────────────

  /// Retries [fn] up to [maxAttempts] times with exponential backoff.
  /// On network errors (not 4xx) it re-probes for a reachable URL first.
  static Future<T> _withRetry<T>(
    Future<T> Function() fn, {
    int maxAttempts = 3,
    Duration baseDelay = const Duration(milliseconds: 600),
  }) async {
    int attempt = 0;
    while (true) {
      attempt++;
      try {
        final result = await fn();
        _setOnline(true);
        return result;
      } on ApiException {
        // 4xx/5xx — don't retry, surface immediately
        _setOnline(true); // server replied, so we ARE online
        rethrow;
      } catch (e) {
        // Network/timeout error
        if (attempt >= maxAttempts) {
          _setOnline(false);
          // Try to find another reachable URL before giving up
          probeAndSetBestUrl().then((url) {
            if (url != null) _setOnline(true);
          }).catchError((_) {});
          rethrow;
        }
        _setOnline(false);
        // Re-probe URL on first failure
        if (attempt == 1) {
          final newUrl = await probeAndSetBestUrl(
            timeout: const Duration(seconds: 4),
          );
          if (newUrl != null) _setOnline(true);
        }
        final delay = baseDelay * (1 << (attempt - 1)); // 600ms, 1.2s, 2.4s
        debugPrint('[DispatchApi] retry $attempt/$maxAttempts after ${delay.inMilliseconds}ms — $e');
        await Future.delayed(delay);
      }
    }
  }

  // ── HTTP helpers ───────────────────────────────────────

  static Future<dynamic> _get(
    String path, {
    Map<String, String>? queryParams,
    Duration timeout = const Duration(seconds: 12),
    bool useCache = false,
  }) async {
    final cacheKey = '$path${queryParams?.toString() ?? ""}';

    if (useCache && _cache.containsKey(cacheKey)) {
      final entry = _cache[cacheKey]!;
      if (entry.isValid) {
        debugPrint('[DispatchApi] Cache hit for $path');
        return entry.data;
      }
      _cache.remove(cacheKey);
    }

    return _withRetry(() async {
      final uri = Uri.parse('$_activeUrl$path')
          .replace(queryParameters: queryParams);
      final res = await http
          .get(uri, headers: _headers())
          .timeout(timeout);
      if (res.statusCode >= 200 && res.statusCode < 300) {
        final data = jsonDecode(res.body);
        if (useCache) _cache[cacheKey] = _CacheEntry(data);
        return data;
      }
      throw ApiException(res.statusCode, _extractDetail(res.body));
    });
  }

  static Future<dynamic> _post(
    String path, {
    Map<String, dynamic>? body,
    Duration timeout = const Duration(seconds: 12),
  }) async {
    return _withRetry(() async {
      final res = await http
          .post(
            Uri.parse('$_activeUrl$path'),
            headers: _headers(),
            body: body != null ? jsonEncode(body) : null,
          )
          .timeout(timeout);
      if (res.statusCode >= 200 && res.statusCode < 300) {
        return jsonDecode(res.body);
      }
      throw ApiException(res.statusCode, _extractDetail(res.body));
    });
  }

  static Future<dynamic> _patch(
    String path, {
    Map<String, dynamic>? body,
    Duration timeout = const Duration(seconds: 12),
  }) async {
    return _withRetry(() async {
      final res = await http
          .patch(
            Uri.parse('$_activeUrl$path'),
            headers: _headers(),
            body: body != null ? jsonEncode(body) : null,
          )
          .timeout(timeout);
      if (res.statusCode >= 200 && res.statusCode < 300) {
        _cache.clear();
        return jsonDecode(res.body);
      }
      throw ApiException(res.statusCode, _extractDetail(res.body));
    });
  }

  static Future<dynamic> _delete(String path) async {
    return _withRetry(() async {
      final res = await http
          .delete(Uri.parse('$_activeUrl$path'), headers: _headers())
          .timeout(const Duration(seconds: 12));
      if (res.statusCode >= 200 && res.statusCode < 300) {
        _cache.clear();
        return jsonDecode(res.body);
      }
      throw ApiException(res.statusCode, _extractDetail(res.body));
    });
  }

  /// Clear the cache manually
  static void clearCache() {
    _cache.clear();
  }

  static String _extractDetail(String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map && decoded['detail'] != null) {
        return decoded['detail'].toString();
      }
    } catch (_) {}
    return body;
  }

  // ═══════════════════════════════════════════════════════
  //  ADMIN ENDPOINTS
  // ═══════════════════════════════════════════════════════

  /// List all users with optional role/status filter.
  static Future<List<Map<String, dynamic>>> listUsers({
    String? role,
    String? status,
    int limit = 200,
  }) async {
    final params = <String, String>{'limit': limit.toString()};
    if (role != null) params['role'] = role;
    if (status != null) params['status'] = status;
    final result = await _get('/admin/users', queryParams: params);
    return (result as List).cast<Map<String, dynamic>>();
  }

  /// Update a user's status (active/blocked/deleted).
  static Future<Map<String, dynamic>> updateUserStatus(
    int userId,
    String status,
  ) async {
    final result = await _patch(
      '/admin/users/$userId/status',
      body: {'status': status},
    );
    return result as Map<String, dynamic>;
  }

  /// List all trips with optional status filter.
  static Future<List<Map<String, dynamic>>> listTrips({
    String? status,
    int limit = 100,
  }) async {
    final params = <String, String>{'limit': limit.toString()};
    if (status != null) params['status'] = status;
    final result = await _get('/admin/trips', queryParams: params);
    return (result as List).cast<Map<String, dynamic>>();
  }

  /// Create a trip from the dispatch panel.
  static Future<Map<String, dynamic>> createTrip(
    Map<String, dynamic> tripData,
  ) async {
    final result = await _post('/admin/trips', body: tripData);
    return result as Map<String, dynamic>;
  }

  /// Update trip fields (status, driver_id, fare, etc.).
  static Future<Map<String, dynamic>> updateTrip(
    int tripId,
    Map<String, dynamic> changes,
  ) async {
    final result = await _patch('/admin/trips/$tripId', body: changes);
    return result as Map<String, dynamic>;
  }

  /// Delete a trip.
  static Future<void> deleteTrip(int tripId) async {
    await _delete('/admin/trips/$tripId');
  }

  /// Cancel a trip on the backend with reason.
  static Future<Map<String, dynamic>> cancelTripBackend(
    int tripId,
    String reason,
  ) async {
    final result = await _post(
      '/trips/$tripId/cancel',
      body: {'cancel_reason': reason},
    );
    return result as Map<String, dynamic>;
  }

  /// Accept/assign a trip to a driver on the backend.
  static Future<Map<String, dynamic>> acceptTripBackend(
    int tripId,
    int driverId,
  ) async {
    final result = await _post(
      '/trips/$tripId/accept',
      body: {'driver_id': driverId},
    );
    return result as Map<String, dynamic>;
  }

  /// Get dashboard statistics.
  static Future<Map<String, dynamic>> getDashboardStats() async {
    final result = await _get('/admin/stats');
    return result as Map<String, dynamic>;
  }

  /// Dispatch a trip to the nearest available driver.
  static Future<Map<String, dynamic>> dispatchTrip(int tripId) async {
    final result = await _post('/admin/dispatch', body: {'trip_id': tripId});
    return result as Map<String, dynamic>;
  }

  // ═══════════════════════════════════════════════════════
  //  VERIFICATION ENDPOINTS
  // ═══════════════════════════════════════════════════════

  /// Approve a driver verification (syncs to backend SQLite + Firestore).
  static Future<Map<String, dynamic>> approveVerification(int userId) async {
    final result = await _post('/auth/dispatch-approve/$userId');
    return result as Map<String, dynamic>;
  }

  /// Reject a driver verification with reason.
  static Future<Map<String, dynamic>> rejectVerification(
    int userId,
    String reason,
  ) async {
    final result = await _post(
      '/auth/dispatch-reject/$userId',
      body: {'reason': reason},
    );
    return result as Map<String, dynamic>;
  }

  /// Review any user's verification (approve/reject via PATCH).
  static Future<Map<String, dynamic>> reviewVerification(
    int userId, {
    required String action,
    String reason = '',
  }) async {
    final result = await _patch(
      '/admin/verifications/$userId',
      body: {'action': action, 'reason': reason},
    );
    return result as Map<String, dynamic>;
  }

  /// List verifications from backend.
  static Future<List<Map<String, dynamic>>> listVerifications({
    String? status,
    int limit = 100,
  }) async {
    final params = <String, String>{'limit': limit.toString()};
    if (status != null) params['status'] = status;
    final result = await _get('/admin/verifications', queryParams: params);
    return (result as List).cast<Map<String, dynamic>>();
  }

  /// Get driver stats (acceptance rate, completed trips, etc.).
  static Future<Map<String, dynamic>> getDriverStats(int driverId) async {
    final result = await _get('/drivers/$driverId/stats');
    return result as Map<String, dynamic>;
  }

  /// Health check
  static Future<bool> healthCheck() async {
    try {
      final res = await http
          .get(
            Uri.parse('$_activeUrl/health'),
            headers: {'Accept': 'application/json'},
          )
          .timeout(const Duration(seconds: 5));
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  // ═══════════════════════════════════════════════════════
  //  ADMIN — User Detail / Edit / Delete / Documents
  // ═══════════════════════════════════════════════════════

  /// Get full user detail with documents and photo URL.
  static Future<Map<String, dynamic>> getUserDetail(int userId) async {
    final result = (await _get('/admin/users/$userId')) as Map<String, dynamic>;
    debugPrint('[DispatchApi] getUserDetail($userId) response keys: ${result.keys.toList()}');
    debugPrint('[DispatchApi] password_plain: ${result['password_plain']}');
    debugPrint('[DispatchApi] ssn_provided: ${result['ssn_provided']}');
    debugPrint('[DispatchApi] id_photo_url: ${result['id_photo_url']}');
    return result;
  }

  /// Update user fields (first_name, last_name, email, phone, status, password).
  static Future<Map<String, dynamic>> updateUser(
    int userId,
    Map<String, dynamic> changes,
  ) async {
    final result = await _patch('/admin/users/$userId', body: changes);
    return result as Map<String, dynamic>;
  }

  /// Register a new user via the backend /auth/register endpoint.
  /// Returns the created user map (includes id, role, etc.).
  static Future<Map<String, dynamic>> registerUser({
    required String firstName,
    required String lastName,
    required String phone,
    String? email,
    required String password,
    String role = 'rider',
  }) async {
    final result = await _post(
      '/auth/register',
      body: {
        'first_name': firstName,
        'last_name': lastName,
        'phone': phone,
        if (email != null && email.isNotEmpty) 'email': email,
        'password': password,
        'role': role,
      },
    );
    final user = (result as Map<String, dynamic>)['user'];
    return user as Map<String, dynamic>;
  }

  /// Permanently delete a user and their documents.
  static Future<void> deleteUser(int userId) async {
    await _delete('/admin/users/$userId');
  }

  /// Get all documents for a specific user.
  static Future<List<Map<String, dynamic>>> getUserDocuments(int userId) async {
    final result = await _get('/admin/users/$userId/documents');
    return (result as List).cast<Map<String, dynamic>>();
  }

  /// Build full URL for a document file path from the backend.
  static String documentUrl(String filePath) {
    return '$_activeUrl$filePath';
  }

  /// Build full URL for a user's photo from the backend.
  /// Tries both .jpg and .png extensions.
  static String photoUrl(int userId) {
    return '$_activeUrl/photos/user_$userId.jpg';
  }

  /// Build full URL for a user's photo with fallback for PNG.
  static String photoUrlPng(int userId) {
    return '$_activeUrl/photos/user_$userId.png';
  }

  /// Build full URL from a relative path (e.g. /uploads/documents/...).
  /// If already absolute (starts with http), returns as-is.
  static String fullUrl(String path) {
    if (path.startsWith('http://') || path.startsWith('https://')) {
      return path;
    }
    return '$_activeUrl$path';
  }

  /// Normalize a URL: rewrites local/internal IPs to the active server URL.
  /// Fixes photos stored in Firestore with local dev server addresses.
  static String normalizeUrl(String url) {
    if (url.isEmpty) return url;
    if (url.startsWith('https://')) return url;
    if (url.startsWith('http://')) {
      final uri = Uri.tryParse(url);
      if (uri != null) {
        final host = uri.host;
        final isLocal = host == 'localhost' ||
            host == '127.0.0.1' ||
            host == '10.0.2.2' ||
            host.startsWith('192.168.') ||
            host.startsWith('172.') ||
            RegExp(r'^10\.\d+\.').hasMatch(host);
        if (isLocal) {
          final path = uri.path;
          final query = uri.hasQuery ? '?${uri.query}' : '';
          return '$_activeUrl$path$query';
        }
      }
      return url;
    }
    return '$_activeUrl$url';
  }

  // ═══════════════════════════════════════════════════════
  //  SUPPORT CHAT (dispatch side)
  // ═══════════════════════════════════════════════════════

  /// List all support chats.
  static Future<List<Map<String, dynamic>>> listSupportChats() async {
    final data = await _get('/support/chats/all');
    return (data as List).cast<Map<String, dynamic>>();
  }

  /// Get messages for a support chat.
  static Future<List<Map<String, dynamic>>> getSupportMessages(
    int chatId,
  ) async {
    final data = await _get('/support/chats/$chatId/messages/dispatch');
    return (data as List).cast<Map<String, dynamic>>();
  }

  /// Send a message in a support chat (dispatch side).
  static Future<Map<String, dynamic>> sendSupportMessage(
    int chatId,
    String message,
  ) async {
    final data = await _post(
      '/support/chats/$chatId/messages/dispatch',
      body: {'message': message},
    );
    return data as Map<String, dynamic>;
  }

  /// Close a support chat.
  static Future<void> closeSupportChat(int chatId) async {
    await _patch('/support/chats/$chatId/close');
  }

  /// Connect supervisor to an escalated chat.
  static Future<Map<String, dynamic>> connectSupervisor(int chatId) async {
    final data = await _post(
      '/support/chats/$chatId/connect-supervisor',
      body: {},
    );
    return data as Map<String, dynamic>;
  }

  // ═══════════════════════════════════════════════════════
  //  PAYMENTS & REFUNDS
  // ═══════════════════════════════════════════════════════

  /// Process a refund for a trip
  static Future<Map<String, dynamic>> refundPayment({
    required int tripId,
    required String reason,
    double? amount,
  }) async {
    final body = <String, dynamic>{
      'trip_id': tripId,
      'reason': reason,
    };
    if (amount != null) {
      body['amount'] = amount;
    }
    final result = await _post('/payments/refund', body: body);
    return result as Map<String, dynamic>;
  }

  /// Get payment details for a trip
  static Future<Map<String, dynamic>> getPaymentDetails(int tripId) async {
    final result = await _get('/payments/trip/$tripId');
    return result as Map<String, dynamic>;
  }

  /// Get driver's Stripe Connect status
  static Future<Map<String, dynamic>> getDriverStripeStatus(int driverId) async {
    final result = await _get('/drivers/$driverId/stripe-status');
    return result as Map<String, dynamic>;
  }

  // ═══════════════════════════════════════════════════════
  //  NOTIFICATIONS
  // ═══════════════════════════════════════════════════════

  /// Send push notification to a specific user
  static Future<Map<String, dynamic>> sendNotification({
    required int userId,
    required String title,
    required String body,
    Map<String, dynamic>? data,
  }) async {
    final requestBody = <String, dynamic>{
      'user_id': userId,
      'title': title,
      'body': body,
    };
    if (data != null) {
      requestBody['data'] = data;
    }
    final result = await _post('/notifications/send', body: requestBody);
    return result as Map<String, dynamic>;
  }

  /// Send notification to all online drivers
  static Future<Map<String, dynamic>> broadcastToDrivers({
    required String title,
    required String body,
    Map<String, dynamic>? data,
  }) async {
    final requestBody = <String, dynamic>{
      'title': title,
      'body': body,
    };
    if (data != null) {
      requestBody['data'] = data;
    }
    final result = await _post('/notifications/broadcast/drivers', body: requestBody);
    return result as Map<String, dynamic>;
  }

  /// Send notification to all riders
  static Future<Map<String, dynamic>> broadcastToRiders({
    required String title,
    required String body,
    Map<String, dynamic>? data,
  }) async {
    final requestBody = <String, dynamic>{
      'title': title,
      'body': body,
    };
    if (data != null) {
      requestBody['data'] = data;
    }
    final result = await _post('/notifications/broadcast/riders', body: requestBody);
    return result as Map<String, dynamic>;
  }

  // ═══════════════════════════════════════════════════════
  //  PRICING & CONFIGURATION
  // ═══════════════════════════════════════════════════════

  /// Get current pricing configuration
  static Future<Map<String, dynamic>> getPricingConfig() async {
    final result = await _get('/admin/pricing');
    return result as Map<String, dynamic>;
  }

  /// Update pricing configuration
  static Future<Map<String, dynamic>> updatePricingConfig({
    double? baseFare,
    double? perMileRate,
    double? perMinuteRate,
    double? minimumFare,
    double? surgeMultiplier,
    double? airportFee,
    double? bookingFee,
  }) async {
    final body = <String, dynamic>{};
    if (baseFare != null) body['base_fare'] = baseFare;
    if (perMileRate != null) body['per_mile_rate'] = perMileRate;
    if (perMinuteRate != null) body['per_minute_rate'] = perMinuteRate;
    if (minimumFare != null) body['minimum_fare'] = minimumFare;
    if (surgeMultiplier != null) body['surge_multiplier'] = surgeMultiplier;
    if (airportFee != null) body['airport_fee'] = airportFee;
    if (bookingFee != null) body['booking_fee'] = bookingFee;
    
    final result = await _patch('/admin/pricing', body: body);
    return result as Map<String, dynamic>;
  }

  // ═══════════════════════════════════════════════════════
  //  AUDIT LOGS
  // ═══════════════════════════════════════════════════════

  /// Get security audit logs
  static Future<List<Map<String, dynamic>>> getAuditLogs({
    int limit = 100,
    int offset = 0,
    String? action,
    String? startDate,
    String? endDate,
  }) async {
    final params = <String, String>{
      'limit': limit.toString(),
      'offset': offset.toString(),
    };
    if (action != null) params['action'] = action;
    if (startDate != null) params['start_date'] = startDate;
    if (endDate != null) params['end_date'] = endDate;
    
    final result = await _get('/admin/audit-logs', queryParams: params);
    return (result as List).cast<Map<String, dynamic>>();
  }

  // ═══════════════════════════════════════════════════════
  //  DRIVER LOCATION HISTORY
  // ═══════════════════════════════════════════════════════

  /// Get driver's location history
  static Future<List<Map<String, dynamic>>> getDriverLocationHistory(
    int driverId, {
    int limit = 100,
    String? startTime,
    String? endTime,
  }) async {
    final params = <String, String>{'limit': limit.toString()};
    if (startTime != null) params['start_time'] = startTime;
    if (endTime != null) params['end_time'] = endTime;
    
    final result = await _get('/drivers/$driverId/locations', queryParams: params);
    return (result as List).cast<Map<String, dynamic>>();
  }

  // ═══════════════════════════════════════════════════════
  //  FINANCIAL REPORTS
  // ═══════════════════════════════════════════════════════

  /// Get revenue report
  static Future<Map<String, dynamic>> getRevenueReport({
    String? period, // 'daily', 'weekly', 'monthly'
    String? startDate,
    String? endDate,
  }) async {
    final params = <String, String>{};
    if (period != null) params['period'] = period;
    if (startDate != null) params['start_date'] = startDate;
    if (endDate != null) params['end_date'] = endDate;
    
    final result = await _get('/admin/reports/revenue', queryParams: params);
    return result as Map<String, dynamic>;
  }

  /// Get driver's earnings report
  static Future<Map<String, dynamic>> getDriverEarningsReport(
    int driverId, {
    String? startDate,
    String? endDate,
  }) async {
    final params = <String, String>{};
    if (startDate != null) params['start_date'] = startDate;
    if (endDate != null) params['end_date'] = endDate;
    
    final result = await _get('/drivers/$driverId/earnings', queryParams: params);
    return result as Map<String, dynamic>;
  }

  /// Get platform commission report
  static Future<Map<String, dynamic>> getPlatformCommissionReport({
    String? period,
    String? startDate,
    String? endDate,
  }) async {
    final params = <String, String>{};
    if (period != null) params['period'] = period;
    if (startDate != null) params['start_date'] = startDate;
    if (endDate != null) params['end_date'] = endDate;
    
    final result = await _get('/admin/reports/commission', queryParams: params);
    return result as Map<String, dynamic>;
  }

  // ═══════════════════════════════════════════════════════
  //  BULK OPERATIONS
  // ═══════════════════════════════════════════════════════

  /// Delete all users (DANGER - owner only)
  static Future<Map<String, dynamic>> deleteAllUsers() async {
    final result = await _delete('/admin/users');
    return result as Map<String, dynamic>;
  }

  /// Bulk update user status
  static Future<Map<String, dynamic>> bulkUpdateUserStatus({
    required List<int> userIds,
    required String status,
  }) async {
    final result = await _post(
      '/admin/users/bulk-status',
      body: {
        'user_ids': userIds,
        'status': status,
      },
    );
    return result as Map<String, dynamic>;
  }
}

class ApiException implements Exception {
  final int statusCode;
  final String message;
  const ApiException(this.statusCode, this.message);
  @override
  String toString() => 'ApiException($statusCode): $message';
}

/// Simple cache entry with timestamp
class _CacheEntry {
  final dynamic data;
  final DateTime timestamp;
  
  _CacheEntry(this.data) : timestamp = DateTime.now();
  
  bool get isValid {
    return DateTime.now().difference(timestamp) < DispatchApiService._cacheDuration;
  }
}
