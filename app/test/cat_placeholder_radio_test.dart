// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The Placeholder Radio pairing: a rig that isn't there, for exercising
// everything above a driver on a build with no socket and no serial port.
//
// What these tests defend is the pairing's usefulness rather than a
// protocol, because there is no protocol. Three of its properties are load
// bearing and each fails silently: it must connect on EVERY platform (a
// placeholder borrowing the TCP transport would be absent from the one
// build it exists for), it must report every set straight back (a rig that
// stores and stays quiet looks exactly like a dead one), and it must be
// findable in the Add dialog, which is the only way an operator meets it.

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
import 'package:ham2k_logger/services/cat/drivers/cw_send_queue.dart';
import 'package:ham2k_logger/services/cat/cat_service.dart';
import 'package:ham2k_logger/services/radio_service.dart';
import 'package:ham2k_logger/services/cat/drivers/placeholder_radio_driver.dart';
import 'package:ham2k_logger/services/cat/equipment.dart';
import 'package:ham2k_logger/services/cat/equipment_registry.dart';
import 'package:ham2k_logger/services/cat/transport.dart';
import 'package:ham2k_logger/services/cat/transports/placeholder_transport.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final registry = EquipmentRegistry();
  final type = registry.typeFor('placeholder-radio')!;

  group('the catalogue entry', () {
    test('is a transceiver on a transport of its own', () {
      expect(type.category, kCategoryTransceiver);
      expect(type.transportKey, PlaceholderTransport.transportKey);
      expect(type.driver.key, 'placeholder-radio');
    });

    test('connects on every platform, unlike every other socket-shaped rig', () {
      // The reason this pairing has its own transport instead of borrowing
      // TCP: the TCP stub reports false on web, so a placeholder built on
      // it would be filtered out of the Add dialog in the build that has no
      // other way to connect a radio at all.
      expect(type.isSupportedOnThisPlatform, isTrue);
      expect(const PlaceholderTransport().isSupportedOnThisPlatform, isTrue);
    });

    test('is in the searchable catalogue, like a radio with a name on it', () {
      // Not [EquipmentModel.hiddenFromCatalog] like the generic antenna and
      // key nodes: an operator with no rig on the desk is the audience, and
      // an entry they cannot find in the Add dialog reaches none of them.
      final model = registry.modelFor('placeholder-radio')!;
      expect(model.hiddenFromCatalog, isFalse);
      expect(registry.typeFor('placeholder-radio'), isNotNull);
      expect(registry.models.map((m) => m.key), contains('placeholder-radio'));
    });

    test('comes up somewhere plausible rather than reporting nothing', () {
      expect(type.defaultConfig['placeholderFreq'], placeholderRadioDefaultFreqKHz);
      expect(type.defaultConfig['placeholderMode'], placeholderRadioDefaultMode);
      expect(type.defaultConfig['placeholderPower'], placeholderRadioDefaultWatts);
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
        'placeholderConnectDelay',
        'placeholderDropAfter',
        'placeholderFailConnect',
        'placeholderFreq',
        'placeholderMode',
        'placeholderPower',
        'placeholderReplyDelay',
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
      const numericKeys = [
        'placeholderConnectDelay',
        'placeholderDropAfter',
        'placeholderReplyDelay',
        'placeholderPower',
        'placeholderFreq',
      ];
      for (final key in numericKeys) {
        expect(type.defaultConfig, contains(key), reason: '$key would open blank and refuse to submit');
        expect(type.validate({...type.defaultConfig, key: null}), isNotNull,
            reason: '$key accepts the null an unparseable entry arrives as');
      }
      expect(type.validate({...type.defaultConfig, 'placeholderConnectDelay': -1}), isNotNull);
      expect(type.validate({...type.defaultConfig, 'placeholderFreq': 0}), isNotNull);
      // The mode is a `text` field, so its blank really is blank — no
      // ambiguity to refuse, and the default covers it.
      expect(type.validate({...type.defaultConfig, 'placeholderMode': ''}), isNull);
      // But a typo must not reach a reading: it goes through RadioService
      // onto logged QSOs and out to ADIF.
      expect(type.validate({...type.defaultConfig, 'placeholderMode': 'US B'}), isNotNull);
    });

    test('a mode stored as something other than a String does not throw', () {
      // CatService does not guard createSession, so a TypeError here escapes
      // with the connection already open and its drop timer running. Config
      // is round-tripped through JSON, which is why nothing else in this
      // layer casts.
      expect(modeFromConfig(const {'placeholderMode': 7200}), '7200');
      expect(modeFromConfig(const {}), placeholderRadioDefaultMode);
      expect(freqFromConfig(const {'placeholderFreq': '7200'}), 7200.0);
      expect(freqFromConfig(const {'placeholderFreq': 'nonsense'}), isNull);
    });
  });

  group('the radio that is only ever this object', () {
    _RecordingSink sinkFor() => _RecordingSink();

    test('reports back every set, or it looks like a rig that has stopped answering', () {
      final sink = sinkFor();
      // A transceiver's session, so the tuning half of the interface is
      // reachable — createSession answers with the connection half alone.
      final session =
          const PlaceholderRadioDriver().createSession(sink, type.driverConfig(type.defaultConfig))
              as TransceiverSession;
      session.startUpdates();
      expect(sink.readings.last, const VfoReading(freqKHz: 7200.0, mode: 'LSB'));
      expect(sink.watts.last, 75);

      session.setFrequency(7040.5);
      expect(sink.readings.last, const VfoReading(freqKHz: 7040.5, mode: 'LSB'));

      session.setMode('CW');
      expect(sink.readings.last, const VfoReading(freqKHz: 7040.5, mode: 'CW'));

      session.setPower(100);
      expect(sink.watts.last, 100);

      // What tells a placeholder rig from a real one in developer mode: a
      // green row cycling through frequencies is exactly what a working
      // radio looks like.
      expect(sink.diagnostic, isNotNull);
      session.teardown();
    });

    test('claims to push, which is a claim Smart VFO Snap acts on', () {
      // Null is not "unknown" here: `_snapQuietPeriod` adds a polling
      // session's interval to the operator's debounce and adds nothing for a
      // pushing one. A stand-in interval would silently lengthen every snap.
      final session = const PlaceholderRadioDriver().createSession(sinkFor(), const {});
      expect(session.expectedUpdateInterval, isNull);
      session.teardown();
    });

    test('keeps restating itself, so a rig left alone never reads as silent', () {
      // CatService marks a connected radio stale after 30s without a
      // reading. A placeholder rig is precisely the one an operator leaves
      // connected while checking something else on screen.
      fakeAsync((async) {
        final sink = sinkFor();
        final session = const PlaceholderRadioDriver().createSession(sink, const {});
        session.startUpdates();
        final atStart = sink.readings.length;
        async.elapse(const Duration(seconds: 29));
        expect(sink.readings.length, greaterThan(atStart));
        expect(sink.readings.last.freqKHz, placeholderRadioDefaultFreqKHz);

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
        final session =
            const PlaceholderRadioDriver().createSession(sink, {'placeholderReplyDelay': 500}) as TransceiverSession;
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
        () => const PlaceholderTransport().connect({'placeholderFailConnect': true}, cancel: CatCancelToken()),
        throwsA(isA<CatUnreachable>()),
      );
    });

    test('a cancelled connect gives up instead of holding the attempt open', () async {
      final cancel = CatCancelToken();
      final pending = const PlaceholderTransport().connect({'placeholderConnectDelay': 60000}, cancel: cancel);
      cancel.cancel();
      await expectLater(pending, throwsA(isA<CatCancelledException>()));
    });

    test('a drop closes the connection on its own', () {
      fakeAsync((async) {
        var closed = false;
        const PlaceholderTransport()
            .connect({'placeholderDropAfter': 5}, cancel: CatCancelToken())
            .then((connection) => connection.closed.then((_) => closed = true));
        async.elapse(const Duration(seconds: 4));
        expect(closed, isFalse);
        async.elapse(const Duration(seconds: 2));
        expect(closed, isTrue);
      });
    });
  });

  group('the node left behind by the rename', () {
    // This change renamed the stored key with no migration, so an operator
    // who had the old entry configured keeps a node nothing can resolve.
    // That is approved — orphaning it QUIETLY is not, and the error the app
    // shows for it is not merely a diagnostic: the Radio panel renders
    // `EquipmentState.error` as its primary text and its Semantics label, in
    // the slot a frequency belongs in.
    test('reports an unrecognized type in the operator\'s own language', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final settings = SettingsService(prefs);
      final cat = CatService(settings, radio: RadioService(prefs, writeDelay: Duration.zero));
      addTearDown(cat.dispose);

      final node = await cat.addNode(typeKey: 'fake-radio', config: const {});
      await cat.connect(node.uuid);

      final state = cat.stateFor(node.uuid);
      expect(state.status, EquipmentStatus.error);
      expect(state.error, t.settings.station.unknownType(typeKey: 'fake-radio'));
      // The raw key is what an equipment report needs, and what the operator
      // must not be handed instead of a sentence.
      expect(state.errorDetail, contains('fake-radio'));
    });
  });

  group('the Add dialog, which is where an operator actually meets it', () {
    // The registry assertions above prove nothing about what the dialog
    // shows: station_panel.dart filters the catalogue itself, so a filter
    // that dropped this entry would leave every one of them green while the
    // operator it exists for never sees it.
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

    testWidgets('offers it alongside every real radio', (tester) async {
      await openAddDialog(tester);
      // Narrowed to ONE match at a time rather than scrolled: the catalogue
      // is a lazy list only a few rows deep here, so a query matching
      // several entries pushes the last of them out of the built range and
      // the assertion fails for the fold rather than for the catalogue.
      await tester.enterText(find.byType(TextField).first, 'placeholder');
      await tester.pump();
      expect(find.text(t.settings.station.models.placeholderRadio), findsOneWidget);

      // A dialog showing nothing at all would pass the line above only by
      // accident, so one real rig, reached the same way, anchors it.
      await tester.enterText(find.byType(TextField).first, 'rigctld');
      await tester.pump();
      expect(find.text(t.settings.station.models.rigctld), findsOneWidget);
    });
  });
}

class _RecordingSink implements EquipmentSink {
  final problems = <String?>[];
  List<EquipmentChannel> channels = const [];
  final readings = <VfoReading>[];
  final watts = <num>[];
  String? diagnostic;

  @override
  void send(List<int> bytes) => fail('the placeholder radio must not put bytes on a wire');

  @override
  void report(VfoReading reading) => readings.add(reading);

  @override
  void reportPower(num w) => watts.add(w);

  @override
  void reportKeyerSpeed(int wpm) {}
  @override
  void reportCwProgress(CwSendProgress? progress) {}

  @override
  void reportDiagnostic(String? note) => diagnostic = note;
  @override
  void reportProblem(String? message) => problems.add(message);

  @override
  void reportChannels(List<EquipmentChannel> channels) => this.channels = channels;

  @override
  void reportSwitchState(List<SwitchAntenna> antennas, List<SwitchPort> ports) {}
}
