import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../services/admin_service.dart';
import '../services/audit_service.dart';
import '../services/auth_service.dart';

enum AuthStatus { uninitialized, authenticated, unauthenticated, loading }

class AuthProvider extends ChangeNotifier {
  // ═══ Authorized admin emails — admins collection is the source of truth ═══
  // Fallback: first login creates superadmin via bootstrapSuperAdmin()
  static const List<String> _authorizedEmails = ['royalpurplecorp@gmail.com'];

  final AuthService _authService = AuthService();
  final AdminService _adminService = AdminService();
  final AuditService _auditService = AuditService();

  AuthStatus _status = AuthStatus.uninitialized;
  User? _user;
  String? _errorMessage;
  String? _userRole; // 'superadmin' | 'admin' | null
  bool _isAdmin = false;

  AuthStatus get status => _status;
  User? get user => _user;
  String? get errorMessage => _errorMessage;
  bool get isAuthenticated => _status == AuthStatus.authenticated;
  bool get isLoading => _status == AuthStatus.loading;
  String? get userRole => _userRole;
  bool get isAdmin => _isAdmin;
  bool get isSuperAdmin => _userRole == 'superadmin';

  AuthProvider() {
    _authService.authStateChanges.listen(_onAuthStateChanged);
  }

  void _onAuthStateChanged(User? user) {
    if (user == null) {
      _status = AuthStatus.unauthenticated;
      _user = null;
      _userRole = null;
      _isAdmin = false;
    } else {
      _status = AuthStatus.authenticated;
      _user = user;
      _loadAdminRole();
    }
    notifyListeners();
  }

  Future<void> _loadAdminRole() async {
    try {
      // Bootstrap first superadmin if none exist
      await _adminService.bootstrapSuperAdmin();
      _userRole = await _adminService.getCurrentUserRole();
      _isAdmin = _userRole != null;
      notifyListeners();
    } catch (_) {
      _isAdmin = false;
      _userRole = null;
    }
  }

  Future<bool> signIn({required String email, required String password}) async {
    try {
      _status = AuthStatus.loading;
      _errorMessage = null;
      notifyListeners();

      // ═══ GATE 1: Check against admin list OR Firestore admins ═══
      final normalizedEmail = email.trim().toLowerCase();
      final isInHardcodedList = _authorizedEmails.contains(normalizedEmail);
      bool isFirestoreAdmin = false;
      if (!isInHardcodedList) {
        // Check if email exists in admins collection
        try {
          final snap = await FirebaseFirestore.instance
              .collection('admins')
              .where('email', isEqualTo: normalizedEmail)
              .limit(1)
              .get();
          isFirestoreAdmin = snap.docs.isNotEmpty;
        } catch (_) {}
      }
      if (!isInHardcodedList && !isFirestoreAdmin) {
        _status = AuthStatus.unauthenticated;
        _errorMessage = 'Access denied. Unauthorized account.';
        notifyListeners();
        return false;
      }

      await _authService.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      // ═══ GATE 2: Verify Firebase Auth user is in authorized set ═══
      final currentUser = _authService.currentUser;
      if (currentUser == null) {
        await _authService.signOut();
        _status = AuthStatus.unauthenticated;
        _user = null;
        _userRole = null;
        _isAdmin = false;
        _errorMessage = 'Access denied. Unauthorized account.';
        notifyListeners();
        return false;
      }

      // Bootstrap superadmin if first login
      await _adminService.bootstrapSuperAdmin();
      final role = await _adminService.getCurrentUserRole();
      if (role == null) {
        await _authService.signOut();
        _status = AuthStatus.unauthenticated;
        _user = null;
        _userRole = null;
        _isAdmin = false;
        _errorMessage =
            'Access denied. You are not authorized to use this app.';
        notifyListeners();
        return false;
      }

      _userRole = role;
      _isAdmin = true;

      // Audit log
      try {
        await _auditService.logLogin();
      } catch (_) {}
      return true;
    } catch (e) {
      _status = AuthStatus.unauthenticated;
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<void> signOut() async {
    try {
      await _auditService.logLogout();
    } catch (_) {}
    await _authService.signOut();
    _status = AuthStatus.unauthenticated;
    _user = null;
    _userRole = null;
    _isAdmin = false;
    notifyListeners();
  }

  Future<bool> resetPassword(String email) async {
    // Only allow password reset for authorized admins
    if (!_authorizedEmails.contains(email.trim().toLowerCase())) {
      _errorMessage = 'Access denied. Unauthorized account.';
      notifyListeners();
      return false;
    }
    try {
      _errorMessage = null;
      await _authService.resetPassword(email);
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}
