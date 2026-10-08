import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../features/search/search_controller.dart';
import 'search_keyboard.dart';

class DriveSearchField extends ConsumerStatefulWidget {
  const DriveSearchField({
    required this.scope,
    this.selectionMode = false,
    this.autofocus = false,
    this.onCancel,
    this.inScrollingHeader = false,
    super.key,
  });
  final SearchScope scope;
  final bool selectionMode;
  final bool autofocus;

  /// A disclosed search stays open until its owner handles Cancel.
  final VoidCallback? onCancel;

  /// Set by the iOS browsing large-title header, where the field scrolls with
  /// content on the plain canvas: touches go to UIKit at once instead of
  /// waiting for the scroll gesture, and the fallback uses the system fill.
  final bool inScrollingHeader;
  @override
  ConsumerState<DriveSearchField> createState() => _DriveSearchFieldState();
}

class _DriveSearchFieldState extends ConsumerState<DriveSearchField>
    with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  late final TextEditingController _text;
  final _focus = FocusNode(debugLabel: 'Drive search');
  late final AnimationController _split;
  MethodChannel? _native;
  bool _available = false, _checked = false, _active = false;
  bool _nativeResolved = false;
  bool _reducedMotion = false;

  String get _hint => widget.selectionMode
      ? 'Search'
      : switch (widget.scope) {
          SearchScope.drive => 'Search files and folders',
          SearchScope.photos => 'Search photos and videos',
          SearchScope.starred => 'Search starred items',
          SearchScope.shared => 'Search shared items',
        };

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _text = TextEditingController(
      text: ref.read(searchQueryProvider(widget.scope)).raw,
    );
    _split = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
      value: widget.onCancel != null ? 1 : 0,
    );
    _active = widget.onCancel != null;
    _focus.addListener(_focusChanged);
  }

  void _focusChanged() {
    if (_focus.hasFocus)
      _setActive(true);
    else if (_text.text.isEmpty && widget.onCancel == null)
      _setActive(false);
  }

  void _setActive(bool value) {
    if (!mounted || _active == value) return;
    setState(() => _active = value);
    if (_reducedMotion)
      _split.value = value ? 1 : 0;
    else
      _split.animateTo(value ? 1 : 0, curve: Curves.easeOutCubic);
    _updateNative();
  }

  void _dismiss({bool cancel = false}) {
    if (cancel) {
      _text.clear();
      ref.read(searchQueryProvider(widget.scope)).clear();
    }
    _focus.unfocus();
    _native?.invokeMethod<void>('dismiss').catchError((Object _) {});
    dismissSearchKeyboard();
    if (widget.onCancel == null && (cancel || _text.text.isEmpty)) {
      _setActive(false);
    }
    if (cancel) widget.onCancel?.call();
  }

  void _changed(String value) {
    ref.read(searchQueryProvider(widget.scope)).update(value);
    setState(() {});
  }

  void _submit() {
    ref.read(searchQueryProvider(widget.scope)).submit();
    _dismiss();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reducedMotion = MediaQuery.disableAnimationsOf(context);
    if (!_checked && Theme.of(context).platform == TargetPlatform.iOS) {
      _checked = true;
      _checkNative();
    }
    _updateNative();
  }

  Future<void> _checkNative() async {
    var supported = false;
    try {
      supported =
          await const MethodChannel(
            'teledrive/appearance',
          ).invokeMethod<bool>('supportsNativeSearch') ??
          false;
    } on PlatformException {
      /* Flutter fallback. */
    } on MissingPluginException {
      /* Portable test host. */
    }
    if (mounted) {
      setState(() {
        _available = supported;
        _nativeResolved = true;
      });
    }
  }

  Map<String, Object> get _configuration => {
    'text': _text.text,
    'placeholder': _hint,
    'active': _active,
    'autofocus': widget.autofocus,
    'keepCancelVisible': widget.onCancel != null,
    'dark': Theme.of(context).brightness == Brightness.dark,
    'textScale': MediaQuery.textScalerOf(context).scale(17) / 17,
    'reduceMotion': _reducedMotion,
    'highContrast': MediaQuery.highContrastOf(context),
  };
  void _updateNative() => _native
      ?.invokeMethod<void>('update', _configuration)
      .catchError((Object _) {});

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) _dismiss();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _native?.invokeMethod<void>('dismiss').catchError((Object _) {});
    _native?.setMethodCallHandler(null);
    _focus.removeListener(_focusChanged);
    _focus.unfocus();
    _focus.dispose();
    _text.dispose();
    _split.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(searchQueryProvider(widget.scope), (_, next) {
      if (_text.text != next.raw) {
        _text.value = TextEditingValue(
          text: next.raw,
          selection: TextSelection.collapsed(offset: next.raw.length),
        );
        _updateNative();
      }
    });
    final theme = Theme.of(context);
    final ios = theme.platform == TargetPlatform.iOS;
    final height = (MediaQuery.textScalerOf(context).scale(17) + 30).clamp(
      48.0,
      76.0,
    );
    return TextFieldTapRegion(
      onTapOutside: (_) => _dismiss(),
      child: SizedBox(
        height: height,
        // An autofocused Flutter field must not briefly own the keyboard before
        // UIKit attaches: disposing that text-input client can hide UIKit's
        // keyboard on the next frame, especially when reopening search.
        child: ios && widget.autofocus && !_nativeResolved
            ? const SizedBox.shrink()
            : _available
            ? UiKitView(
                viewType: 'teledrive/search',
                gestureRecognizers: widget.inScrollingHeader
                    ? {
                        Factory<OneSequenceGestureRecognizer>(
                          EagerGestureRecognizer.new,
                        ),
                      }
                    : const {},
                creationParams: _configuration,
                creationParamsCodec: const StandardMessageCodec(),
                onPlatformViewCreated: (id) {
                  _native = MethodChannel('teledrive/search/$id');
                  _native!.setMethodCallHandler((call) async {
                    if (!mounted) return;
                    switch (call.method) {
                      case 'began':
                        _setActive(true);
                      case 'ended':
                        if (_text.text.isEmpty && widget.onCancel == null) {
                          _setActive(false);
                        }
                      case 'changed':
                        _text.text = call.arguments as String;
                        _changed(_text.text);
                      case 'submitted':
                        _submit();
                      case 'cancelled':
                        _dismiss(cancel: true);
                    }
                  });
                  _updateNative();
                },
              )
            : AnimatedBuilder(
                animation: _split,
                builder: (context, _) => LayoutBuilder(
                  builder: (context, constraints) {
                    final progress = _split.value;
                    final cancelSize = height;
                    final gap = ios ? 12.0 : 8.0;
                    final fieldWidth =
                        constraints.maxWidth - (cancelSize + gap) * progress;
                    final fill = ios && widget.inScrollingHeader
                        ? CupertinoColors.tertiarySystemFill.resolveFrom(
                            context,
                          )
                        : theme.colorScheme.surfaceContainerHigh;
                    final border = OutlineInputBorder(
                      borderRadius: BorderRadius.circular(height / 2),
                      borderSide: MediaQuery.highContrastOf(context)
                          ? BorderSide(color: theme.colorScheme.outline)
                          : BorderSide.none,
                    );
                    return Stack(
                      children: [
                        Positioned(
                          left: 0,
                          width: fieldWidth,
                          top: 0,
                          bottom: 0,
                          child: TextField(
                            autofocus: widget.autofocus,
                            controller: _text,
                            focusNode: _focus,
                            textInputAction: TextInputAction.search,
                            onChanged: _changed,
                            onSubmitted: (_) => _submit(),
                            onTapOutside: (_) => _dismiss(),
                            decoration: InputDecoration(
                              hintText: _hint,
                              hintMaxLines: 1,
                              prefixIcon: Icon(
                                ios
                                    ? CupertinoIcons.search
                                    : Icons.search_rounded,
                              ),
                              filled: true,
                              fillColor: fill,
                              border: border,
                              enabledBorder: border,
                              focusedBorder: border,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                              suffixIcon: _text.text.isEmpty
                                  ? null
                                  : IconButton(
                                      tooltip: 'Clear search',
                                      icon: Icon(
                                        ios
                                            ? CupertinoIcons.xmark_circle_fill
                                            : Icons.cancel_rounded,
                                        size: 20,
                                      ),
                                      onPressed: () {
                                        _text.clear();
                                        ref
                                            .read(
                                              searchQueryProvider(widget.scope),
                                            )
                                            .clear();
                                        _focus.requestFocus();
                                        setState(() {});
                                      },
                                    ),
                            ),
                          ),
                        ),
                        Positioned(
                          right: 0,
                          top: 0,
                          bottom: 0,
                          width: cancelSize,
                          child: IgnorePointer(
                            ignoring: !_active,
                            child: ExcludeSemantics(
                              excluding: !_active,
                              child: Opacity(
                                opacity: progress,
                                child: Transform.scale(
                                  scale: .8 + .2 * progress,
                                  child: Material(
                                    color: fill,
                                    shape: const CircleBorder(),
                                    child: IconButton(
                                      tooltip: 'Cancel search',
                                      onPressed: () => _dismiss(cancel: true),
                                      icon: Icon(
                                        ios
                                            ? CupertinoIcons.xmark
                                            : Icons.close_rounded,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
      ),
    );
  }
}
