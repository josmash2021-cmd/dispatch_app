import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../config/app_theme.dart';
import '../config/page_transitions.dart';
import '../providers/auth_provider.dart';
import '../providers/client_provider.dart';
import '../providers/dashboard_provider.dart';
import '../providers/driver_provider.dart';
import '../providers/trip_provider.dart';
import '../providers/verification_provider.dart';
import '../services/notification_service.dart';
import '../widgets/stat_card.dart';
import 'riders_screen.dart';
import 'drivers_screen.dart';
import 'driver_reports_screen.dart';
import 'home_menu_screen.dart';
import 'trip_list_screen.dart';
import 'create_trip_screen.dart';
import 'database_screen.dart';
import 'admin_config_screen.dart';
import 'fleet_map_screen.dart';
import 'reports_screen.dart';
import 'scheduled_rides_screen.dart';
import 'support_chats_screen.dart';
import 'verification_review_screen.dart';
import 'audit_logs_screen.dart';
import 'blocked_users_screen.dart';
import 'pricing_config_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});
  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with TickerProviderStateMixin {
  int _currentIndex = 0;
  int _previousIndex = 0;
  final Set<int> _visitedPages = {0};
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  late AnimationController _fadeCtrl;
  late Animation<double> _fadeAnim;
  late AnimationController _fabCtrl;
  late Animation<double> _fabScale;

  StreamSubscription<QuerySnapshot>? _notifSub;
  StreamSubscription<NotificationEvent>? _notificationStreamSub;

  static const _navItems = [
    _NavItem(Icons.home_outlined, Icons.home, 'Inicio'),
    _NavItem(Icons.directions_car_outlined, Icons.directions_car, 'Viajes'),
    _NavItem(Icons.map_outlined, Icons.map, 'Mapa Fleet'),
    _NavItem(Icons.person_outline, Icons.person, 'Riders'),
    _NavItem(Icons.local_taxi_outlined, Icons.local_taxi, 'Drivers'),
    _NavItem(Icons.verified_user_outlined, Icons.verified_user, 'Verif. Riders'),
    _NavItem(Icons.local_taxi_rounded, Icons.local_taxi, 'Verif. Drivers'),
    _NavItem(Icons.analytics_outlined, Icons.analytics, 'Analytics'),
    _NavItem(Icons.report_problem_outlined, Icons.report_problem, 'Rep. Drivers'),
    _NavItem(Icons.chat_outlined, Icons.chat_rounded, 'Soporte'),
    _NavItem(Icons.calendar_today_outlined, Icons.calendar_today, 'Agendados'),
    _NavItem(Icons.settings_outlined, Icons.settings, 'Config'),
    _NavItem(Icons.security_outlined, Icons.security, 'Audit Logs'),
    _NavItem(Icons.local_offer_outlined, Icons.local_offer, 'Pricing'),
    _NavItem(Icons.block_outlined, Icons.block, 'Blocked Users'),
  ];

  List<Widget> get _pages => [
    HomeMenuScreen(onNavigate: _onTabChanged),
    const TripListScreen(),
    const FleetMapScreen(),
    const RidersScreen(showAppBar: false),
    const DriversScreen(showAppBar: false),
    const VerificationReviewScreen(),
    const VerificationReviewScreen(),
    const _StatsContent(),  // Analytics (Stats + Reportes)
    const DriverReportsScreen(showAppBar: false),  // NUEVO: Reportes de Drivers (crashes, bugs)
    const SupportChatsScreen(),
    const ScheduledRidesScreen(),
    const AdminConfigScreen(),
    const AuditLogsScreen(),  // NEW: Audit Logs
    const PricingConfigScreen(),  // NEW: Pricing Configuration
    const BlockedUsersScreen(),  // NEW: Blocked Users
  ];

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 260),
    );
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOutCubic);
    _fadeCtrl.value = 1.0;

    _fabCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    );
    _fabScale = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _fabCtrl, curve: Curves.easeOutBack));
    _fabCtrl.value = 1.0;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<DashboardProvider>().loadDashboardData();
      context.read<TripProvider>().startListening();
      context.read<ClientProvider>().startListening();
      context.read<DriverProvider>().startListening();
      context.read<VerificationProvider>().startListening();
      _startNotificationListener();
      _startProfileChangeListener();
      _startNotificationService();
    });
  }

  void _startNotificationListener() {
    _notifSub = FirebaseFirestore.instance
        .collection('dispatch_notifications')
        .where('isRead', isEqualTo: false)
        .orderBy('createdAt', descending: true)
        .limit(10)
        .snapshots()
        .listen((snapshot) {
          for (final change in snapshot.docChanges) {
            if (change.type == DocumentChangeType.added) {
              final data = change.doc.data();
              if (data == null) continue;
              final type = data['type'] as String? ?? '';
              final message = data['message'] as String? ?? '';
              final userName =
                  data['userName'] as String? ??
                  ''; // ignore: unused_local_variable
              final chatId =
                  data['chatId'] as int? ?? 0; // ignore: unused_local_variable

              // Show in-app notification
              if (mounted) {
                final isEscalation = type == 'escalation';
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    backgroundColor: AppColors.primary,
                    content: Row(
                      children: [
                        Icon(
                          isEscalation
                              ? Icons.warning_rounded
                              : Icons.chat_bubble_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                isEscalation
                                    ? '⚠️ Chat Escalado'
                                    : '💬 Nuevo Mensaje',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14,
                                ),
                              ),
                              Text(
                                message,
                                style: const TextStyle(fontSize: 13),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    duration: const Duration(seconds: 5),
                    action: SnackBarAction(
                      label: 'Ver Chat',
                      textColor: Colors.white,
                      onPressed: () => _onTabChanged(6), // Go to Chat tab
                    ),
                  ),
                );
              }

              // Mark as read
              change.doc.reference.update({'isRead': true});
            }
          }
        });
  }

  void _startProfileChangeListener() {
    // Listen for client profile changes (photo, phone, password updates)
    FirebaseFirestore.instance
        .collection('clients')
        .where('lastUpdated', isGreaterThan: Timestamp.fromDate(
          DateTime.now().subtract(const Duration(minutes: 1))
        ))
        .snapshots()
        .listen((snapshot) {
          for (final change in snapshot.docChanges) {
            if (change.type == DocumentChangeType.modified) {
              final data = change.doc.data();
              if (data == null) continue;
              final name = data['firstName'] ?? data['first_name'] ?? 'Usuario';
              final changes = <String>[];
              
              if (data['photoUrl'] != null) changes.add('foto de perfil');
              if (data['phone'] != null) changes.add('teléfono');
              if (data['passwordUpdated'] == true) changes.add('contraseña');
              
              if (changes.isNotEmpty && mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    backgroundColor: AppColors.warning,
                    content: Row(
                      children: [
                        const Icon(Icons.person_outline, color: Colors.white, size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            '📋 $name actualizó: ${changes.join(', ')}',
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    duration: const Duration(seconds: 6),
                    action: SnackBarAction(
                      label: 'Ver DB',
                      textColor: Colors.white,
                      onPressed: () => _onTabChanged(2), // Database tab
                    ),
                  ),
                );
              }
            }
          }
        });
    
    // Listen for driver profile changes
    FirebaseFirestore.instance
        .collection('drivers')
        .where('lastUpdated', isGreaterThan: Timestamp.fromDate(
          DateTime.now().subtract(const Duration(minutes: 1))
        ))
        .snapshots()
        .listen((snapshot) {
          for (final change in snapshot.docChanges) {
            if (change.type == DocumentChangeType.modified) {
              final data = change.doc.data();
              if (data == null) continue;
              final name = data['firstName'] ?? data['first_name'] ?? 'Conductor';
              final changes = <String>[];
              
              if (data['photoUrl'] != null) changes.add('foto de perfil');
              if (data['phone'] != null) changes.add('teléfono');
              if (data['passwordUpdated'] == true) changes.add('contraseña');
              if (data['vehicle'] != null) changes.add('vehículo');
              
              if (changes.isNotEmpty && mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    backgroundColor: const Color(0xFF1565C0),
                    content: Row(
                      children: [
                        const Icon(Icons.local_taxi_outlined, color: Colors.white, size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            '🚕 $name actualizó: ${changes.join(', ')}',
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    duration: const Duration(seconds: 6),
                    action: SnackBarAction(
                      label: 'Ver DB',
                      textColor: Colors.white,
                      onPressed: () => _onTabChanged(2),
                    ),
                  ),
                );
              }
            }
          }
        });
  }

  void _startNotificationService() {
    // Start the notification service to listen for profile changes
    NotificationService().startListening(context);
    
    // Listen to the notification stream for showing in-app notifications
    _notificationStreamSub = notificationStream.stream.listen((event) {
      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: event.color,
          content: Row(
            children: [
              Icon(event.icon, color: Colors.white, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      event.title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                    Text(
                      event.message,
                      style: const TextStyle(fontSize: 13),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          duration: event.duration,
          action: SnackBarAction(
            label: event.actionLabel,
            textColor: Colors.white,
            onPressed: () {
              if (event.onAction != null) {
                event.onAction!();
              }
              // Navigate based on notification type
              if (event.title.contains('verificación')) {
                _onTabChanged(3); // Verify tab
              } else {
                _onTabChanged(2); // Database tab
              }
            },
          ),
        ),
      );
    });
  }

  @override
  void dispose() {
    _notifSub?.cancel();
    _notificationStreamSub?.cancel();
    NotificationService().stop();
    _fadeCtrl.dispose();
    _fabCtrl.dispose();
    super.dispose();
  }

  void _onTabChanged(int i) {
    if (i == _currentIndex) return;
    _previousIndex = _currentIndex;
    setState(() {
      _visitedPages.add(i);
      _currentIndex = i;
    });
    _fadeCtrl.value = 0;
    _fadeCtrl.forward();
    if (i == 0) {
      _fabCtrl.forward();
    } else {
      _fabCtrl.reverse();
    }
  }

  String get _currentTitle => _navItems[_currentIndex].label;

  @override
  Widget build(BuildContext context) {
    final verif = context.watch<VerificationProvider>();
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: _currentIndex == 0 
          ? null  // No back button on home
          : IconButton(
              icon: const Icon(Icons.arrow_back_rounded, color: AppColors.primary),
              onPressed: () => _onTabChanged(0),  // Back to home
            ),
        title: Text(
          _currentTitle,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 17,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          if (_currentIndex == 0)
            IconButton(
              icon: const Icon(Icons.add_rounded, color: AppColors.primary),
              tooltip: 'Nuevo Viaje',
              onPressed: () => Navigator.push(
                context,
                scaleExpandRoute(const CreateTripScreen()),
              ),
            ),
          if (_currentIndex == 3 && verif.pendingCount > 0)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.error,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${verif.pendingCount} pending',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
      body: AnimatedBuilder(
        animation: _fadeAnim,
        builder: (context, child) => IndexedStack(
          index: _currentIndex,
          children: List.generate(_pages.length, (i) {
            if (!_visitedPages.contains(i)) return const SizedBox.shrink();
            final isActive = i == _currentIndex;
            final opacity = isActive
                ? _fadeAnim.value
                : (i == _previousIndex ? 1.0 - _fadeAnim.value : 0.0);
            return Visibility(
              visible: i == _currentIndex || i == _previousIndex,
              maintainState: true,
              child: IgnorePointer(
                ignoring: !isActive,
                child: Opacity(
                  opacity: opacity.clamp(0.0, 1.0),
                  child: _pages[i],
                ),
              ),
            );
          }),
        ),
      ),
      floatingActionButton: _currentIndex == 0
          ? ScaleTransition(
              scale: _fabScale,
              child: FloatingActionButton.extended(
                onPressed: () => Navigator.push(
                  context,
                  scaleExpandRoute(const CreateTripScreen()),
                ),
                icon: const Icon(Icons.add_rounded),
                label: const Text(
                  'New Trip',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            )
          : null,
    );
  }
}

// ─── Nav Item model ──────────────────────────────────────────────────────────

class _NavItem {
  final IconData icon;
  final IconData selectedIcon;
  final String label;
  const _NavItem(this.icon, this.selectedIcon, this.label);
}

// ─── Drawer ──────────────────────────────────────────────────────────────────

class _AppDrawer extends StatelessWidget {
  final int currentIndex;
  final int pendingVerifications;
  final ValueChanged<int> onSelect;

  const _AppDrawer({
    required this.currentIndex,
    required this.pendingVerifications,
    required this.onSelect,
  });

  static const _items = [
    _NavItem(Icons.directions_car_outlined, Icons.directions_car, 'Trips'),
    _NavItem(Icons.map_outlined, Icons.map, 'Fleet Map'),
    _NavItem(Icons.group_outlined, Icons.group_rounded, 'Database'),
    _NavItem(Icons.verified_user_outlined, Icons.verified_user, 'Verify'),
    _NavItem(Icons.bar_chart_outlined, Icons.bar_chart, 'Stats'),
    _NavItem(Icons.receipt_long_outlined, Icons.receipt_long, 'Reports'),
    _NavItem(Icons.chat_outlined, Icons.chat_rounded, 'Chat'),
    _NavItem(Icons.settings_outlined, Icons.settings_rounded, 'Config'),
    _NavItem(Icons.event_note_outlined, Icons.event_note_rounded, 'Scheduled'),
    _NavItem(Icons.security_outlined, Icons.security_rounded, 'Audit Logs'),
    _NavItem(Icons.local_offer_outlined, Icons.local_offer_rounded, 'Pricing'),
  ];

  @override
  Widget build(BuildContext context) {
    final auth = context.read<AuthProvider>();
    return Drawer(
      backgroundColor: const Color(0xFF0A0B0D),
      width: 260,
      child: SafeArea(
        child: Column(
          children: [
            // ── Logo header ───────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
              child: Row(
                children: [
                  // Cruise logo tile
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFE8C547), Color(0xFFF5D158)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(13),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(
                            0xFFE8C547,
                          ).withValues(alpha: 0.35),
                          blurRadius: 18,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: const Center(
                      child: Text(
                        'C',
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF08090C),
                          height: 1,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Cruise',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                          letterSpacing: -0.3,
                        ),
                      ),
                      Text(
                        'Dispatch',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w400,
                          color: AppColors.textSecondary,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Divider
            Container(
              height: 0.5,
              margin: const EdgeInsets.symmetric(horizontal: 20),
              color: AppColors.cardBorder,
            ),
            const SizedBox(height: 10),

            // ── Menu items ────────────────────────────────────────────────
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                itemCount: _items.length,
                itemBuilder: (context, i) {
                  final item = _items[i];
                  final isSelected = i == currentIndex;
                  final showBadge = i == 3 && pendingVerifications > 0;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 2),
                    child: Material(
                      color: Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () => onSelect(i),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? AppColors.primary.withValues(alpha: 0.12)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                isSelected ? item.selectedIcon : item.icon,
                                size: 20,
                                color: isSelected
                                    ? AppColors.primary
                                    : AppColors.textSecondary,
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Text(
                                  item.label,
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: isSelected
                                        ? FontWeight.w700
                                        : FontWeight.w400,
                                    color: isSelected
                                        ? AppColors.primary
                                        : AppColors.textPrimary,
                                  ),
                                ),
                              ),
                              if (showBadge)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 7,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.error,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    pendingVerifications > 9
                                        ? '9+'
                                        : '$pendingVerifications',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),

            // ── Sign out ──────────────────────────────────────────────────
            Container(
              height: 0.5,
              margin: const EdgeInsets.symmetric(horizontal: 20),
              color: AppColors.cardBorder,
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              child: Material(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(12),
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => auth.signOut(),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.logout_rounded,
                          size: 20,
                          color: AppColors.error,
                        ),
                        const SizedBox(width: 14),
                        Text(
                          'Sign Out',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: AppColors.error.withValues(alpha: 0.9),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
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
          IconButton(
            icon: const Icon(
              Icons.event_note_rounded,
              color: AppColors.primary,
            ),
            tooltip: 'Scheduled Rides',
            onPressed: () => Navigator.push(
              context,
              slideFromRightRoute(const ScheduledRidesScreen()),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: dash.refresh,
          ),
          PopupMenuButton<String>(
            onSelected: (v) {
              if (v == 'logout') auth.signOut();
            },
            icon: const Icon(Icons.more_vert_rounded),
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
      ),
      body: dash.isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            )
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
    return Row(
      children: [
        Container(
          width: 3,
          height: 18,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [AppColors.primary, AppColors.primaryLight],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          text,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }

  Widget _buildStatsGrid(
    BuildContext context,
    DashboardProvider dash,
    TripProvider trips,
  ) {
    final fmt = NumberFormat.currency(symbol: '\$', decimalDigits: 0);
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 1.1,
      children: [
        StatCard(
          title: "Today's Trips",
          value: dash.todayTrips.toString(),
          icon: Icons.today_rounded,
          color: AppColors.primary,
          subtitle: '${dash.todayCompleted} completed',
        ),
        StatCard(
          title: 'Active Rides',
          value: trips.activeCount.toString(),
          icon: Icons.directions_car_rounded,
          color: AppColors.inProgress,
          subtitle: '${trips.requestedCount} pending',
        ),
        StatCard(
          title: "Today's Revenue",
          value: fmt.format(dash.todayRevenue),
          icon: Icons.attach_money_rounded,
          color: AppColors.success,
        ),
        StatCard(
          title: 'Completion Rate',
          value: '${dash.todayCompletionRate.toStringAsFixed(0)}%',
          icon: Icons.check_circle_outline_rounded,
          color: dash.todayCompletionRate >= 80
              ? AppColors.success
              : AppColors.warning,
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
                return BarTooltipItem(
                  '${d['total']} trips\n${d['completed']} done',
                  const TextStyle(color: Colors.white, fontSize: 12),
                );
              },
            ),
          ),
          titlesData: FlTitlesData(
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (v, m) {
                  final i = v.toInt();
                  if (i >= 0 && i < dash.weeklyData.length) {
                    return Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        DateFormat(
                          'EEE',
                        ).format(dash.weeklyData[i]['date'] as DateTime),
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.textHint,
                        ),
                      ),
                    );
                  }
                  return const SizedBox.shrink();
                },
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 28,
                getTitlesWidget: (v, m) => Text(
                  v.toInt().toString(),
                  style: const TextStyle(
                    fontSize: 10,
                    color: AppColors.textHint,
                  ),
                ),
              ),
            ),
            topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
          ),
          borderData: FlBorderData(show: false),
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            getDrawingHorizontalLine: (_) =>
                const FlLine(color: AppColors.cardBorder, strokeWidth: 1),
          ),
          barGroups: dash.weeklyData
              .asMap()
              .entries
              .map(
                (e) => BarChartGroupData(
                  x: e.key,
                  barRods: [
                    BarChartRodData(
                      toY: (e.value['completed'] as int).toDouble(),
                      color: AppColors.success,
                      width: 11,
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(4),
                      ),
                    ),
                    BarChartRodData(
                      toY: (e.value['cancelled'] as int).toDouble(),
                      color: AppColors.cancelled,
                      width: 11,
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(4),
                      ),
                    ),
                  ],
                ),
              )
              .toList(),
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
      child: LineChart(
        LineChartData(
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            getDrawingHorizontalLine: (_) =>
                const FlLine(color: AppColors.cardBorder, strokeWidth: 1),
          ),
          titlesData: FlTitlesData(
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (v, m) {
                  final i = v.toInt();
                  if (i >= 0 && i < dash.weeklyData.length) {
                    return Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        DateFormat(
                          'EEE',
                        ).format(dash.weeklyData[i]['date'] as DateTime),
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.textHint,
                        ),
                      ),
                    );
                  }
                  return const SizedBox.shrink();
                },
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 42,
                getTitlesWidget: (v, m) => Text(
                  '\$${v.toInt()}',
                  style: const TextStyle(
                    fontSize: 10,
                    color: AppColors.textHint,
                  ),
                ),
              ),
            ),
            topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
          ),
          borderData: FlBorderData(show: false),
          lineBarsData: [
            LineChartBarData(
              spots: dash.weeklyData
                  .asMap()
                  .entries
                  .map(
                    (e) =>
                        FlSpot(e.key.toDouble(), e.value['revenue'] as double),
                  )
                  .toList(),
              isCurved: true,
              color: AppColors.primary,
              barWidth: 3,
              isStrokeCapRound: true,
              dotData: FlDotData(
                show: true,
                getDotPainter: (s, p, b, i) => FlDotCirclePainter(
                  radius: 4,
                  color: AppColors.primary,
                  strokeWidth: 2,
                  strokeColor: AppColors.surface,
                ),
              ),
              belowBarData: BarAreaData(
                show: true,
                color: AppColors.primary.withValues(alpha: 0.08),
              ),
            ),
          ],
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              getTooltipItems: (spots) => spots
                  .map(
                    (s) => LineTooltipItem(
                      '\$${s.y.toStringAsFixed(0)}',
                      const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryCard(BuildContext context, DashboardProvider dash) {
    final fmt = NumberFormat.currency(symbol: '\$', decimalDigits: 0);
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: LinearGradient(
          colors: [
            AppColors.primary.withValues(alpha: 0.25),
            AppColors.cardBorder.withValues(alpha: 0.6),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Container(
        margin: const EdgeInsets.all(1.2),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(17),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: const Icon(
                    Icons.analytics_rounded,
                    size: 16,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(width: 10),
                const Text(
                  'Summary',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Container(
              height: 1,
              color: AppColors.cardBorder.withValues(alpha: 0.6),
              margin: const EdgeInsets.only(bottom: 14),
            ),
            _statRow(
              'Trips this week',
              dash.weekTrips.toString(),
              Icons.date_range_rounded,
            ),
            const SizedBox(height: 10),
            _statRow(
              'Trips this month',
              dash.monthTrips.toString(),
              Icons.calendar_month_rounded,
            ),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 10),
              child: Divider(color: AppColors.divider, height: 1),
            ),
            _statRow(
              'Week revenue',
              fmt.format(dash.weekRevenue),
              Icons.trending_up_rounded,
              color: AppColors.success,
            ),
            const SizedBox(height: 10),
            _statRow(
              'Month revenue',
              fmt.format(dash.monthRevenue),
              Icons.account_balance_wallet_rounded,
              color: AppColors.success,
            ),
          ],
        ),
      ),
    );
  }

  Widget _statRow(String label, String value, IconData icon, {Color? color}) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppColors.textSecondary),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              color: AppColors.textSecondary,
            ),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: color ?? AppColors.textPrimary,
          ),
        ),
      ],
    );
  }

  Widget _emptyChart(String msg) {
    return Container(
      height: 160,
      decoration: _chartDecoration(),
      child: Center(
        child: Text(msg, style: const TextStyle(color: AppColors.textHint)),
      ),
    );
  }

  BoxDecoration _chartDecoration() {
    return BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: AppColors.cardBorder),
      boxShadow: [
        BoxShadow(
          color: AppColors.primary.withValues(alpha: 0.05),
          blurRadius: 12,
          offset: const Offset(0, 4),
        ),
      ],
    );
  }

  double _maxY(List<Map<String, dynamic>> data) {
    if (data.isEmpty) return 10;
    double max = 0;
    for (final d in data) {
      final t = (d['total'] as int).toDouble();
      if (t > max) max = t;
    }
    return max < 5 ? 5 : max + 2;
  }
}
