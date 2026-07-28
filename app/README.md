# App

Flutter client for the [backend](../backend) API — targets Windows and macOS desktop plus
iOS and Android. There's no bundled server: this app is always a client, pairing with a
backend instance already running on the admin's Windows PC (see the tray app's "Show
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

## Architecture notes

- `lib/api/` — hand-written typed HTTP client + models mirroring `backend/app/schemas/*.py`
  (not OpenAPI-generated: the API surface is small and stable, and generation would need a
  JDK for `openapi-generator-cli`, which felt like the wrong tradeoff for this project).
- `lib/connection/` — the pairing screen and persisted connection info (host/port/token).
- `lib/features/*` — one directory per backend resource (buildings, rooms, tags, roles,
  staff, rules, settings, rosters), each with a list screen and a create/edit form.
- `lib/widgets/async_loader.dart` — shared loading/error/retry plumbing used by every screen.
