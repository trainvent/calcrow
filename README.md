# Calcrow

Calcrow is a Flutter app for opening a spreadsheet-like work log, selecting the
right row for the current context, editing it in a focused Simple mode, and
saving the updated document back out.

The primary product surface is **Simple mode** on the Today tab. Advanced mode
still exists for older CSV workflows, but new feature work should normally target
Simple mode first.

## What The App Does

- Opens CSV, XLSX, and ODS documents.
- Detects the document type automatically from the selected file.
- Reads sheet structure into a Simple editor with typed fields.
- Supports date-based opening, date-based open-end opening, and text-based
  opening.
- Shows the loaded sheet data in the preview flow as well as the Simple editor.
- Saves updated documents locally or back to the selected cloud document,
  depending on how the file was opened.

## Simple Mode Flow

1. Choose an opening mode:
   - **Dates one a day** opens the row for today and blocks if today is missing.
   - **Dates open end** opens today if present, otherwise starts a new row for
     today.
   - **Text based** lets you choose a text column and then open a specific entry.
2. Choose a document source:
   - **Local document** opens the file picker only when no local file is selected.
     After a file is selected, tapping the local row just selects that source.
     Clear the selected local file before picking a different one.
   - **Cloud document** uses the active cloud sync file. Configure Google Drive or
     WebDAV in Settings first, then choose or create a sync file.
3. Press **Open** to load the selected document using the selected opening mode.
4. Edit the focused row in Simple mode.
5. Save the updated document.

Recent opening configurations can be saved for signed-in users. They remember the
document source and opening mode so common files can be reopened quickly.

## Local, Web, And Cloud Behavior

Local files are selected first and opened afterward. This keeps source selection
separate from opening mode selection.

Browser builds cannot reliably overwrite arbitrary local files in place. On web,
the expected flow is:

1. Open a local file.
2. Modify it in Calcrow.
3. Download the updated file when saving.

Direct overwrite is available only where the platform and file source support it,
such as Android SAF-backed files or configured cloud documents.

Cloud sync supports Google Drive and WebDAV through Settings. Cloud documents are
opened from the selected provider, edited in Simple mode, and saved back to that
cloud target.

## Project Structure

- `lib/main.dart`: app entry point
- `lib/features/home/home_shell.dart`: home shell
- `lib/features/home/today/today_page.dart`: Today tab and
  Simple-mode UI
- `lib/features/home/sheet/sheet_preview_store.dart`: preview state
- `lib/core/sheet_type_logic/simple_sheet_file_service.dart`: shared simple file
  parsing/persist helpers
- `lib/core/sheet_type_logic/csv_codec.dart`: CSV parsing and writing
- `lib/core/sheet_type_logic/xlsx_codec.dart`: XLSX parsing and writing
- `lib/core/sheet_type_logic/ods_codec.dart`: ODS parsing and writing
- `lib/core/data/services/simple_local_document_service.dart`: local file picker
  and local document opening
- `lib/core/data/services/simple_cloud_document_service.dart`: cloud document
  opening and persistence

## Run Locally

Create `.env` from `.env.example` before running builds that need configured
services.

```bash
./ci_scripts/run.sh
```

Run the web target:

```bash
./ci_scripts/run.sh -d chrome
```

Run tests:

```bash
flutter test --dart-define-from-file=.env
```

Set `USE_TEST_PURCHASES=true` in the active env file only when you want local
runs to use the RevenueCat test API key. Debug builds otherwise use the same
platform RevenueCat key as release builds.

For App Store subscription review, keep `PRIVACY_POLICY_URL` and
`TERMS_OF_USE_URL` functional, add both links to the RevenueCat paywall, and
mirror those links in App Store Connect metadata. The default Terms URL is
Apple's standard EULA.

Analyze:

```bash
flutter analyze
```

Build iOS release archives with the same configured services:

```bash
./ci_scripts/build_ios.sh
```

## Web Deploy

The web build deploys to GitHub Pages with GitHub Actions.

- Workflow: `.github/workflows/deploy-pages.yml`
- Branch trigger: `main`
- GitHub Pages path mode: root custom domain (`calcrow.com`)

Local web build for GitHub Pages:

```bash
./ci_scripts/build_web.sh
```

For GitHub Pages, set the `DART_DEFINE_ENV` repository secret to the full `.env`
file content if the deployed build should include real keys.

Before the first deploy, set the repository Pages source to `GitHub Actions`. If
using the custom domain, make sure GitHub Pages is configured for `calcrow.com`
and DNS points to GitHub Pages.
