// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The render budget an extension panel is documented to keep
// (docs/extensions/hooks.md). Every pane of a dock group stays MOUNTED so
// in-progress input survives a tab switch, so nothing about being built says
// anything about being looked at — and each of these rules is invisible from
// the outside, which is how the whole budget came to be documented in three
// places while implemented in none.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_core/halo_core.dart';
import 'package:halo_widgets/halo_widgets.dart';
import 'package:halo_i18n/halo_i18n.dart';
import 'package:ham2k_logger/services/error_reporting_service.dart';
import 'package:ham2k_logger/services/panel_service.dart';
import 'package:ham2k_logger/views/operation/extension_panel.dart';
import 'package:ham2k_logger/views/operation/panel_content_view.dart';

import '../support/error_reporting_fakes.dart';

void main() {
  /// Never pumpAndSettle here: a panel with no content yet shows a
  /// progress indicator, which animates forever. These pumps are long
  /// enough to carry a render's throttle window (panelRenderThrottle).
  Future<void> settle(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));
    await tester.pump();
  }

  const definition = PanelDefinition(
    id: 'ext:wx:forecast',
    title: 'Forecast',
    source: PanelSource.extension,
    hookKey: 'wx',
    panelKey: 'forecast',
    triggers: ['qsoLogged'],
  );

  Operation operation() => Operation(uuid: 'op-1', data: const {'stationCall': 'N0DEV'});

  /// The same panel with nothing declared up front — what a panel rendering
  /// operator-written text looks like before it has read any.
  const triggerless = PanelDefinition(
    id: 'ext:text:custom',
    title: 'Custom Text',
    source: PanelSource.extension,
    hookKey: 'text',
    panelKey: 'custom',
  );

  Widget harness(
    _RecordingPanels panels, {
    required bool visible,
    int qsoCount = 0,
    PanelDefinition panel = definition,
    void Function(String?)? onTitle,
  }) => TranslationProvider(
        child: MaterialApp(
          home: Scaffold(
            body: DockPaneVisibility(
              visible: visible,
              child: ExtensionPanel(
                panel: panel,
                panels: panels,
                onTitle: onTitle,
                renderContext: PanelRenderContext(operation: operation(), qsoCount: qsoCount),
              ),
            ),
          ),
        ),
      );

  group('a broken panel reports exactly once per streak', () {
    setUp(ErrorReportingService.resetFailureStreaks);
    tearDown(ErrorReportingService.resetFailureStreaks);

    testWidgets('a panel that renders ONCE and fails is still uploaded', (tester) async {
      // The trap: throttling a per-second panel's uploads by waiting for a
      // streak loses the panel that never gets a second attempt. A triggerless
      // panel is the DEFAULT — it renders once and then never again — so a
      // threshold above one means the broken ones nobody can see are exactly
      // the ones that never reach us.
      final backend = FakeErrorReportingBackend();
      await withErrorHooks(() async {
        final panels = _RecordingPanels()..throwsOnRender = true;
        await tester.pumpWidget(harness(panels, visible: true, panel: triggerless));
        await settle(tester);

        expect(panels.renders, hasLength(1), reason: 'triggerless: one attempt, ever');
        expect(backend.exceptions, hasLength(1));
      }, backend: backend);
    });

    testWidgets('a repeated failure AFTER the bridge call still only reports once', (tester) async {
      // The trap: recording success as soon as `render` ANSWERS, while the
      // catch that counts failures covers everything after it too. The streak
      // would then be cleared and re-set on every attempt, so it never means
      // "still broken" — and at a one-second tick the flood this throttling
      // exists to prevent comes straight back, one upload per render.
      final backend = FakeErrorReportingBackend();
      await withErrorHooks(() async {
        final panels = _RecordingPanels();
        void throwing(String? _) => throw StateError('the view threw');
        for (var qsos = 0; qsos < 4; qsos++) {
          await tester.pumpWidget(harness(panels, visible: true, qsoCount: qsos, onTitle: throwing));
          await settle(tester);
        }

        expect(panels.renders.length, greaterThan(2), reason: 'it kept being asked, and kept failing');
        expect(backend.exceptions, hasLength(1), reason: 'one report for one unbroken streak');
      }, backend: backend);
    });
  });

  testWidgets('a panel that starts behind a tab does not render at all', (tester) async {
    final panels = _RecordingPanels();
    await tester.pumpWidget(harness(panels, visible: false));
    await settle(tester);

    // A group of four extension panels would otherwise fire four bridge
    // calls the moment it is built, three of them for panes nobody can see.
    expect(panels.renders, isEmpty);
  });

  testWidgets('it renders as soon as it is looked at', (tester) async {
    final panels = _RecordingPanels();
    await tester.pumpWidget(harness(panels, visible: false));
    await settle(tester);

    await tester.pumpWidget(harness(panels, visible: true));
    await settle(tester);
    expect(panels.renders, ['initial']);
  });

  testWidgets('a trigger that fires behind a tab is remembered, not rendered', (tester) async {
    final panels = _RecordingPanels();
    await tester.pumpWidget(harness(panels, visible: true));
    await settle(tester);
    expect(panels.renders, ['initial']);

    // Hidden, and its trigger fires.
    await tester.pumpWidget(harness(panels, visible: false, qsoCount: 1));
    await settle(tester);
    expect(panels.renders, ['initial'], reason: 'nobody is looking at it');

    await tester.pumpWidget(harness(panels, visible: true, qsoCount: 1));
    await settle(tester);
    // What it missed, once — not once per trigger that fired while hidden.
    expect(panels.renders, ['initial', 'visible']);
  });

  testWidgets('coming back to a tab where nothing happened costs nothing', (tester) async {
    final panels = _RecordingPanels();
    await tester.pumpWidget(harness(panels, visible: true));
    await settle(tester);
    await tester.pumpWidget(harness(panels, visible: false));
    await settle(tester);
    await tester.pumpWidget(harness(panels, visible: true));
    await settle(tester);

    // A descriptor with no trigger for what changed renders once and stays
    // put — tab switching is not itself a reason to cross the bridge.
    expect(panels.renders, ['initial']);
  });

  // The half of the budget a panel can only decide once it has read its own
  // config: an operator's `{{ op.qsoCount }}` has to start updating without
  // the descriptor — and therefore every other placement of the same panel —
  // paying for it.
  testWidgets('a trigger the render itself declared wakes that placement', (tester) async {
    final panels = _RecordingPanels(declares: ['qsoLogged']);
    await tester.pumpWidget(harness(panels, visible: true, panel: triggerless));
    await settle(tester);
    expect(panels.renders, ['initial']);

    await tester.pumpWidget(harness(panels, visible: true, qsoCount: 1, panel: triggerless));
    await settle(tester);
    expect(panels.renders, ['initial', 'qsoLogged']);
  });

  testWidgets('a placement that declared nothing is left alone by one that did', (tester) async {
    final panels = _RecordingPanels(declares: ['qsoLogged']);
    await tester.pumpWidget(harness(panels, visible: true, panel: triggerless));
    await settle(tester);

    // A second pane of the same panel, rendering static text.
    panels.declares = const [];
    const other = PanelDefinition(
      id: 'ext:text:custom#2',
      title: 'Custom Text',
      source: PanelSource.extension,
      hookKey: 'text',
      panelKey: 'custom',
    );
    await tester.pumpWidget(harness(panels, visible: true, panel: other));
    await settle(tester);
    panels.renders.clear();

    await tester.pumpWidget(harness(panels, visible: true, qsoCount: 1, panel: other));
    await settle(tester);
    expect(panels.renders, isEmpty, reason: "the other pane's template is what asked for qsoLogged");
  });

  // A triggerless pane has nothing that would ever ask again: no ticker, an
  // empty set for didUpdateWidget to intersect, and a come-back-to-the-tab
  // path gated on a trigger having fired. A first render that fails — a
  // runtime still starting, a bridge timeout — would otherwise leave the
  // pane broken for the whole session, curable only by editing its config.
  testWidgets('a failed panel offers a retry, and the retry renders', (tester) async {
    final panels = _RecordingPanels()..failNextRender = true;
    await tester.pumpWidget(harness(panels, visible: true, panel: triggerless));
    await settle(tester);
    expect(panels.renders, ['initial']);
    expect(find.text('Try again'), findsOneWidget);

    await tester.tap(find.text('Try again'));
    await settle(tester);

    expect(panels.renders, ['initial', 'retry']);
    expect(find.text('Try again'), findsNothing, reason: 'the retry succeeded, so the pane is content again');
  });

  testWidgets('a tick a render declared starts the ticker', (tester) async {
    final panels = _RecordingPanels(declares: ['tick:5']);
    await tester.pumpWidget(harness(panels, visible: true, panel: triggerless));
    await settle(tester);
    // NOT `expect(renders, ['initial'])` here: settle pumps two seconds, and
    // whether a 5s tick lands inside that window depends on where the real
    // clock sat when the test ran — the boundary is real, the pump is fake.
    expect(panels.renders.first, 'initial');

    await tester.pump(const Duration(seconds: 6));
    await tester.pump();
    // That the ticker STARTED, not how many times it fired in the window.
    // Ticks are aimed at wall-clock boundaries, so the first one lands
    // somewhere in (0, period] depending on where the real clock sat when the
    // test ran — while the timer itself runs on the test's fake clock. A
    // count is therefore phase-dependent: flaky, and able to pass for the
    // wrong reason. The boundary arithmetic has its own test in
    // wall_clock_test.dart, where it is pure and deterministic.
    expect(panels.renders.first, 'initial');
    expect(panels.renders.length, greaterThan(1), reason: 'the declaration started a ticker');
    expect(panels.renders.skip(1), everyElement('tick'));
  });

  test('the throttle is a gap after a render, not a period from its start', () {
    // The defect this replaced: measured from the START of a render, a panel
    // costing more than the window was allowed to begin the next one the
    // instant it returned — a 100% duty cycle on a single-threaded runtime,
    // starving every other extension hook, with nothing on screen to show it.
    //
    // A widget test cannot see this. The throttle reads the REAL clock (a
    // Timer fires on real time), which `tester.pump(duration)` does not
    // advance, so the buggy and fixed versions defer identically under fake
    // time. The arithmetic is what can be checked.
    final ended = DateTime.utc(2026, 1, 1, 12);

    expect(panelRenderDelay(lastEndedAt: null, now: ended), Duration.zero,
        reason: 'nothing has rendered yet');
    expect(panelRenderDelay(lastEndedAt: ended, now: ended), panelRenderThrottle,
        reason: 'a render that just finished owes the whole gap');
    expect(
      panelRenderDelay(lastEndedAt: ended, now: ended.add(const Duration(milliseconds: 400))),
      const Duration(milliseconds: 350),
    );
    expect(panelRenderDelay(lastEndedAt: ended, now: ended.add(panelRenderThrottle)), Duration.zero);
    expect(
      panelRenderDelay(lastEndedAt: ended, now: ended.add(const Duration(seconds: 5))),
      Duration.zero,
    );
    // A clock that went backwards — an NTP correction mid-session — must not
    // read as "the gap elapsed"; that is the runaway again by another route.
    expect(
      panelRenderDelay(lastEndedAt: ended, now: ended.subtract(const Duration(seconds: 30))),
      panelRenderThrottle,
    );
  });

  testWidgets('an identical answer does not rebuild the pane', (tester) async {
    // A panel on a tick re-renders the same document most of the time — a
    // band plan, a reference table. `setState` on an answer equal to the one
    // already shown rebuilds the subtree once per tick for nothing, and
    // PanelContent has had a working `==` all along that nothing called.
    //
    // Driven by markConfigChanged, not by re-pumping the harness: pumping a
    // new tree rebuilds the subtree from the root whatever the panel does,
    // which would make the probe below always pass for the wrong reason.
    final panels = _RecordingPanels();
    await tester.pumpWidget(harness(panels, visible: true));
    await settle(tester);
    final before = tester.widget<PanelContentView>(find.byType(PanelContentView));

    panels.markConfigChanged(definition.id);
    await settle(tester);
    expect(panels.renders, ['initial', 'config'], reason: 'it did render again');
    expect(
      identical(tester.widget<PanelContentView>(find.byType(PanelContentView)), before),
      isTrue,
      reason: 'same content, so the subtree was never rebuilt',
    );

    // And a real change still gets through — the check must not be a mute.
    panels.content = 'changed';
    panels.markConfigChanged(definition.id);
    await settle(tester);
    expect(
      identical(tester.widget<PanelContentView>(find.byType(PanelContentView)), before),
      isFalse,
    );
  });

  testWidgets('a pane revealed for the first time does not owe a catch-up', (tester) async {
    // A pane that mounts behind a tab has no content, so its first reveal
    // renders `initial` — which answers whatever it missed. Leaving the flag
    // standing buys a second, pointless bridge render the NEXT time the
    // operator switches away and back. At a one-second tick floor a hidden
    // pane sets that flag almost immediately, so this went from rare to
    // near-certain.
    final panels = _RecordingPanels();
    await tester.pumpWidget(harness(panels, visible: false));
    await settle(tester);
    expect(panels.renders, isEmpty);

    // Something it cares about happens while it is still hidden and unrendered.
    await tester.pumpWidget(harness(panels, visible: false, qsoCount: 1));
    await settle(tester);
    expect(panels.renders, isEmpty, reason: 'nobody has looked at it yet');

    await tester.pumpWidget(harness(panels, visible: true, qsoCount: 1));
    await settle(tester);
    expect(panels.renders, ['initial']);

    // Away and back with nothing happening in between.
    await tester.pumpWidget(harness(panels, visible: false, qsoCount: 1));
    await settle(tester);
    await tester.pumpWidget(harness(panels, visible: true, qsoCount: 1));
    await settle(tester);
    expect(panels.renders, ['initial'], reason: 'the first render already answered it');
  });

  testWidgets('an event arriving mid-render is owed, not armed for zero', (tester) async {
    // The wiring, not the rule: the switch in _requestRender is what turns
    // `coalesce` into `_pending` instead of a timer. It matters because the
    // gap is measured from the LAST render's end, which mid-render has
    // usually already elapsed — so a deferred timer would be armed for zero
    // and start a render with no idle gap at all, defeating the change.
    final panels = _RecordingPanels()..renderCost = const Duration(milliseconds: 500);
    await tester.pumpWidget(harness(panels, visible: true));
    await tester.pump();
    expect(panels.renders, ['initial'], reason: 'in flight, not finished');

    // Arrives while that render is still running.
    await tester.pumpWidget(harness(panels, visible: true, qsoCount: 1));
    await tester.pump();
    expect(panels.renders, ['initial'], reason: 'owed, not started');

    await settle(tester);
    await settle(tester);
    expect(panels.renders, ['initial', 'coalesced'],
        reason: 'the render in flight re-requested when it finished');
  });

  test('a tick is dropped whenever a render is already coming', () {
    const gap = Duration(milliseconds: 400);
    const free = Duration.zero;
    PanelRenderRequest ask(String reason, {bool rendering = false, bool scheduled = false, Duration wait = free}) =>
        panelRenderRequest(reason: reason, rendering: rendering, scheduled: scheduled, wait: wait);

    expect(ask('tick'), PanelRenderRequest.now);
    expect(ask('qsoLogged'), PanelRenderRequest.now);

    // A tick is a SAMPLE, and the next one is already aimed at the next
    // boundary. Whatever render is coming reads fresh context anyway, so
    // keeping this one only makes it land late — and RELABEL the pending
    // render, telling the panel it is rendering for a tick when a QSO was
    // logged.
    expect(ask('tick', rendering: true), PanelRenderRequest.drop);
    expect(ask('tick', scheduled: true, wait: gap), PanelRenderRequest.drop,
        reason: 'a render is already scheduled; this tick would only relabel it');
    // Nothing coming: a tick inside the gap is still worth waiting out, since
    // the gap is at most panelRenderThrottle and skipping costs a whole period.
    expect(ask('tick', wait: gap), PanelRenderRequest.defer);

    // An EVENT has nothing coming to bring it back, so it is never dropped.
    // Mid-render it is OWED rather than timed: the gap is measured from the
    // last render's END, which mid-render has usually already elapsed, so a
    // timer would be armed for zero and defeat the gap entirely.
    expect(ask('qsoLogged', rendering: true), PanelRenderRequest.coalesce);
    expect(ask('qsoLogged', rendering: true, scheduled: true, wait: gap), PanelRenderRequest.coalesce);
    expect(ask('config', wait: gap), PanelRenderRequest.defer);
    expect(ask('visible', wait: gap, scheduled: true), PanelRenderRequest.defer);
  });

  test('a panel ticks at the shortest period it declared, floored', () {
    // "the declared period is what runs" is not observable in a widget test:
    // the boundary a tick aims at comes from the real clock while the timer
    // runs on the test's fake one, so any count over a pumped window is
    // phase-dependent.
    expect(panelTickPeriod(const []), isNull);
    expect(panelTickPeriod(const ['qsoLogged', 'spots']), isNull, reason: 'no tick asked for');
    expect(panelTickPeriod(const ['tick:15']), const Duration(seconds: 15));
    // The SHORTEST wins — a descriptor's tick and one a render declared are
    // both in force, and the panel owes the faster of them.
    expect(panelTickPeriod(const ['tick:30', 'tick:5', 'tick:60']), const Duration(seconds: 5));
    expect(panelTickPeriod(const ['tick:1']), const Duration(seconds: 1));
    expect(panelTickPeriod(const ['tick:nope', 'tick:20']), const Duration(seconds: 20));
    // Defence for a caller that skipped the parser, not a live path:
    // `isKnownPanelTrigger` requires seconds > 0, so `tick:0` is dropped as
    // unrecognized long before it could be floored here.
    expect(isKnownPanelTrigger('tick:0'), isFalse);
    expect(panelTickPeriod(const ['tick:0']), const Duration(seconds: minPanelTickSeconds));
  });

  test('the tick delay aims at a boundary, and the floor widens the period', () {
    // The trap this exists to catch: flooring the DELAY instead of the period.
    // The wait to a one-second boundary is under a second by definition, so a
    // `wait < 1000 ? 1000 : wait` clamp replaces every aligned wait with a
    // flat one — the panel then ticks a second after whenever it mounted,
    // forever, and never shares a frame with the WallClock widgets it is
    // supposed to line up with. Every period >= 2s hides this by converging
    // on its first tick, which is why the case below is a 1s one at phase.
    expect(panelTickDelayMillis(periodMs: 1000, nowMillis: 12_250, speed: 1), 750,
        reason: 'lands ON the next second, not 1000ms after an arbitrary phase');
    expect(panelTickDelayMillis(periodMs: 5000, nowMillis: 12_250, speed: 1), 2750);
    // Already on a boundary: a full period away, never zero — a zero-duration
    // timer here would spin the chain.
    expect(panelTickDelayMillis(periodMs: 1000, nowMillis: 12_000, speed: 1), 1000);
    // Under travel the floor is on REAL time while the period is on the app
    // clock, so it has to scale with the speed: at 10x a 1s panel would
    // otherwise be asked to cross the bridge ten times a second. Consecutive
    // waits are what the floor bounds — the partial one from here to the
    // first boundary is whatever the phase makes it, so step a full period
    // past the boundary and measure the wait after that.
    int nextAfterBoundary(int periodMs, double speed) {
      final first = panelTickDelayMillis(periodMs: periodMs, nowMillis: 12_250, speed: speed);
      final atBoundary = 12_250 + (first * speed).round();
      return panelTickDelayMillis(periodMs: periodMs, nowMillis: atBoundary, speed: speed);
    }

    expect(nextAfterBoundary(1000, 10), greaterThanOrEqualTo(minPanelTickMillis));
    expect(nextAfterBoundary(1000, 1), greaterThanOrEqualTo(minPanelTickMillis));
    expect(nextAfterBoundary(60_000, 10), greaterThanOrEqualTo(minPanelTickMillis));
  });

  test('only a genuinely hidden app is treated as unwatched', () {
    // Dock visibility alone is not enough once a panel can tick every second:
    // one on the front tab of a minimized window is visible to the dock and
    // still crossing the bridge for nobody.
    //
    // The predicate, not the wiring. A widget test cannot cover the wiring —
    // the test binding restores `resumed` on the next pump, so a lifecycle
    // state set in a test never survives to the moment a trigger arrives.
    expect(appIsVisibleIn(AppLifecycleState.resumed), isTrue);
    // The one that matters: on desktop `inactive` is a window that merely
    // lost focus while still fully on screen. Treating it as hidden freezes
    // every panel the operator is looking at.
    expect(appIsVisibleIn(AppLifecycleState.inactive), isTrue);
    expect(appIsVisibleIn(AppLifecycleState.hidden), isFalse);
    expect(appIsVisibleIn(AppLifecycleState.paused), isFalse);
    expect(appIsVisibleIn(AppLifecycleState.detached), isFalse);
  });
}

/// Records what it was asked to render, and why. [declares] is what its
/// renders claim to need, as a templated panel's would.
class _RecordingPanels extends PanelService {
  _RecordingPanels({this.declares = const []}) : super(_NullSource());

  List<String> declares;
  final renders = <String>[];

  /// How long a render takes to answer. The default is instant; a value past
  /// [panelRenderThrottle] is what makes the difference between a throttle
  /// measured from the start of a render and one measured from its end.
  Duration renderCost = Duration.zero;

  /// Same content every time unless this changes — a panel on a tick usually
  /// re-renders the document it already showed.
  String content = 'ok';

  /// Fails one render, then answers normally — a runtime still starting.
  bool failNextRender = false;

  /// Throws on every render, the way a broken hook does.
  bool throwsOnRender = false;

  @override
  Future<Map<String, dynamic>?> render(PanelDefinition panel, Map<String, dynamic> args) async {
    renders.add(args['reason'] as String);
    if (renderCost > Duration.zero) await Future<void>.delayed(renderCost);
    if (throwsOnRender) throw StateError('hook is broken');
    if (failNextRender) {
      failNextRender = false;
      return null;
    }
    return {'kind': 'markdown', 'content': content, if (declares.isNotEmpty) 'triggers': declares};
  }

  @override
  Future<Map<String, dynamic>> configFor(PanelDefinition panel) async => const {};
}

class _NullSource implements PanelExtensionSource {
  @override
  final runtimeGeneration = ValueNotifier(0);

  @override
  Future<List<Map<String, dynamic>>?> getExtensionPanels() async => const [];

  @override
  Future<Map<String, dynamic>?> renderPanel({
    required String hookKey,
    required String panelKey,
    required Map<String, dynamic> args,
  }) async => null;

  @override
  Future<Map<String, dynamic>> readPanelConfig({
    required String panelKey,
    required List<Map<String, dynamic>> fields,
  }) async => const {};

  @override
  Future<void> forgetPanelConfig({
    required String panelKey,
    required List<Map<String, dynamic>> fields,
  }) async {}
}
