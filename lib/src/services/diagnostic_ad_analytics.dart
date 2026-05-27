import 'dart:async';
import 'package:flutter/foundation.dart';
import '../interfaces/i_ad_analytics.dart';

/// An entry in the diagnostic timeline.
class DiagnosticLogEntry {
  final DateTime timestamp;
  final String event;
  final Map<String, dynamic>? details;

  DiagnosticLogEntry(this.event, [this.details]) : timestamp = DateTime.now();
}

/// A wrapper for [IAdAnalytics] that maintains a circular buffer of the last 50 events.
/// This allows the diagnostic UI to display a live timeline of monetization events.
class DiagnosticAdAnalytics extends ChangeNotifier implements IAdAnalytics {
  final IAdAnalytics? _delegate;
  final List<DiagnosticLogEntry> _logs = [];
  final int _maxLogs = 50;

  DiagnosticAdAnalytics([this._delegate]);

  List<DiagnosticLogEntry> get logs => List.unmodifiable(_logs);

  void _addLog(String event, [Map<String, dynamic>? details]) {
    _logs.insert(0, DiagnosticLogEntry(event, details));
    if (_logs.length > _maxLogs) {
      _logs.removeLast();
    }
    notifyListeners();
  }

  @override
  Future<void> logAdRequest({required String adType, required String adUnitId, required String screen, required String placement}) async {
    _addLog('${adType}_load_started', {'screen': screen, 'placement': placement});
    if (_delegate != null) {
      await _delegate!.logAdRequest(adType: adType, adUnitId: adUnitId, screen: screen, placement: placement);
    }
  }

  @override
  Future<void> logAdImpression({required String adType, required String adUnitId, required String screen, required String placement, int? loadDurationMs, bool isFallback = false}) async {
    _addLog('${adType}_load_success', {'screen': screen, 'placement': placement, 'isFallback': isFallback});
    if (_delegate != null) {
      await _delegate!.logAdImpression(adType: adType, adUnitId: adUnitId, screen: screen, placement: placement, loadDurationMs: loadDurationMs, isFallback: isFallback);
    }
  }

  @override
  Future<void> logAdFailure({required String adType, required String adUnitId, required String errorCode, required String screen, required String placement}) async {
    _addLog('${adType}_load_failed', {'error': errorCode, 'screen': screen, 'placement': placement});
    if (_delegate != null) {
      await _delegate!.logAdFailure(adType: adType, adUnitId: adUnitId, errorCode: errorCode, screen: screen, placement: placement);
    }
  }

  @override
  Future<void> logAdRevenue({required double value, required String currency, required String adType, required String adUnitId, required String screen, required String placement}) async {
    _addLog('revenue_earned', {'value': value, 'currency': currency, 'adType': adType});
    if (_delegate != null) {
      await _delegate!.logAdRevenue(value: value, currency: currency, adType: adType, adUnitId: adUnitId, screen: screen, placement: placement);
    }
  }

  @override
  Future<void> logAdRewardEarned({required String adType, required String screen, required String placement}) async {
    _addLog('reward_earned', {'adType': adType, 'screen': screen, 'placement': placement});
    if (_delegate != null) {
      await _delegate!.logAdRewardEarned(adType: adType, screen: screen, placement: placement);
    }
  }

  @override
  void startPostAdWindow(String adType) {
    _addLog('${adType}_dismissed');
    if (_delegate != null) {
      _delegate!.startPostAdWindow(adType);
    }
  }
}
