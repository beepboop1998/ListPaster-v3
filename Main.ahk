#Requires AutoHotkey v2.0
#SingleInstance Force

/*
    Main.ahk
    Responsibility: Wire ListPaster v3 dependencies, start services, register hotkeys. No logic.
    Dependencies: every module below
    Hotkeys: Ctrl+Shift+V paste next | Ctrl+Alt+Z undo | Ctrl+Alt+B back | Ctrl+Alt+R restart |
             Ctrl+Alt+L force-load | Ctrl+Alt+A auto-advance | Ctrl+Alt+P Type/Paste |
             Ctrl+Alt+W list window | Ctrl+Alt+G sequence generator
*/

#Include Constants.ahk
#Include lib\SequenceBuilder.ahk
#Include services\TimingEngine.ahk
#Include services\InputSender.ahk
#Include services\Notifier.ahk
#Include services\ClipboardService.ahk
#Include services\ItemList.ahk
#Include services\Settings.ahk
#Include services\DeliveryService.ahk
#Include services\PasteController.ahk
#Include services\ListStore.ahk
#Include gui\ListWindow.ahk
#Include gui\SequenceDialog.ahk

; --- Instances (names must not equal class names: AHK v2 names are case-insensitive) ---
timer      := TimingEngine()
sender     := InputSender()
tips       := Notifier(timer)
clip       := ClipboardService()
items      := ItemList()
prefs      := Settings(A_ScriptDir "\" Constants.SETTINGS_FILE)
delivery   := DeliveryService(sender, clip, timer, prefs)
controller := PasteController(items, delivery, clip, tips, prefs)
store      := ListStore(items, timer, tips, A_ScriptDir "\" Constants.LIST_FILE, A_ScriptDir "\" Constants.SESSION_FILE)
listWin    := ListWindow(items, prefs, timer)
seqBuilder := SequenceBuilder()
seqDialog  := SequenceDialog(items, seqBuilder, tips)

; --- Event wiring ---
items.OnChange(ObjBindMethod(controller, "OnListChanged"))
items.OnChange(ObjBindMethod(store, "OnListChanged"))
items.OnChange(ObjBindMethod(listWin, "OnListChanged"))
prefs.OnChange(ObjBindMethod(listWin, "OnSettingsChanged"))

; --- Startup (order matters: settings, timer, resume, window, then clipboard monitoring) ---
A_IconTip := Constants.APP_NAME " v" Constants.VERSION
prefs.Load()
timer.Start()
store.Resume()
listWin.Start()
clip.StartMonitoring(ObjBindMethod(controller, "OnClipboardText"))
OnExit((*) => (store.Flush(), listWin.SaveGeometry(), 0))

; --- Hotkeys ---
Hotkey(Constants.HK_PASTE_NEXT, (*) => controller.PasteNext())
Hotkey(Constants.HK_UNDO, (*) => controller.Undo())
Hotkey(Constants.HK_BACK, (*) => controller.Back())
Hotkey(Constants.HK_RESET, (*) => controller.Reset())
Hotkey(Constants.HK_FORCE_LOAD, (*) => controller.ForceLoad())
Hotkey(Constants.HK_CYCLE_ADVANCE, (*) => controller.CycleAdvance())
Hotkey(Constants.HK_TOGGLE_DELIVERY, (*) => controller.ToggleDelivery())
Hotkey(Constants.HK_TOGGLE_WINDOW, (*) => listWin.Toggle())
Hotkey(Constants.HK_SEQUENCE, (*) => seqDialog.Show())
