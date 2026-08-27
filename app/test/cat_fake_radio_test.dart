// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The Fake Radio pairing: a rig that isn't there, for exercising everything
// above a driver on a build with no socket and no serial port.
//
// What these tests defend is the pairing's usefulness rather than a
// protocol, because there is no protocol. Three of its properties are load
// bearing and each fails silently: it must connect on EVERY platform (a fake
// borrowing the TCP transport would be absent from the one build it exists
// for), it must report every set straight back (a rig that stores and stays
// quiet looks exactly like a dead one), and it must stay in the registry
// when developer mode goes off (a filtered registry orphans a node the
// operator already configured, with its settings unreachable inside it).

import 'package:drift/native.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_core/halo_core.dart';
import 'package:ham2k_logger/i18n/strings.g.dart';
import 'package:ham2k_logger/main.dart';
import 'package:ham2k_logger/services/settings_service.dart';
import 'package:ham2k_logger/views/station_panel.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ham2k_logger/services/cat/driver.dart';
import 'package:ham2k_logger/services/cat/drivers/fake_radio_driver.dart';
import 'package:ham2k_logger/services/cat/equipment.dart';
import 'package:ham2k_logger/services/cat/equipment_registry.dart';
import 'package:ham2k_logger/services/cat/transport.dart';
import 'package:ham2k_logger/services/cat/transports/fake_transport.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final registry = EquipmentRegistry();
  final type = registry.typeFor('fake-radio')!;

  group('the catalogue entry', () {
    test('is a transceiver on a transport of its own', () {
      expect(type.category, kCategoryTransceiver);
      expect(type.transportKey, FakeTransport.transportKey);
      expect(type.driver.key, 'fake-radio');
    });

    test('connects on every platform, unlike every other socket-shaped rig', () {
      // The reason this pairing has its own transport instead of borrowing
      // TCP: the TCP stub reports false on web, so a fake built on it would
      // be filtered out of the Add dialog in the build that has no other way
      // to connect a radio at all.
      expect(type.isSupportedOnThisPlatform, isTrue);
      expect(const FakeTransport().isSupportedOnThisPlatform, isTrue);
    });

    test('is offered only under developer mode, but never removed from the registry', () {
      // Both halves matter. The flag off would put a fake rig in every
      // operator's catalogue; a registry that filtered instead would strip
      // an already-configured node of the type it resolves through the
      // moment developer mode was switched back off.
      final model = registry.modelFor('fake-radio')!;
      expect(model.developerOnly, isTrue);
      expect(registry.typeFor('fake-radio'), isNotNull);
      expect(registry.models.map((m) => m.key), contains('fake-radio'));
    });

    test('comes up somewhere plausible rather than reporting nothing', () {
      expect(type.defaultConfig['fakeFreq'], fakeRadioDefaultFreqKHz);
      expect(type.defaultConfig['fakeMode'], fakeRadioDefaultMode);
      expect(type.defaultConfig['fakePower'], fakeRadioDefaultWatts);
    });

    test('every simulation knob it offers is a key it actually reads', () {
      // A field whose key nothing reads renders, validates, saves — and
      // changes nothing, which is indistinguishable from the simulation not
      // working.
      final fieldKeys = {
        for (final e in type.configElements())
          if (e['type'] == 'field') e['key'] as String,
      };
      expect(fieldKeys, {
        'fakeConnectDelay',
        'fakeDropAfter',
        'fakeFailConnect',
        'fakeFreq',
        'fakeMode',
        'fakePower',
        'fakeReplyDelay',
      });
      expect(type.validate(type.defaultConfig), isNull,
          reason: 'the prefilled form must be submittable as it opens');
    });

    test('every numeric knob is prefilled, because a blank one is refused', () {
      // The two halves are one rule. A `number` field hands `validate` the
      // SAME null for a cleared box and for an entry no parse accepts —
      // `1.5.0`, `3-`, a lone `-`, all of which the field's `[0-9.-]`
      // formatter lets through. Accepting null would silently ignore a knob
      // the operator did set; refusing it without a prefill would make an
      // untouched form refuse to submit. This is the reachable case, not the
      // String 'abc' the form can never produce.
      for (final key in ['fakeConnectDelay', 'fakeDropAfter', 'fakeReplyDelay', 'fakePower', 'fakeFreq']) {
        expect(type.defaultConfig, contains(key), reason: '$key would open blank and refuse to submit');
        expect(type.validate({...type.defaultConfig, key: null}), isNotNull,
            reason: '$key accepts the null an unparseable entry arrives as');
      }
      expect(type.validate({...type.defaultConfig, 'fakeConnectDelay': -1}), isNotNull);
      expect(type.validate({...type.defaultConfig, 'fakeFreq': 0}), isNotNull);
      // The mode is a `text` field, so its blank really is blank — no
      // ambiguity to refuse, and the default covers it.
      expect(type.validate({...type.defaultConfig, 'fakeMode': ''}), isNull);
      // But a typo must not reach a reading: it goes through RadioService
      // onto logged QSOs and out to ADIF.
      expect(type.validate({...type.defaultConfig, 'fakeMode': 'US B'}), isNotNull);
    });

    test('a mode stored as something other than a String does not throw', () {
      // CatService does not guard createSession, so a TypeError here escapes
      // with the connection already open and its drop timer running. Config
      // is round-tripped through JSON, which is why nothing else in this
      // layer casts.
      expect(modeFromConfig(const {'fakeMode': 7200}), '7200');
      expect(modeFromConfig(const {}), fakeRadioDefaultMode);
      expect(freqFromConfig(const {'fakeFreq': '7200'}), 7200.0);
      expect(freqFromConfig(const {'fakeFreq': 'nonsense'}), isNull);
    });
  });

  group('the radio that is only ever this object', () {
    _RecordingSink sinkFor() => _RecordingSink();

    test('reports back every set, or it looks like a rig that has stopped answering', () {
      final sink = sinkFor();
      final session = const FakeRadioDriver().createSession(sink, type.driverConfig(type.defaultConfig));
      session.startUpdates();
      expect(sink.readings.last, const VfoReading(freqKHz: 7200.0, mode: 'LSB'));
      expect(sink.watts.last, 75);

      session.setFrequency(7040.5);
      expect(sink.readings.last, const VfoReading(freqKHz: 7040.5, mode: 'LSB'));

      session.setMode('CW');
      expect(sink.readings.last, const VfoReading(freqKHz: 7040.5, mode: 'CW'));

      session.setPower(100);
      expect(sink.watts.last, 100);

      // The one thing on screen that tells a fake rig from a real one: a
      // green row cycling through frequencies is exactly what a working
      // radio looks like.
      expect(sink.diagnostic, isNotNull);
      session.teardown();
    });

    test('claims to push, which is a claim Smart VFO Snap acts on', () {
      // Null is not "unknown" here: `_snapQuietPeriod` adds a polling
      // session's interval to the operator's debounce and adds nothing for a
      // pushing one. A stand-in interval would silently lengthen every snap.
      final session = const FakeRadioDriver().createSession(sinkFor(), const {});
      expect(session.expectedUpdateInterval, isNull);
      session.teardown();
    });

    test('keeps restating itself, so a rig left alone never reads as silent', () {
      // CatService marks a connected radio stale after 30s without a
      // reading. A fake rig is precisely the one an operator leaves
      // connected while checking something else on screen.
      fakeAsync((async) {
        final sink = sinkFor();
        final session = const FakeRadioDriver().createSession(sink, const {});
        session.startUpdates();
        final atStart = sink.readings.length;
        async.elapse(const Duration(seconds: 29));
        expect(sink.readings.length, greaterThan(atStart));
        expect(sink.readings.last.freqKHz, fakeRadioDefaultFreqKHz);

        // And stops the moment the session is done: a heartbeat outliving
        // its connection reports a reading for a radio that is gone.
        session.teardown();
        final atEnd = sink.readings.length;
        async.elapse(const Duration(minutes: 1));
        expect(sink.readings.length, atEnd);
      });
    });

    test('a reply delay defers the reading rather than dropping it', () {
      fakeAsync((async) {
        final sink = sinkFor();
        final session = const FakeRadioDriver().createSession(sink, {'fakeReplyDelay': 500});
        session.setFrequency(10136.0);
        expect(sink.readings, isEmpty, reason: 'the whole point of the knob is the round trip taking time');
        async.elapse(const Duration(milliseconds: 500));
        expect(sink.readings.last.freqKHz, 10136.0);
        session.teardown();
      });
    });
  });

  group('the failures it can be told to have', () {
    test('a refused connect is tagged as the equipment being unreachable', () {
      // Untagged, ErrorPolicy treats a connect failure as a bug of ours and
      // reports it — so a knob meant to exercise the silent retry loop would
      // instead exercise the crash backend.
      expect(
        () => const FakeTransport().connect({'fakeFailConnect': true}, cancel: CatCancelToken()),
        throwsA(isA<CatUnreachable>()),
      );
    });

    test('a cancelled connect gives up instead of holding the attempt open', () async {
      final cancel = CatCancelToken();
      final pending = const FakeTransport().connect({'fakeConnectDelay': 60000}, cancel: cancel);
      cancel.cancel();
      await expectLater(pending, throwsA(isA<CatCancelledException>()));
    });

    test('a drop closes the connection on its own', () {
      fakeAsync((async) {
        var closed = false;
        const FakeTransport()
            .connect({'fakeDropAfter': 5}, cancel: CatCancelToken())
            .then((connection) => connection.closed.then((_) => closed = true));
        async.elapse(const Duration(seconds: 4));
        expect(closed, isFalse);
        async.elapse(const Duration(seconds: 2));
        expect(closed, isTrue);
      });
    });
  });

  group('the developer-mode gate, as the Add dialog actually applies it', () {
    // The flag alone proves nothing: deleting the one line that reads it in
    // station_panel.dart leaves every assertion above green, and the
    // regression it hides — a fake rig in every operator's catalogue — is
    // exactly what the flag exists to prevent.
    late HaLoServices services;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      final settings = SettingsService(await SharedPreferences.getInstance());
      final db = HaLoDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      services = HaLoServices(db, settings);
    });

    /// Fixed pumps, never `pumpAndSettle`: the Add dialog runs a discovery
    /// spinner while it looks for a FlexRadio, and an animation that never
    /// ends is a settle that never arrives.
    Future<void> openAddDialog(WidgetTester tester) async {
      await tester.pumpWidget(TranslationProvider(
        child: MaterialApp(home: Scaffold(body: StationPanel(services: services))),
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.text(t.settings.station.add));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
    }

    testWidgets('offers Fake Radio once developer mode is on', (tester) async {
      await services.settings.setDeveloperMode(true);
      await openAddDialog(tester);
      expect(find.text(t.settings.station.models.fakeRadio), findsOneWidget);
    });

    testWidgets('and not otherwise, while every real radio stays', (tester) async {
      await openAddDialog(tester);
      expect(find.text(t.settings.station.models.fakeRadio), findsNothing);
      // The other half of the same assertion: a gate that filtered the whole
      // catalogue would pass the line above and be catastrophically wrong.
      expect(find.text(t.settings.station.models.rigctld), findsOneWidget);
    });
  });
}

class _RecordingSink implements EquipmentSink {
  final readings = <VfoReading>[];
  final watts = <num>[];
  String? diagnostic;

  @override
  void send(List<int> bytes) => fail('the fake radio must not put bytes on a wire');

  @override
  void report(VfoReading reading) => readings.add(reading);

  @override
  void reportPower(num w) => watts.add(w);

  @override
  void reportDiagnostic(String? note) => diagnostic = note;
}
