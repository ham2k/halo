// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Every file from outside the app — opened from the OS or dropped anywhere
// on the window — goes through one router, and the views on screen suggest
// where it goes. The traps: a file with several places to go going to one of
// them without asking; the view's suggestion not being the one Enter takes;
// a view behind a dialog, or slid away, still suggesting; the same import
// offered twice under two names; and a second file's dialog stacked on the
// first's.

import 'dart:async';
import 'dart:convert';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_i18n/halo_i18n.dart';
import 'package:ham2k_logger/config/navigation.dart' show navigatorKey;
import 'package:ham2k_logger/views/file_open/file_kind.dart';
import 'package:ham2k_logger/views/file_open/file_router.dart';

XFile _file(String name, [String content = '']) => XFile.fromData(Uint8List.fromList(utf8.encode(content)), name: name, path: name);

/// A destination that records what it was handed, and finishes when [done]
/// does.
class _Recorder {
  _Recorder(this.id, {this.label, this.kind = HaloFileKind.adif});

  final String id;
  final String? label;
  final HaloFileKind kind;
  final opened = <String>[];
  Completer<void>? done;

  FileDestination get destination => FileDestination(
    id: id,
    label: () => label ?? id,
    kind: kind,
    open: (_, file) {
      opened.add(file.name);
      return done?.future ?? Future<void>.value();
    },
  );
}

Future<void> _pump(WidgetTester tester, Widget body) async {
  tester.view.physicalSize = const Size(800, 600);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    TranslationProvider(
      child: MaterialApp(
        navigatorKey: navigatorKey,
        home: Scaffold(body: body),
      ),
    ),
  );
}

/// Lets the router read the file and act, a frame at a time.
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 10; i++) {
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pump(const Duration(milliseconds: 50));
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('a file with one place to go goes there without asking', (tester) async {
    // The Logs view's own import stands in for the always-there one with
    // its id: the same import, so one place, not two.
    final logsView = _Recorder('logs');
    final logsAnywhere = _Recorder('logs');
    final layouts = _Recorder('layouts', kind: HaloFileKind.layout);
    await _pump(tester, FileSuggestions(suggestions: [logsView.destination, layouts.destination], child: const SizedBox.expand()));
    final router = FileRouter(globals: () => [logsAnywhere.destination]);

    router.open(_file('log.adi'));
    await _settle(tester);

    expect(find.byType(SimpleDialog), findsNothing);
    expect(logsView.opened, ['log.adi']);
    expect(logsAnywhere.opened, isEmpty);
    expect(layouts.opened, isEmpty);
  });

  testWidgets('with several places to go it asks, and Enter takes what the view suggested', (tester) async {
    // An operation's dock suggests layouts inside the operation, which
    // suggests its ADIF import: the inner scope taking nothing for a log
    // must not hide the operation's suggestion behind the app's own.
    final operation = _Recorder('operation', label: 'This operation');
    final dock = _Recorder('dock', kind: HaloFileKind.layout);
    final logs = _Recorder('logs', label: 'Logs');
    await _pump(
      tester,
      FileSuggestions(
        suggestions: [operation.destination],
        child: FileSuggestions(suggestions: [dock.destination], child: const SizedBox.expand()),
      ),
    );
    final router = FileRouter(globals: () => [logs.destination]);

    router.open(_file('log.adi'));
    await _settle(tester);
    final options = [for (final tile in tester.widgetList<ListTile>(find.byType(ListTile))) (tile.title! as Text).data];
    expect(options, ['This operation', 'Logs']);

    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await _settle(tester);
    expect(operation.opened, ['log.adi']);
    expect(logs.opened, isEmpty);
  });

  testWidgets('with no suggestion on screen it asks with nothing chosen for the operator', (tester) async {
    await _pump(tester, const SizedBox.expand());
    final router = FileRouter(globals: () => [_Recorder('logs').destination, _Recorder('elsewhere').destination]);

    router.open(_file('log.adi'));
    await _settle(tester);

    expect(find.byType(ListTile), findsNWidgets(2));
    expect(tester.widgetList<ListTile>(find.byType(ListTile)).where((tile) => tile.autofocus), isEmpty);
  });

  testWidgets('a view its view says is not showing suggests nothing', (tester) async {
    final operation = _Recorder('operation');
    final hidden = _Recorder('hidden');
    await _pump(
      tester,
      FileSuggestions(
        suggestions: [operation.destination],
        child: FileSuggestions(active: () => false, suggestions: [hidden.destination], child: const SizedBox.expand()),
      ),
    );

    expect(FileSuggestions.onScreen().map((d) => d.id), ['operation']);
  });

  testWidgets('a file waits while a dialog is up, then goes where the view under it suggests', (tester) async {
    // Routed under the dialog, the view behind it would suggest nothing and
    // the log would go to Logs alone, whose import first closes every route
    // on top: the dialog, and what the operator had in it, without asking.
    final operation = _Recorder('operation', label: 'This operation');
    final logs = _Recorder('logs', label: 'Logs');
    await _pump(tester, FileSuggestions(suggestions: [operation.destination], child: const SizedBox.expand()));
    final router = FileRouter(globals: () => [logs.destination]);

    unawaited(
      showDialog<void>(
        context: navigatorKey.currentContext!,
        builder: (_) => const AlertDialog(content: Text('busy')),
      ),
    );
    await tester.pumpAndSettle();
    router.open(_file('log.adi'));
    await _settle(tester);
    expect(find.text('busy'), findsOneWidget, reason: 'the dialog stays up');
    expect(find.byType(ListTile), findsNothing);
    expect(logs.opened, isEmpty);

    Navigator.of(tester.element(find.text('busy'))).pop();
    await _settle(tester);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await _settle(tester);
    expect(operation.opened, ['log.adi']);
    expect(logs.opened, isEmpty);
  });

  testWidgets('a file that cannot be read says why, not that HaLo does not read its kind', (tester) async {
    await _pump(tester, const SizedBox.expand());
    final router = FileRouter(globals: () => [_Recorder('logs').destination]);

    router.open(XFile('/no/such/folder/notes.txt'));
    await _settle(tester);

    expect(find.descendant(of: find.byType(Dialog), matching: find.text('Can’t open notes.txt')), findsOneWidget);
    expect(find.text(t.fileOpen.cannotOpenDetail), findsNothing);
  });

  testWidgets('a file nothing takes says so in a dialog, which the next file waits behind', (tester) async {
    // A toast is missed while the operator watches for the file to open,
    // and reads as the drop having done nothing.
    final logs = _Recorder('logs');
    await _pump(tester, const SizedBox.expand());
    final router = FileRouter(globals: () => [logs.destination]);

    router.open(_file('notes.txt', 'just some text'));
    router.open(_file('log.adi'));
    await _settle(tester);

    expect(find.descendant(of: find.byType(Dialog), matching: find.text('Can’t open notes.txt')), findsOneWidget);
    expect(find.byType(SnackBar), findsNothing);
    expect(logs.opened, isEmpty, reason: 'the next file waits until the refusal is read');

    await tester.tap(find.text('Done'));
    await _settle(tester);
    expect(logs.opened, ['log.adi']);
  });

  testWidgets('files wait their turn: the next starts only when the last is done', (tester) async {
    final logs = _Recorder('logs')..done = Completer<void>();
    await _pump(tester, const SizedBox.expand());
    final router = FileRouter(globals: () => [logs.destination]);

    router.open(_file('one.adi'));
    router.open(_file('two.adi'));
    await _settle(tester);
    expect(logs.opened, ['one.adi'], reason: 'the first import is still showing its summary');

    logs.done!.complete();
    logs.done = null;
    await _settle(tester);
    expect(logs.opened, ['one.adi', 'two.adi']);
  });

  group('classifyFile', () {
    test('names the kind from the extension the platforms register', () {
      expect(fileKindOfName('x.H2KEXT'), HaloFileKind.extension);
      expect(fileKindOfName('x.h2kkey'), HaloFileKind.keyBindings);
      expect(fileKindOfName('x.h2klyt'), HaloFileKind.layout);
      expect(fileKindOfName('x.h2kset'), HaloFileKind.cwMessages);
      expect(fileKindOfName('x.h2kvoice'), HaloFileKind.voiceMessages);
      expect(fileKindOfName('x.qson'), HaloFileKind.qson);
      expect(fileKindOfName('x.adi'), HaloFileKind.adif);
      expect(fileKindOfName('x.adif'), HaloFileKind.adif);
      // YAML, zip and JSON are each several kinds, or none.
      expect(fileKindOfName('x.yaml'), isNull);
      expect(fileKindOfName('x.zip'), isNull);
    });

    test('reads ADIF from the bytes of a file whose name says nothing', () async {
      // A share that arrives as .txt, or a provider that drops the extension.
      expect(await classifyFile(_file('shared.txt', 'export\n<CALL:4>W1AW<EOR>')), HaloFileKind.adif);
      expect(await classifyFile(_file('notes.txt', 'just some text')), isNull);
    });
  });
}
