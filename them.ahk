#Requires AutoHotkey v2.0

Main := Gui()

; call dark mode for window title + menu
SetWindowAttribute(Main)

Main.AddText("xm ym w300 0x200", "Static Control")
Main.AddEdit("xm y+10 w300", "Edit Control")
Main.AddEdit("xm y+10 w300", "Edit Control + UpDown")
Main.AddUpDown()
Main.AddEdit("xm y+10 w300 r3", "Multi-Line Edit Control")
Main.AddDropDownList("xm y+10 w300 Choose1", ["DDL Control", "DDL 2", "DDL 3"])
Main.AddComboBox("xm y+10 w300 Choose1", ["CB Control", "CB 2", "CB 3"])

; Regular checkbox (will be styled)
CB1 := Main.AddCheckBox("xm y+10 w300", "CheckBox")

; Custom checkbox approach
SGW := SysGet(SM_CXMENUCHECK := 71)
SGH := SysGet(SM_CYMENUCHECK := 72)
CB2 := Main.AddCheckBox("xm y+10 Checked h" SGH " w" SGW)
Main.AddText("x+1 yp 0x200 h" SGH, "Fake Checkbox")

; Grayed checkbox
CB3 := Main.AddCheckBox("xm y+10 w300 Check3 CheckedGray", "CheckBox CheckedGray")

Main.AddButton("xm y+10 w300", "Button")
Main.AddRadio("xm y+10 w300 Group Checked", "DarkMode").OnEvent("Click", ToggleTheme)
Main.AddRadio("xm y+10 w300", "LightMode").OnEvent("Click", ToggleTheme)
LV := Main.AddListView("x+10 ym w300 r10", ["LV 1", "LV 2", "LV 3"])
loop 11
	LV.Add("", A_Index, A_Index, A_Index)
LB_Entries := Array()
loop 11
	LB_Entries.Push("LB " A_Index)
Main.AddListBox("xp y+10 w300 r10", LB_Entries)
Main.OnEvent("Close", (*) =>  ExitApp)

; call dark mode for controls
SetWindowTheme(Main)

Main.Show("AutoSize")

ToggleTheme(GuiCtrlObj, *)
{
	switch GuiCtrlObj.Text
	{
		case "DarkMode":
		{
			SetWindowAttribute(Main)
			SetWindowTheme(Main)
		}
		default:
		{
			SetWindowAttribute(Main, False)
			SetWindowTheme(Main, False)
		}
	}
}

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
	static GWL_WNDPROC        := -4
	static GWL_STYLE          := -16
	static ES_MULTILINE       := 0x0004
	static LVM_GETTEXTCOLOR   := 0x1023
	static LVM_SETTEXTCOLOR   := 0x1024
	static LVM_GETTEXTBKCOLOR := 0x1025
	static LVM_SETTEXTBKCOLOR := 0x1026
	static LVM_GETBKCOLOR     := 0x1000
	static LVM_SETBKCOLOR     := 0x1001
	static LVM_GETHEADER      := 0x101F
	static GetWindowLong      := A_PtrSize = 8 ? "GetWindowLongPtr" : "GetWindowLong"
	static SetWindowLong      := A_PtrSize = 8 ? "SetWindowLongPtr" : "SetWindowLong"
	static Init               := False
	static LV_Init            := False
	global IsDarkMode         := DarkMode
	global CheckboxControls   := []

	Mode_Explorer  := (DarkMode ? "DarkMode_Explorer"  : "Explorer" )
	Mode_CFD       := (DarkMode ? "DarkMode_CFD"       : "CFD"      )
	Mode_ItemsView := (DarkMode ? "DarkMode_ItemsView" : "ItemsView")

	; Clear previous checkbox tracking
	CheckboxControls := []

	for hWnd, GuiCtrlObj in GuiObj
	{
		switch GuiCtrlObj.Type
		{
			case "Button", "ListBox", "UpDown":
			{
				DllCall("uxtheme\SetWindowTheme", "Ptr", GuiCtrlObj.hWnd, "Str", Mode_Explorer, "Ptr", 0)
			}
			case "CheckBox":
			{
				; Track checkbox controls for custom drawing
				CheckboxControls.Push(GuiCtrlObj)
				
				; Try different theme approaches for checkboxes
				if (DarkMode) {
					; Method 1: Try forcing light theme on checkbox only
					DllCall("uxtheme\SetWindowTheme", "Ptr", GuiCtrlObj.hWnd, "Str", "", "Ptr", 0)
					
					; Method 2: Set custom colors via Windows messages
					; BM_SETCHECK can be used to refresh after color changes
					PostMessage(0x00F1, 0, 0, GuiCtrlObj.hWnd) ; BM_SETCHECK refresh
				} else {
					DllCall("uxtheme\SetWindowTheme", "Ptr", GuiCtrlObj.hWnd, "Str", Mode_Explorer, "Ptr", 0)
				}
			}
			case "ComboBox", "DDL":
			{
				DllCall("uxtheme\SetWindowTheme", "Ptr", GuiCtrlObj.hWnd, "Str", Mode_CFD, "Ptr", 0)
			}
			case "Edit":
			{
				if (DllCall("user32\" GetWindowLong, "Ptr", GuiCtrlObj.hWnd, "Int", GWL_STYLE) & ES_MULTILINE)
				{
					DllCall("uxtheme\SetWindowTheme", "Ptr", GuiCtrlObj.hWnd, "Str", Mode_Explorer, "Ptr", 0)
				}
				else
				{
					DllCall("uxtheme\SetWindowTheme", "Ptr", GuiCtrlObj.hWnd, "Str", Mode_CFD, "Ptr", 0)
				}
			}
			case "ListView":
			{
				if !(LV_Init)
				{
					static LV_TEXTCOLOR   := SendMessage(LVM_GETTEXTCOLOR,   0, 0, GuiCtrlObj.hWnd)
					static LV_TEXTBKCOLOR := SendMessage(LVM_GETTEXTBKCOLOR, 0, 0, GuiCtrlObj.hWnd)
					static LV_BKCOLOR     := SendMessage(LVM_GETBKCOLOR,     0, 0, GuiCtrlObj.hWnd)
					LV_Init := True
				}
				GuiCtrlObj.Opt("-Redraw")
				switch DarkMode
				{
					case True:
					{
						SendMessage(LVM_SETTEXTCOLOR,   0, DarkColors["Font"],       GuiCtrlObj.hWnd)
						SendMessage(LVM_SETTEXTBKCOLOR, 0, DarkColors["Background"], GuiCtrlObj.hWnd)
						SendMessage(LVM_SETBKCOLOR,     0, DarkColors["Background"], GuiCtrlObj.hWnd)
					}
					default:
					{
						SendMessage(LVM_SETTEXTCOLOR,   0, LV_TEXTCOLOR,   GuiCtrlObj.hWnd)
						SendMessage(LVM_SETTEXTBKCOLOR, 0, LV_TEXTBKCOLOR, GuiCtrlObj.hWnd)
						SendMessage(LVM_SETBKCOLOR,     0, LV_BKCOLOR,     GuiCtrlObj.hWnd)
					}
				}
				DllCall("uxtheme\SetWindowTheme", "Ptr", GuiCtrlObj.hWnd, "Str", Mode_Explorer, "Ptr", 0)
				
				LV_Header := SendMessage(LVM_GETHEADER, 0, 0, GuiCtrlObj.hWnd)
				DllCall("uxtheme\SetWindowTheme", "Ptr", LV_Header, "Str", Mode_ItemsView, "Ptr", 0)
				GuiCtrlObj.Opt("+Redraw")
			}
		}
	}

	if !(Init)
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
	static WM_DRAWITEM        := 0x002B
	static WM_MEASUREITEM     := 0x002C
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
				; Special handling for checkboxes
				ControlHwnd := lParam
				for ctrl in CheckboxControls {
					if (ctrl.hWnd == ControlHwnd) {
						; Force white text and dark background for checkbox
						DllCall("gdi32\SetTextColor", "Ptr", wParam, "UInt", 0xFFFFFF) ; White text
						DllCall("gdi32\SetBkColor", "Ptr", wParam, "UInt", DarkColors["Background"])
						DllCall("gdi32\SetDCBrushColor", "Ptr", wParam, "UInt", DarkColors["Background"], "UInt")
						return DllCall("gdi32\GetStockObject", "Int", DC_BRUSH, "Ptr")
					}
				}
				; Default button handling
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

