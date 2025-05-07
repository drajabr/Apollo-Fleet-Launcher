#Requires Autohotkey v2

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

ReadSettingsFile(settingsFile := "settings.ini", Settings := Map(), groups := "all") {
    ; Create default Maps
    for k in ["Manager", "Window", "Paths", "Fleet", "Android"]
        if !Settings.Has(k)
            Settings[k] := Map()
    if !Settings.Has("Fleet")
        Settings["Fleet"] := []

    if !FileExist(settingsFile)
        FileAppend("", settingsFile)

    if (groups = "all" || InStr(groups, "Manager"))
        ReadSettingsGroup(settingsFile, "Manager", Settings)
    if (groups = "all" || InStr(groups, "Window"))
        ReadSettingsGroup(settingsFile, "Window", Settings)
    if (groups = "all" || InStr(groups, "Paths"))
        ReadSettingsGroup(settingsFile, "Paths", Settings)
    if (groups = "all" || InStr(groups, "Android"))
        ReadSettingsGroup(settingsFile, "Android", Settings)
    if (groups = "all" || InStr(groups, "Fleet"))
        ReadSettingsGroup(settingsFile, "Fleet", Settings)
}

ReadSettingsGroup(settingsFile, group, Settings) {
    switch group {
        case "Manager":
			m := Settings["Manager"]
            m["cmdReload"] := IniRead(settingsFile, "Manager", "cmdReload", 0)
			m["AutoLaunch"] := IniRead(settingsFile, "Fleet Options", "AutoLaunch", 1)
            m["SyncVolume"] := IniRead(settingsFile, "Fleet Options", "SyncVolume", 1)
            m["RemoveDisconnected"] := IniRead(settingsFile, "Fleet Options", "RemoveDisconnected", 1)
            m["SyncSettings"] := IniRead(settingsFile, "Fleet Options", "SyncSettings", 1)
			
        case "Window":
			w := Settings["Window"]
            w["restorePosition"] := IniRead(settingsFile, "Window", "restorePosition", 1)
            w["xPos"] := IniRead(settingsFile, "Window", "xPos", (A_ScreenWidth - 580) / 2)
            w["yPos"] := IniRead(settingsFile, "Window", "yPos", (A_ScreenHeight - 198) / 2)
            w["lastState"] := IniRead(settingsFile, "Window", "lastState", 1)
            w["logShow"] := IniRead(settingsFile, "Window", "logShow", 1)

        case "Paths":
            base := A_ScriptDir
			p := Settings["Paths"]
            p["Apollo"] := IniRead(settingsFile, "Paths", "Apollo", "C:\Program Files\Apollo")
            p["apolloExe"] := Settings["Paths"]["Apollo"] "\sunshine.exe"
            p["Config"] := IniRead(settingsFile, "Paths", "Config", base "\config")
            p["ADBTools"] := IniRead(settingsFile, "Paths", "ADB", base "\platform-tools")

        case "Android":
            a := Settings["Android"]
            a["ReverseTethering"] := IniRead(settingsFile, "Android Clients", "ReverseTethering", 1)
            a["gnirehtetPID"] := IniRead(settingsFile, "Android Clients", "gnirehtetPID", "")
            a["MicEnable"] := IniRead(settingsFile, "Android Clients", "MicEnable", 0)
            a["MicDeviceID"] := IniRead(settingsFile, "Android Clients", "MicDeviceID", "")
            a["scrcpyMicPID"] := IniRead(settingsFile, "Android Clients", "scrcpyMicPID", "")
            a["CamEnable"] := IniRead(settingsFile, "Android Clients", "CamEnable", 0)
            a["CamDeviceID"] := IniRead(settingsFile, "Android Clients", "CamDeviceID", "")
            a["scrcpyCamPID"] := IniRead(settingsFile, "Android Clients", "scrcpyCamPID", "")

        case "Fleet":
		    Settings["Fleet"] := []
			f := Settings["Fleet"]
			apollop := Settings["Paths"]["Apollo"]
            configp := Settings["Paths"]["Config"]
            synced := Settings["Manager"]["SyncSettings"] = 1
			; Add default i manually (id = 0)
			defaultConfFile := Settings["Paths"]["Apollo"] . "\config\sunshine.conf"
			i := {}
			i.id := 0
			i.Name := ConfRead(defaultConfFile, "sunshine_name", "default i")
			i.Port := ConfRead(defaultConfFile, "port", "47989")
			i.Enabled := Settings["Manager"]["SyncSettings"] ? 1 : 0
			i.consolePID := 0
			i.apolloPID := 0
			i.LastConfigUpdate := 0
			i.LastReadLogLine := 0
			i.configFile := apollop . '\config\sunshine.conf'
			i.logFile := apollop . '\config\sunshine.log'
			i.stateFile := apollop . '\config\sunshine.json'
			f.Push(i)
            index := 2
            sections := StrSplit(IniRead(settingsFile), "`n")
            for section in sections {
                if (SubStr(section, 1, 8) = "Instance") {
                    i := {}
                    i.id := IsNumber(SubStr(section, 9)) ? SubStr(section, 9) : index - 1
                    i.Name := IniRead(settingsFile, section, "Name", "i" . index)
                    i.Port := IniRead(settingsFile, section, "Port", 10000 + index * 1000)
                    i.Enabled := IniRead(settingsFile, section, "Enabled", 1)
                    i.consolePID := IniRead(settingsFile, section, "consolePID", 0)
                    i.apolloPID := IniRead(settingsFile, section, "apolloPID", 0)
                    i.LastConfigUpdate := IniRead(settingsFile, section, "LastConfigUpdate", 0)
                    i.LastReadLogLine := IniRead(settingsFile, section, "LastReadLogLine", 0)
                    i.configFile := configp "\fleet-" i.id (synced ? "-synced.conf" : ".conf")
                    i.logFile := configp "\fleet-" i.id (synced ? "-synced.log" : ".log")
                    i.stateFile := synced ? I[1].stateFile : configp "\fleet-" i.id ".json"
                    I.Push(i)
                    index += 1
                }
            }
    }
}

WriteSettingsFile(Settings := Map(), settingsFile := "settings.ini", groups := "all") {
    if FileExist(settingsFile)
        FileDelete(settingsFile)
    FileAppend("", settingsFile)

    if (groups = "all" || InStr(groups, "Manager"))
        WriteSettingsGroup(Settings, settingsFile, "Manager")
    if (groups = "all" || InStr(groups, "Window"))
        WriteSettingsGroup(Settings, settingsFile, "Window")
    if (groups = "all" || InStr(groups, "Paths"))
        WriteSettingsGroup(Settings, settingsFile, "Paths")
    if (groups = "all" || InStr(groups, "Android"))
        WriteSettingsGroup(Settings, settingsFile, "Android")
    if (groups = "all" || InStr(groups, "Fleet"))
        WriteSettingsGroup(Settings, settingsFile, "Fleet")
}

WriteSettingsGroup(Settings, settingsFile, group) {
	WriteIfChanged(file, section, key, value) {
		old := IniRead(file, section, key, "__MISSING__")
		if (old != value)
			IniWrite(value, file, section, key)
	}
    switch group {
        case "Manager":
			WriteIfChanged(settingsFile, "Manager", "cmdReload", Settings["Manager"]["cmdReload"])
			WriteIfChanged(settingsFile, "Manager", "AutoLaunch", Settings["Manager"]["AutoLaunch"])
			WriteIfChanged(settingsFile, "Manager", "SyncVolume", Settings["Manager"]["SyncVolume"])
			WriteIfChanged(settingsFile, "Manager", "RemoveDisconnected", Settings["Manager"]["RemoveDisconnected"])
			WriteIfChanged(settingsFile, "Manager", "SyncSettings", Settings["Manager"]["SyncSettings"])

        case "Window":
			WriteIfChanged(settingsFile, "Window", "restorePosition", Settings["Window"]["restorePosition"])
			WriteIfChanged(settingsFile, "Window", "xPos", Settings["Window"]["xPos"])
			WriteIfChanged(settingsFile, "Window", "yPos", Settings["Window"]["yPos"])
			WriteIfChanged(settingsFile, "Window", "lastState", Settings["Window"]["lastState"])
			WriteIfChanged(settingsFile, "Window", "logShow", Settings["Window"]["logShow"])

        case "Paths":
			WriteIfChanged(settingsFile, "Paths", "Apollo", Settings["Paths"]["Apollo"])
			WriteIfChanged(settingsFile, "Paths", "Config", Settings["Paths"]["Config"])
			WriteIfChanged(settingsFile, "Paths", "ADB", Settings["Paths"]["ADBTools"])
		
        case "Android":
			WriteIfChanged(settingsFile, "Android", "ReverseTethering", Settings["Android"]["ReverseTethering"])
			WriteIfChanged(settingsFile, "Android", "gnirehtetPID", Settings["Android"]["gnirehtetPID"])
			WriteIfChanged(settingsFile, "Android", "MicEnable", Settings["Android"]["MicEnable"])
			WriteIfChanged(settingsFile, "Android", "MicDeviceID", Settings["Android"]["MicDeviceID"])
			WriteIfChanged(settingsFile, "Android", "scrcpyMicPID", Settings["Android"]["scrcpyMicPID"])
			WriteIfChanged(settingsFile, "Android", "CamEnable", Settings["Android"]["CamEnable"])
			WriteIfChanged(settingsFile, "Android", "CamDeviceID", Settings["Android"]["CamDeviceID"])
			WriteIfChanged(settingsFile, "Android", "scrcpyCamPID", Settings["Android"]["scrcpyCamPID"])
		
        case "Fleet":
			for i in Settings["Fleet"] {
				if i.id = 0 
					continue
				sectionName := "Instance" i.id
				WriteIfChanged(settingsFile, sectionName, "Name", i.Name)
				WriteIfChanged(settingsFile, sectionName, "Port", i.Port)
				WriteIfChanged(settingsFile, sectionName, "Enabled", i.Enabled)
				WriteIfChanged(settingsFile, sectionName, "consolePID", i.consolePID)
				WriteIfChanged(settingsFile, sectionName, "apolloPID", i.apolloPID)
				WriteIfChanged(settingsFile, sectionName, "LastConfigUpdate", i.LastConfigUpdate)
				WriteIfChanged(settingsFile, sectionName, "LastReadLogLine", i.LastReadLogLine)
				; WriteIfChanged(settingsFile, sectionName, "Audio", i.Audio) ; TODO
				}
			}
}
AllFleetArray(Settings){
	isList := []  ; Create an empty array
	for i in Settings["Fleet"] 
		isList.Push(i.Name)  ; Add the Name property to the array
	return isList
}
InitmyGui() {
	;TODO implement dark theme and follow system theme if possible 
	global myGui, guiItems := Map()
	if !A_IsCompiled {
		TraySetIcon("../assets/9.ico")
	}
	myGui := Gui("+AlwaysOnTop -MinimizeBox -MaximizeBox")
	guiItems["ButtonLockSettings"] := myGui.Add("Button", "x520 y5 w50 h40", "🔒")
	guiItems["ButtonReload"] := myGui.Add("Button", "x520 y50 w50 h40", "Reload")
	guiItems["ButtonLogsShow"] := myGui.Add("Button", "x520 y101 w50 h40", "Show Logs")
	guiItems["ButtonMinimize"] := myGui.Add("Button", "x520 y150 w50 h40", "Minimize")
	myGui.Add("GroupBox", "x318 y0 w196 h90", "Fleet Options")
	guiItems["FleetAutoLaunchCheckBox"] := myGui.Add("CheckBox", "x334 y16 w162 h23", "Auto Launch Fleet Fleet")
	guiItems["FleetSyncVolCheckBox"] := myGui.Add("CheckBox", "x334 y40 w162 h23", "Sync Device Volume Level")
	guiItems["FleetRemoveDisconnectCheckbox"] := myGui.Add("CheckBox", "x334 y64 w167 h23", "Remove on Disconnect")
	myGui.Add("GroupBox", "x318 y96 w196 h95", "Android Clients")
	guiItems["AndroidReverseTetheringCheckbox"] := myGui.Add("CheckBox", "x334 y112 w139 h23", "ADB Reverse Tethering")
	guiItems["AndroidMicCheckbox"] := myGui.Add("CheckBox", "x334 y140 ", "Mic:")
	guiItems["AndroidMicSelector"] := myGui.Add("ComboBox", "x382 y136 w122", [])
	guiItems["AndroidCamCheckbox"] := myGui.Add("CheckBox", "x334 y164 ", "Cam:")
	guiItems["AndroidCamSelector"] := myGui.Add("ComboBox", "x382 y160 w122", [])
	guiItems["PathsApolloBox"] := myGui.Add("Edit", "x56 y24 w209 h23")
	myGui.Add("Text", "x16 y28", "Apollo:")
	guiItems["PathsApolloBrowseButton"] := myGui.Add("Button", "x267 y24 w30 h25", "📂")
	myGui.Add("GroupBox", "x8 y0 w300 h192", "Fleet")
	guiItems["FleetListBox"] := myGui.Add("ListBox", "x16 y66 w100 h82 +0x100 Choose1")
	myGui.Add("Text", "x126 y70", "Name:")
	guiItems["FleetNameBox"] := myGui.Add("Edit", "x166 y65 w130 h23")
	guiItems["FleetNameBox"].Value := savedSettings["Fleet"][1].Name
	myGui.Add("Text", "x126 y98", "Port:")
	guiItems["FleetPortBox"] := myGui.Add("Edit", "x166 y92 w130 h23 +ReadOnly", "")
	guiItems["FleetPortBox"].Value := savedSettings["Fleet"][1].Port
	;myGui.Add("Text", "x126 y120 w54 h23", "Audio:")
	;guiItems["FleetAudioSelector"] := myGui.Add("ComboBox", "x166 y120 w130", [])
	myGui.Add("Text", "x126 y126 ", "Link:")
	myLink := "https://localhost:" . savedSettings["Fleet"][(savedSettings["Manager"]["SyncSettings"] = 1 ? 1 : currentlySelectedIndex)].Port+1
	guiItems["FleetLinkBox"] := myGui.Add("Link", "x166 y126", '<a href="' . myLink . '">' . myLink . '</a>')
	guiItems["FleetSyncCheckbox"] := myGui.Add("CheckBox", "x130 y155 w165 h23", " Copy Default Instance Settings")
	guiItems["FleetButtonAdd"] := myGui.Add("Button", "x49 y155 w71 h23", "Add")
	guiItems["FleetButtonDelete"] := myGui.Add("Button", "x16 y155 w27 h23", "✖")
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
	global myGui, guiItems, currentlySelectedIndex
	guiItems["FleetAutoLaunchCheckBox"].Value := Settings["Manager"]["AutoLaunch"]
	guiItems["FleetSyncVolCheckBox"].Value := Settings["Manager"]["SyncVolume"]
	guiItems["FleetRemoveDisconnectCheckbox"].Value := Settings["Manager"]["RemoveDisconnected"]
	guiItems["FleetSyncCheckbox"].Value := Settings["Manager"]["SyncSettings"]
	guiItems["AndroidReverseTetheringCheckbox"].Value := Settings["Android"]["ReverseTethering"]
	guiItems["AndroidMicCheckbox"].Value := Settings["Android"]["MicEnable"]
	guiItems["AndroidMicSelector"].Value := Settings["Android"]["MicDeviceID"]
	guiItems["AndroidCamCheckbox"].Value := Settings["Android"]["CamEnable"]
	guiItems["AndroidCamSelector"].Value := Settings["Android"]["CamDeviceID"]
	guiItems["PathsApolloBox"].Value := Settings["Paths"]["Apollo"]
	guiItems["ButtonLogsShow"].Text := (Settings["Window"]["logShow"] = 1 ? "Hide Logs" : "Show Logs")
	;guiItems["FleetAudioSelector"].Enabled :=0
	guiItems["FleetListBox"].Delete()
	guiItems["FleetListBox"].Add(AllFleetArray(Settings))
}
InitmyGuiEvents(){
	global myGui, guiItems
	myGui.OnEvent('Close', (*) => ExitMyApp())
	guiItems["ButtonMinimize"].OnEvent("Click", MinimizemyGui)
	guiItems["ButtonLockSettings"].OnEvent("Click", HandleSettingsLock)
	guiItems["ButtonReload"].OnEvent("Click", HandleReloadButton)
	guiItems["ButtonLogsShow"].OnEvent("Click", HandleLogsButton)
	guiItems["FleetListBox"].OnEvent("Change", HandleListChange)

	guiItems["AndroidReverseTetheringCheckbox"].OnEvent("Click", HandleCheckBoxes) ; (*) => userSettings["Android"]["ReverseTethering"] := guiItems["AndroidReverseTetheringCheckbox"].Value)
	guiItems["AndroidMicCheckbox"].OnEvent("Click", HandleAndroidSelector) ; (*)=> guiItems["AndroidMicSelector"].Enabled := guiItems["AndroidMicCheckbox"].Value)
	guiItems["AndroidCamCheckbox"].OnEvent("Click", HandleAndroidSelector) ; (*)=> guiItems["AndroidCamSelector"].Enabled := guiItems["AndroidMicCheckbox"].Value)

	guiItems["FleetAutoLaunchCheckBox"].OnEvent("Click", HandleCheckBoxes) ; (*) => userSettings["Manager"]["AutoLaunch"] := guiItems["FleetAutoLaunchCheckBox"].Value)
	guiItems["FleetSyncVolCheckBox"].OnEvent("Click", HandleCheckBoxes) ;(*) => userSettings["Manager"]["SyncVolume"] := guiItems["FleetSyncVolCheckBox"].Value)
	guiItems["FleetRemoveDisconnectCheckbox"].OnEvent("Click", HandleCheckBoxes) ;(*) => userSettings["Manager"]["RemoveDisconnected"] := guiItems["FleetRemoveDisconnectCheckbox"].Value)
	guiItems["FleetSyncCheckbox"].OnEvent("Click", HandleFleetSyncCheck)

	guiItems["FleetButtonAdd"].OnEvent("Click", HandleInstanceAddButton)
	guiItems["FleetButtonDelete"].OnEvent("Click", HandleInstanceDeleteButton)

	guiItems["FleetNameBox"].OnEvent("Change", HandleNameChange)
	guiItems["FleetPortBox"].OnEvent("LoseFocus", HandlePortChange)
	OnMessage(0x404, TrayIconHandler)
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
	userSettings["Android"]["ReverseTethering"] := guiItems["AndroidReverseTetheringCheckbox"].Value
	userSettings["Manager"]["AutoLaunch"] := guiItems["FleetAutoLaunchCheckBox"].Value
	launchChildren := ["FleetSyncVolCheckBox", "FleetRemoveDisconnectCheckbox"]
	launchChildrenLock := userSettings["Manager"]["AutoLaunch"] = 0
	for item in launchChildren
		guiItems[item].Enabled := launchChildrenLock ? 0 : 1
	userSettings["Manager"]["SyncVolume"] := guiItems["FleetSyncVolCheckBox"].Value
	userSettings["Manager"]["RemoveDisconnected"] := guiItems["FleetRemoveDisconnectCheckbox"].Value
	UpdateButtonsLables()
}

HandleFleetSyncCheck(*){
	global userSettings, guiItems
	userSettings["Manager"]["SyncSettings"] := guiItems["FleetSyncCheckbox"].Value
	userSettings["Fleet"][0].Enabled := userSettings["Manager"]["SyncSettings"]
	; change conf file name so its recognized as synced, also, to trigger delete for non-synced config "and vice versa" on next reload 
	for i in userSettings["Fleet"]
		i.configFile := userSettings["Paths"]["Config"] . '\fleet-' . i.id . (userSettings["Manager"]["SyncSettings"] = 1 ?  '-synced.conf' : '.conf')
	HandleListChange()
}
RefreshFleetList(){
	global guiItems, userSettings
	guiItems["FleetListBox"].Delete()
	guiItems["FleetListBox"].Add(AllFleetArray(userSettings))
	UpdateButtonsLables()
}
HandlePortChange(*){
	global userSettings, guiItems
	selectedEntryIndex := guiItems["FleetListBox"].Value
	newPort := guiItems["FleetPortBox"].Value = "" ? userSettings["Fleet"][selectedEntryIndex].Port : guiItems["FleetPortBox"].Value 
	valid := (1024 < newPort && newPort < 65000) ? 1 : 0
	for i in userSettings["Fleet"]
		if (i.Port = newPort)
			valid := 0
	if valid {
		userSettings["Fleet"][selectedEntryIndex].Port := newPort
		myLink := "https://localhost:" . userSettings["Fleet"][(userSettings["Manager"]["SyncSettings"] = 1 ? 1 : currentlySelectedIndex)].Port+1
		guiItems["FleetLinkBox"].Text :=  '<a href="' . myLink . '">' . myLink . '</a>'	
	} else {
		guiItems["FleetPortBox"].Value := userSettings["Fleet"][currentlySelectedIndex].Port
	}
	UpdateButtonsLables()
}
HandleNameChange(*){
	global userSettings, guiItems
	newName := guiItems["FleetNameBox"].Value
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
	i.Port := i.id = 1 ? 10000 : userSettings["Fleet"][-1].port + 1000
	i.Name := "Instance " . i.Port
	i.Enabled := 1
	i.consolePID := 0
	i.apolloPID := 0
	i.LastConfigUpdate := 0
	i.LastReadLogLine := 0
	i.configFile := userSettings["Paths"]["Config"] . '\fleet-' . i.id . '.conf'
	i.logFile := userSettings["Paths"]["Config"] . '\fleet-' . i.id . '.log'
	i.stateFile := userSettings["Paths"]["Config"] . '\fleet-' . i.id . '.json'
	userSettings["Fleet"].Push(i) ; Add the i object to the userSettings["Fleet"] array
	RefreshFleetList()
	guiItems["FleetListBox"].Choose(i.id)
	HandleListChange()
	}
	Sleep (100)
}
HandleInstanceDeleteButton(*){
	global userSettings, guiItems
	selectedEntryIndex := guiItems["FleetListBox"].Value
	if (selectedEntryIndex != 1){
		userSettings["Fleet"].RemoveAt(selectedEntryIndex) ; MUST USE REMOVEAT INSTEAD OF DELETE TO REMOVE THE ITEM COMPLETELY NOT JUST ITS VALUE
		guiItems["FleetListBox"].Delete(selectedEntryIndex)
		guiItems["FleetListBox"].Choose(selectedEntryIndex - 1 )
		HandleListChange()
		Loop userSettings["Fleet"].Length { 	; Update is index
			userSettings["Fleet"][A_Index].index := A_Index - 1
			userSettings["Fleet"][A_Index].id := A_Index - 1
			; TODO: the id is enough, remove index later
		}
	}
	else
		MsgBox("Can't delete the default entry", "Apollo Fleet Manager - Error", "Owner" myGui.Hwnd " 4112 T2")
	;TODO instead of msgbox, add a statubar like to show the error in there for few seconds/until new label/error is raised
	Sleep (100)
}
HandleAndroidSelector(*) {
	global userSettings
	Selectors := ["AndroidMicSelector", "AndroidCamSelector"]
	Controls := ["AndroidMicCheckbox", "AndroidCamCheckbox"]
	enableSettings := ["MicEnable", "CamEnable"]
	idSettings := ["MicDeviceID", "CamDeviceID"]
	Loop Selectors.Length {
		guiItems[Selectors[A_index]].Enabled := settingsLocked ? 0 : guiItems[Controls[A_index]].Value

		userSettings["Android"].%enableSettings[A_index]% := guiItems[Controls[A_index]].Value
        userSettings["Android"].%idSettings[A_index]% := guiItems[Selectors[A_index]].Value
	}
	UpdateButtonsLables()
}

global currentlySelectedIndex := 1
HandleListChange(*) {
	global guiItems, userSettings, currentlySelectedIndex
	currentlySelectedIndex := guiItems["FleetListBox"].Value = 0 ? 1 : guiItems["FleetListBox"].Value
	guiItems["FleetNameBox"].Value := userSettings["Fleet"][currentlySelectedIndex].Name
	guiItems["FleetPortBox"].Value := userSettings["Fleet"][currentlySelectedIndex].Port
	guiItems["FleetNameBox"].Opt(((settingsLocked || currentlySelectedIndex = 1) ? "+ReadOnly" : "-ReadOnly"))
	guiItems["FleetPortBox"].Opt(((settingsLocked || currentlySelectedIndex = 1) ? "+ReadOnly" : "-ReadOnly"))
	myLink := "https://localhost:" . userSettings["Fleet"][(userSettings["Manager"]["SyncSettings"] = 1 ? 1 : currentlySelectedIndex)].Port+1
	guiItems["FleetLinkBox"].Text :=  '<a href="' . myLink . '">' . myLink . '</a>'
	UpdateButtonsLables()
}
UpdateWindowPosition(){
	global savedSettings, myGui
	if (userSettings["Window"]["restorePosition"] && DllCall("IsWindowVisible", "ptr", myGui.Hwnd) ){
		WinGetPos(&x, &y, , , "ahk_id " myGui.Hwnd)
		; Save position
		userSettings["Window"]["xPos"] := x
		userSettings["Window"]["yPos"] := y
		if !UserSettingsWaiting()
			WriteSettingsFile(savedSettings)
	}
}
HandleLogsButton(*) {
	global guiItems, savedSettings
	userSettings["Window"]["logShow"] := !userSettings["Window"]["logShow"]
	guiItems["ButtonLogsShow"].Text := (userSettings["Window"]["logShow"] = 1 ? "Hide Logs" : "Show Logs")
	UpdateWindowPosition()
	RestoremyGui()
	Sleep (100)
}
HandleReloadButton(*) {
	global settingsLocked, userSettings, savedSettings
	;if settingsLocked && UserSettingsWaiting() {
	;	if (userSettings["Manager"]["SyncSettings"] != userSettings["Manager"]["SyncSettings"]) {
	;		for i in userSettings["Fleet"]
	;			if i.Enabled = 1 && FileExist(i.configFile)
	;				FileDelete(i.configFile)
	;	}
	;	Reload
	;} TODO : MAYBE Add a 3rd state in between Locked/Reload > Unlocked/Cancel > *Save/Cancel* > Apply/Discard > Lock / Reload ? 
	if settingsLocked {
		WriteSettingsFile(userSettings)
		Sleep(100)
		Reload
	}
	else {
		ReflectSettings(savedSettings)
		HandleSettingsLock()
		userSettings := DeepClone(savedSettings)
	}
	Sleep (100)
}
DeepClone(obj) {
    if (obj is Map) {
        out := Map()
        for key, val in obj
            out[key] := DeepClone(val)
        return out
    } else if (obj is Array) {
        out := []
        for val in obj
            out.Push(DeepClone(val))
        return out
    }
    return obj
}
;------------------------------------------------------------------------------  
; Recursively compare any two values (Map, Array, or primitive).  
; Returns 1 if they differ anywhere, 0 if identical.  
DeepCompare(a, b) {
    if (a is Map) {
        if !(b is Map)
            return 1
        for key, val in a {
            if !b.Has(key)          ; ← use Map.Has(key) in v2 :contentReference[oaicite:0]{index=0}
                return 1
            if DeepCompare(val, b[key])
                return 1
        }
        return 0
    }
    else if (a is Array) {
        if !(b is Array)
            return 1
        if (a.Length != b.Length) ; array length mismatch
            return 1
        for index, val in a {
            if DeepCompare(val, b[index])
                return 1
        }
        return 0
    }
    ; --- Primitive (Number, String, etc.)  
    return a != b
}

;------------------------------------------------------------------------------  
; Returns 1 if savedSettings vs. userSettings differ anywhere (skips "Window"), else 0  
UserSettingsWaiting() {
    global savedSettings, userSettings

    for group, subMap in savedSettings {
        ;if (group = "Window" || group = "Manager")	Not neccessary as we copy reference between these settings group for both active and staged
        ;    continue

        if !userSettings.Has(group)  ; missing top‑level group
            return 1

        if DeepCompare(subMap, userSettings[group])
            return 1
    }
    return 0
}

UpdateButtonsLables(){
	global guiItems, settingsLocked
	guiItems["ButtonLockSettings"].Text := UserSettingsWaiting() ? "Save" : settingsLocked ? "🔒" : "🔓" 
	guiItems["ButtonReload"].Text := settingsLocked ?  "Reload" : "Cancel"
}
ApplyLockState(){
	global settingsLocked, guiItems
	textBoxes := [ "PathsApolloBox"]
	checkBoxes := ["FleetAutoLaunchCheckBox", "AndroidReverseTetheringCheckbox", "AndroidMicCheckbox", "AndroidCamCheckbox", "FleetSyncCheckbox"]
	Buttons := ["FleetButtonDelete", "FleetButtonAdd", "PathsApolloBrowseButton"]
	Selectors := ["AndroidMicSelector", "AndroidCamSelector"]
	Controls := ["AndroidMicCheckbox", "AndroidCamCheckbox"]
	iBoxes := ["FleetNameBox", "FleetPortBox"]
	launchChildren := ["FleetSyncVolCheckBox", "FleetRemoveDisconnectCheckbox"]
	launchChildrenLock := userSettings["Manager"]["AutoLaunch"] = 0
	for item in launchChildren
		guiItems[item].Enabled := launchChildrenLock ? 0 : (settingsLocked ? 0 : 1)
	for checkBox in checkBoxes
		guiItems[checkBox].Enabled := (settingsLocked ? 0 : 1)
	for button in Buttons
		guiItems[button].Enabled := (settingsLocked ? 0 : 1)
	for textBox in textBoxes
		guiItems[textbox].Opt(settingsLocked ? "+ReadOnly" : "-ReadOnly")
	for textBox in iBoxes
		guiItems[textBox].Opt(((settingsLocked || currentlySelectedIndex = 1) ? "+ReadOnly" : "-ReadOnly"))
	for i, selector in Selectors
		guiItems[selector].Enabled := settingsLocked ? 0 : guiItems[Controls[i]].Value
}
global settingsLocked := 1
SaveUserSettings(){
	global userSettings, savedSettings
	savedSettings := DeepClone(userSettings)
	userSettings["Manager"] := savedSettings["Manager"]
	userSettings["Window"] := savedSettings["Window"]
}
HandleSettingsLock(*) {
    global guiItems, settingsLocked, savedSettings, userSettings
	UpdateButtonsLables()
	if !UserSettingsWaiting() {
		settingsLocked := !settingsLocked
	} else {
		; hence we need to save settings "clone staged into active and save them"

		SaveUserSettings()
		Sleep (100)
		HandleSettingsLock()
		;MsgBox(savedSettings["Fleet"][2].configFile)
		return
		; Maybe add settings.bak to restore in case new settings didn't work or so
	}
	ApplyLockState()
	UpdateButtonsLables()
	Sleep (100)
}
ExitMyApp() {
	global myGui, savedSettings
	UpdateWindowPosition()
	userSettings["Manager"] := savedSettings["Manager"]
	userSettings["Window"] := savedSettings["Window"]
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

   userSettings["Window"]["lastState"] := 0
    ; Now hide the window
    myGui.Hide()
	Sleep (100)
}
RestoremyGui() {
	global myGui, userSettings

	h := (userSettings["Window"]["logShow"] = 0 ? 198 : 600)
	x := userSettings["Window"]["xPos"]
	y := userSettings["Window"]["yPos"]

	xC := (A_ScreenWidth - 580)/2 
	yC := (A_ScreenHeight - h)/2

	if (x > SysGet(78) || y > SysGet(79)){
		x := xC
		y := yC
	}

	if (savedSettings["Window"]["restorePosition"]) 
		myGui.Show("x" x " y" y " w580 h" h)
	else
		myGui.Show("x" xC " y" yC "w580 h" h)

	savedSettings["Window"]["lastState"] := 1
	Sleep (100)
}
ShowmyGui() {
	global myGui, userSettings
	if userSettings["Manager"]["cmdReload"] = 1 {
		userSettings["Manager"]["cmdReload"] = 0
		WriteSettingsFile(userSettings)
		RestoremyGui()
	} else if (userSettings["Window"]["lastState"] = 1) {
		if (userSettings["Window"]["restorePosition"]){
			userSettings["Window"]["restorePosition"] := 0
			RestoremyGui()
			userSettings["Window"]["restorePosition"] := 1
		} else
			RestoremyGui()
	} else
		return
	Sleep (100)
}


FleetConfigInit(*){
	global savedSettings
	
	; clean and prepare conf directory
	if !DirExist(savedSettings["Paths"]["Config"])	
		DirCreate(savedSettings["Paths"]["Config"])
	configDir := savedSettings["Paths"]["Config"]
	; to delete any unexpected file "such as residual config/log"
	Loop Files configDir . '\*.*' {
		fileIdentified := 0
		for i in savedSettings["Fleet"]{
			if A_LoopFileFullPath = i.configFile || A_LoopFileFullPath = i.logFile || A_LoopFileFullPath = i.stateFile   {
				fileIdentified := 1
				break
			}
		}
		if !fileIdentified
			FileDelete(A_LoopFileFullPath)
	}
	; import default conf if sync is ticked
	baseConf := Map()
	if (savedSettings["Manager"]["SyncSettings"]) {
		defaultConfFile := savedSettings["Paths"]["Apollo"] . "\config\sunshine.conf"
		baseConf := ConfRead(defaultConfFile)
		if baseConf.Has("sunshine_name") 
			baseConf.Delete("sunshine_name") 
		if baseConf.Has("port")
			baseConf.Delete("port")
	}
	; assign and create conf files if not created
	for i in savedSettings["Fleet"] {
		if (i.Enabled = 1) {
			if !(savedSettings["Manager"]["SyncSettings"]) && FileExist(i.configFile)
				thisConf:= ConfRead(i.configFile)	; this will keep config file to retain user modified settings
			else
				thisConf := DeepClone(baseConf)
			thisConf.set("sunshine_name", i.Name, "port", i.Port)
			if !FileExist(i.configFile) || !(FileGetTime(i.configFile, "M" ) = i.LastConfigUpdate)
				ConfWrite(i.configFile, thisConf)
			i.LastConfigUpdate := FileGetTime(i.configFile, "M" ) ; TODO implement this: only update if there's need/change
		}
	} 
	
	if savedSettings["Manager"]["AutoLaunch"]
		SetTimer LogWatchDog, -1

	if savedSettings["Manager"]["SyncVolume"] || savedSettings["Manager"]["RemoveDisconnected"]
		SetTimer LogWatchDog, 100000

	if savedSettings["Android"]["MicEnable"] || savedSettings["Android"]["CamEnable"]
		SetTimer ADBWatchDog, 100000

	if savedSettings["Manager"]["SyncVolume"]
		SetTimer FleetSyncVolume, 10000

	if savedSettings["Manager"]["SyncSettings"]
		SetTimer FleetSyncSettings, 100000

}

FleetLaunch(*){
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



bootstrapSettings() {
	global savedSettings := Map(), userSettings := Map(), runtimeSettings := Map()

	ReadSettingsFile(, userSettings)
	SaveUserSettings()
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
SendSigInt(pid, hard:=false) {
    ; 1. Tell this script to ignore Ctrl+C and Ctrl+Break
    DllCall("SetConsoleCtrlHandler", "Ptr", 0, "UInt", 1)
    ; 2. Detach from current console, attach to target's
    DllCall("FreeConsole")
    DllCall("AttachConsole", "UInt", pid)
    ; 3. Send Ctrl+C (SIGINT) to all processes in that console (including the target)
    DllCall("GenerateConsoleCtrlEvent", "UInt", 0, "UInt", 0)
	DllCall("FreeConsole")

    Sleep 100  ; Give the target process time to exit

	if hard && ProcessExist(pid)
		ProcessClose(pid)

	return ProcessExist(pid)
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
    ) ; TODO issue here is we get the console PID, not the PID for the processes itself
	  ; HOW we will later keep the pid of the processes if we don't have it? TODO
	  ; And we can't send SIGINT directly to the PID itself btw so in case of orphan PIDs will have to terminate it.
	  ; DONE we just need to keep both console PID (used to send SIGINT) and apollo PID (to not kill it if still usable)
	for process in ComObject("WbemScripting.SWbemLocator").ConnectServer().ExecQuery("Select * from Win32_Process where ParentProcessId=" consolePID)
		if InStr(process.CommandLine, exePath) {
			apolloPID := process.ProcessId
			break
		}
		
	return [consolePID, apolloPID]
}


FleetLaunchFleet(){
	global savedSettings

	; get currently running PIDs 
	; terminate anything unknown to us
	; if any PID is known try to test it and reuse it if it is still working "TODO maybe add option to start clean"
	; TODO its time to make settings load/save work for single setting group
	; start is and register write PIDs in settings file 

	; for now, lets just kill any exisiting proccess 

	currentPIDs := PIDsListFromExeName("sunshine.exe")
	knwonPIDs := []
	for i in savedSettings["Fleet"]
		if i.Enabled && (i.apolloPID > 0)
			knwonPIDs.Push(i.apolloPID)
	for pid in currentPIDs
		if !(knwonPIDs.Has(pid))
			SendSigInt(pid)
	Sleep(1000) ; keep it here for now,  
	exe := savedSettings["Paths"]["apolloExe"]
	for i in savedSettings["Fleet"]
		if i.Enabled && !ProcessExist(i.apolloPID){
			pids := RunAndGetPIDs(exe, i.configFile)
			i.consolePID := pids[1]
			i.apolloPID := pids[2]
		}
	MsgBox(savedSettings["Fleet"][1].consolePID . ":" . savedSettings["Fleet"][1].apolloPID)

	; modify our runtime things "that we must save" in savedSettings, and exclude those particular items/groups from being overwritten by userSettings
	; Also, exclude these from UserSettingsWaiting() function so it doesn't stop us from saving them.
}

bootstrapSettings()

if savedSettings["Manager"]["AutoLaunch"] {
	; TODO Disable default service and create/enable ours 
	FleetConfigInit()
	FleetLaunchFleet()	; check previous ones > if they're valid keep them 
	;timer 1000 FleetCheckFleet() ; this is a combination of i check/ logmonitor for connected/disconnected events/ 
	; if enabled, start timer 50 SyncVolume to try sync volume as soon as client connects, probably can verify it too "make it smart not dumb"
	; if enabled, start timer 50 ForceClose to try send SIGINT to i once client disconnected > the rest should be cought by FleetCheckFleet to relaunch it again "if it didn't relaunch by itself" 
} 
if savedSettings["Android"]["ReverseTethering"]{
	; AndroidStartGnirehtet() ; check existing > test it > if invalid start new one, until this is a reload; kill it!
	; timer 1000 AndroidCheckGnirehtet() Possibily we can do it smart way to check if its still alive/there's connections
}
if savedSettings["Android"]["MicEnable"] || savedSettings["Android"]["CamEnable"] {
	; here we sadly need to kill every existing adb.exe process, possibly via kill-server adb command
	; timer 1000 AndroidDevicesList() ; to keep track of currently connected, and disconnected devices with their IDs and time of connection/disconnection and previous time too "maybe we can do something smarter here too"
	if savedSettings["Android"]["MicEnable"]{
		; if the existing scrcpy proccess is ours, and it was created for the same devID keep it, until this is a reload; kill it!
		; check if the micID is non-empty maybe we can do this in a loop as it doesn't really need reload to apply if changed
		; if 
	}
}

bootstrapGUI()

; ───── Keep script alive ─────
While 1
    Sleep(100)

	; TODO Validate settings and reset invalid ones, clear invalid is
	; TODO Keep the last remembered PIDs if they are still running
	; test them "maybe wget or sorta" 
	; kill the rest 

	; if AutoLaunch is set, check for schduleded task, add it if missing, enable it if disabled
	; else disable it ;;; EDIT: AutoLaunch will be used to determine if we launch these is or not at all
	;							TODO Introduce Auto run at startup setting to specifically do that 

