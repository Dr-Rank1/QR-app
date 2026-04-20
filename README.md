# QR Code Scanner

A production-grade Flutter QR code scanner app targeting both Android and iOS. Built with clean architecture, Riverpod state management, and GoRouter navigation.

## Features

- **Scanner Screen**: Real-time QR code scanning with animated scan overlay
- **Flashlight Toggle**: Turn on/off flashlight for low-light scanning
- **Camera Switch**: Switch between front and rear cameras
- **Smart Detection**: Auto-detect and handle QR result types:
  - URL → Open in browser with confirmation dialog
  - Phone number → Launch dialer
  - Email → Launch email client
  - Wi-Fi credentials → Show connect dialog
  - Plain text → Copy to clipboard
- **Scan History**: Last 50 scans stored locally using Hive
- **Result Detail**: View, share, copy, and open scan results
- **Settings**: Vibration, sound, keep screen on, theme options

## Architecture

```
lib/
├── main.dart                 # App entry point
├── app/
│   ├── router.dart         # GoRouter configuration
│   └── theme.dart        # Material 3 theming
├── features/
│   ├── scanner/
│   │   ├── domain/      # Models and enums
│   │   └── presentation/ # Screens, widgets, providers
│   ├── history/
│   │   ├── data/     # Hive repository
│   │   └── presentation/
│   └── settings/
│       └── presentation/
└── shared/
    ├── widgets/        # Reusable widgets
    └── utils/         # Utilities
```

## Tech Stack

- **Framework**: Flutter 3.x
- **State Management**: Riverpod (StateNotifier + AsyncNotifier)
- **Navigation**: GoRouter
- **Camera**: mobile_scanner
- **Storage**: Hive Flutter
- **Permissions**: permission_handler

## Setup

### Prerequisites

- Flutter SDK 3.x or higher
- Dart SDK 3.x or higher

### Installation

1. Clone the repository
2. Install dependencies:

```bash
flutter pub get
```

### Android Setup

The app is configured to work on Android API 21+ (Lollipop).

Camera permission is automatically requested at runtime using `permission_handler`.

No additional setup required - the app handles permissions gracefully.

### iOS Setup

1. Update the iOS deployment target:

```bash
# In ios/Podfile
platform :ios, '14.0'
```

2. The camera permission description is already added to `Info.plist`:

```xml
<key>NSCameraUsageDescription</key>
<string>This app requires camera access to scan QR codes.</string>
```

### Running the App

```bash
# Run on Android
flutter run -d android

# Run on iOS simulator
flutter run -d ios

# Run on connected device
flutter run
```

## Building for Release

### Android

```bash
flutter build apk --release
```

Output: `build/app/outputs/flutter-apk/app-release.apk`

### iOS

```bash
flutter build ios --release
```

Note: iOS release builds require Apple Developer membership and proper code signing.

## Project Structure

| Directory | Description |
|-----------|-------------|
| `lib/app/` | App-level configuration (router, theme) |
| `lib/features/scanner/` | Scanner feature (scanning, result handling) |
| `lib/features/history/` | History feature (Hive storage, list view) |
| `lib/features/settings/` | Settings feature (preferences) |
| `lib/shared/` | Shared widgets and utilities |

## Dependencies

| Package | Version | Purpose |
|---------|---------|---------|
| mobile_scanner | ^5.0.0 | Camera + QR scanning |
| flutter_riverpod | ^2.5.1 | State management |
| go_router | ^13.2.0 | Navigation |
| permission_handler | ^11.3.1 | Runtime permissions |
| hive_flutter | ^1.1.0 | Local storage |
| share_plus | ^8.0.3 | Share functionality |
| url_launcher | ^6.2.6 | Open URLs |

## License

MIT License