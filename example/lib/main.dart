import 'dart:async';
import 'package:flutter/material.dart';
import 'package:monetix_flutter/monetix_flutter.dart';
import 'package:provider/provider.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

/// 1. Implement IAdConfigProvider
class MockAdConfig extends IAdConfigProvider {
  @override
  String? get bannerAdUnitId => 'ca-app-pub-3940256099942544/6300978111';
  @override
  String? get interstitialAdUnitId => 'ca-app-pub-3940256099942544/1033173712';
  @override
  String? get rewardedAdUnitId => 'ca-app-pub-3940256099942544/5224354917';
  @override
  String? get nativeAdUnitId => 'ca-app-pub-3940256099942544/2247696110';
  @override
  bool get adsEnabled => true;
}

/// 2. Implement IAdAnalytics
class MockAdAnalytics extends IAdAnalytics {
  @override
  Future<void> logAdRequest({required String adType, required String adUnitId, required String screen, required String placement}) async {
    debugPrint('Analytics: Ad Request - $adType on $screen');
  }
  @override
  Future<void> logAdImpression({required String adType, required String adUnitId, required String screen, required String placement, int? loadDurationMs, bool isFallback = false}) async {
    debugPrint('Analytics: Ad Impression - $adType on $screen (fallback: $isFallback)');
  }
  @override
  Future<void> logAdFailure({required String adType, required String adUnitId, required String errorCode, required String screen, required String placement}) async {
    debugPrint('Analytics: Ad Failure - $adType error $errorCode');
  }
  @override
  Future<void> logAdRevenue({required double value, required String currency, required String adType, required String adUnitId, required String screen, required String placement}) async {
    debugPrint('Analytics: Ad Revenue - $value $currency');
  }
  @override
  Future<void> logAdRewardEarned({required String adType, required String screen, required String placement}) async {
    debugPrint('Analytics: Reward Earned!');
  }
  @override
  void startPostAdWindow(String adType) {
    debugPrint('Analytics: Starting post-ad window');
  }
}

/// 3. Implement IAdStatusProvider
class MockAdStatus extends ChangeNotifier implements IAdStatusProvider {
  bool _isPremium = false;
  final _controller = StreamController<bool>.broadcast();

  @override
  bool get isPremium => _isPremium;

  void togglePremium() {
    _isPremium = !_isPremium;
    _controller.add(_isPremium);
    notifyListeners();
  }

  @override
  Stream<bool> get premiumStatusStream => _controller.stream;

  @override
  void dispose() {
    _controller.close();
    super.dispose();
  }

  @override
  void showPurchaseScreen(dynamic context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Purchase screen would open here')),
    );
  }

  @override String get pauseAdsLabel => "Pause Ads for 15 min";
  @override String get rewardSheetTitle => "Get an Ad-Free Break";
  @override String get rewardSheetDescription => "Watch a short video to remove all ads for 15 minutes.";
  @override String get watchAdButtonLabel => "Watch Video";
  @override String get loadAdLabel => "Load Ad";
  @override String get alreadyAdFreeLabel => "Ads are Paused";
  @override String get minutesRemainingLabel => "minutes remaining";
  @override String get upgradeLabel => "Upgrade to Premium";
  @override String get tiredOfAdsLabel => "Tired of these ads?";
  @override String get goPremiumLabel => "Go premium for a completely ad-free experience.";
  @override String get okLabel => "Got it";
  @override String get closeLabel => "Close";
  @override String get loadingLabel => "Loading Ad...";
  @override String get adPlayingLabel => "Ad is playing";
  @override String get rateLimitedLabel => "Come back later";
  @override String get cooldownLabel => "Please wait a moment";
}

/// --- QUICK MODE EXAMPLE ---
/// To use the quick mode, you can simplify the entire setup:
/*
void mainQuick() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Monetix.initialize(
    bannerId: 'ca-app-pub-3940256099942544/6300978111',
    // ... other IDs
  );
  runApp(const MyApp());
}
*/

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<MockAdStatus>(create: (_) => MockAdStatus()),
        Provider<IAdConfigProvider>(create: (_) => MockAdConfig()),
        Provider<IAdAnalytics>(create: (_) => MockAdAnalytics()),
        ChangeNotifierProxyProvider2<IAdConfigProvider, IAdAnalytics, RewardedMonetizationService>(
          create: (context) => RewardedMonetizationService(
            context.read<IAdConfigProvider>(),
            analyticsService: context.read<IAdAnalytics>(),
          ),
          update: (_, config, analytics, previous) => previous!,
        ),
        Provider<MonetizationService>(
          create: (context) {
            final service = MonetizationService(
              context.read<IAdConfigProvider>(),
              statusProvider: context.read<MockAdStatus>(),
              analyticsService: context.read<IAdAnalytics>(),
              rewardedAdService: context.read<RewardedMonetizationService>(),
            );
            service.init();
            return service;
          },
        ),
      ],
      child: MaterialApp(
        title: 'Monetix Flutter Example',
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
          useMaterial3: true,
        ),
        home: const HomePage(),
      ),
    );
  }
}

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final status = Provider.of<MockAdStatus>(context);
    final monetization = Provider.of<MonetizationService>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Monetix Flutter'),
        actions: [
          IconButton(
            icon: Icon(status.isPremium ? Icons.star : Icons.star_border),
            onPressed: () => status.togglePremium(),
            tooltip: 'Toggle Premium Status',
          )
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: Text('This is a demo of the modular monetization package.'),
            ),
            
            // Native Ad Example
            const MonetizedNativeAd(
              screen: 'home',
              placement: 'top_banner',
              templateType: TemplateType.small,
            ),
            
            const SizedBox(height: 20),
            
            ElevatedButton(
              onPressed: () => monetization.showInterstitialAd(screen: 'home', placement: 'button_click'),
              child: const Text('Show Interstitial Ad'),
            ),
            
            const SizedBox(height: 20),
            
            ElevatedButton(
              onPressed: () => showRewardStatusSheet(context),
              child: const Text('Check Ad-Free Status / Watch Rewarded'),
            ),
            
            const SizedBox(height: 40),
            
            // Banner Ad Example
            const MonetizedBannerAd(
              screen: 'home',
              placement: 'bottom_anchor',
            ),
          ],
        ),
      ),
    );
  }
}
