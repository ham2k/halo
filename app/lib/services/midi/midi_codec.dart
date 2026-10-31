// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The MIDI a controller sends, decoded to what a mapping can name: a control
// change, a note or the pitch bend, on a channel. Everything else on the wire
// — clock, system exclusive, aftertouch, program changes — is read past.
// See docs/design/cat.md § MIDI controllers.

/// The kind of message a control sends, and the first half of its identity.
enum MidiControlKind {
  cc,
  note,
  pb;

  static MidiControlKind? fromName(Object? name) => switch (name) {
    'cc' => cc,
    'note' => note,
    'pb' => pb,
    _ => null,
  };
}

/// Which control on the device: what a mapping stores.
class MidiControl {
  final MidiControlKind kind;

  /// 1–16, as controllers print it.
  final int channel;

  /// The CC or note number; 0 for the pitch bend, which a channel has one of.
  final int number;

  const MidiControl(this.kind, this.channel, this.number);

  static MidiControl? fromJson(Object? json) {
    if (json is! Map) return null;
    final kind = MidiControlKind.fromName(json['kind']);
    final channel = json['ch'], number = json['num'];
    if (kind == null || channel is! int || number is! int) return null;
    return MidiControl(kind, channel, number);
  }

  Map<String, dynamic> toJson() => {'kind': kind.name, 'ch': channel, 'num': number};

  /// [toString]'s form back — how a Keyboard Shortcuts binding stores one.
  static MidiControl? parse(String text) {
    final parts = text.split(':');
    if (parts.length != 3) return null;
    final kind = MidiControlKind.fromName(parts[0]);
    final channel = int.tryParse(parts[1]), number = int.tryParse(parts[2]);
    if (kind == null || channel == null || number == null) return null;
    return MidiControl(kind, channel, number);
  }

  @override
  bool operator ==(Object other) => other is MidiControl && other.kind == kind && other.channel == channel && other.number == number;

  @override
  int get hashCode => Object.hash(kind, channel, number);

  @override
  String toString() => '${kind.name}:$channel:$number';
}

/// One decoded message.
class MidiControlMessage {
  final MidiControl control;

  /// The value as sent: 0–127, or 0–16383 for the pitch bend.
  final int raw;

  /// Pressed: a note on with a velocity, or a CC at 64 or above — how a
  /// button sending CC says it is down.
  final bool on;

  const MidiControlMessage(this.control, this.raw, {required this.on});

  /// [raw] as 0…1.
  double get value => raw / (control.kind == MidiControlKind.pb ? 16383 : 127);
}

/// Decodes one packet, which may carry several messages and may lean on
/// running status — a controller sending a burst of CCs states the status
/// byte once. Real-time bytes (clock, active sensing) can land anywhere, even
/// mid-message, and are skipped without breaking the message around them.
/// [runningStatus] is the status the device's previous packet ended in, and
/// the result's is this one's, for the next.
({List<MidiControlMessage> messages, int? runningStatus}) parseMidiPacket(List<int> bytes, {int? runningStatus}) {
  final out = <MidiControlMessage>[];
  int? status = runningStatus;
  final data = <int>[];
  var inSysex = false;
  for (final byte in bytes) {
    if (byte >= 0xF8) continue;
    if (byte == 0xF0) {
      inSysex = true;
      status = null;
      continue;
    }
    if (byte == 0xF7) {
      inSysex = false;
      continue;
    }
    if (inSysex) continue;
    if (byte >= 0x80) {
      // System common messages cancel running status.
      status = byte < 0xF0 ? byte : null;
      data.clear();
      continue;
    }
    if (status == null) continue;
    data.add(byte);
    final type = status & 0xF0;
    final needs = type == 0xC0 || type == 0xD0 ? 1 : 2;
    if (data.length < needs) continue;
    final channel = (status & 0x0F) + 1;
    final message = switch (type) {
      0xB0 => MidiControlMessage(MidiControl(MidiControlKind.cc, channel, data[0]), data[1], on: data[1] >= 64),
      0x90 => MidiControlMessage(MidiControl(MidiControlKind.note, channel, data[0]), data[1], on: data[1] > 0),
      0x80 => MidiControlMessage(MidiControl(MidiControlKind.note, channel, data[0]), 0, on: false),
      0xE0 => MidiControlMessage(MidiControl(MidiControlKind.pb, channel, 0), (data[1] << 7) | data[0], on: false),
      _ => null,
    };
    if (message != null) out.add(message);
    data.clear();
  }
  return (messages: out, runningStatus: status);
}

/// How an endless knob says which way it turned. Controllers disagree, and
/// most do not say which they use.
enum MidiEncoderCoding {
  /// Guesses between [twos] and [offset64] from the value: one near 64 is the
  /// latter. A very fast spin (32 ticks or more in one message) can read
  /// backwards — name the coding outright on a controller that does that.
  relative,

  /// Two's complement: 1 is +1, 127 is -1.
  twos,

  /// 64-offset: 65 is +1, 63 is -1.
  offset64,

  /// Sign-magnitude: 1 is +1, 65 is -1.
  sign,

  /// A plain 0–127 knob with end stops: the change since its last message.
  absolute;

  static MidiEncoderCoding fromName(Object? name) => values.firstWhere((v) => v.name == name, orElse: () => relative);
}

/// The ticks one encoder message turned. [last] is the previous raw value
/// of the same control, which only [MidiEncoderCoding.absolute] reads — its
/// first message moves nothing, having nothing to move from.
int midiEncoderTicks(int raw, MidiEncoderCoding coding, {int? last}) => switch (coding) {
  MidiEncoderCoding.absolute => last == null ? 0 : raw - last,
  MidiEncoderCoding.sign => raw == 0 || raw == 64 ? 0 : (raw < 64 ? raw : -(raw - 64)),
  MidiEncoderCoding.twos => raw < 64 ? raw : raw - 128,
  MidiEncoderCoding.offset64 => raw - 64,
  MidiEncoderCoding.relative =>
    raw == 0 || raw == 64
        ? 0
        : (raw - 64).abs() < 32
        ? raw - 64
        : (raw < 64 ? raw : raw - 128),
};

/// [hz] moved [ticks] steps of [stepHz], landing on the step's grid: the
/// first tick from an off-grid frequency goes to the next grid line in that
/// direction (14.200.370 → 14.201.000 up, 14.200.000 down at 1 kHz), the rest
/// are whole steps. Without the snap a coarse knob would carry the fine
/// knob's leftovers forever.
int midiStepFrequency(int hz, int ticks, int stepHz) {
  if (ticks == 0 || stepHz <= 0 || hz <= 0) return hz;
  // Floor going up, ceiling going down: the grid line BEHIND the frequency,
  // so the first step lands on the next line ahead.
  final snapped = ticks > 0 ? (hz ~/ stepHz) * stepHz : ((hz + stepHz - 1) ~/ stepHz) * stepHz;
  return snapped + ticks * stepHz;
}
