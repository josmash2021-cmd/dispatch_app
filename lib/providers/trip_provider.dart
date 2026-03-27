import 'dart:async';
import 'package:flutter/material.dart';
import '../models/trip_model.dart';
import '../services/trip_service.dart';

class TripProvider extends ChangeNotifier {
  final TripService _tripService = TripService();

  List<TripModel> _trips = [];
  List<TripModel> _filteredTrips = [];
  TripModel? _selectedTrip;
  TripStatus? _statusFilter;
  String _searchQuery = '';
  bool _isLoading = false;
  String? _errorMessage;
  StreamSubscription? _tripsSubscription;

  List<TripModel> get trips => _filteredTrips;
  List<TripModel> get allTrips => _trips;
  TripModel? get selectedTrip => _selectedTrip;
  TripStatus? get statusFilter => _statusFilter;
  String get searchQuery => _searchQuery;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  // Conteos por estado
  int get requestedCount =>
      _trips.where((t) => t.status == TripStatus.requested).length;
  int get acceptedCount =>
      _trips.where((t) => t.status == TripStatus.accepted).length;
  int get driverArrivedCount =>
      _trips.where((t) => t.status == TripStatus.driverArrived).length;
  int get inProgressCount =>
      _trips.where((t) => t.status == TripStatus.inProgress).length;
  int get completedCount =>
      _trips.where((t) => t.status == TripStatus.completed).length;
  int get cancelledCount =>
      _trips.where((t) => t.status == TripStatus.cancelled).length;
  int get activeCount =>
      _trips
          .where(
            (t) =>
                t.status != TripStatus.completed &&
                t.status != TripStatus.cancelled,
          )
          .length;

  /// Trips in 'requested' status for more than 2 minutes (no driver assigned).
  List<TripModel> get staleRequestedTrips {
    final cutoff = DateTime.now().subtract(const Duration(minutes: 2));
    return _trips
        .where((t) =>
            t.status == TripStatus.requested &&
            t.createdAt.isBefore(cutoff))
        .toList();
  }

  void startListening() {
    _isLoading = true;
    notifyListeners();

    _tripsSubscription?.cancel();
    _tripsSubscription = _tripService.getTripsStream().listen(
      (trips) {
        _trips = trips;
        _applyFilters();
        _isLoading = false;
        notifyListeners();
      },
      onError: (error) {
        _errorMessage = 'Error al cargar viajes: $error';
        _isLoading = false;
        notifyListeners();
      },
    );
  }

  void stopListening() {
    _tripsSubscription?.cancel();
    _tripsSubscription = null;
  }

  void setStatusFilter(TripStatus? status) {
    _statusFilter = status;
    _applyFilters();
    notifyListeners();
  }

  void setSearchQuery(String query) {
    _searchQuery = query;
    _applyFilters();
    notifyListeners();
  }

  void _applyFilters() {
    _filteredTrips = _trips.where((trip) {
      // Filtro por estado
      if (_statusFilter != null && trip.status != _statusFilter) {
        return false;
      }

      // Filtro por búsqueda
      if (_searchQuery.isNotEmpty) {
        final query = _searchQuery.toLowerCase();
        return trip.passengerName.toLowerCase().contains(query) ||
            trip.passengerPhone.contains(query) ||
            trip.pickupAddress.toLowerCase().contains(query) ||
            trip.dropoffAddress.toLowerCase().contains(query) ||
            (trip.driverName?.toLowerCase().contains(query) ?? false) ||
            trip.tripId.toLowerCase().contains(query);
      }

      return true;
    }).toList();
  }

  void selectTrip(TripModel? trip) {
    _selectedTrip = trip;
    notifyListeners();
  }

  Future<void> refreshTrips() async {
    startListening();
  }

  Future<String> createTrip(TripModel trip) async {
    try {
      _errorMessage = null;
      final id = await _tripService.createTrip(trip);
      return id;
    } catch (e) {
      _errorMessage = 'Error al crear viaje: $e';
      notifyListeners();
      rethrow;
    }
  }

  Future<void> updateTripStatus(String tripId, TripStatus newStatus) async {
    try {
      _errorMessage = null;
      await _tripService.updateTripStatus(tripId, newStatus);
    } catch (e) {
      _errorMessage = 'Error al actualizar estado: $e';
      notifyListeners();
    }
  }

  Future<void> assignDriver({
    required String tripId,
    required String driverId,
    required String driverName,
    required String driverPhone,
  }) async {
    try {
      _errorMessage = null;
      await _tripService.assignDriver(
        tripId: tripId,
        driverId: driverId,
        driverName: driverName,
        driverPhone: driverPhone,
      );
    } catch (e) {
      _errorMessage = 'Error al asignar conductor: $e';
      notifyListeners();
    }
  }

  Future<void> cancelTrip(String tripId, String reason) async {
    try {
      _errorMessage = null;
      await _tripService.cancelTrip(tripId, reason);
    } catch (e) {
      _errorMessage = 'Error al cancelar viaje: $e';
      notifyListeners();
    }
  }

  Future<void> deleteTrip(String tripId) async {
    try {
      _errorMessage = null;
      await _tripService.deleteTrip(tripId);
    } catch (e) {
      _errorMessage = 'Error al eliminar viaje: $e';
      notifyListeners();
    }
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  @override
  void dispose() {
    stopListening();
    super.dispose();
  }
}
