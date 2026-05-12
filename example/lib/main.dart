import 'package:flutter/material.dart';
import 'package:monetix_flutter/monetix_flutter.dart';
import 'package:provider/provider.dart';

import 'providers/revenue_cat_ad_status_provider.dart';
import 'screens/home_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  Provider.debugCheckInvalidValueType = null;
  runApp(const MonetixPlaygroundApp());
}

class MonetixPlaygroundApp extends StatelessWidget {
  const MonetixPlaygroundApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        // 1. Premium State Provider (Mocking RevenueCat)
        ChangeNotifierProvider<RevenueCatAdStatusProvider>(
          create: (_) => RevenueCatAdStatusProvider(),
        ),
        
        // Expose as interface for the framework widgets
        ListenableProxyProvider<RevenueCatAdStatusProvider, IAdStatusProvider>(
          update: (_, status, __) => status,
        ),
        
        // 2. Ad Configuration Provider (with Debug overrides)
        ChangeNotifierProvider<DebugAdConfig>(
          create: (_) => DebugAdConfig(),
        ),

        // Expose as interface
        ListenableProxyProvider<DebugAdConfig, IAdConfigProvider>(
          update: (_, config, __) => config,
        ),
        
        // 3. Analytics Provider
        Provider<IAdAnalytics>(
          create: (_) => PlaygroundAnalytics(),
        ),
        
        // 4. Rewarded Service
        ChangeNotifierProxyProvider2<DebugAdConfig, IAdAnalytics, RewardedMonetizationService>(
          create: (context) => RewardedMonetizationService(
            context.read<DebugAdConfig>(),
            statusProvider: context.read<RevenueCatAdStatusProvider>(),
            analyticsService: context.read<IAdAnalytics>(),
          ),
          update: (_, config, analytics, previous) => previous!,
        ),
        
        // 5. Main Monetization Orchestrator
        Provider<MonetizationService>(
          create: (context) {
            final service = MonetizationService(
              context.read<DebugAdConfig>(),
              statusProvider: context.read<RevenueCatAdStatusProvider>(),
              analyticsService: context.read<IAdAnalytics>(),
              rewardedAdService: context.read<RewardedMonetizationService>(),
            );
            service.init();
            return service;
          },
        ),
      ],
      child: MaterialApp(
        title: 'Monetix Playground',
        debugShowCheckedModeBanner: false,
        theme: _buildPremiumTheme(),
        home: const HomeScreen(),
      ),
    );
  }

  ThemeData _buildPremiumTheme() {
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: Colors.deepPurple,
        primary: Colors.deepPurple,
        secondary: Colors.amber,
      ),
    );
    
    return base.copyWith(
      appBarTheme: const AppBarTheme(
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        titleTextStyle: TextStyle(
          color: Colors.black87,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: Colors.grey.shade200),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }
}

/// A simple analytics logger for the playground
class PlaygroundAnalytics extends IAdAnalytics {
  @override
  Future<void> logAdRequest({required String adType, required String adUnitId, required String screen, required String placement}) async {
    debugPrint('📊 [Analytics] Request: $adType | Screen: $screen | Placement: $placement');
  }

  @override
  Future<void> logAdImpression({required String adType, required String adUnitId, required String screen, required String placement, int? loadDurationMs, bool isFallback = false}) async {
    debugPrint('📊 [Analytics] Impression: $adType | Fallback: $isFallback | Load: ${loadDurationMs}ms');
  }

  @override
  Future<void> logAdFailure({required String adType, required String adUnitId, required String errorCode, required String screen, required String placement}) async {
    debugPrint('📊 [Analytics] FAILURE: $adType | Error: $errorCode');
  }

  @override
  Future<void> logAdRevenue({required double value, required String currency, required String adType, required String adUnitId, required String screen, required String placement}) async {
    debugPrint('📊 [Analytics] Revenue: $value $currency ($adType)');
  }

  @override
  Future<void> logAdRewardEarned({required String adType, required String screen, required String placement}) async {
    debugPrint('📊 [Analytics] REWARD EARNED! Type: $adType');
  }

  @override
  void startPostAdWindow(String adType) {
    debugPrint('📊 [Analytics] Starting Post-Ad Retention Window ($adType)');
  }
}
