# Telemetry

Optional, consent-gated event tracking for HaLo, mirroring app-polo's event
vocabulary so both apps report comparable usage.

## Privacy model

- **Consent-gated at one choke point**: `HaLoServices.track` checks the
  user's *Share app usage data* setting (`consentAppData`) on **every** call.
  Instrumentation sites never call `MetricsService.logEvent` directly.
  Turning the setting off silences tracking immediately; no restart involved.
- **The setting is asked during onboarding, PRE-CHECKED.** `SettingsService`
  falls back to `false` when nothing was ever written, but that is the value
  a build with no onboarding sees, not what operators have: the flow arrives
  with the toggle on (app-polo's default) and writes it either way when it
  finishes, so an operator who completed onboarding has consented unless they
  deliberately turned it off. Only *Skip* from the Welcome step leaves it
  unwritten, since skipping never reaches the consent step. Read this as
  opt-out in the field, and weigh anything added behind it accordingly —
  "off by default" describes the code's fallback and would be the wrong
  thing to design against.
- **No identifying data**: the client identifier is a random install-scoped
  UUID, salted and SHA-256 hashed before leaving the device. Event payloads
  carry no callsigns, no locations — the QSO events send only the contact's
  DXCC prefix and ref *types*. The one deliberate exception is `radio_*`'s
  `name`: a node's label, sent (capped at 60 characters) so a generic
  driver's actual make/model (which the catalogue key alone can't tell
  apart, e.g. `kenwood-generic`) is visible in the data. See "Radios"
  below. **This bullet governs the `track` channel only.** One other path
  sends more, to the crash backend rather than here, behind the same consent
  — see "The first-success report"; do not read this rule as the app's whole
  privacy model without it.
- **OSS builds are silent — and backend-free**: this repo contains only the
  generic `MetricsService` interface (no-op by default) and the consent
  gate. Any analytics backend lives in the private distribution layer
  (`app_dist`), which launches the app through its own entrypoint and
  injects one via `runHaLoApp(metrics: …)`. A plain `flutter run` of this
  repo never carries analytics code at all.
- Debug distribution builds are flagged as test traffic, keeping development
  activity out of production reporting.

## Events

Names and property keys follow app-polo's set; HaLo-only additions marked *.

| Event | Properties | When |
| --- | --- | --- |
| `app_started` | UI prefs (language, colorScheme, fontScale) | once per launch |
| `screen_viewed` | `screen` (`home`, `operation`, `settings`) | one of the three screens opened (app-polo's `navigation` analog) |
| `panel_used` * | `screen`, `panel` | first real input in a panel, once per screen visit |
| `operation_created` | — | new operation |
| `operation_deleted` | — | confirmed delete |
| `operation_exported` | `formats`, `files`, `action` | export generated |
| `qso_added` / `qso_edited` / `qso_deleted` / `qso_undeleted` | `their_prefix`, `refs` (types only) | logging actions |
| `activity_added` / `activity_removed` | `activity` (ref type) | operation activity refs |
| `command_executed` | `command` (action name) | call-field command actions |
| `notice_shown` / `notice_dismissed` | `notice_key` | remote notices (FlagsService) |
| `extension_enabled` / `extension_disabled` * | `extension` | Extensions panel toggle |
| `sync_enabled` / `sync_disabled` * | — | Sync settings toggle |
| `radio_added` * | `radio`, `transport`, `driver`, `name`, `via` | equipment configured (`discovery`/`manual`) |
| `radio_connected` * | `radio`, `transport`, `driver`, `name` | first successful connect, once per radio per session |
| `radio_connect_failed` * | `radio`, `transport`, `driver`, `name`, `reason`, `baud` | first failed connect, once per radio per session |

### Screens and panels

There are exactly three screens — `home`, `operation`, `settings` — and
`screen_viewed` covers all of them. A partial set would be worse than none:
the ratios between tracked screens read as a navigation funnel, and one
built from a subset is simply wrong.

`panel_used` answers the separate question of what gets *touched* inside a
screen. It fires on the first real input — a tap or a keystroke — and at
most once per panel per screen visit, so leaving and returning counts again
while scrolling a list for a minute counts once (`PanelUseTracker`).

Visibility deliberately does **not** count. The operation screen's two-pane
layout has several panels on screen at once, so reporting on appearance
would say every operator uses the map.

| Screen | Panels |
| --- | --- |
| `home` | `operations`, `quick_lookup` |
| `operation` | `logging`, `info`, `spots`, `map` |
| `settings` | the built-in panel keys (`settings`, `sync`, `about`, …), plus `extension` for every extension-provided panel |

Extension panels collapse into one `extension` value on purpose: their ids
depend on what the operator installed, so reporting them by name would be
unbounded cardinality and would leak the extension usage excluded below.

The hooks are pointer listeners that only observe — they never take part in
hit testing or focus. The logging panel is hooked through its existing
call-info callback instead, because its focus ladder is a contract
([logging-fields.md](logging-fields.md)) that forbids panel-wide key
handling; that also catches the operator who never taps, since the call
field is autofocused. One consequence to know when reading the data:
loading a spot fills the call field, so tapping a spot reports **both**
`spots` and `logging`. That is deliberate — those fields are now in play —
but it does mean `logging` is not evidence of typing.

Home is `MaterialApp.home` and its State is never disposed, so it marks a
visit both on first build and whenever a pushed screen pops back to it
(`homeRouteObserver`). Without that it would report once per launch while
the other two report per visit, and the three counts would not be
comparable.

### Radios

`radio` is the `EquipmentVariant` key — a catalogue id we ship and never
change — so cardinality is bounded by our own catalogue rather than by what
hardware exists. `transport` and `driver` are their keys likewise.

**No config value is ever sent, with two deliberate exceptions.** A serial
`port` embeds the adapter's device serial number on macOS, and the network
transports hold addresses and passwords. The first exception is `baud` on a
failed connect: a mismatch is the classic cause of a silent port, the set of
rates is small and fixed, and it identifies nobody. The second is `name` —
sent on all three `radio_*` events despite being free text, because it is
the only way to tell one radio behind a generic driver from another:
`radio` alone collapses every Kenwood on `kenwood-generic` into one bucket.
This is the one place in the app's telemetry where free text reaches the
backend, and it is not always operator-typed: a discovered node (FlexRadio
over SmartLink) takes its name from the radio's own broadcast nickname,
which the operator never reviews before it is used — see `addDiscovered`.
Two mitigations, both in `_trackRadio`: an empty name (a pre-`name` stored
record, or one blanked out in the editor, which enforces no minimum length)
falls back to the driver's own name — e.g. "Kenwood (CAT)", bounded because
it comes from our own driver catalogue rather than the operator — and every
name is capped at 60 characters before it leaves the device.

`reason` is a bounded classification — `unknown_type`, `invalid_config`,
`timeout`, `network`, `other` — derived from *where* the failure happened,
never the exception's text. `'$e'` is what the operator reads and it
routinely carries the host or port that failed.

All three are reported **once per radio per app session**. The reconnect
loop pokes an unreachable radio every 30 s rising to every 8 minutes for the
whole session (`cat_service.dart`), so per-attempt reporting would bury
every other event and skew the data toward whoever left a rig switched off.
A failure is not re-armed by a later success, for the same reason: the
question is whether a pairing ever fails for people, not how often.

The gap between `radio_added` and `radio_connected` is the interesting one —
it counts radios people can configure but never get working.

#### The first-success report

The events above are counts, and counts cannot answer the question the
equipment catalogue actually asks: **which port, speed and CI-V address got
this rig talking?** `radio` is a catalogue key, so every Kenwood behind
`kenwood-generic` collapses into one bucket, and `radio_connected` fires for a
rig that holds a session and answers nothing.

So a second, separate channel: the first time a node's radio reports **both a
frequency and a mode of its own**, the app uploads that node's whole
configuration — port device name and descriptors, USB VID:PID, baud rate,
CI-V address, every non-secret config value — as an
`ErrorReportingService.diagnostic` titled `Radio working: <variant key>`. One
Sentry issue per pairing, one body per shack.

**This is the one path that ships config values, and it is not the `track`
path.** The rule above — no config value, two exceptions — governs the
anonymous event stream and is unchanged there. Everything that makes this
acceptable is different in kind:

- **`consentAppData` gates it**, checked live at the call site
  (`HaLoServices.reportWorkingRadio`) exactly as `track` checks it. An
  operator who turns the setting off has turned this off too. The setting's
  own wording names configuration alongside usage, crash and performance
  data, which is what makes this in scope rather than a surprise.
- **It goes to the crash backend, not the analytics one**, where the event
  already carries the operator's identity. It is a report about their shack;
  pretending otherwise by routing it through an anonymised channel would be
  worse, not better.
- **Secrets never reach it.** The body comes from
  `equipment_details.dart`, whose exclusion is by DECLARATION across the
  whole catalogue — the same builder the operator-written equipment report
  uses, so a value can never reach one report and not the other.
- **The adapter's serial number never reaches it either**, in EITHER report.
  It fingerprints one physical device and answers nothing either report asks.
  Dropping the field that names it is only half the job: macOS builds the
  device node out of the serial (`cu.usbserial-01AF7D0E1`), so it comes back
  through the port name, the picker label quoted beside it, and the `- Port:`
  config line. `redactSerialNumber` is therefore applied to every finished
  line rather than to one field — the only version that a line added later
  cannot defeat. The price is that two of the same adapter are
  indistinguishable in a report; a serial under four characters is left
  alone, being no fingerprint and worth corrupting no words for.

**Fired once per radio per configuration**, marked in preferences
(`radio_proof.dart`). Not per session: this is an upload, not a count.
Not once-ever either — changing a port or a baud rate and getting the rig
talking is the most useful thing an operator can tell us, so a changed
setting re-arms it. The mark is dropped when the node is deleted, since a
node re-added with the same uuid is the case where a stale mark would
silence the report that matters.

`heardFreq`/`heardMode` track what came off the WIRE, never
`_applyReading`'s merge with `lastSent`. A partial frame is completed from
what the app last TOLD the radio, so a rig that echoes only its frequency
still yields a merged reading with both fields — reporting that would file
"this pairing reads frequency and mode" about the app talking to itself.

#### The equipment tag

Every Sentry event carries a `radio` tag naming the designated radio's
variant key while it is connected, set from `CatService._setState` and cleared
when nothing is. A catalogue id, bounded by what we ship and identifying
nobody, so unlike the report above it needs no consent — it rides along with
`git_sha`. Without it the crash stream names a radio only inside a
`CatConnectFailure` title, which is to say only when one fails.

Instrumentation sites send **generic property keys only**. Decorating events
with build and device context, and renaming keys to whatever a backend's
provider reserves, are the backend's job — deliberately not the call sites',
because a public instrumentation site must not be written against any
particular provider.

Not tracked, deliberately: per-keystroke or per-lookup activity (volume and
privacy), spot browsing, sync round-trips, anything from extensions
(`consentOpData` covers operation-data sharing, a separate concern from
this app-usage channel).

## Implementation

- Public side: the `MetricsService` interface, the consent-gated
  `HaLoServices.track`, and the instrumentation sites — nothing tied to a
  backend.
- Distribution builds inject a backend via `runHaLoApp(metrics: …)`; the
  default everywhere else is `NoopMetricsService`. Whatever a backend does
  with a signal after `logEvent` — transport, batching, retry, failure
  handling — is its own concern and is documented alongside it. Telemetry is
  strictly best-effort and must never affect app behavior.
