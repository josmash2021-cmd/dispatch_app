import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/client_model.dart';
import '../services/audit_service.dart';
import '../services/client_service.dart';

class ClientProvider extends ChangeNotifier {
  final ClientService _service = ClientService();
  final AuditService _audit = AuditService();

  List<ClientModel> _clients = [];
  List<ClientModel> get clients => _filteredClients;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  String _searchQuery = '';
  String get searchQuery => _searchQuery;

  StreamSubscription? _subscription;

  int get totalClients => _clients.length;

  /// Start listening to real-time client updates
  void startListening() {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    _subscription?.cancel();
    _subscription = _service.getClientsStream().listen(
      (clients) {
        _clients = clients;
        _isLoading = false;
        _errorMessage = null;
        notifyListeners();
      },
      onError: (error) {
        _errorMessage = 'Error loading clients: $error';
        _isLoading = false;
        notifyListeners();
      },
    );
  }

  List<ClientModel> get _filteredClients {
    if (_searchQuery.isEmpty) return _clients;
    final q = _searchQuery.toLowerCase();
    return _clients.where((c) {
      return c.fullName.toLowerCase().contains(q) ||
          c.phone.toLowerCase().contains(q) ||
          (c.email?.toLowerCase().contains(q) ?? false);
    }).toList();
  }

  void setSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  Future<void> addClient(ClientModel client) async {
    try {
      final id = await _service.addClient(client);
      await _audit.logCreate('clients', id, client.fullName);
    } catch (e) {
      _errorMessage = 'Error adding client: $e';
      notifyListeners();
    }
  }

  Future<void> deleteClient(String clientId, {String? clientName}) async {
    try {
      await _service.deleteClient(clientId);
      await _audit.logDelete('clients', clientId, clientName ?? clientId);
    } catch (e) {
      _errorMessage = 'Error deleting client: $e';
      notifyListeners();
    }
  }

  /// Change client status: 'active', 'inactive', 'blocked'
  Future<void> updateClientStatus(
    String clientId,
    String newStatus, {
    String? clientName,
  }) async {
    try {
      await _service.updateStatus(clientId, newStatus);
      await _audit.logUpdate(
        'clients',
        clientId,
        '${clientName ?? clientId} → $newStatus',
      );
    } catch (e) {
      _errorMessage = 'Error updating client status: $e';
      notifyListeners();
    }
  }

  Future<void> refreshClients() async {
    _isLoading = true;
    notifyListeners();
    try {
      _clients = await _service.getClientsList();
      _errorMessage = null;
    } catch (e) {
      _errorMessage = 'Error refreshing clients: $e';
    }
    _isLoading = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
