// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The platform's MIDI, as MidiService needs it: list the devices, open one,
// hear its bytes. A seam so the service's binding — a device unplugged with a
// key down, a replug finding its node again — is testable without one.

import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show TargetPlatform, defaultTargetPlatform, kIsWeb;
import 'package:flutter_midi_command/flutter_midi_command.dart';

class MidiDeviceInfo {
  final String id;
  final String name;
  final bool connected;

  const MidiDeviceInfo({required this.id, required this.name, this.connected = false});
}

/// The platform has no MIDI to list: a browser without Web MIDI (Safari), a
/// platform the plugin has none on. An expected condition the controller
/// pane says on its status line (ErrorPolicy's `midi-unavailable`).
class MidiUnavailable implements Exception {
  final Object cause;
  const MidiUnavailable(this.cause);

  @override
  String toString() => 'MIDI unavailable: $cause';
}

typedef MidiInputPacket = ({String deviceId, Uint8List data, int? atMicros});

abstract interface class MidiBackend {
  /// Throws [MidiUnavailable] where the platform has no MIDI; anything else
  /// it throws is a failure — access refused, a plugin fault.
  Future<List<MidiDeviceInfo>> devices();
  Future<void> connect(String id);
  void disconnect(String id);

  /// Configure only the explicitly selected MIDI device.
  void send(String id, List<int> bytes);

  /// Bytes from an open device, with its id and a capture timestamp when supported.
  Stream<MidiInputPacket> get packets;

  /// A device appeared, went or changed state.
  Stream<void> get changes;

  void dispose();
}

class FlutterMidiBackend implements MidiBackend {
  final _midi = MidiCommand();

  /// The plugin's own objects, by id: connect and disconnect take the
  /// instance the listing returned, which carries its route.
  final _known = <String, MidiDevice>{};

  @override
  Future<List<MidiDeviceInfo>> devices() async {
    final List<MidiDevice> listed;
    try {
      listed = await _midi.devices ?? const <MidiDevice>[];
    } on UnsupportedError catch (e) {
      // The plugin's own word for no MIDI here, Web MIDI missing among them.
      throw MidiUnavailable(e);
    }
    _known
      ..clear()
      ..addEntries([for (final d in listed) MapEntry(d.id, d)]);
    return [
      for (final d in listed)
        // Our own virtual ports are not controllers.
        if (d.type != MidiDeviceType.ownVirtual) MidiDeviceInfo(id: d.id, name: d.name, connected: d.connected),
    ];
  }

  @override
  Future<void> connect(String id) async {
    final device = _known[id];
    if (device == null) throw StateError('no MIDI device $id');
    await _midi.connectToDevice(device, awaitConnectionTimeout: const Duration(seconds: 10));
  }

  @override
  void disconnect(String id) {
    if (_known[id] case final device?) _midi.disconnectDevice(device);
  }

  @override
  void send(String id, List<int> bytes) {
    final device = _known[id];
    // The plugin labels the ports from the device's perspective.
    if (device == null || device.inputPorts.isEmpty) throw StateError('no MIDI destination for $id');
    _midi.sendData(Uint8List.fromList(bytes), deviceId: id);
  }

  @override
  Stream<MidiInputPacket> get packets => (_midi.onMidiPacketReceived ?? const Stream<MidiPacket>.empty()).map(
    (p) => (
      deviceId: p.device.id,
      data: p.data,
      // The Darwin plugin converts CoreMIDI host ticks to nanoseconds.
      atMicros: !kIsWeb && defaultTargetPlatform == TargetPlatform.macOS && p.timestamp > 0 ? p.timestamp ~/ 1000 : null,
    ),
  );

  @override
  Stream<void> get changes => (_midi.onMidiSetupChanged ?? const Stream<MidiSetupChange>.empty()).map((_) {});

  @override
  void dispose() {
    for (final device in _known.values) {
      if (device.connected) _midi.disconnectDevice(device);
    }
    _known.clear();
  }
}
