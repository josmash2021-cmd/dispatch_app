import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/client_model.dart';
import '../services/audit_service.dart';
import '../services/client_service.dart';
import '../services/dispatch_api_service.dart';

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
  int _retryCount = 0;
  Timer? _retryTimer;

  int get totalClients => _clients.length;
  int get verifiedClients => _clients.where((c) => c.isVerified).length;
  List<ClientModel> get filteredClients => _filteredClients;
  List<ClientModel> get allClients => _clients;

  /// Start listening to real-time client updates
  void startListening() {
    _isLoading = _clients.isEmpty;
    _errorMessage = null;
    if (_isLoading) notifyListeners();

    _subscription?.cancel();
    _retryTimer?.cancel();
    _subscription = _service.getClientsStream().listen(
      (clients) {
        _clients = clients;
        _isLoading = false;
        _errorMessage = null;
        _retryCount = 0;
        notifyListeners();
      },
      onError: (error) {
        debugPrint('[ClientProvider] stream error: $error');
        _isLoading = false;
        _errorMessage = 'Error al cargar clientes';
        notifyListeners();
        _scheduleRetry();
      },
    );
  }

  void _scheduleRetry() {
    _retryTimer?.cancel();
    final delay = Duration(seconds: _retryCount < 3 ? 3 * (1 << _retryCount) : 30);
    _retryCount++;
    debugPrint('[ClientProvider] retry in ${delay.inSeconds}s (attempt $_retryCount)');
    _retryTimer = Timer(delay, () {
      if (DispatchApiService.isOnline) _retryCount = 0;
      startListening();
    });
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

  Future<void> updateClient(
    String clientId,
    Map<String, dynamic> data, {
    String? clientName,
  }) async {
    try {
      await _service.updateClient(clientId, {
        ...data,
        'lastUpdated': DateTime.now(),
      });
      await _audit.logUpdate(
        'clients',
        clientId,
        '${clientName ?? clientId} edited',
      );
    } catch (e) {
      _errorMessage = 'Error updating client: $e';
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
    _retryTimer?.cancel();
    super.dispose();
  }
}
