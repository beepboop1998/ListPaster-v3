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

OnError(ReportUncaught)
ResetTestFiles()

RunTest("A1 List rules", Test_A1_ListRules)
RunTest("A10 Settings", Test_A10_Settings)
RunTest("A14 Generator", Test_A14_Generator)

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
        Out("  FAIL " name)
        Out("       expected: " this._Show(expected))
        Out("       actual:   " this._Show(actual))
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
    Out("[" name "]")
    before := Assert.failed
    try {
        testFn()
    } catch Error as e {
        Assert.failed += 1
        Out("  FAIL threw " Type(e) ": " e.Message " (" e.What ", line " e.Line ")")
    }
    if (Assert.failed = before)
        Out("  ok")
}

Out(text) {
    FileAppend(text "`n", "*", "UTF-8-RAW")
}

Finish() {
    Out("")
    Out("passed: " Assert.passed "   failed: " Assert.failed)
    ResetTestFiles()
    ExitApp(Assert.failed)
}

ReportUncaught(e, mode) {
    Out("UNCAUGHT " Type(e) ": " e.Message " (" e.What ", line " e.Line ")")
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
