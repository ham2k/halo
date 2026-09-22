// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The Personal Info group in the Callsign panel: name, email, club, and the
// ARRL/RAC section. The section row is the interesting one — sections are an
// ARRL/RAC construct, so which label it wears (or whether it appears at all)
// is decided by the DXCC entity of the profile callsign, resolved through the
// extension runtime because Dart has no callsign parser of its own.

import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:halo_i18n/halo_i18n.dart';
import 'package:ham2k_logger/services/settings_service.dart';
import 'package:ham2k_logger/views/settings_view.dart';

import '../support/halo_test_support.dart';

/// Stubs the panel's one seam. `lookupCall` reads the service's private host
/// field, which no mock host can reach, so the hook result is faked one level
/// up — at the method the panel actually calls.
class _StubLookupExtensionService extends ExtensionServiceWithFakeHost {
  /// Answers for successive `lookupCall`s, so a test can make the first one
  /// fail and the second succeed — the runtime-still-booting case.
  final List<String?> entityPrefixes;

  /// Held open to stand in for a runtime still booting: while it is
  /// incomplete, anything awaiting [start] is stuck where the real panel would
  /// be during app launch.
  final Completer<void>? startGate;

  int lookupCalls = 0;

  _StubLookupExtensionService(this.entityPrefixes, {this.startGate}) : super(FakeExtensionHost({}));

  /// The panel awaits this before looking anything up; the real one is
  /// memoized and idempotent.
  @override
  Future<void> start() => startGate?.future ?? Future.value();

  @override
  Future<Map<String, dynamic>?> lookupCall(
    String call, {
    required Map<String, dynamic> qso,
    required Map<String, dynamic> operation,
    bool online = true,
    bool recentContext = false,
  }) async {
    final prefix = entityPrefixes[lookupCalls.clamp(0, entityPrefixes.length - 1)];
    lookupCalls++;
    return prefix == null
        ? null
        : {
            'guess': {'call': call, 'entityPrefix': prefix},
          };
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _StubLookupExtensionService extensions;

  /// Opens the Callsign panel with `call` on the default profile, answering
  /// the offline lookup with `entityPrefix` (null ⇒ the runtime had nothing to
  /// say). `entityPrefixes` answers successive lookups instead, for the
  /// resolve-failed-then-retried case.
  Future<SettingsService> pumpProfilesPanel(
    WidgetTester tester, {
    String call = 'KI2D',
    String? entityPrefix,
    List<String?>? entityPrefixes,
    Completer<void>? startGate,
    Map<String, String> profileFields = const {},
  }) async {
    tester.view.physicalSize = const Size(1000, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    extensions = _StubLookupExtensionService(entityPrefixes ?? [entityPrefix], startGate: startGate);
    final HaLoHarness(:services, :settings) = await makeHaLoServices(
      prefs: {
        'profiles': jsonEncode({
          'default': {'operatorCall': call, ...profileFields},
        }),
      },
      extensions: extensions,
    );

    await tester.pumpWidget(
      TranslationProvider(
        child: MaterialApp(home: SettingsView(services: services)),
      ),
    );
    await tester.pumpAndSettle();
    // Tapped by its description, not its title: once a profile has a callsign
    // the row's title renders as a span (title + mono detail) and find.text
    // can't see it.
    await tester.tap(find.text('Operator callsign and station profile'));
    await tester.pumpAndSettle();
    return settings;
  }

  testWidgets('the group is headed Personal Info and says where the values go', (tester) async {
    await pumpProfilesPanel(tester, entityPrefix: 'K');

    expect(find.text('Personal Info'), findsOneWidget);
    expect(find.text('This might be included in generated logs when relevant for submissions'), findsOneWidget);
    expect(find.text('Name'), findsOneWidget);
    expect(find.text('Email'), findsOneWidget);
    expect(find.text('Club'), findsOneWidget);
  });

  // The dialog's fields, in the order _personalInfoKeys declares them. Indexed
  // rather than found by label: every label also exists on the row behind the
  // dialog, so a text finder matches two widgets.
  const nameField = 0, emailField = 1, clubField = 2, sectionField = 3;

  testWidgets('any row opens one dialog holding the whole group', (tester) async {
    await pumpProfilesPanel(tester, entityPrefix: 'K');

    await tester.tap(find.text('Club'));
    await tester.pumpAndSettle();

    expect(find.byType(TextField), findsNWidgets(4), reason: 'name, email, club, section');
  });

  testWidgets('the dialog opens focused on the row that was tapped', (tester) async {
    await pumpProfilesPanel(tester, entityPrefix: 'K');

    await tester.tap(find.text('Club'));
    await tester.pumpAndSettle();

    final focused = tester.widget<TextField>(find.byType(TextField).at(clubField));
    expect(focused.autofocus, isTrue);
    expect(tester.widget<TextField>(find.byType(TextField).at(nameField)).autofocus, isFalse);
  });

  testWidgets('one dialog writes every field it changed, in one update', (tester) async {
    final settings = await pumpProfilesPanel(tester, entityPrefix: 'K');
    var notifications = 0;
    settings.addListener(() => notifications++);

    await tester.tap(find.text('Name'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).at(nameField), 'Sebastian');
    await tester.enterText(find.byType(TextField).at(emailField), 'sd@ham2k.com');
    await tester.enterText(find.byType(TextField).at(clubField), 'Ham2K Radio Club');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(settings.activeProfile.operatorName, 'Sebastian');
    expect(settings.activeProfile.operatorEmail, 'sd@ham2k.com');
    expect(settings.activeProfile.operatorClub, 'Ham2K Radio Club');
    expect(notifications, 1, reason: 'the group is one write, not one per field');
    // The callsign shares the same JSON blob and must survive the write.
    expect(settings.activeProfile.operatorCall, 'KI2D');
  });

  testWidgets('a US call gets ARRL Section, stored uppercased', (tester) async {
    final settings = await pumpProfilesPanel(tester, entityPrefix: 'K');

    expect(find.text('ARRL Section'), findsOneWidget);
    expect(find.text('RAC Section'), findsNothing);

    await tester.tap(find.text('ARRL Section'));
    await tester.pumpAndSettle();
    // Lowercase on purpose: TextCapitalization is only a keyboard hint, and a
    // desktop keyboard ignores it — the dialog's own uppercasing is the rule.
    await tester.enterText(find.byType(TextField).at(sectionField), 'eny');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(settings.activeProfile.operatorSection, 'ENY');
  });

  // The dialog mirrors the rows: no section row, no section field. (A stored
  // section shows its row, so it is never the omitted one — the merge that
  // protects an omitted field is asserted in settings_service_profiles_test.)
  testWidgets('the dialog omits the section field when the row is not shown', (tester) async {
    await pumpProfilesPanel(tester, call: 'G3ABC', entityPrefix: 'G');

    await tester.tap(find.text('Club'));
    await tester.pumpAndSettle();

    expect(find.byType(TextField), findsNWidgets(3), reason: 'name, email, club — no section');
  });

  // Every US entity that has its own ARRL section — Alaska, Hawaii and the
  // Pacific, Puerto Rico, the Virgin Islands — is a separate DXCC entity from
  // the lower 48, so a bare `== 'K'` test would hide the field from all of
  // them. They share the `K…` prefix; that is what the check keys on.
  for (final prefix in ['K', 'KL', 'KH6', 'KP4', 'KP2', 'KH2']) {
    testWidgets('$prefix is offered an ARRL Section', (tester) async {
      await pumpProfilesPanel(tester, entityPrefix: prefix);
      expect(find.text('ARRL Section'), findsOneWidget);
    });
  }

  testWidgets('a Canadian call gets RAC Section instead', (tester) async {
    await pumpProfilesPanel(tester, call: 'VE3ABC', entityPrefix: 'VE');

    expect(find.text('RAC Section'), findsOneWidget);
    expect(find.text('ARRL Section'), findsNothing);
  });

  testWidgets('a call outside the US and Canada gets no section field', (tester) async {
    await pumpProfilesPanel(tester, call: 'G3ABC', entityPrefix: 'G');

    expect(find.text('ARRL Section'), findsNothing);
    expect(find.text('RAC Section'), findsNothing);
    // The rest of the group is unconditional.
    expect(find.text('Club'), findsOneWidget);
  });

  testWidgets('an unresolved entity hides the section field', (tester) async {
    await pumpProfilesPanel(tester, entityPrefix: null);

    expect(find.text('ARRL Section'), findsNothing);
    expect(find.text('RAC Section'), findsNothing);
    expect(find.text('Section'), findsNothing);
  });

  // Reading a not-yet-booted runtime as "this callsign has no entity" is the
  // first-run path: a US operator opening Settings early would be offered no
  // section at all, with nothing on screen saying why.
  testWidgets('the lookup waits for the extension runtime to start', (tester) async {
    final gate = Completer<void>();
    await pumpProfilesPanel(tester, entityPrefix: 'K', startGate: gate);

    expect(extensions.lookupCalls, 0, reason: 'looked the call up before the runtime was up');
    expect(find.text('ARRL Section'), findsNothing);

    gate.complete();
    await tester.pumpAndSettle();

    expect(find.text('ARRL Section'), findsOneWidget);
  });

  // A failed resolve must not be recorded as this callsign's answer. Stamping
  // it would make the callsign editor — the operator's one way to prod the
  // panel — early-return on the unchanged call and never try again.
  testWidgets('a failed resolve is retried, not remembered', (tester) async {
    await pumpProfilesPanel(tester, entityPrefixes: [null, 'K']);
    expect(find.text('ARRL Section'), findsNothing, reason: 'the first lookup answered nothing');

    await tester.tap(find.text('Callsign'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(find.text('ARRL Section'), findsOneWidget, reason: 'the failed lookup was cached');
  });

  // A stored value the operator cannot see is a value they cannot correct — so
  // a section already on the profile shows even when the entity says
  // otherwise. It wears the bare "Section": naming ARRL for a VE operator
  // whose prefix simply failed to resolve would be telling them something
  // untrue about their own section.
  testWidgets('a stored section stays visible, unattributed, when the entity is unknown', (tester) async {
    await pumpProfilesPanel(tester, call: 'VE3ABC', entityPrefix: null, profileFields: const {'operatorSection': 'ONE'});

    expect(find.text('Section'), findsOneWidget);
    expect(find.text('ARRL Section'), findsNothing);
    expect(find.text('ONE'), findsOneWidget);
  });

  testWidgets('a stored section stays visible for a non-US entity', (tester) async {
    await pumpProfilesPanel(tester, call: 'G3ABC', entityPrefix: 'G', profileFields: const {'operatorSection': 'ENY'});

    expect(find.text('Section'), findsOneWidget);
    expect(find.text('ARRL Section'), findsNothing);
    expect(find.text('ENY'), findsOneWidget);
  });
}
