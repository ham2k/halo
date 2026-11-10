// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// An extension changing a setting or a layout on its own (docs/extensions/
// host.md § host.updateSetting, § host.layouts): behind its grant, checked
// against what the setting takes, and named on the status bar, since the
// operator did not make the change.

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_core/halo_core.dart';
import 'package:halo_extension_host/halo_extension_host.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ham2k_logger/main.dart';
import 'package:ham2k_logger/services/extensions/app_control_host_calls.dart';
import 'package:ham2k_logger/services/extensions/extension_info.dart';
import 'package:ham2k_logger/services/settings_service.dart';
import 'package:ham2k_logger/services/status_bar_service.dart';
import 'package:ham2k_logger/settings/settings_command.dart';
import 'package:ham2k_logger/settings/settings_registry.dart';

import '../support/halo_test_support.dart';

class _Group extends SettingsGroup {
  final List<Map<String, dynamic>> elements;
  final committed = <String, dynamic>{};

  _Group(this.elements);

  @override
  String get key => 'test-group';

  @override
  String get title => 'Test Group';

  @override
  int get order => 999;

  // Read back from what was committed, as every real group does: the write
  // is verified against this.
  @override
  Future<List<Map<String, dynamic>>> buildElements() async => [
    for (final el in elements)
      if (committed.containsKey(el['key'])) {...el, 'value': committed[el['key']]} else el,
  ];

  @override
  Future<void> commit(String fieldKey, dynamic value) async => committed[fieldKey] = value;
}

class _Layouts implements LayoutControl {
  ({String? reason, String? name}) switched = (reason: null, name: 'Contest');
  String? focused;

  @override
  List<Map<String, dynamic>> list() => [
    {'view': 'operation'},
  ];

  @override
  ({String? reason, String? name}) switchTo(String view, String id) => switched;

  @override
  String? focus(String view, String panel) => focused;
}

ExtensionInfo _info(String key, {bool settings = false, bool layouts = false, int? api, List<String> hooks = const []}) => ExtensionInfo(
  key: key,
  file: '$key.js',
  source: ExtensionSource.dev,
  core: true,
  name: 'Coach $key',
  requiresSettingsWrite: settings,
  requiresLayoutControl: layouts,
  api: api,
  hooks: hooks,
);

/// Two extensions, each offering an assistant.
class _TwoAssistants extends ExtensionServiceWithFakeHost {
  _TwoAssistants()
    : super(
        FakeExtensionHost({
          'assistant:*:getAssistants': [
            for (final (key, assistant) in [('coach', 'rate'), ('other', 'watch')])
              {
                'key': key,
                'ok': true,
                'value': [
                  {'key': assistant, 'title': assistant},
                ],
              },
          ],
        }),
      );

  @override
  List<ExtensionInfo> get availableExtensions => [
    for (final key in ['coach', 'other']) _info(key, settings: true, hooks: const ['assistant']),
  ];
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('the host calls', () {
    late AppControlHostCalls calls;
    late StatusBarService statusBar;
    late _Layouts layouts;
    final writes = <String, Object?>{};
    var writeAnswer = (reason: null, message: null, unchanged: false, label: 'Theme', valueLabel: 'Dark') as SettingWrite;
    final available = [
      _info('granted', settings: true, layouts: true),
      _info('plain'),
      _info('settingsOnly', settings: true),
      _info('layoutsOnly', layouts: true),
      _info('older', settings: true, api: 21),
    ];
    String nameOf(String? key) => 'Coach $key';

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      statusBar = StatusBarService(await SharedPreferences.getInstance());
      layouts = _Layouts();
      writes.clear();
      writeAnswer = (reason: null, message: null, unchanged: false, label: 'Theme', valueLabel: 'Dark');
      calls = AppControlHostCalls()
        ..settings = ((key, value, callerKey) async {
          writes[key] = value;
          return writeAnswer;
        })
        ..layouts = layouts
        ..statusBar = statusBar;
    });

    String? said(String key) => statusBar.items.where((item) => item.key == 'extension:$key:changed').firstOrNull?.text;

    test('each call needs its grant, and the stamp is what is checked', () async {
      for (final method in ['updateSetting', 'listLayouts', 'switchLayout', 'focusPanel']) {
        await expectLater(
          calls.handle(method, {'extensionKey': 'plain', 'key': 'theme', 'value': 'dark'}, available, nameOf: nameOf),
          throwsA(isA<ExtensionHostException>()),
          reason: method,
        );
      }
      expect(writes, isEmpty);
    });

    test('one grant does not stand in for the other', () async {
      for (final method in ['listLayouts', 'switchLayout', 'focusPanel']) {
        await expectLater(
          calls.handle(method, {'extensionKey': 'settingsOnly', 'view': 'operation', 'id': '2', 'panel': 'spots'}, available, nameOf: nameOf),
          throwsA(isA<ExtensionHostException>()),
          reason: method,
        );
      }
      await expectLater(
        calls.handle('updateSetting', {'extensionKey': 'layoutsOnly', 'key': 'theme', 'value': 'dark'}, available, nameOf: nameOf),
        throwsA(isA<ExtensionHostException>()),
      );
      expect(writes, isEmpty);
    });

    test('a bundle built for an older API changes no setting unasked', () async {
      // Its operator agreed to settings changed through its commands; an
      // update that kept an older `api` was never asked about the rest.
      await expectLater(
        calls.handle('updateSetting', {'extensionKey': 'older', 'key': 'theme', 'value': 'dark'}, available, nameOf: nameOf),
        throwsA(isA<ExtensionHostException>()),
      );
      expect(writes, isEmpty);
    });

    test('a setting written is named with the extension that wrote it', () async {
      final answer = await calls.handle('updateSetting', {'extensionKey': 'granted', 'key': 'theme', 'value': 'dark'}, available, nameOf: nameOf);
      expect(answer, {'accepted': true});
      expect(writes, {'theme': 'dark'});
      expect(said('granted'), 'Coach granted set Theme to Dark');
    });

    test('a setting left as it was says nothing', () async {
      // An assistant re-asserting a setting on every observe would otherwise
      // keep a line on the status bar for a change that never happens.
      writeAnswer = (reason: null, message: null, unchanged: true, label: null, valueLabel: null);
      expect(await calls.handle('updateSetting', {'extensionKey': 'granted', 'key': 'theme', 'value': 'dark'}, available, nameOf: nameOf), {
        'accepted': true,
        'unchanged': true,
      });
      expect(said('granted'), isNull);
    });

    test('a refusal carries its reason and the store\'s message, and says nothing', () async {
      writeAnswer = (reason: 'rejected', message: 'Too long', unchanged: false, label: null, valueLabel: null);
      expect(await calls.handle('updateSetting', {'extensionKey': 'granted', 'key': 'call', 'value': 'x'}, available, nameOf: nameOf), {
        'accepted': false,
        'reason': 'rejected',
        'message': 'Too long',
      });
      expect(said('granted'), isNull);
    });

    test('a switch is named; one to the layout already drawn, a refusal and a focus are not', () async {
      expect(await calls.handle('switchLayout', {'extensionKey': 'granted', 'view': 'operation', 'id': '1'}, available, nameOf: nameOf), {'accepted': true});
      expect(said('granted'), 'Coach granted switched to the Contest layout');

      statusBar.clear('extension:granted:changed');
      layouts.switched = (reason: null, name: null);
      expect(await calls.handle('switchLayout', {'extensionKey': 'granted', 'view': 'operation', 'id': '1'}, available, nameOf: nameOf), {'accepted': true});
      layouts.switched = (reason: 'editing', name: null);
      expect(await calls.handle('switchLayout', {'extensionKey': 'granted', 'view': 'operation', 'id': '1'}, available, nameOf: nameOf), {
        'accepted': false,
        'reason': 'editing',
      });
      expect(await calls.handle('focusPanel', {'extensionKey': 'granted', 'panel': 'spots'}, available, nameOf: nameOf), {'accepted': true});
      expect(said('granted'), isNull);
    });

    test('a call missing what it names is invalid, not a crash', () async {
      expect(await calls.handle('updateSetting', {'extensionKey': 'granted', 'value': 1}, available, nameOf: nameOf), {'accepted': false, 'reason': 'invalid'});
      expect(await calls.handle('switchLayout', {'extensionKey': 'granted', 'view': 'operation'}, available, nameOf: nameOf), {
        'accepted': false,
        'reason': 'invalid',
      });
      expect(await calls.handle('focusPanel', {'extensionKey': 'granted'}, available, nameOf: nameOf), {'accepted': false, 'reason': 'invalid'});
      expect(writes, isEmpty);
    });
  });

  group('the assistants an extension may switch', () {
    test('its own, never another extension\'s', () async {
      // The operator turns an assistant on knowing it then watches every
      // operation; another extension doing it for them would be that consent
      // given by someone else.
      SharedPreferences.setMockInitialValues({});
      final settings = SettingsService(await SharedPreferences.getInstance());
      final db = HaLoDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final extensions = _TwoAssistants();
      final services = HaLoServices(db, settings, extensions: extensions);
      await services.assistants.refresh();
      expect(services.assistants.catalog.map((a) => a.id), {'assistant:coach:rate', 'assistant:other:watch'});

      expect((await writeSettingForExtension(services, callerKey: 'coach', key: 'assistant:other:watch', value: false)).reason, 'invalid');
      expect((await writeSettingForExtension(services, callerKey: 'coach', key: 'assistant:coach:rate', value: false)).reason, isNull);
      expect(services.assistants.isEnabled(services.assistants.catalog.firstWhere((a) => a.key == 'rate')), isFalse);
      expect(services.assistants.isEnabled(services.assistants.catalog.firstWhere((a) => a.key == 'watch')), isTrue);
    });
  });

  group('writing a setting for an extension', () {
    late _Group group;

    Future<HaLoServices> services() async {
      SharedPreferences.setMockInitialValues({});
      final settings = SettingsService(await SharedPreferences.getInstance());
      final db = HaLoDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final services = HaLoServices(db, settings, extensions: ExtensionServiceWithFakeHost());
      group = _Group([
        {'type': 'field', 'key': 'hideDupes', 'label': 'Hide Dupes', 'fieldType': 'checkbox', 'value': false},
        {
          'type': 'field',
          'key': 'theme',
          'label': 'Theme',
          'fieldType': 'select',
          'value': 'light',
          'options': [
            {'label': 'Light', 'value': 'light'},
            {'label': 'Dark', 'value': 'dark'},
          ],
        },
        {'type': 'field', 'key': 'wpm', 'label': 'Speed', 'fieldType': 'number', 'value': 20},
        {'type': 'field', 'key': 'note', 'label': 'Note', 'fieldType': 'text', 'value': ''},
        {'type': 'field', 'key': 'apiKey', 'label': 'API Key', 'fieldType': 'secret', 'value': ''},
        {'type': 'field', 'key': 'reload', 'label': 'Reload', 'fieldType': 'checkbox', 'value': false, 'restartOnChange': true},
      ]);
      services.settingsRegistry.register(group);
      return services;
    }

    test('each kind of setting takes a value of its own kind, labelled as Settings shows it', () async {
      final s = await services();
      expect(await writeSettingForExtension(s, callerKey: 'coach', key: 'theme', value: 'dark'), (
        reason: null,
        message: null,
        unchanged: false,
        label: 'Theme',
        valueLabel: 'Dark',
      ));
      expect((await writeSettingForExtension(s, callerKey: 'coach', key: 'hideDupes', value: true)).reason, isNull);
      expect((await writeSettingForExtension(s, callerKey: 'coach', key: 'wpm', value: 25)).reason, isNull);
      expect((await writeSettingForExtension(s, callerKey: 'coach', key: 'note', value: 'Skeds at 14:00')).reason, isNull);
      expect(group.committed, {'theme': 'dark', 'hideDupes': true, 'wpm': 25, 'note': 'Skeds at 14:00'});
    });

    test('a value the setting does not take is refused before anything is written', () async {
      // Every core group's commit drops a value it cannot store without a
      // word; caught only afterwards, a string written to a switch would be
      // `rejected` with a message about a write that was never attempted.
      final s = await services();
      for (final (key, value) in [('hideDupes', 'yes'), ('theme', 'Dark'), ('theme', 'sepia'), ('wpm', '25'), ('wpm', double.nan), ('note', 3)]) {
        expect(
          (await writeSettingForExtension(s, callerKey: 'coach', key: key, value: value)).reason,
          'invalid',
          reason: '$key = $value',
        );
      }
      expect(group.committed, isEmpty);
    });

    test('a secret, a field that restarts the extensions and an unknown key are never written', () async {
      // The restart would end the runtime the calling extension is waiting in.
      final s = await services();
      expect((await writeSettingForExtension(s, callerKey: 'coach', key: 'apiKey', value: 'hunter2')).reason, 'invalid');
      expect((await writeSettingForExtension(s, callerKey: 'coach', key: 'reload', value: true)).reason, 'invalid');
      expect((await writeSettingForExtension(s, callerKey: 'coach', key: 'nothingLikeThis', value: true)).reason, 'invalid');
      expect(group.committed, isEmpty);
    });

    test('the value it already holds is unchanged, and not written again', () async {
      final s = await services();
      expect((await writeSettingForExtension(s, callerKey: 'coach', key: 'theme', value: 'light')).unchanged, isTrue);
      expect(group.committed, isEmpty);
    });

    test('a value its extension could not store is not reported as stored', () async {
      // Answered as stored, it would put a status line in front of the
      // operator naming a change that never happened.
      final failing = ExtensionServiceWithFakeHost(FakeExtensionHost({'settingsPanel:keeper:onChangeField': Exception('could not save')}));
      expect(
        await failing.commitSettingsFieldValue(kind: 'dynamic', hookKey: 'keeper', panelKey: 'keeper', fieldKey: 'url', value: 'x', state: const {}),
        isFalse,
      );
      final keeping = ExtensionServiceWithFakeHost();
      expect(
        await keeping.commitSettingsFieldValue(kind: 'dynamic', hookKey: 'keeper', panelKey: 'keeper', fieldKey: 'url', value: 'x', state: const {}),
        isTrue,
      );
    });

    test('text differing only in case is a change', () async {
      // An extension's text field keeps its case: a URL or a user name that
      // differs in it is a different one, and answering `unchanged` would
      // leave the old one stored.
      final s = await services();
      await writeSettingForExtension(s, callerKey: 'coach', key: 'note', value: 'https://x/Foo');
      final again = await writeSettingForExtension(s, callerKey: 'coach', key: 'note', value: 'https://x/foo');
      expect(again.unchanged, isFalse);
      expect(group.committed['note'], 'https://x/foo');
    });
  });
}
