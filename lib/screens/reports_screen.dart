import 'dart:io';
import 'dart:math' as math;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:csv/csv.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import '../config/app_theme.dart';
import '../models/trip_model.dart';

/// Financial reports screen with charts, analytics, and CSV export.
class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen>
    with TickerProviderStateMixin {
  final _db = FirebaseFirestore.instance;
  bool _loading = true;

  // Date range
  DateTime _startDate = DateTime.now().subtract(const Duration(days: 30));
  DateTime _endDate = DateTime.now();

  // Report data
  List<TripModel> _trips = [];
  double _totalRevenue = 0;
  double _avgFare = 0;
  int _totalTrips = 0;
  int _completedTrips = 0;
  int _cancelledTrips = 0;
  Map<String, double> _revenueByVehicle = {};

  // New analytics data
  Map<String, double> _dailyRevenue = {}; // sorted by date
  Map<String, int> _dailyTrips = {};
  Map<String, int> _paymentMethodCounts = {};
  Map<String, int> _cancelReasons = {};
  Map<int, int> _cancellationByHour = {};

  // Animation
  late AnimationController _staggerController;
  late AnimationController _chartController;
  late Animation<double> _chartAnimation;

  @override
  void initState() {
    super.initState();
    _staggerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _chartController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _chartAnimation = CurvedAnimation(
      parent: _chartController,
      curve: Curves.easeOutCubic,
    );
    _loadReport();
  }

  @override
  void dispose() {
    _staggerController.dispose();
    _chartController.dispose();
    super.dispose();
  }

  Future<void> _loadReport() async {
    setState(() => _loading = true);
    try {
      final snap = await _db
          .collection('trips')
          .where('createdAt',
              isGreaterThanOrEqualTo: Timestamp.fromDate(_startDate))
          .where('createdAt',
              isLessThanOrEqualTo: Timestamp.fromDate(
                DateTime(
                    _endDate.year, _endDate.month, _endDate.day, 23, 59, 59),
              ))
          .orderBy('createdAt', descending: true)
          .get();

      final trips = snap.docs.map((d) => TripModel.fromFirestore(d)).toList();

      double total = 0;
      int completed = 0;
      int cancelled = 0;
      final byVehicle = <String, double>{};
      final dailyRev = <String, double>{};
      final dailyTrips = <String, int>{};
      final paymentMethods = <String, int>{};
      final cancelReasons = <String, int>{};
      final cancelByHour = <int, int>{};

      for (final t in trips) {
        final dayKey = DateFormat('yyyy-MM-dd').format(t.createdAt);

        if (t.status == TripStatus.completed) {
          completed++;
          total += t.fare;
          byVehicle[t.vehicleType] =
              (byVehicle[t.vehicleType] ?? 0) + t.fare;
          dailyRev[dayKey] = (dailyRev[dayKey] ?? 0) + t.fare;

          // Payment method
          final pm = t.paymentMethod.isNotEmpty
              ? t.paymentMethod[0].toUpperCase() +
                  t.paymentMethod.substring(1).toLowerCase()
              : 'Other';
          paymentMethods[pm] = (paymentMethods[pm] ?? 0) + 1;
        }

        if (t.status == TripStatus.cancelled) {
          cancelled++;
          final reason = t.cancelReason?.isNotEmpty == true
              ? t.cancelReason!
              : 'No reason given';
          cancelReasons[reason] = (cancelReasons[reason] ?? 0) + 1;

          final cancelTime = t.cancelledAt ?? t.createdAt;
          cancelByHour[cancelTime.hour] =
              (cancelByHour[cancelTime.hour] ?? 0) + 1;
        }

        dailyTrips[dayKey] = (dailyTrips[dayKey] ?? 0) + 1;
      }

      // Sort daily maps by date
      final sortedDailyRev = Map.fromEntries(
          dailyRev.entries.toList()..sort((a, b) => a.key.compareTo(b.key)));
      final sortedDailyTrips = Map.fromEntries(
          dailyTrips.entries.toList()..sort((a, b) => a.key.compareTo(b.key)));

      setState(() {
        _trips = trips;
        _totalRevenue = total;
        _totalTrips = trips.length;
        _completedTrips = completed;
        _cancelledTrips = cancelled;
        _avgFare = completed > 0 ? total / completed : 0;
        _revenueByVehicle = byVehicle;
        _dailyRevenue = sortedDailyRev;
        _dailyTrips = sortedDailyTrips;
        _paymentMethodCounts = paymentMethods;
        _cancelReasons = cancelReasons;
        _cancellationByHour = cancelByHour;
        _loading = false;
      });

      _staggerController.forward(from: 0);
      _chartController.forward(from: 0);
    } catch (e) {
      debugPrint('Error loading report: $e');
      setState(() => _loading = false);
    }
  }

  Future<void> _exportCsv() async {
    try {
      final rows = <List<dynamic>>[
        [
          'Trip ID',
          'Passenger',
          'Pickup',
          'Dropoff',
          'Vehicle',
          'Fare',
          'Payment',
          'Status',
          'Date'
        ],
        ..._trips.map((t) => [
              t.tripId,
              t.passengerName,
              t.pickupAddress,
              t.dropoffAddress,
              t.vehicleType,
              t.fare.toStringAsFixed(2),
              t.paymentMethod,
              t.status.label,
              DateFormat('yyyy-MM-dd HH:mm').format(t.createdAt),
            ]),
      ];

      final csv = const ListToCsvConverter().convert(rows);
      final dir = await getApplicationDocumentsDirectory();
      final file = File(
          '${dir.path}/cruise_report_${DateFormat('yyyyMMdd').format(DateTime.now())}.csv');
      await file.writeAsString(csv);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Report saved to: ${file.path}'),
            backgroundColor: AppColors.primary,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Export error: $e'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _pickDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2024),
      lastDate: DateTime.now(),
      initialDateRange: DateTimeRange(start: _startDate, end: _endDate),
      builder: (context, child) => Theme(
        data: ThemeData.dark().copyWith(
          colorScheme: const ColorScheme.dark(
            primary: AppColors.primary,
            surface: AppColors.surface,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      _startDate = picked.start;
      _endDate = picked.end;
      _loadReport();
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateRange =
        '${DateFormat('MMM d').format(_startDate)} — ${DateFormat('MMM d, y').format(_endDate)}';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppColors.primary),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Financial Reports'),
        actions: [
          IconButton(
            icon: const Icon(Icons.file_download_outlined,
                color: AppColors.primary),
            tooltip: 'Export CSV',
            onPressed: _exportCsv,
          ),
        ],
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Date range picker
                  _buildDateRangePicker(dateRange),
                  const SizedBox(height: 20),

                  // Animated summary cards
                  _buildSummaryCards(),
                  const SizedBox(height: 28),

                  // Revenue Line Chart
                  _buildSectionHeader('Revenue Trend', Icons.show_chart),
                  const SizedBox(height: 12),
                  _buildRevenueLineChart(),
                  const SizedBox(height: 28),

                  // Trips Bar Chart
                  _buildSectionHeader(
                      'Trips by Day', Icons.bar_chart_rounded),
                  const SizedBox(height: 12),
                  _buildTripsBarChart(),
                  const SizedBox(height: 28),

                  // Completion Rate Ring + Cancellation Rate side by side
                  _buildSectionHeader('Performance', Icons.speed_rounded),
                  const SizedBox(height: 12),
                  _buildPerformanceRow(),
                  const SizedBox(height: 28),

                  // Revenue by vehicle type
                  _buildSectionHeader(
                      'Revenue by Vehicle', Icons.directions_car_rounded),
                  const SizedBox(height: 12),
                  _buildRevenueByVehicle(),
                  const SizedBox(height: 28),

                  // Payment Method Breakdown
                  _buildSectionHeader(
                      'Payment Methods', Icons.payment_rounded),
                  const SizedBox(height: 12),
                  _buildPaymentBreakdown(),
                  const SizedBox(height: 28),

                  // Cancellation Analytics
                  if (_cancelledTrips > 0) ...[
                    _buildSectionHeader(
                        'Cancellation Analytics', Icons.cancel_rounded),
                    const SizedBox(height: 12),
                    _buildCancellationAnalytics(),
                    const SizedBox(height: 28),
                  ],

                  const SizedBox(height: 40),
                ],
              ),
            ),
    );
  }

  // ─── Date Range Picker ───────────────────────────────────────────

  Widget _buildDateRangePicker(String dateRange) {
    return GestureDetector(
      onTap: _pickDateRange,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.cardBorder),
        ),
        child: Row(
          children: [
            const Icon(Icons.date_range, color: AppColors.primary, size: 20),
            const SizedBox(width: 10),
            Text(dateRange,
                style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w500)),
            const Spacer(),
            const Icon(Icons.edit, color: AppColors.textHint, size: 16),
          ],
        ),
      ),
    );
  }

  // ─── Summary Cards (animated stagger) ─────────────────────────────

  Widget _buildSummaryCards() {
    final cards = [
      _SummaryData('Revenue', '\$${_totalRevenue.toStringAsFixed(2)}',
          AppColors.primary, Icons.attach_money_rounded),
      _SummaryData('Avg Fare', '\$${_avgFare.toStringAsFixed(2)}',
          AppColors.primaryLight, Icons.trending_up_rounded),
      _SummaryData('Total Trips', '$_totalTrips', AppColors.textPrimary,
          Icons.trip_origin_rounded),
      _SummaryData('Completed', '$_completedTrips', AppColors.completed,
          Icons.check_circle_outline_rounded),
      _SummaryData('Cancelled', '$_cancelledTrips',
          AppColors.textSecondary, Icons.cancel_outlined),
    ];

    return AnimatedBuilder(
      animation: _staggerController,
      builder: (context, _) {
        return Column(
          children: [
            Row(
              children: [
                Expanded(child: _animatedSummaryCard(cards[0], 0, 5)),
                const SizedBox(width: 10),
                Expanded(child: _animatedSummaryCard(cards[1], 1, 5)),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(child: _animatedSummaryCard(cards[2], 2, 5)),
                const SizedBox(width: 10),
                Expanded(child: _animatedSummaryCard(cards[3], 3, 5)),
                const SizedBox(width: 10),
                Expanded(child: _animatedSummaryCard(cards[4], 4, 5)),
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _animatedSummaryCard(_SummaryData data, int index, int total) {
    final start = index / total;
    final end = math.min(start + 0.4, 1.0);
    final animation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _staggerController,
        curve: Interval(start, end, curve: Curves.easeOut),
      ),
    );

    return FadeTransition(
      opacity: animation,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.15),
          end: Offset.zero,
        ).animate(animation),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.cardBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(data.icon, color: data.color.withValues(alpha: 0.6), size: 16),
                  const SizedBox(width: 6),
                  Text(data.label,
                      style: const TextStyle(
                          color: AppColors.textSecondary, fontSize: 11)),
                ],
              ),
              const SizedBox(height: 8),
              Text(data.value,
                  style: TextStyle(
                      color: data.color,
                      fontSize: 20,
                      fontWeight: FontWeight.w800)),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Revenue Line Chart ───────────────────────────────────────────

  Widget _buildRevenueLineChart() {
    if (_dailyRevenue.isEmpty) {
      return _emptyState('No revenue data for this period');
    }

    final entries = _dailyRevenue.entries.toList();
    final maxY = entries.map((e) => e.value).reduce(math.max);
    final spots = List.generate(
        entries.length, (i) => FlSpot(i.toDouble(), entries[i].value));

    return AnimatedBuilder(
      animation: _chartAnimation,
      builder: (context, _) {
        return Container(
          height: 220,
          padding: const EdgeInsets.fromLTRB(8, 16, 16, 8),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.cardBorder),
          ),
          child: LineChart(
            LineChartData(
              minY: 0,
              maxY: maxY * 1.15,
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                horizontalInterval: maxY > 0 ? maxY / 4 : 1,
                getDrawingHorizontalLine: (value) => FlLine(
                  color: AppColors.surfaceHigh,
                  strokeWidth: 1,
                ),
              ),
              titlesData: FlTitlesData(
                topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false)),
                rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false)),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 50,
                    getTitlesWidget: (value, meta) {
                      if (value == meta.min || value == meta.max) {
                        return const SizedBox.shrink();
                      }
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: Text(
                          '\$${value.toInt()}',
                          style: const TextStyle(
                              color: AppColors.textHint, fontSize: 10),
                        ),
                      );
                    },
                  ),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 28,
                    interval: math.max(1, (entries.length / 6).ceilToDouble()),
                    getTitlesWidget: (value, meta) {
                      final idx = value.toInt();
                      if (idx < 0 || idx >= entries.length) {
                        return const SizedBox.shrink();
                      }
                      final date = DateTime.parse(entries[idx].key);
                      return Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          DateFormat('M/d').format(date),
                          style: const TextStyle(
                              color: AppColors.textHint, fontSize: 10),
                        ),
                      );
                    },
                  ),
                ),
              ),
              borderData: FlBorderData(show: false),
              lineTouchData: LineTouchData(
                touchTooltipData: LineTouchTooltipData(
                  getTooltipColor: (_) => AppColors.surfaceHigh,
                  tooltipRoundedRadius: 8,
                  getTooltipItems: (spots) => spots.map((spot) {
                    final idx = spot.spotIndex;
                    final date = DateTime.parse(entries[idx].key);
                    return LineTooltipItem(
                      '${DateFormat('MMM d').format(date)}\n\$${spot.y.toStringAsFixed(2)}',
                      const TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w600,
                          fontSize: 12),
                    );
                  }).toList(),
                ),
              ),
              lineBarsData: [
                LineChartBarData(
                  spots: spots,
                  isCurved: true,
                  curveSmoothness: 0.3,
                  color: AppColors.primary,
                  barWidth: 2.5,
                  isStrokeCapRound: true,
                  dotData: FlDotData(
                    show: entries.length <= 15,
                    getDotPainter: (spot, pct, bar, idx) =>
                        FlDotCirclePainter(
                      radius: 3,
                      color: AppColors.primary,
                      strokeWidth: 1.5,
                      strokeColor: AppColors.surface,
                    ),
                  ),
                  belowBarData: BarAreaData(
                    show: true,
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        AppColors.primary.withValues(alpha: 0.25 * _chartAnimation.value),
                        AppColors.primary.withValues(alpha: 0.0),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            duration: const Duration(milliseconds: 400),
          ),
        );
      },
    );
  }

  // ─── Trips Bar Chart ──────────────────────────────────────────────

  Widget _buildTripsBarChart() {
    if (_dailyTrips.isEmpty) {
      return _emptyState('No trips in this period');
    }

    final entries = _dailyTrips.entries.toList();
    final maxY = entries.map((e) => e.value).reduce(math.max).toDouble();

    return Container(
      height: 200,
      padding: const EdgeInsets.fromLTRB(8, 16, 16, 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: BarChart(
        BarChartData(
          maxY: maxY * 1.2,
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: maxY > 0 ? math.max(1, maxY / 4) : 1,
            getDrawingHorizontalLine: (value) => FlLine(
              color: AppColors.surfaceHigh,
              strokeWidth: 1,
            ),
          ),
          titlesData: FlTitlesData(
            topTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 32,
                getTitlesWidget: (value, meta) {
                  if (value == meta.min || value == meta.max) {
                    return const SizedBox.shrink();
                  }
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Text(
                      '${value.toInt()}',
                      style: const TextStyle(
                          color: AppColors.textHint, fontSize: 10),
                    ),
                  );
                },
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 28,
                getTitlesWidget: (value, meta) {
                  final idx = value.toInt();
                  if (idx < 0 || idx >= entries.length) {
                    return const SizedBox.shrink();
                  }
                  // Show every Nth label to avoid overlap
                  final interval = math.max(1, (entries.length / 6).ceil());
                  if (idx % interval != 0) return const SizedBox.shrink();
                  final date = DateTime.parse(entries[idx].key);
                  return Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      DateFormat('M/d').format(date),
                      style: const TextStyle(
                          color: AppColors.textHint, fontSize: 10),
                    ),
                  );
                },
              ),
            ),
          ),
          borderData: FlBorderData(show: false),
          barTouchData: BarTouchData(
            touchTooltipData: BarTouchTooltipData(
              getTooltipColor: (_) => AppColors.surfaceHigh,
              tooltipRoundedRadius: 8,
              getTooltipItem: (group, groupIdx, rod, rodIdx) {
                final date = DateTime.parse(entries[groupIdx].key);
                return BarTooltipItem(
                  '${DateFormat('MMM d').format(date)}\n${rod.toY.toInt()} trips',
                  const TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w600,
                      fontSize: 12),
                );
              },
            ),
          ),
          barGroups: List.generate(entries.length, (i) {
            return BarChartGroupData(
              x: i,
              barRods: [
                BarChartRodData(
                  toY: entries[i].value.toDouble(),
                  color: AppColors.primary,
                  width: math.max(2, math.min(16, 300 / entries.length)),
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(4)),
                  backDrawRodData: BackgroundBarChartRodData(
                    show: true,
                    toY: maxY * 1.2,
                    color: AppColors.surfaceHigh.withValues(alpha: 0.3),
                  ),
                ),
              ],
            );
          }),
        ),
        duration: const Duration(milliseconds: 400),
      ),
    );
  }

  // ─── Performance Row (Completion Ring + Cancellation Rate) ────────

  Widget _buildPerformanceRow() {
    final completionRate =
        _totalTrips > 0 ? _completedTrips / _totalTrips : 0.0;
    final cancellationRate =
        _totalTrips > 0 ? _cancelledTrips / _totalTrips : 0.0;

    return Row(
      children: [
        Expanded(child: _buildCompletionRing(completionRate)),
        const SizedBox(width: 12),
        Expanded(child: _buildCancellationRateCard(cancellationRate)),
      ],
    );
  }

  Widget _buildCompletionRing(double rate) {
    return AnimatedBuilder(
      animation: _chartAnimation,
      builder: (context, _) {
        final animatedRate = rate * _chartAnimation.value;
        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.cardBorder),
          ),
          child: Column(
            children: [
              const Text('Completion Rate',
                  style: TextStyle(
                      color: AppColors.textSecondary, fontSize: 12)),
              const SizedBox(height: 16),
              SizedBox(
                width: 100,
                height: 100,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 100,
                      height: 100,
                      child: CircularProgressIndicator(
                        value: animatedRate,
                        strokeWidth: 8,
                        backgroundColor: AppColors.surfaceHigh,
                        valueColor: const AlwaysStoppedAnimation<Color>(
                            AppColors.primary),
                        strokeCap: StrokeCap.round,
                      ),
                    ),
                    Text(
                      '${(rate * 100).toStringAsFixed(1)}%',
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Text(
                '$_completedTrips / $_totalTrips trips',
                style: const TextStyle(
                    color: AppColors.textHint, fontSize: 11),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCancellationRateCard(double rate) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        children: [
          const Text('Cancellation Rate',
              style:
                  TextStyle(color: AppColors.textSecondary, fontSize: 12)),
          const SizedBox(height: 16),
          SizedBox(
            width: 100,
            height: 100,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 100,
                  height: 100,
                  child: AnimatedBuilder(
                    animation: _chartAnimation,
                    builder: (context, _) {
                      return CircularProgressIndicator(
                        value: rate * _chartAnimation.value,
                        strokeWidth: 8,
                        backgroundColor: AppColors.surfaceHigh,
                        valueColor: AlwaysStoppedAnimation<Color>(
                            AppColors.textSecondary),
                        strokeCap: StrokeCap.round,
                      );
                    },
                  ),
                ),
                Text(
                  '${(rate * 100).toStringAsFixed(1)}%',
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Text(
            '$_cancelledTrips / $_totalTrips trips',
            style:
                const TextStyle(color: AppColors.textHint, fontSize: 11),
          ),
        ],
      ),
    );
  }

  // ─── Revenue by Vehicle ───────────────────────────────────────────

  Widget _buildRevenueByVehicle() {
    if (_revenueByVehicle.isEmpty) {
      return _emptyState('No completed trips in this period');
    }

    return Column(
      children: _revenueByVehicle.entries.map((e) {
        final pct = _totalRevenue > 0 ? e.value / _totalRevenue : 0.0;
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.cardBorder),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Text(e.key,
                      style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w600)),
                  const Spacer(),
                  Text('\$${e.value.toStringAsFixed(2)}',
                      style: const TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w700)),
                  const SizedBox(width: 8),
                  Text('${(pct * 100).toStringAsFixed(0)}%',
                      style: const TextStyle(
                          color: AppColors.textHint, fontSize: 12)),
                ],
              ),
              const SizedBox(height: 8),
              AnimatedBuilder(
                animation: _chartAnimation,
                builder: (context, _) {
                  return ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: pct * _chartAnimation.value,
                      backgroundColor: AppColors.surfaceHigh,
                      valueColor:
                          const AlwaysStoppedAnimation(AppColors.primary),
                      minHeight: 6,
                    ),
                  );
                },
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  // ─── Payment Method Breakdown ─────────────────────────────────────

  Widget _buildPaymentBreakdown() {
    if (_paymentMethodCounts.isEmpty) {
      return _emptyState('No payment data for this period');
    }

    final total =
        _paymentMethodCounts.values.fold<int>(0, (a, b) => a + b);
    final sortedEntries = _paymentMethodCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final colors = [
      AppColors.primary,
      AppColors.primaryLight,
      AppColors.textPrimary,
      AppColors.textSecondary,
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Row(
        children: [
          // Pie chart
          SizedBox(
            width: 120,
            height: 120,
            child: PieChart(
              PieChartData(
                sectionsSpace: 2,
                centerSpaceRadius: 28,
                sections: List.generate(sortedEntries.length, (i) {
                  final pct = sortedEntries[i].value / total;
                  return PieChartSectionData(
                    value: sortedEntries[i].value.toDouble(),
                    color: colors[i % colors.length],
                    radius: 28,
                    showTitle: false,
                  );
                }),
              ),
            ),
          ),
          const SizedBox(width: 20),
          // Legend
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: List.generate(sortedEntries.length, (i) {
                final entry = sortedEntries[i];
                final pct = (entry.value / total * 100).toStringAsFixed(1);
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: colors[i % colors.length],
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(entry.key,
                            style: const TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: 13)),
                      ),
                      Text('${entry.value}',
                          style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 12,
                              fontWeight: FontWeight.w600)),
                      const SizedBox(width: 6),
                      Text('$pct%',
                          style: const TextStyle(
                              color: AppColors.textHint, fontSize: 11)),
                    ],
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Cancellation Analytics ───────────────────────────────────────

  Widget _buildCancellationAnalytics() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Cancellation reasons breakdown
        if (_cancelReasons.isNotEmpty) ...[
          _buildSubHeader('Reasons'),
          const SizedBox(height: 8),
          _buildCancelReasons(),
          const SizedBox(height: 16),
        ],

        // Top cancellation hours
        if (_cancellationByHour.isNotEmpty) ...[
          _buildSubHeader('Peak Cancellation Hours'),
          const SizedBox(height: 8),
          _buildCancellationHours(),
        ],
      ],
    );
  }

  Widget _buildCancelReasons() {
    final sorted = _cancelReasons.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final maxCount =
        sorted.isEmpty ? 1 : sorted.first.value;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        children: sorted.map((e) {
          final pct =
              _cancelledTrips > 0 ? e.value / _cancelledTrips * 100 : 0.0;
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 5),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(e.key,
                          style: const TextStyle(
                              color: AppColors.textPrimary, fontSize: 13),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                    ),
                    const SizedBox(width: 8),
                    Text('${e.value}',
                        style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 12,
                            fontWeight: FontWeight.w600)),
                    const SizedBox(width: 4),
                    Text('(${pct.toStringAsFixed(0)}%)',
                        style: const TextStyle(
                            color: AppColors.textHint, fontSize: 11)),
                  ],
                ),
                const SizedBox(height: 4),
                ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: LinearProgressIndicator(
                    value: e.value / maxCount,
                    backgroundColor: AppColors.surfaceHigh,
                    valueColor: AlwaysStoppedAnimation(
                        AppColors.textSecondary),
                    minHeight: 4,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildCancellationHours() {
    // Sort by hour and show top hours
    final sorted = _cancellationByHour.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final top = sorted.take(8).toList()..sort((a, b) => a.key.compareTo(b.key));
    final maxCount = sorted.isEmpty ? 1 : sorted.first.value;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        children: top.map((e) {
          final hourLabel = e.key == 0
              ? '12 AM'
              : e.key < 12
                  ? '${e.key} AM'
                  : e.key == 12
                      ? '12 PM'
                      : '${e.key - 12} PM';
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Row(
              children: [
                SizedBox(
                  width: 50,
                  child: Text(hourLabel,
                      style: const TextStyle(
                          color: AppColors.textSecondary, fontSize: 12)),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: LinearProgressIndicator(
                      value: e.value / maxCount,
                      backgroundColor: AppColors.surfaceHigh,
                      valueColor: AlwaysStoppedAnimation(
                          AppColors.textSecondary),
                      minHeight: 14,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 24,
                  child: Text('${e.value}',
                      style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 12,
                          fontWeight: FontWeight.w600),
                      textAlign: TextAlign.right),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  // ─── Helpers ──────────────────────────────────────────────────────

  Widget _buildSectionHeader(String title, IconData icon) {
    return Column(
      children: [
        Container(height: 1, color: AppColors.surfaceHigh),
        const SizedBox(height: 16),
        Row(
          children: [
            Icon(icon, color: AppColors.primary, size: 18),
            const SizedBox(width: 8),
            Text(title,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                )),
          ],
        ),
      ],
    );
  }

  Widget _buildSubHeader(String title) {
    return Text(title,
        style: const TextStyle(
          color: AppColors.textSecondary,
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ));
  }

  Widget _emptyState(String msg) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(msg,
          textAlign: TextAlign.center,
          style: const TextStyle(color: AppColors.textHint, fontSize: 13)),
    );
  }
}

// ─── Data class for summary cards ─────────────────────────────────────

class _SummaryData {
  final String label;
  final String value;
  final Color color;
  final IconData icon;

  const _SummaryData(this.label, this.value, this.color, this.icon);
}
