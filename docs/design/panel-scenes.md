# Panel scenes

Status: experimental contract with three independently packaged reference panels.
Their source and tests live in [ham2k/extensions](https://github.com/ham2k/extensions/tree/main/extensions/dashboard);
the paths below are relative to that repository. HaLo retains the renderer, SDK,
CAT adapter and the small SDK sample used by host-only bridge tests.
`extensions/dashboard/ki2d-weather-panel` fetches and caches real forecasts, resolves
location/units, and builds its entire scene using the host's render environment.
The native Weather and Solar panels remain available for comparison.
`extensions/dashboard/ki2d-solar-panel` supplies the second real extension reference:
hamqsl indices and band conditions with NOAA flux, Kp and wind history.
`extensions/dashboard/ki2d-radio-panel` adds the radio reference through a
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

Open `http://127.0.0.1:8767`, install the externally built `ki2d-weather-panel`
`.h2kext` under Settings → Extensions & Features, then add **KI2D’s Weather Panel**
through Edit Layout. A blank panel location
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

Enable **KI2D’s Solar Panel** in the same settings screen and add it through Edit
Layout. It shows SFI, sunspots, A/Kp, solar wind and day/night band conditions.
Taller panes show NOAA history with local hover, drag and keyboard inspection.
The three charts resolve the selected time to their nearest reading and label
that reading's actual UTC timestamp. Wind is averaged into three-hour UTC buckets;
missing long intervals remain gaps. Each feed preserves its last successful
readings on failure and marks retained chart captions as stale. Refreshes run
every fifteen minutes, primary-source failures retry no faster than once per
minute, and the larger wind history is requested at most every six hours after
success (failed history requests are limited to once per fifteen minutes).

The `k2hrc-panel-scenes` SDK sample holds a simulated radio, a weather chart, and
a **Native Controls** panel that uses every native kind in a layout. It is a test
fixture: the build writes it to `extensions/build/fixtures/`, outside the app's
assets, which ship wholesale, and only the host's bridge tests load it. To try it in a development build, pack
`extensions/samples/k2hrc-panel-scenes` like any other sample and install the
`.h2kext`.

## What the prototype establishes

- A versioned, typed JSON scene with bounded artwork, layers, controls, and values.
- Native SVG layers, dynamic numeric text, clamped linear bindings, and transitions
  of rotation, translation, scale, and opacity. Rotation is in degrees; rotation and
  scale turn about a pivot given as fractions of each layer's rectangle. Layers draw
  in list order, within a clipped viewBox.
- Rectangular buttons, absolute horizontal sliders, and relative tuning knobs.
  Dragging is in scene coordinates, independent of resizing/letterboxing. Knobs
  combine horizontal and upward travel; their sensitivity is value per scene unit.
  A knob with a second value (`valueY`) splits the axes instead — across sets one,
  up the other — so a passband's shift and width share one patch of artwork. Each
  axis queues on its own, so a diagonal drag sends both rather than the later
  replacing the earlier. A knob's `menu` opens on a click, since a scroll or drag
  is already how it turns.
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
  A scene can be longer than its pane and scrolled by the app (`scroll`): the scroll view is the
  app's own, so momentum, a drag begun on a button and a wheel over anything all work without a
  bridge call, and the extension hears the position once it settles. `fixed` layers and controls
  stay over the pane. Moving the view is the extension's by changing the value; leaving it alone
  in a render leaves the operator's scroll where it is.
  Any drawn control may instead take `hoverSet`, which writes a fixed number into a
  scene value while the pointer is over it and puts the scene's own back when it
  leaves — a highlight, never an event — so a button can still be clicked.
- Eased transitions and deterministic pulse/flicker run entirely in Flutter.
  Artwork stays a child of animated transforms; XML is not regenerated per frame.
  LED glow uses an SVG radial gradient rather than animated blur filters.
- Dock/app visibility pauses animation ticks; reduced motion disables transitions
  and pulse/flicker. A one-second telemetry trigger is independent of frame cadence.

## Bridge and state contract

`render` returns `{kind: 'scene', scene: {version: 1, width, height, values,
strings?, layers, controls, layout?, radio?}, title?, triggers?}`. Ordinary content kinds are
unchanged. `svgScene` is the kind's name through SDK 0.9; hosts read it as `scene`, so
packages built against that SDK — KI2D's three panels among them — keep working.
The reverse does not hold: apps before extension API 5 know only `svgScene`, so
`scene` and everything added with it are API 5, and the SDK deprecates
`svgScene` rather than dropping it.
See `extensions/sdk/src/panelScene.ts` for the precise experimental schema.

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

The simulated radio in the `k2hrc-panel-scenes` sample deliberately keeps
`requested` and `reported` frequency separate. It simulates a two-second CAT acknowledgment on subsequent telemetry ticks, offers
external tuning and connection toggles, and rejects tuning when disconnected.
Its knob and slider bind to requested frequency; the needle follows reported
frequency. It sends **no real CAT commands**; KI2D’s Radio Panel is the one that
does. LED flicker is explicitly decorative,
not a claim that a radio emitted individual activity events.

## Native controls and layout

The drawn controls are hit areas over artwork the extension paints; the
`native…` kinds are Material widgets the app paints and themes, so a panel that
needs a form — a callsign to spot, a band to pick — does not have to draw one.
The public contract is in [the panel hook](../extensions/hooks.md) and
`PanelSceneControl`; the choices behind it:

- **String state is a second map.** `strings` beside `values`, with a key in one
  or the other, so bindings and ramps stay numeric-only and a patch or event
  names a value without saying which map holds it. Toggles (switch, checkbox,
  a chip with a value) stay numbers, 1 or 0.
- **One queue.** Native controls report through the same change/commit pair as
  the drawn ones, so coalescing, the pending state on actions, stale-response
  handling and failure rollback apply to strings unchanged.
- **Typing is local until committed.** A text field's edits are active state —
  a render cannot overwrite them — from the first keystroke to Enter or blur.
  Focus alone is not an edit: clicking into a field and out commits nothing.
- **Placement is a rect or the layout, never both.** A rect places a native
  control over the artwork, scaling with it; the layout places it at true size.
  The layout's vocabulary is Flutter's own (Row, Column, Wrap, Flexible,
  Spacer, SizedBox), checked when the scene is parsed wherever Flutter would
  otherwise assert in layout: `flex` outside a row or column, a control placed
  twice, layers with nowhere to draw. Two traps are absorbed at build time
  instead, since a static check cannot see the constraints: a field with no
  width gets 200, `stretch` on an unbounded cross axis falls back to
  `center`, and a `flex` in a row or column with no room to share is dropped.
- **An action commits pending typing first.** A button tap on touch neither
  blurs the field nor takes focus, so without it an action would reach the
  extension ahead of the text it acts on.
- **Controls can sit among the layers.** A rect-placed control's `after` names
  the layer it paints directly after; without one it paints above them all. A
  field on the control, not an entry in `layers`, so the layer type stays one
  shape for SDK readers. Layers are click-through, because the reason to paint
  over a control is a highlight or a frame, and a hit-testing one would silently
  make the control dead; `blocksPointer` is the opt-in for covering it, and only
  while the layer is visible. A control's `opacity` at 0 removes it from clicks,
  focus and semantics, so an unseen control cannot act.
- **Only a pending action disables action controls.** On desktop, pressing a
  button blurs the text field before the click completes, and the field sends
  its text; if any event in flight disabled buttons, that commit would swallow
  the click it came from.
  The opacity wrappers are present at every value and the Stack's children are
  keyed by id, so fading a control or adding a layer never remounts one mid-edit.
- **Focus follows the Operation view's contract**
  ([logging-fields.md](logging-fields.md)): a text field or dropdown keeps what
  it is given, and a clicked button hands focus back to the callsign field. A
  drawn button takes no focus from a click at all — it has nothing to do with
  keys afterwards. A drawn slider or knob does, because the arrow keys adjust
  it, but only for three seconds after its last click, drag or key; then focus
  goes back where it came from, so a knob nudged with the mouse mid-QSO does not
  catch the operator's next keystrokes. Focus that arrived by Tab is the
  operator's choice and stays.

## Spectrum

A `spectrum` control shows a radio's panadapter and waterfall, painted by the
host from sweeps that never reach the extension
([cat.md § Spectrum](cat.md#spectrum)). It is extension API 6:
an older app does not know the kind and would refuse the whole scene, so a
bundle using it declares `"api": 6` and is refused at install there instead;
`follow`, `span` and label `decimals` are API 7. The public contract
is in [the panel hook](../extensions/hooks.md) and `PanelSceneSpectrum`. The
`k2hrc-panafall` sample uses all of it but those three.

- **A control, not a layer.** It takes clicks, sends events and fills space in
  the layout — all things only controls do here. Layers are click-through
  artwork.
- **The panel must be allowed to read the radio.** The dock hands the scene a
  source only when the extension declares `requiresRadioRead`; without one the
  control says the display is not available. (The same source feeds the
  scene's radio values.) Subscribing to
  the sweeps is what starts the radio's scope, so the control subscribes only
  while its pane and the app are visible.
- **One spectrum per selected radio.** Each control resolves its spectrum
  from its radio ID, including logical receivers that share a physical radio.
  Receiver-specific CAT state supplies its marker and tuning target. Stable
  control IDs retain separate waterfall histories when layout slots change;
  an opacity-zero slot stops demand while preserving its history. Changing
  the source or radio clears that history.
- **Display settings are the host's; scope settings are the radio's.**
  Averaging, frame rate, waterfall pace, colors, the gap, labels, overlays and
  annotations are applied after a sweep arrives and mean the same on every
  radio. Span, reference level, center/fixed mode and sweep speed belong to the
  radio and go through `setRadioSpectrum`.
- **Every number may name a scene value.** The control reads it on each sweep,
  so a slider with no `event` retunes contrast, averaging or an overlay's edge
  with no bridge call. `hoverHz`/`hoverDb` work the other way: the pointer
  writes them, and they survive a document refresh, for a text layer to show.
- **Three painters, three paces.** The panadapter repaints at `fps`; the
  waterfall per row, at `waterfallSpeed` — a row keeping the loudest reading
  since the last, so a short signal still marks a slow waterfall; labels,
  ticks and annotations with the panadapter. Waterfall rows are colored as
  they arrive, so a contrast change affects rows from then on.
- **A waterfall row keeps its frequencies.** Each row remembers the range it
  was taken over and is drawn where that range sits in the window shown now:
  a retune slides the history sideways and a span change stretches it, with
  what falls off the window clipped. Redrawing old rows edge to edge would put
  a signal heard a minute ago at a frequency it was never on. For the same
  reason a row's peak-hold restarts when the range changes — a bin of another
  range is another frequency.
- **`span` crops, it does not ask.** A radio's scope comes in a few widths
  (a Flex's DAX IQ in four); `span` cuts each sweep to the middle that many Hz,
  whole bins only, before anything else sees it, so trace, waterfall, labels,
  clicks and `follow` all work on the window shown. Setting the radio's scope
  to the narrowest width that covers it stays the extension's job.
- **`follow` moves the shared window, minimally.** With `follow` set, a tuned
  frequency that comes within that share of the width of either edge — or
  leaves the window — moves the radio's scope just far enough to put it back
  on that margin, at most four moves a second: the window catches up over a
  few sweeps, and a move sent on each of them would overshoot. Within the
  margins (between 15% and 85% of the width at `follow: 0.15`) nothing moves,
  so the picture scrolls with the dial rather than jumping to recentre on
  every step. It applies only where the radio lets the app place its scope
  (`SpectrumCapabilities.canRecenter`, a FlexRadio) and the panel may command
  the radio (`requiresRadioWrite`). On a Flex the scope is the slice's pan,
  which SmartSDR shows too, so following moves the operator's own panadapter
  there as well — the same window everywhere, rather than HaLo's view
  disagreeing with the radio's.
- **Overlays sit relative to the tuned frequency, the sweep's middle, or
  nothing.** On a Flex the panadapter is not centered on its slice, which is
  why `center` exists. On the panadapter an area is drawn behind the trace and
  a line in front of it unless `behind` — which absolute overlays, scenery
  such as a band edge, default to. On the waterfall everything is drawn over
  the rows, since nothing under them would show.
- **The scale is a gap plus a layer.** The gap's fill and borders sit between
  the panadapter and the waterfall; labels and ticks are drawn over the whole
  control so an `offset` can put them anywhere, measured from the panadapter's
  base. A label that would touch the last one is skipped, so a narrow pane
  shows every other label rather than a run of digits.
- **One layout, four flows.** `flow` turns the whole control: the panadapter,
  gap and waterfall are laid out as if the waterfall moved down, and one
  matrix mirrors that for `up` or turns it a quarter for `right` and `left`,
  where frequency rises up the screen. Lines, fills and rows are drawn through
  the matrix; text is not — a label's or an annotation's box is mapped, and
  the text set upright in it — so offsets and pointer corners keep their
  meaning in every flow. Clicks and the pointer go back through the same
  mapping.
- **Clicks.** A click tunes — a `commit` with the frequency as `value`, rounded
  to `tuneStep` — unless it lands on an annotation with an `event`, which sends
  `activate` with its frequency and its `annotation` id instead. Each
  annotation's clicks queue on their own, so a spot clicked while a tune is in
  flight is not replaced by the next click on the control.

## Radio values

A scene with a `radio` block (extension API 7) is fed one radio's readings —
its meters, `radio.transmitting`, `radio.swrAverage` and
`radio.secondsSinceTransmit` (`sceneRadioValues` in `scene_model.dart`) — by
the host, into values its bindings and text read like any other.

- **Why the host feeds them.** An extension renders at most once a second, and
  a meter that moves once a second is not a meter. The radio reports several
  times a second; the host writes those readings straight from CAT into the
  scene's values, so a needle or a bar moves at the radio's rate with no
  render and nothing crossing the bridge. It listens to
  `CatService.meterReadings`, which fires on every reading — the receive
  signal included, which the service's own notification deliberately skips —
  so only a scene that asks for the values pays for them.
- **Reserved names, no writes.** The names are the host's: a scene declaring
  one is refused, no control may bind one, and they exist only in a scene
  with the block. That keeps a patch or an event from fighting the feed over
  a value.
- **A missing reading is negative infinity**, never NaN or a stale number: a
  binding clamps it to the bottom of its range — a needle at rest, a bar
  empty — and text shows `—`. Readings expire as the CAT layer's do
  ([cat.md § Telemetry](cat.md#telemetry-what-the-radio-is-doing)).
- **Time since a transmission is a value too**, so a scene can hold the last
  over's SWR on screen and fade it, with no timer of its own. Nothing reports
  while the radio is idle, so for fifteen seconds after a transmission the
  scene re-reads it four times a second; with no transmission yet it reads as
  a very long time, so a hold is over rather than pending. It counts in real
  time: developer time travel does not age an over that just ended.
- **The same gate as the spectrum.** The values come through the source the
  dock hands a panel that declares `requiresRadioRead`; without one every
  reading is missing.

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

The three reference panels are complete: weather, solar, and radio, each with
responsive layouts from the render environment, English and Spanish text, and
cached or reconciled state. What remains before the contract stops being
experimental:

1. **Publish the reference panels.** They install only from a file and are in no
   catalog. Build 170 is the first release whose host supports them; older hosts
   show an unavailable message.
2. **Settle the schema.** Document the limits the parser enforces
   (`scene_model.dart`) in the public contract. Decide whether charts need a series
   patch: `onEvent` and triggers patch only numeric values, so any change to a
   chart's data re-renders the whole scene. Weather and solar each carry their own
   `svg()`/`sample()` helpers; extract shared chart helpers, or decide not to. Give
   the radio knob `valueLabels`: a screen reader announces its raw number.
3. **Own the command lifecycle, or say the extension does.** The host has no
   command expiry or cancellation. An event is bounded only by the hook budget, and
   `setRadio` calls queue behind a 250 ms pace with no expiry, so a queued tune
   can reach the rig after the panel has shown the action failing. Reconciliation
   of requested against reported state exists only inside the radio panel
   (unconfirmed after five seconds), not as a host facility.
4. **Hardware and platforms.** Radio reads, tuning, and mode changes are verified
   on a FLEX-6600 (firmware 4.2.20) on macOS only. Exercise other rigs and the
   other platforms. The Flex meter socket opens for every connected Flex, whether
   or not a panel reads `signalDbm`.
5. **Profile** the three panels together on desktop, mobile and web, in profile
   builds of the app, and set supported complexity limits from the results.

## Initial measurements and validation (2026-09-17)

Chrome 152 on macOS 26.6.2 / Apple Silicon, Flutter 3.44.6 profile build,
1280×900 CSS viewport, ten-second windows after a three-second warmup, taken with
a standalone preview harness that no longer exists. Measuring again means a
profile build of the app with the panels placed in a layout:

| Scene load | p95 build | p95 raster | Document renders | Interaction events |
| --- | ---: | ---: | ---: | ---: |
| One radio + one weather chart | 1.2 ms | 0.7 ms | 10 | 0 |
| Four radios + four weather charts | 2.1 ms | 1.6 ms | 40 | 0 |
| Eight panels hidden | — | — | 0 | 0 |

These are local browser measurements, not a cross-device frame-rate guarantee or
native GPU measurements. Browser frame-timing delivery includes a few residual
frames around visibility changes, so hidden-frame percentiles are not meaningful.
Dispatch checks current dock visibility, so a hidden panel queues no refreshes; a
regression test holds it. No native measurement has been taken, so no native
performance claim is made.

Validation covers malformed scenes, scaled input, local-only chart inspection,
keyboard changes, stale responses/coalesced final commits, failures, disposal,
reduced motion and hidden tickers. The real bundled JS extension is exercised
through the production service and through a widget gesture. Existing panel
refresh-budget, catalog and per-instance-trigger tests also pass. TypeScript
checks, SDK packaging, sample builds/manifest validation, and sample `.h2kext`
packing pass.

## Weather integration validation (2026-09-17)

86 targeted Flutter tests pass, covering weather parsing/configuration/fetches,
curve geometry, scene gestures and bridge routing. Added coverage checks hourly
bucket boundaries, hover/tap/keyboard selection, accessible value descriptions,
missing readings, both themes and 2× text. The original small-pane, failed-fetch,
location and hidden-panel regressions still pass. Flutter analysis and extension
TypeScript checking pass. The Chrome profile build rendered the panels
successfully; these checks do not constitute cross-platform performance profiling.

## Render environment

`PanelRenderArgs.environment` and `clock` are documented in
[the panel hook contract](../extensions/hooks.md). The renderer is domain-neutral:
all weather fetching, caching, units, condition labels and geometry for **KI2D’s
Weather Panel** live in TypeScript. Font names describe fonts available in the host;
scene text layers render them natively with OS accessibility scaling. SVG artwork
remains vector-only and cannot fetch fonts or other external resources.

The extension, extensions and UI test groups passed (1,996 tests reported by the
workflow runner). After adding an actual weather-bundle widget integration test,
the extension group passed again (329 tests). Targeted Flutter analysis, TypeScript
checking and SDK packaging passed. The real app was checked with KI2D’s Weather Panel
enabled in the operation dock in both light and dark themes; live Open-Meteo data
rendered successfully.

## Solar integration validation (2026-09-17)

The extensions and extension-host test groups passed (1,402 tests reported by the
workflow runner), including UTC parsing, day/night band pairing, partial-feed
failures, wind aggregation, cache budgets and newest-point inspection. The actual
KI2D’s Solar Panel bundle renders through the production panel service in a widget
test; inspection sends no extension event or extra fetch. TypeScript checking,
bundle validation and targeted Flutter analysis passed. Live hamqsl indices and
NOAA flux/Kp charts were verified in the real app, with the extension enabled in
the panel picker and added to the operation layout.

## Radio integration validation (2026-09-17)

The extensions and extension-host test groups passed (1,410 tests reported by the
workflow runner). Coverage includes paced tuning, designation changes while a
command waits, stale/disconnected/transmitting states, expired telemetry and
confirmed versus requested frequency. A widget gesture exercises the actual
radio bundle through the production panel service and CAT host API.
TypeScript checking, SDK packaging and targeted Flutter analysis passed. The
extension is enabled and added to the real app layout; its disconnected state
renders correctly without scene errors. Against a FLEX-6600 (firmware 4.2.20) on
macOS, the packed panel read the rig's frequency and mode through the real
runtime, tuned it and restored it; with `requiresRadioWrite` removed from the
manifest, the same chain was refused at `listRadios` and the rig never moved.
