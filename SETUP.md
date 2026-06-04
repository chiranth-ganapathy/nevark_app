# NeVark — local setup

## Prerequisites

- Flutter SDK 3.11+ (`flutter doctor`)
- Android Studio / device or emulator (recommended for live Angel One data)
- Firebase project (Auth) with `google-services.json` in `android/app/`

## 1. Install dependencies

```bash
flutter pub get
```

## 2. Angel One credentials (required for live market data)

```bash
copy lib\core\config\angel_one_config.example.dart lib\core\config\angel_one_config.dart
```

Edit `lib/core/config/angel_one_config.dart` with your API key, client code, MPIN, and TOTP secret.

This file is **gitignored** — never commit it.

## 3. News API (optional)

Default Marketaux key is embedded for dev. For production, use:

```bash
flutter run --dart-define=MARKETAUX_API_KEY=your_key
```

## 4. Firebase

- Add `android/app/google-services.json` from Firebase Console (gitignored).
- Ensure `lib/firebase_options.dart` matches your Firebase app (run `flutterfire configure` if needed).

## 5. Run the app

```bash
flutter run
```

Use a **physical Android device** or emulator with internet. Web has CORS limits for Angel One.

## 6. If credentials were ever pushed to GitHub

Rotate Angel One API / TOTP and Marketaux keys, then remove secrets from git history:

```bash
git rm --cached lib/core/config/angel_one_config.dart
git rm --cached android/app/google-services.json
```

Commit the removal and rotate keys in the provider dashboards.

## Optional backend

`nevark_backend/` is a separate Python API. The Flutter app does not require it for the main flow. To run it locally:

```bash
cd nevark_backend
python -m venv venv
venv\Scripts\activate
pip install -r requirements.txt
```

Do not commit `venv/` folders (already in `.gitignore`).
