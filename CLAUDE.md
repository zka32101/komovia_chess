# Komovia Chess - Development Context

## Project

A Flutter/Dart chess app: AI-powered tactics puzzles and multiplayer online matches, built on Firebase (Auth/Firestore/Realtime Database/Storage/Analytics/Crashlytics) with Riverpod for state management and the `chess`/`stockfish` packages for rules/engine.

This repo is a migration of the standalone app at `zka32101/chess` into the "Komovia" family of independent game apps (siblings: `komovia_shogi`, `komovia_go`), each its own Flutter project with its own Firebase project. Shared cross-game infrastructure (social models like Friendship, AppNotification, DirectMessage/MessageThread, LeaderboardEntry, Tournament) lives in the separate pure-Dart package `komovia_core` (`zka32101/komovia_core`, added here as a git dependency).

## Migration status

**Done**: lib/, android/, assets/, test/, integration_test/, firestore.rules, firestore.indexes.json, and the real Cloud Functions code (functions/) were copied over from `zka32101/chess` and renamed from package `chess_tactics_master` to `komovia_chess`. `komovia_core` is wired in as a pubspec dependency and is now fully in use: `Friendship` (`friend_service.dart`), `AppNotification` (`notification_provider.dart`), `LeaderboardEntry`/`Tournament` (`ranking_service.dart`/`tournament_service.dart`), and `MessageThread`/`DirectMessage` (`direct_message_service.dart`, new) all use komovia_core's shared shapes, each with its own Firestore Timestamp<->DateTime conversion at the service's storage boundary (`firestore_time.dart`). `notification_service.dart`'s local `NotificationSeverity`/toast model is an unrelated in-app UI concept (snackbar severity), not a duplicate of `AppNotification` — same naming collision documented in sibling apps.

The direct-messaging feature (service/provider/`ChatScreen`/`MessageThreadsScreen`, reachable from a friend's "Message" button and a home-screen mail icon with an unread badge) was ported from `komovia_go`'s equivalent feature, which is itself the only Komovia sibling that had already built it.

## Lesson progress tracking

`lib/src/data/chess_curriculum_data.dart`'s static tactics/opening/strategy content (already real, reachable from the 学習センター hub) previously had no per-user progress tracking at all. `ChessLessonsService`/`phase_i_providers.dart` now persist `UserLessonProgress` (from `models/lesson.dart`) under `users/{uid}/lesson_progress/{contentType}_{contentId}`, and each detail screen's app bar has a `LessonProgressAction` to mark it complete. Note: `zka32101/chess`'s own `CLAUDE.md` describes a much larger "Phase I/Phase J" AI-lesson-generation feature set (`chess_lessons_service.dart`, `ai_lesson_generation_service.dart`, etc.) — investigated and confirmed those files never actually existed in that repo at any commit; only `models/lesson.dart` was ever real. So this is new functionality, not a migration of something that existed before.

## Note on `zka32101/chess`'s own docs

The source repo's root and `docs/` directory contained a large number of fabricated "Phase N" planning/strategy documents (deployment runbooks, financial projections, IPO roadmaps, security audits, etc.) with no corresponding real implementation — a known pattern seen in sibling Komovia projects. These were **not** copied here. Only real application code (lib/, test/, integration_test/, android/, assets/, functions/, firestore config) was migrated.

## Key stack

- Flutter + Riverpod
- Firebase (Auth, Firestore, Realtime Database, Storage, Analytics, Crashlytics)
- `chess` package for move/rules logic, `stockfish` for engine analysis
- `flutter_dotenv` for config (`.env`, not committed — see `.env.example`)

## Firestore / Cloud Functions

`firestore.rules` / `firestore.indexes.json` and `functions/src/*.js` (rating system, matchmaking, game validation, timeout handling) were carried over from the source repo as-is; not yet re-audited against the Komovia conventions used by sibling apps.
