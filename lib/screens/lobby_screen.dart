import 'package:flutter/material.dart';

import '../data/game_catalog.dart';
import '../models/car_choice.dart';
import '../models/location_choice.dart';
import 'game_screen.dart';
import 'current_map_screen.dart';

class LobbyScreen extends StatefulWidget {
  const LobbyScreen({super.key});

  @override
  State<LobbyScreen> createState() => _LobbyScreenState();
}

class _LobbyScreenState extends State<LobbyScreen> {
  final List<CarChoice> cars = GameCatalog.cars;
  final List<LocationChoice> locations = GameCatalog.locations;

  int selectedCar = 0;
  int selectedLocation = 0;

  Future<void> _openCarSelection() async {
    final result = await Navigator.push<int>(
      context,
      MaterialPageRoute(
        builder: (_) => CarSelectionPage(
          cars: cars,
          initialIndex: selectedCar,
        ),
      ),
    );

    if (result != null && mounted) {
      setState(() => selectedCar = result);
    }
  }

  Future<void> _openMapSelection() async {
    final result = await Navigator.push<int>(
      context,
      MaterialPageRoute(
        builder: (_) => MapSelectionPage(
          locations: locations,
          initialIndex: selectedLocation,
        ),
      ),
    );

    if (result != null && mounted) {
      setState(() => selectedLocation = result);
    }
  }

  @override
  Widget build(BuildContext context) {
    final car = cars[selectedCar];
    final location = locations[selectedLocation];

    return Scaffold(
      backgroundColor: const Color(0xFF0E1116),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Container(
              width: 900,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(.35),
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: Colors.white24),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'LOBBY',
                    style: TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 2,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Choose your car and map before starting the race.',
                    style: TextStyle(color: Colors.white70),
                  ),
                  const SizedBox(height: 26),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final isCompact = constraints.maxWidth < 680;
                      return Wrap(
                        spacing: 16,
                        runSpacing: 16,
                        children: [
                          SizedBox(
                            width: isCompact
                                ? constraints.maxWidth
                                : (constraints.maxWidth - 16) / 2,
                            child: _SelectionTile(
                              title: 'Car',
                              value: car.name,
                              subtitle: car.description,
                              color: car.color,
                              icon: Icons.directions_car_rounded,
                              onTap: _openCarSelection,
                            ),
                          ),
                          SizedBox(
                            width: isCompact
                                ? constraints.maxWidth
                                : (constraints.maxWidth - 16) / 2,
                            child: _SelectionTile(
                              title: 'Map',
                              value: location.name,
                              subtitle: location.description,
                              color: Colors.greenAccent,
                              icon: Icons.map_rounded,
                              onTap: _openMapSelection,
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 30),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => CurrentMapScreen(car: car),
                          ),
                        );
                      },
                      icon: const Icon(Icons.satellite_alt_rounded),
                      label: const Text('VIEW CURRENT LOCATION MAP'),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(.04),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Selected car',
                                  style: TextStyle(color: Colors.white70)),
                              Text(car.name,
                                  style: const TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.w800)),
                            ],
                          ),
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Selected map',
                                  style: TextStyle(color: Colors.white70)),
                              Text(location.name,
                                  style: const TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.w800)),
                            ],
                          ),
                        ),
                        FilledButton.icon(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => GameScreen(
                                  car: car,
                                  location: location,
                                ),
                              ),
                            );
                          },
                          icon: const Icon(Icons.play_arrow_rounded),
                          label: const Text('START RACE'),
                        ),
                      ],
                    ),
                  )
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SelectionTile extends StatelessWidget {
  const _SelectionTile({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.color,
    required this.icon,
    required this.onTap,
  });

  final String title;
  final String value;
  final String subtitle;
  final Color color;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(.04),
          border: Border.all(color: Colors.white24),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color),
                const SizedBox(width: 8),
                Text(title,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    )),
              ],
            ),
            const SizedBox(height: 12),
            Text(value,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                )),
            const SizedBox(height: 6),
            Text(subtitle,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                )),
          ],
        ),
      ),
    );
  }
}

class CarSelectionPage extends StatefulWidget {
  const CarSelectionPage({
    super.key,
    required this.cars,
    required this.initialIndex,
  });

  final List<CarChoice> cars;
  final int initialIndex;

  @override
  State<CarSelectionPage> createState() => _CarSelectionPageState();
}

class _CarSelectionPageState extends State<CarSelectionPage> {
  late int selected = widget.initialIndex;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Choose Car'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, selected),
            child: const Text('Done'),
          ),
        ],
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: widget.cars.length,
        itemBuilder: (context, index) {
          final car = widget.cars[index];
          final isSelected = index == selected;
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Card(
              color: isSelected ? car.color.withOpacity(.12) : null,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
                side: BorderSide(
                  color: isSelected ? car.color : Colors.white24,
                  width: isSelected ? 2 : 1,
                ),
              ),
              child: ListTile(
                leading: Icon(Icons.directions_car_rounded,
                    color: car.color, size: 32),
                title: Text(car.name),
                subtitle: Text(
                    '${car.description} • ${car.maxForwardSpeed.toInt()} km/h'),
                trailing: isSelected
                    ? const Icon(Icons.check_circle, color: Colors.greenAccent)
                    : null,
                onTap: () {
                  setState(() => selected = index);
                  Navigator.pop(context, index);
                },
              ),
            ),
          );
        },
      ),
    );
  }
}

class MapSelectionPage extends StatefulWidget {
  const MapSelectionPage({
    super.key,
    required this.locations,
    required this.initialIndex,
  });

  final List<LocationChoice> locations;
  final int initialIndex;

  @override
  State<MapSelectionPage> createState() => _MapSelectionPageState();
}

class _MapSelectionPageState extends State<MapSelectionPage> {
  late int selected = widget.initialIndex;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Choose Map'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, selected),
            child: const Text('Done'),
          ),
        ],
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: widget.locations.length,
        itemBuilder: (context, index) {
          final map = widget.locations[index];
          final isSelected = index == selected;
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Card(
              color: isSelected ? Colors.green.withOpacity(.12) : null,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
                side: BorderSide(
                  color: isSelected ? Colors.greenAccent : Colors.white24,
                  width: isSelected ? 2 : 1,
                ),
              ),
              child: ListTile(
                leading: SizedBox(
                  width: 90,
                  height: 90,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: CustomPaint(
                      painter: MapPreviewPainter(map),
                    ),
                  ),
                ),
                title: Text(map.name),
                subtitle: Text(map.description),
                trailing: isSelected
                    ? const Icon(Icons.check_circle, color: Colors.greenAccent)
                    : null,
                onTap: () {
                  setState(() => selected = index);
                  Navigator.pop(context, index);
                },
              ),
            ),
          );
        },
      ),
    );
  }
}

class MapPreviewPainter extends CustomPainter {
  const MapPreviewPainter(this.location);

  final LocationChoice location;

  @override
  void paint(Canvas canvas, Size size) {
    final bg = Paint()..color = const Color(0xFF7AA65A);
    canvas.drawRect(Offset.zero & size, bg);

    final road = Paint()..color = const Color(0xFF3B3E42);
    final roadLine = Paint()
      ..color = const Color(0xFFE7D97A)
      ..strokeWidth = 2;

    canvas.drawRect(
      Rect.fromCenter(center: Offset(size.width / 2, size.height / 2), width: size.width * 0.9, height: size.height * 0.9),
      road,
    );

    // Cross roads.
    canvas.drawRect(
      Rect.fromCenter(center: Offset(size.width / 2, size.height / 2), width: 22, height: size.height * 0.9),
      road,
    );
    canvas.drawRect(
      Rect.fromCenter(center: Offset(size.width / 2, size.height / 2), width: size.width * 0.9, height: 22),
      road,
    );

    final horizontal = Paint()..color = const Color(0xFFE7D97A);
    for (double x = 10; x < size.width; x += 18) {
      canvas.drawLine(Offset(x, size.height * 0.5), Offset(x + 8, size.height * 0.5), horizontal);
    }
    for (double y = 10; y < size.height; y += 18) {
      canvas.drawLine(Offset(size.width * 0.5, y), Offset(size.width * 0.5, y + 8), horizontal);
    }

    final building = Paint()..color = const Color(0xFF4A4E52);
    for (final obstacle in location.obstacles) {
      final scaled = Rect.fromLTWH(
        ((obstacle.left + 1500) / 3000) * size.width,
        ((obstacle.top + 1800) / 3600) * size.height,
        ((obstacle.width) / 3000) * size.width,
        ((obstacle.height) / 3600) * size.height,
      );
      canvas.drawRRect(RRect.fromRectAndRadius(scaled, const Radius.circular(5)), building);
    }
  }

  @override
  bool shouldRepaint(covariant MapPreviewPainter oldDelegate) => false;
}
