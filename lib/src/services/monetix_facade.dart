import '../interfaces/i_ad_analytics.dart';
import '../interfaces/i_ad_config_provider.dart';
import '../interfaces/i_ad_status_provider.dart';
import 'monetization_service.dart';
import 'rewarded_monetization_service.dart';
import 'simple_implementations.dart';

/// A facade to simplify the setup of the monetization system.
class Monetix {
  static MonetizationService? _instance;
  static RewardedMonetizationService? _rewardedInstance;

  /// The global [MonetizationService] instance.
  static MonetizationService get instance {
    if (_instance == null) {
      throw StateError('Monetix not initialized. Call initialize() first.');
    }
    return _instance!;
  }

  /// The global [RewardedMonetizationService] instance.
  static RewardedMonetizationService get rewarded {
    if (_rewardedInstance == null) {
      throw StateError('Monetix not initialized. Call initialize() first.');
    }
    return _rewardedInstance!;
  }

  /// Initializes the monetization system with either custom providers or simple IDs.
  static Future<void> initialize({
    IAdConfigProvider? config,
    IAdStatusProvider? status,
    IAdAnalytics? analytics,
    String? bannerId,
    String? interstitialId,
    String? rewardedId,
    String? nativeId,
    List<String> testDeviceIds = const [],
    bool adsEnabled = true,
  }) async {
    final configProvider = config ?? SimpleAdConfig(
      bannerAdUnitId: bannerId,
      interstitialAdUnitId: interstitialId,
      rewardedAdUnitId: rewardedId,
      nativeAdUnitId: nativeId,
      adsEnabled: adsEnabled,
      testDeviceIds: testDeviceIds,
    );

    final analyticsService = analytics ?? ConsoleAdAnalytics();
    final statusProvider = status ?? BasicAdStatus();

    _rewardedInstance = RewardedMonetizationService(
      configProvider,
      analyticsService: analyticsService,
    );

    _instance = MonetizationService(
      configProvider,
      statusProvider: statusProvider,
      analyticsService: analyticsService,
      rewardedAdService: _rewardedInstance,
    );

    await _instance!.init();
  }
}
