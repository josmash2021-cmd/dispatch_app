import 'package:flutter/material.dart';
import '../services/trip_service.dart';

class DashboardProvider extends ChangeNotifier {
  final TripService _tripService = TripService();

  Map<String, dynamic> _stats = {};
  List<Map<String, dynamic>> _weeklyData = [];
  bool _isLoading = false;
  String? _errorMessage;

  Map<String, dynamic> get stats => _stats;
  List<Map<String, dynamic>> get weeklyData => _weeklyData;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  // Getters de conveniencia
  int get todayTrips => _stats['todayTrips'] ?? 0;
  int get weekTrips => _stats['weekTrips'] ?? 0;
  int get monthTrips => _stats['monthTrips'] ?? 0;
  int get activeTrips => _stats['activeTrips'] ?? 0;
  double get todayRevenue => (_stats['todayRevenue'] ?? 0.0).toDouble();
  double get weekRevenue => (_stats['weekRevenue'] ?? 0.0).toDouble();
  double get monthRevenue => (_stats['monthRevenue'] ?? 0.0).toDouble();
  int get todayCompleted => _stats['todayCompleted'] ?? 0;
  int get todayCancelled => _stats['todayCancelled'] ?? 0;
  double get todayCompletionRate =>
      (_stats['todayCompletionRate'] ?? 0.0).toDouble();

  Future<void> loadDashboardData() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final results = await Future.wait([
        _tripService.getDashboardStats(),
        _tripService.getWeeklyChartData(),
      ]);

      _stats = results[0] as Map<String, dynamic>;
      _weeklyData = results[1] as List<Map<String, dynamic>>;
    } catch (e) {
      _errorMessage = 'Error al cargar estadísticas: $e';
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> refresh() async {
    await loadDashboardData();
  }
}
