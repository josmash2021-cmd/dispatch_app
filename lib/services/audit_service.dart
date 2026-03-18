import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Immutable audit trail for all sensitive operations.
/// Collection: audit_log/{auto_id}
class AuditService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  CollectionReference get _auditCollection =>
      _firestore.collection('audit_log');

  /// Log a sensitive action
  Future<void> log({
    required String action,
    required String targetCollection,
    required String targetId,
    String? targetName,
    Map<String, dynamic>? details,
  }) async {
    final user = _auth.currentUser;
    await _auditCollection.add({
      'action': action,
      'targetCollection': targetCollection,
      'targetId': targetId,
      'targetName': targetName,
      'details': details,
      'performedBy': user?.uid ?? 'unknown',
      'performedByEmail': user?.email ?? 'unknown',
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  /// Log actions: create, update, delete, login, logout
  Future<void> logCreate(String collection, String id, String name) => log(
    action: 'create',
    targetCollection: collection,
    targetId: id,
    targetName: name,
  );

  Future<void> logDelete(String collection, String id, String name) => log(
    action: 'delete',
    targetCollection: collection,
    targetId: id,
    targetName: name,
  );

  Future<void> logUpdate(
    String collection,
    String id,
    String name, {
    Map<String, dynamic>? changes,
  }) => log(
    action: 'update',
    targetCollection: collection,
    targetId: id,
    targetName: name,
    details: changes,
  );

  Future<void> logLogin() => log(
    action: 'login',
    targetCollection: 'auth',
    targetId: _auth.currentUser?.uid ?? '',
    targetName: _auth.currentUser?.email,
  );

  Future<void> logLogout() => log(
    action: 'logout',
    targetCollection: 'auth',
    targetId: _auth.currentUser?.uid ?? '',
    targetName: _auth.currentUser?.email,
  );
}
