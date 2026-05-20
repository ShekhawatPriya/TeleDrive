import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';

class LoginStepIndicator extends StatelessWidget {
  const LoginStepIndicator({
    required this.currentStep,
    required this.totalSteps,
    super.key,
  });

  final int currentStep;
  final int totalSteps;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(totalSteps, (i) {
        final isActive = i <= currentStep;
        final isCurrent = i == currentStep;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 3),
          child: AnimatedContainer(
            duration: AppDurations.medium2,
            curve: AppEasing.emphasized,
            width: isCurrent ? 32 : 8,
            height: 6,
            decoration: BoxDecoration(
              color: isActive ? scheme.primary : scheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
        );
      }),
    );
  }
}
