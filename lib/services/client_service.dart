import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/client_model.dart';

class ClientService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference get _clientsCollection =>
      _firestore.collection('clients');

  CollectionReference get _usersCollection => _firestore.collection('users');

  /// Real-time stream merging both 'clients' and 'users' collections.
  /// Uses combineLatest so ANY change in EITHER collection triggers an update.
  Stream<List<ClientModel>> getClientsStream() {
    final controller = StreamController<List<ClientModel>>();

    List<ClientModel>? lastClients;
    List<ClientModel>? lastUsers;

    void merge() {
      final clients = lastClients ?? [];
      final users = lastUsers ?? [];
      final clientIds = clients.map((c) => c.clientId).toSet();
      final clientPhones = clients
          .map((c) => c.phone)
          .where((p) => p.isNotEmpty)
          .toSet();
      final merged = [...clients];
      for (final user in users) {
        if (!clientIds.contains(user.clientId) &&
            !clientPhones.contains(user.phone)) {
          merged.add(user);
        }
      }
      merged.sort((a, b) {
        final aTime = a.createdAt ?? DateTime(2000);
        final bTime = b.createdAt ?? DateTime(2000);
        return bTime.compareTo(aTime);
      });
      controller.add(merged);
    }

    final sub1 = _clientsCollection
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((s) => s.docs.map((d) => ClientModel.fromFirestore(d)).toList())
        .listen((clients) {
          lastClients = clients;
          merge();
        }, onError: (e) => controller.addError(e));

    final sub2 = _usersCollection
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((s) => s.docs.map((d) => ClientModel.fromFirestore(d)).toList())
        .listen(
          (users) {
            lastUsers = users;
            if (lastClients != null) merge();
          },
          onError: (_) {
            lastUsers = [];
            if (lastClients != null) merge();
          },
        );

    controller.onCancel = () {
      sub1.cancel();
      sub2.cancel();
      controller.close();
    };

    return controller.stream;
  }

  /// One-time fetch of all clients
  Future<List<ClientModel>> getClientsList() async {
    final snapshot = await _clientsCollection
        .orderBy('createdAt', descending: true)
        .get();
    return snapshot.docs.map((doc) => ClientModel.fromFirestore(doc)).toList();
  }

  /// Add a new client
  Future<String> addClient(ClientModel client) async {
    final data = client.toMap();
    data['createdAt'] = FieldValue.serverTimestamp();
    final docRef = await _clientsCollection.add(data);
    return docRef.id;
  }

  /// Update a client
  Future<void> updateClient(String clientId, Map<String, dynamic> data) async {
    await _clientsCollection.doc(clientId).update(data);
  }

  /// Update client status (active / inactive / blocked)
  /// Also syncs to the 'users' collection so the Cruise app sees the change.
  Future<void> updateStatus(String clientId, String status) async {
    await _clientsCollection.doc(clientId).update({
      'status': status,
      'lastUpdated': FieldValue.serverTimestamp(),
    });
    // Sync to users collection (same docId or matched by phone)
    await _syncStatusToUsers(clientId, status);
  }

  /// Delete a client — also removes from 'users' collection
  Future<void> deleteClient(String clientId) async {
    // Try to find matching user doc
    final clientDoc = await _clientsCollection.doc(clientId).get();
    if (clientDoc.exists) {
      final data = clientDoc.data() as Map<String, dynamic>? ?? {};
      final phone = data['phone'] as String? ?? '';
      // Delete from users by same docId
      final userDoc = await _usersCollection.doc(clientId).get();
      if (userDoc.exists) {
        await _usersCollection.doc(clientId).delete();
      } else if (phone.isNotEmpty) {
        // Find by phone
        final snap = await _usersCollection
            .where('phone', isEqualTo: phone)
            .limit(1)
            .get();
        for (final doc in snap.docs) {
          await _usersCollection.doc(doc.id).delete();
        }
      }
    }
    await _clientsCollection.doc(clientId).delete();
  }

  /// Sync status change to the 'users' collection
  Future<void> _syncStatusToUsers(String clientId, String status) async {
    // Try same docId first
    final userDoc = await _usersCollection.doc(clientId).get();
    if (userDoc.exists) {
      await _usersCollection.doc(clientId).update({
        'status': status,
        'lastUpdated': FieldValue.serverTimestamp(),
      });
      return;
    }
    // Find by phone
    final clientDoc = await _clientsCollection.doc(clientId).get();
    if (!clientDoc.exists) return;
    final data = clientDoc.data() as Map<String, dynamic>? ?? {};
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

  /// Get client by ID
  Future<ClientModel?> getClientById(String clientId) async {
    final doc = await _clientsCollection.doc(clientId).get();
    if (doc.exists) return ClientModel.fromFirestore(doc);
    return null;
  }
}
