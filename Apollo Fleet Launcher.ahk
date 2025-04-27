#Requires Autohotkey v2



LoadStateFile(stateFile) {
	global Settings := Map()
    Settings["FleetManager"] := {}, Settings["Window"] := {}
	Settings["Paths"] := {}, Settings["Fleet"] := {}, Settings["Android"] := {}
	Settings.Instances := []

	;Settings["FleetManager"].SchduledService	; TODO
	;Settings["FleetManager"].StartMinimized	; TODO

	Settings["Window"].restorePosition := IniRead(stateFile, "Fleet Manager Window", "Remember location", 1)
    Settings["Window"].xPos := IniRead(stateFile, "Fleet Manager Window", "xPos", 0)
    Settings["Window"].yPos := IniRead(stateFile, "Fleet Manager Window", "yPos", 0)
    Settings["Window"].lastState := IniRead(stateFile, "Fleet Manager Window", "lastState", 0)

	DefaultApolloPath := "C:\Program Files\Apollo"
	DefaultConfigPath := "C:\Program Files\Apollo\config"
	Settings["Paths"].Apollo  := IniRead(stateFile, "Paths", "Apollo", DefaultApolloPath)
	Settings["Paths"].Config  := IniRead(stateFile, "Paths", "Config", DefaultConfigPath)

	Settings["Fleet"].AutoStart := IniRead(stateFile, "Fleet Options", "Auto Start", 1)
	Settings["Fleet"].SyncVolume := IniRead(stateFile, "Fleet Options", "Sync Volume Levels", 1)
	Settings["Fleet"].RemoveDisconnected := IniRead(stateFile, "Fleet Options", "Remove Disconnected", 1)
	Settings["Fleet"].SyncSettings := IniRead(stateFile, "Fleet Options", "Sync Settings", 1)

	Settings["Android"].ReverseTethering  := IniRead(stateFile, "Android Clients", "Reverse Tethering", 1)
	Settings["Android"].MicDeviceID  := IniRead(stateFile, "Android Clients", "Mic Device", "")
	Settings["Android"].CamDeviceID  := IniRead(stateFile, "Android Clients", "Cam Device", "")

    ; Iterate through all sections, focusing on "instance"
	sectionsNames:=StrSplit(IniRead(stateFile), "`n")
	index := 0
    ; Iterate through all sections, focusing on "instance"
    sectionsNames := StrSplit(IniRead(stateFile), "`n")
    for section in sectionsNames {
        if (SubStr(section, 1, 8) = "Instance") { ; section name starts with Instance
            instance := {} ; Create a new object for each instance
			instance.index := index
            instance.id := Number(SubStr(section, 9, ))
            instance.Name := IniRead(stateFile, section, "Name", "")
            instance.Port := IniRead(stateFile, section, "Port", "")
            ; instance.Audio := IniRead(stateFile, section, "Port", "") TODO
            Settings.Instances.Push(instance) ; Add the instance object to the Settings.Instances array
			index := index + 1
        }
    }
}
SaveStateFile(stateFile) {
    global Settings
	if (Settings["Window"].restorePosition = 1 && DllCall("IsWindowVisible", "ptr", myGui.Hwnd) ){
		WinGetPos(&x, &y, , , "ahk_id " myGui.Hwnd)
		; Save position
		Settings["Window"].xPos := x
		Settings["Window"].yPos := y
	}
    ; Window State
    IniWrite(Settings["Window"].restorePosition, stateFile, "Fleet Manager Window", "Remember location")
	IniWrite(Settings["Window"].xPos, stateFile, "Fleet Manager Window", "xPos")
    IniWrite(Settings["Window"].yPos, stateFile, "Fleet Manager Window", "yPos")
    IniWrite(Settings["Window"].lastState, stateFile, "Fleet Manager Window", "lastState")

    ; Paths
    IniWrite(Settings["Paths"].Apollo, stateFile, "Paths", "Apollo")
    IniWrite(Settings["Paths"].Config, stateFile, "Paths", "Config")

    ; Fleet Options
    IniWrite(Settings["Fleet"].AutoStart, stateFile, "Fleet Options", "Auto Start")
    IniWrite(Settings["Fleet"].SyncVolume, stateFile, "Fleet Options", "Sync Volume Levels")
    IniWrite(Settings["Fleet"].RemoveDisconnected, stateFile, "Fleet Options", "Remove Disconnected")
    IniWrite(Settings["Fleet"].SyncSettings, stateFile, "Fleet Options", "Sync Settings")

    ; Android Clients
    IniWrite(Settings["Android"].ReverseTethering, stateFile, "Android Clients", "Reverse Tethering")
    IniWrite(Settings["Android"].MicDeviceID, stateFile, "Android Clients", "Mic Device")
    IniWrite(Settings["Android"].CamDeviceID, stateFile, "Android Clients", "Cam Device")

    ; Instances
    for index, instance in Settings.Instances {
        sectionName := "Instance" instance.id
        IniWrite(instance.Name, stateFile, sectionName, "Name")
        IniWrite(instance.Port, stateFile, sectionName, "Port")
        ; IniWrite(instance.Audio, stateFile, sectionName, "Audio") ; TODO
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
	guiItems["ButtonLockSettings"] := myGui.Add("Button", "x368 y192 w60 h41", "🔒")
	guiItems["ButtonReload"] := myGui.Add("Button", "x432 y192 w60 h41", "Reload")
	guiItems["ButtonMinimize"] := myGui.Add("Button", "x496 y192 w70 h41", "Minimize")
	myGui.Add("GroupBox", "x368 y0 w200 h90", "Fleet Options")
	guiItems["FleetAutoStartCheckBox"] := myGui.Add("CheckBox", "x384 y16 w162 h23", "Auto Start Multi Instance")
	guiItems["FleetSyncVolCheckBox"] := myGui.Add("CheckBox", "x384 y40 w162 h23", "Sync Volume Levels")
	guiItems["FleetRemoveDisconnectCheckbox"] := myGui.Add("CheckBox", "x384 y64 w167 h23", "Remove on Disconnect")
	myGui.Add("GroupBox", "x368 y96 w200 h95", "Android Clients")
	guiItems["AndroidReverseTetheringCheckbox"] := myGui.Add("CheckBox", "x384 y112 w139 h23", "ADB Reverse Tethering")
	guiItems["AndroidMicCheckbox"] := myGui.Add("CheckBox", "x384 y136 w39 h23", "Mic:")
	guiItems["AndroidMicSelector"] := myGui.Add("ComboBox", "x432 y136 w122", [])
	guiItems["AndroidCamCheckbox"] := myGui.Add("CheckBox", "x384 y160 w42 h23", "Cam:")
	guiItems["AndroidCamSelector"] := myGui.Add("ComboBox", "x432 y160 w122", [])
	myGui.Add("GroupBox", "x8 y0 w349 h90", "Paths")
	guiItems["PathsApolloBox"] := myGui.Add("Edit", "x56 y24 w222 h23")
	myGui.Add("Text", "x16 y24 w35 h23", "Apollo:")
	guiItems["PathsApolloBrowseButton"] := myGui.Add("Button", "x280 y24 w33 h23", "📂")
	guiItems["PathsApolloResetButton"] := myGui.Add("Button", "x320 y24 w27 h23", "✖")
	guiItems["PathsConfigBox"] := myGui.Add("Edit", "x56 y56 w222 h23")
	myGui.Add("Text", "x16 y56 w35 h23", "Config:")
	guiItems["PathsConfigBrowseButton"] := myGui.Add("Button", "x280 y56 w33 h23", "📂")
	guiItems["PathsConfigResetButton"] := myGui.Add("Button", "x320 y56 w27 h23", "✖")
	myGui.Add("GroupBox", "x8 y96 w349 h140", "Settings.Instances")
	myGui.Add("Text", "x176 y120 w45 h23", "Name:")
	guiItems["InstancesNameBox"] := myGui.Add("Edit", "x216 y120 w130 h23")
	myGui.Add("Text", "x176 y152 w45 h23", "Port:")
	guiItems["InstancesPortBox"] := myGui.Add("Edit", "x216 y152 w110 h23", "1")
	guiItems["PortUpDown"] := myGui.Add("UpDown", "x329 y152 w22 h23 -16")
	myGui.Add("Text", "x176 y184 w54 h23", "Audio:")
	guiItems["InstancesAudioSelector"] := myGui.Add("ComboBox", "x216 y184 w130", [])
	guiItems["FleetSyncCheckbox"] := myGui.Add("CheckBox", "x190 y208 w165 h23", "Sync The Remaining Settings")
	guiItems["InstancesButtonAdd"] := myGui.Add("Button", "x96 y208 w74 h23", "Add")
	guiItems["InstancesButtonDelete"] := myGui.Add("Button", "x16 y208 w74 h23", "Delete")
	guiItems["LogTextBox"] := myGui.Add("Edit", "x8 y240 w562 h351 -VScroll +ReadOnly")
	myGui.Title := "Apollo Fleet Launcher"
}
InitTray(){
	A_TrayMenu.Delete()
	A_TrayMenu.Add("Show Manager", (*) => ShowmyGui())
	A_TrayMenu.Add("Minimize", (*) => MinimizemyGui())
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
	guiItems["PathsConfigBox"].Value := Settings["Paths"].Config
	guiItems["InstancesListBox"] := myGui.Add("ListBox", "x16 y120 w150 h82 +0x100", GetInstancesProperty(Settings.Instances, "Name"))
	guiItems["InstancesAudioSelector"].Enabled :=0
}
InitmyGuiEvents(){
	global myGui, guiItems
	myGui.OnEvent('Close', (*) => ExitMyApp())
	guiItems["ButtonMinimize"].OnEvent("Click", MinimizemyGui)
	guiItems["ButtonLockSettings"].OnEvent("Click", HandleSettingsLock)
	
}

global settingsLocked := false
HandleSettingsLock(*) {
    global guiItems, 
    settingsLocked := !settingsLocked   ; Toggle lock state
	guiItems["ButtonLockSettings"].Text := settingsLocked ? "🔒" : "🔓"
    keep := ["LogTextBox", "ButtonLockSettings", "ButtonReload", "ButtonMinimize", "AndroidMicSelector", "AndroidCamSelector", "InstancesAudioSelector"]
    for key, item in guiItems
    {
        isException := false
        for _, exception in keep
        {
            if (key = exception)
            {
                isException := true
                break
            }
        }
        if (settingsLocked && !isException)
            item.Enabled := false   ; Lock (disable)
        else if (!settingsLocked && !isException)
            item.Enabled := true    ; Unlock (enable)
    }
}

; ───── Functions ─────
ExitMyApp() {
	Sleep(1000) ; Give time to save state
	global myGui, Settings
	SaveStateFile(stateFile)
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
}



RestoremyGui() {
	global myGui, Settings
	if (Settings["Window"].restorePosition = 1) 
		myGui.Show("x" Settings["Window"].xPos " y" Settings["Window"].yPos " w580 h600")
	else
		myGui.Show("w580 h600")
	Settings["Window"].lastState := 1
}

ShowmyGui() {
	global myGui, Settings
	if (Settings["Window"].lastState = 1) {
		RestoremyGui()
	}
	else
		return
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








stateFile := A_ScriptDir "\state.ini"

LoadStateFile(stateFile)
InitmyGui()
ReflectSettings()
InitmyGuiEvents
HandleSettingsLock()
ShowmyGui()
InitTray()

; ───── Keep script alive ─────
While true
    Sleep(100)
