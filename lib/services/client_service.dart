import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/client_model.dart';

class ClientService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference get _clientsCollection =>
      _firestore.collection('clients');

  /// Real-time stream of all clients, most recent first
  Stream<List<ClientModel>> getClientsStream() {
    return _clientsCollection
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => ClientModel.fromFirestore(doc))
              .toList(),
        );
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
