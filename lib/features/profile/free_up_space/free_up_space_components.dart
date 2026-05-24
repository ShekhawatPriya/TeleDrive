part of '../free_up_space_screen.dart';

class _FreeUpInfoRow extends StatelessWidget {
  const _FreeUpInfoRow({required this.icon, required this.titleWidget});

  final IconData icon;
  final Widget titleWidget;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: scheme.primary, size: 26),
          const SizedBox(width: AppSpacing.lg),
          Expanded(child: titleWidget),
        ],
      ),
    );
  }
}
