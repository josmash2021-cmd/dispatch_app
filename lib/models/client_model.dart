import 'package:cloud_firestore/cloud_firestore.dart';

/// Status values: 'active', 'inactive', 'blocked'
class ClientModel {
  final String clientId;
  final String firstName;
  final String lastName;
  final String phone;
  final String? email;
  final String? photoUrl;
  final String role; // 'rider' | 'driver'
  final String? passwordHash;
  final bool hasPassword;
  final int totalTrips;
  final double totalSpent;
  final double? rating;
  final DateTime? lastTripAt;
  final DateTime? createdAt;
  final DateTime? lastUpdated;
  final String status; // 'active' | 'inactive' | 'blocked'
  final String? source; // 'cruise_app' | null
  final int? sqliteId;

  ClientModel({
    required this.clientId,
    required this.firstName,
    required this.lastName,
    required this.phone,
    this.email,
    this.photoUrl,
    this.role = 'rider',
    this.passwordHash,
    this.hasPassword = false,
    this.totalTrips = 0,
    this.totalSpent = 0.0,
    this.rating,
    this.lastTripAt,
    this.createdAt,
    this.lastUpdated,
    this.status = 'active',
    this.source,
    this.sqliteId,
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
      role: data['role'] as String? ?? 'rider',
      passwordHash: data['passwordHash'] as String?,
      hasPassword: data['hasPassword'] as bool? ?? false,
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
      lastUpdated:
          (data['lastUpdated'] as Timestamp?)?.toDate() ??
          (data['last_updated'] as Timestamp?)?.toDate(),
      status: data['status'] as String? ?? 'active',
      source: data['source'] as String?,
      sqliteId: (data['sqliteId'] as num?)?.toInt(),
    );
  }

  Map<String, dynamic> toMap() => {
    'firstName': firstName,
    'lastName': lastName,
    'phone': phone,
    if (email != null) 'email': email,
    if (photoUrl != null) 'photoUrl': photoUrl,
    'role': role,
    if (passwordHash != null) 'passwordHash': passwordHash,
    'hasPassword': hasPassword,
    'totalTrips': totalTrips,
    'totalSpent': totalSpent,
    if (rating != null) 'rating': rating,
    'lastTripAt': lastTripAt != null ? Timestamp.fromDate(lastTripAt!) : null,
    'createdAt': createdAt != null
        ? Timestamp.fromDate(createdAt!)
        : FieldValue.serverTimestamp(),
    'lastUpdated': FieldValue.serverTimestamp(),
    'status': status,
    if (source != null) 'source': source,
    if (sqliteId != null) 'sqliteId': sqliteId,
  };

  ClientModel copyWith({
    String? clientId,
    String? firstName,
    String? lastName,
    String? phone,
    String? email,
    String? photoUrl,
    String? role,
    String? passwordHash,
    bool? hasPassword,
    int? totalTrips,
    double? totalSpent,
    double? rating,
    DateTime? lastTripAt,
    DateTime? createdAt,
    DateTime? lastUpdated,
    String? status,
    String? source,
    int? sqliteId,
  }) {
    return ClientModel(
      clientId: clientId ?? this.clientId,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      photoUrl: photoUrl ?? this.photoUrl,
      role: role ?? this.role,
      passwordHash: passwordHash ?? this.passwordHash,
      hasPassword: hasPassword ?? this.hasPassword,
      totalTrips: totalTrips ?? this.totalTrips,
      totalSpent: totalSpent ?? this.totalSpent,
      rating: rating ?? this.rating,
      lastTripAt: lastTripAt ?? this.lastTripAt,
      createdAt: createdAt ?? this.createdAt,
      lastUpdated: lastUpdated ?? this.lastUpdated,
      status: status ?? this.status,
      source: source ?? this.source,
      sqliteId: sqliteId ?? this.sqliteId,
    );
  }
}
