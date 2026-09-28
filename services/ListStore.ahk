/*
    ListStore.ahk
    Responsibility: save the list and position (debounced, atomic) and resume them at startup.
    Dependencies: ItemList, TimingEngine, Notifier
*/
class ListStore {
    ; --- Properties ---
    _items := ""          ; ItemList
    _timer := ""          ; TimingEngine
    _tips := ""            ; Notifier
    _listPath := ""       ; full path of data\list.txt
    _sessionPath := ""    ; full path of data\session.ini
    _listDirty := false   ; list content changed since last write
    _saveFn := ""         ; BoundFunc -> _Save

    ; --- Constructor ---
    __New(items, timer, tips, listPath, sessionPath) {
        for dep in [items, timer, tips] {
            if !IsObject(dep)
                throw Error("Missing dependency", A_ThisFunc)
        }
        if (listPath = "" || sessionPath = "")
            throw Error("File paths are required", A_ThisFunc)
        this._items := items
        this._timer := timer
        this._tips := tips
        this._listPath := listPath
        this._sessionPath := sessionPath
        this._saveFn := ObjBindMethod(this, "_Save")
    }

    ; --- Public Methods ---
    Resume() {
        if !FileExist(this._listPath)
            return
        try {
            lines := this._items.ParseLines(FileRead(this._listPath, "UTF-8"))
            if !lines.Length
                return
            raw := IniRead(this._sessionPath, "Session", "Position", "0")
            position := RegExMatch(raw, "^\d{1,7}$") ? Integer(raw) : 0
            this._items.Restore(lines, position)        ; clamps to 0..Count
            this._tips.Show("Resumed " this._items.GetPosition() "/" this._items.GetCount())
        } catch Error as e {
            this._LogError(A_ThisFunc, e.Message)
        }
    }

    OnListChanged(kind) {
        if (kind = Constants.KIND_RESUME)
            return                                      ; state just came from disk
        if (kind = Constants.KIND_LOAD || kind = Constants.KIND_EDIT)
            this._listDirty := true
        this._timer.After("listSave", Constants.SAVE_DEBOUNCE_MS, this._saveFn)
    }

    Flush() {
        this._timer.Cancel("listSave")
        this._Save()
    }

    ; --- Private Methods ---
    _Save() {
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
