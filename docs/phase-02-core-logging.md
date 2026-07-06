# Phase 2 — Core logging loop

Step 2 of the sequencing plan in [DESIGN.md](../DESIGN.md) §10: operations,
QSO entry, QSO list, SQLite — all pure Dart, no extensions involved. The goal is
proving the storage shape and the keyboard/entry ergonomics before anything
else is layered on.

## What's here

- **`packages/polo_core`** — pure Dart (no Flutter dependency):
  - `src/db/database.dart` — drift schema following app-polo's proven shape:
    JSON `data` blob as source of truth + derived indexed columns,
    `deleted`/`synced` flags for soft deletes and dirty-flag sync.
  - `src/models/models.dart` — `Operation`/`Qso` as thin typed views over
    QSON maps. The JSON stays canonical; it is what will sync and what
    extensions will see.
  - `src/repo/repositories.dart` — the only writers. Every write derives
    indexed columns, marks rows dirty, and refreshes operation counters in a
    transaction. Reads are reactive drift streams.
  - `src/ham/radio.dart` — hot-path domain utilities only (band plan, freq
    parse/format, RST defaults, callsign plausibility). Full domain knowledge
    stays in the TS extension runtime per DESIGN.md §2.
- **`packages/polo_widgets`** — UI modules (DESIGN.md §7: modules, not
  screens):
  - `LoggingPanel` — QSO entry. Enter logs from anywhere in the panel, Esc
    wipes, focus always returns to the callsign field, RST defaults follow
    mode, live band readout from frequency, DUPE chip on same
    call+band+mode.
  - `QsoList` — reactive list, newest at the bottom edge next to the logging
    panel (contest-logger style), soft delete via row menu.
- **`app/`** — thin shell: operations list (create/open/delete) →
  operation screen with the QSO list and docked logging panel; ≥900px wide
  adds an info side panel (first step toward module docking). The spike
  screen from phase 1 stays reachable via the flask icon.

## Verifying

```sh
cd packages/polo_core && dart test        # schema, repos, radio utils
cd packages/polo_widgets && flutter test  # logging keyboard flows
cd app && flutter run -d macos
```

## Decisions made here

- **drift + JSON blob schema** as designed; `drift_flutter` provides the
  executor in the app, `NativeDatabase.memory()` in tests.
- **No state-management framework yet.** Constructor injection + streams;
  the database is the single source of truth. Riverpod (or similar) gets
  introduced when cross-cutting state earns it, not before.
- **Frequency/mode live in the logging panel** for now; they'll move to
  operation `localData` (device-local, unsynced) when the VFO concept
  arrives.

## Deferred to next increments

- ADIF import/export (next).
- Operation refs/activities (needs the extension runtime wired into logging).
- Lookup enrichment of the entry line (extension `lookup` hooks — the bridge
  from spike 01 is ready for this).
- Scoring cache column is in the schema but unused.
