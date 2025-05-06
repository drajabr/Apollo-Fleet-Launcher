# Apollo Fleet Launcher
A simple tool to configure multiple instances of [@ClassicOldSong/Apollo](https://github.com/ClassicOldSong/Apollo) for streaming multi monitor mode, mainly targeting desktop use case where multi devices like android tablets can be used as Plug and play external monitor.

[![Build](https://github.com/drajabr/Apollo-Fleet-Launcher/actions/workflows/build.yml/badge.svg)](https://github.com/drajabr/Apollo-Fleet-Launcher/actions/workflows/build.yml)

# Current Status
* v0.0.1 - Preview release - basic functionality
  * Create and save config files.
  * Start multiple instances them on app start/reload.
  * Minimize to tray and restore properly.


> [!WARNING]
>  [WIP] The following are the planned functionality and their current status:
>  - [x] GUI: Basic functional GUI elements
>  - [x] GUI: Load, Edit, and Save settings
>  - [x] GUI: minimize, close, show/hide logs area
>  - [ ] UX: Auto setup task scheduler service
>  - [ ] UX: Logging overall
>  - [ ] GUI: Add status tab
>  - [ ] GUI: Dark/Light theme and follow system
>  - [ ] GUI: Instead of msgbox, add small label bar to show warning/errors when they're raised
>  - [x] Multi-instance: Add, remove, edit multi instance
>  - [x] Multi-instance: Read and write config files
>  - [X] Multi-instance: Automatically start instances
>  - [ ] Multi-instance: test and preserve the already running instances (hopefully API keys/auth will be implemented to make this more robust than wget/curl test)
>  - [ ] Multi-instance: Sync volume level (client volume level actually change if changing the volume from inside the host)
>  - [ ] Multi-instance: Remove display on client disconnect
>  - [ ] Android-clients: Package with ADB, scrcpy, gnirehtet in CD pipeline or whatever its called
>  - [ ] Android-clients: Maintain gnirehtet auto tunnel for reverse tethering
>  - [ ] Android-clients: Use the device mic to the host using scrcpy
>  - [ ] Android-clients: Start DroidCamX on the client to use it as a cam
>  - [x] Android-clients: Automate launch script to auto connect to the desired instance
>  - [ ] Experience-enhancement: Make it easier to setup launch extra parameters (probably using another automate script? or consult @classicOldSong for ways to connect with just computer name and app name)
>  - [ ] Experience-enhancement: Option to use AndroidMic as legacy devices (below Android 10 i guess where scrcpy mic recording is not supported)
>  - [ ] Experience-enhancement: Option to use cam using scrcpy for Android12+ devices
>  - [ ] Experience-enhancement: Use virtual mic device instead of playback on virtual loopback device
>  - [ ] Experience-enhancement: Use virtual cam device instead of relying on full fledged OBS to do that (maybe use DroidCam app or sorta "would love to find foss way to do it too")
>  - [ ] Extra: Auto launch from server side using ADB commands (bind devices to instances) with option to not start that instance until the device is connected
>  - [ ] Super-Goal: ditch the project once these functionalities get implemented in Apollo, or maybe, just maybe, get this UI somehow to work as a plugin/addon for native apollo webUI, to initiate multi instances from there directly

## Preview
https://github.com/user-attachments/assets/1c63ccff-df32-4b91-b838-d009cd771255






# Many thanks to:
[@ClassicOldSong](https://github.com/ClassicOldSong) For The amazing work on [Apollo](https://github.com/ClassicOldSong/Apollo).

[AutoHotKey](https://github.com/AutoHotkey) For making of this amazing tool [AHK](https://autohotkey.com/) FOSS AND AVAILABLE FOR FREE!.

Everyone at [AHK Forums](https://www.autohotkey.com/boards/) for their contributions.

[@CCCC-L](https://github.com/CCCC-L) For the [AHK v2 Actions template](https://github.com/CCCC-L/Action-Ahk2Exe).

[@alfvar](https://github.com/alfvar) For adding icon support commit in his repo [AHK v2 Actions template](https://github.com/alfvar/action-ahk2exe)
