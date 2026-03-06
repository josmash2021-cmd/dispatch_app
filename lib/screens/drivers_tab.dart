import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../config/app_theme.dart';
import '../models/driver_model.dart';
import '../providers/driver_provider.dart';
import '../widgets/animated_list_item.dart';
import '../widgets/re_auth_dialog.dart';
import '../widgets/shimmer_loading.dart';

class DriversTab extends StatefulWidget {
  const DriversTab({super.key});
  @override
  State<DriversTab> createState() => _DriversTabState();
}

class _DriversTabState extends State<DriversTab> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<DriverProvider>();
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: TextField(
            controller: _searchController,
            onChanged: provider.setSearchQuery,
            style: const TextStyle(color: AppColors.textPrimary),
            decoration: InputDecoration(
              hintText: 'Search by name, phone, plate...',
              hintStyle: const TextStyle(color: AppColors.textHint),
              prefixIcon: const Icon(
                Icons.search_rounded,
                color: AppColors.textHint,
              ),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(
                        Icons.clear_rounded,
                        color: AppColors.textHint,
                      ),
                      onPressed: () {
                        _searchController.clear();
                        provider.setSearchQuery('');
                      },
                    )
                  : null,
              filled: true,
              fillColor: AppColors.surfaceHigh,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Row(
            children: [
              _countChip('Total', provider.totalDrivers, AppColors.primary),
              const SizedBox(width: 8),
              _countChip('Online', provider.onlineDrivers, AppColors.success),
              const SizedBox(width: 8),
              _countChip(
                'Offline',
                provider.offlineDrivers,
                AppColors.textSecondary,
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        Expanded(child: _buildBody(provider)),
      ],
    );
  }

  Widget _countChip(String label, int count, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        '$label: $count',
        style: TextStyle(
          fontSize: 12,
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildBody(DriverProvider provider) {
    if (provider.isLoading) {
      return const ShimmerLoadingList(itemCount: 5, type: ShimmerType.person);
    }
    if (provider.errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.wifi_off_rounded,
              size: 52,
              color: AppColors.textHint,
            ),
            const SizedBox(height: 12),
            Text(
              provider.errorMessage!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: provider.refreshDrivers,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }
    if (provider.drivers.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.directions_car_outlined,
              size: 56,
              color: AppColors.textHint,
            ),
            const SizedBox(height: 12),
            Text(
              provider.searchQuery.isNotEmpty
                  ? 'No drivers match your search'
                  : 'No drivers registered yet',
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 16,
              ),
            ),
          ],
        ),
      );
    }
    return RefreshIndicator(
      color: AppColors.primary,
      backgroundColor: AppColors.surface,
      onRefresh: provider.refreshDrivers,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
        itemCount: provider.drivers.length,
        itemBuilder: (context, i) => AnimatedListItem(
          index: i,
          child: _DriverCard(driver: provider.drivers[i]),
        ),
      ),
    );
  }
}

// ─── Status helpers ─────────────────────────────────────────────────────────

Color _statusColor(String status) {
  switch (status) {
    case 'active':
      return AppColors.success;
    case 'inactive':
      return AppColors.warning;
    case 'blocked':
      return AppColors.error;
    default:
      return AppColors.textHint;
  }
}

IconData _statusIcon(String status) {
  switch (status) {
    case 'active':
      return Icons.check_circle_rounded;
    case 'inactive':
      return Icons.pause_circle_filled_rounded;
    case 'blocked':
      return Icons.block_rounded;
    default:
      return Icons.help_outline_rounded;
  }
}

String _statusLabel(String status) {
  switch (status) {
    case 'active':
      return 'Active';
    case 'inactive':
      return 'Inactive';
    case 'blocked':
      return 'Blocked';
    default:
      return status;
  }
}

// ─── Driver Card ────────────────────────────────────────────────────────────

class _DriverCard extends StatelessWidget {
  final DriverModel driver;
  const _DriverCard({required this.driver});

  @override
  Widget build(BuildContext context) {
    final acctColor = _statusColor(driver.status);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: driver.isBlocked
              ? AppColors.error.withValues(alpha: 0.30)
              : driver.isInactive
              ? AppColors.warning.withValues(alpha: 0.20)
              : AppColors.cardBorder,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => _showDriverDetail(context, driver),
          onLongPress: () => _showActions(context, driver),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                // Avatar with status + online indicator
                Stack(
                  children: [
                    Opacity(
                      opacity: driver.isBlocked
                          ? 0.45
                          : driver.isInactive
                          ? 0.6
                          : 1.0,
                      child: CircleAvatar(
                        radius: 24,
                        backgroundColor: AppColors.primary.withValues(
                          alpha: 0.15,
                        ),
                        backgroundImage: driver.photoUrl != null
                            ? NetworkImage(driver.photoUrl!)
                            : null,
                        child: driver.photoUrl == null
                            ? Text(
                                driver.fullName.isNotEmpty
                                    ? driver.fullName[0].toUpperCase()
                                    : '?',
                                style: const TextStyle(
                                  color: AppColors.primary,
                                  fontSize: 20,
                                  fontWeight: FontWeight.w700,
                                ),
                              )
                            : null,
                      ),
                    ),
                    // Online dot (top-right)
                    Positioned(
                      right: 0,
                      top: 0,
                      child: Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: driver.isOnline
                              ? AppColors.success
                              : AppColors.textHint,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: AppColors.surface,
                            width: 2,
                          ),
                        ),
                      ),
                    ),
                    // Account status (bottom-right)
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: Container(
                        width: 14,
                        height: 14,
                        decoration: BoxDecoration(
                          color: acctColor,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: AppColors.surface,
                            width: 2,
                          ),
                        ),
                        child: Icon(
                          _statusIcon(driver.status),
                          size: 8,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              driver.fullName.isNotEmpty
                                  ? driver.fullName
                                  : 'Unknown',
                              style: TextStyle(
                                color: driver.isBlocked
                                    ? AppColors.textSecondary
                                    : AppColors.textPrimary,
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                decoration: driver.isBlocked
                                    ? TextDecoration.lineThrough
                                    : null,
                              ),
                            ),
                          ),
                          // Account status badge
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: acctColor.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              _statusLabel(driver.status),
                              style: TextStyle(
                                fontSize: 10,
                                color: acctColor,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          const Icon(
                            Icons.phone_outlined,
                            size: 13,
                            color: AppColors.textHint,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            driver.phone.isNotEmpty ? driver.phone : 'No phone',
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                      if (driver.vehicleType != null ||
                          driver.vehiclePlate != null) ...[
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            const Icon(
                              Icons.directions_car_outlined,
                              size: 13,
                              color: AppColors.textHint,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              [driver.vehicleType, driver.vehiclePlate]
                                  .where((e) => e != null && e.isNotEmpty)
                                  .join(' · '),
                              style: const TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                // Quick actions
                IconButton(
                  icon: const Icon(
                    Icons.more_vert_rounded,
                    color: AppColors.textHint,
                    size: 20,
                  ),
                  onPressed: () => _showActions(context, driver),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 32,
                    minHeight: 32,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ─── Actions Bottom Sheet ───────────────────────────────────────────────

  void _showActions(BuildContext context, DriverModel driver) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.cardBorder,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Icon(
                    _statusIcon(driver.status),
                    color: _statusColor(driver.status),
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      driver.fullName,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: _statusColor(
                        driver.status,
                      ).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      _statusLabel(driver.status),
                      style: TextStyle(
                        fontSize: 12,
                        color: _statusColor(driver.status),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              if (!driver.isActive)
                _actionTile(
                  icon: Icons.check_circle_outline_rounded,
                  label: 'Activate',
                  subtitle: 'Restore full access',
                  color: AppColors.success,
                  onTap: () {
                    Navigator.pop(ctx);
                    _changeStatus(context, driver, 'active');
                  },
                ),
              if (!driver.isInactive)
                _actionTile(
                  icon: Icons.pause_circle_outline_rounded,
                  label: 'Deactivate',
                  subtitle: 'Temporarily suspend',
                  color: AppColors.warning,
                  onTap: () {
                    Navigator.pop(ctx);
                    _changeStatus(context, driver, 'inactive');
                  },
                ),
              if (!driver.isBlocked)
                _actionTile(
                  icon: Icons.block_rounded,
                  label: 'Block',
                  subtitle: 'Permanently deny access',
                  color: AppColors.error,
                  onTap: () {
                    Navigator.pop(ctx);
                    _changeStatus(context, driver, 'blocked');
                  },
                ),
              const Divider(color: AppColors.cardBorder, height: 24),
              _actionTile(
                icon: Icons.delete_forever_rounded,
                label: 'Delete permanently',
                subtitle: 'Remove from database',
                color: AppColors.error,
                onTap: () {
                  Navigator.pop(ctx);
                  _confirmDelete(context, driver);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _actionTile({
    required IconData icon,
    required String label,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: color, size: 22),
      ),
      title: Text(
        label,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w600,
          fontSize: 15,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: const TextStyle(color: AppColors.textHint, fontSize: 12),
      ),
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    );
  }

  // ─── Change Status ──────────────────────────────────────────────────────

  void _changeStatus(
    BuildContext context,
    DriverModel driver,
    String newStatus,
  ) {
    final action = _statusLabel(newStatus);
    final color = _statusColor(newStatus);
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(_statusIcon(newStatus), color: color, size: 22),
            const SizedBox(width: 8),
            Text(
              '$action Driver',
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 18,
              ),
            ),
          ],
        ),
        content: Text(
          'Change ${driver.fullName} status to "$action"?',
          style: const TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(dialogCtx);
              context.read<DriverProvider>().updateDriverStatus(
                driver.driverId,
                newStatus,
                driverName: driver.fullName,
              );
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  backgroundColor: AppColors.surfaceHigh,
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  content: Row(
                    children: [
                      Icon(_statusIcon(newStatus), color: color, size: 18),
                      const SizedBox(width: 8),
                      Text(
                        '${driver.fullName} → $action',
                        style: const TextStyle(color: AppColors.textPrimary),
                      ),
                    ],
                  ),
                ),
              );
            },
            child: Text(
              action,
              style: TextStyle(color: color, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Detail Bottom Sheet ────────────────────────────────────────────────

  void _showDriverDetail(BuildContext context, DriverModel driver) {
    final dateFmt = DateFormat('MMM d, yyyy · h:mm a');
    final acctColor = _statusColor(driver.status);
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.85,
        maxChildSize: 0.95,
        minChildSize: 0.5,
        expand: false,
        builder: (_, scrollCtrl) => Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
          child: ListView(
            controller: scrollCtrl,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.cardBorder,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Center(
                child: Stack(
                  children: [
                    CircleAvatar(
                      radius: 36,
                      backgroundColor:
                          AppColors.primary.withValues(alpha: 0.15),
                      backgroundImage: driver.photoUrl != null
                          ? NetworkImage(driver.photoUrl!)
                          : null,
                      child: driver.photoUrl == null
                          ? Text(
                              driver.fullName.isNotEmpty
                                  ? driver.fullName[0].toUpperCase()
                                  : '?',
                              style: const TextStyle(
                                color: AppColors.primary,
                                fontSize: 28,
                                fontWeight: FontWeight.w700,
                              ),
                            )
                          : null,
                    ),
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: Container(
                        width: 18,
                        height: 18,
                        decoration: BoxDecoration(
                          color: acctColor,
                          shape: BoxShape.circle,
                          border:
                              Border.all(color: AppColors.surface, width: 3),
                        ),
                      ),
                    ),
                    Positioned(
                      right: 0,
                      top: 0,
                      child: Container(
                        width: 16,
                        height: 16,
                        decoration: BoxDecoration(
                          color: driver.isOnline
                              ? AppColors.success
                              : AppColors.textHint,
                          shape: BoxShape.circle,
                          border:
                              Border.all(color: AppColors.surface, width: 3),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Center(
                child: Text(
                  driver.fullName,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Center(
                child: Wrap(
                  spacing: 8,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: (driver.isOnline
                                    ? AppColors.success
                                    : AppColors.textHint)
                                .withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        driver.isOnline ? 'Online' : 'Offline',
                        style: TextStyle(
                          fontSize: 13,
                          color: driver.isOnline
                              ? AppColors.success
                              : AppColors.textHint,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: acctColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(_statusIcon(driver.status),
                              color: acctColor, size: 14),
                          const SizedBox(width: 4),
                          Text(
                            _statusLabel(driver.status),
                            style: TextStyle(
                              fontSize: 13,
                              color: acctColor,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (driver.source != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.textHint.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          driver.source!,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                  ],
                ),
              ),

              // ── Contact Info ──
              const SizedBox(height: 20),
              _sectionHeader('Contact Info'),
              _detailRow(Icons.phone_outlined, 'Phone',
                  driver.phone.isNotEmpty ? driver.phone : 'Not set'),
              _detailRow(Icons.email_outlined, 'Email',
                  driver.email ?? 'Not set'),
              if (driver.photoUrl != null)
                _detailRow(Icons.image_outlined, 'Photo URL', 'Set'),

              // ── Account Details ──
              const SizedBox(height: 16),
              _sectionHeader('Account Details'),
              _detailRow(Icons.badge_outlined, 'Driver ID', driver.driverId),
              if (driver.sqliteId != null)
                _detailRow(Icons.storage_outlined, 'SQLite ID',
                    '${driver.sqliteId}'),
              _detailRow(Icons.person_outline, 'Role', driver.role),
              _detailRow(
                Icons.lock_outlined,
                'Password',
                driver.hasPassword ? 'Set' : 'Not set',
              ),
              if (driver.passwordHash != null &&
                  driver.passwordHash!.isNotEmpty)
                _detailRow(
                  Icons.fingerprint_rounded,
                  'Password Hash',
                  '${driver.passwordHash!.substring(0, (driver.passwordHash!.length > 20 ? 20 : driver.passwordHash!.length))}...',
                ),

              // ── Vehicle Info ──
              const SizedBox(height: 16),
              _sectionHeader('Vehicle Info'),
              _detailRow(Icons.directions_car_outlined, 'Vehicle',
                  driver.vehicleType ?? 'Not set'),
              _detailRow(Icons.confirmation_number_outlined, 'Plate',
                  driver.vehiclePlate ?? 'Not set'),

              // ── Location / GPS ──
              const SizedBox(height: 16),
              _sectionHeader('Location'),
              _detailRow(Icons.gps_fixed_rounded, 'GPS Status',
                  driver.isOnline ? 'Active' : 'Inactive'),
              if (driver.lat != null && driver.lng != null)
                _detailRow(Icons.location_on_outlined, 'Coordinates',
                    '${driver.lat!.toStringAsFixed(6)}, ${driver.lng!.toStringAsFixed(6)}'),
              if (driver.rating != null)
                _detailRow(Icons.star_rounded, 'Rating',
                    driver.rating!.toStringAsFixed(1)),

              // ── Timestamps ──
              const SizedBox(height: 16),
              _sectionHeader('Timestamps'),
              if (driver.createdAt != null)
                _detailRow(Icons.calendar_today_rounded, 'Registered',
                    dateFmt.format(driver.createdAt!)),
              if (driver.lastSeen != null)
                _detailRow(Icons.access_time_rounded, 'Last Seen',
                    timeago.format(driver.lastSeen!, locale: 'en')),
              if (driver.lastUpdated != null)
                _detailRow(Icons.update_rounded, 'Last Updated',
                    dateFmt.format(driver.lastUpdated!)),

              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    _showActions(context, driver);
                  },
                  icon: const Icon(Icons.settings_rounded, size: 18),
                  label: const Text('Manage Driver'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: const Color(0xFF1A1400),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Container(
            width: 3,
            height: 16,
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            title,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _detailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.textSecondary),
          const SizedBox(width: 12),
          Text(
            label,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 14,
            ),
          ),
          const Spacer(),
          Flexible(
            child: Text(
              value,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.end,
            ),
          ),
        ],
      ),
    );
  }

  // ─── Delete ─────────────────────────────────────────────────────────────

  void _confirmDelete(BuildContext context, DriverModel driver) {
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(
              Icons.delete_forever_rounded,
              color: AppColors.error,
              size: 22,
            ),
            SizedBox(width: 8),
            Text(
              'Delete Driver',
              style: TextStyle(color: AppColors.textPrimary, fontSize: 18),
            ),
          ],
        ),
        content: Text(
          'Permanently delete ${driver.fullName}? This cannot be undone.',
          style: const TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(dialogCtx);
              final confirmed = await showReAuthDialog(
                context,
                actionDescription:
                    'Deleting "${driver.fullName}" is permanent.',
              );
              if (confirmed && context.mounted) {
                context.read<DriverProvider>().deleteDriver(
                  driver.driverId,
                  driverName: driver.fullName,
                );
              }
            },
            child: const Text(
              'Delete',
              style: TextStyle(
                color: AppColors.error,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
