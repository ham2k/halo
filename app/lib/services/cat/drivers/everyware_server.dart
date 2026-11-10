// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// A Green Heron Everyware server: the one connection its rotators and
// switches share (docs/design/cat.md § Green Heron Everyware).
//
// The server node's session is the hub. It logs in, keeps the connection,
// and remembers the last word on every device, so a device node that
// attaches late still starts from the whole picture. Each device node's
// connection is an [EverywareDeviceConnection] onto this hub: the hub's
// lines about that one device, and its commands going out over the hub's
// socket.

import 'dart:async';
import 'dart:typed_data';

import 'package:halo_core/halo_core.dart' show realNowMillis;
import 'package:halo_i18n/halo_i18n.dart';

import '../driver.dart';
import '../equipment.dart';
import '../transport.dart';
import 'everyware_codec.dart';

/// The config keys a device node keeps: whose server, and which device.
const everywareServerConfigKey = 'everywareServer';
const everywareDeviceConfigKey = 'everywareDevice';

/// The server node's list of devices the operator ticked, as
/// [everywareDeviceKey]s.
const everywareDevicesConfigKey = 'everywareDevices';

/// What the server last announced, as `{key, kind}` maps: the editor lists
/// it while the server is not connected, so a device can be switched off —
/// or on, for the next connect — without connecting first.
const everywareKnownDevicesConfigKey = 'everywareKnownDevices';

/// The `kind` of a device that is listed but not offered: a bank switch's
/// positions are each on or off, and a stack switches several antennas in at
/// once, neither of which a one-selection switch can show.
const everywareUnsupportedKinds = {'bank', 'stack'};

/// Login, both optional: a server with authentication off never asks.
const everywareUserConfigKey = 'user';
const everywarePasswordConfigKey = 'password';

enum EverywareDeviceKind { rotor, switchBox, stack }

/// A device's identity on its server. Rotors and switches are named in
/// separate lists, so a rotor and a switch can share a name.
String everywareDeviceKey(EverywareDeviceKind kind, String name) => '${kind.name}:$name';

/// The kind and name [everywareDeviceKey] made, or null for anything else.
({EverywareDeviceKind kind, String name})? parseEverywareDeviceKey(String key) {
  final colon = key.indexOf(':');
  if (colon < 0) return null;
  final kind = EverywareDeviceKind.values.where((kind) => kind.name == key.substring(0, colon)).firstOrNull;
  return kind == null ? null : (kind: kind, name: key.substring(colon + 1));
}

/// The first keepalive, then the period of the rest, as the Everyware client
/// sends them. Skipped while a command went out within a period: the server
/// reads raw chunks, and a NUL landing behind a command corrupts it.
const everywareKeepaliveFirst = Duration(seconds: 10);
const everywareKeepalivePeriod = Duration(seconds: 5);

/// The server node itself: address and login, no device of its own.
class EverywareServerDriver extends EquipmentDriver {
  const EverywareServerDriver();

  @override
  String get key => 'gh-everyware';

  @override
  String get name => 'GH Everyware';

  @override
  EquipmentSession createSession(EquipmentSink sink, Map<String, dynamic> config) => EverywareServerSession(
    sink,
    user: (config[everywareUserConfigKey] as String? ?? '').trim(),
    password: config[everywarePasswordConfigKey] as String? ?? '',
  );
}

/// What the hub knows about one device, kept so a link opened later can be
/// told it.
class _DeviceRecord {
  /// The announcement — `ADD` or `SWITCHADD` — then the latest state lines,
  /// in the order a link replays them.
  String? added;
  String? state;
  String? locks;
  EverywareSwitchKind? switchKind;
  final links = <EverywareDeviceConnection>{};

  Iterable<String> get replay => [?added, ?state, ?locks];
}

class EverywareServerSession implements EquipmentSession {
  final EquipmentSink _sink;
  final String user;
  final String password;

  EverywareServerSession(this._sink, {this.user = '', this.password = ''});

  final _splitter = EverywareLineSplitter();
  final _devices = <String, _DeviceRecord>{};
  Timer? _keepaliveStart;
  Timer? _keepalive;
  int? _lastCommandMillis;
  bool _closed = false;

  /// Every device in the order the server announced it, as the editor lists
  /// them: a switch's kind as the channel's mode, `stack` for a stack, none
  /// for a rotor. A bank and a stack are listed though nothing here drives
  /// them ([everywareUnsupportedKinds]).
  List<EquipmentChannel> get devices => [
    for (final entry in _devices.entries)
      if (entry.value.added != null)
        EquipmentChannel(
          key: entry.key,
          label: parseEverywareDeviceKey(entry.key)!.name,
          inUse: true,
          mode: entry.key.startsWith('${EverywareDeviceKind.stack.name}:') ? 'stack' : entry.value.switchKind?.name,
        ),
  ];

  @override
  Duration? get expectedUpdateInterval => null;

  @override
  void startUpdates() {
    if (_keepaliveStart != null || _closed) return;
    _keepaliveStart = Timer(everywareKeepaliveFirst, () {
      _sendKeepalive();
      _keepalive = Timer.periodic(everywareKeepalivePeriod, (_) => _sendKeepalive());
    });
  }

  /// Nothing to pause: the server pushes, and the keepalive is what keeps
  /// the connection rather than the readings.
  @override
  void stopUpdates() {}

  @override
  void teardown() {
    _closed = true;
    _keepaliveStart?.cancel();
    _keepalive?.cancel();
    for (final record in _devices.values) {
      for (final link in record.links.toList()) {
        unawaited(link.close());
      }
    }
    _devices.clear();
  }

  void _sendKeepalive() {
    final last = _lastCommandMillis;
    if (last != null && realNowMillis() - last < everywareKeepalivePeriod.inMilliseconds) return;
    _sink.send(everywareKeepalive);
  }

  /// A device link's command, out over this connection.
  void _sendCommand(List<int> bytes) {
    if (_closed) return;
    _lastCommandMillis = realNowMillis();
    _sink.send(bytes);
  }

  /// A connection carrying [deviceKey]'s lines, starting with everything the
  /// server has said about it so far.
  EverywareDeviceConnection openDevice(String deviceKey) {
    final link = EverywareDeviceConnection._(this, deviceKey);
    if (_closed) {
      unawaited(link.close());
      return link;
    }
    final record = _devices.putIfAbsent(deviceKey, _DeviceRecord.new)..links.add(link);
    for (final line in record.replay) {
      link._deliver(line);
    }
    return link;
  }

  void _detach(EverywareDeviceConnection link) => _devices[link.deviceKey]?.links.remove(link);

  @override
  void handleData(Uint8List chunk) {
    for (final line in _splitter.add(chunk)) {
      // Never silent for long, even with nothing moving: the server repeats
      // every rotor's heading about once a second and every switch's
      // position every few seconds, so a device node's own lines keep its
      // silence watch fed as well as this one's.
      _sink.reportAlive();
      _handle(line, parseEverywareLine(line));
    }
  }

  void _handle(String line, EverywareMessage message) {
    switch (message) {
      case EverywareAskUser():
        if (user.isEmpty) {
          _sink.reportProblem(t.settings.station.everywareNeedsLogin);
        } else {
          _sink.send(everywareUser(user));
        }
      case EverywareAskPassword(:final challenge):
        _sink.send(everywarePasswordProof(user: user, password: password, challenge: challenge));
      case EverywareLoginRefused():
        _sink.reportProblem(t.settings.station.everywareLoginRefused);
      case EverywareRotorAdded(:final name):
        _announce(everywareDeviceKey(EverywareDeviceKind.rotor, name), line);
      case EverywareSwitchAdded(:final name, :final kind):
        _announce(everywareDeviceKey(EverywareDeviceKind.switchBox, name), line, switchKind: kind ?? EverywareSwitchKind.buttons);
      case EverywareRotorRemoved(:final name):
        _withdraw(everywareDeviceKey(EverywareDeviceKind.rotor, name), line);
      case EverywareSwitchRemoved(:final name):
        _withdraw(everywareDeviceKey(EverywareDeviceKind.switchBox, name), line);
      case EverywareStackAdded(:final name):
        _announce(everywareDeviceKey(EverywareDeviceKind.stack, name), line);
      case EverywareStackRemoved(:final name):
        _withdraw(everywareDeviceKey(EverywareDeviceKind.stack, name), line);
      case EverywarePoint(:final name):
        _update(everywareDeviceKey(EverywareDeviceKind.rotor, name), line);
      case EverywareSwitchUpdate(:final name):
        _update(everywareDeviceKey(EverywareDeviceKind.switchBox, name), line);
      case EverywareSwitchLocks(:final name):
        _update(everywareDeviceKey(EverywareDeviceKind.switchBox, name), line, locks: true);
      case EverywareClose() || EverywareOther():
        break;
    }
  }

  void _announce(String key, String line, {EverywareSwitchKind? switchKind}) {
    // Moved to the end on its first announcement: [devices] lists them in the
    // order the server announced them, and a heading can arrive before the
    // ADD that names its rotor.
    final record = _devices[key]?.added != null ? _devices[key]! : (_devices.remove(key) ?? _DeviceRecord());
    _devices[key] = record;
    final listed = record.added != null;
    record
      ..added = line
      ..switchKind = switchKind;
    for (final link in record.links) {
      link._deliver(line);
    }
    if (!listed) _sink.reportChannels(devices);
  }

  void _withdraw(String key, String line) {
    final record = _devices[key];
    if (record == null) return;
    for (final link in record.links) {
      link._deliver(line);
    }
    record
      ..added = null
      ..state = null
      ..locks = null;
    if (record.links.isEmpty) _devices.remove(key);
    _sink.reportChannels(devices);
  }

  void _update(String key, String line, {bool locks = false}) {
    final record = _devices.putIfAbsent(key, _DeviceRecord.new);
    if (locks) {
      record.locks = line;
    } else {
      record.state = line;
    }
    for (final link in record.links) {
      link._deliver(line);
    }
  }

  @override
  String toString() => 'EverywareServerSession(${_devices.length} devices)';
}

/// One device node's view of its server's connection.
///
/// Its bytes are the server's lines about that device, each with its line
/// break; what it sends goes out over the server's socket as is. It closes
/// when the device node lets go, or when the server's connection does.
class EverywareDeviceConnection implements EquipmentConnection {
  final EverywareServerSession _hub;
  final String deviceKey;

  EverywareDeviceConnection._(this._hub, this.deviceKey);

  final _data = StreamController<Uint8List>();
  final _closed = Completer<void>();

  void _deliver(String line) {
    if (_closed.isCompleted) return;
    _data.add(Uint8List.fromList([...cp1252Encode(line), 0x0D, 0x0A]));
  }

  @override
  Stream<Uint8List> get data => _data.stream;

  @override
  Future<void> get closed => _closed.future;

  @override
  void send(List<int> bytes) {
    if (_closed.isCompleted) return;
    _hub._sendCommand(bytes);
  }

  @override
  Future<void> close() async {
    if (_closed.isCompleted) return;
    _hub._detach(this);
    _closed.complete();
    unawaited(_data.close());
  }
}
