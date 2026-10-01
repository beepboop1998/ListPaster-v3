/*
    Notifier.ahk
    Responsibility: user-facing messages: tooltips (hidden later via TimingEngine), yes/no questions and alerts.
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

    ; Yes/No question, No is the default. Returns true only for Yes (false if the box can't be shown).
    ; NOTE: 262144 = always on top, so the box can't open hidden behind the app being pasted into.
    Confirm(question) {
        try {
            return MsgBox(question, Constants.APP_NAME, "YesNo Icon? Default2 262144") = "Yes"
        } catch Error as e {
            this._LogError(A_ThisFunc, e.Message)
            return false
        }
    }

    Alert(message) {
        try {
            MsgBox(message, Constants.APP_NAME, "Iconi 262144")
        } catch Error as e {
            this._LogError(A_ThisFunc, e.Message)
        }
    }

    ; --- Private Methods ---
    _Hide() {
        ToolTip()
    }

    _LogError(caller, message) {
        FileAppend(FormatTime(, "yyyy-MM-dd HH:mm:ss") " ERROR [" caller "]: " message "`n", A_ScriptDir "\" Constants.ERROR_LOG)
    }
}
