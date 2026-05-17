import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';
import '../interfaces/i_ad_analytics.dart';
import '../interfaces/i_ad_config_provider.dart';
import '../interfaces/i_ad_status_provider.dart';
import 'monetization_gate.dart';
import 'monetization_service.dart';
import 'rewarded_monetization_service.dart';
import 'simple_implementations.dart';

/// A facade to simplify the setup of the monetization system.
class Monetix {
  static MonetizationService? _instance;
  static RewardedMonetizationService? _rewardedInstance;
  static MonetizationGate? _gateInstance;

  static IAdConfigProvider? _configInstance;
  static IAdStatusProvider? _statusInstance;
  static IAdAnalytics? _analyticsInstance;

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

  /// The global [MonetizationGate] instance.
  static MonetizationGate get gate {
    if (_gateInstance == null) {
      throw StateError('Monetix not initialized. Call initialize() first.');
    }
    return _gateInstance!;
  }

  /// The global [IAdConfigProvider] instance.
  static IAdConfigProvider get config {
    if (_configInstance == null) {
      throw StateError('Monetix not initialized. Call initialize() first.');
    }
    return _configInstance!;
  }

  /// The global [IAdStatusProvider] instance.
  static IAdStatusProvider get status {
    if (_statusInstance == null) {
      throw StateError('Monetix not initialized. Call initialize() first.');
    }
    return _statusInstance!;
  }

  /// The global [IAdAnalytics] instance.
  static IAdAnalytics get analytics {
    if (_analyticsInstance == null) {
      throw StateError('Monetix not initialized. Call initialize() first.');
    }
    return _analyticsInstance!;
  }

  /// Safely resolves a dependency from [context] using Provider,
  /// or falls back to the static global instance if not found in the widget tree.
  static T _resolve<T>(BuildContext context, T staticInstance) {
    try {
      return Provider.of<T>(context, listen: false);
    } catch (_) {
      return staticInstance;
    }
  }

  /// Safely resolves [MonetizationGate] with reactivity if in Provider.
  static MonetizationGate getGate(BuildContext context, {bool listen = false}) {
    try {
      return Provider.of<MonetizationGate>(context, listen: listen);
    } catch (_) {
      return gate;
    }
  }

  /// Safely resolves [IAdStatusProvider] with reactivity if in Provider.
  static IAdStatusProvider getStatus(BuildContext context, {bool listen = false}) {
    try {
      return Provider.of<IAdStatusProvider>(context, listen: listen);
    } catch (_) {
      return status;
    }
  }

  /// Safely resolves [IAdConfigProvider] with reactivity if in Provider.
  static IAdConfigProvider getConfig(BuildContext context, {bool listen = false}) {
    try {
      return Provider.of<IAdConfigProvider>(context, listen: listen);
    } catch (_) {
      return config;
    }
  }

  /// Safely resolves [IAdAnalytics].
  static IAdAnalytics getAnalytics(BuildContext context) {
    return _resolve<IAdAnalytics>(context, analytics);
  }

  /// Safely resolves [MonetizationService].
  static MonetizationService getService(BuildContext context) {
    return _resolve<MonetizationService>(context, instance);
  }

  /// Safely resolves [RewardedMonetizationService] with reactivity if in Provider.
  static RewardedMonetizationService getRewarded(BuildContext context, {bool listen = false}) {
    try {
      return Provider.of<RewardedMonetizationService>(context, listen: listen);
    } catch (_) {
      return rewarded;
    }
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
    bool enableRewardedBreak = true,
  }) async {
    final configProvider = config ?? SimpleAdConfig(
      bannerAdUnitId: bannerId,
      interstitialAdUnitId: interstitialId,
      rewardedAdUnitId: rewardedId,
      nativeAdUnitId: nativeId,
      adsEnabled: adsEnabled,
      enableRewardedBreak: enableRewardedBreak,
      testDeviceIds: testDeviceIds,
    );

    final analyticsService = analytics ?? ConsoleAdAnalytics();
    final statusProvider = status ?? BasicAdStatus();

    _configInstance = configProvider;
    _analyticsInstance = analyticsService;
    _statusInstance = statusProvider;

    _rewardedInstance = RewardedMonetizationService(
      configProvider,
      statusProvider: statusProvider,
      analyticsService: analyticsService,
    );

    _instance = MonetizationService(
      configProvider,
      statusProvider: statusProvider,
      analyticsService: analyticsService,
      rewardedAdService: _rewardedInstance,
    );

    _gateInstance = MonetizationGate(
      configProvider: configProvider,
      statusProvider: statusProvider,
      rewardedService: _rewardedInstance!,
    );

    _instance!.gate = _gateInstance;
    _rewardedInstance!.gate = _gateInstance;

    await _instance!.init();
  }
}
