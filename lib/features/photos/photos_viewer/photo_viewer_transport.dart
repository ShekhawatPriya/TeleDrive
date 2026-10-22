import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../../core/media/photo_video_controller.dart';
import '../../../core/utils/file_type_detector.dart';
import '../../../widgets/native_glass_surface.dart';

/// The Photos video bar above the thumbnail strip: play/pause, a scrubber and
/// mute in one capsule. It is part of the viewer's chrome, so it hides and
/// shows with the toolbar and title on a single tap. Disabled until the
/// current video is ready.
class PhotoVideoTransport extends StatelessWidget {
  const PhotoVideoTransport({
    required this.controller,
    required this.dark,
    super.key,
  });

  /// The current page's controller; null while the page has not attached.
  final PhotoVideoController? controller;

  /// Dark chrome (white content) or light chrome over the white backdrop.
  final bool dark;

  @override
  Widget build(BuildContext context) {
    final controller = this.controller;
    if (controller == null) return _bar(context, null, const PhotoVideoState());
    return ValueListenableBuilder<PhotoVideoState>(
      valueListenable: controller,
      builder: (context, state, _) => _bar(context, controller, state),
    );
  }

  Widget _bar(
    BuildContext context,
    PhotoVideoController? controller,
    PhotoVideoState state,
  ) {
    final ios = Theme.of(context).platform == TargetPlatform.iOS;
    final content = dark ? Colors.white : Colors.black;
    final enabled = controller != null && state.ready;
    Widget button({
      required String label,
      required IconData icon,
      required VoidCallback? onPressed,
    }) => IconButton(
      tooltip: label,
      onPressed: onPressed,
      constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
      padding: EdgeInsets.zero,
      icon: Icon(
        icon,
        size: ios ? 22 : 24,
        color: content.withValues(alpha: onPressed == null ? .35 : 1),
      ),
    );
    final row = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      child: Row(
        children: [
          button(
            label: state.playing ? 'Pause' : 'Play',
            icon: state.playing
                ? (ios ? CupertinoIcons.pause_fill : Icons.pause_rounded)
                : (ios ? CupertinoIcons.play_fill : Icons.play_arrow_rounded),
            onPressed: enabled ? controller.togglePlay : null,
          ),
          Expanded(
            child: _Scrubber(
              controller: enabled ? controller : null,
              state: state,
              color: content,
            ),
          ),
          button(
            label: state.muted ? 'Unmute' : 'Mute',
            icon: state.muted
                ? (ios
                      ? CupertinoIcons.speaker_slash_fill
                      : Icons.volume_off_rounded)
                : (ios
                      ? CupertinoIcons.speaker_2_fill
                      : Icons.volume_up_rounded),
            onPressed: controller == null
                ? null
                : () => controller.setMuted(!state.muted),
          ),
        ],
      ),
    );
    final capsule = Padding(
      padding: EdgeInsets.symmetric(horizontal: ios ? 28 : 16, vertical: 4),
      child: ios
          ? NativeGlassSurface(dark: dark, child: row)
          : Material(
              color: Colors.black.withValues(alpha: .6),
              shape: const StadiumBorder(),
              child: row,
            ),
    );
    return Column(
      key: const ValueKey('photo-video-transport'),
      mainAxisSize: MainAxisSize.min,
      children: [
        // Times appear only while scrubbing; the bar itself stays as calm as
        // Photos'. Growing upward keeps the capsule under the finger.
        if (state.scrubbing)
          ExcludeSemantics(
            child: Text(
              '${formatDuration(state.position.inSeconds)} / '
              '${formatDuration(state.duration.inSeconds)}',
              style: TextStyle(
                color: content.withValues(alpha: .85),
                fontSize: 13,
                fontWeight: FontWeight.w600,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
        capsule,
      ],
    );
  }
}

/// A thin track that follows the finger relative to where the drag began,
/// as in Photos, and thickens while held.
class _Scrubber extends StatefulWidget {
  const _Scrubber({
    required this.controller,
    required this.state,
    required this.color,
  });
  final PhotoVideoController? controller;
  final PhotoVideoState state;
  final Color color;

  @override
  State<_Scrubber> createState() => _ScrubberState();
}

class _ScrubberState extends State<_Scrubber> {
  bool _held = false;
  double _startX = 0;
  Duration _startPosition = Duration.zero;

  double get _fraction {
    final total = widget.state.duration.inMilliseconds;
    if (total <= 0) return 0;
    return (widget.state.position.inMilliseconds / total).clamp(0.0, 1.0);
  }

  void _start(DragStartDetails details) {
    final controller = widget.controller;
    if (controller == null) return;
    setState(() => _held = true);
    _startX = details.localPosition.dx;
    _startPosition = widget.state.position;
    controller.beginScrub();
  }

  void _update(DragUpdateDetails details, double width) {
    final controller = widget.controller;
    if (controller == null || !_held || width <= 0) return;
    final total = widget.state.duration.inMilliseconds;
    final delta = (details.localPosition.dx - _startX) / width * total;
    controller.seek(
      _startPosition + Duration(milliseconds: delta.round()),
      exact: false,
    );
  }

  void _end() {
    if (!_held) return;
    setState(() => _held = false);
    widget.controller?.endScrub();
  }

  void _step(int seconds) {
    final controller = widget.controller;
    if (controller == null) return;
    controller.seek(widget.state.position + Duration(seconds: seconds));
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    final position = formatDuration(state.position.inSeconds);
    final total = formatDuration(state.duration.inSeconds);
    return Semantics(
      slider: true,
      enabled: widget.controller != null,
      label: 'Playback position',
      value: '$position of $total',
      increasedValue: formatDuration(
        (state.position + const Duration(seconds: 10)).inSeconds.clamp(
          0,
          state.duration.inSeconds,
        ),
      ),
      decreasedValue: formatDuration(
        (state.position - const Duration(seconds: 10)).inSeconds.clamp(
          0,
          state.duration.inSeconds,
        ),
      ),
      onIncrease: widget.controller == null ? null : () => _step(10),
      onDecrease: widget.controller == null ? null : () => _step(-10),
      excludeSemantics: true,
      child: Row(
        children: [
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) => GestureDetector(
                key: const ValueKey('photo-video-scrubber'),
                behavior: HitTestBehavior.opaque,
                onHorizontalDragStart: _start,
                onHorizontalDragUpdate: (details) =>
                    _update(details, constraints.maxWidth),
                onHorizontalDragEnd: (_) => _end(),
                onHorizontalDragCancel: _end,
                child: SizedBox(
                  height: 44,
                  child: Center(
                    child: AnimatedContainer(
                      duration: MediaQuery.disableAnimationsOf(context)
                          ? Duration.zero
                          : const Duration(milliseconds: 120),
                      height: _held ? 8 : 4,
                      decoration: BoxDecoration(
                        color: widget.color.withValues(alpha: .3),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      alignment: Alignment.centerLeft,
                      child: FractionallySizedBox(
                        widthFactor: _fraction,
                        heightFactor: 1,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: widget.color.withValues(
                              alpha: widget.controller == null ? .35 : 1,
                            ),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
