# Apollo Fleet Launcher

A simple tool to configure multiple instances of [@ClassicOldSong/Apollo](https://github.com/ClassicOldSong/Apollo) for streaming multi monitor mode, mainly targeting desktop use case where multi devices like android tablets can be used as Plug and play external monitor.

This is the same concept of my old [Multi-streaming-setup](https://github.com/drajabr/My-Sunshine-setup) scripts, with ease of GUI and Auto Configuration, bundled with necessary binaries for Android clients stuff.

## Preview
![image](https://github.com/user-attachments/assets/e6354d61-5b3e-4e35-b4aa-850e89c4de45)

## How to use
https://github.com/user-attachments/assets/72a3909f-b1c7-4aa2-bd78-3a70d3acbc61



# Current Status
[![Build](https://github.com/drajabr/Apollo-Fleet-Launcher/actions/workflows/build.yml/badge.svg)](https://github.com/drajabr/Apollo-Fleet-Launcher/actions/workflows/build.yml)

> [!Note]
> Please bear in mind I'm not a proffissional programmer, this tool could have many issues or some unimplemented features yet, but this is an essential tool for me I use everyday so expect I keep working on delivering fixes and featuers for it.
>
> If you find any issue please don't hesitate to open an issue in the repo, your feedback "and pull requests" are very welcomed.

## Changelog
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
- [x] Android Clients: ADB Revrse tethering via Gnirehtet
- [x] Android Clients: Maintain client Mic to PC using scrcpy
- [x] Android Clients: Maintain client Cam to PC using scrcpy
- [ ] Android Clients: Automate virtual Cam (need suitable driver first)
- [ ] Android Clients: Support Mic with other than scrcpy (like AndroidMic)
- [ ] Android Clients: Automate virtual Cam (something like tiny obs client?)
- [ ] Android Clients: Support Cam for Android version below 12 (like DroidCamX)
- [ ] Android Clients: Possibly bind instance to a device, thus that as soon as it connects launch the client using adb shell?


# Many thanks to:
[@ClassicOldSong](https://github.com/ClassicOldSong) [Apollo](https://github.com/ClassicOldSong/Apollo)

[AutoHotKey](https://github.com/AutoHotkey) [AHK](https://autohotkey.com/) 

[@alfvar](https://github.com/alfvar) [AHK v2 Actions template](https://github.com/alfvar/action-ahk2exe)

[@thqby ](https://github.com/thqby) [Audio.ahk](https://github.com/thqby/ahk2_lib/blob/master/Audio.ahk) and [JSON.ahk](https://github.com/thqby/ahk2_lib/blob/master/JSON.ahk)

[@ntepa](https://www.autohotkey.com/boards/memberlist.php?mode=viewprofile&u=149849)  [Audio.ahk lib](https://www.autohotkey.com/boards/viewtopic.php?t=123256)

[@cyruz](https://www.autohotkey.com/boards/memberlist.php?mode=viewprofile&u=98)  [StdoutToVar.ahk](https://www.autohotkey.com/boards/viewtopic.php?f=83&t=109148&hilit=StdoutToVar)
