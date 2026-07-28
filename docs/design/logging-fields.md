# Logging fields

The logging controls are the area of the Logging Panel for adding or editing
QSOs — the hottest path in the app, and the one place where keyboard
ergonomics are a contract rather than a nicety (see [DESIGN.md](../../DESIGN.md)
§7). They have three parts: the main logging controls, the information area,
and the secondary logging controls.

Implemented in `packages/halo_widgets/lib/src/logging_controls.dart`.

## The three parts

**Main controls.** Always start with the callsign input (also used for
commands), followed by the exchange inputs (unless disabled), then controls
defined by active extensions and operation references, and finally
user-enabled ones like state or grid. This list is deliberately short,
focused on information exchanged over the air on every contact; most other
details belong in the secondary controls.

These — and only these — are the **main logging fields** the focus rules
below apply to. Everything else in the app, including the fields inside an
expanded secondary control, keeps whatever behavior its widget defaults to.

**Secondary controls.** Pills that show the current state of QSO attributes
— built-ins like time and radio, plus extension-defined ones. Selecting a
pill opens its editable controls in a strip above the pill row; the pills
act as mutually exclusive tabs. The strip scrolls horizontally, and can be
expanded to show all controls in multiple rows or collapsed back to a single
scrolling row to save screen space.

**Information area.** Presents information to the user: details for the
current callsign, or a summary of operation statistics when no callsign is
entered. Content usually comes from extensions as markdown and can link to
external resources or internal navigation. Tapping the area can open a
screen or pane with more detail.

## Which field has focus

The callsign field is the default: if no other field is focused, focus
belongs there.

**Except on mobile with no external keyboard attached**, where having no
field focused is fine — the view always starts that way, so the operator
isn't met with a virtual keyboard covering half the screen. And while a
virtual keyboard *is* displayed, tapping a field that is already focused and
still empty blurs it, as a way to dismiss the keyboard: a field you focused
but haven't typed into is the one case where there's nothing to lose by
closing it. Implemented app-wide (not just for the logging fields) by
`TapToDismissEmptyField` in `keyboard_dismiss.dart`, since a per-field opt-in
would be silently missing from every field added later.

## Moving between the main fields

**Space** moves focus to the next main field in order, wrapping back to the
callsign field after the last one.

**Except in a field that allows entering spaces**, where a space is a
literal character. There, focus only advances when the cursor was at the end
of the value and there is already a space there — and both spaces are then
removed before focus moves on. This is what keeps such a field escapable
from the keyboard without stealing the character it legitimately needs.

Today the only field that enters this mode is the callsign field, and it
does so dynamically rather than by static declaration: an extension's
`command` hook returns `expectsParams` (a recognized prefix still awaiting
its parameters) or `mixedCase` (a parameter that is free prose), and either
switches the field to free-text entry. See
[extensions/hooks.md](../extensions/hooks.md) § `command` for the hook
contract.

One consequence on iOS: the system's "double space inserts a period"
shortcut fires on exactly this gesture, and never arrives as a space at all.
It comes as two edits — the trailing space is first replaced by a period,
then the space is re-added — and the first of those is read as the exit. So
the shortcut is not available in a space-accepting field: type a period if
you want one. Nowhere else in the app is affected, because every other field
consumes the first space before it can reach the text. This is recognized on
iOS only; no other platform's smart punctuation has been traced.

**Tab** rotates through the same fields in the same order, and stops there:
from the last main field it returns to the callsign field, and Shift-Tab
from the callsign field goes to the last main field. This deliberately
breaks the platform default of continuing on through the rest of the
screen's focusable elements — the entry row is a loop, not a waypoint.

**Right arrow** at the last position of a field's value moves to the first
position of the next field; **left arrow** at the first position moves to
the last position of the previous field. Both wrap between the first and
last main fields.

**On focus, the cursor goes to the end of the value.** The existing text is
never selected, not even when focus arrived via Tab — several desktop
platforms select-all by default, and an operator who tabbed into a field to
check it shouldn't be one keystroke away from destroying it. This applies to
the main logging fields only.

## Focus and the secondary controls

Opening a secondary control moves focus to whichever field in the expanded
strip the operator opened it to type in (the time control's time field, the
radio control's frequency field, a reference control's input). A control
with nothing to type into leaves focus alone rather than yanking it
somewhere useless.

The main field that had focus before is remembered, and gets it back when
the control is collapsed — falling back to the callsign field if there was
none, or if that field is no longer on screen. Selecting a *different*
secondary control while one is already open moves focus straight to the new
control's field and keeps the remembered main field, so closing the strip
still returns to where the operator left off.

## Leaving the entry row: the focus ladder

Tab and the arrows above keep the operator inside the entry row. **Arrow Up
is the way out of it**, and out of each rung above it in turn; Arrow Down
walks back in. Between them the whole panel — and the QSO list above it — is
reachable without a pointer.

```
QSO list  ──▲──  secondary pills  ──▲──  main logging fields
          ──▼──                   ──▼──
```

- **From a main field**, Up moves to the secondary pill strip. An open
  `options` suggestion menu keeps Up and Down for its own highlight.
- **On the pills**, Left and Right move along the strip, wrapping at both
  ends. Enter opens the pill's controls, placing focus by the rules above.
  Down returns to the remembered main field.
- **In an open control**, Down or Enter closes it and returns to its pill.
  Enter there does *not* log, in any secondary control — logging is one rung
  down, from a main field. (It used to log from all of them: the radio
  control by its own submit handler, the reference controls and the spot
  comment by falling through to the panel's Enter shortcut.)
- **In the QSO list**, Up and Down walk the log, loading each contact into
  the editor **without moving focus**, so the next arrow keeps walking.
  Event and annotation rows are skipped, since they aren't editable
  contacts. Enter moves the cursor to the callsign field with that contact
  still loaded; Down past the newest contact leaves for the pills.

  The list also takes the jumps every list is expected to: **Home** and
  **End** go to the oldest and newest contact, **Page Up** and **Page Down**
  move a screenful (as many rows as fit, less one carried over for context),
  and on macOS **Cmd+Up/Down** repeat Home/End while **Option+Up/Down**
  repeat the page keys. Unlike a single-row Down, none of them ever walks off
  the end of the list — they stop at the last contact, because nobody presses
  Page Down meaning "and then leave".

**Escape** is the way *out*, at every rung, one layer per press: an open
suggestion menu, then an open control — all the way back to the main fields,
where Down and Enter stop at the pill — then the editing session, then the
composed QSO. It never walks back *in*: in particular a second Escape does
not re-select the QSO the first one deselected, which it used to do.

**Every rung claims bare keys only.** A held Cmd, Ctrl or Option makes the
keystroke a platform gesture (Cmd+Down is "caret to the end of the text" on
macOS), and Shift+arrow is a text selection — the ladder stands aside for
both, exactly as the entry row's own Tab and arrow rules do.

Each rung hangs its handling off a `FocusNode`'s own `onKeyEvent`, never a
panel-wide `Shortcuts` binding — a panel-wide arrow binding would swallow the
arrow keys for every field underneath it, caret movement included. Crossing
between the logging controls and the QSO list goes through
`LoggingControls.onNavigateToQsoList` and `LoggingControlsController`: the two
are siblings, and the panel above them owns the selection.

Whichever key moved the selection, the list scrolls to it — the row is placed
from its position in the log rather than measured, so a jump to the far end
lands as surely as a single step does.

Still to come: a "goto" search (Cmd/Ctrl-G) for jumping to a QSO by number or
callsign — see [backlog.md](../backlog.md).

## Related conventions

- All logging input is uppercase unless the input explicitly declares
  otherwise — `uppercase` defaults to true for exchange controls
  ([contests.md](contests.md)), callsign fields are always uppercase
  ([extensions/forms.md](../extensions/forms.md)), and only a command's
  `mixedCase` interpretation lifts the rule for the callsign field.
- Serial-number exchange fields are *planned* to opt out of the Space cycle
  via a per-control `focus: 'skip'`, following app-polo's `skipFocus` — see
  [contests.md](contests.md). **Not built:** every exchange field, serials
  included, currently takes its turn in the cycle.
- The developer commands typed into the callsign field are listed in
  [DEVELOPMENT.md](../../DEVELOPMENT.md).
- Command output and reference validation errors go to the status bar, never
  a toast over the logging UI — see [user-interface.md](user-interface.md).

## Status

Implemented except for:

- The two mobile rules — starting with no field focused when no external
  keyboard is attached, and making "nothing focused → the callsign field" a
  standing invariant rather than something re-asserted after each action. Both
  are blocked on a decision, not on the work; see [backlog.md](../backlog.md).
- The serial fields' `focus: 'skip'` opt-out noted above, which does not exist
  yet.
- The Log button, which the focus ladder doesn't reach: Tab loops within the
  entry row and Arrow Up leaves it for the pills, so pressing Log still takes a
  pointer. Enter from any main field logs, so this is a gap in reaching the
  *button*, not in logging.
