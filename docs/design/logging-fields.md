# Logging fields

The logging controls are the area of the Logging Panel for adding or editing
QSOs — the hottest path in the app, and the one place where keyboard
ergonomics are a contract rather than a nicety (see [DESIGN.md](../../DESIGN.md)
§7). They have three parts: the main logging controls, the information area,
and the secondary logging controls.

Implemented in `packages/halo_widgets/lib/src/logging_controls.dart`, which owns a model per concern
beside it: the Radio control (`logging_controls_radio.dart`), the callsign lookup and scoring
(`logging_controls_lookup.dart`), the command being typed (`logging_controls_command.dart`), the Time
and Spotting controls (`logging_controls_time.dart`, `logging_controls_spotting.dart`), the contest
exchange fields with their options menu and serial previews (`logging_controls_exchange.dart`), the
activity refs and the controls they belong to (`logging_controls_refs.dart`), the draft itself —
what the record carries beyond the fields, and the one bracket for a programmatic write
(`logging_controls_draft.dart`) — the focus ladder, every keyboard move between the rungs
(`logging_controls_ladder.dart`), and the default-focus backstop (`logging_controls_focus.dart`); the
call field's reading rules are `call_field_text.dart`, the row's sizing arithmetic
`logging_controls_metrics.dart`, and the information area `logging_info_area.dart`.

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

Time and Radio can't be hidden; the rest the operator turns on and off in
the row's own settings dialog. A control may also ship **off** — Power and
Notes both do, since most operators state neither per QSO — and stays out
until the operator has been asked. Their saved order is what records that they were:
the dialog writes every key it offered, so a default-hidden key missing from
the order means "never decided", not "decided against", and no second stored
set is needed to tell those apart. Power in particular changes what is
logged: showing it is the operator asking for each QSO to carry the power it
was worked at, and Station Configuration's "Track Station Info" asks for the
same thing a different way (`trackingPower`). Either one puts a Power field
in the More pane after Mode — as does a record that already carries a power,
whether or not anything is tracking one now, because a value nothing
displays is a value nothing can correct.

Notes is a single free-prose field for the contact's own `notes` — the same
value the More pane's Notes field edits, so the two are two views of one
string rather than two places to write it, and its chip carries the ✓ the
reference controls use to say a field is filled in.

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

## When the form is read-only

Everything below assumes the form accepts input. It does not always: the entry
row locks whole, fields and save and keyboard shortcuts alike, and the reason
appears where the call-info area normally sits. Three things lock it —

- a **staged delete**, where Delete has been tapped and not yet saved;
- an **already-deleted QSO** loaded for restore;
- an **operation this device may not write to** — a travelled clock over a
  non-test operation today (`WritePolicy`, [time.md §4](time.md)), and a
  shared operation this device only reads once that exists.

Locked means locked *before* the focus rules apply, not instead of them: no
field takes focus, so none of the movement below has anywhere to go. That is
deliberate for the third case in particular — a refusal raised when the
operator presses Enter would tell them a contact they had already typed did
not land, which is the thing this prevents.

## Which field has focus

The callsign field is the default: if no other field is focused, focus
belongs there.

That is an invariant, not a starting condition. The field's `autofocus`
takes it at mount and a handful of paths assert it on purpose (a spot tap,
the wipe after a log), but focus can fall to *nothing* in ways no caller is
part of — a dialog or sheet closing over a panel that had nothing focused, a
menu closing, a field in another pane being disposed, a stray `unfocus()` —
and each one would leave the operator typing into nothing. So the panel
listens to the `FocusManager` and, whenever primary focus lands on nothing,
gives it back to the callsign field at the end of the frame. "Nothing" is a null primary focus, one of the
callsign field's own ancestor scopes — the root, the route's, the panel's —
holding it for want of a child, or a **button** holding it: web hands a
clicked button the focus, and a dialog closing over it hands the focus
straight back to the button, so a button is not a claim. What is: anything
under the panel's own scope (its pills, its Band dropdown), a text field
anywhere, a `DropdownButton` anywhere, and a node that handles keys — the
mark of a surface the operator steers from, which is the QSO list. A scope
that is not on the panel's ancestry is a dialog's, sheet's, menu's or
overlay's own and is never robbed, whatever is in it, and neither is a route
pushed over the panel (`ModalRoute.isCurrent`). A locked form (above)
reclaims nothing, since its fields cannot take focus.

**Except on mobile with no physical keyboard attached**, where having no
field focused is fine — the view always starts that way, so the operator
isn't met with a virtual keyboard covering half the screen. On mobile the
backstop reclaims only if the operator's last claim on focus was in this
panel — they were typing here, and whatever took the focus was not them
asking for it to go — and a claim taken elsewhere on the route (a text
field in another pane) ends that. And **a panel field that loses focus to
nothing while the route stays current is the operator closing the
keyboard**: Done or Back in a secondary field (those keep Flutter's default,
which blurs), or tapping a focused, still-empty field a second time, which
blurs it as a way to dismiss the keyboard — a field you focused but haven't
typed into is the one case where there's nothing to lose by closing it
(implemented app-wide, not just for the logging fields, by
`TapToDismissEmptyField` in `keyboard_dismiss.dart`, since a per-field
opt-in would be silently missing from every field added later). That blur
is exactly the "nothing focused" the operator asked for: it is left alone,
and it ends the panel's claim, so a dialog opened and closed after it leaves
the keyboard down. The one blur that is not that is a sheet's on its way in
(`operation_view` unfocuses before it pushes), and it tells itself apart by
the route it pushes in the same turn — not current at the end of the frame,
so the claim is kept and the field is reclaimed when the sheet pops. Hence:
a dialog opened from the callsign field returns to it when dismissed,
keyboard and all; one opened after the operator closed the keyboard leaves
it down; one opened over an idle phone never pops a keyboard nobody asked
for. Keyboard state can draw none of these lines — it is down at every pop,
and still up at the instant of either kind of blur — which is why the panel
remembers instead. Nor does the hardware-keyboard flag override a
dismissal, though it governs the autofocus and the spot tap: a device can
report a hardware keyboard and still show the on-screen one (the simulator
always does; an iPad in a keyboard case can), and then the dismissal the
operator just made is the only thing worth believing.

**Nor while the app is away.** On desktop and web the `FocusManager` parks
focus on the root scope when the app goes inactive and restores it on
resume — but only if nothing took focus meanwhile. A reclaim there would be
that something, and an operator who switched apps from the QSO list would
come back to the callsign field; so the backstop ignores focus changes
while the app is not resumed, and looks again on resume for what it missed
(a parked field disposed while the app was away, a dialog that closed on
its own), since then the manager restores nothing and says nothing.

**A request already in flight wins.** The reclaim runs at the end of the
frame and first applies any focus request made earlier in that same phase —
the web view-focus guard putting a parked field back, a menu item handing
focus on — so that it reads as the claim it is rather than as "still
nothing".

**Editing an event row**, the panel has no callsign field; the event text
field stands in for it as the default.

Implemented by `DefaultFocusBackstop` in `logging_controls_focus.dart`,
which also owns the panel's Tab-trapping scope.

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

What the operator *sees* in the Mode field is the other half of that: the
sideband that place runs is shown as plain `SSB`, and only the one it does not
run is spelled out, in the error color. Picking `SSB` sets the sideband the
frequency calls for. Both rules are the same ones the QSO list and the spot
rows follow — see [cat.md](cat.md)'s "Showing it back: `SSB` unless it
contradicts".

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

**Unless the operator is not here.** A contact can be logged by a gesture made
on another surface — sliding a spot row past its commit point
([user-interface.md](user-interface.md) § Row gestures) — and there the return
to callsign is a keyboard thrown up over the list being worked, for an entry
nobody is about to type. So a log that did not come from this panel leaves the
focus where it is (`_log(focusCall: false)`), and that covers every way the
route can end: the wipe after a successful log, the wipe that clears the way at
an overwrite prompt, and the refusal to log at all — which reaches for the
callsign field to point at what needs fixing, and so points at a field the
operator cannot see. That last one leaves the refusal with no signal anywhere;
surfacing it where the gesture happened is [HALO-335](https://cabo.ham2k.com/halo/c/335).

The line this draws is the one [HALO-93](https://cabo.ham2k.com/halo/c/93)
drew for cold start, and the one the default-focus backstop above follows:
focus returns to callsign when the operator is standing in front of the
panel, and not otherwise. With a keyboard, focus was never anywhere but a
claim to begin with — the list the row was slid in is one — so the backstop
has nothing to say. On a phone the dismissal that took them to the list is
what clears the panel's memory of being their place, and `focusCall: false`
keeps the log itself from re-asserting it.

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

**The frequency field itself takes a band**, which matters because it is the
field this refusal opens on: `40`, `40m` and `70cm` all set the band and clear
the field, exactly as the dropdown beside it does. It resolves when the
operator leaves the field, not per keystroke, so a frequency typed digit by
digit never passes through a band on its way; a number that names a real
frequency is never re-read as one. The bare form exists because this field's
iOS keyboard carries no letters, and it is unambiguous only because no band's
wavelength in meters is also a frequency inside a band — `parseBandInput` in
`halo_core` holds that reasoning, and a test pins the property against future
edits to the band table.

Every band the app knows is reachable by name, millimeter bands included, but
those need their unit: the bare form falls back from meters to centimeters
("70" is 70cm because there is no 70m band) and stops there, since "1" means
1mm to nobody and a bare number that named the wrong band is worse than one
that names none. `75m` and `2200m` resolve as the names operators say for 80m
and 2190m. The `40M` command reads the same vocabulary, from its own copy in
the radio-commands extension.

That vocabulary is deliberately wider than the Band dropdown beside the field,
which offers only the bands enabled in Settings: naming a band is how an
operator reaches one they work too rarely to have enabled, and the dropdown
appends whatever band is current, so the one they named still displays.

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

**And said out loud for as long as it's true.** A red `No Band` pill stands at
the top of the information area whenever the contact in hand would be logged
with neither, and a `No Mode` pill whenever it would carry no mode. Unlike the
auto-open, which fires once per install, and the refusal, which speaks only
after a station has been worked, the pills are on screen the whole time the
condition holds — before a callsign is typed, beside the call-info line once
one is, and over a grid-with-no-call. They read the same band-OR-frequency
condition the refusal does, so the two can never disagree about what is
missing.

They sit **above** a command's message, refusal included, rather than being
replaced by it. That message outlives the condition that wrote it — only a
call-field keystroke clears it, not the band pick that answers it — so a
warning underneath would go quiet exactly while the operator was doing what
the refusal asked, and would stay quiet about anything still missing.

Two states show no pill. An event row (a NOTE or TODO) is not a contact and
needs no band. And whenever the fields are locked — a staged delete, an
already-deleted contact, or an operation that cannot be written to — the
information area is replaced by that warning outright, and this never runs.
Nothing in either state can log a contact, so nothing is lost by staying
quiet there.

Tapping the pill does nothing. The area's tap opens the *other station's*
detail panel, which is no answer to a question about our own radio, so the
gesture is applied to the call-info content and not to the warning above it.

The mode pill is the narrower of the two: nothing the operator can do in the
panel empties the mode, since it starts on the hardcoded `SSB` above and every
path that moves it writes a real emission. An extension command that sets an
empty mode is what it catches.

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

## More than one call in the field

The callsign field takes three multi-call syntaxes. They are separate
features that meet on the same Enter, so the order they are resolved in is
part of the contract, not an implementation detail.

**A comma list logs one QSO per call** — `W1AW,K1ABC` writes two contacts
sharing every other attribute, each five seconds after the last. The
displayed serial belongs to the first call only, the one number the operator
actually read out; everyone after it takes the next in the series. No entry
inherits another's looked-up name or guess: each is saved bare and gets its
own background lookup, rather than every call in the list carrying whatever
was cached for the one the operator happened to be on. A typed grid or state
still reaches all of them — that is usually a station-wide correction — but a
typed name is not duplicated, being specific to whoever it was entered for.
(Editing is the exception: the record being edited keeps everything it
already had, and only the calls added alongside it are new.) A single call
with no comma is just a one-item list, so this is also the common path. The
list is all-or-nothing: one implausible entry and nothing logs.

**`//` stacks calls** — a second station worked in while the first is still
queued up. `K1ABC//W1AW` holds both, and Enter logs *one* segment: the one
the cursor is in, or, when that isn't a callsign yet, the first one to its
left that is. The rest stay in the field for the next contact. Nothing
carries over between them — logging one wipes the entry fully (refs, notes,
overrides, reports, manual time) before restoring the remainder, exactly as
if the operator had just typed it.

A stacked segment may itself be a comma list, and then every call in it logs.
That shape is what a mid-stack note expansion leaves behind, so treating it
as un-loggable would strand the operator on a key they had just expanded.

**A note key expands into calls** — `//KEY` looks up a Callsign Notes entry
whose note reads as a plain comma list of calls and replaces the field with
it (the `call-notes` extension's `command` hook; see
[extensions/hooks.md](../extensions/hooks.md)). The same works on one segment
of a stack: `KI2D//1AB` expands to `KI2D//W1AB,W1AC`, leaving the calls
already stacked ahead of it untouched. A key can also lead the stack —
`//1AB//W1AW` is both syntaxes at once, and gets both, one Enter at a time:
the stack's first segment is simply empty, and which of the two an Enter acts
on is decided by the cursor, exactly as step 2 below describes. The leading
`//` is a separator, never a segment the cursor is inside, so a cursor at the
very start belongs to the key that follows it.

**An expansion logs nothing.** It is a rewrite of the field that the *next*
Enter then acts on, and it is exempt from the band-or-frequency refusal
above — there is no contact yet for a missing band to spoil, and refusing
would leave the operator unable to even see what the key expands to. The
cursor stays on the segment that expanded, because that is the segment the
next Enter has to pick.

The order on Enter, and why each step is where it is:

1. **A whole-field command runs first**, note expansion included. A field
   that starts with `//` is a stack like any other, so what keeps `//W1AW`
   from logging W1AW — a note key is usually itself a valid-looking callsign
   — is this step running before stacking does, not stacking refusing the
   field. A key nothing recognizes falls through and logs as the callsign it
   looks like.
2. **Then the segment under the cursor is offered for expansion**, which is
   the only way a key stacked alongside other calls is ever seen — step 1
   only ever looks at the whole field.
3. **Then stacking**, which takes priority over the comma list: a field can't
   meaningfully be both, and `//` is the more specific syntax.
4. **Then the comma list**, which a plain single callsign also travels.

**A key expands at most once per composing entry.** In a stack the `//` is
the separator between calls, not the operator asking to expand, so a note
keyed on a real callsign — the common case for a stacked segment — would
otherwise capture that station for good: Enter expands it, and deleting what
the expansion added and pressing Enter expands it again. Spending the key
instead means taking the expansion back and pressing Enter logs the call
itself. That state belongs to the draft, not the session: it resets on
log/wipe, on the field emptying, and when a QSO context is populated, so the
next contact typing the same key gets its expansion. It is deliberately *not*
reset on a keystroke, which would forget the expansion the operator had just
undone. A whole-field `//KEY` consults none of this — there the `//` is
explicit.

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
- **In the QSO list**, Up and Down walk the log, loading each row into
  the editor **without moving focus**, so the next arrow keeps walking.
  Event and annotation rows (operation start/break/end, NOTE/TODO/SOLAR/
  WEATHER) load too — the main fields swap for that row's inline event
  editor (a kind field and, for NOTE/TODO, its text) instead of a contact's
  fields, and every secondary control but Time is disabled — shown, not
  hidden, so the row's shape stays the same as a contact's. Enter restores
  whichever main field the operator was last in
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

## The More pane

The pill that opens a Modal Pane instead of expanding, and the one surface
that shows everything a contact can hold. Built in
`qso_edit_pane.dart` on the FormRenderer engine (`showFormPane`), in four
sections:

- **QSO** — Date, Time, Frequency, Band, Mode, Power, Sent, Rcvd.
- **Their info** — Call, Name, City, State, County, Entity, CQ Zone, ITU
  Zone, ARRL Section, Grid, Latitude, Longitude, Their power.
- **Our info** — Operator, Position.
- **Notes** — Notes.

Four rules hold that shape together.

**Sent and Rcvd stay in the QSO section, together.** app-polo's Edit QSO
screen splits them between Their Info and Our Info. Here they cannot be
split: one place resolves which is drawn first (`_rstPaneKeyOrder`), and the
row, the key cycle and the QSO list's report cell all read it — a pane that
put them under two headings would contradict the row that opened it.

**County and ARRL Section appear only for a US contact** — the same three
country-file entities the scorer calls US (`K`, `KL`, `KH6`), read from the
entered entity prefix and then the guess. app-polo asks on the bare `K`, which
hides both fields from Alaska and Hawaii; those carry no state of their own, so
the section is the only place their location could be recorded. Both name a US administrative
division, and offering one over a DX contact is offering a field with no
possible answer. **Entity is shown and never taken**: it follows from the
callsign, and nothing here could correct it.

**A value the pane merely displayed is never recorded as an entered one.**
Every `their` field the pane owns outright goes into the record through an
override map (`QsoDraft.theirExtra`, the same shape `ourExtra` has for
Operator/Position), and a key lands there only where the pane actually
CHANGED it. Without that, opening a contact and saving it would promote its
lookup's guesses to entered values and stop the lookup tracking them — the
same trap `QsoDraft.gridTouched` exists for on the primary Grid field.

**Editing the Grid drops the coordinate override, and blanks the two fields
on screen.** The drop is what counts: the pane's on-screen clear runs on blur,
and `submit()` reads its values before the unfocus it triggers is delivered, so
a grid typed and submitted from inside the field would otherwise be saved
alongside the pair it was meant to replace. A coordinate
outranks a grid wherever one is read ([locations.md](locations.md)), and the
save path already clears the pair for a typed grid; blanking the fields is
what keeps the pane from showing a locator the app is about to ignore. A
coordinate typed here still wins — the clear exists to stop a *stale* pair
surviving a typed grid, not to overrule one the operator just stated.

Three fields app-polo offers are deliberately absent. **Our station call**:
the save path stamps the operation's own, and which of several callsigns made
a given contact is not recorded per QSO. **Their exchange** and **our
exchange**: contest exchanges live in refs here, surfaced as their own
controls ([contests.md](contests.md)).

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
