import 'package:flutter/material.dart';
import '../config/app_theme.dart';
import '../config/page_transitions.dart';
import '../models/client_model.dart';
import '../models/driver_model.dart';
import '../services/client_service.dart';
import '../services/driver_service.dart';
import 'user_detail_page.dart';

/// Screen for managing blocked/deleted drivers and riders.
/// Provides a centralized place to view and restore banned users.
class BlockedUsersScreen extends StatefulWidget {
  const BlockedUsersScreen({super.key});

  @override
  State<BlockedUsersScreen> createState() => _BlockedUsersScreenState();
}

class _BlockedUsersScreenState extends State<BlockedUsersScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _driverService = DriverService();
  final _clientService = ClientService();

  List<DriverModel> _blockedDrivers = [];
  List<ClientModel> _blockedRiders = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadBlockedUsers();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadBlockedUsers() async {
    setState(() => _loading = true);
    try {
      // Get blocked drivers
      final driversSnapshot = await _driverService.getBlockedDrivers();
      final drivers = driversSnapshot.docs
          .map((d) => DriverModel.fromFirestore(d))
          .toList();

      // Get blocked riders (clients with 'blocked' status)
      final ridersSnapshot = await _clientService.getBlockedClients();
      final riders = ridersSnapshot.docs
          .map((d) => ClientModel.fromFirestore(d))
          .toList();

      setState(() {
        _blockedDrivers = drivers;
        _blockedRiders = riders;
        _loading = false;
      });
    } catch (e) {
      debugPrint('Error loading blocked users: $e');
      setState(() => _loading = false);
    }
  }

  Future<void> _unblockDriver(DriverModel driver) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Unblock Driver?'),
        content: Text(
          'Are you sure you want to unblock ${driver.fullName}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.success,
            ),
            child: const Text('Unblock'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _driverService.updateStatus(driver.driverId, 'active');
        _loadBlockedUsers();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${driver.fullName} has been unblocked'),
              backgroundColor: AppColors.success,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error: $e'),
              backgroundColor: AppColors.error,
            ),
          );
        }
      }
    }
  }

  Future<void> _unblockRider(ClientModel rider) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Unblock Rider?'),
        content: Text(
          'Are you sure you want to unblock ${rider.fullName}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.success,
            ),
            child: const Text('Unblock'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _clientService.updateStatus(rider.clientId, 'active');
        _loadBlockedUsers();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${rider.fullName} has been unblocked'),
              backgroundColor: AppColors.success,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error: $e'),
              backgroundColor: AppColors.error,
            ),
          );
        }
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
        title: const Text(
          'Blocked Users',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: AppColors.primary),
            onPressed: _loadBlockedUsers,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textSecondary,
          indicatorColor: AppColors.primary,
          tabs: [
            Tab(
              icon: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.local_taxi, size: 18),
                  const SizedBox(width: 8),
                  Text('Drivers (${_blockedDrivers.length})'),
                ],
              ),
            ),
            Tab(
              icon: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.person, size: 18),
                  const SizedBox(width: 8),
                  Text('Riders (${_blockedRiders.length})'),
                ],
              ),
            ),
          ],
        ),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            )
          : TabBarView(
              controller: _tabController,
              children: [
                _buildDriversList(),
                _buildRidersList(),
              ],
            ),
    );
  }

  Widget _buildDriversList() {
    if (_blockedDrivers.isEmpty) {
      return _buildEmptyState(
        'No blocked drivers',
        'All drivers are currently active',
        Icons.local_taxi,
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _blockedDrivers.length,
      itemBuilder: (context, index) {
        final driver = _blockedDrivers[index];
        return _BlockedUserCard(
          name: driver.fullName,
          phone: driver.phone,
          email: driver.email,
          photoUrl: driver.photoUrl,
          blockedAt: driver.lastUpdated,
          onUnblock: () => _unblockDriver(driver),
          onTap: () => Navigator.push(
            context,
            slideFromRightRoute(UserDetailPage(driver: driver)),
          ),
        );
      },
    );
  }

  Widget _buildRidersList() {
    if (_blockedRiders.isEmpty) {
      return _buildEmptyState(
        'No blocked riders',
        'All riders are currently active',
        Icons.person,
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _blockedRiders.length,
      itemBuilder: (context, index) {
        final rider = _blockedRiders[index];
        return _BlockedUserCard(
          name: rider.fullName,
          phone: rider.phone,
          email: rider.email,
          photoUrl: rider.photoUrl,
          blockedAt: rider.lastUpdated,
          onUnblock: () => _unblockRider(rider),
          onTap: () => Navigator.push(
            context,
            slideFromRightRoute(UserDetailPage(client: rider)),
          ),
        );
      },
    );
  }

  Widget _buildEmptyState(String title, String subtitle, IconData icon) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: AppColors.surface,
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              size: 40,
              color: AppColors.textHint,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}

class _BlockedUserCard extends StatelessWidget {
  final String name;
  final String phone;
  final String? email;
  final String? photoUrl;
  final DateTime? blockedAt;
  final VoidCallback onUnblock;
  final VoidCallback onTap;

  const _BlockedUserCard({
    required this.name,
    required this.phone,
    this.email,
    this.photoUrl,
    this.blockedAt,
    required this.onUnblock,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: AppColors.error.withValues(alpha: 0.3)),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Stack(
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: AppColors.error.withValues(alpha: 0.1),
                    backgroundImage: photoUrl != null && photoUrl!.isNotEmpty
                        ? NetworkImage(photoUrl!)
                        : null,
                    child: photoUrl == null || photoUrl!.isEmpty
                        ? Icon(
                            Icons.block,
                            color: AppColors.error,
                            size: 24,
                          )
                        : null,
                  ),
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Container(
                      width: 16,
                      height: 16,
                      decoration: BoxDecoration(
                        color: AppColors.error,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: AppColors.surface,
                          width: 2,
                        ),
                      ),
                      child: const Icon(
                        Icons.block,
                        color: Colors.white,
                        size: 10,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      phone,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                    if (email != null && email!.isNotEmpty)
                      Text(
                        email!,
                        style: const TextStyle(
                          color: AppColors.textHint,
                          fontSize: 12,
                        ),
                      ),
                    if (blockedAt != null)
                      Text(
                        'Blocked: ${_formatDate(blockedAt!)}',
                        style: TextStyle(
                          color: AppColors.error.withValues(alpha: 0.7),
                          fontSize: 11,
                        ),
                      ),
                  ],
                ),
              ),
              ElevatedButton.icon(
                onPressed: onUnblock,
                icon: const Icon(Icons.check_circle, size: 16),
                label: const Text('Unblock'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.success,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.month}/${date.day}/${date.year}';
  }
}
