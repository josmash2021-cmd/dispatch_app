import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../config/app_theme.dart';
import '../models/driver_model.dart';
import '../models/trip_model.dart';

/// Live fleet map showing all online drivers and active trips.
/// Dispatchers can tap a driver to see info or assign them to a pending trip.
class FleetMapScreen extends StatefulWidget {
  const FleetMapScreen({super.key});

  @override
  State<FleetMapScreen> createState() => _FleetMapScreenState();
}

class _FleetMapScreenState extends State<FleetMapScreen> {
  GoogleMapController? _mapCtrl;
  final Set<Marker> _markers = {};
  final Set<Circle> _circles = {};

  // Data
  List<_DriverPin> _driverPins = [];
  List<TripModel> _activeTrips = [];
  StreamSubscription? _driverSub;
  StreamSubscription? _tripSub;

  // Selected driver for info panel
  _DriverPin? _selectedDriver;

  // Filter
  bool _showOnlineOnly = true;

  static const _miamiCenter = LatLng(25.7617, -80.1918);

  @override
  void initState() {
    super.initState();
    _listenDriverLocations();
    _listenActiveTrips();
  }

  @override
  void dispose() {
    _driverSub?.cancel();
    _tripSub?.cancel();
    _mapCtrl?.dispose();
    super.dispose();
  }

  /// Listen to drivers collection for live locations
  void _listenDriverLocations() {
    _driverSub = FirebaseFirestore.instance
        .collection('drivers')
        .snapshots()
        .listen((snap) {
      final pins = <_DriverPin>[];
      for (final doc in snap.docs) {
        final data = doc.data();
        final lat = (data['lat'] as num?)?.toDouble() ??
            (data['latitude'] as num?)?.toDouble();
        final lng = (data['lng'] as num?)?.toDouble() ??
            (data['longitude'] as num?)?.toDouble();
        if (lat == null || lng == null) continue;

        final driver = DriverModel.fromFirestore(doc);
        pins.add(_DriverPin(
          driver: driver,
          position: LatLng(lat, lng),
          bearing: (data['bearing'] as num?)?.toDouble() ?? 0,
        ));
      }
      setState(() {
        _driverPins = pins;
        _rebuildMarkers();
      });
    });
  }

  /// Listen to active trips for pickup/dropoff markers
  void _listenActiveTrips() {
    _tripSub = FirebaseFirestore.instance
        .collection('trips')
        .where('status', whereIn: ['requested', 'accepted', 'driver_arrived', 'in_progress'])
        .snapshots()
        .listen((snap) {
      setState(() {
        _activeTrips = snap.docs.map((d) => TripModel.fromFirestore(d)).toList();
        _rebuildMarkers();
      });
    });
  }

  void _rebuildMarkers() {
    _markers.clear();
    _circles.clear();

    // Driver markers
    final displayDrivers = _showOnlineOnly
        ? _driverPins.where((d) => d.driver.isOnline).toList()
        : _driverPins;

    for (final dp in displayDrivers) {
      final isOnline = dp.driver.isOnline;
      _markers.add(Marker(
        markerId: MarkerId('driver_${dp.driver.driverId}'),
        position: dp.position,
        rotation: dp.bearing,
        icon: BitmapDescriptor.defaultMarkerWithHue(
          isOnline ? BitmapDescriptor.hueGreen : BitmapDescriptor.hueRed,
        ),
        infoWindow: InfoWindow(
          title: dp.driver.fullName,
          snippet: '${dp.driver.vehicleType ?? 'Vehicle'} · ${dp.driver.vehiclePlate ?? ''}',
        ),
        onTap: () => setState(() => _selectedDriver = dp),
      ));
    }

    // Trip markers (pickup = gold, dropoff = red)
    for (final trip in _activeTrips) {
      if (trip.pickupLat != 0 && trip.pickupLng != 0) {
        _markers.add(Marker(
          markerId: MarkerId('pickup_${trip.tripId}'),
          position: LatLng(trip.pickupLat, trip.pickupLng),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange),
          infoWindow: InfoWindow(
            title: 'Pickup: ${trip.passengerName}',
            snippet: trip.pickupAddress,
          ),
        ));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final onlineCount = _driverPins.where((d) => d.driver.isOnline).length;
    final offlineCount = _driverPins.length - onlineCount;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          // Google Map
          GoogleMap(
            initialCameraPosition: const CameraPosition(
              target: _miamiCenter,
              zoom: 11,
            ),
            markers: _markers,
            circles: _circles,
            myLocationEnabled: false,
            zoomControlsEnabled: false,
            mapToolbarEnabled: false,
            style: _darkMapStyle,
            onMapCreated: (ctrl) => _mapCtrl = ctrl,
            onTap: (_) => setState(() => _selectedDriver = null),
          ),

          // Top bar with stats
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            left: 12,
            right: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.surface.withValues(alpha: 0.95),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.cardBorder),
              ),
              child: Row(
                children: [
                  const Icon(Icons.map_rounded, color: AppColors.primary, size: 22),
                  const SizedBox(width: 10),
                  const Text(
                    'Fleet Map',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Spacer(),
                  _statChip(Icons.circle, AppColors.success, '$onlineCount online'),
                  const SizedBox(width: 8),
                  _statChip(Icons.circle, AppColors.error, '$offlineCount offline'),
                  const SizedBox(width: 8),
                  _statChip(Icons.local_taxi, AppColors.primary, '${_activeTrips.length} trips'),
                ],
              ),
            ),
          ),

          // Filter toggle
          Positioned(
            top: MediaQuery.of(context).padding.top + 70,
            right: 12,
            child: Column(
              children: [
                _mapButton(
                  icon: _showOnlineOnly ? Icons.visibility : Icons.visibility_off,
                  label: _showOnlineOnly ? 'Online' : 'All',
                  onTap: () {
                    setState(() {
                      _showOnlineOnly = !_showOnlineOnly;
                      _rebuildMarkers();
                    });
                  },
                ),
                const SizedBox(height: 8),
                _mapButton(
                  icon: Icons.my_location,
                  label: 'Center',
                  onTap: () {
                    _mapCtrl?.animateCamera(CameraUpdate.newLatLngZoom(_miamiCenter, 11));
                  },
                ),
              ],
            ),
          ),

          // Selected driver info panel
          if (_selectedDriver != null)
            Positioned(
              left: 12,
              right: 12,
              bottom: MediaQuery.of(context).padding.bottom + 12,
              child: _buildDriverInfoCard(_selectedDriver!),
            ),
        ],
      ),
    );
  }

  Widget _statChip(IconData icon, Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 8),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(color: AppColors.textSecondary, fontSize: 11, fontWeight: FontWeight.w500),
        ),
      ],
    );
  }

  Widget _mapButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.surface.withValues(alpha: 0.95),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.cardBorder),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: AppColors.primary, size: 16),
            const SizedBox(width: 6),
            Text(label, style: const TextStyle(color: AppColors.textPrimary, fontSize: 12, fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }

  Widget _buildDriverInfoCard(_DriverPin dp) {
    final d = dp.driver;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              // Avatar
              CircleAvatar(
                radius: 24,
                backgroundColor: AppColors.primary.withValues(alpha: 0.2),
                child: Text(
                  d.fullName.isNotEmpty ? d.fullName[0].toUpperCase() : '?',
                  style: const TextStyle(color: AppColors.primary, fontSize: 20, fontWeight: FontWeight.w700),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      d.fullName,
                      style: const TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${d.vehicleType ?? 'Vehicle'} · ${d.vehiclePlate ?? 'N/A'}',
                      style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                    ),
                  ],
                ),
              ),
              // Status badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: d.isOnline
                      ? AppColors.success.withValues(alpha: 0.15)
                      : AppColors.error.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  d.isOnline ? 'Online' : 'Offline',
                  style: TextStyle(
                    color: d.isOnline ? AppColors.success : AppColors.error,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          if (d.isOnline && _activeTrips.any((t) => t.status == TripStatus.requested)) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _showAssignDialog(dp),
                icon: const Icon(Icons.assignment_ind, size: 18),
                label: const Text('Assign to Trip'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.background,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  minimumSize: const Size.fromHeight(44),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Show dialog to pick which pending trip to assign to this driver
  void _showAssignDialog(_DriverPin dp) {
    final pendingTrips = _activeTrips.where((t) => t.status == TripStatus.requested).toList();
    if (pendingTrips.isEmpty) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 12),
          Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.divider, borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 16),
          Text(
            'Assign ${dp.driver.fullName} to:',
            style: const TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          ...pendingTrips.map((trip) => ListTile(
            leading: const Icon(Icons.person, color: AppColors.primary),
            title: Text(trip.passengerName, style: const TextStyle(color: AppColors.textPrimary)),
            subtitle: Text('${trip.pickupAddress} → ${trip.dropoffAddress}',
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
              maxLines: 1, overflow: TextOverflow.ellipsis,
            ),
            trailing: Text('\$${trip.fare.toStringAsFixed(2)}',
              style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600),
            ),
            onTap: () {
              Navigator.pop(ctx);
              _assignDriverToTrip(dp, trip);
            },
          )),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  /// Assign a driver to a trip in Firestore
  Future<void> _assignDriverToTrip(_DriverPin dp, TripModel trip) async {
    try {
      await FirebaseFirestore.instance.collection('trips').doc(trip.tripId).update({
        'status': 'accepted',
        'driverId': dp.driver.driverId,
        'driverName': dp.driver.fullName,
        'driverPhone': dp.driver.phone,
        'acceptedAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        setState(() => _selectedDriver = null);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${dp.driver.fullName} assigned to ${trip.passengerName}'),
            backgroundColor: AppColors.primary,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }
}

class _DriverPin {
  final DriverModel driver;
  final LatLng position;
  final double bearing;

  const _DriverPin({
    required this.driver,
    required this.position,
    this.bearing = 0,
  });
}

const String _darkMapStyle = '''
[
  {"elementType":"geometry","stylers":[{"color":"#0e0e12"}]},
  {"elementType":"labels.icon","stylers":[{"visibility":"off"}]},
  {"elementType":"labels.text.fill","stylers":[{"color":"#757575"}]},
  {"elementType":"labels.text.stroke","stylers":[{"color":"#0e0e12"}]},
  {"featureType":"administrative","elementType":"geometry","stylers":[{"color":"#1a1a24"}]},
  {"featureType":"poi","elementType":"geometry","stylers":[{"color":"#14141c"}]},
  {"featureType":"road","elementType":"geometry.fill","stylers":[{"color":"#1c1c28"}]},
  {"featureType":"road","elementType":"geometry.stroke","stylers":[{"color":"#14141c"}]},
  {"featureType":"road.highway","elementType":"geometry.fill","stylers":[{"color":"#24242e"}]},
  {"featureType":"transit","elementType":"geometry","stylers":[{"color":"#14141c"}]},
  {"featureType":"water","elementType":"geometry","stylers":[{"color":"#080810"}]}
]
''';
