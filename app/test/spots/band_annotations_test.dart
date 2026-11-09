// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// What is said about the bands, as the panels read it: the hooks asked once
// per band and station, in the background, since a panel render that waited
// on another extension would stall the runtime it runs in; what extensions
// put, each under its own key and no other's; and none of it outliving the
// runtime that said it, but the operator's own band tags.

import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter/foundation.dart' show ValueNotifier;
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_core/halo_core.dart';
import 'package:halo_extension_host/halo_extension_host.dart' show ExtensionHostException;
import 'package:ham2k_logger/services/band_annotations_service.dart';
import 'package:ham2k_logger/services/extensions/extension_service.dart' show ExtensionService;
import 'package:ham2k_logger/services/spots_service.dart';

import '../support/fake_clock.dart';
import '../support/halo_test_support.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<({List<Map<String, dynamic>> items, List<String> succeeded, List<String> unreachable, List<String> failed})> noSpots() async =>
      (items: const <Map<String, dynamic>>[], succeeded: const <String>[], unreachable: const <String>[], failed: const <String>[]);

  /// The service as the app wires it, its hooks answering with [answer].
  (ExtensionServiceWithFakeHost, SpotsService, List<Object?>) harness(Object? Function(Object? args) answer) {
    final asked = <Object?>[];
    final extensions = ExtensionServiceWithFakeHost(
      FakeExtensionHost({
        'bandAnnotations:*:annotationsFor': (Object? args) {
          asked.add(args);
          return answer(args);
        },
      }),
    );
    final spots = SpotsService(fetchSpots: noSpots, bandAnnotations: extensions.bandAnnotations);
    extensions.spots = spots;
    addTearDown(spots.dispose);
    addTearDown(extensions.bandAnnotations.dispose);
    return (extensions, spots, asked);
  }

  Map<String, dynamic> from(String ns, Map<String, dynamic> rest) => {'ns': ns, 'extensionKey': ns, ...rest};

  group('the hooks', () {
    test('are asked once per band and station, in the background, their answers on the band asked about', () async {
      final (_, spots, asked) = harness(
        (_) => [
          {
            'key': 'band-plan',
            'ok': true,
            'value': [
              {'type': 'edge', 'fromHz': 14000000, 'toHz': 14350000},
              // On the band it was asked about, wherever its frequency.
              {'type': 'known', 'fromHz': 7074000, 'label': 'FT8'},
              // Malformed: left out, the rest standing.
              {'type': 'nonsense', 'fromHz': 14100000},
            ],
          },
        ],
      );
      var heard = 0;
      spots.bandAnnotations.addListener(() => heard++);

      expect(spots.bandAnnotations.forBand('20m', station: 'K1AA'), isEmpty, reason: 'the first read answers at once');
      await pumpEventQueue();
      expect(heard, 1);
      final said = spots.bandAnnotations.forBand('20m', station: 'K1AA');
      expect(said.map((a) => (a['type'], a['band'], a['source'])), [('edge', '20m', 'band-plan'), ('known', '20m', 'band-plan')]);
      expect(asked, [
        {'band': '20m', 'station': 'K1AA'},
      ]);

      // Another station is another plan.
      spots.bandAnnotations.forBand('20m', station: 'DL1AA');
      spots.bandAnnotations.forBand('20m', station: 'DL1AA');
      await pumpEventQueue();
      expect(asked, hasLength(2));
    });

    test('an answer from a runtime since replaced is not kept', () async {
      final answers = <Completer<BandAnnotationsAnswer>>[];
      final service = BandAnnotationsService(fetch: ({required band, station}) => (answers..add(Completer())).last.future);
      addTearDown(service.dispose);
      service.forBand('20m');
      service.forgetExtensions();
      answers.first.complete((
        items: [
          {'type': 'edge', 'fromHz': 14000000, 'toHz': 14350000, 'band': '20m', 'source': 'gone'},
        ],
        complete: true,
      ));
      await pumpEventQueue();
      // Kept, it would stand for the band until the app restarts: the band is never asked again.
      expect(service.forBand('20m').where((a) => a['source'] == 'gone'), isEmpty);
      expect(answers, hasLength(2), reason: 'the band is asked again, of the runtime now running');
    });

    test('an answer short of a hook is asked again a while later, on its own, but not on every read', () {
      followFakeClock();
      fakeAsync((async) {
        var asked = 0;
        final service = BandAnnotationsService(
          fetch: ({required band, station}) async => (
            items: [
              if (asked++ > 0) {'type': 'edge', 'fromHz': 14000000, 'toHz': 14350000, 'band': '20m', 'source': 'band-plan'},
            ],
            // The first time, the plan missed its time on a busy boot.
            complete: asked > 1,
          ),
        );
        var heard = 0;
        service.addListener(() => heard++);
        service.forBand('20m');
        async.flushMicrotasks();
        service.forBand('20m');
        async.flushMicrotasks();
        expect(asked, 1, reason: 'a panel repainting each tick must not ask a struggling hook each time');
        // Kept for good, a plan that missed its time once would be gone until the runtime restarts;
        // asked only on a read, it would wait for something else to repaint the scope.
        async.elapse(BandAnnotationsService.askAgainAfter);
        expect(heard, 1, reason: 'the panels hear the plan come in with nothing else moving');
        expect(service.forBand('20m').map((a) => a['source']), ['band-plan']);
        async.elapse(BandAnnotationsService.askAgainAfter * 2);
        service.forBand('20m');
        async.flushMicrotasks();
        expect(asked, 2, reason: 'a whole answer is the band\'s for the runtime');
        service.dispose();
      });
    });

    test('a band asked before the hooks are all in place is asked again as they settle, not a while later', () {
      followFakeClock();
      fakeAsync((async) {
        final settled = ValueNotifier(0);
        var asked = 0;
        var whole = false;
        final service = BandAnnotationsService(
          fetch: ({required band, station}) async {
            asked++;
            return (
              items: [
                if (whole) {'type': 'edge', 'fromHz': 14000000, 'toHz': 14350000, 'band': '20m', 'source': 'band-plan'},
              ],
              complete: whole,
            );
          },
          hooksSettled: settled,
        );
        // An operation opening at launch asks ahead of the runtime activating the plan's extension;
        // asked again only askAgainAfter later, its scope would draw no plan for that long.
        service.forBand('20m', station: 'K1AA');
        async.flushMicrotasks();
        whole = true;
        settled.value++;
        async.flushMicrotasks();
        expect(asked, 2);
        expect(service.forBand('20m', station: 'K1AA').map((a) => a['source']), ['band-plan']);
        // A whole answer is not asked again whenever a runtime settles; one replaced forgets it instead.
        settled.value++;
        async.elapse(BandAnnotationsService.askAgainAfter);
        expect(asked, 2);
        service.dispose();
        settled.dispose();
      });
    });

    test('one band and station asked however they are written are one question', () async {
      var asked = 0;
      final service = BandAnnotationsService(
        fetch: ({required band, station}) async {
          asked++;
          expect((band, station), ('20m', 'K1AA'));
          return (items: const <Map<String, dynamic>>[], complete: true);
        },
      );
      addTearDown(service.dispose);
      // The operation view asks with the station as the operation has it; the Band Scope's read
      // comes through the host call. Written apart, the scope would ask again on its first frame.
      service.forBand('20M', station: ' k1aa ');
      await pumpEventQueue();
      service.forBand('20m', station: 'K1AA');
      await pumpEventQueue();
      expect(asked, 1);
    });

    test('an answer already expired as it is given is not drawn, and does not set the band asking without end', () {
      followFakeClock();
      fakeAsync((async) {
        var asked = 0;
        final service = BandAnnotationsService(
          fetch: ({required band, station}) async {
            asked++;
            return (
              items: [
                {'type': 'general', 'fromHz': 14300000, 'band': '20m', 'source': 'nets', 'label': 'Net until 20:00', 'expiresAt': nowMillis() - 1},
              ],
              complete: true,
            );
          },
        );
        service.forBand('20m');
        async.elapse(const Duration(seconds: 5));
        expect(service.forBand('20m'), isEmpty);
        expect(asked, 1);
        service.dispose();
      });
    });

    test('one extension reloaded alone loses what it put and the hooks are asked again; the rest stay', () async {
      final asked = <String>[];
      final service = BandAnnotationsService(
        fetch: ({required band, station}) async {
          asked.add(band);
          return (items: const <Map<String, dynamic>>[], complete: true);
        },
      );
      addTearDown(service.dispose);
      service
        ..put('nets', [
          {'type': 'general', 'fromHz': 14300000, 'label': 'Old'},
        ])
        ..put('other', [
          {'type': 'general', 'fromHz': 14310000, 'label': 'Theirs'},
        ])
        ..put(userBandAnnotationSource, [
          {'type': 'general', 'fromHz': 14320000, 'label': 'QRM'},
        ]);
      service.forBand('20m');
      await pumpEventQueue();
      service.forgetExtensions(['nets', userBandAnnotationSource]);
      expect(service.forBand('20m').map((a) => a['label']), ['Theirs', 'QRM']);
      await pumpEventQueue();
      expect(asked, ['20m', '20m'], reason: 'its hook\'s old answer must not stand for its new code');
    });

    test('with no hook to answer, the band waits for one, with no timer, and is asked as the hooks settle', () async {
      expect(await ExtensionService().getBandAnnotations(band: '20m'), isNull);
      followFakeClock();
      fakeAsync((async) {
        final settled = ValueNotifier(0);
        var asked = 0;
        final service = BandAnnotationsService(
          fetch: ({required band, station}) async => asked++ == 0
              ? null
              : (
                  items: [
                    {'type': 'edge', 'fromHz': 14000000, 'toHz': 14350000, 'band': '20m', 'source': 'band-plan'},
                  ],
                  complete: true,
                ),
          hooksSettled: settled,
        );
        // An operation opened before the runtime starts, or before its plan extension activates,
        // asks then. Kept as a whole answer, the band
        // would keep "nothing" for the runtime's whole life; asked again on a timer, the timer would
        // outlive a view that never sees a runtime at all.
        service.forBand('20m');
        async.flushMicrotasks();
        expect(async.pendingTimers, isEmpty);
        service.forBand('20m');
        async.flushMicrotasks();
        expect(asked, 1, reason: 'a panel repainting before the runtime is up does not ask each time');
        settled.value++;
        async.flushMicrotasks();
        expect(service.forBand('20m').map((a) => a['source']), ['band-plan']);
        service.dispose();
        settled.dispose();
      });
    });

    test("a hook's answer that expires is taken down then, and the band asked again", () {
      followFakeClock();
      fakeAsync((async) {
        var asked = 0;
        final service = BandAnnotationsService(
          fetch: ({required band, station}) async {
            asked++;
            return (
              items: [
                {'type': 'general', 'fromHz': 14300000, 'band': '20m', 'source': 'nets', 'label': 'Net $asked', 'expiresAt': nowMillis() + 60000},
              ],
              complete: true,
            );
          },
        );
        var heard = 0;
        service.addListener(() => heard++);
        service.forBand('20m');
        async.flushMicrotasks();
        expect(heard, 1);
        async.elapse(const Duration(minutes: 1));
        // Asked again as it expires, not at the next read, which a still dial may not make for minutes.
        expect(heard, 3, reason: 'once as it is taken down, once as what the hook says next comes in');
        expect(service.forBand('20m').map((a) => a['label']), ['Net 2'], reason: 'what the hook says next is the band\'s now');
        service.dispose();
      });
    });
  });

  group('put by extensions', () {
    test('each under its own key, a key put again replacing it, and taken by key or all at once', () async {
      final (extensions, spots, _) = harness((_) => const []);
      Future<dynamic> call(String method, String ns, Map<String, dynamic> rest) => extensions.debugHandleHostCall(method, from(ns, rest));

      await call('putBandAnnotations', 'nets', {
        'annotations': [
          {'type': 'general', 'key': 'a', 'fromHz': 14300000, 'label': 'Net'},
          {'type': 'general', 'key': 'b', 'fromHz': 14310000, 'label': 'Other', 'color': '#00FF00'},
        ],
      });
      await call('putBandAnnotations', 'nets', {
        'annotations': [
          {'type': 'general', 'key': 'a', 'fromHz': 14305000, 'label': 'Net moved'},
        ],
      });
      List<String?> labels() => [
        for (final a in spots.bandAnnotations.forBand('20m'))
          if (a['source'] == 'nets') a['label'] as String?,
      ];
      expect(labels(), ['Net moved', 'Other']);

      final read = await extensions.debugHandleHostCall('getBandAnnotations', {'band': '20M', 'extensionKey': 'x'}) as List;
      expect(read.map((a) => (a as Map)['label']), containsAll(['Net moved', 'Other']));

      await call('removeBandAnnotations', 'nets', {
        'keys': ['a'],
      });
      expect(labels(), ['Other']);
      await call('putBandAnnotations', 'other', {
        'annotations': [
          {'type': 'general', 'fromHz': 14320000, 'label': 'Theirs'},
        ],
      });
      // One extension's remove takes only its own.
      await call('removeBandAnnotations', 'nets', {});
      expect(labels(), isEmpty);
      expect(spots.bandAnnotations.forBand('20m').map((a) => a['label']), ['Theirs']);
    });

    test('one put as the runtime comes up, before the services are wired, is kept', () async {
      // The runtime starts before the services exist, so `onActivation` puts land first.
      final extensions = ExtensionServiceWithFakeHost(FakeExtensionHost({}));
      addTearDown(extensions.bandAnnotations.dispose);
      await extensions.debugHandleHostCall(
        'putBandAnnotations',
        from('nets', {
          'annotations': [
            {'type': 'general', 'fromHz': 14300000, 'label': 'Net'},
          ],
        }),
      );
      final spots = SpotsService(fetchSpots: noSpots, bandAnnotations: extensions.bandAnnotations);
      addTearDown(spots.dispose);
      extensions.spots = spots;
      expect(spots.bandAnnotations.forBand('20m').map((a) => a['label']), ['Net']);
    });

    test("one malformed puts none, and no extension writes as the operator", () async {
      final (extensions, spots, _) = harness((_) => const []);
      await expectLater(
        extensions.debugHandleHostCall(
          'putBandAnnotations',
          from('a', {
            'annotations': [
              {'type': 'general', 'fromHz': 14300000},
              {'type': 'general', 'fromHz': 14300000, 'shade': 'blue'},
            ],
          }),
        ),
        throwsFormatException,
      );
      expect(spots.bandAnnotations.forBand('20m'), isEmpty);
      await expectLater(
        extensions.debugHandleHostCall(
          'putBandAnnotations',
          from(userBandAnnotationSource, {
            'annotations': [
              {'type': 'general', 'fromHz': 14300000},
            ],
          }),
        ),
        throwsA(isA<ExtensionHostException>()),
      );
      await expectLater(extensions.debugHandleHostCall('removeBandAnnotations', from(userBandAnnotationSource, {})), throwsA(isA<ExtensionHostException>()));
    });

    test("an extension takes the operator's band tags only by key, and only theirs", () async {
      final (extensions, spots, _) = harness((_) => const []);
      spots.bandAnnotations.put(userBandAnnotationSource, [
        {'type': 'general', 'key': 'qrm', 'fromHz': 14200000, 'label': 'QRM!'},
        {'type': 'general', 'key': 'net', 'fromHz': 14300000, 'label': 'NET!'},
      ]);
      spots.bandAnnotations.put('nets', [
        {'type': 'general', 'key': 'qrm', 'fromHz': 14250000, 'label': 'Theirs'},
      ]);
      Future<dynamic> remove(Map<String, dynamic> rest) => extensions.debugHandleHostCall('removeBandAnnotations', from('map', rest));
      await remove({
        'keys': ['qrm'],
        'source': 'user',
      });
      expect(spots.bandAnnotations.forBand('20m').map((a) => a['label']), unorderedEquals(['NET!', 'Theirs']));
      // Never all of them at once, and never another extension's.
      await expectLater(remove({'source': 'user'}), throwsFormatException);
      await expectLater(remove({'keys': <String>[], 'source': 'user'}), throwsFormatException);
      await expectLater(
        remove({
          'keys': ['qrm'],
          'source': 'nets',
        }),
        throwsFormatException,
      );
      expect(spots.bandAnnotations.forBand('20m').map((a) => a['label']), unorderedEquals(['NET!', 'Theirs']));
    });

    test('none outlives the runtime that put it, but the operator\'s band tags stay', () async {
      final (_, spots, _) = harness((_) => const []);
      spots.bandAnnotations.put('nets', [
        {'type': 'general', 'fromHz': 14300000},
      ]);
      spots.bandAnnotations.put(userBandAnnotationSource, [
        {'type': 'general', 'fromHz': 14200000, 'label': 'QRM'},
      ]);
      spots.bandAnnotations.forgetExtensions();
      expect(spots.bandAnnotations.forBand('20m').map((a) => a['label']), ['QRM']);
    });
  });

  test('one expiring is taken down when it expires, and the panels hear of it', () {
    followFakeClock();
    fakeAsync((async) {
      final service = BandAnnotationsService();
      var heard = 0;
      service.addListener(() => heard++);
      service.put('a', [
        {'type': 'general', 'fromHz': 14300000, 'expiresAt': nowMillis() + 50},
        {'type': 'general', 'fromHz': 14310000},
      ]);
      expect(service.forBand('20m'), hasLength(2));
      async.elapse(const Duration(milliseconds: 50));
      expect(heard, 2, reason: 'once for the put, once for the expiry');
      expect(service.forBand('20m'), hasLength(1));
      service.dispose();
    });
  });
}
