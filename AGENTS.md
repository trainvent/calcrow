# AGENTS.md

## Product Focus
- Primary UI surface is **Simple mode**.
- Treat `lib/features/home/presentation/tabs/simple/today_tab_simple.dart` as the default target for feature work.
- `lib/features/home/presentation/tabs/advanced/today_tab_advanced.dart` is **not a priority**. Only change advanced mode if the user explicitly asks.

## Code Areas That Matter Most
- App entry: `lib/main.dart`
- Home shell: `lib/features/home/presentation/home_shell.dart`
- Today tab selector: `lib/features/home/presentation/tabs/today_tab.dart`
- Simple editor: `lib/features/home/presentation/tabs/simple/today_tab_simple.dart`
- Sheet preview store: `lib/features/home/presentation/sheet_preview_store.dart`
- CSV logic: `lib/core/sheet_type_logic/csv_logic.dart`
- XLSX logic: `lib/core/sheet_type_logic/xlsx_logic.dart`
- File models: `lib/core/sheet_type_logic/sheet_file_models.dart`

## Working Rules
- Keep behavior aligned between parse and persist paths (CSV/XLSX).
- When editing file import/export logic, verify both:
  - data shown in simple editor
  - data shown in preview tab
- Prefer targeted edits over broad refactors.
- Preserve existing UX text unless the request is explicitly UX copy/design.

## Web Constraints (Important)
- Browser builds cannot reliably overwrite arbitrary local files in place.
- Expected web flow is: open file -> modify in app -> save/download updated file.
- “Open via link” should be treated as a separate integration path (Drive/API/auth), not local file overwrite.

## Quick Commands
- Run app: `flutter run`
- Run web: `flutter run -d chrome`
- Tests: `flutter test`
- Analyze: `flutter analyze`

## Change Checklist (Before finishing)
- Confirm changes are in the intended tab (`simple` unless requested otherwise).
- Confirm no accidental advanced-mode edits (unless requested).
- Check for obvious null/state issues in async UI handlers (`mounted` checks).
- Update user-visible error messages when a new failure path is introduced.
