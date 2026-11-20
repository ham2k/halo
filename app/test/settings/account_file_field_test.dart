// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The account dialog's `file` field: what a pick holds, what Save stores, and
// what the extension is handed. The picker is the seam; everything past it —
// the capped read, the dialog, the credentials map — is the real code.

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_core/halo_core.dart';
import 'package:halo_i18n/halo_i18n.dart';
import 'package:ham2k_logger/main.dart';
import 'package:ham2k_logger/services/extensions/extension_service.dart';
import 'package:ham2k_logger/services/settings_service.dart';
import 'package:ham2k_logger/views/settings/accounts_panel.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/halo_test_support.dart';

/// Keeps credentials in memory, so Save and the reopened dialog's read are the
/// real round trip rather than a "storage unavailable" answer.
class _AccountExtensionService extends ExtensionServiceWithFakeHost {
  _AccountExtensionService(super.mockHost);
  final Map<String, Map<String, String>> store = {};

  @override
  Future<Map<String, String>> getAccountCredentials(String kvKey) async => store[kvKey] ?? const {};
  @override
  Future<void> setAccountCredentials(String kvKey, Map<String, String> credentials) async {
    store[kvKey] = credentials;
  }
}

Map<String, dynamic> _definition({int? maxBytes}) => {
  'key': 'n0dev-lotw',
  'ok': true,
  'value': {
    'key': 'n0dev-lotw',
    'extensionKey': 'n0dev-lotw',
    'kvKey': 'n0dev-lotw',
    'label': 'LoTW',
    'fields': [
      {
        'key': 'certificate',
        'label': 'Certificate',
        'type': 'file',
        'accept': {
          'extensions': ['p12'],
        },
        'maxBytes': ?maxBytes,
      },
      {'key': 'password', 'label': 'Password', 'type': 'secret'},
    ],
  },
};

typedef _Harness = ({_AccountExtensionService extensions, List<Map<String, dynamic>> tested});

Future<_Harness> _openPane(WidgetTester tester, {int? maxBytes, Map<String, String>? stored}) async {
  SharedPreferences.setMockInitialValues({});
  final settings = SettingsService(await SharedPreferences.getInstance());
  final tested = <Map<String, dynamic>>[];
  final extensions = _AccountExtensionService(
    FakeExtensionHost({
      'account:*:getDefinition': [_definition(maxBytes: maxBytes)],
      'account:n0dev-lotw:testCredentials': (Object? args) {
        tested.add((args as Map).cast<String, dynamic>());
        return 'Signed in';
      },
    }),
  );
  extensions.settings = settings;
  extensions.debugSetAvailableExtensions([ExtensionInfo(key: 'n0dev-lotw', file: 'n0dev-lotw.js', core: false, name: 'LoTW')]);
  if (stored != null) extensions.store['n0dev-lotw'] = stored;
  final services = HaLoServices(HaLoDatabase(NativeDatabase.memory()), settings, extensions: extensions);
  addTearDown(services.db.close);
  await tester.pumpWidget(
    TranslationProvider(
      child: MaterialApp(
        navigatorKey: navigatorKey,
        home: const Scaffold(body: SizedBox()),
      ),
    ),
  );
  unawaited(showAccountDialogByKey(services, 'n0dev-lotw'));
  await tester.pumpAndSettle();
  return (extensions: extensions, tested: tested);
}

/// Answers the next pick with [answer]: a file, null for a cancel, or a throw
/// for a picker that failed. Records the type groups it was asked for.
List<List<XTypeGroup>> _answerPicks(FutureOr<XFile?> Function() answer) {
  final asked = <List<XTypeGroup>>[];
  accountFilePicker = ({List<XTypeGroup> acceptedTypeGroups = const []}) async {
    asked.add(acceptedTypeGroups);
    return answer();
  };
  return asked;
}

/// An in-memory file. The path only names it — `XFile.fromData` reports an
/// empty `name` without one — and is relative, as no real pick's is.
XFile _file(String name, int size) => XFile.fromData(Uint8List.fromList(List.generate(size, (i) => i % 256)), name: name, path: name);

Finder get _choose => find.widgetWithText(TextButton, t.settings.accounts.chooseFile);
Finder get _remove => find.widgetWithText(TextButton, t.settings.accounts.removeFile);
Finder get _save => find.widgetWithText(FilledButton, t.common.save);

/// Taps [button] and lets what it started run. While a file is being read
/// the field's spinner never settles, so that frame is pumped once instead.
Future<void> _press(WidgetTester tester, Finder button) async {
  await tester.tap(button);
  await tester.runAsync(() => pumpEventQueue());
  await tester.pump();
  if (find.byType(CircularProgressIndicator).evaluate().isEmpty) await tester.pumpAndSettle();
}

/// Lets a read that finished outside the event queue land in the dialog.
Future<void> _settleRead(WidgetTester tester, {Duration wait = Duration.zero}) async {
  await tester.runAsync(() => Future<void>.delayed(wait));
  await tester.runAsync(() => pumpEventQueue());
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  tearDown(() => accountFilePicker = ({List<XTypeGroup> acceptedTypeGroups = const []}) async => null);

  testWidgets('a picked file is saved as its Base64 bytes, with its name beside them', (tester) async {
    final h = await _openPane(tester);
    final asked = _answerPicks(() => _file('N0DEV.p12', 3000));

    expect(find.text(t.settings.accounts.noFileChosen), findsOneWidget);
    await _press(tester, _choose);
    expect(find.text('N0DEV.p12'), findsOneWidget);
    // Held until Save, as a typed field is: picking alone stores nothing.
    expect(h.extensions.store, isEmpty);

    await _press(tester, _save);
    final saved = h.extensions.store['n0dev-lotw']!;
    expect(base64Decode(saved['certificate']!), List.generate(3000, (i) => i % 256));
    expect(saved['certificate:name'], 'N0DEV.p12');
    expect(saved['password'], '');
    // The extension's accept list reached the picker, with the UTI iOS needs.
    expect(asked.single.single.extensions, ['p12']);
    expect(asked.single.single.uniformTypeIdentifiers, ['public.data']);
  });

  testWidgets('the extension tests the picked file before it is saved', (tester) async {
    final h = await _openPane(tester);
    _answerPicks(() => _file('N0DEV.p12', 10));
    await _press(tester, _choose);
    await _press(tester, find.widgetWithText(TextButton, t.settings.accounts.test));

    expect(h.tested.last['certificate'], base64Encode(List.generate(10, (i) => i)));
    expect(h.tested.last['certificate:name'], 'N0DEV.p12');
  });

  testWidgets('a reopened dialog shows the stored file by name, and Remove drops it on Save', (tester) async {
    final h = await _openPane(
      tester,
      stored: {
        'certificate': base64Encode([1, 2, 3]),
        'certificate:name': 'N0DEV.p12',
        'password': 'pw',
      },
    );
    expect(find.text('N0DEV.p12'), findsOneWidget);
    // The stored file went to the extension's test as it was stored.
    expect(h.tested.single['certificate'], base64Encode([1, 2, 3]));

    await _press(tester, _remove);
    expect(find.text(t.settings.accounts.noFileChosen), findsOneWidget);
    await _press(tester, _save);
    // Neither half may linger: a name with no bytes reads as a file to an
    // extension that checks the name, and bytes with no name as one the
    // dialog cannot show.
    expect(h.extensions.store['n0dev-lotw'], {'password': 'pw'});
  });

  testWidgets('a cancelled pick changes nothing', (tester) async {
    final h = await _openPane(
      tester,
      stored: {
        'certificate': base64Encode([1, 2, 3]),
        'certificate:name': 'N0DEV.p12',
      },
    );
    _answerPicks(() => null);
    await _press(tester, _choose);
    expect(find.text('N0DEV.p12'), findsOneWidget);
    await _press(tester, _save);
    expect(h.extensions.store['n0dev-lotw']!['certificate'], base64Encode([1, 2, 3]));
  });

  testWidgets('a file past the cap is refused, saying so, and the chosen one stays', (tester) async {
    final h = await _openPane(
      tester,
      maxBytes: 1024,
      stored: {
        'certificate': base64Encode([1, 2, 3]),
        'certificate:name': 'N0DEV.p12',
      },
    );
    _answerPicks(() => _file('huge.p12', 1025));
    await _press(tester, _choose);

    expect(find.text(t.settings.accounts.fileTooLarge(name: 'huge.p12', size: 1)), findsOneWidget);
    expect(find.text('N0DEV.p12'), findsOneWidget);
    await _press(tester, _save);
    expect(h.extensions.store['n0dev-lotw']!['certificate'], base64Encode([1, 2, 3]));
  });

  testWidgets('an empty file is refused, saying so, and the chosen one stays', (tester) async {
    // Stored, an empty file is '' — which reads back as no file at all, and
    // leaves its name behind in the keychain.
    final h = await _openPane(
      tester,
      stored: {
        'certificate': base64Encode([1, 2, 3]),
        'certificate:name': 'N0DEV.p12',
      },
    );
    _answerPicks(() => _file('placeholder.p12', 0));
    await _press(tester, _choose);

    expect(find.text(t.settings.accounts.fileEmpty(name: 'placeholder.p12')), findsOneWidget);
    expect(find.text('N0DEV.p12'), findsOneWidget);
    await _press(tester, _save);
    expect(h.extensions.store['n0dev-lotw']!['certificate'], base64Encode([1, 2, 3]));
  });

  testWidgets('a file that cannot be read says why, and the field stays as it was', (tester) async {
    await _openPane(tester);
    // A path inside a temp dir of its own: under flutter test the platform is
    // Android, so the read's cleanup runs on it.
    final dir = await tester.runAsync(() => Directory.systemTemp.createTemp('account_file_field_test'));
    addTearDown(() => dir!.delete(recursive: true));
    _answerPicks(() => XFile('${dir!.path}/gone/N0DEV.p12'));
    await _press(tester, _choose);
    // The failed open is real file I/O, answered outside the event queue.
    await _settleRead(tester, wait: const Duration(milliseconds: 200));

    expect(find.textContaining(t.settings.accounts.fileUnreadable(error: '')), findsOneWidget);
    expect(find.text(t.settings.accounts.noFileChosen), findsOneWidget);
  });

  testWidgets('Save and Test wait for a file still being read', (tester) async {
    // On Android a slow provider's file is still being copied with the dialog
    // back on screen; a Save then would store the field without it.
    final h = await _openPane(tester);
    final read = Completer<XFile?>();
    _answerPicks(() => read.future);
    await _press(tester, _choose);

    expect(tester.widget<FilledButton>(_save).onPressed, isNull);
    expect(tester.widget<TextButton>(find.widgetWithText(TextButton, t.settings.accounts.test)).onPressed, isNull);
    expect(h.extensions.store, isEmpty);

    read.complete(_file('N0DEV.p12', 10));
    await _settleRead(tester);
    expect(tester.widget<FilledButton>(_save).onPressed, isNotNull);
    await _press(tester, _save);
    expect(h.extensions.store['n0dev-lotw']!['certificate:name'], 'N0DEV.p12');
  });

  testWidgets('a pick that lands after Disconnect is dropped', (tester) async {
    // Without the drop, the disconnected certificate comes back into the
    // field, and the next Save stores it again.
    await _openPane(
      tester,
      stored: {
        'certificate': base64Encode([1, 2, 3]),
        'certificate:name': 'OLD.p12',
      },
    );
    final read = Completer<XFile?>();
    _answerPicks(() => read.future);
    await _press(tester, _choose);
    await _press(tester, find.widgetWithText(OutlinedButton, t.settings.accounts.disconnect));

    read.complete(_file('N0DEV.p12', 10));
    await _settleRead(tester);
    expect(find.text('N0DEV.p12'), findsNothing);
    expect(find.text(t.settings.accounts.noFileChosen), findsOneWidget);
  });

  testWidgets('a chosen file fits a narrow phone', (tester) async {
    // The name and both buttons side by side overflow a 320 px phone at a
    // raised Font Scale (about 246 logical px); the buttons drop under the
    // name instead. Test glyphs are wider than real ones, so this errs wide.
    tester.view.physicalSize = const Size(246, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await _openPane(
      tester,
      stored: {
        'certificate': base64Encode([1, 2, 3]),
        'certificate:name': 'N0DEV-with-a-long-name.p12',
      },
    );
    expect(tester.takeException(), isNull);
    expect(_remove, findsOneWidget);
    expect(_choose, findsOneWidget);
  });

  testWidgets('a picker that fails says why, and the field stays as it was', (tester) async {
    await _openPane(tester);
    _answerPicks(() => throw const FormatException('provider went away'));
    await _press(tester, _choose);

    expect(find.textContaining('provider went away'), findsOneWidget);
    expect(find.text(t.settings.accounts.noFileChosen), findsOneWidget);
  });

  group('accountFileTypeGroups', () {
    test('a hint that cannot filter by extension offers every file', () {
      // Windows throws for a group without extensions, so a mimeTypes-only
      // hint there would make every pick fail; a malformed one would fail
      // the pick on every platform.
      expect(
        accountFileTypeGroups({
          'accept': {
            'mimeTypes': ['application/x-pkcs12'],
          },
        }),
        isEmpty,
      );
      expect(
        accountFileTypeGroups({
          'accept': {'extensions': 'p12'},
        }),
        isEmpty,
      );
      expect(accountFileTypeGroups({'accept': 'p12'}), isEmpty);
      final groups = accountFileTypeGroups({
        'label': 'Certificate',
        'accept': {
          'extensions': ['p12', 7],
          'mimeTypes': ['application/x-pkcs12'],
        },
      });
      expect(groups.single.extensions, ['p12']);
      expect(groups.single.mimeTypes, ['application/x-pkcs12']);
    });
  });

  group('accountFileSizeLabel', () {
    test('rounds down, so a file under the stated limit is never refused', () {
      // Rounded up, a 1,500-byte cap reads "up to 2 KB" to someone holding a
      // 1.8 KB file.
      expect(accountFileSizeLabel(1500), '1.4');
      expect(accountFileSizeLabel(16384), '16');
      expect(accountFileSizeLabel(kMaxAccountFileBytes), '64');
    });
  });

  group('accountFileCap', () {
    test('a field may ask for less than the host cap, never more', () {
      expect(accountFileCap({'maxBytes': 8192}), 8192);
      // Without the clamp an extension could park megabytes in the keychain
      // and in every hook's ctx.
      expect(accountFileCap({'maxBytes': 10 * 1024 * 1024}), kMaxAccountFileBytes);
      expect(accountFileCap({}), kMaxAccountFileBytes);
      expect(accountFileCap({'maxBytes': 0}), kMaxAccountFileBytes);
      expect(accountFileCap({'maxBytes': 'big'}), kMaxAccountFileBytes);
    });
  });
}
