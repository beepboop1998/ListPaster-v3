/*
    ItemList.ahk
    Responsibility: the list, the position, and change notifications.
    Dependencies: none
*/
class ItemList {
    ; --- Properties ---
    _items := []        ; Array of String (non-blank lines)
    _index := 0         ; items delivered so far
    _listeners := []    ; callables(kind)

    ; --- Public Methods ---
    OnChange(fn) {
        if !HasMethod(fn)
            throw Error("Listener is not callable", A_ThisFunc)
        this._listeners.Push(fn)
    }

    ParseLines(text) {
        lines := []
        for line in StrSplit(text, "`n", "`r") {
            if (Trim(line) != "")
                lines.Push(line)          ; keep original spacing (v2 behavior)
        }
        return lines
    }

    GetCount() => this._items.Length
    GetPosition() => this._index
    GetItem(n) => (n >= 1 && n <= this._items.Length) ? this._items[n] : ""
    Peek() => this.GetItem(this._index + 1)
    IsEmpty() => this._items.Length = 0
    IsFinished() => this._items.Length > 0 && this._index >= this._items.Length
    IsMidList() => this._index > 0 && this._index < this._items.Length
    ToArray() => this._items.Clone()

    Load(lines) {
        this._items := lines.Clone()
        this._index := 0
        this._Notify(Constants.KIND_LOAD)
    }

    Restore(lines, position) {
        this._items := lines.Clone()
        this._index := Max(0, Min(position, this._items.Length))
        this._Notify(Constants.KIND_RESUME)
    }

    Advance() {
        if (this.IsEmpty() || this.IsFinished())
            return false
        this._index += 1
        this._Notify(Constants.KIND_ADVANCE)
        return true
    }

    StepBack(kind) {                      ; kind: Constants.KIND_BACK or Constants.KIND_UNDO
        if (this._index <= 0)
            return false
        this._index -= 1
        this._Notify(kind)
        return true
    }

    Reset() {
        this._index := 0
        this._Notify(Constants.KIND_RESET)
    }

    JumpTo(n) {                           ; row n becomes the NEXT item
        if (n < 1 || n > this._items.Length)
            return false
        this._index := n - 1
        this._Notify(Constants.KIND_JUMP)
        return true
    }

    Replace(n, text) {
        if (n < 1 || n > this._items.Length || Trim(text) = "")
            return false
        this._items[n] := text
        this._Notify(Constants.KIND_EDIT)
        return true
    }

    Remove(n) {
        if (n < 1 || n > this._items.Length)
            return false
        this._items.RemoveAt(n)
        if (n <= this._index)             ; removed a delivered item: NEXT stays the same item
            this._index -= 1
        this._index := Max(0, Min(this._index, this._items.Length))
        this._Notify(Constants.KIND_EDIT)
        return true
    }

    InsertAt(n, text) {                   ; new item occupies position n (Count + 1 = append)
        if (n < 1 || n > this._items.Length + 1 || Trim(text) = "")
            return false
        this._items.InsertAt(n, text)
        if (n <= this._index)             ; inserted inside the delivered part: NEXT stays the same item
            this._index += 1
        this._Notify(Constants.KIND_EDIT)
        return true
    }

    ; --- Private Methods ---
    _Notify(kind) {
        for fn in this._listeners {
            try {
                fn.Call(kind)
            } catch Error as e {
                this._LogError(A_ThisFunc, kind ": " e.Message)
            }
        }
    }

    _LogError(caller, message) {
        FileAppend(FormatTime(, "yyyy-MM-dd HH:mm:ss") " ERROR [" caller "]: " message "`n", A_ScriptDir "\" Constants.ERROR_LOG)
    }
}
