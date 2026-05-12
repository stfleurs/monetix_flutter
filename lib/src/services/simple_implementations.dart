import 'dart:async';
import 'package:flutter/material.dart';
import '../interfaces/i_ad_analytics.dart';
import '../interfaces/i_ad_config_provider.dart';
import '../interfaces/i_ad_status_provider.dart';

/// A simple configuration provider that takes IDs as parameters.
class SimpleAdConfig extends ChangeNotifier implements IAdConfigProvider {
  @override final String? bannerAdUnitId;
  @override final String? interstitialAdUnitId;
  @override final String? rewardedAdUnitId;
  @override final String? nativeAdUnitId;
  @override final bool adsEnabled;
  @override final List<String> testDeviceIds;
  @override final Duration rewardAdFreeDuration;
  @override final int maxAdsPerRateLimitWindow;
  @override final Duration rateLimitWindowDuration;
  @override final Duration cooldownBetweenAdsDuration;

  SimpleAdConfig({
    this.bannerAdUnitId,
    this.interstitialAdUnitId,
    this.rewardedAdUnitId,
    this.nativeAdUnitId,
    this.adsEnabled = true,
    this.testDeviceIds = const [],
    this.rewardAdFreeDuration = const Duration(minutes: 15),
    this.maxAdsPerRateLimitWindow = 2,
    this.rateLimitWindowDuration = const Duration(hours: 1),
    this.cooldownBetweenAdsDuration = const Duration(seconds: 35),
  });
}

/// An analytics provider that prints events to the console.
class ConsoleAdAnalytics extends IAdAnalytics {
  final bool verbose;
  ConsoleAdAnalytics({this.verbose = false});

  @override
  Future<void> logAdRequest({required String adType, required String adUnitId, required String screen, required String placement}) async {
    if (verbose) debugPrint('[AdAnalytics] Request: $adType ($placement) on $screen');
  }

  @override
  Future<void> logAdImpression({required String adType, required String adUnitId, required String screen, required String placement, int? loadDurationMs, bool isFallback = false}) async {
    debugPrint('[AdAnalytics] Impression: $adType ($placement) on $screen ${isFallback ? '(FALLBACK)' : ''}');
  }

  @override
  Future<void> logAdFailure({required String adType, required String adUnitId, required String errorCode, required String screen, required String placement}) async {
    debugPrint('[AdAnalytics] FAILURE: $adType ($placement) on $screen - Error: $errorCode');
  }

  @override
  Future<void> logAdRevenue({required double value, required String currency, required String adType, required String adUnitId, required String screen, required String placement}) async {
    debugPrint('[AdAnalytics] REVENUE: $value $currency from $adType');
  }

  @override
  Future<void> logAdRewardEarned({required String adType, required String screen, required String placement}) async {
    debugPrint('[AdAnalytics] REWARD EARNED: $adType on $screen');
  }

  @override
  void startPostAdWindow(String adType) {
    if (verbose) debugPrint('[AdAnalytics] Post-ad window started for $adType');
  }
}

/// A basic status provider with in-memory state.
class BasicAdStatus extends ChangeNotifier implements IAdStatusProvider {
  bool _isPremium = false;
  final _controller = StreamController<bool>.broadcast();
  
  @override bool get isPremium => _isPremium;
  
  set isPremium(bool value) {
    _isPremium = value;
    _controller.add(value);
    notifyListeners();
  }

  @override Stream<bool> get premiumStatusStream => _controller.stream;

  @override
  void dispose() {
    _controller.close();
    super.dispose();
  }

  @override
  void showPurchaseScreen(dynamic context) {
    debugPrint('Show purchase screen requested');
  }

  @override String pauseAdsLabel = "Pause Ads (15 min)";
  @override String rewardSheetTitle = "Ad-Free Break";
  @override String rewardSheetDescription = "Watch a short ad to remove all ads for 15 minutes.";
  @override String watchAdButtonLabel = "Watch Now";
  @override String alreadyAdFreeLabel = "Ads are Paused";
  @override String minutesRemainingLabel = "min remaining";
  @override String upgradeLabel = "Upgrade";
  @override String tiredOfAdsLabel = "Tired of ads?";
  @override String goPremiumLabel = "Go premium for zero ads.";
  @override String okLabel = "OK";
  @override String closeLabel = "Close";
  @override String loadingLabel = "Loading...";
  @override String loadAdLabel = "Load Ad";
  @override String adPlayingLabel = "Ad is playing";
  @override String rateLimitedLabel = "Come back later";
  @override String cooldownLabel = "Please wait";
}
