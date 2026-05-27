import 'package:flutter/foundation.dart';

abstract class IAdStatusProvider extends Listenable {
  /// Returns true if the user has purchased a premium/pro version and should not see ads.
  bool get isPremium;

  /// A stream of premium status changes.
  Stream<bool> get premiumStatusStream;
  
  /// A callback to show the monetization/purchase sheet (e.g. when user clicks "Pause Ads").
  void showPurchaseScreen(dynamic context);

  /// Localized strings for the UI
  String get pauseAdsLabel;
  String get rewardSheetTitle;
  String get rewardSheetDescription;
  String get watchAdButtonLabel;
  String get alreadyAdFreeLabel;
  String get minutesRemainingLabel;
  String get upgradeLabel;
  String get tiredOfAdsLabel;
  String get goPremiumLabel;
  String get okLabel;
  String get closeLabel;
  String get loadingLabel;
  String get loadAdLabel;
  String get adPlayingLabel;
  String get rateLimitedLabel;
  String get cooldownLabel;
}
