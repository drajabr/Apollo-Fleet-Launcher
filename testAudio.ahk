#Requires AutoHotkey v2.0
#include ./lib/exAudio.ahk

PIDsListFromExeName(name) {
    static wmi := ComObjGet("winmgmts:\\.\root\cimv2")
    if (name = "")
        return []
    PIDs := []
    for process in wmi.ExecQuery("SELECT * FROM Win32_Process WHERE Name = '" name "'")
        PIDs.Push(process.ProcessId)
    return PIDs
}

MsgBox(GetDeviceInfo())
pids := PIDsListFromExeName("sunshine.exe")

defaultAudioDevice := AudioDevice.GetDefault()
defaultDeviceID := GetDeviceID(defaultAudioDevice)

for pid in pids{
   appVol := AppVolume(pid, defaultDeviceID)
   if appVol.IsValid()
        MsgBox("pid: " pid " on device: " defaultAudioDevice.GetName() " status: " appVol.GetVolume())
}
