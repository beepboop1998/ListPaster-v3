/*
    ClipboardService.ahk
    Responsibility: all clipboard reads/writes, change monitoring, and telling ListPaster's own writes apart from the user's.
    Dependencies: none
*/
class ClipboardService {
    ; --- Properties ---
    _ownSeq := -1           ; Windows clipboard sequence number right after ListPaster's last write
    _externalChanges := 0   ; clipboard changes NOT made by this script
    _onTextFn := ""         ; callable(text), set by StartMonitoring
    _changeFn := ""         ; BoundFunc -> _OnChange
    _privateFormats := ""   ; Array of format IDs that keep an item out of clipboard history and cloud sync

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

    ; Puts text on the clipboard, marked so Windows clipboard history (Win+V) and cloud sync skip it.
    SetText(text) {
        wasCritical := A_IsCritical
        Critical                                          ; nothing may run between the write and recording it as ours
        try {
            A_Clipboard := ""
            A_Clipboard := ClipboardAll(this._PrivateTextBuffer(text))
            if !ClipWait(Constants.CLIP_WAIT_S)
                throw Error("Clipboard did not update", A_ThisFunc)
            this._MarkOwnWrite()
            return true
        } catch Error as e {
            this._LogError(A_ThisFunc, e.Message)
            return false
        } finally {
            Critical(wasCritical)
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

    Restore(saved) {
        if !IsObject(saved)
            return false
        wasCritical := A_IsCritical
        Critical
        try {
            A_Clipboard := saved
            this._MarkOwnWrite()
            return true
        } catch Error as e {
            this._LogError(A_ThisFunc, e.Message)
            return false
        } finally {
            Critical(wasCritical)
        }
    }

    ; Windows increments this number on every clipboard change, whoever makes it.
    SequenceNumber() {
        try {
            return DllCall("user32\GetClipboardSequenceNumber", "UInt")
        } catch Error as e {
            this._LogError(A_ThisFunc, e.Message)
            return 0
        }
    }

    ; --- Private Methods ---
    _MarkOwnWrite() {
        this._ownSeq := this.SequenceNumber()
    }

    ; NOTE: callbacks for ListPaster's own writes arrive after the writing thread ends. If the sequence number
    ; still matches the one recorded after that write, nobody else has touched the clipboard since.
    _OnChange(dataType) {
        if (this.SequenceNumber() = this._ownSeq)
            return                                        ; still ListPaster's own write
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

    ; ClipboardAll layout: [UInt format][UInt size][data] repeated, then a UInt 0.
    _PrivateTextBuffer(text) {
        if !IsObject(this._privateFormats)
            this._privateFormats := this._RegisterPrivateFormats()
        textBytes := (StrLen(text) + 1) * 2               ; UTF-16 plus terminator
        buf := Buffer(8 + textBytes + this._privateFormats.Length * 12 + 4, 0)
        NumPut("UInt", 13, "UInt", textBytes, buf, 0)     ; 13 = CF_UNICODETEXT
        StrPut(text, buf.Ptr + 8, "UTF-16")
        offset := 8 + textBytes
        for formatId in this._privateFormats {
            NumPut("UInt", formatId, "UInt", 4, "UInt", 0, buf, offset)   ; DWORD 0 = don't record / don't sync
            offset += 12
        }
        NumPut("UInt", 0, buf, offset)
        return buf
    }

    _RegisterPrivateFormats() {
        ids := []
        for name in ["ExcludeClipboardContentFromMonitorProcessing", "CanIncludeInClipboardHistory", "CanUploadToCloudClipboard"] {
            try {
                id := DllCall("RegisterClipboardFormat", "Str", name, "UInt")
                if id
                    ids.Push(id)
            } catch Error as e {
                this._LogError(A_ThisFunc, name ": " e.Message)
            }
        }
        return ids
    }

    _LogError(caller, message) {
        FileAppend(FormatTime(, "yyyy-MM-dd HH:mm:ss") " ERROR [" caller "]: " message "`n", A_ScriptDir "\" Constants.ERROR_LOG)
    }
}
