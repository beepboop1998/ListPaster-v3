#Requires AutoHotkey v2.0
#SingleInstance Off
#NoTrayIcon
#Warn All, StdOut

/*
    RunTests.ahk
    Responsibility: Headless automated tests for ListPaster's logic. Fakes stand in for keystrokes,
                    the clipboard, windows, prompts and timers, so nothing on the desktop is touched.
    Usage (Git Bash): "/c/Program Files/AutoHotkey/v2/AutoHotkey64.exe" /ErrorStdOut tests/RunTests.ahk | cat
    Exit code = number of failed checks.
*/

#Include %A_ScriptDir%\..\Constants.ahk
#Include %A_ScriptDir%\..\lib\SequenceBuilder.ahk
#Include %A_ScriptDir%\..\services\ItemList.ahk
#Include %A_ScriptDir%\..\services\Settings.ahk
#Include %A_ScriptDir%\..\services\ClipboardService.ahk
#Include %A_ScriptDir%\..\services\DeliveryService.ahk
#Include %A_ScriptDir%\..\services\PasteController.ahk
#Include %A_ScriptDir%\..\services\ListStore.ahk

OnError(ReportUncaught)
ResetTestFiles()

RunTest("A1 List rules", Test_A1_ListRules)
RunTest("A2 Empty list", Test_A2_EmptyList)
RunTest("A3 End of list", Test_A3_EndOfList)
RunTest("A4 Detectable failures and paste guard", Test_A4_FailuresAndGuard)
RunTest("A5 Undo vs Step back", Test_A5_UndoVsStepBack)
RunTest("A6 Undo keys", Test_A6_UndoKeys)
RunTest("A7 Type and Paste delivery", Test_A7_Delivery)
RunTest("A8 Repeated presses", Test_A8_RepeatedPresses)
RunTest("A9 Replacing an unfinished list", Test_A9_UnfinishedList)
RunTest("A10 Settings", Test_A10_Settings)
RunTest("A11 Persistence", Test_A11_Persistence)
RunTest("A14 Generator", Test_A14_Generator)
RunTest("A15 Clipboard ownership and history markers", Test_A15_ClipboardOwnership)

Finish()

; =====================================================================================
; Tests
; =====================================================================================

Test_A1_ListRules() {
    lst := ItemList()
    lines := lst.ParseLines("one`r`n`r`n  two  `n`t`n   `nthree`tcol2`n")
    Assert.Eq(lines.Length, 3, "blank and whitespace-only lines are skipped")
    Assert.Eq(lines[1], "one", "CRLF line ending is stripped")
    Assert.Eq(lines[2], "  two  ", "leading and trailing spaces are kept")
    Assert.Eq(lines[3], "three`tcol2", "a tab inside an item is kept (one item per line)")
    Assert.Eq(lst.ParseLines("a`nb").Length, 2, "LF-only text splits into lines")

    lst.Load(["a", "b", "c"])
    Assert.Eq(lst.IsUnfinished(), 1, "a loaded but unstarted list is unfinished")
    lst.Advance(), lst.Advance()
    Assert.Eq(lst.IsUnfinished(), 1, "a list mid-way is unfinished")
    lst.Advance()
    Assert.Eq(lst.Advance(), 0, "no advance past the last item (never wraps)")
    Assert.Eq(lst.GetPosition(), 3, "position stays at the item count at the end")
    Assert.Eq(lst.IsFinished(), 1, "list reports complete")
    Assert.Eq(lst.IsUnfinished(), 0, "a complete list is not unfinished")

    lst.Reset()
    Assert.Eq(lst.StepBack(Constants.KIND_BACK), 0, "step back stops at position 0")
    Assert.Eq(ItemList().IsUnfinished(), 0, "an empty list is not unfinished")
}

Test_A2_EmptyList() {
    env := NewControllerEnv()
    env.ctl.PasteNext()
    Assert.Contains(env.tips.Last(), "No list loaded", "pasting with no list explains what to do")
    Assert.Eq(env.delivery.delivered.Length, 0, "nothing is sent with no list")
    env.ctl.Back()
    Assert.Eq(env.items.GetPosition(), 0, "step back with no list does nothing")
    env.ctl.ClearList()
    Assert.Eq(env.tips.confirms.Length, 0, "clearing an empty list asks nothing")
    env.ctl.Undo()
    Assert.Eq(env.tips.Last(), "Nothing to undo", "undo with no list has nothing to do")
}

Test_A3_EndOfList() {
    env := NewControllerEnv()
    env.items.Load(["a", "b", "c"])
    positions := ""
    loop 3 {
        env.ctl.PasteNext()
        positions .= env.items.GetPosition()
    }
    Assert.Eq(positions, "123", "each paste advances by exactly one")
    Assert.Contains(env.tips.Last(), "(list complete)", "the last paste says the list is complete")
    env.ctl.PasteNext()
    Assert.Contains(env.tips.Last(), "List complete (3 of 3)", "a press after the end says List complete")
    Assert.Eq(env.delivery.delivered.Length, 3, "nothing is sent after the end (no wrap)")
    Assert.Eq(env.items.GetPosition(), 3, "position stays at the end")
}

Test_A4_FailuresAndGuard() {
    env := NewControllerEnv()
    env.items.Load(["a", "b"])
    env.delivery.failNext := true
    env.ctl.PasteNext()
    Assert.Eq(env.items.GetPosition(), 0, "a failed delivery doesn't advance")
    Assert.Contains(env.tips.Last(), "Paste failed", "a failed delivery is reported")
    env.ctl.PasteNext()
    Assert.Eq(Join(env.delivery.delivered), "a", "the next press retries the same item")
    env.delivery.problem := "Click into the field you want to fill first."
    env.ctl.PasteNext()
    Assert.Eq(Join(env.delivery.delivered), "a", "nothing is sent while focus is somewhere unsafe")
    Assert.Eq(env.items.GetPosition(), 1, "a refused paste doesn't advance")
    Assert.Eq(env.tips.Last(), env.delivery.problem, "the refusal message is shown")

    dEnv := NewDeliveryEnv()
    own := 1000
    Assert.Eq(dEnv.dlv.ClassifyTarget("", own), "none", "no active window is refused")
    Assert.Eq(dEnv.dlv.ClassifyTarget({hwnd: 5, pid: own, cls: "AutoHotkeyGUI", exe: "AutoHotkey64.exe"}, own), "self", "ListPaster's own windows and menus are refused")
    for cls in ["Shell_TrayWnd", "Shell_SecondaryTrayWnd", "NotifyIconOverflowWindow", "TopLevelWindowForOverflowXamlIsland", "XamlExplorerHostIslandWindow", "Progman", "WorkerW"]
        Assert.Eq(dEnv.dlv.ClassifyTarget({hwnd: 5, pid: 2, cls: cls, exe: "explorer.exe"}, own), "shell", "Explorer's " cls " is refused")
    for exe in ["StartMenuExperienceHost.exe", "SearchHost.exe", "ShellExperienceHost.exe"]
        Assert.Eq(dEnv.dlv.ClassifyTarget({hwnd: 5, pid: 2, cls: "Windows.UI.Core.CoreWindow", exe: exe}, own), "shell", exe " is refused")
    Assert.Eq(dEnv.dlv.ClassifyTarget({hwnd: 5, pid: 2, cls: "Windows.UI.Core.CoreWindow", exe: "SomeStoreApp.exe"}, own), "", "a Store app that uses CoreWindow is allowed")
    Assert.Eq(dEnv.dlv.ClassifyTarget({hwnd: 5, pid: 2, cls: "Shell_TrayWnd", exe: "other.exe"}, own), "", "a shell class name in another process is allowed")
    Assert.Eq(dEnv.dlv.ClassifyTarget({hwnd: 5, pid: 2, cls: "Notepad", exe: "notepad.exe"}, own), "", "a normal app is allowed")
    Assert.Eq(dEnv.dlv.TargetProblem(), "", "TargetProblem is empty for a normal app")
    dEnv.probe.info := {hwnd: 5, pid: dEnv.probe.selfPid, cls: "AutoHotkeyGUI", exe: "AutoHotkey64.exe"}
    Assert.Contains(dEnv.dlv.TargetProblem(), "Click into the field", "TargetProblem explains a refusal")
}

Test_A5_UndoVsStepBack() {
    env := NewControllerEnv()
    env.items.Load(["a", "b", "c"])
    env.ctl.PasteNext(), env.ctl.PasteNext()
    env.ctl.Undo()
    Assert.Eq(env.items.GetPosition(), 1, "undo moves the position back one")
    env.ctl.Undo()
    Assert.Eq(Join(env.delivery.erased), "b|a", "undo erases the newest insert first")
    Assert.Eq(env.items.GetPosition(), 0, "two undos return to the start")
    env.ctl.Undo()
    Assert.Eq(env.tips.Last(), "Nothing to undo", "a third undo has nothing left")

    env.ctl.PasteNext(), env.ctl.PasteNext()
    erasedBefore := env.delivery.erased.Length
    env.ctl.Back()
    Assert.Eq(env.items.GetPosition(), 1, "step back moves the position back one")
    Assert.Eq(env.delivery.erased.Length, erasedBefore, "step back sends no erase keys")
    env.ctl.Undo()
    Assert.Eq(env.tips.Last(), "Nothing to undo", "step back clears the undo history")

    env.ctl.PasteNext()
    env.delivery.eraseResult := {erased: false, reason: "window"}
    env.ctl.Undo()
    Assert.Eq(env.items.GetPosition(), 2, "undo while another window is active changes nothing")
    Assert.Contains(env.tips.Last(), "switch back", "and says to switch back")
    env.delivery.eraseResult := {erased: false, reason: "Enter may have submitted"}
    env.ctl.Undo()
    Assert.Eq(env.items.GetPosition(), 1, "the kept record can still be undone later; undo that can't erase moves back")
    Assert.Contains(env.tips.Last(), "Erase it manually (Enter may have submitted)", "and says to erase manually")

    dEnv := NewDeliveryEnv()
    rec := dEnv.dlv.Deliver("abc", "None", "Type")
    Assert.True(dEnv.timer.Has("focusRecord"), "the focused field is read shortly after a paste")
    dEnv.timer.Run("focusRecord")
    Assert.Eq(rec.focusCtrl, dEnv.probe.focus, "the focused field is recorded")
    res := dEnv.dlv.Erase(rec)
    Assert.Eq(res.erased, 1, "undo in the same window and field erases")
    Assert.Eq(dEnv.sender.LastCall(), "keys:{BS 3}", "undo sends Backspace x item length")
    dEnv.probe.info.hwnd := 999
    Assert.Eq(dEnv.dlv.Erase(rec).reason, "window", "undo refuses while another window is active")
    dEnv.probe.info.hwnd := rec.hwnd
    dEnv.probe.focus := rec.focusCtrl + 1
    callsBefore := dEnv.sender.calls.Length
    Assert.Eq(dEnv.dlv.Erase(rec).reason, "you moved to another field", "undo won't erase after a field change")
    Assert.Eq(dEnv.sender.calls.Length, callsBefore, "no keys are sent after a field change")
    dEnv.probe.focus := rec.focusCtrl
    tabRec := {text: "x`ty", advance: "None", mode: "Type", app: "other", hwnd: rec.hwnd, focusCtrl: 0}
    Assert.Eq(dEnv.dlv.Erase(tabRec).reason, "item contains tabs", "items with tabs are not erased")
    enterRec := {text: "abc", advance: "Enter", mode: "Type", app: "other", hwnd: rec.hwnd, focusCtrl: 0}
    Assert.Eq(dEnv.dlv.Erase(enterRec).reason, "Enter may have submitted", "Enter outside a spreadsheet is not erased")
    unknownRec := {text: "abc", advance: "None", mode: "Type", app: "other", hwnd: rec.hwnd, focusCtrl: 0}
    dEnv.probe.focus := 12345
    Assert.Eq(dEnv.dlv.Erase(unknownRec).erased, 1, "with no recorded field, undo still works")
}

Test_A6_UndoKeys() {
    dEnv := NewDeliveryEnv()
    expected := Map(
        "sheet|None|Type", "{Esc}", "sheet|None|Paste", "{Delete}",
        "sheet|Tab|Type", "+{Tab}{Delete}", "sheet|Tab|Paste", "+{Tab}{Delete}",
        "sheet|Enter|Type", "{Up}{Delete}", "sheet|Enter|Paste", "{Up}{Delete}",
        "other|None|Type", "{BS 3}", "other|None|Paste", "{BS 3}",
        "other|Tab|Type", "+{Tab}{End}{BS 3}", "other|Tab|Paste", "+{Tab}{End}{BS 3}",
        "other|Enter|Type", "", "other|Enter|Paste", ""
    )
    for combo, keys in expected {
        parts := StrSplit(combo, "|")
        rec := {text: "abc", app: parts[1], advance: parts[2], mode: parts[3]}
        Assert.Eq(dEnv.dlv._UndoKeys(rec), keys, "undo keys for " combo)
    }
}

Test_A7_Delivery() {
    for mode, keysAfter in Map("None", "", "Tab", "|keys:{Tab}", "Enter", "|keys:{Enter}") {
        dEnv := NewDeliveryEnv()
        dEnv.dlv.Deliver("abc", mode, "Type")
        Assert.Eq(Join(dEnv.sender.calls), "type:abc" keysAfter, "Type mode, auto-advance " mode)
        Assert.Eq(dEnv.clip.setTexts.Length, 0, "Type mode never touches the clipboard (" mode ")")
    }

    dEnv := NewDeliveryEnv()
    dEnv.dlv.Deliver("one", "Tab", "Paste")
    Assert.Eq(Join(dEnv.sender.calls), "keys:^v|keys:{Tab}", "Paste mode sends Ctrl+V, then the advance key")
    Assert.Eq(Join(dEnv.clip.setTexts), "one", "Paste mode puts the item on the clipboard")
    Assert.Eq(dEnv.clip.saves, 1, "your clipboard is saved before the first paste")
    Assert.True(dEnv.timer.Has("clipRestore"), "a restore is scheduled after a paste")
    dEnv.dlv.Deliver("two", "Tab", "Paste")
    Assert.Eq(dEnv.clip.saves, 1, "one save per burst of pastes")
    dEnv.clip.changes += 1
    dEnv.dlv.Deliver("three", "Tab", "Paste")
    Assert.Eq(dEnv.clip.saves, 2, "a copy made mid-burst is saved again, so it's what comes back")
    dEnv.timer.Run("clipRestore")
    Assert.Eq(dEnv.clip.restores.Length, 1, "the clipboard is restored after the burst")
    dEnv.dlv.Deliver("four", "None", "Paste")
    dEnv.clip.changes += 1
    dEnv.timer.Run("clipRestore")
    Assert.Eq(dEnv.clip.restores.Length, 1, "a copy made after the last paste is kept (no restore)")

    dEnv := NewDeliveryEnv()
    dEnv.clip.failSet := true
    Assert.Eq(dEnv.dlv.Deliver("x", "None", "Paste"), "", "a clipboard failure fails the delivery")
    Assert.Eq(dEnv.sender.calls.Length, 0, "Ctrl+V isn't sent when the clipboard couldn't be set")

    dEnv := NewDeliveryEnv()
    dEnv.dlv.Deliver("x", "None", "Paste")
    dEnv.dlv.RestoreNow()
    Assert.Eq(dEnv.clip.restores.Length, 1, "RestoreNow applies a pending restore")
    Assert.Eq(dEnv.timer.Has("clipRestore"), 0, "RestoreNow cancels the scheduled restore")
    dEnv.dlv.RestoreNow()
    Assert.Eq(dEnv.clip.restores.Length, 1, "RestoreNow with nothing pending does nothing")
}

Test_A8_RepeatedPresses() {
    env := NewControllerEnv()
    names := []
    loop 20
        names.Push("item" A_Index)
    env.items.Load(names)
    loop 20
        env.ctl.PasteNext()
    Assert.Eq(Join(env.delivery.delivered), Join(names), "20 presses insert 20 items in order, none skipped or doubled")
    Assert.Eq(env.items.GetPosition(), 20, "position matches the number of presses")
}

Test_A9_UnfinishedList() {
    env := NewControllerEnv()
    env.ctl.OnClipboardText("one`ntwo")
    Assert.Eq(env.items.GetCount(), 2, "a copied list loads when there's no list")
    env.ctl.OnClipboardText("p`nq`nr")
    Assert.Eq(env.items.GetCount(), 2, "a copied list doesn't replace an unstarted list")
    Assert.Contains(env.tips.Last(), "Kept your unfinished list (0 of 2 done)", "and says why")
    env.ctl.PasteNext()
    env.ctl.OnClipboardText("p`nq`nr")
    Assert.Eq(Join(env.items.ToArray()), "one|two", "a copied list doesn't replace a list mid-way")
    env.ctl.PasteNext()
    env.ctl.OnClipboardText("p`nq`nr")
    Assert.Eq(Join(env.items.ToArray()), "p|q|r", "a copied list replaces a complete list")
    Assert.Eq(env.items.GetPosition(), 0, "a new list starts at item 1")
    env.ctl.OnClipboardText("single line")
    Assert.Eq(env.items.GetCount(), 3, "a single-line copy never loads")

    env := NewControllerEnv()
    env.ctl.OnPausedChanged(true)
    env.ctl.OnClipboardText("one`ntwo")
    Assert.Eq(env.items.GetCount(), 0, "copies are ignored while paused")
    env.ctl.OnPausedChanged(false)
    env.ctl.OnClipboardText("one`ntwo")
    Assert.Eq(env.items.GetCount(), 2, "copies load again after resuming")

    env := NewControllerEnv()
    env.clip.text := "last pasted item"
    env.delivery.restoreText := "r1`nr2"
    env.ctl.ForceLoad()
    Assert.Eq(env.delivery.restoreNowCalls, 1, "Load applies a pending clipboard restore first")
    Assert.Eq(Join(env.items.ToArray()), "r1|r2", "Load reads your restored clipboard, not the last pasted item")
    Assert.Eq(env.tips.confirms.Length, 0, "no question when nothing would be lost")

    env.delivery.restoreText := ""
    env.clip.text := "n1`nn2`nn3"
    env.tips.answer := false
    env.ctl.ForceLoad()
    Assert.Eq(env.tips.confirms.Length, 1, "Load asks before replacing an unfinished list")
    Assert.Contains(env.tips.confirms.Length ? env.tips.confirms[1] : "", "Replace your unfinished list? (0 of 2 done)", "the question shows progress")
    Assert.Eq(Join(env.items.ToArray()), "r1|r2", "answering No keeps the list")
    env.tips.answer := true
    env.tips.onConfirm := (*) => env.clip.text := "changed during the prompt"
    env.ctl.ForceLoad()
    Assert.Eq(Join(env.items.ToArray()), "n1|n2|n3", "Yes loads the text read before the prompt")
    env.tips.onConfirm := ""

    env.ctl.PasteNext()
    env.tips.answer := false
    env.ctl.ClearList()
    Assert.Eq(env.items.GetCount(), 3, "No keeps the list when clearing")
    env.tips.answer := true
    env.ctl.ClearList()
    Assert.Eq(env.items.GetCount(), 0, "Yes clears the list")

    env := NewControllerEnv()
    Assert.Eq(env.ctl.ConfirmExit(), 1, "exit with no list doesn't ask")
    env.items.Load(["a", "b"])
    env.tips.answer := false
    Assert.Eq(env.ctl.ConfirmExit(), 0, "exit with an unfinished list asks; No cancels")
    env.tips.answer := true
    Assert.Eq(env.ctl.ConfirmExit(), 1, "Yes exits")
    asked := env.tips.confirms.Length
    env.prefs.Set("RememberList", 1)
    Assert.Eq(env.ctl.ConfirmExit(), 1, "exit doesn't ask when the list will be remembered")
    Assert.Eq(env.tips.confirms.Length, asked, "no question when Remember is on")
}

Test_A10_Settings() {
    ini := FreshIni()
    prefs := Settings(ini)
    prefs.Load()
    Assert.Eq(prefs.Get("AdvanceMode"), "None", "default auto-advance is None")
    Assert.Eq(prefs.Get("DeliveryMode"), "Type", "default insert mode is Type")
    for key in ["ExtraHotkeys", "ShowNextInTooltip", "RememberList"]
        Assert.Eq(prefs.Get(key), 0, key " is off by default")

    for key in ["ExtraHotkeys", "ShowNextInTooltip", "RememberList"]
        prefs.Set(key, 1)
    prefs.Set("AdvanceMode", "tab")
    reloaded := Settings(ini)
    reloaded.Load()
    for key in ["ExtraHotkeys", "ShowNextInTooltip", "RememberList"]
        Assert.Eq(reloaded.Get(key), 1, key " survives a restart")
    Assert.Eq(reloaded.Get("AdvanceMode"), "Tab", "mode names are stored with canonical spelling")

    IniWrite("Sideways", ini, "Settings", "AdvanceMode")
    IniWrite("7", ini, "Settings", "RememberList")
    IniWrite("yes", ini, "Settings", "ExtraHotkeys")
    bad := Settings(ini)
    bad.Load()
    Assert.Eq(bad.Get("AdvanceMode"), "None", "an invalid auto-advance value falls back to None")
    Assert.Eq(bad.Get("RememberList"), 0, "an out-of-range toggle falls back to off")
    Assert.Eq(bad.Get("ExtraHotkeys"), 0, "a non-numeric toggle falls back to off")

    env := NewControllerEnv()
    seen := ""
    loop 4 {
        seen .= env.prefs.Get("AdvanceMode") ">"
        env.ctl.CycleAdvance()
    }
    Assert.Eq(seen, "None>Tab>Enter>None>", "auto-advance cycles None, Tab, Enter, None")
    env.ctl.ToggleDelivery()
    Assert.Eq(env.prefs.Get("DeliveryMode"), "Paste", "Type switches to Paste")
    env.ctl.ToggleDelivery()
    Assert.Eq(env.prefs.Get("DeliveryMode"), "Type", "Paste switches back to Type")
}

Test_A11_Persistence() {
    paths := StorePaths()
    prefs := NewPrefs()
    lst := ItemList()
    timer := FakeTimer()
    store := ListStore(lst, timer, FakeTips(), prefs, paths.list, paths.session)
    lst.OnChange(ObjBindMethod(store, "OnListChanged"))
    prefs.OnChange(ObjBindMethod(store, "OnSettingsChanged"))
    store.Resume()
    lst.Load(["a", "b"])
    Assert.Eq(timer.Has("listSave"), 0, "with Remember off, no save is scheduled")
    store.Flush()
    Assert.Eq(FileExist(paths.list) ? 1 : 0, 0, "with Remember off, nothing is written on exit")

    FileAppend("x`r`ny`r`nz", paths.list, "UTF-8")
    IniWrite(1, paths.session, "Session", "Position")
    lst2 := ItemList()
    tips2 := FakeTips()
    store2 := ListStore(lst2, FakeTimer(), tips2, NewPrefs(), paths.list, paths.session)
    store2.Resume()
    Assert.Eq(Join(lst2.ToArray()) " @" lst2.GetPosition(), "x|y|z @1", "a list saved earlier is loaded into this session")
    Assert.Eq((FileExist(paths.list) || FileExist(paths.session)) ? 1 : 0, 0, "and its files are deleted")
    Assert.Eq(tips2.alerts.Length, 1, "you're told once")
    Assert.Contains(tips2.alerts.Length ? tips2.alerts[1] : "", "(1 of 3 done)", "the message shows the list's progress")

    prefs3 := NewPrefs()
    lst3 := ItemList()
    timer3 := FakeTimer()
    store3 := ListStore(lst3, timer3, FakeTips(), prefs3, paths.list, paths.session)
    lst3.OnChange(ObjBindMethod(store3, "OnListChanged"))
    prefs3.OnChange(ObjBindMethod(store3, "OnSettingsChanged"))
    lst3.Load(["k1", "k2", "k3"])
    lst3.Advance()
    prefs3.Set("RememberList", 1)
    Assert.Eq(FileExist(paths.list) ? FileRead(paths.list, "UTF-8") : "(missing)", "k1`r`nk2`r`nk3", "turning Remember on writes the list now")
    Assert.Eq(IniRead(paths.session, "Session", "Position", "?"), "1", "and the position")

    lst4 := ItemList()
    tips4 := FakeTips()
    store4 := ListStore(lst4, FakeTimer(), tips4, prefs3, paths.list, paths.session)
    store4.Resume()
    Assert.Eq(Join(lst4.ToArray()) " @" lst4.GetPosition(), "k1|k2|k3 @1", "with Remember on, the list and position come back")
    Assert.Eq(tips4.alerts.Length, 0, "no deletion message when Remember is on")
    Assert.Eq(FileExist(paths.list) ? 1 : 0, 1, "the saved files stay")

    lst3.Advance()
    Assert.True(timer3.Has("listSave"), "a change schedules a debounced save")
    prefs3.Set("RememberList", 0)
    Assert.Eq((FileExist(paths.list) || FileExist(paths.session)) ? 1 : 0, 0, "turning Remember off deletes the files")
    Assert.Eq(timer3.Has("listSave"), 0, "and cancels the pending save")
    store3._Save()
    Assert.Eq(FileExist(paths.list) ? 1 : 0, 0, "a save that was already queued writes nothing once Remember is off")
}

Test_A14_Generator() {
    gen := SequenceBuilder()
    res := gen.BuildNumbers("Cam-{n}", "1", "10", "1", "3")
    Assert.Eq(res.error, "", "default number settings are valid")
    Assert.Eq(res.items.Length, 10, "1..10 gives 10 items")
    Assert.Eq(res.items[1] "|" res.items[10], "Cam-001|Cam-010", "zero-padded first and last")

    res := gen.BuildNumbers("Cam-{n}", "10", "1", "1", "3")
    Assert.Eq(res.items[1] "|" res.items[10], "Cam-010|Cam-001", "start > end counts down")

    res := gen.BuildIpRange("192.168.1.250", "192.168.2.5", "1", true)
    Assert.Eq(res.items.Length, 10, "IP range across an octet, skipping .0 and .255")
    res := gen.BuildIpRange("192.168.1.250", "192.168.2.5", "1", false)
    Assert.Eq(res.items.Length, 12, "IP range across an octet, keeping .0 and .255")

    res := gen.BuildIpRange("192.168.1.300", "192.168.1.5", "1", true)
    Assert.Eq(res.error, "Start IP is not valid", "an invalid start IP is rejected")
    res := gen.BuildNumbers("x{n}", "1", "20000", "1", "0")
    Assert.Eq(res.error, "Too many items (max 10000)", "more than 10,000 items is rejected before generating")
}

Test_A15_ClipboardOwnership() {
    sc := SeqClip()
    got := []
    sc._onTextFn := (text) => got.Push(text)
    sc.seq := 41
    sc._MarkOwnWrite()
    sc.text := "a`nb"
    sc._OnChange(1)
    Assert.Eq(sc.ExternalChangeCount() "/" got.Length, "0/0", "ListPaster's own write is not mistaken for a copy")
    sc.seq := 42
    sc._OnChange(1)
    Assert.Eq(sc.ExternalChangeCount() "/" got.Length, "1/1", "any other change is counted and reported")
    sc._OnChange(1)
    Assert.Eq(sc.ExternalChangeCount(), 2, "outside changes count no matter how soon they follow a paste")

    buf := ClipboardService()._PrivateTextBuffer("ab")
    Assert.Eq(NumGet(buf, 0, "UInt") "/" NumGet(buf, 4, "UInt"), "13/6", "text block: CF_UNICODETEXT, 2 characters + terminator")
    Assert.Eq(StrGet(buf.Ptr + 8, "UTF-16"), "ab", "text block content")
    offset := 14
    for name in ["ExcludeClipboardContentFromMonitorProcessing", "CanIncludeInClipboardHistory", "CanUploadToCloudClipboard"] {
        id := DllCall("RegisterClipboardFormat", "Str", name, "UInt")
        Assert.Eq(NumGet(buf, offset, "UInt") "/" NumGet(buf, offset + 4, "UInt") "/" NumGet(buf, offset + 8, "UInt"), id "/4/0", name " is a DWORD 0")
        offset += 12
    }
    Assert.Eq(NumGet(buf, offset, "UInt"), 0, "the format list ends with 0")
    Assert.Eq(buf.Size, offset + 4, "no stray bytes after the end marker")
}

; =====================================================================================
; Builders
; =====================================================================================

NewPrefs() {
    prefs := Settings(FreshIni())
    prefs.Load()
    return prefs
}

NewControllerEnv() {
    env := {}
    env.items := ItemList()
    env.clip := FakeClip()
    env.delivery := FakeDelivery(env.clip)
    env.tips := FakeTips()
    env.prefs := NewPrefs()
    env.ctl := PasteController(env.items, env.delivery, env.clip, env.tips, env.prefs)
    env.items.OnChange(ObjBindMethod(env.ctl, "OnListChanged"))
    return env
}

NewDeliveryEnv() {
    env := {}
    env.sender := FakeSender()
    env.clip := FakeClip()
    env.timer := FakeTimer()
    env.prefs := NewPrefs()
    env.prefs.Set("PastePreDelayMs", 0)
    env.prefs.Set("PastePostDelayMs", 0)
    env.probe := FakeProbe()
    env.dlv := DeliveryService(env.sender, env.clip, env.timer, env.prefs, env.probe)
    return env
}

StorePaths() {
    static count := 0
    count += 1
    return {list: TestDir() "\list" count ".txt", session: TestDir() "\session" count ".ini"}
}

Join(arr, sep := "|") {
    out := ""
    for i, value in arr
        out .= (i > 1 ? sep : "") value
    return out
}

; =====================================================================================
; Fakes
; =====================================================================================

class FakeSender {
    calls := []
    failType := false
    TypeText(text) {
        if (text = "")
            return false
        this.calls.Push("type:" text)
        return !this.failType
    }
    PressKeys(keys) {
        if (keys = "")
            return true
        this.calls.Push("keys:" keys)
        return true
    }
    LastCall() => this.calls.Length ? this.calls[this.calls.Length] : ""
}

class FakeClip {
    text := ""
    changes := 0
    saves := 0
    restores := []
    setTexts := []
    failSet := false
    ExternalChangeCount() => this.changes
    ReadText() => this.text
    SetText(text) {
        if this.failSet
            return false
        this.setTexts.Push(text)
        this.text := text
        return true
    }
    Save() {
        this.saves += 1
        return {snapshot: this.saves}
    }
    Restore(saved) {
        this.restores.Push(saved)
        return true
    }
}

class FakeTimer {
    jobs := Map()
    After(name, delayMs, fn) {
        this.jobs[name] := fn
    }
    Cancel(name) {
        if this.jobs.Has(name)
            this.jobs.Delete(name)
    }
    Has(name) => this.jobs.Has(name)
    Run(name) {
        if !this.jobs.Has(name)
            return false
        fn := this.jobs[name]
        this.jobs.Delete(name)
        fn.Call()
        return true
    }
}

class FakeTips {
    shown := []
    alerts := []
    confirms := []
    answer := false
    onConfirm := ""
    Show(message, durationMs := 0) {
        this.shown.Push(message)
    }
    Confirm(question) {
        this.confirms.Push(question)
        if HasMethod(this.onConfirm)
            this.onConfirm.Call()
        return this.answer
    }
    Alert(message) {
        this.alerts.Push(message)
    }
    Last() => this.shown.Length ? this.shown[this.shown.Length] : ""
}

class FakeProbe {
    info := ""
    selfPid := 1
    sheet := false
    focus := 7
    __New() {
        this.info := {hwnd: 100, pid: 4242, cls: "Notepad", exe: "notepad.exe"}
    }
    ActiveWindow() => IsObject(this.info) ? this.info.hwnd : 0
    ActiveInfo() => this.info
    OwnPid() => this.selfPid
    IsActive(winTitle) => this.sheet
    FocusedControl() => this.focus
}

class FakeDelivery {
    clip := ""
    delivered := []
    erased := []
    problem := ""
    failNext := false
    eraseResult := ""
    restoreText := ""
    restoreNowCalls := 0
    __New(clip := "") {
        this.clip := clip
    }
    TargetProblem() => this.problem
    Deliver(text, advanceMode, deliveryMode) {
        if this.failNext {
            this.failNext := false
            return ""
        }
        this.delivered.Push(text)
        return {text: text, advance: advanceMode, mode: deliveryMode}
    }
    Erase(record) {
        result := IsObject(this.eraseResult) ? this.eraseResult : {erased: true, reason: ""}
        if result.erased
            this.erased.Push(record.text)
        return result
    }
    RestoreNow() {
        this.restoreNowCalls += 1
        if (this.restoreText != "")
            this.clip.text := this.restoreText
    }
}

; ClipboardService with a controllable sequence number and clipboard text (no real clipboard access).
class SeqClip extends ClipboardService {
    seq := 0
    text := ""
    SequenceNumber() => this.seq
    ReadText() => this.text
}

; =====================================================================================
; Test framework
; =====================================================================================

class Assert {
    static passed := 0
    static failed := 0

    static Eq(actual, expected, name) {
        if (String(actual) == String(expected)) {
            this.passed += 1
            return
        }
        this.failed += 1
        Emit("  FAIL " name)
        Emit("       expected: " this._Show(expected))
        Emit("       actual:   " this._Show(actual))
    }

    static True(condition, name) {
        this.Eq(condition ? "true" : "false", "true", name)
    }

    static Contains(haystack, needle, name) {
        this.Eq(InStr(haystack, needle, true) ? "contains" : "missing [" needle "] in [" haystack "]", "contains", name)
    }

    static _Show(value) => StrReplace(StrReplace(String(value), "`n", "\n"), "`t", "\t")
}

RunTest(name, testFn) {
    Emit("[" name "]")
    before := Assert.failed
    try {
        testFn()
    } catch Error as e {
        Assert.failed += 1
        Emit("  FAIL threw " Type(e) ": " e.Message " (" e.What ", line " e.Line ")")
    }
    if (Assert.failed = before)
        Emit("  ok")
}

Emit(text) {
    FileAppend(text "`n", "*", "UTF-8-RAW")
}

Finish() {
    logPath := A_ScriptDir "\" Constants.ERROR_LOG
    if (Assert.failed && FileExist(logPath))
        Emit("`nerror.log written by the tested classes:`n" FileRead(logPath))
    Emit("")
    Emit("passed: " Assert.passed "   failed: " Assert.failed)
    ResetTestFiles()
    ExitApp(Assert.failed)
}

ReportUncaught(e, mode) {
    Emit("UNCAUGHT " Type(e) ": " e.Message " (" e.What ", line " e.Line ")")
    ExitApp(99)
}

; Temp folder for INI and list files; tests\error.log collects errors the tested classes log.
TestDir() => A_Temp "\ListPasterTests"

ResetTestFiles() {
    if DirExist(TestDir())
        DirDelete(TestDir(), true)
    DirCreate(TestDir())
    if FileExist(A_ScriptDir "\" Constants.ERROR_LOG)
        FileDelete(A_ScriptDir "\" Constants.ERROR_LOG)
}

FreshIni() {
    static count := 0
    count += 1
    return TestDir() "\settings" count ".ini"
}
