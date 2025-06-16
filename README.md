# Apollo Fleet Launcher

A simple tool to configure multiple instances of [@ClassicOldSong/Apollo](https://github.com/ClassicOldSong/Apollo) for streaming multi monitor mode, mainly targeting desktop use case where multi devices like android tablets can be used as Plug and play external monitor.

This is the same concept of my old [Multi-streaming-setup](https://github.com/drajabr/My-Sunshine-setup) scripts, with ease of GUI and Auto Configuration, bundled with necessary binaries for Android clients stuff.

## Preview
![image](https://github.com/user-attachments/assets/812db344-6c15-4a37-9235-e561dc6c1a5d)




# Current Status
[![Build](https://github.com/drajabr/Apollo-Fleet-Launcher/actions/workflows/build.yml/badge.svg)](https://github.com/drajabr/Apollo-Fleet-Launcher/actions/workflows/build.yml)

## Functionality
- [x] Multi-instance: Add/remove Multiple instance configuration
- [x] Multi-instance: Auto-startup on user logon
- [x] Multi-instance: Configurable per-instance Audio Device
- [ ] Multi-instance: Sync device volume levels to all instances
- [x] Multi-instance: Enable terminate-on-pause setting to Remove virtual display on client disconnect
- [X] Android Clients: ADB Revrse tethering via Gnirehtet
- [ ] Android Clients: Mic forwarding using (scrcpy)/AndroidMic
- [ ] Android Clients: Cam forwarding using scrcpy/(DroidCamX)

## Changelog
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




# Many thanks to:
[@ClassicOldSong](https://github.com/ClassicOldSong) For The amazing work on [Apollo](https://github.com/ClassicOldSong/Apollo).

[AutoHotKey](https://github.com/AutoHotkey) For making of this amazing tool [AHK](https://autohotkey.com/) FOSS AND AVAILABLE FOR FREE!.

[@CCCC-L](https://github.com/CCCC-L) For the [AHK v2 Actions template](https://github.com/CCCC-L/Action-Ahk2Exe).

[@alfvar](https://github.com/alfvar) For adding icon support commit in his repo [AHK v2 Actions template](https://github.com/alfvar/action-ahk2exe)

Everyone at [AHK Forums](https://www.autohotkey.com/boards/) for their contributions. Especially:

[@thqby ](https://github.com/thqby) For his [Audio.ahk](https://github.com/thqby/ahk2_lib/blob/master/Audio.ahk) library "eventhough its not noob friendly"

[@ntepa](https://www.autohotkey.com/boards/memberlist.php?mode=viewprofile&u=149849) For his amazing contributing on ahk forums, especially [around Audio.ahk lib](https://www.autohotkey.com/boards/viewtopic.php?t=123256)
