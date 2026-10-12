/*
    PasteController.ahk
    Responsibility: user actions from shortcuts, the tray menu and clipboard events (paste, undo, step back, restart,
                    load, clear, exit, mode switches), and the rule that an unfinished list is never replaced without asking.
    Dependencies: ItemList, DeliveryService, ClipboardService, Notifier, Settings
*/
class PasteController {
    ; --- Properties ---
    _items := ""        ; ItemList
    _delivery := ""     ; DeliveryService
    _clip := ""         ; ClipboardService
    _tips := ""         ; Notifier
    _prefs := ""        ; Settings
    _undo := []         ; delivery records, newest last
    _paused := false    ; while paused, copies are ignored

    ; --- Constructor ---
    __New(items, delivery, clip, tips, prefs) {
        for dep in [items, delivery, clip, tips, prefs] {
            if !IsObject(dep)
                throw Error("Missing dependency", A_ThisFunc)
        }
        this._items := items
        this._delivery := delivery
        this._clip := clip
        this._tips := tips
        this._prefs := prefs
    }

    ; --- Public Methods: shortcuts ---
    ; hotkey: the shortcut that fired (e.g. "$^+v"); its keys must be released before anything is typed.
    PasteNext(hotkey := "") {
        Critical                                    ; other shortcuts and clipboard events wait until this finishes
        if this._items.IsEmpty() {
            this._tips.Show("No list loaded. Copy a list of 2+ lines, or use the tray menu.")
            return
        }
        if this._items.IsFinished() {
            count := this._items.GetCount()
            this._tips.Show("List complete (" count " of " count "). Tray menu → Restart at top to go again.")
            return
        }
        problem := this._delivery.HeldKeysProblem(hotkey)
        if (problem = "")
            problem := this._delivery.TargetProblem()   ; checked after the wait: the window you're in once you let go
        if (problem != "") {
            this._tips.Show(problem)
            return
        }
        text := this._items.Peek()
        record := this._delivery.Deliver(text, this._prefs.Get("AdvanceMode"), this._prefs.Get("DeliveryMode"))
        if !IsObject(record) {
            this._tips.Show("Paste failed, see error.log")
            return
        }
        this._items.Advance()                       ; KIND_ADVANCE keeps the undo history
        this._undo.Push(record)
        pos := this._items.GetPosition()
        count := this._items.GetCount()
        this._tips.Show(pos " / " count ":  " text (pos = count ? "   (list complete)" : ""))
    }

    Undo(hotkey := "") {
        Critical
        if !this._undo.Length {
            this._tips.Show("Nothing to undo")
            return
        }
        problem := this._delivery.HeldKeysProblem(hotkey)
        if (problem != "") {
            this._tips.Show(problem)
            return
        }
        record := this._undo.Pop()
        result := this._delivery.Erase(record)
        if (result.reason = "window") {
            this._undo.Push(record)
            this._tips.Show("Undo: switch back to the window you pasted into")
            return
        }
        this._items.StepBack(Constants.KIND_UNDO)
        next := this._items.GetPosition() + 1
        count := this._items.GetCount()
        if result.erased
            this._tips.Show("Undone: " record.text "   (next " next "/" count ")")
        else
            this._tips.Show("Moved back to " next "/" count ". Erase it manually (" result.reason ")")
    }

    ; --- Public Methods: tray menu and extra shortcuts ---
    Back() {
        if !this._items.StepBack(Constants.KIND_BACK)
            return
        this._tips.Show("Next paste: item " (this._items.GetPosition() + 1))
    }

    Reset() {
        this._items.Reset()
        this._tips.Show("Back to top")
    }

    ForceLoad() {
        this._delivery.RestoreNow()                 ; NOTE: timers pause while a menu is open, so a pending restore may not have run
        lines := this._items.ParseLines(this._clip.ReadText())
        if !lines.Length {
            this._tips.Show("Clipboard has no text")
            return
        }
        if !this._MayReplace("Replace")             ; lines were read before asking, so the prompt can't change them
            return
        this._items.Load(lines)
        this._tips.Show(this._LoadedMessage(lines.Length))
    }

    ClearList() {
        if this._items.IsEmpty()
            return
        if !this._MayReplace("Clear")
            return
        this._items.Load([])
        this._tips.Show("List cleared")
    }

    ; True when it's fine to exit; asks first if an unfinished list would be lost.
    ConfirmExit() {
        if (!this._items.IsUnfinished() || this._prefs.Get("RememberList") = 1)
            return true
        question := "Exit and discard your unfinished list? (" this._DoneText() ")`n`nTo keep lists between restarts, turn on 'Remember list after exit' in the tray menu."
        return this._tips.Confirm(question)
    }

    CycleAdvance() {
        modes := Constants.ADVANCE_MODES
        current := this._prefs.Get("AdvanceMode")
        nextMode := modes[1]
        for i, mode in modes {
            if (mode = current) {
                nextMode := modes[Mod(i, modes.Length) + 1]
                break
            }
        }
        this._prefs.Set("AdvanceMode", nextMode)
        this._tips.Show("Auto-advance: " nextMode)
    }

    ToggleDelivery() {
        nextMode := (this._prefs.Get("DeliveryMode") = "Type") ? "Paste" : "Type"
        this._prefs.Set("DeliveryMode", nextMode)
        this._tips.Show(nextMode = "Paste" ? "Mode: Paste (clipboard)" : "Mode: Type")
    }

    ; --- Public Methods: events ---
    OnClipboardText(text) {
        if this._paused
            return
        lines := this._items.ParseLines(text)
        if (lines.Length < 2)
            return                                  ; single-line copies never replace the list
        if this._items.IsUnfinished() {
            this._tips.Show("Kept your unfinished list (" this._DoneText() "). Tray menu → Load from clipboard replaces it.")
            return
        }
        this._items.Load(lines)
        this._tips.Show(this._LoadedMessage(lines.Length))
    }

    OnListChanged(kind) {
        if (kind != Constants.KIND_ADVANCE && kind != Constants.KIND_UNDO)
            this._undo := []                        ; position moved some other way: old records no longer match
    }

    OnPausedChanged(paused) {
        this._paused := paused ? true : false
    }

    ; --- Private Methods ---
    _MayReplace(verb) {
        if !this._items.IsUnfinished()
            return true
        return this._tips.Confirm(verb " your unfinished list? (" this._DoneText() ")")
    }

    _DoneText() => this._items.GetPosition() " of " this._items.GetCount() " done"

    _LoadedMessage(count) {
        return "Loaded " count (count = 1 ? " item" : " items")
    }

    _LogError(caller, message) {
        FileAppend(FormatTime(, "yyyy-MM-dd HH:mm:ss") " ERROR [" caller "]: " message "`n", A_ScriptDir "\" Constants.ERROR_LOG)
    }
}
