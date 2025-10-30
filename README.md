# dgHabit

Build habits, day by day — log activities, visualize trends, and grow.

## Overview

- Flutter (Material 3), Riverpod, Firebase (Auth/Firestore)
- Daily timeline with continuity handling (no-gap/overlap strategies)
- Bottom-sheet UI for Add/Edit Activity, Settings, Permissions, and Category Manager
- Analytics with weekly trends and category breakdowns

## Screenshots

Composite: `docs/screenshots/all_screens.png`

Key screens (see more under `docs/screenshots/individual/`):

![Home](docs/screenshots/individual/home.png)
![Timeline](docs/screenshots/individual/timeline.png)
![Analytics](docs/screenshots/individual/analytics.png)
![Add Activity (Sheet)](docs/screenshots/individual/sheet_add_activity.png)
![Activity Detail (Sheet)](docs/screenshots/individual/sheet_activity_detail.png)
![Settings (Sheet)](docs/screenshots/individual/sheet_settings.png)
![Category Manager (Sheet)](docs/screenshots/individual/sheet_category_manager.png)
![Permissions (Sheet)](docs/screenshots/individual/sheet_permissions.png)
![Quick Actions (Sheet)](docs/screenshots/individual/sheet_quick_actions.png)

## Development

1) Install Flutter and set up platforms.
2) Configure Firebase (google-services.json / GoogleService-Info.plist).
3) Run:

```powershell
flutter pub get
flutter run
```

## Generate documentation screenshots

```powershell
flutter test --update-goldens test/screenshots/golden_screens_test.dart
```

Outputs are written to `docs/screenshots/` and `docs/screenshots/individual/`.

## License

MIT (update if different)
