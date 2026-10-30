# Panel scenes

A [panel](panels.md)'s `render` may answer a **scene** instead of a
document: SVG artwork, text and icon layers, numeric bindings, controls the
app draws or Material controls it themes, a layout, host-run animations and
the radio's live readings. The app draws it and keeps it live itself. Your
extension renders a scene when something changes and answers `onEvent` when
the operator uses a control; a value moving under a binding, a local control
and an animation frame cost no bridge call at all.

```ts
return { kind: "scene", scene, title?, triggers? }
```

`PanelScene` and `PanelSceneControl` in the SDK carry the schema as types,
and `k2hrc-panel-scenes` in the samples has every kind of control.
`kind: 'svgScene'` is the same content under its earlier name, which the
SDK keeps as a deprecated alias (with the `SvgScene*` type names) and the
app still accepts; some published panels still answer it, and a plain scene
that must reach an app older than API 5 keeps that name and the lower level.

## API levels

| Level | Adds |
| --- | --- |
| 5 | `scene` itself: native controls, `strings`, `layout`, `after`, control `opacity` |
| 6 | the `spectrum` control and `host.setRadioSpectrum` |
| 7 | the `radio` block and its values, `scaleX`/`scaleY` bindings, text `glow`, a knob's `menu` and second axis, the spectrum's `follow`, `span` and label `decimals` |
| 12 | up to 512 layers and 256 controls, `icon` layers, `scroll` and the `zoom` strip, `hoverSet`, `tapAt`, `scrollThrough`, `invertDrag`, the spectrum's `rising` and `autoSpan` |
| 13 | the radio's dial in the values (`radio.frequencyHz` and the rest marked so below), `radio.mode`, `radio.tuner` and `radio.status` in `strings`, and `when` on layers and controls |

A bundle declares the highest level it uses; an app speaking less refuses it
at install rather than showing the panel as an unknown kind.

## The scene document

| Field | |
| --- | --- |
| `version` | `1` |
| `width`, `height` | The artwork's viewBox in scene units. Size it to `environment.width`/`height` and a scene unit is a logical pixel |
| `values` | `{ name: number }`: what bindings, numeric text and numeric controls read. At most 256 |
| `strings` | `{ name: string }`: what text fields and choices hold. At most 256, each up to 4,096 characters. A name is in `values` or `strings`, never both |
| `layers` | Painted in order, each over the ones before: `svg` artwork, `text`, or an `icon`. At most 512 (128 before API 12), and 1,048,576 characters of artwork and text in all. A layer's `svg` is self-contained vector artwork, no `<image>`, `<script>` or `<foreignObject>`, no entity declarations, at most 16,384 elements nested at most 32 deep |
| `controls` | At most 256 (64 before API 12). Drawn or native; below |
| `layout` | Optional. Where rect-less native controls and the artwork go; omitted, the artwork fills the pane |
| `scroll` | Optional, `{ axis?, value, event? }` (API 12): a scene longer than its pane along `axis` (`y` by default), scrolled natively by wheel, trackpad and drag (a drag begun on a button included) with no call to the extension. It fills the pane across and runs on past it. The position in scene units is written to the scene value `value`; a render that changes that value moves the view, one that leaves it alone leaves the operator's scroll alone. `event` is sent as a `commit`, the position as `value`, once a scroll comes to rest. Layers and controls with `fixed: true` stay put over the pane, in pane coordinates; a drag along the scroll on a slider or knob that scrolls with the content is the scroll's, so make one that must be dragged `fixed`. Not with `layout` |
| `radio` | Optional, `{ node? }` (API 7): the app feeds that radio's live readings into the reserved `radio.*` values. `node` is an id from `listRadios`; omitted, the logging radio |

Every rule here is checked when the scene arrives, and a scene that breaks
one is refused whole rather than drawn in part: the pane says the panel
could not be displayed, naming the bound when a budget was broken, and the
console names the rule.

## Layers and bindings

A layer has an `id`, a rect (`x`, `y`, `width`, `height`) and one of `svg`,
`text` or `icon`. A layer binds `rotation`, `translateX`/`translateY`,
`scaleX`/`scaleY` and `opacity` to a scene value: `{ value, input: [lo, hi],
output: [lo, hi] }` ramps, or `samples` equally spaced over the input range.
Rotation and scale turn about the layer's `pivot`, so `scaleX` with
`pivot: [0, 0.5]` grows a bar's fill from its left end. Bindings accept
`scale`, `truncate` and `modulo`, applied to the value before the ramp, and a
`transitionMs` eases a change. The app interpolates and clamps locally, so a
meter needle, a chart marker or a callout follows a reading with no bridge
call.

**Text layers** are the typography path; SVG `<text>` is not portable through
the renderer. A text layer takes a `literal` or a bound `value` (a number
or a string name), `size`, `color`, `fontFamily`, `fontWeight`,
`lineHeight`, `letterSpacing`, and a `glow` colour that draws a soft halo
for legibility over busy artwork. Numeric text formats locally with
`scale`, `truncate`, `modulo` and `minIntegerDigits`; `samples` may hold
numbers or preformatted strings. A frequency readout binds its digit groups
to one value: MHz with `scale: 1e-6, truncate: true`, the kHz within with
`scale: 1e-3, truncate: true, modulo: 1000, minIntegerDigits: 3`. Supply the
unscaled `fontSize` from the environment's typography as `size`; the app
scales text once. A text layer also takes `prefix`, `suffix`, `decimals` and
`align`, and a layer a `pulse` (`{ periodMs, minOpacity, flicker? }`);
`PanelSceneLayer` in the SDK has them all.

**Icons** (API 12) are `{ name, color? }`, a Material Design Icons or `fa-`
name drawn in the layer's rect.

## Controls

Every control has an `id` and a `label`, its accessible name; the app has no
tooltips. An `event` names the action sent when it is used; without one the
control is **local-only**: its value changes on screen, survives renders,
and never reaches the extension. `value` names what it shows and sets.

| Kind | Binds to | Sends | Also takes |
| --- | --- | --- | --- |
| `button` | | `activate` | `menu`; `tapAt` (API 12: a click's `value` is where along the longer side it landed, 0 at the top or left end to 1; a key or a screen reader activates with none; needs an `event` and takes no `menu`) |
| `slider` | number | `commit` | `min`, `max`, `step`, `discrete`, `hover` (local-only sliders), `valueLabels`, `continuous`, `scrollThrough` |
| `knob` | number | `commit` | `min`, `max`, `step`, `sensitivity`, `invertDrag`, `scrollThrough`, `valueLabels`, `continuous`, `menu` (a click opens it; a scroll or a drag still turns the knob), a second axis (`valueY`, `eventY`, `minY`, `maxY`, `stepY`, `sensitivityY`) |
| `nativeButton` | | `activate` | `variant` (`filled`, `tonal`, `outlined`, `text`), `icon`, `menu`; needs `event` or `menu` |
| `nativeSlider` | number | `commit` | `min`, `max`, `step`, `valueLabels`, `continuous` |
| `nativeTextField` | string | `commit` on Enter, or on leaving it after typing | `placeholder`, `continuous` |
| `nativeDropdown` | string | `commit` | `options`, `placeholder` |
| `nativeRadio` | string | `commit` | `options` |
| `nativeSegmented` | string | `commit` | `options`, `multi` |
| `nativeSwitch`, `nativeCheckbox` | number, 1 or 0 | `commit` | shows `label` beside it |
| `nativeChip` | number, 1 or 0, or none | `commit`; `activate` without a value | `icon`; needs `event` without a value |
| `nativeText` | number, string, or none | | `style` (a typography role), `align` |
| `spectrum` | | `commit` with the frequency clicked; `activate` from an annotation | below |
| `zoom` | | `commit` with the factor, on release | `min`, `max` (the factors allowed); needs `event`; only with `scroll`; API 12; below |

The three drawn kinds are invisible hit areas over artwork you paint; the
native kinds are Material widgets the app paints and themes. Every control
may also take:

- `x`, `y`, `width`, `height`: its rect in scene units. Required for the
  drawn kinds; a native control omits all four to be placed by `layout`, and
  with a rect takes its width and its own height, up to the rect's, so give a
  field a rect tall enough for it.
- `after`: with a rect, the layer it paints directly after. Otherwise a
  control paints above every layer.
- `opacity`: 0 to 1, fixed or bound like a layer's. At 0 the control takes
  no clicks, focus or screen-reader node.
- `disabled`: shown, but nothing acts on it.
- `when`: a condition, below.
- `hoverSet` (drawn kinds, API 12): `{ value, to }`. While the pointer is
  over the control the scene value reads `to`, set by the app with no call
  to you, and leaving puts back the scene's own value, so a layer bound to
  it lights up under the pointer; several controls naming one value with
  different `to`s light up one thing each. It survives renders while the
  pointer stays.
- `continuous: true`: `change` events during a drag and a final `commit` on
  release; pending movements coalesce to the newest.
- `valueLabels` supplies accessible descriptions of a control's values for a
  screen reader.

`options` is `[{ label, value }]`, up to 64, each `value` unique; a choice's
string is `""` or one of them, and a `multi` choice joins its values with
commas in option order, so no option may contain a comma. `menu` is
`[{ label, event }]`, up to 32; picking an item sends its `event` as the
action with the control's id; dismissing sends nothing.

A knob with `valueY` sets two numbers from one patch of artwork, a
passband's shift across and its width up, say. Horizontal dragging,
horizontal scrolling and the left and right keys set `value`; vertical ones
and the up and down keys set `valueY`, which must be in `values`, with its
own range, step and feel from the `…Y` fields. The second axis sends with
`eventY`, which a knob with an `event` must give, different from `event`,
since an event carries no other mark of which axis moved; a scene without it
is refused. The app queues the two axes separately, so neither replaces the
other's pending value, and a drag commits only the axes it moved.

String-valued controls bind to `strings`; their events carry `text` instead
of `value`. A text field commits on Enter or on leaving it, and a render
that lands while the operator is typing does not overwrite the typing.

**Focus.** A text field or dropdown keeps keyboard focus; clicking any other
native control hands focus back to the callsign field. A drawn `button`
never takes focus from a click. A drawn `slider` or `knob` holds focus for
three seconds after its last use, long enough for the arrow keys, then hands
it back; focus that arrives by Tab stays. A scroll steps a slider or knob by
its `step`, down and left lowering it, and a one-axis control takes a
sideways scroll by its own direction. `scrollThrough` (API 12) lets a slider
or knob also take the scrolls landing on drawn buttons over it, so labels
drawn over a knob do not stop the scroll; anything else in the way (a native
control, a `blocksPointer` layer, another slider or knob) keeps the scroll
from it. `invertDrag` (API 12) moves a knob the other way to a drag, as
content under a finger does, while its scroll is unchanged.

**The `zoom` strip** is drawn by nothing: it claims a drag that begins on it
along a scrolling scene's axis. Away from the pane's middle zooms in and
toward it zooms out, by the ratio of the two distances from the middle,
clamped to `min`…`max`. While the drag lasts the app moves each layer and
control to where the zoom puts its middle, keeping its size, so text and
dots stay as drawn and only spread apart or close in; a layer with
`stretch: true` (a background, a line the length of the scene) scales along
the scroll instead. That preview holds until the render that answers the
`commit` arrives, so a scene meant to zoom draws its pieces as layers of
their own rather than as one picture. A tap on the strip still reaches the
button there, a drag that starts off it still scrolls, a trackpad's
two-finger swipe scrolls on the strip as anywhere else, and a trackpad pinch
begun on it zooms by the pinch's own scale, clamped the same way, and
commits as a drag does.

## Layout

A native control either has a rect or is placed by `scene.layout`, a tree
of `row`, `column` and `wrap` nodes:

| Node | |
| --- | --- |
| `{ row: [...] }`, `{ column: [...] }` | `mainAxisAlignment` (`start`, `center`, `end`, `spaceBetween`, `spaceAround`, `spaceEvenly`), `crossAxisAlignment` (`start`, `center`, `end`, `stretch`), `spacing` |
| `{ wrap: [...] }` | `spacing`, `runSpacing`, the same alignments but no `stretch` |
| `{ control: "id" }` | A native control without a rect. Each appears exactly once |
| `{ scene: true }` | The artwork, scaled to fit. At most once; a layout without it shows no artwork |
| `{ spacer: n }` | Flexible empty space |

Any node may add `width`, `height` and `padding` (one number, or
`[start, top, end, bottom]`); a row or column's direct child may add `flex`
with `fit: "tight"` (the default) or `"loose"`. Sizes are logical pixels. A
text field or dropdown given no width is 200 wide; a row's children that do
not fit overflow, so use `flex` or `wrap`. A `flex` only shares space its row
or column has: in a row that is itself an unflexed child of a row there is
none, and its children lay out at their own size. The layout is at most 8
deep and 128 nodes.

## Controls among the layers

Layers paint in order and are click-through: art painted over a control does
not stop it working. A layer with `blocksPointer: true` takes the clicks
that land on it while visible, covering the controls under it (keyboard
focus still reaches them; mark them `disabled` too to shut them off). Only a
pending action disables action controls; a value being sent does not.

## Conditions

A layer or a control may carry a **`when`** (API 13): it is shown only while
one value passes one test, checked by the app as the value changes.

```js
{ id: "ssb-filter", /* … */ when: { value: "radio.mode", in: ["USB", "LSB"] } }
{ id: "cw-keyer",   /* … */ when: { value: "radio.mode", is: "CW" } }
{ id: "qrp",        /* … */ when: { value: "radio.powerWatts", max: 10 } }
{ id: "offline",    /* … */ when: { value: "radio.connected", is: 1, not: true } }
```

`value` names a number or a string, the scene's own or a `radio.` one, and
the test is exactly one of `is`, `in` (up to 256) or a range (`min` and/or
`max`, inclusive); `not: true` inverts it. The test must suit the value:
words for a string, numbers for a number, no range on a string; a mismatch
is refused when the scene arrives. A radio number the radio has not given
fails the test before `not` inverts it, so `not` is how a scene says "while
this is missing"; a radio word it has not given is empty, and `is: ''` tests
for one. Hidden is the same as an opacity of 0: the layer is not drawn and a
`blocksPointer` one lets clicks through; the control takes no clicks, focus
or screen-reader node, and one placed by `layout` keeps its place. A `when`
and an `opacity` combine: the opacity applies while the condition holds, and
a layer's `transitionMs` fades it in and out.

## Events and results

`onEvent` receives, beside the render arguments:

```ts
event: {
  controlId: string
  action: string                    // the control's `event`, or the menu item's
  phase: "activate" | "change" | "commit"
  sequence: number                  // increases with every event from this pane
  value?: number                    // for a control bound to `values`
  text?: string                     // for a control bound to `strings`
  annotation?: string               // a spectrum annotation's id
}
```

It answers `{ values, strings? }`, a patch of names already in the scene. An
answer with neither is a failure, and so is one that throws or runs out of
time: the pane says the action failed and the control goes back to what the
scene last reported. The app sends one event at a time, keeps only the
newest of a control's queued changes, ignores an answer to an event a newer
one has superseded, and requests a render after each. A text field's typing
is sent before any action, and an action queued behind a value the extension
refused is not sent. A control shows its pending value until the outcome is
known. An `onEvent` that cannot read its panel's config is refused rather
than run with an empty one, since a config is where a panel keeps which
radio it commands; the app allows an event about ten seconds in all, config
and hook together.

### Example

A spot form over a status strip:

```ts
const state = { call: "", band: "20m", status: "Nothing spotted yet" }

export const spotter: PanelHook = {
  async getPanels() {
    return [{ key: "spotter", title: "Spotter", icon: "bullhorn" }]
  },
  async render() {
    return {
      kind: "scene",
      scene: {
        version: 1, width: 400, height: 40, values: {}, strings: state,
        layers: [
          { id: "strip", x: 0, y: 0, width: 400, height: 40,
            svg: '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 400 40"><rect width="400" height="40" rx="8" fill="#142337"/></svg>' },
          { id: "status", x: 12, y: 8, width: 376, height: 24, text: { value: "status", size: 14, color: "#a9efcf" } },
        ],
        controls: [
          { id: "call", kind: "nativeTextField", label: "Callsign", value: "call", event: "set" },
          { id: "band", kind: "nativeDropdown", label: "Band", value: "band", event: "set",
            options: ["40m", "20m", "15m"].map((b) => ({ label: b, value: b })) },
          { id: "spot", kind: "nativeButton", label: "Spot", icon: "bullhorn", event: "spot" },
        ],
        layout: {
          column: [
            { row: [{ control: "call", flex: 1 }, { control: "band", width: 110 }, { control: "spot" }], spacing: 8 },
            { scene: true, flex: 1 },
          ],
          padding: 12, spacing: 8, crossAxisAlignment: "stretch",
        },
      },
    }
  },
  async onEvent({ event }) {
    if (event.controlId === "call" && event.text !== undefined) state.call = event.text.toUpperCase()
    if (event.controlId === "band" && event.text !== undefined) state.band = event.text
    if (event.action === "spot") {
      if (!state.call) throw new Error("No callsign to spot")
      state.status = `Spotted ${state.call} on ${state.band}`
    }
    return { values: {}, strings: state }
  },
}
```

## The render environment

Scene-capable hosts supply `args.environment` on render and event calls:

- `width`, `height` and `safeInsets` describe the pane in logical pixels,
  with the app's font scale already applied. Do not multiply coordinates by
  a font-scale preference or `devicePixelRatio`.
- `brightness` is `light` or `dark`, system theme changes included; `colors`
  holds `surface`, `surfaceContainer`, `onSurface`, `onSurfaceVariant`,
  `accent`, `primary`, `onPrimary`, `secondary`, `outline`, `outlineVariant`,
  `error` and `onError` as `#RRGGBB`.
- `typography` holds the `body`, `label`, `title`, `display` and `mono`
  roles, each with `fontFamily` (null for a platform default), fallbacks,
  `fontSize`, `scaledFontSize`, `fontWeight`, `lineHeight` and
  `letterSpacing`. `scaledFontSize` is the OS accessibility scaling at that
  role's size, not one linear factor for all sizes; use it when reserving
  label space, and supply the unscaled `fontSize` as text `size`.
- `locale`, `textDirection`, `devicePixelRatio`, `reducedMotion` and
  `highContrast`. Font names refer to the app's fonts; they are not URLs or
  permission to load remote fonts.

A scene panel is re-rendered through the usual throttle when the
environment changes, even with no triggers declared; hidden panels catch up
on reveal, repeated resize updates coalesce, and a scene laid out for an old
environment cannot overwrite a newer one. Markdown and HTML panels are
themed and laid out by the app, so an environment change does not re-render
them; their next render carries the current environment.
`args.clock.nowMillis` follows the app clock, which developer time travel
moves (so does the sandbox's `Date`); `realNowMillis` is for network retries
and cache budgets. Both `environment` and `clock` are optional in the SDK,
for detecting an older host.

## Spectrum

A `spectrum` control is a radio's panadapter and waterfall, drawn by the app
from sweeps that never reach the extension. API 6, with
`host.setRadioSpectrum` ([Radio control](radio.md#the-scope)). It needs
`requiresRadioRead`; without it, or on a host or radio without a spectrum,
the control says why instead. Placed like a native control, it takes:

- `radio` (an id from `listRadios`; omitted, the designated radio),
  `display` (`both`, `pan`, `waterfall`), `split`, and `flow`, which way the
  waterfall moves (`down`, `up`, `right`, `left`), the panadapter on the
  side it comes from.
- `rising` (API 12): which way frequency increases across the flow: `right`
  or `left` for `down` and `up`, `down` or `up` for `right` and `left`; one
  along the flow is refused. Omitted, each flow is `down` turned a quarter,
  never mirrored: `right` for `down` and `up`, `up` for `right`, `down` for
  `left`. Text stays upright, and offsets, `align` and pointer corners are
  measured as if frequency rose to the right.
- `floor`, `range`, `average` (0 to 99, default 40), `fps` (default 15),
  `waterfallSpeed`, `waterfallFloor`, `waterfallRange`: numbers, or the names
  of scene values read on every sweep.
- Colours (`#RRGGBB` or `#AARRGGBB`): `palette` or `waterfallColors`,
  `traceColor`/`traceWidth`, `fillColor`/`fillColorBottom`,
  `backgroundColor`, `gridColor`/`gridDashed`, `waterfallGridColor`.
- `center`: the tuned-frequency line, styled per part; `overlays`: up to 16
  lines (`at`) and areas (`from`, `to`) in Hz from the tuned frequency, the
  sweep's middle, or absolute, each styled per part; `scale`: the gap
  between panadapter and waterfall, its fill and borders, and frequency
  `labels` and `ticks`, with `labels.decimals` (0 to 6) fixing the decimals
  of MHz every label shows (omitted, as many as tell one label from the
  next).
- `span`: Hz shown across the control, from the middle of each sweep, a
  number or a scene value. A wider sweep is cropped to it, so a radio whose
  scope comes in a few fixed widths can be shown at any narrower one; set the
  scope to the narrowest that covers it, and everything is drawn, labelled
  and clicked on the window shown. Where the radio's `spectrum` says
  `autoSpan` (API 12) the app sizes the scope itself to the narrowest span
  covering the widest `span` on screen, so a panel there names its width
  here and leaves `setRadioSpectrum`'s `spanHz` alone.
- `follow` (0 to 0.45): keeps the tuned frequency at least this share of the
  width from either edge by moving the radio's scope just far enough, so the
  picture scrolls with the dial rather than jumping to centre it. Only where
  the radio lets the app place its scope and the panel declares
  `requiresRadioWrite`; elsewhere it changes nothing.
- `annotations`: up to 64 pieces of text at frequencies, each with a pointer.
  One with an `event` sends `activate` when clicked, its frequency as
  `value` and its `id` as `annotation`, and does not tune.
- `hoverHz`, `hoverDb`: scene values the pointer writes, for a text layer.
- `tuneStep`: a click elsewhere sends `commit` with the frequency under it,
  rounded to this many Hz. The extension decides whether to tune.

Each waterfall row stays at the frequencies it was taken on: when the radio
retunes its scope the history slides sideways, and when the span changes it
stretches.

## Radio values

A scene with a `radio` block (API 7) is fed that radio's live readings into
reserved values a binding, a text layer, a control's `opacity` or a `when`
can read like any other. They change as the radio reports them, several
times a second, with no render and no bridge call. The feed needs
`requiresRadioRead`; without it every reading is missing. The names are
reserved: a scene may not declare them, and nothing may set them.

| Value | |
| --- | --- |
| `radio.signalDbm` | Receive signal, dBm |
| `radio.powerOut` | RF out, watts |
| `radio.swr`, `radio.alc`, `radio.supplyVolts` | The transmit meters |
| `radio.transmitting` | 1 or 0, the radio's own report |
| `radio.swrAverage` | SWR averaged over the transmission under way, else the last one; only readings taken with RF out count |
| `radio.secondsSinceTransmit` | 0 while transmitting, then counting up; very large when there has been none |
| `radio.frequencyHz` | The frequency, in Hz, last reported; kept while disconnected, as the app's own Radio panel keeps it. API 13 |
| `radio.passbandLowHz`, `radio.passbandHighHz`, `radio.passbandWidthHz` | The receive passband's edges relative to the carrier, and its width. API 13 |
| `radio.powerWatts` | The power the radio is **set** to; `powerOut` is what it measures. API 13 |
| `radio.ptt` | 1 while the app holds the radio's PTT, given where `readRadio()` gives `keying`: the logging radio, connected, on a host with keying enabled. `radio.transmitting` is the radio's own report, and the two differ: a radio keyed from its own microphone is transmitting with no PTT held. API 13 |
| `radio.connected` | 1 while connected and answering. API 13 |

And reserved `strings` (API 13), which a text layer shows and a `when`
tests; one the radio has not given is empty:

| String | |
| --- | --- |
| `radio.mode` | As the radio reports it: `USB`, `CW`, `DATA-USB`, …; last known, like the frequency |
| `radio.tuner` | `inline`, `bypassed`, `tuning` or `failed` |
| `radio.status` | `connected`, `connecting`, `disconnecting`, `disconnected` or `error` |

Except where it says otherwise, a reading is given only while the radio is
connected and answering, the same rule `readRadio()` keeps, so a scene and a
render never disagree about the radio. A reading the radio has not given,
or no longer fresh, is missing: the bottom of a binding's range, and `—` in
a text layer.
`radio.secondsSinceTransmit` is re-read on its own for fifteen seconds after
a transmission, so a hold or a fade bound to it ends on time.

## Examples

`k2hrc-panel-scenes` in the SDK's samples has every control, a control faded
in over artwork and a click-through layer; `k2hrc-panafall` is a panadapter
and waterfall. `ki2d-radio-panel`, `ki2d-weather-panel` and `ki2d-band-map`
in [ham2k/extensions](https://github.com/ham2k/extensions) are published
scene panels.
