; Inno Setup script for Apollo Fleet Launcher (WinUI/WPF .NET port).
;
; Per-user install (no elevation): the app keeps its settings/state/logs in a
; `config` folder NEXT TO the exe (see ApolloFleet.Core/AppStoragePaths.cs), so
; it must live somewhere the running user can write. Installing under
; %LocalAppData%\Programs keeps that portable-config model working without UAC.
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
; Per-user install: no admin prompt, installs under %LocalAppData%\Programs.
PrivilegesRequired=lowest
PrivilegesRequiredOverridesAllowed=dialog
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
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked

[Files]
; Recursively package the entire self-contained publish output.
Source: "{#PublishDir}\*"; DestDir: "{app}"; Flags: recursesubdirs createallsubdirs ignoreversion

[Icons]
Name: "{group}\{#AppName}"; Filename: "{app}\{#AppExe}"
Name: "{userdesktop}\{#AppName}"; Filename: "{app}\{#AppExe}"; Tasks: desktopicon

[Run]
Filename: "{app}\{#AppExe}"; Description: "{cm:LaunchProgram,{#AppName}}"; Flags: nowait postinstall skipifsilent

[UninstallRun]
; Remove the logon scheduled task the app may have created for auto-start.
Filename: "{sys}\schtasks.exe"; Parameters: "/Delete /TN ""{#TaskName}"" /F"; Flags: runhidden; RunOnceId: "DelApolloFleetTask"

[UninstallDelete]
; Clean up the runtime-created portable config next to the exe.
Type: filesandordirs; Name: "{app}\config"
