# Keyboard shortcuts

*Behind the `kb` experiment (`EXP KB`).* The operator picks the keys for the
app's commands in **Settings → Keyboard Shortcuts**, binds keys to commands
typed in the ⌘K dialog, and carries the result to another device as a
`.h2kkey` file. The keys the logging fields and dialogs own stay fixed
([logging-fields.md](logging-fields.md)).

## The pieces

| Piece | Where |
|---|---|
| Chords, the command registry and its defaults, the bindings in force, the legacy matcher | `packages/halo_widgets/lib/src/key_bindings.dart` |
| The operator's changes, stored, and the bindings they produce | `app/lib/services/key_bindings_service.dart` |
| Running bound command text | `runCommandText` in `app/lib/views/command_engine.dart` |
| The file format | `app/lib/services/key_bindings_file.dart` |
| The settings panel, editor and import dialog | `app/lib/views/settings/keyboard_shortcuts_panel.dart` |
| iOS ⌘ chords | `AppDelegate.swift`'s `setKeyCommands` |

**Each key handler stays where it is.** The app-wide handler (`halo_app.dart`),
the keyer and PTT keys, Find, and the logging panel's wipe each keep their own
gating — the route in front, the tester overlay, a keyer that can key — and
ask `keyBindings.value` only whether the event is their command's. Nothing
dispatches commands centrally, so the order a handler runs in, and what it
checks before it acts, is unchanged by a binding.

## Chords

A chord is one key and the modifiers held for it, stored as text:
`cmd+shift+D`, `alt+1`, `F5`, `'`.

- **Modifiers are stored as they are named:** `cmd`, `ctrl`, `meta`, `alt`,
  `shift`. Flutter reports ⌘ and the Windows/Super key as the same key, so
  `cmd` and `meta` both match it; the recorder writes `cmd` on Apple
  platforms (a browser on a Mac included) and `meta` elsewhere, so a file says
  which keyboard it was written for. `fn` is not a modifier: Flutter never
  delivers it on macOS, and keyboards handle it themselves everywhere else.
- **A chord wants exactly its modifiers.** ⌘K and ⌘⇧K can be two commands.
- **Keys are matched by name, and by position only under ⌥ or ⇧ and only
  when the key reported names no key a chord can**: in a browser on a Mac ⌥K
  arrives as '˚'. A key that names one is that key — on AZERTY the key in W's
  place is Z, and ⌥Z there must not wipe as ⌥W.
- **A bare key that types a character matches the character typed**, ⇧ or not.
  PTT's ['] is typed with ⇧ on a German layout. Not a keypad key, which
  types what a main-row key does and is still a key of its own.
- **Key caps draw Apple's symbols as icons** (⌘ ⌥ ⇧ ⌃, Return, ⌫, Tab, the
  arrows) from the bundled Material Design Icons font. The app's own fonts
  hold none of them, so as text each would come from whatever fallback font
  the platform has — and `↩` from the color emoji font, as an emoji. Where
  only text will do (a conflict message, a menu label) Return is spelled out.
- Text reads back in a fixed order; parsing also takes `option`, `control`,
  `command`, `win` and `super`, for a file written by hand. The `+` key is
  `Plus`.

## Commands

| Id | Default | Works |
|---|---|---|
| `app.commandDialog` | ⌘K, ⌘⇧K, ⌘⌥K | anywhere |
| `app.toggleTheme`, `app.toggleLanguage` | ⌘⇧D, ⌘⇧L | anywhere |
| `app.fontScaleUp` / `Down` / `Reset` | ⌘= ⌘+ / ⌘- / ⌘0 (and numpad) | anywhere |
| `app.densityLooser` / `Denser` / `Auto` | the Font Scale keys with ⇧ | anywhere |
| `logView.find` | ⌘F | Operation, Chasing, Logs |
| `keyer.message1`…`8` | F1…F8, ⌥1…⌥8 | Operation, keying a CAT radio |
| `keyer.keyboardMode` | ⌥K | Operation, keying a CAT radio |
| `radio.ptt` | ['] | Operation, PTT on |
| `logging.wipe` | ⌥W | the logging panel |
| `text:<command>` | none | anywhere |

⌘ here is the platform's command key: `cmd` on Apple platforms, `ctrl`
elsewhere. Ids are stable — they are what the settings and files store.

**Command text** (`text:20M`) runs exactly as the ⌘K dialog runs what is typed
into it: against the operation in front, through the same dispatch, with the
hooks' confirmations on the status bar since no field is there to show them.
Several commands chain with `;` — `20M; CW; SPOT` — and run in turn, each
after the one before has dispatched; the chain stops at the first that cannot
run, since the rest were built to go with it. A `;` always separates, so no
command in a chain can carry one in its own text. A command still waiting for
its text (NOTE) stops the chain and opens the dialog with it typed.

The settings list only the command text the operator added — not the ⌘K
catalog — each checked against the command hooks when added, and listed with
no key until one is recorded; it goes only when removed.

**A key that types a character is the focused field's when the field would
take it** (`KeyBindings.yieldsToField`, `fieldTakesKey`) — any chord without
⌘, Ctrl or Win: a bare `]`, ⇧`]`, and ⌥ chords too, since ⌥ types on a Mac
(⌥2 is '@' on Spanish, Nordic and German layouts). Every handler asks once its
chord has matched:

- **with no text field focused**, the shortcut runs;
- **in the logging entry row**, the shortcut runs — no callsign, report or
  exchange takes a `]` — save the call field reading a command that takes
  free text (NOTE), which keeps what it would accept;
- **in the logging panel's other controls**, a field that would take the
  character keeps it (a note) and one that would filter it out (the
  frequency) lets the shortcut have it;
- **in any other text field** — ⌘K, a search, a dialog — the field keeps it.

The field's own formatters answer, so a field whose filter changes with its
mode answers for the mode it is in. A key that types nothing (F9) runs
wherever it is pressed.

## Fixed keys

Never bindable, and listed in the panel so the operator can see what is
taken: Escape, with any modifier; Enter, Space, Tab, the arrows, Page Up/Down,
Home, End, Backspace and Delete on their own or with ⇧; ⌥ or ⌘ with Up or
Down (the QSO list's walk); ⌘Z (Ctrl+Z off a Mac); and **the callsign keys** —
A–Z, 0–9, `,` `.` `/` and the keypad's digits, `.` and `/` — on their own or
with ⇧, for every command, PTT included: a call could not be typed with one
taken. Held with ⌘, Ctrl, Win or ⌥ they are chords like any other, and every
other key on its own is bindable, the field rule above deciding where it
fires.

Chords the system or a browser may take first (⌘Q, ⌘W, ⌘C/V/X/A, Alt+F4…)
are bindable with a warning.

## The experiment

**With `kb` off, no key changes.** `LegacyKeyBindings` answers each command
— and whether it yields to a field: only the keyer's ⌥-digits in free text,
and ['] — with the test its handler made before bindings existed — ⌘ or Ctrl on every
platform, F-keys whatever ⇧ says — so the refactor alone changes nothing an
operator can press. With `kb` on, the defaults hold only the platform's own
command key: ⌃K and ⌃F go back to text editing on a Mac, and Win+K to
Windows.

## Storage

Per device, never synced: a keyboard belongs to a device. The
`keyBindings` preference (`KeyBindingsService`) holds only what differs from
the defaults — `{commands: {id: [chord]}, text: {command: [chord]}}`. A command's
list replaces its defaults whole; an empty list means no key. A command put
back to its defaults leaves no entry behind, so a file of changes never pins
the defaults of the version that wrote it. A list none of whose chords this
version can read is dropped rather than kept empty, so a key a newer version
names never costs an older one the command's defaults.

## Conflicts

Every context sits inside the one before it — the logging panel inside the
Operation view inside the app — so two commands on one chord always meet, and
conflicts ignore context. The panel shows each one in red on both rows; the
editor offers to take a chord from the command that has it. The app does not
pick a winner: the app-wide handler is registered first and answers first, as
it always has.

## Files

```yaml
# Ham2K Logger keyboard shortcuts
ham2k-keys: 1
platform: macos
commands:
  logging.wipe: [F9]
text:
  20M: [cmd+alt+2]
```

`platform` is the OS the keyboard was on — a browser's host OS, not `web`.
Exports are named for the profile's callsign — `Keyboard Shortcuts KI2D.h2kkey`; import also takes `.yaml` and
`.yml`. A file is refused with a reason (not YAML, not a shortcuts file,
written by a newer version, not this shape, too large), with the layout
files' caps on aliases and nesting (`yaml_reader.dart`).

**Import asks how `cmd`, `ctrl` and `meta` read on this keyboard**, for each
one the file uses — never `alt` or `shift`, which mean the same key
everywhere. Each can become one of this keyboard's (`cmd` and `ctrl` on a Mac,
`ctrl` and `meta` elsewhere) or leave its shortcuts out. Translations apply
all at once, so `cmd`→`ctrl` and `ctrl`→`cmd` trade places. The suggestion:

- the same kind of keyboard: each modifier is itself;
- a Mac's file elsewhere: `cmd`→`ctrl`, `ctrl`→`meta`;
- another's file on a Mac: `ctrl`→`cmd`, `meta`→`ctrl`.

The file then **adds to** this device's config (its commands replace the
same ones) or **replaces** it. A file is no way round the fixed keys: the
chords the recorder would refuse are left out, and a command left with none
keeps its defaults. Unknown commands, unreadable chords, refused chords,
command text with no command in it, and the conflicts the result would hold
are all named before Import.

## iOS

UIKit takes ⌘ chords before Flutter sees them unless the app registers them
as UIKeyCommands. With `kb` on, `KeyBindingsService` sends AppDelegate the ⌘
chords of the `app.*` commands and of bound command text; with it off,
AppDelegate keeps its own built-in list. Other commands' ⌘ chords (a ⌘F
rebound, say) do not reach the app on an iPad keyboard: native commands run
through the app-wide handler, and Find and the keyer listen in their views.
The recorder cannot hear a ⌘ chord there either, so on an iPad one comes
only from a file.
