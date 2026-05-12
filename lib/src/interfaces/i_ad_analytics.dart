abstract class IAdAnalytics {
  Future<void> logAdRequest({
    required String adType,
    required String adUnitId,
    required String screen,
    required String placement,
  });

  Future<void> logAdImpression({
    required String adType,
    required String adUnitId,
    required String screen,
    required String placement,
    int? loadDurationMs,
    bool isFallback = false,
  });

  Future<void> logAdFailure({
    required String adType,
    required String adUnitId,
    required String errorCode,
    required String screen,
    required String placement,
  });

  Future<void> logAdRevenue({
    required double value,
    required String currency,
    required String adType,
    required String adUnitId,
    required String screen,
    required String placement,
  });

  Future<void> logAdRewardEarned({
    required String adType,
    required String screen,
    required String placement,
  });

  void startPostAdWindow(String adType);
}
