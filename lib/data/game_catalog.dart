import 'package:flutter/material.dart';

import '../models/car_choice.dart';
import '../models/location_choice.dart';

class GameCatalog {
  const GameCatalog._();

  static const List<CarChoice> cars = [
    CarChoice(
      name: 'Roadster',
      color: Color(0xFFDA3030),
      acceleration: 520.0,
      maxForwardSpeed: 760.0,
      maxReverseSpeed: 280.0,
      description: 'Balanced street car',
    ),
    CarChoice(
      name: 'Rally',
      color: Color(0xFF2F80ED),
      acceleration: 580.0,
      maxForwardSpeed: 820.0,
      maxReverseSpeed: 310.0,
      description: 'Fast and stable',
    ),
    CarChoice(
      name: 'Truck',
      color: Color(0xFFF2C94C),
      acceleration: 440.0,
      maxForwardSpeed: 650.0,
      maxReverseSpeed: 240.0,
      description: 'Heavy and durable',
    ),
  ];

  static const List<LocationChoice> locations = [
    LocationChoice(
      name: 'Downtown',
      description: 'Tight corners and dense blocks',
      spawn: Offset(-40, 70),
      heading: 0,
      obstacles: [
        Rect.fromLTWH(-330, -820, 150, 120),
        Rect.fromLTWH(180, -520, 160, 160),
        Rect.fromLTWH(-420, -240, 130, 180),
        Rect.fromLTWH(250, -40, 150, 180),
        Rect.fromLTWH(-310, 310, 170, 130),
        Rect.fromLTWH(120, 570, 180, 150),
        Rect.fromLTWH(-430, 760, 140, 150),
      ],
    ),
    LocationChoice(
      name: 'Industrial Park',
      description: 'Wide roads and larger turns',
      spawn: Offset(-420, 680),
      heading: 0.3,
      obstacles: [
        Rect.fromLTWH(-700, -400, 260, 170),
        Rect.fromLTWH(250, -520, 200, 200),
        Rect.fromLTWH(-580, 320, 330, 180),
        Rect.fromLTWH(400, 500, 210, 170),
        Rect.fromLTWH(-120, 150, 180, 130),
      ],
    ),
    LocationChoice(
      name: 'Coastal Route',
      description: 'Open road with a long curve',
      spawn: Offset(120, -420),
      heading: 1.2,
      obstacles: [
        Rect.fromLTWH(-500, -300, 170, 170),
        Rect.fromLTWH(220, -200, 210, 140),
        Rect.fromLTWH(-120, 300, 180, 220),
        Rect.fromLTWH(430, 120, 160, 160),
      ],
    ),
  ];
}
