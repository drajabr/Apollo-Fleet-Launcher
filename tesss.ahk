#Include ./lib/DarkGuiHelpers.ahk
Gui.Prototype.DefineProp("AddDarkCheckBox", {Call: AddDarkCheckBox})
myGui := Gui()
myGui.BackColor := "1F1F1F"
myGui.SetFont("s10 cF8F8F8", "Segoe UI")

chk := myGui.AddDarkCheckBox("x20 y20 vMyOption", "Use Dark Checkbox")
chk.OnEvent("Click", (*) => MsgBox("Value: " chk.Value))

myGui.Show()
