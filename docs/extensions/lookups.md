# Lookups

A lookup answers *who is this station*: a name, a location, a licence class,
the parks or summits the station is at. Sources register under `lookup`;
sources whose answer is only true for a contact in progress register under
`recentContextLookup`; and the app's own orchestrator, registered under
`lookupService`, runs them all and merges what they say into one guess. You
write the first two. The third is described so you know what becomes of
your answer.

[How hooks work](hooks.md) covers registration, keys, priority and `ctx`.

## `lookup`

**For:** a data source about callsigns: a web service, a program's API, local
data, the log itself.

**Called:** by the orchestrator, every source in turn, **sequentially in
priority order**, each handed the guess so far. Never per keystroke: the
logging panel asks after a pause in typing, the spots board asks once per
distinct spotted call, and the background queue asks once per saved contact.

```ts
interface LookupHook {
  lookupCall(args: { callInfo: AnnotatedCallInfo; qso; operation }, ctx): Promise<LookupResult>
}
// AnnotatedCallInfo: CallInfo & { guess?: CallInfo, lookups?: CallInfoLookup[] }
// LookupResult:      (CallInfoLookup & { locAccuracy?, refs?: RefInfo[], online?: boolean, largeArea?: boolean })[]
// CallInfoLookup:    CallInfo & { source?, scope?: 'general' | 'operation' | 'qso', notes?, history? }
```

**You receive** the parsed callsign with the country-file annotation already
applied (`callInfo`), the guess every earlier source built (`callInfo.guess`),
their raw answers (`callInfo.lookups`), and the whole `qso` and `operation`,
so a program's source can read `qso.refs` for a hunted reference.

**You return** zero or more records. Each is a `CallInfo` (name, location,
licence and the rest, in the shape `@ham2k/lib-qson-tools` defines) plus:

- `source`: who answered, shown beside each field the operator sees.
- `scope`: `qso` for an answer about **one of the QSO's references** (a
  park's grid, a summit's location), matched to that reference by `source`
  being the reference's `type`; any other value (`general`, the default, or
  `operation`) is an answer about the callsign.
- `refs`: references you **propose** for the QSO being logged, from a spot or
  from the log. The app applies only those whose type the QSO does not
  already carry, then asks the sources once more so a `qso`-scoped source
  can resolve the new reference; because an applied type is filtered out on
  the next pass, that settles rather than cycling.
- `online: true` **only when answering took a network round trip**. The app
  reads it to decide whether a saved contact already has a real online
  answer worth not fetching again. Leave it unset for anything from local
  data, even from a source that usually needs the network for other calls.
- `largeArea: true` for a reference that covers more ground than one point
  can stand for (a trail, a park across several states): the station still
  counts as away from home, but nothing places it.
- `notes` and `history`: free text and past contacts, accumulated across
  sources and shown as they come; never merged into the guess.

**Rules:**

- **Return `[]` for "cannot answer"**: not configured, not found, offline
  with no local data. Never throw for an expected condition; a hook that
  throws takes its feature down for that call.
- **For an operation without assistance** (a contest's non-assisted category,
  or the operator's switch) every lookup runs with `ctx.online` false, the
  background enrichment of logged contacts included. Answer from local data
  or not at all. The one exception is a Lookup All QSOs the operator confirms
  after a warning.
- **A field of the wrong type is dropped**, and reported once by name: a
  numeric `continent`, a boolean `emoji`. The rest of the answer is used. A
  numeric string where a number is read (`cqZone: '05'`) is taken as that
  number.
- **`locSource: 'prefix'` is reserved** for the country file's entity
  centroid, and a coordinate under it is never read as a position. A source
  reporting a real position leaves `locSource` unset or names itself.
- **Register below 0 to be a fallback.** The log-history source registers at
  priority -1, below every live source and below the default 0, so it fills
  only what nothing else answered: a live source describes the station
  today, the log describes it whenever it was last worked.

**Example:** `k2hrc-hamqth` in the SDK's samples is a lookup behind a login,
with the `account` hook that holds the password. In
[ham2k/extensions](https://github.com/ham2k/extensions), `ham2k-lookup` is
about a hundred lines, `ham2k-qrz` adds a session, and `ham2k-call-history`
is the fallback that reads the log through `ctx.getHistoryForCall`.

## `recentContextLookup`

**For:** an answer about *what this station is doing right now*: from the
spots board, from the last minutes of the log, from anything live.

**Called:** by the same orchestrator, through the same `LookupHook`
interface, immediately after the `lookup` sources and folded through the
same merge, but **only while a new contact is being composed**. The spots
board and the background queue never ask.

The split is about truth, not cost. A `lookup` source answers who a
callsign is, which is true whenever asked. A source here answers a question
about a contact in progress; asked about a QSO logged an hour ago, or about
every call on the spots board, its answer is not just useless but wrong. The
economy is real too: an ordinary `lookup` is asked hundreds of times for
answers nobody reads.

`ctx.getSpotsForCall` is the usual input: it reads the spots the app already
holds, never fetches, and is cheap enough for this path.

## How answers merge

The orchestrator (`lookupService`, registered by the app's core and not
something you implement) runs the country-file annotation first, whatever
any source's priority, then every `lookup` source, then the
`recentContextLookup` sources, and settles one `guess`. Every reader in the
app takes that guess as it stands, so what follows decides what the operator
sees of your answer.

**Where the station is.** A result about the callsign (`scope` other than
`qso`) keeps its name and the rest, but its **location is dropped when the
station is away from its registered address**: a portable or mobile call
(`/P`, `/M`, `/AM`, `/MM`) or a call-area digit (`/4`); a prefixed call
(`EA3/KI2D`) when the result answers for the base call rather than the full
one; or a reference on the QSO that has a location. A `scope: 'qso'` result
that carries a location places the station and sets the callsign results'
locations aside; one whose reference is no longer on the QSO takes no part.
A reference inside exactly one state names it (`Ref.state`) and places the
station there; a `largeArea` reference places nothing. Only entries that name
a reference count; a contest exchange carried on `refs` does not. What the
operator typed (`their.lat`/`lon`, `grid`, `state`) goes on last, as a group:
a typed state that disagrees with the lookup's drops the lookup's whole
location, one that matches keeps it.

**Location scope.** `CallInfo.locationScope` ranks `qth < prefixed <
portable`. A result strictly more specific than the current guess clears
every location field (`locSource`, `lat`, `lon`, `grid`, `street`, `city`,
`state`, `postal`, `county`, `country`) before merging, and the guess adopts
its scope. Otherwise priority order applies: a field already in the guess is
never overwritten by a later result, and a location field also needs the
result's scope to be at least as specific as the guess's.

**Location travels as a group.** A same-scope result bringing a pin (a grid,
or a full `lat`/`lon`) to a guess with none replaces the established town
(`city`, `state`, `county`, `country`, `location`) with its own, or clears
the town if it carries only the pin. A result whose pin loses to an
established one contributes no location fields at all. A pinless result's
town is used only where the earlier sources left no town or pin; an
entity-level `country` alone does not count as located. A town is never
spliced with a pin it was not reported with. `street` and `postal` are the
mailing address's own lines and travel with the town they complete. Grid and
coordinates reconcile within a result: grid alone gives a computed
coordinate, coordinates alone a computed 6-character grid, both given are
taken verbatim; setting any of them clears `street`, `city`, `state`,
`postal`, `county` and `country` unless the same result supplies them.

**Zones are the exception to first-answer-wins.** The country file can only
answer `cqZone`, `ituZone` and `tz` for a whole entity or call area, so once
every source has run, a value it still holds goes to the first result that
carried one, while the guess's scope is `qth`. `tz` is a UTC offset string
with its ordinary sign, `"GMT-5"` being five hours behind; the SDK's
`annotateCallAgainstCountryFile` answers with ordinary signs whichever
version of the country file the app carries.

The merge itself is a pure function with its own tests, in the app's core
lookup extension. Where this page and its behaviour disagree, the behaviour
is the contract and this page needs fixing.
