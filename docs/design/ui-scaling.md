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
([`app/lib/main.dart`](../../app/lib/main.dart) — search `UiScale(`)). It wraps
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
   clearance (see below) and the split divider's device-pixel-grid snapping
   (`resizable_split_view.dart` — scale-neutral rounding, not a hand-scaled
   dimension). Reaching for it anywhere else is almost certainly rule 1's
   bug.

Text and vector icons stay crisp at any scale: Flutter records the scene as
vector drawing commands and rasterizes *after* the transform, so glyphs and
shapes are re-rendered at the effective pixel size.

> **Why `FittedBox`, not a bare `Transform.scale`?** The window hands down
> *tight* constraints. A plain `Transform` passes those straight through, so a
> `SizedBox(width: size/scale)` inside it would be forced back to full size and
> nothing would actually scale. `FittedBox` lays its child out at its natural
> (divided) size under loose constraints first, *then* scales. This was a real
> bug in the first draft; there's a widget test guarding it
> (`app/test/font_scale_test.dart`, "UiScale scales the whole subtree").

---

## Rules for future changes

**1. Never scale dimensions by hand.** Do **not** multiply sizes, paddings,
font sizes, or icon sizes by the font scale anywhere in widget or theme code.
`UiScale` already scales the whole tree; a second `* scale` **double-scales**
that element and reintroduces exactly the proportion drift this design
eliminates. If you find yourself reaching for `settings.fontScale.scaleFactor`
in a layout, stop — that's the bug. (The setting is read in exactly one place:
`main.dart`'s builder, to feed `UiScale`.)

**2. Write everything in plain logical pixels.** A row that should be 44pt tall
is `height: 44`. It will render at `44 * scale` on screen. That's the whole
contract.

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
Raster PNGs (e.g. the home-screen logo) and native platform views (the Mapbox
webview) are scaled as bitmaps, so they can soften at large scale. If a raster
asset needs to stay razor-sharp, ship it as SVG or at higher resolution — do
**not** try to counter-scale it.

**6. Any new top-level AppBar on macOS needs traffic-light clearance.** See the
next section — this is the one place scaling interacts with native chrome.

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

**Whenever you add an AppBar that can be a top-level route on macOS, reserve
the clearance:**

```dart
AppBar(
  leadingWidth: macOSAwareLeadingWidth(context),   // null off macOS
  leading: macOSAwareBackButton(context),          // plain BackButton off macOS
  title: Text(...),
)
```

For a non-back leading widget (e.g. a `CloseButton`), pad it with
`macOSTrafficLightClearance(context)` guarded by `isMacOSChromelessWindow`. A
missing reservation shows up as the back arrow / logo sitting *under* the
traffic lights — most visible at large font scales, where the layout reflows to
narrow and previously-unreached pushed AppBars appear.

---

## Where the pieces live

| Piece | File |
|---|---|
| The scaling widget | `packages/halo_widgets/lib/src/ui_scale.dart` |
| Applied once at the root | `app/lib/main.dart` (`MaterialApp.builder`) |
| Font-scale factors | `app/lib/services/settings_service.dart` (`enum FontScale`) |
| macOS traffic-light clearance helpers | `packages/halo_widgets/lib/src/platform_chrome.dart` |
| macOS header-height bridge (Dart) | `app/lib/services/window_chrome_service.dart` |
| macOS header-height + button positioning (native) | `app/macos/Runner/MainFlutterWindow.swift` |
| Tests | `app/test/font_scale_test.dart` |

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
