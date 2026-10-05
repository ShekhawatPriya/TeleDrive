import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Keeps Flutter materials aligned with UIKit's independent transparency setting.
class IosAccessibilityController extends ChangeNotifier {
  static const _channel = MethodChannel('teledrive/accessibility');
  bool reduceTransparency = false;
  bool _disposed = false;
  int _revision = 0;

  Future<void> start() async {
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'reduceTransparencyChanged') {
        _revision++;
        _apply(call.arguments == true);
      }
    });
    await refresh();
  }

  Future<void> refresh() async {
    final revision = _revision;
    try {
      final value = await _channel.invokeMethod<bool>('getReduceTransparency');
      // A settings notification can arrive while the initial read is pending.
      if (!_disposed && revision == _revision && value != null) _apply(value);
    } on MissingPluginException {
      // Portable hosts retain their MediaQuery contrast fallback.
    } on PlatformException {
      // An unavailable preference must not prevent startup.
    }
  }

  void _apply(bool value) {
    if (_disposed || reduceTransparency == value) return;
    reduceTransparency = value;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _channel.setMethodCallHandler(null);
    super.dispose();
  }
}
