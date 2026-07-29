# -*- mode: python ; coding: utf-8 -*-
"""PyInstaller spec for the packaged Windows desktop build.

Run from backend/ (so relative paths below resolve):

    uv run pyinstaller packaging/tray.spec

Produces dist/MedicalStaffReview/ (onedir, not onefile — far more reliable with OR-Tools'
native binaries and starts much faster). alembic.ini and migrations/ are bundled alongside
the exe so app.desktop.tray._backend_root() can find them at runtime (see app/paths.py's
is_frozen()).
"""

from pathlib import Path

backend_root = Path.cwd()

# ortools/__init__.py loads its native DLLs itself via WinDLL(os.path.join(basedir,
# ".libs", dll)) rather than a normal import — PyInstaller's static analysis doesn't see
# that, so the dot-prefixed .libs/ directory is silently dropped unless listed explicitly.
ortools_libs_dir = backend_root / ".venv/Lib/site-packages/ortools/.libs"
if not ortools_libs_dir.exists():
    raise RuntimeError(
        f"Expected OR-Tools native DLL directory not found: {ortools_libs_dir}. "
        "Ensure dependencies are installed in backend/.venv before packaging."
    )
ortools_libs_datas = [
    (str(dll), "ortools/.libs") for dll in ortools_libs_dir.glob("*.dll")
]
if not ortools_libs_datas:
    raise RuntimeError(
        f"No OR-Tools DLLs found under {ortools_libs_dir}; refusing to build a broken package."
    )

a = Analysis(
    [str(backend_root / "app/desktop/tray.py")],
    pathex=[str(backend_root)],
    datas=[
        (str(backend_root / "alembic.ini"), "."),
        (str(backend_root / "migrations"), "migrations"),
        *ortools_libs_datas,
    ],
    hiddenimports=[
        # FastAPI routers are only referenced via app.main's imports, which PyInstaller's
        # static analysis follows fine — but uvicorn picks its loop/protocol/lifespan
        # implementations dynamically at runtime, so they need to be listed explicitly.
        "uvicorn.logging",
        "uvicorn.loops.auto",
        "uvicorn.protocols.http.auto",
        "uvicorn.protocols.websockets.auto",
        "uvicorn.lifespan.on",
    ],
    noarchive=False,
)
pyz = PYZ(a.pure)

exe = EXE(
    pyz,
    a.scripts,
    [],
    exclude_binaries=True,
    name="MedicalStaffReview",
    console=False,
)

COLLECT(
    exe,
    a.binaries,
    a.datas,
    name="MedicalStaffReview",
)
