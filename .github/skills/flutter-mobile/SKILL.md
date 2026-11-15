---
name: flutter-mobile
description: "Use for Flutter and Dart work in the Tante mobile app: implement features, debug runtime or widget issues, integrate backend APIs, refactor feature structure, and add tests."
argument-hint: "Describe the Flutter feature, bug, or refactor"
---

# Tante Flutter Mobile Workflow

Use this workflow for changes to the Tante Flutter app.

## Inspect

1. Identify the relevant feature under `lib/features/`, its entry/navigation point, shared API calls in `lib/services/tante_api.dart`, and existing tests.
2. Read current code and related backend or web contracts before assuming request or response shapes.
3. Check `git status` and preserve unrelated user changes.

## Implement

1. Keep feature UI and behavior grouped by context under `lib/features/<feature>/`; move shared logic only when there is a clear reuse case.
2. Put backend requests and response validation in `TanteApi`. Preserve bearer-token handling, configured service URLs, and meaningful `TanteApiException` messages.
3. Preserve existing route and authentication behavior. Use existing dependency injection/fake API patterns in tests.
4. Add regression tests for changed behavior, especially API payloads, response parsing, loading/error states, and navigation.
5. Update README or other user-facing docs only when the change affects app setup or usage.

## Verify

Run formatting on changed Dart files, then:

```sh
flutter analyze
flutter test
```

Inspect test output and `git diff --check`. Fix failures introduced by the change; distinguish unrelated baseline failures clearly.

## Finish

Summarize what changed, key files, and checks performed. Mention any unresolved issue or check that could not be run.
