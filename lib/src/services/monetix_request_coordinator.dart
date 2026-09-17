import 'dart:async';
import 'dart:collection';
import 'package:flutter/foundation.dart';

/// The type of ad being requested — used for priority and spacing decisions.
enum AdRequestType {
  rewarded,
  interstitial,
  banner,
  native,
}

// Priority: lower index = higher priority.
const List<AdRequestType> _priorityOrder = [
  AdRequestType.rewarded,
  AdRequestType.interstitial,
  AdRequestType.banner,
  AdRequestType.native,
];

/// Aggregated counters for coordinator observability.
class CoordinatorMetrics {
  /// Total times [enqueue] was called.
  int requestsAttempted = 0;

  /// Requests that were suppressed because an identical-type load was
  /// already queued in the current batch.
  int requestsSuppressed = 0;

  /// Requests that were re-enqueued with a delay because the per-type
  /// spacing window had not yet elapsed.
  int requestsDelayed = 0;

  /// How many drain cycles occurred (one cycle may serve many requests).
  int drainCycles = 0;

  /// Number of times [loadFn] was actually invoked.
  int requestsExecuted = 0;

  /// Returns a structured map suitable for analytics payloads or debug UIs.
  Map<String, dynamic> toMap() {
    final total = requestsAttempted;
    final suppressed = requestsSuppressed + requestsDelayed;
    return {
      'requestsAttempted': requestsAttempted,
      'requestsSuppressed': requestsSuppressed,
      'requestsDelayed': requestsDelayed,
      'requestsExecuted': requestsExecuted,
      'drainCycles': drainCycles,
      'suppressionRate': total > 0
          ? double.parse((suppressed / total).toStringAsFixed(4))
          : 0.0,
      'executionRate': total > 0
          ? double.parse((requestsExecuted / total).toStringAsFixed(4))
          : 0.0,
    };
  }

  @override
  String toString() =>
      'CoordinatorMetrics(attempted: $requestsAttempted, '
      'suppressed: $requestsSuppressed, delayed: $requestsDelayed, '
      'executed: $requestsExecuted, drainCycles: $drainCycles, '
      'suppressionRate: ${toMap()['suppressionRate']})';
}

/// A lightweight global scheduler that prevents ad request bursts by
/// coordinating load timing across independent services and widgets.
///
/// Without a coordinator, a single gate change can cause every visible ad
/// widget and the interstitial service to fire requests simultaneously.
/// This class spaces those requests out, prioritises critical ad types,
/// and debounces rapid state cascades into a single drain cycle.
class MonetixRequestCoordinator {
  static const Duration _debounceWindow = Duration(milliseconds: 50);

  /// Minimum gap between two requests of the same type.
  static const Map<AdRequestType, Duration> _minSpacing = {
    AdRequestType.rewarded: Duration(seconds: 2),
    AdRequestType.interstitial: Duration(seconds: 1),
    AdRequestType.banner: Duration(milliseconds: 600),
    AdRequestType.native: Duration(milliseconds: 600),
  };

  final Map<AdRequestType, DateTime> _lastRequestTime = {};
  final Queue<_QueuedRequest> _queue = Queue();
  Timer? _drainTimer;
  bool _isDraining = false;

  /// Read-only snapshot of coordinator metrics.  Consumers can log this
  /// periodically or attach it to analytics payloads.
  final CoordinatorMetrics metrics = CoordinatorMetrics();

  /// Returns `true` if the caller should proceed with loading [type] right now.
  /// This is a synchronous check — callers that get `false` should still
  /// enqueue the request via [enqueue] so it fires when spacing allows.
  bool canRequestNow(AdRequestType type) {
    final last = _lastRequestTime[type];
    if (last == null) return true;
    return DateTime.now().difference(last) >= (_minSpacing[type] ?? Duration.zero);
  }

  /// Enqueue [loadFn] for [type].  The coordinator will invoke it once
  /// the per-type spacing window has elapsed and higher-priority requests
  /// ahead of it in the queue have been served.
  ///
  /// Multiple calls within the same microtask / frame are debounced into
  /// a single drain cycle, which naturally handles gate cascades.
  void enqueue(AdRequestType type, VoidCallback loadFn) {
    metrics.requestsAttempted++;
    _queue.add(_QueuedRequest(type, loadFn));
    _scheduleDrain();
  }

  void _scheduleDrain() {
    _drainTimer?.cancel();
    _drainTimer = Timer(_debounceWindow, _drain);
  }

  void _drain() {
    _drainTimer = null;

    if (_queue.isEmpty) return;
    if (_isDraining) {
      // A drain is already in progress; re-schedule for the next cycle.
      _scheduleDrain();
      return;
    }

    _isDraining = true;
    metrics.drainCycles++;
    try {
      // Sort by priority so higher-priority items go first.
      final sorted = _queue.toList()
        ..sort((a, b) => _priorityOrder.indexOf(a.type).compareTo(_priorityOrder.indexOf(b.type)));
      _queue.clear();

      // Deduplicate: only keep the highest-priority entry per type within
      // this batch to collapse redundant loads from gate cascades.
      final deduplicated = <AdRequestType, _QueuedRequest>{};
      for (final item in sorted) {
        if (deduplicated.containsKey(item.type)) {
          metrics.requestsSuppressed++;
        } else {
          deduplicated[item.type] = item;
        }
      }

      final now = DateTime.now();
      for (final item in deduplicated.values) {
        final last = _lastRequestTime[item.type];
        final elapsed = last == null ? null : now.difference(last);
        final spacing = _minSpacing[item.type] ?? Duration.zero;

        if (elapsed != null && elapsed < spacing) {
          // Still within cooldown — re-enqueue with the time already waited
          // so we don't accumulate unbounded delays.
          metrics.requestsDelayed++;
          final wait = spacing - elapsed;
          Timer(wait, () {
            item.loadFn();
            _lastRequestTime[item.type] = DateTime.now();
            metrics.requestsExecuted++;
          });
          _lastRequestTime[item.type] = now;
        } else {
          item.loadFn();
          _lastRequestTime[item.type] = now;
          metrics.requestsExecuted++;
        }
      }
    } finally {
      _isDraining = false;
    }

    // If more items arrived while we were draining, start the next cycle.
    if (_queue.isNotEmpty) {
      _scheduleDrain();
    }
  }

  /// Reset all timing state.  Useful for testing or when the app is backgrounded.
  void reset() {
    _drainTimer?.cancel();
    _drainTimer = null;
    _queue.clear();
    _lastRequestTime.clear();
    _isDraining = false;
  }

  void dispose() {
    reset();
  }
}

class _QueuedRequest {
  final AdRequestType type;
  final VoidCallback loadFn;

  _QueuedRequest(this.type, this.loadFn);
}
