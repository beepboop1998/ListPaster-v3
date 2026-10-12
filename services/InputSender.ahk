/*
    InputSender.ahk
    Responsibility: the only place keystrokes are sent.
    Dependencies: none
*/
class InputSender {
    ; --- Public Methods ---
    TypeText(text) {
        if (text = "")
            return false
        try {
            SendText(text)          ; NOTE: AHK releases held Ctrl/Shift for the send and restores them after
            return true
        } catch Error as e {
            this._LogError(A_ThisFunc, e.Message)
            return false
        }
    }

    PressKeys(keys) {
        if (keys = "")
            return true             ; nothing to press (advance mode None)
        try {
            SendInput(keys)
            return true
        } catch Error as e {
            this._LogError(A_ThisFunc, e.Message)
            return false
        }
    }

    ; Waits until the shortcut's keys are up, both physically and as Windows sees them. False if any key is still
    ; down after timeoutS (per key).
    WaitForKeysUp(hotkey, timeoutS) {
        try {
            for key in this.KeysToRelease(hotkey) {
                if (!KeyWait(key, "T" timeoutS) || !KeyWait(key, "L T" timeoutS))
                    return false
            }
            return true
        } catch Error as e {
            this._LogError(A_ThisFunc, e.Message)
            return false
        }
    }

    ; Pure: every modifier plus the shortcut's own key, e.g. "$^+v" -> Ctrl, Alt, Shift, LWin, RWin, v.
    KeysToRelease(hotkey) {
        keys := ["Ctrl", "Alt", "Shift", "LWin", "RWin"]
        mainKey := RegExReplace(hotkey, "[\^!+#*~$<>]")
        if (mainKey != "" && !InStr(mainKey, " "))
            keys.Push(mainKey)
        return keys
    }

    ; --- Private Methods ---
    _LogError(caller, message) {
        FileAppend(FormatTime(, "yyyy-MM-dd HH:mm:ss") " ERROR [" caller "]: " message "`n", A_ScriptDir "\" Constants.ERROR_LOG)
    }
}
