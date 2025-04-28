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
ConfWrite(FilePath, Key, Value) {
    lines := []
    keyFound := false

    ; If file exists, read all lines
    if FileExist(FilePath) {
        Loop Read, FilePath
        {
            line := A_LoopReadLine
            if RegExMatch(line, "^\s*" . Key . "\s*=", &match) {
                ; Key found, replace the line
                lines.Push(Key . " = " . Value)
                keyFound := true
            } else {
                lines.Push(line)
            }
        }
    }
    
    ; If key wasn't found, add it
    if (!keyFound) {
        lines.Push(Key . " = " . Value)
    }

    ; Write back all lines
    FileDelete FilePath  ; Remove old file
    FileAppend lines.Join("`n"), FilePath
}

LoadSettingsFile(settingsFile) {
	global Settings := Map()
    Settings["FleetManager"] := {}, Settings["Window"] := {}
	Settings["Paths"] := {}, Settings["Fleet"] := {}, Settings["Android"] := {}
	Settings.Instances := []

	;Settings["FleetManager"].SchduledService	; TODO
	;Settings["FleetManager"].StartMinimized	; TODO

	Settings["Window"].restorePosition := IniRead(settingsFile, "Fleet Manager Window", "Remember location", 1)
    Settings["Window"].xPos := IniRead(settingsFile, "Fleet Manager Window", "xPos", 0)
    Settings["Window"].yPos := IniRead(settingsFile, "Fleet Manager Window", "yPos", 0)
    Settings["Window"].lastState := IniRead(settingsFile, "Fleet Manager Window", "lastState", 0)
	Settings["Window"].logShow := IniRead(settingsFile, "Fleet Manager Window", "Show Logs", 0)


	DefaultApolloPath := "C:\Program Files\Apollo"
	;DefaultConfigPath := "C:\Program Files\Apollo\config"
	DefaultADBPath := A_ScriptDir . "\platform-tools"
	Settings["Paths"].Apollo  := IniRead(settingsFile, "Paths", "Apollo", DefaultApolloPath)
	;Settings["Paths"].Config  := IniRead(settingsFile, "Paths", "Config", DefaultConfigPath)
	Settings["Paths"].ADBTools  := IniRead(settingsFile, "Paths", "ADB", DefaultADBPath)
	

	Settings["Fleet"].AutoStart := IniRead(settingsFile, "Fleet Options", "Auto Start", 1)
	Settings["Fleet"].SyncVolume := IniRead(settingsFile, "Fleet Options", "Sync Volume Levels", 1)
	Settings["Fleet"].RemoveDisconnected := IniRead(settingsFile, "Fleet Options", "Remove Disconnected", 1)
	Settings["Fleet"].SyncSettings := IniRead(settingsFile, "Fleet Options", "Sync Settings", 1)

	Settings["Android"].ReverseTethering  := IniRead(settingsFile, "Android Clients", "Reverse Tethering", 1)
	Settings["Android"].MicDeviceID  := IniRead(settingsFile, "Android Clients", "Mic Device", "")
	Settings["Android"].CamDeviceID  := IniRead(settingsFile, "Android Clients", "Cam Device", "")

	defaultConfFile :=DefaultApolloPath . "\config\sunshine.conf"
	instance := {} ; Create a new object for each instance
	instance.index := 0
	instance.id := 0
	instance.Name := ConfRead(defaultConfFile, "sunshine_name", "default instance")
	instance.Port := ConfRead(defaultConfFile, "port", "47987")
	; instance.Audio := IniRead(settingsFile, section, "Port", "") TODO
	instance.Settings := ConfRead(defaultConfFile)
	Settings.Instances.Push(instance) ; Add the instance object to the Settings.Instances array


    ; Iterate through all sections, focusing on "instance"
	index := 1
    ; Iterate through all sections, focusing on "instance"
    sectionsNames := StrSplit(IniRead(settingsFile), "`n")
    for section in sectionsNames {
        if (SubStr(section, 1, 8) = "Instance") { ; section name starts with Instance
            instance := {} ; Create a new object for each instance
			instance.index := index
            instance.id := Number(SubStr(section, 9 ))
            instance.Name := IniRead(settingsFile, section, "Name", "")
            instance.Port := IniRead(settingsFile, section, "Port", "")
            ; instance.Audio := IniRead(settingsFile, section, "Port", "") TODO
            Settings.Instances.Push(instance) ; Add the instance object to the Settings.Instances array
			index := index + 1
        }
    }
}
SaveSettingsFile(settingsFile) {
    global Settings
	if (Settings["Window"].restorePosition = 1 && DllCall("IsWindowVisible", "ptr", myGui.Hwnd) ){
		WinGetPos(&x, &y, , , "ahk_id " myGui.Hwnd)
		; Save position
		Settings["Window"].xPos := x
		Settings["Window"].yPos := y
	}
    ; Window State
    IniWrite(Settings["Window"].restorePosition, settingsFile, "Fleet Manager Window", "Remember location")
	IniWrite(Settings["Window"].xPos, settingsFile, "Fleet Manager Window", "xPos")
    IniWrite(Settings["Window"].yPos, settingsFile, "Fleet Manager Window", "yPos")
    IniWrite(Settings["Window"].lastState, settingsFile, "Fleet Manager Window", "lastState")
	IniWrite(Settings["Window"].logShow, settingsFile, "Fleet Manager Window", "Show Logs")


    ; Paths
    IniWrite(Settings["Paths"].Apollo, settingsFile, "Paths", "Apollo")
    ;IniWrite(Settings["Paths"].Config, settingsFile, "Paths", "Config")
    IniWrite(Settings["Paths"].ADBTools, settingsFile, "Paths", "ADB")

    ; Fleet Options
    IniWrite(Settings["Fleet"].AutoStart, settingsFile, "Fleet Options", "Auto Start")
    IniWrite(Settings["Fleet"].SyncVolume, settingsFile, "Fleet Options", "Sync Volume Levels")
    IniWrite(Settings["Fleet"].RemoveDisconnected, settingsFile, "Fleet Options", "Remove Disconnected")
    IniWrite(Settings["Fleet"].SyncSettings, settingsFile, "Fleet Options", "Sync Settings")

    ; Android Clients
    IniWrite(Settings["Android"].ReverseTethering, settingsFile, "Android Clients", "Reverse Tethering")
    IniWrite(Settings["Android"].MicDeviceID, settingsFile, "Android Clients", "Mic Device")
    IniWrite(Settings["Android"].CamDeviceID, settingsFile, "Android Clients", "Cam Device")

    ; Instances
    for instance in Settings.Instances {
		if instance.id > 0 {
        	sectionName := "Instance" instance.id
			IniWrite(instance.Name, settingsFile, sectionName, "Name")
			IniWrite(instance.Port, settingsFile, sectionName, "Port")
			; IniWrite(instance.Audio, settingsFile, sectionName, "Audio") ; TODO

		}
    }
}
GetInstancesProperty(Instances, property) {
    ; Initialize an empty array to store the requested property for each instance
    values := []

    ; Loop through each instance (element) in the Settings.Instances array
    for instance in Settings.Instances {
        ; Access the specific property (id, Name, or Port) for the current instance
        values.push(instance.%property%)
    }
    ; Return the array of values (either id, Name, or Port)
    return values
}

InitmyGui() {
	global myGui, guiItems := Map()
	TraySetIcon("shell32.dll", "19")
	myGui := Gui(" -MinimizeBox -MaximizeBox")
	guiItems["ButtonLockSettings"] := myGui.Add("Button", "x520 y5 w50 h40", "🔒")
	guiItems["ButtonReload"] := myGui.Add("Button", "x520 y50 w50 h40", "Reload")
	guiItems["ButtonLogsShow"] := myGui.Add("Button", "x520 y101 w50 h40", "Show Logs")
	guiItems["ButtonMinimize"] := myGui.Add("Button", "x520 y150 w50 h40", "Minimize")
	myGui.Add("GroupBox", "x318 y0 w196 h90", "Fleet Options")
	guiItems["FleetAutoStartCheckBox"] := myGui.Add("CheckBox", "x334 y16 w162 h23", "Auto Start Multi Instance")
	guiItems["FleetSyncVolCheckBox"] := myGui.Add("CheckBox", "x334 y40 w162 h23", "Sync Volume Levels")
	guiItems["FleetRemoveDisconnectCheckbox"] := myGui.Add("CheckBox", "x334 y64 w167 h23", "Remove on Disconnect")
	myGui.Add("GroupBox", "x318 y96 w196 h95", "Android Clients")
	guiItems["AndroidReverseTetheringCheckbox"] := myGui.Add("CheckBox", "x334 y112 w139 h23", "ADB Reverse Tethering")
	guiItems["AndroidMicCheckbox"] := myGui.Add("CheckBox", "x334 y140 ", "Mic:")
	guiItems["AndroidMicSelector"] := myGui.Add("ComboBox", "x382 y136 w122", [])
	guiItems["AndroidCamCheckbox"] := myGui.Add("CheckBox", "x334 y164 ", "Cam:")
	guiItems["AndroidCamSelector"] := myGui.Add("ComboBox", "x382 y160 w122", [])
	guiItems["PathsApolloBox"] := myGui.Add("Edit", "x56 y24 w172 h23")
	myGui.Add("Text", "x16 y28", "Apollo:")
	guiItems["PathsApolloBrowseButton"] := myGui.Add("Button", "x230 y24 w33 h23", "📂")
	guiItems["PathsApolloResetButton"] := myGui.Add("Button", "x270 y24 w27 h23", "✖")
	myGui.Add("GroupBox", "x8 y0 w300 h192", "Instances")
	myGui.Add("Text", "x126 y70", "Name:")
	guiItems["InstancesNameBox"] := myGui.Add("Edit", "x166 y65 w130 h23")
	myGui.Add("Text", "x126 y98", "Port:")
	guiItems["InstancesPortBox"] := myGui.Add("Edit", "x166 y92 w130 h23 +ReadOnly", "")
	;myGui.Add("Text", "x126 y120 w54 h23", "Audio:")
	;guiItems["InstancesAudioSelector"] := myGui.Add("ComboBox", "x166 y120 w130", [])
	myGui.Add("Text", "x126 y126 ", "Link:")
	myLink := "https://google.com"
	guiItems["InstancesLinkBox"] := myGui.Add("Link", "x166 y126", '<a href="' . myLink . '">' . myLink . '</a>')
	guiItems["FleetSyncCheckbox"] := myGui.Add("CheckBox", "x130 y155 w165 h23", " Copy Default Instance Settings")
	guiItems["InstancesButtonAdd"] := myGui.Add("Button", "x49 y155 w71 h23", "Add")
	guiItems["InstancesButtonDelete"] := myGui.Add("Button", "x16 y155 w27 h23", "✖")
	guiItems["LogTextBox"] := myGui.Add("Edit", "x8 y199 w562 h393 -VScroll +ReadOnly")
	myGui.Title := "Apollo Fleet Launcher"
}
InitTray(){
	A_TrayMenu.Delete()
	A_TrayMenu.Add("Show Manager", (*) => ShowmyGui())
	A_TrayMenu.Add("Reload", (*) => MinimizemyGui())
	A_TrayMenu.Add()
	A_TrayMenu.Add("Exit", (*) => ExitMyApp())
}
ReflectSettings(){
	global myGui, guiItems
	guiItems["FleetAutoStartCheckBox"].Value := Settings["Fleet"].AutoStart
	guiItems["FleetSyncVolCheckBox"].Value := Settings["Fleet"].SyncVolume
	guiItems["FleetRemoveDisconnectCheckbox"].Value := Settings["Fleet"].RemoveDisconnected
	guiItems["FleetSyncCheckbox"].Value := Settings["Fleet"].SyncSettings
	guiItems["AndroidReverseTetheringCheckbox"].Value := Settings["Android"].ReverseTethering
	guiItems["AndroidMicCheckbox"].Value := (Settings["Android"].MicDeviceID = "" ? 0 : 1)
	guiItems["AndroidMicSelector"].Enabled := guiItems["AndroidMicCheckbox"].Value
	guiItems["AndroidCamCheckbox"].Value := (Settings["Android"].CamDeviceID = "" ? 0 : 1)
	guiItems["AndroidCamSelector"].Enabled := guiItems["AndroidCamCheckbox"].Value
	guiItems["PathsApolloBox"].Value := Settings["Paths"].Apollo
	guiItems["ButtonLogsShow"].Text := (Settings["Window"].logShow = 1 ? "Hide Logs" : "Show Logs")
	guiItems["InstancesListBox"] := myGui.Add("ListBox", "x16 y66 w100 h82 +0x100 Choose1", GetInstancesProperty(Settings.Instances, "Name"))
	;guiItems["InstancesAudioSelector"].Enabled :=0
}
InitmyGuiEvents(){
	global myGui, guiItems
	myGui.OnEvent('Close', (*) => ExitMyApp())
	guiItems["ButtonMinimize"].OnEvent("Click", MinimizemyGui)
	guiItems["ButtonLockSettings"].OnEvent("Click", HandleSettingsLock)
	guiItems["ButtonReload"].OnEvent("Click", HandleReloadButton)
	guiItems["ButtonLogsShow"].OnEvent("Click", HandleLogsButton)
	guiItems["InstancesListBox"].OnEvent
}

HandleLogsButton(*) {
	global guiItems, Settings
	Settings["Window"].logShow := ! Settings["Window"].logShow
	guiItems["ButtonLogsShow"].Text := (Settings["Window"].logShow = 1 ? "Hide Logs" : "Show Logs")
	WinGetPos(&x, &y, , , "ahk_id " myGui.Hwnd)
    Settings["Window"].xPos := x
    Settings["Window"].yPos := y
	RestoremyGui()
	Sleep (100)
}
HandleReloadButton(*) {
	global settingsLocked
	if settingsLocked {
		; actual reload proccedure
		return
	}
	else {
		ReflectSettings()
		HandleSettingsLock()
	}
	Sleep (100)
}

global settingsLocked := false
HandleSettingsLock(*) {
    global guiItems, settingsLocked
	if ValidateSettings() {
		settingsLocked := !settingsLocked   ; Toggle lock state
		guiItems["ButtonLockSettings"].Text := settingsLocked ? "🔒" : "Apply"
		guiItems["ButtonReload"].Text := settingsLocked ? "Reload" : "Cancel"
		textBoxes := [ "PathsApolloBox", "InstancesNameBox"]
		checkBoxes := ["FleetAutoStartCheckBox", "FleetSyncVolCheckBox", "FleetRemoveDisconnectCheckbox", "AndroidReverseTetheringCheckbox", "AndroidMicCheckbox", "AndroidCamCheckbox", "FleetSyncCheckbox"]
		Buttons := ["InstancesButtonDelete", "InstancesButtonAdd", "PathsApolloBrowseButton", "PathsApolloResetButton"]

		for textBox in textBoxes
			guiItems[textbox].Opt(settingsLocked ? "+ReadOnly" : "-ReadOnly")
		for checkBox in checkBoxes
			guiItems[checkBox].Enabled := (settingsLocked ? false : true)
		for button in Buttons
			guiItems[button].Enabled := (settingsLocked ? false : true)
		if settingsLocked{
			SaveSettingsFile(settingsFile)
			HandleReloadButton()
		}
	}
	else {
		MsgBox("Invalid Setting: `"`" `nReason: `"`"", "Apollo Fleet Launcher - Error", "4144 T3")
		return
	}
	Sleep (100)
}

global settingsValid := false,invalidSettings:= [], invalidReasons := []
ValidateSettings() {
	global myGui, Settings, settingsFile
	global settingsValid
	settingsValid := true
	return True
}

ExitMyApp() {
	Sleep(100) ; Give time to save state
	global myGui, Settings
	SaveSettingsFile(settingsFile)
	myGui.Destroy()
	ExitApp()
}
MinimizemyGui(*) {
    global myGui, Settings
    ; Make sure window exists
    if !WinExist("ahk_id " myGui.Hwnd)
        return  ; Nothing to do

    ; Get position BEFORE hiding
    WinGetPos(&x, &y, , , "ahk_id " myGui.Hwnd)

    ; Save position
    Settings["Window"].xPos := x
    Settings["Window"].yPos := y
    Settings["Window"].lastState := 0
    ; Now hide the window
    myGui.Hide()
	Sleep (100)
}



RestoremyGui() {
	global myGui
	h := (Settings["Window"].logShow = 0 ? " h198" : "h600")
	if (Settings["Window"].restorePosition = 1) 
		myGui.Show("x" Settings["Window"].xPos " y" Settings["Window"].yPos " w580 " h)
	else
		myGui.Show("w580 " h)
	Settings["Window"].lastState := 1
	Sleep (100)
}

ShowmyGui() {
	global myGui, Settings
	if (Settings["Window"].lastState = 1) {
		RestoremyGui()
	}
	else
		return
	Sleep (100)
}


; ───── Tray Icon Click Handler ─────
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








settingsFile := A_ScriptDir "\state.ini"

InitmyGui()
LoadSettingsFile(settingsFile)
HandleSettingsLock()
ReflectSettings()
ShowmyGui()
InitmyGuiEvents()
InitTray()

; ───── Keep script alive ─────
While true
    Sleep(100)
