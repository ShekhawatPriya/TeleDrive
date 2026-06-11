import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/app_config.dart';

/// How the currently active backend URL was obtained.
enum BackendSource {
  /// Address typed by the user in Settings > Server Connection.
  manual,

  /// Address pinned at build time via API_BASE_URL in .env.local.
  environment,

  /// Last known good address, re-verified with a health probe.
  cached,

  /// Backend reached via loopback: adb-reverse USB tunnel on a physical
  /// device, host machine from the Android emulator (10.0.2.2), or the same
  /// desktop (127.0.0.1).
  sameMachine,

  /// Backend answered the UDP discovery broadcast on this network.
  discovered,

  /// Backend found by probing /api/health across the local subnet.
  scanned,

  /// Nothing reachable; using the best guess so requests fail loudly.
  fallback,
}

enum BackendStatus { resolving, connected, unreachable }

final backendResolverProvider = ChangeNotifierProvider<BackendResolver>((ref) {
  final resolver = BackendResolver()..start();
  ref.onDispose(resolver.shutdown);
  return resolver;
});

/// Resolves the backend base URL at runtime so the app follows the backend
/// across WiFi networks without editing .env.local.
///
/// Resolution order: manual override > API_BASE_URL from .env.local >
/// last known good address > same machine > UDP discovery broadcast >
/// LAN subnet scan. The chain re-runs on every connectivity change and
/// whenever a request fails to connect.
///
/// Note: stable identity hashing (TDLib directories, secure-storage keys)
/// intentionally keeps using the static [AppConfig.apiBaseUrl] so identities
/// do not churn when the network changes.
class BackendResolver extends ChangeNotifier {
  BackendResolver();

  static const _manualUrlKey = 'backend_manual_url';
  static const _lastKnownUrlKey = 'backend_last_known_url';
  static const _discoveryProbe = 'TELEDRIVE_DISCOVER_V1';

  String _baseUrl = AppConfig.configuredApiBaseUrl ?? AppConfig.apiBaseUrl;
  BackendStatus _status = BackendStatus.resolving;
  BackendSource _source = BackendSource.fallback;
  String? _manualUrl;
  bool _manualLoaded = false;

  bool _started = false;
  final Completer<void> _firstResolution = Completer<void>();
  Future<String>? _inFlight;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;
  Timer? _connectivityDebounce;
  DateTime? _lastFailureRefresh;
  DateTime? _lastResolveCompletedAt;

  final Dio _probeDio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 2),
      receiveTimeout: const Duration(seconds: 2),
      sendTimeout: const Duration(seconds: 2),
      headers: {'Accept': 'application/json'},
    ),
  );

  final Dio _scanDio = Dio(
    BaseOptions(
      connectTimeout: const Duration(milliseconds: 700),
      receiveTimeout: const Duration(milliseconds: 700),
      sendTimeout: const Duration(milliseconds: 700),
      headers: {'Accept': 'application/json'},
    ),
  );

  String get baseUrl => _baseUrl;
  BackendStatus get status => _status;
  BackendSource get source => _source;
  String? get manualUrl => _manualUrl;
  bool get autoMode =>
      _manualUrl == null && AppConfig.configuredApiBaseUrl == null;

  String get sourceLabel {
    switch (_source) {
      case BackendSource.manual:
        return 'Manual address';
      case BackendSource.environment:
        return 'Pinned by build config (.env.local)';
      case BackendSource.cached:
        return 'Last known address';
      case BackendSource.sameMachine:
        return 'Same machine (USB tunnel or emulator)';
      case BackendSource.discovered:
        return 'Auto-discovered on this network';
      case BackendSource.scanned:
        return 'Found by network scan';
      case BackendSource.fallback:
        return 'Default address (nothing found yet)';
    }
  }

  void start() {
    if (_started) return;
    _started = true;
    _connectivitySub = Connectivity().onConnectivityChanged.listen((_) {
      _connectivityDebounce?.cancel();
      _connectivityDebounce = Timer(
        const Duration(milliseconds: 600),
        () => refresh(),
      );
    });
    refresh();
  }

  void shutdown() {
    _connectivityDebounce?.cancel();
    _connectivitySub?.cancel();
    _probeDio.close(force: true);
    _scanDio.close(force: true);
  }

  /// Completes once the first resolution pass has finished, so requests made
  /// during startup don't race ahead with a stale address. Bounded so a dead
  /// network can never wedge the request pipeline.
  Future<void> ensureResolved() {
    if (_firstResolution.isCompleted) return Future.value();
    return _firstResolution.future.timeout(
      const Duration(seconds: 25),
      onTimeout: () {},
    );
  }

  /// Re-runs the resolution chain. Concurrent calls share one pass.
  Future<String> refresh() {
    return _inFlight ??= _resolve().whenComplete(() => _inFlight = null);
  }

  /// When the last pass found nothing, re-checks (throttled) so a request
  /// made shortly after the backend comes up recovers without waiting for a
  /// connectivity change. No-op while connected.
  Future<void> recheckIfUnreachable() async {
    if (_status != BackendStatus.unreachable) return;
    final pending = _inFlight;
    if (pending != null) {
      await pending;
      return;
    }
    final last = _lastResolveCompletedAt;
    if (last != null &&
        DateTime.now().difference(last) < const Duration(seconds: 8)) {
      return;
    }
    await refresh();
  }

  /// Human-readable explanation used when requests are rejected because no
  /// backend is reachable.
  String get unreachableMessage {
    switch (_source) {
      case BackendSource.manual:
        return 'Backend at $_baseUrl is not responding (manual address). '
            'Fix or clear it in Settings > Server Connection.';
      case BackendSource.environment:
        return 'Backend at $_baseUrl is not responding '
            '(pinned by API_BASE_URL in .env.local).';
      default:
        return 'Backend not found on this network. Make sure the PC running '
            'the backend is on the same WiFi/hotspot and the server is up, '
            'then re-scan in Settings > Server Connection.';
    }
  }

  /// Called by [ApiClient] when a request could not reach [failedBaseUrl].
  /// Returns true when resolution produced a different address, meaning a
  /// retry against the new address is worthwhile.
  Future<bool> onConnectionFailure(String failedBaseUrl) async {
    final pending = _inFlight;
    if (pending != null) return await pending != failedBaseUrl;
    final now = DateTime.now();
    final last = _lastFailureRefresh;
    if (last != null && now.difference(last) < const Duration(seconds: 8)) {
      return _baseUrl != failedBaseUrl;
    }
    _lastFailureRefresh = now;
    return await refresh() != failedBaseUrl;
  }

  /// Sets (or clears, when [raw] is null/empty) the manual address override
  /// and re-resolves immediately.
  Future<void> setManualUrl(String? raw) async {
    final prefs = await SharedPreferences.getInstance();
    final trimmed = raw?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      _manualUrl = null;
      await prefs.remove(_manualUrlKey);
    } else {
      _manualUrl = normalizeBackendUrl(trimmed);
      await prefs.setString(_manualUrlKey, _manualUrl!);
    }
    _manualLoaded = true;
    notifyListeners();
    await refresh();
  }

  /// Accepts '192.168.1.50', '192.168.1.50:9000', or a full URL and returns a
  /// canonical base URL ending in the API prefix without a trailing slash.
  static String normalizeBackendUrl(String raw) {
    var value = raw.trim();
    if (!value.contains('://')) value = 'http://$value';
    final uri = Uri.parse(value);
    final port = uri.hasPort ? uri.port : AppConfig.backendPort;
    var path = uri.path;
    if (path.isEmpty || path == '/') path = AppConfig.backendApiPrefix;
    while (path.endsWith('/')) {
      path = path.substring(0, path.length - 1);
    }
    return '${uri.scheme}://${uri.host}:$port$path';
  }

  /// Builds an absolute URI for [path] against the currently resolved base.
  Uri apiUri(String path, [Map<String, dynamic>? query]) =>
      AppConfig.buildApiUri(_baseUrl, path, query);

  Future<String> _resolve() async {
    _status = BackendStatus.resolving;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    if (!_manualLoaded) {
      _manualUrl = prefs.getString(_manualUrlKey);
      _manualLoaded = true;
    }

    // 1. Manual override always wins, reachable or not, so the user's choice
    // is never silently replaced.
    final manual = _manualUrl;
    if (manual != null) {
      final ok = await _isHealthy(manual);
      return _apply(
        manual,
        BackendSource.manual,
        ok ? BackendStatus.connected : BackendStatus.unreachable,
      );
    }

    // 2. A build-time API_BASE_URL counts as "specific address provided".
    final env = AppConfig.configuredApiBaseUrl;
    if (env != null) {
      final ok = await _isHealthy(env);
      return _apply(
        env,
        BackendSource.environment,
        ok ? BackendStatus.connected : BackendStatus.unreachable,
      );
    }

    // 3. Same network as last time: the cached address answers instantly.
    final cached = prefs.getString(_lastKnownUrlKey);
    if (cached != null && await _isHealthy(cached)) {
      return _apply(cached, BackendSource.cached, BackendStatus.connected);
    }

    // 4. Backend on the same machine (emulator loopback / desktop).
    for (final candidate in _sameMachineCandidates()) {
      if (await _isHealthy(candidate)) {
        await prefs.setString(_lastKnownUrlKey, candidate);
        return _apply(
          candidate,
          BackendSource.sameMachine,
          BackendStatus.connected,
        );
      }
    }

    // 5. UDP discovery broadcast — answered in milliseconds when the backend
    // runs uvicorn directly on the LAN.
    final discovered = await _discoverViaUdp();
    if (discovered != null && await _isHealthy(discovered)) {
      await prefs.setString(_lastKnownUrlKey, discovered);
      return _apply(
        discovered,
        BackendSource.discovered,
        BackendStatus.connected,
      );
    }

    // 6. Subnet scan — covers Docker-hosted backends where broadcasts don't
    // reach the container.
    final scanned = await _scanSubnets();
    if (scanned != null) {
      await prefs.setString(_lastKnownUrlKey, scanned);
      return _apply(scanned, BackendSource.scanned, BackendStatus.connected);
    }

    // Nothing reachable: keep the most plausible address so requests surface
    // a clear connection error instead of hanging on an empty base URL.
    final guess = cached ?? AppConfig.apiBaseUrl;
    return _apply(guess, BackendSource.fallback, BackendStatus.unreachable);
  }

  String _apply(String url, BackendSource source, BackendStatus status) {
    _baseUrl = url;
    _source = source;
    _status = status;
    _lastResolveCompletedAt = DateTime.now();
    if (!_firstResolution.isCompleted) _firstResolution.complete();
    notifyListeners();
    return url;
  }

  List<String> _sameMachineCandidates() {
    final port = AppConfig.backendPort;
    final prefix = AppConfig.backendApiPrefix;
    return [
      // Loopback first: hits the adb-reverse USB tunnel on physical devices
      // (run-dev.ps1 sets it up) and the same machine on desktop. On an
      // emulator without a tunnel this is refused instantly, costing nothing.
      'http://127.0.0.1:$port$prefix',
      // Android emulator alias for the host machine.
      if (Platform.isAndroid) 'http://10.0.2.2:$port$prefix',
    ];
  }

  Future<bool> _isHealthy(String base, {bool quick = false}) async {
    try {
      final dio = quick ? _scanDio : _probeDio;
      final response = await dio.getUri<dynamic>(Uri.parse('$base/health'));
      final data = response.data;
      return response.statusCode == 200 &&
          data is Map &&
          (data.containsKey('database_ok') || data.containsKey('ok'));
    } catch (_) {
      return false;
    }
  }

  Future<String?> _discoverViaUdp() async {
    RawDatagramSocket socket;
    try {
      socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
    } catch (_) {
      return null;
    }
    socket.broadcastEnabled = true;

    final completer = Completer<String?>();
    final subscription = socket.listen(
      (event) {
        if (event != RawSocketEvent.read) return;
        final datagram = socket.receive();
        if (datagram == null) return;
        try {
          final payload = jsonDecode(utf8.decode(datagram.data));
          if (payload is! Map || payload['service'] != 'teledrive') return;
          final port = payload['port'] is int
              ? payload['port'] as int
              : AppConfig.backendPort;
          final prefix =
              payload['api_prefix'] as String? ?? AppConfig.backendApiPrefix;
          final url = 'http://${datagram.address.address}:$port$prefix';
          if (!completer.isCompleted) completer.complete(url);
        } catch (_) {
          // Not a discovery reply; ignore.
        }
      },
      // Failed broadcast sends (e.g. WiFi without an IPv4 lease) surface
      // asynchronously on this stream, not at the send() call site. Swallow
      // them — the subnet scan is the fallback.
      onError: (Object _) {},
      cancelOnError: false,
    );

    try {
      final probe = utf8.encode(_discoveryProbe);
      final targets = <InternetAddress>[
        InternetAddress('255.255.255.255'),
        ...await _subnetBroadcastAddresses(),
      ];
      for (var attempt = 0; attempt < 3 && !completer.isCompleted; attempt++) {
        for (final target in targets) {
          try {
            socket.send(probe, target, AppConfig.discoveryPort);
          } catch (_) {
            // Synchronous send failures: same story as onError above.
          }
        }
        await Future.any(<Future<void>>[
          completer.future,
          Future<void>.delayed(const Duration(milliseconds: 700)),
        ]);
      }
      return completer.isCompleted ? await completer.future : null;
    } catch (_) {
      return null;
    } finally {
      await subscription.cancel();
      socket.close();
    }
  }

  Future<List<InternetAddress>> _subnetBroadcastAddresses() async {
    final addresses = <InternetAddress>[];
    for (final ip in await _localWifiAddresses()) {
      final lastDot = ip.lastIndexOf('.');
      if (lastDot > 0) {
        addresses.add(InternetAddress('${ip.substring(0, lastDot)}.255'));
      }
    }
    return addresses;
  }

  Future<String?> _scanSubnets() async {
    final own = await _localWifiAddresses();
    final prefixes = <String>{};
    for (final ip in own) {
      final lastDot = ip.lastIndexOf('.');
      if (lastDot > 0) prefixes.add(ip.substring(0, lastDot));
    }
    if (prefixes.isEmpty) return null;

    final port = AppConfig.backendPort;
    final apiPrefix = AppConfig.backendApiPrefix;
    final candidates = <String>[
      for (final prefix in prefixes)
        for (var host = 1; host < 255; host++)
          if (!own.contains('$prefix.$host')) '$prefix.$host',
    ];

    const batchSize = 48;
    for (var i = 0; i < candidates.length; i += batchSize) {
      final batch = candidates.sublist(
        i,
        min(i + batchSize, candidates.length),
      );
      final results = await Future.wait(
        batch.map((ip) async {
          final base = 'http://$ip:$port$apiPrefix';
          return await _isHealthy(base, quick: true) ? base : null;
        }),
      );
      for (final hit in results) {
        if (hit != null) return hit;
      }
    }
    return null;
  }

  /// IPv4 addresses of interfaces that can plausibly see the backend: private
  /// ranges only, skipping cellular interfaces so we never sweep a carrier
  /// network.
  Future<Set<String>> _localWifiAddresses() async {
    List<NetworkInterface> interfaces;
    try {
      interfaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
        includeLoopback: false,
        includeLinkLocal: false,
      );
    } catch (_) {
      return const {};
    }
    final result = <String>{};
    for (final iface in interfaces) {
      final name = iface.name.toLowerCase();
      if (name.startsWith('rmnet') ||
          name.startsWith('ccmni') ||
          name.startsWith('pdp_ip')) {
        continue;
      }
      for (final address in iface.addresses) {
        final ip = address.address;
        if (_isPrivateIpv4(ip)) result.add(ip);
      }
    }
    return result;
  }

  static bool _isPrivateIpv4(String ip) {
    final parts = ip.split('.').map(int.tryParse).toList();
    if (parts.length != 4 || parts.any((p) => p == null)) return false;
    final a = parts[0]!, b = parts[1]!;
    if (a == 10) return true;
    if (a == 172 && b >= 16 && b <= 31) return true;
    if (a == 192 && b == 168) return true;
    return false;
  }
}
