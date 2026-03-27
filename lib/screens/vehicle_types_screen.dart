import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../config/app_theme.dart';
import '../services/audit_service.dart';

/// Manage vehicle types (Fusion, Camry, Suburban, etc.) stored in
/// Firestore config/vehicle_types.
class VehicleTypesScreen extends StatefulWidget {
  const VehicleTypesScreen({super.key});

  @override
  State<VehicleTypesScreen> createState() => _VehicleTypesScreenState();
}

class _VehicleTypesScreenState extends State<VehicleTypesScreen> {
  final _db = FirebaseFirestore.instance;
  final _audit = AuditService();
  List<Map<String, dynamic>> _types = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadTypes();
  }

  Future<void> _loadTypes() async {
    try {
      final doc = await _db.collection('config').doc('vehicle_types').get();
      if (doc.exists) {
        final list = (doc.data()?['types'] as List<dynamic>?) ?? [];
        _types = list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      } else {
        // Seed defaults matching existing pricing multipliers
        _types = [
          {'name': 'Fusion', 'multiplier': 1.0, 'maxPassengers': 4, 'active': true},
          {'name': 'Camry', 'multiplier': 1.35, 'maxPassengers': 4, 'active': true},
          {'name': 'Suburban', 'multiplier': 2.20, 'maxPassengers': 7, 'active': true},
        ];
        await _saveTypes();
      }
    } catch (e) {
      debugPrint('Error loading vehicle types: $e');
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _saveTypes() async {
    await _db.collection('config').doc('vehicle_types').set({
      'types': _types,
      'updatedAt': FieldValue.serverTimestamp(),
    });
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
        title: const Text(
          'Tipos de Vehículo',
          style: TextStyle(color: AppColors.textPrimary),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add, color: AppColors.primary),
            onPressed: _showAddDialog,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : _types.isEmpty
              ? const Center(
                  child: Text('Sin tipos de vehículo', style: TextStyle(color: AppColors.textHint)),
                )
              : ReorderableListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: _types.length,
                  onReorder: _reorder,
                  itemBuilder: (_, i) => _buildTypeCard(i),
                ),
    );
  }

  Widget _buildTypeCard(int index) {
    final t = _types[index];
    final name = t['name'] as String? ?? '';
    final mult = (t['multiplier'] as num?)?.toDouble() ?? 1.0;
    final pax = (t['maxPassengers'] as num?)?.toInt() ?? 4;
    final active = t['active'] as bool? ?? true;

    return Container(
      key: ValueKey('vtype_$index'),
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: active
              ? AppColors.primary.withValues(alpha: 0.2)
              : AppColors.cardBorder,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: active
                  ? AppColors.primary.withValues(alpha: 0.15)
                  : AppColors.surfaceHigh,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              Icons.directions_car,
              color: active ? AppColors.primary : AppColors.textHint,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: TextStyle(
                    color: active ? AppColors.textPrimary : AppColors.textHint,
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
                Text(
                  '${mult}x · $pax pasajeros',
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: active,
            onChanged: (v) {
              setState(() => _types[index]['active'] = v);
              _saveTypes();
            },
            activeThumbColor: AppColors.primary,
            inactiveThumbColor: AppColors.textHint,
          ),
          IconButton(
            icon: const Icon(Icons.edit, color: AppColors.primary, size: 20),
            onPressed: () => _showEditDialog(index),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, color: AppColors.error, size: 20),
            onPressed: () => _confirmDelete(index),
          ),
        ],
      ),
    );
  }

  void _reorder(int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > oldIndex) newIndex--;
      final item = _types.removeAt(oldIndex);
      _types.insert(newIndex, item);
    });
    _saveTypes();
  }

  void _showAddDialog() => _showEditDialog(-1);

  void _showEditDialog(int index) {
    final isNew = index < 0;
    final existing = isNew ? <String, dynamic>{} : _types[index];
    final nameCtrl = TextEditingController(text: existing['name'] as String? ?? '');
    final multCtrl = TextEditingController(
      text: ((existing['multiplier'] as num?)?.toDouble() ?? 1.0).toString(),
    );
    final paxCtrl = TextEditingController(
      text: ((existing['maxPassengers'] as num?)?.toInt() ?? 4).toString(),
    );

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          isNew ? 'Nuevo Tipo' : 'Editar ${existing['name']}',
          style: const TextStyle(color: AppColors.textPrimary),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _field(nameCtrl, 'Nombre', TextInputType.text),
            const SizedBox(height: 12),
            _field(multCtrl, 'Multiplicador', TextInputType.number),
            const SizedBox(height: 12),
            _field(paxCtrl, 'Pasajeros máx', TextInputType.number),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () {
              final name = nameCtrl.text.trim();
              if (name.isEmpty) return;
              final entry = {
                'name': name,
                'multiplier': double.tryParse(multCtrl.text) ?? 1.0,
                'maxPassengers': int.tryParse(paxCtrl.text) ?? 4,
                'active': existing['active'] as bool? ?? true,
              };
              setState(() {
                if (isNew) {
                  _types.add(entry);
                } else {
                  _types[index] = entry;
                }
              });
              _saveTypes();
              _audit.log(
                action: isNew ? 'create_vehicle_type' : 'update_vehicle_type',
                targetCollection: 'config/vehicle_types',
                targetId: name,
                targetName: name,
              );
              Navigator.pop(ctx);
            },
            child: Text(
              isNew ? 'Crear' : 'Guardar',
              style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  Widget _field(TextEditingController ctrl, String hint, TextInputType type) {
    return TextField(
      controller: ctrl,
      keyboardType: type,
      style: const TextStyle(color: AppColors.textPrimary),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: AppColors.textSecondary.withValues(alpha: 0.5)),
        filled: true,
        fillColor: AppColors.surfaceHigh,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      ),
    );
  }

  Future<void> _confirmDelete(int index) async {
    final name = _types[index]['name'] as String? ?? '';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('¿Eliminar tipo?', style: TextStyle(color: AppColors.textPrimary)),
        content: Text(
          'Eliminar "$name" permanentemente.',
          style: const TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Eliminar', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() => _types.removeAt(index));
    _saveTypes();
    _audit.logDelete('config/vehicle_types', name, name);
  }
}
