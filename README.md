# Warranty Vault — offline Flutter starter

A portfolio project for Windows and Android, with iOS source scaffolding. No accounts, cloud storage, API keys or paid services. Use a current stable Flutter SDK (Dart 3.10 or newer). Native toolchains and dependencies must be downloaded initially. The Flutter runtime/build was not available in the authoring environment, so the project has not been compiled or run here. The tests are included for your local validation.

## Windows setup (VS Code)

1. Install Flutter: https://docs.flutter.dev/install — add its bin directory to PATH. Install the Flutter VS Code extension.
2. Install Visual Studio Community (not VS Code) and its **Desktop development with C++** workload, including the Windows SDK and CMake tools. https://docs.flutter.dev/platform-integration/windows/setup
3. Open the extracted starter folder in VS Code. Run `flutter doctor -v` and `flutter devices` in its terminal. Fix Windows toolchain errors.
4. In the extracted folder, run `powershell -NoProfile -ExecutionPolicy Bypass -File .\setup.ps1`. This creates a new sibling folder `warranty_vault` and copies all source files. It will not overwrite an existing folder. `-Destination C:\Projects\warranty_vault` is optional. The execution-policy override is scoped to this process; inspect the script first if desired.
5. Open the generated `warranty_vault` folder in VS Code. Run:

```powershell
flutter pub get
flutter analyze
flutter test
flutter run -d windows
```

Use `dart format lib test` to format source. For a release build: `flutter build windows`. Windows release output includes required DLLs; distribute the full release folder, not just the EXE.

If you prefer manual setup: `flutter create --platforms=windows,android,ios --project-name warranty_vault --no-pub warranty_vault`, copy the starter `lib`, `test`, `examples`, `pubspec.yaml` and README into it (delete generated `test/widget_test.dart`). Follow the mobile configuration below.

## First test

- Add warranty > Upload files > `examples/sample-warranty.pdf`. This is a synthetic sample, not a valid warranty.
- Expected extracted product: Sample Bluetooth Speaker; seller: Example Electronics; serial: DEMO-SN-123456; start 2026-11-12; expiry 2028-11-12. Confirm and save.
- Open the entry, view the PDF, copy a serial number, export a calendar reminder. Close the application and run again; the record and PDF should remain available.
- Add a manual warranty with a past expiration and switch to Expired. Change it to a future date and verify it reappears in Active. Use the dashboard menu to export a `.wvb` backup, then import it (adds copies). Delete a test record only after making a backup.
- Test date and persistence behavior with `flutter test`.

## Android

Install Android Studio, its SDK, platform tools and an emulator (or use your Android phone with USB debugging). Run `flutter doctor --android-licenses`, `flutter doctor -v`, `flutter devices`, then `flutter run -d <device-id>`. Android needs compile SDK 35 or higher; use the current Flutter-generated Gradle configuration. Set minSdk to at least 21 if necessary (modern Flutter generally already does). The setup script disables Android OS backup via manifest attributes, for a local-only prototype; device migration behavior can still vary by OS/vendor. Mobile capture uses the native camera app and local ML Kit Latin text recognition. No camera permission prompt is required on Android for the external camera intent. Try taking a photo of the sample certificate, or upload a JPG/PNG. Camera edge detection, deskew and Cyrillic photo recognition are not included yet. Android may destroy the app during capture; this prototype does not recover the pending editor from a killed process.

## iOS

Building or testing requires macOS, Xcode, iOS 15.5 or later and CocoaPods. The app scaffolding is generated, but iOS has not been validated. Set Runner's iOS deployment target (Xcode and Podfile, if present) to 15.5 or above; follow the pinned ML Kit plugin's iOS instructions, including excluding armv7 if required. The script adds camera/photo usage descriptions. For manual setup, add NSCameraUsageDescription and NSPhotoLibraryUsageDescription in ios/Runner/Info.plist. Native OS backup/iCloud settings may include application data; this app has no cloud sync service, but does not disable iOS device backups. iOS may produce HEIC images; use JPG/PNG files or convert if rejected. https://docs.flutter.dev/platform-integration/ios/setup

## Offline recognition

- Digital PDFs: local PDFium text extraction via pdfrx (first 30 pages), English and Bulgarian text if embedded correctly. The original PDF is retained unmodified. Scanned/image-only PDFs are stored and viewable but not OCR-processed in this version.
- Photos: Android/iOS Latin OCR through ML Kit; Cyrillic is not reliably supported. On Windows, optional Tesseract (`tesseract` on PATH) with both `eng` and `bul` trained data. See https://tesseract-ocr.github.io/tessdoc/Installation.html. Verify `tesseract --list-langs` includes both. If absent, uploads still work; manually fill in the details.
- Field extraction uses conservative label-based rules, not AI. Documents without the supported labels or with multiple products need manual entry. Review every extracted field. Dates use ISO or day-month-year, and a warranty's actual start/expiration may differ from the purchase date. Only blank fields are populated when adding documents. The date calculator is explicit; change expiration manually or recalculate after editing start/duration. A receipt and a warranty can be attached to the same record; create separate records for separate products.

## Storage and portability

The dashboard menu shows the application support directory from `path_provider`. Each record is a JSON file and each document has a unique local filename. Writes use a temporary record file and rename. All uploaded documents are copied on save; original source files can be removed without affecting the saved copy. No database server. No app-level encryption or password lock in this prototype; rely on OS account and device encryption. Backups are plaintext JSON containing base64 documents, not encrypted; do not commit or upload private backups. Export/import `.wvb` transfers records manually; import creates new IDs and duplicates if repeated. Files up to 25 MB, backup up to 100 MB. Deleting a record is permanent after confirmation. No trash/undo yet. Existing attachments cannot be removed individually; export or delete/recreate the record if needed. Cloud sync and automatic backups are intentionally absent. OS backups may behave differently by platform. App uninstall, OS reinstall, drive failure and data-clearing can cause loss.

## Calendar

Export an all-day `.ics` event for 30, 7, 1 or 0 days before the expiry, then open/import it in your calendar and enable notifications there. No native background notifications, calendar permission, auto-update or calendar API yet. Re-export after changing expiry; remove old events manually. An expiry date is treated as active through that calendar date; confirm actual contract deadlines with your seller.

## GitHub

In the generated project folder, create an empty repository on GitHub and run `git init`, `git add .`, `git commit -m "Build offline warranty vault"`, `git branch -M main`, `git remote add origin <your repository URL>`, `git push -u origin main`. Flutter generates a .gitignore; commit source, not real receipts, personal backups, local data, or signing keys. Commit pubspec.lock after resolving dependencies. Do not publish real warranty documents in examples.
