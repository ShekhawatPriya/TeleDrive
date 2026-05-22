import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_theme.dart';

class FaqTile extends StatefulWidget {
  const FaqTile({required this.question, required this.answer, super.key});

  final String question;
  final String answer;

  @override
  State<FaqTile> createState() => _FaqTileState();
}

class _FaqTileState extends State<FaqTile> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Card(
      elevation: 0,
      color: _expanded
          ? scheme.surfaceContainerLow
          : scheme.surfaceContainerLowest,
      shape: RoundedRectangleBorder(
        borderRadius: AppRadii.mdR,
        side: BorderSide(
          color: _expanded
              ? scheme.primary.withValues(alpha: 0.3)
              : scheme.outlineVariant.withValues(alpha: 0.4),
          width: _expanded ? 1.5 : 1,
        ),
      ),
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          setState(() {
            _expanded = !_expanded;
          });
          HapticFeedback.lightImpact();
        },
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.question,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: _expanded ? scheme.primary : scheme.onSurface,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  AnimatedRotation(
                    turns: _expanded ? 0.5 : 0.0,
                    duration: AppDurations.medium2,
                    curve: AppEasing.emphasized,
                    child: Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: _expanded
                          ? scheme.primary
                          : scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
              AnimatedCrossFade(
                firstChild: const SizedBox(width: double.infinity),
                secondChild: Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.sm, left: 2),
                  child: Text(
                    widget.answer,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                      height: 1.45,
                    ),
                  ),
                ),
                crossFadeState: _expanded
                    ? CrossFadeState.showSecond
                    : CrossFadeState.showFirst,
                duration: AppDurations.medium2,
                sizeCurve: AppEasing.emphasized,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
