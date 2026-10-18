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

import 'package:flutter/widgets.dart' show BuildContext;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ham2k_logger/settings/core_settings_groups.dart';
import 'package:ham2k_logger/settings/settings_registry.dart';
import 'package:ham2k_logger/services/map_preferences.dart';
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

    // Preferences lists the group in declaration order, and the three "show"
    // toggles about what a list holds read as one run: numbers, then the two
    // kinds of deleted record.
    test('Show QSO Numbers, Show deleted QSOs and Show deleted operations close the group, in that order', () async {
      SharedPreferences.setMockInitialValues({});
      final settings = SettingsService(await SharedPreferences.getInstance());
      final elements = await LoggingSettingsGroup(settings).buildElements();

      final keys = [for (final el in elements) el['key'] as String];
      expect(keys.sublist(keys.length - 3), ['showQsoNumbers', 'showDeletedQSOs', 'showDeletedOps']);
      expect(settings.showDeletedOps, isFalse, reason: 'off by default, as in app-polo');
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
          reason:
              '"$key" is neither a base toggle nor tagged logging-extended — it would be unreachable '
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
    Future<SettingsService> settingsWith({bool keyer = true, bool snap = true, bool zeroBeat = true, bool developer = true}) async {
      SharedPreferences.setMockInitialValues({
        'experiments': jsonEncode({
          if (keyer) 'keyer': {'enabled': true},
        }),
        // Both features written explicitly, never left to their defaults: a
        // test isolating one of them would otherwise also be asserting the
        // other one's default, and would change meaning when that default did.
        'settings.radio': jsonEncode({'smartVfoSnap': snap, 'avoidZeroBeat': zeroBeat}),
        if (developer) 'developerMode': true,
      });
      return SettingsService(await SharedPreferences.getInstance());
    }

    /// Everything except the feature toggles — i.e. the values that must
    /// stay out of the way until someone goes looking for them.
    const toggles = {'pttKey', 'smartVfoSnap', 'avoidZeroBeat'};

    /// The CW messages live in this group too, but under their own dialog
    /// (`cw-messages`) — they are not tuning knobs. Kept out of the knob
    /// tests, and tested on their own.
    /// The repeat delays belong here too: they are keyer settings under the
    /// message dialogs' own targets, not tuning knobs.
    bool isCwMessageElement(Map<String, dynamic> el) => (el['key'] as String? ?? '').startsWith('cwMessage') || el['key'] == 'cwRepeatDelay';

    /// The voice memory labels, the same way, under `voice-messages`.
    bool isVoiceMessageElement(Map<String, dynamic> el) => (el['key'] as String? ?? '').startsWith('voiceMessage') || el['key'] == 'voiceRepeatDelay';

    /// The two rows that open the keyer dialogs — part of the keyer, not knobs.
    bool isKeyerRow(Map<String, dynamic> el) => el['key'] == cwKeyerActionKey || el['key'] == phoneKeyerActionKey;

    bool isMessageElement(Map<String, dynamic> el) => isCwMessageElement(el) || isVoiceMessageElement(el) || isKeyerRow(el);

    /// The row leading on to Station Configuration — navigation, not a knob.
    /// The section headings are no settings at all, and the station-info
    /// pair is logging, not tuning.
    bool isNotAKnob(Map<String, dynamic> el) =>
        (el['type'] == 'link' && el['panel'] != null) || el['type'] == 'header' || el['key'] == 'trackStationInfo' || el['key'] == 'stationInfoTrackedFields';

    Future<Set<String>> keysFor(SettingsService settings) async => {
      for (final el in await RadioSettingsGroup(settings).buildElements())
        if (!isMessageElement(el) && !isNotAKnob(el)) el['key'] as String,
    };

    test('ends with a row that leads on to the Station Configuration panel', () async {
      // Application Preferences only carries the app-wide radio behaviour;
      // without this row an operator there has no path to the equipment
      // itself short of backing out to the sidebar.
      final elements = await RadioSettingsGroup(await settingsWith()).buildElements();
      expect(elements.last['type'], 'link');
      expect(elements.last['panel'], 'station');
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
      expect(await keysFor(await settingsWith(developer: false, zeroBeat: false)), isNot(contains('zeroBeatRangeHz')));
    });

    test('the knobs mean nothing with the feature off, and are not offered', () async {
      expect(await keysFor(await settingsWith(snap: false, zeroBeat: false)), toggles);
      // Each feature hides only its own knobs.
      expect(await keysFor(await settingsWith(snap: false)), {...toggles, 'zeroBeatRangeHz'});
      expect(await keysFor(await settingsWith(zeroBeat: false)), isNot(contains('zeroBeatRangeHz')));
    });

    test("['] PTT is offered only under the keyer experiment, off, and ahead of Smart VFO Snap", () async {
      // Off by default because it puts the transmitter on the air; gated with
      // the voice keyer whose Phone-mode keys it shares.
      SharedPreferences.setMockInitialValues({});
      expect(SettingsService(await SharedPreferences.getInstance()).pttKey, isFalse);
      expect(await keysFor(await settingsWith(keyer: false)), isNot(contains('pttKey')));
      final keys = [for (final el in await RadioSettingsGroup(await settingsWith()).buildElements()) el['key']];
      expect(keys.indexOf('pttKey'), keys.indexOf('smartVfoSnap') - 1);
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

    test('without a radio the CAT rows are unlisted, not gone, and station info still shows', () async {
      // Two traps. Dropping the rows outright hides them from SET/SHOW too,
      // which scan the same elements. Leaving them listed shows a screen of
      // knobs with nothing to act on.
      final settings = await settingsWith();
      Map<String, dynamic> byKey(List<Map<String, dynamic>> els, String key) => els.firstWhere((el) => el['key'] == key);

      final without = await RadioSettingsGroup(settings, hasTransceivers: () => false).buildElements();
      expect(byKey(without, 'smartVfoSnap')['listed'], isFalse);
      expect(byKey(without, 'avoidZeroBeat')['listed'], isFalse);
      expect(byKey(without, 'trackStationInfo')['listed'], isNot(false), reason: 'what a QSO records is not a CAT feature');

      final withRadio = await RadioSettingsGroup(settings, hasTransceivers: () => true).buildElements();
      expect(byKey(withRadio, 'smartVfoSnap')['listed'], isNot(false));
    });

    test('every knob is extended-targeted, dev-flagged where it should be, and commits', () async {
      final settings = await settingsWith();
      final group = RadioSettingsGroup(settings);
      final knobs = [
        for (final el in await group.buildElements())
          if (!toggles.contains(el['key']) && !isMessageElement(el) && !isNotAKnob(el)) el,
      ];
      expect(knobs, hasLength(5));
      for (final el in knobs) {
        // Every knob stays out of the tune dialog's always-visible set...
        expect(elementMatchesTarget(el, 'current-radio-extended'), isTrue, reason: '${el['key']} would crowd the tune dialog\'s always-visible set');
        // ...but only the snap knobs also hide behind developer mode. Compared
        // as `== true`, which is how FormRenderer reads the flag — an absent
        // key and an explicit false both mean "show it".
        expect(el['devMode'] == true, el['key'] != 'zeroBeatRangeHz', reason: '${el['key']} is flagged for the wrong audience in Settings');
      }

      // The select fields emit strings; a commit path that only handled bools
      // would drop every one of them silently.
      await group.commit('smartVfoSnapDebounceMs', '75');
      expect(settings.smartVfoSnapDebounce, const Duration(milliseconds: 75));
      await group.commit('smartVfoSnapMinMoveKHz', '0.5');
      expect(settings.smartVfoSnapMinMoveKHz, 0.5);
    });

    // Every keyer setting stays declared for SET/SHOW and the target modals,
    // but none is a Settings row: the two rows below open the dialogs that
    // edit them. A row that opened nothing would look like a dead link.
    test('the keyer settings are off the rows, and the two keyer rows open their dialogs', () async {
      final opened = <String>[];
      final group = RadioSettingsGroup(
        await settingsWith(),
        openCwKeyer: (context) async => opened.add(cwKeyerActionKey),
        openPhoneKeyer: (context) async => opened.add(phoneKeyerActionKey),
      );
      final all = await group.buildElements();
      final keyer = [
        for (final el in all)
          if (elementMatchesTarget(el, 'cw-messages') || elementMatchesTarget(el, 'voice-messages')) el,
      ];
      expect(keyer, isNotEmpty);
      for (final el in keyer) {
        expect(el['listed'], isFalse, reason: '${el['key']} belongs to a keyer dialog, not the Settings rows');
      }
      final rows = [
        for (final el in all)
          if (el['type'] == 'action') el,
      ];
      expect(rows.map((el) => el['key']), [cwKeyerActionKey, phoneKeyerActionKey]);
      expect(rows.every((el) => el['listed'] != false), isTrue);

      final context = _FakeContext();
      await group.openAction(context, cwKeyerActionKey);
      await group.openAction(context, phoneKeyerActionKey);
      await group.openAction(context, 'moreStationSettings');
      expect(opened, [cwKeyerActionKey, phoneKeyerActionKey]);
    });

    test('the CW messages sit under their own target, never the tune dialog, and commit as text', () async {
      final settings = await settingsWith(developer: false, snap: false, zeroBeat: false);
      final group = RadioSettingsGroup(settings);
      final all = await group.buildElements();
      final messages = [
        for (final el in all)
          if (isCwMessageElement(el) && !elementMatchesTarget(el, 'voice-messages')) el,
      ];
      // Eight messages, their eight labels and the repeat delay. No note: the
      // placeholders are explained by the CW Keyer dialog's own Help.
      expect(messages.where((el) => el['type'] == 'field'), hasLength(SettingsService.cwMessageCount * 2 + 1));
      expect(messages.where((el) => el['type'] == 'markdown'), isEmpty);
      for (final el in messages) {
        expect(elementMatchesTarget(el, 'cw-messages'), isTrue, reason: '${el['key']} belongs to the messages dialog');
        // Eight text rows in the tune dialog would bury the toggles it exists for.
        expect(elementMatchesTarget(el, 'current-radio'), isFalse);
        expect(elementMatchesTarget(el, 'current-radio-extended'), isFalse);
      }
      // The voice memory labels: eight labels, and no message
      // field beside them — the audio is in the radio, so a `voiceMessage$n`
      // text field would be a setting nothing reads.
      final voice = [
        for (final el in all)
          if (elementMatchesTarget(el, 'voice-messages')) el,
      ];
      expect(voice.where((el) => el['type'] == 'field').map((el) => el['key']), [
        'voiceRepeatDelay',
        for (var n = 1; n <= SettingsService.voiceMessageCount; n++) 'voiceMessageLabel$n',
      ]);
      for (final el in voice) {
        expect(elementMatchesTarget(el, 'cw-messages'), isFalse, reason: '${el['key']} is not a CW message');
        expect(elementMatchesTarget(el, 'current-radio-extended'), isFalse);
      }
      await group.commit('voiceMessageLabel3', 'CQ POTA');
      expect(settings.voiceMessageLabel(3), 'CQ POTA');
      // A template is text; a commit path narrowed to bools and option
      // strings would drop it silently.
      await group.commit('cwMessage1', 'CQ CQ DE {{ op.call }} K');
      // Into the ACTIVE SET, which is where cwMessage reads from: a commit
      // that wrote the bare key instead would store a message nothing sends.
      expect(settings.cwMessage(1), 'CQ CQ DE {{ op.call }} K');
      expect(settings.activeCwMessageSet.message(1), 'CQ CQ DE {{ op.call }} K');
      expect(settings.cwMessage(3), '', reason: 'a message the seeds left alone is empty, and sends nothing');

      // Both repeats are settings, so SET and Settings reach them.
      final repeats = all.where((el) => el['key'] == 'cwRepeatDelay' || el['key'] == 'voiceRepeatDelay');
      expect(repeats, hasLength(2));
      expect(elementMatchesTarget(repeats.first, 'cw-messages'), isTrue);
      expect(elementMatchesTarget(repeats.last, 'voice-messages'), isTrue);
      await group.commit('cwRepeatDelay', '5');
      expect(settings.cwRepeatDelay, const Duration(seconds: 5));
      await group.commit('voiceRepeatDelay', '3');
      expect(settings.voiceRepeatDelay, const Duration(seconds: 3));
      // Keyer off: the radio's own toggles, none of the messages.
      final withoutKeyer = await RadioSettingsGroup(await settingsWith(keyer: false, snap: false, zeroBeat: false)).buildElements();
      expect(withoutKeyer.where(isMessageElement), isEmpty, reason: 'the messages follow the keyer experiment');
      expect(withoutKeyer, isNotEmpty);
    });

    test('a stored value this build no longer offers falls back in the ENGINE, not just the picker', () async {
      // Any option list can lose an entry between builds, and a
      // DropdownButtonFormField whose value matches no item throws — so the
      // dialog has to show something offered. The trap is falling back only
      // there: the row would read "0.1 kHz/s" while the snapper went on
      // applying the withdrawn 0, and re-picking the value already displayed
      // would be the only way to reconcile them.
      SharedPreferences.setMockInitialValues({
        'developerMode': true,
        'settings.radio': jsonEncode({'smartVfoSnap': true, 'smartVfoSnapMinSpeed': '0'}),
      });
      final settings = SettingsService(await SharedPreferences.getInstance());
      final speed = (await RadioSettingsGroup(settings).buildElements()).firstWhere((el) => el['key'] == 'smartVfoSnapMinSpeed');
      final offered = [for (final o in speed['options'] as List) (o as Map)['value']];

      expect(offered, isNot(contains('0')));
      expect(offered, contains(speed['value']), reason: 'the dropdown would throw on a value it has no item for');
      expect(speed['value'], '0.1');
      expect(settings.smartVfoSnapMinSpeed, 0.1, reason: 'the snapper must run on what the row shows');
    });

    test('every offered option round-trips through the getter that renders it', () async {
      // The picker's `value` is the getter's answer formatted back into an
      // option string. An option that doesn't survive that round trip (0.10,
      // say, which formats as "0.1") leaves the dropdown with no matching
      // item — which throws when the dialog opens.
      SharedPreferences.setMockInitialValues({'developerMode': true});
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
          final el = (await RadioSettingsGroup(settings).buildElements()).firstWhere((e) => e['key'] == key);
          expect(el['value'], option, reason: '$key: "$option" does not survive the getter it renders through');
        }
      }
    });
  });

  group('MapSettingsGroup', () {
    Future<SettingsService> settingsWith() async {
      SharedPreferences.setMockInitialValues({});
      return SettingsService(await SharedPreferences.getInstance());
    }

    test('offers every MapStyle value, target "map", defaulting to automatic', () async {
      final elements = await MapSettingsGroup(await settingsWith()).buildElements();
      final field = elements.firstWhere((e) => e['key'] == 'mapStyle');
      expect(field['value'], 'automatic');
      expect(elementMatchesTarget(field, 'map'), isTrue);
      final offered = {for (final o in field['options'] as List) (o as Map)['value']};
      expect(offered, MapStyle.values.map((e) => e.name).toSet());
    });

    test('commit round-trips through SettingsService.mapStyle', () async {
      final settings = await settingsWith();
      final group = MapSettingsGroup(settings);
      expect(settings.mapStyle, MapStyle.automatic);
      await group.commit('mapStyle', 'darkMatter');
      expect(settings.mapStyle, MapStyle.darkMatter);
    });

    test('a stored value this build no longer offers falls back to automatic, not a crash', () async {
      final settings = await settingsWith();
      await settings.setSettingValue(SettingsService.generalGroup, 'mapStyle', 'retiredStyle');
      expect(settings.mapStyle, MapStyle.automatic);
    });

    // In the map pane's own settings (target "map"), off until turned on:
    // an operator who never asked for labels keeps the map of dots they had.
    test('Show Callsigns is a toggle in the map pane, off by default, committed to SettingsService', () async {
      final settings = await settingsWith();
      final group = MapSettingsGroup(settings);
      final field = (await group.buildElements()).firstWhere((e) => e['key'] == 'mapShowCallsigns');
      expect(field['fieldType'], 'checkbox');
      expect(field['value'], isFalse);
      expect(elementMatchesTarget(field, 'map'), isTrue);
      await group.commit('mapShowCallsigns', true);
      expect(settings.mapShowCallsigns, isTrue);
      await group.commit('mapShowCallsigns', false);
      expect(settings.mapShowCallsigns, isFalse);
    });
  });

  test('SyncSettingsGroup ends with a row that leads on to the Cloud Sync panel', () async {
    // Application Preferences holds only the on/off toggle; the account,
    // devices and status live on the panel, which this row is the way to.
    SharedPreferences.setMockInitialValues({});
    final settings = SettingsService(await SharedPreferences.getInstance());
    final elements = await SyncSettingsGroup(settings, onToggle: (_) async {}).buildElements();
    expect(elements.last['type'], 'link');
    expect(elements.last['panel'], 'sync');
  });
}

class _FakeContext extends Fake implements BuildContext {}
