import 'package:flutter/material.dart';
import 'package:monetix_flutter/monetix_flutter.dart';

class NativeAdsScreen extends StatelessWidget {
  const NativeAdsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Native Ads & Fallbacks'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildInfoCard(
            context,
            'Smart Fallback Strategy',
            'If a high-value Native Ad fails to load (due to network or inventory), Monetix automatically falls back to a standard Banner Ad to ensure no revenue is lost.',
          ),
          const SizedBox(height: 24),
          
          Text(
            'Native Small Template',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const MonetizedNativeAd(
            screen: 'playground',
            placement: 'native_small',
            templateType: TemplateType.small,
          ),
          
          const SizedBox(height: 32),
          
          Text(
            'Native Medium Template',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const MonetizedNativeAd(
            screen: 'playground',
            placement: 'native_medium',
            templateType: TemplateType.medium,
          ),
          
          const SizedBox(height: 32),
          
          Text(
            'Standard Banner',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const MonetizedBannerAd(
            screen: 'playground',
            placement: 'banner_standard',
          ),
          
          const SizedBox(height: 40),
          
          Card(
            color: Colors.deepPurple.shade50,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  const Icon(Icons.auto_awesome, color: Colors.deepPurple),
                  const SizedBox(height: 8),
                  Text(
                    'Pro Tip',
                    style: TextStyle(color: Colors.deepPurple.shade900, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Try toggling "Force Ad Failure" in the Debug Panel to see these Native ads transition to Banner fallbacks live.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 13),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard(BuildContext context, String title, String description) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 8),
          Text(
            description,
            style: TextStyle(color: Colors.grey.shade700, height: 1.4),
          ),
        ],
      ),
    );
  }
}
