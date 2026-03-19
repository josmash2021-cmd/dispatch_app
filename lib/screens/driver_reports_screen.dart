import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../config/app_theme.dart';

class DriverReportsScreen extends StatefulWidget {
  final bool showAppBar;
  const DriverReportsScreen({super.key, this.showAppBar = true});

  @override
  State<DriverReportsScreen> createState() => _DriverReportsScreenState();
}

class _DriverReportsScreenState extends State<DriverReportsScreen> {
  StreamSubscription? _reportsSub;
  List<Map<String, dynamic>> _reports = [];
  bool _loading = true;
  int _pendingCount = 0;
  int _resolvedCount = 0;

  @override
  void initState() {
    super.initState();
    _startListening();
  }

  void _startListening() {
    _reportsSub = FirebaseFirestore.instance
        .collection('driver_reports')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .listen((snapshot) {
      final reports = snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();

      final pending = reports.where((r) => r['status'] == 'pending').length;
      final resolved = reports.where((r) => r['status'] == 'resolved').length;

      if (mounted) {
        setState(() {
          _reports = reports;
          _pendingCount = pending;
          _resolvedCount = resolved;
          _loading = false;
        });
      }
    });
  }

  @override
  void dispose() {
    _reportsSub?.cancel();
    super.dispose();
  }

  Future<void> _markAsResolved(String reportId) async {
    await FirebaseFirestore.instance
        .collection('driver_reports')
        .doc(reportId)
        .update({'status': 'resolved', 'resolvedAt': Timestamp.now()});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: widget.showAppBar
          ? AppBar(
              backgroundColor: AppColors.background,
              elevation: 0,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back_rounded, color: AppColors.primary),
                onPressed: () => Navigator.pop(context),
              ),
              title: const Text(
                'Reportes de Drivers',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            )
          : null,
      body: Column(
        children: [
          // Stats Header
          _buildStatsHeader(),
          
          // Reports List
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _reports.isEmpty
                    ? _emptyState()
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _reports.length,
                        itemBuilder: (context, index) {
                          final report = _reports[index];
                          return _ReportCard(
                            report: report,
                            onResolve: () => _markAsResolved(report['id']),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsHeader() {
    return Container(
      margin: const EdgeInsets.all(16),
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
        border: Border.all(color: AppColors.primary.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _StatItem(
            value: '$_pendingCount',
            label: 'Pendientes',
            color: AppColors.primary,
          ),
          _StatItem(
            value: '$_resolvedCount',
            label: 'Resueltos',
            color: AppColors.success,
          ),
          _StatItem(
            value: '${_reports.length}',
            label: 'Total',
            color: AppColors.primary,
          ),
        ],
      ),
    );
  }

  Widget _emptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.check_circle_outline,
            size: 80,
            color: AppColors.success.withOpacity(0.5),
          ),
          const SizedBox(height: 16),
          const Text(
            'Sin reportes pendientes',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Los drivers no han reportado problemas',
            style: TextStyle(color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _ReportCard extends StatelessWidget {
  final Map<String, dynamic> report;
  final VoidCallback onResolve;

  const _ReportCard({required this.report, required this.onResolve});

  @override
  Widget build(BuildContext context) {
    final type = report['type'] as String? ?? 'unknown';
    final status = report['status'] as String? ?? 'pending';
    final driverName = report['driverName'] ?? 'Driver Desconocido';
    final message = report['message'] ?? 'Sin descripción';
    final createdAt = (report['createdAt'] as Timestamp?)?.toDate();
    final isPending = status == 'pending';

    IconData typeIcon;
    Color typeColor;
    String typeLabel;

    switch (type) {
      case 'app_crash':
        typeIcon = Icons.error_outline;
        typeColor = AppColors.primary;
        typeLabel = 'App Crash';
        break;
      case 'bug':
        typeIcon = Icons.bug_report;
        typeColor = AppColors.primary;
        typeLabel = 'Bug / Error';
        break;
      case 'feature_request':
        typeIcon = Icons.lightbulb_outline;
        typeColor = AppColors.primary;
        typeLabel = 'Sugerencia';
        break;
      case 'complaint':
        typeIcon = Icons.warning_amber;
        typeColor = AppColors.primary;
        typeLabel = 'Queja';
        break;
      default:
        typeIcon = Icons.report_problem;
        typeColor = AppColors.textSecondary;
        typeLabel = 'Otro';
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isPending ? typeColor.withOpacity(0.3) : AppColors.cardBorder,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: typeColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(typeIcon, color: typeColor, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        typeLabel,
                        style: TextStyle(
                          color: typeColor,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        driverName,
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: isPending 
                        ? AppColors.primary.withOpacity(0.1) 
                        : AppColors.success.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    isPending ? 'PENDIENTE' : 'RESUELTO',
                    style: TextStyle(
                      color: isPending ? AppColors.primary : AppColors.success,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 12),
            
            // Message
            Text(
              message,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 14,
              ),
            ),
            
            // Device info if available
            if (report['deviceInfo'] != null) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.surfaceHigh,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Dispositivo: ${report['deviceInfo']}',
                  style: const TextStyle(
                    color: AppColors.textHint,
                    fontSize: 11,
                  ),
                ),
              ),
            ],
            
            const SizedBox(height: 12),
            
            // Footer with time and actions
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  createdAt != null ? _timeAgo(createdAt) : 'Fecha desconocida',
                  style: const TextStyle(
                    color: AppColors.textHint,
                    fontSize: 12,
                  ),
                ),
                if (isPending)
                  TextButton.icon(
                    onPressed: onResolve,
                    icon: const Icon(Icons.check_circle, size: 18),
                    label: const Text('Marcar Resuelto'),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.success,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _timeAgo(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);
    
    if (diff.inDays > 0) return 'Hace ${diff.inDays} días';
    if (diff.inHours > 0) return 'Hace ${diff.inHours} horas';
    if (diff.inMinutes > 0) return 'Hace ${diff.inMinutes} minutos';
    return 'Hace un momento';
  }
}

class _StatItem extends StatelessWidget {
  final String value;
  final String label;
  final Color color;

  const _StatItem({
    required this.value,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 28,
            fontWeight: FontWeight.w800,
          ),
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
    );
  }
}
