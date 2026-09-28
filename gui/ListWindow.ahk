/*
    ListWindow.ahk
    Responsibility: always-on-top list view that never takes focus; click a row to make it NEXT; right-click to edit, insert, add, or delete.
    Dependencies: ItemList, Settings, TimingEngine
*/
class ListWindow {
    ; --- Properties ---
    _items := ""          ; ItemList
    _prefs := ""          ; Settings
    _timer := ""          ; TimingEngine
    _menuFocusFn := ""    ; BoundFunc -> _RestoreFocusIfOurs (fallback when a menu closes with no pick)
    _gui := ""            ; Gui, built on first Show()
    _lv := ""             ; ListView
    _menu := ""            ; Menu (right-click)
    _visible := false
    _dirty := true        ; full render needed at next Show()
    _shownIdx := 0        ; list position the Status column currently shows
    _menuRow := 0          ; row under the last right-click (0 = empty area)
    _prevActive := 0      ; HWND to re-activate after the menu / InputBox

    ; --- Constructor ---
    __New(items, prefs, timer) {
        if (!IsObject(items) || !IsObject(prefs) || !IsObject(timer))
            throw Error("items, prefs and timer are required", A_ThisFunc)
        this._items := items
        this._prefs := prefs
        this._timer := timer
        this._menuFocusFn := ObjBindMethod(this, "_RestoreFocusIfOurs")
        if !HasMethod(this._menuFocusFn)
            throw Error("Failed to bind menu focus callback", A_ThisFunc)
    }

    ; --- Public Methods ---
    Start() {
        if (this._prefs.Get("WindowVisible") = 1)
            this.Show()
    }

    Toggle() {
        if this._visible
            this.Hide()
        else
            this.Show()
    }

    Show() {
        if (!IsObject(this._gui) && !this._Build())
            return
        if this._dirty
            this._RenderAll()
        try {
            this._gui.Show("NA " this._SavedPlacement())   ; NA: never take focus from the app being pasted into
        } catch Error as e {
            this._LogError(A_ThisFunc, e.Message)
            return
        }
        this._visible := true
        this._UpdateTitle()
        this._prefs.Set("WindowVisible", 1)
    }

    Hide() {
        if !this._visible
            return
        this.SaveGeometry()
        try {
            this._gui.Hide()
        } catch Error as e {
            this._LogError(A_ThisFunc, e.Message)
        }
        this._visible := false
        this._prefs.Set("WindowVisible", 0)
    }

    SaveGeometry() {
        if (!IsObject(this._gui) || !this._visible)
            return
        try {
            this._gui.GetPos(&x, &y)              ; outer position = what Show("x y") sets
            this._gui.GetClientPos(, , &w, &h)    ; client size, DPI-scaled = what Show("w h") takes
        } catch Error as e {
            this._LogError(A_ThisFunc, e.Message)
            return
        }
        this._prefs.Set("WindowX", x)
        this._prefs.Set("WindowY", y)
        this._prefs.Set("WindowW", w)
        this._prefs.Set("WindowH", h)
    }

    OnListChanged(kind) {
        if !this._visible {
            this._dirty := true
            return
        }
        if (kind = Constants.KIND_LOAD || kind = Constants.KIND_EDIT || kind = Constants.KIND_RESUME)
            this._RenderAll()
        else
            this._RefreshStatus()
        this._UpdateTitle()
    }

    OnSettingsChanged(key) {
        if (this._visible && (key = "AdvanceMode" || key = "DeliveryMode"))
            this._UpdateTitle()
    }

    ; --- Private Methods ---
    _Build() {
        try {
            ; E0x08000000 = WS_EX_NOACTIVATE: clicking the window never pulls focus from the target app
            this._gui := Gui("+AlwaysOnTop +ToolWindow +Resize +MinSize240x160 +E0x08000000", Constants.APP_NAME)
            this._gui.MarginX := 8
            this._gui.MarginY := 8
            ; NoSort + NoSortHdr: sorting would make row numbers disagree with list positions
            this._lv := this._gui.Add("ListView", "w360 r18 -Multi Grid NoSort NoSortHdr", ["Status", "#", "Item"])
            this._lv.ModifyCol(1, 50)
            this._lv.ModifyCol(2, "40 Integer")
            this._lv.ModifyCol(3, 250)
            this._lv.OnEvent("Click", ObjBindMethod(this, "_OnRowClick"))
            this._lv.OnEvent("ContextMenu", ObjBindMethod(this, "_OnContextMenu"))
            this._gui.OnEvent("Size", ObjBindMethod(this, "_OnSize"))
            this._gui.OnEvent("Close", ObjBindMethod(this, "_OnClose"))
            this._menu := Menu()
            this._menu.Add("Set as next", ObjBindMethod(this, "_OnMenuSetNext"))
            this._menu.Add("Edit...", ObjBindMethod(this, "_OnMenuEdit"))
            this._menu.Add("Insert above...", ObjBindMethod(this, "_OnMenuInsert"))
            this._menu.Add("Add to end...", ObjBindMethod(this, "_OnMenuAppend"))
            this._menu.Add("Delete", ObjBindMethod(this, "_OnMenuDelete"))
            return true
        } catch Error as e {
            this._LogError(A_ThisFunc, e.Message)
            this._gui := ""
            return false
        }
    }

    _RenderAll() {
        pos := this._items.GetPosition()
        count := this._items.GetCount()
        this._lv.Opt("-Redraw")
        this._lv.Delete()
        loop count
            this._lv.Add(, this._StatusFor(A_Index, pos), A_Index, this._items.GetItem(A_Index))
        this._lv.Opt("+Redraw")
        this._shownIdx := pos
        this._dirty := false
        this._HighlightNext(pos, count)
    }

    ; Only rows between the old and new NEXT row change status (matches a full render).
    _RefreshStatus() {
        pos := this._items.GetPosition()
        count := this._items.GetCount()
        first := Max(1, Min(this._shownIdx, pos) + 1)
        last := Min(count, Max(this._shownIdx, pos) + 1)
        row := first
        while (row <= last) {
            this._lv.Modify(row, , this._StatusFor(row, pos))
            row += 1
        }
        this._shownIdx := pos
        this._HighlightNext(pos, count)
    }

    _StatusFor(row, pos) {
        if (row <= pos)
            return "done"
        return (row = pos + 1) ? "NEXT" : ""
    }

    _HighlightNext(pos, count) {
        this._lv.Modify(0, "-Select")
        if (pos < count)
            this._lv.Modify(pos + 1, "Select Vis")
    }

    _UpdateTitle() {
        if !IsObject(this._gui)
            return
        count := this._items.GetCount()
        title := Constants.APP_NAME
        if (count = 0)
            title .= "  (empty)"
        else
            title .= "  " this._items.GetPosition() "/" count "  |  " this._prefs.Get("AdvanceMode") "  |  " this._prefs.Get("DeliveryMode")
        this._gui.Title := title
    }

    _OnRowClick(ctrl, row) {
        if (row < 1)
            return
        this._items.JumpTo(row)
    }

    _OnContextMenu(ctrl, row, isRightClick, x, y) {
        this._menuRow := row
        this._prevActive := WinExist("A")         ; still the target app: this window never activates
        for name in ["Set as next", "Edit...", "Insert above...", "Delete"] {
            if (row >= 1)
                this._menu.Enable(name)
            else
                this._menu.Disable(name)
        }
        try {
            this._menu.Show()
        } catch Error as e {
            this._LogError(A_ThisFunc, e.Message)
        }
        ; NOTE: a picked item's callback runs AFTER Show() returns. Handing focus back here would put the
        ; target app in front before an Edit/Insert/Add prompt opens, so the prompt would open behind it.
        ; Each callback cancels this fallback and restores focus itself; it only fires if nothing was picked.
        this._timer.After("menuFocus", Constants.MENU_FOCUS_DELAY_MS, this._menuFocusFn)
    }

    _OnMenuSetNext(*) {
        this._timer.Cancel("menuFocus")
        this._items.JumpTo(this._menuRow)
        this._RestoreFocus()
    }

    _OnMenuEdit(*) {
        this._timer.Cancel("menuFocus")          ; keep the script in front so the prompt opens on top
        text := this._AskText("Edit item " this._menuRow, this._items.GetItem(this._menuRow))
        if (text != "")
            this._items.Replace(this._menuRow, text)
        this._RestoreFocus()
    }

    _OnMenuInsert(*) {
        this._timer.Cancel("menuFocus")          ; keep the script in front so the prompt opens on top
        text := this._AskText("Insert above item " this._menuRow, "")
        if (text != "")
            this._items.InsertAt(this._menuRow, text)
        this._RestoreFocus()
    }

    _OnMenuAppend(*) {
        this._timer.Cancel("menuFocus")          ; keep the script in front so the prompt opens on top
        text := this._AskText("Add to end of list", "")
        if (text != "")
            this._items.InsertAt(this._items.GetCount() + 1, text)
        this._RestoreFocus()
    }

    _OnMenuDelete(*) {
        this._timer.Cancel("menuFocus")
        this._items.Remove(this._menuRow)
        this._RestoreFocus()
    }

    _AskText(prompt, current) {
        try {
            reply := InputBox(prompt, Constants.APP_NAME, "w320 h110", current)
        } catch Error as e {
            this._LogError(A_ThisFunc, e.Message)
            return ""
        }
        if (reply.Result != "OK")
            return ""
        text := StrReplace(StrReplace(reply.Value, "`r", ""), "`n", " ")
        return (Trim(text) = "") ? "" : text
    }

    _RestoreFocus() {
        if !this._prevActive
            return
        try {
            if WinExist(this._prevActive)
                WinActivate(this._prevActive)
        } catch Error as e {
            this._LogError(A_ThisFunc, e.Message)
        }
    }

    ; Fallback for a menu closed with no pick: give focus back only if nothing else took it,
    ; so clicking into another app to dismiss the menu doesn't get yanked back.
    _RestoreFocusIfOurs() {
        try {
            active := WinExist("A")
            if (active && active != this._prevActive && WinGetPID(active) != ProcessExist())
                return
        } catch Error as e {
            this._LogError(A_ThisFunc, e.Message)
            return
        }
        this._RestoreFocus()
    }

    _OnSize(guiObj, minMax, width, height) {
        if (minMax = -1)
            return
        this._lv.Move(, , width - 16, height - 16)
        this._lv.ModifyCol(3, Max(80, width - 16 - 50 - 40 - 24))
    }

    _OnClose(*) {
        this.Hide()
        return true                                ; already hidden (and geometry saved); skip default
    }

    _SavedPlacement() {
        size := "w" this._prefs.Get("WindowW") " h" this._prefs.Get("WindowH")
        x := this._prefs.Get("WindowX")
        y := this._prefs.Get("WindowY")
        if (x = "" || y = "" || !this._IsOnScreen(x, y))
            return size                            ; no saved spot, or its monitor is gone: Show centers it
        return "x" x " y" y " " size
    }

    _IsOnScreen(x, y) {
        try {
            loop MonitorGetCount() {
                MonitorGetWorkArea(A_Index, &left, &top, &right, &bottom)
                if (x >= left && x < right - 60 && y >= top && y < bottom - 60)
                    return true
            }
        } catch Error as e {
            this._LogError(A_ThisFunc, e.Message)
        }
        return false
    }

    _LogError(caller, message) {
        FileAppend(FormatTime(, "yyyy-MM-dd HH:mm:ss") " ERROR [" caller "]: " message "`n", A_ScriptDir "\" Constants.ERROR_LOG)
    }
}
