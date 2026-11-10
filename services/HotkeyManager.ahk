/*
    HotkeyManager.ahk
    Responsibility: register ListPaster's shortcuts (always-on core ones plus optional extras), report any that
                    can't be set up, run once-per-press ones only once per physical press, and pause/resume them all.
    Dependencies: Settings, Notifier
*/
class HotkeyManager {
    ; --- Properties ---
    _prefs := ""          ; Settings
    _tips := ""           ; Notifier
    _entries := []        ; {keys, label, fn, group: "core"|"extra", ok, onePerPress, held, releaseOk, press, release}
    _paused := false
    _listeners := []      ; callables(paused)

    ; --- Constructor ---
    __New(prefs, tips) {
        if (!IsObject(prefs) || !IsObject(tips))
            throw Error("prefs and tips are required", A_ThisFunc)
        this._prefs := prefs
        this._tips := tips
    }

    ; --- Public Methods ---
    ; onePerPress: holding the shortcut runs it once; it runs again only after its main key has come up.
    Add(keys, label, fn, group, onePerPress := false) {
        if (group != "core" && group != "extra")
            throw ValueError("group must be core or extra: " label, A_ThisFunc)
        if !HasMethod(fn)
            throw Error("Callback is not callable: " label, A_ThisFunc)
        entry := {keys: keys, label: label, fn: fn, group: group, ok: false}
        entry.onePerPress := onePerPress ? true : false
        entry.held := false          ; a press ran and its main key hasn't been seen coming up yet
        entry.releaseOk := false     ; the main key's release is watched; without it every launch runs
        entry.press := ObjBindMethod(this, "_OnPress", entry)
        entry.release := ObjBindMethod(this, "_OnRelease", entry)
        if (!HasMethod(entry.press) || !HasMethod(entry.release))
            throw Error("Failed to bind shortcut callbacks: " label, A_ThisFunc)
        this._entries.Push(entry)
    }

    ; Registers every shortcut through the keyboard hook ($), so a program that registered the same combo
    ; can't block it. A bad key name is the only failure that can be detected; all of them are reported at once.
    RegisterAll() {
        extrasOn := (this._prefs.Get("ExtraHotkeys") = 1)
        failed := ""
        for entry in this._entries {
            if entry.onePerPress
                entry.releaseOk := this._WatchRelease(entry)
            try {
                Hotkey("$" entry.keys, entry.press, (entry.group = "core" || extrasOn) ? "On" : "Off")
                entry.ok := true
            } catch Error as e {
                this._LogError(A_ThisFunc, entry.label " (" entry.keys "): " e.Message)
                note := (entry.group = "core") ? ": unavailable until fixed, it has no tray item" : ": still in the tray menu"
                failed .= "`n- " entry.label " (" this.Describe(entry.keys) ")" note
            }
        }
        if (failed != "")
            this._tips.Alert("These ListPaster shortcuts couldn't be set up:" failed "`n`nCheck the HK_ lines in Constants.ahk. Everything else keeps working.")
    }

    SetExtraEnabled(enabled) {
        for entry in this._entries {
            if (entry.group != "extra" || !entry.ok)
                continue
            try {
                Hotkey("$" entry.keys, enabled ? "On" : "Off")
            } catch Error as e {
                this._LogError(A_ThisFunc, entry.label ": " e.Message)
            }
        }
    }

    OnSettingsChanged(key) {
        if (key = "ExtraHotkeys")
            this.SetExtraEnabled(this._prefs.Get("ExtraHotkeys") = 1)
    }

    IsPaused() => this._paused

    ; Pause = every ListPaster shortcut goes back to the apps (Suspend); listeners also stop auto-loading copies.
    SetPaused(paused) {
        paused := paused ? true : false
        if (paused = this._paused)
            return
        try {
            Suspend(paused ? 1 : 0)
        } catch Error as e {
            this._LogError(A_ThisFunc, e.Message)
            return
        }
        this._paused := paused
        if !paused {
            for entry in this._entries
                entry.held := false          ; releases aren't seen while paused; don't swallow the next press
        }
        for fn in this._listeners {
            try {
                fn.Call(paused)
            } catch Error as e {
                this._LogError(A_ThisFunc, e.Message)
            }
        }
    }

    TogglePaused() {
        this.SetPaused(!this._paused)
    }

    OnPausedChanged(fn) {
        if !HasMethod(fn)
            throw Error("Listener is not callable", A_ThisFunc)
        this._listeners.Push(fn)
    }

    ; "^<!z" -> "Ctrl+Alt+Z"
    Describe(keys) {
        names := Map("^", "Ctrl+", "!", "Alt+", "+", "Shift+", "#", "Win+")
        text := ""
        pos := 1
        while (pos <= StrLen(keys)) {
            ch := SubStr(keys, pos, 1)
            if (ch = "<" || ch = ">" || ch = "$" || ch = "~" || ch = "*") {
                pos += 1
                continue
            }
            if !names.Has(ch)
                break
            text .= names[ch]
            pos += 1
        }
        key := SubStr(keys, pos)
        return text (StrLen(key) = 1 ? StrUpper(key) : key)
    }

    ; --- Private Methods ---
    ; NOTE: while a shortcut's thread is Critical, AutoHotkey queues every key-repeat of it and starts each one
    ; once that thread ends, when the key is already up. Holding the keys past the 3 s reminder starts a new
    ; thread too. Either way the main key hasn't come up since the press that ran, so the launch is dropped.
    _OnPress(entry, hotkeyName) {
        if (entry.releaseOk && entry.held)
            return
        entry.held := entry.releaseOk
        entry.fn.Call(hotkeyName)
    }

    _OnRelease(entry, *) {
        entry.held := false
    }

    ; Registers a pass-through hotkey for the main key coming up, with any modifiers. True when it's watched.
    _WatchRelease(entry) {
        mainKey := RegExReplace(entry.keys, "[\^!+#*~$<>]")
        if (mainKey = "" || InStr(mainKey, " "))
            return false
        try {
            Hotkey("~*" mainKey " up", entry.release, "On")
            return true
        } catch Error as e {
            this._LogError(A_ThisFunc, entry.label " (" entry.keys "): " e.Message)
            return false
        }
    }

    _LogError(caller, message) {
        line := FormatTime(, "yyyy-MM-dd HH:mm:ss") " ERROR [" caller "]: " message "`n"
        try {
            FileAppend(line, A_ScriptDir "\" Constants.ERROR_LOG)
        } catch Error {
            OutputDebug(Constants.APP_NAME " (error.log not writable) " line)   ; NOTE: runs inside catch blocks, so it must never throw
        }
    }
}
