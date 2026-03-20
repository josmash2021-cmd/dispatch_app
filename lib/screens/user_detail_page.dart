import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:video_player/video_player.dart';

import '../config/app_theme.dart';
import '../models/client_model.dart';
import '../models/driver_model.dart';
import '../providers/client_provider.dart';
import '../providers/driver_provider.dart';
import '../services/dispatch_api_service.dart';
import '../widgets/re_auth_dialog.dart';

// ─── Main Page ────────────────────────────────────────────────────────────────

class UserDetailPage extends StatefulWidget {
  final DriverModel? driver;
  final ClientModel? client;
  /// 0=Info, 1=Fotos&Docs, 2=Pagos, 3=Detalles, 4=Cambios
  final int initialTab;
  /// Fields to highlight in the Cambios tab (e.g. from a notification)
  final List<String>? highlightedChanges;

  const UserDetailPage({
    this.driver,
    this.client,
    this.initialTab = 0,
    this.highlightedChanges,
    super.key,
  }) : assert(
        driver != null || client != null,
        'Provide either driver or client',
      );

  @override
  State<UserDetailPage> createState() => _UserDetailPageState();
}

class _UserDetailPageState extends State<UserDetailPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // ── Common getters ────────────────────────────────────────────────────────

  bool get _isDriver => widget.driver != null;
  String get _fullName =>
      _isDriver ? widget.driver!.fullName : widget.client!.fullName;
  String get _userId =>
      _isDriver ? widget.driver!.driverId : widget.client!.clientId;
  int? get _sqliteId =>
      _isDriver ? widget.driver!.sqliteId : widget.client!.sqliteId;
  String? get _photoUrl =>
      _isDriver ? widget.driver!.photoUrl : widget.client!.photoUrl;
  String get _phone => _isDriver ? widget.driver!.phone : widget.client!.phone;
  String? get _email => _isDriver ? widget.driver!.email : widget.client!.email;
  String get _role => _isDriver ? widget.driver!.role : widget.client!.role;
  String get _status =>
      _isDriver ? widget.driver!.status : widget.client!.status;
  String? get _source =>
      _isDriver ? widget.driver!.source : widget.client!.source;
  String? get _username =>
      _isDriver ? widget.driver!.username : widget.client!.username;
  String? get _licenseUrl =>
      _isDriver ? widget.driver!.licenseUrl : widget.client!.licenseUrl;
  String? get _documentUrl =>
      _isDriver ? widget.driver!.documentUrl : widget.client!.documentUrl;
  DateTime? get _createdAt =>
      _isDriver ? widget.driver!.createdAt : widget.client!.createdAt;
  DateTime? get _lastUpdated =>
      _isDriver ? widget.driver!.lastUpdated : widget.client!.lastUpdated;
  String? get _paymentMethod =>
      _isDriver ? widget.driver!.paymentMethod : widget.client!.paymentMethod;
  String? get _cardBrand =>
      _isDriver ? widget.driver!.cardBrand : widget.client!.cardBrand;
  String? get _cardLast4 =>
      _isDriver ? widget.driver!.cardLast4 : widget.client!.cardLast4;
  String? get _bankName =>
      _isDriver ? widget.driver!.bankName : widget.client!.bankName;
  String? get _bankRouting => _isDriver
      ? widget.driver!.bankRoutingNumber
      : widget.client!.bankRoutingNumber;
  String? get _bankAccount => _isDriver
      ? widget.driver!.bankAccountNumber
      : widget.client!.bankAccountNumber;
  double? get _rating =>
      _isDriver ? widget.driver!.rating : widget.client!.rating;

  Color get _statusColor {
    switch (_status) {
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

  IconData get _statusIcon {
    switch (_status) {
      case 'active':
        return Icons.check_circle_outline_rounded;
      case 'deactivated':
        return Icons.pause_circle_outline_rounded;
      case 'blocked':
        return Icons.block_rounded;
      default:
        return Icons.help_outline_rounded;
    }
  }

  String get _statusLabel {
    switch (_status) {
      case 'active':
        return 'Active';
      case 'deactivated':
        return 'Deactivated';
      case 'blocked':
        return 'Blocked';
      default:
        return _status;
    }
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 5,
      vsync: this,
      initialIndex: widget.initialTab.clamp(0, 4),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // ── Download helper ───────────────────────────────────────────────────────

  Future<void> _downloadImage(String url, String label) async {
    try {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Descargando...'),
          duration: Duration(seconds: 1),
        ),
      );
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        Directory dir;
        try {
          dir =
              (await getExternalStorageDirectory()) ??
              await getApplicationDocumentsDirectory();
        } catch (_) {
          dir = await getApplicationDocumentsDirectory();
        }
        final fileName =
            '${label.replaceAll(' ', '_')}_${DateTime.now().millisecondsSinceEpoch}.jpg';
        final file = File('${dir.path}/$fileName');
        await file.writeAsBytes(response.bodyBytes);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: AppColors.success,
              behavior: SnackBarBehavior.floating,
              content: Text('Guardado: $fileName'),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.error,
            content: Text('Error al guardar: $e'),
          ),
        );
      }
    }
  }

  // ── Manage sheet ──────────────────────────────────────────────────────────

  void _showManageSheet() {
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
                  Icon(_statusIcon, color: _statusColor, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _fullName,
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
                      color: _statusColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      _statusLabel,
                      style: TextStyle(
                        fontSize: 12,
                        color: _statusColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              _actionTile(
                icon: Icons.edit_rounded,
                label: 'Editar',
                subtitle: 'Actualizar información del perfil',
                color: AppColors.primary,
                onTap: () {
                  Navigator.pop(ctx);
                  _showEditSheet();
                },
              ),
              const Divider(color: AppColors.cardBorder, height: 16),
              if (_status != 'active')
                _actionTile(
                  icon: Icons.check_circle_outline_rounded,
                  label: 'Activar',
                  subtitle: 'Restaurar acceso completo',
                  color: AppColors.success,
                  onTap: () {
                    Navigator.pop(ctx);
                    _changeStatus('active');
                  },
                ),
              if (_status != 'deactivated')
                _actionTile(
                  icon: Icons.pause_circle_outline_rounded,
                  label: 'Desactivar',
                  subtitle: 'Suspender temporalmente',
                  color: AppColors.warning,
                  onTap: () {
                    Navigator.pop(ctx);
                    _changeStatus('deactivated');
                  },
                ),
              if (_status != 'blocked')
                _actionTile(
                  icon: Icons.block_rounded,
                  label: 'Bloquear',
                  subtitle: 'Denegar acceso permanentemente',
                  color: AppColors.error,
                  onTap: () {
                    Navigator.pop(ctx);
                    _changeStatus('blocked');
                  },
                ),
              const Divider(color: AppColors.cardBorder, height: 24),
              _actionTile(
                icon: Icons.lock_reset_rounded,
                label: 'Resetear Contraseña',
                subtitle: 'Cambiar contraseña de acceso',
                color: AppColors.warning,
                onTap: () {
                  Navigator.pop(ctx);
                  _resetPasswordDialog();
                },
              ),
              const Divider(color: AppColors.cardBorder, height: 16),
              _actionTile(
                icon: Icons.delete_forever_rounded,
                label: 'Eliminar permanentemente',
                subtitle: 'Remover de la base de datos',
                color: AppColors.error,
                onTap: () {
                  Navigator.pop(ctx);
                  _confirmDelete();
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

  void _changeStatus(String newStatus) {
    final color = newStatus == 'active'
        ? AppColors.success
        : newStatus == 'deactivated'
        ? AppColors.warning
        : AppColors.error;
    final label = newStatus == 'active'
        ? 'Activar'
        : newStatus == 'deactivated'
        ? 'Desactivar'
        : 'Bloquear';
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          '$label usuario',
          style: const TextStyle(color: AppColors.textPrimary, fontSize: 18),
        ),
        content: Text(
          '¿Cambiar estado de $_fullName a "$label"?',
          style: const TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(dialogCtx);
              if (_isDriver) {
                context.read<DriverProvider>().updateDriverStatus(
                  _userId,
                  newStatus,
                  driverName: _fullName,
                );
              } else {
                context.read<ClientProvider>().updateClientStatus(
                  _userId,
                  newStatus,
                  clientName: _fullName,
                );
              }
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    backgroundColor: AppColors.surfaceHigh,
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    content: Text('$_fullName → $label'),
                  ),
                );
                Navigator.pop(context);
              }
            },
            child: Text(
              label,
              style: TextStyle(color: color, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  void _confirmDelete() {
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
              'Eliminar',
              style: TextStyle(color: AppColors.textPrimary, fontSize: 18),
            ),
          ],
        ),
        content: Text(
          '¿Eliminar permanentemente a $_fullName? Esta acción no se puede deshacer.',
          style: const TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(dialogCtx);
              final confirmed = await showReAuthDialog(
                context,
                actionDescription: 'Eliminar "$_fullName" es permanente.',
              );
              if (confirmed && mounted) {
                if (_isDriver) {
                  context.read<DriverProvider>().updateDriverStatus(
                    _userId,
                    'deleted',
                    driverName: _fullName,
                  );
                } else {
                  context.read<ClientProvider>().deleteClient(
                    _userId,
                    clientName: _fullName,
                  );
                }
                Navigator.pop(context);
              }
            },
            child: const Text(
              'Eliminar',
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

  // ── Edit sheet ────────────────────────────────────────────────────────────

  void _showEditSheet() {
    final firstCtrl = TextEditingController(
      text: _isDriver ? widget.driver!.firstName : widget.client!.firstName,
    );
    final lastCtrl = TextEditingController(
      text: _isDriver ? widget.driver!.lastName : widget.client!.lastName,
    );
    final phoneCtrl = TextEditingController(text: _phone);
    final emailCtrl = TextEditingController(text: _email ?? '');
    final vehicleTypeCtrl = _isDriver
        ? TextEditingController(text: widget.driver!.vehicleType ?? '')
        : null;
    final vehiclePlateCtrl = _isDriver
        ? TextEditingController(text: widget.driver!.vehiclePlate ?? '')
        : null;

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
            crossAxisAlignment: CrossAxisAlignment.start,
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
              Text(
                'Editar ${_isDriver ? 'Driver' : 'Rider'}',
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 20),
              _editField(firstCtrl, 'Nombre', Icons.person_outline),
              const SizedBox(height: 12),
              _editField(lastCtrl, 'Apellido', Icons.person_outline),
              const SizedBox(height: 12),
              _editField(
                phoneCtrl,
                'Teléfono',
                Icons.phone_outlined,
                type: TextInputType.phone,
              ),
              const SizedBox(height: 12),
              _editField(
                emailCtrl,
                'Email',
                Icons.email_outlined,
                type: TextInputType.emailAddress,
              ),
              if (vehicleTypeCtrl != null) ...[
                const SizedBox(height: 12),
                _editField(
                  vehicleTypeCtrl,
                  'Tipo de Vehículo',
                  Icons.directions_car_outlined,
                ),
              ],
              if (vehiclePlateCtrl != null) ...[
                const SizedBox(height: 12),
                _editField(
                  vehiclePlateCtrl,
                  'Placa',
                  Icons.confirmation_number_outlined,
                ),
              ],
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: const Color(0xFF1A1400),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  onPressed: () {
                    final data = <String, dynamic>{
                      'firstName': firstCtrl.text.trim(),
                      'lastName': lastCtrl.text.trim(),
                      'phone': phoneCtrl.text.trim(),
                      if (emailCtrl.text.trim().isNotEmpty)
                        'email': emailCtrl.text.trim(),
                      if (vehicleTypeCtrl != null &&
                          vehicleTypeCtrl.text.trim().isNotEmpty)
                        'vehicleType': vehicleTypeCtrl.text.trim(),
                      if (vehiclePlateCtrl != null &&
                          vehiclePlateCtrl.text.trim().isNotEmpty)
                        'vehiclePlate': vehiclePlateCtrl.text.trim(),
                    };
                    Navigator.pop(ctx);
                    if (_isDriver) {
                      context.read<DriverProvider>().updateDriver(
                        _userId,
                        data,
                        driverName: _fullName,
                      );
                    } else {
                      context.read<ClientProvider>().updateClient(
                        _userId,
                        data,
                        clientName: _fullName,
                      );
                    }
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        backgroundColor: AppColors.success,
                        behavior: SnackBarBehavior.floating,
                        content: Text('$_fullName actualizado'),
                      ),
                    );
                  },
                  child: const Text(
                    'Guardar Cambios',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _editField(
    TextEditingController ctrl,
    String label,
    IconData icon, {
    TextInputType type = TextInputType.text,
  }) {
    return TextField(
      controller: ctrl,
      keyboardType: type,
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
      ),
    );
  }

  void _resetPasswordDialog() {
    if (_sqliteId == null) return;
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.lock_reset_rounded, color: AppColors.warning, size: 22),
            SizedBox(width: 8),
            Text(
              'Resetear Contraseña',
              style: TextStyle(color: AppColors.textPrimary, fontSize: 18),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Nueva contraseña para $_fullName:',
              style: const TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: ctrl,
              style: const TextStyle(color: AppColors.textPrimary),
              decoration: InputDecoration(
                labelText: 'Nueva Contraseña',
                labelStyle: const TextStyle(color: AppColors.textSecondary),
                prefixIcon: const Icon(
                  Icons.lock_outline,
                  color: AppColors.textHint,
                  size: 20,
                ),
                filled: true,
                fillColor: AppColors.surfaceHigh,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () async {
              final newPwd = ctrl.text.trim();
              if (newPwd.length < 4) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    backgroundColor: AppColors.error,
                    content: Text(
                      'La contraseña debe tener al menos 4 caracteres',
                    ),
                  ),
                );
                return;
              }
              Navigator.pop(dialogCtx);
              try {
                await DispatchApiService.updateUser(_sqliteId!, {
                  'password': newPwd,
                });
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      backgroundColor: AppColors.success,
                      behavior: SnackBarBehavior.floating,
                      content: Text('Contraseña reseteada para $_fullName'),
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      backgroundColor: AppColors.error,
                      content: Text('Error: $e'),
                    ),
                  );
                }
              }
            },
            child: const Text(
              'Resetear',
              style: TextStyle(
                color: AppColors.warning,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) => [
          _buildSliverHeader(),
          SliverPersistentHeader(
            delegate: _StickyTabBar(
              TabBar(
                controller: _tabController,
                labelColor: AppColors.primary,
                unselectedLabelColor: AppColors.textSecondary,
                indicatorColor: AppColors.primary,
                indicatorSize: TabBarIndicatorSize.tab,
                labelStyle: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
                unselectedLabelStyle: const TextStyle(fontSize: 13),
                tabs: const [
                  Tab(text: 'Info'),
                  Tab(text: 'Fotos & Docs'),
                  Tab(text: 'Pagos'),
                  Tab(text: 'Detalles'),
                  Tab(text: 'Cambios'),
                ],
                isScrollable: true,
              ),
            ),
            pinned: true,
          ),
        ],
        body: TabBarView(
          controller: _tabController,
          children: [
            _buildInfoTab(),
            _buildPhotosTab(),
            _buildPaymentsTab(),
            _buildDetailsTab(),
            _buildCambiosTab(),
          ],
        ),
      ),
    );
  }

  SliverAppBar _buildSliverHeader() {
    final rawPhoto = _photoUrl;
    final effectivePhotoUrl = rawPhoto != null && rawPhoto.isNotEmpty
        ? DispatchApiService.fullUrl(rawPhoto)
        : null;
    final isOnline = _isDriver
        ? (widget.driver?.isOnline ?? false)
        : (widget.client?.isOnline ?? false);

    return SliverAppBar(
      expandedHeight: 230,
      pinned: true,
      backgroundColor: AppColors.background,
      foregroundColor: AppColors.textPrimary,
      elevation: 0,
      actions: [
        IconButton(
          icon: const Icon(Icons.edit_rounded, size: 20),
          onPressed: _showEditSheet,
          tooltip: 'Editar',
        ),
        IconButton(
          icon: const Icon(Icons.more_vert_rounded),
          onPressed: _showManageSheet,
          tooltip: 'Gestionar',
        ),
      ],
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF221C00), AppColors.background],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.only(top: 48),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Avatar
                  Stack(
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: _statusColor.withValues(alpha: 0.6),
                            width: 3,
                          ),
                        ),
                        child: CircleAvatar(
                          radius: 44,
                          backgroundColor: AppColors.primary.withValues(
                            alpha: 0.15,
                          ),
                          child: effectivePhotoUrl != null
                              ? ClipOval(
                                  child: Image.network(
                                    DispatchApiService.normalizeUrl(effectivePhotoUrl),
                                    width: 88,
                                    height: 88,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, _, _) => Text(
                                      _fullName.isNotEmpty
                                          ? _fullName[0].toUpperCase()
                                          : '?',
                                      style: const TextStyle(
                                        color: AppColors.primary,
                                        fontSize: 32,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                )
                              : Text(
                                  _fullName.isNotEmpty
                                      ? _fullName[0].toUpperCase()
                                      : '?',
                                  style: const TextStyle(
                                    color: AppColors.primary,
                                    fontSize: 32,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                        ),
                      ),
                      // Account status dot (bottom-right)
                      Positioned(
                        right: 2,
                        bottom: 2,
                        child: Container(
                          width: 18,
                          height: 18,
                          decoration: BoxDecoration(
                            color: _statusColor,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: AppColors.background,
                              width: 2.5,
                            ),
                          ),
                        ),
                      ),
                      // Online indicator (top-right)
                      Positioned(
                        right: 2,
                        top: 2,
                        child: Container(
                          width: 14,
                          height: 14,
                          decoration: BoxDecoration(
                            color: isOnline
                                ? AppColors.success
                                : AppColors.textHint,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: AppColors.background,
                              width: 2,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  // Name
                  Text(
                    _fullName,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  // Status chips
                  Wrap(
                    spacing: 6,
                    children: [
                      _chip(_role.toUpperCase(), AppColors.primary),
                      _chip(_statusLabel, _statusColor),
                      _chip(
                        isOnline ? 'Online' : 'Offline',
                        isOnline ? AppColors.success : AppColors.textHint,
                      ),
                      if (_source != null) _chip(_source!, AppColors.textHint),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _chip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  // ── Tab 1: Info ───────────────────────────────────────────────────────────

  Widget _buildInfoTab() {
    final dateFmt = DateFormat('MMM d, yyyy · h:mm a');
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Contact
        _sectionCard('Contacto', Icons.contact_phone_rounded, [
          _infoRow(
            Icons.phone_outlined,
            'Teléfono',
            _phone.isNotEmpty ? _phone : 'No registrado',
            copyable: _phone.isNotEmpty,
          ),
          _infoRow(
            Icons.email_outlined,
            'Email',
            _email ?? 'No registrado',
            copyable: _email != null,
          ),
        ]),
        const SizedBox(height: 12),

        // Account
        _sectionCard('Cuenta', Icons.manage_accounts_rounded, [
          _infoRow(
            Icons.badge_outlined,
            _isDriver ? 'Driver ID' : 'Client ID',
            _userId,
            copyable: true,
          ),
          if (_sqliteId != null)
            _infoRow(
              Icons.storage_outlined,
              'Server ID',
              '$_sqliteId',
              copyable: true,
            ),
          _infoRow(Icons.person_outline, 'Rol', _role),
          if (_username != null)
            _infoRow(
              Icons.account_circle_outlined,
              'Usuario',
              _username!,
              copyable: true,
            ),
          // Password widget
          if (_sqliteId != null) ...[
            _UDPasswordWidget(sqliteId: _sqliteId!),
          ] else
            _infoRow(
              Icons.lock_outlined,
              'Contraseña',
              'No disponible (sin server ID)',
            ),
        ]),
        const SizedBox(height: 12),

        // Timestamps
        _sectionCard('Registro', Icons.schedule_rounded, [
          if (_createdAt != null)
            _infoRow(
              Icons.calendar_today_rounded,
              'Registrado',
              dateFmt.format(_createdAt!),
            ),
          if (_isDriver && widget.driver!.lastSeen != null)
            _infoRow(
              Icons.access_time_rounded,
              'Última conexión',
              timeago.format(widget.driver!.lastSeen!, locale: 'en'),
            ),
          if (!_isDriver && widget.client!.lastTripAt != null)
            _infoRow(
              Icons.directions_car_outlined,
              'Último viaje',
              dateFmt.format(widget.client!.lastTripAt!),
            ),
          if (_lastUpdated != null)
            _infoRow(
              Icons.update_rounded,
              'Actualizado',
              dateFmt.format(_lastUpdated!),
            ),
        ]),
        const SizedBox(height: 80),
      ],
    );
  }

  // ── Tab 2: Fotos & Docs ───────────────────────────────────────────────────

  Widget _buildPhotosTab() {
    final rawPhoto2 = _photoUrl;
    final effectivePhotoUrl = rawPhoto2 != null && rawPhoto2.isNotEmpty
        ? DispatchApiService.fullUrl(rawPhoto2)
        : null;

    final hasContent =
        effectivePhotoUrl != null ||
        _licenseUrl != null ||
        _documentUrl != null ||
        _sqliteId != null;

    if (!hasContent) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.photo_library_outlined,
                size: 56,
                color: AppColors.textHint,
              ),
              const SizedBox(height: 16),
              const Text(
                'No hay fotos o documentos',
                style: TextStyle(color: AppColors.textHint, fontSize: 15),
              ),
            ],
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Profile photo
        if (effectivePhotoUrl != null) ...[
          _sectionCard('Foto de Perfil', Icons.face_rounded, [
            _photoTileWithDownload('Perfil', effectivePhotoUrl),
          ]),
          const SizedBox(height: 12),
        ],

        // License / Document from Firestore
        if (_licenseUrl != null || _documentUrl != null) ...[
          _sectionCard('Documentos (Firestore)', Icons.folder_rounded, [
            if (_licenseUrl != null)
              _photoTileWithDownload('Licencia', DispatchApiService.fullUrl(_licenseUrl!)),
            if (_documentUrl != null)
              _photoTileWithDownload('Documento', DispatchApiService.fullUrl(_documentUrl!)),
          ]),
          const SizedBox(height: 12),
        ],

        // Verification photos from Firestore
        if (_sqliteId != null) ...[
          _sectionCard('Fotos de Verificación', Icons.verified_user_rounded, [
            _UDVerifPhotosWidget(
              sqliteId: _sqliteId!,
              onDownload: _downloadImage,
            ),
          ]),
          const SizedBox(height: 12),

          // Server documents from backend
          _sectionCard(
            'Documentos del Servidor',
            Icons.cloud_download_rounded,
            [
              _UDServerDocsWidget(
                sqliteId: _sqliteId!,
                onDownload: _downloadImage,
              ),
            ],
          ),
          const SizedBox(height: 12),
        ],

        const SizedBox(height: 80),
      ],
    );
  }

  Widget _photoTileWithDownload(String label, String rawUrl) {
    final url = DispatchApiService.normalizeUrl(rawUrl);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              label,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            const Spacer(),
            TextButton.icon(
              onPressed: () => _downloadImage(url, label),
              icon: const Icon(Icons.download_rounded, size: 16),
              label: const Text('Guardar'),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.network(
            url,
            width: double.infinity,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => Container(
              height: 100,
              decoration: BoxDecoration(
                color: AppColors.surfaceHigh,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Center(
                child: Icon(
                  Icons.broken_image_outlined,
                  color: AppColors.textHint,
                  size: 36,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
      ],
    );
  }

  // ── Tab 3: Pagos ──────────────────────────────────────────────────────────

  Widget _buildPaymentsTab() {
    final hasPayment =
        _paymentMethod != null ||
        _cardBrand != null ||
        _cardLast4 != null ||
        _bankName != null;

    if (!hasPayment) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.payment_outlined,
                size: 56,
                color: AppColors.textHint,
              ),
              const SizedBox(height: 16),
              const Text(
                'No hay información de pago',
                style: TextStyle(color: AppColors.textHint, fontSize: 15),
              ),
            ],
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _sectionCard('Método de Pago', Icons.payment_rounded, [
          _infoRow(
            Icons.payment_rounded,
            'Método',
            _paymentMethod?.toUpperCase() ?? 'No registrado',
          ),
        ]),

        if (_cardBrand != null || _cardLast4 != null) ...[
          const SizedBox(height: 12),
          _sectionCard('Tarjeta', Icons.credit_card_rounded, [
            _infoRow(
              Icons.credit_card_rounded,
              'Tipo',
              _cardBrand?.toUpperCase() ?? 'Card',
            ),
            _infoRow(
              Icons.numbers_rounded,
              'Últimos 4',
              _cardLast4 != null ? '•••• ${_cardLast4!}' : 'N/A',
            ),
            if (!_isDriver && widget.client?.cardNumber != null)
              _infoRow(
                Icons.credit_card_rounded,
                'Número',
                widget.client!.cardNumber!,
                copyable: true,
              ),
            if (!_isDriver && widget.client?.cardExpiry != null)
              _infoRow(
                Icons.date_range_rounded,
                'Vence',
                widget.client!.cardExpiry!,
              ),
          ]),
        ],

        if (_bankName != null ||
            _bankRouting != null ||
            _bankAccount != null) ...[
          const SizedBox(height: 12),
          _sectionCard('Banco', Icons.account_balance_rounded, [
            if (_bankName != null)
              _infoRow(Icons.account_balance_rounded, 'Banco', _bankName!),
            if (_bankRouting != null)
              _infoRow(
                Icons.route_rounded,
                'Routing',
                _bankRouting!,
                copyable: true,
              ),
            if (_bankAccount != null)
              _infoRow(
                Icons.account_balance_wallet_rounded,
                'Cuenta',
                _bankAccount!,
                copyable: true,
              ),
          ]),
        ],

        const SizedBox(height: 80),
      ],
    );
  }

  // ── Tab 4: Detalles ───────────────────────────────────────────────────────

  Widget _buildDetailsTab() {
    final currFmt = NumberFormat.currency(symbol: '\$', decimalDigits: 2);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (_isDriver) ...[
          _sectionCard('Vehículo', Icons.directions_car_rounded, [
            _infoRow(
              Icons.directions_car_outlined,
              'Tipo',
              widget.driver!.vehicleType ?? 'No registrado',
            ),
            _infoRow(
              Icons.confirmation_number_outlined,
              'Placa',
              widget.driver!.vehiclePlate ?? 'No registrado',
            ),
          ]),
          const SizedBox(height: 12),
          _sectionCard('Ubicación GPS', Icons.location_on_rounded, [
            _infoRow(
              Icons.gps_fixed_rounded,
              'GPS',
              widget.driver!.isOnline ? 'Activo' : 'Inactivo',
            ),
            if (widget.driver!.lat != null && widget.driver!.lng != null)
              _infoRow(
                Icons.location_on_outlined,
                'Coordenadas',
                '${widget.driver!.lat!.toStringAsFixed(6)}, ${widget.driver!.lng!.toStringAsFixed(6)}',
                copyable: true,
              ),
          ]),
        ] else ...[
          _sectionCard('Estadísticas de Viajes', Icons.bar_chart_rounded, [
            _statTile(
              'Total Viajes',
              '${widget.client!.totalTrips}',
              Icons.directions_car_outlined,
            ),
            const Divider(color: AppColors.cardBorder, height: 20),
            _statTile(
              'Total Gastado',
              currFmt.format(widget.client!.totalSpent),
              Icons.attach_money_rounded,
            ),
          ]),
        ],

        if (_rating != null) ...[
          const SizedBox(height: 12),
          _sectionCard('Calificación', Icons.star_rounded, [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  const Icon(Icons.star_rounded, color: Colors.amber, size: 28),
                  const SizedBox(width: 10),
                  Text(
                    _rating!.toStringAsFixed(1),
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 26,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(width: 6),
                  const Text(
                    '/ 5.0',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
          ]),
        ],

        const SizedBox(height: 80),
      ],
    );
  }

  // ── Common widgets ────────────────────────────────────────────────────────

  Widget _sectionCard(String title, IconData icon, List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
            child: Row(
              children: [
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, size: 16, color: AppColors.primary),
                ),
                const SizedBox(width: 10),
                Text(
                  title,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const Divider(
            color: AppColors.cardBorder,
            height: 16,
            indent: 16,
            endIndent: 16,
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
            child: Column(children: children),
          ),
        ],
      ),
    );
  }

  Widget _infoRow(
    IconData icon,
    String label,
    String value, {
    bool copyable = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 17, color: AppColors.textSecondary),
          const SizedBox(width: 10),
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          if (copyable)
            GestureDetector(
              onTap: () {
                Clipboard.setData(ClipboardData(text: value));
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('$label copiado'),
                    duration: const Duration(seconds: 1),
                  ),
                );
              },
              child: const Padding(
                padding: EdgeInsets.only(left: 6),
                child: Icon(
                  Icons.copy_rounded,
                  size: 15,
                  color: AppColors.textHint,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _statTile(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 20, color: AppColors.primary),
          ),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                label,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Tab 5: Cambios ────────────────────────────────────────────────────────

  Widget _buildCambiosTab() {
    final collection = _isDriver ? 'drivers' : 'clients';
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('audit_log')
          .where('targetCollection', isEqualTo: collection)
          .where('targetId', isEqualTo: _userId)
          .orderBy('timestamp', descending: true)
          .limit(50)
          .snapshots(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: AppColors.primary),
          );
        }
        if (snap.hasError) {
          return Center(
            child: Text(
              'Error: ${snap.error}',
              style: const TextStyle(color: AppColors.textSecondary),
            ),
          );
        }
        final docs = snap.data?.docs ?? [];
        if (docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.history_rounded,
                  size: 56,
                  color: AppColors.textHint.withValues(alpha: 0.5),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Sin historial de cambios',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Los cambios de perfil aparecerán aquí',
                  style: TextStyle(color: AppColors.textHint, fontSize: 13),
                ),
              ],
            ),
          );
        }

        final highlighted = widget.highlightedChanges ?? [];

        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
          itemCount: docs.length,
          itemBuilder: (context, i) {
            final data = docs[i].data() as Map<String, dynamic>;
            final action = data['action'] as String? ?? 'update';
            final ts = data['timestamp'];
            final DateTime? time = ts is Timestamp ? ts.toDate() : null;
            final details = data['details'] as Map<String, dynamic>?;
            final fields = details != null
                ? (details['fields'] as List?)
                          ?.map((e) => e.toString())
                          .toList() ??
                      []
                : <String>[];
            final values = details != null
                ? (details['values'] as Map<String, dynamic>?) ?? {}
                : <String, dynamic>{};
            final source = details?['source'] as String?;
            final performedBy = data['performedByEmail'] as String? ?? '';
            final isHighlighted = i == 0 && highlighted.isNotEmpty;
            final isUserSelf = source == 'user_self_update';

            final actionColor = action == 'delete'
                ? AppColors.error
                : action == 'create'
                ? AppColors.success
                : isUserSelf
                ? AppColors.warning
                : AppColors.primary;
            final actionIcon = action == 'delete'
                ? Icons.delete_outline_rounded
                : action == 'create'
                ? Icons.person_add_alt_1_rounded
                : isUserSelf
                ? Icons.smartphone_rounded
                : Icons.edit_rounded;
            final actionLabel = action == 'delete'
                ? 'Eliminado'
                : action == 'create'
                ? 'Creado'
                : isUserSelf
                ? 'Cambio por el usuario'
                : 'Editado por admin';

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: isHighlighted
                    ? AppColors.warning.withValues(alpha: 0.08)
                    : AppColors.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isHighlighted
                      ? AppColors.warning.withValues(alpha: 0.45)
                      : AppColors.cardBorder,
                  width: isHighlighted ? 1.5 : 1,
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: actionColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(actionIcon, color: actionColor, size: 20),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    actionLabel,
                                    style: TextStyle(
                                      color: actionColor,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  if (isHighlighted) ...[
                                    const SizedBox(width: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 7,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: AppColors.warning,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: const Text(
                                        'NUEVO',
                                        style: TextStyle(
                                          color: Colors.black,
                                          fontSize: 9,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              if (time != null)
                                Text(
                                  _formatAuditTime(time),
                                  style: const TextStyle(
                                    color: AppColors.textHint,
                                    fontSize: 11,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        if (!isUserSelf && performedBy.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.10),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text(
                              'Admin',
                              style: TextStyle(
                                color: AppColors.primary,
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                      ],
                    ),
                    if (fields.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      const Divider(color: AppColors.cardBorder, height: 1),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: fields.map((f) {
                          final isNew = highlighted.contains(f);
                          return Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 9,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: isNew
                                  ? AppColors.warning.withValues(alpha: 0.15)
                                  : AppColors.surfaceHigh,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: isNew
                                    ? AppColors.warning.withValues(alpha: 0.4)
                                    : AppColors.cardBorder,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  _auditFieldIcon(f),
                                  size: 12,
                                  color: isNew
                                      ? AppColors.warning
                                      : AppColors.textHint,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  f,
                                  style: TextStyle(
                                    color: isNew
                                        ? AppColors.warning
                                        : AppColors.textSecondary,
                                    fontSize: 12,
                                    fontWeight: isNew
                                        ? FontWeight.w700
                                        : FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                      if (isHighlighted && values.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        ...values.entries
                            .where((e) => e.key != 'passwordUpdated')
                            .map(
                              (e) => Padding(
                                padding: const EdgeInsets.only(bottom: 4),
                                child: Row(
                                  children: [
                                    const SizedBox(width: 4),
                                    Icon(
                                      _auditFieldIcon(e.key),
                                      size: 13,
                                      color: AppColors.textHint,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      '${_auditFieldLabel(e.key)}: ',
                                      style: const TextStyle(
                                        color: AppColors.textHint,
                                        fontSize: 12,
                                      ),
                                    ),
                                    Expanded(
                                      child: Text(
                                        '${e.value}',
                                        style: const TextStyle(
                                          color: AppColors.textPrimary,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                      ],
                    ],
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  String _formatAuditTime(DateTime t) {
    final now = DateTime.now();
    final diff = now.difference(t);
    if (diff.inMinutes < 1) return 'Hace un momento';
    if (diff.inMinutes < 60) return 'Hace ${diff.inMinutes} min';
    if (diff.inHours < 24) return 'Hace ${diff.inHours} h';
    if (diff.inDays < 7) return 'Hace ${diff.inDays} días';
    return DateFormat('dd/MM/yyyy · HH:mm').format(t);
  }

  IconData _auditFieldIcon(String field) {
    switch (field) {
      case 'foto de perfil':
      case 'photoUrl':
        return Icons.photo_camera_outlined;
      case 'teléfono':
      case 'phone':
        return Icons.phone_outlined;
      case 'email':
        return Icons.email_outlined;
      case 'nombre':
      case 'name':
        return Icons.person_outline;
      case 'contraseña':
      case 'passwordUpdated':
        return Icons.lock_outline;
      case 'vehículo':
      case 'vehicle':
        return Icons.directions_car_outlined;
      default:
        return Icons.edit_outlined;
    }
  }

  String _auditFieldLabel(String key) {
    switch (key) {
      case 'photoUrl':
        return 'Foto';
      case 'phone':
        return 'Teléfono';
      case 'email':
        return 'Email';
      case 'name':
        return 'Nombre';
      case 'vehicle':
        return 'Vehículo';
      default:
        return key;
    }
  }
}

// ─── Sticky TabBar delegate ───────────────────────────────────────────────────

class _StickyTabBar extends SliverPersistentHeaderDelegate {
  final TabBar tabBar;
  const _StickyTabBar(this.tabBar);

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return Container(color: AppColors.surface, child: tabBar);
  }

  @override
  double get maxExtent => tabBar.preferredSize.height;

  @override
  double get minExtent => tabBar.preferredSize.height;

  @override
  bool shouldRebuild(_StickyTabBar old) => old.tabBar != tabBar;
}

// ─── Verification Photos Widget ───────────────────────────────────────────────

class _UDVerifPhotosWidget extends StatefulWidget {
  final int sqliteId;
  final Future<void> Function(String url, String label) onDownload;

  const _UDVerifPhotosWidget({
    required this.sqliteId,
    required this.onDownload,
  });

  @override
  State<_UDVerifPhotosWidget> createState() => _UDVerifPhotosWidgetState();
}

class _UDVerifPhotosWidgetState extends State<_UDVerifPhotosWidget> {
  Map<String, dynamic>? _data;
  Map<String, dynamic>? _backendUser;
  bool _loading = true;
  bool _ssnRevealed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      // Fetch Firestore verification doc and backend user in parallel
      final results = await Future.wait([
        FirebaseFirestore.instance
            .collection('verifications')
            .doc('sql_${widget.sqliteId}')
            .get(),
        DispatchApiService.getUserDetail(
          widget.sqliteId,
        ).catchError((_) => <String, dynamic>{}),
      ]);
      if (mounted) {
        final doc = results[0] as DocumentSnapshot;
        setState(() {
          _data = doc.exists ? doc.data() as Map<String, dynamic>? : null;
          _backendUser = results[1] as Map<String, dynamic>?;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// Pick the first non-null, non-empty URL from Firestore or backend.
  String? _pick(String firestoreKey, String backendKey) {
    final fs = _data?[firestoreKey] as String?;
    if (fs != null && fs.isNotEmpty) return fs;
    final be = _backendUser?[backendKey] as String?;
    if (be != null && be.isNotEmpty) return be;
    return null;
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(12),
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: AppColors.primary,
          ),
        ),
      );
    }
    if (_data == null && _backendUser == null) {
      return const Text(
        'No hay verificación enviada',
        style: TextStyle(color: AppColors.textHint, fontSize: 13),
      );
    }

    final profileUrl = _pick('profilePhotoUrl', 'photo_url');
    final idUrl = _pick('idPhotoUrl', 'id_photo_url');
    final selfieUrl = _pick('selfieUrl', 'selfie_url');
    final licenseFrontUrl = _pick('licenseFrontUrl', 'license_front_url');
    final licenseBackUrl = _pick('licenseBackUrl', 'license_back_url');
    final insuranceUrl = _pick('insuranceUrl', 'insurance_url');
    final role =
        _data?['role'] as String? ??
        _backendUser?['role'] as String? ??
        'rider';
    final isDriver = role == 'driver';
    final idType =
        _data?['idDocumentType'] as String? ??
        _backendUser?['id_document_type'] as String? ??
        'Government ID';
    final status =
        _data?['status'] as String? ??
        _backendUser?['verification_status'] as String? ??
        'pending';
    final statusColor = status == 'approved'
        ? AppColors.success
        : status == 'rejected'
        ? AppColors.error
        : AppColors.warning;

    // SSN fields — Firestore first, backend fallback
    final ssnMasked =
        _data?['ssnMasked'] as String? ??
        _backendUser?['ssn_masked'] as String?;
    final ssnLast4 =
        _data?['ssnLast4'] as String? ?? _backendUser?['ssn_last4'] as String?;
    final ssnProvided =
        _data?['ssnProvided'] as bool? ??
        _backendUser?['ssn_provided'] as bool? ??
        false;
    final ssnFull = _backendUser?['ssn_full'] as String?;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
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
        // ── SSN row ──────────────────────────────────────────────────────
        const SizedBox(height: 12),
        GestureDetector(
          onTap: ssnProvided && ssnFull != null
              ? () => setState(() => _ssnRevealed = !_ssnRevealed)
              : null,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.surfaceHigh,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: ssnProvided
                    ? AppColors.success.withValues(alpha: 0.3)
                    : AppColors.warning.withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.security_rounded,
                  size: 18,
                  color: ssnProvided ? AppColors.success : AppColors.warning,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Text(
                            'Social Security Number',
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          if (ssnProvided && ssnFull != null) ...[
                            const SizedBox(width: 6),
                            Icon(
                              _ssnRevealed
                                  ? Icons.visibility_off_rounded
                                  : Icons.visibility_rounded,
                              size: 14,
                              color: AppColors.primary,
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        ssnProvided
                            ? (_ssnRevealed && ssnFull != null
                                  ? ssnFull
                                  : (ssnMasked ??
                                        '***-**-${ssnLast4 ?? '????'}'))
                            : 'No proporcionado',
                        style: TextStyle(
                          color: ssnProvided
                              ? AppColors.textPrimary
                              : AppColors.textHint,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          fontFamily: 'monospace',
                          letterSpacing: 1,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: ssnProvided
                        ? AppColors.success.withValues(alpha: 0.12)
                        : AppColors.warning.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    ssnProvided ? 'Verificado' : 'Pendiente',
                    style: TextStyle(
                      color: ssnProvided
                          ? AppColors.success
                          : AppColors.warning,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        // ── License Front ──
        if (licenseFrontUrl != null && licenseFrontUrl.isNotEmpty)
          _verifPhotoTile('Licencia (Frente)', licenseFrontUrl),
        // ── License Back ──
        if (licenseBackUrl != null && licenseBackUrl.isNotEmpty)
          _verifPhotoTile('Licencia (Atrás)', licenseBackUrl),
        // ── Insurance (drivers only) ──
        if (isDriver && insuranceUrl != null && insuranceUrl.isNotEmpty)
          _verifPhotoTile('Seguro de Auto', insuranceUrl),
        // ── Profile photo ──
        if (profileUrl != null && profileUrl.isNotEmpty)
          _verifPhotoTile('Foto de Perfil', profileUrl),
        // ── ID Document fallback ──
        if (idUrl != null && idUrl.isNotEmpty)
          _verifPhotoTile('ID ($idType)', idUrl),
        // ── Selfie / Biometrics ──
        if (selfieUrl != null && selfieUrl.isNotEmpty)
          _verifPhotoTile('Selfie / Biométricos', selfieUrl),
        if ((licenseFrontUrl == null || licenseFrontUrl.isEmpty) &&
            (licenseBackUrl == null || licenseBackUrl.isEmpty) &&
            (profileUrl == null || profileUrl.isEmpty) &&
            (idUrl == null || idUrl.isEmpty) &&
            (selfieUrl == null || selfieUrl.isEmpty))
          const Text(
            'Sin fotos de verificación',
            style: TextStyle(color: AppColors.textHint, fontSize: 13),
          ),
      ],
    );
  }

  Widget _verifPhotoTile(String label, String rawUrl) {
    final url = DispatchApiService.normalizeUrl(
      rawUrl.startsWith('http') ? rawUrl : DispatchApiService.fullUrl(rawUrl),
    );
    
    // Detectar si es un video
    final isVideo = url.toLowerCase().endsWith('.mp4') ||
        url.toLowerCase().endsWith('.mov') ||
        url.toLowerCase().endsWith('.avi') ||
        url.toLowerCase().endsWith('.webm') ||
        url.toLowerCase().contains('video') ||
        label.toLowerCase().contains('biométrico');
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              isVideo ? Icons.videocam_rounded : Icons.image_rounded,
              size: 14,
              color: AppColors.textSecondary,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            const Spacer(),
            TextButton.icon(
              onPressed: () => widget.onDownload(url, label),
              icon: const Icon(Icons.download_rounded, size: 15),
              label: const Text('Guardar'),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        if (isVideo)
          _BiometricVideoPlayer(videoUrl: url)
        else
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Image.network(
              url,
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
}

// ─── Server Documents Widget ──────────────────────────────────────────────────

class _UDServerDocsWidget extends StatefulWidget {
  final int sqliteId;
  final Future<void> Function(String url, String label) onDownload;

  const _UDServerDocsWidget({required this.sqliteId, required this.onDownload});

  @override
  State<_UDServerDocsWidget> createState() => _UDServerDocsWidgetState();
}

class _UDServerDocsWidgetState extends State<_UDServerDocsWidget> {
  List<Map<String, dynamic>>? _docs;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
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
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(12),
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }
    if (_error != null) {
      return Text(
        'Error: $_error',
        style: const TextStyle(color: AppColors.textHint, fontSize: 13),
      );
    }
    if (_docs == null || _docs!.isEmpty) {
      return const Text(
        'No hay documentos subidos',
        style: TextStyle(color: AppColors.textHint, fontSize: 13),
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
        final fileUrl = filePath != null
            ? DispatchApiService.documentUrl(filePath)
            : null;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
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
                if (fileUrl != null) ...[
                  const SizedBox(width: 6),
                  IconButton(
                    icon: const Icon(
                      Icons.download_rounded,
                      size: 18,
                      color: AppColors.primary,
                    ),
                    onPressed: () => widget.onDownload(fileUrl, docType),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ],
            ),
            if (fileUrl != null) ...[
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.network(
                  fileUrl,
                  width: double.infinity,
                  height: 140,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => Container(
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
            const SizedBox(height: 10),
          ],
        );
      }).toList(),
    );
  }

}

// ─── Password Widget ──────────────────────────────────────────────────────────

class _UDPasswordWidget extends StatefulWidget {
  final int sqliteId;

  const _UDPasswordWidget({required this.sqliteId});

  @override
  State<_UDPasswordWidget> createState() => _UDPasswordWidgetState();
}

class _UDPasswordWidgetState extends State<_UDPasswordWidget> {
  String? _password;
  bool _loading = true;
  String? _error;
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    _loadPassword();
  }

  Future<void> _loadPassword() async {
    try {
      final detail = await DispatchApiService.getUserDetail(widget.sqliteId);
      final pwd = detail['password'] as String?;
      if (mounted) {
        setState(() {
          _password = pwd;
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

  void _copyPassword() {
    if (_password != null) {
      Clipboard.setData(ClipboardData(text: _password!));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
          content: Text('Contraseña copiada al portapapeles'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            const Icon(
              Icons.lock_outlined,
              size: 20,
              color: AppColors.textHint,
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Contraseña',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ],
        ),
      );
    }

    if (_error != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            const Icon(
              Icons.lock_outlined,
              size: 20,
              color: AppColors.error,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Contraseña',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Error al cargar',
                    style: TextStyle(
                      color: AppColors.error.withValues(alpha: 0.7),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    final displayPassword = _password ?? 'Sin contraseña';
    final hasPassword = _password != null && _password!.isNotEmpty;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Icon(
            Icons.lock_outlined,
            size: 20,
            color: hasPassword ? AppColors.primary : AppColors.textHint,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Contraseña',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        hasPassword && _obscurePassword
                            ? '••••••••'
                            : displayPassword,
                        style: TextStyle(
                          color: hasPassword
                              ? AppColors.textPrimary
                              : AppColors.textHint,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          fontFamily: hasPassword ? 'monospace' : null,
                        ),
                      ),
                    ),
                    if (hasPassword) ...[
                      const SizedBox(width: 8),
                      InkWell(
                        onTap: () => setState(() => _obscurePassword = !_obscurePassword),
                        borderRadius: BorderRadius.circular(8),
                        child: Padding(
                          padding: const EdgeInsets.all(6),
                          child: Icon(
                            _obscurePassword
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                            size: 18,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                      InkWell(
                        onTap: _copyPassword,
                        borderRadius: BorderRadius.circular(8),
                        child: const Padding(
                          padding: EdgeInsets.all(6),
                          child: Icon(
                            Icons.copy_rounded,
                            size: 18,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Biometric Video Player Widget ────────────────────────────────────────────

class _BiometricVideoPlayer extends StatefulWidget {
  final String videoUrl;

  const _BiometricVideoPlayer({required this.videoUrl});

  @override
  State<_BiometricVideoPlayer> createState() => _BiometricVideoPlayerState();
}

class _BiometricVideoPlayerState extends State<_BiometricVideoPlayer> {
  late VideoPlayerController _controller;
  bool _isInitialized = false;
  bool _hasError = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _initializeVideo();
  }

  Future<void> _initializeVideo() async {
    try {
      _controller = VideoPlayerController.networkUrl(
        Uri.parse(widget.videoUrl),
      );
      await _controller.initialize();
      if (mounted) {
        setState(() {
          _isInitialized = true;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _hasError = true;
          _errorMessage = e.toString();
        });
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_hasError) {
      return Container(
        height: 200,
        decoration: BoxDecoration(
          color: AppColors.surfaceHigh,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline_rounded,
              color: AppColors.error,
              size: 40,
            ),
            const SizedBox(height: 8),
            const Text(
              'Error al cargar video',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (_errorMessage != null) ...[
              const SizedBox(height: 4),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  _errorMessage!,
                  style: const TextStyle(
                    color: AppColors.textHint,
                    fontSize: 11,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ],
        ),
      );
    }

    if (!_isInitialized) {
      return Container(
        height: 200,
        decoration: BoxDecoration(
          color: AppColors.surfaceHigh,
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(
                color: AppColors.primary,
                strokeWidth: 2,
              ),
              SizedBox(height: 12),
              Text(
                'Cargando video...',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Stack(
        alignment: Alignment.center,
        children: [
          AspectRatio(
            aspectRatio: _controller.value.aspectRatio,
            child: VideoPlayer(_controller),
          ),
          // Play/Pause overlay
          Positioned.fill(
            child: GestureDetector(
              onTap: () {
                setState(() {
                  if (_controller.value.isPlaying) {
                    _controller.pause();
                  } else {
                    _controller.play();
                  }
                });
              },
              child: Container(
                color: Colors.transparent,
                child: Center(
                  child: AnimatedOpacity(
                    opacity: _controller.value.isPlaying ? 0.0 : 1.0,
                    duration: const Duration(milliseconds: 200),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.6),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.play_arrow_rounded,
                        color: Colors.white,
                        size: 40,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          // Video controls
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.7),
                  ],
                ),
              ),
              child: Row(
                children: [
                  IconButton(
                    icon: Icon(
                      _controller.value.isPlaying
                          ? Icons.pause_rounded
                          : Icons.play_arrow_rounded,
                      color: Colors.white,
                      size: 24,
                    ),
                    onPressed: () {
                      setState(() {
                        if (_controller.value.isPlaying) {
                          _controller.pause();
                        } else {
                          _controller.play();
                        }
                      });
                    },
                  ),
                  Expanded(
                    child: VideoProgressIndicator(
                      _controller,
                      allowScrubbing: true,
                      colors: const VideoProgressColors(
                        playedColor: AppColors.primary,
                        bufferedColor: AppColors.textHint,
                        backgroundColor: AppColors.surfaceHigh,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _formatDuration(_controller.value.position),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Text(
                    ' / ',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                    ),
                  ),
                  Text(
                    _formatDuration(_controller.value.duration),
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }
}
