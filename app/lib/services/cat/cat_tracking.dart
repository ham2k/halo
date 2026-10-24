// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The `radio_*` analytics events, and what each is allowed to say about the
// equipment (docs/design/telemetry.md).

part of 'cat_service.dart';

extension _Tracking on CatService {
  /// Describes a radio by its catalogue identity — the variant key (a
  /// stable id we ship), its transport and its driver — plus the node's
  /// name. Still never any other config: a serial `port` embeds the
  /// adapter's device serial number on macOS, and the network transports
  /// hold addresses and passwords. See docs/design/telemetry.md.
  ///
  /// Taking the whole [node] (not a separately-passed name) so every call
  /// site gets the same blank-name fallback rather than each one having to
  /// remember it: an unnamed node — freshly loaded from a pre-`name` record,
  /// or blanked out in the editor, which enforces no minimum length — falls
  /// back to the driver's own name, e.g. "Kenwood (CAT)". That is still
  /// bounded (drawn from our own driver catalogue, not typed by the
  /// operator), just less specific than a real name.
  void _trackRadio(String event, EquipmentNode node, {Map<String, Object?> extra = const {}}) {
    final track = _onTrack;
    if (track == null) return;
    final type = registry.typeFor(node.typeKey);
    final name = node.name.isNotEmpty ? node.name : (type?.driver.name ?? node.typeKey);
    track(event, {'radio': node.typeKey, 'transport': type?.transportKey, 'driver': type?.driver.key, 'name': _trackedName(name), ...extra});
  }

  /// The name field has no length limit in the editor, unlike every other
  /// property this event sends — all bounded by our own catalogue. Capped
  /// here, at the one place all `radio_*` events funnel through, rather than
  /// in the editor: a length limit there is a UX decision for the name
  /// operators see everywhere, not a telemetry one.
  static const _maxTrackedNameLength = 60;

  static String _trackedName(String name) => name.length <= _maxTrackedNameLength ? name : name.substring(0, _maxTrackedNameLength);

  /// The baud rate a failed serial attempt was using — deliberately the ONE
  /// config value that goes out. A mismatch is the classic cause of a silent
  /// port, the set of rates is small and fixed, and it identifies nobody.
  Map<String, Object?> _baudExtra(Map<String, dynamic> config) => config['baudRate'] == null ? const {} : {'baud': config['baudRate']};

  /// First failure per node per session only — see [_trackedFailed]. Not
  /// re-armed by a later success on purpose: a flapping rig would otherwise
  /// report on every cycle, which is the volume this de-dup exists to stop.
  /// The question being answered is "does this pairing ever fail for people",
  /// not "how often".
  void _trackFailure(EquipmentNode node, String reason, {Map<String, Object?> extra = const {}}) {
    if (!_trackedFailed.add(node.uuid)) return;
    _trackRadio('radio_connect_failed', node, extra: {'reason': reason, ...extra});
  }
}
