part of '../settings_screen.dart';

class _AppUpdatesSettingsTile extends ConsumerStatefulWidget {
  @override
  ConsumerState<_AppUpdatesSettingsTile> createState() =>
      _AppUpdatesSettingsTileState();
}

class _AppUpdatesSettingsTileState
    extends ConsumerState<_AppUpdatesSettingsTile> {
  bool _busy = false;

  Future<void> _handleTap() async {
    if (_busy) return;
    setState(() => _busy = true);
    final controller = ref.read(appUpdateControllerProvider);
    controller.clearManualMessages();
    await controller.checkForUpdate(reason: AppUpdateCheckReason.manual);
    if (!mounted) return;
    final state = controller.state;
    setState(() => _busy = false);

    if (state.lastError != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not check for updates. Please try again.'),
        ),
      );
      return;
    }

    if (state.update != null) {
      // The AppUpdateGate listener handles surfacing the prompt.
      return;
    }

    if (state.lastManualResultUpToDate) {
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          icon: const Icon(Icons.check_circle_rounded),
          title: const Text("You're up to date"),
          content: const Text('TeleDrive is running the latest version.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return _SettingsTile(
      icon: Icons.system_update_alt_rounded,
      iconColor: const Color(0xFF5C8AA8),
      title: 'App Updates',
      subtitle: 'Check for the latest TeleDrive APK release',
      statusText: _busy ? 'Checking...' : null,
      onTap: _handleTap,
    );
  }
}
