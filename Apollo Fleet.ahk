;@Ahk2Exe-UpdateManifest 1 , Apollo Fleet Launcher
;@Ahk2Exe-SetVersion 0.1.1
;@Ahk2Exe-SetName ApolloFleet
;@Ahk2Exe-SetMainIcon ./icons/9.ico
;@Ahk2Exe-SetDescription Manage Multiple Apollo Streaming Instances
;@Ahk2Exe-SetCopyright Copyright (C) 2025 @drajabr

#Requires Autohotkey v2

#Include ./lib/exAudio.ahk

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
			m.AutoLaunch := IniRead(File, "Manager", "AutoLaunch", 1)
            m.SyncVolume := IniRead(File, "Manager", "SyncVolume", 1)
            m.RemoveDisconnected := IniRead(File, "Manager", "RemoveDisconnected", 1)
            m.SyncSettings := IniRead(File, "Manager", "SyncSettings", 1)
			
        case "Window":
			w := Settings["Window"]
            w.restorePosition := IniRead(File, "Window", "restorePosition", 1)
            w.xPos := IniRead(File, "Window", "xPos", (A_ScreenWidth - 580) / 2)
            w.yPos := IniRead(File, "Window", "yPos", (A_ScreenHeight - 198) / 2)
            w.lastState := IniRead(File, "Window", "lastState", 1)
            w.logShow := IniRead(File, "Window", "logShow", 1)
			w.cmdReload := IniRead(File, "Window", "cmdReload", 0)
			w.cmdExit := IniRead(File, "Window", "cmdExit", 0)

        case "Paths":
            base := A_ScriptDir
			p := Settings["Paths"]
            p.Apollo := IniRead(File, "Paths", "Apollo", "C:\Program Files\Apollo")
            p.apolloExe := Settings["Paths"].Apollo "\sunshine.exe"
            p.Config := IniRead(File, "Paths", "Config", base "\config")
            p.ADBTools := IniRead(File, "Paths", "ADB", base "\bin\platform-tools")
			; TODO: fix save settings from webui, use default conf dir
			; OR wait when apollo support working outside its own dir
        case "Android":
            a := Settings["Android"]
            a.ReverseTethering := IniRead(File, "Android Clients", "ReverseTethering", 1)
            a.gnirehtetPID := IniRead(File, "Android Clients", "gnirehtetPID", 0)
            a.MicDeviceID := IniRead(File, "Android Clients", "MicDeviceID", 0)
			a.MicEnable := a.MicDeviceID = 0 ? 0 : 1
            a.scrcpyMicPID := IniRead(File, "Android Clients", "scrcpyMicPID", 0)
            a.CamDeviceID := IniRead(File, "Android Clients", "CamDeviceID", 0)
			a.CamEnable := a.CamDeviceID = 0 ? 0 : 1
            a.scrcpyCamPID := IniRead(File, "Android Clients", "scrcpyCamPID", 0)

        case "Fleet":
		    Settings["Fleet"] := []
			f := Settings["Fleet"]
            configp := Settings["Paths"].Config
            synced := Settings["Manager"].SyncSettings = 1
			i := {}
			defConfigPath:= Settings["Paths"].Apollo . "\config"
			defaultConfFile := defConfigPath "\sunshine.conf"
			i.id := 0
			i.Name := ConfRead(defaultConfFile, "sunshine_name", "Default")
			i.Port := ConfRead(defaultConfFile, "port", "47989")
			i.Enabled := synced ? 1 : 0
			i.Synced := synced
			i.configFile := defConfigPath "\sunshine.conf"
			i.logFile := defConfigPath "\sunshine.log"
			i.stateFile := defConfigPath "\sunshine_state.json"
			i.appsFile := defConfigPath "\apps.json"
			i.credFile := defConfigPath "\sunshine_state.json"
			i.consolePID := IniRead(File, "Instance0", "consolePID", 0)
			i.apolloPID := IniRead(File, "Instance0", "apolloPID", 0)
			i.AudioDevice := ConfRead(defaultConfFile, "virtual_sink", "Unset")
			i.LastConfigUpdate := IniRead(File, "Instance0", "LastConfigUpdate", 0)
			i.LastReadLogLine := IniRead(File, "Instance0", "LastReadLogLine", 0)
			f.Push(i)
            index := 2
            sections := StrSplit(IniRead(File), "`n")
            for section in sections 
                if (SubStr(section, 1, 8) = "Instance") {
					if SubStr(section, -1)=0
						continue
                    i := {}
					i.id := IsNumber(SubStr(section, -1)) ? SubStr(section, -1) : index
					i.Name := IniRead(File, section, "Name", "i" . index)
					i.Port := IniRead(File, section, "Port", 11000 + index * 1000)
					i.Enabled := IniRead(File, section, "Enabled", 1)
					i.Synced := synced ? IniRead(File, section, "Synced", synced ) : 0
					i.configFile := configp "\fleet-" i.id (i.Synced ? "-synced.conf" : ".conf")
					i.logFile := configp "\fleet-" i.id (i.Synced ? "-synced.log" : ".log")
					i.stateFile := configp "\state-" i.id ".json"
					i.appsFile := i.Synced ? f[1].appsFile : configp "\apps-" i.id ".json"
					i.credFile := configp "\state-" i.id ".json"
					i.consolePID := IniRead(File, section, "consolePID", 0)
					i.apolloPID := IniRead(File, section, "apolloPID", 0)
					i.AudioDevice := IniRead(File, section, "AudioDevice", "Unset")
					i.LastConfigUpdate := IniRead(File, section, "LastConfigUpdate", 0)
					i.LastReadLogLine := IniRead(File, section, "LastReadLogLine", 0)
					f.Push(i)
					index += 1
                }
    }
}

WriteSettingsFile(Settings := Map(), File := "settings.ini", groups := "all") {
    if FileExist(File) {
		if (groups = "all" || InStr(groups, "Manager"))
			WriteSettingsGroup(Settings, File, "Manager")
		if (groups = "all" || InStr(groups, "Window"))
			WriteSettingsGroup(Settings, File, "Window")
		if (groups = "all" || InStr(groups, "Paths"))
			WriteSettingsGroup(Settings, File, "Paths")
		if (groups = "all" || InStr(groups, "Android"))
			WriteSettingsGroup(Settings, File, "Android")
		if (groups = "all" || InStr(groups, "Fleet"))
			WriteSettingsGroup(Settings, File, "Fleet")
	}
}

WriteSettingsGroup(Settings, File, group) {
	WriteIfChanged(file, section, key, value) {
		old := IniRead(file, section, key, "__MISSING__")
		if (old != value)
			IniWrite(value, file, section, key)
	}
    switch group {
        case "Manager":
			m := Settings["Manager"]
			WriteIfChanged(File, "Manager", "AutoLaunch", m.AutoLaunch)
			WriteIfChanged(File, "Manager", "SyncVolume", m.SyncVolume)
			WriteIfChanged(File, "Manager", "RemoveDisconnected", m.RemoveDisconnected)
			WriteIfChanged(File, "Manager", "SyncSettings", m.SyncSettings)

        case "Window":
			w := Settings["Window"]
			WriteIfChanged(File, "Window", "restorePosition", w.restorePosition)
			WriteIfChanged(File, "Window", "xPos", w.xPos)
			WriteIfChanged(File, "Window", "yPos", w.yPos)
			WriteIfChanged(File, "Window", "lastState", w.lastState)
			WriteIfChanged(File, "Window", "logShow", w.logShow)
			WriteIfChanged(File, "Window", "cmdReload", w.cmdReload)
			WriteIfChanged(File, "Window", "cmdExit", w.cmdExit)

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
			WriteIfChanged(File, "Android", "scrcpyMicPID", a.scrcpyMicPID)
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
				IniWrite(i.Synced, File, section, "Synced")
				IniWrite(i.consolePID, File, section, "consolePID")
				IniWrite(i.apolloPID, File, section, "apolloPID")
				IniWrite(i.AudioDevice, File, section, "AudioDevice")
				IniWrite(i.LastConfigUpdate, File, section, "LastConfigUpdate")
				IniWrite(i.LastReadLogLine, File, section, "LastReadLogLine")
				; IniWrite(i.Audio, File, section, "Audio") ; TODO
			}
	}
}
InitmyGui() {
	;TODO implement dark theme and follow system theme if possible 
	global myGui, guiItems := Map()
	if !A_IsCompiled {
		TraySetIcon("./icons/9.ico")
	}
	myGui := Gui("+AlwaysOnTop -MinimizeBox -MaximizeBox")

	guiItems["ButtonLockSettings"] := myGui.Add("Button", "x520 y5 w50 h40", "🔒")
	guiItems["ButtonReload"] := myGui.Add("Button", "x520 y50 w50 h40", "Reload")
	guiItems["ButtonLogsShow"] := myGui.Add("Button", "x520 y101 w50 h40", "Show Logs")
	guiItems["ButtonMinimize"] := myGui.Add("Button", "x520 y150 w50 h40", "Minimize")

	myGui.Add("GroupBox", "x318 y0 w196 h90", "Fleet Options")
	guiItems["FleetAutoLaunchCheckBox"] := myGui.Add("CheckBox", "x334 y16 w162 h23", "Auto Launch Apollo Fleet")
	guiItems["FleetSyncVolCheckBox"] := myGui.Add("CheckBox", "x334 y40 w162 h23", "Sync Device Volume Level")
	guiItems["FleetRemoveDisconnectCheckbox"] := myGui.Add("CheckBox", "x334 y64 w167 h23", "Remove on Disconnect")

	myGui.Add("GroupBox", "x318 y96 w196 h95", "Android Clients")
	guiItems["AndroidReverseTetheringCheckbox"] := myGui.Add("CheckBox", "x334 y112 w139 h23", "ADB Reverse Tethering")
	guiItems["AndroidMicCheckbox"] := myGui.Add("CheckBox", "x334 y140 ", "Mic:")
	guiItems["AndroidMicSelector"] := myGui.Add("DropDownList", "x382 y136 w122 Choose1", ["none"])
	guiItems["AndroidCamCheckbox"] := myGui.Add("CheckBox", "x334 y164 ", "Cam:")
	guiItems["AndroidCamSelector"] := myGui.Add("DropDownList", "x382 y160 w122 Choose1", ["none"])

	myGui.Add("GroupBox", "x8 y0 w300 h192", "Fleet")
	guiItems["PathsApolloBox"] := myGui.Add("Edit", "x53 y16 w212 h23")
	myGui.Add("Text", "x16 y21", "Apollo:")
	guiItems["PathsApolloBrowseButton"] := myGui.Add("Button", "x267 y16 w30 h25", "📂")

	guiItems["FleetListBox"] := myGui.Add("ListBox", "x16 y50 w100 h82 +0x100 Choose1")
	myGui.Add("Text", "x123 y54", "Name:Port")
	guiItems["InstanceNameBox"] := myGui.Add("Edit", "x176 y48 w80 h23")
	guiItems["InstancePortBox"] := myGui.Add("Edit", "x256 y48 w40 h23 +ReadOnly", "")

	myGui.Add("Text", "x123 y82", "Audio :")
	guiItems["InstanceAudioSelector"] := myGui.Add("DropDownList", "x176 y79 w120 Choose1", ["Unset"])

	myGui.Add("Text", "x123 y110 ", "Link:")
	myLink := "https://localhost:" . savedSettings["Fleet"][(savedSettings["Manager"].SyncSettings = 1 ? 1 : currentlySelectedIndex)].Port+1
	guiItems["FleetLinkBox"] := myGui.Add("Link", "x176 y110", '<a href="' . myLink . '">' . myLink . '</a>')

	myGui.Add("Text", "x123 y137 ", "Other Settings:")
	guiItems["InstanceSyncCheckbox"] := myGui.Add("CheckBox", "x196 y137", "Clone from Default")

	guiItems["FleetButtonAdd"] := myGui.Add("Button", "x43 y134 w75 h23", "Add")
	guiItems["FleetButtonDelete"] := myGui.Add("Button", "x14 y134 w27 h23", "✖")
	; TODO actually functional status area, 
	guiItems["StatusArea"] := myGui.Add("Text", "x16 y172 ", "✅ Apollo    ❎ Gnirehtet    ❎ AndroidMic    ❎ AndroidCam")

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
	guiItems["FleetRemoveDisconnectCheckbox"].Value := m.RemoveDisconnected
	guiItems["AndroidReverseTetheringCheckbox"].Value := a.ReverseTethering
	guiItems["AndroidMicCheckbox"].Value := a.MicEnable
	guiItems["AndroidMicSelector"].Value := a.MicDeviceID
	guiItems["AndroidCamCheckbox"].Value := a.CamEnable
	guiItems["AndroidCamSelector"].Value := a.CamDeviceID
	guiItems["PathsApolloBox"].Value := Settings["Paths"].Apollo
	guiItems["ButtonLogsShow"].Text := (Settings["Window"].logShow = 1 ? "Hide Logs" : "Show Logs")
	;guiItems["InstanceAudioSelector"].Enabled :=0
	guiItems["FleetListBox"].Delete()
	guiItems["FleetListBox"].Add(EveryInstanceProp(Settings))
	guiItems["InstanceNameBox"].Value := savedSettings["Fleet"][currentlySelectedIndex].Name
	guiItems["InstancePortBox"].Value := savedSettings["Fleet"][currentlySelectedIndex].Port
	guiItems["InstanceSyncCheckbox"].Value := f[currentlySelectedIndex].Synced 
	RefreshAudioSelector()
	guiItems["InstanceAudioSelector"].Text := f[currentlySelectedIndex].AudioDevice
	UpdateButtonsLabels()
}
EveryInstanceProp(Settings, prop:="Name"){
	isList := []  ; Create an empty array
	for i in Settings["Fleet"] 
		isList.Push(i.%prop%)  ; Add the Name property to the array
	return isList
}
InitmyGuiEvents(){
	global myGui, guiItems
	myGui.OnEvent('Close', (*) => ExitMyApp())
	guiItems["ButtonMinimize"].OnEvent("Click", MinimizemyGui)
	guiItems["ButtonLockSettings"].OnEvent("Click", HandleSettingsLock)
	guiItems["ButtonReload"].OnEvent("Click", HandleReloadButton)
	guiItems["ButtonLogsShow"].OnEvent("Click", HandleLogsButton)
	guiItems["FleetListBox"].OnEvent("Change", HandleListChange)

	guiItems["AndroidReverseTetheringCheckbox"].OnEvent("Click", HandleCheckBoxes) ; (*) => userSettings["Android"].ReverseTethering := guiItems["AndroidReverseTetheringCheckbox"].Value)
	guiItems["AndroidMicCheckbox"].OnEvent("Click", HandleAndroidSelector) ; (*)=> guiItems["AndroidMicSelector"].Enabled := guiItems["AndroidMicCheckbox"].Value)
	guiItems["AndroidCamCheckbox"].OnEvent("Click", HandleAndroidSelector) ; (*)=> guiItems["AndroidCamSelector"].Enabled := guiItems["AndroidMicCheckbox"].Value)
	guiItems["AndroidMicSelector"].OnEvent("Change", HandleAndroidSelector) ; (*)=> guiItems["AndroidMicSelector"].Enabled := guiItems["AndroidMicCheckbox"].Value)
	guiItems["AndroidCamSelector"].OnEvent("Change", HandleAndroidSelector)

	guiItems["FleetAutoLaunchCheckBox"].OnEvent("Click", HandleCheckBoxes) ; (*) => userSettings["Manager"].AutoLaunch := guiItems["FleetAutoLaunchCheckBox"].Value)
	guiItems["FleetSyncVolCheckBox"].OnEvent("Click", HandleCheckBoxes) ;(*) => userSettings["Manager"].SyncVolume := guiItems["FleetSyncVolCheckBox"].Value)
	guiItems["FleetRemoveDisconnectCheckbox"].OnEvent("Click", HandleCheckBoxes) ;(*) => userSettings["Manager"].RemoveDisconnected := guiItems["FleetRemoveDisconnectCheckbox"].Value)
	guiItems["InstanceSyncCheckbox"].OnEvent("Click", HandleFleetSyncCheck)

	guiItems["FleetButtonAdd"].OnEvent("Click", HandleInstanceAddButton)
	guiItems["FleetButtonDelete"].OnEvent("Click", HandleInstanceDeleteButton)

	guiItems["InstanceNameBox"].OnEvent("Change", HandleNameChange)
	guiItems["InstancePortBox"].OnEvent("LoseFocus", HandlePortChange)
	guiItems["InstancePortBox"].OnEvent("Change", StrictPortLimits)
	guiItems["InstanceAudioSelector"].OnEvent("Change", HandleAudioSelector)
	OnMessage(0x404, TrayIconHandler)

	OnAudioEvent(RefreshAudioSelector)
}
HandleAudioSelector(*){
	global userSettings, 
	i := userSettings["Fleet"][currentlySelectedIndex]
	i.AudioDevice := guiItems["InstanceAudioSelector"].Text	; TODO devices list array and index instead of text, or maybe its just fine to use text? 
	UpdateButtonsLabels()
}
RefreshAudioSelector(*){
	global guiItems, audioDevicesList
	selection := guiItems["InstanceAudioSelector"].Text
	guiItems["InstanceAudioSelector"].Delete()
	audioDevicesList := ["Unset"]
	for dev in AudioDevice.GetAll()
		audioDevicesList.Push(dev.GetName())
	;for device in EveryInstanceProp(userSettings, "AudioDevice")	; TODO: Get the actual devices here, if the previously configure device is absent revert to default? 
	;	if !(ArrayHas(devicesList, device))
	;		devicesList.Push(device)
	guiItems["InstanceAudioSelector"].Add(audioDevicesList)
	guiItems["InstanceAudioSelector"].Text := ArrayHas(audioDevicesList, selection) ? selection : "Unset"
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
	global userSettings, guiItems
	userSettings["Android"].ReverseTethering := guiItems["AndroidReverseTetheringCheckbox"].Value
	userSettings["Manager"].AutoLaunch := guiItems["FleetAutoLaunchCheckBox"].Value
	launchChildren := ["FleetSyncVolCheckBox", "FleetRemoveDisconnectCheckbox"]
	launchChildrenLock := userSettings["Manager"].AutoLaunch = 0
	for item in launchChildren
		guiItems[item].Enabled := launchChildrenLock ? 0 : 1
	userSettings["Manager"].SyncVolume := guiItems["FleetSyncVolCheckBox"].Value
	userSettings["Manager"].RemoveDisconnected := guiItems["FleetRemoveDisconnectCheckbox"].Value
	UpdateButtonsLabels()
	WriteSettingsFile(userSettings)

}

HandleFleetSyncCheck(*){
	global userSettings, guiItems
	m := userSettings["Manager"]
	f := userSettings["Fleet"]
	configp := userSettings["Paths"].Config
	
	i := f[currentlySelectedIndex]
	i.Synced := guiItems["InstanceSyncCheckbox"].Value

	if i.id = 0 {
		m.SyncSettings := i.Synced
		i.Enabled := m.SyncSettings
		for otherI in f{
			otherI.Synced := m.SyncSettings
			otherI.configFile := configp "\fleet-" otherI.id (otherI.Synced ? "-synced.conf" : ".conf")
			otherI.logFile := configp "\fleet-" otherI.id (otherI.Synced ? "-synced.log" : ".log")
			otherI.appsFile := otherI.Synced ? f[1].appsFile : configp "\apps-" otherI.id ".json"
		}
	} else if m.SyncSettings {
		i.configFile := configp "\fleet-" i.id (i.Synced ? "-synced.conf" : ".conf")
		i.logFile := configp "\fleet-" i.id (i.Synced ? "-synced.log" : ".log")
		i.appsFile := i.Synced ? f[1].appsFile : configp "\apps-" i.id ".json"
	}
	HandleListChange()
}
RefreshFleetList(){
	global guiItems, userSettings
	guiItems["FleetListBox"].Delete()
	guiItems["FleetListBox"].Add(EveryInstanceProp(userSettings))
	UpdateButtonsLabels()
}
HandlePortChange(*){
	global userSettings, guiItems
	currentlySelectedIndex := guiItems["FleetListBox"].Value = 0 ? 1 : guiItems["FleetListBox"].Value
	i := userSettings["Fleet"][currentlySelectedIndex]
	newPort := guiItems["InstancePortBox"].Value = "" ? i.Port : guiItems["InstancePortBox"].Value 
	valid := (1024 < newPort && newPort < 65000) ? 1 : 0
	for otherI in userSettings["Fleet"]
		if otherI.id != i.id
			if (otherI.Port = newPort)
				valid := 0
	if valid {
		i.Port := newPort
		myLink := "https://localhost:" . (i.Synced ? userSettings["Fleet"][1].Port + 1 : i.Port + 1)
		guiItems["FleetLinkBox"].Text :=  '<a href="' . myLink . '">' . myLink . '</a>'	
	} else {
		guiItems["InstancePortBox"].Value := userSettings["Fleet"][currentlySelectedIndex].Port
	}
	UpdateButtonsLabels()
}
HandleNameChange(*){
	global userSettings, guiItems
	newName := guiItems["InstanceNameBox"].Value
	selectedEntryIndex := guiItems["FleetListBox"].Value
	userSettings["Fleet"][selectedEntryIndex].Name := newName
	RefreshFleetList()
	guiItems["FleetListBox"].Choose(selectedEntryIndex)
}
HandleInstanceAddButton(*){
	global userSettings, guiItems
	
	i := {} ; Create a new object for each i
	i.id := userSettings["Fleet"][-1].id + 1
	if (i.id > 5){
		MsgBox("Let's not add more than 5 is for now.")
	} else {
	synced := userSettings["Manager"].SyncSettings = 1
	configp := userSettings["Paths"].Config
	f := userSettings["Fleet"]
	i.Port := i.id = 1 ? 11000 : f[-1].port + 1000
	i.Name := "Instance " . i.id
	i.Enabled := 1
	i.Synced := synced
	i.AudioDevice := "Unset"
	i.configFile := configp "\fleet-" i.id (i.Synced ? "-synced.conf" : ".conf")
	i.logFile := configp "\fleet-" i.id (i.Synced ? "-synced.log" : ".log")
	i.stateFile := i.Synced ? f[1].stateFile : configp "\state-" i.id ".json"
	i.appsFile := i.Synced ? f[1].appsFile : configp "\apps-" i.id ".json"
	i.credFile := i.Synced ? f[1].credFile : configp "\state-" i.id ".json"	
	i.consolePID := 0
	i.apolloPID := 0
	i.LastConfigUpdate := 0
	i.LastReadLogLine := 0
	userSettings["Fleet"].Push(i) ; Add the i object to the userSettings["Fleet"] array
	RefreshFleetList()
	guiItems["FleetListBox"].Choose(i.id + 1)
	HandleListChange()
	}
	Sleep (100)
}
HandleInstanceDeleteButton(*){ 
	global userSettings, guiItems, currentlySelectedIndex
	if (currentlySelectedIndex != 1){
		userSettings["Fleet"].RemoveAt(currentlySelectedIndex) ; MUST USE REMOVEAT INSTEAD OF DELETE TO REMOVE THE ITEM COMPLETELY NOT JUST ITS VALUE
		guiItems["FleetListBox"].Delete(currentlySelectedIndex)
		nextChoice := currentlySelectedIndex <= userSettings["Fleet"].Length ? currentlySelectedIndex : currentlySelectedIndex - 1
		guiItems["FleetListBox"].Choose(nextChoice)
		HandleListChange()
		Loop userSettings["Fleet"].Length { 	; Update is index
			userSettings["Fleet"][A_Index].id := A_Index - 1
		}
	}
	else
		MsgBox("Can't delete the default entry", "Apollo Fleet Manager - Error", "Owner" myGui.Hwnd " 4112 T2")
	;TODO instead of msgbox, add a statubar like to show the error in there for few seconds/until new label/error is raised
	Sleep (100)
}
HandleAndroidSelector(*) {
	global savedSettings
	checkBoxes := ["AndroidMicCheckbox", "AndroidCamCheckbox"]
	Selectors := ["AndroidMicSelector", "AndroidCamSelector"]
	enableSettings := ["MicEnable", "CamEnable"]
	idSettings := ["MicDeviceID", "CamDeviceID"]
	Loop Selectors.Length {
		chckBox := guiItems[checkBoxes[A_index]]
		selector := guiItems[Selectors[A_index]]

		selector.Enabled := settingsLocked ? 0 : chckBox.Value

		savedSettings["Android"].%enableSettings[A_index]% := chckBox
        savedSettings["Android"].%idSettings[A_index]% := chckBox ? selector.Value : 0
	}
	UpdateButtonsLabels()
}

global currentlySelectedIndex := 1
HandleListChange(*) {
	global guiItems, userSettings, currentlySelectedIndex
	currentlySelectedIndex := guiItems["FleetListBox"].Value = 0 ? 1 : guiItems["FleetListBox"].Value
	i := userSettings["Fleet"][currentlySelectedIndex]
	guiItems["InstanceNameBox"].Value := i.Name
	guiItems["InstancePortBox"].Value := i.Port
	guiItems["InstanceNameBox"].Opt(((settingsLocked || currentlySelectedIndex = 1) ? "+ReadOnly" : "-ReadOnly"))
	guiItems["InstancePortBox"].Opt(((settingsLocked || currentlySelectedIndex = 1) ? "+ReadOnly" : "-ReadOnly"))
	guiItems["InstanceAudioSelector"].Enabled := (settingsLocked || currentlySelectedIndex = 1) ? 0 : 1
	myLink := "https://localhost:" . userSettings["Fleet"][(userSettings["Manager"].SyncSettings = 1 ? 1 : currentlySelectedIndex)].Port+1
	guiItems["FleetLinkBox"].Text :=  '<a href="' . myLink . '">' . myLink . '</a>'

	RefreshAudioSelector()
	guiItems["InstanceAudioSelector"].Text := ArrayHas(audioDevicesList, i.AudioDevice) ? i.AudioDevice : "Unset"

	guiItems["InstanceSyncCheckbox"].Value := i.Synced
	guiItems["InstanceSyncCheckbox"].Enabled := !settingsLocked && (userSettings["Manager"].SyncSettings || currentlySelectedIndex = 1)
	HandlePortChange()
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
	Sleep (100)
}
HandleReloadButton(*) {
	global settingsLocked, userSettings, savedSettings, currentlySelectedIndex
	;if settingsLocked && UserSettingsWaiting() {
	;	if (userSettings["Manager"].SyncSettings != userSettings["Manager"].SyncSettings) {
	;		for i in userSettings["Fleet"]
	;			if i.Enabled = 1 && FileExist(i.configFile)
	;				FileDelete(i.configFile)
	;	}
	;	Reload
	;} TODO : MAYBE Add a 3rd state in between Locked/Reload > Unlocked/Cancel > *Save/Cancel* > Apply/Discard > Lock / Reload ? 
	if settingsLocked {
		UpdateWindowPosition()
		savedSettings["Window"].cmdReload := 1
		WriteSettingsFile(savedSettings)
		Sleep(100)
		Reload
	}
	else {
		currentlySelectedIndex := 1
		ReflectSettings(savedSettings)
		HandleSettingsLock()
		bootstrapSettings()
	}
	Sleep (100)
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
;------------------------------------------------------------------------------  
; Recursively compare any two values (Map, Array, or primitive).  
; Returns 1 if they differ anywhere, 0 if identical.  
DeepCompare(a, b) {
    if (Type(a) != Type(b))
        return 1

    if (Type(a) = "Map") {
        if a.Count != b.Count
            return 1
        for key, val in a {
            if !b.Has(key)
                return 1
            if DeepCompare(val, b[key])
                return 1
        }
        return 0
    }

    if (Type(a) = "Array") {
        if a.Length != b.Length
            return 1
        for index, val in a {
            if DeepCompare(val, b[index])
                return 1
        }
        return 0
    }

    if (Type(a) = "Object") {
        if ObjOwnPropCount(a) != ObjOwnPropCount(b)
            return 1
        for key in ObjOwnProps(a) {
            if !b.HasOwnProp(key)
                return 1
            if DeepCompare(a.%key%, b.%key%)
                return 1
        }
        return 0
    }

    ; Primitive (number, string, etc.)
    return a != b
}


;------------------------------------------------------------------------------  
; Returns 1 if savedSettings vs. userSettings differ anywhere (skips "Window"), else 0  
UserSettingsWaiting() {
    global savedSettings, userSettings

    return DeepCompare(savedSettings, userSettings)
}


UpdateButtonsLabels(){
	global guiItems, settingsLocked
	guiItems["ButtonLockSettings"].Text := UserSettingsWaiting() && !settingsLocked ? "Save" : settingsLocked ? "🔒" : "🔓" 
	guiItems["ButtonReload"].Text := settingsLocked ?  "Reload" : "Cancel"
	guiItems["InstanceSyncCheckbox"].Text := currentlySelectedIndex = 1 ? userSettings["Manager"].SyncSettings ? "Copy from Default" : "Disable Copy" : "Copy from Default"
}
ApplyLockState() {
	global settingsLocked, guiItems, userSettings, currentlySelectedIndex

	isEnabled(cond := true) => cond ? 1 : 0
	isReadOnly(cond := true) => cond ? "+ReadOnly" : "-ReadOnly"

	textBoxes := ["PathsApolloBox"]
	checkBoxes := ["FleetAutoLaunchCheckBox", "AndroidReverseTetheringCheckbox", "AndroidMicCheckbox", "AndroidCamCheckbox"]
	buttons := ["FleetButtonDelete", "FleetButtonAdd", "PathsApolloBrowseButton"]
	androidSelectors := Map(
		"AndroidMicSelector", "AndroidMicCheckbox",
		"AndroidCamSelector", "AndroidCamCheckbox"
	)
	inputBoxes := ["InstanceNameBox", "InstancePortBox"]
	inputSelectors := ["InstanceAudioSelector"]
	launchChildren := ["FleetSyncVolCheckBox", "FleetRemoveDisconnectCheckbox"]

	launchChildrenLock := userSettings["Manager"].AutoLaunch = 0
	readOnlyFleet := settingsLocked || currentlySelectedIndex = 1

	for item in launchChildren
		guiItems[item].Enabled := isEnabled(!settingsLocked && !launchChildrenLock)

	for checkbox in checkBoxes
		guiItems[checkbox].Enabled := isEnabled(!settingsLocked)

	for button in buttons
		guiItems[button].Enabled := isEnabled(!settingsLocked)

	for box in textBoxes
		guiItems[box].Opt(isReadOnly(settingsLocked))

	for box in inputBoxes
		guiItems[box].Opt(isReadOnly(readOnlyFleet))

	for selector in inputSelectors
		guiItems[selector].Enabled := isEnabled(!readOnlyFleet)

	for selector, chkbox in androidSelectors
		guiItems[selector].Enabled := isEnabled(!settingsLocked && guiItems[chkbox].Value)

	guiItems["InstanceSyncCheckbox"].Enabled := !settingsLocked && (userSettings["Manager"].SyncSettings || currentlySelectedIndex = 1)
}

SaveUserSettings(){
	global userSettings, savedSettings, currentlySelectedIndex
	; TODO verify settings before save? 
	savedSettings := DeepClone(userSettings)
}
global settingsLocked := 1
HandleSettingsLock(*) {
    global guiItems, settingsLocked, savedSettings, userSettings
	UpdateButtonsLabels()
	if !UserSettingsWaiting() {
		settingsLocked := !settingsLocked
		if !settingsLocked {	; to do if got unlocked
			RefreshAudioSelector()
		}
	} else {
		currentlySelectedIndex := 1
		HandleListChange()
		; hence we need to save settings "clone staged into active and save them"
		SaveUserSettings()
		HandleSettingsLock()
	}
	ApplyLockState()
	UpdateButtonsLabels()
	Sleep (100)
}
ExitMyApp() {
	global myGui, savedSettings
	UpdateWindowPosition()
	savedSettings["Window"].cmdExit := 1
	WriteSettingsFile(savedSettings)
	Sleep (100)
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
	Sleep (100)
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
	Sleep (100)
}
ShowmyGui() {
	global myGui, userSettings
	if savedSettings["Window"].cmdReload = 1 {
		RestoremyGui()
	} else if (savedSettings["Window"].lastState = 1) {
		if (savedSettings["Window"].restorePosition){
			savedSettings["Window"].restorePosition := 0
			RestoremyGui()
			savedSettings["Window"].restorePosition := 1
		} else
			RestoremyGui()
	} else
		return
	Sleep (100)
}

SetIfChanged(map, key, newValue) {
    if map.Get(key,0) != newValue {
		MsgBox( map.Get(key,0) . " > " . newValue)
        map.set(key, newValue)
        return true
    }
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
FleetConfigInit(*) {
	global savedSettings
	
	; clean and prepare conf directory
	p := savedSettings["Paths"]
	m := savedSettings["Manager"]
	f := savedSettings["Fleet"]
	if !DirExist(p.Config)	
		DirCreate(p.Config)
	configDir := p.Config
	; to delete any unexpected file "such as residual config/log"
	knownFiles := []
	fileTypes := ["configFile","stateFile", "appsFile", "credFile", "logFile"]
	for i in f
		for file in fileTypes
			knownFiles.Push(i.%file%)

	Loop Files configDir . '\*.*' 
		if !ArrayHas(knownFiles, A_LoopFileFullPath)
			FileDelete(A_LoopFileFullPath)
	
	; import default conf if sync is ticked
	baseConf := Map()
	if (m.SyncSettings) {
		defaultConfFile := p.Apollo . "\config\sunshine.conf"
		baseConf := ConfRead(defaultConfFile)
		excludeOptions := ["sunshine_name", "port", "file_state", "credentials_file", "file_apps"]	; TODO: Audio device
		for option in excludeOptions
			if baseConf.Has(option) 
				baseConf.Delete(option)
		baseConf.Set("headless_mode", "enabled")
	}
	; assign and create conf files if not created
	optionMap := Map(
		"sunshine_name", "Name",
		"port", "Port",
		"log_path","logFile", 
		"file_state", "stateFile",
		"credentials_file", "credFile",
		"file_apps", "appsFile",
		"virtual_sink", "AudioDevice"
	)	; TODO: Audio device and its consequences; the mute option/ and or others
	newConf := false
	for i in f {
		if i.id = 0 {
			i.configChange := (i.LastConfigUpdate != FileGetTime(i.configFile, "M"))
		}
		else if i.id > 0 && i.Enabled = 1 {
			i.configChange := i.Synced ? ((!FileExist(i.configFile) || f[1].configChange) ? 1 : 0 ) : (!FileExist(i.configFile) || (i.LastConfigUpdate != FileGetTime(i.configFile, "M")))
			i.thisConf := FileExist(i.configFile) ? (i.Synced ?  MergeConfMap(ConfRead(i.configFile), DeepClone(baseConf)):  ConfRead(i.configFile)) : Map()
			for option, key in optionMap 
				if !(option = "virtual_sink" && i.%key% = "Unset")
					if SetIfChanged(i.thisConf, option, i.%key%)
						i.configChange := true

			if SetIfChanged(i.thisConf, "headless_mode", "enabled")
				i.configChange := true
			if i.configChange 
				if i.AudioDevice != "Unset" {
					i.thisConf.Set("auto_capture_sink", "disabled", "keep_sink_default", "disabled")
				}
				else {
					i.thisConf.Set("auto_capture_sink", "enabled", "keep_sink_default", "enabled")
					i.thisConf.Delete("virtual_sink")
				}
			if !FileExist(i.configFile) || i.configChange {
				ConfWrite(i.configFile, i.thisConf)
				i.LastConfigUpdate := FileGetTime(i.configFile, "M")
				newConf := true
			}
		}
	}
	if f[1].LastConfigUpdate != FileGetTime(f[1].configFile, "M") {
		f[1].LastConfigUpdate := FileGetTime(f[1].configFile, "M")
		f[1].configChange := 1
	} else
		f[1].configChange := 0
	if newConf
		UrgentSettingWrite(savedSettings, "Fleet")
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
	ShowmyGui()
	InitmyGuiEvents()
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
SendSigInt(pid, force:=false) {
    ; 1. Tell this script to ignore Ctrl+C and Ctrl+Break
    DllCall("SetConsoleCtrlHandler", "Ptr", 0, "UInt", 1)
    ; 2. Detach from current console, attach to target's
    DllCall("FreeConsole")
    DllCall("AttachConsole", "UInt", pid)
    ; 3. Send Ctrl+C (SIGINT) to all processes in that console (including the target)
    DllCall("GenerateConsoleCtrlEvent", "UInt", 0, "UInt", 0)
	DllCall("FreeConsole")

    Sleep 100  ; Give the target process time to exit

	if force && ProcessExist(pid)
		ProcessClose(pid)

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
	Sleep(1)
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
	; get currently running PIDs terminate anything unknown to us
	currentPIDs := PIDsListFromExeName("sunshine.exe")
	knownPIDs := []
	for i in f
		if (i.Enabled && !i.configChange)
			knownPIDs.Push(i.apolloPID)	
	wait := 0
	for pid in currentPIDs
		if !ArrayHas(knownPIDs, pid)
			if SendSigInt(pid, true)
				wait := 100
			; TODO maybe  we need to check pid if they still exist 
	for i in f
		if (!i.Enabled || i.configChange) && (ProcessExist(i.apolloPID) || ProcessExist(i.consolePID))
			if SendSigInt(i.apolloPID) || SendSigInt(i.consolePID)
				continue 

	Sleep(wait) ; keep it here for now,  
	exe := savedSettings["Paths"].apolloExe
	newPID := 0
	for i in f
		if i.Enabled && (!ProcessExist(i.apolloPID) || i.configChange) {	; TODO add test for the instance if it responds or not, also, may check if display is connected deattach it/force exit? 
			if FileExist(i.LogFile)
				FileDelete(i.LogFile)
			pids := RunAndGetPIDs(exe, i.configFile)
			i.consolePID := pids[1]
			i.apolloPID := pids[2]
			newPID := 1
		}
	if newPID
		UrgentSettingWrite(savedSettings, "Fleet")
	;MsgBox(savedSettings["Fleet"][1].consolePID . ":" . savedSettings["Fleet"][1].apolloPID)
}
UrgentSettingWrite(srcSettings, group){
	global savedSettings, userSettings
	transientMap := Map()
	transientMap := DeepClone(srcSettings)
	savedSettings[group] := DeepClone(transientMap[group])
	userSettings[group] := DeepClone(transientMap[group])
	WriteSettingsFile(savedSettings)
}

LogWatchDog(*){
}

FleetSyncVolume(*){
}

FleetRemoveDisconnected(*){
}

FleetSyncSettings(*){
}

ADBWatchDog(*){
}

SetupFleetTask() {
    taskName := "Apollo Fleet Launcher"
    exePath := A_ScriptFullPath

    if !A_IsAdmin {
        MsgBox "Please run as Administrator."
        ExitApp
    }

    if savedSettings["Manager"].AutoLaunch {
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

ResetFlags(){
	global savedSettings
	w := savedSettings["Window"]
	w.cmdReload := 0
	w.cmdExit := 0
	UrgentSettingWrite(savedSettings, "Window")
	bootstrapSettings()
}
KillExistingGnirehtetProcess(){
	
}
MaintainGnirehtetProcess(){
	global savedSettings

}



















; Step 1 Load settings
bootstrapSettings()

; Step 2 Check if admin and setup scheduled task
SetupFleetTask()

; Step 3 Setup and show GUI
bootstrapGUI()

; Step 4 Prepare and launch fleet if enabled
if savedSettings["Manager"].AutoLaunch {
	; Step 1 Create/Load/Modify config files
	FleetConfigInit()
	; Step 2 Kill/Start Apollo Processes
	FleetLaunchFleet()
	; Step 3 TODO
	;timer 1000 FleetCheckFleet() ; this is a combination of i check/ logmonitor for connected/disconnected events/ 
	; if enabled, start timer 50 SyncVolume to try sync volume as soon as client connects, probably can verify it too "make it smart not dumb"
	; if enabled, start timer 50 ForceClose to try send SIGINT to i once client disconnected > the rest should be cought by FleetCheckFleet to relaunch it again "if it didn't relaunch by itself" 
	if savedSettings["Manager"].SyncVolume || savedSettings["Manager"].RemoveDisconnected || savedSettings["Manager"].SyncSettings
		SetTimer LogWatchDog, 100000

} 

; Step 5 If Enabled, Start gnirehtet (Android reverse tethering over ADB)
if savedSettings["Android"].ReverseTethering {
	SetTimer MaintainGnirehtetProcess, 1000
	; AndroidStartGnirehtet() ; check existing > test it > if invalid start new one, until this is a reload; kill it!
	; timer 1000 AndroidCheckGnirehtet() Possibily we can do it smart way to check if its still alive/there's connections
} else {
	KillExistingGnirehtetProcess()
}
if savedSettings["Android"].MicEnable || savedSettings["Android"].CamEnable {
	; here we sadly need to kill every existing adb.exe process, possibly via kill-server adb command
	; timer 1000 AndroidDevicesList() ; to keep track of currently connected, and disconnected devices with their IDs and time of connection/disconnection and previous time too "maybe we can do something smarter here too"
	if savedSettings["Android"].MicEnable{
		; if the existing scrcpy proccess is ours, and it was created for the same devID keep it, until this is a reload; kill it!
		; check if the micID is non-empty maybe we can do this in a loop as it doesn't really need reload to apply if changed
		; if 
	}
	if savedSettings["Android"].CamEnable{
		; if the existing scrcpy proccess is ours, and it was created for the same devID keep it, until this is a reload; kill it!
		; check if the micID is non-empty maybe we can do this in a loop as it doesn't really need reload to apply if changed
		; if 
	}
}


ResetFlags()


; ───── Keep script alive ─────
While 1
    Sleep(100)

	; TODO Validate settings and reset invalid ones, clear invalid is

	; if AutoLaunch is set, check for schduleded task, add it if missing, enable it if disabled
	; else disable it ;;; EDIT: AutoLaunch will be used to determine if we launch these is or not at all
	;							TODO Introduce Auto run at startup setting to specifically do that 

