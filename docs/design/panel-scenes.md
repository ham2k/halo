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
  in list order, within a clipped viewBox. The whole scene, laid-out controls
  included, stops at its pane, so nothing a control draws past its slot paints
  over the pane beside it.
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
  A button with `tapAt` says where it was clicked: the event's `value` is the click's
  place along its longer side, 0 at its top or left and 1 at its bottom or right, so a
  scale tunes to the frequency under the pointer. Keys and screen readers send none.
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
The public contract is in [panel scenes](../extensions/scenes.md) and
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
- **`when` is an opacity gate, not a second visibility.** A failing condition
  reads as opacity 0 through `opacityAt`, so every path that already treats 0
  as gone — hit-testing, `blocksPointer`, focus, a band scope's demand —
  treats a hidden piece the same without learning a new rule. Its test is
  checked against the value's kind when the scene is parsed, the one place that
  knows whether a name is a number or a string.
- **The radio's values are the host's alone.** An `onEvent` answer naming one
  is ignored: patched, the readout would show a dial the radio is not on until
  its next reading. The dial values follow `readRadio()`'s rules for what a
  radio that is not live still shows, so a scene and the render beside it
  never disagree.
- **Named sources are the `radio` block, several times over.** A board shows
  two radios, a rotator and a switch at once, and the single `radio` block
  could feed one. Each source's readings land under its name by the same
  path, through the same `SceneSpectrumSource` the panel's radio grant hands
  the scene, which gives equipment readings beside the radio's as
  `listEquipment` describes them. The view fills only the names the scene
  reads, collected when it is parsed, so a switch port the scene names but
  the switch lacks is a missing reading rather than a crash at the first
  binding to look it up.
- **A reveal is a clip, not a scale.** `scaleX` squashes a bar of LED
  segments into narrower segments; `clipX` shows the segments whole, as many
  as the reading reaches. Stepping a segment at a time is `scale` and
  `truncate` on the binding, rather than a second way to quantise, with an
  `offset` first so the steps count from the ramp's own bottom: truncated
  from zero, -130 dBm in 10-dB segments lights two thirds of one.
- **A peak hold lives in the layer, on a ticker that stops.** A held peak is
  state over time, so the layer keeping it owns a ticker, running only while
  a held value stands above the live one; the hold counts from the last
  moment the reading was at its peak, which keeps a steady reading from ever
  starting it. A control's opacity may not hold: a control lingering visible
  after its reading fell would still take clicks.
- **Only a pending action disables action controls.** On desktop, pressing a
  button blurs the text field before the click completes, and the field sends
  its text; if any event in flight disabled buttons, that commit would swallow
  the click it came from.
  The opacity wrappers are present at every value and the Stack's children are
  keyed by id, so fading a control or adding a layer never remounts one mid-edit.
- **Focus follows the Operation view's contract**
  ([logging-fields.md](logging-fields.md)): a text field or dropdown keeps what
  it is given, and a clicked button hands focus back to the callsign field. A
  drawn control, button, slider or knob, takes no focus from a click or a drag
  at all. A scene is worked mid-QSO, and a control holding the focus even
  briefly catches the operator's next keystrokes, meant for the callsign. The
  arrow keys adjust a slider or knob reached by Tab, which is the operator's
  choice and stays; the wheel adjusts one with no focus.
- **In a grid that scrolls, a drag begun on a cell's slider or knob is the
  control's.** A plain pan claims a drag only past twice the distance a
  scroll view's drag needs, so the grid would win every one. The cell's pan
  accepts at the scroll's own distance and, deeper in the hit path, hears each
  move first, at the device's own slop as the scroll view has it. A slider
  claims only a drag that goes mostly across, its one axis: a swipe down the
  board that happens to start on a meter is a scroll, and claimed, it would
  set the meter to wherever the finger landed. A disabled control claims
  nothing, and a trackpad's two-finger swipe is always the scroll's. A scene
  `scroll` keeps the opposite rule, its documented one: a drag along it is
  the scroll's.

## Band scope

A band scope (`bandScope`, `spectrum` before API 17) shows a radio's spectrum
and, under it, its waterfall, painted by the host from sweeps that never reach
the extension ([cat.md § Spectrum](cat.md#spectrum)). It is extension API 6:
an older app does not know the kind and would refuse the whole scene, so a
bundle using it declares `"api": 6` and is refused at install there instead;
`follow`, `span` and label `decimals` are API 7. The public contract
is in [panel scenes](../extensions/scenes.md#band-scope) and `PanelSceneSpectrum`. The app's own
Band Scope (`extensions/core/band-scope`) is the reference panel; it leaves the
gestures to the host and takes its settings from the pane's form.
The names are the operator's: the band scope is the whole control, and its
spectrum and waterfall its two parts. `spectrum` stays the kind's alias and
`pan` the spectrum's in every field that took it before API 17, since
published panels name them; what API 17 added has the new names only.

- **A control, not a layer.** It takes clicks, sends events and fills space in
  the layout — all things only controls do here. Layers are click-through
  artwork.
- **The panel must be allowed to read the radio.** The dock hands the scene a
  source only when the extension declares `requiresRadioRead`; without one the
  control says the display is not available. (The same source feeds the
  scene's radio values.) Subscribing to
  the sweeps is what starts the radio's scope, so the control subscribes only
  while its pane and the app are visible.
- **One band scope per selected radio.** Each control resolves its sweeps
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
  writes them, and they survive a document refresh, for a text layer to show;
  so do `widthHz`, `stepHz` and `vfoHz`, which the control writes with the
  width it shows, a click's step and its radio's dial. The dial is per
  control rather than the scene's `radio.frequencyHz` because a panel showing
  two receivers has one `radio` block and two dials.
- **Three painters, three paces.** The spectrum repaints at `fps`; the
  waterfall per row, at `waterfallSpeed` — a row keeping the loudest reading
  since the last, so a short signal still marks a slow waterfall; labels,
  ticks and annotations with the spectrum. Waterfall rows are colored as
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
  why `center` exists. On the spectrum an area is drawn behind the trace and
  a line in front of it unless `behind` — which absolute overlays, scenery
  such as a band edge, default to. On the waterfall everything is drawn over
  the rows, since nothing under them would show.
- **The trace's look by level and by range** (API 17). Colors by level are
  stops spread up the spectrum's height rather than along the trace, so a
  level keeps its color however the floor and range move, and the same
  stops serve the trace and its fill. A stop may name its level instead, by
  the noise or the spectrum's edges as a layer's coordinates do, so a scene
  can color what stands over the noise on any radio without knowing its
  scale. An overlay area can give the trace and
  fill a look of their own over its frequencies — the passband, a segment —
  drawn by clipping one trace to each range, so the line stays one line
  across the edges; a look on a line or the tuned-frequency line has no
  width of frequencies to cover, and is refused. Smoothing is the control's
  alone, a trace smoothed in one range only would bend at its edges, and it
  shapes only the drawing: hover, the noise and the waterfall read the
  sweep as it came.
- **Layers are the band scope's, not the scene's** (API 17). A scene layer sits
  at scene coordinates, but a band scope placed by a `layout` has none, and its
  window moves under any fixed position with every pan, zoom and glide — so
  what a scene places by frequency is a list on the control, drawn by it,
  clipped to it, turned with it, and repainted with the spectrum rather
  than rebuilt. A coordinate is a frequency plus pixels: Hz that move with
  the zoom and pixels that do not, so one item can cover a range of
  frequencies and another be a fixed size at one. Across the frequency it is
  a part's edge plus a share of the part, seconds down the waterfall, and
  pixels, so items stay on their part, at the same share or age, as the
  operator moves the split or the speed; or dB above the noise. Radios
  report levels on scales of their own, uncalibrated and some not dB of
  anything at the antenna, so a level in dBm would land somewhere different
  on each; the noise, estimated on every radio and settled so it holds
  still, is the one level a scene can name everywhere. Drawn over the picture and under the annotations, since
  annotations are the ones carrying text an operator clicks most — or, one
  by one, behind the trace, where artwork reads as scenery under the signals
  rather than covering them; artwork is loaded once per source and let go
  when the scene stops drawing it.
- **The scale is a gap plus a layer.** The gap's fill and borders sit between
  the spectrum and the waterfall; labels and ticks are drawn over the whole
  control so an `offset` can put them anywhere, measured from the spectrum's
  base. A label that would touch the last one is skipped, so a narrow pane
  shows every other label rather than a run of digits.
- **One layout, eight ways.** `flow` turns the whole control: the spectrum,
  gap and waterfall are laid out as if the waterfall moved down, and one
  matrix mirrors that for `up`, or lays frequency down the screen for `right`
  and `left`. `rising` turns frequency the other way across the flow, a
  mirror applied before the turn, so the eight ways a band scope can lie share
  one layout. Its default makes each sideways flow `down` turned a quarter,
  never mirrored: up the screen for `right`, down it for `left`. Lines, fills and rows are drawn through
  the matrix; text is not — a label's or an annotation's box is mapped, and
  the text set upright in it — so offsets and pointer corners keep their
  meaning in every flow. Clicks and the pointer go back through the same
  mapping.
- **Clicks.** A click tunes, unless it lands on an annotation or a layer with
  an `event`, which sends `activate` with the frequency and its `annotation`
  or `layer` id instead — an annotation first, as it is drawn on top. Each
  one's clicks queue on their own, so a spot clicked while a tune is in
  flight is not replaced by the next click on the control. One with a
  `menu` opens a native popup at the pointer instead, the shape a button's
  menu has: an extension cannot place a control where a click lands, since
  a band scope is usually laid out rather than placed over the artwork, and
  a dropdown it placed would open closed and stay put as the picture pans.
  The event carries where the click landed (`at`) — the control's pixels,
  scene units when it has a rect, the part, the frequency, and the level or
  the row's age — taken as it lands, since the waterfall moves on while a
  menu is open. Window pixels are left out, as nothing an extension does
  takes them, and so is dBm until levels are calibrated.
- **The gestures are the host's, the scene's to take or turn off** (API 17).
  Tuning, zoom and pan behave the same in every panel that shows a radio, so
  the host does them; `gestures` gives each to the extension as events, or
  turns it off, for a panel that means something else by them. Native tuning
  goes through the same paced queue as a panel's `setRadio`, so a click and
  an extension's command never race to the radio, and needs the same
  `requiresRadioWrite`; without it the click is the event, as before.
- **A bundle before API 17 keeps its clicks.** Those panels tune on their
  click's `commit`; the host tuning too would tune twice. Their tune stays
  the event, landing where it is clicked, their wheel scrolls the scene, and
  they get no axis they did not draw. Zoom and pan cost them nothing and are
  the host's. The source carries the bundle's level (`nativeGestures`)
  because the dock, which knows the bundle, is what builds it.
- **The step follows the zoom, along 1, 2, 5 × 10ⁿ.** Without `tuneStep`,
  every step is a rung of that ladder counted from the smallest covering a
  pixel, which names a frequency nobody could aim at finer. The fine step is a rung up (one pixel's lands on digits nobody tunes by); the
  medium a rung above that and the coarse two, both stopping at 1 kHz, where
  signals sit, unless the fine one is already coarser. A click is the
  operator adjusting only within 5 seconds of the last tune: fine within
  1 kHz of the dial, medium within 3; anything else is a jump to a signal,
  which the coarse step still lands on. The wheel takes the same three by
  speed: fine for notches 120 ms or more apart, medium down to 40 ms, coarse
  closer — a spin covering ground. With only fine and coarse, a brisk turn
  went coarse too soon. Doubling
  instead of the ladder would put 400 and 40 Hz steps on the dial. A
  trackpad swipe turns the same notches, one per wheel notch of travel. What
  a scroll does is the scene's, by its way on screen — up and down tune and
  sideways pans unless it says otherwise — rather than by the frequency's
  way, so a wheel does the same over an upright band scope and a sideways
  one; along the frequency it moves the dial or window the way it goes, so
  the picture follows the hand. A swipe is a pan or a tune by the way it
  starts, so a pan that drifts never tunes. The tuned frequency's line, and a
  finger's width either side, is a handle: dragged, the dial goes to the
  frequency under the pointer, as far from it as the drag took hold, paced
  like the wheel — on no step, so the line moves smoothly with the pointer,
  while its label reads the fine step, and let go the dial lands on the
  fine step the label showed. In the outer 15% the window pans under the line, from
  nothing at 15% in to a window's width a second at the edge and past it,
  so the operator steers by how close to the edge they hold it; the line
  stays under the pointer as the picture moves, exactly, on no step, and
  `follow` leaves the window to the drag, since chasing the dial it would
  run away with it. When the pan stops — the pointer back inside, or let go —
  the dial lands on the step the wheel would be on spun as fast: fine where
  its notches would come 120 ms or more apart, medium down to 40, coarse
  faster, rather than the fine step: where it stops is where the operator
  listens, and a fast pan has gone past what a fine step would place.
- **With Alt held, the line is a bow's string.** Taken hold of with Alt
  down, where the app tunes the radio itself, the line is tied at the
  spectrum's two ends and the pointer pulls it into a V. Nothing tunes while
  it is drawn: the draw aims. Let go before both halves lean 30° off
  straight, it swings back through straight and settles, and the dial stays.
  Past 30° it is loaded — drawn a pixel thicker, so the operator feels for
  the point — and let go, the dial goes the other way from the pull, like an
  arrow: a full draw at 60°, past which the string stretches no further,
  flies 6.7 widths of the window — 100 kHz from 15 kHz wide — up to
  300 kHz, and one just loaded at 30° a third as far, on the coarse step, and no further than the edge
  of the band the dial was in (the app's own region-agnostic band table): past
  it is somewhere the operator cannot transmit. The line is the arrow; the
  radio is tuned there as the window sets off after it, not as it leaves,
  since a scope centred on the dial would carry the window off before the
  arrow had left it — so a gesture taking hold of the window before then
  drops the shot, tuning nothing. Arched back from the way it flies, it leaves
  the still window at one speed, 6 widths of it a second — a full draw lands
  1.1 s later, at any width short of the 300 kHz — so it reads the same
  zoomed in or out. The window sets off after it once it is out of sight —
  at least 27% of the flight before it must be at rest — slow to start and
  quick to close, so it catches the arrow up, overtakes it, and is at rest
  for the last 18% of the flight, to watch it come in
  and quiver the way it flew until it settles. `follow` leaves the window to
  the chase: ten widths away it would be there at once, as for a band
  change, and nothing would be chased. Until it lands the dial's own line,
  label and marks are not drawn: the arrow is not yet where the dial is.
- **A click near an edge glides it in.** One in the outer 15% of the
  window is a signal the operator wants to work, about to sit against the
  edge; the window moves just far enough to bring it 15% in — to the middle
  would shift the whole picture further than the click needs — the radio's
  scope at once and the drawing after it, so the eye keeps the signal
  instead of losing it to a jump. `follow` keeps the dial in the same
  way, and tells a jump of the dial from a spin by the step, whatever moved
  it: a step of up to a tenth of the window's width is a spin — the radio's
  knob, the wheel, a trackpad, a drag of the line, a MIDI controller —
  and anything longer a jump — a click, a memory, a frequency typed in.
  - **A jump glides, after a breath.** It waits for the dial to stand
    200 ms — a run of clicks glides once, from the last, rather than
    jerking the picture to each — then glides there quickly: 600 ms for
    the window's whole width, 150 to 350 ms, the radio's scope at once and
    the drawing after it. A jump of more than three widths of the window —
    a band change — is not glided: the window is there at once, rather than
    sweeping across every frequency between.
  - **A spin is chased.** Waiting for a spinning dial to stand would let it
    run off the edge, and a window held to it on every step jerks along
    with it. The window closes on where the dial needs it, two thirds of
    the way every 120 ms, so it trails the dial by as far as it goes in
    that time — closely on a slow turn, further on a fast one — and
    settles with the dial on the margin once it stops.

  A window that was the radio's sweep is held where a glide or a chase
  sent the scope only until the sweeps arrive from there, then is the
  sweeps' again, so it goes on following a scope moved from the radio
  itself. A gesture taking hold of the window stops either.
- **The dial is drawn where the operator put it.** The source's dial is
  the app's VFO for that radio, which runs ahead of the radio's report
  with the operator's tune until the radio reports it, and holds it
  against reports that contradict it (cat.md § The VFO the app shows).
  After a click, a notch or a drag of the line, the control draws the
  frequency sent ahead of that too, while the tune waits its turn in the
  paced queue: until the source gives it there or 1.5 s pass, and a radio
  that answers no (transmitting, gone, the request queued too long) puts
  it back at once. Where a tune can go nowhere — no leave to command the
  radio and no event to hear it — nothing tunes, and nothing is drawn as
  though it had. Only a tune the app sends the radio itself is drawn ahead:
  one that goes out as the control's event may be put to another use or
  refused, so the dial stays the radio's, and no click near an edge glides
  the window. The wheel counts from the last step it took for a second, since the
  radio's report of it lags, and sends at most four tunes a second, the
  newest kept: a spun wheel otherwise queues a walk.
- **The window is cropped at paint, not at arrival.** The trace, labels,
  marks and clicks work on the window shown, cut from the latest sweep;
  waterfall rows keep whole sweeps, each drawn where its range sits in the
  window. A zoom or a pan then redraws at the pointer's pace with its history
  intact, instead of waiting for sweeps and starting the waterfall empty.
- **Within the sweep it is a crop; past it, the radio's scope moves.** A pan
  past the sweep's edge recentres a scope the app may place, at most four
  times a second. One it may not place goes on until the window's middle
  reaches the sweep's edge, the rest drawn as filler: what lies past a scope
  held on the dial — spots, the band plan — is still the operator's to look
  at, and a window stopped at the edge would hide it. A zoom past the
  sweep asks for a wider scope: through `showWidth` where the app sizes it
  (`autoSpan`), as the radio's next span where the panel may command it
  (visible on the radio's own screen, hence the permission), and no further
  elsewhere. Within the sweep a zoom crops while it moves; where it ends
  with the sweep's points more than 3 pixels apart, a radio whose span the
  panel commands goes to the narrowest that covers the window where it sits
  and the widest window any other display of it shows, since a few hundred
  points cropped to a narrow window draw a handful of them. Closer than
  that the span is left alone: each change jolts the radio's own screen and
  restretches the waterfall. A zoom goes no narrower than the narrowest
  sweep the scope can be made to send (`minWidthHz` on the source) with its
  points 10 pixels apart, taken to have as many points as the one it sends
  now: further apart, the trace is a few straight strokes. Pixels, not a
  count of points: a count fit for a narrow pane spreads them coarse across
  a wide one. Narrowed as it went, the zoom would step the radio through every span
  on the way. A display naming no width draws the whole sweep, so it holds
  the span from narrowing (`showWidth` 0); a scope in fixed mode, whose width
  is its edges, is left alone unless the app places those edges itself
  (`spanSetsEdges`) — an SDR tuned on its own would otherwise change its
  sample rate and retune; and the double click's reset widens back what
  that display's zoom narrowed, which would otherwise leave it cropping the
  narrowed sweep.
- **A scene may zoom past the scope.** `minWidthHz`/`maxWidthHz` replace the
  radio's limits, so a band scope can show a whole band on a radio whose
  scope covers part of it. Past what the scope can be made to show, the
  picture covers the swept part, and past it a dashed line at the median of
  the bins drawn, over the fill darkened, stands in for it, the two fading
  into each other over the sweep's last pixels. The median, not the noise
  estimate: that comes from the raw sweeps and settles slowly, so it stands
  off the averaged trace the line carries on from. Left blank, a band past
  the scope reads as silent; filled alike, as heard; and cut off sharp, as
  falling silent.
  The fade adds the two into one layer, since one laid over the other
  thins both where they meet. A radio with no scope sends no sweeps, so it
  gets no filler either. The window no
  longer drags the scope with it: a pan stops where the sweep reaches the
  window's edge, so the live part never leaves view, and the scope follows
  the dial by `follow`'s margin of its own width, moved just far enough as
  the window is. Following the window instead, a pan would leave the dial
  unswept. The dial is measured against where the scope was last sent until
  a sweep from there arrives (or a second passes, for a radio that lands it
  nearby): against the sweeps still arriving from where it was, each would
  send it again.
- **A scene may name its window.** Over a sweep, `window` is where the
  window centres until the operator pans: a band map shows its band, not
  wherever the radio's scope happens to sit. While no sweep comes it stands a
  sweep with no levels in for the radio's, so a band map is one
  control whether the radio has a scope or not: the axis, marks and gestures
  all work on the window shown, which the stand-in provides as a sweep does.
  It is a scope the app cannot move, so a zoom and a pan stay within it and
  nothing is asked of the radio; the trace and the level strip have nothing
  to draw and are left out. A sweep that arrives takes its place, and the
  operator's zoom with it, since a window chosen over the band is not one
  over the sweep; one that stops gives it back after the 3 seconds that
  would otherwise say the display is waiting.
- **A native gesture is still reported, once.** The extension owns the
  panel's preferences, so the host tells it where a zoom, pan or split ended
  — one `commit` at the end, not the stream an event-mode scene gets, since
  keeping a choice needs only where it landed. A scene that gives a saved
  width back as `span` makes the double click's reset a no-op, so the reset
  reports a zoom of 0 for the scene to drop it. Never to a bundle before API
  17, whose commits are its tunes.
- **A pan holds against `follow` until the dial moves.** Follow pulls the
  window back toward the dial, which would undo every pan the moment it
  ended; a moved dial is the operator going somewhere, and follow resumes.
  Where follow moves the window, the window moves the scope. Where it
  stands still, a scope the app places weighs two aims: covering the
  window, and changing as seldom as it can, since each change redraws the
  picture under the operator. So a spin of the dial leaves the sweep alone
  unless the dial comes within `follow`'s share of the sweep's width of an
  edge, and then moves as little as keeps the dial that far in, to where
  it covers most of the window. A jump — a click, a spot — with the window
  not covered, or landing that near an edge, moves it at once to cover the
  window, and within that as near centred on the dial as it goes: the
  operator has just said where they are looking, a dial left at the margin
  is a step from moving it again, and centred regardless, the sweep would
  leave part of the window bare. Recentred on every move, a sweep a
  little short of a panned window would change with every knob step; left
  alone after a click, it would show a partial picture until the next pan.
  The scope's middle is taken from where
  it was last sent until a sweep from there arrives, so a sweep still on
  its way is not asked for again.
- **Drags only along the frequency, except on the axis.** A drag across it
  is left in the arena for a scene that scrolls, but on the axis it moves the
  axis, resizing the spectrum against the waterfall: the strip is the
  divider between them, and too narrow to be where a scroll begins. The
  operator's share is held over the scene's `split`, given back when the
  scene changes it, the way a zoom is over `span`. A pinch, a trackpad
  gesture and the wheel are read outside the arena; the wheel claims its
  event, so a scroll and the band scope never both take one, and a scene's
  scroll takes a trackpad swipe outside the arena too. Along a scrolling
  scene's axis a trackpad swipe — a pan-zoom on a desktop, a scroll event in
  a browser — and a sideways wheel are left to the scroll: taken by both,
  they would tune or pan the radio as the scene scrolls, and claimed by the
  band scope, the scene would stop scrolling over it. A mouse wheel turned up
  or down over the band scope tunes, scrolling scene or not.
- **A click on the axis tunes, once it is not a double.** A double click
  there resets the zoom, so a click waits out the double-click time before
  it tunes; tuning at once, the first click of a reset would also move the
  dial. Only the axis waits: the double is told apart in the click handler
  rather than by a double-tap recognizer, which would hold back every click
  on the picture too.
- **The dial's label reads over the passband.** At the top of the line,
  on the side the scene's passband (its first area anchored to the dial)
  is, in every mode: it sits above the signals heard, and the side away from
  the passband is left clear for the neighbours an operator tunes towards.
  It shows as many digits as the dial has, `14.074` or `14.07425`, but keeps
  any it has shown while the dial moves — 14.0745 on to 14.0750, not
  14.075 — and drops them once the dial has stood 300 ms: a label a digit
  shorter and back on each step shakes. A digit slides out from under the
  box's edge, or back under it, over 150 ms, and is cut, never rounded.
  A scene can fix the Hz digits instead, and style the MHz, kHz and Hz
  apart; by default the MHz is bold and the kHz and Hz light, so the
  figure the eye lands on is the band's.
- **Axes over the picture or beside it.** Each axis can lie over the
  picture on a see-through background, keeping the picture its room, or
  take room of its own. The level strip lies over by default and the
  frequency axis beside, as it always did; over the picture the frequency
  axis lies across the waterfall's head unless the scene says the
  spectrum's foot, where it would cover the noise floor the eye reads
  levels against; the strip borrows the frequency
  axis's background, labels and ticks unless the scene styles it, so the
  two read as one frame. Over the picture the strip is a sibling above the
  band scope rather than inside it, so its drags and double clicks never
  reach the picture's clicks and pans.
- **The level strip is a handle too.** Along the flow at the end of the
  frequency's way across the screen unless the scene says the start — the
  right of an upright band scope, the bottom of a sideways one, so the
  strip lies where the levels and ages run in every way the band scope
  can lie — dB along the spectrum (no unit, as a radio's scale reads) and
  seconds along the waterfall (with theirs: a bare number there could be
  anything). Sideways its labels sit upright side by side, so they need
  more room between them, and the strip is only as deep as a label. Its drags work as the frequency axis's do — what is
  taken hold of stays under the pointer: the age on the waterfall, which
  sets the speed; the trace on the spectrum's bottom third, which sets the
  floor; a level above that, with the range zooming away from the middle;
  and, with Alt held, the waterfall's floor (`waterfallFloor`), in fine
  steps — the waterfall's whole length is 12 dB — for matching a radio's own
  waterfall by eye. Each is held over the scene's number, given back when
  the scene changes it, and reported, like a zoom; a double click hands the
  first three back, each reported as 0, as the axis's reports a zoom of 0,
  and drops a held waterfall floor unreported: a scene keeps that one as a
  setting, not a drag of the moment. The waterfall's window is measured on
  the spectrum's as the strip leaves it, so a drag that lifts the noise or
  stretches the contrast does the same down the waterfall, and any change of
  that window or the palette redraws the whole history, each row from the
  levels it keeps, not only the rows still to come.
- **Waterfall rows lie at their age.** Each row is drawn from when it was
  taken down to the row before it, at the speed now: a change of speed
  re-spaces the whole history at once, so a drag on the strip moves the
  picture with the pointer instead of only the rows still to come, and
  irregular sweeps leave no gaps. The waterfall's time scale is the speed
  set, or the sweeps' steady rate, never their rate as it wobbles: every row
  lies at its age on it, and a scale that moved with each sweep would shake
  the history up and down. The dB are on the radio's own scale, not
  calibrated dBm ([cat.md](cat.md)); where the app estimates the floor, it
  settles rather than following each sweep, so the labels hold still.
- **The axis is the zoom handle.** A scene that names no `scale` gets the
  default one, with ticks, so there is always a strip to drag; `scale: false`
  is the way to have none.

## Rotator map

A rotator map (`rotatorMap`, extension API 23) shows a rotator on an
azimuthal equidistant map centred on the station, and whatever the scene
places over it by bearing and distance or by place on Earth. The public
contract is in [panel scenes](../extensions/scenes.md#rotator-map) and
`PanelSceneRotatorMap`. It is the station's equipment under the radio's
grants ([radio.md § Antenna switches and rotators](../extensions/radio.md#antenna-switches-and-rotators)):
`requiresRadioRead` shows it and `requiresRadioWrite` turns it. The app's own
Rotator panel (`ham2k-rotator`, in ham2k/extensions, pre-loaded) is the
reference panel: one
rotator or several in their own colours, a beam's width or a switched
array's fixed bearings, its readouts and buttons at the pane's corners, and
the operator's zoom and pan kept per placement in the key-value store.

- **A control, as the band scope is.** It takes clicks and drags and fills
  space in the layout. The map and the rotator's readings are the host's:
  the land, night and outlines are painted from bundled data, and a heading
  reaches the scene only as the values it writes.
- **Decorations are placed on the map, not in scene units.** The map's
  scale and centre move with every zoom and pan, so a beam drawn in scene
  units would have to be re-rendered by the extension on each. A bearing
  and a distance (`heading+15deg`, `rim-8px`, `1000km`), a `lat`/`lon`, or a
  share along an earlier line stay put on their own.
- **`defaults` is the host's own decorations, in the scene's order.** A
  scene draws under and over the beam, target, heading and call marker
  without redrawing them, and without seeing the palette they are drawn
  in.
- **Zoom, pan and rim follow red-ham-toolkit's rotator widget.** Zoomed all
  the way out the rim is a circle round the whole Earth; closing in, it
  becomes a rounded box whose corners tighten with the zoom. Panning moves
  the station, never further than `0.95·zoom − 1` disc radii from the
  pane's middle, which keeps the antipode — the disc's edge — out of view,
  so a map at zoom 1 does not pan. The box stretches toward the side the
  station moved to, and the corner across from it opens toward a round,
  so the rim leans with the pan (`scene_rotator_frame.dart`).
- **Turning is a click or a drag of a decoration, never a drag of the map.**
  A drag that starts on the station pans; the wheel, a trackpad's scroll
  and a pinch zoom; a drag anywhere else does nothing, so a pan meant for
  the view never turns the antenna. A drag of a decoration turns on
  release only: a rotator told every frame of a drag would chase it.
- **With Alt held, a line that turns is a rubber band.** Taken hold of
  with Alt down, a line decoration that turns — the heading arrow, by
  default — is tied at its two ends and the pointer pulls it sideways into a
  V, by the band scope's bow's angles (§ Spectrum): let go short of both
  halves leaning 30° it twangs back straight and nothing turns; past 30° it
  is loaded, a pixel thicker, and let go, the target spins away the other
  way from the pull — 2 whole turns just loaded, 5 at the full 60°, then on
  round to a heading picked at random among the scene's stops or anywhere —
  slowing all the way over 1.9 to 3 s, and wobbles 5° past where it lands.
  The rotator is told once, as it lands, not as it is let go: the operator
  sees where the antenna is going before it goes. A click, another drag of
  a decoration or the map's stop button while it spins drops the shot,
  turning nothing: the turn the operator asks for is the one they meant.
  Only the map's own: a turn sent from elsewhere while it spins — the
  Station panel, an extension — is overtaken when it lands.
- **A turn shows at once.** The target is drawn the moment it is sent and
  held for 2 seconds, long enough for a polled rotator's own report to
  catch up, so a click is never followed by a moment with nothing drawn.
- **The raster covers everywhere the pan can reach.** Land and night are a
  raster asking each pixel where on Earth it is (the reason is in
  [cat.md § Rotators](cat.md#rotators)). It is built for the zoom, over the whole
  stretch of disc a pan at that zoom can show, at most 1024 pixels a side,
  so a pan moves a picture rather than projecting it again; off the UI
  isolate except on the web. Its night is three steps — sunset, civil and
  nautical twilight — each 20% darker (25% on a dark theme) and faded in
  across 1.5° of the sun's altitude rather than at the hard edges of the
  Map tab's four.
- **States and provinces fade in as the view closes in.** Natural Earth's
  1:50m first-order divisions, which that scale has only for the USA,
  Canada, Brazil, Russia, China, India and Australia
  (`assets/geo/admin1-50m.json`, by `scripts/admin1-outlines.py`), faded
  in between zoom 2.5 and 4.
- **The heading it writes is the last one given.** `headingDeg` holds the
  rotator's last heading while it is disconnected or not answering, so a
  readout does not blank on a dropped connection; `status` says whether it
  is current.

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
- **The same gate as the band scope.** The values come through the source the
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
[the panel scene contract](../extensions/scenes.md). The renderer is domain-neutral:
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
