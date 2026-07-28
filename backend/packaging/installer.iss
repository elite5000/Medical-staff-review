; Inno Setup script for the Medical Staff Review backend.
;
; Build order (run from backend/):
;   1. uv run pyinstaller packaging/tray.spec   -> dist/MedicalStaffReview/
;   2. iscc packaging/installer.iss             -> packaging/dist_installer/MedicalStaffReviewSetup.exe
;
; Requires Inno Setup (https://jrsoftware.org/isinfo.php) — not installed in this repo/CI,
; so step 2 must be run manually on a machine that has it (see packaging/README.md).

#define MyAppName "Medical Staff Review"
#define MyAppExeName "MedicalStaffReview.exe"
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
Source: "..\dist\MedicalStaffReview\*"; DestDir: "{app}"; Flags: recursesubdirs createallsubdirs

[Icons]
Name: "{group}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"
; This Startup-folder shortcut is what makes the tray app launch automatically at every
; login — the admin never has to remember to "start the server" (see the migration plan's
; "Backend startup" decision).
Name: "{userstartup}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Flags: runminimized

[Run]
Filename: "{app}\{#MyAppExeName}"; Description: "Launch {#MyAppName} now"; Flags: nowait postinstall skipifsilent runminimized
