// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// HALO-258's _LazyQsoList defers a large operation's QSO list behind a
// spinner until the enclosing route's push transition settles, tied to the
// transition's own AnimationStatus. That status listener has no path back if
// the transition's AnimationController is stranded mid-flight — e.g. a
// desktop window losing frames to the OS while occluded or backgrounded
// right after opening a large log — leaving the spinner on screen forever.
//
// TickerMode(enabled: false) reproduces the stall here — it mutes the
// transition's ticker exactly as a dead frame pump would, while Timers keep
// running — so these tests exercise the wall-clock settle deadline that is
// the only way off that stranded state.

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_core/halo_core.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ham2k_logger/i18n/strings.g.dart';
import 'package:ham2k_logger/main.dart';
import 'package:ham2k_logger/services/lookup_queue_service.dart';
import 'package:ham2k_logger/services/settings_service.dart';
import 'package:ham2k_logger/services/status_bar_service.dart';
import 'package:ham2k_logger/views/operation/logging_panel.dart';

/// In the real app, OperationView loads the operation's data before it
/// builds LoggingPanel, so LoggingPanel mounts a frame or more after the
/// push transition itself has started — by which point the transition's
/// AnimationController is genuinely mid-flight. Mounting LoggingPanel on
/// the very same frame as the push (as a bare `push(...builder: (_) =>
/// LoggingPanel(...))` would) hits Navigator before it reparents the
/// route's exposed animation onto that controller, so `_LazyQsoList` would
/// see `kAlwaysCompleteAnimation` and conclude there's nothing to wait for
/// — never a realistic reproduction of the stall. This defers the mount by
/// one frame via `addPostFrameCallback`, the same way real async data
/// loading would.
class _MountNextFrame extends StatefulWidget {
  final WidgetBuilder builder;

  const _MountNextFrame({required this.builder});

  @override
  State<_MountNextFrame> createState() => _MountNextFrameState();
}

class _MountNextFrameState extends State<_MountNextFrame> {
  bool _show = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _show = true);
    });
  }

  @override
  Widget build(BuildContext context) => _show ? widget.builder(context) : const SizedBox.shrink();
}

/// Above _lazyQsoListThreshold (200) in logging_panel.dart.
const _largeQsoCount = 201;

/// Comfortably past a pushed route's default transition (300ms) plus
/// _settleSlack in logging_panel.dart, with margin for the frames this test
/// itself spends getting LoggingPanel mounted (_MountNextFrame, then
/// _LazyQsoList's own post-frame arm) before the deadline even starts
/// counting.
const _settleDeadline = Duration(milliseconds: 800);

List<Qso> _buildQsos(String operationUuid, int count) => [
      for (var i = 0; i < count; i++)
        Qso(
          uuid: 'qso-$i',
          operationUuid: operationUuid,
          data: const {
            'their': {'call': 'W1AW', 'sent': '59'},
            'mode': 'SSB',
          },
        ),
    ];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('a large QSO list interrupted by a stalled ticker still settles', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final settings = SettingsService(await SharedPreferences.getInstance());
    final db = HaLoDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final services = HaLoServices(
      db,
      settings,
      lookupQueue: LookupQueueService(
        lookup: (call, {required qso, required operation, required online, recentContext = false}) async => null,
        qsos: QsosRepository(db),
        operations: OperationsRepository(db),
        statusBar: StatusBarService(settings.prefs),
        runtimeWaitBudget: Duration.zero,
      ),
    );
    final operation = await services.operations.create(stationCall: 'N0CALL', userTitle: 'Test Op');
    // Built directly rather than through services.qsos.add: routing this many
    // QSOs through the repository also crosses ScoringService/decode isolate
    // offload thresholds tuned for this same QSO count, which need real
    // (non-fake) async time to resolve and have nothing to do with what this
    // test is about — the route transition's settle timer.
    final qsos = _buildQsos(operation.uuid, _largeQsoCount);

    Widget buildApp({required bool ticking}) => TranslationProvider(
          child: TickerMode(
            enabled: ticking,
            child: MaterialApp(
              home: Builder(
                builder: (context) => Scaffold(
                  body: Center(
                    child: ElevatedButton(
                      onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => Scaffold(
                          body: _MountNextFrame(
                            builder: (_) => LoggingPanel(
                              operation: operation,
                              services: services,
                              qsos: qsos,
                              loggingControls: const [],
                              onCommandAction: (_, [resultCallback]) async {},
                            ),
                          ),
                        ),
                      )),
                      child: const Text('Open'),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );

    await tester.pumpWidget(buildApp(ticking: true));
    await tester.tap(find.text('Open'));

    // One frame for the push to start and LoggingPanel to mount (see
    // _MountNextFrame), then partway through the still-running transition —
    // the spinner is up and the real list isn't built yet.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    // The window loses focus/is occluded mid-transition and the frame pump
    // dies with it — the AnimationController never reaches a terminal
    // status on its own from here.
    await tester.pumpWidget(buildApp(ticking: false));
    await tester.pump(_settleDeadline);

    expect(
      find.byType(CircularProgressIndicator),
      findsNothing,
      reason: 'the settle deadline should force readiness even though the transition never completed',
    );
  });

  testWidgets('a QSO list crossing the threshold while already open does not get stuck', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final settings = SettingsService(await SharedPreferences.getInstance());
    final db = HaLoDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final services = HaLoServices(
      db,
      settings,
      lookupQueue: LookupQueueService(
        lookup: (call, {required qso, required operation, required online, recentContext = false}) async => null,
        qsos: QsosRepository(db),
        operations: OperationsRepository(db),
        statusBar: StatusBarService(settings.prefs),
        runtimeWaitBudget: Duration.zero,
      ),
    );
    final operation = await services.operations.create(stationCall: 'N0CALL', userTitle: 'Test Op');

    // _LazyQsoList keeps the same widget type (and Element) across the
    // threshold specifically so an operator logging QSOs mid-session doesn't
    // lose their scroll position — see the call site's comment in
    // logging_panel.dart. That means largeEnough can flip false→true via a
    // plain rebuild (no remount), which only fires didUpdateWidget, not
    // didChangeDependencies.
    var qsos = _buildQsos(operation.uuid, 5);

    late StateSetter setPanelState;
    await tester.pumpWidget(
      TranslationProvider(
        child: MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                setPanelState = setState;
                return LoggingPanel(
                  operation: operation,
                  services: services,
                  qsos: qsos,
                  loggingControls: const [],
                  onCommandAction: (_, [resultCallback]) async {},
                );
              },
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(CircularProgressIndicator), findsNothing);

    setPanelState(() => qsos = _buildQsos(operation.uuid, _largeQsoCount));
    await tester.pump();

    expect(
      find.byType(CircularProgressIndicator),
      findsNothing,
      reason: 'largeEnough flipping true via didUpdateWidget must still resolve readiness, not just '
          "didChangeDependencies' one-time check",
    );
  });
}
