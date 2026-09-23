# Meter calibration tables

What a radio's raw meter readings mean, in the units an operator uses. One
file per model, read by `../meter_calibration.dart`.

They live here, as JSON, rather than as Dart literals inside a driver: they
are data, they are edited far more often than the code that reads them, and a
table is easier to check against a manual or a bench sheet when it is a list
of numbers rather than a Dart literal wearing punctuation.

## Why a table is needed at all

Every CAT protocol here answers its meters with a raw scale — 0-255 on both
Yaesu and Icom — and **none of them says what the number means**. Yaesu's CAT
manuals give the meter numbering and the range and stop there. So without a
table a reading is uninterpretable, and a radio with no file reports no
meters at all rather than a guess: an invented SWR would be measured against
the threshold the operator is warned at.

## Adding a radio

1. Drop a `.json` file in the manufacturer's folder, named for the model.
2. Point the catalogue entry at it: `meterInfo: 'yaesu/ftdx10'` in the
   variant's `overrides` (`equipment_models_<protocol family>.dart`), without the `.json`.

To say a radio has **no** meters — an IC-706MKIIG, whose CI-V predates the
TX meter sub-commands — name the empty string: `meterInfo: ''`. That is
different from naming nothing, which inherits whatever default its driver
carries, and the difference is visible: an inherited table reserves slots on
the panel that can never fill.

A **new manufacturer folder** also needs a line in `app/pubspec.yaml` —
Flutter's asset directories are not recursive. A new radio in a folder that
is already declared needs nothing.

## A file may ship before its radio does

A table with no catalogue entry pointing at it is **fine, and deliberate**.
The data is worth having the moment someone finds it; the entry that makes a
radio pickable is a claim that the app can drive that radio, and that waits
for an operator with one in front of them to confirm it. So do not "tidy up"
by wiring a loose file to a new entry — the file is not the missing half, the
confirmation is.

Nothing is spent on an unused file beyond its few kilobytes: it is parsed at
startup and then simply never asked for.

## Format

```jsonc
{
  "manufacturer": "Yaesu",
  "model": "FTdx10",
  "meterCalibration": {
    "_comments": "where these numbers came from",  // kept, and worth filling in
    "swr":         [ { "value": 52, "ratio": 1.5 } ],
    "power":       [ { "value": 147, "watts": 50.0 } ],
    "alc":         [ { "value": 64, "level": 1.0 } ],   // 0.0-1.0 of the ALC zone
    "voltage":     [ { "value": 192, "volts": 13.8 } ],
    "drain":       [ { "value": 255, "amperes": 25.5 } ],
    "strength":    [ { "value": 130, "db": 0, "tick": "S9" } ],
    "compression": [ { "value": 60, "db": 5.0 } ]
  }
}
```

- `value` is what the radio answers; the other key is what it means, and its
  name IS the unit. A row using the wrong key for its table is refused rather
  than read in whatever unit it offered.
- Rows may be in any order — they are sorted on load.
- Any table may be omitted. A meter with no table is not shown.
- Between two rows the scale is interpolated linearly. **Outside the ends it
  is clamped, never extrapolated** — a table states the range someone
  actually measured, and running the last slope out to 255 invents readings
  at exactly the end an SWR curve is least linear.
- `tick` on a strength row is a label for people reading the file. Nothing
  reads it.
- A key beginning with `_` is a note for whoever opens the file, never a
  table. `_comments` is the one the loader does read, as the table's stated
  source — the first thing anyone asks of a calibration, and the thing that
  decides how far to trust a reading that disagrees with the radio's own
  meter.

## A caution worth keeping

On Yaesu these meters are aligned **per radio, per band**, in service mode
(the technical supplements' `100W MTR 1.8` and its siblings), and a
commercial CAT meter product for the FT-891 shows the raw values with no
scale at all for exactly that reason. A table here is a good default for the
model, not a calibration of anyone's particular radio.
