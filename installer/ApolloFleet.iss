; Inno Setup script for Apollo Fleet Launcher (WinUI/WPF .NET port).
;
; All-users install to Program Files (requires admin): the app always runs
; elevated (requireAdministrator). It stores its settings/state/fleet config under
; %ProgramData%\ApolloFleet (see ApolloFleet.Core/AppStoragePaths.cs), NOT next to
; the exe. There is deliberately no per-user "just for me" option — an unelevated
; install would be useless because the app cannot function without elevation.
;
; Expects a self-contained publish so no separate .NET runtime is required.
; Version and the payload folder are passed in from CI:
;   iscc /DAppVersion=0.4.0 /DPublishDir=..\publish\ApolloFleet installer\ApolloFleet.iss

#ifndef AppVersion
  #define AppVersion "0.0.0"
#endif
#ifndef PublishDir
  #define PublishDir "..\publish\ApolloFleet"
#endif

#define AppName "Apollo Fleet Launcher"
#define AppExe "ApolloFleet.App.exe"
#define AppPublisher "drajabr"
#define AppUrl "https://github.com/drajabr/Apollo-Fleet-Launcher"
#define TaskName "ApolloFleet"

[Setup]
AppId={{7C9E6A54-3B2D-4E1F-A8C0-9D5B4F2E1A3C}
AppName={#AppName}
AppVersion={#AppVersion}
AppPublisher={#AppPublisher}
AppPublisherURL={#AppUrl}
AppSupportURL={#AppUrl}/issues
DefaultDirName={autopf}\{#AppName}
DefaultGroupName={#AppName}
DisableProgramGroupPage=yes
; All-users install; the app requires elevation to run, so require it to install too.
PrivilegesRequired=admin
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
OutputBaseFilename=ApolloFleet-Setup-v{#AppVersion}-win-x64
SetupIconFile=..\src\ApolloFleet.App\app.ico
UninstallDisplayIcon={app}\{#AppExe}
UninstallDisplayName={#AppName} {#AppVersion}
Compression=lzma2/max
SolidCompression=yes
WizardStyle=modern

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
; Desktop icon checked by default.
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"

[Files]
; Recursively package the entire self-contained publish output.
Source: "{#PublishDir}\*"; DestDir: "{app}"; Flags: recursesubdirs createallsubdirs ignoreversion

[Icons]
Name: "{group}\{#AppName}"; Filename: "{app}\{#AppExe}"
Name: "{autodesktop}\{#AppName}"; Filename: "{app}\{#AppExe}"; Tasks: desktopicon

[Run]
; shellexec (ShellExecuteEx) is required: the app is requireAdministrator, and a
; plain CreateProcess launch from Setup fails with "requires elevation" (740).
; ShellExecuteEx honors the manifest; since Setup is already elevated the app
; starts elevated with no extra UAC prompt.
Filename: "{app}\{#AppExe}"; Description: "{cm:LaunchProgram,{#AppName}}"; Flags: nowait postinstall skipifsilent shellexec
; Self-update relaunch. The entry above is `skipifsilent`, so it never fires for the
; in-app updater's /VERYSILENT install; this one has no `postinstall` and is gated on
; our own /RELAUNCH=1 switch, so only the updater triggers it.
Filename: "{app}\{#AppExe}"; Flags: nowait shellexec; Check: ShouldRelaunch

[UninstallRun]
; Remove the logon scheduled task the app may have created for auto-start.
Filename: "{sys}\schtasks.exe"; Parameters: "/Delete /TN ""{#TaskName}"" /F"; Flags: runhidden; RunOnceId: "DelApolloFleetTask"

[UninstallDelete]
; Only remove volatile logs on uninstall. User settings, fleet config and device
; pairings (%ProgramData%\ApolloFleet\settings.json + fleet\) are intentionally
; PRESERVED so an uninstall-then-reinstall style update never wipes the user's
; setup or forces them to re-pair (GitHub #27). Delete that folder by hand for a
; full clean removal.
Type: filesandordirs; Name: "{commonappdata}\ApolloFleet\logs"
; Downloaded self-update installers are pure cache.
Type: filesandordirs; Name: "{commonappdata}\ApolloFleet\updates"

[Code]
// Must match App.xaml.cs TryAcquireSingleInstance().
const
  SingleInstanceMutex = 'Global\ApolloFleetLauncher_SingleInstance';
  MutexWaitMs = 15000;

// The in-app updater passes /RELAUNCH=1. {param:} only matches NAME=VALUE
// switches, which is why it is not a bare /RELAUNCH.
function ShouldRelaunch(): Boolean;
begin
  Result := ExpandConstant('{param:RELAUNCH|0}') = '1';
end;

// Self-update only: the updater launches Setup and then exits, so wait (bounded)
// for the app's single-instance mutex to disappear before replacing files under a
// live process. Gated on /RELAUNCH=1 so a normal interactive install is completely
// unaffected (no stall, Restart Manager behaves as before).
// Deliberately NOT using AppMutex: under /VERYSILENT that aborts Setup rather than
// waiting. If the app never exits, the file copy fails and Setup exits nonzero with
// the previous install left intact.
function PrepareToInstall(var NeedsRestart: Boolean): String;
var
  Waited: Integer;
begin
  Result := '';
  if not ShouldRelaunch() then
    Exit;

  Waited := 0;
  while CheckForMutexes(SingleInstanceMutex) and (Waited < MutexWaitMs) do
  begin
    Sleep(250);
    Waited := Waited + 250;
  end;
  // Handle close and file-lock release are not atomic.
  if Waited > 0 then
    Sleep(500);
end;
