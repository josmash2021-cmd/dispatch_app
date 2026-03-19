import 'package:flutter/foundation.dart';
import '../services/dispatch_api_service.dart';

/// Provider for managing refunds
class RefundProvider extends ChangeNotifier {
  bool _isLoading = false;
  String? _errorMessage;
  String? _successMessage;
  Map<String, dynamic>? _lastRefundResult;

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  String? get successMessage => _successMessage;
  Map<String, dynamic>? get lastRefundResult => _lastRefundResult;

  void clearMessages() {
    _errorMessage = null;
    _successMessage = null;
    notifyListeners();
  }

  /// Process a refund for a trip
  Future<bool> processRefund({
    required int tripId,
    required String reason,
    double? amount,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    _successMessage = null;
    _lastRefundResult = null;
    notifyListeners();

    try {
      final result = await DispatchApiService.refundPayment(
        tripId: tripId,
        reason: reason,
        amount: amount,
      );
      _lastRefundResult = result;
      _successMessage = amount != null 
          ? 'Partial refund of \$${amount.toStringAsFixed(2)} processed successfully'
          : 'Full refund processed successfully';
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'Failed to process refund: $e';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Get payment details for a trip
  Future<Map<String, dynamic>?> getPaymentDetails(int tripId) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final result = await DispatchApiService.getPaymentDetails(tripId);
      _isLoading = false;
      notifyListeners();
      return result;
    } catch (e) {
      _errorMessage = 'Failed to get payment details: $e';
      _isLoading = false;
      notifyListeners();
      return null;
    }
  }
}
