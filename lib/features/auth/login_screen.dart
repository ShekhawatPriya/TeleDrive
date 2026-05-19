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

  @override
  void dispose() {
    _phone.dispose();
    _code.dispose();
    _password.dispose();
    super.dispose();
  }

  void _setStep(_Step next) {
    setState(() {
      _step = next;
      _error = null;
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
      final data = await _call(() => ref
          .read(authRepositoryProvider)
          .start('${_selectedCountry.dialCode}$local'));
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
      final data = await _call(() => ref
          .read(authRepositoryProvider)
          .verifyCode(_attemptId!, _code.text.trim()));
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
      final data = await _call(() => ref
          .read(authRepositoryProvider)
          .verifyPassword(_attemptId!, _password.text.trim()));
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
    if (picked != null) setState(() => _selectedCountry = picked);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg, vertical: AppSpacing.xl),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 88,
                    height: 88,
                    decoration: BoxDecoration(
                      color: scheme.primaryContainer,
                      borderRadius: AppRadii.xlR,
                    ),
                    child: Icon(
                      Icons.cloud_outlined,
                      color: scheme.onPrimaryContainer,
                      size: 40,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xl),
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
                    'Your data is stored securely on Telegram servers.',
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
    );
  }

  Widget _buildHeader() {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final (title, subtitle) = switch (_step) {
      _Step.phone => (
          'Sign in to TeleDrive',
          'Enter your phone number to connect your Telegram account.'
        ),
      _Step.code => (
          'Verification code',
          'We sent a code to your Telegram app. Enter it below.'
        ),
      _Step.password => (
          'Two-factor authentication',
          'Your account has 2FA enabled. Enter your cloud password.'
        ),
    };

    return Column(
      children: [
        Text(
          title,
          style: theme.textTheme.headlineSmall,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          subtitle,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: scheme.onSurfaceVariant,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildFormCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _StepIndicator(currentStep: _step),
            const SizedBox(height: AppSpacing.lg),
            if (_error != null) ...[
              _ErrorBanner(message: _error!),
              const SizedBox(height: AppSpacing.md),
            ],
            if (_step == _Step.phone) _buildPhoneStep(),
            if (_step == _Step.code) _buildCodeStep(),
            if (_step == _Step.password) _buildPasswordStep(),
          ],
        ),
      ),
    );
  }

  Widget _buildPhoneStep() {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InkWell(
          onTap: _pickCountry,
          borderRadius: AppRadii.xsR,
          child: InputDecorator(
            decoration: InputDecoration(
              labelText: 'Country',
              prefixIcon: Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                child: Text(_selectedCountry.flag,
                    style: const TextStyle(fontSize: 22)),
              ),
              prefixIconConstraints: const BoxConstraints(minWidth: 44),
              suffixIcon: Icon(Icons.arrow_drop_down_rounded,
                  color: scheme.onSurfaceVariant),
            ),
            child: Text(
              '${_selectedCountry.name} (${_selectedCountry.dialCode})',
              style: theme.textTheme.bodyLarge,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        TextField(
          controller: _phone,
          keyboardType: TextInputType.phone,
          textInputAction: TextInputAction.send,
          decoration: InputDecoration(
            labelText: 'Phone number',
            prefixIcon: const Icon(Icons.phone_outlined),
            prefixText: '${_selectedCountry.dialCode} ',
            prefixStyle: theme.textTheme.bodyLarge,
          ),
          onSubmitted: (_) => _sendCode(),
        ),
        const SizedBox(height: AppSpacing.lg),
        FilledButton(
          onPressed: _loading ? null : _sendCode,
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
          child: _loading
              ? const SizedBox(
                  width: 22, height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2.5))
              : const Text('Continue'),
        ),
      ],
    );
  }

  Widget _buildCodeStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _code,
          keyboardType: TextInputType.number,
          textAlign: TextAlign.center,
          maxLength: 6,
          autofocus: true,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(6),
          ],
          style: Theme.of(context).textTheme.headlineSmall,
          decoration: const InputDecoration(
            labelText: 'Verification code',
            counterText: '',
            hintText: '——————',
          ),
          onSubmitted: (_) => _verifyCode(),
        ),
        const SizedBox(height: AppSpacing.lg),
        FilledButton(
          onPressed: _loading ? null : _verifyCode,
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
          child: _loading
              ? const SizedBox(
                  width: 22, height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2.5))
              : const Text('Verify'),
        ),
        const SizedBox(height: AppSpacing.xs),
        TextButton.icon(
          onPressed: () => _setStep(_Step.phone),
          icon: const Icon(Icons.arrow_back_rounded, size: 18),
          label: const Text('Wrong number?'),
        ),
      ],
    );
  }

  Widget _buildPasswordStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _password,
          keyboardType: TextInputType.visiblePassword,
          textInputAction: TextInputAction.done,
          enableSuggestions: false,
          autocorrect: false,
          obscureText: _obscurePassword,
          autofocus: true,
          decoration: InputDecoration(
            labelText: 'Cloud password',
            prefixIcon: const Icon(Icons.lock_outline_rounded),
            suffixIcon: IconButton(
              icon: Icon(_obscurePassword
                  ? Icons.visibility_off_outlined
                  : Icons.visibility_outlined),
              onPressed: () =>
                  setState(() => _obscurePassword = !_obscurePassword),
            ),
          ),
          onSubmitted: (_) => _verifyPassword(),
        ),
        const SizedBox(height: AppSpacing.lg),
        FilledButton(
          onPressed: _loading ? null : _verifyPassword,
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
          child: _loading
              ? const SizedBox(
                  width: 22, height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2.5))
              : const Text('Sign in'),
        ),
        const SizedBox(height: AppSpacing.xs),
        TextButton.icon(
          onPressed: () => _setStep(_Step.phone),
          icon: const Icon(Icons.arrow_back_rounded, size: 18),
          label: const Text('Start over'),
        ),
      ],
    );
  }
}

class _StepIndicator extends StatelessWidget {
  const _StepIndicator({required this.currentStep});
  final _Step currentStep;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final current = _Step.values.indexOf(currentStep);

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(3, (i) {
        final isActive = i <= current;
        final isCurrent = i == current;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 3),
          child: AnimatedContainer(
            duration: AppDurations.medium2,
            curve: AppEasing.emphasized,
            width: isCurrent ? 32 : 8,
            height: 6,
            decoration: BoxDecoration(
              color:
                  isActive ? scheme.primary : scheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
        );
      }),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: scheme.errorContainer,
        borderRadius: AppRadii.smR,
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline_rounded,
              color: scheme.onErrorContainer, size: 20),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              message,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: scheme.onErrorContainer,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
