import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../config/app_theme.dart';
import '../services/dispatch_api_service.dart';
import 'support_chat_detail_screen.dart';

class RiderDetailScreen extends StatefulWidget {
  final int sqliteId;
  const RiderDetailScreen({super.key, required this.sqliteId});

  @override
  State<RiderDetailScreen> createState() => _RiderDetailScreenState();
}

class _RiderDetailScreenState extends State<RiderDetailScreen> {
  Map<String, dynamic>? _userData;
  List<Map<String, dynamic>> _chats = [];
  bool _loading = true;
  bool _ssnRevealed = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      // Load user details from backend
      final userDetail = await DispatchApiService.getUserDetail(widget.sqliteId);
      
      // Load support chats from Firestore - removed orderBy to avoid index requirement
      final chatsSnap = await FirebaseFirestore.instance
          .collection('support_chats')
          .where('userId', isEqualTo: widget.sqliteId)
          .get();
      final chats = chatsSnap.docs.map((d) {
        final data = d.data();
        data['id'] = int.tryParse(d.id) ?? 0;
        return data;
      }).toList();
      // Sort locally by createdAt
      chats.sort((a, b) {
        final aTime = a['createdAt'] as Timestamp?;
        final bTime = b['createdAt'] as Timestamp?;
        if (aTime == null || bTime == null) return 0;
        return bTime.compareTo(aTime); // descending
      });
      
      if (mounted) {
        setState(() {
          _userData = userDetail;
          _chats = chats;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error cargando datos: $e')),
        );
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
          _userData?['first_name'] ?? 'Rider Detail',
          style: const TextStyle(color: AppColors.textPrimary),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.primary),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          if (!_loading)
            IconButton(
              icon: const Icon(Icons.refresh, color: AppColors.primary),
              onPressed: _loadData,
            ),
        ],
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
    final ssnLast4 = u['ssn_last4'] as String?;
    final createdAt = u['created_at'] as String?;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with photo
          _buildHeader(photoUrl, u['first_name'], u['last_name'], isVerified),
          
          const SizedBox(height: 20),
          
          // Account Info Section
          _buildSectionTitle('Información de Cuenta'),
          _buildInfoCard([
            _buildInfoRow(Icons.email_outlined, 'Email', email ?? 'No proporcionado'),
            _buildInfoRow(Icons.phone_outlined, 'Teléfono', phone ?? 'No proporcionado'),
            _buildInfoRow(Icons.lock_open, 'Contraseña', 
              password != null && password.isNotEmpty 
                ? password 
                : hasPassword 
                  ? '(Configurada - no visible)'
                  : 'No configurada'
            ),
            if (createdAt != null)
              _buildInfoRow(Icons.calendar_today, 'Registrado', _formatDate(createdAt)),
          ]),
          
          const SizedBox(height: 16),
          
          // SSN Section
          _buildSectionTitle('Social Security Number'),
          _buildSSNCard(ssnProvided, ssnFull, ssnMasked, ssnLast4),
          
          const SizedBox(height: 16),
          
          // Verification Photos
          _buildSectionTitle('Fotos de Verificación'),
          _buildVerificationPhotos(u),
          
          const SizedBox(height: 16),
          
          // Payment Methods
          _buildSectionTitle('Métodos de Pago'),
          _buildPaymentMethods(u),
          
          const SizedBox(height: 16),
          
          // Support Chats
          _buildSectionTitle('Chats con Soporte'),
          _buildSupportChats(),
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
                    ? const Icon(Icons.person, size: 50, color: AppColors.textHint)
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
            name.isNotEmpty ? name : 'Rider',
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
              color: isVerified ? AppColors.success.withOpacity(0.1) : AppColors.warning.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              isVerified ? '✓ Cuenta Verificada' : '⏳ Verificación Pendiente',
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

  Widget _buildSSNCard(bool ssnProvided, String? ssnFull, String? ssnMasked, String? ssnLast4) {
    return GestureDetector(
      onTap: ssnProvided && ssnFull != null
          ? () => setState(() => _ssnRevealed = !_ssnRevealed)
          : null,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: ssnProvided ? AppColors.success.withOpacity(0.05) : AppColors.warning.withOpacity(0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: ssnProvided ? AppColors.success.withOpacity(0.3) : AppColors.warning.withOpacity(0.3),
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
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                      if (ssnProvided && ssnFull != null) ...[
                        const SizedBox(width: 8),
                        Text(
                          _ssnRevealed ? '(Toca para ocultar)' : '(Toca para revelar)',
                          style: TextStyle(
                            color: AppColors.primary,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    ssnProvided
                        ? (_ssnRevealed && ssnFull != null
                            ? ssnFull
                            : (ssnMasked ?? '***-**-${ssnLast4 ?? "????"}'))
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
    );
  }

  Widget _buildVerificationPhotos(Map<String, dynamic> u) {
    final idPhoto = u['id_photo_url'] as String?;
    final selfie = u['selfie_url'] as String?;
    
    if (idPhoto == null && selfie == null) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Text(
          'No hay fotos de verificación',
          style: TextStyle(color: AppColors.textHint),
        ),
      );
    }

    return Column(
      children: [
        if (idPhoto != null) _buildPhotoCard('ID Documento', idPhoto),
        if (selfie != null) _buildPhotoCard('Selfie', selfie),
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
          Text(
            label,
            style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.network(
              fullUrl,
              height: 180,
              width: double.infinity,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
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

  Widget _buildPaymentMethods(Map<String, dynamic> u) {
    // TODO: Add payment methods from backend when available
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          _buildPaymentRow(Icons.credit_card, 'Tarjetas', '0 agregadas'),
          const Divider(color: AppColors.cardBorder),
          _buildPaymentRow(Icons.account_balance, 'Cuentas Bancarias', '0 agregadas'),
        ],
      ),
    );
  }

  Widget _buildPaymentRow(IconData icon, String label, String status) {
    return Row(
      children: [
        Icon(icon, color: AppColors.textSecondary),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600)),
              Text(status, style: const TextStyle(color: AppColors.textHint, fontSize: 12)),
            ],
          ),
        ),
      ],
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
              MaterialPageRoute(
                builder: (_) => SupportChatDetailScreen(
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

  String _formatDate(String isoDate) {
    try {
      final dt = DateTime.parse(isoDate);
      return '${dt.day}/${dt.month}/${dt.year}';
    } catch (_) {
      return isoDate;
    }
  }
}
