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
QSOs. They have three parts: the main logging controls, the information
area, and the secondary logging controls.

**Main controls.** Always start with the callsign input (also used for
commands), followed by the exchange inputs (unless disabled), then controls
defined by active extensions and operation references, and finally
user-enabled ones like state or grid. This list is deliberately short,
focused on information exchanged over the air on every contact; most other
details belong in the secondary controls.

Pressing Tab or Space rotates focus between main controls. If an input
allows spaces, one press enters a space; two presses in a row delete that
space and move focus to the next control.

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

### Header

Windows (or screens on mobile) have a header with a title and optional
subtitle, a logo or back arrow on the left, and one or more buttons on the
right. When the window is wide enough for split views, the title and
subtitle are left-aligned; on narrow windows they are centered.

### Footer

A footer at the bottom of the window can show a progress bar for sync
activity and other status information. On mobile devices it hides while the
keyboard is open. It includes padding so rounded screen corners don't cover
it.

## Dialogs

Dialogs can have a title and subtitle pinned at the top, content in the
middle, and a set of action buttons pinned at the bottom. Clicking outside
the dialog or pressing Escape dismisses it.

A Cancel/Close button is always the leading, left-aligned button, separate
from the primary/confirm action(s) grouped at the trailing edge — not merely
listed first among right-packed buttons (`HaloDialog`'s `cancel` parameter).

Pane-sized dialogs — "Modal Panes" — additionally present as full screens on
phone-sized windows; see [layouts.md](layouts.md).

## Forms

Forms use a clear, consistent layout, with labels and fields aligned
properly. When a form renders in a view instead of a dialog, its actions are
pinned at the bottom, same as in a dialog.

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
