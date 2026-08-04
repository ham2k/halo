import 'dart:async';
import 'dart:io' as io;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:halo_core/halo_core.dart';
import 'package:halo_widgets/halo_widgets.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

import '../config/dev_bridge.dart';
import '../config/dev_flags.dart';
import '../config/web_preview_label.dart';
import '../main.dart';
import '../services/settings_service.dart';
import '../tools/operation_title.dart';
import 'command_engine.dart';
import 'header_profile_label.dart';
import 'operation_dialogs.dart';
import 'operation_view.dart';
import 'settings_view.dart';
import 'ham2k_logo.dart';
import 'version_label.dart';
import '../i18n/strings.g.dart';

/// A free-form developer label shown in the home header after the edition
/// badge — marks which dev build/session is running. Set with
/// `--dart-define=DEV_LABEL=…` or (off web) a `DEV_LABEL` environment variable;
/// that explicit label is dev-only (stripped in release). Web preview
/// deployments are themselves release builds, so they instead fall back to the
/// preview name derived from the URL. Empty
/// otherwise. Resolved once (a lazy top-level final).
final String _devLabel = _resolveDevLabel();

String _resolveDevLabel() {
  final explicit = debugEnvFlag(const String.fromEnvironment('DEV_LABEL'), 'DEV_LABEL');
  if (explicit.isNotEmpty) return explicit;
  return webPreviewLabel();
}

/// HaLo home-screen style row: bold "CALL title" line with count pill,
/// subtitle line with refs/description and right-aligned date.
class _OperationRow extends StatelessWidget {
  final HaLoServices services;
  final Operation operation;

  const _OperationRow({required this.services, required this.operation});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final when = operation.startAtMax;
    final dateLabel = when == null ? '' : formatShortDate(when);
    // The ref-derived subtitle only exists once
    // OperationTitleService has run at least once for this operation — until
    // then, fall back to the raw ref names so the row isn't blank.
    final suggestedSubtitle = displaySubtitleFor(operation);
    final subtitle = suggestedSubtitle.isNotEmpty
        ? suggestedSubtitle
        : operation.refs.map((r) => r['name']).whereType<String>().join(' • ');

    return Material(
      color: theme.colorScheme.surface,
      child: InkWell(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => OperationView(services: services, operationUuid: operation.uuid),
          ),
        ),
        onLongPress: () => confirmDeleteOperation(context, services, operation),
        mouseCursor: SystemMouseCursors.click,
        child: Padding(
          padding: PaneSafeArea.symmetricOf(context, horizontal: 16, vertical: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: operation.stationCall,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                              fontFamily: 'RobotoMono',
                            ),
                          ),
                          TextSpan(
                            text: ' ${displayTitleFor(context, operation)}',
                            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                          ),
                        ],
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(formatNumber(operation.qsoCount), style: theme.textTheme.labelLarge),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                    ),
                  ),
                  Text(dateLabel, style: theme.textTheme.bodyMedium),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

}

class OperationListPanel extends StatelessWidget {
  final HaLoServices services;
  final List<Operation> operations;
  // Whether the operations stream hasn't emitted its first snapshot yet —
  // distinct from an emitted empty list. While true, `operations` is a
  // placeholder empty list, not a confirmed one, so the "no operations yet"
  // text must not show yet (it would flash for a frame on every startup,
  // even for accounts with operations).
  final bool loading;

  const OperationListPanel({super.key, required this.services, required this.operations, required this.loading});

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.surfaceContainerHighest;
    if (operations.isEmpty) {
      if (loading) return ColoredBox(color: color);
      return Container(color: color, child: Center(child: Text(context.t.home.emptyList)));
    }
    return Container(
      // Shows through below the last row when there aren't enough
      // operations to fill the screen.
      color: color,
      child: ListView.separated(
        itemCount: operations.length,
        separatorBuilder: (context, index) => const Divider(),
        itemBuilder: (context, index) => _OperationRow(services: services, operation: operations[index]),
      ),
    );
  }
}

class HomeView extends StatefulWidget {
  /// Home's arrangement is fixed (docs/design/layouts.md): its split opts
  /// into the "surfaces" divider style below.
  static const layoutPolicy = ViewLayoutPolicy.fixed;

  final HaLoServices services;

  const HomeView({super.key, required this.services});

  @override
  State<HomeView> createState() => _HomeViewState();
}

/// How many new operations a user has to open before the FAB's onboarding
/// nudge (see [_NewOperationNudge]) stops.
const _newOperationNudgeThreshold = 2;

/// How long the screen sits still before the nudge fires. Someone who is
/// already doing something doesn't need to be pointed at the button, and
/// someone still taking the screen in hasn't reached the point of needing it
/// either — so the nudge waits, and any touch in the meantime cancels it.
const _newOperationNudgeDelay = Duration(seconds: 5);

/// How long the FAB's extend/collapse takes, and how long after the last
/// change we wait before forcing it to its resting state (see
/// [_HomeViewState._setFabExtended]). The slack is deliberate: the transition
/// starts on the frame *after* the flip, not at the instant of it, so a
/// healthy one must never be cut short by its own deadline.
const _fabTransitionDuration = Duration(milliseconds: 300);
const _fabSettleSlack = Duration(milliseconds: 100);

class _HomeViewState extends State<HomeView> with WidgetsBindingObserver {
  bool _isFabExtended = true;

  /// Bumped once a transition's deadline passes, and used as the animated
  /// FAB subtree's key — see [_setFabExtended].
  int _fabSettleEpoch = 0;
  Timer? _fabSettleTimer;

  /// Identifies the FAB's button proper — everything a finger can be resting
  /// on — so it is MOVED rather than rebuilt whenever the wrapper above it is
  /// replaced: by [_fabSettleEpoch] here, and by the nudge settling in
  /// [_NewOperationNudgeState.build]. Both replace an ancestor mid-gesture,
  /// and re-inflating the subtree would dispose the InkWell's recognizers
  /// under the user's finger — the tap would simply never fire, and the FAB
  /// would look dead. Reparenting keeps the element, its State, its render
  /// object and its focus, so a press in flight survives.
  ///
  /// Per-instance, not a file-level final: two HomeViews alive at once (a
  /// route transition between them) would otherwise collide on one key.
  late final GlobalKey _fabButtonKey = GlobalKey();

  /// Whether the FAB's onboarding nudge has waited out
  /// [_newOperationNudgeDelay] without the user touching anything. Only the
  /// wait is cancellable: once the burst is under way it runs itself out,
  /// since yanking the rotation mid-swing would snap the button upright,
  /// which reads worse than letting it finish.
  bool _nudgeArmed = false;
  Timer? _nudgeTimer;

  /// Memoized: build now depends on MediaQuery.sizeOf (ShirtSize.of), so it
  /// reruns on every window-resize frame — watchAll() returns a NEW drift
  /// stream per call, and an inline `stream:` would make the StreamBuilder
  /// resubscribe (and re-run the SELECT) each of those frames.
  late final Stream<List<Operation>> _operationsStream = widget.services.operations.watchAll();

  /// Blocks a second tap while _newOperation is in flight — a fast
  /// double-tap could otherwise create two operations before the pushed
  /// route starts absorbing pointer events.
  bool _creatingOperation = false;

  /// No call/title dialog: the station call comes from the active profile's
  /// callsign, and the operation screen opens straight into the Activities
  /// pane (title and everything else are editable there and in the
  /// operation's own settings).
  Future<void> _newOperation(BuildContext context) async {
    if (_creatingOperation) return;
    _creatingOperation = true;
    try {
      final operation = await widget.services.operations.create(
        stationCall: widget.services.settings.activeProfile.operatorCall,
      );
      widget.services.track('operation_created');
      // Counts opened new operations, not overlay displays —
      // what the FAB's nudge (_NewOperationNudge) is gated on.
      unawaited(widget.services.settings.recordOnboardingShown(OnboardingFlows.newOperation));
      if (context.mounted) {
        // The guard stays up until the pushed route pops back to this
        // screen — the home screen remains hit-testable during the push
        // transition, so releasing right after push would reopen the
        // double-tap window.
        unawaited(
          Navigator.of(context)
              .push(
                MaterialPageRoute(
                  builder: (_) =>
                      OperationView(services: widget.services, operationUuid: operation.uuid, openActivities: true),
                ),
              )
              .whenComplete(() => _creatingOperation = false),
        );
      } else {
        _creatingOperation = false;
      }
    } catch (_) {
      _creatingOperation = false;
      rethrow;
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _nudgeTimer = Timer(_newOperationNudgeDelay, () {
      if (mounted) setState(() => _nudgeArmed = true);
    });
  }

  @override
  void dispose() {
    _fabSettleTimer?.cancel();
    _nudgeTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Flips the FAB between extended and collapsed, and puts a hard deadline on
  /// the transition that follows.
  ///
  /// Implicit animations can be left half-applied. `RenderAnimatedSize` only
  /// resumes a controller that stopped mid-flight — a muted ticker, a
  /// detached render object, a browser tab that stopped delivering frames —
  /// when layout runs again, and a plain rebuild doesn't necessarily mark it
  /// for layout, so a controller stranded at 0.5 keeps reporting a half width
  /// indefinitely. That's the FAB stuck at a partial width with its label
  /// half-faded, with nothing on the way to fix it.
  ///
  /// Rather than trying to detect that state, we make the resting state a
  /// matter of wall-clock time: one transition's worth after the last flip,
  /// the animated subtree is rebuilt under a new key. A fresh
  /// AnimatedSize/AnimatedOpacity lays out at its target *without* animating
  /// (neither animates on its first build), so whatever the old render object
  /// was stuck on is discarded. Re-arming on each flip means a healthy
  /// transition is never truncated, and when nothing was stuck the rebuild is
  /// invisible.
  void _setFabExtended(bool extended) {
    if (_isFabExtended == extended) return;
    setState(() => _isFabExtended = extended);
    _fabSettleTimer?.cancel();
    _fabSettleTimer = Timer(_fabTransitionDuration + _fabSettleSlack, () {
      if (mounted) setState(() => _fabSettleEpoch++);
    });
  }

  // The FAB's extend/collapse can get stuck mid-transition, at least on
  // web, where a backgrounded tab's frame pump doesn't necessarily resume on
  // its own once the tab is visible again — whatever frame the animation was
  // mid-paint on then never gets redrawn. AppLifecycleState.resumed fires for
  // both app-foregrounding (mobile) and tab-visibility-regained (web, via the
  // PlatformDispatcher), so asking for a fresh frame here lets a merely
  // stalled animation pick up where it left off, promptly and smoothly.
  //
  // That makes this the fast path, not the guarantee — a rebuild can't unstick
  // a stopped RenderAnimatedSize on its own (it resumes on layout, which a
  // rebuild needn't trigger). _setFabExtended's deadline is what actually
  // guarantees the FAB ends up at rest.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) setState(() {});
  }

  /// A touch anywhere on the screen means the user is engaged on their own,
  /// so a nudge still waiting its turn is dropped for this visit. No rebuild
  /// needed: [_nudgeArmed] stays false, so it simply never gets inserted.
  void _cancelPendingNudge() {
    _nudgeTimer?.cancel();
    _nudgeTimer = null;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Wraps the whole Scaffold, app bar included, so that anything the user
    // reaches for counts — not just the parts below it.
    return Listener(
      onPointerDown: (_) => _cancelPendingNudge(),
      child: _buildScaffold(context, theme),
    );
  }

  Widget _buildScaffold(BuildContext context, ThemeData theme) {
    return Scaffold(
      // Full height behind the on-screen keyboard so each pane paints its own
      // bottom — the Quick Lookup bar's teal on the left, the branding on the
      // right — and a two-pane split reflects through. Each keeps its content
      // above the keyboard itself (HomeQuickLookup / _BrandingPane).
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        flexibleSpace: windowHeaderGestureArea(),
        leadingWidth: isMacOSChromelessWindow ? 48 + macOSTrafficLightClearance(context) : null,
        leading: Padding(
          padding: EdgeInsets.fromLTRB(
            8 + (isMacOSChromelessWindow ? macOSTrafficLightClearance(context) : 0),
            8,
            8,
            8,
          ),
          child: SvgPicture.asset(ham2kSquareLogoAsset, width: 22, height: 22),
        ),
        // "Desktop Logger" / "Portable Logger" is the in-app main-screen
        // title — independent of the OS-level app name ("Ham2K Logger" on
        // desktop, "HaLo" on mobile; see macos/Runner/Configs/AppInfo.xcconfig,
        // ios/Runner/Info.plist, android's AndroidManifest.xml).
        title: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            // The product name gets priority over the edition badge/dev
            // label when the header is too narrow to fit both at full size
            // — a 3:1 flex split shrinks the trailing group
            // first and further, rather than shrinking both equally.
            Flexible(flex: 3, child: shrinkToFitText(Text(ham2kProductName))),
            if (ham2kEditionBadgeAsset != null || _devLabel.isNotEmpty) ...[
              const SizedBox(width: 10),
              Flexible(
                child: shrinkToFit(
                  // A free-form dev label (DEV_LABEL) — marks which dev build/session
                  // is running — takes the edition badge's place when present, rather
                  // than stacking with it; absent in release builds.
                  _devLabel.isNotEmpty
                      ? Text(
                          _devLabel,
                          style: TextStyle(
                            fontSize: 13,
                            fontStyle: FontStyle.italic,
                            color: (theme.appBarTheme.foregroundColor ?? theme.colorScheme.onPrimary)
                                .withValues(alpha: 0.8),
                          ),
                        )
                      // Zero-offset shadows read as a glow: black for Next, white for Dev.
                      : Ham2kEditionBadge(height: 15, shadows: ham2kHeaderEditionBadgeShadows),
                ),
              ),
            ],
          ],
        ),
        actions: [
          HeaderProfileLabel(settings: widget.services.settings),
          IconButton(
            icon: Icon(MdiIcons.cog, semanticLabel: context.t.settings.title),
            onPressed: () =>
                Navigator.of(context).push(MaterialPageRoute(builder: (_) => SettingsView(services: widget.services))),
            mouseCursor: SystemMouseCursors.click,
          ),
          const SizedBox(width: 8),
          windowsCaptionSpacer(context),
        ],
      ),
      // Two-pane on L+ (docs/design/layouts.md): the list column keeps the
      // ideal pane width and the branding pane takes the rest. Single-pane
      // sizes pass a null secondary so the list subtree stays mounted (and
      // keeps its scroll position) across a live resize.
      body: PaneSafeArea.root(
        context,
        // Real device safe-area insets (notch, home indicator) bubble in
        // from here; PaneSafeArea's own
        // divider-clearance role composes with it further down.
        child: ResizableSplitView(
          // Home is ViewLayoutPolicy.fixed and (for now) opts into the
          // "surfaces" divider: the branding pane reads as a surface under
          // the list column's shadow. See docs/design/layouts.md.
          dividerStyle: SplitDividerStyle.surfaces,
          secondary: ShirtSize.of(context).isTwoPane ? const _BrandingPane() : null,
          // Null when never dragged → the split's own 2/3-capped-at-sMax
          // default applies.
          preferredPrimaryWidth: widget.services.settings.layoutDimension(LayoutKeys.homeLeftColumn),
          maxPrimaryWidth: ShirtSize.sMax,
          onPreferredPrimaryWidthChanged: (width) =>
              widget.services.settings.setLayoutDimension(LayoutKeys.homeLeftColumn, width),
          primary: Column(
            children: [
              Expanded(
                child: NotificationListener<ScrollNotification>(
                  onNotification: (ScrollNotification notification) {
                    _setFabExtended(notification.metrics.pixels <= 10);
                    return false;
                  },
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: StreamBuilder<List<Operation>>(
                          stream: _operationsStream,
                          builder: (context, snapshot) {
                            // First real snapshot = bootstrap done + first data
                            // load complete: resolve the dev bridge's `ready`
                            // promise so agents can await it instead of
                            // sleeping. Idempotent; only while the bridge is live.
                            //
                            // Anchored to the build because that's what the test
                            // harness can drive; the cost is that on a HIDDEN web
                            // pane (Flutter throttles frames to ~0) `ready` waits
                            // until the pane is visible again. That's fine for the
                            // agent workflow — agents drive a visible pane — and
                            // it self-heals on the next frame.
                            if (snapshot.hasData && DevBridge.instance.installed) {
                              DevBridge.instance.signalReady();
                            }
                            return OperationListPanel(
                              services: widget.services,
                              // `snapshot.hasData` distinguishes "the stream
                              // hasn't emitted its first snapshot yet" from "it
                              // emitted an empty list" — collapsing both into
                              // `snapshot.data ?? []` would leave
                              // OperationListPanel guessing (via a fixed
                              // delay) how long "still loading" might last.
                              loading: !snapshot.hasData,
                              operations: snapshot.data ?? const <Operation>[],
                            );
                          },
                        ),
                      ),
                      // A Builder, not the outer `context`: this Stack is built
                      // directly inside _HomeViewState.build, above the
                      // PaneSafeArea established by PaneSafeArea.root — that
                      // `context` is an ANCESTOR of it, so PaneSafeArea.maybeOf
                      // would always find nothing and silently read 0. Builder
                      // gets a genuine descendant context while staying a
                      // transparent, non-RenderObject wrapper — Positioned's
                      // ParentDataWidget mechanism sees straight through it to
                      // this Stack.
                      Builder(
                        builder: (context) => Positioned(
                          // Clears the device's real bottom/right insets (home
                          // indicator, landscape cutout) so the FAB isn't drawn
                          // under them.
                          bottom: 16 + PaneSafeArea.bottomOf(context),
                          right: 16 + PaneSafeArea.rightOf(context),
                          child: ListenableBuilder(
                            listenable: widget.services.settings,
                            builder: (context, _) {
                              final fab = AnimatedSize(
                                // Changing this key is what forces the FAB
                                // back to its resting state once a transition's
                                // deadline has passed (see _setFabExtended).
                                key: ValueKey(_fabSettleEpoch),
                                duration: _fabTransitionDuration,
                                curve: Curves.easeInOut,
                                child: Container(
                                  key: _fabButtonKey,
                                  height: 56,
                                  width: _isFabExtended ? null : 56,
                                  decoration: BoxDecoration(
                                    color: fabAccentColor,
                                    borderRadius: BorderRadius.circular(16),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(alpha: 0.15),
                                        blurRadius: 6,
                                        offset: const Offset(0, 3),
                                      ),
                                    ],
                                  ),
                                  child: Material(
                                    color: Colors.transparent,
                                    child: InkWell(
                                      borderRadius: BorderRadius.circular(16),
                                      onTap: () => _newOperation(context),
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(horizontal: 16),
                                        child: Row(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Icon(MdiIcons.plus, color: theme.colorScheme.onPrimary),
                                            AnimatedSize(
                                              duration: _fabTransitionDuration,
                                              curve: Curves.easeInOut,
                                              child: SizedBox(
                                                width: _isFabExtended ? null : 0,
                                                child: AnimatedOpacity(
                                                  duration: _fabTransitionDuration,
                                                  curve: Curves.easeInOut,
                                                  opacity: _isFabExtended ? 1.0 : 0.0,
                                                  child: Padding(
                                                    padding: const EdgeInsets.only(left: 8),
                                                    child: Text(
                                                      context.t.home.newOperation,
                                                      maxLines: 1,
                                                      softWrap: false,
                                                      style: theme.textTheme.labelLarge?.copyWith(
                                                        color: theme.colorScheme.onPrimary,
                                                        fontWeight: FontWeight.bold,
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              );
                              final newOperationsOpened = widget.services.settings
                                  .onboardingShownCount(OnboardingFlows.newOperation);
                              final needsNudge =
                                  _nudgeArmed && newOperationsOpened < _newOperationNudgeThreshold;
                              return needsNudge ? _NewOperationNudge(child: fab) : fab;
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              HomeQuickLookup(services: widget.services),
            ],
          ),
        ),
      ),
    );
  }
}

/// Wraps the FAB with a repeating wiggle to draw a first-time user's eye,
/// for as long as [_newOperationNudgeThreshold] new operations
/// haven't been opened yet. The caller decides both WHETHER to include this
/// widget (by reading the onboarding count) and WHEN (after
/// [_newOperationNudgeDelay] of an untouched screen), rather than this widget
/// deciding whether to animate — so it's simply absent from the tree until
/// its moment, and dropped afterwards, instead of needing to smoothly start
/// or stop a mid-cycle rotation. It bursts as soon as it is mounted.
class _NewOperationNudge extends StatefulWidget {
  final Widget child;

  const _NewOperationNudge({required this.child});

  @override
  State<_NewOperationNudge> createState() => _NewOperationNudgeState();
}

class _NewOperationNudgeState extends State<_NewOperationNudge> with SingleTickerProviderStateMixin {
  static const _cycle = Duration(milliseconds: 1200);
  static const _bursts = 3;

  /// Quiet time between one burst and the next. Long enough that the FAB
  /// reads as catching the eye now and then rather than demanding attention.
  static const _gap = Duration(seconds: 3);

  /// How long the whole nudge lasts, from mount to the last burst's end.
  /// Derived rather than written out, so it can't drift from the schedule
  /// [_runBurst] actually keeps.
  static final _sequence = _cycle * _bursts + _gap * (_bursts - 1);

  late final AnimationController _controller = AnimationController(vsync: this, duration: _cycle);

  /// Set once the bursts' wall-clock time is up, after which this widget stops
  /// rotating its child at all.
  ///
  /// The controller runs once per mount, so if its ticker stops mid-burst — a
  /// muted route, a backgrounded tab — nothing would ever bring the rotation
  /// back to 0 and the FAB would sit there visibly tilted. Dropping the
  /// [Transform] outright is upright by construction, whatever value the
  /// controller froze at.
  bool _settled = false;
  Timer? _settleTimer;
  Timer? _gapTimer;
  int _burstsRun = 0;

  @override
  void initState() {
    super.initState();
    // Armed unconditionally, including under test: the guarantee is that the
    // FAB is upright once the nudge's time is up, no matter what ran.
    _settleTimer = Timer(_sequence + _fabSettleSlack, () {
      if (mounted) setState(() => _settled = true);
    });
    // An endlessly-repeating controller never lets pumpAndSettle finish
    // (same trap as _PulsingGpsPin in activities_view.dart) — settle at rest
    // under test instead of animating.
    final isTest = !kIsWeb && io.Platform.environment.containsKey('FLUTTER_TEST');
    if (isTest) {
      _controller.value = 0;
    } else {
      _runBurst();
    }
  }

  /// One flutter, then quiet, [_bursts] times — rather than fluttering the
  /// whole time the FAB is below the nudge threshold.
  ///
  /// Spacing the bursts by hand instead of with `repeat(count:)` is what keeps
  /// [_gap] independent of the tween's own weights: those proportions are what
  /// make the flutter read as a tremble, and stretching the cycle to hold a
  /// five-second pause inside it would slow every swing by the same factor.
  void _runBurst() {
    _controller.forward(from: 0);
    _burstsRun++;
    // Measured from the start of this burst, so the quiet time between one
    // cycle ending and the next beginning is exactly [_gap].
    if (_burstsRun < _bursts) _gapTimer = Timer(_cycle + _gap, _runBurst);
  }

  /// A rapid, small-angle flutter burst, then a pause at rest — reads as an
  /// occasional nudge rather than constant jitter. Each item's `weight` is
  /// its share of one [_cycle]; ten short alternating swings over a
  /// shortened cycle pack many direction changes into a small window,
  /// reading as a fast tremble rather than a slow rock.
  late final Animation<double> _angle = TweenSequence<double>([
    TweenSequenceItem(tween: Tween(begin: 0.0, end: -0.08), weight: 1),
    TweenSequenceItem(tween: Tween(begin: -0.08, end: 0.08), weight: 1),
    TweenSequenceItem(tween: Tween(begin: 0.08, end: -0.08), weight: 1),
    TweenSequenceItem(tween: Tween(begin: -0.08, end: 0.08), weight: 1),
    TweenSequenceItem(tween: Tween(begin: 0.08, end: -0.08), weight: 1),
    TweenSequenceItem(tween: Tween(begin: -0.08, end: 0.08), weight: 1),
    TweenSequenceItem(tween: Tween(begin: 0.08, end: -0.08), weight: 1),
    TweenSequenceItem(tween: Tween(begin: -0.08, end: 0.08), weight: 1),
    TweenSequenceItem(tween: Tween(begin: 0.08, end: -0.08), weight: 1),
    TweenSequenceItem(tween: Tween(begin: -0.08, end: 0.0), weight: 1),
    TweenSequenceItem(tween: ConstantTween(0.0), weight: 4),
  ]).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));

  @override
  void dispose() {
    _settleTimer?.cancel();
    _gapTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_settled) return widget.child;
    return AnimatedBuilder(
      animation: _angle,
      builder: (context, child) => Transform.rotate(angle: _angle.value, child: child),
      child: widget.child,
    );
  }
}

/// The home view's right column on two-pane layouts: the operation list has
/// nothing useful to spend the extra width on, so it shows the wordmark and
/// version instead.
class _BrandingPane extends StatelessWidget {
  const _BrandingPane();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final details = buildDetails();
    return Container(
      color: theme.colorScheme.surfaceContainerHighest,
      alignment: Alignment.center,
      // No keyboard padding here: `StatusBarOverlay` holds the keyboard's
      // height back for the whole app and consumes the inset, so this pane is
      // already only as tall as the space above the keyboard. Padding by
      // `viewInsets.bottom` as well would shrink the branding to a sliver
      // pinned near the top on iPad landscape.
      // Scale the branding down rather than overflow when the pane is short —
      // e.g. landscape two-pane with the keyboard up shrinks it well below
      // the logo+text's natural height. No effect at full height.
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SvgPicture.asset(ham2kSquareLogoAsset, width: 180),
          const SizedBox(height: 4),
          // The square mark already says "Ham2K", so per the branding rules
          // (docs/design/user-interface.md) only the product name — "Mac
          // Logger", "Browser Logger", etc. — goes below it.
          Text(
            ham2kProductName,
            style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
          ),
          // Edition badge below the name, centered, a bit smaller (Regular has none).
          if (ham2kEditionBadgeAsset != null) ...[
            const SizedBox(height: 8),
            SvgPicture.asset(ham2kEditionBadgeAsset!, width: 130),
          ],
          // A free-form dev label (DEV_LABEL) — marks which dev build/session is
          // running; absent in release builds. Unlike the header (where it takes the
          // badge's place), here it's shown alongside it, between the badge and the
          // version name.
          if (_devLabel.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              _devLabel,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontStyle: FontStyle.italic,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
          const SizedBox(height: 16),
          // Just the release name, without the edition qualifier (the edition
          // is already shown by the badge SVG above).
          VersionLabel(
            nameOnly: true,
            style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
          // Build number and/or git SHA underneath, in every build mode: a bug
          // report from a release build is the one that most needs to say which
          // build it came from. Empty only when there is nothing to identify
          // this build by (see buildDetails), and then the line is dropped
          // rather than rendered as a bare "()".
          if (details.isNotEmpty)
            Text(
              details,
              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
        ],
        ),
      ),
    );
  }
}

class HomeQuickLookup extends StatefulWidget {
  final HaLoServices services;

  const HomeQuickLookup({super.key, required this.services});

  @override
  State<HomeQuickLookup> createState() => _HomeQuickLookupState();
}

class _HomeQuickLookupState extends State<HomeQuickLookup> with WidgetsBindingObserver {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();

  /// Lookup, command interpretation and execution all live in the shared
  /// engine — the ⌘K command dialog runs on the same one, so the debounce,
  /// space-retention and execute rules can't drift
  /// between the two. This widget only renders it.
  late final CommandEngine _engine;

  @override
  void initState() {
    super.initState();
    _engine = CommandEngine(
      services: widget.services,
      // The home screen has no open operation, so operation-scoped commands
      // (SEED, NOTE, SPOT) answer with their own error here.
      operationContext: () => null,
      runAction: (action, params) => runCommandAction(widget.services, this, action, params),
    )..attach(_controller);
    _engine.addListener(_onEngineChanged);
    // The clear button and the numbers row's contextual key both key off the
    // text, and the numbers row shows only while this field has focus, so
    // rebuild for both.
    _controller.addListener(_onEngineChanged);
    _focusNode.addListener(_onFocusChanged);
    // The numbers row and the bottom reserve both ask the raw FlutterView
    // whether the keyboard is up, because StatusBarOverlay consumes the inset
    // from MediaQuery — and the raw view carries no rebuild dependency, so
    // this is what notices the keyboard opening and closing.
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeMetrics() {
    if (isMobilePlatform && mounted) setState(() {});
  }

  @override
  void dispose() {
    // A published row would otherwise outlive this field, floating over
    // whatever replaces it with a dead key handler. The controller defers the
    // write while the tree is locked, which it is here.
    widget.services.keyboardAccessory.clearIfOwner(this);
    WidgetsBinding.instance.removeObserver(this);
    _focusNode.removeListener(_onFocusChanged);
    _controller.removeListener(_onEngineChanged);
    _engine.removeListener(_onEngineChanged);
    _engine.dispose();
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onEngineChanged() {
    if (mounted) setState(() {});
  }

  void _onFocusChanged() {
    if (mounted) setState(() {});
  }

  /// Whether to float the mobile numbers row above the keyboard right now: the
  /// setting is on, we're on a phone/tablet, this field has focus, and a real
  /// on-screen keyboard is up (`virtualKeyboardIsUp`'s >100px threshold ignores
  /// iOS's thin hardware-keyboard accessory bar, ~45–55px).
  ///
  /// Reads the raw `FlutterView`, not MediaQuery: `StatusBarOverlay`
  /// consumes the bottom inset for everything below it, so MediaQuery reports 0
  /// here even with the keyboard up. That is deliberate — it stops every route
  /// reserving the keyboard a second time — but it means "is the keyboard up?"
  /// has to be asked of the view. The raw view has no rebuild dependency, hence
  /// `didChangeMetrics` below.
  bool _shouldShowNumbersRow(BuildContext context) =>
      isMobilePlatform &&
      widget.services.settings.showNumbersRow &&
      _focusNode.hasFocus &&
      virtualKeyboardIsUp(context);

  /// Publishes (or withdraws) this field's numbers row. Written after the
  /// frame, never during build: the overlay that draws it is an ancestor, and
  /// notifying it mid-build would rebuild a widget already being built.
  void _syncNumbersRow(BuildContext context, ThemeData theme) {
    final accessory = widget.services.keyboardAccessory;
    final spec = _shouldShowNumbersRow(context)
        ? KeyboardAccessorySpec(
            onKey: _handleNumberKey,
            extraKey: _numbersRowExtraKey,
            vibrate: widget.services.settings.vibrateNumbersRow,
            backgroundColor: (theme.appBarTheme.backgroundColor ?? theme.colorScheme.primary).toARGB32(),
            foregroundColor: (theme.appBarTheme.foregroundColor ?? theme.colorScheme.onPrimary).toARGB32(),
          )
        : null;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (spec == null) {
        accessory.clearIfOwner(this);
      } else {
        accessory.publish(this, spec);
      }
    });
  }

  /// The contextual extra key: "/" once a callsign (letters, not just digits)
  /// is being composed — for portable calls like W1AW/P — otherwise ".". Same
  /// rule as the logging panel; null when the extra key is turned off.
  String? get _numbersRowExtraKey {
    if (!widget.services.settings.showExtraInNumbersRow) return null;
    final text = _controller.text;
    final hasLetter = RegExp(r'[A-Za-z]').hasMatch(text);
    final onlyDigits = RegExp(r'^[0-9]+$').hasMatch(text);
    return (hasLetter && !onlyDigits) ? '/' : '.';
  }

  /// Inserts a tapped numbers-row character at the cursor. Sets the controller
  /// value directly (bypassing the field's input formatters, which is fine —
  /// digits and "/"/"." need no transform), which fires `_onTextChanged` so
  /// the lookup/command interpretation runs just as if it were typed.
  void _handleNumberKey(String key) {
    final value = _controller.value;
    final selection = value.selection;
    final start = selection.start < 0 ? value.text.length : selection.start;
    final end = selection.end < 0 ? value.text.length : selection.end;
    _controller.value = value.copyWith(
      text: value.text.replaceRange(start, end, key),
      selection: TextSelection.collapsed(offset: start + key.length),
      composing: TextRange.empty,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final lookupLine = _engine.lookupLine;

    final commandMessage = _engine.message;
    final hasContent = commandMessage != null || lookupLine != null;

    // The Home Scaffold doesn't resize for the keyboard, so this bar
    // reserves the bottom safe area itself below the field (and the numbers
    // row, when shown), and its Material fills that strip so the teal forms the
    // home-indicator strip. NOT the keyboard: `StatusBarOverlay` reserves that
    // for the whole app so the status footer rides above it instead of hiding,
    // which means the space this bar is given already ends above the keyboard.
    // And nothing at all while the keyboard is up, since it covers the home
    // indicator: the strip the overlay is already holding back IS that space.
    //
    // The keyboard question goes to the raw view, not MediaQuery — the overlay
    // consumes that inset on the way down precisely so no route reserves it
    // twice, which also means MediaQuery reports 0 here in both states and
    // could not tell them apart. `viewPadding`, not `padding`, for the safe
    // area, since the latter zeroes out under the keyboard.
    final mq = MediaQuery.of(context);
    final view = View.of(context);
    final keyboardUp = view.viewInsets.bottom > 0;
    final bottomReserve = keyboardUp ? 0.0 : mq.viewPadding.bottom;
    _syncNumbersRow(context, theme);

    return Material(
      elevation: 8,
      color: theme.appBarTheme.backgroundColor ?? theme.colorScheme.surface,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (hasContent)
            Container(
              width: double.infinity,
              padding: PaneSafeArea.symmetricOf(context, horizontal: 16, vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (commandMessage != null)
                    Row(
                      children: [
                        if (_engine.isError) ...[
                          Icon(MdiIcons.alertCircle, size: 16, color: theme.colorScheme.onPrimary),
                          const SizedBox(width: 8),
                        ],
                        Expanded(
                          child: MarkdownBody(
                            data: commandMessage,
                            styleSheet: MarkdownStyleSheet.fromTheme(theme).copyWith(
                              p: theme.textTheme.bodyLarge?.copyWith(
                                color: _engine.isConfirmation
                                    ? theme.colorScheme.onPrimary
                                    : theme.colorScheme.onPrimary.withValues(alpha: 0.85),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  if (commandMessage == null && lookupLine != null)
                    Row(
                      children: [
                        Icon(MdiIcons.accountSearch, size: 16, color: theme.colorScheme.onPrimary),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            lookupLine,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onPrimary.withValues(alpha: 0.85),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          Padding(
            padding: PaneSafeArea.symmetricOf(context, horizontal: 16, vertical: 8),
            child: TextField(
              selectAllOnFocus: false,
              controller: _controller,
              focusNode: _focusNode,
              style: haloMonoStyle(context, fontSize: 15),
              textCapitalization: TextCapitalization.characters,
              inputFormatters: [
                if (isMobilePlatform) MobileDotToSlashFormatter(),
                // Spaces are only meaningful mid-command (a command's free-
                // text parameters, e.g. "NOTE hello") — otherwise they'd
                // just corrupt a callsign/command being typed.
                if (!_engine.commandExpectsParams && !_engine.commandMixedCase)
                  FilteringTextInputFormatter.deny(RegExp(r'\s')),
                TextInputFormatter.withFunction(
                  (oldValue, newValue) => newValue.copyWith(text: newValue.text.toUpperCase()),
                ),
              ],
              decoration: InputDecoration(
                filled: true,
                fillColor: theme.colorScheme.surface,
                prefixIcon: const Icon(MdiIcons.magnify),
                suffixIcon: _controller.text.isNotEmpty
                    ? IconButton(
                        icon: Icon(MdiIcons.close, semanticLabel: context.t.common.clear),
                        onPressed: () {
                          _controller.clear();
                        },
                      )
                    : null,
                hintText: context.t.home.quickLookup,
                isDense: true,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(24.0), borderSide: BorderSide.none),
              ),
              // Not onSubmitted: the default TextInputAction.done handling
              // unfocuses (closing the keyboard) before onSubmitted even
              // runs. onEditingComplete replaces that default entirely, so
              // the field keeps focus for the next command.
              onEditingComplete: () => _engine.submit(),
            ),
          ),
          // The numbers row is not drawn here — it is published to
          // `StatusBarOverlay`, which draws it below the status footer and
          // directly on the keyboard (see `_syncNumbersRow`). Same reason as
          // the logging panel: the footer is one level up, so no route can put
          // itself under it.
          if (bottomReserve > 0) SizedBox(width: double.infinity, height: bottomReserve),
        ],
      ),
    );
  }
}
