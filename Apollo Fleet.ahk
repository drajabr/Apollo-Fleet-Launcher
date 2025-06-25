;@Ahk2Exe-UpdateManifest 1 , Apollo Fleet Launcher
;@Ahk2Exe-SetVersion 0.1.1
;@Ahk2Exe-SetName ApolloFleet
;@Ahk2Exe-SetMainIcon ./icons/9.ico
;@Ahk2Exe-SetDescription Manage Multiple Apollo Streaming Instances
;@Ahk2Exe-SetCopyright Copyright (C) 2025 @drajabr

#Requires Autohotkey v2

#Include ./lib/exAudio.ahk
#Include ./lib/jsongo.v2.ahk
#Include ./lib/StdOutToVar.ahk

ConfRead(FilePath, Param := "", Default := "") {
    ; Check if file exists
    if !FileExist(FilePath)
        throw Error("Config file not found: " . FilePath)

    ; Initialize the map
    confMap := Map()
    
    ; Read the file line by line
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
    
    ; If a specific parameter is requested
    if (Param != "")
    {
        return confMap.Has(Param) ? confMap[Param] : Default
    }
    else
    {
        ; No parameter requested: return the whole map
        return confMap
    }
}

ConfWrite(configFile, configMap) {
	lines := ""
	for Key, Value in configMap
			lines.=(Key . " = " . Value . "`n")
	; Write back all lines
	if FileExist(configFile)
		FileDelete configFile  ; Remove old file
	FileAppend lines, configFile
	FileOpen(configFile, "a").Close()
}

ReadSettingsFile(Settings := Map(), File := "settings.ini", groups := "all" ) {
    ; Create default Maps
    for k in ["Manager", "Window", "Paths", "Fleet", "Android"]
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
}

ReadSettingsGroup(File, group, Settings) {
    switch group {
        case "Manager":
			m := Settings["Manager"]
			m.AutoLaunch := IniRead(File, "Manager", "AutoLaunch", 1) = "1" ? 1 : 0
            m.SyncVolume := IniRead(File, "Manager", "SyncVolume", 1) = "1" ? 1 : 0
            m.RemoveDisconnected := IniRead(File, "Manager", "RemoveDisconnected", "true")
            m.SyncSettings := IniRead(File, "Manager", "SyncSettings", 1) = "1" ? 1 : 0
			m.StockServiceEnabled := 1
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
			; TODO: fix save settings from webui, use default conf dir
			; OR wait when apollo support working outside its own dir
        case "Android":
            a := Settings["Android"]
            a.ReverseTethering := IniRead(File, "Android", "ReverseTethering", 1) = "1" ? 1 : 0
            a.gnirehtetPID := IniRead(File, "Android", "gnirehtetPID", 0)
            a.MicDeviceID := IniRead(File, "Android", "MicDeviceID", "Unset")
			a.MicEnable := IniRead(File, "Android", "MicEnable", a.MicDeviceID = "Unset" ? 0 : 1) = "1" ? 1 : 0
            a.scrcpyMicPID := IniRead(File, "Android", "scrcpyMicPID", 0)
            a.CamDeviceID := IniRead(File, "Android", "CamDeviceID", "Unset")
			a.CamEnable := IniRead(File, "Android", "CamEnable", a.CamDeviceID = "Unset" ? 0 : 1) = "1" ? 1 : 0
            a.scrcpyCamPID := IniRead(File, "Android", "scrcpyCamPID", 0)
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
					i.configFile := configp "\fleet-" i.id ".conf"
					i.logFile := configp "\fleet-" i.id ".log"
					i.appsFile := configp "\apps-" i.id ".json"
					i.stateFile := configp "\state-" i.id ".json"
					i.consolePID := IniRead(File, section, "consolePID", 0)
					i.apolloPID := IniRead(File, section, "apolloPID", 0)
					i.AudioDevice := IniRead(File, section, "AudioDevice", "Unset")
					i.AutoCaptureSink := i.AudioDevice = "Unset" ? "enabled" : "disabled"
					f.Push(i)
                }
			if f.Length = 0 {
				i := {} ; Create a new object for each i
				i.id := 1
				i.Port := 11000
				i.Name := "Instance " . i.id
				i.Enabled := 1
				i.AudioDevice := "Unset"
				i.AutoCaptureSink := i.AudioDevice = "Unset" ? "enabled" : "disabled"
				i.configFile := configp "\fleet-" i.id ".conf"
				i.logFile := configp "\fleet-" i.id ".log"
				i.stateFile :=  configp "\state-" i.id ".json"
				i.appsFile := configp "\apps-" i.id ".json"
				i.stateFile := configp "\state-" i.id ".json"	
				i.consolePID := 0
				i.apolloPID := 0	
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
		if changed
			FileOpen(File, "a").Close()
	} else {
		FileAppend("", File)
		WriteSettingsFile(Settings, File, groups) ; Retry writing settings if file was just created
	}
	while changed && (FileRead(File) = lastContents) { ; TODO Check do we really need this? 
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
        case "Manager":
			m := Settings["Manager"]
			WriteIfChanged(File, "Manager", "AutoLaunch", m.AutoLaunch)
			WriteIfChanged(File, "Manager", "SyncVolume", m.SyncVolume)
			WriteIfChanged(File, "Manager", "RemoveDisconnected", m.RemoveDisconnected)
			WriteIfChanged(File, "Manager", "ShowErrors", m.ShowErrors)
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

        case "Paths":
			p := Settings["Paths"]
			WriteIfChanged(File, "Paths", "Apollo", p.Apollo)
			WriteIfChanged(File, "Paths", "Config", p.Config)
			WriteIfChanged(File, "Paths", "ADB", p.ADBTools)
		
        case "Android":
			a := Settings["Android"]
			WriteIfChanged(File, "Android", "ReverseTethering", a.ReverseTethering)
			WriteIfChanged(File, "Android", "gnirehtetPID", a.gnirehtetPID)
			WriteIfChanged(File, "Android", "MicDeviceID", a.MicDeviceID)
			WriteIfChanged(File, "Android", "MicEnable", a.MicEnable)
			WriteIfChanged(File, "Android", "scrcpyMicPID", a.scrcpyMicPID)
			WriteIfChanged(File, "Android", "CamEnable", a.CamEnable)
			WriteIfChanged(File, "Android", "CamDeviceID", a.CamDeviceID)
			WriteIfChanged(File, "Android", "scrcpyCamPID", a.scrcpyCamPID)
		
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
				IniWrite(i.consolePID, File, section, "consolePID")
				IniWrite(i.apolloPID, File, section, "apolloPID")
				IniWrite(i.AudioDevice, File, section, "AudioDevice")
				; IniWrite(i.Audio, File, section, "Audio") ; TODO
			}
	}
	return changed
}
InitmyGui() {
	global savedSettings

	;TODO implement dark theme and follow system theme if possible 
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
	guiItems["FleetAutoLaunchCheckBox"] := myGui.Add("CheckBox", "x334 y16 w162 h23", "Auto Launch Apollo Fleet")
	guiItems["FleetSyncVolCheckBox"] := myGui.Add("CheckBox", "x334 y40 w162 h23", "Sync Device Volume Level")
	guiItems["FleetRemoveDisconnectCheckbox"] := myGui.Add("CheckBox", "x334 y64 w167 h23", "Remove on Disconnect")

	myGui.Add("GroupBox", "x318 y96 w196 h95", "Android Clients")
	guiItems["AndroidReverseTetheringCheckbox"] := myGui.Add("CheckBox", "x334 y112 w139 h23", "ADB Reverse Tethering")
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
	guiItems["PathsApolloBox"] := myGui.Add("Edit", "x53 y16 w212 h23")
	myGui.Add("Text", "x16 y21", "Apollo:")
	guiItems["PathsApolloBrowseButton"] := myGui.Add("Button", "x267 y16 w30 h25", "📂")

	guiItems["FleetListBox"] := myGui.Add("ListBox", "x16 y50 w100 h82 +0x100 Choose1")
	guiItems["FleetListBox"].Enabled := 0
	myGui.Add("Text", "x123 y54", "Name:Port")
	guiItems["InstanceNameBox"] := myGui.Add("Edit", "x176 y48 w80 h23")
	guiItems["InstancePortBox"] := myGui.Add("Edit", "x256 y48 w40 h23 +ReadOnly", "")

	myGui.Add("Text", "x123 y82", "Audio :")
	
	presetAudioDevices := ["Unset"]
	for i in savedSettings["Fleet"]
		if !presetAudioDevices.Has(i.AudioDevice)
			presetAudioDevices.Push(i.AudioDevice)
	guiItems["InstanceAudioSelector"] := myGui.Add("DropDownList", "x176 y79 w120 Choose1", presetAudioDevices)

	myGui.Add("Text", "x123 y110 ", "Link:")
	myLink := "https://localhost:00000"
	guiItems["FleetLinkBox"] := myGui.Add("Link", "x176 y110", '<a href="' . myLink . '">' . myLink . '</a>')

	myGui.Add("Text", "x123 y137 ", "Enable:")
	guiItems["InstanceEnableCheckbox"] := myGui.Add("CheckBox", "x176 y137", "Enabled")

	guiItems["FleetButtonAdd"] := myGui.Add("Button", "x43 y134 w75 h23", "Add")
	guiItems["FleetButtonDelete"] := myGui.Add("Button", "x14 y134 w27 h23", "✖")
	; TODO actually functional status area, 
	guiItems["StatusApollo"] := myGui.Add("Text", "x16 y172 w70", "❎ Apollo ")
	guiItems["StatusGnirehtet"] := myGui.Add("Text", "x76 y172 w70", "❎ Gnirehtet")
	guiItems["StatusAndroidMic"] := myGui.Add("Text", "x146 y172 w75", "❎ AndroidMic")
	guiItems["StatusAndroidCam"] := myGui.Add("Text", "x226 y172 w75", "❎ AndroidCam")
	guiItems["StatusMessage"] := myGui.Add("Text", "x16 y172 w290")
	ShowMessage("Initialized All GUI Elements")

	guiItems["LogTextBox"] := myGui.Add("Edit", "x8 y199 w562 h393 -VScroll +ReadOnly")
	myGui.Title := "Apollo Fleet Manager"
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
	guiItems["FleetAutoLaunchCheckBox"].Value := m.AutoLaunch
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
	;RefreshAudioSelector() TODO Revist if we still need this here
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

	guiItems["FleetAutoLaunchCheckBox"].OnEvent("Click", HandleCheckBoxes) ; (*) => userSettings["Manager"].AutoLaunch := guiItems["FleetAutoLaunchCheckBox"].Value)
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
	RefreshAdbDevices()
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
	i.AudioDevice := guiItems["InstanceAudioSelector"].Text	; TODO devices list array and index instead of text, or maybe its just fine to use text? 
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
	userSettings["Manager"].AutoLaunch := guiItems["FleetAutoLaunchCheckBox"].Value
	launchChildren := ["FleetSyncVolCheckBox", "FleetRemoveDisconnectCheckbox"]
	launchChildrenLock := userSettings["Manager"].AutoLaunch = 0
	for item in launchChildren
		guiItems[item].Enabled := launchChildrenLock ? 0 : 1
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
	i.consolePID := 0
	i.apolloPID := 0
	userSettings["Fleet"].Push(i)
	currentlySelectedIndex := userSettings["Fleet"].Length
	RefreshFleetList()
	HandleListChange()
	}
}
HandleInstanceDeleteButton(*){ 
	global userSettings, guiItems, currentlySelectedIndex
	if (userSettings["Fleet"].Length > 1){ ; TODO Remake this?
		userSettings["Fleet"].RemoveAt(currentlySelectedIndex) ; MUST USE REMOVEAT INSTEAD OF DELETE TO REMOVE THE ITEM COMPLETELY NOT JUST ITS VALUE
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

	RefreshAudioSelector()
	guiItems["InstanceAudioSelector"].Text := ArrayHas(audioDevicesList, i.AudioDevice) ? i.AudioDevice : "Unset"
	guiItems["InstanceEnableCheckbox"].Value := i.Enabled
	guiItems["InstanceEnableCheckbox"].Text := userSettings["Fleet"][currentlySelectedIndex].Enabled ? "Enabled" : "Disabled"
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
	SetTimer(MaintainApolloProcesses, 0)
	SetTimer(MaintainGnirehtetProcess, 0)
	SetTimer(RefreshAdbDevices , 0)
	SetTimer(MaintainScrcpyMicProcess, 0)
	SetTimer(MaintainScrcpyCamProcess, 0)

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
				SendSigInt(savedSettings["Android"].gnirehtetPID, true)
			if savedSettings["Android"].MicEnable 
				SendSigInt(savedSettings["Android"].scrcpyMicPID, true)
			if savedSettings["Android"].CamEnable
				SendSigInt(savedSettings["Android"].scrcpyCamPID, true)
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
	w := userSettings["Window"]
	if !initDone
		return false
	for category in userSettings
		if category != "Window" && DeepCompare(savedSettings[category], userSettings[category], category){
			return true
		}
	return false
}

UpdateButtonsLabels(){
	global guiItems, settingsLocked
	guiItems["ButtonLockSettings"].Text := (UserSettingsWaiting() && !settingsLocked) ? "Apply" : settingsLocked ? "🔒" : "🔓" 
	guiItems["ButtonReload"].Text := settingsLocked ?  "Reload" : "Cancel"
	; TODO here we could also show the running/not running status of each selected instance 
}
ApplyLockState() {
	global settingsLocked, guiItems, userSettings, currentlySelectedIndex

	isEnabled(cond := true) => cond ? 1 : 0
	isReadOnly(cond := true) => cond ? "+ReadOnly" : "-ReadOnly"

	textBoxes := ["PathsApolloBox"]
	checkBoxes := ["InstanceEnableCheckbox", "FleetAutoLaunchCheckBox", "AndroidReverseTetheringCheckbox", "AndroidMicCheckbox", "AndroidCamCheckbox"]
	buttons := ["FleetButtonDelete", "FleetButtonAdd", "PathsApolloBrowseButton"]
	androidSelectors := Map(
		"AndroidMicSelector", "AndroidMicCheckbox",
		"AndroidCamSelector", "AndroidCamCheckbox"
	)
	inputBoxes := ["InstanceNameBox", "InstancePortBox"]
	inputSelectors := ["InstanceAudioSelector"]
	launchChildren := ["FleetSyncVolCheckBox", "FleetRemoveDisconnectCheckbox"]

	launchChildrenLock := userSettings["Manager"].AutoLaunch = 0

	for item in launchChildren
		guiItems[item].Enabled := isEnabled(!settingsLocked && !launchChildrenLock)

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
	; TODO verify settings before save? 
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
MapDeleteItemIfExist(map, option){
	if map.Has(option){
		map.Delete(option)
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

	defaultAppsTemplate :="
	(
	{
		"apps": [
			{
				"cmd": "",
				"exit-timeout": 0,
				"image-path": "desktop.png",
				"name": "Desktop",
				"state-cmd": [],
				"terminate-on-pause": "true"
			}
		],
		"env": {},
		"version": 2
	}
	)"
	baseApps := jsongo.Parse(defaultAppsTemplate)
	app := baseApps["apps"][1]
	if app["terminate-on-pause"] != m.RemoveDisconnected 
		app["terminate-on-pause"] := m.RemoveDisconnected ? "true" : "false"

	appsJsonText := jsongo.Stringify(baseApps, , '    ')
	appsJsonText := RegExReplace(appsJsonText, ':\s*"true"', ': true')
	appsJsonText := RegExReplace(appsJsonText, ':\s*"false"', ': false')

	; TODO: Simple text find and replace instead of JXON maybe enough?

	for i in f {
		i.configChange := false
		i.baseConfig := CreateConfigMap(i)
		if !FileExist(i.configFile) {
			i.currentConfig := DeepClone(i.baseConfig)
			if MirrorMapItemsIntoAnother(i.baseConfig, i.currentConfig)
				i.configChange := true
		} else {
			i.currentConfig := ConfRead(i.configFile)
			if MirrorMapItemsIntoAnother(i.baseConfig, i.currentConfig)
				i.configChange := true
		}
		if i.configChange {
			ConfWrite(i.configFile, i.currentConfig)
			if FileExist(i.appsFile)
				FileDelete(i.appsFile)	; delete old file if exists
			FileAppend(appsJsonText, i.appsFile)
		}
	}
}
MirrorMapItemsIntoAnother(inputMap, outputMap){
	modified := false
		for option, value in inputMap {
			if MapSetIfChanged(outputMap, option, value)
				modified := true
			if value = "Unset"
				MapDeleteItemIfExist(outputMap, option)
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
	for option, value in optionsMap	;TODO depricate this keep_sink_default unset thing
		configMap.Set(option, option = "keep_sink_default" ? "Unset" : instance.%value%)
	
	
	for option, value in staticOptions
		configMap.Set(option, value)

	return configMap
}
bootstrapSettings() {
	global savedSettings := Map(), userSettings := Map(), runtimeSettings := Map()

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
	Sleep(10)
	for process in ComObject("WbemScripting.SWbemLocator").ConnectServer().ExecQuery("Select * from Win32_Process where ParentProcessId=" consolePID)
		if InStr(process.CommandLine, exePath) {
			apolloPID := process.ProcessId
			break
		}
		
	return [consolePID, apolloPID]
}

ArrayHas(arr, val) {
    for _, v in arr
        if (v = val)
            return true
    return false
}

FleetLaunchFleet(){
	global savedSettings
	f := savedSettings["Fleet"]
	p := savedSettings["Paths"]

	fileTypes := ["configFile","stateFile", "appsFile", "logFile"]

	keepPIDs := []
	keepFiles := []
	for i in f{
		if (i.Enabled && !i.configChange)
			keepPIDs.Push(i.apolloPID)
		for file in fileTypes
				if FileExist(i.%file%) && file != "logFile"
					keepFiles.Push(i.%file%)
	}

	KillProcessesExcept("sunshine.exe", keepPIDs, 5000)

	Loop Files p.Config . '\*.*' 
		if !ArrayHas(keepFiles, A_LoopFileFullPath)
			try
				FileDelete(A_LoopFileFullPath)
		
	exe := savedSettings["Paths"].apolloExe
	newPID := false
	for i in f
		if i.Enabled && (i.configChange || !ProcessExist(i.apolloPID)) {	; TODO add test for the instance if it responds or not, also, may check if display is connected deattach it/force exit? 
			pids := RunAndGetPIDs(exe, i.configFile)
			i.consolePID := pids[1]
			i.apolloPID := pids[2]
			newPID := true
		}
	if newPID
		UrgentSettingWrite(savedSettings, "Fleet")
	;MsgBox(savedSettings["Fleet"][1].consolePID . ":" . savedSettings["Fleet"][1].apolloPID)
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
    autoLaunch := savedSettings["Manager"].AutoLaunch
    stockService := savedSettings["Manager"].StockServiceEnabled
    if stockService {
        if RunWait("cmd /c sc query ApolloService >nul 2>&1", , "Hide") == 0 {
            if autoLaunch {
                RunWait('sc stop ApolloService', , "Hide")
                RunWait('sc config ApolloService start=disabled', , "Hide")
            } else {
				; TODO if this is the first run lets keep the stock service disabled if we disable autoLaunch 
                RunWait('sc config ApolloService start=auto', , "Hide")
                RunWait('sc start ApolloService', , "Hide")
            }
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

	if autoLaunch {
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
KillProcessesExcept(pName, keep := [0], wait := 1000){
	
	if Type(keep) != "Array"
		keep := [keep]  ; Ensure keep is an array

	pids := PIDsListFromExeName(pName)
	targetKill := []
	for pid in pids
		if !ArrayHas(keep, pid){
			KillWithoutBlocking(pid, true, 0)
			targetKill.Push(pid)
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
KillWithoutBlocking(pid, force:=false, wait:=1000) {
	SetTimer(()=>SendSigInt(pid, force, wait), -1)
}
MaintainGnirehtetProcess(){
	global savedSettings
	static firstRun := true

	a := savedSettings["Android"]
	p := savedSettings["Paths"]

	if firstRun 
		if KillProcessesExcept("gnirehtet.exe", a.gnirehtetPID)
			firstRun := false

	if !ProcessExist(a.gnirehtetPID) || a.gnirehtetPID = 0 {
		exe := p.gnirehtetExe
		pids := RunAndGetPIDs(exe, "autorun")
		a.gnirehtetPID := pids[2]
		UrgentSettingWrite(savedSettings, "Android")
	}
	; TODO detect fault or output connections log or more nice features...
}

ProcessRunning(pid){
	return !!ProcessExist(pid)
}

UpdateStatusArea() {
	global savedSettings, guiItems, msgTimeout
	f := savedSettings["Fleet"]
	a := savedSettings["Android"]
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
		gnirehtetRunning := ProcessRunning(a.gnirehtetPID)
		androidMicRunning := ProcessRunning(a.scrcpyMicPID)
		androidCamRunning := ProcessRunning(a.scrcpyCamPID)

		statusItems := Map(
			"StatusApollo", "apolloRunning",
			"StatusGnirehtet", "gnirehtetRunning",
			"StatusAndroidMic", "androidMicRunning",
			"StatusAndroidCam", "androidCamRunning"
		)

		for item, status in statusItems 
			guiItems[item].Value := (%status%? "✅" : "❎") . SubStr(guiItems[item].Value, 2)
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
			CreateTimerForInstance(A_Index)
}
CreateTimerForInstance(id) {
    SetTimer(() => ProcessApolloLog(id), 500)
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

MaintainApolloProcesses(){
	global savedSettings, userSettings, currentlySelectedIndex
	static firstRun := true

	f := savedSettings["Fleet"]
	p := savedSettings["Paths"]
	m := savedSettings["Manager"]

	; TODO WATCH APOLLO PIDS AND IN CASE ONE DIES RESTART IT AND RECORD NEW PIDS

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

	if counter = 0 {
		systemDevice := AudioDevice.GetDefault()
		for i in savedSettings["Fleet"]
			if i.Enabled && ProcessExist(i.apolloPID)
				appsVol[i.id] := AppVolume(i.apolloPID)
			else if appsVol.Has(i.id)
				appsVol.Delete(i.id)
	} else if counter = 10
		counter := -1

		
    ; Get current system volume and mute status
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
	} 
	else {
		for id, appVol in appsVol {
			if (appVol.GetVolume() != desiredVolume){
				;MsgBox("System Volume: " systemDevice.GetVolume() " id: " id " CurrentVol: " appVol.GetVolume())
				appVol.SetVolume(desiredVolume)

			}
		}
	}
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
	a := savedSettings["Android"]

	micID := a.MicDeviceID
	camID := a.CamDeviceID

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
	}
	if !adbReady
		adbReady := true
}

MaintainScrcpyMicProcess() {
    global savedSettings, guiItems, androidDevicesMap, adbReady

    a := savedSettings["Android"]
    p := savedSettings["Paths"]

    static newPID := -1

	if !adbReady
		return

    deviceConnected := androidDevicesMap.Has(a.MicDeviceID) && androidDevicesMap[a.MicDeviceID] = "Connected"
    processRunning := a.scrcpyMicPID ? ProcessExist(a.scrcpyMicPID) : 0

	if (deviceConnected && !processRunning) {        
		if ProcessExist(a.scrcpyMicPID)
			SendSigInt(a.scrcpyMicPID, true)

        RunWait(p.adbExe ' -s ' a.MicDeviceID ' shell input keyevent KEYCODE_WAKEUP', , 'Hide')
        pids := RunAndGetPIDs(p.scrcpyExe, " -s " . a.MicDeviceID . " --no-video --no-window --audio-source=mic")
        newPID := pids[2]
    } else if (!deviceConnected && processRunning) {
        if SendSigInt(a.scrcpyMicPID, true)
            newPID := 0
    }
    
    if (newPID > -1 && newPID != a.scrcpyMicPID) {
        a.scrcpyMicPID := newPID
        UrgentSettingWrite(savedSettings, "Android")
    }
}
MaintainScrcpyCamProcess() {
    global savedSettings, guiItems, androidDevicesMap, adbReady

    a := savedSettings["Android"]
    p := savedSettings["Paths"]

    newPID := -1

	if !adbReady
		return

    deviceConnected := androidDevicesMap.Has(a.CamDeviceID) && androidDevicesMap[a.CamDeviceID] = "Connected"
    processRunning := a.scrcpyCamPID ? ProcessExist(a.scrcpyCamPID) : 0

    if (deviceConnected && !processRunning) {
		if ProcessExist(a.scrcpyCamPID) 
			SendSigInt(a.scrcpyCamPID, true)

        RunWait(p.adbExe ' -s ' a.CamDeviceID ' shell input keyevent KEYCODE_WAKEUP', , 'Hide')
        pids := RunAndGetPIDs(p.scrcpyExe, " -s " . a.CamDeviceID . " --video-source=camera --no-audio")
        newPID := pids[2]

    } else if (!deviceConnected && processRunning) {
        if SendSigInt(a.scrcpyCamPID, true)
            newPID := 0
    }
    
    if (newPID > -1 && newPID != a.scrcpyCamPID) {
        a.scrcpyCamPID := newPID
        UrgentSettingWrite(savedSettings, "Android")
    }
}
CleanScrcpyMicProcess(){
	global savedSettings, guiItems
	a := savedSettings["Android"]
	if SendSigInt(a.scrcpyMicPID, true){
		a.scrcpyMicPID := 0
		UrgentSettingWrite(savedSettings, "Android")
	}
}

bootstrapApollo(){
	global savedSettings, guiItems, currentlySelectedIndex, apolloBootsraped
	SetupFleetTask()
	if true {	;savedSettings["Manager"].AutoLaunch to be used for startup task at log on
		FleetConfigInit()
		FleetLaunchFleet()
		SetTimer(MaintainApolloProcesses, 1000)
		FleetInitApolloLogWatch()
		if savedSettings["Manager"].SyncVolume
			SetTimer(SyncApolloVolume, 100)
	} 
	apolloBootsraped := true
	FinishBootStrap()
}

bootstrapGnirehtet(){
	global savedSettings, guiItems, gnirehtetBootsraped
	if savedSettings["Android"].ReverseTethering {
		ShowMessage("Starting Gnirehtet...")
		SetTimer(MaintainGnirehtetProcess, 1000)
	} else {
		SetTimer(() => KillProcessesExcept("gnirehtet.exe", , 3000), -1)
	}
	gnirehtetBootsraped := true
	FinishBootStrap()
}

bootstrapAndroid() {
	global savedSettings, guiItems, androidDevicesMap, adbReady, androidBootsraped
	savedRequire := savedSettings["Android"].MicEnable || savedSettings["Android"].CamEnable
	userRequire := userSettings["Android"].MicEnable || userSettings["Android"].CamEnable
	if savedRequire || userRequire {
		KillProcessesExcept("adb.exe", , 5000)
		SetTimer(RefreshAdbDevices , 1000)
		keep := []
		if savedSettings["Android"].MicEnable
			keep.Push(savedSettings["Android"].scrcpyMicPID)
		if savedSettings["Android"].CamEnable
			keep.Push(savedSettings["Android"].scrcpyCamPID)
		KillProcessesExcept("scrcpy.exe", keep, 5000)
		
		if savedSettings["Android"].MicEnable
			SetTimer(MaintainScrcpyMicProcess, 500)
		if savedSettings["Android"].CamEnable
			SetTimer(MaintainScrcpyCamProcess, 500)
	} else {
		SetTimer(() => KillProcessesExcept("adb.exe", , 5000), -1) ; TODO maybe use adb-kill server here
		SetTimer(() => KillProcessesExcept("scrcpy.exe", , 5000), -1) ; TODO maybe use adb-kill server here
	}
	androidBootsraped := true
	FinishBootStrap()
}









global myGui, guiItems, userSettings, savedSettings, runtimeSettings, initDone := false
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