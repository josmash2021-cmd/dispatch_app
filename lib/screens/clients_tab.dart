import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../config/app_theme.dart';
import '../models/client_model.dart';
import '../providers/client_provider.dart';
import '../services/dispatch_api_service.dart';
import 'user_detail_page.dart';
import '../widgets/animated_list_item.dart';
import '../widgets/re_auth_dialog.dart';
import '../widgets/shimmer_loading.dart';

class ClientsTab extends StatefulWidget {
  const ClientsTab({super.key});
  @override
  State<ClientsTab> createState() => _ClientsTabState();
}

class _ClientsTabState extends State<ClientsTab> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ClientProvider>();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: TextField(
            controller: _searchController,
            onChanged: provider.setSearchQuery,
            style: const TextStyle(color: AppColors.textPrimary),
            decoration: InputDecoration(
              hintText: 'Search by name, phone, email...',
              hintStyle: const TextStyle(color: AppColors.textHint),
              prefixIcon: const Icon(
                Icons.search_rounded,
                color: AppColors.textHint,
              ),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(
                        Icons.clear_rounded,
                        color: AppColors.textHint,
                      ),
                      onPressed: () {
                        _searchController.clear();
                        provider.setSearchQuery('');
                      },
                    )
                  : null,
              filled: true,
              fillColor: AppColors.surfaceHigh,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Row(
            children: [
              _countChip('Total', provider.totalClients, AppColors.primary),
              const SizedBox(width: 8),
              _countChip(
                'Shown',
                provider.clients.length,
                AppColors.textSecondary,
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        Expanded(child: _buildBody(provider)),
      ],
    );
  }

  Widget _countChip(String label, int count, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        '$label: $count',
        style: TextStyle(
          fontSize: 12,
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildBody(ClientProvider provider) {
    if (provider.isLoading) {
      return const ShimmerLoadingList(itemCount: 5, type: ShimmerType.person);
    }
    if (provider.errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.wifi_off_rounded,
              size: 52,
              color: AppColors.textHint,
            ),
            const SizedBox(height: 12),
            Text(
              provider.errorMessage!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: provider.refreshClients,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }
    if (provider.clients.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.people_outline_rounded,
              size: 56,
              color: AppColors.textHint,
            ),
            const SizedBox(height: 12),
            Text(
              provider.searchQuery.isNotEmpty
                  ? 'No clients match your search'
                  : 'No clients registered yet',
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 16,
              ),
            ),
          ],
        ),
      );
    }
    return RefreshIndicator(
      color: AppColors.primary,
      backgroundColor: AppColors.surface,
      onRefresh: provider.refreshClients,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
        itemCount: provider.clients.length,
        itemBuilder: (context, i) => AnimatedListItem(
          index: i,
          child: _ClientCard(client: provider.clients[i]),
        ),
      ),
    );
  }
}

// ─── Status helpers ─────────────────────────────────────────────────────────

Color _statusColor(String status) {
  switch (status) {
    case 'active':
      return AppColors.success;
    case 'deactivated':
      return AppColors.warning;
    case 'blocked':
      return AppColors.error;
    default:
      return AppColors.textHint;
  }
}

IconData _statusIcon(String status) {
  switch (status) {
    case 'active':
      return Icons.check_circle_rounded;
    case 'deactivated':
      return Icons.pause_circle_filled_rounded;
    case 'blocked':
      return Icons.block_rounded;
    default:
      return Icons.help_outline_rounded;
  }
}

String _statusLabel(String status) {
  switch (status) {
    case 'active':
      return 'Active';
    case 'deactivated':
      return 'Deactivated';
    case 'blocked':
      return 'Blocked';
    default:
      return status;
  }
}

// ─── Client Card ────────────────────────────────────────────────────────────

class _ClientCard extends StatelessWidget {
  final ClientModel client;
  const _ClientCard({required this.client});

  @override
  Widget build(BuildContext context) {
    final color = _statusColor(client.status);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: client.isBlocked
              ? AppColors.error.withValues(alpha: 0.30)
              : client.isInactive
              ? AppColors.warning.withValues(alpha: 0.20)
              : AppColors.cardBorder,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => UserDetailPage(client: client)),
          ),
          onLongPress: () => _showActions(context, client),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Stack(
                  children: [
                    Opacity(
                      opacity: client.isBlocked
                          ? 0.45
                          : client.isInactive
                          ? 0.6
                          : 1.0,
                      child: CircleAvatar(
                        radius: 24,
                        backgroundColor: AppColors.primary.withValues(
                          alpha: 0.15,
                        ),
                        backgroundImage: client.photoUrl != null
                            ? NetworkImage(client.photoUrl!)
                            : null,
                        child: client.photoUrl == null
                            ? Text(
                                client.fullName.isNotEmpty
                                    ? client.fullName[0].toUpperCase()
                                    : '?',
                                style: const TextStyle(
                                  color: AppColors.primary,
                                  fontSize: 20,
                                  fontWeight: FontWeight.w700,
                                ),
                              )
                            : null,
                      ),
                    ),
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: Container(
                        width: 14,
                        height: 14,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: AppColors.surface,
                            width: 2,
                          ),
                        ),
                        child: Icon(
                          _statusIcon(client.status),
                          size: 8,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    // Online indicator (top-right)
                    Positioned(
                      right: 0,
                      top: 0,
                      child: Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: client.isOnline
                              ? AppColors.success
                              : AppColors.textHint,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: AppColors.surface,
                            width: 2,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              client.fullName.isNotEmpty
                                  ? client.fullName
                                  : 'Unknown',
                              style: TextStyle(
                                color: client.isBlocked
                                    ? AppColors.textSecondary
                                    : AppColors.textPrimary,
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                decoration: client.isBlocked
                                    ? TextDecoration.lineThrough
                                    : null,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: color.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              _statusLabel(client.status),
                              style: TextStyle(
                                fontSize: 10,
                                color: color,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          const Icon(
                            Icons.phone_outlined,
                            size: 13,
                            color: AppColors.textHint,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            client.phone.isNotEmpty ? client.phone : 'No phone',
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                      if (client.email != null && client.email!.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            const Icon(
                              Icons.email_outlined,
                              size: 13,
                              color: AppColors.textHint,
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                client.email!,
                                style: const TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 13,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(
                    Icons.more_vert_rounded,
                    color: AppColors.textHint,
                    size: 20,
                  ),
                  onPressed: () => _showActions(context, client),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 32,
                    minHeight: 32,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showActions(BuildContext context, ClientModel client) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.cardBorder,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Icon(
                    _statusIcon(client.status),
                    color: _statusColor(client.status),
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      client.fullName,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: _statusColor(
                        client.status,
                      ).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      _statusLabel(client.status),
                      style: TextStyle(
                        fontSize: 12,
                        color: _statusColor(client.status),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              _actionTile(
                icon: Icons.edit_rounded,
                label: 'Edit Client',
                subtitle: 'Update profile information',
                color: AppColors.primary,
                onTap: () {
                  Navigator.pop(ctx);
                  _showEditClient(context, client);
                },
              ),
              const Divider(color: AppColors.cardBorder, height: 16),
              if (!client.isActive)
                _actionTile(
                  icon: Icons.check_circle_outline_rounded,
                  label: 'Activate',
                  subtitle: 'Restore full access',
                  color: AppColors.success,
                  onTap: () {
                    Navigator.pop(ctx);
                    _changeStatus(context, client, 'active');
                  },
                ),
              if (!client.isInactive)
                _actionTile(
                  icon: Icons.pause_circle_outline_rounded,
                  label: 'Deactivate',
                  subtitle: 'Temporarily suspend',
                  color: AppColors.warning,
                  onTap: () {
                    Navigator.pop(ctx);
                    _changeStatus(context, client, 'deactivated');
                  },
                ),
              if (!client.isBlocked)
                _actionTile(
                  icon: Icons.block_rounded,
                  label: 'Block',
                  subtitle: 'Permanently deny access',
                  color: AppColors.error,
                  onTap: () {
                    Navigator.pop(ctx);
                    _changeStatus(context, client, 'blocked');
                  },
                ),
              const Divider(color: AppColors.cardBorder, height: 24),
              _actionTile(
                icon: Icons.delete_forever_rounded,
                label: 'Delete permanently',
                subtitle: 'Remove from database',
                color: AppColors.error,
                onTap: () {
                  Navigator.pop(ctx);
                  _confirmDelete(context, client);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _actionTile({
    required IconData icon,
    required String label,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: color, size: 22),
      ),
      title: Text(
        label,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w600,
          fontSize: 15,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: const TextStyle(color: AppColors.textHint, fontSize: 12),
      ),
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    );
  }

  void _changeStatus(
    BuildContext context,
    ClientModel client,
    String newStatus,
  ) {
    final action = _statusLabel(newStatus);
    final color = _statusColor(newStatus);
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(_statusIcon(newStatus), color: color, size: 22),
            const SizedBox(width: 8),
            Text(
              '$action Client',
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 18,
              ),
            ),
          ],
        ),
        content: Text(
          'Change ${client.fullName} status to "$action"?',
          style: const TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(dialogCtx);
              context.read<ClientProvider>().updateClientStatus(
                client.clientId,
                newStatus,
                clientName: client.fullName,
              );
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  backgroundColor: AppColors.surfaceHigh,
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  content: Row(
                    children: [
                      Icon(_statusIcon(newStatus), color: color, size: 18),
                      const SizedBox(width: 8),
                      Text(
                        '${client.fullName} → $action',
                        style: const TextStyle(color: AppColors.textPrimary),
                      ),
                    ],
                  ),
                ),
              );
            },
            child: Text(
              action,
              style: TextStyle(color: color, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
  // ─── Edit Client ────────────────────────────────────────────────────────

  void _showEditClient(BuildContext context, ClientModel client) {
    final firstNameCtrl = TextEditingController(text: client.firstName);
    final lastNameCtrl = TextEditingController(text: client.lastName);
    final phoneCtrl = TextEditingController(text: client.phone);
    final emailCtrl = TextEditingController(text: client.email ?? '');

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(
          24,
          16,
          24,
          MediaQuery.of(ctx).viewInsets.bottom + 24,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.cardBorder,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Row(
                children: [
                  Icon(Icons.edit_rounded, color: AppColors.primary, size: 20),
                  SizedBox(width: 8),
                  Text(
                    'Edit Client',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              _editField('First Name', firstNameCtrl, Icons.person_outline),
              const SizedBox(height: 12),
              _editField('Last Name', lastNameCtrl, Icons.person_outline),
              const SizedBox(height: 12),
              _editField('Phone', phoneCtrl, Icons.phone_outlined),
              const SizedBox(height: 12),
              _editField('Email', emailCtrl, Icons.email_outlined),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    final data = <String, dynamic>{};
                    if (firstNameCtrl.text.trim() != client.firstName) {
                      data['firstName'] = firstNameCtrl.text.trim();
                    }
                    if (lastNameCtrl.text.trim() != client.lastName) {
                      data['lastName'] = lastNameCtrl.text.trim();
                    }
                    if (phoneCtrl.text.trim() != client.phone) {
                      data['phone'] = phoneCtrl.text.trim();
                    }
                    final email = emailCtrl.text.trim();
                    if (email != (client.email ?? '')) {
                      data['email'] = email.isEmpty ? null : email;
                    }
                    if (data.isEmpty) {
                      Navigator.pop(ctx);
                      return;
                    }
                    context.read<ClientProvider>().updateClient(
                      client.clientId,
                      data,
                      clientName: client.fullName,
                    );
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        backgroundColor: AppColors.surfaceHigh,
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        content: Row(
                          children: [
                            const Icon(
                              Icons.check_circle_rounded,
                              color: AppColors.success,
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '${client.fullName} updated',
                              style: const TextStyle(
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.save_rounded, size: 18),
                  label: const Text('Save Changes'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: const Color(0xFF1A1400),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _editField(String label, TextEditingController ctrl, IconData icon) {
    return TextField(
      controller: ctrl,
      style: const TextStyle(color: AppColors.textPrimary),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: AppColors.textSecondary),
        prefixIcon: Icon(icon, color: AppColors.textHint, size: 20),
        filled: true,
        fillColor: AppColors.surfaceHigh,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 12,
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context, ClientModel client) {
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(
              Icons.delete_forever_rounded,
              color: AppColors.error,
              size: 22,
            ),
            SizedBox(width: 8),
            Text(
              'Delete Client',
              style: TextStyle(color: AppColors.textPrimary, fontSize: 18),
            ),
          ],
        ),
        content: Text(
          'Permanently delete ${client.fullName}? This cannot be undone.',
          style: const TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(dialogCtx);
              final confirmed = await showReAuthDialog(
                context,
                actionDescription:
                    'Deleting "${client.fullName}" is permanent.',
              );
              if (confirmed && context.mounted) {
                context.read<ClientProvider>().updateClientStatus(
                  client.clientId,
                  'deleted',
                  clientName: client.fullName,
                );
              }
            },
            child: const Text(
              'Delete',
              style: TextStyle(
                color: AppColors.error,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Server Documents Widget ──────────────────────────────────────────────

// ─── Password Widget (fetches real password from backend) ─────────────────────

class _UserPasswordWidget extends StatefulWidget {
  final int sqliteId;
  const _UserPasswordWidget({required this.sqliteId});
  @override
  State<_UserPasswordWidget> createState() => _UserPasswordWidgetState();
}

class _UserPasswordWidgetState extends State<_UserPasswordWidget> {
  String? _password;
  bool _loading = true;
  bool _visible = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final detail = await DispatchApiService.getUserDetail(widget.sqliteId);
      if (mounted) {
        setState(() {
          _password = detail['password_plain'] as String?;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            Icon(Icons.lock_outlined, size: 18, color: AppColors.textSecondary),
            SizedBox(width: 12),
            Text(
              'Password',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
            ),
            Spacer(),
            SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppColors.primary,
              ),
            ),
          ],
        ),
      );
    }
    final hasPass = _password != null && _password!.isNotEmpty;
    final display = hasPass ? (_visible ? _password! : '••••••••') : '';

    // No plain text stored — show warning badge
    if (!hasPass) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            const Icon(
              Icons.lock_open_outlined,
              size: 18,
              color: AppColors.warning,
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Password',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              decoration: BoxDecoration(
                color: AppColors.warning.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(7),
                border: Border.all(
                  color: AppColors.warning.withValues(alpha: 0.3),
                ),
              ),
              child: const Text(
                'Usa Reset ↓',
                style: TextStyle(
                  color: AppColors.warning,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Icon(
            Icons.lock_outlined,
            size: 18,
            color: AppColors.textSecondary,
          ),
          const SizedBox(width: 12),
          const Text(
            'Password',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
          ),
          const Spacer(),
          if (hasPass) ...[
            GestureDetector(
              onTap: () => setState(() => _visible = !_visible),
              child: Text(
                display,
                style: TextStyle(
                  color: _visible ? AppColors.primary : AppColors.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  fontFamily: 'monospace',
                ),
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () {
                Clipboard.setData(ClipboardData(text: _password!));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Password copied'),
                    duration: Duration(seconds: 1),
                  ),
                );
              },
              child: const Icon(
                Icons.copy_rounded,
                size: 16,
                color: AppColors.primary,
              ),
            ),
          ] else
            Text(
              display,
              style: const TextStyle(color: AppColors.textHint, fontSize: 13),
            ),
        ],
      ),
    );
  }
}

// ─── Verification Photos Widget (from Firestore verifications) ────────────────

class _VerifPhotosWidget extends StatefulWidget {
  final int sqliteId;
  const _VerifPhotosWidget({required this.sqliteId});
  @override
  State<_VerifPhotosWidget> createState() => _VerifPhotosWidgetState();
}

class _VerifPhotosWidgetState extends State<_VerifPhotosWidget> {
  Map<String, dynamic>? _data;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('verifications')
          .doc('sql_${widget.sqliteId}')
          .get();
      if (mounted) {
        setState(() {
          _data = doc.exists ? doc.data() : null;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Widget _photoTile(String label, String? url) {
    if (url == null || url.isEmpty) return const SizedBox.shrink();
    final resolvedUrl = url.startsWith('http')
        ? url
        : DispatchApiService.fullUrl(url);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Image.network(
            resolvedUrl,
            height: 160,
            width: double.infinity,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => Container(
              height: 80,
              decoration: BoxDecoration(
                color: AppColors.surfaceHigh,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Center(
                child: Icon(
                  Icons.broken_image_outlined,
                  color: AppColors.textHint,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: AppColors.primary,
            ),
          ),
        ),
      );
    }
    if (_data == null) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: Text(
          'No verification submitted',
          style: TextStyle(color: AppColors.textHint, fontSize: 13),
        ),
      );
    }
    final profileUrl = _data!['profilePhotoUrl'] as String?;
    final idUrl = _data!['idPhotoUrl'] as String?;
    final selfieUrl = _data!['selfieUrl'] as String?;
    final idType = _data!['idDocumentType'] as String? ?? 'Government ID';
    final status = _data!['status'] as String? ?? 'pending';
    final statusColor = status == 'approved'
        ? AppColors.success
        : status == 'rejected'
        ? AppColors.error
        : AppColors.warning;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(
            children: [
              const Text(
                'Status:',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  status.toUpperCase(),
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
        _photoTile('Profile Photo', profileUrl),
        _photoTile('ID Document ($idType)', idUrl),
        _photoTile('Selfie / Selfie with ID', selfieUrl),
      ],
    );
  }
}

// ─── Server Documents Widget (uses getUserDetail) ─────────────────────────────

class _UserDetailDocsWidget extends StatefulWidget {
  final int sqliteId;
  const _UserDetailDocsWidget({required this.sqliteId});
  @override
  State<_UserDetailDocsWidget> createState() => _UserDetailDocsWidgetState();
}

class _UserDetailDocsWidgetState extends State<_UserDetailDocsWidget> {
  List<Map<String, dynamic>>? _docs;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadDocs();
  }

  Future<void> _loadDocs() async {
    try {
      final detail = await DispatchApiService.getUserDetail(widget.sqliteId);
      final docs = (detail['documents'] as List? ?? [])
          .cast<Map<String, dynamic>>();
      if (mounted) {
        setState(() {
          _docs = docs;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = '$e';
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }
    if (_error != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Text(
          'Could not load: $_error',
          style: const TextStyle(color: AppColors.textHint, fontSize: 13),
        ),
      );
    }
    if (_docs == null || _docs!.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: Text(
          'No documents uploaded',
          style: TextStyle(color: AppColors.textHint, fontSize: 13),
        ),
      );
    }
    return Column(
      children: _docs!.map((doc) {
        final docType = (doc['doc_type'] as String? ?? 'unknown').replaceAll(
          '_',
          ' ',
        );
        final status = doc['status'] as String? ?? 'pending';
        final filePath = doc['file_path'] as String?;
        final statusColor = status == 'approved'
            ? AppColors.success
            : status == 'rejected'
            ? AppColors.error
            : AppColors.warning;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  const Icon(
                    Icons.description_rounded,
                    size: 16,
                    color: AppColors.textSecondary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      docType.toUpperCase(),
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      status,
                      style: TextStyle(
                        fontSize: 11,
                        color: statusColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (filePath != null) ...[
              const SizedBox(height: 4),
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.network(
                  DispatchApiService.documentUrl(filePath),
                  height: 140,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (_, e, s) => Container(
                    height: 60,
                    decoration: BoxDecoration(
                      color: AppColors.surfaceHigh,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Center(
                      child: Icon(
                        Icons.broken_image_outlined,
                        color: AppColors.textHint,
                        size: 28,
                      ),
                    ),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 8),
          ],
        );
      }).toList(),
    );
  }
}
