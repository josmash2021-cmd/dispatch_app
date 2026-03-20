import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../config/app_theme.dart';
import '../services/audit_service.dart';

/// Service that listens for real-time changes in Firestore and shows
/// in-app notifications for profile updates and new verifications
class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final List<StreamSubscription> _subscriptions = [];
  final Map<String, DateTime> _lastNotified = {};

  /// Start listening for all notification types
  void startListening(BuildContext context) {
    _stopAll();
    
    // Listen for client profile changes
    _listenToCollection(
      context, 
      'clients', 
      Icons.person_outline,
      AppColors.warning,
      'Cliente'
    );
    
    // Listen for driver profile changes  
    _listenToCollection(
      context,
      'drivers',
      Icons.local_taxi_outlined,
      AppColors.primary,
      'Conductor'
    );
    
    // Listen for new verifications
    _listenToVerifications(context);
  }

  void _listenToCollection(
    BuildContext context,
    String collection,
    IconData icon,
    Color color,
    String roleLabel,
  ) {
    // Only listen for recent updates (last 5 minutes to avoid flood on startup)
    final fiveMinutesAgo = DateTime.now().subtract(const Duration(minutes: 5));
    
    final sub = FirebaseFirestore.instance
        .collection(collection)
        .where('lastUpdated', isGreaterThan: Timestamp.fromDate(fiveMinutesAgo))
        .snapshots()
        .listen((snapshot) {
          for (final change in snapshot.docChanges) {
            if (change.type == DocumentChangeType.modified) {
              _handleProfileChange(
                context, change.doc, icon, color, roleLabel, collection);
            }
          }
        });
    
    _subscriptions.add(sub);
  }

  Future<void> _handleProfileChange(
    BuildContext context,
    DocumentSnapshot doc,
    IconData icon,
    Color color,
    String roleLabel,
    String collection,
  ) async {
    final data = doc.data() as Map<String, dynamic>?;
    if (data == null) return;

    final docId = doc.id;
    final now = DateTime.now();
    
    // Debounce - don't notify same user more than once per 30 seconds
    final lastTime = _lastNotified[docId];
    if (lastTime != null && now.difference(lastTime).inSeconds < 30) {
      return;
    }
    _lastNotified[docId] = now;

    final firstName = data['firstName'] ?? data['first_name'] ?? 'Usuario';
    final lastName = data['lastName'] ?? data['last_name'] ?? '';
    final name = '$firstName $lastName'.trim();

    // Detect what changed
    final changedFields = <String, dynamic>{};
    final changeLabels = <String>[];

    if (_fieldChanged(data, 'photoUrl') || _fieldChanged(data, 'photo_url')) {
      changedFields['photoUrl'] = data['photoUrl'] ?? data['photo_url'];
      changeLabels.add('foto de perfil');
    }
    if (_fieldChanged(data, 'phone') || _fieldChanged(data, 'phoneNumber')) {
      changedFields['phone'] = data['phone'] ?? data['phoneNumber'];
      changeLabels.add('teléfono');
    }
    if (_fieldChanged(data, 'email')) {
      changedFields['email'] = data['email'];
      changeLabels.add('email');
    }
    if (_fieldChanged(data, 'firstName') || _fieldChanged(data, 'lastName')) {
      changedFields['name'] = name;
      changeLabels.add('nombre');
    }
    if (data['passwordUpdated'] == true) {
      changedFields['passwordUpdated'] = true;
      changeLabels.add('contraseña');
    }
    if (_fieldChanged(data, 'vehicleType') || _fieldChanged(data, 'vehiclePlate')) {
      changedFields['vehicle'] =
          '${data['vehicleType'] ?? ''} ${data['vehiclePlate'] ?? ''}'.trim();
      changeLabels.add('vehículo');
    }

    if (changeLabels.isEmpty) return;

    // Write to audit_log so the Cambios tab can show it
    try {
      await AuditService().logUpdate(
        collection,
        docId,
        name,
        changes: {
          'fields': changeLabels,
          'values': changedFields,
          'source': 'user_self_update',
        },
      );
    } catch (_) {}

    // Show notification
    _showNotification(
      context,
      icon: icon,
      color: color,
      title: '📢 $roleLabel actualizó su perfil',
      message: '$name cambió: ${changeLabels.join(', ')}',
      actionLabel: 'Ver cambios',
      userId: docId,
      userType: collection,
      changedFields: changeLabels,
    );
  }

  void _listenToVerifications(BuildContext context) {
    final sub = FirebaseFirestore.instance
        .collection('verifications')
        .where('status', isEqualTo: 'pending')
        .where('createdAt', isGreaterThan: Timestamp.fromDate(
          DateTime.now().subtract(const Duration(minutes: 5))
        ))
        .snapshots()
        .listen((snapshot) {
          for (final change in snapshot.docChanges) {
            if (change.type == DocumentChangeType.added) {
              final data = change.doc.data();
              if (data == null) continue;
              
              final name = data['fullName'] ?? 
                          '${data['firstName'] ?? ''} ${data['lastName'] ?? ''}'.trim() ??
                          'Nuevo usuario';
              
              _showNotification(
                context,
                icon: Icons.verified_user_outlined,
                color: AppColors.success,
                title: '✅ Nueva verificación pendiente',
                message: '$name solicita verificación de cuenta',
                actionLabel: 'Verificar ahora',
                duration: const Duration(seconds: 8),
              );
            }
          }
        });
    
    _subscriptions.add(sub);
  }

  bool _fieldChanged(Map<String, dynamic> data, String field) {
    // Check if field exists and was recently updated
    if (!data.containsKey(field)) return false;
    
    final updatedAt = data['lastUpdated'] ?? data['updatedAt'];
    if (updatedAt is Timestamp) {
      final updateTime = updatedAt.toDate();
      final now = DateTime.now();
      // Only consider changed if updated in last 2 minutes
      return now.difference(updateTime).inMinutes < 2;
    }
    return false;
  }

  void _showNotification(
    BuildContext context, {
    required IconData icon,
    required Color color,
    required String title,
    required String message,
    required String actionLabel,
    VoidCallback? onAction,
    String? userId,
    String? userType,
    List<String>? changedFields,
    Duration duration = const Duration(seconds: 6),
  }) {
    notificationStream.add(NotificationEvent(
      icon: icon,
      color: color,
      title: title,
      message: message,
      actionLabel: actionLabel,
      onAction: onAction,
      userId: userId,
      userType: userType,
      changedFields: changedFields,
      duration: duration,
    ));
  }

  void _stopAll() {
    for (final sub in _subscriptions) {
      sub.cancel();
    }
    _subscriptions.clear();
  }

  void stop() {
    _stopAll();
    _lastNotified.clear();
  }
}

/// Event emitted when a notification should be shown
class NotificationEvent {
  final IconData icon;
  final Color color;
  final String title;
  final String message;
  final String actionLabel;
  final VoidCallback? onAction;
  /// Firestore doc ID of the client/driver who changed their profile
  final String? userId;
  /// 'clients' or 'drivers'
  final String? userType;
  /// Human-readable list of changed fields
  final List<String>? changedFields;
  final Duration duration;

  NotificationEvent({
    required this.icon,
    required this.color,
    required this.title,
    required this.message,
    required this.actionLabel,
    this.onAction,
    this.userId,
    this.userType,
    this.changedFields,
    required this.duration,
  });
}

/// Global stream for notifications
final StreamController<NotificationEvent> notificationStream = 
    StreamController<NotificationEvent>.broadcast();
