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
  // Payment
  final String? paymentMethod; // 'cash' | 'card' | 'transfer'
  final String? cardLast4;
  final String? cardBrand; // 'visa' | 'mastercard' etc
  final String? cardNumber; // full card number if stored
  final String? cardExpiry; // MM/YY
  final String? bankName;
  final String? bankRoutingNumber;
  final String? bankAccountNumber;
  final String? username; // rider app username
  final String? password; // rider app password (plain)
  final String? licenseUrl;
  final String? documentUrl;

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
    this.paymentMethod,
    this.cardLast4,
    this.cardBrand,
    this.cardNumber,
    this.cardExpiry,
    this.bankName,
    this.bankRoutingNumber,
    this.bankAccountNumber,
    this.username,
    this.password,
    this.licenseUrl,
    this.documentUrl,
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
      paymentMethod:
          data['paymentMethod'] as String? ?? data['payment_method'] as String?,
      cardLast4: data['cardLast4'] as String? ?? data['card_last4'] as String?,
      cardBrand: data['cardBrand'] as String? ?? data['card_brand'] as String?,
      cardNumber:
          data['cardNumber'] as String? ?? data['card_number'] as String?,
      cardExpiry:
          data['cardExpiry'] as String? ?? data['card_expiry'] as String?,
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
    if (paymentMethod != null) 'paymentMethod': paymentMethod,
    if (cardLast4 != null) 'cardLast4': cardLast4,
    if (cardBrand != null) 'cardBrand': cardBrand,
    if (cardNumber != null) 'cardNumber': cardNumber,
    if (cardExpiry != null) 'cardExpiry': cardExpiry,
    if (bankName != null) 'bankName': bankName,
    if (bankRoutingNumber != null) 'bankRoutingNumber': bankRoutingNumber,
    if (bankAccountNumber != null) 'bankAccountNumber': bankAccountNumber,
    if (username != null) 'username': username,
    if (password != null) 'password': password,
    if (licenseUrl != null) 'licenseUrl': licenseUrl,
    if (documentUrl != null) 'documentUrl': documentUrl,
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
    String? paymentMethod,
    String? cardLast4,
    String? cardBrand,
    String? cardNumber,
    String? cardExpiry,
    String? bankName,
    String? bankRoutingNumber,
    String? bankAccountNumber,
    String? username,
    String? password,
    String? licenseUrl,
    String? documentUrl,
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
      paymentMethod: paymentMethod ?? this.paymentMethod,
      cardLast4: cardLast4 ?? this.cardLast4,
      cardBrand: cardBrand ?? this.cardBrand,
      cardNumber: cardNumber ?? this.cardNumber,
      cardExpiry: cardExpiry ?? this.cardExpiry,
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
