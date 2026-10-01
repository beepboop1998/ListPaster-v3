/*
    WindowProbe.ahk
    Responsibility: read-only facts about the active window for DeliveryService (handle, process, class, focused control).
    Dependencies: none
*/
class WindowProbe {
    ; --- Public Methods ---
    ActiveWindow() {
        try {
            return WinExist("A")
        } catch Error as e {
            this._LogError(A_ThisFunc, e.Message)
            return 0
        }
    }

    ; {hwnd, pid, cls, exe} for the active window, or "" if there is none. exe is "" when it can't be read.
    ActiveInfo() {
        hwnd := this.ActiveWindow()
        if !hwnd
            return ""
        try {
            info := {hwnd: hwnd, pid: WinGetPID(hwnd), cls: WinGetClass(hwnd), exe: ""}
        } catch Error as e {
            this._LogError(A_ThisFunc, e.Message)
            return ""
        }
        try {
            info.exe := WinGetProcessName(hwnd)
        } catch Error as e {
            this._LogError(A_ThisFunc, "process name: " e.Message)
        }
        return info
    }

    OwnPid() => ProcessExist()

    IsActive(winTitle) {
        try {
            return WinActive(winTitle) ? true : false
        } catch Error as e {
            this._LogError(A_ThisFunc, e.Message)
            return false
        }
    }

    ; Focused control of the active window, or 0 when unknown.
    FocusedControl() {
        try {
            return ControlGetFocus("A")
        } catch Error as e {
            this._LogError(A_ThisFunc, e.Message)
            return 0
        }
    }

    ; --- Private Methods ---
    _LogError(caller, message) {
        FileAppend(FormatTime(, "yyyy-MM-dd HH:mm:ss") " ERROR [" caller "]: " message "`n", A_ScriptDir "\" Constants.ERROR_LOG)
    }
}
