# Tante mobile app guidance

## Project conventions

- This repository is a Flutter/Dart app. Follow the existing `lib/features/` structure and keep feature-specific screens, dialogs, and widgets grouped by context.
- Use `TanteApi` in `lib/services/tante_api.dart` for backend requests and preserve its typed parsing and `TanteApiException` error handling.
- Keep API base URLs configurable through the existing Dart defines and `config/local.json` / `config/production.json`. Never commit credentials or secrets.
- Preserve existing navigation and authentication behavior, including the distinction between landing-page sign-in and sign-in initiated from a listing.
- Add or update tests in `test/` for user-visible behavior and API contracts. Prefer injected API clients or fakes over live service calls in tests.
- Make focused changes, preserve unrelated worktree edits, and update directly related documentation when behavior or setup changes.

## Validation

For Dart or Flutter changes, run:

```sh
dart format <changed-dart-files>
flutter analyze
flutter test
```

Use focused tests while iterating, then run the full suite before finishing. Report any validation command that could not be completed.
