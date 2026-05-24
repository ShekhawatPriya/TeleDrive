import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import 'auth_controller.dart';
import 'tdlib_session_controller.dart';

class TdlibSessionScreen extends ConsumerStatefulWidget {
  const TdlibSessionScreen({this.returnTo, super.key});

  final String? returnTo;

  @override
  ConsumerState<TdlibSessionScreen> createState() => _TdlibSessionScreenState();
}

class _TdlibSessionScreenState extends ConsumerState<TdlibSessionScreen> {
  final _phone = TextEditingController();
  final _code = TextEditingController();
  final _password = TextEditingController();
  bool _submitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final auth = ref.read(authControllerProvider);
      _phone.text = auth.activeAccount?.phoneNumber ?? '';
      ref.read(tdlibSessionControllerProvider).check(force: true);
    });
  }

  @override
  void dispose() {
    _phone.dispose();
    _code.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_submitting) return;
    final controller = ref.read(tdlibSessionControllerProvider);
    final status = controller.state.status;
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      if (status == TdlibSessionStatus.authorizationRequired) {
        await controller.submitPhoneNumber(_phone.text.trim());
      } else if (status == TdlibSessionStatus.waitCode) {
        await controller.submitCode(_code.text.trim());
      } else if (status == TdlibSessionStatus.waitPassword) {
        await controller.submitPassword(_password.text);
      } else {
        await controller.check(force: true);
      }
      HapticFeedback.lightImpact();
    } catch (err) {
      setState(() => _error = '$err');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _continue() {
    final destination = _destination();
    context.go(destination);
  }

  String _destination() {
    final auth = ref.read(authControllerProvider);
    final target = widget.returnTo;
    if (target != null &&
        target.isNotEmpty &&
        target != '/' &&
        target != '/welcome' &&
        target != '/login' &&
        target != '/tdlib-session') {
      return target;
    }
    if (auth.needsCommunityOnboarding) return '/community-setup';
    return '/drive';
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(tdlibSessionControllerProvider).state;
    final auth = ref.watch(authControllerProvider);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final ready = session.status == TdlibSessionStatus.ready;
    final busy = session.status == TdlibSessionStatus.checking || _submitting;

    if (!auth.isAuthenticated && !auth.loading) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) context.go('/login');
      });
    }

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.xl,
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Icon(
                    ready
                        ? Icons.check_circle_rounded
                        : Icons.phonelink_lock_rounded,
                    color: ready ? scheme.primary : scheme.onSurfaceVariant,
                    size: 56,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    ready
                        ? 'Device Telegram session ready'
                        : 'Connect this device',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    'TeleDrive requires local TDLib file transfer before Drive opens. Private file bytes are not uploaded through TeleDrive backend servers; the backend stores metadata, folders, upload state, and Telegram references.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  if (busy) const LinearProgressIndicator(),
                  if (busy) const SizedBox(height: AppSpacing.md),
                  if (session.message != null)
                    Container(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      decoration: BoxDecoration(
                        color: ready
                            ? scheme.primaryContainer
                            : scheme.surfaceContainerHighest,
                        borderRadius: AppRadii.mdR,
                      ),
                      child: Text(
                        session.message!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: ready
                              ? scheme.onPrimaryContainer
                              : scheme.onSurfaceVariant,
                          height: 1.35,
                        ),
                      ),
                    ),
                  if (_error != null) ...[
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      _error!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.error,
                      ),
                    ),
                  ],
                  const SizedBox(height: AppSpacing.lg),
                  _buildAuthField(session.status),
                  const SizedBox(height: AppSpacing.lg),
                  if (ready)
                    FilledButton(
                      onPressed: _continue,
                      child: const Text('Continue'),
                    )
                  else if (_needsInput(session.status))
                    FilledButton(
                      onPressed: busy ? null : _submit,
                      child: Text(
                        session.status ==
                                TdlibSessionStatus.authorizationRequired
                            ? 'Send code'
                            : 'Continue',
                      ),
                    )
                  else
                    FilledButton.tonal(
                      onPressed: busy
                          ? null
                          : () => ref
                                .read(tdlibSessionControllerProvider)
                                .check(force: true),
                      child: const Text('Retry'),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  bool _needsInput(TdlibSessionStatus status) =>
      status == TdlibSessionStatus.authorizationRequired ||
      status == TdlibSessionStatus.waitCode ||
      status == TdlibSessionStatus.waitPassword;

  Widget _buildAuthField(TdlibSessionStatus status) {
    if (status == TdlibSessionStatus.authorizationRequired) {
      return TextField(
        key: const ValueKey('tdlib-session-phone'),
        controller: _phone,
        keyboardType: TextInputType.phone,
        textInputAction: TextInputAction.next,
        decoration: const InputDecoration(labelText: 'Phone number'),
      );
    }
    if (status == TdlibSessionStatus.waitCode) {
      return TextField(
        key: const ValueKey('tdlib-session-code'),
        controller: _code,
        keyboardType: TextInputType.number,
        textInputAction: TextInputAction.done,
        decoration: const InputDecoration(labelText: 'Verification code'),
        onSubmitted: (_) => _submit(),
      );
    }
    if (status == TdlibSessionStatus.waitPassword) {
      return TextField(
        key: const ValueKey('tdlib-session-password'),
        controller: _password,
        keyboardType: TextInputType.visiblePassword,
        textInputAction: TextInputAction.done,
        obscureText: true,
        autocorrect: false,
        enableSuggestions: false,
        textCapitalization: TextCapitalization.none,
        decoration: const InputDecoration(labelText: 'Cloud password'),
        onSubmitted: (_) => _submit(),
      );
    }
    return const SizedBox.shrink();
  }
}
