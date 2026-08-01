// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The notice rule engine decides who sees a server notice. These tests pin
// the rules that matter — a notice targeted at the wrong version/platform/
// callsign/entity/country/region must NOT show, a `testCalls` whitelist must
// override the segment gate, dismissed notices stay gone, `notes` (which
// needs the call-notes extension this module has no access to) fails closed,
// and the adjust pass resolves platform-specific keys and templates. Pure
// logic, no runtime/network.

import 'package:flutter_test/flutter_test.dart';
import 'package:ham2k_logger/services/notices.dart';

void main() {
  NoticeContext ctx({
    String baseCall = 'KI2D',
    String call = 'KI2D',
    String? entityPrefix = 'K',
    String? continent = 'NA',
    String? countryCode = 'us',
    int? ituRegion = 2,
    String appVersion = '26.8.0',
    String appBuild = '1234',
    String platform = 'macos',
    Set<String> dismissedKeys = const {},
    DateTime? now,
  }) =>
      NoticeContext(
        baseCall: baseCall,
        call: call,
        entityPrefix: entityPrefix,
        continent: continent,
        countryCode: countryCode,
        ituRegion: ituRegion,
        appVersion: appVersion,
        appVersionName: "August '26",
        appBuild: appBuild,
        platform: platform,
        dismissedKeys: dismissedKeys,
        now: now ?? DateTime.utc(2026, 8, 1),
      );

  List<String> keys(List<EvaluatedNotice> ns) => ns.map((n) => n.key).toList();

  group('calculateCallSegment', () {
    test('is deterministic, 1-100, and 0 for empty', () {
      expect(calculateCallSegment(''), 0);
      expect(calculateCallSegment(null), 0);
      final seg = calculateCallSegment('KI2D');
      expect(seg, calculateCallSegment('KI2D'));
      expect(seg, inInclusiveRange(1, 100));
      expect(calculateCallSegment('W1AW'), isNot(seg));
    });
  });

  group('version and build filters', () {
    test('versions match by startsWith', () {
      final notices = [
        {'key': 'a', 'text': 'x', 'versions': ['26.8']},
        {'key': 'b', 'text': 'x', 'versions': ['26.7']},
      ];
      expect(keys(evaluateNotices(notices, ctx(appVersion: '26.8.0'))), ['a']);
    });

    test('exceptVersions hides a matching version', () {
      final notices = [
        {'key': 'a', 'text': 'x', 'exceptVersions': ['26.8']},
      ];
      expect(evaluateNotices(notices, ctx(appVersion: '26.8.0')), isEmpty);
    });

    test('builds match exactly', () {
      final notices = [
        {'key': 'a', 'text': 'x', 'builds': ['1234']},
        {'key': 'b', 'text': 'x', 'builds': ['9999']},
      ];
      expect(keys(evaluateNotices(notices, ctx(appBuild: '1234'))), ['a']);
    });
  });

  group('platform filter', () {
    test('only shows on listed platforms', () {
      final notices = [
        {'key': 'a', 'text': 'x', 'platforms': ['ios', 'android']},
        {'key': 'b', 'text': 'x', 'platforms': ['macos']},
      ];
      expect(keys(evaluateNotices(notices, ctx(platform: 'macos'))), ['b']);
    });
  });

  group('date window', () {
    test('respects dateFrom/dateTo', () {
      final notices = [
        {'key': 'past', 'text': 'x', 'dateTo': '2026-07-01T00:00:00Z'},
        {'key': 'future', 'text': 'x', 'dateFrom': '2026-09-01T00:00:00Z'},
        {'key': 'now', 'text': 'x', 'dateFrom': '2026-07-01T00:00:00Z', 'dateTo': '2026-09-01T00:00:00Z'},
      ];
      expect(keys(evaluateNotices(notices, ctx(now: DateTime.utc(2026, 8, 1)))), ['now']);
    });
  });

  group('callsign filters', () {
    test('calls matches the base call', () {
      final notices = [
        {'key': 'a', 'text': 'x', 'calls': ['ki2d']},
        {'key': 'b', 'text': 'x', 'calls': ['w1aw']},
      ];
      expect(keys(evaluateNotices(notices, ctx(baseCall: 'KI2D'))), ['a']);
    });

    test('testCalls whitelist overrides the segment gate', () {
      final seg = calculateCallSegment('KI2D');
      final notices = [
        {
          'key': 'a',
          'text': 'x',
          'testCalls': ['ki2d'],
          // A segment window the operator is NOT in — the whitelist wins.
          'segmentFrom': seg + 1,
          'segmentTo': 100,
        },
      ];
      expect(keys(evaluateNotices(notices, ctx(baseCall: 'KI2D'))), ['a']);
    });
  });

  group('segment gate', () {
    test('includes only operators inside the segment window', () {
      final seg = calculateCallSegment('KI2D');
      final inWindow = {'key': 'in', 'text': 'x', 'segmentFrom': seg, 'segmentTo': seg};
      final outWindow = {'key': 'out', 'text': 'x', 'segmentFrom': seg + 1, 'segmentTo': 100};
      expect(keys(evaluateNotices([inWindow, outWindow], ctx(baseCall: 'KI2D'))), ['in']);
    });
  });

  group('geo filters', () {
    test('entities match the DXCC entity prefix', () {
      final notices = [
        {'key': 'a', 'text': 'x', 'entities': ['K']},
        {'key': 'b', 'text': 'x', 'entities': ['G']},
      ];
      expect(keys(evaluateNotices(notices, ctx(entityPrefix: 'K'))), ['a']);
    });

    test('continents match', () {
      final notices = [
        {'key': 'a', 'text': 'x', 'continents': ['NA']},
        {'key': 'b', 'text': 'x', 'continents': ['EU']},
      ];
      expect(keys(evaluateNotices(notices, ctx(continent: 'NA'))), ['a']);
    });

    test('countries match by lowercase ISO code (HALO-52)', () {
      final notices = [
        {'key': 'a', 'text': 'x', 'countries': ['us']},
        {'key': 'b', 'text': 'x', 'countries': ['au']},
      ];
      expect(keys(evaluateNotices(notices, ctx(countryCode: 'us'))), ['a']);
    });

    test('ituRegions match by number (HALO-52)', () {
      final notices = [
        {'key': 'a', 'text': 'x', 'ituRegions': [2]},
        {'key': 'b', 'text': 'x', 'ituRegions': [1, 3]},
      ];
      expect(keys(evaluateNotices(notices, ctx(ituRegion: 2))), ['a']);
    });

    test('countries/ituRegions fail closed when the operator\'s own value is unknown', () {
      final notices = [
        {'key': 'c', 'text': 'x', 'countries': ['us']},
        {'key': 'i', 'text': 'x', 'ituRegions': [2]},
        {'key': 'ok', 'text': 'x'},
      ];
      expect(keys(evaluateNotices(notices, ctx(countryCode: null, ituRegion: null))), ['ok']);
    });

    test('notes fails closed (unsupported in HaLo — needs the call-notes extension)', () {
      final notices = [
        {'key': 'n', 'text': 'x', 'notes': true},
        {'key': 'ok', 'text': 'x'},
      ];
      expect(keys(evaluateNotices(notices, ctx())), ['ok']);
    });
  });

  group('dismissal and uniqueness', () {
    test('dismissed keys are skipped', () {
      final notices = [
        {'key': 'a', 'text': 'x'},
        {'key': 'b', 'text': 'x'},
      ];
      expect(keys(evaluateNotices(notices, ctx(dismissedKeys: {'a'}))), ['b']);
    });

    test('unique keeps only the first of a group', () {
      final notices = [
        {'key': 'a', 'text': 'x', 'unique': 'g'},
        {'key': 'b', 'text': 'x', 'unique': 'g'},
        {'key': 'c', 'text': 'x', 'unique': 'h'},
      ];
      expect(keys(evaluateNotices(notices, ctx())), ['a', 'c']);
    });
  });

  group('key de-duplication', () {
    test('keeps only the first matching notice for a given key', () {
      final notices = [
        {'key': 'k', 'text': 'x', 'title': 'first'},
        {'key': 'k', 'text': 'x', 'title': 'second'},
      ];
      final result = evaluateNotices(notices, ctx());
      expect(result, hasLength(1));
      expect(result.single.title, 'first');
    });

    test('a non-matching earlier same-key notice does not shadow a later match', () {
      final notices = [
        {'key': 'k', 'text': 'x', 'title': 'nomatch', 'versions': ['99.0']},
        {'key': 'k', 'text': 'x', 'title': 'match'},
      ];
      final result = evaluateNotices(notices, ctx(appVersion: '26.8.0'));
      expect(result, hasLength(1));
      expect(result.single.title, 'match');
    });

    test('picks the per-key representative by list order, not priority', () {
      // Which notice REPRESENTS a key is decided by list order (so a
      // higher-precedence source wins) — independent of the priority sort
      // that orders the final distinct set.
      final notices = [
        {'key': 'k', 'text': 'x', 'title': 'first', 'priority': 9},
        {'key': 'k', 'text': 'x', 'title': 'higher-priority', 'priority': 1},
      ];
      expect(evaluateNotices(notices, ctx()).single.title, 'first');
    });

    test('keyless notices are not de-duped', () {
      final notices = [
        {'text': 'a'},
        {'text': 'b'},
      ];
      final result = evaluateNotices(notices, ctx());
      expect(result.map((n) => n.text), ['a', 'b']);
    });

    test('the de-duped set is still priority-sorted, array order as tiebreaker', () {
      final notices = [
        {'key': 'a', 'text': 'x', 'priority': 5},
        {'key': 'b', 'text': 'x', 'priority': 1},
        {'key': 'a', 'text': 'x', 'priority': 1}, // dropped: 'a' already kept
        {'key': 'c', 'text': 'x'}, // no priority → last
        {'key': 'd', 'text': 'x', 'priority': 1}, // ties 'b' → array order
      ];
      // 'a' keeps its first entry (priority 5). Distinct set {a:5, b:1, d:1,
      // c:none} sorts to b, d (priority 1, b before d by array order), a
      // (priority 5), then c (no priority).
      expect(keys(evaluateNotices(notices, ctx())), ['b', 'd', 'a', 'c']);
    });
  });

  group('sorting', () {
    test('lower priority first; unprioritized keep order after', () {
      final notices = [
        {'key': 'none1', 'text': 'x'},
        {'key': 'p2', 'text': 'x', 'priority': 2},
        {'key': 'p1', 'text': 'x', 'priority': 1},
        {'key': 'none2', 'text': 'x'},
      ];
      expect(keys(evaluateNotices(notices, ctx())), ['p1', 'p2', 'none1', 'none2']);
    });
  });

  group('adjustment', () {
    test('resolves platform-suffixed keys and drops other platforms', () {
      final notices = [
        {'key': 'a', 'text': 'base', 'text-ios': 'on ios', 'text-macos': 'on mac'},
      ];
      final result = evaluateNotices(notices, ctx(platform: 'macos'));
      expect(result.single.text, 'on mac');
      expect(result.single.data.containsKey('text-ios'), isFalse);
      expect(result.single.data.containsKey('text-macos'), isFalse);
    });

    test('expands actionLabel shorthand into actions', () {
      final notices = [
        {'key': 'a', 'text': 'x', 'action': 'link', 'actionLabel': 'Open', 'actionArgs': {'url': 'https://x'}},
      ];
      final action = evaluateNotices(notices, ctx()).single.actions.single;
      expect(action['action'], 'link');
      expect(action['label'], 'Open');
      expect((action['args'] as Map)['url'], 'https://x');
    });

    test('substitutes {{ }} template variables', () {
      final notices = [
        {'key': 'a', 'text': 'Hi {{operator.baseCall}} on {{app.platform}}', 'title': '{{missing.value}}!'},
      ];
      final n = evaluateNotices(notices, ctx(baseCall: 'KI2D', platform: 'macos')).single;
      expect(n.text, 'Hi KI2D on macos');
      expect(n.title, '!'); // unknown path resolves to empty
    });

    test('does not mutate the source notice map', () {
      final source = {'key': 'a', 'text': '{{operator.baseCall}}', 'text-macos': 'mac'};
      evaluateNotices([source], ctx(platform: 'macos'));
      expect(source['text'], '{{operator.baseCall}}');
      expect(source.containsKey('text-macos'), isTrue);
    });
  });
}
