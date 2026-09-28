/*
    Notifier.ahk
    Responsibility: shows a tooltip and hides it later via TimingEngine.
    Dependencies: TimingEngine
*/
class Notifier {
    ; --- Properties ---
    _timer := ""      ; TimingEngine
    _hideFn := ""     ; BoundFunc -> _Hide

    ; --- Constructor ---
    __New(timer) {
        if !IsObject(timer)
            throw Error("timer is required", A_ThisFunc)
        this._timer := timer
        this._hideFn := ObjBindMethod(this, "_Hide")
    }

    ; --- Public Methods ---
    Show(message, durationMs := 0) {        ; 0 = Constants.TIP_MS (v2.0 defaults must be literals)
        if (durationMs <= 0)
            durationMs := Constants.TIP_MS
        try {
            ToolTip(message)
        } catch Error as e {
            this._LogError(A_ThisFunc, e.Message)
            return
        }
        this._timer.After("tipHide", durationMs, this._hideFn)
    }

    ; --- Private Methods ---
    _Hide() {
        ToolTip()
    }

    _LogError(caller, message) {
        FileAppend(FormatTime(, "yyyy-MM-dd HH:mm:ss") " ERROR [" caller "]: " message "`n", A_ScriptDir "\" Constants.ERROR_LOG)
    }
}
