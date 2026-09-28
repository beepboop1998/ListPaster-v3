/*
    DeliveryService.ahk
    Responsibility: put an item into the focused field (type or paste), press the advance key, and erase it again for Undo.
    Dependencies: InputSender, ClipboardService, TimingEngine, Settings
*/
class DeliveryService {
    ; --- Properties ---
    _sender := ""           ; InputSender
    _clip := ""             ; ClipboardService
    _timer := ""            ; TimingEngine
    _prefs := ""            ; Settings
    _snapshot := ""         ; clip.Save() result from the start of a Paste-mode burst ("" if none or failed)
    _hasSnapshot := false
    _snapshotChanges := 0   ; clip.ExternalChangeCount() when _snapshot was taken
    _restoreFn := ""        ; BoundFunc -> _RestoreSnapshot

    ; --- Constructor ---
    __New(sender, clip, timer, prefs) {
        for dep in [sender, clip, timer, prefs] {
            if !IsObject(dep)
                throw Error("Missing dependency", A_ThisFunc)
        }
        this._sender := sender
        this._clip := clip
        this._timer := timer
        this._prefs := prefs
        this._restoreFn := ObjBindMethod(this, "_RestoreSnapshot")
    }

    ; --- Public Methods ---
    ; Returns a delivery record for Erase(), or "" on failure (caller must NOT advance the position).
    Deliver(text, advanceMode, deliveryMode) {
        advanceKey := Constants.ADVANCE_KEYS[advanceMode]
        record := {text: text, advance: advanceMode, mode: deliveryMode, app: this._DetectApp(), hwnd: WinExist("A")}
        ok := (deliveryMode = "Paste") ? this._PasteText(text, advanceKey) : this._TypeText(text, advanceKey)
        return ok ? record : ""
    }

    ; Returns {erased: true/false, reason: String}. reason "window" = caller must refuse the undo.
    Erase(record) {
        if (WinExist("A") != record.hwnd)
            return {erased: false, reason: "window"}
        if InStr(record.text, "`t")
            return {erased: false, reason: "item contains tabs"}
        keys := this._UndoKeys(record)
        if (keys = "")
            return {erased: false, reason: "Enter may have submitted"}
        if !this._sender.PressKeys(keys)
            return {erased: false, reason: "key send failed"}
        return {erased: true, reason: ""}
    }

    ; --- Private Methods ---
    _TypeText(text, advanceKey) {
        if !this._sender.TypeText(text)
            return false
        this._sender.PressKeys(advanceKey)          ; "" = no-op; failures are logged by InputSender
        return true
    }

    _PasteText(text, advanceKey) {
        ; Snapshot once per burst; re-snapshot if the user copied something since, so their newest copy is restored.
        if (!this._hasSnapshot || this._clip.ExternalChangeCount() != this._snapshotChanges) {
            this._snapshot := this._clip.Save()
            this._snapshotChanges := this._clip.ExternalChangeCount()
            this._hasSnapshot := true
        }
        this._clip.BeginSelfWrite()
        try {
            if !this._clip.SetText(text)
                return false
            Sleep(this._prefs.Get("PastePreDelayMs"))   ; lets RDP/VDI clipboard sync catch up before ^v
            if !this._sender.PressKeys("^v")
                return false
            Sleep(this._prefs.Get("PastePostDelayMs"))  ; target app reads the clipboard before anything changes it
            this._sender.PressKeys(advanceKey)
            return true
        } finally {
            this._clip.EndSelfWrite()
            this._timer.After("clipRestore", Constants.CLIP_RESTORE_IDLE_MS, this._restoreFn)
        }
    }

    _RestoreSnapshot() {
        if !this._hasSnapshot
            return
        snapshot := this._snapshot
        userCopied := (this._clip.ExternalChangeCount() != this._snapshotChanges)
        this._snapshot := ""
        this._hasSnapshot := false
        if (userCopied || !IsObject(snapshot))
            return                                      ; keep the user's newer clipboard, or nothing to restore
        this._clip.BeginSelfWrite()
        this._clip.Restore(snapshot)
        this._clip.EndSelfWrite()
    }

    _DetectApp() {
        try {
            for winTitle in Constants.SHEET_WINDOWS {
                if WinActive(winTitle)
                    return "sheet"
            }
        } catch Error as e {
            this._LogError(A_ThisFunc, e.Message)
        }
        return "other"
    }

    _UndoKeys(record) {
        n := StrLen(record.text)
        if (record.app = "sheet") {
            switch record.advance {
                case "Tab":
                    return "+{Tab}{Delete}"
                case "Enter":
                    return "{Up}{Delete}"
                default:
                    return (record.mode = "Paste") ? "{Delete}" : "{Esc}"
            }
        }
        switch record.advance {
            case "Tab":
                return "+{Tab}{End}{BS " n "}"
            case "Enter":
                return ""                               ; unknown app: Enter may have submitted
            default:
                return "{BS " n "}"
        }
    }

    _LogError(caller, message) {
        FileAppend(FormatTime(, "yyyy-MM-dd HH:mm:ss") " ERROR [" caller "]: " message "`n", A_ScriptDir "\" Constants.ERROR_LOG)
    }
}
