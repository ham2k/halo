// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The radio named on every crash report — see docs/design/telemetry.md
// § The equipment tag.
//
// Not consent-gated, unlike the first-success report it sits beside: the
// value is an EquipmentVariant key from our own catalogue, bounded by what we
// ship and identifying nobody. Without it the crash stream names a radio only
// inside a CatConnectFailure title, which is to say only when one fails.

import '../error_reporting_service.dart';

/// Holds the last value sent so an unchanged tag is not re-sent.
///
/// It is fed from `CatService._setState`, the one funnel every status change
/// passes through — which is also the funnel every METER reading passes
/// through, at up to five a second. Without this the backend would take a
/// scope write per reading to say what it already knows.
class EquipmentTag {
  String? _sent;

  /// [radio] is the connected radio's variant key, or null when nothing is.
  void update(String? radio) {
    if (radio == _sent) return;
    _sent = radio;
    ErrorReportingService.updateEquipmentContext(radio: radio);
  }
}
