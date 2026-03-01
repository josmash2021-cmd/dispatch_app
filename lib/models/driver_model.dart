import 'package:cloud_firestore/cloud_firestore.dart';

class DriverModel {
  final String driverId;
  final String firstName;
  final String lastName;
  final String phone;
  final String? photoUrl;
  final String? vehicleType;
  final String? vehiclePlate;
  final bool isOnline;
  final double? rating;
  final DateTime? lastSeen;
  final DateTime? createdAt;

  DriverModel({
    required this.driverId,
    required this.firstName,
    required this.lastName,
    required this.phone,
    this.photoUrl,
    this.vehicleType,
    this.vehiclePlate,
    this.isOnline = false,
    this.rating,
    this.lastSeen,
    this.createdAt,
  });

  String get fullName => '$firstName $lastName'.trim();

  factory DriverModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return DriverModel(
      driverId: doc.id,
      firstName: data['firstName'] as String? ?? data['first_name'] as String? ?? '',
      lastName: data['lastName'] as String? ?? data['last_name'] as String? ?? '',
      phone: data['phone'] as String? ?? '',
      photoUrl: data['photoUrl'] as String? ?? data['photo_url'] as String?,
      vehicleType: data['vehicleType'] as String? ?? data['vehicle_type'] as String?,
      vehiclePlate: data['vehiclePlate'] as String? ?? data['vehicle_plate'] as String?,
      isOnline: data['isOnline'] as bool? ?? data['is_online'] as bool? ?? false,
      rating: (data['rating'] as num?)?.toDouble(),
      lastSeen: (data['lastSeen'] as Timestamp?)?.toDate() ?? (data['last_seen'] as Timestamp?)?.toDate(),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? (data['created_at'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() => {
        'firstName': firstName,
        'lastName': lastName,
        'phone': phone,
        if (photoUrl != null) 'photoUrl': photoUrl,
        if (vehicleType != null) 'vehicleType': vehicleType,
        if (vehiclePlate != null) 'vehiclePlate': vehiclePlate,
        'isOnline': isOnline,
        if (rating != null) 'rating': rating,
        'lastSeen': lastSeen != null ? Timestamp.fromDate(lastSeen!) : FieldValue.serverTimestamp(),
        'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : FieldValue.serverTimestamp(),
      };

  DriverModel copyWith({
    String? driverId,
    String? firstName,
    String? lastName,
    String? phone,
    String? photoUrl,
    String? vehicleType,
    String? vehiclePlate,
    bool? isOnline,
    double? rating,
    DateTime? lastSeen,
    DateTime? createdAt,
  }) {
    return DriverModel(
      driverId: driverId ?? this.driverId,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      phone: phone ?? this.phone,
      photoUrl: photoUrl ?? this.photoUrl,
      vehicleType: vehicleType ?? this.vehicleType,
      vehiclePlate: vehiclePlate ?? this.vehiclePlate,
      isOnline: isOnline ?? this.isOnline,
      rating: rating ?? this.rating,
      lastSeen: lastSeen ?? this.lastSeen,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
