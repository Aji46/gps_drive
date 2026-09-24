import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

import '../models/car_choice.dart';

class CurrentMapScreen extends StatefulWidget {
  const CurrentMapScreen({super.key, required this.car});

  final CarChoice car;

  @override
  State<CurrentMapScreen> createState() => _CurrentMapScreenState();
}

class _CurrentMapScreenState extends State<CurrentMapScreen> {
  static const _mapsApiKey = String.fromEnvironment(
    'GOOGLE_MAPS_API_KEY',
    defaultValue: 'AIzaSyDBltRFmvlIsvRjMApSIi-5n0gjJ_AtukA',
  );

  GoogleMapController? _controller;
  final _searchController = TextEditingController();
  final _searchFocusNode = FocusNode();
  Position? _position;
  LatLng? _carPosition;
  LatLng? _startPosition;
  LatLng? _destination;
  List<LatLng> _routePoints = const [];
  Timer? _driveTimer;
  String? _error;
  bool _loading = true;
  double _heading = 0;
  double _speed = 0;
  double _driveInput = 0;
  double _steering = 0;
  bool _brake = false;
  bool _horn = false;
  bool _collisionDialogShowing = false;
  bool _missionDialogShowing = false;
  bool _searching = false;
  bool _loadingRoute = false;
  bool _roadReady = false;
  String? _destinationName;
  int _missionScore = 0;
  int _cameraUpdateCounter = 0;

  bool get _mapSupported => kIsWeb ||
      defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS;

  static const CameraPosition _fallbackCamera = CameraPosition(
    target: LatLng(20, 0),
    zoom: 2,
  );

  @override
  void initState() {
    super.initState();
    _loadCurrentLocation();
  }

  Future<void> _loadCurrentLocation() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        throw Exception('Location services are disabled.');
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        throw Exception('Location permission was not granted.');
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
      if (!mounted) return;
      setState(() {
        _position = position;
        _startPosition = LatLng(position.latitude, position.longitude);
        _carPosition = _startPosition;
        _loading = false;
      });
      _driveTimer ??= Timer.periodic(
        const Duration(milliseconds: 50),
        (_) => _updateCar(),
      );
      await _controller?.animateCamera(
        CameraUpdate.newCameraPosition(_cameraFor(position)),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  CameraPosition _cameraFor(Position position) {
    return CameraPosition(
      target: LatLng(position.latitude, position.longitude),
      zoom: 19,
      tilt: 40,
    );
  }

  void _onMapCreated(GoogleMapController controller) {
    _controller = controller;
    final position = _position;
    if (position != null) {
      controller.moveCamera(CameraUpdate.newCameraPosition(_cameraFor(position)));
    }
  }

  void _zoomToMaximum() {
    final carPosition = _carPosition;
    if (carPosition == null) return;
    _controller?.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(
          target: carPosition,
          zoom: 21,
          tilt: 45,
          bearing: _heading * 180 / math.pi,
        ),
      ),
    );
  }

  Widget _zoomControls() {
    return Positioned(
      top: 18,
      right: 14,
      child: _zoomButton(
        Icons.zoom_in_map_rounded,
        _zoomToMaximum,
        'Maximum zoom',
      ),
    );
  }

  Widget _zoomButton(IconData icon, VoidCallback onPressed, String tooltip) {
    return Material(
      color: Colors.black.withOpacity(.78),
      shape: const CircleBorder(),
      child: IconButton(
        tooltip: tooltip,
        onPressed: onPressed,
        icon: Icon(icon, color: Colors.white),
      ),
    );
  }

  Set<Marker> get _markers {
    final destination = _destination;
    if (destination == null) return const <Marker>{};
    return {
      Marker(
        markerId: const MarkerId('mission-destination'),
        position: destination,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
        infoWindow: const InfoWindow(title: 'Mission destination'),
      ),
    };
  }


  // Game buildings are rendered as rectangular obstacle zones around the
  // real road route. GoogleMap's `buildingsEnabled` is visual-only; it does
  // not expose real building polygons for collision detection.
  Set<Polygon> get _buildingPolygons {
    final points = _routePoints;
    if (points.length < 2) return const <Polygon>{};

    final polygons = <Polygon>{};
    const buildingWidth = 16.0;
    const buildingLength = 24.0;

    // Place obstacles beside the actual road at intervals. They are deliberately
    // outside the normal driving corridor so the player can hit them by rash
    // driving/off-road steering.
    for (var i = 1; i < points.length - 1; i += 8) {
      final a = points[i];
      final b = points[i + 1];
      final dx = (b.longitude - a.longitude) *
          111320 *
          math.cos(a.latitude * math.pi / 180);
      final dy = (b.latitude - a.latitude) * 111320;
      final length = math.sqrt(dx * dx + dy * dy);
      if (length < 1) continue;

      final nx = -dy / length;
      final ny = dx / length;

      final side = (i ~/ 8).isEven ? 1.0 : -1.0;
      const offset = 27.0;

      final cx = a.longitude +
          (nx * offset * side) /
              (111320 * math.cos(a.latitude * math.pi / 180));
      final cy = a.latitude + (ny * offset * side) / 111320;

      final ux = dx / length;
      final uy = dy / length;

      LatLng p(double along, double across) {
        final east = ux * along + nx * across;
        final north = uy * along + ny * across;
        return LatLng(
          cy + north / 111320,
          cx + east /
              (111320 * math.cos(a.latitude * math.pi / 180)),
        );
      }

      final polygonPoints = <LatLng>[
        p(-buildingLength / 2, -buildingWidth / 2),
        p(buildingLength / 2, -buildingWidth / 2),
        p(buildingLength / 2, buildingWidth / 2),
        p(-buildingLength / 2, buildingWidth / 2),
      ];

      polygons.add(
        Polygon(
          polygonId: PolygonId('building_$i'),
          points: polygonPoints,
          fillColor: Colors.red.withOpacity(.30),
          strokeColor: Colors.redAccent,
          strokeWidth: 2,
        ),
      );
    }

    return polygons;
  }

  Set<Polyline> get _routeLines {
    final car = _carPosition;
    final destination = _destination;
    if (car == null || destination == null) return const <Polyline>{};
    final points = _routePoints.length > 1
        ? [car, ..._routePoints.skip(1)]
        : [car, destination];
    return {
      Polyline(
        polylineId: const PolylineId('mission-route-base'),
        points: points,
        color: const Color(0xFF123D2C),
        width: 15,
        jointType: JointType.round,
      ),
      Polyline(
        polylineId: const PolylineId('mission-route-center'),
        points: points,
        color: Colors.greenAccent,
        width: 7,
        jointType: JointType.round,
        patterns: [PatternItem.dash(22), PatternItem.gap(8)],
      ),
    };
  }

  Future<void> _showFullRoute(List<LatLng> points) async {
    if (points.length < 2 || _controller == null) return;
    var minLat = points.first.latitude;
    var maxLat = minLat;
    var minLng = points.first.longitude;
    var maxLng = minLng;
    for (final point in points.skip(1)) {
      minLat = math.min(minLat, point.latitude);
      maxLat = math.max(maxLat, point.latitude);
      minLng = math.min(minLng, point.longitude);
      maxLng = math.max(maxLng, point.longitude);
    }
    final bounds = LatLngBounds(
      southwest: LatLng(minLat, minLng),
      northeast: LatLng(maxLat, maxLng),
    );
    await _controller!.animateCamera(CameraUpdate.newLatLngBounds(bounds, 90));
  }

  double? get _missionDistanceMeters {
    final car = _carPosition;
    final destination = _destination;
    if (car == null || destination == null) return null;
    final north = (destination.latitude - car.latitude) * 111320;
    final east = (destination.longitude - car.longitude) *
        111320 * math.cos(car.latitude * math.pi / 180);
    return math.sqrt(north * north + east * east);
  }

  void _setDestination(LatLng destination) {
    setState(() {
      _destination = destination;
      _destinationName ??= 'Pinned destination';
      _missionScore = 1000;
      _routePoints = [_carPosition ?? destination, destination];
    });
    _controller?.animateCamera(CameraUpdate.newLatLng(destination));
    _loadRoadRoute(destination);
  }

  void _clearDestination() {
    setState(() {
      _destination = null;
      _destinationName = null;
      _missionScore = 0;
      _routePoints = const [];
    });
  }

  Future<void> _loadRoadRoute(LatLng destination) async {
    final origin = _carPosition;
    if (origin == null) return;
    setState(() => _loadingRoute = true);
    try {
      final uri = Uri.https('maps.googleapis.com', '/maps/api/directions/json', {
        'origin': '${origin.latitude},${origin.longitude}',
        'destination': '${destination.latitude},${destination.longitude}',
        'mode': 'driving',
        'alternatives': 'true',
        'key': _mapsApiKey,
      });
      final response = await http.get(uri);
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final routes = data['routes'] as List<dynamic>? ?? const [];
      if (response.statusCode != 200 || routes.isEmpty) {
        throw Exception('No driving route found');
      }
      final route = routes.cast<Map<String, dynamic>>().reduce((shortest, candidate) {
        int routeDistance(Map<String, dynamic> value) {
          final legs = value['legs'] as List<dynamic>? ?? const [];
          return legs.fold<int>(0, (total, leg) {
            final distance = (leg as Map<String, dynamic>)['distance']
                as Map<String, dynamic>?;
            return total + ((distance?['value'] as num?)?.toInt() ?? 0);
          });
        }

        return routeDistance(candidate) < routeDistance(shortest)
            ? candidate
            : shortest;
      });
      final overview = route['overview_polyline'] as Map<String, dynamic>;
      final encoded = overview['points'] as String?;
      if (encoded == null || encoded.isEmpty) throw Exception('Empty route');
      final points = _decodePolyline(encoded);
      if (!mounted) return;
      setState(() {
        _routePoints = points;
        _roadReady = points.length > 1;
        if (_roadReady) {
          _startPosition = points.first;
          _carPosition = points.first;
          _heading = _bearingRadians(points[0], points[1]);
        }
        _loadingRoute = false;
      });
      await _showFullRoute(points);
      if (_roadReady) {
        await _controller?.animateCamera(
          CameraUpdate.newCameraPosition(
            CameraPosition(target: points.first, zoom: 19, tilt: 40),
          ),
        );
      }
    } catch (_) {
      if (mounted) setState(() => _loadingRoute = false);
    }
  }

  List<LatLng> _decodePolyline(String encoded) {
    final points = <LatLng>[];
    var index = 0;
    var latitude = 0;
    var longitude = 0;

    while (index < encoded.length) {
      var shift = 0;
      var result = 0;
      int byte;
      do {
        byte = encoded.codeUnitAt(index++) - 63;
        result |= (byte & 0x1f) << shift;
        shift += 5;
      } while (byte >= 0x20 && index < encoded.length);
      latitude += (result & 1) != 0 ? ~(result >> 1) : result >> 1;

      shift = 0;
      result = 0;
      do {
        byte = encoded.codeUnitAt(index++) - 63;
        result |= (byte & 0x1f) << shift;
        shift += 5;
      } while (byte >= 0x20 && index < encoded.length);
      longitude += (result & 1) != 0 ? ~(result >> 1) : result >> 1;

      points.add(LatLng(latitude / 1e5, longitude / 1e5));
    }
    return points;
  }

  Future<void> _searchLocation(String query) async {
    final text = query.trim();
    if (text.isEmpty || _searching) return;
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => _searching = true);

    try {
      final uri = Uri.https('maps.googleapis.com', '/maps/api/geocode/json', {
        'address': text,
        'key': _mapsApiKey,
      });
      final response = await http.get(uri);
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final results = data['results'] as List<dynamic>? ?? const [];
      final apiStatus = data['status'] as String? ?? 'UNKNOWN_ERROR';
      if (response.statusCode != 200 || apiStatus != 'OK' || results.isEmpty) {
        final message = switch (apiStatus) {
          'REQUEST_DENIED' =>
            'Google denied the search. Enable Geocoding API for this key.',
          'OVER_QUERY_LIMIT' => 'Search limit reached. Try again later.',
          'ZERO_RESULTS' =>
            'Location not found. Try a city, street, or landmark.',
          _ => 'Location search failed ($apiStatus). Check your internet connection.',
        };
        throw Exception(message);
      }

      final first = results.first as Map<String, dynamic>;
      final geometry = first['geometry'] as Map<String, dynamic>;
      final location = geometry['location'] as Map<String, dynamic>;
      final destination = LatLng(
        (location['lat'] as num).toDouble(),
        (location['lng'] as num).toDouble(),
      );
      if (!mounted) return;
      setState(() {
        _destination = destination;
        _destinationName = first['formatted_address'] as String? ?? text;
        _missionScore = 1000;
        _routePoints = [_carPosition ?? destination, destination];
        _searching = false;
      });
      _loadRoadRoute(destination);
      await _controller?.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(target: destination, zoom: 16, tilt: 35),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _searching = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString().replaceFirst('Exception: ', ''))),
      );
    }
  }

  void _updateCar() {
    final position = _carPosition;
    if (!mounted || position == null) return;

    const dt = .05;
    if (_driveInput != 0) {
      final acceleration = widget.car.acceleration / 35;
      final maximum = _driveInput > 0
          ? widget.car.maxForwardSpeed / 30
          : widget.car.maxReverseSpeed / 30;
      _speed += acceleration * dt * _driveInput;
      _speed = _speed.clamp(-maximum, maximum);
    } else {
      _speed = _speed.sign * math.max(0, _speed.abs() - 18 * dt);
    }
    if (_brake) {
      _speed = _speed.sign * math.max(0, _speed.abs() - 35 * dt);
    }
    _heading += _steering * 1.8 * dt * (_speed.abs() / 24).clamp(0.0, 1.0) *
        (_speed >= 0 ? 1 : -1);

    final meters = _speed * dt;
    final latitude = position.latitude +
        math.cos(_heading) * meters / 111320;
    final longitude = position.longitude +
        math.sin(_heading) *
            meters /
            (111320 * math.cos(position.latitude * math.pi / 180));
    final next = LatLng(latitude, longitude);

    setState(() => _carPosition = next);
    if (_hitBuilding(next)) {
      _handleBuildingCollision(roadside: false);
      return;
    }

    if (_leftRoad(next)) {
      _handleBuildingCollision(roadside: true);
      return;
    }
    if ((_missionDistanceMeters ?? double.infinity) < 12) {
      _completeMission();
      return;
    }
    _cameraUpdateCounter++;
    if (_cameraUpdateCounter % 4 == 0) {
      _controller?.moveCamera(CameraUpdate.newLatLng(next));
    }
  }

  bool _leftRoad(LatLng position) {
    if (!_roadReady || _routePoints.length < 2) return false;
    var closest = double.infinity;
    for (var index = 0; index < _routePoints.length - 1; index++) {
      final start = _routePoints[index];
      final end = _routePoints[index + 1];
      final distance = _distanceToSegmentMeters(position, start, end);
      closest = math.min(closest, distance);
    }
    return closest > 22;
  }

  double _distanceToSegmentMeters(LatLng point, LatLng start, LatLng end) {
    final latitudeScale = 111320.0;
    final longitudeScale =
        111320 * math.cos(point.latitude * math.pi / 180);
    final px = point.longitude * longitudeScale;
    final py = point.latitude * latitudeScale;
    final ax = start.longitude * longitudeScale;
    final ay = start.latitude * latitudeScale;
    final bx = end.longitude * longitudeScale;
    final by = end.latitude * latitudeScale;
    final dx = bx - ax;
    final dy = by - ay;
    final lengthSquared = dx * dx + dy * dy;
    if (lengthSquared == 0) {
      return math.sqrt((px - ax) * (px - ax) + (py - ay) * (py - ay));
    }
    final projection = (((px - ax) * dx) + ((py - ay) * dy)) / lengthSquared;
    final clamped = projection.clamp(0.0, 1.0);
    final closestX = ax + clamped * dx;
    final closestY = ay + clamped * dy;
    return math.sqrt(
      (px - closestX) * (px - closestX) +
          (py - closestY) * (py - closestY),
    );
  }

  Future<void> _completeMission() async {
    if (_missionDialogShowing || !mounted) return;
    _missionDialogShowing = true;
    _driveInput = 0;
    _speed = 0;
    final score = _missionScore +
      math.max(0, 500 - ((_missionDistanceMeters ?? 0) / 10).round());
    final destinationName = _destinationName ?? 'destination';
    setState(() => _destination = null);
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Ride complete!'),
        content: Text(
          'You reached $destinationName. Your ride mission is completed and you are ready for the next ride.',
        ),
        icon: const Icon(Icons.emoji_events_rounded,
            color: Colors.amber, size: 42),
        actions: [
          FilledButton.icon(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.route_rounded),
            label: Text('NEXT RIDE  +$score'),
          ),
        ],
      ),
    );
    _missionDialogShowing = false;
  }

  bool _hitBuilding(LatLng position) {
    final start = _startPosition;
    if (start == null) return false;

    // Car collision box in local meter coordinates.
    final northMeters = (position.latitude - start.latitude) * 111320;
    final eastMeters = (position.longitude - start.longitude) *
        111320 * math.cos(start.latitude * math.pi / 180);

    final carBounds = Rect.fromCenter(
      center: Offset(eastMeters, northMeters),
      width: 5,
      height: 9,
    );

    // Keep a few guaranteed obstacles near the starting area.
    const fixedBuildings = [
      Rect.fromLTWH(-45, 70, 55, 42),
      Rect.fromLTWH(38, 135, 58, 45),
      Rect.fromLTWH(-105, 190, 62, 48),
      Rect.fromLTWH(75, -100, 60, 50),
    ];

    if (fixedBuildings.any((building) => carBounds.overlaps(building))) {
      return true;
    }

    // Check the generated buildings beside the real Google driving route.
    final route = _routePoints;
    if (route.length < 2) return false;

    const buildingWidth = 16.0;
    const buildingLength = 24.0;

    for (var i = 1; i < route.length - 1; i += 8) {
      final a = route[i];
      final b = route[i + 1];

      final ax = (a.longitude - start.longitude) *
          111320 *
          math.cos(start.latitude * math.pi / 180);
      final ay = (a.latitude - start.latitude) * 111320;
      final bx = (b.longitude - start.longitude) *
          111320 *
          math.cos(start.latitude * math.pi / 180);
      final by = (b.latitude - start.latitude) * 111320;

      final dx = bx - ax;
      final dy = by - ay;
      final length = math.sqrt(dx * dx + dy * dy);
      if (length < 1) continue;

      final ux = dx / length;
      final uy = dy / length;
      final nx = -uy;
      final ny = ux;

      final side = (i ~/ 8).isEven ? 1.0 : -1.0;
      final center = Offset(
        ax + nx * 27 * side,
        ay + ny * 27 * side,
      );

      final building = Rect.fromCenter(
        center: center,
        width: buildingLength,
        height: buildingWidth,
      );

      // Convert the car point into the building's road-aligned coordinates.
      final rx = eastMeters - center.dx;
      final ry = northMeters - center.dy;
      final localAlong = rx * ux + ry * uy;
      final localAcross = rx * nx + ry * ny;

      final localCar = Rect.fromCenter(
        center: Offset(localAlong, localAcross),
        width: 5,
        height: 9,
      );

      if (localCar.overlaps(
        Rect.fromCenter(
          center: Offset.zero,
          width: building.width,
          height: building.height,
        ),
      )) {
        return true;
      }
    }

    return false;
  }

  Future<void> _handleBuildingCollision({required bool roadside}) async {
    if (_collisionDialogShowing || !mounted) return;

    _collisionDialogShowing = true;
    _driveInput = 0;
    _speed = 0;
    _steering = 0;
    _brake = false;

    final start = _startPosition;
    if (start != null) {
      final initialHeading = _routePoints.length > 1
          ? _bearingRadians(_routePoints[0], _routePoints[1])
          : 0.0;

      setState(() {
        _carPosition = start;
        _heading = initialHeading;
      });

      await _controller?.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: start,
            zoom: 19,
            tilt: 45,
            bearing: _heading * 180 / math.pi,
          ),
        ),
      );
    }

    if (!mounted) return;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text(
          'POLICE ARRESTED YOU',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        content: Text(
          roadside
              ? 'Rash driving detected. You left the road and the police arrested you. Your mission will start again from the beginning.'
              : 'You crashed into a building while driving rashly. The police arrested you. Your mission will start again from the beginning.',
        ),
        icon: const Icon(
          Icons.local_police_rounded,
          color: Colors.redAccent,
          size: 52,
        ),
        actions: [
          FilledButton.icon(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.restart_alt_rounded),
            label: const Text('START FROM BEGINNING'),
          ),
        ],
      ),
    );

    _collisionDialogShowing = false;
  }

  double _bearingRadians(LatLng a, LatLng b) {
    final dLon = (b.longitude - a.longitude) * math.pi / 180;
    final lat1 = a.latitude * math.pi / 180;
    final lat2 = b.latitude * math.pi / 180;

    final y = math.sin(dLon) * math.cos(lat2);
    final x = math.cos(lat1) * math.sin(lat2) -
        math.sin(lat1) * math.cos(lat2) * math.cos(dLon);

    return math.atan2(y, x);
  }

  void _setDriveInput(double value) => setState(() => _driveInput = value);

  void _setSteering(double value) => setState(() => _steering = value);

  void _setBrake(bool value) => setState(() => _brake = value);

  void _setHorn(bool value) => setState(() => _horn = value);

  KeyEventResult _handleKeyboard(KeyEvent event) {
    if (_searchFocusNode.hasFocus) return KeyEventResult.ignored;
    final isDown = event is KeyDownEvent || event is KeyRepeatEvent;
    final isUp = event is KeyUpEvent;
    if (!isDown && !isUp) return KeyEventResult.ignored;

    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.arrowLeft || key == LogicalKeyboardKey.keyA) {
      _setSteering(isUp ? 0 : -1);
    } else if (key == LogicalKeyboardKey.arrowRight ||
        key == LogicalKeyboardKey.keyD) {
      _setSteering(isUp ? 0 : 1);
    } else if (key == LogicalKeyboardKey.arrowUp ||
        key == LogicalKeyboardKey.keyW) {
      _setDriveInput(isUp ? 0 : 1);
    } else if (key == LogicalKeyboardKey.arrowDown ||
        key == LogicalKeyboardKey.keyS) {
      _setDriveInput(isUp ? 0 : -1);
    } else if (key == LogicalKeyboardKey.space) {
      _setBrake(!isUp);
    } else if (key == LogicalKeyboardKey.keyH) {
      _setHorn(!isUp);
    } else {
      return KeyEventResult.ignored;
    }
    return KeyEventResult.handled;
  }

  Widget _driveControls() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
        child: Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(.52),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: Colors.white24),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _controlButton(
                      icon: Icons.arrow_back_rounded,
                      label: 'LEFT',
                      onStart: () => _setSteering(-1),
                      onEnd: () => _setSteering(0),
                    ),
                    const SizedBox(width: 16),
                    _controlButton(
                      icon: Icons.arrow_forward_rounded,
                      label: 'RIGHT',
                      onStart: () => _setSteering(1),
                      onEnd: () => _setSteering(0),
                    ),
                  ],
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _controlButton(
                          icon: Icons.arrow_upward_rounded,
                          label: 'DRIVE',
                          accent: Colors.greenAccent,
                          onStart: () => _setDriveInput(1),
                          onEnd: () => _setDriveInput(0),
                        ),
                        const SizedBox(width: 6),
                        _controlButton(
                          icon: Icons.stop_circle_outlined,
                          label: 'BRAKE',
                          accent: Colors.redAccent,
                          onStart: () => _setBrake(true),
                          onEnd: () => _setBrake(false),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _controlButton(
                          icon: Icons.arrow_downward_rounded,
                          label: 'REVERSE',
                          accent: Colors.orangeAccent,
                          onStart: () => _setDriveInput(-1),
                          onEnd: () => _setDriveInput(0),
                        ),
                        const SizedBox(width: 6),
                        _controlButton(
                          icon: Icons.volume_up_rounded,
                          label: 'HORN',
                          onStart: () => _setHorn(true),
                          onEnd: () => _setHorn(false),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _controlButton({
    required IconData icon,
    required String label,
    Color accent = Colors.white,
    required VoidCallback onStart,
    required VoidCallback onEnd,
  }) {
    return GestureDetector(
      onTapDown: (_) => onStart(),
      onTapUp: (_) => onEnd(),
      onTapCancel: onEnd,
      child: Container(
        width: 60,
        height: 60,
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(.75),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white38),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: accent, size: 25),
            Text(label, style: TextStyle(color: accent, fontSize: 8)),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final position = _position;
    if (!_mapSupported) {
      return Scaffold(
        appBar: AppBar(title: const Text('Current Location')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.phone_android_rounded,
                    size: 64, color: Colors.greenAccent),
                const SizedBox(height: 16),
                const Text(
                  'Satellite driving is available on Android, iOS, or Chrome.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text(
                  'The Windows desktop target does not support the Google Maps plugin. Run the app on the connected Android phone with: flutter run -d HA26D5PQ',
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.car.name} Drive'),
        actions: [
          IconButton(
            tooltip: 'Refresh location',
            onPressed: _loadCurrentLocation,
            icon: const Icon(Icons.my_location_rounded),
          ),
        ],
      ),
      body: Focus(
        autofocus: true,
        onKeyEvent: (_, event) => _handleKeyboard(event),
        child: Stack(
          children: [
          GoogleMap(
            mapType: MapType.satellite,
            initialCameraPosition: position == null
                ? _fallbackCamera
                : _cameraFor(position),
            onMapCreated: _onMapCreated,
            myLocationEnabled: false,
            myLocationButtonEnabled: true,
            zoomControlsEnabled: false,
            compassEnabled: true,
            buildingsEnabled: true,
            mapToolbarEnabled: false,
            rotateGesturesEnabled: true,
            trafficEnabled: false,
            padding: const EdgeInsets.only(top: 76, bottom: 170),
            markers: _markers,
            polygons: _buildingPolygons,
            polylines: _routeLines,
            onLongPress: _setDestination,
          ),
          _zoomControls(),
          _searchPanel(),
          if (_destination != null && _error == null)
            Positioned(
              top: 78,
              left: 14,
              child: _missionCard(),
            ),
          if (_carPosition != null && _error == null)
            IgnorePointer(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(.78),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        'YOUR CAR',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Transform.rotate(
                      angle: _heading,
                      child: SizedBox(
                        width: 58,
                        height: 104,
                        child: CustomPaint(
                          painter: MapCarPainter(color: widget.car.color),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          if (_loading)
            const Center(child: CircularProgressIndicator()),
          if (_error != null)
            Positioned(
              left: 16,
              right: 16,
              bottom: 24,
              child: Card(
                color: Colors.black.withOpacity(.82),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      const Icon(Icons.location_off, color: Colors.orangeAccent),
                      const SizedBox(width: 12),
                      Expanded(child: Text(_error!)),
                      TextButton(
                        onPressed: _loadCurrentLocation,
                        child: const Text('RETRY'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          if (_carPosition != null && _error == null)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: _driveControls(),
            ),
          if (_horn)
            const Positioned(
              top: 86,
              left: 0,
              right: 0,
              child: Center(
                child: Text('HORN',
                    style: TextStyle(
                        color: Colors.yellowAccent,
                        fontWeight: FontWeight.w900,
                        fontSize: 24)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _missionCard() {
    final distance = _missionDistanceMeters ?? 0;
    return Card(
      color: Colors.black.withOpacity(.82),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.flag_rounded, color: Colors.redAccent),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('MISSION: REACH THE PIN',
                    style: TextStyle(fontWeight: FontWeight.w800)),
                if (_destinationName != null)
                  SizedBox(
                    width: 230,
                    child: Text(
                      _destinationName!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white70),
                    ),
                  ),
                Text('${distance.toStringAsFixed(0)} m remaining',
                    style: const TextStyle(color: Colors.white70)),
                if (_loadingRoute)
                  const Text('Finding the shortest road route...',
                      style: TextStyle(color: Colors.greenAccent, fontSize: 11)),
              ],
            ),
            IconButton(
              tooltip: 'Clear mission',
              onPressed: _clearDestination,
              icon: const Icon(Icons.close, size: 20),
            ),
          ],
        ),
      ),
    );
  }

  Widget _searchPanel() {
    return Positioned(
      top: 14,
      left: 14,
      right: 70,
      child: Material(
        color: Colors.black.withOpacity(.84),
        borderRadius: BorderRadius.circular(18),
        elevation: 8,
        child: TextField(
          controller: _searchController,
          focusNode: _searchFocusNode,
          textInputAction: TextInputAction.search,
          onSubmitted: _searchLocation,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: 'Search a place for your next ride',
            hintStyle: const TextStyle(color: Colors.white60),
            prefixIcon: const Icon(Icons.search_rounded,
                color: Colors.greenAccent),
            suffixIcon: _searching
                ? const Padding(
                    padding: EdgeInsets.all(13),
                    child: SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : IconButton(
                    tooltip: 'Search destination',
                    onPressed: () => _searchLocation(_searchController.text),
                    icon: const Icon(Icons.arrow_forward_rounded),
                  ),
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(vertical: 16),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _driveTimer?.cancel();
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }
}

class MapCarPainter extends CustomPainter {
  const MapCarPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final shadow = Paint()..color = Colors.black.withOpacity(.5);
    canvas.drawOval(
      Rect.fromCenter(
        center: center.translate(0, 3),
        width: 42,
        height: 96,
      ),
      shadow,
    );

    final tire = Paint()..color = const Color(0xFF0A0C10);
    for (final offset in const [
      Offset(-25, -33),
      Offset(14, -33),
      Offset(-25, 25),
      Offset(14, 25),
    ]) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(center.dx + offset.dx, center.dy + offset.dy, 11, 22),
          const Radius.circular(4),
        ),
        tire,
      );
    }

    final bodyBounds = Rect.fromCenter(
      center: center,
      width: 42,
      height: 96,
    );
    final bodyPath = Path()
      ..moveTo(center.dx, center.dy - 48)
      ..cubicTo(center.dx + 15, center.dy - 47, center.dx + 20,
          center.dy - 36, center.dx + 19, center.dy - 20)
      ..lineTo(center.dx + 18, center.dy + 31)
      ..cubicTo(center.dx + 17, center.dy + 43, center.dx + 10,
          center.dy + 48, center.dx, center.dy + 48)
      ..cubicTo(center.dx - 10, center.dy + 48, center.dx - 17,
          center.dy + 43, center.dx - 18, center.dy + 31)
      ..lineTo(center.dx - 19, center.dy - 20)
      ..cubicTo(center.dx - 20, center.dy - 36, center.dx - 15,
          center.dy - 47, center.dx, center.dy - 48)
      ..close();
    final body = Paint()
      ..shader = LinearGradient(
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
        colors: [color.withValues(alpha: .62), color, color.withValues(alpha: .72)],
      ).createShader(bodyBounds);
    canvas.drawPath(bodyPath, body);
    canvas.drawPath(
      bodyPath,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..color = Colors.white.withOpacity(.48),
    );

    final glass = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFFBDEBF5), Color(0xFF315A69)],
      ).createShader(bodyBounds);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: center.translate(0, -14),
          width: 28,
          height: 39,
        ),
        const Radius.circular(8),
      ),
      glass,
    );

    final windowDivider = Paint()
      ..color = Colors.white.withOpacity(.35)
      ..strokeWidth = 1;
    canvas.drawLine(
      center.translate(-13, -14),
      center.translate(13, -14),
      windowDivider,
    );

    final rim = Paint()..color = const Color(0xFFBFC7CC);
    for (final offset in const [
      Offset(-19, -28),
      Offset(19, -28),
      Offset(-19, 31),
      Offset(19, 31),
    ]) {
      canvas.drawCircle(center.translate(offset.dx, offset.dy), 3.5, rim);
      canvas.drawCircle(
        center.translate(offset.dx, offset.dy),
        1.5,
        Paint()..color = const Color(0xFF444A50),
      );
    }

    final headlight = Paint()..color = const Color(0xFFFFF2A8);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: center.translate(-10, -42), width: 7, height: 4),
        const Radius.circular(2),
      ),
      headlight,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: center.translate(10, -42), width: 7, height: 4),
        const Radius.circular(2),
      ),
      headlight,
    );

    final tailLight = Paint()..color = const Color(0xFFE53935);
    canvas.drawCircle(center.translate(-10, 43), 3, tailLight);
    canvas.drawCircle(center.translate(10, 43), 3, tailLight);
  }

  @override
  bool shouldRepaint(covariant MapCarPainter oldDelegate) => oldDelegate.color != color;
}