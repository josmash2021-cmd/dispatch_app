import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config/env.dart';

/// HTTP client for the Cruise FastAPI backend with API-key + HMAC signing.
/// Used by the dispatch admin panel to sync operations with the backend.
class DispatchApiService {
  static const String _defaultTunnelUrl =
      'https://combines-dramatically-five-cooperative.trycloudflare.com';
  static const String _localNetworkUrl = 'http://172.20.11.24:8000';
  static const String _localUrl = 'http://10.0.2.2:8000';
  static const String _adbUrl = 'http://localhost:8000';

  static const String _serverUrlPrefKey = 'dispatch_server_url';

  static String _activeUrl = _defaultTunnelUrl;
  static String get activeServerUrl => _activeUrl;

  static const String _apiKey = Env.apiKey;
  static const String _hmacSecret = Env.hmacSecret;

  /// Load persisted server URL. Call once before runApp().
  static Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_serverUrlPrefKey);
    if (saved != null && saved.isNotEmpty) {
      _activeUrl = saved;
    }
    debugPrint('[DispatchApi] active URL: $_activeUrl');
  }

  /// Persist a new server URL.
  static Future<void> setServerUrl(String url) async {
    _activeUrl = url.trimRight().replaceAll(RegExp(r'/+$'), '');
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_serverUrlPrefKey, _activeUrl);
    debugPrint('[DispatchApi] server URL updated → $_activeUrl');
  }

  /// Auto-detect reachable backend URL.
  static Future<String?> probeAndSetBestUrl({
    Duration timeout = const Duration(seconds: 6),
  }) async {
    final urls = [
      _activeUrl,
      _defaultTunnelUrl,
      _adbUrl,
      _localNetworkUrl,
      _localUrl,
    ];
    for (final url in urls) {
      try {
        final res = await http
            .get(
              Uri.parse('$url/health'),
              headers: {'Accept': 'application/json'},
            )
            .timeout(timeout);
        if (res.statusCode == 200) {
          await setServerUrl(url);
          return url;
        }
      } catch (_) {}
    }
    // Try discovering tunnel URL via local backend
    for (final base in [_localNetworkUrl, _localUrl]) {
      try {
        final disc = await http
            .get(
              Uri.parse('$base/tunnel-url'),
              headers: {'Accept': 'application/json'},
            )
            .timeout(timeout);
        if (disc.statusCode == 200) {
          final body = jsonDecode(disc.body);
          final tunnelUrl = body['tunnel_url'] as String?;
          if (tunnelUrl != null && tunnelUrl.isNotEmpty) {
            final check = await http
                .get(
                  Uri.parse('$tunnelUrl/health'),
                  headers: {'Accept': 'application/json'},
                )
                .timeout(timeout);
            if (check.statusCode == 200) {
              await setServerUrl(tunnelUrl);
              return tunnelUrl;
            }
          }
        }
      } catch (_) {}
    }
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

  // ── HTTP helpers ───────────────────────────────────────

  static Future<dynamic> _get(
    String path, {
    Map<String, String>? queryParams,
  }) async {
    final uri = Uri.parse(
      '$_activeUrl$path',
    ).replace(queryParameters: queryParams);
    final res = await http
        .get(uri, headers: _headers())
        .timeout(const Duration(seconds: 15));
    if (res.statusCode >= 200 && res.statusCode < 300) {
      return jsonDecode(res.body);
    }
    throw ApiException(res.statusCode, _extractDetail(res.body));
  }

  static Future<dynamic> _post(
    String path, {
    Map<String, dynamic>? body,
  }) async {
    final res = await http
        .post(
          Uri.parse('$_activeUrl$path'),
          headers: _headers(),
          body: body != null ? jsonEncode(body) : null,
        )
        .timeout(const Duration(seconds: 15));
    if (res.statusCode >= 200 && res.statusCode < 300) {
      return jsonDecode(res.body);
    }
    throw ApiException(res.statusCode, _extractDetail(res.body));
  }

  static Future<dynamic> _patch(
    String path, {
    Map<String, dynamic>? body,
  }) async {
    final res = await http
        .patch(
          Uri.parse('$_activeUrl$path'),
          headers: _headers(),
          body: body != null ? jsonEncode(body) : null,
        )
        .timeout(const Duration(seconds: 15));
    if (res.statusCode >= 200 && res.statusCode < 300) {
      return jsonDecode(res.body);
    }
    throw ApiException(res.statusCode, _extractDetail(res.body));
  }

  static Future<dynamic> _delete(String path) async {
    final res = await http
        .delete(Uri.parse('$_activeUrl$path'), headers: _headers())
        .timeout(const Duration(seconds: 15));
    if (res.statusCode >= 200 && res.statusCode < 300) {
      return jsonDecode(res.body);
    }
    throw ApiException(res.statusCode, _extractDetail(res.body));
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
    final result = await _get('/admin/users/$userId');
    return result as Map<String, dynamic>;
  }

  /// Update user fields (first_name, last_name, email, phone, status, password).
  static Future<Map<String, dynamic>> updateUser(
    int userId,
    Map<String, dynamic> changes,
  ) async {
    final result = await _patch('/admin/users/$userId', body: changes);
    return result as Map<String, dynamic>;
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
  static String fullUrl(String relativePath) {
    return '$_activeUrl$relativePath';
  }
}

class ApiException implements Exception {
  final int statusCode;
  final String message;
  const ApiException(this.statusCode, this.message);
  @override
  String toString() => 'ApiException($statusCode): $message';
}
