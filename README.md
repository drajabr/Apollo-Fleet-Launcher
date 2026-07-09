# Apollo Fleet Launcher

A simple tool to configure multiple instances of [@ClassicOldSong/Apollo](https://github.com/ClassicOldSong/Apollo) for streaming multi monitor mode, mainly targeting desktop use case where multi devices like android tablets can be used as Plug and play external monitor.

## WinUI 3 manager (`src/`)

A newer **.NET 8 + WinUI 3** implementation lives under [`src/ApolloFleet.sln`](src/ApolloFleet.sln): multi-instance Apollo hosting, lock/apply settings flow, tray, English + Arabic (RTL) + Spanish + French, scheduled logon task (`ApolloFleet`) with optional cooperation with `ApolloService`, and GitHub Actions **WinUI CI / WinUI Release** workflows.

- **Install:** download `ApolloFleet-Setup-vX.Y.Z-win-x64.exe` from the [latest release](https://github.com/drajabr/Apollo-Fleet-Launcher/releases/latest) and run it. It is self-contained (no .NET runtime needed) and installs for all users under `Program Files`, adding a Start Menu entry, desktop icon, and uninstaller.
- **Elevation:** the app **requires administrator** — managing Apollo is impossible without it. Manual launch shows one UAC prompt; the auto-start logon task runs it elevated with no prompt. See [`docs/elevation.md`](docs/elevation.md).
- **Build from source:** run `./build.ps1 -Configuration Release -Publish` to create a single-file exe at `dist/Release/win-x64/ApolloFleet.App.exe`.
- **Settings / state:** stored in a `config\` folder next to the app (under the install directory); the elevated app manages it for you.
- **SmartScreen:** CI builds are **unsigned**; Windows SmartScreen may warn until you trust the app or apply a code signature.
- **Uninstall:** exit the app (tray **Exit**), then use *Settings → Apps* or the Start Menu uninstaller — it also removes the **ApolloFleet** scheduled task and the config.
- **Minimum tested Apollo:** use a current stable [Apollo release](https://github.com/ClassicOldSong/Apollo/releases); Web UI URL logic uses **HTTPS on streaming port + 1** (same as the legacy AHK launcher).

This is the same concept of my old [Multi-streaming-setup](https://github.com/drajabr/My-Sunshine-setup) scripts, with ease of GUI and Auto Configuration.

> [!Note]
> The `.NET` port replaces the original AutoHotkey app and **drops the Android helper features** (reverse tethering, ADB, scrcpy mic/cam, bundled platform-tools). If you need those, use a `v0.3.x` release from the AHK era.

## Preview
<img width="582" height="230" alt="image" src="https://github.com/user-attachments/assets/2bfe3efe-21ab-494b-a790-5a0133e1b18d" />


## How to use
https://github.com/user-attachments/assets/72a3909f-b1c7-4aa2-bd78-3a70d3acbc61



# Current Status
[![WinUI CI](https://github.com/drajabr/Apollo-Fleet-Launcher/actions/workflows/apollofleet-ci.yml/badge.svg)](https://github.com/drajabr/Apollo-Fleet-Launcher/actions/workflows/apollofleet-ci.yml)

> [!Note]
> Please bear in mind I'm not a proffissional programmer, this tool could have many issues or some unimplemented features yet, but this is an essential tool for me I use everyday so expect I keep working on delivering fixes and featuers for it.
>
> If you find any issue please don't hesitate to open an issue in the repo, your feedback "and pull requests" are very welcomed.

## Changelog
* v0.4.2 Auto-detect Apollo install, features on by default, elevated launch without extra UAC prompts, installer-only release
* v0.4.1 Self-contained Windows installer (.exe) — no runtime prerequisite; portable zip still available
* v0.4.0 Claude finishing the job, native UI, experimental release
* v0.3.3 Bug fixes
  * FIX: Run with powershell full path to avoid errors if not defined in PATH for some reason
  * FIX: Reset window area if one monitor disconnected
  * FIX: Stop all timers before apply, so don't result orphand processes in some cases
  * FIX: Properly delete instances from settings file
  * FIX: Handle terminate-on-pause override properly if the apps.json was already initialized
* v0.3.2 Bug fixes and enhancements
  * FIX: Proper JSON boolean handling
  * FIX: Preserve pids properly, in seperate "transient" ini file
  * FIX: Allow alternative path for apollo
  * UX: Add option to enable/disable headless mode per-instance
  * Fix: Disable if "Unset" for android cam/mic features
* v0.3.1 DARK Theme! & Apollo elevated run
  * UI: Dark Theme: Follows system for now (could be changed from settings.ini too)
  * FIX: Apollo runs with service permissions using PsExec (well paexec used here) [2](https://github.com/drajabr/Apollo-Fleet-Launcher/issues/2)
  * FIX: Unset configs properly
  * Manager: More non-blocking start and kill to increase responsivity
  * FIX: Volume sync now works with audio device set other than default output
* v0.2.9hotfix - Standalone operation hotfix
  * FIX: Launch process if its killed or not launched
  * FIX: Delay startup run 30 sec to allow systray init properly
* v0.2.9 - Standalone operation fix
  * FIX: Don't use default instance as a reference
  * FIX: Non-blocking termination of unnecessary processes
  * FIX: More validation for list selected item
  * UI: Removed sync instaces with default instance checkbox
  * UI:  Add enable/disable checkbox to control each instance
* v0.2.2 - Nothing exciting, dumb hotfixes
  * FIX: more non-blocking bootstrap
  * FIX: Volume level sync for multi instance
* v0.2.1 - Volume Sync, Android Mic and Cam coming Alive!
  * Fleet: Sync system volume level to all apollo instances
  * Android: Mainaing list of connected ADB devices
  * Android: Use Scrcpy to playback device mic (still need loop device to use it as a mic)
  * Android: Use Scrcpy to mirror device camera (need obs to expose it as virtual camera)
  * UX: Apply button directly save and apply settings and reload manager
  * FIX: Audio selector, confirm settings file write, apollo status logic, disable buttons until ready
* v0.1.3 - Essential fixes and functionality
  * GUI: No close button, use sytemtray icon to exit
  * UX: Use terminate-on-pause setting from latest Apollo update to remove virtual display on client disconnect
  * FIX: Clone apps.json from default instance
  * FIX: Scheduled task creation and disable stock service
* v0.1.2 - Rise of Android Helpers
  * Android: Start and Maintain Gnirehtet process for Reverse Tethering
  * Android: Package the latest adb, gnirehtet, and scrcpy binaries
  * GUI: Basic functionality for the Status Area
  * UX: Copy Settings from default instance can be enabled selectively
  * FIX: Don't delete files until process exits
* v0.1.1 - Quite the fundemental functionality!
  * UX: Create scheduled task to run priviliged at user log on! 
  * Multi-instance: Allow Seperate Audio Device selection
  * GUI: Add Audio Device Selector for each instance
  * GUI: Allow per-instance Copy other settings from default
  * GUI: Introduce "statusbar" for future functionality
  * FIX: Seperate Log, credentials, and state file for each instance
  * FIX: Actually remember the old processes and keep them
  * FIX: Add headless_mode enabled to the configurations
* v0.0.2 - Second preview release - slightly improved
  * Multi-instance: don't kill the process if we created it earlier
  * Code improvement: more scoped write settings
  * Code improvement: better settings handling for runtime variables we need to keep
  * Code improvement: smart process termination using sigint
  * Release: create simple sfx installer
* v0.0.1 - Preview release - basic functionality
  * GUI: Basic functional GUI elements
  * GUI: Load, Edit, and Save settings
  * GUI: minimize, close, show/hide logs area
  * Multi-instance: Add, remove, edit multi instance
  * Multi-instance: Read and write config files
  * Multi-instance: Automatically start instances


## Functionality
- [x] Multi-instance: Add/remove Multiple instance configuration
- [x] Multi-instance: Auto-startup on user logon
- [x] Multi-instance: Configurable per-instance Audio Device
- [x] Multi-instance: Sync device volume levels to all instances
- [x] Multi-instance: Enable terminate-on-pause setting to Remove virtual display on client disconnect
- [x] Multi-instance: Maintain Apollo instances "in case one exit/crash" 
- [x] Multi-instance: Fix volume level sync 

**Android client helpers** (AHK era only — **removed in the `.NET` port**; available in `v0.3.x` releases):
- ADB reverse tethering via Gnirehtet, client Mic/Cam to PC via scrcpy, bundled adb/scrcpy/gnirehtet binaries.


# Many thanks to:
[@ClassicOldSong](https://github.com/ClassicOldSong) [Apollo](https://github.com/ClassicOldSong/Apollo)

[AutoHotKey](https://github.com/AutoHotkey) [AHK](https://autohotkey.com/) 

[@alfvar](https://github.com/alfvar) [AHK v2 Actions template](https://github.com/alfvar/action-ahk2exe)

[@thqby ](https://github.com/thqby) [Audio.ahk](https://github.com/thqby/ahk2_lib/blob/master/Audio.ahk) and [JSON.ahk](https://github.com/thqby/ahk2_lib/blob/master/JSON.ahk)

[@ntepa](https://www.autohotkey.com/boards/memberlist.php?mode=viewprofile&u=149849)  [Audio.ahk lib](https://www.autohotkey.com/boards/viewtopic.php?t=123256)

[@cyruz](https://www.autohotkey.com/boards/memberlist.php?mode=viewprofile&u=98)  [StdoutToVar.ahk](https://www.autohotkey.com/boards/viewtopic.php?f=83&t=109148&hilit=StdoutToVar)
