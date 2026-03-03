import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import '../config/app_theme.dart';

/// Shimmer placeholder for trip cards while loading.
class ShimmerTripCard extends StatelessWidget {
  const ShimmerTripCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: AppColors.surface,
      highlightColor: AppColors.surfaceHigh,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.cardBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _shimmerBox(80, 14),
                const Spacer(),
                _shimmerBox(60, 22, radius: 12),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                _shimmerCircle(10),
                const SizedBox(width: 10),
                _shimmerBox(180, 13),
              ],
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.only(left: 4),
              child: Container(
                width: 2,
                height: 16,
                color: AppColors.cardBorder,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                _shimmerCircle(10),
                const SizedBox(width: 10),
                _shimmerBox(160, 13),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                _shimmerCircle(32),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _shimmerBox(110, 13),
                    const SizedBox(height: 6),
                    _shimmerBox(80, 11),
                  ],
                ),
                const Spacer(),
                _shimmerBox(60, 15),
              ],
            ),
            const SizedBox(height: 14),
            // Pipeline placeholder
            _shimmerBox(double.infinity, 32, radius: 8),
          ],
        ),
      ),
    );
  }
}

/// Shimmer placeholder for person (client/driver) cards.
class ShimmerPersonCard extends StatelessWidget {
  const ShimmerPersonCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: AppColors.surface,
      highlightColor: AppColors.surfaceHigh,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.cardBorder),
        ),
        child: Row(
          children: [
            _shimmerCircle(48),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      _shimmerBox(120, 15),
                      const Spacer(),
                      _shimmerBox(50, 18, radius: 10),
                    ],
                  ),
                  const SizedBox(height: 8),
                  _shimmerBox(90, 12),
                  const SizedBox(height: 4),
                  _shimmerBox(140, 12),
                ],
              ),
            ),
            const SizedBox(width: 8),
            _shimmerBox(4, 20),
          ],
        ),
      ),
    );
  }
}

/// Shimmer placeholder for stat cards.
class ShimmerStatCard extends StatelessWidget {
  const ShimmerStatCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: AppColors.surface,
      highlightColor: AppColors.surfaceHigh,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.cardBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                _shimmerBox(30, 30, radius: 8),
                const Spacer(),
                _shimmerBox(12, 12),
              ],
            ),
            const SizedBox(height: 12),
            _shimmerBox(60, 24),
            const SizedBox(height: 6),
            _shimmerBox(80, 12),
            const SizedBox(height: 4),
            _shimmerBox(50, 10),
          ],
        ),
      ),
    );
  }
}

/// Loading list with shimmer cards
class ShimmerLoadingList extends StatelessWidget {
  final int itemCount;
  final ShimmerType type;

  const ShimmerLoadingList({
    super.key,
    this.itemCount = 5,
    this.type = ShimmerType.trip,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
      physics: const NeverScrollableScrollPhysics(),
      itemCount: itemCount,
      itemBuilder: (_, __) {
        switch (type) {
          case ShimmerType.trip:
            return const ShimmerTripCard();
          case ShimmerType.person:
            return const ShimmerPersonCard();
        }
      },
    );
  }
}

enum ShimmerType { trip, person }

// ── Helpers ──────────────────────────────────────────────────────────────────

Widget _shimmerBox(double width, double height, {double radius = 4}) {
  return Container(
    width: width,
    height: height,
    decoration: BoxDecoration(
      color: AppColors.surfaceHigh,
      borderRadius: BorderRadius.circular(radius),
    ),
  );
}

Widget _shimmerCircle(double size) {
  return Container(
    width: size,
    height: size,
    decoration: const BoxDecoration(
      color: AppColors.surfaceHigh,
      shape: BoxShape.circle,
    ),
  );
}
