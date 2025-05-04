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

LoadSettingsFile(settingsFile, Settings) {
    Settings["FleetManager"] := {}, Settings["Window"] := {}
	Settings["Paths"] := {}, Settings["Fleet"] := {}, Settings["Android"] := {}
	Settings["Fleet"].Instances := []

	;Settings["FleetManager"].SchduledService	; TODO
	;Settings["FleetManager"].StartMinimized	; TODO
	if !FileExist(settingsFile)
        FileAppend "", settingsFile

	Settings["Window"].restorePosition := IniRead(settingsFile, "Window", "Remember location", 1)
    Settings["Window"].xPos := IniRead(settingsFile, "Window", "xPos", (A_ScreenWidth - 580) / 2)
    Settings["Window"].yPos := IniRead(settingsFile, "Window", "yPos", (A_ScreenHeight - 198) / 2)
    Settings["Window"].lastState := IniRead(settingsFile, "Window", "lastState", 1)
	Settings["Window"].logShow := IniRead(settingsFile, "Window", "Show Logs", 1)


	DefaultApolloPath := "C:\Program Files\Apollo"
	DefaultConfigPath := A_ScriptDir . "\config"
	DefaultADBPath := A_ScriptDir . "\platform-tools"
	Settings["Paths"].Apollo  := IniRead(settingsFile, "Paths", "Apollo", DefaultApolloPath)
	Settings["Paths"].Config  := IniRead(settingsFile, "Paths", "Config", DefaultConfigPath)
	Settings["Paths"].ADBTools  := IniRead(settingsFile, "Paths", "ADB", DefaultADBPath)
	

	Settings["Fleet"].AutoLaunch := IniRead(settingsFile, "Fleet Options", "Auto Launch", 1)
	Settings["Fleet"].SyncVolume := IniRead(settingsFile, "Fleet Options", "Sync Volume Levels", 1)
	Settings["Fleet"].RemoveDisconnected := IniRead(settingsFile, "Fleet Options", "Remove Disconnected", 1)
	Settings["Fleet"].SyncSettings := IniRead(settingsFile, "Fleet Options", "Sync Settings", 1)

	Settings["Android"].ReverseTethering  := IniRead(settingsFile, "Android Clients", "Reverse Tethering", 1)
	Settings["Android"].gnirehtetPID := IniRead(settingsFile, "Android Clients", "Last gnirehtetPID", "")  
	Settings["Android"].MicEnable  := IniRead(settingsFile, "Android Clients", "Mic Enable", 0)
	Settings["Android"].MicDeviceID  := IniRead(settingsFile, "Android Clients", "Mic Device Serial", "")
	Settings["Android"].scrcpyMicPID := IniRead(settingsFile, "Android Clients", "Last scrcpyMicPID", "")  
	Settings["Android"].CamEnable  := IniRead(settingsFile, "Android Clients", "Cam Enable", 0)
	Settings["Android"].CamDeviceID  := IniRead(settingsFile, "Android Clients", "Cam Device Serial", "")
	Settings["Android"].scrcpyCamPID := IniRead(settingsFile, "Android Clients", "Last scrcpyCamPID", "")  


	defaultConfFile := Settings["Paths"].Apollo . "\config\sunshine.conf"
	instance := {} ; Create a new object for each instance
	instance.index := 0
	instance.id := 0
	instance.Name := ConfRead(defaultConfFile, "sunshine_name", "default instance")
	instance.Port := ConfRead(defaultConfFile, "port", "47989")
	instance.Enabled := 0
	instance.LastKnownPID := 0
	instance.LastConfigUpdate := 0
	instance.LastReadLogLine := 0
	instance.configFile := Settings["Paths"].Apollo . '\config\sunshine.conf'
	instance.logFile := Settings["Paths"].Apollo . '\config\sunshine.log'
	instance.stateFile := Settings["Paths"].Apollo . '\config\sunshine.json'

	; instance.Audio := IniRead(settingsFile, section, "Port", "") TODO
	Settings["Fleet"].Instances.Push(instance) ; Add the instance object to the Settings["Fleet"].Instances array


    ; Iterate through all sections, focusing on "instance"
	index := 1
    ; Iterate through all sections, focusing on "instance"
    sectionsNames := StrSplit(IniRead(settingsFile), "`n")
    for section in sectionsNames {
        if (SubStr(section, 1, 8) = "Instance") { ; section name starts with Instance
            instance := {} ; Create a new object for each instance
			instance.index := index
            instance.id := IsNumber(SubStr(section, 9 )) ? SubStr(section, 9 ) : index
            instance.Name := IniRead(settingsFile, section, "Name", "instance" . index)
            instance.Port := IniRead(settingsFile, section, "Port", 10000 + index * 1000)
			instance.Enabled := IniRead(settingsFile, section, "Enabled", 1)
			instance.LastKnownPID := IniRead(settingsFile, section, "LastKnownPID", 0)
			instance.LastConfigUpdate := IniRead(settingsFile, section, "LastConfigUpdate", 0)
			instance.LastReadLogLine := IniRead(settingsFile, section, "LastReadLogLine", 0)

			instance.configFile := Settings["Paths"].Config . '\fleet-' . instance.id . '.conf'
			instance.logFile := Settings["Paths"].Config . '\fleet-' . instance.id . '.log'
			instance.stateFile := Settings["Paths"].Config . '\fleet-' . instance.id . '.json'
            ; instance.Audio := IniRead(settingsFile, section, "Port", "") TODO
            Settings["Fleet"].Instances.Push(instance) ; Add the instance object to the Settings["Fleet"].Instances array
			index := index + 1
        }
    }
}
SaveSettingsFile(settingsFile, Settings) {
    if FileExist(settingsFile)
        FileDelete(settingsFile)
	FileAppend "", settingsFile
	
	UpdateWindowPosition()
    ; Window State
    IniWrite(Settings["Window"].restorePosition, settingsFile, "Window", "Remember location")
	IniWrite(Settings["Window"].xPos, settingsFile, "Window", "xPos")
    IniWrite(Settings["Window"].yPos, settingsFile, "Window", "yPos")
    IniWrite(Settings["Window"].lastState, settingsFile, "Window", "lastState")
	IniWrite(Settings["Window"].logShow, settingsFile, "Window", "Show Logs")

    ; Paths
    IniWrite(Settings["Paths"].Apollo, settingsFile, "Paths", "Apollo")
    IniWrite(Settings["Paths"].Config, settingsFile, "Paths", "Config")
    IniWrite(Settings["Paths"].ADBTools, settingsFile, "Paths", "ADB")

    ; Fleet Options
    IniWrite(Settings["Fleet"].AutoLaunch, settingsFile, "Fleet Options", "Auto Launch")
    IniWrite(Settings["Fleet"].SyncVolume, settingsFile, "Fleet Options", "Sync Volume Levels")
    IniWrite(Settings["Fleet"].RemoveDisconnected, settingsFile, "Fleet Options", "Remove Disconnected")
    IniWrite(Settings["Fleet"].SyncSettings, settingsFile, "Fleet Options", "Sync Settings")

    ; Android Clients
    IniWrite(Settings["Android"].ReverseTethering, settingsFile, "Android Clients", "Reverse Tethering")
	IniWrite(Settings["Android"].gnirehtetPID, settingsFile, "Android Clients", "Last gnirehtetPID")
    IniWrite(Settings["Android"].MicEnable, settingsFile, "Android Clients", "Mic Enable")
	IniWrite(Settings["Android"].MicDeviceID, settingsFile, "Android Clients", "Mic Device Serial")
	IniWrite(Settings["Android"].scrcpyMicPID, settingsFile, "Android Clients", "Last scrcpyMicPID")

	IniWrite(Settings["Android"].CamEnable, settingsFile, "Android Clients", "Cam Enable")
    IniWrite(Settings["Android"].CamDeviceID, settingsFile, "Android Clients", "Cam Device Serial")
	IniWrite(Settings["Android"].scrcpyCamPID, settingsFile, "Android Clients", "Last scrcpyCamPID")


    ; Instances
    for instance in Settings["Fleet"].Instances {
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
	for instance in stagedSettings["Fleet"].Instances 
		instancesList.Push(instance.Name)  ; Add the Name property to the array
	return instancesList
}
InitmyGui() {
	global myGui, guiItems := Map()
	TraySetIcon("shell32.dll", "19")
	myGui := Gui("+AlwaysOnTop -MinimizeBox -MaximizeBox")
	guiItems["ButtonLockSettings"] := myGui.Add("Button", "x520 y5 w50 h40", "🔒")
	guiItems["ButtonReload"] := myGui.Add("Button", "x520 y50 w50 h40", "Reload")
	guiItems["ButtonLogsShow"] := myGui.Add("Button", "x520 y101 w50 h40", "Show Logs")
	guiItems["ButtonMinimize"] := myGui.Add("Button", "x520 y150 w50 h40", "Minimize")
	myGui.Add("GroupBox", "x318 y0 w196 h90", "Fleet Options")
	guiItems["FleetAutoLaunchCheckBox"] := myGui.Add("CheckBox", "x334 y16 w162 h23", "Auto Launch Multi Instance")
	guiItems["FleetSyncVolCheckBox"] := myGui.Add("CheckBox", "x334 y40 w162 h23", "Sync Volume Levels")
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
	guiItems["InstancesNameBox"].Value := Settings["Fleet"].Instances[currentlySelectedIndex].Name
	myGui.Add("Text", "x126 y98", "Port:")
	guiItems["InstancesPortBox"] := myGui.Add("Edit", "x166 y92 w130 h23 +ReadOnly", "")
	guiItems["InstancesPortBox"].Value := Settings["Fleet"].Instances[currentlySelectedIndex].Port
	;myGui.Add("Text", "x126 y120 w54 h23", "Audio:")
	;guiItems["InstancesAudioSelector"] := myGui.Add("ComboBox", "x166 y120 w130", [])
	myGui.Add("Text", "x126 y126 ", "Link:")
	myLink := "https://localhost:" . Settings["Fleet"].Instances[(Settings["Fleet"].SyncSettings = 1 ? 1 : currentlySelectedIndex)].Port+1
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
	A_TrayMenu.Add("Show Manager", (*) => ShowmyGui())
	A_TrayMenu.Add("Reload", (*) => MinimizemyGui())
	A_TrayMenu.Add()
	A_TrayMenu.Add("Exit", (*) => ExitMyApp())
}
ReflectSettings(Settings){
	global myGui, guiItems, currentlySelectedIndex
	guiItems["FleetAutoLaunchCheckBox"].Value := Settings["Fleet"].AutoLaunch
	guiItems["FleetSyncVolCheckBox"].Value := Settings["Fleet"].SyncVolume
	guiItems["FleetRemoveDisconnectCheckbox"].Value := Settings["Fleet"].RemoveDisconnected
	guiItems["FleetSyncCheckbox"].Value := Settings["Fleet"].SyncSettings
	guiItems["AndroidReverseTetheringCheckbox"].Value := Settings["Android"].ReverseTethering
	guiItems["AndroidMicCheckbox"].Value := Settings["Android"].MicEnable
	guiItems["AndroidMicSelector"].Value := Settings["Android"].MicDeviceID
	guiItems["AndroidCamCheckbox"].Value := Settings["Android"].CamEnable
	guiItems["AndroidCamSelector"].Value := Settings["Android"].CamDeviceID
	guiItems["PathsApolloBox"].Value := Settings["Paths"].Apollo
	guiItems["ButtonLogsShow"].Text := (Settings["Window"].logShow = 1 ? "Hide Logs" : "Show Logs")
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

	guiItems["AndroidReverseTetheringCheckbox"].OnEvent("Click", HandleCheckBoxes) ; (*) => stagedSettings["Android"].ReverseTethering := guiItems["AndroidReverseTetheringCheckbox"].Value)
	guiItems["AndroidMicCheckbox"].OnEvent("Click", HandleAndroidSelector) ; (*)=> guiItems["AndroidMicSelector"].Enabled := guiItems["AndroidMicCheckbox"].Value)
	guiItems["AndroidCamCheckbox"].OnEvent("Click", HandleAndroidSelector) ; (*)=> guiItems["AndroidCamSelector"].Enabled := guiItems["AndroidMicCheckbox"].Value)

	guiItems["FleetAutoLaunchCheckBox"].OnEvent("Click", HandleCheckBoxes) ; (*) => stagedSettings["Fleet"].AutoLaunch := guiItems["FleetAutoLaunchCheckBox"].Value)
	guiItems["FleetSyncVolCheckBox"].OnEvent("Click", HandleCheckBoxes) ;(*) => stagedSettings["Fleet"].SyncVolume := guiItems["FleetSyncVolCheckBox"].Value)
	guiItems["FleetRemoveDisconnectCheckbox"].OnEvent("Click", HandleCheckBoxes) ;(*) => stagedSettings["Fleet"].RemoveDisconnected := guiItems["FleetRemoveDisconnectCheckbox"].Value)
	guiItems["FleetSyncCheckbox"].OnEvent("Click", HandleFleetSyncCheck)

	guiItems["InstancesButtonAdd"].OnEvent("Click", HandleInstanceAddButton)
	guiItems["InstancesButtonDelete"].OnEvent("Click", HandleInstanceDeleteButton)

	guiItems["InstancesNameBox"].OnEvent("Change", HandleNameChange)
	guiItems["InstancesPortBox"].OnEvent("LoseFocus", HandlePortChange)
	
}
HandleCheckBoxes(*) {
	global stagedSettings
	stagedSettings["Android"].ReverseTethering := guiItems["AndroidReverseTetheringCheckbox"].Value
	stagedSettings["Fleet"].AutoLaunch := guiItems["FleetAutoLaunchCheckBox"].Value
	stagedSettings["Fleet"].SyncVolume := guiItems["FleetSyncVolCheckBox"].Value
	stagedSettings["Fleet"].RemoveDisconnected := guiItems["FleetRemoveDisconnectCheckbox"].Value
	UpdateButtonsLables()
}

HandleFleetSyncCheck(*){
	global stagedSettings, guiItems
	stagedSettings["Fleet"].SyncSettings := guiItems["FleetSyncCheckbox"].Value
	; change conf file name so its recognized as synced, also, to trigger delete for non-synced config "and vice versa" on next reload 
	for instance in stagedSettings["Fleet"].Instances
		instance.configFile := stagedSettings["Paths"].Config . '\fleet-' . instance.id . stagedSettings["Fleet"].SyncSettings ?  '-synced' : '' . '.conf'
	HandleListChange()
}
RefreshInstancesList(){
	global guiItems, stagedSettings
	guiItems["InstancesListBox"].Delete()
	guiItems["InstancesListBox"].Add(AllInstancesArray(stagedSettings))
	UpdateButtonsLables()
}
HandlePortChange(*){
	global stagedSettings, guiItems
	selectedEntryIndex := guiItems["InstancesListBox"].Value
	newPort := guiItems["InstancesPortBox"].Value = "" ? stagedSettings["Fleet"].Instances[selectedEntryIndex].Port : guiItems["InstancesPortBox"].Value 
	valid := (1024 < newPort && newPort < 65000) ? true : false
	for instance in stagedSettings["Fleet"].Instances
		if (instance.Port = newPort)
			valid := false
	if valid {
		stagedSettings["Fleet"].Instances[selectedEntryIndex].Port := newPort
		myLink := "https://localhost:" . stagedSettings["Fleet"].Instances[(stagedSettings["Fleet"].SyncSettings = 1 ? 1 : currentlySelectedIndex)].Port+1
		guiItems["InstancesLinkBox"].Text :=  '<a href="' . myLink . '">' . myLink . '</a>'	
	} else {
		guiItems["InstancesPortBox"].Value := stagedSettings["Fleet"].Instances[currentlySelectedIndex].Port
	}
	UpdateButtonsLables()
}
HandleNameChange(*){
	global stagedSettings, guiItems
	newName := guiItems["InstancesNameBox"].Value
	selectedEntryIndex := guiItems["InstancesListBox"].Value
	stagedSettings["Fleet"].Instances[selectedEntryIndex].Name := newName
	RefreshInstancesList()
	guiItems["InstancesListBox"].Choose(selectedEntryIndex)
}
HandleInstanceAddButton(*){
	global stagedSettings, guiItems
	
	instance := {} ; Create a new object for each instance
	instance.index := stagedSettings["Fleet"].Instances[-1].index + 1
	if (instance.index > 5){
		MsgBox("Let's not add more than 5 instances for now.")
	} else {
	instance.id := instance.index
	instance.Port := instance.id = 1 ? 10000 : stagedSettings["Fleet"].Instances[-1].port + 1000
	instance.Name := "Instance " . instance.Port
	instance.Enabled := 1
	instance.LastKnownPID := 0
	instance.LastConfigUpdate := 0
	instance.LastReadLogLine := 0
	instance.configFile := stagedSettings["Paths"].Config . '\fleet-' . instance.id . '.conf'
	instance.logFile := stagedSettings["Paths"].Config . '\fleet-' . instance.id . '.log'
	instance.stateFile := stagedSettings["Paths"].Config . '\fleet-' . instance.id . '.json'
	stagedSettings["Fleet"].Instances.Push(instance) ; Add the instance object to the stagedSettings["Fleet"].Instances array
	RefreshInstancesList()
	guiItems["InstancesListBox"].Choose(instance.index+1)
	HandleListChange()
	}
	Sleep (200)
}
HandleInstanceDeleteButton(*){
	global stagedSettings, guiItems
	selectedEntryIndex := guiItems["InstancesListBox"].Value
	if (selectedEntryIndex != 1){
		stagedSettings["Fleet"].Instances.RemoveAt(selectedEntryIndex) ; MUST USE REMOVEAT INSTEAD OF DELETE TO REMOVE THE ITEM COMPLETELY NOT JUST ITS VALUE
		guiItems["InstancesListBox"].Delete(selectedEntryIndex)
		guiItems["InstancesListBox"].Choose(selectedEntryIndex - 1 )
		HandleListChange()
		Loop stagedSettings["Fleet"].Instances.Length { 	; Update instances index
			stagedSettings["Fleet"].Instances[A_Index].index := A_Index - 1
			stagedSettings["Fleet"].Instances[A_Index].id := A_Index - 1
			; TODO: the id is enough, remove index later
		}
	}
	else
		MsgBox("Can't delete the default entry")
	Sleep (200)
}
HandleAndroidSelector(*) {
	global stagedSettings
	Selectors := ["AndroidMicSelector", "AndroidCamSelector"]
	Controls := ["AndroidMicCheckbox", "AndroidCamCheckbox"]
	enableSettings := ["MicEnable", "CamEnable"]
	idSettings := ["MicDeviceID", "CamDeviceID"]
	Loop Selectors.Length {
		guiItems[Selectors[A_index]].Enabled := settingsLocked ? 0 : guiItems[Controls[A_index]].Value

		stagedSettings["Android"].%enableSettings[A_index]% := guiItems[Controls[A_index]].Value
        stagedSettings["Android"].%idSettings[A_index]% := guiItems[Selectors[A_index]].Value
	}
	UpdateButtonsLables()
}

global currentlySelectedIndex := 1
HandleListChange(*) {
	global guiItems, stagedSettings, currentlySelectedIndex
	currentlySelectedIndex := guiItems["InstancesListBox"].Value = 0 ? 1 : guiItems["InstancesListBox"].Value
	guiItems["InstancesNameBox"].Value := stagedSettings["Fleet"].Instances[currentlySelectedIndex].Name
	guiItems["InstancesPortBox"].Value := stagedSettings["Fleet"].Instances[currentlySelectedIndex].Port
	guiItems["InstancesNameBox"].Opt(((settingsLocked || currentlySelectedIndex = 1) ? "+ReadOnly" : "-ReadOnly"))
	guiItems["InstancesPortBox"].Opt(((settingsLocked || currentlySelectedIndex = 1) ? "+ReadOnly" : "-ReadOnly"))
	myLink := "https://localhost:" . stagedSettings["Fleet"].Instances[(stagedSettings["Fleet"].SyncSettings = 1 ? 1 : currentlySelectedIndex)].Port+1
	guiItems["InstancesLinkBox"].Text :=  '<a href="' . myLink . '">' . myLink . '</a>'
	UpdateButtonsLables()
}
UpdateWindowPosition(){
	global Settings, myGui
	if (Settings["Window"].restorePosition && DllCall("IsWindowVisible", "ptr", myGui.Hwnd) ){
		WinGetPos(&x, &y, , , "ahk_id " myGui.Hwnd)
		; Save position
		Settings["Window"].xPos := x
		Settings["Window"].yPos := y
	}
}
HandleLogsButton(*) {
	global guiItems, Settings
	Settings["Window"].logShow := !Settings["Window"].logShow
	guiItems["ButtonLogsShow"].Text := (Settings["Window"].logShow = 1 ? "Hide Logs" : "Show Logs")
	UpdateWindowPosition()
	RestoremyGui()
	Sleep (200)
}
HandleReloadButton(*) {
	global settingsLocked, stagedSettings, Settings
	;if settingsLocked && stagedSettingsWaiting() {
	;	if (stagedSettings["Fleet"].SyncSettings != Settings["Fleet"].SyncSettings) {
	;		for instance in stagedSettings["Fleet"].Instances
	;			if instance.Enabled = 1 && FileExist(instance.configFile)
	;				FileDelete(instance.configFile)
	;	}
	;	Reload
	;} TODO : MAYBE Add a 3rd state in between Locked/Reload > Unlocked/Cancel > *Save/Cancel* > Apply/Discard > Lock / Reload ? 
	if settingsLocked {
		SaveSettingsFile(settingsFile, Settings)
		Reload
	}
	else {
		ReflectSettings(Settings)
		HandleSettingsLock()
		LoadSettingsFile(settingsFile, stagedSettings)
	}
	Sleep (200)
}
stagedSettingsWaiting(){
	global Settings, stagedSettings
	for group in Settings {
		if !(group = "Window") {
			for setting in Settings[group].OwnProps() {
				if type(Settings[group].%setting%) = "String" && Settings[group].%setting% != stagedSettings[group].%setting%
					return true
				else if type(Settings[group].%setting%) = "Array" && Settings[group].%setting%.Length != stagedSettings[group].%setting%.Length
					return true
				else if type(Settings[group].%setting%) = "Array" {
					inst := 1
					Loop Settings[group].%setting%.Length {
						if (inst > 0)
							for inSetting in Settings[group].%setting%[inst].OwnProps(){
								if !(Settings[group].%setting%[inst].%inSetting% = stagedSettings[group].%setting%[inst].%inSetting%)
									return true
							}
						inst := inst + 1
					}
				}
			}
		}
	}
	return false
}
UpdateButtonsLables(){
	global guiItems, settingsLocked
	guiItems["ButtonLockSettings"].Text := stagedSettingsWaiting() ? "Save" : settingsLocked ? "🔒" : "🔓" 
	guiItems["ButtonReload"].Text := settingsLocked ?  "Reload" : "Cancel"
}
ApplyLockState(){
	global settingsLocked, guiItems
	textBoxes := [ "PathsApolloBox"]
	checkBoxes := ["FleetAutoLaunchCheckBox", "FleetSyncVolCheckBox", "FleetRemoveDisconnectCheckbox", "AndroidReverseTetheringCheckbox", "AndroidMicCheckbox", "AndroidCamCheckbox", "FleetSyncCheckbox"]
	Buttons := ["InstancesButtonDelete", "InstancesButtonAdd", "PathsApolloBrowseButton"]
	Selectors := ["AndroidMicSelector", "AndroidCamSelector"]
	Controls := ["AndroidMicCheckbox", "AndroidCamCheckbox"]
	instanceBoxes := ["InstancesNameBox", "InstancesPortBox"]
	for checkBox in checkBoxes
		guiItems[checkBox].Enabled := (settingsLocked ? false : true)
	for button in Buttons
		guiItems[button].Enabled := (settingsLocked ? false : true)
	for textBox in textBoxes
		guiItems[textbox].Opt(settingsLocked ? "+ReadOnly" : "-ReadOnly")
	for textBox in instanceBoxes
		guiItems[textBox].Opt(((settingsLocked || currentlySelectedIndex = 1) ? "+ReadOnly" : "-ReadOnly"))
	for i, selector in Selectors
		guiItems[selector].Enabled := settingsLocked ? 0 : guiItems[Controls[i]].Value
}
global settingsLocked := true

HandleSettingsLock(*) {
    global guiItems, settingsLocked, Settings, stagedSettings, settingsFile
	UpdateButtonsLables()
	if !stagedSettingsWaiting() {
		settingsLocked := !settingsLocked
	} else if stagedSettingsWaiting(){
		; hence we need to save settings
		SaveSettingsFile(settingsFile, stagedSettings)
		Settings := stagedSettings.Clone()
		Sleep (100)
		HandleSettingsLock()
		return
		; Maybe add settings.bak to restore in case new settings didn't work or so
	}
	ApplyLockState()
	UpdateButtonsLables()
	Sleep (200)
}
ExitMyApp() {
	global myGui, Settings
	UpdateWindowPosition()
	Sleep (200)
	SaveSettingsFile(settingsFile, Settings)
	myGui.Destroy()
	ExitApp()
}
MinimizemyGui(*) {
    global myGui, Settings
    ; Make sure window exists
    if !WinExist("ahk_id " myGui.Hwnd)
        return  ; Nothing to do

    ; Get position BEFORE hiding
	UpdateWindowPosition()

    Settings["Window"].lastState := 0
    ; Now hide the window
    myGui.Hide()
	Sleep (200)
}
RestoremyGui() {
	global myGui, Settings
	h := (Settings["Window"].logShow = 0 ? 198 : 600)
	xC := (A_ScreenWidth - 580)/2 
	yC := (A_ScreenHeight - h)/2
	x := Settings["Window"].xPos
	y := Settings["Window"].yPos
	if (Settings["Window"].restorePosition && (Settings["Window"].xPos < A_ScreenWidth && Settings["Window"].yPos < A_ScreenHeight)) 
		myGui.Show("x" x " y" y " w580 h" h)
	else
		myGui.Show("x" xC " y" yC "w580 h" h)
	Settings["Window"].lastState := 1
	Sleep (200)
}
ShowmyGui() {
	global myGui
	if (Settings["Window"].lastState = 1) {
		if Settings["Window"].restorePosition {
			Settings["Window"].restorePosition := false
			RestoremyGui()
			Settings["Window"].restorePosition := true
		} else 
			RestoremyGui()
	}
	else
		return
	Sleep (200)
}
OnMessage(0x404, TrayIconHandler)
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

FleetInit(*){
	global Settings
	; clean and prepare conf directory
	if !DirExist(Settings["Paths"].Config)	
		DirCreate(Settings["Paths"].Config)
	configDir := Settings["Paths"].Config
	; to delete any unexpected file "such as residual config/log"
	Loop Files configDir . '\*.*' {
		fileIdentified := false
		for instance in Settings["Fleet"].Instances{

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
	if (Settings["Fleet"].SyncSettings) {
		defaultConfFile := Settings["Paths"].Apollo . "\config\sunshine.conf"
		baseConf := ConfRead(defaultConfFile)
		if baseConf.Has("sunshine_name") 
			baseConf.Delete("sunshine_name") 
		if baseConf.Has("port")
			baseConf.Delete("port")
	}
	; assign and create conf files if not created
	for instance in Settings["Fleet"].Instances {
		if (instance.Enabled = 1) {
			if !(Settings["Fleet"].SyncSettings) && FileExist(instance.configFile)
				thisConf:= ConfRead(instance.configFile)	; this will keep config file to retain user modified settings
			else
				thisConf := baseConf.Clone()
			thisConf.set("sunshine_name", instance.Name, "port", instance.Port)
			if !FileExist(instance.configFile) || !(FileGetTime(instance.configFile, "M" ) = instance.LastConfigUpdate)
				ConfWrite(instance.configFile, thisConf)
			instance.LastConfigUpdate := FileGetTime(instance.configFile, "M" ) ; TODO implement this: only update if there's need/change
		}
	}
	; TODO Validate settings and reset invalid ones, clear invalid instances
	; TODO Keep the last remembered PIDs if they are still running
	; test them "maybe wget or sorta" 
	; kill the rest 

	; if AutoLaunch is set, check for schduleded task, add it if missing, enable it if disabled
	; else disable it ;;; EDIT: AutoLaunch will be used to determine if we launch these instances or not at all
	;							TODO Introduce Auto run at startup setting to specifically do that 


	if Settings["Fleet"].AutoLaunch
		SetTimer LogWatchDog, -1

	if Settings["Fleet"].SyncVolume || Settings["Fleet"].RemoveDisconnected
		SetTimer LogWatchDog, 100000

	if Settings["Android"].MicEnable || Settings["Android"].CamEnable
		SetTimer ADBWatchDog, 100000

	if Settings["Fleet"].SyncVolume
		SetTimer FleetSyncVolume, 10000

	if Settings["Fleet"].SyncSettings
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

settingsFile := A_ScriptDir "\state.ini"
global Settings := Map(), stagedSettings := Map()

LoadSettingsFile(settingsFile, Settings)
LoadSettingsFile(settingsFile, stagedSettings)

InitmyGui()
ApplyLockState()
ReflectSettings(Settings)
ShowmyGui()
InitmyGuiEvents()
InitTray()

SetTimer FleetInit, -1

; ───── Keep script alive ─────
While true
    Sleep(100)
