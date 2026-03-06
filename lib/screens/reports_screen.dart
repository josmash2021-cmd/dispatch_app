import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:csv/csv.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import '../config/app_theme.dart';
import '../models/trip_model.dart';

/// Financial reports screen with totals, breakdowns, and CSV export.
class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
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
  Map<String, int> _tripsByDay = {};

  @override
  void initState() {
    super.initState();
    _loadReport();
  }

  Future<void> _loadReport() async {
    setState(() => _loading = true);
    try {
      final snap = await _db
          .collection('trips')
          .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(_startDate))
          .where('createdAt', isLessThanOrEqualTo: Timestamp.fromDate(
            DateTime(_endDate.year, _endDate.month, _endDate.day, 23, 59, 59),
          ))
          .orderBy('createdAt', descending: true)
          .get();

      final trips = snap.docs.map((d) => TripModel.fromFirestore(d)).toList();

      double total = 0;
      int completed = 0;
      int cancelled = 0;
      final byVehicle = <String, double>{};
      final byDay = <String, int>{};

      for (final t in trips) {
        if (t.status == TripStatus.completed) {
          completed++;
          total += t.fare;
          byVehicle[t.vehicleType] = (byVehicle[t.vehicleType] ?? 0) + t.fare;
        }
        if (t.status == TripStatus.cancelled) cancelled++;

        final dayKey = DateFormat('MM/dd').format(t.createdAt);
        byDay[dayKey] = (byDay[dayKey] ?? 0) + 1;
      }

      setState(() {
        _trips = trips;
        _totalRevenue = total;
        _totalTrips = trips.length;
        _completedTrips = completed;
        _cancelledTrips = cancelled;
        _avgFare = completed > 0 ? total / completed : 0;
        _revenueByVehicle = byVehicle;
        _tripsByDay = byDay;
        _loading = false;
      });
    } catch (e) {
      debugPrint('Error loading report: $e');
      setState(() => _loading = false);
    }
  }

  Future<void> _exportCsv() async {
    try {
      final rows = <List<dynamic>>[
        ['Trip ID', 'Passenger', 'Pickup', 'Dropoff', 'Vehicle', 'Fare', 'Status', 'Date'],
        ..._trips.map((t) => [
          t.tripId,
          t.passengerName,
          t.pickupAddress,
          t.dropoffAddress,
          t.vehicleType,
          t.fare.toStringAsFixed(2),
          t.status.label,
          DateFormat('yyyy-MM-dd HH:mm').format(t.createdAt),
        ]),
      ];

      final csv = const ListToCsvConverter().convert(rows);
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/cruise_report_${DateFormat('yyyyMMdd').format(DateTime.now())}.csv');
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
    final dateRange = '${DateFormat('MMM d').format(_startDate)} — ${DateFormat('MMM d, y').format(_endDate)}';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Financial Reports'),
        backgroundColor: AppColors.background,
        actions: [
          IconButton(
            icon: const Icon(Icons.file_download_outlined, color: AppColors.primary),
            tooltip: 'Export CSV',
            onPressed: _exportCsv,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Date range picker
                  GestureDetector(
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
                          Text(dateRange, style: const TextStyle(color: AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.w500)),
                          const Spacer(),
                          const Icon(Icons.edit, color: AppColors.textHint, size: 16),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Summary cards
                  Row(
                    children: [
                      Expanded(child: _summaryCard('Revenue', '\$${_totalRevenue.toStringAsFixed(2)}', AppColors.primary)),
                      const SizedBox(width: 10),
                      Expanded(child: _summaryCard('Avg Fare', '\$${_avgFare.toStringAsFixed(2)}', AppColors.accent)),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(child: _summaryCard('Total Trips', '$_totalTrips', AppColors.textPrimary)),
                      const SizedBox(width: 10),
                      Expanded(child: _summaryCard('Completed', '$_completedTrips', AppColors.completed)),
                      const SizedBox(width: 10),
                      Expanded(child: _summaryCard('Cancelled', '$_cancelledTrips', AppColors.cancelled)),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // Revenue by vehicle type
                  _sectionTitle('Revenue by Vehicle'),
                  const SizedBox(height: 8),
                  if (_revenueByVehicle.isEmpty)
                    _emptyState('No completed trips in this period')
                  else
                    ..._revenueByVehicle.entries.map((e) {
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
                                Text(e.key, style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600)),
                                const Spacer(),
                                Text('\$${e.value.toStringAsFixed(2)}',
                                  style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700)),
                                const SizedBox(width: 8),
                                Text('${(pct * 100).toStringAsFixed(0)}%',
                                  style: const TextStyle(color: AppColors.textHint, fontSize: 12)),
                              ],
                            ),
                            const SizedBox(height: 8),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: pct,
                                backgroundColor: AppColors.surfaceHigh,
                                valueColor: const AlwaysStoppedAnimation(AppColors.primary),
                                minHeight: 6,
                              ),
                            ),
                          ],
                        ),
                      );
                    }),

                  const SizedBox(height: 24),

                  // Trips by day
                  _sectionTitle('Trips by Day'),
                  const SizedBox(height: 8),
                  if (_tripsByDay.isEmpty)
                    _emptyState('No trips in this period')
                  else
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.cardBorder),
                      ),
                      child: Column(
                        children: _tripsByDay.entries.take(15).map((e) {
                          final maxTrips = _tripsByDay.values.fold(1, (a, b) => a > b ? a : b);
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Row(
                              children: [
                                SizedBox(width: 50, child: Text(e.key, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12))),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(3),
                                    child: LinearProgressIndicator(
                                      value: e.value / maxTrips,
                                      backgroundColor: AppColors.surfaceHigh,
                                      valueColor: const AlwaysStoppedAnimation(AppColors.primary),
                                      minHeight: 16,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                SizedBox(width: 24, child: Text('${e.value}',
                                  style: const TextStyle(color: AppColors.textPrimary, fontSize: 12, fontWeight: FontWeight.w600),
                                  textAlign: TextAlign.right)),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    ),

                  const SizedBox(height: 40),
                ],
              ),
            ),
    );
  }

  Widget _summaryCard(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 11)),
          const SizedBox(height: 6),
          Text(value, style: TextStyle(color: color, fontSize: 20, fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Text(title, style: const TextStyle(
      color: AppColors.textPrimary,
      fontSize: 16,
      fontWeight: FontWeight.w700,
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
      child: Text(msg, textAlign: TextAlign.center,
        style: const TextStyle(color: AppColors.textHint, fontSize: 13)),
    );
  }
}
