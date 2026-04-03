import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'dispatch_api_service.dart';

/// Result of an approve/reject operation.
/// [syncedToBackend] is false when Firestore succeeded but the backend
/// SQLite sync failed.  The caller can decide whether to show a warning.
class VerificationResult {
  final bool syncedToBackend;
  final String? syncError;
  const VerificationResult({this.syncedToBackend = true, this.syncError});
}

class VerificationRequest {
  final String docId;
  final int userId;
  final String firstName;
  final String lastName;
  final String? email;
  final String phone;
  final String idDocumentType;
  final String role;
  final String status; // pending, approved, rejected
  final String? reason;
  final DateTime? submittedAt;
  final DateTime? reviewedAt;
  final String? idPhotoUrl;
  final String? selfieUrl;
  final String? profilePhotoUrl;
  final String? licenseFrontUrl;
  final String? licenseBackUrl;
  final String? insuranceUrl;
  final String? verificationVideoUrl;
  final Map<String, dynamic>? vehicle;
  // SSN (masked — only last 4 visible)
  final bool ssnProvided;
  final String? ssnMasked;
  final String? ssnLast4;

  VerificationRequest({
    required this.docId,
    required this.userId,
    required this.firstName,
    required this.lastName,
    this.email,
    required this.phone,
    required this.idDocumentType,
    required this.role,
    required this.status,
    this.reason,
    this.submittedAt,
    this.reviewedAt,
    this.idPhotoUrl,
    this.selfieUrl,
    this.profilePhotoUrl,
    this.licenseFrontUrl,
    this.licenseBackUrl,
    this.insuranceUrl,
    this.verificationVideoUrl,
    this.vehicle,
    this.ssnProvided = false,
    this.ssnMasked,
    this.ssnLast4,
  });

  String get fullName => '$firstName $lastName'.trim();

  bool get isPending => status == 'pending';
  bool get isApproved => status == 'approved';
  bool get isRejected => status == 'rejected';

  factory VerificationRequest.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return VerificationRequest(
      docId: doc.id,
      userId: (data['userId'] as num?)?.toInt() ?? 0,
      firstName: data['firstName'] as String? ?? '',
      lastName: data['lastName'] as String? ?? '',
      email: data['email'] as String?,
      phone: data['phone'] as String? ?? '',
      idDocumentType: data['idDocumentType'] as String? ?? 'id_card',
      role: data['role'] as String? ?? 'rider',
      status: data['status'] as String? ?? 'pending',
      reason: data['reason'] as String?,
      submittedAt: (data['submittedAt'] as Timestamp?)?.toDate(),
      reviewedAt: (data['reviewedAt'] as Timestamp?)?.toDate(),
      idPhotoUrl: data['idPhotoUrl'] as String?,
      selfieUrl: data['selfieUrl'] as String?,
      profilePhotoUrl: data['profilePhotoUrl'] as String?,
      licenseFrontUrl: data['licenseFrontUrl'] as String?,
      licenseBackUrl: data['licenseBackUrl'] as String?,
      insuranceUrl: data['insuranceUrl'] as String?,
      verificationVideoUrl: data['verificationVideoUrl'] as String?,
      vehicle: data['vehicle'] as Map<String, dynamic>?,
      ssnProvided: data['ssnProvided'] as bool? ?? false,
      ssnMasked: data['ssnMasked'] as String?,
      ssnLast4: data['ssnLast4'] as String?,
    );
  }
}

class VerificationService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference get _collection => _firestore.collection('verifications');

  /// Real-time stream of all verification requests
  Stream<List<VerificationRequest>> getVerificationsStream() {
    return _collection
        .snapshots()
        .map((snap) {
          final list = snap.docs
              .map((d) => VerificationRequest.fromFirestore(d))
              .toList();
          list.sort((a, b) {
            final aTime = a.submittedAt ?? DateTime(2000);
            final bTime = b.submittedAt ?? DateTime(2000);
            return bTime.compareTo(aTime);
          });
          return list;
        });
  }

  /// Approve a verification request.
  ///
  /// Returns a [VerificationResult] — check [syncedToBackend] to decide
  /// whether to show a non-critical warning to the dispatcher.
  Future<VerificationResult> approve(String docId) async {
    // Read doc data BEFORE batch write (need role, userId, photo)
    final doc = await _collection.doc(docId).get();
    if (!doc.exists) return const VerificationResult();

    final data = doc.data() as Map<String, dynamic>? ?? {};
    final role = data['role'] as String? ?? 'rider';
    final userId = (data['userId'] as num?)?.toInt() ?? 0;
    final col = role == 'driver' ? 'drivers' : 'clients';
    final selfieUrl = data['selfieUrl'] as String?;
    final profilePhotoUrl = data['profilePhotoUrl'] as String? ?? selfieUrl;

    // Atomic batch write to ALL 3 collections — Cruise app detects any of them
    final approvalPayload = <String, dynamic>{
      'status': 'approved',
      'driver_status': 'approved',
      'approvalStatus': 'approved',
      'verificationStatus': 'approved',
      'isVerified': true,
      'isApproved': true,
      'reason': null,
      'verificationReason': null,
      'reviewedAt': FieldValue.serverTimestamp(),
      'updated_at': FieldValue.serverTimestamp(),
      'lastUpdated': FieldValue.serverTimestamp(),
      if (profilePhotoUrl != null && profilePhotoUrl.isNotEmpty)
        'profilePhotoUrl': profilePhotoUrl,
    };

    final batch = _firestore.batch();
    batch.set(_collection.doc(docId), approvalPayload, SetOptions(merge: true));
    batch.set(_firestore.collection(col).doc(docId), approvalPayload, SetOptions(merge: true));
    batch.set(_firestore.collection('users').doc(docId), approvalPayload, SetOptions(merge: true));
    await batch.commit();
    // Sync to backend SQLite — non-critical
    if (userId > 0) {
      try {
        if (role == 'driver') {
          await DispatchApiService.approveVerification(userId);
        } else {
          await DispatchApiService.reviewVerification(
            userId,
            action: 'approve',
          );
        }
      } catch (e) {
        debugPrint('[Verification] Backend approve sync failed: $e');
        return VerificationResult(
          syncedToBackend: false,
          syncError: e.toString(),
        );
      }
    }
    return const VerificationResult();
  }

  /// Reject a verification request with a reason.
  ///
  /// Returns a [VerificationResult] — check [syncedToBackend] to decide
  /// whether to show a non-critical warning to the dispatcher.
  Future<VerificationResult> reject(String docId, String reason) async {
    // Read doc data BEFORE batch write (need role, userId)
    final doc = await _collection.doc(docId).get();
    if (!doc.exists) return const VerificationResult();

    final data = doc.data() as Map<String, dynamic>? ?? {};
    final role = data['role'] as String? ?? 'rider';
    final userId = (data['userId'] as num?)?.toInt() ?? 0;
    final col = role == 'driver' ? 'drivers' : 'clients';

    // Atomic batch write to ALL 3 collections — Cruise app detects any of them
    final rejectPayload = <String, dynamic>{
      'status': 'rejected',
      'driver_status': 'rejected',
      'approvalStatus': 'rejected',
      'verificationStatus': 'rejected',
      'isVerified': false,
      'isApproved': false,
      'reason': reason,
      'verificationReason': reason,
      'reviewedAt': FieldValue.serverTimestamp(),
      'updated_at': FieldValue.serverTimestamp(),
      'lastUpdated': FieldValue.serverTimestamp(),
    };

    final batch = _firestore.batch();
    batch.set(_collection.doc(docId), rejectPayload, SetOptions(merge: true));
    batch.set(_firestore.collection(col).doc(docId), rejectPayload, SetOptions(merge: true));
    batch.set(_firestore.collection('users').doc(docId), rejectPayload, SetOptions(merge: true));
    await batch.commit();
    // Sync to backend SQLite — non-critical
    if (userId > 0) {
      try {
        if (role == 'driver') {
          await DispatchApiService.rejectVerification(userId, reason);
        } else {
          await DispatchApiService.reviewVerification(
            userId,
            action: 'reject',
            reason: reason,
          );
        }
      } catch (e) {
        debugPrint('[Verification] Backend reject sync failed: $e');
        return VerificationResult(
          syncedToBackend: false,
          syncError: e.toString(),
        );
      }
    }
    return const VerificationResult();
  }

  /// Get count of pending verifications
  Stream<int> getPendingCountStream() {
    return _collection
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .map((snap) => snap.docs.length);
  }
}
