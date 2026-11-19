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

/// A sweep beyond the session's own, as a radio with more than one runs it.
class _Extra implements SpectrumScope {
  final SpectrumSink sink;
  final requests = <SpectrumRequest>[];
  bool closed = false;
  _Extra(this.sink);
  @override
  bool setSpectrum(SpectrumRequest request) {
    requests.add(request);
    return true;
  }

  @override
  void close() => closed = true;

  int? get span => requests.lastWhere((r) => r.spanHz != null).spanHz;

  void sweep(int lowHz) => sink.reportSpectrum(SpectrumFrame(lowHz: lowHz, highHz: lowHz + 1, levels: Float32List(4), floorDb: 0, ceilingDb: 1, atMillis: 0));
}

class _Scope implements TransceiverSession, MultiScopeSession {
  /// How many sweeps beyond its own the radio runs: none unless a test gives it some.
  int spare = 0;

  /// Whether those sweeps take any span, as one transformed from IQ does.
  bool anySpan = false;
  @override
  bool get scopesTakeAnySpan => anySpan;

  /// A problem each sweep says as it is opened, as a Flex pan does with no UDP socket.
  String? failOnOpen;
  final extras = <_Extra>[];
  @override
  SpectrumScope? openScope(SpectrumSink sink) {
    if (extras.where((e) => !e.closed).length >= spare) return null;
    final extra = _Extra(sink);
    extras.add(extra);
    if (failOnOpen case final message?) sink.reportSpectrumProblem(message);
    return extra;
  }

  final SpectrumSink sink;
  final log = <String>[];
  _Scope(this.sink);
  @override
  String? get spectrumUnavailable => null;
  SpectrumCapabilities capabilities = const SpectrumCapabilities(spansHz: [1], refMinDb: 0, refMaxDb: 1, refStepDb: 1);
  @override
  SpectrumCapabilities get spectrumCapabilities => capabilities;
  final spans = <int?>[];
  final centers = <int?>[];
  @override
  void startSpectrum() => log.add('start');
  @override
  void stopSpectrum() => log.add('stop');
  bool running = false;
  @override
  bool setSpectrum(SpectrumRequest request) {
    if (running) {
      spans.add(request.spanHz);
      centers.add(request.centerHz);
    }
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

  void sweep([int lowHz = 0]) =>
      sink.reportSpectrum(SpectrumFrame(lowHz: lowHz, highHz: lowHz + 1, levels: Float32List(4), floorDb: 0, ceilingDb: 1, atMillis: 0));
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

  // A band map is a secondary display: it leaves the scope to the displays that name a width, and
  // drives it itself while there is none. Unchanged in what it reads, or told nothing when one
  // arrives, it would go on widening the scope under the other display, or never take it up.
  test('a display is shown elsewhere while another names a width, and its listeners hear when one comes or goes', () async {
    final panel = Object(), map = Object();
    var notified = 0;
    cat.addListener(() => notified++);
    expect(cat.spectrumLedElsewhere(uuid, map), isFalse);
    cat.wantSpectrumWidth(uuid, map, 450000);
    expect(cat.spectrumLedElsewhere(uuid, map), isFalse, reason: 'its own width is not another display');
    cat.wantSpectrumWidth(uuid, panel, 50000);
    expect(cat.spectrumLedElsewhere(uuid, map), isTrue);
    await pumpEventQueue();
    final arrivals = notified;
    expect(arrivals, 1, reason: 'two displays arriving at once, as a dock rebuild brings them, told once');
    cat.wantSpectrumWidth(uuid, panel, 40000);
    await pumpEventQueue();
    expect(notified, arrivals, reason: 'a zoom changes no display there is, and comes several times a second');
    cat.wantSpectrumWidth(uuid, panel, null);
    expect(cat.spectrumLedElsewhere(uuid, map), isFalse);
    await pumpEventQueue();
    expect(notified, greaterThan(arrivals));
  });

  // Left to a display that cannot move the scope, a band map would see the sweep stay where it
  // started; left to another band map, the second to open would draw only what the first asks.
  test('only a display that may move the scope leads it: band maps share it, at the widest of them', () async {
    final scope = driver.sessions.single
      ..capabilities = const SpectrumCapabilities(spansHz: [10000, 20000, 40000, 80000], refMinDb: 0, refMaxDb: 1, refStepDb: 1, autoSpan: true)
      ..running = true;
    final drawing = cat.spectrumFrames(uuid).listen((_) {});
    addTearDown(drawing.cancel);
    final viewer = Object(), mapA = Object(), mapB = Object();
    CatSpectrumSource(cat).showWidth(uuid, viewer, 20000);
    expect(cat.spectrumLedElsewhere(uuid, mapA), isFalse, reason: 'a panel that may not command the radio moves nothing');
    final commanding = CatSpectrumSource(cat, canCommand: true);
    commanding.showWidth(uuid, mapA, 30000, secondary: true);
    commanding.showWidth(uuid, mapB, 150000, secondary: true);
    expect([cat.spectrumLedElsewhere(uuid, mapA), cat.spectrumLedElsewhere(uuid, mapB)], [false, false]);
    await pumpEventQueue();
    expect(scope.spans.last, 80000, reason: 'the scope run for the wider map');
    commanding.showWidth(uuid, Object(), 20000);
    expect([cat.spectrumLedElsewhere(uuid, mapA), cat.spectrumLedElsewhere(uuid, mapB)], [true, true]);
  });

  // Nothing says what a display that names no width wants, so it gets what is there.
  test('with no display naming a width, the span stays where it was', () async {
    final scope = driver.sessions.single
      ..capabilities = const SpectrumCapabilities(spansHz: [10000, 20000, 40000, 80000], refMinDb: 0, refMaxDb: 1, refStepDb: 1, autoSpan: true)
      ..running = true;
    final drawing = cat.spectrumFrames(uuid).listen((_) {});
    addTearDown(drawing.cancel);
    final map = Object();
    cat.wantSpectrumWidth(uuid, map, 450000);
    await pumpEventQueue();
    cat.wantSpectrumWidth(uuid, map, null);
    cat.wantSpectrumWidth(uuid, Object(), 0);
    await pumpEventQueue();
    expect(scope.spans, [80000], reason: 'a display drawing the whole sweep names no width either');
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

  test("a radio's own span, fitted by a zoom, covers the widest display drawing it", () async {
    final scope = driver.sessions.single
      ..capabilities = const SpectrumCapabilities(spansHz: [10000, 20000, 40000, 80000], refMinDb: 0, refMaxDb: 1, refStepDb: 1)
      ..running = true;
    final drawing = cat.spectrumFrames(uuid).listen((_) {});
    addTearDown(drawing.cancel);
    final source = CatSpectrumSource(cat, canCommand: true);
    final panel = Object(), map = Object();
    cat.wantSpectrumWidth(uuid, panel, 30000);
    expect(source.fitSpan(uuid, 30000), isTrue);
    expect(scope.spans.last, 20000, reason: 'the narrowest span covering 30 kHz');
    cat.wantSpectrumWidth(uuid, map, 150000);
    source.fitSpan(uuid, 30000);
    expect(scope.spans.last, 80000, reason: "one display's zoom in must not cut off another's wider window");
    expect(CatSpectrumSource(cat).fitSpan(uuid, 30000), isFalse, reason: 'only a panel that may command the radio changes its screen');
  });

  test("a display drawing the radio's whole sweep holds its span where it is; a fixed scope's is left alone", () async {
    final scope = driver.sessions.single
      ..capabilities = const SpectrumCapabilities(spansHz: [10000, 20000, 40000, 80000], refMinDb: 0, refMaxDb: 1, refStepDb: 1)
      ..running = true;
    final drawing = cat.spectrumFrames(uuid).listen((_) {});
    addTearDown(drawing.cancel);
    final source = CatSpectrumSource(cat, canCommand: true);
    scope.sink.reportSpectrumSettings(const SpectrumSettings(spanHz: 40000));
    cat.wantSpectrumWidth(uuid, Object(), 0);
    source.fitSpan(uuid, 30000);
    expect(scope.spans.last, 40000, reason: 'a zoom in on one display would cut the other down to its window');
    source.fitSpan(uuid, 150000);
    expect(scope.spans.last, 80000, reason: 'it holds the span from narrowing, never from widening');

    scope.sink.reportSpectrumSettings(const SpectrumSettings(mode: SpectrumMode.fixed, spanHz: 40000));
    scope.spans.clear();
    expect(source.fitSpan(uuid, 150000), isFalse);
    expect(scope.spans, isEmpty, reason: "a fixed scope's width is its edges: a span set rewrites only centre mode's");

    // A scope that moves its fixed window but keeps its own width — an SDR tuned on its own — is left
    // be: a span there would change its sample rate and retune it.
    scope.capabilities = const SpectrumCapabilities(spansHz: [10000, 20000, 40000, 80000], refMinDb: 0, refMaxDb: 1, refStepDb: 1, canRecenter: true);
    expect(source.fitSpan(uuid, 30000), isFalse);
    expect(source.minWidthHz(uuid), isNull);

    // Where the app places the edges itself, a span is their width, and a display drawing the
    // whole sweep holds them as far apart as they are — not as centre mode's span last had them.
    scope.capabilities = const SpectrumCapabilities(
      spansHz: [10000, 20000, 40000, 80000],
      refMinDb: 0,
      refMaxDb: 1,
      refStepDb: 1,
      canRecenter: true,
      spanSetsEdges: true,
    );
    scope.sink.reportSpectrumSettings(const SpectrumSettings(mode: SpectrumMode.fixed, lowHz: 14000000, highHz: 14060000));
    expect(source.fitSpan(uuid, 30000), isTrue);
    expect(scope.spans.last, 40000);
  });

  test('a zoom that ends off to one side moves edges the app places to the window, and widens one centred where it is', () async {
    final scope = driver.sessions.single
      ..capabilities = const SpectrumCapabilities(
        spansHz: [10000, 20000, 40000, 80000],
        refMinDb: 0,
        refMaxDb: 1,
        refStepDb: 1,
        canRecenter: true,
        spanSetsEdges: true,
      )
      ..running = true;
    final drawing = cat.spectrumFrames(uuid).listen((_) {});
    addTearDown(drawing.cancel);
    final source = CatSpectrumSource(cat, canCommand: true);
    // A 10 kHz window by the dial, 60 kHz from the middle of a 160 kHz sweep.
    cat.wantSpectrumWidth(uuid, Object(), 10000);
    scope.sink.reportSpectrumSettings(const SpectrumSettings(mode: SpectrumMode.fixed, lowHz: 7000000, highHz: 7160000));
    expect(source.fitSpan(uuid, 10000, centerHz: 7140000, offCenterHz: 60000), isTrue);
    expect((scope.spans.last, scope.centers.last), (10000, 7140000), reason: 'covering the window from the sweep\'s middle, it would never narrow');
    scope.sink.reportSpectrumSettings(const SpectrumSettings(mode: SpectrumMode.center, spanHz: 80000));
    expect(source.fitSpan(uuid, 10000, centerHz: 7140000, offCenterHz: 60000), isTrue);
    expect((scope.spans.last, scope.centers.last), (80000, null), reason: 'narrowed about the dial, the window would fall off its side');
  });

  test('a zoom may go as narrow as the narrowest sweep the panel can have the scope send', () async {
    driver.sessions.single
      ..capabilities = const SpectrumCapabilities(spansHz: [10000, 20000, 40000, 80000], refMinDb: 0, refMaxDb: 1, refStepDb: 1)
      ..running = true;
    final drawing = cat.spectrumFrames(uuid).listen((_) {});
    addTearDown(drawing.cancel);
    final source = CatSpectrumSource(cat, canCommand: true);
    expect(source.minWidthHz(uuid), 20000);
    expect(CatSpectrumSource(cat).minWidthHz(uuid), isNull, reason: 'a panel that may not command the radio cannot narrow it');
    // A fixed scope's width is its edges, which no span narrows.
    driver.sessions.single.sink.reportSpectrumSettings(const SpectrumSettings(mode: SpectrumMode.fixed, spanHz: 40000));
    expect(source.minWidthHz(uuid), isNull);
  });

  group('several sweeps', () {
    const spans = SpectrumCapabilities(spansHz: [10000, 20000, 40000, 80000], refMinDb: 0, refMaxDb: 1, refStepDb: 1, autoSpan: true);

    // Cropped from the widest, a 20 kHz panel beside a 160 kHz map shows an eighth of its points.
    test('a display at a narrower span draws a sweep of its own, at its span, where the radio has one to spare', () async {
      final scope = driver.sessions.single
        ..capabilities = spans
        ..running = true
        ..spare = 1;
      final panel = Object(), map = Object();
      final panelSweeps = <int>[], mapSweeps = <int>[];
      final a = cat.spectrumFrames(uuid, owner: panel).listen((f) => panelSweeps.add(f.lowHz));
      final b = cat.spectrumFrames(uuid, owner: map).listen((f) => mapSweeps.add(f.lowHz));
      addTearDown(a.cancel);
      addTearDown(b.cancel);
      cat.wantSpectrumWidth(uuid, panel, 20000);
      cat.wantSpectrumWidth(uuid, map, 160000);
      await pumpEventQueue();
      expect(scope.spans.last, 80000, reason: "the session's own runs at the widest");
      expect(scope.extras.single.span, 10000, reason: 'the other at the narrowest covering the panel');
      scope.sweep(1);
      scope.extras.single.sweep(2);
      await pumpEventQueue();
      expect(
        [panelSweeps, mapSweeps],
        [
          [2],
          [1],
        ],
        reason: 'each display draws only its own sweep',
      );
    });

    // A band map alone holds the scope at its width, and gives it way when a display arrives: told
    // after the scope is sized, the radio would run the map's width a moment longer, and open a
    // sweep for the new display beside it, both undone at once.
    test('a secondary display gives the scope back before it is sized for the display that arrives', () async {
      final scope = driver.sessions.single
        ..capabilities = spans
        ..running = true
        ..spare = 1;
      final panel = Object(), map = Object();
      final drawing = cat.spectrumFrames(uuid, owner: map).listen((_) {});
      addTearDown(drawing.cancel);
      cat.addListener(() {
        if (cat.spectrumLedElsewhere(uuid, map)) cat.wantSpectrumWidth(uuid, map, null);
      });
      cat.wantSpectrumWidth(uuid, map, 160000, leads: false);
      await pumpEventQueue();
      expect(scope.spans.last, 80000);
      cat.wantSpectrumWidth(uuid, panel, 20000);
      await pumpEventQueue();
      expect(scope.extras, isEmpty, reason: 'no sweep opened for a width the map had already given back');
      expect(scope.spans.last, 10000);
    });

    // A band map and a radio panel mounted in one frame, the map first: the map's own demand is
    // already queued when the panel arrives, and run before the map hears to give way, it would size
    // the scope for the map and open a sweep for the panel beside it.
    test('a demand already queued waits for a secondary display to give way to the display arriving with it', () async {
      final scope = driver.sessions.single
        ..capabilities = spans
        ..running = true
        ..spare = 1;
      final panel = Object(), map = Object();
      cat.addListener(() {
        if (cat.spectrumLedElsewhere(uuid, map)) cat.wantSpectrumWidth(uuid, map, null);
      });
      final drawing = cat.spectrumFrames(uuid, owner: map).listen((_) {});
      addTearDown(drawing.cancel);
      cat.wantSpectrumWidth(uuid, map, 160000, leads: false);
      cat.wantSpectrumWidth(uuid, panel, 20000);
      await pumpEventQueue();
      expect(scope.extras, isEmpty);
      expect(scope.spans, isNot(contains(80000)), reason: "never sized for the map's width");
      expect(scope.spans.last, 10000);
    });

    // Each sweep is a pan of the radio's or a transform of every IQ sample: five panes at five
    // spans would run five, where the narrowest two crop well enough what the next one shows.
    test('no more than three sweeps run beyond the widest, the narrowest displays cropping the narrowest of them', () async {
      final scope = driver.sessions.single
        ..capabilities = const SpectrumCapabilities(spansHz: [5000, 10000, 20000, 40000, 80000], refMinDb: 0, refMaxDb: 1, refStepDb: 1, autoSpan: true)
        ..running = true
        ..spare = 5;
      final drawing = cat.spectrumFrames(uuid).listen((_) {});
      addTearDown(drawing.cancel);
      final narrowest = Object(), drawn = <int>[];
      final draws = cat.spectrumFrames(uuid, owner: narrowest).listen((f) => drawn.add(f.lowHz));
      addTearDown(draws.cancel);
      for (final width in [160000, 80000, 40000, 20000]) {
        cat.wantSpectrumWidth(uuid, Object(), width);
      }
      cat.wantSpectrumWidth(uuid, narrowest, 10000);
      await pumpEventQueue();
      expect(scope.spans.last, 80000);
      expect([for (final extra in scope.extras) extra.span], [40000, 20000, 10000]);
      for (final (i, extra) in scope.extras.indexed) {
        extra.sweep(i + 1);
      }
      await pumpEventQueue();
      expect(drawn, [3], reason: 'the narrowest sweep that covers it');
    });

    // Rounded up to the IQ rate's spans, a 24 kHz panel's own sweep would be 40 kHz wide, and the
    // panel would crop half its points away.
    test("a sweep transformed from IQ is given the display's own width, the session's still a span it has", () async {
      final scope = driver.sessions.single
        ..capabilities = spans
        ..running = true
        ..spare = 1
        ..anySpan = true;
      final drawing = cat.spectrumFrames(uuid).listen((_) {});
      addTearDown(drawing.cancel);
      cat.wantSpectrumWidth(uuid, Object(), 150000);
      cat.wantSpectrumWidth(uuid, Object(), 24000);
      await pumpEventQueue();
      expect(scope.spans.last, 80000);
      expect(scope.extras.single.span, 12000);
    });

    test('with no sweep to spare, a narrower display crops the widest', () async {
      final scope = driver.sessions.single
        ..capabilities = spans
        ..running = true;
      final panel = Object();
      final panelSweeps = <int>[];
      final a = cat.spectrumFrames(uuid, owner: panel).listen((f) => panelSweeps.add(f.lowHz));
      addTearDown(a.cancel);
      cat.wantSpectrumWidth(uuid, panel, 20000);
      cat.wantSpectrumWidth(uuid, Object(), 160000);
      await pumpEventQueue();
      scope.sweep(1);
      await pumpEventQueue();
      expect(panelSweeps, [1]);
    });

    // A zoom drag passes through every span on its way; on a Flex each sweep is a panadapter.
    test("a display's sweep follows its zoom without being closed and opened again, and closes when the display goes", () async {
      final scope = driver.sessions.single
        ..capabilities = spans
        ..running = true
        ..spare = 1;
      final drawing = cat.spectrumFrames(uuid).listen((_) {});
      addTearDown(drawing.cancel);
      final panel = Object();
      cat.wantSpectrumWidth(uuid, Object(), 160000);
      for (final width in [20000, 40000, 80000]) {
        cat.wantSpectrumWidth(uuid, panel, width);
        await pumpEventQueue();
      }
      expect(scope.extras, hasLength(1));
      expect([for (final r in scope.extras.single.requests) r.spanHz], [10000, 20000, 40000]);
      cat.wantSpectrumWidth(uuid, panel, null);
      await pumpEventQueue();
      expect(scope.extras.single.closed, isTrue);
    });

    test('a sweep the radio turns down is closed, its display crops the widest, and none is asked again until the scope restarts', () async {
      final scope = driver.sessions.single
        ..capabilities = spans
        ..running = true
        ..spare = 2;
      final panel = Object();
      final panelSweeps = <int>[];
      var a = cat.spectrumFrames(uuid, owner: panel).listen((f) => panelSweeps.add(f.lowHz));
      cat.wantSpectrumWidth(uuid, panel, 20000);
      cat.wantSpectrumWidth(uuid, Object(), 160000);
      await pumpEventQueue();
      scope.extras.single.sink.reportSpectrumProblem('no pan free');
      await pumpEventQueue();
      expect(scope.extras.single.closed, isTrue);
      scope.sweep(1);
      await pumpEventQueue();
      expect(panelSweeps, [1]);
      cat.wantSpectrumWidth(uuid, panel, 40000);
      await pumpEventQueue();
      expect(scope.extras, hasLength(1), reason: 'opening another would only be turned down again');

      await a.cancel();
      await pumpEventQueue();
      a = cat.spectrumFrames(uuid, owner: panel).listen((_) {});
      addTearDown(a.cancel);
      await pumpEventQueue();
      expect(scope.extras, hasLength(2), reason: 'a restarted scope asks again: the pan may be free by now');
    });

    test("a display's recentre moves its own sweep; an extension's speed reaches every sweep", () async {
      final scope = driver.sessions.single
        ..capabilities = spans
        ..running = true
        ..spare = 1;
      final drawing = cat.spectrumFrames(uuid).listen((_) {});
      addTearDown(drawing.cancel);
      final panel = Object(), map = Object();
      cat.wantSpectrumWidth(uuid, panel, 20000);
      cat.wantSpectrumWidth(uuid, map, 160000);
      await pumpEventQueue();
      cat.setSpectrum(uuid, const SpectrumRequest(centerHz: 14070000), owner: panel);
      expect(scope.extras.single.requests.last.centerHz, 14070000);
      expect(scope.centers.whereType<int>(), isEmpty, reason: "the map's sweep stays where it is");
      // What the radio says it took, not what was asked: a speed it refused is not the receiver's look.
      scope.sink.reportSpectrumSettings(const SpectrumSettings(speed: SpectrumSpeed.fast, refLevelDb: 6));
      expect((scope.extras.single.requests.last.speed, scope.extras.single.requests.last.refLevelDb), (SpectrumSpeed.fast, 6));
    });

    test('a sweep opened later starts at the speed and reference level the others run at', () async {
      final scope = driver.sessions.single
        ..capabilities = spans
        ..running = true
        ..spare = 1;
      final drawing = cat.spectrumFrames(uuid).listen((_) {});
      addTearDown(drawing.cancel);
      scope.sink.reportSpectrumSettings(const SpectrumSettings(speed: SpectrumSpeed.slow, refLevelDb: -3));
      cat.wantSpectrumWidth(uuid, Object(), 20000);
      cat.wantSpectrumWidth(uuid, Object(), 160000);
      await pumpEventQueue();
      final asked = scope.extras.single.requests.where((r) => r.speed != null);
      expect([for (final r in asked) (r.speed, r.refLevelDb)], [(SpectrumSpeed.slow, -3.0)]);
    });

    test('a sweep that says a problem while it is being opened is closed, not kept drawing nothing', () async {
      final scope = driver.sessions.single
        ..capabilities = spans
        ..running = true
        ..spare = 1
        ..failOnOpen = 'no UDP';
      final drawing = cat.spectrumFrames(uuid).listen((_) {});
      addTearDown(drawing.cancel);
      cat.wantSpectrumWidth(uuid, Object(), 20000);
      cat.wantSpectrumWidth(uuid, Object(), 160000);
      await pumpEventQueue();
      expect(scope.extras.single.closed, isTrue);
    });
  });
}
