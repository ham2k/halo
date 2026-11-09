// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Spots an extension pushes onto the board as they happen (`host.spots`),
// rather than waiting for the next fetch: the whole list, or keyed puts and
// removes; only ever under one of the pushing extension's own sources; and
// standing through a fetch that did not ask that source, until the extension
// that pushed them is unloaded.

import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_extension_host/halo_extension_host.dart' show ExtensionHostException;
import 'package:ham2k_logger/services/spots_service.dart';

import '../support/halo_test_support.dart';

typedef Fetched = ({List<Map<String, dynamic>> items, List<String> succeeded, List<String> unreachable, List<String> failed});

Map<String, dynamic> spot(String call, {String? key, int ageMinutes = 1, num freq = 14025}) => {
  'their': {'call': call},
  'freq': freq,
  'key': ?key,
  'spot': {'timeInMillis': DateTime.now().millisecondsSinceEpoch - Duration(minutes: ageMinutes).inMilliseconds, 'source': 'cluster'},
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  /// What the next fetch answers; nothing, by default, from nobody.
  Fetched answer = (items: const [], succeeded: const [], unreachable: const [], failed: const []);

  (ExtensionServiceWithFakeHost, SpotsService) harness() {
    final extensions = ExtensionServiceWithFakeHost(FakeExtensionHost({}));
    final spots = SpotsService(fetchSpots: () async => answer, pushNoticeDelay: Duration.zero);
    extensions.spots = spots;
    addTearDown(spots.dispose);
    addTearDown(extensions.bandAnnotations.dispose);
    answer = (items: const [], succeeded: const [], unreachable: const [], failed: const []);
    return (extensions, spots);
  }

  Future<dynamic> call(ExtensionServiceWithFakeHost extensions, String method, String ns, Map<String, dynamic> rest) =>
      extensions.debugHandleHostCall(method, {'ns': ns, 'extensionKey': ns, ...rest});

  List<String> calls(SpotsService spots, String source) => [for (final s in spots.spotsBySource[source] ?? const []) (s['their'] as Map)['call'] as String];

  test('a whole list replaces what the source held, each spot under the source, and findable by its call', () async {
    final (extensions, spots) = harness();
    await call(extensions, 'replaceSpots', 'ham2k-cluster-spots', {
      'spots': [spot('JA1ABC'), spot('OH2BH')],
    });
    expect(calls(spots, 'ham2k-cluster-spots'), ['JA1ABC', 'OH2BH']);
    expect(spots.spotsBySource['ham2k-cluster-spots']!.every((s) => s['hookKey'] == 'ham2k-cluster-spots'), isTrue);
    expect(spots.spotsForCall('ja1abc', maxAge: const Duration(minutes: 30)), hasLength(1));

    await call(extensions, 'replaceSpots', 'ham2k-cluster-spots', {
      'spots': [spot('VP8XYZ')],
    });
    expect(calls(spots, 'ham2k-cluster-spots'), ['VP8XYZ']);
    expect(spots.spotsForCall('JA1ABC', maxAge: const Duration(minutes: 30)), isEmpty, reason: 'the index follows the board');

    await call(extensions, 'replaceSpots', 'ham2k-cluster-spots', {'spots': <Object>[]});
    expect(spots.spotsBySource.containsKey('ham2k-cluster-spots'), isFalse, reason: 'a source with nothing is off the board');
  });

  test('a put replaces by key and adds the rest; a remove takes by key, or everything', () async {
    final (extensions, spots) = harness();
    await call(extensions, 'putSpots', 'feed', {
      'spots': [spot('JA1ABC', key: 'a'), spot('OH2BH', key: 'b')],
    });
    await call(extensions, 'putSpots', 'feed', {
      'spots': [spot('JA1ABC', key: 'a', freq: 7010), spot('VP8XYZ'), spot('VP8XYZ')],
    });
    expect(calls(spots, 'feed'), ['JA1ABC', 'OH2BH', 'VP8XYZ', 'VP8XYZ'], reason: 'one without a key is only ever added');
    expect(spots.spotsBySource['feed']!.first['freq'], 7010);

    await call(extensions, 'removeSpots', 'feed', {
      'keys': ['a', 'nothing'],
    });
    expect(calls(spots, 'feed'), ['OH2BH', 'VP8XYZ', 'VP8XYZ']);
    await call(extensions, 'removeSpots', 'feed', {});
    expect(spots.spotsBySource.containsKey('feed'), isFalse);
  });

  test("a push goes only under one of the caller's own sources, never another's or the operator's", () async {
    final (extensions, spots) = harness();
    await call(extensions, 'putSpots', 'pota', {
      'source': 'pota_hunters',
      'spots': [spot('KI2D')],
    });
    expect(calls(spots, 'pota_hunters'), ['KI2D']);

    for (final source in ['sota', 'potato', 'local']) {
      await expectLater(
        call(extensions, 'putSpots', 'pota', {
          'source': source,
          'spots': [spot('KI2D')],
        }),
        throwsA(isA<ExtensionHostException>()),
        reason: source,
      );
    }
    await expectLater(call(extensions, 'removeSpots', 'sota', {'source': 'pota_hunters'}), throwsA(isA<ExtensionHostException>()));
    expect(calls(spots, 'pota_hunters'), ['KI2D']);
  });

  test('a push before there is a board is refused, not lost', () async {
    final extensions = ExtensionServiceWithFakeHost(FakeExtensionHost({}));
    addTearDown(extensions.bandAnnotations.dispose);
    await expectLater(
      call(extensions, 'putSpots', 'feed', {
        'spots': [spot('KI2D')],
      }),
      throwsA(isA<ExtensionHostException>()),
    );
  });

  test('a malformed spot, or more than a source may hold, pushes none', () async {
    final (extensions, spots) = harness();
    await call(extensions, 'putSpots', 'feed', {
      'spots': [spot('KI2D')],
    });
    for (final bad in [
      {'their': 'KI2D'},
      {...spot('N0DEV'), 'freq': '14025'},
      {...spot('N0DEV'), 'key': 7},
    ]) {
      await expectLater(
        call(extensions, 'putSpots', 'feed', {
          'spots': [spot('N0DEV'), bad],
        }),
        throwsFormatException,
        reason: '$bad',
      );
    }
    await expectLater(
      call(extensions, 'replaceSpots', 'feed', {
        'spots': [for (var i = 0; i < SpotsService.maxPushedSpots + 1; i++) spot('K$i')],
      }),
      throwsA(isA<ExtensionHostException>().having((e) => '$e', 'message', contains("replaceSpots refused: 'feed' would hold"))),
    );
    expect(calls(spots, 'feed'), ['KI2D']);
  });

  test('a source a fetch left over the limit can still have spots taken off', () async {
    final (extensions, spots) = harness();
    answer = (
      items: [
        for (var i = 0; i < SpotsService.maxPushedSpots + 2; i++) {...spot('K$i', key: 'k$i'), 'hookKey': 'feed'},
      ],
      succeeded: ['feed'],
      unreachable: const [],
      failed: const [],
    );
    await spots.refresh();
    await call(extensions, 'removeSpots', 'feed', {
      'keys': ['k0'],
    });
    expect(spots.spotsBySource['feed'], hasLength(SpotsService.maxPushedSpots + 1));
  });

  test('spots past the board\'s age are not held', () async {
    final (extensions, spots) = harness();
    await call(extensions, 'replaceSpots', 'feed', {
      'spots': [spot('OLD', ageMinutes: 200), spot('NEW')],
    });
    expect(calls(spots, 'feed'), ['NEW']);
  });

  test('a fetch that asked the source replaces what it pushed; one that did not leaves it, until its extension is unloaded', () async {
    final (extensions, spots) = harness();
    await call(extensions, 'replaceSpots', 'other', {
      'spots': [spot('N0DEV')],
    });
    await call(extensions, 'replaceSpots', 'pusher', {
      'spots': [spot('JA1ABC')],
    });
    await call(extensions, 'replaceSpots', 'both', {
      'spots': [spot('OH2BH')],
    });

    answer = (
      items: [
        {...spot('VP8XYZ'), 'hookKey': 'both'},
      ],
      succeeded: ['both'],
      unreachable: const [],
      failed: const [],
    );
    await spots.refresh();
    expect(calls(spots, 'pusher'), ['JA1ABC'], reason: 'not asked: a source with no fetchSpots keeps what it pushed');
    expect(calls(spots, 'both'), ['VP8XYZ'], reason: 'asked: its answer is its whole list');

    spots.forgetPushers(['pusher']);
    await spots.refresh();
    expect(spots.spotsBySource.containsKey('pusher'), isFalse, reason: 'pushed by an extension since unloaded, and not pushed again');
    expect(calls(spots, 'other'), ['N0DEV'], reason: "another extension's pushes stand");
  });

  test("a source that pushes while a fetch waits has its pushes made again on that fetch's answer", () async {
    final (extensions, spots) = harness();
    final release = Completer<void>();
    final slow = SpotsService(
      fetchSpots: () async {
        final before = answer;
        await release.future;
        return before;
      },
      pushNoticeDelay: Duration.zero,
    );
    addTearDown(slow.dispose);
    extensions.spots = slow;
    slow.putSpots('feed', [spot('AGED', key: 'aged'), spot('QRT', key: 'q')]);
    // What the source answers: its own pruning has taken AGED off.
    answer = (
      items: [
        {...spot('QRT', key: 'q'), 'hookKey': 'feed'},
        {...spot('KEPT'), 'hookKey': 'feed'},
      ],
      succeeded: ['feed'],
      unreachable: const [],
      failed: const [],
    );
    final fetching = slow.refresh();
    await call(extensions, 'putSpots', 'feed', {
      'spots': [spot('NEW', key: 'n')],
    });
    await call(extensions, 'removeSpots', 'feed', {
      'keys': ['q'],
    });
    release.complete();
    await fetching;
    expect(calls(slow, 'feed'), ['KEPT', 'NEW'], reason: 'the answer, with what was pushed while it was out');
    expect(spots.spotsBySource, isEmpty);
  });

  test('a burst of pushes repaints the board once', () {
    fakeAsync((async) {
      final spots = SpotsService(fetchSpots: () async => answer, pushNoticeDelay: const Duration(milliseconds: 250));
      var notices = 0;
      spots.addListener(() => notices++);
      for (var i = 0; i < 5; i++) {
        spots.putSpots('feed', [spot('K$i')]);
      }
      expect(spots.spotsBySource['feed'], hasLength(5), reason: 'held at once');
      expect(notices, 0);
      async.elapse(const Duration(milliseconds: 300));
      expect(notices, 1);
      spots.dispose();
    });
  });
}
