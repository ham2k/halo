; Ham2K Logger — Windows per-user installer (Inno Setup 6)
; ---------------------------------------------------------------------------
; Compiled in CI after `flutter build windows`, then Authenticode-signed
; (Azure Artifact Signing) as a post-step by the Windows build script that
; invokes this file. Per-EDITION via
; /DHaloEdition=dev|next|prod, mirroring the macOS/iOS HALO_EDITION seam and the
; Windows runner's own halo_edition.h (docs/releases.md §2.6).
;
; Per-user install (no admin/UAC), so background updates need no elevation —
; the WinSparkle/auto_updater path downloads the next signed Setup and runs this
; same wizard, overwriting the install folder in place. It passes no arguments
; (the appcast carries no sparkle:installerArguments), so an update is an
; ordinary interactive install, and the [Run] entry's postinstall checkbox is
; what brings the app back.
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
; Per-edition, so side-by-side installs never fight over the file type.
#define ProgId "Ham2K.Logger." + HaloEdition + ".h2kext"
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
; An update runs while the old build is still up: WinSparkle launches this and
; only then asks the app to quit, and the app it asks may be an older build that
; does not (auto_update_service.dart's _QuitForUpdateListener). Restart Manager,
; which is all the default `yes` has, cannot clear that — it can only ASK, and
; crashpad_handler.exe (Sentry's native crash handler, a child of the app,
; living in {app} and so in use itself) has no window and never registers with
; RM. Setup gives up on it and waits for the operator, whose only way out is
; Task Manager. That stalls a hand-run install over a running app exactly as it
; stalls an update.
;
; `force` TERMINATES what RM could not close, and for the app that is a kill,
; NOT its exit hook: RM asks a GUI process with WM_QUERYENDSESSION, while only
; WM_CLOSE reaches the path that runs main.dart's shutdownOnExit — so a forced
; close skips the CAT goodbyes and the database close. The quit above is what
; keeps the UPDATER's path graceful: the app gets itself out of the way before
; Setup ever looks. A hand-run install has no such help, so quit the app first.
;
; RestartApplications=no: RM's own relaunch would just as happily bring back the
; crash handler, orphaned from the app it was watching.
CloseApplications=force
RestartApplications=no

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

[Registry]
; Ham2K extension bundles (HALO-422), so a downloaded .h2kext opens this app.
;
; Per-user (HKA resolves to HKCU for this per-user installer), and keyed per
; EDITION: three editions install side by side, and one shared ProgID would
; leave whichever installed last owning the extension for all of them, still
; owning it after being uninstalled.
;
; uninsdeletevalue/uninsdeletekey throughout: an association pointing at a
; removed install is a double-click that fails with nothing to explain it.
Root: HKA; Subkey: "Software\Classes\.h2kext"; ValueType: string; ValueName: ""; ValueData: "{#ProgId}"; Flags: uninsdeletevalue
Root: HKA; Subkey: "Software\Classes\.h2kext"; ValueType: string; ValueName: "Content Type"; ValueData: "application/vnd.ham2k.extension"; Flags: uninsdeletevalue
Root: HKA; Subkey: "Software\Classes\{#ProgId}"; ValueType: string; ValueName: ""; ValueData: "Ham2K Extension"; Flags: uninsdeletekey
Root: HKA; Subkey: "Software\Classes\{#ProgId}\DefaultIcon"; ValueType: string; ValueName: ""; ValueData: "{app}\{#ExeName},0"
; %1 quoted: a bundle sitting in a path with a space would otherwise reach the
; app as two arguments, neither of them a file.
Root: HKA; Subkey: "Software\Classes\{#ProgId}\shell\open\command"; ValueType: string; ValueName: ""; ValueData: """{app}\{#ExeName}"" ""%1"""

; --- URL schemes (HALO-178) ------------------------------------------------
; The `com.ham2k*://` catalog `deep_link_service.dart` documents, and the same
; list macOS registers in Info.plist's CFBundleURLTypes. Without these, Windows
; hands a deep link to nobody: `app_links` needs an OS registration, and the
; runner's own single-instance forwarding never gets the chance to run.
;
; A scheme has exactly ONE owner per user, so the SHARED ones (com.ham2k,
; com.ham2k.logger, the bare .auth spelling and the com.ham2k.halo alias) go
; to whichever edition installed last — the same "last one wins" the ProgID
; above already lives with. The EDITION-SPECIFIC ones are unambiguous and stay
; with their own install forever.
;
; com.ham2k.logger* is the official HaLo prefix; com.ham2k.halo* is an alias
; under the app's own name. com.ham2k plain is the public deep-link api any
; Ham2K app may answer, never an OAuth redirect.
;
; com.ham2k.polo* is NOT here, on purpose (HALO-526). A Ham2K logger that
; claims PoLo's schemes cannot then ask whether PoLo is installed, because it
; answers its own question — and PoLo cannot run on Windows at all, so the
; claim only ever cost. Older installs did register them, which is why
; UnregisterSharedSchemes in [Code] still names them.
;
; The two are also uninstalled differently, which is the point of the split:
; the edition-specific keys carry uninsdeletekey, while the shared ones are
; removed in [Code] and ONLY when they still point at this install. Deleting
; them unconditionally would mean uninstalling Dev silently unregisters every
; deep link for a Prod install that is still sitting there working.
; An install predating HALO-526 registered com.ham2k.polo* pointing at its own
; exe, and an upgrade only overwrites what it still claims — so without these
; the stale handlers would outlive it on every upgraded machine, leaving
; upgraded and fresh installs answering differently. Deleted outright rather
; than conditionally: no Ham2K app on Windows may own these, and PoLo has no
; Windows build to own them either.
Root: HKA; Subkey: "Software\Classes\com.ham2k.polo"; Flags: deletekey
Root: HKA; Subkey: "Software\Classes\com.ham2k.polo.auth"; Flags: deletekey

; Shared — no uninsdeletekey; see UnregisterSharedSchemes in [Code].
Root: HKA; Subkey: "Software\Classes\com.ham2k"; ValueType: string; ValueName: ""; ValueData: "URL:Ham2K"
Root: HKA; Subkey: "Software\Classes\com.ham2k"; ValueType: string; ValueName: "URL Protocol"; ValueData: ""
Root: HKA; Subkey: "Software\Classes\com.ham2k\DefaultIcon"; ValueType: string; ValueName: ""; ValueData: "{app}\{#ExeName},0"
Root: HKA; Subkey: "Software\Classes\com.ham2k\shell\open\command"; ValueType: string; ValueName: ""; ValueData: """{app}\{#ExeName}"" ""%1"""

Root: HKA; Subkey: "Software\Classes\com.ham2k.logger"; ValueType: string; ValueName: ""; ValueData: "URL:Ham2K Logger"
Root: HKA; Subkey: "Software\Classes\com.ham2k.logger"; ValueType: string; ValueName: "URL Protocol"; ValueData: ""
Root: HKA; Subkey: "Software\Classes\com.ham2k.logger\DefaultIcon"; ValueType: string; ValueName: ""; ValueData: "{app}\{#ExeName},0"
Root: HKA; Subkey: "Software\Classes\com.ham2k.logger\shell\open\command"; ValueType: string; ValueName: ""; ValueData: """{app}\{#ExeName}"" ""%1"""

Root: HKA; Subkey: "Software\Classes\com.ham2k.logger.auth"; ValueType: string; ValueName: ""; ValueData: "URL:Ham2K Logger Sign-in"
Root: HKA; Subkey: "Software\Classes\com.ham2k.logger.auth"; ValueType: string; ValueName: "URL Protocol"; ValueData: ""
Root: HKA; Subkey: "Software\Classes\com.ham2k.logger.auth\DefaultIcon"; ValueType: string; ValueName: ""; ValueData: "{app}\{#ExeName},0"
Root: HKA; Subkey: "Software\Classes\com.ham2k.logger.auth\shell\open\command"; ValueType: string; ValueName: ""; ValueData: """{app}\{#ExeName}"" ""%1"""

; The alias under HaLo's own name.
Root: HKA; Subkey: "Software\Classes\com.ham2k.halo"; ValueType: string; ValueName: ""; ValueData: "URL:Ham2K Logger"
Root: HKA; Subkey: "Software\Classes\com.ham2k.halo"; ValueType: string; ValueName: "URL Protocol"; ValueData: ""
Root: HKA; Subkey: "Software\Classes\com.ham2k.halo\DefaultIcon"; ValueType: string; ValueName: ""; ValueData: "{app}\{#ExeName},0"
Root: HKA; Subkey: "Software\Classes\com.ham2k.halo\shell\open\command"; ValueType: string; ValueName: ""; ValueData: """{app}\{#ExeName}"" ""%1"""

; Edition-specific — nobody else ever claims these, so they uninstall cleanly.
Root: HKA; Subkey: "Software\Classes\com.ham2k.halo.{#HaloEdition}"; ValueType: string; ValueName: ""; ValueData: "URL:{#AppName}"; Flags: uninsdeletekey
Root: HKA; Subkey: "Software\Classes\com.ham2k.halo.{#HaloEdition}"; ValueType: string; ValueName: "URL Protocol"; ValueData: ""
Root: HKA; Subkey: "Software\Classes\com.ham2k.halo.{#HaloEdition}\DefaultIcon"; ValueType: string; ValueName: ""; ValueData: "{app}\{#ExeName},0"
Root: HKA; Subkey: "Software\Classes\com.ham2k.halo.{#HaloEdition}\shell\open\command"; ValueType: string; ValueName: ""; ValueData: """{app}\{#ExeName}"" ""%1"""

Root: HKA; Subkey: "Software\Classes\com.ham2k.halo.{#HaloEdition}.auth"; ValueType: string; ValueName: ""; ValueData: "URL:{#AppName} Sign-in"; Flags: uninsdeletekey
Root: HKA; Subkey: "Software\Classes\com.ham2k.halo.{#HaloEdition}.auth"; ValueType: string; ValueName: "URL Protocol"; ValueData: ""
Root: HKA; Subkey: "Software\Classes\com.ham2k.halo.{#HaloEdition}.auth\DefaultIcon"; ValueType: string; ValueName: ""; ValueData: "{app}\{#ExeName},0"
Root: HKA; Subkey: "Software\Classes\com.ham2k.halo.{#HaloEdition}.auth\shell\open\command"; ValueType: string; ValueName: ""; ValueData: """{app}\{#ExeName}"" ""%1"""

Root: HKA; Subkey: "Software\Classes\com.ham2k.logger.{#HaloEdition}"; ValueType: string; ValueName: ""; ValueData: "URL:{#AppName}"; Flags: uninsdeletekey
Root: HKA; Subkey: "Software\Classes\com.ham2k.logger.{#HaloEdition}"; ValueType: string; ValueName: "URL Protocol"; ValueData: ""
Root: HKA; Subkey: "Software\Classes\com.ham2k.logger.{#HaloEdition}\DefaultIcon"; ValueType: string; ValueName: ""; ValueData: "{app}\{#ExeName},0"
Root: HKA; Subkey: "Software\Classes\com.ham2k.logger.{#HaloEdition}\shell\open\command"; ValueType: string; ValueName: ""; ValueData: """{app}\{#ExeName}"" ""%1"""

Root: HKA; Subkey: "Software\Classes\com.ham2k.logger.{#HaloEdition}.auth"; ValueType: string; ValueName: ""; ValueData: "URL:{#AppName} Sign-in"; Flags: uninsdeletekey
Root: HKA; Subkey: "Software\Classes\com.ham2k.logger.{#HaloEdition}.auth"; ValueType: string; ValueName: "URL Protocol"; ValueData: ""
Root: HKA; Subkey: "Software\Classes\com.ham2k.logger.{#HaloEdition}.auth\DefaultIcon"; ValueType: string; ValueName: ""; ValueData: "{app}\{#ExeName},0"
Root: HKA; Subkey: "Software\Classes\com.ham2k.logger.{#HaloEdition}.auth\shell\open\command"; ValueType: string; ValueName: ""; ValueData: """{app}\{#ExeName}"" ""%1"""

[Run]
; Offered at the end of the wizard — including the updater's run, which is an
; ordinary interactive install, so this is how the app comes back after an
; update. skipifsilent leaves a hand-run /VERYSILENT install alone.
Filename: "{app}\{#ExeName}"; Description: "{cm:LaunchProgram,{#AppName}}"; Flags: nowait postinstall skipifsilent

[Code]
// Uninstall only ever removes {app} (the program files) — never the
// operator's own data, per Windows best practice: ask, default to keeping
// it. Skipped for a silent uninstall — the updater only ever INSTALLS over the
// existing files, never uninstalls, so this only fires for an interactive
// Settings > Apps run.
// Removes a SHARED URL scheme, but only while it still points at this
// install's exe (HALO-178).
//
// Shared schemes go to whichever edition installed last, so at uninstall time
// this one may no longer be the owner: a machine with Dev and Prod where Prod
// installed second has Prod holding com.ham2k://. Deleting it with Dev would
// unregister every deep link for an install that is still there and working,
// and nothing would report it — the links would simply stop opening anything.
//
// Comparing the command string is what makes that decidable: it names the
// exe path, and {app} is per-edition.
procedure UnregisterSharedSchemeIn(RootKey: Integer; Scheme: String);
var
  Key, Command, Ours: String;
begin
  Key := 'Software\Classes\' + Scheme;
  Ours := ExpandConstant('"{app}\{#ExeName}" "%1"');
  if RegQueryStringValue(RootKey, Key + '\shell\open\command', '', Command) then
  begin
    if CompareText(Command, Ours) = 0 then
      RegDeleteKeyIncludingSubkeys(RootKey, Key);
  end;
end;

// BOTH roots, every time, and neither is redundant.
//
// [Registry] writes under HKA, which is HKCU for the ordinary per-user install
// and HKLM when the operator takes the all-users option that
// PrivilegesRequiredOverridesAllowed leaves open — so cleaning only HKCU would
// leave an all-users install's schemes pointing at a deleted exe.
//
// HKCU is then still worth checking on an all-users uninstall, because the
// in-app "Register URL schemes" button always writes HKCU: a copy that used it
// leaves per-user keys SHADOWING the machine ones, which outlive an uninstall
// that only knew about HKLM.
procedure UnregisterSharedScheme(Scheme: String);
begin
  UnregisterSharedSchemeIn(HKCU, Scheme);
  if IsAdminInstallMode() then
    UnregisterSharedSchemeIn(HKLM, Scheme);
end;

procedure UnregisterSharedSchemes();
begin
  UnregisterSharedScheme('com.ham2k');
  UnregisterSharedScheme('com.ham2k.halo');
  UnregisterSharedScheme('com.ham2k.logger');
  UnregisterSharedScheme('com.ham2k.logger.auth');
  // No longer registered (HALO-526), but an install predating that did, and
  // the keys outlive it: an upgrade writes over what it claims and leaves the
  // rest. These two stay so the stale handler goes when this copy does — and
  // they are safe to name, since the command check above deletes nothing that
  // does not already point at this exe.
  UnregisterSharedScheme('com.ham2k.polo');
  UnregisterSharedScheme('com.ham2k.polo.auth');
end;

procedure CurUninstallStepChanged(CurUninstallStep: TUninstallStep);
var
  DataDir, SecureStorageDir: String;
begin
  // Unconditionally, and before the data prompt: a handler pointing at a
  // deleted exe is a link that fails with nothing to explain it, whatever the
  // operator decides about their logs. Silent uninstalls included.
  if CurUninstallStep = usPostUninstall then
    UnregisterSharedSchemes();

  if (CurUninstallStep = usPostUninstall) and not UninstallSilent then
  begin
    if MsgBox('Also delete your {#AppName} data - logs, settings and accounts? This cannot be undone.',
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
      RegDeleteKeyIncludingSubkeys(HKCU, 'Software\Ham2K\Halo\{#SecureStorageAppName}');
    end;
  end;
end;
