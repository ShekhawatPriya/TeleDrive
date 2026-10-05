import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'auth_controller.dart';

/// Refresh while foregrounded and on return from Telegram. Saved identities
/// use their own credentials; refreshing never switches the active session.
class ProfileRefreshGate extends ConsumerStatefulWidget {
  const ProfileRefreshGate({required this.child, super.key});
  final Widget child;
  @override
  ConsumerState<ProfileRefreshGate> createState() => _ProfileRefreshGateState();
}

class _ProfileRefreshGateState extends ConsumerState<ProfileRefreshGate>
    with WidgetsBindingObserver {
  Timer? _timer;
  ProviderSubscription<AuthController>? _subscription;
  String? _identity;
  bool _foreground = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _subscription = ref.listenManual(authControllerProvider, (_, auth) {
      final identity = auth.isAuthenticated && !auth.loading
          ? '${auth.user!.userId}:${auth.activeAccount?.addedAt}'
          : null;
      if (_identity == identity) return;
      _identity = identity;
      _schedule();
    }, fireImmediately: true);
  }

  void _schedule() {
    _timer?.cancel();
    _timer = null;
    if (!_foreground || _identity == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _foreground) _refresh();
    });
    _timer = Timer.periodic(const Duration(minutes: 2), (_) => _refresh());
  }

  void _refresh() {
    final auth = ref.read(authControllerProvider);
    if (!auth.isAuthenticated || auth.loading || auth.switchingAccount) return;
    unawaited(auth.refreshProfile());
    unawaited(auth.refreshSavedAccountSnapshots());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    _schedule();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    _subscription?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
