$ErrorActionPreference = 'Stop'

Write-Host 'Creating Flutter Android scaffolding...'
flutter create . --platforms=android
flutter pub get
Write-Host 'Bootstrap complete. Run: flutter run'
