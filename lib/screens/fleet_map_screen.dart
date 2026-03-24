import 'dart:async';
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' as mapbox;

import '../config/app_theme.dart';
import '../config/map_theme.dart';
import '../config/mapbox_config.dart';
import '../models/driver_model.dart';
import '../models/trip_model.dart';

// Cruise gold constant
const _kGold = Color(0xFFE8C547);

/// Live fleet map â€” Mapbox navigation-night-v1 (dark blue + golden freeways).
class FleetMapScreen extends StatefulWidget {
  const FleetMapScreen({super.key});

  @override
  State<FleetMapScreen> createState() => _FleetMapScreenState();
}

class _FleetMapScreenState extends State<FleetMapScreen> {
  mapbox.MapboxMap? _mapCtrl;

  List<_DriverPin> _driverPins = [];
  List<TripModel> _activeTrips = [];
  List<TripModel> _todayTrips = [];
  StreamSubscription? _driverSub;
  StreamSubscription? _tripSub;
  StreamSubscription? _todayTripSub;

  _DriverPin? _selectedDriver;
  bool _showOnlineOnly = true;

  // Car PNG for map annotations
  Uint8List? _carPng;

  // Gold pulsing dot animation (Cruise-style)
  List<Uint8List> _goldDotFrames = [];
  int _goldDotFrame = 0;
  Timer? _goldDotTimer;

  // Device location — updated on init, falls back to Birmingham, AL (US center)
  double _defaultLat = 33.5186;
  double _defaultLng = -86.8104;

  @override
  void initState() {
    super.initState();
    mapbox.MapboxOptions.setAccessToken(MapboxConfig.accessToken);
    _fetchDeviceLocation();
    _listenDriverLocations();
    _listenActiveTrips();
    _listenTodayTrips();
    _initCarPng();
    _buildGoldDotFrames();
  }

  Future<void> _fetchDeviceLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return;
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return;
      }
      if (permission == LocationPermission.deniedForever) return;
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.low),
      );
      if (!mounted) return;
      setState(() {
        _defaultLat = pos.latitude;
        _defaultLng = pos.longitude;
      });
      _mapCtrl?.flyTo(
        mapbox.CameraOptions(
          center: mapbox.Point(
            coordinates: mapbox.Position(pos.longitude, pos.latitude),
          ),
          zoom: 12.0,
        ),
        mapbox.MapAnimationOptions(duration: 1000),
      );
    } catch (_) {}
  }

  @override
  void dispose() {
    _goldDotTimer?.cancel();
    _driverSub?.cancel();
    _tripSub?.cancel();
    _todayTripSub?.cancel();
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
          if (mounted) {
            setState(() => _driverPins = pins);
            _refreshAnnotations();
          }
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
            _refreshAnnotations();
          }
        });
  }

  void _listenTodayTrips() {
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    _todayTripSub = FirebaseFirestore.instance
        .collection('trips')
        .where(
          'createdAt',
          isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay),
        )
        .snapshots()
        .listen((snap) {
          if (mounted) {
            setState(() {
              _todayTrips = snap.docs
                  .map((d) => TripModel.fromFirestore(d))
                  .toList();
            });
          }
        });
  }

  Future<void> _initCarPng() async {
    _carPng = await _renderCarPng();
    if (mounted) setState(() {});
  }

  Future<Uint8List> _renderCarPng() async {
    const w = 42.0;
    const h = 100.0;
    const scale = 0.45;
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
    if (_carPng == null) return Uint8List(0);
    final codec = await ui.instantiateImageCodec(_carPng!);
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
    return _showOnlineOnly
        ? _driverPins.where((d) => d.driver.isOnline).toList()
        : _driverPins;
  }

  void _centerMap() {
    _mapCtrl?.flyTo(
      mapbox.CameraOptions(
        center: mapbox.Point(
          coordinates: mapbox.Position(_defaultLng, _defaultLat),
        ),
        zoom: 12.0,
      ),
      mapbox.MapAnimationOptions(duration: 800),
    );
  }

  mapbox.PointAnnotationManager? _annotationManager;

  Future<void> _onMapCreated(mapbox.MapboxMap ctrl) async {
    _mapCtrl = ctrl;
    ctrl.scaleBar.updateSettings(mapbox.ScaleBarSettings(enabled: false));
    ctrl.compass.updateSettings(mapbox.CompassSettings(enabled: false));
    ctrl.logo.updateSettings(mapbox.LogoSettings(enabled: false));
    ctrl.attribution.updateSettings(
      mapbox.AttributionSettings(enabled: false),
    );
    _annotationManager =
        await ctrl.annotations.createPointAnnotationManager();
    _annotationManager!.tapEvents(onTap: (annotation) {
      final id = annotation.id.replaceFirst('driver_', '');
      final match = _displayDrivers.where(
        (d) => d.driver.driverId == id,
      );
      if (match.isNotEmpty && mounted) {
        setState(() => _selectedDriver = match.first);
      }
    });
    await _refreshAnnotations();
  }

  Future<void> _refreshAnnotations() async {
    final mgr = _annotationManager;
    if (mgr == null) return;
    await mgr.deleteAll();
    for (final dp in _displayDrivers) {
      final Uint8List imageBytes;
      if (_carPng != null) {
        imageBytes = await _rotatedCarPng(dp.bearing);
      } else {
        // Use gold pulsing dot frame if available, else fallback
        imageBytes = _goldDotFrames.isNotEmpty
            ? _goldDotFrames[_goldDotFrame % _goldDotFrames.length]
            : await _dotPng(
                dp.driver.isOnline ? _kGold : AppColors.error,
              );
      }
      await mgr.create(
        mapbox.PointAnnotationOptions(
          geometry: mapbox.Point(
            coordinates: mapbox.Position(dp.lng, dp.lat),
          ),
          image: imageBytes,
          iconSize: dp.driver.isOnline ? 0.72 : 0.55,
          iconAnchor: mapbox.IconAnchor.CENTER,
          textField: dp.driver.fullName,
          textOffset: [0, 2.2],
          textColor: 0xFFFFFFFF,
          textSize: 11,
          textHaloColor: 0xFF080c16,
          textHaloWidth: 2.0,
        ),
      );
    }
    for (final trip in _activeTrips) {
      if (trip.pickupLat != 0 && trip.pickupLng != 0) {
        final bytes = await _goldSquarePng();
        await mgr.create(
          mapbox.PointAnnotationOptions(
            geometry: mapbox.Point(
              coordinates: mapbox.Position(trip.pickupLng, trip.pickupLat),
            ),
            image: bytes,
            iconSize: 0.65,
            iconAnchor: mapbox.IconAnchor.CENTER,
            textField: trip.passengerName,
            textOffset: [0, 2.2],
            textColor: 0xFFFFFFFF,
            textSize: 11,
            textHaloColor: 0xFF080c16,
            textHaloWidth: 2.0,
          ),
        );
      }
    }
  }

  Future<Uint8List> _dotPng(Color color) async {
    const sz = 80.0;
    final rec = ui.PictureRecorder();
    final canvas = Canvas(rec, const Rect.fromLTWH(0, 0, sz, sz));
    const cx = sz / 2;
    const cy = sz / 2;
    const r = sz * 0.32;
    // Drop shadow
    canvas.drawCircle(
      const Offset(cx, cy + 2),
      r + 2,
      Paint()
        ..color = Colors.black.withValues(alpha: 0.35)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );
    // Gold outer ring gradient
    canvas.drawCircle(
      const Offset(cx, cy),
      r,
      Paint()
        ..shader = ui.Gradient.radial(
          const Offset(cx - 4, cy - 4),
          r + 4,
          [const Color(0xFFF5E27A), _kGold, const Color(0xFFB8941E)],
          [0.0, 0.5, 1.0],
        ),
    );
    // White inner dot
    canvas.drawCircle(const Offset(cx, cy), r * 0.48, Paint()..color = Colors.white);
    // Highlight specular
    canvas.drawCircle(
      const Offset(cx - 4, cy - 4),
      r * 0.26,
      Paint()..color = const Color(0x40FFFFFF),
    );
    final img = await rec.endRecording().toImage(sz.toInt(), sz.toInt());
    final data = await img.toByteData(format: ui.ImageByteFormat.png);
    return data!.buffer.asUint8List();
  }

  /// Gold rounded-square pin for trip pickup (Cruise dropoff style).
  Future<Uint8List> _goldSquarePng() async {
    const sz = 80.0;
    const r = sz * 0.32;
    final rec = ui.PictureRecorder();
    final canvas = Canvas(rec, const Rect.fromLTWH(0, 0, sz, sz));
    const cx = sz / 2;
    const cy = sz / 2;
    final rrect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: const Offset(cx, cy), width: r * 2, height: r * 2),
      Radius.circular(r * 0.30),
    );
    canvas.drawRRect(
      rrect,
      Paint()
        ..color = Colors.black.withValues(alpha: 0.30)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
    );
    canvas.drawRRect(
      rrect,
      Paint()
        ..shader = ui.Gradient.radial(
          const Offset(cx - 4, cy - 4),
          r + 4,
          [const Color(0xFFF5E27A), _kGold, const Color(0xFFB8941E)],
          [0.0, 0.5, 1.0],
        ),
    );
    canvas.drawRRect(
      rrect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = Colors.white.withValues(alpha: 0.22),
    );
    canvas.drawCircle(const Offset(cx, cy), r * 0.32, Paint()..color = Colors.white);
    canvas.drawCircle(
      const Offset(cx - 4, cy - 4),
      r * 0.16,
      Paint()..color = const Color(0x40FFFFFF),
    );
    final img = await rec.endRecording().toImage(sz.toInt(), sz.toInt());
    final data = await img.toByteData(format: ui.ImageByteFormat.png);
    return data!.buffer.asUint8List();
  }

  /// Build 12-frame animated gold pulsing dot (identical to Cruise location dot).
  Future<void> _buildGoldDotFrames() async {
    const int frameCount = 12;
    const double canvasSize = 140.0;
    final frames = <Uint8List>[];
    for (int i = 0; i < frameCount; i++) {
      final t = i / frameCount;
      final pulseRadius = 40.0 + 20.0 * t;
      final pulseAlpha = (0.35 * (1.0 - t)).clamp(0.0, 1.0);
      final rec = ui.PictureRecorder();
      final canvas = Canvas(rec, const Rect.fromLTWH(0, 0, canvasSize, canvasSize));
      final center = const Offset(canvasSize / 2, canvasSize / 2);
      // Shadow
      canvas.drawCircle(
        center.translate(0, 4), 22,
        Paint()
          ..color = const Color(0x50000000)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
      );
      // Outer pulse ring
      canvas.drawCircle(center, pulseRadius,
          Paint()..color = _kGold.withValues(alpha: pulseAlpha * 0.4));
      canvas.drawCircle(center, pulseRadius,
          Paint()
            ..color = _kGold.withValues(alpha: pulseAlpha)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.5);
      // Gold 3D ring
      canvas.drawCircle(
        center, 18,
        Paint()
          ..shader = ui.Gradient.radial(
            center.translate(-4, -4), 22,
            [const Color(0xFFF5E27A), _kGold, const Color(0xFFB8941E)],
            [0.0, 0.5, 1.0],
          ),
      );
      // White inner
      canvas.drawCircle(center, 9, Paint()..color = Colors.white);
      // Highlight
      canvas.drawCircle(
        center.translate(-3, -3), 5,
        Paint()..color = const Color(0x40FFFFFF),
      );
      final img = await rec.endRecording().toImage(canvasSize.toInt(), canvasSize.toInt());
      final data = await img.toByteData(format: ui.ImageByteFormat.png);
      if (data == null) return;
      frames.add(data.buffer.asUint8List());
    }
    if (!mounted || frames.length != frameCount) return;
    setState(() => _goldDotFrames = frames);
    _goldDotTimer = Timer.periodic(const Duration(milliseconds: 130), (_) {
      if (!mounted || _goldDotFrames.isEmpty) return;
      _goldDotFrame = (_goldDotFrame + 1) % _goldDotFrames.length;
      _refreshAnnotations();
    });
  }

  Widget _buildMapbox() {
    return mapbox.MapWidget(
      key: const ValueKey('dispatch-fleet-map'),
      styleUri: MapboxConfig.styleNavigation,
      textureView: true,
      cameraOptions: mapbox.CameraOptions(
        center: mapbox.Point(
          coordinates: mapbox.Position(_defaultLng, _defaultLat),
        ),
        zoom: 12.0,
      ),
      onMapCreated: _onMapCreated,
      onStyleLoadedListener: (_) async {
        if (_mapCtrl != null) await MapTheme.applyNavyGold(_mapCtrl!);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // Counts from ALL drivers (not filtered by _showOnlineOnly)
    final int onlineCount = _driverPins.where((d) => d.driver.isOnline).length;
    final int offlineCount = _driverPins.length - onlineCount;
    final int todayTripCount = _todayTrips.length;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          _buildMapbox(),
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            left: 12,
            right: 12,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: BackdropFilter(
                filter: ui.ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
                  decoration: BoxDecoration(
                    color: const Color(0xFF080c16).withValues(alpha: 0.85),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: _kGold.withValues(alpha: 0.18),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.40),
                        blurRadius: 16,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: const LinearGradient(
                            colors: [Color(0xFFF5E27A), _kGold],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: _kGold.withValues(alpha: 0.35),
                              blurRadius: 8,
                              spreadRadius: 1,
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.map_rounded,
                          color: Colors.black,
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 10),
                      const Text(
                        'Fleet Map',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.2,
                        ),
                      ),
                      const Spacer(),
                      _statChip(
                        Icons.circle,
                        AppColors.success,
                        '$onlineCount online',
                      ),
                      const SizedBox(width: 6),
                      _statChip(
                        Icons.circle,
                        AppColors.error,
                        '$offlineCount offline',
                      ),
                      const SizedBox(width: 6),
                      _statChip(
                        Icons.local_taxi,
                        _kGold,
                        '$todayTripCount trips',
                      ),
                    ],
                  ),
                ),
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.28)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 8),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }

  Widget _mapButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool gold = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: gold
                  ? _kGold.withValues(alpha: 0.15)
                  : const Color(0xFF0a0e1a).withValues(alpha: 0.82),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: gold
                    ? _kGold.withValues(alpha: 0.40)
                    : const Color(0xFFE8C547).withValues(alpha: 0.14),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, color: gold ? _kGold : _kGold, size: 16),
                const SizedBox(width: 7),
                Text(
                  label,
                  style: TextStyle(
                    color: gold ? _kGold : Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.3,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDriverInfoCard(_DriverPin dp) {
    final d = dp.driver;
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 22, sigmaY: 22),
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 18),
          decoration: BoxDecoration(
            color: const Color(0xFF080c16).withValues(alpha: 0.88),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: _kGold.withValues(alpha: 0.18),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.45),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Drag handle
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 14),
                  decoration: BoxDecoration(
                    color: _kGold.withValues(alpha: 0.30),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              Row(
                children: [
                  // Gold avatar
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [_kGold, _kGold.withValues(alpha: 0.55)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        d.fullName.isNotEmpty ? d.fullName[0].toUpperCase() : '?',
                        style: const TextStyle(
                          color: Colors.black,
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                        ),
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
                            color: Colors.white,
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.2,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '${d.vehicleType ?? "Vehicle"} Â· ${d.vehiclePlate ?? "N/A"}',
                          style: TextStyle(
                            color: _kGold,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Status badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: d.isOnline
                          ? AppColors.success.withValues(alpha: 0.15)
                          : AppColors.error.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: d.isOnline
                            ? AppColors.success.withValues(alpha: 0.35)
                            : AppColors.error.withValues(alpha: 0.35),
                      ),
                    ),
                    child: Text(
                      d.isOnline ? 'Online' : 'Offline',
                      style: TextStyle(
                        color: d.isOnline ? AppColors.success : AppColors.error,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              if (d.isOnline &&
                  _activeTrips.any((t) => t.status == TripStatus.requested)) ...[
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton.icon(
                    onPressed: () => _showAssignDialog(dp),
                    icon: const Icon(Icons.assignment_ind, size: 18),
                    label: const Text(
                      'Assign to Trip',
                      style: TextStyle(fontWeight: FontWeight.w800, letterSpacing: 0.3),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _kGold,
                      foregroundColor: Colors.black,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
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
