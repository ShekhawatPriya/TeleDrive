import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../widgets/premium_toast.dart';
import 'auth_controller.dart';
import 'components/login_error_banner.dart';
import 'components/login_controls.dart';
import 'components/login_identity.dart';
import '../../widgets/brand_mark.dart';
import '../../widgets/adaptive_surface.dart';
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
  String? _attemptToken;
  bool _loading = false;
  String? _error;
  bool _obscurePassword = true;

  void _setUiState(VoidCallback change) => setState(change);

  @override
  void initState() {
    super.initState();
    dismissPremiumToast();
  }

  @override
  void dispose() {
    _attemptId = null;
    _attemptToken = null;
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
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 24, 0),
                child: Row(
                  children: [
                    AdaptiveSurface(
                      radius: 24,
                      role: GlassRole.navigation,
                      child: IconButton(
                        tooltip: 'Back',
                        icon: Icon(
                          theme.platform == TargetPlatform.iOS
                              ? CupertinoIcons.chevron_left
                              : Icons.arrow_back_rounded,
                          size: 21,
                        ),
                        onPressed: _loading
                            ? null
                            : () {
                                if (_step != _Step.phone) {
                                  _setStep(_Step.phone);
                                } else {
                                  context.go(_cancelDestination());
                                }
                              },
                      ),
                    ),
                    const Spacer(),
                    const BrandMark(size: 24),
                    const SizedBox(width: 8),
                    Text(
                      'TeleDrive',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) => SingleChildScrollView(
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    padding: const EdgeInsets.fromLTRB(28, 28, 28, 28),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          maxWidth: 430,
                          minHeight: (constraints.maxHeight - 56).clamp(
                            0,
                            double.infinity,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Align(
                              alignment: Alignment.centerLeft,
                              child: LoginIdentity(step: _step.index),
                            ),
                            const SizedBox(height: 28),
                            _buildHeader(),
                            const SizedBox(height: 32),
                            AnimatedSwitcher(
                              duration: MediaQuery.disableAnimationsOf(context)
                                  ? Duration.zero
                                  : const Duration(milliseconds: 180),
                              child: KeyedSubtree(
                                key: ValueKey(_step),
                                child: _buildFormCard(),
                              ),
                            ),
                            const SizedBox(height: 28),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(
                                  theme.platform == TargetPlatform.iOS
                                      ? CupertinoIcons.lock
                                      : Icons.lock_outline_rounded,
                                  size: 15,
                                  color: scheme.onSurfaceVariant,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    _step == _Step.phone
                                        ? 'Use the number linked to your Telegram account. Your files stay in your Telegram storage.'
                                        : _step == _Step.code
                                        ? 'Keep Telegram open until you finish signing in.'
                                        : 'This is your Telegram password, not your device passcode.',
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      height: 1.5,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
