/*
    ClipboardService.ahk
    Responsibility: all clipboard reads/writes, change monitoring, and ignoring the script's own writes.
    Dependencies: none
*/
class ClipboardService {
    ; --- Properties ---
    _suppressUntil := 0     ; A_TickCount before which change events are ignored (our own writes)
    _externalChanges := 0   ; clipboard changes NOT made by this script
    _onTextFn := ""         ; callable(text), set by StartMonitoring
    _changeFn := ""         ; BoundFunc -> _OnChange

    ; --- Constructor ---
    __New() {
        this._changeFn := ObjBindMethod(this, "_OnChange")
        if !HasMethod(this._changeFn)
            throw Error("Failed to bind clipboard callback", A_ThisFunc)
    }

    ; --- Public Methods ---
    StartMonitoring(onTextFn) {
        if !HasMethod(onTextFn)
            throw Error("onTextFn is not callable", A_ThisFunc)
        this._onTextFn := onTextFn
        try {
            OnClipboardChange(this._changeFn)
        } catch Error as e {
            this._LogError(A_ThisFunc, e.Message)
        }
    }

    ExternalChangeCount() {
        return this._externalChanges
    }

    ReadText() {
        try {
            return A_Clipboard
        } catch Error as e {
            this._LogError(A_ThisFunc, e.Message)
            return ""
        }
    }

    ; Caller must wrap in BeginSelfWrite / EndSelfWrite.
    SetText(text) {
        try {
            A_Clipboard := ""
            A_Clipboard := text
            if !ClipWait(Constants.CLIP_WAIT_S)
                throw Error("Clipboard did not update", A_ThisFunc)
            return true
        } catch Error as e {
            this._LogError(A_ThisFunc, e.Message)
            return false
        }
    }

    ; Returns a ClipboardAll object, or "" on failure.
    Save() {
        try {
            return ClipboardAll()
        } catch Error as e {
            this._LogError(A_ThisFunc, e.Message)
            return ""
        }
    }

    ; Caller must wrap in BeginSelfWrite / EndSelfWrite.
    Restore(saved) {
        if !IsObject(saved)
            return false
        try {
            A_Clipboard := saved
            return true
        } catch Error as e {
            this._LogError(A_ThisFunc, e.Message)
            return false
        }
    }

    BeginSelfWrite() {
        this._suppressUntil := A_TickCount + 60000        ; closed by EndSelfWrite
    }

    EndSelfWrite() {
        this._suppressUntil := A_TickCount + Constants.CLIP_SUPPRESS_MS
    }

    ; --- Private Methods ---
    _OnChange(dataType) {
        if (A_TickCount < this._suppressUntil)
            return                                        ; our own write
        this._externalChanges += 1
        if (dataType != 1)
            return                                        ; not text
        text := this.ReadText()
        if (text = "")
            return
        try {
            this._onTextFn.Call(text)
        } catch Error as e {
            this._LogError(A_ThisFunc, e.Message)
        }
    }

    _LogError(caller, message) {
        FileAppend(FormatTime(, "yyyy-MM-dd HH:mm:ss") " ERROR [" caller "]: " message "`n", A_ScriptDir "\" Constants.ERROR_LOG)
    }
}
