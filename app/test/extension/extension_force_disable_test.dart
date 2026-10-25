// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The flags' `halo-extensions-disabled` list: how its entries combine, what
// the boot reads before the first start, and what applying a complete
// refresh does. The traps are a refresh that changes nothing still restarting
// the runtime or re-raising the notice, a lifted entry leaving its notice up,
// an extension that is not installed being announced as stopped, and an entry
// the boot put on the list never being announced at all.

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:ham2k_logger/services/extensions/extension_force_disable.dart';
import 'package:ham2k_logger/services/extensions/extension_info.dart';
import 'package:ham2k_logger/services/settings_service.dart';
import 'package:ham2k_logger/services/status_bar_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('parseForceDisabled', () {
    test('an entry naming no versions covers them all, whatever another entry for the key lists', () {
      // defaults.json and a per-call file each naming the key is the merged
      // flags concatenating the two lists. Mutated to keep the first entry,
      // a per-call "every version" is narrowed back to one.
      final parsed = parseForceDisabled([
        {
          'key': 'ki2d-my-clock',
          'versions': ['1.0.0'],
          'note': 'Crashes.',
        },
        {'key': 'ki2d-my-clock'},
      ]);
      expect(parsed['ki2d-my-clock']!.versions, isNull);
      expect(parsed['ki2d-my-clock']!.note, 'Crashes.');
    });

    test('versions listed by several entries add up', () {
      final parsed = parseForceDisabled([
        {
          'key': 'ki2d-my-clock',
          'versions': ['1.0.0'],
        },
        {
          'key': 'ki2d-my-clock',
          'versions': ['1.0.1'],
        },
      ]);
      expect(parsed['ki2d-my-clock']!.versions, {'1.0.0', '1.0.1'});
    });

    test('drops an entry it cannot read rather than the whole list', () {
      final parsed = parseForceDisabled([
        'ki2d-my-clock',
        {'key': ''},
        {'versions': []},
        {'key': 'ki2d-other'},
      ]);
      expect(parsed.keys, ['ki2d-other']);
      expect(parseForceDisabled({'key': 'ki2d-other'}), isEmpty);
    });

    test('a `versions` that is not a list drops the entry rather than covering every version', () {
      // Read as absent, `"versions": "1.2.3"` stops every version of the
      // extension on every install — the stop widened past what its author
      // wrote, with nothing to say so.
      expect(
        parseForceDisabled([
          {'key': 'ki2d-my-clock', 'versions': '1.2.3'},
        ]),
        isEmpty,
      );
    });
  });

  group('applyForceDisabledFlags', () {
    late SettingsService settings;
    late StatusBarService statusBar;
    var applied = 0;

    const clock = ExtensionInfo(key: 'ki2d-my-clock', file: 'index.js', core: false, name: 'Clock', source: ExtensionSource.installed, version: '1.0.0');

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      settings = SettingsService(prefs);
      statusBar = StatusBarService(prefs);
      applied = 0;
    });

    Future<void> apply(Object? list, {List<ExtensionInfo> available = const [clock]}) => applyForceDisabledFlags(
      flags: {kForceDisabledFlag: ?list},
      settings: settings,
      statusBar: statusBar,
      available: available,
      applyAvailability: () async => applied++,
    );

    bool noticeUp() => statusBar.activeNotices.any((n) => n.key == forceDisabledNoticeKey('ki2d-my-clock'));

    test('records the list, says so once, and applies it once', () async {
      // Applied on every refresh — a callsign edit, a forced re-fetch — and
      // each restart costs the operator every panel's state. Mutated to apply
      // unconditionally, `applied` reads 2.
      final list = [
        {'key': 'ki2d-my-clock', 'note': 'Uploads the log.'},
      ];
      await apply(list);
      expect(settings.extensionForceDisabled.keys, ['ki2d-my-clock']);
      expect(applied, 1);
      expect(noticeUp(), isTrue);
      expect(statusBar.activeNotices.single.text, contains('Uploads the log.'));

      statusBar.dismissNotice(forceDisabledNoticeKey('ki2d-my-clock'));
      await apply(list);
      expect(applied, 1);
      expect(noticeUp(), isFalse, reason: 'the record is what says the operator was told');
    });

    test('a key that leaves the list is lifted, and its notice comes down', () async {
      await apply([
        {'key': 'ki2d-my-clock'},
      ]);
      await apply(null);
      expect(settings.extensionForceDisabled, isEmpty);
      expect(applied, 2);
      expect(noticeUp(), isFalse);
    });

    test('an entry the boot kept before anything was installed-aware is announced by the next refresh', () async {
      // The boot read puts an entry on the kept list before the list of what
      // is installed exists. Told by a diff of old list against new, the
      // refresh that follows sees nothing new, and the operator never hears
      // why the extension stopped.
      await keepForceDisabledFromBoot(settings, {'ki2d-my-clock': const ExtensionForceDisable(note: 'Crashes on start.')});
      expect(settings.extensionForceDisabled.keys, ['ki2d-my-clock']);
      expect(statusBar.activeNotices, isEmpty);
      await apply([
        {'key': 'ki2d-my-clock', 'note': 'Crashes on start.'},
      ]);
      expect(noticeUp(), isTrue);
      expect(applied, 0, reason: 'the list did not change, so nothing loads differently');
    });

    test('tells nobody about an extension that is not installed, or a version it does not cover', () async {
      // Recorded all the same: an install of it later must land off.
      await apply([
        {'key': 'ki2d-elsewhere'},
        {
          'key': 'ki2d-my-clock',
          'versions': ['0.9.0'],
        },
      ]);
      expect(statusBar.activeNotices, isEmpty);
      expect(settings.extensionForceDisabled.keys, unorderedEquals(['ki2d-elsewhere', 'ki2d-my-clock']));
    });
  });

  group('before the first start', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    test('the kept list and defaults.json now add up; the boot keeps the sum and lifts nothing', () async {
      // Lifting here would run what a per-call file stops: the boot reads
      // defaults.json alone, and an entry missing from it may live elsewhere.
      SharedPreferences.setMockInitialValues({
        kForceDisabledPrefsKey: jsonEncode({
          'ki2d-kept': {'note': 'kept'},
        }),
      });
      final early = await forceDisabledBeforeStart(
        fetchDefaults: () async => {
          kForceDisabledFlag: [
            {'key': 'ki2d-new', 'note': 'new'},
          ],
        },
      );
      expect(early.keys, unorderedEquals(['ki2d-kept', 'ki2d-new']));

      final settings = SettingsService(await SharedPreferences.getInstance());
      await keepForceDisabledFromBoot(settings, {'ki2d-new': const ExtensionForceDisable(note: 'new')});
      expect(settings.extensionForceDisabled.keys, unorderedEquals(['ki2d-kept', 'ki2d-new']));
    });

    test('an unreachable flags server leaves the kept list standing', () async {
      SharedPreferences.setMockInitialValues({
        kForceDisabledPrefsKey: jsonEncode({
          'ki2d-kept': {'note': ''},
        }),
      });
      expect((await forceDisabledBeforeStart(fetchDefaults: () async => null)).keys, ['ki2d-kept']);
    });
  });
}
