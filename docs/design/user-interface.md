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
specified in [layouts.md](layouts.md).

### Buttons and hover labels

**No tooltips.** Icon-only buttons do not get a hover label — never pass
`tooltip:` to an `IconButton` (or wrap a control in a `Tooltip`). A label that
pops up over whatever is under the pointer is noise on desktop, and on touch
it is unreachable anyway; an icon that needs a hover label to be understood
needs a better icon, or a visible text label.

Icons still need an accessible name for screen readers. Put it on the icon
itself — `Icon(Icons.close, semanticLabel: t.common.close)` — which names the
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

### Header

Windows (or screens on mobile) have a header with a title and optional
subtitle, a logo or back arrow on the left, and one or more buttons on the
right. When the window is wide enough for split views, the title and
subtitle are left-aligned; on narrow windows they are centered.

### Footer & User Feedback

A footer at the bottom of the window can show progress bars and status messages (`StatusBarService`). On mobile devices it hides while the keyboard is open. It includes padding so rounded screen corners don't cover it.

The app follows a selective user feedback policy:
- **Immediate interactive actions** (e.g. copying text to the clipboard) display a floating Flutter `SnackBar` toast.
- **Multi-second operations** (e.g. data file sync/refresh, patch checks, export generation) report progress and status via `StatusBarService` items in the footer.
- **Logging screen / UI feedback** (e.g. activity reference validation errors or call field command outputs) use `StatusBarService` messages so toasts never obscure or interfere with the logging UI.

## Dialogs

Dialogs can have a title and subtitle pinned at the top, content in the
middle, and a set of action buttons pinned at the bottom. Clicking outside
the dialog or pressing Escape dismisses it.

A Cancel/Close button is always the leading, left-aligned button, separate
from the primary/confirm action(s) grouped at the trailing edge — not merely
listed first among right-packed buttons (`HaloDialog`'s `cancel` parameter).

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
  running it is usually what Enter should do.
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

The typing behavior — debounced interpretation, the space rules for commands
mid-parameter, execution — is **not** the dialog's own: it lives in
`CommandEngine`, shared with the Home view's Quick Lookup bar so the two
can't drift apart. The dialog runs commands against the front-most Operation
View's operation via `HaLoServices.currentOperationContext`.

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
