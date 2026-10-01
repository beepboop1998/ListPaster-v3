# ListPaster

**Paste a list one line at a time.** Copy a list (a column from Excel, serial
numbers, names, IP addresses), then press **Ctrl+Shift+V**. Each press enters
the next item into whatever field has focus. It's made for data entry into web
forms, spreadsheets and remote-desktop apps that won't take a bulk paste.

It's a free, open-source (MIT) AutoHotkey v2 script for Windows.

## What it's for

- **Filling web forms field by field.** Tab auto-advance moves to the next field after each item.
- **Entering a list down a spreadsheet column, one cell at a time.** Enter auto-advance moves down after each item.
- **Remote desktop and VDI sessions where clipboard paste is unreliable.** Type mode sends real keystrokes.
- **Entering generated sequences** such as `Cam-001 … Cam-050` or `192.168.1.100 … 192.168.1.150`, using the built-in generator.

## Quick start

1. Install [AutoHotkey v2.0](https://www.autohotkey.com/).
2. Download this repo (**Code → Download ZIP**) and extract it.
3. Double-click `Main.ahk`. A green **H** icon appears in the system tray. On Windows 11 it may be hidden behind
   the **^** arrow; drag it onto the taskbar, or turn it on under
   **Settings → Personalization → Taskbar → Other system tray icons**, so the menu is one click away.
4. Copy two or more lines, click into the first field, and press **Ctrl+Shift+V**.

## Shortcuts

Only two shortcuts are always on, because they act on the field you're typing in:

| Keys | Action |
|---|---|
| **Ctrl+Shift+V** | Paste the next item |
| **Ctrl+Alt+Z** (left Alt) | Undo the last paste: erase it and step back, so the next paste repeats it |

Everything else is in the **tray menu** (right-click the icon):

| Item | What it does |
|---|---|
| *Next: 5 of 10 · Tab · Type* | Status line: next item, list size, auto-advance and insert mode |
| Show list window | Opens the list window (double-clicking the icon does the same) |
| Generate list... | Makes a numbered or IP-address list |
| Load from clipboard | Uses what's on the clipboard as the list, even a single line (asks first if your list is unfinished) |
| Step back | Next paste repeats the previous item. Nothing already entered is changed |
| Restart at top | Next paste is item 1 again |
| Clear list | Empties the list (asks first if it's unfinished) |
| Auto-advance ▸ | None / Tab / Enter, pressed after each item |
| Insert mode ▸ | Type (keystrokes) / Paste (clipboard + Ctrl+V) |
| Extra hotkeys | Turns on the shortcuts below |
| Show next item in tooltip | Shows the next item when you hover the icon (off by default) |
| Remember list after exit | Keeps the list and position between restarts (off by default) |
| Pause / Resume ListPaster | Gives every shortcut back to your apps and ignores copies until you resume |
| Exit | Asks first if an unfinished list would be lost |

**Extra hotkeys** (off by default, left Alt only): Ctrl+Alt+**B** step back · **R** restart at top ·
**L** load from clipboard · **A** cycle auto-advance · **P** switch Type/Paste · **W** show/hide the list window ·
**G** generate list.

After using the tray menu, click back into your field before the next paste. Ctrl+Shift+V won't type into
ListPaster's own windows, the taskbar, or the desktop; it tells you to click into a field instead.

## How the list works

- **Loading.** Copying text with two or more lines loads it as the list, **only if you have no list or the
  current one is complete**. An unfinished list (including one you haven't started) is never replaced
  without asking. To replace it, use *Load from clipboard*.
- **One line = one item.** Lines that are empty or only spaces are skipped, and everything else is kept
  exactly. A row copied from several spreadsheet columns stays one item with tabs in it: Type mode presses
  Tab between the parts, and Paste mode pastes the tabs (which fills the cells next to it in Excel).
- **Each Ctrl+Shift+V advances by one**, only once the item was handed to Windows without error. Quick
  repeated presses each insert one item, in order. Holding the keys down repeats like any key, so release
  between presses.
- **At the end** you'll see *List complete (10 of 10)*. It never wraps around; use *Restart at top* to go again.
- **The list window** shows every item and whether it's done. Click a row to make it the next item.
  Right-click a row to edit, insert, add or delete items.

### Undo vs Step back

- **Undo (Ctrl+Alt+Z)** erases what ListPaster just entered and steps back one. You can repeat it to go further back.
- **Step back (tray)** only moves the position. Nothing you've entered is touched.

Undo sends keys to erase the text: Backspace for the item's length, or Esc/Delete in Excel, Google Sheets and
LibreOffice Calc. It can't read what's in other apps' fields, so:

- **Different window:** it refuses, and nothing changes.
- **Enter auto-advance outside a spreadsheet:** it sends no keys (Enter may have submitted something). It steps
  back and asks you to erase manually. It does the same for items that contain tabs.
- **Moved to another field:** in classic Windows apps it notices and won't erase. Browsers, Office and similar
  apps report one field for the whole window, so there it erases wherever the cursor is now.
- **Edited the text, typed after it, or moved the cursor:** Undo can erase the wrong characters, so use the
  app's own Ctrl+Z instead.
- **In a spreadsheet:** Undo clears the cell; it doesn't bring back what was there before.

## Type or Paste

- **Type** (default) types each item as keystrokes and never touches your clipboard.
- **Paste** puts the item on the clipboard and presses Ctrl+V. It works better for long items and in Excel.
  - Your clipboard is saved before the first paste and put back 1.5 seconds after the last one, or right
    away when you exit.
  - If you copy something yourself in the meantime, your copy is kept.
  - Pasted items are marked so Windows clipboard history (Win+V) and cloud clipboard don't record them.

## Privacy

- Lists stay **in memory only** unless you turn on *Remember list after exit*. Then they're saved as plain text
  in `data\list.txt`. Turning it off deletes that file.
- The next item is hidden from the tray tooltip unless you turn it on, since tooltips are visible to anyone
  looking at or sharing your screen.
- `data\settings.ini` holds only settings, and `error.log` never contains list items.

## Shortcut conflicts

**Ctrl+Shift+V** is "paste as plain text" in Chrome, Edge, Firefox and Google Docs. It's "paste values" in Google
Sheets and recent Excel, and it has other meanings in Word, Outlook, Windows Terminal and VS Code. While
ListPaster is running it takes this shortcut in every app; **Pause** it from the tray to give it back.

The Ctrl+Alt shortcuts use the **left** Alt key only, so AltGr typing on non-US keyboards (ą, ł, ż, @, €…) keeps
working. To use different keys, edit the `HK_` lines in `Constants.ahk`; ListPaster tells you at startup if a key
name is wrong.

## Upgrading from 3.0

- Most shortcuts moved to the tray menu. Turn on **Extra hotkeys** to get the old Ctrl+Alt ones back.
- Lists are no longer saved by default. A list saved by 3.0 is loaded once, then removed from disk, and you're told.
- Copying a new list no longer replaces a list you've loaded but haven't started.

## Known limitations

- **Apps running as administrator** silently block ListPaster's shortcuts and keystrokes. Run `Main.ahk` with
  AutoHotkey's *Run with UI Access* (right-click menu), or as administrator.
- **Other keyboard tools** installed after ListPaster starts (another AutoHotkey script, PowerToys) can take a
  shortcut first.
- **Copying something in the half second while a Paste-mode item is being pasted** can swap which text gets
  pasted. Wait for the tooltip.
- **Excel AutoComplete** can extend a typed item (typing `Door 1` above an existing `Door 10` can commit `Door 10`).
  Use Paste mode in Excel, or turn off AutoComplete (File → Options → Advanced).
- **Enter auto-advance** presses Enter after every item, so don't use it in forms where Enter submits.
- **On Remote Desktop**, if Paste mode pastes the previous item, raise `PastePreDelayMs` in `data\settings.ini`.
- **Right Alt:** Ctrl + *right* Alt shortcuts don't trigger; use the left Alt key.

## Project layout

v3 rewrote the original single-file script as one class per file. The old script is kept at
[`legacy/ListPaster_v2.ahk`](legacy/ListPaster_v2.ahk).

```
ListPaster/
├── Main.ahk              ; wiring only: builds everything, registers shortcuts and the tray menu
├── Constants.ahk         ; shared constants, including the shortcut keys
├── services/             ; TimingEngine, InputSender, ClipboardService, WindowProbe, ItemList,
│                         ; Settings, DeliveryService, PasteController, ListStore, Notifier,
│                         ; HotkeyManager
├── gui/                  ; TrayMenu, ListWindow, SequenceDialog
├── lib/                  ; SequenceBuilder (pure number/IP generation)
├── tests/                ; RunTests.ahk: automated tests, no desktop interaction
├── legacy/               ; ListPaster_v2.ahk, the untouched v2 baseline
└── data/                 ; created at runtime (settings; the list only if remembered)
```

Run the tests from Git Bash:

```bash
"/c/Program Files/AutoHotkey/v2/AutoHotkey64.exe" /ErrorStdOut tests/RunTests.ahk | cat
```

## License

[MIT](LICENSE)
