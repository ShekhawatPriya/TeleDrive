import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Reuses the existing UIKit toolbar bridge for one system-glass action group.
/// The bridge receives symbols and action labels only; media stays in Flutter.
class NativePhotoControls extends StatefulWidget {
  const NativePhotoControls({
    super.key,
    required this.starred,
    required this.infoSelected,
    required this.onStar,
    required this.onInfo,
    required this.fallback,
  });
  final bool starred, infoSelected;
  final VoidCallback onStar, onInfo;
  final Widget fallback;
  @override
  State<NativePhotoControls> createState() => _NativePhotoControlsState();
}

class _NativePhotoControlsState extends State<NativePhotoControls> {
  MethodChannel? _channel;
  bool _available = false;
  Map<String, Object> get _configuration => {
    'dark': true,
    'enabled': true,
    'selectAll': false,
    'clear': false,
    'actions': [
      {
        'label': widget.starred ? 'Remove star' : 'Add star',
        'symbol': widget.starred ? 'star.fill' : 'star',
      },
      {
        'label': 'Info',
        'symbol': widget.infoSelected ? 'info.circle.fill' : 'info.circle',
      },
    ],
  };
  @override
  void initState() {
    super.initState();
    _check();
  }

  Future<void> _check() async {
    try {
      final available =
          await const MethodChannel(
            'teledrive/appearance',
          ).invokeMethod<bool>('supportsSelectionToolbar') ??
          false;
      if (mounted) setState(() => _available = available);
    } on PlatformException {
      /* Flutter fallback. */
    } on MissingPluginException {
      /* Tests and older hosts. */
    }
  }

  @override
  void didUpdateWidget(covariant NativePhotoControls oldWidget) {
    super.didUpdateWidget(oldWidget);
    _update();
  }

  void _update() => _channel
      ?.invokeMethod<void>('update', _configuration)
      .catchError((Object _) {});
  @override
  void dispose() {
    _channel?.setMethodCallHandler(null);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 128,
    height: 48,
    child: !_available
        ? widget.fallback
        : UiKitView(
            viewType: 'teledrive/selection-toolbar',
            creationParamsCodec: const StandardMessageCodec(),
            creationParams: _configuration,
            onPlatformViewCreated: (id) {
              _channel = MethodChannel('teledrive/selection-toolbar/$id');
              _channel!.setMethodCallHandler((call) async {
                if (!mounted || call.method != 'action') return;
                if (call.arguments == 'Info') widget.onInfo();
                if (call.arguments == 'Add star' ||
                    call.arguments == 'Remove star')
                  widget.onStar();
              });
              _update();
            },
          ),
  );
}
