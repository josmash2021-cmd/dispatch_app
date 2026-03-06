import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/client_model.dart';

class ClientService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference get _clientsCollection =>
      _firestore.collection('clients');

  CollectionReference get _usersCollection => _firestore.collection('users');

  /// Real-time stream merging both 'clients' and 'users' collections
  Stream<List<ClientModel>> getClientsStream() {
    final clientsStream = _clientsCollection
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((s) => s.docs.map((d) => ClientModel.fromFirestore(d)).toList());

    final usersStream = _usersCollection
        .orderBy('createdAt', descending: true)
        .snapshots()
        .handleError((_) => <ClientModel>[])
        .map((s) => s.docs.map((d) => ClientModel.fromFirestore(d)).toList());

    // Merge both streams — deduplicate by phone or ID
    return clientsStream.asyncExpand((clients) {
      return usersStream.map((users) {
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
        return merged;
      });
    });
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
  Future<void> updateStatus(String clientId, String status) async {
    await _clientsCollection.doc(clientId).update({'status': status});
  }

  /// Delete a client
  Future<void> deleteClient(String clientId) async {
    await _clientsCollection.doc(clientId).delete();
  }

  /// Get client by ID
  Future<ClientModel?> getClientById(String clientId) async {
    final doc = await _clientsCollection.doc(clientId).get();
    if (doc.exists) return ClientModel.fromFirestore(doc);
    return null;
  }
}
