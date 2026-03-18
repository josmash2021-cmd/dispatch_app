import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../config/app_theme.dart';
import '../models/trip_model.dart';
import '../providers/trip_provider.dart';

class CreateTripScreen extends StatefulWidget {
  const CreateTripScreen({super.key});
  @override
  State<CreateTripScreen> createState() => _CreateTripScreenState();
}

class _CreateTripScreenState extends State<CreateTripScreen>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  final _passengerNameCtrl = TextEditingController();
  final _passengerPhoneCtrl = TextEditingController();
  final _pickupAddressCtrl = TextEditingController();
  final _pickupLatCtrl = TextEditingController();
  final _pickupLngCtrl = TextEditingController();
  final _dropoffAddressCtrl = TextEditingController();
  final _dropoffLatCtrl = TextEditingController();
  final _dropoffLngCtrl = TextEditingController();
  final _fareCtrl = TextEditingController();
  final _distanceCtrl = TextEditingController();
  final _durationCtrl = TextEditingController();
  String _paymentMethod = 'cash';
  String _vehicleType = 'Economy';

  // Stagger animations
  late AnimationController _staggerCtrl;
  final List<Animation<double>> _sectionAnims = [];

  static const _vehicleTypes = ['Economy', 'Comfort', 'Premium', 'XL', 'Moto'];
  static const _paymentOptions = [
    ('cash', Icons.payments_outlined, 'Cash'),
    ('card', Icons.credit_card_rounded, 'Card'),
    ('transfer', Icons.swap_horiz_rounded, 'Transfer'),
  ];

  @override
  void initState() {
    super.initState();
    _staggerCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    for (int i = 0; i < 5; i++) {
      final start = (i * 0.12).clamp(0.0, 1.0);
      final end = (start + 0.50).clamp(0.0, 1.0);
      _sectionAnims.add(
        CurvedAnimation(
          parent: _staggerCtrl,
          curve: Interval(start, end, curve: Curves.easeOutCubic),
        ),
      );
    }
    _staggerCtrl.forward();
  }

  @override
  void dispose() {
    _staggerCtrl.dispose();
    for (final c in [
      _passengerNameCtrl,
      _passengerPhoneCtrl,
      _pickupAddressCtrl,
      _pickupLatCtrl,
      _pickupLngCtrl,
      _dropoffAddressCtrl,
      _dropoffLatCtrl,
      _dropoffLngCtrl,
      _fareCtrl,
      _distanceCtrl,
      _durationCtrl,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _create() async {
    if (!_formKey.currentState!.validate()) return;
    HapticFeedback.mediumImpact();
    setState(() => _isLoading = true);
    try {
      final trip = TripModel(
        tripId: const Uuid().v4(),
        passengerId: 'PAX_${const Uuid().v4().substring(0, 8)}',
        passengerName: _passengerNameCtrl.text.trim(),
        passengerPhone: _passengerPhoneCtrl.text.trim(),
        pickupAddress: _pickupAddressCtrl.text.trim(),
        pickupLat: double.tryParse(_pickupLatCtrl.text) ?? 0.0,
        pickupLng: double.tryParse(_pickupLngCtrl.text) ?? 0.0,
        dropoffAddress: _dropoffAddressCtrl.text.trim(),
        dropoffLat: double.tryParse(_dropoffLatCtrl.text) ?? 0.0,
        dropoffLng: double.tryParse(_dropoffLngCtrl.text) ?? 0.0,
        status: TripStatus.requested,
        fare: double.tryParse(_fareCtrl.text) ?? 0.0,
        distance: double.tryParse(_distanceCtrl.text) ?? 0.0,
        duration: int.tryParse(_durationCtrl.text) ?? 0,
        paymentMethod: _paymentMethod,
        vehicleType: _vehicleType,
        createdAt: DateTime.now(),
      );
      await context.read<TripProvider>().createTrip(trip);
      if (mounted) {
        HapticFeedback.lightImpact();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: const [
                Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
                SizedBox(width: 10),
                Text('Trip created successfully'),
              ],
            ),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            margin: const EdgeInsets.all(16),
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            margin: const EdgeInsets.all(16),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(
          icon: Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.cardBorder),
            ),
            child: const Icon(
              Icons.arrow_back_ios_new_rounded,
              size: 15,
              color: AppColors.textPrimary,
            ),
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppColors.primary, AppColors.primaryLight],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(9),
              ),
              child: const Icon(
                Icons.add_road_rounded,
                color: Color(0xFF08090C),
                size: 17,
              ),
            ),
            const SizedBox(width: 10),
            const Text(
              'New Trip',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Route Preview Hero ──────────────────────────────────────────
              _animated(0, _buildRouteHero()),
              const SizedBox(height: 20),

              // ── Passenger Section ────────────────────────────────────────────
              _animated(
                1,
                _buildSection(
                  icon: Icons.person_rounded,
                  title: 'Passenger',
                  color: AppColors.primary,
                  children: [
                    _field(
                      _passengerNameCtrl,
                      'Full Name',
                      'e.g. John Smith',
                      Icons.person_outline_rounded,
                      required: true,
                    ),
                    const SizedBox(height: 12),
                    _field(
                      _passengerPhoneCtrl,
                      'Phone Number',
                      'e.g. +1 555 0100',
                      Icons.phone_outlined,
                      keyboard: TextInputType.phone,
                      required: true,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // ── Route Section ────────────────────────────────────────────────
              _animated(
                2,
                _buildSection(
                  icon: Icons.alt_route_rounded,
                  title: 'Route',
                  color: const Color(0xFF4FC3F7),
                  children: [
                    _locationField(
                      ctrl: _pickupAddressCtrl,
                      latCtrl: _pickupLatCtrl,
                      lngCtrl: _pickupLngCtrl,
                      label: 'Pickup Address',
                      hint: 'e.g. 123 Main St',
                      dotColor: AppColors.success,
                      required: true,
                    ),
                    Padding(
                      padding: const EdgeInsets.only(left: 10),
                      child: Row(
                        children: [
                          Container(
                            width: 1.5,
                            height: 16,
                            color: AppColors.divider,
                          ),
                        ],
                      ),
                    ),
                    _locationField(
                      ctrl: _dropoffAddressCtrl,
                      latCtrl: _dropoffLatCtrl,
                      lngCtrl: _dropoffLngCtrl,
                      label: 'Drop-off Address',
                      hint: 'e.g. 456 Oak Ave',
                      dotColor: AppColors.error,
                      required: true,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // ── Details Section ──────────────────────────────────────────────
              _animated(
                3,
                _buildSection(
                  icon: Icons.receipt_long_rounded,
                  title: 'Trip Details',
                  color: AppColors.primary,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: _field(
                            _fareCtrl,
                            'Fare (\$)',
                            '0.00',
                            Icons.attach_money_rounded,
                            keyboard: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            required: true,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _field(
                            _distanceCtrl,
                            'Distance (mi)',
                            '0.0',
                            Icons.straighten_rounded,
                            keyboard: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _field(
                      _durationCtrl,
                      'Duration (min)',
                      '0',
                      Icons.timer_outlined,
                      keyboard: TextInputType.number,
                    ),
                    const SizedBox(height: 16),
                    _buildLabel('Vehicle Type', Icons.directions_car_outlined),
                    const SizedBox(height: 8),
                    _buildChipSelector(
                      options: _vehicleTypes,
                      selected: _vehicleType,
                      onSelected: (v) => setState(() => _vehicleType = v),
                    ),
                    const SizedBox(height: 16),
                    _buildLabel('Payment Method', Icons.payment_rounded),
                    const SizedBox(height: 8),
                    _buildPaymentSelector(),
                  ],
                ),
              ),
              const SizedBox(height: 28),

              // ── Submit Button ────────────────────────────────────────────────
              _animated(4, _buildSubmitButton()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _animated(int index, Widget child) {
    return AnimatedBuilder(
      animation: _sectionAnims[index],
      builder: (_, _) => Transform.translate(
        offset: Offset(0, 24 * (1 - _sectionAnims[index].value)),
        child: Opacity(
          opacity: _sectionAnims[index].value.clamp(0.0, 1.0),
          child: child,
        ),
      ),
    );
  }

  Widget _buildRouteHero() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.surface, AppColors.surfaceHigh],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.35),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          // Route dots visualization
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: AppColors.success,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.success.withValues(alpha: 0.6),
                      blurRadius: 6,
                    ),
                  ],
                ),
              ),
              Container(
                width: 1.5,
                height: 30,
                margin: const EdgeInsets.symmetric(vertical: 2),
                color: AppColors.divider,
              ),
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: AppColors.error,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.error.withValues(alpha: 0.6),
                      blurRadius: 6,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AnimatedBuilder(
                  animation: _passengerNameCtrl,
                  builder: (_, _) => Text(
                    _pickupAddressCtrl.text.isNotEmpty
                        ? _pickupAddressCtrl.text
                        : 'Pickup location…',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: _pickupAddressCtrl.text.isNotEmpty
                          ? AppColors.textPrimary
                          : AppColors.textHint,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(height: 4),
                AnimatedBuilder(
                  animation: _dropoffAddressCtrl,
                  builder: (_, _) => Text(
                    _dropoffAddressCtrl.text.isNotEmpty
                        ? _dropoffAddressCtrl.text
                        : 'Drop-off location…',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: _dropoffAddressCtrl.text.isNotEmpty
                          ? AppColors.textPrimary
                          : AppColors.textHint,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: AppColors.primary.withValues(alpha: 0.25),
              ),
            ),
            child: AnimatedBuilder(
              animation: _fareCtrl,
              builder: (_, _) => Text(
                _fareCtrl.text.isNotEmpty ? '\$${_fareCtrl.text}' : '\$—',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: AppColors.primary,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection({
    required IconData icon,
    required String title,
    required Color color,
    required List<Widget> children,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(icon, size: 16, color: color),
              ),
              const SizedBox(width: 10),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Container(
            height: 1,
            color: AppColors.cardBorder.withValues(alpha: 0.6),
            margin: const EdgeInsets.only(bottom: 14),
          ),
          ...children,
        ],
      ),
    );
  }

  Widget _locationField({
    required TextEditingController ctrl,
    required TextEditingController latCtrl,
    required TextEditingController lngCtrl,
    required String label,
    required String hint,
    required Color dotColor,
    bool required = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Column(
              children: [
                const SizedBox(height: 14),
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: dotColor,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: dotColor.withValues(alpha: 0.6),
                        blurRadius: 5,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _field(ctrl, label, hint, null, required: required),
            ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.only(left: 18, top: 8),
          child: Row(
            children: [
              Expanded(child: _coordField(latCtrl, 'Lat')),
              const SizedBox(width: 8),
              Expanded(child: _coordField(lngCtrl, 'Lng')),
            ],
          ),
        ),
      ],
    );
  }

  Widget _coordField(TextEditingController ctrl, String label) {
    return SizedBox(
      height: 38,
      child: TextFormField(
        controller: ctrl,
        keyboardType: const TextInputType.numberWithOptions(
          decimal: true,
          signed: true,
        ),
        style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(fontSize: 11, color: AppColors.textHint),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 10,
            vertical: 8,
          ),
          filled: true,
          fillColor: AppColors.surfaceHigh,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }

  Widget _buildLabel(String text, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 13, color: AppColors.textHint),
        const SizedBox(width: 5),
        Text(
          text,
          style: const TextStyle(
            fontSize: 12,
            color: AppColors.textHint,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildChipSelector({
    required List<String> options,
    required String selected,
    required ValueChanged<String> onSelected,
  }) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: options.map((opt) {
        final isSelected = opt == selected;
        return GestureDetector(
          onTap: () {
            HapticFeedback.selectionClick();
            onSelected(opt);
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
            decoration: BoxDecoration(
              color: isSelected
                  ? AppColors.primary.withValues(alpha: 0.15)
                  : AppColors.surfaceHigh,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isSelected
                    ? AppColors.primary.withValues(alpha: 0.6)
                    : AppColors.cardBorder,
                width: isSelected ? 1.5 : 1,
              ),
            ),
            child: Text(
              opt,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w400,
                color: isSelected ? AppColors.primary : AppColors.textSecondary,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildPaymentSelector() {
    return Row(
      children: _paymentOptions.map((opt) {
        final (value, icon, label) = opt;
        final isSelected = _paymentMethod == value;
        return Expanded(
          child: GestureDetector(
            onTap: () {
              HapticFeedback.selectionClick();
              setState(() => _paymentMethod = value);
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: EdgeInsets.only(right: value == 'transfer' ? 0 : 8),
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: isSelected
                    ? AppColors.primary.withValues(alpha: 0.15)
                    : AppColors.surfaceHigh,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isSelected
                      ? AppColors.primary.withValues(alpha: 0.6)
                      : AppColors.cardBorder,
                  width: isSelected ? 1.5 : 1,
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    icon,
                    size: 18,
                    color: isSelected ? AppColors.primary : AppColors.textHint,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: isSelected
                          ? FontWeight.w700
                          : FontWeight.w400,
                      color: isSelected
                          ? AppColors.primary
                          : AppColors.textHint,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildSubmitButton() {
    return GestureDetector(
      onTap: _isLoading ? null : _create,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        height: 56,
        decoration: BoxDecoration(
          gradient: _isLoading
              ? LinearGradient(
                  colors: [
                    AppColors.primary.withValues(alpha: 0.4),
                    AppColors.primary.withValues(alpha: 0.3),
                  ],
                )
              : const LinearGradient(
                  colors: [AppColors.primary, AppColors.primaryLight],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: _isLoading
              ? []
              : [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.35),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
        ),
        child: Center(
          child: _isLoading
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: Color(0xFF08090C),
                  ),
                )
              : const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.add_rounded, color: Color(0xFF08090C), size: 22),
                    SizedBox(width: 8),
                    Text(
                      'Create Trip',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF08090C),
                        letterSpacing: 0.3,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _field(
    TextEditingController ctrl,
    String label,
    String hint,
    IconData? icon, {
    TextInputType? keyboard,
    bool required = false,
  }) {
    return TextFormField(
      controller: ctrl,
      keyboardType: keyboard,
      style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: icon != null ? Icon(icon, size: 18) : null,
        labelStyle: const TextStyle(color: AppColors.textHint, fontSize: 13),
        hintStyle: const TextStyle(color: AppColors.textHint, fontSize: 13),
        filled: true,
        fillColor: AppColors.surfaceHigh,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.cardBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.error, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 14,
        ),
      ),
      validator: required
          ? (v) => (v == null || v.isEmpty) ? 'Required' : null
          : null,
    );
  }
}
