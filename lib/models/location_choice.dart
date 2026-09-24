import 'dart:ui';

class LocationChoice {
  final String name;
  final String description;
  final Offset spawn;
  final double heading;
  final List<Rect> obstacles;

  const LocationChoice({
    required this.name,
    required this.description,
    required this.spawn,
    required this.heading,
    required this.obstacles,
  });
}
