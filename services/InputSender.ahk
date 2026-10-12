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
        this._WaitForModifiersUp()
        try {
            SendText(text)
            return true
        } catch Error as e {
            this._LogError(A_ThisFunc, e.Message)
            return false
        }
    }

    PressKeys(keys) {
        if (keys = "")
            return true             ; nothing to press (advance mode None)
        this._WaitForModifiersUp()
        try {
            SendInput(keys)
            return true
        } catch Error as e {
            this._LogError(A_ThisFunc, e.Message)
            return false
        }
    }

    ; --- Private Methods ---
    ; Send releases held modifiers and presses them down again afterwards. If the user lets go in between
    ; (likelier with another script's keyboard hook or a remote desktop client), they stay stuck down.
    ; So wait for the hotkey's modifiers to come up first; after the timeout, send anyway.
    _WaitForModifiersUp() {
        deadline := A_TickCount + Constants.MODIFIER_WAIT_MS
        try {
            for key in Constants.HOTKEY_MODIFIERS {
                remaining := deadline - A_TickCount
                if (remaining <= 0 || !KeyWait(key, "T" remaining / 1000))
                    return
            }
        } catch Error as e {
            this._LogError(A_ThisFunc, e.Message)
        }
    }

    _LogError(caller, message) {
        FileAppend(FormatTime(, "yyyy-MM-dd HH:mm:ss") " ERROR [" caller "]: " message "`n", A_ScriptDir "\" Constants.ERROR_LOG)
    }
}
