# Spot hooks

The [hook reference](hooks.md) says how hooks are registered and invoked, and what every hook is handed.

## ✅ `spots` — spot sources and spotting (ham2k/halo-dist#9, #10)

```ts
interface SpotsHook {
  sourceName: string
  fetchSpots(args: {}, ctx): Promise<Spot[]>
  isSelfSpotEnabled?(args: { operation }, ctx): Promise<SpotEligibility>
  isOtherSpotEnabled?(args: { qso }, ctx): Promise<SpotEligibility>
  postSelfSpot?(args: PostSelfSpotRequest, ctx): Promise<PostResult>
  postOtherSpot?(args: PostOtherSpotRequest, ctx): Promise<PostResult>
}
// Spot: {their: {call}, freq?, band?, mode?, refs?: Ref[],
//        spot: {timeInMillis, source, label?, sourceInfo?}}
// SpotEligibility: {enabled, icon?}
// PostResult: {ok, message?, userMessage?, skipped?}
// PostSelfSpotRequest: {operation, freq, mode?, comment?}
// PostOtherSpotRequest: {qso, comment?, spotterCall?}
```

Map upstream spots into QSON-shaped spot objects; filter out QRT/stale
entries at the source. `Spot` may also carry an `icon` (MDI/FontAwesome
name, same convention as `activity` controls). Implemented by: `pota`,
`sota` (SOTAWatch) — fetch only.

The four posting methods are all optional; a hook that omits them just
never appears in the Spotting control's icon row (same "silently absent"
convention as `export`'s `suggestExportOptions`). `isSelfSpotEnabled`/
`isOtherSpotEnabled` are checked once to decide whether to show a source's
icon at all (e.g. only when the operation/QSO has a matching activation
ref); `postSelfSpot`/`postOtherSpot` are only called for sources that
reported `enabled: true`. Implemented by: `pota` (self + other, posts
directly to the POTA API, no auth required). `sota`'s spot API requires an
authenticated account app-halo doesn't have yet, so `sota` stays
fetch-only for now.

**An operation without assistance asks no spot source.** The board stops
calling `fetchSpots` while such an operation is open, and `ctx.getSpots`
answers it with nothing. Without self-spotting, no source is asked
`isSelfSpotEnabled` and no self-spot is posted. Spotting somebody else
(`isOtherSpotEnabled`/`postOtherSpot`) is allowed under both. Both are the
operator's switches or a ref's rules ([`ref:<type>`](activities.md)).

A poster whose own rules decline a particular spot — a Discord channel whose
message template renders blank for it — answers `{ok: true, skipped: true}`.
Its icon stays neutral gray instead of lighting as sent, and no failure is
reported. The Spotting chip's color counts only the sources that did not skip.
When every one did, the chip stays neutral and the operator is told so, in
each source's `message` when it gives one; that spot is never what
auto-respotting repeats, and a round of it every source skips ends it.
`skipped` without `ok` is still a failure.

## ✅ `cluster` — the DX cluster connection

```ts
interface ClusterHook {
  onLines(args: { lines: ClusterLine[] }, ctx): Promise<void>
}
// ClusterLine: {seq, at, text}
// host.clusterSubscribe(): Promise<ClusterStatus>   // then onLines, until
// host.clusterUnsubscribe(): Promise<ClusterStatus> // this
// host.clusterLines({after?, limit?}): Promise<ClusterLine[]>
// host.clusterStatus(): Promise<ClusterStatus>
// host.clusterPostSpot({freq, call, comment?}): Promise<ClusterReply>
// host.clusterSend(command): Promise<ClusterReply>
// ClusterReply: {ok, lines: string[], error?, message?}
```

The app holds one telnet connection to the DX cluster node the operator picked
in Settings, logged in as the operator. Extensions share it rather than open
their own, because a node logs a call in once
([docs/design/cluster.md](../design/cluster.md)). Not on web, where every call
answers `error: 'unsupported'`. Extension API 10.

`clusterPostSpot` is how a `spots` hook posts to the cluster: the host builds
the `DX` command, sends at most 60 characters of comment, and spaces spots five
seconds apart. A reply with `ok: true` means the node took the spot without
refusing it. It does not prove the spot left that node: a DXSpider node can keep
a self-spot local and still echo it.

`onLines` is called only for an extension that called `clusterSubscribe()`,
with the lines since the last batch, at most once a second. Register the hook
under the extension's own key (the default): that is the key the host delivers
to. A subscription lasts until `clusterUnsubscribe()` or the runtime restarts,
and keeps the session open while it lasts. A reader that only polls
`clusterLines({ after })` holds nothing open.

Three manifest grants gate it, each including the ones before it:
`"requiresClusterRead": true` for status, lines and subscribing;
`"requiresClusterSpot": true` adds `clusterPostSpot`;
`"requiresClusterCommand": true` adds `clusterSend`, which sends any command in
the operator's name. Declare the least you need: the consent screen names it.
Implemented by: `ki2d-cluster-spotter` (spot).
