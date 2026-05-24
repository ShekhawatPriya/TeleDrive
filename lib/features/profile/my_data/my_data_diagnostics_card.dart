part of '../my_data_screen.dart';

class _MyDataDiagnosticsCard extends StatelessWidget {
  const _MyDataDiagnosticsCard({
    required this.running,
    required this.completed,
    required this.step,
    required this.onRun,
  });

  final bool running;
  final bool completed;
  final String step;
  final VoidCallback onRun;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final successColor = const Color(0xFF30D158);

    return Container(
      decoration: BoxDecoration(
        color: scheme.primary.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: completed
              ? successColor.withValues(alpha: 0.3)
              : scheme.primary.withValues(alpha: 0.12),
        ),
      ),
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: completed
                      ? successColor.withValues(alpha: 0.1)
                      : scheme.primary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  completed
                      ? Icons.verified_user_rounded
                      : Icons.security_outlined,
                  color: completed ? successColor : scheme.primary,
                  size: 22,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Security Diagnostics',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      completed
                          ? 'Diagnostic scan successfully completed'
                          : 'Verify your session and encryption integrity',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (running || completed) ...[
            const SizedBox(height: AppSpacing.md + 4),
            Row(
              children: [
                if (running) ...[
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  const SizedBox(width: AppSpacing.md),
                ] else if (completed) ...[
                  Container(
                    width: 22,
                    height: 22,
                    alignment: Alignment.center,
                    child: Lottie.asset(
                      'assets/animations/green_tick.json',
                      repeat: false,
                      width: 22,
                      height: 22,
                      errorBuilder: (_, __, ___) => const Icon(
                        Icons.check_circle_rounded,
                        color: Color(0xFF30D158),
                        size: 20,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm + 2),
                ],
                Expanded(
                  child: Text(
                    step,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: completed ? successColor : scheme.onSurface,
                      fontWeight: completed
                          ? FontWeight.bold
                          : FontWeight.normal,
                    ),
                  ),
                ),
              ],
            ),
          ],
          if (!running) ...[
            const SizedBox(height: AppSpacing.md + 4),
            OutlinedButton(
              onPressed: onRun,
              style: OutlinedButton.styleFrom(
                side: BorderSide(
                  color: completed
                      ? successColor.withValues(alpha: 0.5)
                      : scheme.primary.withValues(alpha: 0.5),
                ),
                foregroundColor: completed ? successColor : scheme.primary,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(completed ? 'Re-run Diagnostics' : 'Run Diagnostics'),
            ),
          ],
        ],
      ),
    );
  }
}
