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

    ; --- Private Methods ---
    _LogError(caller, message) {
        FileAppend(FormatTime(, "yyyy-MM-dd HH:mm:ss") " ERROR [" caller "]: " message "`n", A_ScriptDir "\" Constants.ERROR_LOG)
    }
}
