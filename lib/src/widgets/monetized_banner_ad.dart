import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:provider/provider.dart';
import '../interfaces/i_ad_analytics.dart';
import '../interfaces/i_ad_config_provider.dart';
import '../interfaces/i_ad_status_provider.dart';
import '../services/monetization_gate.dart';
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
  bool _hasLoggedImpression = false;
  DateTime? _loadStartTime;
  int? _loadDurationMs;
  StreamSubscription<bool>? _premiumSubscription;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final statusProvider = Provider.of<IAdStatusProvider>(context, listen: false);
      _premiumSubscription = statusProvider.premiumStatusStream.listen((_) {
        if (mounted) setState(() {});
      });
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final adGate = Provider.of<MonetizationGate>(context);
    final decision = adGate.evaluateBanner();

    if (!decision.allowed) {
      debugPrint('🛡️ [Monetix] Banner ad hidden on screen "${widget.screen}" (placement: "${widget.placement}") due to reason: ${decision.reason}');
    }

    if (decision.allowed && !_adLoaded) {
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
    final configProvider =
        Provider.of<IAdConfigProvider>(context, listen: false);
    final analyticsService = Provider.of<IAdAnalytics>(context, listen: false);
    final adUnitId = configProvider.bannerAdUnitId ??
        'ca-app-pub-3940256099942544/6300978111'; // Test ID

    final size = await AdSize.getLargeAnchoredAdaptiveBannerAdSize(
        MediaQuery.of(context).size.width.truncate());

    if (!isSafe || size == null) return;

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
    _bannerAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_adLoaded && _bannerAd != null) {
      final statusProvider = Provider.of<IAdStatusProvider>(context);
      final configProvider = Provider.of<IAdConfigProvider>(context);
      final showOptOut = configProvider.enableRewardedBreak;

      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (showOptOut)
            Padding(
              padding: const EdgeInsets.only(bottom: 1, right: 4),
              child: GestureDetector(
              onTap: () => showRewardStatusSheet(context),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary,
                  borderRadius: BorderRadius.circular(20),
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
                      size: 14,
                      color: Theme.of(context).colorScheme.onPrimary,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      statusProvider.pauseAdsLabel,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onPrimary,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          SizedBox(
            width: _bannerAd!.size.width.toDouble(),
            height: _bannerAd!.size.height.toDouble(),
            child: AdWidget(ad: _bannerAd!),
          ),
        ],
      );
    } else {
      return const SizedBox.shrink();
    }
  }
}
