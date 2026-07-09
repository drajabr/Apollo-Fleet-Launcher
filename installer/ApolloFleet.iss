; Inno Setup script for Apollo Fleet Launcher (WinUI/WPF .NET port).
;
; All-users install to Program Files (requires admin): the app always runs
; elevated (requireAdministrator), so it can write its `config` folder next to
; the exe there (see ApolloFleet.Core/AppStoragePaths.cs). There is deliberately
; no per-user "just for me" option — an unelevated install would be useless
; because the app cannot function without elevation.
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

[UninstallRun]
; Remove the logon scheduled task the app may have created for auto-start.
Filename: "{sys}\schtasks.exe"; Parameters: "/Delete /TN ""{#TaskName}"" /F"; Flags: runhidden; RunOnceId: "DelApolloFleetTask"

[UninstallDelete]
; Clean up the machine-wide config/state/logs the app creates at runtime.
Type: filesandordirs; Name: "{commonappdata}\ApolloFleet"
