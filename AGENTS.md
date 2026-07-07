# AGENTS.md

## Product Focus
- Primary UI surface is **Simple mode**.
- Treat `lib/features/home/today/today_page.dart` and `lib/features/home/today/simple/` as the default targets for feature work.
- `lib/features/home/today/advanced/` is **not a priority**. Only change advanced mode if the user explicitly asks.

## Code Areas That Matter Most
- App entry: `lib/main.dart`
- Home shell: `lib/features/home/home_shell.dart`
- Today tab selector: `lib/features/home/today/today_tab.dart`
- Simple editor: `lib/features/home/today/today_page.dart`
- Sheet preview store: `lib/features/home/sheet/sheet_preview_store.dart`
- CSV logic: `lib/core/sheet_type_logic/csv_codec.dart`
- XLSX logic: `lib/core/sheet_type_logic/xlsx_codec.dart`
- File models: `lib/core/sheet_type_logic/sheet_file_models.dart`

## Working Rules
- Keep behavior aligned between parse and persist paths (CSV/XLSX).
- When editing file import/export logic, verify both:
  - data shown in simple editor
  - data shown in preview tab
- Prefer targeted edits over broad refactors.
- Preserve existing UX text unless the request is explicitly UX copy/design.
- Backwards compatibility is not required for Simple mode schema/type label changes unless explicitly requested.

## Web Constraints (Important)
- Browser builds cannot reliably overwrite arbitrary local files in place.
- Expected web flow is: open file -> modify in app -> save/download updated file.
- “Open via link” should be treated as a separate integration path (Drive/API/auth), not local file overwrite.

## Quick Commands
- Run app: `./ci_scripts/run.sh`
- Run web: `./ci_scripts/run.sh -d chrome`
- Tests: `flutter test --dart-define-from-file=.env`
- Analyze: `flutter analyze`

## Change Checklist (Before finishing)
- Confirm changes are in the intended tab (`simple` unless requested otherwise).
- Confirm no accidental advanced-mode edits (unless requested).
- Check for obvious null/state issues in async UI handlers (`mounted` checks).
- Update user-visible error messages when a new failure path is introduced.
