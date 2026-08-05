// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'density.dart';

import 'spacing.dart';

/// A row of digit keys the logging panel floats above the on-screen keyboard
/// on mobile, so digits — and one contextual "/" or "." — are a
/// single tap away while a callsign/RST/frequency field has focus. Ported
/// from app-polo's `NumberKeys`.
///
/// The keys deliberately never take focus (`canRequestFocus: false`): tapping
/// one must leave the text field focused and its keyboard up, since the whole
/// point is to type into that field. The host ([LoggingControls]) decides
/// when to show the bar and inserts each tapped character at the field's
/// cursor.
///
/// Sizes are plain logical pixels — the whole UI is scaled once at the root
/// by `UiScale` (docs/design/ui-scaling.md), so nothing here multiplies by
/// the font scale.
class NumberKeys extends StatelessWidget {
  /// Fixed at every density: these are tap targets on a phone, already at
  /// Apple's 44pt minimum. Only the padding around them gives.
  static const double _keyHeight = 44;

  /// The row's laid-out height. Public because whatever draws the bottom of the
  /// window has to budget the space this will take BEFORE building it — see
  /// `StatusBarOverlay`, which divides what is left between the notice stack
  /// and the status footer.
  static double heightOf(BuildContext context) => heightFor(LayoutDensity.metricsOf(context));

  /// [heightOf] without a context — for the arithmetic that budgets the
  /// bottom of the window, which is checked across a matrix of densities,
  /// devices and keyboard insets rather than by pumping a widget.
  static double heightFor(LayoutMetrics metrics) => _keyHeight + metrics.numbersRowPaddingV * 2;

  /// Fired with the tapped character: '0'–'9', or [extraKey].
  final ValueChanged<String> onKey;

  /// The contextual extra key shown after the digits — "/" while composing a
  /// callsign, "." in numeric fields — or null to omit it.
  final String? extraKey;

  /// Whether a key press gives haptic feedback.
  final bool vibrate;

  /// Bar fill and key color, passed in so the bar matches the logging panel's
  /// current accent (tertiary while composing, secondary while editing).
  final Color backgroundColor;
  final Color foregroundColor;

  const NumberKeys({
    super.key,
    required this.onKey,
    required this.backgroundColor,
    required this.foregroundColor,
    this.extraKey,
    this.vibrate = true,
  });

  void _handle(String key) {
    // app-polo buzzes on press; HapticFeedback is the built-in equivalent, no
    // extra plugin. Guarded by the setting so it's easy to turn off.
    if (vibrate) HapticFeedback.mediumImpact();
    onKey(key);
  }

  @override
  Widget build(BuildContext context) {
    final keys = <String>[
      '1', '2', '3', '4', '5', '6', '7', '8', '9', '0',
      ?extraKey,
    ];
    return Material(
      color: backgroundColor,
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: Space.xs,
          vertical: LayoutDensity.metricsOf(context).numbersRowPaddingV,
        ),
        child: Row(
          children: [
            for (final key in keys)
              Expanded(
                child: InkWell(
                  // Never steal focus — see the class doc comment.
                  canRequestFocus: false,
                  onTap: () => _handle(key),
                  child: SizedBox(
                    height: _keyHeight,
                    child: Center(
                      child: Text(
                        key,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: foregroundColor,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
