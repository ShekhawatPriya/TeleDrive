import 'dart:ui' as ui;

import 'package:dio/dio.dart';

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

import 'ios_menu/ios_menu_models.dart';
import 'ios_menu/native_menu_payload.dart';

/// A lazy tile keeps its Flutter content and media cache. UIKit owns the hold,
/// lift, preview, menu, haptics and dismissal. Source snapshots animate the lift;
/// a separate cancellable loader supplies actual preview content.
class NativeItemContextMenu extends StatefulWidget {
  const NativeItemContextMenu({
    required this.child,
    required this.identity,
    required this.title,
    required this.onOpen,
    required this.sectionsBuilder,
    this.trailingClearance = 0,
    this.previewLoader,
    this.previewSymbol = 'doc',
    this.subtitle = '',
    this.previewRevision = '',
    this.hasVisualPreview = false,
    super.key,
  });
  final Widget child;
  final String identity, title;
  final VoidCallback onOpen;
  final List<IosMenuSection> Function() sectionsBuilder;
  final double trailingClearance;
  final Future<Map<String, String>?> Function(CancelToken)? previewLoader;
  final String previewSymbol, subtitle, previewRevision;
  final bool hasVisualPreview;

  @override
  State<NativeItemContextMenu> createState() => _NativeItemContextMenuState();
}

class _NativeItemContextMenuState extends State<NativeItemContextMenu> {
  final _snapshotKey = GlobalKey();
  MethodChannel? _channel;
  bool _available = false;
  bool _previewActive = false;
  bool _checked = false;
  int _generation = 0;
  CancelToken? _previewToken;
  Map<String, VoidCallback> _actions = {};

  Map<String, Object> get _configuration => {
    'identity': widget.identity,
    'title': widget.title,
    'symbol': widget.previewSymbol,
    'subtitle': widget.subtitle,
    'visualPreview': widget.hasVisualPreview,
    'revision': widget.previewRevision,
    'dark': Theme.of(context).brightness == Brightness.dark,
  };

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_checked) {
      _checked = true;
      _check();
    }
    _update();
  }

  Future<void> _check() async {
    try {
      final available =
          await const MethodChannel(
            'teledrive/appearance',
          ).invokeMethod<bool>('supportsContextMenus') ??
          false;
      if (mounted) setState(() => _available = available);
    } on PlatformException {
      /* Functional Cupertino fallback. */
    } on MissingPluginException {
      /* Widget tests / old host. */
    }
  }

  @override
  void didUpdateWidget(NativeItemContextMenu oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.identity != widget.identity ||
        oldWidget.previewRevision != widget.previewRevision) {
      _previewToken?.cancel();
      _generation++;
      _previewActive = false;
      _actions = {};
    }
    _update();
  }

  void _update() {
    _channel
        ?.invokeMethod<void>('update', _configuration)
        .catchError((Object _) {});
  }

  Future<Object?> _handle(MethodCall call) async {
    if (!mounted || call.arguments != widget.identity) return null;
    if (call.method == 'menuRequest') {
      final payload = NativeMenuPayload(widget.sectionsBuilder());
      _actions = payload.actions;
      return payload.sections;
    }
    if (call.method == 'previewCancel') {
      _previewToken?.cancel();
      return null;
    }
    if (call.method == 'previewRequest') {
      _previewToken?.cancel();
      final token = _previewToken = CancelToken();
      final generation = _generation;
      Map<String, String>? preview;
      try {
        preview = await widget.previewLoader?.call(token);
      } catch (_) {
        /* Unavailable sources retain the native identity card. */
      }
      if (!mounted || token.isCancelled || generation != _generation)
        return null;
      return preview;
    }
    if (call.method == 'snapshotRequest') {
      final generation = _generation;
      final boundary = _snapshotKey.currentContext?.findRenderObject();
      if (boundary is! RenderRepaintBoundary ||
          !boundary.hasSize ||
          boundary.debugNeedsPaint)
        return null;
      final longest = boundary.size.longestSide;
      if (longest <= 0) return null;
      final image = await boundary.toImage(
        pixelRatio: (768 / longest).clamp(.01, 3.0),
      );
      try {
        final data = await image.toByteData(format: ui.ImageByteFormat.png);
        if (!mounted || generation != _generation) return null;
        return data?.buffer.asUint8List();
      } finally {
        image.dispose();
      }
    }
    if (call.method == 'open') widget.onOpen();
    return null;
  }

  @override
  void dispose() {
    _generation++;
    _previewToken?.cancel();
    _channel?.setMethodCallHandler(null);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_available) {
      final items = widget.sectionsBuilder().expand((section) => section.items);
      return LayoutBuilder(
        builder: (context, constraints) {
          // Cupertino's lifted child receives unconstrained space. Preserve the
          // source bounds so list rows and grid cards can still lay out safely.
          final width = constraints.maxWidth.isFinite
              ? constraints.maxWidth
              : MediaQuery.sizeOf(context).width;
          final height = constraints.hasTightHeight
              ? constraints.maxHeight
              : double.infinity;
          return CupertinoContextMenu.builder(
            actions: [
              for (final action in items)
                CupertinoContextMenuAction(
                  isDestructiveAction: action.destructive,
                  trailingIcon: action.leadingIcon,
                  onPressed: () {
                    Navigator.of(context, rootNavigator: true).pop();
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (mounted) action.onTap();
                    });
                  },
                  child: Text(action.label),
                ),
            ],
            builder: (menuContext, animation) {
              final source =
                  menuContext
                      .findAncestorStateOfType<_NativeItemContextMenuState>() ==
                  this;
              final child = ConstrainedBox(
                constraints: BoxConstraints(maxWidth: width, maxHeight: height),
                child: RepaintBoundary(
                  // Only the source owns this key. The fallback's lifted copy
                  // lives in an overlay and must have its own render subtree.
                  key: source ? _snapshotKey : null,
                  child: widget.child,
                ),
              );
              return source
                  ? child
                  : FittedBox(
                      fit: BoxFit.cover,
                      child: ClipRSuperellipse(
                        borderRadius: BorderRadius.circular(
                          CupertinoContextMenu.kOpenBorderRadius *
                              animation.value,
                        ),
                        child: child,
                      ),
                    );
            },
          );
        },
      );
    }
    final accessible = widget.sectionsBuilder().expand(
      (section) => section.items,
    );
    return Semantics(
      customSemanticsActions: {
        for (final action in accessible)
          CustomSemanticsAction(label: action.label): action.onTap,
      },
      child: Stack(
        children: [
          Opacity(
            opacity: _previewActive ? 0 : 1,
            child: RepaintBoundary(key: _snapshotKey, child: widget.child),
          ),
          Positioned.fill(
            right: widget.trailingClearance,
            child: ExcludeSemantics(
              child: UiKitView(
                viewType: 'teledrive/item-context-menu',
                gestureRecognizers: {
                  Factory<LongPressGestureRecognizer>(
                    () => LongPressGestureRecognizer(),
                  ),
                },
                creationParamsCodec: const StandardMessageCodec(),
                creationParams: _configuration,
                onPlatformViewCreated: (id) {
                  _channel = MethodChannel('teledrive/item-context-menu/$id');
                  _channel!.setMethodCallHandler((call) async {
                    if (call.method == 'visibility') {
                      final args = Map<Object?, Object?>.from(
                        call.arguments as Map,
                      );
                      if (mounted && args['identity'] == widget.identity) {
                        setState(
                          () => _previewActive = args['visible'] == true,
                        );
                      }
                      return null;
                    }
                    if (call.method == 'menuAction') {
                      final args = Map<Object?, Object?>.from(
                        call.arguments as Map,
                      );
                      if (mounted && args['identity'] == widget.identity)
                        _actions[args['id']]?.call();
                      return null;
                    }
                    return _handle(call);
                  });
                  _update();
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
