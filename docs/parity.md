# PoLo → HaLo Feature Parity

A working inventory of what Ham2K Portable Logger (app-polo, RN) has that
HaLo doesn't yet. First full sweep 2026-07-24 (PoLo 26.7.2); re-audited and
re-swept 2026-07-28 (PoLo still 26.7.2, HaLo dist `92ad710`). Update as gaps
close; this is a tracking document, not a roadmap — see DESIGN.md §10 for
sequencing intent.

Legend: ⛔ missing entirely · 🟡 partial · 🧭 prerequisite work needed first

## 0. Closed since the first sweep (2026-07-24 → 2026-07-28)

- **Contest support** — was ⛔ with prerequisites. Now: `ContestScorer`
  contract + harness, exchange input catalog (`text|serial|form|options`
  alongside `refList`), serial sequence service, Cabrillo writer, operation
  segments (scoring side), and 7 contests: simple-contest, CQ WW, CQ WPX,
  ARRL DX, IARU HF, NAQP, State Parks (4 events). PRs #344, #370, #380,
  #389, #399, #414, #415, #417.
- **Activity catalog** — was POTA + SOTA only. Now 18 programs: + WWFF,
  WWBOTA, GMA, SiOTA, ZLOTA, LLOTA, MOTA, TOTA, WCA, BCA, ECA, BLHA, ELA,
  PGA, Satellites, Custom. Activation scoring (`activityScorer`),
  per-reference export files, n-fer record splitting. PRs #398, #411, #412,
  #413, #416, #427.
- **Export options** — grouped per-station-callsign export modal with a
  private-data switch (#452); Cabrillo + per-activity/per-contest ADIF;
  compact-filename option.
- **Onboarding "existing account" branch** — done (`onboarding_overlay.dart`
  link-account step).
- **Multiple station calls** — data layer done (`Operation.stationCalls`),
  consumed by export grouping. Operator model beyond that still open (§2).
- **Bearing setting** is now consumed (`call_info_panel.dart`); the
  "stored but not consumed" comment in `core_settings_groups.dart` is stale
  for this one item only.

## 1. Structural gaps (biggest leverage)

| Gap | PoLo has | HaLo status |
| --- | --- | --- |
| **Import** | Per-operation "Add QSOs from ADIF" + global "Import History from ADIF" feeding worked-before detection; QSON import with merge/dedup (`mergeQSOs`) | ⛔ no import path of any kind (DESIGN §10 step 2 goal) |
| **Contest breadth** | 12 contest extensions + Field Day + Winter Field Day | 🟡 7 ported. Missing: FD, WFD, RSGB/R1 VHF, QSO Parties, GAPOTA, 13 Colonies. Next per RFC §7: M7 VHF distance + `grid` input, M8 EDI writer, M9 cross-extension POTA ref synthesis, M10 full QP rules |
| **Export breadth** | 29 ADIF variants, 11 Cabrillo, QSON, REG1TEST/EDI; user-editable Handlebars templates for filename **and title and ADIF notes/comments/QSL message**, per-export-type overrides; "ignore lookup data" toggle; Wavelog upload with station selection | 🟡 whole-log + per-activity + per-contest ADIF, Cabrillo, private-data switch, QSON dump (dev-mode only, `export_service.dart`). No REG1TEST/Wavelog, no user-editable templates (deliberately dropped — `exportNames.ts`), no ignore-lookup-data. Also: PoLo emits `APP_HAM2K_*` app fields (renamed from `X_` in 26.7.2+); HaLo emits none — decide compatibility when import lands |
| **Activity catalog** | 21 activity dirs + WAB (under `other/`) | 🟡 18 ported. Missing: **13 Colonies**, **FD/WFD** (both moved to the contest thread), **WAB squares** |
| **Lookup providers** | QRZ, HamQTH, QRZCALL.EU, HamDB, **Call History** (worked-before from own log + imported ADIF history), Spot History; call-notes with **user-added custom note files (name + URL management screen)** | 🟡 QRZ + HamDB + call-notes (single built-in file) + spot-history (ported; refs off recent spots, 30-min window vs PoLo's 10). Cross-operation worked-before EXISTS (`historyForCall`, shown in call info as "N QSOs in other operations") — the gap is a lookup *provider*: prior-QSO name/state/grid never feed the guess merge, and there's no imported-history source. Lookup caching explicitly deferred (`lookup_queue_service.dart`) |

## 2. Gaps within existing surfaces

### Logging
- Secondary controls: **Notes**, **TxPower**, **CW Key** chips still missing
  (Notes reachable only inside the "more" pane's form). The control-set
  manager itself (add/remove/reorder chips) is DONE, as is the Spotter
  control.
- Commands: power (`5W`), time/date set, `SET`, operator change, `RTFM`,
  `EXCUSE`. (Note/todo/solar/weather, the SPOT/QRV/QRT/QSY family,
  band/mode/freq are done. `LANG` and the debug commands are tracked
  under Developer tooling in §3.)
- **Segment creation** ⛔: PoLo's `START`/`BREAK`/`STOP` commands insert
  segment markers. HaLo's read path is complete — segment rows render,
  `SegmentedOperation` scores, and `QsosRepository.addEvent` exists — but
  `addEvent` has zero production callers: **nothing in HaLo can create a
  segment**; they arrive only from synced PoLo logs.
- RST auto-expansion 🟡: exists (`defaultRSTFor`) but is bare 59/599, and
  its phone-mode set is `SSB/FM/AM` only — a USB or LSB QSO defaults to
  599.
- **Log events** 🟡: note/todo/solar/weather rows are stored and rendered,
  but there's no dedicated editor (taps fall into the generic QSO form),
  no todo done-toggle in the UI, and no "pending to-dos" warning on export
  (PoLo warns).
- HaLo-internal ⚠️: leftie mode, fields-on-top, country flags, report
  order, jump-after-RST are still **stored and shown in Settings but not
  consumed** (`core_settings_groups.dart`; bearing is now consumed). Also:
  PoLo's country-flags setting is tri-state (none / DX only / all), not a
  boolean.

### Station & operator model
- `/P`-style suffixes as first-class, club / multi-operator handling with
  QSO-migration prompts, "suggest default operator", multi-profile actually
  in use (HaLo: profiles scaffolded, single profile active).
- **Multi-station flag + station identifier** (free-text) on an
  operation. ⛔

### Operations
- **Operation templates** ("use as template" + suggestions on create). ⛔
- **Operation undelete** UI (HaLo soft-deletes; QSO-level restore exists,
  operation-level doesn't). ⛔
- **Operation badge** screen (full-screen map/stats badge, reached from
  the map tab; user screenshots it manually — no share code). ⛔
- Keep-device-awake while logging. ⛔
- Op info stats: HaLo has counts, rates (last 10/100), dupes, score
  summaries (#409); missing per-day breakdown in the info panel.

### Spots
- **Global Spots screen** reachable from Home (outside any operation). ⛔
- ParksnPeaks spot source; Discord spot posting. ⛔
- POTA **"Confirm Spots"** QSO-confirmation flow. ⛔
- (Spot filters — band/mode/age/sort/per-source — are done, plus a
  continent filter PoLo lacks. Sources beyond POTA/SOTA are done: 10
  extensions feed spots. Deliberate divergence on bands: PoLo offers only
  the bands that currently have spots, HaLo offers the operator's enabled
  bands as well and narrows the list itself to them when no single band is
  chosen.)

### Integration
- Deep links: **`/qso`** (with multi-call `their.call=A,B` and
  `their.refs=`), **`/vfo`**, and **`/operation`** (`our.refs=` →
  find-or-create-and-open, PoLo #235) — the de-facto WSJT-X bridge. HaLo
  handles only auth callbacks; `/qso` and `/link_client` are reserved in a
  comment, unimplemented. ⛔

### Sync
- Guided linking scenarios (HaLo: bare Combine/Replace banner — backlog). 🟡
- Linked-devices list + connection-request approval UI. ⛔ (HaLo links via
  QR/email; the accounts dialog lists accounts, not devices.)
- LoFi **plan/subscription display**. ⛔ (Server picker and
  reset-sync-status are devMode-only in PoLo — tracked under Developer
  tooling in §3.)

### Home & onboarding
- Quick lookup 🟡: HaLo's home search runs commands and shows a one-line
  lookup summary; PoLo resolves a callsign into full Call Info, and has a
  standalone CallInfo screen from Home. (HaLo's `CallInfoPanel` is full-
  featured but only reachable inside an operation.)
- Onboarding activities step 🟡: HaLo's is two hardcoded POTA/SOTA
  toggles; PoLo's is a picker over the activity extensions.

### Scoring
- US-states and Canadian-provinces handlers still deferred
  (`extensions/core/scoring/src/scoring.ts`); NAQP/ARRL-DX carry local
  tables as a workaround. 🟡

## 3. Platform & polish

- **i18n**: PoLo ships ~14 Crowdin locales + tone variants (cw/qrp/qro);
  HaLo has en + es.
- Settings PoLo has: keep-awake, 8- vs 6-digit grid precision,
  smart-keyboard toggles, comma **and period/slash** keys on numbers row
  (HaLo shows one contextual extra key). (Haptics is NOT a gap — PoLo also
  vibrates only the numbers row; the first sweep got this wrong.)
- **Credits / community links** (Discord, forums, YouTube, manual, contact)
  — HaLo has none. ⛔
- Accessibility: PoLo has a systematic a11y-label layer (`a11yTools.js`);
  HaLo has stable semantic identifiers + spot coverage (~18 of ~60 UI
  files) after #433. 🟡
### Developer tooling (dev-mode features are parity items too)

Covered on both sides: dev-mode toggle, seeded fake QSOs (`SEED`),
synthetic error (`ERROR!` ≈ `DEVSENTRY`), sample notices (`NOTICE` ≈
`DEVNOTICE`), onboarding re-run (`ONBOARD` ≈ `DEVONBOARD`), `SYNCALL`,
dev QSON export.

PoLo has, HaLo lacks:
- **Database surgery**: `WIPE!`/`WIPEDB!` (wipe QSOs / whole DB),
  `FACTORY!` (factory reset), `RECOVER!`, replace-database-from-file, and
  **QSON import** (also the doc's §1 import gap, but the dev-mode QSON
  round-trip is the cheap first step and the natural test harness for the
  real importer). ⛔
- **"Share system information"** diagnostic bundle for support. ⛔
- `SYNCUP` (push-only sync) and `RESETNOTICES`. ⛔
- **Crowdin live-translation mode** (personal-token, in-app) and `LANG`
  (locale override) — moot until i18n grows past en+es, then needed. 🧭
- Download-location override; Wavelog experiments toggle. ⛔
- devMode-only sync controls: **LoFi server picker** (named + custom) and
  **Reset Sync Status** — HaLo's transport reads `kvGet('server')` but no
  UI writes it, and there's no resync-from-zero action; both are the kind
  of escape hatch support conversations end up needing. ⛔

HaLo has, PoLo lacks: `DEVSTATUS`/`DEVPROGRESS` (status-bar exercisers),
`DEVSPLASH` (re-show release overlay), `RELOAD` (force data-file re-sync
past the staleness gate), `EXP` (experiments from experiments.yaml).

## 4. Where HaLo is ahead (not gaps — context)

Desktop platforms (macOS/Windows/Linux/web) with Sparkle/WinSparkle
self-update + Shorebird patches; dock layouts and keyboard-first logging;
sandboxed extension runtime with static manifests and per-locale string
catalogs; consent-gated telemetry with a vendor-free public app; spot
continent filter; segment-sliced exports; secondary-control **reorder**
(PoLo's manager only shows/hides, order is fixed). (The first sweep listed
SOLAR/WEATHER annotations here — wrong: PoLo has both as commands.
Server-driven notices + remote feature flags exist in both.)

## 5. Suggested closing order

1. ADIF import (per-operation, then history import for worked-before);
   QSON import rides along.
2. Call History lookup (worked-before pills in call info).
3. Deep links `/qso`, `/vfo`, `/operation` (WSJT-X bridge).
4. Segment-creation commands (`START`/`BREAK`/`STOP`) — the scoring and
   rendering halves already exist.
5. Export templates + REG1TEST/Wavelog (+ user-facing QSON); remaining
   contests (M7–M10, FD/WFD, QSO Parties) and 13 Colonies + WAB.
6. Multi-station / operator model.
7. Long tail (providers, log-event editors, polish).
