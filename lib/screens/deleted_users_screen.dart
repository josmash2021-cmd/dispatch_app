import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../config/app_theme.dart';
import '../services/audit_service.dart';

/// Screen showing soft-deleted users (riders + drivers) with restore / permanent delete.
class DeletedUsersScreen extends StatefulWidget {
  final String roleFilter; // 'rider', 'driver', or '' for all
  const DeletedUsersScreen({super.key, this.roleFilter = ''});

  @override
  State<DeletedUsersScreen> createState() => _DeletedUsersScreenState();
}

class _DeletedUsersScreenState extends State<DeletedUsersScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabCtrl;
  final _audit = AuditService();

  bool get _showRiders => widget.roleFilter.isEmpty || widget.roleFilter == 'rider';
  bool get _showDrivers => widget.roleFilter.isEmpty || widget.roleFilter == 'driver';
  int get _tabCount => (_showRiders && _showDrivers) ? 2 : 1;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: _tabCount, vsync: this);
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.primary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          widget.roleFilter == 'rider'
              ? 'Riders Eliminados'
              : widget.roleFilter == 'driver'
                  ? 'Drivers Eliminados'
                  : 'Usuarios Eliminados',
          style: const TextStyle(color: AppColors.textPrimary),
        ),
        bottom: _tabCount > 1
            ? TabBar(
                controller: _tabCtrl,
                indicatorColor: AppColors.primary,
                labelColor: AppColors.primary,
                unselectedLabelColor: AppColors.textSecondary,
                tabs: [
                  if (_showRiders) const Tab(text: 'Riders'),
                  if (_showDrivers) const Tab(text: 'Drivers'),
                ],
              )
            : null,
      ),
      body: _tabCount > 1
          ? TabBarView(
              controller: _tabCtrl,
              children: [
                if (_showRiders) _buildList('clients'),
                if (_showDrivers) _buildList('drivers'),
              ],
            )
          : _showRiders
              ? _buildList('clients')
              : _buildList('drivers'),
    );
  }

  Widget _buildList(String collection) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection(collection)
          .where('status', isEqualTo: 'deleted')
          .orderBy('deletedAt', descending: true)
          .snapshots(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: AppColors.primary),
          );
        }
        final docs = snap.data?.docs ?? [];
        if (docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.delete_outline, size: 48, color: AppColors.textHint),
                const SizedBox(height: 12),
                Text(
                  'Sin ${collection == 'clients' ? 'riders' : 'drivers'} eliminados',
                  style: const TextStyle(color: AppColors.textHint),
                ),
              ],
            ),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: docs.length,
          itemBuilder: (_, i) {
            final doc = docs[i];
            final d = doc.data()! as Map<String, dynamic>;
            final name = collection == 'clients'
                ? '${d['firstName'] ?? ''} ${d['lastName'] ?? ''}'.trim()
                : '${d['first_name'] ?? d['firstName'] ?? ''} ${d['last_name'] ?? d['lastName'] ?? ''}'.trim();
            final email = d['email'] as String? ?? '';
            final deletedAt = d['deletedAt'] as Timestamp?;

            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.cardBorder),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 22,
                    backgroundColor: AppColors.error.withValues(alpha: 0.15),
                    child: Icon(
                      collection == 'clients' ? Icons.person : Icons.local_taxi,
                      color: AppColors.error,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name.isNotEmpty ? name : 'Sin nombre',
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                        if (email.isNotEmpty)
                          Text(
                            email,
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                        if (deletedAt != null)
                          Text(
                            'Eliminado: ${_fmtDate(deletedAt.toDate())}',
                            style: const TextStyle(
                              color: AppColors.textHint,
                              fontSize: 11,
                            ),
                          ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.restore, color: AppColors.success),
                    tooltip: 'Restaurar',
                    onPressed: () => _restore(collection, doc.id, name),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_forever, color: AppColors.error),
                    tooltip: 'Eliminar permanente',
                    onPressed: () =>
                        _confirmPermanentDelete(collection, doc.id, name),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _restore(String collection, String docId, String name) async {
    try {
      await FirebaseFirestore.instance
          .collection(collection)
          .doc(docId)
          .update({'status': 'active', 'deletedAt': FieldValue.delete()});
      await _audit.log(
        action: 'restore_user',
        targetCollection: collection,
        targetId: docId,
        targetName: name,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$name restaurado'),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  Future<void> _confirmPermanentDelete(
    String collection,
    String docId,
    String name,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.warning, color: AppColors.error, size: 22),
            SizedBox(width: 8),
            Text(
              '¿Eliminar permanente?',
              style: TextStyle(color: AppColors.textPrimary, fontSize: 16),
            ),
          ],
        ),
        content: Text(
          'Esta acción eliminará a "$name" de forma permanente y no se puede deshacer.',
          style: const TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Eliminar',
              style: TextStyle(color: AppColors.error, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    try {
      await FirebaseFirestore.instance
          .collection(collection)
          .doc(docId)
          .delete();
      await _audit.log(
        action: 'permanent_delete',
        targetCollection: collection,
        targetId: docId,
        targetName: name,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$name eliminado permanentemente'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  String _fmtDate(DateTime dt) {
    return '${dt.month}/${dt.day}/${dt.year}';
  }
}
