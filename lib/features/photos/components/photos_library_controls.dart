import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/tokens/app_motion.dart';
import '../../../widgets/drive_search_field.dart';
import '../../search/search_controller.dart';
import '../photos_filter.dart';

/// Browsing is the resting state. Search temporarily takes over the same row.
class PhotosLibraryControls extends ConsumerStatefulWidget {
  const PhotosLibraryControls({
    required this.filter,
    required this.onFilterChanged,
    super.key,
  });

  final PhotosFilter filter;
  final ValueChanged<PhotosFilter> onFilterChanged;

  @override
  ConsumerState<PhotosLibraryControls> createState() =>
      _PhotosLibraryControlsState();
}

class _PhotosLibraryControlsState extends ConsumerState<PhotosLibraryControls> {
  late bool _searching;
  bool _focusSearch = false;
  bool _nativeAvailable = false, _nativeChecked = false;
  MethodChannel? _native;
  Map<String, Object>? _lastConfiguration;

  @override
  void initState() {
    super.initState();
    _searching = ref
        .read(searchQueryProvider(SearchScope.photos))
        .raw
        .isNotEmpty;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_nativeChecked && Theme.of(context).platform == TargetPlatform.iOS) {
      _nativeChecked = true;
      _checkNative();
    }
    _updateNative();
  }

  Future<void> _checkNative() async {
    try {
      final available =
          await const MethodChannel(
            'teledrive/appearance',
          ).invokeMethod<bool>('supportsPhotosControls') ??
          false;
      if (mounted) setState(() => _nativeAvailable = available);
    } on MissingPluginException {
      // Portable widget tests and hosts without this bridge.
    } on PlatformException {
      // Retain the functional Flutter controls.
    }
  }

  Map<String, Object> get _configuration => {
    'text': ref.read(searchQueryProvider(SearchScope.photos)).raw,
    'selected': widget.filter.index,
    'searching': _searching,
    'dark': Theme.of(context).brightness == Brightness.dark,
    'textScale': MediaQuery.textScalerOf(context).scale(17) / 17,
    'reduceMotion': MediaQuery.disableAnimationsOf(context),
    'highContrast': MediaQuery.highContrastOf(context),
  };

  void _updateNative() {
    if (_native == null) return;
    final configuration = _configuration;
    if (mapEquals(configuration, _lastConfiguration)) return;
    _lastConfiguration = configuration;
    _native
        ?.invokeMethod<void>('update', configuration)
        .catchError((Object _) {});
  }

  @override
  void didUpdateWidget(PhotosLibraryControls oldWidget) {
    super.didUpdateWidget(oldWidget);
    _updateNative();
  }

  @override
  void dispose() {
    _native?.invokeMethod<void>('dispose').catchError((Object _) {});
    _native?.setMethodCallHandler(null);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(
      searchQueryProvider(SearchScope.photos),
      (_, _) => _updateNative(),
    );
    final theme = Theme.of(context);
    final ios = theme.platform == TargetPlatform.iOS;
    final reducedMotion = MediaQuery.disableAnimationsOf(context);
    final height = (MediaQuery.textScalerOf(context).scale(17) + 30).clamp(
      48.0,
      76.0,
    );
    if (ios && _nativeAvailable) {
      return TextFieldTapRegion(
        onTapOutside: (_) =>
            _native?.invokeMethod<void>('dismiss').catchError((Object _) {}),
        child: SizedBox(
          height: height,
          child: UiKitView(
            key: const ValueKey('photos-native-library-controls'),
            viewType: 'teledrive/photos-controls',
            gestureRecognizers: {
              Factory<OneSequenceGestureRecognizer>(
                () => EagerGestureRecognizer(),
              ),
            },
            creationParams: _configuration,
            creationParamsCodec: const StandardMessageCodec(),
            onPlatformViewCreated: (id) {
              _native = MethodChannel('teledrive/photos-controls/$id');
              _lastConfiguration = null;
              _native!.setMethodCallHandler((call) async {
                if (!mounted) return;
                final query = ref.read(searchQueryProvider(SearchScope.photos));
                switch (call.method) {
                  case 'selected':
                    final index = call.arguments;
                    if (index is int &&
                        index >= 0 &&
                        index < PhotosFilter.values.length) {
                      widget.onFilterChanged(PhotosFilter.values[index]);
                    }
                  case 'searching':
                    _searching = call.arguments == true;
                  case 'changed':
                    query.update(call.arguments as String);
                  case 'submitted':
                    query.submit();
                  case 'cancelled':
                    _searching = false;
                    query.clear();
                }
              });
              _updateNative();
            },
          ),
        ),
      );
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final controls = AnimatedSwitcher(
          duration: reducedMotion ? Duration.zero : AppDurations.medium1,
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          layoutBuilder: (current, previous) => SizedBox(
            width: constraints.maxWidth,
            child: Stack(
              alignment: Alignment.topLeft,
              children: [
                for (final child in previous) Positioned.fill(child: child),
                ?current,
              ],
            ),
          ),
          transitionBuilder: (child, animation) {
            final search = child.key == const ValueKey('photos-search-open');
            return IgnorePointer(
              ignoring: search != _searching,
              child: ExcludeSemantics(
                excluding: search != _searching,
                child: FadeTransition(
                  opacity: animation,
                  child: search
                      ? AnimatedBuilder(
                          animation: animation,
                          child: child,
                          builder: (context, child) => ClipRect(
                            child: Align(
                              alignment: Alignment.centerLeft,
                              widthFactor:
                                  height / constraints.maxWidth +
                                  (1 - height / constraints.maxWidth) *
                                      animation.value,
                              child: child,
                            ),
                          ),
                        )
                      : child,
                ),
              ),
            );
          },
          child: _searching
              ? SizedBox(
                  key: const ValueKey('photos-search-open'),
                  width: constraints.maxWidth,
                  child: DriveSearchField(
                    scope: SearchScope.photos,
                    autofocus: _focusSearch,
                    onCancel: () => setState(() => _searching = false),
                  ),
                )
              : Row(
                  key: const ValueKey('photos-browse-controls'),
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox.square(
                      dimension: height,
                      child: IconButton.filledTonal(
                        tooltip: 'Search photos and videos',
                        style: IconButton.styleFrom(
                          backgroundColor:
                              theme.colorScheme.surfaceContainerHigh,
                          foregroundColor: theme.colorScheme.onSurface,
                        ),
                        onPressed: () => setState(() {
                          _focusSearch = true;
                          _searching = true;
                        }),
                        icon: Icon(
                          ios ? CupertinoIcons.search : Icons.search_rounded,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(child: _filters(context, height)),
                  ],
                ),
        );
        return reducedMotion
            ? controls
            : AnimatedSize(
                alignment: Alignment.topLeft,
                duration: AppDurations.medium1,
                curve: Curves.easeOutCubic,
                child: controls,
              );
      },
    );
  }

  Widget _filters(BuildContext context, double height) {
    final theme = Theme.of(context);
    final ios = theme.platform == TargetPlatform.iOS;
    final style = theme.textTheme.labelLarge;
    String label(PhotosFilter filter) =>
        filter == PhotosFilter.all ? 'All media' : filter.label;
    return LayoutBuilder(
      builder: (context, constraints) {
        final measure = TextPainter(
          text: TextSpan(text: 'All media', style: style),
          textDirection: Directionality.of(context),
          textScaler: MediaQuery.textScalerOf(context),
        )..layout();
        final fitsSegments =
            (measure.width + 12) * 3 + 8 <= constraints.maxWidth;
        measure.dispose();
        if (ios && fitsSegments) {
          return SizedBox(
            height: height,
            width: double.infinity,
            child: CupertinoSlidingSegmentedControl<PhotosFilter>(
              groupValue: widget.filter,
              backgroundColor: theme.colorScheme.surfaceContainer,
              thumbColor: theme.colorScheme.surfaceContainerLow,
              children: {
                for (final filter in PhotosFilter.values)
                  filter: SizedBox(
                    height: 44,
                    child: Center(child: Text(label(filter), style: style)),
                  ),
              },
              onValueChanged: (filter) {
                if (filter != null) widget.onFilterChanged(filter);
              },
            ),
          );
        }
        return Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            for (final filter in PhotosFilter.values)
              if (ios)
                Semantics(
                  selected: filter == widget.filter,
                  child: CupertinoButton(
                    minimumSize: const Size(44, 48),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    color: filter == widget.filter
                        ? theme.colorScheme.surfaceContainerHigh
                        : theme.colorScheme.surface,
                    onPressed: () => widget.onFilterChanged(filter),
                    child: Text(label(filter), style: style),
                  ),
                )
              else
                ChoiceChip(
                  label: Text(label(filter)),
                  selected: widget.filter == filter,
                  showCheckmark: false,
                  onSelected: (_) => widget.onFilterChanged(filter),
                ),
          ],
        );
      },
    );
  }
}
