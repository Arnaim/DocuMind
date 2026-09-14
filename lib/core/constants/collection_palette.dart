import 'package:flutter/material.dart';

/// Collection palette: each collection gets a stable color identity from its
/// name, drawn from the shared DocuMind accent set — University=lavender,
/// Research=mint, Work=coral, Personal=gold by default.
class CollectionPalette {
  CollectionPalette._();

  static const _colors = <Color>[
    Color(0xFF8B6FC7), // lavender  — University
    Color(0xFF1E8E7A), // mint      — Research
    Color(0xFFE8604C), // coral     — Work
    Color(0xFFB98214), // gold      — Personal
    Color(0xFFD2548C), // pink
    Color(0xFF4A2545), // plum
  ];

  /// Stable color for a collection name.
  static Color forName(String name) {
    final n = name.toLowerCase();
    if (n.contains('univers') || n.contains('study') || n.contains('school')) {
      return _colors[0];
    }
    if (n.contains('research') || n.contains('science') || n.contains('lab')) {
      return _colors[1];
    }
    if (n.contains('work') || n.contains('job') || n.contains('career')) {
      return _colors[2];
    }
    if (n.contains('person') || n.contains('home') || n.contains('life')) {
      return _colors[3];
    }
    return _colors[name.hashCode.abs() % _colors.length];
  }
}
