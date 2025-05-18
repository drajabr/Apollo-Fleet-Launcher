# Apollo Fleet Launcher

A simple tool to configure multiple instances of [@ClassicOldSong/Apollo](https://github.com/ClassicOldSong/Apollo) for streaming multi monitor mode, mainly targeting desktop use case where multi devices like android tablets can be used as Plug and play external monitor.

## Preview
![image](https://github.com/user-attachments/assets/b3d4c8e9-6cbb-4306-8e13-94aac00e67f7)



# Current Status
[![Build](https://github.com/drajabr/Apollo-Fleet-Launcher/actions/workflows/build.yml/badge.svg)](https://github.com/drajabr/Apollo-Fleet-Launcher/actions/workflows/build.yml)

## Functionality
- [x] Multi-instance: Add/remove Multiple instance configuration
- [x] Multi-instance: Auto-startup on user logon
- [x] Multi-instance: Configurable per-instance Audio Device
- [ ] Multi-instance: Sync device volume levels to all instances
- [ ] Multi-instance: Remove virtual display on client disconnect
- [ ] Android Clients: ADB Revrse tethering via Gnirehtet
- [ ] Android Clients: Mic forwarding using (scrcpy)/AndroidMic
- [ ] Android Clients: Cam forwarding using scrcpy/(DroidCamX)

## Changelog
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

> [!Note]
>  [WIP] The following are the planned functionality:
>  - [ ] UX: Logging overall
>  - [ ] GUI: Add status tab
>  - [ ] GUI: Dark/Light theme and follow system
>  - [ ] Multi-instance: Sync volume level (client volume level actually change if changing the volume from inside the host)
>  - [ ] Multi-instance: Remove display on client disconnect
>  - [ ] Android-clients: Package with ADB, scrcpy, gnirehtet in CD pipeline or whatever its called
>  - [ ] Android-clients: Maintain gnirehtet auto tunnel for reverse tethering
>  - [ ] Android-clients: Use the device mic to the host using scrcpy
>  - [ ] Android-clients: Start DroidCamX on the client to use it as a cam
>  - [ ] Android-clients: Automate launch script to auto connect to the desired instance
>  - [ ] Experience-enhancement: Make it easier to setup launch extra parameters (probably using another automate script? or consult @classicOldSong for ways to connect with just computer name and app name)
>  - [ ] Experience-enhancement: Option to use AndroidMic as legacy devices (below Android 10 i guess where scrcpy mic recording is not supported)
>  - [ ] Experience-enhancement: Option to use cam using scrcpy for Android12+ devices
>  - [ ] Experience-enhancement: Use virtual mic device instead of playback on virtual loopback device
>  - [ ] Experience-enhancement: Use virtual cam device instead of relying on full fledged OBS to do that (maybe use DroidCam app or sorta "would love to find foss way to do it too")
>  - [ ] Extra: Auto launch from server side using ADB commands (bind devices to instances) with option to not start that instance until the device is connected
>  - [ ] Super-Goal: ditch the project once these functionalities get implemented in Apollo, or maybe, just maybe, get this UI somehow to work as a plugin/addon for native apollo webUI, to initiate multi instances from there directly




# Many thanks to:
[@ClassicOldSong](https://github.com/ClassicOldSong) For The amazing work on [Apollo](https://github.com/ClassicOldSong/Apollo).

[AutoHotKey](https://github.com/AutoHotkey) For making of this amazing tool [AHK](https://autohotkey.com/) FOSS AND AVAILABLE FOR FREE!.

[@CCCC-L](https://github.com/CCCC-L) For the [AHK v2 Actions template](https://github.com/CCCC-L/Action-Ahk2Exe).

[@alfvar](https://github.com/alfvar) For adding icon support commit in his repo [AHK v2 Actions template](https://github.com/alfvar/action-ahk2exe)

Everyone at [AHK Forums](https://www.autohotkey.com/boards/) for their contributions. Especially:

[@thqby ](https://github.com/thqby) For his [Audio.ahk](https://github.com/thqby/ahk2_lib/blob/master/Audio.ahk) library "eventhough its not noob friendly"

[@ntepa](https://www.autohotkey.com/boards/memberlist.php?mode=viewprofile&u=149849) For his amazing contributing on ahk forums, especially [around Audio.ahk lib](https://www.autohotkey.com/boards/viewtopic.php?t=123256)
