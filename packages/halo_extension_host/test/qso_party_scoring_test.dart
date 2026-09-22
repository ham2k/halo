// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The QSO-party extension through the REAL runtime (docs/design/contests.md
// M10). Its rules are unit-tested inside the bundle; what can only be seen from
// here is that the bundle registers, that the descriptors it publishes are the
// shapes the app renders, and — the milestone's own claim — that a rover's
// county comes from the SEGMENT the contact was made in, which no test inside
// the extension can reach because the harness resolves it.

import 'package:flutter_test/flutter_test.dart';

import 'support/bundles.dart';

void main() {
  requireBundles();

  // The New York QSO Party: a county line party, 2 points a CW contact, and
  // `stateCountsForInState` — so an in-state contact is two multipliers.
  Map<String, dynamic> qso(int i, String call, String county, {String band = '20m'}) => {
    'uuid': 'q$i',
    'startAtMillis': DateTime.utc(2026, 10, 17, 14, i).millisecondsSinceEpoch,
    'band': band,
    'mode': 'CW',
    'our': {'call': 'N0DEV'},
    'their': {'call': call, 'entityPrefix': 'K'},
    'refs': [
      {'type': 'qp', 'location': county},
    ],
  };

  Map<String, dynamic> operationIn(String county) => {
    'uuid': 'op',
    'stationCall': 'N0DEV',
    'refs': [
      {'type': 'qp', 'ref': 'NY', 'location': county},
    ],
  };

  Future<Map<String, dynamic>> score(Map<String, dynamic> args) async {
    final host = await sharedHost(['qp']);
    final result = await host.invokeHook('scoring', key: 'qp', method: 'scoreQsos', args: args, timeout: const Duration(seconds: 20)) as Map;
    return result.cast<String, dynamic>();
  }

  Map<String, dynamic> summaryOf(Map<String, dynamic> result) => ((result['operationSummary'] as Map)['qp'] as Map).cast<String, dynamic>();

  test('a county line is worth every pairing, through the real runtime', () async {
    // Two counties each side: four contacts' worth of points from one exchange,
    // and the multipliers to match. This is the whole of M10 in one QSO, and it
    // also proves the bundle registers its scorer under the ref type at all.
    final result = await score({
      'operation': operationIn('ALB/REN'),
      'qsos': [qso(0, 'K1ABC', 'ERI/CHA')],
      'ref': {'type': 'qp', 'ref': 'NY', 'location': 'ALB/REN'},
    });

    final summary = summaryOf(result);
    expect(summary['points'], 2 * 2 * 2);
    // ERI, CHA and NY itself — the party counts its own state for an in-state
    // entrant.
    expect(summary['mults'], 3);
  }, timeout: const Timeout(Duration(seconds: 60)));

  test('a rover who breaks into a new county may work the same station again', () async {
    // The claim M10 is named for. The base operation says Albany; a break
    // restates the ref as Rensselaer, and the second contact with K1ABC is a
    // new county pair rather than a duplicate. Were the segment ignored, the
    // second QSO would score nothing and the log would be worth half as much.
    final qsos = [qso(0, 'K1ABC', 'ERI'), qso(10, 'K1ABC', 'ERI')];
    final breakAt = qsos[1]['startAtMillis'] as int;

    final rolling = await score({
      'operation': operationIn('ALB'),
      'qsos': qsos,
      'ref': {'type': 'qp', 'ref': 'NY', 'location': 'ALB'},
      'segments': [
        // -1 << 62, as SegmentedOperation writes the first segment's start.
        {'fromMillis': -4611686018427387904, 'operation': operationIn('ALB')},
        {'fromMillis': breakAt, 'operation': operationIn('REN')},
      ],
    });
    expect(summaryOf(rolling)['qsos'], 2);
    expect(summaryOf(rolling)['points'], 4);

    // The same log without the break: the second contact is the duplicate it
    // would be if the operator had never moved.
    final parked = await score({
      'operation': operationIn('ALB'),
      'qsos': qsos,
      'ref': {'type': 'qp', 'ref': 'NY', 'location': 'ALB'},
    });
    expect(summaryOf(parked)['qsos'], 1);
    expect(summaryOf(parked)['points'], 2);
  }, timeout: const Timeout(Duration(seconds: 60)));

  test('the exchange field is a searchable set, and takes a county line', () async {
    final host = await sharedHost(['qp']);
    final controls =
        (await host.invokeHook(
                  'activity',
                  key: 'qp',
                  method: 'loggingControls',
                  args: {
                    'operation': operationIn('ALB'),
                    'qso': const {
                      'their': {
                        'call': 'K1ABC',
                        'entityPrefix': 'K',
                        'guess': {'state': 'NY'},
                      },
                    },
                  },
                  timeout: const Duration(seconds: 20),
                )
                as List)
            .cast<Map>();

    final location = controls.firstWhere((control) => control['key'] == 'qp/location');
    // The field says which activity wants it, not what the sponsor calls a
    // county: in a row of four-character fields "County" does not distinguish
    // it from the State beside it, and is wrong for everyone sending a state
    // or a province. The short form is what a squeezed field shows.
    expect(location['label'], 'QP Location');
    expect(location['shortLabel'], 'QP Loc');
    final input = (location['input'] as Map).cast<String, dynamic>();
    expect(input['kind'], 'options');
    expect(input['field'], 'location');
    // New York is a county-line party, so the field accepts two values.
    expect((input['multiValue'] as Map)['separator'], '/');
    // The set is the party's counties plus the states an out-of-state station
    // sends — narrowed to what a US station could possibly say.
    final codes = (input['options'] as List).map((option) => (option as Map)['code']).toSet();
    expect(codes, contains('ALB'));
    expect(codes, contains('NJ'));
    // …and never the party's OWN state. An in-state caller sends a county and
    // nobody else is in New York, so `NY` is an exchange no station could have
    // given — and it resolves cleanly, which is exactly why the field has to
    // refuse it rather than score the contact under out-of-party rules.
    expect(codes, isNot(contains('NY')));
    // …and the guessed state floats its own counties up the list. Nothing is
    // filled in here: this caller is IN the party, so what they send is a
    // county, and `NY` would be a state multiplier claimed for a county nobody
    // copied.
    expect((input['preferredCodes'] as List), contains('ALB'));
    // An in-party caller's own state is not an exchange anyone sends, so it is
    // a hint — which New York station this is — while the county goes in.
    expect(input.containsKey('suggestedValue'), isFalse);
    expect(input['placeholder'], 'NY');
  }, timeout: const Timeout(Duration(seconds: 60)));

  test('the lookup fills in what the log would claim — a DX caller included', () async {
    // The prefill is what the log will claim if nothing is typed — the same
    // function the scorer and both exports fall back to — so a prefill left
    // alone changes nothing about the log, and the operator sees the value
    // it will carry rather than finding out afterwards.
    final host = await sharedHost(['qp']);
    Future<Map<String, dynamic>> inputFor(Map<String, dynamic> their) async {
      final controls =
          (await host.invokeHook(
                    'activity',
                    key: 'qp',
                    method: 'loggingControls',
                    args: {
                      'operation': operationIn('ALB'),
                      'qso': {'their': their},
                    },
                    timeout: const Duration(seconds: 20),
                  )
                  as List)
              .cast<Map>();
      return ((controls.firstWhere((control) => control['key'] == 'qp/location'))['input'] as Map).cast<String, dynamic>();
    }

    // Out of the party: the state IS what they will send.
    final pa = await inputFor({
      'call': 'W3WC',
      'entityPrefix': 'K',
      'guess': {'state': 'PA'},
    });
    expect(pa['suggestedValue'], 'PA');
    expect(pa.containsKey('placeholder'), isFalse);

    // DX: nobody asks them to type an exchange, and this is what the file
    // writes for them.
    final dx = await inputFor({'call': 'DL1ABC', 'entityPrefix': 'DL'});
    expect(dx['suggestedValue'], 'DX');
  }, timeout: const Timeout(Duration(seconds: 60)));

  test('what a station sent us earlier is offered back, ahead of any guess', () async {
    // Not a guess at all: an exchange the operator already copied from this
    // same station. The scorer and both exports already fall back to it for a
    // blank second-band contact, so offering it in the field is the operator
    // confirming what the log would otherwise assume silently.
    // An in-state caller, whose exchange is a COUNTY — the case no lookup can
    // help with, and where nothing was offered at all before this.
    Map<String, dynamic>? asked;
    final log = [
      {
        'their': {'call': 'K2ABC'},
        'band': '20m',
        'refs': [
          {'type': 'qp', 'location': 'ERI'},
        ],
      },
    ];
    final host = await sharedHost(
      ['qp'],
      onHostCall: (method, params) async {
        if (method != 'getHistoryForCall') return null;
        asked = params;
        return log;
      },
      cacheKey: 'qp-prior-exchange',
    );
    final controls =
        (await host.invokeHook(
                  'activity',
                  key: 'qp',
                  method: 'loggingControls',
                  args: {
                    'operation': operationIn('ALB'),
                    'qso': const {
                      'their': {
                        'call': 'K2ABC',
                        'entityPrefix': 'K',
                        'guess': {'state': 'NY'},
                      },
                    },
                  },
                  timeout: const Duration(seconds: 20),
                )
                as List)
            .cast<Map>();

    final input = ((controls.firstWhere((control) => control['key'] == 'qp/location'))['input'] as Map).cast<String, dynamic>();
    // The county they gave on the first band. The lookup knows only `NY`,
    // which is not an exchange anybody sends and is not offered at all.
    expect(input['suggestedValue'], 'ERI');
    // Asked of the host for THIS operation and this activity — a handful of
    // indexed rows, not the whole log. Unfiltered, a station worked in last
    // year's party would have last year's county offered back.
    expect(asked?['call'], 'K2ABC');
    expect(asked?['operation'], 'op');
    expect(asked?['refType'], 'qp');
  }, timeout: const Timeout(Duration(seconds: 60)));

  test('with nothing from this operation, an earlier running of the party is asked', () async {
    // An in-state caller on their first contact: no lookup knows their county,
    // and this operation has none yet — but last year's NYQP does. Found
    // through the OPERATION's party ref, which past HaLo and PoLo logs both
    // carry, and never this operation's own contacts, which were asked first.
    final asked = <Map<String, dynamic>>[];
    final lastYear = [
      {
        'their': {'call': 'K2ABC'},
        'band': '40m',
        'refs': [
          {'type': 'qp', 'location': 'SUL'},
        ],
      },
    ];
    final host = await sharedHost(
      ['qp'],
      onHostCall: (method, params) async {
        if (method != 'getHistoryForCall') return null;
        asked.add(params);
        return params.containsKey('excludeOperation') ? lastYear : const <Map<String, dynamic>>[];
      },
      cacheKey: 'qp-past-running',
    );
    final controls =
        (await host.invokeHook(
                  'activity',
                  key: 'qp',
                  method: 'loggingControls',
                  args: {
                    'operation': operationIn('ALB'),
                    'qso': const {
                      'their': {
                        'call': 'K2ABC',
                        'entityPrefix': 'K',
                        'guess': {'state': 'NY'},
                      },
                    },
                  },
                  timeout: const Duration(seconds: 20),
                )
                as List)
            .cast<Map>();

    final input = ((controls.firstWhere((control) => control['key'] == 'qp/location'))['input'] as Map).cast<String, dynamic>();
    expect(input['suggestedValue'], 'SUL');
    expect(asked, hasLength(2), reason: 'this operation first, then earlier runnings');
    expect(asked[0]['operation'], 'op');
    expect(asked[1]['refType'], 'qp');
    expect(asked[1]['refPrefix'], 'NY', reason: 'the party, found through the operation ref');
    expect(asked[1]['excludeOperation'], 'op');
  }, timeout: const Timeout(Duration(seconds: 60)));

  test("a Hawaiian in the Hawaii QSO Party is hinted their state, not handed it", () async {
    // A Hawaiian is the one station that sends a Hawaii multiplier, so the
    // list is theirs to pick from — and their fallback location, `HI`, is the
    // party's own state: prefilled, it would log them as an out-of-party state
    // for a multiplier nobody copied, so it is a hint like `NY` in NYQP.
    final host = await sharedHost(['qp']);
    final controls =
        (await host.invokeHook(
                  'activity',
                  key: 'qp',
                  method: 'loggingControls',
                  args: {
                    'operation': const {
                      'uuid': 'op',
                      'stationCall': 'N0DEV',
                      'refs': [
                        {'type': 'qp', 'ref': 'HI', 'location': 'HIL'},
                      ],
                    },
                    'qso': const {
                      'their': {'call': 'KH6ABC', 'entityPrefix': 'KH6'},
                    },
                  },
                  timeout: const Duration(seconds: 20),
                )
                as List)
            .cast<Map>();

    final input = ((controls.firstWhere((control) => control['key'] == 'qp/location'))['input'] as Map).cast<String, dynamic>();
    expect(input.containsKey('suggestedValue'), isFalse);
    expect(input['placeholder'], 'HI');
    final codes = (input['options'] as List).map((option) => (option as Map)['code']).toSet();
    expect(codes, contains('HON'), reason: 'the Hawaii multipliers, to pick from and to be checked against');
    expect(input['allowFreeform'], isFalse);
  }, timeout: const Timeout(Duration(seconds: 60)));

  test('a history the host could not answer offers nothing, not an earlier running', () async {
    // "Could not ask about this operation" is not "never worked them here":
    // read as the second, last year's county would answer over one the
    // operator may have copied minutes ago. Nothing is offered, the field
    // still comes up, and the lookup's hint is still there.
    final host = await sharedHost(
      ['qp'],
      onHostCall: (method, params) async {
        if (method != 'getHistoryForCall') return null;
        if (params.containsKey('operation')) throw const FormatException('history unavailable');
        return [
          {
            'their': {'call': 'K2ABC'},
            'band': '40m',
            'refs': [
              {'type': 'qp', 'location': 'SUL'},
            ],
          },
        ];
      },
      cacheKey: 'qp-history-fails',
    );
    final controls =
        (await host.invokeHook(
                  'activity',
                  key: 'qp',
                  method: 'loggingControls',
                  args: {
                    'operation': operationIn('ALB'),
                    'qso': const {
                      'their': {
                        'call': 'K2ABC',
                        'entityPrefix': 'K',
                        'guess': {'state': 'NY'},
                      },
                    },
                  },
                  timeout: const Duration(seconds: 20),
                )
                as List)
            .cast<Map>();

    final input = ((controls.firstWhere((control) => control['key'] == 'qp/location'))['input'] as Map).cast<String, dynamic>();
    expect(input.containsKey('suggestedValue'), isFalse, reason: "last year's SUL must not answer for this operation");
    expect(input['placeholder'], 'NY');
  }, timeout: const Timeout(Duration(seconds: 60)));

  test('an empty entry row suggests nothing, and never reads the log for it', () async {
    // The controls are fetched with no QSO at all on every operation change,
    // from the spots panel and from an import. There is no caller, so there
    // is nothing to suggest — without `defaultTheirLocation`'s no-entity guard
    // every empty row would offer `DX` — and a whole-log read would be paid
    // for an answer none of those callers can use.
    var logReads = 0;
    final host = await sharedHost(
      ['qp'],
      onHostCall: (method, params) async {
        if (method == 'getQsos' || method == 'getHistoryForCall') logReads++;
        return method == 'getQsos' || method == 'getHistoryForCall' ? const <Map<String, dynamic>>[] : null;
      },
      cacheKey: 'qp-no-qso',
    );
    final controls =
        (await host.invokeHook('activity', key: 'qp', method: 'loggingControls', args: {'operation': operationIn('ALB')}, timeout: const Duration(seconds: 20))
                as List)
            .cast<Map>();

    final input = ((controls.firstWhere((control) => control['key'] == 'qp/location'))['input'] as Map).cast<String, dynamic>();
    expect(input.containsKey('suggestedValue'), isFalse);
    expect(input.containsKey('placeholder'), isFalse);
    expect(logReads, 0);
  }, timeout: const Timeout(Duration(seconds: 60)));

  test('the setup list offers what is coming, not what is most out of date', () async {
    // The select is also how a party is FIRST chosen, so its top entry is the
    // default a straight Save writes. Ordering by days-until alone put the
    // parties whose files still hold LAST year's dates first — the staler the
    // file, the more negative the count — so a fresh setup defaulted to a party
    // that ran a year and a half ago.
    final host = await sharedHost(['qp']);
    final controls =
        (await host.invokeHook(
                  'activity',
                  key: 'qp',
                  method: 'operationControls',
                  args: {
                    'operation': const {'uuid': 'op', 'refs': []},
                  },
                  timeout: const Duration(seconds: 20),
                )
                as List)
            .cast<Map>();

    final elements = ((controls.single['input'] as Map)['form'] as Map)['elements'] as List;
    final picker = (elements.first as Map).cast<String, dynamic>();
    expect(picker['key'], 'ref');
    final labels = (picker['options'] as List).map((o) => (o as Map)['label'] as String).toList();
    final stale = [for (final label in labels) label.contains('already happened')];

    // Every party whose dates have all passed sits below every party that has
    // not run yet — asserted as an ORDERING, not against the calendar: for a
    // few weeks each year, until the files are re-synced, every party is stale,
    // and a test demanding an upcoming one at the top would fail on a date with
    // no code change at all. `./scripts/test.sh` is the only gate, so that
    // would be everyone's gate, red, for a reason nobody had changed.
    expect(
      !stale.contains(true) || stale.lastIndexOf(false) < stale.indexOf(true),
      isTrue,
      reason: 'a party waiting for next year\'s dates cannot outrank one about to run',
    );

    // Among the stale ones, the most RECENT comes first — which is the half of
    // this the all-stale weeks actually exercise, and where ordering by
    // days-until would put the most out-of-date file at the top.
    final staleDays = [
      for (var i = 0; i < labels.length; i++)
        if (stale[i]) int.tryParse(RegExp(r'in (\d+) days').firstMatch(labels[i])?.group(1) ?? '') ?? -1,
    ];
    expect(staleDays.every((days) => days == -1), isTrue, reason: 'a party that has run is labelled as such, not counted down to');

    // The default a Save would write is whatever sits at the top.
    expect(picker['value'], (picker['options'] as List).first['value']);
  }, timeout: const Timeout(Duration(seconds: 60)));

  test('a QSO party does not clobber another activity\'s exchange', () async {
    // `their.exchange` is one field shared by every activity on the operation,
    // and `mergeQsoPatch` merges `their` one level deep — so a hook that
    // projects an empty string unconditionally writes over whatever a co-active
    // contest just put there. A DX contact reaches this every time: no party
    // asks a DX station to send anything, so this extension has nothing to say
    // about one, and must say nothing rather than say "".
    final host = await sharedHost(['qp']);
    final patch = await host.invokeHook(
      'activity',
      key: 'qp',
      method: 'processQsoBeforeSave',
      args: {
        'operation': operationIn('ALB'),
        'qso': const {
          'their': {'call': 'DL1ABC', 'entityPrefix': 'DL'},
          'band': '20m',
          'mode': 'CW',
        },
      },
      timeout: const Duration(seconds: 20),
    );

    final their = (patch as Map?)?['their'] as Map?;
    expect(their?['exchange'], isNot(''), reason: 'an empty exchange must not be projected over a neighbour\'s');

    // And a county the operator DID type still projects, as it must.
    final typed =
        await host.invokeHook(
              'activity',
              key: 'qp',
              method: 'processQsoBeforeSave',
              args: {
                'operation': operationIn('ALB'),
                'qso': const {
                  'their': {'call': 'K1ABC', 'entityPrefix': 'K'},
                  'band': '20m',
                  'mode': 'CW',
                  'refs': [
                    {'type': 'qp', 'location': 'ERI'},
                  ],
                },
              },
              timeout: const Duration(seconds: 20),
            )
            as Map;
    expect(((typed['their'] as Map)['exchange'] as String), 'ERI');
  }, timeout: const Timeout(Duration(seconds: 60)));

  test('a party is found by name in the activity search', () async {
    final host = await sharedHost(['qp']);
    final suggestions =
        (await host.invokeHook('activity', key: 'qp', method: 'suggest', args: const {'searchTerm': 'salmon'}, timeout: const Duration(seconds: 20)) as List)
            .cast<Map>();

    // §5.6's discovery goal: one extension, 49 parties, each reachable by its
    // own name — including the one whose name says nothing about its state.
    expect(suggestions.map((s) => s['ref']), contains('WA'));
    // The suggestion path never calls decorateRef, so everything the activity
    // row shows has to be carried here.
    final salmon = suggestions.firstWhere((s) => s['ref'] == 'WA');
    expect(salmon['shortLabel'], isNotEmpty);
    expect(salmon['program'], 'Contest');
    // The subtitle carries the DATE the party runs: an operator scanning 47 of
    // them is choosing by when, and the name alone does not say whether this is
    // the weekend coming or one last February.
    expect(salmon['name'], matches(RegExp(r'^Washington Salmon Run • \d{4}-\d{2}-\d{2}$')));
  }, timeout: const Timeout(Duration(seconds: 60)));
}
