# PoLo → HaLo Feature Parity

A working inventory of what Ham2K Portable Logger (app-polo, RN) has that
HaLo doesn't yet, from a full side-by-side sweep of both codebases
(2026-07-24, PoLo 26.7.2). Update as gaps close; this is a tracking
document, not a roadmap — see DESIGN.md §10 for sequencing intent.

Legend: ⛔ missing entirely · 🟡 partial · 🧭 prerequisite work needed first

## 1. Structural gaps (biggest leverage)

| Gap | PoLo has | HaLo status |
| --- | --- | --- |
| **ADIF import** | Per-operation "Add QSOs from ADIF" + global "Import History from ADIF" feeding worked-before detection | ⛔ no import path at all (DESIGN §10 step 2 goal) |
| **Contest support** | ~12 contest extensions (NAQP, QSO Parties, State Parks, ARRL DX/VHF, CQ WW/WPX, IARU HF, RSGB/R1 VHF, simple-contest) + Field Day + Winter Field Day | ⛔ none. 🧭 prerequisites: exchange-field control in the UI catalog (only `refList` exists), serial handling, contest scoring/mults, Cabrillo |
| **Export breadth** | 29 ADIF variants, 11 Cabrillo, QSON, REG1TEST; filename Handlebars templates; "ignore lookup data" / "include private data" toggles; Wavelog upload | 🟡 single ADIF export, no options, no Cabrillo/QSON/REG1TEST, no logbook upload |
| **Activity catalog** | ~20 location-based programs | 🟡 POTA + SOTA only. Missing: WWFF, WWBOTA, GMA, SiOTA, ZLOTA, LLOTA, MOTA, TOTA, WCA, BLHA, ELA, PGA, 13 Colonies, Satellites, WAB squares, **Custom Activity** (user-defined refs — the escape hatch; port first) |
| **Lookup providers** | QRZ, HamQTH, QRZCALL.EU, HamDB, **Call History** (worked-before from own log), **Spot History** | 🟡 QRZ + HamDB + call-notes. Call History matters most. Also: no lookup-result caching (re-queries every pass; backlog) |

## 2. Gaps within existing surfaces

### Logging
- Secondary controls: **Notes**, **TxPower**, **CW Key** chips (HaLo has Time/Radio/Spotting/activity only).
- Commands: power (`5W`), time/date set commands, `SET` (settings), operator change, `RTFM`, `LANG`, `EXCUSE`.
- RST auto-expansion conveniences by mode (🟡 verify coverage).
- HaLo-internal ⚠️: several logging settings are **stored and shown in
  Settings but not consumed by the logging UI yet** (leftie mode,
  fields-on-top, country flags, bearing, report order, jump-after-RST —
  see the note in `core_settings_groups.dart`). Worse than missing: looks
  like it works.

### Station & operator model
- Multiple station calls, `/P`-style suffixes as first-class, club /
  multi-operator handling with QSO-migration prompts, "suggest default
  operator". HaLo: single profile (multi-profile scaffolded, unused).

### Operations
- **Operation templates** ("use as template" + suggestions on create). ⛔
- **Operation undelete** UI (HaLo soft-deletes + keeps backups; no restore surface). ⛔
- Shareable **operation badge** screen (social screenshot). ⛔
- Keep-device-awake while logging. ⛔

### Spots
- **Global Spots screen** reachable from Home (outside any operation). ⛔
- ParksnPeaks spot source; Discord spot posting. ⛔
- POTA **"Confirm Spots"** QSO-confirmation flow. ⛔

### Integration
- Deep links `/qso` and `/vfo` — external apps pushing logged QSOs and VFO
  state (the de-facto WSJT-X bridge). HaLo handles only auth callbacks and
  `/link_client`. ⛔

### Sync
- Onboarding "existing account" sign-in branch; guided linking scenarios
  (HaLo: bare Combine/Replace banner — backlog). 🟡
- Linked-devices list + connection-request approval UI. 🟡 (HaLo links via
  QR/email but has no device management view.)

### Scoring
- US-states and Canadian-provinces handlers (deferred in HaLo; also blocks
  activity/contest mults). 🟡

## 3. Platform & polish

- **i18n**: PoLo ships ~14 Crowdin locales + tone variants (cw/qrp/qro);
  HaLo has en + es. (HaLo's per-locale JSON catalogs are ready to absorb
  more.)
- Settings PoLo has: keep-awake, 8- vs 6-digit grid precision,
  smart-keyboard toggles, comma key on numbers row, haptics on general
  pressables (HaLo: numbers-row vibrate only).

## 4. Where HaLo is ahead (not gaps — context)

Desktop platforms (macOS/Windows/Linux/web) with Sparkle/WinSparkle
self-update + Shorebird patches; dock layouts and keyboard-first logging;
SOLAR/WEATHER annotations; sandboxed extension runtime with static
manifests and per-locale string catalogs; consent-gated telemetry with a
vendor-free public app.

## 5. Suggested closing order

1. ADIF import (per-operation, then history import for worked-before).
2. Call History lookup (worked-before pills in call info).
3. Export options + Cabrillo.
4. Custom Activity, then WWFF/GMA (each additional program port gets
   cheaper once the pattern repeats).
5. Exchange-field UI control + simple-contest.
6. Multi-station / operator model.
7. Long tail (remaining programs, contests, providers, polish).
