import 'package:flutter/material.dart';
import '../config/app_theme.dart';
import '../models/trip_model.dart';

class StatusBadge extends StatelessWidget {
  final TripStatus status;
  final bool compact;

  const StatusBadge({
    super.key,
    required this.status,
    this.compact = false,
  });

  static const _gold = AppColors.primary;
  static const _goldLight = AppColors.primaryLight;

  Color get _color {
    switch (status) {
      case TripStatus.requested:    return _gold;
      case TripStatus.accepted:     return _gold;
      case TripStatus.driverArrived: return _goldLight;
      case TripStatus.inProgress:   return _gold;
      case TripStatus.completed:    return AppColors.success;
      case TripStatus.cancelled:    return AppColors.error;
    }
  }

  IconData get _icon {
    switch (status) {
      case TripStatus.requested:    return Icons.schedule_rounded;
      case TripStatus.accepted:     return Icons.directions_car_rounded;
      case TripStatus.driverArrived: return Icons.place_rounded;
      case TripStatus.inProgress:   return Icons.speed_rounded;
      case TripStatus.completed:    return Icons.check_circle_rounded;
      case TripStatus.cancelled:    return Icons.cancel_rounded;
    }
  }

  String get _label => status.label;

  @override
  Widget build(BuildContext context) {
    final c = _color;
    if (compact) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: c.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: c.withValues(alpha: 0.25)),
        ),
        child: Text(
          _label,
          style: TextStyle(color: c, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 0.2),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: c.withValues(alpha: 0.30)),
        boxShadow: [BoxShadow(color: c.withValues(alpha: 0.15), blurRadius: 12)],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_icon, color: c, size: 15),
          const SizedBox(width: 6),
          Text(
            _label,
            style: TextStyle(color: c, fontSize: 13, fontWeight: FontWeight.w700, letterSpacing: 0.2),
          ),
        ],
      ),
    );
  }
}

