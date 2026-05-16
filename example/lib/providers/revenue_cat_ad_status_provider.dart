import 'dart:async';
import 'package:flutter/material.dart';
import 'package:monetix_flutter/monetix_flutter.dart';

class RevenueCatAdStatusProvider extends ChangeNotifier implements IAdStatusProvider {
  bool _isPremium = false;
  final _controller = StreamController<bool>.broadcast();

  @override
  bool get isPremium => _isPremium;

  void simulateSubscriptionActive(bool value) {
    _isPremium = value;
    _controller.add(_isPremium);
    notifyListeners();
  }

  @override
  Stream<bool> get premiumStatusStream => _controller.stream;

  @override
  void dispose() {
    _controller.close();
    super.dispose();
  }

  @override
  void showPurchaseScreen(dynamic context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('💰 RevenueCat Paywall would open here')),
    );
  }

  @override String get pauseAdsLabel => "Pause Ads for 15 min";
  @override String get rewardSheetTitle => "Get an Ad-Free Break";
  @override String get rewardSheetDescription => "Watch a short video to remove all ads for 15 minutes.";
  @override String get watchAdButtonLabel => "Watch Video";
  @override String get loadAdLabel => "Load Ad";
  @override String get alreadyAdFreeLabel => "Ads are Paused";
  @override String get minutesRemainingLabel => "minutes remaining";
  @override String get upgradeLabel => "Upgrade to Premium";
  @override String get tiredOfAdsLabel => "Tired of these ads?";
  @override String get goPremiumLabel => "Go premium for a completely ad-free experience.";
  @override String get okLabel => "Got it";
  @override String get closeLabel => "Close";
  @override String get loadingLabel => "Loading Ad...";
  @override String get adPlayingLabel => "Ad is playing";
  @override String get rateLimitedLabel => "Come back later";
  @override String get cooldownLabel => "Please wait a moment";
}

class DebugAdConfig extends ChangeNotifier implements IAdConfigProvider {
  bool _adsEnabled = true;
  bool _simulateNativeFailure = false;
  bool _enableRewardedBreak = true;
  final String _bannerId = 'ca-app-pub-3940256099942544/6300978111';
  final String _nativeId = 'ca-app-pub-3940256099942544/2247696110';

  @override bool get adsEnabled => _adsEnabled;
  @override bool get simulateNativeFailure => _simulateNativeFailure;
  @override bool get enableRewardedBreak => _enableRewardedBreak;
  @override String? get bannerAdUnitId => _bannerId;
  @override String? get nativeAdUnitId => _nativeId;
  String? _interstitialId = 'ca-app-pub-3940256099942544/1033173712';
  @override String? get interstitialAdUnitId => _interstitialId;
  
  void setInterstitialId(String? value) {
    _interstitialId = value;
    notifyListeners();
  }
  String? _rewardedId = 'ca-app-pub-3940256099942544/5224354917';
  @override String? get rewardedAdUnitId => _rewardedId;
  
  void setRewardedId(String? value) {
    _rewardedId = value;
    notifyListeners();
  }
  @override List<String> get testDeviceIds => [];

  void setAdsEnabled(bool value) {
    _adsEnabled = value;
    notifyListeners();
  }

  void setSimulateNativeFailure(bool value) {
    _simulateNativeFailure = value;
    notifyListeners();
  }

  void setEnableRewardedBreak(bool value) {
    _enableRewardedBreak = value;
    notifyListeners();
  }

  @override Duration get rewardAdFreeDuration => const Duration(minutes: 15);
  @override int get maxAdsPerRateLimitWindow => 2;
  @override Duration get rateLimitWindowDuration => const Duration(hours: 1);
  @override Duration get cooldownBetweenAdsDuration => const Duration(seconds: 35);
}
