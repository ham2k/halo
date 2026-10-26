// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// SO2R — Single Operator, Two Radios (docs/design/logging-fields.md § SO2R):
// two `LoggingControls`, one per radio, stacked under ONE strip. Each set is
// a whole panel of its own — draft, lookups, info area, wipe and log buttons
// — following its own VFO. What they share goes through [So2rLink]: set A
// draws the strip, with set B's Radio control in it as the `radioB` pill, and
// the focus ladder's rung past set A's fields is set B's.

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:halo_core/halo_core.dart';
import 'package:halo_i18n/halo_i18n.dart';

import 'logging_controls_radio.dart';
import 'secondary_control_row.dart';
import 'semantic_id.dart';
import 'spacing.dart';
import 'theme.dart';

/// Which of the two sets a `LoggingControls` is, and the link to the other.
class So2rSet {
  const So2rSet({required this.radio, required this.link, this.running = false, this.onToggleRunning, this.transmitting = false});

  /// `A` or `B` — the letter the set's pill shows. Set A follows `vfoA`, set
  /// B `vfoB`, through whatever VFO store the host wires each one to.
  final String radio;

  final So2rLink link;

  /// Whether this set's radio is running rather than searching and pouncing
  /// — the host's state, shown on the set's pill.
  final bool running;

  /// Flips [running]; a tap on the pill's Run / S&P line.
  final VoidCallback? onToggleRunning;

  /// Whether this set's radio is on the air — its pill and rule turn the
  /// theme's error red while it is.
  final bool transmitting;

  /// Set A draws the shared strip; set B draws none.
  bool get ownsStrip => radio == 'A';

  /// The strip's key for this set's Radio control.
  String get radioControlKey => ownsStrip ? 'radio' : 'radioB';
}

/// What one set offers the other while it is mounted.
typedef So2rSetHandle = ({
  /// The main field the set's keyboard was last in, or its callsign field.
  VoidCallback focusLastPrimaryField,

  /// Opens one of the strip's controls — only set A has a strip to open.
  void Function(String key) openControl,
});

/// The two sets' meeting point. Made by the host, handed to both sets.
///
/// A notifier so set A repaints when set B's Radio control changes: the pill
/// it draws for it reads that control's band, frequency and mode.
class So2rLink extends ChangeNotifier {
  final _sets = <String, So2rSetHandle>{};

  /// The set the keyboard was last in — `A` until either set has had it.
  /// The one whose default focus is reclaimed, and the host's answer to
  /// "which radio is the operator working".
  String get active => _active.value;

  /// [active], for a host to listen to. The link itself also fires for every
  /// edit to set B's Radio control, some of them made while the sets are
  /// being built, so a host above the sets that rebuilds on the link would
  /// be marked dirty mid-build.
  ValueListenable<String> get activeSet => _active;
  final _active = ValueNotifier('A');

  /// Wired by each set as the keyboard enters it — not meant for callers.
  void noteActive(String radio) {
    if (_active.value == radio) return;
    _active.value = radio;
    notifyListeners();
  }

  /// Set B's Radio control, while set B is mounted.
  RadioControlModel? get radioB => _radioB;
  RadioControlModel? _radioB;

  /// Wired by each set on mount — not meant for callers. Set B passes its
  /// Radio control along for set A's strip.
  void attach(String radio, So2rSetHandle handle, {RadioControlModel? radioModel}) {
    _sets[radio] = handle;
    if (radio == 'B' && radioModel != null && !identical(radioModel, _radioB)) {
      _radioB?.removeListener(notifyListeners);
      _radioB = radioModel..addListener(notifyListeners);
      _notifyAfterFrame();
    }
  }

  /// Wired by each set on unmount — not meant for callers.
  void detach(String radio, So2rSetHandle handle) {
    if (!identical(_sets[radio], handle)) return;
    _sets.remove(radio);
    if (radio == 'B') {
      _radioB?.removeListener(notifyListeners);
      _radioB = null;
      _notifyAfterFrame();
    }
  }

  /// Sets attach and detach while the tree is being built or torn down, and a
  /// listener that rebuilds then — set A, or a host above both sets — would be
  /// marked dirty mid-build, so the news waits for the frame to end.
  void _notifyAfterFrame() => WidgetsBinding.instance.addPostFrameCallback((_) {
    if (!_disposed) notifyListeners();
  });

  bool _disposed = false;

  /// Puts the keyboard in [radio]'s set; false when that set is not mounted.
  bool focusSet(String radio) {
    final handle = _sets[radio];
    if (handle == null) return false;
    handle.focusLastPrimaryField();
    return true;
  }

  /// Opens [radio]'s Radio control in the shared strip.
  void openRadio(String radio) => _sets['A']?.openControl(radio == 'A' ? 'radio' : 'radioB');

  @override
  void dispose() {
    _disposed = true;
    _radioB?.removeListener(notifyListeners);
    _active.dispose();
    super.dispose();
  }
}

/// A Radio control's pill in SO2R's strip, named for its radio — the two
/// would otherwise read alike but for the numbers.
SecondaryControlSpec so2rRadioSpec(String radio, SecondaryControlSpec spec) => spec.copyWith(
  key: radio == 'A' ? 'radio' : 'radioB',
  summary: '$radio ${spec.summary}',
  summaryParts: spec.summaryParts == null ? null : [(text: '$radio ', color: null), ...spec.summaryParts!],
);

/// The contacts an SO2R set's stats count: its own radio's. One with no radio
/// recorded counts for A, the set that edits it. [qsos] unchanged outside SO2R.
List<Qso> so2rQsos(So2rSet? so2r, List<Qso> qsos) => so2r == null
    ? qsos
    : [
        for (final q in qsos)
          if ((q.ourRadio == 'B' ? 'B' : 'A') == so2r.radio) q,
      ];

/// Each radio's colour — violet for A, gold for B: clear of the theme's
/// teal, tan and editing blue, and of the green and red that mean good and
/// bad, and still apart for an operator who cannot tell red from green. [ink]
/// is the hue as text on the panel, for the set without the keyboard.
({Color fill, Color onFill, Color ink}) _colorsFor(So2rSet so2r, ThemeData theme) {
  final colors = theme.colorScheme;
  // On the air, whichever set has the keyboard: red is what says so.
  if (so2r.transmitting) return (fill: colors.error, onFill: colors.onError, ink: colors.error);
  return _radioColors(so2r.radio, theme.brightness);
}

({Color fill, Color onFill, Color ink}) _radioColors(String radio, Brightness brightness) => switch ((radio, brightness)) {
  ('A', Brightness.light) => (fill: const Color(0xFF6B4BC8), onFill: Colors.white, ink: const Color(0xFF5A3DB0)),
  ('A', Brightness.dark) => (fill: const Color(0xFFA08CF0), onFill: const Color(0xFF24124F), ink: const Color(0xFFB9A9F5)),
  (_, Brightness.light) => (fill: const Color(0xFFFF9A00), onFill: const Color(0xFF3A2A00), ink: const Color(0xFF945200)),
  (_, Brightness.dark) => (fill: const Color(0xFFFFB000), onFill: const Color(0xFF3A2A00), ink: const Color(0xFFFFBF1F)),
};

/// The pill's three lines, top to bottom: the radio's letter, large, then its
/// band, then Run or S&P.
List<(String, TextStyle)> _pillLines(So2rSet so2r, ThemeData theme, String? band) {
  final radio = _colorsFor(so2r, theme);
  final color = so2r.link.active == so2r.radio || so2r.transmitting ? radio.onFill : radio.ink;
  final strings = t.settings.radio.enterSends;
  return [
    (so2r.radio, TextStyle(fontSize: 20, height: 1.1, fontWeight: FontWeight.w800, color: color)),
    (band ?? '—', TextStyle(fontSize: 12, height: 1.2, fontWeight: FontWeight.w700, color: color)),
    (so2r.running ? strings.run : strings.sp, TextStyle(fontSize: 11, height: 1.2, fontWeight: FontWeight.w500, color: color)),
  ];
}

double _pillWidth(BuildContext context, So2rSet so2r, ThemeData theme, String? band) =>
    _pillLines(so2r, theme, band).map((line) => textWidth(context, line.$1, line.$2)).reduce((a, b) => a > b ? a : b) + Space.sm * 2;

/// The rule along an SO2R set's top edge, in the pill's colour.
const _ruleHeight = 4.0;

/// How far the active set's background runs past its buttons and fields.
const _washInset = 6.0;

/// An SO2R set's info area and entry row ([children], laid out as the panel
/// lays them out outside SO2R), framed for its radio. The set takes 90% of
/// the panel, set A's against the leading edge and set B's against the
/// trailing one, so the two read as two radios at a glance. Its pill runs
/// the full height of the info area and the fields, with its radio, band and
/// Run or S&P against the entry row, and a rule runs from the pill's top
/// across to the far edge of the wipe and log buttons. The pill is filled in
/// the accent while the keyboard is in this set; a tap on its Run / S&P line
/// flips it, and anywhere else opens the radio's control in the strip.
/// Mirrored when [entryRowAbove]. [children] unchanged outside SO2R.
List<Widget> so2rFramed(BuildContext context, So2rSet? so2r, ThemeData theme, String? band, {required bool entryRowAbove, required List<Widget> children}) {
  if (so2r == null) return children;
  final active = so2r.link.active == so2r.radio;
  final radio = _colorsFor(so2r, theme);
  // The other set keeps its radio's hue as a wash, so the two radios read
  // apart whichever has the keyboard.
  final color = active || so2r.transmitting ? radio.fill : radio.fill.withValues(alpha: 0.22);
  final pillWidth = _pillWidth(context, so2r, theme, band);
  final [letter, bandLine, mode] = [
    for (final (text, style) in _pillLines(so2r, theme, band)) Text(text, textAlign: TextAlign.center, maxLines: 1, softWrap: false, style: style),
  ];
  // Square on the side the rule and the background leave it, so the three
  // read as one piece.
  const corner = Radius.circular(8);
  const shape = RoundedRectangleBorder(borderRadius: BorderRadiusDirectional.horizontal(start: corner));
  final pill = semanticId(
    'so2r.pill.${so2r.radio}',
    Material(
      color: color,
      shape: shape,
      child: InkWell(
        customBorder: shape,
        onTap: () => so2r.link.openRadio(so2r.radio),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: Space.xs),
          child: Column(
            mainAxisAlignment: entryRowAbove ? MainAxisAlignment.start : MainAxisAlignment.end,
            children: [
              letter,
              bandLine,
              semanticId(
                'so2r.mode.${so2r.radio}',
                InkWell(
                  onTap: so2r.onToggleRunning,
                  child: SizedBox(width: double.infinity, child: mode),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
  const ruleGap = _ruleHeight + Space.sm;
  return [
    Align(
      alignment: so2r.ownsStrip ? AlignmentDirectional.centerStart : AlignmentDirectional.centerEnd,
      child: FractionallySizedBox(
        widthFactor: 0.9,
        // Clip.none: the exchange suggestions float over the info area and
        // may run past this frame's edge.
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            // The set with the keyboard is washed in its radio's colour,
            // between the pill and the far edge of its buttons.
            if (active)
              PositionedDirectional(
                start: pillWidth,
                end: 0,
                top: 0,
                bottom: 0,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: _radioColors(so2r.radio, theme.brightness).fill.withValues(alpha: 0.14),
                    borderRadius: entryRowAbove
                        ? const BorderRadiusDirectional.only(topEnd: Radius.circular(8))
                        : const BorderRadiusDirectional.only(bottomEnd: Radius.circular(8)),
                  ),
                ),
              ),
            Padding(
              // The background reaches a little past the buttons and the
              // fields, on every set so the layout holds as the keyboard moves.
              padding: EdgeInsetsDirectional.only(
                start: pillWidth + Space.sm,
                end: _washInset,
                top: entryRowAbove ? _washInset : ruleGap,
                bottom: entryRowAbove ? ruleGap : _washInset,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                verticalDirection: entryRowAbove ? VerticalDirection.up : VerticalDirection.down,
                children: children,
              ),
            ),
            // From the pill's edge, not under it: where the two are a
            // translucent wash, an overlap paints twice and shows as a seam.
            PositionedDirectional(
              start: pillWidth,
              end: 0,
              top: entryRowAbove ? null : 0,
              bottom: entryRowAbove ? 0 : null,
              height: _ruleHeight,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: const BorderRadiusDirectional.horizontal(end: Radius.circular(_ruleHeight / 2)),
                ),
              ),
            ),
            PositionedDirectional(start: 0, top: 0, bottom: 0, width: pillWidth, child: pill),
          ],
        ),
      ),
    ),
  ];
}
