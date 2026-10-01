/*
    TrayMenu.ahk
    Responsibility: the tray icon's menu and tooltip: status, list actions, settings choices, pause and exit.
    Dependencies: ItemList, Settings, HotkeyManager, TimingEngine, and an action map from Main
                  (show, generate, load, back, restart, clear, exit -> callables)
*/
class TrayMenu {
    ; --- Properties ---
    _items := ""          ; ItemList
    _prefs := ""          ; Settings
    _hotkeys := ""        ; HotkeyManager
    _timer := ""          ; TimingEngine
    _actions := ""        ; Map: action id -> callable
    _menu := ""           ; A_TrayMenu
    _advanceMenu := ""    ; Menu: auto-advance choices
    _modeMenu := ""       ; Menu: insert mode choices
    _refreshFn := ""      ; BoundFunc -> Refresh
    _built := false
    _statusText := ""     ; current text of the status line (items are renamed by their current text)
    _pauseText := ""      ; current text of the pause item
    _labels := Map("show", "Show list window", "generate", "Generate list...", "load", "Load from clipboard", "back", "Step back", "restart", "Restart at top", "clear", "Clear list", "exit", "Exit")
    _toggleLabels := Map("ExtraHotkeys", "Extra hotkeys", "ShowNextInTooltip", "Show next item in tooltip", "RememberList", "Remember list after exit")

    ; --- Constructor ---
    __New(items, prefs, hotkeys, timer, actions) {
        for dep in [items, prefs, hotkeys, timer, actions] {
            if !IsObject(dep)
                throw Error("Missing dependency", A_ThisFunc)
        }
        for id, label in this._labels {
            if (!actions.Has(id) || !HasMethod(actions[id]))
                throw Error("Missing tray action: " id, A_ThisFunc)
        }
        this._items := items
        this._prefs := prefs
        this._hotkeys := hotkeys
        this._timer := timer
        this._actions := actions
        this._refreshFn := ObjBindMethod(this, "Refresh")
    }

    ; --- Public Methods ---
    Start() {
        if !this._Build()
            return
        this._built := true
        this.Refresh()
    }

    ; NOTE: events only schedule a refresh, so a paste (a Critical thread) never waits on Explorer redrawing the tray.
    OnListChanged(kind) => this._ScheduleRefresh()
    OnSettingsChanged(key) => this._ScheduleRefresh()
    OnPausedChanged(paused) => this._ScheduleRefresh()

    Refresh() {
        if !this._built
            return
        info := {count: this._items.GetCount(), position: this._items.GetPosition(), next: this._items.Peek()}
        cfg := {advance: this._prefs.Get("AdvanceMode"), mode: this._prefs.Get("DeliveryMode")}
        cfg.extra := this._prefs.Get("ExtraHotkeys")
        cfg.showNext := this._prefs.Get("ShowNextInTooltip")
        cfg.remember := this._prefs.Get("RememberList")
        oldWindows := VerCompare(A_OSVersion, Constants.FIRST_WIN11_BUILD) < 0
        this._Apply(this.BuildState(info, cfg, this._hotkeys.IsPaused(), oldWindows))
    }

    ; Pure: what the menu and tooltip should show. escapeAmpersands = Windows 10 or earlier.
    BuildState(info, cfg, paused, escapeAmpersands) {
        count := info.count
        pos := info.position
        if (count = 0)
            status := "No list loaded"
        else if (pos >= count)
            status := "List complete (" count " of " count ")"
        else
            status := "Next: " (pos + 1) " of " count " · " cfg.advance " · " cfg.mode
        if paused
            status := "Paused — " status
        tip := Constants.APP_NAME " — " status
        if (cfg.showNext = 1 && count > 0 && pos < count)
            tip .= "`nNext item: " StrReplace(info.next, "`t", " ")    ; Windows cuts a tooltip at its first tab
        if escapeAmpersands
            tip := StrReplace(tip, "&", "&&&")
        tip := SubStr(tip, 1, Constants.TRAY_TIP_MAX)
        if escapeAmpersands {
            trailing := StrLen(tip) - StrLen(RTrim(tip, "&"))
            tip := SubStr(tip, 1, StrLen(tip) - Mod(trailing, 3))       ; don't leave half an escape at the cut
        }
        state := {status: status, tip: tip, advance: cfg.advance, mode: cfg.mode}
        state.enabled := Map("back", pos > 0, "restart", pos > 0, "clear", count > 0)
        state.checks := Map("ExtraHotkeys", cfg.extra = 1, "ShowNextInTooltip", cfg.showNext = 1, "RememberList", cfg.remember = 1)
        state.pauseText := paused ? "Resume ListPaster" : "Pause ListPaster"
        return state
    }

    ; --- Private Methods ---
    _Build() {
        try {
            this._menu := A_TrayMenu
            this._menu.Delete()                                     ; drop AutoHotkey's standard items
            this._advanceMenu := Menu()
            for mode in Constants.ADVANCE_MODES
                this._advanceMenu.Add(mode, ObjBindMethod(this, "_OnAdvance", mode), "Radio")
            this._modeMenu := Menu()
            for mode in Constants.DELIVERY_MODES
                this._modeMenu.Add(mode, ObjBindMethod(this, "_OnMode", mode), "Radio")
            this._statusText := Constants.APP_NAME
            this._menu.Add(this._statusText, ObjBindMethod(this, "_OnStatus"))
            this._menu.Disable("1&")                                ; the status line is display-only
            this._menu.Add()
            for id in ["show", "generate", "load", "back", "restart", "clear"]
                this._menu.Add(this._labels[id], ObjBindMethod(this, "_OnAction", id))
            this._menu.Add()
            this._menu.Add("Auto-advance", this._advanceMenu)
            this._menu.Add("Insert mode", this._modeMenu)
            this._menu.Add()
            for key in ["ExtraHotkeys", "ShowNextInTooltip", "RememberList"]
                this._menu.Add(this._toggleLabels[key], ObjBindMethod(this, "_OnToggle", key))
            this._menu.Add()
            this._pauseText := "Pause ListPaster"
            this._menu.Add(this._pauseText, ObjBindMethod(this, "_OnPause"))
            this._menu.Add(this._labels["exit"], ObjBindMethod(this, "_OnAction", "exit"))
            this._menu.Default := this._labels["show"]              ; double-clicking the icon opens the list window
            return true
        } catch Error as e {
            this._LogError(A_ThisFunc, e.Message)
            return false
        }
    }

    _Apply(state) {
        try {
            if (state.status != this._statusText) {
                this._menu.Rename("1&", state.status)
                this._statusText := state.status
            }
            for id, enabled in state.enabled {
                if enabled
                    this._menu.Enable(this._labels[id])
                else
                    this._menu.Disable(this._labels[id])
            }
            for mode in Constants.ADVANCE_MODES {
                if (mode = state.advance)
                    this._advanceMenu.Check(mode)
                else
                    this._advanceMenu.Uncheck(mode)
            }
            for mode in Constants.DELIVERY_MODES {
                if (mode = state.mode)
                    this._modeMenu.Check(mode)
                else
                    this._modeMenu.Uncheck(mode)
            }
            for key, checked in state.checks {
                if checked
                    this._menu.Check(this._toggleLabels[key])
                else
                    this._menu.Uncheck(this._toggleLabels[key])
            }
            if (state.pauseText != this._pauseText) {
                this._menu.Rename(this._pauseText, state.pauseText)
                this._pauseText := state.pauseText
            }
            A_IconTip := state.tip
        } catch Error as e {
            this._LogError(A_ThisFunc, e.Message)
        }
    }

    _ScheduleRefresh() {
        this._timer.After("trayRefresh", 0, this._refreshFn)
    }

    _OnAction(id, *) {
        try {
            this._actions[id].Call()
        } catch Error as e {
            this._LogError(A_ThisFunc, id ": " e.Message)
        }
    }

    _OnAdvance(mode, *) {
        this._prefs.Set("AdvanceMode", mode)
    }

    _OnMode(mode, *) {
        this._prefs.Set("DeliveryMode", mode)
    }

    _OnToggle(key, *) {
        this._prefs.Set(key, this._prefs.Get(key) = 1 ? 0 : 1)
    }

    _OnPause(*) {
        this._hotkeys.TogglePaused()
    }

    _OnStatus(*) {
        return                                                      ; disabled item: never runs
    }

    _LogError(caller, message) {
        FileAppend(FormatTime(, "yyyy-MM-dd HH:mm:ss") " ERROR [" caller "]: " message "`n", A_ScriptDir "\" Constants.ERROR_LOG)
    }
}
