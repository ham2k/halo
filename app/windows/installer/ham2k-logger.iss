; Ham2K Logger — Windows per-user installer (Inno Setup 6)
; ---------------------------------------------------------------------------
; Compiled in CI after `flutter build windows`, then Authenticode-signed
; (Azure Trusted Signing) as a post-step — see codemagic.yaml. Per-EDITION via
; /DHaloEdition=dev|next|prod, mirroring the macOS/iOS HALO_EDITION seam and the
; Windows runner's own halo_edition.h (docs/releases.md §2.6).
;
; Per-user install (no admin/UAC), so background updates need no elevation —
; the WinSparkle/auto_updater path just downloads the next signed Setup and runs
; it silently (/VERYSILENT), overwriting the install folder in place.
;
; CI invocation (PowerShell):
;   ISCC /DHaloEdition=next /DHaloVersion=26.8.73 `
;        "/DSourceDir=<abs>\app\build\windows\x64\runner\Release" `
;        "/DIconDir=<abs>\app\windows\runner\resources" `
;        /O"<abs>\installer-output" `
;        app\windows\installer\ham2k-logger.iss

#ifndef HaloEdition
  #define HaloEdition "dev"
#endif
#ifndef HaloVersion
  #define HaloVersion "0.0.0"
#endif
#ifndef SourceDir
  #define SourceDir "..\..\build\windows\x64\runner\Release"
#endif
#ifndef IconDir
  #define IconDir "..\runner\resources"
#endif

; --- Per-edition identity ---------------------------------------------------
; AppId GUIDs are STABLE per edition forever (change one and upgrades / uninstall
; break for installed users) and DISTINCT so dev/next/prod install side by side.
; Frozen 2026-07 — do not regenerate.
#if HaloEdition == "prod"
  #define AppName "Ham2K Logger"
  #define AppId "{{C41D7E08-3A52-49B6-8F7C-1D6B90E2A344}"
  #define InstallFolder "Ham2K Logger"
#elif HaloEdition == "next"
  #define AppName "Ham2K Logger Next"
  #define AppId "{{2E9B5D41-8C67-4F0A-B3D2-9A1E7C4055F8}"
  #define InstallFolder "Ham2K Logger Next"
#else
  #define AppName "Ham2K Logger (Dev)"
  #define AppId "{{7F3C1A96-2B84-4D5E-9E11-4A0C6D2F8B31}"
  #define InstallFolder "Ham2K Logger Dev"
#endif

#define ExeName "ham2k_logger.exe"
#define AppPublisher "Ham2K"
#define AppUrl "https://ham2k.com"
#define IconFile IconDir + "\app_icon-" + HaloEdition + ".ico"

[Setup]
AppId={#AppId}
AppName={#AppName}
AppVersion={#HaloVersion}
AppPublisher={#AppPublisher}
AppPublisherURL={#AppUrl}
AppSupportURL={#AppUrl}
; Per-user, no elevation. Users may still choose all-users if they run elevated.
PrivilegesRequired=lowest
PrivilegesRequiredOverridesAllowed=dialog
DefaultDirName={autopf}\{#InstallFolder}
DisableProgramGroupPage=yes
UninstallDisplayName={#AppName}
UninstallDisplayIcon={app}\{#ExeName}
SetupIconFile={#IconFile}
WizardStyle=modern
Compression=lzma2
SolidCompression=yes
; Flutter Windows builds x64; x64compatible also allows arm64 (x64 emulation).
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
OutputBaseFilename={#AppName} {#HaloVersion} Setup

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked

[Files]
; Ship the entire Flutter Release output (exe + flutter_windows.dll + data\ +
; plugin DLLs). ignoreversion so updates overwrite regardless of file version.
Source: "{#SourceDir}\*"; DestDir: "{app}"; Flags: recursesubdirs createallsubdirs ignoreversion

[Icons]
Name: "{autoprograms}\{#AppName}"; Filename: "{app}\{#ExeName}"
Name: "{autodesktop}\{#AppName}"; Filename: "{app}\{#ExeName}"; Tasks: desktopicon

[Run]
; Offered after an interactive install; skipped during a silent (updater) run.
Filename: "{app}\{#ExeName}"; Description: "{cm:LaunchProgram,{#AppName}}"; Flags: nowait postinstall skipifsilent
