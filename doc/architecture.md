# Monetix Architecture & Logic

This document dives deep into how Monetix manages the complex relationship between ads, rewards, and fallbacks.

## The Policy Engine

Monetix uses a centralized **"Policy-First"** approach governed by `MonetizationGate`. Rather than distributing check logic across multiple services or UI widgets, all visibility decisions are consolidated in one orchestrator.

### Centralized Policy Evaluation
The formula for whether ads should be displayed (and whether background services should preload or cache ads) is evaluated as a single policy decision:

*   **`evaluateNative()` & `evaluateBanner()`**: Checks if ads are enabled via remote configurations, verifies that the user is not premium, and checks if rewarded breaks are currently active.
*   **`evaluateRewarded()`**: Verifies that remote config permits rewarded ad-free breaks, and confirms that the user is not currently in premium status (where ads are already fully suppressed).

All services and widgets automatically listen to `MonetizationGate` and instantly dispose of loaded resources in memory if policies change reactively (e.g. if the user purchases premium or if config disables ads).

## Smart Fallback System

One of Monetix's most powerful features is the automatic, bandwidth-friendly fallback from Native to Banner ads.

### Why Fallbacks?
Native ads have higher CPM but lower fill rates and can fail for various reasons (network, inventory, etc.). Banner ads have nearly 100% fill rates but lower CPM.

### How it Works
1.  `MonetizedNativeAd` requests a high-value Native ad.
2.  The fallback Banner ad loading is **deferred lazily**: instead of preloading both in parallel (which wastes network bandwidth and triggers redundant requests), the banner ad is loaded *only* if the Native ad request fails or exceeds the configurable 5-second timeout (`_nativeFallbackTimeout`).
3.  If the config explicitly enables `simulateNativeFailure`, the widget directly loads the fallback Banner ad without even attempting a native load.
4.  This ensures you never have "empty holes" in your UI while keeping network overhead at an absolute minimum.

## Rewarded Break Logic

The "Ad-Free Break" system manages its own state and persistence.

### Persistence
Monetix uses `shared_preferences` to persist the expiry time of an ad-free break. This means if a user earns 15 minutes of no ads and closes the app, the countdown continues correctly when they return.

### Rate Limiting & Cooldowns
To prevent users from "farming" rewarded ads and hurting your CPM/User Experience, Monetix includes built-in limits:
*   **Cooldown**: Minimum time between watching two rewarded ads.
*   **Rate Limit**: Maximum number of rewarded ads allowed in a specific window (e.g., 2 ads per hour).

These are all configurable via `IAdConfigProvider`.
