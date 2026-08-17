# PoLo → HaLo Feature Parity

A working inventory of what Ham2K Portable Logger (app-polo, RN) has that
HaLo doesn't yet. First full sweep 2026-07-24 (PoLo 26.7.2); re-swept
2026-07-28 (PoLo 26.7.2, HaLo `92ad710`) and 2026-08-04 (PoLo **26.7.3**
`7acb7198`, HaLo main **`73bcd5e2`**). Update as gaps close; this is a
tracking document, not a roadmap — see DESIGN.md §10 for sequencing intent.

Legend: ⛔ missing entirely · 🟡 partial · 🧭 prerequisite work needed first

## 0. Closed since the previous sweep (2026-07-28 → 2026-08-04)

- **Field Day + Winter Field Day** — contests M11 (#435). `fd` and `wfd`
  ship as contest extensions with the ARRL/RAC section table, power
  multiplier and bonuses. HaLo now carries 9 of PoLo's 15 contest-shaped
  extensions.
- **Call-notes custom files** — the whole PoLo "name + URL management
  screen" equivalent (HALO-53): enable/disable builtin sources, add custom
  note files by URL with reorder/delete, gist/Dropbox/Drive share-link
  resolution, and a Manage link from the Data Files screen.
- **Activity refs from recent spots** (HALO-80) — the spot-history lookup
  now feeds `their.refs`, not just a callsign hit.
- **Leftie mode** is consumed (#524, `logging_panel.dart`); **country
  flags** became tri-state (`dxFlags`: none/DX/all), matching PoLo's shape
  — though it is still not consumed (§2).
- **Default reports** — configurable per phone/CW/FT8, rendered as a
  placeholder rather than a pre-filled value, with shorthand completion
  (HALO-83). Closes most of the RST auto-expansion gap; the USB/LSB
  misclassification is gone.
- **Multiple references per QSO** for ZLOTA, WWBOTA, WCA, TOTA, SiOTA,
  MOTA, LLOTA, ELA, ECA, BLHA, BCA (HALO-138).
- **Band/mode integrity** — every contact requires a band or frequency and
  is asked for it up front (HALO-24); mode is guessed from the band plan
  using the operator's real ITU region/country (HALO-32, HALO-52).
- **Spots** — sort-by-time flat list + Group by Band toggle (HALO-16), and
  the band filter honours the operator's enabled bands (HALO-57).
- **Sync settings** — server-side counts shown next to this device's
  (HALO-92); the account is described by email, not callsign (HALO-81).
- **Data files** — Update All button (#459), fetch timeouts, reconnect
  resync, web conditional-GET retry (HALO-74, HALO-30).
- **ParksnPeaks** (HALO-19) — the VK/ZL spot source, reading and posting,
  narrowed to WWFF and SiOTA. Brings spot sources to 15.
- **Report order and jump-after-RST** (HALO-143) — both were stored and
  shown but read by nothing; now wired, leaving two dead settings (§2).
- **US states and Canadian provinces** scored by the core scorer, and
  band/mode newness notifications aligned with PoLo's (HALO-42).

## 1. Structural gaps (biggest leverage)

| Gap | PoLo has | HaLo status |
| --- | --- | --- |
| **Import** | Per-operation "Add QSOs from ADIF" + global "Import History from ADIF" feeding worked-before detection; QSON import with merge/dedup (`mergeQSOs`) | 🟡 **Per-operation import landed** (HALO-173) and **PoLo's separate "history-only" import isn't needed** — the Logs view's own ADIF import (`logs_view.dart`, `AdifImportService`) writes real QSOs into an operation, same as the per-operation path, so any worked-before detection (Call History, HALO-304) already sees them; there is no reason to duplicate that as a second, history-only store. The parser (HALO-166) turns ADIF into QSON against a ten-logger corpus, with same-band/supermode/5-minute merging, station-call rewriting and activation hoisting. `adifImport` recovers references for every activity except `custom` — see hooks.md for why it has none. Missing: QSON import |
| **Contest breadth** | 12 contest extensions + Field Day + Winter Field Day + 13 Colonies (15 total) | 🟡 **9 ported** (+FD/WFD since the last sweep). Missing: ARRL VHF (M7), R1/RSGB VHF (M8), GAPOTA (M9), full QSO Parties (M10), 13 Colonies (M12). Next per RFC §7: **M7** — great-circle distance scoring + `grid` input + rover our-grid from segments |
| **Export breadth** | 29 ADIF variants, 11 Cabrillo, QSON, REG1TEST/EDI; user-editable Handlebars templates for filename **and title and ADIF notes/comments/QSL message**, per-export-type overrides; "ignore lookup data" toggle; Wavelog upload with station selection; **Ham2K File Stash export** (new in 26.7.3) | 🟡 whole-log + per-activity + per-contest ADIF, Cabrillo, private-data switch, QSON dump (dev-mode only, `export_service.dart`). No REG1TEST/EDI, no Wavelog, no File Stash, no user-editable templates (deliberately dropped — `exportNames.ts`), no ignore-lookup-data. Also: PoLo emits `APP_HAM2K_*` app fields (renamed from `X_` in 26.7.2+); HaLo emits none — decide compatibility when import lands |
| **Activity catalog** | 21 activity dirs + WAB (under `other/`) | 🟡 **18 ported — the catalog is effectively closed.** `fd`/`wfd` shipped as contests; only **13 Colonies** (contest thread, M12) and **WAB squares** remain |
| **Lookup providers** | QRZ, HamQTH, QRZCALL.EU, HamDB, **Call History** (worked-before from own log + imported ADIF history), Spot History; call-notes with user-added custom note files | 🟡 QRZ + call-notes (**custom files now done**, HALO-53) + spot-history (now also yielding activity refs; 30-min window vs PoLo's 10) + **Call History** (HALO-304 — identity/location fields, dropping a portable/prefixed location; a manually-typed field outranks every live source, a guessed-only one is outranked by all of them; "imported ADIF history" needs no separate mechanism — see the Import row above, an ADIF import from the Logs view is already ordinary QSOs) + **Ham2K Lookup Service** (HaLo-only, not in PoLo — free, US/Canada/Germany, `services.ham2k.net`). HamDB was ported then removed in favor of Ham2K Lookup Service, which covers the same 3 countries; the one regression is grid/lat/lon, which HamDB supplied and Ham2K Lookup Service does not (yet) return. Missing providers: HamQTH, QRZCALL.EU. Lookup caching explicitly deferred (`lookup_queue_service.dart`) |

## 2. Gaps within existing surfaces

### Logging
- Secondary controls: **Notes**, **TxPower**, **CW Key** chips still
  missing. HaLo's descriptor set is `time`, `radio`, `spotting`, the
  activity `refList` controls, and `more` (`logging_controls.dart`
  `_controlDescriptors`); Notes is reachable only inside the "more" pane's
  form. The control-set manager (add/remove/reorder) and the Spotter
  control are DONE.
- Commands: **power** (`5W`), **time/date set** (`+1h`, `NOW`, `TODAY`,
  `YESTERDAY`, explicit dates), **`SET`**, **operator change** (`OP.`),
  **`CHAT`**, **`RTFM`**, **`EXCUSE`**. (Note/todo/solar/weather, the
  SPOT/QRV/QRT/QSY family, band/mode/freq are done. `LANG`/`CROWDIN` and
  the debug commands are tracked under Developer tooling in §3.)
- **Segment creation** ⛔ (unchanged): PoLo's `START`/`BREAK`/`STOP`/`END`
  commands insert segment markers. HaLo's read path is complete — segment
  rows render, `SegmentedOperation` scores, and `QsosRepository.addEvent`
  exists — but `addEvent` still has **zero production callers** (tests
  only): nothing in HaLo can create a segment; they arrive only from synced
  PoLo logs.
- RST auto-expansion ✅ — closed by HALO-83 (per-mode configurable default,
  shown as a placeholder, shorthand completion).
- **Log events** 🟡: note/todo/solar/weather rows are stored and rendered,
  but there's no dedicated editor (taps fall into the generic QSO form),
  no todo done-toggle in the UI, and no "pending to-dos" warning on export
  (PoLo warns).
- HaLo-internal ⚠️: **fields-on-top** and **country flags** (`dxFlags`) are
  still stored, shown in Settings and published to the extension host
  (`extension_service.dart`) but **not consumed by any view**. Leftie mode,
  bearing, report order and jump-after-RST have all left this list —
  the last two via HALO-143.

### Station & operator model
- `/P`-style suffixes as first-class, club / multi-operator handling with
  QSO-migration prompts, "suggest default operator", multi-profile actually
  in use (HaLo: profiles scaffolded, single profile active).
- **Multi-station flag + station identifier** (free-text) on an
  operation. ⛔ PoLo 26.7.3 also now spots multi-station operations as
  `/OP{n}` — same thread.

### Operations
- **Operation templates** ("use as template" + suggestions on create). ⛔
- **Operation undelete** UI (HaLo soft-deletes; QSO-level restore exists,
  operation-level doesn't). ⛔
- **Operation badge** screen (full-screen map/stats badge, reached from
  the map tab; user screenshots it manually — no share code). ⛔
- Keep-device-awake while logging. ⛔ (no wakelock dependency at all)
- Op info stats: HaLo has counts, rates (last 10/100), dupes, score
  summaries (#409); missing per-day breakdown in the info panel.

### Spots
- **Global Spots screen** reachable from Home (outside any operation). ⛔
- Discord spot posting. ⛔
- POTA **"Confirm Spots"** QSO-confirmation flow. ⛔
- (Spot filters — band/mode/age/sort/per-source — are done, plus a
  continent filter PoLo lacks, plus Group-by-Band and a flat time-sorted
  list. Sources beyond POTA/SOTA are done: 15 extensions feed spots,
  ParksnPeaks among them. Deliberate divergence on bands: PoLo offers only
  the bands that currently have spots, HaLo offers the operator's enabled
  bands as well and narrows the list itself to them when no single band is
  chosen.)

### Integration
- Deep links: **`/qso`** (with multi-call `their.call=A,B` and
  `their.refs=`), **`/vfo`**, and **`/operation`** (`our.refs=` →
  find-or-create-and-open, PoLo #235) — the de-facto WSJT-X bridge. HaLo's
  `DeepLinkService` handles auth callbacks only; `/qso` and `/link_client`
  are reserved in a comment, unimplemented. ⛔

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
- Onboarding activities step 🟡: HaLo's is three hardcoded POTA/SOTA/WWFF
  toggles; PoLo's is a picker over the activity extensions.

### Scoring
- US states and Canadian provinces are scored by the core scorer, which
  carries the two lists inline (`extensions/core/scoring/src/scoring.ts`);
  NAQP/ARRL-DX still carry their own local tables. What is not ported is
  web-lofi's per-handler summary presentation — its struck-through grid of
  worked/unworked states — only the rules and a count. 🟡
- What NOTIFIES now matches PoLo on band/mode: its `DefaultScoringHandler`
  emits `newBand`/`newMode` only for a station already in the log, and has no
  operation-level rule. HaLo's operation-level newness is a tally with no
  pill. `newDXCC` is HaLo's own (PoLo's default handler emits no DXCC notice
  at all), and it stays silent for the operator's own entity.

## 3. Platform & polish

- **i18n**: PoLo ships ~14 Crowdin locales + tone variants (cw/qrp/qro);
  HaLo has en + es (unchanged).
- Settings PoLo has: keep-awake, 8- vs 6-digit grid precision,
  smart-keyboard toggles, comma **and period/slash** keys on numbers row
  (HaLo shows one contextual extra key). (Haptics is NOT a gap — PoLo also
  vibrates only the numbers row; the first sweep got this wrong.)
- **Credits / community links** (Discord, forums, YouTube, manual, contact)
  — PoLo has a whole `CreditsSettingsScreen`; HaLo has none. ⛔
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
- **"Share system information"** diagnostic bundle for support. 🟡 HaLo's
  developer settings now *display* a System Information block (device key,
  version, data folder) — there is no shareable bundle.
- `SYNCUP` (push-only sync) and `RESETNOTICES`. ⛔
- **Crowdin live-translation mode** (personal-token, in-app) and `LANG`
  (locale override) — moot until i18n grows past en+es, then needed. 🧭
- Download-location override; Wavelog experiments toggle. ⛔
- devMode-only sync controls: **LoFi server picker** (named + custom) and
  **Reset Sync Status** — HaLo's transport reads `kvGet('server')` but no
  UI writes it, and there's no resync-from-zero action; both are the kind
  of escape hatch support conversations end up needing. ⛔

HaLo has, PoLo lacks: `DEVSTATUS`/`DEVPROGRESS` (status-bar exercisers),
`DEVSPLASH` (re-show release overlay), `DEVTESTER` (tester-notes overlay),
`RELOAD` (force data-file re-sync past the staleness gate), `EXP`
(experiments from experiments.yaml).

## 4. Where HaLo is ahead (not gaps — context)

- **CAT / rig control** — PoLo has none at all. HaLo ships an equipment
  registry with Icom CI-V, Yaesu (FT-891), Kenwood, FlexRadio, Hamlib
  `rigctld` and `flrig` drivers over serial, TCP, Icom-network and **Web
  Serial** transports, plus discovery, adaptive polling and Smart VFO Snap
  (HALO-64/67/68/69/91/94/131).
- Desktop platforms (macOS/Windows/Linux/web) with Sparkle/WinSparkle
  self-update + Shorebird patches; dock layouts and keyboard-first logging.
- **Command palette** (⌘K / ⌘⌥K) over commands, callsigns and navigation,
  with opt-in suggestions (HALO-87/89).
- Sandboxed extension runtime with static manifests, per-locale string
  catalogs, and declarative extension settings panels (HALO-55/59).
- Consent-gated telemetry with a vendor-free public app; server-driven
  notices with an ErrorPolicy that decides notice-vs-silent in one place.
- **Per-build tester-notes overlay** for the Dev/Next editions (HALO-132).
- Spot continent filter; segment-sliced exports; secondary-control
  **reorder** (PoLo's manager only shows/hides, order is fixed).
- Per-edition private storage folder (HALO-100) and a Windows uninstall
  data prompt (HALO-99).

## 5. Suggested closing order

1. ~~**ADIF import**~~ — done. Per-operation (HALO-173) and Logs-view
   whole-log (`AdifImportService`) both land ordinary QSOs, so there is no
   separate "history-only" import to build — PoLo's structural ⛔ here
   doesn't apply to HaLo's shape. QSON import is the one remaining gap, but
   it's not structural.
2. ~~**Call History lookup**~~ — done (HALO-304); no imported-ADIF-history
   half needed, per item 1.
3. Deep links `/qso`, `/vfo`, `/operation` (WSJT-X bridge).
4. Segment-creation commands (`START`/`BREAK`/`STOP`) — the scoring and
   rendering halves already exist; this is the cheapest remaining ⛔ on the
   list.
5. Consume the two remaining dead logging settings (fields-on-top, country
   flags) — they are already stored, surfaced and published; only the views
   are missing.
6. Remaining contests M7–M10 + 13 Colonies (M12); WAB.
7. Export templates + REG1TEST/Wavelog (+ user-facing QSON).
8. Multi-station / operator model.
9. Long tail (remaining lookup providers, log-event editors, global Spots
   screen, credits/community links, polish).
