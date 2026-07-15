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
ideal pane width.** No view invents its own numbers.

| Size | Logical width | Typical device |
|---|---|---|
| **XS** | below 360 | small phones |
| **S** | 360 – 719 | typical phones (360–430) |
| **L** | 720 – 1199 | tablets, small desktop windows |
| **XL** | 1200 and up | large windows, full screens |

There is deliberately **no M**. Between S and L lies the **ideal pane width**
(`idealPaneWidth = 500`) — the width most panes are *designed* for. A window
around that width simply shows one pane at its best size; it isn't a distinct
layout mode. When a view goes two-pane at L, its primary pane sits at the
ideal width by default.

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
| **Home** | Operation list with Quick Lookup below, full width | List + Quick Lookup in a left column (ideal width, resizable); right column shows branding (logo, name, version) on a tinted background |
| **Operation** | Four tabs: QSOs, Spots, Map, Operation | Logging pane on the left (ideal width, resizable); right side tabs: Info, Spots, Map, Operation |
| **Settings** | Settings list; each panel pushes a full screen | Settings list stays as a left column (resizable); selected panel on the right |

Mode switches are **hard cuts within a single build** — a view's `build`
switches on `ShirtSize.of(context)` and returns one arrangement or the
other. Width changes *within* a mode animate (300ms, ease-in-out, via
`ResizableSplitView`).

## Resizable splits

Side-by-side panes are composed with
[`ResizableSplitView`](../../packages/halo_widgets/lib/src/resizable_split_view.dart):
a primary pane with a preferred width, a draggable divider handle, and an
expanding secondary pane. When `secondary` is null the primary fills the
window — pass null on XS/S rather than swapping widget trees, so the primary
subtree stays mounted (scroll positions and in-progress input survive the
flip).

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
    the pane's full bounded height instead of a scroll view.)

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
