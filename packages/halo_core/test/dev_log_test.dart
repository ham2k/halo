// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0

import 'package:halo_core/halo_core.dart';
import 'package:test/test.dart';

void main() {
  final log = DevLog.instance;

  setUp(() {
    // Singleton — reset between tests.
    log.clear();
    log.enabled = false;
    log.capacity = 500;
  });

  test('is inert until enabled — nothing buffered or emitted in release', () {
    log.log('qso', {'call': 'W1AW'});
    expect(log.recent(), isEmpty);

    log.enabled = true;
    log.log('qso', {'call': 'W1AW'});
    expect(log.recent(), hasLength(1));
  });

  test('records the tag and data (plus a timestamp)', () {
    log.enabled = true;
    log.log('lookup', {'call': 'W1AW', 'grid': 'FN31pr'});

    final e = log.recent().single;
    expect(e['tag'], 'lookup');
    expect(e['call'], 'W1AW');
    expect(e['grid'], 'FN31pr');
    expect(e['ms'], isA<int>()); // stamped so recentLog() history is orderable
  });

  test('recent() filters by tag and caps to the last [limit]', () {
    log.enabled = true;
    log.log('qso', {'call': 'A'});
    log.log('lookup', {'call': 'B'});
    log.log('qso', {'call': 'C'});
    log.log('qso', {'call': 'D'});

    expect(log.recent(tag: 'qso').map((e) => e['call']), ['A', 'C', 'D']);
    expect(log.recent(tag: 'lookup').map((e) => e['call']), ['B']);
    // limit keeps the newest, oldest-first.
    expect(log.recent(limit: 2).map((e) => e['call']), ['C', 'D']);
    expect(log.recent(tag: 'qso', limit: 2).map((e) => e['call']), ['C', 'D']);
  });

  test('a non-JSON-encodable payload does not throw — logging never breaks the caller', () {
    log.enabled = true;
    // DateTime has no jsonEncode support; a stray one must not blow up the log
    // call (and, via QsosRepository.add, the QSO-commit path).
    expect(() => log.log('qso', {'when': DateTime(2026), 'call': 'W1AW'}), returnsNormally);
    expect(log.recent().single['call'], 'W1AW'); // still buffered
  });

  test('caps the buffer at capacity, dropping oldest (bounded ring)', () {
    log.enabled = true;
    log.capacity = 3;
    for (final c in ['A', 'B', 'C', 'D', 'E']) {
      log.log('qso', {'call': c});
    }
    expect(log.recent().map((e) => e['call']), ['C', 'D', 'E']);
  });

  test('recent() returns copies — a caller cannot corrupt the buffer', () {
    log.enabled = true;
    log.log('qso', {'call': 'W1AW'});
    // The list itself is unmodifiable...
    expect(() => log.recent().add(<String, Object?>{}), throwsUnsupportedError);
    // ...and mutating a returned entry (a copy) doesn't reach the buffer.
    log.recent().single['call'] = 'HACKED';
    expect(log.recent().single['call'], 'W1AW');
  });
}
