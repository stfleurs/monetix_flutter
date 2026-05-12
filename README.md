# Monetix Flutter

**Monetix Flutter** is a production-ready monetization policy layer for Flutter apps. It goes beyond simple ad wrappers by orchestrating the relationship between ads, premium features, user consent, and rewarded incentives.

## Why Monetix?

Most ad packages only provide widgets. Monetix provides a **policy layer** that helps you:
- **Balance Revenue & UX**: Automatically suppress ads for premium users or during temporary "ad-free breaks."
- **Resilient Fallbacks**: `MonetizedNativeAd` automatically falls back to standard Banners if high-value Native ads fail to load.
- **Incentivized Retention**: Built-in logic for a "15-minute ad-free break" flow, encouraging users to watch rewarded ads to reduce frustration.
- **Decoupled Architecture**: Use the interface-driven design to plug in your own analytics, remote configuration, and localization without scattering ad logic across your UI.

## Features

- **Shield: Smart Native Ads**: High-performance native ads with automatic banner fallbacks and unified styling.
- **Gift: Rewarded Ad-Free Breaks**: Out-of-the-box logic for temporary ad suppression, including persistence, rate limiting, and cooldowns.
- **Scale: Policy Orchestration**: Centralized management of premium status, UMP consent, and feature toggles.
- **Chart: Deep Analytics Hooks**: Built-in interfaces for logging requests, impressions, failures, and revenue to any backend.
- **Globe: Localization-Agnostic**: All UI strings are provided through providers, ensuring zero dependencies on your app's l10n system.

## Getting Started

### 1. Add dependency

```yaml
dependencies:
  monetix_flutter:
    path: ./packages/monetix_flutter
```

### 2. Implementation Modes

#### Quick Mode (Simple)
Ideal for testing or smaller apps. Uses default console logging and simple ID configuration.

```dart
await Monetix.initialize(
  bannerId: 'ca-app-pub-3940256099942544/6300978111',
  interstitialId: 'ca-app-pub-3940256099942544/1033173712',
  rewardedId: 'ca-app-pub-3940256099942544/5224354917',
  nativeId: 'ca-app-pub-3940256099942544/2247696110',
);

// Access services globally
final ads = Monetix.instance;
final rewards = Monetix.rewarded;
```

#### Advanced Mode (Interface-Driven)
The recommended way for production apps. Implement the core interfaces to link your own services.

```dart
class MyAdConfig extends IAdConfigProvider { ... }
class MyAdAnalytics extends IAdAnalytics { ... }
class MyAdStatus extends IAdStatusProvider { ... }

await Monetix.initialize(
  config: MyAdConfig(),
  analytics: MyAdAnalytics(),
  status: MyAdStatus(),
);
```

### 3. Use Widgets

```dart
MonetizedNativeAd(
  screen: 'home',
  placement: 'feed_top',
  templateType: TemplateType.small,
)
```

## Example App

Check out the `example/` directory for a full demonstration of the "Ad-Free Break" flow, native fallbacks, and reactive premium suppression.

## License

MIT
