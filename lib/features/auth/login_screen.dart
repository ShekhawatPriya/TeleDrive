import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

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
      duration: const Duration(milliseconds: 300),
    );
    _fadeAnim = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeInOut,
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
        await ref.read(authControllerProvider).login('${data['token']}');
        if (mounted) context.go('/drive');
      }
    } catch (_) {}
  }

  Future<void> _verifyPassword() async {
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
        await ref.read(authControllerProvider).login('${data['token']}');
        if (mounted) context.go('/drive');
      }
    } catch (_) {}
  }

  Future<void> _pickCountry() async {
    final picked = await showCountryPicker(context);
    if (picked != null) {
      setState(() => _selectedCountry = picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Logo
                _buildLogo(theme, isDark),
                const SizedBox(height: 40),
                // Title & subtitle
                _buildHeader(theme),
                const SizedBox(height: 32),
                // Form card
                FadeTransition(
                  opacity: _fadeAnim,
                  child: SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0, 0.04),
                      end: Offset.zero,
                    ).animate(_fadeAnim),
                    child: _buildFormCard(theme, isDark),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLogo(ThemeData theme, bool isDark) {
    return Container(
      width: 88,
      height: 88,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            theme.colorScheme.primary,
            theme.colorScheme.primary.withValues(alpha: 0.8),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.primary.withValues(alpha: 0.3),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: const Icon(
        Icons.send_rounded,
        color: Colors.white,
        size: 40,
      ),
    );
  }

  Widget _buildHeader(ThemeData theme) {
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
          duration: const Duration(milliseconds: 250),
          child: Text(
            title,
            key: ValueKey('title_$_step'),
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.w700,
              fontSize: 24,
              letterSpacing: -0.3,
            ),
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(height: 10),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          child: Text(
            subtitle,
            key: ValueKey('sub_$_step'),
            style: theme.textTheme.bodyMedium?.copyWith(
              fontSize: 15,
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }

  Widget _buildFormCard(ThemeData theme, bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xff262624) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.06)
              : Colors.black.withValues(alpha: 0.06),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.04),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Step indicator
          _StepDots(currentStep: _step),
          const SizedBox(height: 24),
          // Error banner
          if (_error != null) ...[
            _ErrorBanner(message: _error!),
            const SizedBox(height: 16),
          ],
          // Form fields
          if (_step == _Step.phone) _buildPhoneStep(theme, isDark),
          if (_step == _Step.code) _buildCodeStep(theme, isDark),
          if (_step == _Step.password) _buildPasswordStep(theme, isDark),
        ],
      ),
    );
  }

  Widget _buildPhoneStep(ThemeData theme, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Country picker button
        GestureDetector(
          onTap: _pickCountry,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.04)
                  : Colors.black.withValues(alpha: 0.03),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.08)
                    : Colors.black.withValues(alpha: 0.08),
              ),
            ),
            child: Row(
              children: [
                Text(
                  _selectedCountry.flag,
                  style: const TextStyle(fontSize: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _selectedCountry.name,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w500,
                      fontSize: 15,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Icon(
                  Icons.keyboard_arrow_down_rounded,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                  size: 22,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        // Phone number input row
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Dial code chip
            GestureDetector(
              onTap: _pickCountry,
              child: Container(
                height: 52,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.04)
                      : Colors.black.withValues(alpha: 0.03),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.08)
                        : Colors.black.withValues(alpha: 0.08),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _selectedCountry.flag,
                      style: const TextStyle(fontSize: 18),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _selectedCountry.dialCode,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 10),
            // Phone field
            Expanded(
              child: SizedBox(
                height: 52,
                child: TextField(
                  controller: _phone,
                  keyboardType: TextInputType.phone,
                  textInputAction: TextInputAction.send,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w500,
                    fontSize: 16,
                    letterSpacing: 0.5,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Phone number',
                    hintStyle: TextStyle(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.35),
                      fontWeight: FontWeight.w400,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    filled: true,
                    fillColor: isDark
                        ? Colors.white.withValues(alpha: 0.04)
                        : Colors.black.withValues(alpha: 0.03),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.08)
                            : Colors.black.withValues(alpha: 0.08),
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.08)
                            : Colors.black.withValues(alpha: 0.08),
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(
                        color: theme.colorScheme.primary.withValues(alpha: 0.6),
                        width: 1.5,
                      ),
                    ),
                  ),
                  onSubmitted: (_) => _sendCode(),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        // Continue button
        _PrimaryButton(
          label: 'Continue',
          loading: _loading,
          onPressed: _sendCode,
        ),
      ],
    );
  }

  Widget _buildCodeStep(ThemeData theme, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Code input
        TextField(
          controller: _code,
          keyboardType: TextInputType.number,
          textAlign: TextAlign.center,
          maxLength: 6,
          autofocus: true,
          style: theme.textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.w600,
            letterSpacing: 8,
            fontSize: 28,
          ),
          decoration: InputDecoration(
            hintText: '• • • • • •',
            hintStyle: TextStyle(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.2),
              letterSpacing: 6,
              fontSize: 24,
            ),
            counterText: '',
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 18,
            ),
            filled: true,
            fillColor: isDark
                ? Colors.white.withValues(alpha: 0.04)
                : Colors.black.withValues(alpha: 0.03),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.08)
                    : Colors.black.withValues(alpha: 0.08),
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.08)
                    : Colors.black.withValues(alpha: 0.08),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(
                color: theme.colorScheme.primary.withValues(alpha: 0.6),
                width: 1.5,
              ),
            ),
          ),
          onSubmitted: (_) => _verifyCode(),
        ),
        const SizedBox(height: 20),
        _PrimaryButton(
          label: 'Verify',
          loading: _loading,
          onPressed: _verifyCode,
        ),
        const SizedBox(height: 12),
        Center(
          child: TextButton.icon(
            onPressed: () => _setStep(_Step.phone),
            icon: const Icon(Icons.arrow_back_rounded, size: 18),
            label: const Text('Wrong number?'),
            style: TextButton.styleFrom(
              foregroundColor: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              textStyle: const TextStyle(
                fontWeight: FontWeight.w500,
                fontSize: 14,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPasswordStep(ThemeData theme, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _password,
          obscureText: _obscurePassword,
          autofocus: true,
          style: theme.textTheme.bodyLarge?.copyWith(
            fontWeight: FontWeight.w500,
            fontSize: 16,
          ),
          decoration: InputDecoration(
            hintText: 'Cloud password',
            hintStyle: TextStyle(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.35),
              fontWeight: FontWeight.w400,
            ),
            prefixIcon: Icon(
              Icons.lock_outline_rounded,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
              size: 20,
            ),
            suffixIcon: IconButton(
              onPressed: () =>
                  setState(() => _obscurePassword = !_obscurePassword),
              icon: Icon(
                _obscurePassword
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                size: 20,
              ),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 16,
            ),
            filled: true,
            fillColor: isDark
                ? Colors.white.withValues(alpha: 0.04)
                : Colors.black.withValues(alpha: 0.03),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.08)
                    : Colors.black.withValues(alpha: 0.08),
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.08)
                    : Colors.black.withValues(alpha: 0.08),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(
                color: theme.colorScheme.primary.withValues(alpha: 0.6),
                width: 1.5,
              ),
            ),
          ),
          onSubmitted: (_) => _verifyPassword(),
        ),
        const SizedBox(height: 20),
        _PrimaryButton(
          label: 'Sign in',
          loading: _loading,
          onPressed: _verifyPassword,
        ),
        const SizedBox(height: 12),
        Center(
          child: TextButton.icon(
            onPressed: () => _setStep(_Step.phone),
            icon: const Icon(Icons.arrow_back_rounded, size: 18),
            label: const Text('Start over'),
            style: TextButton.styleFrom(
              foregroundColor: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              textStyle: const TextStyle(
                fontWeight: FontWeight.w500,
                fontSize: 14,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Supporting Widgets ─────────────────────────────────────────────────────

class _StepDots extends StatelessWidget {
  const _StepDots({required this.currentStep});
  final _Step currentStep;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final current = _Step.values.indexOf(currentStep);

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(3, (i) {
        final isActive = i <= current;
        final isCurrent = i == current;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOutCubic,
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: isCurrent ? 24 : 8,
          height: 8,
          decoration: BoxDecoration(
            color: isActive
                ? theme.colorScheme.primary
                : theme.colorScheme.onSurface.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(4),
          ),
        );
      }),
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  const _PrimaryButton({
    required this.label,
    required this.loading,
    required this.onPressed,
  });

  final String label;
  final bool loading;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      height: 52,
      child: FilledButton(
        onPressed: loading ? null : onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: theme.colorScheme.primary,
          foregroundColor: Colors.white,
          disabledBackgroundColor: theme.colorScheme.primary.withValues(alpha: 0.6),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 16,
          ),
        ),
        child: loading
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: Colors.white,
                ),
              )
            : Text(label),
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.error.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.colorScheme.error.withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.error_outline_rounded,
            color: theme.colorScheme.error,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: theme.colorScheme.error,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
