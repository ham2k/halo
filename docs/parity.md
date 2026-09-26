# PoLo → HaLo Feature Parity

A working inventory of what Ham2K Portable Logger (app-polo, RN) has that
HaLo doesn't yet. First full sweep 2026-07-24 (PoLo 26.7.2); re-swept
2026-07-28 (PoLo 26.7.2, HaLo `92ad710`), 2026-08-04 (PoLo 26.7.3
`7acb7198`, HaLo main `73bcd5e2`) and 2026-09-03 (PoLo **26.7.7**
`98b045b0`, HaLo main **`de4e6341`**). Update as gaps close; this is a
tracking document, not a roadmap — see DESIGN.md §10 for sequencing intent.

Legend: ⛔ missing entirely · 🟡 partial · 🧭 prerequisite work needed first

## 0. Closed since the previous sweep (2026-08-04 → 2026-09-03)

PoLo moved 67 commits (26.7.3 → 26.7.7), HaLo 376. Almost all of PoLo's are
fixes to ground HaLo already covers; the sweep's movement is on the HaLo side.

- **ARRL VHF (M7)** and **R1/RSGB VHF (M8)** contests (HALO-295, HALO-296),
  the latter bringing a **REG1TEST/EDI export writer**. Contest extensions
  are now 13 to PoLo's 15.
- **ARRL 10 GHz and Up** scored on both sides in the same week (HaLo
  `e5399e5b`, PoLo `98b045b0`) — grid-only distance and reverse bearings.
- **CWops CWT** — a contest HaLo has and PoLo does not (§4).
- **Templating** (HALO-201) — one Handlebars-shaped renderer behind a
  `template` hook, used for panels, export filenames and ADIF text. The
  export row's "no user-editable templates" is now only about the
  per-export-type override UI.
- **APP_HAM2K_* ADIF fields** are emitted (`APP_HAM2K_POSITION`), matching
  PoLo's 26.7.2 rename away from `X_`.
- **Country flags** (`dxFlags`) is consumed (`de4e6341`), leaving
  **fields-on-top** as the last stored-but-dead logging setting.
- **Power** as a secondary control, and power on the VFO (HALO-198);
  **per-QSO station info** — rig, antenna, key, power (HALO-263).
- **`SET`/`SHOW`/`HIDE`** commands (HALO-151) and **`OPER`** (operator
  change, PoLo's `OP.`); operator and operating **position** travel with the
  operation and its QSOs.
- **Multi-station identifier** per device, appended to self-spots
  (`b83dbeb6`) — matching PoLo's `/OP{n}` (`bf0c090c`), landed the same week.
- **Quick Lookup** shows the logging panel's full call info, and Enter opens
  the panel (HALO-408) — closes the Home-screen call-info gap.
- **Log-event editing** — a NOTE/TODO/BREAK row is edited in place
  (`528c39eb`), not through a time-only dialog.
- **Per-day/operation scoring summaries** matched to PoLo's info panel
  (`8855d622`).
- **Segment commands** `START`/`BREAK`/`STOP`/`ROVERQTH` (HALO-108).
- **Call History** lookup as a last-resort fallback (HALO-304, HALO-453) and
  a worked-before count in Call Info (`17538454`).
- **Ham2K Lookup Service** replaces HamDB on both sides the same week
  (HaLo `06a3d837`/`5eace64b`, PoLo `12f6f8c2`).
- **Sync device linking**: the approving side is a real UI (Confirm a
  device, HALO-9) and `com.ham2k:///link_client` is implemented — the doc's
  claim that it was only a reserved comment was stale.
- **Coordinates, not just grids**, captured everywhere (HALO-349).
- **Cross-operation Logs view** by station callsign (HALO-273), with ADIF
  import, and a **hunter/chaser export** (HALO-274).
- **Inbound QSO capture from N1MM+ and WSJT-X** (HALO-306) — not PoLo's
  deep-link bridge, but it serves the same WSJT-X case by another route.

New on PoLo's side since 26.7.3, and open here: **Ham2K File Stash export**
(`c4838811`, `fd657e23`) and two more locales (Italian, Korean). PoLo's QSO
Party scoring work is closed on this side by M10 (§1), which ports it and
fixes four rules it carries but never awards.

## 1. Structural gaps (biggest leverage)

| Gap | PoLo has | HaLo status |
| --- | --- | --- |
| **Import** | Per-operation "Add QSOs from ADIF" + global "Import History from ADIF" feeding worked-before detection; QSON import with merge/dedup (`mergeQSOs`) | 🟡 **Per-operation import landed** (HALO-173) and **PoLo's separate "history-only" import isn't needed** — the Logs view's own ADIF import (`logs/logs_adif_drop.dart`, `AdifImportService`) writes real QSOs into an operation, same as the per-operation path, so any worked-before detection (Call History, HALO-304) already sees them; there is no reason to duplicate that as a second, history-only store. The parser (HALO-166) turns ADIF into QSON against a ten-logger corpus, with same-band/supermode/5-minute merging, station-call rewriting and activation hoisting. `adifImport` recovers references for every activity except `custom` — see hooks.md for why it has none. Missing: QSON import |
| **Contest breadth** | 12 contest extensions + Field Day + Winter Field Day + 13 Colonies (15 total) | 🟡 **13 of the 15 ported** (+M7 ARRL VHF and M8 R1/RSGB VHF since the last sweep, with ARRL 10 GHz scored inside `arrl-vhf-tests`), plus **CWT**, an extension PoLo lacks. **QSO Parties (M10)** ships 49 operable parties (50 files; NSARA is disabled by its own sponsor's data), including Maine, which PoLo does not have, with county-line N×M scoring, rolling rover location off segments, and several rules PoLo documents but does not award (power multipliers, the bonus-station sweep, the DX-entity cap, `DIGI` points). Missing: **GAPOTA (M9)** and **13 Colonies (M12)**. Next per RFC §7: **M9** |
| **Export breadth** | 29 ADIF variants, 11 Cabrillo, QSON, REG1TEST/EDI; user-editable Handlebars templates for filename **and title and ADIF notes/comments/QSL message**, per-export-type overrides; "ignore lookup data" toggle; Wavelog upload with station selection; **Ham2K File Stash export** (new in 26.7.3) | 🟡 whole-log + per-activity + per-contest ADIF, **Cabrillo**, **REG1TEST/EDI** (HALO-296), a **hunter/chaser export** (HALO-274) PoLo has no equivalent of, segment-sliced exports, private-data switch, QSON dump (dev-mode only, `export_service.dart`). HaLo now emits `APP_HAM2K_*` fields (`APP_HAM2K_POSITION`) and **templating exists** (HALO-201: one renderer behind the `template` hook, driving filenames, panels and ADIF text). Missing: **Wavelog**, **Ham2K File Stash** (new in 26.7.3), per-export-type template overrides in the UI, ignore-lookup-data, user-facing QSON |
| **Activity catalog** | 21 activity dirs + WAB (under `other/`) | 🟡 **18 ported — the catalog is effectively closed.** `fd`/`wfd` shipped as contests; only **13 Colonies** (contest thread, M12) and **WAB squares** remain |
| **Lookup providers** | QRZ, HamQTH, QRZCALL.EU, HamDB, **Call History** (worked-before from own log + imported ADIF history), Spot History; call-notes with user-added custom note files | 🟡 QRZ + call-notes (**custom files now done**, HALO-53) + spot-history (now also yielding activity refs; 30-min window vs PoLo's 10) + **Call History** (HALO-304, HALO-453 — identity/location fields, dropping a portable/prefixed location; registered last of every lookup source, so the log fills only what nothing live answered, a manually-typed field included; "imported ADIF history" needs no separate mechanism — see the Import row above, an ADIF import from the Logs view is already ordinary QSOs) + **Ham2K Lookup Service** (HaLo-only, not in PoLo — free, US/Canada/Germany, `services.ham2k.net`). HamDB was ported then removed in favor of Ham2K Lookup Service, which covers the same 3 countries and, like HamDB, answers a US or Canadian record with a grid; the residual gap is the lat/lon pair, which HamDB supplied and Ham2K Lookup Service does not return for any record (nor a grid for a German one). Missing providers: HamQTH (a sample extension only, `extensions/samples/k2hrc-hamqth`), QRZCALL.EU. Lookup caching explicitly deferred (`lookup_queue_service.dart`) |

## 2. Gaps within existing surfaces

### Logging
- Secondary controls: **Notes** and **CW Key** chips still missing.
  HaLo's descriptor set is `time`, `radio`, **`power`** (HALO-198),
  `spotting`, the activity `refList` controls, and `more`
  (`logging_controls.dart`); Notes is reachable only inside the "more"
  pane's form, and the key is captured per-QSO as station info (HALO-263)
  rather than from a chip. The control-set manager (add/remove/reorder) and
  the Spotter control are DONE.
- Commands still missing: **time/date set** (`+1h`, `NOW`, `TODAY`,
  `YESTERDAY`, explicit dates), **`CHAT`**, **`RTFM`**, **`EXCUSE`** (PoLo
  `225189b8`). Done since the last sweep: **power** (`5W`), **`SET`** with
  `SHOW`/`HIDE` (HALO-151), **operator change** (`OPER`, PoLo's `OP.`).
  (Note/todo/solar/weather, the SPOT/QRV/QRT/QSY family, band/mode/freq,
  `POSITION`, `WPM`/`KEYER` are done. `LANG`/`CROWDIN` and the debug
  commands are tracked under Developer tooling in §3.)
- **Segment creation** ✅ (HALO-108): `START`/`BREAK`/`STOP`(`END`) and
  `ROVERQTH` (operation-commands → `HaLoServices._markSegment`) write the
  same rows PoLo's commands do, with two deliberate differences: the
  override REPLACES rather than accumulates (contests.md §5.1.3), and a local
  edit of the operation's refs or location restamps the latest segment
  (`OperationsRepository.onLocalSave`) instead of waiting for the next
  BREAK to fix the previous one up. No UI yet for editing or deleting a
  segment.
- RST auto-expansion ✅ — closed by HALO-83 (per-mode configurable default,
  shown as a placeholder, shorthand completion).
- **Log events** 🟡: note/todo/solar/weather rows are stored, rendered and
  **edited in place** when tapped (`528c39eb`). Still missing: a todo
  done-toggle in the UI, and the "pending to-dos" warning on export
  (PoLo warns).
- HaLo-internal ⚠️: **fields-on-top** is the last setting still stored and
  shown in Settings but **not consumed by any view** — `dxFlags` left this
  list in `de4e6341`, joining leftie mode, bearing, report order and
  jump-after-RST.

### Station & operator model
- Multi-station ✅ and in places ahead: several station callsigns in one
  comma-separated `stationCall` (`Operation.stationCalls`, where PoLo splits
  `stationCall` + `stationCallPlusArray`), the operating position in
  `localData['multiIdentifier']` (`b83dbeb6`) written through one canonicalizer
  by both the details dialog and `POSITION`, appended to self-spots and
  exported as `APP_HAM2K_POSITION` — PoLo landed the same `/OP{n}` spotting in
  `bf0c090c` — and the operator stored **per position** in synced data
  (`operator1`, `operator2`, … — `operation_operator.dart`) where PoLo keeps
  one device-local `operatorCall`. PoLo's separate `isMultiStation` boolean is
  a deliberate divergence, not a gap: here a non-empty position *is* the flag.
- The Operation Details dialog's remaining half ✅ (HALO-279), warning about
  an unparseable callsign without refusing it, disabling the operator field
  under several station calls, and suggesting the operator's own call behind
  "Suggest Operator" — PoLo's `suggestDefaultOperator`.
  ("`/P`-style suffixes as first-class" left this list as a first-sweep
  artifact — it matches no code in PoLo.)
- **PoLo's QSO-migration prompts are answered by a different design** (HALO-510):
  the station call is a SEGMENT key here, so changing it rewrites that
  segment's contacts unasked, and contacts in earlier segments keep the call
  they were made under — something PoLo cannot express, having added the
  mid-operation call change before it had segments. The **operator** keeps the
  prompt, since an operator does change mid-segment; clearing one deliberately
  offers no restamp, an empty field being every intermediate state of typing
  one, and the `OPER` command restamps nothing.
- **Multi-profile actually in use** ⛔ (HaLo: profiles scaffolded, single
  profile active) — HALO-107. Showing which operator and position logged each
  QSO is HALO-439.

### Operations
- **Operation templates** ("use as template" + suggestions on create). ⛔
- **Operation undelete** ✅ — Show Deleted Operations (PoLo's
  `showDeletedOps`) lists them struck through and faded, as PoLo does, and
  the operation's Tools menu offers Undelete in place of Delete. PoLo's
  delete tombstones the operation's QSOs with the operation's own revision
  stamp, where HaLo's leaves them alone, so Undelete also restores the
  deleted QSOs carrying exactly that stamp and no others. Deliberately
  unlike PoLo, a deleted operation is read-only until undeleted: a save
  re-stamps it, which would strand those QSOs for good.
- **Operation badge** ✅ — HaLo's Operation Postcard (the Map tab's camera
  button, HALO-708) makes the picture PoLo's badge screen shows for a
  screenshot, as an image to save, share or copy: the Map tab's framing in
  portrait, landscape or square, any map style, the title and the contact
  count and span over it, and the popup open on the tab.
- Keep-device-awake while logging. ⛔ (no wakelock dependency at all)
- Op info stats ✅ — counts, rates (last 10/100), dupes, score summaries
  and the per-day/operation breakdown now match PoLo's info panel
  (`8855d622`).

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
- Deep links ✅ — **`/qso`** (multi-call `their.call=A,B`, `their.refs=`),
  **`/vfo`** and **`/operation`** (`our.refs=` → find-or-create-and-open,
  PoLo #235) all land, alongside the auth callbacks, **`/link_client`** and
  **`/install_extension`** (HALO-422) that came before them. A link's
  frequency is authoritative where a spot's is not, so `/qso` writes the VFO
  and skips Avoid Zero-Beating; `/operation` reuses an operation only on an
  exact activation-ref set match within 48 hours, as PoLo does.
  - Registered on macOS, iOS, Android and **Windows** (HALO-178 — schemes in
    the installer, plus single-instance forwarding, since Windows answers a
    scheme by launching a second copy rather than delivering to the running
    one). Remaining ⛔: **Linux registers no URL protocol** (HALO-121), so no
    deep link of any kind reaches the app there, `link_client` included.
  - HaLo also reaches the WSJT-X case from the other end: **HALO-306 listens
    for N1MM+ and WSJT-X broadcasts** and captures those QSOs directly.

### Sync
- Guided linking scenarios (HaLo: bare Combine/Replace banner — backlog). 🟡
- Linked-devices list. 🟡 The **connection-request approval UI is done**
  (HALO-9's "Confirm a device", by code or `/link_client` QR link, with a
  waiting-devices count); what's missing is the standing list of devices
  already on the account. (HaLo's separate Peer Devices panel is its own
  LAN/BLE peer sync, not LoFi's device roster.)
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

- **i18n**: PoLo ships 15 Crowdin locales (Italian bundled and Korean added
  since the last sweep) + tone variants (cw/qrp/qro); HaLo has en + es, with
  es brought back to full parity with en (HALO-421). The gap widens.
- Settings PoLo has: smart-keyboard toggles, comma **and period/slash**
  keys on numbers row (HaLo shows one contextual extra key). Keep Device
  Awake and Grid Precision are no longer gaps. (Haptics is NOT a gap — PoLo also
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
- Spot continent filter; segment-sliced exports; a **hunter/chaser export**;
  secondary-control **reorder** (PoLo's manager only shows/hides, order is
  fixed).
- **Peer device sync** over LAN and BLE (HALO-310/342) — paired devices
  share the log, GPS, the radio's VFO and contest serial numbers, with a
  Positions panel and remote screen sharing. PoLo syncs only through LoFi.
- **CW keying from CAT** — F1–F8 messages, a keyer area, `WPM`/`KEYER`
  (behind `EXP KEYER`) — and **voice keying** on the same keys in a Phone
  mode, playing and recording the radio's own voice memories (HALO-503) —
  with N1MM-style **Enter Sends Messages** (`ESM`, `RUN`, `SP`; behind
  `EXP ESM`; HALO-662).
- **Inbound QSO capture** from N1MM+ and WSJT-X broadcasts (HALO-306).
- **CWops CWT** contest, offered only around a session — PoLo has no CWT.
- **Extension distribution**: `.h2kext` bundles installed from a file, a
  drop or a link (HALO-422), a published SDK, and a rebuild-on-save dev loop.
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
3. ~~Deep links `/qso`, `/vfo`, `/operation`~~ — done, and ~~Windows scheme
   registration~~ with them (HALO-178). What is left is Linux (HALO-121),
   where no deep link reaches the app at all today.
4. ~~Segment-creation commands (`START`/`BREAK`/`STOP`)~~ — done (HALO-108).
5. Consume **fields-on-top**, the last dead logging setting — already
   stored, surfaced and published; only the view is missing. (Country flags
   is done.)
6. Remaining contests **M9 (GAPOTA)** and 13 Colonies (M12); WAB. (M7, M8
   and M10 are done.)
7. Per-export-type template overrides + Wavelog + File Stash (+ user-facing
   QSON). REG1TEST/EDI is done.
8. ~~Multi-station / operator model~~ — done (HALO-370, HALO-279). What is
   left of §2's "Station & operator model" is profiles (HALO-107).
9. Long tail (HamQTH/QRZCALL.EU, todo done-toggle and the pending-to-dos
   export warning, global Spots screen, operation templates/badge,
   keep-awake, credits/community links, dev-mode database surgery, polish).
