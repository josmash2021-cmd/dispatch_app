import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:apple_maps_flutter/apple_maps_flutter.dart' as am;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' as gm;

import '../config/app_theme.dart';
import '../models/driver_model.dart';
import '../models/trip_model.dart';

/// Live fleet map - Apple Maps on iOS, Google Maps on Android.
class FleetMapScreen extends StatefulWidget {
  const FleetMapScreen({super.key});

  @override
  State<FleetMapScreen> createState() => _FleetMapScreenState();
}

class _FleetMapScreenState extends State<FleetMapScreen> {
  am.AppleMapController? _appleCtrl;
  gm.GoogleMapController? _googleCtrl;

  List<_DriverPin> _driverPins = [];
  List<TripModel> _activeTrips = [];
  StreamSubscription? _driverSub;
  StreamSubscription? _tripSub;

  _DriverPin? _selectedDriver;
  bool _showOnlineOnly = true;

  gm.BitmapDescriptor? _gmOnlineIcon;
  gm.BitmapDescriptor? _gmOfflineIcon;
  gm.BitmapDescriptor? _gmPickupIcon;

  static const double _miamiLat = 25.7617;
  static const double _miamiLng = -80.1918;

  @override
  void initState() {
    super.initState();
    _listenDriverLocations();
    _listenActiveTrips();
    if (!Platform.isIOS) _initGoogleMarkers();
  }

  @override
  void dispose() {
    _driverSub?.cancel();
    _tripSub?.cancel();
    _googleCtrl?.dispose();
    super.dispose();
  }

  void _listenDriverLocations() {
    _driverSub = FirebaseFirestore.instance
        .collection('drivers')
        .snapshots()
        .listen((snap) {
          final pins = <_DriverPin>[];
          for (final doc in snap.docs) {
            final data = doc.data();
            final lat =
                (data['lat'] as num?)?.toDouble() ??
                (data['latitude'] as num?)?.toDouble();
            final lng =
                (data['lng'] as num?)?.toDouble() ??
                (data['longitude'] as num?)?.toDouble();
            if (lat == null || lng == null) continue;
            pins.add(
              _DriverPin(
                driver: DriverModel.fromFirestore(doc),
                lat: lat,
                lng: lng,
                bearing: (data['bearing'] as num?)?.toDouble() ?? 0,
              ),
            );
          }
          if (mounted) setState(() => _driverPins = pins);
        });
  }

  void _listenActiveTrips() {
    _tripSub = FirebaseFirestore.instance
        .collection('trips')
        .where(
          'status',
          whereIn: ['requested', 'accepted', 'driver_arrived', 'in_progress'],
        )
        .snapshots()
        .listen((snap) {
          if (mounted) {
            setState(() {
              _activeTrips = snap.docs
                  .map((d) => TripModel.fromFirestore(d))
                  .toList();
            });
          }
        });
  }

  Future<void> _initGoogleMarkers() async {
    _gmOnlineIcon = await _carBitmap(AppColors.success);
    _gmOfflineIcon = await _carBitmap(AppColors.error);
    _gmPickupIcon = await _pickupBitmap();
    if (mounted) setState(() {});
  }

  Future<gm.BitmapDescriptor> _carBitmap(Color color) async {
    const sz = 72.0;
    final rec = ui.PictureRecorder();
    final c = Canvas(rec);
    c.drawCircle(
      const Offset(sz / 2, sz / 2),
      sz / 2 - 3,
      Paint()..color = color,
    );
    c.drawCircle(
      const Offset(sz / 2, sz / 2),
      sz / 2 - 3,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );
    final tp = TextPainter(
      text: TextSpan(
        text: String.fromCharCode(Icons.directions_car.codePoint),
        style: const TextStyle(
          fontSize: 32,
          fontFamily: 'MaterialIcons',
          color: Colors.white,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(c, Offset((sz - tp.width) / 2, (sz - tp.height) / 2));
    final img = await rec.endRecording().toImage(sz.toInt(), sz.toInt());
    final data = await img.toByteData(format: ui.ImageByteFormat.png);
    return gm.BitmapDescriptor.bytes(data!.buffer.asUint8List());
  }

  Future<gm.BitmapDescriptor> _pickupBitmap() async {
    const sz = 60.0;
    final rec = ui.PictureRecorder();
    final c = Canvas(rec);
    c.drawCircle(
      const Offset(sz / 2, sz / 2),
      sz / 2 - 3,
      Paint()..color = AppColors.primary,
    );
    c.drawCircle(
      const Offset(sz / 2, sz / 2),
      sz / 2 - 3,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );
    final tp = TextPainter(
      text: TextSpan(
        text: String.fromCharCode(Icons.location_on.codePoint),
        style: const TextStyle(
          fontSize: 28,
          fontFamily: 'MaterialIcons',
          color: Colors.white,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(c, Offset((sz - tp.width) / 2, (sz - tp.height) / 2));
    final img = await rec.endRecording().toImage(sz.toInt(), sz.toInt());
    final data = await img.toByteData(format: ui.ImageByteFormat.png);
    return gm.BitmapDescriptor.bytes(data!.buffer.asUint8List());
  }

  List<_DriverPin> get _displayDrivers => _showOnlineOnly
      ? _driverPins.where((d) => d.driver.isOnline).toList()
      : _driverPins;

  void _centerMap() {
    if (Platform.isIOS) {
      _appleCtrl?.animateCamera(
        am.CameraUpdate.newLatLngZoom(
          const am.LatLng(_miamiLat, _miamiLng),
          11,
        ),
      );
    } else {
      _googleCtrl?.animateCamera(
        gm.CameraUpdate.newLatLngZoom(
          const gm.LatLng(_miamiLat, _miamiLng),
          11,
        ),
      );
    }
  }

  Set<am.Annotation> _buildAppleAnnotations() {
    final annotations = <am.Annotation>{};
    for (final dp in _displayDrivers) {
      annotations.add(
        am.Annotation(
          annotationId: am.AnnotationId('driver_${dp.driver.driverId}'),
          position: am.LatLng(dp.lat, dp.lng),
          icon: am.BitmapDescriptor.defaultAnnotationWithHue(
            dp.driver.isOnline ? 120.0 : 0.0,
          ),
          infoWindow: am.InfoWindow(
            title: dp.driver.fullName,
            snippet:
                '${dp.driver.vehicleType ?? "Vehicle"} · ${dp.driver.vehiclePlate ?? ""}',
          ),
          onTap: () => setState(() => _selectedDriver = dp),
        ),
      );
    }
    for (final trip in _activeTrips) {
      if (trip.pickupLat != 0 && trip.pickupLng != 0) {
        annotations.add(
          am.Annotation(
            annotationId: am.AnnotationId('pickup_${trip.tripId}'),
            position: am.LatLng(trip.pickupLat, trip.pickupLng),
            icon: am.BitmapDescriptor.defaultAnnotationWithHue(45.0),
            infoWindow: am.InfoWindow(
              title: trip.passengerName,
              snippet: trip.pickupAddress,
            ),
          ),
        );
      }
    }
    return annotations;
  }

  Widget _buildAppleMap() {
    return am.AppleMap(
      initialCameraPosition: const am.CameraPosition(
        target: am.LatLng(_miamiLat, _miamiLng),
        zoom: 11,
      ),
      annotations: _buildAppleAnnotations(),
      onMapCreated: (ctrl) => setState(() => _appleCtrl = ctrl),
      onTap: (_) => setState(() => _selectedDriver = null),
      mapType: am.MapType.standard,
      myLocationEnabled: false,
      compassEnabled: true,
      zoomGesturesEnabled: true,
      scrollGesturesEnabled: true,
    );
  }

  Set<gm.Marker> _buildGoogleMapMarkers() {
    final markers = <gm.Marker>{};
    for (final dp in _displayDrivers) {
      final icon = dp.driver.isOnline
          ? (_gmOnlineIcon ??
                gm.BitmapDescriptor.defaultMarkerWithHue(
                  gm.BitmapDescriptor.hueGreen,
                ))
          : (_gmOfflineIcon ??
                gm.BitmapDescriptor.defaultMarkerWithHue(
                  gm.BitmapDescriptor.hueRed,
                ));
      markers.add(
        gm.Marker(
          markerId: gm.MarkerId('driver_${dp.driver.driverId}'),
          position: gm.LatLng(dp.lat, dp.lng),
          rotation: dp.bearing,
          icon: icon,
          flat: true,
          infoWindow: gm.InfoWindow(
            title: dp.driver.fullName,
            snippet:
                '${dp.driver.vehicleType ?? "Vehicle"} · ${dp.driver.vehiclePlate ?? ""}',
          ),
          onTap: () => setState(() => _selectedDriver = dp),
        ),
      );
    }
    for (final trip in _activeTrips) {
      if (trip.pickupLat != 0 && trip.pickupLng != 0) {
        markers.add(
          gm.Marker(
            markerId: gm.MarkerId('pickup_${trip.tripId}'),
            position: gm.LatLng(trip.pickupLat, trip.pickupLng),
            icon:
                _gmPickupIcon ??
                gm.BitmapDescriptor.defaultMarkerWithHue(
                  gm.BitmapDescriptor.hueOrange,
                ),
            infoWindow: gm.InfoWindow(
              title: trip.passengerName,
              snippet: trip.pickupAddress,
            ),
          ),
        );
      }
    }
    return markers;
  }

  Widget _buildGoogleMap() {
    return gm.GoogleMap(
      initialCameraPosition: const gm.CameraPosition(
        target: gm.LatLng(_miamiLat, _miamiLng),
        zoom: 11,
      ),
      markers: _buildGoogleMapMarkers(),
      onMapCreated: (ctrl) => setState(() => _googleCtrl = ctrl),
      onTap: (_) => setState(() => _selectedDriver = null),
      zoomControlsEnabled: false,
      mapToolbarEnabled: false,
      myLocationEnabled: false,
      style: _darkMapStyle,
    );
  }

  @override
  Widget build(BuildContext context) {
    final onlineCount = _driverPins.where((d) => d.driver.isOnline).length;
    final offlineCount = _driverPins.length - onlineCount;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          Platform.isIOS ? _buildAppleMap() : _buildGoogleMap(),
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
                  const Icon(
                    Icons.map_rounded,
                    color: AppColors.primary,
                    size: 22,
                  ),
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
                  _statChip(
                    Icons.circle,
                    AppColors.success,
                    '$onlineCount online',
                  ),
                  const SizedBox(width: 8),
                  _statChip(
                    Icons.circle,
                    AppColors.error,
                    '$offlineCount offline',
                  ),
                  const SizedBox(width: 8),
                  _statChip(
                    Icons.local_taxi,
                    AppColors.primary,
                    '${_activeTrips.length} trips',
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            top: MediaQuery.of(context).padding.top + 70,
            right: 12,
            child: Column(
              children: [
                _mapButton(
                  icon: _showOnlineOnly
                      ? Icons.visibility
                      : Icons.visibility_off,
                  label: _showOnlineOnly ? 'Online' : 'All',
                  onTap: () =>
                      setState(() => _showOnlineOnly = !_showOnlineOnly),
                ),
                const SizedBox(height: 8),
                _mapButton(
                  icon: Icons.my_location,
                  label: 'Center',
                  onTap: _centerMap,
                ),
              ],
            ),
          ),
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
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 11,
            fontWeight: FontWeight.w500,
          ),
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
            Text(
              label,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
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
              CircleAvatar(
                radius: 24,
                backgroundColor: AppColors.primary.withValues(alpha: 0.2),
                child: Text(
                  d.fullName.isNotEmpty ? d.fullName[0].toUpperCase() : '?',
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      d.fullName,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${d.vehicleType ?? "Vehicle"} · ${d.vehiclePlate ?? "N/A"}',
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
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
          if (d.isOnline &&
              _activeTrips.any((t) => t.status == TripStatus.requested)) ...[
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
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  minimumSize: const Size.fromHeight(44),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _showAssignDialog(_DriverPin dp) {
    final pending = _activeTrips
        .where((t) => t.status == TripStatus.requested)
        .toList();
    if (pending.isEmpty) return;
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
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.divider,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Assign ${dp.driver.fullName} to:',
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          ...pending.map(
            (trip) => ListTile(
              leading: const Icon(Icons.person, color: AppColors.primary),
              title: Text(
                trip.passengerName,
                style: const TextStyle(color: AppColors.textPrimary),
              ),
              subtitle: Text(
                '${trip.pickupAddress} -> ${trip.dropoffAddress}',
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: Text(
                '\$${trip.fare.toStringAsFixed(2)}',
                style: const TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              onTap: () {
                Navigator.pop(ctx);
                _assignDriverToTrip(dp, trip);
              },
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Future<void> _assignDriverToTrip(_DriverPin dp, TripModel trip) async {
    try {
      await FirebaseFirestore.instance
          .collection('trips')
          .doc(trip.tripId)
          .update({
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
            content: Text(
              '${dp.driver.fullName} assigned to ${trip.passengerName}',
            ),
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
  final double lat;
  final double lng;
  final double bearing;

  const _DriverPin({
    required this.driver,
    required this.lat,
    required this.lng,
    this.bearing = 0,
  });
}

const String _darkMapStyle = r"""
[
  {"elementType":"geometry","stylers":[{"color":"#0e0e12"}]},
  {"elementType":"labels.icon","stylers":[{"visibility":"off"}]},
  {"elementType":"labels.text.fill","stylers":[{"color":"#757575"}]},
  {"elementType":"labels.text.stroke","stylers":[{"color":"#0e0e12"}]},
  {"featureType":"road","elementType":"geometry.fill","stylers":[{"color":"#1c1c28"}]},
  {"featureType":"road.highway","elementType":"geometry.fill","stylers":[{"color":"#24242e"}]},
  {"featureType":"water","elementType":"geometry","stylers":[{"color":"#080810"}]}
]
""";
