import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../config/app_theme.dart';

class PromosScreen extends StatefulWidget {
  const PromosScreen({super.key});

  @override
  State<PromosScreen> createState() => _PromosScreenState();
}

enum _PromoFilter { all, active, expired }

class _PromosScreenState extends State<PromosScreen> {
  StreamSubscription<QuerySnapshot>? _subscription;
  List<DocumentSnapshot> _promos = [];
  bool _isLoading = true;
  _PromoFilter _filter = _PromoFilter.all;

  @override
  void initState() {
    super.initState();
    _listenToPromos();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  void _listenToPromos() {
    _subscription = FirebaseFirestore.instance
        .collection('promo_codes')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .listen((snapshot) {
      if (!mounted) return;
      setState(() {
        _promos = snapshot.docs;
        _isLoading = false;
      });
    }, onError: (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
    });
  }

  List<DocumentSnapshot> get _filteredPromos {
    final now = DateTime.now();
    return _promos.where((doc) {
      final data = doc.data() as Map<String, dynamic>;
      final isActive = data['isActive'] == true;
      final expiresAt = (data['expiresAt'] as Timestamp?)?.toDate();
      final isExpired = expiresAt != null && expiresAt.isBefore(now);

      switch (_filter) {
        case _PromoFilter.active:
          return isActive && !isExpired;
        case _PromoFilter.expired:
          return isExpired;
        case _PromoFilter.all:
          return true;
      }
    }).toList();
  }

  int get _activeCount {
    final now = DateTime.now();
    return _promos.where((doc) {
      final data = doc.data() as Map<String, dynamic>;
      final isActive = data['isActive'] == true;
      final expiresAt = (data['expiresAt'] as Timestamp?)?.toDate();
      return isActive && (expiresAt == null || expiresAt.isAfter(now));
    }).length;
  }

  int get _totalRedemptions {
    int total = 0;
    for (final doc in _promos) {
      final data = doc.data() as Map<String, dynamic>;
      total += (data['currentUses'] as num?)?.toInt() ?? 0;
    }
    return total;
  }

  double get _totalDiscountGiven {
    double total = 0;
    for (final doc in _promos) {
      final data = doc.data() as Map<String, dynamic>;
      final uses = (data['currentUses'] as num?)?.toDouble() ?? 0;
      final value = (data['discountValue'] as num?)?.toDouble() ?? 0;
      final type = data['discountType'] as String? ?? 'percentage';
      // For fixed: uses * value. For percentage: approximate as uses * value (actual depends on fare).
      if (type == 'fixed') {
        total += uses * value;
      } else {
        // Cannot know exact fare, show uses * value as approximate
        total += uses * value;
      }
    }
    return total;
  }

  Future<void> _toggleActive(DocumentSnapshot doc, bool value) async {
    await FirebaseFirestore.instance
        .collection('promo_codes')
        .doc(doc.id)
        .update({'isActive': value});
  }

  Future<void> _deletePromo(DocumentSnapshot doc) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete Promo Code',
            style: TextStyle(color: AppColors.textPrimary)),
        content: Text(
          'Are you sure you want to delete "${(doc.data() as Map<String, dynamic>)['code']}"?',
          style: const TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel',
                style: TextStyle(color: AppColors.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child:
                const Text('Delete', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await FirebaseFirestore.instance
          .collection('promo_codes')
          .doc(doc.id)
          .delete();
    }
  }

  void _showPromoSheet({DocumentSnapshot? doc}) {
    final data =
        doc != null ? doc.data() as Map<String, dynamic> : <String, dynamic>{};
    final isEdit = doc != null;

    final codeCtrl = TextEditingController(text: data['code'] as String? ?? '');
    final valueCtrl = TextEditingController(
        text: (data['discountValue'] as num?)?.toString() ?? '');
    final maxUsesCtrl = TextEditingController(
        text: (data['maxUses'] as num?)?.toString() ?? '0');
    final minFareCtrl = TextEditingController(
        text: (data['minFare'] as num?)?.toString() ?? '0');
    final descCtrl =
        TextEditingController(text: data['description'] as String? ?? '');

    String discountType = data['discountType'] as String? ?? 'percentage';
    DateTime? expiresAt = (data['expiresAt'] as Timestamp?)?.toDate();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            return Container(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(ctx).viewInsets.bottom,
              ),
              decoration: const BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Handle
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: AppColors.textHint,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      isEdit ? 'Edit Promo Code' : 'Create Promo Code',
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Code field
                    _sheetField(
                      label: 'Promo Code',
                      controller: codeCtrl,
                      hint: 'e.g. CRUISE20',
                      inputFormatters: [UpperCaseTextFormatter()],
                      textCapitalization: TextCapitalization.characters,
                    ),
                    const SizedBox(height: 16),

                    // Discount type toggle
                    const Text('Discount Type',
                        style: TextStyle(
                            color: AppColors.textSecondary, fontSize: 13)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () => setSheetState(
                                () => discountType = 'percentage'),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              decoration: BoxDecoration(
                                color: discountType == 'percentage'
                                    ? AppColors.primary
                                    : AppColors.surfaceHigh,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                'Percentage',
                                style: TextStyle(
                                  color: discountType == 'percentage'
                                      ? AppColors.background
                                      : AppColors.textSecondary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: GestureDetector(
                            onTap: () =>
                                setSheetState(() => discountType = 'fixed'),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              decoration: BoxDecoration(
                                color: discountType == 'fixed'
                                    ? AppColors.primary
                                    : AppColors.surfaceHigh,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                'Fixed Amount',
                                style: TextStyle(
                                  color: discountType == 'fixed'
                                      ? AppColors.background
                                      : AppColors.textSecondary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Discount value
                    _sheetField(
                      label: discountType == 'percentage'
                          ? 'Discount Percentage'
                          : 'Discount Amount (\$)',
                      controller: valueCtrl,
                      hint: discountType == 'percentage' ? 'e.g. 20' : 'e.g. 5.00',
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                    ),
                    const SizedBox(height: 16),

                    // Max uses & min fare
                    Row(
                      children: [
                        Expanded(
                          child: _sheetField(
                            label: 'Max Uses (0 = unlimited)',
                            controller: maxUsesCtrl,
                            hint: '0',
                            keyboardType: TextInputType.number,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _sheetField(
                            label: 'Min Fare (\$)',
                            controller: minFareCtrl,
                            hint: '0',
                            keyboardType: const TextInputType.numberWithOptions(
                                decimal: true),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Expiry date picker
                    const Text('Expiry Date (optional)',
                        style: TextStyle(
                            color: AppColors.textSecondary, fontSize: 13)),
                    const SizedBox(height: 8),
                    GestureDetector(
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: ctx,
                          initialDate:
                              expiresAt ?? DateTime.now().add(const Duration(days: 30)),
                          firstDate: DateTime.now(),
                          lastDate:
                              DateTime.now().add(const Duration(days: 365 * 2)),
                          builder: (context, child) {
                            return Theme(
                              data: ThemeData.dark().copyWith(
                                colorScheme: const ColorScheme.dark(
                                  primary: AppColors.primary,
                                  surface: AppColors.surface,
                                ),
                              ),
                              child: child!,
                            );
                          },
                        );
                        if (picked != null) {
                          setSheetState(() => expiresAt = picked);
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 14),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceHigh,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                expiresAt != null
                                    ? DateFormat('MMM d, yyyy').format(expiresAt!)
                                    : 'No expiry',
                                style: TextStyle(
                                  color: expiresAt != null
                                      ? AppColors.textPrimary
                                      : AppColors.textHint,
                                ),
                              ),
                            ),
                            if (expiresAt != null)
                              GestureDetector(
                                onTap: () =>
                                    setSheetState(() => expiresAt = null),
                                child: const Icon(Icons.close,
                                    color: AppColors.textSecondary, size: 18),
                              )
                            else
                              const Icon(Icons.calendar_today,
                                  color: AppColors.textSecondary, size: 18),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Description
                    _sheetField(
                      label: 'Description',
                      controller: descCtrl,
                      hint: 'e.g. Summer promo for new riders',
                      maxLines: 2,
                    ),
                    const SizedBox(height: 28),

                    // Save button
                    SizedBox(
                      height: 52,
                      child: ElevatedButton(
                        onPressed: () => _savePromo(
                          ctx: ctx,
                          docId: doc?.id,
                          code: codeCtrl.text.trim(),
                          discountType: discountType,
                          discountValue:
                              double.tryParse(valueCtrl.text.trim()) ?? 0,
                          maxUses:
                              int.tryParse(maxUsesCtrl.text.trim()) ?? 0,
                          minFare:
                              double.tryParse(minFareCtrl.text.trim()) ?? 0,
                          expiresAt: expiresAt,
                          description: descCtrl.text.trim(),
                          currentUses: (data['currentUses'] as num?)?.toInt() ?? 0,
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: AppColors.background,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          textStyle: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        child: Text(isEdit ? 'Update Promo' : 'Create Promo'),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _sheetField({
    required String label,
    required TextEditingController controller,
    String? hint,
    TextInputType? keyboardType,
    int maxLines = 1,
    List<TextInputFormatter>? inputFormatters,
    TextCapitalization textCapitalization = TextCapitalization.none,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                color: AppColors.textSecondary, fontSize: 13)),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          maxLines: maxLines,
          inputFormatters: inputFormatters,
          textCapitalization: textCapitalization,
          style: const TextStyle(color: AppColors.textPrimary),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: AppColors.textHint),
            filled: true,
            fillColor: AppColors.surfaceHigh,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
        ),
      ],
    );
  }

  Future<void> _savePromo({
    required BuildContext ctx,
    String? docId,
    required String code,
    required String discountType,
    required double discountValue,
    required int maxUses,
    required double minFare,
    DateTime? expiresAt,
    required String description,
    required int currentUses,
  }) async {
    if (code.isEmpty || discountValue <= 0) {
      ScaffoldMessenger.of(ctx).showSnackBar(
        const SnackBar(
          backgroundColor: AppColors.surfaceHigh,
          content: Text('Code and discount value are required',
              style: TextStyle(color: AppColors.textPrimary)),
        ),
      );
      return;
    }

    final data = <String, dynamic>{
      'code': code.toUpperCase(),
      'discountType': discountType,
      'discountValue': discountValue,
      'maxUses': maxUses,
      'minFare': minFare,
      'expiresAt': expiresAt != null ? Timestamp.fromDate(expiresAt) : null,
      'isActive': true,
      'description': description,
    };

    final collection = FirebaseFirestore.instance.collection('promo_codes');

    if (docId != null) {
      await collection.doc(docId).update(data);
    } else {
      data['currentUses'] = 0;
      data['createdAt'] = FieldValue.serverTimestamp();
      await collection.add(data);
    }

    if (ctx.mounted) Navigator.pop(ctx);
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredPromos;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        title: const Text('Promo Codes',
            style: TextStyle(
                color: AppColors.textPrimary, fontWeight: FontWeight.bold)),
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
        elevation: 0,
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.primary,
        onPressed: () => _showPromoSheet(),
        child: const Icon(Icons.add, color: AppColors.background),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary))
          : Column(
              children: [
                // Summary row
                _buildSummaryRow(),
                const SizedBox(height: 8),
                // Filter chips
                _buildFilterChips(),
                const SizedBox(height: 8),
                // Promo list
                Expanded(
                  child: filtered.isEmpty
                      ? _buildEmptyState()
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
                          itemCount: filtered.length,
                          itemBuilder: (_, i) =>
                              _buildPromoCard(filtered[i]),
                        ),
                ),
              ],
            ),
    );
  }

  Widget _buildSummaryRow() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Row(
        children: [
          _summaryItem('Active', '$_activeCount', Icons.local_offer),
          _divider(),
          _summaryItem('Redeemed', '$_totalRedemptions', Icons.redeem),
          _divider(),
          _summaryItem(
            'Discount',
            '\$${_totalDiscountGiven.toStringAsFixed(0)}',
            Icons.savings_outlined,
          ),
        ],
      ),
    );
  }

  Widget _summaryItem(String label, String value, IconData icon) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, color: AppColors.primary, size: 20),
          const SizedBox(height: 6),
          Text(value,
              style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.bold,
                  fontSize: 18)),
          const SizedBox(height: 2),
          Text(label,
              style: const TextStyle(
                  color: AppColors.textSecondary, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _divider() {
    return Container(width: 1, height: 40, color: AppColors.surfaceHigh);
  }

  Widget _buildFilterChips() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: _PromoFilter.values.map((f) {
          final selected = _filter == f;
          final label = f == _PromoFilter.all
              ? 'All'
              : f == _PromoFilter.active
                  ? 'Active'
                  : 'Expired';
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(label),
              selected: selected,
              onSelected: (_) => setState(() => _filter = f),
              selectedColor: AppColors.primary,
              backgroundColor: AppColors.surfaceHigh,
              labelStyle: TextStyle(
                color: selected ? AppColors.background : AppColors.textSecondary,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              side: BorderSide.none,
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.local_offer_outlined,
              size: 64, color: AppColors.textHint),
          const SizedBox(height: 16),
          const Text('No promo codes yet',
              style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 16,
                  fontWeight: FontWeight.w500)),
          const SizedBox(height: 8),
          const Text('Tap + to create one',
              style: TextStyle(color: AppColors.textHint, fontSize: 14)),
        ],
      ),
    );
  }

  Widget _buildPromoCard(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final code = data['code'] as String? ?? '';
    final description = data['description'] as String? ?? '';
    final discountType = data['discountType'] as String? ?? 'percentage';
    final discountValue = (data['discountValue'] as num?)?.toDouble() ?? 0;
    final maxUses = (data['maxUses'] as num?)?.toInt() ?? 0;
    final currentUses = (data['currentUses'] as num?)?.toInt() ?? 0;
    final isActive = data['isActive'] == true;
    final expiresAt = (data['expiresAt'] as Timestamp?)?.toDate();
    final now = DateTime.now();
    final isExpired = expiresAt != null && expiresAt.isBefore(now);

    final discountLabel = discountType == 'percentage'
        ? '${discountValue.toStringAsFixed(0)}% OFF'
        : '\$${discountValue.toStringAsFixed(2)} OFF';

    final usageLabel = maxUses > 0 ? '$currentUses/$maxUses used' : '$currentUses used';
    final usageProgress =
        maxUses > 0 ? (currentUses / maxUses).clamp(0.0, 1.0) : 0.0;

    return Dismissible(
      key: ValueKey(doc.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.red.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Icon(Icons.delete_outline, color: Colors.red, size: 28),
      ),
      confirmDismiss: (_) async {
        await _deletePromo(doc);
        return false; // deletion handled by Firestore listener
      },
      child: GestureDetector(
        onTap: () => _showPromoSheet(doc: doc),
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.cardBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top row: code + discount badge + toggle
              Row(
                children: [
                  Expanded(
                    child: Text(
                      code,
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'monospace',
                        letterSpacing: 1.5,
                      ),
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      discountLabel,
                      style: const TextStyle(
                        color: AppColors.background,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    height: 28,
                    child: Switch(
                      value: isActive,
                      activeColor: AppColors.primary,
                      onChanged: (val) => _toggleActive(doc, val),
                    ),
                  ),
                ],
              ),

              // Description
              if (description.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(description,
                    style: const TextStyle(
                        color: AppColors.textSecondary, fontSize: 13)),
              ],

              const SizedBox(height: 14),

              // Usage bar
              Row(
                children: [
                  Text(usageLabel,
                      style: const TextStyle(
                          color: AppColors.textSecondary, fontSize: 12)),
                  const SizedBox(width: 12),
                  if (maxUses > 0)
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: usageProgress,
                          minHeight: 6,
                          backgroundColor: AppColors.surfaceHigh,
                          valueColor: const AlwaysStoppedAnimation<Color>(
                              AppColors.primary),
                        ),
                      ),
                    )
                  else
                    Expanded(
                      child: Text('Unlimited',
                          style: TextStyle(
                              color: AppColors.textHint, fontSize: 12)),
                    ),
                ],
              ),

              const SizedBox(height: 10),

              // Expiry row
              Row(
                children: [
                  Icon(
                    isExpired ? Icons.timer_off : Icons.timer_outlined,
                    size: 14,
                    color:
                        isExpired ? Colors.red.shade300 : AppColors.textHint,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    expiresAt != null
                        ? (isExpired
                            ? 'Expired ${DateFormat('MMM d, yyyy').format(expiresAt)}'
                            : 'Expires ${DateFormat('MMM d, yyyy').format(expiresAt)}')
                        : 'No expiry',
                    style: TextStyle(
                      color:
                          isExpired ? Colors.red.shade300 : AppColors.textHint,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Formatter that converts text to uppercase as the user types.
class UpperCaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    return TextEditingValue(
      text: newValue.text.toUpperCase(),
      selection: newValue.selection,
    );
  }
}
