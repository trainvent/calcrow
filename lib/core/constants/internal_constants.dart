class IConst {
  static const String appName = 'Calcrow';
  static const String adMobAndroidAppId = String.fromEnvironment(
    'ADMOB_ANDROID_APP_ID',
    defaultValue: '',
  );
  static const String adMobIosAppId = String.fromEnvironment(
    'ADMOB_IOS_APP_ID',
    defaultValue: '',
  );
  static const String adMobAndroidInterstitialId = String.fromEnvironment(
    'ADMOB_ANDROID_INTERSTITIAL_ID',
    defaultValue: '',
  );
  static const String adMobAndroidBannerId = String.fromEnvironment(
    'ADMOB_ANDROID_BANNER_ID',
    defaultValue: '',
  );
  static const String revenueCatTestAPIKey = String.fromEnvironment(
    'REVENUECAT_TEST_API_KEY',
    defaultValue: '',
  );
  static const String revenueCatGoogleAPIKey = String.fromEnvironment(
    'REVENUECAT_GOOGLE_API_KEY',
    defaultValue: '',
  );
}
