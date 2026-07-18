import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

/// App-wide English/German localization catalog.
///
/// English UI copy is also the stable lookup key. This keeps localization
/// usable for labels assembled by the editor while still routing every visible
/// string through Flutter's locale system.
class AppLocalizations {
  const AppLocalizations(this.locale);

  final Locale locale;

  static const supportedLocales = <Locale>[Locale('en'), Locale('de')];

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations) ??
        const AppLocalizations(Locale('en'));
  }

  String translate(String source) {
    if (locale.languageCode != 'de') return source;
    final exact = _de[source];
    if (exact != null) return exact;
    for (final template in _deTemplates) {
      final match = template.pattern.firstMatch(source);
      if (match != null) return template.build(match);
    }
    return source;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) => AppLocalizations.supportedLocales.any(
    (supported) => supported.languageCode == locale.languageCode,
  );

  @override
  Future<AppLocalizations> load(Locale locale) =>
      SynchronousFuture<AppLocalizations>(AppLocalizations(locale));

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

extension AppLocalizationBuildContext on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);
  String tr(String source) => l10n.translate(source);
  String? trNullable(String? source) =>
      source == null ? null : l10n.translate(source);
}

/// Drop-in localized counterpart to [Text].
class LText extends StatelessWidget {
  const LText(
    this.data, {
    super.key,
    this.style,
    this.strutStyle,
    this.textAlign,
    this.textDirection,
    this.locale,
    this.softWrap,
    this.overflow,
    this.textScaler,
    this.maxLines,
    this.semanticsLabel,
    this.textWidthBasis,
    this.textHeightBehavior,
    this.selectionColor,
  });

  final String data;
  final TextStyle? style;
  final StrutStyle? strutStyle;
  final TextAlign? textAlign;
  final TextDirection? textDirection;
  final Locale? locale;
  final bool? softWrap;
  final TextOverflow? overflow;
  final TextScaler? textScaler;
  final int? maxLines;
  final String? semanticsLabel;
  final TextWidthBasis? textWidthBasis;
  final TextHeightBehavior? textHeightBehavior;
  final Color? selectionColor;

  @override
  Widget build(BuildContext context) {
    return Text(
      context.tr(data),
      style: style,
      strutStyle: strutStyle,
      textAlign: textAlign,
      textDirection: textDirection,
      locale: locale,
      softWrap: softWrap,
      overflow: overflow,
      textScaler: textScaler,
      maxLines: maxLines,
      semanticsLabel: semanticsLabel == null
          ? null
          : context.tr(semanticsLabel!),
      textWidthBasis: textWidthBasis,
      textHeightBehavior: textHeightBehavior,
      selectionColor: selectionColor,
    );
  }
}

class _TranslationTemplate {
  const _TranslationTemplate(this.pattern, this.build);

  final RegExp pattern;
  final String Function(RegExpMatch match) build;
}

const Map<String, String> _de = <String, String>{
  '6-digit code': '6-stelliger Code',
  'Active cloud provider': 'Aktiver Cloud-Anbieter',
  'Ad consent reset on this device.':
      'Die Werbeeinwilligung wurde auf diesem Gerät zurückgesetzt.',
  'Ad privacy choices updated.': 'Datenschutzauswahl für Werbung aktualisiert.',
  'Add field': 'Feld hinzufügen',
  'Add WebDAV entry': 'WebDAV-Eintrag hinzufügen',
  'Adjust': 'Anpassen',
  'Ads Privacy': 'Werbedatenschutz',
  'Ads privacy choices': 'Datenschutzauswahl für Werbung',
  'Ads privacy policy': 'Datenschutzrichtlinie für Werbung',
  'All WebDAV entries unlinked.': 'Alle WebDAV-Einträge wurden getrennt.',
  'Anonymous usage patterns to understand which screens and flows are used.':
      'Anonyme Nutzungsmuster, um zu verstehen, welche Ansichten und Abläufe verwendet werden.',
  'App password': 'App-Passwort',
  'Back': 'Zurück',
  'Back to sign in': 'Zurück zur Anmeldung',
  'Both categories stay off until you explicitly enable them here. You can turn them off again at any time.':
      'Beide Kategorien bleiben deaktiviert, bis du sie hier ausdrücklich aktivierst. Du kannst sie jederzeit wieder deaktivieren.',
  'Cached field types cleared.': 'Gespeicherte Feldtypen wurden gelöscht.',
  'Cancel': 'Abbrechen',
  'Change password': 'Passwort ändern',
  'Choose': 'Auswählen',
  'Choose a document from Get Started.':
      'Wähle unter „Loslegen“ ein Dokument aus.',
  'Choose any row from the sheet.':
      'Wähle eine beliebige Zeile aus der Tabelle aus.',
  'Choose a Google Drive or WebDAV folder.':
      'Wähle einen Google-Drive- oder WebDAV-Ordner aus.',
  'Choose a save location on this device.':
      'Wähle einen Speicherort auf diesem Gerät aus.',
  'Choose a writable Android folder.':
      'Wähle einen beschreibbaren Android-Ordner aus.',
  'Choose Document': 'Dokument auswählen',
  'Choose Folder': 'Ordner auswählen',
  'Choose SAF Folder': 'SAF-Ordner auswählen',
  'Choose sync file': 'Synchronisierungsdatei auswählen',
  'Clear': 'Löschen',
  'Clear cache': 'Cache leeren',
  'Clear cached field types': 'Gespeicherte Feldtypen löschen',
  'Clear cached field types?': 'Gespeicherte Feldtypen löschen?',
  'Clear editable fields': 'Bearbeitbare Felder leeren',
  'Clear editor': 'Editor leeren',
  'Clear note': 'Notiz löschen',
  'Clear remembered cloud file': 'Gemerkte Cloud-Datei entfernen',
  'Clear remembered local file': 'Gemerkte lokale Datei entfernen',
  'Close': 'Schließen',
  'Close templates': 'Vorlagen schließen',
  'Cloud': 'Cloud',
  'Cloud document': 'Cloud-Dokument',
  'Cloud Settings': 'Cloud-Einstellungen',
  'Column': 'Spalte',
  'Confirm': 'Bestätigen',
  'Confirm field formats': 'Feldformate bestätigen',
  'Confirm new password': 'Neues Passwort bestätigen',
  'Confirm password': 'Passwort bestätigen',
  'Connect a cloud provider in Settings first.':
      'Verbinde zuerst in den Einstellungen einen Cloud-Anbieter.',
  'Connect Google Drive': 'Google Drive verbinden',
  'Continue': 'Weiter',
  'Could not acquire a writable SAF folder URI.':
      'Es konnte kein beschreibbarer SAF-Ordner abgerufen werden.',
  'Could not open the file in another app.':
      'Die Datei konnte nicht in einer anderen App geöffnet werden.',
  'Could not read CSV file content.':
      'Der Inhalt der CSV-Datei konnte nicht gelesen werden.',
  'Could not reopen the remembered local file. Choose it again.':
      'Die gemerkte lokale Datei konnte nicht erneut geöffnet werden. Wähle sie erneut aus.',
  'Current file is not SAF-backed. Use "Save as is" in Preview, or reopen via SAF.':
      'Die aktuelle Datei ist nicht SAF-gestützt. Verwende in der Vorschau „Unverändert speichern“ oder öffne sie erneut über SAF.',
  'Could not open saved sync file. Choose another one.':
      'Die gespeicherte Synchronisierungsdatei konnte nicht geöffnet werden. Wähle eine andere aus.',
  'Could not send password reset code.':
      'Der Code zum Zurücksetzen des Passworts konnte nicht gesendet werden.',
  'Crash logs, non-fatal errors, and performance monitoring to diagnose failures and slow paths.':
      'Absturzprotokolle, nicht schwerwiegende Fehler und Leistungsüberwachung zur Diagnose von Fehlern und langsamen Abläufen.',
  'Crash reports and performance': 'Absturzberichte und Leistung',
  'Create account': 'Konto erstellen',
  'Create Document': 'Dokument erstellen',
  'Create document canceled.': 'Dokumenterstellung abgebrochen.',
  'Create CSV': 'CSV erstellen',
  'Create XLSX': 'XLSX erstellen',
  'Create ODS': 'ODS erstellen',
  'Create New': 'Neu erstellen',
  'Create new': 'Neu erstellen',
  'Create new entry mode.': 'Modus für neuen Eintrag.',
  'Create new entry': 'Neuen Eintrag erstellen',
  'Create New CSV': 'Neue CSV erstellen',
  'Current behavior': 'Aktuelles Verhalten',
  'Current File': 'Aktuelle Datei',
  'Data Collection': 'Datenerfassung',
  'Data collection': 'Datenerfassung',
  'Date': 'Datum',
  'default': 'Standard',
  'Date-based open-end needs a detected date column.':
      'Der datumsbasierte Modus mit offenem Ende benötigt eine erkannte Datumsspalte.',
  'Delete Account': 'Konto löschen',
  'Delete account': 'Konto löschen',
  'Define columns and field types for a fresh sheet.':
      'Definiere Spalten und Feldtypen für eine neue Tabelle.',
  'Details': 'Details',
  'Summary': 'Zusammenfassung',
  'Kind': 'Art',
  'Origin': 'Ursprung',
  'Request host': 'Anfragehost',
  'Request path': 'Anfragepfad',
  'Request method': 'Anfragemethode',
  'Required CORS methods': 'Erforderliche CORS-Methoden',
  'Required CORS headers': 'Erforderliche CORS-Header',
  'Technical details': 'Technische Details',
  'unknown': 'unbekannt',
  'browser_blocked': 'vom Browser blockiert',
  'network': 'Netzwerk',
  'auth': 'Authentifizierung',
  'method_not_allowed': 'Methode nicht erlaubt',
  'Desktop to mobile, optimized to fit.':
      'Vom Desktop bis zum Smartphone optimal angepasst.',
  'Diary': 'Tagebuch',
  'Discard': 'Verwerfen',
  'Editor cleared.': 'Editor geleert.',
  'Email': 'E-Mail',
  'End': 'Ende',
  'Enter app password': 'App-Passwort eingeben',
  'Entitlement': 'Berechtigung',
  'Every template starts with Date as the first column. Pick a starting point, then rename, add, remove, and reorder the remaining fields before creating the document.':
      'Jede Vorlage beginnt mit Datum als erster Spalte. Wähle einen Ausgangspunkt und benenne, ergänze, entferne oder sortiere die übrigen Felder, bevor du das Dokument erstellst.',
  'Explain opening modes': 'Öffnungsmodi erklären',
  'FALSE': 'FALSCH',
  'Field formats confirmed.': 'Feldformate bestätigt.',
  'Fields': 'Felder',
  'File name': 'Dateiname',
  'Focused row editing': 'Fokussierte Zeilenbearbeitung',
  'Focused row is highlighted': 'Die fokussierte Zeile ist hervorgehoben',
  'Focus, blockers, wins...': 'Fokus, Hindernisse, Erfolge …',
  'Folder': 'Ordner',
  'Forgot password?': 'Passwort vergessen?',
  'Free plan': 'Kostenloser Tarif',
  'Got it': 'Verstanden',
  'Help Improve Calcrow': 'Hilf mit, Calcrow zu verbessern',
  'Hours': 'Stunden',
  'How to open the sheet': 'So wird die Tabelle geöffnet',
  'I agree to the Terms of Use, Privacy Policy, and Ads Privacy Policy.':
      'Ich stimme den Nutzungsbedingungen, der Datenschutzrichtlinie und der Datenschutzrichtlinie für Werbung zu.',
  'I already have an account': 'Ich habe bereits ein Konto',
  'If phone works but web fails, this is usually CORS/TLS on the WebDAV server.':
      'Wenn es auf dem Smartphone funktioniert, aber im Web nicht, liegt es meist an CORS/TLS auf dem WebDAV-Server.',
  'Keep Off': 'Deaktiviert lassen',
  'Link': 'Verbinden',
  'Link WebDAV / Nextcloud': 'WebDAV / Nextcloud verbinden',
  'Local': 'Lokal',
  'Local document': 'Lokales Dokument',
  'Logbook': 'Arbeitsprotokoll',
  'Manage SAF folder': 'SAF-Ordner verwalten',
  'Manage separate consent for usage analytics and crash or performance diagnostics.':
      'Einwilligungen für Nutzungsanalyse und Absturz- oder Leistungsdiagnose getrennt verwalten.',
  'Manage WebDAV entries': 'WebDAV-Einträge verwalten',
  'Manage': 'Verwalten',
  'Manage Google Drive and WebDAV connections.':
      'Google-Drive- und WebDAV-Verbindungen verwalten.',
  'Manage your subscription, privacy, and account access.':
      'Abonnement, Datenschutz und Kontozugriff verwalten.',
  'Manage widgets': 'Widgets verwalten',
  'Minutes': 'Minuten',
  'Mobile two-column view': 'Mobile Zweispaltenansicht',
  'Monthly': 'Monatlich',
  'Move down': 'Nach unten',
  'Move up': 'Nach oben',
  'Namelist': 'Namensliste',
  'New': 'Neu',
  'New password': 'Neues Passwort',
  'New row submitted.': 'Neue Zeile übernommen.',
  'No account email is available.': 'Keine Konto-E-Mail verfügbar.',
  'No editable field types to reset.':
      'Keine bearbeitbaren Feldtypen zum Zurücksetzen vorhanden.',
  'No entry found for this date.':
      'Für dieses Datum wurde kein Eintrag gefunden.',
  'No file loaded yet.': 'Noch keine Datei geladen.',
  'No email available.': 'Keine E-Mail-Adresse verfügbar.',
  'No SAF folder configured.': 'Kein SAF-Ordner konfiguriert.',
  'No recent opening configurations saved yet.':
      'Noch keine zuletzt verwendeten Öffnungskonfigurationen gespeichert.',
  'No SAF target selected. Open a SAF-backed file or configure SAF folder in Settings, or use "Save as is" in Preview.':
      'Kein SAF-Ziel ausgewählt. Öffne eine SAF-gestützte Datei, konfiguriere einen SAF-Ordner in den Einstellungen oder verwende in der Vorschau „Unverändert speichern“.',
  'Note: this sheet is just an example':
      'Hinweis: Diese Tabelle ist nur ein Beispiel',
  'Notes': 'Notizen',
  'Open a CSV, XLSX, or ODS document': 'CSV-, XLSX- oder ODS-Dokument öffnen',
  'Open CSV, XLSX, or ODS.': 'CSV, XLSX oder ODS öffnen.',
  'Open the existing row for today and keep one entry per day.':
      'Öffne die vorhandene Zeile für heute und behalte einen Eintrag pro Tag.',
  'Open today if it exists, otherwise start a new row for today.':
      'Öffne den heutigen Eintrag, falls er vorhanden ist, oder beginne eine neue Zeile für heute.',
  'Choose an existing named entry from a text column and edit that row.':
      'Wähle einen vorhandenen benannten Eintrag aus einer Textspalte und bearbeite diese Zeile.',
  'Your table needs a date column with one prepared row per day.':
      'Deine Tabelle benötigt eine Datumsspalte mit einer vorbereiteten Zeile pro Tag.',
  'Your table needs a date column; Calcrow can add today as a new row.':
      'Deine Tabelle benötigt eine Datumsspalte; Calcrow kann heute als neue Zeile hinzufügen.',
  'Your table needs an editable text column with the entry names.':
      'Deine Tabelle benötigt eine bearbeitbare Textspalte mit den Namen der Einträge.',
  'Open subscription and purchase options.':
      'Abonnement- und Kaufoptionen öffnen.',
  'Open CSV, XLSX, or ODS. Calcrow detects the file type automatically.':
      'CSV, XLSX oder ODS öffnen. Calcrow erkennt den Dateityp automatisch.',
  'Open CSV, XLSX, or ODS files, edit the focused row in core editor, and save back to local or cloud storage.':
      'Öffne CSV-, XLSX- oder ODS-Dateien, bearbeite die fokussierte Zeile im Editor und speichere sie lokal oder in der Cloud.',
  'Opened document in another app.': 'Dokument in einer anderen App geöffnet.',
  'Opening document...': 'Dokument wird geöffnet …',
  'Opening Mode': 'Öffnungsmodus',
  'Opening mode': 'Öffnungsmodus',
  'Opening modes': 'Öffnungsmodi',
  'Password': 'Passwort',
  'Password updated.': 'Passwort aktualisiert.',
  'Password updated. You can sign in now.':
      'Passwort aktualisiert. Du kannst dich jetzt anmelden.',
  'Pause (min)': 'Pause (Min.)',
  'Pick SAF folder': 'SAF-Ordner auswählen',
  'Pick row': 'Zeile auswählen',
  'Pick Row': 'Zeile auswählen',
  'Pick Entry': 'Eintrag auswählen',
  'Preparing editor fields...': 'Editorfelder werden vorbereitet …',
  'Previous': 'Zurück',
  'Privacy controls': 'Datenschutzeinstellungen',
  'Privacy Policy': 'Datenschutzrichtlinie',
  'Pro enabled.': 'Pro aktiviert.',
  'Read how Calcrow and Google AdMob handle consent choices for the EEA, UK, Switzerland, and applicable US state privacy rules.':
      'Lies nach, wie Calcrow und Google AdMob Einwilligungen für den EWR, das Vereinigte Königreich, die Schweiz und geltende Datenschutzregeln von US-Bundesstaaten behandeln.',
  'Remembered cloud sync file cleared.':
      'Gemerkte Cloud-Synchronisierungsdatei entfernt.',
  'Remembered local file cleared. Pick a file again anytime.':
      'Gemerkte lokale Datei entfernt. Du kannst jederzeit wieder eine Datei auswählen.',
  'Remove column': 'Spalte entfernen',
  'Remove one entry': 'Einen Eintrag entfernen',
  'Remove WebDAV entry': 'WebDAV-Eintrag entfernen',
  'Resend code': 'Code erneut senden',
  'Reset': 'Zurücksetzen',
  'Reset ad consent': 'Werbeeinwilligung zurücksetzen',
  'Reset ad consent?': 'Werbeeinwilligung zurücksetzen?',
  'Reset code': 'Zurücksetzungscode',
  'Row updated. File save canceled.':
      'Zeile aktualisiert. Speichern der Datei abgebrochen.',
  'Row-Definement': 'Zeilendefinition',
  'Row': 'Zeile',
  'SAF folder cleared.': 'SAF-Ordner entfernt.',
  'SAF folder selection canceled.': 'Auswahl des SAF-Ordners abgebrochen.',
  'SAF folder setup is Android-only.':
      'Die Einrichtung eines SAF-Ordners ist nur unter Android verfügbar.',
  'SAF save canceled. Use "Save as is" in Preview.':
      'SAF-Speichern abgebrochen. Verwende in der Vorschau „Unverändert speichern“.',
  'SAF save is not available here. Use "Save as is" in Preview.':
      'SAF-Speichern ist hier nicht verfügbar. Verwende in der Vorschau „Unverändert speichern“.',
  'SAF stream write failed. Use "Save as is" in Preview.':
      'Schreiben in den SAF-Datenstrom fehlgeschlagen. Verwende in der Vorschau „Unverändert speichern“.',
  'Same row, compacted for mobile screens':
      'Dieselbe Zeile, kompakt für mobile Bildschirme',
  'Save': 'Speichern',
  'Save Choices': 'Auswahl speichern',
  'Save into the folder configured in Settings.':
      'Im in den Einstellungen konfigurierten Ordner speichern.',
  'Save New Document': 'Neues Dokument speichern',
  'Save the current row before starting a new one?':
      'Die aktuelle Zeile speichern, bevor eine neue begonnen wird?',
  'Scan passkey QR': 'Passkey-QR-Code scannen',
  'Select active entry': 'Aktiven Eintrag auswählen',
  'Select Local File': 'Lokale Datei auswählen',
  'Select WebDAV entry': 'WebDAV-Eintrag auswählen',
  'Select currency': 'Währung auswählen',
  'Select date': 'Datum auswählen',
  'Selector': 'Auswahl',
  'Set': 'Festlegen',
  'Set Recent': 'Zuletzt verwendet festlegen',
  'Set recent': 'Zuletzt verwendet festlegen',
  'Settings': 'Einstellungen',
  'Sheet manipulation on the go.': 'Tabellen unterwegs bearbeiten.',
  'Sheet separation': 'Tabellenaufteilung',
  'Sheet': 'Tabelle',
  'Sheet Preview': 'Tabellenvorschau',
  'Sign in': 'Anmelden',
  'Sign in or create account': 'Anmelden oder Konto erstellen',
  'Sign in to save this Android folder setting to your account.':
      'Melde dich an, um diese Android-Ordner-Einstellung in deinem Konto zu speichern.',
  'Sign in to use Calcrow.': 'Melde dich an, um Calcrow zu verwenden.',
  'Sign in to use recent opening configurations.':
      'Melde dich an, um zuletzt verwendete Öffnungskonfigurationen zu nutzen.',
  'Sign out': 'Abmelden',
  'Signed in as': 'Angemeldet als',
  'Signed in. Welcome to Calcrow.': 'Angemeldet. Willkommen bei Calcrow.',
  'Signed out': 'Abgemeldet',
  'Smart Data': 'Intelligente Daten',
  'Start': 'Beginn',
  'Start from a fresh monthly sheet': 'Mit einer neuen Monatstabelle beginnen',
  'Support': 'Support',
  'Templates': 'Vorlagen',
  'Terms': 'Bedingungen',
  'Terms of Use': 'Nutzungsbedingungen',
  'Text-based opening needs at least one editable text column for new entries.':
      'Textbasiertes Öffnen benötigt mindestens eine bearbeitbare Textspalte für neue Einträge.',
  'The selected CSV is empty.': 'Die ausgewählte CSV-Datei ist leer.',
  'This folder has no subfolders.': 'Dieser Ordner enthält keine Unterordner.',
  'This folder has no supported CSV, XLSX, or ODS files yet. Open another folder or create a new sync file here.':
      'Dieser Ordner enthält noch keine unterstützten CSV-, XLSX- oder ODS-Dateien. Öffne einen anderen Ordner oder erstelle hier eine neue Synchronisierungsdatei.',
  'This SAF source cannot be overwritten directly. Reopen from a writable folder via SAF, or use "Save as is".':
      'Diese SAF-Quelle kann nicht direkt überschrieben werden. Öffne sie über SAF aus einem beschreibbaren Ordner erneut oder verwende „Unverändert speichern“.',
  'This WebDAV entry is already active.':
      'Dieser WebDAV-Eintrag ist bereits aktiv.',
  'Total': 'Gesamt',
  'TRUE': 'WAHR',
  'Type': 'Typ',
  'Unlink all entries': 'Alle Einträge trennen',
  'Unlink': 'Trennen',
  'Unsaved row edits': 'Ungespeicherte Zeilenänderungen',
  'Update': 'Aktualisieren',
  'Upgrade': 'Upgrade',
  'Up one folder': 'Eine Ordnerebene nach oben',
  'Usage analytics': 'Nutzungsanalyse',
  'Available on Android only.': 'Nur unter Android verfügbar.',
  'Connect a WebDAV or Nextcloud folder using its WebDAV URL.':
      'Verbinde einen WebDAV- oder Nextcloud-Ordner über seine WebDAV-URL.',
  'Connected to Google Drive': 'Mit Google Drive verbunden',
  'Grant Drive read/write permissions for cloud document sync.':
      'Erteile Drive-Lese- und Schreibberechtigungen für die Cloud-Dokumentsynchronisierung.',
  'WebDAV connected': 'Mit WebDAV verbunden',
  'Ad unavailable now (Google no fill).':
      'Werbung derzeit nicht verfügbar (Google liefert keine Anzeige).',
  'Ad unavailable due to app/config issue.':
      'Werbung wegen eines App- oder Konfigurationsproblems nicht verfügbar.',
  'Ad unavailable (unknown cause).':
      'Werbung nicht verfügbar (unbekannte Ursache).',
  'Use current SAF folder': 'Aktuellen SAF-Ordner verwenden',
  'Use these formats': 'Diese Formate verwenden',
  'Use This Folder': 'Diesen Ordner verwenden',
  'Verification code reissued.': 'Bestätigungscode erneut gesendet.',
  'WebDAV error details': 'WebDAV-Fehlerdetails',
  'Wellbeing': 'Wohlbefinden',
  'Widget layout is locked because this CSV already has entries.':
      'Das Widget-Layout ist gesperrt, weil diese CSV-Datei bereits Einträge enthält.',
  'Workhours': 'Arbeitszeiten',
  'worklog editor': 'Arbeitszeit-Editor',
  'Yearly': 'Jährlich',
  'Account Settings': 'Kontoeinstellungen',
  'Advanced': 'Erweitert',
  'Arrange fields': 'Felder anordnen',
  'Calcrow Daily Editor': 'Calcrow-Tageseditor',
  'Core': 'Basis',
  'Editor': 'Editor',
  'Finish arranging': 'Anordnen beenden',
  'Get Started': 'Loslegen',
  'Hide field types': 'Feldtypen ausblenden',
  'Jump Today': 'Zu heute springen',
  'Next Row': 'Nächste Zeile',
  'Pick': 'Auswählen',
  'Show field types': 'Feldtypen anzeigen',
  'Submit New': 'Neu übernehmen',
  'Text': 'Text',
  'boolean': 'Wahrheitswert',
  'date': 'Datum',
  'duration': 'Dauer',
  'email': 'E-Mail',
  'float': 'Dezimalzahl',
  'integer': 'Ganzzahl',
  'money': 'Geldbetrag',
  'phone': 'Telefon',
  'text': 'Text',
  'time': 'Uhrzeit',
  'Minutes or HH:MM:SS': 'Minuten oder HH:MM:SS',
  'TRUE or FALSE': 'WAHR oder FALSCH',
  'Amount': 'Betrag',
  'Bike km': 'Rad-km',
  'Client': 'Kunde',
  'Client A': 'Kunde A',
  'Client B': 'Kunde B',
  'Client C': 'Kunde C',
  'Customer': 'Kunde',
  'Customer Service': 'Kundenservice',
  'Energy': 'Energie',
  'Expenses': 'Ausgaben',
  'Guestlist': 'Gästeliste',
  'Health': 'Gesundheit',
  'Invoices': 'Rechnungen',
  'Location': 'Standort',
  'Mood': 'Stimmung',
  'Name': 'Name',
  'Phone': 'Telefon',
  'Project': 'Projekt',
  'Reps': 'Wiederholungen',
  'Run km': 'Lauf-km',
  'Sets': 'Sätze',
  'Squats': 'Kniebeugen',
  'Status': 'Status',
  'Steps': 'Schritte',
  'Swim km': 'Schwimm-km',
  'Work done': 'Erledigte Arbeit',
  'A clean day-by-day timesheet with breaks and notes.':
      'Ein übersichtlicher täglicher Stundenzettel mit Pausen und Notizen.',
  'Basic invoice tracking with dates, clients, and totals.':
      'Einfache Rechnungsverfolgung mit Datum, Kunden und Gesamtbeträgen.',
  'Bring an existing file or generate a full month table with your preferred date style.':
      'Importiere eine vorhandene Datei oder erstelle sofort eine vollständige Monatstabelle mit deinem bevorzugten Datumsformat.',
  'Calcrow gives you one clean daily editor so you update logs fast on your phone.':
      'Calcrow bietet einen übersichtlichen Tageseditor, mit dem du Protokolle schnell auf dem Smartphone aktualisierst.',
  'Clean and Press weight': 'Umsetzen und Drücken – Gewicht',
  'Barbell Curl weight': 'Langhantel-Curls – Gewicht',
  'Behind-the-neck Press weight': 'Nackendrücken – Gewicht',
  'Upright Row weight': 'Aufrechtes Rudern – Gewicht',
  'Barbell Squat weight': 'Langhantel-Kniebeugen – Gewicht',
  'Barbell Row weight': 'Langhantel-Rudern – Gewicht',
  'Barbell Bench Press weight': 'Langhantel-Bankdrücken – Gewicht',
  'Barbell Pullover weight': 'Langhantel-Pullover – Gewicht',
  'Import or create monthly CSV instantly':
      'Monatliche CSV sofort importieren oder erstellen',
  'Invoice': 'Rechnung',
  'Keep data local, sync when you choose':
      'Daten lokal halten und bei Bedarf synchronisieren',
  'Log customer visits, billable time, expenses, and outcomes.':
      'Kundenbesuche, abrechenbare Zeit, Ausgaben und Ergebnisse protokollieren.',
  'Names, contacts, and RSVP status for an event.':
      'Namen, Kontakte und Zu- oder Absagen für eine Veranstaltung.',
  'Pull-ups': 'Klimmzüge',
  'Push-ups': 'Liegestütze',
  'Start offline. Later connect account sync and backups without changing your workflow.':
      'Starte offline. Verbinde später Kontosynchronisierung und Backups, ohne deinen Arbeitsablauf zu ändern.',
  'Track training sessions without turning the sheet into a fitness app.':
      'Trainingseinheiten erfassen, ohne die Tabelle in eine Fitness-App zu verwandeln.',
  'Track swim, bike, run, and strength work in one row.':
      'Schwimmen, Radfahren, Laufen und Krafttraining in einer Zeile erfassen.',
  'Track workdays in under a minute':
      'Arbeitstage in weniger als einer Minute erfassen',
  'Triathlon Training Tracker Plus': 'Triathlon-Trainingsplaner Plus',
  'Workout like Bruce Lee': 'Trainieren wie Bruce Lee',
  'Accept the Terms of Use, Privacy Policy, and Ads Privacy Policy to create an account.':
      'Akzeptiere die Nutzungsbedingungen, die Datenschutzrichtlinie und die Datenschutzrichtlinie für Werbung, um ein Konto zu erstellen.',
  'Code is invalid or expired.': 'Der Code ist ungültig oder abgelaufen.',
  'Could not create your account right now.':
      'Dein Konto kann derzeit nicht erstellt werden.',
  'Could not resend code.': 'Der Code konnte nicht erneut gesendet werden.',
  'Could not reset password right now.':
      'Das Passwort kann derzeit nicht zurückgesetzt werden.',
  'Could not sign in right now.': 'Die Anmeldung ist derzeit nicht möglich.',
  'Could not verify code right now.':
      'Der Code kann derzeit nicht bestätigt werden.',
  'Create your account and continue to setup.':
      'Erstelle dein Konto und fahre mit der Einrichtung fort.',
  'Email and password are required.':
      'E-Mail-Adresse und Passwort sind erforderlich.',
  'Email, password and confirmation are required.':
      'E-Mail-Adresse, Passwort und Bestätigung sind erforderlich.',
  'Email address format is invalid.':
      'Das Format der E-Mail-Adresse ist ungültig.',
  'Email is required.': 'Eine E-Mail-Adresse ist erforderlich.',
  'Email or password is incorrect.': 'E-Mail-Adresse oder Passwort ist falsch.',
  'Email/password auth is disabled in Firebase Auth settings.':
      'Die Anmeldung mit E-Mail und Passwort ist in Firebase Auth deaktiviert.',
  'Enter the 6-digit code.': 'Gib den 6-stelligen Code ein.',
  'Enter the 6-digit verification code.':
      'Gib den 6-stelligen Bestätigungscode ein.',
  'Enter the code from your email and choose a new password.':
      'Gib den Code aus deiner E-Mail ein und wähle ein neues Passwort.',
  'Firebase web config is invalid for this app/environment.':
      'Die Firebase-Webkonfiguration ist für diese App oder Umgebung ungültig.',
  'Missing verification context. Sign in again.':
      'Bestätigungsdaten fehlen. Melde dich erneut an.',
  'Network error. Check connection and try again.':
      'Netzwerkfehler. Prüfe die Verbindung und versuche es erneut.',
  'New password and confirmation are required.':
      'Neues Passwort und Bestätigung sind erforderlich.',
  'No account found for that email.':
      'Für diese E-Mail-Adresse wurde kein Konto gefunden.',
  'No active code was found. Request a new code.':
      'Kein aktiver Code gefunden. Fordere einen neuen Code an.',
  'No active reset code was found. Request a new one.':
      'Kein aktiver Zurücksetzungscode gefunden. Fordere einen neuen an.',
  'Password is too weak.': 'Das Passwort ist zu schwach.',
  'Password must be at least 6 characters.':
      'Das Passwort muss mindestens 6 Zeichen lang sein.',
  'Passwords do not match.': 'Die Passwörter stimmen nicht überein.',
  'Permission denied by Firestore rules.':
      'Zugriff durch Firestore-Regeln verweigert.',
  'Register': 'Registrieren',
  'Request failed.': 'Anfrage fehlgeschlagen.',
  'Reset password': 'Passwort zurücksetzen',
  'Send reset code': 'Zurücksetzungscode senden',
  'Service temporarily unavailable. Try again.':
      'Dienst vorübergehend nicht verfügbar. Versuche es erneut.',
  'Set new password': 'Neues Passwort festlegen',
  'That code has expired. Request a new one.':
      'Dieser Code ist abgelaufen. Fordere einen neuen an.',
  'That reset code is no longer valid. Request a new one.':
      'Dieser Zurücksetzungscode ist nicht mehr gültig. Fordere einen neuen an.',
  'The code was not accepted. Check it and try again.':
      'Der Code wurde nicht akzeptiert. Prüfe ihn und versuche es erneut.',
  'This auth operation is restricted by Firebase project settings.':
      'Dieser Anmeldevorgang ist durch die Firebase-Projekteinstellungen eingeschränkt.',
  'This domain is not authorized for Firebase Auth.':
      'Diese Domain ist nicht für Firebase Auth autorisiert.',
  'This email is already in use.':
      'Diese E-Mail-Adresse wird bereits verwendet.',
  'Too many attempts. Try again later.':
      'Zu viele Versuche. Versuche es später erneut.',
  'Too many failed attempts. Request a new code.':
      'Zu viele fehlgeschlagene Versuche. Fordere einen neuen Code an.',
  'Use your email and password.':
      'Verwende deine E-Mail-Adresse und dein Passwort.',
  'Verify': 'Bestätigen',
  'Verify email': 'E-Mail bestätigen',
  'We will send a 6-digit password reset code to your email.':
      'Wir senden einen 6-stelligen Code zum Zurücksetzen des Passworts an deine E-Mail-Adresse.',
  'Your session expired. Sign in again and request a new code.':
      'Deine Sitzung ist abgelaufen. Melde dich erneut an und fordere einen neuen Code an.',
  'Add at least one column.': 'Füge mindestens eine Spalte hinzu.',
  'Column names must be unique.': 'Spaltennamen müssen eindeutig sein.',
  'Dates open end needs one date column.':
      'Der Datumsmodus mit offenem Ende benötigt eine Datumsspalte.',
  'Cached field types do not match Logbook.':
      'Die gespeicherten Feldtypen passen nicht zum Arbeitsprotokoll.',
  'Cached field types do not match Namelist.':
      'Die gespeicherten Feldtypen passen nicht zur Namensliste.',
  'App password is required.': 'Ein App-Passwort ist erforderlich.',
  'App password imported from QR. Enter server URL and username to continue.':
      'App-Passwort aus dem QR-Code importiert. Gib Server-URL und Benutzernamen ein, um fortzufahren.',
  'Enter the WebDAV URL, username, and app password.':
      'Gib WebDAV-URL, Benutzername und App-Passwort ein.',
  'QR code was read, but the format is not supported. Use URL, username, and app password fields.':
      'Der QR-Code wurde gelesen, aber das Format wird nicht unterstützt. Verwende die Felder für URL, Benutzername und App-Passwort.',
  'QR scan is available on Android and iOS only.':
      'Das Scannen von QR-Codes ist nur unter Android und iOS verfügbar.',
  'Server URL imported from QR. Enter username and app password to continue.':
      'Server-URL aus dem QR-Code importiert. Gib Benutzername und App-Passwort ein, um fortzufahren.',
  'Username': 'Benutzername',
  'Enter a valid WebDAV URL.': 'Gib eine gültige WebDAV-URL ein.',
  'Could not validate the WebDAV URL.':
      'Die WebDAV-URL konnte nicht überprüft werden.',
  'WebDAV credentials are missing on this device. Re-link the account in Settings.':
      'Auf diesem Gerät fehlen WebDAV-Zugangsdaten. Verbinde das Konto in den Einstellungen erneut.',
  'This WebDAV folder path contains unsupported characters.':
      'Dieser WebDAV-Ordnerpfad enthält nicht unterstützte Zeichen.',
  'This WebDAV folder path could not be opened.':
      'Dieser WebDAV-Ordnerpfad konnte nicht geöffnet werden.',
  'The WebDAV server returned an invalid folder response.':
      'Der WebDAV-Server hat eine ungültige Ordnerantwort zurückgegeben.',
  'A file or folder name in this WebDAV directory uses unsupported characters.':
      'Ein Datei- oder Ordnername in diesem WebDAV-Verzeichnis enthält nicht unterstützte Zeichen.',
  'This WebDAV folder contains an entry that could not be opened.':
      'Dieser WebDAV-Ordner enthält einen Eintrag, der nicht geöffnet werden konnte.',
  'This WebDAV file path contains unsupported characters.':
      'Dieser WebDAV-Dateipfad enthält nicht unterstützte Zeichen.',
  'This WebDAV file path could not be opened.':
      'Dieser WebDAV-Dateipfad konnte nicht geöffnet werden.',
  'This WebDAV file path could not be saved.':
      'Dieser WebDAV-Dateipfad konnte nicht gespeichert werden.',
  'WebDAV sign-in failed. Check the username and app password.':
      'WebDAV-Anmeldung fehlgeschlagen. Prüfe Benutzername und App-Passwort.',
  'WebDAV endpoint rejected PROPFIND (405).':
      'Der WebDAV-Endpunkt hat PROPFIND abgelehnt (405).',
  'Could not reach the WebDAV server. Check the URL and network access.':
      'Der WebDAV-Server konnte nicht erreicht werden. Prüfe URL und Netzwerkzugriff.',
  'Could not reach the WebDAV server from this browser. Check URL, HTTPS certificate, and network access.':
      'Der WebDAV-Server konnte aus diesem Browser nicht erreicht werden. Prüfe URL, HTTPS-Zertifikat und Netzwerkzugriff.',
  'Browser blocked the WebDAV request (likely CORS/TLS). Allow this app origin in WebDAV CORS and permit methods PROPFIND/GET/PUT with headers Authorization, Depth, and Content-Type.':
      'Der Browser hat die WebDAV-Anfrage blockiert (wahrscheinlich CORS/TLS). Erlaube den Ursprung dieser App in WebDAV-CORS sowie die Methoden PROPFIND/GET/PUT mit den Headern Authorization, Depth und Content-Type.',
  'Could not read cloud document content.':
      'Der Inhalt des Cloud-Dokuments konnte nicht gelesen werden.',
  'No cloud provider is active. Choose Google Drive or WebDAV in Settings first.':
      'Kein Cloud-Anbieter ist aktiv. Wähle zuerst Google Drive oder WebDAV in den Einstellungen.',
  'Could not read document content.':
      'Der Dokumentinhalt konnte nicht gelesen werden.',
  'Could not reopen the remembered local document.':
      'Das gemerkte lokale Dokument konnte nicht erneut geöffnet werden.',
  'Drive metadata is incomplete.': 'Die Drive-Metadaten sind unvollständig.',
  'Google Drive authorization was canceled.':
      'Die Google-Drive-Autorisierung wurde abgebrochen.',
  'Google account email is unavailable.':
      'Die E-Mail-Adresse des Google-Kontos ist nicht verfügbar.',
  'Google account unlinked.': 'Google-Konto getrennt.',
  'Google Drive is not connected in this session. Connect Google Drive again to refresh access.':
      'Google Drive ist in dieser Sitzung nicht verbunden. Verbinde Google Drive erneut, um den Zugriff zu aktualisieren.',
  'Purchases are unavailable right now. Please try again later.':
      'Käufe sind derzeit nicht verfügbar. Versuche es später erneut.',
  'Purchases are unavailable in this build. Please update the app and try again.':
      'Käufe sind in diesem Build nicht verfügbar. Aktualisiere die App und versuche es erneut.',
  'Could not open subscription options. Please try again later.':
      'Abonnementoptionen konnten nicht geöffnet werden. Versuche es später erneut.',
  'RevenueCat paywalls are not supported on web builds.':
      'RevenueCat-Paywalls werden in Web-Builds nicht unterstützt.',
  'RevenueCat customer center is not supported on web builds.':
      'Das RevenueCat-Kundencenter wird in Web-Builds nicht unterstützt.',
  'Open the permanent account deletion flow.':
      'Dauerhafte Kontolöschung öffnen.',
  'Send a reset code to your signed-in email.':
      'Zurücksetzungscode an deine angemeldete E-Mail-Adresse senden.',
  'The selected document has no named sheets.':
      'Das ausgewählte Dokument enthält keine benannten Tabellenblätter.',
  'The selected ODS has no content.xml.':
      'Die ausgewählte ODS-Datei enthält keine content.xml.',
  'The selected ODS has no spreadsheet body.':
      'Die ausgewählte ODS-Datei enthält keinen Tabelleninhalt.',
  'The selected ODS has no sheets.':
      'Die ausgewählte ODS-Datei enthält keine Tabellenblätter.',
  'The selected ODS sheet is empty.':
      'Das ausgewählte ODS-Tabellenblatt ist leer.',
  'The selected XLSX has no sheets.':
      'Die ausgewählte XLSX-Datei enthält keine Tabellenblätter.',
  'The selected XLSX sheet is empty.':
      'Das ausgewählte XLSX-Tabellenblatt ist leer.',
  'First row has no header titles.':
      'Die erste Zeile enthält keine Spaltenüberschriften.',
  'No ODS sheet is selected.': 'Kein ODS-Tabellenblatt ausgewählt.',
  'No XLSX workbook is loaded.': 'Keine XLSX-Arbeitsmappe geladen.',
  'Could not encode ODS document.':
      'Das ODS-Dokument konnte nicht codiert werden.',
  'Could not create ODS document.':
      'Das ODS-Dokument konnte nicht erstellt werden.',
  'Could not encode XLSX workbook.':
      'Die XLSX-Arbeitsmappe konnte nicht codiert werden.',
  'Choose separately whether Calcrow may collect anonymous usage analytics and technical crash or performance diagnostics.':
      'Wähle getrennt aus, ob Calcrow anonyme Nutzungsanalysen und technische Absturz- oder Leistungsdiagnosen erfassen darf.',
  'Choose separately whether Calcrow may collect anonymous usage analytics, technical crash or performance diagnostics, and ad privacy preferences where supported.':
      'Wähle getrennt aus, ob Calcrow anonyme Nutzungsanalysen, technische Absturz- oder Leistungsdiagnosen und – soweit unterstützt – Werbedatenschutzeinstellungen erfassen darf.',
  'Manage your Google ad privacy choices. This entry point must stay available after consent is collected.':
      'Verwalte deine Google-Werbedatenschutzauswahl. Dieser Zugang muss nach Erfassung der Einwilligung verfügbar bleiben.',
  'Google does not currently require a persistent ad privacy options button on this device or region.':
      'Google verlangt auf diesem Gerät oder in dieser Region derzeit keine dauerhaft verfügbare Schaltfläche für Werbedatenschutzoptionen.',
  'Refresh ad privacy choices and review the latest Google consent options for this device.':
      'Aktualisiere die Werbedatenschutzauswahl und prüfe die neuesten Google-Einwilligungsoptionen für dieses Gerät.',
  'Clear the current AdMob consent state on this device. Ads stay disabled until Google collects consent again.':
      'Lösche den aktuellen AdMob-Einwilligungsstatus auf diesem Gerät. Werbung bleibt deaktiviert, bis Google erneut eine Einwilligung erfasst.',
  'Clear any stored AdMob consent state on this device and force the Google consent flow to ask again later.':
      'Lösche gespeicherte AdMob-Einwilligungen auf diesem Gerät, damit Google später erneut danach fragt.',
  'Collect anonymous usage patterns to understand which screens and flows are used.':
      'Anonyme Nutzungsmuster erfassen, um zu verstehen, welche Ansichten und Abläufe verwendet werden.',
  'Usage analytics are not available on this platform.':
      'Nutzungsanalysen sind auf dieser Plattform nicht verfügbar.',
  'Send crash logs, non-fatal errors, and performance monitoring data to help analyze app failures and slow paths.':
      'Absturzprotokolle, nicht schwerwiegende Fehler und Leistungsdaten senden, um App-Fehler und langsame Abläufe zu analysieren.',
  'Crash reporting and performance monitoring are only available on supported mobile builds.':
      'Absturzberichte und Leistungsüberwachung sind nur in unterstützten mobilen Builds verfügbar.',
  'Usage analytics enabled.': 'Nutzungsanalyse aktiviert.',
  'Usage analytics disabled.': 'Nutzungsanalyse deaktiviert.',
  'Crash reporting and performance monitoring enabled.':
      'Absturzberichte und Leistungsüberwachung aktiviert.',
  'Crash reporting and performance monitoring disabled.':
      'Absturzberichte und Leistungsüberwachung deaktiviert.',
  'Calcrow is delivered by ': 'Calcrow wird bereitgestellt von ',
  'Choose whether Calcrow may collect anonymous usage analytics and technical crash or performance diagnostics. You can change both later in Settings.':
      'Wähle aus, ob Calcrow anonyme Nutzungsanalysen und technische Absturz- oder Leistungsdiagnosen erfassen darf. Du kannst beides später in den Einstellungen ändern.',
  'This clears the current Google AdMob consent state on this device. The next consent refresh may ask again before ads can be requested.':
      'Dadurch wird der aktuelle Google-AdMob-Einwilligungsstatus auf diesem Gerät gelöscht. Bei der nächsten Aktualisierung kann erneut gefragt werden, bevor Werbung angefordert wird.',
};

final List<_TranslationTemplate> _deTemplates = <_TranslationTemplate>[
  _template(
    r'^(Local|Google Drive|WebDAV) - (Diary|Logbook|Namelist)$',
    (m) =>
        '${_translateGermanFragment(m[1]!)} – ${_translateGermanFragment(m[2]!)}',
  ),
  _template(
    r'^(Steps|Location|Health|Mood|Energy): (.+)$',
    (m) => '${_translateGermanFragment(m[1]!)}: ${m[2]}',
  ),
  _template(
    r'^Authentication failed \((.+)\)\.$',
    (m) => 'Authentifizierung fehlgeschlagen (${m[1]}).',
  ),
  _template(
    r'^Request failed \((.+)\)\.$',
    (m) => 'Anfrage fehlgeschlagen (${m[1]}).',
  ),
  _template(
    r'^Could not list WebDAV folder \((.+)\)\.$',
    (m) => 'WebDAV-Ordner konnte nicht aufgelistet werden (${m[1]}).',
  ),
  _template(
    r'^Could not download WebDAV file \((.+)\)\.$',
    (m) => 'WebDAV-Datei konnte nicht heruntergeladen werden (${m[1]}).',
  ),
  _template(
    r'^Could not upload WebDAV file \((.+)\)\.$',
    (m) => 'WebDAV-Datei konnte nicht hochgeladen werden (${m[1]}).',
  ),
  _template(
    r'^WebDAV server responded with (.+)\. Check that the URL points to a valid WebDAV folder\.$',
    (m) =>
        'Der WebDAV-Server hat mit ${m[1]} geantwortet. Prüfe, ob die URL auf einen gültigen WebDAV-Ordner verweist.',
  ),
  _template(
    r'^Clear the remembered field types for (.+)\? Calcrow will infer or ask for field types the next time you open it\.$',
    (m) =>
        'Gespeicherte Feldtypen für ${m[1]} löschen? Calcrow erkennt die Feldtypen beim nächsten Öffnen oder fragt danach.',
  ),
  _template(
    r'^Date-based opening is blocked because (.+) was not found in the detected date column\.$',
    (m) =>
        'Datumsbasiertes Öffnen ist blockiert, weil ${m[1]} in der erkannten Datumsspalte nicht gefunden wurde.',
  ),
  _template(
    r'^(\d+) entry for this date found\.$',
    (m) => '1 Eintrag für dieses Datum gefunden.',
  ),
  _template(
    r'^(\d+) entries for this date found\.$',
    (m) => '${m[1]} Einträge für dieses Datum gefunden.',
  ),
  _template(
    r'^Could not open ads privacy policy\. Visit (.+) in a browser\.$',
    (m) =>
        'Die Datenschutzrichtlinie für Werbung konnte nicht geöffnet werden. Rufe ${m[1]} in einem Browser auf.',
  ),
  _template(
    r'^WebDAV entry added: (.+) on (.+)\.$',
    (m) => 'WebDAV-Eintrag hinzugefügt: ${m[1]} auf ${m[2]}.',
  ),
  _template(
    r'^Loaded (.+) \((\d+) entries\)\.$',
    (m) => '${m[1]} geladen (${m[2]} Einträge).',
  ),
  _template(
    r'^Loaded (.+) \((\d+) entries\) from tab (.+)\. SAF target ready\.$',
    (m) =>
        '${m[1]} geladen (${m[2]} Einträge) aus Tabellenblatt ${m[3]}. SAF-Ziel bereit.',
  ),
  _template(
    r'^Loaded (.+) \((\d+) entries\) from tab (.+)\. SAF target not detected\.$',
    (m) =>
        '${m[1]} geladen (${m[2]} Einträge) aus Tabellenblatt ${m[3]}. Kein SAF-Ziel erkannt.',
  ),
  _template(
    r'^Loaded (.+) \((\d+) entries\) from sheet (.+)\. SAF target ready\.$',
    (m) =>
        '${m[1]} geladen (${m[2]} Einträge) aus Tabelle ${m[3]}. SAF-Ziel bereit.',
  ),
  _template(
    r'^Loaded (.+) \((\d+) entries\) from sheet (.+)\. SAF target not detected\.$',
    (m) =>
        '${m[1]} geladen (${m[2]} Einträge) aus Tabelle ${m[3]}. Kein SAF-Ziel erkannt.',
  ),
  _template(
    r'^Loaded Google Sheet (.+) \((\d+) entries\) from tab (.+)\.$',
    (m) =>
        'Google-Tabelle ${m[1]} geladen (${m[2]} Einträge) aus Tabellenblatt ${m[3]}.',
  ),
  _template(
    r'^Uses a multi-sheet format such as XLSX\. Starts with (.+)\.$',
    (m) =>
        'Verwendet ein Format mit mehreren Tabellenblättern wie XLSX. Beginnt mit ${m[1]}.',
  ),
  _template(
    r'^CSV saves one year\. XLSX can keep separate year tabs\. Starts with (.+)\.$',
    (m) =>
        'CSV speichert ein Jahr. XLSX kann getrennte Jahresblätter enthalten. Beginnt mit ${m[1]}.',
  ),
  _template(
    r'^(.+) must be an integer\.$',
    (m) => '${m[1]} muss eine Ganzzahl sein.',
  ),
  _template(
    r'^(.+) must be a float\.$',
    (m) => '${m[1]} muss eine Dezimalzahl sein.',
  ),
  _template(
    r'^(.+) must be a money amount\.$',
    (m) => '${m[1]} muss ein Geldbetrag sein.',
  ),
  _template(
    r'^(.+) must be TRUE or FALSE\.$',
    (m) => '${m[1]} muss WAHR oder FALSCH sein.',
  ),
  _template(r'^(.+) must be a date\.$', (m) => '${m[1]} muss ein Datum sein.'),
  _template(
    r'^(.+) must be a time\.$',
    (m) => '${m[1]} muss eine Uhrzeit sein.',
  ),
  _template(
    r'^(.+) must be a duration\.$',
    (m) => '${m[1]} muss eine Dauer sein.',
  ),
  _template(
    r'^Row updated\. Downloaded updated file as (.+)\.$',
    (m) =>
        'Zeile aktualisiert. Aktualisierte Datei als ${m[1]} heruntergeladen.',
  ),
  _template(
    r'^Row saved to app storage at (.+)\.$',
    (m) => 'Zeile im App-Speicher unter ${m[1]} gespeichert.',
  ),
  _template(
    r'^Row saved to (.+)\. Future saves will overwrite this file\.$',
    (m) =>
        'Zeile in ${m[1]} gespeichert. Zukünftiges Speichern überschreibt diese Datei.',
  ),
  _template(r'^Row saved to (.+)\.$', (m) => 'Zeile in ${m[1]} gespeichert.'),
  _template(
    r'^Loaded same-date entry (\d+)/(\d+)\. Edit and submit a new row if needed\.$',
    (m) =>
        'Eintrag mit gleichem Datum ${m[1]}/${m[2]} geladen. Bearbeite und übernimm bei Bedarf eine neue Zeile.',
  ),
  _template(r'^Created (.+) in (.+)\.$', (m) => '${m[1]} in ${m[2]} erstellt.'),
  _template(
    r'^Opened local document (.+)\.$',
    (m) => 'Lokales Dokument ${m[1]} geöffnet.',
  ),
  _template(
    r'^Linked as (.+) on (.+)$',
    (m) => 'Verknüpft als ${m[1]} auf ${m[2]}',
  ),
  _template(r'^Linked as (.+)$', (m) => 'Verknüpft als ${m[1]}'),
  _template(
    r'^(\d+) WebDAV entries\. Active: (.+) on (.+)$',
    (m) => '${m[1]} WebDAV-Einträge. Aktiv: ${m[2]} auf ${m[3]}',
  ),
  _template(
    r'^(\d+) WebDAV entries\. Active: (.+)$',
    (m) => '${m[1]} WebDAV-Einträge. Aktiv: ${m[2]}',
  ),
  _template(r'^money \((.+)\)$', (m) => 'Geldbetrag (${m[1]})'),
  _template(
    r'^Type: (.+) \(fixed\)$',
    (m) => 'Typ: ${_translateGermanFragment(m[1]!)} (fest)',
  ),
  _template(
    r'^Type: (.+) \(enter hours and minutes\)$',
    (m) =>
        'Typ: ${_translateGermanFragment(m[1]!)} (Stunden und Minuten eingeben)',
  ),
  _template(r'^Type: (.+)$', (m) => 'Typ: ${_translateGermanFragment(m[1]!)}'),
  _template(
    r'^The first field must stay (Date|Text) for this opening mode\.$',
    (m) =>
        'Das erste Feld muss für diesen Öffnungsmodus ${m[1] == 'Date' ? 'Datum' : 'Text'} bleiben.',
  ),
  _template(
    r'^Choose a row for (.+)\.$',
    (m) => 'Wähle eine Zeile für ${m[1]} aus.',
  ),
  _template(r'^Column (.+)$', (m) => 'Spalte ${m[1]}'),
  _template(r'^Sent to (.+)$', (m) => 'Gesendet an ${m[1]}'),
  _template(
    r'^Password required for (.+)$',
    (m) => 'Passwort für ${m[1]} erforderlich',
  ),
  _template(
    r'^Password reset code sent to (.+)\.$',
    (m) => 'Code zum Zurücksetzen des Passworts an ${m[1]} gesendet.',
  ),
  _template(
    r'^Enter the code sent to (.+)\.$',
    (m) => 'Gib den an ${m[1]} gesendeten Code ein.',
  ),
  _template(
    r'^Could not (.+): (.+)$',
    (m) =>
        '${_couldNot[m[1]] ?? 'Vorgang fehlgeschlagen'}: ${_translateGermanFragment(m[2]!)}',
  ),
  _template(
    r'^Import failed: (.+)$',
    (m) => 'Import fehlgeschlagen: ${_translateGermanFragment(m[1]!)}',
  ),
  _template(
    r'^Google link failed: (.+)$',
    (m) =>
        'Google-Verknüpfung fehlgeschlagen: ${_translateGermanFragment(m[1]!)}',
  ),
  _template(
    r'^WebDAV update failed: (.+)$',
    (m) =>
        'WebDAV-Aktualisierung fehlgeschlagen: ${_translateGermanFragment(m[1]!)}',
  ),
  _template(
    r'^Row saved in app, but file write failed: (.+)$',
    (m) =>
        'Zeile in der App gespeichert, aber Schreiben der Datei fehlgeschlagen: ${_translateGermanFragment(m[1]!)}',
  ),
  _template(
    r'^Selected local document (.+)\.$',
    (m) => 'Lokales Dokument ${m[1]} ausgewählt.',
  ),
  _template(
    r'^Selected local file: (.+)$',
    (m) => 'Ausgewählte lokale Datei: ${m[1]}',
  ),
  _template(
    r'^Imported (.+) \((\d+) rows\)\.$',
    (m) => '${m[1]} importiert (${m[2]} Zeilen).',
  ),
  _template(
    r'^No rows found for (.+)\.$',
    (m) => 'Keine Zeilen für ${m[1]} gefunden.',
  ),
  _template(
    r'^WebDAV entry removed: (.+)\.$',
    (m) => 'WebDAV-Eintrag entfernt: ${m[1]}.',
  ),
  _template(r'^Active sheet: (.+)$', (m) => 'Aktive Tabelle: ${m[1]}'),
  _template(
    r'^(\d+) rows • (\d+) columns$',
    (m) => '${m[1]} Zeilen • ${m[2]} Spalten',
  ),
  _template(r'^Debug code: (.+)$', (m) => 'Debug-Code: ${m[1]}'),
  _template(r'^Current file: (.+)$', (m) => 'Aktuelle Datei: ${m[1]}'),
  _template(r'^Created (.+)\.$', (m) => '${m[1]} erstellt.'),
  _template(
    r'^Opened (.+) document (.+)\.$',
    (m) => '${m[2]} als ${m[1]}-Dokument geöffnet.',
  ),
  _template(
    r'^(.+) sync file cleared\.$',
    (m) => '${m[1]}-Synchronisierungsdatei entfernt.',
  ),
  _template(
    r'^(.+) is now the active cloud provider\.$',
    (m) => '${m[1]} ist jetzt der aktive Cloud-Anbieter.',
  ),
  _template(
    r'^Google Drive connected: (.+)\. Choose a Drive file next\.$',
    (m) =>
        'Google Drive verbunden: ${m[1]}. Wähle als Nächstes eine Drive-Datei aus.',
  ),
  _template(
    r'^Open (.+) in a browser to continue\.$',
    (m) => 'Öffne ${m[1]} in einem Browser, um fortzufahren.',
  ),
  _template(
    r'^Open the permanent account deletion flow\.$',
    (m) => 'Dauerhafte Kontolöschung öffnen.',
  ),
  _template(
    r'^Send a reset code to your signed-in email\.$',
    (m) => 'Zurücksetzungscode an deine angemeldete E-Mail-Adresse senden.',
  ),
];

_TranslationTemplate _template(
  String source,
  String Function(RegExpMatch match) build,
) => _TranslationTemplate(RegExp(source), build);

String _translateGermanFragment(String source) {
  const localizations = AppLocalizations(Locale('de'));
  for (final prefix in const <String>['FormatException: ', 'Bad state: ']) {
    if (source.startsWith(prefix)) {
      final translatedPrefix = prefix.startsWith('Format')
          ? 'Formatfehler: '
          : 'Ungültiger Zustand: ';
      return '$translatedPrefix${localizations.translate(source.substring(prefix.length))}';
    }
  }
  return localizations.translate(source);
}

const Map<String, String> _couldNot = <String, String>{
  'clear cached field types':
      'Gespeicherte Feldtypen konnten nicht gelöscht werden',
  'clear SAF folder': 'SAF-Ordner konnte nicht entfernt werden',
  'create cloud document': 'Cloud-Dokument konnte nicht erstellt werden',
  'create local document': 'Lokales Dokument konnte nicht erstellt werden',
  'open ad privacy choices':
      'Datenschutzauswahl für Werbung konnte nicht geöffnet werden',
  'open ads privacy policy':
      'Datenschutzrichtlinie für Werbung konnte nicht geöffnet werden',
  'open cloud document': 'Cloud-Dokument konnte nicht geöffnet werden',
  'open subscription options':
      'Abonnementoptionen konnten nicht geöffnet werden',
  'refresh ad privacy choices':
      'Datenschutzauswahl für Werbung konnte nicht aktualisiert werden',
  'reset ad consent': 'Werbeeinwilligung konnte nicht zurückgesetzt werden',
  'select document': 'Dokument konnte nicht ausgewählt werden',
  'set SAF folder': 'SAF-Ordner konnte nicht festgelegt werden',
  'update cloud provider': 'Cloud-Anbieter konnte nicht aktualisiert werden',
  'update crash reporting':
      'Absturzberichterstattung konnte nicht aktualisiert werden',
  'update usage analytics': 'Nutzungsanalyse konnte nicht aktualisiert werden',
};
