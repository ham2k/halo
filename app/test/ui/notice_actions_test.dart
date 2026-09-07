// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The notice action handler shows dialogs through the app-global navigatorKey
// (it has no BuildContext of its own). This verifies that path actually
// resolves a Navigator — a `dialog` action must open a modal carrying the
// server-supplied title/text — rather than silently failing.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ham2k_logger/main.dart' show navigatorKey;
import 'package:ham2k_logger/views/notice_actions.dart';

void main() {
  testWidgets('dialog action opens a modal via the global navigator', (tester) async {
    await tester.pumpWidget(MaterialApp(
      navigatorKey: navigatorKey,
      home: const Scaffold(body: SizedBox()),
    ));

    handleNoticeAction('n', {
      'action': 'dialog',
      'args': {
        'dialogTitle': 'Support Ham2K',
        'dialogText': 'Please help',
        'dialogActions': [
          {'label': 'Later', 'action': 'noop'},
        ],
      },
    });
    await tester.pumpAndSettle();

    expect(find.text('Support Ham2K'), findsOneWidget);
    expect(find.text('Please help'), findsOneWidget);
    expect(find.text('Later'), findsOneWidget);
    // Done, not Close: a notice's own actions sit beside it, but the way out
    // of a dialog with nothing to commit is Done everywhere in the app.
    expect(find.text('Done'), findsOneWidget);

    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();
    expect(find.text('Support Ham2K'), findsNothing);
  });
}
