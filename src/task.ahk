;@Ahk2Exe-UpdateManifest 1 , Apollo Fleet Launcher
;@Ahk2Exe-SetMainIcon ../assets/9.ico
;@Ahk2Exe-SetName ApolloFleet
;@Ahk2Exe-SetDescription Manage Multiple Apollo Streaming Instances
;@Ahk2Exe-SetVersion 0.0.3
;@Ahk2Exe-SetCopyright Copyright 2025 @drajabr

MsgBox "Running as admin: " A_IsAdmin "`nPath: " A_ScriptFullPath

SetupFleetStartup() {
    taskName := "Apollo Fleet Launcher"
    exePath := A_ScriptFullPath

    if !A_IsAdmin {
        MsgBox "Please run this script as Administrator."
        ExitApp
    }

    if 1 {  ; Replace with savedSettings["Manager"].AutoLaunch
        if !TaskExists(taskName) {
            CreateScheduledTask(taskName, exePath)
        } else if !TaskEnabled(taskName) {
            EnableScheduledTask(taskName)
        }
    } else {
        if TaskExists(taskName) && TaskEnabled(taskName) {
            DisableScheduledTask(taskName)
        }
    }
}

GetLaunchCommand(scriptPath) {
    if SubStr(scriptPath, -3) = ".exe" {
        return '"' scriptPath '"'
    } else {
        ahkExe := A_AhkPath
        return Format('"{}" "{}"', ahkExe, scriptPath)
    }
}

TaskExists(name) {
    try {
        ts := ComObject("Schedule.Service")
        ts.Connect()
        folder := ts.GetFolder("\")
        folder.GetTask(name)
        return true
    } catch {
        return false
    }
}

TaskEnabled(name) {
    try {
        ts := ComObject("Schedule.Service")
        ts.Connect()
        folder := ts.GetFolder("\")
        task := folder.GetTask(name)
        return task.Definition.Settings.Enabled
    } catch {
        return false
    }
}

CreateScheduledTask(name, path) {
    runCmd := GetLaunchCommand(path)
    ; Escape quotes for schtasks
    runCmd := StrReplace(runCmd, '"', '\"')
    cmd := Format('schtasks /Create /TN "{1}" /TR "{2}" /SC ONLOGON /RL HIGHEST /F', name, runCmd)
    
    exitCode := RunWait(cmd, , "Hide")
    if exitCode != 0
        MsgBox "Failed to create scheduled task. Exit code: " exitCode "`nCommand: " cmd
}
EnableScheduledTask(name) {
    cmd := Format('schtasks /Change /TN "{1}" /ENABLE', name)
    RunWait cmd, , "Hide"
}

DisableScheduledTask(name) {
    cmd := Format('schtasks /Change /TN "{1}" /DISABLE', name)
    RunWait cmd, , "Hide"
}

; --- Run it ---
SetupFleetStartup()
