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
;   ISCC /DHaloEdition=next /DHaloMarketing=26.8.1 /DHaloBuild=73 `
;        "/DSourceDir=<abs>\app\build\windows\x64\runner\Release" `
;        "/DIconDir=<abs>\app\windows\runner\resources" `
;        /O"<abs>" `
;        app\windows\installer\ham2k-logger.iss

#ifndef HaloEdition
  #define HaloEdition "dev"
#endif
#ifndef HaloMarketing
  #define HaloMarketing "0.0.0"
#endif
#ifndef HaloBuild
  #define HaloBuild "0"
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
; SecureStorageAppName is the window-title display name
; (runner/CMakeLists.txt's HALO_PRODUCT_NAME) — deliberately shorter than
; {#AppName} (docs/releases.md): it sits beside the taskbar icon, so it drops
; the "Ham2K" prefix. flutter_secure_storage_windows keys its folder off this
; same name, which is why the uninstaller below needs it separately from
; {#InstallFolder}; it must keep matching CMakeLists.txt's per-edition values.
#if HaloEdition == "prod"
  #define AppName "Ham2K Logger"
  #define AppId "{{C41D7E08-3A52-49B6-8F7C-1D6B90E2A344}"
  #define InstallFolder "Ham2K Logger"
  #define SecureStorageAppName "Windows Logger"
#elif HaloEdition == "next"
  #define AppName "Ham2K Logger (Next)"
  #define AppId "{{2E9B5D41-8C67-4F0A-B3D2-9A1E7C4055F8}"
  #define InstallFolder "Ham2K Logger Next"
  #define SecureStorageAppName "Windows Logger Next"
#else
  #define AppName "Ham2K Logger (Dev)"
  #define AppId "{{7F3C1A96-2B84-4D5E-9E11-4A0C6D2F8B31}"
  #define InstallFolder "Ham2K Logger Dev"
  #define SecureStorageAppName "Windows Logger (Dev)"
#endif

#define ExeName "ham2k_logger.exe"
#define AppPublisher "Ham2K"
#define AppUrl "https://ham2k.com"
#define IconFile IconDir + "\app_icon-" + HaloEdition + ".ico"

; The full, human-facing artifact base (§2.2), e.g.
; "Ham2K Logger (Next) 26.8.1-alpha1 (73)". CI passes it from the shared helper
; (print_artifact_name.dart) so the Setup file name matches every other
; platform; the fallback keeps a local ISCC run working without it.
#ifndef HaloFullName
  #define HaloFullName AppName + " " + HaloMarketing + " (" + HaloBuild + ")"
#endif

[Setup]
AppId={#AppId}
AppName={#AppName}
AppVersion={#HaloMarketing}
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
; e.g. "Ham2K Logger (Next) 26.8.1-alpha1 (73) Installer.exe" — the ".exe"
; already implies Windows, so no platform word (§2.2).
OutputBaseFilename={#HaloFullName} Installer

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

[Code]
// Uninstall only ever removes {app} (the program files) — never the
// operator's own data, per Windows best practice: ask, default to keeping
// it. Skipped for a silent uninstall (WinSparkle's background updater only
// ever runs a silent INSTALL over the existing files, never an uninstall, so
// this only fires for an interactive Settings > Apps run or a developer's
// manual `/VERYSILENT`-less test).
procedure CurUninstallStepChanged(CurUninstallStep: TUninstallStep);
var
  DataDir, SecureStorageDir: String;
begin
  if (CurUninstallStep = usPostUninstall) and not UninstallSilent then
  begin
    if MsgBox('Also delete your {#AppName} data - logged QSOs, settings, and your saved QRZ.com login? This cannot be undone.',
       mbConfirmation, MB_YESNO or MB_DEFBUTTON2) = IDYES then
    begin
      // The database, preferences and data-file cache all live together here
      // (app_storage.dart's windowsDataFolderName). Not covered: a failed
      // relocation leaves the database loose in the operator's real Documents
      // folder instead — deliberately untouched, since matching individual
      // files there risks catching something that isn't ours.
      DataDir := ExpandConstant('{localappdata}\{#InstallFolder}');
      // flutter_secure_storage_windows derives this path itself from the
      // exe's own ProductName/CompanyName version info — {#SecureStorageAppName}
      // must keep matching runner/CMakeLists.txt's HALO_PRODUCT_NAME or this
      // stops finding it.
      SecureStorageDir := ExpandConstant('{userappdata}\com.ham2k\{#SecureStorageAppName}');
      DelTree(DataDir, True, True, True);
      DelTree(SecureStorageDir, True, True, True);
      // Remembered window position/size (win32_window.cpp) — cosmetic, but
      // part of "completely uninstalled".
      RegDeleteKeyIncludeSubkeys(HKCU, 'Software\Ham2K\Halo\{#SecureStorageAppName}');
    end;
  end;
end;
