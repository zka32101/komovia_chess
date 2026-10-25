# Komovia Chess

A Flutter chess app: AI-powered tactics puzzles and online multiplayer matches, backed by Firebase.

Part of the Komovia family of independent game apps (alongside `komovia_shogi`, `komovia_go`), each its own Flutter project / Firebase project, sharing cross-game social models (friendships, notifications, direct messages, leaderboards, tournaments) via the `komovia_core` package.

## Status

This repo was scaffolded by migrating the standalone `chess` app (`zka32101/chess`) into the Komovia structure. The migration is in progress:

- [x] App code, assets, Android config, tests copied and renamed to `komovia_chess`
- [x] `komovia_core` added as a dependency
- [ ] Social features (friends, notifications, direct messages, leaderboard, tournaments) still use this app's own local model copies; migrating them to `komovia_core`'s shared models is a follow-up pass, not yet done

## Setup

```bash
flutter pub get
cp .env.example .env   # fill in your Firebase/RevenueCat config
flutter run --dart-define-from-file=.env
```

`.env` is **not** bundled into the app - it's only read at build/run time via
`--dart-define-from-file`, so its values get compiled into the binary as
Dart constants instead of shipping as a plaintext file inside the APK/IPA.
Always pass `--dart-define-from-file=.env` to `flutter run`/`flutter build`;
without it, the app falls back to the placeholder values baked into
`lib/firebase_options.dart`.

Requires a Firebase project (Auth, Firestore, Realtime Database, Storage, Analytics, Crashlytics) configured via the values in `.env`.

## Dependencies

- `komovia_core` (git dependency on `zka32101/komovia_core`) — shared cross-game models
- Firebase (Auth/Firestore/Realtime DB/Storage/Analytics/Crashlytics)
- Riverpod for state management
- `chess`/`stockfish` packages for chess rules/engine
