/*
    SequenceDialog.ahk
    Responsibility: form that previews and loads a generated list.
    Dependencies: ItemList, SequenceBuilder, Notifier
*/
class SequenceDialog {
    ; --- Properties ---
    _items := ""          ; ItemList
    _builder := ""        ; SequenceBuilder
    _tips := ""            ; Notifier
    _gui := ""            ; Gui, built on first Show()
    _ctl := Map()         ; key -> GuiControl
    _changedFn := ""      ; BoundFunc -> _OnInputChanged (shared by every input)
    _prevActive := 0      ; HWND to re-activate after Load / Cancel

    ; --- Constructor ---
    __New(items, builder, tips) {
        for dep in [items, builder, tips] {
            if !IsObject(dep)
                throw Error("Missing dependency", A_ThisFunc)
        }
        this._items := items
        this._builder := builder
        this._tips := tips
        this._changedFn := ObjBindMethod(this, "_OnInputChanged")
    }

    ; --- Public Methods ---
    Show() {
        this._prevActive := WinExist("A")
        if (!IsObject(this._gui) && !this._Build())
            return
        this._UpdatePreview()
        try {
            this._gui.Show()
        } catch Error as e {
            this._LogError(A_ThisFunc, e.Message)
        }
    }

    ; --- Private Methods ---
    _Build() {
        try {
            g := Gui("+AlwaysOnTop", Constants.APP_NAME " - Generate list")
            this._ctl["modeNum"] := g.Add("Radio", "Checked Group", "Numbers")
            this._ctl["modeIp"] := g.Add("Radio", "x+20", "IP range")
            g.Add("Text", "xm y+12", "Template  ({n} = number)")
            this._ctl["tpl"] := g.Add("Edit", "xm w320", "Cam-{n}")
            g.Add("Text", "xm y+8", "Start")
            this._ctl["start"] := g.Add("Edit", "x+4 yp-3 w60", "1")
            g.Add("Text", "x+10 yp+3", "End")
            this._ctl["end"] := g.Add("Edit", "x+4 yp-3 w60", "10")
            g.Add("Text", "x+10 yp+3", "Step")
            this._ctl["step"] := g.Add("Edit", "x+4 yp-3 w40", "1")
            g.Add("Text", "x+10 yp+3", "Pad")
            this._ctl["pad"] := g.Add("Edit", "x+4 yp-3 w30", "3")
            g.Add("Text", "xm y+16", "Start IP")
            this._ctl["ipStart"] := g.Add("Edit", "x+4 yp-3 w110", "192.168.1.100")
            g.Add("Text", "x+10 yp+3", "End IP")
            this._ctl["ipEnd"] := g.Add("Edit", "x+4 yp-3 w110", "192.168.1.150")
            g.Add("Text", "xm y+10", "Step")
            this._ctl["ipStep"] := g.Add("Edit", "x+4 yp-3 w40", "1")
            this._ctl["skip"] := g.Add("Checkbox", "x+14 yp+3 Checked", "Skip .0 and .255")
            this._ctl["preview"] := g.Add("Text", "xm y+16 w320 r2")
            this._ctl["load"] := g.Add("Button", "xm w80 Default", "Load")
            this._ctl["cancel"] := g.Add("Button", "x+8 w80", "Cancel")
            for key in ["tpl", "start", "end", "step", "pad", "ipStart", "ipEnd", "ipStep"]
                this._ctl[key].OnEvent("Change", this._changedFn)
            for key in ["modeNum", "modeIp", "skip"]
                this._ctl[key].OnEvent("Click", this._changedFn)
            this._ctl["load"].OnEvent("Click", ObjBindMethod(this, "_OnLoad"))
            this._ctl["cancel"].OnEvent("Click", ObjBindMethod(this, "_OnCancel"))
            g.OnEvent("Escape", ObjBindMethod(this, "_OnCancel"))
            g.OnEvent("Close", ObjBindMethod(this, "_OnCancel"))
            this._gui := g
            return true
        } catch Error as e {
            this._LogError(A_ThisFunc, e.Message)
            this._gui := ""
            return false
        }
    }

    _OnInputChanged(*) {
        this._UpdatePreview()
    }

    _UpdatePreview() {
        isNum := (this._ctl["modeNum"].Value = 1)
        for key in ["tpl", "start", "end", "step", "pad"]
            this._ctl[key].Enabled := isNum
        for key in ["ipStart", "ipEnd", "ipStep", "skip"]
            this._ctl[key].Enabled := !isNum
        result := this._Generate()
        if (result.error != "") {
            this._ctl["preview"].Value := "Error: " result.error
            this._ctl["load"].Enabled := false
            return
        }
        generated := result.items
        this._ctl["preview"].Value := generated.Length " items:   " generated[1] "   ...   " generated[generated.Length]
        this._ctl["load"].Enabled := true
    }

    _Generate() {
        if (this._ctl["modeNum"].Value = 1)
            return this._builder.BuildNumbers(this._ctl["tpl"].Value, this._ctl["start"].Value
                , this._ctl["end"].Value, this._ctl["step"].Value, this._ctl["pad"].Value)
        return this._builder.BuildIpRange(this._ctl["ipStart"].Value, this._ctl["ipEnd"].Value
            , this._ctl["ipStep"].Value, this._ctl["skip"].Value = 1)
    }

    _OnLoad(*) {
        result := this._Generate()
        if (result.error != "")
            return
        try {
            if this._items.IsMidList() {
                question := "Replace the current list? (" this._items.GetPosition() "/" this._items.GetCount() " done)"
                ; Owner = this dialog, so the prompt stays on top of the always-on-top form
                if (MsgBox(question, Constants.APP_NAME, "YesNo Icon? Default2 Owner" this._gui.Hwnd) != "Yes")
                    return
            }
            this._items.Load(result.items)
            this._gui.Hide()
        } catch Error as e {
            this._LogError(A_ThisFunc, e.Message)
            return
        }
        n := result.items.Length
        this._tips.Show("Loaded " n (n = 1 ? " item" : " items"))
        this._RestoreFocus()
    }

    _OnCancel(*) {
        try {
            this._gui.Hide()
        } catch Error as e {
            this._LogError(A_ThisFunc, e.Message)
        }
        this._RestoreFocus()
        return true
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

    _LogError(caller, message) {
        FileAppend(FormatTime(, "yyyy-MM-dd HH:mm:ss") " ERROR [" caller "]: " message "`n", A_ScriptDir "\" Constants.ERROR_LOG)
    }
}
