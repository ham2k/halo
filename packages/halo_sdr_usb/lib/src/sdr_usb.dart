// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// A USB SDR receiver, as the app drives one: what it offers, tuning it, and
// reading back the newest of what it sampled. Platform-free, so the app's
// code and its tests can name these on every platform; only the desktop
// binding (sdr_usb_ffi.dart) opens one.

import 'dart:typed_data';

/// The receivers this opens. [code] is the native binding's own.
enum SdrUsbKind {
  /// Airspy R2 and Mini, through libairspy.
  airspy(1),

  /// Airspy HF+ Dual Port, Discovery and Ranger, through libairspyhf.
  airspyHf(2),

  /// SDRplay's RSPs, through the API the operator installs with SDRplay's
  /// software. Never on macOS: a signed, sandboxed app may not load a
  /// library it did not ship.
  sdrplay(3);

  const SdrUsbKind(this.code);
  final int code;
}

/// What [SdrUsbDevice.streaming] reports.
enum SdrUsbStreaming {
  stopped,
  streaming,

  /// It stopped without being asked: unplugged, or a USB error its library
  /// gave up on.
  lost,
}

/// One open receiver. What talks to the hardware — starting, stopping,
/// tuning — runs off the calling isolate, in the order it was asked for, and
/// may take a while: a USB control transfer, or a round trip to SDRplay's
/// service. Reading the ring is a copy, and answers at once.
abstract interface class SdrUsbDevice {
  SdrUsbKind get kind;

  /// The rates it offers, in samples a second, ascending. Never empty.
  List<int> get sampleRates;

  int get minFrequencyHz;
  int get maxFrequencyHz;

  /// Queued behind whatever was asked before; a failure leaves the receiver
  /// where it was, as a server's clamp would.
  void setSampleRate(int rate);
  void setFrequency(int hz);

  /// A gain step of the receiver's own, or null for its automatic gain.
  void setGain(int? step);

  /// True once it is streaming; false when it would not start.
  Future<bool> start();

  /// Done once the stop has run off the calling isolate: whatever was
  /// streaming then has stopped, until a later [start].
  Future<void> stop();

  /// While a command is still on its way, what was last asked for — a rate
  /// change restarts an Airspy's stream, and that is not the receiver going.
  SdrUsbStreaming get streaming;

  /// Complex samples written since it was opened: one past the newest's index.
  int get written;

  /// How far back the ring reaches: older samples are gone.
  int get capacity;

  /// Copies samples [from] .. [from] + [count] — indexes as [written] counts
  /// them — into [into] as interleaved I/Q floats from float [at]. Returns
  /// how many it copied: fewer once [from] is overwritten or past the newest.
  int read(int from, int count, Float32List into, int at);

  /// Stops it and lets it go. From the call on, it reads as gone.
  Future<void> close();
}

/// Why a receiver could not be opened, in the vendor library's words.
class SdrUsbOpenException implements Exception {
  final String message;

  /// Nothing to open it with: no USB support in this build, or no SDRplay
  /// API installed.
  final bool unavailable;

  const SdrUsbOpenException(this.message, {this.unavailable = false});

  @override
  String toString() => 'SdrUsbOpenException: $message';
}
