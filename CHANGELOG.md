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
