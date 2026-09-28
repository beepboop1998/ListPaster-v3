#Requires AutoHotkey v2.0
#SingleInstance Force

; ListPaster: copy a list (2+ lines), then each hotkey press types the next line.
;
; Hotkeys:
;   (auto)        copying any multi-line text loads it as the list
;   Ctrl+Shift+V  paste next item
;   Ctrl+Alt+B    step back one (next paste repeats previous item)
;   Ctrl+Alt+R    restart at top of list
;   Ctrl+Alt+L    force-load clipboard as list (use for a 1-line list)
;
; NOTE: items are typed with SendText, not pasted via clipboard, so the
;       clipboard is never touched and apps can't grab a stale item.

class ListPaster {
    ; --- Properties ---
    _items := []   ; Array of strings
    _index := 0    ; Items pasted so far

    ; --- Public Methods ---
    OnClip(dataType) {
        if (dataType != 1)                 ; guard: text only
            return
        this._Parse(this._ReadClipboard(), false)
    }

    Load() {
        this._Parse(this._ReadClipboard(), true)
    }

    PasteNext() {
        if !this._items.Length {
            this._Tip("No list loaded. Copy a multi-line list first")
            return
        }
        if (this._index >= this._items.Length) {
            this._Tip("End of list (Ctrl+Alt+R to restart)")
            return
        }
        item := this._items[this._index + 1]
        try {
            SendText item
        } catch Error as e {
            this._LogError(A_ThisFunc, e.Message)
            this._Tip("Paste failed, see error.log")
            return
        }
        this._index++
        this._Tip(this._index " / " this._items.Length ":  " item)
    }

    Back() {
        if (this._index <= 0)
            return
        this._index--
        this._Tip("Next paste: item " this._index + 1)
    }

    Reset() {
        this._index := 0
        this._Tip("Back to top")
    }

    ; --- Private Methods ---
    _Parse(text, manual) {
        if (text = "")
            return
        items := []
        for line in StrSplit(text, "`n", "`r") {
            if (Trim(line) != "")          ; skip blank lines
                items.Push(line)
        }
        if (!manual && items.Length < 2)   ; guard: normal single-line copies don't replace the list
            return
        if !items.Length
            return
        this._items := items
        this._index := 0
        this._Tip("Loaded " items.Length " items")
    }

    _ReadClipboard() {
        try {
            return A_Clipboard
        } catch Error as e {
            this._LogError(A_ThisFunc, e.Message)
            return ""
        }
    }

    _Tip(msg) {
        ToolTip msg
        SetTimer () => ToolTip(), -1500
    }

    _LogError(caller, message) {
        FileAppend(FormatTime(, "yyyy-MM-dd HH:mm:ss") " ERROR [" caller "]: " message "`n", A_ScriptDir "\error.log")
    }
}

paster := ListPaster()
OnClipboardChange(ObjBindMethod(paster, "OnClip"))

^+v:: paster.PasteNext()
^!b:: paster.Back()
^!r:: paster.Reset()
^!l:: paster.Load()
