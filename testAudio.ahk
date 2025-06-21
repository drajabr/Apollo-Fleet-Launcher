#Requires AutoHotkey v2.0
#SingleInstance Force
#Include ./lib/exAudio.ahk

OnAudioStateChange(Audio_Callback)


Audio_Callback(pid, bState) {
    ProcessName := pid = 0 ? "System Audio" : ProcessGetName(pid)

    Title := ""
    try Title := WinGetTitle(ProcessName)

    MsgBox ProcessName " " (bState ? "started" : "stopped") " playing audio.`nTitle: " Title
}


; Simple function to sync PIDs volume with system volume
SyncPIDsWithSystem(pids) {
    ; Static variables to track previous system state
    static lastSystemVolume := -1
    static lastSystemMute := -1
    
    ; Get current system volume and mute status
    systemDevice := AudioDevice.GetDefault()
    systemVolume := systemDevice.GetVolume()
    systemMute := systemDevice.GetMute()
    
    ; Check if system volume or mute status changed
    if (systemVolume == lastSystemVolume && systemMute == lastSystemMute) {
        return ; No change, skip sync
    }
    
    ; Update tracking variables
    lastSystemVolume := systemVolume
    lastSystemMute := systemMute
    
    ; Apply to each PID
    for pid in pids {
        try {
            appVol := AppVolume(pid)
            if appVol.ISAV { ; Check if we found a valid audio session
                appVol.SetVolume(systemVolume)
                appVol.SetMute(systemMute)
            }
        }
    }
}

; Usage examples:
; SyncPIDsWithSystem([1234, 5678, 9012])  ; Array of PIDs SyncPIDsWithSystem([ProcessExist("chrome.exe"), ProcessExist("spotify.exe")])

; If you want continuous syncing, you can set up a timer:
SetTimer(() => SyncPIDsWithSystem([ProcessExist("Apollo.exe")]), 1000)  ; Sync every second

Sleep (100000)