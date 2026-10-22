#!/usr/bin/env bash
set -euo pipefail
flutter create . --platforms=android --org com.arcoanalytics
# O Flutter não inclui INTERNET em release por padrão em alguns templates.
MANIFEST="android/app/src/main/AndroidManifest.xml"
if ! grep -q 'android.permission.INTERNET' "$MANIFEST"; then
  sed -i '/<manifest/a\    <uses-permission android:name="android.permission.INTERNET" />' "$MANIFEST"
fi
flutter pub get
flutter analyze
flutter build apk --release
printf '\nAPK gerado em:\n%s\n' "$(pwd)/build/app/outputs/flutter-apk/app-release.apk"
