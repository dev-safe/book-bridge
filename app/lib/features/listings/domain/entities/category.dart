import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';

/// Represents an academic category in BookBridge.
///
/// This entity defines the structure for categories displayed on the search screen,
/// including metadata for UI representation like icons and faculty subtitles.
class Category extends Equatable {
  final String id;
  final String name;
  final IconData icon;
  final String subtitle;

  const Category({
    required this.id,
    required this.name,
    required this.icon,
    required this.subtitle,
  });

  @override
  List<Object?> get props => [id, name, icon, subtitle];
}
