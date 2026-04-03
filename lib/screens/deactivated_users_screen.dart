import 'package:flutter/material.dart';
import '../config/app_theme.dart';
import '../config/page_transitions.dart';
import '../models/client_model.dart';
import '../models/driver_model.dart';
import '../services/client_service.dart';
import '../services/driver_service.dart';
import 'user_detail_page.dart';

/// Screen for managing deactivated drivers and riders.
class DeactivatedUsersScreen extends StatefulWidget {
  final String roleFilter; // 'rider', 'driver', or '' for all
  const DeactivatedUsersScreen({super.key, this.roleFilter = ''});

  @override
  State<DeactivatedUsersScreen> createState() => _DeactivatedUsersScreenState();
}

class _DeactivatedUsersScreenState extends State<DeactivatedUsersScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _driverService = DriverService();
  final _clientService = ClientService();

  List<DriverModel> _deactivatedDrivers = [];
  List<ClientModel> _deactivatedRiders = [];
  bool _loading = true;

  bool get _showRiders => widget.roleFilter.isEmpty || widget.roleFilter == 'rider';
  bool get _showDrivers => widget.roleFilter.isEmpty || widget.roleFilter == 'driver';
  int get _tabCount => (_showRiders && _showDrivers) ? 2 : 1;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabCount, vsync: this);
    _loadDeactivatedUsers();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadDeactivatedUsers() async {
    setState(() => _loading = true);
    try {
      final driversSnapshot = await _driverService.getDeactivatedDrivers();
      final drivers = driversSnapshot.docs
          .map((d) => DriverModel.fromFirestore(d))
          .toList();

      final ridersSnapshot = await _clientService.getDeactivatedClients();
      final riders = ridersSnapshot.docs
          .map((d) => ClientModel.fromFirestore(d))
          .toList();

      setState(() {
        _deactivatedDrivers = drivers;
        _deactivatedRiders = riders;
        _loading = false;
      });
    } catch (e) {
      debugPrint('Error loading deactivated users: $e');
      setState(() => _loading = false);
    }
  }

  Future<void> _reactivateDriver(DriverModel driver) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Reactivar Driver?'),
        content: Text(
          '¿Estás seguro de que quieres reactivar a ${driver.fullName}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.success,
            ),
            child: const Text('Reactivar'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await _driverService.updateStatus(driver.driverId, 'active');
      _loadDeactivatedUsers();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${driver.fullName} ha sido reactivado'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    }
  }

  Future<void> _reactivateRider(ClientModel rider) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Reactivar Rider?'),
        content: Text(
          '¿Estás seguro de que quieres reactivar a ${rider.fullName}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.success,
            ),
            child: const Text('Reactivar'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await _clientService.updateStatus(rider.clientId, 'active');
      _loadDeactivatedUsers();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${rider.fullName} ha sido reactivado'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppColors.primary),
          onPressed: () => Navigator.pop(context),
        ),
        elevation: 0,
        title: Text(
          widget.roleFilter == 'rider'
              ? 'Riders Desactivados'
              : widget.roleFilter == 'driver'
                  ? 'Drivers Desactivados'
                  : 'Usuarios Desactivados',
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: AppColors.primary),
            onPressed: _loadDeactivatedUsers,
          ),
        ],
        bottom: _tabCount > 1
            ? TabBar(
                controller: _tabController,
                indicatorColor: AppColors.primary,
                labelColor: AppColors.primary,
                unselectedLabelColor: AppColors.textSecondary,
                tabs: [
                  if (_showDrivers)
                    Tab(
                      text: 'Drivers (${_deactivatedDrivers.length})',
                      icon: const Icon(Icons.local_taxi, size: 20),
                    ),
                  if (_showRiders)
                    Tab(
                      text: 'Riders (${_deactivatedRiders.length})',
                      icon: const Icon(Icons.person, size: 20),
                    ),
                ],
              )
            : null,
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            )
          : _tabCount > 1
              ? TabBarView(
                  controller: _tabController,
                  children: [
                    if (_showDrivers) _buildDriversList(),
                    if (_showRiders) _buildRidersList(),
                  ],
                )
              : _showDrivers
                  ? _buildDriversList()
                  : _buildRidersList(),
    );
  }

  Widget _buildDriversList() {
    if (_deactivatedDrivers.isEmpty) {
      return _buildEmptyState('No hay drivers desactivados', Icons.local_taxi);
    }
    return RefreshIndicator(
      onRefresh: _loadDeactivatedUsers,
      color: AppColors.primary,
      child: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: _deactivatedDrivers.length,
        itemBuilder: (context, i) => _buildDriverCard(_deactivatedDrivers[i]),
      ),
    );
  }

  Widget _buildRidersList() {
    if (_deactivatedRiders.isEmpty) {
      return _buildEmptyState('No hay riders desactivados', Icons.person);
    }
    return RefreshIndicator(
      onRefresh: _loadDeactivatedUsers,
      color: AppColors.primary,
      child: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: _deactivatedRiders.length,
        itemBuilder: (context, i) => _buildRiderCard(_deactivatedRiders[i]),
      ),
    );
  }

  Widget _buildEmptyState(String message, IconData icon) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 56, color: AppColors.textHint),
          const SizedBox(height: 12),
          Text(
            message,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDriverCard(DriverModel driver) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        leading: CircleAvatar(
          radius: 24,
          backgroundColor: AppColors.warning.withValues(alpha: 0.15),
          child: Text(
            driver.fullName.isNotEmpty ? driver.fullName[0].toUpperCase() : '?',
            style: const TextStyle(
              color: AppColors.warning,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        title: Text(
          driver.fullName,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              driver.phone,
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
            Container(
              margin: const EdgeInsets.only(top: 4),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.warning.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                'DESACTIVADO',
                style: TextStyle(
                  color: AppColors.warning,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.restore, color: AppColors.success, size: 22),
              tooltip: 'Reactivar',
              onPressed: () => _reactivateDriver(driver),
            ),
            IconButton(
              icon: const Icon(Icons.info_outline, color: AppColors.primary, size: 22),
              tooltip: 'Ver detalles',
              onPressed: () => Navigator.push(
                context,
                slideFromRightRoute(UserDetailPage(driver: driver)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRiderCard(ClientModel rider) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        leading: CircleAvatar(
          radius: 24,
          backgroundColor: AppColors.warning.withValues(alpha: 0.15),
          child: Text(
            rider.fullName.isNotEmpty ? rider.fullName[0].toUpperCase() : '?',
            style: const TextStyle(
              color: AppColors.warning,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        title: Text(
          rider.fullName,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              rider.phone,
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
            Container(
              margin: const EdgeInsets.only(top: 4),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.warning.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                'DESACTIVADO',
                style: TextStyle(
                  color: AppColors.warning,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.restore, color: AppColors.success, size: 22),
              tooltip: 'Reactivar',
              onPressed: () => _reactivateRider(rider),
            ),
            IconButton(
              icon: const Icon(Icons.info_outline, color: AppColors.primary, size: 22),
              tooltip: 'Ver detalles',
              onPressed: () => Navigator.push(
                context,
                slideFromRightRoute(UserDetailPage(client: rider)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
