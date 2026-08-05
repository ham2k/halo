# Telemetry

Optional, consent-gated event tracking for HaLo, mirroring app-polo's event
vocabulary so both apps report comparable usage.

## Privacy model

- **Consent-gated at one choke point**: `HaLoServices.track` checks the
  user's *Share app usage data* setting (`consentAppData`, off by default,
  asked during onboarding) on **every** call. Instrumentation sites never
  call `MetricsService.logEvent` directly. Turning the setting off silences
  tracking immediately; no restart involved.
- **No identifying data**: the client identifier is a random install-scoped
  UUID, salted and SHA-256 hashed before leaving the device. Event payloads
  carry no callsigns, no locations, no free text — the QSO events send only
  the contact's DXCC prefix and ref *types*.
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
| `radio_added` * | `radio`, `transport`, `driver`, `via` | equipment configured (`discovery`/`manual`) |
| `radio_connected` * | `radio`, `transport`, `driver` | first successful connect, once per radio per session |
| `radio_connect_failed` * | `radio`, `transport`, `driver`, `reason`, `baud` | first failed connect, once per radio per session |

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

**No config value is ever sent, with one deliberate exception.** A serial
`port` embeds the adapter's device serial number on macOS, and the network
transports hold addresses and passwords. The exception is `baud` on a failed
connect: a mismatch is the classic cause of a silent port, the set of rates
is small and fixed, and it identifies nobody.

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
