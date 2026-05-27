import 'package:flutter/material.dart';
import '../interfaces/i_ad_config_provider.dart';
import '../interfaces/i_ad_status_provider.dart';
import '../services/monetix_facade.dart';
import '../services/diagnostic_ad_analytics.dart';
import '../services/monetization_gate.dart';

/// A premium, ready-to-use diagnostics panel for Monetix.
class MonetixDebugPanel extends StatefulWidget {
  const MonetixDebugPanel({super.key});

  @override
  State<MonetixDebugPanel> createState() => _MonetixDebugPanelState();
}

class _MonetixDebugPanelState extends State<MonetixDebugPanel> {
  IAdConfigProvider? _currentConfig;
  IAdStatusProvider? _currentStatus;
  DiagnosticAdAnalytics? _analytics;

  ColorScheme get _colors => Theme.of(context).colorScheme;

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

    final analytics = Monetix.getAnalytics(context);
    if (analytics is DiagnosticAdAnalytics) {
      if (_analytics != analytics) {
        _analytics?.removeListener(_onStateChanged);
        _analytics = analytics;
        _analytics?.addListener(_onStateChanged);
      }
    }

    Monetix.gate.addListener(_onStateChanged);
    Monetix.rewarded.addListener(_onStateChanged);
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
    _analytics?.removeListener(_onStateChanged);
    Monetix.gate.removeListener(_onStateChanged);
    Monetix.rewarded.removeListener(_onStateChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_currentConfig == null || _currentStatus == null) {
      return Scaffold(
        backgroundColor: _colors.surface,
        body: Center(child: CircularProgressIndicator()),
      );
    }
    final config = _currentConfig!;
    final status = _currentStatus!;
    final gate = Monetix.gate;

    return Scaffold(
      backgroundColor: _colors.surface,
      appBar: AppBar(
        title: const Text('Monetization Diagnostics',
            style: TextStyle(
                fontSize: 18, fontWeight: FontWeight.bold)),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outlined),
            onPressed: () {
              // Clear logs if needed
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        children: [
          _buildEngineStatusSection(gate),
          const SizedBox(height: 16),
          _buildActiveSuppressionsSection(status, config, gate),
          const SizedBox(height: 16),
          _buildMutationControlsSection(status, config),
          const SizedBox(height: 16),
          if (_analytics != null) _buildTimelineLogSection(_analytics!),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _sectionHeader(String text) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(text,
          style: TextStyle(
              color: _colors.onSurface.withValues(alpha: 0.5),
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2)),
    );
  }

  Widget _buildSectionContainer({required Widget child}) {
    return Container(
      decoration: BoxDecoration(
        color: _colors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _colors.outlineVariant),
      ),
      padding: const EdgeInsets.all(16),
      child: child,
    );
  }

  Widget _buildEngineStatusSection(MonetizationGate gate) {
    final rewarded = gate.evaluateRewarded();
    final interstitial = gate.evaluateInterstitial();
    final native = gate.evaluateNative();
    final banner = gate.evaluateBanner();

    final rewardedLoading = Monetix.rewarded.isLoading;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader('AD ENGINE STATUS'),
        _buildSectionContainer(
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                      child: _buildStatusCard(
                          'Rewarded',
                          rewardedLoading
                              ? 'LOADING'
                              : (rewarded.allowed ? 'READY' : 'SUPPRESSED'),
                          rewardedLoading
                              ? Colors.orange
                              : (rewarded.allowed
                                  ? Colors.green
                                  : Colors.orange))),
                  const SizedBox(width: 12),
                  Expanded(
                      child: _buildStatusCard(
                          'Interstitial',
                          interstitial.allowed ? 'READY' : 'SUPPRESSED',
                          interstitial.allowed ? Colors.green : Colors.orange)),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                      child: _buildStatusCard(
                          'Native',
                          native.allowed ? 'READY' : 'SUPPRESSED',
                          native.allowed ? Colors.green : Colors.orange)),
                  const SizedBox(width: 12),
                  Expanded(
                      child: _buildStatusCard(
                          'Banner',
                          banner.allowed ? 'READY' : 'SUPPRESSED',
                          banner.allowed ? Colors.green : Colors.orange)),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStatusCard(String title, String status, Color dotColor) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _colors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: TextStyle(color: _colors.onSurface.withOpacity(0.7), fontSize: 13)),
          const SizedBox(height: 6),
          Row(
            children: [
              Container(
                  width: 6,
                  height: 6,
                  decoration:
                      BoxDecoration(color: dotColor, shape: BoxShape.circle)),
              const SizedBox(width: 6),
              Text(status,
                  style: TextStyle(
                      color: dotColor,
                      fontSize: 11,
                      fontWeight: FontWeight.bold)),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildActiveSuppressionsSection(IAdStatusProvider status,
      IAdConfigProvider config, MonetizationGate gate) {
    bool hasBreak = Monetix.rewarded.isAdFree;

    List<String> reasons = [];
    if (status.isPremium) reasons.add('PREMIUM');
    if (hasBreak) reasons.add('REWARDEDPAUSE');
    if (!config.adsEnabled) reasons.add('REMOTEDISABLED');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader('ACTIVE SUPPRESSIONS'),
        _buildSectionContainer(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSuppressionRow('Simulated Premium (Pro)', status.isPremium),
              const SizedBox(height: 12),
              _buildSuppressionRow('Ad-Free Break Active', hasBreak),
              const SizedBox(height: 12),
              _buildSuppressionRow('Global Ads Disabled', !config.adsEnabled),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Divider(color: _colors.outlineVariant, height: 1),
              ),
              Text('Active Suppression Reasons:',
                  style: TextStyle(color: _colors.onSurface.withOpacity(0.7), fontSize: 13)),
              const SizedBox(height: 8),
              if (reasons.isEmpty)
                Text('NONE',
                    style: TextStyle(
                        color: Colors.green,
                        fontSize: 12,
                        fontWeight: FontWeight.bold)),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: reasons
                    .map((r) => Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.red.withOpacity(0.1),
                            border:
                                Border.all(color: Colors.red.withOpacity(0.3)),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(r,
                              style: const TextStyle(
                                  color: Colors.red,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold)),
                        ))
                    .toList(),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSuppressionRow(String label, bool active) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: TextStyle(color: _colors.onSurface, fontSize: 14)),
        Row(
          children: [
            Icon(active ? Icons.circle : Icons.circle_outlined,
                size: 12,
                color:
                    active ? Colors.orange : _colors.onSurface.withOpacity(0.3)),
            const SizedBox(width: 6),
            Text(active ? 'ACTIVE' : 'INACTIVE',
                style: TextStyle(
                    color: active
                        ? Colors.orange
                        : _colors.onSurface.withOpacity(0.3),
                    fontSize: 11,
                    fontWeight: FontWeight.bold)),
          ],
        )
      ],
    );
  }

  Widget _buildMutationControlsSection(
      IAdStatusProvider status, IAdConfigProvider config) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader('MUTATION CONTROLS'),
        _buildSectionContainer(
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Simulate Pro Unlock',
                            style: TextStyle(
                                color: _colors.onSurface,
                                fontSize: 15,
                                fontWeight: FontWeight.w600)),
                        const SizedBox(height: 2),
                        Text('Toggles premium feature access & ad suppression',
                            style: TextStyle(
                                color: _colors.onSurface.withOpacity(0.5),
                                fontSize: 12)),
                      ],
                    ),
                  ),
                  Switch(
                    value: status.isPremium,
                    activeThumbColor: Colors.white,
                    activeTrackColor: Colors.orange,
                    onChanged: (val) {
                      status.setPremiumForDebug(val);
                    },
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Divider(color: _colors.outlineVariant, height: 1),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Global Ads Enabled',
                            style: TextStyle(
                                color: _colors.onSurface,
                                fontSize: 15,
                                fontWeight: FontWeight.w600)),
                        const SizedBox(height: 2),
                        Text('Simulate remote config toggle',
                            style: TextStyle(
                                color: _colors.onSurface.withOpacity(0.5),
                                fontSize: 12)),
                      ],
                    ),
                  ),
                  Switch(
                    value: config.adsEnabled,
                    activeThumbColor: Colors.white,
                    activeTrackColor: Colors.green,
                    onChanged: (val) {
                      config.setAdsEnabledForDebug(val);
                    },
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Divider(color: _colors.outlineVariant, height: 1),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Simulate Native Failure',
                            style: TextStyle(
                                color: _colors.onSurface,
                                fontSize: 15,
                                fontWeight: FontWeight.w600)),
                        const SizedBox(height: 2),
                        Text('Instantly switch to preloaded banner',
                            style: TextStyle(
                                color: _colors.onSurface.withOpacity(0.5),
                                fontSize: 12)),
                      ],
                    ),
                  ),
                  Switch(
                    value: config.simulateNativeFailure,
                    activeThumbColor: Colors.white,
                    activeTrackColor: Colors.orange,
                    onChanged: (val) {
                      config.setSimulateNativeFailureForDebug(val);
                    },
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Divider(color: _colors.outlineVariant, height: 1),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Enable Rewarded Break',
                            style: TextStyle(
                                color: _colors.onSurface,
                                fontSize: 15,
                                fontWeight: FontWeight.w600)),
                        const SizedBox(height: 2),
                        Text('Show/Hide the "Pause Ads" button',
                            style: TextStyle(
                                color: _colors.onSurface.withOpacity(0.5),
                                fontSize: 12)),
                      ],
                    ),
                  ),
                  Switch(
                    value: config.enableRewardedBreak,
                    activeThumbColor: Colors.white,
                    activeTrackColor: Colors.blue,
                    onChanged: (val) {
                      config.setEnableRewardedBreakForDebug(val);
                    },
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange.withOpacity(0.15),
                        foregroundColor: Colors.orange,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () {
                        assert(() {
                          Monetix.rewarded.grantRewardForTesting(
                              const Duration(minutes: 5));
                          return true;
                        }());
                      },
                      icon: const Icon(Icons.timer_outlined, size: 18),
                      label: const Text('Add 5 Min Break',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red.withOpacity(0.15),
                        foregroundColor: Colors.red[300],
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () {
                        assert(() {
                          Monetix.rewarded.expireRewardForTesting();
                          return true;
                        }());
                      },
                      icon: const Icon(Icons.cancel_outlined, size: 18),
                      label: const Text('Expire Break',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              )
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTimelineLogSection(DiagnosticAdAnalytics analytics) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader('MONETIZATION TIMELINE LOG (LAST 50)'),
        _buildSectionContainer(
          child: ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: analytics.logs.length,
            separatorBuilder: (context, index) =>
                Divider(color: _colors.outlineVariant, height: 16),
            itemBuilder: (context, index) {
              final log = analytics.logs[index];
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(log.event,
                          style: TextStyle(
                              color: _colors.onSurface,
                              fontFamily: 'monospace',
                              fontSize: 13,
                              fontWeight: FontWeight.w600)),
                      Text(
                        '${log.timestamp.hour.toString().padLeft(2, '0')}:${log.timestamp.minute.toString().padLeft(2, '0')}:${log.timestamp.second.toString().padLeft(2, '0')}.${log.timestamp.millisecond.toString().padLeft(3, '0')}',
                        style: TextStyle(
                            color: _colors.onSurface.withValues(alpha: 0.4),
                            fontFamily: 'monospace',
                            fontSize: 11),
                      ),
                    ],
                  ),
                  if (log.details != null && log.details!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      log.details.toString(),
                      style: TextStyle(
                          color: _colors.onSurface.withValues(alpha: 0.4),
                          fontFamily: 'monospace',
                          fontSize: 11),
                    )
                  ]
                ],
              );
            },
          ),
        ),
      ],
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
