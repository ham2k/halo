// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Satellite operations — the last activity in the port, and the only one that
// is not an award.
//
// The fixtures below are copied from the real feed
// (polo.ham2k.com/data/satellites.json, 38 birds), not invented. AO-7 is here
// because it is the ONE bird whose two transponders answer on different bands
// — 2m up → 10m down, 70cm up → 2m down — which is the whole reason the
// reference names a transponder rather than a satellite. Get that wrong and
// BAND_RX is wrong on every AO-7 contact, which is exactly the kind of thing
// nobody notices until an award rejects the log.

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:halo_extension_host/halo_extension_host.dart';

import 'support/bundles.dart';

void main() {
  requireBundles();

  /// Verbatim from the feed.
  const soFifty = {
    'name': 'SO-50',
    'number': 27607,
    'modulation': 'fm',
    'uplinks': [
      {'mode': 'fm', 'lowerMHz': 145.85, 'upperMHz': 145.85},
    ],
    'downlinks': [
      {'mode': 'fm', 'lowerMHz': 436.795, 'upperMHz': 436.795},
    ],
  };

  const aoSeven = {
    'name': 'AO-7',
    'number': 7530,
    'modulation': 'linear',
    'uplinks': [
      {'mode': 'linear', 'lowerMHz': 145.85, 'upperMHz': 145.95},
      {'mode': 'linear', 'lowerMHz': 432.125, 'upperMHz': 432.175},
    ],
    'downlinks': [
      {'mode': 'linear', 'lowerMHz': 29.4, 'upperMHz': 29.5},
      {'mode': 'linear', 'lowerMHz': 145.925, 'upperMHz': 145.975},
    ],
  };

  /// The lookup rows the data file would have produced, answered straight from
  /// `onHostCall` — this is the bird table the extension reads.
  // Keyed by the fixture, not by the handler: the handler closes over `birds`
  // and is rebuilt per call, so identity would boot a host per call. Sharing
  // WITHIN a fixture is sound; sharing across fixtures would not be, because
  // the extension caches its transponder table after the first load
  // (activities/satellites/src/index.ts) — hence the fixture in the key.
  Future<ExtensionHost> hostWithBirds(List<Map<String, dynamic>> birds) async {
    final host = await sharedHost(
      ['satellites'],
      cacheKey: 'birds:${birds.map((b) => b['name']).join(',')}',
      onHostCall: (method, params) async {
        if (method == 'dbLookupSelectAll' && params['category'] == 'satellites') {
          return [
            for (final bird in birds)
              {
                'category': 'satellites',
                'key': (bird['name'] as String).toUpperCase(),
                'name': bird['name'],
                'data': bird,
              },
          ];
        }
        return null;
      },
    );
    return host;
  }

  Future<List<Map<String, String>>> adifFor(ExtensionHost host, String? ref) async {
    final fields = await host.invokeHook('adifFields',
        key: 'satellites',
        method: 'fieldsForOneQSO',
        args: {
          'qso': {'refs': ref == null ? [] : [{'type': 'satellite', 'ref': ref}]},
          'operation': const {'refs': []},
        },
        timeout: const Duration(seconds: 10)) as List;
    return fields.map((f) => {(f as Map)['name'] as String: f['value'] as String}).toList();
  }

  Map<String, String> flat(List<Map<String, String>> fields) => {
        for (final f in fields) ...f,
      };

  group('what an award reads', () {
    test('a satellite QSO carries PROP_MODE, SAT_NAME and the downlink band', () async {
      final host = await hostWithBirds([soFifty]);
      // The picker has to have been opened once for the bird table to be
      // loaded, which is what the export path then reads.
      await host.invokeHook('activity', key: 'satellites', method: 'loggingControls',
          args: {'operation': const {'refs': []}}, timeout: const Duration(seconds: 10));

      expect(flat(await adifFor(host, 'SO-50/145.85/fm')), {
        'PROP_MODE': 'SAT',
        'SAT_NAME': 'SO-50',
        // The DOWNLINK's band (436.795 MHz), not the uplink's 2m.
        'BAND_RX': '70cm',
      });
    }, timeout: const Timeout(Duration(seconds: 60)));

    test("AO-7's two transponders report DIFFERENT downlink bands", () async {
      // The reason the reference names a transponder at all. Same bird, same
      // SAT_NAME, different BAND_RX — a reference that named only "AO-7" could
      // not express this, and would be wrong half the time.
      final host = await hostWithBirds([aoSeven]);
      await host.invokeHook('activity', key: 'satellites', method: 'loggingControls',
          args: {'operation': const {'refs': []}}, timeout: const Duration(seconds: 10));

      expect(flat(await adifFor(host, 'AO-7/145.85/linear'))['BAND_RX'], '10m');
      expect(flat(await adifFor(host, 'AO-7/432.125/linear'))['BAND_RX'], '2m');
    }, timeout: const Timeout(Duration(seconds: 60)));

    test('a QSO with no satellite gets no satellite fields', () async {
      final host = await hostWithBirds([soFifty]);
      expect(await adifFor(host, null), isEmpty);
    }, timeout: const Timeout(Duration(seconds: 60)));

    test('a bare satellite name, with no transponder, still exports', () async {
      // What import leaves behind when a record does not say which transponder
      // was used. The whole "import the bird and move on" rule rests on this
      // shape surviving: a reference that split wrong here would export a
      // mangled SAT_NAME, or none.
      final host = await hostWithBirds([soFifty]);
      final fields = flat(await adifFor(host, 'AO-7'));
      expect(fields['SAT_NAME'], 'AO-7');
      expect(fields['PROP_MODE'], 'SAT');
      expect(fields.containsKey('BAND_RX'), isFalse);
    }, timeout: const Timeout(Duration(seconds: 60)));

    test('an unknown bird still logs the name, just without a band', () async {
      // A reference from a log recorded before this bird was retired from the
      // feed. PROP_MODE and SAT_NAME are what the reference itself says, so
      // they are always right; only BAND_RX needs the table.
      final host = await hostWithBirds([soFifty]);
      final fields = flat(await adifFor(host, 'XW-2A/435.03/linear'));
      expect(fields['SAT_NAME'], 'XW-2A');
      expect(fields.containsKey('BAND_RX'), isFalse);
    }, timeout: const Timeout(Duration(seconds: 60)));
  });

  group('reading a satellite log back', () {
    // The inverse of the group above, and the only activity whose import is
    // hand-written: satellites write no SIG at all, so `activityAdifImport`
    // cannot apply. The reconstruction is genuinely lossy — the log stores a
    // TRANSPONDER and ADIF carries only the bird and its downlink band — so
    // most of what these assert is when the hook must refuse to guess.
    Future<List<dynamic>> importFrom(ExtensionHost host, List<Map<String, String>> records) async {
      return await host.invokeHook(
        'adifImport',
        key: 'satellites',
        method: 'refsForRecords',
        args: {
          'records': [
            for (final fields in records) {'fields': fields},
          ],
        },
        timeout: const Duration(seconds: 20),
      ) as List;
    }

    test('a one-transponder bird round-trips what the exporter wrote', () async {
      final host = await hostWithBirds([soFifty]);
      final results = await importFrom(host, [
        {'prop_mode': 'SAT', 'sat_name': 'SO-50', 'band_rx': '70cm'},
      ]);

      expect(results.single['refs'], [
        {'type': 'satellite', 'ref': 'SO-50/145.85/fm'},
      ]);
    }, timeout: const Timeout(Duration(seconds: 60)));

    test("BAND_RX tells AO-7's two transponders apart", () async {
      // The pair the export group proves writes different BAND_RX values. If
      // import could not read that back, an AO-7 log would round-trip onto the
      // wrong transponder and export a downlink band the operator never used.
      final host = await hostWithBirds([aoSeven]);
      final results = await importFrom(host, [
        {'sat_name': 'AO-7', 'band_rx': '10m'},
        {'sat_name': 'AO-7', 'band_rx': '2m'},
      ]);

      expect(results[0]['refs'], [
        {'type': 'satellite', 'ref': 'AO-7/145.85/linear'},
      ]);
      expect(results[1]['refs'], [
        {'type': 'satellite', 'ref': 'AO-7/432.125/linear'},
      ]);
    }, timeout: const Timeout(Duration(seconds: 60)));

    test('the record\'s own band narrows it too, being the UPLINK', () async {
      // ADIF's FREQ/BAND is the transmit side. A file with no BAND_RX still
      // says which transponder was used, in the field every logger fills in.
      final host = await hostWithBirds([aoSeven]);
      final results = await importFrom(host, [
        {'sat_name': 'AO-7', 'band': '70cm'},
        {'sat_name': 'AO-7', 'freq': '145.850'},
      ]);

      expect(results[0]['refs'], [
        {'type': 'satellite', 'ref': 'AO-7/432.125/linear'},
      ]);
      expect(results[1]['refs'], [
        {'type': 'satellite', 'ref': 'AO-7/145.85/linear'},
      ]);
    }, timeout: const Timeout(Duration(seconds: 60)));

    test('a FREQ that names no band is no information, not a contradiction', () async {
      // `bandForFrequency` answers `'other'` for a frequency it cannot place,
      // never anything falsy. Passed through as a band, it matches no
      // transponder and eliminates every candidate — so a junk FREQ would cost
      // SO-50 the transponder its name alone had already settled.
      final host = await hostWithBirds([soFifty]);
      final results = await importFrom(host, [
        {'sat_name': 'SO-50', 'freq': '0'},
      ]);

      expect(results.single['refs'], [
        {'type': 'satellite', 'ref': 'SO-50/145.85/fm'},
      ]);
    }, timeout: const Timeout(Duration(seconds: 60)));

    test('an ambiguous bird imports as the bare bird, not a guessed transponder', () async {
      // Nothing in the record says which of AO-7's transponders was used.
      // Naming either would claim a band the operator never transmitted on, so
      // the reference keeps only what the file actually said.
      final host = await hostWithBirds([aoSeven]);
      final results = await importFrom(host, [
        {'prop_mode': 'SAT', 'sat_name': 'AO-7'},
      ]);

      expect(results.single['refs'], [
        {'type': 'satellite', 'ref': 'AO-7'},
      ]);
    }, timeout: const Timeout(Duration(seconds: 60)));

    test('a BAND_RX the table contradicts still imports the bird', () async {
      // SO-50 has one transponder and the file says a band it does not answer
      // on. The disagreement is real — resolving it either way would invent
      // something — but it is no reason to drop the satellite.
      final host = await hostWithBirds([soFifty]);
      final results = await importFrom(host, [
        {'sat_name': 'SO-50', 'band_rx': '2m'},
      ]);

      expect(results.single['refs'], [
        {'type': 'satellite', 'ref': 'SO-50'},
      ]);
    }, timeout: const Timeout(Duration(seconds: 60)));

    test('a bird the table has never heard of imports anyway', () async {
      // Nothing here is validated against the table. A retired bird, a new one
      // the feed has not caught up with, or a build whose data file never
      // downloaded must not silently cost the operator the satellite.
      final host = await hostWithBirds([soFifty]);
      final results = await importFrom(host, [
        {'prop_mode': 'SAT', 'sat_name': 'XW-2A'},
      ]);

      expect(results.single['refs'], [
        {'type': 'satellite', 'ref': 'XW-2A'},
      ]);
    }, timeout: const Timeout(Duration(seconds: 60)));

    test('a bird named without its dash is the same bird', () async {
      final host = await hostWithBirds([soFifty]);
      final results = await importFrom(host, [
        {'sat_name': 'so50', 'band_rx': '70cm'},
      ]);

      expect(results.single['refs'], [
        {'type': 'satellite', 'ref': 'SO-50/145.85/fm'},
      ]);
    }, timeout: const Timeout(Duration(seconds: 60)));

    test('returns one result per record, nulls included', () async {
      // The Dart side matches these back by index; a hook that omitted its
      // empties would put one QSO's satellite on another.
      final host = await hostWithBirds([soFifty]);
      final results = await importFrom(host, [
        {'sat_name': 'SO-50', 'band_rx': '70cm'},
        {'call': 'W1AW'},
        {'sat_name': 'XW-2A', 'band_rx': '70cm'},
      ]);

      expect(results, hasLength(3));
      expect(results[0]['refs'], [
        {'type': 'satellite', 'ref': 'SO-50/145.85/fm'},
      ]);
      // No SAT_NAME at all — the one record that genuinely has no satellite in
      // it, and so the only shape that yields a null.
      expect(results[1], isNull);
      expect(results[2]['refs'], [
        {'type': 'satellite', 'ref': 'XW-2A'},
      ]);
    }, timeout: const Timeout(Duration(seconds: 60)));
  });

  group('the published feed', () {
    // The mapper the other groups stub past. The fixture is a verbatim slice of
    // polo.ham2k.com/data/satellites.json — inferring an award's data shape is
    // what went wrong three times earlier in this port, so this one was read
    // first and is pinned here.
    test('maps the real feed into one row per bird', () async {
      final feed = jsonDecode(File('test/fixtures/satellites.json').readAsStringSync()) as List;
      final host = await hostWithBirds(const []);
      final rows = (await host.invokeHook('dataFile',
              key: 'satellite-data',
              method: 'mapJsonBatch',
              args: {'entries': feed},
              timeout: const Duration(seconds: 20)) as List)
          .map((e) => (e as Map).cast<String, dynamic>())
          .toList();

      // One row per BIRD, not per transponder — `queryLookups` caps at 100 and
      // the cap is silent.
      expect(rows.length, feed.length);
      expect(rows.map((r) => r['key']), ['AO-7', 'SO-50', 'QO-100', 'IO-117']);
      expect(rows.first['subCategory'], 'linear');
      // The transponders ride in `data`, which is what the pickers expand.
      expect((rows.first['data']['uplinks'] as List).length, 2);
    }, timeout: const Timeout(Duration(seconds: 60)));

    test('every bird in the feed yields a usable transponder', () async {
      // End to end on real data: feed → rows → picker options. A bird that
      // produced a malformed code would be unselectable and would export a
      // wrong SAT_NAME.
      final feed = (jsonDecode(File('test/fixtures/satellites.json').readAsStringSync()) as List)
          .map((e) => (e as Map).cast<String, dynamic>())
          .toList();
      final host = await hostWithBirds(feed);
      final controls = await host.invokeHook('activity',
          key: 'satellites',
          method: 'loggingControls',
          args: {'operation': const {'refs': []}},
          timeout: const Duration(seconds: 10)) as List;
      final options = (((controls.single as Map)['input'] as Map)['options'] as List).cast<Map>();

      // AO-7 and QO-100 have two uplinks each; SO-50 and IO-117 one.
      expect(options.length, 6);
      for (final option in options) {
        final code = option['code'] as String;
        expect(code.split('/').length, 3, reason: '$code should be name/freq/mode');
        expect(code.contains('undefined'), isFalse, reason: '$code has a missing part');
        expect((option['name'] as String).contains('→'), isTrue, reason: '$code has no frequencies');
      }
    }, timeout: const Timeout(Duration(seconds: 60)));
  });

  group('the pickers', () {
    test('the per-QSO control offers one option per transponder', () async {
      final host = await hostWithBirds([soFifty, aoSeven]);
      final controls = await host.invokeHook('activity',
          key: 'satellites',
          method: 'loggingControls',
          args: {'operation': const {'refs': []}},
          timeout: const Duration(seconds: 10)) as List;

      final input = (controls.single as Map)['input'] as Map;
      expect(input['kind'], 'options');
      expect(input['field'], 'ref');
      // Not uppercased: the stored code carries a lowercase mode, and app-polo
      // reads the same strings.
      expect(input['uppercase'], isFalse);

      final options = (input['options'] as List).cast<Map>();
      expect(options.map((o) => o['code']), [
        'SO-50/145.85/fm',
        'AO-7/145.85/linear',
        'AO-7/432.125/linear',
      ]);
      // MHz to three decimals — `fmtFreq` would render QO-100's 10489.5 as
      // "10.489.500", reading its argument as kHz.
      expect(options.first['name'], 'SO-50 • FM: 145.850 → 436.795');
    }, timeout: const Timeout(Duration(seconds: 60)));

    test("the operation's bird becomes each QSO's suggested value", () async {
      // app-polo's `operation.satellite` without a second place to store it: a
      // pass is one choice, not one per contact.
      final host = await hostWithBirds([soFifty]);
      final controls = await host.invokeHook('activity',
          key: 'satellites',
          method: 'loggingControls',
          args: {
            'operation': {'refs': [{'type': 'satellite', 'ref': 'SO-50/145.85/fm'}]},
          },
          timeout: const Duration(seconds: 10)) as List;

      final control = controls.single as Map;
      expect((control['input'] as Map)['suggestedValue'], 'SO-50/145.85/fm');
      // Every contact on a pass goes through the bird; one that forgot to say
      // so cannot be uploaded as a satellite QSO.
      expect(control['optionType'], 'mandatory');
    }, timeout: const Timeout(Duration(seconds: 60)));

    test('the operation control is a form, which is all operationControls renders', () async {
      // `operationControls` handles `refList` and `form` only — an `options`
      // control there would silently never appear.
      final host = await hostWithBirds([soFifty, aoSeven]);
      final controls = await host.invokeHook('activity',
          key: 'satellites',
          method: 'operationControls',
          args: {'operation': const {'refs': []}},
          timeout: const Duration(seconds: 10)) as List;

      final input = (controls.single as Map)['input'] as Map;
      expect(input['kind'], 'form');
      expect(input['refType'], 'satellite');
      final field = ((input['form'] as Map)['elements'] as List).single as Map;
      expect(field['fieldType'], 'select');
      expect(field['key'], 'ref');
      expect((field['options'] as List).length, 3);
    }, timeout: const Timeout(Duration(seconds: 60)));
  });

  group('the SAT command', () {
    Future<Map?> interpret(ExtensionHost host, String input, {Map<String, dynamic>? qso}) async =>
        await host.invokeHook('command',
            key: 'satellites-sat',
            method: 'interpret',
            args: {'input': input, 'qso': ?qso},
            timeout: const Duration(seconds: 10)) as Map?;

    test('names the bird AND tunes the radio, which a control cannot', () async {
      // The whole reason the command exists: a `loggingControls` selection
      // writes its value and cannot ask for anything else to happen.
      final host = await hostWithBirds([soFifty]);
      final result = await interpret(host, 'SAT SO-50');

      final commands = (result!['commands'] as List).cast<Map>();
      // Uplink in kHz, and FM because this transponder really is FM.
      expect(commands.first['setVfo'], {'freq': 145850.0, 'mode': 'FM'});
      final refs = ((commands.last['updateQso'] as Map)['refs'] as List).cast<Map>();
      expect(refs.single, {'type': 'satellite', 'ref': 'SO-50/145.85/fm'});
    }, timeout: const Timeout(Duration(seconds: 60)));

    test('a linear transponder is tuned but not moded', () async {
      // Only FM says anything about the mode. On a linear transponder the
      // operator chooses, and overwriting that would be worse than leaving it.
      final host = await hostWithBirds([aoSeven]);
      final result = await interpret(host, 'SAT AO-7');
      final setVfo = ((result!['commands'] as List).first as Map)['setVfo'] as Map;
      expect(setVfo['freq'], 145850.0);
      expect(setVfo.containsKey('mode'), isFalse);
    }, timeout: const Timeout(Duration(seconds: 60)));

    test('it keeps the other activities on the QSO', () async {
      // `updateQso` writes whole fields, so a bare refs list would drop the
      // park this contact is also for — a silent loss of the operator's log.
      final host = await hostWithBirds([soFifty]);
      final result = await interpret(host, 'SAT SO-50', qso: {
        'refs': [
          {'type': 'pota', 'ref': 'US-0001'},
          {'type': 'satellite', 'ref': 'AO-7/145.85/linear'},
        ],
      });

      final refs = (((result!['commands'] as List).last as Map)['updateQso'] as Map)['refs'] as List;
      expect(refs, [
        {'type': 'pota', 'ref': 'US-0001'},
        {'type': 'satellite', 'ref': 'SO-50/145.85/fm'},
      ]);
    }, timeout: const Timeout(Duration(seconds: 60)));

    test('a bare SAT asks for the bird rather than guessing one', () async {
      final host = await hostWithBirds([soFifty]);
      final result = await interpret(host, 'SAT');
      expect(result!['expectsParams'], isTrue);
      expect(result.containsKey('commands'), isFalse);
    }, timeout: const Timeout(Duration(seconds: 60)));

    test('an unknown bird is an error, not a silent no-op', () async {
      final host = await hostWithBirds([soFifty]);
      final result = await interpret(host, 'SAT NOTABIRD');
      expect(result!['error'], contains('NOTABIRD'));
      expect(result.containsKey('commands'), isFalse);
    }, timeout: const Timeout(Duration(seconds: 60)));

    test('anything that is not SAT is left to other commands', () async {
      // `interpret` fans out to every command hook; returning non-null for
      // something else would hijack it.
      final host = await hostWithBirds([soFifty]);
      expect(await interpret(host, 'SATURDAY'), isNull);
      expect(await interpret(host, 'W1AW'), isNull);
    }, timeout: const Timeout(Duration(seconds: 60)));
  });
}
