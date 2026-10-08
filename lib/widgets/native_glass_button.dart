import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// UIKit owns glass rendering, accessibility and SF Symbols on supported iOS.
/// Older OS versions and other platforms retain a fully functional control.
class NativeGlassButton extends StatefulWidget {
  const NativeGlassButton({
    super.key,
    required this.label,
    required this.symbol,
    required this.icon,
    required this.onPressed,
    this.white = false,
    this.prominent = false,
    this.width,
    this.visualSize,
    this.size = 48,
    this.symbolSize = 19,
    this.menuBuilder,
    this.onMenuAction,
  });
  final String label, symbol;
  final IconData icon;
  final VoidCallback? onPressed;
  final bool white, prominent;
  final double? width, visualSize;
  final double size, symbolSize;
  final List<Map<String, Object?>> Function()? menuBuilder;
  final ValueChanged<String>? onMenuAction;
  @override
  State<NativeGlassButton> createState() => _NativeGlassButtonState();
}

class _NativeGlassButtonState extends State<NativeGlassButton> {
  MethodChannel? _channel;
  bool _available = false;
  bool _checked = false;
  Map<String, Object>? _lastConfiguration;
  Map<String, Object> get _configuration => {
    'label': widget.label,
    'symbol': widget.symbol,
    'symbolSize': widget.symbolSize,
    'enabled': widget.onPressed != null,
    'white': widget.white,
    'prominent': widget.prominent,
    'visualSize': widget.visualSize ?? widget.size,
    'hasMenu': widget.menuBuilder != null,
    'dark': Theme.of(context).brightness == Brightness.dark || widget.white,
    'textScale': MediaQuery.textScalerOf(context).scale(17) / 17,
  };
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_checked && Theme.of(context).platform == TargetPlatform.iOS) {
      _checked = true;
      _checkAvailability();
    }
    _update();
  }

  Future<void> _checkAvailability() async {
    try {
      final available =
          await const MethodChannel(
            'teledrive/appearance',
          ).invokeMethod<bool>('supportsGlass') ??
          false;
      if (mounted) setState(() => _available = available);
    } on PlatformException {
      /* Cupertino fallback. */
    } on MissingPluginException {
      /* Widget tests and older hosts. */
    }
  }

  @override
  void didUpdateWidget(NativeGlassButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    _update();
  }

  void _update() {
    if (_channel == null) return;
    final configuration = _configuration;
    if (mapEquals(configuration, _lastConfiguration)) return;
    _lastConfiguration = configuration;
    _channel
        ?.invokeMethod<void>('update', configuration)
        .catchError((Object _) {});
  }

  @override
  void dispose() {
    _channel?.setMethodCallHandler(null);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SizedBox(
    width: widget.width ?? widget.size,
    height: widget.size,
    child: _available
        ? UiKitView(
            viewType: 'teledrive/glass-button',
            creationParamsCodec: const StandardMessageCodec(),
            creationParams: _configuration,
            onPlatformViewCreated: (id) {
              _lastConfiguration = null;
              _channel = MethodChannel('teledrive/glass-button/$id');
              _channel!.setMethodCallHandler((call) async {
                if (call.method == 'tap') widget.onPressed?.call();
                if (call.method == 'menuRequest')
                  return widget.menuBuilder?.call() ?? [];
                if (call.method == 'menuAction' && mounted) {
                  widget.onMenuAction?.call(call.arguments as String);
                }
              });
              _update();
            },
          )
        : Tooltip(
            message: widget.label,
            child: CupertinoButton(
              padding: EdgeInsets.zero,
              minimumSize: Size(widget.width ?? widget.size, widget.size),
              onPressed: widget.onPressed,
              child: Container(
                width: widget.width ?? widget.visualSize ?? widget.size,
                height: widget.visualSize ?? widget.size,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: widget.prominent
                      ? CupertinoColors.activeBlue.resolveFrom(context)
                      : widget.white
                      ? const Color(0xCC252529)
                      : Theme.of(context).colorScheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(100),
                ),
                child: widget.symbol.isEmpty
                    ? Text(
                        widget.label,
                        style: Theme.of(context).textTheme.bodyLarge,
                      )
                    : Icon(
                        widget.icon,
                        size: widget.symbolSize,
                        color:
                            (widget.white || widget.prominent
                                    ? Colors.white
                                    : Theme.of(context).colorScheme.onSurface)
                                .withValues(
                                  alpha: widget.onPressed == null ? .3 : 1,
                                ),
                        semanticLabel: widget.label,
                      ),
              ),
            ),
          ),
  );
}

/// Shared navigation affordance for account and settings destinations.
class AdaptivePageBackButton extends StatelessWidget {
  const AdaptivePageBackButton({super.key, this.onPressed});
  final VoidCallback? onPressed;
  @override
  Widget build(BuildContext context) {
    final action = onPressed ?? () => Navigator.of(context).maybePop();
    return Theme.of(context).platform == TargetPlatform.iOS
        ? Padding(
            padding: const EdgeInsets.all(4),
            child: NativeGlassButton(
              label: 'Back',
              symbol: 'chevron.left',
              icon: CupertinoIcons.chevron_back,
              onPressed: action,
            ),
          )
        : BackButton(onPressed: action);
  }
}
