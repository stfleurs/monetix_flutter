import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';
import '../interfaces/i_ad_analytics.dart';
import '../interfaces/i_ad_config_provider.dart';
import '../interfaces/i_ad_status_provider.dart';
import 'monetization_gate.dart';
import 'monetization_service.dart';
import 'monetix_request_coordinator.dart';
import 'rewarded_monetization_service.dart';
import 'simple_implementations.dart';
import 'diagnostic_ad_analytics.dart';

/// The lifecycle and synchronization state of the Monetix framework.
enum MonetixState {
  /// The framework has not been prepared or bootstrapped yet.
  uninitialized,

  /// The singletons have been synchronously registered and are safe to access,
  /// but third-party SDKs (such as GMA or UMP) are not yet initialized.
  bootstrapped,

  /// The asynchronous consent and SDK initialization flow is currently in progress.
  initializing,

  /// The framework has successfully completed initialization and is fully ready.
  ready,

  /// The initialization failed or timed out. The framework operates in degraded/fallback mode.
  failed,
}

/// A facade to simplify the setup and orchestration of the monetization system.
class Monetix {
  static MonetizationService? _instance;
  static RewardedMonetizationService? _rewardedInstance;
  static MonetizationGate? _gateInstance;
  static MonetixRequestCoordinator? _coordinatorInstance;

  static IAdConfigProvider? _configInstance;
  static IAdStatusProvider? _statusInstance;
  static IAdAnalytics? _analyticsInstance;

  static MonetixState _state = MonetixState.uninitialized;

  /// Internal flag used to suppress direct construction warnings during bootstrap.
  static bool isInternalConstruction = false;

  /// Returns the current lifecycle state of the Monetix framework.
  static MonetixState get state => _state;

  /// Returns true if the framework has successfully completed its asynchronous initialization.
  static bool get isReady => _state == MonetixState.ready;

  /// A future that completes when the asynchronous initialization has finished
  /// (either successfully or with a timeout/failure).
  static Future<void> get ready {
    if (_instance == null || _state == MonetixState.ready || _state == MonetixState.failed) {
      return Future.value();
    }
    return _instance!.initialized;
  }

  /// The global [MonetizationService] instance.
  static MonetizationService get instance {
    if (_instance == null) {
      throw StateError('Monetix not initialized. Call initialize() or bootstrap() first.');
    }
    return _instance!;
  }

  /// The global [RewardedMonetizationService] instance.
  static RewardedMonetizationService get rewarded {
    if (_rewardedInstance == null) {
      throw StateError('Monetix not initialized. Call initialize() or bootstrap() first.');
    }
    return _rewardedInstance!;
  }

  /// The global [MonetizationGate] instance.
  static MonetizationGate get gate {
    if (_gateInstance == null) {
      throw StateError('Monetix not initialized. Call initialize() or bootstrap() first.');
    }
    return _gateInstance!;
  }

  /// The global [MonetixRequestCoordinator] instance.
  static MonetixRequestCoordinator get coordinator {
    if (_coordinatorInstance == null) {
      throw StateError('Monetix not initialized. Call initialize() or bootstrap() first.');
    }
    return _coordinatorInstance!;
  }

  /// The global [IAdConfigProvider] instance.
  static IAdConfigProvider get config {
    if (_configInstance == null) {
      throw StateError('Monetix not initialized. Call initialize() or bootstrap() first.');
    }
    return _configInstance!;
  }

  /// The global [IAdStatusProvider] instance.
  static IAdStatusProvider get status {
    if (_statusInstance == null) {
      throw StateError('Monetix not initialized. Call initialize() or bootstrap() first.');
    }
    return _statusInstance!;
  }

  /// The global [IAdAnalytics] instance.
  static IAdAnalytics get analytics {
    if (_analyticsInstance == null) {
      throw StateError('Monetix not initialized. Call initialize() or bootstrap() first.');
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

  /// Returns a structured debug snapshot of the coordinator's request metrics.
  /// Useful for debugging, QA screenshots, and verifying burst suppression.
  ///
  /// Returns `null` if Monetix has not been bootstrapped.
  static Map<String, dynamic>? debugMetrics() {
    if (_coordinatorInstance == null) return null;
    return _coordinatorInstance!.metrics.toMap();
  }

  /// Wires externally-created instances into the static facade, allowing
  /// the debug panel and coordinator to reference them without going through
  /// Provider.  Call this after creating your Provider tree.
  ///
  /// Unlike [bootstrap], this does not create new instances — it adopts
  /// the ones you pass in.  Safe to call multiple times; subsequent calls
  /// are no-ops after the first.
  static void wire({
    required MonetizationService service,
    required RewardedMonetizationService rewarded,
    required MonetizationGate gate,
    required IAdConfigProvider config,
    required IAdStatusProvider status,
    required IAdAnalytics analytics,
    MonetixRequestCoordinator? coordinator,
  }) {
    if (_state != MonetixState.uninitialized) return;

    _instance = service;
    _rewardedInstance = rewarded;
    _gateInstance = gate;
    _configInstance = config;
    _statusInstance = status;
    _analyticsInstance = analytics;
    _coordinatorInstance = coordinator ?? MonetixRequestCoordinator();

    _state = MonetixState.bootstrapped;
  }

  /// Synchronously bootstraps and prepares all singleton instances.
  /// This registers all core services synchronously to prevent `StateError`s during startup.
  static void bootstrap({
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
    bool usePauseAdsPill = false,
  }) {
    if (_state != MonetixState.uninitialized) return;

    final configProvider = config ?? SimpleAdConfig(
      bannerAdUnitId: bannerId,
      interstitialAdUnitId: interstitialId,
      rewardedAdUnitId: rewardedId,
      nativeAdUnitId: nativeId,
      adsEnabled: adsEnabled,
      enableRewardedBreak: enableRewardedBreak,
      usePauseAdsPill: usePauseAdsPill,
      testDeviceIds: testDeviceIds,
    );

    IAdAnalytics analyticsService = analytics ?? ConsoleAdAnalytics();
    
    // Automatically wrap analytics for diagnostics in debug mode
    assert(() {
      analyticsService = DiagnosticAdAnalytics(analyticsService);
      return true;
    }());
    
    final statusProvider = status ?? BasicAdStatus();

    _configInstance = configProvider;
    _analyticsInstance = analyticsService;
    _statusInstance = statusProvider;
    _coordinatorInstance = MonetixRequestCoordinator();

    isInternalConstruction = true;
    try {
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
        coordinator: _coordinatorInstance,
      );

      _instance!.gate = _gateInstance;
      _rewardedInstance!.gate = _gateInstance;
    } finally {
      isInternalConstruction = false;
    }

    _state = MonetixState.bootstrapped;
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
    bool usePauseAdsPill = false,
  }) async {
    if (_state == MonetixState.uninitialized) {
      bootstrap(
        config: config,
        status: status,
        analytics: analytics,
        bannerId: bannerId,
        interstitialId: interstitialId,
        rewardedId: rewardedId,
        nativeId: nativeId,
        testDeviceIds: testDeviceIds,
        adsEnabled: adsEnabled,
        enableRewardedBreak: enableRewardedBreak,
        usePauseAdsPill: usePauseAdsPill,
      );
    }

    if (_state == MonetixState.ready) return;

    _state = MonetixState.initializing;
    try {
      await _instance!.init();
      if (_instance!.isInitialized) {
        _state = MonetixState.ready;
      } else {
        _state = MonetixState.failed;
      }
    } catch (_) {
      _state = MonetixState.failed;
      rethrow;
    }
  }
}
