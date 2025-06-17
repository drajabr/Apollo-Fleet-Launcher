#Requires AutoHotkey v2.0

#Include ./lib/jsongo.v2.ahk


text := FileRead("test.json")
obj := jsongo.Parse(text)

for index, value in obj['apps']{
    MsgBox("App: " index "`nName: " value['name'] '`nterminate-on-pause: ' value['terminate-on-pause'])
    value['terminate-on-pause'] := value['terminate-on-pause'] ? "false" : "true"
}

text := jsongo.Stringify(obj, , '    ')

text := RegExReplace(text, ':\s*"true"', ': true')
text := RegExReplace(text, ':\s*"false"', ': false')
if FileExist("testOut.json")
    FileDelete("testOut.json")
FileAppend(text, "testOut.json")