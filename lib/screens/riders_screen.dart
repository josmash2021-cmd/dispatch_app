import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../config/app_theme.dart';
import '../providers/client_provider.dart';
import '../services/dispatch_api_service.dart';
import '../widgets/shimmer_loading.dart';
import 'rider_detail_screen.dart';

class RidersScreen extends StatefulWidget {
  const RidersScreen({super.key});

  @override
  State<RidersScreen> createState() => _RidersScreenState();
}

class _RidersScreenState extends State<RidersScreen> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ClientProvider>();

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              controller: _searchController,
              onChanged: provider.setSearchQuery,
              style: const TextStyle(color: AppColors.textPrimary),
              decoration: InputDecoration(
                hintText: 'Buscar riders por nombre, teléfono...',
                hintStyle: const TextStyle(color: AppColors.textHint),
                prefixIcon: const Icon(Icons.search_rounded, color: AppColors.textHint),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded, color: AppColors.textHint),
                        onPressed: () {
                          _searchController.clear();
                          provider.setSearchQuery('');
                        },
                      )
                    : null,
                filled: true,
                fillColor: AppColors.surfaceHigh,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
            ),
          ),
          // Stats chips
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              children: [
                _countChip('Total', provider.totalClients, AppColors.primary),
                const SizedBox(width: 8),
                _countChip('Verificados', provider.verifiedClients, AppColors.success),
              ],
            ),
          ),
          // Riders list
          Expanded(
            child: provider.isLoading
                ? const _ShimmerList()
                : provider.filteredClients.isEmpty
                    ? _emptyState()
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        itemCount: provider.filteredClients.length,
                        itemBuilder: (context, index) {
                          final client = provider.filteredClients[index];
                          return _RiderCard(
                            client: client,
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => RiderDetailScreen(sqliteId: client.sqliteId),
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _countChip(String label, int count, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        '$label: $count',
        style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600),
      ),
    );
  }

  Widget _emptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.people_outline, size: 64, color: AppColors.textHint.withOpacity(0.5)),
          const SizedBox(height: 16),
          const Text(
            'No hay riders',
            style: TextStyle(color: AppColors.textHint, fontSize: 16),
          ),
        ],
      ),
    );
  }
}

class _RiderCard extends StatelessWidget {
  final dynamic client;
  final VoidCallback onTap;

  const _RiderCard({required this.client, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isVerified = client.isVerified;
    
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: isVerified ? AppColors.success : AppColors.warning,
          child: Icon(
            isVerified ? Icons.verified_user : Icons.person_outline,
            color: Colors.white,
            size: 20,
          ),
        ),
        title: Text(
          client.fullName,
          style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(client.phone, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
            if (client.email != null && client.email!.isNotEmpty)
              Text(client.email!, style: const TextStyle(color: AppColors.textHint, fontSize: 12)),
          ],
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: isVerified ? AppColors.success.withOpacity(0.1) : AppColors.warning.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            isVerified ? 'Verificado' : 'Pendiente',
            style: TextStyle(
              color: isVerified ? AppColors.success : AppColors.warning,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

class _ShimmerList extends StatelessWidget {
  const _ShimmerList();

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: 6,
      itemBuilder: (_, __) => const ShimmerCard(height: 80, margin: EdgeInsets.only(bottom: 8)),
    );
  }
}
