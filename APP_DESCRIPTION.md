# QR Vault (QR Code Scanner) — Complete Application Reference

**Package name:** `qr_vault`  
**Display name:** QR Code Scanner (Android label) / QR Vault (in-app branding)  
**Version:** 1.1.2+10  
**Application ID:** `com.dr_rank.qrcodescanner`  
**Platforms:** Android, iOS (portrait-only)  
**Distribution model:** Fully local, offline-first utility app — no accounts, no ads, no backend, no analytics SDKs.

---

## 1. Product overview

QR Vault is a Flutter mobile application for scanning, decoding, generating, and managing QR codes. All scan history, settings, generator drafts, and diagnostic crash logs are stored **on-device only** using Hive. The app never requires network connectivity for core features, though optional actions (opening URLs, sharing, web search) may use the system browser or share sheet when the user explicitly chooses them.

### Primary user journeys

1. **Scan** — Point the rear camera at a QR code, or pick an image from the gallery.
2. **Review** — View decoded content on the Scan Result screen with type-specific actions.
3. **History** — Browse, search, filter, favorite, export, or delete past scans.
4. **Generate** — Build QR codes for text, URLs, Wi-Fi, phone, email, SMS, and contacts.
5. **Settings** — Configure feedback, appearance, data management, and diagnostics.

### First launch

A three-page **onboarding** flow runs once (persisted in Hive `settings` box as `onboarding_completed`). After completion, the user lands on the main four-tab shell.

---

## 2. Technology stack

| Layer | Technology | Version / notes |
|-------|------------|-----------------|
| **Language** | Dart | SDK `^3.0.0` |
| **Framework** | Flutter | Material 3 (`useMaterial3: true`) |
| **State management** | flutter_riverpod | `^2.6.1` — `StateNotifier`, `AsyncNotifier`, `Provider` |
| **Navigation** | go_router | `^17.2.2` — declarative routes, redirects, custom transitions |
| **Local database** | hive + hive_flutter | `^2.2.3` — typed boxes, code-generated adapters |
| **Camera / scan** | mobile_scanner | `^7.2.0` — live preview, `analyzeImage` for gallery |
| **Gallery pick** | image_picker | `^1.2.2` |
| **QR rendering** | qr_flutter | `^4.1.0` |
| **Image export** | screenshot | `^3.0.0` — PNG capture for share-as-image |
| **Sharing** | share_plus | `^13.1.0` |
| **URLs** | url_launcher | `^6.2.6` |
| **Permissions** | permission_handler | `^12.0.1` |
| **Deep links** | app_links | `^6.4.0` |
| **Inbound shares** | receive_sharing_intent | `1.8.1` (pinned) |
| **Screen wake** | wakelock_plus | `^1.6.1` |
| **IDs** | uuid | `^4.4.0` |
| **Codegen** | hive_generator, build_runner | Dev — `QRResult` Hive adapter |

### Explicitly removed / not used

- Firebase, Google Mobile Ads, shared_preferences, intl, color pickers, batch/premium modes.
- No `INTERNET` permission on Android (stripped from manifest merge).
- No cloud sync, login, or telemetry pipelines.

---

## 3. Project structure

```
lib/
├── main.dart                          # App entry, Hive init, crash zones, ProviderScope
├── app/
│   ├── router.dart                    # GoRouter routes + onboarding redirect
│   ├── main_shell.dart                # Bottom nav + TabCrossfadeStack
│   ├── navigation_provider.dart       # Selected tab index (Riverpod)
│   ├── theme.dart                     # Material 3 light/dark themes
│   ├── app_spacing.dart               # Uniform 16dp margins, section gaps
│   └── app_info.dart                  # Version constants
├── features/
│   ├── scanner/                       # Live scan, result detail, camera service
│   ├── generator/                       # QR Studio — types, preview, export
│   ├── history/                         # Hive repository, list UI, filters
│   ├── settings/                      # Preferences, diagnostics, privacy
│   └── onboarding/                    # First-run pager
└── shared/
    ├── widgets/                       # Reusable UI (overlay, icons, empty state)
    ├── utils/                           # Parsers, URL safety, haptics, permissions
    ├── security/                      # Sanitization, redaction, secure logging
    └── services/                        # Share, deep links, crash reporter
```

### Architecture pattern

**Feature-first folders** with a thin **shared** layer. Business logic for scanning and generation lives in **domain services** (`CameraScanService`, `QrGenerationService`, `ShareService`, `DeepLinkService`). UI screens are `ConsumerWidget` / `ConsumerStatefulWidget` and delegate to Riverpod notifiers and repositories.

---

## 4. Navigation and routing

### GoRouter routes

| Path | Screen | Notes |
|------|--------|-------|
| `/onboarding` | `OnboardingScreen` | Redirects to `/` when completed |
| `/` | `MainShell` | Four tabs via `IndexedStack`-style crossfade |
| `/result/:id` | `ResultDetailScreen` | Slide-up transition; full-screen over shell |

### Main shell tabs (bottom navigation)

| Index | Label | Screen | Icon style |
|-------|-------|--------|------------|
| 0 | Scanner | `ScannerScreen` | Outlined / filled when selected |
| 1 | Generator | `GeneratorScreen` ("QR Studio") | Outlined / filled |
| 2 | History | `EnhancedHistoryScreen` | Outlined / filled |
| 3 | Settings | `SettingsScreen` | Outlined / filled |

`TabCrossfadeStack` keeps all four tabs **mounted** while cross-fading visibility — tab state (scroll position, form input) is preserved when switching.

---

## 5. User interface and design system

### Design language

- **Material 3** with a purple seed color `#6750A4` (Material You `ColorScheme.fromSeed`).
- **Dark-first aesthetic** — default onboarding encourages dark usage; user can toggle Dark Mode in Settings.
- **Surface hierarchy** — cards use `surfaceContainerLow` / `surfaceContainerHigh` on the scaffold background instead of harsh borders.
- **Uniform horizontal margins** — `AppSpacing.screenHorizontal` = **16dp** on all primary screens.
- **Outlined iconography** — `AppIcons` centralizes stroke-style icons; active bottom-nav tabs use filled variants.

### Typography

Defined in `AppTheme` via `TextTheme`:

- **Titles** — `titleLarge` / `titleSmall`, weight 600–700.
- **Body** — elevated line heights (`bodyLarge` 1.45, `bodyMedium` 1.4) for readability in history and forms.
- **Settings section headers** — uppercase `labelLarge`, letter-spacing 1.1, primary color.

### Interaction patterns

- **InkRipple** splash factory globally; soft primary-tinted overlays on buttons and icon buttons.
- **`SoftRipple` widget** — reusable `InkWell` wrapper for chips and action sheet rows.
- **Haptics** — `AppHaptics` on successful scan validation, copy, and history long-press.
- **Scan feedback** — optional vibration and sound on successful decode (`ScanFeedback` + settings).

### Screen-by-screen UI summary

#### Scanner (`ScannerScreen`)

- Full-bleed camera preview with immersive transparent `AppBar`.
- **Scan overlay** (`ScanOverlay`) — rounded reticle (32dp corners), animated scan line, bracket-close + pulse glow on detection.
- Toolbar pill: **Gallery** and **Flash** only (camera flip removed).
- Gallery scan uses the live `MobileScannerController.analyzeImage()` with QR format filter.
- Permission-denied state still offers **Scan from gallery**.

#### Scan Result (`ResultDetailScreen`)

- Close (X) returns to Scanner tab.
- Elevated **payload card** with type icon, scrollable content, scan timestamp.
- URLs: **bold root domain** in payload text; suspicious shortener warning card.
- **Primary CTA** by type (Open Link, Connect to Wi-Fi, Call, etc.).
- Secondary row: Copy, Share, Web Search (URLs).

#### Generator / QR Studio (`GeneratorScreen`)

- Centered white QR preview card with drop shadow and inner padding.
- **Circular icon type selector** (horizontal scroll) — Text, Link, Wi-Fi, Phone, Email, SMS, Contact.
- Details form with soft filled inputs and clear (X) suffix icons.
- **Advanced options** accordion — size slider, embed logo, rounded modules.
- Copy + Share data (outlined, side-by-side) when valid; **Share as image** full-width primary.

#### History (`EnhancedHistoryScreen`)

- Stats banner (total, today, favorites, top type).
- Search field matching generator input styling; clear icon when typing.
- Horizontally scrolling filter chips with right-edge gradient fade.
- List items as flat cards: type icon, bold snippet, subtle timestamp.
- Long-press → bottom sheet (Copy, Share, Delete); swipe-to-delete; export/delete-all in app bar.

#### Settings (`SettingsScreen`)

- Grouped cards: **SCANNING**, **APPEARANCE**, **DATA**, **DIAGNOSTICS**, **ABOUT**.
- Full-row tappable switches with leading icons.
- **Clear Scan History** in semantic red with bottom-sheet confirmation.
- Crash log export/clear for closed testing (local Hive only).
- Embedded privacy policy (`assets/privacy_policy.txt`).

#### Onboarding (`OnboardingScreen`)

- Three-page `PageView`: Scan Anything, Smart Actions, Full History.
- Completes → `onboarding_completed` in Hive.

---

## 6. Data model and local storage

### Hive boxes

| Box name | Content | Adapter |
|----------|---------|---------|
| `settings` | User prefs, onboarding flag, generator draft keys | Primitive maps |
| `scan_history` | `QRResult` entities | `QRResultAdapter` (typeId 0) |
| `crash_logs` | `CrashLogEntry` maps | Manual serialization |

### `QRResult` model

- `id` (UUID), `rawValue`, `typeIndex`, `scannedAt`, optional `displayValue`, `metadata`, `isFavorite`.
- Types: URL, phone, email, Wi-Fi, text, SMS, geo, vCard, calendar.

### History limits

- **Maximum 50 scans** — oldest trimmed on insert (`ScanHistoryRepository._maxItems`).
- Pagination constant `_pageSize = 20` for repository API (UI loads all via provider).

### Generator persistence

- `generatorType` and `generatorFields` stored in `settings` box across sessions.

### Settings keys

- `darkMode`, `vibrateOnScan`, `soundOnScan`, `keepScreenOn`, `themeMode`, `onboarding_completed`.

---

## 7. Scanning pipeline

1. **Camera** or **gallery** produces a raw string.
2. **`PayloadSanitizer.sanitizeRaw`** — blocks `javascript:`, `data:`, script patterns, control chars; max 4096 chars.
3. **`QRContentParser.parse`** — detects type and metadata (Wi-Fi credentials, vCard fields, etc.).
4. **`ScannerStateNotifier.processBarcode`** — builds `QRResult`, redacts metadata for storage, saves to Hive, triggers haptic/sound.
5. **Navigation** to `/result/:id`.

### Gallery scan implementation

Uses the **active** `MobileScannerController.analyzeImage(path, formats: [BarcodeFormat.qrCode])`. Falls back to a dedicated `autoStart: false` analyzer if needed. Separate `_processScan` path avoids camera debounce conflicts.

### URL safety

- `UrlSafety.confirmOpen` dialog before launching browsers.
- Flags known shortener domains.
- `PayloadSanitizer.sanitizeUrl` blocks dangerous schemes.

### Wi-Fi / sensitive data

- `SensitiveMetadata` redacts passwords in display and crash logs.
- Wi-Fi passwords never logged via `SecureLogger`.

---

## 8. QR generation pipeline

1. User selects `GeneratorContentType` and fills fields.
2. **`QRPayloadBuilder`** validates and builds payload string (vCard, WIFI:, mailto:, etc.).
3. **`GeneratorState`** exposes `payload`, `isValid`, `fieldErrors`.
4. **`QrGenerationService`** renders preview via `qr_flutter` and PNG export via `Screenshot` widget capture.
5. **`QrRenderOptions`** — size, embedded logo (`assets/app_icon.png`), square vs rounded modules.

---

## 9. Security and privacy

| Concern | Implementation |
|---------|----------------|
| Malicious URLs | Scheme blocklist, confirm-before-open dialog |
| Script injection | Raw payload pattern checks |
| Secrets in logs | `SecureLogger`, `SensitiveMetadata` redaction |
| Network | No INTERNET permission; no background uploads |
| Crash data | Local Hive only; user can export/delete in Settings |
| Android backup | Local data stays on device by default |

---

## 10. Deep linking and inbound intents

### Custom URI scheme: `qrvault://`

| Host | Action |
|------|--------|
| `scan` | Open scanner or process `?data=` payload |
| `generate` | Pre-fill generator with `?data=` |
| `open` | Alias with `?url=` |

### HTTPS (optional): `https://scan.qrvault.app/...`

### Android intent filters

- `SEND` `text/plain` — share text into app via `receive_sharing_intent`.
- App links for HTTPS host (autoVerify).

`DeepLinkListener` wraps `MaterialApp` and routes inbound actions to scanner/generator tabs.

---

## 11. Services reference

| Service | Responsibility |
|---------|----------------|
| `CameraScanService` | Controller lifecycle, torch, `analyzeImageFromPath` |
| `QrGenerationService` | Off-tree QR PNG rendering |
| `ShareService` | Text and image sharing |
| `DeepLinkService` | URI parsing |
| `CrashReporter` | Zone + FlutterError capture, max 50 entries |
| `OnboardingStorage` | First-run flag |

Registered in `service_providers.dart` for Riverpod injection.

---

## 12. Permissions

| Permission | Purpose |
|------------|---------|
| `CAMERA` | Live QR scanning |
| `VIBRATE` | Optional scan haptic |
| Photo library | Via image_picker (system picker; no broad storage read on Android 13+) |

`AppPermissionHandler` wraps `permission_handler` for camera checks.

---

## 13. Assets

| File | Use |
|------|-----|
| `assets/app_icon.png` | Launcher icon source |
| `assets/app_icon_foreground.png` | Adaptive icon foreground |
| `assets/splash_logo.png` | Native splash (dark `#121212` background) |
| `assets/privacy_policy.txt` | In-app privacy dialog |

Splash configuration lives in **`pubspec.yaml`** under `flutter_native_splash:` (regenerate via `dart run flutter_native_splash:create`).

---

## 14. Build and release

### Android

- `compileSdk` / `targetSdk` **36**, `minSdk` from Flutter default.
- Release: ProGuard minify + shrink; `ndk.debugSymbolLevel = SYMBOL_TABLE` for Windows CI compatibility.
- Signing via `android/key.properties` (not committed).
- Scripts: `scripts/build_release_aab.ps1`, `scripts/build_release_aab.sh`.

### iOS

- Deployment target 14.0+ (standard Flutter iOS project).
- URL scheme `qrvault` in `Info.plist`.

### CI (`.github/workflows/ci.yml`)

- `flutter analyze` + `flutter test` on Ubuntu.
- Release AAB artifact build on success.

---

## 15. Testing

Unit/widget tests in `test/`:

- `payload_sanitizer_test.dart` — security rules
- `qr_parser_test.dart` — type detection
- `qr_payload_builder_test.dart` — generator payloads
- `camera_scan_service_test.dart` — torch/switch planning logic
- `scanner_camera_toggle_widget_test.dart` — torch UI rules

Run: `flutter test`

---

## 16. Key dependencies graph (conceptual)

```
main.dart
  └── QRScannerApp (Riverpod)
        ├── GoRouter (onboarding → MainShell → ResultDetail)
        └── DeepLinkListener
              └── MainShell
                    ├── ScannerScreen → CameraScanService → mobile_scanner
                    │       └── scannerProvider → ScanHistoryRepository
                    ├── GeneratorScreen → generatorProvider → QRPayloadBuilder
                    ├── EnhancedHistoryScreen → scanHistoryProvider
                    └── SettingsScreen → settingsProvider
```

---

## 17. Localization and language

- **UI language:** English only (all strings are inline in Dart widgets — no `flutter_localizations` or ARB files).
- **Content encoding:** UTF-8 throughout; URL and mailto builders use `Uri.encodeComponent` where required.
- **Date formatting:** Relative times in history ("5m ago"); absolute timestamps on result cards.

---

## 18. Known design decisions

1. **Rear camera only** — front-camera switch removed to avoid device-specific preview bugs.
2. **50-scan cap** — keeps Hive footprint small on low-end devices.
3. **No internet permission** — reinforces offline-first trust model; external opens use system handlers.
4. **Pinned `receive_sharing_intent` 1.8.1** — avoids Gradle/Kotlin breakage in 1.9.x on current toolchain.
5. **Premium/ads/batch removed** — settings and UI are utility-only.

---

## 19. File index (lib/)

| Path | Description |
|------|-------------|
| `main.dart` | Entry point, Hive, crash handling |
| `app/router.dart` | Routes and transitions |
| `app/main_shell.dart` | Bottom navigation shell |
| `app/theme.dart` | Theming |
| `features/scanner/presentation/screens/scanner_screen.dart` | Camera UI |
| `features/scanner/presentation/screens/result_detail_screen.dart` | Result UI |
| `features/scanner/domain/services/camera_scan_service.dart` | Camera/gallery analysis |
| `features/generator/presentation/screens/generator_screen.dart` | QR Studio |
| `features/history/presentation/screens/enhanced_history_screen.dart` | History UI |
| `features/settings/presentation/screens/settings_screen.dart` | Settings UI |
| `shared/widgets/scan_overlay.dart` | Scanner reticle animation |
| `shared/widgets/app_icons.dart` | Icon constants + SoftRipple |
| `shared/security/payload_sanitizer.dart` | Input sanitization |
| `shared/utils/qr_parser.dart` | Decode + open actions |

---

*This document describes the codebase as of version **1.1.2+10**. For quick setup commands, see `README.md`.*
