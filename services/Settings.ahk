/*
    Settings.ahk
    Responsibility: load, validate, save, and announce user settings in data\settings.ini.
    Dependencies: none
*/
class Settings {
    ; --- Properties ---
    _path := ""          ; full path of settings.ini
    _values := Map()     ; key -> validated value
    _listeners := []     ; callables(key)

    ; --- Constructor ---
    __New(iniPath) {
        if (iniPath = "")
            throw Error("iniPath is required", A_ThisFunc)
        this._path := iniPath
    }

    ; --- Public Methods ---
    Load() {
        try {
            SplitPath(this._path, , &dir)
            DirCreate(dir)
        } catch Error as e {
            this._LogError(A_ThisFunc, e.Message)
        }
        for key, fallback in Constants.SETTINGS_DEFAULTS {
            raw := fallback
            try {
                raw := IniRead(this._path, "Settings", key, fallback)
            } catch Error as e {
                this._LogError(A_ThisFunc, key ": " e.Message)
            }
            this._values[key] := this._Validate(key, raw)
        }
    }

    Get(key) {
        if !this._values.Has(key)
            throw Error("Unknown or unloaded setting: " key, A_ThisFunc)
        return this._values[key]
    }

    Set(key, value) {
        if !Constants.SETTINGS_DEFAULTS.Has(key)
            throw Error("Unknown setting: " key, A_ThisFunc)
        value := this._Validate(key, value)
        this._values[key] := value
        try {
            IniWrite(value, this._path, "Settings", key)
        } catch Error as e {
            this._LogError(A_ThisFunc, key ": " e.Message)
        }
        this._Notify(key)
    }

    OnChange(fn) {
        if !HasMethod(fn)
            throw Error("Listener is not callable", A_ThisFunc)
        this._listeners.Push(fn)
    }

    ; --- Private Methods ---
    _Validate(key, value) {
        fallback := Constants.SETTINGS_DEFAULTS[key]
        switch key {
            case "AdvanceMode":
                return this._OneOf(key, value, Constants.ADVANCE_MODES, fallback)
            case "DeliveryMode":
                return this._OneOf(key, value, Constants.DELIVERY_MODES, fallback)
            case "PastePreDelayMs", "PastePostDelayMs":
                return this._IntInRange(key, value, 0, 5000, fallback)
            case "WindowVisible":
                return this._IntInRange(key, value, 0, 1, fallback)
            case "WindowW", "WindowH":
                return this._IntInRange(key, value, 100, 4000, fallback)
            case "WindowX", "WindowY":
                return (value = "") ? "" : this._IntInRange(key, value, -32000, 32000, fallback)
        }
        return fallback
    }

    _OneOf(key, value, allowed, fallback) {
        for option in allowed {
            if (option = value)           ; case-insensitive; returns the canonical spelling
                return option
        }
        this._LogError(A_ThisFunc, "Invalid " key "=" value ", using " fallback)
        return fallback
    }

    _IntInRange(key, value, low, high, fallback) {
        if (RegExMatch(value, "^-?\d{1,6}$") && Integer(value) >= low && Integer(value) <= high)
            return Integer(value)
        this._LogError(A_ThisFunc, "Invalid " key "=" value ", using " fallback)
        return fallback
    }

    _Notify(key) {
        for fn in this._listeners {
            try {
                fn.Call(key)
            } catch Error as e {
                this._LogError(A_ThisFunc, key ": " e.Message)
            }
        }
    }

    _LogError(caller, message) {
        FileAppend(FormatTime(, "yyyy-MM-dd HH:mm:ss") " ERROR [" caller "]: " message "`n", A_ScriptDir "\" Constants.ERROR_LOG)
    }
}
