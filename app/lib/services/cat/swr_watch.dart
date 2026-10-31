// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The FYI area's SWR message (docs/design/logging-fields.md § The FYI area),
// one per local radio.

import 'package:halo_i18n/halo_i18n.dart';
import 'package:halo_widgets/halo_widgets.dart' show MdiIcons;

import '../fyi_service.dart';
import 'cat_service.dart';
import 'equipment.dart';

/// Posts each local radio's SWR to its set's FYI area: a warning from
/// [swrWarnsFrom], an alert from [swrAlertsFrom], read off the average CAT
/// keeps per transmission ([CatService.swrAverageFor] — the one under way,
/// else the last one), and taken down once a transmission reads under the
/// warning. One key per radio, so the two levels never show side by side:
/// a match that worsens mid-over turns the warning into the alert in place.
class SwrWatch {
  SwrWatch({required this.cat, required this.fyi});

  final CatService cat;
  final FyiService fyi;

  void start() {
    cat.meterReadings.addListener(_check);
    _check();
  }

  void dispose() => cat.meterReadings.removeListener(_check);

  static String keyFor(String radio) => 'swr:$radio';

  void _check() {
    final radio1 = cat.radio1;
    for (final (uuid, radio) in [(radio1 is LocalRadio ? radio1.uuid : null, 'A'), (cat.radio2, 'B')]) {
      if (uuid == null) {
        // A role with no local radio has no SWR to speak of, and a message
        // left standing from the radio that held it would describe a rig
        // that is gone.
        fyi.clear(keyFor(radio));
        continue;
      }
      final swr = cat.swrAverageFor(uuid);
      // A transmission just begun has no reading yet: what the last one
      // said stands until this one says otherwise, or the message would
      // blink out at every key-down and back at the first reading.
      if (swr == null && cat.stateFor(uuid).telemetry.transmitting == true) continue;
      final key = keyFor(radio);
      if (swr == null || swr < swrWarnsFrom) {
        fyi.clear(key);
        continue;
      }
      final alert = swr >= swrAlertsFrom;
      final value = swr.toStringAsFixed(1);
      fyi.post(
        FyiMessage(
          key: key,
          category: alert ? FyiCategory.alert : FyiCategory.warning,
          icon: MdiIcons.antenna,
          text: alert ? t.fyi.swrAlert(swr: value) : t.fyi.swrWarning(swr: value),
          radio: radio,
        ),
      );
    }
  }
}
