import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';

class ThemePickerCards extends StatelessWidget {
  const ThemePickerCards({
    required this.mode,
    required this.onChanged,
    super.key,
  });

  final ThemeMode mode;
  final ValueChanged<ThemeMode> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _ThemeCard(
            label: 'Light',
            icon: Icons.light_mode_rounded,
            variant: _ThemeCardVariant.light,
            selected: mode == ThemeMode.light,
            onTap: () => onChanged(ThemeMode.light),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: _ThemeCard(
            label: 'Dark',
            icon: Icons.dark_mode_rounded,
            variant: _ThemeCardVariant.dark,
            selected: mode == ThemeMode.dark,
            onTap: () => onChanged(ThemeMode.dark),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: _ThemeCard(
            label: 'Auto',
            icon: Icons.brightness_auto_rounded,
            variant: _ThemeCardVariant.auto,
            selected: mode == ThemeMode.system,
            onTap: () => onChanged(ThemeMode.system),
          ),
        ),
      ],
    );
  }
}

enum _ThemeCardVariant { light, dark, auto }

class _ThemeCard extends StatelessWidget {
  const _ThemeCard({
    required this.label,
    required this.icon,
    required this.variant,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final _ThemeCardVariant variant;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final motion = theme.extension<AppMotion>();

    return AnimatedContainer(
      duration: motion?.durationShort ?? const Duration(milliseconds: 200),
      curve: motion?.emphasized ?? Curves.easeOutCubic,
      decoration: BoxDecoration(
        borderRadius: AppRadii.lgR,
        border: Border.all(
          color: selected ? scheme.primary : scheme.outlineVariant,
          width: selected ? 2 : 1,
        ),
        color: scheme.surfaceContainerLow,
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: AppRadii.lgR,
        child: InkWell(
          borderRadius: AppRadii.lgR,
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              vertical: AppSpacing.sm,
              horizontal: AppSpacing.xs,
            ),
            child: Column(
              children: [
                Stack(
                  children: [
                    _ThemePreview(variant: variant, icon: icon),
                    if (selected)
                      Positioned(
                        top: 4,
                        right: 4,
                        child: Container(
                          decoration: BoxDecoration(
                            color: scheme.surface,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.check_circle_rounded,
                            size: 18,
                            color: scheme.primary,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  label,
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: selected ? scheme.primary : scheme.onSurface,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ThemePreview extends StatelessWidget {
  const _ThemePreview({required this.variant, required this.icon});

  final _ThemeCardVariant variant;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1.4,
      child: ClipRRect(
        borderRadius: AppRadii.mdR,
        child: switch (variant) {
          _ThemeCardVariant.light => _previewSurface(
            bg: const Color(0xFFF7F8FA),
            barColor: const Color(0xFFE3E5EA),
            accent: const Color(0xFF1A73E8),
            icon: icon,
            iconColor: const Color(0xFF1A73E8),
          ),
          _ThemeCardVariant.dark => _previewSurface(
            bg: const Color(0xFF111418),
            barColor: const Color(0xFF2A2D32),
            accent: const Color(0xFF8AB4F8),
            icon: icon,
            iconColor: const Color(0xFFE3E5EA),
          ),
          _ThemeCardVariant.auto => _autoPreview(icon: icon),
        },
      ),
    );
  }

  Widget _previewSurface({
    required Color bg,
    required Color barColor,
    required Color accent,
    required IconData icon,
    required Color iconColor,
  }) {
    return Container(
      color: bg,
      padding: const EdgeInsets.all(8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 6,
            width: 26,
            decoration: BoxDecoration(
              color: accent,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          const SizedBox(height: 6),
          Container(
            height: 4,
            decoration: BoxDecoration(
              color: barColor,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 4),
          Container(
            height: 4,
            width: 32,
            decoration: BoxDecoration(
              color: barColor,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const Spacer(),
          Align(
            alignment: Alignment.bottomRight,
            child: Icon(icon, size: 18, color: iconColor),
          ),
        ],
      ),
    );
  }

  Widget _autoPreview({required IconData icon}) {
    return ClipPath(
      clipper: const _DiagonalClipper(),
      child: Stack(
        children: [
          Positioned.fill(
            child: _previewSurface(
              bg: const Color(0xFFF7F8FA),
              barColor: const Color(0xFFE3E5EA),
              accent: const Color(0xFF1A73E8),
              icon: icon,
              iconColor: const Color(0xFF1A73E8),
            ),
          ),
          Positioned.fill(
            child: ClipPath(
              clipper: const _BottomDiagonalClipper(),
              child: _previewSurface(
                bg: const Color(0xFF111418),
                barColor: const Color(0xFF2A2D32),
                accent: const Color(0xFF8AB4F8),
                icon: icon,
                iconColor: const Color(0xFFE3E5EA),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DiagonalClipper extends CustomClipper<Path> {
  const _DiagonalClipper();
  @override
  Path getClip(Size size) {
    return Path()..addRect(Offset.zero & size);
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

class _BottomDiagonalClipper extends CustomClipper<Path> {
  const _BottomDiagonalClipper();
  @override
  Path getClip(Size size) {
    return Path()
      ..moveTo(size.width, 0)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}
