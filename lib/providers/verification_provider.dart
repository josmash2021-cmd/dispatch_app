import 'dart:async';
import 'package:flutter/foundation.dart';
import '../services/verification_service.dart';

class VerificationProvider extends ChangeNotifier {
  final VerificationService _service = VerificationService();

  List<VerificationRequest> _all = [];
  List<VerificationRequest> get verifications => _filtered;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  String _filter = 'all'; // all, pending, approved, rejected
  String get filter => _filter;

  String _searchQuery = '';

  int _pendingCount = 0;
  int get pendingCount => _pendingCount;

  StreamSubscription? _subscription;
  StreamSubscription? _countSub;

  int get totalCount => _all.length;
  int get pendingTotal => _all.where((v) => v.isPending).length;
  int get approvedTotal => _all.where((v) => v.isApproved).length;
  int get rejectedTotal => _all.where((v) => v.isRejected).length;

  List<VerificationRequest> get _filtered {
    var list = _all;
    if (_filter != 'all') {
      list = list.where((v) => v.status == _filter).toList();
    }
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      list = list
          .where((v) =>
              v.fullName.toLowerCase().contains(q) ||
              v.phone.contains(q) ||
              (v.email?.toLowerCase().contains(q) ?? false))
          .toList();
    }
    return list;
  }

  void setFilter(String f) {
    _filter = f;
    notifyListeners();
  }

  void setSearchQuery(String q) {
    _searchQuery = q;
    notifyListeners();
  }

  void startListening() {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    _subscription?.cancel();
    _subscription = _service.getVerificationsStream().listen(
      (list) {
        _all = list;
        _isLoading = false;
        _errorMessage = null;
        notifyListeners();
      },
      onError: (e) {
        _errorMessage = 'Error loading verifications: $e';
        _isLoading = false;
        notifyListeners();
      },
    );

    _countSub?.cancel();
    _countSub = _service.getPendingCountStream().listen(
      (count) {
        _pendingCount = count;
        notifyListeners();
      },
    );
  }

  Future<void> approve(String docId) async {
    try {
      await _service.approve(docId);
    } catch (e) {
      _errorMessage = 'Failed to approve: $e';
      notifyListeners();
    }
  }

  Future<void> reject(String docId, String reason) async {
    try {
      await _service.reject(docId, reason);
    } catch (e) {
      _errorMessage = 'Failed to reject: $e';
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _countSub?.cancel();
    super.dispose();
  }
}
