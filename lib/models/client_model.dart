import 'package:cloud_firestore/cloud_firestore.dart';

/// Status values: 'active', 'inactive', 'blocked'
class ClientModel {
  final String clientId;
  final String firstName;
  final String lastName;
  final String phone;
  final String? email;
  final String? photoUrl;
  final int totalTrips;
  final double totalSpent;
  final double? rating;
  final DateTime? lastTripAt;
  final DateTime? createdAt;
  final String status; // 'active' | 'inactive' | 'blocked'

  ClientModel({
    required this.clientId,
    required this.firstName,
    required this.lastName,
    required this.phone,
    this.email,
    this.photoUrl,
    this.totalTrips = 0,
    this.totalSpent = 0.0,
    this.rating,
    this.lastTripAt,
    this.createdAt,
    this.status = 'active',
  });

  bool get isActive => status == 'active';
  bool get isInactive => status == 'inactive';
  bool get isBlocked => status == 'blocked';

  String get fullName => '$firstName $lastName'.trim();

  factory ClientModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return ClientModel(
      clientId: doc.id,
      firstName:
          data['firstName'] as String? ?? data['first_name'] as String? ?? '',
      lastName:
          data['lastName'] as String? ?? data['last_name'] as String? ?? '',
      phone: data['phone'] as String? ?? '',
      email: data['email'] as String?,
      photoUrl: data['photoUrl'] as String? ?? data['photo_url'] as String?,
      totalTrips:
          (data['totalTrips'] as num?)?.toInt() ??
          (data['total_trips'] as num?)?.toInt() ??
          0,
      totalSpent:
          (data['totalSpent'] as num?)?.toDouble() ??
          (data['total_spent'] as num?)?.toDouble() ??
          0.0,
      rating: (data['rating'] as num?)?.toDouble(),
      lastTripAt:
          (data['lastTripAt'] as Timestamp?)?.toDate() ??
          (data['last_trip_at'] as Timestamp?)?.toDate(),
      createdAt:
          (data['createdAt'] as Timestamp?)?.toDate() ??
          (data['created_at'] as Timestamp?)?.toDate(),
      status: data['status'] as String? ?? 'active',
    );
  }

  Map<String, dynamic> toMap() => {
    'firstName': firstName,
    'lastName': lastName,
    'phone': phone,
    if (email != null) 'email': email,
    if (photoUrl != null) 'photoUrl': photoUrl,
    'totalTrips': totalTrips,
    'totalSpent': totalSpent,
    if (rating != null) 'rating': rating,
    'lastTripAt': lastTripAt != null ? Timestamp.fromDate(lastTripAt!) : null,
    'createdAt': createdAt != null
        ? Timestamp.fromDate(createdAt!)
        : FieldValue.serverTimestamp(),
    'status': status,
  };

  ClientModel copyWith({
    String? clientId,
    String? firstName,
    String? lastName,
    String? phone,
    String? email,
    String? photoUrl,
    int? totalTrips,
    double? totalSpent,
    double? rating,
    DateTime? lastTripAt,
    DateTime? createdAt,
    String? status,
  }) {
    return ClientModel(
      clientId: clientId ?? this.clientId,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      photoUrl: photoUrl ?? this.photoUrl,
      totalTrips: totalTrips ?? this.totalTrips,
      totalSpent: totalSpent ?? this.totalSpent,
      rating: rating ?? this.rating,
      lastTripAt: lastTripAt ?? this.lastTripAt,
      createdAt: createdAt ?? this.createdAt,
      status: status ?? this.status,
    );
  }
}
