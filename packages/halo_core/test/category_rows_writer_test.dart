// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The one place every data-file import ends: the rows written, then the shrink
// guard, then the sweep. The order is the contract — a short file reaching
// the sweep deletes every row it did not restamp, emptying the category until
// the next good import, and in the app that is days away.

import 'package:drift/native.dart';
import 'package:halo_core/halo_core.dart';
import 'package:test/test.dart';

void main() {
  late HaLoDatabase db;
  late LookupRepository lookups;

  setUp(() {
    db = HaLoDatabase(NativeDatabase.memory());
    lookups = LookupRepository(db);
  });
  tearDown(() => db.close());

  Future<void> seed(int count) => lookups.insertLookupBatch([for (var i = 0; i < count; i++) LookupRow(category: 'parks', key: 'OLD-$i', updated: 1)]);
  Future<Set<String>> keys() async => {for (final row in await lookups.queryLookups('parks', '')) row.key};
  List<LookupRow> rows(List<String> keys, int updated) => [for (final key in keys) LookupRow(category: 'parks', key: key, updated: updated)];

  test('an import replaces the category: what it wrote stays, what it did not is swept', () async {
    await seed(2);
    final writer = await CategoryRowsWriter.start(lookups, key: 'parks', category: 'parks', force: false);
    await writer.write(rows(['OLD-0', 'NEW-1'], writer.updated));
    await writer.write(rows(['NEW-2'], writer.updated));
    expect(await writer.finish(), isNull);
    expect(writer.written, 3);
    expect(await keys(), {'OLD-0', 'NEW-1', 'NEW-2'});
  });

  test('a short import is refused before the sweep, and the rows it did not restamp are kept', () async {
    await seed(10);
    var swept = false;
    final writer = await CategoryRowsWriter.start(lookups, key: 'parks', category: 'parks', force: false);
    await writer.write(rows(['NEW-1'], writer.updated));
    await expectLater(writer.finish(beforeSweep: () async => swept = true), throwsA(isA<DataFileImportShrank>()));
    expect(swept, isFalse, reason: 'a refused import never reaches the step before the sweep');
    expect(await keys(), hasLength(11));
  });

  test('a forced short import sweeps, and answers the shrink for the host to report', () async {
    await seed(10);
    final writer = await CategoryRowsWriter.start(lookups, key: 'parks', category: 'parks', force: true);
    await writer.write(rows(['NEW-1'], writer.updated));
    final shrank = await writer.finish();
    expect(shrank, isA<DataFileImportShrank>().having((s) => s.forced, 'forced', isTrue).having((s) => s.existing, 'existing', 10));
    expect(await keys(), {'NEW-1'});
  });

  test('a mapper answer becomes rows; an entry with no key names none', () {
    final mapped = lookupRowsFromMapped(
      [
        {
          'key': 'K-1',
          'name': 'Park',
          'lat': 41,
          'data': {'grid': 'FN31'},
        },
        {'name': 'no key'},
        'not an object',
      ],
      category: 'parks',
      updated: 7,
    );
    expect(mapped, hasLength(1));
    expect(mapped.single.key, 'K-1');
    expect(mapped.single.lat, 41.0);
    expect(mapped.single.data, '{"grid":"FN31"}');
    expect(mapped.single.updated, 7);
  });

  // A mapper writing its keys as numbers would otherwise map every row to
  // nothing: a first import then succeeds empty, is stamped fresh, and the
  // feature has no data until the file ages out, with nothing reported.
  test('a key that is not text fails the import rather than mapping to nothing', () {
    expect(
      () => lookupRowsFromMapped(
        [
          {'key': 42},
        ],
        category: 'parks',
        updated: 7,
      ),
      throwsA(isA<TypeError>()),
    );
  });

  // A row stamped otherwise would count toward the guard and then be swept
  // as stale by the same import that wrote it.
  test('a row of another category or stamp is refused, before anything is written', () async {
    final writer = await CategoryRowsWriter.start(lookups, key: 'parks', category: 'parks', force: false);
    await expectLater(writer.write(rows(['NEW-1'], writer.updated + 1)), throwsStateError);
    await expectLater(writer.write([LookupRow(category: 'sota', key: 'S-1', updated: writer.updated)]), throwsStateError);
    expect(writer.written, 0);
    expect(await lookups.countCategory('parks') + await lookups.countCategory('sota'), 0);
  });
}
