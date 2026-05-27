import 'package:flutter/material.dart';
import 'package:monetix_flutter/monetix_flutter.dart';
import 'package:provider/provider.dart';
import '../providers/revenue_cat_ad_status_provider.dart';
import 'debug_panel_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final status = Provider.of<RevenueCatAdStatusProvider>(context);
    final monetization = Provider.of<MonetizationService>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Monetix Playground'),
        actions: [
          IconButton(
            icon: const Icon(Icons.bug_report_outlined),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const DebugPanelScreen()),
            ),
          ),
        ],
      ),
      floatingActionButton: const MonetixAdminGate(
        showIf: true, // Always show in playground
        child: MonetixDebugButton(),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            _buildHeader(status),
            
            // Native Ad with Fallback
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.0),
              child: MonetizedNativeAd(
                screen: 'home',
                placement: 'top_feed',
                templateType: TemplateType.small,
              ),
            ),
            
            const SizedBox(height: 20),
            
            _buildActionCard(
              context,
              title: 'Interstitial Ad',
              subtitle: 'Full-screen ad experience',
              icon: Icons.fullscreen,
              onTap: () => monetization.showInterstitialAd(
                screen: 'home', 
                placement: 'main_button',
              ),
            ),
            
            _buildActionCard(
              context,
              title: 'Rewarded Break',
              subtitle: 'Earn 15 minutes of zero ads',
              icon: Icons.card_giftcard,
              onTap: () => showRewardStatusSheet(context),
            ),
            
            const SizedBox(height: 20),
            
            // Banner Ad at bottom
            const MonetizedBannerAd(
              screen: 'home',
              placement: 'bottom_anchor',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(RevenueCatAdStatusProvider status) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.deepPurple.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                status.isPremium ? 'PREMIUM ACTIVE' : 'FREE VERSION',
                style: TextStyle(
                  color: status.isPremium ? Colors.amber.shade800 : Colors.deepPurple,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                ),
              ),
              Icon(
                status.isPremium ? Icons.star : Icons.star_border,
                color: status.isPremium ? Colors.amber : Colors.grey,
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Welcome to the Playground',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const Text('Test your monetization strategy in real-time.'),
        ],
      ),
    );
  }

  Widget _buildActionCard(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Colors.deepPurple.withValues(alpha: 0.1),
          child: Icon(icon, color: Colors.deepPurple),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}
