# Monetix Architecture & Logic

This document dives deep into how Monetix manages the complex relationship between ads, rewards, and fallbacks.

## The Policy Engine

Monetix uses a "Policy-First" approach. Every ad widget checks the global policy before attempting to load.

### Ad Suppression Logic
The formula for whether an ad should be hidden is:
`shouldHide = statusProvider.isPremium || rewardedService.isAdFree || !configProvider.adsEnabled`

This logic is centralized so you don't have to repeat it in every screen.

## Smart Fallback System

One of Monetix's most powerful features is the automatic fallback from Native to Banner ads.

### Why Fallbacks?
Native ads have higher CPM but lower fill rates and can fail for various reasons (network, inventory, etc.). Banner ads have nearly 100% fill rates but lower CPM.

### How it Works
1.  `MonetizedNativeAd` requests a high-value Native ad.
2.  In parallel, it prepares a fallback Banner ad.
3.  If the Native ad fails (or times out), the widget seamlessly switches to the preloaded Banner ad.
4.  This ensures you never have "empty holes" in your UI while still maximizing revenue.

## Rewarded Break Logic

The "Ad-Free Break" system manages its own state and persistence.

### Persistence
Monetix uses `shared_preferences` to persist the expiry time of an ad-free break. This means if a user earns 15 minutes of no ads and closes the app, the countdown continues correctly when they return.

### Rate Limiting & Cooldowns
To prevent users from "farming" rewarded ads and hurting your CPM/User Experience, Monetix includes built-in limits:
*   **Cooldown**: Minimum time between watching two rewarded ads.
*   **Rate Limit**: Maximum number of rewarded ads allowed in a specific window (e.g., 2 ads per hour).

These are all configurable via `IAdConfigProvider`.
