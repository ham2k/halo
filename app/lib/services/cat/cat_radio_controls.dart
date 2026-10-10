// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Commands to one radio by node, and what it measured — beside CatService's
// designation-driven paths, for what addresses a radio directly: an extension
// panel pinned to it, or one following the logging radio.

part of 'cat_service.dart';

mixin _RadioControls {
  Map<String, _NodeRuntime> get _runtimes;
  EquipmentSession? connectedSession(String uuid);
  EquipmentState stateFor(String uuid);

  /// Sets [uuid]'s receive passband, as near as its radio can — see
  /// [PassbandSession]. A no-op for a radio whose driver cannot.
  void setNodePassband(String uuid, Passband passband) {
    final session = connectedSession(uuid);
    if (session is! PassbandSession) return;
    try {
      session.setPassband(passband);
    } catch (e, st) {
      ErrorReportingService.report(e, st, context: 'cat:set-passband');
    }
  }

  /// Puts [uuid]'s antenna tuner in line or bypasses it. A no-op for a radio
  /// whose driver has no tuner control; on a FlexRadio, in line is a tune —
  /// see [AntennaTunerSession].
  void setNodeTuner(String uuid, {required bool inline}) {
    final session = connectedSession(uuid);
    if (session is! AntennaTunerSession) return;
    try {
      session.setTuner(inline: inline);
    } catch (e, st) {
      ErrorReportingService.report(e, st, context: 'cat:set-tuner');
    }
  }

  /// Pushes [watts] to the radio [uuid] names — what [setPower] does for
  /// radio1, for a panel pinned to another radio. Bypasses [RadioService]: a
  /// radio that is not radio1 has no app-wide value to keep in step.
  void setNodePower(String uuid, num watts) {
    final runtime = _runtimes[uuid];
    final session = runtime?.session;
    // Only a transceiver has RF output to set: a uuid naming a switch or a
    // keyer — radio1's stored designation read back from a stray record
    // included — changes nothing.
    if (session is! TransceiverSession) return;
    // The same echo guard [tuneNode] applies, and needed for the same
    // reason: every VFO notification — a typed frequency, a band pick —
    // arrives here too, and without this each one re-sends a power command
    // the radio already obeyed. Recorded only after the command lands, so a
    // throw doesn't leave a value remembered as delivered.
    if (runtime!.lastSentPower == watts) return;
    try {
      session.setPower(watts);
      runtime.lastSentPower = watts;
    } catch (e, st) {
      ErrorReportingService.report(e, st, context: 'cat:set-power');
    }
  }

  /// Picks [uuid]'s own antenna ports — see [RadioAntennaSession]. A no-op for
  /// a radio whose driver cannot.
  void setNodeAntenna(String uuid, {String? rx, String? tx}) {
    final session = connectedSession(uuid);
    if (session is! RadioAntennaSession) return;
    try {
      session.setAntenna(rx: rx, tx: tx);
    } catch (e, st) {
      ErrorReportingService.report(e, st, context: 'cat:set-antenna');
    }
  }

  /// The last transmission [uuid] finished since the app started: its average
  /// SWR over the readings taken with RF out (null when there were none), and
  /// when it ended, in real milliseconds — a span to show for a few seconds,
  /// which must not travel with the app clock.
  ({double? swrAverage, int endedAtMillis})? lastTransmissionFor(String uuid) => _runtimes[uuid]?.lastTransmission;

  /// The SWR average of the transmission under way, or else of the last one.
  double? swrAverageFor(String uuid) =>
      stateFor(uuid).telemetry.transmitting == true ? _runtimes[uuid]?.swrRunning : _runtimes[uuid]?.lastTransmission?.swrAverage;
}
