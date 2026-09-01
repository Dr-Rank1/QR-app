# QR Vault

Flutter QR scanner and generator for Android and iOS.

## Setup

```bash
flutter pub get
dart run build_runner build --delete-conflicting-outputs
flutter run
```

## Features

- Camera and gallery scanning
- QR generation (text, URL, Wi-Fi, phone, email, SMS, vCard)
- Scan history with search and export
- Dark/light themes
- Offline storage (Hive)
- Deep links: `qrvault://`

## Tests

```bash
flutter analyze
flutter test
```

## Android release

```bash
flutter build appbundle
```

Output: `build/app/outputs/bundle/release/app-release.aab`

Windows: `scripts/build_release_aab.ps1`

## License

MIT
