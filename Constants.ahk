/*
    Constants.ahk
    Responsibility: Shared constants for ListPaster. Base layer: includes nothing, depends on nothing.
    Dependencies: none
*/
class Constants {
    static APP_NAME := "ListPaster"
    static VERSION := "3.0"

    ; --- Files (relative to A_ScriptDir) ---
    static ERROR_LOG := "error.log"
    static SETTINGS_FILE := "data\settings.ini"
    static LIST_FILE := "data\list.txt"
    static SESSION_FILE := "data\session.ini"

    ; --- Hotkeys ---
    static HK_PASTE_NEXT := "^+v"
    static HK_UNDO := "^!z"
    static HK_BACK := "^!b"
    static HK_RESET := "^!r"
    static HK_FORCE_LOAD := "^!l"
    static HK_CYCLE_ADVANCE := "^!a"
    static HK_TOGGLE_DELIVERY := "^!p"
    static HK_TOGGLE_WINDOW := "^!w"
    static HK_SEQUENCE := "^!g"

    ; --- Modes ---
    static ADVANCE_MODES := ["None", "Tab", "Enter"]
    static ADVANCE_KEYS := Map("None", "", "Tab", "{Tab}", "Enter", "{Enter}")
    static DELIVERY_MODES := ["Type", "Paste"]

    ; --- ItemList change kinds ---
    static KIND_LOAD := "load"
    static KIND_RESUME := "resume"
    static KIND_ADVANCE := "advance"
    static KIND_UNDO := "undo"
    static KIND_BACK := "back"
    static KIND_RESET := "reset"
    static KIND_JUMP := "jump"
    static KIND_EDIT := "edit"

    ; --- Timing ---
    static TICK_MS := 50
    static TIP_MS := 1500
    static SAVE_DEBOUNCE_MS := 1000
    static CLIP_SUPPRESS_MS := 500
    static CLIP_RESTORE_IDLE_MS := 1500
    static CLIP_WAIT_S := 1
    static MENU_FOCUS_DELAY_MS := 300

    ; --- Settings defaults (key -> default) ---
    static SETTINGS_DEFAULTS := Map(
        "AdvanceMode", "None",
        "DeliveryMode", "Type",
        "PastePreDelayMs", 250,
        "PastePostDelayMs", 250,
        "WindowVisible", 0,
        "WindowX", "",
        "WindowY", "",
        "WindowW", 380,
        "WindowH", 420
    )

    ; --- Windows where Undo uses spreadsheet keys (WinTitle, default match mode 2 = contains) ---
    static SHEET_WINDOWS := ["ahk_exe EXCEL.EXE", "Google Sheets", "LibreOffice Calc"]

    ; --- Sequence generator ---
    static SEQ_MAX_ITEMS := 10000
}
