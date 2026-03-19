import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/app_theme.dart';
import '../providers/client_provider.dart';
import '../providers/dashboard_provider.dart';
import '../providers/driver_provider.dart';
import '../providers/trip_provider.dart';
import '../providers/verification_provider.dart';
import '../config/page_transitions.dart';
import 'create_trip_screen.dart';
import 'fleet_map_screen.dart';
import 'riders_screen.dart';
import 'drivers_screen.dart';
import 'verification_review_screen.dart';
import 'blocked_users_screen.dart';
import 'deactivated_users_screen.dart';
import 'account_appeals_screen.dart';
import 'support_chats_screen.dart';
import 'scheduled_rides_screen.dart';
import 'trip_list_screen.dart';
import 'admin_config_screen.dart';
import 'reports_screen.dart';
import 'audit_logs_screen.dart';
import 'pricing_config_screen.dart';
import 'database_screen.dart';
import 'driver_reports_screen.dart';

class HomeMenuScreen extends StatefulWidget {
  final Function(int) onNavigate;
  const HomeMenuScreen({super.key, required this.onNavigate});

  @override
  State<HomeMenuScreen> createState() => _HomeMenuScreenState();
}

class _HomeMenuScreenState extends State<HomeMenuScreen>
    with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;
  late TabController _tabController;
  int _currentTab = 0; // 0 = Dispatch, 1 = Admin
  
  // Real-time counters
  int _riderCount = 0;
  int _driverCount = 0;
  int _pendingVerifications = 0;
  int _activeTrips = 0;
  int _scheduledTrips = 0;
  int _driverReports = 0;
  int _supportChats = 0;
  int _blockedUsers = 0;
  int _onlineDrivers = 0;
  
  StreamSubscription? _ridersSub;
  StreamSubscription? _driversSub;
  StreamSubscription? _verifSub;
  StreamSubscription? _tripsSub;
  StreamSubscription? _scheduledSub;
  StreamSubscription? _chatsSub;
  StreamSubscription? _driverReportsSub;
  StreamSubscription? _blockedSub;
  StreamSubscription? _onlineDriversSub;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOutCubic,
    );
    _fadeController.forward();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) return;
      setState(() => _currentTab = _tabController.index);
    });
    
    _startRealTimeListeners();
  }

  void _startRealTimeListeners() {
    // Riders count
    _ridersSub = FirebaseFirestore.instance
        .collection('clients')
        .snapshots()
        .listen((snap) => setState(() => _riderCount = snap.docs.length));
    
    // Drivers count
    _driversSub = FirebaseFirestore.instance
        .collection('drivers')
        .snapshots()
        .listen((snap) => setState(() => _driverCount = snap.docs.length));
    
    // Pending verifications
    _verifSub = FirebaseFirestore.instance
        .collection('verifications')
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .listen((snap) => setState(() => _pendingVerifications = snap.docs.length));
    
    // Active trips
    _tripsSub = FirebaseFirestore.instance
        .collection('trips')
        .where('status', whereIn: ['pending', 'accepted', 'in_progress'])
        .snapshots()
        .listen((snap) => setState(() => _activeTrips = snap.docs.length));
    
    // Scheduled trips (reservas) - trips with scheduledAt in the future
    final now = DateTime.now();
    _scheduledSub = FirebaseFirestore.instance
        .collection('trips')
        .where('scheduledAt', isGreaterThan: Timestamp.fromDate(now))
        .snapshots()
        .listen((snap) => setState(() => _scheduledTrips = snap.docs.length));
    
    // Support chats with unread messages
    _chatsSub = FirebaseFirestore.instance
        .collection('support_chats')
        .where('hasUnread', isEqualTo: true)
        .snapshots()
        .listen((snap) => setState(() => _supportChats = snap.docs.length));
    
    // Driver reports (crashes, bugs, etc.)
    _driverReportsSub = FirebaseFirestore.instance
        .collection('driver_reports')
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .listen((snap) => setState(() => _driverReports = snap.docs.length));

    // Blocked users count
    _blockedSub = FirebaseFirestore.instance
        .collection('clients')
        .where('status', isEqualTo: 'blocked')
        .snapshots()
        .listen((snap) {
          final blockedClients = snap.docs.length;
          FirebaseFirestore.instance
              .collection('drivers')
              .where('status', isEqualTo: 'blocked')
              .snapshots()
              .listen((driverSnap) {
                setState(() => _blockedUsers = blockedClients + driverSnap.docs.length);
              });
        });

    // Online drivers count
    _onlineDriversSub = FirebaseFirestore.instance
        .collection('drivers')
        .where('isOnline', isEqualTo: true)
        .snapshots()
        .listen((snap) => setState(() => _onlineDrivers = snap.docs.length));
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _tabController.dispose();
    _ridersSub?.cancel();
    _driversSub?.cancel();
    _verifSub?.cancel();
    _tripsSub?.cancel();
    _scheduledSub?.cancel();
    _chatsSub?.cancel();
    _driverReportsSub?.cancel();
    _blockedSub?.cancel();
    _onlineDriversSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          child: Column(
            children: [
              // Header with dynamic title
              _buildHeader(),
              // Tab bar: Dispatch | Admin
              _buildTabBar(),
              // Tab content
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildDispatchTab(),
                    _buildAdminTab(),
                  ],
                ),
              ),
            ],
          ),
        ),
        floatingActionButton: _currentTab == 0
            ? FloatingActionButton.extended(
                onPressed: () => Navigator.push(
                  context,
                  scaleExpandRoute(const CreateTripScreen()),
                ),
                backgroundColor: AppColors.primary,
                icon: const Icon(Icons.add),
                label: const Text(
                  'Nuevo Viaje',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              )
            : null,
      ),
    );
  }

  void _navigate(int index) {
    widget.onNavigate(index);
  }

  // ─── DISPATCH TAB ─────────────────────────────────────────────────────
  Widget _buildDispatchTab() {
    return CustomScrollView(
      slivers: [
        // Quick Stats - Dispatch
        SliverToBoxAdapter(child: _buildDispatchQuickStats()),
        // Dispatch Menu Grid
        SliverPadding(
          padding: const EdgeInsets.all(16),
          sliver: SliverGrid(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.3,
            ),
            delegate: SliverChildListDelegate([
              _ContextMenuCard(
                icon: Icons.directions_car,
                label: 'Viajes',
                sublabel: '$_activeTrips activos',
                color: AppColors.primary,
                badge: _activeTrips > 0 ? '$_activeTrips' : null,
                onTap: () => _showTripsMenu(context),
              ),
              _ContextMenuCard(
                icon: Icons.map,
                label: 'Mapa Fleet',
                sublabel: '$_onlineDrivers en línea',
                color: AppColors.primary,
                badge: _onlineDrivers > 0 ? '$_onlineDrivers' : null,
                onTap: () => _showFleetMenu(context),
              ),
              _ContextMenuCard(
                icon: Icons.chat_bubble,
                label: 'Soporte',
                sublabel: _supportChats > 0
                    ? '$_supportChats mensajes nuevos'
                    : 'Chat con usuarios',
                color: AppColors.primary,
                badge: _supportChats > 0 ? '$_supportChats' : null,
                onTap: () => Navigator.push(
                  context,
                  slideFromRightRoute(const SupportChatsScreen()),
                ),
              ),
              _ContextMenuCard(
                icon: Icons.calendar_today,
                label: 'Reservas',
                sublabel: '$_scheduledTrips programados',
                color: AppColors.primary,
                badge: _scheduledTrips > 0 ? '$_scheduledTrips' : null,
                onTap: () => Navigator.push(
                  context,
                  slideFromRightRoute(const ScheduledRidesScreen()),
                ),
              ),
            ]),
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 80)),
      ],
    );
  }

  // ─── ADMIN TAB ────────────────────────────────────────────────────────
  Widget _buildAdminTab() {
    return CustomScrollView(
      slivers: [
        // Quick Stats - Admin
        SliverToBoxAdapter(child: _buildAdminQuickStats()),
        // Admin Menu Grid
        SliverPadding(
          padding: const EdgeInsets.all(16),
          sliver: SliverGrid(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.3,
            ),
            delegate: SliverChildListDelegate([
              _ContextMenuCard(
                icon: Icons.person,
                label: 'Riders',
                sublabel: '$_riderCount usuarios',
                color: AppColors.primary,
                badge: _pendingVerifications > 0 ? '$_pendingVerifications' : null,
                onTap: () => _showRidersMenu(context),
              ),
              _ContextMenuCard(
                icon: Icons.local_taxi,
                label: 'Drivers',
                sublabel: '$_driverCount conductores',
                color: AppColors.primary,
                onTap: () => _showDriversMenu(context),
              ),
              _ContextMenuCard(
                icon: Icons.settings,
                label: 'Configuración',
                sublabel: 'Ajustes del sistema',
                color: AppColors.primary,
                onTap: () => Navigator.push(
                  context,
                  slideFromRightRoute(const AdminConfigScreen()),
                ),
              ),
              _ContextMenuCard(
                icon: Icons.attach_money,
                label: 'Precios',
                sublabel: 'Tarifas y pricing',
                color: AppColors.primary,
                onTap: () => Navigator.push(
                  context,
                  slideFromRightRoute(const PricingConfigScreen()),
                ),
              ),
              _ContextMenuCard(
                icon: Icons.analytics,
                label: 'Reportes',
                sublabel: 'Reportes financieros',
                color: AppColors.primary,
                onTap: () => Navigator.push(
                  context,
                  slideFromRightRoute(const ReportsScreen()),
                ),
              ),
              _ContextMenuCard(
                icon: Icons.security,
                label: 'Audit Logs',
                sublabel: 'Registro de actividad',
                color: AppColors.primary,
                onTap: () => Navigator.push(
                  context,
                  slideFromRightRoute(const AuditLogsScreen()),
                ),
              ),
              _ContextMenuCard(
                icon: Icons.storage,
                label: 'Base de Datos',
                sublabel: 'Gestión de datos',
                color: AppColors.primary,
                onTap: () => Navigator.push(
                  context,
                  slideFromRightRoute(const DatabaseScreen()),
                ),
              ),
              _ContextMenuCard(
                icon: Icons.report_problem,
                label: 'Rep. Drivers',
                sublabel: _driverReports > 0
                    ? '$_driverReports pendientes'
                    : 'Sin reportes',
                color: AppColors.primary,
                badge: _driverReports > 0 ? '$_driverReports' : null,
                onTap: () => Navigator.push(
                  context,
                  slideFromRightRoute(const DriverReportsScreen()),
                ),
              ),
            ]),
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 20)),
      ],
    );
  }

  // ─── CONTEXT MENUS ────────────────────────────────────────────────────
  void _showRidersMenu(BuildContext context) {
    _showContextMenu(
      context: context,
      title: 'Riders',
      icon: Icons.person,
      color: AppColors.primary,
      items: [
        _MenuAction(
          icon: Icons.verified_user,
          label: 'Verificación',
          badge: _pendingVerifications > 0 ? '$_pendingVerifications' : null,
          onTap: () => Navigator.push(
            context,
            slideFromRightRoute(const VerificationReviewScreen()),
          ),
        ),
        _MenuAction(
          icon: Icons.block,
          label: 'Bloqueados',
          badge: _blockedUsers > 0 ? '$_blockedUsers' : null,
          onTap: () => Navigator.push(
            context,
            slideFromRightRoute(const BlockedUsersScreen()),
          ),
        ),
        _MenuAction(
          icon: Icons.pause_circle_filled,
          label: 'Desactivados',
          onTap: () => Navigator.push(
            context,
            slideFromRightRoute(const DeactivatedUsersScreen()),
          ),
        ),
        _MenuAction(
          icon: Icons.delete_forever,
          label: 'Eliminados',
          onTap: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Página de eliminados - Próximamente')),
            );
          },
        ),
        _MenuAction(
          icon: Icons.gavel,
          label: 'Apelaciones',
          onTap: () => Navigator.push(
            context,
            slideFromRightRoute(const AccountAppealsScreen()),
          ),
        ),
      ],
    );
  }

  void _showDriversMenu(BuildContext context) {
    _showContextMenu(
      context: context,
      title: 'Drivers',
      icon: Icons.local_taxi,
      color: AppColors.primary,
      items: [
        _MenuAction(
          icon: Icons.verified_user,
          label: 'Verificación',
          onTap: () => Navigator.push(
            context,
            slideFromRightRoute(const VerificationReviewScreen()),
          ),
        ),
        _MenuAction(
          icon: Icons.block,
          label: 'Bloqueados',
          onTap: () => Navigator.push(
            context,
            slideFromRightRoute(const BlockedUsersScreen()),
          ),
        ),
        _MenuAction(
          icon: Icons.pause_circle_filled,
          label: 'Desactivados',
          onTap: () => Navigator.push(
            context,
            slideFromRightRoute(const DeactivatedUsersScreen()),
          ),
        ),
        _MenuAction(
          icon: Icons.delete_forever,
          label: 'Eliminados',
          onTap: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Página de eliminados - Próximamente')),
            );
          },
        ),
        _MenuAction(
          icon: Icons.gavel,
          label: 'Apelaciones',
          onTap: () => Navigator.push(
            context,
            slideFromRightRoute(const AccountAppealsScreen()),
          ),
        ),
      ],
    );
  }

  void _showTripsMenu(BuildContext context) {
    _showContextMenu(
      context: context,
      title: 'Viajes',
      icon: Icons.directions_car,
      color: AppColors.primary,
      items: [
        _MenuAction(
          icon: Icons.local_taxi,
          label: 'Viajes Activos',
          badge: _activeTrips > 0 ? '$_activeTrips' : null,
          onTap: () => Navigator.push(
            context,
            slideFromRightRoute(const TripListScreen()),
          ),
        ),
        _MenuAction(
          icon: Icons.pending_actions,
          label: 'Viajes Pendientes',
          onTap: () => Navigator.push(
            context,
            slideFromRightRoute(const TripListScreen()),
          ),
        ),
        _MenuAction(
          icon: Icons.calendar_today,
          label: 'Viajes Reservados',
          badge: _scheduledTrips > 0 ? '$_scheduledTrips' : null,
          onTap: () => Navigator.push(
            context,
            slideFromRightRoute(const ScheduledRidesScreen()),
          ),
        ),
        _MenuAction(
          icon: Icons.cancel,
          label: 'Viajes Cancelados',
          onTap: () => Navigator.push(
            context,
            slideFromRightRoute(const TripListScreen()),
          ),
        ),
        _MenuAction(
          icon: Icons.flight_takeoff,
          label: 'Reserva Aeropuertos',
          onTap: () => Navigator.push(
            context,
            slideFromRightRoute(const ScheduledRidesScreen()),
          ),
        ),
      ],
    );
  }

  void _showFleetMenu(BuildContext context) {
    _showContextMenu(
      context: context,
      title: 'Mapa Fleet',
      icon: Icons.map,
      color: AppColors.primary,
      items: [
        _MenuAction(
          icon: Icons.local_taxi,
          label: 'Drivers Activos',
          badge: _onlineDrivers > 0 ? '$_onlineDrivers' : null,
          onTap: () => Navigator.push(
            context,
            slideFromRightRoute(const FleetMapScreen()),
          ),
        ),
        _MenuAction(
          icon: Icons.location_on,
          label: 'Ver Mapa Completo',
          onTap: () => Navigator.push(
            context,
            slideFromRightRoute(const FleetMapScreen()),
          ),
        ),
      ],
    );
  }

  void _showContextMenu({
    required BuildContext context,
    required String title,
    required IconData icon,
    required Color color,
    required List<_MenuAction> items,
  }) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Dismiss',
      barrierColor: Colors.black.withOpacity(0.5),
      transitionDuration: const Duration(milliseconds: 200),
      pageBuilder: (context, anim1, anim2) {
        return ScaleTransition(
          scale: Tween<double>(begin: 0.8, end: 1.0).animate(CurvedAnimation(
            parent: anim1,
            curve: Curves.easeOutBack,
          )),
          child: FadeTransition(
            opacity: anim1,
            child: AlertDialog(
              backgroundColor: Colors.transparent,
              contentPadding: EdgeInsets.zero,
              content: Container(
                width: 280,
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.3),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.1),
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(16),
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: color.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(icon, color: color, size: 24),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            title,
                            style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1, color: AppColors.cardBorder),
                    ...items.map((item) => _buildMenuItem(item)),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildMenuItem(_MenuAction item) {
    return InkWell(
      onTap: () {
        Navigator.pop(context);
        item.onTap();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: AppColors.cardBorder,
              width: 0.5,
            ),
          ),
        ),
        child: Row(
          children: [
            Icon(item.icon, color: AppColors.primary, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                item.label,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 15,
                ),
              ),
            ),
            if (item.badge != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.error,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  item.badge!,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            const SizedBox(width: 8),
            const Icon(
              Icons.arrow_forward_ios,
              color: AppColors.textHint,
              size: 14,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final isDispatch = _currentTab == 0;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  child: Text(
                    isDispatch ? 'Dashboard Dispatch' : 'Dashboard Admin',
                    key: ValueKey(isDispatch),
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                Text(
                  isDispatch
                      ? 'Gestión operativa de viajes'
                      : 'Administración del sistema',
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined, color: AppColors.primary),
            onPressed: () => Navigator.push(
              context,
              slideFromRightRoute(const AdminConfigScreen()),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surfaceHigh,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: TabBar(
        controller: _tabController,
        indicator: BoxDecoration(
          color: AppColors.primary,
          borderRadius: BorderRadius.circular(12),
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        labelColor: const Color(0xFF08090C),
        unselectedLabelColor: AppColors.textSecondary,
        labelStyle: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w700,
        ),
        unselectedLabelStyle: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
        dividerColor: Colors.transparent,
        padding: const EdgeInsets.all(4),
        tabs: const [
          Tab(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.headset_mic, size: 18),
                SizedBox(width: 8),
                Text('Dispatch'),
              ],
            ),
          ),
          Tab(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.admin_panel_settings, size: 18),
                SizedBox(width: 8),
                Text('Admin'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDispatchQuickStats() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primary.withOpacity(0.15),
            AppColors.primary.withOpacity(0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary.withOpacity(0.2)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _StatItem(
            icon: Icons.directions_car,
            value: '$_activeTrips',
            label: 'Viajes Activos',
            color: AppColors.primary,
            onTap: () => _showTripsMenu(context),
          ),
          _StatItem(
            icon: Icons.calendar_today,
            value: '$_scheduledTrips',
            label: 'Reservas',
            color: AppColors.primary,
            onTap: () => Navigator.push(
              context,
              slideFromRightRoute(const ScheduledRidesScreen()),
            ),
          ),
          _StatItem(
            icon: Icons.chat,
            value: '$_supportChats',
            label: 'Chats Nuevos',
            color: AppColors.primary,
            onTap: () => Navigator.push(
              context,
              slideFromRightRoute(const SupportChatsScreen()),
            ),
          ),
          _StatItem(
            icon: Icons.local_taxi,
            value: '$_onlineDrivers',
            label: 'Drivers Activos',
            color: AppColors.success,
            onTap: () => Navigator.push(
              context,
              slideFromRightRoute(const FleetMapScreen()),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAdminQuickStats() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF1565C0).withOpacity(0.15),
            const Color(0xFF1565C0).withOpacity(0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF1565C0).withOpacity(0.2)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _StatItem(
            icon: Icons.person,
            value: '$_riderCount',
            label: 'Riders',
            color: const Color(0xFF1565C0),
            onTap: () => _showRidersMenu(context),
          ),
          _StatItem(
            icon: Icons.local_taxi,
            value: '$_driverCount',
            label: 'Drivers',
            color: const Color(0xFF1565C0),
            onTap: () => _showDriversMenu(context),
          ),
          _StatItem(
            icon: Icons.verified_user,
            value: '$_pendingVerifications',
            label: 'Verificaciones',
            color: AppColors.warning,
            onTap: () => Navigator.push(
              context,
              slideFromRightRoute(const VerificationReviewScreen()),
            ),
          ),
          _StatItem(
            icon: Icons.block,
            value: '$_blockedUsers',
            label: 'Bloqueados',
            color: AppColors.error,
            onTap: () => Navigator.push(
              context,
              slideFromRightRoute(const BlockedUsersScreen()),
            ),
          ),
        ],
      ),
    );
  }
}

class _MenuAction {
  final IconData icon;
  final String label;
  final String? badge;
  final VoidCallback onTap;

  _MenuAction({
    required this.icon,
    required this.label,
    this.badge,
    required this.onTap,
  });
}

class _ContextMenuCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String sublabel;
  final Color color;
  final String? badge;
  final VoidCallback? onTap;

  const _ContextMenuCard({
    required this.icon,
    required this.label,
    required this.sublabel,
    required this.color,
    this.badge,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppColors.surface,
              AppColors.surfaceHigh,
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: color.withOpacity(0.08),
            width: 1,
          ),
          boxShadow: [
            // Bottom shadow for 3D depth
            BoxShadow(
              color: Colors.black.withOpacity(0.5),
              blurRadius: 1,
              offset: const Offset(0, 4),
            ),
            // Soft ambient shadow
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 8,
              offset: const Offset(0, 6),
            ),
            // Top-left highlight for 3D raised effect
            BoxShadow(
              color: Colors.white.withOpacity(0.03),
              blurRadius: 1,
              offset: const Offset(-1, -1),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: color.withOpacity(0.1),
                        width: 1,
                      ),
                    ),
                    child: Icon(icon, color: color, size: 24),
                  ),
                  if (badge != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.error,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        badge!,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    sublabel,
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color color;
  final VoidCallback? onTap;

  const _StatItem({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(height: 8),
              Text(
                value,
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                label,
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
