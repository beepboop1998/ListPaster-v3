#Requires AutoHotkey v2.0
#SingleInstance Force

/*
    Main.ahk
    Responsibility: Wire ListPaster's dependencies, start services, register shortcuts and the tray menu. No logic.
    Dependencies: every module below
    Shortcuts: Ctrl+Shift+V paste next | Ctrl+Alt+Z undo (left Alt). Everything else is in the tray menu;
               "Extra hotkeys" there adds Ctrl+Alt+B/R/L/A/P/W/G.
*/

#Include Constants.ahk
#Include lib\SequenceBuilder.ahk
#Include services\TimingEngine.ahk
#Include services\InputSender.ahk
#Include services\Notifier.ahk
#Include services\ClipboardService.ahk
#Include services\WindowProbe.ahk
#Include services\ItemList.ahk
#Include services\Settings.ahk
#Include services\DeliveryService.ahk
#Include services\PasteController.ahk
#Include services\ListStore.ahk
#Include services\HotkeyManager.ahk
#Include gui\ListWindow.ahk
#Include gui\SequenceDialog.ahk
#Include gui\TrayMenu.ahk

; --- Instances (names must not equal class names: AHK v2 names are case-insensitive) ---
timer      := TimingEngine()
sender     := InputSender()
tips       := Notifier(timer)
clip       := ClipboardService()
probe      := WindowProbe()
items      := ItemList()
prefs      := Settings(A_ScriptDir "\" Constants.SETTINGS_FILE)
delivery   := DeliveryService(sender, clip, timer, prefs, probe)
controller := PasteController(items, delivery, clip, tips, prefs)
store      := ListStore(items, timer, tips, prefs, A_ScriptDir "\" Constants.LIST_FILE, A_ScriptDir "\" Constants.SESSION_FILE)
listWin    := ListWindow(items, prefs, timer)
seqBuilder := SequenceBuilder()
seqDialog  := SequenceDialog(items, seqBuilder, tips)
hotkeys    := HotkeyManager(prefs, tips)
actions    := Map(
    "show",     (*) => listWin.Show(),
    "generate", (*) => seqDialog.Show(),
    "load",     (*) => controller.ForceLoad(),
    "back",     (*) => controller.Back(),
    "restart",  (*) => controller.Reset(),
    "clear",    (*) => controller.ClearList(),
    "exit",     (*) => controller.ConfirmExit() && ExitApp()
)
tray       := TrayMenu(items, prefs, hotkeys, timer, actions)

; --- Event wiring ---
items.OnChange(ObjBindMethod(controller, "OnListChanged"))
items.OnChange(ObjBindMethod(store, "OnListChanged"))
items.OnChange(ObjBindMethod(listWin, "OnListChanged"))
items.OnChange(ObjBindMethod(tray, "OnListChanged"))
prefs.OnChange(ObjBindMethod(listWin, "OnSettingsChanged"))
prefs.OnChange(ObjBindMethod(store, "OnSettingsChanged"))
prefs.OnChange(ObjBindMethod(hotkeys, "OnSettingsChanged"))
prefs.OnChange(ObjBindMethod(tray, "OnSettingsChanged"))
hotkeys.OnPausedChanged(ObjBindMethod(controller, "OnPausedChanged"))
hotkeys.OnPausedChanged(ObjBindMethod(tray, "OnPausedChanged"))

; --- Shortcuts (core = always on; extra = only while "Extra hotkeys" is ticked in the tray menu) ---
hotkeys.Add(Constants.HK_PASTE_NEXT, "Paste next", (*) => controller.PasteNext(), "core")
hotkeys.Add(Constants.HK_UNDO, "Undo last paste", (*) => controller.Undo(), "core")
hotkeys.Add(Constants.HK_BACK, "Step back", (*) => controller.Back(), "extra")
hotkeys.Add(Constants.HK_RESET, "Restart at top", (*) => controller.Reset(), "extra")
hotkeys.Add(Constants.HK_FORCE_LOAD, "Load from clipboard", (*) => controller.ForceLoad(), "extra")
hotkeys.Add(Constants.HK_CYCLE_ADVANCE, "Cycle auto-advance", (*) => controller.CycleAdvance(), "extra")
hotkeys.Add(Constants.HK_TOGGLE_DELIVERY, "Switch Type/Paste", (*) => controller.ToggleDelivery(), "extra")
hotkeys.Add(Constants.HK_TOGGLE_WINDOW, "Show/hide list window", (*) => listWin.Toggle(), "extra")
hotkeys.Add(Constants.HK_SEQUENCE, "Generate list", (*) => seqDialog.Show(), "extra")

; --- Startup (order matters: settings, timer, saved list, window, shortcuts, tray, then clipboard monitoring) ---
prefs.Load()
timer.Start()
store.Resume()
listWin.Start()
hotkeys.RegisterAll()
tray.Start()
clip.StartMonitoring(ObjBindMethod(controller, "OnClipboardText"))
OnExit((*) => (delivery.RestoreNow(), store.Flush(), listWin.SaveGeometry(), 0))    ; must end with 0 or exit is cancelled
