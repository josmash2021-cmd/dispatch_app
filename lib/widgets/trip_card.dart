import 'package:flutter/material.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../config/app_theme.dart';
import '../models/trip_model.dart';

// ── Pulsing live dot for active trips ───────────────────────────────────────
class _PulseDot extends StatefulWidget {
  final Color color;
  final bool active;
  const _PulseDot({required this.color, required this.active});

  @override
  State<_PulseDot> createState() => _PulseDotState();
}

class _PulseDotState extends State<_PulseDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _anim = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
    if (widget.active) _ctrl.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(_PulseDot old) {
    super.didUpdateWidget(old);
    if (widget.active && !_ctrl.isAnimating) _ctrl.repeat(reverse: true);
    if (!widget.active) { _ctrl.stop(); _ctrl.value = 1.0; }
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
        width: 8, height: 8,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: widget.color,
          boxShadow: widget.active
              ? [BoxShadow(
                  color: widget.color.withValues(alpha: _anim.value * 0.70),
                  blurRadius: 8 + 4 * _anim.value,
                  spreadRadius: 1,
                )]
              : [],
        ),
      ),
    );
  }
}

/// Cruise-style trip card with real-time animated status pipeline.
class TripCard extends StatefulWidget {
  final TripModel trip;
  final VoidCallback? onTap;

  const TripCard({super.key, required this.trip, this.onTap});

  @override
  State<TripCard> createState() => _TripCardState();
}

class _TripCardState extends State<TripCard>
    with SingleTickerProviderStateMixin {
  static const _gold      = AppColors.primary;
  static const _goldLight = AppColors.primaryLight;

  late AnimationController _stepCtrl;
  late Animation<double> _stepAnim;
  double _fromStep = 0;
  double _toStep   = 0;

  @override
  void initState() {
    super.initState();
    _fromStep = _toStep = _stepIndex(widget.trip.status).toDouble();
    _stepCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _stepAnim = Tween<double>(begin: _fromStep, end: _toStep).animate(
      CurvedAnimation(parent: _stepCtrl, curve: Curves.easeOutCubic),
    );
  }

  @override
  void didUpdateWidget(TripCard old) {
    super.didUpdateWidget(old);
    final newStep = _stepIndex(widget.trip.status).toDouble();
    if (newStep != _toStep) {
      _fromStep = _stepAnim.value;
      _toStep   = newStep;
      _stepAnim = Tween<double>(begin: _fromStep, end: _toStep).animate(
        CurvedAnimation(parent: _stepCtrl, curve: Curves.easeOutCubic),
      );
      _stepCtrl
        ..reset()
        ..forward();
    }
  }

  @override
  void dispose() {
    _stepCtrl.dispose();
    super.dispose();
  }

  // ── Helpers ──────────────────────────────────────────────

  TripModel get trip => widget.trip;

  int _stepIndex(TripStatus s) {
    switch (s) {
      case TripStatus.requested:     return 0;
      case TripStatus.accepted:      return 1;
      case TripStatus.driverArrived: return 2;
      case TripStatus.inProgress:    return 3;
      case TripStatus.completed:     return 4;
      case TripStatus.cancelled:     return -1;
    }
  }

  Color get _statusColor {
    switch (trip.status) {
      case TripStatus.requested:     return _gold;
      case TripStatus.accepted:      return _gold;
      case TripStatus.driverArrived: return _goldLight;
      case TripStatus.inProgress:    return _gold;
      case TripStatus.completed:     return AppColors.success;
      case TripStatus.cancelled:     return AppColors.error;
    }
  }

  String get _statusHeadline {
    final hasDriver = trip.driverName != null && trip.driverName!.isNotEmpty;
    switch (trip.status) {
      case TripStatus.requested:     return 'Waiting for driver';
      case TripStatus.accepted:      return hasDriver ? '${trip.driverName} en route' : 'Driver on the way';
      case TripStatus.driverArrived: return hasDriver ? '${trip.driverName} arrived' : 'Driver has arrived';
      case TripStatus.inProgress:    return 'Ride in progress';
      case TripStatus.completed:     return 'Ride completed';
      case TripStatus.cancelled:     return 'Cancelled';
    }
  }

  IconData get _statusIcon {
    switch (trip.status) {
      case TripStatus.requested:     return Icons.schedule_rounded;
      case TripStatus.accepted:      return Icons.directions_car_rounded;
      case TripStatus.driverArrived: return Icons.place_rounded;
      case TripStatus.inProgress:    return Icons.speed_rounded;
      case TripStatus.completed:     return Icons.check_circle_rounded;
      case TripStatus.cancelled:     return Icons.cancel_rounded;
    }
  }

  bool get _isActive =>
      trip.status != TripStatus.completed &&
      trip.status != TripStatus.cancelled;

  @override
  Widget build(BuildContext context) {
    final isCancelled = trip.status == TripStatus.cancelled;
    final borderColor = isCancelled
        ? AppColors.error.withValues(alpha: 0.25)
        : _isActive
            ? _gold.withValues(alpha: 0.30)
            : Colors.white.withValues(alpha: 0.06);

    return AnimatedBuilder(
      animation: _stepAnim,
      builder: (_, _) => GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          margin: const EdgeInsets.only(bottom: 10),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: borderColor, width: 1),
            boxShadow: _isActive
                ? [BoxShadow(color: _gold.withValues(alpha: 0.08), blurRadius: 20, offset: const Offset(0, 4))]
                : [],
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _buildTopBar(),
            Divider(height: 1, thickness: 1, color: Colors.white.withValues(alpha: 0.04)),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                _buildPassengerRow(),
                if (trip.driverName != null && trip.driverName!.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  _buildDriverRow(),
                ],
                const SizedBox(height: 12),
                _buildRoute(),
                const SizedBox(height: 12),
                _buildMeta(),
              ]),
            ),
            if (!isCancelled) ...[
              const SizedBox(height: 14),
              _buildPipeline(_stepAnim.value),
            ] else ...[
              const SizedBox(height: 14),
              _buildCancelledBanner(),
            ],
            const SizedBox(height: 14),
          ]),
        ),
      ),
    );
  }

  // ── Top bar ───────────────────────────────────────────────

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
      child: Row(children: [
        // Status dot + headline
        _PulseDot(color: _statusColor, active: _isActive),
        const SizedBox(width: 8),
        Icon(_statusIcon, size: 14, color: _statusColor),
        const SizedBox(width: 6),
        Text(
          _statusHeadline,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: _statusColor,
            letterSpacing: 0.1,
          ),
        ),
        const Spacer(),
        Text(
          timeago.format(trip.createdAt, locale: 'en'),
          style: TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: 0.30)),
        ),
      ]),
    );
  }

  // ── Passenger row ─────────────────────────────────────────

  Widget _buildPassengerRow() {
    return Row(children: [
      // Avatar
      Container(
        width: 38, height: 38,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: _gold.withValues(alpha: 0.10),
          border: Border.all(color: _gold.withValues(alpha: 0.25), width: 1),
        ),
        child: Center(
          child: Text(
            trip.passengerName.isNotEmpty ? trip.passengerName[0].toUpperCase() : '?',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: _gold),
          ),
        ),
      ),
      const SizedBox(width: 12),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(trip.passengerName,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white)),
        const SizedBox(height: 2),
        Text(trip.passengerPhone,
          style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.40))),
      ])),
      // Fare pill
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: _gold.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _gold.withValues(alpha: 0.30)),
        ),
        child: Text(
          '\$${trip.fare.toStringAsFixed(2)}',
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _gold),
        ),
      ),
    ]);
  }

  // ── Route ─────────────────────────────────────────────────

  Widget _buildDriverRow() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: _gold.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _gold.withValues(alpha: 0.15)),
      ),
      child: Row(children: [
        Container(
          width: 30, height: 30,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: _gold.withValues(alpha: 0.15),
          ),
          child: Center(
            child: Icon(Icons.directions_car_rounded, size: 15, color: _gold),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(trip.driverName ?? '',
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white)),
          if (trip.driverPhone != null && trip.driverPhone!.isNotEmpty)
            Text(trip.driverPhone!,
              style: TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: 0.40))),
        ])),
        if (trip.vehicleType.isNotEmpty)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(trip.vehicleType,
              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w500, color: _gold.withValues(alpha: 0.80))),
          ),
      ]),
    );
  }

  Widget _buildRoute() {
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(
        padding: const EdgeInsets.only(top: 3),
        child: Column(children: [
          Container(width: 9, height: 9, decoration: BoxDecoration(shape: BoxShape.circle, color: AppColors.success, boxShadow: [BoxShadow(color: AppColors.success.withValues(alpha: 0.5), blurRadius: 4)])),
          Container(width: 1, height: 22, color: Colors.white.withValues(alpha: 0.12)),
          Container(width: 9, height: 9, decoration: BoxDecoration(shape: BoxShape.circle, color: AppColors.error, boxShadow: [BoxShadow(color: AppColors.error.withValues(alpha: 0.5), blurRadius: 4)])),
        ]),
      ),
      const SizedBox(width: 12),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(trip.pickupAddress,
          maxLines: 1, overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 13, color: Colors.white)),
        const SizedBox(height: 10),
        Text(trip.dropoffAddress,
          maxLines: 1, overflow: TextOverflow.ellipsis,
          style: TextStyle(fontSize: 13, color: Colors.white.withValues(alpha: 0.70))),
      ])),
    ]);
  }

  // ── Meta row (distance, duration, driver) ─────────────────

  Widget _buildMeta() {
    return Row(children: [
      _metaChip(Icons.straighten_rounded, '${(trip.distance * 0.621371).toStringAsFixed(1)} mi'),
      const SizedBox(width: 8),
      _metaChip(Icons.timer_rounded, '${trip.duration} min'),
      if (trip.driverName != null && trip.driverName!.isNotEmpty && _isActive) ...[
        const SizedBox(width: 8),
        Expanded(
          child: Row(children: [
            Icon(Icons.person_rounded, size: 13, color: _gold.withValues(alpha: 0.80)),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                trip.driverName!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _gold.withValues(alpha: 0.90)),
              ),
            ),
          ]),
        ),
      ],
    ]);
  }

  Widget _metaChip(IconData icon, String label) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 12, color: Colors.white.withValues(alpha: 0.30)),
      const SizedBox(width: 4),
      Text(label, style: TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: 0.40))),
    ]);
  }

  // ── Status pipeline ───────────────────────────────────────

  static const _stages = ['New', 'Assigned', 'Arrived', 'Riding', 'Done'];

  Widget _buildPipeline(double animStep) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: List.generate(_stages.length * 2 - 1, (i) {
          if (i.isOdd) {
            // connector line — fill fraction driven by animated step
            final lineIndex = i ~/ 2;
            final fill = (animStep - lineIndex).clamp(0.0, 1.0);
            return Expanded(
              child: Container(
                height: 2,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(1),
                  gradient: LinearGradient(
                    stops: [fill, fill],
                    colors: [
                      _gold.withValues(alpha: 0.65),
                      Colors.white.withValues(alpha: 0.08),
                    ],
                  ),
                ),
              ),
            );
          }
          final stageIndex = i ~/ 2;
          // dot is "active" when it's the current target step
          final isActive = _toStep.round() == stageIndex;
          // dot is "done" once animStep fully passes it
          final isDone = animStep > stageIndex + 0.5;
          return _pipelineDot(stageIndex, isActive && !isDone, isDone);
        }),
      ),
    );
  }

  Widget _pipelineDot(int idx, bool isActive, bool isDone) {
    final Color dotColor = isDone
        ? _gold
        : isActive
            ? _gold
            : Colors.white.withValues(alpha: 0.15);
    final Color labelColor = (isActive || isDone)
        ? (isActive ? _gold : Colors.white.withValues(alpha: 0.50))
        : Colors.white.withValues(alpha: 0.20);

    return Column(mainAxisSize: MainAxisSize.min, children: [
      isActive
          ? _PulseDot(color: _gold, active: true)
          : Container(
              width: isDone ? 10 : 8,
              height: isDone ? 10 : 8,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: dotColor,
                boxShadow: isDone
                    ? [BoxShadow(color: _gold.withValues(alpha: 0.25), blurRadius: 4)]
                    : [],
              ),
              child: isDone
                  ? const Icon(Icons.check, size: 5, color: Color(0xFF08090C))
                  : null,
            ),
      const SizedBox(height: 4),
      Text(_stages[idx],
        style: TextStyle(fontSize: 9, fontWeight: isActive ? FontWeight.w700 : FontWeight.w400, color: labelColor)),
    ]);
  }

  // ── Cancelled banner ──────────────────────────────────────

  Widget _buildCancelledBanner() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.20)),
      ),
      child: Row(children: [
        Icon(Icons.cancel_rounded, size: 14, color: AppColors.error.withValues(alpha: 0.70)),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            trip.cancelReason != null && trip.cancelReason!.isNotEmpty
                ? 'Reason: ${trip.cancelReason}'
                : 'This trip was cancelled',
            maxLines: 1, overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 11, color: AppColors.error.withValues(alpha: 0.70)),
          ),
        ),
      ]),
    );
  }
}

