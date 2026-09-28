# ListPaster

Copy a multi-line list once, then feed it into any app one item per hotkey
press — form fields, spreadsheet cells, chat boxes, anywhere you'd otherwise
copy-paste the same list by hand, item by item.

v3 is a class-per-file AutoHotkey v2 rewrite of the original single-file
script (kept at [`legacy/ListPaster_v2.ahk`](legacy/ListPaster_v2.ahk) as a
rollback reference), adding list lock, auto-advance, undo, a Type/Paste
toggle, an always-on-top list window, a number/IP sequence generator, and
save/resume between runs.

## Requirements

- Windows
- [AutoHotkey v2.0](https://www.autohotkey.com/)

## Usage

Run [`Main.ahk`](Main.ahk). Copy any multi-line text (2+ non-blank lines) and
it loads automatically as the current list.

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

The list window (Ctrl+Alt+W) shows every item with its status, lets you
click a row to make it the next item, and right-click a row for Edit,
Insert above, Add to end, or Delete.

Settings, the current list, and your position in it persist across restarts
in `data\` (created on first run, git-ignored).

## Project layout

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
- Enter-advance mode presses Enter after every item — don't use it in forms
  where Enter submits.
- Undo assumes the cursor hasn't moved since the paste; clicking elsewhere in
  the same window before undoing erases at the new spot instead.
- Undo counts UTF-16 units, so an emoji in an item can over-delete by one
  character.
- On Remote Desktop, if Paste mode pastes the previous item, raise
  `PastePreDelayMs` in `data\settings.ini`.
- Ctrl+Alt+letter equals AltGr+letter on non-US keyboard layouts.

## License

[MIT](LICENSE)
