# Monetix Flutter

[![pub package](https://img.shields.io/pub/v/monetix_flutter.svg)](https://pub.dev/packages/monetix_flutter)
[![likes](https://img.shields.io/pub/likes/monetix_flutter.svg)](https://pub.dev/packages/monetix_flutter/score)
[![popularity](https://img.shields.io/pub/popularity/monetix_flutter.svg)](https://pub.dev/packages/monetix_flutter/score)
[![license](https://img.shields.io/github/license/stfleurs/monetix_flutter.svg)](https://github.com/stfleurs/monetix_flutter/blob/main/LICENSE)

**The Monetization Orchestration Ecosystem for Flutter.**

Monetix is not just an ad SDK wrapper — it's a policy-driven orchestration layer that manages the complex relationship between your revenue strategy, your user experience, and your premium states.

---

## ⏱️ 30-Second Integration

Monetix works out of the box, but becomes exponentially more powerful when connected to your premium state and remote config systems. To start simple:

```dart
MonetizedBannerAd(
  screen: 'home',
  placement: 'footer',
)
```

---

## Core Philosophy

> **Monetix treats monetization as a product system — not just an implementation detail.**

The goal is to maximize long-term revenue without degrading user experience. We believe that a happy user is a more valuable user, which is why Monetix prioritizes policy-driven ad suppression and incentivized "ad-free breaks" over mindless ad frequency.

---

## Best For

Monetix is ideal for:
- freemium apps,
- utility apps,
- content apps,
- apps with subscriptions + ads,
- apps needing dynamic monetization policies.

Not ideal for:
- extremely simple apps needing only one banner ad.

---

## Real-World Scenario

Orchestration systems become easier to understand through workflows. Here is a typical Monetix scenario:

- **Free users** see ads.
- **Premium users** instantly suppress ads.
- **Rewarded users** get 15 ad-free minutes.
- **Native ads** fallback to banners automatically.
- **Remote config** controls ad frequency.

---

## Showcase

### 📸 Component Gallery
| Playground Home | Rewarded Break | Debug Control Center |
| :---: | :---: | :---: |
| ![Home](media/monetix_home.png) | ![Rewarded](media/monetix_rewarded.png) | ![Debug](media/monetix_debug.png) |

---

## Architecture Overview

Monetix sits as an orchestration layer between your App UI and the underlying Ad Providers.

```mermaid
graph TD
    UI[Flutter App UI] --> EngineNode[Monetix Policy Engine]
    
    subgraph EngineSub ["Monetix Orchestration Layer"]
        Policy[Ad Suppression Policy]
        Rewarded[Rewarded Logic & Cooldowns]
        Consent[UMP Consent Management]
        Fallback[Smart Fallback Orchestrator]
    end
    
    EngineNode --> Analytics[IAdAnalytics]
    EngineNode --> Config[IAdConfigProvider]
    EngineNode --> Status[IAdStatusProvider]
    
    Fallback --> AdMob[Google Mobile Ads]
    Fallback --> Others[Future Provider Support]
```

---

## The "Ad-Free Break" Flow

Our signature feature: Let users "buy" time with a single rewarded ad, reducing fatigue and increasing engagement.

```mermaid
sequenceDiagram
    participant U as User
    participant M as Monetix
    participant P as Ad Provider
    
    U->>M: Request Ad-Free Break
    M->>M: Check Cooldown & Rate Limits
    alt Is Blocked
        M-->>U: Show Cooldown/Limit Message
    else Is Available
        M->>P: Load & Show Rewarded Ad
        P-->>M: Reward Earned
        M->>M: Grant 15-Minute Break
        M->>M: Persist Expiry State
        M-->>U: Notify: Ads Suppressed
    end
    
    Note over U,M: All Native/Banner ads are now hidden
```

---

## Why Monetix?

Most ad packages are just widget wrappers. Monetix is a **strategy engine** that lets you define *how* and *when* ads appear based on real-time app state.

### Why not just use Google Mobile Ads directly?

| Problem | Raw AdMob | Monetix |
| --- | --- | --- |
| **Premium suppression** | Manual | Built-in |
| **Rewarded cooldowns** | Manual | Built-in |
| **Ad-free breaks** | Manual | Built-in |
| **Centralized policies** | ❌ | ✅ |
| **Runtime monetization config** | Limited | ✅ |

### Problems Monetix Solves
- 🍝 **Scattered Logic**: No more ad checks and premium suppression scattered across your UI.
- 📉 **Revenue Leakage**: `MonetizedNativeAd` automatically falls back to Banners if high-value Native ads fail.
- 😫 **User Frustration**: Handles the complex logic of rewarded breaks, rate limits, and cooldowns out of the box.
- 🔓 **Provider Lock-in**: Interface-driven design lets you swap or mock providers (AdMob, RevenueCat, Custom) easily.

---

## Onboarding Paths

### Path 1: Simple Setup (5 minutes)
Ideal for basic apps with minimal config.

#### 1. Install

```yaml
dependencies:
  monetix_flutter: ^0.1.2
```

#### 2. Initialize

```dart
import 'package:monetix_flutter/monetix_flutter.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  await Monetix.initialize(
    bannerId: 'ca-app-pub-...',
    nativeId: 'ca-app-pub-...',
  );

  runApp(const MyApp());
}
```

#### 3. Add Widgets

```dart
MonetizedBannerAd(screen: 'home', placement: 'footer')
```

---

### Path 2: Production Setup
Ideal for apps with RevenueCat, Firebase Remote Config, analytics, and complex orchestration.

#### 1. Install

```yaml
dependencies:
  monetix_flutter: ^0.1.2
```

### 2. Implement the Interfaces

Create a class that implements `IAdStatusProvider` (e.g., wrapping RevenueCat) and `IAdConfigProvider` (e.g., wrapping Firebase Remote Config).

Both interfaces extend `Listenable`, so your implementation **must** also extend `ChangeNotifier` (or another `Listenable`) to enable reactive UI updates.

```dart
class MyPremiumStatus extends ChangeNotifier implements IAdStatusProvider {
  bool _isPremium = false;
  final _controller = StreamController<bool>.broadcast();

  @override bool get isPremium => _isPremium;
  @override Stream<bool> get premiumStatusStream => _controller.stream;

  void onSubscriptionChanged(bool isPremium) {
    _isPremium = isPremium;
    _controller.add(isPremium);
    notifyListeners(); // Triggers UI rebuild
  }

  // ... implement remaining label/string getters
}
```

### 3. Wire Up the Provider Tree

Use `ListenableProxyProvider` to expose your implementations as the Monetix interfaces. This is what enables **reactive premium suppression** — ads disappear the instant `notifyListeners()` is called.

```dart
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  Provider.debugCheckInvalidValueType = null; // Required for interface injection
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        // 1. Your status provider (e.g. RevenueCat)
        ChangeNotifierProvider<MyPremiumStatus>(
          create: (_) => MyPremiumStatus(),
        ),
        // Expose as interface — use ListenableProxyProvider for reactivity
        ListenableProxyProvider<MyPremiumStatus, IAdStatusProvider>(
          update: (_, status, __) => status,
        ),

        // 2. Your config provider (e.g. Firebase Remote Config)
        ChangeNotifierProvider<MyAdConfig>(
          create: (_) => MyAdConfig(),
        ),
        ListenableProxyProvider<MyAdConfig, IAdConfigProvider>(
          update: (_, config, __) => config,
        ),

        // 3. Analytics (optional)
        Provider<IAdAnalytics>(create: (_) => ConsoleAdAnalytics()),

        // 4. Rewarded Ad Service
        ChangeNotifierProxyProvider2<MyAdConfig, IAdAnalytics, RewardedMonetizationService>(
          create: (ctx) => RewardedMonetizationService(
            ctx.read<MyAdConfig>(),
            analyticsService: ctx.read<IAdAnalytics>(),
          ),
          update: (_, __, ___, prev) => prev!,
        ),

        // 5. Main Orchestrator
        Provider<MonetizationService>(
          create: (ctx) {
            final svc = MonetizationService(
              ctx.read<MyAdConfig>(),
              statusProvider: ctx.read<MyPremiumStatus>(),
              analyticsService: ctx.read<IAdAnalytics>(),
              rewardedAdService: ctx.read<RewardedMonetizationService>(),
            );
            svc.init();
            return svc;
          },
        ),
      ],
      child: MaterialApp(home: MyHomePage()),
    );
  }
}
```

### 4. Add Widgets

```dart
// Automatically hides when user is premium or in an ad-free break
MonetizedNativeAd(screen: 'home', placement: 'main_feed')

// Standalone banner (falls back gracefully if native fails)
MonetizedBannerAd(screen: 'home', placement: 'footer')
```

---

## Implementation Modes

### ⚡ Quick Mode
Ideal for testing or simple apps. Uses default console logging and in-memory status.

### 🛠️ Advanced Mode
For production apps. Implement the core interfaces to link your own services:
- **Remote Config**: Manage IDs and frequencies remotely.
- **Analytics**: Connect Firebase, Mixpanel, or Amplitude.
- **RevenueCat**: React to subscription states instantly.

---

## Monetix Playground

The `/example` directory contains an **Interactive Showcase App** demonstrating:
- **Reactive Premium Suppression**: Watch ads disappear instantly when status changes.
- **Smart Fallbacks**: Native ads transitioning to Banners seamlessly.
- **Incentivized Flow**: A fully working "Ad-Free Break" sheet.
- **Debug Control Center**: Toggle states live to test your app's behavior.

## License

MIT
