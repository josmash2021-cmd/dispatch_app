import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/driver_model.dart';
import '../services/audit_service.dart';
import '../services/driver_service.dart';

class DriverProvider extends ChangeNotifier {
  final DriverService _service = DriverService();
  final AuditService _audit = AuditService();

  List<DriverModel> _drivers = [];
  List<DriverModel> get drivers => _filteredDrivers;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  String _searchQuery = '';
  String get searchQuery => _searchQuery;

  StreamSubscription? _subscription;

  int get totalDrivers => _drivers.length;
  int get onlineDrivers => _drivers.where((d) => d.isOnline).length;
  int get offlineDrivers => _drivers.where((d) => !d.isOnline).length;
  int get verifiedDrivers => _drivers.where((d) => d.isVerified).length;
  List<DriverModel> get filteredDrivers => _filteredDrivers;

  /// Start listening to real-time driver updates
  void startListening() {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    _subscription?.cancel();
    _subscription = _service.getDriversStream().listen(
      (drivers) {
        _drivers = drivers;
        _isLoading = false;
        _errorMessage = null;
        notifyListeners();
      },
      onError: (error) {
        _errorMessage = 'Error loading drivers: $error';
        _isLoading = false;
        notifyListeners();
      },
    );
  }

  List<DriverModel> get _filteredDrivers {
    if (_searchQuery.isEmpty) return _drivers;
    final q = _searchQuery.toLowerCase();
    return _drivers.where((d) {
      return d.fullName.toLowerCase().contains(q) ||
          d.phone.toLowerCase().contains(q) ||
          (d.vehiclePlate?.toLowerCase().contains(q) ?? false) ||
          (d.vehicleType?.toLowerCase().contains(q) ?? false);
    }).toList();
  }

  void setSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  Future<void> addDriver(DriverModel driver) async {
    try {
      final id = await _service.addDriver(driver);
      await _audit.logCreate('drivers', id, driver.fullName);
    } catch (e) {
      _errorMessage = 'Error adding driver: $e';
      notifyListeners();
    }
  }

  Future<void> deleteDriver(String driverId, {String? driverName}) async {
    try {
      await _service.deleteDriver(driverId);
      await _audit.logDelete('drivers', driverId, driverName ?? driverId);
    } catch (e) {
      _errorMessage = 'Error deleting driver: $e';
      notifyListeners();
    }
  }

  /// Change driver status: 'active', 'inactive', 'blocked'
  Future<void> updateDriverStatus(
    String driverId,
    String newStatus, {
    String? driverName,
  }) async {
    try {
      await _service.updateStatus(driverId, newStatus);
      await _audit.logUpdate(
        'drivers',
        driverId,
        '${driverName ?? driverId} → $newStatus',
      );
    } catch (e) {
      _errorMessage = 'Error updating driver status: $e';
      notifyListeners();
    }
  }

  Future<void> updateDriver(
    String driverId,
    Map<String, dynamic> data, {
    String? driverName,
  }) async {
    try {
      await _service.updateDriver(driverId, {
        ...data,
        'lastUpdated': DateTime.now(),
      });
      await _audit.logUpdate(
        'drivers',
        driverId,
        '${driverName ?? driverId} edited',
      );
    } catch (e) {
      _errorMessage = 'Error updating driver: $e';
      notifyListeners();
    }
  }

  Future<void> refreshDrivers() async {
    _isLoading = true;
    notifyListeners();
    try {
      _drivers = await _service.getDriversList();
      _errorMessage = null;
    } catch (e) {
      _errorMessage = 'Error refreshing drivers: $e';
    }
    _isLoading = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
