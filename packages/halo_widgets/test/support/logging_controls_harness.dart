// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The shared fixture behind the logging panel's widget suite, which is split
// across `logging_controls*_test.dart` by the panel's own seams. Everything
// each of those files reads — the database, the operation under test, the
// two radio stores, and `host()` itself — lives here as top-level state, so
// a test body says `host(radio: ...)` exactly as it would beside the fixture
// rather than reaching through a receiver.
//
// That state is only safe because `flutter test` gives every test FILE its
// own isolate: the files never share these, and within a file
// [installLoggingHarness]'s `setUp` builds them fresh for every test. Call it
// first in `main()`; without it the `late` fields below are uninitialized and
// the first test dies naming one.
//
// Widget tests drive the keyboard flows; database verification goes through
// tester.runAsync() because drift's futures/timers otherwise sit unresolved
// in testWidgets' FakeAsync zone. Interleaved pumps let widget-initiated
// writes (which start inside the fake zone) run to completion.

import 'dart:async';
import 'dart:math' as math;

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_core/halo_core.dart';
import 'package:halo_i18n/halo_i18n.dart';
import 'package:halo_widgets/halo_widgets.dart';

// WCAG 2.1 relative luminance / contrast ratio, so the focus-indicator test
// pins an actual accessibility threshold rather than "some color".
double _linear(double c) => c <= 0.03928 ? c / 12.92 : math.pow((c + 0.055) / 1.055, 2.4).toDouble();
double _luminance(Color c) => 0.2126 * _linear(c.r) + 0.7152 * _linear(c.g) + 0.0722 * _linear(c.b);
double contrastRatio(Color a, Color b) {
  final la = _luminance(a), lb = _luminance(b);
  final hi = math.max(la, lb), lo = math.min(la, lb);
  return (hi + 0.05) / (lo + 0.05);
}

/// Runs the rest of the test in Spanish, and puts English back afterwards.
/// `runAsync`: the Spanish translations are a deferred library, and its load
/// is a real future that fake async would never complete — a bare
/// `await LocaleSettings.setLocale` under `testWidgets` hangs to the timeout.
Future<void> useSpanish(WidgetTester tester) async {
  await tester.runAsync(() => LocaleSettings.setLocale(AppLocale.es));
  addTearDown(() => LocaleSettings.setLocaleSync(AppLocale.en));
}

late HaLoDatabase db;
late OperationsRepository operations;
late QsosRepository qsos;
late Operation operation;
late FakeVfoStore fakeRadio;
late KeyboardAccessoryController keyboardAccessory;
late FakeVfoStore tunedRadio;

/// The two groups almost every construction below passes as-is: the log
/// under test, and a radio already tuned to a band. Built on each call
/// rather than once in `setUp`, because a test may replace `operation` (or
/// the store) in its own body before building the panel, and a group held
/// from `setUp` would hand it the operation it replaced.
LogHooks baseLog() => LogHooks(operation: operation, qsosRepository: qsos);
RadioHookup baseRadio() => RadioHookup(radioService: tunedRadio);

bool _installed = false;

/// Builds the fixtures above fresh for each test, and closes the database
/// after it. Every `main()` in the split suite calls this first.
///
/// Exactly once per file. A second call registers a second `setUp` that
/// overwrites [db] with a fresh one, and both `tearDown`s then close that
/// same second database — the first is left open, per test, and every
/// assertion still passes.
void installLoggingHarness() {
  assert(() {
    if (_installed) throw StateError('installLoggingHarness() called twice in one test file');
    _installed = true;
    return true;
  }());
  setUp(() async {
    db = HaLoDatabase(NativeDatabase.memory());
    operations = OperationsRepository(db);
    qsos = QsosRepository(db);
    operation = await operations.create(stationCall: 'KI2D');
    fakeRadio = FakeVfoStore();
    keyboardAccessory = KeyboardAccessoryController();
    // A mode as well as a frequency: a station on the air has both, and an
    // unset mode is one of the things that pops the Radio control open on
    // mount (see `RadioControlModel.vfoIsUnset`), which would steal focus in every test here.
    tunedRadio = FakeVfoStore()..setVfo('vfoA', freq: 14285, mode: 'SSB');
  });

  tearDown(() async {
    // The app clock is process-global and the panel stamps every contact
    // through it, so a test that travels and does not come back stamps the
    // contacts of every test after it — days out, with nothing raised. Reset
    // unconditionally rather than in the group that happens to travel today:
    // moving one of those tests to another file is what arms this.
    AppClock.instance.reset();
    await db.close();
  });
}

/// The same operation, but running the given activities.
///
/// Primary fields are gated on this: a control only reaches the entry row if
/// the operation carries a ref of the type it writes to. Tests that exercise
/// a contest exchange have to say which contest is being run, exactly as the
/// operator has to add the activity before the field appears.
Operation running(List<String> refTypes) => Operation(
  uuid: operation.uuid,
  data: {
    ...operation.data,
    'refs': [
      for (final type in refTypes) {'type': type},
    ],
  },
);

/// The panel under test, wired with the same nine groups the app wires it
/// with — a test names the group it varies and nothing else. [log] and
/// [radio] default to the fixtures every test shares; a radio passed
/// without its own [RadioHookup.radioUpdates] gets the store as its
/// listenable, the way the app passes one object as both.
///
/// Three production states cannot be reached through here, because this
/// always fills them in: a null [RadioHookup.radioService] (the Radio
/// control local to the panel), a null [RadioHookup.radioUpdates] (the
/// control reads the VFO only when it seeds), and a null
/// [LoggingPreferences.keyboardAccessory]. A test that means to pin one of
/// those builds its own [LoggingControls] instead — asking for it here
/// yields the opposite, and every assertion about it passes for the wrong
/// reason.
Widget host({
  LogHooks? log,
  LoggingSession? session,
  RadioHookup? radio,
  LookupHooks? lookups,
  ActivityHooks? activities,
  CommandHooks? commands,
  ControlStripSettings? strip,
  SpottingHooks? spotting,
  LoggingPreferences? prefs,
  Widget? trailing,
  ThemeData? appTheme,
}) {
  // A radio already tuned to a band, because that is the ordinary state of
  // a station on the air — and because logging refuses a contact carrying
  // neither band nor frequency, so a test that logs anything needs one. A
  // [radio] that names no store of its own still gets this one, so a test
  // varying the rig's status does not silently lose its VFO; tests about
  // the untuned, fresh-install state pass `fakeRadio` (or their own store).
  final resolvedRadio = radio ?? baseRadio();
  final store = resolvedRadio.radioService ?? tunedRadio;
  final controls = LoggingControls(
    log: log ?? baseLog(),
    session: session ?? const LoggingSession(),
    // The app passes the same object twice — RadioService is both the store
    // and the Listenable. See RadioHookup.radioUpdates.
    radio: resolvedRadio.copyWith(radioService: store, radioUpdates: resolvedRadio.radioUpdates ?? (store is Listenable ? store as Listenable : null)),
    // The dupe notice is a pill in the info area keyed `duplicate`; map it
    // to DUPE so the dupe-detection tests can assert on the text. The
    // caller's own label wins, and has to be checked for here: a copyWith
    // keeps what it has only for an argument that is null, and this one
    // never is.
    lookups: (lookups ?? const LookupHooks()).copyWith(scoreNoticeLabel: lookups?.scoreNoticeLabel ?? (key) => key == 'duplicate' ? 'DUPE' : key),
    activities: activities ?? const ActivityHooks(),
    commands: commands ?? const CommandHooks(),
    strip: strip ?? const ControlStripSettings(),
    spotting: spotting ?? const SpottingHooks(),
    prefs: (prefs ?? const LoggingPreferences()).copyWith(keyboardAccessory: keyboardAccessory),
  );
  return MaterialApp(
    theme: appTheme,
    home: Scaffold(
      // Matches the operation view: the Scaffold doesn't resize for the
      // keyboard (LoggingControls reserves its own bottom spacer), and the
      // panel is bottom-anchored with the rest of the height above it (the
      // QsoList in the app). `trailing` stands in for that QSO list — a
      // focusable sibling OUTSIDE the controls, so a Tab-trap test can prove
      // focus never lands on it.
      resizeToAvoidBottomInset: false,
      body: Column(
        children: [
          const Expanded(child: SizedBox.shrink()),
          controls,
          ?trailing,
          // The panel no longer draws the numbers row — it publishes it, and
          // the app's StatusBarOverlay draws it below the status footer and
          // directly on the keyboard. This stands in for that, so the tests
          // still exercise the row end to end (publish → render → tap)
          // rather than asserting on the spec and calling it covered.
          ValueListenableBuilder<KeyboardAccessorySpec?>(
            valueListenable: keyboardAccessory,
            builder: (context, spec, _) => spec == null
                ? const SizedBox.shrink()
                : NumberKeys(
                    onKey: spec.onKey,
                    extraKey: spec.extraKey,
                    vibrate: spec.vibrate,
                    backgroundColor: Color(spec.backgroundColor),
                    foregroundColor: Color(spec.foregroundColor),
                  ),
          ),
        ],
      ),
    ),
  );
}

// The on-screen keyboard, as the widget tree actually sees it: raise the
// real FlutterView's bottom inset (Scaffold hides it from MediaQuery, so
// that's the only faithful signal — the very thing `_keyboardIsUp` reads).
// Insets are physical px, so scale by the pixel ratio pinned here;
// `logicalHeight` stands in either a full keyboard (default) or the thin
// ~50px shortcuts bar iOS shows when a HARDWARE keyboard is attached.
void raiseKeyboard(WidgetTester tester, {double logicalHeight = 300}) {
  tester.view.devicePixelRatio = 3.0;
  tester.view.viewInsets = FakeViewPadding(bottom: logicalHeight * 3.0);
  addTearDown(tester.view.resetViewInsets);
  addTearDown(tester.view.resetDevicePixelRatio);
}

/// Stand-in for the real `radio-commands` extension (see
/// extensions/core/radio-commands), so this widget test can verify how
/// LoggingControls applies a command result without booting a JS runtime.
/// The extension itself is covered by an integration test in
/// halo_extension_host against the real built bundle.
Future<Map<String, dynamic>?> fakeInterpretCommand(String input, [Map<String, dynamic>? operation, Map<String, dynamic>? qso, bool execute = false]) async {
  final band = RegExp(r'^(2200|630|160|80|60|40|30|20|17|15|12|10|6|4|2)M?$', caseSensitive: false).firstMatch(input);
  if (band != null) {
    final b = '${band.group(1)!.toLowerCase()}m';
    return {
      'describe': 'Change band to **$b**?',
      'confirm': 'Band set to **$b**',
      'commands': [
        {
          'setVfo': {'band': b},
        },
      ],
    };
  }

  final mode = modes.firstWhere((m) => m.toLowerCase() == input.toLowerCase(), orElse: () => '');
  if (mode.isNotEmpty) {
    return {
      'describe': 'Change mode to **$mode**?',
      'confirm': 'Mode set to **$mode**',
      'commands': [
        {
          'setVfo': {'mode': mode},
        },
      ],
    };
  }

  if (input.length >= 3) {
    final freq = parseFreq(input);
    if (freq != null && bandForFrequency(freq) != null) {
      return {
        'describe': 'Change frequency to **${(freq / 1000).toStringAsFixed(3)} MHz**?',
        'confirm': 'Frequency set to **${(freq / 1000).toStringAsFixed(3)} MHz**',
        'commands': [
          {
            'setVfo': {'freq': freq},
          },
        ],
      };
    }
  }
  return null;
}

/// Starts a contact — the first character of a call is what takes a serial
/// number (docs/design/contests.md §5.8.1); an idle panel shows none.
Future<void> startContact(WidgetTester tester, [String call = 'W']) async {
  await tester.enterText(find.widgetWithText(TextField, 'Their call'), call);
  await tester.pump();
}

/// Holds [modifier] down around one press of [key].
Future<void> sendChord(WidgetTester tester, LogicalKeyboardKey modifier, LogicalKeyboardKey key) async {
  await tester.sendKeyDownEvent(modifier);
  await tester.sendKeyEvent(key);
  await tester.sendKeyUpEvent(modifier);
  await tester.pump();
}

/// Pumps until a serial field has picked up its number, and FAILS if it
/// never does. The claim is a drift query kicked off outside the frame, so
/// it needs interleaved pumps to resolve — same reasoning as [waitForQsos].
///
/// Loud for that helper's reason too: the tests that then assert a number is
/// RELEASED are satisfied by a release that never had a claim behind it, so
/// giving up quietly here leaves them green against a panel that stopped
/// claiming numbers altogether.
Future<void> pumpUntilSerial(WidgetTester tester, String label) async {
  for (var i = 0; i < 20; i++) {
    await tester.pump(const Duration(milliseconds: 10));
    final text = tester.widget<TextField>(find.widgetWithText(TextField, label)).controller?.text ?? '';
    if (text.isNotEmpty) return;
  }
  fail('"$label" never showed a number');
}

/// Pumps until the operation's QSO list reaches [count], and FAILS if it
/// never does.
///
/// The budget is 20 interleaved pumps, because a write starts inside the
/// fake-async zone and needs them to run to completion. Falling out of that
/// loop is the one thing this must not do quietly: returning the short list
/// hands the caller a number it will assert against, so a contact that is
/// merely late reads exactly like a contact that was refused. Use
/// [qsosAfterWaiting] where nothing arriving, or nothing FURTHER arriving,
/// is the point.
///
/// What it waits on is the row COUNT, which makes it a sync point for an
/// insert and none at all for an update: a test that seeded N records and
/// edits one of them is already at N, so this returns on the first poll and
/// proves only that the seeding happened. Where the claim is about what an
/// edit WROTE, poll the record's content instead — there is an example at
/// the top of the "composing draft survives a detour" group.
///
/// Always watches [operation], so a [repository] passed here has to be one
/// over that same operation — a repository for another finds nothing, for
/// the whole budget, every time.
Future<List<Qso>> waitForQsos(WidgetTester tester, int count, {QsosRepository? repository}) async {
  final logged = await _pumpForQsos(tester, count, repository: repository);
  if (logged.length < count) fail('waited for $count QSO(s), saw ${logged.length}');
  return logged;
}

/// What the operation holds after the same budget of pumps, asserting
/// nothing — for the claims [waitForQsos] cannot make, which are the ones
/// with an upper bound: nothing was logged at all, or one contact was and a
/// second never followed. The caller states the claim and says why.
///
/// [watchFor] only lets the wait stop early, once that many have landed, so
/// pass one MORE than the test expects whenever the point is that no further
/// contact arrives — otherwise the wait returns the moment the expected one
/// does and never gives the unwanted one a chance to show up.
Future<List<Qso>> qsosAfterWaiting(WidgetTester tester, {int watchFor = 1, QsosRepository? repository}) =>
    _pumpForQsos(tester, watchFor, repository: repository);

Future<List<Qso>> _pumpForQsos(WidgetTester tester, int count, {QsosRepository? repository}) async {
  final repo = repository ?? qsos;
  final uuid = operation.uuid;
  var logged = <Qso>[];
  for (var i = 0; i < 20; i++) {
    await tester.pump(const Duration(milliseconds: 10));
    logged = (await tester.runAsync(() => repo.watchForOperation(uuid).first))!;
    if (logged.length >= count) break;
  }
  return logged;
}

/// Opens a secondary control by tapping its chip (found by icon, since a
/// control's chip label is a dynamic summary — e.g. Radio's starts as
/// "Band??? • SSB" — not a fixed string). Taps the ChoiceChip ancestor
/// rather than the icon itself: the icon glyph's tight bounding box can
/// sit a pixel or two outside the chip's actual hit-test area.
Future<void> openControl(WidgetTester tester, IconData icon) async {
  await tester.tap(find.ancestor(of: find.byIcon(icon), matching: find.byType(ChoiceChip)));
  await tester.pump();
  // The panel slides into/out of place over SecondaryControlRow's fixed
  // 200ms animation — a bounded pump (rather than pumpAndSettle, which
  // would also chase the Time control's Timer.periodic clock tick and
  // never settle) gets it fully in view (or fully gone, when this
  // closes a panel) before callers interact with its fields. Slightly
  // over 200ms, plus a trailing zero-duration pump, so AnimatedSwitcher's
  // own post-animation cleanup (dropping the outgoing child) has
  // actually run rather than landing exactly on the animation's edge.
  await tester.pump(const Duration(milliseconds: 250));
  await tester.pump();
}

/// Settles SecondaryControlRow's 200ms expand/collapse slide — same shape
/// as [openControl]'s trailing pumps, for callers that trigger the
/// animation via a key event instead of a tap.
Future<void> settleControl(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 250));
  await tester.pump();
}

/// A repository whose [add] starts throwing after [addsBeforeFailure]
/// successful inserts — the disk-full / closed-database stand-in for the
/// write-failure tests.
class FailingQsosRepository extends QsosRepository {
  FailingQsosRepository(super.db, {this.addsBeforeFailure = 0});
  final int addsBeforeFailure;
  int _adds = 0;

  @override
  Future<Qso> add(String operationUuid, Map<String, dynamic> qsoData, {List<SequenceDescriptor> serialSequences = const []}) {
    if (_adds >= addsBeforeFailure) throw StateError('disk full');
    _adds++;
    return super.add(operationUuid, qsoData, serialSequences: serialSequences);
  }
}

/// In-memory stand-in for the app's `RadioService` (which lives outside
/// this package, in the Flutter app rather than halo_widgets) — just
/// enough of `VfoStore` to verify LoggingControls seeds from and writes
/// back to it, without a real SharedPreferences-backed store.
class FakeVfoStore extends ChangeNotifier implements VfoStore {
  Vfo _vfoA = const Vfo();

  @override
  Vfo get vfoA => _vfoA;

  @override
  void setVfo(String key, {double? freq, String? band, String? mode, num? power, bool clearFreq = false, bool clearPower = false}) {
    if (key != 'vfoA') return;
    final newPower = clearPower ? null : (power ?? _vfoA.power);
    if (freq != null) {
      _vfoA = Vfo(freq: freq, band: bandForFrequency(freq), mode: mode ?? _vfoA.mode, power: newPower);
    } else if (band != null || clearFreq) {
      _vfoA = Vfo(freq: null, band: band ?? _vfoA.band, mode: mode ?? _vfoA.mode, power: newPower);
    } else {
      _vfoA = Vfo(freq: _vfoA.freq, band: _vfoA.band, mode: mode ?? _vfoA.mode, power: newPower);
    }
    // The real RadioService is a ChangeNotifier; without this the panel's
    // live-follow listener never fires and its tests pass vacuously.
    notifyListeners();
  }
}

/// Stands in for SpotsPanel: something else in the tree that listens to the
/// VFO and rebuilds when it changes.
class VfoWatcher extends StatefulWidget {
  final Listenable store;

  const VfoWatcher({super.key, required this.store});

  @override
  State<VfoWatcher> createState() => _VfoWatcherState();
}

class _VfoWatcherState extends State<VfoWatcher> {
  int _changes = 0;

  @override
  void initState() {
    super.initState();
    widget.store.addListener(_onChanged);
  }

  @override
  void dispose() {
    widget.store.removeListener(_onChanged);
    super.dispose();
  }

  void _onChanged() => setState(() => _changes++);

  @override
  Widget build(BuildContext context) => Text('vfo changes: $_changes');
}

/// A number source that answers from the sequence and records what the panel
/// asked of it — the seam the peer claims plug into in the app.
class RecordingSerialSource implements SerialNumberSource {
  RecordingSerialSource(this.sequences, {this.conflicted = const {}, this.gate});

  final SequencesRepository sequences;
  final Set<int> conflicted;

  /// When set, a claim does not resolve until this completes — the peers'
  /// acks still in flight.
  final Completer<void>? gate;
  int claims = 0;
  int releases = 0;
  Map<SequenceRequest, int> committed = const {};

  @override
  Future<int> claim(String operationUuid, SequenceRequest request) async {
    claims++;
    if (gate case final gate?) await gate.future;
    return sequences.peek(operationUuid, request);
  }

  @override
  void release(String operationUuid, {Map<SequenceRequest, int> committed = const {}, Set<String>? labels}) {
    releases++;
    if (committed.isNotEmpty) this.committed = committed;
  }

  @override
  bool isConflicted(String operationUuid, SequenceRequest request, int number) => conflicted.contains(number);
}
