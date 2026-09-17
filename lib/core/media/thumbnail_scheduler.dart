import 'dart:async';

import 'package:dio/dio.dart';

enum ThumbnailPriority { visible, nearby }

/// Shared admission control. Nearby work can occupy only one slot; original
/// fallback can occupy only one slot and is never prefetched.
class ThumbnailScheduler<T> {
  ThumbnailScheduler({this.concurrency = 4});
  final int concurrency;
  final Map<String, _Job<T>> _jobs = {};
  final Set<_Job<T>> _running = {};
  bool _scheduled = false;
  bool _disposed = false;

  ThumbnailRequest<T> request(
    String key, {
    required ThumbnailPriority priority,
    required Future<T?> Function(CancelToken token) load,
    bool original = false,
  }) {
    final existing = _jobs[key];
    final job = existing != null && !existing.token.isCancelled
        ? existing
        : _Job<T>(key, load, original);
    if (_disposed) {
      job.result.complete(null);
    } else {
      _jobs[key] = job;
    }
    final request = ThumbnailRequest<T>._(this, job, priority);
    job.consumers.add(request);
    _schedule();
    return request;
  }

  void _schedule() {
    if (_scheduled || _disposed) return;
    _scheduled = true;
    // Collect all visibility changes from this frame before choosing work.
    scheduleMicrotask(() {
      _scheduled = false;
      _drain();
    });
  }

  void _drain() {
    if (_disposed) return;
    final pending =
        _jobs.values
            .where((job) => !_running.contains(job) && job.consumers.isNotEmpty)
            .toList()
          ..sort((a, b) {
            final priority = a.priority.index.compareTo(b.priority.index);
            return priority != 0
                ? priority
                : (a.original ? 1 : 0).compareTo(b.original ? 1 : 0);
          });
    var needed =
        pending
            .where(
              (job) =>
                  job.priority == ThumbnailPriority.visible &&
                  (!job.original ||
                      !_running.any((running) => running.original)),
            )
            .length -
        (concurrency - _running.length);
    // A previously visible tile can become nearby while its request is in
    // flight. Reclaim those slots when the new viewport needs them.
    for (final job in _running) {
      if (needed <= 0) break;
      if (job.priority == ThumbnailPriority.nearby && !job.token.isCancelled) {
        job.token.cancel('Visible thumbnails take priority');
        needed--;
      }
    }
    for (final job in pending) {
      if (_running.length >= concurrency) break;
      if (job.original &&
          (job.priority != ThumbnailPriority.visible ||
              _running.any((running) => running.original)))
        continue;
      if (job.priority == ThumbnailPriority.nearby &&
          (concurrency <= 1 ||
              _running.any(
                (running) => running.priority == ThumbnailPriority.nearby,
              )))
        continue;
      _running.add(job);
      unawaited(_run(job));
    }
  }

  Future<void> _run(_Job<T> job) async {
    try {
      final value = await job.load(job.token);
      job.result.complete(job.token.isCancelled ? null : value);
    } catch (_) {
      job.result.complete(null);
    } finally {
      _running.remove(job);
      if (identical(_jobs[job.key], job)) _jobs.remove(job.key);
      _schedule();
    }
  }

  void _release(ThumbnailRequest<T> request) {
    final job = request._job;
    job.consumers.remove(request);
    if (job.consumers.isEmpty) {
      job.token.cancel('Thumbnail no longer needed');
      if (identical(_jobs[job.key], job)) _jobs.remove(job.key);
      if (!_running.contains(job) && !job.result.isCompleted) {
        job.result.complete(null);
      }
    }
    _schedule();
  }

  void dispose() {
    _disposed = true;
    for (final job in {..._jobs.values, ..._running}) {
      job.token.cancel('Thumbnail scope disposed');
      if (!_running.contains(job) && !job.result.isCompleted) {
        job.result.complete(null);
      }
    }
    _jobs.clear();
  }
}

class ThumbnailRequest<T> {
  ThumbnailRequest._(this._scheduler, this._job, this._priority);
  final ThumbnailScheduler<T> _scheduler;
  final _Job<T> _job;
  ThumbnailPriority _priority;
  bool _released = false;
  Future<T?> get future => _job.result.future;
  bool get isCancelled => _job.token.isCancelled;

  void updatePriority(ThumbnailPriority priority) {
    if (_released || _priority == priority) return;
    _priority = priority;
    _scheduler._schedule();
  }

  void release() {
    if (_released) return;
    _released = true;
    _scheduler._release(this);
  }
}

class _Job<T> {
  _Job(this.key, this.load, this.original);
  final String key;
  final Future<T?> Function(CancelToken) load;
  final bool original;
  final token = CancelToken();
  final result = Completer<T?>();
  final consumers = <ThumbnailRequest<T>>{};
  ThumbnailPriority get priority =>
      consumers.any((request) => request._priority == ThumbnailPriority.visible)
      ? ThumbnailPriority.visible
      : ThumbnailPriority.nearby;
}
