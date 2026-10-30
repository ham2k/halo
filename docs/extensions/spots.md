# Spots

A spot source feeds the Spots Panel and lets the operator spot themselves
and others. The DX cluster is a connection the app holds and extensions
share. [How hooks work](hooks.md) covers registration, keys, priority and
`ctx`.

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
  chip's colour counts only the sources that did not skip. A round every
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
