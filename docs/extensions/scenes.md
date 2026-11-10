# Panel scenes

A [panel](panels.md)'s `render` may answer a **scene** instead of a
document: SVG artwork, text and icon layers, numeric bindings, controls the
app draws or Material controls it themes, a layout, host-run animations and
the radio's live readings. The app draws it and keeps it live itself. Your
extension renders a scene when something changes and answers `onEvent` when
the operator uses a control; a value moving under a binding, a local control
and an animation frame cost no bridge call at all.
[Guidelines](guidelines.md#dashboard-panels) says when a panel should be a
scene, and how one takes its colors from the app and offers its own.

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
| 6 | the band scope control (`spectrum`) and `host.setRadioSpectrum` |
| 7 | the `radio` block and its values, `scaleX`/`scaleY` bindings, text `glow`, a knob's `menu` and second axis, the band scope's `follow`, `span` and label `decimals` |
| 12 | up to 512 layers and 256 controls, `icon` layers, `scroll` and the `zoom` strip, `hoverSet`, `tapAt`, `scrollThrough`, `invertDrag`, the band scope's `rising` and `autoSpan` |
| 13 | the radio's dial in the values (`radio.frequencyHz` and the rest marked so below), `radio.mode`, `radio.tuner` and `radio.status` in `strings`, and `when` on layers and controls |
| 17 | `bandScope` as the band scope's kind, `spectrum` for its upper section where it took `pan`, and its `gestures`, default axis and `levelScale`, `vfoLabel`, `widthHz`, `stepHz` and `vfoHz`, `layers`, and a click's step that follows the zoom |
| 19 | `radio.reportedFrequencyHz`, the radio's own report beside the dial |
| 20 | the band scope's `minWidthHz` and `maxWidthHz`, its `vfoLabel`'s `arrow`, up to 512 of its `layers` and 256 `annotations`, and an annotation's `collapsed` |
| 22 | the band scope's `window` and `centerHz`, an annotation's `baseline`, `stretch`, `more`, `badge`, `openBorder`, `openBackground` and `padding: { x, y }`, a collapsed one's `width: 'box'`, a zoom's `commit` of its middle as a pan, and its axis labels' and ticks' `align`; an annotation's `secondaryEvent`, sent on a right-click; `radio.compression`; `cells`, the `grid` and `cell` layout nodes, and a layout up to 12 deep and 512 nodes; a slider's or knob's `invertScroll`; named `sources` for radios, rotators and antenna switches, a band scope's `radio` naming one; a layer's `clipX` and `clipY`, and a binding's `hold` |
| 23 | the rotator map control (`rotatorMap`), a `nativeButton`'s `icon` variant, and an event's `bearing` and `km` |

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
| `layout` | Optional. Where rect-less native controls, cells and the artwork go; omitted, the artwork fills the pane |
| `cells` | Optional, `[{ id, width, height }]` (API 22): pieces drawn at their own size, below. At most 256. Each needs a `layout` to place it |
| `scroll` | Optional, `{ axis?, value, event? }` (API 12): a scene longer than its pane along `axis` (`y` by default), scrolled natively by wheel, trackpad and drag (a drag begun on a button included) with no call to the extension. It fills the pane across and runs on past it. The position in scene units is written to the scene value `value`; a render that changes that value moves the view, one that leaves it alone leaves the operator's scroll alone. `event` is sent as a `commit`, the position as `value`, once a scroll comes to rest. Layers and controls with `fixed: true` stay put over the pane, in pane coordinates; a drag along the scroll on a slider or knob that scrolls with the content is the scroll's, so make one that must be dragged `fixed`. Not with `layout` |
| `radio` | Optional, `{ node? }` (API 7): the app feeds that radio's live readings into the reserved `radio.*` values. `node` is an id from `listRadios`; omitted, the logging radio |
| `sources` | Optional (API 22): radios, rotators and antenna switches fed live under names of the scene's own; [Named sources](#named-sources) |

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

`clipX` and `clipY` (API 22) show a share of the layer, 0 to 1, growing from
its `pivot` as a scale does but keeping the artwork's shape: a bar of LED
segments drawn whole lights segment by segment where a scale would squash
it, and with `scale` and `truncate` before the ramp it steps a segment at a
time. A binding's `hold` (API 22), `{ ms, fallPerSecond? }`, makes it a peak
meter: the highest reading stands for `ms` after the reading drops, then
falls toward it at `fallPerSecond` in the bound value's own units (by
default the whole input range a second, and never slower than the whole
range in ten minutes), with no render. A steady reading holds nothing. Only a
layer's bindings hold, with a positive `scale` and no `modulo`. A reveal's
`output` and `samples` are shares from 0 to 1, and a `blocksPointer` layer
can neither reveal nor hold: it would take clicks where nothing is drawn.

**Text layers** are the typography path; SVG `<text>` is not portable through
the renderer. A text layer takes a `literal` or a bound `value` (a number
or a string name), `size`, `color`, `fontFamily`, `fontWeight`,
`lineHeight`, `letterSpacing`, and a `glow` color that draws a soft halo
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

**Cells** (API 22) are pieces of the scene drawn at their own size in
logical pixels, never scaled with the pane: a meter 144 wide is 144 wide in
any pane, and the layout moves it rather than shrinking it. A cell is
declared in `cells` with its `width` and `height`, and placed by a
`{ cell: id }` node in the layout. A layer or a control with `cell` belongs
to it: its rect is in the cell's coordinates, 0,0 at the cell's top left,
and the cell clips what it paints. Bindings, `when`, `hoverSet` and events
work in a cell as anywhere else, and the scene's budgets count every cell's
pieces together. A control in a cell needs a rect, its `after` names a layer
in the same cell, and nothing in a cell is `fixed`.

## Controls

Every control has an `id` and a `label`, its accessible name; the app has no
tooltips. An `event` names the action sent when it is used; without one the
control is **local-only**: its value changes on screen, survives renders,
and never reaches the extension. `value` names what it shows and sets.

| Kind | Binds to | Sends | Also takes |
| --- | --- | --- | --- |
| `button` | | `activate` | `menu`; `tapAt` (API 12: a click's `value` is where along the longer side it landed, 0 at the top or left end to 1; a key or a screen reader activates with none; needs an `event` and takes no `menu`) |
| `slider` | number | `commit` | `min`, `max`, `step`, `discrete`, `hover` (local-only sliders), `valueLabels`, `continuous`, `scrollThrough`, `invertScroll` |
| `knob` | number | `commit` | `min`, `max`, `step`, `sensitivity`, `invertDrag`, `invertScroll`, `scrollThrough`, `valueLabels`, `continuous`, `menu` (a click opens it; a scroll or a drag still turns the knob), a second axis (`valueY`, `eventY`, `minY`, `maxY`, `stepY`, `sensitivityY`) |
| `nativeButton` | | `activate` | `variant` (`filled`, `tonal`, `outlined`, `text`, or from API 23 `icon`, the icon alone with `label` its accessible name), `icon`, `menu`; needs `event` or `menu` |
| `nativeSlider` | number | `commit` | `min`, `max`, `step`, `valueLabels`, `continuous` |
| `nativeTextField` | string | `commit` on Enter, or on leaving it after typing | `placeholder`, `continuous` |
| `nativeDropdown` | string | `commit` | `options`, `placeholder` |
| `nativeRadio` | string | `commit` | `options` |
| `nativeSegmented` | string | `commit` | `options`, `multi` |
| `nativeSwitch`, `nativeCheckbox` | number, 1 or 0 | `commit` | shows `label` beside it |
| `nativeChip` | number, 1 or 0, or none | `commit`; `activate` without a value | `icon`; needs `event` without a value |
| `nativeText` | number, string, or none | | `style` (a typography role), `align` |
| `bandScope` | | `commit` with the frequency clicked, where the scene hears its tunes; `activate` from an annotation or a layer; `change` and `commit` for a zoom, pan, split or level drag it hears | below |
| `rotatorMap` | | `commit` with the bearing clicked, where the scene hears its turns; `activate` from a decoration; `commit` for a zoom or pan | below |
| `zoom` | | `commit` with the factor, on release | `min`, `max` (the factors allowed); needs `event`; only with `scroll`; API 12; below |

The three drawn kinds are invisible hit areas over artwork you paint; the
native kinds are Material widgets the app paints and themes. Every control
may also take:

- `x`, `y`, `width`, `height`: its rect in scene units. Required for the
  drawn kinds; a native control omits all four to be placed by `layout`, and
  with a rect takes its width and its own height, up to the rect's, so give a
  field a rect tall enough for it.
- `cell` (API 22): the [cell](#layers-and-bindings) it is drawn in, its
  rect in that cell's coordinates.
- `after`: with a rect, the layer it paints directly after, in the same
  cell or none. Otherwise a control paints above every layer.
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
native control hands focus back to the callsign field. A drawn `button`,
`slider` or `knob` takes no focus from a click or a drag, so the operator's
typing stays where it was; Tab reaches it, and the arrow keys then adjust a
slider or knob. A scroll steps a slider or knob by
its `step`, down and left lowering it, and a one-axis control takes a
sideways scroll by its own direction. `scrollThrough` (API 12) lets a slider
or knob also take the scrolls landing on drawn buttons over it, so labels
drawn over a knob do not stop the scroll; anything else in the way (a native
control, a `blocksPointer` layer, another slider or knob) keeps the scroll
from it. `invertDrag` (API 12) moves a knob the other way to a drag, as
content under a finger does, while its scroll is unchanged. `invertScroll`
(API 22) turns a slider's or knob's scroll around: down and left raise it.

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
of `row`, `column`, `wrap` and `grid` nodes, which also places the artwork
and the cells:

| Node | |
| --- | --- |
| `{ row: [...] }`, `{ column: [...] }` | `mainAxisAlignment` (`start`, `center`, `end`, `spaceBetween`, `spaceAround`, `spaceEvenly`), `crossAxisAlignment` (`start`, `center`, `end`, `stretch`), `spacing` |
| `{ wrap: [...] }` | `spacing`, `runSpacing`, the same alignments but no `stretch` |
| `{ grid: [...] }` | Slots, below (API 22) |
| `{ control: "id" }` | A native control without a rect. Each appears exactly once |
| `{ cell: "id" }` | A cell, at its own size (API 22). Each appears exactly once |
| `{ scene: true }` | The artwork, scaled to fit. At most once; a layout without it shows no artwork, and a scene drawn entirely in cells needs none |
| `{ spacer: n }` | Flexible empty space |

Any node may add `width`, `height` and `padding` (one number, or
`[start, top, end, bottom]`); a row or column's direct child may add `flex`
with `fit: "tight"` (the default) or `"loose"`. Sizes are logical pixels. A
text field or dropdown given no width is 200 wide; a row's children that do
not fit overflow, so use `flex` or `wrap`. A `flex` only shares space its row
or column has: in a row that is itself an unflexed child of a row there is
none, and its children lay out at their own size. The layout is at most 12
deep and 512 nodes (8 and 128 before API 22).

### Grids

A grid (API 22) puts its children in slots, row by row in the order written,
each at the first place it fits from where the one before it went, so what
comes later never goes back into a hole left earlier. A narrower pane moves
children onto more rows; nothing is scaled.

```js
layout: {
  grid: [
    { cell: "smeter", span: [3, 2] },
    { grid: [{ cell: "cw" }, { cell: "ssb" }, { cell: "fm" }], columns: 6, style: { title: "Mode" } },
    { control: "band" },
  ],
  unit: [48, 48], gap: 4, padding: 8,
  style: { background: "surfaceContainer", radius: 8 },
}
```

| Field | |
| --- | --- |
| `unit` | `[width, height]` of one slot. The outermost grid needs one; a grid within a grid takes its parent's unless it names its own |
| `gap` | The space between slots, one number or `[across, down]`; inherited like `unit`, else 0 |
| `columns` | The grid's width in slots. Past the room it is given it scrolls sideways on its own, so a row of controls scrolls while the board around it stays put. Omitted, as many as fit, and never fewer than its widest child |
| `style` | The grid's box, drawn by the app: `background`, `border` (`{ color, width? }`), `radius`, and a `title` above the slots in the label typography. A color is one of the render environment's `colors` names, which follows the theme, or `#RRGGBB` / `#AARRGGBB`. A border `width` of 0 draws none |
| `padding` | Inside the box, between its border and the slots |

A grid's direct child takes `span: [across, down]` slots, the area it is
given whole; a cell without one takes the slots its size covers, centered in
them, and anything else one slot. A grid within a grid takes no `span`: one
with `columns` takes the slots its content needs, and one that wraps takes a
whole row of its parent and wraps within it. A grid or a cell within a grid is its
direct child, never inside a row or column in one.

A cell is never cut short or spread over its neighbors, so a layout that
would do either is refused when the scene arrives: a `span` smaller than its
cell's size or wider than its grid's `columns`, a wrapping grid wider than
its parent's `columns`, a `width`, `height`, `flex` or `padding` on a cell,
and a `width`, `height` or `padding` on a grid's child (the grid gives it its
slots; a grid's own `padding` is inside its box). A child covers at most 256
slots across and down, and all a scene's grids at most 16,384 between them.
A grid that has no width to fill, in a row with no `flex`, is as many slots
wide as its widest child.

The outermost grid fills the pane's width and scrolls the pane: down when
its rows run past the bottom, across when its widest child is wider than the
pane. These scrolls are the app's own and send no events. A grid that
scrolls is dragged by any pointer, a mouse included, except where a drag
begins on a knob in a cell, or goes mostly across on a slider in one, which
keeps it; a disabled one keeps nothing, and a trackpad's swipe scrolls. An edge with content
hidden past it fades out, and the fade thins away as that content runs out.

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
  annotation?: string               // a band scope annotation's id
  layer?: string                    // a band scope layer's id; API 17; a rotator map decoration's; API 23
  gesture?: "zoom" | "pan" | "split" | "floor" | "range" | "speed"  // a band scope gesture; API 17; a rotator map's zoom or pan; API 23
  at?: {                            // where a band scope annotation or layer was clicked; API 17
    x: number, y: number            // pixels in the control, the ones a layer's `px` measures
    sceneX?: number, sceneY?: number  // scene units, for a band scope placed by a rect
    part?: "spectrum" | "axis" | "waterfall"
    hz?: number                     // the frequency clicked
    db?: number, aboveNoiseDb?: number  // on the spectrum: the level clicked, on the radio's scale and above the noise
    ageSeconds?: number, atMillis?: number  // on the waterfall: the row's age, and when it was taken
    bearing?: number, km?: number   // on a rotator map: the bearing and distance from the station clicked; API 23
  }
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

## Band scope

A `bandScope` control is a band scope: a radio's spectrum and, under it, its
waterfall, drawn by the app from sweeps that never reach the extension. API 6,
with `host.setRadioSpectrum` ([Radio control](radio.md#the-scope)); before
API 17 its kind is `spectrum` and its spectrum `pan`, names it still reads the
same. It needs `requiresRadioRead`; without it, or on a host or radio without
a scope, the control says why instead. Placed like a native control, it takes:

- `radio` (an id from `listRadios`, or the name of one of the scene's radio
  [sources](#named-sources); omitted, the designated radio),
  `display` (`both`, `spectrum`, `waterfall`), `split`, and `flow`, which way
  the waterfall moves (`down`, `up`, `right`, `left`), the spectrum on the
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
- Colors (`#RRGGBB` or `#AARRGGBB`): `palette` or `waterfallColors`,
  `traceColor`/`traceWidth`, `fillColor`/`fillColorBottom`,
  `backgroundColor`, `gridColor`/`gridDashed`, `waterfallGridColor`.
- The trace (API 17): `traceColors` and `fillColors`, 2 to 8 stops lowest
  level first, color the trace and the fill under it by level, so a level
  keeps its color as the floor and range move — in place of `traceColor`,
  and of `fillColor` and `fillColorBottom`, which neither may be given
  beside. Plain colors spread evenly from the spectrum's bottom to its top;
  `{ color, at }` stops (all or none) each sit at a level, `at` measured as
  a layer's `y` is but on the spectrum alone: `noise` and dB above it, or the
  spectrum's edges and a share — `[{ color: '#FFFFFF', at: 'noise' },
  { color: '#FF3D9A', at: 'noise+3db' }]` turns the fill pink from just over
  the noise. Until the app has estimated the noise, the stops spread evenly. `traceDashed` draws
  the trace in dashes. `traceSmooth` (0 to 20) averages it across that many
  pixels of frequency and draws it as a curve; the waterfall, the hover
  level and the noise stay raw.
- `center`: the tuned-frequency line, styled per part (`spectrum`,
  `waterfall`); `overlays`: up to 16 lines (`at`) and areas (`from`, `to`) in
  Hz from the tuned frequency, the sweep's middle, or absolute, each styled
  per part. An area may also take a `trace` (API 17): `color`, `width`,
  `dashed`, `colors`, `fill` and `fillColors`, the trace's and its fill's
  look over its frequencies, each it leaves out the control's, a later
  area's over an earlier one's; `scale`: the gap
  between spectrum and waterfall, its fill and borders, and frequency
  `labels` and `ticks` — the axis a drag zooms on; omitted, the app draws its
  own (API 17; before it, none), and `false` is none. With `over` (API 17)
  it lies over the picture on a see-through background, taking no height
  of its own: `waterfall` (or `true`) across the waterfall's head,
  `spectrum` across the spectrum's foot. Labels read like every
  frequency in the app: MHz in bold, kHz at the labels' `weight`, Hz smaller.
  `labels: false` draws none; `labels.decimals` (0 to 6) fixes the decimals
  of MHz every label shows (omitted, every kHz digit and as many Hz as tell
  one label from the next). `labels.align` (API 22) says which edge of each
  label, across the axis as if flowing down, is at its `offset`: `start` its
  top, `end` its bottom, `center` its middle; with no `offset`, the gap's
  edge on that side. Turned sideways, `end` lines the labels up on the gap's
  waterfall side, each reaching back over the spectrum as far as it runs, so
  the gap can be as narrow as its ticks. `ticks.align` (API 22) is `start`
  (the default), each tick growing from its `offset` toward the waterfall, or
  `end`, growing back over the spectrum. From API 17 a label's tick is taller and heavier,
  with half-length ones between: every 100 Hz once labels are 1 kHz apart or
  closer and those are 4 pixels apart, else every 1 kHz where those are.
  A click on the axis tunes as one on the picture once no second click
  follows; a double click resets the zoom and tunes nothing.
- `vfoLabel` (API 17): the tuned frequency at the top of its line, larger
  than the axis's labels, over the passband the scene draws (its first
  area anchored to the dial), in the line's color over a see-through box of
  the spectrum's. `false` hides it. An object `{ mhz, khz, hz, hzDigits }`
  says how it is drawn: each part `{ fontFamily, size, weight, italic, color }`
  takes what it does not name from the part before it (the MHz from the
  label's own), except that the MHz is bold where the kHz is light (weight
  300) and the Hz is four fifths the kHz's size. `hzDigits` (0 to 3) always
  shows that many Hz digits, cut rather than rounded; `auto`, the default,
  shows as many as the frequency has, each sliding in or out as the dial
  needs it and kept while the dial moves. With the dial out of the window
  the label waits at the edge it is past, an arrow on that side pointing
  the way, and a click on either brings the window back centered on the
  dial where `pan` is native. `arrow` (API 20) styles it, `{ color, size }`
  (the line's color, under half the text's height), or `false` for
  none. A level strip lying over the picture at that edge keeps the label
  to the window's side of it.
- `levelScale` (API 17): a strip along the flow, `{ side, over, width,
  background, labels, ticks }`: dB along the spectrum, with no unit, and
  the waterfall's age in seconds along it, with theirs. `side` is `end`
  (the default) or `start` of the frequency's way across the screen: the
  right or left of a band scope flowing `down` or `up`, the bottom or top
  of one flowing `right` or `left`, its labels upright either way. `over`
  lays it over the picture on a see-through background (the default),
  `false` beside it. `width` is how deep it is, 40 by default upright and
  24 sideways. Its background, label text (`size`, `weight`, `color`,
  `fontFamily`, `italic`) and ticks (`color`, `width`, `length`) are the
  frequency axis's where it names none. Omitted, the app draws one;
  `false` is none. A double click on it puts the scene's own floor, range
  and speed back.
- `span`: Hz shown across the control, from the middle of each sweep, a
  number or a scene value. A wider sweep is cropped to it, so a radio whose
  scope comes in a few fixed widths can be shown at any narrower one; set the
  scope to the narrowest that covers it, and everything is drawn, labeled
  and clicked on the window shown. Where the radio's `spectrum` says
  `autoSpan` (API 12) the app sizes the scope itself to the narrowest span
  covering the widest `span` on screen, so a panel there names its width
  here and leaves `setRadioSpectrum`'s `spanHz` alone.
- `minWidthHz`, `maxWidthHz` (API 20): the narrowest and widest a zoom goes,
  in Hz, or `radio`, as each is when omitted: a hundred Hz or the narrowest
  sweep the scope can be made to send with its points 10 pixels apart, and
  what it can be made to show. A window wider
  than the scope can be made draws the spectrum and waterfall over the part
  it sweeps; past it the waterfall is blank and the spectrum shows a dashed
  line level with the trace's middle over its fill darkened, the two fading into each other
  over the sweep's last pixels, and the axis, layers and annotations run across the whole. There a pan moves only the window, stopping where the
  sweep reaches its edge, and with `follow` the scope follows the dial
  instead of the window: where the radio lets the app place it, moved just
  far enough to keep the dial that share of the sweep's own width from its
  edges.
- `window` (API 22): `{lowHz, highHz}`, the window shown until the operator
  pans. Over a sweep it is where the window centers, `span` its width, the
  picture over the part the sweep covers. While no sweep comes — no radio, a
  radio without a scope or with it off, or before the first sweep — it is the
  whole window: the axis, overlays, annotations and layers are drawn and the
  gestures work over a blank picture, as over a sweep that wide from a scope
  the app cannot move, so a zoom and a pan stay within it; the level strip is
  left out, and no message says why there is no picture. A sweep takes its
  place as it arrives; one that stops for 3 seconds gives it back, unzoomed.
  A band map names its band here and works the same with a scope or without.
- `centerHz` (API 22): the window's middle until the operator pans, for a
  panel keeping where the operator left it — a pan's `commit` says where, and
  from API 22 a zoom sends one too, since it moves the middle. One that
  changes takes the window back there. Omitted, `window`'s middle, or the
  sweep's.
- `follow` (0 to 0.45): keeps the tuned frequency at least this share of the
  width from either edge by moving the window just far enough — within the
  sweep a crop, past it the radio's scope — gliding there once the dial
  rests, so the picture scrolls with the dial rather than jumping to center
  it. Only where
  the radio lets the app place its scope and the panel declares
  `requiresRadioWrite`; elsewhere it changes nothing.
- `annotations`: up to 256 (64 before API 20) pieces of text at frequencies, each with a pointer.
  One with an `event` sends `activate` when clicked, its frequency as
  `value`, its `id` as `annotation` and where it was clicked as `at`, and
  does not tune. One with a `menu` (API 17, `[{ label, event }]` like a
  button's, and no `event` beside it) opens it where it was clicked, and
  sends the item picked the same way. One with a `secondaryEvent` (API 22)
  sends it the same way when right-clicked — taking it down, say; without
  one a right-click does nothing. An `icon` (`{ name, color? }`, an MDI
  or `fa-` name) is drawn before the text at its size, in the text's color
  unless it names its own; an app without it draws the text alone. Its
  `offset` is pixels up from the spectrum's foot or down from the
  waterfall's head, or from a `y` written as a layer's is: `noise+30db`
  stands it that far above the noise on any radio, once the app has
  estimated it, and an app without `y` measures from the edge. With
  `borderEdges: "near"` its border is only the edge facing that one, an
  underline on the spectrum. With `baseline` (API 22) its box runs from the
  tops of the capitals to the baseline rather than over the whole line, so
  `align` and `offset` place those, descenders hanging past it. With
  `stretch` (API 22, `{ from, to }` in Hz from its frequency, a passband) the
  box covers that span where it is longer than the box, the text centered in
  it. Its `padding` (API 22) may be `{ x, y }`, across the text and above
  and below it apart. Its `more` (API 22, up to 32 lines) shows under the
  text while the pointer is on it, or a touch has opened it, hanging down the
  screen from where the box stands, over any annotation it would overlap —
  the spots a label stands for; a click on it open says which line in its
  `at`'s `line`, 0 its own text, 1 the first of `more`. A line may be
  `{ text, icon }`; where any line has an icon, every line's text starts past
  an icon's room. A `badge` (API 22, `{ text, color?, background? }`) is a
  short count or tag after the text, a little smaller, in a pill. An
  `openBorder` (API 22, `{ color, width? }`) is drawn on the edge facing the
  one `offset` measures from while it is open, and an `openBackground`
  (API 22) fills its box then in place of its `background`. With `collapsed`
  (API 20: `true`, or
  `{ width }` in pixels, four fifths of the box by default, or from API 22
  `'box'`, the box's own width) it is drawn as
  a line that wide where that border would be, its hover reach mostly on
  the side away from the box, and whole only while the pointer is on the
  line or the box, over any annotation it would overlap, which waits
  meanwhile. A click on the line opens it first where nothing hovered (a
  touch), and is a click on the annotation once it is open.
- `layers` (API 17): up to 512 (128 before API 20) rectangles, lines, text and artwork placed by
  frequency, drawn over the picture under the annotations and moving with
  every zoom, pan and glide. Each has an `id` and a `kind` — `rect`, `line`,
  `text` or `svg` — and corners `x`, `y` and `x2`, `y2`: a rect or an svg
  fills the box between them, a line runs from one to the other, and text
  sits at the first, upright. `x` and `x2` run along the frequency, whichever
  way the control is turned: `freq:` and a number of Hz or a scene value, or
  `vfo` for this control's tuned frequency, then any of `±<n>hz`, which moves
  with the zoom, and `±<n>px`, which does not — `freq:14074000`,
  `vfo-1500hz`, `freq:spotHz+4px`. So `x: 'freq:14060000', x2:
  'freq:14060000+40px'` is a tag forty pixels wide at any zoom, and `x2:
  'freq:14150000'` a box covering the range. With no frequency, or as a
  number, `x` is pixels from the window's low edge. `y` and `y2` run across
  it: `spectrum`, `axis` or `waterfall` for that part's top (`:bottom` for
  its bottom), then any of `±<n>%`, a share of that part's height,
  `±<n>s` on the waterfall, seconds of its history, and `±<n>px` —
  `spectrum+30%`, `waterfall+5s`, `spectrum:bottom-12px`. Or `noise`, the
  noise on the spectrum as the app estimates it, then `±<n>db` above it,
  `±<n>%` of the spectrum's height and `±<n>px` — `noise+20db`. An item on a part stays on it, at the same share
  or age, as the operator moves the split or the waterfall's speed, and one
  above the noise stays that far above it as the floor and range change;
  with neither, or as a number, it is measured from the control's top, a
  share being of the control's height. Omitted, `y` is the control's top and
  `y2` its bottom; a part not shown draws nothing on it, nor the noise with
  no spectrum. Levels are dB on the radio's own scale, not calibrated dBm,
  so dB above the noise is the one level that means the same on every radio. A rect takes `fill` and an outline `color` and
  `width`, and `radius`; a line `color`, `width` and `dashed`; text either
  `text` or a scene `value` with `decimals`, `prefix` and `suffix`, and
  `align` (which end is at `x`), `valign` (which edge at `y`), `color`,
  `size`, `weight`, `fontFamily`, `italic`, `background` and `padding`; an
  svg its `svg`, stretched to its box. They are drawn in order over the
  picture, under the annotations; one with `behind: true` is drawn behind the
  spectrum's grid, areas and trace instead, and so hidden under the
  waterfall. One with an `event` sends `activate` when clicked — the topmost
  there, one behind only where none over the picture is — with the
  frequency clicked as `value`, its `id` as `layer` and where it was
  clicked as `at`, and does not tune; one with a `menu` opens it there
  instead, as an annotation does. `at.atMillis` is on the app's clock, and
  `at.db` on the radio's own scale, so it is no dBm.
- `hoverHz`, `hoverDb`: scene values the pointer writes, for a text layer.
- `widthHz`, `stepHz`, `vfoHz` (API 17): scene values the app writes, in Hz,
  as they change: the width shown, what a click rounds to (it follows the
  zoom), and this control's radio's tuned frequency. `vfoHz` is per control,
  so a scene showing two receivers reads each one's, which the scene's
  single `radio` block cannot.
- `tuneStep`: what a click rounds to, the wheel steps by and a dragged line
  lands on, in Hz. Omitted (API 17), steps that follow the zoom, along 1, 2,
  5, 10, 20, 50… Hz from the smallest covering a pixel. The fine step is the
  next one up, which a dragged line moving smoothly with the pointer reads
  on its label and lands on when let go; the medium one above that and
  the coarse two above, those no coarser than 1 kHz unless the fine one is.
  Within 5 seconds of the last tune a click within 1 kHz of the dial is on
  the fine step and one within 3 kHz on the medium; any other is on the
  coarse. The wheel is fine a notch at a time, medium turned briskly and
  coarse spun. The `stepHz` value is the fine step.
- `gestures` (API 17): `{ tune, zoom, pan, split, levels, scroll }`, the
  first five each `native` (the app does it), `event` (the extension hears
  it) or `off`. Omitted, each is `native`.
  - `scroll` is `{ vertical, horizontal }`: what scrolling up and down, and
    sideways, does — the wheel, or a trackpad's two-finger swipe — each
    `tune`, `pan` or `off`, whichever way the band scope lies. Omitted, up
    and down tune and sideways pans. A scroll along the frequency on screen
    moves the dial or the window the way it goes, so on a band scope
    whose frequency runs down the screen a scroll down tunes up; across
    it, up and right are higher. Each then goes as `tune` or `pan` says:
    natively, as the extension's event, or nowhere where it is `off`.
  - `tune` is a click, a scroll that tunes, or a drag of the tuned
    frequency's line (or within a finger's width of it); in a scene that
    scrolls, a trackpad swipe along its axis scrolls it, while a mouse wheel
    over the band scope still does what `scroll` says.
    Native, the app draws the dial where the
    operator put it at once, ahead of the radio's report; once clicks come
    to rest, one in the outer 15% of the window glides the window just far
    enough to bring it 15% in, where the window can move; and the app tunes the
    radio itself where the panel declares `requiresRadioWrite`, and the click
    is the event elsewhere; as an event, `commit` with the frequency.
    Natively, a drag of the line with Alt held draws it like a bow's string:
    let go once it leans past 30°, the dial shoots the other way, further
    by how far it was drawn and how wide the window — up to 300 kHz — and
    never past the band's edge; the line
    flies off as the arrow, and the window chases it there to watch it land.
  - `zoom` is a drag along the axis — the tuned frequency's line holds
    still (the window's middle, for a line out of view) and the frequency
    pressed on stays exactly under the pointer, the axis stretched between
    them: away from the line narrows the window, toward it widens it — or a
    pinch, by touch or on a trackpad, about the fingers.
    Zooming past the sweep asks for a wider scope: the app's own where the
    radio's `spectrum` says `autoSpan`, the radio's next span where the panel
    may command it, and no further elsewhere unless `maxWidthHz` says. Where
    a zoom ends with the sweep's points more than 5 pixels apart, a
    radio span the panel commands goes to the narrowest that covers the
    window and every other display of that scope; one showing the whole
    sweep keeps it from narrowing. A double click on the axis puts the window back, about the
    dial, and widens back what the zoom narrowed.
  - `pan` is a drag along the frequency over the spectrum or the waterfall,
    or a scroll that pans, unless the scene scrolls that way, whose scroll
    takes it. Within the sweep it only moves the window;
    past it, it moves the radio's scope where the radio lets the app place it,
    and where not, goes on until the window's middle reaches the sweep's
    edge, the part past it drawn as the filler below. After a pan, `follow` leaves the window
    alone until the dial moves. With the window standing still, a scope the
    app places moves when a turned dial comes within `follow`'s share of
    its width of an edge, as little as keeps the dial that far in while
    covering as much of the window as it can. A dial that jumps (a click, a
    spot) with the window not covered, or that near an edge, moves it to
    cover the window, as near centered on the dial as that allows. A knob
    turned elsewhere leaves it be.
  - `split` is a drag across the axis, which moves it between the
    spectrum and the waterfall, between a tenth and nine tenths of their
    height. Both drags start anywhere on the axis; the pointer shows the
    resize cursor across it within a few pixels of where the spectrum meets
    the waterfall, and the one along it elsewhere. Natively the operator's share holds until the scene changes its
    own `split`.
  - `levels` is a drag along the level strip. On the waterfall it changes
    the speed, the age taken hold of staying under the pointer. On the
    third of the spectrum by its base it moves `floor`, the trace following
    the pointer; above it, it changes `range` as a drag along the axis changes
    the width — away from the middle narrows — the level taken hold of
    staying under the pointer. Natively each holds until the scene changes
    its own.

  As events, a zoom, pan, split or level drag sends `change` while it moves
  and `commit` when it ends, with `gesture` naming it — `zoom`, `pan`,
  `split`, `floor`, `range` or `speed` — and `value` the width or the
  middle in Hz, the spectrum's share, the floor offset or range in dB, or
  waterfall rows a second; what is drawn stays the scene's. Native, the app
  still sends that `commit` once the gesture ends, where the control has an
  `event`, so a panel can keep the operator's choice: give each back as
  `span`, `split`, `floor`, `range` or `waterfallSpeed`. A double click on
  the axis sends a zoom of `0`, the scene's own width again, and one on the
  level strip a `floor`, `range` and `speed` of `0`. A drag across
  the frequency anywhere but the axis is left to a scene that scrolls. A bundle declaring an API before 17 keeps its clicks
  as its event, where they land, its wheel scrolling the scene, and no axis
  it did not ask for; its zoom and pan are the app's.

Each waterfall row stays at the frequencies it was taken on: when the radio
retunes its scope the history slides sideways, and when the span changes it
stretches.

## Rotator map

A `rotatorMap` control is a rotator on a map of the world centered on the
station: where the antenna points, where it is turning to, and whatever the
scene draws over the map by bearing and distance. API 23, with the rotator
calls ([Radio control](radio.md#antenna-switches-and-rotators)). It needs
`requiresRadioRead`; without it, or with no rotator in the station, it says
so instead. Turning the rotator from the map needs `requiresRadioWrite`;
without it a click or a drag is the scene's event, where the control has
one. Placed like a native control, it takes:

- `rotator`, a rotator's id from `listEquipment`; omitted, the station's first.
- `home`, `{ lat, lon }`, the map's center; omitted, the operation's
  location. With neither, the map says it has no place to center on and
  draws a bare compass, still true and still clickable.
- `map`: `palette` (`color`, `gray`, `muted`, `contrast`, `teal`), then any of
  `sea`, `land`, `coast`, `borders`, `divisions` (the lines between states
  and provinces, drawn as the view closes in), `graticule` and `background`
  over it. `grayline: false` leaves the night side unshaded; `world: false`
  draws no map at all.
- `rim`: the map's edge, a circle while the whole Earth is in view and a
  rounded box zoomed in. `color`, `width` (1.5), `background` (filled
  outside the edge), and up to 16 sets each of `ticks` and `labels`, every
  `every` degrees from north or at the bearings in `at`. A tick takes
  `color`, `length` (6) and `width` (1); a label `color`, `size` (12),
  `weight` and `offset`, pixels inside the rim (12; outside where
  negative), and with `at`, `text`, one for each bearing. Omitted, ticks
  every 10° and N, E, S and W.
- `rings`: up to 16 circles at a `distance` on the ground, in `unit` `km`
  (the default) or `mi`, each with `color`, `width`, `dashed` and up to 16
  `labels` at bearings: `{ az, text, size, color }`, the distance when
  `text` is omitted.
- `zoom`: `{ min, max, initial }`, 1 fitting the whole Earth; 1 to 20 when
  omitted. `initial` may name a scene value.
- `pan`: where the station may be moved to, within the `area` `square`
  around the circle the widest zoom draws, or anywhere in the `pane` (the
  default), no nearer that area's edge than `margin` percent of the pane's
  shorter side (10). Never further than keeps the far side of the Earth out
  of view, so a map zoomed all the way out does not pan. `x` and `y`, pixels
  from the pane's middle, numbers or scene values, put the station there
  until the operator moves it.
- `beamWidth`: the default decorations' beam, in degrees (30; 0 draws none). An antenna whose device reports its own beam is drawn with that instead.
- `snap`: pixels (12). A click this near the station in the call field turns
  to its exact bearing.
- `stops`: the only bearings the antenna can point at, a 4-square's four or
  a switched array's eight. A click, an aim and a drag each land on the
  nearest. Omitted, any bearing.
- `hud`: `false` hides the app's heading readout. `actions`: `false` hides
  its connect, stop and whole-map buttons. Draw your own with the values
  below and `nativeButton` controls.
- `decorations`: up to 256 layers, below. Omitted, the app's own: the beam,
  the target, the heading and the station in the call field.

The control writes scene values, each named by the scene and declared in its
`values`: `headingDeg`, the rotator's heading, kept at the last one it gave
while it is not connected and answering; `targetDeg` while it turns;
`elevationDeg` for one that tilts; `hoverAz` and `hoverKm`, the bearing and
distance under the pointer; and `zoomValue`. `status` names a string in
`strings` the control writes with the rotator's state: `connected`,
`turning`, `stale` (connected and not answering), `connecting`,
`disconnecting`, `disconnected`, `error`, or `none` with no rotator, for a
`when` to test. `rotators`, up to 8 `{ rotator, headingDeg, targetDeg,
status }`, writes the same for rotators the scene draws beside the
control's own. A reading the rotator has not given, a target while it is
not turning, is missing, as a radio's is: the bottom of a binding's range,
`—` in a text layer, and failing a `when`.

### Decorations

A decoration is drawn over the map, in order, each over the ones before,
and cut at the rim unless `clip: false`, which draws it past the rim: an
arrow's head or a label sitting on the edge. The rim's line and marks are
drawn just before the first decoration with `clip: false`, so the cut ones
listed before it lie under the line, and those after it over it. Each has
an `id` and a `kind`:

- `line`: `from` and `to`, two points. `head: { width, length }` makes its
  end an arrow's point. `width`, `dashed`, and `casing`, a color drawn a
  pixel wider either side under it and round its head, so it stands off
  whatever it crosses.
- `wedge`: from bearing `az` clockwise to `az2`, from distance `r` to `r2`
  (the center to the rim when omitted). `fill` and `color` for its edge;
  `casing` runs a pixel along the outside of each straight side.
- `circle`: at `at`, `radius` pixels, `fill` and `color`.
- `text`: at `at`, one of `text`, `value` (a scene value, with `decimals`)
  or `show`, one of the map's own readings: the rotator's `heading`,
  `target` or `elevation`, or this layer's place's `bearing`, `km` or `mi`
  from the station. `prefix`, `suffix`, `size`, `weight`, `fontFamily`,
  `italic`, `background` and `padding`; `align` (`start`, `center`, `end`)
  and `valign` (`top`, `center`, `bottom`) say which end and edge sit at
  its place.
- `svg`: artwork, drawn upright and centered on `at`, `svgWidth` by
  `svgHeight` pixels (24), under the same rules as an `svg` layer's.
- `defaults`: nothing but its `id`. The app's own beam, target, heading and
  call marker, drawn at that place in the list, so you can draw under and
  over them without drawing them. A list holds it once, and then no other
  decoration takes the ids `heading` or `target`.

A point is one of:

- `az` and `r`: a bearing and a distance from the station.
- `lat` and `lon`: a place on Earth.
- `place: 'call'`: the station in the call field, where its lookup puts it.
  A decoration placed there is not drawn while the call field has none.
- `on` and `along`: a share of the way along a `line` drawn earlier in the
  list, 0 its start and 1 its end (the default). With `defaults` drawn
  before, `heading` and `target` are such lines.

Then `dx` and `dy`, pixels right and down that do not turn with the bearing:
a label set beside its place.

A bearing is `heading` or `target` (the rotator's), `call` (the station in
the call field), or `az:` and degrees or a scene value, then degrees added:
`heading+15deg`, `az:120`, `az:aimDeg-5deg`. A number is that many degrees.
A distance is `rim` or `center`, then any of `±<n>%` (a share of the way to
the rim along that bearing), `±<n>km`, `±<n>mi` and `±<n>px`: `rim-8px`,
`60%`, `1000km+4px`. A number is pixels. A decoration that needs a reading
the rotator has not given, or the call field's station when there is none,
is not drawn.

`rotator` names the rotator a decoration's `heading` and `target` are;
omitted, the control's. `turningColor` and `turningFill` replace `color`
and `fill` while that rotator turns to a target. `width`, `radius`,
`size`, `weight` and `padding`, and an `az:` bearing, may name a scene
value.

A decoration acts on a click with one of:

- `aim: true`: turns its rotator toward the decoration's place.
- `event`: sends `activate` with that action, `layer` its id, `value` the
  bearing clicked, and `at` with `x`, `y`, `bearing` and `km`.
- `menu`: `[{ label, event }]`, opened where clicked; the item picked is
  sent as `event` is.

`drag` turns the rotator when the decoration is dragged: `turn` to where
the pointer points, or `{ axis: 'x' | 'y', degPerPx }`, moving the target
by `degPerPx` degrees (1) for every pixel along that axis. The decoration
shows where the drag will land as it moves; the rotator is told once, on
release. A rotator not connected and answering is not dragged.

### Gestures

`gestures` takes `turn` (`native`, `event`, `off`), `zoom` and `pan`
(`native`, `off`):

- `turn` is a click on the map or a drag of a decoration. Native, with
  `requiresRadioWrite`, the app turns the rotator, shows the target at
  once and holds it for 2 seconds while the rotator's own report catches
  up; as an event, `commit` with the bearing as `value`. A click on a
  decoration that acts is that decoration's.
- `zoom` is the mouse wheel, a trackpad's two-finger scroll or a pinch.
  It sends `commit` with `gesture: 'zoom'` and the zoom as `value` once it
  settles. The app's whole-map button sends a zoom of `0`.
- `pan` is a drag that starts on the station, which moves it within the
  limits above. It sends `commit` with `gesture: 'pan'`, `at.x` and `at.y`
  where the station is, in pixels from the pane's middle. A drag anywhere
  else on the map moves nothing, so a scene that scrolls keeps its drag.

To keep the operator's view, store each `commit` and give it back as
`zoom.initial` and `pan.x` and `pan.y`; forget it on a zoom of `0`.

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
| `radio.compression` | The speech processor's compression, dB, while transmitting. API 22 |
| `radio.transmitting` | 1 or 0, the radio's own report |
| `radio.swrAverage` | SWR averaged over the transmission under way, else the last one; only readings taken with RF out count |
| `radio.secondsSinceTransmit` | 0 while transmitting, then counting up; very large when there has been none |
| `radio.frequencyHz` | The frequency, in Hz, where the app has the radio: a tune set through the app from the moment it is accepted, ahead of the radio's report of it; the last reported, kept while disconnected, as the app's own Radio panel keeps it. API 13 |
| `radio.reportedFrequencyHz` | The frequency, in Hz, the radio itself last reported, as `readRadio()` gives it. API 19 |
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

## Named sources

A scene's `sources` (API 22) are radios, rotators and antenna switches the
app feeds live, each under a name of the scene's choosing, as `radio` feeds
the logging radio under `radio.`: a board with a meter for each of two
radios reads `main.signalDbm` and `sub.signalDbm`, and one showing a
switch's port reads `ant.1.antennaName`.

```js
sources: {
  main: { radio: "…id from listRadios…" },   // or { radio: null }, the designated radio
  rot:  { rotator: "…id from listEquipment…" },
  ant:  { antennaSwitch: "…id from listEquipment…" },
}
```

| Source | Gives |
| --- | --- |
| A radio | Every [radio value](#radio-values) and word, under its name: `main.signalDbm`, `main.frequencyHz`, `main.mode` |
| A rotator | `azimuth`, `elevation`, `targetAzimuth` (where it was told to turn, until it gets there), `moving` (1 while turning there) and `connected`, as numbers |
| An antenna switch | `connected`, and for each port by its `key` in `listEquipment()` (not its label: an Antenna Genius's ports are keyed `1` and `2`, labeled A and B), `<port>.auto` (1 or 0) as a number and `<port>.antenna` (the antenna's key) and `<port>.antennaName` (for an antenna the operator has set up) as words |

A switch names its ports its own way, so any port name is accepted and one
the switch does not have reads as missing, as does a source given the id of
a device of another kind. A band scope's `radio` may name a radio source,
never a rotator or a switch. A name is an identifier, never
`radio`; a scene has at most 16 sources. Their names are reserved as the
`radio.` ones are: a scene may not declare them, and an `onEvent` answer
does not set them. They need `requiresRadioRead`, and they follow
`readRadio()` and `listEquipment()`, so a scene and a render never disagree:
a reading a device has not given, or a device that is not there, is
missing.

## Examples

`k2hrc-panel-scenes` in the SDK's samples has every control, a control faded
in over artwork and a click-through layer. `ki2d-radio-panel`,
`ki2d-weather-panel` and `ki2d-band-map` in
[ham2k/extensions](https://github.com/ham2k/extensions) are published scene
panels.
