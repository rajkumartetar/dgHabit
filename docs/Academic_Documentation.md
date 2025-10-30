# dgHabit: Academic Project Documentation

Title: dgHabit – A Minimal, Sheet‑Based Habit and Activity Tracker

Authors: [Your Name]

Affiliation: [Institute / Department]

Date: October 30, 2025

---

## Abstract

dgHabit is a cross‑platform Flutter application that helps users build habits through a daily timeline of activities, lightweight automation (steps, screen time), and clear analytics. The app employs a persistent shell with a unified AppBar and presents feature UIs as modal bottom sheets for a modern, focused user experience. This document describes the problem and motivation, objectives, literature context, system architecture and design, implementation details (including activity continuity handling), testing methodology with automated screenshot generation, and results. We conclude with limitations and future work.

## 1. Introduction

Habit formation is a compound process of planning, repetition, and feedback. Many tools log steps or tasks in isolation but make it hard to see the day holistically. dgHabit aims to unify manual and automatic signals into a continuous “timeline” that reflects real days, while keeping the interface minimal and responsive.

## 2. Objectives

- Build a daily activity timeline that preserves continuity (no gaps/overlaps after edits).
- Support quick manual logging and custom categories.
- Integrate lightweight automation sources (steps, screen time) with user consent.
- Provide simple analytics for weekly trends and category breakdown.
- Deliver a cohesive UI with a persistent shell and bottom‑sheet feature surfaces.

## 3. Literature Review (Brief)

- Habit tracking apps (e.g., Streaks, Habitica) focus on check‑ins; fewer visualize continuous time allocation.
- Time‑blocking tools (e.g., calendar) provide continuity but emphasize planning over retrospective logging.
- Mobile sensor research shows practical collection of steps and usage metrics under explicit permissions; privacy and clarity of consent remain central.

## 4. System Design and Architecture

- Platform: Flutter (Material 3) for Android, iOS, Web, Desktop.
- State: Riverpod providers (e.g., `firebaseServiceProvider`, `sensorServiceProvider`).
- Data: Firebase Auth/Firestore; per‑user collections under `users/{uid}`.
- UI: Unified AppBar theme; persistent root Scaffold (AppBar + Bottom Nav). Feature UIs (Add Activity, Activity Detail, Settings, Permissions, Category Manager) presented as modal bottom sheets with compact sheet headers.
- Services:
  - FirebaseService: activity CRUD and continuity helpers (detect and resolve overlaps/gaps).
  - Sensor integration: steps (Activity Recognition), screen time (Usage Access on Android).

### 4.1 Data Model

```
ActivityModel
- activityId: string
- activityName: string
- startTime: Date
- endTime: Date
- category: string
- source: enum(manual|auto)
- steps?: int
- screenTimeMinutes?: double
```

### 4.2 Continuity Handling (Algorithm Outline)

Goal: After inserting or editing an activity, maintain a continuous timeline without overlaps. Let A′ be the new or updated activity.

- Detect: Query previous neighbor (prev) and next neighbor (next) around A′. Report `prevOverlap = prev.end > A′.start`, `nextOverlap = A′.end > next.start`.
- Strategies (user‑selectable when overlap exists):
  - If prevOverlap: either trim prev.end to A′.start, or move A′.start to prev.end.
  - If nextOverlap: either trim A′.end to next.start, or move next.start to A′.end.
- Apply selected strategy then upsert activities; ensure invariants prev.end ≤ A′.start ≤ A′.end ≤ next.start.

Edge cases:
- Activities confined to a single day (clamp edits within current day).
- Very short durations (enforce minimum duration or allow zero‑length for markers as future work).
- Deletions collapse gaps; app may optionally extend neighbors (future work).

## 5. Implementation

- Unified AppBar color: 0xFF2DD4BF (mint), white foreground across light/dark.
- Sheet header component: `SheetHeader` reused across sheets (title + actions + close).
- Screens updated to sheet mode (`inSheet` flag): Add Activity, Activity Detail, Settings, Permissions, Category Manager.
- Timeline interactions: tap to open details sheet; swipe left to edit; swipe right to delete with UNDO.
- Quick Actions sheet: record screen time for today, show steps, start/stop a steps session.

Key files:
- `lib/theme/app_theme.dart` – unified AppBar styling.
- `lib/screens/home_screen.dart` – persistent shell; launches sheet screens.
- `lib/screens/timeline_screen.dart` – swipe actions and list rendering.
- `lib/screens/add_activity_screen.dart`, `lib/screens/activity_detail_screen.dart` – in‑sheet editing with continuity choices.
- `lib/screens/settings_screen.dart`, `lib/screens/permissions_screen.dart`, `lib/screens/category_manager_screen.dart` – sheet variants with `SheetHeader`.
- `lib/widgets/sheet_header.dart` – reusable header.

## 6. Screens and UX Walkthrough

The following images live under `docs/screenshots/individual/` and were generated via automated goldens.

- Splash: `splash.png`
- Onboarding: `onboarding.png`
- Home: `home.png`
- Timeline: `timeline.png`
- Analytics: `analytics.png`
- Add Activity (page): `add_activity.png`; (sheet): `sheet_add_activity.png`
- Activity Detail (page): `activity_detail.png`; (sheet): `sheet_activity_detail.png`
- Settings (page): `settings.png`; (sheet): `sheet_settings.png`
- Category Manager (page): `category_manager.png`; (sheet): `sheet_category_manager.png`
- Permissions (page): `permissions.png`; (sheet): `sheet_permissions.png`
- Quick Actions (sheet): `sheet_quick_actions.png`

Composite overview: `docs/screenshots/all_screens.png`.

## 7. Testing and Validation

- Golden screenshots: `test/screenshots/golden_screens_test.dart` uses a fake Firebase service and local fonts to avoid network I/O.
- Command to regenerate:

```powershell
flutter test --update-goldens test/screenshots/golden_screens_test.dart
```

- Analyzer/lints: flutter_lints; deprecations replaced; tests pass.

## 8. Results and Discussion

- The sheet‑based UX preserved navigation context, reducing full‑screen transitions and visual churn.
- Swipe gestures and Quick Actions improved capture speed for common tasks.
- Continuity helpers prevented broken timelines after inserts/edits, with explicit choices when overlaps occur.

## 9. Limitations

- iOS screen time APIs are not implemented (Android Usage Access only).
- Sensors can be noisy; step streams may vary by device.
- No offline sync conflict resolution (future enhancement).

## 10. Future Work

- Dark mode golden assets; tablet/desktop responsive layouts.
- Additional automations (calendar import, location‑based suggestions).
- Reminders, streaks, and habit goals.
- Advanced continuity policies (auto‑merge/extend neighbors).

## 11. Ethical and Privacy Considerations

- Permissions are explicit and revocable; app provides a Permissions screen and guidance.
- Data is scoped per user UID; no analytics/telemetry beyond functional logging.
- Users can delete activities; future work: export/delete all data.

## 12. References

- Flutter, Riverpod, Firebase official documentation.
- Literature on habit formation and time‑use studies (add citations as needed).

## 13. Appendix A: Design System

- Colors:
  - AppBar background: 0xFF2DD4BF; foreground: white.
  - Material 3 light/dark schemes elsewhere.
- Typography:
  - Sheet headers use TitleMedium with fontWeight 700.
- Components:
  - Reusable `SheetHeader` (title + actions + close), FilledButton/OutlinedButton, compact ListTiles.

## 14. Appendix B: How to Run

```powershell
flutter pub get
flutter run
```

Configure Firebase with `google-services.json` (Android) and `GoogleService-Info.plist` (iOS) as applicable.

## 15. Appendix C: Export to DOCX/PDF/RTF (Pandoc)

Optional: Use Pandoc to export this Markdown document to common academic formats.

Install Pandoc (Windows):

```powershell
winget install Pandoc.Pandoc
```

Export to DOCX:

```powershell
pandoc -s docs/Academic_Documentation.md -o docs/Academic_Documentation.docx
```

Export to PDF (requires a TeX engine such as MiKTeX):

```powershell
pandoc -s docs/Academic_Documentation.md -o docs/Academic_Documentation.pdf --pdf-engine=xelatex
```

Export to RTF:

```powershell
pandoc -s docs/Academic_Documentation.md -o docs/Academic_Documentation.rtf
```
