import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../cache_controller.dart';
import '../../auth/auth_controller.dart';

class SignOutConfirmationSheet extends ConsumerStatefulWidget {
  const SignOutConfirmationSheet({super.key});

  @override
  ConsumerState<SignOutConfirmationSheet> createState() => _SignOutConfirmationSheetState();
}

class _SignOutConfirmationSheetState extends ConsumerState<SignOutConfirmationSheet> with SingleTickerProviderStateMixin {
  late final AnimationController _animController;
  late final List<Animation<double>> _fadeAnimations;
  late final List<Animation<Offset>> _slideAnimations;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    );

    // 6 staggered animation levels:
    // 0: Glowing Hero Icon
    // 1: Bold Title & Subtitle
    // 2: Card 1 (Telegram Logout)
    // 3: Card 2 (Cloud Storage Safety)
    // 4: Card 3 (Cache Wipe)
    // 5: Confirmation Button
    _fadeAnimations = List.generate(6, (index) {
      final start = index * 0.08;
      final end = start + 0.35;
      return CurvedAnimation(
        parent: _animController,
        curve: Interval(start, end, curve: Curves.easeOut),
      );
    });

    _slideAnimations = List.generate(6, (index) {
      final start = index * 0.08;
      final end = start + 0.35;
      return Tween<Offset>(
        begin: const Offset(0, 0.25),
        end: Offset.zero,
      ).animate(CurvedAnimation(
        parent: _animController,
        curve: Interval(start, end, curve: AppEasing.emphasized),
      ));
    });

    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  Future<void> _handleSignOut() async {
    if (_isProcessing) return;
    setState(() => _isProcessing = true);

    try {
      // 1. Wipe local cache first completely
      await ref.read(cacheControllerProvider).clearCache();
      
      if (mounted) {
        // 2. Dismiss sheet visually
        Navigator.of(context).pop();
      }

      // 3. Clear auth token & state, causing GoRouter to redirect to /welcome
      await ref.read(authControllerProvider).logout();
    } catch (e) {
      debugPrint('Error during sign-out process: $e');
      if (mounted) {
        setState(() => _isProcessing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Sign out failed: ${e.toString()}'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return PopScope(
      canPop: !_isProcessing,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.lg, 8, AppSpacing.lg, AppSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 2. Glowing Hero Icon
              Center(
                child: FadeTransition(
                  opacity: _fadeAnimations[0],
                  child: SlideTransition(
                    position: _slideAnimations[0],
                    child: Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: [
                            scheme.error.withValues(alpha: 0.16),
                            scheme.error.withValues(alpha: 0.04),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        border: Border.all(
                          color: scheme.error.withValues(alpha: 0.25),
                          width: 2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: scheme.error.withValues(alpha: 0.08),
                            blurRadius: 20,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: Icon(
                        Icons.logout_rounded,
                        size: 32,
                        color: scheme.error,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.md),

              // 3. Bold Title & Subtitle
              FadeTransition(
                opacity: _fadeAnimations[1],
                child: SlideTransition(
                  position: _slideAnimations[1],
                  child: Column(
                    children: [
                      Text(
                        'Sign Out of TeleDrive?',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: scheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        'Please review the cloud & local device storage impacts below.',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),

              // 4. Staggered Detail Rows
              // Card 1: Telegram Session
              FadeTransition(
                opacity: _fadeAnimations[2],
                child: SlideTransition(
                  position: _slideAnimations[2],
                  child: _buildDetailRow(
                    scheme: scheme,
                    theme: theme,
                    icon: Image.asset(
                      'assets/icon/telegram.png',
                      width: 26,
                      height: 26,
                    ),
                    iconBgColor: Colors.transparent,
                    title: 'Telegram Logout',
                    subtitle: 'Your active session on this device will be revoked and logged out.',
                  ),
                ),
              ),

              // Card 2: Cloud Data Safe
              FadeTransition(
                opacity: _fadeAnimations[3],
                child: SlideTransition(
                  position: _slideAnimations[3],
                  child: _buildDetailRow(
                    scheme: scheme,
                    theme: theme,
                    icon: const Icon(
                      Icons.cloud_done_rounded,
                      color: AppColors.success,
                      size: 20,
                    ),
                    iconBgColor: AppColors.success.withValues(alpha: 0.12),
                    title: 'Cloud Data Safe',
                    subtitle: 'All your files, folders, and documents remain permanently safe in cloud storage.',
                  ),
                ),
              ),

              // Card 3: Cache Reclaimed
              FadeTransition(
                opacity: _fadeAnimations[4],
                child: SlideTransition(
                  position: _slideAnimations[4],
                  child: _buildDetailRow(
                    scheme: scheme,
                    theme: theme,
                    icon: const Icon(
                      Icons.cleaning_services_rounded,
                      color: AppColors.warning,
                      size: 20,
                    ),
                    iconBgColor: AppColors.warning.withValues(alpha: 0.12),
                    title: 'Local Cache Cleared',
                    subtitle: 'Temporary data, streaming chunks, and previews will be fully wiped to save space.',
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.md),

              // 5. Destructive Confirm Button with Interactive Scaling
              FadeTransition(
                opacity: _fadeAnimations[5],
                child: SlideTransition(
                  position: _slideAnimations[5],
                  child: _InteractiveConfirmButton(
                    onTap: _isProcessing ? null : _handleSignOut,
                    backgroundColor: scheme.error,
                    foregroundColor: scheme.onError,
                    child: _isProcessing
                        ? SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: scheme.onError,
                            ),
                          )
                        : Text(
                            'Sign Out',
                            style: theme.textTheme.labelLarge?.copyWith(
                              color: scheme.onError,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                          ),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow({
    required ColorScheme scheme,
    required ThemeData theme,
    required Widget icon,
    required Color iconBgColor,
    required String title,
    required String subtitle,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: AppRadii.lgR,
        border: Border.all(
          color: scheme.outlineVariant.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: iconBgColor,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: icon,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: scheme.onSurface,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InteractiveConfirmButton extends StatefulWidget {
  final VoidCallback? onTap;
  final Widget child;
  final Color backgroundColor;
  final Color foregroundColor;

  const _InteractiveConfirmButton({
    required this.onTap,
    required this.child,
    required this.backgroundColor,
    required this.foregroundColor,
  });

  @override
  State<_InteractiveConfirmButton> createState() => _InteractiveConfirmButtonState();
}

class _InteractiveConfirmButtonState extends State<_InteractiveConfirmButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final isEnabled = widget.onTap != null;

    return GestureDetector(
      onTapDown: isEnabled ? (_) => setState(() => _isPressed = true) : null,
      onTapUp: isEnabled ? (_) => setState(() => _isPressed = false) : null,
      onTapCancel: isEnabled ? () => setState(() => _isPressed = false) : null,
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _isPressed ? 0.96 : 1.0,
        duration: const Duration(milliseconds: 100),
        curve: Curves.easeInOut,
        child: Container(
          height: 52,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isEnabled
                ? widget.backgroundColor
                : widget.backgroundColor.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(AppRadii.pill),
            boxShadow: isEnabled
                ? [
                    BoxShadow(
                      color: widget.backgroundColor.withValues(alpha: 0.25),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          child: widget.child,
        ),
      ),
    );
  }
}
