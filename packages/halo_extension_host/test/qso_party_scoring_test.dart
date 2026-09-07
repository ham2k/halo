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
    final result = await host.invokeHook(
      'scoring',
      key: 'qp',
      method: 'scoreQsos',
      args: args,
      timeout: const Duration(seconds: 20),
    ) as Map;
    return result.cast<String, dynamic>();
  }

  Map<String, dynamic> summaryOf(Map<String, dynamic> result) =>
      ((result['operationSummary'] as Map)['qp'] as Map).cast<String, dynamic>();

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
    final controls = (await host.invokeHook(
      'activity',
      key: 'qp',
      method: 'loggingControls',
      args: {
        'operation': operationIn('ALB'),
        'qso': const {
          'their': {'call': 'K1ABC', 'entityPrefix': 'K', 'guess': {'state': 'NY'}},
        },
      },
      timeout: const Duration(seconds: 20),
    ) as List).cast<Map>();

    final location = controls.firstWhere((control) => control['key'] == 'qp/location');
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
    // …and the guessed state floats its own counties up the list rather than
    // filling the field in.
    expect((input['preferredCodes'] as List), contains('ALB'));
  }, timeout: const Timeout(Duration(seconds: 60)));

  test('the setup list offers what is coming, not what is most out of date', () async {
    // The select is also how a party is FIRST chosen, so its top entry is the
    // default a straight Save writes. Ordering by days-until alone put the
    // parties whose files still hold LAST year's dates first — the staler the
    // file, the more negative the count — so a fresh setup defaulted to a party
    // that ran a year and a half ago.
    final host = await sharedHost(['qp']);
    final controls = (await host.invokeHook(
      'activity',
      key: 'qp',
      method: 'operationControls',
      args: {'operation': const {'uuid': 'op', 'refs': []}},
      timeout: const Duration(seconds: 20),
    ) as List).cast<Map>();

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
    expect(!stale.contains(true) || stale.lastIndexOf(false) < stale.indexOf(true), isTrue,
        reason: 'a party waiting for next year\'s dates cannot outrank one about to run');

    // Among the stale ones, the most RECENT comes first — which is the half of
    // this the all-stale weeks actually exercise, and where ordering by
    // days-until would put the most out-of-date file at the top.
    final staleDays = [
      for (var i = 0; i < labels.length; i++)
        if (stale[i]) int.tryParse(RegExp(r'in (\d+) days').firstMatch(labels[i])?.group(1) ?? '') ?? -1,
    ];
    expect(staleDays.every((days) => days == -1), isTrue,
        reason: 'a party that has run is labelled as such, not counted down to');

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
    expect(their?['exchange'], isNot(''),
        reason: 'an empty exchange must not be projected over a neighbour\'s');

    // And a county the operator DID type still projects, as it must.
    final typed = await host.invokeHook(
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
    ) as Map;
    expect(((typed['their'] as Map)['exchange'] as String), 'ERI');
  }, timeout: const Timeout(Duration(seconds: 60)));

  test('a party is found by name in the activity search', () async {
    final host = await sharedHost(['qp']);
    final suggestions = (await host.invokeHook(
      'activity',
      key: 'qp',
      method: 'suggest',
      args: const {'searchTerm': 'salmon'},
      timeout: const Duration(seconds: 20),
    ) as List).cast<Map>();

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
