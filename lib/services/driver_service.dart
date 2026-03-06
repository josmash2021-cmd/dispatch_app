import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/driver_model.dart';

class DriverService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference get _driversCollection =>
      _firestore.collection('drivers');

  CollectionReference get _usersCollection => _firestore.collection('users');

  /// Real-time stream merging 'drivers' and driver-role docs from 'users'
  Stream<List<DriverModel>> getDriversStream() {
    final driversStream = _driversCollection
        .orderBy('isOnline', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => DriverModel.fromFirestore(doc))
              .toList(),
        );

    final usersStream = _usersCollection
        .where('role', isEqualTo: 'driver')
        .snapshots()
        .handleError((_) => <DriverModel>[])
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => DriverModel.fromFirestore(doc))
              .toList(),
        );

    return driversStream.asyncExpand((drivers) {
      return usersStream.map((userDrivers) {
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
        // Online first, then by name
        merged.sort((a, b) {
          if (a.isOnline != b.isOnline) return a.isOnline ? -1 : 1;
          return a.fullName.compareTo(b.fullName);
        });
        return merged;
      });
    });
  }

  /// One-time fetch of all drivers
  Future<List<DriverModel>> getDriversList() async {
    final snapshot = await _driversCollection
        .orderBy('isOnline', descending: true)
        .get();
    return snapshot.docs.map((doc) => DriverModel.fromFirestore(doc)).toList();
  }

  /// Add a driver manually from dispatch
  Future<String> addDriver(DriverModel driver) async {
    final data = driver.toMap();
    data['createdAt'] = FieldValue.serverTimestamp();
    final docRef = await _driversCollection.add(data);
    return docRef.id;
  }

  /// Update driver online status
  Future<void> setOnlineStatus(String driverId, bool isOnline) async {
    await _driversCollection.doc(driverId).update({
      'isOnline': isOnline,
      'lastSeen': FieldValue.serverTimestamp(),
    });
  }

  /// Update driver status (active / inactive / blocked)
  Future<void> updateStatus(String driverId, String status) async {
    await _driversCollection.doc(driverId).update({'status': status});
  }

  /// Update driver fields
  Future<void> updateDriver(String driverId, Map<String, dynamic> data) async {
    await _driversCollection.doc(driverId).update(data);
  }

  /// Delete a driver
  Future<void> deleteDriver(String driverId) async {
    await _driversCollection.doc(driverId).delete();
  }

  /// Get driver by ID
  Future<DriverModel?> getDriverById(String driverId) async {
    final doc = await _driversCollection.doc(driverId).get();
    if (doc.exists) return DriverModel.fromFirestore(doc);
    return null;
  }
}
