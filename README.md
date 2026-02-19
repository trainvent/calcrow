# calcrow Mobile (Flutter)

A tool to display a line of CSV in a visually appealing way. The line gets picked by date given in the first column. 

## Current App Structure

- `lib/app`: app bootstrap and theme
- `lib/features/onboarding`: onboarding flow
- `lib/features/auth`: auth entry sheet (UI shell)
- `lib/features/home`: post-onboarding shell (`Today`, `History`, `Settings`)

## Run

```bash
flutter run
```

## Firebase Recommendation

Yes, Firebase is a strong fit for your mobile app:

- Auth: `firebase_auth` (Google + Apple + email)
- Data sync: `cloud_firestore` (profiles, settings, metadata)
- File backup: `firebase_storage` (CSV snapshots/backups)
- Analytics and release quality: `firebase_analytics`, `crashlytics`, `remote_config`

For V1, keep local-first CSV editing and add Firebase sign-in plus optional sync as V1.1.

## Suggested Next Build Steps

1. Add state management (`riverpod`) and route management (`go_router`).
2. Port CSV parsing/generation logic from `web_react/lib/csv.ts` to Dart.
3. Add Excel support (`.xlsx`): import, parse, and export while preserving sheet/column types.
4. Build in-app spreadsheet editing for CSV and Excel files (cell edit, add/remove rows, save).
5. Add further support for (`.ods`)
6. Persist local data with `isar` or `sqflite`.
7. Wire Firebase project + auth providers.
8. Add paywall/subscription layer only after retention signals.
