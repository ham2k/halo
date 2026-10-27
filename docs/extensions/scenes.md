# Panel scenes

A panel's `render` ([Panel hooks](panels.md)) may answer a **scene** instead
of a document. This experimental fourth kind of panel content adds SVG and
text layers, numeric bindings, local controls, native Material controls, a
layout, and host-run animations, which the app draws and keeps live itself:
the extension renders a scene when something changes and answers `onEvent`
when the operator uses a control, while a value moving under a binding, a
local control and an animation frame cost no bridge call at all.
Its payload is `{kind: 'scene', scene, title?, triggers?}`; it does not have a
`content` string. `kind: 'svgScene'` is the same kind under its name through SDK 0.9,
which the SDK keeps as a deprecated alias along with the `SvgScene*` type names.

## Versions

**`scene` and everything it adds are extension API 5**: native controls,
`strings`, `layout`, `after` and control `opacity`. A bundle using any of them
declares `"api": 5` ([distribution.md](distribution.md)), and an app speaking
less refuses it at install rather than showing the panel as an unknown kind.
A plain scene that must reach those apps keeps `svgScene` and its lower API.
**Extension API 7** adds the scene's host-fed `radio` values (*Radio values*
below), `scaleX`/`scaleY` bindings, text `glow`, a knob's `menu` and second
axis, and the spectrum control's `follow`, `span` and label `decimals`; a
bundle using any of them declares `"api": 7`.

## Bindings, events and local formatting

Scene-capable hosts pass
`instanceId` on render/event calls. `onEvent` handles control events and returns
value patches (`values`, and `strings` for string controls); local-only controls and animation frames make no bridge
calls. Controls with `continuous: true` send `change` events during dragging and a
final `commit` on release; pending movements are coalesced to the newest value.
Numeric text supports `scale`, `truncate`, `modulo`, and `minIntegerDigits`
for local numeric formatting; bindings accept `scale`, `truncate` and `modulo`
too, applied to the value before the ramp. KI2D’s Radio Panel uses these for its Modern
frequency groups; its settings offer Modern/LCD styles and radio selection. Local sliders may use `hover` and `discrete` hourly buckets. Text `samples`
may hold numbers or preformatted strings; control `valueLabels` supplies accessible
value descriptions. A layer binds `rotation`, `translateX`/`translateY`,
`scaleX`/`scaleY` and `opacity`; rotation and scale turn about its `pivot`, so
`scaleX` with `pivot: [0, 0.5]` grows a bar's fill from its left end.
Transform/opacity bindings may also supply numeric `samples`,
equally spaced over their `input` range, instead of the `output` ramp. The host
interpolates and clamps these locally; chart markers and callouts can follow
individual readings without bridge calls. See [the design notes and open milestones](../design/panel-scenes.md)
and the `k2hrc-panel-scenes` sample. This API is experimental.

## The render environment

Scene-capable hosts also supply `args.environment` on **render and event** calls:

- `width`, `height`, and `safeInsets` describe the current panel in logical pixels.
  The app's Font Scale is already applied to this coordinate space. Do not multiply
  coordinates by a font-scale preference or `devicePixelRatio`.
- `brightness` is resolved to `light` or `dark`, including system theme changes.
  `colors` contains `surface`, `surfaceContainer`, `onSurface`, `onSurfaceVariant`,
  `accent`, `primary`, `onPrimary`, `secondary`, `outline`, `outlineVariant`,
  `error`, and `onError`, all `#RRGGBB` strings.
- `typography` contains `body`, `label`, `title`, `display`, and `mono` roles, each
  with `fontFamily`, fallbacks, `fontSize`, `scaledFontSize`, `fontWeight`,
  `lineHeight`, and `letterSpacing`. Family can be null for a platform default.
  `scaledFontSize` describes OS accessibility scaling **at that role's size**;
  do not assume one linear factor for all sizes. Use it when reserving label space.
  Supply the unscaled `fontSize` as scene text `size`: the host scales text once.
- `locale`, `textDirection`, `devicePixelRatio`, `reducedMotion`, and `highContrast`
  describe the resolved presentation context. Font names refer to host fonts;
  they are not URLs or permission to load remote fonts.

For a panel showing a scene, environment changes automatically request a
render through the existing throttle, even with no triggers declared. Hidden
panels catch up on reveal; repeated resize updates coalesce; a scene laid out for
an old environment cannot overwrite a newer one. Markdown and HTML panels are
themed and laid out by the host, so an environment change does not re-render
them; their next render carries the current environment.
`args.clock.nowMillis` follows the app clock; `realNowMillis` is for network retry
and cache budgets, so developer time travel does not hammer an external API.
Both `environment` and `clock` are optional in the SDK for older-host detection.

## Text and menus

Use scene **text layers** for typography; SVG `<text>` is not a portable text path
through the renderer. Text supports either `literal` or bound `value`, plus
`fontFamily`, `fontWeight`, `lineHeight`, and `letterSpacing`. Text participates
in native directionality, accessibility scaling and semantics. A text `glow`
(`#RRGGBB`) draws a soft halo of that colour around the letters, to keep them
legible over busy artwork.
Button controls can supply `menu: [{label, event}]` to open a native dropdown.
Selecting an item emits its `event` as the action with the original control ID;
dismissing the menu emits nothing. A knob takes a `menu` too: a click opens it,
while a scroll or a drag still turns the knob.

## Native controls

**Native controls.** Besides the drawn `button`, `slider` and `knob` — invisible
hit areas over the extension's own artwork — a scene can use Material widgets
the app themes itself: `nativeButton`, `nativeSlider`, `nativeTextField`,
`nativeDropdown`, `nativeSwitch`, `nativeCheckbox`, `nativeRadio`,
`nativeSegmented`, `nativeChip` and `nativeText`. `PanelSceneControl` in the SDK
lists what each kind takes. String-valued controls (text field, dropdown, radio,
segmented) bind to the scene's `strings` map, which sits beside `values`; a key
is in one or the other, never both; a choice's string is `""` or one of its
`options` (each comma-separated part, for `multi`). Their events carry `text` instead of `value`,
and an `onEvent` result may return `strings` as well as `values`. A text layer
whose `value` names a string shows it as-is. A text field commits on Enter, or
on leaving it after typing; a render that lands while the operator is typing
does not overwrite the typing. Every control's `label` is its accessible name;
the app has no tooltips. A text field or dropdown in a panel keeps keyboard
focus; clicking any other native control hands focus back to the callsign
field, as clicking a button anywhere else in the Operation view does. A drawn
`button` never takes focus from a click, so the operator's typing stays where
it was. A drawn `slider` or `knob` clicked or dragged holds focus for three
seconds after its last use — long enough for the arrow keys to adjust it — then
hands it back to wherever it came from. Focus that arrives by Tab stays.

## Layout

**Layout.** A native control either has an `x`/`y`/`width`/`height` rect over the
artwork, like the drawn kinds — it takes the rect's width and its own height, up
to the rect's, so give a field a rect tall enough for it — or omits all four and is placed by
`scene.layout` — a tree of Flutter's `row`, `column` and `wrap`, with `flex`/`fit`
(Expanded and Flexible), `width`/`height`, `padding`, `spacing`, the two axis
alignments, `{spacer: flex}`, `{control: id}`, and `{scene: true}` for the
artwork, scaled to fit. Sizes are logical pixels, like the render environment's.
Every rect-less control appears in the layout exactly once; a layout with no
`scene` node shows no artwork, so it may declare no layers either. A text field
or dropdown given no width (a row child without `flex` or `width`) is 200 wide,
and a row's children that do not fit overflow as a Flutter `Row`'s do — use
`flex` or `wrap`. A `flex` only shares space its row or column has: in a row
that is itself an unflexed child of a row, there is none, and its children lay
out at their own size. The layout is at most 8 deep and 128 nodes.

## Controls among the layers

**Controls among the layers.** Layers paint in order, and a control with a rect
paints above all of them unless its `after` names a layer: then it paints
directly after that one, and later layers draw over it. Layers are
click-through: art painted over a control does not stop it working. A layer with
`blocksPointer: true` takes the clicks that land on it while it is visible,
covering the controls under it (keyboard focus still reaches them; mark them
`disabled` too to shut them off). Only a pending action disables action
controls; a value being sent does not. Any control can take an `opacity`, fixed or bound like a layer's;
at 0 it takes no clicks, focus or screen-reader node.

## Events and the panel's config

An `onEvent` that cannot read its panel's config is refused rather than run
with an empty one, since a config is where a panel keeps which radio it
commands. The host allows an event up to about ten seconds in all (config, then
the hook); the control shows its pending value until the outcome is known.

## Scene reference

The schema in one place; `panelScene.ts` in the SDK carries the same as types.
Every rule below is checked when the scene arrives: a scene that breaks one is
refused whole, and the pane shows the error naming what is wrong, rather than
drawing part of it.

**The scene document**

| Field | |
|---|---|
| `version` | `1` |
| `width`, `height` | The artwork's viewBox, in scene units. Size it to `environment.width`/`height` and a scene unit is a logical pixel. |
| `values` | `{name: number}`: what bindings, numeric text and numeric controls read. At most 256. |
| `strings` | `{name: string}`: what text fields and choices hold. At most 256, each up to 4096 characters. A name is in `values` or `strings`, never both. |
| `layers` | Painted in order, each over the ones before: `svg` artwork, `text`, or an `icon`. At most 512 (128 before extension API 12), and 1 MiB of artwork and text in all. |
| `controls` | At most 256 (64 before extension API 12). Drawn or native; see below. |
| `layout` | Optional. Where rect-less native controls and the artwork go; omitted, the artwork fills the pane. |
| `scroll` | Optional, `{axis?, value, event?}` (extension API 12): a scene longer than its pane along `axis` (`y` by default), scrolled natively by the app — wheel, trackpad and drag, a drag begun on a button included — with no call to the extension. It fills the pane across and runs on past it. The position, in scene units, is written to the scene value `value`; a render that changes that value moves the view there, one that leaves it alone leaves the operator's scroll alone. `event` is sent as a `commit`, the position as `value`, once a scroll comes to rest. Layers and controls with `fixed: true` stay put over the pane, in pane coordinates. A drag along the scroll on a slider or knob that scrolls with the content is the scroll's: make one that must be dragged `fixed`. Not with `layout`. |
| `radio` | Optional, `{node?}`: the host feeds that radio's live readings into the reserved `radio.*` values. `node` is an id from `listRadios`; omitted, the logging radio. See *Radio values*. |

**Controls.** Every control has an `id` and a `label`, which is its accessible
name. An `event` names the action sent when it is used; without one the control
is local-only: its value changes on screen, survives renders, and never reaches
the extension. `value` names what it shows and sets.

| Kind | Binds to | Sends | Also takes |
|---|---|---|---|
| `button` | — | `activate` | `menu`, `tapAt` (extension API 12: a click's `value` is where along the button's longer side it landed, 0 at its top or left end to 1 at its bottom or right; a key or screen reader activates it with none; it needs an `event` and takes no `menu`) |
| `slider` | number | `commit` | `min`, `max`, `step`, `discrete`, `hover`, `valueLabels`, `continuous`, `scrollThrough` |
| `knob` | number | `commit` | `min`, `max`, `step`, `sensitivity`, `invertDrag`, `scrollThrough`, `valueLabels`, `continuous`, `menu`, a second axis (`valueY`, `eventY`, `minY`, `maxY`, `stepY`, `sensitivityY`) |
| `nativeButton` | — | `activate` | `variant` (`filled`, `tonal`, `outlined`, `text`), `icon`, `menu`; needs `event` or `menu` |
| `nativeSlider` | number | `commit` | `min`, `max`, `step`, `valueLabels`, `continuous` |
| `nativeTextField` | string | `commit` on Enter, or on leaving it after typing | `placeholder`, `continuous` |
| `nativeDropdown` | string | `commit` | `options`, `placeholder` |
| `nativeRadio` | string | `commit` | `options` |
| `nativeSegmented` | string | `commit` | `options`, `multi` |
| `nativeSwitch`, `nativeCheckbox` | number, 1 or 0 | `commit` | — (shows `label` beside it) |
| `nativeChip` | number, 1 or 0; or none | `commit`; `activate` without a value | `icon`; needs `event` without a value |
| `nativeText` | number, string, or none | nothing | `style` (a typography role), `align` (`start`, `center`, `end`) |
| `spectrum` | — | `commit` with the frequency clicked; `activate` from an annotation | see *Spectrum* below |
| `zoom` | — | `commit` with the factor, on release | `min`, `max` (the factors allowed); only in a scene with `scroll`; extension API 12 |

The three drawn kinds are invisible hit areas over artwork the extension paints;
the native kinds are Material widgets the app paints and themes. Every control
may also take:

- `x`, `y`, `width`, `height`: its rect over the artwork, in scene units.
  Required for the drawn kinds; a native control omits all four to be placed by
  `layout` instead, and takes the rect's width and its own height when it has one.
- `after`: with a rect, the layer it paints directly after.
- `opacity`: 0 to 1, fixed or bound like a layer's. At 0 the control is gone.
- `disabled`: shown, but no click, drag, key or screen-reader adjustment acts on it.
- `hoverSet` (drawn kinds only; extension API 12): `{value, to}`. While the
  pointer is over the control, the scene value `value` reads `to` — set by the
  host, with no call to the extension — and leaving puts back the scene's own
  value. A layer bound to it lights up under the pointer, and several controls
  naming one value with different `to`s light up one thing each. It survives
  renders while the pointer stays.

`options` is `[{label, value}]`, up to 64, with each `value` unique. A choice's
string is `""` or one of them; a `multi` choice holds its values joined with
commas in option order, so no option may contain one. `menu` is
`[{label, event}]`, up to 32: picking an item sends its `event` as the action.

A `zoom` strip is drawn by nothing: it claims a drag that begins on it along a scrolling
scene's axis. Away from the pane's middle zooms in and toward it zooms out, by the ratio of
the two distances from the middle, clamped to `min`…`max`. While the drag lasts the app moves
each layer and control to where the zoom puts its middle, keeping its size, so text and dots
stay as drawn and only spread apart or close in; a layer with `stretch: true` — a background,
a line the length of the scene — scales along the scroll instead. That preview holds until
the render that answers the `commit` arrives, so a scene meant to zoom draws its pieces as
layers of their own rather than as one picture. A tap on the strip still reaches the button there, and a drag that starts off it
still scrolls. A trackpad's two-finger swipe scrolls on the strip as anywhere else; a trackpad
pinch begun on it zooms by the pinch's own scale, clamped the same way, and commits as a drag does.

A scroll steps a slider or knob by its `step`, down and left lowering it; a one-axis
control takes a sideways scroll by its own direction. A slider or knob with
`scrollThrough` (API 12) also takes the scrolls landing on drawn buttons over it, so labels
drawn over a knob that scrolls the artwork do not stop the scroll; anything else in the
way — a native control, a `blocksPointer` layer, another slider or knob — keeps the scroll
from it.
A knob with `invertDrag` (API 12) moves the other way to a drag, as content held under
the finger does — what a knob that scrolls the artwork wants — while its scroll is unchanged.

A knob with `valueY` sets two numbers from one patch of artwork — a passband's
shift across and its width up, say. Horizontal dragging, horizontal scrolling
and the left/right keys set `value`; vertical ones and the up/down keys set
`valueY`, which must be in `values`, with its own range, step and feel from the
`…Y` fields. The second axis sends its events with the action `eventY`, which a
knob with an `event` must give, different from `event` — an event carries no
other mark of which axis moved, and a scene without one is refused. The host queues the two axes separately, so neither
replaces the other's pending value, and a drag commits only the axes it moved.

**Layout nodes.** Each is an object with exactly one of these keys:

| Node | |
|---|---|
| `{row: [...]}`, `{column: [...]}` | Flutter's `Row` and `Column`. `mainAxisAlignment` (`start`, `center`, `end`, `spaceBetween`, `spaceAround`, `spaceEvenly`), `crossAxisAlignment` (`start`, `center`, `end`, `stretch`), `spacing`. |
| `{wrap: [...]}` | Flutter's `Wrap`: `spacing`, `runSpacing`, the same alignments but no `stretch`. |
| `{control: "id"}` | A native control without a rect. Each appears exactly once. |
| `{scene: true}` | The artwork, scaled to fit. At most once. |
| `{spacer: n}` | `Spacer(flex: n)`. |

Any node may add `width`, `height` and `padding` (one number, or
`[start, top, end, bottom]`). A row or column's direct child may add `flex`, with
`fit: "tight"` (the default, Flutter's `Expanded`) or `"loose"` (`Flexible`). At
most 8 deep and 128 nodes.

**Events and results.** `onEvent` receives, beside the render args:

```ts
event: {
  controlId: string      // the control's id
  action: string         // its `event`, or the menu item's
  phase: "activate" | "change" | "commit"
  sequence: number       // increases with every event from this pane
  value?: number         // for a control bound to `values`
  text?: string          // for a control bound to `strings`
}
```

It answers `{values, strings?}`: a patch of names already in the scene. An
answer with neither is taken as a failure, and so is one that throws or runs out
of time: the pane says the action failed, and the control goes back to what the
scene last reported. The host sends one event at a time, keeps only the newest
of a control's queued changes, ignores an answer to an event a newer one has
superseded, and requests a render after each. Action controls are disabled while an
action is waiting for its answer; a value being sent does not disable them. A text field's typing is sent before any action, and an
action queued behind a value the extension refused is not sent.

**An example.** A spot form over a status strip:

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
        version: 1,
        width: 400,
        height: 40,
        values: {},
        strings: state,
        layers: [
          {
            id: "strip", x: 0, y: 0, width: 400, height: 40,
            svg: '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 400 40"><rect width="400" height="40" rx="8" fill="#142337"/></svg>',
          },
          { id: "status", x: 12, y: 8, width: 376, height: 24, text: { value: "status", size: 14, color: "#a9efcf" } },
        ],
        controls: [
          { id: "call", kind: "nativeTextField", label: "Callsign", value: "call", event: "set" },
          {
            id: "band", kind: "nativeDropdown", label: "Band", value: "band", event: "set",
            options: ["40m", "20m", "15m"].map((b) => ({ label: b, value: b })),
          },
          { id: "spot", kind: "nativeButton", label: "Spot", icon: "bullhorn", event: "spot" },
        ],
        layout: {
          column: [
            { row: [{ control: "call", flex: 1 }, { control: "band", width: 110 }, { control: "spot" }], spacing: 8 },
            { scene: true, flex: 1 },
          ],
          padding: 12,
          spacing: 8,
          crossAxisAlignment: "stretch",
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

The callsign comes back upper-cased, and the field shows the extension's
version once the typing is committed. A bundle carrying this declares
`"api": 5`. The `k2hrc-panel-scenes` sample in the SDK has every kind, a
control faded in over the artwork, and a click-through layer painted over it.

## Spectrum

A `spectrum` control is a radio's panadapter and waterfall, drawn by the host
from sweeps that never reach the extension. It is **extension API 6**, as is
`host.setRadioSpectrum` ([Radio control](radio.md#the-scope)): a bundle using either declares `"api": 6`, and an app speaking less refuses it at install
rather than failing to render the scene. It needs `requiresRadioRead`; without it, or on a host or radio
without a spectrum, the control says why instead. It is placed like a native
control and takes the fields of `PanelSceneSpectrum` in the SDK:

- `radio` (an id from `listRadios`; omitted, the designated radio), `display`
  (`both`, `pan`, `waterfall`), `split`, and `flow` — which way the waterfall
  moves (`down`, `up`, `right`, `left`), the panadapter on the side it comes
  from.
- `rising` (extension API 12): which way frequency increases, across the
  flow — `right` or `left` for `down` and `up`, `down` or `up` for `right` and
  `left`; one along the flow is refused. Omitted, each flow is `down` turned a
  quarter, never mirrored: `right` for `down` and `up`, `up` for `right`,
  `down` for `left` (before API 12, `left` rose up the screen too). Text stays
  upright, and offsets, `align` and pointer corners are measured as if
  frequency rose to the right.
- `floor`, `range`, `average` (0–99, default 40), `fps` (default 15),
  `waterfallSpeed`, `waterfallFloor`, `waterfallRange`: numbers, or the names
  of scene values the control reads on every sweep.
- Colors (`#RRGGBB` or `#AARRGGBB`): `palette` or `waterfallColors`,
  `traceColor`/`traceWidth`, `fillColor`/`fillColorBottom`, `backgroundColor`,
  `gridColor`/`gridDashed`, `waterfallGridColor`.
- `center`: the tuned-frequency line, styled per part.
- `overlays`: up to 16 lines (`at`) and areas (`from`, `to`) in Hz from the
  tuned frequency, the sweep's middle, or absolute, each styled per part.
- `scale`: the gap between the panadapter and the waterfall, its fill and
  borders, and frequency `labels` and `ticks`. `labels.decimals` (0–6) fixes
  the decimals of MHz every label shows; omitted, as many as tell one label
  from the next.
- `span`: Hz shown across the control, from the middle of each sweep — a
  number or a scene value. A wider sweep is cropped to it, so a radio whose
  scope comes in a few fixed widths can be shown at any narrower one; set the
  scope to the narrowest that covers it. Everything is drawn, labelled and
  clicked on the window shown. Where the radio's `spectrum` says `autoSpan`
  (extension API 12), the app sets the scope itself, to the narrowest span
  covering the widest `span` among the spectrum controls on screen, so each
  panel names its width here and leaves `setRadioSpectrum`'s `spanHz` alone.
- `follow` (0–0.45): keeps the tuned frequency at least this share of the
  width from either edge, by moving the radio's scope just far enough to put
  it on that margin — the picture scrolls with the dial rather than jumping
  to centre it. Only where the radio lets the app place its scope (a
  FlexRadio, whose panadapter in SmartSDR moves with it) and the panel
  declares `requiresRadioWrite`; elsewhere it changes nothing.
- `annotations`: up to 64 pieces of text at frequencies, with a pointer to
  where they sit. One with an `event` sends `activate` when clicked, its
  frequency as `value` and its `id` as `annotation`, and does not tune.
- `hoverHz`, `hoverDb`: scene values the pointer writes, for a text layer.
- `tuneStep`: a click elsewhere sends `commit` with the frequency under it,
  rounded to this many Hz. The extension decides whether to tune.

Each waterfall row stays at the frequencies it was taken on: when the radio
retunes its scope the history slides sideways, and when the span changes it
stretches, rather than old signals being redrawn where they never were.

## Radio values

A scene with a document-level `radio` block (extension API 7) is fed that
radio's live readings by the host, into reserved values a binding, a text
layer or a control's `opacity` can read like any other:

| Value | |
|---|---|
| `radio.signalDbm` | Receive signal, dBm. |
| `radio.powerOut` | RF out, watts. |
| `radio.swr`, `radio.alc`, `radio.supplyVolts` | The transmit meters. |
| `radio.transmitting` | 1 or 0. |
| `radio.swrAverage` | The SWR averaged over the transmission under way, or else over the last one — only readings taken with RF out count. |
| `radio.secondsSinceTransmit` | 0 while transmitting, then counting up; a very large number when there has been no transmission. |

They change as the radio reports them — several times a second — with no
render and no bridge call, so a meter needle moves at the radio's rate while
the extension renders once a second or not at all. A reading the radio has
not given, or no longer fresh, is missing: a binding takes it as the bottom
of its range and a text layer shows `—`. `radio.secondsSinceTransmit` is
re-read on its own for fifteen seconds after a transmission, so a hold or a
fade bound to it ends on time. The names are reserved — a scene may not
declare them in `values` or `strings` — and readable only with the block;
nothing may set them. The feed needs `requiresRadioRead`: without it every
reading is missing.

## Reference panels

The `ki2d-weather-panel`, `ki2d-solar-panel` and `ki2d-radio-panel` reference
panels live in
[ham2k/extensions](https://github.com/ham2k/extensions/tree/main/extensions/dashboard).
They use public host APIs and ship as `.h2kext` packages, not app assets.
Install the packages, then add their panels through Edit Layout. See that
repository's dashboard README for building them.
