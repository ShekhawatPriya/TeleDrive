import 'package:flutter/material.dart';

class SheetActionItem {
  const SheetActionItem({
    required this.id,
    required this.label,
    required this.icon,
    this.destructive = false,
  });

  final String id;
  final String label;
  final IconData icon;
  final bool destructive;
}
