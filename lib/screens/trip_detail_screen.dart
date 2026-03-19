import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../config/app_theme.dart';
import '../models/driver_model.dart';
import '../models/trip_model.dart';
import '../providers/refund_provider.dart';
import '../providers/trip_provider.dart';
import '../services/dispatch_api_service.dart';
import '../services/driver_service.dart';
import '../services/trip_service.dart';
import '../widgets/status_badge.dart';

class TripDetailScreen extends StatefulWidget {
  final TripModel trip;
  const TripDetailScreen({super.key, required this.trip});
  @override
  State<TripDetailScreen> createState() => _TripDetailScreenState();
}

class _TripDetailScreenState extends State<TripDetailScreen>
    with SingleTickerProviderStateMixin {
  final TripService _tripService = TripService();
  final DriverService _driverService = DriverService();
  StreamSubscription? _tripSub;
  TripModel? _currentTrip;

  // Pipeline animation
  late AnimationController _pipeCtrl;
  late Animation<double> _pipeAnim;
  double _fromStep = 0;
  double _toStep = 0;

  int _pipeStepIndex(TripStatus s) {
    switch (s) {
      case TripStatus.requested:
        return 0;
      case TripStatus.accepted:
        return 1;
      case TripStatus.driverArrived:
        return 2;
      case TripStatus.inProgress:
        return 3;
      case TripStatus.completed:
        return 4;
      case TripStatus.cancelled:
        return -1;
    }
  }

  @override
  void initState() {
    super.initState();
    _currentTrip = widget.trip;
    _fromStep = _toStep = _pipeStepIndex(widget.trip.status).toDouble();
    _pipeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _pipeAnim = Tween<double>(
      begin: _fromStep,
      end: _toStep,
    ).animate(CurvedAnimation(parent: _pipeCtrl, curve: Curves.easeOutCubic));
    _tripSub = _tripService.getTripStream(widget.trip.tripId).listen((updated) {
      if (updated != null && mounted) {
        final newStep = _pipeStepIndex(updated.status).toDouble();
        if (newStep != _toStep) {
          _fromStep = _pipeAnim.value;
          _toStep = newStep;
          _pipeAnim = Tween<double>(begin: _fromStep, end: _toStep).animate(
            CurvedAnimation(parent: _pipeCtrl, curve: Curves.easeOutCubic),
          );
          _pipeCtrl
            ..reset()
            ..forward();
        }
        setState(() => _currentTrip = updated);
      }
    }, onError: (_) {});
  }

  @override
  void dispose() {
    _tripSub?.cancel();
    _pipeCtrl.dispose();
    super.dispose();
  }

  TripModel get trip => _currentTrip ?? widget.trip;

  Color _statusColor(TripStatus s) {
    switch (s) {
      case TripStatus.requested:
        return AppColors.primary;
      case TripStatus.accepted:
        return AppColors.accepted;
      case TripStatus.driverArrived:
        return AppColors.driverArrived;
      case TripStatus.inProgress:
        return AppColors.inProgress;
      case TripStatus.completed:
        return AppColors.completed;
      case TripStatus.cancelled:
        return AppColors.cancelled;
    }
  }

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('MM/dd/yyyy HH:mm');
    final sc = _statusColor(trip.status);
    final shortId = trip.tripId.length > 8
        ? trip.tripId.substring(0, 8).toUpperCase()
        : trip.tripId.toUpperCase();
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: sc.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: sc.withValues(alpha: 0.35)),
              ),
              child: Icon(Icons.receipt_long_rounded, size: 17, color: sc),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '#$shortId',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  trip.passengerName,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textHint,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          PopupMenuButton<String>(
            onSelected: (v) => _handleAction(context, v),
            color: AppColors.surface,
            icon: Icon(Icons.more_vert_rounded, color: AppColors.textSecondary),
            itemBuilder: (_) => [
              if (trip.status == TripStatus.requested)
                _menuItem(
                  'accept',
                  Icons.check_circle_rounded,
                  'Accept Trip',
                  AppColors.success,
                ),
              if (trip.status == TripStatus.accepted)
                _menuItem(
                  'arrived',
                  Icons.place_rounded,
                  'Driver Arrived',
                  AppColors.driverArrived,
                ),
              if (trip.status == TripStatus.driverArrived)
                _menuItem(
                  'start',
                  Icons.play_arrow_rounded,
                  'Start Trip',
                  AppColors.inProgress,
                ),
              if (trip.status == TripStatus.inProgress)
                _menuItem(
                  'complete',
                  Icons.done_all_rounded,
                  'Complete Trip',
                  AppColors.completed,
                ),
              if (trip.status != TripStatus.completed &&
                  trip.status != TripStatus.cancelled)
                _menuItem(
                  'cancel',
                  Icons.cancel_outlined,
                  'Cancel Trip',
                  AppColors.error,
                ),
              _menuItem(
                'delete',
                Icons.delete_forever_rounded,
                'Delete',
                AppColors.error,
              ),
              // Show refund option for completed or cancelled trips with payment
              if (trip.status == TripStatus.completed || 
                  trip.status == TripStatus.cancelled)
                _menuItem(
                  'refund',
                  Icons.money_off_rounded,
                  'Process Refund',
                  const Color(0xFF9C27B0),
                ),
            ],
          ),
        ],
      ),
      bottomNavigationBar: _buildBottomAction(context),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(child: StatusBadge(status: trip.status)),
            const SizedBox(height: 16),
            // ── Status pipeline (animated real-time) ──
            if (trip.status != TripStatus.cancelled)
              AnimatedBuilder(
                animation: _pipeAnim,
                builder: (_, _) => _buildStatusPipeline(_pipeAnim.value),
              ),
            if (trip.status == TripStatus.cancelled) _buildCancelledBanner(),
            const SizedBox(height: 16),
            _card('Trip Info', Icons.info_outline_rounded, [
              _infoRow(
                'ID',
                '...${trip.tripId.substring(trip.tripId.length > 12 ? trip.tripId.length - 12 : 0)}',
              ),
              _infoRow(
                'Fare',
                '\$${trip.fare.toStringAsFixed(2)}',
                valueColor: AppColors.primary,
                valueBold: true,
              ),
              _infoRow(
                'Distance',
                '${(trip.distance * 0.621371).toStringAsFixed(1)} mi',
              ),
              _infoRow('Duration', '${trip.duration} min'),
              _infoRow('Payment', _paymentLabel(trip.paymentMethod)),
              _infoRow('Vehicle', trip.vehicleType),
              if (trip.rating != null)
                _infoRow('Rating', '⭐ ${trip.rating!.toStringAsFixed(1)}'),
            ]),
            const SizedBox(height: 12),
            _card('Route', Icons.alt_route_rounded, [_routeWidget()]),
            const SizedBox(height: 12),
            _card('Passenger', Icons.person_rounded, [
              _infoRow('Name', trip.passengerName),
              _infoRow('Phone', trip.passengerPhone),
            ]),
            const SizedBox(height: 12),
            if (trip.driverId != null)
              _card('Driver', Icons.drive_eta_rounded, [
                _infoRow('Name', trip.driverName ?? 'N/A'),
                _infoRow('Phone', trip.driverPhone ?? 'N/A'),
              ]),
            if (trip.driverId == null &&
                trip.status == TripStatus.requested) ...[
              _assignDriverBanner(context),
            ],
            const SizedBox(height: 12),
            _card('Timeline', Icons.timeline_rounded, [
              _timeline(
                'Created',
                fmt.format(trip.createdAt),
                AppColors.primary,
                true,
              ),
              if (trip.acceptedAt != null)
                _timeline(
                  'Accepted',
                  fmt.format(trip.acceptedAt!),
                  AppColors.accepted,
                  true,
                ),
              if (trip.driverArrivedAt != null)
                _timeline(
                  'Driver Arrived',
                  fmt.format(trip.driverArrivedAt!),
                  AppColors.driverArrived,
                  true,
                ),
              if (trip.startedAt != null)
                _timeline(
                  'In Progress',
                  fmt.format(trip.startedAt!),
                  AppColors.inProgress,
                  true,
                ),
              if (trip.completedAt != null)
                _timeline(
                  'Completed',
                  fmt.format(trip.completedAt!),
                  AppColors.completed,
                  false,
                ),
              if (trip.cancelledAt != null) ...[
                _timeline(
                  'Cancelled',
                  fmt.format(trip.cancelledAt!),
                  AppColors.cancelled,
                  false,
                ),
                if (trip.cancelReason != null)
                  Padding(
                    padding: const EdgeInsets.only(left: 24, top: 4),
                    child: Text(
                      'Reason: ${trip.cancelReason}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.error,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
              ],
            ]),
          ],
        ),
      ),
    );
  }

  Widget? _buildBottomAction(BuildContext context) {
    if (trip.status == TripStatus.completed ||
        trip.status == TripStatus.cancelled) {
      return null;
    }
    String label;
    IconData icon;
    Color color;
    String action;
    switch (trip.status) {
      case TripStatus.requested:
        label = 'Accept Trip';
        icon = Icons.check_circle_rounded;
        color = AppColors.success;
        action = 'accept';
        break;
      case TripStatus.accepted:
        label = 'Driver Arrived';
        icon = Icons.place_rounded;
        color = AppColors.driverArrived;
        action = 'arrived';
        break;
      case TripStatus.driverArrived:
        label = 'Start Trip';
        icon = Icons.play_arrow_rounded;
        color = AppColors.inProgress;
        action = 'start';
        break;
      case TripStatus.inProgress:
        label = 'Complete Trip';
        icon = Icons.done_all_rounded;
        color = AppColors.completed;
        action = 'complete';
        break;
      default:
        return null;
    }
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.cardBorder)),
      ),
      child: Row(
        children: [
          if (trip.status == TripStatus.requested) ...[
            Expanded(
              child: GestureDetector(
                onTap: () => _handleAction(context, 'dispatch'),
                child: Container(
                  height: 52,
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.35),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.send_rounded, color: Colors.white, size: 20),
                      SizedBox(width: 8),
                      Text(
                        'Dispatch',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
          ],
          Expanded(
            child: GestureDetector(
              onTap: () => _handleAction(context, action),
              child: Container(
                height: 52,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: color.withValues(alpha: 0.35),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(icon, color: Colors.white, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      label,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: () => _handleAction(context, 'cancel'),
            child: Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: AppColors.error.withValues(alpha: 0.3),
                ),
              ),
              child: const Icon(
                Icons.cancel_outlined,
                color: AppColors.error,
                size: 22,
              ),
            ),
          ),
        ],
      ),
    );
  }

  PopupMenuItem<String> _menuItem(
    String value,
    IconData icon,
    String label,
    Color color,
  ) {
    return PopupMenuItem(
      value: value,
      child: Row(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 10),
          Text(
            label,
            style: TextStyle(
              color: color == AppColors.error
                  ? AppColors.error
                  : AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _card(String title, IconData icon, List<Widget> children) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          colors: [
            AppColors.primary.withValues(alpha: 0.18),
            AppColors.cardBorder.withValues(alpha: 0.6),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Container(
        margin: const EdgeInsets.all(1),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(15.5),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, size: 15, color: AppColors.primary),
                ),
                const SizedBox(width: 10),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Container(
              height: 1,
              color: AppColors.cardBorder.withValues(alpha: 0.5),
              margin: const EdgeInsets.only(bottom: 12),
            ),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _infoRow(
    String label,
    String value, {
    Color? valueColor,
    bool valueBold = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: const TextStyle(fontSize: 12, color: AppColors.textHint),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 13,
                fontWeight: valueBold ? FontWeight.w700 : FontWeight.w500,
                color: valueColor ?? AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _routeWidget() {
    return Row(
      children: [
        Column(
          children: [
            Container(
              width: 11,
              height: 11,
              decoration: const BoxDecoration(
                color: AppColors.success,
                shape: BoxShape.circle,
              ),
            ),
            Container(width: 2, height: 28, color: AppColors.divider),
            Container(
              width: 11,
              height: 11,
              decoration: const BoxDecoration(
                color: AppColors.error,
                shape: BoxShape.circle,
              ),
            ),
          ],
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Pickup',
                style: TextStyle(fontSize: 11, color: AppColors.textHint),
              ),
              Text(
                trip.pickupAddress,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'Drop-off',
                style: TextStyle(fontSize: 11, color: AppColors.textHint),
              ),
              Text(
                trip.dropoffAddress,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _assignDriverBanner(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.person_add_rounded,
            color: AppColors.warning,
            size: 32,
          ),
          const SizedBox(height: 8),
          const Text(
            'No Driver Assigned',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Assign a driver to this trip',
            style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: () => _showAssignDialog(context),
            icon: const Icon(Icons.person_add_rounded, size: 16),
            label: const Text('Assign Driver'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.warning,
              foregroundColor: Colors.black,
            ),
          ),
        ],
      ),
    );
  }

  Widget _timeline(String label, String time, Color color, bool showLine) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Container(
              width: 11,
              height: 11,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            if (showLine)
              Container(width: 2, height: 22, color: AppColors.divider),
          ],
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: color,
                  ),
                ),
                Text(
                  time,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textHint,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  String _paymentLabel(String m) {
    switch (m) {
      case 'cash':
        return 'Cash';
      case 'card':
        return 'Card';
      case 'transfer':
        return 'Transfer';
      default:
        return m;
    }
  }

  // ── Status pipeline ─────────────────────────────────────────────────────

  static const _pipelineLabels = [
    'New',
    'Assigned',
    'Arrived',
    'Riding',
    'Done',
  ];

  Widget _buildStatusPipeline(double animStep) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.20)),
      ),
      child: Row(
        children: List.generate(_pipelineLabels.length * 2 - 1, (i) {
          if (i.isOdd) {
            // Animated connector line
            final lineIndex = i ~/ 2;
            final fill = (animStep - lineIndex).clamp(0.0, 1.0);
            return Expanded(
              child: Container(
                height: 2.5,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(1.25),
                  gradient: LinearGradient(
                    stops: [fill, fill],
                    colors: [
                      AppColors.primary.withValues(alpha: 0.70),
                      Colors.white.withValues(alpha: 0.08),
                    ],
                  ),
                ),
              ),
            );
          }
          final idx = i ~/ 2;
          final isActive = _toStep.round() == idx;
          final isDone = animStep > idx + 0.5;
          final color = (isActive || isDone)
              ? AppColors.primary
              : Colors.white.withValues(alpha: 0.15);
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                width: isActive ? 16 : (isDone ? 12 : 9),
                height: isActive ? 16 : (isDone ? 12 : 9),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: color,
                  border: isActive
                      ? Border.all(
                          color: AppColors.primary.withValues(alpha: 0.50),
                          width: 2.5,
                        )
                      : null,
                  boxShadow: isActive
                      ? [
                          BoxShadow(
                            color: AppColors.primary.withValues(alpha: 0.60),
                            blurRadius: 12,
                            spreadRadius: 1,
                          ),
                        ]
                      : isDone
                      ? [
                          BoxShadow(
                            color: AppColors.primary.withValues(alpha: 0.30),
                            blurRadius: 6,
                          ),
                        ]
                      : [],
                ),
                child: isDone
                    ? const Icon(Icons.check, size: 7, color: Color(0xFF08090C))
                    : null,
              ),
              const SizedBox(height: 5),
              Text(
                _pipelineLabels[idx],
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: isActive ? FontWeight.w700 : FontWeight.w400,
                  color: isActive
                      ? AppColors.primary
                      : isDone
                      ? Colors.white.withValues(alpha: 0.55)
                      : Colors.white.withValues(alpha: 0.20),
                ),
              ),
            ],
          );
        }),
      ),
    );
  }

  Widget _buildCancelledBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Icon(
            Icons.cancel_rounded,
            color: AppColors.error.withValues(alpha: 0.80),
            size: 18,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              trip.cancelReason != null && trip.cancelReason!.isNotEmpty
                  ? 'Cancelled — ${trip.cancelReason}'
                  : 'This ride was cancelled',
              style: TextStyle(
                fontSize: 13,
                color: AppColors.error.withValues(alpha: 0.80),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Handle actions ───────────────────────────────────────────────────────

  void _handleAction(BuildContext context, String action) {
    final provider = context.read<TripProvider>();
    switch (action) {
      case 'accept':
        provider.updateTripStatus(trip.tripId, TripStatus.accepted);
        Navigator.pop(context);
        break;
      case 'dispatch':
        _dispatchToNearest(context);
        break;
      case 'arrived':
        provider.updateTripStatus(trip.tripId, TripStatus.driverArrived);
        Navigator.pop(context);
        break;
      case 'start':
        provider.updateTripStatus(trip.tripId, TripStatus.inProgress);
        Navigator.pop(context);
        break;
      case 'complete':
        provider.updateTripStatus(trip.tripId, TripStatus.completed);
        Navigator.pop(context);
        break;
      case 'cancel':
        _showCancelDialog(context);
        break;
      case 'delete':
        _showDeleteDialog(context);
        break;
      case 'refund':
        _showRefundDialog(context);
        break;
    }
  }

  void _dispatchToNearest(BuildContext context) async {
    // Read sqliteId from Firestore doc
    final tripService = TripService();
    final doc = await tripService.tripDoc(trip.tripId);
    final data = doc.data() as Map<String, dynamic>? ?? {};
    final sqliteId = data['sqliteId'] as int?;
    if (sqliteId == null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Trip not synced to backend yet')),
        );
      }
      return;
    }
    try {
      final result = await DispatchApiService.dispatchTrip(sqliteId);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.surfaceHigh,
            behavior: SnackBarBehavior.floating,
            content: Text(
              result['message'] as String? ?? 'Dispatched successfully',
              style: const TextStyle(color: AppColors.textPrimary),
            ),
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.error,
            content: Text('Dispatch failed: $e'),
          ),
        );
      }
    }
  }

  void _showCancelDialog(BuildContext context) {
    final rc = TextEditingController(
      text: 'No hay drivers disponibles cerca de tu zona en estos momentos',
    );
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel Trip'),
        content: TextField(
          controller: rc,
          decoration: const InputDecoration(labelText: 'Reason'),
          maxLines: 3,
          style: const TextStyle(color: AppColors.textPrimary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Back'),
          ),
          ElevatedButton(
            onPressed: () {
              if (rc.text.trim().isNotEmpty) {
                context.read<TripProvider>().cancelTrip(
                  trip.tripId,
                  rc.text.trim(),
                );
                Navigator.pop(ctx);
                Navigator.pop(context);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
            child: const Text('Cancel Trip'),
          ),
        ],
      ),
    );
  }

  void _showDeleteDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Trip'),
        content: const Text('Delete this trip? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Back'),
          ),
          ElevatedButton(
            onPressed: () {
              context.read<TripProvider>().deleteTrip(trip.tripId);
              Navigator.pop(ctx);
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _showRefundDialog(BuildContext context) async {
    // Get sqliteId from trip
    final tripService = TripService();
    final doc = await tripService.tripDoc(trip.tripId);
    final data = doc.data() as Map<String, dynamic>? ?? {};
    final sqliteId = data['sqliteId'] as int?;
    
    if (sqliteId == null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: AppColors.error,
            content: Text('Trip not synced to backend - cannot process refund'),
          ),
        );
      }
      return;
    }

    final reasonCtrl = TextEditingController(text: 'Customer requested refund');
    final amountCtrl = TextEditingController();
    bool fullRefund = true;

    if (!context.mounted) return;
    
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          backgroundColor: AppColors.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF9C27B0).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.money_off_rounded,
                  color: Color(0xFF9C27B0),
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              const Text(
                'Process Refund',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 18,
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Trip: #${trip.tripId.substring(trip.tripId.length > 8 ? trip.tripId.length - 8 : 0).toUpperCase()}',
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Original fare: \$${trip.fare.toStringAsFixed(2)}',
                style: const TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 16),
              // Full vs Partial refund toggle
              Container(
                decoration: BoxDecoration(
                  color: AppColors.surfaceHigh,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => fullRefund = true),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: fullRefund
                                ? AppColors.primary.withOpacity(0.2)
                                : null,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'Full Refund',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: fullRefund
                                  ? AppColors.primary
                                  : AppColors.textSecondary,
                              fontWeight: fullRefund
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => fullRefund = false),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: !fullRefund
                                ? AppColors.primary.withOpacity(0.2)
                                : null,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'Partial',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: !fullRefund
                                  ? AppColors.primary
                                  : AppColors.textSecondary,
                              fontWeight: !fullRefund
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              if (!fullRefund)
                TextField(
                  controller: amountCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  style: const TextStyle(color: AppColors.textPrimary),
                  decoration: InputDecoration(
                    labelText: 'Refund Amount (\$)',
                    labelStyle: const TextStyle(color: AppColors.textSecondary),
                    prefixText: '\$',
                    prefixStyle: const TextStyle(color: AppColors.primary),
                    filled: true,
                    fillColor: AppColors.surfaceHigh,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              if (!fullRefund) const SizedBox(height: 12),
              TextField(
                controller: reasonCtrl,
                style: const TextStyle(color: AppColors.textPrimary),
                decoration: InputDecoration(
                  labelText: 'Reason for Refund',
                  labelStyle: const TextStyle(color: AppColors.textSecondary),
                  filled: true,
                  fillColor: AppColors.surfaceHigh,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none,
                  ),
                ),
                maxLines: 2,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text(
                'Cancel',
                style: TextStyle(color: AppColors.textSecondary),
              ),
            ),
            Consumer<RefundProvider>(
              builder: (context, refundProvider, _) {
                return ElevatedButton(
                  onPressed: refundProvider.isLoading
                      ? null
                      : () async {
                          final reason = reasonCtrl.text.trim();
                          if (reason.isEmpty) return;

                          double? refundAmount;
                          if (!fullRefund) {
                            final amountText = amountCtrl.text.trim();
                            if (amountText.isEmpty) return;
                            refundAmount = double.tryParse(amountText);
                            if (refundAmount == null || refundAmount <= 0) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  backgroundColor: AppColors.error,
                                  content: Text('Invalid refund amount'),
                                ),
                              );
                              return;
                            }
                            if (refundAmount > trip.fare) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  backgroundColor: AppColors.error,
                                  content: Text(
                                    'Refund amount cannot exceed original fare',
                                  ),
                                ),
                              );
                              return;
                            }
                          }

                          Navigator.pop(ctx);
                          
                          final success = await refundProvider.processRefund(
                            tripId: sqliteId,
                            reason: reason,
                            amount: refundAmount,
                          );

                          if (success && context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                backgroundColor: AppColors.success,
                                behavior: SnackBarBehavior.floating,
                                content: Text(
                                  refundAmount != null
                                      ? 'Partial refund of \$${refundAmount.toStringAsFixed(2)} processed'
                                      : 'Full refund of \$${trip.fare.toStringAsFixed(2)} processed',
                                ),
                              ),
                            );
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF9C27B0),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: refundProvider.isLoading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Process Refund'),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showAssignDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      isScrollControlled: true,
      builder: (ctx) => _DriverPickerSheet(
        tripId: trip.tripId,
        driverService: _driverService,
        onAssign: (driver) {
          context.read<TripProvider>().assignDriver(
            tripId: trip.tripId,
            driverId: driver.driverId,
            driverName: driver.fullName,
            driverPhone: driver.phone,
          );
          Navigator.pop(ctx);
        },
      ),
    );
  }
}

// ─── Driver Picker Bottom Sheet ────────────────────────────────────────────

class _DriverPickerSheet extends StatefulWidget {
  final String tripId;
  final DriverService driverService;
  final void Function(DriverModel driver) onAssign;

  const _DriverPickerSheet({
    required this.tripId,
    required this.driverService,
    required this.onAssign,
  });

  @override
  State<_DriverPickerSheet> createState() => _DriverPickerSheetState();
}

class _DriverPickerSheetState extends State<_DriverPickerSheet> {
  String _search = '';
  bool _showAddForm = false;
  final _fnCtrl = TextEditingController();
  final _lnCtrl = TextEditingController();
  final _phCtrl = TextEditingController();
  final _vtCtrl = TextEditingController();
  final _vpCtrl = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _fnCtrl.dispose();
    _lnCtrl.dispose();
    _phCtrl.dispose();
    _vtCtrl.dispose();
    _vpCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.45,
      maxChildSize: 0.95,
      expand: false,
      builder: (_, scrollCtrl) {
        return Column(
          children: [
            // Handle
            Center(
              child: Container(
                margin: const EdgeInsets.symmetric(vertical: 10),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.divider,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: AppColors.warning.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.person_search_rounded,
                      color: AppColors.warning,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'Assign Driver',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () =>
                        setState(() => _showAddForm = !_showAddForm),
                    icon: Icon(
                      _showAddForm ? Icons.close_rounded : Icons.add_rounded,
                      size: 16,
                    ),
                    label: Text(_showAddForm ? 'Cancel' : 'Add Driver'),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.primary,
                    ),
                  ),
                ],
              ),
            ),

            // Add driver form
            if (_showAddForm)
              Container(
                margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.surfaceHigh,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.3),
                  ),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: _field(
                            _fnCtrl,
                            'First Name',
                            Icons.person_outline_rounded,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _field(
                            _lnCtrl,
                            'Last Name',
                            Icons.person_outline_rounded,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    _field(
                      _phCtrl,
                      'Phone',
                      Icons.phone_rounded,
                      keyboard: TextInputType.phone,
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: _field(
                            _vtCtrl,
                            'Vehicle Type',
                            Icons.directions_car_rounded,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _field(_vpCtrl, 'Plate', Icons.pin_rounded),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _saving ? null : _saveNewDriver,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.black,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: _saving
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.black,
                                ),
                              )
                            : const Text(
                                'Save Driver',
                                style: TextStyle(fontWeight: FontWeight.w700),
                              ),
                      ),
                    ),
                  ],
                ),
              ),

            // Search
            if (!_showAddForm)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                child: TextField(
                  onChanged: (v) => setState(() => _search = v.toLowerCase()),
                  style: const TextStyle(color: AppColors.textPrimary),
                  decoration: InputDecoration(
                    hintText: 'Search drivers...',
                    hintStyle: const TextStyle(color: AppColors.textHint),
                    prefixIcon: const Icon(
                      Icons.search_rounded,
                      color: AppColors.textHint,
                    ),
                    filled: true,
                    fillColor: AppColors.surfaceHigh,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                  ),
                ),
              ),

            // Driver list or add-form placeholder
            if (!_showAddForm)
              Expanded(
                child: StreamBuilder<List<DriverModel>>(
                  stream: widget.driverService.getDriversStream(),
                  builder: (ctx, snap) {
                    if (snap.connectionState == ConnectionState.waiting) {
                      return const Center(
                        child: CircularProgressIndicator(
                          color: AppColors.primary,
                        ),
                      );
                    }
                    if (snap.hasError) {
                      return Center(
                        child: Text(
                          'Error loading drivers',
                          style: TextStyle(color: AppColors.error),
                        ),
                      );
                    }
                    final all = snap.data ?? [];
                    final drivers = _search.isEmpty
                        ? all
                        : all
                              .where(
                                (d) =>
                                    d.fullName.toLowerCase().contains(
                                      _search,
                                    ) ||
                                    d.phone.contains(_search) ||
                                    (d.vehiclePlate?.toLowerCase().contains(
                                          _search,
                                        ) ??
                                        false),
                              )
                              .toList();

                    if (drivers.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.person_off_rounded,
                              size: 48,
                              color: AppColors.textHint,
                            ),
                            const SizedBox(height: 10),
                            Text(
                              all.isEmpty
                                  ? 'No drivers registered yet.\nTap "Add Driver" to add one.'
                                  : 'No drivers match your search.',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      );
                    }

                    return ListView.separated(
                      controller: scrollCtrl,
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                      itemCount: drivers.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemBuilder: (_, i) => _DriverTile(
                        driver: drivers[i],
                        onAssign: () => widget.onAssign(drivers[i]),
                      ),
                    );
                  },
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _field(
    TextEditingController ctrl,
    String label,
    IconData icon, {
    TextInputType? keyboard,
  }) {
    return TextField(
      controller: ctrl,
      keyboardType: keyboard,
      style: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(
          color: AppColors.textSecondary,
          fontSize: 12,
        ),
        prefixIcon: Icon(icon, color: AppColors.textHint, size: 16),
        filled: true,
        fillColor: AppColors.background,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      ),
    );
  }

  Future<void> _saveNewDriver() async {
    if (_fnCtrl.text.trim().isEmpty || _phCtrl.text.trim().isEmpty) return;
    setState(() => _saving = true);
    try {
      final driver = DriverModel(
        driverId: '',
        firstName: _fnCtrl.text.trim(),
        lastName: _lnCtrl.text.trim(),
        phone: _phCtrl.text.trim(),
        vehicleType: _vtCtrl.text.trim().isEmpty ? null : _vtCtrl.text.trim(),
        vehiclePlate: _vpCtrl.text.trim().isEmpty ? null : _vpCtrl.text.trim(),
        isOnline: false,
      );
      await widget.driverService.addDriver(driver);
      _fnCtrl.clear();
      _lnCtrl.clear();
      _phCtrl.clear();
      _vtCtrl.clear();
      _vpCtrl.clear();
      if (mounted) {
        setState(() {
          _saving = false;
          _showAddForm = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _saving = false);
    }
  }
}

// ─── Driver Tile ───────────────────────────────────────────────────────────

class _DriverTile extends StatelessWidget {
  final DriverModel driver;
  final VoidCallback onAssign;
  const _DriverTile({required this.driver, required this.onAssign});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surfaceHigh,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: driver.isOnline
              ? AppColors.success.withValues(alpha: 0.4)
              : AppColors.cardBorder,
        ),
      ),
      child: Row(
        children: [
          // Avatar
          Stack(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: AppColors.primary.withValues(alpha: 0.15),
                child: Text(
                  driver.firstName.isNotEmpty
                      ? driver.firstName[0].toUpperCase()
                      : '?',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
              ),
              Positioned(
                bottom: 0,
                right: 0,
                child: Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: driver.isOnline
                        ? AppColors.success
                        : AppColors.textHint,
                    border: Border.all(color: AppColors.surface, width: 2),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  driver.fullName,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  driver.phone,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
                if (driver.vehicleType != null ||
                    driver.vehiclePlate != null) ...[
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      const Icon(
                        Icons.directions_car_rounded,
                        size: 12,
                        color: AppColors.textHint,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        [
                          driver.vehicleType,
                          driver.vehiclePlate,
                        ].where((e) => e != null && e.isNotEmpty).join(' · '),
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.textHint,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: onAssign,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.warning,
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: const Text(
              'Assign',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}
