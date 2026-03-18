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
import 'reports_screen.dart';
import 'support_chats_screen.dart';
import 'scheduled_rides_screen.dart';

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
  
  // Real-time counters
  int _riderCount = 0;
  int _driverCount = 0;
  int _pendingVerifications = 0;
  int _activeTrips = 0;
  int _driverReports = 0;
  int _supportChats = 0;
  
  StreamSubscription? _ridersSub;
  StreamSubscription? _driversSub;
  StreamSubscription? _verifSub;
  StreamSubscription? _tripsSub;
  StreamSubscription? _chatsSub;
  StreamSubscription? _driverReportsSub;

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
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _ridersSub?.cancel();
    _driversSub?.cancel();
    _verifSub?.cancel();
    _tripsSub?.cancel();
    _chatsSub?.cancel();
    _driverReportsSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          child: CustomScrollView(
            slivers: [
              // Header
              SliverToBoxAdapter(
                child: _buildHeader(),
              ),
              
              // Quick Stats
              SliverToBoxAdapter(
                child: _buildQuickStats(),
              ),
              
              // Menu Grid
              SliverPadding(
                padding: const EdgeInsets.all(16),
                sliver: SliverGrid(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 1.1,
                  ),
                  delegate: SliverChildListDelegate([
                    // FILA 1: Operaciones
                    _MenuCard(
                      icon: Icons.directions_car,
                      label: 'Viajes',
                      sublabel: '$_activeTrips viajes activos',
                      color: const Color(0xFF4CAF50),
                      onTap: () => _navigate(1),
                    ),
                    _MenuCard(
                      icon: Icons.map,
                      label: 'Mapa Fleet',
                      sublabel: 'Ubicaciones en tiempo real',
                      color: const Color(0xFF2196F3),
                      onTap: () => _navigate(2),
                    ),
                    
                    // FILA 2: Usuarios
                    _MenuCard(
                      icon: Icons.person,
                      label: 'Riders',
                      sublabel: '$_riderCount usuarios registrados',
                      color: const Color(0xFF9C27B0),
                      badge: _riderCount > 0 ? '$_riderCount' : null,
                      onTap: () => _navigate(3),
                    ),
                    _MenuCard(
                      icon: Icons.local_taxi,
                      label: 'Drivers',
                      sublabel: '$_driverCount conductores',
                      color: const Color(0xFFFF9800),
                      badge: _driverCount > 0 ? '$_driverCount' : null,
                      onTap: () => _navigate(4),
                    ),
                    
                    // FILA 3: Verificaciones
                    _MenuCard(
                      icon: Icons.verified_user,
                      label: 'Verificar Riders',
                      sublabel: _pendingVerifications > 0 
                        ? '$_pendingVerifications cuentas pendientes'
                        : 'Sin verificaciones pendientes',
                      color: const Color(0xFFE91E63),
                      badge: _pendingVerifications > 0 ? '$_pendingVerifications' : null,
                      onTap: () => _navigate(5),
                    ),
                    _MenuCard(
                      icon: Icons.local_taxi_rounded,
                      label: 'Verificar Drivers',
                      sublabel: 'Verificación de conductores',
                      color: const Color(0xFF00BCD4),
                      onTap: () => _navigate(6),
                    ),
                    
                    // FILA 4: Datos y Reportes
                    _MenuCard(
                      icon: Icons.analytics,
                      label: 'Analytics',
                      sublabel: 'Estadísticas y reportes',
                      color: const Color(0xFF3F51B5),
                      onTap: () => _navigate(7),
                    ),
                    _MenuCard(
                      icon: Icons.report_problem,
                      label: 'Reportes Drivers',
                      sublabel: _driverReports > 0
                        ? '$_driverReports problemas reportados'
                        : 'Sin reportes pendientes',
                      color: const Color(0xFFF44336),
                      badge: _driverReports > 0 ? '$_driverReports' : null,
                      onTap: () => _navigate(8),
                    ),
                    
                    // FILA 5: Comunicación y Agenda
                    _MenuCard(
                      icon: Icons.chat_bubble,
                      label: 'Soporte',
                      sublabel: _supportChats > 0
                        ? '$_supportChats chats nuevos'
                        : 'Soporte al cliente',
                      color: const Color(0xFF607D8B),
                      badge: _supportChats > 0 ? '$_supportChats' : null,
                      onTap: () => _navigate(9),
                    ),
                    _MenuCard(
                      icon: Icons.calendar_today,
                      label: 'Agendados',
                      sublabel: 'Viajes programados',
                      color: const Color(0xFF009688),
                      onTap: () => _navigate(10),
                    ),
                  ]),
                ),
              ),
              
              // Bottom spacing
              const SliverToBoxAdapter(
                child: SizedBox(height: 20),
              ),
            ],
          ),
        ),
        floatingActionButton: FloatingActionButton.extended(
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
        ),
      ),
    );
  }

  void _navigate(int index) {
    widget.onNavigate(index);
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppColors.primary, AppColors.primaryLight],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withOpacity(0.4),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: const Center(
              child: Text(
                'C',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF08090C),
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Cruise Dispatch',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  'Panel de Administración',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined, color: AppColors.primary),
            onPressed: () => _navigate(10),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickStats() {
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
            color: const Color(0xFF4CAF50),
          ),
          _StatItem(
            icon: Icons.verified_user,
            value: '$_pendingVerifications',
            label: 'Verif. Pendientes',
            color: const Color(0xFFE91E63),
          ),
          _StatItem(
            icon: Icons.chat,
            value: '$_supportChats',
            label: 'Chats Nuevos',
            color: const Color(0xFF2196F3),
          ),
        ],
      ),
    );
  }
}

class _MenuCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String sublabel;
  final Color color;
  final String? badge;
  final VoidCallback onTap;

  const _MenuCard({
    required this.icon,
    required this.label,
    required this.sublabel,
    required this.color,
    this.badge,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.cardBorder),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Stack(
              children: [
                // Background gradient
                Positioned(
                  right: -20,
                  bottom: -20,
                  child: Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
                // Content
                Padding(
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
                            ),
                            child: Icon(
                              icon,
                              color: color,
                              size: 24,
                            ),
                          ),
                          if (badge != null)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: color,
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
              ],
            ),
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

  const _StatItem({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
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
    );
  }
}
