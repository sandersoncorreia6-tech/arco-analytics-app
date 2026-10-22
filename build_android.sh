#!/usr/bin/env bash
# Gera o APK localmente. A pasta android/ já vem configurada
# (permissão INTERNET, applicationId com.arcoanalytics.app, ícone e assinatura).
set -euo pipefail
cd "$(dirname "$0")"
flutter pub get
flutter analyze
flutter test
flutter build apk --release
printf '\nAPK gerado em:\n%s\n' "$(pwd)/build/app/outputs/flutter-apk/app-release.apk"
if [ ! -f android/key.properties ]; then
  echo "Aviso: android/key.properties ausente — APK assinado com chave de teste (debug)."
fi
