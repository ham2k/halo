// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The host↔kernel CSV contract (APP-16). `DataFileManager` sends rows
// POSITIONALLY plus the header row ONCE per chunk, and the kernel zips them
// back into the `Record<string,string>` that `csvToLookupEntry` is declared to
// take. That split is worth 61% of the bytes on SOTA's 181k-row file, but it
// moved the zip out of Dart — where it was covered — into JS, where nothing
// exercised it.
//
// What these pin, driven through the real SOTA bundle rather than a stand-in
// mapper: that a column lands on the field it names, that EVERY row in a chunk
// is zipped against the one shared header list, that ragged lines are tolerated
// rather than dropped or allowed to shift a later row, and that a file with no
// headers still reaches the mapper positionally.
//
// What they deliberately do NOT claim: that the `limit = min(headers, cells)`
// bound is exactly right. A mapper only ever READS properties, and a missing
// key and an `undefined`-valued key read identically — so no test driven
// through one can tell the two bounds apart. That bound matters only to a
// mapper that enumerates (`Object.keys`, spread, `in`), and none do; it is held
// by the comment at the zip, not by an assertion here. Verified by mutation:
// forcing `limit = headers.length` leaves this whole file green.

import 'package:flutter_test/flutter_test.dart';

import 'support/bundles.dart';

void main() {
  requireBundles();

  // summitslist.csv's real column order.
  const headers = [
    'SummitCode',
    'AssociationName',
    'RegionName',
    'SummitName',
    'AltM',
    'AltFt',
    'GridRef1',
    'GridRef2',
    'Longitude',
    'Latitude',
    'Points',
    'BonusPoints',
    'ValidFrom',
    'ValidTo',
    'ActivationCount',
    'ActivationDate',
    'ActivationCall',
  ];

  // 31/12/2099 is SOTA's "never expires" sentinel; the mapper drops anything
  // whose ValidTo has passed, so every row here has to carry it.
  const fullRow = [
    'W6/CT-001',
    'USA - California',
    'Central',
    'Test Peak',
    '1200',
    '3937',
    '',
    '',
    '-122.1',
    '37.5',
    '4',
    '0',
    '01/01/2020',
    '31/12/2099',
    '0',
    '',
    '',
  ];

  Future<List<Map<String, dynamic>>> mapCsv(Map<String, Object?> args) async {
    final host = await sharedHost(['sota']);
    final result = await host.invokeHook('dataFile', key: 'sota-all-summits', method: 'mapCsvBatch', args: args, timeout: const Duration(seconds: 20)) as List;
    return result.map((e) => (e as Map).cast<String, dynamic>()).toList();
  }

  group('dataFile CSV host↔kernel contract', () {
    test('positional rows plus one headers list arrive as named fields', () async {
      final out = await mapCsv({
        'headers': headers,
        'rows': [fullRow],
      });

      expect(out, hasLength(1), reason: 'the zip must produce exactly one entry per row');
      expect(out.first['key'], 'W6/CT-001');
      expect(out.first['name'], 'Test Peak', reason: 'SummitName must land on the right column');
      expect(out.first['lat'], closeTo(37.5, 0.001));
      expect(out.first['lon'], closeTo(-122.1, 0.001));
    });

    test('every row in a chunk is zipped against the one shared header list', () async {
      // The headers cross ONCE per chunk and are reused for all 5000 rows. A
      // zip that hoisted the wrong way — building the object once, or only
      // honouring the first row — would still return something for row 0.
      final second = [...fullRow];
      second[0] = 'W6/CT-002';
      second[3] = 'Second Peak';
      second[9] = '38.5';

      final out = await mapCsv({
        'headers': headers,
        'rows': [fullRow, second],
      });

      expect(out, hasLength(2));
      expect(out.map((e) => e['key']), containsAll(['W6/CT-001', 'W6/CT-002']));
      expect(out.firstWhere((e) => e['key'] == 'W6/CT-002')['name'], 'Second Peak');
      expect(out.firstWhere((e) => e['key'] == 'W6/CT-002')['lat'], closeTo(38.5, 0.001));
    });

    test('ragged lines are tolerated and do not shift the row after them', () async {
      // Published lists are full of these. A zip that rejected a length
      // mismatch outright would silently drop real summits; one that carried
      // state between rows would corrupt the row following a ragged one.
      final short = fullRow.sublist(0, 14); // truncated after ValidTo
      final long = [...fullRow, 'surplus-one', 'surplus-two'];
      long[0] = 'W6/CT-003';
      long[3] = 'Third Peak';

      final out = await mapCsv({
        'headers': headers,
        'rows': [short, long, fullRow],
      });

      expect(out, hasLength(3), reason: 'neither a short nor a long line is a reason to drop a summit');
      expect(out[0]['name'], 'Test Peak', reason: 'the short row keeps the columns it does have');
      expect(out[1]['key'], 'W6/CT-003');
      expect(out[1]['name'], 'Third Peak', reason: 'surplus cells must not shift the mapping');
      expect(out[2]['name'], 'Test Peak', reason: 'a ragged row must not corrupt the row after it');
      expect(out[2]['lat'], closeTo(37.5, 0.001));
    });

    test('a row whose ValidTo has passed is still dropped through the zip', () async {
      // The filter has to survive the new path — this is what keeps ~10k
      // retired summits out of the 181k-row import.
      final expired = [...fullRow];
      expired[13] = '01/01/2020';

      final out = await mapCsv({
        'headers': headers,
        'rows': [expired],
      });

      expect(out, isEmpty);
    });

    test('with no headers the row is passed through positionally', () async {
      // `hasHeaders: false` sends no headers at all, and the mapper receives
      // the raw string[] — the other half of its declared signature. SOTA's
      // mapper reads named fields, so it correctly rejects a positional row
      // rather than mapping garbage; what matters is that the path exists and
      // does not throw.
      final out = await mapCsv({
        'rows': [fullRow],
      });

      expect(out, isEmpty);
    });
  });
}
