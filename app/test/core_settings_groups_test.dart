// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// HALO-55: LoggingSettingsGroup's target tagging — the five toggles the old
// operation-view popup menu had must stay `target: 'logging'` (the
// tune-icon dialog's always-visible set); everything newer must be
// `target: 'logging-extended'` (behind that dialog's "show more settings").
// Mistagging a field here is silent everywhere else — it just quietly
// stops showing up in (or starts cluttering) the dialog.

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ham2k_logger/settings/core_settings_groups.dart';
import 'package:ham2k_logger/settings/settings_registry.dart';
import 'package:ham2k_logger/services/settings_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('LoggingSettingsGroup target tagging', () {
    const baseKeys = {'showRSTFields', 'showStateField', 'showGridField', 'showDeletedQSOs', 'showQsoNumbers'};

    test('exactly the five legacy toggles are target: "logging"', () async {
      SharedPreferences.setMockInitialValues({});
      final settings = SettingsService(await SharedPreferences.getInstance());
      final elements = await LoggingSettingsGroup(settings).buildElements();

      final loggingKeys = {
        for (final el in elements)
          if (elementMatchesTarget(el, 'logging')) el['key'] as String,
      };
      expect(loggingKeys, baseKeys);
    });

    test('every other declared field is target: "logging-extended", not left untargeted', () async {
      SharedPreferences.setMockInitialValues({});
      final settings = SettingsService(await SharedPreferences.getInstance());
      final elements = await LoggingSettingsGroup(settings).buildElements();

      for (final el in elements) {
        final key = el['key'] as String;
        if (baseKeys.contains(key)) continue;
        expect(
          elementMatchesTarget(el, 'logging-extended'),
          isTrue,
          reason: '"$key" is neither a base toggle nor tagged logging-extended — it would be unreachable '
              'from the tune-icon dialog entirely',
        );
      }
    });

    test('commit writes an extended boolean field through to SettingsService, same path as a base toggle', () async {
      SharedPreferences.setMockInitialValues({});
      final settings = SettingsService(await SharedPreferences.getInstance());
      final group = LoggingSettingsGroup(settings);

      expect(settings.leftieMode, isFalse);
      await group.commit('leftieMode', true);
      expect(settings.leftieMode, isTrue);
    });

    test('HALO-83: a default-report field commits uppercased and trimmed', () async {
      // The logging fields are uppercase throughout, so a CW operator typing
      // "5nn" must not end up with a report that reads differently from every
      // other value in the row.
      SharedPreferences.setMockInitialValues({});
      final settings = SettingsService(await SharedPreferences.getInstance());
      final group = LoggingSettingsGroup(settings);

      expect(settings.defaultReportCW, isEmpty, reason: 'unset means "the standard report"');
      await group.commit('defaultReportCW', ' 5nn ');
      expect(settings.defaultReportCW, '5NN');

      // Clearing has to be possible: a whitespace-only value is cleared, not
      // stored, or the operator would log a blank report with no way back.
      await group.commit('defaultReportCW', '   ');
      expect(settings.defaultReportCW, isEmpty);
    });

    test('HALO-83: the default-report fields show the standard report as their placeholder', () async {
      // The placeholder is what makes an empty field readable as "599 unless
      // you say otherwise" rather than as a missing setting.
      SharedPreferences.setMockInitialValues({});
      final settings = SettingsService(await SharedPreferences.getInstance());
      final elements = await LoggingSettingsGroup(settings).buildElements();
      final byKey = {for (final el in elements) el['key'] as String: el};

      expect(byKey['defaultReport']?['placeholder'], '59');
      expect(byKey['defaultReportCW']?['placeholder'], '599');
      expect(byKey['defaultReportFT8']?['placeholder'], '+0');
    });
  });

  group('RadioSettingsGroup', () {
    Future<SettingsService> settingsWith({
      bool cat = true,
      bool snap = true,
      bool zeroBeat = true,
      bool developer = true,
    }) async {
      SharedPreferences.setMockInitialValues({
        if (cat) 'experiments': jsonEncode({
            'gato': {'enabled': true},
          }),
        // Both features written explicitly, never left to their defaults: a
        // test isolating one of them would otherwise also be asserting the
        // other one's default, and would change meaning when that default did.
        'settings.radio': jsonEncode({'smartVfoSnap': snap, 'avoidZeroBeat': zeroBeat}),
        if (developer) 'developerMode': true,
      });
      return SettingsService(await SharedPreferences.getInstance());
    }

    /// Everything except the two feature toggles — i.e. the values that must
    /// stay out of the way until someone goes looking for them.
    const toggles = {'smartVfoSnap', 'avoidZeroBeat'};

    Future<Set<String>> keysFor(SettingsService settings) async =>
        {for (final el in await RadioSettingsGroup(settings).buildElements()) el['key'] as String};

    test('contributes nothing at all until the CAT experiment is on', () async {
      // An empty group renders nothing; a group with only a header renders a
      // section title over no rows, on everyone's All Settings screen.
      expect(await keysFor(await settingsWith(cat: false)), isEmpty);
    });

    test("Smart VFO Snap's knobs are emitted, not merely flagged, only in developer mode", () async {
      // The distinction is load-bearing: `devMode: true` alone hides the
      // fields inside FormRenderer, but showSettingsForTarget offers "show
      // more settings" whenever the extended bucket is NON-EMPTY — so
      // flagging without gating leaves every other operator a disclosure that
      // expands to nothing.
      expect(await keysFor(await settingsWith(developer: false)), isNot(contains('smartVfoSnapDebounceMs')));
      expect(await keysFor(await settingsWith()), contains('smartVfoSnapDebounceMs'));
    });

    test('the zero-beat range follows its own feature, not developer mode', () async {
      // Unlike the snap knobs, this one only exists once the operator has
      // deliberately switched the feature on — and that operator is exactly
      // who would want to tune the spread, developer or not.
      expect(await keysFor(await settingsWith(developer: false)), contains('zeroBeatRangeHz'));
      expect(await keysFor(await settingsWith(developer: false, zeroBeat: false)),
          isNot(contains('zeroBeatRangeHz')));
    });

    test('the knobs mean nothing with the feature off, and are not offered', () async {
      expect(await keysFor(await settingsWith(snap: false, zeroBeat: false)), toggles);
      // Each feature hides only its own knobs.
      expect(await keysFor(await settingsWith(snap: false)), {...toggles, 'zeroBeatRangeHz'});
      expect(await keysFor(await settingsWith(zeroBeat: false)), isNot(contains('zeroBeatRangeHz')));
    });

    test('both radio features are off out of the box', () async {
      // The frequency an operator transmits on and logs is theirs to choose,
      // so anything that moves it is opted into. Zero-beat being the milder
      // of the two — it redirects a retune already asked for, rather than
      // moving the radio uninvited — does not make it automatic.
      SharedPreferences.setMockInitialValues({});
      final fresh = SettingsService(await SharedPreferences.getInstance());
      expect(fresh.avoidZeroBeat, isFalse);
      expect(fresh.smartVfoSnap, isFalse);
      expect(fresh.zeroBeatRangeHz, 25);
    });

    test('every knob is extended-targeted, dev-flagged where it should be, and commits', () async {
      final settings = await settingsWith();
      final group = RadioSettingsGroup(settings);
      final knobs = [
        for (final el in await group.buildElements())
          if (!toggles.contains(el['key'])) el,
      ];
      expect(knobs, hasLength(5));
      for (final el in knobs) {
        // Every knob stays out of the tune dialog's always-visible set...
        expect(elementMatchesTarget(el, 'current-radio-extended'), isTrue,
            reason: '${el['key']} would crowd the tune dialog\'s always-visible set');
        // ...but only the snap knobs also hide behind developer mode. Compared
        // as `== true`, which is how FormRenderer reads the flag — an absent
        // key and an explicit false both mean "show it".
        expect(el['devMode'] == true, el['key'] != 'zeroBeatRangeHz',
            reason: '${el['key']} is flagged for the wrong audience in All Settings');
      }

      // The select fields emit strings; a commit path that only handled bools
      // would drop every one of them silently.
      await group.commit('smartVfoSnapDebounceMs', '750');
      expect(settings.smartVfoSnapDebounce, const Duration(milliseconds: 750));
      await group.commit('smartVfoSnapMinMoveKHz', '0.5');
      expect(settings.smartVfoSnapMinMoveKHz, 0.5);
    });

    test('a stored value this build no longer offers falls back in the ENGINE, not just the picker', () async {
      // Any option list can lose an entry between builds, and a
      // DropdownButtonFormField whose value matches no item throws — so the
      // dialog has to show something offered. The trap is falling back only
      // there: the row would read "0.25 kHz/s" while the snapper went on
      // applying the withdrawn 0, and re-picking the value already displayed
      // would be the only way to reconcile them.
      SharedPreferences.setMockInitialValues({
        'experiments': jsonEncode({
          'gato': {'enabled': true},
        }),
        'developerMode': true,
        'settings.radio': jsonEncode({'smartVfoSnap': true, 'smartVfoSnapMinSpeed': '0'}),
      });
      final settings = SettingsService(await SharedPreferences.getInstance());
      final speed = (await RadioSettingsGroup(settings).buildElements())
          .firstWhere((el) => el['key'] == 'smartVfoSnapMinSpeed');
      final offered = [for (final o in speed['options'] as List) (o as Map)['value']];

      expect(offered, isNot(contains('0')));
      expect(offered, contains(speed['value']), reason: 'the dropdown would throw on a value it has no item for');
      expect(speed['value'], '0.25');
      expect(settings.smartVfoSnapMinSpeed, 0.25, reason: 'the snapper must run on what the row shows');
    });

    test('every offered option round-trips through the getter that renders it', () async {
      // The picker's `value` is the getter's answer formatted back into an
      // option string. An option that doesn't survive that round trip (0.10,
      // say, which formats as "0.1") leaves the dropdown with no matching
      // item — which throws when the dialog opens.
      SharedPreferences.setMockInitialValues({
        'experiments': jsonEncode({
          'gato': {'enabled': true},
        }),
        'developerMode': true,
      });
      final prefs = await SharedPreferences.getInstance();
      final settings = SettingsService(prefs);

      for (final (key, options) in [
        ('smartVfoSnapDebounceMs', SettingsService.smartVfoSnapDebounceOptions),
        ('smartVfoSnapLongMoveKHz', SettingsService.smartVfoSnapLongMoveOptions),
        ('smartVfoSnapMinMoveKHz', SettingsService.smartVfoSnapMinMoveOptions),
        ('smartVfoSnapMinSpeed', SettingsService.smartVfoSnapMinSpeedOptions),
      ]) {
        for (final option in options) {
          await settings.setSettingValue(SettingsService.radioGroup, 'smartVfoSnap', true);
          await settings.setSettingValue(SettingsService.radioGroup, key, option);
          final el =
              (await RadioSettingsGroup(settings).buildElements()).firstWhere((e) => e['key'] == key);
          expect(el['value'], option, reason: '$key: "$option" does not survive the getter it renders through');
        }
      }
    });
  });
}
