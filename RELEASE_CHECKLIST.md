# QR Vault Release Checklist

## Pre-Release Setup

- [ ] Update app name to "QR Vault" in AndroidManifest.xml and Info.plist
- [ ] Set bundle ID: `com.yourname.qrvault`
- [ ] Update version in pubspec.yaml: `1.0.0+1`
- [ ] Add app icons (1024x1024 PNG)
- [ ] Run splash screen generator: `dart run flutter_native_splash:create`
- [ ] Run icon generator: `dart run flutter_launcher_icons`

## Android Release

- [ ] Create keystore for signing:
  ```bash
  keytool -genkey -v -keystore android/app/key.jks -keyalg RSA -keysize 2048 -validity 10000 -alias key
  ```

- [ ] Configure `android/key.properties`:
  ```
  storePassword=your_password
  keyPassword=your_password
  keyAlias=key
  storeFile=key.jks
  ```

- [ ] Update `android/app/build.gradle`:
  - Set `minSdkVersion = 21`
  - Set `targetSdkVersion = 34`
  - Set `compileSdkVersion = 34`
  - Enable `minifyEnabled true`
  - Enable `shrinkResources true`

- [ ] Build Android App Bundle:
  ```bash
  flutter build appbundle --release
  ```

- [ ] Output: `build/app/outputs/bundle/release/app-release.aab`

## iOS Release

- [ ] Set `IPHONEOS_DEPLOYMENT_TARGET = 14.0` in Xcode
- [ ] Verify `NSCameraUsageDescription` in Info.plist
- [ ] Add Privacy manifest: `ios/Runner/PrivacyInfo.xcprivacy`
- [ ] Configure signing in Xcode (manual or automatic)
- [ ] Create archive: Product > Archive

- [ ] Build iOS App:
  ```bash
  flutter build ipa --release
  ```

- [ ] Output: `build/ios/ipa/*.ipa`

## App Store Assets

### Android Play Store
- [ ] 1080x1920 screenshots (phone)
- [ ] 1242x2688 screenshots (optional)
- [ ] 1024x500 feature graphic
- [ ] Short description (80 chars): "Scan, decode & save QR codes — fast, private, offline."
- [ ] Full description (4000 chars max)

### iOS App Store
- [ ] 1290x2796 screenshots (iPhone)
- [ ] 2048x2732 screenshots (iPad optional)
- [ ] App preview video (optional)
- [ ] Description and keywords

## Privacy & Compliance

- [ ] Privacy policy URL posted
- [ ] Privacy manifest for iOS 17+
- [ ] Check ad SDK compliance (AdMob, RevenueCat)
- [ ] Verify camera permission usage description

## Testing

- [ ] Test on Android 14 (API 34)
- [ ] Test on Android 9 (API 28)
- [ ] Test on iOS 17
- [ ] Test on iOS 15
- [ ] Verify offline functionality

## Submission

- [ ] Create Google Play Console account
- [ ] Create Apple Developer account
- [ ] Upload Android App Bundle
- [ ] Upload iOS build via Transporter
- [ ] Complete store listing forms
- [ ] Submit for review

## Post-Release

- [ ] Monitor crash reports
- [ ] Monitor review ratings
- [ ] Push updates as needed
