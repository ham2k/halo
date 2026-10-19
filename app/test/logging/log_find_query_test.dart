// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// What the Find bar's text asks for. The three readings are told apart by the
// text alone, so each test is a reading that a looser rule would swap for
// another: a number taken for a callsign scrolls nowhere, and an exact call
// taken for a partial one buries the station among every call that holds it.

import 'package:flutter_test/flutter_test.dart';
import 'package:ham2k_logger/tools/log_find_query.dart';

void main() {
  test('digits alone are a QSO number, never a callsign', () {
    final query = LogFindQuery.parse(' 42 ')!;
    expect(query.number, 42);
    // A number filters nothing: the whole log stays on show to scroll in.
    expect(query.matchesCall('K1ABC'), isTrue);
  });

  test('a call with a digit in it is still a callsign', () {
    expect(LogFindQuery.parse('K1')!.number, isNull);
    expect(LogFindQuery.parse('1A')!.number, isNull);
  });

  test('a partial call matches anywhere in the callsign, whatever the case', () {
    final query = LogFindQuery.parse('k1a')!;
    expect(query.matchesCall('K1ABC'), isTrue);
    expect(query.matchesCall('WK1AX'), isTrue);
    expect(query.matchesCall('VE3/K1ABC'), isTrue);
    expect(query.matchesCall('K2ABC'), isFalse);
  });

  test('a trailing period asks for that exact callsign', () {
    final query = LogFindQuery.parse('K1AB.')!;
    expect(query.exact, isTrue);
    expect(query.matchesCall('K1AB'), isTrue);
    expect(query.matchesCall('k1ab'), isTrue);
    expect(query.matchesCall('K1ABC'), isFalse);
    expect(query.matchesCall('WK1AB'), isFalse);
  });

  test('digits with a trailing period are an exact callsign, not a number', () {
    final query = LogFindQuery.parse('123.')!;
    expect(query.number, isNull);
    expect(query.matchesCall('123'), isTrue);
  });

  test('nothing to find reads as no query at all', () {
    expect(LogFindQuery.parse(''), isNull);
    expect(LogFindQuery.parse('   '), isNull);
    expect(LogFindQuery.parse('.'), isNull);
  });
}
