// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// What a configured device offers the rest of the app, and how one of those
// things is addressed — docs/design/station-model.md § 4. Pure data: no I/O.

import 'package:flutter/foundation.dart';

/// A receiver: a frequency, a mode, a passband.
const kCapabilityReceiver = 'rx';

/// A transmitter: power, PTT, the meters while keyed.
const kCapabilityTransmitter = 'tx';

/// A spectrum and waterfall for a receiver.
const kCapabilityScope = 'scope';

/// Something that sends CW for the app.
const kCapabilityKeyer = 'keyer';

/// Voice memories held in the equipment.
const kCapabilityVoice = 'voice';

/// Routes its inputs to its outputs: an antenna switch, or a radio's own
/// antenna ports.
const kCapabilitySwitch = 'switch';

const kCapabilityRotator = 'rotator';

/// Combines audio channels and routes them to outputs.
const kCapabilityAudioMixer = 'audioMixer';

/// Sits between two radios and one operator: which radio is heard, and which
/// one the key, the PTT and the microphone reach.
const kCapabilitySo2rController = 'so2rController';

/// A piece of wire in the air, with nothing to connect to: there to be
/// picked and credited.
const kCapabilityAntenna = 'antenna';

/// A key on the desk, for [kCapabilityAntenna]'s reason.
const kCapabilityKey = 'key';

/// The key of a capability its device has only one of.
const capabilityDefaultKey = 'main';

/// A radio's own antenna ports, as a [kCapabilitySwitch]: its key, and the
/// outputs every one has, wired inside the radio to its receiver and its
/// transmitter.
const radioSwitchKey = 'ant';
const radioSwitchOutputs = [kCapabilityReceiver, kCapabilityTransmitter];

/// One thing a device offers.
///
/// [key] is the equipment's own name for it — a Flex slice's index, a rotor
/// as its server names it — and never a position in a list: equipment that
/// numbers from one or leaves a gap would be mis-addressed by an index.
@immutable
class Capability {
  final String kind;
  final String key;

  /// A [kCapabilitySwitch]'s ports, by the equipment's own keys: [inputs] on
  /// the antenna side, [outputs] on the side a radio plugs into. Empty for
  /// every other kind, and for a switch that has not said what it has.
  final List<String> inputs, outputs;

  const Capability(this.kind, {this.key = capabilityDefaultKey, this.inputs = const [], this.outputs = const []});

  @override
  bool operator ==(Object other) =>
      other is Capability && other.kind == kind && other.key == key && listEquals(other.inputs, inputs) && listEquals(other.outputs, outputs);

  @override
  int get hashCode => Object.hash(kind, key, Object.hashAll(inputs), Object.hashAll(outputs));

  @override
  String toString() => 'Capability($kind:$key${inputs.isEmpty && outputs.isEmpty ? '' : ', in: $inputs, out: $outputs'})';
}

/// Which piece of which device: `<device>/<kind>:<key>`, and
/// `<device>/<kind>:<key>/in:<port>` or `…/out:<port>` for a port of it
/// (station-model.md § 4.2).
///
/// A bare `<device>` is an address too: the device's first receiver, or the
/// one thing a device with no receiver offers. Extension calls, peer offers
/// and stored picks hold a device's id and mean its radio, or its rotator,
/// by it. So two addresses can name one capability, and what is compared is
/// what each resolves to, never the addresses.
///
/// These are stored wherever a slot holds one, so [toString] and [parse] are
/// a format, not a display: a `/` or `%` in any part is percent-escaped, and
/// what one writes the other reads back.
@immutable
class CapabilityAddress {
  final String device;
  final String? kind, key;

  /// Null for the capability itself; otherwise which side [port] is on.
  final bool? portIsInput;
  final String? port;

  const CapabilityAddress.device(this.device) : kind = null, key = null, portIsInput = null, port = null;

  const CapabilityAddress(this.device, String this.kind, {String this.key = capabilityDefaultKey}) : portIsInput = null, port = null;

  const CapabilityAddress.input(this.device, String this.kind, String this.key, String this.port) : portIsInput = true;

  const CapabilityAddress.output(this.device, String this.kind, String this.key, String this.port) : portIsInput = false;

  CapabilityAddress.of(String device, Capability capability) : this(device, capability.kind, key: capability.key);

  /// Whether this names a device and nothing on it.
  bool get isDevice => kind == null;

  /// The capability this is, or is a port of.
  CapabilityAddress get capability => port == null || kind == null ? this : CapabilityAddress(device, kind!, key: key!);

  /// Null for anything that is not an address — an empty part, a kind that is
  /// not an identifier, a fourth segment.
  static CapabilityAddress? parse(String text) {
    final parts = text.split('/');
    if (parts.isEmpty || parts.length > 3) return null;
    final device = _unescape(parts[0]);
    if (device == null || device.isEmpty) return null;
    if (parts.length == 1) return CapabilityAddress.device(device);

    final named = _split(parts[1]);
    if (named == null || !_identifier.hasMatch(named.$1)) return null;
    final (kind, key) = named;
    if (parts.length == 2) return CapabilityAddress(device, kind, key: key);

    return switch (_split(parts[2])) {
      ('in', final port) => CapabilityAddress.input(device, kind, key, port),
      ('out', final port) => CapabilityAddress.output(device, kind, key, port),
      _ => null,
    };
  }

  static final _identifier = RegExp(r'^[A-Za-z][A-Za-z0-9]*$');

  /// A `%` that does not start one of the two escapes [toString] writes.
  static final _strayEscape = RegExp(r'%(?!25|2F)');

  /// `name:rest`, split at the first colon — a key may hold more of them.
  static (String, String)? _split(String segment) {
    final colon = segment.indexOf(':');
    if (colon <= 0) return null;
    final rest = _unescape(segment.substring(colon + 1));
    return rest == null || rest.isEmpty ? null : (segment.substring(0, colon), rest);
  }

  static String _escape(String part) => part.replaceAll('%', '%25').replaceAll('/', '%2F');

  /// Null for an escape that is not one this format writes.
  static String? _unescape(String part) {
    if (_strayEscape.hasMatch(part)) return null;
    return part.replaceAll('%2F', '/').replaceAll('%25', '%');
  }

  @override
  String toString() =>
      [_escape(device), if (kind != null) '$kind:${_escape(key!)}', if (port != null) '${portIsInput! ? 'in' : 'out'}:${_escape(port!)}'].join('/');

  @override
  bool operator ==(Object other) =>
      other is CapabilityAddress && other.device == device && other.kind == kind && other.key == key && other.portIsInput == portIsInput && other.port == port;

  @override
  int get hashCode => Object.hash(device, kind, key, portIsInput, port);
}
