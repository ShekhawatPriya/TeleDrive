import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Reuses the existing UIKit toolbar bridge for the complete photo action bar.
/// The bridge receives symbols and action labels only; media stays in Flutter.
class NativePhotoControls extends StatefulWidget {
  const NativePhotoControls({
    super.key,
    required this.starred,
    required this.infoSelected,
    required this.onStar,
    required this.onInfo,
    required this.onShare,
    this.onDelete,
    this.download = false,
    required this.fallback,
  });
  final bool starred, infoSelected;
  final VoidCallback onStar, onInfo, onShare;
  final VoidCallback? onDelete;
  final bool download;
  final Widget fallback;
  @override
  State<NativePhotoControls> createState() => _NativePhotoControlsState();
}

class _NativePhotoControlsState extends State<NativePhotoControls> {
  MethodChannel? _channel;
  bool _available = false;
  Map<String, Object> get _configuration => {
    'dark': true,
    'photoViewer': true,
    'enabled': true,
    'selectAll': false,
    'clear': false,
    'actions': [
      {
        'label': widget.download ? 'Download' : 'Share',
        'symbol': widget.download
            ? 'square.and.arrow.down'
            : 'square.and.arrow.up',
      },
      {
        'label': widget.starred ? 'Remove star' : 'Add star',
        'symbol': widget.starred ? 'star.fill' : 'star',
        'selected': widget.starred.toString(),
      },
      {
        'label': 'Info',
        'symbol': widget.infoSelected ? 'info.circle.fill' : 'info.circle',
        'selected': widget.infoSelected.toString(),
      },
      if (widget.onDelete != null) {'label': 'Delete', 'symbol': 'trash'},
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
    if (oldWidget.starred != widget.starred ||
        oldWidget.infoSelected != widget.infoSelected ||
        oldWidget.download != widget.download ||
        (oldWidget.onDelete == null) != (widget.onDelete == null)) {
      _update();
    }
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
    width: double.infinity,
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
                if (call.arguments == 'Share' || call.arguments == 'Download')
                  widget.onShare();
                if (call.arguments == 'Delete') widget.onDelete?.call();
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
