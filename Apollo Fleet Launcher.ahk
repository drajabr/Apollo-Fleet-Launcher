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

LoadSettingsFile(settingsFile:="settings.ini", Settings:=Map()) {
	Settings["Manager"] := Map()
	Settings["Window" ] := Map()
	Settings["Paths"  ] := Map()
	Settings["Fleet"  ] := Map()
	Settings["Android"] := Map()
	Settings["Fleet"]["Instances"] := []

	if !FileExist(settingsFile)
        FileAppend "", settingsFile

	
	;Settings["Manager"]["SchduledService"]	; TODO
	;Settings["Manager"]["StartMinimized"]	; TODO as option in the UI instead of auto save it 
	Settings["Manager"]["cmdReload"] := IniRead(settingsFile, "Manager", "cmdReload", 0)
	
	Settings["Window"]["restorePosition"] := IniRead(settingsFile, "Window", "restorePosition", 1)
	Settings["Window"]["xPos"] := IniRead(settingsFile, "Window", "xPos", (A_ScreenWidth - 580) / 2)
	Settings["Window"]["yPos"] := IniRead(settingsFile, "Window", "yPos", (A_ScreenHeight - 198) / 2)
	Settings["Window"]["lastState"] := IniRead(settingsFile, "Window", "lastState", true)
	Settings["Window"]["logShow"] := IniRead(settingsFile, "Window", "logShow", true)


	DefaultApolloPath := "C:\Program Files\Apollo"
	DefaultConfigPath := A_ScriptDir . "\config"
	DefaultADBPath := A_ScriptDir . "\platform-tools"
	Settings["Paths"]["Apollo"]  := IniRead(settingsFile, "Paths", "Apollo", DefaultApolloPath)
	Settings["Paths"]["Config"]  := IniRead(settingsFile, "Paths", "Config", DefaultConfigPath)
	Settings["Paths"]["ADBTools"]  := IniRead(settingsFile, "Paths", "ADB", DefaultADBPath)
	

	Settings["Fleet"]["AutoLaunch"] := IniRead(settingsFile, "Fleet Options", "AutoLaunch", 1)
	Settings["Fleet"]["SyncVolume"] := IniRead(settingsFile, "Fleet Options", "SyncVolume", 1)
	Settings["Fleet"]["RemoveDisconnected"] := IniRead(settingsFile, "Fleet Options", "RemoveDisconnected", 1)
	Settings["Fleet"]["SyncSettings"] := IniRead(settingsFile, "Fleet Options", "SyncSettings", 1)

	Settings["Android"]["ReverseTethering"]  := IniRead(settingsFile, "Android Clients", "ReverseTethering", 1)
	Settings["Android"]["gnirehtetPID"] := IniRead(settingsFile, "Android Clients", "gnirehtetPID", "")  
	Settings["Android"]["MicEnable"]  := IniRead(settingsFile, "Android Clients", "MicEnable", 0)
	Settings["Android"]["MicDeviceID"]  := IniRead(settingsFile, "Android Clients", "MicDeviceID", "")
	Settings["Android"]["scrcpyMicPID"] := IniRead(settingsFile, "Android Clients", "scrcpyMicPID", "")  
	Settings["Android"]["CamEnable"]  := IniRead(settingsFile, "Android Clients", "CamEnable", 0)
	Settings["Android"]["CamDeviceID"]  := IniRead(settingsFile, "Android Clients", "CamDeviceID", "")
	Settings["Android"]["scrcpyCamPID"] := IniRead(settingsFile, "Android Clients", "scrcpyCamPID", "")  


	defaultConfFile := Settings["Paths"]["Apollo"] . "\config\sunshine.conf"
	instance := {} ; Create a new object for each instance
	instance.index := 0
	instance.id := 0
	instance.Name := ConfRead(defaultConfFile, "sunshine_name", "default instance")
	instance.Port := ConfRead(defaultConfFile, "port", "47989")
	instance.Enabled := 0
	instance.LastKnownPID := 0
	instance.LastConfigUpdate := 0
	instance.LastReadLogLine := 0
	instance.configFile := Settings["Paths"]["Apollo"] . '\config\sunshine.conf'
	instance.logFile := Settings["Paths"]["Apollo"] . '\config\sunshine.log'
	instance.stateFile := Settings["Paths"]["Apollo"] . '\config\sunshine.json'

	; instance.Audio := IniRead(settingsFile, section, "Port", "") TODO Seperate audio device for each instance through gui
	Settings["Fleet"]["Instances"].Push(instance) ; Add the instance object to the Settings["Fleet"]["Instances"] array


    ; Iterate through all sections, focusing on "instance"
	index := 1
    ; Iterate through all sections, focusing on "instance"
    sectionsNames := StrSplit(IniRead(settingsFile), "`n")
    for section in sectionsNames {
        if (SubStr(section, 1, 8) = "Instance") { ; section name starts with Instance
            instance :={} ; Create a new object for each instance
			instance.index := index
            instance.id := IsNumber(SubStr(section, 9 )) ? SubStr(section, 9 ) : index
            instance.Name := IniRead(settingsFile, section, "Name", "instance" . index)
            instance.Port := IniRead(settingsFile, section, "Port", 10000 + index * 1000)
			instance.Enabled := IniRead(settingsFile, section, "Enabled", true)
			instance.LastKnownPID := IniRead(settingsFile, section, "LastKnownPID", false)
			instance.LastConfigUpdate := IniRead(settingsFile, section, "LastConfigUpdate", false)
			instance.LastReadLogLine := IniRead(settingsFile, section, "LastReadLogLine", false)

			instance.configFile := Settings["Paths"]["Config"] . '\fleet-' . instance.id . (Settings["Fleet"]["SyncSettings"] = 1 ?  '-synced.conf' : '.conf')
			instance.logFile := Settings["Paths"]["Config"] . '\fleet-' . instance.id . '.log'
			instance.stateFile := Settings["Paths"]["Config"] . '\fleet-' . instance.id . '.json'
            ; instance.Audio := IniRead(settingsFile, section, "Port", "") TODO
			Settings["Fleet"]["Instances"].Push(instance) ; Add the instance object to the Settings["Fleet"]["Instances"] array
			index := index + 1
        }
    }
}
SaveSettingsFile(Settings:=Map(), settingsFile:="settings.ini") {
    if FileExist(settingsFile)
        FileDelete(settingsFile)
	FileAppend "", settingsFile
	
	UpdateWindowPosition()

    IniWrite(Settings["Manager"]["cmdReload"], settingsFile, "Manager", "cmdReload")

    ; Window State
    IniWrite(Settings["Window"]["restorePosition"], settingsFile, "Window", "restorePosition")
	IniWrite(Settings["Window"]["xPos"], settingsFile, "Window", "xPos")
    IniWrite(Settings["Window"]["yPos"], settingsFile, "Window", "yPos")
    IniWrite(Settings["Window"]["lastState"], settingsFile, "Window", "lastState")
	IniWrite(Settings["Window"]["logShow"], settingsFile, "Window", "logShow")

    ; Paths
    IniWrite(Settings["Paths"]["Apollo"], settingsFile, "Paths", "Apollo")
    IniWrite(Settings["Paths"]["Config"], settingsFile, "Paths", "Config")
    IniWrite(Settings["Paths"]["ADBTools"], settingsFile, "Paths", "ADB")

    ; Fleet Options
    IniWrite(Settings["Fleet"]["AutoLaunch"], settingsFile, "Fleet Options", "AutoLaunch")
    IniWrite(Settings["Fleet"]["SyncVolume"], settingsFile, "Fleet Options", "SyncVolume")
    IniWrite(Settings["Fleet"]["RemoveDisconnected"], settingsFile, "Fleet Options", "RemoveDisconnected")
    IniWrite(Settings["Fleet"]["SyncSettings"], settingsFile, "Fleet Options", "SyncSettings")

    ; Android Clients
    IniWrite(Settings["Android"]["ReverseTethering"], settingsFile, "Android Clients", "ReverseTethering")
	IniWrite(Settings["Android"]["gnirehtetPID"], settingsFile, "Android Clients", "gnirehtetPID")
    IniWrite(Settings["Android"]["MicEnable"], settingsFile, "Android Clients", "MicEnable")
	IniWrite(Settings["Android"]["MicDeviceID"], settingsFile, "Android Clients", "MicDeviceID")
	IniWrite(Settings["Android"]["scrcpyMicPID"], settingsFile, "Android Clients", "scrcpyMicPID")

	IniWrite(Settings["Android"]["CamEnable"], settingsFile, "Android Clients", "CamEnable")
    IniWrite(Settings["Android"]["CamDeviceID"], settingsFile, "Android Clients", "CamDeviceID")
	IniWrite(Settings["Android"]["scrcpyCamPID"], settingsFile, "Android Clients", "scrcpyCamPID")


    ; Instances
    for instance in Settings["Fleet"]["Instances"] {
		if instance.id > 0 {
        	sectionName := "Instance" instance.id
			IniWrite(instance.Name, settingsFile, sectionName, "Name")
			IniWrite(instance.Port, settingsFile, sectionName, "Port")
			IniWrite(instance.Enabled, settingsFile, sectionName, "Enabled")
			IniWrite(instance.LastKnownPID, settingsFile, sectionName, "LastKnownPID")
			IniWrite(instance.LastConfigUpdate, settingsFile, sectionName, "LastConfigUpdate")
			IniWrite(instance.LastReadLogLine, settingsFile, sectionName, "LastReadLogLine")
			; IniWrite(instance.Audio, settingsFile, sectionName, "Audio") ; TODO

		}
    }
}
AllInstancesArray(Settings){
	instancesList := []  ; Create an empty array
	for instance in Settings["Fleet"]["Instances"] 
		instancesList.Push(instance.Name)  ; Add the Name property to the array
	return instancesList
}
InitmyGui() {
	;TODO implement dark theme and follow system theme if possible 
	global myGui, guiItems := Map()
	TraySetIcon("shell32.dll", "19")
	myGui := Gui("+AlwaysOnTop -MinimizeBox -MaximizeBox")
	guiItems["ButtonLockSettings"] := myGui.Add("Button", "x520 y5 w50 h40", "🔒")
	guiItems["ButtonReload"] := myGui.Add("Button", "x520 y50 w50 h40", "Reload")
	guiItems["ButtonLogsShow"] := myGui.Add("Button", "x520 y101 w50 h40", "Show Logs")
	guiItems["ButtonMinimize"] := myGui.Add("Button", "x520 y150 w50 h40", "Minimize")
	myGui.Add("GroupBox", "x318 y0 w196 h90", "Fleet Options")
	guiItems["FleetAutoLaunchCheckBox"] := myGui.Add("CheckBox", "x334 y16 w162 h23", "Auto Launch Fleet Instances")
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
	myGui.Add("GroupBox", "x8 y0 w300 h192", "Instances")
	guiItems["InstancesListBox"] := myGui.Add("ListBox", "x16 y66 w100 h82 +0x100 Choose1")
	myGui.Add("Text", "x126 y70", "Name:")
	guiItems["InstancesNameBox"] := myGui.Add("Edit", "x166 y65 w130 h23")
	guiItems["InstancesNameBox"].Value := savedSettings["Fleet"]["Instances"][1].Name
	myGui.Add("Text", "x126 y98", "Port:")
	guiItems["InstancesPortBox"] := myGui.Add("Edit", "x166 y92 w130 h23 +ReadOnly", "")
	guiItems["InstancesPortBox"].Value := savedSettings["Fleet"]["Instances"][1].Port
	;myGui.Add("Text", "x126 y120 w54 h23", "Audio:")
	;guiItems["InstancesAudioSelector"] := myGui.Add("ComboBox", "x166 y120 w130", [])
	myGui.Add("Text", "x126 y126 ", "Link:")
	myLink := "https://localhost:" . savedSettings["Fleet"]["Instances"][(savedSettings["Fleet"]["SyncSettings"] = 1 ? 1 : currentlySelectedIndex)].Port+1
	guiItems["InstancesLinkBox"] := myGui.Add("Link", "x166 y126", '<a href="' . myLink . '">' . myLink . '</a>')
	guiItems["FleetSyncCheckbox"] := myGui.Add("CheckBox", "x130 y155 w165 h23", " Copy Default Instance Settings")
	guiItems["InstancesButtonAdd"] := myGui.Add("Button", "x49 y155 w71 h23", "Add")
	guiItems["InstancesButtonDelete"] := myGui.Add("Button", "x16 y155 w27 h23", "✖")
	guiItems["LogTextBox"] := myGui.Add("Edit", "x8 y199 w562 h393 -VScroll +ReadOnly")
	myGui.Title := "Apollo Fleet Launcher"
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
	guiItems["FleetAutoLaunchCheckBox"].Value := Settings["Fleet"]["AutoLaunch"]
	guiItems["FleetSyncVolCheckBox"].Value := Settings["Fleet"]["SyncVolume"]
	guiItems["FleetRemoveDisconnectCheckbox"].Value := Settings["Fleet"]["RemoveDisconnected"]
	guiItems["FleetSyncCheckbox"].Value := Settings["Fleet"]["SyncSettings"]
	guiItems["AndroidReverseTetheringCheckbox"].Value := Settings["Android"]["ReverseTethering"]
	guiItems["AndroidMicCheckbox"].Value := Settings["Android"]["MicEnable"]
	guiItems["AndroidMicSelector"].Value := Settings["Android"]["MicDeviceID"]
	guiItems["AndroidCamCheckbox"].Value := Settings["Android"]["CamEnable"]
	guiItems["AndroidCamSelector"].Value := Settings["Android"]["CamDeviceID"]
	guiItems["PathsApolloBox"].Value := Settings["Paths"]["Apollo"]
	guiItems["ButtonLogsShow"].Text := (Settings["Window"]["logShow"] = 1 ? "Hide Logs" : "Show Logs")
	;guiItems["InstancesAudioSelector"].Enabled :=0
	guiItems["InstancesListBox"].Delete()
	guiItems["InstancesListBox"].Add(AllInstancesArray(Settings))
}
InitmyGuiEvents(){
	global myGui, guiItems
	myGui.OnEvent('Close', (*) => ExitMyApp())
	guiItems["ButtonMinimize"].OnEvent("Click", MinimizemyGui)
	guiItems["ButtonLockSettings"].OnEvent("Click", HandleSettingsLock)
	guiItems["ButtonReload"].OnEvent("Click", HandleReloadButton)
	guiItems["ButtonLogsShow"].OnEvent("Click", HandleLogsButton)
	guiItems["InstancesListBox"].OnEvent("Change", HandleListChange)

	guiItems["AndroidReverseTetheringCheckbox"].OnEvent("Click", HandleCheckBoxes) ; (*) => sessionSettings["Android"]["ReverseTethering"] := guiItems["AndroidReverseTetheringCheckbox"].Value)
	guiItems["AndroidMicCheckbox"].OnEvent("Click", HandleAndroidSelector) ; (*)=> guiItems["AndroidMicSelector"].Enabled := guiItems["AndroidMicCheckbox"].Value)
	guiItems["AndroidCamCheckbox"].OnEvent("Click", HandleAndroidSelector) ; (*)=> guiItems["AndroidCamSelector"].Enabled := guiItems["AndroidMicCheckbox"].Value)

	guiItems["FleetAutoLaunchCheckBox"].OnEvent("Click", HandleCheckBoxes) ; (*) => sessionSettings["Fleet"]["AutoLaunch"] := guiItems["FleetAutoLaunchCheckBox"].Value)
	guiItems["FleetSyncVolCheckBox"].OnEvent("Click", HandleCheckBoxes) ;(*) => sessionSettings["Fleet"]["SyncVolume"] := guiItems["FleetSyncVolCheckBox"].Value)
	guiItems["FleetRemoveDisconnectCheckbox"].OnEvent("Click", HandleCheckBoxes) ;(*) => sessionSettings["Fleet"]["RemoveDisconnected"] := guiItems["FleetRemoveDisconnectCheckbox"].Value)
	guiItems["FleetSyncCheckbox"].OnEvent("Click", HandleFleetSyncCheck)

	guiItems["InstancesButtonAdd"].OnEvent("Click", HandleInstanceAddButton)
	guiItems["InstancesButtonDelete"].OnEvent("Click", HandleInstanceDeleteButton)

	guiItems["InstancesNameBox"].OnEvent("Change", HandleNameChange)
	guiItems["InstancesPortBox"].OnEvent("LoseFocus", HandlePortChange)
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
	global sessionSettings, guiItems
	sessionSettings["Android"]["ReverseTethering"] := guiItems["AndroidReverseTetheringCheckbox"].Value
	sessionSettings["Fleet"]["AutoLaunch"] := guiItems["FleetAutoLaunchCheckBox"].Value
	launchChildren := ["FleetSyncVolCheckBox", "FleetRemoveDisconnectCheckbox"]
	launchChildrenLock := sessionSettings["Fleet"]["AutoLaunch"] = 0
	for item in launchChildren
		guiItems[item].Enabled := launchChildrenLock ? 0 : 1
	sessionSettings["Fleet"]["SyncVolume"] := guiItems["FleetSyncVolCheckBox"].Value
	sessionSettings["Fleet"]["RemoveDisconnected"] := guiItems["FleetRemoveDisconnectCheckbox"].Value
	UpdateButtonsLables()
}

HandleFleetSyncCheck(*){
	global sessionSettings, guiItems
	sessionSettings["Fleet"]["SyncSettings"] := guiItems["FleetSyncCheckbox"].Value
	; change conf file name so its recognized as synced, also, to trigger delete for non-synced config "and vice versa" on next reload 
	for instance in sessionSettings["Fleet"]["Instances"]
		instance.configFile := sessionSettings["Paths"]["Config"] . '\fleet-' . instance.id . (sessionSettings["Fleet"]["SyncSettings"] = 1 ?  '-synced.conf' : '.conf')
	HandleListChange()
}
RefreshInstancesList(){
	global guiItems, sessionSettings
	guiItems["InstancesListBox"].Delete()
	guiItems["InstancesListBox"].Add(AllInstancesArray(sessionSettings))
	UpdateButtonsLables()
}
HandlePortChange(*){
	global sessionSettings, guiItems
	selectedEntryIndex := guiItems["InstancesListBox"].Value
	newPort := guiItems["InstancesPortBox"].Value = "" ? sessionSettings["Fleet"]["Instances"][selectedEntryIndex].Port : guiItems["InstancesPortBox"].Value 
	valid := (1024 < newPort && newPort < 65000) ? true : false
	for instance in sessionSettings["Fleet"]["Instances"]
		if (instance.Port = newPort)
			valid := false
	if valid {
		sessionSettings["Fleet"]["Instances"][selectedEntryIndex].Port := newPort
		myLink := "https://localhost:" . sessionSettings["Fleet"]["Instances"][(sessionSettings["Fleet"]["SyncSettings"] = 1 ? 1 : currentlySelectedIndex)].Port+1
		guiItems["InstancesLinkBox"].Text :=  '<a href="' . myLink . '">' . myLink . '</a>'	
	} else {
		guiItems["InstancesPortBox"].Value := sessionSettings["Fleet"]["Instances"][currentlySelectedIndex].Port
	}
	UpdateButtonsLables()
}
HandleNameChange(*){
	global sessionSettings, guiItems
	newName := guiItems["InstancesNameBox"].Value
	selectedEntryIndex := guiItems["InstancesListBox"].Value
	sessionSettings["Fleet"]["Instances"][selectedEntryIndex].Name := newName
	RefreshInstancesList()
	guiItems["InstancesListBox"].Choose(selectedEntryIndex)
}
HandleInstanceAddButton(*){
	global sessionSettings, guiItems
	
	instance := {} ; Create a new object for each instance
	instance.index := sessionSettings["Fleet"]["Instances"][-1].index + 1
	if (instance.index > 5){
		MsgBox("Let's not add more than 5 instances for now.")
	} else {
	instance.id := instance.index
	instance.Port := instance.id = 1 ? 10000 : sessionSettings["Fleet"]["Instances"][-1].port + 1000
	instance.Name := "Instance " . instance.Port
	instance.Enabled := 1
	instance.LastKnownPID := 0
	instance.LastConfigUpdate := 0
	instance.LastReadLogLine := 0
	instance.configFile := sessionSettings["Paths"]["Config"] . '\fleet-' . instance.id . '.conf'
	instance.logFile := sessionSettings["Paths"]["Config"] . '\fleet-' . instance.id . '.log'
	instance.stateFile := sessionSettings["Paths"]["Config"] . '\fleet-' . instance.id . '.json'
	sessionSettings["Fleet"]["Instances"].Push(instance) ; Add the instance object to the sessionSettings["Fleet"]["Instances"] array
	RefreshInstancesList()
	guiItems["InstancesListBox"].Choose(instance.index+1)
	HandleListChange()
	}
	Sleep (100)
}
HandleInstanceDeleteButton(*){
	global sessionSettings, guiItems
	selectedEntryIndex := guiItems["InstancesListBox"].Value
	if (selectedEntryIndex != 1){
		sessionSettings["Fleet"]["Instances"].RemoveAt(selectedEntryIndex) ; MUST USE REMOVEAT INSTEAD OF DELETE TO REMOVE THE ITEM COMPLETELY NOT JUST ITS VALUE
		guiItems["InstancesListBox"].Delete(selectedEntryIndex)
		guiItems["InstancesListBox"].Choose(selectedEntryIndex - 1 )
		HandleListChange()
		Loop sessionSettings["Fleet"]["Instances"].Length { 	; Update instances index
			sessionSettings["Fleet"]["Instances"][A_Index].index := A_Index - 1
			sessionSettings["Fleet"]["Instances"][A_Index].id := A_Index - 1
			; TODO: the id is enough, remove index later
		}
	}
	else
		MsgBox("Can't delete the default entry", "Apollo Fleet Launcher - Error", "Owner" myGui.Hwnd " 4112 T2")
	;TODO instead of msgbox, add a statubar like to show the error in there for few seconds/until new label/error is raised
	Sleep (100)
}
HandleAndroidSelector(*) {
	global sessionSettings
	Selectors := ["AndroidMicSelector", "AndroidCamSelector"]
	Controls := ["AndroidMicCheckbox", "AndroidCamCheckbox"]
	enableSettings := ["MicEnable", "CamEnable"]
	idSettings := ["MicDeviceID", "CamDeviceID"]
	Loop Selectors.Length {
		guiItems[Selectors[A_index]].Enabled := settingsLocked ? 0 : guiItems[Controls[A_index]].Value

		sessionSettings["Android"].%enableSettings[A_index]% := guiItems[Controls[A_index]].Value
        sessionSettings["Android"].%idSettings[A_index]% := guiItems[Selectors[A_index]].Value
	}
	UpdateButtonsLables()
}

global currentlySelectedIndex := 1
HandleListChange(*) {
	global guiItems, sessionSettings, currentlySelectedIndex
	currentlySelectedIndex := guiItems["InstancesListBox"].Value = 0 ? 1 : guiItems["InstancesListBox"].Value
	guiItems["InstancesNameBox"].Value := sessionSettings["Fleet"]["Instances"][currentlySelectedIndex].Name
	guiItems["InstancesPortBox"].Value := sessionSettings["Fleet"]["Instances"][currentlySelectedIndex].Port
	guiItems["InstancesNameBox"].Opt(((settingsLocked || currentlySelectedIndex = 1) ? "+ReadOnly" : "-ReadOnly"))
	guiItems["InstancesPortBox"].Opt(((settingsLocked || currentlySelectedIndex = 1) ? "+ReadOnly" : "-ReadOnly"))
	myLink := "https://localhost:" . sessionSettings["Fleet"]["Instances"][(sessionSettings["Fleet"]["SyncSettings"] = 1 ? 1 : currentlySelectedIndex)].Port+1
	guiItems["InstancesLinkBox"].Text :=  '<a href="' . myLink . '">' . myLink . '</a>'
	UpdateButtonsLables()
}
UpdateWindowPosition(){
	global savedSettings, myGui
	if (sessionSettings["Window"]["restorePosition"] && DllCall("IsWindowVisible", "ptr", myGui.Hwnd) ){
		WinGetPos(&x, &y, , , "ahk_id " myGui.Hwnd)
		; Save position
		sessionSettings["Window"]["xPos"] := x
		sessionSettings["Window"]["yPos"] := y
	}
}
HandleLogsButton(*) {
	global guiItems, savedSettings
	sessionSettings["Window"]["logShow"] := !sessionSettings["Window"]["logShow"]
	guiItems["ButtonLogsShow"].Text := (sessionSettings["Window"]["logShow"] = 1 ? "Hide Logs" : "Show Logs")
	UpdateWindowPosition()
	RestoremyGui()
	Sleep (100)
}
HandleReloadButton(*) {
	global settingsLocked, sessionSettings, savedSettings
	;if settingsLocked && sessionSettingsWaiting() {
	;	if (sessionSettings["Fleet"]["SyncSettings"] != sessionSettings["Fleet"]["SyncSettings"]) {
	;		for instance in sessionSettings["Fleet"]["Instances"]
	;			if instance.Enabled = 1 && FileExist(instance.configFile)
	;				FileDelete(instance.configFile)
	;	}
	;	Reload
	;} TODO : MAYBE Add a 3rd state in between Locked/Reload > Unlocked/Cancel > *Save/Cancel* > Apply/Discard > Lock / Reload ? 
	if settingsLocked {
		SaveSettingsFile(savedSettings)
		Sleep(100)
		Reload
	}
	else {
		ReflectSettings(savedSettings)
		HandleSettingsLock()
		sessionSettings := DeepClone(savedSettings)
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
; Returns 1 if savedSettings vs. sessionSettings differ anywhere (skips "Window"), else 0  
sessionSettingsWaiting() {
    global savedSettings, sessionSettings

    for group, subMap in savedSettings {
        ;if (group = "Window" || group = "Manager")	Not neccessary as we copy reference between these settings group for both active and staged
        ;    continue

        if !sessionSettings.Has(group)  ; missing top‑level group
            return 1

        if DeepCompare(subMap, sessionSettings[group])
            return 1
    }
    return 0
}

UpdateButtonsLables(){
	global guiItems, settingsLocked
	guiItems["ButtonLockSettings"].Text := sessionSettingsWaiting() ? "Save" : settingsLocked ? "🔒" : "🔓" 
	guiItems["ButtonReload"].Text := settingsLocked ?  "Reload" : "Cancel"
}
ApplyLockState(){
	global settingsLocked, guiItems
	textBoxes := [ "PathsApolloBox"]
	checkBoxes := ["FleetAutoLaunchCheckBox", "AndroidReverseTetheringCheckbox", "AndroidMicCheckbox", "AndroidCamCheckbox", "FleetSyncCheckbox"]
	Buttons := ["InstancesButtonDelete", "InstancesButtonAdd", "PathsApolloBrowseButton"]
	Selectors := ["AndroidMicSelector", "AndroidCamSelector"]
	Controls := ["AndroidMicCheckbox", "AndroidCamCheckbox"]
	instanceBoxes := ["InstancesNameBox", "InstancesPortBox"]
	launchChildren := ["FleetSyncVolCheckBox", "FleetRemoveDisconnectCheckbox"]
	launchChildrenLock := sessionSettings["Fleet"]["AutoLaunch"] = 0
	for item in launchChildren
		guiItems[item].Enabled := launchChildrenLock ? 0 : (settingsLocked ? 0 : 1)
	for checkBox in checkBoxes
		guiItems[checkBox].Enabled := (settingsLocked ? 0 : 1)
	for button in Buttons
		guiItems[button].Enabled := (settingsLocked ? 0 : 1)
	for textBox in textBoxes
		guiItems[textbox].Opt(settingsLocked ? "+ReadOnly" : "-ReadOnly")
	for textBox in instanceBoxes
		guiItems[textBox].Opt(((settingsLocked || currentlySelectedIndex = 1) ? "+ReadOnly" : "-ReadOnly"))
	for i, selector in Selectors
		guiItems[selector].Enabled := settingsLocked ? 0 : guiItems[Controls[i]].Value
}
global settingsLocked := true
SaveStagedSettings(){
	global sessionSettings, savedSettings
	savedSettings := DeepClone(sessionSettings)
	sessionSettings["Manager"] := savedSettings["Manager"]
	sessionSettings["Window"] := savedSettings["Window"]
}
HandleSettingsLock(*) {
    global guiItems, settingsLocked, savedSettings, sessionSettings
	UpdateButtonsLables()
	if !sessionSettingsWaiting() {
		settingsLocked := !settingsLocked
	} else {
		; hence we need to save settings "clone staged into active and save them"

		SaveStagedSettings()
		Sleep (100)
		HandleSettingsLock()
		;MsgBox(savedSettings["Fleet"]["Instances"][2].configFile)
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
	sessionSettings["Manager"] := savedSettings["Manager"]
	sessionSettings["Window"] := savedSettings["Window"]
	SaveSettingsFile(savedSettings)
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

   sessionSettings["Window"]["lastState"] := 0
    ; Now hide the window
    myGui.Hide()
	Sleep (100)
}
RestoremyGui() {
	global myGui, savedSettings

	h := (savedSettings["Window"]["logShow"] = 0 ? 198 : 600)
	x := savedSettings["Window"]["xPos"]
	y := savedSettings["Window"]["yPos"]

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
	global myGui, savedSettings
	if savedSettings["Manager"]["cmdReload"] = 1 {
		savedSettings["Manager"]["cmdReload"] = 0
		SaveSettingsFile(savedSettings)
		RestoremyGui()
	} else if (savedSettings["Window"]["lastState"] = 1) {
		if (savedSettings["Window"]["restorePosition"]){
			savedSettings["Window"]["restorePosition"] := 0
			RestoremyGui()
			savedSettings["Window"]["restorePosition"] := 1
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
		fileIdentified := false
		for instance in savedSettings["Fleet"]["Instances"]{

			if A_LoopFileFullPath = instance.configFile || A_LoopFileFullPath = instance.logFile || A_LoopFileFullPath = instance.stateFile   {
				fileIdentified := true
				break
			}
		}
		if !fileIdentified
			FileDelete(A_LoopFileFullPath)
	}
	; import default conf if sync is ticked
	baseConf := Map()
	if (savedSettings["Fleet"]["SyncSettings"]) {
		defaultConfFile := savedSettings["Paths"]["Apollo"] . "\config\sunshine.conf"
		baseConf := ConfRead(defaultConfFile)
		if baseConf.Has("sunshine_name") 
			baseConf.Delete("sunshine_name") 
		if baseConf.Has("port")
			baseConf.Delete("port")
	}
	; assign and create conf files if not created
	for instance in savedSettings["Fleet"]["Instances"] {
		if (instance.Enabled = 1) {
			if !(savedSettings["Fleet"]["SyncSettings"]) && FileExist(instance.configFile)
				thisConf:= ConfRead(instance.configFile)	; this will keep config file to retain user modified settings
			else
				thisConf := DeepClone(baseConf)
			thisConf.set("sunshine_name", instance.Name, "port", instance.Port)
			if !FileExist(instance.configFile) || !(FileGetTime(instance.configFile, "M" ) = instance.LastConfigUpdate)
				ConfWrite(instance.configFile, thisConf)
			instance.LastConfigUpdate := FileGetTime(instance.configFile, "M" ) ; TODO implement this: only update if there's need/change
		}
	} 
	
	if savedSettings["Fleet"]["AutoLaunch"]
		SetTimer LogWatchDog, -1

	if savedSettings["Fleet"]["SyncVolume"] || savedSettings["Fleet"]["RemoveDisconnected"]
		SetTimer LogWatchDog, 100000

	if savedSettings["Android"]["MicEnable"] || savedSettings["Android"]["CamEnable"]
		SetTimer ADBWatchDog, 100000

	if savedSettings["Fleet"]["SyncVolume"]
		SetTimer FleetSyncVolume, 10000

	if savedSettings["Fleet"]["SyncSettings"]
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
	global savedSettings := Map(), sessionSettings := Map()

	LoadSettingsFile(, sessionSettings)
	SaveStagedSettings()
	;MsgBox(sessionSettings["Fleet"]["Instances"][1].Name)
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
SendSigInt(pid) {
    ; 1. Tell this script to ignore Ctrl+C and Ctrl+Break
    DllCall("SetConsoleCtrlHandler", "Ptr", 0, "UInt", 1)

    ; 2. Detach from current console, attach to target's
    DllCall("FreeConsole")
    if !DllCall("AttachConsole", "UInt", pid) {
        MsgBox "Failed to attach to target console"
        return false
    }
    ; 3. Send Ctrl+C (SIGINT) to all processes in that console (including the target)
    if !DllCall("GenerateConsoleCtrlEvent", "UInt", 0, "UInt", 0) {
        MsgBox "Failed to send SIGINT"
        DllCall("FreeConsole")
        return false
    }
    Sleep 200  ; Give the target process time to exit gracefully
    ; 4. Detach again
    DllCall("FreeConsole")
    return true
}
FleetLaunchInstances(){
	global savedSettings

	; get currently running PIDs 
	; terminate anything unknown to us
	; if any PID is known try to test it and reuse it if it is still working "TODO maybe add option to start clean"
	; TODO its time to make settings load/save work for single setting group
	; start instances and register write PIDs in settings file 

	; for now, lets just kill any exisiting proccess 

	currentPIDs := PIDsListFromExeName("sunshine.exe")
	if (currentPIDs.Length > 0)
		for pid in currentPIDs
			SendSigInt(pid)
	
}

bootstrapSettings()
bootstrapGUI()

if savedSettings["Fleet"]["AutoLaunch"] {
	; TODO Disable default service and create/enable ours 
	FleetConfigInit()
	FleetLaunchInstances()	; check previous ones > if they're valid keep them 
	;timer 1000 FleetCheckInstances() ; this is a combination of instance check/ logmonitor for connected/disconnected events/ 
	; if enabled, start timer 50 SyncVolume to try sync volume as soon as client connects, probably can verify it too "make it smart not dumb"
	; if enabled, start timer 50 ForceClose to try send SIGINT to instance once client disconnected > the rest should be cought by FleetCheckInstances to relaunch it again "if it didn't relaunch by itself" 
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
; ───── Keep script alive ─────
While true
    Sleep(100)

	; TODO Validate settings and reset invalid ones, clear invalid instances
	; TODO Keep the last remembered PIDs if they are still running
	; test them "maybe wget or sorta" 
	; kill the rest 

	; if AutoLaunch is set, check for schduleded task, add it if missing, enable it if disabled
	; else disable it ;;; EDIT: AutoLaunch will be used to determine if we launch these instances or not at all
	;							TODO Introduce Auto run at startup setting to specifically do that 

