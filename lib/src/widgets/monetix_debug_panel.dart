import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../interfaces/i_ad_config_provider.dart';
import '../interfaces/i_ad_status_provider.dart';
import '../services/simple_implementations.dart';
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
      return const Scaffold(
        backgroundColor: Color(0xFF121418),
        body: Center(child: CircularProgressIndicator()),
      );
    }
    final config = _currentConfig!;
    final status = _currentStatus!;
    final gate = Monetix.gate;

    return Scaffold(
      backgroundColor: const Color(0xFF121418),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Monetization Diagnostics', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.white),
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
          _buildMutationControlsSection(status),
          const SizedBox(height: 16),
          if (_analytics != null) _buildTimelineLogSection(_analytics!),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildSectionContainer({required Widget child}) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1C1E24),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
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
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text('AD ENGINE STATUS', style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
        ),
        _buildSectionContainer(
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(child: _buildStatusCard('Rewarded', rewardedLoading ? 'LOADING' : (rewarded.allowed ? 'READY' : 'SUPPRESSED'), rewardedLoading ? Colors.orange : (rewarded.allowed ? Colors.green : Colors.orange))),
                  const SizedBox(width: 12),
                  Expanded(child: _buildStatusCard('Interstitial', interstitial.allowed ? 'READY' : 'SUPPRESSED', interstitial.allowed ? Colors.green : Colors.orange)),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: _buildStatusCard('Native', native.allowed ? 'READY' : 'SUPPRESSED', native.allowed ? Colors.green : Colors.orange)),
                  const SizedBox(width: 12),
                  Expanded(child: _buildStatusCard('Banner', banner.allowed ? 'READY' : 'SUPPRESSED', banner.allowed ? Colors.green : Colors.orange)),
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
        color: const Color(0xFF24272E),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(color: Colors.white70, fontSize: 13)),
          const SizedBox(height: 6),
          Row(
            children: [
              Container(width: 6, height: 6, decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle)),
              const SizedBox(width: 6),
              Text(status, style: TextStyle(color: dotColor, fontSize: 11, fontWeight: FontWeight.bold)),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildActiveSuppressionsSection(IAdStatusProvider status, IAdConfigProvider config, MonetizationGate gate) {
    bool hasBreak = Monetix.rewarded.isAdFree;
    
    // Collect active reasons
    List<String> reasons = [];
    if (status.isPremium) reasons.add('PREMIUM');
    if (hasBreak) reasons.add('REWARDEDPAUSE');
    if (!config.adsEnabled) reasons.add('REMOTEDISABLED');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text('ACTIVE SUPPRESSIONS', style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
        ),
        _buildSectionContainer(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSuppressionRow('Simulated Premium (Pro)', status.isPremium),
              const SizedBox(height: 12),
              _buildSuppressionRow('Ad-Free Break Active', hasBreak),
              const SizedBox(height: 12),
              _buildSuppressionRow('Global Ads Disabled', !config.adsEnabled),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Divider(color: Colors.white10, height: 1),
              ),
              const Text('Active Suppression Reasons:', style: TextStyle(color: Colors.white70, fontSize: 13)),
              const SizedBox(height: 8),
              if (reasons.isEmpty)
                const Text('NONE', style: TextStyle(color: Colors.green, fontSize: 12, fontWeight: FontWeight.bold)),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: reasons.map((r) => Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1),
                    border: Border.all(color: Colors.red.withOpacity(0.3)),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(r, style: const TextStyle(color: Colors.red, fontSize: 10, fontWeight: FontWeight.bold)),
                )).toList(),
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
        Text(label, style: const TextStyle(color: Colors.white, fontSize: 14)),
        Row(
          children: [
            Icon(active ? Icons.circle : Icons.circle_outlined, size: 12, color: active ? Colors.orange : Colors.white30),
            const SizedBox(width: 6),
            Text(active ? 'ACTIVE' : 'INACTIVE', style: TextStyle(color: active ? Colors.orange : Colors.white30, fontSize: 11, fontWeight: FontWeight.bold)),
          ],
        )
      ],
    );
  }

  Widget _buildMutationControlsSection(IAdStatusProvider status) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text('MUTATION CONTROLS', style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
        ),
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
                        const Text('Simulate Pro Unlock', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 2),
                        Text('Toggles premium feature access & ad suppression', style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12)),
                      ],
                    ),
                  ),
                  Switch(
                    value: status.isPremium,
                    activeColor: Colors.white,
                    activeTrackColor: Colors.orange,
                    onChanged: (val) {
                      if (status is BasicAdStatus) {
                        status.isPremium = val;
                      }
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
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () {
                        assert(() {
                          Monetix.rewarded.grantRewardForTesting(const Duration(minutes: 5));
                          return true;
                        }());
                      },
                      icon: const Icon(Icons.timer_outlined, size: 18),
                      label: const Text('Add 5 Min Break', style: TextStyle(fontWeight: FontWeight.bold)),
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
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () {
                        assert(() {
                          Monetix.rewarded.expireRewardForTesting();
                          return true;
                        }());
                      },
                      icon: const Icon(Icons.cancel_outlined, size: 18),
                      label: const Text('Expire Break', style: TextStyle(fontWeight: FontWeight.bold)),
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
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text('MONETIZATION TIMELINE LOG (LAST 50)', style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
        ),
        _buildSectionContainer(
          child: ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: analytics.logs.length,
            separatorBuilder: (context, index) => const Divider(color: Colors.white10, height: 16),
            itemBuilder: (context, index) {
              final log = analytics.logs[index];
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(log.event, style: const TextStyle(color: Colors.white, fontFamily: 'monospace', fontSize: 13, fontWeight: FontWeight.w600)),
                      Text(
                        '${log.timestamp.hour.toString().padLeft(2, '0')}:${log.timestamp.minute.toString().padLeft(2, '0')}:${log.timestamp.second.toString().padLeft(2, '0')}.${log.timestamp.millisecond.toString().padLeft(3, '0')}',
                        style: TextStyle(color: Colors.white.withOpacity(0.4), fontFamily: 'monospace', fontSize: 11),
                      ),
                    ],
                  ),
                  if (log.details != null && log.details!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      log.details.toString(),
                      style: TextStyle(color: Colors.white.withOpacity(0.4), fontFamily: 'monospace', fontSize: 11),
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
