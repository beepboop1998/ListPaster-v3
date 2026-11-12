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

    ; Pure: the shortcut's own key without its modifiers, e.g. "$^+v" -> "v". "" unless there is exactly one key.
    MainKey(hotkey) {
        mainKey := RegExReplace(hotkey, "[\^!+#*~$<>]")
        return InStr(mainKey, " ") ? "" : mainKey
    }

    ; Waits until the shortcut's own key is physically up. True at once when there is none; false if it is still
    ; down after timeoutS or the key name is unknown.
    WaitForMainKeyUp(hotkey, timeoutS) {
        mainKey := this.MainKey(hotkey)
        if (mainKey = "")
            return true
        try {
            return KeyWait(mainKey, "T" timeoutS) ? true : false
        } catch Error as e {
            this._LogError(A_ThisFunc, e.Message)
            return false
        }
    }

    ; Pure: every modifier plus the shortcut's own key, e.g. "$^+v" -> Ctrl, Alt, Shift, LWin, RWin, v.
    KeysToRelease(hotkey) {
        keys := ["Ctrl", "Alt", "Shift", "LWin", "RWin"]
        mainKey := this.MainKey(hotkey)
        if (mainKey != "")
            keys.Push(mainKey)
        return keys
    }

    ; --- Private Methods ---
    _LogError(caller, message) {
        line := FormatTime(, "yyyy-MM-dd HH:mm:ss") " ERROR [" caller "]: " message "`n"
        try {
            FileAppend(line, A_ScriptDir "\" Constants.ERROR_LOG)
        } catch Error {
            OutputDebug(Constants.APP_NAME " (error.log not writable) " line)   ; NOTE: runs inside catch blocks, so it must never throw
        }
    }
}
