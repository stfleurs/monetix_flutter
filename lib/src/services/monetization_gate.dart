import 'package:flutter/foundation.dart';
import '../interfaces/i_ad_config_provider.dart';
import '../interfaces/i_ad_status_provider.dart';
import 'rewarded_monetization_service.dart';

/// Reasons why an ad is either allowed or blocked from being displayed.
enum AdVisibilityReason {
  /// User has active premium access.
  premium,

  /// User earned a temporary ad-free rewarded break.
  rewardedPause,

  /// Ads are globally disabled via Remote Config/Ad Config.
  remoteDisabled,

  /// Ad is allowed to be shown.
  allowed,
}

/// Represents the final structured decision of the ad visibility engine.
class AdDecision {
  /// Whether the ad is allowed to be displayed in the UI.
  final bool allowed;

  /// The underlying diagnostic reason supporting this decision.
  final AdVisibilityReason reason;

  const AdDecision({
    required this.allowed,
    required this.reason,
  });

  @override
  String toString() => 'AdDecision(allowed: $allowed, reason: $reason)';
}

/// A centralized ad visibility gate that evaluates multi-dimensional rules
/// (premium state, ad-free rewards, remote configs, etc.) to determine if
/// ads should be shown in the UI.
class MonetizationGate extends ChangeNotifier {
  final IAdConfigProvider _configProvider;
  final IAdStatusProvider _statusProvider;
  final RewardedMonetizationService _rewardedService;

  IAdConfigProvider get configProvider => _configProvider;
  IAdStatusProvider get statusProvider => _statusProvider;
  RewardedMonetizationService get rewardedService => _rewardedService;

  MonetizationGate({
    required IAdConfigProvider configProvider,
    required IAdStatusProvider statusProvider,
    required RewardedMonetizationService rewardedService,
  })  : _configProvider = configProvider,
        _statusProvider = statusProvider,
        _rewardedService = rewardedService {
    _configProvider.addListener(_onStateChanged);
    _statusProvider.addListener(_onStateChanged);
    _rewardedService.addListener(_onStateChanged);
  }

  void _onStateChanged() {
    notifyListeners();
  }

  /// Evaluates standard banner ad visibility.
  AdDecision evaluateBanner() {
    if (!_configProvider.adsEnabled) {
      return const AdDecision(allowed: false, reason: AdVisibilityReason.remoteDisabled);
    }
    if (_statusProvider.isPremium) {
      return const AdDecision(allowed: false, reason: AdVisibilityReason.premium);
    }
    if (_rewardedService.isAdFree) {
      return const AdDecision(allowed: false, reason: AdVisibilityReason.rewardedPause);
    }
    return const AdDecision(allowed: true, reason: AdVisibilityReason.allowed);
  }

  /// Evaluates native ad visibility.
  AdDecision evaluateNative() {
    return evaluateBanner();
  }

  /// Evaluates interstitial ad visibility.
  AdDecision evaluateInterstitial() {
    return evaluateBanner();
  }

  /// Evaluates rewarded ad visibility/loading policy.
  AdDecision evaluateRewarded() {
    if (!_configProvider.adsEnabled || !_configProvider.enableRewardedBreak) {
      return const AdDecision(allowed: false, reason: AdVisibilityReason.remoteDisabled);
    }
    if (_statusProvider.isPremium) {
      return const AdDecision(allowed: false, reason: AdVisibilityReason.premium);
    }
    return const AdDecision(allowed: true, reason: AdVisibilityReason.allowed);
  }

  /// Returns true if all criteria for showing ads are met.
  bool get shouldShowAds => evaluateBanner().allowed;

  /// Whether persistent bottom banner ads should be shown.
  bool get shouldShowBottomAd => evaluateBanner().allowed;

  /// Whether banner ads should be shown in general.
  bool get shouldShowBanner => evaluateBanner().allowed;

  /// Whether native ads should be shown.
  bool get shouldShowNative => evaluateNative().allowed;

  /// Whether interstitial ads should be shown.
  bool get shouldShowInterstitial => evaluateInterstitial().allowed;

  @override
  void dispose() {
    _configProvider.removeListener(_onStateChanged);
    _statusProvider.removeListener(_onStateChanged);
    _rewardedService.removeListener(_onStateChanged);
    super.dispose();
  }
}
