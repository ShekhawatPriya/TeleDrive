part of 'app_update_screen.dart';

enum _HeroTone { neutral, accent, success, warning }

class _StatusHero extends StatefulWidget {
  const _StatusHero({
    required this.icon,
    required this.tone,
    this.spinning = false,
  });

  final IconData icon;
  final _HeroTone tone;
  final bool spinning;

  @override
  State<_StatusHero> createState() => _StatusHeroState();
}

class _StatusHeroState extends State<_StatusHero>
    with SingleTickerProviderStateMixin {
  late final AnimationController _spin = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  );

  @override
  void initState() {
    super.initState();
    if (widget.spinning) _spin.repeat();
  }

  @override
  void didUpdateWidget(covariant _StatusHero oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.spinning && !_spin.isAnimating) {
      _spin.repeat();
    } else if (!widget.spinning && _spin.isAnimating) {
      _spin.stop();
      _spin.value = 0;
    }
  }

  @override
  void dispose() {
    _spin.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    final (Color bg, Color fg, Color ring) = switch (widget.tone) {
      _HeroTone.neutral => (
        scheme.surfaceContainerHigh,
        scheme.onSurface,
        scheme.outlineVariant,
      ),
      _HeroTone.accent => (
        scheme.primaryContainer,
        scheme.onPrimaryContainer,
        scheme.primary.withValues(alpha: 0.18),
      ),
      _HeroTone.success => (
        scheme.tertiaryContainer,
        scheme.onTertiaryContainer,
        scheme.tertiary.withValues(alpha: 0.18),
      ),
      _HeroTone.warning => (
        scheme.errorContainer,
        scheme.onErrorContainer,
        scheme.error.withValues(alpha: 0.18),
      ),
    };

    return Container(
      width: 132,
      height: 132,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: bg,
        border: Border.all(color: ring, width: 1),
      ),
      alignment: Alignment.center,
      child: RotationTransition(
        turns: _spin,
        child: Icon(widget.icon, size: 56, color: fg),
      ),
    );
  }
}
