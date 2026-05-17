import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../interfaces/i_ad_analytics.dart';
import '../interfaces/i_ad_config_provider.dart';
import '../interfaces/i_ad_status_provider.dart';
import 'monetization_service.dart';
import 'monetization_gate.dart';

enum RewardBlockReason {
  alreadyShowing,
  rateLimited,
  cooldown,
}

class RewardedMonetizationService extends ChangeNotifier {
  static const String _prefExpiry = 'rewarded_ad_expiry_ms';
  static const String _prefWatchTimes = 'rewarded_ad_watch_times';
  static const String _prefHwm = 'rewarded_hwm';

  Duration get _rewardPerAd => _configProvider.rewardAdFreeDuration;
  Duration get _rateLimitWindow => _configProvider.rateLimitWindowDuration;
  Duration get _cooldownBetweenAds => _configProvider.cooldownBetweenAdsDuration;
  int get _maxAdsPerWindow => _configProvider.maxAdsPerRateLimitWindow;

  final IAdConfigProvider _configProvider;
  final MonetizationService? _monetizationService;
  final IAdAnalytics? _analyticsService;
  final IAdStatusProvider? _statusProvider;
  MonetizationGate? gate;
  
  RewardedAd? _rewardedAd;
  bool _isLoading = false;
  bool _isShowing = false;
  bool _hasLoggedImpression = false;
  int? _lastLoadDurationMs;
  Timer? _expiryTimer;
  final Completer<void> _initCompleter = Completer<void>();
  Future<void> get initialized => _initCompleter.future;

  int _highWaterMarkMs = 0;
  DateTime? _lastManualLoadTime;

  final bool _autoLoad;
  final DateTime Function() _nowProvider;

  RewardedMonetizationService(
    this._configProvider, {
    MonetizationService? monetizationService,
    IAdStatusProvider? statusProvider,
    IAdAnalytics? analyticsService,
    bool autoLoad = true,
    DateTime Function()? nowProvider,
  })  : _monetizationService = monetizationService,
        _statusProvider = statusProvider,
        _analyticsService = analyticsService,
        _autoLoad = autoLoad,
        _nowProvider = nowProvider ?? (() => DateTime.now()) {
    _init();
    _configProvider.addListener(_onConfigChanged);
  }

  void _onConfigChanged() {
    final allowed = gate != null
        ? gate!.evaluateRewarded().allowed
        : (_configProvider.adsEnabled && _configProvider.enableRewardedBreak && _statusProvider?.isPremium != true);

    if (!allowed) {
      if (_rewardedAd != null) {
        _rewardedAd!.dispose();
        _rewardedAd = null;
      }
      _isLoading = false;
      notifyListeners();
    } else {
      if (_autoLoad && _rewardedAd == null) {
        loadRewardedAd();
      }
    }
  }

  void _scheduleExpiryNotify() {
    _expiryTimer?.cancel();
    final remaining = remainingTime;
    if (remaining != null) {
      _expiryTimer = Timer(remaining + const Duration(milliseconds: 100), () {
        notifyListeners();
      });
    }
  }

  bool get isAdFree {
    final expiry = _cachedExpiryMs;
    if (expiry == null) return false;
    final now = _safeNowMs();
    return now < expiry;
  }

  Duration? get remainingTime {
    final expiry = _cachedExpiryMs;
    if (expiry == null) return null;
    final now = _safeNowMs();
    final remaining = expiry - now;
    if (remaining <= 0) return null;
    return Duration(milliseconds: remaining);
  }

  int get adsWatchedThisHour {
    final now = _safeNowMs();
    final cutoff = now - _rateLimitWindow.inMilliseconds;
    return _cachedWatchTimes.where((t) => t >= cutoff).length;
  }

  bool get canWatchAd {
    final allowed = gate != null
        ? gate!.evaluateRewarded().allowed
        : (_configProvider.adsEnabled && _configProvider.enableRewardedBreak && _statusProvider?.isPremium != true);

    if (!allowed) return false;

    if (_isShowing) return false;
    final now = _safeNowMs();
    final cutoff = now - _rateLimitWindow.inMilliseconds;
    final recent = _cachedWatchTimes.where((t) => t >= cutoff).toList()..sort();

    if (recent.length >= _maxAdsPerWindow) return false;
    if (recent.isNotEmpty) {
      final lastWatch = recent.last;
      if (now - lastWatch < _cooldownBetweenAds.inMilliseconds) return false;
    }
    return true;
  }

  RewardBlockReason? get blockReason {
    if (_isShowing) return RewardBlockReason.alreadyShowing;
    final now = _safeNowMs();
    final cutoff = now - _rateLimitWindow.inMilliseconds;
    final recent = _cachedWatchTimes.where((t) => t >= cutoff).toList()..sort();

    if (recent.length >= _maxAdsPerWindow) return RewardBlockReason.rateLimited;
    if (recent.isNotEmpty) {
      final lastWatch = recent.last;
      if (now - lastWatch < _cooldownBetweenAds.inMilliseconds) return RewardBlockReason.cooldown;
    }
    return null;
  }

  bool get isAdReady => _rewardedAd != null && !_isLoading;
  bool get isLoading => _isLoading;

  Future<void> _init() async {
    // Premium users: skip all ad initialization entirely.
    if (_statusProvider?.isPremium == true) {
      if (!_initCompleter.isCompleted) _initCompleter.complete();
      return;
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      _highWaterMarkMs = prefs.getInt(_prefHwm) ?? 0;
      _cachedExpiryMs = prefs.getInt(_prefExpiry);
      _cachedWatchTimes = _decodeWatchTimes(prefs.getString(_prefWatchTimes));
      

      _scheduleExpiryNotify();
      notifyListeners();
      if (_autoLoad) {
        await loadRewardedAd();
      }
    } catch (e) {
      debugPrint('⚠️ Monetix: Error during RewardedMonetizationService init (likely unsupported platform): $e');
    } finally {
      if (!_initCompleter.isCompleted) _initCompleter.complete();
    }
  }

  Future<void> loadRewardedAd({bool isManual = false}) async {
    final allowed = gate != null
        ? gate!.evaluateRewarded().allowed
        : (_configProvider.adsEnabled && _configProvider.enableRewardedBreak && _statusProvider?.isPremium != true);

    if (!allowed) {
      if (_rewardedAd != null) {
        _rewardedAd!.dispose();
        _rewardedAd = null;
      }
      return;
    }

    if (_isLoading || _rewardedAd != null) return;
    
    if (isManual) {
      if (_lastManualLoadTime != null && _nowProvider().difference(_lastManualLoadTime!) < const Duration(seconds: 30)) {
        return;
      }
      _lastManualLoadTime = _nowProvider();
    }

    final connectivityResult = await Connectivity().checkConnectivity();
    if (connectivityResult.every((r) => r == ConnectivityResult.none)) {
      return;
    }

    _isLoading = true;
    notifyListeners();

    if (_monetizationService != null) {
      await _monetizationService.initialized;
    }

    final adUnitId = _adUnitId;
    _analyticsService?.logAdRequest(
      adType: 'rewarded',
      adUnitId: adUnitId,
      screen: 'rewarded_screen',
      placement: 'rewarded_break',
    );

    final startTime = _nowProvider();
    await RewardedAd.load(
      adUnitId: adUnitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
      onAdLoaded: (ad) {
        _lastLoadDurationMs = _nowProvider().difference(startTime).inMilliseconds;
        _rewardedAd = ad;
        _isLoading = false;
        notifyListeners();
      },
        onAdFailedToLoad: (error) {
          _analyticsService?.logAdFailure(
            adType: 'rewarded',
            adUnitId: adUnitId,
            errorCode: error.code.toString(),
            screen: 'rewarded_screen',
            placement: 'rewarded_break',
          );
          _rewardedAd = null;
          _isLoading = false;
          notifyListeners();
        },
      ),
    );
  }

  Future<void> showRewardedAd({
    required VoidCallback onRewarded,
    VoidCallback? onFailed,
  }) async {
    final allowed = gate != null
        ? gate!.evaluateRewarded().allowed
        : (_configProvider.adsEnabled && _configProvider.enableRewardedBreak && _statusProvider?.isPremium != true);

    if (!allowed) {
      onFailed?.call();
      return;
    }

    if (!canWatchAd) {
      onFailed?.call();
      return;
    }

    if (_rewardedAd == null) {
      onFailed?.call();
      loadRewardedAd(isManual: true);
      return;
    }

    _isShowing = true;
    notifyListeners();

    _rewardedAd!.fullScreenContentCallback = FullScreenContentCallback(
      onAdImpression: (ad) {
        if (!_hasLoggedImpression && _analyticsService != null) {
          _analyticsService.logAdImpression(
            adType: 'rewarded',
            adUnitId: ad.adUnitId,
            screen: 'rewarded_screen',
            placement: 'rewarded_break',
            loadDurationMs: _lastLoadDurationMs,
          );
          _hasLoggedImpression = true;
        }
      },
      onAdDismissedFullScreenContent: (ad) {
        _analyticsService?.startPostAdWindow('rewarded');
        _rewardedAd = null;
        _isShowing = false;
        _hasLoggedImpression = false;
        notifyListeners();
        loadRewardedAd();
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        _analyticsService?.logAdFailure(
          adType: 'rewarded',
          adUnitId: ad.adUnitId,
          errorCode: 'show_fail_${error.code}',
          screen: 'rewarded_screen',
          placement: 'rewarded_break',
        );
        ad.dispose();
        _rewardedAd = null;
        _isShowing = false;
        _hasLoggedImpression = false;
        notifyListeners();
        onFailed?.call();
      },
    );

    _rewardedAd!.onPaidEvent = (Ad ad, double valueMicros, PrecisionType precision, String currencyCode) {
      _analyticsService?.logAdRevenue(
        value: valueMicros / 1000000.0,
        currency: currencyCode,
        adType: 'rewarded',
        adUnitId: ad.adUnitId,
        screen: 'rewarded_screen',
        placement: 'rewarded_break',
      );
    };

    await _rewardedAd!.show(
      onUserEarnedReward: (ad, reward) {
        _analyticsService?.logAdRewardEarned(
          adType: 'rewarded',
          screen: 'rewarded_screen',
          placement: 'rewarded_break',
        );
        _grantAdFreeTime();
        onRewarded();
      },
    );
  }

  Future<void> _grantAdFreeTime() async {
    final now = _safeNowMs();
    await _recordWatch(now);

    final existingExpiry = _cachedExpiryMs ?? now;
    final baseMs = existingExpiry > now ? existingExpiry : now;
    final maxExpiry = now + (_rewardPerAd.inMilliseconds * _maxAdsPerWindow);
    final newExpiry = (baseMs + _rewardPerAd.inMilliseconds).clamp(0, maxExpiry);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_prefExpiry, newExpiry);
    _cachedExpiryMs = newExpiry;
    _scheduleExpiryNotify();
    notifyListeners();
  }

  int? _cachedExpiryMs;
  List<int> _cachedWatchTimes = [];

  Future<void> _recordWatch(int nowMs) async {
    final prefs = await SharedPreferences.getInstance();
    final times = _decodeWatchTimes(prefs.getString(_prefWatchTimes));
    final cutoff = nowMs - _rateLimitWindow.inMilliseconds;
    times.removeWhere((t) => t < cutoff);
    times.add(nowMs);
    await prefs.setString(_prefWatchTimes, times.join(','));
    _cachedWatchTimes = List.from(times);
    if (nowMs > _highWaterMarkMs) {
      _highWaterMarkMs = nowMs;
      await prefs.setInt(_prefHwm, _highWaterMarkMs);
    }
  }

  List<int> _decodeWatchTimes(String? raw) {
    if (raw == null || raw.isEmpty) return [];
    return raw.split(',').map((s) => int.tryParse(s)).whereType<int>().toList();
  }

  int _safeNowMs() {
    final real = _nowProvider().millisecondsSinceEpoch;
    if (real > _highWaterMarkMs) {
      _highWaterMarkMs = real;
      SharedPreferences.getInstance().then((p) => p.setInt(_prefHwm, _highWaterMarkMs));
    }
    return real < _highWaterMarkMs ? _highWaterMarkMs : real;
  }

  String get _testRewardedAdUnitId => 'ca-app-pub-3940256099942544/5224354917';
  String get _adUnitId {
    if (kDebugMode) return _testRewardedAdUnitId;
    return _configProvider.rewardedAdUnitId ?? _testRewardedAdUnitId;
  }

  @override
  void dispose() {
    _configProvider.removeListener(_onConfigChanged);
    _expiryTimer?.cancel();
    _rewardedAd?.dispose();
    super.dispose();
  }
}
