import 'package:flutter/material.dart';
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

class _CreateTripScreenState extends State<CreateTripScreen> {
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

  @override
  void dispose() {
    for (final c in [_passengerNameCtrl, _passengerPhoneCtrl, _pickupAddressCtrl, _pickupLatCtrl, _pickupLngCtrl, _dropoffAddressCtrl, _dropoffLatCtrl, _dropoffLngCtrl, _fareCtrl, _distanceCtrl, _durationCtrl]) { c.dispose(); }
    super.dispose();
  }

  Future<void> _create() async {
    if (!_formKey.currentState!.validate()) return;
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
        createdAt: DateTime.now(),
      );
      await context.read<TripProvider>().createTrip(trip);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Trip created successfully'), backgroundColor: AppColors.success));
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.error));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('New Trip'), backgroundColor: AppColors.background),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        child: Form(
          key: _formKey,
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            _section('Passenger', Icons.person_rounded),
            const SizedBox(height: 12),
            _field(_passengerNameCtrl, 'Passenger Name', 'e.g. John Smith', Icons.person_outline_rounded, required: true),
            const SizedBox(height: 12),
            _field(_passengerPhoneCtrl, 'Phone', 'e.g. +1 555 0100', Icons.phone_outlined, keyboard: TextInputType.phone, required: true),
            const SizedBox(height: 24),

            _section('Pickup Location', Icons.my_location_rounded),
            const SizedBox(height: 12),
            _field(_pickupAddressCtrl, 'Pickup Address', 'e.g. 123 Main St', Icons.location_on_outlined, required: true),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: _field(_pickupLatCtrl, 'Latitude', '0.0', null, keyboard: const TextInputType.numberWithOptions(decimal: true, signed: true))),
              const SizedBox(width: 12),
              Expanded(child: _field(_pickupLngCtrl, 'Longitude', '0.0', null, keyboard: const TextInputType.numberWithOptions(decimal: true, signed: true))),
            ]),
            const SizedBox(height: 24),

            _section('Drop-off Location', Icons.flag_rounded),
            const SizedBox(height: 12),
            _field(_dropoffAddressCtrl, 'Drop-off Address', 'e.g. 456 Oak Ave', Icons.location_on_rounded, required: true),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: _field(_dropoffLatCtrl, 'Latitude', '0.0', null, keyboard: const TextInputType.numberWithOptions(decimal: true, signed: true))),
              const SizedBox(width: 12),
              Expanded(child: _field(_dropoffLngCtrl, 'Longitude', '0.0', null, keyboard: const TextInputType.numberWithOptions(decimal: true, signed: true))),
            ]),
            const SizedBox(height: 24),

            _section('Trip Details', Icons.receipt_long_rounded),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: _field(_fareCtrl, 'Fare (\$)', '0.00', Icons.attach_money_rounded, keyboard: const TextInputType.numberWithOptions(decimal: true), required: true)),
              const SizedBox(width: 12),
              Expanded(child: _field(_distanceCtrl, 'Distance (km)', '0.0', Icons.straighten_rounded, keyboard: const TextInputType.numberWithOptions(decimal: true))),
            ]),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: _field(_durationCtrl, 'Duration (min)', '0', Icons.timer_rounded, keyboard: TextInputType.number)),
              const SizedBox(width: 12),
              Expanded(child: DropdownButtonFormField<String>(
                initialValue: _paymentMethod,
                decoration: const InputDecoration(labelText: 'Payment', prefixIcon: Icon(Icons.payment_rounded)),
                dropdownColor: AppColors.surfaceHigh,
                style: const TextStyle(color: AppColors.textPrimary),
                items: const [
                  DropdownMenuItem(value: 'cash', child: Text('Cash')),
                  DropdownMenuItem(value: 'card', child: Text('Card')),
                  DropdownMenuItem(value: 'transfer', child: Text('Transfer')),
                ],
                onChanged: (v) => setState(() => _paymentMethod = v!),
              )),
            ]),
            const SizedBox(height: 32),
            SizedBox(height: 54, child: ElevatedButton.icon(
              onPressed: _isLoading ? null : _create,
              icon: _isLoading ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.5, color: Color(0xFF08090C))) : const Icon(Icons.add_rounded, size: 20),
              label: Text(_isLoading ? 'Creating...' : 'Create Trip', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            )),
          ]),
        ),
      ),
    );
  }

  Widget _section(String title, IconData icon) {
    return Row(children: [
      Container(padding: const EdgeInsets.all(6), decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8)), child: Icon(icon, size: 16, color: AppColors.primary)),
      const SizedBox(width: 10),
      Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
    ]);
  }

  Widget _field(TextEditingController ctrl, String label, String hint, IconData? icon, {TextInputType? keyboard, bool required = false}) {
    return TextFormField(
      controller: ctrl,
      keyboardType: keyboard,
      style: const TextStyle(color: AppColors.textPrimary),
      decoration: InputDecoration(labelText: label, hintText: hint, prefixIcon: icon != null ? Icon(icon) : null),
      validator: required ? (v) => (v == null || v.isEmpty) ? 'Required' : null : null,
    );
  }
}
