import 'package:flutter/foundation.dart';

abstract class IAdConfigProvider extends Listenable {
  String? get bannerAdUnitId;
  String? get interstitialAdUnitId;
  String? get rewardedAdUnitId;
  String? get nativeAdUnitId;
  
  /// Global toggle to enable/disable ads.
  bool get adsEnabled;

  /// Debug/testing hook to toggle [adsEnabled] at runtime.
  void setAdsEnabledForDebug(bool value) {}

  /// Debug/Simulation: Force the UI to show the fallback banner instead of the native ad.
  bool get simulateNativeFailure => false;

  /// Debug/testing hook to toggle [simulateNativeFailure] at runtime.
  void setSimulateNativeFailureForDebug(bool value) {}

  /// Test device IDs for Google Mobile Ads.
  List<String> get testDeviceIds => ['EMULATOR'];

  /// Reward Policy Configuration
  bool get enableRewardedBreak => true;

  /// Show the explicit "Pause Ads" pill in the header instead of the minimal X.
  /// Default is false (X icon).
  bool get usePauseAdsPill => false;

  /// Debug/testing hook to toggle [enableRewardedBreak] at runtime.
  void setEnableRewardedBreakForDebug(bool value) {}

  /// Debug/testing hook to toggle [usePauseAdsPill] at runtime.
  void setUsePauseAdsPillForDebug(bool value) {}

  Duration get rewardAdFreeDuration => const Duration(minutes: 15);
  int get maxAdsPerRateLimitWindow => 2;
  Duration get rateLimitWindowDuration => const Duration(hours: 1);
  Duration get cooldownBetweenAdsDuration => const Duration(seconds: 35);
}
