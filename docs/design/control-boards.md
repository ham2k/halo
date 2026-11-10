# Control boards

Status: proposal. Nothing here is built yet; the stages at the end say in
what order it would be.

A **control board** is a panel of buttons, toggles, labels, meters, a band
scope, a rotator, even other panels, laid out on grids the operator (or an
extension) defines. Every widget is drawn at its own size in logical pixels and
is never scaled with the pane. A narrower pane reflows the widgets, and a row
that cannot reflow scrolls.

A board is **data**: a definition document the board panel turns into a
[scene](../extensions/scenes.md). The operator builds one in an editor with
a palette, a structure tree and an inspector. An extension builds one in
code through the SDK.

## 1. Where a board lives

- **A board belongs to its placement.** The Add a Panel list offers
  *Blank Board* and *Sample Board*, both `multiple`. Placing one copies a
  definition into that placement's settings. From then on it is that pane's
  own: editing it changes nothing else, and a later version of the app with
  a different sample leaves it alone. To reuse a board, export it or copy it.
- **It travels in layout files.** The definition and the parameter values
  are the placement's settings, and a layout file already carries each
  pane's settings ([layouts.md § Layout files](layouts.md#layout-files)).
  Import already gives every instance a fresh id. A board needs no special
  case there.
- **It exports on its own as a `.h2kboard` file** (YAML, §8), and imports
  into an existing board pane. The add-panel list offers *Board from file…*.

## 2. The pieces, and who owns them

| Piece | Owner | Why there |
| --- | --- | --- |
| Grids, cells, multi-source live values, new bindings | Host (Dart), scene API 22 | They are layout and painting. Reflow at native speed with no bridge call is the whole point |
| Definition → scene compiler, widget library, Liquid, declarative actions | Core extension `control-board` (TypeScript), compiler also exported by the SDK | Liquid already lives in the extension runtime. Widgets as code emitting scene parts ship without a host release. Extensions get boards through the same compiler |
| Board scripts (the JS subset) | Isolated context, §6 | Operator-written code must not see the extension's own globals |
| Per-placement parameter form | Host, API 22 | A board's parameters differ per placement, and a descriptor's `form` is fixed |
| Embedded panels | Host | They are the views' own widgets |
| Editor | Host (Flutter) | HTML panels are unavailable on web and Linux, and the editor needs real drag and drop |

The host contract stays one thing: a scene. A board is never a new content kind.

## 3. Layout: grids and cells

### What scenes lack today

A scene's `layout` places only **native** controls at their own size. Drawn
artwork (layers, knobs, sliders, buttons over SVG) sits in the single
`{ scene: true }` box, scaled to fit. A meter that is always 144×48 and
moves to the next row in a narrow pane cannot be said without the extension
recomputing coordinates on every resize.

### Cells

A **cell** is a fixed-size piece of the scene placed by the layout. A layer
or a drawn control that names a `cell` has its rect in that cell's local
coordinates, `0,0` at the cell's top left. A cell is declared in the scene's
`cells: [{ id, width, height }]`, and placed by a layout node `{ cell: "id" }`,
exactly once. Layers, controls, values and strings stay in the scene's flat
lists, so bindings, `when`, `hoverSet` and events work in a cell unchanged,
and the scene budgets count across all cells. A cell clips what it paints.

### The `grid` layout node

```yaml
grid:                   # the children, like a row's or a column's
  - { cell: smeter, span: [3, 2] }
  - { grid: [ … ], columns: 6, style: { title: Mode } }
  - { control: band }
unit: [48, 48]          # one slot, logical pixels; inherited by nested grids
gap: 4                  # or [x, y]; inherited
padding: 8              # inside the box; not inherited
columns: 8              # omitted: as many slots as fit, wrapping to new rows
style: { background: surfaceContainer, border: { color: outlineVariant, width: 1 }, radius: 8, title: "Main radio" }
```

- A child's `span: [cols, rows]` is in slots, and it is given that area
  whole. A cell without one takes the slots its size covers, centered in
  them; anything else, one slot. Its size in pixels is
  `span × unit + (span − 1) × gap`, so widgets on grids sharing a unit line
  up across nested containers, and the editor snaps to them.
- **Placement follows order**, row by row, each child at the first position
  it fits from where the last one went (CSS grid's `grid-auto-flow: row`, not
  `dense`). An operator reading the definition finds the widgets in the order
  they appear on screen.
- **Wrapping or fixed.** Without `columns` a grid has as many columns as the
  width allows, at least the widest span. With `columns` it keeps that width
  and scrolls sideways on its own when it is given less room, so a row of
  controls scrolls while the board around it stays put.
- **A nested grid takes no `span`**: its size comes from its content.
- **A nested grid with `columns`** is a block of known width: it takes the
  slots its content needs, rounded up to whole parent slots and never wider
  than its parent, and flows with its siblings.
- **A nested grid that wraps takes a full row of its parent** and wraps
  within that width, its height its content's, rounded up to whole parent
  rows. Without that rule the sizes depend on each other: the parent's
  columns on its children's spans, and a wrapping child's span on the width
  it is given. A full row breaks the cycle, and it is the common case: a
  board as a stack of sections, each wrapping its own buttons.
- Merging a nested grid's children into its parent's flow is not offered: it
  would lose the group's rectangle, its background, border and title, which
  are why a group exists. An unstyled group that only gathers widgets for
  editing or `when` could join its parent's flow later, if one is wanted.
- **The outermost grid fills the pane's width** and scrolls the pane:
  vertically when it is taller, sideways when its widest child is wider.
  These scrolls are native and send no events. A scrolling grid is dragged
  by any pointer, a mouse included, except where the drag begins on a
  control that takes it. An edge with content hidden past it fades out, the
  fade thinning away as that content runs out.
- **A board control takes no focus from the pointer**: a click or drag
  leaves the logging fields focused. Tab still reaches it.
- Colors are theme roles (`surface`, `surfaceContainer`, `onSurface`,
  `accent`, …, the render environment's names) or `#RRGGBB`. Roles are the
  default, so a board follows light and dark like the app does.
- Sizes are logical pixels: the Font Scale setting scales the whole UI from
  the root ([ui-scaling.md](ui-scaling.md)), and nothing here multiplies by it.
- The layout's limits rise to 12 deep and 512 nodes (from 8 and 128).

`row`, `column` and `wrap` keep working beside `grid`, and a native control
can sit in a grid slot like a cell.

## 4. Widgets

Each widget type is code in the board extension that turns its properties
into one cell: layers, drawn or native controls, bindings. Each also
describes itself to the editor: a title, an icon, a default span, a preview,
and its properties as a [form schema](../extensions/forms.md), so the
inspector is generic.

The first set:

| Group | Widgets |
| --- | --- |
| Controls | Button, Toggle (with indicator light), Menu button, Segmented choice, Knob, Slider |
| Indicators | Label, Value readout, Frequency readout, Indicator light |
| Meters | Bar, LED bar (segmented), Needle; each with min/max, zones, scale labels (S-units, watts, SWR) and an optional peak hold. A bar may be `adjustable`: a slider over its own track, dragged by its fill, its scroll inverted (`invertScroll`) unless the board says otherwise |
| Radio and equipment | Band scope (the existing control), Rotator compass, Antenna selector |
| Layout | Group (a nested grid), Spacer |
| Panels | Embedded panel (§7) |

Two scene features serve the meters:

- The **reveal** binding (`clipX`/`clipY`, the share of the layer shown, from
  its pivot). With `scale` and `truncate` it steps segment by segment, so an
  LED bar is two layers (dim and lit) rather than one layer per segment,
  which 512 layers would not afford across a board.
- **Peak hold**, a binding's `hold: { ms, fallPerSecond }`, kept by the host.
  Without it a peak needs a render per reading.

## 5. Values

A property takes one of four kinds of value. The editor shows them as a mode
switch on each property.

| Kind | Written as | Evaluated | For |
| --- | --- | --- | --- |
| Literal | `20` | never | Fixed settings |
| Text | `"{{ params.radio1.name }} — {{ op.station }}"` | at render, as Liquid | Labels, titles, menu items |
| Live | `{ live: radio1.signalDbm }` | by the host as the source reports, no bridge call | Meters, readouts, lights, `when` |
| Script | `{ js: "…" }` | at render, §6; **not in the first phase** | Anything computed |

- **A meter is never driven by a script.** Polling an expression is a bridge
  call per reading; a live binding is free and smooth. Meter shaping (range,
  zones, scale, smoothing, peak hold) is a widget property for that reason.
- **Live sources** extend the scene's single `radio` block to several, each
  under a name:

  ```yaml
  sources:
    radio1: { radio: "{{ params.radio1 }}" }
    rot:    { rotator: "{{ params.rot }}" }
    ant:    { antennaSwitch: "{{ params.ant }}" }
  ```

  A radio source gives `radio1.signalDbm`, `radio1.mode`, every `radio.*`
  reading under its own name. A rotator gives `azimuth`, `elevation`,
  `targetAzimuth`, `moving`, `connected`; a switch each port's `antenna`.
  The scene's `radio` block stays as the unnamed `radio.*` source.
- Text and script values are re-evaluated on the board's triggers, which the
  compiler derives from the templates and the sources (`radio` and
  `equipment` for a board naming them, `qso` for one reading the draft),
  plus the board's own `on` for scripts.
- **Actions** (a button's press, a menu item, a toggle's change) are
  **declarative first**:

  ```yaml
  onPress: { setRadio: { source: radio1, mode: CW } }
  onPress: { turnRotator: { source: rot, azimuth: "{{ qso.their.bearing }}" } }
  onPress: { setParam: { radio1: "{{ params.radio2 }}" } }
  onPress: { command: "…" }
  ```

  Those cover the first phase, and keep a board data, which is why the app
  chose Liquid ([templates.ts](../../extensions/sdk/src/templates.ts)).
  `onPress: { js: "…" }` is the later fallback (§6).
- **What a board commands is declared** (`uses: [radioWrite,
  equipmentWrite]`). The board refuses an action outside it, and importing a
  file says what the board commands before it is placed.
- **Board variables** (`vars`) hold local state: a toggle that shows a
  section, a selected band. They are scene values, kept per placement.

## 6. Board scripts

The one place a board holds code. **Not in the first phase**, but the format
keeps room for it: `{ js: "…" }` is reserved wherever a value or an action
goes, and until scripts land a definition carrying one is refused on import
and in the editor, naming the property, rather than shown with the script
skipped.

**Tension, stated:** the app chose Liquid over Handlebars because operator
text must not become code, and board scripts are operator text that IS code.
What keeps that acceptable:

- **A curated surface, not the extension API.** A script sees `params`,
  `vars`, `op`, the draft `qso` (read only), `now`, the named sources'
  readings, and a few commands, each mirroring a host call under its rules:
  `radio(name).set(patch)`, `rotator(name).turn(az)` / `.stop()`,
  `antennaSwitch(name).select(port, antenna)`, `setVar`, `setParam`. No
  `fetch`, `kv`, settings, accounts, secrets, other extensions, and no
  `updateDraft`: a board does not write the QSO being logged.
- **A context of its own.** Shadowing names in a `new Function` does not
  isolate: `globalThis`, `Function` and every prototype chain still reach
  the extension's `host`. A script runs in a separate context whose global
  holds only that surface. *Spike: whether a sub-context in the extension's
  runtime or a host-made runtime per board, and how either works on the web
  build's engine.*
- **Bounded.** A time limit per evaluation (the 250 ms Liquid has) and a
  memory cap. A runaway script fails that widget, not the pane.
- **Declared.** Scripts command only what the board's `uses` lists, as
  actions do, and importing a file says that it holds scripts before
  anything runs.

## 7. Embedding panels

A grid slot can hold another panel: `{ type: panel, panel: map, span: [6, 4], settings: { … } }`.

- **Only panels that say they are embeddable.** A panel opts in with an
  `embeddable` flag on its definition, native (`PanelDefinition`) or an
  extension's descriptor (API 22). Maps, Weather, Solar, Clock, Rotator, a
  scene panel: things that read well in a fixed box. Lists (QSOs, Spots,
  Operations) do not opt in: they need the pane's height and their own
  scrolling, and a fixed slot inside a scrolling board gives them neither.
  The logging panel never does (focus contract,
  [logging-fields.md](logging-fields.md)), nor a board (no recursion).
- An embeddable panel takes its config per placement, as a `multiple` one
  does, since each embedded copy carries its own settings.
- The pane is the view's own widget, built by the same builder the dock uses
  (`sharedDashboardPanes` and the views' `_panes`), handed to the scene view
  for that slot at the slot's fixed size.
- **Its settings live in the board's definition**, so they travel with it
  and with the layout file. That needs a seam in `PanelService`: a placement
  whose config comes from its board, not from its own slot in the store.
  This is the real work.
- A map's own pan and zoom inside a scrolling board: the inner one wins while
  the pointer is over it, as nested scroll views do.

## 8. The `.h2kboard` file

```yaml
# Ham2K Logger board
ham2k-board: 1
name: Station
description: Main radio, amp and rotator
uses: [radioWrite, equipmentWrite]
params:
  radio1: { type: radio, label: Main transceiver }
  rot:    { type: rotator, label: Rotator }
sources:
  radio1: { radio: "{{ params.radio1 }}" }
  rot:    { rotator: "{{ params.rot }}" }
grid:
  unit: [48, 48]
  gap: 4
  padding: 8
  children:
    - type: group
      title: "{{ params.radio1.name }}"
      columns: 8
      style: { background: surfaceContainer, radius: 8 }
      children:
        - { type: needleMeter, value: { live: radio1.signalDbm }, scale: sUnits, span: [3, 2] }
        - { type: ledBarMeter, value: { live: radio1.powerOut }, max: 100, zones: [[80, warn]], span: [5, 1] }
        - { type: button, label: CW, onPress: { setRadio: { source: radio1, mode: CW } } }
    - { type: rotatorCompass, source: rot, span: [3, 3] }
```

Parameter types: `radio`, `rotator`, `antennaSwitch`, `band`, `mode`,
`choice`, `text`, `number`, `toggle`. The pickers read new system lists
(`$core.radios`, `$core.rotators`, `$core.antennaSwitches`) beside
`$core.bands` and `$core.modes`.

Reading follows the layout file's rules: YAML, refused with a readable
reason, alias expansion and nesting capped. An imported board's parameters
start empty, since another device's radio ids mean nothing here.

## 9. Parameters, outside the editor

Parameters are the board's settings an operator changes without editing it:
which radio is *radio1*, which rotator, a callsign. A render result may
carry a `form` (API 22) that replaces the descriptor's for that placement, the
way `triggers` already adds to it per placement. The board answers its
parameters as that form, and the values land in the placement's config beside
the definition. The operator reaches it from the **pane's menu**
(*Board Settings…*, beside *Edit Board…*), with no layout editing involved;
Layout Setup's gear shows the same form. Panes have no menu today, so this
is new host UI: a menu on the pane's tab, whose entries a panel supplies.
*Open: whether it is the tab's context menu, a button on the tab, or both,
and whether other panels put their settings there too.*

## 10. The editor

Desktop and tablet. A full-screen modal pane, opened from the board pane
(*Edit Board…*), editing a draft: Save and Cancel mean what they mean in
layout editing, with undo and redo.

- **Left: palette and structure.** The palette lists the widget groups in §4;
  the structure tab shows the tree of grids and widgets, where reordering and
  nesting are drags.
- **Middle: the board, live, at real size,** with the slots of the selected
  grid drawn. Drop a widget on a slot, drag one to move it, pull its corner to
  change its span. The canvas width can be set to preview reflow.
- **Right: the inspector,** generated from the selected widget's form schema,
  each property with its Literal / Text / Live switch (Script joins it with
  §6). Text uses the existing `textTemplate` editor. The board itself has an inspector too: name, unit, gap,
  parameters, sources, `uses`.
- **Import / Export** `.h2kboard`, and *Start from the sample*.

The preview renders through the board extension on each change, outside
the panel's 750 ms trigger budget. *Open: whether that is fast enough to
feel live while dragging, or whether moves are previewed host-side and
compiled on drop.*

Phones get the parameters form now and perhaps a structure-only editor later.

## 11. Stages

Each is one branch, landed on its own.

1. **This document**, settled.
2. **Scene primitives**, in the open API level (22), in two branches:
   - **2a:** cells and the `grid` node, with its host-drawn group style.
   - **2b:** named live sources for radios and equipment, the reveal binding
     and peak hold.

   Each is proven with a hand-written scene in the SDK samples.
3. **The board panel:** the `control-board` core extension, the definition
   format, the compiler and the first widgets, Liquid, declarative actions,
   *Blank* and *Sample* in the add-panel list, the per-placement parameter
   form and system lists, the pane menu, `.h2kboard` import and export. Boards are edited
   as YAML in the pane's settings at this point.
4. **The editor.**
5. **Embedded panels:** the `embeddable` flag, the `PanelService` config
   seam, Map and Weather first.

Later phases: board scripts (§6: the isolated context and the curated
surface), a phone editor, widget types contributed by extensions.

The feature stays behind an experiment until the editor lands.
