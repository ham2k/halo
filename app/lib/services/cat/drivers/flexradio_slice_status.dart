// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0

part of 'flexradio_driver.dart';

/// What the radio last said about one slice. Merged field-by-field from the
/// status pushes, which carry only what changed.
@immutable
class _SliceStatus {
  final String label;

  /// Null when the radio has mentioned this slice without ever saying
  /// whether it is running. Guessing either way is a real answer to a
  /// question nobody asked: `true` withdraws a missing-slice problem that is
  /// still true, and `false` accuses a slice that is fine. Both are silent,
  /// so the state is representable instead.
  final bool? inUse;
  final double? freqKHz;
  final String? mode;
  final String? clientHandle;

  /// Whether this slice holds the radio's transmit flag (`tx=1`).
  final bool? tx;

  /// The panadapter showing this slice, as `0x40000000`.
  final String? pan;

  /// The receive filter's edges, in Hz from the slice frequency.
  final int? filterLo, filterHi;

  /// The antennas in use, and the ports each can choose.
  final String? rxant, txant;
  final List<String>? rxPorts, txPorts;

  /// `audio_pan` (0 left, 100 right) and `audio_mute`: what SO2R switches.
  final int? audioPan;
  final bool? audioMute;

  /// The DAX channel the slice's audio goes to, 0 for none.
  final int? dax;

  const _SliceStatus({
    required this.label,
    required this.inUse,
    this.freqKHz,
    this.mode,
    this.clientHandle,
    this.tx,
    this.pan,
    this.filterLo,
    this.filterHi,
    this.rxant,
    this.txant,
    this.rxPorts,
    this.txPorts,
    this.audioPan,
    this.audioMute,
    this.dax,
  });
}
