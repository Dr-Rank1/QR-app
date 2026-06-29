# QR Vault

A production-grade Flutter QR code scanner and generator for Android and iOS. Built with Riverpod, GoRouter, and Hive for offline-first local storage.

## Features

- **Live Scanner** — Real-time QR scanning with animated overlay, torch, and camera flip
- **Gallery Scan** — Decode QR codes from photos in your library
- **Smart Detection** — Auto-detects URL, phone, email, Wi-Fi, SMS, geo, vCard, calendar, and plain text
- **Safe URL Preview** — Confirms domain before opening links; warns on URL shorteners
- **QR Generator** — Create QR codes with presets (URL, Wi-Fi, phone, email, SMS)
- **Scan History** — Search, filter, favorites, swipe-to-delete, and JSON export (up to 50 scans)
- **Settings** — Vibration, sound, keep-screen-on, dark mode, privacy policy
- **Offline First** — All data stored locally with Hive; no account required

## Architecture

```
lib/
├── main.dart
├── app/                    # Router, theme, navigation, shell
├── features/
│   ├── scanner/            # Scanning, results, providers
│   ├── generator/          # QR code creation
│   ├── history/            # Hive repository, history UI
│   ├── settings/           # Preferences
│   └── onboarding/         # First-run flow
└── shared/                   # Ads, widgets, utilities
```

## Tech Stack

| Package | Purpose |
|---------|---------|
| mobile_scanner | Camera + QR scanning |
| flutter_riverpod | State management |
| go_router | Navigation |
| hive_flutter | Local storage |
| google_mobile_ads | Banner + interstitial ads |
| image_picker | Gallery scan |
| wakelock_plus | Keep screen on while scanning |

## Setup

```bash
flutter pub get
dart run build_runner build --delete-conflicting-outputs
flutter run
```

### Android

Camera and photo permissions are requested at runtime. Minimum API 21.

### iOS

Deployment target 14.0+. Camera and photo library usage descriptions are in `Info.plist`.

## Build

```bash
flutter build apk --release
flutter build appbundle --release
flutter build ios --release
```

## Testing

```bash
flutter analyze
flutter test
```

## License

MIT License
