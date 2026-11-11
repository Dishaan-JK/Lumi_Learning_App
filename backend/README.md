# Bundled Lumi service

This is the Dart/Genkit HTTP service bundled with the Learning-App-React web
client. It is kept in this repository so packaging does not depend on a sibling
checkout. The package contains only the backend entry point and the libraries
it needs; the Flutter UI is not part of this package.

The source snapshot was copied from the existing Lumi backend worktree on
2026-11-11, including the note-only agent action and student-profile settings
needed by the current React client. The original backend checkout was left
untouched. Update this package and its lockfile in the same change as backend
API changes used by the React client.

Build a standalone backend binary with Dart 3.12 or newer:

```sh
dart pub get
dart compile exe --packages=.dart_tool/package_config.json bin/server.dart -o lumi-backend
```
