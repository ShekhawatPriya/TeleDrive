import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../core/config/app_config.dart';
import '../../core/theme/app_theme.dart';
import '../profile/legal_screen.dart'; // To reuse GitHubIcon

/// A premium pre-login landing screen that introduces TeleDrive,
/// explains storage concepts, and guides unauthenticated users.
class LandingScreen extends StatefulWidget {
  const LandingScreen({super.key});

  @override
  State<LandingScreen> createState() => _LandingScreenState();
}

class _LandingScreenState extends State<LandingScreen> {
  final _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          controller: _scrollController,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.xl,
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 1. Hero Section
                  const _FadeInSlide(
                    delay: Duration.zero,
                    child: _HeroSection(),
                  ),
                  const SizedBox(height: AppSpacing.xxl),

                  // 2. How it works Section
                  const _FadeInSlide(
                    delay: Duration(milliseconds: 150),
                    child: _HowItWorksSection(),
                  ),
                  const SizedBox(height: AppSpacing.xxl),

                  // 3. Storage Separation Section
                  const _FadeInSlide(
                    delay: Duration(milliseconds: 300),
                    child: _StorageSeparationSection(),
                  ),
                  const SizedBox(height: AppSpacing.xxl),

                  // 4. Privacy & Trust Section
                  const _FadeInSlide(
                    delay: Duration(milliseconds: 450),
                    child: _PrivacyAndTrustSection(),
                  ),
                  const SizedBox(height: AppSpacing.xxl),

                  // 5. Open Source Section
                  const _FadeInSlide(
                    delay: Duration(milliseconds: 600),
                    child: _OpenSourceSection(),
                  ),
                  const SizedBox(height: AppSpacing.xxl),

                  // 6. Final CTA & Footer Section
                  const _FadeInSlide(
                    delay: Duration(milliseconds: 700),
                    child: _FinalCtaAndFooter(),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A standard staggered slide and fade-in animator for premium entry motion.
class _FadeInSlide extends StatefulWidget {
  final Widget child;
  final Duration delay;

  const _FadeInSlide({
    required this.child,
    this.delay = Duration.zero,
  });

  @override
  State<_FadeInSlide> createState() => _FadeInSlideState();
}

class _FadeInSlideState extends State<_FadeInSlide>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _opacity;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 550),
    );
    _opacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.85, curve: Curves.easeOut),
      ),
    );
    _slide = Tween<Offset>(begin: const Offset(0, 0.06), end: Offset.zero).animate(
      CurvedAnimation(
        parent: _controller,
        curve: AppEasing.emphasizedDecelerate,
      ),
    );

    Future.delayed(widget.delay, () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Opacity(
          opacity: _opacity.value,
          child: SlideTransition(
            position: _slide,
            child: child,
          ),
        );
      },
      child: widget.child,
    );
  }
}

/// Hero Section containing core marketing headers and initial options.
class _HeroSection extends StatelessWidget {
  const _HeroSection();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Column(
      children: [
        // App Identity Brand Circle
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            color: scheme.primaryContainer.withValues(alpha: 0.4),
            borderRadius: AppRadii.xlR,
          ),
          child: Icon(
            Icons.cloud_outlined,
            color: scheme.primary,
            size: 38,
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        Text(
          'TeleDrive',
          style: theme.textTheme.labelMedium?.copyWith(
            color: scheme.primary,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.5,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          'Your Telegram-powered drive,\nmade transparent.',
          textAlign: TextAlign.center,
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
            color: scheme.onSurface,
            height: 1.25,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Text(
          'TeleDrive helps you organize, preview, stream, and manage files through a clean drive interface while keeping storage backed by Telegram and your configured backend.',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: scheme.onSurfaceVariant,
            height: 1.45,
          ),
        ),
        const SizedBox(height: AppSpacing.lg),

        // Actions
        Row(
          children: [
            Expanded(
              child: FilledButton(
                onPressed: () {
                  HapticFeedback.mediumImpact();
                  context.push('/login');
                },
                child: const Text('Get Started'),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () {
                  HapticFeedback.lightImpact();
                  AppConfig.openRepository();
                },
                icon: GitHubIcon(size: 16, color: scheme.primary),
                label: const Text('GitHub'),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),

        // Trust Line
        Wrap(
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: AppSpacing.xs,
          children: [
            _buildTrustBadge(context, 'Open Source'),
            _buildDividerDot(context),
            _buildTrustBadge(context, 'Telegram-backed'),
            _buildDividerDot(context),
            _buildTrustBadge(context, 'Local Cache Explained'),
            _buildDividerDot(context),
            _buildTrustBadge(context, 'No Confusions'),
          ],
        ),
      ],
    );
  }

  Widget _buildTrustBadge(BuildContext context, String label) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Text(
      label,
      style: theme.textTheme.bodySmall?.copyWith(
        color: scheme.onSurfaceVariant.withValues(alpha: 0.8),
        fontWeight: FontWeight.w500,
        fontSize: 11,
      ),
    );
  }

  Widget _buildDividerDot(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: 3.5,
      height: 3.5,
      decoration: BoxDecoration(
        color: scheme.onSurfaceVariant.withValues(alpha: 0.4),
        shape: BoxShape.circle,
      ),
    );
  }
}

/// Visual explanation section illustrating Phone, Backend, Telegram storage relationships.
class _HowItWorksSection extends StatelessWidget {
  const _HowItWorksSection();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: AppRadii.mdR,
        side: BorderSide(
          color: scheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'How TeleDrive Works',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: scheme.onSurface,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'TeleDrive bridges your device, metadata configuration, and Telegram storage layers securely.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
                height: 1.35,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),

            // Vertical Flow Items
            _buildFlowStep(
              context: context,
              icon: Icons.phone_iphone_rounded,
              iconColor: scheme.primary,
              title: 'Your Phone / App',
              description: 'Acts as the control interface to explore files, play videos, and manage directories.',
              isFirst: true,
            ),
            _buildFlowStep(
              context: context,
              icon: Icons.dns_outlined,
              iconColor: scheme.secondary,
              title: 'Backend Metadata Layer',
              description: 'Stores folder organization, permissions, names, and sharing status (no actual file contents).',
            ),
            _buildFlowStep(
              context: context,
              icon: Icons.cloud_done_outlined,
              iconColor: scheme.tertiary,
              title: 'Telegram Storage Layer',
              description: 'Hosts the original uploaded binaries permanently and securely inside your Telegram files ecosystem.',
              isLast: true,
            ),
            
            const Padding(
              padding: EdgeInsets.symmetric(vertical: AppSpacing.sm),
              child: Divider(),
            ),

            // Cache Side Concept callout
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.speed_rounded,
                    size: 16,
                    color: Colors.orange,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Direct Local Cache (Separate Concept)',
                        style: theme.textTheme.labelMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Colors.orange.shade800,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Temporary copies, thumbnails, and preview structures live locally on your phone solely for speed. You can wipe this cache whenever you want without risk.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFlowStep({
    required BuildContext context,
    required IconData icon,
    required Color iconColor,
    required String title,
    required String description,
    bool isFirst = false,
    bool isLast = false,
  }) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: iconColor, size: 18),
            ),
            if (!isLast)
              Container(
                width: 2,
                height: 40,
                color: scheme.outlineVariant.withValues(alpha: 0.6),
              ),
          ],
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: scheme.onSurface,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  description,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                    height: 1.35,
                  ),
                ),
                if (!isLast) const SizedBox(height: AppSpacing.sm),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Section highlighting the absolute difference between Telegram Cloud Storage vs Local Cache.
class _StorageSeparationSection extends StatelessWidget {
  const _StorageSeparationSection();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Understanding Storage & Cache',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: scheme.onSurface,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          'TeleDrive clearly segregates uploaded permanent libraries from temporary performance resources.',
          style: theme.textTheme.bodySmall?.copyWith(
            color: scheme.onSurfaceVariant,
            height: 1.35,
          ),
        ),
        const SizedBox(height: AppSpacing.md),

        // Stacked Cards representing Storage Roles
        // Card 1: Telegram Storage
        Card(
          elevation: 0,
          margin: const EdgeInsets.only(bottom: AppSpacing.sm),
          color: scheme.surfaceContainerLow,
          shape: RoundedRectangleBorder(
            borderRadius: AppRadii.mdR,
            side: BorderSide(
              color: scheme.outlineVariant.withValues(alpha: 0.4),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: scheme.primaryContainer.withValues(alpha: 0.4),
                    borderRadius: AppRadii.smR,
                  ),
                  child: Icon(
                    Icons.cloud_done_outlined,
                    color: scheme.primary,
                    size: 22,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Telegram Storage',
                              style: theme.textTheme.bodyLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: scheme.onSurface,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: scheme.primary.withValues(alpha: 0.08),
                              borderRadius: AppRadii.xsR,
                            ),
                            child: Text(
                              'CLOUD STORAGE',
                              style: theme.textTheme.labelSmall?.copyWith(
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                color: scheme.primary,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'This represents your actual library. All videos, songs, photos, documents, and folders reside here permanently, independent of your phone\'s local state.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      _buildBulletItem(context, 'No permanent phone storage consumed'),
                      _buildBulletItem(context, 'Safe if app is uninstalled or device is changed'),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),

        // Card 2: Local Cache
        Card(
          elevation: 0,
          margin: EdgeInsets.zero,
          color: scheme.surfaceContainerLow,
          shape: RoundedRectangleBorder(
            borderRadius: AppRadii.mdR,
            side: BorderSide(
              color: scheme.outlineVariant.withValues(alpha: 0.4),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.12),
                    borderRadius: AppRadii.smR,
                  ),
                  child: const Icon(
                    Icons.speed_rounded,
                    color: Colors.green,
                    size: 22,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Local Device Cache',
                              style: theme.textTheme.bodyLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: scheme.onSurface,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.green.withValues(alpha: 0.1),
                              borderRadius: AppRadii.xsR,
                            ),
                            child: const Text(
                              '100% SAFE TO CLEAR',
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                color: Colors.green,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Temporary device copies of thumbnails, small media previews, and opened documents stored locally. Used only to make browsing load instantly.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      _buildBulletItem(context, 'Clearing cache will NOT delete original cloud files'),
                      _buildBulletItem(context, 'Automatically recycled for smooth operation'),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBulletItem(BuildContext context, String text) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 5.5, right: 8.0),
            child: Container(
              width: 5,
              height: 5,
              decoration: BoxDecoration(
                color: scheme.primary.withValues(alpha: 0.6),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Expanded(
            child: Text(
              text,
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
                fontSize: 11,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Trust, FAQ and Security features.
class _PrivacyAndTrustSection extends StatelessWidget {
  const _PrivacyAndTrustSection();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Privacy & Core Principles',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: scheme.onSurface,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          'We believe trust is built on transparency, precise wording, and verifiable open-source practices.',
          style: theme.textTheme.bodySmall?.copyWith(
            color: scheme.onSurfaceVariant,
            height: 1.35,
          ),
        ),
        const SizedBox(height: AppSpacing.md),

        // Grid/List of Expandable Core FAQ panels
        const _FaqTile(
          question: 'Where are my files stored?',
          answer: 'Your uploaded files are hosted directly on Telegram\'s robust cloud infrastructure. TeleDrive acts as a client dashboard, wrapping those binaries into a structured, elegant folder interface.',
        ),
        const _FaqTile(
          question: 'What does TeleDrive store?',
          answer: 'TeleDrive stores structural folder indexes, configuration tags, search cache files, names, and references on your self-hosted backend metadata DB to build a drive-like navigation experience. We do not inspect nor retain actual file contents.',
        ),
        const _FaqTile(
          question: 'Is my login secure?',
          answer: 'Absolutely. Session keys and Telegram session credentials are saved directly in your device\'s hardware-backed keystore/keychain utilizing flutter_secure_storage. This guarantees credentials remain fully isolated.',
        ),
        const _FaqTile(
          question: 'Does clearing cache delete my files?',
          answer: 'No. Clearing local device cache only flushes temporary thumbnails, preview clips, and opened documents stored on this phone. Your original uploaded library remains untouched on Telegram.',
        ),
        const _FaqTile(
          question: 'How are my device folders accessed?',
          answer: 'TeleDrive only queries local storage when you explicitly tap to upload files or media. There is absolutely no background, automated, or passive storage scanning occurring inside this app.',
        ),
      ],
    );
  }
}

/// FAQ Expansion Card component.
class _FaqTile extends StatefulWidget {
  final String question;
  final String answer;

  const _FaqTile({required this.question, required this.answer});

  @override
  State<_FaqTile> createState() => _FaqTileState();
}

class _FaqTileState extends State<_FaqTile> {
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
                      color: _expanded ? scheme.primary : scheme.onSurfaceVariant,
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

/// Open source transparency presentation card.
class _OpenSourceSection extends StatelessWidget {
  const _OpenSourceSection();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      color: scheme.surfaceContainerHighest.withValues(alpha: 0.25),
      shape: RoundedRectangleBorder(
        borderRadius: AppRadii.mdR,
        side: BorderSide(
          color: scheme.outlineVariant.withValues(alpha: 0.3),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: scheme.onSurface.withValues(alpha: 0.07),
                    shape: BoxShape.circle,
                  ),
                  child: GitHubIcon(
                    size: 28,
                    color: scheme.onSurface,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Text(
                  'Open Source by Design',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: scheme.onSurface,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'TeleDrive is completely open source. Anyone can inspect our code, audit storage processes, self-host the backend, or check how sessions and local cache keys are handled.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
                height: 1.4,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            OutlinedButton.icon(
              onPressed: () {
                HapticFeedback.lightImpact();
                AppConfig.openRepository();
              },
              icon: GitHubIcon(size: 16, color: scheme.primary),
              label: const Text('View GitHub Repository'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Final CTA prompt and the discoverable legal links section.
class _FinalCtaAndFooter extends StatelessWidget {
  const _FinalCtaAndFooter();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Column(
      children: [
        const Divider(),
        const SizedBox(height: AppSpacing.md),
        Text(
          'Ready to open your drive?',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: scheme.onSurface,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          'Sign in to connect your Telegram-backed library and start managing files beautifully.',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodySmall?.copyWith(
            color: scheme.onSurfaceVariant,
            height: 1.35,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        FilledButton(
          onPressed: () {
            HapticFeedback.mediumImpact();
            context.push('/login');
          },
          style: FilledButton.styleFrom(
            minimumSize: const Size(200, 44),
          ),
          child: const Text('Get Started'),
        ),
        const SizedBox(height: AppSpacing.xl),

        // Legal Links discoverable footer
        Text(
          'By continuing, you can review how TeleDrive handles storage, cache, and account data in the Privacy Policy and Terms of Service.',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodySmall?.copyWith(
            fontSize: 11,
            color: scheme.onSurfaceVariant.withValues(alpha: 0.7),
            height: 1.35,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextButton(
              onPressed: () {
                HapticFeedback.lightImpact();
                context.push('/privacy');
              },
              style: TextButton.styleFrom(
                minimumSize: Size.zero,
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                textStyle: const TextStyle(fontSize: 12),
              ),
              child: const Text('Privacy Policy'),
            ),
            Container(
              width: 3,
              height: 3,
              decoration: BoxDecoration(
                color: scheme.onSurfaceVariant.withValues(alpha: 0.4),
                shape: BoxShape.circle,
              ),
            ),
            TextButton(
              onPressed: () {
                HapticFeedback.lightImpact();
                context.push('/terms');
              },
              style: TextButton.styleFrom(
                minimumSize: Size.zero,
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                textStyle: const TextStyle(fontSize: 12),
              ),
              child: const Text('Terms of Service'),
            ),
          ],
        ),
      ],
    );
  }
}
