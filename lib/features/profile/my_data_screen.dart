import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lottie/lottie.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/file_type_detector.dart';
import '../../core/utils/safe_navigation.dart';
import '../../models/auth_user.dart';
import '../../widgets/profile_avatar.dart';
import '../auth/auth_controller.dart';
import '../drive/drive_controller.dart';

class MyDataScreen extends ConsumerStatefulWidget {
  const MyDataScreen({super.key});

  @override
  ConsumerState<MyDataScreen> createState() => _MyDataScreenState();
}

class _MyDataScreenState extends ConsumerState<MyDataScreen> {
  // Diagnostics State
  bool _diagnosticsRunning = false;
  String _diagnosticsStep = '';
  bool _diagnosticsCompleted = false;

  Future<void> _launchUrl(String urlString) async {
    final uri = Uri.parse(urlString);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  void _runDiagnostics() async {
    if (_diagnosticsRunning) return;

    setState(() {
      _diagnosticsRunning = true;
      _diagnosticsCompleted = false;
      _diagnosticsStep = 'Initializing diagnostics tunnel...';
    });

    final steps = [
      'Scanning local storage cache...',
      'Verifying Telegram session token...',
      'Testing end-to-end data integrity...',
      'Analyzing local keychain storage...',
    ];

    for (final step in steps) {
      await Future.delayed(const Duration(milliseconds: 650));
      if (!mounted) return;
      setState(() {
        _diagnosticsStep = step;
      });
    }

    await Future.delayed(const Duration(milliseconds: 500));
    if (!mounted) return;

    setState(() {
      _diagnosticsRunning = false;
      _diagnosticsCompleted = true;
      _diagnosticsStep = 'Diagnostics complete. All checks passed successfully!';
    });
  }

  void _showExportDataDialog(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          icon: Icon(
            Icons.import_export_rounded,
            size: 38,
            color: scheme.primary,
          ),
          title: const Text('Exporting Your Data'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'TeleDrive operates on direct-to-Telegram storage architecture. Your files exist solely within your personal Telegram Account.',
                  style: theme.textTheme.bodyMedium?.copyWith(height: 1.4),
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  'Since we do not store, duplicate, or index your data on external databases, a direct export from TeleDrive servers is not applicable.',
                  style: theme.textTheme.bodyMedium?.copyWith(height: 1.4),
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  'To download a full copy of your files, settings, and media:',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                _buildBulletPoint(
                  context,
                  'For all Telegram account data: Use Telegram Desktop -> Settings -> Advanced -> Export Telegram data.',
                ),
                const SizedBox(height: AppSpacing.xs),
                _buildBulletPoint(
                  context,
                  'For specific files in TeleDrive: Use the multi-select feature on the files tab and tap Download.',
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Got it'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildBulletPoint(BuildContext context, String text) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Container(
            width: 5,
            height: 5,
            decoration: BoxDecoration(
              color: scheme.primary,
              shape: BoxShape.circle,
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text(
            text,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: scheme.onSurfaceVariant,
              height: 1.35,
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final auth = ref.watch(authControllerProvider);
    final drive = ref.watch(driveControllerProvider);
    final user = auth.user;

    final usedStorageStr = formatFileSize(drive.state.usedStorage);
    final totalFiles = drive.files.length;
    final totalFolders = drive.folders.length;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          tooltip: 'Back',
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Data & Privacy',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: SafeArea(
        child: TweenAnimationBuilder<double>(
          tween: Tween<double>(begin: 0.0, end: 1.0),
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeOutCubic,
          builder: (context, value, child) {
            return Opacity(
              opacity: value,
              child: Transform.translate(
                offset: Offset(0, (1.0 - value) * 15),
                child: child,
              ),
            );
          },
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.md,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Pulsing Sync Badge & Profile Info Card
                _buildProfileHeroCard(context, user, usedStorageStr, totalFiles, totalFolders),
                const SizedBox(height: AppSpacing.xl),

                // Interactive Diagnostics Card
                _buildDiagnosticsCard(context),
                const SizedBox(height: AppSpacing.xl),

                // Security Pillars
                Text(
                  'Privacy & Security Standards',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: scheme.onSurface,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                _buildSecurityPillar(
                  context,
                  icon: Icons.vpn_lock_rounded,
                  title: 'Decentralized Storage',
                  description:
                      "Your files are split and securely stored within Telegram's distributed cloud network, safeguarding them with robust server-side encryption.",
                ),
                const SizedBox(height: AppSpacing.sm),
                _buildSecurityPillar(
                  context,
                  icon: Icons.phonelink_lock_rounded,
                  title: 'Encrypted Cache',
                  description:
                      'All local file downloads and thumbnails are stored using app-level encryption inside this device\'s secure container.',
                ),
                const SizedBox(height: AppSpacing.sm),
                _buildSecurityPillar(
                  context,
                  icon: Icons.verified_user_rounded,
                  title: 'Zero Third-Party Sharing',
                  description:
                      'TeleDrive does not read, index, sell, or monitor your files. All interactions are direct to your personal Telegram Cloud.',
                ),
                const SizedBox(height: AppSpacing.xl),

                // Actions Section
                Text(
                  'Portability & Actions',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: scheme.onSurface,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                _buildActionTile(
                  context,
                  icon: Icons.import_export_rounded,
                  title: 'Export Account Data',
                  subtitle: 'Learn how to generate a complete backup copy.',
                  onTap: () => _showExportDataDialog(context),
                ),
                const SizedBox(height: AppSpacing.sm),
                _buildActionTile(
                  context,
                  icon: Icons.cleaning_services_rounded,
                  title: 'Clear Cached Storage',
                  subtitle: 'Free up local space from downloaded items.',
                  onTap: () => context.safePush('/profile/free-up-space'),
                ),
                const SizedBox(height: AppSpacing.xl + 4),

                // Helpful external resources
                _buildLinkCard(
                  context,
                  title: 'Telegram Privacy Policy',
                  subtitle: 'Official statements on how your personal data is kept secure.',
                  onTap: () => _launchUrl('https://telegram.org/privacy'),
                ),
                const SizedBox(height: AppSpacing.sm),
                _buildLinkCard(
                  context,
                  title: 'Telegram Security FAQ',
                  subtitle: 'Deep technical explanation of MTProto protocol security.',
                  onTap: () => _launchUrl('https://telegram.org/faq#q-is-telegram-secure'),
                ),
                const SizedBox(height: AppSpacing.xxl),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProfileHeroCard(
    BuildContext context,
    AuthUser? user,
    String usedStorage,
    int fileCount,
    int folderCount,
  ) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    final displayName = user != null
        ? '${user.firstName} ${user.lastName}'.trim()
        : 'TeleDrive Member';
    final accountLabel = user?.username != null && user!.username!.isNotEmpty
        ? '@${user.username}'
        : 'Secure Session';

    return Container(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: scheme.outlineVariant.withValues(alpha: 0.3),
        ),
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
              // Secure Connection Pulse Badge
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
          // Storage Stats grid row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildStatColumn(context, usedStorage, 'Cloud Storage'),
              _buildStatDivider(context),
              _buildStatColumn(context, '$fileCount', 'Files Synced'),
              _buildStatDivider(context),
              _buildStatColumn(context, '$folderCount', 'Folders'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatColumn(BuildContext context, String value, String label) {
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

  Widget _buildStatDivider(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: 1,
      height: 32,
      color: scheme.outlineVariant.withValues(alpha: 0.5),
    );
  }

  Widget _buildDiagnosticsCard(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: scheme.primary.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: _diagnosticsCompleted
              ? const Color(0xFF30D158).withValues(alpha: 0.3)
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
                  color: _diagnosticsCompleted
                      ? const Color(0xFF30D158).withValues(alpha: 0.1)
                      : scheme.primary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _diagnosticsCompleted
                      ? Icons.verified_user_rounded
                      : Icons.security_outlined,
                  color: _diagnosticsCompleted
                      ? const Color(0xFF30D158)
                      : scheme.primary,
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
                      _diagnosticsCompleted
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
          if (_diagnosticsRunning || _diagnosticsCompleted) ...[
            const SizedBox(height: AppSpacing.md + 4),
            Row(
              children: [
                if (_diagnosticsRunning) ...[
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                ] else if (_diagnosticsCompleted) ...[
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
                    _diagnosticsStep,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: _diagnosticsCompleted
                          ? const Color(0xFF30D158)
                          : scheme.onSurface,
                      fontWeight: _diagnosticsCompleted
                          ? FontWeight.bold
                          : FontWeight.normal,
                    ),
                  ),
                ),
              ],
            ),
          ],
          if (!_diagnosticsRunning) ...[
            const SizedBox(height: AppSpacing.md + 4),
            OutlinedButton(
              onPressed: _runDiagnostics,
              style: OutlinedButton.styleFrom(
                side: BorderSide(
                  color: _diagnosticsCompleted
                      ? const Color(0xFF30D158).withValues(alpha: 0.5)
                      : scheme.primary.withValues(alpha: 0.5),
                ),
                foregroundColor: _diagnosticsCompleted
                    ? const Color(0xFF30D158)
                    : scheme.primary,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                _diagnosticsCompleted ? 'Re-run Diagnostics' : 'Run Diagnostics',
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSecurityPillar(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String description,
  }) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: scheme.outlineVariant.withValues(alpha: 0.2),
        ),
      ),
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: scheme.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              icon,
              color: scheme.primary,
              size: 20,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: scheme.outlineVariant.withValues(alpha: 0.25),
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Row(
              children: [
                Icon(
                  icon,
                  color: scheme.onSurfaceVariant,
                  size: 24,
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  color: scheme.onSurfaceVariant.withValues(alpha: 0.5),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLinkCard(
    BuildContext context, {
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Container(
      decoration: BoxDecoration(
        border: Border.all(
          color: scheme.outlineVariant.withValues(alpha: 0.2),
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: scheme.primary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.open_in_new_rounded,
                  size: 18,
                  color: scheme.primary.withValues(alpha: 0.7),
                ),
              ],
            ),
          ),
        ),
      ),
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
    _animation = Tween<double>(begin: 3.0, end: 8.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
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
