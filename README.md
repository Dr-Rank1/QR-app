# QR Vault

QR Vault is a comprehensive Flutter-based application for scanning, generating, and managing QR codes. Designed with privacy and speed in mind, QR Vault provides robust features for both Android and iOS devices, ensuring offline capabilities and an intuitive user experience.

## Key Features

- **Advanced Scanning Capabilities**: Instantly scan QR codes using the device camera or by selecting images from the gallery. Leverages Google ML Kit for fast and accurate barcode scanning.
- **Versatile QR Code Generation**: Generate QR codes for various data types including plain text, URLs, Wi-Fi networks, phone numbers, email addresses, SMS messages, and vCards.
- **Scan History and Management**: Automatically save scan history locally using Hive. Search through past scans and export them as needed.
- **Customizable Themes**: Full support for system, light, and dark modes to match your preferences.
- **Offline First**: All scanning, generation, and history storage operations work entirely offline to guarantee your privacy.
- **Deep Linking Support**: Built-in support for deep links via the `qrvault://` scheme.

## Getting Started

### Prerequisites

- Flutter SDK (version ^3.0.0 or higher)
- Android Studio or Xcode (for iOS development)
- A connected physical device or emulator

### Installation

1. Clone the repository to your local machine:
   ```bash
   git clone https://github.com/Dr-Rank1/QR-app.git
   cd QR-app
   ```

2. Fetch the required dependencies:
   ```bash
   flutter pub get
   ```

3. Generate the required Hive adapters and Riverpod providers:
   ```bash
   dart run build_runner build --delete-conflicting-outputs
   ```

4. Run the application:
   ```bash
   flutter run
   ```

## Development and Testing

To ensure code quality and prevent regressions, run the static analyzer and the test suite:

```bash
flutter analyze
flutter test
```

## Building for Release

### Android

To build a release Android App Bundle (AAB):

```bash
flutter build appbundle
```
The output file will be located at: `build/app/outputs/bundle/release/app-release.aab`

For Windows users, a convenience script is provided:
```bash
scripts/build_release_aab.ps1
```

## Architecture and Technologies

- **Framework**: Flutter
- **State Management**: Riverpod (`flutter_riverpod`)
- **Navigation**: GoRouter (`go_router`)
- **Local Storage**: Hive (`hive`, `hive_flutter`)
- **Scanning**: Mobile Scanner (`mobile_scanner`), Google ML Kit (`google_mlkit_barcode_scanning`)
- **Permissions**: Permission Handler (`permission_handler`)
- **Deep Linking**: App Links (`app_links`)

## License

This project is licensed under the MIT License.
