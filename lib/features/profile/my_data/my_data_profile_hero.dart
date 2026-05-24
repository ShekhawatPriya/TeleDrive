part of '../my_data_screen.dart';

class _MyDataProfileHero extends StatelessWidget {
  const _MyDataProfileHero({
    required this.user,
    required this.usedStorage,
    required this.fileCount,
    required this.folderCount,
  });

  final AuthUser? user;
  final String usedStorage;
  final int fileCount;
  final int folderCount;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final displayName = user != null
        ? '${user!.firstName} ${user!.lastName}'.trim()
        : 'TeleDrive Member';
    final accountLabel = user?.username != null && user!.username!.isNotEmpty
        ? '@${user!.username}'
        : 'Secure Session';

    return Container(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        children: [
          Row(
            children: [
              ProfileAvatar(user: user, size: 54),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      displayName,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      accountLabel,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF30D158).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(100),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _PulsingStatusDot(),
                    SizedBox(width: 6),
                    Text(
                      'Synced',
                      style: TextStyle(
                        color: Color(0xFF30D158),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg + 4),
          const Divider(height: 1),
          const SizedBox(height: AppSpacing.lg),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _MyDataStatColumn(value: usedStorage, label: 'Cloud Storage'),
              const _MyDataStatDivider(),
              _MyDataStatColumn(value: '$fileCount', label: 'Files Synced'),
              const _MyDataStatDivider(),
              _MyDataStatColumn(value: '$folderCount', label: 'Folders'),
            ],
          ),
        ],
      ),
    );
  }
}

class _MyDataStatColumn extends StatelessWidget {
  const _MyDataStatColumn({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
              color: scheme.primary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: scheme.onSurfaceVariant,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _MyDataStatDivider extends StatelessWidget {
  const _MyDataStatDivider();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: 1,
      height: 32,
      color: scheme.outlineVariant.withValues(alpha: 0.5),
    );
  }
}

class _PulsingStatusDot extends StatefulWidget {
  const _PulsingStatusDot();

  @override
  State<_PulsingStatusDot> createState() => _PulsingStatusDotState();
}

class _PulsingStatusDotState extends State<_PulsingStatusDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat(reverse: true);
    _animation = Tween<double>(
      begin: 3.0,
      end: 8.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(
            color: const Color(0xFF30D158),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF30D158).withValues(alpha: 0.45),
                blurRadius: _animation.value,
                spreadRadius: _animation.value / 2.5,
              ),
            ],
          ),
        );
      },
    );
  }
}
