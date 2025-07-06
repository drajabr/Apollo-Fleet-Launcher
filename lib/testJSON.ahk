#Requires AutoHotkey v2.0
#Include JSON.ahk

; Create the 3 boolean variables
jsonBool1 := JSON.true
jsonBool2 := JSON.false
ahkBool := true

; Compare them
if (jsonBool1 == JSON.true && jsonBool2 == JSON.false && ahkBool == true) {
    MsgBox("All booleans match expected values")
}

; Check if any are truthy
if (jsonBool1 && !jsonBool2 && ahkBool) {
    MsgBox("Truthiness check passed")
}

; Direct comparison
MsgBox("jsonBool1 == ahkBool: " . (jsonBool1 == ahkBool))
MsgBox("jsonBool2 == ahkBool: " . (jsonBool2 == ahkBool))