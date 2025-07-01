#Requires AutoHotkey v2.0
#SingleInstance Force

; Read command-line arguments
args := A_Args
if (args.Length < 3) {
    MsgBox "Usage: RunHidden.ahk exePath args workingDir [psexecPath]"
    ExitApp
}

exePath := args[1]
args := args[2]
workingDir := args[3]
psexecPath := args.Length >= 4 ? args[4] : A_ScriptDir "\bin\PsTools\PsExec64.exe"

; Get session ID
sessionId := DllCall("Kernel32.dll\WTSGetActiveConsoleSessionId")

; Build and run PsExec command
target := Format('"{1}" {2}', exePath, args)
fullCmd := Format('"{1}" -accepteula -i {2} -s cmd.exe /c start "" /B "{3}" {4}', psexecPath, sessionId, exePath, args)

consolePID := 0
Run(fullCmd, workingDir, "Hide", &consolePID)
Sleep(300)

; Find child process (your actual app)
servicePID := 0
for proc in ComObjGet("winmgmts:").ExecQuery("SELECT * FROM Win32_Process WHERE ParentProcessId=" consolePID) {
    if InStr(proc.CommandLine, exePath) && InStr(proc.CommandLine, args) {
        servicePID := proc.ProcessId
        break
    }
}

; Return PIDs as CSV (consolePID,servicePID)
FileAppend consolePID "," servicePID, "*"
ExitApp