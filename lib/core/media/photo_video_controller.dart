import 'package:flutter/foundation.dart';

/// What the viewer's video transport shows for the current page.
@immutable
class PhotoVideoState {
  const PhotoVideoState({
    this.ready = false,
    this.playing = false,
    this.buffering = false,
    this.muted = true,
    this.filled = false,
    this.scrubbing = false,
    this.position = Duration.zero,
    this.duration = Duration.zero,
  });
  final bool ready, playing, buffering, muted, filled, scrubbing;
  final Duration position, duration;

  PhotoVideoState copyWith({
    bool? ready,
    bool? playing,
    bool? buffering,
    bool? muted,
    bool? filled,
    bool? scrubbing,
    Duration? position,
    Duration? duration,
  }) => PhotoVideoState(
    ready: ready ?? this.ready,
    playing: playing ?? this.playing,
    buffering: buffering ?? this.buffering,
    muted: muted ?? this.muted,
    filled: filled ?? this.filled,
    scrubbing: scrubbing ?? this.scrubbing,
    position: position ?? this.position,
    duration: duration ?? this.duration,
  );

  @override
  bool operator ==(Object other) =>
      other is PhotoVideoState &&
      other.ready == ready &&
      other.playing == playing &&
      other.buffering == buffering &&
      other.muted == muted &&
      other.filled == filled &&
      other.scrubbing == scrubbing &&
      other.position == position &&
      other.duration == duration;

  @override
  int get hashCode => Object.hash(
    ready,
    playing,
    buffering,
    muted,
    filled,
    scrubbing,
    position,
    duration,
  );
}

/// The playback engine behind a page: AVPlayer on iOS, video_player elsewhere.
abstract interface class PhotoVideoEngine {
  Future<void> play();
  Future<void> pause();
  Future<void> seek(Duration position, {bool exact});
  Future<void> mute(bool value);
  Future<void> fill(bool value);
}

/// Shared by a video page (which owns the engine) and the viewer's chrome
/// (which owns the transport). As in Photos there is one set of controls; the
/// player itself draws none.
class PhotoVideoController extends ValueNotifier<PhotoVideoState> {
  PhotoVideoController() : super(const PhotoVideoState());

  PhotoVideoEngine? engine;
  bool _resumeAfterScrub = false;

  /// Engine state replaces ours, except a scrub's held position.
  void report(PhotoVideoState state) {
    value = value.scrubbing
        ? state.copyWith(position: value.position, scrubbing: true)
        : state;
  }

  Future<void> play() async {
    value = value.copyWith(playing: true);
    await engine?.play();
  }

  Future<void> pause() async {
    value = value.copyWith(playing: false);
    await engine?.pause();
  }

  Future<void> togglePlay() => value.playing ? pause() : play();

  Future<void> setMuted(bool muted) async {
    value = value.copyWith(muted: muted);
    await engine?.mute(muted);
  }

  Future<void> toggleFill() async {
    final filled = !value.filled;
    value = value.copyWith(filled: filled);
    await engine?.fill(filled);
  }

  Future<void> seek(Duration position, {bool exact = true}) async {
    final max = value.duration;
    final target = position < Duration.zero
        ? Duration.zero
        : max > Duration.zero && position > max
        ? max
        : position;
    value = value.copyWith(position: target);
    await engine?.seek(target, exact: exact);
  }

  /// Scrubbing holds playback, then resumes it if it was playing.
  void beginScrub() {
    if (value.scrubbing) return;
    _resumeAfterScrub = value.playing;
    value = value.copyWith(scrubbing: true);
    if (_resumeAfterScrub) pause();
  }

  Future<void> endScrub() async {
    if (!value.scrubbing) return;
    value = value.copyWith(scrubbing: false);
    await seek(value.position);
    if (_resumeAfterScrub) await play();
  }
}
