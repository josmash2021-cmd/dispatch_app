import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'dispatch_api_service.dart';

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
        .orderBy('submittedAt', descending: true)
        .snapshots()
        .map(
          (snap) => snap.docs
              .map((d) => VerificationRequest.fromFirestore(d))
              .toList(),
        );
  }

  /// Approve a verification request
  Future<void> approve(String docId) async {
    await _collection.doc(docId).update({
      'status': 'approved',
      'reason': null,
      'reviewedAt': FieldValue.serverTimestamp(),
    });
    // Also update the user's verification status in clients/drivers collection
    final doc = await _collection.doc(docId).get();
    if (doc.exists) {
      final data = doc.data() as Map<String, dynamic>? ?? {};
      final role = data['role'] as String? ?? 'rider';
      final userId = (data['userId'] as num?)?.toInt() ?? 0;
      final col = role == 'driver' ? 'drivers' : 'clients';
      await _firestore.collection(col).doc(docId).set({
        'isVerified': true,
        'verificationStatus': 'approved',
        'verificationReason': null,
        'lastUpdated': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      // Also update in users collection
      await _firestore.collection('users').doc(docId).set({
        'isVerified': true,
        'verificationStatus': 'approved',
        'verificationReason': null,
        'lastUpdated': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      // Sync to backend SQLite
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
        }
      }
    }
  }

  /// Reject a verification request with a reason
  Future<void> reject(String docId, String reason) async {
    await _collection.doc(docId).update({
      'status': 'rejected',
      'reason': reason,
      'reviewedAt': FieldValue.serverTimestamp(),
    });
    // Also update the user's verification status
    final doc = await _collection.doc(docId).get();
    if (doc.exists) {
      final data = doc.data() as Map<String, dynamic>? ?? {};
      final role = data['role'] as String? ?? 'rider';
      final userId = (data['userId'] as num?)?.toInt() ?? 0;
      final col = role == 'driver' ? 'drivers' : 'clients';
      await _firestore.collection(col).doc(docId).set({
        'isVerified': false,
        'verificationStatus': 'rejected',
        'verificationReason': reason,
        'lastUpdated': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      await _firestore.collection('users').doc(docId).set({
        'isVerified': false,
        'verificationStatus': 'rejected',
        'verificationReason': reason,
        'lastUpdated': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      // Sync to backend SQLite
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
        }
      }
    }
  }

  /// Get count of pending verifications
  Stream<int> getPendingCountStream() {
    return _collection
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .map((snap) => snap.docs.length);
  }
}
