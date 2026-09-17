import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../services/monetization_gate.dart';
import '../services/monetix_facade.dart';
import '../interfaces/i_ad_status_provider.dart';
import 'reward_status_sheet.dart';

mixin SafeState<T extends StatefulWidget> on State<T> {
  bool get isSafe => mounted;

  @override
  void setState(VoidCallback fn) {
    if (isSafe) {
      super.setState(fn);
    }
  }
}

class MonetizedNativeAd extends StatefulWidget {
  final TemplateType templateType;
  final String screen;
  final String placement;

  const MonetizedNativeAd({
    super.key,
    this.templateType = TemplateType.small,
    required this.screen,
    required this.placement,
  });

  @override
  MonetizedNativeAdState createState() => MonetizedNativeAdState();
}

class MonetizedNativeAdState extends State<MonetizedNativeAd>
    with SafeState<MonetizedNativeAd> {
  NativeAd? _nativeAd;
  BannerAd? _fallbackBannerAd;
  bool _adLoaded = false;
  bool _bannerLoaded = false;

  bool _isLoading = false;
  bool _isBannerLoading = false;
  bool _hasLoggedImpression = false;
  bool _hasLoggedBannerImpression = false;

  int _bannerRetryCount = 0;
  static const int _maxBannerRetries = 3;

  bool _nativeFailed = false;
  DateTime? _lastFailureTime;

  DateTime? _nativeLoadStartTime;
  int? _nativeLoadDurationMs;
  DateTime? _bannerLoadStartTime;
  int? _bannerLoadDurationMs;

  Brightness? _currentBrightness;
  StreamSubscription<bool>? _premiumSubscription;
  MonetizationGate? _currentGate;
  IAdStatusProvider? _currentStatusProvider;

  static const Duration _nativeFallbackTimeout = Duration(seconds: 5);

  AdSize? _adaptiveSize;
  static const double _defaultBannerHeight = 50.0;

  Timer? _nativeFallbackTimer;

  void _cancelFallbackTimer() {
    _nativeFallbackTimer?.cancel();
    _nativeFallbackTimer = null;
  }

  bool _canRetry() {
    if (_lastFailureTime == null) return true;
    return DateTime.now().difference(_lastFailureTime!) >
        const Duration(seconds: 30);
  }

  Future<void> _ensureAdaptiveSize() async {
    if (_adaptiveSize != null) return;
    try {
      final width = MediaQuery.of(context).size.width.truncate();
      // ignore: deprecated_member_use
      final size = await AdSize.getCurrentOrientationAnchoredAdaptiveBannerAdSize(width);
      if (isSafe && size != null) {
        setState(() => _adaptiveSize = size);
      }
    } catch (_) {}
  }

  @override
  void initState() {
    super.initState();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final statusProvider = Monetix.getStatus(context);
    if (_currentStatusProvider != statusProvider) {
      _premiumSubscription?.cancel();
      _currentStatusProvider = statusProvider;
      _premiumSubscription = _currentStatusProvider!.premiumStatusStream.listen((_) {
        if (mounted) setState(() {});
      });
    }

    final adGate = Monetix.getGate(context);
    if (_currentGate != adGate) {
      _currentGate?.removeListener(_onGateChanged);
      _currentGate = adGate;
      _currentGate?.addListener(_onGateChanged);
    }

    _evaluateAdDecision();
    _ensureAdaptiveSize();
  }

  void _onGateChanged() {
    if (mounted) {
      setState(() {
        _evaluateAdDecision();
      });
    }
  }

  void _evaluateAdDecision() {
    if (_currentGate == null) return;
    final configProvider = Monetix.getConfig(context);
    final currentBrightness = Theme.of(context).brightness;
    final decision = _currentGate!.evaluateNative();

    if (!decision.allowed) {
      debugPrint(
          '🛡️ [Monetix] Native ad hidden on screen "${widget.screen}" (placement: "${widget.placement}") due to reason: ${decision.reason}');
    }

    if ((_adLoaded || _bannerLoaded) &&
        _currentBrightness != currentBrightness) {
      _disposeAds();
      _loadNativeAd();
      return;
    }

    if (decision.allowed && configProvider.adsEnabled && _canRetry()) {
      if (configProvider.simulateNativeFailure) {
        if (!_bannerLoaded && !_isBannerLoading && _fallbackBannerAd == null) {
          _loadFallbackBanner();
        }
      } else {
        if (!_adLoaded && !_isLoading && _nativeAd == null) {
          _loadNativeAd();
        }
      }
    } else if (!decision.allowed &&
        (_nativeAd != null || _fallbackBannerAd != null)) {
      _disposeAds();
    }
  }

  void _disposeAds() {
    _cancelFallbackTimer();
    _nativeAd?.dispose();
    _fallbackBannerAd?.dispose();
    _nativeAd = null;
    _fallbackBannerAd = null;
    if (isSafe) {
      setState(() {
        _adLoaded = false;
        _bannerLoaded = false;
        _isLoading = false;
        _isBannerLoading = false;
        _nativeFailed = false;
      });
    }
  }

  Future<void> _loadNativeAd() async {
    final configProvider = Monetix.getConfig(context);
    final adUnitId = configProvider.nativeAdUnitId ??
        'ca-app-pub-3940256099942544/2247696110'; // Test ID

    if (adUnitId.isEmpty) return;

    final monetizationService = Monetix.getService(context);
    final analyticsService = Monetix.getAnalytics(context);
    final theme = Theme.of(context);

    if (!isSafe) return;

    setState(() {
      _isLoading = true;
      _currentBrightness = theme.brightness;
    });

    try {
      if (!monetizationService.isInitialized) {
        await monetizationService.initialized;
        if (!isSafe) return;
      }
    } catch (_) {}

    _nativeLoadStartTime = DateTime.now();
    analyticsService.logAdRequest(
      adType: 'native',
      adUnitId: adUnitId,
      screen: widget.screen,
      placement: widget.placement,
    );

    try {
      _nativeAd = NativeAd(
        adUnitId: adUnitId,
        request: const AdRequest(),
        listener: NativeAdListener(
          onAdLoaded: (ad) {
            _cancelFallbackTimer();
            if (_nativeAd != null && _nativeAd != ad) {
              // A newer load is already in-flight; discard this late arrival.
              ad.dispose();
              return;
            }
            if (_nativeLoadStartTime != null) {
              _nativeLoadDurationMs = DateTime.now()
                  .difference(_nativeLoadStartTime!)
                  .inMilliseconds;
            }
            setState(() {
              _adLoaded = true;
              _isLoading = false;
            });
          },
          onAdImpression: (ad) {
            if (!_hasLoggedImpression) {
              analyticsService.logAdImpression(
                adType: 'native',
                adUnitId: ad.adUnitId,
                screen: widget.screen,
                placement: widget.placement,
                loadDurationMs: _nativeLoadDurationMs,
              );
              _hasLoggedImpression = true;
            }
          },
          onAdFailedToLoad: (ad, error) {
            analyticsService.logAdFailure(
              adType: 'native',
              adUnitId: ad.adUnitId,
              errorCode: error.code.toString(),
              screen: widget.screen,
              placement: widget.placement,
            );
            ad.dispose();
            if (isSafe) {
              setState(() {
                _isLoading = false;
                _nativeFailed = true;
              });
              _cancelFallbackTimer();
              _loadFallbackBanner();
            }
          },
          onPaidEvent: (ad, valueMicros, precision, currencyCode) {
            analyticsService.logAdRevenue(
              value: valueMicros / 1000000.0,
              currency: currencyCode,
              adType: 'native',
              adUnitId: ad.adUnitId,
              screen: widget.screen,
              placement: widget.placement,
            );
          },
        ),
        nativeTemplateStyle: NativeTemplateStyle(
          templateType: widget.templateType,
          mainBackgroundColor: theme.cardColor,
          cornerRadius: 24.0,
          callToActionTextStyle: NativeTemplateTextStyle(
            textColor: Colors.white,
            backgroundColor: theme.colorScheme.primary,
            style: NativeTemplateFontStyle.bold,
            size: 16.0,
          ),
          primaryTextStyle: NativeTemplateTextStyle(
            textColor: theme.colorScheme.onSurface,
            style: NativeTemplateFontStyle.bold,
            size: 16.0,
          ),
          secondaryTextStyle: NativeTemplateTextStyle(
            textColor: theme.colorScheme.onSurface.withValues(alpha: 0.7),
            style: NativeTemplateFontStyle.normal,
            size: 14.0,
          ),
          tertiaryTextStyle: NativeTemplateTextStyle(
            textColor: theme.colorScheme.onSurface.withValues(alpha: 0.5),
            style: NativeTemplateFontStyle.normal,
            size: 12.0,
          ),
        ),
      );
      _nativeAd?.load();
    } catch (e) {
      debugPrint('⚠️ Monetix: NativeAd not supported on this platform: $e');
      if (isSafe) {
        setState(() => _nativeFailed = true);
      }
    }

    _nativeFallbackTimer = Timer(_nativeFallbackTimeout, () {
      if (isSafe && !_adLoaded && !_nativeFailed && _isLoading) {
        setState(() {
          _nativeFailed = true;
          _isLoading = false;
        });
        _loadFallbackBanner();
      }
    });
  }

  Future<void> _loadFallbackBanner() async {
    if (_isBannerLoading || _bannerLoaded) return;

    final configProvider = Monetix.getConfig(context);
    final adUnitId = configProvider.bannerAdUnitId ??
        'ca-app-pub-3940256099942544/6300978111';

    if (adUnitId.isEmpty) return;

    final analyticsService = Monetix.getAnalytics(context);
    setState(() => _isBannerLoading = true);

    final size = _adaptiveSize ??
        (widget.templateType == TemplateType.small
            ? AdSize.largeBanner
            : AdSize.mediumRectangle);

    _bannerLoadStartTime = DateTime.now();
    analyticsService.logAdRequest(
      adType: 'banner',
      adUnitId: adUnitId,
      screen: widget.screen,
      placement: '${widget.placement}_fallback',
    );

    _fallbackBannerAd = BannerAd(
      adUnitId: adUnitId,
      request: const AdRequest(),
      size: size,
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          if (_bannerLoadStartTime != null) {
            _bannerLoadDurationMs =
                DateTime.now().difference(_bannerLoadStartTime!).inMilliseconds;
          }
          setState(() {
            _bannerLoaded = true;
            _isBannerLoading = false;
            _bannerRetryCount = 0;
          });
        },
        onAdImpression: (ad) {
          if (!_hasLoggedBannerImpression) {
            analyticsService.logAdImpression(
              adType: 'banner',
              adUnitId: ad.adUnitId,
              screen: widget.screen,
              placement: '${widget.placement}_fallback',
              isFallback: true,
              loadDurationMs: _bannerLoadDurationMs,
            );
            _hasLoggedBannerImpression = true;
          }
        },
        onAdFailedToLoad: (ad, error) {
          analyticsService.logAdFailure(
            adType: 'banner',
            adUnitId: ad.adUnitId,
            errorCode: error.code.toString(),
            screen: widget.screen,
            placement: '${widget.placement}_fallback',
          );
          ad.dispose();
          if (isSafe) {
            setState(() => _isBannerLoading = false);
            if (_bannerRetryCount < _maxBannerRetries) {
              _bannerRetryCount++;
              Future.delayed(Duration(seconds: _bannerRetryCount * 5), () {
                if (isSafe && !_bannerLoaded && !_isBannerLoading) {
                  _loadFallbackBanner();
                }
              });
            } else {
              _lastFailureTime = DateTime.now();
            }
          }
        },
        onPaidEvent: (ad, valueMicros, precision, currencyCode) {
          analyticsService.logAdRevenue(
            value: valueMicros / 1000000.0,
            currency: currencyCode,
            adType: 'banner',
            adUnitId: ad.adUnitId,
            screen: widget.screen,
            placement: '${widget.placement}_fallback',
          );
        },
      ),
    );

    await _fallbackBannerAd!.load();
  }

  @override
  void dispose() {
    _cancelFallbackTimer();
    _premiumSubscription?.cancel();
    _currentGate?.removeListener(_onGateChanged);
    _nativeAd?.dispose();
    _fallbackBannerAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_currentGate == null) return const SizedBox.shrink();
    final decision = _currentGate!.evaluateNative();

    if (!decision.allowed) {
      return const SizedBox.shrink();
    }

    final configProvider = Monetix.getConfig(context);
    final statusProvider = Monetix.getStatus(context);
    final usePill = configProvider.usePauseAdsPill;
    final simulateFailure = configProvider.simulateNativeFailure;
    final isMedium = widget.templateType == TemplateType.medium;

    Widget buildHeaderBar() {
      final configProvider = Monetix.getConfig(context);
      final showOptOut = configProvider.enableRewardedBreak;
      final colors = Theme.of(context).colorScheme;

      return Container(
        height: 24,
        color: colors.surface.withValues(alpha: 0.95),
        child: Row(
          children: [
            const SizedBox(width: 6),
            Text(
              'Ad',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
                color: colors.onSurface.withValues(alpha: 0.4),
              ),
            ),
            const Spacer(),
            if (showOptOut)
              usePill
                  ? GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => showRewardStatusSheet(context),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          color: colors.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: colors.primary.withValues(alpha: 0.3),
                            width: 0.8,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.block_rounded,
                                size: 11, color: colors.primary),
                            const SizedBox(width: 4),
                            Text(
                              statusProvider.pauseAdsLabel,
                              style: TextStyle(
                                color: colors.primary,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  : GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => showRewardStatusSheet(context),
                      child: Container(
                        width: 22,
                        height: 22,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: colors.onSurface.withValues(alpha: 0.15),
                            width: 0.5,
                          ),
                        ),
                        child: Icon(
                          Icons.close,
                          size: 13,
                          color: colors.onSurface.withValues(alpha: 0.4),
                        ),
                      ),
                    ),
            const SizedBox(width: 6),
          ],
        ),
      );
    }

    Widget buildContainer({required Widget child, bool compact = false}) {
      final adHeight = compact
          ? (_adaptiveSize?.height.toDouble() ?? _defaultBannerHeight)
          : null;
      return Container(
        margin:
            EdgeInsets.symmetric(horizontal: isMedium ? 12 : 8, vertical: 0),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(isMedium ? 16 : 12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isMedium ? 0.08 : 0.08),
              blurRadius: isMedium ? 8 : 8,
              offset: const Offset(0, 2),
            ),
          ],
          border: Border.all(
            color: Theme.of(context)
                .colorScheme
                .outlineVariant
                .withValues(alpha: 0.4),
            width: 1.0,
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(isMedium ? 16 : 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              buildHeaderBar(),
              Divider(
                height: 1,
                thickness: 0.8,
                color: Theme.of(context)
                    .colorScheme
                    .outlineVariant
                    .withValues(alpha: 0.08),
              ),
              if (compact) SizedBox(height: adHeight, child: child) else child,
            ],
          ),
        ),
      );
    }

    Widget buildAdWrapper(Widget adContent, {bool compact = false}) {
      return buildContainer(child: adContent, compact: compact);
    }

    final showNative =
        _adLoaded && _nativeAd != null && !simulateFailure && !_nativeFailed;
    final showBanner = _bannerLoaded &&
        _fallbackBannerAd != null &&
        (simulateFailure || _nativeFailed);
    final hasFailedCompletely = _nativeFailed && !_bannerLoaded && !_isBannerLoading && (_bannerRetryCount >= _maxBannerRetries);

    if (hasFailedCompletely) {
      return const SizedBox.shrink();
    }

    if (showNative) {
      final nativeAdHeight =
          widget.templateType == TemplateType.small ? 85.0 : 250.0;
      return buildAdWrapper(
        SizedBox(
          width: double.infinity,
          height: nativeAdHeight,
          child: AdWidget(ad: _nativeAd!),
        ),
      );
    } else if (showBanner) {
      return buildAdWrapper(
        Center(
          child: SizedBox(
            width: _fallbackBannerAd!.size.width.toDouble(),
            height: _fallbackBannerAd!.size.height.toDouble(),
            child: AdWidget(ad: _fallbackBannerAd!),
          ),
        ),
        compact: true,
      );
    } else {
      return buildAdWrapper(
        const Center(child: CircularProgressIndicator(strokeWidth: 2)),
        compact: true,
      );
    }
  }
}
