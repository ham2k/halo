# Phase 5 — The secondary control row

Ported from app-polo's `SecondaryExchangePanel`: a horizontal strip of chips
above the call/RST row, one per control — built-in (**Time**, **Radio**) or
extension-contributed (POTA's park reference, and any future activity's
controls). Each chip shows a compact summary of the control's current value;
tapping it expands the actual editable fields above the row, and tapping
again (or selecting a different chip) collapses it. Only one control is
expanded at a time.

## Why not just leave everything always-visible

Phase 2–4 had frequency/band/mode and POTA's ref field permanently visible in
the panel's top strip. That doesn't scale: app-polo hit exactly this wall as
more activities registered logging controls, which is why it moved to the
chip-row-plus-expansion pattern in the first place. Adopting it now, while
there's still only one extension control, avoids having to redo the panel
layout later when SOTA/WWFF/contests each want their own control.

## What's here

- **`packages/halo_widgets/lib/src/secondary_control_row.dart`** —
  `SecondaryControlRow` (dumb: renders chips + the selected control's
  expanded widget) and `SecondaryControlSpec` (icon, summary, `hasValue`
  badge flag, `expandedBuilder`). Deliberately origin-agnostic — a spec
  doesn't know or care whether it came from a built-in Dart widget or an
  extension descriptor.
- **`LoggingPanel`** now builds three kinds of specs:
  - **Time** — summary is a live-ticking `"17:06:49z"` clock while nothing
    overrides it (a `Timer.periodic` that only runs while actually needed —
    not while a manual time or an existing QSO's own time is showing), or a
    static `"14:32z"` once one is. Expands to UTC time/date fields; the
    "Now" reset button only appears once a manual override is actually set
    **and** we're not editing an existing QSO — there's no "automatic" to
    reset a historical entry back to. Backed by `_manualStartAtMillis`
    (passed through to `QsosRepository.add` when set, letting the
    repository default to insert-time "now" otherwise) and the new
    `LoggingPanel.editingQso` parameter — unused by any caller yet (there's
    no tap-to-edit on QsoList rows), but the Time control's display/seeding/
    Now-button logic already branches on it correctly via a single
    `_effectiveStartAtMillis` getter (`manual override ?? editingQso's
    recorded time ?? null-meaning-live`), so wiring up real editing later
    is additive, not a rewrite. Resets on wipe.
  - **Radio** — summary is `"<freq> • <mode>"` or `"<band> • <mode>"` or
    `"Band??? • <mode>"` (matching app-polo's exact fallback copy); expands
    to the frequency field, band readout, and mode dropdown that used to be
    permanently visible. Command shortcuts (`14285 `, `20m `, `cw `) still
    work while this is collapsed — they mutate the same underlying
    `_freqController`/`_manualBand`/`_mode` state the expanded fields edit —
    and a successful command auto-selects Radio so the result is visible
    without a second tap.
  - **Extension controls** — one per `activityControls` entry with
    `input.kind == 'refList'`, rendered via the existing `RefChipsInput`
    catalog component. `hasValue` reflects whether `_controlRefs[key]` is
    non-empty, giving a visual "already set" indicator on the collapsed
    chip. Icon comes from a small `icon name → IconData` map (`'pota'` →
    `Icons.park_outlined`, default `Icons.extension_outlined`) — extension
    icons cross the bridge as strings, not Flutter `IconData`.
- The **DUPE indicator** moved from the old inline `Wrap` to
  `SecondaryControlRow`'s `trailing` slot — it's a status flag, not a
  control, so it doesn't participate in selection.

## Testing notes

- Chips are found by icon in tests (`find.byIcon(Icons.radio)`, etc.), not by
  label text, since Radio's and extension controls' labels are dynamic
  summaries. Tap the `ChoiceChip` ancestor of the icon, not the icon glyph
  itself — its tight bounding box can sit outside the actual hit-test area
  and trips `tester.tap()`'s hit-test warning even though the tap still
  (usually) lands.
- A command's auto-select-Radio behavior meant the existing
  `call-field commands` test needed **no changes** — every assertion that
  reads the Freq field runs right after a successful command, by which point
  Radio is already expanded.
- Tests that read the call/POTA fields directly *do* need an explicit
  `openControl` tap first now that those fields are conditionally rendered.

## Deferred

- No per-user visibility settings (app-polo's "which optional controls show"
  configuration screen) — every control passed in just shows. Not needed
  yet with only one extension control in play; straightforward to add later
  without changing `SecondaryControlRow`'s contract.
- No drag-reordering of chips.
- Only `refList` is wired as an extension control kind; a contest
  exchange's `textField` control will need a new catalog component when
  contests land, same as `refList` did for POTA.
