import 'package:flutter/material.dart';
import '../interfaces/i_ad_config_provider.dart';
import '../interfaces/i_ad_status_provider.dart';
import '../services/simple_implementations.dart';
import '../services/monetix_facade.dart';

/// A premium, ready-to-use debug panel for Monetix.
/// 
/// This widget provides a comprehensive interface for testing monetization
/// states live in your app. It works best with [SimpleAdConfig] and [BasicAdStatus],
/// but can also be used with custom implementations if they provide setters.
class MonetixDebugPanel extends StatefulWidget {
  const MonetixDebugPanel({super.key});

  @override
  State<MonetixDebugPanel> createState() => _MonetixDebugPanelState();
}

class _MonetixDebugPanelState extends State<MonetixDebugPanel> {
  IAdConfigProvider? _currentConfig;
  IAdStatusProvider? _currentStatus;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final config = Monetix.getConfig(context);
    if (_currentConfig != config) {
      _currentConfig?.removeListener(_onStateChanged);
      _currentConfig = config;
      _currentConfig?.addListener(_onStateChanged);
    }

    final status = Monetix.getStatus(context);
    if (_currentStatus != status) {
      _currentStatus?.removeListener(_onStateChanged);
      _currentStatus = status;
      _currentStatus?.addListener(_onStateChanged);
    }
  }

  void _onStateChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _currentConfig?.removeListener(_onStateChanged);
    _currentStatus?.removeListener(_onStateChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_currentConfig == null || _currentStatus == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    final theme = Theme.of(context);
    final config = _currentConfig!;
    final status = _currentStatus!;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Monetix Control Center'),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 16),
        children: [
          _buildSection(
            context,
            title: 'User State',
            children: [
              _buildSwitch(
                context,
                title: 'Premium Subscription',
                subtitle: 'Instantly suppress all ads',
                value: status.isPremium,
                onChanged: (val) {
                  if (status is BasicAdStatus) {
                    status.isPremium = val;
                  } else {
                    _showManualUpdateHint(context, 'IAdStatusProvider');
                  }
                },
              ),
            ],
          ),
          _buildSection(
            context,
            title: 'Global Policy',
            children: [
              _buildSwitch(
                context,
                title: 'Ads Enabled',
                subtitle: 'Master toggle for all ad requests',
                value: config.adsEnabled,
                onChanged: (val) {
                  if (config is SimpleAdConfig) {
                    config.adsEnabled = val;
                  } else {
                    _showManualUpdateHint(context, 'IAdConfigProvider');
                  }
                },
              ),
            ],
          ),
          _buildSection(
            context,
            title: 'Orchestration',
            children: [
              _buildSwitch(
                context,
                title: 'Rewarded Breaks',
                subtitle: 'Enable "Pause Ads" feature',
                value: config.enableRewardedBreak,
                onChanged: (val) {
                  if (config is SimpleAdConfig) {
                    config.enableRewardedBreak = val;
                  } else {
                    _showManualUpdateHint(context, 'IAdConfigProvider');
                  }
                },
              ),
              _buildSwitch(
                context,
                title: 'Simulate Native Failure',
                subtitle: 'Force fallback to banner ads',
                value: config.simulateNativeFailure,
                onChanged: (val) {
                  if (config is SimpleAdConfig) {
                    config.simulateNativeFailure = val;
                  } else {
                    _showManualUpdateHint(context, 'IAdConfigProvider');
                  }
                },
              ),
            ],
          ),
          _buildSection(
            context,
            title: 'Diagnostics',
            children: [
              _buildInfoRow('Native ID', config.nativeAdUnitId ?? 'Not set'),
              _buildInfoRow('Banner ID', config.bannerAdUnitId ?? 'Not set'),
              _buildInfoRow('Interstitial ID', config.interstitialAdUnitId ?? 'Not set'),
              _buildInfoRow('Rewarded ID', config.rewardedAdUnitId ?? 'Not set'),
            ],
          ),
          const SizedBox(height: 32),
          Center(
            child: Text(
              'Monetix Framework v0.1.2',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection(BuildContext context, {required String title, required List<Widget> children}) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
          child: Text(
            title.toUpperCase(),
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
            ),
          ),
        ),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(children: children),
        ),
      ],
    );
  }

  Widget _buildSwitch(
    BuildContext context, {
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return SwitchListTile(
      value: value,
      onChanged: onChanged,
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return ListTile(
      title: Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
      trailing: Text(
        value.length > 20 ? '...${value.substring(value.length - 15)}' : value,
        style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
      ),
    );
  }

  void _showManualUpdateHint(BuildContext context, String provider) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Note: Using custom $provider. Implement setters to enable toggles.',
        ),
        duration: const Duration(seconds: 3),
      ),
    );
  }
}

/// A floating action button helper to open the debug panel.
class MonetixDebugButton extends StatelessWidget {
  const MonetixDebugButton({super.key});

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton.small(
      heroTag: 'monetix_debug_fab',
      onPressed: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const MonetixDebugPanel()),
      ),
      child: const Icon(Icons.bug_report_rounded),
    );
  }
}

/// A helper widget that only shows its child if a condition is met.
/// 
/// Useful for wrapping the [MonetixDebugButton] or any other admin UI.
class MonetixAdminGate extends StatelessWidget {
  final bool showIf;
  final Widget child;

  const MonetixAdminGate({
    super.key,
    required this.showIf,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return showIf ? child : const SizedBox.shrink();
  }
}
