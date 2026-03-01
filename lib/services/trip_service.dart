import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/trip_model.dart';

class TripService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference get _tripsCollection => _firestore.collection('trips');

  /// Stream de todos los viajes en tiempo real, ordenados por fecha de creación
  Stream<List<TripModel>> getTripsStream({
    TripStatus? statusFilter,
    int? limit,
  }) {
    Query query = _tripsCollection.orderBy('createdAt', descending: true);

    if (statusFilter != null) {
      query = query.where('status', isEqualTo: statusFilter.value);
    }

    if (limit != null) {
      query = query.limit(limit);
    }

    return query.snapshots().map((snapshot) {
      return snapshot.docs.map((doc) => TripModel.fromFirestore(doc)).toList();
    });
  }

  /// Obtener un viaje específico por ID
  Future<TripModel?> getTripById(String tripId) async {
    final doc = await _tripsCollection.doc(tripId).get();
    if (doc.exists) {
      return TripModel.fromFirestore(doc);
    }
    return null;
  }

  /// Stream de un viaje específico en tiempo real
  Stream<TripModel?> getTripStream(String tripId) {
    return _tripsCollection.doc(tripId).snapshots().map((doc) {
      if (doc.exists) {
        return TripModel.fromFirestore(doc);
      }
      return null;
    });
  }

  /// Crear un nuevo viaje
  Future<String> createTrip(TripModel trip) async {
    final docRef = await _tripsCollection.add(trip.toMap());
    return docRef.id;
  }

  /// Actualizar el estado de un viaje
  Future<void> updateTripStatus(String tripId, TripStatus newStatus) async {
    final Map<String, dynamic> updateData = {'status': newStatus.value};

    switch (newStatus) {
      case TripStatus.accepted:
        updateData['acceptedAt'] = FieldValue.serverTimestamp();
        break;
      case TripStatus.driverArrived:
        updateData['driverArrivedAt'] = FieldValue.serverTimestamp();
        break;
      case TripStatus.inProgress:
        updateData['startedAt'] = FieldValue.serverTimestamp();
        break;
      case TripStatus.completed:
        updateData['completedAt'] = FieldValue.serverTimestamp();
        break;
      case TripStatus.cancelled:
        updateData['cancelledAt'] = FieldValue.serverTimestamp();
        break;
      default:
        break;
    }

    await _tripsCollection.doc(tripId).update(updateData);
  }

  /// Asignar un conductor a un viaje
  Future<void> assignDriver({
    required String tripId,
    required String driverId,
    required String driverName,
    required String driverPhone,
  }) async {
    await _tripsCollection.doc(tripId).update({
      'driverId': driverId,
      'driverName': driverName,
      'driverPhone': driverPhone,
      'status': TripStatus.accepted.value,
      'acceptedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Cancelar un viaje con razón
  Future<void> cancelTrip(String tripId, String reason) async {
    await _tripsCollection.doc(tripId).update({
      'status': TripStatus.cancelled.value,
      'cancelReason': reason,
      'cancelledAt': FieldValue.serverTimestamp(),
    });
  }

  /// Actualizar datos de un viaje
  Future<void> updateTrip(String tripId, Map<String, dynamic> data) async {
    await _tripsCollection.doc(tripId).update(data);
  }

  /// Eliminar un viaje
  Future<void> deleteTrip(String tripId) async {
    await _tripsCollection.doc(tripId).delete();
  }

  /// Obtener estadísticas del dashboard
  Future<Map<String, dynamic>> getDashboardStats() async {
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    final startOfWeek = startOfDay.subtract(
      Duration(days: startOfDay.weekday - 1),
    );
    final startOfMonth = DateTime(now.year, now.month, 1);

    // Viajes de hoy
    final todaySnapshot =
        await _tripsCollection
            .where(
              'createdAt',
              isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay),
            )
            .get();

    // Viajes de la semana
    final weekSnapshot =
        await _tripsCollection
            .where(
              'createdAt',
              isGreaterThanOrEqualTo: Timestamp.fromDate(startOfWeek),
            )
            .get();

    // Viajes del mes
    final monthSnapshot =
        await _tripsCollection
            .where(
              'createdAt',
              isGreaterThanOrEqualTo: Timestamp.fromDate(startOfMonth),
            )
            .get();

    // Viajes activos (no completados ni cancelados)
    final activeSnapshot =
        await _tripsCollection
            .where('status', whereIn: [
              'requested',
              'accepted',
              'driver_arrived',
              'in_progress',
            ])
            .get();

    final todayTrips =
        todaySnapshot.docs
            .map((d) => TripModel.fromFirestore(d))
            .toList();
    final weekTrips =
        weekSnapshot.docs.map((d) => TripModel.fromFirestore(d)).toList();
    final monthTrips =
        monthSnapshot.docs.map((d) => TripModel.fromFirestore(d)).toList();

    double todayRevenue = todayTrips
        .where((t) => t.status == TripStatus.completed)
        .fold(0.0, (total, t) => total + t.fare);

    double weekRevenue = weekTrips
        .where((t) => t.status == TripStatus.completed)
        .fold(0.0, (total, t) => total + t.fare);

    double monthRevenue = monthTrips
        .where((t) => t.status == TripStatus.completed)
        .fold(0.0, (total, t) => total + t.fare);

    int todayCompleted =
        todayTrips.where((t) => t.status == TripStatus.completed).length;
    int todayCancelled =
        todayTrips.where((t) => t.status == TripStatus.cancelled).length;

    return {
      'todayTrips': todayTrips.length,
      'weekTrips': weekTrips.length,
      'monthTrips': monthTrips.length,
      'activeTrips': activeSnapshot.docs.length,
      'todayRevenue': todayRevenue,
      'weekRevenue': weekRevenue,
      'monthRevenue': monthRevenue,
      'todayCompleted': todayCompleted,
      'todayCancelled': todayCancelled,
      'todayCompletionRate':
          todayTrips.isNotEmpty
              ? (todayCompleted / todayTrips.length * 100)
              : 0.0,
    };
  }

  /// Obtener datos para gráficos - viajes por día de la última semana
  Future<List<Map<String, dynamic>>> getWeeklyChartData() async {
    final now = DateTime.now();
    final List<Map<String, dynamic>> chartData = [];

    for (int i = 6; i >= 0; i--) {
      final day = DateTime(now.year, now.month, now.day - i);
      final nextDay = day.add(const Duration(days: 1));

      final snapshot =
          await _tripsCollection
              .where(
                'createdAt',
                isGreaterThanOrEqualTo: Timestamp.fromDate(day),
              )
              .where(
                'createdAt',
                isLessThan: Timestamp.fromDate(nextDay),
              )
              .get();

      final trips =
          snapshot.docs.map((d) => TripModel.fromFirestore(d)).toList();
      final completed =
          trips.where((t) => t.status == TripStatus.completed).length;
      final cancelled =
          trips.where((t) => t.status == TripStatus.cancelled).length;
      final revenue = trips
          .where((t) => t.status == TripStatus.completed)
          .fold(0.0, (total, t) => total + t.fare);

      chartData.add({
        'date': day,
        'total': trips.length,
        'completed': completed,
        'cancelled': cancelled,
        'revenue': revenue,
      });
    }

    return chartData;
  }
}
