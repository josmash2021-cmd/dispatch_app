import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../config/app_theme.dart';
import '../config/page_transitions.dart';
import '../services/dispatch_api_service.dart';
import 'alerts_screen.dart';

class SystemHealthScreen extends StatefulWidget {
  const SystemHealthScreen({super.key});

  @override
  State<SystemHealthScreen> createState() => _SystemHealthScreenState();
}

class _SystemHealthScreenState extends State<SystemHealthScreen>
    with SingleTickerProviderStateMixin {
  // ── Animation ──────────────────────────────────────────
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  // ── State ──────────────────────────────────────────────
  bool _serverOnline = true;
  bool _apiHealthy = true;
  bool _firestoreConnected = true;
  bool _checkingHealth = false;
  DateTime? _lastChecked;
  DateTime? _lastSuccessfulApiCall;

  // Live metrics
  int _onlineDrivers = 0;
  int _activeTrips = 0;
  int _unreadAlerts = 0;

  // Recent alerts
  List<DocumentSnapshot> _recentAlerts = [];

  // ── Subscriptions & Timer ──────────────────────────────
  Timer? _refreshTimer;
  StreamSubscription<bool>? _onlineSub;
  StreamSubscription<QuerySnapshot>? _driversSub;
  StreamSubscription<QuerySnapshot>? _tripsSub;
  StreamSubscription<QuerySnapshot>? _alertsSub;
  StreamSubscription<QuerySnapshot>? _unreadAlertsSub;

  // Severity colors (matching alerts screen)
  static const _severityColors = {
    'critical': Color(0xFFEF4444),
    'high': Color(0xFFF97316),
    'medium': Color(0xFFEAB308),
    'low': Color(0xFF22C55E),
  };

  @override
  void initState() {
    super.initState();
    _initPulseAnimation();
    _performHealthCheck();
    _startAutoRefresh();
    _listenToOnlineStatus();
    _listenToFirestoreMetrics();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _refreshTimer?.cancel();
    _onlineSub?.cancel();
    _driversSub?.cancel();
    _tripsSub?.cancel();
    _alertsSub?.cancel();
    _unreadAlertsSub?.cancel();
    super.dispose();
  }

  // ═════════════════════════════════════════════════════════
  //  ANIMATION
  // ═════════════════════════════════════════════════════════

  void _initPulseAnimation() {
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _pulseAnimation = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _pulseController.repeat(reverse: true);
  }

  // ═════════════════════════════════════════════════════════
  //  HEALTH CHECK
  // ═════════════════════════════════════════════════════════

  Future<void> _performHealthCheck() async {
    if (_checkingHealth) return;
    setState(() => _checkingHealth = true);

    try {
      final healthy = await DispatchApiService.healthCheck();
      if (!mounted) return;
      setState(() {
        _serverOnline = healthy;
        _apiHealthy = healthy;
        _lastChecked = DateTime.now();
        if (healthy) _lastSuccessfulApiCall = DateTime.now();
        _checkingHealth = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _serverOnline = false;
        _apiHealthy = false;
        _lastChecked = DateTime.now();
        _checkingHealth = false;
      });
    }
  }

  void _startAutoRefresh() {
    _refreshTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => _performHealthCheck(),
    );
  }

  // ═════════════════════════════════════════════════════════
  //  FIRESTORE LISTENERS
  // ═════════════════════════════════════════════════════════

  void _listenToOnlineStatus() {
    _onlineSub = DispatchApiService.onlineStream.listen((online) {
      if (!mounted) return;
      setState(() => _serverOnline = online);
    });
  }

  void _listenToFirestoreMetrics() {
    final firestore = FirebaseFirestore.instance;

    // Online drivers
    _driversSub = firestore
        .collection('drivers')
        .where('status', isEqualTo: 'online')
        .snapshots()
        .listen(
      (snap) {
        if (!mounted) return;
        setState(() {
          _onlineDrivers = snap.docs.length;
          _firestoreConnected = true;
        });
      },
      onError: (_) {
        if (!mounted) return;
        setState(() => _firestoreConnected = false);
      },
    );

    // Active trips
    _tripsSub = firestore
        .collection('trips')
        .where('status', whereIn: ['accepted', 'arrived', 'in_progress'])
        .snapshots()
        .listen(
      (snap) {
        if (!mounted) return;
        setState(() => _activeTrips = snap.docs.length);
      },
      onError: (_) {},
    );

    // Unread alerts count
    _unreadAlertsSub = firestore
        .collection('admin_alerts')
        .where('read', isEqualTo: false)
        .snapshots()
        .listen(
      (snap) {
        if (!mounted) return;
        setState(() => _unreadAlerts = snap.docs.length);
      },
      onError: (_) {},
    );

    // Recent alerts (last 5)
    _alertsSub = firestore
        .collection('admin_alerts')
        .orderBy('createdAt', descending: true)
        .limit(5)
        .snapshots()
        .listen(
      (snap) {
        if (!mounted) return;
        setState(() => _recentAlerts = snap.docs);
      },
      onError: (_) {},
    );
  }

  // ═════════════════════════════════════════════════════════
  //  BUILD
  // ═════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        title: const Text(
          'System Health',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
        actions: [
          IconButton(
            icon: _checkingHealth
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.primary,
                    ),
                  )
                : const Icon(Icons.refresh, color: AppColors.primary),
            onPressed: _checkingHealth ? null : _performHealthCheck,
            tooltip: 'Refresh health check',
          ),
        ],
      ),
      body: RefreshIndicator(
        color: AppColors.primary,
        backgroundColor: AppColors.surface,
        onRefresh: _performHealthCheck,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          children: [
            _buildServerStatusCard(),
            const SizedBox(height: 16),
            _buildMetricsGrid(),
            const SizedBox(height: 16),
            _buildRecentAlertsSection(),
            const SizedBox(height: 16),
            _buildConnectionStatusSection(),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  // ═════════════════════════════════════════════════════════
  //  SERVER STATUS CARD
  // ═════════════════════════════════════════════════════════

  Widget _buildServerStatusCard() {
    final statusColor =
        _serverOnline ? const Color(0xFF22C55E) : const Color(0xFFEF4444);
    final statusText = _serverOnline ? 'Server Online' : 'Server Offline';

    return AnimatedContainer(
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeInOut,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: statusColor.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          // Pulsing status dot
          AnimatedBuilder(
            animation: _pulseAnimation,
            builder: (context, child) {
              return Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: statusColor.withOpacity(
                    _serverOnline ? _pulseAnimation.value * 0.3 : 0.3,
                  ),
                ),
                child: Center(
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 500),
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: statusColor,
                      boxShadow: _serverOnline
                          ? [
                              BoxShadow(
                                color: statusColor.withOpacity(
                                  _pulseAnimation.value * 0.6,
                                ),
                                blurRadius: 12,
                                spreadRadius: 2,
                              ),
                            ]
                          : null,
                    ),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 16),
          // Status text
          AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 400),
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: statusColor,
            ),
            child: Text(statusText),
          ),
          const SizedBox(height: 8),
          // Last checked
          Text(
            _lastChecked != null
                ? 'Last checked: ${DateFormat('h:mm:ss a').format(_lastChecked!)}'
                : 'Checking...',
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 13,
            ),
          ),
          if (_checkingHealth) ...[
            const SizedBox(height: 12),
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppColors.primary,
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ═════════════════════════════════════════════════════════
  //  METRICS GRID (2x2)
  // ═════════════════════════════════════════════════════════

  Widget _buildMetricsGrid() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(left: 4, bottom: 12),
          child: Text(
            'Live Metrics',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 17,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Row(
          children: [
            Expanded(
              child: _buildMetricCard(
                icon: Icons.local_taxi,
                label: 'Online Drivers',
                value: '$_onlineDrivers',
                color: const Color(0xFF22C55E),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildMetricCard(
                icon: Icons.route,
                label: 'Active Trips',
                value: '$_activeTrips',
                color: AppColors.primary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildMetricCard(
                icon: Icons.notifications_active,
                label: 'Unread Alerts',
                value: '$_unreadAlerts',
                color: _unreadAlerts > 0
                    ? const Color(0xFFF97316)
                    : AppColors.textSecondary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildMetricCard(
                icon: Icons.api,
                label: 'API Status',
                value: _apiHealthy ? 'Healthy' : 'Down',
                color: _apiHealthy
                    ? const Color(0xFF22C55E)
                    : const Color(0xFFEF4444),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMetricCard({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.surfaceHigh, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 12),
          AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 300),
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: color,
            ),
            child: Text(value),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  // ═════════════════════════════════════════════════════════
  //  RECENT ALERTS
  // ═════════════════════════════════════════════════════════

  Widget _buildRecentAlertsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Padding(
              padding: EdgeInsets.only(left: 4),
              child: Text(
                'Recent Alerts',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).push(
                  slideFromRightRoute(const AlertsScreen()),
                );
              },
              child: const Text(
                'View All',
                style: TextStyle(color: AppColors.primary, fontSize: 13),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (_recentAlerts.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Text(
              'No recent alerts',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textHint, fontSize: 14),
            ),
          )
        else
          Container(
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(12),
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: List.generate(_recentAlerts.length, (i) {
                final doc = _recentAlerts[i];
                final data = doc.data() as Map<String, dynamic>? ?? {};
                return _buildAlertTile(data, isLast: i == _recentAlerts.length - 1);
              }),
            ),
          ),
      ],
    );
  }

  Widget _buildAlertTile(Map<String, dynamic> data, {bool isLast = false}) {
    final severity = (data['severity'] as String?) ?? 'medium';
    final type = (data['type'] as String?) ?? '';
    final message = (data['message'] as String?) ?? 'Alert';
    final isRead = (data['read'] as bool?) ?? false;
    final createdAt = data['createdAt'] as Timestamp?;
    final severityColor = _severityColors[severity] ?? AppColors.textSecondary;

    String timeAgo = '';
    if (createdAt != null) {
      final diff = DateTime.now().difference(createdAt.toDate());
      if (diff.inMinutes < 1) {
        timeAgo = 'just now';
      } else if (diff.inMinutes < 60) {
        timeAgo = '${diff.inMinutes}m ago';
      } else if (diff.inHours < 24) {
        timeAgo = '${diff.inHours}h ago';
      } else {
        timeAgo = '${diff.inDays}d ago';
      }
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        border: isLast
            ? null
            : const Border(
                bottom: BorderSide(color: AppColors.surfaceHigh, width: 1),
              ),
      ),
      child: Row(
        children: [
          // Severity indicator
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: severityColor,
            ),
          ),
          const SizedBox(width: 12),
          // Content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  message,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: isRead
                        ? AppColors.textSecondary
                        : AppColors.textPrimary,
                    fontSize: 14,
                    fontWeight: isRead ? FontWeight.w400 : FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Text(
                      severity.toUpperCase(),
                      style: TextStyle(
                        color: severityColor,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (type.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      Text(
                        type.replaceAll('_', ' '),
                        style: const TextStyle(
                          color: AppColors.textHint,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          if (timeAgo.isNotEmpty)
            Text(
              timeAgo,
              style: const TextStyle(
                color: AppColors.textHint,
                fontSize: 11,
              ),
            ),
        ],
      ),
    );
  }

  // ═════════════════════════════════════════════════════════
  //  CONNECTION STATUS
  // ═════════════════════════════════════════════════════════

  Widget _buildConnectionStatusSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(left: 4, bottom: 12),
          child: Text(
            'Connection Status',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 17,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(12),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              _buildConnectionRow(
                label: 'Backend API',
                isConnected: _serverOnline,
                icon: Icons.dns,
              ),
              Container(height: 1, color: AppColors.surfaceHigh),
              _buildConnectionRow(
                label: 'Firestore',
                isConnected: _firestoreConnected,
                icon: Icons.cloud,
              ),
              Container(height: 1, color: AppColors.surfaceHigh),
              _buildLastApiCallRow(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildConnectionRow({
    required String label,
    required bool isConnected,
    required IconData icon,
  }) {
    final color =
        isConnected ? const Color(0xFF22C55E) : const Color(0xFFEF4444);
    final statusLabel = isConnected ? 'Connected' : 'Disconnected';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Icon(icon, color: AppColors.textSecondary, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 14,
              ),
            ),
          ),
          AnimatedContainer(
            duration: const Duration(milliseconds: 400),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: color,
                  ),
                ),
                const SizedBox(width: 6),
                AnimatedDefaultTextStyle(
                  duration: const Duration(milliseconds: 300),
                  style: TextStyle(
                    color: color,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                  child: Text(statusLabel),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLastApiCallRow() {
    final timeStr = _lastSuccessfulApiCall != null
        ? DateFormat('h:mm:ss a').format(_lastSuccessfulApiCall!)
        : 'Never';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          const Icon(Icons.schedule, color: AppColors.textSecondary, size: 20),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Last Successful API Call',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 14,
              ),
            ),
          ),
          Text(
            timeStr,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}
