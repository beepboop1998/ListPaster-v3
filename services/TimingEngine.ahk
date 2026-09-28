/*
    TimingEngine.ahk
    Responsibility: the only SetTimer; runs per-tick callbacks and named one-shot jobs.
    Dependencies: none
*/
class TimingEngine {
    ; --- Properties ---
    _tickMs := 0          ; Integer
    _callbacks := Map()   ; name -> callable, every tick
    _oneShots := Map()    ; name -> {due: A_TickCount value, fn: callable}
    _tickFn := ""         ; BoundFunc -> _OnTick

    ; --- Constructor ---
    __New() {
        this._tickMs := Constants.TICK_MS
        this._tickFn := ObjBindMethod(this, "_OnTick")
        if !HasMethod(this._tickFn)
            throw Error("Failed to bind tick callback", A_ThisFunc)
    }

    ; --- Public Methods ---
    Start() {
        try {
            SetTimer(this._tickFn, this._tickMs)
        } catch Error as e {
            this._LogError(A_ThisFunc, e.Message)
        }
    }

    Stop() {
        try {
            SetTimer(this._tickFn, 0)
        } catch Error as e {
            this._LogError(A_ThisFunc, e.Message)
        }
    }

    Register(name, fn) {
        if !HasMethod(fn)
            throw Error("Callback is not callable: " name, A_ThisFunc)
        this._callbacks[name] := fn
    }

    Unregister(name) {
        if this._callbacks.Has(name)
            this._callbacks.Delete(name)
    }

    ; Runs fn once, delayMs from now. Calling again with the same name replaces the pending job.
    After(name, delayMs, fn) {
        if !HasMethod(fn)
            throw Error("Callback is not callable: " name, A_ThisFunc)
        this._oneShots[name] := {due: A_TickCount + delayMs, fn: fn}
    }

    Cancel(name) {
        if this._oneShots.Has(name)
            this._oneShots.Delete(name)
    }

    ; --- Private Methods ---
    _OnTick() {
        for name, fn in this._callbacks {
            try {
                fn.Call()
            } catch Error as e {
                this._LogError(A_ThisFunc, name ": " e.Message)
            }
        }
        if !this._oneShots.Count
            return
        now := A_TickCount
        dueNames := []
        for name, job in this._oneShots {       ; NOTE: collect first; never Delete from a Map while enumerating it
            if (now >= job.due)
                dueNames.Push(name)
        }
        for name in dueNames {
            if !this._oneShots.Has(name)        ; cancelled by an earlier job this tick
                continue
            job := this._oneShots[name]
            this._oneShots.Delete(name)         ; delete BEFORE calling so the job can re-schedule itself
            try {
                job.fn.Call()
            } catch Error as e {
                this._LogError(A_ThisFunc, name ": " e.Message)
            }
        }
    }

    _LogError(caller, message) {
        FileAppend(FormatTime(, "yyyy-MM-dd HH:mm:ss") " ERROR [" caller "]: " message "`n", A_ScriptDir "\" Constants.ERROR_LOG)
    }
}
