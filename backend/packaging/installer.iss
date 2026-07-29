; Inno Setup script for Medical Staff Review — packages BOTH the backend (tray app) and the
; Flutter Windows client into one installer, since a Windows-only admin running everything
; on their own PC needs both and there's no other Windows installer/build step documented
; anywhere in this repo (see packaging/README.md's "Building" section for why one installer,
; not two, is the right call here).
;
; Build order (run from repo root):
;   1. cd backend && uv run pyinstaller packaging/tray.spec  -> backend/dist/MedicalStaffReview/
;   2. cd app && flutter build windows --release              -> app/build/windows/x64/runner/Release/
;   3. iscc backend/packaging/installer.iss                   -> backend/packaging/dist_installer/MedicalStaffReviewSetup.exe
;
; Requires Inno Setup (https://jrsoftware.org/isinfo.php) — not installed in this repo/CI,
; so step 3 must be run manually on a machine that has it (see packaging/README.md).

#define MyAppName "Medical Staff Review"
#define MyBackendExeName "MedicalStaffReview.exe"
#define MyClientExeName "app.exe"
#define MyAppPublisher "Medical Staff Review"

[Setup]
AppId={{7B7C9D2D-9C7B-4F52-8B9E-4C6B2D1F9A11}
AppName={#MyAppName}
AppVersion=1.0
AppPublisher={#MyAppPublisher}
DefaultDirName={autopf}\{#MyAppName}
DefaultGroupName={#MyAppName}
DisableProgramGroupPage=yes
OutputDir=dist_installer
OutputBaseFilename=MedicalStaffReviewSetup
Compression=lzma2
SolidCompression=yes
ArchitecturesInstallIn64BitMode=x64compatible
; Installs to the current user only and only touches the current user's Startup folder
; (see [Icons] below) — no admin rights needed, which matters since the whole point is
; that a non-technical admin can install and run this without help.
PrivilegesRequired=lowest

[Files]
; Kept in separate subfolders, not both dumped into {app}: each is its own independent build
; output with its own arbitrary set of DLLs, and nothing guarantees those names never collide.
Source: "..\dist\MedicalStaffReview\*"; DestDir: "{app}\backend"; Flags: recursesubdirs createallsubdirs
Source: "..\..\app\build\windows\x64\runner\Release\*"; DestDir: "{app}\client"; Flags: recursesubdirs createallsubdirs

[Icons]
; Only the backend gets a Startup-folder shortcut — it's the tray server that needs to
; always be running (see the migration plan's "Backend startup" decision); the client is
; an ordinary app the admin opens when they want to use it, like any other program.
Name: "{group}\{#MyAppName} Backend"; Filename: "{app}\backend\{#MyBackendExeName}"
Name: "{userstartup}\{#MyAppName} Backend"; Filename: "{app}\backend\{#MyBackendExeName}"; Flags: runminimized
Name: "{group}\{#MyAppName}"; Filename: "{app}\client\{#MyClientExeName}"
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\client\{#MyClientExeName}"

[Run]
Filename: "{app}\backend\{#MyBackendExeName}"; Description: "Launch the {#MyAppName} backend now"; Flags: nowait postinstall skipifsilent runminimized
Filename: "{app}\client\{#MyClientExeName}"; Description: "Launch {#MyAppName} now"; Flags: nowait postinstall skipifsilent unchecked
