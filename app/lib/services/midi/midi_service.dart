// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Binds each MIDI controller node in Station Configuration to its device and
// feeds that device's messages to a [MidiController] — see docs/design/cat.md
// § MIDI controllers. Nothing here runs, and the platform's MIDI is never
// asked for, until `EXP MIDI` is on AND a MIDI controller node exists: on the
// web that first ask is a permission prompt.

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:halo_widgets/halo_widgets.dart' show KeyCommandPresser;

import '../cat/cat_service.dart';
import '../cat/equipment.dart';
import '../error_reporting_service.dart';
import '../settings_service.dart';
import 'midi_backend.dart';
import 'midi_codec.dart';
import 'midi_controller.dart';
import 'midi_mapping.dart';
import 'midi_station.dart';
import 'midi_targets.dart';

enum MidiDeviceStatus {
  /// The node names no device yet.
  noDevice,

  /// The named device is not plugged in, or not on.
  waiting,
  connecting,
  connected,

  /// The platform has no MIDI here, or refused access to it.
  unavailable,

  /// Opening the device failed; [MidiService.failureFor] says how.
  failed,
}

/// The mapping pane's monitor line: the last message the node's device sent,
/// and what it did — null [outcome] for a control the controller maps to
/// nothing, which may still press a keyboard [shortcut].
class MidiMonitorLine {
  final MidiControlMessage message;
  final MidiOutcome? outcome;

  /// The Keyboard Shortcuts command the control pressed.
  final String? shortcut;
  const MidiMonitorLine(this.message, this.outcome, {this.shortcut});
}

/// A row waiting in Learn for a control, and what it last turned down — a
/// note offered to a knob row, say.
class MidiLearning {
  final String nodeUuid;
  final String targetId;
  final MidiTargetKind? refused;
  const MidiLearning(this.nodeUuid, this.targetId, {this.refused});
}

class MidiService extends ChangeNotifier {
  final CatService cat;
  final SettingsService settings;
  final MidiStation station;
  final MidiBackend Function() _newBackend;

  /// The Keyboard Shortcuts command a control presses, by its stored form
  /// (`note:1:60`) — for a control no controller node maps.
  final String? Function(String control) _shortcutFor;
  final KeyCommandPresser _presser;

  MidiService({
    required this.cat,
    required this.settings,
    required this.station,
    MidiBackend Function()? backend,
    String? Function(String control)? shortcutFor,
    KeyCommandPresser? presser,
  }) : _newBackend = backend ?? FlutterMidiBackend.new,
       _shortcutFor = shortcutFor ?? _noShortcut,
       _presser = presser ?? KeyCommandPresser.instance;

  static String? _noShortcut(String control) => null;

  /// Shortcut presses held, by node and control: what a release, or the
  /// device going away, lets go of.
  final _shortcutsHeld = <String, Set<String>>{};

  /// Waiting in the Keyboard Shortcuts editor for a control to bind.
  void Function(MidiControl control)? _shortcutLearn;

  MidiBackend? _backend;
  StreamSubscription<({String deviceId, Uint8List data})>? _packets;
  StreamSubscription<void>? _changes;
  bool _started = false;

  final _controllers = <String, MidiController>{};
  final _configs = <String, Map<String, dynamic>>{};
  final _status = <String, MidiDeviceStatus>{};
  final _failures = <String, String>{};

  /// Device id → the node it is bound to. One node per device: two nodes
  /// naming the same device would both act on every message.
  final _boundDevice = <String, String>{};

  /// The running status a device's last packet ended in, for one that
  /// carries it across packets.
  final _runningStatus = <String, int>{};

  final _monitors = <String, ValueNotifier<MidiMonitorLine?>>{};

  /// Names of the devices the platform lists now, for the pane's picker.
  final devices = ValueNotifier<List<String>>(const []);

  /// The row in Learn, if any.
  final learning = ValueNotifier<MidiLearning?>(null);

  /// The MIDI controller nodes, while `EXP MIDI` is on; none while it is off.
  List<EquipmentNode> get _midiNodes => settings.experimentEnabled('midi') /* stored key, see experiments.yaml */
      ? [
          for (final node in cat.nodes)
            if (cat.typeFor(node)?.category == kCategoryMidi) node,
        ]
      : const [];

  MidiDeviceStatus statusFor(String uuid) => _status[uuid] ?? MidiDeviceStatus.noDevice;

  /// Whether any controller's device is connected — what the Keyboard
  /// Shortcuts editor needs to learn a control from.
  bool get anyConnected => _status.values.contains(MidiDeviceStatus.connected);

  /// The controller node and target that map [control], if any: those win
  /// over a shortcut bound to the same control.
  ({EquipmentNode node, String targetId})? controllerMapping(MidiControl control) {
    for (final MapEntry(key: uuid, value: controller) in _controllers.entries) {
      final target = controller.mapping.targetFor(control);
      final node = cat.nodeFor(uuid);
      if (target != null && node != null) return (node: node, targetId: target);
    }
    return null;
  }

  /// Hands the next control pressed on any connected controller to
  /// [onControl], swallowing everything until then; null stops waiting.
  void learnShortcut(void Function(MidiControl control)? onControl) {
    if (onControl != null) {
      // Learn swallows the releases of what is held now: let go first.
      for (final uuid in _controllers.keys) {
        _releaseNode(uuid);
      }
    }
    _shortcutLearn = onControl;
  }

  /// Lets go of everything [uuid]'s device holds down: the controller's own
  /// key, and the shortcuts it pressed.
  void _releaseNode(String uuid) {
    _controllers[uuid]?.releaseAll();
    for (final control in _shortcutsHeld.remove(uuid) ?? const <String>{}) {
      _presser.release('$uuid/$control');
    }
  }

  String? failureFor(String uuid) => _failures[uuid];
  ValueListenable<MidiMonitorLine?> monitorFor(String uuid) => _monitors.putIfAbsent(uuid, () => ValueNotifier(null));

  void start() {
    if (_started) return;
    _started = true;
    settings.addListener(_sync);
    cat.addListener(_sync);
    _sync();
  }

  /// Runs on every CatService notification, which is every reading a radio
  /// sends: it compares configs by identity and does nothing more until one
  /// changed.
  void _sync() {
    final nodes = _midiNodes;
    if (nodes.isEmpty) {
      if (_backend != null) _stop();
      return;
    }
    // A PTT change notifies too: a key dropped elsewhere is no longer one a
    // controller's release may let go of.
    for (final controller in _controllers.values) {
      controller.forgetDroppedKey();
    }
    var changed = _backend == null;
    final present = {for (final n in nodes) n.uuid};
    for (final uuid in _controllers.keys.toList()) {
      if (present.contains(uuid)) continue;
      _releaseNode(uuid);
      _controllers.remove(uuid)!.dispose();
      _configs.remove(uuid);
      _status.remove(uuid);
      _failures.remove(uuid);
      // Closed with the node: left open, a node added later for the same
      // device would open it a second time.
      for (final id in [
        for (final MapEntry(key: id, value: node) in _boundDevice.entries)
          if (node == uuid) id,
      ]) {
        _boundDevice.remove(id);
        _runningStatus.remove(id);
        _backend?.disconnect(id);
      }
      changed = true;
    }
    for (final node in nodes) {
      if (identical(_configs[node.uuid], node.config)) continue;
      final previousDevice = _configs[node.uuid] == null ? null : MidiMapping.fromConfig(_configs[node.uuid]!).device;
      _configs[node.uuid] = node.config;
      final mapping = MidiMapping.fromConfig(node.config);
      final controller = _controllers[node.uuid];
      if (controller == null) {
        _controllers[node.uuid] = MidiController(station: station, mapping: mapping);
      } else {
        controller.mapping = mapping;
      }
      if (mapping.device != previousDevice) changed = true;
    }
    if (_backend == null) unawaited(_open());
    if (changed) unawaited(_bind());
  }

  Future<void> _open() async {
    final backend = _backend = _newBackend();
    _packets = backend.packets.listen(_onPacket, onError: (Object e, StackTrace st) => ErrorReportingService.report(e, st, context: 'midi:packets'));
    _changes = backend.changes.listen((_) => unawaited(_bind()));
  }

  void _stop() {
    learning.value = null;
    _shortcutLearn = null;
    for (final uuid in _controllers.keys) {
      _releaseNode(uuid);
    }
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    _controllers.clear();
    _configs.clear();
    _status.clear();
    _failures.clear();
    _boundDevice.clear();
    _runningStatus.clear();
    unawaited(_packets?.cancel());
    unawaited(_changes?.cancel());
    _packets = _changes = null;
    _backend?.dispose();
    _backend = null;
    devices.value = const [];
    notifyListeners();
  }

  /// Serialized: a device plugged in fires several setup changes in a row,
  /// and two binds interleaving would open it twice.
  Future<void> _bindTail = Future.value();

  Future<void> _bind() => _bindTail = _bindTail.then((_) => _bindNow()).catchError((Object e, StackTrace st) {
    ErrorReportingService.report(e, st, context: 'midi:bind');
  });

  Future<void> _bindNow() async {
    final backend = _backend;
    if (backend == null) return;
    final List<MidiDeviceInfo> listed;
    try {
      listed = await backend.devices();
    } catch (e, st) {
      // Nothing to bind, and the pane says why. ErrorPolicy keeps a platform
      // with no MIDI (MidiUnavailable) to the console.
      ErrorReportingService.report(e, st, context: 'midi:devices');
      if (!identical(backend, _backend)) return;
      for (final uuid in _controllers.keys) {
        _status[uuid] = MidiDeviceStatus.unavailable;
      }
      notifyListeners();
      return;
    }
    if (!identical(backend, _backend)) return;
    devices.value = [for (final d in listed) d.name];
    final byName = <String, MidiDeviceInfo>{for (final d in listed) d.name: d};
    final listedIds = {for (final d in listed) d.id};
    // A device that went away takes its key with it: a footswitch unplugged
    // mid-transmission must not leave the radio keyed.
    for (final id in _boundDevice.keys.toList()) {
      if (listedIds.contains(id)) continue;
      final uuid = _boundDevice.remove(id)!;
      _releaseNode(uuid);
      _runningStatus.remove(id);
    }
    final claimed = <String>{};
    // A copy: the connect below waits, and a node added or removed meanwhile
    // changes the map. A node added is bound by the bind its sync queues.
    for (final MapEntry(key: uuid, value: controller) in _controllers.entries.toList()) {
      if (!_controllers.containsKey(uuid)) continue;
      final name = controller.mapping.device;
      final device = name == null ? null : byName[name];
      final boundId = _boundDevice.entries.where((e) => e.value == uuid).map((e) => e.key).firstOrNull;
      if (boundId != null && boundId != device?.id) {
        _boundDevice.remove(boundId);
        _releaseNode(uuid);
        backend.disconnect(boundId);
      }
      if (name == null) {
        _status[uuid] = MidiDeviceStatus.noDevice;
        continue;
      }
      if (device == null || claimed.contains(device.id)) {
        _status[uuid] = MidiDeviceStatus.waiting;
        continue;
      }
      claimed.add(device.id);
      if (_boundDevice[device.id] == uuid && device.connected) {
        _status[uuid] = MidiDeviceStatus.connected;
        continue;
      }
      _status[uuid] = MidiDeviceStatus.connecting;
      _failures.remove(uuid);
      notifyListeners();
      try {
        await backend.connect(device.id);
      } catch (e, st) {
        ErrorReportingService.report(e, st, context: 'midi:connect');
        if (!identical(backend, _backend)) return;
        if (_controllers.containsKey(uuid)) {
          _status[uuid] = MidiDeviceStatus.failed;
          _failures[uuid] = '$e';
        }
        continue;
      }
      if (!identical(backend, _backend)) return;
      if (!_controllers.containsKey(uuid)) {
        // Removed while it opened: nothing reads it now.
        backend.disconnect(device.id);
        continue;
      }
      _boundDevice[device.id] = uuid;
      _status[uuid] = MidiDeviceStatus.connected;
    }
    notifyListeners();
  }

  void _onPacket(({String deviceId, Uint8List data}) packet) {
    final uuid = _boundDevice[packet.deviceId];
    final controller = uuid == null ? null : _controllers[uuid];
    if (controller == null) return;
    final (:messages, :runningStatus) = parseMidiPacket(packet.data, runningStatus: _runningStatus[packet.deviceId]);
    if (runningStatus == null) {
      _runningStatus.remove(packet.deviceId);
    } else {
      _runningStatus[packet.deviceId] = runningStatus;
    }
    for (final message in messages) {
      final monitor = _monitors.putIfAbsent(uuid!, () => ValueNotifier(null));
      if (_learn(uuid, controller, message) || _learnShortcut(message)) {
        monitor.value = MidiMonitorLine(message, null);
        continue;
      }
      if (controller.mapping.targetFor(message.control) == null) {
        monitor.value = MidiMonitorLine(message, null, shortcut: _pressShortcut(uuid, message));
        continue;
      }
      monitor.value = MidiMonitorLine(message, controller.handle(message));
    }
  }

  bool _learnShortcut(MidiControlMessage message) {
    final onControl = _shortcutLearn;
    if (onControl == null) return false;
    // A press: a note on, or a CC's press. Anything else is swallowed while
    // waiting — the knob turned on the way to the button must not act.
    if (message.control.kind != MidiControlKind.pb && message.on) {
      _shortcutLearn = null;
      onControl(message.control);
    }
    return true;
  }

  /// Presses or lets go of the shortcut [message]'s control is bound to, on
  /// its press and release edges; the command, when it has one.
  String? _pressShortcut(String uuid, MidiControlMessage message) {
    if (message.control.kind == MidiControlKind.pb) return null;
    final control = '${message.control}';
    final id = _shortcutFor(control);
    final held = _shortcutsHeld.putIfAbsent(uuid, () => {});
    final source = '$uuid/$control';
    if (!message.on) {
      if (held.remove(control)) _presser.release(source);
      return id;
    }
    // A CC button repeats its pressed value while held: one press.
    if (id == null || held.contains(control)) return id;
    held.add(control);
    _presser.press(source, id);
    return id;
  }

  /// Starts Learn on [targetId] — or ends it, when that row is already the
  /// one learning.
  void toggleLearn(String nodeUuid, String targetId) {
    final current = learning.value;
    if (current != null && current.nodeUuid == nodeUuid && current.targetId == targetId) {
      learning.value = null;
      return;
    }
    // Learn swallows the device's messages, a PTT release among them: the
    // controller lets go of what it keyed first.
    _releaseNode(nodeUuid);
    learning.value = MidiLearning(nodeUuid, targetId);
  }

  void cancelLearn() => learning.value = null;

  /// Whether Learn took [message].
  bool _learn(String uuid, MidiController controller, MidiControlMessage message) {
    final current = learning.value;
    if (current == null || current.nodeUuid != uuid) return false;
    final target = midiTargetById(current.targetId);
    final node = cat.nodeFor(uuid);
    if (target == null || node == null) {
      learning.value = null;
      return false;
    }
    // The release of the press that was learned.
    if (message.control.kind == MidiControlKind.note && !message.on) return true;
    if (!target.kind.accepts.contains(message.control.kind)) {
      learning.value = MidiLearning(uuid, target.id, refused: target.kind);
      return true;
    }
    learning.value = null;
    final config = MidiMapping.assign(node.config, target.id, message.control);
    // In force now, ahead of the write: a release arriving before it lands
    // would otherwise miss the row, leaving it held, and the first real press
    // after Learn would read as no change.
    controller.mapping = MidiMapping.fromConfig(config);
    // So the learning press does not fire on its release.
    controller.notePressed(target.id, on: message.on);
    unawaited(cat.updateNode(node.copyWith(config: config)));
    return true;
  }

  /// The app is quitting: closes every MIDI port, and stops following the
  /// settings and the radios, so nothing opens one again. Not [dispose]: the
  /// controller's settings may still be listening as the window goes.
  void closeForExit() {
    if (_started) {
      settings.removeListener(_sync);
      cat.removeListener(_sync);
    }
    _stop();
  }

  @override
  void dispose() {
    if (_started) {
      settings.removeListener(_sync);
      cat.removeListener(_sync);
    }
    _stop();
    for (final monitor in _monitors.values) {
      monitor.dispose();
    }
    devices.dispose();
    learning.dispose();
    super.dispose();
  }
}
