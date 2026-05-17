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
