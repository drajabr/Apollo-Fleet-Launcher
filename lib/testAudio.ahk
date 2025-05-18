#Requires AutoHotkey v2.0
#SingleInstance Force
#Include ./lib/exAudio.ahk

OnAudioStateChange(Audio_Callback)


Audio_Callback(pid, bState) {
    ProcessName := pid = 0 ? "System Audio" : ProcessGetName(pid)

    Title := ""
    try Title := WinGetTitle("ahk_exe" ProcessName)

    MsgBox ProcessName " " (bState ? "started" : "stopped") " playing audio.`nTitle: " Title
}
Sleep (100000)