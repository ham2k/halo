# User Interface Design

## Concepts

- **Views** are the screens or windows the user interacts with.
- **Panels** are the main components of a view, laid out next to each other
  or as tabs.
- **Areas** are sections or groups inside a panel.

## Branding

The app is formally called "Ham2K Logger". On desktop and the web it identifies
itself as "Ham2K Power Logger"; on iOS and Android, "Ham2K Portable Logger".

- The package name / identifier is `com.ham2k.logger`.
- "HaLo" (or "halo") is used internally — package names, identifiers — but
  never in content shown to users.
- Where the app name stands alone (headers, dialog titles), use the Ham2K
  wordmark graphic plus the text "Power Logger" or "Portable Logger", either
  to the right of the logo (left-aligned, vertically centered) or below it
  (centered).
- The name the OS shows — the Dock/Finder label, the Windows title bar, the
  installers, the web manifests — is a separate thing that follows this one
  everywhere but Windows, which still says "Windows Logger" because that
  string keys the operator's stored credentials (see
  [releases.md §2.6](../releases.md)).
- When mentioning the app in text, use the formal name "Ham2K Logger",
  "Ham2K Power Logger" or "Ham2K Portable Logger" — never "HaLo".

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
  the version. Shown for release notes and when tapping the About-screen
  logo — never at startup.

  The version reads as two lines — `August '26 ALPHA` over
  `Patch 1 (build 130)` ([`version_label.dart`](../../app/lib/views/version_label.dart)'s
  `VersionLabel(nameAndBuild: true)`). Neither line wraps: over a brand mark a
  broken line reads as a layout bug, so the whole header block scales down
  instead (`release_overlay.dart`'s `overlayVersionHeader`, which the tester and
  onboarding overlays share; the home screen's right pane scales its branding
  column, which scales the version lines along with the logo). That header
  measures only itself and never the notes band below it, EXCEPT in the tester
  overlay, whose header is bounded to the space above its band so the block
  scales instead of sliding under it. That overlay can afford it because its
  band is a fixed fraction of the height; the release and onboarding bands
  animate open, and a header chasing a height in another coordinate space that
  moves is the cost this rule exists to avoid — there, on a phone-sized
  viewport, the band still covers the version lines entirely. The tester
  overlay, the onboarding overlay and the home pane show the same two lines,
  and none of them repeats the edition, which the brand mark's badge already
  carries.

  The tester overlay is the one deliberate divergence: its build number is a
  notes KEY, so it names the binary's number alone — no code push, no SHA, and
  named even on a Dev build where the others suppress it (`bareBuildNumber`).
  Making it match the rest would break the link between that header and the
  notes listed under it. No other surface may reach for that flag to fill an
  empty line: on Dev the number is the last release's, so it would name a
  binary that isn't running, in place of the SHA that is. A Dev build with no
  SHA baked in is left with only its qualifiers on that line, and on a patch-0
  version with no pre-release that is nothing at all — which is why the run
  tooling passes `HALO_GIT_SHA`, the way CI does.

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

The header shows "Power Logger" on desktop and the web, and "Portable Logger"
on iOS and Android, plus a button that opens the Settings View.

At the bottom, a "Quick Lookup Panel" has a field where the user can enter a
callsign to see information about it, or enter commands. Results appear just
above the field: a command's answer, or — for a callsign — the same compact
call-info area the logging controls show, rendered by the same
`CallInfoSummary` widget so the two cannot drift. It carries no distance and
no scoring pills here, deliberately: both are an operation's measurements and
the home screen has no open operation. The worked-before pill does show: how
often the log holds the station is the log's fact, not an operation's.

Enter belongs to a command whenever the text is one, including a command that
answered with an error — that answer is what the operator asked for and
nothing may cover it. Only when nothing ran does Enter open the full
`CallInfoPanel` for the callsign, the same panel the Call Info pane and the
⌘K dialog render.

Enter empties the field either way, as it always has, and **Escape** empties it
too. That ordering is a constraint, not a detail: clearing the field resets the
lookup on its way through the engine's text handler, so the call-info the panel
is built from has to be read *before* the submit that clears it.

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
  builds — it just reserves the wrong width and mis-wraps. `call_info_summary
  .dart`'s notice-pill and call-note measurements are the worked examples.
- **`Space` is not [`ShirtSize`](layouts.md).** They share the t-shirt idiom
  and nothing else: `ShirtSize` classifies a *window* to choose a pane
  arrangement, `Space` measures a *gap*. The rungs don't correspond and
  neither derives from the other.

`app/test/guards/spacing_vocabulary_test.dart` enforces this: it parses every
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
`TooltipVisibility(visible: false)` (`views/app_shell/halo_app.dart`). That is what actually
enforces the rule; not setting `tooltip:` in our own code is the other half.
Both halves are guarded by `app/test/guards/no_hover_tooltips_test.dart`.

**Animated SWAPS stay out of the semantics tree.** A widget that keeps an
outgoing subtree mounted beside its replacement and then destroys it —
`AnimatedSwitcher`, and the cross-fading stacks built on it — can stop a
completely unrelated text field from receiving keystrokes on web. The engine
gives every semantics node a DOM element chosen by its role and disposes that
element when the role changes; the framework recycles `SemanticsNode`s, so the
doubling-then-destroying hands a node on to some other widget, and one handed
to a focused field's neighbour takes that field's `<input>` with it. The caret
goes on blinking and the typing goes nowhere.

The swap is the trigger, not the node count. **A list that merely grows and
shrinks is not the same thing**, and the numbers are not close: the ⌘K
palette's results swing between 8 and 22 nodes as the operator types and
provoke nothing across a minute of it, alone or alongside a status-bar sync,
while the footer's switchers managed three blurs in five seconds over a
smaller swing. `command_dialog.dart` has no animated swap in its results, for
an unrelated reason (an `AnimatedSize` there clips hit-testing), and that is
what keeps it safe. Do not go restructuring a plain list on the strength of
this rule.

Chrome that does swap announces itself through ONE node whose *label* changes,
with `ExcludeSemantics` around the moving parts and any control inside hoisted
out of the animation so its own node survives. `StatusBarFooter`
(`halo_widgets/status_bar.dart`) is the worked example: a `liveRegion` for
messages, not announced for progress ticks (the label still changes; the
`liveRegion` flag is what stops it being read out several times a second),
dismiss button outside the switcher. The notice stack's peeking card is the
other half of the lesson — `IgnorePointer` does **not** remove semantics, and
`Opacity` only does so at exactly zero.

None of it applies to CONTENT — search results, a spot list, anything the
operator is meant to read. Excluding those would trade a focus bug for an
accessibility one; `ViewFocusGuard` (`app/lib/services/view_focus_guard.dart`)
is the net for whatever still gets through, and `DEVHAMMER` reproduces the
churn on demand.

An icon-only button still gets an accessible name — a `Semantics` label or
the icon's `semanticLabel` — read from the strings package like any other
text (`halo_widgets` reads `t` directly). A `…Label` parameter exists only
where the caller knows something the widget cannot (`closeLabel` on a pane
that is shown from several places), never as a way to keep a widget free of
the strings package. Nothing named `…Tooltip` survives; don't add one back.

**A tappable node's name has to fit inside it.** With semantics on — a screen
reader, or any non-release web build, where `main()` forces them on for agent
tooling — Flutter web gives each tappable node a DOM element that takes the
clicks itself, and lays the node's name out inside it as DOM text with its
overflow showing. A name longer than the box wraps out of it, and every line
that lands on a neighbour takes that neighbour's clicks. So a button with a
visible label is named by that label alone: don't run it together with an
icon's `semanticLabel`, and don't add a hint. The Logs view's callsign picker
and its editor's operation button are both built this way; with the arrow's
label run in, the picker's name wraps onto the table header below it and opens
on every click there.

**A covered pane leaves the semantics tree.** Painted over, a widget still
answers to its semantics, and on web its tappable nodes go on taking clicks
through whatever covers them. Home is excluded while Logs or Settings rides
over it (`HomeView`); left in, a click on any empty stretch of those panes
opens the operation card underneath.

### Links leave the app

A link the app hands off — the QRZ button, a markdown link in a call note, an
extension's notice action, an OAuth sign-in page — opens in the operator's
**own browser**, where their sessions, extensions, password manager and
history are. Never an in-app browser (an Android Custom Tab, an iOS
`SFSafariViewController`) or an embedded web view wearing the app's chrome.

Route every one through `openExternalUrl` (`app/lib/services/link_opener.dart`),
which also holds the scheme allowlist that keeps `javascript:` and `file:` out
of URLs authored by extensions and community call-notes files. It takes no
mode: there is one behaviour and no call site can opt out of it.

`url_launcher` makes the wrong thing the easy thing — `launchUrl(uri)` with no
`mode` is `platformDefault`, which IS the in-app browser on both mobile
platforms — so `app/test/guards/links_leave_the_app_test.dart` scans the source for
that omission as well as for an explicit `LaunchMode.platformDefault`.

An embedded web view is for a **pane that shows a site** (the Web Site pane,
HTML extension panels, the MapLibre map backend), never for handing the
operator off to somebody else's page.

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

**The band is permanent** wherever there is room for it — an arriving message lands in a bar the operator is already looking at, rather than pushing the whole window up by the bar's height. The one exception is a virtual keyboard, where the band is borrowed space: there it opens for a new message and slides away a few seconds later, the item itself staying in `StatusBarService` and coming back with the keyboard.

**Two kinds of thing live down there, on two surfaces.** A *message* is an event — it is the most recent thing posted, it is pushed aside by the next one, and it is dismissible; those are the `StatusBarService` items above, and tapping the bar expands them into a list. A **permanent status** is a state that is true until it is not (the internet connection; the designated radio), which no message can be: it would be pushed aside precisely when it is the answer to the question being asked. Each one holds an icon at the trailing edge of the bar, and tapping any icon opens a menu listing them all — one line each, naming the thing and its state ("Internet: connected"), and opening whatever detail it has. A menu rather than the band's own list because they are a short fixed set that reads better anchored to the icons that asked for it, and because the band is what a progress bar needs the width of. A status whose state is a *count* (the peer devices connected right now) may badge its icon with that number and nothing longer — the whole line stays in the menu — and one whose count is zero draws itself dimmed rather than disappearing, since a status that vanished would read as "this device does not do that at all".

An expanded message list is modal: it puts a barrier over the rest of the window, and a tap anywhere outside a row — including the margins either side of the writing — puts it away. The bottom chrome is drawn OUTSIDE the Navigator, so a dialog's own barrier stops at the routes; `_ChromeScrim` paints the missing half over the band, dismissing exactly as the rest of the dimmed window does.

**It rides directly above the on-screen keyboard** rather than behind it — a sync's progress or a command's output is most relevant exactly while the operator is typing, and being hidden outright at that moment is what this replaced. (What it shows there is transient; see the band's own rule above.) This is why `_StatusBarOverlay` reserves the keyboard's height for the whole app: the routes below it run full height behind the keyboard (both mobile Scaffolds set `resizeToAvoidBottomInset: false`), and the overlay holds that strip back for all of them. Reserving the keyboard inside a pane as well would hold the same strip back twice and leave its fields floating in the gap.

**A route that does not have the keyboard keeps its size.** Shrinking the Navigator shrinks every route in it, and a route behind a dialog would be laid out again the moment the dialog's field took focus — its lazy lists dropping rows, and anything with a side effect on disposal running it under the dialog (a topmost `AutofillGroup` closes the dialog's own iOS keyboard). So each route's content sits in a `HoldSizeWhileCovered` (`halo_widgets`), which while the keyboard is up lays it out at the height it had, clipped, unless the focus is inside that route on something other than a bare focus scope (its own, or one nested in it). The route with the keyboard shrinks above it; every other one — behind a dialog, a Modal Pane, or onboarding's layer over the Navigator — holds until the keyboard is down.

**The bottom safe area goes the same way.** A drawn footer spans the window below every route and paints over the home indicator, holding it with a `SafeArea` of its own — so nothing above the band may reserve that strip a second time, or a band of the view's own background opens up between its last row and the footer. The shell takes the inset out of the MediaQuery the routes and the rail see whenever the footer is drawn (`HomeRailShell.bottomInsetHeldByChrome`), which is what Quick Lookup, the rail's Settings cap, Home's action button, the logging panel and every `PaneSafeArea` consumer read it from. A pane holds the indicator itself only where no footer is drawn below it.

The app follows a selective user feedback policy:
- **Immediate interactive actions** (e.g. copying text to the clipboard) display a floating Flutter `SnackBar` toast.
- **Multi-second operations** (e.g. data file sync/refresh, patch checks) report progress and status via `StatusBarService` items in the footer — when the operator asked for them. An unattended pass (the boot sync, a reconnect resync) refreshes quietly, except a file's first download, which narrates itself even then: until it lands, its feature is missing. Completion messages auto-dismiss after a few seconds (`completedDismissDelay`); only failures persist as notices.
- **An operation the operator is standing in front of** reports its outcome on the surface that did the work, not in the footer: an export raises a dialog over the export pane naming the files and where they went. The footer is for something finishing while attention is elsewhere; a result the operator is waiting on, in a pane they opened to get it, must not be missable in a far corner of the window.
- **Logging screen / UI feedback** (e.g. activity reference validation errors or call field command outputs) use `StatusBarService` messages so toasts never obscure or interfere with the logging UI.

## Dialogs

Dialogs can have a title and subtitle pinned at the top, content in the
middle, and a set of action buttons pinned at the bottom. Clicking outside
the dialog or pressing Escape dismisses it.

Every footer is `haloDialogFooterRow` — one implementation, not a convention
each dialog follows on its own. It carries five roles; `HaloDialog` takes
all of them, while `showFormDialog`, `showFormPane` and a modal pane's
`haloDialogFooterBand` take all but `help`:

| Role | Where it sits | What it is |
| --- | --- | --- |
| `destructive` | leading edge, alone | A verb that destroys what the operator is looking at |
| `help` | leading edge, after `destructive` | Reading about the dialog — it changes nothing in it |
| `secondary` | trailing group, leftmost | Something else to **do** with the thing being edited |
| `cancel` | trailing group, next to the primary | The way out |
| `actions` | trailing edge | The primary/confirm action, normally one `FilledButton` |
| `tools` | leading edge, all the room left | Things to do with what a surface shows as a whole rather than a verb that confirms it — the Operation Postcard's Share, Copy and Save, its section picker's Reset; in place of `destructive` and `help`, a `haloDialogCancelGap` from the trailing group, which takes at most half the row |

This follows Material, which end-aligns dialog buttons with the dismissive
action immediately left of the confirming one, and gives the leading edge to
its `neutral` button — the position `destructive` and `help` take here.

**The one deliberate divergence** is the gap: `haloDialogCancelGap`
(`Space.xxl`, three times the spacing between any other pair) separates
`cancel` from the primary. A logging operator works this footer at speed, and
Cancel discards what they just typed; the gap is what stops a mis-aimed tap on
Save from landing on it. Material spaces all its dialog buttons uniformly.

`cancel` stays a slot of its own rather than being listed first in `actions`,
even though both now render in the same group: **only that slot gets the gap**,
so a Cancel passed through `actions` lands flush against Save.
`app/test/guards/dialog_footer_convention_test.dart` fails the build when one does,
and when a dialog reaches for a raw `AlertDialog` instead of `HaloDialog`.

A dialog shown through `showHaloDialog`, `showFormDialog` or a Modal Pane gets its route's `HoldSizeWhileCovered` from there, and a page route from the theme. One built by hand — a direct `showDialog` or `showGeneralDialog`, a `PageRouteBuilder`, a route subclass — wraps its own content in one; `app/test/guards/covered_route_hold_test.dart` fails the build when it does not (see the status bar's keyboard rule above for why).

### Over a map, on the web

On the web a map — or a website pane's page — is an HTML element, and the
browser hands it every pointer event over it, whatever the app paints above: a
dialog over the Map tab would otherwise let the map pan under a drag and take
the clicks meant for its buttons. Two widgets in `platform_view_shield.dart`
stand between them, and do nothing off the web:

- **`PlatformViewShield`** goes under every surface the app draws that can
  sit over a map: `HaloDialog` and the Modal Panes carry one already, as do the
  status bar's scrim and menus and the form fields' menus. The shield's element
  takes no part in Flutter's own hit testing, so what it hands to Flutter still
  reaches whatever lies there, the barrier beside a dialog's card included. A
  new menu or overlay drawn over the
  operation view needs its own. SnackBars are built with `haloSnackBar`, which
  shields the whole bar; `app/test/guards/snack_bar_shield_test.dart` fails the
  build on a bare `SnackBar`.
- **`PlatformViewCover`** goes over every platform view itself — the map, the
  website pane — and blocks it while a route covers its own and for a moment
  after. That is what reaches the framework's popups the app cannot wrap, such
  as a dropdown's menu.

### What it says

Brief and to the point. A dialog states what is about to happen and what it
costs; it does not argue for itself.

- No selling. "so a new QSO party reaches you without waiting for a new
  version of the app" is a release note, not a dialog.
- No reassurance the operator did not ask for. Say what is kept in four words,
  not in a sentence about how careful we have been.
- One fact per sentence, and only the facts that change the answer. A count,
  a duration, a requirement — not the reasoning behind them.
- Never restate the title in the body.

An operator reads a dialog to decide something. Everything that is not the
decision is in their way, and prose that justifies the decision reads as a
dialog that expects to be argued with.

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

**A settings field's editor is the one family that never says Save or
Cancel.** Every editor a settings row opens — the text/number/secret dialog,
the option picker, the bands/modes multiselect — carries `Done` in the
`cancel` slot and, where the field declares a `defaultValue`, `Defaults` in
`secondary`. A setting commits as its editor closes, by Done or by Escape or
by a tap outside, so there is no pending change for a Cancel to abandon and
nothing left for a Save to apply. One editor offering to discard would be the
only place in Settings where leaving a dialog undid what the operator just
typed. The option picker takes this footer even though every row in it is
already an action: a field's editors are read as one family, and a picker
with no buttons beside a bands editor with two reads as a dialog missing its
own.

### One way out, and it works

A surface carries **one** way out per level. A dialog that walks the operator
through steps gives each step a `Back`, and that Back **is** the way out of
it — a `cancel` beside it is a second dismiss next to the first, and in a
Modal Pane a third, next to the header's close icon. So `cancel` belongs only
where the Back beside it cannot act, and where nothing else can either: the
first level, which has no Back; and, on a surface with no chrome of its own,
a request in flight, which disables it. A Modal Pane needs no second case —
its header icon covers that state.

Two buttons spelled the same way, going to different places, is the failure
this prevents. **It counts in time as well as space**: one button whose
destination changes with the surface's state is the same trap, harder to see.
And it counts against the **chrome**, not just the footer — a Modal Pane's
full-screen presentation leads with a `BackButton`, whose accessible name is
"Back", so a stepped pane on a phone can pair that with a footer "Back" going
somewhere else. Known, unresolved, and worst for a screen reader.

Which leaves the header icon carrying real weight, so **it has to work**. A
`PopScope` that guards something in flight must intercept the gesture, not
refuse it: Escape and that icon both route through `Navigator.maybePop()`, and
a `canPop: false` with no `onPopInvokedWithResult` turns both into controls
that visibly do nothing. Honour the dismissal and abandon what was pending.
Two things that guard has to get right, and both are easy to miss: the flag
it reads must be true for the **whole** window it claims to cover —
a request is in flight before there is anything polling for it — and a
`PopScope` only does anything at all with a `ModalRoute` above it, so a
surface mounted over the Navigator (an overlay) is not protected by one and
must carry its way out in the footer.

Guarding the **barrier** is separate and is a different judgement: a stray tap
outside is not a decision the way Escape is, so a pane whose work is expensive
to redo opens with `barrierDismissible: false` — which nulls the barrier's own
tap handler and has nothing to do with `canPop`.

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
opens the dialog there (halo_app.dart's `_handleKeyEvent` and AppDelegate.swift's
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
re-filters a list of forms while the operator is still typing the query — the
Settings panel's search is the one that exists today — must keep the excluded
sections in the tree (`Visibility`/`SliverVisibility` with
`maintainState: true`, plus `ExcludeFocus` so a hidden field stays out of the
Tab order). Dropping a section instead
disposes every `FocusNode` and `TextEditingController` its `FormRenderer`
owns, and **on web that teardown takes the browser's text-input element with
it**: focus falls back to the route's scope and the next keystrokes are
swallowed, so the query loses characters as it is typed. There is no symptom
on macOS, which has no DOM — and none in a widget test either, because
`flutter test --platform chrome` drives text input through the test binding
rather than a DOM element, so no browser focus event ever fires. Test the
invariant (the sections are still mounted) rather than the symptom.

### Settings lists

A settings **list** is any surface whose content is settings rows: the
Settings panels, a target-scoped settings dialog (the logging pane's tune
icon), a pane's layout options, a panel's own configuration, the spot
filters, the operation's location screen. Whatever builds one — a declared
`SettingsGroup` through `FormRenderer`, an extension's `settingsPanel`, or a
hand-built panel like Sync or Station — it is the same list to the operator,
and these rules are what keep it one:

- **Rows span the surface; their CONTENTS are inset.** The reading width
  comes from padding inside each row, never from capping the column, so row
  backgrounds and section bands reach the edges instead of floating in a
  gutter on a wide window. The inset rides the ambient `ListTileTheme`, which
  `SettingsList` publishes (`settingsRowInset`, plus a pane's own centring
  offset) and which `ListTile` rows and `FormRenderer`'s `_rowContentPadding`
  both read — one number, which a pane's title lines up with too. A surface
  that builds something that is not a row (a search field, a status line)
  takes the same inset from that theme rather than restating it, and a
  DIALOG carrying a list says `list: true` rather than spending horizontal
  padding of its own.
- **The SURFACE decides the row shape, not the element.** `FormRenderer`
  renders a settings list's fields as settings rows — bold title, the
  description underneath, the whole row working the toggle, a tap opening the
  editor for anything that is not one — and a form's fields as controls to
  type into (`settingsList:`). A field whose element declares no `icon` is
  still a settings row on a settings list, with nothing in the leading slot.
  Decided per element, the shape becomes an accident of whoever wrote the
  declaration.
- **A section is headed by `SectionHeader`**: the accent title in the slab
  face, a step above the row face, over a hairline rule in that same accent,
  on no ground of its own. Title and rule both keep the row inset, lining up
  with the rows they head — the slab face and the rule are what set the
  heading apart — and the rule measures the content rather than running
  full-bleed the way a filled band does. `FormRenderer`'s
  `style: 'section'` header IS that widget, and it is the only section header
  in the app. It abuts its rows on both sides — the gap belongs above a
  section, not between a heading and what it names. Pinned it paints the
  pane's surface behind itself, since its own rows scroll under it; only a
  surface-grounded list may pin one.
- **Bands stick.** A section is a `SliverMainAxisGroup` of [band, rows]
  (`SectionHeader.section`), so the band holds the top while its own rows
  scroll under it and is pushed off by the next section's. That makes the
  surface a `CustomScrollView`, and every piece of it a sliver: a box handed
  to a viewport fails the whole list, not just the section that returned it.
  A list assembled as a flat row list, bands among them, says
  `SectionedListView` and is cut into those groups for it;
  `FormRenderer(sliver: true)` does the same for a declared form. That cut
  reads BOTH heading levels: a `CategoryBand` among the rows opens a category
  and the `SectionHeader`s after it are gathered into it, so their bands pin
  UNDER the category's rather than pushing it off — the two-deep stack the
  Settings panel gets from its accordion, for a surface whose categories do
  not fold (the Station panel's Current Transceiver, Equipment Inventory
  and CAT Control Preferences). The band is
  a `PinnedHeaderSliver`, so it is as tall as it lays out to — a title that
  wraps at a large font scale takes the room it needs rather than a stated
  extent's guess — and nested bands STACK: a section band pins under whatever
  pinned band the group above it holds.
- **A CATEGORY is not a section.** The FILLED band is the shelf; the unfilled
  heading names a group of rows already on one. A surface whose groups are its
  own top level takes the filled band with no chevron and nothing to collapse
  — `CategoryBand`, which a declared form asks for with
  `style: 'category'` (the station equipment editor's Current State and
  Wiring). It takes an optional `trailing` control that belongs to the whole
  category — the Station panel's Add Equipment button — because a control over
  a category has nowhere else to sit: as the last ROW of a long list it is the
  one thing an operator has to scroll to find. Its ground runs to the surface's edges and only its title takes the
  row inset, so a host that pads its content horizontally has to spend that
  padding on its rows instead — `showFormPane` does, through the row theme —
  or the band floats in a gutter and reads as one highlighted row.
- **The Application Preferences panel is an accordion of categories** — Common Preferences,
  then one per declared group and extension
  panel, one open at a time and remembered across visits. A category heads
  itself with that filled band and a chevron on its left; a section inside one (a panel's
  own `style: 'section'` header, e.g. Callsign Notes' "Built-in Notes") is
  the unfilled heading above. The ground is what says which contains the
  other, so neither borrows the other's look. The category band pins too, and
  the section bands inside it stack under it — two bands deep while the rows
  of an open category scroll past, which is what keeps "where am I" answerable
  in a list whose rows all look alike. Opening a category brings it to the top
  of the pane, a frame after its own animation: the pane can only scroll as
  far as its content, and the room to scroll into is what that animation is
  still making. The body is slivers, so the accordion's open-and-shut is
  `CollapsingSliver` rather than `AnimatedCrossFade` — same wipe, a sliver
  subtree instead of a box. Every category is built up
  front, never lazily: one a lazy list scrolls out of view is DISPOSED, and
  disposing a form takes the focus of whatever is being typed in with it —
  the live-filter rule above, which the panel's search depends on. A shut
  category is mounted but paints nothing, which is what makes it "offstage" to
  a widget test's default finder. Inside Common Preferences the
  contributing groups head their own rows with the unfilled section heading,
  so a row drawn from a dozen groups still says where it belongs. A search
  opens every category that still matches (Common Preferences excepted — its
  rows are copies of the ones below, and it would answer every query twice),
  and clearing the query returns to the one remembered category.

## Row gestures

A list row may be **slid** horizontally to reveal one action per side. The
spots list is the only one that does today; anything that adopts it matches
this shape rather than inventing a second dialect.

The gesture has **two thresholds**, and the hand must be able to tell them
apart without looking:

- **The peek**, half an action well's width. Past it the row rests open on
  release with the action's icon exposed to tap, and any *preparatory* effect
  happens now — the spots list makes the row's station the suggested QSO here.
  A `HapticFeedback.mediumImpact` marks it. Nothing preparatory may fire before
  this point: on the first pixel of travel, a twitch during a scroll would
  retune the radio. Up to the commit the icon centres in whatever width is
  revealed, so it arrives with the well and rests centred in it.
- **The commit**, two fifths of the ROW's width. Releasing past it performs the
  action outright, without the icon ever being pressed. A heavier
  `HapticFeedback.heavyImpact` marks it, in **both** directions — reversing
  back under the threshold is a promise that release will no longer act, and
  it deserves the same weight that promised it would. Crossing it also slides
  the icon across its well to sit against the row it will act on, which is the
  visible half of the same statement.

Both are impacts rather than selection ticks: the gesture is made without
looking, and feedback the hand can miss is feedback the gesture does not have.

An action that has two senses shows **the one that reverses what the row
currently says**, so the gesture never depends on remembering how the row got
that way. In the spots list the trailing action is backspace on a live spot and
undo on a greyed-out one — including one greyed by scoring rather than by an
earlier slide, which the operator can put back on the board. Only the grey
moves: the strikethrough says the call is already in the log, so no slide in
either direction adds or removes it, and a restored duplicate comes back at
full contrast still struck. Nothing here edits the log.

Actions are **icons alone**, with the word carried as a `Semantics` label —
there are no tooltips in this app. Only **one row is open at a time**, and
scrolling closes whatever was open: a row left open under a thumb that has
moved on is an armed action over whatever has since scrolled into its place.

A row asked to close while a finger is still on it **refuses** — zeroing its
displacement mid-gesture restarts the drag from nothing under a finger that
never lifted. So whatever tracks open rows must keep tracking a refuser rather
than forget it to make room for the next one. A forgotten row is open with
nothing able to close it, and every later slide leaves another beside it: the
list fills with open rows and none of them answer to anything. This is the
ordinary path, not a corner — crossing the peek suggests the QSO, which arms
the list's own reveal scroll, which asks every open row to close mid-drag.

**What a peek fills belongs to the open row, not to the operator.** The
preparatory effect lasts exactly as long as the row stays open: dragging back,
setting the spot aside with the other action, opening another row and scrolling
the list all take it back again, and the fields return to empty. The moment the
operator types over the fill it becomes theirs, and closing the row no longer
touches it.

A row can also be **discarded** while open, without ever closing — a list that
keys its rows on the spot's own timestamp rebuilds one the moment it is
re-spotted — so the row's `dispose` has to take the fill back too, not just its
close.

**An open row is a question, and answering it anywhere closes it.** Tapping any
spot closes whatever row is open — a tap chooses a station outright, which is
an answer — and so does the operator going to the logging panel and typing in
(or wiping) the call field. Leaving the row armed behind either one leaves a
gesture pointing at a station they have already moved past. The close runs
before the tap's own suggestion, so the closing row's withdrawal cannot take
the newly chosen station straight back out.

**Choosing a station is not composing an entry.** A callsign a suggestion put
in the fields — slid or tapped — is never the work in progress that the next
suggestion has to ask about; only something the operator typed is. So one spot
replaces another silently however either was chosen, and the log request that
ends a slide never asks permission to overwrite what that same slide filled in
a moment earlier. Whose the entry is, is decided by comparing the field to what
was put there, NOT by a flag set from the field's change listener: that listener
fires for every programmatic rewrite as well as for typing, and one spurious
fire turns a suggestion nobody composed into work — after which every spot is
refused, in silence.

**A slide may not destroy work the operator cannot see.** The panel a slide
acts on is not the one being looked at, so anything the action would overwrite
— an edit in progress, a station part-typed into the call field — earns a
prompt offering to go back to it or to clear it and proceed, and "go back"
surfaces the panel so the operator lands on what they kept. Work here means a
**station**: a frequency, a reference or a stray field with no callsign
attached is scaffolding the incoming spot replaces anyway, and prompting over
it would train the operator to dismiss the prompt.

The prompt comes at the **peek**, not at the commit — the point of filling the
fields early is that what the gesture would do is on screen before it happens,
and a slide that silently fills nothing has already failed at that. But it
waits for the gesture to be over: the peek fires mid-drag, and a dialog raised
under a moving finger takes the pointer while the drag runs on underneath it,
so the release still commits. The suggestion is HELD instead, and put to the
operator when the row comes to rest open. Declining keeps their work and ends
the gesture; carrying the same slide through to a commit asks once more, since
the commit destroys what the peek only offered to — and the commit's answer
ENDS the peek's question, both halves being one gesture. A held question that
outlives its gesture comes back on the next row the operator slides, offering
to overwrite a panel that no longer holds anything.

Both halves of what a held question assumed are re-read when it is finally
asked, never trusted from when it was held: a conflict the operator has since
cleared themselves is not worth a prompt (the suggestion simply applies), and a
suggestion whose row has closed or been discarded while the dialog was up is
dropped — applying it then would fill the fields and retune the radio for a row
that is gone, after the withdrawal that could have undone it has already run.

**A contact logged by the gesture alone leaves the focus where it is.** Logging
normally ends by focusing the call field, ready for the next contact. A slide
is made from the list, where that focus is an on-screen keyboard thrown up over
the thing being worked — and that goes for every way the route can end: the
wipe after a successful log, the wipe that clears the way at the prompt, and
the refusal to log at all, which reaches for the field to point at what needs
fixing.

**A slide never navigates.** The operator sliding a row is working the list
they are looking at, and surfacing another pane — which a *tap* on the same
row legitimately does — takes it out from under them mid-gesture. On a narrow
window that is the whole difference between the two interactions.

Two structural constraints, both of which draw blood when ignored:

- **The gesture must live above any key that changes.** A row whose widget key
  changes has its subtree discarded, and a discarded subtree takes the drag's
  `State` and its live recogniser with it — the row snaps shut mid-slide. In
  the spots list the tile takes a `GlobalKey` on becoming the current QSO,
  which is a thing sliding it *causes*, so the slide wraps the tile rather
  than living inside it.
- **Sliding may not change a row's height.** Where a list declares row heights
  for scroll arithmetic it cannot measure (`spotRowHeightFor`), the action
  layer is `Positioned.fill` and the content moves by a `Transform`, so
  neither contributes layout. The divider stays outside the slide: the ruling
  between rows does not move with the row.

## Number Formatting

All numbers displayed in the user interface (including QSO counts, QSO row index numbers, scoring summaries, statistics tallies, and general quantities) must be formatted with thousands separators to enhance readability.
- In the Dart/Flutter core, use the `formatNumber` utility function exported by `halo_widgets`.
- In JS/TS extensions, use the `fmtInteger` (or `fmtNumber`) utility function from `@ham2k/lib-format-tools` when generating user-facing counts.

### Which characters, and who decides

Settings → General → **Number Formatting** picks the decimal and thousands
separators: the device's own conventions (the default), always a period, or
always a comma. The two are ONE choice — `14,285.5` or `14.285,5`, never a
mixture — so they are resolved together and read together.

The resolved pair lives in `NumberFormatting` (halo_core), a process-wide
singleton on the `AppClock` pattern and for the same reason: a number
FORMATTED with one separator and PARSED with another does not round-trip, and
the field that shows a frequency is the field the operator edits. `HaLoServices`
resolves the preference and pushes the answer in — halo_core is pure Dart, with
neither the device locale nor ICU.

Every user-facing surface reads from there, and there is no second source:
`fmtFreq`/`fmtFreqInput`/`parseFreq`, `formatNumber`, FormRenderer's `number`
fields (display, parse, and the input formatter — a fixed `[0-9.-]` silently
swallows the decimal key on a comma-conventions keyboard), the QSO row's
frequency, and the logging panel's numbers-row extra key, which types whatever
`parseFreq` will read back as a decimal point.

Frequencies read as **kHz** everywhere they are shown — the QSO list, the
spots panel and the radio controls alike — so `7200.5` kHz is `7,200.5`, and a
whole 7.2 MHz is `7,200`. The QSO row splits that into MHz/kHz/Hz parts for
styling and for column alignment across an operation, but the marks between
them are an ordinary thousands separator and an ordinary decimal point, not a
notation of their own.

**Machine-facing output is never localized.** ADIF, spots, sync payloads and
every other wire format carry a plain period-decimal number whatever the
operator sees. Extensions receive the resolved pair as
`ctx.decimalSeparator`/`ctx.groupingSeparator` for parsing typed input and
formatting text shown back — not for anything they transmit.

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
