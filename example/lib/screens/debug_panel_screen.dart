import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/revenue_cat_ad_status_provider.dart';

class DebugPanelScreen extends StatelessWidget {
  const DebugPanelScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final status = Provider.of<RevenueCatAdStatusProvider>(context);
    final config = Provider.of<DebugAdConfig>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Debug Control Center'),
      ),
      body: ListView(
        children: [
          _buildSectionHeader('RevenueCat Simulation'),
          SwitchListTile(
            title: const Text('Premium Active'),
            subtitle: const Text('Suppress all ads instantly'),
            value: status.isPremium,
            onChanged: (val) => status.simulateSubscriptionActive(val),
          ),
          
          _buildSectionHeader('Ad Configuration'),
          SwitchListTile(
            title: const Text('Ads Globally Enabled'),
            subtitle: const Text('Simulate remote config toggle'),
            value: config.adsEnabled,
            onChanged: (val) => config.setAdsEnabled(val),
          ),

          _buildSectionHeader('Orchestration & Fallback'),
          SwitchListTile(
            title: const Text('Simulate Native Failure'),
            subtitle: const Text('Instantly switch to preloaded banner'),
            value: config.simulateNativeFailure,
            onChanged: (val) => config.setSimulateNativeFailure(val),
          ),
          SwitchListTile(
            title: const Text('Enable Rewarded Break'),
            subtitle: const Text('Show/Hide the "Pause Ads" button'),
            value: config.enableRewardedBreak,
            onChanged: (val) => config.setEnableRewardedBreak(val),
          ),
          
          const Divider(),
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text(
              'Use this panel to test how your app reacts to different monetization states without needing to rebuild.',
              style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: Colors.grey,
        ),
      ),
    );
  }
}
