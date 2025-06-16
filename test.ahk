#Include ./lib/_JXON.ahk

jsonFile := "C:\Program Files\Apollo\config\apps.json"

text := FileRead(jsonFile)
jsonData := JXON_Load(&text)

for app in jsonData["apps"]
    if app.Has("name")
        if app["name"] == "Desktop"
            if app.Has("terminate-on-pause")
                app["terminate-on-pause"] := !app["terminate-on-pause"]
            else
                MsgBox("Please Upgrade to latest Apollo Version")
        else
            continue
    else
        MsgBox("Apps.json file is corrupted, please clean install Apollo")
    
text := Jxon_Dump(jsonData, "4")	; save default apps file for synced instances
FileAppend(text, "my.json", "UTF-8")