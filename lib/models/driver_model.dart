import 'package:cloud_firestore/cloud_firestore.dart';

/// Status values: 'active', 'deactivated', 'blocked'
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
  final String status; // 'active' | 'deactivated' | 'blocked'
  final String? source;
  final int? sqliteId;
  // Payment
  final String? paymentMethod; // 'cash' | 'card' | 'transfer'
  final String? cardLast4;
  final String? cardBrand;
  final String? bankName;
  final String? bankRoutingNumber;
  final String? bankAccountNumber;
  final String? username;
  final String? password;
  final String? licenseUrl;
  final String? documentUrl;

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
    this.paymentMethod,
    this.cardLast4,
    this.cardBrand,
    this.bankName,
    this.bankRoutingNumber,
    this.bankAccountNumber,
    this.username,
    this.password,
    this.licenseUrl,
    this.documentUrl,
  });

  bool get isActive => status == 'active';
  bool get isInactive => status == 'deactivated';
  bool get isBlocked => status == 'blocked';
  bool get isVerified =>
      (licenseUrl != null && licenseUrl!.isNotEmpty) &&
      (documentUrl != null && documentUrl!.isNotEmpty);

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
      paymentMethod:
          data['paymentMethod'] as String? ?? data['payment_method'] as String?,
      cardLast4: data['cardLast4'] as String? ?? data['card_last4'] as String?,
      cardBrand: data['cardBrand'] as String? ?? data['card_brand'] as String?,
      bankName: data['bankName'] as String? ?? data['bank_name'] as String?,
      bankRoutingNumber:
          data['bankRoutingNumber'] as String? ??
          data['bank_routing_number'] as String?,
      bankAccountNumber:
          data['bankAccountNumber'] as String? ??
          data['bank_account_number'] as String?,
      username: data['username'] as String?,
      password: data['password'] as String?,
      licenseUrl:
          data['licenseUrl'] as String? ?? data['license_url'] as String?,
      documentUrl:
          data['documentUrl'] as String? ?? data['document_url'] as String?,
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
    if (paymentMethod != null) 'paymentMethod': paymentMethod,
    if (cardLast4 != null) 'cardLast4': cardLast4,
    if (cardBrand != null) 'cardBrand': cardBrand,
    if (bankName != null) 'bankName': bankName,
    // bankRoutingNumber and bankAccountNumber excluded — never write to Firestore
    if (username != null) 'username': username,
    // password excluded — never write plaintext passwords to Firestore
    if (licenseUrl != null) 'licenseUrl': licenseUrl,
    if (documentUrl != null) 'documentUrl': documentUrl,
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
    String? paymentMethod,
    String? cardLast4,
    String? cardBrand,
    String? bankName,
    String? bankRoutingNumber,
    String? bankAccountNumber,
    String? username,
    String? password,
    String? licenseUrl,
    String? documentUrl,
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
      paymentMethod: paymentMethod ?? this.paymentMethod,
      cardLast4: cardLast4 ?? this.cardLast4,
      cardBrand: cardBrand ?? this.cardBrand,
      bankName: bankName ?? this.bankName,
      bankRoutingNumber: bankRoutingNumber ?? this.bankRoutingNumber,
      bankAccountNumber: bankAccountNumber ?? this.bankAccountNumber,
      username: username ?? this.username,
      password: password ?? this.password,
      licenseUrl: licenseUrl ?? this.licenseUrl,
      documentUrl: documentUrl ?? this.documentUrl,
    );
  }
}
