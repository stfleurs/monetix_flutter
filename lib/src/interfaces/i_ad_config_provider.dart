import 'package:flutter/foundation.dart';

abstract class IAdConfigProvider extends Listenable {
  String? get bannerAdUnitId;
  String? get interstitialAdUnitId;
  String? get rewardedAdUnitId;
  String? get nativeAdUnitId;
  
  /// Global toggle to enable/disable ads.
  bool get adsEnabled;

  /// Test device IDs for Google Mobile Ads.
  List<String> get testDeviceIds => ['EMULATOR'];

  /// Reward Policy Configuration
  Duration get rewardAdFreeDuration => const Duration(minutes: 15);
  int get maxAdsPerRateLimitWindow => 2;
  Duration get rateLimitWindowDuration => const Duration(hours: 1);
  Duration get cooldownBetweenAdsDuration => const Duration(seconds: 35);

  /// Debug/Simulation: Force the UI to show the fallback banner instead of the native ad.
  bool get simulateNativeFailure => false;
}
