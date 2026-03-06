import 'dart:async';
import 'dart:io';
import 'dart:math';
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

  // Simulation demo
  bool _simulationMode = false;
  Timer? _simTimer;
  List<_SimDriverState> _simStates = [];
  final _rand = Random();
  gm.BitmapDescriptor? _simCarIcon;

  gm.BitmapDescriptor? _gmOnlineIcon;
  gm.BitmapDescriptor? _gmOfflineIcon;
  gm.BitmapDescriptor? _gmPickupIcon;

  static const double _defaultLat = 33.5186; // Birmingham, Alabama
  static const double _defaultLng = -86.8104;

  @override
  void initState() {
    super.initState();
    _listenDriverLocations();
    _listenActiveTrips();
    if (!Platform.isIOS) _initGoogleMarkers();
  }

  @override
  void dispose() {
    _simTimer?.cancel();
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
    _simCarIcon = await _simCarBitmap();
    if (mounted) setState(() {});
  }

  Future<gm.BitmapDescriptor> _carBitmap(Color color) async {
    const sz = 28.0;
    final rec = ui.PictureRecorder();
    final c = Canvas(rec);
    c.drawCircle(
      const Offset(sz / 2, sz / 2),
      sz / 2 - 1,
      Paint()..color = color,
    );
    c.drawCircle(
      const Offset(sz / 2, sz / 2),
      sz / 2 - 1,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
    final tp = TextPainter(
      text: TextSpan(
        text: String.fromCharCode(Icons.directions_car.codePoint),
        style: const TextStyle(
          fontSize: 14,
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
    const sz = 24.0;
    final rec = ui.PictureRecorder();
    final c = Canvas(rec);
    c.drawCircle(
      const Offset(sz / 2, sz / 2),
      sz / 2 - 1,
      Paint()..color = AppColors.primary,
    );
    c.drawCircle(
      const Offset(sz / 2, sz / 2),
      sz / 2 - 1,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
    final tp = TextPainter(
      text: TextSpan(
        text: String.fromCharCode(Icons.location_on.codePoint),
        style: const TextStyle(
          fontSize: 12,
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

  Future<gm.BitmapDescriptor> _simCarBitmap() async {
    const w = 42.0;
    const h = 100.0;
    const scale = 0.38;
    final ow = (w * scale).ceil();
    final oh = (h * scale).ceil();
    final rec = ui.PictureRecorder();
    final c = Canvas(rec);
    c.scale(scale);
    c.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(4, 6, 34, 92),
        const Radius.circular(10),
      ),
      Paint()
        ..color = const Color(0x60000000)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
    );
    final bodyPath = Path()
      ..moveTo(w / 2, 4)
      ..quadraticBezierTo(w - 6, 4, w - 6, 16)
      ..lineTo(w - 5, h - 16)
      ..quadraticBezierTo(w - 6, h - 4, w / 2, h - 4)
      ..quadraticBezierTo(6, h - 4, 6, h - 16)
      ..lineTo(5, 16)
      ..quadraticBezierTo(6, 4, w / 2, 4)
      ..close();
    c.drawPath(bodyPath, Paint()..color = const Color(0xFFF5F5F5));
    c.drawPath(
      bodyPath,
      Paint()
        ..color = const Color(0xFFBBBBBB)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.8,
    );
    c.drawLine(
      const Offset(12, 20),
      Offset(w - 12, 20),
      Paint()
        ..color = const Color(0xFFDDDDDD)
        ..strokeWidth = 0.5,
    );
    final fwPath = Path()
      ..moveTo(10, 26)
      ..lineTo(w - 10, 26)
      ..lineTo(w - 12, 40)
      ..lineTo(12, 40)
      ..close();
    c.drawPath(fwPath, Paint()..color = const Color(0xFF2D3748));
    c.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(12, 40, 18, 18),
        const Radius.circular(2),
      ),
      Paint()..color = const Color(0xFFE2E2E2),
    );
    final rwPath = Path()
      ..moveTo(12, 58)
      ..lineTo(w - 12, 58)
      ..lineTo(w - 10, 70)
      ..lineTo(10, 70)
      ..close();
    c.drawPath(rwPath, Paint()..color = const Color(0xFF2D3748));
    c.drawLine(
      const Offset(12, 78),
      Offset(w - 12, 78),
      Paint()
        ..color = const Color(0xFFDDDDDD)
        ..strokeWidth = 0.5,
    );
    c.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(8, 6, 7, 4),
        const Radius.circular(2),
      ),
      Paint()..color = const Color(0xFFFFF8E1),
    );
    c.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(w - 15, 6, 7, 4),
        const Radius.circular(2),
      ),
      Paint()..color = const Color(0xFFFFF8E1),
    );
    c.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(8, h - 10, 7, 4),
        const Radius.circular(2),
      ),
      Paint()..color = const Color(0xFFE53E3E),
    );
    c.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(w - 15, h - 10, 7, 4),
        const Radius.circular(2),
      ),
      Paint()..color = const Color(0xFFE53E3E),
    );
    final wp = Paint()..color = const Color(0xFF1A1A1A);
    c.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(2, 20, 5, 14),
        const Radius.circular(2),
      ),
      wp,
    );
    c.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(w - 7, 20, 5, 14),
        const Radius.circular(2),
      ),
      wp,
    );
    c.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(2, h - 34, 5, 14),
        const Radius.circular(2),
      ),
      wp,
    );
    c.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(w - 7, h - 34, 5, 14),
        const Radius.circular(2),
      ),
      wp,
    );
    c.drawOval(
      const Rect.fromLTWH(1, 28, 5, 4),
      Paint()..color = const Color(0xFFE0E0E0),
    );
    c.drawOval(
      Rect.fromLTWH(w - 6, 28, 5, 4),
      Paint()..color = const Color(0xFFE0E0E0),
    );
    final img = await rec.endRecording().toImage(ow, oh);
    final data2 = await img.toByteData(format: ui.ImageByteFormat.png);
    return gm.BitmapDescriptor.bytes(data2!.buffer.asUint8List());
  }

  List<_DriverPin> get _displayDrivers {
    if (_simulationMode) {
      return _simStates
          .map(
            (s) => _DriverPin(
              driver: s.driver,
              lat: s.lat,
              lng: s.lng,
              bearing: s.bearing,
            ),
          )
          .toList();
    }
    return _showOnlineOnly
        ? _driverPins.where((d) => d.driver.isOnline).toList()
        : _driverPins;
  }

  void _centerMap() {
    if (Platform.isIOS) {
      _appleCtrl?.animateCamera(
        am.CameraUpdate.newLatLngZoom(
          const am.LatLng(_defaultLat, _defaultLng),
          12,
        ),
      );
    } else {
      _googleCtrl?.animateCamera(
        gm.CameraUpdate.newLatLngZoom(
          const gm.LatLng(_defaultLat, _defaultLng),
          12,
        ),
      );
    }
  }

  void _startSimulation() {
    const simInfo = [
      ('sim_1', 'Carlos', 'Martinez', 'Toyota Camry', 'ALA-001', 0, true),
      ('sim_2', 'Ana', 'González', 'Honda Accord', 'ALA-002', 1, true),
      ('sim_3', 'Roberto', 'Silva', 'Ford Fusion', 'ALA-003', 2, false),
      ('sim_4', 'Maria', 'López', 'Chevy Malibu', 'ALA-004', 3, false),
      ('sim_5', 'José', 'Rodríguez', 'Nissan Altima', 'ALA-005', 4, true),
    ];
    _simStates = simInfo.map((d) {
      final route = _simRoutes[d.$6];
      final startIdx = _rand.nextInt(route.length);
      return _SimDriverState(
        driver: DriverModel(
          driverId: d.$1,
          firstName: d.$2,
          lastName: d.$3,
          phone: '+1-205-555-${_rand.nextInt(9000) + 1000}',
          isOnline: true,
          vehicleType: d.$4,
          vehiclePlate: d.$5,
          status: 'active',
        ),
        route: route,
        isLoop: d.$7,
        waypointIdx: startIdx,
        lat: route[startIdx].$1,
        lng: route[startIdx].$2,
        bearing: _rand.nextDouble() * 360,
      );
    }).toList();
    setState(() => _simulationMode = true);
    _simTimer = Timer.periodic(const Duration(milliseconds: 80), _moveSim);
  }

  void _stopSimulation() {
    _simTimer?.cancel();
    _simTimer = null;
    setState(() {
      _simulationMode = false;
      _simStates = [];
      _selectedDriver = null;
    });
  }

  void _moveSim(Timer t) {
    if (!mounted) return;
    setState(() {
      for (final s in _simStates) {
        int nextIdx;
        if (s.isLoop) {
          nextIdx = (s.waypointIdx + 1) % s.route.length;
        } else if (s.forward) {
          nextIdx = s.waypointIdx + 1;
        } else {
          nextIdx = s.waypointIdx - 1;
        }
        if (nextIdx < 0 || nextIdx >= s.route.length) {
          s.forward = !s.forward;
          continue;
        }
        final target = s.route[nextIdx];
        final dx = target.$2 - s.lng;
        final dy = target.$1 - s.lat;
        final dist = sqrt(dx * dx + dy * dy);
        const speed = 0.000035;
        if (dist < speed * 1.5) {
          s.lat = target.$1;
          s.lng = target.$2;
          s.waypointIdx = nextIdx;
          if (!s.isLoop) {
            if (s.forward && nextIdx >= s.route.length - 1) {
              s.forward = false;
            } else if (!s.forward && nextIdx <= 0) {
              s.forward = true;
            }
          }
        } else {
          final ratio = speed / dist;
          s.lat += dy * ratio;
          s.lng += dx * ratio;
        }
        final tBearing = _calcBearing(s.lat, s.lng, target.$1, target.$2);
        s.bearing = _lerpAngle(s.bearing, tBearing, 0.12);
      }
    });
  }

  double _calcBearing(double lat1, double lng1, double lat2, double lng2) {
    final dLng = (lng2 - lng1) * pi / 180;
    final lat1R = lat1 * pi / 180;
    final lat2R = lat2 * pi / 180;
    final y = sin(dLng) * cos(lat2R);
    final x = cos(lat1R) * sin(lat2R) - sin(lat1R) * cos(lat2R) * cos(dLng);
    return (atan2(y, x) * 180 / pi + 360) % 360;
  }

  double _lerpAngle(double from, double to, double t) {
    final diff = ((to - from) + 540) % 360 - 180;
    return (from + diff * t) % 360;
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
        target: am.LatLng(_defaultLat, _defaultLng),
        zoom: 12,
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
      final icon = _simulationMode
          ? (_simCarIcon ?? gm.BitmapDescriptor.defaultMarker)
          : dp.driver.isOnline
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
        target: gm.LatLng(_defaultLat, _defaultLng),
        zoom: 12,
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
    final displayedDrivers = _displayDrivers;
    final onlineCount = displayedDrivers.where((d) => d.driver.isOnline).length;
    final offlineCount = displayedDrivers.length - onlineCount;

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
                const SizedBox(height: 8),
                _mapButton(
                  icon: _simulationMode ? Icons.stop : Icons.play_arrow,
                  label: _simulationMode ? 'Stop' : 'Demo',
                  onTap: _simulationMode ? _stopSimulation : _startSimulation,
                ),
              ],
            ),
          ),
          if (_simulationMode)
            Positioned(
              top: MediaQuery.of(context).padding.top + 68,
              left: 12,
              right: 110,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.92),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.play_arrow, color: Colors.white, size: 14),
                    SizedBox(width: 6),
                    Text(
                      'SIMULATION — Demo Visual',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
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

class _SimDriverState {
  final DriverModel driver;
  final List<(double, double)> route;
  final bool isLoop;
  int waypointIdx;
  bool forward;
  double lat;
  double lng;
  double bearing;

  _SimDriverState({
    required this.driver,
    required this.route,
    required this.isLoop,
    this.waypointIdx = 0,
    required this.lat,
    required this.lng,
    this.bearing = 0,
  }) : forward = true;
}

const _simRoutes = <List<(double, double)>>[
  // Route 0: Downtown rectangle loop (clockwise)
  [
    (33.5215, -86.8140),
    (33.5215, -86.8120),
    (33.5215, -86.8100),
    (33.5215, -86.8080),
    (33.5210, -86.8065),
    (33.5200, -86.8060),
    (33.5185, -86.8060),
    (33.5170, -86.8060),
    (33.5162, -86.8065),
    (33.5158, -86.8080),
    (33.5158, -86.8100),
    (33.5158, -86.8120),
    (33.5158, -86.8140),
    (33.5163, -86.8150),
    (33.5175, -86.8155),
    (33.5195, -86.8155),
    (33.5210, -86.8148),
  ],
  // Route 1: UAB campus loop
  [
    (33.5105, -86.8130),
    (33.5105, -86.8110),
    (33.5105, -86.8090),
    (33.5105, -86.8070),
    (33.5098, -86.8058),
    (33.5085, -86.8055),
    (33.5070, -86.8055),
    (33.5062, -86.8062),
    (33.5058, -86.8075),
    (33.5058, -86.8095),
    (33.5058, -86.8115),
    (33.5058, -86.8130),
    (33.5068, -86.8138),
    (33.5085, -86.8140),
    (33.5098, -86.8135),
  ],
  // Route 2: 20th St corridor north-south (ping-pong)
  [
    (33.5280, -86.8094),
    (33.5260, -86.8094),
    (33.5240, -86.8094),
    (33.5220, -86.8094),
    (33.5200, -86.8094),
    (33.5180, -86.8094),
    (33.5160, -86.8094),
    (33.5140, -86.8094),
    (33.5120, -86.8094),
    (33.5100, -86.8094),
    (33.5080, -86.8094),
  ],
  // Route 3: Highland Ave diagonal (ping-pong)
  [
    (33.5080, -86.7940),
    (33.5090, -86.7965),
    (33.5100, -86.7990),
    (33.5108, -86.8015),
    (33.5115, -86.8040),
    (33.5120, -86.8065),
    (33.5125, -86.8090),
    (33.5128, -86.8115),
    (33.5130, -86.8140),
  ],
  // Route 4: Lakeview district loop
  [
    (33.5060, -86.7930),
    (33.5060, -86.7955),
    (33.5060, -86.7980),
    (33.5055, -86.7995),
    (33.5045, -86.8000),
    (33.5030, -86.8000),
    (33.5030, -86.7975),
    (33.5030, -86.7950),
    (33.5035, -86.7935),
    (33.5048, -86.7928),
  ],
];

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
