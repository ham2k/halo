# User Interface Design

## Concepts

- **Views** are the screens or windows the user interacts with.
- **Panels** are the main components of a view, laid out next to each other
  or as tabs.
- **Areas** are sections or groups inside a panel.

## Branding

The app is formally called "Ham2K Logger". On desktop it identifies itself as
"Ham2K Logger"; on mobile, "Ham2K Portable Logger".

- The package name / identifier is `com.ham2k.logger`.
- "HaLo" (or "halo") is used internally — package names, identifiers — but
  never in content shown to users.
- Where the app name stands alone (headers, dialog titles), use the Ham2K
  wordmark graphic plus the text "Logger" or "Portable Logger", either to the
  right of the logo (left-aligned, vertically centered) or below it
  (centered).
- When mentioning the app in text, use the formal name "Ham2K Logger" or
  "Ham2K Portable Logger" — never "HaLo".

### Splash screens

Two distinct things are both loosely called "the splash" — keep them separate:

- **The real startup splash** ([`splash_view.dart`](../../app/lib/views/splash_view.dart)'s
  `SplashScreen`, and the web loading page in
  [`web/index.html`](../../app/web/index.html)'s `#startup-splash`). This is the
  first frame shown on launch, before `bootstrap()` runs. It is deliberately
  minimal: just the per-edition Ham2K square logo on the surface background, with
  the web loading spinner's footprint reserved as an empty placeholder so the
  HTML→Flutter handoff is a visual no-op. It shows **no version info**; the build
  edition is conveyed only by the logo art (Dev/Next/Regular), which is a
  compile-time constant (`kEdition`) available immediately, before bootstrap. On
  web the splash logo is swapped to match via `scripts/apply-web-edition.sh`.
- **The "version splash" overlay** ([`release_overlay.dart`](../../app/lib/views/release_overlay.dart)'s
  photo/wordmark overlay). A richer, edition-aware panel over the release photo:
  the brand mark (arc wordmark + product name + edition badge), the credits, and
  the release name. Shown for release notes and when tapping the About-screen
  logo — never at startup.

### Overlays that pin their own palette

The onboarding, release and tester overlays sit over a photo rather than the
app chrome, so their panel colours are fixed regardless of the app's light/dark
mode: each pins its subtree to `buildHaLoTheme(Brightness.light)`. Anything not
explicitly forced (markdown styles, scrollbars, button ink, a field's focus
border) would otherwise paint dark-mode colours onto the white band.

**The pin must sit ABOVE the class that reads the theme — never inside it.**
A class whose `build` creates the pin has a `context` that is an *ancestor* of
it, so anything on that class resolving a theme reads the app's ambient
brightness instead. That failure is invisible in every way that usually catches
one: nothing throws, nothing logs, and in light mode the wrong code and the
right code are indistinguishable.

The rule this leaves is checkable by reading a file: **no class both pins a
theme and reads one.** Give the content its own widget below the pin.

That rule is enforced by reading, not by a test — no widget test distinguishes
a method that takes a `BuildContext` parameter from one that falls back to
`State.context`, because the correct shape and the broken one build the same
tree. What tests *can* cover is the resolution, and there the trap repeats:
asserting `Theme.of` at a widget in the tree proves only that the pin exists,
since every context in the tree is below it either way. A test that can fail
has to assert a value a build method **resolved**, with the app theme dark —
`onboarding_test.dart`'s "the callsign field still focuses DARK" is the model.

## Main views

The app has three main views:

- **Home View** — a list of all operations, plus a button to start a new one.
- **Operation View** — the main view for an operation: its QSOs, logging
  controls, and related information.
- **Settings View** — app configuration.

### Home View

The Home View shows all operations in an "Operation List Panel", sorted most
recent first, with a button to start a new operation.

The header shows "Desktop Logger" on desktop platforms and "Portable Logger"
on mobile, plus a button that opens the Settings View.

At the bottom, a "Quick Lookup Panel" has a field where the user can enter a
callsign to see information about it, or enter commands. Results appear just
above the field.

### Operation View

The Operation View has four main panels:

- **Logging Panel** — the QSOs of the current operation, plus logging
  controls to add or edit QSOs.
- **Spots Panel** — spots relevant to the operation.
- **Map Panel** — a map of the operation's QSOs.
- **Operation Settings Panel** — settings for the current operation.

Normally all four panels display as tabs, with the Logging Panel tab showing
the QSO count. If the view is wide enough, the Logging Panel moves to the
left and the other panels group as tabs on the right — with an extra "Info"
tab first — and a user-resizable split between them. The size thresholds and
split mechanics are defined in [layouts.md](layouts.md).

### Logging controls

The logging controls are the area of the Logging Panel for adding or editing
QSOs: the main logging controls, the information area, and the secondary
logging controls. What each part holds, the keyboard rules that move focus
between the main fields, and the ladder that reaches the secondary controls
and the QSO list from them, are specified in
[logging-fields.md](logging-fields.md).

## Interface scaling

The **Font Scale** setting scales the entire interface — text, controls,
spacing, everything — by one uniform factor from a single root wrapper. It
is not a text-only setting. The mechanism and, crucially, the rules that
keep it working (never scale dimensions by hand; write plain logical pixels;
macOS traffic-light clearance) are documented in
[ui-scaling.md](ui-scaling.md) — read it before touching anything scaling-,
layout-, or macOS-window-related.

## General layout

How views arrange their panes at each window size — the shirt-size
breakpoints, the ideal pane width, resizable splits, and Modal Panes — is
specified in [layouts.md](layouts.md), which also covers **Layout Density**:
the height vocabulary that decides how much room rows, headers and tab strips
spend, chosen from the window's height and overridable by the operator.

### Spacing

**Every padding, margin and gap is one of seven rungs**, named on `Space`
([`spacing.dart`](../../packages/halo_widgets/lib/src/spacing.dart)):

| Rung | Value | Role |
|---|---|---|
| `xxs` | 2 | hairline separation — two lines of one record; a nudge that must not read as a gap |
| `xs` | 4 | a glyph and its label; the inset of a chip or pill |
| `sm` | 6 | a compact row's vertical breathing room |
| `md` | **8** | **the default** — between two related controls, and whenever no rung is obviously better |
| `lg` | 12 | a list row's own inset; between a group's members |
| `xl` | 16 | the padding of a panel, card or dialog body; between groups |
| `xxl` | 24 | between major sections of a scrolling view |

Pick by **role, not arithmetic**. The ladder is deliberately short — its job
is to give new UI a small menu to choose from, and a rung two pixels from its
neighbour defeats that. A new rung needs a role none of these covers, not a
site that happens to want an in-between number.

Values are plain logical pixels, like every other dimension
([ui-scaling.md](ui-scaling.md) rule 2) — the root `UiScale` already
multiplies the whole tree, so a spacing value is never scaled by hand.

Three rules that are not obvious:

- **A value that fits no rung is usually a *size*, not spacing** — a row
  height, a control diameter, a map camera inset — and belongs in a named
  constant of its own. Those are legitimately off-ladder; a handful exist
  (the map views' camera and fit-bounds insets, the splash view's mirror of
  the HTML loading page's box model, and two paddings that stand in for
  content still loading — a spinner inside a fixed box, and a QR code's
  reserved footprint) and each is recorded with its reason in the guard test
  below.
- **A measurement that mirrors a gap must name the same rung, never repeat
  its value.** `TextPainter` width math that hand-copies a widget's padding
  measures the wrong widget the moment the rung moves, and the layout still
  builds — it just reserves the wrong width and mis-wraps. `logging_controls
  .dart`'s notice-pill and call-note measurements are the worked examples.
- **`Space` is not [`ShirtSize`](layouts.md).** They share the t-shirt idiom
  and nothing else: `ShirtSize` classifies a *window* to choose a pane
  arrangement, `Space` measures a *gap*. The rungs don't correspond and
  neither derives from the other.

`app/test/spacing_vocabulary_test.dart` enforces this: it parses every
`EdgeInsets` argument and every childless single-axis `SizedBox` in both
packages and fails on a bare literal, the same way
`no_hover_tooltips_test.dart` enforces the no-tooltip rule. An off-ladder
value that is genuinely a size goes in that test's allowlist, with the reason
it is not spacing.

### Buttons and hover labels

**No tooltips.** Icon-only buttons do not get a hover label — never pass
`tooltip:` to an `IconButton` (or wrap a control in a `Tooltip`). A label that
pops up over whatever is under the pointer is noise on desktop, and on touch
it is unreachable anyway; an icon that needs a hover label to be understood
needs a better icon, or a visible text label.

Icons still need an accessible name for screen readers. Put it on the icon
itself — `Icon(MdiIcons.close, semanticLabel: t.common.close)` — which names the
button without displaying anything, and flips with state where the icon does
(Show/Hide, Delete/Revert/Restore). Tests find these buttons with
`find.bySemanticsLabel(...)`, not `find.byTooltip(...)`.

Flutter's own built-ins (`BackButton`, `CloseButton`, `PopupMenuButton`, a
`Chip`'s delete icon) supply a tooltip from `MaterialLocalizations` and take no
parameter to turn it off, so the app root wraps everything in
`TooltipVisibility(visible: false)` (`main.dart`). That is what actually
enforces the rule; not setting `tooltip:` in our own code is the other half.
Both halves are guarded by `app/test/no_hover_tooltips_test.dart`.

Widget APIs that let a caller name an icon-only button do so with a `…Label`
parameter (`closeLabel`, `expandLabel`/`collapseLabel`, `clearLabel`,
`openPageLabel`) — the app passes a translated string, and the widget package
defaults it to English so it stays i18n-free. Nothing named `…Tooltip`
survives; don't add one back.

### Icons

The app's icon language is **Material Design Icons** (Pictogrammers MDI, the
same set app-polo uses), with FontAwesome6 solid as a secondary set for
extensions. Flutter's own `Icons.*` are **never used in our code** — they are
Material-style glyphs in an MDI UI. The built-in MaterialIcons font still
ships (`uses-material-design: true`), but only as a safety net: Flutter
renders some glyphs internally with no override point (the Android
text-selection toolbar's overflow buttons, flutter_markdown's task-list
checkboxes), and those cannot be enumerated, so without the font each one
would surface as a missing-glyph box.

- **Core Dart uses `MdiIcons.*` consts** (generated, one per MDI icon —
  `MdiIcons.cloudSync` for `'cloud-sync'`), so a bad name is an analyzer
  error.
- **Extensions name icons as strings** (`icon: 'pine-tree'`, or `'fa-tree'`
  for FontAwesome solid), resolved at runtime by `resolveIconName` with a
  puzzle-piece fallback (or the call site's `fallback:`) for unknown names.
  Literal names in core Dart are not allowed — `resolveIconName` is for
  extension-supplied data only.
- **Framework widgets whose default glyph we can override get MDI**, the
  canonical list: `buildHaLoTheme`'s `actionIconTheme` covers
  Back/Close/Drawer buttons app-wide; `DropdownMenu` and
  `DropdownButtonFormField` take the shared `dropdownTrailingIcon`/
  `dropdownSelectedTrailingIcon` consts from theme.dart at each site;
  `SegmentedButton` sets `showSelectedIcon: false`; `ExpansionTile` needs a
  hand-flipped MDI `trailing:` (see `_CollapsibleMarkdown`). Adopting a new
  Material widget with a built-in glyph means extending this list.

All of this is enforced by `packages/halo_build_tools/test/icon_names_test.dart`,
which validates every extension icon name against the vendored glyphmaps and
rejects `Icons.*` or literal icon names in core Dart. Fonts and name tables
are vendored as pinned pairs from the icon projects' own packages by
`packages/halo_widgets/tool/update_icons.py`, which proves the pairing
against each font's cmap.

### Header

Windows (or screens on mobile) have a header with a title and optional
subtitle, a logo or back arrow on the left, and one or more buttons on the
right. When the window is wide enough for split views, the title and
subtitle are left-aligned; on narrow windows they are centered.

### Footer & User Feedback

A footer at the bottom of the window can show progress bars and status messages (`StatusBarService`). It includes padding so rounded screen corners don't cover it.

**It stays visible while the on-screen keyboard is up**, riding directly above it — a sync's progress or a command's output is most relevant exactly while the operator is typing, and it used to be hidden outright at that moment. This is why `_StatusBarOverlay` reserves the keyboard's height for the whole app: the routes below it run full height behind the keyboard (both mobile Scaffolds set `resizeToAvoidBottomInset: false`), so the panes reserve only the bottom safe area and let the overlay hold back the keyboard. Reserving the keyboard inside a pane as well would hold the same strip back twice and leave its fields floating in the gap.

The app follows a selective user feedback policy:
- **Immediate interactive actions** (e.g. copying text to the clipboard) display a floating Flutter `SnackBar` toast.
- **Multi-second operations** (e.g. data file sync/refresh, patch checks, export generation) report progress and status via `StatusBarService` items in the footer.
- **Logging screen / UI feedback** (e.g. activity reference validation errors or call field command outputs) use `StatusBarService` messages so toasts never obscure or interfere with the logging UI.

## Dialogs

Dialogs can have a title and subtitle pinned at the top, content in the
middle, and a set of action buttons pinned at the bottom. Clicking outside
the dialog or pressing Escape dismisses it.

Every footer is `haloDialogFooterRow` — one implementation, not a convention
each dialog follows on its own. It carries four roles, and `HaloDialog`,
`showFormDialog` and `showFormPane` all take the same four:

| Role | Where it sits | What it is |
| --- | --- | --- |
| `destructive` | leading edge, alone | A verb that destroys what the operator is looking at |
| `secondary` | trailing group, leftmost | Something else to **do** with the thing being edited |
| `cancel` | trailing group, next to the primary | The way out |
| `actions` | trailing edge | The primary/confirm action, normally one `FilledButton` |

This follows Material, which end-aligns dialog buttons with the dismissive
action immediately left of the confirming one, and gives the leading edge to
its `neutral` button — the position `destructive` takes here.

**The one deliberate divergence** is the gap: `haloDialogCancelGap`
(`Space.xxl`, three times the spacing between any other pair) separates
`cancel` from the primary. A logging operator works this footer at speed, and
Cancel discards what they just typed; the gap is what stops a mis-aimed tap on
Save from landing on it. Material spaces all its dialog buttons uniformly.

`cancel` stays a slot of its own rather than being listed first in `actions`,
even though both now render in the same group: **only that slot gets the gap**,
so a Cancel passed through `actions` lands flush against Save.
`app/test/dialog_footer_convention_test.dart` fails the build when one does,
and when a dialog reaches for a raw `AlertDialog` instead of `HaloDialog`.

### Which verb

- **`Cancel`** when there are pending changes to abandon.
- **`Done`**, as a plain `TextButton`, when there are not — a dialog whose
  changes have already taken effect, even when other actions sit beside it.
  Never a filled button: there is no action to emphasise. `Close` and `Apply`
  are not dialog-footer verbs (`Close` remains a Modal Pane header icon
  button's accessible name, which is not a footer button).
- **`Save`**, filled, when pressing it is what applies the change — or better,
  a specific verb for what actually happens: `Delete`, `Remove`, `Replace`,
  `Link Account`, `Link Device`.
- A clearer word for the situation wins over all of the above: `Dismiss` on an
  alert the operator is being asked to acknowledge.

A dialog whose every row is itself an action (a menu, an option picker) needs
no footer at all; this rule governs dialogs that **have** a dismiss button, not
which dialogs need one.

Pane-sized dialogs — "Modal Panes" — additionally present as full screens on
phone-sized windows; see [layouts.md](layouts.md).

### Command dialog

⌘K (⌃K on Windows/Linux) opens the **command dialog** from anywhere in the
app: a search field near the top-middle of the window — rounded, with a thick
teal border — and, **attached directly beneath it**, a card carrying the
results. The card's top edge butts against the bar (square top corners,
rounded bottom, and the bar's shadow doesn't fall on it), and its sides line
up with the bar's search icon, so the two read as one object. The bar's
height is fixed, so it doesn't resize when the placeholder gives way to typed
text. Escape, a click outside, or a second ⌘K dismisses it.

On iOS, plain ⌘K is reserved by the OS itself (it shows/hides the software
keyboard) and never reaches the app on a hardware keyboard, and ⌘⇧K is
reserved too (at least on the Simulator) — ⌘⌥K is the chord that actually
opens the dialog there (main.dart's `_handleKeyEvent` and AppDelegate.swift's
`keyCommands` both accept ⌘⇧K and ⌘⌥K as alternates everywhere).

The field's placeholder is set in the regular face — it's prose — while what
the user types is monospaced, since it's a callsign or a command.

One field, four kinds of result:

- **Commands** extensions advertise through their `catalog` hook
  ([hooks.md](../extensions/hooks.md#catalog--advertising-commands-to-the-k-dialog)),
  narrowed by substring as the user types and **ranked name-first**: every
  match on a command's name outranks every match on its description, so
  typing "SET" offers SETUP before a band command merely described as "Set
  the band". Picking one with parameters types it into the field; picking one
  without runs it. The declaring extension's category shows as a trailing
  label rather than a grouping heading, since rows are ranked across
  categories.
- **What's typed**, when a `command` hook recognizes it — listed first, since
  running it is usually what Enter should do. A hook that answers with a
  placeholder and fills it in later (SOLAR describes itself as "Fetching solar
  conditions…" while its fetch runs, then pushes the reading through
  `host.updateInterpretation`) updates this row in place: the row IS the
  describe here, so a push that only reached the message line would leave the
  palette reading "Fetching…" long after the answer arrived.
- **Navigation** — Home, Settings, a new operation, or any existing operation
  matched by title.
- **The callsign lookup**, when the text looks like a callsign. It says
  "Looking up callsign…" the moment the text reads as one, fills in from the
  offline data files (country, often a name) as soon as they answer, then
  replaces that with the full online result. It renders through the very same
  `CallInfoPanel` the Call Info pane uses — notes, emoji, flag, distance and
  bearing, QSO history — rather than a summary line of its own, so a lookup
  here reads exactly as it does there. It sits below the selectable rows and
  is never the selection, so Enter keeps meaning "run the command".

↑/↓ move the selection, Enter activates it, and rows are tappable. Enter on
text that matches no command leaves it alone — on a callsign the lookup below
IS the result, and clearing the field would throw it away and drop the
palette back to its suggestions. (The Home bar keeps its own "Enter clears
the search" behaviour; the shared engine takes a flag for it.) An
operation-scoped command (SEED, NOTE, SPOT) is simply **not offered** when no
operation is open — listing something unpickable is noise, and picking it
would only produce the hook's error.

**What a command says lands in the bar it was typed into**, at the foot of the
results card — never the status bar, which outlives the route and would still
be carrying "Band set to 20m" over an unrelated screen minutes later. That
answer gets the card **to itself**, set at the field's own size rather than a
footnote's: executing clears the field, and an empty field is exactly what
puts the sample commands on screen, so without suppressing them the card reads
"here is what happened, and here are two unrelated things to try". A describe
or an interpret-time error stays small — that is commentary on text still
being typed, not the thing Enter was pressed for.

The palette therefore stays up after running a command and dismisses itself
once the response has had its five seconds. It closes at once when the command
had nothing to say; **Enter dismisses a response** rather than waiting it out,
since the field behind it is empty and Enter would otherwise be the one key
here that does nothing; and typing again cancels the dismissal, because those
five seconds are for a palette nobody is using. The consequence to know about
is that the palette holds focus for those seconds — an operator who runs a
band change and immediately types the next callsign puts it in the palette,
which then stays open.

A command ACTION's message (`syncAll`'s status, EXP's outcome, a failed
setting write) replaces the hook's `confirm` on that same line: the action is
the one that knows whether anything actually happened — **including whether it
is bad news**, which it says explicitly rather than leaving the wording to be
read. A failure gets the error wash and the alert icon: `updateSetting`
returns text only when it could NOT store the value, while `syncAll` returns
it either way, so nothing downstream could tell them apart. Within one batch
the worst news wins, not the last — a spot one source refused and the next
accepted must not read as success, because the operator's next move is to
spot the refused one again. It gets there through
`HaLoServices.commandResponseSink`, because with an operation open it is the
logging panel's dispatcher, not the bar, that runs those actions — the message
comes back through code the bar never touches, so a parameter could not carry
it. `CommandEngine` holds that slot open for the length of ONE command's
dispatch and no longer: every action's message arrives inside that awaited
window, and a slot held for a bar's whole lifetime instead catches messages
belonging to commands typed elsewhere — a SPOT started in the call field,
answering seconds later on a palette that has since opened, blanking its card
and dismissing it over a command that was never typed there. The Home bar's
message line works identically, minus the closing.

The five seconds start when the command **settles**, not when its confirm
appears: `syncAll` resyncs a whole account and a settings write can wait on an
extension validator, and a clock started at the confirm expires mid-flight —
closing the surface the action's own word was about to land on. If it lands
anyway with nowhere to go (the operator dismissed the palette meanwhile), the
status bar takes it: a message that reaches nobody is the one outcome ruled
out. DEVNOTICE/DEVSTATUS/DEVPROGRESS are the exception that proves the rule —
painting the status bar is what those commands are *for* — as is anything a
command finishes **after** its dispatch returns, notably RELOAD's data-file
progress, which reports there by design.

The sheet shows at most five rows and scrolls beyond that. An **empty field is
not a browse-everything list**: for the first ten opens it offers two random
sample commands so the feature is discoverable, and after that it stays quiet
until the user types. The open count rides on the same per-flow counter the
onboarding nudges use (`OnboardingFlows.commandDialog`).

**Driving it from outside.** The shortcut is a modifier combo, and those
don't reach the Flutter canvas — a synthetic `ctrl+k` no-ops, as does the
pre-existing ⌘⇧D — so on web the dev bridge (`window.__halo`, dev/preview
builds only) exposes `openCommandBar()`, `closeCommandBar()`,
`setCommandText()`, `commandSubmit()`, `commandMove()` and
`commandBarState()`. Without them the dialog can't be opened, driven, or even
looked at by a script or agent. `openCommandBar()` returns a **promise**:
the route mounts a frame after the call, and typing before that silently does
nothing — which looks exactly like the dialog having closed itself.

The typing behavior — debounced interpretation, execution, and the input
rules in `commandFieldFormatters` — is **not** the dialog's own: it lives in
`CommandEngine`, shared with the Home view's Quick Lookup bar so the two
can't drift apart. Those input rules are **positional, never interpreted**:
spaces are free (the engine reads the field trimmed), any run of whitespace
collapses to one plain space — a single-line field filters out `\n` and
nothing else, so tabs, CRs and non-breaking spaces do arrive — and only the
text up to the first whitespace is uppercased.
Nothing about a keystroke may wait on `interpret`, whose answer lands 150ms
later at the earliest and never lands at all while someone types steadily —
so `mixedCase` changes nothing in these two bars, and `expectsParams` only
still withholds execution rather than switching the field's mode. The
logging panel's call field is the one that asks, because Space is a
keystroke it owns and can await an answer for. The dialog runs commands
against the front-most Operation View's operation via
`HaLoServices.currentOperationContext`.

**Where a command's actions land.** Most `CommandAction`s are QSO-scoped —
`setVfo`, `addQso`, `updateQso`, `setCallField`, `sendSpots` — and only the
logging panel can apply them, since they need the in-progress QSO and its
controllers. So while a logging panel is mounted it publishes its dispatcher
as `HaLoServices.currentCommandDispatch`, and the dialog hands it the whole
action batch: a command run from the palette behaves exactly as if it had
been typed into the call field. The batch is never split — a command can
return several actions at once (satellites' SAT returns `setVfo` plus
`updateQso`), and their order matters. With no panel live (the Home bar, or
the dialog with nothing open) only the app-scoped actions can apply, and
`CommandEngine` handles those itself.

## Forms

Forms use a clear, consistent layout, with labels and fields aligned
properly. When a form renders in a view instead of a dialog, its actions are
pinned at the bottom, same as in a dialog.

Text fields pass `selectAllOnFocus: false`. Flutter defaults it to **true**
on web and desktop, so focusing a field flashes its whole contents selected
before collapsing the caret to the end — distracting, and wrong for fields
you focus to *append* to. The logging panel's own controls
(`logging_controls.dart`, `ref_text_input.dart`) manage selection
themselves; every other field opts out.

**A live filter hides what it excludes; it never unmounts it.** Anything that
re-filters a list of forms while the operator is still typing the query — All
Settings' search is the one that exists today — must keep the excluded
sections in the tree (`Visibility(maintainState: true)` plus `ExcludeFocus`,
so a hidden field stays out of the Tab order). Dropping a section instead
disposes every `FocusNode` and `TextEditingController` its `FormRenderer`
owns, and **on web that teardown takes the browser's text-input element with
it**: focus falls back to the route's scope and the next keystrokes are
swallowed, so the query loses characters as it is typed. There is no symptom
on macOS, which has no DOM — and none in a widget test either, because
`flutter test --platform chrome` drives text input through the test binding
rather than a DOM element, so no browser focus event ever fires. Test the
invariant (the sections are still mounted) rather than the symptom.

## Number Formatting

All numbers displayed in the user interface (including QSO counts, QSO row index numbers, scoring summaries, statistics tallies, and general quantities) must be formatted with thousands separators to enhance readability.
- In the Dart/Flutter core, use the `formatNumber` utility function exported by `halo_widgets`.
- In JS/TS extensions, use the `fmtInteger` (or `fmtNumber`) utility function from `@ham2k/lib-format-tools` when generating user-facing counts.

## Future directions

- A layout mechanism to drag-reorder secondary controls, and to drag one out
  of the strip into its own independent strip that stays open on its own.
- A more modular layout system, driven by JSON layout definitions per window
  or screen.
- Multiple windows, each with its own "current operation" context.
- A QSO List layout option with the logging controls on top and the list
  sorted most recent first (in addition to the current controls-below,
  oldest-first layout).
- Possibly theming, letting users customize the app's appearance.
