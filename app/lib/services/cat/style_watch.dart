// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The FYI area's Run / S&P pill (docs/design/logging-fields.md § The FYI
// area), one per set.

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart' show Color;
import 'package:halo_i18n/halo_i18n.dart';
import 'package:halo_widgets/halo_widgets.dart' show MdiIcons;

import '../fyi_service.dart';
import '../settings_service.dart';
import 'cat_service.dart';
import 'operating_style.dart';

/// Says "Run" in each running set's FYI area — the style that is not the
/// default, and otherwise shown nowhere with ESM off — and, with
/// [SettingsService.alwaysShowStyle], "S&P" in the others. A high
/// operational message, ahead of the keyer line, on a pill of its own
/// colour: a state, not a problem.
/// A tap switches the style, so it is never dismissed: the pill that stays
/// is the other style's, or none.
class StyleWatch {
  StyleWatch({required this.cat, required this.fyi, required this.settings});

  final CatService cat;
  final FyiService fyi;
  final SettingsService settings;

  /// The pills': the alert's white reads on both, on either theme.
  static const runColor = Color(0xFF4F8559);
  static const spColor = Color(0xFF7787A3);

  late final Listenable _changes = Listenable.merge([cat.styleChanges, settings]);

  void start() {
    _changes.addListener(_check);
    _check();
  }

  void dispose() => _changes.removeListener(_check);

  static String keyFor(String radio) => 'style:$radio';

  void _check() {
    for (final radio in ['A', 'B']) {
      final run = cat.styleOf(radio) == OperatingStyle.run;
      if (!cat.styledRadios.contains(radio) || !(run || settings.alwaysShowStyle)) {
        fyi.clear(keyFor(radio));
        continue;
      }
      fyi.post(
        FyiMessage(
          key: keyFor(radio),
          category: FyiCategory.operational,
          priority: FyiPriority.high,
          icon: run ? MdiIcons.run : MdiIcons.magnify,
          text: run ? t.fyi.run : t.fyi.sp,
          backgroundColor: run ? runColor : spColor,
          radio: radio,
          dismissible: false,
          onTap: () => cat.toggleStyle(radio),
        ),
      );
    }
  }
}
