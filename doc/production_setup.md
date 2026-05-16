# Advanced Production Setup

This guide walks you through a full-scale production implementation of Monetix, integrating with **RevenueCat** (for premium states), **Firebase Remote Config** (for dynamic orchestration), and custom analytics.

## 1. Implement the Core Interfaces

Monetix is interface-driven. To link it to your existing services, you must implement the three core providers.

### IAdStatusProvider (e.g. RevenueCat)
This provider tells Monetix whether the current user should see ads.

```dart
class MyPremiumStatus extends ChangeNotifier implements IAdStatusProvider {
  bool _isPremium = false;
  final _controller = StreamController<bool>.broadcast();

  @override bool get isPremium => _isPremium;
  @override Stream<bool> get premiumStatusStream => _controller.stream;

  void onSubscriptionChanged(bool isPremium) {
    _isPremium = isPremium;
    _controller.add(isPremium);
    notifyListeners(); // This instantly suppresses ads across the app
  }

  // Implement other labels for localization...
  @override String get pauseAdsLabel => "Pause Ads";
  // ...
}
```

### IAdConfigProvider (e.g. Remote Config)
This provider manages your ad unit IDs and orchestration policies.

```dart
class MyAdConfig extends ChangeNotifier implements IAdConfigProvider {
  @override String? get bannerAdUnitId => remoteConfig.getString('ad_banner_id');
  @override bool get adsEnabled => remoteConfig.getBool('ads_enabled');
  
  // You can tune rewards and cooldowns live from the cloud
  @override Duration get rewardAdFreeDuration => Duration(minutes: remoteConfig.getInt('reward_mins'));
  
  // ...
}
```

## 2. Wire Up the Provider Tree

Monetix uses `Provider` for dependency injection. We recommend using `ListenableProxyProvider` to ensure the UI reacts instantly to state changes.

```dart
MultiProvider(
  providers: [
    // 1. Your status provider
    ChangeNotifierProvider<MyPremiumStatus>(create: (_) => MyPremiumStatus()),
    ListenableProxyProvider<MyPremiumStatus, IAdStatusProvider>(
      update: (_, status, __) => status,
    ),

    // 2. Your config provider
    ChangeNotifierProvider<MyAdConfig>(create: (_) => MyAdConfig()),
    ListenableProxyProvider<MyAdConfig, IAdConfigProvider>(
      update: (_, config, __) => config,
    ),

    // 3. Analytics
    Provider<IAdAnalytics>(create: (_) => MyAnalytics()),

    // 4. Rewarded Ad Service
    ChangeNotifierProxyProvider2<IAdConfigProvider, IAdAnalytics, RewardedMonetizationService>(
      create: (ctx) => RewardedMonetizationService(
        ctx.read<IAdConfigProvider>(),
        statusProvider: ctx.read<IAdStatusProvider>(),
        analyticsService: ctx.read<IAdAnalytics>(),
      ),
      update: (_, __, ___, prev) => prev!,
    ),

    // 5. Main Orchestrator
    Provider<MonetizationService>(
      create: (ctx) {
        final svc = MonetizationService(
          ctx.read<IAdConfigProvider>(),
          statusProvider: ctx.read<IAdStatusProvider>(),
          analyticsService: ctx.read<IAdAnalytics>(),
          rewardedAdService: ctx.read<RewardedMonetizationService>(),
        );
        svc.init();
        return svc;
      },
    ),
  ],
  child: MyApp(),
)
```

## 3. Benefits of this Architecture

*   **Reactive Ads**: Ads disappear the millisecond a user subscribes.
*   **Zero Logic in UI**: Your widgets don't need to know about RevenueCat or Remote Config; they just use `MonetizedNativeAd`.
*   **Testability**: You can swap `MyPremiumStatus` for a mock during integration tests.
