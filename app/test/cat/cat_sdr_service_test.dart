// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// An SDR receiver in the station: which radio's spectrum it draws, and when
// it is connected. An rtl_tcp server streams for as long as a client holds
// it and serves one client at a time, so an SDR connected while nothing
// draws it is megabytes a second of waste and another program locked out.

import 'dart:async';
import 'dart:io' show SocketException;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:halo_i18n/halo_i18n.dart';
import 'package:ham2k_logger/services/cat/auto_connect_guard.dart';
import 'package:ham2k_logger/services/cat/cat_service.dart';
import 'package:ham2k_logger/services/cat/driver.dart';
import 'package:ham2k_logger/services/cat/drivers/sdr_spectrum.dart';
import 'package:ham2k_logger/services/cat/equipment.dart';
import 'package:ham2k_logger/services/cat/equipment_registry.dart';
import 'package:ham2k_logger/services/cat/spectrum.dart';
import 'package:ham2k_logger/services/cat/transport.dart';
import 'package:ham2k_logger/services/cat/transports/sdr_usb_transport.dart' show SdrUsbTransport;
import 'package:ham2k_logger/services/panel_radio_service.dart';
import 'package:ham2k_logger/services/radio_service.dart';
import 'package:ham2k_logger/services/settings_service.dart';
import 'package:ham2k_logger/views/operation/panel_scene/cat_spectrum_source.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Connection implements EquipmentConnection {
  final _data = StreamController<Uint8List>();
  final _closed = Completer<void>();
  @override
  Stream<Uint8List> get data => _data.stream;
  @override
  Future<void> get closed => _closed.future;
  @override
  void send(List<int> bytes) {}
  @override
  Future<void> close() async {
    if (!_closed.isCompleted) _closed.complete();
    await _data.close();
  }
}

/// A receiver on this computer's USB, as far as the connect path can tell:
/// only the transport's key says so.
class _UsbTransport extends _Transport {
  @override
  String get key => SdrUsbTransport.transportKey;
}

class _Transport extends EquipmentTransport {
  int connects = 0;
  final opened = <_Connection>[];

  /// Held until completed, when set: a connect still under way.
  Completer<void>? gate;
  bool refuse = false;
  @override
  String get key => 'fake';
  @override
  Future<EquipmentConnection> connect(Map<String, dynamic> target, {required CatCancelToken cancel}) async {
    connects++;
    await gate?.future;
    if (refuse) throw const SocketException('Connection refused');
    final connection = _Connection();
    opened.add(connection);
    return connection;
  }
}

/// A radio that reports [khz] on connect.
class _Radio implements TransceiverSession {
  final EquipmentSink sink;
  final double khz;
  _Radio(this.sink, this.khz);
  @override
  void startUpdates() => sink.report(VfoReading(freqKHz: khz, mode: 'USB'));
  @override
  void handleData(Uint8List chunk) {}
  @override
  void stopUpdates() {}
  @override
  void teardown() {}
  @override
  Duration? get expectedUpdateInterval => null;
  @override
  void setFrequency(double freqKHz) {}
  @override
  void setMode(String mode) {}
  @override
  void setPower(num watts) {}
}

class _RadioDriver extends EquipmentDriver {
  final double khz;
  _RadioDriver(this.khz);
  @override
  String get key => 'radio-$khz';
  @override
  String get name => 'Radio';
  @override
  EquipmentSession createSession(EquipmentSink sink, Map<String, dynamic> config) => _Radio(sink, khz);
}

class _Sdr implements SpectrumSession {
  final EquipmentSink sink;
  final Map<String, dynamic> config;
  _Sdr(this.sink, this.config);
  @override
  String? get spectrumUnavailable => null;
  @override
  SpectrumCapabilities get spectrumCapabilities => const SpectrumCapabilities(spansHz: [1], refMinDb: 0, refMaxDb: 1, refStepDb: 1);
  @override
  void startSpectrum() {}
  @override
  void stopSpectrum() {}
  @override
  bool setSpectrum(SpectrumRequest request) => true;
  @override
  void handleData(Uint8List chunk) {}
  @override
  void startUpdates() {}
  @override
  void stopUpdates() {}
  @override
  void teardown() {}
  @override
  Duration? get expectedUpdateInterval => null;
}

class _SdrDriver extends EquipmentDriver {
  final sessions = <_Sdr>[];
  @override
  String get key => 'sdr';
  @override
  String get name => 'SDR';
  @override
  EquipmentSession createSession(EquipmentSink sink, Map<String, dynamic> config) {
    final session = _Sdr(sink, config);
    sessions.add(session);
    return session;
  }
}

const _release = Duration(milliseconds: 20);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late CatService cat;
  late RadioService radio;
  late SettingsService settings;
  late SharedPreferences prefs;
  late _Transport transport;
  late _UsbTransport usbTransport;
  late _SdrDriver sdrDriver;

  CatService build({Duration sdrRetryDelay = const Duration(minutes: 5)}) {
    transport = _Transport();
    usbTransport = _UsbTransport();
    sdrDriver = _SdrDriver();
    final cat = CatService(
      settings = SettingsService(prefs),
      radio: radio,
      registry: EquipmentRegistry(
        models: [
          EquipmentModel(
            key: 'left',
            category: kCategoryTransceiver,
            name: () => 'Left',
            variants: [EquipmentVariant(key: 'left-type', driver: _RadioDriver(14074), transport: transport)],
          ),
          EquipmentModel(
            key: 'right',
            category: kCategoryTransceiver,
            name: () => 'Right',
            variants: [EquipmentVariant(key: 'right-type', driver: _RadioDriver(7030), transport: transport)],
          ),
          EquipmentModel(
            key: 'sdr',
            category: kCategorySdr,
            name: () => 'SDR',
            variants: [EquipmentVariant(key: 'sdr-type', driver: sdrDriver, transport: transport)],
          ),
          EquipmentModel(
            key: 'usb-sdr',
            category: kCategorySdr,
            name: () => 'USB SDR',
            variants: [EquipmentVariant(key: 'usb-sdr-type', driver: sdrDriver, transport: usbTransport)],
          ),
        ],
        transports: {'fake': transport, SdrUsbTransport.transportKey: usbTransport},
      ),
      reconnectDelay: Duration.zero,
      idleRetryFirst: const Duration(minutes: 5),
      sdrIdleRelease: _release,
      sdrRetryDelay: sdrRetryDelay,
    );
    addTearDown(cat.dispose);
    return cat;
  }

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    radio = RadioService(prefs, writeDelay: Duration.zero);
    addTearDown(radio.dispose);
    cat = build();
  });

  Future<void> settle() async {
    for (var i = 0; i < 5; i++) {
      await Future<void>.delayed(Duration.zero);
    }
  }

  test("an SDR linked to Main draws Main's spectrum, and moves with the Main pick", () async {
    final left = (await cat.addNode(typeKey: 'left-type', name: 'Left', config: const {})).uuid;
    final right = (await cat.addNode(typeKey: 'right-type', name: 'Right', config: const {})).uuid;
    final sdr = (await cat.addNode(typeKey: 'sdr-type', name: 'SDR', config: const {sdrRadioConfigKey: sdrRadioMain})).uuid;
    // The newest radio is Main.
    expect(cat.spectrumNodeFor(right), sdr);
    expect(cat.spectrumNodeFor(left), left, reason: 'a radio with no SDR keeps its own scope');

    await cat.setRadio1(LocalRadio(left));
    expect(cat.spectrumNodeFor(left), sdr);
    expect(cat.spectrumNodeFor(right), right);
  });

  test("with SDR receivers off, a linked SDR stands in for the radio's scope neither in the panel nor in readRadio", () async {
    final left = (await cat.addNode(typeKey: 'left-type', name: 'Left', config: const {})).uuid;
    final sdr = (await cat.addNode(typeKey: 'sdr-type', name: 'SDR', config: const {sdrRadioConfigKey: sdrRadioMain})).uuid;
    await cat.connect(left);
    await settle();
    final scene = CatSpectrumSource(cat, settings: settings);
    final panel = PanelRadioService(cat, radio, sdrEnabled: () => settings.experimentEnabled('fall'));
    var changed = 0;
    scene.changes.addListener(() => changed++);
    // Left has no scope of its own, so its spectrum reads null; the SDR's,
    // not yet connected, reads as a wait. Gating one path and not the other
    // would have a panel set one scope while its control draws another.
    expect(scene.resolve(left), left);
    expect(panel.read(left)['spectrum'], isNull);

    // The source the dock built before the toggle: a gate it captured then
    // would keep drawing Left while the panel reads and sets the SDR.
    await settings.setExperimentEnabled('fall', true);
    expect(changed, greaterThan(0), reason: 'the control re-resolves only when told to');
    expect(scene.resolve(left), sdr);
    expect(panel.read(left)['spectrum'], isNotNull);
  });

  test('an SDR linked to one radio stays with it whichever radio is Main', () async {
    final left = (await cat.addNode(typeKey: 'left-type', name: 'Left', config: const {})).uuid;
    final sdr = (await cat.addNode(typeKey: 'sdr-type', name: 'SDR', config: {sdrRadioConfigKey: left})).uuid;
    final right = (await cat.addNode(typeKey: 'right-type', name: 'Right', config: const {})).uuid;
    expect(cat.spectrumNodeFor(right), right, reason: 'Main moved to Right; the SDR did not');
    expect(cat.spectrumNodeFor(left), sdr);
    expect(cat.linkedRadioFor(sdr), left);
  });

  test("the SDR reads its linked radio's dial through its sink", () async {
    final left = (await cat.addNode(typeKey: 'left-type', name: 'Left', config: const {})).uuid;
    final sdr = (await cat.addNode(typeKey: 'sdr-type', name: 'SDR', config: {sdrRadioConfigKey: left})).uuid;
    await cat.connect(sdr);
    final sink = sdrDriver.sessions.single.sink as SdrSink;
    expect(sink.linkedVfoHz, isNull, reason: 'the radio is not connected, so it has no dial to follow');
    await cat.connect(left);
    expect(sink.linkedVfoHz, 14074000);
  });

  test('a display connects the SDR, and it is let go a moment after the last one leaves', () async {
    await cat.addNode(typeKey: 'left-type', name: 'Left', config: const {});
    final sdr = (await cat.addNode(typeKey: 'sdr-type', name: 'SDR', config: const {})).uuid;
    expect(cat.stateFor(sdr).status, EquipmentStatus.disconnected, reason: 'nothing draws it yet');

    final display = cat.spectrumFrames(sdr).listen((_) {});
    await settle();
    expect(cat.stateFor(sdr).status, EquipmentStatus.connected);

    // A tab switched away and back costs nothing.
    await display.cancel();
    final again = cat.spectrumFrames(sdr).listen((_) {});
    await Future<void>.delayed(_release * 3);
    expect(cat.stateFor(sdr).status, EquipmentStatus.connected);
    expect(transport.connects, 1, reason: 'the second display found it still connected');

    await again.cancel();
    await Future<void>.delayed(_release * 3);
    expect(cat.stateFor(sdr).status, EquipmentStatus.disconnected);

    // Letting go is not the operator's Disconnect: the next display connects it again.
    final later = cat.spectrumFrames(sdr).listen((_) {});
    await settle();
    expect(cat.stateFor(sdr).status, EquipmentStatus.connected);
    await later.cancel();
  });

  test('a display that leaves while the SDR is still connecting does not leave it connected', () async {
    final sdr = (await cat.addNode(typeKey: 'sdr-type', name: 'SDR', config: const {})).uuid;
    final display = cat.spectrumFrames(sdr).listen((_) {});
    await Future<void>.microtask(() {});
    await display.cancel();
    await Future<void>.delayed(_release * 3);
    expect(cat.stateFor(sdr).status, EquipmentStatus.disconnected, reason: 'held open, the server streams to nobody and refuses every other client');
  });

  test('a display waiting through a release gets the SDR back', () async {
    final sdr = (await cat.addNode(typeKey: 'sdr-type', name: 'SDR', config: const {})).uuid;
    final display = cat.spectrumFrames(sdr).listen((_) {});
    await settle();
    await cat.disconnect(sdr, byUser: false);
    await settle();
    expect(cat.stateFor(sdr).status, EquipmentStatus.connected);
    await display.cancel();
  });

  test('an edit to a live SDR reaches it at once, without counting as a Disconnect', () async {
    final sdr = (await cat.addNode(typeKey: 'sdr-type', name: 'SDR', config: const {})).uuid;
    final display = cat.spectrumFrames(sdr).listen((_) {});
    await settle();
    await cat.updateNode(cat.nodeFor(sdr)!.copyWith(config: {sdrOffsetHzConfigKey: 125000000}));
    await settle();
    expect(cat.stateFor(sdr).status, EquipmentStatus.connected);
    expect(sdrDriver.sessions.last.config[sdrOffsetHzConfigKey], 125000000, reason: 'the setup is read when a session starts');
    await display.cancel();
  });

  test("the operator's Disconnect holds, and hands the radio back its own scope", () async {
    final left = (await cat.addNode(typeKey: 'left-type', name: 'Left', config: const {})).uuid;
    final sdr = (await cat.addNode(typeKey: 'sdr-type', name: 'SDR', config: const {})).uuid;
    await cat.connect(sdr);
    await cat.disconnect(sdr);
    expect(cat.spectrumNodeFor(left), left, reason: 'an SDR switched off would leave the radio with no picture at all');
    // A display already open on it is not a way back on.
    final display = cat.spectrumFrames(sdr).listen((_) {});
    await settle();
    expect(cat.stateFor(sdr).status, EquipmentStatus.disconnected);
    await display.cancel();

    await cat.connect(sdr);
    expect(cat.spectrumNodeFor(left), sdr);
  });

  test("the operator's Connect keeps it connected with nothing drawing it", () async {
    final sdr = (await cat.addNode(typeKey: 'sdr-type', name: 'SDR', config: const {})).uuid;
    await cat.connect(sdr);
    final display = cat.spectrumFrames(sdr).listen((_) {});
    await settle();
    await display.cancel();
    await Future<void>.delayed(_release * 3);
    expect(cat.stateFor(sdr).status, EquipmentStatus.connected, reason: 'let go, it reads as a dropped connection the operator just made');
  });

  test('a display that comes and goes as it connects starts one connect, not two', () async {
    transport.gate = Completer<void>();
    final sdr = (await cat.addNode(typeKey: 'sdr-type', name: 'SDR', config: const {})).uuid;
    // Within one frame, so each settles before the first connect has said
    // `connecting`: the status alone cannot tell them it is under way.
    final first = cat.spectrumFrames(sdr).listen((_) {});
    unawaited(first.cancel());
    final second = cat.spectrumFrames(sdr).listen((_) {});
    await settle();
    transport.gate!.complete();
    await settle();
    expect(transport.connects, 1, reason: 'the second supersedes the first, and the server takes one client');
    expect(cat.stateFor(sdr).status, EquipmentStatus.connected);
    await second.cancel();
  });

  test('an SDR connect leaves no crash mark to hold it at the next launch', () async {
    transport.gate = Completer<void>();
    final sdr = (await cat.addNode(typeKey: 'sdr-type', name: 'SDR', config: const {})).uuid;
    final display = cat.spectrumFrames(sdr).listen((_) {});
    await settle();
    expect(autoConnectMarks(prefs), isNot(contains(sdr)), reason: 'held, the SDR would say "auto-connect held" and no notice would name it');
    transport.gate!.complete();
    await display.cancel();
  });

  test('a USB SDR connect is marked while it runs, as a radio\'s is', () async {
    // Its open is a native call into libusb or SDRplay's service that can
    // wedge the process; unmarked, a display open at launch would open it
    // again, and wedge again, on every launch.
    usbTransport.gate = Completer<void>();
    final sdr = (await cat.addNode(typeKey: 'usb-sdr-type', name: 'USB SDR', config: const {})).uuid;
    final display = cat.spectrumFrames(sdr).listen((_) {});
    await settle();
    expect(autoConnectMarks(prefs), contains(sdr));
    usbTransport.gate!.complete();
    await settle();
    expect(autoConnectMarks(prefs), isNot(contains(sdr)), reason: 'a connect that returns leaves nothing behind');
    expect(cat.stateFor(sdr).status, EquipmentStatus.connected);
    await display.cancel();
  });

  test('a server that refuses is said to, not waited on forever', () async {
    transport.refuse = true;
    final sdr = (await cat.addNode(typeKey: 'sdr-type', name: 'SDR', config: const {})).uuid;
    final display = cat.spectrumFrames(sdr).listen((_) {});
    await settle();
    expect(cat.stateFor(sdr).status, EquipmentStatus.error);
    expect(cat.sdrConnectionProblem(sdr), isNot(t.settings.station.spectrumWaiting), reason: 'a wait would never end');
    await display.cancel();
  });

  test('a radio re-typed into an SDR is connected by the display that wants it', () async {
    final node = await cat.addNode(typeKey: 'left-type', name: 'Was a radio', config: const {});
    await cat.connect(node.uuid);
    await cat.updateNode(node.copyWith(typeKey: 'sdr-type'));
    final display = cat.spectrumFrames(node.uuid).listen((_) {});
    await settle();
    expect(cat.stateFor(node.uuid).status, EquipmentStatus.connected, reason: "a re-type into an SDR is not the operator's Disconnect");
    expect(sdrDriver.sessions, hasLength(1));
    await display.cancel();
  });

  test('an SDR whose stream can no longer be read loses its connection, and is not counted as switched off', () async {
    final left = (await cat.addNode(typeKey: 'left-type', name: 'Left', config: const {})).uuid;
    final sdr = (await cat.addNode(typeKey: 'sdr-type', name: 'SDR', config: const {})).uuid;
    final display = cat.spectrumFrames(sdr).listen((_) {});
    await settle();
    (sdrDriver.sessions.single.sink as SdrSink).dropConnection('out of step');
    await settle();
    expect(cat.stateFor(sdr).status, isNot(EquipmentStatus.connected), reason: 'held open, the server streams on into a session that reads none of it');
    expect(cat.spectrumNodeFor(left), sdr, reason: "not the operator's Disconnect: the display waits for it to come back");
    await display.cancel();
  });

  /// Until [done], on the real clock: a retry is a timer, which may run
  /// late but not early, so the deadline only stops a hang
  /// (docs/design/time.md §7).
  Future<void> until(bool Function() done) async {
    for (var i = 0; i < 5000 && !done(); i++) {
      await Future<void>.delayed(const Duration(milliseconds: 1));
    }
    expect(done(), isTrue);
  }

  test('why the last connection ended is shown while it is tried again, until a sweep is drawn', () async {
    cat = build(sdrRetryDelay: const Duration(milliseconds: 10));
    final sdr = (await cat.addNode(typeKey: 'sdr-type', name: 'SDR', config: const {})).uuid;
    final display = cat.spectrumFrames(sdr).listen((_) {});
    await settle();
    (sdrDriver.sessions.last.sink as SdrSink).dropConnection('No receiver attached');
    await settle();
    expect(cat.sdrConnectionProblem(sdr), 'No receiver attached', reason: 'a wait would never end, on a server that fails the same way each time');

    await until(() => cat.stateFor(sdr).status == EquipmentStatus.connected);
    expect(sdrDriver.sessions, hasLength(2));
    expect(cat.sdrConnectionProblem(sdr), 'No receiver attached', reason: 'connected is not drawing: forgotten here, it would flash a wait between tries');

    (sdrDriver.sessions.last.sink as SpectrumSink).reportSpectrum(
      SpectrumFrame(lowHz: 0, highHz: 1, levels: Float32List(4), floorDb: -100, ceilingDb: 0, atMillis: 0),
    );
    expect(cat.sdrConnectionProblem(sdr), isNull);

    // A connection that ends with nothing said.
    await transport.opened.last.close();
    await settle();
    expect(cat.sdrConnectionProblem(sdr), t.settings.station.spectrumSdrServerClosed);
    await display.cancel();
  });

  test('a failed connect is the reason shown through the next try, and a display that leaves forgets it', () async {
    cat = build(sdrRetryDelay: const Duration(milliseconds: 10));
    final sdr = (await cat.addNode(typeKey: 'sdr-type', name: 'SDR', config: const {})).uuid;
    final display = cat.spectrumFrames(sdr).listen((_) {});
    await settle();
    transport.refuse = true;
    (sdrDriver.sessions.last.sink as SdrSink).dropConnection('No receiver attached');
    await until(() => cat.stateFor(sdr).status == EquipmentStatus.error);
    final refused = cat.sdrConnectionProblem(sdr);
    expect(refused, isNot('No receiver attached'));

    // The next try, held mid-connect.
    transport
      ..refuse = false
      ..gate = Completer<void>();
    await until(() => cat.stateFor(sdr).status == EquipmentStatus.connecting);
    expect(cat.sdrConnectionProblem(sdr), refused, reason: 'the older drop is not the newest reason');

    await display.cancel();
    transport.gate!.complete();
    await settle();
    expect(cat.sdrConnectionProblem(sdr), isNot(refused), reason: 'a display opened later meets a fresh wait, not an old failure');
  });

  test('a radio is never connected or released by a display', () async {
    final left = (await cat.addNode(typeKey: 'left-type', name: 'Left', config: const {})).uuid;
    final display = cat.spectrumFrames(left).listen((_) {});
    await settle();
    expect(cat.stateFor(left).status, EquipmentStatus.disconnected);
    await cat.connect(left);
    await display.cancel();
    await Future<void>.delayed(_release * 3);
    expect(cat.stateFor(left).status, EquipmentStatus.connected);
  });
}
