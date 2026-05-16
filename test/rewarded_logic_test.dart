import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monetix_flutter/monetix_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MockConfig extends ChangeNotifier implements IAdConfigProvider {
  @override String? get bannerAdUnitId => null;
  @override String? get interstitialAdUnitId => null;
  @override String? get rewardedAdUnitId => null;
  @override String? get nativeAdUnitId => null;
  @override bool get adsEnabled => true;
  @override List<String> get testDeviceIds => [];
  
  @override Duration get rewardAdFreeDuration => const Duration(minutes: 15);
  @override bool get enableRewardedBreak => true;
  @override int get maxAdsPerRateLimitWindow => 2;
  @override Duration get rateLimitWindowDuration => const Duration(hours: 1);
  @override Duration get cooldownBetweenAdsDuration => const Duration(seconds: 35);
  @override bool get simulateNativeFailure => false;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  
  // Mock Connectivity
  const MethodChannel channel = MethodChannel('dev.fluttercommunity.plus/connectivity');
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, (MethodCall methodCall) async {
    if (methodCall.method == 'check') return ['wifi'];
    return null;
  });

  // Mock Google Mobile Ads
  const MethodChannel adsChannel = MethodChannel('plugins.flutter.io/google_mobile_ads');
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(adsChannel, (MethodCall methodCall) async {
    return null;
  });

  group('RewardedMonetizationService Logic', () {
    late RewardedMonetizationService service;
    late MockConfig config;
    late DateTime mockTime;

    setUp(() {
      config = MockConfig();
      mockTime = DateTime(2026, 1, 1, 12, 0, 0);
      SharedPreferences.setMockInitialValues({});
    });

    test('Initial state: not ad-free, can watch ad', () async {
      service = RewardedMonetizationService(
        config, 
        autoLoad: false, // Skip auto-load for tests
        nowProvider: () => mockTime,
      );
      await service.initialized;
      
      expect(service.isAdFree, false);
      expect(service.canWatchAd, true);
      expect(service.blockReason, null);
    });

    test('Ad-free status from SharedPreferences', () async {
      final expiry = mockTime.add(const Duration(minutes: 10)).millisecondsSinceEpoch;
      SharedPreferences.setMockInitialValues({
        'rewarded_ad_expiry_ms': expiry,
      });

      service = RewardedMonetizationService(
        config, 
        autoLoad: false, 
        nowProvider: () => mockTime,
      );
      await service.initialized;

      expect(service.isAdFree, true);
      expect(service.remainingTime?.inMinutes, 10);
    });

    test('Rate limiting logic', () async {
      // Simulate 2 watches in the last hour
      final watch1 = mockTime.subtract(const Duration(minutes: 40)).millisecondsSinceEpoch;
      final watch2 = mockTime.subtract(const Duration(minutes: 10)).millisecondsSinceEpoch;
      
      SharedPreferences.setMockInitialValues({
        'rewarded_ad_watch_times': '$watch1,$watch2',
      });

      service = RewardedMonetizationService(
        config, 
        autoLoad: false, 
        nowProvider: () => mockTime,
      );
      await service.initialized;

      expect(service.adsWatchedThisHour, 2);
      expect(service.canWatchAd, false);
      expect(service.blockReason, RewardBlockReason.rateLimited);
    });

    test('Cooldown logic', () async {
      // Only 1 watch, but very recent (10 seconds ago)
      final watch1 = mockTime.subtract(const Duration(seconds: 10)).millisecondsSinceEpoch;
      
      SharedPreferences.setMockInitialValues({
        'rewarded_ad_watch_times': '$watch1',
      });

      service = RewardedMonetizationService(
        config, 
        autoLoad: false, 
        nowProvider: () => mockTime,
      );
      await service.initialized;

      expect(service.canWatchAd, false);
      expect(service.blockReason, RewardBlockReason.cooldown);
      
      // Advance time past cooldown (35s)
      mockTime = mockTime.add(const Duration(seconds: 30)); 
      expect(service.canWatchAd, true); // (10s + 30s = 40s > 35s)
    });
  });
}
