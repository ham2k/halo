# Phase 4 — POTA and the declarative UI catalog

The last unproven pillar of the architecture (DESIGN.md §5): plugins
contributing UI as data, rendered by native widgets from a core catalog.
POTA is the archetype — the richest activity in app-polo — ported as a
vertical slice touching every remaining seam.

## What's here

### SDK / kernel

- **Ref and activity hook types**: `Ref` (QSON refs, same convention as
  app-polo: `pota` hunting, `potaActivation` activating), `RefHandlerHook`
  (`validateRef`, `decorateRef`), `ActivityHook` (`loggingControls`,
  `operationControls` returning `LoggingControlDescriptor`s), and
  `AdifFieldsHook`.
- **In-runtime hook composition**: `kernel.invokeLocal` / SDK `hooks.invokeAll`
  lets one plugin call other plugins' hooks without crossing the bridge. The
  ADIF exporter uses it to collect per-QSO program fields from activity
  plugins — plugin composition stays inside the JS runtime.

### POTA plugin (`plugins/activities/pota`)

One plugin, five hooks (mirroring app-polo's extension shape):
`ref:pota` + `ref:potaActivation` (validation regex + park decoration via
the POTA API with an in-runtime cache), `activity` (declarative refList
controls for logging panel and operation settings), `adifFields`
(SIG/SIG_INFO/POTA_REF and MY_SIG/MY_SIG_INFO/MY_POTA_REF), and the `spots`
source (absorbed from the former spots-only plugin).

### UI catalog v0 (`polo_widgets`)

- **`RefChipsInput`** — the first catalog component (`input.kind: 'refList'`):
  chip list + entry field, pattern pre-validation from the descriptor,
  duplicate rejection, async decoration via a callback into the plugin
  runtime that updates the chip when it lands. Never blocks on the plugin.
- **`LoggingPanel`** renders `activityControls` descriptors (refList kind),
  folds entered refs into the logged QSO's `refs`, and clears them on wipe.
- **`QsoList`** shows QSO refs in the row.

### App

- Operation screen loads logging controls from activity hooks when opened.
- "Activities" app-bar action opens a dialog built from `operationControls`
  descriptors; saved refs land in `operation.data['refs']` (synced data).
- Exports now carry POTA fields end to end: log a QSO with a park ref in an
  activation, export, and the ADIF has both sides' program fields.

## What this proves

A plugin can put a control on the hottest screen in the app without owning
any pixels: the descriptor crosses the bridge once per operation open, all
rendering is native, and plugin involvement (validation feedback, park-name
decoration) is async behavior on core-owned widgets. SOTA/WWFF/GMA are now
mostly copy work; contests need one more catalog component (an exchange
`textField`).

## Deferred

- Offline park dataset via a host-managed `lookups` store (decoration
  currently hits the POTA API per park, with an in-runtime cache).
- Activator-mode logging control variants, "nearby parks" suggestions
  (needs location host API), spotting hooks, scoring.
- Catalog components beyond `refList`: `textField` (contest exchanges),
  `select`, `form` sections.
