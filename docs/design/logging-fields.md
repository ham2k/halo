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
- A keyboard-only route *out* of the entry row. Tab now loops within it, so
  reaching the Log button or the secondary controls takes a pointer; a separate
  change is adding a way out.
