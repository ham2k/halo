# Spots

A spot source feeds the Spots Panel and lets the operator spot themselves
and others. The DX cluster is a connection the app holds and extensions
share. Band annotations say what is on a band besides its stations: its
plan, its windows, anything worth marking. [How hooks work](hooks.md) covers
registration, keys, priority and `ctx`.

## `spots`

**For:** a spot feed (a program's API, a chat, a cluster) and the posting of
spots to it.

**Called:** every registered source, each on its own. `fetchSpots` on the
board's refresh; the eligibility methods once, when the Spotting control is
built; the posting methods only for sources that answered `enabled: true`.

```ts
interface SpotsHook {
  sourceName: string
  fetchSpots(args: {}, ctx): Promise<Spot[]>
  isSelfSpotEnabled?(args: { operation }, ctx): Promise<SpotEligibility>
  isOtherSpotEnabled?(args: { qso }, ctx): Promise<SpotEligibility>
  postSelfSpot?(args: PostSelfSpotRequest, ctx): Promise<PostResult>
  postOtherSpot?(args: PostOtherSpotRequest, ctx): Promise<PostResult>
}
// Spot:                 { their: { call }, freq?, band?, mode?, refs?: Ref[], icon?,
//                         spot: { timeInMillis, source, label?, sourceInfo? } }
// SpotEligibility:      { enabled, icon? }
// PostSelfSpotRequest:  { operation, freq, mode?, comment? }
// PostOtherSpotRequest: { qso, comment?, spotterCall? }
// PostResult:           { ok, message?, userMessage?, skipped? }
```

**`fetchSpots`** maps the upstream feed into `Spot` objects: the station,
the frequency, the mode, the references it carries, and when it was
spotted. Filter QRT and stale entries at the source. `icon` is a Material
Design Icons name or a FontAwesome `fa-` name, drawn on the row.

**Posting** is optional method by method. A source that omits the posting
methods never appears in the Spotting control's icon row. The eligibility
methods decide whether to show the source's icon at all, for instance only
when the operation carries a matching activation reference. `postSelfSpot`
is handed the operation and the frequency; `postOtherSpot` the contact being
logged.

**`PostResult`:**

- `ok: true` means the service took it; `message` is for the log,
  `userMessage` for the operator.
- `ok: true, skipped: true` means your own rules declined this one (a
  channel whose message template rendered blank). The icon stays neutral
  instead of lighting as sent, no failure is reported, and the Spotting
  chip's color counts only the sources that did not skip. A round every
  source skips is reported to the operator through each source's `message`,
  is never what auto-respotting repeats, and ends an auto-respot.
- `skipped` without `ok` is a failure.

**Rules:**

- **An operation without assistance asks no source for spots.** The board
  stops calling `fetchSpots` while such an operation is open, and
  `ctx.getSpots` answers nothing. Without self-spotting, no source is asked
  `isSelfSpotEnabled` and no self-spot is posted. Spotting somebody else is
  allowed under both. Both come from the operator's switches or from a
  reference's rules ([Activities](activities.md#what-a-reference-forbids)).
- **The operator picks which self-spots each source is sent**, under
  Settings › Spotting › Destinations: all of them, only those whose comment
  leads with QRV or QRT, all but auto re-spots, or none. `postSelfSpot` is
  not called for a spot the source is held back from, and a source set to
  none is not sent spots of other stations either. A spot command that names
  the source reaches it whatever the setting. A source is listed there when
  its hook object has `postSelfSpot` or `postOtherSpot` as a method of its
  own, as an object literal does.
- Identify the app to the service with `ctx.appName`, never a hard-coded
  name.

**Example:** `ham2k-parksnpeaks` in
[ham2k/extensions](https://github.com/ham2k/extensions) is a feed in and
spots out; `ki2d-discord-spotting` posts only, with its own settings panel;
`ham2k-pota` does all of it.

## `cluster`

Extension API 10. The app holds **one** telnet connection to the DX cluster
node the operator picked in Settings, logged in as the operator. Extensions
share it rather than opening their own, because a node logs a call in once.
Not available on the web build, where every cluster call answers
`error: 'unsupported'`.

```ts
interface ClusterHook {
  onLines(args: { lines: ClusterLine[] }, ctx): Promise<void>
}
// ClusterLine: { seq, at, text }
```

```ts
host.clusterStatus(): Promise<ClusterStatus>
host.clusterLines({ after?, limit? }): Promise<ClusterLine[]>
host.clusterSubscribe(): Promise<ClusterStatus>     // then onLines, until
host.clusterUnsubscribe(): Promise<ClusterStatus>   // this
host.clusterPostSpot({ freq, call, comment? }): Promise<ClusterReply>
host.clusterSend(command): Promise<ClusterReply>
// ClusterReply: { ok, lines: string[], error?, message? }
```

**Three manifest grants**, each including the ones before it:
`requiresClusterRead` for status, lines and subscribing;
`requiresClusterSpot` adds `clusterPostSpot`; `requiresClusterCommand` adds
`clusterSend`, which sends any command in the operator's name. The consent
screen names the grant; declare the least you need.

**Reading.** `onLines` is called only for an extension that called
`clusterSubscribe()`, with the lines since the last batch, at most once a
second. Register the hook under your extension's own key (the default): that
is the key the app delivers to. A subscription lasts until
`clusterUnsubscribe()` or the runtime restarts, and keeps the session open
while it lasts. A reader that only polls `clusterLines({ after })` holds
nothing open.

**Spotting.** `clusterPostSpot` is how a `spots` hook posts to the cluster:
the app builds the `DX` command, sends at most 60 characters of comment,
and spaces spots five seconds apart. `ok: true` means the node took the spot
without refusing it. It does not prove the spot left that node: a DXSpider
node can keep a self-spot local and still echo it.

**Example:** `ham2k-cluster-spots` in
[ham2k/extensions](https://github.com/ham2k/extensions).

## `bandAnnotations`

Extension API 20. What is said about a stretch of a band, or a place on it,
held by the app beside the spots for every panel that draws a band: the Band
Scope draws them over its picture. They come three ways, and a reader gets
them all from `ctx.getBandAnnotations({ band })`, each with the `source` that
said it:

- a `bandAnnotations` hook, asked for a band the first time one is read;
- `host.bandAnnotations.put`, for what changes while you run;
- the operator's band tags ("QRM!" in the call field), under `source: 'user'`.

```ts
interface BandAnnotationsHook {
  annotationsFor(args: { band, station? }, ctx): Promise<BandAnnotation[]>
}
// BandAnnotation: { type, fromHz, toHz?, band?, key?, label?, icon?,
//                   importance?, color?, expiresAt? }
```

**`type`** says what it marks:

| `type` | Marks | The Band Scope draws it |
| --- | --- | --- |
| `edge` | A stretch of the band that is allocated, edge to edge | as barriers at its ends, what lies outside dimmed |
| `plan` | A stretch of the band plan's modes; at `secondary` and below, of a license's privileges | a mode's start labeled on a gold tag; a license's start and end in gray |
| `known` | A window or a frequency known for something: FT8, a calling frequency, emergency traffic | veiled, its label boxed over it |
| `general` | Anything else | as a spot is, in its lanes, its label for a call |

**Frequencies** are in Hz: `fromHz`, and `toHz` where it covers a stretch;
omit `toHz` for a place. `band` is the band at `fromHz` (or at `toHz`) unless
you name it. **`importance`** is `primary` (the default), `secondary` or
`tertiary`: a display short of room, or set to show less, leaves out the
least first. The Band Scope's Edges & Modes leaves out only the tertiary.
**`color`** is a suggestion, `#RRGGBB` and no other form, a display may
draw otherwise, and **`icon`** an MDI or FontAwesome (`fa-`) name.
**`expiresAt`**, epoch milliseconds on the app clock, takes it down then;
without it, it stays.

**`annotationsFor`** answers for one band, for a station at `station`'s
location where one is known. It is asked once per band and station while the
runtime lasts, in the background, so give what does not change: the band
plan, which the app's own `band-plan` extension gives, is the model. An
operation opening asks about its radio's band, ahead of any panel. A band a
hook failed or missed its time for is asked again once the extensions have
all activated, or else some time later, and as soon as one of the hook's
annotations expires. An annotation's own `band` is
ignored: it is on the band asked about. A malformed one is left out, and the
rest stand.

**`host.bandAnnotations.put(annotations)`** adds yours, replacing any you put
under the same **`key`**; one without a key is only ever added.
`remove(keys?)` takes them by key, or all of yours. A key is yours alone: no
extension reaches another's, or the operator's. A malformed annotation
rejects the whole put. You hold at most 1,000, and they last until you take
them, they expire, or the runtime restarts, so put them again from
`onActivation`.

A panel declaring `on: ['spots']` is rendered again whenever a band's
annotations may have changed.
