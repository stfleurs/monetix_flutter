import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monetix_flutter/monetix_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    Monetix.resetForTesting();
    SharedPreferences.setMockInitialValues({});
  });

  tearDown(() {
    Monetix.resetForTesting();
    // Clear mocks
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('dev.fluttercommunity.plus/connectivity'), null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('plugins.flutter.io/google_mobile_ads'), null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('plugins.flutter.io/google_mobile_ads/ump'), null);
  });

  test('ready_before_bootstrap_test: Monetix.ready throws before bootstrap', () async {
    expect(() => Monetix.ready, throwsA(isA<StateError>()));
  });

  test('wire_after_bootstrap_test: wire() updates references if already bootstrapped', () {
    Monetix.bootstrap();
    expect(Monetix.state, MonetixState.bootstrapped);
    final originalGate = Monetix.gate;

    final config = SimpleAdConfig();
    final status = BasicAdStatus();
    final analytics = ConsoleAdAnalytics();
    final rewarded = RewardedMonetizationService(config, statusProvider: status, analyticsService: analytics);
    final service = MonetizationService(config, statusProvider: status, analyticsService: analytics, rewardedAdService: rewarded);
    final gate = MonetizationGate(configProvider: config, statusProvider: status, rewardedService: rewarded);
    
    Monetix.wire(
      service: service,
      rewarded: rewarded,
      gate: gate,
      config: config,
      status: status,
      analytics: analytics,
      coordinator: null,
    );

    expect(Monetix.gate, isNot(equals(originalGate)));
    expect(Monetix.gate, equals(gate));
    expect(Monetix.coordinator, isNotNull);
  });

  test('gate_injection_test: Gate is properly injected and evaluated', () {
    final config = SimpleAdConfig(adsEnabled: false);
    final status = BasicAdStatus();
    final analytics = ConsoleAdAnalytics();
    final rewarded = RewardedMonetizationService(config, statusProvider: status, analyticsService: analytics);
    final service = MonetizationService(config, statusProvider: status, analyticsService: analytics, rewardedAdService: rewarded);
    
    final gate = MonetizationGate(configProvider: config, statusProvider: status, rewardedService: rewarded);
    service.gate = gate;

    final decision = service.gate!.evaluateInterstitial();
    expect(decision.allowed, isFalse);
    expect(decision.reason, equals(AdVisibilityReason.remoteDisabled));
  });

  test('offline_startup_test: Offline startup prevents initialization and clears future for retry', () async {
    final config = SimpleAdConfig();
    final status = BasicAdStatus();
    final analytics = ConsoleAdAnalytics();
    final rewarded = RewardedMonetizationService(config, statusProvider: status, analyticsService: analytics);
    final service = MonetizationService(config, statusProvider: status, analyticsService: analytics, rewardedAdService: rewarded);

    // Mock offline state
    const connectivityChannel = MethodChannel('dev.fluttercommunity.plus/connectivity');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(connectivityChannel, (call) async {
      if (call.method == 'check') return ['none']; // offline
      return null;
    });

    // 1. Attempt init
    final firstInitFuture = service.init();
    await firstInitFuture;
    
    expect(service.isInitialized, isFalse, reason: "Service should not be initialized when offline");

    // 2. Second init attempt (still offline or online, doesn't matter for this proof)
    // The core bug was that _initFuture was never cleared on offline exit.
    // If the bug is fixed, a second init() should return a brand NEW future.
    // If the bug is present, it would return the exact same blocked future.
    final secondInitFuture = service.init();
    
    expect(identical(firstInitFuture, secondInitFuture), isFalse, 
      reason: "Second init() should return a new future because the first offline attempt cleared _initFuture");
      
    // Await it so we don't leak async work in the test runner
    await secondInitFuture;
  });
  
  testWidgets('listener_deduplication_test: MonetixDebugPanel does not leak listeners', (WidgetTester tester) async {
    final config = SimpleAdConfig();
    final status = BasicAdStatus();
    final analytics = ConsoleAdAnalytics();
    final rewarded = RewardedMonetizationService(config, statusProvider: status, analyticsService: analytics);
    
    final gate = MonetizationGate(
      configProvider: config,
      statusProvider: status,
      rewardedService: rewarded,
    );

    final service = MonetizationService(config, statusProvider: status, analyticsService: analytics, rewardedAdService: rewarded);

    Monetix.bootstrap();
    Monetix.wire(
      service: service,
      rewarded: rewarded,
      gate: gate, // Wire our gate
      config: config,
      status: status,
      analytics: analytics,
      coordinator: null,
    );

    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: MonetixDebugPanel()),
    ));

    // Verify it has listeners initially
    // ignore: invalid_use_of_protected_member
    expect(gate.hasListeners, isTrue, reason: 'Debug panel should have listeners registered to the gate');

    // Trigger multiple didChangeDependencies
    // ignore: invalid_use_of_protected_member
    tester.state(find.byType(MonetixDebugPanel)).didChangeDependencies();
    // ignore: invalid_use_of_protected_member
    tester.state(find.byType(MonetixDebugPanel)).didChangeDependencies();
    // ignore: invalid_use_of_protected_member
    tester.state(find.byType(MonetixDebugPanel)).didChangeDependencies();

    await tester.pumpAndSettle();

    // Verify it still has listeners, meaning it didn't unregister without registering
    // ignore: invalid_use_of_protected_member
    expect(gate.hasListeners, isTrue, reason: 'Debug panel should still have listeners registered to the gate');

    // Pump widget out of tree
    await tester.pumpWidget(const SizedBox.shrink());

    // Verify all listeners were cleaned up exactly (no duplicates leaked)
    // ignore: invalid_use_of_protected_member
    expect(gate.hasListeners, isFalse, reason: 'Debug panel should have removed all listeners when disposed');
  });

  test('premium_suppression_test: Active premium status completely suppresses interstitials', () {
    final config = SimpleAdConfig();
    final status = BasicAdStatus();
    final analytics = ConsoleAdAnalytics();
    final rewarded = RewardedMonetizationService(config, statusProvider: status, analyticsService: analytics);
    
    final gate = MonetizationGate(configProvider: config, statusProvider: status, rewardedService: rewarded);
    
    // Default allowed
    expect(gate.evaluateInterstitial().allowed, isTrue);

    // Simulate revenuecat premium activation
    status.isPremium = true;

    final decision = gate.evaluateInterstitial();
    expect(decision.allowed, isFalse);
    expect(decision.reason, equals(AdVisibilityReason.premium));
  });

  test('rewarded_pause_expiration_test: Rewarded pause correctly blocks ads and expires', () {
    final config = SimpleAdConfig();
    final status = BasicAdStatus();
    final analytics = ConsoleAdAnalytics();
    
    DateTime fakeNow = DateTime(2025, 1, 1, 12, 0, 0); // 12:00:00 PM
    final rewarded = RewardedMonetizationService(
      config, 
      statusProvider: status, 
      analyticsService: analytics,
      nowProvider: () => fakeNow,
    );
    
    final gate = MonetizationGate(configProvider: config, statusProvider: status, rewardedService: rewarded);
    
    expect(gate.evaluateInterstitial().allowed, isTrue);
    
    // Grant 5 minutes of ad-free time
    rewarded.grantRewardForTesting(const Duration(minutes: 5));
    
    // Verify ads are blocked
    final decision = gate.evaluateInterstitial();
    expect(decision.allowed, isFalse);
    expect(decision.reason, equals(AdVisibilityReason.rewardedPause));
    
    // Fast forward 6 minutes
    fakeNow = fakeNow.add(const Duration(minutes: 6));
    
    // Verify ads are allowed again
    expect(gate.evaluateInterstitial().allowed, isTrue);
  });

  test('coordinator_throttling_test: Request coordinator properly throttles consecutive identical ads', () async {
    final coordinator = MonetixRequestCoordinator();
    
    // Initial request is allowed
    expect(coordinator.canRequestNow(AdRequestType.interstitial), isTrue);
    
    int loadCount = 0;
    coordinator.enqueue(AdRequestType.interstitial, () {
      loadCount++;
    });
    
    // Await debounce window (default 50ms, await 150ms to be safe)
    await Future.delayed(const Duration(milliseconds: 150));
    
    // The loadFn should have been called
    expect(loadCount, equals(1));
    
    // Immediate subsequent request should NOT be allowed due to minimum spacing
    expect(coordinator.canRequestNow(AdRequestType.interstitial), isFalse);
    
    // Enqueue a duplicate immediately
    coordinator.enqueue(AdRequestType.interstitial, () {
      loadCount++;
    });
    
    // Wait another drain
    await Future.delayed(const Duration(milliseconds: 150));
    
    // loadFn should NOT be called again immediately (it gets delayed)
    expect(loadCount, equals(1));
    expect(coordinator.metrics.requestsDelayed, equals(1));
  });
}
