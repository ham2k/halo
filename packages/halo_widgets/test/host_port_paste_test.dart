// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// A server address pasted as `host:port` into a host field whose element
// names its `portField`. The address an operator copies — from rigctld's
// startup line, a Flex's network page, a forum post — almost always carries
// its port, and left whole in the host field it names no host at all.
//
// A typed address splits too, but only once it is finished — as the field is
// left, or the form saved with the field still focused. Typed one character
// at a time it passes through `host:4` on its way to `host:4532`, and
// splitting there would send `4` to the port field and the rest of the port
// into the host.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_widgets/halo_widgets.dart';

void main() {
  group('splitHostPort', () {
    test('a host or address with a port splits', () {
      expect(splitHostPort('10.0.0.5:4532'), (host: '10.0.0.5', port: 4532));
      expect(splitHostPort(' shack.local:4992 '), (host: 'shack.local', port: 4992));
      expect(splitHostPort('[fe80::1]:50001'), (host: 'fe80::1', port: 50001));
    });

    test('a bare IPv6 address is not a host and a port', () {
      // Its last group is all digits, which is exactly what a port looks like.
      expect(splitHostPort('fe80::1'), isNull);
      expect(splitHostPort('2001:db8::4532'), isNull);
    });

    test('a port no socket can name stays in the host', () {
      expect(splitHostPort('radio:0'), isNull);
      expect(splitHostPort('radio:65536'), isNull);
      expect(splitHostPort('radio:'), isNull);
      expect(splitHostPort('radio'), isNull);
    });
  });

  group('HostPortPasteFormatter', () {
    int? port;
    final formatter = HostPortPasteFormatter(onPort: (value) => port = value);
    setUp(() => port = null);

    TextEditingValue value(String text) => TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );

    test('a paste splits', () {
      final result = formatter.formatEditUpdate(value(''), value('10.0.0.5:4532'));
      expect(result.text, '10.0.0.5');
      expect(result.selection, const TextSelection.collapsed(offset: 8));
      expect(port, 4532);
    });

    test('a paste over a selection splits, however little the length changed', () {
      // Select-all over a host as long as the address replacing it: the text
      // grows by nothing, and only counting the selection it replaced tells
      // the paste from a keystroke.
      final old = const TextEditingValue(text: '192.168.1.100', selection: TextSelection(baseOffset: 0, extentOffset: 13));
      expect(formatter.formatEditUpdate(old, value('10.0.0.5:4532')).text, '10.0.0.5');
      expect(port, 4532);
    });

    test('one key typed over a selection never splits', () {
      final old = const TextEditingValue(text: 'radio:453', selection: TextSelection(baseOffset: 6, extentOffset: 9));
      expect(formatter.formatEditUpdate(old, value('radio:4')).text, 'radio:4');
      expect(port, isNull);
    });

    test('typing one character at a time never splits', () {
      expect(formatter.formatEditUpdate(value('10.0.0.5:'), value('10.0.0.5:4')).text, '10.0.0.5:4');
      expect(formatter.formatEditUpdate(value('10.0.0.5:453'), value('10.0.0.5:4532')).text, '10.0.0.5:4532');
      expect(port, isNull);
    });
  });

  group('a form', () {
    const definition = {
      'title': 'Radio',
      'elements': [
        {'type': 'field', 'fieldType': 'text', 'key': 'host', 'label': 'Host', 'portField': 'port'},
        {'type': 'field', 'fieldType': 'number', 'key': 'port', 'label': 'Port'},
      ],
    };

    /// The form, with what it last submitted and every key its presenter's
    /// `onChange` heard, in order. [reply] is what that presenter answers.
    Future<({Map<String, dynamic> submitted, List<String> changes})> pump(
      WidgetTester tester, {
      bool settingsList = false,
      Map<String, dynamic> form = definition,
      Map<String, dynamic> initial = const {'host': '127.0.0.1', 'port': 4532},
      Map<String, dynamic>? Function(String key, dynamic value)? reply,
    }) async {
      final submitted = <String, dynamic>{};
      final changes = <String>[];
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: FormRenderer(
                formDefinition: form,
                initialState: initial,
                settingsList: settingsList,
                onChange: (key, value, state) async {
                  changes.add(key);
                  return reply?.call(key, value);
                },
                onSubmit: submitted.addAll,
                onCancel: () {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      return (submitted: submitted, changes: changes);
    }

    testWidgets('a pasted address fills the port field and saves as two', (tester) async {
      final form = await pump(tester);

      await tester.enterText(find.widgetWithText(TextField, 'Host'), '10.0.0.5:4992');
      await tester.pumpAndSettle();

      expect(tester.widget<TextField>(find.widgetWithText(TextField, 'Port')).controller!.text, '4992');
      // The presenter hears about the port as if it had been typed there.
      expect(form.changes, contains('port'));

      final save = find.widgetWithText(FilledButton, 'Save');
      await tester.ensureVisible(save);
      await tester.tap(save);
      await tester.pumpAndSettle();
      expect(form.submitted, allOf(containsPair('host', '10.0.0.5'), containsPair('port', 4992)));
    });

    /// Types [text] into Host one character at a time, as a keyboard does.
    Future<void> typeHost(WidgetTester tester, String text) async {
      final host = find.widgetWithText(TextField, 'Host');
      await tester.tap(host);
      for (var i = 1; i <= text.length; i++) {
        await tester.enterText(host, text.substring(0, i));
      }
      await tester.pump();
    }

    String fieldText(WidgetTester tester, String label) => tester.widget<TextField>(find.widgetWithText(TextField, label)).controller!.text;

    testWidgets('a typed address splits when the field is left, not while it is typed', (tester) async {
      final form = await pump(tester);
      await typeHost(tester, '10.0.0.5:4992');
      expect(fieldText(tester, 'Host'), '10.0.0.5:4992', reason: 'still being typed');
      expect(fieldText(tester, 'Port'), '4532');

      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();
      expect(fieldText(tester, 'Host'), '10.0.0.5');
      expect(fieldText(tester, 'Port'), '4992');
      expect(form.changes, containsAllInOrder(['port', 'host']));
    });

    testWidgets('a typed address saved with the field still focused saves as two', (tester) async {
      // Save takes no focus: without a split of its own, the form copies its
      // values before the field ever hears it was left.
      final form = await pump(tester);
      await typeHost(tester, '10.0.0.5:4992');

      final save = find.widgetWithText(FilledButton, 'Save');
      await tester.ensureVisible(save);
      await tester.tap(save);
      await tester.pumpAndSettle();
      expect(form.submitted, allOf(containsPair('host', '10.0.0.5'), containsPair('port', 4992)));
    });

    testWidgets('saving waits for what the split port moves along with it', (tester) async {
      // An Icom serial port follows its control port through the presenter's
      // onChange, which answers after the split. Copied before that answer,
      // the save keeps a serial port the radio never answers on.
      final form = await pump(
        tester,
        form: const {
          'title': 'Radio',
          'elements': [
            {'type': 'field', 'fieldType': 'text', 'key': 'host', 'label': 'Host', 'portField': 'port'},
            {'type': 'field', 'fieldType': 'number', 'key': 'port', 'label': 'Port'},
            {'type': 'field', 'fieldType': 'number', 'key': 'serialPort', 'label': 'Serial port'},
          ],
        },
        initial: const {'host': '127.0.0.1', 'port': 50001, 'serialPort': 50002},
        reply: (key, value) => key == 'port' ? {'serialPort': (value as int) + 1} : null,
      );
      await typeHost(tester, '10.0.0.5:60001');

      final save = find.widgetWithText(FilledButton, 'Save');
      await tester.ensureVisible(save);
      await tester.tap(save);
      await tester.pumpAndSettle();
      expect(form.submitted, allOf(containsPair('port', 60001), containsPair('serialPort', 60002)));
    });

    testWidgets('a typed address sends its port where the host field on screen says', (tester) async {
      // The equipment editor declares a `host` per pairing, each behind its
      // own visibleWhen and naming its own port field. The first one declared
      // is not the one being typed into.
      final form = await pump(
        tester,
        form: const {
          'title': 'Radio',
          'elements': [
            {'type': 'field', 'fieldType': 'text', 'key': 'transport', 'label': 'Transport'},
            {
              'type': 'field',
              'fieldType': 'text',
              'key': 'host',
              'label': 'Host',
              'portField': 'tcpPort',
              'visibleWhen': {'field': 'transport', 'equals': 'tcp'},
            },
            {
              'type': 'field',
              'fieldType': 'number',
              'key': 'tcpPort',
              'label': 'TCP port',
              'visibleWhen': {'field': 'transport', 'equals': 'tcp'},
            },
            {
              'type': 'field',
              'fieldType': 'text',
              'key': 'host',
              'label': 'Host',
              'portField': 'remotePort',
              'visibleWhen': {'field': 'transport', 'equals': 'remote'},
            },
            {
              'type': 'field',
              'fieldType': 'number',
              'key': 'remotePort',
              'label': 'Remote port',
              'visibleWhen': {'field': 'transport', 'equals': 'remote'},
            },
          ],
        },
        initial: const {'transport': 'remote', 'host': '127.0.0.1', 'tcpPort': 9200, 'remotePort': 9204},
      );
      await typeHost(tester, 'k4.example.net:9205');
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();
      expect(fieldText(tester, 'Remote port'), '9205');

      final save = find.widgetWithText(FilledButton, 'Save');
      await tester.ensureVisible(save);
      await tester.tap(save);
      await tester.pumpAndSettle();
      expect(form.submitted, allOf(containsPair('host', 'k4.example.net'), containsPair('remotePort', 9205), containsPair('tcpPort', 9200)));
    });

    testWidgets('a host field with no portField keeps the paste whole', (tester) async {
      // The field an entry that fixes its port declares: there is no port
      // field to send it to, and dropping it silently would lose what the
      // operator pasted.
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: FormRenderer(
                formDefinition: const {
                  'title': 'Radio',
                  'elements': [
                    {'type': 'field', 'fieldType': 'text', 'key': 'host', 'label': 'Host'},
                  ],
                },
                initialState: const {},
                onSubmit: (_) {},
                onCancel: () {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(find.widgetWithText(TextField, 'Host'), '10.0.0.5:4992');
      await tester.pumpAndSettle();
      expect(tester.widget<TextField>(find.widgetWithText(TextField, 'Host')).controller!.text, '10.0.0.5:4992');
    });

    testWidgets('a portField naming no field of the form keeps the paste whole', (tester) async {
      // Splitting toward it would store a port nothing on screen shows.
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: FormRenderer(
                formDefinition: const {
                  'title': 'Radio',
                  'elements': [
                    {'type': 'field', 'fieldType': 'text', 'key': 'host', 'label': 'Host', 'portField': 'udpPort'},
                  ],
                },
                initialState: const {},
                onSubmit: (_) {},
                onCancel: () {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(find.widgetWithText(TextField, 'Host'), '10.0.0.5:4992');
      await tester.pumpAndSettle();
      expect(tester.widget<TextField>(find.widgetWithText(TextField, 'Host')).controller!.text, '10.0.0.5:4992');
    });

    testWidgets('a settings row splits a typed address as its edit dialog closes', (tester) async {
      await pump(tester, settingsList: true);
      await tester.tap(find.text('Host'));
      await tester.pumpAndSettle();
      final field = find.byType(TextField).last;
      for (final text in ['1', '1:', '1:4', '1:49', '1:499', '1:4992']) {
        await tester.enterText(field, text);
      }
      await tester.pump();
      expect(tester.widget<TextField>(field).controller!.text, '1:4992', reason: 'typed, so nothing splits in the dialog');

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(find.text('1'), findsOneWidget);
      expect(find.text('4992'), findsOneWidget);
    });

    testWidgets('a settings row splits the paste in its edit dialog', (tester) async {
      await pump(tester, settingsList: true);
      await tester.tap(find.text('Host'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).last, '10.0.0.5:4992');
      await tester.pumpAndSettle();
      // The dialog shows what the host field will hold, so the split is seen
      // as it happens rather than discovered after closing.
      expect(tester.widget<TextField>(find.byType(TextField).last).controller!.text, '10.0.0.5');

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(find.text('10.0.0.5'), findsOneWidget);
      expect(find.text('4992'), findsOneWidget);
    });
  });
}
