import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../config/app_theme.dart';

/// Admin configuration screen for managing tariffs, surge pricing,
/// cancellation policies, and service zones.
/// All config is stored in Firestore `config` collection for real-time sync.
class AdminConfigScreen extends StatefulWidget {
  const AdminConfigScreen({super.key});

  @override
  State<AdminConfigScreen> createState() => _AdminConfigScreenState();
}

class _AdminConfigScreenState extends State<AdminConfigScreen> {
  final _db = FirebaseFirestore.instance;
  bool _loading = true;

  // Tariff config
  double _baseFare = 2.50;
  double _perMile = 1.50;
  double _perMinute = 0.25;
  double _minimumFare = 5.00;

  // Vehicle multipliers
  double _fusionMultiplier = 1.0;
  double _camryMultiplier = 1.35;
  double _suburbanMultiplier = 2.20;

  // Surge config
  double _nightMultiplier = 1.25;
  double _holidayMultiplier = 1.35;
  int _nightStartHour = 23;
  int _nightEndHour = 6;

  // Cancellation config
  int _freeCancelMinutes = 3;
  double _cancelFee = 5.00;
  double _noShowFee = 10.00;
  int _maxWaitMinutes = 10;

  // Driver hourly earnings config
  double _driverHourlyRate = 15.00;
  double _driverMinimumHourly = 12.00;
  double _driverPeakHourly = 25.00;
  int _peakStartHour = 17;
  int _peakEndHour = 20;

  // App mode/state
  String _appMode = 'production'; // 'production', 'maintenance', 'beta'
  bool _acceptingNewTrips = true;
  bool _driverRegistrationOpen = true;
  bool _riderRegistrationOpen = true;

  // Service zones — active US states
  Set<String> _activeStates = {};
  final _stateSearchCtrl = TextEditingController();
  String _stateFilter = '';

  @override
  void initState() {
    super.initState();
    _loadConfig();
  }

  Future<void> _loadConfig() async {
    try {
      final doc = await _db.collection('config').doc('pricing').get();
      if (doc.exists) {
        final d = doc.data()!;
        setState(() {
          _baseFare = (d['base_fare'] as num?)?.toDouble() ?? _baseFare;
          _perMile = (d['per_mile'] as num?)?.toDouble() ?? _perMile;
          _perMinute = (d['per_minute'] as num?)?.toDouble() ?? _perMinute;
          _minimumFare =
              (d['minimum_fare'] as num?)?.toDouble() ?? _minimumFare;
          _fusionMultiplier =
              (d['fusion_multiplier'] as num?)?.toDouble() ?? _fusionMultiplier;
          _camryMultiplier =
              (d['camry_multiplier'] as num?)?.toDouble() ?? _camryMultiplier;
          _suburbanMultiplier =
              (d['suburban_multiplier'] as num?)?.toDouble() ??
              _suburbanMultiplier;
          _nightMultiplier =
              (d['night_multiplier'] as num?)?.toDouble() ?? _nightMultiplier;
          _holidayMultiplier =
              (d['holiday_multiplier'] as num?)?.toDouble() ??
              _holidayMultiplier;
          _nightStartHour =
              (d['night_start_hour'] as num?)?.toInt() ?? _nightStartHour;
          _nightEndHour =
              (d['night_end_hour'] as num?)?.toInt() ?? _nightEndHour;
          _freeCancelMinutes =
              (d['free_cancel_minutes'] as num?)?.toInt() ?? _freeCancelMinutes;
          _cancelFee = (d['cancel_fee'] as num?)?.toDouble() ?? _cancelFee;
          _noShowFee = (d['no_show_fee'] as num?)?.toDouble() ?? _noShowFee;
          _maxWaitMinutes =
              (d['max_wait_minutes'] as num?)?.toInt() ?? _maxWaitMinutes;
          // Driver earnings
          _driverHourlyRate =
              (d['driver_hourly_rate'] as num?)?.toDouble() ?? _driverHourlyRate;
          _driverMinimumHourly =
              (d['driver_minimum_hourly'] as num?)?.toDouble() ?? _driverMinimumHourly;
          _driverPeakHourly =
              (d['driver_peak_hourly'] as num?)?.toDouble() ?? _driverPeakHourly;
          _peakStartHour =
              (d['peak_start_hour'] as num?)?.toInt() ?? _peakStartHour;
          _peakEndHour =
              (d['peak_end_hour'] as num?)?.toInt() ?? _peakEndHour;
        });
      }

      final appConfigSnap = await _db.collection('config').doc('app').get();
      if (appConfigSnap.exists) {
        final d = appConfigSnap.data()!;
        setState(() {
          _appMode = d['app_mode'] as String? ?? _appMode;
          _acceptingNewTrips = d['accepting_new_trips'] as bool? ?? _acceptingNewTrips;
          _driverRegistrationOpen = d['driver_registration_open'] as bool? ?? _driverRegistrationOpen;
          _riderRegistrationOpen = d['rider_registration_open'] as bool? ?? _riderRegistrationOpen;
        });
      }

      final zonesSnap = await _db
          .collection('config')
          .doc('serviceZones')
          .get();
      if (zonesSnap.exists) {
        final states =
            (zonesSnap.data()?['activeStates'] as List<dynamic>? ?? [])
                .map((s) => s.toString())
                .toSet();
        setState(() => _activeStates = states);
      }
    } catch (e) {
      debugPrint('Error loading config: $e');
    }
    setState(() => _loading = false);
  }

  Future<void> _saveConfig() async {
    try {
      await _db.collection('config').doc('pricing').set({
        'base_fare': _baseFare,
        'per_mile': _perMile,
        'per_minute': _perMinute,
        'minimum_fare': _minimumFare,
        'fusion_multiplier': _fusionMultiplier,
        'camry_multiplier': _camryMultiplier,
        'suburban_multiplier': _suburbanMultiplier,
        'night_multiplier': _nightMultiplier,
        'holiday_multiplier': _holidayMultiplier,
        'night_start_hour': _nightStartHour,
        'night_end_hour': _nightEndHour,
        'free_cancel_minutes': _freeCancelMinutes,
        'cancel_fee': _cancelFee,
        'no_show_fee': _noShowFee,
        'max_wait_minutes': _maxWaitMinutes,
        'driver_hourly_rate': _driverHourlyRate,
        'driver_minimum_hourly': _driverMinimumHourly,
        'driver_peak_hourly': _driverPeakHourly,
        'peak_start_hour': _peakStartHour,
        'peak_end_hour': _peakEndHour,
        'updated_at': FieldValue.serverTimestamp(),
      });

      await _db.collection('config').doc('app').set({
        'app_mode': _appMode,
        'accepting_new_trips': _acceptingNewTrips,
        'driver_registration_open': _driverRegistrationOpen,
        'rider_registration_open': _riderRegistrationOpen,
        'updated_at': FieldValue.serverTimestamp(),
      });

      await _db.collection('config').doc('serviceZones').set({
        'activeStates': _activeStates.toList(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Configuration saved'),
            backgroundColor: AppColors.primary,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving: $e'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
          ),
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
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppColors.primary),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Admin Configuration'),
        actions: [
          TextButton.icon(
            onPressed: _saveConfig,
            icon: const Icon(Icons.save_rounded, size: 18),
            label: const Text('Save'),
            style: TextButton.styleFrom(foregroundColor: AppColors.primary),
          ),
        ],
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _sectionHeader('Base Tariff', Icons.attach_money),
                  _configCard([
                    _sliderRow(
                      'Base fare',
                      _baseFare,
                      0,
                      10,
                      (v) => setState(() => _baseFare = v),
                      prefix: '\$',
                    ),
                    _sliderRow(
                      'Per mile',
                      _perMile,
                      0,
                      5,
                      (v) => setState(() => _perMile = v),
                      prefix: '\$',
                    ),
                    _sliderRow(
                      'Per minute',
                      _perMinute,
                      0,
                      2,
                      (v) => setState(() => _perMinute = v),
                      prefix: '\$',
                    ),
                    _sliderRow(
                      'Minimum fare',
                      _minimumFare,
                      0,
                      20,
                      (v) => setState(() => _minimumFare = v),
                      prefix: '\$',
                    ),
                  ]),

                  const SizedBox(height: 20),
                  _sectionHeader('Vehicle Multipliers', Icons.directions_car),
                  _configCard([
                    _sliderRow(
                      'Fusion',
                      _fusionMultiplier,
                      0.5,
                      3,
                      (v) => setState(() => _fusionMultiplier = v),
                      suffix: 'x',
                    ),
                    _sliderRow(
                      'Camry',
                      _camryMultiplier,
                      0.5,
                      3,
                      (v) => setState(() => _camryMultiplier = v),
                      suffix: 'x',
                    ),
                    _sliderRow(
                      'Suburban',
                      _suburbanMultiplier,
                      0.5,
                      5,
                      (v) => setState(() => _suburbanMultiplier = v),
                      suffix: 'x',
                    ),
                  ]),

                  const SizedBox(height: 20),
                  _sectionHeader('Surge Pricing', Icons.trending_up),
                  _configCard([
                    _sliderRow(
                      'Night multiplier',
                      _nightMultiplier,
                      1,
                      3,
                      (v) => setState(() => _nightMultiplier = v),
                      suffix: 'x',
                    ),
                    _sliderRow(
                      'Holiday multiplier',
                      _holidayMultiplier,
                      1,
                      3,
                      (v) => setState(() => _holidayMultiplier = v),
                      suffix: 'x',
                    ),
                    _intSliderRow(
                      'Night starts at',
                      _nightStartHour,
                      18,
                      23,
                      (v) => setState(() => _nightStartHour = v),
                      suffix: ':00',
                    ),
                    _intSliderRow(
                      'Night ends at',
                      _nightEndHour,
                      4,
                      8,
                      (v) => setState(() => _nightEndHour = v),
                      suffix: ':00',
                    ),
                  ]),

                  const SizedBox(height: 20),
                  _sectionHeader('Cancellation Policy', Icons.cancel_outlined),
                  _configCard([
                    _intSliderRow(
                      'Free cancel window',
                      _freeCancelMinutes,
                      1,
                      10,
                      (v) => setState(() => _freeCancelMinutes = v),
                      suffix: ' min',
                    ),
                    _sliderRow(
                      'Cancel fee',
                      _cancelFee,
                      0,
                      25,
                      (v) => setState(() => _cancelFee = v),
                      prefix: '\$',
                    ),
                    _sliderRow(
                      'No-show fee',
                      _noShowFee,
                      0,
                      50,
                      (v) => setState(() => _noShowFee = v),
                      prefix: '\$',
                    ),
                    _intSliderRow(
                      'Max driver wait',
                      _maxWaitMinutes,
                      5,
                      20,
                      (v) => setState(() => _maxWaitMinutes = v),
                      suffix: ' min',
                    ),
                  ]),

                  const SizedBox(height: 20),
                  _sectionHeader('Driver Earnings (Hourly)', Icons.access_time),
                  _configCard([
                    _sliderRow(
                      'Standard rate',
                      _driverHourlyRate,
                      5,
                      50,
                      (v) => setState(() => _driverHourlyRate = v),
                      prefix: '\$',
                      suffix: '/hr',
                    ),
                    _sliderRow(
                      'Minimum hourly',
                      _driverMinimumHourly,
                      5,
                      30,
                      (v) => setState(() => _driverMinimumHourly = v),
                      prefix: '\$',
                      suffix: '/hr',
                    ),
                    _sliderRow(
                      'Peak hour rate',
                      _driverPeakHourly,
                      10,
                      60,
                      (v) => setState(() => _driverPeakHourly = v),
                      prefix: '\$',
                      suffix: '/hr',
                    ),
                    _intSliderRow(
                      'Peak starts at',
                      _peakStartHour,
                      16,
                      20,
                      (v) => setState(() => _peakStartHour = v),
                      suffix: ':00',
                    ),
                    _intSliderRow(
                      'Peak ends at',
                      _peakEndHour,
                      18,
                      23,
                      (v) => setState(() => _peakEndHour = v),
                      suffix: ':00',
                    ),
                  ]),

                  const SizedBox(height: 20),
                  _sectionHeader('App Mode & Status', Icons.settings_applications),
                  _buildAppModeSection(),

                  const SizedBox(height: 20),
                  _sectionHeader(
                    'Service Zones — Active States',
                    Icons.map_outlined,
                  ),
                  _buildServiceZonesSection(),

                  const SizedBox(height: 40),

                  // Fare preview
                  _sectionHeader(
                    'Fare Preview (10 mi, 20 min)',
                    Icons.calculate,
                  ),
                  _configCard([
                    _farePreview(
                      'Fusion',
                      _baseFare + (10 * _perMile) + (20 * _perMinute),
                      _fusionMultiplier,
                    ),
                    _farePreview(
                      'Camry',
                      _baseFare + (10 * _perMile) + (20 * _perMinute),
                      _camryMultiplier,
                    ),
                    _farePreview(
                      'Suburban',
                      _baseFare + (10 * _perMile) + (20 * _perMinute),
                      _suburbanMultiplier,
                    ),
                  ]),

                  const SizedBox(height: 40),
                ],
              ),
            ),
    );
  }

  Widget _sectionHeader(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Icon(icon, color: AppColors.primary, size: 20),
          const SizedBox(width: 8),
          Text(
            title,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _configCard(List<Widget> children) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(children: children),
    );
  }

  Widget _sliderRow(
    String label,
    double value,
    double min,
    double max,
    ValueChanged<double> onChanged, {
    String prefix = '',
    String suffix = '',
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
              ),
            ),
          ),
          Expanded(
            child: Slider(
              value: value.clamp(min, max),
              min: min,
              max: max,
              divisions: ((max - min) * 20).round().clamp(1, 200),
              activeColor: AppColors.primary,
              inactiveColor: AppColors.surfaceHigh,
              onChanged: onChanged,
            ),
          ),
          SizedBox(
            width: 60,
            child: Text(
              '$prefix${value.toStringAsFixed(2)}$suffix',
              style: const TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }

  Widget _intSliderRow(
    String label,
    int value,
    int min,
    int max,
    ValueChanged<int> onChanged, {
    String suffix = '',
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
              ),
            ),
          ),
          Expanded(
            child: Slider(
              value: value.toDouble().clamp(min.toDouble(), max.toDouble()),
              min: min.toDouble(),
              max: max.toDouble(),
              divisions: max - min,
              activeColor: AppColors.primary,
              inactiveColor: AppColors.surfaceHigh,
              onChanged: (v) => onChanged(v.round()),
            ),
          ),
          SizedBox(
            width: 60,
            child: Text(
              '$value$suffix',
              style: const TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }

  Widget _farePreview(String name, double baseFare, double multiplier) {
    final fare = baseFare * multiplier;
    final withNight = fare * _nightMultiplier;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            child: Text(
              name,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const Spacer(),
          Text(
            '\$${fare.toStringAsFixed(2)}',
            style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
          ),
          const SizedBox(width: 16),
          Text(
            'Night: \$${withNight.toStringAsFixed(2)}',
            style: TextStyle(
              color: AppColors.primary.withValues(alpha: 0.7),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppModeSection() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // App Mode Selector
          Text(
            'Application Mode',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _modeButton('Production', 'production', Icons.check_circle),
              const SizedBox(width: 8),
              _modeButton('Maintenance', 'maintenance', Icons.build),
              const SizedBox(width: 8),
              _modeButton('Beta', 'beta', Icons.science),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(color: AppColors.cardBorder),
          const SizedBox(height: 16),
          // Toggle switches for app functions
          _toggleRow(
            'Accepting New Trips',
            _acceptingNewTrips,
            (v) => setState(() => _acceptingNewTrips = v),
            Icons.local_taxi,
          ),
          const SizedBox(height: 12),
          _toggleRow(
            'Driver Registration Open',
            _driverRegistrationOpen,
            (v) => setState(() => _driverRegistrationOpen = v),
            Icons.person_add,
          ),
          const SizedBox(height: 12),
          _toggleRow(
            'Rider Registration Open',
            _riderRegistrationOpen,
            (v) => setState(() => _riderRegistrationOpen = v),
            Icons.person_add_alt,
          ),
        ],
      ),
    );
  }

  Widget _modeButton(String label, String mode, IconData icon) {
    final isSelected = _appMode == mode;
    final color = mode == 'production'
        ? AppColors.success
        : mode == 'maintenance'
            ? AppColors.warning
            : AppColors.primary;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _appMode = mode),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          decoration: BoxDecoration(
            color: isSelected ? color.withOpacity(0.15) : AppColors.surfaceHigh,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected ? color : AppColors.cardBorder,
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Column(
            children: [
              Icon(
                icon,
                color: isSelected ? color : AppColors.textHint,
                size: 24,
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  color: isSelected ? color : AppColors.textSecondary,
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _toggleRow(
    String label,
    bool value,
    ValueChanged<bool> onChanged,
    IconData icon,
  ) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppColors.surfaceHigh,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: AppColors.primary, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 14,
            ),
          ),
        ),
        Switch(
          value: value,
          onChanged: onChanged,
          activeColor: AppColors.primary,
          inactiveThumbColor: AppColors.textHint,
          inactiveTrackColor: AppColors.surfaceHigh,
        ),
      ],
    );
  }

  Widget _buildServiceZonesSection() {
    final filtered = _stateFilter.isEmpty
        ? _kUsStates
        : _kUsStates
              .where(
                (s) => s.toLowerCase().contains(_stateFilter.toLowerCase()),
              )
              .toList();
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Active count badge + clear button
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${_activeStates.length} state${_activeStates.length == 1 ? '' : 's'} active',
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const Spacer(),
              if (_activeStates.isNotEmpty)
                TextButton(
                  onPressed: () => setState(() => _activeStates = {}),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.error,
                    padding: EdgeInsets.zero,
                  ),
                  child: const Text(
                    'Clear all',
                    style: TextStyle(fontSize: 12),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          // Search field
          TextField(
            controller: _stateSearchCtrl,
            onChanged: (v) => setState(() => _stateFilter = v),
            style: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
            decoration: InputDecoration(
              hintText: 'Search state...',
              hintStyle: TextStyle(
                color: AppColors.textSecondary.withValues(alpha: 0.5),
                fontSize: 13,
              ),
              prefixIcon: const Icon(
                Icons.search,
                color: AppColors.textSecondary,
                size: 18,
              ),
              filled: true,
              fillColor: AppColors.surfaceHigh,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(vertical: 8),
              isDense: true,
            ),
          ),
          const SizedBox(height: 12),
          // State chips
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: filtered.map((state) {
              final active = _activeStates.contains(state);
              return GestureDetector(
                onTap: () => setState(() {
                  if (active) {
                    _activeStates = {..._activeStates}..remove(state);
                  } else {
                    _activeStates = {..._activeStates, state};
                  }
                }),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: active ? AppColors.primary : AppColors.surfaceHigh,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: active ? AppColors.primary : AppColors.cardBorder,
                    ),
                  ),
                  child: Text(
                    state,
                    style: TextStyle(
                      color: active ? Colors.black : AppColors.textSecondary,
                      fontSize: 12,
                      fontWeight: active ? FontWeight.w700 : FontWeight.w400,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _stateSearchCtrl.dispose();
    super.dispose();
  }
}

const _kUsStates = [
  'Alabama',
  'Alaska',
  'Arizona',
  'Arkansas',
  'California',
  'Colorado',
  'Connecticut',
  'Delaware',
  'Florida',
  'Georgia',
  'Hawaii',
  'Idaho',
  'Illinois',
  'Indiana',
  'Iowa',
  'Kansas',
  'Kentucky',
  'Louisiana',
  'Maine',
  'Maryland',
  'Massachusetts',
  'Michigan',
  'Minnesota',
  'Mississippi',
  'Missouri',
  'Montana',
  'Nebraska',
  'Nevada',
  'New Hampshire',
  'New Jersey',
  'New Mexico',
  'New York',
  'North Carolina',
  'North Dakota',
  'Ohio',
  'Oklahoma',
  'Oregon',
  'Pennsylvania',
  'Rhode Island',
  'South Carolina',
  'South Dakota',
  'Tennessee',
  'Texas',
  'Utah',
  'Vermont',
  'Virginia',
  'Washington',
  'West Virginia',
  'Wisconsin',
  'Wyoming',
];
