import 'package:flutter/material.dart';
import 'package:monetix_flutter/monetix_flutter.dart';
import 'package:provider/provider.dart';
import '../providers/revenue_cat_ad_status_provider.dart';

class PremiumModeScreen extends StatelessWidget {
  const PremiumModeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final statusProvider = Provider.of<RevenueCatAdStatusProvider>(context);
    final isPremium = statusProvider.isPremium;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Premium Mode'),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                const Icon(
                  Icons.auto_fix_high_rounded,
                  size: 80,
                  color: Colors.amber,
                ),
                const SizedBox(height: 24),
                Text(
                  isPremium ? 'Premium Experience Active' : 'Free Experience Active',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 16),
                Text(
                  isPremium
                      ? 'All ads are now suppressed app-wide. The framework automatically detects this state and removes ad widgets from the tree.'
                      : 'Ads are currently enabled. Switch to Premium to see them disappear instantly across the entire application.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey.shade600, height: 1.5),
                ),
                const SizedBox(height: 48),
                
                // The big toggle
                Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    decoration: BoxDecoration(
                      color: isPremium ? Colors.amber.withValues(alpha: 0.1) : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(100),
                      border: Border.all(
                        color: isPremium ? Colors.amber : Colors.grey.shade300,
                        width: 2,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'PREMIUM STATUS',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: isPremium ? Colors.amber.shade900 : Colors.grey.shade700,
                            letterSpacing: 1.2,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Switch(
                          value: isPremium,
                          activeThumbColor: Colors.amber,
                          onChanged: (val) => statusProvider.simulateSubscriptionActive(val),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          // Ad at the bottom that will disappear
          Container(
            padding: const EdgeInsets.symmetric(vertical: 16),
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: Colors.grey.shade200)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (!isPremium)
                  const Padding(
                    padding: EdgeInsets.only(bottom: 8.0),
                    child: Text('This ad will disappear when Premium is ON', 
                        style: TextStyle(fontSize: 10, color: Colors.grey)),
                  ),
                const MonetizedBannerAd(
                  screen: 'premium_demo',
                  placement: 'footer',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
