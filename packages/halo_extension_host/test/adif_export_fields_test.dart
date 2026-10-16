// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// What a record of the whole-log ADIF export actually SAYS about a contact.
// The importer (`adif_to_qson.dart`) is the measure: every field it reads back
// is one a log round-tripped through this app must not lose. A field the
// exporter stops writing costs the operator the entity, the zones, the power,
// the county or the split — and no other export test can catch that, because
// each asserts only the fields it already names.
//
// Driven through the real runtime rather than the TypeScript unit tests: the
// question here is what one QSON contact turns into, and the answer runs
// through the SDK's country-file data, which the bundle carries and a stub
// would not.

import 'package:flutter_test/flutter_test.dart';

import 'support/bundles.dart';

void main() {
  requireBundles();

  /// A California operator working a Connecticut station, with everything the
  /// app can know about either side present — an entered county on ours, a
  /// looked-up one on theirs, a split, a duration and a power.
  Map<String, dynamic> operation() => {
    'uuid': 'op',
    'stationCall': 'N0DEV',
    'title': 'Park run',
    'state': 'CA',
    'county': 'Marin',
    'grid': 'CM87ss',
    // Decorated, the way `decorateRef` leaves a reference the operator
    // added — QSLMSG names the programs, and a fixture of bare codes would
    // pass whether it did or not. The WWFF ref stays undecorated: a
    // reference that resolved to nothing must still reach the card.
    'refs': [
      {'type': 'potaActivation', 'ref': 'US-0001', 'shortLabel': 'POTA US-0001', 'label': 'POTA US-0001: Some Park'},
      {'type': 'wwffActivation', 'ref': 'KFF-0002'},
    ],
  };

  Map<String, dynamic> qso() => {
    'uuid': 'q0',
    // `cqZone`/`ituZone` are here because something PUT them here — an
    // import, or an extension that knows where the station is. Nothing
    // derives them, so a zone no country file would produce is the proof.
    'our': {'call': 'N0DEV', 'sent': '59', 'rig': 'FT-891', 'antenna': 'EFHW', 'cqZone': 31, 'ituZone': 61},
    'their': {
      'call': 'W1AW',
      'sent': '57',
      'power': 5,
      // The receive half of a split, which QSON records on `their`.
      'freq': 14275.0,
      'band': '20m',
      'email': 'w1aw@example.org',
      'guess': {
        'call': 'W1AW',
        'name': 'ARRL HQ',
        'street': '225 Main St',
        'city': 'Newington',
        'postal': '06111',
        'county': 'Hartford',
        'state': 'CT',
        'country': 'United States',
        'continent': 'NA',
        'entityPrefix': 'K',
        'dxccCode': 291,
        // Deliberately not the zone a country file would resolve W1AW to:
        // an export writes what an extension filled in, and a value only
        // the log could hold is the only way to prove it.
        'cqZone': 9,
        'ituZone': 8,
        'qslVia': 'LoTW',
        'url': 'https://www.arrl.org/w1aw',
      },
    },
    'band': '20m',
    'mode': 'SSB',
    'freq': 14250.0,
    'power': 100,
    'notes': 'first QSO of the day',
    'startAtMillis': DateTime.utc(2026, 7, 1, 12).millisecondsSinceEpoch,
    'endAtMillis': DateTime.utc(2026, 7, 1, 12, 3).millisecondsSinceEpoch,
  };

  Future<String> export({
    required bool includePrivateData,
    Map<String, dynamic>? qsoOverrides,
    Map<String, dynamic>? operationOverrides,
    List<Map<String, dynamic>>? qsos,
    List<Map<String, dynamic>>? events,
  }) async {
    final host = await sharedHost(['adif'], cacheKey: 'adif-fields');
    final result =
        await host.invokeHook(
              'export',
              key: 'adif',
              method: 'generateExport',
              args: {
                'operation': operation()..addAll(operationOverrides ?? const {}),
                'qsos': qsos ?? [qso()..addAll(qsoOverrides ?? const {})],
                'events': ?events,
                'exportType': 'adif',
                'includePrivateData': includePrivateData,
              },
              timeout: const Duration(seconds: 20),
            )
            as Map;
    return result['content'] as String;
  }

  test('the contact carries the entity, the zones and the power a program reads', () async {
    final content = await export(includePrivateData: true);

    expect(content, contains('<DXCC:3>291'));
    expect(content, contains('<CONT:2>NA'));
    expect(content, contains('<TX_PWR:3>100'));
    expect(content, contains('<RX_PWR:1>5'));
  }, timeout: const Timeout(Duration(seconds: 60)));

  // The zones are REPORTED, not worked out here: resolving a callsign belongs
  // to the lookup layer, which did it once when the contact was logged. An
  // exporter that re-derived them could state a zone the operator never saw,
  // and would overrule whatever an extension had filled in.
  test('the zones are the ones the log holds', () async {
    final content = await export(includePrivateData: true);

    expect(content, contains('<CQZ:1>9'), reason: "the guess's zone, odd as it is, is what the log says");
    expect(content, contains('<ITUZ:1>8'));
  }, timeout: const Timeout(Duration(seconds: 60)));

  // An operation records a callsign and no entity, so these are resolved from
  // it — the three a callsign settles outright.
  test('our own entity is resolved from the station call', () async {
    final content = await export(includePrivateData: true);

    expect(content, contains('<MY_DXCC:3>291'));
    expect(content, contains('<MY_COUNTRY:13>United States'));
    expect(content, contains('<MY_CONT:2>NA'));
    expect(content, contains('<MY_STATE:2>CA'));
    expect(content, contains('<MY_RIG:6>FT-891'));
    expect(content, contains('<MY_ANTENNA:4>EFHW'));
  }, timeout: const Timeout(Duration(seconds: 60)));

  // An operation records no entity, but a CONTACT can: an ADIF import writes
  // `our.entityName`/`dxccCode`/`continent` from MY_COUNTRY/MY_DXCC/MY_CONT. A
  // log made from Hawaii under a mainland call says 110 where the callsign says
  // 291, and re-deriving would answer the wrong entity through the very round
  // trip these fields exist to keep whole.
  test('an entity the contact carries outranks one resolved from the call', () async {
    final host = await sharedHost(['adif'], cacheKey: 'adif-fields');
    final imported = qso()..['our'] = {'call': 'N0DEV', 'sent': '59', 'dxccCode': 110, 'entityName': 'Hawaii', 'continent': 'OC', 'regionCode': 'HI'};
    final result =
        await host.invokeHook(
              'export',
              key: 'adif',
              method: 'generateExport',
              args: {
                'operation': operation(),
                'qsos': [imported],
                'exportType': 'adif',
                'includePrivateData': true,
              },
              timeout: const Duration(seconds: 20),
            )
            as Map;
    final content = result['content'] as String;

    expect(content, contains('<MY_DXCC:3>110'));
    expect(content, contains('<MY_COUNTRY:6>Hawaii'));
    expect(content, contains('<MY_CONT:2>OC'));
    expect(content, contains('<MY_REGION:2>HI'));
    // The station call still resolves to 291 — that is what must NOT win here.
    // (The worked station's own DXCC is 291 too, hence the MY_ prefix.)
    expect(content, isNot(contains('<MY_DXCC:3>291')));
  }, timeout: const Timeout(Duration(seconds: 60)));

  // Which zone of an entity a station is in does not follow from its callsign,
  // so these are reported like every other stored value. A country file would
  // answer 4 and 7 for N0DEV; the log says otherwise, and the log wins.
  test('our own zones are read, never resolved from the call', () async {
    final content = await export(includePrivateData: true);

    expect(content, contains('<MY_CQ_ZONE:2>31'));
    expect(content, contains('<MY_ITU_ZONE:2>61'));
  }, timeout: const Timeout(Duration(seconds: 60)));

  // Left unwritten rather than guessed.
  test('an operation with no zones recorded writes none', () async {
    final host = await sharedHost(['adif'], cacheKey: 'adif-fields');
    final bare = qso()..['our'] = {'call': 'N0DEV', 'sent': '59'};
    final result =
        await host.invokeHook(
              'export',
              key: 'adif',
              method: 'generateExport',
              args: {
                'operation': operation(),
                'qsos': [bare],
                'exportType': 'adif',
                'includePrivateData': true,
              },
              timeout: const Duration(seconds: 20),
            )
            as Map;

    expect(result['content'] as String, isNot(contains('MY_CQ_ZONE')));
    expect(result['content'] as String, isNot(contains('MY_ITU_ZONE')));
    // The three that DO follow from the call are still there.
    expect(result['content'] as String, contains('<MY_DXCC:3>291'));
  }, timeout: const Timeout(Duration(seconds: 60)));

  // ADIF's CNTY is `STATE,COUNTY`, and QSON's `county` reaches the exporter in
  // three shapes depending on who wrote it (see adifCounty). A lookup writes
  // the bare name, which is not a CNTY until the state qualifies it.
  test('a county is qualified by its state on both sides', () async {
    final content = await export(includePrivateData: true);

    expect(content, contains('<CNTY:11>CT,Hartford'));
    expect(content, contains('<MY_CNTY:8>CA,Marin'));
    // Asserted here so the withholding test below is testing something: a
    // field the export never writes at all is trivially absent.
    expect(content, contains('<EMAIL:16>w1aw@example.org'));
  }, timeout: const Timeout(Duration(seconds: 60)));

  // What a QSL card needs, from the lookup that found it. ADDRESS is a
  // MultilineString, so its lines break on CR LF.
  test('the mailing address, QSL route and web page reach the file with private data', () async {
    final content = await export(includePrivateData: true);

    const address = 'ARRL HQ\r\n225 Main St\r\nNewington, CT 06111\r\nUnited States';
    expect(content, contains('<ADDRESS:${address.length}>$address'));
    expect(content, contains('<QSL_VIA:4>LoTW'));
    expect(content, contains('<WEB:25>https://www.arrl.org/w1aw'));
  }, timeout: const Timeout(Duration(seconds: 60)));

  // An operator correcting a bad lookup's state leaves its county behind.
  // Qualifying it with the correction files Hartford County into Ontario;
  // qualifying it with the guess makes STATE and CNTY name two different
  // primary subdivisions in one record. Neither is true of the contact.
  test('a county whose state has been overruled is not exported at all', () async {
    final host = await sharedHost(['adif'], cacheKey: 'adif-fields');
    final corrected = qso();
    (corrected['their'] as Map)['state'] = 'ON';
    (corrected['their'] as Map).remove('county');
    final result =
        await host.invokeHook(
              'export',
              key: 'adif',
              method: 'generateExport',
              args: {
                'operation': operation(),
                'qsos': [corrected],
                'exportType': 'adif',
                'includePrivateData': true,
              },
              timeout: const Duration(seconds: 20),
            )
            as Map;
    final content = result['content'] as String;

    expect(content, contains('<STATE:2>ON'));
    expect(content, isNot(contains('<CNTY:')), reason: 'our own MY_CNTY is unaffected and still there');
    expect(content, isNot(contains('Hartford')));
  }, timeout: const Timeout(Duration(seconds: 60)));

  // COMMENT is an ADIF String, which excludes line breaks; NOTES is a
  // MultilineString and keeps the operator's own. Writing a two-line note
  // into COMMENT verbatim is a field a strict reader rejects.
  test('a multi-line note keeps its lines in NOTES and loses them in COMMENT', () async {
    final host = await sharedHost(['adif'], cacheKey: 'adif-fields');
    final multiline = qso()..['notes'] = 'first line\nsecond line';
    final result =
        await host.invokeHook(
              'export',
              key: 'adif',
              method: 'generateExport',
              args: {
                'operation': operation(),
                'qsos': [multiline],
                'exportType': 'adif',
                'includePrivateData': true,
              },
              timeout: const Duration(seconds: 20),
            )
            as Map;
    final content = result['content'] as String;

    expect(content, contains('<NOTES:22>first line\nsecond line'));
    expect(content, contains('<COMMENT:22>first line second line'));
  }, timeout: const Timeout(Duration(seconds: 60)));

  // A grid and a coordinate are two statements about one place. `lat`/`lon`
  // are stored as explicit nulls where an operator typed a locator instead of
  // taking a fix, so reading them apart from the grid pairs a contact's own
  // square with whatever coordinate the operation last held — and
  // locations.md says the coordinate wins, so the record reads as a place the
  // operator never claimed.
  test('our grid and our coordinate come from one source', () async {
    final host = await sharedHost(['adif'], cacheKey: 'adif-fields');
    // The contact states a square and no fix; the operation holds a fix
    // somewhere else entirely.
    final roving = qso()..['our'] = {'call': 'N0DEV', 'sent': '59', 'grid': 'DM09aa'};
    final result =
        await host.invokeHook(
              'export',
              key: 'adif',
              method: 'generateExport',
              args: {
                'operation': {...operation(), 'lat': 37.86, 'lon': -122.48},
                'qsos': [roving],
                'exportType': 'adif',
                'includePrivateData': true,
              },
              timeout: const Duration(seconds: 20),
            )
            as Map;
    final content = result['content'] as String;

    expect(content, contains('<MY_GRIDSQUARE:6>DM09aa'));
    expect(content, isNot(contains('MY_LAT')), reason: 'the operation\'s fix is not where this contact was made');
    expect(content, isNot(contains('MY_LON')));
  }, timeout: const Timeout(Duration(seconds: 60)));

  // FREQ_RX equal to FREQ says "split" about a contact that wasn't one, so the
  // pair is written only where the two frequencies actually differ.
  test('a split contact records the frequency we listened on', () async {
    final content = await export(includePrivateData: true);

    expect(content, contains('<FREQ:5>14.25'));
    expect(content, contains('<FREQ_RX:6>14.275'));
    expect(content, contains('<BAND_RX:3>20m'));
  }, timeout: const Timeout(Duration(seconds: 60)));

  test('a contact that recorded an end writes TIME_OFF', () async {
    final content = await export(includePrivateData: true);

    expect(content, contains('<TIME_ON:6>120000'));
    expect(content, contains('<TIME_OFF:6>120300'));
    // Same day, so the date is not repeated — QSO_DATE_OFF exists for a
    // contact that crossed midnight.
    expect(content, isNot(contains('QSO_DATE_OFF')));
  }, timeout: const Timeout(Duration(seconds: 60)));

  test('the three free-text fields carry polo\'s defaults', () async {
    final content = await export(includePrivateData: true);

    expect(content, contains('<NOTES:20>first QSO of the day'));
    expect(content, contains('<COMMENT:20>first QSO of the day'));
    expect(content, contains('<QSLMSG:23>POTA US-0001 & KFF-0002'));
  }, timeout: const Timeout(Duration(seconds: 60)));

  // The switch a file uploaded to a program's servers is written under. Every
  // field added here had to be placed on one side of it or the other, and the
  // ones that describe a person rather than a contact belong on this one —
  // COMMENT most of all, since it says exactly what NOTES says under a name
  // that would otherwise slip past the gate.
  test('withholding private data withholds the person, not the contact', () async {
    final content = await export(includePrivateData: false);

    expect(content, isNot(contains('EMAIL')));
    expect(content, isNot(contains('ADDRESS')));
    expect(content, isNot(contains('225 Main St')));
    expect(content, isNot(contains('QSL_VIA')));
    expect(content, isNot(contains('<WEB:')));
    expect(content, isNot(contains('first QSO of the day')), reason: 'NOTES and COMMENT are both the operator\'s words');

    // Still a submittable log: everything implied by the callsign stays.
    expect(content, contains('<DXCC:3>291'));
    expect(content, contains('<CQZ:1>9'));
    expect(content, contains('<STATE:2>CT'));
    expect(content, contains('<MY_CQ_ZONE:2>31'));
    // The county rides with them: in a QSO party it is the exchange, so a
    // file that withheld it would claim nothing the event scores on.
    expect(content, contains('<CNTY:11>CT,Hartford'));
    expect(content, contains('<MY_CNTY:8>CA,Marin'));
    expect(content, contains('<QSLMSG:23>POTA US-0001 & KFF-0002'));
  }, timeout: const Timeout(Duration(seconds: 60)));

  test('a sideband the band runs is exported as plain SSB, with no SUBMODE', () async {
    // The log STORES the sideband — `RadioService` resolves every SSB request
    // to one — so an exporter that passes it straight through would state
    // `SUBMODE:USB` on every phone contact ever made on 20m. A reader that
    // shows the submode then reports a single-mode log as two modes, which is
    // the same thing the QSO list refuses to do.
    final content = await export(includePrivateData: true, qsoOverrides: {'mode': 'USB'});

    expect(content, contains('<MODE:3>SSB'));
    expect(content, isNot(contains('SUBMODE')));
  }, timeout: const Timeout(Duration(seconds: 60)));

  test('the sideband a band does NOT run is stated, because only that says something', () async {
    // 14250 kHz is upper anywhere; a contact recorded on lower there is either
    // deliberate or wrong, and both are things the file must carry. Dropping
    // this submode too would make the export lossy in the one case it matters.
    final content = await export(includePrivateData: true, qsoOverrides: {'mode': 'LSB'});

    expect(content, contains('<MODE:3>SSB'));
    expect(content, contains('<SUBMODE:3>LSB'));
  }, timeout: const Timeout(Duration(seconds: 60)));

  test('a submode that names the emission is never dropped', () async {
    // Guards the suppression above from widening: `FT4` reaches ADIF as
    // MODE=MFSK SUBMODE=FT4, and losing that submode loses which mode was
    // worked — where losing a sideband loses nothing the band does not say.
    final content = await export(includePrivateData: true, qsoOverrides: {'mode': 'FT4'});

    expect(content, contains('<MODE:4>MFSK'));
    expect(content, contains('<SUBMODE:3>FT4'));
  }, timeout: const Timeout(Duration(seconds: 60)));

  test('a sideband with no band to vouch for it is written, not dropped', () async {
    // "Nothing contradicts it" is true both of a sideband that matches the
    // band and of a contact that has no band at all — and only the first can
    // be re-derived by a reader. Dropping the second takes the sideband out of
    // the log for good, which is the opposite of what the suppression is for.
    final content = await export(includePrivateData: true, qsoOverrides: {'mode': 'LSB', 'freq': null, 'band': null});

    expect(content, contains('<MODE:3>SSB'));
    expect(content, contains('<SUBMODE:3>LSB'));
  }, timeout: const Timeout(Duration(seconds: 60)));

  group('the log around the contacts', () {
    final noon = DateTime.utc(2026, 7, 1, 12).millisecondsSinceEpoch;
    List<Map<String, dynamic>> twoContacts() => [
      qso(),
      qso()
        ..['uuid'] = 'q1'
        ..['their'] = {'call': 'K2ABC'}
        ..['startAtMillis'] = noon + 20 * 60000,
    ];
    List<Map<String, dynamic>> events() => [
      {
        'uuid': 'e1',
        'band': 'event',
        'startAtMillis': noon + 10 * 60000,
        'event': {
          'event': 'break',
          'description': 'moved • to the summit',
          'operation': {'grid': 'CM88'},
        },
      },
      // Sharing the second contact's instant: the contact is the new
      // segment's, so the event that opens it comes first.
      {
        'uuid': 'e2',
        'band': 'event',
        'startAtMillis': noon + 20 * 60000,
        'event': {'event': 'note', 'note': 'antenna swapped'},
      },
      {
        'uuid': 'e3',
        'band': 'event',
        'startAtMillis': noon + 30 * 60000,
        'event': {'event': 'stop'},
      },
    ];

    test('the full ADIF keeps the breaks and notes, each before the contact it precedes', () async {
      // Without them a log kept as ADIF loses where it moved and why: the
      // segments live in these rows, not in any contact.
      final content = await export(includePrivateData: true, qsos: twoContacts(), events: events());

      final firstContact = content.indexOf('<CALL:4>W1AW');
      final secondContact = content.indexOf('<CALL:5>K2ABC');
      final breakAt = content.indexOf('<APP_HAM2K_BREAK:');
      final noteAt = content.indexOf('<APP_HAM2K_NOTE:');
      expect(firstContact, greaterThan(content.indexOf('<EOH>')));
      expect(breakAt, allOf(greaterThan(firstContact), lessThan(secondContact)));
      expect(noteAt, allOf(greaterThan(breakAt), lessThan(secondContact)));
      expect(content, contains('2026-07-01T12:10:00Z: moved * to the summit'));
      expect(content, contains('antenna swapped'));
    }, timeout: const Timeout(Duration(seconds: 60)));

    test('an event after the last contact still lands inside a record', () async {
      // After the final <EOR> it is an unterminated record with no callsign,
      // and reading the operator's own backup back reports a broken contact.
      final content = await export(includePrivateData: true, qsos: twoContacts(), events: events());

      final stopAt = content.indexOf('<APP_HAM2K_STOP:');
      expect(stopAt, isNonNegative, reason: 'dropping it loses how the log ended');
      expect(stopAt, lessThan(content.indexOf('<CALL:5>K2ABC')));
      expect(content.trimRight(), endsWith('<EOR>'));
    }, timeout: const Timeout(Duration(seconds: 60)));

    test('an event whose note is not text writes its kind, not [object Object]', () async {
      final content = await export(
        includePrivateData: true,
        events: [
          {
            'uuid': 'e9',
            'band': 'event',
            'startAtMillis': noon - 60000,
            'event': {
              'event': 'note',
              'note': {'rich': true},
            },
          },
        ],
      );

      expect(content, contains('2026-07-01T11:59:00Z: note'));
      expect(content, isNot(contains('[object Object]')));
    }, timeout: const Timeout(Duration(seconds: 60)));

    test('a file without private data carries none of them', () async {
      final content = await export(includePrivateData: false, qsos: twoContacts(), events: events());

      expect(content, isNot(contains('APP_HAM2K_BREAK')));
      expect(content, isNot(contains('APP_HAM2K_NOTE')));
    }, timeout: const Timeout(Duration(seconds: 60)));

    test("the header names the operation's title and notes, with private data only", () async {
      // A note quoting `<EOH>` would end the header there for any reader that
      // looks for the tag, and file the rest of it as a contact.
      final overrides = {'userTitle': 'Dad\'s memorial activation', 'notes': 'ended early, see <EOH> below'};
      final private = await export(includePrivateData: true, operationOverrides: overrides);
      final header = private.substring(0, private.indexOf('<EOH>'));

      expect(header, matches(RegExp(r"<APP_HAM2K_OP_TITLE:\d+>Dad's memorial activation")));
      expect(header, contains('APP_HAM2K_OP_NOTES'));
      expect(header, contains('see &lt;EOH&gt; below'));

      final public = await export(includePrivateData: false, operationOverrides: overrides);
      expect(public, isNot(contains('APP_HAM2K_OP_')));
    }, timeout: const Timeout(Duration(seconds: 60)));
  });
}
