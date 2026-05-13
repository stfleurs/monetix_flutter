import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:provider/provider.dart';
import '../interfaces/i_ad_analytics.dart';
import '../interfaces/i_ad_config_provider.dart';
import '../interfaces/i_ad_status_provider.dart';
import '../services/monetization_service.dart';
import '../services/rewarded_monetization_service.dart';
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

  int _retryCount = 0;
  int _bannerRetryCount = 0;
  static const int _maxRetries = 3;
  static const int _maxBannerRetries = 3;

  bool _nativeFailed = false;
  DateTime? _lastFailureTime;

  DateTime? _nativeLoadStartTime;
  int? _nativeLoadDurationMs;
  DateTime? _bannerLoadStartTime;
  int? _bannerLoadDurationMs;

  Brightness? _currentBrightness;
  StreamSubscription<bool>? _premiumSubscription;

  bool _canRetry() {
    if (_lastFailureTime == null) return true;
    return DateTime.now().difference(_lastFailureTime!) >
        const Duration(seconds: 30);
  }

  @override
  void initState() {
    super.initState();
    // Subscribe directly to the premium stream so ads react regardless of
    // how the host app has set up its Provider tree.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final statusProvider =
          Provider.of<IAdStatusProvider>(context, listen: false);
      _premiumSubscription = statusProvider.premiumStatusStream.listen((_) {
        if (mounted) setState(() {});
      });
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final statusProvider = Provider.of<IAdStatusProvider>(context);
    final rewardedAdService = Provider.of<RewardedMonetizationService>(context);
    final configProvider = Provider.of<IAdConfigProvider>(context);

    final currentBrightness = Theme.of(context).brightness;
    final shouldHideAds =
        statusProvider.isPremium || rewardedAdService.isAdFree;

    if ((_adLoaded || _bannerLoaded) &&
        _currentBrightness != currentBrightness) {
      _disposeAds();
      _loadNativeAd();
      return;
    }

    if (!shouldHideAds && configProvider.adsEnabled && _canRetry()) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!isSafe) return;
        if (!_adLoaded && !_isLoading && _nativeAd == null) {
          _loadNativeAd();
        }
        if (!_bannerLoaded && !_isBannerLoading && _fallbackBannerAd == null) {
          _loadFallbackBanner();
        }
      });
    } else if (shouldHideAds &&
        (_nativeAd != null || _fallbackBannerAd != null)) {
      _disposeAds();
    }
  }

  void _disposeAds() {
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
    final configProvider =
        Provider.of<IAdConfigProvider>(context, listen: false);
    final adUnitId = configProvider.nativeAdUnitId ??
        'ca-app-pub-3940256099942544/2247696110'; // Test ID

    if (adUnitId.isEmpty) return;

    final monetizationService =
        Provider.of<MonetizationService>(context, listen: false);
    final analyticsService = Provider.of<IAdAnalytics>(context, listen: false);
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
            if (_nativeLoadStartTime != null) {
              _nativeLoadDurationMs = DateTime.now()
                  .difference(_nativeLoadStartTime!)
                  .inMilliseconds;
            }
            setState(() {
              _adLoaded = true;
              _isLoading = false;
              _retryCount = 0;
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
              setState(() => _isLoading = false);
              if (_retryCount < _maxRetries) {
                _retryCount++;
                Future.delayed(Duration(seconds: _retryCount * 5), () {
                  if (isSafe && !_adLoaded && !_isLoading && !_nativeFailed)
                    _loadNativeAd();
                });
              } else {
                setState(() => _nativeFailed = true);
              }
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

    Future.delayed(const Duration(seconds: 5), () {
      if (isSafe && !_adLoaded && !_nativeFailed && !_isLoading) {
        setState(() => _nativeFailed = true);
      }
    });
  }

  Future<void> _loadFallbackBanner() async {
    if (_isBannerLoading || _bannerLoaded) return;

    final configProvider =
        Provider.of<IAdConfigProvider>(context, listen: false);
    final adUnitId = configProvider.bannerAdUnitId ??
        'ca-app-pub-3940256099942544/6300978111';

    if (adUnitId.isEmpty) return;

    final analyticsService = Provider.of<IAdAnalytics>(context, listen: false);
    setState(() => _isBannerLoading = true);

    final size = widget.templateType == TemplateType.small
        ? AdSize.largeBanner
        : AdSize.mediumRectangle;

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
                if (isSafe && !_bannerLoaded && !_isBannerLoading)
                  _loadFallbackBanner();
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
    _premiumSubscription?.cancel();
    _nativeAd?.dispose();
    _fallbackBannerAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final statusProvider = Provider.of<IAdStatusProvider>(context);
    final rewardedAdService = Provider.of<RewardedMonetizationService>(context);

    if (statusProvider.isPremium || rewardedAdService.isAdFree) {
      return const SizedBox.shrink();
    }

    final configProvider = Provider.of<IAdConfigProvider>(context);
    final simulateFailure = configProvider.simulateNativeFailure;
    final isMedium = widget.templateType == TemplateType.medium;

    Widget buildContainer({required Widget child}) {
      return Container(
        margin:
            EdgeInsets.symmetric(horizontal: isMedium ? 12 : 8, vertical: 0),
        height: isMedium ? 350 : 105,
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(isMedium ? 16 : 12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isMedium ? 0.06 : 0.04),
              blurRadius: isMedium ? 8 : 4,
              offset: const Offset(0, 2),
            ),
          ],
          border: Border.all(
            color:
                Theme.of(context).colorScheme.outline.withValues(alpha: 0.05),
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(isMedium ? 16 : 12),
          child: child,
        ),
      );
    }

    Widget buildOptOutButton() {
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => showRewardStatusSheet(context),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primary,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(isMedium ? 16 : 12),
              topRight: Radius.circular(isMedium ? 16 : 12),
              bottomLeft: const Radius.circular(12),
              bottomRight: const Radius.circular(4),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.15),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.block_rounded,
                size: 12.5,
                color: Theme.of(context).colorScheme.onPrimary,
              ),
              const SizedBox(width: 6),
              Text(
                statusProvider.pauseAdsLabel,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onPrimary,
                  fontSize: 9.5,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      );
    }

    Widget buildAdWrapper(Widget adContent) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.topRight,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 11),
                child: buildContainer(child: adContent),
              ),
              Positioned(
                top: 0,
                right: isMedium ? 12 : 8,
                child: buildOptOutButton(),
              ),
            ],
          ),
        ],
      );
    }

    final showNative =
        _adLoaded && _nativeAd != null && !simulateFailure && !_nativeFailed;
    final showBanner = _bannerLoaded &&
        _fallbackBannerAd != null &&
        (simulateFailure || _nativeFailed);

    if (showNative) {
      return buildAdWrapper(AdWidget(ad: _nativeAd!));
    } else if (showBanner) {
      return buildAdWrapper(
        Center(
          child: SizedBox(
            width: _fallbackBannerAd!.size.width.toDouble(),
            height: _fallbackBannerAd!.size.height.toDouble(),
            child: AdWidget(ad: _fallbackBannerAd!),
          ),
        ),
      );
    } else {
      return buildAdWrapper(
        const Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }
  }
}
