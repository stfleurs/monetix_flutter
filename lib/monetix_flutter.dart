library monetix_flutter;

// Interfaces
export 'src/interfaces/i_ad_analytics.dart';
export 'src/interfaces/i_ad_status_provider.dart';
export 'src/interfaces/i_ad_config_provider.dart';

// Services
export 'src/services/monetization_service.dart';
export 'src/services/rewarded_monetization_service.dart';
export 'src/services/simple_implementations.dart';
export 'src/services/monetix_facade.dart';

// Widgets
export 'src/widgets/monetized_native_ad.dart';
export 'src/widgets/monetized_banner_ad.dart';
export 'src/widgets/reward_status_sheet.dart';
export 'src/widgets/monetix_debug_panel.dart';

// Re-export common types from dependencies
export 'package:google_mobile_ads/google_mobile_ads.dart' show TemplateType;
