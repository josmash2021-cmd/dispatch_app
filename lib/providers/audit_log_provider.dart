import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// Provider for managing audit logs from Firestore
class AuditLogProvider extends ChangeNotifier {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  StreamSubscription<QuerySnapshot>? _logsSub;
  
  bool _isLoading = true;
  String? _errorMessage;
  List<Map<String, dynamic>> _logs = [];
  bool _hasMore = true;
  DocumentSnapshot? _lastDoc;
  static const int _limit = 50;

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  List<Map<String, dynamic>> get logs => _logs;
  bool get hasMore => _hasMore;
  bool get isInitialLoading => _isLoading && _lastDoc == null;

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  /// Load audit logs with real-time listener
  Future<void> loadLogs({
    String? action,
    String? startDate,
    String? endDate,
    bool refresh = false,
  }) async {
    if (refresh) {
      _lastDoc = null;
      _logs = [];
      _hasMore = true;
      _logsSub?.cancel();
    }

    if (!_hasMore && !refresh) return;

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      // Simplified query to avoid composite index requirements
      // We query by timestamp only (which has automatic indexing)
      // and filter by action locally if needed
      Query query = _db.collection('audit_logs')
          .orderBy('timestamp', descending: true)
          .limit(_limit * 2); // Fetch more to account for local filtering

      // Date filters can be combined with orderBy on same field without extra index
      if (startDate != null) {
        query = query.where('timestamp', isGreaterThanOrEqualTo: DateTime.parse(startDate));
      }
      if (endDate != null) {
        query = query.where('timestamp', isLessThanOrEqualTo: DateTime.parse(endDate));
      }
      
      if (_lastDoc != null) {
        query = query.startAfterDocument(_lastDoc!);
      }

      final snapshot = await query.get();
      
      // Filter by action locally if specified (avoids composite index)
      var docs = snapshot.docs;
      if (action != null) {
        docs = docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          return data['action'] == action;
        }).toList();
      }
      
      // Limit to actual page size after filtering
      if (docs.length > _limit) {
        docs = docs.sublist(0, _limit);
        _hasMore = true;
      } else {
        _hasMore = snapshot.docs.length >= _limit * 2; // Rough check if more might exist
      }
      
      if (docs.isNotEmpty) {
        _lastDoc = docs.last;
      } else {
        _hasMore = false;
      }

      final newLogs = docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id;
        return data;
      }).toList();

      _logs.addAll(newLogs);
      _isLoading = false;
      notifyListeners();

      // Set up real-time listener for new logs (simplified)
      _setupRealtimeListener(action, startDate, endDate);
    } catch (e) {
      _errorMessage = 'Failed to load audit logs: $e';
      _isLoading = false;
      notifyListeners();
    }
  }

  void _setupRealtimeListener(String? action, String? startDate, String? endDate) {
    _logsSub?.cancel();
    
    // Simplified query - only order by timestamp to avoid composite index
    Query query = _db.collection('audit_logs')
        .orderBy('timestamp', descending: true)
        .limit(_limit);

    _logsSub = query.snapshots().listen((snapshot) {
      var docs = snapshot.docs;
      
      // Filter by action locally if specified
      if (action != null) {
        docs = docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          return data['action'] == action;
        }).toList();
      }
      
      // Filter by date locally if specified
      if (startDate != null) {
        final start = DateTime.parse(startDate);
        docs = docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final ts = data['timestamp'];
          if (ts == null) return false;
          final docDate = ts is Timestamp ? ts.toDate() : DateTime.parse(ts.toString());
          return docDate.isAfter(start) || docDate.isAtSameMomentAs(start);
        }).toList();
      }
      
      if (endDate != null) {
        final end = DateTime.parse(endDate);
        docs = docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final ts = data['timestamp'];
          if (ts == null) return false;
          final docDate = ts is Timestamp ? ts.toDate() : DateTime.parse(ts.toString());
          return docDate.isBefore(end) || docDate.isAtSameMomentAs(end);
        }).toList();
      }

      final newLogs = docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id;
        return data;
      }).toList();

      _logs = newLogs;
      _isLoading = false;
      notifyListeners();
    }, onError: (e) {
      _errorMessage = 'Real-time listener error: $e';
      notifyListeners();
    });
  }

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

  @override
  void dispose() {
    _logsSub?.cancel();
    super.dispose();
  }
}
