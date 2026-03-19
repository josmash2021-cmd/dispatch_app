import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/app_theme.dart';
import '../config/page_transitions.dart';
import '../models/trip_model.dart';
import '../providers/auth_provider.dart';
import '../providers/trip_provider.dart';
import '../widgets/animated_list_item.dart';
import '../widgets/shimmer_loading.dart';
import '../widgets/status_filter_chips.dart';
import '../widgets/trip_card.dart';
import 'trip_detail_screen.dart';

class TripListScreen extends StatefulWidget {
  const TripListScreen({super.key});
  @override
  State<TripListScreen> createState() => _TripListScreenState();
}

class _TripListScreenState extends State<TripListScreen> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // ── Live badge ──────────────────────────────────────────────────────────
  Widget _liveBadge(int activeCount) {
    if (activeCount == 0) return const SizedBox.shrink();
    return _LiveBadge(count: activeCount);
  }

  @override
  Widget build(BuildContext context) {
    final trips = context.watch<TripProvider>();
    final auth = context.read<AuthProvider>();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppColors.primary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.local_taxi_rounded,
                color: Color(0xFF08090C),
                size: 18,
              ),
            ),
            const SizedBox(width: 10),
            const Text(
              'Trips',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(width: 10),
            _liveBadge(trips.activeCount),
          ],
        ),
        backgroundColor: AppColors.background,
        elevation: 0,
        actions: [
          PopupMenuButton<String>(
            onSelected: (v) {
              if (v == 'logout') auth.signOut();
            },
            icon: const Icon(
              Icons.more_vert_rounded,
              color: AppColors.textSecondary,
            ),
            color: AppColors.surface,
            itemBuilder: (_) => [
              const PopupMenuItem(
                value: 'logout',
                child: Row(
                  children: [
                    Icon(
                      Icons.logout_rounded,
                      color: AppColors.error,
                      size: 18,
                    ),
                    SizedBox(width: 10),
                    Text(
                      'Sign Out',
                      style: TextStyle(color: AppColors.textPrimary),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(104),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                child: TextField(
                  controller: _searchController,
                  onChanged: trips.setSearchQuery,
                  style: const TextStyle(color: AppColors.textPrimary),
                  decoration: InputDecoration(
                    hintText: 'Search by name, phone, address...',
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
                              trips.setSearchQuery('');
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
              StatusFilterChips(
                selectedStatus: trips.statusFilter,
                onStatusChanged: trips.setStatusFilter,
                counts: {
                  TripStatus.requested: trips.requestedCount,
                  TripStatus.accepted: trips.acceptedCount,
                  TripStatus.driverArrived: trips.driverArrivedCount,
                  TripStatus.inProgress: trips.inProgressCount,
                  TripStatus.completed: trips.completedCount,
                  TripStatus.cancelled: trips.cancelledCount,
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
      body: _buildBody(trips),
    );
  }

  Widget _buildBody(TripProvider trips) {
    if (trips.isLoading) {
      return const ShimmerLoadingList(itemCount: 4, type: ShimmerType.trip);
    }
    if (trips.errorMessage != null) {
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
              trips.errorMessage!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: trips.refreshTrips,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }
    if (trips.trips.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              trips.statusFilter != null
                  ? Icons.filter_list_off_rounded
                  : Icons.local_taxi_outlined,
              size: 56,
              color: AppColors.textHint,
            ),
            const SizedBox(height: 12),
            Text(
              trips.statusFilter != null
                  ? 'No trips match this filter'
                  : 'No trips yet',
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
      onRefresh: trips.refreshTrips,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
        itemCount: trips.trips.length,
        itemBuilder: (context, i) {
          final trip = trips.trips[i];
          return AnimatedListItem(
            index: i,
            child: TapScaleWrapper(
              onTap: () => Navigator.push(
                context,
                sharedAxisVerticalRoute(TripDetailScreen(trip: trip)),
              ),
              child: TripCard(
                key: ValueKey(trip.tripId),
                trip: trip,
                onTap: () => Navigator.push(
                  context,
                  sharedAxisVerticalRoute(TripDetailScreen(trip: trip)),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

// ─── Live Badge ────────────────────────────────────────────────────────────

class _LiveBadge extends StatefulWidget {
  final int count;
  const _LiveBadge({required this.count});

  @override
  State<_LiveBadge> createState() => _LiveBadgeState();
}

class _LiveBadgeState extends State<_LiveBadge>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _anim = Tween<double>(
      begin: 0.3,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, _) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: AppColors.error.withValues(alpha: 0.10 + 0.04 * _anim.value),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.error.withValues(alpha: 0.30)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.error.withValues(alpha: _anim.value),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.error.withValues(alpha: _anim.value * 0.6),
                    blurRadius: 4,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 5),
            Text(
              'LIVE · ${widget.count}',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: AppColors.error.withValues(
                  alpha: 0.7 + 0.3 * _anim.value,
                ),
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
