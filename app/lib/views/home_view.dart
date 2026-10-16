import 'dart:async';
import 'dart:io' as io;
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:halo_core/halo_core.dart';
import 'package:halo_widgets/halo_widgets.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

import '../config/dev_bridge.dart';
import '../config/dev_label.dart';
import '../services/command_actions.dart';
import '../services/halo_services.dart';
import 'app_shell/home_rail_state.dart';
import '../services/link_opener.dart';
import '../services/panel_service.dart';
import '../services/settings_service.dart';
import '../tools/operation_title.dart';
import '../tools/worked_before_label.dart';
import 'command_engine.dart';
import 'dock_host.dart';
import 'header_profile_label.dart';
import 'home_branding_pane.dart';
import 'home_navigation_rail.dart';
import 'chase_view.dart';
import 'logs_view.dart';
import 'maps_view.dart';
import 'operation/call_info_panel.dart';
import 'operation/extension_panel.dart';
import 'operation_dialogs.dart';
import 'operation_view.dart';
import 'qson_import_flow.dart';
import 'settings_view.dart';
import 'ham2k_logo.dart';
import 'panel_use_tracker.dart';
import 'package:halo_i18n/halo_i18n.dart';

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
    final subtitle = suggestedSubtitle.isNotEmpty ? suggestedSubtitle : operation.refs.map((r) => r['name']).whereType<String>().join(' • ');

    // A deleted operation reads as app-polo shows one: the whole row at half
    // strength, its title line struck through.
    final strike = operation.deleted ? TextDecoration.lineThrough : null;

    final row = Material(
      color: theme.colorScheme.surface,
      child: InkWell(
        onTap: () => Navigator.of(context).push(slideInFromRight<void>((_) => OperationView(services: services, operationUuid: operation.uuid))),
        // Undelete lives in the operation's own tools menu, so a deleted row
        // has nothing to offer here.
        onLongPress: operation.deleted ? null : () => confirmDeleteOperation(context, services, operation),
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
                            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800, fontFamily: 'RobotoMono', decoration: strike),
                          ),
                          TextSpan(
                            text: ' ${displayTitleFor(context, operation)}',
                            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700, decoration: strike),
                          ),
                        ],
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: Space.md),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: Space.md, vertical: Space.xxs),
                    decoration: BoxDecoration(color: theme.colorScheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(12)),
                    child: Text(formatNumber(operation.qsoCount), style: theme.textTheme.labelLarge),
                  ),
                ],
              ),
              const SizedBox(height: Space.xxs),
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
    return operation.deleted ? Opacity(opacity: 0.5, child: row) : row;
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
    final color = HaLoColors.of(context).listBackground;
    if (operations.isEmpty) {
      if (loading) return ColoredBox(color: color);
      return Container(
        color: color,
        child: Center(child: Text(context.t.home.emptyList)),
      );
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
  /// Home's panes are user-arrangeable (docs/design/layouts.md).
  static const layoutPolicy = ViewLayoutPolicy.customizable;

  /// The dock module ids Home builds itself.
  static const operationsPanelId = 'operations';
  static const versionPanelId = 'version';

  /// Quick Lookup's id, which names NO pane — it is chrome now, outside the
  /// arrangement entirely.
  ///
  /// Named `retired` because that is the only thing left to do with it, and it
  /// must go on being done: `_HomeViewState.retiredModules` hands this to the
  /// dock host, which drops the module from a spec that still names it and
  /// gives its space to its siblings. An operator who arranged Home while
  /// Quick Lookup was a pane has exactly such a spec. Take this away and the
  /// drop stops: `lookup` reaches the dock as a module nobody supplies a
  /// widget for, and Home shows a permanent empty pane — with only
  /// `DockLayoutView`'s assert-mode "no child widget supplied" line to say so,
  /// which no release build prints and no operator can read.
  static const retiredLookupPanelId = 'lookup';

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

class _HomeViewState extends State<HomeView> with WidgetsBindingObserver, RouteAware, TickerProviderStateMixin, DockHost<HomeView> {
  @override
  HaLoServices get dockServices => widget.services;

  @override
  String get dockView => PanelViews.home;

  @override
  DockLayoutKeys dockKeysFor(DockLayoutClass layoutClass) => switch (layoutClass) {
    DockLayoutClass.wide => const DockLayoutKeys(
      spec: LayoutKeys.homeDock,
      state: LayoutKeys.homeDockState,
      paneOptions: LayoutKeys.homePaneOptions,
      viewOptions: LayoutKeys.homeViewOptions,
    ),
    DockLayoutClass.narrow => const DockLayoutKeys(
      spec: LayoutKeys.homeNarrowDock,
      state: LayoutKeys.homeNarrowDockState,
      paneOptions: LayoutKeys.homeNarrowPaneOptions,
      viewOptions: LayoutKeys.homeNarrowViewOptions,
    ),
  };

  @override
  Set<String> get nativeModuleIds => const {HomeView.operationsPanelId, HomeView.versionPanelId};

  /// Both of them. Home's panes say what they are by their own content — a
  /// list of operations, the Ham2K mark — so a title bar over each would be a
  /// label naming what is already on screen, in a window whose whole job is to
  /// show them. The operator can turn either back on from that pane's layout
  /// options.
  @override
  Set<String> get defaultHeaderlessModules => nativeModuleIds;

  /// Home has no operation, no QSO being logged, and no live spot cache — it
  /// subscribes to none of them, so there is nothing here to report. Extension
  /// panels on Home therefore render on mount, on their own `tick:` timer, and
  /// whenever their config changes; the `operation`/`qso`/`spots` triggers
  /// cannot fire, because on this screen none of those things happen.
  @override
  PanelRenderContext get panelRenderContext => const PanelRenderContext();

  @override
  Map<String, String> get nativeTitles => {
    HomeView.operationsPanelId: context.t.home.panels.operations,
    HomeView.versionPanelId: context.t.home.panels.version,
  };

  /// What the operator's old dragged divider becomes, once.
  ///
  /// Installs carry a pixel width under `home.leftColumn`, from the fixed
  /// split the dock replaces. The dock persists proportions, so that value has
  /// to be converted rather than abandoned — dropping it silently resets a
  /// width the operator chose deliberately. Read against the window the FIRST default spec
  /// is built for, which is the only moment a pixel width can be turned into a
  /// ratio at all.
  ///
  /// Returns null when there is nothing stored (a fresh install, or an
  /// operator who never dragged it), which leaves the shipped 2:1.
  List<double>? _migratedColumnWeights() {
    final stored = widget.services.settings.layoutDimension(LayoutKeys.homeLeftColumn);
    if (stored == null || stored <= 0) return null;
    final total = MediaQuery.sizeOf(context).width - HomeNavigationRail.collapsedWidth;
    if (total <= 0) return null;
    // The cap the old split enforced through `maxPrimaryWidth`, applied here
    // because the dock has no such notion: without it a 2560px window gives
    // the operation list ~1700px of stretched rows. `ShirtSize.sMax` is the
    // widest a pane's content is designed for.
    final primary = math.min(stored, ShirtSize.sMax);
    final secondary = total - primary;
    if (secondary <= 0) return null;
    return [primary, secondary];
  }

  /// The shipped split: two thirds to the operation list, and never wider
  /// than a pane's content is designed for.
  ///
  /// Worked out against the window rather than written as `[2, 1]`, because
  /// that ratio has no ceiling and the dock enforces only a floor — on a
  /// 2560pt window it lays the list out at ~1700pt of stretched callsign rows,
  /// where the split this replaced clamped it to [ShirtSize.sMax]. Weights
  /// persist from here, so the cap applies as the default is first built.
  List<double> _shippedColumnWeights() {
    final total = MediaQuery.sizeOf(context).width - HomeNavigationRail.collapsedWidth;
    if (total <= 0) return [2, 1];
    final primary = math.min(total * 2 / 3, ShirtSize.sMax);
    final secondary = total - primary;
    return secondary <= 0 ? [2, 1] : [primary, secondary];
  }

  /// The operation list beside the branding, which is the arrangement Home
  /// shipped with. Quick Lookup is in neither group: it is chrome under the
  /// whole dock, so a phone shows the list with the bar beneath it without the
  /// arrangement having to say so.
  ///
  /// Narrow ships as the list ALONE. The branding column is not in it: two
  /// thirds of a 360-pixel window is not a list, and the mark is already on
  /// the header. It stays addable from the sheet for an operator who wants
  /// it.
  @override
  DockNode buildDefaultDockSpec(DockLayoutClass layoutClass, {bool migrate = true}) => switch (layoutClass) {
    DockLayoutClass.narrow => DockGroup([HomeView.operationsPanelId]),
    DockLayoutClass.wide => DockSplit(Axis.horizontal, [
      DockGroup([HomeView.operationsPanelId]),
      DockGroup([HomeView.versionPanelId]),
      // The operator's own width if they ever set one — but never for a
      // RESTORE, which is the one control that has to reach the shipped
      // arrangement.
    ], (migrate ? _migratedColumnWeights() : null) ?? _shippedColumnWeights()),
  };

  /// Quick Lookup is chrome, not a pane — always on screen, below
  /// whatever the layout holds — so an arrangement that still names it is
  /// describing a pane that no longer exists.
  @override
  Set<String> get retiredModules => const {HomeView.retiredLookupPanelId};

  /// Registers Home's panels with the service. From [didChangeDependencies]
  /// rather than [initState] because the titles are localized — a locale
  /// change has to reach the catalog too.
  void _registerNativePanels() {
    final t = context.t.home.panels;
    final service = widget.services.panels;
    service.registerNative(
      PanelDefinition(
        id: HomeView.operationsPanelId,
        title: t.operations,
        description: t.operationsDescription,
        icon: 'notebook-multiple',
        source: PanelSource.native,
        views: const {PanelViews.home},
      ),
    );
    service.registerNative(
      PanelDefinition(
        id: HomeView.versionPanelId,
        title: t.version,
        description: t.versionDescription,
        icon: 'information-outline',
        source: PanelSource.native,
        views: const {PanelViews.home},
      ),
    );
    registerSharedDashboardPanels();
  }

  bool _isFabExtended = true;

  /// Bumped once a transition's deadline passes, and used as the animated
  /// FAB subtree's key — see [_setFabExtended].
  int _fabSettleEpoch = 0;
  Timer? _fabSettleTimer;

  /// Carries the pane subtrees across the two-pane flip.
  ///
  /// The dock and the narrow Column are different widgets at the same slot, so
  /// without these the whole subtree is torn down and rebuilt whenever the
  /// window (or a Font Scale change, which moves the effective width) crosses
  /// the boundary: the list loses its scroll position, its operations stream
  /// resubscribes and the pane flashes its empty state for a frame, and the
  /// FAB snaps back to extended. Reparenting keeps the elements, their State
  /// and their scroll offsets. Same reason the Operation view keys its panes.
  ///
  /// Per-instance, not file-level: two HomeViews alive at once (a route
  /// transition between them) would otherwise collide on one key.
  late final GlobalKey _operationsPaneKey = GlobalKey();

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
  ///
  /// Keyed on the Show Deleted Operations setting, the one thing that changes
  /// which query this is.
  Stream<List<Operation>>? _operationsStream;
  bool? _operationsStreamIncludesDeleted;

  Stream<List<Operation>> _operations() {
    final includeDeleted = widget.services.settings.showDeletedOps;
    if (_operationsStream == null || _operationsStreamIncludesDeleted != includeDeleted) {
      _operationsStream = widget.services.operations.watchAll(includeDeleted: includeDeleted);
      _operationsStreamIncludesDeleted = includeDeleted;
    }
    return _operationsStream!;
  }

  /// Nothing else rebuilds the operations pane when a setting changes.
  void _onSettingsChanged() {
    if (widget.services.settings.showDeletedOps != _operationsStreamIncludesDeleted) setState(() {});
  }

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
      final operation = await widget.services.operations.create(stationCall: widget.services.settings.activeProfile.operatorCall);
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
              .push(slideInFromRight<void>((_) => OperationView(services: widget.services, operationUuid: operation.uuid, openActivities: true)))
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
    _startHomeVisit();
    // Seed the rail from the stored preference.
    homeRail.expanded = widget.services.settings.homeNavExpanded;
    homeRail.destination = HomeDestination.operations;
    homeRail.addListener(_onRailChanged);
    widget.services.settings.addListener(_onSettingsChanged);
    WidgetsBinding.instance.addObserver(this);
    _nudgeTimer = Timer(_newOperationNudgeDelay, () {
      if (mounted) setState(() => _nudgeArmed = true);
    });
  }

  /// Replaced per visit, not per State — see [_startHomeVisit].
  late PanelUseTracker _panels;

  /// This State is never disposed (HomeView is `MaterialApp.home`), so a
  /// visit is marked here rather than in [initState] alone: on first build
  /// and again each time a pushed screen pops back to it.
  void _startHomeVisit() {
    widget.services.track('screen_viewed', {'screen': 'home'});
    _panels = PanelUseTracker(track: widget.services.track, screen: 'home');
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _registerNativePanels();
    final route = ModalRoute.of(context);
    if (route is PageRoute) homeRouteObserver.subscribe(this, route);
  }

  @override
  void didPopNext() => _startHomeVisit();

  @override
  void dispose() {
    // Nothing resets the rail's global state here. It outlives this view by
    // design — the window draws the rail, not Home — and every field it holds
    // is re-seeded by the next `initState`. Writing to it from a `dispose`
    // would also notify an ancestor already being torn down.
    _settingsSlide.dispose();
    _logsSlide.dispose();
    _chaseSlide.dispose();
    _mapsSlide.dispose();
    homeRail.removeListener(_onRailChanged);
    widget.services.settings.removeListener(_onSettingsChanged);
    homeRouteObserver.unsubscribe(this);
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
    return Listener(onPointerDown: (_) => _cancelPendingNudge(), child: _buildScaffold(context, theme));
  }

  /// The operator's stored preference, mirrored here so the toggle takes
  /// effect on the frame it is pressed. [SettingsService.setHomeNavExpanded]
  /// only makes the new value readable once its write to storage has
  /// completed, and nothing rebuilds this scaffold when it does — reading the
  /// setting back inside `build` shows the OLD width and then never corrects
  /// itself, which is a toggle that does nothing at all.
  late bool _navExpandedSetting = widget.services.settings.homeNavExpanded;

  /// Whether Settings is showing IN PLACE of Home's own content. Not a pushed
  /// route: the rail is the app's navigation, and a route over the top would
  /// cover the very thing the operator navigated with. Other entry points into
  /// Settings (the command bar, the operation view) still push, because they
  /// are not navigating within this shell.
  bool _showingSettings = false;

  /// Same as [_showingSettings], for the Logs destination.
  bool _showingLogs = false;

  /// Same as [_showingSettings], for the Chasing destination.
  bool _showingChase = false;

  /// Whether Chasing has been shown at all. From then on it stays MOUNTED,
  /// offstage while another destination is up, rather than torn down like
  /// Settings and Logs: it holds a contact being logged, or an earlier one
  /// being edited, and a trip to the Operations list must not throw either
  /// away.
  bool _chaseMounted = false;

  /// Same as [_showingSettings], for the Maps destination.
  bool _showingMaps = false;

  /// Same as [_chaseMounted], for Maps: a map torn down and rebuilt on every
  /// visit reloads its style and loses where the operator had taken it.
  bool _mapsMounted = false;

  /// Drives Settings on and off OVER Home. An explicit controller rather than
  /// an AnimatedSwitcher: a switcher animates both children, and coming back
  /// has to leave Home exactly where it is so that it is REVEALED rather than
  /// slid in behind.
  late final AnimationController _settingsSlide = AnimationController(vsync: this, duration: layoutAnimationDuration);

  late final Animation<Offset> _settingsOffset = Tween<Offset>(
    begin: const Offset(-1, 0),
    end: Offset.zero,
  ).animate(CurvedAnimation(parent: _settingsSlide, curve: layoutAnimationCurve));

  /// Same as [_settingsSlide], for the Logs destination.
  late final AnimationController _logsSlide = AnimationController(vsync: this, duration: layoutAnimationDuration);

  late final Animation<Offset> _logsOffset = Tween<Offset>(
    begin: const Offset(-1, 0),
    end: Offset.zero,
  ).animate(CurvedAnimation(parent: _logsSlide, curve: layoutAnimationCurve));

  /// Same as [_settingsSlide], for the Chasing destination.
  late final AnimationController _chaseSlide = AnimationController(vsync: this, duration: layoutAnimationDuration);

  late final Animation<Offset> _chaseOffset = Tween<Offset>(
    begin: const Offset(-1, 0),
    end: Offset.zero,
  ).animate(CurvedAnimation(parent: _chaseSlide, curve: layoutAnimationCurve));

  /// Same as [_settingsSlide], for the Maps destination.
  late final AnimationController _mapsSlide = AnimationController(vsync: this, duration: layoutAnimationDuration);

  late final Animation<Offset> _mapsOffset = Tween<Offset>(
    begin: const Offset(-1, 0),
    end: Offset.zero,
  ).animate(CurvedAnimation(parent: _mapsSlide, curve: layoutAnimationCurve));

  void _showSettings(bool showing) {
    if (_showingSettings == showing) return;
    setState(() => _showingSettings = showing);
    showing ? _settingsSlide.forward() : _settingsSlide.reverse();
  }

  /// Takes the embedded Settings down. The header's back button and the
  /// system back press both come here, so the two cannot drift apart.
  void _leaveSettings() {
    final last = homeRail.lastNonSettingsDestination;
    // Same guard as the rail's own Settings toggle — Logs or Chasing may have
    // gone behind its experiment flag while Settings sat over it.
    final settings = widget.services.settings;
    final offered = homeDestinationOffered(
      last,
      showLogs: settings.experimentEnabled('logs') /* stored key, see experiments.yaml */,
      showChase: settings.experimentEnabled('chase') /* stored key, see experiments.yaml */,
    );
    homeRail.destination = offered ? last : HomeDestination.operations;
  }

  /// Same as [_showSettings], for the Logs destination.
  void _showLogsView(bool showing) {
    if (_showingLogs == showing) return;
    setState(() => _showingLogs = showing);
    showing ? _logsSlide.forward() : _logsSlide.reverse();
  }

  /// Same as [_showSettings], for the Chasing destination.
  void _showChaseView(bool showing) {
    if (_showingChase == showing) return;
    setState(() {
      _showingChase = showing;
      if (showing) _chaseMounted = true;
    });
    showing ? _chaseSlide.forward() : _chaseSlide.reverse();
  }

  /// Same as [_showChaseView], for the Maps destination.
  void _showMapsView(bool showing) {
    if (_showingMaps == showing) return;
    setState(() {
      _showingMaps = showing;
      if (showing) _mapsMounted = true;
    });
    showing ? _mapsSlide.forward() : _mapsSlide.reverse();
  }

  /// Which destination [_onRailChanged] last tracked a visit for — set to
  /// [HomeDestination.operations] in [initState] to match its own explicit
  /// [_startHomeVisit] call, so the rail's very first change (e.g. straight
  /// into Settings) doesn't also count as a second Home visit.
  HomeDestination _lastTrackedDestination = HomeDestination.operations;

  /// Mirrors the window's rail state into this view — the rail is drawn by the
  /// shell, so what it reports is the source of truth for which destination is
  /// up and whether the labels are out.
  void _onRailChanged() {
    if (!mounted) return;
    final destination = homeRail.destination;
    _showSettings(destination == HomeDestination.settings);
    _showLogsView(destination == HomeDestination.logs);
    _showChaseView(destination == HomeDestination.chase);
    _showMapsView(destination == HomeDestination.maps);
    // Settings/Logs shown IN PLACE is navigation without a route, so
    // `didPopNext` never fires for it. Settings and Logs track their own
    // `screen_viewed` in `initState` (embedded panes get freshly remounted
    // each time they're revealed — see the `isDismissed` check around each
    // one's `ListenableBuilder`); Home only gets one when the destination
    // actually LANDS there, not merely whenever some other pane hides.
    if (destination != _lastTrackedDestination) {
      _lastTrackedDestination = destination;
      if (destination == HomeDestination.operations) _startHomeVisit();
    }
    if (homeRail.expanded != _navExpandedSetting) {
      setState(() => _navExpandedSetting = homeRail.expanded);
    }
  }

  Widget _buildScaffold(BuildContext context, ThemeData theme) {
    final isTwoPane = ShirtSize.of(context).isTwoPane;
    // Which arrangement the dock below draws. Assigned before it is built:
    // every accessor the mixin offers reads this field.
    dockLayoutClass = isTwoPane ? DockLayoutClass.wide : DockLayoutClass.narrow;
    // Home and Settings both sit BESIDE the rail (drawn by the window — see
    // `HomeRailState`), so each holds its own column open by the rail's width.
    //
    // Off the rail's RESTING width — what it measures with the labels out or
    // not — which changes only when the operator toggles it. Animated for
    // exactly that reason and no other, in step with the rail: same duration
    // and curve, both started by the same notification. Home does not move for
    // anything else, and never for navigation.
    //
    // The padding goes on each child rather than around the Stack so that
    // Settings SLIDES from the window's edge, passing under the rail on its
    // way, and only comes to rest beside it. Around the Stack it would start
    // at the rail's inner edge instead, which reads as sliding out of the
    // panes rather than out of the destination that was pressed.
    Widget besideRail(Widget child) => AnimatedPadding(
      duration: layoutAnimationDuration,
      curve: layoutAnimationCurve,
      padding: EdgeInsets.only(left: HomeNavigationRail.widthFor(context, expanded: _navExpandedSetting)),
      child: child,
    );

    // Settings rides OVER Home rather than swapping with it: both directions
    // travel leftward — in from the left edge, out to it — and on the way out
    // Home has to be sitting there unmoved to be revealed.
    return Stack(
      fit: StackFit.expand,
      children: [
        // Out of the semantics tree while a pane covers it. Painted over, Home
        // still answers to its semantics: on web those are DOM nodes that take
        // clicks, so a click on an empty stretch of Logs or Settings would
        // open the operation card beneath it, and a screen reader would read
        // a list nobody can see.
        ExcludeSemantics(
          excluding: _showingSettings || _showingLogs || _showingChase || _showingMaps,
          child: besideRail(_homeScaffold(context, theme, isTwoPane)),
        ),
        // Listening to the controller, not just to `setState`: the slide OUT
        // ends without any rebuild of its own, and a Settings left mounted
        // off-screen keeps laying itself out against a pane it no longer has —
        // which is a negative padding, not merely wasted work.
        ListenableBuilder(
          listenable: _settingsSlide,
          builder: (context, child) => _settingsSlide.isDismissed
              ? const SizedBox.shrink()
              // Settings has no route of its own for the system back key or
              // gesture to pop — it rides over Home inside Home's — so
              // unclaimed, the press reaches Home's route and leaves the app.
              // Claimed only while Settings is the live destination: mounted
              // but sliding OUT it is already gone as far as the operator is
              // concerned, and a press absorbed there does nothing at all
              // instead of backgrounding the app the way a press on Home does.
              //
              // `canPop` scopes the VETO only: a route hands the press to
              // every PopScope registered on it, whichever one refused it. So
              // the pane that is leaving has to decline the callback too, or
              // switching between the two panes gives one press two answers.
              : PopScope(
                  canPop: !_showingSettings,
                  onPopInvokedWithResult: (didPop, _) {
                    if (!didPop && _showingSettings) _leaveSettings();
                  },
                  child: SlideTransition(position: _settingsOffset, child: child!),
                ),
          child: besideRail(
            SettingsView(
              services: widget.services,
              embedded: true,
              onBack: _leaveSettings,
              // Where this view and the app's mark reach for the same corner —
              // no rail at all, or a Mac window where the buttons have pushed
              // the mark off the rail's column — hold what the mark overhangs
              // by, so the back button lands beside it rather than under it.
              leadingInset: HomeRailLogo.headerReserveOf(context, railWidth: HomeNavigationRail.widthFor(context, expanded: _navExpandedSetting)),
            ),
          ),
        ),
        // Same arrangement as Settings above, for the Logs destination —
        // including its claim on the system back press, and the same reason
        // for only claiming it while Logs is the live destination.
        ListenableBuilder(
          listenable: _logsSlide,
          builder: (context, child) => _logsSlide.isDismissed
              ? const SizedBox.shrink()
              : PopScope(
                  canPop: !_showingLogs,
                  onPopInvokedWithResult: (didPop, _) {
                    if (!didPop && _showingLogs) unawaited(homeRail.leaveTo(HomeDestination.operations));
                  },
                  child: SlideTransition(position: _logsOffset, child: child!),
                ),
          child: besideRail(LogsView(services: widget.services)),
        ),
        // Same arrangement again, for the Chasing destination — except that
        // once shown it is only ever HIDDEN (see [_chaseMounted]): offstage,
        // its tickers stopped, and out of the focus tree, so nothing it holds
        // takes a key while another destination is up.
        ListenableBuilder(
          listenable: _chaseSlide,
          builder: (context, child) {
            if (!_chaseMounted) return const SizedBox.shrink();
            final hidden = _chaseSlide.isDismissed;
            return Offstage(
              offstage: hidden,
              child: TickerMode(
                enabled: !hidden,
                child: ExcludeFocus(
                  excluding: hidden,
                  child: PopScope(
                    canPop: !_showingChase,
                    onPopInvokedWithResult: (didPop, _) {
                      if (!didPop && _showingChase) unawaited(homeRail.leaveTo(HomeDestination.operations));
                    },
                    child: SlideTransition(position: _chaseOffset, child: child!),
                  ),
                ),
              ),
            );
          },
          child: besideRail(ChaseView(services: widget.services, visible: _showingChase)),
        ),
        // Same arrangement as Chasing, for the Maps destination.
        ListenableBuilder(
          listenable: _mapsSlide,
          builder: (context, child) {
            if (!_mapsMounted) return const SizedBox.shrink();
            final hidden = _mapsSlide.isDismissed;
            return Offstage(
              offstage: hidden,
              child: TickerMode(
                enabled: !hidden,
                child: ExcludeFocus(
                  excluding: hidden,
                  child: PopScope(
                    canPop: !_showingMaps,
                    onPopInvokedWithResult: (didPop, _) {
                      if (!didPop && _showingMaps) unawaited(homeRail.leaveTo(HomeDestination.operations));
                    },
                    child: SlideTransition(position: _mapsOffset, child: child!),
                  ),
                ),
              ),
            );
          },
          child: besideRail(MapsView(services: widget.services, visible: _showingMaps)),
        ),
      ],
    );
  }

  /// The dev label's own style — shared by the label and by the measurement
  /// that decides whether the header still fits on one line.
  TextStyle _headerDevLabelStyle(ThemeData theme) =>
      TextStyle(fontSize: 13, fontStyle: FontStyle.italic, color: (theme.appBarTheme.foregroundColor ?? theme.colorScheme.onPrimary).withValues(alpha: 0.8));

  /// What sits beside (or under) the product name, or null when there is
  /// nothing: a free-form dev label (DEV_LABEL) marking which dev
  /// build/session is running, which TAKES THE EDITION BADGE'S PLACE rather
  /// than stacking with it, and is absent in release builds.
  ///
  /// [inline] is the one-line header, where the badge has a product name
  /// beside it to align against: there it is carried as a baseline-aligned
  /// WidgetSpan, because a Row aligned by baseline puts a child that reports
  /// none at the TOP of the row and an SvgPicture reports none. A
  /// placeholder's baseline is its own bottom edge, so the wordmark lands ON
  /// the baseline and then takes its optical nudge below it. Stacked, there
  /// is no baseline to meet and the art goes in raw.
  Widget? _headerTrailing(ThemeData theme, {required bool inline}) {
    if (devLabel.isNotEmpty) return Text(devLabel, style: _headerDevLabelStyle(theme));
    if (ham2kEditionBadgeAsset == null) return null;
    // Zero-offset shadows read as a glow: black for Next, white for Dev.
    final art = Ham2kEditionBadge(height: _headerEditionBadgeHeight, shadows: ham2kHeaderEditionBadgeShadows);
    if (!inline) return art;
    return Text.rich(
      WidgetSpan(
        alignment: PlaceholderAlignment.baseline,
        baseline: TextBaseline.alphabetic,
        // Translated, not padded: padding would grow the placeholder, and its
        // baseline is its height, so the art would ride back up by whatever
        // was added.
        child: Transform.translate(offset: const Offset(0, headerEditionBadgeBaselineNudge), child: art),
      ),
      // A minimal line box, so the enclosing paragraph adds no leading of its
      // own around the art.
      style: const TextStyle(fontSize: 1, height: 1),
    );
  }

  Widget _homeScaffold(BuildContext context, ThemeData theme, bool isTwoPane) {
    final railPresent = HomeNavigationRail.presentIn(context, expanded: _navExpandedSetting);
    return Scaffold(
      // Full height behind the on-screen keyboard so each pane paints its own
      // bottom — the Quick Lookup bar's teal on the left, the branding on the
      // right — and a two-pane split reflects through. Each keeps its content
      // above the keyboard itself (HomeQuickLookup / BrandingPane).
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        flexibleSpace: windowHeaderGestureArea(),
        // Room for the mark, which the WINDOW draws over this corner (see
        // [HomeRailLogo]) — only for the part of it the rail is not already
        // holding open, which is nothing at all in the common case.
        leadingWidth: HomeRailLogo.headerReserveOf(context, railWidth: HomeNavigationRail.widthFor(context, expanded: _navExpandedSetting)),
        // Matches the inset of an operation row's text
        // (`PaneSafeArea.symmetricOf(context, horizontal: 16)` in
        // [_OperationRow]), so the product name and the callsigns below it
        // start on the same vertical line rather than a few pixels apart.
        titleSpacing: Space.xl,
        leading: const SizedBox.shrink(),
        // "Power Logger" / "Portable Logger" is the in-app main-screen
        // title — independent of the OS-level app name ("Ham2K Logger" on
        // desktop, "HaLo" on mobile; see macos/Runner/Configs/AppInfo.xcconfig,
        // ios/Runner/Info.plist, android's AndroidManifest.xml).
        title: LayoutBuilder(
          builder: (context, constraints) {
            // Measured against the space the TITLE actually gets, not the
            // window's width: the leading reserve for the rail's mark and the
            // trailing actions both vary, so a window-width breakpoint would
            // stack a header that had room and keep one that did not.
            final trailingWidth = devLabel.isNotEmpty
                ? textWidth(context, devLabel, _headerDevLabelStyle(theme))
                // The art's own width needs the SVG loaded; this estimate is
                // enough to choose a layout with.
                : _headerEditionBadgeHeight * ham2kEditionBadgeWidthRatio;
            // Height is checked as well as width, and the AppBar's own bar is
            // the budget: the title is laid out with an INFINITE height and
            // its box then clamped to the toolbar with the child centred in
            // it, so a title taller than the bar spills over the header
            // silently — no overflow stripes, no thrown error, release too.
            // When two lines will not fit, the one-line row is the safer
            // answer: it is only ever as tall as its tallest child, and gives
            // up width through `shrinkToFit` instead.
            final trailingHeight = devLabel.isNotEmpty
                ? spansHeight(context, [TextSpan(text: devLabel)], _headerDevLabelStyle(theme))
                : _headerEditionBadgeHeight;
            final stackedHeight = spansHeight(context, [TextSpan(text: ham2kProductName)], const TextStyle()) + _headerStackGap + trailingHeight;
            final stacked =
                _headerTrailing(theme, inline: true) != null &&
                constraints.maxWidth.isFinite &&
                textWidth(context, ham2kProductName, const TextStyle()) + Space.md + trailingWidth > constraints.maxWidth &&
                stackedHeight <= (theme.appBarTheme.toolbarHeight ?? kToolbarHeight);

            if (stacked) {
              // Two lines, name over badge. No baseline to align to here, so
              // the badge goes in raw — no WidgetSpan, no optical nudge, both
              // of which exist only to place it against the name beside it.
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  shrinkToFitText(Text(ham2kProductName)),
                  const SizedBox(height: _headerStackGap),
                  shrinkToFit(_headerTrailing(theme, inline: false)!),
                ],
              );
            }

            return Row(
              mainAxisSize: MainAxisSize.min,
              // The trailing slot carries one of two things, and they want
              // different alignments. The edition wordmark goes on the product
              // name's BASELINE (plus its nudge) — bottom-aligning would drop
              // it by the name's whole descent. The dev label keeps the
              // box-bottom alignment it has always had: baseline-aligning
              // would lift it by the difference of the two descents, and it
              // reads right where it is. `shrinkToFitText` rebuilds its Text
              // at the smaller size, so its baseline stays true; `shrinkToFit`
              // is a FittedBox, which forwards its child's baseline UNSCALED —
              // exact at scale 1, and the header stacks before the trailing
              // slot is ever squeezed, which is what keeps it there.
              crossAxisAlignment: devLabel.isNotEmpty ? CrossAxisAlignment.end : CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                // The product name gets priority over the edition badge/dev
                // label when the header is too narrow to fit both at full size
                // — a 3:1 flex split shrinks the trailing group
                // first and further, rather than shrinking both equally.
                Flexible(flex: 3, child: shrinkToFitText(Text(ham2kProductName))),
                if (_headerTrailing(theme, inline: true) case final trailing?) ...[const SizedBox(width: Space.md), Flexible(child: shrinkToFit(trailing))],
              ],
            );
          },
        ),
        actions: [
          // The settings cog, for the one arrangement with no rail to put it
          // in. Two ways to the same screen, one of them a permanent fixture
          // of the other's chrome, is how an operator learns to distrust
          // both — so it goes away as the rail arrives, fading AND closing up
          // in step with it rather than leaving a hole where it stood.
          TweenAnimationBuilder<double>(
            tween: Tween<double>(end: railPresent ? 0 : 1),
            duration: layoutAnimationDuration,
            curve: layoutAnimationCurve,
            builder: (context, t, child) => t == 0
                ? const SizedBox.shrink()
                : ClipRect(
                    child: Align(
                      alignment: Alignment.centerRight,
                      widthFactor: t,
                      child: Opacity(opacity: t, child: child),
                    ),
                  ),
            child: IconButton(
              // Named, because on this arrangement it is the ONLY way into
              // Settings and the app shows no hover tooltips
              // (docs/design/user-interface.md) — an icon button's accessible
              // name is the only place it says what it is.
              icon: Icon(MdiIcons.cogOutline, semanticLabel: context.t.settings.title),
              mouseCursor: SystemMouseCursors.click,
              onPressed: () => homeRail.destination = HomeDestination.settings,
            ),
          ),
          // The railless header is a phone's, with the product name and the
          // cog already in it: the profile name and the way into layout
          // editing wait for the rail, which is one tap on the logo away.
          if (railPresent && !layoutSheetOpen) HeaderProfileLabel(settings: widget.services.settings),
          // The VIEW's own layout options, and the only route to Restore
          // Defaults — without it an operator who rearranges Home into
          // something they dislike, or drops a pane, has no way back to the
          // arrangement it ships with. Null unless editing.
          ?viewOptionsButton(context, editing: layoutEditing),
          // `layoutEditing` keeps them through a rail toggled away MID-EDIT:
          // once editing these are Save and Discard, and hiding them with the
          // rail would leave the edit with no way to end.
          if (railPresent || layoutEditing) ...layoutHeaderControls(context),
          const SizedBox(width: Space.md),
          windowsCaptionSpacer(context),
        ],
      ),
      // Quick Lookup UNDER the layout and inside this view, full width beside
      // the rail's own Settings cap: it is the home layer's chrome, so an
      // operation covers it by covering the window and Settings slides over it
      // without either being told to hide it. The notice band and the numbers
      // row are the window's, below this view entirely (see [HomeRailShell]).
      // The safe area wraps BOTH rows, not just the panes: Quick Lookup reads
      // its own horizontal inset from this ancestor, and outside it a cutout
      // lands on the lookup field's magnifier and the first characters typed
      // — on a landscape phone with no rail, which is the shipped default
      // there and the one arrangement where this view really does touch that
      // edge.
      body: PaneSafeArea.root(
        context,
        // Real device safe-area insets (notch, home indicator) bubble in from
        // here; PaneSafeArea's own divider-clearance role composes with it
        // further down.
        //
        // Except the LEFT one WHERE THERE IS A RAIL: the rail touches that
        // edge and takes the cutout by widening itself, so the panes never
        // reach it and republishing it here would indent every operation row
        // and the lookup field by a cutout nothing is avoiding. With no rail
        // this view does touch that edge, and has to take the cutout itself or
        // a notch lands on the list.
        left: railPresent ? 0 : null,
        child: Column(
          children: [
            Expanded(
              // A dock at every width. The tree names no widths — it is the
              // same splits and weights wherever it is drawn, so ONE of them
              // drawn at 360 logical pixels would give a two-thirds list and a
              // 120px branding column. Hence two arrangements rather than one
              // that reflows: narrow ships as the list alone, which is what a
              // phone drew before this view had a narrow arrangement at all.
              // Quick Lookup is below either of them, as chrome.
              child: withViewOverrides(buildDock(children: _panes(context, theme), extraChildren: sharedDashboardPanes)),
            ),
            // Pointer-down rather than a gesture, exactly as the operations
            // pane does it: this only OBSERVES, so it neither competes with
            // the field's own taps nor changes hit testing. Quick Lookup is
            // chrome rather than a pane, but it is still one of the two things
            // the home screen offers, and telemetry.md counts it.
            Listener(
              onPointerDown: (_) => _panels.used('quick_lookup'),
              child: HomeQuickLookup(services: widget.services),
            ),
          ],
        ),
      ),
    );
  }

  Map<String, Widget> _panes(BuildContext context, ThemeData theme) => {
    HomeView.operationsPanelId: KeyedSubtree(key: _operationsPaneKey, child: _operationsPane(context, theme)),
    HomeView.versionPanelId: const BrandingPane(),
  };

  /// [_operationsList], taking a dropped QSON file while Developer Mode is on.
  ///
  /// Only while the list is what shows: Logs, Chasing and the rest slide over
  /// this pane rather than replacing it, and a drop reaches every target
  /// under the point.
  Widget _operationsPane(BuildContext context, ThemeData theme) {
    return ListenableBuilder(
      listenable: Listenable.merge([widget.services.settings, homeRail]),
      builder: (context, child) => QsonDropTarget(
        services: widget.services,
        enabled: widget.services.settings.developerMode && homeRail.destination == HomeDestination.operations,
        child: child!,
      ),
      child: _operationsList(context, theme),
    );
  }

  /// The operation list with the New Operation FAB over it — one pane, because
  /// the button creates what the list holds and an operator who moved the list
  /// elsewhere would otherwise leave its button behind.
  Widget _operationsList(BuildContext context, ThemeData theme) {
    return NotificationListener<ScrollNotification>(
      onNotification: (ScrollNotification notification) {
        _setFabExtended(notification.metrics.pixels <= 10);
        return false;
      },
      child: Stack(
        children: [
          Positioned.fill(
            child: StreamBuilder<List<Operation>>(
              stream: _operations(),
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
                // Pointer-down rather than a gesture: this only
                // OBSERVES, so it neither competes with the rows'
                // own taps nor changes hit testing.
                return Listener(
                  onPointerDown: (_) => _panels.used('operations'),
                  child: OperationListPanel(
                    services: widget.services,
                    // `snapshot.hasData` distinguishes "the stream
                    // hasn't emitted its first snapshot yet" from "it
                    // emitted an empty list" — collapsing both into
                    // `snapshot.data ?? []` would leave
                    // OperationListPanel guessing (via a fixed
                    // delay) how long "still loading" might last.
                    loading: !snapshot.hasData,
                    operations: snapshot.data ?? const <Operation>[],
                  ),
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
                        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 6, offset: const Offset(0, 3))],
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: () => _newOperation(context),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: Space.xl),
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
                                        padding: const EdgeInsets.only(left: Space.md),
                                        child: Text(
                                          context.t.home.newOperation,
                                          maxLines: 1,
                                          softWrap: false,
                                          style: theme.textTheme.labelLarge?.copyWith(color: theme.colorScheme.onPrimary, fontWeight: FontWeight.bold),
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
                  final newOperationsOpened = widget.services.settings.onboardingShownCount(OnboardingFlows.newOperation);
                  final needsNudge = _nudgeArmed && newOperationsOpened < _newOperationNudgeThreshold;
                  return needsNudge ? _NewOperationNudge(child: fab) : fab;
                },
              ),
            ),
          ),
        ],
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
    // (same trap as PulsingGpsPin in operation_location_pin.dart) — settle
    // at rest under test instead of animating.
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

/// The gap between the header's two lines when it stacks.
const double _headerStackGap = 2;

/// The height the header's edition wordmark is drawn at.
const double _headerEditionBadgeHeight = 15;

/// How far the header's edition wordmark sits BELOW the product name's
/// baseline. All-caps art with a flat bottom edge reads high when that edge
/// lands exactly on a baseline that lowercase descenders hang under, so it
/// takes a small optical drop. Named because the header test asserts the
/// badge lands here, not merely somewhere near the baseline.
const double headerEditionBadgeBaselineNudge = 2;

class HomeQuickLookup extends StatefulWidget {
  final HaLoServices services;

  const HomeQuickLookup({super.key, required this.services});

  /// This bar's RESTING height — the field and its padding, before a lookup
  /// line or a command's answer grows it upward.
  ///
  /// Exact rather than an estimate: the field is held to one chrome row below,
  /// so this is the height, and two other things are built to it. The window's
  /// chrome budget reserves it, since the bar is always on screen on the home
  /// layer and a budget blind to it hands the notice and the footer room Home
  /// has already spent. And the rail's Settings cap is this tall, so the two
  /// read as one row across the foot of the window — the cap does NOT follow
  /// the bar when it grows, which is the one direction they may differ.
  static double heightOf(BuildContext context) => LayoutDensity.chromeHeightOf(context) + Space.md * 2;

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

  /// Whether an Enter is still being resolved — see [_submit].
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _engine = CommandEngine(
      services: widget.services,
      // The home screen has no open operation, so operation-scoped commands
      // (SEED, NOTE, SPOT) answer with their own error here.
      operationContext: () => null,
      runAction: (action, params) => runCommandAction(widget.services, action, params, context),
      // HomeView stays mounted under every pushed route, so being alive
      // says nothing about being on screen.
      canShowResponse: () => mounted && (ModalRoute.of(context)?.isCurrent ?? false),
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
      isMobilePlatform && widget.services.settings.showNumbersRow && _focusNode.hasFocus && virtualKeyboardIsUp(context);

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

  /// Enter: run whatever is typed, and — only when nothing ran and the engine
  /// had nothing to say about why — open the full Call Info for the callsign
  /// that was looked up.
  ///
  /// The command wins outright. A callsign that is also a command word must
  /// keep running as a command, and a command that refused (an error on the
  /// message line) has already answered the Enter; opening a panel over either
  /// would bury the answer.
  Future<void> _submit() async {
    // A second Enter while the first is still in `interpretCommand` gets
    // `false` back from the engine's own re-entrancy guard, which is not
    // "nothing ran" — without this, key auto-repeat stacks a Call Info modal
    // on top of another one, and the operator dismisses the same panel twice.
    if (_submitting) return;
    _submitting = true;
    try {
      // Read BEFORE submitting. Enter on this bar clears the field, which
      // resets the lookup state on the way through `_onTextChanged` — so by
      // the time the panel is opened there is nothing left to open it with.
      final info = _engine.callInfo;
      final executed = await _engine.submit();
      // `isError`, not `message != null`: the message line also carries a
      // previous command's confirmation, which `_onTextChanged` deliberately
      // holds until this keystroke's interpretation answers. Reading that as
      // "already answered" would eat an Enter typed inside the window.
      if (!mounted || executed || _engine.isError) return;
      if (info != null) await _openCallInfo(info);
    } finally {
      _submitting = false;
    }
  }

  /// Escape empties the bar, wherever the operator got to — a half-typed
  /// callsign, a command mid-parameter, or an answer still on the line.
  /// Clearing the controller runs the engine's own text handler, so the lookup
  /// state and the message go with it.
  void _clearField() {
    if (_controller.text.isEmpty) return;
    _controller.clear();
  }

  /// The full Call Info panel — the same one the Call Info pane and the ⌘K
  /// dialog render, so what Enter opens here is not a second, thinner view of
  /// the same callsign.
  Future<void> _openCallInfo(CallInfoData info) => showModalPane<void>(
    context,
    title: info.call,
    closeLabel: context.t.common.close,
    // The panel is a ListView and scrolls itself; wrapped in the pane's own
    // scroll view it would sit in unbounded height and lay out blank.
    scrollable: false,
    builder: (context) =>
        CallInfoPanel(operation: operationForCallInfo(widget.services), services: widget.services, call: info.call, guess: info.guess, lookups: info.lookups),
  );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final callInfo = _engine.callInfo;

    final commandMessage = _engine.message;
    // A guess is what the summary draws from; without one there is nothing to
    // paint but the icon and a blank line. Enter still opens the panel, which
    // has the QSO history to show even when no callbook answered.
    final hasSummary = callInfo?.guess != null;
    final hasContent = commandMessage != null || hasSummary;

    // The Home Scaffold doesn't resize for the keyboard, so this bar
    // reserves the bottom safe area itself below the field (and the numbers
    // row, when shown), and its Material fills that strip so the teal forms
    // the home-indicator strip. NOT the keyboard: `StatusBarOverlay` reserves
    // that for the whole app so the status footer rides above it instead of
    // hiding, which means the space this bar is given already ends above the
    // keyboard. And nothing at all while the keyboard is up, since it covers
    // the home indicator: the strip the overlay is already holding back IS
    // that space.
    //
    // Nothing either while the status footer is drawn: it paints over that
    // same strip and holds it with a `SafeArea` of its own. The shell takes
    // the inset out of the MediaQuery this reads whenever that is so (see
    // `HomeRailShell.bottomInsetHeldByChrome`), so this follows it from there
    // rather than deciding for itself.
    //
    // The keyboard question goes to the raw view, not MediaQuery — the overlay
    // consumes that inset on the way down precisely so no route reserves it
    // twice, which also means MediaQuery reports 0 here in both states and
    // could not tell them apart.
    final mq = MediaQuery.of(context);
    final view = View.of(context);
    final keyboardUp = view.viewInsets.bottom > 0;
    final bottomReserve = keyboardUp ? 0.0 : mq.padding.bottom;
    _syncNumbersRow(context, theme);

    return CallbackShortcuts(
      bindings: {const SingleActivator(LogicalKeyboardKey.escape): _clearField},
      child: Material(
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
                          if (_engine.isError) ...[Icon(MdiIcons.alertCircle, size: 16, color: theme.colorScheme.onPrimary), const SizedBox(width: Space.md)],
                          Expanded(
                            child: MarkdownBody(
                              data: commandMessage,
                              styleSheet: withEmojiFallback(
                                MarkdownStyleSheet.fromTheme(theme).copyWith(
                                  p: theme.textTheme.bodyLarge?.copyWith(
                                    color: _engine.isConfirmation ? theme.colorScheme.onPrimary : theme.colorScheme.onPrimary.withValues(alpha: 0.85),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    // The very widget the logging panel's info area is, so a
                    // callsign reads the same in both places. No distance line:
                    // Home has no operation, so there is no location to measure
                    // from, and no scoring keys for the same reason — see
                    // `CommandEngine.lookupLocationLine`.
                    if (commandMessage == null && hasSummary)
                      InkWell(
                        onTap: () => _openCallInfo(callInfo),
                        child: CallInfoSummary(
                          data: callInfo!,
                          locationLine: _engine.lookupLocationLine,
                          workedBeforeLabel: (times) => workedBeforeLabel(context, times),
                          foregroundColor: theme.colorScheme.onPrimary,
                          iconColor: theme.colorScheme.onPrimary,
                          linkColor: theme.colorScheme.onPrimary,
                          onOpenLink: openExternalUrl,
                        ),
                      ),
                  ],
                ),
              ),
            Padding(
              padding: PaneSafeArea.symmetricOf(context, horizontal: 16, vertical: 8),
              // One chrome row exactly, rather than whatever a dense
              // `InputDecoration` and a prefix icon happen to measure. [heightOf]
              // is what the rail's Settings cap is built to and what the window's
              // chrome budget reserves, and both are wrong the moment this bar
              // is a few pixels off it — a cap that does not line up with the bar
              // beside it reads as one of them being misaligned.
              child: SizedBox(
                height: LayoutDensity.chromeHeightOf(context),
                // A callsign field that keeps focus after Enter — see
                // keyboard_dismiss.dart.
                child: TapToDismissEmptyField(
                  focusNode: _focusNode,
                  controller: _controller,
                  child: TextField(
                    selectAllOnFocus: false,
                    controller: _controller,
                    focusNode: _focusNode,
                    style: haloMonoStyle(context, fontSize: 15),
                    // The formatters own casing, not the keyboard: a soft keyboard's
                    // capitalization is fixed when the input connection opens and is not
                    // re-sent on rebuild, so a mode chosen here could never follow the
                    // text turning from a callsign into a command mid-typing.
                    textCapitalization: TextCapitalization.none,
                    inputFormatters: commandFieldFormatters,
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
                    onEditingComplete: _submit,
                  ),
                ),
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
      ),
    );
  }
}
