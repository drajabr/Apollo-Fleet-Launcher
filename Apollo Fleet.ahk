;@Ahk2Exe-UpdateManifest 1 , Apollo Fleet Launcher
;@Ahk2Exe-SetVersion 0.1.1
;@Ahk2Exe-SetName ApolloFleet
;@Ahk2Exe-SetMainIcon ./icons/9.ico
;@Ahk2Exe-SetDescription Manage Multiple Apollo Streaming Instances
;@Ahk2Exe-SetCopyright Copyright (C) 2025 @drajabr

#Requires Autohotkey v2

#Include ./lib/exAudio.ahk
#Include ./lib/JSON.ahk
#Include ./lib/StdOutToVar.ahk
#Include ./lib/DarkGuiHelpers.ahk

ConfRead(FilePath, Param := "") {
    ; Check if file exists
    if !FileExist(FilePath)
        throw Error("Config file not found: " . FilePath)

    confMap := Map()
    
    Loop Read, FilePath
    {
        line := Trim(A_LoopReadLine)
        ; Skip empty lines and comments
        if (line = "" || SubStr(line, 1, 1) = ";")
            continue
        
        ; Match "key = value" format
        if RegExMatch(line, "^\s*([^=]+?)\s*=\s*(.*)$", &match)
        {
            key := Trim(match[1])
            value := Trim(match[2])

            ; Remove surrounding brackets from arrays like [60]
            if (SubStr(value, 1, 1) = "[" && SubStr(value, -1) = "]") {
                value := SubStr(value, 2, -1)
            }
            confMap[key] := value
        }
    }
    
    return confMap
}

ConfWrite(configFile, configMap) {
	lines := ""
	for Key, Value in configMap
		lines .= Key " = " Value "`n"

	if FileExist(configFile) {
		if FileRead(configFile) = lines
			return false
		FileDelete(configFile)
	}

	FileAppend(lines, configFile)
	return true
}
ReadSettingsFile(Settings := Map(), File := "settings.ini", groups := "all") {
    for k in ["Transient", "Manager", "Window", "Paths", "Fleet", "Android"]
        if !Settings.Has(k)
            Settings[k] := (k = "Fleet" ? [] : {})

    if !FileExist(File)
        FileAppend("", File)

    ReadGroup(group) {
        switch group {
            case "Manager":
                m := Settings["Manager"]
                m.AutoStart := IniRead(File, "Manager", "AutoStart", 1) = "1"
                m.SyncVolume := IniRead(File, "Manager", "SyncVolume", 1) = "1"
                m.RemoveDisconnected := IniRead(File, "Manager", "RemoveDisconnected", 1)
                m.SyncSettings := IniRead(File, "Manager", "SyncSettings", 1) = "1"
                m.DarkTheme := IniRead(File, "Manager", "DarkMode", IsSystemDarkMode())
                m.ShowErrors := IniRead(File, "Manager", "ShowErrors", 1)

            case "Window":
                w := Settings["Window"]
                w.restorePosition := IniRead(File, "Window", "restorePosition", 1)
            case "Paths":
                p := Settings["Paths"]
                p.Apollo := IniRead(File, "Paths", "Apollo", "C:\Program Files\Apollo")
                p.Config := IniRead(File, "Paths", "Config", A_ScriptDir "\config")
                p.ADBTools := IniRead(File, "Paths", "ADB", A_ScriptDir "\bin\platform-tools")
                p.apolloExe := p.Apollo "\sunshine.exe"
				p.ApolloFound := FileExist(p.apolloExe)
                p.gnirehtetExe := p.ADBTools "\gnirehtet.exe"
                p.scrcpyExe := p.ADBTools "\scrcpy.exe"
                p.adbExe := p.ADBTools "\adb.exe"
                p.paexecExe := IniRead(File, "Paths", "paexecExe", A_ScriptDir "\bin\PaExec\paexec.exe")

            case "Android":
                a := Settings["Android"]
                a.ReverseTethering := IniRead(File, "Android", "ReverseTethering", 0) = "1"
                a.MicDeviceID := IniRead(File, "Android", "MicDeviceID", "Unset")
                a.MicEnable := (a.MicDeviceID = "Unset" ? 0 : 1) = "1"
                a.CamDeviceID := IniRead(File, "Android", "CamDeviceID", "Unset")
                a.CamEnable := (a.CamDeviceID = "Unset" ? 0 : 1) = "1"

            case "Fleet":
                Settings["Fleet"] := []
                f := Settings["Fleet"]
                configp := IniRead(File, "Paths", "Config", A_ScriptDir "\config")
                instanceNumber := 1
                for section in StrSplit(IniRead(File), "`n")
                    if (SubStr(section, 1, 8) = "Instance") {
                        i := {}
                        i.id := instanceNumber++
                        i.Name := IniRead(File, section, "Name", "i" . A_Index)
                        i.Port := IniRead(File, section, "Port", 11000 + A_Index * 1000)
                        i.Enabled := IniRead(File, section, "Enabled", 1) = "1"
                        i.configFile := configp "\fleet-" i.id ".conf"
                        i.logFile := configp "\fleet-" i.id ".log"
                        i.appsFile := configp "\apps-" i.id ".json"
                        i.stateFile := configp "\state-" i.id ".json"
                        i.AudioDevice := IniRead(File, section, "AudioDevice", "Unset")
                        i.AutoCaptureSink := i.AudioDevice = "Unset" ? "enabled" : "disabled"
						i.HeadlessModeSet := IniRead(File, section, "HeadlessModeSet", "enabled")
                        i.configChange := 0
                        f.Push(i)
                    }
                if f.Length = 0 {
                    i := { id: 1, Port: 11000, Name: "Instance 1", Enabled: 1, AudioDevice: "Unset" }
                    i.AutoCaptureSink := "enabled"
					i.HeadlessModeSet := "enabled"
                    i.configFile := configp "\fleet-1.conf"
                    i.logFile := configp "\fleet-1.log"
                    i.appsFile := configp "\apps-1.json"
                    i.stateFile := configp "\state-1.json"
                    i.configChange := 0
                    f.Push(i)
                }

            case "Transient":
                ; reserved for other use
        }
    }

    for g in ["Manager", "Window", "Paths", "Android", "Fleet", "Transient"]
        if (groups = "all" || InStr(groups, g))
            ReadGroup(g)
}
WriteIfChanged(file, section, key, value) {
	old := IniRead(file, section, key, "__MISSING__")
	if (old != value) {
		IniWrite(value, file, section, key)
		return 1
	}
	return 0
}
WriteSettingsFile(Settings := Map(), File := "settings.ini", groups := "all") {
	changed := 0
	if FileExist(File) {
		lastContents := FileRead(File)

		if (groups = "all" || InStr(groups, "Manager")) {
			m := Settings["Manager"]
			changed += WriteIfChanged(File, "Manager", "AutoStart", m.AutoStart)
			changed += WriteIfChanged(File, "Manager", "SyncVolume", m.SyncVolume)
			changed += WriteIfChanged(File, "Manager", "RemoveDisconnected", m.RemoveDisconnected)
			changed += WriteIfChanged(File, "Manager", "DarkTheme", m.DarkTheme)
			changed += WriteIfChanged(File, "Manager", "ShowErrors", m.ShowErrors)
		}

		if (groups = "all" || InStr(groups, "Window")) {
			w := Settings["Window"]
			changed += WriteIfChanged(File, "Window", "restorePosition", w.restorePosition)
		}

		if (groups = "all" || InStr(groups, "Paths")) {
			p := Settings["Paths"]
			changed += WriteIfChanged(File, "Paths", "Apollo", p.Apollo)
			changed += WriteIfChanged(File, "Paths", "Config", p.Config)
			changed += WriteIfChanged(File, "Paths", "ADB", p.ADBTools)
		}

		if (groups = "all" || InStr(groups, "Android")) {
			a := Settings["Android"]
			changed += WriteIfChanged(File, "Android", "ReverseTethering", a.ReverseTethering)
			changed += WriteIfChanged(File, "Android", "MicDeviceID", a.MicDeviceID)
			changed += WriteIfChanged(File, "Android", "CamDeviceID", a.CamDeviceID)
			changed += WriteIfChanged(File, "Android", "MicEnable", a.MicEnable)
			changed += WriteIfChanged(File, "Android", "CamEnable", a.CamEnable)
		}

		if (groups = "all" || InStr(groups, "Fleet")) {
			sections := IniRead(File)
			for section in StrSplit(sections, "`n") {
				section := Trim(section)
				if RegExMatch(section, "^Instance\d+$")
					IniDelete(File, section)
			}
			
			for i in Settings["Fleet"] {
				section := "Instance" i.id
				IniWrite(i.Name, File, section, "Name")
				IniWrite(i.Port, File, section, "Port") 
				IniWrite(i.Enabled, File, section, "Enabled")
				IniWrite(i.AudioDevice, File, section, "AudioDevice")
				IniWrite(i.HeadlessModeSet, File, section, "HeadlessModeSet")
			}
			changed += 1
		}

		if changed
			FileOpen(File, "a").Close()

	} else {
		FileAppend("", File)
		WriteSettingsFile(Settings, File, groups) ; Retry after file created
	}

	;while changed && (FileRead(File) = lastContents)
	;	Sleep 10
}

ReadTransientFile(transient := Map(), File := "transient.ini", groups := "all") {
	; Init default maps
	for k in ["Android", "Fleet", "Window"]
		if !transient.Has(k)
			transient[k] := (k = "Fleet" ? Map() : {})

	if !FileExist(File)
		FileAppend("", File)

	if (groups = "all" || InStr(groups, "Android")) {
		a := transient["Android"]
		a.gnirehtetPID := Integer(IniRead(File, "Transient", "gnirehtetPID", 0))
		a.scrcpyMicPID := Integer(IniRead(File, "Transient", "scrcpyMicPID", 0))
		a.scrcpyCamPID := Integer(IniRead(File, "Transient", "scrcpyCamPID", 0))
	}

	if (groups = "all" || InStr(groups, "Fleet")) {
		for line in StrSplit(IniRead(File, "Fleet",, ""), "`n")
			if RegExMatch(line, "Instance-(\d+)\s*=\s*(\d+)", &m){
				transient["Fleet"][Integer(m[1])] := Integer(m[2])
				;MsgBox("Read Fleet Instance-" m[1] " with PID: " m[2])
			}
	}

	if (groups = "all" || InStr(groups, "Window")) {
		w := transient["Window"]
		w.xPos := IniRead(File, "Window", "xPos", (A_ScreenWidth - 580) / 2)
		w.yPos := IniRead(File, "Window", "yPos", (A_ScreenHeight - 198) / 2)
		w.lastState := IniRead(File, "Window", "lastState", 1)
		w.logShow := IniRead(File, "Window", "logShow", 0)
		w.cmdReload := IniRead(File, "Window", "cmdReload", 0)
		w.cmdExit := IniRead(File, "Window", "cmdExit", 0)
		w.cmdApply := IniRead(File, "Window", "cmdApply", 0)
	}
	return transient
}

WriteTransientFile(groups := "all") {
	global transientSettings
	File := "transient.ini"

	if FileExist(File) {
		if (groups = "all" || InStr(groups, "Android")) {
			r := transientSettings["Android"]
			IniWrite(r.GnirehtetPID, File, "Android", "GnirehtetPID")
			IniWrite(r.scrcpyMicPID, File, "Android", "scrcpyMicPID")
			IniWrite(r.scrcpyCamPID, File, "Android", "scrcpyCamPID")
		}

		if (groups = "all" || InStr(groups, "Fleet")) {
			IniDelete(File, "Fleet")
			for id, pid in transientSettings["Fleet"] {
				;MsgBox("Writing Fleet Instance-" id " with PID: " pid)
				IniWrite(pid, File, "Fleet", "Instance-" id)
			}
		}

		if (groups = "all" || InStr(groups, "Window")) {
			w := transientSettings["Window"]
			IniWrite(w.xPos, File, "Window", "xPos")
			IniWrite(w.yPos, File, "Window", "yPos")
			IniWrite(w.lastState, File, "Window", "lastState")
			IniWrite(w.logShow, File, "Window", "logShow")
			IniWrite(w.cmdReload, File, "Window", "cmdReload")
			IniWrite(w.cmdExit, File, "Window", "cmdExit")
			IniWrite(w.cmdApply, File, "Window", "cmdApply")

		}
	} else {
		FileAppend("", File)
		WriteTransientFile(groups)
	}
}



InitmyGui() {
	global savedSettings

	global myGui, guiItems := Map()
	if !A_IsCompiled {
		TraySetIcon("./icons/9.ico")
	}
	myGui := Gui("+AlwaysOnTop -SysMenu")

	guiItems["ButtonLockSettings"] := myGui.Add("Button", "x520 y5 w50 h40", "🔒")
	guiItems["ButtonReload"] := myGui.Add("Button", "x520 y50 w50 h40", "Reload")
	guiItems["ButtonLogsShow"] := myGui.Add("Button", "x520 y101 w50 h40", "Show Logs")
	guiItems["ButtonMinimize"] := myGui.Add("Button", "x520 y150 w50 h40", "Minimize")
	guiItems["ButtonReload"].Enabled := 0
	guiItems["ButtonLockSettings"].Enabled := 0

	myGui.Add("GroupBox", "x318 y0 w196 h90", "Fleet Options")
	guiItems["FleetAutoStartCheckBox"] := myGui.Add("CheckBox", "x334 y21 w162 h21", "Auto Start Apollo Fleet")
	guiItems["FleetSyncVolCheckBox"] := myGui.Add("CheckBox", "x334 y43 w162 h21", "Sync Device Volume Level")
	guiItems["FleetRemoveDisconnectCheckbox"] := myGui.Add("CheckBox", "x334 y65 w167 h21", "Remove on Disconnect")

	myGui.Add("GroupBox", "x318 y96 w196 h95", "Android Clients")
	guiItems["AndroidReverseTetheringCheckbox"] := myGui.Add("CheckBox", "x334 y116 w139 h21", "ADB Reverse Tethering")
	guiItems["AndroidMicCheckbox"] := myGui.Add("CheckBox", "x334 y140 ", "Mic:")
	presetAndroidDevices := ["Unset"]
	if savedSettings["Android"].MicDeviceID != "Unset" 
		presetAndroidDevices.Push(savedSettings["Android"].MicDeviceID)
	if savedSettings["Android"].CamDeviceID != "Unset" && savedSettings["Android"].CamDeviceID != savedSettings["Android"].MicDeviceID
		presetAndroidDevices.Push(savedSettings["Android"].CamDeviceID)
	guiItems["AndroidMicSelector"] := myGui.Add("DropDownList", "x382 y136 w122 Choose1", presetAndroidDevices)
	guiItems["AndroidCamCheckbox"] := myGui.Add("CheckBox", "x334 y164 ", "Cam:")
	guiItems["AndroidCamSelector"] := myGui.Add("DropDownList", "x382 y160 w122 Choose1", presetAndroidDevices)

	myGui.Add("GroupBox", "x8 y0 w300 h192", "Fleet")
	myGui.Add("Text", "x16 y21", "Apollo Folder:")
	guiItems["PathsApolloBox"] := myGui.Add("Edit", "x85 y17 w190 h21")
	myGui.SetFont("s14")
	guiItems["PathsApolloIndicator"] := myGui.Add("Text", "x278 y15", "⚠️")
	myGui.SetFont()

	guiItems["FleetListBox"] := myGui.Add("ListBox", "x16 y50 w100 h82 +0x100 Choose1")
	guiItems["FleetListBox"].Enabled := 0
	myGui.Add("Text", "x123 y54", "Name:Port")
	guiItems["InstanceNameBox"] := myGui.Add("Edit", "x176 y51 w80 h21")
	guiItems["InstancePortBox"] := myGui.Add("Edit", "x256 y51 w40 h21")

	presetAudioDevices := ["Unset"]
	for i in savedSettings["Fleet"]
		if !presetAudioDevices.Has(i.AudioDevice)
			presetAudioDevices.Push(i.AudioDevice)
	myGui.Add("Text", "x123 y76", "Audio :")
	guiItems["InstanceAudioSelector"] := myGui.Add("DropDownList", "x176 y74 w120 Choose1", presetAudioDevices)

	myGui.Add("Text", "x123 y100 ", "Enabled:")
	guiItems["InstanceEnableCheckbox"] := myGui.Add("CheckBox", "x176 y100", "Status will appear here")
	
	myGui.Add("Text", "x123 y120 ", "Headless:")
	guiItems["InstanceHeadlessCheckbox"] := myGui.Add("CheckBox", "x176 y120", "Force Headless Mode")

	myGui.Add("Text", "x123 y144  ", "WebUI:")
	myLink := "https://localhost:00000"
	guiItems["FleetLinkBox"] := myGui.Add("Link", "x176 y144", '<a href="' . myLink . '">' . myLink . '</a>')

	guiItems["FleetButtonAdd"] := myGui.Add("Button", "x43 y139 w74 h21", "Add")
	guiItems["FleetButtonDelete"] := myGui.Add("Button", "x15 y139 w26 h21", "✖")

	guiItems["StatusApollo"] := myGui.Add("Text", "x16 y172 w70", "❎ Apollo ")
	guiItems["StatusGnirehtet"] := myGui.Add("Text", "x76 y172 w70", "❎ Gnirehtet")
	guiItems["StatusAndroidMic"] := myGui.Add("Text", "x146 y172 w75", "❎ AndroidMic")
	guiItems["StatusAndroidCam"] := myGui.Add("Text", "x226 y172 w75", "❎ AndroidCam")
	guiItems["StatusMessage"] := myGui.Add("Text", "x16 y172 w290")
	ShowMessage("Initialized All GUI Elements")

	guiItems["LogTextBox"] := myGui.Add("Edit", "x8 y199 w562 h393 -VScroll +ReadOnly")
	myGui.Title := "Apollo Fleet Manager"

	if savedSettings["Manager"].DarkTheme {
		EnableDarkMode(myGui, guiItems)
		SetWindowAttribute(myGui, true)
		SetWindowTheme(myGui, true)
		SetSysLinkColor(guiItems["FleetLinkBox"])
	}
}

SetSysLinkColor(linkObj) {
	; Thanks for @teadrinker https://www.autohotkey.com/boards/viewtopic.php?t=114011
	static LM_SETITEM := 0x702, mask := (LIF_ITEMINDEX := 0x1) | (LIF_STATE := 0x2), LIS_DEFAULTCOLORS := 0x10
	LITEM := Buffer(16, 0)
	NumPut('Int64', mask, 'Int64', LIS_DEFAULTCOLORS|(LIS_DEFAULTCOLORS << 32), LITEM)
	while SendMessage(LM_SETITEM,, LITEM, linkObj)
		NumPut('Int', A_Index, LITEM, 4)
}

EnableDarkMode(gui, guiItems) {
    ; Replace CheckBoxes with dark ones
    for k, ctrl in guiItems {
        if ctrl.Type = "CheckBox" {
            rect := GuiControlGetPos(ctrl)
            txt := ctrl.Text
            val := ctrl.Value
            ctrl.Visible := false
            ctrl.Opt("+Disabled")
            opts := Format("x{} y{} w{} h{}", rect.x, rect.y, rect.w, rect.h)
            guiItems[k] := AddDarkCheckBox(gui, opts, txt)
            guiItems[k].Value := val
        }
    }

    ; Manually re-add GroupBoxes as dark versions
    AddDarkGroupBox(gui, "x318 y0 w196 h90", "Fleet Options")
    AddDarkGroupBox(gui, "x318 y96 w196 h95", "Android Clients")
    AddDarkGroupBox(gui, "x8 y0 w300 h192", "Fleet")
}
GuiControlGetPos(ctrl) {
    rect := Buffer(16, 0)
    DllCall("GetWindowRect", "ptr", ctrl.hwnd, "ptr", rect.Ptr)
    x := NumGet(rect, 0, "int")
    y := NumGet(rect, 4, "int")
    w := NumGet(rect, 8, "int") - x
    h := NumGet(rect, 12, "int") - y

    pt := Buffer(8)
    NumPut("int", x, pt, 0)
    NumPut("int", y, pt, 4)
    DllCall("ScreenToClient", "ptr", ctrl.Gui.Hwnd, "ptr", pt.Ptr)

    return {x: NumGet(pt, 0, "int"), y: NumGet(pt, 4, "int"), w: w, h: h}
}
InitTray(){
	global myGui
	A_TrayMenu.Delete()
	A_TrayMenu.Add("Open Manager", (*) => RestoremyGui() )
	A_TrayMenu.Add("Reload", (*) => HandleReloadButton())
	A_TrayMenu.Add()
	A_TrayMenu.Add("Exit", (*) => ExitMyApp())
}
ReflectSettings(Settings){
	global myGui, guiItems
	a := Settings["Android"]
	m := Settings["Manager"]
	f := Settings["Fleet"]
	guiItems["FleetAutoStartCheckBox"].Value := m.AutoStart
	guiItems["FleetSyncVolCheckBox"].Value := m.SyncVolume
	guiItems["FleetRemoveDisconnectCheckbox"].Value := m.RemoveDisconnected
	guiItems["AndroidReverseTetheringCheckbox"].Value := a.ReverseTethering
	guiItems["AndroidMicCheckbox"].Value := a.MicEnable
	guiItems["AndroidMicSelector"].Text := a.MicDeviceID
	guiItems["AndroidCamCheckbox"].Value := a.CamEnable
	guiItems["AndroidCamSelector"].Text := a.CamDeviceID
	guiItems["PathsApolloBox"].Value := Settings["Paths"].Apollo
	guiItems["ButtonLogsShow"].Text := (transientSettings["Window"].logShow = 1 ? "Hide Logs" : "Show Logs")
	;guiItems["InstanceAudioSelector"].Enabled :=0
	guiItems["FleetListBox"].Delete()
	guiItems["FleetListBox"].Add(EveryInstanceProp(Settings))
	instanceCount := Settings["Fleet"].Length
	valid := currentlySelectedIndex > 0 && currentlySelectedIndex <= userSettings["Fleet"].Length 
	guiItems["InstanceNameBox"].Value := valid ? Settings["Fleet"][currentlySelectedIndex].Name : ""
	guiItems["InstancePortBox"].Value := valid ? Settings["Fleet"][currentlySelectedIndex].Port : ""
	guiItems["InstanceEnableCheckbox"].Value := valid ? f[currentlySelectedIndex].Enabled : 0
	guiItems["InstanceHeadlessCheckbox"].Value := valid ? (f[currentlySelectedIndex].HeadlessModeSet = "enabled") : 0
	port := valid ?  userSettings["Fleet"][currentlySelectedIndex].Port+1 : 00000
	myLink := "https://localhost:" . port
	guiItems["FleetLinkBox"].Text :=  '<a href="' . myLink . '">' . myLink . '</a>'
	SetSysLinkColor(guiItems["FleetLinkBox"])

	guiItems["InstanceAudioSelector"].Text := valid ? f[currentlySelectedIndex].AudioDevice : "Unset"
	UpdateButtonsLabels()
}
EveryInstanceProp(Settings, prop:="Name"){
	isList := []  ; Create an empty array
	for i in Settings["Fleet"] 
		isList.Push(i.%prop%)  ; Add the Name property to the array
	return isList
}
InitGuiItemsEvents(){
	global myGui, guiItems
	myGui.OnEvent('Close', (*) => ExitMyApp())
	OnMessage(0x0003, UpdateWindowPosition)
	guiItems["ButtonMinimize"].OnEvent("Click", MinimizemyGui)
	guiItems["ButtonLockSettings"].OnEvent("Click", HandleLockButton)
	guiItems["ButtonReload"].OnEvent("Click", HandleReloadButton)
	guiItems["ButtonLogsShow"].OnEvent("Click", HandleLogsButton)
	guiItems["FleetListBox"].OnEvent("Change", HandleListChange)

	guiItems["AndroidReverseTetheringCheckbox"].OnEvent("Click", HandleCheckBoxes) ; (*) => userSettings["Android"].ReverseTethering := guiItems["AndroidReverseTetheringCheckbox"].Value)
	guiItems["AndroidMicCheckbox"].OnEvent("Click", HandleMicCheckBox)
	guiItems["AndroidCamCheckbox"].OnEvent("Click", HandleCamCheckBox)
	guiItems["AndroidMicSelector"].OnEvent("Change", HandleMicSelector)
	guiItems["AndroidCamSelector"].OnEvent("Change", HandleCamSelector)

	guiItems["FleetAutoStartCheckBox"].OnEvent("Click", HandleCheckBoxes) ; (*) => userSettings["Manager"].AutoStart := guiItems["FleetAutoStartCheckBox"].Value)
	guiItems["FleetSyncVolCheckBox"].OnEvent("Click", HandleCheckBoxes) ;(*) => userSettings["Manager"].SyncVolume := guiItems["FleetSyncVolCheckBox"].Value)
	guiItems["FleetRemoveDisconnectCheckbox"].OnEvent("Click", HandleCheckBoxes) ;(*) => userSettings["Manager"].RemoveDisconnected := guiItems["FleetRemoveDisconnectCheckbox"].Value)
	guiItems["InstanceEnableCheckbox"].OnEvent("Click", HandleCheckBoxes)
	guiItems["InstanceHeadlessCheckbox"].OnEvent("Click", HandleCheckBoxes)

	guiItems["FleetButtonAdd"].OnEvent("Click", HandleInstanceAddButton)
	guiItems["FleetButtonDelete"].OnEvent("Click", HandleInstanceDeleteButton)

	guiItems["InstanceNameBox"].OnEvent("Change", HandleNameChange)
	guiItems["InstancePortBox"].OnEvent("Change", HandlePortChange)
	guiItems["InstancePortBox"].OnEvent("Change", StrictPortLimits)
	guiItems["InstanceAudioSelector"].OnEvent("Change", HandleAudioSelector)

	guiItems["PathsApolloBox"].OnEvent("Change", HandlePathChange)

	OnMessage(0x404, TrayIconHandler)
	guiItems["FleetListBox"].Enabled := 1
	guiItems["ButtonReload"].Enabled := 1
	guiItems["ButtonLockSettings"].Enabled := 1
}
CheckApolloFound(){
	global guiItems, userSettings
	path := guiItems["PathsApolloBox"].Value
	if !FileExist(path . "\sunshine.exe") {
		guiItems["PathsApolloIndicator"].Text := "⚠️"
		ShowMessage("Apollo not found in selected folder", 3)
		userSettings["Paths"].ApolloFound := 0
		return false
	}
	guiItems["PathsApolloIndicator"].Text := "✅"
	userSettings["Paths"].Apollo := path
	guiItems["PathsApolloBox"].Value := path
	userSettings["Paths"].ApolloFound := 1
	return true
}
HandlePathChange(*){
	global guiItems, userSettings
	path := guiItems["PathsApolloBox"].Value
	if !CheckApolloFound()
		return
	userSettings["Paths"].Apollo := path
	guiItems["PathsApolloBox"].Value := path
}	
CheckAdbRefresh(){
	userRequire := userSettings["Android"].MicEnable || userSettings["Android"].CamEnable
	if userRequire && !adbReady
		bootstrapAndroid()
}
HandleMicCheckBox(*) {
	global userSettings, guiItems

	guiItems["AndroidMicSelector"].Enabled := guiItems["AndroidMicCheckbox"].Value
	userSettings["Android"].MicEnable := guiItems["AndroidMicCheckbox"].Value
	CheckAdbRefresh()
	RefreshAdbSelectors("Mic")
	UpdateButtonsLabels()
}
HandleMicSelector(*) {
	global userSettings, androidDevicesList
	userSettings["Android"].MicDeviceID := guiItems["AndroidMicSelector"].Text
	if guiItems["AndroidMicSelector"].Text = "Unset"
		guiItems["AndroidMicCheckbox"].Value := 0
	else
		guiItems["AndroidMicCheckbox"].Value := 1
	UpdateButtonsLabels()
}
HandleCamCheckBox(*) {
	global userSettings, guiItems

	guiItems["AndroidCamSelector"].Enabled := guiItems["AndroidCamCheckbox"].Value
	userSettings["Android"].CamEnable := guiItems["AndroidCamCheckbox"].Value
	
	CheckAdbRefresh()
	RefreshAdbSelectors("Cam")
	UpdateButtonsLabels()
}
HandleCamSelector(*) {
	global userSettings, androidDevicesList
	userSettings["Android"].CamDeviceID := guiItems["AndroidCamSelector"].Text
	if guiItems["AndroidCamSelector"].Text = "Unset"
		guiItems["AndroidCamCheckbox"].Value := 0
	else
		guiItems["AndroidCamCheckbox"].Value := 1
	UpdateButtonsLabels()
}

HandleAudioSelector(*){
	global userSettings, currentlySelectedIndex
	valid := currentlySelectedIndex > 0 && currentlySelectedIndex <= userSettings["Fleet"].Length 
	currentlySelectedIndex := valid ? currentlySelectedIndex : 1
	i := userSettings["Fleet"][currentlySelectedIndex]
	i.AudioDevice := guiItems["InstanceAudioSelector"].Text
	UpdateButtonsLabels()
}
RefreshAudioSelector(*){
	global guiItems, audioDevicesList, currentlySelectedIndex
	valid := currentlySelectedIndex > 0 && currentlySelectedIndex <= userSettings["Fleet"].Length 
	currentlySelectedIndex := valid ? currentlySelectedIndex : 1
	selection := userSettings["Fleet"][currentlySelectedIndex].AudioDevice
	audioDevicesList := ["Unset"]
	for dev in AudioDevice.GetAll()
		audioDevicesList.Push(dev.GetName())

	guiItems["InstanceAudioSelector"].Delete()
	guiItems["InstanceAudioSelector"].Add(audioDevicesList)
	guiItems["InstanceAudioSelector"].Text :=  ArrayHas(audioDevicesList, selection) ? selection : "Unset"
}
StrictPortLimits(*){
	p := guiItems["InstancePortBox"]
	if !IsNumber(p.Value)
		p.Value := 10000
	else if p.Value < 0
		p.Value := 10000
	else if p.Value > 65000
		p.Value := 65000
}
TrayIconHandler(wParam, lParam, msg, hwnd) {
	global myGui
    if (lParam = 0x202)  ; Left click tray icon
    {
        if DllCall("IsWindowVisible", "ptr", myGui.Hwnd)
            MinimizemyGui()
        else
            RestoremyGui()
    }
}
HandleCheckBoxes(*) {
	global userSettings, guiItems, currentlySelectedIndex
	userSettings["Android"].ReverseTethering := guiItems["AndroidReverseTetheringCheckbox"].Value
	userSettings["Manager"].AutoStart := guiItems["FleetAutoStartCheckBox"].Value
	userSettings["Manager"].SyncVolume := guiItems["FleetSyncVolCheckBox"].Value
	userSettings["Manager"].RemoveDisconnected := guiItems["FleetRemoveDisconnectCheckbox"].Value
	valid := currentlySelectedIndex > 0 && currentlySelectedIndex <= userSettings["Fleet"].Length 
	currentlySelectedIndex := valid ? currentlySelectedIndex : 1
	i := userSettings["Fleet"][currentlySelectedIndex]
	i.Enabled := guiItems["InstanceEnableCheckbox"].Value
	i.HeadlessModeSet := guiItems["InstanceHeadlessCheckbox"].Value ? "enabled" : "disabled"
	UpdateButtonsLabels()
}
RefreshFleetList(){
	global guiItems, userSettings, currentlySelectedIndex, transientSettings
	valid := currentlySelectedIndex > 0 && currentlySelectedIndex <= userSettings["Fleet"].Length 
	currentlySelectedIndex := valid ? currentlySelectedIndex : 1
	guiItems["FleetListBox"].Delete()
	guiItems["FleetListBox"].Add(EveryInstanceProp(userSettings))
	guiItems["FleetListBox"].Choose(currentlySelectedIndex)
	Loop userSettings["Fleet"].Length {
		userSettings["Fleet"][A_Index].id := A_Index
	}
	UpdateButtonsLabels()
}
HandlePortChange(*){
	global userSettings, guiItems, currentlySelectedIndex
	valid := currentlySelectedIndex > 0 && currentlySelectedIndex <= userSettings["Fleet"].Length 
	currentlySelectedIndex := valid ? currentlySelectedIndex : 1
	i := userSettings["Fleet"][currentlySelectedIndex]
	newPort := guiItems["InstancePortBox"].Value = "" ? i.Port : guiItems["InstancePortBox"].Value 
	valid := 0
	try 
		valid := (1024 < newPort && newPort < 65000) ? 1 : 0
	for otherI in userSettings["Fleet"]
		if otherI.id != i.id
			if (otherI.Port = newPort)
				valid := 0
	if valid {
		i.Port := newPort
		myLink := "https://localhost:" . i.Port + 1
		guiItems["FleetLinkBox"].Text :=  '<a href="' . myLink . '">' . myLink . '</a>'	
		SetSysLinkColor(guiItems["FleetLinkBox"])

	} else {
		guiItems["InstancePortBox"].Value := userSettings["Fleet"][currentlySelectedIndex].Port
	}
	UpdateButtonsLabels()
}
HandleNameChange(*){
	global userSettings, guiItems, currentlySelectedIndex
	valid := currentlySelectedIndex > 0 && currentlySelectedIndex <= userSettings["Fleet"].Length 
	currentlySelectedIndex := valid ? currentlySelectedIndex : 1
	newName := guiItems["InstanceNameBox"].Value
	userSettings["Fleet"][currentlySelectedIndex].Name := newName
	RefreshFleetList()
}
HandleInstanceAddButton(*){
	global userSettings, guiItems, currentlySelectedIndex
	f := userSettings["Fleet"]
	if (f.Length > 5){
		ShowMessage("Let's not add more than 5 is for now.", 3)
	} else {
	i := {} ; Create a new object for each i
	i.id := f.Length + 1
	configp := userSettings["Paths"].Config
	i.Port := i.id = 1 ? 11000 : f[-1].port + 1000
	i.Name := "Instance " . i.id
	i.Enabled := 1
	i.AudioDevice := "Unset"
	i.AutoCaptureSink := i.AudioDevice = "Unset" ? "enabled" : "disabled"
	i.HeadlessModeSet := "enabled"
	i.configFile := configp "\fleet-" i.id ".conf"
	i.logFile := configp "\fleet-" i.id ".log"
	i.stateFile :=  configp "\state-" i.id ".json"
	i.appsFile := configp "\apps-" i.id ".json"
	i.stateFile := configp "\state-" i.id ".json"	
	userSettings["Fleet"].Push(i)
	currentlySelectedIndex := userSettings["Fleet"].Length
	RefreshFleetList()
	HandleListChange()
	}
}
HandleInstanceDeleteButton(*){ 
	global userSettings, guiItems, currentlySelectedIndex
	if (userSettings["Fleet"].Length > 1){
		userSettings["Fleet"].RemoveAt(currentlySelectedIndex)
		currentlySelectedIndex := currentlySelectedIndex <= userSettings["Fleet"].Length ? currentlySelectedIndex : currentlySelectedIndex - 1
		RefreshFleetList()
		HandleListChange()
	} else
		ShowMessage("Lets keep at least 1 instance.." , 3, 3000)
}

global currentlySelectedIndex := 1
HandleListChange(*) {
	global guiItems, userSettings, currentlySelectedIndex
	currentlySelectedIndex := guiItems["FleetListBox"].Value
	if currentlySelectedIndex < 1 
		currentlySelectedIndex := 1
	if currentlySelectedIndex > userSettings["Fleet"].Length 
		currentlySelectedIndex := userSettings["Fleet"].Length
	valid := currentlySelectedIndex > 0 && currentlySelectedIndex <= userSettings["Fleet"].Length 
	currentlySelectedIndex := valid ? currentlySelectedIndex : 1
	instanceCount := userSettings["Fleet"].Length
	i := userSettings["Fleet"][currentlySelectedIndex]
	guiItems["InstanceNameBox"].Value := i.Name
	guiItems["InstancePortBox"].Value := i.Port
	myLink := "https://localhost:" . userSettings["Fleet"][currentlySelectedIndex].Port+1
	guiItems["FleetLinkBox"].Text :=  '<a href="' . myLink . '">' . myLink . '</a>'
	SetSysLinkColor(guiItems["FleetLinkBox"])

	RefreshAudioSelector()
	guiItems["InstanceAudioSelector"].Text := ArrayHas(audioDevicesList, i.AudioDevice) ? i.AudioDevice : "Unset"
	guiItems["InstanceEnableCheckbox"].Value := i.Enabled
	guiItems["InstanceHeadlessCheckbox"].Value := (i.HeadlessModeSet = "enabled") ? 1 : 0
	UpdateButtonsLabels()
}
UpdateWindowPosition(*){
	global transientSettings, userSettings, myGui
	if (userSettings["Window"].restorePosition && DllCall("IsWindowVisible", "ptr", myGui.Hwnd) ){
		WinGetPos(&x, &y, , , "ahk_id " myGui.Hwnd)
		; Save position
		transientSettings["Window"].xPos := x
		transientSettings["Window"].yPos := y
	}
}
HandleLogsButton(*) {
	global guiItems, savedSettings, transientSettings
	transientSettings["Window"].logShow := !transientSettings["Window"].logShow
	guiItems["ButtonLogsShow"].Text := (transientSettings["Window"].logShow = 1 ? "Hide Logs" : "Show Logs")
	UpdateWindowPosition()
	RestoremyGui()
}
DeleteAllTimers(){

	for i in savedSettings["Fleet"] {
		if i.Enabled {
			DeleteLogWatchTimer(i.id)
			DeleteApolloMaintainTimer(i.id)
		}
	}
	SetTimer(MaintainGnirehtetProcess, 0)
	SetTimer(RefreshAdbDevices , 0)
	SetTimer(() => MaintainScrcpyProcess("Mic"), 0)
	SetTimer(() => MaintainScrcpyProcess("Cam"), 0)
}
HandleReloadButton(*) {
	global settingsLocked, userSettings, savedSettings, currentlySelectedIndex

	if settingsLocked {
		UpdateWindowPosition()
		userSettings["Window"].cmdReload := 1
		DeleteAllTimers()
		if false {
			; TODO maybe add seperate button to restart sertvices apart from apolo (possibly restart button)
			for process in PIDsListFromExeName("sunshine.exe")
				SendSigInt(process, true)
			for process in PIDsListFromExeName("adb.exe")
				SendSigInt(process, true)
			for process in PIDsListFromExeName("scrcpy.exe")
				SendSigInt(process, true)
			for process in PIDsListFromExeName("gnirehtet.exe")
				SendSigInt(process, true)
		}
		Reload
	}
	else {
		settingsLocked := !settingsLocked
		ApplyLockState()
		UpdateButtonsLabels()
		bootstrapSettings()
		ReflectSettings(savedSettings)
		Sleep (100)
	}
}
DeepClone(thing) {
    if (Type(thing) = "Map") {
        out := Map()
        for key, val in thing
            out[key] := DeepClone(val)
        return out
    } else if (Type(thing) = "Array") {
        out := []
        for val in thing
            out.Push(DeepClone(val))
        return out
    } else if (Type(thing) = "Object") {
        out := {}
        for key in ObjOwnProps(thing) {
            if thing.HasOwnProp(key)
                out.%key% := DeepClone(thing.%key%)
        }
        return out
    }
    return thing  ; primitive value
}

DeepCompare(a, b, path := "") {
    if (Type(a) != Type(b)) {
        ;MsgBox("Type mismatch at " . (path = "" ? "root" : path) . ": " . Type(a) . " vs " . Type(b))
        return 1
    }

    if (Type(a) = "Map") {
        if a.Count != b.Count {
            ;MsgBox("Map count difference at " . (path = "" ? "root" : path) . ": " . a.Count . " vs " . b.Count)
            return 1
        }
        for key, val in a {
            if !b.Has(key) {
                ;MsgBox("Missing key in second map at " . (path = "" ? "root" : path) . ": " . key)
                return 1
            }
            currentPath := path = "" ? String(key) : path . "." . String(key)
            if DeepCompare(val, b[key], currentPath)
                return 1
        }
        return 0
    }

    if (Type(a) = "Array") {
        if a.Length != b.Length {
            ;MsgBox("Array length difference at " . (path = "" ? "root" : path) . ": " . a.Length . " vs " . b.Length)
            return 1
        }
        for index, val in a {
            currentPath := path = "" ? "[" . index . "]" : path . "[" . index . "]"
            if DeepCompare(val, b[index], currentPath)
                return 1
        }
        return 0
    }

    if (Type(a) = "Object") {
        if ObjOwnPropCount(a) != ObjOwnPropCount(b) {
            ;MsgBox("Object property count difference at " . (path = "" ? "root" : path) . ": " . ObjOwnPropCount(a) . " vs " . ObjOwnPropCount(b))
            return 1
        }
        for key in ObjOwnProps(a) {
            if !b.HasOwnProp(key) {
                ;MsgBox("Missing property in second object at " . (path = "" ? "root" : path) . ": " . key)
                return 1
            }
            currentPath := path = "" ? key : path . "." . key
            if DeepCompare(a.%key%, b.%key%, currentPath)
                return 1
        }
        return 0
    }

    ; Primitive (number, string, etc.)
    if (a != b) {
        ;MsgBox("Value difference at " . (path = "" ? "root" : path) . ": '" . String(a) . "' vs '" . String(b) . "'")
        return 1
    }
    return 0
}


;------------------------------------------------------------------------------  
; Returns 1 if savedSettings vs. userSettings differ anywhere (skips "Window"), else 0  
UserSettingsWaiting() {
    global savedSettings, userSettings
	if !initDone
		return false
	for category in ["Manager", "Paths", "Fleet", "Android"]
		if DeepCompare(savedSettings[category], userSettings[category], category){
			return true
		}
	return false
}

UpdateButtonsLabels(){
	global guiItems, settingsLocked
	guiItems["ButtonLockSettings"].Text := (UserSettingsWaiting() && !settingsLocked) ? "Apply" : settingsLocked ? "🔒" : "🔓" 
	guiItems["ButtonReload"].Text := settingsLocked ?  "Reload" : "Cancel"

	i := userSettings["Fleet"][currentlySelectedIndex]
	pid := transientSettings["Fleet"].has(i.id) ? transientSettings["Fleet"][i.id] : 0
	guiItems["InstanceEnableCheckbox"].Text := i.Enabled ? ProcessExist(pid)  ? "Running: " pid "" : "Stopped" :  ProcessExist(pid) ? "To be Disabled" : "Disabled"
	CheckApolloFound()
	guiItems["InstanceHeadlessCheckbox"].Text := (i.HeadlessModeSet = "enabled" ? "Force Enabled" : "Force Disabled")
}
ApplyLockState() {
	global settingsLocked, guiItems, userSettings, currentlySelectedIndex

	isEnabled(cond := true) => cond ? 1 : 0
	isReadOnly(cond := true) => cond ? "+ReadOnly" : "-ReadOnly"

	textBoxes := ["PathsApolloBox"]
	checkBoxes := ["InstanceEnableCheckbox", "FleetAutoStartCheckBox", "AndroidReverseTetheringCheckbox", "AndroidMicCheckbox", "AndroidCamCheckbox", "FleetSyncVolCheckBox", "FleetRemoveDisconnectCheckbox", "InstanceHeadlessCheckbox"]
	buttons := ["FleetButtonDelete", "FleetButtonAdd"]
	androidSelectors := Map(
		"AndroidMicSelector", "AndroidMicCheckbox",
		"AndroidCamSelector", "AndroidCamCheckbox"
	)
	inputBoxes := ["InstanceNameBox", "InstancePortBox"]
	inputSelectors := ["InstanceAudioSelector"]

	for checkbox in checkBoxes
		guiItems[checkbox].Enabled := isEnabled(!settingsLocked)

	for button in buttons
		guiItems[button].Enabled := isEnabled(!settingsLocked)

	for box in textBoxes
		guiItems[box].Opt(isReadOnly(settingsLocked))

	for box in inputBoxes
		guiItems[box].Opt(isReadOnly(settingsLocked))

	for selector in inputSelectors
		guiItems[selector].Enabled := isEnabled(!settingsLocked)

	for selector, chkbox in androidSelectors
		guiItems[selector].Enabled := isEnabled(!settingsLocked && guiItems[chkbox].Value)
}

SaveUserSettings(){
	global userSettings, savedSettings

	savedSettings := DeepClone(userSettings)
	WriteSettingsFile(savedSettings)
}
global settingsLocked := 1
HandleLockButton(*) {
    global guiItems, settingsLocked, savedSettings, userSettings
	settingsLocked := !settingsLocked

	if !settingsLocked { ; to do if got unlocked
		RefreshFleetList()
		RefreshAudioSelector()
		RefreshAdbSelectors()
	} else {
		if UserSettingsWaiting(){
			userSettings["Window"].cmdApply := 1
			SaveUserSettings()
			DeleteAllTimers()
			WriteTransientFile()
			Reload
		}
	}
	ApplyLockState()
	UpdateButtonsLabels()

}
ExitMyApp() {
	global myGui, savedSettings
	userSettings["Window"].cmdExit := 1
	SaveUserSettings()
	myGui.Destroy()
	ExitApp()
}
MinimizemyGui(*) {
    global myGui, savedSettings, transientSettings
    ; Make sure window exists
    if !WinExist("ahk_id " myGui.Hwnd)
        return  ; Nothing to do

    ; Get position BEFORE hiding
	UpdateWindowPosition()

    transientSettings["Window"].lastState := 0
    ; Now hide the window
    myGui.Hide()
}
RestoremyGui() {
	global myGui, transientSettings, savedSettings, transientSettings

	h := (transientSettings["Window"].logShow = 0 ? 198 : 600)
	x := transientSettings["Window"].xPos
	y := transientSettings["Window"].yPos

	xC := (A_ScreenWidth - 580)/2 
	yC := (A_ScreenHeight - h)/2

	; Virtual screen bounds
	vx := SysGet(74) ; left
	vy := SysGet(75) ; top
	vw := SysGet(76) ; width
	vh := SysGet(77) ; height

	; If position outside entire virtual screen, reset
	if (x < vx || x > vx+vw || y < vy || y > vy+vh) {
		x := xC
		y := yC
	}

	if (savedSettings["Window"].restorePosition = 1) 
		myGui.Show("x" x " y" y " w580 h" h)
	else
		myGui.Show("x" xC " y" yC "w580 h" h)

	transientSettings["Window"].lastState := 1
}

MapSetIfChanged(map, option, newValue) {
    if map.Get(option,0) != newValue {
		;MsgBox( map.Get(key,0) . " > " . newValue)
        map.set(option, newValue)
        return true
    }
    return false
}
MapDeleteItemIfExist(map, key){
	if map.Has(key){
		map.Delete(key)
		return true
	} else
		return false
}
MergeConfMap(map1, map2) {
    merged := Map()
    
    ; Copy all key-value pairs from map1
    for key, val in map1
        merged[key] := val
    
    ; Copy key-value pairs from map2 (overwrites if key exists)
    for key, val in map2
        merged[key] := val
    
    return merged
}
DeleteKeyIfExist(map, key) {
    if map.Has(key)
        map.Delete(key)
}
FleetConfigInit(*) {
	global savedSettings
	
	; clean and prepare conf directory
	p := savedSettings["Paths"]
	m := savedSettings["Manager"]
	f := savedSettings["Fleet"]
	if !DirExist(p.Config)	
		DirCreate(p.Config)
	baseAppsJson := Map(
		"apps", [],
		"env",  {},
		"version", 2,
	)
	intendedTerminate := m.RemoveDisconnected ? JSON.true : JSON.false

	baseDesktopApp := Map(
		"image-path", "desktop.png",
		"name", "Desktop",
		"state-cmd", [],
		"terminate-on-pause", intendedTerminate
	)
	baseAppsJson["apps"].Push(baseDesktopApp)

	for i in f {
		baseConfig := CreateConfigMap(i)
		thisConfig := FileExist(i.configFile)? ConfRead(i.configFile) : DeepClone(baseConfig)
		if MirrorMapItemsIntoAnother(baseConfig, thisConfig)
			if ConfWrite(i.configFile, thisConfig)
				i.configChange := true

		if !FileExist(i.appsFile){
			FileAppend(JSON.stringify(baseAppsJson), i.appsFile)
			i.configChange := true
		} else {
			try 
				currentJson := JSON.Parse(FileRead(i.appsFile))
			catch 
				currentJson := Map()
			
			hasApps := currentJson.Has("apps")
			if hasApps {
				hasDesktopApp := false
				for app in currentJson["apps"] {
					if app.Has("name") && app["name"] = "Desktop" {
						; Check if we need to update terminate-on-pause
						needsUpdate := false
						
						if !app.Has("terminate-on-pause") {
							needsUpdate := true
						} else {
							; Compare current value with intended value
							; Handle both JSON boolean objects and regular booleans/numbers
							currentVal := app["terminate-on-pause"]
							if (currentVal == JSON.true || currentVal == true || currentVal == 1) {
								needsUpdate := (intendedTerminate == JSON.false)
							} else if (currentVal == JSON.false || currentVal == false || currentVal == 0) {
								needsUpdate := (intendedTerminate == JSON.true)
							} else {
								needsUpdate := true ; Unknown value, force update
							}
						}
						
						if needsUpdate {
							app["terminate-on-pause"] := intendedTerminate
							i.configChange := true
						}
						hasDesktopApp := true
					}
				}
				if !hasDesktopApp {
					currentJson["apps"].Push(baseDesktopApp)
					i.configChange := true
				}
				if i.configChange {
					; CRITICAL FIX: Recreate the entire structure to ensure proper JSON boolean handling
					newJson := Map(
						"apps", [],
						"env", currentJson.Has("env") ? currentJson["env"] : {},
						"version", currentJson.Has("version") ? currentJson["version"] : 2
					)
					
					; Rebuild apps array with proper JSON boolean types
					for app in currentJson["apps"] {
						newApp := Map()
						for key, value in app {
							if key = "terminate-on-pause" {
								; Ensure this is always a proper JSON boolean
								if (value == JSON.true || value == true || value == 1) {
									newApp[key] := JSON.true
								} else {
									newApp[key] := JSON.false
								}
							} else {
								newApp[key] := value
							}
						}
						newJson["apps"].Push(newApp)
					}
					
					FileDelete(i.appsFile)
					FileAppend(JSON.stringify(newJson), i.appsFile)
				}
			} else {
				FileDelete(i.appsFile)
				FileAppend(JSON.stringify(baseAppsJson), i.appsFile)
				i.configChange := true
			}
		}
	}
}

MirrorMapItemsIntoAnother(inputMap, outputMap){
	modified := false
	for option, value in inputMap {
		if value = "Unset" {
			if MapDeleteItemIfExist(outputMap, option)
				modified := true
		} else if MapSetIfChanged(outputMap, option, value)
			modified := true
	}
	return modified
}
CreateConfigMap(instance){
	optionsMap := Map(
		"sunshine_name", "Name",
		"port", "Port",
		"log_path","logFile", 
		"file_state", "stateFile",
		"credentials_file", "stateFile",
		"file_apps", "appsFile",
		"virtual_sink", "AudioDevice",
		"audio_sink", "AudioDevice",
		"auto_capture_sink", "AutoCaptureSink",
		"headless_mode", "HeadlessModeSet"
	)
	staticOptions := Map(
		"keep_sink_default", "disabled"
	)

	configMap := Map()
	for option, value in optionsMap
		configMap.Set(option, instance.%value%)
	
	for option, value in staticOptions
		configMap.Set(option, value)

	return configMap
}
bootstrapSettings() {
	global savedSettings := Map(), userSettings := Map()

	ReadSettingsFile(savedSettings)
	userSettings := DeepClone(savedSettings)
	userSettings["Window"] := savedSettings["Window"]
	;MsgBox(userSettings["Fleet"][1].Name)

}
bootstrapTransientSettings() {
	global transientSettings
	transientSettings := Map()
	transientSettings := ReadTransientFile()
	Changed := false

	tF := transientSettings["Fleet"]
	for id, pid in transientSettings["Fleet"] {
		isValid := false
		for i in savedSettings["Fleet"] 
			if i.id = id {
				;MsgBox("valid PID " . pid . " for instance ID " . id)
				isValid := true
				break
			}
		if !isValid {
			transientSettings["Fleet"].Delete(id)
			Changed := true
		}
	}
	for i in savedSettings["Fleet"] {
		if !tF.Has(Integer(i.id)) { 
			;MsgBox("Adding PID 0 for instance ID " . i.id)
			transientSettings["Fleet"][i.id] := 0 
			Changed := true
		}
	}
	if Changed 
		WriteTransientFile()
	SetTimer(WriteTransientSettingsASAP ,100)
}
WriteTransientSettingsASAP() {
	global transientSettings
	static lastSettings := Map(), firstRun := true
	
	if firstRun {
		firstRun := false
		lastSettings := DeepClone(transientSettings) ; Initialize lastSettings on first run
	} else {
		for cat in transientSettings
			if DeepCompare(transientSettings[cat], lastSettings[cat]) {
				lastSettings[cat] := DeepClone(transientSettings[cat]) ; Update lastSettings to current state
				WriteTransientFile(cat)
				UpdateButtonsLabels()
			}
	}
}

bootstrapGUI(){
	global savedSettings
	InitmyGui()
	ApplyLockState()
	ReflectSettings(savedSettings)
	RestoremyGui()
	InitTray()
}
PIDsListFromExeName(name) {
    static wmi := ComObjGet("winmgmts:\\.\root\cimv2")
    
    if (name == "")
        return

    PIDs := []
    for Process in wmi.ExecQuery("SELECT * FROM Win32_Process WHERE Name = '" name "'")
        PIDs.Push(Process.processId)

    return PIDs 
}
SendSigInt(pid, force:=false, wait := 1000) {
	if ProcessExist(pid) {
		; 1. Tell this script to ignore Ctrl+C and Ctrl+Break
		DllCall("SetConsoleCtrlHandler", "Ptr", 0, "UInt", 1)
		; 2. Detach from current console, attach to target's
		DllCall("FreeConsole")
		DllCall("AttachConsole", "UInt", pid)
		; 3. Send Ctrl+C (SIGINT) to all processes in that console (including the target)
		DllCall("GenerateConsoleCtrlEvent", "UInt", 0, "UInt", 0)
		DllCall("FreeConsole")

		timeSent := A_TickCount
		while force && ProcessExist(pid) && (wait + timeSent) > A_TickCount 
			sleep 10
		if force && ProcessExist(pid) 
			ProcessClose(pid)
	}
	return !ProcessExist(pid)
}


RunAndGetPID(exePath, args := "", workingDir := "") {
    consolePID := 0
	pid := 0
    Run(
        A_ComSpec " /c " '"' exePath '"' . (args ? " " . args : ""),
        workingDir := workingDir ? workingDir : SubStr(exePath, 1, InStr(exePath, "\",, -1) - 1),
        "Hide",
        &consolePID
    )
	Sleep(10)
	for process in ComObject("WbemScripting.SWbemLocator").ConnectServer().ExecQuery("Select * from Win32_Process where ParentProcessId=" consolePID)
		if InStr(process.CommandLine, exePath) {
			pid := process.ProcessId
			break
		}
	
	return pid
}

RunPsExecAndGetPID(exePath, args := "", id := 0) {
    workingDir := SubStr(exePath, 1, InStr(exePath, "\",, -1) - 1)
    psexecPath := savedSettings["Paths"].paexecExe
    sessionId := DllCall("Kernel32.dll\WTSGetActiveConsoleSessionId")
    tmpFile := A_Temp "\apollo-fleet-" id ".txt"
    
    ; Delete any existing file first
    if FileExist(tmpFile)
        FileDelete tmpFile

    psCmd := "$p=Start-Process -WindowStyle Hidden -FilePath '" . exePath . "' -ArgumentList '" . args . "' -PassThru;$p.Id>'" . tmpFile . "'"

	cmd := Format('"{1}" -accepteula -i {2} -w "{3}" -s "C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe"  -Command "{4}"', psexecPath, sessionId, workingDir, psCmd)

    RunWait(cmd, , "Hide")

    Loop 50 {
        Sleep 10
        if FileExist(tmpFile)
            return Number(RegExReplace(FileRead(tmpFile), "[^\d]"))
    }
    return 0
}



ArrayHas(arr, val) {
    for _, v in arr
        if (v = val)
            return true
    return false
}

FleetLaunchFleet(){
	global savedSettings, running := Map(), transientSettings
	f := savedSettings["Fleet"]
	p := savedSettings["Paths"]

	for i in f 
		if i.Enabled
			MaintainInstanceTimer(i.id)

	SetTimer(CleanConfigAndKillPIDs, 1000) ; Clean up config files every 10 seconds
}
CleanConfigAndKillPIDs() {
	global savedSettings, transientSettings, running
	static firstRun := true
	for id in running 
		if running[id]
			return
	
	fileTypes := ["configFile","stateFile", "appsFile", "logFile"]

	keepPIDs := []
	keepFiles := []
	for i in savedSettings["Fleet"] {
		if i.Enabled && (!i.configChange || !firstRun){
			keepPIDs.Push(transientSettings["Fleet"][i.id])
			;MsgBox("Keeping pid: " transientSettings["Fleet"][i.id])
		}
		for file in fileTypes
				if FileExist(i.%file%)
					keepFiles.Push(i.%file%)
	}
	KillProcessesExcept("sunshine.exe", keepPIDs, 5000)
	Loop Files savedSettings["Paths"].Config . '\*.*' 
		if !ArrayHas(keepFiles, A_LoopFileFullPath)
			try
				FileDelete(A_LoopFileFullPath)
	if firstRun
		firstRun := false
}
MaintainInstanceTimer(id){
	SetTimer(() => MaintainInstance(id), 5000)
}
DeleteApolloMaintainTimer(id){
	SetTimer(() => MaintainInstance(id), 0)
}
MaintainInstance(id) {
	global savedSettings, running, transientSettings
	static lastPid := 0
	running[id] := true
	i := savedSettings["Fleet"][id]
	if !(userSettings["Paths"].ApolloFound && FileExist(i.configFile) && FileExist(i.appsFile))
		return
	else if !ProcessExist(transientSettings["Fleet"][id]) 
		transientSettings["Fleet"][id] := RunPsExecAndGetPID(savedSettings["Paths"].apolloExe, i.configFile, id)
	if !transientSettings["Fleet"][id] != lastPid{
		lastPid := transientSettings["Fleet"][id]
		ShowMessage("Starting " i.Name " with PID: " transientSettings["Fleet"][id])
	}
	Sleep 100
	running[id] := false
}

SetupFleetTask() {
    taskName := "Apollo Fleet Launcher"
    exePath := A_ScriptFullPath
    AutoStart := savedSettings["Manager"].AutoStart
    
	if RunWait("cmd /c sc query ApolloService >nul 2>&1", , "Hide") == 0 {
		if AutoStart {
			RunWait('sc stop ApolloService', , "Hide")
			RunWait('sc config ApolloService start=disabled', , "Hide")
		} else {
			RunWait('sc config ApolloService start=auto', , "Hide")
			RunWait('sc start ApolloService', , "Hide")
		}
	}
    
	try {
		ts := ComObject("Schedule.Service")
		ts.Connect()
		task := ts.GetFolder("\").GetTask(taskName)
		isTask := true
		isEnabled := task.Definition.Settings.Enabled
		existingPath := task.Definition.Actions.Item(1).Path
		pathMismatch := (StrLower(existingPath) != StrLower(exePath))
	} catch {
		isTask := false
		isEnabled := false
		pathMismatch := true
	}

	if AutoStart {
		if !isTask || pathMismatch {
			Task := ComObject("Schedule.Service")
			Task.Connect()
			rootFolder := Task.GetFolder("\")
			taskDef := Task.NewTask(0)

			; Set logon trigger
			trigger := taskDef.Triggers.Create(9)  ; 9 = Logon
			trigger.Delay := "PT30S"

			; Set high privileges
			taskDef.Principal.RunLevel := 1  ; 1 = Highest

			; Set action: this is where we split program & arguments!
			action := taskDef.Actions.Create(0)  ; 0 = Exec
			action.Path := A_IsCompiled ? exePath : A_AhkPath
			action.Arguments := A_IsCompiled ? "" : '"' exePath '"'

			taskDef.RegistrationInfo.Description := "Apollo Fleet Manager"
			taskDef.Settings.Enabled := true
			taskDef.Settings.StartWhenAvailable := true

			rootFolder.RegisterTaskDefinition(taskName, taskDef, 6, "", "", 3) ; 6 = create/overwrite, 3 = logon

		} else if !isEnabled {
			RunWait Format('schtasks /Change /TN "{1}" /ENABLE', taskName), , "Hide"
		}
	} else if isTask && isEnabled {
		RunWait Format('schtasks /Change /TN "{1}" /DISABLE', taskName), , "Hide"
	}


}

ResetFlags(){
	global transientSettings, initDone
	w := transientSettings["Window"]
	w.cmdReload := 0
	w.cmdExit := 0
	w.cmdApply := 0
	initDone := true
}
KillProcessesExcept(pName, keep := [0], wait := 1000) {
	if Type(keep) != "Array"
		keep := [keep]
	
	targetKill := []

	; Check keep[] validity
	newKeep := []
	for pid in keep
		if ProcessExist(pid) 
			if GetProcessName(pid) = pName
				newKeep.Push(pid)
			else
				targetKill.Push(pid)
		
	keep := newKeep

	pids := PIDsListFromExeName(pName)

	; Kill remaining
	for pid in pids {
		if !ArrayHas(keep, pid) {
			KillWithoutBlocking(pid, true, 100)
			targetKill.Push(pid)
		}
	}

	lastSent := A_TickCount
	while AnyProcessAlive(targetKill) && (wait + lastSent) > A_TickCount
		sleep 10
	for pid in targetKill
		if ProcessExist(pid) && !ArrayHas(keep, pid) {
			ShowMessage("Failed to kill " . pName . " PID: " . pid, 3)
			return false
		}
	return true
}

AnyProcessAlive(pids){
	for pid in pids
		if ProcessExist(pid)
			return true
	return false
}
KillWithoutBlocking(pid, force:=false, wait:=100) {
	SetTimer(()=>SendSigInt(pid, force, wait), -1)
}
GetProcessName(pid) {
    try {
        for p in ComObject("WbemScripting.SWbemLocator").ConnectServer().ExecQuery(
            "SELECT Name FROM Win32_Process WHERE ProcessId=" . pid)
        return p.Name
    } catch
        return ""
}

MaintainGnirehtetProcess(){
	global savedSettings, transientSettings

	p := savedSettings["Paths"]

	if !ProcessExist(transientSettings["Android"].gnirehtetPID) 
		transientSettings["Android"].gnirehtetPID := RunAndGetPID(p.gnirehtetExe, "autorun")

	KillProcessesExcept("gnirehtet.exe", transientSettings["Android"].gnirehtetPID, 3000)

	; TODO detect fault or output connections log or more nice features...
}

ProcessRunning(pid){
	return !!ProcessExist(pid)
}

UpdateStatusArea() {
	global savedSettings, guiItems, msgTimeout

	f := savedSettings["Fleet"]

	if  msgTimeout {
		valid := f.Length > 0
		apolloRunning := valid ? 1 : 0
		for i in f {
			if i.Enabled = 0
				continue
			else if !ProcessRunning(transientSettings["Fleet"][i.id]) {
				apolloRunning := 0
				break
			}
		}
		gnirehtetRunning := ProcessRunning(transientSettings["Android"].gnirehtetPID)
		androidMicRunning := ProcessRunning(transientSettings["Android"].scrcpyMicPID)
		androidCamRunning := ProcessRunning(transientSettings["Android"].scrcpyCamPID)

		statusItems := Map(
			"StatusApollo", "apolloRunning",
			"StatusGnirehtet", "gnirehtetRunning",
			"StatusAndroidMic", "androidMicRunning",
			"StatusAndroidCam", "androidCamRunning"
		)

		for item, status in statusItems 
			guiItems[item].Value := (%status%? "✅" : "❎") . SubStr(guiItems[item].Value, 2)
	}
	for i in f {

	}
}

global msgTimeout := 0
global currentMessageLevel := -1
ShowMessage(msg, level:=0, timeout:=1000) {
	global myGui, guiItems, msgTimeout, msgExpiry
	static colors := ["000000", "ff0000", "FFA500", "0000ff"]
	static icons := ["🏃 ", "ℹ️ ", "⚠️ ", "❌ "]
	global currentMessageLevel
	if (level >= currentMessageLevel) || msgTimeout {
		; level: 0=debug, 1=info, 2=warn, 3=error
		msgExpiry := A_TickCount + timeout
		icon := icons.Has(level+1) ? icons[level+1] : ""
		color := colors.Has(level+1) ? colors[level+1] : "Black"
		guiItems["StatusMessage"].Opt("c" color)
		guiItems["StatusMessage"].Text := icon . msg
		currentMessageLevel := level
		msgTimeout := 0
		SetTimer(AutoClearMessage, -1)
	}
}
AutoClearMessage() {
	global msgTimeout, guiItems, msgExpiry, currentMessageLevel
	While msgExpiry > A_TickCount {
		Sleep(100)
		if msgTimeout
			return
	}
	currentMessageLevel := -1
	msgTimeout := 1
}

LogMessage(msg, level, show:=0, timeout:=1000){
	global myGui, guiItems, msgTimeout
	static colors := ["Black", "Blue", "Orange", "Red"]
	static icons := ["🏃 ", "ℹ️ ", "⚠️ ", "❌ "]
	; level: 0=debug, 1=info, 2=warn, 3=error
	
	if (show && msgTimeout) || level > 1 {
		ShowMessage(msg, level, timeout)
	}
}
; TODO LOGGING from all functions

FleetInitApolloLogWatch() {
    global savedSettings

    for i in savedSettings["Fleet"]
        if i.Enabled 
			CreateTimerForInstance(i.id)
}
CreateTimerForInstance(id) {
    SetTimer(() => ProcessApolloLog(id), 500)
}
DeleteLogWatchTimer(id){
	SetTimer(() => ProcessApolloLog(id), 0)
}
ProcessApolloLog(id) {
	global savedSettings
	static LastReadLogLine := 0
	if savedSettings["Fleet"].Length < id
		return 0
	i := savedSettings["Fleet"][id]

    ; Fix case sensitivity - use consistent casing
    if !FileExist(i.logFile) {
        return 0
    }
    
    content := FileRead(i.logFile)
    lines := StrSplit(content, "`n")
    totalLines := lines.Length
    if totalLines <= LastReadLogLine 
        return 0
    
    status := ""
    
    ; Process only new lines (from LastReadLogLine + 1 to totalLines)
    Loop totalLines - LastReadLogLine {
        lineIndex := LastReadLogLine + A_Index
        if lineIndex <= totalLines {
            line := lines[lineIndex]
            
            if InStr(line, "CLIENT CONNECTED") 
                status := "CONNECTED"
            else if InStr(line, "CLIENT DISCONNECTED") 
                status := "DISCONNECTED"
        }
    }

    LastReadLogLine := totalLines

    return 0
}

SyncApolloVolume(){
	global savedSettings, transientSettings

	static lastSystemVolume := -1
    static lastSystemMute := -1
	static desiredVolume := 0

	static counter := -1
	static systemDevice := AudioDevice.GetDefault()

	static appsVol := Map()

	counter += 1
	if counter = 0 {
		systemDevice := AudioDevice.GetDefault()
		for i in savedSettings["Fleet"] {
			pid := transientSettings["Fleet"][i.id]
			if i.Enabled && ProcessExist(pid)
				if i.AudioDevice = "Unset" && AppVolume(pid).IsValid()
					appsVol[i.id] := AppVolume(pid)
				else if i.AudioDevice != "Unset" && AppVolume(pid, GetDeviceID(i.AudioDevice)).IsValid()
					appsVol[i.id] := AppVolume(pid, GetDeviceID(i.AudioDevice))
		}
		for pid, appVol in appsVol
			if !appVol.IsValid()
				appsVol.Delete(pid)
	} else if counter = 10
		counter := -1

	if (appsVol.Count = 0) 
		return

    systemVolume := systemDevice.GetVolume()
    systemMute := systemDevice.GetMute()

	if (lastSystemMute != systemMute) || (lastSystemVolume != systemVolume) {
		lastSystemVolume := systemVolume
		lastSystemMute := systemMute

		desiredVolume := systemMute ? 0 : systemVolume
		for id, appVol in appsVol 
			appVol.SetVolume(desiredVolume)
	} else 
		for pid, appVol in appsVol 
			if (appVol.GetVolume() != desiredVolume)
				appVol.SetVolume(desiredVolume)
}

global androidDevicesMap := Map("Unset", "Unset"), androidDevicesList := ["Unset"], adbReady := false
RefreshAdbSelectors(item:="") {
	global guiItems, androidDevicesMap, androidDevicesList
	a := savedSettings["Android"]

	if !adbReady
		return 

	micID := a.MicDeviceID
	camID := a.CamDeviceID

	if micID != "Unset" && !ArrayHas(androidDevicesList, micID)
		androidDevicesList.Push(micID)
	if camID != "Unset" && camID != micID && !ArrayHas(androidDevicesList, camID)
		androidDevicesList.Push(camID)

	for device, status in androidDevicesMap
		if !ArrayHas(androidDevicesList, device)
			androidDevicesList.Push(device)

	if item = "Mic" {
		guiItems["AndroidMicSelector"].Delete()
		guiItems["AndroidMicSelector"].Add(androidDevicesList)
		guiItems["AndroidMicSelector"].Text :=  micID
	} else if item = "Cam" {
		guiItems["AndroidCamSelector"].Delete()
		guiItems["AndroidCamSelector"].Add(androidDevicesList)
		guiItems["AndroidCamSelector"].Text := camID
		return
	} else {
		guiItems["AndroidMicSelector"].Delete()
		guiItems["AndroidMicSelector"].Add(androidDevicesList)
		guiItems["AndroidMicSelector"].Text :=  micID
		guiItems["AndroidCamSelector"].Delete()
		guiItems["AndroidCamSelector"].Add(androidDevicesList)
		guiItems["AndroidCamSelector"].Text := camID
	}
}

RefreshAdbDevices(){
	global androidDevicesMap, guiItems, savedSettings, adbReady
	p := savedSettings["Paths"]
	r := savedSettings["Android"]

	micID := r.MicDeviceID
	camID := r.CamDeviceID

	tempMap := Map()
	tempMap := DeepClone(androidDevicesMap) ; keep old map to compare later

	if micID != "Unset"
		tempMap[micID] := "Disconnected"
	if camID != "Unset" && camID != micID
		tempMap[camID] := "Disconnected"
	
	result := StdoutToVar('"' p.adbExe '" devices', , "UTF-8")
	output := result.Output
	for key, value in tempMap
		tempMap[key] := "Disconnected" ; reset all devices to disconnected
	for line in StrSplit(output, "`n") {
		if InStr(line, "device") && !InStr(line, "List of devices") {
			deviceName := StrSplit(line, "`t")[1]
			tempMap[deviceName] := "Connected"
		}
	}
	if DeepCompare(tempMap, androidDevicesMap) {
		androidDevicesMap := DeepClone(tempMap) ; update the global map only if it changed
		RefreshAdbSelectors()
		UpdateButtonsLabels()
	}
	if !adbReady
		adbReady := true
}

MaintainScrcpyProcess(targetDevice := "Mic") {
	global savedSettings, transientSettings, androidDevicesMap, adbReady

	if !adbReady
		return

	p := savedSettings["Paths"]
	dev := targetDevice = "Mic" ? savedSettings["Android"].MicDeviceID : savedSettings["Android"].CamDeviceID
	cmd := targetDevice = "Mic" ? "--no-video --no-window --audio-source=mic" : "--video-source=camera --no-audio"
	deviceConnected := androidDevicesMap.Has(dev) && androidDevicesMap[dev] = "Connected"
	pid := targetDevice = "Mic" ? transientSettings["Android"].scrcpyMicPID : transientSettings["Android"].scrcpyCamPID

	if deviceConnected && !ProcessExist(pid) {
		RunWait(p.adbExe ' -s ' dev ' shell input keyevent KEYCODE_WAKEUP', , 'Hide')
		pid := RunAndGetPID(p.scrcpyExe, " -s " dev " " cmd)
	} else if !deviceConnected && ProcessExist(pid) {
		if SendSigInt(pid, true)
			pid := 0
	}

	; update only the PID in transientSettings
	if (targetDevice = "Mic")
		transientSettings["Android"].scrcpyMicPID := pid
	else
		transientSettings["Android"].scrcpyCamPID := pid

	Sleep(100)
}



bootstrapApollo(){
	global savedSettings, guiItems, currentlySelectedIndex, apolloBootsraped
	SetupFleetTask()
	FleetConfigInit()
	FleetLaunchFleet()
	FleetInitApolloLogWatch()
	if savedSettings["Manager"].SyncVolume
		SetTimer(SyncApolloVolume, 100)
	apolloBootsraped := true
	FinishBootStrap()
}

bootstrapGnirehtet(){
	global savedSettings, guiItems, gnirehtetBootsraped
	if savedSettings["Android"].ReverseTethering {
		ShowMessage("Starting Gnirehtet...")
		SetTimer(MaintainGnirehtetProcess, 3000)
	} else {
		SetTimer(() => KillProcessesExcept("gnirehtet.exe", , 3000), -1)
	}
	gnirehtetBootsraped := true
	FinishBootStrap()
}

bootstrapAndroid() {
	global savedSettings, guiItems, androidDevicesMap, adbReady, androidBootsraped
	r := transientSettings["Android"]
	a := savedSettings["Android"]
	uA := userSettings["Android"]
	savedRequire := a.MicEnable || a.CamEnable
	userRequire := uA.MicEnable || uA.CamEnable
	if savedRequire || userRequire {
		KillProcessesExcept("adb.exe", , 3000)
		SetTimer(RefreshAdbDevices , 1000)
		scMic := r.scrcpyMicPID
		scCam := r.scrcpyCamPID
		while !adbReady
			sleep 100
		if a.MicEnable && a.MicDeviceID != "Unset"
			SetTimer(() => MaintainScrcpyProcess("Mic"), 500)
		if a.CamEnable && a.CamDeviceID != "Unset"
			SetTimer(() => MaintainScrcpyProcess("Cam"), 500)
	} else {
		SetTimer(() => KillProcessesExcept("adb.exe", , 3000), -1) ; TODO maybe use adb-kill server here
		SetTimer(() => KillProcessesExcept("scrcpy.exe", , 3000), -1)
	}
	androidBootsraped := true
	FinishBootStrap()
}









global myGui, guiItems, userSettings, savedSettings, transientSettings, initDone := false
bootstrapSettings()
bootstrapTransientSettings()
bootstrapGUI()

if !savedSettings["Manager"].ShowErrors{
	OnError(HandleError, -1)  ; -1 = override default behavior

	HandleError(err, mode) {
		;HandleReloadButton()
		return true
		; TODO pipe the error message to the status area
	}
}

global apolloBootsraped := false
SetTimer(bootstrapApollo, -1)

global gnirehtetBootsraped := false
SetTimer(bootstrapGnirehtet, -1)

global androidBootsraped := false
SetTimer(bootstrapAndroid, -1)

SetTimer UpdateStatusArea, 1000

FinishBootStrap() {
	global apolloBootsraped, gnirehtetBootsraped, androidBootsraped
	if !apolloBootsraped || !androidBootsraped || !gnirehtetBootsraped
		return false
	InitGuiItemsEvents()
	ResetFlags()
}