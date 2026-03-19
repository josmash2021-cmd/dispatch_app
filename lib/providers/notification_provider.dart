import 'package:flutter/foundation.dart';
import '../services/dispatch_api_service.dart';

/// Provider for managing notifications state and operations
class NotificationProvider extends ChangeNotifier {
  bool _isLoading = false;
  String? _errorMessage;
  String? _successMessage;

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  String? get successMessage => _successMessage;

  void clearMessages() {
    _errorMessage = null;
    _successMessage = null;
    notifyListeners();
  }

  /// Send notification to a specific user
  Future<bool> sendNotificationToUser({
    required int userId,
    required String title,
    required String body,
    Map<String, dynamic>? data,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    _successMessage = null;
    notifyListeners();

    try {
      await DispatchApiService.sendNotification(
        userId: userId,
        title: title,
        body: body,
        data: data,
      );
      _successMessage = 'Notification sent successfully';
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'Failed to send notification: $e';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Broadcast notification to all online drivers
  Future<bool> broadcastToDrivers({
    required String title,
    required String body,
    Map<String, dynamic>? data,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    _successMessage = null;
    notifyListeners();

    try {
      await DispatchApiService.broadcastToDrivers(
        title: title,
        body: body,
        data: data,
      );
      _successMessage = 'Notification sent to all drivers';
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'Failed to broadcast: $e';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Broadcast notification to all riders
  Future<bool> broadcastToRiders({
    required String title,
    required String body,
    Map<String, dynamic>? data,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    _successMessage = null;
    notifyListeners();

    try {
      await DispatchApiService.broadcastToRiders(
        title: title,
        body: body,
        data: data,
      );
      _successMessage = 'Notification sent to all riders';
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'Failed to broadcast: $e';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }
}
