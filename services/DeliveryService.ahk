/*
    DeliveryService.ahk
    Responsibility: put an item into the focused field (type or paste), press the advance key, and erase it again for Undo.
    Dependencies: InputSender, ClipboardService, TimingEngine, Settings, WindowProbe
*/
class DeliveryService {
    ; --- Properties ---
    _sender := ""           ; InputSender
    _clip := ""             ; ClipboardService
    _timer := ""            ; TimingEngine
    _prefs := ""            ; Settings
    _probe := ""            ; WindowProbe
    _snapshot := ""         ; clip.Save() result from the start of a Paste-mode burst ("" if none or failed)
    _hasSnapshot := false
    _snapshotChanges := 0   ; clip.ExternalChangeCount() when _snapshot was taken
    _restoreFn := ""        ; BoundFunc -> _RestoreSnapshot

    ; --- Constructor ---
    __New(sender, clip, timer, prefs, probe) {
        for dep in [sender, clip, timer, prefs, probe] {
            if !IsObject(dep)
                throw Error("Missing dependency", A_ThisFunc)
        }
        this._sender := sender
        this._clip := clip
        this._timer := timer
        this._prefs := prefs
        this._probe := probe
        this._restoreFn := ObjBindMethod(this, "_RestoreSnapshot")
    }

    ; --- Public Methods ---
    ; "" when the active window is a fine place to paste; otherwise a message for the user.
    TargetProblem() {
        if (this.ClassifyTarget(this._probe.ActiveInfo(), this._probe.OwnPid()) = "")
            return ""
        return "Click into the field you want to fill first."
    }

    ; Pure: "" = fine, "none" = no active window, "self" = a ListPaster window or menu, "shell" = taskbar/Start/desktop.
    ClassifyTarget(info, ownPid) {
        if (!IsObject(info) || !info.hwnd)
            return "none"
        if (info.pid = ownPid)
            return "self"
        for cls in Constants.SHELL_CLASSES {
            if (info.cls = cls && (info.exe = "" || info.exe = "explorer.exe"))
                return "shell"
        }
        for name in Constants.SHELL_PROCESSES {
            if (info.exe = name)
                return "shell"
        }
        return ""
    }

    ; Returns a delivery record for Erase(), or "" on failure (caller must NOT advance the position).
    Deliver(text, advanceMode, deliveryMode) {
        advanceKey := Constants.ADVANCE_KEYS[advanceMode]
        record := {text: text, advance: advanceMode, mode: deliveryMode}
        record.app := this._DetectApp()
        record.hwnd := this._probe.ActiveWindow()
        record.focusCtrl := 0                       ; 0 = unknown: Undo skips the field check
        ok := (deliveryMode = "Paste") ? this._PasteText(text, advanceKey) : this._TypeText(text, advanceKey)
        if !ok
            return ""
        ; NOTE: read the focused field a moment later, once the app has acted on Tab/Enter
        this._timer.After("focusRecord", Constants.FOCUS_RECORD_DELAY_MS, () => record.focusCtrl := this._probe.FocusedControl())
        return record
    }

    ; Returns {erased: true/false, reason: String}. reason "window" = caller must refuse the undo.
    Erase(record) {
        if (this._probe.ActiveWindow() != record.hwnd)
            return {erased: false, reason: "window"}
        current := this._probe.FocusedControl()
        if (record.focusCtrl && current && current != record.focusCtrl)
            return {erased: false, reason: "you moved to another field"}
        if InStr(record.text, "`t")
            return {erased: false, reason: "item contains tabs"}
        keys := this._UndoKeys(record)
        if (keys = "")
            return {erased: false, reason: "Enter may have submitted"}
        if !this._sender.PressKeys(keys)
            return {erased: false, reason: "key send failed"}
        return {erased: true, reason: ""}
    }

    ; Applies a pending clipboard restore right away (on Exit, and before Load from clipboard reads it).
    RestoreNow() {
        this._timer.Cancel("clipRestore")
        this._RestoreSnapshot()
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
        this._clip.Restore(snapshot)
    }

    _DetectApp() {
        for winTitle in Constants.SHEET_WINDOWS {
            if this._probe.IsActive(winTitle)
                return "sheet"
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
