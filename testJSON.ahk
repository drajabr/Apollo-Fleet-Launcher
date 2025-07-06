#Requires AutoHotkey v2.0

#Include ./lib/JSON.ahk

jsonText := FileRead("sample.json")
data := JSON.parse(jsonText, true, true) ; keepbooltype:=true, as_map:=true

; Access & modify
data["count"] += 1
data["enabled"] := data["enabled"] = JSON.true ? JSON.false : JSON.true
data["settings"]["theme"] := "light"

; Add new entry
data["newFeature"] := JSON.true

; Convert back to JSON string
newJson := JSON.stringify(data)

; Save to file
if FileExist("output.json")
    FileDelete("output.json")
FileAppend(newJson, "output.json")
