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

## How wide each main field is

Every main field states a **minimum width** — the width it renders at whenever
the row has the room, not a fixed size. The callsign field states none at all:
it takes whatever the others leave, down to a floor of **six characters** (a
full call with a portable suffix, `W1AW/4`), which it holds however many other
fields are enabled.

When the enabled fields don't all fit, the row makes its concessions in this
order, and never reaches for the next one until the last is spent:

1. **The fields shrink, evenly** — the same number of pixels off each, not the
   same share of each, so a field that asked for more stays wider by exactly as
   much as it started.
2. **They stop at two characters.** Enough to tell a filled field from an empty
   one and to aim a click at it. Every field floors at the same two characters,
   so down here the wider ones are no longer wider.
3. **The gaps between the fields and the padding inside them go next**, both
   together and *gradually* — a single fraction of each, falling with the width
   rather than snapping off at a breakpoint, and all the way to nothing. This
   shrinks the floors above with them: two characters without padding is
   narrower than two with.
4. **The callsign gives up its six characters.** It is the last thing left, and
   a narrow callsign field reads better than a row of overflow stripes.

**The focused field is exempt from all of it.** It renders at its full minimum
width for as long as it has focus, and its neighbours carry its share — the
field the operator is typing in is the one worth reading. This is the one place
in the panel where moving focus changes the layout, so the change is
**animated**, briefly (100ms). A change in the space *available* is not: the
callsign is `Expanded` and never animates, so animating the others through a
window drag would leave it absorbing their lag for the whole gesture.

Two consequences worth knowing before changing any of this:

- **A field's label must never wrap.** It is laid out above the value, so a
  label on two lines makes the whole field taller — and through the row's
  `IntrinsicHeight` that widens the log button, taking back more room than the
  squeeze just found. `poloFieldDecoration`'s `labelMaxLines` is what pins it;
  Material's own `labelText` has no line limit.
- **A field's real inset is more than its `contentPadding`.** Material adds 4pt
  a side to every `filled` field of its own accord (`_kInputExtraPadding`),
  which no `InputDecoration` field exposes. Step 3 counts it as part of what
  there is to give and cancels it with a *negative* content padding, which is
  the only way to get it back; the arithmetic would otherwise be 8pt per field
  short of what the row actually spends.
- **What never compresses**: the panel's own 12pt edge inset (shared with the
  pill strip and the info area above, so the fields row can't give it up
  alone), the log button's diameter, and the fields' vertical padding.
- All of it is written in plain logical pixels and characters and scales with
  the interface ([ui-scaling.md](ui-scaling.md)); the character-derived widths
  are measured against the fields' own font, so OS text scaling widens them
  rather than eating into them.

## Which field has focus

The callsign field is the default: if no other field is focused, focus
belongs there.

**Except on mobile with no physical keyboard attached**, where having no
field focused is fine — the view always starts that way, so the operator
isn't met with a virtual keyboard covering half the screen. And while a
virtual keyboard *is* displayed, tapping a field that is already focused and
still empty blurs it, as a way to dismiss the keyboard: a field you focused
but haven't typed into is the one case where there's nothing to lose by
closing it. Implemented app-wide (not just for the logging fields) by
`TapToDismissEmptyField` in `keyboard_dismiss.dart`, since a per-field opt-in
would be silently missing from every field added later.

Whether a physical keyboard is attached comes from the native side over the
`ham2k/hardware_keyboard` channel — GCKeyboard on iOS, InputDevice
enumeration on Android — into halo_widgets' `hardwareKeyboardAttached`
notifier, fed by the app's `HardwareKeyboardService`. Flutter itself cannot
answer this: its HardwareKeyboard API only reports keys while they are
pressed, and the `viewInsets` heuristic in `keyboard_dismiss.dart` only
answers while a field is already focused — strictly after the moment the
answer is needed. The value is read at each focus decision, not watched: a
keyboard attached mid-session applies from the next decision on. (One
harmless corner: `autofocus` re-evaluates per build, so with nothing focused
a late attach can hand focus to the callsign field — with hardware attached
there is no virtual keyboard to pop, so that is the default-focus rule, not
a violation.) The default while the channel's first answer is in flight is
"none attached", so a race costs a keyboard user one tap rather than popping
an uninvited virtual keyboard.

**Tapping a spot focuses the callsign field.** The suggestion it hands over
means "work THIS station", so Enter must be able to log it immediately — but
the tap itself lands in the Spots pane, outside the logging fields, leaving
nothing focused for Enter to reach. The suggestedQso-change path asserts the
focus itself (a deeplinked cold start gets it from the field's autofocus).
Not on mobile without a physical keyboard, per the carve-out above: there
the suggestion fills the fields without popping a keyboard over the call
info the tap just surfaced.

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

**Two settings bend this order, and both bend it everywhere at once.**

*Switch signal report order* draws Rcvd before Sent, for an operator who takes
the report before giving one. The row's order and the keyboard's path through
it are the same list — reversing one without the other leaves Space walking
backwards through fields the operator reads forwards — so one place resolves
the order (`_rstPair`) and the row, the Space/Tab/arrow cycle, the QSO list's
report cell and the More pane all read it. The list cell in particular carries
no labels, so a fixed order there would have the operator reading every logged
contact backwards. Which controller is Sent and which is Rcvd never changes;
only where each is drawn does.

*Jump to next field on RST entry* advances focus the moment a report is
complete, so a full exchange costs no Spaces. "Complete" is the **full** report
— two characters on phone, three on CW and the data modes (`rstLengthFor`) —
not the significant part the completion rule above expands from: a `44` on CW
still owes its `A` or its tone, and jumping at two characters would put `44A`
and `5NN` out of reach entirely. **The FT modes have no complete length**, and
so no jump: `-9`, `+05` and `-12` are equally real reports, and any threshold
would either never fire or fire halfway through one — the same reason the
completion rule leaves them alone.

Phone pays a smaller version of that price knowingly: with the setting on,
`59+` can't be typed, because the jump has already fired at `59` and the `+`
lands in the next field. `59` and `59+` cannot both be "complete", the plain
one is overwhelmingly the common case, and the setting is off by default — an
operator who gives `59+` leaves it off. The alternative, exempting phone the
way the FT modes are exempt, would remove the setting from the modes most
people want it in.

It fires only on **crossing that length from below**, so correcting a report
that is already complete doesn't throw the operator out of the field on their
first keystroke. That rule needs a baseline, and the baseline has to be seeded
from the fields when a QSO arrives already loaded: a panel *constructed* around
a QSO populates before the trigger is attached, and gaining focus is itself a
value change (it collapses the selection), so an unseeded field jumps on the
tap that arrives in it — and then again out of the next one.

The trigger hangs off the text controller rather than the field's `onChanged`,
which is what makes it work for the mobile numbers row (that row writes the
controller directly and never reaches `onChanged`, and it is where saving a
keypress matters most); a focus check is what keeps it to real typing, since
every programmatic write happens to a field the operator isn't in.

**USB and LSB count as phone here**, not as data. No CAT protocol has an "SSB"
mode, so a connected rig reports the concrete sideband and nothing maps it
back; treating them as anything else would give an operator with a radio
attached a three-digit report while one who picked SSB by hand gets two.

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

## Enter and focus

**Enter never blurs.** It means "log", not "done editing", so the field that
submitted keeps focus and the operator can keep typing — whether the Enter
logged a contact, ran a command, saved an edit, or was rejected as none of
those. Only something downstream deliberately moves focus after it: `_wipe`
sends it back to the callsign field once a contact is logged, so a QSO
submitted from an exchange field still leaves the operator on callsign, ready
for the next one.

This has to be asserted, not assumed. A single-line `TextField` unfocuses
itself *before* calling `onSubmitted` — Flutter's default end-of-editing
behavior — so every main logging field supplies `onEditingComplete` to
suppress that (`_finishEditingWithoutBlur`). Without it the entry row only
*looks* intact, because the two commonest paths happen to re-focus afterwards
and the rest silently leave nothing focused at all.

Two consequences worth knowing:

- **On mobile the on-screen keyboard stays up** after Enter, including on the
  paths that keep the typed input (a rejected command). The only dismissal
  gesture, tap-to-dismiss, needs the field to be *empty* — see the mobile
  carve-out above.
- **A test that drives Enter with `sendKeyEvent` is not testing this.** That
  route reaches the logging code through the panel's shortcut bindings without
  ever finalizing the editing session, so it never blurs and passes against
  broken code. Use `receiveAction(TextInputAction.done)`, which is what the
  engine actually sends.

## A contact needs a band or a frequency

**Enter logs — except when the contact would carry neither a band nor a
frequency.** Then it asks instead: the message takes the information area,
the same place a command's error appears, and the Radio control opens on its
frequency field, so the answer is one number away. Nothing is written until
one of the two is set.

Either value satisfies it. A band picked by hand — or by a `40M` command,
which deliberately clears the frequency — is a complete answer.

This exists because on a fresh install nothing has ever set either one: the
stored VFO is empty, and every other gate looks only at the callsign. The
resulting record is not merely incomplete — the ADIF exporter emits `BAND`
only when there is one and `FREQ` only when it's non-zero, so the contact
leaves carrying neither, and LoTW, QRZ and POTA all reject it. The operator
finds out long after the station is gone.

It applies while editing an existing contact too, since an edit is the moment
to repair one of those records. It does **not** block deleting one: the check
sits below the delete branch, so a contact you want gone doesn't have to be
fixed first.

**Asked up front, not only at log time.** When the stored VFO holds nothing —
no band *and* no frequency, or no mode — the Radio control opens by itself
once, on mount, so the operator is looking at the fields that need answering
instead of discovering the problem on their first Enter. Mode counts even
though the mode field always shows a value: it falls back to a hardcoded
`SSB` nobody chose, and a null `vfoA.mode` is what tells "defaulted" from
"confirmed". The VFO is persisted device-wide, so this happens once per
install, not once per operation.

Only while composing, and only once per mount — an operator who closes the
control isn't fought by the next rebuild. It's also skipped when a
`suggestedQso` supplied the radio state (tapping a spot, or a deeplinked cold
start): the condition is evaluated in a post-frame callback, after the
suggestion's own push to the VFO, so the control doesn't pop open over a
frequency the operator was just handed.

The log-time refusal above remains the backstop for the operator who closes
the control without answering. Note the two interact: while the control is
open, Enter closes it rather than logging, per the ladder below.

The QSO list's empty state carries the same reminder — "Please make sure your
band and mode are correct" — but only while the VFO actually needs it, using
the same condition as the auto-open above. A band picked by hand (no
frequency) or a frequency with no band already satisfies HALO-24, so once the
operator has answered, an empty log goes back to the ordinary "No QSOs yet —
work someone!" text. `LoggingPanel` recomputes this on every VFO change (a
listener on `RadioService`, diffed like the numbers-row settings) so the
warning clears the moment the Radio control is answered, not on the next
unrelated rebuild.

Seeding a default band at onboarding was considered and rejected — a guessed
band means contacts logged on the *wrong* band, which is worse than being
asked once.

## Focus and the secondary controls

**Landing on a pill opens it.** Arriving via Up from a main field, Down from
the QSO list, or a Tab/cursor-key crossing between pills all auto-open the
control the keyboard lands on and focus whichever field it's opened to type
in (the time control's time field, the radio control's frequency field, a
reference control's input) — there is no separate "select the pill, then
Enter to open it" step anymore. `more` is the one exception: it has no
fields of its own, so it stays chip-focused and pops its dialog on Enter or
a tap instead. A control with nothing to type into (e.g. spotting with its
comment hidden) leaves focus on the chip rather than yanking it somewhere
useless.

**Tab and the cursor keys move between controls differently.** Tab and
Shift-Tab step through a multi-field control's own fields first — Radio's
Band, Frequency, then Mode; Time's Time, then Date — in the order they're
laid out, only crossing to the neighbouring pill once those are exhausted,
and landing on its first (Tab) or last (Shift-Tab) field. Left and Right, by
contrast, treat a whole control as one stop the same way they treat one main
field: at the edge of the focused field's value they cross straight to the
neighbouring pill's own canonical field (Radio's Frequency, not Band or
Mode), skipping any other fields the control might have. Both wrap at the
ends of the strip.

The main field that had focus before is remembered, and gets it back when
the control is collapsed via Down or Enter (not the pill — see the ladder
below) — falling back to the callsign field if there was none, or if that
field is no longer on screen. Selecting a *different* secondary control
while one is already open moves focus straight to the new control's field
and keeps the remembered main field, so closing the strip still returns to
where the operator left off.

## Leaving the entry row: the focus ladder

Tab and the arrows above keep the operator inside the entry row. **Arrow Up
is the way out of it**, and out of each rung above it in turn; Arrow Down
walks back in. Between them the whole panel — and the QSO list above it — is
reachable without a pointer.

```
QSO list  ──▲──  secondary pills  ──▲──  main logging fields
          ──▼──                   ──▼──
```

- **From a main field**, Up moves to the secondary pill strip, opening
  whichever pill the keyboard was last on (or the first) and focusing its
  field — see above. An open `options` suggestion menu keeps Up and Down for
  its own highlight.
- **On the pills**, Left and Right cross straight to the next/previous pill
  and open it, wrapping at both ends; Tab and Shift-Tab step within a
  multi-field control first. Down returns to the remembered main field.
  Enter, landing on a pill that's already open (the ordinary case, since
  arrival auto-opens), closes it the same way it does from inside a field,
  below — it is no longer the way to open one, except for `more`, the one
  pill that stays chip-focused and pops its own dialog on Enter or a tap.
- **In an open control**, Down or Enter closes it and returns to the main
  field the operator was in before — not the pill. Up closes it too, but
  keeps going the same direction Up already takes from a bare pill: onward
  into the QSO list. Enter does *not* log, in any secondary control —
  logging is one rung down, from a main field. (It used to log from all of
  them: the radio control by its own submit handler, the reference controls
  and the spot comment by falling through to the panel's Enter shortcut. The
  spot comment is a partial exception again now — see the Status section's
  note on the Send button.)
- **In the QSO list**, Up and Down walk the log, loading each contact into
  the editor **without moving focus**, so the next arrow keeps walking.
  Event and annotation rows are skipped, since they aren't editable
  contacts. Enter restores whichever main field the operator was last in
  before arrowing up (the callsign field if none is remembered) with that
  contact still loaded — this is "resume editing where I left off," not
  "start fresh," which is what Escape below is for. Down past the newest
  contact deselects back to the QSO that was being composed and leaves for
  the pills, opening the remembered one the same way Up from a main field
  does — see "The composing draft" below for what "deselects back to"
  actually restores.

  The list also takes the jumps every list is expected to: **Home** and
  **End** go to the oldest and newest contact, **Page Up** and **Page Down**
  move a screenful (as many rows as fit, less one carried over for context),
  and on macOS **Cmd+Up/Down** repeat Home/End while **Option+Up/Down**
  repeat the page keys. Unlike a single-row Down, none of them ever walks off
  the end of the list — they stop at the last contact, because nobody presses
  Page Down meaning "and then leave".

**Escape** is the way *out*, at every rung, one layer per press: an open
suggestion menu, then an open control (back to the main fields, the same
destination Down/Enter reach above) — then the editing session, back
specifically to the callsign field, a "start a fresh QSO" gesture unlike
Enter/Down-past-the-newest's "resume where I left off" — then the composed
QSO. It never walks back *in*: in particular a second Escape does not
re-select the QSO the first one deselected, which it used to do.

### The composing draft

Stepping away from a QSO being composed — Up into the list, or a click on an
earlier row — to look at or edit an earlier contact does not lose what was
typed. The draft (every field, including ones like grid/state that only
round-trip when explicitly touched) is snapshotted the instant the detour
starts and restored exactly when it ends, whichever way that happens:
Escape, Enter/save, or Down off the newest row. Switching directly between
two earlier contacts (arrowing further, or another click) keeps the
*original* snapshot — only the trip back to composing restores it, so a
detour through several contacts doesn't silently keep the last one's data
instead of the first's.

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

- **A default is a placeholder, never a pre-filled value.** The Sent and Rcvd
  reports show the mode's default as a faint hint over an empty field, the
  same way a looked-up Grid or State does, so giving a true report is one
  keystroke rather than a clear-then-type. The default becomes real on the way
  out, in the one place every consumer reads the QSO from, so what is logged,
  scored, spotted and exported is exactly what it was when the field held the
  text. The hint is absent while editing a saved record: there a blank field is
  stored data, and a hint would promise a value the save would not write.
- **A report is completed from its significant part.** `5` becomes `55`, `2`
  becomes `32` (readability tracks strength — an S2 signal isn't fully
  readable), and on CW and RTTY the tone digit is filled in too: `5` → `559`,
  `57` → `579`, with `4A` → `44A` for aurora. It happens when focus leaves the
  field *and* again where the default materializes — Enter never blurs, so the
  field the operator logs from is one that never left focus, and would
  otherwise carry a bare `5` into the record. `defaultRSTFor`/`expandRST` in
  halo_core hold both rules. The FT modes are exempt from all of it: their
  exchange is a signal-to-noise figure (`+0`, `-12`), which every rule above
  would mangle.
- **The default is the operator's to change, in three bands** — phone, CW and
  data, and the FT modes — from Logging settings. An empty setting means the
  standard report rather than a blank one, so clearing the field restores
  `59`/`599`/`+0` and nothing outside `defaultRSTFor` has to name them. The
  override changes the *value* only: which modes fall in which band, and what
  the completion above does with a partial report, stay properties of the
  mode.
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

- Making "nothing focused → the callsign field" a standing invariant rather
  than something re-asserted after each action. Blocked on a decision, not on
  the work; see [backlog.md](../backlog.md). Enter is no longer one of the
  actions needing that re-assertion — it doesn't drop focus in the first
  place (§ "Enter and focus") — which narrows the rule without settling it.
  (The other mobile rule — starting with no field focused when no physical
  keyboard is attached — is implemented; see the carve-out in § "Which field
  has focus".)
- The serial fields' `focus: 'skip'` opt-out noted above, which does not exist
  yet.
- The Log button, which the focus ladder doesn't reach: Tab loops within the
  entry row and Arrow Up leaves it for the pills, so pressing Log still takes a
  pointer. Enter from any main field logs, so this is a gap in reaching the
  *button*, not in logging.
- The spotting control's Send button, same gap: Tab within an open control
  only steps through its own fields (see "Focus and the secondary controls"),
  never reaching a button. Enter from the comment field sends the spot before
  closing the control, the same substitute the Log button has, so this too is
  a gap in reaching the *button*, not in sending.
