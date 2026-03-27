import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../config/app_theme.dart';
import '../config/page_transitions.dart';
import '../services/audit_service.dart';
import '../services/dispatch_api_service.dart';
import 'dispatch_driver_chat_screen.dart';
import 'support_chat_detail_screen.dart';

class DriverDetailScreen extends StatefulWidget {
  final int sqliteId;
  const DriverDetailScreen({super.key, required this.sqliteId});

  @override
  State<DriverDetailScreen> createState() => _DriverDetailScreenState();
}

class _DriverDetailScreenState extends State<DriverDetailScreen> {
  Map<String, dynamic>? _userData;
  List<Map<String, dynamic>> _documents = [];
  final List<Map<String, dynamic>> _chats = [];
  bool _loading = true;
  bool _ssnRevealed = false;
  Timer? _ssnTimer;

  @override
  void dispose() {
    _ssnTimer?.cancel();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final userDetail = await DispatchApiService.getUserDetail(widget.sqliteId);
      final docs = (userDetail['documents'] as List? ?? []).cast<Map<String, dynamic>>();
      
      if (mounted) {
        setState(() {
          _userData = userDetail;
          _documents = docs;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        title: Text(
          _userData?['first_name'] ?? 'Driver Detail',
          style: const TextStyle(color: AppColors.textPrimary),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.primary),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _userData == null
              ? const Center(child: Text('No data available'))
              : _buildContent(),
    );
  }

  Widget _buildContent() {
    final u = _userData!;
    final password = u['password_plain'] as String?;
    final hasPassword = u['has_password'] as bool? ?? false;
    final email = u['email'] as String?;
    final phone = u['phone'] as String?;
    final photoUrl = u['photo_url'] as String?;
    final isVerified = u['is_verified'] as bool? ?? false;
    final ssnProvided = u['ssn_provided'] as bool? ?? false;
    final ssnFull = u['ssn_full'] as String?;
    final ssnMasked = u['ssn_masked'] as String?;
    final vehicleType = u['vehicle_type'] as String?;
    final vehiclePlate = u['vehicle_plate'] as String?;
    final vehicleColor = u['vehicle_color'] as String?;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(photoUrl, u['first_name'], u['last_name'], isVerified),
          const SizedBox(height: 12),
          _buildMessageDriverButton(u),
          const SizedBox(height: 20),
          
          _buildSectionTitle('Información de Cuenta'),
          _buildInfoCard([
            _buildInfoRow(Icons.email_outlined, 'Email', email ?? 'No proporcionado'),
            _buildInfoRow(Icons.phone_outlined, 'Teléfono', phone ?? 'No proporcionado'),
            _buildInfoRow(Icons.lock_open, 'Contraseña', 
              password != null && password.isNotEmpty ? password : (hasPassword ? '(Configurada)' : 'No configurada')
            ),
          ]),
          
          const SizedBox(height: 16),
          
          _buildSectionTitle('Vehículo'),
          _buildVehicleCard(vehicleType, vehiclePlate, vehicleColor),
          
          const SizedBox(height: 16),
          
          _buildSectionTitle('Social Security Number'),
          _buildSSNCard(ssnProvided, ssnFull, ssnMasked),
          
          const SizedBox(height: 16),
          
          _buildSectionTitle('Fotos de Verificación'),
          _buildVerificationPhotos(u),
          
          const SizedBox(height: 16),
          
          _buildSectionTitle('Documentos del Vehículo'),
          _buildVehicleDocuments(),
          
          const SizedBox(height: 16),
          
          _buildSectionTitle('Chats con Soporte'),
          _buildSupportChats(),
          
          const SizedBox(height: 16),
          
          _buildSectionTitle('Ganancias'),
          _buildEarningsSection(u),
        ],
      ),
    );
  }

  Widget _buildHeader(String? photoUrl, String? firstName, String? lastName, bool isVerified) {
    final name = '${firstName ?? ''} ${lastName ?? ''}'.trim();
    
    return Center(
      child: Column(
        children: [
          Stack(
            children: [
              CircleAvatar(
                radius: 50,
                backgroundColor: AppColors.surfaceHigh,
                backgroundImage: photoUrl != null ? NetworkImage(photoUrl) : null,
                child: photoUrl == null
                    ? const Icon(Icons.local_taxi, size: 50, color: AppColors.textHint)
                    : null,
              ),
              if (isVerified)
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: AppColors.success,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.check, color: Colors.white, size: 16),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            name.isNotEmpty ? name : 'Driver',
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: isVerified ? AppColors.success.withValues(alpha: 0.1) : AppColors.warning.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              isVerified ? '✓ Driver Verificado' : '⏳ Verificación Pendiente',
              style: TextStyle(
                color: isVerified ? AppColors.success : AppColors.warning,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVehicleCard(String? type, String? plate, String? color) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFE8C547).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE8C547).withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.directions_car, color: Color(0xFFE8C547), size: 40),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  type?.toUpperCase() ?? 'Vehículo no especificado',
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (plate != null && plate.isNotEmpty)
                  Text(
                    'Placa: $plate',
                    style: const TextStyle(color: AppColors.textSecondary, fontSize: 14),
                  ),
                if (color != null && color.isNotEmpty)
                  Text(
                    'Color: $color',
                    style: const TextStyle(color: AppColors.textHint, fontSize: 12),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVehicleDocuments() {
    if (_documents.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Text(
          'No hay documentos del vehículo',
          style: TextStyle(color: AppColors.textHint),
        ),
      );
    }

    return Column(
      children: _documents.map((doc) {
        final docType = (doc['doc_type'] as String? ?? 'documento').replaceAll('_', ' ').toUpperCase();
        final status = doc['status'] as String? ?? 'pending';
        final filePath = doc['file_path'] as String?;
        
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
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
                  const Icon(Icons.description, color: AppColors.textSecondary, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      docType,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: status == 'approved' 
                          ? AppColors.success.withValues(alpha: 0.1) 
                          : AppColors.warning.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      status.toUpperCase(),
                      style: TextStyle(
                        color: status == 'approved' ? AppColors.success : AppColors.warning,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              if (filePath != null) ...[
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    DispatchApiService.documentUrl(filePath),
                    height: 140,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => Container(
                      height: 80,
                      color: AppColors.surfaceHigh,
                      child: const Center(child: Icon(Icons.broken_image)),
                    ),
                  ),
                ),
              ],
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: const TextStyle(
          color: AppColors.textPrimary,
          fontSize: 16,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _buildInfoCard(List<Widget> children) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.textSecondary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                ),
                Text(
                  value,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmRevealSSN() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.security, color: AppColors.warning, size: 22),
            SizedBox(width: 8),
            Text('Reveal SSN?', style: TextStyle(color: AppColors.textPrimary, fontSize: 18)),
          ],
        ),
        content: const Text(
          'This action is logged for compliance. '
          'The SSN will auto-hide after 30 seconds.',
          style: TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Reveal', style: TextStyle(color: AppColors.warning, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    // Log to audit trail
    AuditService().log(
      action: 'viewed_ssn',
      targetCollection: 'drivers',
      targetId: widget.sqliteId.toString(),
      targetName: _userData?['first_name'] ?? 'unknown',
    );

    setState(() => _ssnRevealed = true);

    // Auto-hide after 30 seconds
    _ssnTimer?.cancel();
    _ssnTimer = Timer(const Duration(seconds: 30), () {
      if (mounted) setState(() => _ssnRevealed = false);
    });
  }

  Widget _buildSSNCard(bool ssnProvided, String? ssnFull, String? ssnMasked) {
    return GestureDetector(
      onTap: ssnProvided && ssnFull != null
          ? () {
              if (_ssnRevealed) {
                _ssnTimer?.cancel();
                setState(() => _ssnRevealed = false);
              } else {
                _confirmRevealSSN();
              }
            }
          : null,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: ssnProvided ? AppColors.success.withValues(alpha: 0.05) : AppColors.warning.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: ssnProvided ? AppColors.success.withValues(alpha: 0.3) : AppColors.warning.withValues(alpha: 0.3),
          ),
        ),
        child: Row(
          children: [
            Icon(
              Icons.security,
              color: ssnProvided ? AppColors.success : AppColors.warning,
              size: 24,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text(
                        'SSN',
                        style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                      ),
                      if (ssnProvided && ssnFull != null) ...[
                        const SizedBox(width: 8),
                        Text(
                          _ssnRevealed ? '(Toca para ocultar)' : '(Toca para revelar)',
                          style: TextStyle(color: AppColors.primary, fontSize: 10),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    ssnProvided
                        ? (_ssnRevealed && ssnFull != null ? ssnFull : (ssnMasked ?? '***-**-****'))
                        : 'No proporcionado',
                    style: TextStyle(
                      color: ssnProvided ? AppColors.textPrimary : AppColors.textHint,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      fontFamily: 'monospace',
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: ssnProvided ? AppColors.success : AppColors.warning,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                ssnProvided ? 'OK' : 'FALTA',
                style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVerificationPhotos(Map<String, dynamic> u) {
    final idPhoto = u['id_photo_url'] as String?;
    final selfie = u['selfie_url'] as String?;
    final licenseFront = u['license_front_url'] as String?;
    final licenseBack = u['license_back_url'] as String?;
    
    return Column(
      children: [
        if (idPhoto != null) _buildPhotoCard('ID Documento', idPhoto),
        if (selfie != null) _buildPhotoCard('Selfie', selfie),
        if (licenseFront != null) _buildPhotoCard('Licencia Frontal', licenseFront),
        if (licenseBack != null) _buildPhotoCard('Licencia Trasera', licenseBack),
      ],
    );
  }

  Widget _buildPhotoCard(String label, String url) {
    final fullUrl = url.startsWith('http') ? url : DispatchApiService.fullUrl(url);
    
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.network(
              fullUrl,
              height: 180,
              width: double.infinity,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => Container(
                height: 100,
                color: AppColors.surfaceHigh,
                child: const Center(child: Icon(Icons.broken_image)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageDriverButton(Map<String, dynamic> u) {
    final firebaseUid = u['firebase_uid'] as String?;
    final name = '${u['first_name'] ?? ''} ${u['last_name'] ?? ''}'.trim();
    if (firebaseUid == null || firebaseUid.isEmpty) {
      return const SizedBox.shrink();
    }
    return SizedBox(
      width: double.infinity,
      height: 44,
      child: OutlinedButton.icon(
        onPressed: () => Navigator.push(
          context,
          slideFromRightRoute(
            DispatchDriverChatScreen(
              driverId: firebaseUid,
              driverName: name.isNotEmpty ? name : 'Driver',
            ),
          ),
        ),
        icon: const Icon(Icons.chat_outlined, size: 18),
        label: const Text(
          'Message Driver',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primary,
          side: BorderSide(color: AppColors.primary.withValues(alpha: 0.4)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }

  Widget _buildSupportChats() {
    if (_chats.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Text(
          'No hay chats de soporte',
          style: TextStyle(color: AppColors.textHint),
        ),
      );
    }

    return Column(
      children: _chats.map((chat) {
        return Card(
          color: AppColors.surface,
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: const Icon(Icons.chat_bubble_outline, color: AppColors.primary),
            title: Text('Chat #${chat['id']}', style: const TextStyle(color: AppColors.textPrimary)),
            subtitle: Text(
              chat['lastMessage'] ?? 'Sin mensajes',
              style: const TextStyle(color: AppColors.textHint, fontSize: 12),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: AppColors.textHint),
            onTap: () => Navigator.push(
              context,
              slideFromRightRoute(
                SupportChatDetailScreen(
                  chatId: chat['id'] as int,
                  userName: '${_userData?['firstName'] ?? ''} ${_userData?['lastName'] ?? ''}'.trim(),
                  userId: widget.sqliteId,
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  // ─── EARNINGS SECTION ───────────────────────────────────────────────
  Widget _buildEarningsSection(Map<String, dynamic> u) {
    final firebaseUid = u['firebase_uid'] as String? ?? '';
    if (firebaseUid.isEmpty) {
      return const Text('No Firebase UID', style: TextStyle(color: AppColors.textHint));
    }
    return _DriverEarningsWidget(driverId: firebaseUid);
  }
}

class _DriverEarningsWidget extends StatefulWidget {
  final String driverId;
  const _DriverEarningsWidget({required this.driverId});

  @override
  State<_DriverEarningsWidget> createState() => _DriverEarningsWidgetState();
}

class _DriverEarningsWidgetState extends State<_DriverEarningsWidget> {
  int _days = 7;
  List<_DayEarning> _earnings = [];
  bool _loading = true;
  double _total = 0;
  int _tripCount = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final since = DateTime.now().subtract(Duration(days: _days));
      final snap = await FirebaseFirestore.instance
          .collection('trips')
          .where('driverId', isEqualTo: widget.driverId)
          .where('status', isEqualTo: 'completed')
          .where('completedAt', isGreaterThanOrEqualTo: Timestamp.fromDate(since))
          .get();

      final Map<String, double> byDay = {};
      double total = 0;
      for (final doc in snap.docs) {
        final d = doc.data();
        final earn = (d['driverEarnings'] as num?)?.toDouble() ??
            (d['fare'] as num?)?.toDouble() ?? 0;
        total += earn;
        final ts = d['completedAt'] as Timestamp?;
        if (ts != null) {
          final dt = ts.toDate();
          final key = '${dt.month}/${dt.day}';
          byDay[key] = (byDay[key] ?? 0) + earn;
        }
      }

      // Fill missing days
      final result = <_DayEarning>[];
      for (int i = _days - 1; i >= 0; i--) {
        final dt = DateTime.now().subtract(Duration(days: i));
        final key = '${dt.month}/${dt.day}';
        result.add(_DayEarning(label: key, amount: byDay[key] ?? 0));
      }

      if (mounted) {
        setState(() {
          _earnings = result;
          _total = total;
          _tripCount = snap.docs.length;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Period selector
          Row(
            children: [
              _periodChip(7),
              const SizedBox(width: 8),
              _periodChip(14),
              const SizedBox(width: 8),
              _periodChip(30),
              const Spacer(),
              if (!_loading)
                Text(
                  '$_tripCount viajes',
                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                ),
            ],
          ),
          const SizedBox(height: 12),
          // KPI row
          if (!_loading) ...[
            Row(
              children: [
                _kpi('Total', '\$${_total.toStringAsFixed(2)}'),
                const SizedBox(width: 16),
                _kpi('Promedio/día', '\$${(_total / _days).toStringAsFixed(2)}'),
                const SizedBox(width: 16),
                _kpi('Promedio/viaje',
                    _tripCount > 0 ? '\$${(_total / _tripCount).toStringAsFixed(2)}' : '\$0'),
              ],
            ),
            const SizedBox(height: 16),
            // Bar chart
            SizedBox(
              height: 160,
              child: _buildChart(),
            ),
          ],
          if (_loading)
            const SizedBox(
              height: 160,
              child: Center(child: CircularProgressIndicator(color: AppColors.primary)),
            ),
        ],
      ),
    );
  }

  Widget _periodChip(int days) {
    final selected = _days == days;
    return GestureDetector(
      onTap: () {
        _days = days;
        _load();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : AppColors.surfaceHigh,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          '${days}d',
          style: TextStyle(
            color: selected ? Colors.black : AppColors.textSecondary,
            fontSize: 12,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _kpi(String label, String value) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: AppColors.textHint, fontSize: 10)),
          Text(
            value,
            style: const TextStyle(
              color: AppColors.primary,
              fontWeight: FontWeight.w800,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChart() {
    if (_earnings.isEmpty) {
      return const Center(child: Text('Sin datos', style: TextStyle(color: AppColors.textHint)));
    }
    final maxY = _earnings.fold<double>(0, (m, e) => e.amount > m ? e.amount : m);
    return BarChart(
      BarChartData(
        maxY: maxY > 0 ? maxY * 1.2 : 10,
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            getTooltipItem: (group, gi, rod, ri) => BarTooltipItem(
              '\$${rod.toY.toStringAsFixed(2)}',
              const TextStyle(color: Colors.white, fontSize: 11),
            ),
          ),
        ),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 40,
              getTitlesWidget: (v, _) => Text(
                '\$${v.toInt()}',
                style: const TextStyle(color: AppColors.textHint, fontSize: 9),
              ),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 28,
              getTitlesWidget: (v, _) {
                final i = v.toInt();
                if (i < 0 || i >= _earnings.length) return const SizedBox.shrink();
                // Show every Nth label to avoid overlap
                final step = _earnings.length > 14 ? 3 : (_earnings.length > 7 ? 2 : 1);
                if (i % step != 0) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    _earnings[i].label,
                    style: const TextStyle(color: AppColors.textHint, fontSize: 9),
                  ),
                );
              },
            ),
          ),
        ),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          getDrawingHorizontalLine: (_) => FlLine(
            color: AppColors.cardBorder,
            strokeWidth: 0.5,
          ),
        ),
        borderData: FlBorderData(show: false),
        barGroups: _earnings.asMap().entries.map((e) {
          return BarChartGroupData(
            x: e.key,
            barRods: [
              BarChartRodData(
                toY: e.value.amount,
                color: AppColors.primary,
                width: _earnings.length > 14 ? 6 : 12,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }
}

class _DayEarning {
  final String label;
  final double amount;
  const _DayEarning({required this.label, required this.amount});
}
