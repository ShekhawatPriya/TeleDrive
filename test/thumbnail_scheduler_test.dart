import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_m_fsdk/core/media/thumbnail_scheduler.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> flush() => Future<void>.delayed(Duration.zero);

void main() {
  test(
    'visible requests overtake queued prefetch and share duplicate work',
    () async {
      final scheduler = ThumbnailScheduler<String>(concurrency: 2);
      addTearDown(scheduler.dispose);
      final started = <String>[];
      final completions = <String, Completer<String?>>{};
      ThumbnailRequest<String> request(
        String key,
        ThumbnailPriority priority,
      ) => scheduler.request(
        key,
        priority: priority,
        load: (_) {
          started.add(key);
          return (completions[key] = Completer<String?>()).future;
        },
      );
      final nearby = request('nearby', ThumbnailPriority.nearby);
      final promoted = request('promoted', ThumbnailPriority.nearby);
      final cover = request('visible', ThumbnailPriority.visible);
      final tile = request('visible', ThumbnailPriority.visible);
      await flush();
      expect(started, ['visible', 'nearby']);
      expect(identical(cover.future, tile.future), isTrue);
      promoted.updatePriority(ThumbnailPriority.visible);
      final abandoned = request('abandoned', ThumbnailPriority.visible);
      abandoned.release();
      expect(await abandoned.future, isNull);
      cover.release(); // The other consumer still needs the same image.
      completions['visible']!.complete('image');
      expect(await tile.future, 'image');
      await flush();
      expect(started, ['visible', 'nearby', 'promoted']);
      completions['nearby']!.complete('nearby');
      completions['promoted']!.complete('promoted');
      await Future.wait([nearby.future, promoted.future]);
    },
  );

  test(
    'prefetch reserves capacity and original fallback has a separate limit',
    () async {
      final scheduler = ThumbnailScheduler<String>();
      addTearDown(scheduler.dispose);
      final started = <String>[];
      final pending = <Completer<String?>>[];
      void request(
        String key,
        ThumbnailPriority priority, {
        bool original = false,
      }) {
        scheduler.request(
          key,
          priority: priority,
          original: original,
          load: (_) {
            started.add(key);
            final completion = Completer<String?>();
            pending.add(completion);
            return completion.future;
          },
        );
      }

      for (var i = 0; i < 30; i++) {
        request('nearby-$i', ThumbnailPriority.nearby);
      }
      await flush();
      expect(started, ['nearby-0']);
      request('original-1', ThumbnailPriority.visible, original: true);
      request('original-2', ThumbnailPriority.visible, original: true);
      request('visible-1', ThumbnailPriority.visible);
      request('visible-2', ThumbnailPriority.visible);
      await flush();
      expect(started, containsAll(['original-1', 'visible-1', 'visible-2']));
      expect(started, isNot(contains('original-2')));
      expect(started, hasLength(4));
      scheduler.dispose();
      for (final completion in pending) {
        completion.complete(null);
      }
      await flush();
    },
  );

  test(
    'only last consumer cancels; disposed jobs cannot revive the queue',
    () async {
      final scheduler = ThumbnailScheduler<String>(concurrency: 1);
      CancelToken? token;
      final pending = Completer<String?>();
      final first = scheduler.request(
        'same',
        priority: ThumbnailPriority.visible,
        load: (value) {
          token = value;
          return pending.future;
        },
      );
      final second = scheduler.request(
        'same',
        priority: ThumbnailPriority.visible,
        load: (_) => throw StateError('duplicate'),
      );
      await flush();
      first.release();
      expect(token!.isCancelled, isFalse);
      second.release();
      expect(token!.isCancelled, isTrue);
      var nextStarted = false;
      final next = scheduler.request(
        'next',
        priority: ThumbnailPriority.visible,
        load: (_) async {
          nextStarted = true;
          return 'next';
        },
      );
      scheduler.dispose();
      pending.complete('stale');
      expect(await first.future, isNull);
      expect(await next.future, isNull);
      await flush();
      expect(nextStarted, isFalse);
    },
  );

  test('new visible demand cancels an in-flight nearby request', () async {
    final scheduler = ThumbnailScheduler<String>(concurrency: 2);
    addTearDown(scheduler.dispose);
    final visibleGate = Completer<String?>();
    final visible = scheduler.request(
      'visible',
      priority: ThumbnailPriority.visible,
      load: (_) => visibleGate.future,
    );
    CancelToken? nearbyToken;
    final nearby = scheduler.request(
      'nearby',
      priority: ThumbnailPriority.nearby,
      load: (token) async {
        nearbyToken = token;
        await token.whenCancel;
        return null;
      },
    );
    await flush();
    final newVisible = scheduler.request(
      'new',
      priority: ThumbnailPriority.visible,
      load: (_) async => 'new viewport',
    );
    expect(await newVisible.future, 'new viewport');
    expect(nearbyToken!.isCancelled, isTrue);
    expect(await nearby.future, isNull);
    visibleGate.complete('old visible');
    await visible.future;
  });

  test('a failed request frees its slot and can be retried', () async {
    final scheduler = ThumbnailScheduler<String>(concurrency: 1);
    addTearDown(scheduler.dispose);
    final first = scheduler.request(
      'same',
      priority: ThumbnailPriority.visible,
      load: (_) async => throw StateError('temporary'),
    );
    expect(await first.future, isNull);
    final second = scheduler.request(
      'same',
      priority: ThumbnailPriority.visible,
      load: (_) async => 'recovered',
    );
    expect(await second.future, 'recovered');
  });
}
