; By @jNizM https://www.autohotkey.com/boards/viewtopic.php?t=115952

global DarkColors          := Map("Background", "0x202020", "Controls", "0x404040", "Font", "0xE0E0E0")
global TextBackgroundBrush := DllCall("gdi32\CreateSolidBrush", "UInt", DarkColors["Background"], "Ptr")

SetWindowAttribute(GuiObj, DarkMode := True)
{
	global DarkColors          := Map("Background", "0x202020", "Controls", "0x404040", "Font", "0xE0E0E0")
	global TextBackgroundBrush := DllCall("gdi32\CreateSolidBrush", "UInt", DarkColors["Background"], "Ptr")
	static PreferredAppMode    := Map("Default", 0, "AllowDark", 1, "ForceDark", 2, "ForceLight", 3, "Max", 4)

	if (VerCompare(A_OSVersion, "10.0.17763") >= 0)
	{
		DWMWA_USE_IMMERSIVE_DARK_MODE := 19
		if (VerCompare(A_OSVersion, "10.0.18985") >= 0)
		{
			DWMWA_USE_IMMERSIVE_DARK_MODE := 20
		}
		uxtheme := DllCall("kernel32\GetModuleHandle", "Str", "uxtheme", "Ptr")
		SetPreferredAppMode := DllCall("kernel32\GetProcAddress", "Ptr", uxtheme, "Ptr", 135, "Ptr")
		FlushMenuThemes     := DllCall("kernel32\GetProcAddress", "Ptr", uxtheme, "Ptr", 136, "Ptr")
		switch DarkMode
		{
			case True:
			{
				DllCall("dwmapi\DwmSetWindowAttribute", "Ptr", GuiObj.hWnd, "Int", DWMWA_USE_IMMERSIVE_DARK_MODE, "Int*", True, "Int", 4)
				DllCall(SetPreferredAppMode, "Int", PreferredAppMode["ForceDark"])
				DllCall(FlushMenuThemes)
				GuiObj.BackColor := DarkColors["Background"]
			}
			default:
			{
				DllCall("dwmapi\DwmSetWindowAttribute", "Ptr", GuiObj.hWnd, "Int", DWMWA_USE_IMMERSIVE_DARK_MODE, "Int*", False, "Int", 4)
				DllCall(SetPreferredAppMode, "Int", PreferredAppMode["Default"])
				DllCall(FlushMenuThemes)
				GuiObj.BackColor := "Default"
			}
		}
	}
}


SetWindowTheme(GuiObj, DarkMode := True)
{
	static GWL_WNDPROC := -4, GWL_STYLE := -16
	static ES_MULTILINE := 0x0004
	static LVM_GETTEXTCOLOR := 0x1023, LVM_SETTEXTCOLOR := 0x1024
	static LVM_GETTEXTBKCOLOR := 0x1025, LVM_SETTEXTBKCOLOR := 0x1026
	static LVM_GETBKCOLOR := 0x1000, LVM_SETBKCOLOR := 0x1001
	static LVM_GETHEADER := 0x101F
	static GetWindowLong := A_PtrSize = 8 ? "GetWindowLongPtr" : "GetWindowLong"
	static SetWindowLong := A_PtrSize = 8 ? "SetWindowLongPtr" : "SetWindowLong"
	static Init := False, LV_Init := False

	global IsDarkMode := DarkMode
	global CheckboxLabelMap := Map()

	Mode_Explorer := (DarkMode ? "DarkMode_Explorer" : "Explorer")
	Mode_CFD := (DarkMode ? "DarkMode_CFD" : "CFD")
	Mode_ItemsView := (DarkMode ? "DarkMode_ItemsView" : "ItemsView")

	for hWnd, GuiCtrlObj in GuiObj
	{
		switch GuiCtrlObj.Type
		{
			case "CheckBox":
			{
				DllCall("uxtheme\SetWindowTheme", "Ptr", GuiCtrlObj.hWnd, "Str", Mode_Explorer, "Ptr", 0)
			}
			case "Button", "ListBox", "UpDown":
			{
				DllCall("uxtheme\SetWindowTheme", "Ptr", GuiCtrlObj.hWnd, "Str", Mode_Explorer, "Ptr", 0)
			}
			case "ComboBox", "DDL":
			{
				DllCall("uxtheme\SetWindowTheme", "Ptr", GuiCtrlObj.hWnd, "Str", Mode_CFD, "Ptr", 0)
			}
			case "Edit":
			{
				style := DllCall("user32\" GetWindowLong, "Ptr", GuiCtrlObj.hWnd, "Int", GWL_STYLE)
				theme := (style & ES_MULTILINE) ? Mode_Explorer : Mode_CFD
				DllCall("uxtheme\SetWindowTheme", "Ptr", GuiCtrlObj.hWnd, "Str", theme, "Ptr", 0)
			}
			case "ListView":
			{
				if !(LV_Init)
				{
					static LV_TEXTCOLOR := SendMessage(LVM_GETTEXTCOLOR, 0, 0, GuiCtrlObj.hWnd)
					static LV_TEXTBKCOLOR := SendMessage(LVM_GETTEXTBKCOLOR, 0, 0, GuiCtrlObj.hWnd)
					static LV_BKCOLOR := SendMessage(LVM_GETBKCOLOR, 0, 0, GuiCtrlObj.hWnd)
					LV_Init := True
				}
				GuiCtrlObj.Opt("-Redraw")
				if DarkMode
				{
					SendMessage(LVM_SETTEXTCOLOR, 0, DarkColors["Font"], GuiCtrlObj.hWnd)
					SendMessage(LVM_SETTEXTBKCOLOR, 0, DarkColors["Background"], GuiCtrlObj.hWnd)
					SendMessage(LVM_SETBKCOLOR, 0, DarkColors["Background"], GuiCtrlObj.hWnd)
				}
				else
				{
					SendMessage(LVM_SETTEXTCOLOR, 0, LV_TEXTCOLOR, GuiCtrlObj.hWnd)
					SendMessage(LVM_SETTEXTBKCOLOR, 0, LV_TEXTBKCOLOR, GuiCtrlObj.hWnd)
					SendMessage(LVM_SETBKCOLOR, 0, LV_BKCOLOR, GuiCtrlObj.hWnd)
				}
				DllCall("uxtheme\SetWindowTheme", "Ptr", GuiCtrlObj.hWnd, "Str", Mode_Explorer, "Ptr", 0)
				LV_Header := SendMessage(LVM_GETHEADER, 0, 0, GuiCtrlObj.hWnd)
				DllCall("uxtheme\SetWindowTheme", "Ptr", LV_Header, "Str", Mode_ItemsView, "Ptr", 0)
				GuiCtrlObj.Opt("+Redraw")
			}
		}
	}

	if !Init
	{
		global WindowProcNew := CallbackCreate(WindowProc)
		global WindowProcOld := DllCall("user32\" SetWindowLong, "Ptr", GuiObj.Hwnd, "Int", GWL_WNDPROC, "Ptr", WindowProcNew, "Ptr")
		Init := True
	}
}



WindowProc(hwnd, uMsg, wParam, lParam)
{
	critical
	static WM_CTLCOLOREDIT    := 0x0133
	static WM_CTLCOLORLISTBOX := 0x0134
	static WM_CTLCOLORBTN     := 0x0135
	static WM_CTLCOLORSTATIC  := 0x0138
	static DC_BRUSH           := 18

	if (IsDarkMode)
	{
		switch uMsg
		{
			case WM_CTLCOLOREDIT, WM_CTLCOLORLISTBOX:
			{
				DllCall("gdi32\SetTextColor", "Ptr", wParam, "UInt", DarkColors["Font"])
				DllCall("gdi32\SetBkColor", "Ptr", wParam, "UInt", DarkColors["Controls"])
				DllCall("gdi32\SetDCBrushColor", "Ptr", wParam, "UInt", DarkColors["Controls"], "UInt")
				return DllCall("gdi32\GetStockObject", "Int", DC_BRUSH, "Ptr")
			}
			case WM_CTLCOLORBTN:
			{
				DllCall("gdi32\SetDCBrushColor", "Ptr", wParam, "UInt", DarkColors["Background"], "UInt")
				return DllCall("gdi32\GetStockObject", "Int", DC_BRUSH, "Ptr")
			}
			case WM_CTLCOLORSTATIC:
			{
				DllCall("gdi32\SetTextColor", "Ptr", wParam, "UInt", DarkColors["Font"])
				DllCall("gdi32\SetBkColor", "Ptr", wParam, "UInt", DarkColors["Background"])
				return TextBackgroundBrush
			}
		}
	}
	return DllCall("user32\CallWindowProc", "Ptr", WindowProcOld, "Ptr", hwnd, "UInt", uMsg, "Ptr", wParam, "Ptr", lParam)
}












; By @nperovic https://github.com/nperovic/Dark_WindowSpy/blob/main/WindowSpy.ahk
AddDarkCheckBox(gui, Options, Text)
{
    static checkBoxW := SysGet(71)
    static checkBoxH := SysGet(72)
    static HWND_TOP := 0

    ; Add checkbox with label to trigger rendering
    chbox := gui.Add("Checkbox", Options " r1.2 +0x4000000", Text)

    ; Wipe native label
    chbox.Text := ""

    ; Add fake label
    if !InStr(Options, "right")
        lbl := gui.Add("Text", "xp+" (checkBoxW + 5) " yp+1 HP-4 +0x4000200", Text)
    else
        lbl := gui.Add("Text", "xp+5 yp+1 HP-4 +0x4000200", Text)

    ; Bring checkbox & label to front (above groupbox!)
    SetWindowPos(chbox.hwnd, HWND_TOP, 0, 0, 0, 0, 0x43)
    SetWindowPos(lbl.hwnd, HWND_TOP, 0, 0, 0, 0, 0x43)

    ; Optional: click label to toggle
    lbl.OnEvent("Click", (*) => chbox.Value := !chbox.Value)

    ; Define .Text prop
    chbox.DeleteProp("Text")
    chbox.DefineProp("Text", {
        Get: this => lbl.Text,
        Set: (this, v) => lbl.Text := v
    })

    return chbox
}

SetWindowPos(hwnd, insertAfter := 0, x := 0, y := 0, w := 0, h := 0, flags := 0x40)
{
    DllCall("SetWindowPos", "ptr", hwnd, "ptr", insertAfter, "int", x, "int", y, "int", w, "int", h, "uint", flags)
}

AddDarkGroupBox(gui, Options, Text) {
    gb := gui.Add("GroupBox", Options, " " Text " ")
    lbl := gui.Add("Text", "xp+10 yp-1", " " Text " ")
    gb.Label := lbl  ; Store label as property
    return gb
}


Gui.Prototype.DefineProp("AddDarkCheckBox", {Call: AddDarkCheckBox})
Gui.Prototype.DefineProp("AddDarkGroupBox", {Call: AddDarkGroupBox})


















SetDarkControl(ctrl, style := "DarkMode_Explorer")
{
	static IsWin11 := (VerCompare(A_OSVersion, "10.0.22000") > 0)
	hwnd := IsObject(ctrl) ? ctrl.hwnd : ctrl
	DllCall("uxtheme\SetWindowTheme", "ptr", hwnd, "ptr", StrPtr(style), "ptr", 0)
	if IsWin11
		DllCall("Dwmapi\DwmSetWindowAttribute", "Ptr", hwnd, "UInt", 33, "Ptr*", 3, "UInt", 4)
}

SetDarkMode(_obj)
{
	For v in [135, 136]
		DllCall(DllCall("GetProcAddress", "ptr", DllCall("GetModuleHandle", "str", "uxtheme", "ptr"), "ptr", v, "ptr"), "int", 2)

	if !(attr := VerCompare(A_OSVersion, "10.0.18985") >= 0 ? 20 : VerCompare(A_OSVersion, "10.0.17763") >= 0 ? 19 : 0)
		return false
	
	DllCall("dwmapi\DwmSetWindowAttribute", "ptr", _obj.hwnd, "int", attr, "int*", true, "int", 4)
}


IsSystemDarkMode() {
    RegRead("HKCU\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize", "AppsUseLightTheme", &val := 1)
    return 1
}