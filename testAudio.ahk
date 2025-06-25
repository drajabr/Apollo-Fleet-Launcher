#Requires AutoHotkey v2.0
#include ./lib/exAudio.ahk

class ApolloAudioManager {
    static GetAllSessions() {
        de := IMMDeviceEnumerator()
        IMMD := de.GetDefaultAudioEndpoint()
        se := IMMD.Activate(IAudioSessionManager2).GetSessionEnumerator()
        
        allSessions := []
        
        loop se.GetCount() {
            sc := se.GetSession(A_Index - 1).QueryInterface(IAudioSessionControl2)
            
            ; Get session state for display purposes
            ; AudioSessionState: 0=Inactive, 1=Active, 2=Expired
            sessionState := sc.GetState()
            stateText := ""
            switch sessionState {
                case 0: stateText := "Inactive"
                case 1: stateText := "Active"
                case 2: stateText := "Expired"
                default: stateText := "Unknown (" . sessionState . ")"
            }
            
            ; Include all sessions regardless of state (remove the state filter)
            pid := sc.GetProcessId()
            processName := ""
            
            ; Get process name
            try {
                wmi := ComObjGet("winmgmts:\\.\root\cimv2")
                for Process in wmi.ExecQuery("SELECT * FROM Win32_Process WHERE ProcessId = " pid) {
                    processName := Process.Name
                    break
                }
            } catch {
                try {
                    processName := ProcessGetName(pid)
                } catch {
                    processName := "Unknown"
                }
            }
            
            ; Get volume info
            try {
                sav := sc.QueryInterface(ISimpleAudioVolume)
                volume := Round(sav.GetMasterVolume() * 100, 2)
                muted := sav.GetMute()
                
                sessionInfo := {
                    PID: pid,
                    ProcessName: processName,
                    Volume: volume,
                    Muted: muted,
                    State: sessionState,
                    StateText: stateText,
                    SessionControl: sc,
                    SimpleAudioVolume: sav
                }
                
                allSessions.Push(sessionInfo)
            } catch {
                ; Even if we can't get volume interface, still add basic info
                sessionInfo := {
                    PID: pid,
                    ProcessName: processName,
                    Volume: "N/A",
                    Muted: "N/A",
                    State: sessionState,
                    StateText: stateText,
                    SessionControl: sc,
                    SimpleAudioVolume: ""
                }
                allSessions.Push(sessionInfo)
            }
        }
        
        return allSessions
    }
    
    ; Keep the old method name for backward compatibility, but now it gets all sessions
    static GetPlayingSessions() {
        return this.GetAllSessions()
    }
    
    ; Get only active sessions (playing audio)
    static GetActiveSessions() {
        allSessions := this.GetAllSessions()
        activeSessions := []
        
        for session in allSessions {
            if (session.State = 1) {  ; Only active sessions
                activeSessions.Push(session)
            }
        }
        
        return activeSessions
    }
    
    ; Get sessions by specific state
    static GetSessionsByState(targetState) {
        allSessions := this.GetAllSessions()
        filteredSessions := []
        
        for session in allSessions {
            if (session.State = targetState) {
                filteredSessions.Push(session)
            }
        }
        
        return filteredSessions
    }
    
    static GetApolloSessions() {
        allSessions := this.GetAllSessions()
        apolloSessions := []
        
        for session in allSessions {
            ; Case-insensitive check for "Apollo" in process name
            if (InStr(StrLower(session.ProcessName), "apollo")) {
                apolloSessions.Push(session)
            }
        }
        
        return apolloSessions
    }
    
    static SetApolloVolume(volume) {
        apolloSessions := this.GetApolloSessions()
        success := 0
        
        for session in apolloSessions {
            ; Skip sessions without volume control
            if (session.SimpleAudioVolume = "") {
                continue
            }
            
            try {
                ; Handle relative volume changes
                if (Type(volume) = "String" && (volume ~= "^[+-]")) {
                    newVolume := session.Volume + Integer(volume)
                } else {
                    newVolume := volume
                }
                
                ; Clamp volume between 0-100
                newVolume := Min(Max(newVolume, 0), 100)
                
                ; Set the volume
                session.SimpleAudioVolume.SetMasterVolume(newVolume / 100)
                success++
            } catch {
                continue
            }
        }
        
        return success  ; Returns number of Apollo sessions that were successfully modified
    }
    
    static GetApolloVolume() {
        apolloSessions := this.GetApolloSessions()
        volumes := []
        
        for session in apolloSessions {
            volumes.Push({
                PID: session.PID,
                ProcessName: session.ProcessName,
                Volume: session.Volume,
                Muted: session.Muted,
                State: session.StateText
            })
        }
        
        return volumes
    }
    
    static MuteApollo(mute := true) {
        apolloSessions := this.GetApolloSessions()
        success := 0
        
        for session in apolloSessions {
            ; Skip sessions without volume control
            if (session.SimpleAudioVolume = "") {
                continue
            }
            
            try {
                session.SimpleAudioVolume.SetMute(mute)
                success++
            } catch {
                continue
            }
        }
        
        return success
    }
    
    static ToggleApolloMute() {
        apolloSessions := this.GetApolloSessions()
        success := 0
        
        for session in apolloSessions {
            ; Skip sessions without volume control
            if (session.SimpleAudioVolume = "") {
                continue
            }
            
            try {
                currentMute := session.SimpleAudioVolume.GetMute()
                session.SimpleAudioVolume.SetMute(!currentMute)
                success++
            } catch {
                continue
            }
        }
        
        return success
    }
    
    ; Display all audio sessions (including inactive, active, expired)
    static ShowAllSessions() {
        sessions := this.GetAllSessions()
        
        if (sessions.Length = 0) {
            MsgBox("No audio sessions found.")
            return
        }
        
        output := "All Audio Sessions:`n`n"
        for session in sessions {
            output .= "Process: " . session.ProcessName . "`n"
            output .= "PID: " . session.PID . "`n"
            output .= "State: " . session.StateText . "`n"
            output .= "Volume: " . session.Volume . (session.Volume != "N/A" ? "%" : "") . "`n"
            output .= "Muted: " . (session.Muted = "N/A" ? "N/A" : (session.Muted ? "Yes" : "No")) . "`n"
            output .= "------------------------`n"
        }
        
        MsgBox(output, "All Audio Sessions")
    }
    
    ; Display only active sessions (backward compatibility)
    static ShowPlayingSessions() {
        sessions := this.GetActiveSessions()
        
        if (sessions.Length = 0) {
            MsgBox("No active audio sessions found.")
            return
        }
        
        output := "Currently Active Audio Sessions:`n`n"
        for session in sessions {
            output .= "Process: " . session.ProcessName . "`n"
            output .= "PID: " . session.PID . "`n"
            output .= "Volume: " . session.Volume . "%`n"
            output .= "Muted: " . (session.Muted ? "Yes" : "No") . "`n"
            output .= "------------------------`n"
        }
        
        MsgBox(output, "Active Audio Sessions")
    }
    
    ; Display only Apollo sessions
    static ShowApolloSessions() {
        sessions := this.GetApolloSessions()
        
        if (sessions.Length = 0) {
            MsgBox("No Apollo audio sessions found.")
            return
        }
        
        output := "Apollo Audio Sessions:`n`n"
        for session in sessions {
            output .= "Process: " . session.ProcessName . "`n"
            output .= "PID: " . session.PID . "`n"
            output .= "State: " . session.StateText . "`n"
            output .= "Volume: " . session.Volume . (session.Volume != "N/A" ? "%" : "") . "`n"
            output .= "Muted: " . (session.Muted = "N/A" ? "N/A" : (session.Muted ? "Yes" : "No")) . "`n"
            output .= "------------------------`n"
        }
        
        MsgBox(output, "Apollo Audio Sessions")
    }
    
    ; New method to show sessions by state
    static ShowSessionsByState(targetState) {
        sessions := this.GetSessionsByState(targetState)
        stateNames := Map(0, "Inactive", 1, "Active", 2, "Expired")
        stateName := stateNames.Has(targetState) ? stateNames[targetState] : "Unknown"
        
        if (sessions.Length = 0) {
            MsgBox("No " . stateName . " audio sessions found.")
            return
        }
        
        output := stateName . " Audio Sessions:`n`n"
        for session in sessions {
            output .= "Process: " . session.ProcessName . "`n"
            output .= "PID: " . session.PID . "`n"
            output .= "Volume: " . session.Volume . (session.Volume != "N/A" ? "%" : "") . "`n"
            output .= "Muted: " . (session.Muted = "N/A" ? "N/A" : (session.Muted ? "Yes" : "No")) . "`n"
            output .= "------------------------`n"
        }
        
        MsgBox(output, stateName . " Audio Sessions")
    }
}

; Example usage functions
ShowAllAudioSessions() {
    ApolloAudioManager.ShowAllSessions()
}

ShowActiveAudioSessions() {
    ApolloAudioManager.ShowPlayingSessions()  ; This now shows only active sessions
}

ShowInactiveAudioSessions() {
    ApolloAudioManager.ShowSessionsByState(0)  ; Show inactive sessions
}

ShowExpiredAudioSessions() {
    ApolloAudioManager.ShowSessionsByState(2)  ; Show expired sessions
}

ShowAllPlayingAudio() {
    ApolloAudioManager.ShowPlayingSessions()
}

ShowApolloAudio() {
    ApolloAudioManager.ShowApolloSessions()
}

SetApolloVolume(volume) {
    count := ApolloAudioManager.SetApolloVolume(volume)
    MsgBox("Set volume for " . count . " Apollo session(s) to " . volume . "%")
}

GetApolloVolume() {
    volumes := ApolloAudioManager.GetApolloVolume()
    if (volumes.Length = 0) {
        MsgBox("No Apollo sessions found")
        return
    }
    
    output := "Apollo Volume Levels:`n`n"
    for vol in volumes {
        output .= vol.ProcessName . " (PID: " . vol.PID . "): " . vol.Volume . (vol.Volume != "N/A" ? "%" : "") . " [" . vol.State . "]" . (vol.Muted = true ? " (Muted)" : vol.Muted = false ? "" : " (Mute: N/A)") . "`n"
    }
    MsgBox(output)
}

MuteApollo() {
    count := ApolloAudioManager.MuteApollo(true)
    MsgBox("Muted " . count . " Apollo session(s)")
}

UnmuteApollo() {
    count := ApolloAudioManager.MuteApollo(false)
    MsgBox("Unmuted " . count . " Apollo session(s)")
}

ToggleApolloMute() {
    count := ApolloAudioManager.ToggleApolloMute()
    MsgBox("Toggled mute for " . count . " Apollo session(s)")
}

; Example usage:

; Show all audio sessions (active, inactive, expired)
ApolloAudioManager.ShowAllSessions()

; Show only active sessions (the old behavior)
ApolloAudioManager.ShowPlayingSessions()

; Show only inactive sessions
ApolloAudioManager.ShowSessionsByState(0)

; Show only expired sessions  
ApolloAudioManager.ShowSessionsByState(2)

; Show Apollo sessions (all states)
ApolloAudioManager.ShowApolloSessions()

; Set Apollo volume to 50%
ApolloAudioManager.SetApolloVolume(50)

; Get Apollo volume levels (includes state info)
volumes := ApolloAudioManager.GetApolloVolume()

; Or use the helper functions:
ShowAllAudioSessions()     ; Shows all sessions regardless of state
ShowActiveAudioSessions()  ; Shows only active sessions
ShowInactiveAudioSessions() ; Shows only inactive sessions
SetApolloVolume(75)        ; Set Apollo to 75%
GetApolloVolume()          ; Show Apollo volume levels with state
MuteApollo()              ; Mute Apollo