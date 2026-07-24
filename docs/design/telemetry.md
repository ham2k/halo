# Telemetry (MetricsBackend)

Event tracking for HaLo (ham2k/app-halo-dist#255), mirroring app-polo's
MetricsBackend usage so both apps report a comparable event vocabulary.

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
- **OSS builds are silent — and vendor-free**: this repo contains only the
  generic `MetricsService` interface (no-op by default) and the consent
  gate. All MetricsBackend-specific code lives in the private distribution
  layer (`app_dist`), which launches the app through its own entrypoint
  and injects the real backend via `runHaLoApp(metrics: …)`. A plain
  `flutter run` of this repo never carries analytics code at all.
- Debug distribution builds send with MetricsBackend's `isTestMode` flag,
  keeping dev traffic out of production charts.

## Events

Names and property keys follow app-polo's set; HaLo-only additions marked *.

| Event | Properties | When |
| --- | --- | --- |
| `app_started` | UI prefs (language, colorScheme, fontScale) | once per launch |
| `screen_viewed` | `screen` (`operation`, `settings`) | major surface opened (app-polo's `navigation` analog) |
| `operation_created` | — | new operation |
| `operation_deleted` | — | confirmed delete |
| `operation_exported` | `formats`, `files` | export generated |
| `qso_added` / `qso_edited` / `qso_deleted` / `qso_undeleted` | `their_prefix`, `refs` (types only) | logging actions |
| `activity_added` / `activity_removed` | `activity` (ref type) | operation activity refs |
| `command_executed` | `command` (action name) | call-field command actions |
| `notice_shown` / `notice_dismissed` | `notice_key` | remote notices (FlagsService) |
| `extension_enabled` / `extension_disabled` * | `extension` | Extensions panel toggle |
| `sync_enabled` / `sync_disabled` * | — | Sync settings toggle |

Instrumentation sites send only generic property keys; the distribution
backend attaches MetricsBackend's default-parameter namespace (AppInfo,
Device, RunContext) to **all** signals per MetricsBackend's recommendation,
where app-polo only decorates `app_started`.

Not tracked, deliberately: per-keystroke or per-lookup activity (volume and
privacy), spot browsing, sync round-trips, anything from extensions
(`consentOpData` covers operation-data sharing, a separate concern from
this app-usage channel).

## Implementation

- Public side: the `MetricsService` interface, the consent-gated
  `HaLoServices.track`, and the instrumentation sites — nothing
  vendor-specific.
- Private side (`app_dist`): the MetricsBackend implementation (pure Dart
  against the v2 ingest API, so one implementation covers every platform
  including web) and the `main_dist.dart` entrypoint the official builds
  use, which injects it via `runHaLoApp(metrics: …)` with the app id and
  salt from CI dart-defines. Signals queue until the hashed client id
  resolves, then send in order; failures drop the queue and log —
  telemetry is strictly best-effort and must never affect app behavior.
