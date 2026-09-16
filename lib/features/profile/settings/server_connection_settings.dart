part of '../settings_screen.dart';

({IconData icon, Color color, String label}) _statusVisual(
  BackendStatus status,
  ColorScheme scheme,
) {
  return switch (status) {
    BackendStatus.connected => (
      icon: Icons.cloud_done_rounded,
      color: AppColors.success,
      label: 'Connected',
    ),
    BackendStatus.resolving => (
      icon: Icons.wifi_find_outlined,
      color: scheme.primary,
      label: 'Searching for backend…',
    ),
    BackendStatus.unreachable => (
      icon: Icons.cloud_off_rounded,
      color: scheme.error,
      label: 'Backend unreachable',
    ),
  };
}

class _ServerConnectionSettingsTile extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final resolver = ref.watch(backendResolverProvider);
    final scheme = Theme.of(context).colorScheme;
    final visual = _statusVisual(resolver.status, scheme);
    final pillLabel = switch (resolver.status) {
      BackendStatus.connected => 'Connected',
      BackendStatus.resolving => 'Searching…',
      BackendStatus.unreachable => 'Offline',
    };

    return _SettingsMenuTile(
      icon: Icons.wifi_find_outlined,
      iconColor: _accentServer,
      title: 'Server Connection',
      subtitle: 'Auto-discover the backend or pin a fixed address',
      trailing: AnimatedSwitcher(
        duration: AppDurations.short4,
        switchInCurve: AppEasing.standard,
        switchOutCurve: AppEasing.standard,
        child: _SettingsStatusPill(
          key: ValueKey(resolver.status),
          label: pillLabel,
          color: visual.color,
        ),
      ),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
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
        centerTitle: true,
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
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _settingsSectionHeader(context, 'Automatic Connection'),
              _settingsSectionIntro(
                context,
                'TeleDrive finds the backend by itself: last known address, '
                'same machine, discovery broadcast, then a network scan. It '
                're-checks whenever you change WiFi networks.',
              ),
              _SettingsGroupCard(
                dividerIndent: 72,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _SettingsActionTile(
                        title: 'Re-Scan Network',
                        subtitle:
                            'Search this network for the backend again now.',
                        icon: Icons.radar_rounded,
                        iconColor: _accentServer,
                        enabled: !_busy,
                        onTap: _busy
                            ? () {}
                            : () => _run(
                                () =>
                                    ref.read(backendResolverProvider).refresh(),
                                'Network scan finished.',
                              ),
                      ),
                      _SettingsInfoNote(
                        text:
                            'The phone and the backend PC must be on the '
                            'same WiFi network or hotspot. Discovery uses '
                            'the backend\'s UDP responder on port '
                            '${AppConfig.discoveryPort}; if a network '
                            'blocks it, the subnet scan still finds the '
                            'backend in a few seconds.',
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _settingsSectionHeader(context, 'Manual Address'),
              _settingsSectionIntro(
                context,
                'Pin a fixed address instead of auto-discovery, e.g. a '
                'hosted server or a PC the scan cannot see. Leave empty '
                'for automatic.',
              ),
              _ManualAddressCard(
                addressController: _addressController,
                busy: _busy,
                hasManualUrl: resolver.manualUrl != null,
                onSave: () => _run(
                  () => ref
                      .read(backendResolverProvider)
                      .setManualUrl(_addressController.text),
                  _addressController.text.trim().isEmpty
                      ? 'Switched to automatic discovery.'
                      : 'Manual address saved.',
                ),
                onUseAutomatic: () {
                  _addressController.clear();
                  _run(
                    () => ref.read(backendResolverProvider).setManualUrl(null),
                    'Switched to automatic discovery.',
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ManualAddressCard extends StatelessWidget {
  const _ManualAddressCard({
    required this.addressController,
    required this.busy,
    required this.hasManualUrl,
    required this.onSave,
    required this.onUseAutomatic,
  });

  final TextEditingController addressController;
  final bool busy;
  final bool hasManualUrl;
  final VoidCallback onSave;
  final VoidCallback onUseAutomatic;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = scheme.brightness == Brightness.dark;

    return _SettingsGroupCard(
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: addressController,
                    enabled: !busy,
                    keyboardType: TextInputType.url,
                    autocorrect: false,
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: scheme.surfaceContainerHigh,
                      prefixIcon: const Icon(Icons.link_rounded),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: AppRadii.mdR,
                        borderSide: BorderSide(
                          color: scheme.outlineVariant.withValues(
                            alpha: isDark ? 0.18 : 0.5,
                          ),
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: AppRadii.mdR,
                        borderSide: BorderSide(
                          color: scheme.primary,
                          width: 1.5,
                        ),
                      ),
                      border: OutlineInputBorder(borderRadius: AppRadii.mdR),
                      labelText: 'Backend address',
                      hintText: '192.168.1.50, 192.168.1.50:8000, or full URL',
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Row(
                    children: [
                      FilledButton.icon(
                        onPressed: busy ? null : onSave,
                        icon: const Icon(Icons.save_outlined),
                        label: const Text('Save & Connect'),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      TextButton(
                        onPressed: busy || !hasManualUrl
                            ? null
                            : onUseAutomatic,
                        child: const Text('Use Automatic'),
                      ),
                      AnimatedSwitcher(
                        duration: AppDurations.short4,
                        switchInCurve: AppEasing.standard,
                        switchOutCurve: AppEasing.standard,
                        child: busy
                            ? const Padding(
                                padding: EdgeInsets.only(left: AppSpacing.sm),
                                child: SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                ),
                              )
                            : const SizedBox.shrink(),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (AppConfig.configuredApiBaseUrl != null)
              const _SettingsInfoNote(
                tone: _SettingsNoteTone.warning,
                text:
                    'API_BASE_URL is set in .env.local, which pins the '
                    'address and disables auto-discovery for this build. A '
                    'manual address saved here still takes priority.',
              ),
          ],
        ),
      ],
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
    final isDark = scheme.brightness == Brightness.dark;
    final visual = _statusVisual(resolver.status, scheme);
    final resolving = resolver.status == BackendStatus.resolving;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: AppRadii.lgR,
        border: Border.all(
          color: scheme.outlineVariant.withValues(alpha: isDark ? 0.18 : 0.5),
        ),
        boxShadow: isDark
            ? null
            : AppElevation.shadowFor(AppElevation.level1, Brightness.light),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AnimatedSwitcher(
            duration: AppDurations.medium1,
            switchInCurve: AppEasing.emphasizedDecelerate,
            switchOutCurve: AppEasing.emphasizedAccelerate,
            transitionBuilder: (child, animation) => FadeTransition(
              opacity: animation,
              child: ScaleTransition(
                scale: Tween(begin: 0.92, end: 1.0).animate(animation),
                child: child,
              ),
            ),
            child: Row(
              key: ValueKey(resolver.status),
              children: [
                _SettingsIconBadge(
                  icon: visual.icon,
                  color: resolving ? scheme.onSurfaceVariant : visual.color,
                  size: 48,
                  child: resolving
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2.4),
                        )
                      : null,
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        visual.label,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: visual.color,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xxs),
                      Text(
                        resolver.sourceLabel,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant.withValues(
                            alpha: 0.75,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm,
              vertical: AppSpacing.xs,
            ),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHigh,
              borderRadius: AppRadii.smR,
            ),
            child: Text(
              resolver.baseUrl,
              style: theme.textTheme
                  .code(scheme.onSurface)
                  .copyWith(fontSize: 12.5),
            ),
          ),
        ],
      ),
    );
  }
}
