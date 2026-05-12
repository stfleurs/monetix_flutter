import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../interfaces/i_ad_status_provider.dart';
import '../services/rewarded_monetization_service.dart';

/// Shows a bottom sheet that lets the user watch a rewarded ad to get a
/// temporary ad-free break.
void showRewardStatusSheet(BuildContext context) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const RewardStatusSheet(),
  );
}

class RewardStatusSheet extends StatelessWidget {
  const RewardStatusSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final rewardedAd = context.watch<RewardedMonetizationService>();
    final statusProvider = context.watch<IAdStatusProvider>();
    
    final canWatch = rewardedAd.canWatchAd;
    final blockReason = rewardedAd.blockReason;
    final isActive = rewardedAd.isAdFree;
    final remaining = rewardedAd.remainingTime;

    return Container(
      margin: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: theme.colorScheme.outline.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
            child: Column(
              children: [
                // Icon
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isActive
                        ? Icons.check_circle_outline_rounded
                        : Icons.block_rounded,
                    color: isActive ? Colors.green : theme.colorScheme.primary,
                    size: 32,
                  ),
                ),
                const SizedBox(height: 16),

                if (isActive) ...[
                  // Already in an ad-free period
                  Text(
                    statusProvider.alreadyAdFreeLabel,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "${remaining?.inMinutes ?? 0}:${((remaining?.inSeconds ?? 0) % 60).toString().padLeft(2, '0')} ${statusProvider.minutesRemainingLabel}",
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text(statusProvider.okLabel),
                    ),
                  ),
                ] else ...[
                  // Offer rewarded ad
                  Text(
                    statusProvider.rewardSheetTitle,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    statusProvider.rewardSheetDescription,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),

                  // Watch Ad button
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: (canWatch)
                          ? () {
                              if (rewardedAd.isAdReady) {
                                _watchAd(context, rewardedAd);
                              } else {
                                rewardedAd.loadRewardedAd(isManual: true);
                              }
                            }
                          : null,
                      icon: rewardedAd.isLoading
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white))
                          : Icon(
                              rewardedAd.isAdReady
                                  ? Icons.play_circle_outline_rounded
                                  : Icons.ads_click_rounded,
                            ),
                      label: Text(
                        rewardedAd.isLoading
                            ? statusProvider.loadingLabel
                            : (rewardedAd.isAdReady
                                ? statusProvider.watchAdButtonLabel
                                : statusProvider.loadAdLabel),
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),

                  if (blockReason != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      _getBlockReasonText(rewardedAd, statusProvider),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                      ),
                    ),
                  ],

                  const SizedBox(height: 12),
                  // Close
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(
                      statusProvider.closeLabel,
                      style: TextStyle(
                          color: theme.colorScheme.onSurface
                              .withValues(alpha: 0.5)),
                    ),
                  ),
                ],
              ],
            ),
          ),
          // Permanent Ad-Free option
          if (!statusProvider.isPremium) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.amber.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.star_rounded,
                        color: Colors.amber, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          statusProvider.tiredOfAdsLabel,
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                        Text(
                          statusProvider.goPremiumLabel,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurface
                                .withValues(alpha: 0.6),
                          ),
                        ),
                      ],
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      Navigator.pop(context);
                      statusProvider.showPurchaseScreen(context);
                    },
                    child: Text(
                      statusProvider.upgradeLabel,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _watchAd(
      BuildContext context, RewardedMonetizationService rewardedAdService) async {
    await rewardedAdService.showRewardedAd(
      onRewarded: () {
        if (!context.mounted) return;
        Navigator.pop(context);
      },
      onFailed: () {
        // Handle failure
      },
    );
  }

  String _getBlockReasonText(RewardedMonetizationService service, IAdStatusProvider provider) {
    final reason = service.blockReason;
    if (reason == null) return '';
    switch (reason) {
      case RewardBlockReason.alreadyShowing:
        return provider.adPlayingLabel;
      case RewardBlockReason.rateLimited:
        return provider.rateLimitedLabel;
      case RewardBlockReason.cooldown:
        return provider.cooldownLabel;
    }
  }
}
