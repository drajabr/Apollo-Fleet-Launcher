#Requires AutoHotkey v2.0

p := Map()

p.ADBTools := A_ScriptDir "\bin\platform-tools"
p.scrcpyExe := p.ADBTools "\scrcpy.exe"
p.adbExe := p.ADBTools "\adb.exe"

a := Map()
a.micID := "PE3SIL21060300042"

RunAndGetPIDs(exePath, args := "", workingDir := "", flags := "Hide") {
    consolePID := 0
	apolloPID := 0
	pids := []
    Run(
        A_ComSpec " /c " '"' exePath '"' . (args ? " " . args : ""),
        workingDir := workingDir ? workingDir : SubStr(exePath, 1, InStr(exePath, "\",, -1) - 1),
        flags,
        &consolePID
    )
	Sleep(1)
	for process in ComObject("WbemScripting.SWbemLocator").ConnectServer().ExecQuery("Select * from Win32_Process where ParentProcessId=" consolePID)
		if InStr(process.CommandLine, exePath) {
			apolloPID := process.ProcessId
			break
		}
		
	return [consolePID, apolloPID]
}


RunWait(p.adbExe ' -s ' a.micID ' shell input keyevent KEYCODE_WAKEUP', , 'Hide')
pids := RunAndGetPIDs(p.scrcpyExe, "-s " . a.MicID . " --no-video --no-window --audio-source=mic")
newPID := pids[1]
