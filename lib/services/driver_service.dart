import 'dart:async';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/driver_model.dart';
import 'dispatch_api_service.dart';

class DriverService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference get _driversCollection =>
      _firestore.collection('drivers');

  CollectionReference get _usersCollection => _firestore.collection('users');

  /// Real-time stream merging 'drivers' and driver-role docs from 'users'.
  /// Uses combineLatest so ANY change in EITHER collection triggers an update.
  Stream<List<DriverModel>> getDriversStream() {
    final controller = StreamController<List<DriverModel>>();

    List<DriverModel>? lastDrivers;
    List<DriverModel>? lastUserDrivers;

    void merge() {
      final drivers = lastDrivers ?? [];
      final userDrivers = lastUserDrivers ?? [];
      final driverIds = drivers.map((d) => d.driverId).toSet();
      final driverPhones = drivers
          .map((d) => d.phone)
          .where((p) => p.isNotEmpty)
          .toSet();
      final merged = [...drivers];
      for (final ud in userDrivers) {
        if (!driverIds.contains(ud.driverId) &&
            !driverPhones.contains(ud.phone)) {
          merged.add(ud);
        }
      }
      merged.sort((a, b) {
        if (a.isOnline != b.isOnline) return a.isOnline ? -1 : 1;
        return a.fullName.compareTo(b.fullName);
      });
      controller.add(merged);
    }

    final sub1 = _driversCollection
        .snapshots()
        .map((s) => s.docs.map((d) => DriverModel.fromFirestore(d)).toList())
        .listen((drivers) {
          lastDrivers = drivers;
          merge();
        }, onError: (e) => controller.addError(e));

    final sub2 = _usersCollection
        .where('role', isEqualTo: 'driver')
        .snapshots()
        .map((s) => s.docs.map((d) => DriverModel.fromFirestore(d)).toList())
        .listen(
          (userDrivers) {
            lastUserDrivers = userDrivers;
            if (lastDrivers != null) merge();
          },
          onError: (_) {
            lastUserDrivers = [];
            if (lastDrivers != null) merge();
          },
        );

    controller.onCancel = () {
      sub1.cancel();
      sub2.cancel();
      controller.close();
    };

    return controller.stream;
  }

  /// One-time fetch of all drivers
  Future<List<DriverModel>> getDriversList() async {
    final snapshot = await _driversCollection.get();
    final list = snapshot.docs.map((doc) => DriverModel.fromFirestore(doc)).toList();
    list.sort((a, b) {
      if (a.isOnline != b.isOnline) return a.isOnline ? -1 : 1;
      return a.fullName.compareTo(b.fullName);
    });
    return list;
  }

  /// Add a driver manually from dispatch
  Future<String> addDriver(DriverModel driver) async {
    final data = driver.toMap();
    data['createdAt'] = FieldValue.serverTimestamp();
    final docRef = await _driversCollection.add(data);
    // Best-effort: register in backend so SQLite stays in sync
    _syncNewDriverToBackend(docRef.id, driver);
    return docRef.id;
  }

  /// Register a newly-added driver in the backend SQLite via /auth/register.
  void _syncNewDriverToBackend(String firestoreId, DriverModel driver) async {
    try {
      final tempPassword = _generateTempPassword();
      final user = await DispatchApiService.registerUser(
        firstName: driver.firstName,
        lastName: driver.lastName,
        phone: driver.phone,
        password: tempPassword,
        role: 'driver',
      );
      final sqliteId = user['id'] as int?;
      if (sqliteId != null) {
        await _driversCollection.doc(firestoreId).update({
          'sqliteId': sqliteId,
        });
      }
    } catch (e) {
      debugPrint('[DriverService] Backend register sync failed: $e');
    }
  }

  static String _generateTempPassword() {
    const chars =
        'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final rng = Random.secure();
    return List.generate(12, (_) => chars[rng.nextInt(chars.length)]).join();
  }

  /// Update driver online status
  Future<void> setOnlineStatus(String driverId, bool isOnline) async {
    await _driversCollection.doc(driverId).update({
      'isOnline': isOnline,
      'lastSeen': FieldValue.serverTimestamp(),
    });
  }

  /// Update driver status (active / inactive / blocked)
  /// Syncs to 'users' collection AND backend SQLite.
  Future<void> updateStatus(String driverId, String status) async {
    await _driversCollection.doc(driverId).update({
      'status': status,
      'lastUpdated': FieldValue.serverTimestamp(),
    });
    // Sync to users collection
    await _syncStatusToUsers(driverId, status);
    // Sync to backend SQLite
    _syncStatusToBackend(driverId, status);
  }

  /// Best-effort sync status to backend via sqliteId
  void _syncStatusToBackend(String firestoreId, String status) async {
    try {
      final doc = await _driversCollection.doc(firestoreId).get();
      if (!doc.exists) return;
      final data = doc.data() as Map<String, dynamic>? ?? {};
      final sqliteId = data['sqliteId'] as int?;
      if (sqliteId != null) {
        await DispatchApiService.updateUserStatus(sqliteId, status);
      }
    } catch (e) {
      debugPrint('[DriverService] Backend status sync failed: $e');
    }
  }

  /// Update driver fields
  Future<void> updateDriver(String driverId, Map<String, dynamic> data) async {
    await _driversCollection.doc(driverId).update(data);
    // Sync to backend SQLite
    _syncEditToBackend(driverId, data);
  }

  /// Sync edit to backend via sqliteId
  void _syncEditToBackend(String firestoreId, Map<String, dynamic> data) async {
    try {
      final doc = await _driversCollection.doc(firestoreId).get();
      if (!doc.exists) return;
      final docData = doc.data() as Map<String, dynamic>? ?? {};
      final sqliteId = docData['sqliteId'] as int?;
      if (sqliteId != null) {
        final backendData = <String, dynamic>{};
        if (data.containsKey('firstName')) {
          backendData['first_name'] = data['firstName'];
        }
        if (data.containsKey('lastName')) {
          backendData['last_name'] = data['lastName'];
        }
        if (data.containsKey('phone')) backendData['phone'] = data['phone'];
        if (data.containsKey('email')) backendData['email'] = data['email'];
        if (data.containsKey('status')) backendData['status'] = data['status'];
        if (backendData.isNotEmpty) {
          await DispatchApiService.updateUser(sqliteId, backendData);
        }
      }
    } catch (e) {
      debugPrint('[DriverService] Backend edit sync failed: $e');
    }
  }

  /// Delete a driver — also removes from 'users' collection and backend
  Future<void> deleteDriver(String driverId) async {
    int? sqliteId;
    final driverDoc = await _driversCollection.doc(driverId).get();
    if (driverDoc.exists) {
      final data = driverDoc.data() as Map<String, dynamic>? ?? {};
      sqliteId = data['sqliteId'] as int?;
      final phone = data['phone'] as String? ?? '';
      final userDoc = await _usersCollection.doc(driverId).get();
      if (userDoc.exists) {
        await _usersCollection.doc(driverId).delete();
      } else if (phone.isNotEmpty) {
        final snap = await _usersCollection
            .where('phone', isEqualTo: phone)
            .limit(1)
            .get();
        for (final doc in snap.docs) {
          await _usersCollection.doc(doc.id).delete();
        }
      }
    }
    await _driversCollection.doc(driverId).delete();
    // Sync delete to backend
    if (sqliteId != null) {
      try {
        await DispatchApiService.deleteUser(sqliteId);
      } catch (e) {
        debugPrint('[DriverService] Backend delete sync failed: $e');
      }
    }
  }

  /// Sync status change to the 'users' collection
  Future<void> _syncStatusToUsers(String driverId, String status) async {
    final userDoc = await _usersCollection.doc(driverId).get();
    if (userDoc.exists) {
      await _usersCollection.doc(driverId).update({
        'status': status,
        'lastUpdated': FieldValue.serverTimestamp(),
      });
      return;
    }
    final driverDoc = await _driversCollection.doc(driverId).get();
    if (!driverDoc.exists) return;
    final data = driverDoc.data() as Map<String, dynamic>? ?? {};
    final phone = data['phone'] as String? ?? '';
    if (phone.isEmpty) return;
    final snap = await _usersCollection
        .where('phone', isEqualTo: phone)
        .limit(1)
        .get();
    for (final doc in snap.docs) {
      await _usersCollection.doc(doc.id).update({
        'status': status,
        'lastUpdated': FieldValue.serverTimestamp(),
      });
    }
  }

  /// Get blocked drivers
  Future<QuerySnapshot> getBlockedDrivers() async {
    return await _driversCollection
        .where('status', isEqualTo: 'blocked')
        .orderBy('lastUpdated', descending: true)
        .get();
  }

  /// Get deactivated drivers
  Future<QuerySnapshot> getDeactivatedDrivers() async {
    return await _driversCollection
        .where('status', isEqualTo: 'deactivated')
        .orderBy('lastUpdated', descending: true)
        .get();
  }

  /// Get driver by ID
  Future<DriverModel?> getDriverById(String driverId) async {
    final doc = await _driversCollection.doc(driverId).get();
    if (doc.exists) return DriverModel.fromFirestore(doc);
    return null;
  }
}
