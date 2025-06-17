/**
 * @Fileoverview JSON handler for AutoHotkey
 * @FileEncoding UTF-8[dos]
 * @Requirements AutoHotkey v1.1.x. Not confirmed to work on v2.0 or newer.
 * @Installation
 *   Use #Include %A_ScriptDir%\AhkJSON\Libs\Class_JSON.ahk or copy into your code
 * @License MIT
 * @Links
 *   cocobelgica (original) https://github.com/cocobelgica/AutoHotkey-JSON
 *   Tuckn (forked v2.1.3) https://github.com/tuckn/AhkJSON
 * @Author Tuckn
 * @Email tuckn333@gmail.com
 */

/**
 * @Class JSON
 * @Description The JSON object contains methods for parsing JSON and converting values to JSON.
 *   Callable - NO; Instantiable - YES; Subclassable - YES;
 *   Nestable(via #Include) - NO.
 * @Methods
 *   Parse(...) - see relevant documentation before method definition header
 *   Stringify(...) - see relevant documentation before method definition header
 *   ReadFile(...) - Read a JSON file
 *   WriteFile(...) - Write a JSON data to the file
 */
class JSON
{
  /**
   * @Method Parse
   * @Description Parses a JSON string into an AHK value {{{
   * @Syntax value := JSON.Parse(text[, reviver])
   * @Param {ByRef String} text JSON formatted string
   * @Param {Function} [reviver] function object, similar to JavaScript's JSON.parse() 'reviver' parameter
   * @Return {Object} parsed value
   */
  class Parse extends JSON.Functor
  {
    Call(self, ByRef text, reviver:="")
    {
      this.rev := IsObject(reviver) ? reviver : false
    ; Object keys(and array indices) are temporarily stored in arrays so that
    ; we can enumerate them in the order they appear in the document/text instead
    ; of alphabetically. Skip if no reviver function is specified.
      this.keys := this.rev ? {} : false

      static quot := Chr(34), bashq := "\" . quot
           , json_value := quot . "{[01234567890-tfn"
           , json_value_or_array_closing := quot . "{[]01234567890-tfn"
           , object_key_or_object_closing := quot . "}"

      key := ""
      is_key := false
      root := {}
      stack := [root]
      next := json_value
      pos := 0

      while ((ch := SubStr(text, ++pos, 1)) != "") {
        if InStr(" `t`r`n", ch)
          continue
        if !InStr(next, ch, 1)
          this.ParseError(next, text, pos)

        holder := stack[1]
        is_array := holder.IsArray

        if InStr(",:", ch) {
          next := (is_key := !is_array && ch == ",") ? quot : json_value

        } else if InStr("}]", ch) {
          ObjRemoveAt(stack, 1)
          next := stack[1]==root ? "" : stack[1].IsArray ? ",]" : ",}"

        } else {
          if InStr("{[", ch) {
          ; Check if Array() is overridden and if its return value has
          ; the 'IsArray' property. If so, Array() will be called normally,
          ; otherwise, use a custom base object for arrays
            static json_array := Func("Array").IsBuiltIn || ![].IsArray ? {IsArray: true} : 0

          ; sacrifice readability for minor(actually negligible) performance gain
            (ch == "{")
              ? ( is_key := true
                , value := {}
                , next := object_key_or_object_closing )
            ; ch == "["
              : ( value := json_array ? new json_array : []
                , next := json_value_or_array_closing )

            ObjInsertAt(stack, 1, value)

            if (this.keys)
              this.keys[value] := []

          } else {
            if (ch == quot) {
              i := pos
              while (i := InStr(text, quot,, i+1)) {
                value := StrReplace(SubStr(text, pos+1, i-pos-1), "\\", "\u005c")

                static tail := A_AhkVersion<"2" ? 0 : -1
                if (SubStr(value, tail) != "\")
                  break
              }

              if (!i)
                this.ParseError("'", text, pos)

                value := StrReplace(value,  "\/",  "/")
              , value := StrReplace(value, bashq, quot)
              , value := StrReplace(value,  "\b", "`b")
              , value := StrReplace(value,  "\f", "`f")
              , value := StrReplace(value,  "\n", "`n")
              , value := StrReplace(value,  "\r", "`r")
              , value := StrReplace(value,  "\t", "`t")

              pos := i ; update pos

              i := 0
              while (i := InStr(value, "\",, i+1)) {
                if !(SubStr(value, i+1, 1) == "u")
                  this.ParseError("\", text, pos - StrLen(SubStr(value, i+1)))

                uffff := Abs("0x" . SubStr(value, i+2, 4))
                if (A_IsUnicode || uffff < 0x100)
                  value := SubStr(value, 1, i-1) . Chr(uffff) . SubStr(value, i+6)
              }

              if (is_key) {
                key := value, next := ":"
                continue
              }

            } else {
              value := SubStr(text, pos, i := RegExMatch(text, "[\]\},\s]|$",, pos)-pos)

              static number := "number", integer :="integer"
              if value is %number%
              {
                if value is %integer%
                  value += 0
              }
              else if (value == "true" || value == "false")
                value := %value% + 0
              else if (value == "null")
                value := ""
              else
              ; we can do more here to pinpoint the actual culprit
              ; but that's just too much extra work.
                this.ParseError(next, text, pos, i)

              pos += i-1
            }

            next := holder==root ? "" : is_array ? ",]" : ",}"
          } ; If InStr("{[", ch) { ... } else

          is_array? key := ObjPush(holder, value) : holder[key] := value

          if (this.keys && this.keys.HasKey(holder))
            this.keys[holder].Push(key)
        }

      } ; while ( ... )

      return this.rev ? this.Walk(root, "") : root[""]
    }

    ParseError(expect, ByRef text, pos, len:=1)
    {
      static quot := Chr(34), qurly := quot . "}"

      line := StrSplit(SubStr(text, 1, pos), "`n", "`r").Length()
      col := pos - InStr(text, "`n",, -(StrLen(text)-pos+1))
      msg := Format("{1}`n`nLine:`t{2}`nCol:`t{3}`nChar:`t{4}"
      ,     (expect == "")     ? "Extra data"
          : (expect == "'")    ? "Unterminated string starting at"
          : (expect == "\")    ? "Invalid \escape"
          : (expect == ":")    ? "Expecting ':' delimiter"
          : (expect == quot)   ? "Expecting object key enclosed in double quotes"
          : (expect == qurly)  ? "Expecting object key enclosed in double quotes or object closing '}'"
          : (expect == ",}")   ? "Expecting ',' delimiter or object closing '}'"
          : (expect == ",]")   ? "Expecting ',' delimiter or array closing ']'"
          : InStr(expect, "]") ? "Expecting JSON value or array closing ']'"
          :                      "Expecting JSON value(string, number, true, false, null, object or array)"
      , line, col, pos)

      static offset := A_AhkVersion<"2" ? -3 : -4
      throw Exception(msg, offset, SubStr(text, pos, len))
    }

    Walk(holder, key)
    {
      value := holder[key]
      if IsObject(value) {
        for i, k in this.keys[value] {
          ; check if ObjHasKey(value, k) ??
          v := this.Walk(value, k)
          if (v != JSON.Undefined)
            value[k] := v
          else
            ObjDelete(value, k)
        }
      }

      return this.rev.Call(holder, key, value)
    }
  } ; }}}

  /**
   * @Method Stringify
   * @Description Converts an AHK value into a JSON string {{{
   * @Syntax str := JSON.Stringify(value[, replacer, space])
   * @Param {Object/String/Number} value any value(object, string, number)
   * @Param {Function} [replacer] function object, similar to JavaScript's JSON.stringify() 'replacer' parameter
   * @Param {Integer} [space] similar to JavaScript's JSON.stringify() 'space' parameter
   * @Return {String} JSON representation of an AHK value
   */
  class Stringify extends JSON.Functor
  {
    Call(self, value, replacer:="", space:="", escapeUnicode:=True)
    {
      this.rep := IsObject(replacer) ? replacer : ""

      this.gap := ""
      if (space) {
        static integer := "integer"
        if space is %integer%
          Loop, % ((n := Abs(space))>10 ? 10 : n)
            this.gap .= " "
        else
          this.gap := SubStr(space, 1, 10)

        this.indent := "`n"
      }

      return this.Str({"": value}, "", escapeUnicode)
    }

    Str(holder, key, escapeUnicode:=True)
    {
      value := holder[key]

      if (this.rep)
        value := this.rep.Call(holder, key, ObjHasKey(holder, key) ? value : JSON.Undefined)

      if IsObject(value) {
      ; Check object type, skip serialization for other object types such as
      ; ComObject, Func, BoundFunc, FileObject, RegExMatchObject, Property, etc.
        static type := A_AhkVersion<"2" ? "" : Func("Type")
        if (type ? type.Call(value) == "Object" : ObjGetCapacity(value) != "") {
          if (this.gap) {
            stepback := this.indent
            this.indent .= this.gap
          }

          is_array := value.IsArray
        ; Array() is not overridden, rollback to old method of
        ; identifying array-like objects. Due to the use of a for-loop
        ; sparse arrays such as '[1,,3]' are detected as objects({}).
          if (!is_array) {
            for i in value
              is_array := i == A_Index
            until !is_array
          }

          str := ""
          if (is_array) {
            Loop, % value.Length() {
              if (this.gap)
                str .= this.indent

              v := this.Str(value, A_Index, escapeUnicode)
              str .= (v != "") ? v . "," : "null,"
            }
          } else {
            colon := this.gap ? ": " : ":"
            for k in value {
              v := this.Str(value, k, escapeUnicode)
              if (v != "") {
                if (this.gap)
                  str .= this.indent

                str .= this.Quote(k, escapeUnicode) . colon . v . ","
              }
            }
          }

          if (str != "") {
            str := RTrim(str, ",")
            if (this.gap)
              str .= stepback
          }

          if (this.gap)
            this.indent := stepback

          return is_array ? "[" . str . "]" : "{" . str . "}"
        }

      } else { ; is_number ? value : "value"
          return ObjGetCapacity([value], 1)=="" ? value : this.Quote(value, escapeUnicode)
      }
    }

    Quote(string, escapeUnicode:=True)
    {
      static quot := Chr(34), bashq := "\" . quot

      if (string != "") {
        string := StrReplace(string,  "\",  "\\")
            ;; optional in ECMAScript
            ;, string := StrReplace(string,  "/",  "\/")
            , string := StrReplace(string, quot, bashq)
            , string := StrReplace(string, "`b",  "\b")
            , string := StrReplace(string, "`f",  "\f")
            , string := StrReplace(string, "`n",  "\n")
            , string := StrReplace(string, "`r",  "\r")
            , string := StrReplace(string, "`t",  "\t")

        if (escapeUnicode) {
          static rx_escapable := A_AhkVersion<"2"
              ? "O)[^\x20-\x7e]" : "[^\x20-\x7e]"
          while RegExMatch(string, rx_escapable, m)
            string := StrReplace(string, m.Value
                , Format("\u{1:04x}", Ord(m.Value)))
        }
      }

      return quot . string . quot
    }
  } ; }}}

  /**
   * @Property Undefined
   * @Description Proxy for 'undefined' type {{{
   * @Syntax undefined := JSON.Undefined
   * @Remarks
   *   For use with reviver and replacer functions since AutoHotkey does not
   *   have an 'undefined' type. Returning blank("") or 0 won't work since these
   *   can't be distnguished from actual JSON values. This leaves us with objects.
   *   Replacer() - the caller may return a non-serializable AHK objects such as
   *   ComObject, Func, BoundFunc, FileObject, RegExMatchObject, and Property to
   *   mimic the behavior of returning 'undefined' in JavaScript but for the sake
   *   of code readability and convenience, it's better to do 'return JSON.Undefined'.
   *   Internally, the property returns a ComObject with the variant type of VT_EMPTY.
   */
  Undefined[]
  {
    get {
      static empty := {}, vt_empty := ComObject(0, &empty, 1)
      return vt_empty
    }
  } ; }}}

  /**
   * @Method ReadFile
   * @Description Read a object form the JSON file.  {{{
   *   JSONファイルをSJIS-CRLFにすると日本語の値でもそのまま読める
   * @Syntax parsed := ReadFile(jsonPath)
   * @Param {String} jsonPath A file path of JSON
   * @Return {Object} A parsed object
   */
  class ReadFile extends JSON.Functor
  {
    Call(self, jsonPath)
    {
      FileRead, strJson, %jsonPath%

      if (!ErrorLevel) { ; Successfully loaded.
        parsedObj := JSON.Parse(strJson)
      } else {
        ; MsgBox, ERROR: Couldn't read from the JSON "%jsonPath%"!
        Return
      }

      Return %parsedObj%
    }
  } ; }}}

  /**
   * @Method WriteFile
   * @Description Write the object to a JSON file. {{{
   *   - JSON内に日本語をそのまま保存したい場合、codePointingをFalseにする
   *   - AHKにtrue、falseはなく、これらは"1"、"0"となる
   *   - 文字列"true"、"false"、"\d+" の"はJSON化されるにあたり除去される
  *  @Syntax val := WriteFile(obj, jsonPath)
   * @Param {Object} obj A Custom Object
   * @Param {String} jsonPath A file path of JSON
   * @Param {String} [escapeUnicode=True] ほ -> U+307B
   * @Return {Number} 0: Failed, 1: Success
   */
  class WriteFile extends JSON.Functor
  {
    Call(self, obj, jsonPath, escapeUnicode:=True)
    {
      ; JSON.Stringify(object, [replacer, space, escapeUnicode])
      stringified := JSON.Stringify(obj, , 4, escapeUnicode)

      ; Remove double quotes from Boolean. ex: "True" -> True
      stringified := RegExReplace(stringified, "i)""(true|false)""", "$1")
      ; @FIXME 全部数字の文字列を数値に変換すると問題があるため無しに
      ;stringified := RegExReplace(stringified, "i)""(true|false|\d+)""", "$1")

      if (FileExist(jsonPath)) {
        FileDelete, %jsonPath%
      }

      if (!ErrorLevel) { ; Successfully deleted.
        FileAppend, %stringified%, %jsonPath%
      } else {
        ; MsgBox, ERROR: Couldn't write on the JSON file "%jsonPath%"!
        Return False ; 0
      }

      Return True ; 1
    }
  } ; }}}

  class Functor
  {
    __Call(method, ByRef arg, args*)
    {
    ; When casting to Call(), use a new instance of the "function object"
    ; so as to avoid directly storing the properties(used across sub-methods)
    ; into the "function object" itself.
      if IsObject(method)
        return (new this).Call(method, arg, args*)
      else if (method == "")
        return (new this).Call(arg, args*)
    }
  }
} ; }}}

; vim:set foldmethod=marker commentstring=;%s :