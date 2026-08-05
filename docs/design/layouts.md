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
  layout (`DockLayoutView`, behind the `layouts` experiment). Currently
  only the **Operation** view. All its dividers — the fixed split's and the
  dock's — use the **solid** style below.
- **`fixed`** — the arrangement never changes (Home, Settings). Fixed
  views may opt their splits into the **surfaces** divider style.

## Resizable splits

Side-by-side panes are composed with
[`ResizableSplitView`](../../packages/halo_widgets/lib/src/resizable_split_view.dart):
a primary pane with a preferred width and an expanding secondary pane,
separated by one of two divider styles (`SplitDividerStyle`):

**Solid (the default).** A header-colored bar
([`SolidPaneDivider`](../../packages/halo_widgets/lib/src/pane_divider.dart),
`paneDividerWidth` wide) that owns its own layout space — no overlay, no
drop shadow. It reads as chrome between panes, matching the app bar's
surface, and it is the shared divider language of layout-customizable
views: the dock layout's split dividers are the same widget, so the fixed
split and the dock can't drift apart visually. Being an opaque painted
bar, it needs no special handling over native platform views.

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
