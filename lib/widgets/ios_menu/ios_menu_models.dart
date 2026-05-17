import 'package:flutter/widgets.dart';

class IosMenuItem {
  const IosMenuItem({
    required this.label,
    required this.onTap,
    this.trailingIcon,
    this.checked = false,
    this.subtitle,
    this.destructive = false,
  });

  final String label;
  final VoidCallback onTap;
  final IconData? trailingIcon;
  final bool checked;
  final String? subtitle;
  final bool destructive;
}

class IosMenuSection {
  const IosMenuSection(this.items);
  final List<IosMenuItem> items;
}

typedef IosMenuSectionsBuilder = List<IosMenuSection> Function(
  BuildContext context,
);
