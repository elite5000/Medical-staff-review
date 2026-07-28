# Packaging the desktop build

Turns the backend *and* the Windows Flutter client into a single installer that a
non-technical admin can run once — after which the backend starts automatically at every
login with no terminal involved, and the client is an ordinary Start Menu / Desktop app they
open when they want to use it. See the migration plan's "Backend changes" section for the
rationale, and the note below for why this is one installer covering both, not two.

## Build steps

Run from the repo root:

```
cd backend && uv run pyinstaller packaging/tray.spec
cd ../app && flutter build windows --release
```

Produces `backend/dist/MedicalStaffReview/` (onedir — not onefile, since OR-Tools' native
DLLs and startup time are both much better behaved this way) and
`app/build/windows/x64/runner/Release/`. Then, on a machine with
[Inno Setup](https://jrsoftware.org/isinfo.php) installed, from `backend/`:

```
iscc packaging/installer.iss
```

Produces `packaging/dist_installer/MedicalStaffReviewSetup.exe` — the one file to hand to
the admin. It installs the backend to `{app}\backend` and the client to `{app}\client`
(kept in separate subfolders since each is an independent build with its own DLLs and
nothing guarantees their filenames never collide).

**Why one installer, not two**: the backend only runs on Windows, but the Flutter app also
targets macOS and Android — so a phone or Mac never needs `installer.iss` at all, while a
Windows admin using their own PC for everything needs both the backend and a client. Before
this, `installer.iss` only packaged the backend; the admin had no supported way to get the
Windows client at all (caught in review — see git history on this file).

## Known gotchas (already handled in `tray.spec`, documented here so they aren't
"fixed" again by accident)

- **OR-Tools DLLs**: `ortools/__init__.py` loads its native DLLs itself via
  `ctypes.WinDLL(os.path.join(basedir, ".libs", dll))` rather than a normal Python import,
  so PyInstaller's static analysis never sees that dependency and silently drops the
  `ortools/.libs/*.dll` files. `tray.spec` globs them in explicitly as `datas`. Confirmed by
  building a frozen exe without this and watching `ortools.sat.python.cp_model` fail with
  `DLL load failed` at import time — the "Library not found: could not resolve 'ortools.dll'"
  warning PyInstaller prints during the build is not a false positive; treat it as fatal if
  it reappears.
- **Bundled-data location in onedir builds**: PyInstaller 6.x's onedir layout puts all
  bundled data (including `alembic.ini` and `migrations/`) under a `_internal/` subfolder
  next to the exe, not next to `sys.executable` itself. `app/desktop/tray.py`'s
  `_backend_root()` uses `sys._MEIPASS` (correct for both onedir and onefile) rather than
  `Path(sys.executable).parent` for this reason.
- **uvicorn's dynamic imports**: uvicorn picks its event loop/protocol implementations at
  runtime rather than via static imports, so `tray.spec` lists
  `uvicorn.loops.auto`/`uvicorn.protocols.http.auto`/etc. as explicit `hiddenimports`.

## Verified so far

Building `dist/MedicalStaffReview/MedicalStaffReview.exe` and running it standalone (outside
the installer) was confirmed to: run Alembic migrations against
`%LOCALAPPDATA%\MedicalStaffReview\data.db`, generate and persist a pairing token, serve
`/health` without auth and reject `/buildings` without the correct bearer token, and
successfully generate a roster via `POST /rosters` — i.e. the OR-Tools solver runs correctly
inside the frozen build end-to-end.

## Expected warnings on first run

- **Windows Defender Firewall**: the tray app binds a port and will trigger the standard
  one-time "allow this app" prompt (scoped to the Private network profile) the first time it
  starts. Expected — the admin clicks "Allow".
- **Windows SmartScreen**: `MedicalStaffReviewSetup.exe` is unsigned, so SmartScreen will
  likely warn ("Windows protected your PC") the first time it's run. Expected too — the admin
  clicks "More info" → "Run anyway". Code signing would remove this but is a separate, paid
  step not worth doing until it becomes a real nuisance for the admin.

## Not yet verified (needs a real install, see the plan's Verification section)

- Running `iscc` itself — Inno Setup isn't installed in this environment. Both `[Files]`
  source paths in `installer.iss` were confirmed to resolve to real, current build output
  (`backend/dist/MedicalStaffReview/MedicalStaffReview.exe` and
  `app/build/windows/x64/runner/Release/app.exe` both exist), so `iscc` should have what it
  needs — just not proven by actually compiling it.
- Installing the compiled `MedicalStaffReviewSetup.exe` on a clean machine/user account:
  Startup-folder autostart actually firing after a real login, the tray icon and its "Show
  connection QR" / "Open data folder" / "Quit" menu items, and the first-run Windows
  Defender Firewall prompt.
- Pairing a phone over a real LAN (scanning the QR code from a second device) — that's the
  Flutter side (tasks #4+), not built yet.
