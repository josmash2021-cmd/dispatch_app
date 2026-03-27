import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/app_theme.dart';
import '../providers/pricing_provider.dart';

class PricingConfigScreen extends StatefulWidget {
  const PricingConfigScreen({super.key});

  @override
  State<PricingConfigScreen> createState() => _PricingConfigScreenState();
}

class _PricingConfigScreenState extends State<PricingConfigScreen> {
  final _baseFareCtrl = TextEditingController();
  final _perMileCtrl = TextEditingController();
  final _perMinuteCtrl = TextEditingController();
  final _minimumFareCtrl = TextEditingController();
  final _airportFeeCtrl = TextEditingController();
  final _bookingFeeCtrl = TextEditingController();
  final _surgeCtrl = TextEditingController();

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadPricing();
  }

  @override
  void dispose() {
    _baseFareCtrl.dispose();
    _perMileCtrl.dispose();
    _perMinuteCtrl.dispose();
    _minimumFareCtrl.dispose();
    _airportFeeCtrl.dispose();
    _bookingFeeCtrl.dispose();
    _surgeCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadPricing() async {
    final provider = context.read<PricingProvider>();
    await provider.loadPricingConfig();
    
    if (provider.pricingConfig != null) {
      setState(() {
        _baseFareCtrl.text = provider.baseFare?.toString() ?? '';
        _perMileCtrl.text = provider.perMileRate?.toString() ?? '';
        _perMinuteCtrl.text = provider.perMinuteRate?.toString() ?? '';
        _minimumFareCtrl.text = provider.minimumFare?.toString() ?? '';
        _airportFeeCtrl.text = provider.airportFee?.toString() ?? '';
        _bookingFeeCtrl.text = provider.bookingFee?.toString() ?? '';
        _surgeCtrl.text = provider.surgeMultiplier?.toString() ?? '1.0';
      });
    }
  }

  Future<void> _savePricing() async {
    setState(() => _isLoading = true);
    
    final provider = context.read<PricingProvider>();
    final success = await provider.updatePricing(
      baseFare: double.tryParse(_baseFareCtrl.text),
      perMileRate: double.tryParse(_perMileCtrl.text),
      perMinuteRate: double.tryParse(_perMinuteCtrl.text),
      minimumFare: double.tryParse(_minimumFareCtrl.text),
      airportFee: double.tryParse(_airportFeeCtrl.text),
      bookingFee: double.tryParse(_bookingFeeCtrl.text),
      surgeMultiplier: double.tryParse(_surgeCtrl.text),
    );

    setState(() => _isLoading = false);

    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: AppColors.success,
          content: Text('Pricing configuration updated successfully'),
        ),
      );
    }
  }

  void _applySurge(double multiplier) {
    setState(() {
      _surgeCtrl.text = multiplier.toString();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppColors.primary),
          onPressed: () => Navigator.pop(context),
        ),
        elevation: 0,
        title: const Text(
          'Pricing Configuration',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
        actions: [
          TextButton.icon(
            onPressed: _isLoading ? null : _loadPricing,
            icon: const Icon(Icons.refresh, size: 18),
            label: const Text('Reload'),
          ),
        ],
      ),
      body: Consumer<PricingProvider>(
        builder: (context, provider, _) {
          if (provider.isLoading && provider.pricingConfig == null) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            );
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Current status card
                _buildStatusCard(provider),
                const SizedBox(height: 20),
                // Quick surge buttons
                _buildSurgeSection(),
                const SizedBox(height: 24),
                // Pricing form
                _buildPricingForm(),
                const SizedBox(height: 24),
                // Save button
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _isLoading || provider.isLoading ? null : _savePricing,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _isLoading || provider.isLoading
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.black,
                            ),
                          )
                        : const Text(
                            'Save Changes',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                  ),
                ),
                if (provider.errorMessage != null) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.error.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.error_outline, color: AppColors.error, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            provider.errorMessage!,
                            style: TextStyle(color: AppColors.error, fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                if (provider.successMessage != null) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.success.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.check_circle, color: AppColors.success, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            provider.successMessage!,
                            style: TextStyle(color: AppColors.success, fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildStatusCard(PricingProvider provider) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primary.withValues(alpha: 0.2),
            AppColors.primary.withValues(alpha: 0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.local_offer,
                  color: AppColors.primary,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Current Pricing',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildPriceStat(
                  'Base Fare',
                  '\$${provider.baseFare?.toStringAsFixed(2) ?? '--'}',
                ),
              ),
              Expanded(
                child: _buildPriceStat(
                  'Per Mile',
                  '\$${provider.perMileRate?.toStringAsFixed(2) ?? '--'}',
                ),
              ),
              Expanded(
                child: _buildPriceStat(
                  'Per Min',
                  '\$${provider.perMinuteRate?.toStringAsFixed(2) ?? '--'}',
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildPriceStat(
                  'Minimum',
                  '\$${provider.minimumFare?.toStringAsFixed(2) ?? '--'}',
                ),
              ),
              Expanded(
                child: _buildPriceStat(
                  'Surge',
                  '${provider.surgeMultiplier?.toStringAsFixed(1) ?? '1.0'}x',
                  valueColor: (provider.surgeMultiplier ?? 1.0) > 1.0
                      ? AppColors.warning
                      : AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPriceStat(String label, String value, {Color? valueColor}) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            color: valueColor ?? AppColors.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 11,
          ),
        ),
      ],
    );
  }

  Widget _buildSurgeSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Quick Surge Multiplier',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Apply emergency pricing during high demand periods',
          style: TextStyle(
            color: AppColors.textSecondary,
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            _buildSurgeButton('Normal', 1.0, AppColors.success),
            const SizedBox(width: 8),
            _buildSurgeButton('1.5x', 1.5, AppColors.warning),
            const SizedBox(width: 8),
            _buildSurgeButton('2.0x', 2.0, AppColors.error),
            const SizedBox(width: 8),
            _buildSurgeButton('3.0x', 3.0, AppColors.primary),
          ],
        ),
      ],
    );
  }

  Widget _buildSurgeButton(String label, double multiplier, Color color) {
    final isSelected = double.tryParse(_surgeCtrl.text) == multiplier;
    return Expanded(
      child: GestureDetector(
        onTap: () => _applySurge(multiplier),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? color.withValues(alpha: 0.2) : AppColors.surface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected ? color : AppColors.cardBorder,
            ),
          ),
          child: Column(
            children: [
              Text(
                label,
                style: TextStyle(
                  color: isSelected ? color : AppColors.textPrimary,
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                ),
              ),
              if (isSelected)
                Container(
                  margin: const EdgeInsets.only(top: 4),
                  width: 4,
                  height: 4,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPricingForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Pricing Details',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 16),
        _buildPriceField(
          controller: _baseFareCtrl,
          label: 'Base Fare',
          hint: 'Starting fare for every trip',
          icon: Icons.attach_money,
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildPriceField(
                controller: _perMileCtrl,
                label: 'Per Mile Rate',
                hint: 'Cost per mile',
                icon: Icons.route,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildPriceField(
                controller: _perMinuteCtrl,
                label: 'Per Minute Rate',
                hint: 'Cost per minute',
                icon: Icons.timer,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _buildPriceField(
          controller: _minimumFareCtrl,
          label: 'Minimum Fare',
          hint: 'Lowest possible fare',
          icon: Icons.trending_down,
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildPriceField(
                controller: _airportFeeCtrl,
                label: 'Airport Fee',
                hint: 'Additional airport charge',
                icon: Icons.local_airport,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildPriceField(
                controller: _bookingFeeCtrl,
                label: 'Booking Fee',
                hint: 'Service fee per ride',
                icon: Icons.confirmation_number,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _buildPriceField(
          controller: _surgeCtrl,
          label: 'Surge Multiplier',
          hint: 'Current demand multiplier (1.0 = normal)',
          icon: Icons.trending_up,
          suffix: 'x',
        ),
      ],
    );
  }

  Widget _buildPriceField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    String? suffix,
  }) {
    return TextField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      style: const TextStyle(color: AppColors.textPrimary),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        labelStyle: const TextStyle(color: AppColors.textSecondary),
        hintStyle: TextStyle(color: AppColors.textHint.withValues(alpha: 0.5)),
        prefixIcon: Icon(icon, color: AppColors.textHint, size: 20),
        suffixText: suffix,
        suffixStyle: const TextStyle(
          color: AppColors.primary,
          fontWeight: FontWeight.w700,
        ),
        filled: true,
        fillColor: AppColors.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: AppColors.cardBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
      ),
    );
  }
}
