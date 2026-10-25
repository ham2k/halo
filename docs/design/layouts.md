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
| **Home** | Navigation rail, then a **dock** holding the operation list, with Quick Lookup under both | Navigation rail, then a **dock**: Operation List (~2/3 width) beside Current Version — the default arrangement, which the operator may rearrange — with Quick Lookup under both |
| **Operation** | A **dock**: one tab strip of QSOs, Spots and Map | Logging pane on the left (~2/3 width, resizable); right side tabs: Info, Spots, Map, Operation |
| **Settings** | Settings list; each panel pushes a full screen | Settings list stays as a left column (resizable); selected panel on the right |

### The navigation rail

The rail runs down the left edge of the **window**, not of a view, starting
**below the header line** — it is a sibling of the routes and of the status
chrome, so a status item shortens the
views beside it and never the navigation, and Settings can be shown in Home's
place with the rail standing still. It sits outside the dock, so rearranging
can neither move it nor delete it.

**The logo toggles it, and one stored preference (`homeNavExpanded`) means two
different things** because the two sizes have different room to give:

| | L / XL | XS / S |
|---|---|---|
| toggle off | icon-only rail | **no rail** — the logo and a settings cog in the header instead |
| toggle on | labelled rail | icon-only rail |

Labels would take a third of a phone's width, so a narrow window spends the
toggle on the rail's presence rather than on labels. The settings cog exists
only for the one arrangement with no rail to hold it — two ways to the same
screen, one of them a permanent fixture of the other's chrome, is how an
operator learns to distrust both — and it fades *and* closes up as the rail
arrives, rather than leaving a hole where it stood.

**The railless header holds the product name and the cog, and nothing else.**
The profile name and the layout button come with the rail, which is one tap on
the logo away: a phone's header has no room to carry them beside the cog. The
exception is an edit already in progress — once editing, the layout controls
are Save and Discard, so they stay through a rail toggled away mid-edit rather
than leaving the edit with no way to end.

**Headers span the window and never answer to the rail.** Every destination's
header runs the full width above it, holding the same leading gap for the mark
(`HomeRailLogo.headerReserveOf`) whether the rail is out, labelled or gone, so
toggling the rail never moves a title. Only the BODIES sit beside the rail
(`BesideRail`). The header's *contents* may still follow the rail — the cog
above, and embedded Settings showing a back arrow only while there is no rail,
since beside one the rail's own Settings entry is the way back.

**The mark is drawn by the window**, at a fixed position, rather than by the
rail or by the header. Its box is the same in every state — the icon column's
width, the header's height — and it sits on the header's own LINE, never below
it. On a chromeless macOS window that means after the native window buttons
rather than under them: the mark takes the next place along that line, and the
headers hold open the whole of it. It belongs to the rail and travels with it:
a view that covers the rail covers the mark too, and neither needs telling.

The rail is a **well**: the header above and the panes to the right cast
inward onto it. Both shadows are drawn by the RAIL, not by the casters — one
painted by the caster would fall on the caster's own side of the boundary —
and they are paint-only, so every destination under them stays pressable. Dark mode swaps the black for
a white glow, the same rule and the same numbers as the `surfaces` split
divider.

**Safe areas.** A landscape cutout falls on the leading edge, and who takes it
depends on who is standing there. With a rail, the rail does — by GROWING,
never by padding its contents in: its widths are sized to hold a glyph and a
label, and an inset subtracted from them overflows instead of insetting. Every
width computed for the rail therefore carries the cutout too, including the
tight one it is laid out at; one that left it out would clamp the widening
away and squeeze the glyph out of its own column, on device only. Its icons
are then padded off the cutout inside that wider column. With no rail, Home
reaches that edge itself and takes the inset in the usual way
(`PaneSafeArea.root`'s `left`). The mark, drawn outside both, clears the
status bar and the cutout on its own.

The rail also stops where the **on-screen keyboard** starts. It runs the full
height of the window and pins Settings to the bottom of itself, so a keyboard
over that corner takes the app's only route to Settings with it. The shell is
built inside `removeViewInsets(removeBottom: true)` and cannot see the keyboard
from there, so the inset is handed to it. Standing clear of a keyboard leaves
the rail short — shorter than its own contents on a landscape phone at a large
font scale — so it scrolls rather than overflows, while staying exactly as it
was wherever there is room.

Its destinations are **Operations** (`notebook-multiple`) at the top, then
**Chasing** (`binoculars`) and **Logs** (`file-cabinet`) while their
experiments (`chase`, `logs`) are on, then **Maps** (`map`), with **Settings**
(`cog`) pinned to the bottom, on the rail's own surface like the rest. Each of
the column's destinations is inert while it names the screen the operator is
already on — it renders selected and announces itself, but a control that
reloads the screen you are on is a control that does nothing — and takes them
there from anywhere else. Inert, it still TAKES the press rather than letting
it through to the rail's ground. Each one's press target also reaches halfway
into the gap on either side, the first one up to the header: the gaps belong
to the entries, so a press landing just off a glyph navigates instead of
toggling the rail. Only the stretch below the last entry is ground. They all
draw the muted solid glyph: MDI has no outline for most of them, and the
column must read as one tone, so Maps passes over the `map-outline` it does
have. Settings, unlike them, is a **toggle** — whoever opened it from the rail
reaches for the same control to put it away, and comes back to the
destination they left, or to Operations if that one has gone behind its
experiment meanwhile.

### Navigation around the rail

The rail never hides, narrows, or animates for navigation. What changes is
which side of the routes it is painted on:

- **Home and the other destinations sit beside it**, each spanning the
  window with its body held clear of the rail, and the rail is painted *over*
  them. That is forced rather than chosen: the overlay a route lives in takes
  every pointer that lands in it, so a rail painted underneath is a rail
  nothing can press. **Every destination arrives the same way, Home
  included**: it comes to the top and slides in from the window's left edge,
  passing *under* the rail, OVER the one it replaces — which stays exactly
  where it is until covered, and only then is put away. Nothing slides out: a
  view leaving to the left as another arrives from the left reads as the two
  colliding. The one exception is launch, where Home is simply there. Home,
  Chasing and Maps stay mounted once first shown, offstage while another
  destination is up, so coming back finds them as they were left, the map's
  camera and what it had loaded included — Maps keeps the device's location
  fix running only while it is the one on screen.
- **The operation view owns the whole window**, so the rail is painted *under*
  that one and the view simply covers it on the way in. Losing the rail's taps
  while it is buried costs nothing, which is what makes the flip safe. Home
  spans the window, though, so the real rail under it would vanish the moment
  a push begins — and under a dialog that only dims Home. While anything
  covers it, Home's own layer paints a stand-in of the rail and the mark
  (`HomeRailStandIn`, paint only), which the arriving view covers as it covers
  the rest of Home. The operation view arrives from the RIGHT, away from the
  rail's edge — a view that covers the navigation should not read as having
  come out of it — and its header carries a cross rather than a back arrow,
  because a view over the top of everything has no trail behind it to step
  back along. It travels over **400ms**, longer
  than the 300ms that paces pane widths and the rail's toggle: a whole view
  crossing a whole window covers far more ground, and the shorter duration
  over that distance reads as a snap. Out matches in.

The two layers are keyed, because they swap places in the Stack. Unkeyed, the
framework matches children by position, finds a `Positioned` in each slot, and
updates each element with the other one's widget — re-inflating the whole route
tree on every push, at exactly the moment a view is trying to animate in.

Bodies take **no inset from the rail's animating width**: one inset by it
would re-lay itself out on every frame. Their inset comes off the rail's
*resting* width, which changes only on the toggle, and animates for that
alone — in step with the rail, same duration and curve.

**The foot of the window is two rows, and they belong to different owners.**
Nearest the panes, Quick Lookup with the rail's Settings entry beside it: that
row is the HOME layer's, drawn inside the routes, so an operation covers it by
covering the window and Settings shown in Home's place slides over the field
it replaces — neither is told to hide it. Below that, notices, the status
footer and the numbers row span the whole window and belong to no view: they
say the same things over Home, over Settings and over an operation, so they
stop at nothing and move for nothing. The rail's column ends where that band
begins.

Mode switches are **hard cuts within a single build** — a view's `build`
switches on `ShirtSize.of(context)` and returns one arrangement or the
other. Width changes *within* a mode animate (300ms, ease-in-out, via
`ResizableSplitView`).

## View classification: fixed vs. layout-customizable

Every root view is classified by `ViewLayoutPolicy`
([`layout.dart`](../../packages/halo_widgets/lib/src/layout.dart)), declared
as a `layoutPolicy` const on the view class:

- **`customizable`** — the view's panes are user-arrangeable via the dock
  layout (`DockLayoutView`): the **Operation** view and **Home**. There is
  no setting behind it — a customizable view is always a dock, and an
  operator who never enters edit mode sees its default arrangement.
  Rearranging decides where panes go, never what there is to arrange: the
  native panels ship with the app, and a dashboard PANEL extension (Custom
  Text is the only one today) is enabled from the Extensions panel like any
  other. Enabling a panel must not quietly rearrange somebody's view.
  A dragged tab can land on another group's
  **tab strip** (joining that group at the position aimed at, which is also
  how tabs reorder), on one of the **four split bands** over a group's body,
  or on a **dock edge** strip. The bands are thirds running the full length
  of the body and so overlap at the corners: a corner entered from outside
  resolves to the horizontal band, and a band already highlighted keeps the
  pointer as it slides into an overlap, so the highlight doesn't flicker
  while the operator is still moving. A dropped pane takes **the band's own
  third** — it arrives at the size the operator was looking at — and grows
  into it over `layoutAnimationDuration`, floored at a group's chrome height
  so a pane is never laid out shorter than its own tab strip.

  The **middle square** is a fifth and sixth target, and means something the
  four bands cannot: its upper and lower halves **nest** the newcomer inside
  the tab that is showing rather than splitting the group in its parent. See
  *A tab can hold a split* below. A strip along its centre line stays inert
  — the one place inside a pane where a drag the operator thought better of
  can be let go, and without it every pixel of every pane would act on
  release.

  All of a customizable view's dividers use the **solid** style below.

  **Home** carries its own four
  `LayoutKeys` (`home.dock`, `home.dockState`, `home.paneOptions`,
  `home.viewOptions`) and its own two panels — Operation List and Current
  Version. Quick Lookup is NOT among them: it is chrome the operator cannot
  rearrange away, under whatever the layout holds. There is no
  `home.leftColumn` any more: a dock's splits carry their own weights, and
  Restore Defaults deliberately ignores the old key rather than handing back a
  width dragged before the dock existed.

  **Every customizable view carries TWO arrangements**, wide and narrow,
  split at the same two-pane boundary. A dock tree names splits, weights and
  module ids and no widths at all, so ONE tree drawn at 360px would hand a
  phone the same two-thirds/one-third split it was arranged at — which is why
  this is two trees rather than one that reflows. Each is a
  `DockLayoutClass`, with its own four `LayoutKeys` (the narrow set is
  `<view>.narrowDock`, `.narrowDockState`, `.narrowPaneOptions`,
  `.narrowViewOptions`), its own default, and its own dock: crossing the
  boundary MOUNTS the other one, because `DockLayoutView` copies its
  `initialSpec` once and ignores it afterward, so a single dock handed a new
  spec would go on showing the tree it started with and take every later edit
  into that one. The panes carry their own keys and are reparented across the
  swap, so nothing being typed is lost.

  Each narrow default reproduces what its view drew before it had a narrow
  arrangement, so nothing moves for an operator who never edits: Home the
  operation list alone (Quick Lookup being chrome under it either way), Logs
  its QSO table alone, Operation one tab strip of QSOs, Spots and Map. Info
  is not in Operation's — it stays one tap from the callsign area — but the
  Add a Panel sheet offers it like any other.

  The two arrangements are **independent**: a panel added wide does not
  appear narrow, and each holds its own instance ids and its own pane and
  view options. A phone's density is not the desktop's.
- **`fixed`** — the arrangement never changes (Settings). Fixed
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

**A touch platform grabs from a slop either side of the bar.** A fingertip
is wider than any thickness the panes can afford to give up, so the extra
target isn't painted at all: on `isMobilePlatform`, each boundary carries a
transparent grab strip `paneDividerTouchSlop()` (8pt) wider on each side,
stacked over the run and wired to the same drag callbacks as the bar it
covers — a resting solid divider is a 9pt bar in a 25pt target. It costs no
layout space; it costs presses, since the strip takes them opaquely: within
that slop of a boundary, pane content gets no tap at all, and a gesture the
content owns can't be started there either — in the logs table, a column
REORDER drag can't begin within a slop of a column boundary. Only travel
ALONG the divider's axis arms a resize, so a swipe across the strip is at
least not silently turned into one — see `PaneDividerDragTarget`. The strip has to be placed by the owning layout
(`DockLayoutView`'s split runs and `ResizableSplitView`, which covers the
surfaces style too), never by the divider overflowing its own box:
hit-testing runs in reverse child order, so a self-overflowing bar would lose
every point on its trailing side to the pane after it. Covering the bar also
takes the bar's own `MouseRegion` out of the hit path, which matters on an
iPad with a trackpad — so the strip carries the resize cursor and forwards
hover into the bar (`SolidPaneDivider.hovered`). The same mechanism widens
the logs table's column-resize handles, which can't grow either: that handle
IS the gap the QSO rows leave between columns. There the strip paints the
line as well, and the row leaves a plain gap — whichever widget the pointer
reaches is the one that draws the feedback.

The editing width is granted unconditionally — the panes give it up, and
nothing rations it against what they can spare. A group is a Column of its
tab strip over an Expanded body, so a pane shorter than its own strip
overflows — which is why a headerless group does NOT gain a strip on
entering edit mode: its handle, name and options button float over its
corner instead (`_FloatingPaneChrome`), costing the pane a divider's few
points rather than a whole chrome height. A guard on the bar alone would
have bought a guarantee that still didn't hold for a headed group, so the
bar stays simple and the real floor lives where the chrome is —
`dockMinPaneExtent` (`packages/halo_widgets/lib/src/layout.dart`), one number
for every pane whatever its orientation, editing or not.

**Surfaces (opt-in — Settings today).** The divider consumes no
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

- `settings.leftColumn`

The split clamps the preference to what fits **at layout time only** — a
temporarily small window never overwrites the stored value. The persistence
callback fires on drag end, not on every drag frame.

### Dock pane minimum size

Every dock pane's floor is expressed in **units**
(`dockPaneUnit`, `packages/halo_widgets/lib/src/layout.dart`) — a normal
button's size at the current density and font scale, the same value the
chrome height and the handle/settings icons are built from. A pane cannot
lay out its handle, title and settings icon at all below **three units in a
row, or one wide by three tall** — whichever orientation its available space
allows (`dockMinPaneExtent`). Below three units on one axis the header
reflows from a row to a stacked column on the other, rather than shrinking
past the point its three controls still fit.

This is the floor for every pane, editing or not — a pane never changes size
just because the operator entered edit mode (see the divider section above).
A `DockSplit`'s own floor along an axis is the max, or for a matching-axis
nested split the SUM, of its children's floors (`DockLayoutViewState._nodeMinExtent`)
— a nested split needs its whole subtree's minimum, not one unit per direct
child.

A panel can declare a larger minimum than the three-unit default for content
that genuinely needs more (a map, a table) via `PanelDefinition.minWidth`/
`minHeight` (`app/lib/services/panel_service.dart`) — native panels only
today; an extension panel's `panel` hook entry declares no minimum and
always gets the default.

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

- **Native panels.** Each view registers its own (Operation: QSOs, Info,
  Spots, Map, Operation Summaries; Home: Operation List, Current Version; the Logs view: QSOs,
  Info, Map) with their title, description, icon and, where they have any,
  the settings *target* whose declared settings make up their settings
  dialog. The service holds identity only: the widget stays with the view
  that builds it, which is what lets the Add a Panel sheet list a panel it
  has no way to build.

  Clock, Weather, Solar and Web Site are the exception: every customizable
  view offers all four, so `DockHost.registerSharedDashboardPanels` (used by
  every view via the mixin) is what registers them, and
  `DockHost.sharedDashboardPanes` is what builds their widgets. Radio joins
  them, and Remote Screen does while its experiment (`remote`) is on —
  registered from the same place and gated there, so a saved arrangement
  holding one falls to the missing-panel placeholder with the experiment off
  rather than losing the operator their pane. Registering
  from every view rather than a single owner is deliberate —
  `PanelService.registerNative` no-ops on an identical re-registration, so
  whichever view mounts first wins and the other calls cost nothing, and no
  view's catalog depends on another view having mounted first.

  **Registering is how a descriptor built from live state is published, so
  identity compares the form's CONTENT.** The Radio panel's picker lists the
  configured radios and names whichever one drives VFO A; that list rebuilds
  to the same field *count* every time it changes, so an equality comparing
  `formFields.length` reads a changed picker as identical, the registration
  no-ops, and the operator is left choosing from a list frozen at whenever
  the view first mounted — with nothing on screen to say so. Two rules
  follow, and a panel with a live form needs both: `PanelDefinition.==`
  deep-compares `formFields`, and something has to *call* `registerNative`
  again when the state behind the form moves (`DockHost` listens to
  `CatService` for exactly this). The no-op is what makes the second rule
  cheap — a radio connecting notifies several times a minute and costs one
  comparison.

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
  instruction list (`<animate>` and `<style>` are dropped outright), so
  nothing an extension can return sweeps a second hand. The tick floor is one
  second and no longer the reason: a panel CAN be asked to re-render every
  second, it just cannot hand back anything that moves between two of them.

  **Weather is native for the second of those two reasons.** Its eight-hour
  temperature curve is fitted to whatever was fetched, and a hook that
  contributes a document has no way to hand back a shape — as a `panel` hook
  it can only be a table of numbers. Its fetch, cache and refresh are
  ordinary Dart besides: no bridge call per render, and no tick floor at all.
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

The placeholder also says what would bring the panel back
(`MissingExtensionAction`): **Enable** for an extension installed and switched
off, **Install…** for one the app does not have, or why neither helps (it
won't run in this version, it isn't offered in this app). Install asks the
catalog only when pressed, since a layout full of these panes would otherwise
fetch on every open. It then takes the catalog's usual consent prompt, or says
the catalog had no such extension or couldn't be reached, offering to try
again. The import dialog's extension rows are the same control.

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

A tap anywhere on a row adds that panel and **dismisses the sheet** — adding
is what the operator came for. The row's thumbnail is the one exception: it
opens the preview at pane scale. A panel with no drawable preview shows a
placeholder in that slot, which adds like the rest of the row.

The sheet carries a **search** — matching a panel's description and its
extension's name as well as its own name, since a panel is often easier to
describe than to name — and beside it a button opening the **extensions
screen filtered to the ones that contribute panels**
(`ExtensionsPanel.onlyHook`). A search also offers, below the panels it
matched, the extensions that would contribute one: **Enable X** for an
installed one that is switched off, and **Install X** from the catalog (the
same tiers, rows and experiment gate as the operation sheet's activity
search; the catalog is fetched on the first search, once per sheet). Gaining
one puts its name in the search box, which lands the list on its panels.

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
  A headerless pane still **peeks** its header while the mouse is within a
  chrome height of its top (`PaneHeaderPeek`): the title and tab action,
  sized to their content with a solo tab's insets (capped at the pane's
  width, the title ellipsizing), drawn ABOVE the pane's
  top-left corner over whatever is there and fading out to the right. Above
  rather than on the pane, because the pointer is near that top reaching for
  something in it. A pane with only **chrome above it** — at the top of the
  dock, under the view's header, or nested under a group's tab strip — has
  no pane above to draw over, and covering that chrome would hide what the
  pointer may be heading for, so its peek lies over its own top-left corner
  instead — and because there it covers the
  pane's content, it shows only after the pointer rests **still for a
  second** (a few points of drift allowed) in that corner: a third of a
  chrome height tall, and as wide as the peek. Only the
  peek's button takes a press: the title passes clicks and hover through,
  since it lies over the divider above its pane, and a pointer reaching for
  that divider from inside the pane always brings the peek up first. Mouse
  only, and not while editing, where `FloatingPaneChrome` is the pane's
  chrome.
- **Font Scale**, **Layout Density** and **Theme Mode**, side by side and
  always visible (no disclosure to open first), each an "inherit or override"
  for this pane alone, and a **Restore Defaults** in the dialog's footer that
  asks first. The font size is a `SubtreeUiScale` — the
  only way to do this that [ui-scaling.md](ui-scaling.md) allows, since
  everything inside stays in plain logical pixels and simply lives in a space
  scaled once more. Not a nested `UiScale`, which is a root primitive and
  stretches a pane's two axes by different factors.
  Density is the same scope a vertical split already publishes, set
  explicitly rather than derived from height. Theme Mode wraps the pane in a
  `Theme` built for the chosen `Brightness`, light or dark; there is no
  per-pane "system" — that would only mean what inheriting already does.
- **Panel Settings**, under its own banded header, embeds the panel's own
  configuration in the same dialog instead of a separate one: a plain-form
  extension panel's `formFields` render inline
  (`EmbeddedPanelSettingsForm`), and a native panel whose settings are more
  than a form (logging, map) embeds `settingsFormForTarget` — the same
  target-scoped settings widget a standalone dialog would otherwise show.

  A native panel may answer for its own settings instead — a shared
  dashboard panel through `DockHost.sharedDashboardPanelSettings`, a view's
  own through its `nativePanelSettingsForm` — and then that ONE widget serves
  both routes: this embed, and the tab's own settings button, which shows it
  in a dialog of its own. Required, not
  a preference, for a panel whose real control is an action: the embed
  strips every `type: 'action'` element (an action here has no route of its
  own to close on), which would otherwise leave such a panel showing
  nothing but its stored value with no way to change it — and for one whose
  settings are no form at all: Operation Summaries' sections are a
  drag-to-reorder list with a tick per section, saved per placement under
  declared but never-rendered fields so `forgetInstanceConfig` still clears
  them. Serving both routes
  from one widget is the point — the same panel offering two different
  settings surfaces depending on which way in the operator took is worse
  than either.
  Both autosave per field, same as the rest of this dialog. Scrolls in its
  own bounded region so a long panel settings list doesn't push Title or the
  footer off screen.

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
chosen its own colour.

**A tab's action is painted quiet, but never below 3:1** against the header
it sits on (WCAG 1.4.11). It darkens INTO the header rather than fading off
it, and darkens further if the first step is not yet legible — derived from
the header colour, since an edition's is not the one this was tuned against.
A header already too dark to recede into gets the control at full strength:
a louder header than intended beats a control nobody can find, and there is
no hover to fall back on when the screen is a touchscreen.

**Tabs share the strip, whatever they are called.** While the dock is being
used, every tab in a group takes an equal share of the pane's width and
ellipsizes its name to fit. Sizing the strip to its WIDEST tab instead — every
tab as wide as the longest name in the group — pushes the strip past the pane
the moment one module has a long name, and a tab pushed off the edge is a pane
the operator cannot reach without first discovering that the strip scrolls at
all. It scrolls only below a floor of three letters and an ellipsis per tab —
measured like the editing floor, over every box between a tab's two edges, so
it holds at every font scale.

**In a tight tab the ACTION slot gives way, not the name.** The action sits
inside the selected tab's own share, and it is a full chrome height with room
to spare; approaching the floor it gives up exactly what the name needs, down
to its own glyph — the same box editing gives it — and no further. So the
floor reserves that glyph, and a tab AT the floor shows three letters beside
the smallest slot. Reserving the whole tap target there instead is the
tempting alternative and is wrong twice over: the reservation is multiplied by
the tab count, so a group of four flips to scrolling — tabs no longer filling
the pane, every width jumping, dead header at the end — the moment the tab
carrying the action is picked. Reserving nothing is wrong the other way: the
slot bottoms out at its glyph while the share keeps shrinking, and the tab
reads as a settings button with no name.

**A tab's width never moves with the selection.** It is ONE floor per group,
the action counted where any tab in the group carries one rather than where
the selected one does — the selection moves, and a floor that moved with it
would resize the whole strip on every tap. That floor is what the strip
SHARES on too, so a group of four with an action reserves four glyph slots to
guarantee one: the price of a strip that never rearranges itself under the
operator's finger.

**On a touch platform the slot does not shrink at all.** `chromeHeightOf`
holds the strip's height at the tap-target minimum there for this control's
sake, and taking the same points off its width instead would undo that
silently, on the one platform with no pointer to aim with. So the floor
reserves the whole target and such a strip scrolls sooner. Wherever the slot
IS below that target — either mode — the button is themed tight to its glyph:
an IconButton's own padding is 8pt a side, so a 32pt slot otherwise lays a
24pt glyph out in 16 and paints it outside its own box.

Scrolling stays undiscoverable — no scrollbar, and a horizontal wheel the
mouse may not have. That is accepted, not solved: below the floor there is
nothing left to share, and the strip has to give somewhere. Sharing the width
is what makes it rare enough to accept.

**The squeeze has a floor of its own.** Below the grab handle a tab does not
shrink, it overflows — the handle is a fixed box, and it lands on the
neighbouring tab. A strip too narrow even for handles scrolls: the wrong
answer while rearranging, and the only one left. The showing tab's floor is
measured from every box between its two edges, the label's own inset
included; one left out of that sum is a tab that ellipsizes below the three
letters the floor exists to keep.

**A group of one is a pane, not a tab bar of one.** It renders as a plain
title bar, reading from the leading edge, with no
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
  strip stops sharing evenly and starts squeezing: a strip too narrow to
  divide evenly shrinks the tabs that are not showing, and the showing one stops at
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
  Larger and late at Smallest. Scrolling — the last resort in either mode —
  at least leaves every name readable while the dock is being read;
  mid-rearrange the tab scrolled out of sight is as likely as not the one
  being worked on;
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
- **deleting is a drag**, onto a circle at the top of the window that
  exists only while something is in the air. The circle stands a spacing
  unit clear of the edge, below the device's safe area, so a notch or status
  bar never covers it — but the strip above it is part of the target, so the
  throw that overshoots still lands. Not a button on the pane: a
  control sitting on every pane is one an operator can hit while doing
  something else, and what it destroys is a pane they arranged and
  configured. Reaching this one takes a deliberate journey with the pane
  already in hand — and the top edge is where a pane thrown upward
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

**An edit spans both arrangements.** Narrowing past the two-pane breakpoint
hands the operator the OTHER draft with Save and Discard still on screen, and
either of them commits or rolls back BOTH. A resize is not a decision about
the layout: an edit that ended itself on one would commit or lose half of what
was done, with nothing left that could take it back. So both classes are
snapshotted when editing begins — including the one that is not on screen,
which `ensureDockSpec` resolves there rather than snapshotting a null, since
`build` only ever draws one of them.

**Narrow gives the way IN to the operation's Tools menu**, after Export Logs
and Imports, rather than to the header: a narrow header has room for the title
and one control, and the operation's own title has the better claim on it.
Once editing, the plus, Discard and Save come back to the header at every
width — a menu is not somewhere to hide the only way out of a mode.

**Operation pins its logging pane narrow.** No grab handle, no `Draggable` at
all, and both routes to removal refuse it (`DockLayoutView.pinnedModuleIds`).
A phone with no logging pane cannot enter a QSO, and unlike the last-pane rule
there is nothing about the arrangement on screen that would say so — which is
why the tab simply never becomes draggable, rather than a drop being refused
after the operator has already carried it to the target. Wide pins nothing:
the arrangement there always has room for logging alongside whatever else.

### A tab can hold a split

A tab's content is ordinarily a pane. Dropping on the **upper or lower half of
a pane's centre square** makes it a **container** instead: a vertical split
holding what was in that tab and the newcomer, above or below it, taking the
tab's own slot. {Info, Spots, Map} with Info dropped below Map's centre is
{Spots, More[Map over Info]} — the tab SET keeps its shape, which is the whole
distinction from the four bands, which split the group in its PARENT.

Each half is a real group, so dropping on its tab strip gives it tabs, and a
container can hold containers. A container down to **one module** hands its
slot back to that module; one holding a single GROUP of several tabs does not,
because that is a tab set the operator built and folding it up would rearrange
more than they did. A container holding a group whose one tab is ANOTHER
container does fold — that is two tabs deep for one thing, and the operator
would see "More" containing a single "More".

**A drop normalizes once, at the end — never mid-move.** Every drop takes the
module out of the tree before it puts it anywhere, and applying the collapse
rule at that moment is what made a two-pane container impossible to rearrange
from the inside: taking one of its panes out empties that pane's group, which
collapses the split, which retires the container — detaching the very group the
drop was aimed at, so the placement found nothing to place into and silently
did nothing. The removal therefore leaves the tree in its intermediate shape
(a split with one child, a container down to one module) and each handler puts
it back into canonical shape once, after the placement. The tree is only odd
between those two points, inside one `setState`, so nothing ever renders it.

A container has a tab, a title (**"More"** by default) and the whole
`PaneLayoutOptions` surface, because it carries a real id in the same
namespace as module ids — `nested#1`. That is what lets titles, pane options
and `DockState` reach it with no new machinery. The id is allocated per DOCK
rather than per app, unlike a panel instance id: a container indexes nothing
outside its own arrangement.

`DockGroup.modules` stays a list of slot ids; a slot listed in
`DockGroup.nested` renders that subtree instead of a pane. Two fields rather
than one recursive list of nodes, so that every consumer keyed by a module id
— titles, pane options, dock state, headerless modules, minimum sizes —
reaches a container unchanged, and every arrangement saved before containers
existed reads identically. The price is one invariant, and it is `DockGroup`'s
to keep: **`nested`'s keys are always a subset of `modules`**.
`collapseNested` is what holds it after a mutation.

Three consequences. Dragging a container **carries its contents** — a move
that arrived as an empty tab would be a move that silently deletes. Removing
one **takes the panes inside it**, reported through `onModuleDeleted` one id
at a time so a host forgetting their configs needs to know nothing about the
shape of what it removed. And while a container is SHOWING, the outer group's
own body bands, editing wash and outline all stand down: they belong to a
pane, and what is on screen is layout. Splitting that outer group means
selecting a plain tab first; the dock's own edge strips are always there.

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
breakpoint unmounts one dock and mounts the other's, while the route stands
through it — so everything it does re-reads `dockKey.currentState` rather than the one captured when it
opened. That getter answers for the class ON SCREEN, which is the other half
of the same rule: a captured key is stale about which dock as well as about
whether there is one.

**Leaving edit mode from that header takes the sheet with it.** The sheet is
a control panel for an edit in progress; left open past the exit, its add
writes straight to settings on the next press, with the discard that was
beside it gone.

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

## Named layouts

*Behind the `layouts` experiment.* A customizable view keeps a **list of
named layouts**, and draws one of them. Each named layout is everything the
sections above call "the arrangement" — both classes, wide and narrow, with
their trees, pane options, view options and dock state — so switching swaps
all of it at once, the same unit an edit already spans.

**The first layout is the view's original keys.** The list lives under
`<view>.layouts` (`ViewLayouts`, `app/lib/views/dock_layouts/view_layouts.dart`):
`{active, layouts: [{id, name}]}`. The layout with id `default` stores under
the view's unsuffixed `LayoutKeys`, and every other suffixes each of its keys
with `@<id>`. So an arrangement saved before the list existed IS the default
layout, with nothing to migrate, and a missing list reads as that one
layout. It is never scanned for others: the list and the keys are one stored
map, lost together or not at all. Its name is unset until the operator gives it one, and shows as the
translated "Default" meanwhile.

**A list that can't be read loses names, never layouts.** The `@<id>` keys
outlive the list, so `ViewLayouts.read` lists again every id whose keys still
hold something. Each one is unnamed and shows as "Layout <id>". The recovered
list is written back, and a notice says once what happened. A list that forgot
those ids would hand them to new layouts, and a new layout empties its keys
before taking them.

**Switching mounts a different dock.** `DockHost` holds one
`_DockClassState` per class for the layout on screen; switching replaces both
with a fresh pair — new keys, new dock keys — and the dock re-reads its
`initialSpec` because its key changed, exactly as crossing the two-pane
boundary does. The choice is per VIEW, shared by every operation; a view
remembers it across launches.

**Leaving a layout ends its edit first.** The draft belongs to the layout it
began in, and a Save after a switch would write it into the other one, so
`switchLayout` and the rest refuse mid-edit. The sheet goes through
`leaveEditFor` instead. When the draft changed something, the operator picks
Save, Discard or Cancel, and Cancel leaves the sheet up. The edit then ends,
and the editor opens again on whatever layout is now on screen: moving to
another layout from the editor is still editing. Starting a new layout from
the default and importing one as a new layout go the same way. Two actions
take no question. **Duplicate** from the editor copies the DRAFT, including
shared panels' settings an import queued for Save, and lets the original keep
what it last saved, so the edit carries on in the copy. **Delete** drops the
draft along with the layout it belonged to.

**A new layout is written before the edit ends.** A copy or a new-layout
import writes its keys, its instances' settings and the list entry while the
edit is still open, with every id the edit holds kept off limits. Only then
does it save or discard the edit and draw the new layout. One that fails
partway, a keychain refusing a secret say, takes out what it wrote and
leaves the edit as it was. Its half-written slots would otherwise open in the
next layout or pane handed those ids.

**The list is re-read before every change.** Two views of one kind share
it (an Operation view can be stacked over another), and a change made against
a stale copy would hand a layout id out twice or write the other view's
layout out of the list. A view of the same kind drawing the layout another one deletes is moved off
it at once, its draft discarded as the deleting view's is, before the deleted
instances' settings are forgotten under its panes. A re-read that still finds
the layout on screen gone keeps it listed until this view moves off it, but
only here: it is never written back to the list, where it would be a layout
again in both views, opening on the keys the delete emptied.

**Instance ids are unique across every layout of every view.**
`DockLayoutKeys.everySpecIn` lists the spec key of every stored layout, and
`_instanceIdsInEveryDock` reads them all — a layout off screen still holds the
config its instances placed. Two consequences follow from config living in
one app-wide store keyed by placement id:

- **Duplicate** gives each instance a new id with its settings COPIED into it
  (secrets included — the copy stays on this device). Sharing the ids would
  make the two layouts' clocks one placement, and changing one zone would
  change the other's. An instance whose extension is switched off still has
  its plain values copied, read from storage without its fields. Its secrets
  are not: the keychain cannot be listed everywhere the app runs.
- **Delete** forgets the settings of the instances the deleted layout held,
  as removing those panes would have. A panel placed once keeps its settings,
  which belong to the panel and every layout showing it. The last layout
  cannot be deleted.
- An instance whose panel is not loaded, its extension switched off or
  missing, has no fields to name what it stored. Forgetting it, on a delete
  or on a Discard of an import, removes every plain value stored under its
  id instead. So does a forget that fails: it goes a field at a time, and a
  keychain refusing one secret would leave every field after it behind.
  Undoing a write that failed takes each step on its own, so one refused
  forget stops none after it.

The switcher is the layout's name with a drop-down arrow, left of the layout
button. Outside the editor it shows only once there are two layouts: with one
there is nothing to switch to, and the editor, which always shows it, is
where a second one is made. It opens the **layouts sheet**, hanging from it like the Add a Panel
sheet from its plus: one row per layout, its name over its **description**
so two layouts are told apart by more than a name, and a tap on another row
switches to it. A layout the operator has not described shows the panes it
holds instead, and the description field offers that same list as its hint,
so leaving it blank is a choice whose result is on screen. Only the row on
screen carries **Edit** — it is the layout there is to edit — and the Edit
dialog names and describes it and holds **Delete**, at the
far edge of its footer behind a confirmation of its own, absent for the last
layout. The sheet's foot holds Import, Export and **New**, whose dialog asks
for a name and whether to **duplicate the current layout** (the default) or
**start from the default** arrangement.

**While editing, the header keeps the switcher**, the same control as outside
the edit, left of Save, which loses its label and stays the rightmost
control. With several layouts, the header has to say which one a Save writes
into. From the Add a Panel sheet's own header copy, the switcher takes that
sheet down before opening the layouts sheet: what the layouts sheet does next
can end the edit, and an Add a Panel sheet left up past that writes its adds
straight to settings.

A narrow header has no room for the name: Logs and Chase show an icon there,
and Operation's Tools menu carries a **Layouts** entry beside Edit Layout;
both open the same sheet.

## Layout files

A layout — whole, or any part of one — can be exported as a **YAML file** and
imported on another device (`LayoutFile`,
`app/lib/views/dock_layouts/layout_file.dart`). YAML rather than JSON because
these are meant to be read and edited by people; the `yaml` package only
reads, so a small emitter (`yaml_writer.dart`) writes them. Exports are named
`<layout name>.h2klyt`, so a file says which app it is for. Import also takes
`.yaml` and `.yml`, for a file written by hand, and the parse is what decides
in the end.

```yaml
# Ham2K Logger layout
ham2k-layout: 1
view: operation
name: Contest
description: Sprint, with the log on the left
extensions:
  - key: custom-text
    name: Custom Text
wide:
  options:
    density: dense
  root:
    split: horizontal
    weights: [2, 1]
    children:
      - tabs:
          - panel: logging
      - tabs:
          - panel: ext:custom-text:text
            instance: true
            options:
              title: Skeds
            settings:
              text: |-
                K1ABC 14:00
                W1AW 15:30
```

**A file names panels, not placements.** `#n` is a slot in one device's config
store and means nothing on another, so a tab carries its descriptor id, and
`instance: true` where the placement was one of several — read only when the
reading device's catalog cannot say whether the panel allows several (its
extension is not installed). On import every instance gets an id clear of
every layout on the device, and every container a `nested#n` clear of the
arrangement it joins.

**Settings travel per pane, secrets never.** Each pane's form values ride in
its tab; a `secret` field is left out of an exported file, and not even read
from the keychain, which can prompt or fail. On import an
instance's settings are written at once — nothing else reads that new slot.
A panel placed once shares ONE set of settings with every layout showing it,
so the file's replace them only when the operator ticks *Replace the settings
of panels already set up here*, and in a draft only on Save. Those writes
take turns: a Save writes the ones it queued without waiting, and an import
right after it writing the same panel lands after it, not field by field
among it.

**Export** shows a diagram of the arrangement on screen — boxes in the
proportions of its splits, a tick on every panel and one over every tab set
and container — and writes the ticked part, pruned to canonical shape (no empty
group, no split of one, a container down to one pane folded back into a tab).
With everything ticked it carries the other class too, whole: that one has
no diagram, since it is not on screen to pick from. A partial export carries
only the class on screen. Inside a tab set or a container, the tabs and the
container's contents are indented under its tick.

**Import** offers three destinations:

- **As a new layout** — written and drawn at once, keys in one write. A file
  that places nothing this view can hold makes no layout at all; the panels
  left out are named, as always.
- **In place of this layout** and **Added to this layout** — both go into the
  edit DRAFT, entering edit mode if need be, so Save and Discard mean what
  they always do and a discarded import forgets the instance settings it
  wrote. Those settings are written before the draft changes: an import that
  fails partway takes them out again and leaves the draft untouched, rather
  than one Save would commit as though it had worked. One overtaken while it
  writes (a Discard, a move to another layout, a pane added meanwhile) takes
  them out too and lands nowhere. Adding puts the imported panes in a new column at the right of the
  root, for the operator to drag where they belong, and leaves out a panel
  placed once that the arrangement already shows.

A file is refused with a reason the operator can read in their own
language: not YAML (with the line), not a layout file, written by a newer
version, holding no arrangement, not following the format, or too large. Too
large counts values after YAML aliases are expanded, which caps at 100,000;
a few lines of nested aliases would otherwise expand to billions and freeze
the app. It also caps bracket nesting at 200, counted before the parser
runs, since the parser's time grows with the square of the depth. Block
nesting deep enough to run the parser out of stack is refused the same way.

A file exported from another view still imports, and the dialog says which
view it came from: the panels the two views share come across. A class whose
panels the view offers none of is left at the view's default, and the
left-out panels are named after the import like any other.

**A pinned pane stays.** A class's pinned pane (the log, in a narrow Operation
or Chasing arrangement) is put back as the first tab of the first group when
the file leaves it out, and the operator is told. Nothing on a phone could
bring it back, and without it there is nowhere to enter a QSO.

A file with both classes fills both, as a new layout or in place of this
one. The class off screen has no diagram to pick from, so it comes whole and
unasked; adding takes only the class on screen. A file with one class fills
**the class on screen**, whichever it was exported from — the operator is
looking at the arrangement they mean to change. "On screen" is as the dialog
drew it: the picks are tabs of that arrangement, and a rotation behind the
dialog does not move them to the other one. Another view's native pane is left out
(greyed in the diagram), and an extension panel whose extension is missing
comes in as the usual missing-panel pane. The dialog lists those extensions,
each with the placeholder's own control (Enable, Install…, or why neither
helps; after a press that failed, a retry that says so). Once one is running, only the panels that became pickable with it are
ticked; the operator's own unticks stand.

## Dialogs and Modal Panes

Two distinct surfaces; pick deliberately:

- **Simple dialogs** — brief messages, confirmations, one or two fields.
  `showHaloDialog` + `HaloDialog`, no minimum width, identical at every
  shirt size.
- **Modal Panes** — pane-sized content, designed at `idealPaneWidth`. Shown
  via [`showModalPane`](../../packages/halo_widgets/lib/src/modal_pane.dart),
  which pushes one adaptive route:
  - **XS / S:** a full-screen page with an AppBar whose back button *is* the
    dismissal, and actions pinned at the bottom.
  - **L / XL:** a centered dialog at the ideal pane width, with a pinned
    title row, scrollable body, pinned actions, and barrier/Escape
    dismissal.

  Panes that manage their own vertical layout — internal scrollables,
  height-filling sections — pass `scrollable: false` and get a bounded
  height instead of a scroll view: as much as they ask for, up to the pane's
  max, so a filling body still gets the full height and a short form gets a
  card that fits it. This is not a refinement of the dialog presentation but
  a requirement of **both**: a body holding a ListView inside the pane's own
  scroll view is handed unbounded height, and lays the pane out blank under
  a header that still looks right.

  A pane whose body has a natural width of its own — the Cluster Console's
  line length — passes `maxWidth` to widen the dialog presentation past
  `maxDialogWidth`. The window still bounds it; full screen ignores it.

  It is a single route that re-presents itself when the window crosses the
  S/L boundary while open — no pop-and-reshow. Both presentations resolve
  through `Navigator.pop(context, result)`; call sites `await` it exactly
  like `showHaloDialog`.

---

## Rules for future changes

**1. Never invent a breakpoint.** Branch on `ShirtSize.of(context)` (usually
`.isTwoPane`). If you're comparing `MediaQuery` width against a literal
number in a view, stop — either it's a shirt-size decision, or the constant
belongs in `layout.dart` with a name. (Internal component reflow like the
form renderer's icon-row stacking, or the operation header weighing its
Exports/Imports/Tools labels against the width its title wants, is exempt:
that's content fitting, not layout mode. Fitting measures what the content
actually needs — a shirt size cannot, since the title is as long as the
operator's callsign and refs happen to make it.)

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
| Dock definition and dock state | `packages/halo_widgets/lib/src/dock_model.dart` |
| The drop model: regions and drop geometry | `packages/halo_widgets/lib/src/dock_regions.dart` |
| The dock view — tabs, drags, drops and edit-mode paint | `packages/halo_widgets/lib/src/dock_layout.dart`, with `dock_tab.dart`, `dock_drop_targets.dart`, `dock_chrome.dart` |
| Shirt sizes, ideal pane width, animation constants | `packages/halo_widgets/lib/src/layout.dart` |
| Layout density, its metrics and the operator's preference | `packages/halo_widgets/lib/src/density.dart` |
| The root density scope, and the header's snap | `app/lib/views/app_shell/halo_app.dart` (`_LayoutDensityFromWindow`) |
| Resizable split with draggable divider | `packages/halo_widgets/lib/src/resizable_split_view.dart` |
| Modal Panes (`showModalPane`) | `packages/halo_widgets/lib/src/modal_pane.dart` |
| Persisted pane widths (`layoutDimension`) | `app/lib/services/settings_service.dart` |
| Home's dock, panels and narrow fallback | `app/lib/views/home_view.dart` |
| The navigation rail | `app/lib/views/home_navigation_rail.dart` |
| The shared dock-hosting machinery | `app/lib/views/dock_host.dart` |
| Named layouts, layout files, the switcher and its dialogs | `app/lib/views/dock_layouts/` |
| Operation tab/split layout | `app/lib/views/operation/operation_view_dock.dart` (part of `operation_view.dart`) |
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
