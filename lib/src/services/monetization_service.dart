import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../interfaces/i_ad_analytics.dart';
import '../interfaces/i_ad_config_provider.dart';
import '../interfaces/i_ad_status_provider.dart';
import 'rewarded_monetization_service.dart';

class MonetizationService {
  final IAdConfigProvider _configProvider;
  final IAdStatusProvider? _statusProvider;
  final IAdAnalytics? _analyticsService;
  RewardedMonetizationService? rewardedAdService;
  
  InterstitialAd? _interstitialAd;
  bool isInitialized = false;
  final Completer<void> _initCompleter = Completer<void>();
  Future<void> get initialized => _initCompleter.future;
  
  bool _isLoading = false;
  bool _isPremium = false;
  StreamSubscription<bool>? _premiumSubscription;
  int _loadAttempts = 0;
  static const int _maxAttempts = 3;

  String? _currentScreen;
  String? _currentPlacement;
  bool _hasLoggedImpression = false;
  DateTime? _loadStartTime;
  int? _lastLoadDurationMs;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;

  MonetizationService(
    this._configProvider, {
    IAdStatusProvider? statusProvider,
    IAdAnalytics? analyticsService,
    this.rewardedAdService,
  })  : _statusProvider = statusProvider,
        _analyticsService = analyticsService;

  bool get isAdFree => _isPremium || (rewardedAdService?.isAdFree ?? false);
  bool shouldShowInterstitial() => !isAdFree;

  Future<void>? _initFuture;

  Future<void> init() async {
    if (kIsWeb) {
      isInitialized = true;
      if (!_initCompleter.isCompleted) _initCompleter.complete();
      return;
    }

    if (isInitialized) return;
    if (_initFuture != null) return _initFuture;

    _connectivitySubscription ??= Connectivity().onConnectivityChanged.listen((results) {
      final isOnline = results.any((r) => r != ConnectivityResult.none);
      if (isOnline && !isInitialized && _initFuture == null) {
        init();
      }
    });

    _initFuture = _initInternal();
    return _initFuture;
  }

  Future<void> _initInternal() async {
    try {
      // Basic connectivity check
      final connectivityResult = await Connectivity().checkConnectivity();
      if (connectivityResult.every((r) => r == ConnectivityResult.none)) {
        isInitialized = false;
        _initFuture = null;
        return;
      }

      _isPremium = _statusProvider?.isPremium ?? false;

      if (isAdFree) {
        isInitialized = true;
        _listenForPremiumChanges();
        return;
      }

      try {
        await _handleConsent();
      } catch (e) {
        debugPrint('[MonetizationService] UMP flow failed: $e');
      }

      final canAds = await ConsentInformation.instance.canRequestAds();
      debugPrint('[MonetizationService] canRequestAds: $canAds');

      final requestConfig = RequestConfiguration(testDeviceIds: _configProvider.testDeviceIds);
      await MobileAds.instance.updateRequestConfiguration(requestConfig);

      const initTimeout = kDebugMode ? Duration(seconds: 15) : Duration(seconds: 8);
      await MobileAds.instance.initialize().timeout(
        initTimeout,
        onTimeout: () {
          debugPrint('[MonetizationService] MobileAds initialize timed out');
          return Future.value(InitializationStatus({}));
        },
      );

      isInitialized = true;
      _listenForPremiumChanges();

      if (!isAdFree) {
        loadInterstitialAd();
      }
    } catch (e, st) {
      debugPrint('[MonetizationService] initialize error: $e\n$st');
      isInitialized = false;
    } finally {
      if (!_initCompleter.isCompleted) {
        _initCompleter.complete();
      }
    }
  }

  void _listenForPremiumChanges() {
    if (_statusProvider != null && _premiumSubscription == null) {
      _premiumSubscription = _statusProvider.premiumStatusStream.listen((isPremium) {
        _isPremium = isPremium;
        
        if (isAdFree) {
          if (_interstitialAd != null) {
            _interstitialAd!.dispose();
            _interstitialAd = null;
          }
          _isLoading = false;
        } else {
          if (isInitialized) {
            loadInterstitialAd();
          } else {
            init();
          }
        }
      });
    }
  }

  String get _testInterstitialId => 'ca-app-pub-3940256099942544/1033173712';

  String? get interstitialAdUnitId {
    if (kDebugMode) return _testInterstitialId;
    return _configProvider.interstitialAdUnitId;
  }

  Future<void> loadInterstitialAd() async {
    if (!isInitialized || isAdFree || _isLoading) return;

    final adUnitId = interstitialAdUnitId ?? _testInterstitialId;
    _isLoading = true;
    _loadAttempts += 1;

    _loadStartTime = DateTime.now();
    _analyticsService?.logAdRequest(
      adType: 'interstitial',
      adUnitId: adUnitId,
      screen: _currentScreen ?? 'background_preload',
      placement: _currentPlacement ?? 'background_preload',
    );

    try {
      InterstitialAd.load(
        adUnitId: adUnitId,
        request: const AdRequest(),
        adLoadCallback: InterstitialAdLoadCallback(
          onAdLoaded: (InterstitialAd ad) {
            if (_loadStartTime != null) {
              _lastLoadDurationMs = DateTime.now().difference(_loadStartTime!).inMilliseconds;
            }
            _interstitialAd = ad;
            _isLoading = false;
            _loadAttempts = 0;
            _attachFullScreenCallbacks(ad);
          },
          onAdFailedToLoad: (LoadAdError error) {
            _isLoading = false;
            _interstitialAd = null;
            _analyticsService?.logAdFailure(
              adType: 'interstitial',
              adUnitId: adUnitId,
              errorCode: error.message,
              screen: _currentScreen ?? 'background_preload',
              placement: _currentPlacement ?? 'background_preload',
            );

            if (_loadAttempts < _maxAttempts) {
              Future.delayed(const Duration(seconds: 5), loadInterstitialAd);
            }
          },
        ),
      );
    } catch (e) {
      debugPrint('⚠️ Monetix: InterstitialAd not supported on this platform: $e');
      _isLoading = false;
    }
  }

  void _attachFullScreenCallbacks(InterstitialAd ad) {
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdImpression: (ad) {
        if (!_hasLoggedImpression && _analyticsService != null) {
          _analyticsService.logAdImpression(
            adType: 'interstitial',
            adUnitId: ad.adUnitId,
            screen: _currentScreen ?? 'unknown',
            placement: _currentPlacement ?? 'unknown',
            loadDurationMs: _lastLoadDurationMs,
          );
          _hasLoggedImpression = true;
        }
      },
      onAdDismissedFullScreenContent: (ad) {
        _analyticsService?.startPostAdWindow('interstitial');
        ad.dispose();
        if (_interstitialAd == ad) _interstitialAd = null;
        _hasLoggedImpression = false;
        loadInterstitialAd();
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        _analyticsService?.logAdFailure(
          adType: 'interstitial',
          adUnitId: ad.adUnitId,
          errorCode: 'show_fail_${error.code}',
          screen: _currentScreen ?? 'unknown',
          placement: _currentPlacement ?? 'unknown',
        );
        ad.dispose();
        if (_interstitialAd == ad) _interstitialAd = null;
        _hasLoggedImpression = false;
        loadInterstitialAd();
      },
    );

    ad.onPaidEvent = (Ad ad, double valueMicros, PrecisionType precision, String currencyCode) {
      _analyticsService?.logAdRevenue(
        value: valueMicros / 1000000.0,
        currency: currencyCode,
        adType: 'interstitial',
        adUnitId: ad.adUnitId,
        screen: _currentScreen ?? 'unknown',
        placement: _currentPlacement ?? 'unknown',
      );
    };
  }

  Future<void> showInterstitialAd({String? screen, String? placement}) async {
    if (isAdFree) {
      if (_interstitialAd != null) {
        _interstitialAd!.dispose();
        _interstitialAd = null;
      }
      return;
    }

    if (_interstitialAd != null) {
      try {
        _currentScreen = screen;
        _currentPlacement = placement;
        _hasLoggedImpression = false;
        await _interstitialAd!.show();
        _interstitialAd = null;
      } catch (e) {
        debugPrint('[MonetizationService] show interstitial exception: $e');
        _interstitialAd?.dispose();
        _interstitialAd = null;
        loadInterstitialAd();
      }
    } else {
      loadInterstitialAd();
    }
  }

  Future<void> _handleConsent() async {
    if (kIsWeb) return;
    final completer = Completer<void>();
    final timeout = Timer(const Duration(seconds: 5), () {
      if (!completer.isCompleted) completer.complete();
    });

    try {
      final params = kDebugMode
          ? ConsentRequestParameters(
              consentDebugSettings: ConsentDebugSettings(
                debugGeography: DebugGeography.debugGeographyEea,
                testIdentifiers: _configProvider.testDeviceIds,
              ),
            )
          : ConsentRequestParameters();

      ConsentInformation.instance.requestConsentInfoUpdate(
        params,
        () async {
          try {
            if (await ConsentInformation.instance.isConsentFormAvailable()) {
              await ConsentForm.loadAndShowConsentFormIfRequired(
                (formError) {
                  timeout.cancel();
                  if (!completer.isCompleted) completer.complete();
                },
              );
            } else {
              completer.complete();
            }
          } catch (e) {
            completer.complete();
          }
        },
        (FormError error) {
          timeout.cancel();
          if (!completer.isCompleted) completer.complete();
        },
      );
    } catch (e) {
      timeout.cancel();
      if (!completer.isCompleted) completer.complete();
    }
    return completer.future;
  }

  void dispose() {
    _interstitialAd?.dispose();
    _premiumSubscription?.cancel();
    _connectivitySubscription?.cancel();
  }
}
