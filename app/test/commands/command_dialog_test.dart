// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The ⌘K command dialog (ham2k/halo-dist#55). What these pin down is the
// palette's own behavior — the typing/interpretation rules it inherits from
// `CommandEngine` are covered by home_quick_lookup_test.dart, which runs the
// same engine.
//
// The load-bearing parts:
//
//  • Advertised commands are listed and narrowed by substring, so the dialog
//    is a DISCOVERY surface — that's the whole point of the `catalog` hook.
//  • ↑/↓ + Enter pick a row. Arrow keys have to beat the text field's own
//    caret movement (DefaultTextEditingShortcuts is an app-root ancestor, so
//    the dialog's CallbackShortcuts, being nearer the focus, wins) — if that
//    ever inverts, the palette silently stops being keyboard-navigable.
//  • A command that takes parameters is TYPED IN, not run: picking "NOTE"
//    must not log an empty note.
//  • An operation-scoped command with no operation open is inert, rather
//    than running and coming back with the hook's error.
//  • The callsign lookup line is information, never a selection — Enter with
//    it on screen must not "activate" it.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_widgets/halo_widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ham2k_logger/config/tester_notes.dart';
import 'package:halo_i18n/halo_i18n.dart';
import 'package:ham2k_logger/main.dart';
import 'package:ham2k_logger/services/extension_service.dart';
import 'package:ham2k_logger/services/settings_service.dart';
import 'package:ham2k_logger/views/command_dialog.dart';
import 'package:ham2k_logger/views/command_engine.dart';
import 'package:ham2k_logger/views/operation/call_info_panel.dart';

import '../support/halo_test_support.dart';

class _CannedExtensions extends ExtensionService {
  @override
  bool get ready => true;

  @override
  Future<void> start() async {}

  /// Commands executed through `interpret(execute: true)`.
  final executed = <String>[];

  @override
  Future<List<Map<String, dynamic>>> getCommandCatalog() async => [
    {'command': 'DEVMODE', 'describe': 'Toggle developer mode', 'category': 'Developer'},
    {'command': 'NOTE', 'params': '<text>', 'describe': 'Add a note to the log', 'category': 'Log annotations', 'needsOperation': true, 'expectsParams': true},
    {'command': 'SYNCALL', 'describe': 'Sync all operations now', 'category': 'Sync'},
    // Advertised in the catalog AND currently unrunnable, so a query for it
    // puts an error and a result row on screen together. Deliberately NOT
    // `needsOperation` — the palette drops those entirely with no operation
    // open, which would empty the list and hide the very collision this
    // models (the real shape is SYNCALL erroring while sync is disabled).
    {'command': 'WIPEDB', 'describe': 'Erase the local database', 'category': 'Developer'},
    // The ranking pair: "SET" is in SETUP's NAME and in 20M's
    // DESCRIPTION, and the name match has to win. Also the only two
    // `suggest` entries, so the empty-field samples are deterministic:
    // DEVMODE and SYNCALL stand in for the commands that must never be
    // volunteered.
    {'command': 'SETUP', 'describe': 'Open the setup screen', 'category': 'App', 'suggest': true},
    {'command': '20M', 'describe': 'Set the band to **20m**', 'category': 'Radio', 'suggest': true},
  ];

  @override
  Future<Map<String, dynamic>?> interpretCommand(String input, [Map<String, dynamic>? operation, Map<String, dynamic>? qso, bool execute = false]) async {
    final trimmed = input.trim().toUpperCase();
    interpretCalls++;
    if (execute) {
      executed.add(trimmed);
      if (executeGate != null) await executeGate!.future;
    }
    if (trimmed == 'DEVMODE') {
      return {
        'describe': 'Activate developer mode?',
        'confirm': 'Developer mode activated',
        'commands': [
          {
            'updateSettings': {'developerMode': true},
          },
        ],
      };
    }
    if (trimmed == 'SYNCALL') {
      return {
        'describe': 'Sync everything?',
        'confirm': 'Syncing…',
        'commands': [
          {'syncAll': {}},
        ],
      };
    }
    if (trimmed == '20M') {
      return {
        'describe': 'Change band to **20m**?',
        'confirm': 'Band set to **20m**',
        'commands': [
          {
            'setVfo': {'band': '20m'},
          },
        ],
      };
    }
    if (trimmed == 'SETUP') {
      return {
        'describe': 'Open setup?',
        'confirm': 'Opening setup',
        'commands': [
          {'syncAll': {}},
        ],
      };
    }
    if (trimmed == 'NOTE') return {'expectsParams': true, 'mixedCase': true};
    // The SOLAR shape: a hook that answers immediately with a placeholder and
    // pushes the real reading through `host.updateInterpretation` once its
    // fetch lands. Deliberately NOT in the catalog — the ranking tests count
    // on the entries there.
    if (trimmed == 'SOLAR') return {'describe': 'Fetching solar conditions…'};
    // Recognized but not runnable right now — the shape a hook returns when
    // the app isn't in a state to accept it. WIPEDB is also in the catalog, so
    // this is the case where an error and a result row are on screen together.
    if (trimmed == 'WIPEDB') return {'error': 'WIPEDB needs an open operation'};
    // Carries a confirm AND an action that fails — the case where the
    // optimistic confirm must not paint over the action's bad news.
    if (trimmed == 'FAILWRITE') {
      return {
        'describe': 'Change Thing to On?',
        'confirm': 'Thing set to On',
        'commands': [
          {
            'updateSetting': {'key': 'noSuchThing', 'value': true},
          },
        ],
      };
    }
    // The shape a settings command returns when the words name no setting:
    // recognized (so Enter can't log it as a callsign), not runnable, and
    // carrying the only explanation the operator will get.
    //
    // Bare 'SET' answers too: a prefix still being typed is recognized but not
    // runnable, which is the state the tests below drive through.
    if (trimmed == 'SET') return {'expectsParams': true, 'mixedCase': true};
    if (trimmed.startsWith('SET ')) {
      return {'expectsParams': true, 'mixedCase': true, 'describe': 'No setting matches that'};
    }
    return null;
  }

  /// Stands in for the extension runtime's `host.updateInterpretation`
  /// channel, which the real service feeds from the host.
  final _pushes = StreamController<Map<String, dynamic>>.broadcast();

  @override
  Stream<Map<String, dynamic>> get commandInterpretationUpdates => _pushes.stream;

  /// A `command` hook answering again, later, for an input it already
  /// interpreted.
  void pushInterpretation(String input, Map<String, dynamic> interpretation) => _pushes.add({'input': input, 'interpretation': interpretation});

  /// Each lookup pass, in order, as ('CALL', online) — so a test can assert
  /// the offline pass really does run first, and that a caret move causes no
  /// further passes at all.
  final lookupPasses = <(String, bool)>[];

  int interpretCalls = 0;

  /// Holds an execute-time interpret open, so a test can type into the field
  /// while a command it already ran is still in flight.
  Completer<void>? executeGate;

  /// Completes the online pass only when a test says so, to hold the dialog
  /// in its mid-lookup state.
  Completer<void>? gateOnline;

  /// Makes the online pass answer with nothing, as it does with no sources
  /// configured.
  bool onlineReturnsNothing = false;

  @override
  Future<Map<String, dynamic>?> lookupCall(
    String call, {
    Map<String, dynamic>? qso,
    Map<String, dynamic>? operation,
    bool online = true,
    bool recentContext = false,
  }) async {
    lookupPasses.add((call, online));
    if (!online) {
      // What the offline data files can answer: country, no name.
      return {
        'guess': {'call': call, 'entityName': 'United States', 'entityPrefix': 'K'},
        'lookups': const [],
      };
    }
    if (gateOnline != null) await gateOnline!.future;
    if (onlineReturnsNothing) return null;
    // The shape a REAL lookup returns — flag, emoji, note, coordinates and
    // all — not a trimmed-down stand-in. A guess with only a couple of
    // fields exercises almost none of CallInfoPanel.
    return {
      'guess': {
        'call': call,
        'baseCall': call,
        'name': 'Hiram Percy Maxim',
        'entityName': 'United States',
        'entityPrefix': 'K',
        'dxccCode': 291,
        'continent': 'NA',
        'cqZone': 5,
        'ituZone': 8,
        'flag': '🇺🇸',
        'emoji': '📻',
        'note': 'ARRL headquarters',
        'city': 'Newington',
        'state': 'CT',
        'country': 'United States',
        'location': 'Newington, CT',
        'grid': 'FN31pr',
        'lat': 41.714,
        'lon': -72.727,
      },
      'lookups': const [
        {
          'notes': ['ARRL co-founder'],
        },
      ],
    };
  }
}

Future<HaLoServices> _services(WidgetTester tester) async {
  SharedPreferences.setMockInitialValues({});
  // Empty prefs mean lastSeenTesterBuild == 0, so without this stub the
  // tester gate loads the real tester-notes asset mid-test and mounts a
  // focus-stealing full-screen overlay over the ⌘K assertions.
  setTesterNotesForTesting(const []);
  return (await makeHaLoServices(prefs: null, extensions: _CannedExtensions())).services;
}

/// Opens the dialog the way ⌘K does — as a route over a host screen — so
/// that closing it (which the dialog does itself after running a command)
/// behaves as it does in the app.
Future<void> _pumpDialog(WidgetTester tester, HaLoServices services, {bool settle = true}) async {
  await tester.pumpWidget(
    TranslationProvider(
      child: MaterialApp(
        theme: buildHaLoTheme(Brightness.light),
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(onPressed: () => showCommandDialog(context, services), child: const Text('open')),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  if (settle) await _settle(tester);
}

/// Pumps enough frames for the route transition, the catalog read and — the
/// one that bites — the panel's `AnimatedSize`.
///
/// Two things make this fiddly, and both cost an afternoon once:
///
///  • `pumpAndSettle` is unusable here. The dialog autofocuses its field, and
///    a focused TextField's cursor blink schedules frames forever, so
///    settling never completes and the test hangs until its own timeout.
///  • `AnimatedSize` CLIPS HIT-TESTING to its in-progress box while it grows.
///    A row can therefore be laid out, painted and returned by `getRect`, yet
///    still be untappable — `tap()` reports no miss and the callback simply
///    never fires. Only extra frames fix it. (Real usage is unaffected: frames
///    arrive continuously there, so the 120ms animation finishes on its own.)
Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  for (var i = 0; i < 4; i++) {
    await tester.pump(const Duration(milliseconds: 150));
  }
}

/// Unmounts the tree *inside* the test body. The dialog's operations list is
/// a drift stream, and when its StreamBuilder unsubscribes drift schedules a
/// zero-duration timer (`StreamQueryStore.markAsClosed`) to close the query.
/// At normal teardown that timer is still pending, which trips the binding's
/// "A Timer is still pending even after the widget tree was disposed"
/// invariant — so every test ends by unmounting and pumping once more, giving
/// that timer a chance to actually run.
Future<void> _unmount(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  // A real duration, not a bare pump(): the timer drift schedules is
  // zero-duration, and under fake async only advancing the clock runs it.
  await tester.pump(const Duration(milliseconds: 1));
}

/// Opens a command-context entry the way `OperationView` does, optionally with
/// a logging-panel dispatcher attached. Returns the entry so a test can close
/// it again and check what the palette sees afterwards.
OperationCommandContext _openOperation(HaLoServices services, String uuid, {CommandActionsDispatcher? dispatch}) {
  final entry = services.openOperationContext(uuid);
  entry.operation = {'uuid': uuid};
  entry.dispatch = dispatch;
  return entry;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('the field takes the shared input rules, not a copy of them', (tester) async {
    // What a space and a letter's case MEAN is covered once, against the
    // engine, in home_quick_lookup_test.dart. What this catches is the two
    // fields drifting apart: their rules are identical and hand-copying them
    // gets one of the two fixed and the other left behind.
    final services = await _services(tester);
    await _pumpDialog(tester, services);

    // Chained, as the framework chains them: each formatter's output is the
    // next one's input. Feeding them all the raw edit instead lets the
    // collapse pass be silently discarded by the one after it.
    String runThrough(List<TextInputFormatter>? formatters) {
      var value = const TextEditingValue(text: 'note  Hello There');
      for (final formatter in formatters!) {
        value = formatter.formatEditUpdate(const TextEditingValue(text: ''), value);
      }
      return value.text;
    }

    final field = tester.widget<TextField>(find.byType(TextField));
    expect(runThrough(field.inputFormatters), runThrough(commandFieldFormatters));
    expect(runThrough(field.inputFormatters), 'NOTE Hello There');

    await _unmount(tester);
  });

  testWidgets('an empty field offers two sample commands while the dialog is still new', (tester) async {
    final services = await _services(tester);
    await _pumpDialog(tester, services);

    // Two, not the whole catalog: an empty field is a nudge toward what's
    // available, not a browse-everything list.
    expect(find.byIcon(MdiIcons.consoleLine), findsNWidgets(2));
    expect(find.text('Try'), findsOneWidget);

    await _unmount(tester);
  });

  testWidgets('the field takes focus only after the entrance transition completes', (tester) async {
    final services = await _services(tester);
    await _pumpDialog(tester, services, settle: false);

    // Mid-transition (the route animates for 140ms). Requesting focus while
    // the dialog is still animating in is what loses the browser's DOM focus
    // on web — anything animating alongside the open (a status bar progress
    // item) makes that race reliable — so focus must not land yet.
    await tester.pump(const Duration(milliseconds: 70));
    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.focusNode!.hasFocus, isFalse, reason: 'focusing mid-transition loses web DOM focus');

    // Past the transition: the completion listener fires and focus sticks.
    await tester.pump(const Duration(milliseconds: 150));
    await tester.pump();
    expect(field.focusNode!.hasFocus, isTrue);

    await _unmount(tester);
  });

  testWidgets('suggestions only offer commands that opted in with `suggest`', (tester) async {
    final services = await _services(tester);
    await _pumpDialog(tester, services);

    // The pool is exactly the catalog's `suggest: true` entries, never the
    // whole catalog: DEVMODE and SYNCALL stand in for developer and
    // destructive commands, which must stay searchable but can never be
    // volunteered to someone who doesn't yet know what they do.
    expect(find.text('SETUP'), findsOneWidget);
    expect(find.text('20M'), findsOneWidget);
    expect(find.text('DEVMODE'), findsNothing);
    expect(find.text('SYNCALL'), findsNothing);

    await _unmount(tester);
  });

  testWidgets('after ten opens an empty field offers nothing at all', (tester) async {
    final services = await _services(tester);
    for (var i = 0; i < 10; i++) {
      await services.settings.recordOnboardingShown(OnboardingFlows.commandDialog);
    }

    await _pumpDialog(tester, services);

    expect(find.byIcon(MdiIcons.consoleLine), findsNothing, reason: 'the samples have done their job by now');
    expect(find.text('Try'), findsNothing);

    await _unmount(tester);
  });

  testWidgets('ranks name matches above description matches', (tester) async {
    final services = await _services(tester);
    await _pumpDialog(tester, services);

    // "SET" appears in SETUP's NAME and in 20M's description ("Set the
    // band"). The name match has to win — ranking by catalog order alone put
    // 20M first, which is what made typing "SET" feel broken.
    await tester.enterText(find.byType(TextField), 'SET');
    await tester.pump(const Duration(milliseconds: 200));

    final rows = tester.widgetList<Text>(find.byType(Text)).map((w) => w.data).whereType<String>().toList();
    final setup = rows.indexWhere((t) => t.startsWith('SETUP'));
    final band = rows.indexWhere((t) => t.startsWith('20M'));
    expect(setup, isNonNegative);
    expect(band, isNonNegative);
    expect(setup, lessThan(band), reason: 'a command NAMED SETUP outranks one merely described as "Set the band"');

    await _unmount(tester);
  });

  testWidgets('narrows the list to substring matches, on the command and on its description', (tester) async {
    final services = await _services(tester);
    await _pumpDialog(tester, services);

    await tester.enterText(find.byType(TextField), 'SYNC');
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('SYNCALL'), findsOneWidget);
    expect(find.text('DEVMODE'), findsNothing);

    // "developer" matches DEVMODE's describe, not just its name.
    await tester.enterText(find.byType(TextField), 'DEVELOPER');
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('DEVMODE'), findsOneWidget);
    expect(find.text('SYNCALL'), findsNothing);

    await _unmount(tester);
  });

  testWidgets('↓ then Enter runs the highlighted command rather than moving the caret', (tester) async {
    final services = await _services(tester);
    await _pumpDialog(tester, services);

    // "S" ranks SYNCALL and SETUP first (both name matches), then 20M (its
    // description starts with "Set"). One ↓ moves off SYNCALL onto SETUP.
    await tester.enterText(find.byType(TextField), 'S');
    await tester.pump(const Duration(milliseconds: 200));

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();

    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // SETUP, not SYNCALL — if the arrow key had gone to the text field's
    // caret instead, the selection would still be on the first row and THAT
    // is what would have run.
    final extensions = services.extensions as _CannedExtensions;
    expect(extensions.executed, contains('SETUP'));
    expect(extensions.executed, isNot(contains('SYNCALL')));
    // Running a command dismisses the palette, once its response has been on
    // screen for its five seconds.
    await tester.pump(const Duration(seconds: 6));
    await _settle(tester);
    expect(find.byType(CommandDialog), findsNothing);

    await _unmount(tester);
  });

  testWidgets('tapping a parameterless command runs it', (tester) async {
    final services = await _services(tester);
    await _pumpDialog(tester, services);

    await tester.enterText(find.byType(TextField), 'DEV');
    await _settle(tester);

    // find.text, not the field's own contents — "DEV" doesn't collide with
    // the row's "DEVMODE" label the way typing the full name would.
    await tester.tap(find.text('DEVMODE'));
    await _settle(tester);

    expect((services.extensions as _CannedExtensions).executed, contains('DEVMODE'));
    expect(services.settings.developerMode, isTrue, reason: 'the action must actually be dispatched');

    // The palette holds its response for five seconds and then dismisses
    // itself — see the response tests below.
    expect(find.byType(CommandDialog), findsOneWidget);
    await tester.pump(const Duration(seconds: 6));
    await _settle(tester);
    expect(find.byType(CommandDialog), findsNothing);

    await _unmount(tester);
  });

  testWidgets('an operation-scoped command is not offered at all with no operation open', (tester) async {
    final services = await _services(tester);
    expect(services.currentOperationContext, isNull);
    await _pumpDialog(tester, services);

    await tester.enterText(find.byType(TextField), 'NOTE');
    await _settle(tester);

    // Absent, not greyed out: offering something unpickable is just noise.
    expect(find.text('NOTE <text>'), findsNothing);

    await _unmount(tester);
  });

  testWidgets('with an operation open, a parameterised command is typed in — not run', (tester) async {
    final services = await _services(tester);
    _openOperation(services, 'op-1');
    await _pumpDialog(tester, services);

    await tester.enterText(find.byType(TextField), 'NOTE');
    await _settle(tester);
    expect(find.text('NOTE <text>'), findsOneWidget, reason: 'with an operation open it becomes available');

    await tester.tap(find.text('NOTE <text>'));
    await _settle(tester);

    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      'NOTE ',
      reason: 'the user still has to say what the note says — running it now would log an empty one',
    );
    expect((services.extensions as _CannedExtensions).executed, isEmpty);

    await _unmount(tester);
  });

  testWidgets('a callsign says so immediately, then fills in offline before online', (tester) async {
    final services = await _services(tester);
    final extensions = services.extensions as _CannedExtensions;
    extensions.gateOnline = Completer<void>();
    await _pumpDialog(tester, services);

    await tester.enterText(find.byType(TextField), 'W1AW');
    await tester.pump();

    // Before any debounce has elapsed: the user is told a lookup is coming,
    // rather than staring at an empty panel while the network works.
    expect(find.text('Looking up callsign…'), findsOneWidget);
    expect(extensions.lookupPasses, isEmpty);

    // Past the debounce, the offline pass has answered and the online one is
    // still in flight — the country shows without waiting for the network.
    await tester.pump(const Duration(milliseconds: 400));
    await _settle(tester);
    // The online pass has been *started* (it records itself before awaiting
    // the gate) but hasn't answered — what matters is that offline went
    // first and its result is already on screen.
    expect(extensions.lookupPasses.first, ('W1AW', false), reason: 'the offline pass runs first');
    expect(find.textContaining('United States', findRichText: true), findsWidgets);
    expect(find.textContaining('Hiram Percy Maxim', findRichText: true), findsNothing);

    // Once the online pass lands, the fuller record replaces it.
    extensions.gateOnline!.complete();
    await _settle(tester);
    expect(extensions.lookupPasses, [('W1AW', false), ('W1AW', true)]);
    expect(find.textContaining('Hiram Percy Maxim', findRichText: true), findsWidgets);
    // Rendered by the very same panel the Call Info pane uses.
    expect(find.byType(CallInfoPanel), findsOneWidget);

    await _unmount(tester);
  });

  testWidgets('Enter on a callsign keeps it — the lookup IS the result', (tester) async {
    // Enter used to wipe the field whenever nothing matched a command, which
    // on a callsign threw away the lookup the user had just asked for and
    // dropped the palette back to its sample commands — with the stale
    // "Looking up callsign…" spinner still sitting over an empty field.
    final services = await _services(tester);
    await _pumpDialog(tester, services);

    await tester.enterText(find.byType(TextField), 'W1AW');
    await tester.pump(const Duration(milliseconds: 400));
    await _settle(tester);
    expect(find.byType(CallInfoPanel), findsOneWidget);

    await tester.testTextInput.receiveAction(TextInputAction.done);
    await _settle(tester);

    expect(tester.widget<TextField>(find.byType(TextField)).controller!.text, 'W1AW', reason: 'the callsign must survive Enter');
    expect(find.byType(CallInfoPanel), findsOneWidget, reason: 'and so must its lookup');
    expect(find.text('Looking up callsign…'), findsNothing, reason: 'no spinner once the lookup is done');
    expect(find.text('Try'), findsNothing, reason: 'suggestions are for an EMPTY field');
    expect((services.extensions as _CannedExtensions).executed, isEmpty);
    expect(find.byType(CommandDialog), findsOneWidget, reason: 'a lookup is not an action to run');

    await _unmount(tester);
  });

  testWidgets('an online pass that finds nothing keeps what offline already found', (tester) async {
    // No sources configured, or genuinely offline: the online pass returns
    // null and must not wipe out the country the data files supplied.
    final services = await _services(tester);
    final extensions = services.extensions as _CannedExtensions;
    extensions.onlineReturnsNothing = true;
    await _pumpDialog(tester, services);

    await tester.enterText(find.byType(TextField), 'W1AW');
    await tester.pump(const Duration(milliseconds: 400));
    await _settle(tester);

    expect(find.textContaining('United States', findRichText: true), findsWidgets);

    await _unmount(tester);
  });

  testWidgets('Escape closes the dialog', (tester) async {
    final services = await _services(tester);

    await tester.pumpWidget(
      TranslationProvider(
        child: MaterialApp(
          theme: buildHaLoTheme(Brightness.light),
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(onPressed: () => showCommandDialog(context, services), child: const Text('open')),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(CommandDialog), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(CommandDialog), findsNothing);

    await _unmount(tester);
  });

  testWidgets('⌘K opens the dialog, and a second ⌘K closes it', (tester) async {
    // The one thing the other tests can't reach: the global handler in
    // main.dart that actually binds the shortcut. Everything else here pumps
    // CommandDialog directly, so without this a rename or a lost
    // `addHandler` would leave every test green and the feature unreachable.
    final services = await _services(tester);

    await tester.pumpWidget(TranslationProvider(child: HaLoApp(services: services)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(CommandDialog), findsNothing);

    await _pressCommandK(tester);
    expect(find.byType(CommandDialog), findsOneWidget);

    // Toggles rather than stacking a second copy over the first.
    await _pressCommandK(tester);
    expect(find.byType(CommandDialog), findsNothing);

    await _unmount(tester);
  });

  // The inline-markdown parsing these rows rely on is InlineMarkdownText's now
  // — see packages/halo_widgets/test/inline_markdown_test.dart.

  testWidgets('a row shows a description\'s markdown as formatting, not as asterisks', (tester) async {
    final services = await _services(tester);
    await _pumpDialog(tester, services);

    await tester.enterText(find.byType(TextField), '20M');
    await _settle(tester);

    // The literal source would read "Set the band to **20m**".
    expect(find.textContaining('**'), findsNothing);
    expect(find.textContaining('20m', findRichText: true), findsWidgets);

    await _unmount(tester);
  });

  testWidgets('a QSO-scoped command reaches the live logging panel', (tester) async {
    // The bug this pins: the engine only ever handled the APP-scoped actions
    // itself, so "20M" from the dialog interpreted fine, returned
    // {setVfo: …}, and then silently did nothing — the dialog has no VFO
    // fields to write to. Asserting that `interpret(execute: true)` ran is
    // NOT enough; it passed all along while the band never changed. What
    // matters is that the action reaches a dispatcher.
    final services = await _services(tester);
    final dispatched = <List<dynamic>>[];
    _openOperation(
      services,
      'op-1',
      dispatch: (actions, {bool skipOnlineLookup = false}) async {
        dispatched.add(actions);
      },
    );

    await _pumpDialog(tester, services);
    await tester.enterText(find.byType(TextField), '20M');
    await _settle(tester);
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await _settle(tester);

    expect(dispatched, hasLength(1));
    expect(dispatched.single.single, {
      'setVfo': {'band': '20m'},
    });

    await _unmount(tester);
  });

  testWidgets('the whole batch goes to the panel in order, not just the QSO-scoped part', (tester) async {
    // A command can return several actions at once (satellites' SAT returns
    // setVfo + updateQso). Splitting the batch — app-scoped handled here,
    // the rest forwarded — would reorder them, so the panel gets all of it.
    final services = await _services(tester);
    final dispatched = <List<dynamic>>[];
    _openOperation(
      services,
      'op-1',
      dispatch: (actions, {bool skipOnlineLookup = false}) async {
        dispatched.add(actions);
      },
    );

    await _pumpDialog(tester, services);
    await tester.enterText(find.byType(TextField), 'DEV');
    await _settle(tester);
    await tester.tap(find.text('DEVMODE'));
    await _settle(tester);

    // DEVMODE is app-scoped, and it STILL goes through the panel's
    // dispatcher — which handles those too — rather than being peeled off.
    expect(dispatched, hasLength(1));
    expect(dispatched.single.single, {
      'updateSettings': {'developerMode': true},
    });

    await _unmount(tester);
  });

  testWidgets('with no logging panel live, app-scoped actions still apply', (tester) async {
    // The Home bar, and the dialog with nothing open: no dispatcher is
    // registered, so the engine's own branches have to carry it.
    final services = await _services(tester);
    expect(services.currentCommandDispatch, isNull);

    await _pumpDialog(tester, services);
    await tester.enterText(find.byType(TextField), 'DEV');
    await _settle(tester);
    await tester.tap(find.text('DEVMODE'));
    await _settle(tester);

    expect(services.settings.developerMode, isTrue);

    await _unmount(tester);
  });

  testWidgets('picking "New operation" actually creates one', (tester) async {
    // The nav rows run their action AFTER the dialog closes itself, so the
    // work happens on an unmounted State — easy to get wrong, and invisible
    // unless something checks the operation really landed.
    final services = await _services(tester);

    await _pumpDialog(tester, services);
    await tester.enterText(find.byType(TextField), 'NEW');
    await _settle(tester);

    await tester.tap(find.text('New operation'));
    await _settle(tester);

    // runAsync: a drift stream never resolves under the fake async a
    // testWidgets body runs in (see halo's drift/fakeAsync note), so reading
    // the operations back has to step outside it.
    final operations = await tester.runAsync(() => services.operations.watchAll().first);
    expect(operations, hasLength(1), reason: 'the palette must create the operation, not just close');

    await _unmount(tester);
  });

  testWidgets('clearing the field mid-lookup drops the spinner, not just the result', (tester) async {
    // The reported state, exactly: text '' with lookupStage 'searching' — an
    // empty box under a spinner that never resolves. The empty-text path
    // cleared the lookup RESULT but not the STAGE, and the in-flight lookup
    // then aborted on its own stale-text guard, so nothing ever replaced it.
    final services = await _services(tester);
    final extensions = services.extensions as _CannedExtensions;
    extensions.gateOnline = Completer<void>();
    await _pumpDialog(tester, services);

    await tester.enterText(find.byType(TextField), 'KI2D');
    await tester.pump();
    expect(find.text('Looking up callsign…'), findsOneWidget);

    // Whatever empties the field — the clear button, a command running, a
    // backspace — must leave no lookup behind.
    await tester.enterText(find.byType(TextField), '');
    await _settle(tester);

    expect(find.text('Looking up callsign…'), findsNothing, reason: 'the spinner must not outlive the text');
    expect(find.byType(CallInfoPanel), findsNothing);

    // And the abandoned lookup landing later must not resurrect it.
    extensions.gateOnline!.complete();
    await _settle(tester);
    expect(find.text('Looking up callsign…'), findsNothing);
    expect(find.byType(CallInfoPanel), findsNothing);

    await _unmount(tester);
  });

  testWidgets('a lookup in flight is replaced by the result, not left spinning', (tester) async {
    // What the user expects: a brief "searching", then the name.
    final services = await _services(tester);
    final extensions = services.extensions as _CannedExtensions;
    extensions.gateOnline = Completer<void>();
    await _pumpDialog(tester, services);

    await tester.enterText(find.byType(TextField), 'W1AW');
    await tester.pump();
    expect(find.text('Looking up callsign…'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 400));
    await _settle(tester);
    extensions.gateOnline!.complete();
    await _settle(tester);

    expect(find.text('Looking up callsign…'), findsNothing, reason: 'the spinner gives way to the result');
    expect(find.textContaining('Hiram Percy Maxim', findRichText: true), findsWidgets);
    expect(tester.widget<TextField>(find.byType(TextField)).controller!.text, 'W1AW');

    await _unmount(tester);
  });

  testWidgets('moving the caret re-runs nothing', (tester) async {
    // TextEditingController notifies for SELECTION changes as well as text
    // changes. The engine treated those as edits, so every caret move — a tap
    // into the field, an arrow key — cancelled the debounces and re-ran the
    // whole interpret-and-lookup cycle for identical text, which is what made
    // the results visibly re-resolve in stages while just moving the cursor.
    final services = await _services(tester);
    final extensions = services.extensions as _CannedExtensions;
    await _pumpDialog(tester, services);

    await tester.enterText(find.byType(TextField), 'W1AW');
    await tester.pump(const Duration(milliseconds: 400));
    await _settle(tester);

    final lookupsAfterTyping = extensions.lookupPasses.length;
    final interpretsAfterTyping = extensions.interpretCalls;
    expect(lookupsAfterTyping, greaterThan(0), reason: 'typing should of course look up');

    // Move the caret without changing a character.
    final controller = tester.widget<TextField>(find.byType(TextField)).controller!;
    controller.selection = const TextSelection.collapsed(offset: 2);
    await tester.pump(const Duration(milliseconds: 400));
    await _settle(tester);
    controller.selection = const TextSelection.collapsed(offset: 0);
    await tester.pump(const Duration(milliseconds: 400));
    await _settle(tester);

    expect(extensions.lookupPasses.length, lookupsAfterTyping, reason: 'a caret move is not an edit');
    expect(extensions.interpretCalls, interpretsAfterTyping, reason: 'nor should it re-interpret');
    // And the result stays put rather than re-resolving through its stages.
    expect(find.byType(CallInfoPanel), findsOneWidget);
    expect(find.text('Looking up callsign…'), findsNothing);
    expect(controller.text, 'W1AW');

    await _unmount(tester);
  });

  testWidgets('popping a nested operation reveals the one underneath, not nothing', (tester) async {
    // The palette can open operation B from inside operation A, so open
    // operations nest. A single context slot cleared on dispose left A
    // silently context-less once B popped — its logging panel still mounted
    // and visible, but operation-scoped commands gone from the palette and no
    // dispatcher for the QSO-scoped ones. Exactly the silent no-op this
    // feature exists to avoid.
    final services = await _services(tester);

    final dispatchedByA = <List<dynamic>>[];
    final a = _openOperation(
      services,
      'op-A',
      dispatch: (actions, {bool skipOnlineLookup = false}) async {
        dispatchedByA.add(actions);
      },
    );
    expect(services.currentOperationContext, {'uuid': 'op-A'});

    final b = _openOperation(services, 'op-B', dispatch: (actions, {bool skipOnlineLookup = false}) async {});
    expect(services.currentOperationContext, {'uuid': 'op-B'}, reason: 'the nested one is front-most');

    services.closeOperationContext(b);
    expect(services.currentOperationContext, {'uuid': 'op-A'}, reason: 'A is revealed again');
    expect(services.currentCommandDispatch, isNotNull, reason: "and A's dispatcher comes back with it");

    // Prove it end to end: a QSO-scoped command from the palette reaches A.
    await _pumpDialog(tester, services);
    await tester.enterText(find.byType(TextField), '20M');
    await _settle(tester);
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await _settle(tester);
    expect(dispatchedByA.single.single, {
      'setVfo': {'band': '20m'},
    });

    services.closeOperationContext(a);
    expect(services.currentOperationContext, isNull);
    expect(services.currentCommandDispatch, isNull);

    await _unmount(tester);
  });

  testWidgets('a disposing panel cannot detach a live one\'s dispatcher', (tester) async {
    // setCommandDispatchFor targets the entry for that uuid, so B detaching
    // on dispose leaves A's alone even though A registered first.
    final services = await _services(tester);
    final a = _openOperation(services, 'op-A', dispatch: (actions, {bool skipOnlineLookup = false}) async {});
    _openOperation(services, 'op-B', dispatch: (actions, {bool skipOnlineLookup = false}) async {});

    services.setCommandDispatchFor('op-B', null);
    expect(services.currentCommandDispatch, isNull, reason: "B is front-most and has detached");

    // A's is untouched underneath.
    expect(a.dispatch, isNotNull);
  });

  testWidgets('HALO-151: a describe with expectsParams is shown, not swallowed', (tester) async {
    // `expectsParams` keeps the typed text out of the results list — it isn't
    // runnable yet — and a query like "SET ltfm" matches no catalog entry
    // either, so the describe is the ONLY thing left to tell the operator
    // anything. Counting just errors and confirmations as "a message" left
    // the card empty of all three: no result, no message, and no empty state
    // (which suppresses itself whenever a message exists). The card blinked
    // and went blank while the operator was still typing.
    final services = await _services(tester);
    await _pumpDialog(tester, services);

    await tester.enterText(find.byType(TextField), 'SET');
    await _settle(tester);
    await tester.enterText(find.byType(TextField), 'SET ltfm');
    await _settle(tester);

    expect(find.text('No setting matches that'), findsOneWidget);
    // And ONLY that: the card's own generic fallback must not double up on it.
    expect(find.textContaining('Nothing matches'), findsNothing);
    await _unmount(tester);
  });

  testWidgets('HALO-151: the generic fallback never flashes while a hook is still answering', (tester) async {
    // `message` is cleared synchronously on each keystroke and refilled when
    // the debounced interpret answers. Painting "Nothing matches …" in that
    // gap is what made two messages appear to fight over the same line as the
    // operator typed.
    final services = await _services(tester);
    await _pumpDialog(tester, services);

    await tester.enterText(find.byType(TextField), 'SET');
    await _settle(tester);

    // The card, mid-gap, with its first describe already on screen.
    await tester.enterText(find.byType(TextField), 'SET l');
    await _settle(tester);
    expect(find.text('No setting matches that'), findsOneWidget);
    final cardBefore = tester.widgetList(find.byType(Material)).length;

    // One frame after the next keystroke — the describe debounce has not
    // fired. Asserting only that "Nothing matches" is absent is NOT enough:
    // it is also absent when the whole card has been torn out of the tree,
    // which is the other way to fail here and looks far worse — the sheet
    // pops out and back in on every character.
    await tester.enterText(find.byType(TextField), 'SET lt');
    await tester.pump();
    expect(find.textContaining('Nothing matches'), findsNothing, reason: 'the hook has not answered yet; the card must wait rather than guess');
    expect(find.text('No setting matches that'), findsOneWidget, reason: 'the previous line holds the card open until this keystroke answers');
    expect(tester.widgetList(find.byType(Material)).length, cardBefore, reason: 'the card must not unmount and remount between keystrokes');

    // Once it lands, the hook's own wording is what shows.
    await _settle(tester);
    expect(find.text('No setting matches that'), findsOneWidget);
    await _unmount(tester);
  });

  testWidgets('HALO-151: an error still shows when the command also matches a catalog row', (tester) async {
    // The trap in "results win over the message": an ERROR is not repeated by
    // any row, so hiding it behind a result list loses it outright. WIPEDB
    // matches its own catalog entry, so the list is NOT empty exactly when the
    // error most needs saying.
    final services = await _services(tester);
    await _pumpDialog(tester, services);

    await tester.enterText(find.byType(TextField), 'WIPEDB');
    await _settle(tester);

    expect(
      find.text('WIPEDB needs an open operation'),
      findsOneWidget,
      reason: 'the catalog row for WIPEDB is on screen, and the error must not hide behind it',
    );
    await _unmount(tester);
  });

  testWidgets('HALO-151: an action\'s failure is not painted over by the optimistic confirm', (tester) async {
    // The engine sets `confirm` BEFORE dispatching, so by the time the action
    // reports it could not write, the palette is holding a message that says
    // it did. Both land on the same response line, the confirm first — so
    // without the action's word replacing it the operator is told "Thing set
    // to On" for a write that failed, which is the failure this whole feature
    // keeps circling back to.
    final services = await _services(tester);
    await _pumpDialog(tester, services);

    await tester.enterText(find.byType(TextField), 'FAILWRITE');
    await _settle(tester);
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await _settle(tester);

    expect(find.text('Thing set to On'), findsNothing, reason: 'the write failed; the confirm must not be the last word');
    expect(find.textContaining('noSuchThing'), findsOneWidget, reason: "the action's own account of the failure is what the operator gets");
    final posted = services.statusBar.items.map((i) => i.text).toList();
    expect(posted, isNot(contains('Thing set to On')));
    await _unmount(tester);
  });

  testWidgets('a command answers in the palette, not the status bar, and then dismisses it', (tester) async {
    // The palette is where the operator is looking when they press Enter, so
    // that is where the command's word goes. The status bar outlives the route
    // and would still be showing it minutes later, over a screen that has
    // nothing to do with the command.
    final services = await _services(tester);
    await _pumpDialog(tester, services);

    await tester.enterText(find.byType(TextField), 'DEVMODE');
    await _settle(tester);
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await _settle(tester);

    expect(find.text('Developer mode activated'), findsOneWidget);
    expect(find.byType(CommandDialog), findsOneWidget, reason: 'it has to stay up to be read');
    expect(services.statusBar.items.map((i) => i.text), isNot(contains('Developer mode activated')));

    // The answer has the card to itself. Executing clears the field, and an
    // empty field is what puts the sample commands on screen — so without the
    // response state they crowd in underneath, and the card reads "here is
    // what happened, and here are two unrelated things to try".
    expect(find.text('SETUP'), findsNothing, reason: 'the empty-field samples must not return under the answer');
    expect(find.text('20M'), findsNothing);

    await tester.pump(const Duration(seconds: 6));
    await _settle(tester);
    expect(find.byType(CommandDialog), findsNothing, reason: 'the response has had its five seconds');
    await _unmount(tester);
  });

  testWidgets("an action's message is the palette's response too", (tester) async {
    // SYNCALL's outcome is known only app-side — sync is off, so nothing is
    // syncing whatever the hook's confirm claims. Route that answer anywhere
    // but this line and the operator reads "Syncing…" on the palette while the
    // truth sits in the status bar behind it.
    final services = await _services(tester);
    expect(services.settings.syncEnabled, isFalse);
    await _pumpDialog(tester, services);

    await tester.enterText(find.byType(TextField), 'SYNCALL');
    await _settle(tester);
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await _settle(tester);

    expect(find.text(_t(tester).commands.enableSyncFirst), findsOneWidget);
    expect(find.text('Syncing…'), findsNothing, reason: 'nothing is syncing; the action knows better');
    expect(services.statusBar.items, isEmpty);
    await _unmount(tester);
  });

  testWidgets('an action dispatched by the logging panel still answers on the palette', (tester) async {
    // With an operation open the palette dispatches almost nothing itself —
    // the whole batch goes to the front-most logging panel, whose handler is
    // what calls runCommandAction. That message comes back through code the
    // palette never touches, so the sink is the only thing joining them;
    // without it, SPOT from ⌘K answers in the status bar behind the palette.
    final services = await _services(tester);
    // Stands in for LoggingControls' own dispatcher, which handles the
    // app-scoped actions by calling runCommandAction with ITS state — code
    // reached only through `currentCommandDispatch`, never through anything
    // the palette passed in.
    _openOperation(
      services,
      'op-1',
      dispatch: (actions, {bool skipOnlineLookup = false}) async {
        for (final _ in actions) {
          await runCommandAction(services, 'syncAll', null);
        }
      },
    );
    await _pumpDialog(tester, services);

    await tester.enterText(find.byType(TextField), 'SYNCALL');
    await _settle(tester);
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await _settle(tester);

    expect(
      find.text(_t(tester).commands.enableSyncFirst),
      findsOneWidget,
      reason: 'the panel dispatched it, and the answer still comes back to where it was typed',
    );
    expect(services.statusBar.items, isEmpty);
    await _unmount(tester);
  });

  testWidgets('an action outliving the response clock still answers, and holds the palette open', (tester) async {
    // The clock must not start on the hook's optimistic confirm: syncAll
    // resyncs a whole account and a settings write waits on an extension
    // validator. A clock started at the confirm expires mid-flight, closing
    // the very surface the action's own word was about to be delivered to —
    // and leaving "Syncing…" as the operator's last word on a sync that never
    // started.
    final services = await _services(tester);
    final gate = Completer<void>();
    _openOperation(
      services,
      'op-1',
      dispatch: (actions, {bool skipOnlineLookup = false}) async {
        await gate.future;
        await runCommandAction(services, 'syncAll', null);
      },
    );
    await _pumpDialog(tester, services);

    await tester.enterText(find.byType(TextField), 'SYNCALL');
    await _settle(tester);
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await _settle(tester);

    // Well past the five seconds, with the action still in flight.
    await tester.pump(const Duration(seconds: 8));
    expect(find.byType(CommandDialog), findsOneWidget, reason: 'nothing has finished; there is nothing to dismiss for');

    gate.complete();
    await _settle(tester);
    expect(find.text(_t(tester).commands.enableSyncFirst), findsOneWidget);
    expect(services.statusBar.items, isEmpty);

    await tester.pump(const Duration(seconds: 6));
    await _settle(tester);
    expect(find.byType(CommandDialog), findsNothing, reason: 'the clock runs from when the command settled');
    await _unmount(tester);
  });

  testWidgets("an action's failure reads as one, not as a confirmation", (tester) async {
    // Same line, same five seconds — but "Sync is not enabled" rendered in the
    // confirmation's accent wash is pixel-identical to "Band set to 20m", and
    // then auto-dismisses. The operator scanning it takes the styling for the
    // answer and reads success. Only the action knows which it is, so it says
    // so and the line renders what it was told.
    final services = await _services(tester);
    _openOperation(
      services,
      'op-1',
      dispatch: (actions, {bool skipOnlineLookup = false}) async {
        await runCommandAction(services, 'syncAll', null);
      },
    );
    await _pumpDialog(tester, services);

    await tester.enterText(find.byType(TextField), 'SYNCALL');
    await _settle(tester);
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await _settle(tester);

    expect(find.text(_t(tester).commands.enableSyncFirst), findsOneWidget);
    expect(find.byIcon(MdiIcons.alertCircle), findsOneWidget, reason: 'the error affordance the message line already has, for the message that needs it');
    await _unmount(tester);
  });

  testWidgets('a failed action outranks a later success in the same batch', (tester) async {
    // The batch's answer is its WORST news, not its last. A spot refused by
    // one source and accepted by the next must not end up reading as success —
    // the operator's next move is to spot the refused one again, and a line
    // saying it worked is what stops them.
    final services = await _services(tester);
    _openOperation(
      services,
      'op-1',
      dispatch: (actions, {bool skipOnlineLookup = false}) async {
        await runCommandAction(services, 'syncAll', null); // fails: sync is off
        await runCommandAction(services, 'devSentry', {'message': 'ok'}); // succeeds
      },
    );
    await _pumpDialog(tester, services);

    await tester.enterText(find.byType(TextField), 'SYNCALL');
    await _settle(tester);
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await _settle(tester);

    expect(find.text(_t(tester).commands.enableSyncFirst), findsOneWidget, reason: 'the failure is still the answer after a later action succeeded');
    expect(find.byIcon(MdiIcons.alertCircle), findsOneWidget);
    expect(services.statusBar.items, isEmpty, reason: 'and the suppressed success does not go contradict it somewhere else');
    await _unmount(tester);
  });

  testWidgets('an early action in a slow batch does not start the clock for the rest', (tester) async {
    // The clock belongs to the BATCH, not to whichever action spoke first.
    // `[updateSetting, syncAll]` is the real shape: the write's validator
    // fails at once and the resync then runs for longer than five seconds —
    // so a clock armed by that first message expires with dispatch still in
    // flight, dismissing the palette and sending everything the rest of the
    // batch has to say to the status bar behind an unrelated screen.
    final services = await _services(tester);
    final gate = Completer<void>();
    _openOperation(
      services,
      'op-1',
      dispatch: (actions, {bool skipOnlineLookup = false}) async {
        await runCommandAction(services, 'syncAll', null);
        await gate.future; // a second, slower action in the same batch
      },
    );
    await _pumpDialog(tester, services);

    await tester.enterText(find.byType(TextField), 'SYNCALL');
    await _settle(tester);
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await _settle(tester);
    expect(find.text(_t(tester).commands.enableSyncFirst), findsOneWidget);

    await tester.pump(const Duration(seconds: 8));
    expect(find.byType(CommandDialog), findsOneWidget, reason: 'the batch has not finished');
    expect(find.text(_t(tester).commands.enableSyncFirst), findsOneWidget, reason: "the first action's word must still be there when the batch ends");

    gate.complete();
    await _settle(tester);
    await tester.pump(const Duration(seconds: 6));
    await _settle(tester);
    expect(find.byType(CommandDialog), findsNothing, reason: 'now the batch is done, the clock runs');
    await _unmount(tester);
  });

  testWidgets('an action answering after its bar is gone falls back to the status bar', (tester) async {
    // Escape mid-flight, or any surface that dies while an action runs. The
    // message has nowhere to be shown, which is a reason to say it elsewhere
    // and never a reason to drop it — an operator who sees no trace of a
    // rejected write is left holding the optimistic confirm.
    final services = await _services(tester);
    final gate = Completer<void>();
    _openOperation(
      services,
      'op-1',
      dispatch: (actions, {bool skipOnlineLookup = false}) async {
        await gate.future;
        await runCommandAction(services, 'syncAll', null);
      },
    );
    await _pumpDialog(tester, services);

    await tester.enterText(find.byType(TextField), 'SYNCALL');
    await _settle(tester);
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await _settle(tester);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await _settle(tester);
    expect(find.byType(CommandDialog), findsNothing);

    gate.complete();
    await _settle(tester);
    expect(services.statusBar.items.map((i) => i.text), contains(_t(tester).commands.enableSyncFirst), reason: 'the palette is gone; the message is not');
    await _unmount(tester);
  });

  testWidgets('typing again keeps the palette open past the response', (tester) async {
    // The five-second dismissal is for a palette nobody is using. Closing one
    // out from under an operator mid-command is the worse failure by far.
    final services = await _services(tester);
    await _pumpDialog(tester, services);

    await tester.enterText(find.byType(TextField), 'DEVMODE');
    await _settle(tester);
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await _settle(tester);
    expect(find.text('Developer mode activated'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'SET');
    await _settle(tester);
    await tester.pump(const Duration(seconds: 6));

    expect(find.byType(CommandDialog), findsOneWidget);
    // …and the results are the new text's again, not still held back for a
    // response that is no longer what the operator is looking at.
    expect(find.text('SETUP'), findsOneWidget);
    await _unmount(tester);
  });

  testWidgets('Enter on a response dismisses the palette without waiting it out', (tester) async {
    // The field is empty behind the answer, so Enter has nothing to run and
    // would otherwise be the one key here that does nothing — leaving the
    // operator to sit through the five seconds or reach for Escape.
    final services = await _services(tester);
    await _pumpDialog(tester, services);

    await tester.enterText(find.byType(TextField), 'DEVMODE');
    await _settle(tester);
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await _settle(tester);
    expect(find.text('Developer mode activated'), findsOneWidget);

    await tester.testTextInput.receiveAction(TextInputAction.done);
    await _settle(tester);

    expect(find.byType(CommandDialog), findsNothing);
    expect(
      (services.extensions as _CannedExtensions).executed.where((c) => c == 'DEVMODE').length,
      1,
      reason: 'dismissing is not re-running the command that just ran',
    );
    await _unmount(tester);
  });

  testWidgets('a confirmation landing over text the operator typed does not close the palette', (tester) async {
    // The one path where a response's five seconds run with text ALREADY in
    // the field: the operator typed on while the command was executing, so
    // the engine puts the confirmation up over their new text (it is the only
    // record that a non-idempotent command ran) and starts the clock there.
    // Expiry must not then dismiss a palette somebody is mid-command in —
    // "the clock was cancelled by their keystrokes" is not true here, because
    // the confirmation was set after them.
    final services = await _services(tester);
    final extensions = services.extensions as _CannedExtensions;
    await _pumpDialog(tester, services);

    await tester.enterText(find.byType(TextField), 'DEVMODE');
    await _settle(tester);
    extensions.executeGate = Completer<void>();
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();

    await tester.enterText(find.byType(TextField), 'SET');
    await _settle(tester);
    extensions.executeGate!.complete();
    await _settle(tester);
    expect(find.text('Developer mode activated'), findsOneWidget, reason: 'the command ran; that has to be said');

    await tester.pump(const Duration(seconds: 6));
    await _settle(tester);

    expect(find.byType(CommandDialog), findsOneWidget);
    expect(find.text('SET'), findsWidgets, reason: "the operator's text is still theirs");
    await _unmount(tester);
  });

  testWidgets('a response is set larger than the describe it replaces', (tester) async {
    // The response is what the operator pressed Enter for and it has the card
    // to itself; a describe is commentary on text still being typed. Same
    // widget renders both, so nothing but a test keeps them from converging.
    final services = await _services(tester);
    await _pumpDialog(tester, services);

    await tester.enterText(find.byType(TextField), 'SET lt');
    await _settle(tester);
    final describeSize = _messageFontSize(tester, 'No setting matches that');

    await tester.enterText(find.byType(TextField), 'DEVMODE');
    await _settle(tester);
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await _settle(tester);

    expect(_messageFontSize(tester, 'Developer mode activated'), greaterThan(describeSize));
    await _unmount(tester);
  });

  testWidgets('a hook answering late updates the row, not just the message line', (tester) async {
    // SOLAR describes itself as "Fetching…" and pushes the real reading
    // through host.updateInterpretation when its fetch lands. The row IS the
    // describe here — with a result on screen the message line is suppressed
    // as a duplicate — so a push that only reached the message line would
    // leave the palette reading "Fetching…" forever.
    final services = await _services(tester);
    final extensions = services.extensions as _CannedExtensions;
    await _pumpDialog(tester, services);

    await tester.enterText(find.byType(TextField), 'SOLAR');
    await _settle(tester);
    expect(find.textContaining('Fetching solar conditions'), findsOneWidget);

    extensions.pushInterpretation('SOLAR', {'describe': 'SFI 168, A 5, K 2'});
    await _settle(tester);

    expect(find.textContaining('SFI 168'), findsOneWidget);
    expect(find.textContaining('Fetching solar conditions'), findsNothing);
    await _unmount(tester);
  });

  testWidgets('a late answer for text the operator has moved on from is ignored', (tester) async {
    // The push names the input it answers, and a hook that took two seconds
    // has no idea what the field says now. Applying it anyway would describe
    // one command with another's answer.
    final services = await _services(tester);
    final extensions = services.extensions as _CannedExtensions;
    await _pumpDialog(tester, services);

    await tester.enterText(find.byType(TextField), 'SOLAR');
    await _settle(tester);
    await tester.enterText(find.byType(TextField), '20M');
    await _settle(tester);

    extensions.pushInterpretation('SOLAR', {'describe': 'SFI 168, A 5, K 2'});
    await _settle(tester);

    expect(find.textContaining('SFI 168'), findsNothing);
    expect(find.textContaining('Change band to'), findsOneWidget);
    await _unmount(tester);
  });

  testWidgets('HALO-151: a describe is not repeated below the row that already shows it', (tester) async {
    // 20M interprets to a runnable command, so it appears as the "run what's
    // typed" row WITH its describe as the subtitle. Repeating that describe on
    // the message line below reads as a second, competing answer.
    final services = await _services(tester);
    await _pumpDialog(tester, services);

    await tester.enterText(find.byType(TextField), '20M');
    await _settle(tester);

    expect(find.textContaining('Change band to'), findsOneWidget, reason: 'shown once, as the typed row\'s subtitle — not twice');
    await _unmount(tester);
  });
}

/// This tree's translations — the app's own strings, so a test asserting on a
/// message the app composed can't drift from it by transcribing it.
Translations _t(WidgetTester tester) => TranslationProvider.of(tester.element(find.byType(MaterialApp))).translations;

/// The size the message line actually renders [text] at. Read off the
/// RichText the markdown body builds: the style is set on a
/// MarkdownStyleSheet, so there is no widget a finder can name it by — and it
/// lands on the SPAN carrying the words, not on the root, which keeps the
/// ambient 14.
double _messageFontSize(WidgetTester tester, String text) {
  final rich = tester
      .widgetList<RichText>(find.byType(RichText))
      .firstWhere((w) => w.text.toPlainText() == text, orElse: () => throw StateError('no message reading "$text"'));
  double? size;
  rich.text.visitChildren((span) {
    if (span is TextSpan && (span.text?.isNotEmpty ?? false)) size ??= span.style?.fontSize;
    return size == null;
  });
  if (size == null) throw StateError('"$text" carries no font size to compare');
  return size!;
}

/// ⌘K on macOS, ⌃K elsewhere — the handler accepts either modifier, so the
/// test drives Control, which is what a Windows/Linux user presses.
Future<void> _pressCommandK(WidgetTester tester) async {
  await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
  await tester.sendKeyEvent(LogicalKeyboardKey.keyK);
  await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}
