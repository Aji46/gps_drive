import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';

import '../models/car_choice.dart';
import '../models/location_choice.dart';

class GameScreen extends StatefulWidget {
  const GameScreen({
    super.key,
    required this.car,
    required this.location,
  });

  final CarChoice car;
  final LocationChoice location;

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen>
    with SingleTickerProviderStateMixin {
  late final TickerTicker _ticker;
  late final GameWorld world;
  Timer? _gpsTimer;
  Position? position;
  String gpsStatus = 'GPS not started';

  @override
  void initState() {
    super.initState();
    world = GameWorld(carChoice: widget.car, locationChoice: widget.location);
    _ticker = TickerTicker((_) {
      world.update(const Duration(milliseconds: 16));
      if (mounted) setState(() {});
    })..start();
    _startGps();
  }

  Future<void> _startGps() async {
    try {
      final enabled = await Geolocator.isLocationServiceEnabled();
      if (!enabled) {
        setState(() => gpsStatus = 'Location service disabled');
        return;
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        setState(() => gpsStatus = 'Location permission denied');
        return;
      }
      final p = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
      if (mounted) {
        setState(() {
          position = p;
          gpsStatus = 'GPS connected';
        });
      }
      _gpsTimer = Timer.periodic(const Duration(seconds: 3), (_) async {
        try {
          final next = await Geolocator.getCurrentPosition(
            locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.high,
            ),
          );
          if (mounted) setState(() => position = next);
        } catch (_) {}
      });
    } catch (_) {
      if (mounted) setState(() => gpsStatus = 'GPS unavailable');
    }
  }

  @override
  void dispose() {
    _gpsTimer?.cancel();
    _ticker.dispose();
    super.dispose();
  }

  void _restart() {
    setState(() => world.reset());
  }

  KeyEventResult _handleKeyboard(KeyEvent event) {
    final isDown = event is KeyDownEvent || event is KeyRepeatEvent;
    final isUp = event is KeyUpEvent;
    if (!isDown && !isUp) return KeyEventResult.ignored;

    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.arrowLeft || key == LogicalKeyboardKey.keyA) {
      world.setSteering(isUp ? 0 : -1);
    } else if (key == LogicalKeyboardKey.arrowRight ||
        key == LogicalKeyboardKey.keyD) {
      world.setSteering(isUp ? 0 : 1);
    } else if (key == LogicalKeyboardKey.arrowUp ||
        key == LogicalKeyboardKey.keyW) {
      world.throttle = isUp ? 0 : 1;
      world.reverse = false;
    } else if (key == LogicalKeyboardKey.arrowDown ||
        key == LogicalKeyboardKey.keyS) {
      world.throttle = 0;
      world.reverse = !isUp;
    } else if (key == LogicalKeyboardKey.space) {
      world.brake = !isUp;
    } else {
      return KeyEventResult.ignored;
    }
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Focus(
        autofocus: true,
        onKeyEvent: (_, event) => _handleKeyboard(event),
        child: SafeArea(
          child: Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                onPanUpdate: (details) {
                  world.setSteering(
                    (world.steering + details.delta.dx / 90).clamp(-1.0, 1.0),
                  );
                },
                onPanEnd: (_) => world.setSteering(0),
                child: CustomPaint(
                  painter: WorldPainter(world),
                ),
              ),
            ),
            Positioned(
              left: 12,
              top: 12,
              child: _hud(),
            ),
            Positioned(
              right: 14,
              top: 14,
              child: _resetButton(),
            ),
            Positioned(
              left: 20,
              bottom: 25,
              child: _steeringPad(),
            ),
            Positioned(
              right: 20,
              bottom: 25,
              child: _pedals(),
            ),
            if (world.gameOver) Positioned.fill(child: _gameOver()),
          ],
          ),
        ),
      ),
    );
  }

  Widget _hud() {
    return Container(
      width: 235,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(.72),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('TUMBLER DRIVE',
              style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.2)),
          const SizedBox(height: 5),
          Text('${world.speedKmh.toStringAsFixed(0)} km/h'),
          Text('Car: ${world.carChoice.name}'),
          Text('Location: ${world.locationChoice.name}'),
          Text('Distance: ${world.distanceMeters.toStringAsFixed(0)} m'),
          Text('Surface: ${world.surfaceName}'),
          const Divider(color: Colors.white24),
          Text(gpsStatus,
              style: TextStyle(
                color: position != null ? Colors.greenAccent : Colors.orangeAccent,
                fontSize: 12,
              )),
          if (position != null) ...[
            Text('Lat: ${position!.latitude.toStringAsFixed(6)}',
                style: const TextStyle(fontSize: 11)),
            Text('Lon: ${position!.longitude.toStringAsFixed(6)}',
                style: const TextStyle(fontSize: 11)),
          ],
        ],
      ),
    );
  }

  Widget _resetButton() => FloatingActionButton.small(
        heroTag: 'reset',
        backgroundColor: Colors.black87,
        onPressed: _restart,
        child: const Icon(Icons.refresh),
      );

  Widget _steeringPad() {
    return Container(
      width: 155,
      height: 155,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.black.withOpacity(.52),
        border: Border.all(color: Colors.white30, width: 2),
      ),
      child: GestureDetector(
        onPanUpdate: (d) {
          world.setSteering(
              (world.steering + d.delta.dx / 45).clamp(-1.0, 1.0));
        },
        onPanEnd: (_) => world.setSteering(0),
        child: Center(
          child: Transform.translate(
            offset: Offset(world.steering * 38, 0),
            child: Container(
              width: 70,
              height: 70,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white12,
              ),
              child: const Icon(Icons.swap_horiz, size: 42),
            ),
          ),
        ),
      ),
    );
  }

  Widget _pedals() {
    return Column(
      children: [
        _pedal(Icons.arrow_upward, 'THROTTLE', () {
          world.throttle = 1;
          world.reverse = false;
        }),
        const SizedBox(height: 10),
        _pedal(Icons.arrow_downward, 'REVERSE', () {
          world.throttle = 0;
          world.reverse = true;
        }),
        const SizedBox(height: 10),
        _pedal(Icons.stop, 'BRAKE', () => world.brake = true),
        const SizedBox(height: 8),
        Row(
          children: [
            _release(() {
              world.throttle = 0;
              world.reverse = false;
            }),
            const SizedBox(width: 8),
            _release(() => world.brake = false),
          ],
        ),
      ],
    );
  }

  Widget _pedal(IconData icon, String label, VoidCallback onDown) {
    return GestureDetector(
      onTapDown: (_) => onDown(),
      onTapUp: (_) {
        if (label == 'THROTTLE') world.throttle = 0;
        if (label == 'REVERSE') world.reverse = false;
        if (label == 'BRAKE') world.brake = false;
      },
      onTapCancel: () {
        if (label == 'THROTTLE') world.throttle = 0;
        if (label == 'REVERSE') world.reverse = false;
        if (label == 'BRAKE') world.brake = false;
      },
      child: Container(
        width: 105,
        height: 62,
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(.7),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white24),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon),
            Text(label, style: const TextStyle(fontSize: 10)),
          ],
        ),
      ),
    );
  }

  Widget _release(VoidCallback onTap) {
    return SizedBox(
      width: 50,
      child: ElevatedButton(
        onPressed: onTap,
        child: const Icon(Icons.pause, size: 16),
      ),
    );
  }

  Widget _gameOver() {
    return Container(
      color: Colors.black.withOpacity(.78),
      child: Center(
        child: Container(
          width: 310,
          padding: const EdgeInsets.all(26),
          decoration: BoxDecoration(
            color: const Color(0xff171717),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.redAccent.withOpacity(.6)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.car_crash, color: Colors.redAccent, size: 62),
              const SizedBox(height: 10),
              const Text('GAME OVER',
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900)),
              const SizedBox(height: 8),
              Text('Crash detected\nDistance: ${world.distanceMeters.toStringAsFixed(0)} m',
                  textAlign: TextAlign.center),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: _restart,
                icon: const Icon(Icons.refresh),
                label: const Text('START AGAIN'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class TickerTicker {
  final void Function(Duration) onTick;
  Timer? _timer;
  DateTime? _last;
  TickerTicker(this.onTick);
  void start() {
    _last = DateTime.now();
    _timer = Timer.periodic(const Duration(milliseconds: 16), (_) {
      final now = DateTime.now();
      final dt = now.difference(_last!);
      _last = now;
      onTick(dt);
    });
  }
  void dispose() => _timer?.cancel();
}

class GameWorld {
  GameWorld({
    required this.carChoice,
    required this.locationChoice,
  }) {
    obstacles = List<Rect>.from(locationChoice.obstacles);
    reset();
  }

  final CarChoice carChoice;
  final LocationChoice locationChoice;

  double x = 0;
  double z = 0;
  double heading = 0;
  double velocity = 0;
  double steering = 0;
  double throttle = 0;
  bool reverse = false;
  bool brake = false;
  bool gameOver = false;
  double distanceMeters = 0;

  late List<Rect> obstacles;

  double get speedKmh => velocity.abs() * 3.6;
  String get surfaceName => (x.abs() % 850 < 350) ? 'ROAD' : 'GRASS';

  void setSteering(double value) {
    if (!gameOver) steering = value.clamp(-1.0, 1.0);
  }

  void update(Duration delta) {
    if (gameOver) return;
    final dt = delta.inMicroseconds / 1000000.0;

    final engineAcceleration = carChoice.acceleration;
    final reverseAcceleration = carChoice.maxReverseSpeed * 1.08;
    final maxForwardSpeed = carChoice.maxForwardSpeed;
    final maxReverseSpeed = carChoice.maxReverseSpeed;
    const rollingResistance = 65.0;
    const aeroDrag = 0.00085;

    if (throttle > 0) {
      velocity += engineAcceleration * throttle * dt;
    } else if (reverse) {
      velocity -= reverseAcceleration * dt;
    }

    velocity -= velocity.sign * rollingResistance * dt;
    velocity -= velocity * velocity.abs() * aeroDrag * dt;

    if (brake) {
      final braking = 16.0 * dt;
      if (velocity.abs() <= braking) {
        velocity = 0;
      } else {
        velocity -= velocity.sign * braking;
      }
    }

    velocity = velocity.clamp(-maxReverseSpeed, maxForwardSpeed);

    final steeringStrength = (velocity.abs() / maxForwardSpeed).clamp(0.0, 1.0);
    heading += steering * 1.8 * steeringStrength * dt * (velocity >= 0 ? 1 : -1);

    final oldX = x;
    final oldZ = z;
    x += math.sin(heading) * velocity * dt;
    z += math.cos(heading) * velocity * dt;
    distanceMeters += math.Point(x, z).distanceTo(math.Point(oldX, oldZ));

    final carRect = Rect.fromCenter(
      center: Offset(x, z),
      width: 28,
      height: 50,
    );

    for (final obstacle in obstacles) {
      if (carRect.overlaps(obstacle.inflate(8))) {
        gameOver = true;
        velocity = 0;
        return;
      }
    }

    if (x.abs() > 1150 || z.abs() > 1350) {
      gameOver = true;
      velocity = 0;
    }
  }

  void reset() {
    final safeSpawn = _findSafeSpawn();
    x = safeSpawn.dx;
    z = safeSpawn.dy;
    heading = locationChoice.heading;
    velocity = 0;
    steering = 0;
    throttle = 0;
    reverse = false;
    brake = false;
    gameOver = false;
    distanceMeters = 0;
    obstacles = List<Rect>.from(locationChoice.obstacles);
  }

  Offset _findSafeSpawn() {
    final start = locationChoice.spawn;
    if (!_rectCollides(Rect.fromCenter(center: start, width: 28, height: 50))) {
      return start;
    }

    for (double radius = 30; radius <= 700; radius += 30) {
      for (int step = 0; step < 360; step += 12) {
        final angle = step * math.pi / 180;
        final candidate = Offset(
          start.dx + math.cos(angle) * radius,
          start.dy + math.sin(angle) * radius,
        );

        final candidateRect = Rect.fromCenter(
          center: candidate,
          width: 28,
          height: 50,
        );

        if (!_rectCollides(candidateRect)) {
          return candidate;
        }
      }
    }

    return start;
  }

  bool _rectCollides(Rect rect) {
    return obstacles.any((obstacle) => rect.overlaps(obstacle.inflate(8)));
  }
}

class WorldPainter extends CustomPainter {
  final GameWorld world;
  WorldPainter(this.world);

  @override
  void paint(Canvas canvas, Size size) {
    final bg = Paint()..color = const Color(0xff172018);
    canvas.drawRect(Offset.zero & size, bg);

    canvas.save();
    final scale = math.min(size.width / 1200, size.height / 900);
    canvas.translate(size.width / 2, size.height / 2);
    canvas.scale(scale);
    canvas.translate(-world.x * .72, -world.z * .72);

    _drawTerrain(canvas, size);
    _drawRoads(canvas);
    _drawObstacles(canvas);
    _drawCar(canvas);

    canvas.restore();

    final vignette = Paint()
      ..shader = RadialGradient(
        colors: [Colors.transparent, Colors.black.withOpacity(.62)],
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, vignette);
  }

  void _drawTerrain(Canvas canvas, Size size) {
    final p = Paint()..color = const Color(0xff213522);
    canvas.drawRect(const Rect.fromLTWH(-1600, -1700, 3200, 3400), p);

    final grid = Paint()
      ..color = Colors.white.withOpacity(.025)
      ..strokeWidth = 1;

    for (double i = -1600; i <= 1600; i += 100) {
      canvas.drawLine(Offset(i, -1700), Offset(i, 1700), grid);
      canvas.drawLine(Offset(-1600, i), Offset(1600, i), grid);
    }
  }

  void _drawRoads(Canvas canvas) {
    final road = Paint()
      ..color = const Color(0xff303234)
      ..style = PaintingStyle.fill;

    final line = Paint()
      ..color = const Color(0xffd6c979)
      ..strokeWidth = 4;

    canvas.drawRect(const Rect.fromLTWH(-110, -1600, 220, 3200), road);
    canvas.drawRect(const Rect.fromLTWH(-1600, -110, 3200, 220), road);

    for (double y = -1600; y < 1600; y += 55) {
      canvas.drawLine(Offset(-3, y), Offset(3, y + 28), line);
    }
    for (double x = -1600; x < 1600; x += 55) {
      canvas.drawLine(Offset(x, -3), Offset(x + 28, 3), line);
    }

    final path = Path()
      ..moveTo(-900, 950)
      ..cubicTo(-500, 500, -300, 250, 100, 50)
      ..cubicTo(400, -120, 550, -500, 900, -900);

    final roadPaint = Paint()
      ..color = const Color(0xff303234)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 130;
    canvas.drawPath(path, roadPaint);

    final center = Paint()
      ..color = const Color(0xffd6c979)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    canvas.drawPath(path, center);
  }

  void _drawObstacles(Canvas canvas) {
    for (final r in world.obstacles) {
      final building = Paint()..color = const Color(0xff4a4e52);
      canvas.drawRRect(
        RRect.fromRectAndRadius(r, const Radius.circular(10)),
        building,
      );

      final roof = Paint()..color = const Color(0xff25282a);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(r.left + 12, r.top + 12, r.width - 24, r.height - 24),
          const Radius.circular(7),
        ),
        roof,
      );
    }

    for (int i = 0; i < 40; i++) {
      final px = ((i * 173) % 1800) - 900.0;
      final pz = ((i * 291) % 2200) - 1100.0;
      if (px.abs() < 145 || pz.abs() < 145) continue;
      final trunk = Paint()..color = const Color(0xff614833);
      final leaves = Paint()..color = const Color(0xff1b4a27);
      canvas.drawRect(Rect.fromLTWH(px - 3, pz, 6, 18), trunk);
      canvas.drawCircle(Offset(px, pz - 5), 20, leaves);
    }
  }

  void _drawCar(Canvas canvas) {
    canvas.save();
    canvas.translate(world.x, world.z);
    canvas.rotate(-world.heading);

    final shadow = Paint()..color = Colors.black.withOpacity(.4);
    canvas.drawOval(
      const Rect.fromLTWH(-24, -16, 48, 68),
      shadow,
    );

    final tire = Paint()..color = const Color(0xff090909);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(-25, -16, 11, 22),
        const Radius.circular(4),
      ),
      tire,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(14, -16, 11, 22),
        const Radius.circular(4),
      ),
      tire,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(-25, 25, 11, 22),
        const Radius.circular(4),
      ),
      tire,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(14, 25, 11, 22),
        const Radius.circular(4),
      ),
      tire,
    );

    final body = Paint()..color = world.carChoice.color;
    final path = Path()
      ..moveTo(-17, -27)
      ..lineTo(17, -27)
      ..lineTo(22, -8)
      ..lineTo(20, 33)
      ..lineTo(12, 46)
      ..lineTo(-12, 46)
      ..lineTo(-20, 33)
      ..lineTo(-22, -8)
      ..close();
    canvas.drawPath(path, body);

    final glass = Paint()..color = const Color(0xff3f6872);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(-13, -10, 26, 18),
        const Radius.circular(5),
      ),
      glass,
    );

    final lamp = Paint()..color = Colors.white70;
    canvas.drawCircle(const Offset(-10, -25), 3, lamp);
    canvas.drawCircle(const Offset(10, -25), 3, lamp);

    final arrow = Paint()..color = Colors.redAccent;
    final a = Path()
      ..moveTo(0, -39)
      ..lineTo(-5, -29)
      ..lineTo(5, -29)
      ..close();
    canvas.drawPath(a, arrow);

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant WorldPainter oldDelegate) => true;
}
