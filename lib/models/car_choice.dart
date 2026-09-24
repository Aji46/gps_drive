import 'package:flutter/material.dart';

class CarChoice {
  final String name;
  final Color color;
  final double acceleration;
  final double maxForwardSpeed;
  final double maxReverseSpeed;
  final String description;

  const CarChoice({
    required this.name,
    required this.color,
    required this.acceleration,
    required this.maxForwardSpeed,
    required this.maxReverseSpeed,
    required this.description,
  });
}
