# Panels

A panel is a pane the operator can place in a view's layout, beside the
app's own QSOs, Info, Spots and Map panes. An extension declares one or
several, each with its own identity, configuration form and refresh budget,
and answers each render with a **document** the app draws, or a
[scene](scenes.md) the app keeps live. [How hooks work](hooks.md) covers
registration, keys, priority and `ctx`.

## `panel`

```ts
interface PanelHook {
  getPanels(args: {}, ctx): Promise<PanelDescriptor[]>
  render(args: PanelRenderArgs, ctx): Promise<PanelContent>
  onEvent?(args: PanelRenderArgs & { event: PanelSceneEvent }, ctx): Promise<PanelSceneEventResult>
}
// PanelDescriptor:  { key, title, description?, icon?, preview?, on?, form?, multiple? }
// PanelRenderArgs:  { panelKey, operation, qso?, qsoCount, config, reason, environment?, clock?, instanceId? }
// PanelContent:     { kind: 'markdown' | 'svg' | 'html', content, title?, triggers? }
//                 | { kind: 'scene', scene, title?, triggers? }
```

**`getPanels`** lists what the operator can place. The app addresses each
panel as `ext:<hook key>:<key>` and stores that id inside saved layouts, so
renaming a `key` drops the panel out of every arrangement holding it.

**`render`** is called when the panel appears and whenever one of its
triggers fires. `operation` is the operation's data with its `uuid`, its
`startAtMillisMin`/`startAtMillisMax`, and `operatorCall`, who is at the key
on this device. `config` is the panel's own form values. `qso` is the draft
being composed, present when a trigger asked for it. `environment`,
`clock` and `instanceId` (which placed pane this is, since a `multiple`
panel may be placed several times) arrive on scene-capable hosts
([Panel scenes](scenes.md#the-render-environment)).

**`onEvent`** answers a scene's controls; [Panel scenes](scenes.md#events-and-results).

### Content

**A panel returns content, not widgets.** There is no way to reach the app's
UI toolkit, by design.

- **`markdown`** is the one to prefer. It renders with the app's own
  typography, theme, font scale and density, costs no web view, and has
  none of the caveats below.
- **`svg`** is drawn as a vector image.
- **`html`** is the escape hatch, and runs sandboxed: **no JavaScript, no
  network for subresources** (inline what you need as `data:` URIs), **no
  navigation**. A link the operator taps opens in the OS browser; one the
  document triggers itself is blocked. The no-network rule is enforced by
  content blockers on Apple platforms and a block on Android; where a web
  view honours neither it still gets no scripts and no navigation, so treat
  "no network" as a rule your document follows rather than one it is held
  to everywhere. HTML panels do not render where there is no web view
  (Linux, and Windows without the WebView2 runtime), nor on the web build,
  where the sandbox cannot keep the no-navigation rule; the pane says so.
- **`scene`** is artwork, text and controls the app draws and keeps live,
  calling you only when the operator acts. [Panel scenes](scenes.md).

**Budgets.** A render's `content` is at most **262,144** characters of
markdown, **1,048,576** of SVG and **4,194,304** of HTML. A `preview` is at
most 262,144; a raster preview (a `data:` URI holding a PNG, JPEG, GIF, WebP
or BMP) declares at most **16,777,216 pixels**, read from its header before
anything is decoded, and a `data:` image of another type, or one whose
header does not say its size, is dropped. An SVG document, content or
preview, is self-contained vector artwork: no `<image>`, `<script>` or
`<foreignObject>`, no entity declarations (a DOCTYPE with an internal subset
is refused), at most **16,384 elements** nested at most **32 deep**. Over any
of these a document is refused whole: the pane shows a placeholder naming
the budget and the console says what was sent. A preview over its budget is
dropped and its row keeps its title. Nothing is trimmed or drawn in part.

### Triggers

**`on`** is a refresh budget, not a subscription. A descriptor with no `on`
renders once when it appears, and that is the right default: every trigger
costs a bridge call each time it fires.

| Trigger | Fires |
| --- | --- |
| `operation` | when the operation's data changes |
| `qsoLogged` | on every change to the log: a contact logged, edited or deleted, or one a sync brought in |
| `spots` | whenever `ctx.getSpots()`'s answer may have moved: a refresh, new verdicts, the operator's filters or bands, the radio's band or mode |
| `lookup` | when the panel is shown a callsign that **has** a lookup answer, including opening a QSO whose record already carries one; never when a lookup starts, fails or times out |
| `qso` | as the draft contact changes, debounced to one wake per pause in typing |
| `radio` | when any radio's dial moves: frequency, mode, passband, transmit state, PTT or connection; never for a meter. Extension API 13; needs `requiresRadioRead` |
| `tick:<seconds>` | on wall-clock boundaries, one second at the fastest; a smaller value is not a trigger and is dropped |

- The app keeps **at least 750 ms of idle** between one render finishing
  and the next starting. A gap, not a period: a slow panel runs less often
  instead of monopolising the runtime. A tick that arrives while a render is
  already coming is dropped, not queued, and another is aimed at the next
  boundary; everything else waits. Ticks are aimed at wall-clock boundaries,
  so panels sharing a period render in the same frame.
- **Nothing renders while the panel is behind another tab or the app is
  hidden.** A trigger that arrives meanwhile is remembered, and the panel
  renders once when it comes back. A panel on a tab nobody has selected is
  not rendered until that tab is, so one-time setup belongs in your hook's
  own initialization, not in a render.
- A trigger name outside the list is dropped when the panel is read, with a
  line in the console.
- **`qso` is the expensive one.** `args.qso` is the whole draft, every
  field, as it would be logged, and it changes as fast as the operator
  types. A panel that wants only the resolved callsign declares `lookup`
  instead: the guess is inside `args.qso` either way, and `lookup` fires
  when an answer lands, not while a call is being typed. A panel that must
  show "still looking" as well as "no answer coming" wants `qso` too, and
  reads `qso.their.guess` to tell them apart.
- Beside the QSON, a draft carries `callField`, the call field read at the
  cursor: `call`, `fullCall`, `partial`, `nextCall`, `nextPartial`.
  `their.call` is the field as typed, which may be a whole `//` stack or a
  comma list; `callField.call` is the one call Enter logs, and what
  [Templates](templates.md) render `qso.call` from. Moving the cursor
  within a stack or a list wakes a `qso` panel even when the QSON is
  unchanged.
- `radio` is for a panel that must lay itself out again around the
  frequency, such as a band map. A readout that only shows the frequency
  binds a scene to `radio.frequencyHz` instead and follows the dial with no
  render at all.

**The log and the spots are absent from `render`'s arguments** on purpose. A
panel that needs the log calls `ctx.getQsos(operation.uuid)`, which is right
for a `qsoLogged` render; one that shows spots declares `spots` and calls
`ctx.getSpots()`, which answers the operator's own filtered board, judged
against this operation.

### The descriptor's other fields

- **`form`** declares the panel's own configuration, in the same field schema
  a settings panel uses ([Settings panels](settings.md)). The app renders it
  behind the gear beside the panel in Layout Setup, persists the values per
  placed panel, and hands them back as `args.config`. Nothing for you to
  store.
- **`multiple`** lets the operator place more than one of the panel. Off by
  default: most panels are one thing. Set it where two is the point, such as
  a panel whose content is the operator's own notes. Each placement gets
  its own id and its own config. What you owe an instanceable panel is a
  `title` on the render result; without one every pane reads the same
  descriptor title.
- **`preview`** is a still image for the list of panels: an SVG document or
  a `data:` URI, never a URL, since the list renders offline.

### The render result's other fields

- **`title`** replaces the tab label for that pane. Blank is ignored; a
  result without one keeps the descriptor's.
- **`triggers`** adds trigger names to the descriptor's **for that placement
  only**. For a panel whose content is written by the operator, so a pane
  showing a band plan renders once while the pane beside it, naming the
  callsign being typed, wakes per pause. `triggersForTemplate` from the SDK
  derives them from a template ([Templates](templates.md#panel-triggers)).
  Unknown names are dropped with a line in the console, as in a descriptor.
  The declaration lands after the render that carried it, so declare in `on`
  anything the panel always needs.

### Example

```ts
const RatePanel: PanelHook = {
  async getPanels() {
    return [{ key: "rate", title: "Rate", icon: "speedometer", on: ["qsoLogged"] }]
  },
  async render({ operation }, ctx) {
    const qsos = (await ctx.getQsos?.(operation.uuid)) ?? []
    const lastHour = qsos.filter((q) => q.startAtMillis > Date.now() - 3_600_000).length   // Date follows the app clock in the sandbox
    return { kind: "markdown", content: `# ${lastHour}\n\nQSOs in the last hour` }
  },
}
```

`k2hrc-hello-world` and `k2hrc-radio` in the SDK's samples are the smallest
markdown and HTML panels; `ki2d-weather-panel`, `ki2d-rate-chart` and
`ki2d-band-map` in [ham2k/extensions](https://github.com/ham2k/extensions)
are published ones.
