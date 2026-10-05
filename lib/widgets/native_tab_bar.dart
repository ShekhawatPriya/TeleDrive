import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class NativeTabBar extends StatefulWidget {
  const NativeTabBar({
    super.key,
    required this.selectedIndex,
    required this.onSelected,
  });
  final int selectedIndex;
  final ValueChanged<int> onSelected;
  @override
  State<NativeTabBar> createState() => _NativeTabBarState();
}

class _NativeTabBarState extends State<NativeTabBar> {
  MethodChannel? _channel;
  bool _native = false;
  Map<String, Object>? _lastConfiguration;
  Map<String, Object> get _config => {
    'selectedIndex': widget.selectedIndex,
    'dark': Theme.of(context).brightness == Brightness.dark,
  };
  @override
  void initState() {
    super.initState();
    _check();
  }

  Future<void> _check() async {
    try {
      final native =
          await const MethodChannel(
            'teledrive/appearance',
          ).invokeMethod<bool>('supportsNativeTabs') ??
          false;
      if (mounted) setState(() => _native = native);
    } on PlatformException {
      /* Cupertino fallback. */
    } on MissingPluginException {
      /* Tests and old hosts. */
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _update();
  }

  @override
  void didUpdateWidget(NativeTabBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    _update();
  }

  void _update() {
    if (_channel == null) return;
    final configuration = _config;
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
  Widget build(BuildContext context) {
    if (!_native)
      return CupertinoTabBar(
        currentIndex: widget.selectedIndex,
        onTap: widget.onSelected,
        backgroundColor: Theme.of(
          context,
        ).colorScheme.surfaceContainerLow.withValues(alpha: .92),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(CupertinoIcons.folder),
            activeIcon: Icon(CupertinoIcons.folder_fill),
            label: 'Drive',
          ),
          BottomNavigationBarItem(
            icon: Icon(CupertinoIcons.photo_on_rectangle),
            label: 'Photos',
          ),
          BottomNavigationBarItem(
            icon: Icon(CupertinoIcons.star),
            activeIcon: Icon(CupertinoIcons.star_fill),
            label: 'Starred',
          ),
          BottomNavigationBarItem(
            icon: Icon(CupertinoIcons.person_2),
            label: 'Shared',
          ),
        ],
      );
    return SizedBox(
      height: 64 + MediaQuery.paddingOf(context).bottom,
      child: UiKitView(
        viewType: 'teledrive/tab-bar',
        creationParamsCodec: const StandardMessageCodec(),
        creationParams: _config,
        onPlatformViewCreated: (id) {
          _lastConfiguration = null;
          _channel = MethodChannel('teledrive/tab-bar/$id');
          _channel!.setMethodCallHandler((call) async {
            if (call.method == 'select' && mounted)
              widget.onSelected(call.arguments as int);
          });
          _update();
        },
      ),
    );
  }
}
