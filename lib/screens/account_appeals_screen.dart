import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../config/app_theme.dart';
import '../config/page_transitions.dart';
import '../models/client_model.dart';
import '../models/driver_model.dart';
import '../services/client_service.dart';
import '../services/driver_service.dart';
import 'user_detail_page.dart';

/// Screen for managing account appeals from blocked/deactivated riders and drivers.
class AccountAppealsScreen extends StatefulWidget {
  final String roleFilter; // 'rider', 'driver', or '' for all
  const AccountAppealsScreen({super.key, this.roleFilter = ''});

  @override
  State<AccountAppealsScreen> createState() => _AccountAppealsScreenState();
}

class _AccountAppealsScreenState extends State<AccountAppealsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _driverService = DriverService();
  final _clientService = ClientService();

  List<Map<String, dynamic>> _appeals = [];
  bool _loading = true;
  String _filter = 'pending'; // pending, approved, rejected, all

  StreamSubscription? _appealsSub;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _listenAppeals();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _appealsSub?.cancel();
    super.dispose();
  }

  void _listenAppeals() {
    _appealsSub?.cancel();
    setState(() => _loading = true);

    Query query = FirebaseFirestore.instance.collection('account_appeals');
    if (widget.roleFilter.isNotEmpty) {
      // Filter by role: 'rider' matches 'rider' and 'client', 'driver' matches 'driver'
      if (widget.roleFilter == 'rider') {
        query = query.where('userRole', whereIn: ['rider', 'client']);
      } else {
        query = query.where('userRole', isEqualTo: widget.roleFilter);
      }
    }
    if (_filter != 'all') {
      query = query.where('status', isEqualTo: _filter);
    }
    query = query.orderBy('createdAt', descending: true);

    _appealsSub = query.snapshots().listen((snap) {
      final appeals = snap.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id;
        return data;
      }).toList();
      if (mounted) {
        setState(() {
          _appeals = appeals;
          _loading = false;
        });
      }
    }, onError: (e) {
      debugPrint('Error listening appeals: $e');
      if (mounted) setState(() => _loading = false);
    });
  }

  Future<void> _approveAppeal(Map<String, dynamic> appeal) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Aprobar Apelación?',
            style: TextStyle(color: AppColors.textPrimary)),
        content: Text(
          'Esto reactivará la cuenta de ${appeal['userName'] ?? 'usuario'}. ¿Continuar?',
          style: const TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.success),
            child: const Text('Aprobar'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      final role = appeal['userRole'] ?? '';
      final firestoreId = appeal['userFirestoreId'] ?? '';

      // Reactivate the user
      if (role == 'driver' && firestoreId.isNotEmpty) {
        await _driverService.updateStatus(firestoreId, 'active');
      } else if ((role == 'rider' || role == 'client') && firestoreId.isNotEmpty) {
        await _clientService.updateStatus(firestoreId, 'active');
      }

      // Update appeal status
      await FirebaseFirestore.instance
          .collection('account_appeals')
          .doc(appeal['id'])
          .update({
        'status': 'approved',
        'reviewedAt': FieldValue.serverTimestamp(),
        'reviewNote': 'Aprobado por admin',
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Apelación de ${appeal['userName']} aprobada'),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _rejectAppeal(Map<String, dynamic> appeal) async {
    final reasonCtrl = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Rechazar Apelación',
            style: TextStyle(color: AppColors.textPrimary)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Rechazar la apelación de ${appeal['userName'] ?? 'usuario'}.',
              style: const TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: reasonCtrl,
              maxLines: 3,
              style: const TextStyle(color: AppColors.textPrimary),
              decoration: InputDecoration(
                hintText: 'Razón del rechazo (opcional)...',
                hintStyle: const TextStyle(color: AppColors.textHint),
                filled: true,
                fillColor: AppColors.surfaceHigh,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Rechazar'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await FirebaseFirestore.instance
          .collection('account_appeals')
          .doc(appeal['id'])
          .update({
        'status': 'rejected',
        'reviewedAt': FieldValue.serverTimestamp(),
        'reviewNote': reasonCtrl.text.trim().isNotEmpty
            ? reasonCtrl.text.trim()
            : 'Rechazado por admin',
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Apelación de ${appeal['userName']} rechazada'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
    reasonCtrl.dispose();
  }

  Future<void> _navigateToUserDetail(Map<String, dynamic> appeal) async {
    final firestoreId = appeal['userFirestoreId'] as String?;
    final role = appeal['userRole'] as String? ?? '';
    if (firestoreId == null || firestoreId.isEmpty) return;

    try {
      if (role == 'driver') {
        final doc = await FirebaseFirestore.instance
            .collection('drivers')
            .doc(firestoreId)
            .get();
        if (doc.exists && mounted) {
          Navigator.push(
            context,
            slideFromRightRoute(
              UserDetailPage(
                driver: DriverModel.fromFirestore(doc),
              ),
            ),
          );
        }
      } else {
        final doc = await FirebaseFirestore.instance
            .collection('clients')
            .doc(firestoreId)
            .get();
        if (doc.exists && mounted) {
          Navigator.push(
            context,
            slideFromRightRoute(
              UserDetailPage(
                client: ClientModel.fromFirestore(doc),
              ),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al cargar perfil: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final pendingCount = _appeals.where((a) => a['status'] == 'pending').length;
    final approvedCount = _appeals.where((a) => a['status'] == 'approved').length;
    final rejectedCount = _appeals.where((a) => a['status'] == 'rejected').length;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppColors.primary),
          onPressed: () => Navigator.pop(context),
        ),
        elevation: 0,
        title: Text(
          widget.roleFilter == 'rider'
              ? 'Apelaciones Riders'
              : widget.roleFilter == 'driver'
                  ? 'Apelaciones Drivers'
                  : 'Apelaciones de Cuentas',
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: Column(
        children: [
          // Filter chips
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Row(
              children: [
                _filterChip('pending', 'Pendientes', pendingCount, AppColors.warning),
                const SizedBox(width: 8),
                _filterChip('approved', 'Aprobadas', approvedCount, AppColors.success),
                const SizedBox(width: 8),
                _filterChip('rejected', 'Rechazadas', rejectedCount, AppColors.error),
                const SizedBox(width: 8),
                _filterChip('all', 'Todas', _appeals.length, AppColors.primary),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.cardBorder),
          // Body
          Expanded(
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator(color: AppColors.primary),
                  )
                : _appeals.isEmpty
                    ? _buildEmptyState()
                    : RefreshIndicator(
                        onRefresh: () async => _listenAppeals(),
                        color: AppColors.primary,
                        child: ListView.builder(
                          padding: const EdgeInsets.all(12),
                          itemCount: _appeals.length,
                          itemBuilder: (_, i) => _buildAppealCard(_appeals[i]),
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _filterChip(String value, String label, int count, Color color) {
    final selected = _filter == value;
    return GestureDetector(
      onTap: () {
        setState(() => _filter = value);
        _listenAppeals();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: selected
              ? color.withValues(alpha: 0.20)
              : color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(20),
          border: selected
              ? Border.all(color: color.withValues(alpha: 0.40))
              : null,
        ),
        child: Text(
          '$label${_filter == 'all' || _filter == value ? ': $count' : ''}',
          style: TextStyle(
            fontSize: 12,
            color: color,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.gavel_rounded, size: 56, color: AppColors.textHint),
          const SizedBox(height: 12),
          Text(
            _filter == 'pending'
                ? 'No hay apelaciones pendientes'
                : 'No hay apelaciones',
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Las apelaciones aparecerán aquí cuando un usuario\nsolicite la reactivación de su cuenta.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.textHint,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppealCard(Map<String, dynamic> appeal) {
    final status = appeal['status'] ?? 'pending';
    final userName = appeal['userName'] ?? 'Usuario desconocido';
    final userRole = appeal['userRole'] ?? '';
    final reason = appeal['reason'] ?? '';
    final createdAt = (appeal['createdAt'] as Timestamp?)?.toDate();
    final reviewedAt = (appeal['reviewedAt'] as Timestamp?)?.toDate();
    final reviewNote = appeal['reviewNote'] ?? '';
    final previousStatus = appeal['previousStatus'] ?? 'blocked';
    final dateFmt = DateFormat('dd/MM/yyyy HH:mm');

    Color statusColor;
    IconData statusIcon;
    String statusLabel;
    switch (status) {
      case 'approved':
        statusColor = AppColors.success;
        statusIcon = Icons.check_circle;
        statusLabel = 'APROBADA';
        break;
      case 'rejected':
        statusColor = AppColors.error;
        statusIcon = Icons.cancel;
        statusLabel = 'RECHAZADA';
        break;
      default:
        statusColor = AppColors.warning;
        statusIcon = Icons.pending;
        statusLabel = 'PENDIENTE';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: status == 'pending'
              ? AppColors.warning.withValues(alpha: 0.3)
              : AppColors.cardBorder,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: statusColor.withValues(alpha: 0.15),
                  child: Icon(
                    userRole == 'driver' ? Icons.local_taxi : Icons.person,
                    color: statusColor,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        userName,
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.textHint.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              userRole.toUpperCase(),
                              style: const TextStyle(
                                fontSize: 10,
                                color: AppColors.textSecondary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.error.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              previousStatus == 'blocked'
                                  ? 'BLOQUEADO'
                                  : 'DESACTIVADO',
                              style: TextStyle(
                                fontSize: 10,
                                color: AppColors.error,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(statusIcon, color: statusColor, size: 14),
                      const SizedBox(width: 4),
                      Text(
                        statusLabel,
                        style: TextStyle(
                          fontSize: 10,
                          color: statusColor,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Reason
          if (reason.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.surfaceHigh,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Motivo de apelación:',
                      style: TextStyle(
                        color: AppColors.textHint,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      reason,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          // Review note (if reviewed)
          if (reviewNote.isNotEmpty && status != 'pending')
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: statusColor.withValues(alpha: 0.2)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Nota del admin:',
                      style: TextStyle(
                        color: statusColor,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      reviewNote,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          // Dates + Actions
          Container(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
            child: Row(
              children: [
                if (createdAt != null)
                  Text(
                    dateFmt.format(createdAt),
                    style: const TextStyle(
                      color: AppColors.textHint,
                      fontSize: 11,
                    ),
                  ),
                if (reviewedAt != null) ...[
                  const Text(' · ', style: TextStyle(color: AppColors.textHint)),
                  Text(
                    'Rev: ${dateFmt.format(reviewedAt)}',
                    style: const TextStyle(
                      color: AppColors.textHint,
                      fontSize: 11,
                    ),
                  ),
                ],
                const Spacer(),
                if (appeal['userFirestoreId'] != null)
                  TextButton.icon(
                    onPressed: () => _navigateToUserDetail(appeal),
                    icon: const Icon(Icons.person_search, size: 16),
                    label: const Text('Ver perfil', style: TextStyle(fontSize: 12)),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                    ),
                  ),
                if (status == 'pending') ...[
                  const SizedBox(width: 4),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: AppColors.error, size: 22),
                    tooltip: 'Rechazar',
                    onPressed: () => _rejectAppeal(appeal),
                  ),
                  IconButton(
                    icon: const Icon(Icons.check_rounded, color: AppColors.success, size: 22),
                    tooltip: 'Aprobar',
                    onPressed: () => _approveAppeal(appeal),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
