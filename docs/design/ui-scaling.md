# Interface Scaling (Font Scale)

The **Font Scale** setting (Settings → General) scales the *entire* interface —
text, icons, controls, list rows, headers, padding, borders, gaps — by one
uniform factor. It is not a text-only setting; it is a whole-UI zoom.

This document explains how that works and, more importantly, the small set of
rules that keep it working. **Read this before touching anything scaling-,
layout-, or macOS-window-adjacent.**

---

## The one idea

**Scale once, at the root. Everything else is written in plain logical
pixels and scales for free.**

There is exactly one scaling primitive:
[`UiScale`](../../packages/halo_widgets/lib/src/ui_scale.dart), applied once in
`MaterialApp.builder`
([`app/lib/views/app_shell/halo_app.dart`](../../app/lib/views/app_shell/halo_app.dart) — search `UiScale(`)). It wraps
the whole app. Everything below it lives in a single **logical coordinate
space** that is the real window divided by the scale factor, and a transform
paints that space back up to fill the window.

Because everything the app draws lives in that one logical space:

- Every dimension you write in ordinary widget code (`SizedBox(height: 12)`,
  `EdgeInsets.all(8)`, a `Divider`, a custom row height, an icon size) scales
  automatically and by exactly the same factor as everything else.
- Proportions can never drift, because there is only one factor.
- New widgets need **zero** scaling awareness. Write plain Flutter.

## How `UiScale` works

1. It reads the real `MediaQuery` and produces a copy whose `size` and insets
   (`padding`, `viewInsets`, `viewPadding`, `systemGestureInsets`) are
   **divided** by the scale. Children therefore lay out as if the screen were
   `size / scale` logical pixels.
2. It wraps the child in a `FittedBox(fit: BoxFit.fill)` sized to that divided
   size, which scales the painted result back up to fill the real window. The
   fill factor works out to exactly the scale factor.
3. It publishes the scale to descendants via an inherited widget, read with
   `UiScale.of(context)`. Only two things need it: the macOS traffic-light
   clearance (see below) and `PixelGrid` (below — scale-neutral rounding, not
   a hand-scaled dimension). Reaching for it anywhere else is almost certainly
   rule 1's bug.

Text and vector icons stay crisp at any scale: Flutter records the scene as
vector drawing commands and rasterizes *after* the transform, so glyphs and
shapes are re-rendered at the effective pixel size.

> **Why `FittedBox`, not a bare `Transform.scale`?** A plain `Transform` passes
> the incoming tight constraints straight through, so a
> `SizedBox(width: size/scale)` inside it would be forced back to full size and
> nothing would actually scale. `FittedBox` lays its child out at its natural
> (divided) size under loose constraints first, *then* scales. This was a real
> bug in the first draft; there's a widget test guarding it
> (`app/test/settings/font_scale_test.dart`, "UiScale scales the whole subtree").
>
> **Why the `SizedBox.expand` around it?** `FittedBox` only scales up to the
> constraints it is *given*. Handed loose ones it shrink-wraps instead, and the
> mechanism degrades silently: the subtree still lays out in the divided space —
> so the UI reflows to narrower breakpoints — but is never magnified. That looks
> exactly like "the layout changes but the fonts don't". The failure is
> **asymmetric**, which is why it survived review and a passing guard test:
> below 1.0 the child is *larger* than the window and gets clamped, so scaling
> down keeps working. Expanding first makes `UiScale` independent of whatever
> constraints its parent happens to pass (the app root is a `Stack`, which is
> loose by default). Guarded by "UiScale magnifies under LOOSE constraints".

---

## Rules for future changes

**1. Never scale dimensions by hand.** Do **not** multiply sizes, paddings,
font sizes, or icon sizes by the font scale anywhere in widget or theme code.
`UiScale` already scales the whole tree; a second `* scale` **double-scales**
that element and reintroduces exactly the proportion drift this design
eliminates. If you find yourself reaching for `settings.fontScale.scaleFactor`
in a layout, stop — that's the bug. (The setting is read in exactly one place:
`halo_app.dart`'s builder, to feed `UiScale`.)

**2. Write everything in plain logical pixels.** A row that should be 44pt tall
is `height: 44`. It will render at `44 * scale` on screen. That's the whole
contract. Which logical pixels a *padding, margin or gap* may use is a
separate question with its own answer — the seven `Space` rungs
([user-interface.md § Spacing](user-interface.md#spacing)). Sizes like that
44pt row are not on that ladder and don't belong on it.

**3. Do not override `MediaQuery.textScaler` for the app font scale.** Text
scales via the transform, along with everything else. (There used to be a
`RelativeTextScaler`; it's gone, and re-adding it would double-scale text.) The
OS accessibility text-scale preference still composes on top — that's
intentional.

**4. Responsive breakpoints read the divided width — by design.**
`ShirtSize.of(context)` ([layouts.md](layouts.md), the one breakpoint
vocabulary — don't invent per-view width checks) reads `MediaQuery.sizeOf`,
which sees the *scaled* logical width, so a larger font scale reflows to
narrower layouts sooner (genuinely less fits on screen). This is the
behavior you want. Only if a specific check must key off the *physical*
window regardless of zoom — a deliberate, rare exception — read
`View.of(context).physicalSize / devicePixelRatio` for that one check, and
comment why.

**5. Raster images and platform views scale as textures.** Vector content
(text, MDI/FontAwesome glyphs, `Icon`s, `CustomPaint`) re-rasterizes crisply.
Raster PNGs (e.g. the home-screen logo) and native platform views (the map
webview) are scaled as bitmaps, so they can soften at large scale. If a raster
asset needs to stay razor-sharp, ship it as SVG or at higher resolution — do
**not** try to counter-scale it.

**6. One pane at a different scale uses `SubtreeUiScale`, never a nested
`UiScale`.** A layout-customizable view lets an operator set a font size for
one pane ([layouts.md](layouts.md)), which is the one legitimate departure
from "scale once at the root" — and it is still not a hand-multiplied
dimension: the pane simply lives in a coordinate space scaled once more, with
everything inside it in plain logical pixels. `UiScale` itself cannot do this.
It sizes its inner box to the ambient MediaQuery — the WINDOW — and lets
`BoxFit.fill` stretch that box to the constraints it is given; at the root
those agree, and inside a pane they do not, so the two axes stretch by
different factors and a square comes out a rectangle. `SubtreeUiScale`
measures the incoming constraints instead, and takes the ABSOLUTE level so no
caller has to know what is already in force.

**7. Any new top-level AppBar needs window-chrome clearance.** macOS reserves
LEADING space for the native traffic lights; Windows reserves TRAILING space
for the Flutter-drawn caption buttons. See the next section — this is the one
place scaling interacts with window chrome.

---

## Hairline seams: `PixelGrid`

Scaling has one visual side effect. Inside the scaled space, one logical pixel
paints as `UiScale × devicePixelRatio` device pixels — a *fractional* step at
most font scales (0.85 × 2.0 = 1.7). A boundary between two differently
colored surfaces that lands *between* device pixels is antialiased into both,
and the blended pair reads as a **hairline gap** — most visibly along the
dividers between panes.

[`PixelGrid`](../../packages/halo_widgets/lib/src/ui_scale.dart) is the one
primitive for this: `PixelGrid.of(context).snap(x)` rounds a value to whole
device pixels (`snapDown` / `snapUp` for values that must not exceed a cap, or
must stay at least one device pixel thick).

Two rules when using it:

- **Snap boundary POSITIONS, not extents.** An extent snapped on its own still
  starts off-grid if the element before it did. Walk a run cumulatively, snap
  each edge, and take each child's extent as the difference between its two
  snapped edges (`DockLayoutView._buildSplit` is the reference implementation).
  Leave the run's own trailing edge at exactly the incoming extent — snapping
  it can only open a real gap.
- **Snap both edges of a separator.** A divider of a fixed logical width has an
  off-grid *far* edge even when its near edge is snapped, which seams it
  against the next pane just the same (`SolidPaneDivider.extent`).

The AppBar is snapped **once, app-wide**: `halo_app.dart`'s builder rounds the
theme's `toolbarHeight` to the grid and pushes it into an overriding `Theme`,
so every header in the app inherits an on-grid bottom edge instead of each
view having to remember. That snapped height is also what
`WindowChromeService.reportTitleBarHeight` reports, so the macOS traffic
lights stay centered in the height the headers actually render at. The status
bar snaps its own height for the same reason (its top edge is the boundary;
its bottom is the window edge, always on-grid).

This is not a licence to snap every dimension — only boundaries where two
surfaces meet, and thin lines that must paint crisply. Ordinary padding and
sizes stay plain logical pixels (rule 2).

---

## macOS traffic lights: the one thing that must NOT scale

The macOS window's close/minimise/zoom buttons are **native, fixed-size system
controls** floating over the app's own AppBar (the window is chromeless — see
[`platform_chrome.dart`](../../packages/halo_widgets/lib/src/platform_chrome.dart)
and `macos/Runner/MainFlutterWindow.swift`). They do **not** scale with the UI,
and they shouldn't — users expect them at the standard size.

Two consequences:

- **Vertical centering.** Flutter is the single source of truth for the header
  height and pushes it (`base AppBar height * scale`) to the native window over
  the `ham2k/window_chrome` channel
  ([`WindowChromeService`](../../app/lib/services/window_chrome_service.dart));
  the native side centers the buttons in that height. The native code does
  **not** re-derive the height from the font-scale setting — don't reintroduce
  that coupling.

- **Horizontal clearance is fixed *physical*.** The AppBar leading content
  (logo, back button) must not slide under the fixed buttons. Because the
  AppBar lives inside the scaled space, its clearance is expressed as
  `macOSTrafficLightClearance(context)` = `(inset + gap) / UiScale.of(context)`
  — dividing by the scale so it renders at a constant on-screen size that
  clears the buttons at *every* scale. A raw constant would scale with the UI
  and overlap the buttons at small scales.

**Whenever you add an AppBar that can be a top-level route, reserve the
clearance on BOTH edges:**

```dart
AppBar(
  flexibleSpace: windowHeaderGestureArea(),        // drag / double-click chrome
  leadingWidth: macOSAwareLeadingWidth(context),   // null off macOS
  leading: macOSAwareBackButton(context),          // plain BackButton off macOS
  title: Text(...),
  actions: [..., windowsCaptionSpacer(context)],   // zero-width off Windows
)
```

For a non-back leading widget (e.g. a `CloseButton`), pad it with
`macOSTrafficLightClearance(context)` guarded by `isMacOSChromelessWindow`. A
missing reservation shows up as the back arrow / logo sitting *under* the
traffic lights — most visible at large font scales, where the layout reflows to
narrow and previously-unreached pushed AppBars appear.

**Windows scales the OTHER way — deliberately.** The Windows build is also
chromeless (`windows/runner/win32_window.cpp`), but its caption buttons are
**Flutter-drawn** (`WindowsCaptionButtons`, overlaid at the app root), not
native controls — so unlike the traffic lights they simply scale with the UI
like any other widget, and `windowsCaptionClearance` is a plain logical
constant with **no** `/ UiScale` division. Don't "fix" either side to match
the other: physical-size math is only for clearing controls Flutter doesn't
draw.

---

## Where the pieces live

| Piece | File |
|---|---|
| The scaling widget, and `PixelGrid` | `packages/halo_widgets/lib/src/ui_scale.dart` |
| Applied once at the root | `app/lib/views/app_shell/halo_app.dart` (`MaterialApp.builder`) |
| Font-scale factors | `app/lib/services/settings_service.dart` (`enum FontScale`) |
| Window-chrome clearance helpers, caption buttons, header gestures | `packages/halo_widgets/lib/src/platform_chrome.dart` |
| Window-chrome bridge (Dart, both platforms) | `app/lib/services/window_chrome_service.dart` |
| macOS header-height + button positioning (native) | `app/macos/Runner/MainFlutterWindow.swift` |
| Windows custom frame + resize/min-size handling (native) | `app/windows/runner/win32_window.cpp` |
| Windows window-chrome channel (native) | `app/windows/runner/flutter_window.cpp` |
| Tests | `app/test/settings/font_scale_test.dart`, `packages/halo_widgets/test/platform_chrome_test.dart` |

## How to verify a change

Run the app on macOS (or any desktop) and cycle Font Scale across
Smallest ↔ Largest. Confirm:

- The whole UI scales in proportion — rows, buttons, inputs, headers, spacing —
  not just text.
- Text and icons stay crisp.
- Layouts reflow at breakpoints (e.g. Settings goes single-column at large
  scales) and back.
- On macOS, the traffic lights stay vertically centered in the header and the
  leading content clears them at every scale, including on pushed views.
