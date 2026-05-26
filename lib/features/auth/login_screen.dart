import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../widgets/premium_toast.dart';
import 'auth_controller.dart';
import 'components/login_error_banner.dart';
import 'components/login_step_indicator.dart';
import 'country_data.dart';
import 'country_picker.dart';

part 'login_screen_actions.dart';
part 'login_screen_view.dart';

enum LoginMode { normalLogin, addAccount, reauthenticateAccount }

extension LoginModeX on LoginMode {
  static LoginMode fromQuery(String? value) {
    return LoginMode.values.firstWhere(
      (mode) => mode.name == value,
      orElse: () => LoginMode.normalLogin,
    );
  }
}

enum _Step { phone, code, password }

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({
    this.mode = LoginMode.normalLogin,
    this.returnTo,
    this.targetUserId,
    super.key,
  });

  final LoginMode mode;
  final String? returnTo;
  final int? targetUserId;

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  _Step _step = _Step.phone;
  final _phone = TextEditingController();
  final _code = TextEditingController();
  final _password = TextEditingController();
  Country _selectedCountry = findCountryByDialCode('+91');
  int? _attemptId;
  bool _loading = false;
  String? _error;
  bool _obscurePassword = true;

  void _setUiState(VoidCallback change) => setState(change);

  @override
  void dispose() {
    _phone.dispose();
    _code.dispose();
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return PopScope(
      canPop: widget.mode == LoginMode.normalLogin,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop || widget.mode == LoginMode.normalLogin) return;
        context.go(_cancelDestination());
      },
      child: Scaffold(
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: AppSpacing.xl,
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(height: AppSpacing.md),
                    Image.asset(
                      'assets/icon/app_icon.png',
                      width: 64,
                      height: 64,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    _buildHeader(),
                    const SizedBox(height: AppSpacing.lg),
                    AnimatedSwitcher(
                      duration: AppDurations.medium2,
                      switchInCurve: AppEasing.emphasizedDecelerate,
                      switchOutCurve: AppEasing.emphasizedAccelerate,
                      transitionBuilder: (child, anim) => FadeTransition(
                        opacity: anim,
                        child: SlideTransition(
                          position: Tween<Offset>(
                            begin: const Offset(0, .04),
                            end: Offset.zero,
                          ).animate(anim),
                          child: child,
                        ),
                      ),
                      child: KeyedSubtree(
                        key: ValueKey(_step),
                        child: _buildFormCard(),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    Text(
                      'Login completes after this device is ready for local TDLib file transfer.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
