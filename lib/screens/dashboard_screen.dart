import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../config/app_theme.dart';
import '../config/page_transitions.dart';
import '../providers/auth_provider.dart';
import '../providers/dashboard_provider.dart';
import '../providers/trip_provider.dart';
import '../widgets/stat_card.dart';
import 'trip_list_screen.dart';
import 'create_trip_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});
  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<DashboardProvider>().loadDashboardData();
      context.read<TripProvider>().startListening();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: const [
          TripListScreen(),
          _StatsContent(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (i) => setState(() => _currentIndex = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.directions_car_outlined), selectedIcon: Icon(Icons.directions_car), label: 'Trips'),
          NavigationDestination(icon: Icon(Icons.bar_chart_outlined), selectedIcon: Icon(Icons.bar_chart), label: 'Stats'),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(context, scaleExpandRoute(const CreateTripScreen())),
        icon: const Icon(Icons.add_rounded),
        label: const Text('New Trip', style: TextStyle(fontWeight: FontWeight.w700)),
      ),
    );
  }
}

class _StatsContent extends StatelessWidget {
  const _StatsContent();

  @override
  Widget build(BuildContext context) {
    final dash = context.watch<DashboardProvider>();
    final trips = context.watch<TripProvider>();
    final auth = context.read<AuthProvider>();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Stats'),
        backgroundColor: AppColors.background,
        actions: [
          IconButton(icon: const Icon(Icons.refresh_rounded), onPressed: dash.refresh),
          PopupMenuButton<String>(
            onSelected: (v) { if (v == 'logout') auth.signOut(); },
            icon: const Icon(Icons.more_vert_rounded),
            color: AppColors.surface,
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'logout', child: Row(children: [Icon(Icons.logout_rounded, color: AppColors.error, size: 18), SizedBox(width: 10), Text('Sign Out', style: TextStyle(color: AppColors.textPrimary))])),
            ],
          ),
        ],
      ),
      body: dash.isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : RefreshIndicator(
              color: AppColors.primary,
              backgroundColor: AppColors.surface,
              onRefresh: dash.refresh,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildStatsGrid(context, dash, trips),
                    const SizedBox(height: 24),
                    _sectionTitle('Trips This Week'),
                    const SizedBox(height: 12),
                    _buildWeeklyChart(context, dash),
                    const SizedBox(height: 24),
                    _sectionTitle('Weekly Revenue'),
                    const SizedBox(height: 12),
                    _buildRevenueChart(context, dash),
                    const SizedBox(height: 24),
                    _buildSummaryCard(context, dash),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _sectionTitle(String text) {
    return Text(text, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: AppColors.textPrimary));
  }

  Widget _buildStatsGrid(BuildContext context, DashboardProvider dash, TripProvider trips) {
    final fmt = NumberFormat.currency(symbol: '\$', decimalDigits: 0);
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 1.1,
      children: [
        StatCard(title: "Today's Trips", value: dash.todayTrips.toString(), icon: Icons.today_rounded, color: AppColors.primary, subtitle: '${dash.todayCompleted} completed'),
        StatCard(title: 'Active Rides', value: trips.activeCount.toString(), icon: Icons.directions_car_rounded, color: AppColors.inProgress, subtitle: '${trips.requestedCount} pending'),
        StatCard(title: "Today's Revenue", value: fmt.format(dash.todayRevenue), icon: Icons.attach_money_rounded, color: AppColors.success),
        StatCard(
          title: 'Completion Rate',
          value: '${dash.todayCompletionRate.toStringAsFixed(0)}%',
          icon: Icons.check_circle_outline_rounded,
          color: dash.todayCompletionRate >= 80 ? AppColors.success : AppColors.warning,
          subtitle: '${dash.todayCancelled} cancelled',
        ),
      ],
    );
  }

  Widget _buildWeeklyChart(BuildContext context, DashboardProvider dash) {
    if (dash.weeklyData.isEmpty) {
      return _emptyChart('No data available');
    }
    return Container(
      height: 220,
      padding: const EdgeInsets.fromLTRB(12, 16, 16, 8),
      decoration: _chartDecoration(),
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          maxY: _maxY(dash.weeklyData),
          barTouchData: BarTouchData(
            enabled: true,
            touchTooltipData: BarTouchTooltipData(
              getTooltipItem: (group, gi, rod, ri) {
                final d = dash.weeklyData[gi];
                return BarTooltipItem('${d['total']} trips\n${d['completed']} done', const TextStyle(color: Colors.white, fontSize: 12));
              },
            ),
          ),
          titlesData: FlTitlesData(
            bottomTitles: AxisTitles(sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (v, m) {
                final i = v.toInt();
                if (i >= 0 && i < dash.weeklyData.length) {
                  return Padding(padding: const EdgeInsets.only(top: 6), child: Text(DateFormat('EEE').format(dash.weeklyData[i]['date'] as DateTime), style: const TextStyle(fontSize: 11, color: AppColors.textHint)));
                }
                return const SizedBox.shrink();
              },
            )),
            leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 28, getTitlesWidget: (v, m) => Text(v.toInt().toString(), style: const TextStyle(fontSize: 10, color: AppColors.textHint)))),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          borderData: FlBorderData(show: false),
          gridData: FlGridData(show: true, drawVerticalLine: false, getDrawingHorizontalLine: (_) => const FlLine(color: AppColors.cardBorder, strokeWidth: 1)),
          barGroups: dash.weeklyData.asMap().entries.map((e) => BarChartGroupData(
            x: e.key,
            barRods: [
              BarChartRodData(toY: (e.value['completed'] as int).toDouble(), color: AppColors.success, width: 11, borderRadius: const BorderRadius.vertical(top: Radius.circular(4))),
              BarChartRodData(toY: (e.value['cancelled'] as int).toDouble(), color: AppColors.cancelled, width: 11, borderRadius: const BorderRadius.vertical(top: Radius.circular(4))),
            ],
          )).toList(),
        ),
      ),
    );
  }

  Widget _buildRevenueChart(BuildContext context, DashboardProvider dash) {
    if (dash.weeklyData.isEmpty) return const SizedBox.shrink();
    return Container(
      height: 200,
      padding: const EdgeInsets.fromLTRB(4, 16, 16, 8),
      decoration: _chartDecoration(),
      child: LineChart(LineChartData(
        gridData: FlGridData(show: true, drawVerticalLine: false, getDrawingHorizontalLine: (_) => const FlLine(color: AppColors.cardBorder, strokeWidth: 1)),
        titlesData: FlTitlesData(
          bottomTitles: AxisTitles(sideTitles: SideTitles(
            showTitles: true,
            getTitlesWidget: (v, m) {
              final i = v.toInt();
              if (i >= 0 && i < dash.weeklyData.length) {
                return Padding(padding: const EdgeInsets.only(top: 6), child: Text(DateFormat('EEE').format(dash.weeklyData[i]['date'] as DateTime), style: const TextStyle(fontSize: 11, color: AppColors.textHint)));
              }
              return const SizedBox.shrink();
            },
          )),
          leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 42, getTitlesWidget: (v, m) => Text('\$${v.toInt()}', style: const TextStyle(fontSize: 10, color: AppColors.textHint)))),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        borderData: FlBorderData(show: false),
        lineBarsData: [
          LineChartBarData(
            spots: dash.weeklyData.asMap().entries.map((e) => FlSpot(e.key.toDouble(), e.value['revenue'] as double)).toList(),
            isCurved: true,
            color: AppColors.primary,
            barWidth: 3,
            isStrokeCapRound: true,
            dotData: FlDotData(show: true, getDotPainter: (s, p, b, i) => FlDotCirclePainter(radius: 4, color: AppColors.primary, strokeWidth: 2, strokeColor: AppColors.surface)),
            belowBarData: BarAreaData(show: true, color: AppColors.primary.withValues(alpha: 0.08)),
          ),
        ],
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipItems: (spots) => spots.map((s) => LineTooltipItem('\$${s.y.toStringAsFixed(0)}', const TextStyle(color: Colors.white, fontWeight: FontWeight.w600))).toList(),
          ),
        ),
      )),
    );
  }

  Widget _buildSummaryCard(BuildContext context, DashboardProvider dash) {
    final fmt = NumberFormat.currency(symbol: '\$', decimalDigits: 0);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.cardBorder)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Summary', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
          const SizedBox(height: 16),
          _statRow('Trips this week', dash.weekTrips.toString(), Icons.date_range_rounded),
          const Divider(color: AppColors.divider, height: 20),
          _statRow('Trips this month', dash.monthTrips.toString(), Icons.calendar_month_rounded),
          const Divider(color: AppColors.divider, height: 20),
          _statRow('Week revenue', fmt.format(dash.weekRevenue), Icons.trending_up_rounded, color: AppColors.success),
          const Divider(color: AppColors.divider, height: 20),
          _statRow('Month revenue', fmt.format(dash.monthRevenue), Icons.account_balance_wallet_rounded, color: AppColors.success),
        ],
      ),
    );
  }

  Widget _statRow(String label, String value, IconData icon, {Color? color}) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppColors.textSecondary),
        const SizedBox(width: 12),
        Expanded(child: Text(label, style: const TextStyle(fontSize: 14, color: AppColors.textSecondary))),
        Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: color ?? AppColors.textPrimary)),
      ],
    );
  }

  Widget _emptyChart(String msg) {
    return Container(
      height: 160,
      decoration: _chartDecoration(),
      child: Center(child: Text(msg, style: const TextStyle(color: AppColors.textHint))),
    );
  }

  BoxDecoration _chartDecoration() {
    return BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.cardBorder));
  }

  double _maxY(List<Map<String, dynamic>> data) {
    if (data.isEmpty) return 10;
    double max = 0;
    for (final d in data) { final t = (d['total'] as int).toDouble(); if (t > max) max = t; }
    return max < 5 ? 5 : max + 2;
  }
}
