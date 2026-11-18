# BIG DUCK — Encrypted Telegram Cloud Vault

Client-side AES-256-GCM + Argon2id encrypted cloud storage backed by your Telegram account and a bundled Rust core (`teledrive-core` + `teledrive-mobile-bridge`).

## Repository Layout

- `lib/` — Flutter UI (`Signal Vault` design system, bilingual Arabic/English + RTL, biometric lock, local media/PDF preview, owned/admin storage group selector)
- `rust/` — Self-contained Rust workspace (`core/` + `mobile-bridge/`) compiled into Android `.so` libraries and iOS static libraries
- `scripts/` — Cross-platform native build helpers (`build_android_rust.ps1`, `build_android_rust.sh`, `build_ios_rust.sh`)
- `.github/workflows/build-mobile.yml` — GitHub Actions CI that builds both **Android APK** and **iOS IPA**

---

## Push to GitHub & Build APK + IPA Automatically

1. Create a new repository on GitHub (empty, without README).
2. From `d:\BIG DUCK\big_duck`, stage and push:

```powershell
git add .
git commit -m "Initial BIG DUCK mobile release"
git remote add origin https://github.com/Ubb-a/big-duck-flutter.git
git push -u origin main
```

3. Open the **Actions** tab on GitHub (`https://github.com/Ubb-a/big-duck-flutter/actions`) -> workflow **Build Android APK & iOS IPA**:
   - It runs automatically on every push to `main`, or click **Run workflow** manually.
   - Download **`BIG-DUCK-android-apk`** (`BIG-DUCK-android.apk`) for Android.
   - Download **`BIG-DUCK-ios-ipa`** (`BIG-DUCK-ios.ipa`) for iPhone/iPad, then sideload it using **Sideloadly**, **AltStore**, or **SideStore**.
4. To publish a permanent **GitHub Release** with both `.apk` and `.ipa` attached:

```powershell
git tag v1.0.0
git push origin v1.0.0
```

---

## Local Builds

### Android (Windows / Linux / macOS)

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\build_android_rust.ps1
flutter pub get
flutter build apk --release
```

### iOS (macOS + Xcode)

```bash
chmod +x ./scripts/build_ios_rust.sh
./scripts/build_ios_rust.sh --device-only
flutter pub get
flutter build ios --release --no-codesign
```
