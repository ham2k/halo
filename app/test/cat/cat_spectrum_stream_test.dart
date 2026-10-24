// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// CatService.spectrumFrames: the radio's scope runs while a display listens,
// and only then — on a serial line a sweep nobody draws is most of the
// bandwidth the VFO and the keyer share.
import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:ham2k_logger/services/cat/cat_service.dart';
import 'package:ham2k_logger/services/cat/driver.dart';
import 'package:ham2k_logger/services/cat/equipment.dart';
import 'package:ham2k_logger/services/cat/equipment_registry.dart';
import 'package:ham2k_logger/services/cat/spectrum.dart';
import 'package:ham2k_logger/services/cat/transport.dart';
import 'package:ham2k_logger/services/radio_service.dart';
import 'package:ham2k_logger/services/settings_service.dart';
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

class _Transport extends EquipmentTransport {
  @override
  String get key => 'fake';
  @override
  List<Map<String, dynamic>> configElements({Map<String, dynamic> overrides = const {}, Map<String, dynamic> restrictions = const {}}) => const [];
  @override
  String? validateField(String key, dynamic value, Map<String, dynamic> config) => null;
  @override
  String describeTarget(Map<String, dynamic> config) => 'fake';
  @override
  Future<EquipmentConnection> connect(Map<String, dynamic> target, {required CatCancelToken cancel}) async => _Connection();
}

class _Scope implements TransceiverSession, SpectrumSession {
  final SpectrumSink sink;
  final log = <String>[];
  _Scope(this.sink);
  @override
  String? get spectrumUnavailable => null;
  SpectrumCapabilities capabilities = const SpectrumCapabilities(spansHz: [1], refMinDb: 0, refMaxDb: 1, refStepDb: 1);
  @override
  SpectrumCapabilities get spectrumCapabilities => capabilities;
  final spans = <int?>[];
  @override
  void startSpectrum() => log.add('start');
  @override
  void stopSpectrum() => log.add('stop');
  bool running = false;
  @override
  bool setSpectrum(SpectrumRequest request) {
    if (running) spans.add(request.spanHz);
    return running;
  }

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
  @override
  void setFrequency(double freqKHz) {}
  @override
  void setMode(String mode) {}
  @override
  void setPower(num watts) {}

  void sweep() => sink.reportSpectrum(SpectrumFrame(lowHz: 0, highHz: 1, levels: Float32List(4), floorDb: 0, ceilingDb: 1, atMillis: 0));
}

class _Driver extends EquipmentDriver {
  final sessions = <_Scope>[];
  @override
  String get key => 'scope';
  @override
  String get name => 'Scope';
  @override
  EquipmentSession createSession(EquipmentSink sink, Map<String, dynamic> config) {
    final session = _Scope(sink as SpectrumSink);
    sessions.add(session);
    return session;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late CatService cat;
  late _Driver driver;
  late String uuid;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final radio = RadioService(prefs, writeDelay: Duration.zero);
    addTearDown(radio.dispose);
    driver = _Driver();
    final transport = _Transport();
    cat = CatService(
      SettingsService(prefs),
      radio: radio,
      registry: EquipmentRegistry(
        models: [
          EquipmentModel(
            key: 'scope',
            category: kCategoryTransceiver,
            name: () => 'Scope',
            variants: [EquipmentVariant(key: 'scope-type', driver: driver, transport: transport)],
          ),
        ],
        transports: {'fake': transport},
      ),
      reconnectDelay: Duration.zero,
      idleRetryFirst: const Duration(minutes: 5),
    );
    addTearDown(cat.dispose);
    uuid = (await cat.addNode(typeKey: 'scope-type', name: 'Scope', config: const {})).uuid;
    await cat.connect(uuid);
  });

  test('the scope starts with the first display and stops with the last', () async {
    expect(driver.sessions.single.log, isEmpty, reason: 'connected, with nothing drawing');
    final frames = <SpectrumFrame>[];
    final a = cat.spectrumFrames(uuid).listen(frames.add);
    final b = cat.spectrumFrames(uuid).listen((_) {});
    // Not yet: a display subscribes from inside a build, and starting a scope
    // writes state every listener of the station hears — Flutter refuses
    // that mid-build. It settles once the subscribing work is done.
    expect(driver.sessions.single.log, isEmpty);
    await pumpEventQueue();
    expect(driver.sessions.single.log, ['start']);
    driver.sessions.single.sweep();
    await pumpEventQueue();
    expect(frames, hasLength(1));
    await a.cancel();
    await pumpEventQueue();
    expect(driver.sessions.single.log, ['start'], reason: 'another display is still drawing');
    await b.cancel();
    await pumpEventQueue();
    expect(driver.sessions.single.log, ['start', 'stop']);
  });

  test('a display that leaves and comes back within one frame costs the radio nothing', () async {
    final first = cat.spectrumFrames(uuid).listen((_) {});
    await pumpEventQueue();
    // Unawaited, as a widget's dispose and a new pane's mount are: the same
    // synchronous frame, with no chance for the demand to settle between.
    unawaited(first.cancel());
    final second = cat.spectrumFrames(uuid).listen((_) {});
    await pumpEventQueue();
    expect(driver.sessions.single.log, ['start']);
    await second.cancel();
  });

  test('a display open across a reconnect starts the new session, and the old one is not heard', () async {
    final frames = <SpectrumFrame>[];
    final sub = cat.spectrumFrames(uuid).listen(frames.add);
    final old = driver.sessions.single;
    await cat.disconnect(uuid);
    await cat.connect(uuid);
    expect(driver.sessions.last.log, ['start']);
    old.sweep();
    await pumpEventQueue();
    expect(frames, isEmpty);
    driver.sessions.last.sweep();
    await pumpEventQueue();
    expect(frames, hasLength(1));
    await sub.cancel();
  });

  test('a stopped scope forgets its settings, and refuses a change', () async {
    final session = driver.sessions.single;
    final sub = cat.spectrumFrames(uuid).listen((_) {});
    await pumpEventQueue();
    session.running = true;
    session.sink.reportSpectrumSettings(const SpectrumSettings(spanHz: 50000));
    expect(cat.setSpectrum(uuid, const SpectrumRequest(spanHz: 25000)), isTrue);
    await sub.cancel();
    await pumpEventQueue();
    session.running = false;
    // What it was set to is not what it is: the radio's own knob moves it
    // while nothing listens.
    expect(cat.stateFor(uuid).spectrum, isNull);
    expect(cat.setSpectrum(uuid, const SpectrumRequest(spanHz: 25000)), isFalse);
  });

  test('settings and problems become state; sweeps do not', () async {
    final session = driver.sessions.single;
    var notified = 0;
    cat.addListener(() => notified++);
    session.sweep();
    expect(notified, 0, reason: 'a sweep thirty times a second would wake every listener of the station');
    session.sink.reportSpectrumSettings(const SpectrumSettings(spanHz: 50000));
    session.sink.reportSpectrumProblem('busy');
    expect((cat.stateFor(uuid).spectrum?.spanHz, cat.stateFor(uuid).spectrumProblem), (50000, 'busy'));
    session.sink.reportSpectrumProblem(null);
    expect(cat.stateFor(uuid).spectrumProblem, isNull);
  });

  // A FlexRadio's DAX IQ: the band map wants all the stream gives, the radio panel 50 kHz of it.
  test('a span the app chooses covers the widest display drawing it, and narrows when that one goes', () async {
    final scope = driver.sessions.single
      ..capabilities = const SpectrumCapabilities(spansHz: [10000, 20000, 40000, 80000], refMinDb: 0, refMaxDb: 1, refStepDb: 1, autoSpan: true)
      ..running = true;
    final drawing = cat.spectrumFrames(uuid).listen((_) {});
    addTearDown(drawing.cancel);
    final panel = Object(), map = Object();
    cat.wantSpectrumWidth(uuid, panel, 50000);
    await pumpEventQueue();
    expect(scope.spans.last, 40000, reason: 'the narrowest span covering 50 kHz, a span being half the width');
    cat.wantSpectrumWidth(uuid, map, 450000);
    await pumpEventQueue();
    expect(scope.spans.last, 80000, reason: 'wider than any, the widest');
    cat.wantSpectrumWidth(uuid, map, null);
    await pumpEventQueue();
    expect(scope.spans.last, 40000);
  });

  test("a span that is the radio's own is left to it, whatever the displays show", () async {
    final scope = driver.sessions.single
      ..capabilities = const SpectrumCapabilities(spansHz: [10000, 80000], refMinDb: 0, refMaxDb: 1, refStepDb: 1)
      ..running = true;
    final drawing = cat.spectrumFrames(uuid).listen((_) {});
    addTearDown(drawing.cancel);
    cat.wantSpectrumWidth(uuid, Object(), 450000);
    await pumpEventQueue();
    expect(scope.spans, isEmpty);
  });

  // A start re-reports the last session's settings, and the radio's report lags an ask: neither
  // says whether this session's scope was asked for the span its displays need.
  test('the span is asked again each time the scope starts, and once per change while it runs', () async {
    final scope = driver.sessions.single
      ..capabilities = const SpectrumCapabilities(spansHz: [10000, 20000, 40000, 80000], refMinDb: 0, refMaxDb: 1, refStepDb: 1, autoSpan: true)
      ..running = true;
    cat.wantSpectrumWidth(uuid, Object(), 50000);
    var drawing = cat.spectrumFrames(uuid).listen((_) {});
    await pumpEventQueue();
    expect(scope.spans, [40000]);
    final other = cat.spectrumFrames(uuid).listen((_) {});
    await pumpEventQueue();
    expect(scope.spans, [40000], reason: 'another display naming no width changes nothing');
    await other.cancel();
    await drawing.cancel();
    await pumpEventQueue();
    drawing = cat.spectrumFrames(uuid).listen((_) {});
    addTearDown(drawing.cancel);
    await pumpEventQueue();
    expect(scope.spans, [40000, 40000]);
  });
}
