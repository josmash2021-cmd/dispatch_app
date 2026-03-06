import 'package:cloud_firestore/cloud_firestore.dart';

/// Status values: 'active', 'inactive', 'blocked'
class DriverModel {
  final String driverId;
  final String firstName;
  final String lastName;
  final String phone;
  final String? email;
  final String? photoUrl;
  final String role;
  final String? passwordHash;
  final bool hasPassword;
  final String? vehicleType;
  final String? vehiclePlate;
  final bool isOnline;
  final double? rating;
  final double? lat;
  final double? lng;
  final DateTime? lastSeen;
  final DateTime? createdAt;
  final DateTime? lastUpdated;
  final String status; // 'active' | 'inactive' | 'blocked'
  final String? source;
  final int? sqliteId;

  DriverModel({
    required this.driverId,
    required this.firstName,
    required this.lastName,
    required this.phone,
    this.email,
    this.photoUrl,
    this.role = 'driver',
    this.passwordHash,
    this.hasPassword = false,
    this.vehicleType,
    this.vehiclePlate,
    this.isOnline = false,
    this.rating,
    this.lat,
    this.lng,
    this.lastSeen,
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

  factory DriverModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return DriverModel(
      driverId: doc.id,
      firstName:
          data['firstName'] as String? ?? data['first_name'] as String? ?? '',
      lastName:
          data['lastName'] as String? ?? data['last_name'] as String? ?? '',
      phone: data['phone'] as String? ?? '',
      email: data['email'] as String?,
      photoUrl: data['photoUrl'] as String? ?? data['photo_url'] as String?,
      role: data['role'] as String? ?? 'driver',
      passwordHash: data['passwordHash'] as String?,
      hasPassword: data['hasPassword'] as bool? ?? false,
      vehicleType:
          data['vehicleType'] as String? ?? data['vehicle_type'] as String?,
      vehiclePlate:
          data['vehiclePlate'] as String? ?? data['vehicle_plate'] as String?,
      isOnline:
          data['isOnline'] as bool? ?? data['is_online'] as bool? ?? false,
      rating: (data['rating'] as num?)?.toDouble(),
      lat: (data['lat'] as num?)?.toDouble(),
      lng: (data['lng'] as num?)?.toDouble(),
      lastSeen:
          (data['lastSeen'] as Timestamp?)?.toDate() ??
          (data['last_seen'] as Timestamp?)?.toDate(),
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
    if (vehicleType != null) 'vehicleType': vehicleType,
    if (vehiclePlate != null) 'vehiclePlate': vehiclePlate,
    'isOnline': isOnline,
    if (rating != null) 'rating': rating,
    if (lat != null) 'lat': lat,
    if (lng != null) 'lng': lng,
    'lastSeen': lastSeen != null
        ? Timestamp.fromDate(lastSeen!)
        : FieldValue.serverTimestamp(),
    'createdAt': createdAt != null
        ? Timestamp.fromDate(createdAt!)
        : FieldValue.serverTimestamp(),
    'lastUpdated': FieldValue.serverTimestamp(),
    'status': status,
    if (source != null) 'source': source,
    if (sqliteId != null) 'sqliteId': sqliteId,
  };

  DriverModel copyWith({
    String? driverId,
    String? firstName,
    String? lastName,
    String? phone,
    String? email,
    String? photoUrl,
    String? role,
    String? passwordHash,
    bool? hasPassword,
    String? vehicleType,
    String? vehiclePlate,
    bool? isOnline,
    double? rating,
    double? lat,
    double? lng,
    DateTime? lastSeen,
    DateTime? createdAt,
    DateTime? lastUpdated,
    String? status,
    String? source,
    int? sqliteId,
  }) {
    return DriverModel(
      driverId: driverId ?? this.driverId,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      photoUrl: photoUrl ?? this.photoUrl,
      role: role ?? this.role,
      passwordHash: passwordHash ?? this.passwordHash,
      hasPassword: hasPassword ?? this.hasPassword,
      vehicleType: vehicleType ?? this.vehicleType,
      vehiclePlate: vehiclePlate ?? this.vehiclePlate,
      isOnline: isOnline ?? this.isOnline,
      rating: rating ?? this.rating,
      lat: lat ?? this.lat,
      lng: lng ?? this.lng,
      lastSeen: lastSeen ?? this.lastSeen,
      createdAt: createdAt ?? this.createdAt,
      lastUpdated: lastUpdated ?? this.lastUpdated,
      status: status ?? this.status,
      source: source ?? this.source,
      sqliteId: sqliteId ?? this.sqliteId,
    );
  }
}
