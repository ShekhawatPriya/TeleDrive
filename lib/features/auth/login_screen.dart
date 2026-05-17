import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import 'auth_controller.dart';
import 'country_data.dart';
import 'country_picker.dart';

enum _Step { phone, code, password }

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen>
    with SingleTickerProviderStateMixin {
  _Step _step = _Step.phone;
  final _phone = TextEditingController();
  final _code = TextEditingController();
  final _password = TextEditingController();
  Country _selectedCountry = findCountryByDialCode('+91');
  int? _attemptId;
  bool _loading = false;
  String? _error;
  bool _obscurePassword = true;

  late final AnimationController _animController;
  late final Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _fadeAnim = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOutCubic,
    );
    _animController.forward();
  }

  @override
  void dispose() {
    _phone.dispose();
    _code.dispose();
    _password.dispose();
    _animController.dispose();
    super.dispose();
  }

  void _setStep(_Step next) {
    _animController.reverse().then((_) {
      setState(() {
        _step = next;
        _error = null;
      });
      _animController.forward();
    });
    HapticFeedback.lightImpact();
  }

  Future<Map<String, dynamic>> _call(
    Future<Map<String, dynamic>> Function() fn,
  ) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      return await fn();
    } catch (err) {
      final repo = ref.read(authRepositoryProvider);
      setState(() => _error = repo.api.errorMessage(err));
      rethrow;
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _sendCode() async {
    if (_loading) return;
    final local = _phone.text.replaceAll(RegExp(r'\s+'), '');
    if (local.isEmpty) {
      setState(() => _error = 'Please enter your phone number');
      return;
    }
    try {
      final data = await _call(
        () => ref
            .read(authRepositoryProvider)
            .start('${_selectedCountry.dialCode}$local'),
      );
      _attemptId = (data['attempt_id'] as num).toInt();
      _setStep(_Step.code);
    } catch (_) {}
  }

  Future<void> _verifyCode() async {
    if (_loading) return;
    if (_attemptId == null || _code.text.trim().isEmpty) {
      setState(() => _error = 'Please enter the verification code');
      return;
    }
    try {
      final data = await _call(
        () => ref
            .read(authRepositoryProvider)
            .verifyCode(_attemptId!, _code.text.trim()),
      );
      if (data['status'] == 'requires_2fa') {
        _setStep(_Step.password);
      } else if (data['token'] != null) {
        await _completeLogin('${data['token']}', data);
      }
    } catch (_) {}
  }

  Future<void> _verifyPassword() async {
    if (_loading) return;
    if (_attemptId == null || _password.text.trim().isEmpty) {
      setState(() => _error = 'Please enter your password');
      return;
    }
    try {
      final data = await _call(
        () => ref
            .read(authRepositoryProvider)
            .verifyPassword(_attemptId!, _password.text.trim()),
      );
      if (data['token'] != null) {
        await _completeLogin('${data['token']}', data);
      }
    } catch (_) {}
  }

  Future<void> _completeLogin(
    String token,
    Map<String, dynamic> authPayload,
  ) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await ref
          .read(authControllerProvider)
          .login(token, authPayload: authPayload);
      if (mounted) context.go('/drive');
    } catch (err) {
      final repo = ref.read(authRepositoryProvider);
      if (mounted) setState(() => _error = repo.api.errorMessage(err));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _pickCountry() async {
    final picked = await showCountryPicker(context);
    if (picked != null) {
      setState(() => _selectedCountry = picked);
    }
  }

  // ─── Design System Colors ──────────────────────────────────────────────────
  static const _parchment = AppColors.parchment;
  static const _ivory = AppColors.ivory;
  static const _nearBlack = AppColors.nearBlack;
  static const _terracotta = AppColors.terracotta;
  static const _oliveGray = AppColors.oliveGray;
  static const _stone = AppColors.stone;
  static const _borderCream = AppColors.border;
  static const _borderWarm = AppColors.warmSand;

  static const _focusBlue = Color(0xff3898ec);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _parchment,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 40),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Logo mark
                  _buildLogo(),
                  const SizedBox(height: 36),
                  // Title & subtitle
                  _buildHeader(),
                  const SizedBox(height: 32),
                  // Form card
                  FadeTransition(
                    opacity: _fadeAnim,
                    child: SlideTransition(
                      position: Tween<Offset>(
                        begin: const Offset(0, 0.03),
                        end: Offset.zero,
                      ).animate(_fadeAnim),
                      child: _buildFormCard(),
                    ),
                  ),
                  const SizedBox(height: 32),
                  // Footer text
                  Text(
                    'Your data is stored securely on Telegram servers.',
                    style: TextStyle(
                      fontFamily: 'Roboto',
                      fontSize: 13,
                      color: _stone,
                      height: 1.6,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLogo() {
    return Container(
      width: 80,
      height: 80,
      decoration: BoxDecoration(
        color: _terracotta,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          // Ring shadow per design system
          BoxShadow(
            color: _terracotta.withValues(alpha: 0.18),
            blurRadius: 0,
            spreadRadius: 1,
          ),
          BoxShadow(
            color: _terracotta.withValues(alpha: 0.10),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: const Icon(
        Icons.send_rounded,
        color: Color(0xfffaf9f5), // Ivory
        size: 36,
      ),
    );
  }

  Widget _buildHeader() {
    final (title, subtitle) = switch (_step) {
      _Step.phone => (
        'Sign in to TeleDrive',
        'Enter your phone number to connect\nyour Telegram account.',
      ),
      _Step.code => (
        'Verification code',
        'We sent a code to your Telegram app.\nPlease enter it below.',
      ),
      _Step.password => (
        'Two-factor authentication',
        'Your account has 2FA enabled.\nEnter your cloud password.',
      ),
    };

    return Column(
      children: [
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 280),
          child: Text(
            title,
            key: ValueKey('title_$_step'),
            style: const TextStyle(
              fontFamily: 'Georgia',
              fontSize: 26,
              fontWeight: FontWeight.w500,
              color: _nearBlack,
              height: 1.16,
            ),
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(height: 10),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 280),
          child: Text(
            subtitle,
            key: ValueKey('sub_$_step'),
            style: const TextStyle(
              fontFamily: 'Roboto',
              fontSize: 15,
              fontWeight: FontWeight.w400,
              color: _oliveGray,
              height: 1.6,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }

  Widget _buildFormCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: _ivory,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _borderCream),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0D000000), // rgba(0,0,0,0.05)
            blurRadius: 24,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Step indicator
          _StepIndicator(currentStep: _step),
          const SizedBox(height: 24),
          // Error banner
          if (_error != null) ...[
            _ErrorBanner(message: _error!),
            const SizedBox(height: 16),
          ],
          // Form fields
          if (_step == _Step.phone) _buildPhoneStep(),
          if (_step == _Step.code) _buildCodeStep(),
          if (_step == _Step.password) _buildPasswordStep(),
        ],
      ),
    );
  }

  // ─── Phone Step ─────────────────────────────────────────────────────────────

  Widget _buildPhoneStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // "Phone number" label
        const Padding(
          padding: EdgeInsets.only(bottom: 8),
          child: Text(
            'Phone number',
            style: TextStyle(
              fontFamily: 'Roboto',
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: _nearBlack,
              height: 1.43,
              letterSpacing: 0.12,
            ),
          ),
        ),
        // Combined phone input row — flag/code selector + number field
        Container(
          height: 52,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _borderWarm),
            color: Colors.white,
          ),
          child: Row(
            children: [
              // Country selector button (flag + dropdown arrow + dial code)
              GestureDetector(
                onTap: _pickCountry,
                child: Container(
                  height: 52,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    border: Border(right: BorderSide(color: _borderWarm)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _selectedCountry.flag,
                        style: const TextStyle(fontSize: 22),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        Icons.arrow_drop_down_rounded,
                        color: _stone,
                        size: 20,
                      ),
                    ],
                  ),
                ),
              ),
              // Dial code display
              Padding(
                padding: const EdgeInsets.only(left: 12),
                child: Text(
                  _selectedCountry.dialCode,
                  style: const TextStyle(
                    fontFamily: 'Roboto',
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: _nearBlack,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
              // Vertical separator
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 10),
                width: 1,
                height: 24,
                color: _borderCream,
              ),
              // Phone number input
              Expanded(
                child: TextField(
                  key: const ValueKey('phone_input'),
                  controller: _phone,
                  keyboardType: TextInputType.phone,
                  textInputAction: TextInputAction.send,
                  style: const TextStyle(
                    fontFamily: 'Roboto',
                    fontSize: 16,
                    fontWeight: FontWeight.w400,
                    color: _nearBlack,
                    letterSpacing: 0.8,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Phone number',
                    hintStyle: TextStyle(
                      fontFamily: 'Roboto',
                      fontSize: 15,
                      fontWeight: FontWeight.w400,
                      color: _stone.withValues(alpha: 0.6),
                    ),
                    contentPadding: const EdgeInsets.symmetric(vertical: 14),
                    filled: false,
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    isDense: true,
                  ),
                  onSubmitted: (_) => _sendCode(),
                ),
              ),
              const SizedBox(width: 8),
            ],
          ),
        ),
        const SizedBox(height: 8),
        // Country name hint
        GestureDetector(
          onTap: _pickCountry,
          child: Row(
            children: [
              Icon(Icons.public_rounded, size: 14, color: _stone),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  _selectedCountry.name,
                  style: const TextStyle(
                    fontFamily: 'Roboto',
                    fontSize: 13,
                    fontWeight: FontWeight.w400,
                    color: _stone,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                size: 16,
                color: _stone.withValues(alpha: 0.5),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        // Continue button
        _PrimaryButton(
          label: 'Continue',
          loading: _loading,
          onPressed: _sendCode,
        ),
      ],
    );
  }

  // ─── Code Step ──────────────────────────────────────────────────────────────

  Widget _buildCodeStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Padding(
          padding: EdgeInsets.only(bottom: 8),
          child: Text(
            'Verification code',
            style: TextStyle(
              fontFamily: 'Roboto',
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: _nearBlack,
              height: 1.43,
              letterSpacing: 0.12,
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: Colors.white,
          ),
          child: TextField(
            key: const ValueKey('code_input'),
            controller: _code,
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            maxLength: 6,
            autofocus: true,
            style: const TextStyle(
              fontFamily: 'Georgia',
              fontWeight: FontWeight.w500,
              fontSize: 28,
              letterSpacing: 10,
              color: _nearBlack,
            ),
            decoration: InputDecoration(
              hintText: '• • • • • •',
              hintStyle: TextStyle(
                color: _stone.withValues(alpha: 0.4),
                letterSpacing: 8,
                fontSize: 22,
              ),
              counterText: '',
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 18,
              ),
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: _borderWarm),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: _borderWarm),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: _focusBlue, width: 1.4),
              ),
            ),
            onSubmitted: (_) => _verifyCode(),
          ),
        ),
        const SizedBox(height: 24),
        _PrimaryButton(
          label: 'Verify',
          loading: _loading,
          onPressed: _verifyCode,
        ),
        const SizedBox(height: 14),
        Center(
          child: GestureDetector(
            onTap: () => _setStep(_Step.phone),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.arrow_back_rounded, size: 16, color: _oliveGray),
                const SizedBox(width: 6),
                const Text(
                  'Wrong number?',
                  style: TextStyle(
                    fontFamily: 'Roboto',
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: _oliveGray,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ─── Password Step ──────────────────────────────────────────────────────────

  Widget _buildPasswordStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Padding(
          padding: EdgeInsets.only(bottom: 8),
          child: Text(
            'Cloud password',
            style: TextStyle(
              fontFamily: 'Roboto',
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: _nearBlack,
              height: 1.43,
              letterSpacing: 0.12,
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: Colors.white,
          ),
          child: TextField(
            key: const ValueKey('password_input'),
            controller: _password,
            keyboardType: TextInputType.visiblePassword,
            textInputAction: TextInputAction.done,
            enableSuggestions: false,
            autocorrect: false,
            obscureText: _obscurePassword,
            autofocus: true,
            style: const TextStyle(
              fontFamily: 'Roboto',
              fontSize: 16,
              fontWeight: FontWeight.w400,
              color: _nearBlack,
            ),
            decoration: InputDecoration(
              hintText: 'Enter your password',
              hintStyle: TextStyle(
                fontFamily: 'Roboto',
                fontSize: 15,
                fontWeight: FontWeight.w400,
                color: _stone.withValues(alpha: 0.6),
              ),
              prefixIcon: Icon(
                Icons.lock_outline_rounded,
                color: _stone,
                size: 20,
              ),
              suffixIcon: GestureDetector(
                onTap: () =>
                    setState(() => _obscurePassword = !_obscurePassword),
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Icon(
                    _obscurePassword
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                    color: _stone,
                    size: 20,
                  ),
                ),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 16,
              ),
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: _borderWarm),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: _borderWarm),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: _focusBlue, width: 1.4),
              ),
            ),
            onSubmitted: (_) => _verifyPassword(),
          ),
        ),
        const SizedBox(height: 24),
        _PrimaryButton(
          label: 'Sign in',
          loading: _loading,
          onPressed: _verifyPassword,
        ),
        const SizedBox(height: 14),
        Center(
          child: GestureDetector(
            onTap: () => _setStep(_Step.phone),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.arrow_back_rounded, size: 16, color: _oliveGray),
                const SizedBox(width: 6),
                const Text(
                  'Start over',
                  style: TextStyle(
                    fontFamily: 'Roboto',
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: _oliveGray,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Supporting Widgets ─────────────────────────────────────────────────────

class _StepIndicator extends StatelessWidget {
  const _StepIndicator({required this.currentStep});
  final _Step currentStep;

  @override
  Widget build(BuildContext context) {
    final current = _Step.values.indexOf(currentStep);

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(3, (i) {
        final isCompleted = i < current;
        final isCurrent = i == current;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 3),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 320),
            curve: Curves.easeOutCubic,
            width: isCurrent ? 28 : 8,
            height: 6,
            decoration: BoxDecoration(
              color: isCompleted || isCurrent
                  ? AppColors.terracotta
                  : AppColors.warmSand,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
        );
      }),
    );
  }
}

class _PrimaryButton extends StatefulWidget {
  const _PrimaryButton({
    required this.label,
    required this.loading,
    required this.onPressed,
  });

  final String label;
  final bool loading;
  final VoidCallback onPressed;

  @override
  State<_PrimaryButton> createState() => _PrimaryButtonState();
}

class _PrimaryButtonState extends State<_PrimaryButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        if (!widget.loading) widget.onPressed();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOut,
        height: 52,
        decoration: BoxDecoration(
          color: widget.loading
              ? AppColors.terracotta.withValues(alpha: 0.7)
              : _pressed
              ? const Color(0xffb5573a) // Slightly darker terracotta
              : AppColors.terracotta,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            // Ring shadow per design system
            BoxShadow(
              color: AppColors.terracotta.withValues(alpha: 0.0),
              blurRadius: 0,
              spreadRadius: 0,
            ),
            const BoxShadow(
              color: Color(0xffc96442), // terracotta
              blurRadius: 0,
              spreadRadius: 1,
              offset: Offset(0, 0),
            ),
          ],
        ),
        alignment: Alignment.center,
        child: widget.loading
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: Color(0xfffaf9f5), // Ivory
                ),
              )
            : Text(
                widget.label,
                style: const TextStyle(
                  fontFamily: 'Roboto',
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Color(0xfffaf9f5), // Ivory
                  letterSpacing: 0.3,
                ),
              ),
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.15)),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline_rounded, color: AppColors.error, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                fontFamily: 'Roboto',
                color: AppColors.error,
                fontSize: 13,
                fontWeight: FontWeight.w500,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
