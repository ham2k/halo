# Panel hooks

The [hook reference](hooks.md) says how hooks are registered and invoked, and what every hook is handed.

## ✅ `panel` — panes an extension contributes to a view

A panel is a PANE the operator can put in a customizable view's layout
(docs/design/layouts.md), listed in Layout Setup alongside the app's own
QSOs / Info / Spots / Map. One extension may declare several, each with its
own identity, config form and refresh budget.

```ts
interface PanelHook {
  getPanels(args: {}, ctx): Promise<PanelDescriptor[]>
  render(args: PanelRenderArgs, ctx): Promise<PanelContent>
  onEvent?(args: PanelRenderArgs & {event: PanelSceneEvent}, ctx): Promise<PanelSceneEventResult>
}
// PanelDescriptor: {key, title, description?, icon?, preview?, on?, form?}
// PanelRenderArgs: {panelKey, operation, qso?, qsoCount, config, reason}
// PanelContent:    {kind: 'markdown' | 'svg' | 'html', content, title?, triggers?}
//                | {kind: 'scene', scene, title?, triggers?}   (see scenes.md)
```

`operation` is the operation's data with its `uuid`, its
`startAtMillisMin`/`startAtMillisMax`, and `operatorCall`: who is at the key on
this device, resolved for its position in a multi-station operation, and empty
when nobody is named.

The host addresses a panel as `ext:<hookKey>:<key>`, and that id is stored
inside saved layouts — renaming a `key` drops the panel out of every
arrangement holding it.

**Content is a document, not widgets** — the same UI-catalog seam every
other declarative hook sits behind. Prefer `markdown`: it renders with the
app's own typography, theme, font scale and density, and costs no web view.
`svg` is drawn as a vector image. `html` is the escape hatch and runs
sandboxed: **no JavaScript, no network for subresources (inline what you
need as a `data:` URI), and no navigation** — a link the operator taps opens
in the OS browser; one the document triggers itself is blocked. The
no-network half is enforced by content blockers on Apple platforms and
`blockNetworkLoads` on Android; a platform whose web view honours neither
still gets no scripts and no navigation, so treat "no network" as a rule
your panel must follow rather than one it is held to everywhere. HTML
panels do not render at all where there is no web view (Linux, and Windows
without the WebView2 runtime) — the pane says so. Nor on the web build, where
one exists but is an iframe whose sandbox grants top-level navigation and
popups: the no-navigation rule above is the one part a panel cannot be trusted
to keep on its own, so the pane refuses rather than render under it.
`markdown` has none of these caveats, which is the other reason to prefer it.

A render may answer a **panel scene** instead of a document: artwork, text
and controls the app draws, animates and keeps live itself, calling the
extension only when the operator acts. [Panel scenes](scenes.md) describes
them, and [Radio control](radio.md) the radio calls a panel commanding a
transceiver makes.

**`on`** is a refresh budget, not a subscription: `'operation'`,
`'qsoLogged'`, `'spots'`, `'lookup'`, `'qso'`, or `` `tick:<seconds>` ``
(one second is the fastest; anything below it is not a recognized trigger and
is dropped with a line in the console, so the panel gets no tick at all). The host
keeps at least 750ms of idle between one render FINISHING and the next
starting — a gap, not a period, so a slow panel simply runs less often
instead of monopolising a single-threaded runtime. A tick that arrives while
a render is already coming is DROPPED rather than queued: another is aimed at
the next boundary, and the render that is coming reads fresh context anyway.
Everything else waits instead of being dropped. Ticks are aimed at wall-clock
boundaries, so panels sharing a period render in the same frame. The host
renders nothing while the panel is behind another dock tab, or while the whole
app is hidden — an unselected tab stays mounted, so without that a four-panel
layout would pay for the three nobody is looking at. A trigger that arrives
while the panel is away is remembered, and the panel renders once when it
comes back. Do not treat the first render as something that happens at mount:
a panel placed on a tab nobody has selected is not rendered until that tab is,
so one-time setup belongs in the hook's own initialization, not in a render. A trigger name outside this list is dropped when
the panel is read, with a line in the console: it would otherwise sit in the
descriptor looking live and never fire. A descriptor with no `on` renders once when it
appears. Omitting it is the right default: a trigger costs a bridge call
every time it fires.

`'qso'` is the expensive one. `args.qso` is the whole QSO being composed —
every field, in QSON, as it would be logged — and it changes as fast as the
operator types. The host debounces it to one wake per pause and stops
producing it entirely when no panel in the arrangement asked, but a panel
that wants only the resolved callsign should declare `'lookup'` instead: it
fires when a lookup is ANSWERED, not while a call is being typed, and the
guess is inside `args.qso` either way — declaring `'lookup'` is enough to be
sent the draft, so what it saves over `'qso'` is renders, not the QSO.

Beside the QSON, a draft carries one key a logged record never does:
`callField`, the call field read at the cursor (`call`, `fullCall`,
`partial`, `nextCall`, `nextPartial`). `their.call` is the field as typed, which may be a whole
`//` stack or comma list; `callField.call` is the one call Enter logs. It
is what [templates.md](templates.md)'s `qso.call` renders from, so a panel
rendering a template needs nothing more, and moving the cursor within a
stack or a list wakes a `'qso'` panel even when the QSON is unchanged.

`'lookup'` fires when the panel is shown a callsign that HAS an answer —
which includes opening a QSO whose stored record already carries one, not
only a fresh lookup resolving. It does not fire when a lookup starts, fails,
or times out. A panel keyed to it alone cannot tell "still looking"
from "no answer coming", and will sit on whatever it last drew. A panel that
needs to show either state wants `'qso'` too, and should read
`qso.their.guess` to decide which it is looking at.

**`form`** declares the panel's own configuration in the same field schema
a Tier 1 `settingsPanel` uses ([settings.md](./settings.md)), rendered by
the core's `FormRenderer` and reached from the gear beside the panel in
Layout Setup. Values are host-persisted per panel and handed back as
`args.config`; there is no per-keystroke bridge call and nothing for the
extension to store.

**`multiple`** lets an operator place more than one of your panel. Off by
default, because most panels are one thing — two maps or two spot lists would
be a mistake to offer. Set it where two is the point: a panel whose content
is the operator's OWN, like `custom-text`'s notes.

Each placement gets its own id and therefore its own config, so `args.config`
differs per pane with nothing to do on your side. What you DO owe an
instanceable panel is a `title` on the render result — without one every pane
reads the same descriptor title and the operator cannot tell them apart.

**`preview`** is a still image for that same list — an SVG document or a
`data:` URI, never a URL: the list renders offline, and a remote preview
would make opening it a fetch (and a beacon).

A render result may carry a **`title`**, which replaces the tab label for
that pane. Blank is ignored rather than producing a nameless tab, and a
result with no title keeps the descriptor's.

A render result may also carry **`triggers`** — the same names as `on`,
added to the descriptor's for THAT PLACEMENT only. `on` is per panel and so
is paid by every pane of it; this is per pane, and exists for panels whose
content is written by the operator: `custom-text` derives its triggers from
the template in each pane (`triggersForTemplate`), so a pane showing a band
plan renders once while the pane beside it, naming the callsign being typed,
gets woken per keystroke pause. Unknown names are dropped with a line in the
console, exactly as in a descriptor.

The declaration necessarily lands AFTER the render that carried it, so a
panel asking for `'qso'` this way is answered without one the first time and
woken by the next change to the draft. Declare in `on` instead when the
panel always needs the signal — a descriptor's triggers are in force before
its first render.

The whole log is deliberately absent from `render`'s args. A panel that
needs it calls `ctx.getQsos(operation.uuid)` — right for a `'qsoLogged'`
render, which comes for every change to the log: a contact logged, edited
or deleted, or one a sync brought in. Spots are absent for the same reason:
a panel showing them declares `'spots'` and calls `ctx.getSpots()`, which
answers the operator's own filtered board, judged against this operation.
