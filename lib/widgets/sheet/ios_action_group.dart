import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class IosActionGroup extends StatelessWidget {
  const IosActionGroup({required this.children, super.key});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
    clipBehavior: Clip.antiAlias,
    decoration: ShapeDecoration(
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      shape: RoundedSuperellipseBorder(borderRadius: BorderRadius.circular(20)),
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < children.length; i++) ...[
          if (i > 0)
            Divider(
              height: .5,
              thickness: .5,
              indent: 16,
              color: Theme.of(context).colorScheme.outlineVariant,
            ),
          children[i],
        ],
      ],
    ),
  );
}

class IosActionRow extends StatelessWidget {
  const IosActionRow({
    required this.label,
    required this.icon,
    required this.onPressed,
    this.subtitle,
    this.destructive = false,
    super.key,
  });
  final String label;
  final String? subtitle;
  final IconData icon;
  final VoidCallback onPressed;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = destructive
        ? theme.colorScheme.error
        : theme.colorScheme.onSurface;
    return CupertinoButton(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
      onPressed: onPressed,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: color,
                    fontSize: 17,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 3),
                  Text(subtitle!, style: theme.textTheme.bodySmall),
                ],
              ],
            ),
          ),
          const SizedBox(width: 18),
          Icon(icon, size: 22, color: color),
        ],
      ),
    );
  }
}
