import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/driver_model.dart';
import '../services/audit_service.dart';
import '../services/driver_service.dart';
import '../services/dispatch_api_service.dart';

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
  int _retryCount = 0;
  Timer? _retryTimer;

  int get totalDrivers => _drivers.length;
  int get onlineDrivers => _drivers.where((d) => d.isOnline).length;
  int get offlineDrivers => _drivers.where((d) => !d.isOnline).length;
  int get verifiedDrivers => _drivers.where((d) => d.isVerified).length;
  int get rejectedDrivers => _drivers.where((d) => d.isRejected).length;
  int get pendingDrivers => _drivers.where((d) => d.isPendingVerification).length;
  List<DriverModel> get filteredDrivers => _filteredDrivers;
  List<DriverModel> get allDrivers => _drivers;

  /// Start listening to real-time driver updates
  void startListening() {
    _isLoading = _drivers.isEmpty;
    _errorMessage = null;
    if (_isLoading) notifyListeners();

    _subscription?.cancel();
    _retryTimer?.cancel();
    _subscription = _service.getDriversStream().listen(
      (drivers) {
        _drivers = drivers;
        _isLoading = false;
        _errorMessage = null;
        _retryCount = 0;
        notifyListeners();
      },
      onError: (error) {
        debugPrint('[DriverProvider] stream error: $error');
        _isLoading = false;
        _errorMessage = 'Error al cargar conductores';
        notifyListeners();
        _scheduleRetry();
      },
    );
  }

  void _scheduleRetry() {
    _retryTimer?.cancel();
    final delay = Duration(seconds: _retryCount < 3 ? 3 * (1 << _retryCount) : 30);
    _retryCount++;
    debugPrint('[DriverProvider] retry in ${delay.inSeconds}s (attempt $_retryCount)');
    _retryTimer = Timer(delay, () {
      if (DispatchApiService.isOnline) _retryCount = 0;
      startListening();
    });
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
    _retryTimer?.cancel();
    super.dispose();
  }
}
