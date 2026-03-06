import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
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
  Uint8List? _simCarPng; // raw car PNG for iOS rotation
  final Map<int, am.BitmapDescriptor> _iosRotatedIcons = {}; // 0-359° cache

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
    _initMarkers();
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

  Future<void> _initMarkers() async {
    _simCarPng = await _renderCarPng();
    if (Platform.isIOS) {
      // Pre-generate 36 rotated icons (every 10°) for smooth iOS rotation
      for (int deg = 0; deg < 360; deg += 10) {
        final bytes = await _rotatedCarPng(deg.toDouble());
        _iosRotatedIcons[deg] = am.BitmapDescriptor.fromBytes(bytes);
      }
    } else {
      _gmOnlineIcon = await _carBitmap(AppColors.success);
      _gmOfflineIcon = await _carBitmap(AppColors.error);
      _gmPickupIcon = await _pickupBitmap();
      _simCarIcon = gm.BitmapDescriptor.bytes(_simCarPng!);
    }
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

  Future<Uint8List> _renderCarPng() async {
    const w = 42.0;
    const h = 100.0;
    const scale = 0.22;
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
    return data2!.buffer.asUint8List();
  }

  Future<Uint8List> _rotatedCarPng(double bearingDeg) async {
    if (_simCarPng == null) return Uint8List(0);
    final codec = await ui.instantiateImageCodec(_simCarPng!);
    final frame = await codec.getNextFrame();
    final src = frame.image;
    final sz = max(src.width, src.height).toDouble();
    final rec = ui.PictureRecorder();
    final c = Canvas(rec);
    c.translate(sz / 2, sz / 2);
    c.rotate(bearingDeg * pi / 180);
    c.translate(-src.width / 2, -src.height / 2);
    c.drawImage(src, Offset.zero, Paint());
    final out = await rec.endRecording().toImage(sz.toInt(), sz.toInt());
    final d = await out.toByteData(format: ui.ImageByteFormat.png);
    src.dispose();
    out.dispose();
    return d!.buffer.asUint8List();
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
      const startIdx = 0;
      final nextPt = route.length > 1 ? route[1] : route[0];
      final initBearing = _calcBearing(
        route[0].$1,
        route[0].$2,
        nextPt.$1,
        nextPt.$2,
      );
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
        bearing: initBearing,
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
        const speed = 0.000018;
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
          // Look ahead to next waypoint and set bearing toward it
          int lookAhead;
          if (s.isLoop) {
            lookAhead = (s.waypointIdx + 1) % s.route.length;
          } else if (s.forward) {
            lookAhead = min(s.waypointIdx + 1, s.route.length - 1);
          } else {
            lookAhead = max(s.waypointIdx - 1, 0);
          }
          final la = s.route[lookAhead];
          s.bearing = _calcBearing(s.lat, s.lng, la.$1, la.$2);
        } else {
          final ratio = speed / dist;
          s.lat += dy * ratio;
          s.lng += dx * ratio;
          // Always face the direction we are moving
          s.bearing = _calcBearing(s.lat, s.lng, target.$1, target.$2);
        }
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

  am.BitmapDescriptor _iosCarIcon(double bearing) {
    final snap = ((bearing / 10).round() * 10) % 360;
    return _iosRotatedIcons[snap] ?? am.BitmapDescriptor.defaultAnnotation;
  }

  Set<am.Annotation> _buildAppleAnnotations() {
    final annotations = <am.Annotation>{};
    for (final dp in _displayDrivers) {
      final icon = _simulationMode
          ? _iosCarIcon(dp.bearing)
          : am.BitmapDescriptor.defaultAnnotationWithHue(
              dp.driver.isOnline ? 120.0 : 0.0,
            );
      annotations.add(
        am.Annotation(
          annotationId: am.AnnotationId('driver_${dp.driver.driverId}'),
          position: am.LatLng(dp.lat, dp.lng),
          anchor: const Offset(0.5, 0.5),
          icon: icon,
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
  // Route 0: Downtown grid loop — 20th St S → 1st Ave N → 18th St N → 5th Ave N
  [
    // South on 20th St
    (33.5214, -86.8093), (33.5210, -86.8093), (33.5206, -86.8093),
    (33.5202, -86.8093), (33.5198, -86.8093), (33.5194, -86.8093),
    (33.5190, -86.8093), (33.5186, -86.8093), (33.5182, -86.8093),
    (33.5178, -86.8093), (33.5174, -86.8093), (33.5170, -86.8093),
    // Curve left (turn east onto 1st Ave N)
    (33.5168, -86.8091), (33.5167, -86.8088), (33.5167, -86.8084),
    // East on 1st Ave N
    (33.5167, -86.8080), (33.5167, -86.8076), (33.5167, -86.8072),
    (33.5167, -86.8068), (33.5167, -86.8064), (33.5167, -86.8060),
    (33.5167, -86.8056), (33.5167, -86.8052), (33.5167, -86.8048),
    (33.5167, -86.8044), (33.5167, -86.8040), (33.5167, -86.8036),
    (33.5167, -86.8032),
    // Curve left (turn north onto 18th St)
    (33.5168, -86.8029), (33.5170, -86.8028), (33.5172, -86.8028),
    // North on 18th St
    (33.5176, -86.8028), (33.5180, -86.8028), (33.5184, -86.8028),
    (33.5188, -86.8028), (33.5192, -86.8028), (33.5196, -86.8028),
    (33.5200, -86.8028), (33.5204, -86.8028), (33.5208, -86.8028),
    (33.5212, -86.8028),
    // Curve left (turn west onto 5th Ave N)
    (33.5214, -86.8030), (33.5215, -86.8033), (33.5215, -86.8036),
    // West on 5th Ave N
    (33.5215, -86.8040), (33.5215, -86.8044), (33.5215, -86.8048),
    (33.5215, -86.8052), (33.5215, -86.8056), (33.5215, -86.8060),
    (33.5215, -86.8064), (33.5215, -86.8068), (33.5215, -86.8072),
    (33.5215, -86.8076), (33.5215, -86.8080), (33.5215, -86.8084),
    (33.5215, -86.8088),
    // Curve left (turn south back onto 20th St)
    (33.5215, -86.8091), (33.5214, -86.8093),
  ],
  // Route 1: UAB area loop — University Blvd → 14th St → 8th Ave → 20th St
  [
    // East on University Blvd
    (33.5055, -86.8097), (33.5055, -86.8093), (33.5055, -86.8089),
    (33.5055, -86.8085), (33.5055, -86.8081), (33.5055, -86.8077),
    (33.5055, -86.8073), (33.5055, -86.8069), (33.5055, -86.8065),
    (33.5055, -86.8061), (33.5055, -86.8057), (33.5055, -86.8053),
    (33.5055, -86.8049), (33.5055, -86.8045), (33.5055, -86.8041),
    (33.5055, -86.8037),
    // Curve right (turn south onto 14th St)
    (33.5054, -86.8034), (33.5052, -86.8033), (33.5050, -86.8033),
    // South on 14th St
    (33.5046, -86.8033), (33.5042, -86.8033), (33.5038, -86.8033),
    (33.5034, -86.8033), (33.5030, -86.8033), (33.5026, -86.8033),
    // Curve right (turn west onto 8th Ave)
    (33.5024, -86.8035), (33.5023, -86.8038), (33.5023, -86.8041),
    // West on 8th Ave
    (33.5023, -86.8045), (33.5023, -86.8049), (33.5023, -86.8053),
    (33.5023, -86.8057), (33.5023, -86.8061), (33.5023, -86.8065),
    (33.5023, -86.8069), (33.5023, -86.8073), (33.5023, -86.8077),
    (33.5023, -86.8081), (33.5023, -86.8085), (33.5023, -86.8089),
    (33.5023, -86.8093),
    // Curve right (turn north onto 20th St)
    (33.5024, -86.8096), (33.5026, -86.8097), (33.5028, -86.8097),
    // North on 20th St
    (33.5032, -86.8097), (33.5036, -86.8097), (33.5040, -86.8097),
    (33.5044, -86.8097), (33.5048, -86.8097), (33.5052, -86.8097),
  ],
  // Route 2: 20th St long corridor N→S (ping-pong)
  [
    (33.5250, -86.8093),
    (33.5246, -86.8093),
    (33.5242, -86.8093),
    (33.5238, -86.8093),
    (33.5234, -86.8093),
    (33.5230, -86.8093),
    (33.5226, -86.8093),
    (33.5222, -86.8093),
    (33.5218, -86.8093),
    (33.5214, -86.8093),
    (33.5210, -86.8093),
    (33.5206, -86.8093),
    (33.5202, -86.8093),
    (33.5198, -86.8093),
    (33.5194, -86.8093),
    (33.5190, -86.8093),
    (33.5186, -86.8093),
    (33.5182, -86.8093),
    (33.5178, -86.8093),
    (33.5174, -86.8093),
    (33.5170, -86.8093),
    (33.5166, -86.8093),
    (33.5162, -86.8093),
    (33.5158, -86.8093),
    (33.5154, -86.8093),
    (33.5150, -86.8093),
    (33.5146, -86.8093),
    (33.5142, -86.8093),
    (33.5138, -86.8093),
    (33.5134, -86.8093),
    (33.5130, -86.8093),
    (33.5126, -86.8093),
    (33.5122, -86.8093),
    (33.5118, -86.8093),
    (33.5114, -86.8093),
    (33.5110, -86.8093),
    (33.5106, -86.8093),
    (33.5102, -86.8093),
    (33.5098, -86.8093),
  ],
  // Route 3: 2nd Ave N E→W (ping-pong)
  [
    (33.5187, -86.8140),
    (33.5187, -86.8136),
    (33.5187, -86.8132),
    (33.5187, -86.8128),
    (33.5187, -86.8124),
    (33.5187, -86.8120),
    (33.5187, -86.8116),
    (33.5187, -86.8112),
    (33.5187, -86.8108),
    (33.5187, -86.8104),
    (33.5187, -86.8100),
    (33.5187, -86.8096),
    (33.5187, -86.8092),
    (33.5187, -86.8088),
    (33.5187, -86.8084),
    (33.5187, -86.8080),
    (33.5187, -86.8076),
    (33.5187, -86.8072),
    (33.5187, -86.8068),
    (33.5187, -86.8064),
    (33.5187, -86.8060),
    (33.5187, -86.8056),
    (33.5187, -86.8052),
    (33.5187, -86.8048),
    (33.5187, -86.8044),
    (33.5187, -86.8040),
    (33.5187, -86.8036),
    (33.5187, -86.8032),
    (33.5187, -86.8028),
    (33.5187, -86.8024),
    (33.5187, -86.8020),
    (33.5187, -86.8016),
    (33.5187, -86.8012),
  ],
  // Route 4: Southside loop — 11th Ave → 17th St → 14th Ave → 20th St
  [
    // East on 11th Ave S
    (33.4985, -86.8097), (33.4985, -86.8093), (33.4985, -86.8089),
    (33.4985, -86.8085), (33.4985, -86.8081), (33.4985, -86.8077),
    (33.4985, -86.8073), (33.4985, -86.8069), (33.4985, -86.8065),
    (33.4985, -86.8061), (33.4985, -86.8057), (33.4985, -86.8053),
    // Curve right (turn south onto 17th St)
    (33.4984, -86.8050), (33.4982, -86.8049), (33.4980, -86.8049),
    // South on 17th St
    (33.4976, -86.8049), (33.4972, -86.8049), (33.4968, -86.8049),
    (33.4964, -86.8049), (33.4960, -86.8049),
    // Curve right (turn west onto 14th Ave)
    (33.4958, -86.8051), (33.4957, -86.8054), (33.4957, -86.8057),
    // West on 14th Ave S
    (33.4957, -86.8061), (33.4957, -86.8065), (33.4957, -86.8069),
    (33.4957, -86.8073), (33.4957, -86.8077), (33.4957, -86.8081),
    (33.4957, -86.8085), (33.4957, -86.8089), (33.4957, -86.8093),
    // Curve right (turn north onto 20th St)
    (33.4958, -86.8096), (33.4960, -86.8097), (33.4962, -86.8097),
    // North on 20th St
    (33.4966, -86.8097), (33.4970, -86.8097), (33.4974, -86.8097),
    (33.4978, -86.8097), (33.4982, -86.8097),
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
