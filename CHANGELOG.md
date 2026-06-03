## 0.2.3
- **CI/CD Reliability**: Fixed `CHANGELOG.md` parsing and strict `pub.dev` analyzer lint validation for deprecated `AdSize` method calls.
- **Documentation**: Updated `README.md` dependency versions.

## 0.2.2
- **Hotfix**: Resolved internal CI strict-validation errors triggered by upstream `google_mobile_ads` `8.0.0` deprecations by intentionally suppressing them for maximum backward compatibility.

## 0.2.1
- **Architectural Stability**: Fixed multiple race conditions and `Completer` leaks during offline initialization, guaranteeing `_initFuture` safely unblocks retries.
- **Data Integrity**: Enforced explicit `int` casting on `clamp()` operands in `RewardedMonetizationService` to prevent `num` type casting errors.
- **Memory Leak Fix**: Resolved `ChangeNotifier` listener accumulation in `MonetixDebugPanel` caused by missing unregister logic during rapid widget `didChangeDependencies` updates.
- **UI Gracefulness**: Replaced permanent loading spinners in `MonetizedNativeAd` with `SizedBox.shrink()` when an ad permanently fails to load.
- **Testing Rigor**: Introduced a rigorous automated regression suite covering offline startups, premium suppressions, listener deduplication, gate injections, and coordinator anti-spam logic.

## 0.2.0
- **Request Burst Prevention**: Added `MonetixRequestCoordinator` — a global scheduler that debounces gate cascades, deduplicates same-type requests, and enforces per-ad-type minimum spacing. Exposes `Monetix.debugMetrics()` for observability.
- **Native Fallback Redesign**: Fallback banner now only loads when the native ad explicitly fails, not pre-emptively after a 5s timer. The safety timer is cancellable and cleaned up on widget disposal. Prevents guaranteed double-requests under moderate latency.
- **Interstitial Jittered Cooldown**: All reload paths use a 2-5s jittered delay with a cancellable `Timer` instead of immediate `loadInterstitialAd()`. Timer is cancelled on premium unlock, config disable, and service disposal.
- **Gate Cascade Debouncing**: `MonetizationGate._onStateChanged()` uses a 50ms debounce timer to coalesce rapid state changes from config, premium, and rewarded sources into a single notification.
- **Debug Panel Overhaul**: `MonetixDebugPanel` now inherits the host app's color scheme and includes mutation toggles for Global Ads Enabled, Simulate Native Failure, and Enable Rewarded Break. Timeline log renders when `DiagnosticAdAnalytics` is used.
- **Debug Interface Hooks**: Added `setPremiumForDebug()` to `IAdStatusProvider` and `setAdsEnabledForDebug()` / `setSimulateNativeFailureForDebug()` / `setEnableRewardedBreakForDebug()` to `IAdConfigProvider` — no-op by default, overridable by any implementation.
- **Monetix.wire()**: New static method to adopt externally-created instances into the static facade for Provider-heavy setups.
- **DiagnosticAdAnalytics**: `IAdAnalytics` wrapper that maintains a 50-entry circular buffer of monetization events for the debug timeline.

## 0.1.9
- **Non-Blocking Initialization**: Restructured setup into synchronous `Monetix.bootstrap(...)` and asynchronous `Monetix.initialize(...)` to resolve heavy startup bottlenecks and Android `DeadObjectException` emulator crashes.
- **State & Readiness Engine**: Introduced `MonetixState` enum and `state`, `isReady`, and `ready` future properties to natively support offline fallback and graceful degraded ad states.
- **Developer Safety Guards**: Added debug construction warning messages to notify developers who directly instantiate the underlying services instead of using the facade.
- **Unit Testing Improvements**: Stabilized unit testing mock channels using custom message codecs to avoid type-cast and `FormatException` errors.

## 0.1.8
- **CI/CD Fix**: Integrated `dart-lang/setup-dart` into the workflow to securely configure OpenID Connect (OIDC) token handshake variables, resolving hanging authorization requests.

## 0.1.7
- **CI/CD Fix**: Corrected the GitHub Actions glob trigger pattern to `'v*'` so that automated OIDC publishing executes successfully on tag push events.

## 0.1.6
- **Automated OIDC Publishing**: Added robust pre-publish validation checks (`flutter analyze`, `flutter test`, and `flutter pub publish --dry-run`) to our OIDC GitHub Actions pipeline.
- **Release Playbook**: Added a comprehensive `RELEASE_CHECKLIST.md` in the package root to enforce standardized release procedures.

## 0.1.5
- **Hybrid Resolution**: Decoupled package widgets from strict Provider injection tree requirements, integrating robust fallback resolution to facade singletons.
- **Dynamic Background Suppression**: Services dynamically monitor Remote Config / premium updates, immediately cancelling active background loads and disposing of ad cache on disable.
- **Bandwidth-Friendly Fallbacks**: Migrated Native fallback Banner ad loads to occur lazily upon Native ad failure or timeout (5 seconds).
- **Safety Guards**: Implemented `_isLoading` guard on Banner ads to prevent duplicate/concurrent request storms under rapid rebuilds.
- **Improved Portability**: Relaxed package dependency constraint to `google_mobile_ads: ">=7.0.0 <9.0.0"` and migrated anchored adaptive banner sizes to a highly portable API compatible across all versions.

## 0.1.4
- **Developer Tools**: Added `MonetixDebugPanel`, `MonetixDebugButton`, and `MonetixAdminGate` for easier production testing.
- **Flexibility**: Added `enableRewardedBreak` toggle to globally disable the rewarded ad break feature.
- **Reactivity**: Made `SimpleAdConfig` and `BasicAdStatus` mutable to support live configuration updates during testing.
- **UI/UX**: Improved Reward Status Sheet layout with a more prominent "Premium" upgrade path.
- **Documentation**: Restructured docs into a layered system with a streamlined README and a new `/docs` folder for advanced setups.
- **Fixes**: Corrected missing `statusProvider` wire-up in `Monetix.initialize`.

## 0.1.3
- **Documentation**: Substantial README overhaul. Added "30-Second Integration" guide, comparison with raw AdMob, and split onboarding paths for Simple vs Production setups.

## 0.1.2
- **Dependencies**: Update `google_mobile_ads` to `^8.0.0` and `connectivity_plus` to `^7.1.1`.
- **Maintenance**: Fix linting warnings including the deprecated `getCurrentOrientationAnchoredAdaptiveBannerAdSize` and missing block enclosures.

## 0.1.1
- **Stable Release**: First feature-complete production-ready release.
- **Orchestrated Fallback Readiness**: Parallel loading of native ads and banner fallbacks for instant, zero-delay switching.
- **Enhanced Debug Simulation**: Added `simulateNativeFailure` to `IAdConfigProvider` for easier testing of fallback flows.
- **Improved Reactivity**: Native ads now respond instantly to debug simulation toggles in real-time.

## 0.0.1

* Initial release of **Monetix Flutter**.
* Production-ready monetization policy layer for Google Mobile Ads.
* Configurable rewarded "ad-free break" logic with rate limiting and cooldowns.
* Smart Native-to-Banner fallback orchestration.
* Zero-dependency localization and reactive state management.
* Quick Mode facade (`Monetix`) for simple initialization.
* Professional example app and unit tests for rewarded logic.
