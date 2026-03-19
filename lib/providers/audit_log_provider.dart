import 'package:flutter/foundation.dart';
import '../services/dispatch_api_service.dart';

/// Provider for managing audit logs
class AuditLogProvider extends ChangeNotifier {
  bool _isLoading = false;
  String? _errorMessage;
  List<Map<String, dynamic>> _logs = [];
  bool _hasMore = true;
  int _offset = 0;
  static const int _limit = 50;

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  List<Map<String, dynamic>> get logs => _logs;
  bool get hasMore => _hasMore;
  bool get isInitialLoading => _isLoading && _offset == 0;

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  /// Load audit logs with optional filters
  Future<void> loadLogs({
    String? action,
    String? startDate,
    String? endDate,
    bool refresh = false,
  }) async {
    if (refresh) {
      _offset = 0;
      _logs = [];
      _hasMore = true;
    }

    if (!_hasMore && !refresh) return;

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final result = await DispatchApiService.getAuditLogs(
        limit: _limit,
        offset: _offset,
        action: action,
        startDate: startDate,
        endDate: endDate,
      );

      if (result.length < _limit) {
        _hasMore = false;
      }

      _logs.addAll(result);
      _offset += result.length;
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Failed to load audit logs: $e';
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Load more logs (pagination)
  Future<void> loadMore({
    String? action,
    String? startDate,
    String? endDate,
  }) async {
    if (_isLoading || !_hasMore) return;
    await loadLogs(
      action: action,
      startDate: startDate,
      endDate: endDate,
    );
  }

  /// Refresh logs
  Future<void> refresh({
    String? action,
    String? startDate,
    String? endDate,
  }) async {
    await loadLogs(
      action: action,
      startDate: startDate,
      endDate: endDate,
      refresh: true,
    );
  }
}
