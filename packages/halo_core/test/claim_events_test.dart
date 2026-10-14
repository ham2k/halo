// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Imported claims are records in the log (docs/design/claims.md §9), so they
// sync with it and survive the claims table being emptied. Sponsor exports
// are cumulative: each file of a kind is the whole list, and importing it
// again must neither pile up rows nor leave behind what the sponsor dropped.

import 'package:drift/native.dart';
import 'package:halo_core/halo_core.dart';
import 'package:test/test.dart';

Map<String, dynamic> _record(String ref, {String importer = 'hunted-parks', String label = 'A park'}) => claimEventQson(
  program: 'pota',
  importer: importer,
  imported: ImportedClaim(QsoClaim(holder: 'KI2D', ref: ref, band: null, mode: null, level: ClaimLevel.verified, label: label), atMillis: 500),
  fallbackMillis: 9000,
);

void main() {
  late HaLoDatabase db;
  late QsosRepository qsos;

  setUp(() {
    db = HaLoDatabase(NativeDatabase.memory());
    qsos = QsosRepository(db);
  });
  tearDown(() async => db.close());

  Future<Set<String>> live({String importer = 'hunted-parks'}) async => {
    for (final qso in await qsos.claimEvents('pota', importer))
      if (!qso.deleted) claimEventOf(qso.data)!.claim.ref,
  };

  test('a new file of the same kind replaces the last, deleting what it no longer lists', () async {
    await qsos.replaceClaimEvents('pota', 'hunted-parks', [_record('US-0001'), _record('US-0002')]);
    await qsos.replaceClaimEvents('pota', 'hunted-parks', [_record('US-0002'), _record('US-0003')]);
    expect(await live(), {'US-0002', 'US-0003'});
    expect(await qsos.claimEvents('pota', 'hunted-parks'), hasLength(3), reason: 'the dropped park is a tombstone, which syncs its removal');
  });

  // A tombstone holds the uuid: inserting the park again would collide with
  // it and roll the whole import back.
  test('a park the sponsor lists again after dropping it comes back', () async {
    await qsos.replaceClaimEvents('pota', 'hunted-parks', [_record('US-0001')]);
    await qsos.replaceClaimEvents('pota', 'hunted-parks', [_record('US-0002')]);
    await qsos.replaceClaimEvents('pota', 'hunted-parks', [_record('US-0001'), _record('US-0002')]);
    expect(await live(), {'US-0001', 'US-0002'});
  });

  // Every row written is a row pushed, to every device on the account.
  test('the same file again writes nothing, and a changed record is rewritten', () async {
    await qsos.replaceClaimEvents('pota', 'hunted-parks', [_record('US-0001'), _record('US-0002')]);
    expect(await qsos.replaceClaimEvents('pota', 'hunted-parks', [_record('US-0001'), _record('US-0002')]), 0);
    expect(await qsos.replaceClaimEvents('pota', 'hunted-parks', [_record('US-0001', label: 'Renamed'), _record('US-0002')]), 1);
    final renamed = (await qsos.claimEvents('pota', 'hunted-parks')).firstWhere((qso) => claimEventOf(qso.data)!.claim.ref == 'US-0001');
    expect(claimEventOf(renamed.data)!.claim.label, 'Renamed');
  });

  test("one importer's file leaves another's records and the contacts alone", () async {
    final contact = await qsos.add('', {
      'their': {'call': 'W1AW'},
      'band': '20m',
    });
    await qsos.replaceClaimEvents('pota', 'other', [_record('US-0009', importer: 'other')]);
    await qsos.replaceClaimEvents('pota', 'hunted-parks', [_record('US-0001')]);
    await qsos.replaceClaimEvents('pota', 'hunted-parks', []);
    expect(await live(importer: 'other'), {'US-0009'});
    expect((await qsos.get(contact.uuid))!.deleted, isFalse);
  });
}
