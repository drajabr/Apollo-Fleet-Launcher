@echo off
setlocal
rem ---------------------------------------------------------------------------
rem  Double-click-friendly launcher for build.ps1.
rem
rem  Double-clicking build.ps1 directly runs it under the machine execution
rem  policy (often blocked) and closes the console instantly, so you never see
rem  the output. This wrapper bypasses the policy for THIS run only (no machine
rem  change), keeps the window open, and — critically — locates a .NET SDK.
rem
rem  On this machine the SDK is a PER-USER install under
rem  %LOCALAPPDATA%\Microsoft\dotnet and is NOT on the system PATH (the only
rem  dotnet on PATH, C:\Program Files\dotnet, is runtime-only -> "No .NET SDKs
rem  were found"). We therefore probe for a dotnet that actually has an sdk\
rem  folder, scanning user profiles too so it's found even if this window was
rem  launched elevated (where %LOCALAPPDATA% is the admin's, not yours).
rem
rem  Double-click        -> Debug build (verifies it compiles).
rem  From a terminal, any build.ps1 switch passes through, e.g.:
rem    build.cmd -Configuration Release -Test
rem    build.cmd -Run
rem    build.cmd -Configuration Release -Publish
rem ---------------------------------------------------------------------------

set "DOTNET_DIR="
call :trydir "%LOCALAPPDATA%\Microsoft\dotnet"
call :trydir "%USERPROFILE%\AppData\Local\Microsoft\dotnet"
if not defined DOTNET_DIR for /d %%U in ("%SystemDrive%\Users\*") do call :trydir "%%~U\AppData\Local\Microsoft\dotnet"
call :trydir "%ProgramFiles%\dotnet"

if defined DOTNET_DIR (
    set "PATH=%DOTNET_DIR%;%PATH%"
    echo Using .NET SDK at: %DOTNET_DIR%
) else (
    echo WARNING: no per-user .NET SDK found; relying on whatever 'dotnet' is on PATH.
)
echo.

powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0build.ps1" %*
set "EXITCODE=%ERRORLEVEL%"

echo.
if "%EXITCODE%"=="0" (
    echo === build.ps1 succeeded ===
) else (
    echo === build.ps1 FAILED ^(exit %EXITCODE%^) ===
)
pause
exit /b %EXITCODE%

rem Sets DOTNET_DIR to %1 (first match wins) only if it holds a real SDK
rem (dotnet.exe next to a non-empty sdk\ folder).
:trydir
if defined DOTNET_DIR goto :eof
if exist "%~1\dotnet.exe" if exist "%~1\sdk\*" set "DOTNET_DIR=%~1"
goto :eof
