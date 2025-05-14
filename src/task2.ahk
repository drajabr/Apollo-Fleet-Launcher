#Requires AutoHotkey v2.0
if !A_IsAdmin {
    MsgBox "Run this script as Administrator."
    ExitApp
}

taskName := "Test Task AHK"
ahkPath := A_AhkPath
scriptToRun := A_ScriptFullPath  ; This .ahk file will run on login
runCmd := Format('"{}" "{}"', ahkPath, scriptToRun)

cmd := Format('schtasks /Create /TN "{}" /TR {} /SC ONLOGON /RL HIGHEST /F', taskName, runCmd)
RunWait cmd, , "Hide"

MsgBox "Scheduled task created. It will run this same script on user logon."
