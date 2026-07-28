# App

Flutter client for the [backend](../backend) API — targets Windows and macOS desktop plus
Android. (iOS is not a supported target — building/testing it needs a Mac with Xcode, which
isn't available here.) There's no bundled server: this app is always a client, pairing with
a backend instance already running on the admin's Windows PC (see the tray app's "Show
connection QR" menu item, or type the host/port/token shown there manually).

## Development

```
flutter pub get
flutter run -d windows   # or -d macos / a connected phone/emulator
```

On first launch it shows the connect/pairing screen; against a locally running dev backend
(`uv run uvicorn app.main:app --port 8000` in `backend/`, no pairing token required in dev
mode) just enter `localhost` / `8000` and leave the token blank.

### Tests

```
flutter analyze
flutter test                                       # widget tests, mocked HTTP
flutter test integration_test -d windows            # full flow against a REAL backend —
                                                      # start one first, see backend/README.md
```

## Android release signing

`flutter build apk --release`/`--appbundle` sign with `android/app/upload-keystore.jks` if
`android/key.properties` exists (both gitignored — never commit them), falling back to the
debug key otherwise. **A keystore has already been generated on this machine** — back up
`android/app/upload-keystore.jks` and `android/key.properties` somewhere safe (a password
manager, an encrypted drive) before this working copy is deleted. Without that exact
keystore, Android refuses to install a future release build as an update over an existing
install — the app would have to be uninstalled first, losing local state.

To generate a new one elsewhere instead (e.g. on a teammate's machine):

```
keytool -genkey -v -keystore android/app/upload-keystore.jks -keyalg RSA -keysize 2048 \
  -validity 10000 -alias upload
```

Then create `android/key.properties`:

```
storePassword=<password you set above>
keyPassword=<same password — PKCS12 keystores require store and key passwords to match>
keyAlias=upload
storeFile=upload-keystore.jks
```

## Architecture notes

- `lib/api/` — hand-written typed HTTP client + models mirroring `backend/app/schemas/*.py`
  (not OpenAPI-generated: the API surface is small and stable, and generation would need a
  JDK for `openapi-generator-cli`, which felt like the wrong tradeoff for this project).
- `lib/connection/` — the pairing screen and persisted connection info (host/port/token).
- `lib/features/*` — one directory per backend resource (buildings, rooms, tags, roles,
  staff, rules, settings, rosters), each with a list screen and a create/edit form.
- `lib/widgets/async_loader.dart` — shared loading/error/retry plumbing used by every screen.
