$ErrorActionPreference = "Stop"

$Root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
Set-Location $Root

Write-Host "Fetching dependencies..."
flutter pub get

Write-Host "Running analyzer and tests..."
flutter analyze
flutter test

Write-Host "Building release Android App Bundle..."
flutter build appbundle --release

$Output = Join-Path $Root "build\app\outputs\bundle\release\app-release.aab"
if (Test-Path $Output) {
  Write-Host "AAB ready: $Output"
} else {
  Write-Error "AAB build finished but output file was not found at $Output"
}
