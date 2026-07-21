import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_de.dart';
import 'app_localizations_en.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'generated/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('de'),
    Locale('en'),
  ];

  /// No description provided for @message6DigitCode.
  ///
  /// In en, this message translates to:
  /// **'6-digit code'**
  String get message6DigitCode;

  /// No description provided for @activeCloudProvider.
  ///
  /// In en, this message translates to:
  /// **'Active cloud provider'**
  String get activeCloudProvider;

  /// No description provided for @adConsentResetOnThisDevice.
  ///
  /// In en, this message translates to:
  /// **'Ad consent reset on this device.'**
  String get adConsentResetOnThisDevice;

  /// No description provided for @adPrivacyChoicesUpdated.
  ///
  /// In en, this message translates to:
  /// **'Ad privacy choices updated.'**
  String get adPrivacyChoicesUpdated;

  /// No description provided for @addField.
  ///
  /// In en, this message translates to:
  /// **'Add field'**
  String get addField;

  /// No description provided for @addWebDAVEntry.
  ///
  /// In en, this message translates to:
  /// **'Add WebDAV entry'**
  String get addWebDAVEntry;

  /// No description provided for @adjust.
  ///
  /// In en, this message translates to:
  /// **'Adjust'**
  String get adjust;

  /// No description provided for @adsPrivacy.
  ///
  /// In en, this message translates to:
  /// **'Ads Privacy'**
  String get adsPrivacy;

  /// No description provided for @adsPrivacyChoices.
  ///
  /// In en, this message translates to:
  /// **'Ads privacy choices'**
  String get adsPrivacyChoices;

  /// No description provided for @adsPrivacyPolicy.
  ///
  /// In en, this message translates to:
  /// **'Ads privacy policy'**
  String get adsPrivacyPolicy;

  /// No description provided for @allWebDAVEntriesUnlinked.
  ///
  /// In en, this message translates to:
  /// **'All WebDAV entries unlinked.'**
  String get allWebDAVEntriesUnlinked;

  /// No description provided for @anonymousUsagePatternsToUnderstandWhichScreensAndFlowsAreUsed.
  ///
  /// In en, this message translates to:
  /// **'Anonymous usage patterns to understand which screens and flows are used.'**
  String get anonymousUsagePatternsToUnderstandWhichScreensAndFlowsAreUsed;

  /// No description provided for @appPassword.
  ///
  /// In en, this message translates to:
  /// **'App password'**
  String get appPassword;

  /// No description provided for @back.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get back;

  /// No description provided for @backToSignIn.
  ///
  /// In en, this message translates to:
  /// **'Back to sign in'**
  String get backToSignIn;

  /// No description provided for @bothCategoriesStayOffUntilYouExplicitlyEnableThemHereYouCanTurnThemOffAgainAtAnyTime.
  ///
  /// In en, this message translates to:
  /// **'Both categories stay off until you explicitly enable them here. You can turn them off again at any time.'**
  String
  get bothCategoriesStayOffUntilYouExplicitlyEnableThemHereYouCanTurnThemOffAgainAtAnyTime;

  /// No description provided for @cachedFieldTypesCleared.
  ///
  /// In en, this message translates to:
  /// **'Cached field types cleared.'**
  String get cachedFieldTypesCleared;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @changePassword.
  ///
  /// In en, this message translates to:
  /// **'Change password'**
  String get changePassword;

  /// No description provided for @choose.
  ///
  /// In en, this message translates to:
  /// **'Choose'**
  String get choose;

  /// No description provided for @chooseADocumentFromGetStarted.
  ///
  /// In en, this message translates to:
  /// **'Choose a document from Get Started.'**
  String get chooseADocumentFromGetStarted;

  /// No description provided for @chooseAnyRowFromTheSheet.
  ///
  /// In en, this message translates to:
  /// **'Choose any row from the sheet.'**
  String get chooseAnyRowFromTheSheet;

  /// No description provided for @chooseAGoogleDriveOrWebDAVFolder.
  ///
  /// In en, this message translates to:
  /// **'Choose a Google Drive or WebDAV folder.'**
  String get chooseAGoogleDriveOrWebDAVFolder;

  /// No description provided for @chooseOrCreateTheActiveCloudSyncFile.
  ///
  /// In en, this message translates to:
  /// **'Choose or create the active cloud sync file.'**
  String get chooseOrCreateTheActiveCloudSyncFile;

  /// No description provided for @chooseOrCreateTheGoogleDriveFileUsedForSync.
  ///
  /// In en, this message translates to:
  /// **'Choose or create the Google Drive file used for sync.'**
  String get chooseOrCreateTheGoogleDriveFileUsedForSync;

  /// No description provided for @chooseOrCreateTheWebDAVFileUsedForSync.
  ///
  /// In en, this message translates to:
  /// **'Choose or create the WebDAV file used for sync.'**
  String get chooseOrCreateTheWebDAVFileUsedForSync;

  /// No description provided for @chooseASaveLocationOnThisDevice.
  ///
  /// In en, this message translates to:
  /// **'Choose a save location on this device.'**
  String get chooseASaveLocationOnThisDevice;

  /// No description provided for @chooseAWritableAndroidFolder.
  ///
  /// In en, this message translates to:
  /// **'Choose a writable Android folder.'**
  String get chooseAWritableAndroidFolder;

  /// No description provided for @chooseDocument.
  ///
  /// In en, this message translates to:
  /// **'Choose Document'**
  String get chooseDocument;

  /// No description provided for @chooseFolder.
  ///
  /// In en, this message translates to:
  /// **'Choose Folder'**
  String get chooseFolder;

  /// No description provided for @chooseSAFFolder.
  ///
  /// In en, this message translates to:
  /// **'Choose SAF Folder'**
  String get chooseSAFFolder;

  /// No description provided for @chooseSyncFile.
  ///
  /// In en, this message translates to:
  /// **'Choose sync file'**
  String get chooseSyncFile;

  /// No description provided for @clear.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get clear;

  /// No description provided for @clearCache.
  ///
  /// In en, this message translates to:
  /// **'Clear cache'**
  String get clearCache;

  /// No description provided for @clearCachedFieldTypes.
  ///
  /// In en, this message translates to:
  /// **'Clear cached field types'**
  String get clearCachedFieldTypes;

  /// No description provided for @clearCachedFieldTypes2.
  ///
  /// In en, this message translates to:
  /// **'Clear cached field types?'**
  String get clearCachedFieldTypes2;

  /// No description provided for @clearEditableFields.
  ///
  /// In en, this message translates to:
  /// **'Clear editable fields'**
  String get clearEditableFields;

  /// No description provided for @clearEditor.
  ///
  /// In en, this message translates to:
  /// **'Clear editor'**
  String get clearEditor;

  /// No description provided for @clearNote.
  ///
  /// In en, this message translates to:
  /// **'Clear note'**
  String get clearNote;

  /// No description provided for @clearRememberedCloudFile.
  ///
  /// In en, this message translates to:
  /// **'Clear remembered cloud file'**
  String get clearRememberedCloudFile;

  /// No description provided for @clearRememberedLocalFile.
  ///
  /// In en, this message translates to:
  /// **'Clear remembered local file'**
  String get clearRememberedLocalFile;

  /// No description provided for @close.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get close;

  /// No description provided for @closeTemplates.
  ///
  /// In en, this message translates to:
  /// **'Close templates'**
  String get closeTemplates;

  /// No description provided for @cloud.
  ///
  /// In en, this message translates to:
  /// **'Cloud'**
  String get cloud;

  /// No description provided for @cloudDocument.
  ///
  /// In en, this message translates to:
  /// **'Cloud document'**
  String get cloudDocument;

  /// No description provided for @cloudSettings.
  ///
  /// In en, this message translates to:
  /// **'Cloud Settings'**
  String get cloudSettings;

  /// No description provided for @column.
  ///
  /// In en, this message translates to:
  /// **'Column'**
  String get column;

  /// No description provided for @confirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get confirm;

  /// No description provided for @confirmFieldFormats.
  ///
  /// In en, this message translates to:
  /// **'Confirm field formats'**
  String get confirmFieldFormats;

  /// No description provided for @confirmNewPassword.
  ///
  /// In en, this message translates to:
  /// **'Confirm new password'**
  String get confirmNewPassword;

  /// No description provided for @confirmPassword.
  ///
  /// In en, this message translates to:
  /// **'Confirm password'**
  String get confirmPassword;

  /// No description provided for @connectACloudProviderInSettingsFirst.
  ///
  /// In en, this message translates to:
  /// **'Connect a cloud provider in Settings first.'**
  String get connectACloudProviderInSettingsFirst;

  /// No description provided for @connectGoogleDrive.
  ///
  /// In en, this message translates to:
  /// **'Connect Google Drive'**
  String get connectGoogleDrive;

  /// No description provided for @continueLabel.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get continueLabel;

  /// No description provided for @couldNotAcquireAWritableSAFFolderURI.
  ///
  /// In en, this message translates to:
  /// **'Could not acquire a writable SAF folder URI.'**
  String get couldNotAcquireAWritableSAFFolderURI;

  /// No description provided for @couldNotOpenTheFileInAnotherApp.
  ///
  /// In en, this message translates to:
  /// **'Could not open the file in another app.'**
  String get couldNotOpenTheFileInAnotherApp;

  /// No description provided for @couldNotReadCSVFileContent.
  ///
  /// In en, this message translates to:
  /// **'Could not read CSV file content.'**
  String get couldNotReadCSVFileContent;

  /// No description provided for @couldNotReopenTheRememberedLocalFileChooseItAgain.
  ///
  /// In en, this message translates to:
  /// **'Could not reopen the remembered local file. Choose it again.'**
  String get couldNotReopenTheRememberedLocalFileChooseItAgain;

  /// No description provided for @currentFileIsNotSAFBackedUseSaveAsIsInPreviewOrReopenViaSAF.
  ///
  /// In en, this message translates to:
  /// **'Current file is not SAF-backed. Use \"Save as is\" in Preview, or reopen via SAF.'**
  String get currentFileIsNotSAFBackedUseSaveAsIsInPreviewOrReopenViaSAF;

  /// No description provided for @couldNotOpenSavedSyncFileChooseAnotherOne.
  ///
  /// In en, this message translates to:
  /// **'Could not open saved sync file. Choose another one.'**
  String get couldNotOpenSavedSyncFileChooseAnotherOne;

  /// No description provided for @couldNotSendPasswordResetCode.
  ///
  /// In en, this message translates to:
  /// **'Could not send password reset code.'**
  String get couldNotSendPasswordResetCode;

  /// No description provided for @crashLogsNonFatalErrorsAndPerformanceMonitoringToDiagnoseFailuresAndSlowPaths.
  ///
  /// In en, this message translates to:
  /// **'Crash logs, non-fatal errors, and performance monitoring to diagnose failures and slow paths.'**
  String
  get crashLogsNonFatalErrorsAndPerformanceMonitoringToDiagnoseFailuresAndSlowPaths;

  /// No description provided for @crashReportsAndPerformance.
  ///
  /// In en, this message translates to:
  /// **'Crash reports and performance'**
  String get crashReportsAndPerformance;

  /// No description provided for @createAccount.
  ///
  /// In en, this message translates to:
  /// **'Create account'**
  String get createAccount;

  /// No description provided for @createDocument.
  ///
  /// In en, this message translates to:
  /// **'Create Document'**
  String get createDocument;

  /// No description provided for @createDocumentCanceled.
  ///
  /// In en, this message translates to:
  /// **'Create document canceled.'**
  String get createDocumentCanceled;

  /// No description provided for @createCSV.
  ///
  /// In en, this message translates to:
  /// **'Create CSV'**
  String get createCSV;

  /// No description provided for @createXLSX.
  ///
  /// In en, this message translates to:
  /// **'Create XLSX'**
  String get createXLSX;

  /// No description provided for @createODS.
  ///
  /// In en, this message translates to:
  /// **'Create ODS'**
  String get createODS;

  /// No description provided for @createNew.
  ///
  /// In en, this message translates to:
  /// **'Create New'**
  String get createNew;

  /// No description provided for @createNew2.
  ///
  /// In en, this message translates to:
  /// **'Create new'**
  String get createNew2;

  /// No description provided for @createNewEntryMode.
  ///
  /// In en, this message translates to:
  /// **'Create new entry mode.'**
  String get createNewEntryMode;

  /// No description provided for @createNewEntry.
  ///
  /// In en, this message translates to:
  /// **'Create new entry'**
  String get createNewEntry;

  /// No description provided for @createNewCSV.
  ///
  /// In en, this message translates to:
  /// **'Create New CSV'**
  String get createNewCSV;

  /// No description provided for @currentBehavior.
  ///
  /// In en, this message translates to:
  /// **'Current behavior'**
  String get currentBehavior;

  /// No description provided for @currentFile.
  ///
  /// In en, this message translates to:
  /// **'Current File'**
  String get currentFile;

  /// No description provided for @dataCollection.
  ///
  /// In en, this message translates to:
  /// **'Data Collection'**
  String get dataCollection;

  /// No description provided for @dataCollection2.
  ///
  /// In en, this message translates to:
  /// **'Data collection'**
  String get dataCollection2;

  /// No description provided for @date.
  ///
  /// In en, this message translates to:
  /// **'Date'**
  String get date;

  /// No description provided for @defaultLabel.
  ///
  /// In en, this message translates to:
  /// **'default'**
  String get defaultLabel;

  /// No description provided for @dateBasedOpenEndNeedsADetectedDateColumn.
  ///
  /// In en, this message translates to:
  /// **'Date-based open-end needs a detected date column.'**
  String get dateBasedOpenEndNeedsADetectedDateColumn;

  /// No description provided for @deleteAccount.
  ///
  /// In en, this message translates to:
  /// **'Delete Account'**
  String get deleteAccount;

  /// No description provided for @deleteAccount2.
  ///
  /// In en, this message translates to:
  /// **'Delete account'**
  String get deleteAccount2;

  /// No description provided for @defineColumnsAndFieldTypesForAFreshSheet.
  ///
  /// In en, this message translates to:
  /// **'Define columns and field types for a fresh sheet.'**
  String get defineColumnsAndFieldTypesForAFreshSheet;

  /// No description provided for @details.
  ///
  /// In en, this message translates to:
  /// **'Details'**
  String get details;

  /// No description provided for @summary.
  ///
  /// In en, this message translates to:
  /// **'Summary'**
  String get summary;

  /// No description provided for @kind.
  ///
  /// In en, this message translates to:
  /// **'Kind'**
  String get kind;

  /// No description provided for @origin.
  ///
  /// In en, this message translates to:
  /// **'Origin'**
  String get origin;

  /// No description provided for @requestHost.
  ///
  /// In en, this message translates to:
  /// **'Request host'**
  String get requestHost;

  /// No description provided for @requestPath.
  ///
  /// In en, this message translates to:
  /// **'Request path'**
  String get requestPath;

  /// No description provided for @requestMethod.
  ///
  /// In en, this message translates to:
  /// **'Request method'**
  String get requestMethod;

  /// No description provided for @requiredCORSMethods.
  ///
  /// In en, this message translates to:
  /// **'Required CORS methods'**
  String get requiredCORSMethods;

  /// No description provided for @requiredCORSHeaders.
  ///
  /// In en, this message translates to:
  /// **'Required CORS headers'**
  String get requiredCORSHeaders;

  /// No description provided for @technicalDetails.
  ///
  /// In en, this message translates to:
  /// **'Technical details'**
  String get technicalDetails;

  /// No description provided for @unknown.
  ///
  /// In en, this message translates to:
  /// **'unknown'**
  String get unknown;

  /// No description provided for @browserBlocked.
  ///
  /// In en, this message translates to:
  /// **'browser_blocked'**
  String get browserBlocked;

  /// No description provided for @network.
  ///
  /// In en, this message translates to:
  /// **'network'**
  String get network;

  /// No description provided for @auth.
  ///
  /// In en, this message translates to:
  /// **'auth'**
  String get auth;

  /// No description provided for @methodNotAllowed.
  ///
  /// In en, this message translates to:
  /// **'method_not_allowed'**
  String get methodNotAllowed;

  /// No description provided for @desktopToMobileOptimizedToFit.
  ///
  /// In en, this message translates to:
  /// **'Desktop to mobile, optimized to fit.'**
  String get desktopToMobileOptimizedToFit;

  /// No description provided for @diary.
  ///
  /// In en, this message translates to:
  /// **'Diary'**
  String get diary;

  /// No description provided for @discard.
  ///
  /// In en, this message translates to:
  /// **'Discard'**
  String get discard;

  /// No description provided for @editorCleared.
  ///
  /// In en, this message translates to:
  /// **'Editor cleared.'**
  String get editorCleared;

  /// No description provided for @email.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get email;

  /// No description provided for @end.
  ///
  /// In en, this message translates to:
  /// **'End'**
  String get end;

  /// No description provided for @enterAppPassword.
  ///
  /// In en, this message translates to:
  /// **'Enter app password'**
  String get enterAppPassword;

  /// No description provided for @entitlement.
  ///
  /// In en, this message translates to:
  /// **'Entitlement'**
  String get entitlement;

  /// No description provided for @everyTemplateStartsWithDateAsTheFirstColumn.
  ///
  /// In en, this message translates to:
  /// **'Every template starts with Date as the first column.'**
  String get everyTemplateStartsWithDateAsTheFirstColumn;

  /// No description provided for @explainOpeningModes.
  ///
  /// In en, this message translates to:
  /// **'Explain opening modes'**
  String get explainOpeningModes;

  /// No description provided for @falseLabel.
  ///
  /// In en, this message translates to:
  /// **'FALSE'**
  String get falseLabel;

  /// No description provided for @fieldFormatsConfirmed.
  ///
  /// In en, this message translates to:
  /// **'Field formats confirmed.'**
  String get fieldFormatsConfirmed;

  /// No description provided for @fields.
  ///
  /// In en, this message translates to:
  /// **'Fields'**
  String get fields;

  /// No description provided for @fileName.
  ///
  /// In en, this message translates to:
  /// **'File name'**
  String get fileName;

  /// No description provided for @focusedRowEditing.
  ///
  /// In en, this message translates to:
  /// **'Focused row editing'**
  String get focusedRowEditing;

  /// No description provided for @focusedRowIsHighlighted.
  ///
  /// In en, this message translates to:
  /// **'Focused row is highlighted'**
  String get focusedRowIsHighlighted;

  /// No description provided for @focusBlockersWins.
  ///
  /// In en, this message translates to:
  /// **'Focus, blockers, wins...'**
  String get focusBlockersWins;

  /// No description provided for @folder.
  ///
  /// In en, this message translates to:
  /// **'Folder'**
  String get folder;

  /// No description provided for @forgotPassword.
  ///
  /// In en, this message translates to:
  /// **'Forgot password?'**
  String get forgotPassword;

  /// No description provided for @freePlan.
  ///
  /// In en, this message translates to:
  /// **'Free plan'**
  String get freePlan;

  /// No description provided for @gotIt.
  ///
  /// In en, this message translates to:
  /// **'Got it'**
  String get gotIt;

  /// No description provided for @helpImproveCalcrow.
  ///
  /// In en, this message translates to:
  /// **'Help Improve Calcrow'**
  String get helpImproveCalcrow;

  /// No description provided for @hours.
  ///
  /// In en, this message translates to:
  /// **'Hours'**
  String get hours;

  /// No description provided for @howToOpenTheSheet.
  ///
  /// In en, this message translates to:
  /// **'How to open the sheet'**
  String get howToOpenTheSheet;

  /// No description provided for @iAgreeToTheTermsOfUsePrivacyPolicyAndAdsPrivacyPolicy.
  ///
  /// In en, this message translates to:
  /// **'I agree to the Terms of Use, Privacy Policy, and Ads Privacy Policy.'**
  String get iAgreeToTheTermsOfUsePrivacyPolicyAndAdsPrivacyPolicy;

  /// No description provided for @iAlreadyHaveAnAccount.
  ///
  /// In en, this message translates to:
  /// **'I already have an account'**
  String get iAlreadyHaveAnAccount;

  /// No description provided for @ifPhoneWorksButWebFailsThisIsUsuallyCORSTLSOnTheWebDAVServer.
  ///
  /// In en, this message translates to:
  /// **'If phone works but web fails, this is usually CORS/TLS on the WebDAV server.'**
  String get ifPhoneWorksButWebFailsThisIsUsuallyCORSTLSOnTheWebDAVServer;

  /// No description provided for @keepOff.
  ///
  /// In en, this message translates to:
  /// **'Keep Off'**
  String get keepOff;

  /// No description provided for @link.
  ///
  /// In en, this message translates to:
  /// **'Link'**
  String get link;

  /// No description provided for @linkWebDAVNextcloud.
  ///
  /// In en, this message translates to:
  /// **'Link WebDAV / Nextcloud'**
  String get linkWebDAVNextcloud;

  /// No description provided for @local.
  ///
  /// In en, this message translates to:
  /// **'Local'**
  String get local;

  /// No description provided for @localDocument.
  ///
  /// In en, this message translates to:
  /// **'Local document'**
  String get localDocument;

  /// No description provided for @logbook.
  ///
  /// In en, this message translates to:
  /// **'Logbook'**
  String get logbook;

  /// No description provided for @manageSAFFolder.
  ///
  /// In en, this message translates to:
  /// **'Manage SAF folder'**
  String get manageSAFFolder;

  /// No description provided for @localAccess.
  ///
  /// In en, this message translates to:
  /// **'Local Access'**
  String get localAccess;

  /// No description provided for @manageLocalAndroidFolderAccess.
  ///
  /// In en, this message translates to:
  /// **'Manage Android folder access for local documents.'**
  String get manageLocalAndroidFolderAccess;

  /// No description provided for @manageSeparateConsentForUsageAnalyticsAndCrashOrPerformanceDiagnostics.
  ///
  /// In en, this message translates to:
  /// **'Manage separate consent for usage analytics and crash or performance diagnostics.'**
  String
  get manageSeparateConsentForUsageAnalyticsAndCrashOrPerformanceDiagnostics;

  /// No description provided for @manageWebDAVEntries.
  ///
  /// In en, this message translates to:
  /// **'Manage WebDAV entries'**
  String get manageWebDAVEntries;

  /// No description provided for @manage.
  ///
  /// In en, this message translates to:
  /// **'Manage'**
  String get manage;

  /// No description provided for @manageGoogleDriveAndWebDAVConnections.
  ///
  /// In en, this message translates to:
  /// **'Manage Google Drive and WebDAV connections.'**
  String get manageGoogleDriveAndWebDAVConnections;

  /// No description provided for @manageYourSubscriptionPrivacyAndAccountAccess.
  ///
  /// In en, this message translates to:
  /// **'Manage your subscription, privacy, and account access.'**
  String get manageYourSubscriptionPrivacyAndAccountAccess;

  /// No description provided for @manageWidgets.
  ///
  /// In en, this message translates to:
  /// **'Manage widgets'**
  String get manageWidgets;

  /// No description provided for @minutes.
  ///
  /// In en, this message translates to:
  /// **'Minutes'**
  String get minutes;

  /// No description provided for @mobileTwoColumnView.
  ///
  /// In en, this message translates to:
  /// **'Mobile two-column view'**
  String get mobileTwoColumnView;

  /// No description provided for @monthly.
  ///
  /// In en, this message translates to:
  /// **'Monthly'**
  String get monthly;

  /// No description provided for @moveDown.
  ///
  /// In en, this message translates to:
  /// **'Move down'**
  String get moveDown;

  /// No description provided for @moveUp.
  ///
  /// In en, this message translates to:
  /// **'Move up'**
  String get moveUp;

  /// No description provided for @namelist.
  ///
  /// In en, this message translates to:
  /// **'Namelist'**
  String get namelist;

  /// No description provided for @newLabel.
  ///
  /// In en, this message translates to:
  /// **'New'**
  String get newLabel;

  /// No description provided for @newPassword.
  ///
  /// In en, this message translates to:
  /// **'New password'**
  String get newPassword;

  /// No description provided for @newRowSubmitted.
  ///
  /// In en, this message translates to:
  /// **'New row submitted.'**
  String get newRowSubmitted;

  /// No description provided for @noAccountEmailIsAvailable.
  ///
  /// In en, this message translates to:
  /// **'No account email is available.'**
  String get noAccountEmailIsAvailable;

  /// No description provided for @noEditableFieldTypesToReset.
  ///
  /// In en, this message translates to:
  /// **'No editable field types to reset.'**
  String get noEditableFieldTypesToReset;

  /// No description provided for @noEntryFoundForThisDate.
  ///
  /// In en, this message translates to:
  /// **'No entry found for this date.'**
  String get noEntryFoundForThisDate;

  /// No description provided for @noFileLoadedYet.
  ///
  /// In en, this message translates to:
  /// **'No file loaded yet.'**
  String get noFileLoadedYet;

  /// No description provided for @noEmailAvailable.
  ///
  /// In en, this message translates to:
  /// **'No email available.'**
  String get noEmailAvailable;

  /// No description provided for @noSAFFolderConfigured.
  ///
  /// In en, this message translates to:
  /// **'No SAF folder configured.'**
  String get noSAFFolderConfigured;

  /// No description provided for @noRecentOpeningConfigurationsSavedYet.
  ///
  /// In en, this message translates to:
  /// **'No recent opening configurations saved yet.'**
  String get noRecentOpeningConfigurationsSavedYet;

  /// No description provided for @noSAFTargetSelectedOpenASAFBackedFileOrConfigureSAFFolderInSettingsOrUseSaveAsIsInPreview.
  ///
  /// In en, this message translates to:
  /// **'No SAF target selected. Open a SAF-backed file or configure SAF folder in Settings, or use \"Save as is\" in Preview.'**
  String
  get noSAFTargetSelectedOpenASAFBackedFileOrConfigureSAFFolderInSettingsOrUseSaveAsIsInPreview;

  /// No description provided for @noteThisSheetIsJustAnExample.
  ///
  /// In en, this message translates to:
  /// **'Note: this sheet is just an example'**
  String get noteThisSheetIsJustAnExample;

  /// No description provided for @notes.
  ///
  /// In en, this message translates to:
  /// **'Notes'**
  String get notes;

  /// No description provided for @openACSVXLSXOrODSDocument.
  ///
  /// In en, this message translates to:
  /// **'Open a CSV, XLSX, or ODS document'**
  String get openACSVXLSXOrODSDocument;

  /// No description provided for @openCSVXLSXOrODS.
  ///
  /// In en, this message translates to:
  /// **'Open CSV, XLSX, or ODS.'**
  String get openCSVXLSXOrODS;

  /// No description provided for @openTheExistingRowForTodayAndKeepOneEntryPerDay.
  ///
  /// In en, this message translates to:
  /// **'Open the existing row for today and keep one entry per day.'**
  String get openTheExistingRowForTodayAndKeepOneEntryPerDay;

  /// No description provided for @openTodayIfItExistsOtherwiseStartANewRowForToday.
  ///
  /// In en, this message translates to:
  /// **'Open today if it exists, otherwise start a new row for today.'**
  String get openTodayIfItExistsOtherwiseStartANewRowForToday;

  /// No description provided for @chooseAnExistingNamedEntryFromATextColumnAndEditThatRow.
  ///
  /// In en, this message translates to:
  /// **'Choose an existing named entry from a text column and edit that row.'**
  String get chooseAnExistingNamedEntryFromATextColumnAndEditThatRow;

  /// No description provided for @yourTableNeedsADateColumnWithOnePreparedRowPerDay.
  ///
  /// In en, this message translates to:
  /// **'Your table needs a date column with one prepared row per day.'**
  String get yourTableNeedsADateColumnWithOnePreparedRowPerDay;

  /// No description provided for @yourTableNeedsADateColumnCalcrowCanAddTodayAsANewRow.
  ///
  /// In en, this message translates to:
  /// **'Your table needs a date column; Calcrow can add today as a new row.'**
  String get yourTableNeedsADateColumnCalcrowCanAddTodayAsANewRow;

  /// No description provided for @yourTableNeedsAnEditableTextColumnWithTheEntryNames.
  ///
  /// In en, this message translates to:
  /// **'Your table needs an editable text column with the entry names.'**
  String get yourTableNeedsAnEditableTextColumnWithTheEntryNames;

  /// No description provided for @openSubscriptionAndPurchaseOptions.
  ///
  /// In en, this message translates to:
  /// **'Open subscription and purchase options.'**
  String get openSubscriptionAndPurchaseOptions;

  /// No description provided for @openCSVXLSXOrODSCalcrowDetectsTheFileTypeAutomatically.
  ///
  /// In en, this message translates to:
  /// **'Open CSV, XLSX, or ODS. Calcrow detects the file type automatically.'**
  String get openCSVXLSXOrODSCalcrowDetectsTheFileTypeAutomatically;

  /// No description provided for @openCSVXLSXOrODSFilesEditTheFocusedRowInCoreEditorAndSaveBackToLocalOrCloudStorage.
  ///
  /// In en, this message translates to:
  /// **'Open CSV, XLSX, or ODS files, edit the focused row in core editor, and save back to local or cloud storage.'**
  String
  get openCSVXLSXOrODSFilesEditTheFocusedRowInCoreEditorAndSaveBackToLocalOrCloudStorage;

  /// No description provided for @openedDocumentInAnotherApp.
  ///
  /// In en, this message translates to:
  /// **'Opened document in another app.'**
  String get openedDocumentInAnotherApp;

  /// No description provided for @openingDocument.
  ///
  /// In en, this message translates to:
  /// **'Opening document...'**
  String get openingDocument;

  /// No description provided for @openingMode.
  ///
  /// In en, this message translates to:
  /// **'Opening Mode'**
  String get openingMode;

  /// No description provided for @openingMode2.
  ///
  /// In en, this message translates to:
  /// **'Opening mode'**
  String get openingMode2;

  /// No description provided for @openingModes.
  ///
  /// In en, this message translates to:
  /// **'Opening modes'**
  String get openingModes;

  /// No description provided for @password.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get password;

  /// No description provided for @passwordUpdated.
  ///
  /// In en, this message translates to:
  /// **'Password updated.'**
  String get passwordUpdated;

  /// No description provided for @passwordUpdatedYouCanSignInNow.
  ///
  /// In en, this message translates to:
  /// **'Password updated. You can sign in now.'**
  String get passwordUpdatedYouCanSignInNow;

  /// No description provided for @pauseMin.
  ///
  /// In en, this message translates to:
  /// **'Pause (min)'**
  String get pauseMin;

  /// No description provided for @pickSAFFolder.
  ///
  /// In en, this message translates to:
  /// **'Pick SAF folder'**
  String get pickSAFFolder;

  /// No description provided for @pickRow.
  ///
  /// In en, this message translates to:
  /// **'Pick row'**
  String get pickRow;

  /// No description provided for @pickRow2.
  ///
  /// In en, this message translates to:
  /// **'Pick Row'**
  String get pickRow2;

  /// No description provided for @pickEntry.
  ///
  /// In en, this message translates to:
  /// **'Pick Entry'**
  String get pickEntry;

  /// No description provided for @preparingEditorFields.
  ///
  /// In en, this message translates to:
  /// **'Preparing editor fields...'**
  String get preparingEditorFields;

  /// No description provided for @previous.
  ///
  /// In en, this message translates to:
  /// **'Previous'**
  String get previous;

  /// No description provided for @privacyControls.
  ///
  /// In en, this message translates to:
  /// **'Privacy controls'**
  String get privacyControls;

  /// No description provided for @privacyPolicy.
  ///
  /// In en, this message translates to:
  /// **'Privacy Policy'**
  String get privacyPolicy;

  /// No description provided for @proEnabled.
  ///
  /// In en, this message translates to:
  /// **'Pro enabled.'**
  String get proEnabled;

  /// No description provided for @readHowCalcrowAndGoogleAdMobHandleConsentChoicesForTheEEAUKSwitzerlandAndApplicableUSStatePrivacyRules.
  ///
  /// In en, this message translates to:
  /// **'Read how Calcrow and Google AdMob handle consent choices for the EEA, UK, Switzerland, and applicable US state privacy rules.'**
  String
  get readHowCalcrowAndGoogleAdMobHandleConsentChoicesForTheEEAUKSwitzerlandAndApplicableUSStatePrivacyRules;

  /// No description provided for @rememberedCloudSyncFileCleared.
  ///
  /// In en, this message translates to:
  /// **'Remembered cloud sync file cleared.'**
  String get rememberedCloudSyncFileCleared;

  /// No description provided for @rememberedLocalFileClearedPickAFileAgainAnytime.
  ///
  /// In en, this message translates to:
  /// **'Remembered local file cleared. Pick a file again anytime.'**
  String get rememberedLocalFileClearedPickAFileAgainAnytime;

  /// No description provided for @removeColumn.
  ///
  /// In en, this message translates to:
  /// **'Remove column'**
  String get removeColumn;

  /// No description provided for @removeOneEntry.
  ///
  /// In en, this message translates to:
  /// **'Remove one entry'**
  String get removeOneEntry;

  /// No description provided for @removeWebDAVEntry.
  ///
  /// In en, this message translates to:
  /// **'Remove WebDAV entry'**
  String get removeWebDAVEntry;

  /// No description provided for @resendCode.
  ///
  /// In en, this message translates to:
  /// **'Resend code'**
  String get resendCode;

  /// No description provided for @reset.
  ///
  /// In en, this message translates to:
  /// **'Reset'**
  String get reset;

  /// No description provided for @resetAdConsent.
  ///
  /// In en, this message translates to:
  /// **'Reset ad consent'**
  String get resetAdConsent;

  /// No description provided for @resetAdConsent2.
  ///
  /// In en, this message translates to:
  /// **'Reset ad consent?'**
  String get resetAdConsent2;

  /// No description provided for @resetCode.
  ///
  /// In en, this message translates to:
  /// **'Reset code'**
  String get resetCode;

  /// No description provided for @rowUpdatedFileSaveCanceled.
  ///
  /// In en, this message translates to:
  /// **'Row updated. File save canceled.'**
  String get rowUpdatedFileSaveCanceled;

  /// No description provided for @rowDefinement.
  ///
  /// In en, this message translates to:
  /// **'Row-Definement'**
  String get rowDefinement;

  /// No description provided for @row.
  ///
  /// In en, this message translates to:
  /// **'Row'**
  String get row;

  /// No description provided for @safFolderCleared.
  ///
  /// In en, this message translates to:
  /// **'SAF folder cleared.'**
  String get safFolderCleared;

  /// No description provided for @safFolderSelectionCanceled.
  ///
  /// In en, this message translates to:
  /// **'SAF folder selection canceled.'**
  String get safFolderSelectionCanceled;

  /// No description provided for @safFolderSetupIsAndroidOnly.
  ///
  /// In en, this message translates to:
  /// **'SAF folder setup is Android-only.'**
  String get safFolderSetupIsAndroidOnly;

  /// No description provided for @safSaveCanceledUseSaveAsIsInPreview.
  ///
  /// In en, this message translates to:
  /// **'SAF save canceled. Use \"Save as is\" in Preview.'**
  String get safSaveCanceledUseSaveAsIsInPreview;

  /// No description provided for @safSaveIsNotAvailableHereUseSaveAsIsInPreview.
  ///
  /// In en, this message translates to:
  /// **'SAF save is not available here. Use \"Save as is\" in Preview.'**
  String get safSaveIsNotAvailableHereUseSaveAsIsInPreview;

  /// No description provided for @safStreamWriteFailedUseSaveAsIsInPreview.
  ///
  /// In en, this message translates to:
  /// **'SAF stream write failed. Use \"Save as is\" in Preview.'**
  String get safStreamWriteFailedUseSaveAsIsInPreview;

  /// No description provided for @sameRowCompactedForMobileScreens.
  ///
  /// In en, this message translates to:
  /// **'Same row, compacted for mobile screens'**
  String get sameRowCompactedForMobileScreens;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @saveChoices.
  ///
  /// In en, this message translates to:
  /// **'Save Choices'**
  String get saveChoices;

  /// No description provided for @saveIntoTheFolderConfiguredInSettings.
  ///
  /// In en, this message translates to:
  /// **'Save into the folder configured in Settings.'**
  String get saveIntoTheFolderConfiguredInSettings;

  /// No description provided for @saveNewDocument.
  ///
  /// In en, this message translates to:
  /// **'Save New Document'**
  String get saveNewDocument;

  /// No description provided for @saveTheCurrentRowBeforeStartingANewOne.
  ///
  /// In en, this message translates to:
  /// **'Save the current row before starting a new one?'**
  String get saveTheCurrentRowBeforeStartingANewOne;

  /// No description provided for @scanPasskeyQR.
  ///
  /// In en, this message translates to:
  /// **'Scan passkey QR'**
  String get scanPasskeyQR;

  /// No description provided for @selectActiveEntry.
  ///
  /// In en, this message translates to:
  /// **'Select active entry'**
  String get selectActiveEntry;

  /// No description provided for @selectLocalFile.
  ///
  /// In en, this message translates to:
  /// **'Select Local File'**
  String get selectLocalFile;

  /// No description provided for @selectWebDAVEntry.
  ///
  /// In en, this message translates to:
  /// **'Select WebDAV entry'**
  String get selectWebDAVEntry;

  /// No description provided for @selectCurrency.
  ///
  /// In en, this message translates to:
  /// **'Select currency'**
  String get selectCurrency;

  /// No description provided for @selectDate.
  ///
  /// In en, this message translates to:
  /// **'Select date'**
  String get selectDate;

  /// No description provided for @selector.
  ///
  /// In en, this message translates to:
  /// **'Selector'**
  String get selector;

  /// No description provided for @set.
  ///
  /// In en, this message translates to:
  /// **'Set'**
  String get set;

  /// No description provided for @setRecent.
  ///
  /// In en, this message translates to:
  /// **'Set Recent'**
  String get setRecent;

  /// No description provided for @setRecent2.
  ///
  /// In en, this message translates to:
  /// **'Set recent'**
  String get setRecent2;

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// No description provided for @sheetManipulationOnTheGo.
  ///
  /// In en, this message translates to:
  /// **'Sheet manipulation on the go.'**
  String get sheetManipulationOnTheGo;

  /// No description provided for @sheetSeparation.
  ///
  /// In en, this message translates to:
  /// **'Sheet separation'**
  String get sheetSeparation;

  /// No description provided for @sheet.
  ///
  /// In en, this message translates to:
  /// **'Sheet'**
  String get sheet;

  /// No description provided for @sheetPreview.
  ///
  /// In en, this message translates to:
  /// **'Sheet Preview'**
  String get sheetPreview;

  /// No description provided for @signIn.
  ///
  /// In en, this message translates to:
  /// **'Sign in'**
  String get signIn;

  /// No description provided for @signInOrCreateAccount.
  ///
  /// In en, this message translates to:
  /// **'Sign in or create account'**
  String get signInOrCreateAccount;

  /// No description provided for @signInToSaveThisAndroidFolderSettingToYourAccount.
  ///
  /// In en, this message translates to:
  /// **'Sign in to save this Android folder setting to your account.'**
  String get signInToSaveThisAndroidFolderSettingToYourAccount;

  /// No description provided for @signInToUseCalcrow.
  ///
  /// In en, this message translates to:
  /// **'Sign in to use Calcrow.'**
  String get signInToUseCalcrow;

  /// No description provided for @signInToUseRecentOpeningConfigurations.
  ///
  /// In en, this message translates to:
  /// **'Sign in to use recent opening configurations.'**
  String get signInToUseRecentOpeningConfigurations;

  /// No description provided for @signOut.
  ///
  /// In en, this message translates to:
  /// **'Sign out'**
  String get signOut;

  /// No description provided for @signedInAs.
  ///
  /// In en, this message translates to:
  /// **'Signed in as'**
  String get signedInAs;

  /// No description provided for @signedInWelcomeToCalcrow.
  ///
  /// In en, this message translates to:
  /// **'Signed in. Welcome to Calcrow.'**
  String get signedInWelcomeToCalcrow;

  /// No description provided for @signedOut.
  ///
  /// In en, this message translates to:
  /// **'Signed out'**
  String get signedOut;

  /// No description provided for @smartData.
  ///
  /// In en, this message translates to:
  /// **'Smart Data'**
  String get smartData;

  /// No description provided for @start.
  ///
  /// In en, this message translates to:
  /// **'Start'**
  String get start;

  /// No description provided for @startFromAFreshMonthlySheet.
  ///
  /// In en, this message translates to:
  /// **'Start from a fresh monthly sheet'**
  String get startFromAFreshMonthlySheet;

  /// No description provided for @support.
  ///
  /// In en, this message translates to:
  /// **'Support'**
  String get support;

  /// No description provided for @templates.
  ///
  /// In en, this message translates to:
  /// **'Templates'**
  String get templates;

  /// No description provided for @terms.
  ///
  /// In en, this message translates to:
  /// **'Terms'**
  String get terms;

  /// No description provided for @termsOfUse.
  ///
  /// In en, this message translates to:
  /// **'Terms of Use'**
  String get termsOfUse;

  /// No description provided for @textBasedOpeningNeedsAtLeastOneEditableTextColumnForNewEntries.
  ///
  /// In en, this message translates to:
  /// **'Text-based opening needs at least one editable text column for new entries.'**
  String get textBasedOpeningNeedsAtLeastOneEditableTextColumnForNewEntries;

  /// No description provided for @theSelectedCSVIsEmpty.
  ///
  /// In en, this message translates to:
  /// **'The selected CSV is empty.'**
  String get theSelectedCSVIsEmpty;

  /// No description provided for @thisFolderHasNoSubfolders.
  ///
  /// In en, this message translates to:
  /// **'This folder has no subfolders.'**
  String get thisFolderHasNoSubfolders;

  /// No description provided for @thisFolderHasNoSupportedCSVXLSXOrODSFilesYetOpenAnotherFolderOrCreateANewSyncFileHere.
  ///
  /// In en, this message translates to:
  /// **'This folder has no supported CSV, XLSX, or ODS files yet. Open another folder or create a new sync file here.'**
  String
  get thisFolderHasNoSupportedCSVXLSXOrODSFilesYetOpenAnotherFolderOrCreateANewSyncFileHere;

  /// No description provided for @thisSAFSourceCannotBeOverwrittenDirectlyReopenFromAWritableFolderViaSAFOrUseSaveAsIs.
  ///
  /// In en, this message translates to:
  /// **'This SAF source cannot be overwritten directly. Reopen from a writable folder via SAF, or use \"Save as is\".'**
  String
  get thisSAFSourceCannotBeOverwrittenDirectlyReopenFromAWritableFolderViaSAFOrUseSaveAsIs;

  /// No description provided for @thisWebDAVEntryIsAlreadyActive.
  ///
  /// In en, this message translates to:
  /// **'This WebDAV entry is already active.'**
  String get thisWebDAVEntryIsAlreadyActive;

  /// No description provided for @total.
  ///
  /// In en, this message translates to:
  /// **'Total'**
  String get total;

  /// No description provided for @trueLabel.
  ///
  /// In en, this message translates to:
  /// **'TRUE'**
  String get trueLabel;

  /// No description provided for @type.
  ///
  /// In en, this message translates to:
  /// **'Type'**
  String get type;

  /// No description provided for @unlinkAllEntries.
  ///
  /// In en, this message translates to:
  /// **'Unlink all entries'**
  String get unlinkAllEntries;

  /// No description provided for @unlink.
  ///
  /// In en, this message translates to:
  /// **'Unlink'**
  String get unlink;

  /// No description provided for @unsavedRowEdits.
  ///
  /// In en, this message translates to:
  /// **'Unsaved row edits'**
  String get unsavedRowEdits;

  /// No description provided for @update.
  ///
  /// In en, this message translates to:
  /// **'Update'**
  String get update;

  /// No description provided for @upgrade.
  ///
  /// In en, this message translates to:
  /// **'Upgrade'**
  String get upgrade;

  /// No description provided for @upOneFolder.
  ///
  /// In en, this message translates to:
  /// **'Up one folder'**
  String get upOneFolder;

  /// No description provided for @usageAnalytics.
  ///
  /// In en, this message translates to:
  /// **'Usage analytics'**
  String get usageAnalytics;

  /// No description provided for @availableOnAndroidOnly.
  ///
  /// In en, this message translates to:
  /// **'Available on Android only.'**
  String get availableOnAndroidOnly;

  /// No description provided for @connectAWebDAVOrNextcloudFolderUsingItsWebDAVURL.
  ///
  /// In en, this message translates to:
  /// **'Connect a WebDAV or Nextcloud folder using its WebDAV URL.'**
  String get connectAWebDAVOrNextcloudFolderUsingItsWebDAVURL;

  /// No description provided for @connectedToGoogleDrive.
  ///
  /// In en, this message translates to:
  /// **'Connected to Google Drive'**
  String get connectedToGoogleDrive;

  /// No description provided for @grantDriveReadWritePermissionsForCloudDocumentSync.
  ///
  /// In en, this message translates to:
  /// **'Grant Drive read/write permissions for cloud document sync.'**
  String get grantDriveReadWritePermissionsForCloudDocumentSync;

  /// No description provided for @webdavConnected.
  ///
  /// In en, this message translates to:
  /// **'WebDAV connected'**
  String get webdavConnected;

  /// No description provided for @adUnavailableNowGoogleNoFill.
  ///
  /// In en, this message translates to:
  /// **'Ad unavailable now (Google no fill).'**
  String get adUnavailableNowGoogleNoFill;

  /// No description provided for @adUnavailableDueToAppConfigIssue.
  ///
  /// In en, this message translates to:
  /// **'Ad unavailable due to app/config issue.'**
  String get adUnavailableDueToAppConfigIssue;

  /// No description provided for @adUnavailableUnknownCause.
  ///
  /// In en, this message translates to:
  /// **'Ad unavailable (unknown cause).'**
  String get adUnavailableUnknownCause;

  /// No description provided for @useCurrentSAFFolder.
  ///
  /// In en, this message translates to:
  /// **'Use current SAF folder'**
  String get useCurrentSAFFolder;

  /// No description provided for @useTheseFormats.
  ///
  /// In en, this message translates to:
  /// **'Use these formats'**
  String get useTheseFormats;

  /// No description provided for @useThisFolder.
  ///
  /// In en, this message translates to:
  /// **'Use This Folder'**
  String get useThisFolder;

  /// No description provided for @verificationCodeReissued.
  ///
  /// In en, this message translates to:
  /// **'Verification code reissued.'**
  String get verificationCodeReissued;

  /// No description provided for @webdavErrorDetails.
  ///
  /// In en, this message translates to:
  /// **'WebDAV error details'**
  String get webdavErrorDetails;

  /// No description provided for @wellbeing.
  ///
  /// In en, this message translates to:
  /// **'Wellbeing'**
  String get wellbeing;

  /// No description provided for @widgetLayoutIsLockedBecauseThisCSVAlreadyHasEntries.
  ///
  /// In en, this message translates to:
  /// **'Widget layout is locked because this CSV already has entries.'**
  String get widgetLayoutIsLockedBecauseThisCSVAlreadyHasEntries;

  /// No description provided for @workhours.
  ///
  /// In en, this message translates to:
  /// **'Workhours'**
  String get workhours;

  /// No description provided for @worklogEditor.
  ///
  /// In en, this message translates to:
  /// **'worklog editor'**
  String get worklogEditor;

  /// No description provided for @yearly.
  ///
  /// In en, this message translates to:
  /// **'Yearly'**
  String get yearly;

  /// No description provided for @accountSettings.
  ///
  /// In en, this message translates to:
  /// **'Account Settings'**
  String get accountSettings;

  /// No description provided for @advanced.
  ///
  /// In en, this message translates to:
  /// **'Advanced'**
  String get advanced;

  /// No description provided for @arrangeFields.
  ///
  /// In en, this message translates to:
  /// **'Arrange fields'**
  String get arrangeFields;

  /// No description provided for @calcrowDailyEditor.
  ///
  /// In en, this message translates to:
  /// **'Calcrow Daily Editor'**
  String get calcrowDailyEditor;

  /// No description provided for @core.
  ///
  /// In en, this message translates to:
  /// **'Core'**
  String get core;

  /// No description provided for @editor.
  ///
  /// In en, this message translates to:
  /// **'Editor'**
  String get editor;

  /// No description provided for @finishArranging.
  ///
  /// In en, this message translates to:
  /// **'Finish arranging'**
  String get finishArranging;

  /// No description provided for @getStarted.
  ///
  /// In en, this message translates to:
  /// **'Get Started'**
  String get getStarted;

  /// No description provided for @hideFieldTypes.
  ///
  /// In en, this message translates to:
  /// **'Hide field types'**
  String get hideFieldTypes;

  /// No description provided for @jumpToday.
  ///
  /// In en, this message translates to:
  /// **'Jump Today'**
  String get jumpToday;

  /// No description provided for @nextRow.
  ///
  /// In en, this message translates to:
  /// **'Next Row'**
  String get nextRow;

  /// No description provided for @pick.
  ///
  /// In en, this message translates to:
  /// **'Pick'**
  String get pick;

  /// No description provided for @showFieldTypes.
  ///
  /// In en, this message translates to:
  /// **'Show field types'**
  String get showFieldTypes;

  /// No description provided for @submitNew.
  ///
  /// In en, this message translates to:
  /// **'Submit New'**
  String get submitNew;

  /// No description provided for @text.
  ///
  /// In en, this message translates to:
  /// **'Text'**
  String get text;

  /// No description provided for @boolean.
  ///
  /// In en, this message translates to:
  /// **'boolean'**
  String get boolean;

  /// No description provided for @date2.
  ///
  /// In en, this message translates to:
  /// **'date'**
  String get date2;

  /// No description provided for @duration.
  ///
  /// In en, this message translates to:
  /// **'duration'**
  String get duration;

  /// No description provided for @email2.
  ///
  /// In en, this message translates to:
  /// **'email'**
  String get email2;

  /// No description provided for @float.
  ///
  /// In en, this message translates to:
  /// **'float'**
  String get float;

  /// No description provided for @integer.
  ///
  /// In en, this message translates to:
  /// **'integer'**
  String get integer;

  /// No description provided for @money.
  ///
  /// In en, this message translates to:
  /// **'money'**
  String get money;

  /// No description provided for @phone.
  ///
  /// In en, this message translates to:
  /// **'phone'**
  String get phone;

  /// No description provided for @text2.
  ///
  /// In en, this message translates to:
  /// **'text'**
  String get text2;

  /// No description provided for @time.
  ///
  /// In en, this message translates to:
  /// **'time'**
  String get time;

  /// No description provided for @minutesOrHHMMSS.
  ///
  /// In en, this message translates to:
  /// **'Minutes or HH:MM:SS'**
  String get minutesOrHHMMSS;

  /// No description provided for @trueOrFALSE.
  ///
  /// In en, this message translates to:
  /// **'TRUE or FALSE'**
  String get trueOrFALSE;

  /// No description provided for @amount.
  ///
  /// In en, this message translates to:
  /// **'Amount'**
  String get amount;

  /// No description provided for @bikeKm.
  ///
  /// In en, this message translates to:
  /// **'Bike km'**
  String get bikeKm;

  /// No description provided for @client.
  ///
  /// In en, this message translates to:
  /// **'Client'**
  String get client;

  /// No description provided for @clientA.
  ///
  /// In en, this message translates to:
  /// **'Client A'**
  String get clientA;

  /// No description provided for @clientB.
  ///
  /// In en, this message translates to:
  /// **'Client B'**
  String get clientB;

  /// No description provided for @clientC.
  ///
  /// In en, this message translates to:
  /// **'Client C'**
  String get clientC;

  /// No description provided for @customer.
  ///
  /// In en, this message translates to:
  /// **'Customer'**
  String get customer;

  /// No description provided for @customerService.
  ///
  /// In en, this message translates to:
  /// **'Customer Service'**
  String get customerService;

  /// No description provided for @distanceOrRepetitions.
  ///
  /// In en, this message translates to:
  /// **'Distance / Repetitions'**
  String get distanceOrRepetitions;

  /// No description provided for @durationField.
  ///
  /// In en, this message translates to:
  /// **'Duration'**
  String get durationField;

  /// No description provided for @dynamicWorkoutTracker.
  ///
  /// In en, this message translates to:
  /// **'Dynamic Workout Tracker'**
  String get dynamicWorkoutTracker;

  /// No description provided for @energy.
  ///
  /// In en, this message translates to:
  /// **'Energy'**
  String get energy;

  /// No description provided for @exercize.
  ///
  /// In en, this message translates to:
  /// **'Exercize'**
  String get exercize;

  /// No description provided for @expenses.
  ///
  /// In en, this message translates to:
  /// **'Expenses'**
  String get expenses;

  /// No description provided for @guestlist.
  ///
  /// In en, this message translates to:
  /// **'Guestlist'**
  String get guestlist;

  /// No description provided for @health.
  ///
  /// In en, this message translates to:
  /// **'Health'**
  String get health;

  /// No description provided for @invoices.
  ///
  /// In en, this message translates to:
  /// **'Invoices'**
  String get invoices;

  /// No description provided for @location.
  ///
  /// In en, this message translates to:
  /// **'Location'**
  String get location;

  /// No description provided for @mood.
  ///
  /// In en, this message translates to:
  /// **'Mood'**
  String get mood;

  /// No description provided for @name.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get name;

  /// No description provided for @phone2.
  ///
  /// In en, this message translates to:
  /// **'Phone'**
  String get phone2;

  /// No description provided for @project.
  ///
  /// In en, this message translates to:
  /// **'Project'**
  String get project;

  /// No description provided for @reps.
  ///
  /// In en, this message translates to:
  /// **'Reps'**
  String get reps;

  /// No description provided for @runKm.
  ///
  /// In en, this message translates to:
  /// **'Run km'**
  String get runKm;

  /// No description provided for @sets.
  ///
  /// In en, this message translates to:
  /// **'Sets'**
  String get sets;

  /// No description provided for @squats.
  ///
  /// In en, this message translates to:
  /// **'Squats'**
  String get squats;

  /// No description provided for @status.
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get status;

  /// No description provided for @steps.
  ///
  /// In en, this message translates to:
  /// **'Steps'**
  String get steps;

  /// No description provided for @swimKm.
  ///
  /// In en, this message translates to:
  /// **'Swim km'**
  String get swimKm;

  /// No description provided for @workDone.
  ///
  /// In en, this message translates to:
  /// **'Work done'**
  String get workDone;

  /// No description provided for @aCleanDayByDayTimesheetWithBreaksAndNotes.
  ///
  /// In en, this message translates to:
  /// **'A clean day-by-day timesheet with breaks and notes.'**
  String get aCleanDayByDayTimesheetWithBreaksAndNotes;

  /// No description provided for @basicInvoiceTrackingWithDatesClientsAndTotals.
  ///
  /// In en, this message translates to:
  /// **'Basic invoice tracking with dates, clients, and totals.'**
  String get basicInvoiceTrackingWithDatesClientsAndTotals;

  /// No description provided for @bringAnExistingFileOrGenerateAFullMonthTableWithYourPreferredDateStyle.
  ///
  /// In en, this message translates to:
  /// **'Bring an existing file or generate a full month table with your preferred date style.'**
  String
  get bringAnExistingFileOrGenerateAFullMonthTableWithYourPreferredDateStyle;

  /// No description provided for @calcrowGivesYouOneCleanDailyEditorSoYouUpdateLogsFastOnYourPhone.
  ///
  /// In en, this message translates to:
  /// **'Calcrow gives you one clean daily editor so you update logs fast on your phone.'**
  String get calcrowGivesYouOneCleanDailyEditorSoYouUpdateLogsFastOnYourPhone;

  /// No description provided for @cleanAndPressWeight.
  ///
  /// In en, this message translates to:
  /// **'Clean and Press weight'**
  String get cleanAndPressWeight;

  /// No description provided for @barbellCurlWeight.
  ///
  /// In en, this message translates to:
  /// **'Barbell Curl weight'**
  String get barbellCurlWeight;

  /// No description provided for @behindTheNeckPressWeight.
  ///
  /// In en, this message translates to:
  /// **'Behind-the-neck Press weight'**
  String get behindTheNeckPressWeight;

  /// No description provided for @uprightRowWeight.
  ///
  /// In en, this message translates to:
  /// **'Upright Row weight'**
  String get uprightRowWeight;

  /// No description provided for @barbellSquatWeight.
  ///
  /// In en, this message translates to:
  /// **'Barbell Squat weight'**
  String get barbellSquatWeight;

  /// No description provided for @barbellRowWeight.
  ///
  /// In en, this message translates to:
  /// **'Barbell Row weight'**
  String get barbellRowWeight;

  /// No description provided for @barbellBenchPressWeight.
  ///
  /// In en, this message translates to:
  /// **'Barbell Bench Press weight'**
  String get barbellBenchPressWeight;

  /// No description provided for @barbellPulloverWeight.
  ///
  /// In en, this message translates to:
  /// **'Barbell Pullover weight'**
  String get barbellPulloverWeight;

  /// No description provided for @importOrCreateMonthlyCSVInstantly.
  ///
  /// In en, this message translates to:
  /// **'Import or create monthly CSV instantly'**
  String get importOrCreateMonthlyCSVInstantly;

  /// No description provided for @invoice.
  ///
  /// In en, this message translates to:
  /// **'Invoice'**
  String get invoice;

  /// No description provided for @keepDataLocalSyncWhenYouChoose.
  ///
  /// In en, this message translates to:
  /// **'Keep data local, sync when you choose'**
  String get keepDataLocalSyncWhenYouChoose;

  /// No description provided for @logCustomerVisitsBillableTimeExpensesAndOutcomes.
  ///
  /// In en, this message translates to:
  /// **'Log customer visits, billable time, expenses, and outcomes.'**
  String get logCustomerVisitsBillableTimeExpensesAndOutcomes;

  /// No description provided for @namesContactsAndRSVPStatusForAnEvent.
  ///
  /// In en, this message translates to:
  /// **'Names, contacts, and RSVP status for an event.'**
  String get namesContactsAndRSVPStatusForAnEvent;

  /// No description provided for @pullUps.
  ///
  /// In en, this message translates to:
  /// **'Pull-ups'**
  String get pullUps;

  /// No description provided for @pushUps.
  ///
  /// In en, this message translates to:
  /// **'Push-ups'**
  String get pushUps;

  /// No description provided for @startOfflineLaterConnectAccountSyncAndBackupsWithoutChangingYourWorkflow.
  ///
  /// In en, this message translates to:
  /// **'Start offline. Later connect account sync and backups without changing your workflow.'**
  String
  get startOfflineLaterConnectAccountSyncAndBackupsWithoutChangingYourWorkflow;

  /// No description provided for @trackTrainingSessionsWithoutTurningTheSheetIntoAFitnessApp.
  ///
  /// In en, this message translates to:
  /// **'Track training sessions without turning the sheet into a fitness app.'**
  String get trackTrainingSessionsWithoutTurningTheSheetIntoAFitnessApp;

  /// No description provided for @trackFlexibleWorkoutsDistanceRepetitionsAndTime.
  ///
  /// In en, this message translates to:
  /// **'Track flexible workouts by distance, repetitions, or time.'**
  String get trackFlexibleWorkoutsDistanceRepetitionsAndTime;

  /// No description provided for @templateCategoryOther.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get templateCategoryOther;

  /// No description provided for @templateCategorySports.
  ///
  /// In en, this message translates to:
  /// **'Sports'**
  String get templateCategorySports;

  /// No description provided for @templateCategoryWork.
  ///
  /// In en, this message translates to:
  /// **'Work'**
  String get templateCategoryWork;

  /// No description provided for @useTemplate.
  ///
  /// In en, this message translates to:
  /// **'Use template'**
  String get useTemplate;

  /// No description provided for @trackSwimBikeRunAndStrengthWorkInOneRow.
  ///
  /// In en, this message translates to:
  /// **'Track swim, bike, run, and strength work in one row.'**
  String get trackSwimBikeRunAndStrengthWorkInOneRow;

  /// No description provided for @trackWorkdaysInUnderAMinute.
  ///
  /// In en, this message translates to:
  /// **'Track workdays in under a minute'**
  String get trackWorkdaysInUnderAMinute;

  /// No description provided for @triathlonTrainingTrackerPlus.
  ///
  /// In en, this message translates to:
  /// **'Triathlon Training Tracker Plus'**
  String get triathlonTrainingTrackerPlus;

  /// No description provided for @workoutLikeBruceLee.
  ///
  /// In en, this message translates to:
  /// **'Workout like Bruce Lee'**
  String get workoutLikeBruceLee;

  /// No description provided for @acceptTheTermsOfUsePrivacyPolicyAndAdsPrivacyPolicyToCreateAnAccount.
  ///
  /// In en, this message translates to:
  /// **'Accept the Terms of Use, Privacy Policy, and Ads Privacy Policy to create an account.'**
  String
  get acceptTheTermsOfUsePrivacyPolicyAndAdsPrivacyPolicyToCreateAnAccount;

  /// No description provided for @codeIsInvalidOrExpired.
  ///
  /// In en, this message translates to:
  /// **'Code is invalid or expired.'**
  String get codeIsInvalidOrExpired;

  /// No description provided for @couldNotCreateYourAccountRightNow.
  ///
  /// In en, this message translates to:
  /// **'Could not create your account right now.'**
  String get couldNotCreateYourAccountRightNow;

  /// No description provided for @couldNotResendCode.
  ///
  /// In en, this message translates to:
  /// **'Could not resend code.'**
  String get couldNotResendCode;

  /// No description provided for @couldNotResetPasswordRightNow.
  ///
  /// In en, this message translates to:
  /// **'Could not reset password right now.'**
  String get couldNotResetPasswordRightNow;

  /// No description provided for @couldNotSignInRightNow.
  ///
  /// In en, this message translates to:
  /// **'Could not sign in right now.'**
  String get couldNotSignInRightNow;

  /// No description provided for @couldNotVerifyCodeRightNow.
  ///
  /// In en, this message translates to:
  /// **'Could not verify code right now.'**
  String get couldNotVerifyCodeRightNow;

  /// No description provided for @createYourAccountAndContinueToSetup.
  ///
  /// In en, this message translates to:
  /// **'Create your account and continue to setup.'**
  String get createYourAccountAndContinueToSetup;

  /// No description provided for @emailAndPasswordAreRequired.
  ///
  /// In en, this message translates to:
  /// **'Email and password are required.'**
  String get emailAndPasswordAreRequired;

  /// No description provided for @emailPasswordAndConfirmationAreRequired.
  ///
  /// In en, this message translates to:
  /// **'Email, password and confirmation are required.'**
  String get emailPasswordAndConfirmationAreRequired;

  /// No description provided for @emailAddressFormatIsInvalid.
  ///
  /// In en, this message translates to:
  /// **'Email address format is invalid.'**
  String get emailAddressFormatIsInvalid;

  /// No description provided for @emailIsRequired.
  ///
  /// In en, this message translates to:
  /// **'Email is required.'**
  String get emailIsRequired;

  /// No description provided for @emailOrPasswordIsIncorrect.
  ///
  /// In en, this message translates to:
  /// **'Email or password is incorrect.'**
  String get emailOrPasswordIsIncorrect;

  /// No description provided for @emailPasswordAuthIsDisabledInFirebaseAuthSettings.
  ///
  /// In en, this message translates to:
  /// **'Email/password auth is disabled in Firebase Auth settings.'**
  String get emailPasswordAuthIsDisabledInFirebaseAuthSettings;

  /// No description provided for @enterThe6DigitCode.
  ///
  /// In en, this message translates to:
  /// **'Enter the 6-digit code.'**
  String get enterThe6DigitCode;

  /// No description provided for @enterThe6DigitVerificationCode.
  ///
  /// In en, this message translates to:
  /// **'Enter the 6-digit verification code.'**
  String get enterThe6DigitVerificationCode;

  /// No description provided for @enterTheCodeFromYourEmailAndChooseANewPassword.
  ///
  /// In en, this message translates to:
  /// **'Enter the code from your email and choose a new password.'**
  String get enterTheCodeFromYourEmailAndChooseANewPassword;

  /// No description provided for @firebaseWebConfigIsInvalidForThisAppEnvironment.
  ///
  /// In en, this message translates to:
  /// **'Firebase web config is invalid for this app/environment.'**
  String get firebaseWebConfigIsInvalidForThisAppEnvironment;

  /// No description provided for @missingVerificationContextSignInAgain.
  ///
  /// In en, this message translates to:
  /// **'Missing verification context. Sign in again.'**
  String get missingVerificationContextSignInAgain;

  /// No description provided for @networkErrorCheckConnectionAndTryAgain.
  ///
  /// In en, this message translates to:
  /// **'Network error. Check connection and try again.'**
  String get networkErrorCheckConnectionAndTryAgain;

  /// No description provided for @newPasswordAndConfirmationAreRequired.
  ///
  /// In en, this message translates to:
  /// **'New password and confirmation are required.'**
  String get newPasswordAndConfirmationAreRequired;

  /// No description provided for @noAccountFoundForThatEmail.
  ///
  /// In en, this message translates to:
  /// **'No account found for that email.'**
  String get noAccountFoundForThatEmail;

  /// No description provided for @noActiveCodeWasFoundRequestANewCode.
  ///
  /// In en, this message translates to:
  /// **'No active code was found. Request a new code.'**
  String get noActiveCodeWasFoundRequestANewCode;

  /// No description provided for @noActiveResetCodeWasFoundRequestANewOne.
  ///
  /// In en, this message translates to:
  /// **'No active reset code was found. Request a new one.'**
  String get noActiveResetCodeWasFoundRequestANewOne;

  /// No description provided for @passwordIsTooWeak.
  ///
  /// In en, this message translates to:
  /// **'Password is too weak.'**
  String get passwordIsTooWeak;

  /// No description provided for @passwordMustBeAtLeast6Characters.
  ///
  /// In en, this message translates to:
  /// **'Password must be at least 6 characters.'**
  String get passwordMustBeAtLeast6Characters;

  /// No description provided for @passwordsDoNotMatch.
  ///
  /// In en, this message translates to:
  /// **'Passwords do not match.'**
  String get passwordsDoNotMatch;

  /// No description provided for @permissionDeniedByFirestoreRules.
  ///
  /// In en, this message translates to:
  /// **'Permission denied by Firestore rules.'**
  String get permissionDeniedByFirestoreRules;

  /// No description provided for @register.
  ///
  /// In en, this message translates to:
  /// **'Register'**
  String get register;

  /// No description provided for @requestFailed.
  ///
  /// In en, this message translates to:
  /// **'Request failed.'**
  String get requestFailed;

  /// No description provided for @resetPassword.
  ///
  /// In en, this message translates to:
  /// **'Reset password'**
  String get resetPassword;

  /// No description provided for @sendResetCode.
  ///
  /// In en, this message translates to:
  /// **'Send reset code'**
  String get sendResetCode;

  /// No description provided for @serviceTemporarilyUnavailableTryAgain.
  ///
  /// In en, this message translates to:
  /// **'Service temporarily unavailable. Try again.'**
  String get serviceTemporarilyUnavailableTryAgain;

  /// No description provided for @setNewPassword.
  ///
  /// In en, this message translates to:
  /// **'Set new password'**
  String get setNewPassword;

  /// No description provided for @thatCodeHasExpiredRequestANewOne.
  ///
  /// In en, this message translates to:
  /// **'That code has expired. Request a new one.'**
  String get thatCodeHasExpiredRequestANewOne;

  /// No description provided for @thatResetCodeIsNoLongerValidRequestANewOne.
  ///
  /// In en, this message translates to:
  /// **'That reset code is no longer valid. Request a new one.'**
  String get thatResetCodeIsNoLongerValidRequestANewOne;

  /// No description provided for @theCodeWasNotAcceptedCheckItAndTryAgain.
  ///
  /// In en, this message translates to:
  /// **'The code was not accepted. Check it and try again.'**
  String get theCodeWasNotAcceptedCheckItAndTryAgain;

  /// No description provided for @thisAuthOperationIsRestrictedByFirebaseProjectSettings.
  ///
  /// In en, this message translates to:
  /// **'This auth operation is restricted by Firebase project settings.'**
  String get thisAuthOperationIsRestrictedByFirebaseProjectSettings;

  /// No description provided for @thisDomainIsNotAuthorizedForFirebaseAuth.
  ///
  /// In en, this message translates to:
  /// **'This domain is not authorized for Firebase Auth.'**
  String get thisDomainIsNotAuthorizedForFirebaseAuth;

  /// No description provided for @thisEmailIsAlreadyInUse.
  ///
  /// In en, this message translates to:
  /// **'This email is already in use.'**
  String get thisEmailIsAlreadyInUse;

  /// No description provided for @tooManyAttemptsTryAgainLater.
  ///
  /// In en, this message translates to:
  /// **'Too many attempts. Try again later.'**
  String get tooManyAttemptsTryAgainLater;

  /// No description provided for @tooManyFailedAttemptsRequestANewCode.
  ///
  /// In en, this message translates to:
  /// **'Too many failed attempts. Request a new code.'**
  String get tooManyFailedAttemptsRequestANewCode;

  /// No description provided for @useYourEmailAndPassword.
  ///
  /// In en, this message translates to:
  /// **'Use your email and password.'**
  String get useYourEmailAndPassword;

  /// No description provided for @verify.
  ///
  /// In en, this message translates to:
  /// **'Verify'**
  String get verify;

  /// No description provided for @verifyEmail.
  ///
  /// In en, this message translates to:
  /// **'Verify email'**
  String get verifyEmail;

  /// No description provided for @weWillSendA6DigitPasswordResetCodeToYourEmail.
  ///
  /// In en, this message translates to:
  /// **'We will send a 6-digit password reset code to your email.'**
  String get weWillSendA6DigitPasswordResetCodeToYourEmail;

  /// No description provided for @yourSessionExpiredSignInAgainAndRequestANewCode.
  ///
  /// In en, this message translates to:
  /// **'Your session expired. Sign in again and request a new code.'**
  String get yourSessionExpiredSignInAgainAndRequestANewCode;

  /// No description provided for @addAtLeastOneColumn.
  ///
  /// In en, this message translates to:
  /// **'Add at least one column.'**
  String get addAtLeastOneColumn;

  /// No description provided for @columnNamesMustBeUnique.
  ///
  /// In en, this message translates to:
  /// **'Column names must be unique.'**
  String get columnNamesMustBeUnique;

  /// No description provided for @datesOpenEndNeedsOneDateColumn.
  ///
  /// In en, this message translates to:
  /// **'Dates open end needs one date column.'**
  String get datesOpenEndNeedsOneDateColumn;

  /// No description provided for @cachedFieldTypesDoNotMatchLogbook.
  ///
  /// In en, this message translates to:
  /// **'Cached field types do not match Logbook.'**
  String get cachedFieldTypesDoNotMatchLogbook;

  /// No description provided for @cachedFieldTypesDoNotMatchNamelist.
  ///
  /// In en, this message translates to:
  /// **'Cached field types do not match Namelist.'**
  String get cachedFieldTypesDoNotMatchNamelist;

  /// No description provided for @appPasswordIsRequired.
  ///
  /// In en, this message translates to:
  /// **'App password is required.'**
  String get appPasswordIsRequired;

  /// No description provided for @appPasswordImportedFromQREnterServerURLAndUsernameToContinue.
  ///
  /// In en, this message translates to:
  /// **'App password imported from QR. Enter server URL and username to continue.'**
  String get appPasswordImportedFromQREnterServerURLAndUsernameToContinue;

  /// No description provided for @enterTheWebDAVURLUsernameAndAppPassword.
  ///
  /// In en, this message translates to:
  /// **'Enter the WebDAV URL, username, and app password.'**
  String get enterTheWebDAVURLUsernameAndAppPassword;

  /// No description provided for @qrCodeWasReadButTheFormatIsNotSupportedUseURLUsernameAndAppPasswordFields.
  ///
  /// In en, this message translates to:
  /// **'QR code was read, but the format is not supported. Use URL, username, and app password fields.'**
  String
  get qrCodeWasReadButTheFormatIsNotSupportedUseURLUsernameAndAppPasswordFields;

  /// No description provided for @qrScanIsAvailableOnAndroidAndIOSOnly.
  ///
  /// In en, this message translates to:
  /// **'QR scan is available on Android and iOS only.'**
  String get qrScanIsAvailableOnAndroidAndIOSOnly;

  /// No description provided for @serverURLImportedFromQREnterUsernameAndAppPasswordToContinue.
  ///
  /// In en, this message translates to:
  /// **'Server URL imported from QR. Enter username and app password to continue.'**
  String get serverURLImportedFromQREnterUsernameAndAppPasswordToContinue;

  /// No description provided for @username.
  ///
  /// In en, this message translates to:
  /// **'Username'**
  String get username;

  /// No description provided for @enterAValidWebDAVURL.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid WebDAV URL.'**
  String get enterAValidWebDAVURL;

  /// No description provided for @couldNotValidateTheWebDAVURL.
  ///
  /// In en, this message translates to:
  /// **'Could not validate the WebDAV URL.'**
  String get couldNotValidateTheWebDAVURL;

  /// No description provided for @webdavCredentialsAreMissingOnThisDeviceReLinkTheAccountInSettings.
  ///
  /// In en, this message translates to:
  /// **'WebDAV credentials are missing on this device. Re-link the account in Settings.'**
  String get webdavCredentialsAreMissingOnThisDeviceReLinkTheAccountInSettings;

  /// No description provided for @thisWebDAVFolderPathContainsUnsupportedCharacters.
  ///
  /// In en, this message translates to:
  /// **'This WebDAV folder path contains unsupported characters.'**
  String get thisWebDAVFolderPathContainsUnsupportedCharacters;

  /// No description provided for @thisWebDAVFolderPathCouldNotBeOpened.
  ///
  /// In en, this message translates to:
  /// **'This WebDAV folder path could not be opened.'**
  String get thisWebDAVFolderPathCouldNotBeOpened;

  /// No description provided for @theWebDAVServerReturnedAnInvalidFolderResponse.
  ///
  /// In en, this message translates to:
  /// **'The WebDAV server returned an invalid folder response.'**
  String get theWebDAVServerReturnedAnInvalidFolderResponse;

  /// No description provided for @aFileOrFolderNameInThisWebDAVDirectoryUsesUnsupportedCharacters.
  ///
  /// In en, this message translates to:
  /// **'A file or folder name in this WebDAV directory uses unsupported characters.'**
  String get aFileOrFolderNameInThisWebDAVDirectoryUsesUnsupportedCharacters;

  /// No description provided for @thisWebDAVFolderContainsAnEntryThatCouldNotBeOpened.
  ///
  /// In en, this message translates to:
  /// **'This WebDAV folder contains an entry that could not be opened.'**
  String get thisWebDAVFolderContainsAnEntryThatCouldNotBeOpened;

  /// No description provided for @thisWebDAVFilePathContainsUnsupportedCharacters.
  ///
  /// In en, this message translates to:
  /// **'This WebDAV file path contains unsupported characters.'**
  String get thisWebDAVFilePathContainsUnsupportedCharacters;

  /// No description provided for @thisWebDAVFilePathCouldNotBeOpened.
  ///
  /// In en, this message translates to:
  /// **'This WebDAV file path could not be opened.'**
  String get thisWebDAVFilePathCouldNotBeOpened;

  /// No description provided for @thisWebDAVFilePathCouldNotBeSaved.
  ///
  /// In en, this message translates to:
  /// **'This WebDAV file path could not be saved.'**
  String get thisWebDAVFilePathCouldNotBeSaved;

  /// No description provided for @webdavSignInFailedCheckTheUsernameAndAppPassword.
  ///
  /// In en, this message translates to:
  /// **'WebDAV sign-in failed. Check the username and app password.'**
  String get webdavSignInFailedCheckTheUsernameAndAppPassword;

  /// No description provided for @webdavEndpointRejectedPROPFIND405.
  ///
  /// In en, this message translates to:
  /// **'WebDAV endpoint rejected PROPFIND (405).'**
  String get webdavEndpointRejectedPROPFIND405;

  /// No description provided for @couldNotReachTheWebDAVServerCheckTheURLAndNetworkAccess.
  ///
  /// In en, this message translates to:
  /// **'Could not reach the WebDAV server. Check the URL and network access.'**
  String get couldNotReachTheWebDAVServerCheckTheURLAndNetworkAccess;

  /// No description provided for @couldNotReachTheWebDAVServerFromThisBrowserCheckURLHTTPSCertificateAndNetworkAccess.
  ///
  /// In en, this message translates to:
  /// **'Could not reach the WebDAV server from this browser. Check URL, HTTPS certificate, and network access.'**
  String
  get couldNotReachTheWebDAVServerFromThisBrowserCheckURLHTTPSCertificateAndNetworkAccess;

  /// No description provided for @browserBlockedTheWebDAVRequestLikelyCORSTLSAllowThisAppOriginInWebDAVCORSAndPermitMethodsPROPFINDGETPUTWithHeadersAuthorizationDepthAndContentType.
  ///
  /// In en, this message translates to:
  /// **'Browser blocked the WebDAV request (likely CORS/TLS). Allow this app origin in WebDAV CORS and permit methods PROPFIND/GET/PUT with headers Authorization, Depth, and Content-Type.'**
  String
  get browserBlockedTheWebDAVRequestLikelyCORSTLSAllowThisAppOriginInWebDAVCORSAndPermitMethodsPROPFINDGETPUTWithHeadersAuthorizationDepthAndContentType;

  /// No description provided for @couldNotReadCloudDocumentContent.
  ///
  /// In en, this message translates to:
  /// **'Could not read cloud document content.'**
  String get couldNotReadCloudDocumentContent;

  /// No description provided for @noCloudProviderIsActiveChooseGoogleDriveOrWebDAVInSettingsFirst.
  ///
  /// In en, this message translates to:
  /// **'No cloud provider is active. Choose Google Drive or WebDAV in Settings first.'**
  String get noCloudProviderIsActiveChooseGoogleDriveOrWebDAVInSettingsFirst;

  /// No description provided for @couldNotReadDocumentContent.
  ///
  /// In en, this message translates to:
  /// **'Could not read document content.'**
  String get couldNotReadDocumentContent;

  /// No description provided for @openDocument.
  ///
  /// In en, this message translates to:
  /// **'Open document'**
  String get openDocument;

  /// No description provided for @saveCsv.
  ///
  /// In en, this message translates to:
  /// **'Save CSV'**
  String get saveCsv;

  /// No description provided for @saveXlsx.
  ///
  /// In en, this message translates to:
  /// **'Save XLSX'**
  String get saveXlsx;

  /// No description provided for @saveOds.
  ///
  /// In en, this message translates to:
  /// **'Save ODS'**
  String get saveOds;

  /// No description provided for @importCsv.
  ///
  /// In en, this message translates to:
  /// **'Import CSV'**
  String get importCsv;

  /// No description provided for @upgradeToRemoveThisSlotAndUnlockPro.
  ///
  /// In en, this message translates to:
  /// **'Upgrade to remove this slot and unlock Pro.'**
  String get upgradeToRemoveThisSlotAndUnlockPro;

  /// No description provided for @firstFieldMustStayForOpeningMode.
  ///
  /// In en, this message translates to:
  /// **'The first field must stay {type} for this opening mode.'**
  String firstFieldMustStayForOpeningMode(String type);

  /// No description provided for @rowUpdatedDownloadedFileAs.
  ///
  /// In en, this message translates to:
  /// **'Row updated. Downloaded updated file as {location}.'**
  String rowUpdatedDownloadedFileAs(String location);

  /// No description provided for @rowSavedToAppStorageAt.
  ///
  /// In en, this message translates to:
  /// **'Row saved to app storage at {location}.'**
  String rowSavedToAppStorageAt(String location);

  /// No description provided for @rowSavedToLocation.
  ///
  /// In en, this message translates to:
  /// **'Row saved to {location}.'**
  String rowSavedToLocation(String location);

  /// No description provided for @rowSavedFutureSavesOverwrite.
  ///
  /// In en, this message translates to:
  /// **'Row saved to {location}. Future saves will overwrite this file.'**
  String rowSavedFutureSavesOverwrite(String location);

  /// No description provided for @loadedSameDateEntry.
  ///
  /// In en, this message translates to:
  /// **'Loaded same-date entry {current}/{total}. Edit and submit a new row if needed.'**
  String loadedSameDateEntry(int current, int total);

  /// No description provided for @rowNumber.
  ///
  /// In en, this message translates to:
  /// **'row {number}'**
  String rowNumber(int number);

  /// No description provided for @newRow.
  ///
  /// In en, this message translates to:
  /// **'new row'**
  String get newRow;

  /// No description provided for @setDatatypesCalculatedFieldsReadOnly.
  ///
  /// In en, this message translates to:
  /// **'Set datatypes and bear in mind that calculated fields are read-only.'**
  String get setDatatypesCalculatedFieldsReadOnly;

  /// No description provided for @noUsableTypeRowPickFormats.
  ///
  /// In en, this message translates to:
  /// **'This file has no usable type row yet. Pick the editable field formats once before saving.'**
  String get noUsableTypeRowPickFormats;

  /// No description provided for @activeSheet.
  ///
  /// In en, this message translates to:
  /// **'Active sheet: {sheetName}'**
  String activeSheet(String sheetName);

  /// No description provided for @rsvpField.
  ///
  /// In en, this message translates to:
  /// **'RSVP'**
  String get rsvpField;

  /// No description provided for @pauseField.
  ///
  /// In en, this message translates to:
  /// **'Pause'**
  String get pauseField;

  /// No description provided for @lookAndFeel.
  ///
  /// In en, this message translates to:
  /// **'Look and feel'**
  String get lookAndFeel;

  /// No description provided for @customizeLanguageAndAppearance.
  ///
  /// In en, this message translates to:
  /// **'Customize the app\'s language and appearance.'**
  String get customizeLanguageAndAppearance;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @languageEnglish.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get languageEnglish;

  /// No description provided for @languageGerman.
  ///
  /// In en, this message translates to:
  /// **'Deutsch'**
  String get languageGerman;

  /// No description provided for @signInToSaveLanguageToProfile.
  ///
  /// In en, this message translates to:
  /// **'Sign in to save this language to your profile.'**
  String get signInToSaveLanguageToProfile;

  /// No description provided for @languageSavedToProfile.
  ///
  /// In en, this message translates to:
  /// **'Saved in your user profile.'**
  String get languageSavedToProfile;

  /// No description provided for @languageSaved.
  ///
  /// In en, this message translates to:
  /// **'Language saved.'**
  String get languageSaved;

  /// No description provided for @couldNotSaveLanguage.
  ///
  /// In en, this message translates to:
  /// **'Could not save language: {details}'**
  String couldNotSaveLanguage(String details);

  /// No description provided for @couldNotReopenTheRememberedLocalDocument.
  ///
  /// In en, this message translates to:
  /// **'Could not reopen the remembered local document.'**
  String get couldNotReopenTheRememberedLocalDocument;

  /// No description provided for @driveMetadataIsIncomplete.
  ///
  /// In en, this message translates to:
  /// **'Drive metadata is incomplete.'**
  String get driveMetadataIsIncomplete;

  /// No description provided for @googleDriveAuthorizationWasCanceled.
  ///
  /// In en, this message translates to:
  /// **'Google Drive authorization was canceled.'**
  String get googleDriveAuthorizationWasCanceled;

  /// No description provided for @googleAccountEmailIsUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Google account email is unavailable.'**
  String get googleAccountEmailIsUnavailable;

  /// No description provided for @googleAccountUnlinked.
  ///
  /// In en, this message translates to:
  /// **'Google account unlinked.'**
  String get googleAccountUnlinked;

  /// No description provided for @googleDriveIsNotConnectedInThisSessionConnectGoogleDriveAgainToRefreshAccess.
  ///
  /// In en, this message translates to:
  /// **'Google Drive is not connected in this session. Connect Google Drive again to refresh access.'**
  String
  get googleDriveIsNotConnectedInThisSessionConnectGoogleDriveAgainToRefreshAccess;

  /// No description provided for @purchasesAreUnavailableRightNowPleaseTryAgainLater.
  ///
  /// In en, this message translates to:
  /// **'Purchases are unavailable right now. Please try again later.'**
  String get purchasesAreUnavailableRightNowPleaseTryAgainLater;

  /// No description provided for @purchasesAreUnavailableInThisBuildPleaseUpdateTheAppAndTryAgain.
  ///
  /// In en, this message translates to:
  /// **'Purchases are unavailable in this build. Please update the app and try again.'**
  String get purchasesAreUnavailableInThisBuildPleaseUpdateTheAppAndTryAgain;

  /// No description provided for @couldNotOpenSubscriptionOptionsPleaseTryAgainLater.
  ///
  /// In en, this message translates to:
  /// **'Could not open subscription options. Please try again later.'**
  String get couldNotOpenSubscriptionOptionsPleaseTryAgainLater;

  /// No description provided for @revenuecatPaywallsAreNotSupportedOnWebBuilds.
  ///
  /// In en, this message translates to:
  /// **'RevenueCat paywalls are not supported on web builds.'**
  String get revenuecatPaywallsAreNotSupportedOnWebBuilds;

  /// No description provided for @revenuecatCustomerCenterIsNotSupportedOnWebBuilds.
  ///
  /// In en, this message translates to:
  /// **'RevenueCat customer center is not supported on web builds.'**
  String get revenuecatCustomerCenterIsNotSupportedOnWebBuilds;

  /// No description provided for @purchasesUnavailableMissingConfiguration.
  ///
  /// In en, this message translates to:
  /// **'Purchases are unavailable in this build. The App Store build is missing its purchase configuration.'**
  String get purchasesUnavailableMissingConfiguration;

  /// No description provided for @purchasesTemporarilyUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Purchases are temporarily unavailable. Please try again later.'**
  String get purchasesTemporarilyUnavailable;

  /// No description provided for @openThePermanentAccountDeletionFlow.
  ///
  /// In en, this message translates to:
  /// **'Open the permanent account deletion flow.'**
  String get openThePermanentAccountDeletionFlow;

  /// No description provided for @sendAResetCodeToYourSignedInEmail.
  ///
  /// In en, this message translates to:
  /// **'Send a reset code to your signed-in email.'**
  String get sendAResetCodeToYourSignedInEmail;

  /// No description provided for @theSelectedDocumentHasNoNamedSheets.
  ///
  /// In en, this message translates to:
  /// **'The selected document has no named sheets.'**
  String get theSelectedDocumentHasNoNamedSheets;

  /// No description provided for @theSelectedODSHasNoContentXml.
  ///
  /// In en, this message translates to:
  /// **'The selected ODS has no content.xml.'**
  String get theSelectedODSHasNoContentXml;

  /// No description provided for @theSelectedODSHasNoSpreadsheetBody.
  ///
  /// In en, this message translates to:
  /// **'The selected ODS has no spreadsheet body.'**
  String get theSelectedODSHasNoSpreadsheetBody;

  /// No description provided for @theSelectedODSHasNoSheets.
  ///
  /// In en, this message translates to:
  /// **'The selected ODS has no sheets.'**
  String get theSelectedODSHasNoSheets;

  /// No description provided for @theSelectedODSSheetIsEmpty.
  ///
  /// In en, this message translates to:
  /// **'The selected ODS sheet is empty.'**
  String get theSelectedODSSheetIsEmpty;

  /// No description provided for @theSelectedXLSXHasNoSheets.
  ///
  /// In en, this message translates to:
  /// **'The selected XLSX has no sheets.'**
  String get theSelectedXLSXHasNoSheets;

  /// No description provided for @theSelectedXLSXSheetIsEmpty.
  ///
  /// In en, this message translates to:
  /// **'The selected XLSX sheet is empty.'**
  String get theSelectedXLSXSheetIsEmpty;

  /// No description provided for @firstRowHasNoHeaderTitles.
  ///
  /// In en, this message translates to:
  /// **'First row has no header titles.'**
  String get firstRowHasNoHeaderTitles;

  /// No description provided for @noODSSheetIsSelected.
  ///
  /// In en, this message translates to:
  /// **'No ODS sheet is selected.'**
  String get noODSSheetIsSelected;

  /// No description provided for @noXLSXWorkbookIsLoaded.
  ///
  /// In en, this message translates to:
  /// **'No XLSX workbook is loaded.'**
  String get noXLSXWorkbookIsLoaded;

  /// No description provided for @couldNotEncodeODSDocument.
  ///
  /// In en, this message translates to:
  /// **'Could not encode ODS document.'**
  String get couldNotEncodeODSDocument;

  /// No description provided for @couldNotCreateODSDocument.
  ///
  /// In en, this message translates to:
  /// **'Could not create ODS document.'**
  String get couldNotCreateODSDocument;

  /// No description provided for @couldNotEncodeXLSXWorkbook.
  ///
  /// In en, this message translates to:
  /// **'Could not encode XLSX workbook.'**
  String get couldNotEncodeXLSXWorkbook;

  /// No description provided for @chooseSeparatelyWhetherCalcrowMayCollectAnonymousUsageAnalyticsAndTechnicalCrashOrPerformanceDiagnostics.
  ///
  /// In en, this message translates to:
  /// **'Choose separately whether Calcrow may collect anonymous usage analytics and technical crash or performance diagnostics.'**
  String
  get chooseSeparatelyWhetherCalcrowMayCollectAnonymousUsageAnalyticsAndTechnicalCrashOrPerformanceDiagnostics;

  /// No description provided for @chooseSeparatelyWhetherCalcrowMayCollectAnonymousUsageAnalyticsTechnicalCrashOrPerformanceDiagnosticsAndAdPrivacyPreferencesWhereSupported.
  ///
  /// In en, this message translates to:
  /// **'Choose separately whether Calcrow may collect anonymous usage analytics, technical crash or performance diagnostics, and ad privacy preferences where supported.'**
  String
  get chooseSeparatelyWhetherCalcrowMayCollectAnonymousUsageAnalyticsTechnicalCrashOrPerformanceDiagnosticsAndAdPrivacyPreferencesWhereSupported;

  /// No description provided for @manageYourGoogleAdPrivacyChoicesThisEntryPointMustStayAvailableAfterConsentIsCollected.
  ///
  /// In en, this message translates to:
  /// **'Manage your Google ad privacy choices. This entry point must stay available after consent is collected.'**
  String
  get manageYourGoogleAdPrivacyChoicesThisEntryPointMustStayAvailableAfterConsentIsCollected;

  /// No description provided for @googleDoesNotCurrentlyRequireAPersistentAdPrivacyOptionsButtonOnThisDeviceOrRegion.
  ///
  /// In en, this message translates to:
  /// **'Google does not currently require a persistent ad privacy options button on this device or region.'**
  String
  get googleDoesNotCurrentlyRequireAPersistentAdPrivacyOptionsButtonOnThisDeviceOrRegion;

  /// No description provided for @refreshAdPrivacyChoicesAndReviewTheLatestGoogleConsentOptionsForThisDevice.
  ///
  /// In en, this message translates to:
  /// **'Refresh ad privacy choices and review the latest Google consent options for this device.'**
  String
  get refreshAdPrivacyChoicesAndReviewTheLatestGoogleConsentOptionsForThisDevice;

  /// No description provided for @clearTheCurrentAdMobConsentStateOnThisDeviceAdsStayDisabledUntilGoogleCollectsConsentAgain.
  ///
  /// In en, this message translates to:
  /// **'Clear the current AdMob consent state on this device. Ads stay disabled until Google collects consent again.'**
  String
  get clearTheCurrentAdMobConsentStateOnThisDeviceAdsStayDisabledUntilGoogleCollectsConsentAgain;

  /// No description provided for @clearAnyStoredAdMobConsentStateOnThisDeviceAndForceTheGoogleConsentFlowToAskAgainLater.
  ///
  /// In en, this message translates to:
  /// **'Clear any stored AdMob consent state on this device and force the Google consent flow to ask again later.'**
  String
  get clearAnyStoredAdMobConsentStateOnThisDeviceAndForceTheGoogleConsentFlowToAskAgainLater;

  /// No description provided for @collectAnonymousUsagePatternsToUnderstandWhichScreensAndFlowsAreUsed.
  ///
  /// In en, this message translates to:
  /// **'Collect anonymous usage patterns to understand which screens and flows are used.'**
  String
  get collectAnonymousUsagePatternsToUnderstandWhichScreensAndFlowsAreUsed;

  /// No description provided for @usageAnalyticsAreNotAvailableOnThisPlatform.
  ///
  /// In en, this message translates to:
  /// **'Usage analytics are not available on this platform.'**
  String get usageAnalyticsAreNotAvailableOnThisPlatform;

  /// No description provided for @sendCrashLogsNonFatalErrorsAndPerformanceMonitoringDataToHelpAnalyzeAppFailuresAndSlowPaths.
  ///
  /// In en, this message translates to:
  /// **'Send crash logs, non-fatal errors, and performance monitoring data to help analyze app failures and slow paths.'**
  String
  get sendCrashLogsNonFatalErrorsAndPerformanceMonitoringDataToHelpAnalyzeAppFailuresAndSlowPaths;

  /// No description provided for @crashReportingAndPerformanceMonitoringAreOnlyAvailableOnSupportedMobileBuilds.
  ///
  /// In en, this message translates to:
  /// **'Crash reporting and performance monitoring are only available on supported mobile builds.'**
  String
  get crashReportingAndPerformanceMonitoringAreOnlyAvailableOnSupportedMobileBuilds;

  /// No description provided for @usageAnalyticsEnabled.
  ///
  /// In en, this message translates to:
  /// **'Usage analytics enabled.'**
  String get usageAnalyticsEnabled;

  /// No description provided for @usageAnalyticsDisabled.
  ///
  /// In en, this message translates to:
  /// **'Usage analytics disabled.'**
  String get usageAnalyticsDisabled;

  /// No description provided for @crashReportingAndPerformanceMonitoringEnabled.
  ///
  /// In en, this message translates to:
  /// **'Crash reporting and performance monitoring enabled.'**
  String get crashReportingAndPerformanceMonitoringEnabled;

  /// No description provided for @crashReportingAndPerformanceMonitoringDisabled.
  ///
  /// In en, this message translates to:
  /// **'Crash reporting and performance monitoring disabled.'**
  String get crashReportingAndPerformanceMonitoringDisabled;

  /// No description provided for @calcrowIsDeliveredBy.
  ///
  /// In en, this message translates to:
  /// **'Calcrow is delivered by '**
  String get calcrowIsDeliveredBy;

  /// No description provided for @chooseWhetherCalcrowMayCollectAnonymousUsageAnalyticsAndTechnicalCrashOrPerformanceDiagnosticsYouCanChangeBothLaterInSettings.
  ///
  /// In en, this message translates to:
  /// **'Choose whether Calcrow may collect anonymous usage analytics and technical crash or performance diagnostics. You can change both later in Settings.'**
  String
  get chooseWhetherCalcrowMayCollectAnonymousUsageAnalyticsAndTechnicalCrashOrPerformanceDiagnosticsYouCanChangeBothLaterInSettings;

  /// No description provided for @thisClearsTheCurrentGoogleAdMobConsentStateOnThisDeviceTheNextConsentRefreshMayAskAgainBeforeAdsCanBeRequested.
  ///
  /// In en, this message translates to:
  /// **'This clears the current Google AdMob consent state on this device. The next consent refresh may ask again before ads can be requested.'**
  String
  get thisClearsTheCurrentGoogleAdMobConsentStateOnThisDeviceTheNextConsentRefreshMayAskAgainBeforeAdsCanBeRequested;

  /// No description provided for @passwordResetCodeSentTo.
  ///
  /// In en, this message translates to:
  /// **'Password reset code sent to {email}.'**
  String passwordResetCodeSentTo(String email);

  /// No description provided for @sentTo.
  ///
  /// In en, this message translates to:
  /// **'Sent to {email}'**
  String sentTo(String email);

  /// No description provided for @passwordRequiredFor.
  ///
  /// In en, this message translates to:
  /// **'Password required for {username}'**
  String passwordRequiredFor(String username);

  /// No description provided for @enterCodeSentTo.
  ///
  /// In en, this message translates to:
  /// **'Enter the code sent to {email}.'**
  String enterCodeSentTo(String email);

  /// No description provided for @columnNumber.
  ///
  /// In en, this message translates to:
  /// **'Column {number}'**
  String columnNumber(int number);

  /// No description provided for @selectedLocalDocument.
  ///
  /// In en, this message translates to:
  /// **'Selected local document {fileName}.'**
  String selectedLocalDocument(String fileName);

  /// No description provided for @selectedLocalFile.
  ///
  /// In en, this message translates to:
  /// **'Selected local file: {fileName}'**
  String selectedLocalFile(String fileName);

  /// No description provided for @openedLocalDocument.
  ///
  /// In en, this message translates to:
  /// **'Opened local document {fileName}.'**
  String openedLocalDocument(String fileName);

  /// No description provided for @openedCloudDocument.
  ///
  /// In en, this message translates to:
  /// **'Opened {provider} document {fileName}.'**
  String openedCloudDocument(String provider, String fileName);

  /// No description provided for @importedRows.
  ///
  /// In en, this message translates to:
  /// **'Imported {fileName} ({rowCount} rows).'**
  String importedRows(String fileName, int rowCount);

  /// No description provided for @noRowsFoundFor.
  ///
  /// In en, this message translates to:
  /// **'No rows found for {date}.'**
  String noRowsFoundFor(String date);

  /// No description provided for @webDavEntryRemoved.
  ///
  /// In en, this message translates to:
  /// **'WebDAV entry removed: {username}.'**
  String webDavEntryRemoved(String username);

  /// No description provided for @manageGoogleDriveSyncFile.
  ///
  /// In en, this message translates to:
  /// **'Manage Google Drive sync file: {fileName}'**
  String manageGoogleDriveSyncFile(String fileName);

  /// No description provided for @manageWebDavSyncFile.
  ///
  /// In en, this message translates to:
  /// **'Manage WebDAV sync file: {fileName}'**
  String manageWebDavSyncFile(String fileName);

  /// No description provided for @couldNotCompleteAction.
  ///
  /// In en, this message translates to:
  /// **'Could not {action}: {details}'**
  String couldNotCompleteAction(String action, String details);

  /// No description provided for @importFailed.
  ///
  /// In en, this message translates to:
  /// **'Import failed: {details}'**
  String importFailed(String details);

  /// No description provided for @googleLinkFailed.
  ///
  /// In en, this message translates to:
  /// **'Google link failed: {details}'**
  String googleLinkFailed(String details);

  /// No description provided for @webDavUpdateFailed.
  ///
  /// In en, this message translates to:
  /// **'WebDAV update failed: {details}'**
  String webDavUpdateFailed(String details);

  /// No description provided for @rowSavedButFileWriteFailed.
  ///
  /// In en, this message translates to:
  /// **'Row saved in app, but file write failed: {details}'**
  String rowSavedButFileWriteFailed(String details);

  /// No description provided for @couldNotOpenSubscriptionOptionsDetails.
  ///
  /// In en, this message translates to:
  /// **'Could not open subscription options: {details}'**
  String couldNotOpenSubscriptionOptionsDetails(String details);

  /// No description provided for @couldNotUpdateUsageAnalytics.
  ///
  /// In en, this message translates to:
  /// **'Could not update usage analytics: {details}'**
  String couldNotUpdateUsageAnalytics(String details);

  /// No description provided for @couldNotUpdateCrashReporting.
  ///
  /// In en, this message translates to:
  /// **'Could not update crash reporting: {details}'**
  String couldNotUpdateCrashReporting(String details);

  /// No description provided for @couldNotOpenAdPrivacyChoices.
  ///
  /// In en, this message translates to:
  /// **'Could not open ad privacy choices: {details}'**
  String couldNotOpenAdPrivacyChoices(String details);

  /// No description provided for @couldNotRefreshAdPrivacyChoices.
  ///
  /// In en, this message translates to:
  /// **'Could not refresh ad privacy choices: {details}'**
  String couldNotRefreshAdPrivacyChoices(String details);

  /// No description provided for @couldNotOpenAdsPrivacyPolicy.
  ///
  /// In en, this message translates to:
  /// **'Could not open ads privacy policy: {details}'**
  String couldNotOpenAdsPrivacyPolicy(String details);

  /// No description provided for @couldNotResetAdConsent.
  ///
  /// In en, this message translates to:
  /// **'Could not reset ad consent: {details}'**
  String couldNotResetAdConsent(String details);

  /// No description provided for @couldNotClearCachedFieldTypes.
  ///
  /// In en, this message translates to:
  /// **'Could not clear cached field types: {details}'**
  String couldNotClearCachedFieldTypes(String details);

  /// No description provided for @couldNotSelectDocument.
  ///
  /// In en, this message translates to:
  /// **'Could not select document: {details}'**
  String couldNotSelectDocument(String details);

  /// No description provided for @couldNotOpenCloudDocument.
  ///
  /// In en, this message translates to:
  /// **'Could not open cloud document: {details}'**
  String couldNotOpenCloudDocument(String details);

  /// No description provided for @couldNotCreateLocalDocument.
  ///
  /// In en, this message translates to:
  /// **'Could not create local document: {details}'**
  String couldNotCreateLocalDocument(String details);

  /// No description provided for @couldNotCreateCloudDocument.
  ///
  /// In en, this message translates to:
  /// **'Could not create cloud document: {details}'**
  String couldNotCreateCloudDocument(String details);

  /// No description provided for @couldNotUpdateCloudProvider.
  ///
  /// In en, this message translates to:
  /// **'Could not update cloud provider: {details}'**
  String couldNotUpdateCloudProvider(String details);

  /// No description provided for @couldNotSetSafFolder.
  ///
  /// In en, this message translates to:
  /// **'Could not set SAF folder: {details}'**
  String couldNotSetSafFolder(String details);

  /// No description provided for @couldNotClearSafFolder.
  ///
  /// In en, this message translates to:
  /// **'Could not clear SAF folder: {details}'**
  String couldNotClearSafFolder(String details);

  /// No description provided for @zero.
  ///
  /// In en, this message translates to:
  /// **'0'**
  String get zero;

  /// No description provided for @csv.
  ///
  /// In en, this message translates to:
  /// **'CSV'**
  String get csv;

  /// No description provided for @calcrow.
  ///
  /// In en, this message translates to:
  /// **'Calcrow'**
  String get calcrow;

  /// No description provided for @ods.
  ///
  /// In en, this message translates to:
  /// **'ODS'**
  String get ods;

  /// No description provided for @trainvent.
  ///
  /// In en, this message translates to:
  /// **'Trainvent'**
  String get trainvent;

  /// No description provided for @webDavUrl.
  ///
  /// In en, this message translates to:
  /// **'WebDAV URL'**
  String get webDavUrl;

  /// No description provided for @xlsx.
  ///
  /// In en, this message translates to:
  /// **'XLSX'**
  String get xlsx;

  /// No description provided for @http.
  ///
  /// In en, this message translates to:
  /// **'http'**
  String get http;

  /// No description provided for @yyyyMmDd.
  ///
  /// In en, this message translates to:
  /// **'YYYY-MM-DD'**
  String get yyyyMmDd;

  /// No description provided for @hhMmSs.
  ///
  /// In en, this message translates to:
  /// **'HH:MM:SS'**
  String get hhMmSs;

  /// No description provided for @exampleInteger.
  ///
  /// In en, this message translates to:
  /// **'e.g. 123'**
  String get exampleInteger;

  /// No description provided for @exampleDecimal.
  ///
  /// In en, this message translates to:
  /// **'e.g. 123.45 or 123,45'**
  String get exampleDecimal;

  /// No description provided for @exampleEmail.
  ///
  /// In en, this message translates to:
  /// **'name@example.com'**
  String get exampleEmail;

  /// No description provided for @examplePhone.
  ///
  /// In en, this message translates to:
  /// **'e.g. +49 123 456789'**
  String get examplePhone;

  /// No description provided for @moneyWithCurrency.
  ///
  /// In en, this message translates to:
  /// **'money ({currencyCode})'**
  String moneyWithCurrency(String currencyCode);

  /// No description provided for @typeLabel.
  ///
  /// In en, this message translates to:
  /// **'Type: {type}'**
  String typeLabel(String type);

  /// No description provided for @typeLabelFixed.
  ///
  /// In en, this message translates to:
  /// **'Type: {type} (fixed)'**
  String typeLabelFixed(String type);

  /// No description provided for @typeLabelHoursAndMinutes.
  ///
  /// In en, this message translates to:
  /// **'Type: {type} (enter hours and minutes)'**
  String typeLabelHoursAndMinutes(String type);

  /// No description provided for @debugCode.
  ///
  /// In en, this message translates to:
  /// **'Debug code: {code}'**
  String debugCode(String code);

  /// No description provided for @authenticationFailedWithCode.
  ///
  /// In en, this message translates to:
  /// **'Authentication failed ({code}).'**
  String authenticationFailedWithCode(String code);

  /// No description provided for @requestFailedWithCode.
  ///
  /// In en, this message translates to:
  /// **'Request failed ({code}).'**
  String requestFailedWithCode(String code);

  /// No description provided for @authSetupIssue.
  ///
  /// In en, this message translates to:
  /// **'Auth setup issue ({code}). Check Firebase Auth provider and authorized domains.'**
  String authSetupIssue(String code);

  /// No description provided for @linkedAs.
  ///
  /// In en, this message translates to:
  /// **'Linked as {username}'**
  String linkedAs(String username);

  /// No description provided for @linkedAsOn.
  ///
  /// In en, this message translates to:
  /// **'Linked as {username} on {host}'**
  String linkedAsOn(String username, String host);

  /// No description provided for @webDavEntriesActive.
  ///
  /// In en, this message translates to:
  /// **'{count} WebDAV entries. Active: {username}'**
  String webDavEntriesActive(int count, String username);

  /// No description provided for @webDavEntriesActiveOn.
  ///
  /// In en, this message translates to:
  /// **'{count} WebDAV entries. Active: {username} on {host}'**
  String webDavEntriesActiveOn(int count, String username, String host);

  /// No description provided for @chooseRowFor.
  ///
  /// In en, this message translates to:
  /// **'Choose a row for {date}.'**
  String chooseRowFor(String date);

  /// No description provided for @rowsAndColumns.
  ///
  /// In en, this message translates to:
  /// **'{rowCount} rows • {columnCount} columns'**
  String rowsAndColumns(int rowCount, int columnCount);

  /// No description provided for @googleDrive.
  ///
  /// In en, this message translates to:
  /// **'Google Drive'**
  String get googleDrive;

  /// No description provided for @webDav.
  ///
  /// In en, this message translates to:
  /// **'WebDAV'**
  String get webDav;

  /// No description provided for @localEditingTip.
  ///
  /// In en, this message translates to:
  /// **'Tip: pick a local file first, then edit daily rows. For cloud-based files, connect Google Drive or WebDAV in Settings and use Edit Cloud Document here.'**
  String get localEditingTip;

  /// No description provided for @cloudEditingTip.
  ///
  /// In en, this message translates to:
  /// **'Tip: connect Google Drive or WebDAV in Settings, then use Edit Cloud Document here.'**
  String get cloudEditingTip;

  /// No description provided for @openAnExistingCsvFromThisDevice.
  ///
  /// In en, this message translates to:
  /// **'Open an existing CSV from this device'**
  String get openAnExistingCsvFromThisDevice;

  /// No description provided for @dateBasedOpeningBlocked.
  ///
  /// In en, this message translates to:
  /// **'Date-based opening is blocked because {date} was not found in the detected date column.'**
  String dateBasedOpeningBlocked(String date);

  /// No description provided for @couldNotOpenAdsPrivacyPolicyVisit.
  ///
  /// In en, this message translates to:
  /// **'Could not open ads privacy policy. Visit {url} in a browser.'**
  String couldNotOpenAdsPrivacyPolicyVisit(String url);

  /// No description provided for @googleDriveConnectedChooseFile.
  ///
  /// In en, this message translates to:
  /// **'Google Drive connected: {email}. Choose a Drive file next.'**
  String googleDriveConnectedChooseFile(String email);

  /// No description provided for @webDavEntryAdded.
  ///
  /// In en, this message translates to:
  /// **'WebDAV entry added: {username} on {host}.'**
  String webDavEntryAdded(String username, String host);

  /// No description provided for @webDavEntryActive.
  ///
  /// In en, this message translates to:
  /// **'WebDAV entry active: {username}.'**
  String webDavEntryActive(String username);

  /// No description provided for @webDavEntryActiveOn.
  ///
  /// In en, this message translates to:
  /// **'WebDAV entry active: {username} on {host}.'**
  String webDavEntryActiveOn(String username, String host);

  /// No description provided for @openInBrowserToContinue.
  ///
  /// In en, this message translates to:
  /// **'Open {url} in a browser to continue.'**
  String openInBrowserToContinue(String url);

  /// No description provided for @safFolderSavedForSession.
  ///
  /// In en, this message translates to:
  /// **'SAF folder saved for this app session.'**
  String get safFolderSavedForSession;

  /// No description provided for @safFolderSavedInSettings.
  ///
  /// In en, this message translates to:
  /// **'SAF folder saved in settings.'**
  String get safFolderSavedInSettings;

  /// No description provided for @safFolderSavedSettingsSyncFailed.
  ///
  /// In en, this message translates to:
  /// **'SAF folder saved for this app session. Settings sync failed.'**
  String get safFolderSavedSettingsSyncFailed;

  /// No description provided for @myDrive.
  ///
  /// In en, this message translates to:
  /// **'My Drive'**
  String get myDrive;

  /// No description provided for @webDavRoot.
  ///
  /// In en, this message translates to:
  /// **'WebDAV root'**
  String get webDavRoot;

  /// No description provided for @googleSheets.
  ///
  /// In en, this message translates to:
  /// **'Google Sheets'**
  String get googleSheets;

  /// No description provided for @openAction.
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get openAction;

  /// No description provided for @createAction.
  ///
  /// In en, this message translates to:
  /// **'Create'**
  String get createAction;

  /// No description provided for @clearRememberedFieldTypes.
  ///
  /// In en, this message translates to:
  /// **'Clear the remembered field types for {fileName}? Calcrow will infer or ask for field types the next time you open it.'**
  String clearRememberedFieldTypes(String fileName);

  /// No description provided for @loadedEntries.
  ///
  /// In en, this message translates to:
  /// **'Loaded {fileName} ({entryCount} entries).'**
  String loadedEntries(String fileName, int entryCount);

  /// No description provided for @loadedEntriesFromTabSafReady.
  ///
  /// In en, this message translates to:
  /// **'Loaded {fileName} ({entryCount} entries) from tab {sheetName}. SAF target ready.'**
  String loadedEntriesFromTabSafReady(
    String fileName,
    int entryCount,
    String sheetName,
  );

  /// No description provided for @loadedEntriesFromTabSafMissing.
  ///
  /// In en, this message translates to:
  /// **'Loaded {fileName} ({entryCount} entries) from tab {sheetName}. SAF target not detected.'**
  String loadedEntriesFromTabSafMissing(
    String fileName,
    int entryCount,
    String sheetName,
  );

  /// No description provided for @loadedEntriesFromSheetSafReady.
  ///
  /// In en, this message translates to:
  /// **'Loaded {fileName} ({entryCount} entries) from sheet {sheetName}. SAF target ready.'**
  String loadedEntriesFromSheetSafReady(
    String fileName,
    int entryCount,
    String sheetName,
  );

  /// No description provided for @loadedEntriesFromSheetSafMissing.
  ///
  /// In en, this message translates to:
  /// **'Loaded {fileName} ({entryCount} entries) from sheet {sheetName}. SAF target not detected.'**
  String loadedEntriesFromSheetSafMissing(
    String fileName,
    int entryCount,
    String sheetName,
  );

  /// No description provided for @loadedGoogleSheetEntries.
  ///
  /// In en, this message translates to:
  /// **'Loaded Google Sheet {fileName} ({entryCount} entries) from tab {sheetName}.'**
  String loadedGoogleSheetEntries(
    String fileName,
    int entryCount,
    String sheetName,
  );

  /// No description provided for @multiSheetStartsWith.
  ///
  /// In en, this message translates to:
  /// **'Uses a multi-sheet format such as XLSX. Starts with {sheetName}.'**
  String multiSheetStartsWith(String sheetName);

  /// No description provided for @yearTabsStartWith.
  ///
  /// In en, this message translates to:
  /// **'CSV saves one year. XLSX can keep separate year tabs. Starts with {sheetName}.'**
  String yearTabsStartWith(String sheetName);

  /// No description provided for @createdFile.
  ///
  /// In en, this message translates to:
  /// **'Created {fileName}.'**
  String createdFile(String fileName);

  /// No description provided for @createdFileInFolder.
  ///
  /// In en, this message translates to:
  /// **'Created {fileName} in {folderName}.'**
  String createdFileInFolder(String fileName, String folderName);

  /// No description provided for @connectGoogleDriveOrWebDavInSettingsFirst.
  ///
  /// In en, this message translates to:
  /// **'Connect Google Drive or WebDAV in Settings first.'**
  String get connectGoogleDriveOrWebDavInSettingsFirst;

  /// No description provided for @couldNotListWebDavFolder.
  ///
  /// In en, this message translates to:
  /// **'Could not list WebDAV folder ({statusCode}).'**
  String couldNotListWebDavFolder(int statusCode);

  /// No description provided for @couldNotDownloadWebDavFile.
  ///
  /// In en, this message translates to:
  /// **'Could not download WebDAV file ({statusCode}).'**
  String couldNotDownloadWebDavFile(int statusCode);

  /// No description provided for @couldNotUploadWebDavFile.
  ///
  /// In en, this message translates to:
  /// **'Could not upload WebDAV file ({statusCode}).'**
  String couldNotUploadWebDavFile(int statusCode);

  /// No description provided for @webDavServerRespondedWith.
  ///
  /// In en, this message translates to:
  /// **'WebDAV server responded with {statusCode}. Check that the URL points to a valid WebDAV folder.'**
  String webDavServerRespondedWith(int statusCode);

  /// No description provided for @webDavEndpointUseExactUrl.
  ///
  /// In en, this message translates to:
  /// **'WebDAV endpoint rejected PROPFIND (405). Use the exact WebDAV folder URL. For Nextcloud, this is usually https://<host>/remote.php/dav/files/<username>/'**
  String get webDavEndpointUseExactUrl;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['de', 'en'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'de':
      return AppLocalizationsDe();
    case 'en':
      return AppLocalizationsEn();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
