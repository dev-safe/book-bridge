import 'package:flutter/material.dart';

class Category {
  final String name;
  final IconData icon;
  final Color color;

  const Category({required this.name, required this.icon, required this.color});
}

const List<Category> appCategories = [
  Category(name: 'Textbooks', icon: Icons.school_rounded, color: Colors.blue),
  Category(
    name: 'Fiction',
    icon: Icons.auto_stories_rounded,
    color: Colors.purple,
  ),
  Category(name: 'Science', icon: Icons.science_rounded, color: Colors.teal),
  Category(
    name: 'History',
    icon: Icons.history_edu_rounded,
    color: Colors.brown,
  ),
  Category(name: 'GCE', icon: Icons.assignment_rounded, color: Colors.orange),
  Category(
    name: 'Business',
    icon: Icons.business_center_rounded,
    color: Colors.indigo,
  ),
  Category(
    name: 'Technology',
    icon: Icons.computer_rounded,
    color: Colors.cyan,
  ),
  Category(name: 'Arts', icon: Icons.palette_rounded, color: Colors.pink),
  Category(name: 'Language', icon: Icons.language_rounded, color: Colors.green),
  Category(
    name: 'Mathematics',
    icon: Icons.functions_rounded,
    color: Colors.red,
  ),
  Category(
    name: 'Engineering',
    icon: Icons.engineering_rounded,
    color: Colors.blueGrey,
  ),
  Category(
    name: 'Medicine',
    icon: Icons.medical_services_rounded,
    color: Colors.redAccent,
  ),
];
