/*
    PasteController.ahk
    Responsibility: hotkey and clipboard-event actions (paste, undo, back, reset, load, mode toggles, list lock).
    Dependencies: ItemList, DeliveryService, ClipboardService, Notifier, Settings
*/
class PasteController {
    ; --- Properties ---
    _items := ""        ; ItemList
    _delivery := ""     ; DeliveryService
    _clip := ""          ; ClipboardService
    _tips := ""          ; Notifier
    _prefs := ""         ; Settings
    _undo := []          ; delivery records, newest last

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

    ; --- Public Methods: hotkeys ---
    PasteNext() {
        Critical                                    ; other hotkeys and clipboard events wait until this finishes
        if this._items.IsEmpty() {
            this._tips.Show("No list loaded. Copy a multi-line list first")
            return
        }
        if this._items.IsFinished() {
            this._tips.Show("End of list (Ctrl+Alt+R to restart)")
            return
        }
        text := this._items.Peek()
        record := this._delivery.Deliver(text, this._prefs.Get("AdvanceMode"), this._prefs.Get("DeliveryMode"))
        if !IsObject(record) {
            this._tips.Show("Paste failed, see error.log")
            return
        }
        this._items.Advance()                       ; KIND_ADVANCE keeps the undo stack
        this._undo.Push(record)
        pos := this._items.GetPosition()
        count := this._items.GetCount()
        this._tips.Show(pos " / " count ":  " text (pos = count ? "   (done)" : ""))
    }

    Undo() {
        Critical
        if !this._undo.Length {
            this._tips.Show("Nothing to undo")
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
        lines := this._items.ParseLines(this._clip.ReadText())
        if !lines.Length {
            this._tips.Show("Clipboard has no text")
            return
        }
        this._items.Load(lines)
        this._tips.Show(this._LoadedMessage(lines.Length))
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
        lines := this._items.ParseLines(text)
        if (lines.Length < 2)
            return                                  ; single-line copies never replace the list
        if this._items.IsMidList() {
            this._tips.Show("List locked at " this._items.GetPosition() "/" this._items.GetCount() ". Ctrl+Alt+L to replace")
            return
        }
        this._items.Load(lines)
        this._tips.Show(this._LoadedMessage(lines.Length))
    }

    OnListChanged(kind) {
        if (kind != Constants.KIND_ADVANCE && kind != Constants.KIND_UNDO)
            this._undo := []                        ; position moved some other way: old records no longer match
    }

    ; --- Private Methods ---
    _LoadedMessage(count) {
        return "Loaded " count (count = 1 ? " item" : " items")
    }

    _LogError(caller, message) {
        FileAppend(FormatTime(, "yyyy-MM-dd HH:mm:ss") " ERROR [" caller "]: " message "`n", A_ScriptDir "\" Constants.ERROR_LOG)
    }
}
