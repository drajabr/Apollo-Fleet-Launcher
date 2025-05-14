scGui := Gui(, "Sound Components")
scLV := scGui.Add('ListView', "w600 h400"
    , ["Component", "#", "Device", "Volume", "Mute"])

devMap := Map()

loop
{
    ; For each loop iteration, try to get the corresponding device.
    try
        devName := SoundGetName(, dev := A_Index)
    catch  ; No more devices.
        break
    
    ; Retrieve master volume and mute setting, if possible.
    vol := mute := ""
    try vol := Round(SoundGetVolume( , dev), 2)
    try mute := SoundGetMute( , dev)
    
    ; Display the master settings only if at least one was retrieved.
    if vol != "" || mute != ""
        scLV.Add("", "", dev, devName, vol, mute)
}

loop 5
    scLV.ModifyCol(A_Index, 'AutoHdr Logical')
scGui.Show()

; Qualifies full names with ":index" when needed.
Qualify(name, names, overallIndex)
{
    if name = ''
        return overallIndex
    key := StrLower(name)
    index := names.Has(key) ? ++names[key] : (names[key] := 1)
    return (index > 1 || InStr(name, ':') || IsInteger(name)) ? name ':' index : name
}
