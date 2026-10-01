/*
    ListStore.ahk
    Responsibility: when "Remember list after exit" is on, save the list and position (debounced, atomic) and resume
                    them at startup; when it's off, keep nothing on disk.
    Dependencies: ItemList, TimingEngine, Notifier, Settings
*/
class ListStore {
    ; --- Properties ---
    _items := ""          ; ItemList
    _timer := ""          ; TimingEngine
    _tips := ""           ; Notifier
    _prefs := ""          ; Settings
    _listPath := ""       ; full path of data\list.txt
    _sessionPath := ""    ; full path of data\session.ini
    _listDirty := false   ; list content changed since last write
    _saveFn := ""         ; BoundFunc -> _Save

    ; --- Constructor ---
    __New(items, timer, tips, prefs, listPath, sessionPath) {
        for dep in [items, timer, tips, prefs] {
            if !IsObject(dep)
                throw Error("Missing dependency", A_ThisFunc)
        }
        if (listPath = "" || sessionPath = "")
            throw Error("File paths are required", A_ThisFunc)
        this._items := items
        this._timer := timer
        this._tips := tips
        this._prefs := prefs
        this._listPath := listPath
        this._sessionPath := sessionPath
        this._saveFn := ObjBindMethod(this, "_Save")
    }

    ; --- Public Methods ---
    Resume() {
        lines := []
        position := 0
        if FileExist(this._listPath) {
            try {
                lines := this._items.ParseLines(FileRead(this._listPath, "UTF-8"))
                raw := IniRead(this._sessionPath, "Session", "Position", "0")
                position := RegExMatch(raw, "^\d{1,7}$") ? Integer(raw) : 0
            } catch Error as e {
                this._LogError(A_ThisFunc, e.Message)
            }
        }
        if lines.Length
            this._items.Restore(lines, position)        ; clamps to 0..Count
        if this._Remember() {
            if lines.Length
                this._tips.Show("Resumed " this._items.GetPosition() "/" this._items.GetCount())
            return
        }
        ; NOTE: Remember is off, so nothing may stay on disk. A list saved earlier (e.g. by v3.0) is never
        ; deleted unread: it is loaded into this session first, then removed, and the user is told once.
        this._DeleteFiles()
        if lines.Length {
            done := this._items.GetPosition() " of " this._items.GetCount() " done"
            this._tips.Alert("ListPaster no longer keeps lists on disk unless you turn on 'Remember list after exit' in the tray menu.`n`nThe list saved earlier (" done ") is loaded for this session, and the saved copy has been deleted.")
        }
    }

    OnListChanged(kind) {
        if (kind = Constants.KIND_RESUME)
            return                                      ; state just came from disk
        if (kind = Constants.KIND_LOAD || kind = Constants.KIND_EDIT)
            this._listDirty := true
        if this._Remember()
            this._timer.After("listSave", Constants.SAVE_DEBOUNCE_MS, this._saveFn)
    }

    OnSettingsChanged(key) {
        if (key != "RememberList")
            return
        if this._Remember() {
            this._listDirty := true                     ; write the list itself now, not just the position
            this.Flush()
            return
        }
        this._timer.Cancel("listSave")
        this._DeleteFiles()
    }

    Flush() {
        this._timer.Cancel("listSave")
        this._Save()
    }

    ; --- Private Methods ---
    _Remember() => this._prefs.Get("RememberList") = 1

    _Save() {
        if !this._Remember()
            return                                      ; NOTE: re-checked in case a debounced save was already queued
        try {
            SplitPath(this._listPath, , &dir)
            DirCreate(dir)
            if this._listDirty {
                this._WriteAtomic(this._listPath, this._Join(this._items.ToArray()))
                this._listDirty := false
            }
            IniWrite(this._items.GetPosition(), this._sessionPath, "Session", "Position")
        } catch Error as e {
            this._LogError(A_ThisFunc, e.Message)
        }
    }

    _DeleteFiles() {
        for path in [this._listPath, this._listPath ".tmp", this._sessionPath] {
            try {
                if FileExist(path)
                    FileDelete(path)
            } catch Error as e {
                this._LogError(A_ThisFunc, e.Message)
            }
        }
    }

    _WriteAtomic(path, text) {                          ; called only inside _Save's try
        tmp := path ".tmp"
        if FileExist(tmp)
            FileDelete(tmp)
        FileAppend(text, tmp, "UTF-8")
        FileMove(tmp, path, 1)                          ; replace in one step: a crash never leaves half a list
    }

    _Join(lines) {
        out := ""
        for i, line in lines
            out .= (i > 1 ? "`r`n" : "") line
        return out
    }

    _LogError(caller, message) {
        FileAppend(FormatTime(, "yyyy-MM-dd HH:mm:ss") " ERROR [" caller "]: " message "`n", A_ScriptDir "\" Constants.ERROR_LOG)
    }
}
