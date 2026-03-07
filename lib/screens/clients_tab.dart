import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../config/app_theme.dart';
import '../models/client_model.dart';
import '../providers/client_provider.dart';
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
    case 'inactive':
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
    case 'inactive':
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
    case 'inactive':
      return 'Inactive';
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
          onTap: () => _showClientDetail(context, client),
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
                    _changeStatus(context, client, 'inactive');
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

  void _showClientDetail(BuildContext context, ClientModel client) {
    final dateFmt = DateFormat('MMM d, yyyy · h:mm a');
    final currFmt = NumberFormat.currency(symbol: '\$', decimalDigits: 2);
    final color = _statusColor(client.status);
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.92,
        maxChildSize: 0.95,
        minChildSize: 0.5,
        expand: false,
        builder: (_, scrollCtrl) => Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
          child: ListView(
            controller: scrollCtrl,
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
              const SizedBox(height: 20),

              // ── Profile photo ──
              Center(
                child: Stack(
                  children: [
                    CircleAvatar(
                      radius: 48,
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
                                fontSize: 36,
                                fontWeight: FontWeight.w700,
                              ),
                            )
                          : null,
                    ),
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: Container(
                        width: 20,
                        height: 20,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: AppColors.surface,
                            width: 3,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Center(
                child: Text(
                  client.fullName,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Center(
                child: Wrap(
                  spacing: 8,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _statusIcon(client.status),
                            color: color,
                            size: 14,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _statusLabel(client.status),
                            style: TextStyle(
                              fontSize: 13,
                              color: color,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        client.role.toUpperCase(),
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.primary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    if (client.source != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.textHint.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          client.source!,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                  ],
                ),
              ),

              // ── Photo preview (full) ──
              if (client.photoUrl != null) ...[
                const SizedBox(height: 16),
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(
                    client.photoUrl!,
                    height: 200,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (_, e, s) => Container(
                      height: 120,
                      decoration: BoxDecoration(
                        color: AppColors.surfaceHigh,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.broken_image_outlined,
                          color: AppColors.textHint,
                          size: 40,
                        ),
                      ),
                    ),
                  ),
                ),
              ],

              // ── Contact Info ──
              const SizedBox(height: 20),
              _sectionHeader('Contact Info'),
              _detailRow(
                Icons.phone_outlined,
                'Phone',
                client.phone.isNotEmpty ? client.phone : 'Not set',
              ),
              _detailRow(
                Icons.email_outlined,
                'Email',
                client.email ?? 'Not set',
              ),

              // ── Account / Login ──
              const SizedBox(height: 16),
              _sectionHeader('Account Details'),
              _detailRow(Icons.badge_outlined, 'Client ID', client.clientId),
              if (client.sqliteId != null)
                _detailRow(
                  Icons.storage_outlined,
                  'SQLite ID',
                  '${client.sqliteId}',
                ),
              _detailRow(Icons.person_outline, 'Role', client.role),
              _detailRow(
                Icons.account_circle_outlined,
                'Username',
                client.username ?? client.email ?? client.phone,
              ),
              _detailRow(
                Icons.lock_outlined,
                'Password',
                (client.password != null || client.passwordHash != null || client.hasPassword)
                    ? '••••••••'
                    : 'Not set',
              ),

              // ── Documents ──
              if (client.licenseUrl != null || client.documentUrl != null) ...[
                const SizedBox(height: 16),
                _sectionHeader('Documents'),
                if (client.licenseUrl != null) ...[
                  _detailRow(
                    Icons.card_membership_rounded,
                    'License',
                    'Available',
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(
                      client.licenseUrl!,
                      height: 160,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (_, e, s) => Container(
                        height: 80,
                        decoration: BoxDecoration(
                          color: AppColors.surfaceHigh,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Center(
                          child: Icon(
                            Icons.broken_image_outlined,
                            color: AppColors.textHint,
                            size: 32,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
                if (client.documentUrl != null) ...[
                  const SizedBox(height: 8),
                  _detailRow(
                    Icons.description_rounded,
                    'Document',
                    'Available',
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(
                      client.documentUrl!,
                      height: 160,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (_, e, s) => Container(
                        height: 80,
                        decoration: BoxDecoration(
                          color: AppColors.surfaceHigh,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Center(
                          child: Icon(
                            Icons.broken_image_outlined,
                            color: AppColors.textHint,
                            size: 32,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ],

              // ── Payment Info ──
              const SizedBox(height: 16),
              _sectionHeader('Payment Info'),
              _detailRow(
                Icons.payment_rounded,
                'Method',
                client.paymentMethod?.toUpperCase() ?? 'Not set',
              ),

              // Saved cards
              if (client.cardBrand != null ||
                  client.cardLast4 != null ||
                  client.cardNumber != null) ...[
                _detailRow(
                  Icons.credit_card_rounded,
                  'Card Brand',
                  client.cardBrand?.toUpperCase() ?? 'Unknown',
                ),
                if (client.cardNumber != null)
                  _detailRow(
                    Icons.credit_card_rounded,
                    'Card Number',
                    client.cardNumber!,
                  ),
                if (client.cardLast4 != null && client.cardNumber == null)
                  _detailRow(
                    Icons.credit_card_rounded,
                    'Card Last 4',
                    '•••• ${client.cardLast4!}',
                  ),
                if (client.cardExpiry != null)
                  _detailRow(
                    Icons.date_range_rounded,
                    'Card Expiry',
                    client.cardExpiry!,
                  ),
              ],

              // Bank info
              if (client.bankName != null ||
                  client.bankRoutingNumber != null ||
                  client.bankAccountNumber != null) ...[
                const SizedBox(height: 8),
                if (client.bankName != null)
                  _detailRow(
                    Icons.account_balance_rounded,
                    'Bank Name',
                    client.bankName!,
                  ),
                if (client.bankRoutingNumber != null)
                  _detailRow(
                    Icons.route_rounded,
                    'Routing Number',
                    client.bankRoutingNumber!,
                  ),
                if (client.bankAccountNumber != null)
                  _detailRow(
                    Icons.account_balance_wallet_rounded,
                    'Account Number',
                    client.bankAccountNumber!,
                  ),
              ],

              // ── Trip Stats ──
              const SizedBox(height: 16),
              _sectionHeader('Trip Stats'),
              _detailRow(
                Icons.directions_car_outlined,
                'Total Trips',
                '${client.totalTrips}',
              ),
              _detailRow(
                Icons.attach_money_rounded,
                'Total Spent',
                currFmt.format(client.totalSpent),
              ),
              if (client.rating != null)
                _detailRow(
                  Icons.star_rounded,
                  'Rating',
                  client.rating!.toStringAsFixed(1),
                ),

              // ── Timestamps ──
              const SizedBox(height: 16),
              _sectionHeader('Timestamps'),
              if (client.createdAt != null)
                _detailRow(
                  Icons.calendar_today_rounded,
                  'Registered',
                  dateFmt.format(client.createdAt!),
                ),
              if (client.lastTripAt != null)
                _detailRow(
                  Icons.schedule_rounded,
                  'Last Trip',
                  dateFmt.format(client.lastTripAt!),
                ),
              if (client.lastUpdated != null)
                _detailRow(
                  Icons.update_rounded,
                  'Last Updated',
                  dateFmt.format(client.lastUpdated!),
                ),

              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    _showActions(context, client);
                  },
                  icon: const Icon(Icons.settings_rounded, size: 18),
                  label: const Text('Manage Client'),
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

  Widget _sectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Container(
            width: 3,
            height: 16,
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            title,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _detailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: AppColors.textSecondary),
          const SizedBox(width: 12),
          Text(
            label,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 14,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.end,
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
            24, 16, 24, MediaQuery.of(ctx).viewInsets.bottom + 24),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Container(
                  width: 40, height: 4,
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
                  Text('Edit Client',
                      style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 18,
                          fontWeight: FontWeight.w700)),
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
                        client.clientId, data,
                        clientName: client.fullName);
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      backgroundColor: AppColors.surfaceHigh,
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      content: Row(children: [
                        const Icon(Icons.check_circle_rounded,
                            color: AppColors.success, size: 18),
                        const SizedBox(width: 8),
                        Text('${client.fullName} updated',
                            style: const TextStyle(
                                color: AppColors.textPrimary)),
                      ]),
                    ));
                  },
                  icon: const Icon(Icons.save_rounded, size: 18),
                  label: const Text('Save Changes'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: const Color(0xFF1A1400),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
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
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
                context.read<ClientProvider>().deleteClient(
                  client.clientId,
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
