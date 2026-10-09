// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// A radio's panadapter, as the app sees it — docs/design/cat.md § Spectrum.
// Pure data and one session interface: no I/O, no Flutter widgets.
//
// Frames never cross the extension bridge. A sweep arrives up to thirty times
// a second with hundreds of points; the host paints it, and an extension only
// places the control and reads or sets the radio's scope settings.

import 'package:flutter/foundation.dart';

import 'driver.dart';

/// One sweep across [lowHz]..[highHz], left to right.
///
/// [levels] are dB on the radio's own scale, which is not dBm on any radio
/// here: an Icom reports 0..160 steps of its screen, and a Flex mirrored
/// through DAX IQ is dB below full scale. [floorDb]..[ceilingDb] is the
/// range the radio itself would draw them in, so a display maps that range
/// to its height and an operator's contrast setting moves from there.
@immutable
class SpectrumFrame {
  final int lowHz;
  final int highHz;
  final Float32List levels;
  final double floorDb;
  final double ceilingDb;

  /// App-clock millis ([nowMillis], never `DateTime.now()` — docs/design/time.md).
  final int atMillis;

  const SpectrumFrame({
    required this.lowHz,
    required this.highHz,
    required this.levels,
    required this.floorDb,
    required this.ceilingDb,
    required this.atMillis,
  });
}

/// Where the sweep sits: following the VFO, or between fixed edges.
enum SpectrumMode { center, fixed }

/// How fast the radio sweeps — the three settings every scope here offers.
enum SpectrumSpeed { slow, mid, fast }

/// What the radio's scope is set to, as the radio last said.
@immutable
class SpectrumSettings {
  final SpectrumMode mode;

  /// Half the width shown in [SpectrumMode.center] — what Icom calls the
  /// span, and what the radio's own menu shows as ±.
  final int? spanHz;

  /// The edges in [SpectrumMode.fixed]; null while centered.
  final int? lowHz;
  final int? highHz;

  final double? refLevelDb;
  final SpectrumSpeed? speed;

  const SpectrumSettings({this.mode = SpectrumMode.center, this.spanHz, this.lowHz, this.highHz, this.refLevelDb, this.speed});

  SpectrumSettings copyWith({SpectrumMode? mode, int? spanHz, int? lowHz, int? highHz, double? refLevelDb, SpectrumSpeed? speed}) => SpectrumSettings(
    mode: mode ?? this.mode,
    spanHz: spanHz ?? this.spanHz,
    lowHz: lowHz ?? this.lowHz,
    highHz: highHz ?? this.highHz,
    refLevelDb: refLevelDb ?? this.refLevelDb,
    speed: speed ?? this.speed,
  );

  @override
  bool operator ==(Object other) =>
      other is SpectrumSettings &&
      other.mode == mode &&
      other.spanHz == spanHz &&
      other.lowHz == lowHz &&
      other.highHz == highHz &&
      other.refLevelDb == refLevelDb &&
      other.speed == speed;

  @override
  int get hashCode => Object.hash(mode, spanHz, lowHz, highHz, refLevelDb, speed);

  @override
  String toString() => 'SpectrumSettings(${mode.name}, ±$spanHz, $lowHz..$highHz, ref $refLevelDb, ${speed?.name})';
}

/// What a request may ask for, per radio. A request outside it is clamped or
/// snapped by the session, never sent as-is: a radio answers an unknown span
/// with a NAK the session cannot tie back to the command that caused it.
@immutable
class SpectrumCapabilities {
  /// The half-widths the radio accepts, ascending.
  final List<int> spansHz;
  final double refMinDb;
  final double refMaxDb;
  final double refStepDb;
  final Set<SpectrumMode> modes;
  final Set<SpectrumSpeed> speeds;

  const SpectrumCapabilities({
    required this.spansHz,
    required this.refMinDb,
    required this.refMaxDb,
    required this.refStepDb,
    this.modes = const {SpectrumMode.center},
    this.speeds = const {},
  });

  int snapSpan(int hz) => spansHz.reduce((a, b) => (a - hz).abs() <= (b - hz).abs() ? a : b);

  double snapRef(double db) => ((db.clamp(refMinDb, refMaxDb) - refMinDb) / refStepDb).round() * refStepDb + refMinDb;
}

/// A change to the scope. Null fields are left as they are.
@immutable
class SpectrumRequest {
  final SpectrumMode? mode;
  final int? spanHz;
  final double? refLevelDb;
  final SpectrumSpeed? speed;

  const SpectrumRequest({this.mode, this.spanHz, this.refLevelDb, this.speed});
}

/// A session whose radio can stream its panadapter.
///
/// The scope runs only between [startSpectrum] and [stopSpectrum], which the
/// manager calls as the first display appears and the last one goes. A radio
/// streaming a sweep nobody draws is not free: on a serial line it is most of
/// the bandwidth the VFO and the keyer share.
abstract class SpectrumSession implements EquipmentSession {
  /// Why this connection cannot show a spectrum, in words for the operator,
  /// or null when it can.
  String? get spectrumUnavailable;

  SpectrumCapabilities get spectrumCapabilities;

  void startSpectrum();

  void stopSpectrum();

  /// False when the scope is not running, so nothing was sent: a change
  /// asked of a stopped scope is refused, not queued for whenever it runs.
  bool setSpectrum(SpectrumRequest request);
}

/// The sink calls a spectrum session reports through. Separate from
/// [EquipmentSink] so the drivers without a scope implement nothing new.
abstract class SpectrumSink {
  /// One sweep. Never stored in [EquipmentState]: it would notify every
  /// listener of the station thirty times a second.
  void reportSpectrum(SpectrumFrame frame);

  void reportSpectrumSettings(SpectrumSettings settings);

  /// Why a scope that should run cannot right now, in words for the
  /// operator — null once it can. For what changes with the radio's state
  /// (every DAX IQ channel taken); what is fixed for the connection is
  /// [SpectrumSession.spectrumUnavailable].
  void reportSpectrumProblem(String? message);
}
