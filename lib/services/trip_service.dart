import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/trip_model.dart';
import 'dispatch_api_service.dart';

class TripService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference get _tripsCollection => _firestore.collection('trips');

  /// Stream de todos los viajes en tiempo real, ordenados por fecha de creación
  Stream<List<TripModel>> getTripsStream({
    TripStatus? statusFilter,
    int? limit,
  }) {
    return _tripsCollection.snapshots().map((snapshot) {
      List<TripModel> list = snapshot.docs.map((doc) => TripModel.fromFirestore(doc)).toList();
      if (statusFilter != null) {
        list = list.where((t) => t.status == statusFilter).toList();
      }
      list.sort((a, b) {
        final aTime = a.createdAt ?? DateTime(2000);
        final bTime = b.createdAt ?? DateTime(2000);
        return bTime.compareTo(aTime);
      });
      if (limit != null && list.length > limit) {
        list = list.sublist(0, limit);
      }
      return list;
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

  /// Get raw Firestore document for a trip.
  Future<DocumentSnapshot> tripDoc(String tripId) {
    return _tripsCollection.doc(tripId).get();
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

  /// Crear un nuevo viaje — writes to Firestore AND syncs to backend
  Future<String> createTrip(TripModel trip) async {
    final docRef = await _tripsCollection.add(trip.toMap());
    // Sync to backend
    try {
      await DispatchApiService.createTrip({
        'pickup_address': trip.pickupAddress,
        'dropoff_address': trip.dropoffAddress,
        'pickup_lat': trip.pickupLat,
        'pickup_lng': trip.pickupLng,
        'dropoff_lat': trip.dropoffLat,
        'dropoff_lng': trip.dropoffLng,
        'fare': trip.fare,
        'vehicle_type': trip.vehicleType,
        'status': trip.status.value,
        'notes': 'dispatch:${docRef.id}',
      });
    } catch (e) {
      debugPrint('[TripService] Backend sync failed on create: $e');
    }
    return docRef.id;
  }

  /// Actualizar el estado de un viaje — syncs to backend via SQLite ID
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
    // Sync status to backend if we have a sqliteId
    _syncStatusToBackend(tripId, newStatus.value);
  }

  /// Best-effort sync: find the backend trip by notes field containing Firestore docId
  void _syncStatusToBackend(String firestoreId, String status) async {
    try {
      final doc = await _tripsCollection.doc(firestoreId).get();
      if (!doc.exists) return;
      final data = doc.data() as Map<String, dynamic>? ?? {};
      final sqliteId = data['sqliteId'] as int?;
      if (sqliteId != null) {
        await DispatchApiService.updateTrip(sqliteId, {'status': status});
      }
    } catch (e) {
      debugPrint('[TripService] Backend status sync failed: $e');
    }
  }

  /// Asignar un conductor a un viaje — syncs to backend
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
    // Sync assignment to backend
    _syncAssignToBackend(tripId, driverId, driverName, driverPhone);
  }

  /// Sync driver assignment to backend via sqliteId
  void _syncAssignToBackend(
    String firestoreId,
    String driverId,
    String driverName,
    String driverPhone,
  ) async {
    try {
      final doc = await _tripsCollection.doc(firestoreId).get();
      if (!doc.exists) return;
      final data = doc.data() as Map<String, dynamic>? ?? {};
      final sqliteId = data['sqliteId'] as int?;
      // Parse driver SQLite ID from Firestore format "sql_123"
      final driverSqlId = int.tryParse(driverId.replaceFirst('sql_', ''));
      if (sqliteId != null && driverSqlId != null) {
        await DispatchApiService.acceptTripBackend(sqliteId, driverSqlId);
      }
    } catch (e) {
      debugPrint('[TripService] Backend assign sync failed: $e');
    }
  }

  /// Cancelar un viaje con razón — syncs to backend
  Future<void> cancelTrip(String tripId, String reason) async {
    await _tripsCollection.doc(tripId).update({
      'status': TripStatus.cancelled.value,
      'cancelReason': reason,
      'cancelledAt': FieldValue.serverTimestamp(),
    });
    _syncCancelToBackend(tripId, reason);
  }

  /// Sync cancel + reason to backend via sqliteId
  void _syncCancelToBackend(String firestoreId, String reason) async {
    try {
      final doc = await _tripsCollection.doc(firestoreId).get();
      if (!doc.exists) return;
      final data = doc.data() as Map<String, dynamic>? ?? {};
      final sqliteId = data['sqliteId'] as int?;
      if (sqliteId != null) {
        await DispatchApiService.cancelTripBackend(sqliteId, reason);
      }
    } catch (e) {
      debugPrint('[TripService] Backend cancel sync failed: $e');
    }
  }

  /// Actualizar datos de un viaje
  Future<void> updateTrip(String tripId, Map<String, dynamic> data) async {
    await _tripsCollection.doc(tripId).update(data);
  }

  /// Eliminar un viaje
  Future<void> deleteTrip(String tripId) async {
    await _tripsCollection.doc(tripId).delete();
  }

  /// Obtener estadísticas del dashboard — tries backend first, falls back to Firestore
  Future<Map<String, dynamic>> getDashboardStats() async {
    // Try backend first (authoritative source)
    try {
      final backendStats = await DispatchApiService.getDashboardStats();
      return {
        'todayTrips': backendStats['today_trips'] ?? 0,
        'weekTrips': backendStats['week_trips'] ?? 0,
        'monthTrips': backendStats['month_trips'] ?? 0,
        'activeTrips': backendStats['active_trips'] ?? 0,
        'todayRevenue': (backendStats['today_revenue'] ?? 0).toDouble(),
        'weekRevenue': (backendStats['week_revenue'] ?? 0).toDouble(),
        'monthRevenue': (backendStats['month_revenue'] ?? 0).toDouble(),
        'todayCompleted': backendStats['today_completed'] ?? 0,
        'todayCancelled': backendStats['today_cancelled'] ?? 0,
        'todayCompletionRate': (backendStats['completion_rate'] ?? 0)
            .toDouble(),
        'onlineDrivers': backendStats['online_drivers'] ?? 0,
        'totalDrivers': backendStats['total_drivers'] ?? 0,
      };
    } catch (e) {
      debugPrint('[TripService] Backend stats failed, using Firestore: $e');
    }

    // Fallback to Firestore
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    final startOfWeek = startOfDay.subtract(
      Duration(days: startOfDay.weekday - 1),
    );
    final startOfMonth = DateTime(now.year, now.month, 1);

    // Viajes de hoy
    final todaySnapshot = await _tripsCollection
        .where(
          'createdAt',
          isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay),
        )
        .get();

    // Viajes de la semana
    final weekSnapshot = await _tripsCollection
        .where(
          'createdAt',
          isGreaterThanOrEqualTo: Timestamp.fromDate(startOfWeek),
        )
        .get();

    // Viajes del mes
    final monthSnapshot = await _tripsCollection
        .where(
          'createdAt',
          isGreaterThanOrEqualTo: Timestamp.fromDate(startOfMonth),
        )
        .get();

    // Viajes activos (no completados ni cancelados)
    final activeSnapshot = await _tripsCollection
        .where(
          'status',
          whereIn: ['requested', 'accepted', 'driver_arrived', 'in_progress'],
        )
        .get();

    final todayTrips = todaySnapshot.docs
        .map((d) => TripModel.fromFirestore(d))
        .toList();
    final weekTrips = weekSnapshot.docs
        .map((d) => TripModel.fromFirestore(d))
        .toList();
    final monthTrips = monthSnapshot.docs
        .map((d) => TripModel.fromFirestore(d))
        .toList();

    double todayRevenue = todayTrips
        .where((t) => t.status == TripStatus.completed)
        .fold(0.0, (total, t) => total + t.fare);

    double weekRevenue = weekTrips
        .where((t) => t.status == TripStatus.completed)
        .fold(0.0, (total, t) => total + t.fare);

    double monthRevenue = monthTrips
        .where((t) => t.status == TripStatus.completed)
        .fold(0.0, (total, t) => total + t.fare);

    int todayCompleted = todayTrips
        .where((t) => t.status == TripStatus.completed)
        .length;
    int todayCancelled = todayTrips
        .where((t) => t.status == TripStatus.cancelled)
        .length;

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
      'todayCompletionRate': todayTrips.isNotEmpty
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

      final snapshot = await _tripsCollection
          .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(day))
          .where('createdAt', isLessThan: Timestamp.fromDate(nextDay))
          .get();

      final trips = snapshot.docs
          .map((d) => TripModel.fromFirestore(d))
          .toList();
      final completed = trips
          .where((t) => t.status == TripStatus.completed)
          .length;
      final cancelled = trips
          .where((t) => t.status == TripStatus.cancelled)
          .length;
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
