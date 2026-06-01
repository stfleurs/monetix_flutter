import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../services/monetization_gate.dart';
import '../services/monetix_facade.dart';
import 'monetized_native_ad.dart'; // For SafeState mixin
import 'reward_status_sheet.dart';

class MonetizedBannerAd extends StatefulWidget {
  final String screen;
  final String placement;

  const MonetizedBannerAd({
    super.key,
    required this.screen,
    required this.placement,
  });

  @override
  MonetizedBannerAdState createState() => MonetizedBannerAdState();
}

class MonetizedBannerAdState extends State<MonetizedBannerAd>
    with SafeState<MonetizedBannerAd> {
  BannerAd? _bannerAd;
  bool _adLoaded = false;
  bool _isLoading = false;
  bool _hasLoggedImpression = false;
  DateTime? _loadStartTime;
  int? _loadDurationMs;
  StreamSubscription<bool>? _premiumSubscription;
  MonetizationGate? _currentGate;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final statusProvider = Monetix.getStatus(context);
      _premiumSubscription = statusProvider.premiumStatusStream.listen((_) {
        if (mounted) setState(() {});
      });
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final adGate = Monetix.getGate(context);
    if (_currentGate != adGate) {
      _currentGate?.removeListener(_onGateChanged);
      _currentGate = adGate;
      _currentGate?.addListener(_onGateChanged);
    }

    _evaluateAdDecision();
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
    final decision = _currentGate!.evaluateBanner();

    if (!decision.allowed) {
      debugPrint('🛡️ [Monetix] Banner ad hidden on screen "${widget.screen}" (placement: "${widget.placement}") due to reason: ${decision.reason}');
    }

    if (decision.allowed && !_adLoaded && !_isLoading) {
      _loadBannerAd();
    } else if (!decision.allowed && _adLoaded) {
      _disposeBanner();
    }
  }

  void _disposeBanner() {
    _bannerAd?.dispose();
    _bannerAd = null;
    setState(() => _adLoaded = false);
  }

  Future<void> _loadBannerAd() async {
    if (_isLoading) return;

    final configProvider = Monetix.getConfig(context);
    final analyticsService = Monetix.getAnalytics(context);
    final adUnitId = configProvider.bannerAdUnitId ??
        'ca-app-pub-3940256099942544/6300978111'; // Test ID

    // ignore: deprecated_member_use
    final size = await AdSize.getCurrentOrientationAnchoredAdaptiveBannerAdSize(
        MediaQuery.of(context).size.width.truncate());

    if (!isSafe || size == null) return;

    setState(() {
      _isLoading = true;
    });

    _loadStartTime = DateTime.now();
    analyticsService.logAdRequest(
      adType: 'banner',
      adUnitId: adUnitId,
      screen: widget.screen,
      placement: widget.placement,
    );

    try {
      _bannerAd = BannerAd(
        adUnitId: adUnitId,
        request: const AdRequest(),
        size: size,
        listener: BannerAdListener(
          onAdLoaded: (ad) {
            if (_loadStartTime != null) {
              _loadDurationMs =
                  DateTime.now().difference(_loadStartTime!).inMilliseconds;
            }
            setState(() {
              _adLoaded = true;
              _isLoading = false;
            });
          },
          onAdImpression: (ad) {
            if (!_hasLoggedImpression) {
              analyticsService.logAdImpression(
                adType: 'banner',
                adUnitId: ad.adUnitId,
                screen: widget.screen,
                placement: widget.placement,
                loadDurationMs: _loadDurationMs,
              );
              _hasLoggedImpression = true;
            }
          },
          onAdFailedToLoad: (ad, error) {
            ad.dispose();
            _bannerAd = null;
            analyticsService.logAdFailure(
              adType: 'banner',
              adUnitId: adUnitId,
              errorCode: error.message,
              screen: widget.screen,
              placement: widget.placement,
            );
            setState(() {
              _isLoading = false;
            });
          },
          onPaidEvent: (ad, valueMicros, precision, currencyCode) {
            analyticsService.logAdRevenue(
              value: valueMicros / 1000000.0,
              currency: currencyCode,
              adType: 'banner',
              adUnitId: ad.adUnitId,
              screen: widget.screen,
              placement: widget.placement,
            );
          },
        ),
      );
      _bannerAd?.load();
    } catch (e) {
      debugPrint('⚠️ Monetix: BannerAd not supported on this platform: $e');
    }
  }

  @override
  void dispose() {
    _premiumSubscription?.cancel();
    _currentGate?.removeListener(_onGateChanged);
    _bannerAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_adLoaded && _bannerAd != null) {
      final statusProvider = Monetix.getStatus(context);
      final configProvider = Monetix.getConfig(context);
      final showOptOut = configProvider.enableRewardedBreak;
      final colors = Theme.of(context).colorScheme;

      return Container(
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
          border: Border.all(
            color: colors.outlineVariant.withValues(alpha: 0.4),
            width: 1.0,
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header bar
              Container(
                height: 32,
                color: colors.surface.withValues(alpha: 0.95),
                child: Row(
                  children: [
                    const SizedBox(width: 10),
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
                      GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => showRewardStatusSheet(context),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
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
                      ),
                    const SizedBox(width: 10),
                  ],
                ),
              ),
              Divider(
                height: 1,
                thickness: 0.5,
                color: colors.outlineVariant.withValues(alpha: 0.4),
              ),
              // Banner ad
              Center(
                child: SizedBox(
                  width: _bannerAd!.size.width.toDouble(),
                  height: _bannerAd!.size.height.toDouble(),
                  child: AdWidget(ad: _bannerAd!),
                ),
              ),
            ],
          ),
        ),
      );
    } else {
      return const SizedBox.shrink();
    }
  }

}
