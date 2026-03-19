import 'package:flutter/foundation.dart';
import '../services/dispatch_api_service.dart';

/// Provider for managing pricing configuration
class PricingProvider extends ChangeNotifier {
  bool _isLoading = false;
  String? _errorMessage;
  String? _successMessage;
  
  Map<String, dynamic>? _pricingConfig;
  
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  String? get successMessage => _successMessage;
  Map<String, dynamic>? get pricingConfig => _pricingConfig;

  // Cached pricing values
  double? get baseFare => _pricingConfig?['base_fare']?.toDouble();
  double? get perMileRate => _pricingConfig?['per_mile_rate']?.toDouble();
  double? get perMinuteRate => _pricingConfig?['per_minute_rate']?.toDouble();
  double? get minimumFare => _pricingConfig?['minimum_fare']?.toDouble();
  double? get surgeMultiplier => _pricingConfig?['surge_multiplier']?.toDouble();
  double? get airportFee => _pricingConfig?['airport_fee']?.toDouble();
  double? get bookingFee => _pricingConfig?['booking_fee']?.toDouble();

  void clearMessages() {
    _errorMessage = null;
    _successMessage = null;
    notifyListeners();
  }

  /// Load current pricing configuration
  Future<void> loadPricingConfig() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final result = await DispatchApiService.getPricingConfig();
      _pricingConfig = result;
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Failed to load pricing: $e';
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Update pricing configuration
  Future<bool> updatePricing({
    double? baseFare,
    double? perMileRate,
    double? perMinuteRate,
    double? minimumFare,
    double? surgeMultiplier,
    double? airportFee,
    double? bookingFee,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    _successMessage = null;
    notifyListeners();

    try {
      final result = await DispatchApiService.updatePricingConfig(
        baseFare: baseFare,
        perMileRate: perMileRate,
        perMinuteRate: perMinuteRate,
        minimumFare: minimumFare,
        surgeMultiplier: surgeMultiplier,
        airportFee: airportFee,
        bookingFee: bookingFee,
      );
      _pricingConfig = result;
      _successMessage = 'Pricing updated successfully';
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'Failed to update pricing: $e';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Set surge multiplier (emergency pricing)
  Future<bool> setSurgeMultiplier(double multiplier) async {
    return updatePricing(surgeMultiplier: multiplier);
  }
}
