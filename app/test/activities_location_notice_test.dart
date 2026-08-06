// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// With no location, the Suggestions section has nothing nearby to offer — and
// said so in the same muted grey as "No suggestions", which reads as "there is
// nothing near you" rather than "this app does not know where you are". The
// operator stops looking instead of typing a grid.
//
// So the location states get a red headline and a way out, and the trap these
// tests guard is that the way out has to WORK: the hint names the pin that
// opens the location editor, and a hint pointing at something that doesn't
// respond to a tap is worse than no hint. The plain states must stay plain —
// a red headline on "No suggestions" would cry wolf on every empty search.

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_core/halo_core.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ham2k_logger/i18n/strings.g.dart';
import 'package:ham2k_logger/main.dart';
import 'package:ham2k_logger/services/extension_service.dart';
import 'package:ham2k_logger/services/location_service.dart';
import 'package:ham2k_logger/services/settings_service.dart';
import 'package:ham2k_logger/views/operation/activities_view.dart';
import 'package:ham2k_logger/views/operation/operation_location_screen.dart';

import 'operation_view_layout_test.dart' show MockExtensionHost, ExtensionServiceWithMockHost;

/// The real service reaches these states only by being denied an OS permission
/// or losing a GPS fix, neither of which a widget test can arrange.
class _FixedLocation extends LocationService {
  _FixedLocation(this._status);

  final LocationStatus _status;

  @override
  LocationStatus get status => _status;

  // The view starts the stream and subscribes on mount. Left to the real
  // implementation these reach geolocator, throw MissingPluginException, and
  // are swallowed by start()'s own broad catch — so the tests would pass on
  // the strength of a caught exception, and start failing the day that catch
  // is narrowed.
  @override
  Future<void> start() async {}

  @override
  void stop() {}

  @override
  void addListener(VoidCallback listener) {}

  @override
  void removeListener(VoidCallback listener) {}
}

class _NoActivityExtensions extends ExtensionServiceWithMockHost {
  _NoActivityExtensions({this.offersNearby = true, this.allSourcesFail = false}) : super(const MockExtensionHost({}));

  /// Stands in for every activity hook being broken — the empty list that
  /// means "nobody could answer" rather than "nobody had anything".
  final bool allSourcesFail;

  /// Whether this stands in for extensions that have something nearby to
  /// offer. False is the "searched and genuinely found nothing" case, which is
  /// the only way to see the plain empty state while a grid is set.
  final bool offersNearby;

  @override
  Future<List<Map<String, dynamic>>> operationControls(
    Map<String, dynamic> operationData, {
    Map<String, dynamic>? qso,
  }) async =>
      const [];

  /// How many times the view has asked — the only way to see that a search
  /// re-ran when its answer happens to be the same either way.
  int searches = 0;

  /// Nearby suggestions exist only once the operation has a grid the search
  /// can actually place — which is what the real hooks get, since
  /// `suggestActivities` passes them `gridToLocation`'s answer and nothing
  /// else. Keying on "non-empty" instead would hand results back for a
  /// half-typed `FN` that the real ones cannot answer at all.
  @override
  Future<ActivitySuggestionResult> suggestActivities(
    Map<String, dynamic> operationData, {
    String? searchTerm,
    GridLocation? fallbackLocation,
    String? activityKey,
    String? preferredKey,
    String? preferredSearchTerm,
  }) async {
    searches++;
    if (allSourcesFail) return (suggestions: const <Map<String, dynamic>>[], allSourcesFailed: true);
    if (!offersNearby || gridToLocation(operationData['grid'] as String?) == null) {
      return (suggestions: const <Map<String, dynamic>>[], allSourcesFailed: false);
    }
    return (
      suggestions: const [
        {'type': 'pota', 'ref': 'US-0001', 'label': 'POTA US-0001', 'shortLabel': 'US-0001', 'name': 'Some Park'},
      ],
      allSourcesFailed: false,
    );
  }
}

Future<(HaLoServices, Operation)> _harness(
  LocationStatus status, {
  String? grid,
  bool offersNearby = true,
  bool allSourcesFail = false,
}) async {
  SharedPreferences.setMockInitialValues({});
  final settings = SettingsService(await SharedPreferences.getInstance());
  final db = HaLoDatabase(NativeDatabase.memory());
  final extensions = _NoActivityExtensions(offersNearby: offersNearby, allSourcesFail: allSourcesFail)
    ..settings = settings;
  extensions.debugSetAvailableExtensions(const []);
  return (
    HaLoServices(db, settings, extensions: extensions, location: _FixedLocation(status)),
    Operation(uuid: 'op-1', data: {'refs': const [], if (grid != null) 'grid': grid}),
  );
}

Future<void> _pump(
  WidgetTester tester,
  HaLoServices services,
  Operation operation, {
  Key? sheetKey,
}) async {
  await tester.pumpWidget(TranslationProvider(
    child: MaterialApp(
      home: Scaffold(body: OperationSheet(key: sheetKey, services: services, operation: operation)),
    ),
  ));
  await tester.pumpAndSettle();
}

int _searchCount(HaLoServices services) => (services.extensions as _NoActivityExtensions).searches;

/// The notice's headline paragraph.
Finder _headline(String headline) => find.byWidgetPredicate(
      (w) => w is Text && (w.textSpan?.toPlainText() ?? '').startsWith(headline),
    );

/// The whole notice — the tappable block the headline sits in, so an assertion
/// scopes to it rather than to anything on the sheet that happens to match.
Finder _notice(String headline) => find.ancestor(of: _headline(headline), matching: find.byType(InkWell));

/// The color the notice's first line is painted, found by the text it carries.
Color? _headlineColor(WidgetTester tester, String headline) {
  final rich = tester.widget<Text>(_headline(headline));
  final first = (rich.textSpan! as TextSpan).children!.first as TextSpan;
  return first.style?.color;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('the injectable location still wires the real service into extensions', () async {
    // The override parameter shares its name with the field, and inside the
    // constructor body the parameter wins — so `extensions.location = location`
    // hands every extension null in production while every test that assigns
    // `extensions.location` itself stays green. `getLocation` then answers null
    // for good, silently, to every extension that asked for a fix.
    SharedPreferences.setMockInitialValues({});
    final settings = SettingsService(await SharedPreferences.getInstance());
    final services = HaLoServices(HaLoDatabase(NativeDatabase.memory()), settings);
    expect(identical(services.extensions.location, services.location), isTrue);
  });

  testWidgets('an unavailable location says so in red, with the pin and a way out', (tester) async {
    final (services, operation) = await _harness(LocationStatus.unavailable);
    await _pump(tester, services, operation);

    final t = AppLocale.en.buildSync().activitiesView;
    expect(find.textContaining(t.locationUnavailableTitle, findRichText: true), findsOneWidget);
    expect(find.textContaining(t.noNearbyReason, findRichText: true), findsOneWidget);

    // The headline alone is the error color. The advice below it is not an
    // error — searching by name is a perfectly good thing to go do.
    final theme = Theme.of(tester.element(find.byType(OperationSheet)));
    expect(_headlineColor(tester, t.locationUnavailableTitle), theme.colorScheme.error);

    // The whole hint sentence survives rendering. Splitting it on the icon
    // placeholder and keeping only the outer segments is a real and silent way
    // to lose the middle of a translation, and every other assertion here
    // passes while it happens.
    final fragments = t.locationManualHint(icon: '\u{FFFC}').split('\u{FFFC}');
    for (final fragment in fragments) {
      expect(find.textContaining(fragment, findRichText: true), findsOneWidget, reason: 'lost "$fragment"');
    }

    // The pin the hint tells the operator to tap is really drawn, inside the
    // notice's own text rather than anywhere on the sheet.
    expect(
      find.descendant(of: _notice(t.locationUnavailableTitle), matching: find.byType(Icon)),
      findsOneWidget,
    );
  });

  testWidgets('denied permission is named apart from a location that simply is not there', (tester) async {
    final (services, operation) = await _harness(LocationStatus.permissionDenied);
    await _pump(tester, services, operation);

    final t = AppLocale.en.buildSync().activitiesView;
    // Only one of these two is the operator's to grant, so one message for
    // both would send half of them to the wrong fix.
    expect(find.textContaining(t.locationDeniedTitle, findRichText: true), findsOneWidget);
    expect(find.textContaining(t.locationUnavailableTitle, findRichText: true), findsNothing);
  });

  testWidgets('tapping the notice opens the location editor', (tester) async {
    final (services, operation) = await _harness(LocationStatus.unavailable);
    await _pump(tester, services, operation);

    final t = AppLocale.en.buildSync().activitiesView;
    await tester.tap(find.textContaining(t.locationUnavailableTitle, findRichText: true));
    await tester.pumpAndSettle();

    // Telling someone to tap for manual entry and then not accepting the tap
    // is the failure this exists to catch.
    expect(find.byType(OperationLocationScreen), findsOneWidget);
  });

  testWidgets('an operation that already has a grid keeps the plain empty state', (tester) async {
    // A grid means nearby suggestions were possible and simply found nothing;
    // shouting about location here would be a lie.
    final (services, operation) = await _harness(LocationStatus.unavailable, grid: 'FN31pr', offersNearby: false);
    await _pump(tester, services, operation);

    final t = AppLocale.en.buildSync().activitiesView;
    expect(find.textContaining(t.noSuggestions, findRichText: true), findsOneWidget);
    expect(find.textContaining(t.locationUnavailableTitle, findRichText: true), findsNothing);
  });

  testWidgets('a grid typed into the editor produces results, not "No suggestions"', (tester) async {
    // The whole point of the notice: it sends the operator to type a location.
    // Nearby suggestions come from the operation's grid, and nothing else
    // re-runs the search once it changes — the device-GPS listener that would
    // is exactly what cannot fire in the states that show this notice. Without
    // a re-search the operator lands on a muted "No suggestions" over a grid
    // never searched, which is the very reading this notice exists to prevent.
    final sheetKey = GlobalKey<OperationSheetState>();
    final (services, operation) = await _harness(LocationStatus.unavailable);
    await _pump(tester, services, operation, sheetKey: sheetKey);

    final t = AppLocale.en.buildSync().activitiesView;
    expect(find.text('Some Park'), findsNothing, reason: 'nothing is nearby until there is a grid');

    // What the location editor's own result does when it comes back.
    sheetKey.currentState!.updateOperation(
      Operation(uuid: operation.uuid, data: {...operation.data, 'grid': 'FN31pr'}),
    );
    await tester.pumpAndSettle();

    expect(find.text('Some Park'), findsOneWidget);
    expect(find.textContaining(t.noSuggestions, findRichText: true), findsNothing);
  });

  testWidgets('a state filled in on its own re-runs the search too', (tester) async {
    // The editor returns grid, state and county together, so filling in only
    // State under "More Details" is ordinary — and the whole operation map
    // reaches the hooks, where an administratively-defined program answers off
    // exactly that field.
    final sheetKey = GlobalKey<OperationSheetState>();
    final (services, operation) = await _harness(LocationStatus.unavailable);
    await _pump(tester, services, operation, sheetKey: sheetKey);

    sheetKey.currentState!.updateOperation(
      Operation(uuid: operation.uuid, data: {...operation.data, 'state': 'NY'}),
    );
    await tester.pumpAndSettle();

    // The fake answers on the grid, so the observable proof is that a search
    // ran at all: the notice is gone only if the suggestions were refetched.
    expect(_searchCount(services), greaterThan(1));
  });

  testWidgets('every source failing says so, rather than "No suggestions"', (tester) async {
    // Identical empty lists, opposite meanings: "nobody had a match" sends the
    // operator on to something else, "nobody could answer" should send them
    // back in a moment. Reporting the first for the second loses the reference
    // that was there all along.
    final (services, operation) = await _harness(LocationStatus.available, allSourcesFail: true);
    await _pump(tester, services, operation);

    final t = AppLocale.en.buildSync().activitiesView;
    expect(find.textContaining(t.searchUnavailableTitle, findRichText: true), findsOneWidget);
    expect(find.textContaining(t.noSuggestions, findRichText: true), findsNothing);
  });

  testWidgets('a blocked permission offers Settings, a denied one offers to ask again', (tester) async {
    // The two OS states take different fixes, and a button offering the wrong
    // one wastes the only tap the operator is likely to give it.
    final t = AppLocale.en.buildSync().activitiesView;

    final (denied, op1) = await _harness(LocationStatus.permissionDenied);
    await _pump(tester, denied, op1);
    expect(find.text(t.locationGrantAction), findsOneWidget);
    expect(find.text(t.locationSettingsAction), findsNothing);

    final (blocked, op2) = await _harness(LocationStatus.permissionBlocked);
    await _pump(tester, blocked, op2);
    expect(find.text(t.locationSettingsAction), findsOneWidget);
    expect(find.text(t.locationGrantAction), findsNothing);
    expect(find.textContaining(t.locationBlockedTitle, findRichText: true), findsOneWidget);
  });

  testWidgets('no permission button when the OS is not what is in the way', (tester) async {
    // `unavailable` is a device with no fix to give; asking for permission
    // again would be a button that cannot possibly help.
    final (services, operation) = await _harness(LocationStatus.unavailable);
    await _pump(tester, services, operation);

    final t = AppLocale.en.buildSync().activitiesView;
    expect(find.text(t.locationGrantAction), findsNothing);
    expect(find.text(t.locationSettingsAction), findsNothing);
  });

  testWidgets('a grid the search cannot use is no grid at all', (tester) async {
    // The location editor saves whatever was typed, unvalidated, so "FN" is
    // exactly what taking the notice's advice can produce. Counting it as a
    // location silences the notice and answers "No suggestions" over a grid
    // the hooks were never given — the operator believes they fixed it.
    final (services, operation) = await _harness(LocationStatus.unavailable, grid: 'FN');
    await _pump(tester, services, operation);

    final t = AppLocale.en.buildSync().activitiesView;
    expect(find.textContaining(t.locationUnavailableTitle, findRichText: true), findsOneWidget);
  });

  testWidgets('an empty-string grid is no grid at all', (tester) async {
    // Sync and import can both deliver one. Read as a location it silences the
    // notice while the pill next to it shows the red no-location pin — the two
    // controls contradicting each other about the same operation.
    final (services, operation) = await _harness(LocationStatus.unavailable, grid: '');
    await _pump(tester, services, operation);

    final t = AppLocale.en.buildSync().activitiesView;
    expect(find.textContaining(t.locationUnavailableTitle, findRichText: true), findsOneWidget);
  });
}
