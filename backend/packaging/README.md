# Packaging the desktop build

Turns the backend into a single Windows installer that a non-technical admin can run once,
after which the app starts automatically at every login with no terminal involved. See the
"Backend changes" section of the migration plan for the full rationale.

## Build steps

Run from `backend/`:

```
uv run pyinstaller packaging/tray.spec
```

Produces `dist/MedicalStaffReview/` (onedir — not onefile, since OR-Tools' native DLLs and
startup time are both much better behaved this way). Then, on a machine with
[Inno Setup](https://jrsoftware.org/isinfo.php) installed:

```
iscc packaging/installer.iss
```

Produces `packaging/dist_installer/MedicalStaffReviewSetup.exe` — the file to hand to the
admin.

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

## Not yet verified (needs a real install, see the plan's Verification section)

- Running `iscc` itself — Inno Setup isn't installed in this environment.
- Installing the compiled `MedicalStaffReviewSetup.exe` on a clean machine/user account:
  Startup-folder autostart actually firing after a real login, the tray icon and its "Show
  connection QR" / "Open data folder" / "Quit" menu items, and the first-run Windows
  Defender Firewall prompt.
- Pairing a phone over a real LAN (scanning the QR code from a second device) — that's the
  Flutter side (tasks #4+), not built yet.
