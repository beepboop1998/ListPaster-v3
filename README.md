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
3. Double-click `Main.ahk`.
4. Copy two or more lines, click into the first field, and press **Ctrl+Shift+V**.

Copying text with two or more lines loads it as the list automatically. Once
you've started pasting, a new copy won't replace the list until you reach the
end. Press Ctrl+Alt+L to replace it anyway.

## Hotkeys

| Keys | Action |
|---|---|
| Ctrl+Shift+V | Paste next item |
| Ctrl+Alt+Z | Undo last paste |
| Ctrl+Alt+B | Step back one |
| Ctrl+Alt+R | Restart at top |
| Ctrl+Alt+L | Force-load clipboard as the list (even mid-list, even a single line) |
| Ctrl+Alt+A | Cycle auto-advance: None → Tab → Enter |
| Ctrl+Alt+P | Toggle delivery mode: Type ↔ Paste |
| Ctrl+Alt+W | Show/hide the always-on-top list window |
| Ctrl+Alt+G | Open the number/IP sequence generator |

**Type or Paste:** Type mode (the default) types each item as keystrokes and
never touches your clipboard. Paste mode puts the item on the clipboard and
presses Ctrl+V, which works better for long items and in Excel. It restores
your clipboard afterwards.

The list window (Ctrl+Alt+W) shows every item and whether it's done. Click a
row to make it the next item. Right-click a row to edit, insert, add or delete
items.

Your list, your place in it and your settings are saved in `data\` (created on
first run) and restored the next time you start ListPaster.

## Project layout

v3 rewrites the original single-file script as one class per file. The old
script is kept at [`legacy/ListPaster_v2.ahk`](legacy/ListPaster_v2.ahk) in
case you need to roll back.

```
ListPaster/
├── Main.ahk              ; wiring + hotkeys only
├── Constants.ahk         ; shared constants
├── services/             ; TimingEngine, InputSender, ClipboardService,
│                         ; ItemList, Settings, DeliveryService,
│                         ; PasteController, ListStore, Notifier
├── gui/                  ; ListWindow, SequenceDialog
├── lib/                  ; SequenceBuilder (pure number/IP generation)
├── legacy/               ; ListPaster_v2.ahk — untouched v2 baseline
└── data/                 ; created at runtime (list, settings, session)
```

## Known limitations

- Excel AutoComplete can extend a typed item (typing `Door 1` above an
  existing `Door 10` can commit `Door 10`). Use Paste mode in Excel, or turn
  off AutoComplete (File → Options → Advanced).
- Enter auto-advance presses Enter after every item, so don't use it in forms
  where Enter submits.
- Undo assumes the cursor hasn't moved since the paste. If you click elsewhere
  in the same window first, undo erases at the new spot instead.
- Undo counts characters in UTF-16 units, so an item containing an emoji can
  over-delete by one character.
- On Remote Desktop, if Paste mode pastes the previous item, raise
  `PastePreDelayMs` in `data\settings.ini`.
- On non-US keyboard layouts, Ctrl+Alt+letter is the same as AltGr+letter.

## License

[MIT](LICENSE)
