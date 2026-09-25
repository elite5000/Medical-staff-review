# Medical Staff Review

A fortnightly roster builder for a multi-building medical practice. Staff are assigned to
rooms for shifts, subject to role rules, so every room is covered by a qualified person
during opening hours. See [CONTEXT.md](CONTEXT.md) for the domain language (Role, Tag,
Rule, Shift, Roster, etc.) used throughout this README and the codebase.

## How it fits together

- **[`backend/`](backend)** — FastAPI + SQLAlchemy + OR-Tools API. Runs on one Windows PC on
  the practice's LAN (the admin's machine) and owns the database.
- **[`app/`](app)** — Flutter client (Windows, macOS, Android) that pairs with that backend
  over HTTP. There's no bundled server — the app is always a client.

For day-to-day use, the backend runs unattended as a Windows tray app (auto-starts at
login, no terminal), and the Flutter app is what staff/admins actually open. The sections
below cover: setting up a dev environment, building the installers you hand to an admin,
and using the finished app.

## Installing a development environment

### Prerequisites

- [uv](https://docs.astral.sh/uv/) (Python package/dependency manager) for the backend
- [Flutter](https://flutter.dev/setup/) (stable channel) for the app — `flutter doctor`
  should show Windows desktop (or macOS) and Android toolchains as ready for whichever
  targets you intend to run

### Backend

```
cd backend
uv sync
uv run alembic upgrade head
uv run uvicorn app.main:app --port 8000
```

Serves `http://localhost:8000` against a local SQLite file (`dev.db`, gitignored). In this
mode there's no pairing-token check — that only activates in the packaged desktop build.
Tests: `uv run pytest`. Lint/types: `uv run ruff check .` and `uv run mypy app tests`.

### App

```
cd app
flutter pub get
flutter run -d windows   # or -d macos / a connected phone/emulator
```

On first launch it shows the connect/pairing screen — against the dev backend above, enter
`localhost` / `8000` and leave the pairing token blank. Tests: `flutter analyze` and
`flutter test` (widget tests, mocked HTTP); `flutter test integration_test -d windows` runs
the full flow against a real backend you've started yourself.

Full details (including Android release-signing setup) are in
[`app/README.md`](app/README.md) and [`backend/README.md`](backend/README.md).

## Building the installers

### Windows installer (backend + desktop client, one file)

This is what you hand to the practice's admin — it installs the backend as an auto-starting
tray app plus the Windows desktop client, in one setup file. From the repo root:

```
cd backend && uv run pyinstaller packaging/tray.spec
cd ../app && flutter build windows --release
```

Then, on a machine with [Inno Setup](https://jrsoftware.org/isinfo.php) installed, from
`backend/`:

```
iscc packaging/installer.iss
```

Produces `backend/packaging/dist_installer/MedicalStaffReviewSetup.exe`. Expect two normal
one-time prompts on first run: a Windows Defender Firewall "allow this app" prompt (the
backend binds a port) and a SmartScreen warning (the installer is unsigned) — both expected,
see [`backend/packaging/README.md`](backend/packaging/README.md) for details and the
PyInstaller/OR-Tools gotchas already solved there.

### Android client

```
cd app
flutter build apk --release        # or: flutter build appbundle --release
```

Signs with `android/app/upload-keystore.jks` if `android/key.properties` exists (both
gitignored), falling back to the debug key otherwise. **A release keystore has already been
generated on the original dev machine** — see [`app/README.md`](app/README.md#android-release-signing)
for why losing it matters (it blocks installing future releases as updates) and how to
generate a new one if needed.

### macOS / iOS

macOS is a supported client target (`flutter build macos --release`); iOS is not (needs a
Mac with Xcode, not available in this project's dev setup).

## Using the app

### 1. First run, on the admin's Windows PC

Run the installer above (or an already-built one) once. The backend starts automatically at
every login from then on — no terminal, just a tray icon. Right-click it for:

- **Show connection QR** — the host, port, pairing token and certificate fingerprint another
  device needs to pair, as a QR code
- **Open data folder** — where the database lives
- **Quit**

### 2. Pairing a device (phone, tablet, or the desktop client itself)

Open the app. On first launch it shows a connect screen — either **Scan QR code** (point it
at the tray app's "Show connection QR" window) or enter the host/IP, port, pairing token and
certificate fingerprint manually. Once paired, the connection is remembered; use
**Settings → Disconnect** to pair a different backend or re-pair after a token change.

### 3. Set up your data

Do this once per practice, then maintain it as staff/rooms change. The app's left-hand nav
(or bottom nav on phone-width screens) has one section per resource — set them up roughly in
this order, since later ones reference earlier ones:

1. **Buildings** — the practice's physical sites.
2. **Rooms** — belong to a Building.
3. **Tags** — labels describing what kind of work happens in a Room (e.g. "General
   Practice", "Emergency Department"); attach one or more to each Room from the Tags page's
   bulk-apply action or the room form.
4. **Roles** — what a Staff member is qualified to do (e.g. "Senior Fellow", "Nurse
   Practitioner"). Rules and Tags key off Role, not job title.
5. **Staff** — each Staff member holds one or more Roles, has a fortnightly Preferred Days
   pattern (soft — the roster may break it) and date-specific Unavailability (hard — the
   roster never assigns over it). The Roles page has a bulk-apply action for assigning a
   Role to many Staff at once.
6. **Rules** — constraints the generated roster must satisfy: a **minimum-count rule**
   ("this Building/Tag needs at least N staff holding Role X") or an **eligibility rule**
   ("only Role X may work rooms with Tag Y").
7. **Settings** — app-wide Shift Length, travel time between rooms, and max daily minutes
   per staff member, all of which the solver respects.

### 4. Generate a roster

**Rosters → Generate Roster**, pick the date range, and generate. The solver assigns staff
to rooms for every shift in range, respecting Rules, Unavailability, Preferred Days and
Settings, and reports any Rule violations it couldn't avoid.

### 5. View and edit a roster

Open a roster to switch between three views:

- **Text** — shifts grouped by date, one row per shift.
- **Personal** — search for a staff member to see just their shifts across the range.
- **Map** — drill from Building → Room to see that room's 14-day shift calendar.

On the most recently generated roster for a date range, reassign any shift's staff member
directly from the Text view's dropdown — this **pins** that assignment. **Regenerate** from
the Rosters list solves again around any pinned assignments, only filling in the rest. Every
roster ever generated is kept permanently (older ones in a range show read-only) for
audit/review.
