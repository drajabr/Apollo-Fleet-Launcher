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
			lines.=(Key . " = " . Value . "`n")

	if FileExist(configFile)
		FileDelete(configFile)
	FileAppend(lines, configFile)

	return true

}

ReadSettingsFile(Settings := Map(), File := "settings.ini", groups := "all" ) {
    ; Create default Maps
    for k in ["Runtime", "Manager", "Window", "Paths", "Fleet", "Android"]
        if !Settings.Has(k)
            Settings[k] := {}
    if !Settings.Has("Fleet")
        Settings["Fleet"] := []

    if !FileExist(File)
        FileAppend("", File)

    if (groups = "all" || InStr(groups, "Manager"))
        ReadSettingsGroup(File, "Manager", Settings)
    if (groups = "all" || InStr(groups, "Window"))
        ReadSettingsGroup(File, "Window", Settings)
    if (groups = "all" || InStr(groups, "Paths"))
        ReadSettingsGroup(File, "Paths", Settings)
    if (groups = "all" || InStr(groups, "Android"))
        ReadSettingsGroup(File, "Android", Settings)
    if (groups = "all" || InStr(groups, "Fleet"))
        ReadSettingsGroup(File, "Fleet", Settings)
	if (groups = "all" || InStr(groups, "Runtime"))
        ReadSettingsGroup(File, "Runtime", Settings)
}

ReadSettingsGroup(File, group, Settings) {
    switch group {
		case "Runtime":
			r := Settings["Runtime"]
			r.ManagerPID := Integer(IniRead(File, "Runtime", "ManagerPID", 0))
			r.gnirehtetPID := Integer(IniRead(File, "Runtime", "gnirehtetPID", 0))
			r.scrcpyMicPID := Integer(IniRead(File, "Runtime", "scrcpyMicPID", 0))
			r.scrcpyCamPID := Integer(IniRead(File, "Runtime", "scrcpyCamPID", 0))
        case "Manager":
			m := Settings["Manager"]
			m.AutoStart := IniRead(File, "Manager", "AutoStart", 1) = "1" ? 1 : 0
            m.SyncVolume := IniRead(File, "Manager", "SyncVolume", 1) = "1" ? 1 : 0
            m.RemoveDisconnected := IniRead(File, "Manager", "RemoveDisconnected", "true")
            m.SyncSettings := IniRead(File, "Manager", "SyncSettings", 1) = "1" ? 1 : 0
			m.DarkTheme := IniRead(File, "Manager", "DarkMode", IsSystemDarkMode())	; TODO now it defaults to system mode at first launch.maybe we can add small button with icon or somewhat
			m.ShowErrors := IniRead(File, "Manager", "ShowErrors", 1)
        case "Window":
			w := Settings["Window"]
            w.restorePosition := IniRead(File, "Window", "restorePosition", 1)
            w.xPos := IniRead(File, "Window", "xPos", (A_ScreenWidth - 580) / 2)
            w.yPos := IniRead(File, "Window", "yPos", (A_ScreenHeight - 198) / 2)
            w.lastState := IniRead(File, "Window", "lastState", 1)
            w.logShow := IniRead(File, "Window", "logShow", 0)
			w.cmdReload := IniRead(File, "Window", "cmdReload", 0)
			w.cmdExit := IniRead(File, "Window", "cmdExit", 0)
			w.cmdApply := IniRead(File, "Window", "cmdApply", 0)
        case "Paths":
            base := A_ScriptDir
			p := Settings["Paths"]
            p.Apollo := IniRead(File, "Paths", "Apollo", "C:\Program Files\Apollo")
            p.Config := IniRead(File, "Paths", "Config", base "\config")
            p.ADBTools := IniRead(File, "Paths", "ADB", base "\bin\platform-tools")
			p.apolloExe := p.Apollo "\sunshine.exe"
			p.gnirehtetExe := p.ADBTools "\gnirehtet.exe"
			p.scrcpyExe := p.ADBTools "\scrcpy.exe"
			p.adbExe := p.ADBTools "\adb.exe"
			p.paexecExe := IniRead(File, "Paths", "paexecExe", base "\bin\PaExec\paexec.exe")
        case "Android":
            a := Settings["Android"]
            a.ReverseTethering := IniRead(File, "Android", "ReverseTethering", 1) = "1" ? 1 : 0
            a.MicDeviceID := IniRead(File, "Android", "MicDeviceID", "Unset")
			a.MicEnable := IniRead(File, "Android", "MicEnable", a.MicDeviceID = "Unset" ? 0 : 1) = "1" ? 1 : 0
            a.CamDeviceID := IniRead(File, "Android", "CamDeviceID", "Unset")
			a.CamEnable := IniRead(File, "Android", "CamEnable", a.CamDeviceID = "Unset" ? 0 : 1) = "1" ? 1 : 0
        case "Fleet":
			Settings["Fleet"] := []
			f := Settings["Fleet"]
            configp := Settings["Paths"].Config
            sections := StrSplit(IniRead(File), "`n")
			instanceNumber := 1
            for section in sections 
                if (SubStr(section, 1, 8) = "Instance") {
                    i := {}
					i.id := instanceNumber
					instanceNumber += 1
					i.Name := IniRead(File, section, "Name", "i" . A_Index)
					i.Port := IniRead(File, section, "Port", 11000 + A_Index * 1000)
					i.Enabled := IniRead(File, section, "Enabled", 1) = "1" ? 1 : 0
					i.apolloPID := Integer(IniRead(File, section, "apolloPID", 0))
					i.configFile := configp "\fleet-" i.id ".conf"
					i.logFile := configp "\fleet-" i.id ".log"
					i.appsFile := configp "\apps-" i.id ".json"
					i.stateFile := configp "\state-" i.id ".json"
					i.AudioDevice := IniRead(File, section, "AudioDevice", "Unset")
					i.AutoCaptureSink := i.AudioDevice = "Unset" ? "enabled" : "disabled"
					i.configChange := 0
					f.Push(i)
                }
			if f.Length = 0 {
				i := {} ; Create a new object for each i
				i.id := 1
				i.Port := 11000
				i.Name := "Instance " . i.id
				i.Enabled := 1
				i.apolloPID := 0
				i.AudioDevice := "Unset"
				i.AutoCaptureSink := i.AudioDevice = "Unset" ? "enabled" : "disabled"
				i.configFile := configp "\fleet-" i.id ".conf"
				i.logFile := configp "\fleet-" i.id ".log"
				i.stateFile :=  configp "\state-" i.id ".json"
				i.appsFile := configp "\apps-" i.id ".json"
				i.stateFile := configp "\state-" i.id ".json"
				i.configChange := 0
				f.Push(i)
			}
    }
}
WriteSettingsFile(Settings := Map(), File := "settings.ini", groups := "all") {
    if FileExist(File) {
		lastContents := FileRead(File)
		changed := 0
		if (groups = "all" || InStr(groups, "Manager"))
			changed += WriteSettingsGroup(Settings, File, "Manager")
		if (groups = "all" || InStr(groups, "Window"))
			changed += WriteSettingsGroup(Settings, File, "Window")
		if (groups = "all" || InStr(groups, "Paths"))
			changed += WriteSettingsGroup(Settings, File, "Paths")
		if (groups = "all" || InStr(groups, "Android"))
			changed += WriteSettingsGroup(Settings, File, "Android")
		if (groups = "all" || InStr(groups, "Fleet"))
			changed += WriteSettingsGroup(Settings, File, "Fleet")
		if (groups = "all" || InStr(groups, "Runtime"))
			changed += WriteSettingsGroup(Settings, File, "Runtime")
		if changed
			FileOpen(File, "a").Close()
	} else {
		FileAppend("", File)
		WriteSettingsFile(Settings, File, groups) ; Retry writing settings if file was just created
	}
	while changed && (FileRead(File) = lastContents) {
		Sleep 10 ; Wait for file to be written
	}
}

WriteSettingsGroup(Settings, File, group) {
	changed := 0
	WriteIfChanged(file, section, key, value) {
		old := IniRead(file, section, key, "__MISSING__")
		if (old != value) {
			IniWrite(value, file, section, key)
			changed := 1
		}
	}
    switch group {
		case "Runtime":
			r := Settings["Runtime"]
			WriteIfChanged(File, "Runtime", "ManagerPID", r.ManagerPID)
			WriteIfChanged(File, "Runtime", "GnirehtetPID", r.GnirehtetPID)
			WriteIfChanged(File, "Runtime", "scrcpyMicPID", r.scrcpyMicPID)
			WriteIfChanged(File, "Runtime", "scrcpyCamPID", r.scrcpyCamPID)
        case "Window":
			w := Settings["Window"]
			WriteIfChanged(File, "Window", "restorePosition", w.restorePosition)
			WriteIfChanged(File, "Window", "xPos", w.xPos)
			WriteIfChanged(File, "Window", "yPos", w.yPos)
			WriteIfChanged(File, "Window", "lastState", w.lastState)
			WriteIfChanged(File, "Window", "logShow", w.logShow)
			WriteIfChanged(File, "Window", "cmdReload", w.cmdReload)
			WriteIfChanged(File, "Window", "cmdExit", w.cmdExit)
			WriteIfChanged(File, "Window", "cmdApply", w.cmdApply)
        case "Manager":
			m := Settings["Manager"]
			WriteIfChanged(File, "Manager", "AutoStart", m.AutoStart)
			WriteIfChanged(File, "Manager", "SyncVolume", m.SyncVolume)
			WriteIfChanged(File, "Manager", "RemoveDisconnected", m.RemoveDisconnected)
			WriteIfChanged(File, "Manager", "DarkTheme", m.DarkTheme)
			WriteIfChanged(File, "Manager", "ShowErrors", m.ShowErrors)
        case "Paths":
			p := Settings["Paths"]
			WriteIfChanged(File, "Paths", "Apollo", p.Apollo)
			WriteIfChanged(File, "Paths", "Config", p.Config)
			WriteIfChanged(File, "Paths", "ADB", p.ADBTools)
		
        case "Android":
			a := Settings["Android"]
			WriteIfChanged(File, "Android", "ReverseTethering", a.ReverseTethering)
			WriteIfChanged(File, "Android", "MicDeviceID", a.MicDeviceID)
			WriteIfChanged(File, "Android", "MicEnable", a.MicEnable)
			WriteIfChanged(File, "Android", "CamEnable", a.CamEnable)
		
        case "Fleet":
			f := Settings["Fleet"]
			sections := StrSplit(IniRead(File), "`n")
            for section in sections 
                if (SubStr(section, 1, 8) = "Instance")
					IniDelete(File, section)
			for i in Settings["Fleet"] {
				section := "Instance" i.id
				IniWrite(i.Name, File, section, "Name")
				IniWrite(i.Port, File, section, "Port")
				IniWrite(i.Enabled, File, section, "Enabled")
				IniWrite(i.apolloPID, File, section, "apolloPID")
				IniWrite(i.AudioDevice, File, section, "AudioDevice")
			}
	}
	return changed
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
	guiItems["PathsApolloBox"] := myGui.Add("Edit", "x53 y17 w212 h21")
	myGui.Add("Text", "x16 y21", "Apollo:")
	guiItems["PathsApolloBrowseButton"] := myGui.Add("Button", "x267 y16 w30 h23", "📂")

	guiItems["FleetListBox"] := myGui.Add("ListBox", "x16 y50 w100 h82 +0x100 Choose1")
	guiItems["FleetListBox"].Enabled := 0
	myGui.Add("Text", "x123 y54", "Name:Port")
	guiItems["InstanceNameBox"] := myGui.Add("Edit", "x176 y51 w80 h21")
	guiItems["InstancePortBox"] := myGui.Add("Edit", "x256 y51 w40 h21")

	presetAudioDevices := ["Unset"]
	for i in savedSettings["Fleet"]
		if !presetAudioDevices.Has(i.AudioDevice)
			presetAudioDevices.Push(i.AudioDevice)
	myGui.Add("Text", "x123 y83", "Audio :")
	guiItems["InstanceAudioSelector"] := myGui.Add("DropDownList", "x176 y80 w120 Choose1", presetAudioDevices)

	myGui.Add("Text", "x123 y108 ", "Link:")
	myLink := "https://localhost:00000"
	guiItems["FleetLinkBox"] := myGui.Add("Link", "x176 y108", '<a href="' . myLink . '">' . myLink . '</a>')

	myGui.Add("Text", "x123 y135 ", "Enabled:")
	guiItems["InstanceEnableCheckbox"] := myGui.Add("CheckBox", "x176 y135", "Status will appear here")

	guiItems["FleetButtonAdd"] := myGui.Add("Button", "x43 y134 w75 h21", "Add")
	guiItems["FleetButtonDelete"] := myGui.Add("Button", "x14 y134 w27 h21", "✖")

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
	guiItems["FleetRemoveDisconnectCheckbox"].Value := m.RemoveDisconnected = "true" ? 1 : 0
	guiItems["AndroidReverseTetheringCheckbox"].Value := a.ReverseTethering
	guiItems["AndroidMicCheckbox"].Value := a.MicEnable
	guiItems["AndroidMicSelector"].Text := a.MicDeviceID
	guiItems["AndroidCamCheckbox"].Value := a.CamEnable
	guiItems["AndroidCamSelector"].Text := a.CamDeviceID
	guiItems["PathsApolloBox"].Value := Settings["Paths"].Apollo
	guiItems["ButtonLogsShow"].Text := (Settings["Window"].logShow = 1 ? "Hide Logs" : "Show Logs")
	;guiItems["InstanceAudioSelector"].Enabled :=0
	guiItems["FleetListBox"].Delete()
	guiItems["FleetListBox"].Add(EveryInstanceProp(Settings))
	instanceCount := Settings["Fleet"].Length
	valid := currentlySelectedIndex > 0 && currentlySelectedIndex <= userSettings["Fleet"].Length 
	guiItems["InstanceNameBox"].Value := valid ? Settings["Fleet"][currentlySelectedIndex].Name : ""
	guiItems["InstancePortBox"].Value := valid ? Settings["Fleet"][currentlySelectedIndex].Port : ""
	guiItems["InstanceEnableCheckbox"].Value := valid ? f[currentlySelectedIndex].Enabled : 0
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

	guiItems["FleetButtonAdd"].OnEvent("Click", HandleInstanceAddButton)
	guiItems["FleetButtonDelete"].OnEvent("Click", HandleInstanceDeleteButton)

	guiItems["InstanceNameBox"].OnEvent("Change", HandleNameChange)
	guiItems["InstancePortBox"].OnEvent("Change", HandlePortChange)
	guiItems["InstancePortBox"].OnEvent("Change", StrictPortLimits)
	guiItems["InstanceAudioSelector"].OnEvent("Change", HandleAudioSelector)
	OnMessage(0x404, TrayIconHandler)
	guiItems["FleetListBox"].Enabled := 1
	guiItems["ButtonReload"].Enabled := 1
	guiItems["ButtonLockSettings"].Enabled := 1
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
	userSettings["Manager"].RemoveDisconnected := guiItems["FleetRemoveDisconnectCheckbox"].Value ? "true" : "false"
	valid := currentlySelectedIndex > 0 && currentlySelectedIndex <= userSettings["Fleet"].Length 
	currentlySelectedIndex := valid ? currentlySelectedIndex : 1
	userSettings["Fleet"][currentlySelectedIndex].Enabled := guiItems["InstanceEnableCheckbox"].Value
	UpdateButtonsLabels()
}
RefreshFleetList(){
	global guiItems, userSettings, currentlySelectedIndex
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
	i.configFile := configp "\fleet-" i.id ".conf"
	i.logFile := configp "\fleet-" i.id ".log"
	i.stateFile :=  configp "\state-" i.id ".json"
	i.appsFile := configp "\apps-" i.id ".json"
	i.stateFile := configp "\state-" i.id ".json"	
	i.apolloPID := 0
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
	UpdateButtonsLabels()
}
UpdateWindowPosition(){
	global savedSettings, myGui
	if (userSettings["Window"].restorePosition && DllCall("IsWindowVisible", "ptr", myGui.Hwnd) ){
		WinGetPos(&x, &y, , , "ahk_id " myGui.Hwnd)
		; Save position
		savedSettings["Window"].xPos := x
		savedSettings["Window"].yPos := y
		WriteSettingsFile(savedSettings,,"Window")
	}
}
HandleLogsButton(*) {
	global guiItems, savedSettings
	userSettings["Window"].logShow := !userSettings["Window"].logShow
	guiItems["ButtonLogsShow"].Text := (userSettings["Window"].logShow = 1 ? "Hide Logs" : "Show Logs")
	UpdateWindowPosition()
	RestoremyGui()
}
DeleteAllTimers(){
	SetTimer(UpdateAndSavePIDs, 0)
	for i in savedSettings["Fleet"] {
		if i.Enabled = 1 {
			DeleteLogWatchTimer(i.id)
			DeleteApolloMaintainTimer(i.id)
		}
	}
	SetTimer(MaintainGnirehtetProcess, 0)
	SetTimer(RefreshAdbDevices , 0)
	r := savedSettings["Runtime"]
	a := savedSettings["Android"]
	SetTimer(() => MaintainScrcpyProcess(r.scrcpyMicPID, a.MicDeviceID, " --no-video --no-window --audio-source=mic"), 0)
	SetTimer(() => MaintainScrcpyProcess(r.scrcpyCamPID, a.CamDeviceID, " --video-source=camera --no-audio"), 0)
}
HandleReloadButton(*) {
	global settingsLocked, userSettings, savedSettings, currentlySelectedIndex

	if settingsLocked {
		UpdateWindowPosition()
		userSettings["Window"].cmdReload := 1
		DeleteAllTimers()
		if false {
			; TODO maybe add seperate button to restart sertvices apart from apolo (possibly restart button)
			if savedSettings["Android"].ReverseTethering 
				SendSigInt(savedSettings["Runtime"].gnirehtetPID, true)
			if savedSettings["Android"].MicEnable 
				SendSigInt(savedSettings["Runtime"].scrcpyMicPID, true)
			if savedSettings["Android"].CamEnable
				SendSigInt(savedSettings["Runtime"].scrcpyCamPID, true)
			for i in savedSettings["Fleet"] {
				if i.Enabled = 1
					SendSigInt(i.apolloPID, true)
				if i.Enabled = 1 && ProcessExist(i.consolePID)
					SendSigInt(i.consolePID, true)
				if i.Enabled = 1 && ProcessExist(i.apolloPID)
					continue
				if i.Enabled = 1 && FileExist(i.configFile)
					FileDelete(i.configFile)
				if i.Enabled = 1 && FileExist(i.logFile)
					FileDelete(i.logFile)
				if i.Enabled = 1 && FileExist(i.appsFile)
					FileDelete(i.appsFile)

				for process in PIDsListFromExeName("sunshine.exe")
					SendSigInt(process, true)
				for process in PIDsListFromExeName("adb.exe")
					SendSigInt(process, true)
				for process in PIDsListFromExeName("scrcpy.exe")
					SendSigInt(process, true)
				for process in PIDsListFromExeName("gnirehtet.exe")
					SendSigInt(process, true)
			}
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
	guiItems["InstanceEnableCheckbox"].Text := i.Enabled ? ProcessExist(i.apolloPID)  ? "Running: " i.apolloPID "" : "Stopped" :  ProcessExist(i.apolloPID) ? "To be Disabled" : "Disabled"

}
ApplyLockState() {
	global settingsLocked, guiItems, userSettings, currentlySelectedIndex

	isEnabled(cond := true) => cond ? 1 : 0
	isReadOnly(cond := true) => cond ? "+ReadOnly" : "-ReadOnly"

	textBoxes := ["PathsApolloBox"]
	checkBoxes := ["InstanceEnableCheckbox", "FleetAutoStartCheckBox", "AndroidReverseTetheringCheckbox", "AndroidMicCheckbox", "AndroidCamCheckbox", "FleetSyncVolCheckBox", "FleetRemoveDisconnectCheckbox"]
	buttons := ["FleetButtonDelete", "FleetButtonAdd", "PathsApolloBrowseButton"]
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
			UpdateWindowPosition()
			userSettings["Window"].cmdApply := 1
			SaveUserSettings()
			Reload
		}
	}
	ApplyLockState()
	UpdateButtonsLabels()

}
ExitMyApp() {
	global myGui, savedSettings
	UpdateWindowPosition()
	userSettings["Window"].cmdExit := 1
	SaveUserSettings()
	myGui.Destroy()
	ExitApp()
}
MinimizemyGui(*) {
    global myGui, savedSettings
    ; Make sure window exists
    if !WinExist("ahk_id " myGui.Hwnd)
        return  ; Nothing to do

    ; Get position BEFORE hiding
	UpdateWindowPosition()

    userSettings["Window"].lastState := 0
    ; Now hide the window
    myGui.Hide()
}
RestoremyGui() {
	global myGui, savedSettings

	h := (userSettings["Window"].logShow = 0 ? 198 : 600)
	x := savedSettings["Window"].xPos
	y := savedSettings["Window"].yPos

	xC := (A_ScreenWidth - 580)/2 
	yC := (A_ScreenHeight - h)/2

	if (x > SysGet(78) || y > SysGet(79)){
		x := xC
		y := yC
	}

	if (savedSettings["Window"].restorePosition = 1) 
		myGui.Show("x" x " y" y " w580 h" h)
	else
		myGui.Show("x" xC " y" yC "w580 h" h)

	savedSettings["Window"].lastState := 1
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
	baseDesktopApp := Map(
		"image-path", "desktop.png",
		"name", "Desktop",
		"state-cmd", [],
		"terminate-on-pause", m.RemoveDisconnected ? JSON.true : JSON.false,
	)
	baseAppsJson["apps"].Push(baseDesktopApp)

	for i in f {
		baseConfig := CreateConfigMap(i)
		thisConfig := FileExist(i.configFile)? ConfRead(i.configFile) : DeepClone(baseConfig)
		if MirrorMapItemsIntoAnother(baseConfig, thisConfig)
			if ConfWrite(i.configFile, thisConfig)
				i.configChange := 1

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
						if !app.Has("terminate-on-pause") || (app["terminate-on-pause"] = JSON.true ? !m.RemoveDisconnected : m.RemoveDisconnected) {
							app["terminate-on-pause"] := m.RemoveDisconnected ? JSON.true : JSON.false
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
					FileDelete(i.appsFile)
					FileAppend(JSON.stringify(currentJson), i.appsFile)
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
	)
	staticOptions := Map(
		"headless_mode", "enabled"
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
    workingDir :=  SubStr(exePath, 1, InStr(exePath, "\",, -1) - 1)
    psexecPath := savedSettings["Paths"].paexecExe
    sessionId := DllCall("Kernel32.dll\WTSGetActiveConsoleSessionId")
    tmpFile := A_Temp "\apollo-fleet-" id ".txt"
    
    ; Delete any existing file first
    if FileExist(tmpFile)
        FileDelete tmpFile

    psCmd := "$p=Start-Process -WindowStyle Hidden -FilePath '" . exePath . "' -ArgumentList '" . args . "' -PassThru;$p.Id>'" . tmpFile . "'"

	cmd := Format('"{1}" -accepteula -i {2} -w "{3}" -s powershell -Command "{4}"', psexecPath, sessionId, workingDir, psCmd)

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
	global savedSettings, launching := Map(), lastPID := Map(), settingsUpdating := false
	f := savedSettings["Fleet"]
	p := savedSettings["Paths"]

	CleanConfigAndKillPIDs()

	for i in f 
		if i.Enabled{
			lastPID[i.id] := i.apolloPID
			launching[i.id] := true
			MaintainInstanceStatus(i.id)
		}

	SetTimer(UpdateAndSavePIDs, 1000)
}
CleanConfigAndKillPIDs() {
	global savedSettings
	f := savedSettings["Fleet"]
	p := savedSettings["Paths"]

	fileTypes := ["configFile","stateFile", "appsFile", "logFile"]

	keepPIDs := []
	keepFiles := []
	for i in f {
		if i.Enabled && !i.configChange
			keepPIDs.Push(i.apolloPID)
		for file in fileTypes
				if FileExist(i.%file%)
					keepFiles.Push(i.%file%)
	}
	KillProcessesExcept("sunshine.exe", keepPIDs, 5000)
	Loop Files p.Config . '\*.*' 
		if !ArrayHas(keepFiles, A_LoopFileFullPath)
			try
				FileDelete(A_LoopFileFullPath)
}
MaintainInstanceStatus(id){
	SetTimer(() => LaunchApolloInstance(id), 5000)
}
DeleteApolloMaintainTimer(id){
	SetTimer(() => LaunchApolloInstance(id), 0)
}
LaunchApolloInstance(id) {
	global savedSettings, launching, lastPID, settingsUpdating
	while settingsUpdating
		sleep 100
	launching[id] := true
	i := savedSettings["Fleet"][id]
	if !i.Enabled || !FileExist(i.configFile) || !FileExist(i.appsFile)
		return
	else if lastPID[id] = 0 || !ProcessExist(lastPID[id]) 
		lastPID[id] := RunPsExecAndGetPID(savedSettings["Paths"].apolloExe, i.configFile, i.id)
	Sleep 100
	launching[id] := false
}
UpdateAndSavePIDs(){
	global savedSettings, lastPID, launching
	f := savedSettings["Fleet"]
	p := savedSettings["Paths"]
	settingsUpdating := true
	for id in launching
		if launching[id]
			return
	
	newPID := false
	for i in f
		if lastPID[i.id] != i.apolloPID {
			i.apolloPID := lastPID[i.id]
			newPID := true
		}
	if newPID{
		UrgentSettingWrite(savedSettings, "Fleet")
		CleanConfigAndKillPIDs()
	}
	Sleep 100
	settingsUpdating := false

}
UrgentSettingWrite(srcSettings, group){
	global savedSettings, userSettings
	;transientMap := Map()
	;transientMap := DeepClone(srcSettings)
	;savedSettings[group] := DeepClone(transientMap[group])
	;userSettings[group] := DeepClone(transientMap[group])
	WriteSettingsFile(srcSettings, , group)
	bootstrapSettings()
}

FleetRemoveDisconnected(*){
}

ADBWatchDog(*){
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
	global userSettings, guiItems, initDone
	w := userSettings["Window"]
	w.cmdReload := 0
	w.cmdExit := 0
	w.cmdApply := 0
	SaveUserSettings()
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
	global savedSettings

	r := savedSettings["Runtime"]
	p := savedSettings["Paths"]

	KillProcessesExcept("gnirehtet.exe", r.gnirehtetPID, 3000)

	if !ProcessExist(r.gnirehtetPID) {
		r.gnirehtetPID := RunAndGetPID(p.gnirehtetExe, "autorun")
		UrgentSettingWrite(savedSettings, "Runtime")
	}
	; TODO detect fault or output connections log or more nice features...
}

ProcessRunning(pid){
	return !!ProcessExist(pid)
}

UpdateStatusArea() {
	global savedSettings, guiItems, msgTimeout

	f := savedSettings["Fleet"]
	r := savedSettings["Runtime"]
	if  msgTimeout {
		valid := f.Length > 0
		apolloRunning := valid ? 1 : 0
		for i in f {
			if i.Enabled = 0
				continue
			else if !ProcessRunning(i.apolloPID) {
				apolloRunning := 0
				break
			}
		}
		gnirehtetRunning := ProcessRunning(r.gnirehtetPID)
		androidMicRunning := ProcessRunning(r.scrcpyMicPID)
		androidCamRunning := ProcessRunning(r.scrcpyCamPID)

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
	static colors := ["Black", "Blue", "Orange", "Red"]
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
    if !FileExist(i.LogFile) {
        return 0
    }
    
    content := FileRead(i.LogFile)
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
	global savedSettings

	static lastSystemVolume := -1
    static lastSystemMute := -1
	static desiredVolume := 0

	static counter := -1
	static systemDevice := AudioDevice.GetDefault()

	static appsVol := Map()

	counter += 1
	f := savedSettings["Fleet"]
	if counter = 0 {
		systemDevice := AudioDevice.GetDefault()
		for i in savedSettings["Fleet"]
			if i.Enabled && ProcessExist(i.apolloPID)
				if i.AudioDevice = "Unset" && AppVolume(i.apolloPID).IsValid()
					appsVol[i.apolloPID] := AppVolume(i.apolloPID)
				else if i.AudioDevice != "Unset" && AppVolume(i.apolloPID, GetDeviceID(i.AudioDevice)).IsValid()
					appsVol[i.apolloPID] := AppVolume(i.apolloPID, GetDeviceID(i.AudioDevice))
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

MaintainScrcpyProcess(pid, dev, cmd) {
    global savedSettings, guiItems, androidDevicesMap

    p := savedSettings["Paths"]

    static newPID := pid

    deviceConnected := androidDevicesMap.Has(dev) && androidDevicesMap[dev] = "Connected"
    Running := newPID ? ProcessExist(newPID) : 0

	if (deviceConnected && !Running) {        
		if ProcessExist(pid)
			SendSigInt(pid, true)

        RunWait(p.adbExe ' -s ' dev ' shell input keyevent KEYCODE_WAKEUP', , 'Hide')
        newPID := RunAndGetPID(p.scrcpyExe, " -s "  dev " " cmd)
    } else if (!deviceConnected && Running) {
        if SendSigInt(dev, true)
            newPID := 0
    }
    
    if (newPID > -1 && newPID != pid) {
        pid := newPID
        UrgentSettingWrite(savedSettings, "Runtime")
    }
}

CleanScrcpyMicProcess(){
	global savedSettings, guiItems
	r := savedSettings["Runtime"]
	if SendSigInt(r.scrcpyMicPID, true){
		r.scrcpyMicPID := 0
		UrgentSettingWrite(savedSettings, "Runtime")
	}
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
	r := savedSettings["Runtime"]
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
			SetTimer(() => MaintainScrcpyProcess(scMic, a.MicDeviceID, "--no-video --no-window --audio-source=mic"), 500)
		if a.CamEnable && a.CamDeviceID != "Unset"
			SetTimer(() => MaintainScrcpyProcess(scCam, a.CamDeviceID, "--video-source=camera --no-audio"), 500)
	} else {
		SetTimer(() => KillProcessesExcept("adb.exe", , 3000), -1) ; TODO maybe use adb-kill server here
		SetTimer(() => KillProcessesExcept("scrcpy.exe", , 3000), -1)
	}
	androidBootsraped := true
	FinishBootStrap()
}









global myGui, guiItems, userSettings, savedSettings, initDone := false
bootstrapSettings()
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