# SVG scene prototype

Status: experimental contract with three independently packaged reference panels.
Their source and tests live in [ham2k/extensions](https://github.com/ham2k/extensions/tree/main/extensions/dashboard);
the paths below are relative to that repository. HaLo retains the renderer, SDK,
CAT adapter and the small SDK sample used by host-only bridge tests.
`extensions/dashboard/svg-weather` fetches and caches real forecasts, resolves
location/units, and builds its entire scene using the host's render environment.
The native Weather and Solar panels remain available for comparison.
`extensions/dashboard/svg-solar` supplies the second real extension reference:
hamqsl indices and band conditions with NOAA flux, Kp and wind history.
`extensions/dashboard/svg-radio` adds the Radio Panel Example reference through a
narrow host adapter to the existing local CAT service. Frequency, mode, power and receive
meter behavior have been exercised against a FLEX-6600 on macOS; other radios
and cross-platform performance still need validation.

## Try it

Use the normal app for feature review. From `app/`, run:

```sh
flutter run -d web-server --web-port 8767 --web-hostname 127.0.0.1 \
  --dart-define=DEV_LABEL="SVG panels" --dart-define=ONBOARD_AS="N0DEV,pota" \
  --dart-define=POLO_OPEN_FIRST_OP=1
```

Open `http://127.0.0.1:8767`, install the externally built `svg-weather` `.h2kext`
package under Settings → Features & Extensions, then add **SVG Weather** through Edit Layout. A blank panel location
follows the operation's exact coordinates (preferred) or grid; a configured grid
or latitude/longitude overrides it. The extension requests Open-Meteo through
`host.fetch`, caches per location/units for fifteen minutes, coalesces concurrent
requests and retries failures no more than once per minute. A failed refresh
retains and visibly marks the last reading. Local inspection never crosses the
bridge. English and Spanish labels follow the current render locale.

Theme, font, locale, safe-area and pane-size changes automatically update a
scene panel's render environment. Use this full app build for iteration and acceptance checks.
The native **Weather** panel is separately available as a layout/data comparison;
its earlier chart-only migration is not the extension reference implementation.

Enable **SVG Solar Weather** in the same settings screen and add it through Edit
Layout. It shows SFI, sunspots, A/Kp, solar wind and day/night band conditions.
Taller panes show NOAA history with local hover, drag and keyboard inspection.
The three charts resolve the selected time to their nearest reading and label
that reading's actual UTC timestamp. Wind is averaged into three-hour UTC buckets;
missing long intervals remain gaps. Each feed preserves its last successful
readings on failure and marks retained chart captions as stale. Refreshes run
every fifteen minutes, primary-source failures retry no faster than once per
minute, and the larger wind history is requested at most every six hours after
success (failed history requests are limited to once per fifteen minutes).

### Isolated diagnostic harness

The standalone preview below is only for repeatable renderer/bridge measurements;
it is not the feature review build.

From `extensions/`, run `npm ci`, then `npm run build`, then leave the sample
being served:

```sh
npm run dev -- --only k2hrc-svg-scenes
```

From `app/`, run:

```sh
flutter run --profile -d macos -t tool/svg_scene_preview.dart
```

The sample is a test fixture: the build writes it to `extensions/build/fixtures/`
rather than into the app's assets, which ship wholesale, so the preview takes it
from the dev server (`--dart-define=SCENE_FIXTURE_URL=…` for another address).

Chrome is also supported (`-d chrome`). For a static web build, add
`--no-tree-shake-icons` because the logger resolves extension icons dynamically. The standalone preview loads the **real
kernel and sample extension**, and uses `ExtensionService`, `PanelService`, and
`ExtensionPanel`. It does not boot the logger or connect to hardware. The sample
fixture is built with the other bundles but into `extensions/build/fixtures/`, so
it is in neither the app's assets nor the installed-extension index. To install it manually in a development build of the logger, build and pack
`extensions/samples/k2hrc-svg-scenes` like any other sample extension.

The preview now opens with the production weather panel beside the simulated
radio. Weather uses an injected, fixed forecast through the real parser/controller;
no live weather or hardware is involved. “Sample weather” switches back to the
extension-only comparison. Automatic benchmarks use the original extension samples.

The preview offers two/eight panels, hide/show, reduced motion, and a ten-second
measurement of p95 Flutter build/raster duration and bridge-call counts. Add
`--dart-define=SVG_SCENE_BENCHMARK=true` to measure two, eight, then hidden panels
automatically. Frame timing availability depends on the Flutter backend; `n/a`
means it supplied no samples. Measure profile mode, not debug/widget-test timing.

## What the prototype establishes

- A versioned, typed JSON scene with bounded artwork, layers, controls, and values.
- Native SVG layers, dynamic numeric text, clamped linear bindings, and transitions
  of rotation, translation, and opacity. Rotation is in degrees; pivots are fractions
  of each layer's rectangle. Layers draw in list order, within a clipped viewBox.
- Rectangular buttons, absolute horizontal sliders, and relative tuning knobs.
  Dragging is in scene coordinates, independent of resizing/letterboxing. Knobs
  combine horizontal and upward travel; their sensitivity is value per scene unit.
- Keyboard arrows and mouse wheel adjust by one step; Shift+arrow adjusts ten.
  Focus outlines and adjustable semantics are provided. Focus traversal follows
  control order. Controls are fixed in scene coordinates, not attached to moving layers.
- Optional local-only controls. Weather inspection updates the cursor and sampled
  temperature text without asking the extension. Text `samples` accepts finite numbers
  or preformatted strings (including localized labels and missing-data markers) and selects the nearest
  clamped array index from its bound value; it is not a general expression evaluator.
  A slider can opt into `discrete` equal-width step buckets and local-only `hover`.
  `valueLabels` supplies accessible descriptions indexed by `(value - min) / step`.
  Hover is rejected on event-producing controls; it cannot dispatch hardware actions.
- Eased transitions and deterministic pulse/flicker run entirely in Flutter.
  Artwork stays a child of animated transforms; XML is not regenerated per frame.
  LED glow uses an SVG radial gradient rather than animated blur filters.
- Dock/app visibility pauses animation ticks; reduced motion disables transitions
  and pulse/flicker. A one-second telemetry trigger is independent of frame cadence.

## Bridge and state contract

`render` returns `{kind: 'svgScene', scene: {version: 1, width, height, values,
layers, controls}, title?, triggers?}`. Ordinary content kinds are unchanged.
See `extensions/sdk/src/svgScene.ts` for the precise experimental schema.

The host adds `instanceId` to render/event arguments. State belongs to the placement,
not the panel descriptor. Interactive controls optionally name an `event`; the host
calls `PanelHook.onEvent({...renderArgs, reason: 'event', event}, ctx)` with control
ID, action, sequence, phase (`activate`, `change` or `commit`), and optional numeric value.
The result is `{values: {...}}`, a patch of declared numeric values.

Controls send commits by default; `continuous: true` also sends coalesced changes
during dragging. Animation frames and local inspection remain in Flutter. One event
is awaited at a time; repeated queued events for a control retain the newest value. Buttons are disabled while an action
is pending. A newer interaction invalidates an older response. In-flight document
renders cannot overwrite completed actions; actions request a budgeted authoritative
refresh. Local inspection values survive those refreshes.

An action failure leaves the panel visible, presents an error, and releases local
optimistic values back to reported state. Timeouts are not cancellation of a command
already sent to hardware; real CAT integration must reconcile against telemetry.
Runtime replacement remounts scene state and invalidates old results. Removal drops
queued actions and ignores late responses.

The radio sample deliberately keeps `requested` and `reported` frequency separate.
It simulates a two-second CAT acknowledgment on subsequent telemetry ticks, offers
external tuning and connection toggles, and rejects tuning when disconnected.
Its knob and slider bind to requested frequency; the needle follows reported
frequency. It sends **no real CAT commands**. LED flicker is explicitly decorative,
not a claim that a radio emitted individual activity events.

## Comparable systems and reuse decision

[Vega signals](https://vega.github.io/vega/docs/signals/) and
[event streams](https://vega.github.io/vega/docs/event-streams/) provide the closest
precedent for chart inspection: graphics react to local interaction state.
[Qt Quick animations](https://doc.qt.io/qt-6/qtquick-statesanimations-animations.html)
provide a precedent for property transitions.

[Rive's Flutter runtime](https://rive.app/docs/runtimes/flutter/flutter) is a viable
candidate for authored animated instruments. The prototype uses flutter_svg because
our panels generate charts from data and extension authors can produce SVG/JSON
without an asset editor. No Rive dependency or performance comparison was added;
a `.riv` adapter remains an option if authored instruments need richer timelines or
state machines. This is an authoring/API assessment, not a benchmark against Rive.

## Next milestones

1. Review this contract against the three reference panels. Resolve responsive
   layouts, theme/localized text, units, screen-reader value formatting, and chart
   series updates before calling the API stable. Preserve no-script/no-network artwork.
2. Continuous controls are implemented with coalescing and final-value delivery.
   Extend command expiry, cancellation and per-control reconciliation; measure
   radio-specific command budgets and test concurrent telemetry.
3. Weather reference implemented in two forms: the native panel uses the scene
   renderer for its chart, and the optional **SVG Weather** extension owns fetching,
   caching, units, responsive layout and scene generation in TypeScript. It uses
   the public render environment for theme and typography. Hover, tap, drag,
   keyboard and screen-reader adjustment inspect hourly columns locally.
4. Solar reference implemented through the same API, including flux/Kp/wind
   charts, band conditions, responsive layouts, caching and partial-feed failures.
   Review both reference panels before extracting shared chart helpers.
5. Radio Panel Example is connected to the designated local radio through the CAT
   adapter, with requested/reported frequency separation, paced continuous tuning,
   a native mode menu, connection control and receive meter. Modern and LCD styles
   support a selected radio per placement. Extend the FLEX-6600 checks to other rigs.
6. Profile the three real panels together across desktop/mobile/web and establish
   supported complexity limits. Hardware coverage beyond the FLEX-6600 remains outstanding.

## Initial measurements and validation (2026-09-17)

Chrome 152 on macOS 26.6.2 / Apple Silicon, Flutter 3.44.6 profile build,
1280×900 CSS viewport, ten-second windows after a three-second warmup:

| Scene load | p95 build | p95 raster | Document renders | Interaction events |
| --- | ---: | ---: | ---: | ---: |
| One radio + one weather chart | 1.2 ms | 0.7 ms | 10 | 0 |
| Four radios + four weather charts | 2.1 ms | 1.6 ms | 40 | 0 |
| Eight panels hidden | — | — | 0 | 0 |

These are local browser measurements, not a cross-device frame-rate guarantee or
native GPU measurements. Browser frame-timing delivery includes a few residual
frames around visibility changes, so hidden-frame percentiles are not meaningful.
An earlier run exposed queued refreshes after hiding; dispatch now checks current
dock visibility and has a regression test. The native macOS profile build was
blocked by Flutter/Xcode's framework architecture check (it reported both `arm64`
and `x86_64` present while rejecting the combined architecture request). No native
performance claim is made.

Validation covers malformed scenes, scaled input, local-only chart inspection,
keyboard changes, stale responses/coalesced final commits, failures, disposal,
reduced motion and hidden tickers. The real bundled JS extension is exercised
through the production service and through a widget gesture. Existing panel
refresh-budget, catalog and per-instance-trigger tests also pass. TypeScript
checks, SDK packaging, sample builds/manifest validation, and sample `.h2kext`
packing pass. The full repository pre-merge gate has not been run.

## Weather integration validation (2026-09-17)

86 targeted Flutter tests pass, covering weather parsing/configuration/fetches,
curve geometry, scene gestures and bridge routing. Added coverage checks hourly
bucket boundaries, hover/tap/keyboard selection, accessible value descriptions,
missing readings, both themes and 2× text. The original small-pane, failed-fetch,
location and hidden-panel regressions still pass. Flutter analysis and extension
TypeScript checking pass. The updated Chrome profile preview builds and renders
successfully; these checks do not constitute cross-platform performance profiling.

## Render environment

`PanelRenderArgs.environment` and `clock` are documented in
[the panel hook contract](../extensions/hooks.md). The renderer is domain-neutral:
all weather fetching, caching, units, condition labels and geometry for **SVG
Weather** live in TypeScript. Font names describe fonts available in the host;
scene text layers render them natively with OS accessibility scaling. SVG artwork
remains vector-only and cannot fetch fonts or other external resources.

The extension, extensions and UI test groups passed (1,996 tests reported by the
workflow runner). After adding an actual weather-bundle widget integration test,
the extension group passed again (329 tests). Targeted Flutter analysis, TypeScript
checking and SDK packaging passed. The real app was checked with SVG Weather
enabled in the operation dock in both light and dark themes; live Open-Meteo data
rendered successfully. The full pre-merge gate and cross-platform profiling remain
outstanding.

## Solar integration validation (2026-09-17)

The extensions and extension-host test groups passed (1,402 tests reported by the
workflow runner), including UTC parsing, day/night band pairing, partial-feed
failures, wind aggregation, cache budgets and newest-point inspection. The actual
Solar Weather bundle renders through the production panel service in a widget
test; inspection sends no extension event or extra fetch. TypeScript checking,
bundle validation and targeted Flutter analysis passed. Live hamqsl indices and
NOAA flux/Kp charts were verified in the real app, with the extension enabled in
the panel picker and added to the operation layout. Full pre-merge validation and
cross-platform profiling are still outstanding.

## Radio integration validation (2026-09-17)

The extensions and extension-host test groups passed (1,410 tests reported by the
workflow runner). Coverage includes paced tuning, designation changes while a
command waits, stale/disconnected/transmitting states, expired telemetry and
confirmed versus requested frequency. A widget gesture exercises the actual
Radio Panel Example bundle through the production panel service and CAT host API.
TypeScript checking, SDK packaging and targeted Flutter analysis passed. The
extension is enabled and added to the real app layout; its disconnected state
renders correctly without scene errors. Physical-radio validation, the full
pre-merge gate and cross-platform performance profiling remain outstanding.
