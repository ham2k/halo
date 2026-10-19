// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// +1m / 12:33 / :34 / 3/18 / NOW (time-commands extension), through the real
// bundled JS. The parsing is covered by the extension's own node tests; what
// these pin is what those cannot see — that the bundle is registered, that
// each form answers with the `setTime` action the logging panel dispatches,
// and that no OTHER command claims the same text first (a frequency, a band,
// a callsign note), since the panel runs whichever answers.

import 'package:flutter_test/flutter_test.dart';
import 'package:ham2k_logger/services/extensions/extension_service.dart';
import 'package:ham2k_logger/tools/date_order.dart';

import '../support/shipped_extensions.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ExtensionService extensions;

  setUp(() async {
    extensions = ExtensionService();
    prepareExtensionServiceForTest(extensions);
    await extensions.start();
  });

  Future<List<Map<String, dynamic>>> answers(String input, {Map<String, dynamic>? qso}) async {
    final entries = await extensions.host!.invokeHookAll(
      'command',
      method: 'interpret',
      args: {
        'input': input,
        'operation': {'stationCall': 'K2SUL'},
        'qso': ?qso,
      },
    );
    return [
      for (final entry in entries)
        if (entry['ok'] == true && entry['value'] is Map) (entry['value'] as Map).cast<String, dynamic>(),
    ];
  }

  Future<Map<String, dynamic>> setTimeOf(String input) async {
    final all = await answers(input);
    expect(all, hasLength(1), reason: '"$input" must be the time command\'s alone');
    return ((all.single['commands'] as List).cast<Map>().single['setTime'] as Map).cast<String, dynamic>();
  }

  test('every form answers with setTime, and only the time command answers', () async {
    expect(await setTimeOf('+1'), {'deltaMillis': 60000});
    expect(await setTimeOf('+30S'), {'deltaMillis': 30000});
    expect(await setTimeOf('-1H'), {'deltaMillis': -3600000});
    expect(await setTimeOf('12:33'), {'hour': 12, 'minute': 33});
    expect(await setTimeOf('12:33:30'), {'hour': 12, 'minute': 33, 'second': 30});
    expect(await setTimeOf(':34'), {'minute': 34});
    expect(await setTimeOf('::30'), {'second': 30});
    expect(await setTimeOf('NOW'), {'now': true});
  });

  test('a date reads in the order the device writes one', () async {
    final action = await setTimeOf(dateOrderFor() == 'dmy' ? '18/3' : '3/18');
    expect(action, {'month': 3, 'day': 18});
  });

  test('a Feb 29 in the contact\'s common year reads, and sets, Feb 28', () async {
    // The year is the contact's, which only the app knows: a preview saying
    // "February 29" while the app stamps the 28th misleads the operator.
    final input = dateOrderFor() == 'dmy' ? '29/2' : '2/29';
    final common = {'startAtMillis': DateTime.utc(2025, 5, 6).millisecondsSinceEpoch};
    final leap = {'startAtMillis': DateTime.utc(2024, 5, 6).millisecondsSinceEpoch};
    final inCommon = (await answers(input, qso: common)).single;
    expect(inCommon['confirm'], contains('February 28'));
    expect((inCommon['commands'] as List).single['setTime'], {'month': 2, 'day': 28});
    expect((await answers(input, qso: leap)).single['confirm'], contains('February 29'));
  });

  test('an impossible time is refused rather than logged as a callsign', () async {
    final all = await answers('25:00');
    expect(all.single['error'], isA<String>());
    expect(all.single['commands'], isNull);
  });

  test('the date order follows the region, not the language', () {
    expect(dateOrderFor('en_US'), 'mdy');
    expect(dateOrderFor('en_GB'), 'dmy');
    expect(dateOrderFor('es_ES'), 'dmy');
    expect(dateOrderFor('de_DE'), 'dmy');
    expect(dateOrderFor('ja_JP'), 'ymd');
    // A region intl has no pattern for falls back to its language's.
    expect(dateOrderFor('de_XX'), 'dmy');
    // ...except English, whose language pattern is the US one: English in
    // the Netherlands writes 18/3, in Puerto Rico 3/18.
    expect(dateOrderFor('en_NL'), 'dmy');
    expect(dateOrderFor('en-DE'), 'dmy');
    expect(dateOrderFor('en_PR'), 'mdy');
    expect(dateOrderFor('en'), 'mdy');
    // Year first, then the day: a two-part date reads day/month.
    expect(dateOrderFor('ky'), 'dmy');
  });
}
