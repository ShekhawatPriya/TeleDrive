import 'package:flutter/material.dart';
import '../../../models/drive_models.dart';
import '../../../widgets/media_thumb.dart';

class PhotoViewerFilmstrip extends StatefulWidget {
  const PhotoViewerFilmstrip({
    super.key,
    required this.files,
    required this.index,
    required this.onSelected,
    this.onScrubbingChanged,
  });
  final List<DriveFile> files;
  final int index;
  final ValueChanged<int> onSelected;
  final ValueChanged<bool>? onScrubbingChanged;
  @override
  State<PhotoViewerFilmstrip> createState() => _PhotoViewerFilmstripState();
}

class _PhotoViewerFilmstripState extends State<PhotoViewerFilmstrip> {
  bool _scrubbing = false;
  late final ScrollController _scroll = ScrollController(
    initialScrollOffset: widget.index * 44.0,
  );
  @override
  void didUpdateWidget(covariant PhotoViewerFilmstrip oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.index != widget.index && !_scrubbing)
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !_scroll.hasClients) return;
        final offset = (widget.index * 44.0).clamp(
          0.0,
          _scroll.position.maxScrollExtent,
        );
        if (MediaQuery.disableAnimationsOf(context)) {
          _scroll.jumpTo(offset);
        } else {
          _scroll.animateTo(
            offset,
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
          );
        }
      });
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 48,
    child: LayoutBuilder(
      builder: (context, constraints) => NotificationListener<ScrollNotification>(
        onNotification: (notification) {
          if (notification is ScrollStartNotification &&
              notification.dragDetails != null) {
            _scrubbing = true;
            widget.onScrubbingChanged?.call(true);
          }
          if (_scrubbing && notification is ScrollUpdateNotification) {
            final i = (notification.metrics.pixels / 44).round().clamp(
              0,
              widget.files.length - 1,
            );
            if (i != widget.index) widget.onSelected(i);
          }
          if (notification is ScrollEndNotification && _scrubbing) {
            _scrubbing = false;
            widget.onScrubbingChanged?.call(false);
          }
          return false;
        },
        child: ListView.builder(
          controller: _scroll,
          scrollDirection: Axis.horizontal,
          padding: EdgeInsets.symmetric(
            horizontal: (constraints.maxWidth - 44) / 2,
          ),
          itemExtent: 44,
          itemCount: widget.files.length,
          itemBuilder: (context, i) => Semantics(
            button: true,
            selected: i == widget.index,
            label:
                '${widget.files[i].name}, ${i + 1} of ${widget.files.length} loaded items',
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => widget.onSelected(i),
              child: Center(
                child: Container(
                  width: i == widget.index ? 34 : 24,
                  height: i == widget.index ? 36 : 30,
                  decoration: BoxDecoration(
                    border: i == widget.index
                        ? Border.all(color: Colors.white, width: 2)
                        : null,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: MediaThumb(
                    file: widget.files[i],
                    radius: 2,
                    decodeWidth: 96,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
