# QR Vault

A local-first Flutter QR scanner and generator for Android and iOS.

**Full technical documentation:** see [APP_DESCRIPTION.md](APP_DESCRIPTION.md) for architecture, UI, data model, security, and build details.

## Quick start

```bash
flutter pub get
dart run build_runner build --delete-conflicting-outputs
flutter run
```

## Features

- Live camera + gallery QR scanning
- QR generation (text, URL, Wi-Fi, phone, email, SMS, contact)
- Local scan history (50 items max), search, filters, export
- Dark Material 3 UI, no ads, no account required
- Fully offline storage via Hive

## Test & analyze

```bash
flutter analyze
flutter test
```

## License

MIT License
