import 'package:cloud_firestore/cloud_firestore.dart';

enum TripStatus {
  requested,
  accepted,
  driverArrived,
  inProgress,
  completed,
  cancelled,
}

extension TripStatusExtension on TripStatus {
  String get label {
    switch (this) {
      case TripStatus.requested:
        return 'Requested';
      case TripStatus.accepted:
        return 'Accepted';
      case TripStatus.driverArrived:
        return 'Driver Arrived';
      case TripStatus.inProgress:
        return 'In Progress';
      case TripStatus.completed:
        return 'Completed';
      case TripStatus.cancelled:
        return 'Cancelled';
    }
  }

  String get value {
    switch (this) {
      case TripStatus.requested:
        return 'requested';
      case TripStatus.accepted:
        return 'accepted';
      case TripStatus.driverArrived:
        return 'driver_arrived';
      case TripStatus.inProgress:
        return 'in_progress';
      case TripStatus.completed:
        return 'completed';
      case TripStatus.cancelled:
        return 'cancelled';
    }
  }

  static TripStatus fromString(String status) {
    switch (status) {
      case 'requested':
        return TripStatus.requested;
      case 'accepted':
        return TripStatus.accepted;
      case 'driver_arrived':
        return TripStatus.driverArrived;
      case 'in_progress':
        return TripStatus.inProgress;
      case 'completed':
        return TripStatus.completed;
      case 'cancelled':
        return TripStatus.cancelled;
      default:
        return TripStatus.requested;
    }
  }
}

class TripModel {
  final String tripId;
  final String passengerId;
  final String passengerName;
  final String passengerPhone;
  final String? driverId;
  final String? driverName;
  final String? driverPhone;
  final String pickupAddress;
  final double pickupLat;
  final double pickupLng;
  final String dropoffAddress;
  final double dropoffLat;
  final double dropoffLng;
  final TripStatus status;
  final double fare;
  final double distance; // km
  final int duration; // minutes
  final String paymentMethod;
  final String vehicleType;
  final double? rating;
  final String? cancelReason;
  final DateTime createdAt;
  final DateTime? acceptedAt;
  final DateTime? driverArrivedAt;
  final DateTime? startedAt;
  final DateTime? completedAt;
  final DateTime? cancelledAt;

  TripModel({
    required this.tripId,
    required this.passengerId,
    required this.passengerName,
    required this.passengerPhone,
    this.driverId,
    this.driverName,
    this.driverPhone,
    required this.pickupAddress,
    required this.pickupLat,
    required this.pickupLng,
    required this.dropoffAddress,
    required this.dropoffLat,
    required this.dropoffLng,
    required this.status,
    required this.fare,
    required this.distance,
    required this.duration,
    required this.paymentMethod,
    this.vehicleType = 'Economy',
    this.rating,
    this.cancelReason,
    required this.createdAt,
    this.acceptedAt,
    this.driverArrivedAt,
    this.startedAt,
    this.completedAt,
    this.cancelledAt,
  });

  factory TripModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return TripModel(
      tripId: doc.id,
      passengerId: data['passengerId'] ?? '',
      passengerName: data['passengerName'] ?? 'Desconocido',
      passengerPhone: data['passengerPhone'] ?? '',
      driverId: data['driverId'],
      driverName: data['driverName'],
      driverPhone: data['driverPhone'],
      pickupAddress: data['pickupAddress'] ?? '',
      pickupLat: (data['pickupLat'] ?? 0.0).toDouble(),
      pickupLng: (data['pickupLng'] ?? 0.0).toDouble(),
      dropoffAddress: data['dropoffAddress'] ?? '',
      dropoffLat: (data['dropoffLat'] ?? 0.0).toDouble(),
      dropoffLng: (data['dropoffLng'] ?? 0.0).toDouble(),
      status: TripStatusExtension.fromString(data['status'] ?? 'requested'),
      fare: (data['fare'] ?? 0.0).toDouble(),
      distance: (data['distance'] ?? 0.0).toDouble(),
      duration: (data['duration'] ?? 0).toInt(),
      paymentMethod: data['paymentMethod'] ?? 'cash',
      vehicleType: data['vehicleType'] ?? 'Economy',
      rating: data['rating']?.toDouble(),
      cancelReason: data['cancelReason'],
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      acceptedAt: (data['acceptedAt'] as Timestamp?)?.toDate(),
      driverArrivedAt: (data['driverArrivedAt'] as Timestamp?)?.toDate(),
      startedAt: (data['startedAt'] as Timestamp?)?.toDate(),
      completedAt: (data['completedAt'] as Timestamp?)?.toDate(),
      cancelledAt: (data['cancelledAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'passengerId': passengerId,
      'passengerName': passengerName,
      'passengerPhone': passengerPhone,
      'driverId': driverId,
      'driverName': driverName,
      'driverPhone': driverPhone,
      'pickupAddress': pickupAddress,
      'pickupLat': pickupLat,
      'pickupLng': pickupLng,
      'dropoffAddress': dropoffAddress,
      'dropoffLat': dropoffLat,
      'dropoffLng': dropoffLng,
      'status': status.value,
      'fare': fare,
      'distance': distance,
      'duration': duration,
      'paymentMethod': paymentMethod,
      'vehicleType': vehicleType,
      'rating': rating,
      'cancelReason': cancelReason,
      'createdAt': Timestamp.fromDate(createdAt),
      'acceptedAt': acceptedAt != null ? Timestamp.fromDate(acceptedAt!) : null,
      'driverArrivedAt':
          driverArrivedAt != null
              ? Timestamp.fromDate(driverArrivedAt!)
              : null,
      'startedAt': startedAt != null ? Timestamp.fromDate(startedAt!) : null,
      'completedAt':
          completedAt != null ? Timestamp.fromDate(completedAt!) : null,
      'cancelledAt':
          cancelledAt != null ? Timestamp.fromDate(cancelledAt!) : null,
    };
  }

  TripModel copyWith({
    String? tripId,
    String? passengerId,
    String? passengerName,
    String? passengerPhone,
    String? driverId,
    String? driverName,
    String? driverPhone,
    String? pickupAddress,
    double? pickupLat,
    double? pickupLng,
    String? dropoffAddress,
    double? dropoffLat,
    double? dropoffLng,
    TripStatus? status,
    double? fare,
    double? distance,
    int? duration,
    String? paymentMethod,
    String? vehicleType,
    double? rating,
    String? cancelReason,
    DateTime? createdAt,
    DateTime? acceptedAt,
    DateTime? driverArrivedAt,
    DateTime? startedAt,
    DateTime? completedAt,
    DateTime? cancelledAt,
  }) {
    return TripModel(
      tripId: tripId ?? this.tripId,
      passengerId: passengerId ?? this.passengerId,
      passengerName: passengerName ?? this.passengerName,
      passengerPhone: passengerPhone ?? this.passengerPhone,
      driverId: driverId ?? this.driverId,
      driverName: driverName ?? this.driverName,
      driverPhone: driverPhone ?? this.driverPhone,
      pickupAddress: pickupAddress ?? this.pickupAddress,
      pickupLat: pickupLat ?? this.pickupLat,
      pickupLng: pickupLng ?? this.pickupLng,
      dropoffAddress: dropoffAddress ?? this.dropoffAddress,
      dropoffLat: dropoffLat ?? this.dropoffLat,
      dropoffLng: dropoffLng ?? this.dropoffLng,
      status: status ?? this.status,
      fare: fare ?? this.fare,
      distance: distance ?? this.distance,
      duration: duration ?? this.duration,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      vehicleType: vehicleType ?? this.vehicleType,
      rating: rating ?? this.rating,
      cancelReason: cancelReason ?? this.cancelReason,
      createdAt: createdAt ?? this.createdAt,
      acceptedAt: acceptedAt ?? this.acceptedAt,
      driverArrivedAt: driverArrivedAt ?? this.driverArrivedAt,
      startedAt: startedAt ?? this.startedAt,
      completedAt: completedAt ?? this.completedAt,
      cancelledAt: cancelledAt ?? this.cancelledAt,
    );
  }
}
