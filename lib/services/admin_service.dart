import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Manages admin roles and permissions in Firestore.
/// Collection: admins/{uid} → { email, role, createdAt }
/// Roles: 'superadmin', 'admin'
class AdminService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  CollectionReference get _adminsCollection => _firestore.collection('admins');

  /// Check if the current user is an admin
  Future<bool> isCurrentUserAdmin() async {
    final user = _auth.currentUser;
    if (user == null) return false;
    final doc = await _adminsCollection.doc(user.uid).get();
    return doc.exists;
  }

  /// Get the current user's role
  Future<String?> getCurrentUserRole() async {
    final user = _auth.currentUser;
    if (user == null) return null;
    final doc = await _adminsCollection.doc(user.uid).get();
    if (!doc.exists) return null;
    return (doc.data() as Map<String, dynamic>)['role'] as String?;
  }

  /// Stream the current user's admin document for real-time role updates
  Stream<Map<String, dynamic>?> watchCurrentUserRole() {
    final user = _auth.currentUser;
    if (user == null) return Stream.value(null);
    return _adminsCollection.doc(user.uid).snapshots().map((doc) {
      if (!doc.exists) return null;
      return doc.data() as Map<String, dynamic>;
    });
  }

  /// Bootstrap: create initial superadmin if no admins exist
  /// This only works if Firestore rules allow it (first setup)
  Future<bool> bootstrapSuperAdmin() async {
    final user = _auth.currentUser;
    if (user == null) return false;

    // Check if any admin already exists
    final existing = await _adminsCollection.limit(1).get();
    if (existing.docs.isNotEmpty) {
      // If current user is already admin, return true
      final myDoc = await _adminsCollection.doc(user.uid).get();
      return myDoc.exists;
    }

    // No admins exist — create first superadmin
    await _adminsCollection.doc(user.uid).set({
      'email': user.email,
      'role': 'superadmin',
      'displayName':
          user.displayName ?? user.email?.split('@').first ?? 'Admin',
      'createdAt': FieldValue.serverTimestamp(),
      'createdBy': 'system_bootstrap',
    });
    return true;
  }

  /// Re-authenticate the current user (for destructive operations)
  Future<bool> reAuthenticate(String password) async {
    final user = _auth.currentUser;
    if (user == null || user.email == null) return false;
    try {
      final credential = EmailAuthProvider.credential(
        email: user.email!,
        password: password,
      );
      await user.reauthenticateWithCredential(credential);
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Get all admins (for superadmin management)
  Stream<List<Map<String, dynamic>>> getAdminsStream() {
    return _adminsCollection.snapshots().map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        data['uid'] = doc.id;
        return data;
      }).toList();
    });
  }
}
