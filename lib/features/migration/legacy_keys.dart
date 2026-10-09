/// The native apps' preference keys that migration reads (MIGRATION_PLAN.md §4). Read only.
abstract final class IosKeys {
  static const launchCount = 'launchcount';
  static const launchCountOld = 'launchCount';
  static const upgradeFlag = 'FLAG_UPGRADE_1';
  static const updateOnboardingShown = 'FLAG_ONBOARDING_UPDATE_SHOWN';
  static const fontSize = 'KEY_DATA_INT_FONT_SIZE';
  static const hourlyOn = 'FLAG_NOTIFICATIONS_HOURLY';
  static const hourlyStart = 'KEY_DATA_STRING_HOURLY_NOTIFICATION_START_TIME';
  static const hourlyEnd = 'KEY_DATA_STRING_HOURLY_NOTIFICATION_END_TIME';
  static const morningOn = 'FLAG_NOTIFICATIONS_ON_AWAKENING';
  static const morningTime = 'KEY_DATA_STRING_ON_AWAKENING_NOTIFICATION_TIME';
  static const nightOn = 'FLAG_NOTIFICATIONS_NIGHT_TIME';
  static const nightTime = 'KEY_DATA_STRING_NIGHT_NOTIFICATION_TIME';
  static const annualPurchased = 'annual_PURCHASED';
  static const subscriptionExpiry = 'KEY_SUBSCRIPTION_EXPIRY';
  static const donationFlags = [
    'com.ibyteapps.aa12stepguide.donatetier5_PURCHASED',
    'com.ibyteapps.aa12stepguide.donatetier10_PURCHASED',
    'com.ibyteapps.aa12stepguide.donatetier20_PURCHASED',
  ];
  static const lastAppOpenAd = 'LastShownAppOpenAd';
  static const tapCount = 'KEY_DATA_INT_TAP_COUNT';

  /// Any of these means the native iOS app ran on this device.
  static const recognised = [
    launchCount,
    launchCountOld,
    upgradeFlag,
    updateOnboardingShown,
    fontSize,
    hourlyOn,
    hourlyStart,
    annualPurchased,
    lastAppOpenAd,
    tapCount,
    ...donationFlags,
  ];

  /// Identifiers of the native app's pending notifications (MIGRATION_PLAN §6).
  static bool isLegacyNotification(String id) =>
      id.startsWith('HourNotification') ||
      id == morningTime ||
      id == nightTime ||
      id == '3days' ||
      id == '7days';
}

abstract final class AndroidKeys {
  static const launchCount = 'mKeyStepDatalaunchCount_aa12stepguide_aa12stepguide';
  static const onboardingShown = 'onBoardingShown';
  static const day = 'myAppDay';
  static const month = 'myAppMonth';
  static const year = 'myAppYear';
  static const textZoom = 'mKeyStepDatahtmlsize_aa12stepguide';
  static const donationFlags = [
    'donatetier1_aa12stepguidepurchased_aa12stepguide',
    'donatetier2_aa12stepguidepurchased_aa12stepguide',
    'donatetier3_aa12stepguidepurchased_aa12stepguide',
  ];
  static const contentOpens = 'mKeyStepDatatimeShownLiterature_aa12stepguide_aa12stepguide';
  static const rateShown = 'mKeyStepDatarate_shown_aa12stepguide';
  static const ratedApp = 'ratedapp_aa12stepguide';
  static const rated = 'rated';
  static const tooltipSuffix = 'COUNT_TIPPED_aa12stepguide';

  static const recognised = [
    launchCount,
    onboardingShown,
    day,
    textZoom,
    contentOpens,
    rateShown,
    ...donationFlags,
  ];
}
