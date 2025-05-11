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
            p.ADBTools := IniRead(File, "Paths", "ADB", base "\platform-tools")

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
			i.Enabled := Settings["Manager"].SyncSettings ? 1 : 0
			i.configFile := defConfigPath "\sunshine.conf"
			i.logFile := defConfigPath "\sunshine.log"
			i.stateFile := defConfigPath "\sunshine.json"
			i.consolePID := IniRead(File, "Instance0", "consolePID", 0)
			i.apolloPID := IniRead(File, "Instance0", "apolloPID", 0)
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
					i.id := IsNumber(SubStr(section, 9)) ? SubStr(section, -1) : index
					i.Name := IniRead(File, section, "Name", "i" . index)
					i.Port := IniRead(File, section, "Port", 10000 + index * 1000)
					i.Enabled := IniRead(File, section, "Enabled", 1)
					i.configFile := configp "\fleet-" i.id (synced ? "-synced.conf" : ".conf")
					i.logFile := configp "\fleet-" i.id (synced ? "-synced.log" : ".log")
					i.stateFile := synced ? f[1].stateFile : configp "\fleet-" i.id ".json"
					i.consolePID := IniRead(File, section, "consolePID", 0)
					i.apolloPID := IniRead(File, section, "apolloPID", 0)
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
				IniWrite(i.consolePID, File, section, "consolePID")
				IniWrite(i.apolloPID, File, section, "apolloPID")
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
	guiItems["AndroidMicSelector"] := myGui.Add("ComboBox", "x382 y136 w122", [1,2,3])
	guiItems["AndroidCamCheckbox"] := myGui.Add("CheckBox", "x334 y164 ", "Cam:")
	guiItems["AndroidCamSelector"] := myGui.Add("ComboBox", "x382 y160 w122", [3,2,1])
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
	myLink := "https://localhost:" . savedSettings["Fleet"][(savedSettings["Manager"].SyncSettings = 1 ? 1 : currentlySelectedIndex)].Port+1
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
	global myGui, guiItems
	a := Settings["Android"]
	m := Settings["Manager"]
	guiItems["FleetAutoLaunchCheckBox"].Value := m.AutoLaunch
	guiItems["FleetSyncVolCheckBox"].Value := m.SyncVolume
	guiItems["FleetRemoveDisconnectCheckbox"].Value := m.RemoveDisconnected
	guiItems["FleetSyncCheckbox"].Value := m.SyncSettings
	guiItems["AndroidReverseTetheringCheckbox"].Value := a.ReverseTethering
	guiItems["AndroidMicCheckbox"].Value := a.MicEnable
	guiItems["AndroidMicSelector"].Value := a.MicDeviceID
	guiItems["AndroidCamCheckbox"].Value := a.CamEnable
	guiItems["AndroidCamSelector"].Value := a.CamDeviceID
	guiItems["PathsApolloBox"].Value := Settings["Paths"].Apollo
	guiItems["ButtonLogsShow"].Text := (Settings["Window"].logShow = 1 ? "Hide Logs" : "Show Logs")
	;guiItems["FleetAudioSelector"].Enabled :=0
	guiItems["FleetListBox"].Delete()
	guiItems["FleetListBox"].Add(AllFleetArray(Settings))
}
AllFleetArray(Settings){
	isList := []  ; Create an empty array
	for i in Settings["Fleet"] 
		isList.Push(i.Name)  ; Add the Name property to the array
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
	userSettings["Android"].ReverseTethering := guiItems["AndroidReverseTetheringCheckbox"].Value
	userSettings["Manager"].AutoLaunch := guiItems["FleetAutoLaunchCheckBox"].Value
	launchChildren := ["FleetSyncVolCheckBox", "FleetRemoveDisconnectCheckbox"]
	launchChildrenLock := userSettings["Manager"].AutoLaunch = 0
	for item in launchChildren
		guiItems[item].Enabled := launchChildrenLock ? 0 : 1
	userSettings["Manager"].SyncVolume := guiItems["FleetSyncVolCheckBox"].Value
	userSettings["Manager"].RemoveDisconnected := guiItems["FleetRemoveDisconnectCheckbox"].Value
	UpdateButtonsLables()
	WriteSettingsFile(userSettings)

}

HandleFleetSyncCheck(*){
	global userSettings, guiItems
	userSettings["Manager"].SyncSettings := guiItems["FleetSyncCheckbox"].Value
	userSettings["Fleet"][1].Enabled := userSettings["Manager"].SyncSettings
	; change conf file name so its recognized as synced, also, to trigger delete for non-synced config "and vice versa" on next reload 
	for i in userSettings["Fleet"]
		i.configFile := userSettings["Paths"].Config . '\fleet-' . i.id . (userSettings["Manager"].SyncSettings = 1 ?  '-synced.conf' : '.conf')
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
		myLink := "https://localhost:" . userSettings["Fleet"][(userSettings["Manager"].SyncSettings = 1 ? 1 : currentlySelectedIndex)].Port+1
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
	i.configFile := userSettings["Paths"].Config . '\fleet-' . i.id . '.conf'
	i.logFile := userSettings["Paths"].Config . '\fleet-' . i.id . '.log'
	i.stateFile := userSettings["Paths"].Config . '\fleet-' . i.id . '.json'
	userSettings["Fleet"].Push(i) ; Add the i object to the userSettings["Fleet"] array
	RefreshFleetList()
	guiItems["FleetListBox"].Choose(i.id + 1)
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
	myLink := "https://localhost:" . userSettings["Fleet"][(userSettings["Manager"].SyncSettings = 1 ? 1 : currentlySelectedIndex)].Port+1
	guiItems["FleetLinkBox"].Text :=  '<a href="' . myLink . '">' . myLink . '</a>'
	UpdateButtonsLables()
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
	global settingsLocked, userSettings, savedSettings
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
	launchChildrenLock := userSettings["Manager"].AutoLaunch = 0
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
SaveUserSettings(){
	global userSettings, savedSettings
	savedSettings := DeepClone(userSettings)
}
global settingsLocked := 1
HandleSettingsLock(*) {
    global guiItems, settingsLocked, savedSettings, userSettings
	UpdateButtonsLables()
	if !UserSettingsWaiting() {
		settingsLocked := !settingsLocked
	} else {
		; hence we need to save settings "clone staged into active and save them"
		SaveUserSettings()
		HandleSettingsLock()
	}
	ApplyLockState()
	UpdateButtonsLables()
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
		savedSettings["Window"].cmdReload = 0
		 ;TODO revise this 
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


FleetConfigInit(*){
	global savedSettings
	
	; clean and prepare conf directory
	if !DirExist(savedSettings["Paths"].Config)	
		DirCreate(savedSettings["Paths"].Config)
	configDir := savedSettings["Paths"].Config
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
	if (savedSettings["Manager"].SyncSettings) {
		defaultConfFile := savedSettings["Paths"].Apollo . "\config\sunshine.conf"
		baseConf := ConfRead(defaultConfFile)
		if baseConf.Has("sunshine_name") 
			baseConf.Delete("sunshine_name") 
		if baseConf.Has("port")
			baseConf.Delete("port")
	}
	; assign and create conf files if not created
	for i in savedSettings["Fleet"] {
		if (i.Enabled = 1) {
			if !(savedSettings["Manager"].SyncSettings) && FileExist(i.configFile)
				thisConf:= ConfRead(i.configFile)	; this will keep config file to retain user modified settings
			else
				thisConf := DeepClone(baseConf)
			thisConf.set("sunshine_name", i.Name, "port", i.Port)
			if !FileExist(i.configFile) || !(FileGetTime(i.configFile, "M" ) = i.LastConfigUpdate)
				ConfWrite(i.configFile, thisConf)
			i.LastConfigUpdate := FileGetTime(i.configFile, "M" ) ; TODO implement this: only update if there's need/change
		}
	}
	
	if savedSettings["Manager"].AutoLaunch
		SetTimer LogWatchDog, -1

	if savedSettings["Manager"].SyncVolume || savedSettings["Manager"].RemoveDisconnected
		SetTimer LogWatchDog, 100000

	if savedSettings["Android"].MicEnable || savedSettings["Android"].CamEnable
		SetTimer ADBWatchDog, 100000

	if savedSettings["Manager"].SyncVolume
		SetTimer FleetSyncVolume, 10000

	if savedSettings["Manager"].SyncSettings
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
    )
	sleep 1 ; TODO issue here is we get the console PID, not the PID for the processes itself
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

JoinArray(arr, delimiter := ", ") {
    result := ""
    for i, val in arr {
        result .= val . (i < arr.Length ? delimiter : "")
    }
    return result
}

ArrayHas(arr, val) {
    for _, v in arr
        if (v = val)
            return true
    return false
}

FleetLaunchFleet(){
	global savedSettings

	; get currently running PIDs terminate anything unknown to us
	currentPIDs := PIDsListFromExeName("sunshine.exe")
	knownPIDs := []
	for i in savedSettings["Fleet"]
		if i.Enabled
			knownPIDs.Push(i.apolloPID)	
	for pid in currentPIDs
		if !ArrayHas(knownPIDs, pid)
			SendSigInt(pid, true)
	Sleep(1000) ; keep it here for now,  
	exe := savedSettings["Paths"].apolloExe
	newPID := 0
	for i in savedSettings["Fleet"]
		if (i.Enabled && !ProcessExist(i.apolloPID)){	; TODO add test for the instance if it responds or not, also, may check if display is connected deattach it/force exit? 
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
bootstrapSettings()

if savedSettings["Manager"].AutoLaunch {
	; TODO Disable default service and create/enable ours 
	FleetConfigInit()
	FleetLaunchFleet()
	;timer 1000 FleetCheckFleet() ; this is a combination of i check/ logmonitor for connected/disconnected events/ 
	; if enabled, start timer 50 SyncVolume to try sync volume as soon as client connects, probably can verify it too "make it smart not dumb"
	; if enabled, start timer 50 ForceClose to try send SIGINT to i once client disconnected > the rest should be cought by FleetCheckFleet to relaunch it again "if it didn't relaunch by itself" 
} 
if savedSettings["Android"].ReverseTethering{
	; AndroidStartGnirehtet() ; check existing > test it > if invalid start new one, until this is a reload; kill it!
	; timer 1000 AndroidCheckGnirehtet() Possibily we can do it smart way to check if its still alive/there's connections
}
if savedSettings["Android"].MicEnable || savedSettings["Android"].CamEnable {
	; here we sadly need to kill every existing adb.exe process, possibly via kill-server adb command
	; timer 1000 AndroidDevicesList() ; to keep track of currently connected, and disconnected devices with their IDs and time of connection/disconnection and previous time too "maybe we can do something smarter here too"
	if savedSettings["Android"].MicEnable{
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

