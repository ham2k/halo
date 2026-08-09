# Layouts (Shirt Sizes, Panes, and Modal Panes)

Every root view — Home, Operation, Settings — is a composition of **panes**,
and the arrangement of those panes is a pure function of the window's
**shirt size**. A window resized across a size boundary re-arranges live,
with animation; nothing is rebuilt from scratch, no navigation happens.

This document defines the size system, the reusable primitives, and the
rules that keep layouts consistent. **Read this before adding a breakpoint,
a side-by-side split, or a dialog-like surface.**

---

## The one idea

**There is one width vocabulary for the whole app: four shirt sizes and one
ideal pane width.** No view invents its own numbers. Height has its own,
separate vocabulary — five density rungs, below.

| Size | Logical width | Typical device |
|---|---|---|
| **XS** | below 360 | small phones |
| **S** | 360 – 719 | typical phones (360–430) |
| **L** | 720 – 1199 | tablets, small desktop windows |
| **XL** | 1200 and up | large windows, full screens |

There is deliberately **no M**. Between S and L lies the **ideal pane width**
(`idealPaneWidth = 500`) — the width most panes are *designed* for. A window
around that width simply shows one pane at its best size; it isn't a distinct
layout mode. When a view goes two-pane at L and the user has never dragged
that divider, the primary pane defaults to about two thirds of the available
width, capped at the S boundary (`ShirtSize.sMax`) — content designed for a
pane reads fine up to the widest single-pane phone layout, and beyond that
the extra width serves the secondary pane better.

All values live in
[`packages/halo_widgets/lib/src/layout.dart`](../../packages/halo_widgets/lib/src/layout.dart):
`ShirtSize` (with `ShirtSize.of(context)`), `idealPaneWidth`, `minPaneWidth`,
and the standard layout animation (`layoutAnimationDuration`,
`layoutAnimationCurve`).

Widths are **plain logical pixels** in the UiScale-divided space
([ui-scaling.md](ui-scaling.md)). `ShirtSize.of` reads
`MediaQuery.sizeOf(context).width`, so a larger font scale narrows the
effective width and collapses layouts sooner — by design, and it means a
font-scale change can flip a view's shirt size while it is on screen.

XL currently behaves exactly like L everywhere. The value exists so views
can diverge later (third columns, wider gutters) without another migration.

Resizable windows have a floor: `minWindowSize` (320×480, an XS phone's
footprint), enforced natively via `WindowChromeService.reportMinimumSize`
(macOS today) and multiplied by the UI scale so the floor holds in the
divided space. Fixed device screens may be smaller than this — layouts must
still tolerate them; users just can't *drag* a window below it.

---

## Root view layouts

| View | XS / S | L / XL |
|---|---|---|
| **Home** | Operation list with Quick Lookup below, full width | List + Quick Lookup in a left column (~2/3 width, resizable); right column shows branding (logo, name, version) on a tinted background |
| **Operation** | Four tabs: QSOs, Spots, Map, Operation | Logging pane on the left (~2/3 width, resizable); right side tabs: Info, Spots, Map, Operation |
| **Settings** | Settings list; each panel pushes a full screen | Settings list stays as a left column (resizable); selected panel on the right |

Mode switches are **hard cuts within a single build** — a view's `build`
switches on `ShirtSize.of(context)` and returns one arrangement or the
other. Width changes *within* a mode animate (300ms, ease-in-out, via
`ResizableSplitView`).

## View classification: fixed vs. layout-customizable

Every root view is classified by `ViewLayoutPolicy`
([`layout.dart`](../../packages/halo_widgets/lib/src/layout.dart)), declared
as a `layoutPolicy` const on the view class:

- **`customizable`** — the view's panes are user-arrangeable via the dock
  layout (`DockLayoutView`), behind the operator's own **Enable Layout
  Customization** setting (Settings → User Interface), off by default: a
  fixed arrangement is the one an operator can be talked through over the
  air, so rearranging is opted into. The **LAYOUTS** command (LYT or LAYOUT
  too) toggles it from the command bar — `SET LAYOUT` reaches the same
  setting, but the word an operator is told over the air is this one. Currently only the **Operation** view.
  The **`panels` experiment** is a separate switch and stays one: it gates
  the dashboard PANEL extensions (weather, solar, custom text), which
  declare it in their manifests, and nothing else. It answers to `PANELS` and `PANEL` and
  nothing else: it is what the `layouts` experiment became once the dock
  stopped being a tester's feature, and every dock word now belongs to the
  setting's own command. State does not follow a key change either. Rearranging what already
  ships needs only the setting; the experiment is what adds more to arrange.
  The setting does not read the experiment either — two features behind one
  switch is what splitting them was for.
  A dragged tab can land on another group's
  **tab strip** (joining that group at the position aimed at, which is also
  how tabs reorder), on one of the **four split bands** over a group's body,
  or on a **dock edge** strip. The bands are thirds running the full length
  of the body and so overlap at the corners: a corner entered from outside
  resolves to the horizontal band, and a band already highlighted keeps the
  pointer as it slides into an overlap, so the highlight doesn't flicker
  while the operator is still moving. The middle square belongs to no band
  and a drop there does nothing. A dropped pane takes **the band's own
  third** — it arrives at the size the operator was looking at — and grows
  into it over `layoutAnimationDuration`, floored at a group's chrome height
  so a pane is never laid out shorter than its own tab strip.

  All of a customizable view's dividers — the fixed split's and the dock's —
  use the **solid** style below.
- **`fixed`** — the arrangement never changes (Home, Settings). Fixed
  views may opt their splits into the **surfaces** divider style.

## Resizable splits

Side-by-side panes are composed with
[`ResizableSplitView`](../../packages/halo_widgets/lib/src/resizable_split_view.dart):
a primary pane with a preferred width and an expanding secondary pane,
separated by one of two divider styles (`SplitDividerStyle`):

**Solid (the default).** A header-colored bar
([`SolidPaneDivider`](../../packages/halo_widgets/lib/src/pane_divider.dart),
`paneDividerWidth()` wide) that owns its own layout space — no overlay, no
drop shadow. It reads as chrome between panes, matching the app bar's
surface, and it is the shared divider language of layout-customizable
views: the dock layout's split dividers are the same widget, so the fixed
split and the dock can't drift apart visually. Being an opaque painted
bar, it needs no special handling over native platform views.

Its thickness varies on two axes. The mobile **platforms**
(`isMobilePlatform` — iOS or Android, not web, the same gate `LayoutDensity`
uses for its touch minimum) get a few pixels more than a pointer everywhere,
7 → 9; a touch tablet on the web build reads as a pointer. And while a layout
is being **edited** the bar fattens further, 11 on desktop and 16 on mobile,
because there a divider drag competes with pane drags for the same pointer
and has to read as a grab target rather than as furniture.

The editing width is granted unconditionally — the panes give it up, and
nothing rations it against what they can spare. **Edit mode is not
overflow-safe in a very short dock, and the divider is the smaller half of
why.** A group is a Column of its tab strip over an Expanded body, so a pane
shorter than its own strip overflows; entering edit mode also gives every
headerless group a strip it did not have, a whole chrome height that no
divider width can give back. A guard on the bar alone would buy a guarantee
that still does not hold, so the bar stays simple and the real fix belongs
where the chrome is added.

**Surfaces (opt-in — Home and Settings today).** The divider consumes no
layout space — it is a transparent drag overlay (with grab dots) on the
secondary's leftmost pixels, so the secondary's own background and content
stretch to the very boundary, and the separation is drawn by the shadow
the divider casts rightward onto the secondary pane (a white glow in dark
mode, where a black shadow would vanish into dark surfaces). The strip
deliberately blocks clicks, hover, and scrolling (it exists only to
resize). Over native platform views (the map) the strip stays
near-invisibly painted so its events route through Flutter — that wash is
load-bearing, see `ResizableSplitView._platformViewHitWashAlpha`.

**PaneSafeArea holds in both styles, and also carries real device insets
(ham2k/halo-dist#205).** Content that needs interactivity near the
divider edge reads `PaneSafeArea.leftOf(context)` and insets itself — rows
and backgrounds still render edge-to-edge, only their content shifts.
Surfaces advises the grab-strip width; solid advises 0 (nothing overlays
the pane) on that axis. Independently, each root view (`OperationView`,
`Home`) wraps its `Scaffold.body` in `PaneSafeArea.root`, which reads the
device's real safe-area insets (notch, home indicator, camera cutout) from
`MediaQuery`; `ResizableSplitView` and `DockLayoutView` both forward that
ambient value through their own `PaneSafeArea` insertion points, netting
it against each pane's position — only the pane whose edge is actually AT
a physical screen edge inherits that edge's inset; an interior pane (in a
multi-way dock split) reads 0 there. `top`/`bottom`/`left`/`right` all
compose this way. Do not remove a `PaneSafeArea` just because its value is
currently zero for a given pane/edge.

When `secondary` is null
the primary fills the window — pass null on XS/S rather than swapping
widget trees, so the primary subtree stays mounted (scroll positions and
in-progress input survive the flip).

The user's dragged width is a **preference, persisted per divider** through
`SettingsService.layoutDimension` / `setLayoutDimension`
([`app/lib/services/settings_service.dart`](../../app/lib/services/settings_service.dart)),
stored as dotted keys under the `layout` setting:

- `home.leftColumn`
- `operation.leftColumn`
- `settings.leftColumn`

The split clamps the preference to what fits **at layout time only** — a
temporarily small window never overwrites the stored value. The persistence
callback fires on drag end, not on every drag frame.

## Layout density: the height vocabulary

`ShirtSize` classifies a window's **width** to choose a pane arrangement.
`LayoutDensity` ([`density.dart`](../../packages/halo_widgets/lib/src/density.dart))
classifies its **height** to choose how much room the app's fixed furniture
spends. They share the idiom and nothing else — the rungs don't correspond,
and neither derives from the other.

Five rungs, and `normal` is what the app looked like before densities existed:

| Rung | Auto picks it below | QSO row | Chrome row | Field padding |
|---|---|---|---|---|
| `densest` | 450 | 23 | 42 | 3 / 4 |
| `dense` | 650 | 25 | 44 | 4 / 5 |
| **`normal`** | 1000 | **29** | **48** | **6 / 8** |
| `sparse` | 1400 | 35 | 54 | 9 / 11 |
| `sparsest` | — | 41 | 60 | 12 / 14 |

Heights are read from `LayoutMetrics`, which holds the **named dimensions a
height budget is actually made of** — row heights, section headers, chip strip
gaps, status bar rows, field padding. The `Space` rungs
([user-interface.md § Spacing](user-interface.md#spacing)) are compile-time
constants and deliberately do **not** vary: 92% of their uses sit inside
`const` expressions, and they account for about an eighth of the logging
panel's height. The named dimensions are the rest.

The ladder reads the **UiScale-divided** height ([ui-scaling.md](ui-scaling.md)
rule 4), so a larger font scale genuinely fits less and reaches a tighter
layout sooner — the same bargain `ShirtSize` makes on width.

### The operator's setting

`DensityPreference` is `Auto / Densest / Dense / Normal / Sparse / Sparsest`,
`auto` by default, stored by `SettingsService.densityPreference` and offered in
Settings → User Interface. `⌘⇧-` / `⌘⇧=` step it and `⌘⇧0` returns to Auto —
Font Scale's own keys, one modifier up, because the two answer the same
question. Stepping starts from the density **in effect**, not the stored value,
so the first press off Auto always moves exactly one visible rung.

An explicit pick is honoured, with one exception: **on a window short enough
to sit below the `normal` band, the layout has to fit and that wins.** A denser
pick is always honoured, since it can only help. The band thresholds decide
what *Auto* picks; they are not a gate on an explicit one — conflating those
two once made every roomier rung a silent no-op below 1000pt.

### Rules

**1. A declared height must equal what the widget paints.** The QSO list's
pinned day header trips Flutter's `layoutExtent exceeds paintExtent` assertion
on the difference, and `_estimatedTopOf` walks the log summing row heights
**without measuring** — a row outside the viewport isn't built, or carries a
stale paint transform. A row that paints taller than it declares scrolls to
the wrong place with nothing to catch it. `qso_list_test` measures the painted
pitch at every rung.

**2. A measurement that mirrors a gap names the metric, never the number.**
Same rule the `Space` rungs carry, and it bites harder here because these
values move at runtime.

**3. Values stay whole logical pixels, and every metric increases strictly
across all five rungs.** A tie makes one rung indistinguishable on screen —
the shortcut moves and nothing visibly happens. Both are enforced in
`density_test.dart`, as is the requirement that every metric has a reader:
a metric nothing honours reads as wired when it is not.

**4. Chrome rows share ONE metric and never shrink below a finger.** The app
header, every tab strip, the wide split's pane title bar and a dock group's
header stack and abut, so they move together or read as a mistake. Read them
through `LayoutDensity.chromeHeightOf`, which holds the value to
`kMinInteractiveDimension` on the mobile **platforms** — a landscape phone
lands in `densest`, which is exactly when the tab strip is the primary
navigation and a thumb still has to hit it.

The floor is gated on `isMobilePlatform` (iOS or Android, not web), not on
whether the pointer is actually coarse: a touch device running the web build
is deliberately outside it, because widening the gate to every coarse pointer
also catches touchscreen laptops, which are overwhelmingly trackpad-driven.

A control INSIDE a chrome row gets that whole height only if nothing insets
it. A `BoxDecoration` border does — which is why a tab's selection indicator
is a `foregroundDecoration`, painted over an already-laid-out child. Sizing a
strip to a tap target means nothing if its own button renders shorter than the
strip.

**5. A pane may tighten the density, never loosen it.** The root scope reads
the window; a vertical dock split and a Modal Pane are genuinely shorter than
the window and publish their own via `LayoutDensityScope.forHeight`. A pane
cannot buy back room the window does not have.

**6. Anything that is a colour boundary still goes through `PixelGrid` — and
the density-resolved value is what gets snapped.** Snapping a base constant
and substituting a shorter one downstream puts the hairline seam straight back
at every non-1.0 font scale.

### What density deliberately does not touch

Text sizes (HALO-76 names font-size changes a last resort, and nothing has
needed one), the `Space` rungs, the logging row's **horizontal** concession
ladder ([logging-fields.md](logging-fields.md) — it must not gain a second
competing squeeze), and the numbers row's key height, which is already at
Apple's 44pt tap-target minimum.

## The panels a view can hold

A layout-customizable view arranges **panels**, and the list of panels is a
registry — `PanelService` (`app/lib/services/panel_service.dart`) — not a
constant in the view. Two sources write into it:

- **Native panels.** The view registers its own (Operation: QSOs, Info,
  Spots, Map, Clock, Weather, Web Site) with their title, description, icon
  and, where they have
  any, the settings *target* whose declared settings make up their settings
  dialog. The service holds identity only: the widget stays with the view
  that builds it, which is what lets the Add a Panel sheet list a panel it
  has no way to build.

  A native panel may also carry `formFields` — the same declarative schema an
  extension panel's `form` uses, rendered by the same `FormRenderer` and
  persisted to the same Dart-owned storage, with no extension and no bridge
  call anywhere in it. Clock is the first, and it is also the first native
  panel to set `multiple`: an operator places one per zone, so its ids are
  `clock#1`, `clock#2`, and its config is stored per placement.

  **Clock is native rather than an extension because the extension runtime
  cannot do either half of it.** QuickJS-NG ships no ECMA-402, so `Intl` is
  undefined and `toLocaleString(…, {timeZone})` *silently* returns host-local
  time instead of throwing — real zones are unreachable there, and wrong in a
  way that is invisible on the developer's own machine. And a panel
  contributes a document, not widgets: an SVG is compiled to a static
  instruction list (`<animate>` and `<style>` are dropped outright) and the
  panel tick floors at five seconds, so nothing an extension can return
  sweeps a second hand.

  **Weather is native for the second of those two reasons.** Its eight-hour
  temperature curve is fitted to whatever was fetched, and a hook that
  contributes a document has no way to hand back a shape — as a `panel` hook
  it can only be a table of numbers. Its fetch, cache and refresh are
  ordinary Dart besides: no bridge call per render, and no five-second floor.
- **Extension panels.** Every `panel` hook contributes its own
  ([hooks.md](../extensions/hooks.md)). An extension panel is a *document* —
  markdown, SVG, or sandboxed HTML — rendered by `PanelContentView`, never
  widgets, the same UI-catalog seam every other declarative hook sits behind.
  Its id is `ext:<hookKey>:<panelKey>`, and that id is what a saved layout
  stores.

A panel's id disappearing from the catalog — an extension disabled or
uninstalled — **never costs the operator their arrangement**. The pane stays
and renders a placeholder (`MissingPanelPane`: a `toy-brick-remove` glyph and
*Extension "X" is missing*), it can be dragged to the delete target like any
other pane so removal stays the operator's call, and one that was only
briefly missing repairs
itself when its extension answers. Nothing reconciles, and nothing is set aside.

That rule exists because setting an arrangement aside is as destructive as
deleting from it — the next thing written replaces it — and an extension can
be absent for reasons as mundane as a `panel` hook that timed out once. The
catalog is read during **startup**, before the first view builds, so the
ordinary case never shows a placeholder at all; the placeholder is for a
panel that is genuinely gone.

**A panel may be placeable more than once.** A descriptor sets
`multiple: true` and each placement gets an id of the form
`ext:<hook>:<key>#<n>`; everything else keeps one pane per panel. Because
panel config is stored under the panel id, each instance's values persist
separately with no storage code of their own — the property that makes the
whole feature cheap. `#` is safe as the separator (neither key may contain
one), so an arrangement saved before instances existed parses as its own
descriptor and keeps working.

Three consequences worth knowing. The Add a Panel sheet keeps an instanceable
panel listed once placed, because that row is the only "add another" control
there is. A render result may carry a **`title`** that replaces the
tab label — without it, three placements of one panel all read the same
thing, and the operator's own heading beats an ordinal. And **removing an
instance forgets its config**, because an instance id is an anonymous slot
that the next placement reuses; a panel placed once is deliberately not
forgotten, since its settings belong to the panel rather than to that pane.

**A panel's own settings and a pane's layout options are different
questions, and they live in different places.** A panel's settings are a
control on its TAB, present only while the layout is being used: the logging
panel's tune dialog, and an extension panel's own config form, which
configures that pane alone and has nowhere else to go.

The sheet carries a **search** — matching a panel's description as well as
its name, since a panel is often easier to describe than to name — and beside
it a button opening the **extensions screen filtered to the ones that
contribute panels** (`ExtensionsPanel.onlyHook`). The sheet lists what is
INSTALLED; an operator who cannot find the panel they want needs the other
screen, and sending them to hunt for it is worse than a button.

**Layout options** are the dock's business rather than the panel's, and every
pane has them whichever panel is in it. They are reached while editing and
nowhere else — outside edit mode there is no layout to have options about.
`PaneLayoutOptions` holds them, keyed by module id under
`LayoutKeys.operationPaneOptions`:

- **Title** — the operator's own name for the pane, beating both the
  descriptor's title and whatever the panel's render supplies. Nobody
  overrules what they typed into that box.
- **Show header** — whether a pane ALONE in its group draws one. Greyed
  rather than hidden while it shares a group: the header is the tab strip
  there, and hiding it would strand every other pane. Also always shown while
  editing, since the header is the grab handle and the pane's own control.
- Under a collapsed **Advanced Options**: **font size** and **layout
  density**, for this pane alone, and a **Reset** in the dialog's footer that
  asks first. The font size is a `SubtreeUiScale` — the
  only way to do this that [ui-scaling.md](ui-scaling.md) allows, since
  everything inside stays in plain logical pixels and simply lives in a space
  scaled once more. Not a nested `UiScale`, which is a root primitive and
  stretches a pane's two axes by different factors.
  Density is the same scope a vertical split already publishes, set
  explicitly rather than derived from height.

**The VIEW has the same options, one level up** — its own name and its own
size and density, under `LayoutKeys.operationViewOptions`, reached from a
second button in the header while editing, under the same glyph a pane's
carries — the same kind of thing, told apart by where it sits. Its Restore
Defaults is the whole view: the default arrangement, its own options and
every pane's. Each level names an ABSOLUTE size
and the innermost that names one decides: a pane that overrides nothing sits
inside the view's scope, and the view's own falls back to the app's settings.
The title is greyed for a built-in view (the Operation view is the app's, so
its name is too) rather than hidden, so an operator looking for the setting
is told it does not apply instead of hunting for it. While editing, the
header shows the view's name in place of the operation's — what is being
rearranged belongs to the view, and outlives this operation and every other.

All of it is part of the ARRANGEMENT: edited in the same draft, written by
the same save, restored by the same discard, and a pane's options are
forgotten when the pane they describe leaves the view.

### Using a layout, and editing one

**A tab's name and its action sit together at the leading edge**, in both
modes, with the slack after them. The name is a heading and starts where the
eye already is; the action acts on THAT name, so it follows it rather than
sitting at the far edge of however wide the tab happens to be. While the dock
is being used that action is painted **quiet** — darkened toward black
against the header — and comes up to full strength under the pointer: it is
not what the tab is for, and one at full contrast beside every name competes
with the one thing the strip exists to say. It darkens rather than fading out
so it stays findable at a glance. The recolour is a `ColorFilter`, not a
colour passed down, because the action is the caller's widget and has already
chosen a colour for the fixed split's title bar, where it must read against
that header instead.

**A tab's action is painted quiet, but never below 3:1** against the header
it sits on (WCAG 1.4.11). It darkens INTO the header rather than fading off
it, and darkens further if the first step is not yet legible — derived from
the header colour, since an edition's is not the one this was tuned against.
A header already too dark to recede into gets the control at full strength:
a louder header than intended beats a control nobody can find, and there is
no hover to fall back on when the screen is a touchscreen.

**The squeeze has a floor of its own.** Below the grab handle a tab does not
shrink, it overflows — the handle is a fixed box, and it lands on the
neighbouring tab. A strip too narrow even for handles scrolls: the wrong
answer while rearranging, and the only one left. The showing tab's floor is
measured from every box between its two edges, the label's own inset
included; one left out of that sum is a tab that ellipsizes below the three
letters the floor exists to keep.

**A group of one is a pane, not a tab bar of one.** It renders as a plain
title bar — the fixed split's idiom, reading from the leading edge — with no
selection indicator, no tap, and nothing announced to a screen reader as a
tab. A tab bar of one offers a choice that does not exist. It is still the
group's grab handle and still takes drops, so a second pane dropped on it
turns it into a real tab strip.

**Rearranging is a mode, and it is off.** The dock an operator works in all
day offers exactly one layout gesture: dragging a **divider** to resize.
Tabs select, each pane keeps its own settings control, and no tab carries a
grab handle — there is no drag to catch a pointer that was aiming at a tab,
because the pane a stray drag would rearrange is the one with a half-typed
QSO in it. `DockLayoutView.editing` off means there is no `Draggable` on a
tab *at all*, not a disabled one: a refusing `Draggable` still enters the
gesture arena against the tap.

**The header's layout button** turns the mode on. It is always visible where
the setting is on — an operator who asked for a customizable layout has asked
to see the way into it — and pressing it goes straight into editing, with no
sheet in between: what they want when they reach for it is to move a pane.
While editing it becomes **Save Layout**, with a **discard** and a **plus**
to its left. While editing:

- every tab is a grab handle, at full strength, on every tab in a group. The
  strip stops SCROLLING and starts squeezing: a strip too narrow to divide
  evenly shrinks the tabs that are not showing, and the showing one stops at
  a floor of its two slots plus three letters and an ellipsis. Those slots
  are UNEQUAL while editing — each only as wide as what is in it, rather than
  the matching chrome-height pair that keeps a label centred and still while
  the dock is being read. Equal slots would spend the whole floor on a 20pt
  handle and a 24pt glyph, and the tab would show punctuation where a word
  would fit. The squeeze is
  continuous — the others give up exactly what that floor needs and no more,
  so a strip a few points too narrow costs a few points of label rather than
  every label at once. The floor is MEASURED, not a constant: a fixed number
  is a number for one font scale, and the strip would collapse early at
  Larger and late at Smallest. Scrolling is right while the dock is being
  used, where the operator is reading tab names; mid-rearrange the tab
  scrolled out of sight is as likely as not the one being worked on;
- the view's header goes inert: it names the view, drops the dots, and no
  longer opens the operation's setup sheet. The operation is not what is being
  arranged;
- each pane is **outlined as a folder** in `fabAccentColor` — every tab is a
  block with a rounded top, and the one that is showing is filled dark blue
  and leaves its bottom open, so the line runs down into the pane's body and
  around it; the pane and the tab naming it read as one object to pick up.
  The pane's own two bottom corners stay square: they sit against the dock's
  dividers and its outer edge, which are square;
- each pane's tab action slot holds its **layout options** (below) instead of
  whatever the panel offers while it is being used. One or the other, never
  both: they are different questions, and edit mode is when only the second
  can be answered;
- **deleting is a drag**, onto a circle flush with the dock's top edge that
  exists only while something is in the air. Not a button on the pane: a
  control sitting on every pane is one an operator can hit while doing
  something else, and what it destroys is a pane they arranged and
  configured. Reaching this one takes a deliberate journey with the pane
  already in hand — and against the top edge is where a pane thrown upward
  runs out of room, which beats a target that has to be aimed at while the
  pointer is already busy. Whether it arms is decided from where the
  PRESS landed, before the drag exists: anywhere outside its circle and it is
  mounted from the first frame, which is every ordinary drag. Only a press
  that landed ON it waits — the top edge is where the tab strips are, so a
  press there is already on the target, and a mouse that slips a pixel
  between press and release would take the pane with it — and then only until
  the pointer leaves or has travelled a diameter. Deciding it later, from
  accumulated travel, is worse than the bug: `onDragUpdate` fires after
  Flutter has hit-tested that move, so a target that appears part-way through
  a drag can miss the last update and never become the active one, and the
  pane silently re-docks at the top edge instead of being deleted. The circle
  is tested as a circle, not as its bounding box: the operator aims at what
  is painted. It overlaps the middle of the tab strip and wins
  the drop there, being drawn last; the tabs either side of it are still
  reachable, and the strip's exact centre is not where anyone aims to join a
  group. It is absent for the view's last pane, which cannot be removed — an
  empty dock has no tab left to drag anything back with;
- **the pane's layout options carry a Remove**, which is the same act by
  pointer-free means. A drag cannot be made with a keyboard or a screen
  reader, and without this the only route left would be Restore Defaults —
  the whole arrangement thrown away to be rid of one pane. It does not ask
  first, unlike the Restore Defaults beside it: one pane is part of the
  draft, and discard brings it back with what was in it;
- pane contents are covered and take no pointer input — while editing they
  are blocks to arrange, not things to read. The cover carries the showing
  tab's blue on down into the top of the pane, for the height of the strip
  itself (that band is where a row of pane controls goes), and then fades
  over the same distance into a **half-opaque grey**, so the pane's contents
  come back gradually rather than at a line. The stock tab indicator is
  suppressed while editing: it would draw a line across exactly the gap the
  folder shape leaves open;
- the header carries **Save Layout** and, left of it, a **discard**.

**The pane gives up the room the outline needs.** It gets a little smaller on
its three free sides while editing, and the line sits in what it gave up
rather than over anything the pane is showing — at a pane's edge that would
be a log column or the map's scale. Nothing comes off the *top*: the tab
strip's own segments are the outline there and the strip has not moved, so no
pane shifts down when editing begins.

The outline is drawn in **pieces** — each tab paints its own segment, the body
paints the rest — rather than by one painter over the group. Only a tab knows
where it is: tabs share the strip evenly until they stop fitting, and then the
strip scrolls. A painter above them would have to measure, and a measurement
taken mid-scroll or off-screen is a frame stale. Interior tabs centre their
side strokes on their own boundaries so each pair draws one line between them
rather than two; the strip's two outer edges, having no neighbour to share
with and a scroll viewport that would clip their outer half, inset instead.

Narrowing past the two-pane breakpoint takes the dock away and with it every
edit control, so as far as the operator can see the edit is over: the draft
stays in state (widening returns to it), but the focus edit mode took is
handed back there and then, or they meet a normal-looking logging view that
swallows every keystroke.

**The edit is a draft.** Nothing an edit does — a drag, a split, a divider,
an add from the plus or a drag onto the delete target — reaches settings
until Save Layout;
that is the whole basis on which discard can promise anything. The two
buttons are the only ways out and they are exact opposites: Save keeps
everything, discard restores the arrangement as it was when editing began and
ends the edit. **Restore Defaults**, in the view's own layout options, is a
third thing — the app's default layout, not this session's starting point —
and it is part of the draft like everything else, so discard undoes it.

Restoring or reverting replaces the arrangement WITHOUT emitting: an emit
reports the new selection through `onStateChanged`, which is not gated on
edit mode and would write which pane is on top to settings there and then —
past a discard that cannot take it back.

**Restore Defaults restores everything**: the default arrangement, the view's
own options, and every pane's. Not two controls. A reset that put the options
back and left the arrangement alone is not a restore — an operator asking for
defaults is asking for the view they started with, and having to find a
second control in another menu to finish is how they end up half-way between
two layouts. A pane's own Restore Defaults is the same promise one level
down: its title, header and size, and nothing else in the layout.

An id waiting to be forgotten is not free. A new instance takes the next
number past it, so a pane added where a removed one stood arrives empty
rather than holding the last one's notes — and the save, seeing that id back
in the arrangement, would have spared it.

Two consequences that are easy to get wrong. **Removals defer their forget**:
dropping a pane normally forgets its config (see instances, above), but a
discard brings the pane back and it has to come back with what was in it, so
the forget waits for the save — and a discard forgets, there and then, the
panes it is *dropping*, which the edit added and nothing outside it ever knew.
And **selection is not part of the draft** —
which pane is on top is state, not arrangement (below), and it is saved as
the operator makes it whether or not they are editing.

Two structural notes. The view's header takes no taps while a modal route is
up — the route's barrier takes them wherever they land. So the edit controls
are built once by the view and rendered in *two* places, never both: the
view's own header while no sheet is up, and the sheet's
`TopModalPaneRoute.headerTrailing` while one is. A control left in the header
under an open sheet is visible and dead.

The plus is one of the controls the sheet's own header carries, so it is the
obvious thing to press while the sheet is already up. It refuses: a second
route would take over the revision notifier the first sheet's list listens
to, and closing would clear the open flag under a sheet still on screen —
putting exactly the dead copy of the controls in the header that the rule
above exists to prevent.

A sheet outlives the dock it was opened over — a resize past the two-pane
breakpoint takes the dock down and leaves the route standing — so everything
it does re-reads `_dockKey.currentState` rather than the one captured when it
opened. The same goes for the discard: it must work with no dock mounted,
because turning the setting off mid-edit is exactly when there is none.

**Leaving edit mode from that header takes the sheet with it.** The sheet is
a control panel for an edit in progress; left open past the exit, its add
writes straight to settings on the next press, with the discard that was
beside it gone. And the header dresses for editing only
where the dock actually IS — the controls are two-pane-only, so a header that
went on naming the view after the window narrowed would strand the operator
with no way out. The draft is state, so widening comes back to it.

**The dock's definition and its state are stored apart.** The definition
(`LayoutKeys.operationDock`) is the tree — splits, weights, which modules sit
where. The state (`LayoutKeys.operationDockState`) is what the operator has
done *without* changing it: which pane is on top, and later which collapsible
panes are hidden. `DockNode.toJson` carries no `selected`.

This is not tidiness. While selection lived in the definition, **tapping a tab
was an edit to the arrangement** — so merely looking at another pane wrote the
dock back to settings, and whatever stand-in happened to be on screen at that
moment replaced the real layout permanently.

State is keyed by **module id**: `{"selected": ["logging", "info"]}` names the
modules on top of whatever group holds them. A group holding none of them
shows its first, which is also the default for a group nobody has touched.
Keying this way survives rearrangement — a pane carries its selectedness with
it — and needs no migration when the tree's shape changes underneath.

The catalog re-reads itself on every runtime (re)start
(`ExtensionService.runtimeGeneration`), which is the path an enable/disable
toggle takes. Without that subscription a view mounted across a trip to
Settings would never see a newly enabled extension's panels, and a catalog
first asked before the runtime finished booting would stay unresolved for
the session.

**Rendering is budgeted, not reactive.** An extension panel declares what it
re-renders on; the host throttles to one render per `panelRenderThrottle`
and renders nothing while the panel is behind another tab (dock tabs stay
mounted, so otherwise a four-panel layout pays for the three nobody is
looking at). The rule this exists to enforce: **nothing an extension
declares may put a bridge call on the per-keystroke path.**

The `qso` trigger is where that rule bites, since the QSO being composed
changes on every keystroke. Three gates keep it off that path, and all three
are load-bearing: the view hands `LoggingControls` a **null** `onQsoChanged`
unless a panel in the current arrangement declared `qso` **or** `lookup`
(the resolved guess travels inside the draft and nowhere else, so a
lookup-only panel would otherwise be woken with no callsign at all), so the
draft is not even built otherwise; the draft is deep-compared before it is published,
so a rebuild that changed nothing publishes nothing; and the view debounces
what it does publish, so typing a callsign is one rebuild rather than one
per letter. A panel that only wants the resolved callsign declares `lookup`
instead, which fires when a lookup is answered.

The producer gate is **arrangement-wide, not visibility-aware**, and
deliberately so: a `qso` panel parked behind another dock tab still turns
the draft on, even though `ExtensionPanel` renders nothing for it while it
is hidden. Which pane is on top is the dock's own state and is not published
upward, and the consumer-side rule is the one that guards the expensive half
— the bridge call. What a hidden panel still costs is the draft's rebuild
and one debounced rebuild of the view per typing pause.

## Dialogs and Modal Panes

Two distinct surfaces; pick deliberately:

- **Simple dialogs** — brief messages, confirmations, one or two fields.
  Plain `showDialog` + `AlertDialog`, no minimum width, identical at every
  shirt size.
- **Modal Panes** — pane-sized content, designed at `idealPaneWidth`. Shown
  via [`showModalPane`](../../packages/halo_widgets/lib/src/modal_pane.dart),
  which pushes one adaptive route:
  - **XS / S:** a full-screen page with an AppBar whose back button *is* the
    dismissal, and actions pinned at the bottom.
  - **L / XL:** a centered dialog at the ideal pane width, with a pinned
    title row, scrollable body, pinned actions, and barrier/Escape
    dismissal. (Panes that manage their own vertical layout — internal
    scrollables, height-filling sections — pass `scrollable: false` and get
    a bounded height instead of a scroll view: as much as they ask for, up
    to the pane's max, so a filling body still gets the full height and a
    short form gets a card that fits it.)

  It is a single route that re-presents itself when the window crosses the
  S/L boundary while open — no pop-and-reshow. Both presentations resolve
  through `Navigator.pop(context, result)`; call sites `await` it exactly
  like `showDialog`.

---

## Rules for future changes

**1. Never invent a breakpoint.** Branch on `ShirtSize.of(context)` (usually
`.isTwoPane`). If you're comparing `MediaQuery` width against a literal
number in a view, stop — either it's a shirt-size decision, or the constant
belongs in `layout.dart` with a name. (Internal component reflow like the
form renderer's icon-row stacking is exempt: that's content fitting, not
layout mode.)

**2. Tolerate mid-life mode flips.** Window resize *and* font-scale changes
can flip shirt size while a view is on screen. State that must survive the
flip lives above the layout switch (in the view's `State`), and shared pane
subtrees carry `GlobalKey`s so Flutter reparents them instead of rebuilding.

**3. Never mount both arrangements at once.** No `AnimatedCrossFade` or
stacked variants across a mode switch — `GlobalKey` reparenting requires a
single instance per frame, and a duplicate key is a crash. The mode switch
is a hard cut; the polish comes from `ResizableSplitView` animating widths
inside a mode.

**4. Clamp on read, never write back.** A persisted pane width that doesn't
fit the current window is clamped for layout only. Only an actual user drag
updates the stored preference.

**5. Reserve macOS traffic-light clearance on the left edge only.** Any
AppBar that can sit at the window's left edge on macOS — a full-screen Modal
Pane, a split's *left* pane, any narrow-mode route — needs
`macOSAwareLeadingWidth` / `macOSAwareBackButton`
([ui-scaling.md](ui-scaling.md)). AppBars on a split's *right* pane must
not add it.

---

## Where the pieces live

| Piece | File |
|---|---|
| The panel catalog (native + extension) | `app/lib/services/panel_service.dart` |
| Extension panel rendering and its HTML sandbox | `app/lib/views/operation/panel_content_view.dart` |
| A panel's render loop and refresh budget | `app/lib/views/operation/extension_panel.dart` |
| Add a Panel sheet | `app/lib/views/operation/layout_sheet.dart` |
| The pane a missing extension leaves behind | `app/lib/views/operation/missing_panel_pane.dart` |
| Dock definition, dock state, and the drop model | `packages/halo_widgets/lib/src/dock_layout.dart` |
| Shirt sizes, ideal pane width, animation constants | `packages/halo_widgets/lib/src/layout.dart` |
| Layout density, its metrics and the operator's preference | `packages/halo_widgets/lib/src/density.dart` |
| The root density scope, and the header's snap | `app/lib/main.dart` (`_LayoutDensityFromWindow`) |
| Resizable split with draggable divider | `packages/halo_widgets/lib/src/resizable_split_view.dart` |
| Modal Panes (`showModalPane`) | `packages/halo_widgets/lib/src/modal_pane.dart` |
| Persisted pane widths (`layoutDimension`) | `app/lib/services/settings_service.dart` |
| Home split + branding pane | `app/lib/views/home_view.dart` |
| Operation tab/split layout | `app/lib/views/operation_view.dart` |
| Settings split | `app/lib/views/settings_view.dart` |
| Tests | `packages/halo_widgets/test/`, `app/test/` |

## How to verify a change

Run the app on macOS and drag the window width across 360, 720, and 1200.
Confirm:

- Home, Operation, and Settings each switch arrangements at 720 — and
  nothing changes at 1200 (XL is reserved).
- In-progress state survives the flip: a half-typed callsign in the logging
  controls, the operation list's scroll position.
- Dividers drag smoothly, respect minimum pane widths, and the widths come
  back after quitting and relaunching.
- A Modal Pane open during the resize re-presents as screen ↔ dialog, and
  still returns its result.
- At font scale Largest, everything above still holds at proportionally
  wider physical windows.
