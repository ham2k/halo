// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The REPORT command (HALO-140) as the app actually reaches it: registered by
// the real ham2k-lofi bundle, dispatched through the real extension host.
//
// This covers the one seam nothing else can. `report.test.ts` unit-tests the
// payload shaping, but it imports `report.ts` precisely BECAUSE that file has
// no `host` dependency — so the registration itself (`registerHook('command',
// {key: 'ham2k-lofi-report'})`, and the catalog/interpret shapes the command
// bar reads) is invisible to it. A REPORT that never registered, or a pattern
// that stopped matching, would leave every unit test green and simply do
// nothing when a user typed it.
//
// The one `execute: true` case below is network-free BECAUSE of what it
// asserts: with sync off the hook refuses before it reaches `request()`. Any
// other execute case would call `request()`, which registers a device against
// the live LoFi server when no token is cached — so the POST itself is
// verified against api-lofi's own controller tests, not from here.

import 'package:flutter_test/flutter_test.dart';
import 'package:ham2k_logger/services/extension_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // One started service for the file: REPORT's interpret path touches no
  // lookups, so there is nothing to isolate between tests, and booting the
  // runtime dwarfs the work of every case below.
  late ExtensionService extensions;

  setUpAll(() async {
    extensions = ExtensionService();
    await extensions.start();
  });

  // REPORT is operation-OPTIONAL — it files a bug from anywhere, including the
  // home screen's Quick Lookup with nothing open — so nothing here passes an
  // operation, and a result is still expected.
  Future<Map<String, dynamic>?> interpret(String input, {bool execute = false}) async {
    final entries = await extensions.host!.invokeHookAll(
      'command',
      method: 'interpret',
      args: {'input': input, if (execute) 'execute': true},
    );
    for (final entry in entries) {
      if (entry['ok'] == true && entry['value'] is Map) {
        return (entry['value'] as Map).cast<String, dynamic>();
      }
    }
    return null;
  }

  Future<Map<String, dynamic>> catalogFor(String command) async {
    final entries = await extensions.host!.invokeHookAll('command', method: 'catalog', args: {});
    for (final entry in entries) {
      if (entry['ok'] != true || entry['value'] is! List) continue;
      for (final item in (entry['value'] as List).cast<Map>()) {
        if (item['command'] == command) return item.cast<String, dynamic>();
      }
    }
    fail('no catalog entry for $command');
  }

  group('REPORT command (real ham2k-lofi extension)', () {
    test('the preview warns what a report may carry, before anything is sent', () async {
      final result = await interpret('REPORT the spots panel came up empty');
      expect(result, isNotNull);
      // A filed report carries more than what was typed — the account, the
      // build, and the open operation. This is the only place the operator is
      // told so before it leaves the machine.
      final describe = result!['describe'] as String;
      expect(describe, contains('account'));
      expect(describe, contains('app'));
      expect(describe, contains('operation'));
      // Deliberately does NOT interpolate the typed text: the dialog renders
      // `describe` as one ellipsized line of markdown, so quoting the
      // description back both truncates this warning away and reformats the
      // operator's own prose (a stray asterisk becomes italics). The row's
      // title already shows what was typed, verbatim and unparsed.
      expect(describe, isNot(contains('the spots panel came up empty')));
      // Without mixedCase the field would snap the description to uppercase as
      // it is typed past the first word, and the card would arrive shouting.
      expect(result['mixedCase'], isTrue);
      // A describe-time submission would file a card on every keystroke.
      expect(result.containsKey('confirm'), isFalse);
    });

    test('a description spanning lines is still recognized', () async {
      // A pasted error message brings its own line breaks, and the field's
      // whitespace filter is off while a command takes free text. A pattern
      // whose `.` excludes newlines stops matching mid-paste, and the Home
      // bar's Enter then clears the whole report as "no match".
      final result = await interpret('REPORT it crashed\r\nwhen I hit Enter');
      expect(result, isNotNull);
      // `describe` present and `expectsParams` absent is what distinguishes a
      // captured description from a bare REPORT still waiting for one. A
      // pattern that matches but drops the capture — keeping only the first
      // line, say — returns the waiting shape, and asserting isNotNull plus
      // mixedCase would not notice: both hold on every return path.
      expect(result!['describe'], isNotNull);
      expect(result.containsKey('expectsParams'), isFalse);
    });

    test('a bare "REPORT" is recognized but waits for a description', () async {
      final result = await interpret('REPORT');
      expect(result, {'expectsParams': true, 'mixedCase': true});
    });

    test('a longer word starting with REPORT is not the command', () async {
      // The command bar sees every keystroke, and callsigns and references run
      // through the same interpret fan-out — matching a bare prefix would make
      // REPORT hijack input meant for something else.
      expect(await interpret('REPORTING'), isNull);
    });

    test('refuses to file without sync, rather than registering a device to do it', () async {
      // request() registers this device with the live server when no token is
      // cached, so reaching it at all is a network write plus persisted
      // credentials for an operator who never enabled sync — and then a 404,
      // because a client with no account behind it cannot file. The refusal has
      // to come BEFORE that, which is also what keeps this case offline: the
      // service booted here has no settings, so syncEnabled reads false.
      //
      // What this pins is the refusal and its message, not the specific
      // setting behind it: every flag on a settings-less service reads false,
      // so a gate on some OTHER false flag would pass here too. The direction
      // that would pin it — sync ON, then assert the call proceeds — is the one
      // direction that cannot be asserted offline.
      final result = await interpret('REPORT the spots panel came up empty', execute: true);
      expect(result, isNotNull);
      expect(result!['error'], contains('enable sync in Settings'));
      // Not a `confirm`: nothing was filed, and the field must keep the typed
      // text so the operator can retry once sync is on.
      expect(result.containsKey('confirm'), isFalse);
    });

    test('the palette advertises REPORT as taking a description', () async {
      final entry = await catalogFor('REPORT');
      expect(entry['expectsParams'], isTrue);
      expect(entry['describe'], isNotEmpty);
      // Operation-scoped commands set needsOperation, which greys the entry out
      // with nothing open. REPORT must not: a bug worth filing is often a bug
      // that stopped an operation from opening at all.
      expect(entry['needsOperation'], isNot(isTrue));
    });
  });
}
