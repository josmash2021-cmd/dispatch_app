import 'package:flutter/material.dart';
import '../config/app_theme.dart';
import '../models/trip_model.dart';

class StatusFilterChips extends StatelessWidget {
  final TripStatus? selectedStatus;
  final ValueChanged<TripStatus?> onStatusChanged;
  final Map<TripStatus, int>? counts;

  const StatusFilterChips({
    super.key,
    required this.selectedStatus,
    required this.onStatusChanged,
    this.counts,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          _buildChip(
            context,
            label: 'All',
            isSelected: selectedStatus == null,
            color: AppColors.primary,
            count: null,
            onTap: () => onStatusChanged(null),
          ),
          const SizedBox(width: 8),
          ...TripStatus.values.map((status) {
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: _buildChip(
                context,
                label: status.label,
                isSelected: selectedStatus == status,
                color: _getStatusColor(status),
                count: counts?[status],
                onTap: () => onStatusChanged(status),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildChip(
    BuildContext context, {
    required String label,
    required bool isSelected,
    required Color color,
    required int? count,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? color : color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? color : color.withValues(alpha: 0.3),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                color: isSelected ? const Color(0xFF08090C) : color,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (count != null) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 6,
                  vertical: 2,
                ),
                decoration: BoxDecoration(
                  color:
                      isSelected
                          ? Colors.white.withValues(alpha: 0.25)
                          : color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  count.toString(),
                  style: TextStyle(
                    color: isSelected ? const Color(0xFF08090C) : color,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Color _getStatusColor(TripStatus status) {
    switch (status) {
      case TripStatus.requested:
        return AppColors.requested;
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
}
