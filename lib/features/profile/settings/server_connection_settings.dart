part of '../settings_screen.dart';

class _ServerConnectionSettingsTile extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final resolver = ref.watch(backendResolverProvider);
    final statusText = switch (resolver.status) {
      BackendStatus.connected => 'Connected',
      BackendStatus.resolving => 'Searching…',
      BackendStatus.unreachable => 'Offline',
    };
    return _SettingsTile(
      icon: Icons.wifi_find_outlined,
      iconColor: const Color(0xFF5C8FBF),
      title: 'Server Connection',
      subtitle: 'Auto-discover the backend on your WiFi or pin a fixed address',
      statusText: statusText,
      onTap: () => Navigator.of(context).push(
        CupertinoPageRoute(
          builder: (_) => const ServerConnectionSettingsScreen(),
        ),
      ),
    );
  }
}

class ServerConnectionSettingsScreen extends ConsumerStatefulWidget {
  const ServerConnectionSettingsScreen({super.key});

  @override
  ConsumerState<ServerConnectionSettingsScreen> createState() =>
      _ServerConnectionSettingsScreenState();
}

class _ServerConnectionSettingsScreenState
    extends ConsumerState<ServerConnectionSettingsScreen> {
  late final TextEditingController _addressController;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _addressController = TextEditingController(
      text: ref.read(backendResolverProvider).manualUrl ?? '',
    );
  }

  @override
  void dispose() {
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() action, String doneMessage) async {
    setState(() => _busy = true);
    await action();
    if (!mounted) return;
    setState(() => _busy = false);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(doneMessage)));
  }

  @override
  Widget build(BuildContext context) {
    final resolver = ref.watch(backendResolverProvider);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          tooltip: 'Back',
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('Server Connection'),
      ),
      body: ListView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.only(
          top: AppSpacing.md,
          bottom: AppSpacing.xxl,
        ),
        children: [
          _ServerStatusCard(resolver: resolver),
          const SizedBox(height: AppSpacing.xl),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: _settingsSectionLabel(context, 'Automatic Connection'),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: _settingsSectionIntro(
              context,
              'TeleDrive finds the backend by itself: last known address, '
              'same machine, discovery broadcast, then a network scan. It '
              're-checks whenever you change WiFi networks.',
            ),
          ),
          _FlatActionTile(
            title: 'Re-Scan Network',
            subtitle: 'Search this network for the backend again now.',
            onTap: _busy
                ? () {}
                : () => _run(
                    () => ref.read(backendResolverProvider).refresh(),
                    'Network scan finished.',
                  ),
          ),
          const SizedBox(height: AppSpacing.xl),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: _settingsSectionLabel(context, 'Manual Address'),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: _settingsSectionIntro(
              context,
              'Pin a fixed address instead of auto-discovery, e.g. a hosted '
              'server or a PC the scan cannot see. Leave empty for automatic.',
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: TextField(
              controller: _addressController,
              enabled: !_busy,
              keyboardType: TextInputType.url,
              autocorrect: false,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                labelText: 'Backend address',
                hintText: '192.168.1.50, 192.168.1.50:8000, or full URL',
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: Row(
              children: [
                FilledButton.icon(
                  onPressed: _busy
                      ? null
                      : () => _run(
                          () => ref
                              .read(backendResolverProvider)
                              .setManualUrl(_addressController.text),
                          _addressController.text.trim().isEmpty
                              ? 'Switched to automatic discovery.'
                              : 'Manual address saved.',
                        ),
                  icon: const Icon(Icons.save_outlined),
                  label: const Text('Save & Connect'),
                ),
                const SizedBox(width: AppSpacing.sm),
                TextButton(
                  onPressed: _busy || resolver.manualUrl == null
                      ? null
                      : () {
                          _addressController.clear();
                          _run(
                            () => ref
                                .read(backendResolverProvider)
                                .setManualUrl(null),
                            'Switched to automatic discovery.',
                          );
                        },
                  child: const Text('Use Automatic'),
                ),
                if (_busy) ...[
                  const SizedBox(width: AppSpacing.sm),
                  const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          if (AppConfig.configuredApiBaseUrl != null)
            const _WarningText(
              text:
                  'API_BASE_URL is set in .env.local, which pins the address '
                  'and disables auto-discovery for this build. A manual '
                  'address saved here still takes priority.',
            ),
          _WarningText(
            text:
                'The phone and the backend PC must be on the same WiFi '
                'network or hotspot. Discovery uses the backend\'s UDP '
                'responder on port ${AppConfig.discoveryPort}; if a network '
                'blocks it, the subnet scan still finds the backend in a few '
                'seconds.',
          ),
        ],
      ),
    );
  }
}

class _ServerStatusCard extends StatelessWidget {
  const _ServerStatusCard({required this.resolver});

  final BackendResolver resolver;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    final (icon, color, label) = switch (resolver.status) {
      BackendStatus.connected => (
        Icons.cloud_done_outlined,
        const Color(0xFF4C8F87),
        'Connected',
      ),
      BackendStatus.resolving => (
        Icons.wifi_find_outlined,
        scheme.onSurfaceVariant,
        'Searching for backend…',
      ),
      BackendStatus.unreachable => (
        Icons.cloud_off_outlined,
        scheme.error,
        'Backend unreachable',
      ),
    };

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: scheme.outlineVariant.withValues(alpha: 0.4),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (resolver.status == BackendStatus.resolving)
              const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2.4),
              )
            else
              Icon(icon, color: color, size: 24),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: color,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xxs),
                  Text(
                    resolver.baseUrl,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurface,
                      fontFamily: 'monospace',
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xxs),
                  Text(
                    resolver.sourceLabel,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant.withValues(alpha: 0.75),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
