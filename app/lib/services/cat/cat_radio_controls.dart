// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Commands to one radio by node, and what it measured — beside CatService's
// designation-driven paths, for what addresses a radio directly: an extension
// panel pinned to it, or one following the logging radio.

part of 'cat_service.dart';

/// How soon a tune the radio was asked for shows as one in its reports.
const _tuneShowsWithinMillis = 3000;

/// Longer than a tune runs: a radio tuning this long after the app started
/// one is tuning again on its own.
const _tuneOutlastsMillis = 60000;

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

  /// Whether [uuid]'s radio starts a tune apart from putting its tuner in
  /// line — see [AntennaTunerSession.canStartTune].
  bool canStartTuneFor(String uuid) => switch (connectedSession(uuid)) {
    final AntennaTunerSession session => session.canStartTune,
    _ => false,
  };

  /// When this app last started a tune on each radio: the tunes
  /// [stopNodeTunes] ends.
  final _tunesStarted = <String, int>{};

  /// Starts a tune on [uuid]'s radio — a carrier on the air. Only for an
  /// operator's explicit request; a no-op where [canStartTuneFor] is false.
  void startNodeTune(String uuid) {
    final session = connectedSession(uuid);
    if (session is! AntennaTunerSession) return;
    // A tune takes a moment to show as one in the radio's reports, and until
    // it does a second press would go out into it.
    final started = _tunesStarted[uuid];
    if (started != null && realNowMillis() - started < _tuneShowsWithinMillis) return;
    try {
      session.startTune();
      _tunesStarted[uuid] = realNowMillis();
    } catch (e, st) {
      ErrorReportingService.report(e, st, context: 'cat:start-tune');
    }
  }

  /// Ends every tune this app started that is still running, or too new to
  /// show yet — Escape's, and a panel's stop. True when it ended one. A tune
  /// started on the radio itself is the operator's at the radio, and left
  /// alone.
  bool stopNodeTunes() {
    final now = realNowMillis();
    var stopped = false;
    for (final MapEntry(key: uuid, value: started) in _tunesStarted.entries) {
      final age = now - started;
      if (age >= _tuneOutlastsMillis || (stateFor(uuid).tuner != TunerStatus.tuning && age >= _tuneShowsWithinMillis)) continue;
      if (connectedSession(uuid) case final AntennaTunerSession session) {
        try {
          session.stopTune();
          stopped = true;
        } catch (e, st) {
          ErrorReportingService.report(e, st, context: 'cat:stop-tune');
        }
      }
    }
    _tunesStarted.clear();
    return stopped;
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
