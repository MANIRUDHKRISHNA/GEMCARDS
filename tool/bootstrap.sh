#!/usr/bin/env bash
set -euo pipefail
flutter create . --platforms=android
flutter pub get
printf '\nBootstrap complete. Run: flutter run\n'
