import 'package:flutter/material.dart';
import 'package:monetix_flutter/monetix_flutter.dart';

class RewardedBreakScreen extends StatelessWidget {
  const RewardedBreakScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ad-Free Break'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHero(context),
            const SizedBox(height: 32),
            _buildFeatureDescription(context),
            const SizedBox(height: 48),
            Center(
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 20),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 0,
                ),
                onPressed: () => showRewardStatusSheet(context),
                icon: const Icon(Icons.play_circle_filled_rounded),
                label: const Text(
                  'Start Ad-Free Break',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
            ),
            const SizedBox(height: 48),
            const Divider(),
            const SizedBox(height: 24),
            const Text(
              'Live Ad Status',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 12),
            const MonetizedNativeAd(
              screen: 'rewarded_demo',
              placement: 'live_test',
              templateType: TemplateType.small,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHero(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Colors.blue, Colors.lightBlueAccent],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          const Icon(Icons.timer_rounded, color: Colors.white, size: 64),
          const SizedBox(height: 16),
          const Text(
            'Pause Ads with One Video',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Let users "buy" 15 minutes of uninterrupted focus by watching a single rewarded ad.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureDescription(BuildContext context) {
    return Column(
      children: [
        _buildListTile(
          Icons.health_and_safety_outlined,
          'Reduce Ad Fatigue',
          'Users are more likely to stay engaged if they feel in control of their ad experience.',
        ),
        const SizedBox(height: 16),
        _buildListTile(
          Icons.trending_up_rounded,
          'Higher eCPM',
          'Rewarded ads typically pay 5-10x more than standard banners.',
        ),
        const SizedBox(height: 16),
        _buildListTile(
          Icons.phonelink_ring_outlined,
          'Universal Suppression',
          'Once granted, all Monetized widgets across the whole app automatically hide themselves.',
        ),
      ],
    );
  }

  Widget _buildListTile(IconData icon, String title, String subtitle) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.blue.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: Colors.blue, size: 24),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              const SizedBox(height: 4),
              Text(subtitle, style: TextStyle(color: Colors.grey.shade600, fontSize: 13, height: 1.4)),
            ],
          ),
        ),
      ],
    );
  }
}
