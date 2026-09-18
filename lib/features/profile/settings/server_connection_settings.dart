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
      subtitle: AppConfig.backendPinned
          ? 'One secure connection across your devices'
          : 'Auto-discover the backend or pin a fixed address',
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
    if (_busy) return;
    setState(() => _busy = true);
    var message = doneMessage;
    try {
      await action();
    } catch (_) {
      message = 'Could not connect. Check the address and try again.';
    } finally {
      if (mounted) setState(() => _busy = false);
    }
    if (!mounted) return;
    if (Theme.of(context).platform == TargetPlatform.iOS) {
      await showCupertinoDialog<void>(
        context: context,
        builder: (ctx) => CupertinoAlertDialog(
          title: const Text('Server Connection'),
          content: Text(message),
          actions: [
            CupertinoDialogAction(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  Widget _buildIosServer(BackendResolver resolver) {
    final visual = _statusVisual(
      resolver.status,
      Theme.of(context).colorScheme,
    );
    return IosPage(
      title: 'Server Connection',
      compact: true,
      children: [
        IosSettingsIntro(
          icon: CupertinoIcons.antenna_radiowaves_left_right,
          color: CupertinoColors.systemBlue,
          title: visual.label,
          description: AppConfig.backendPinned
              ? 'Connect to your TeleDrive server from any of your devices.'
              : 'Connect automatically on your network or choose a server address.',
        ),
        IosGroup(
          title: 'Connection',
          children: [
            IosRow(title: 'Source', subtitle: resolver.sourceLabel),
            IosRow(title: 'Server Address', subtitle: resolver.baseUrl),
            IosRow(
              title: _busy ? 'Checking…' : 'Check Connection',
              action: true,
              enabled: !_busy,
              trailing: _busy
                  ? const CupertinoActivityIndicator()
                  : const SizedBox.shrink(),
              onTap: _busy
                  ? null
                  : () => _run(resolver.refresh, 'Connection checked.'),
            ),
          ],
        ),
        if (!AppConfig.backendPinned) ...[
          IosGroup(
            title: 'Manual Address',
            footer:
                'Leave the address empty to find a server automatically on the same Wi-Fi network.',
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: CupertinoTextField(
                  controller: _addressController,
                  enabled: !_busy,
                  keyboardType: TextInputType.url,
                  autocorrect: false,
                  placeholder: 'Server address',
                  decoration: null,
                  placeholderStyle: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  padding: const EdgeInsets.all(12),
                  textInputAction: TextInputAction.done,
                  onSubmitted: _busy ? null : (_) => _saveIosAddress(resolver),
                ),
              ),
              IosRow(
                title: 'Save & Connect',
                action: true,
                enabled: !_busy,
                trailing: const SizedBox.shrink(),
                onTap: _busy ? null : () => _saveIosAddress(resolver),
              ),
              IosRow(
                title: 'Use Automatic Connection',
                action: true,
                enabled: !_busy && resolver.manualUrl != null,
                trailing: const SizedBox.shrink(),
                onTap: _busy || resolver.manualUrl == null
                    ? null
                    : () {
                        _addressController.clear();
                        _run(
                          () => resolver.setManualUrl(null),
                          'Automatic connection enabled.',
                        );
                      },
              ),
            ],
          ),
        ],
      ],
    );
  }

  void _saveIosAddress(BackendResolver resolver) {
    FocusScope.of(context).unfocus();
    _run(
      () => resolver.setManualUrl(_addressController.text),
      'Server address saved.',
    );
  }

  @override
  Widget build(BuildContext context) {
    final resolver = ref.watch(backendResolverProvider);
    if (Theme.of(context).platform == TargetPlatform.iOS)
      return _buildIosServer(resolver);

    return _SettingsScaffold(
      appBar: AppBar(
        centerTitle: true,
        leading: AdaptivePageBackButton(
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
          if (AppConfig.backendPinned) ...[
            _settingsSectionHeader(context, 'Main server'),
            _settingsSectionIntro(
              context,
              'Your devices connect to the same TeleDrive server over the internet. Your computer can stay off.',
            ),
            _SettingsGroupCard(
              children: [
                _SettingsActionTile(
                  title: 'Check connection',
                  subtitle: 'Reconnect to your TeleDrive server.',
                  icon: Icons.refresh_rounded,
                  iconColor: _accentServer,
                  enabled: !_busy,
                  onTap: _busy
                      ? () {}
                      : () => _run(
                          () => ref.read(backendResolverProvider).refresh(),
                          'Connection checked.',
                        ),
                ),
              ],
            ),
          ] else ...[
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
                                  () => ref
                                      .read(backendResolverProvider)
                                      .refresh(),
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
                      () =>
                          ref.read(backendResolverProvider).setManualUrl(null),
                      'Switched to automatic discovery.',
                    );
                  },
                ),
              ],
            ),
          ],
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
                  Wrap(
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.sm,
                    children: [
                      FilledButton.icon(
                        onPressed: busy ? null : onSave,
                        icon: const Icon(Icons.save_outlined),
                        label: const Text(
                          'Save & Connect',
                          textAlign: TextAlign.center,
                        ),
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
            duration: MediaQuery.disableAnimationsOf(context)
                ? Duration.zero
                : AppDurations.medium1,
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
                          color: ColorScheme.fromSeed(
                            seedColor: visual.color,
                            brightness: scheme.brightness,
                            contrastLevel: MediaQuery.highContrastOf(context)
                                ? 1
                                : 0,
                          ).primary,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xxs),
                      Text(
                        resolver.sourceLabel,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
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
