# Komovia Chess - Development Context

## Project

A Flutter/Dart chess app: AI-powered tactics puzzles and multiplayer online matches, built on Firebase (Auth/Firestore/Realtime Database/Storage/Analytics/Crashlytics) with Riverpod for state management and the `chess`/`stockfish` packages for rules/engine.

This repo is a migration of the standalone app at `zka32101/chess` into the "Komovia" family of independent game apps (siblings: `komovia_shogi`, `komovia_go`), each its own Flutter project with its own Firebase project. Shared cross-game infrastructure (social models like Friendship, AppNotification, DirectMessage/MessageThread, LeaderboardEntry, Tournament) lives in the separate pure-Dart package `komovia_core` (`zka32101/komovia_core`, added here as a git dependency).

## Migration status

**Done**: lib/, android/, assets/, test/, integration_test/, firestore.rules, firestore.indexes.json, and the real Cloud Functions code (functions/) were copied over from `zka32101/chess` and renamed from package `chess_tactics_master` to `komovia_chess`. `komovia_core` is wired in as a pubspec dependency but not yet used.

**Not done (deliberately left for a follow-up pass)**: this app's own local models/services for friends, notifications, direct messages, leaderboard, and tournaments still exist as this app's own copies rather than importing the shared classes from `package:komovia_core/komovia_core.dart`. That extraction — replacing local model declarations with komovia_core imports, and adding Firestore Timestamp<->DateTime conversion helpers (`firestore_time.dart`) in each service that persists a komovia_core model — is a separate, later piece of work (this is the same order of operations used for `komovia_go`: that project's initial scaffold also deferred this extraction to its own follow-up PR).

## Note on `zka32101/chess`'s own docs

The source repo's root and `docs/` directory contained a large number of fabricated "Phase N" planning/strategy documents (deployment runbooks, financial projections, IPO roadmaps, security audits, etc.) with no corresponding real implementation — a known pattern seen in sibling Komovia projects. These were **not** copied here. Only real application code (lib/, test/, integration_test/, android/, assets/, functions/, firestore config) was migrated.

## Key stack

- Flutter + Riverpod
- Firebase (Auth, Firestore, Realtime Database, Storage, Analytics, Crashlytics)
- `chess` package for move/rules logic, `stockfish` for engine analysis
- `flutter_dotenv` for config (`.env`, not committed — see `.env.example`)

## Firestore / Cloud Functions

`firestore.rules` / `firestore.indexes.json` and `functions/src/*.js` (rating system, matchmaking, game validation, timeout handling) were carried over from the source repo as-is; not yet re-audited against the Komovia conventions used by sibling apps.
