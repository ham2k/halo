// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The bottom chrome: status bar, notices, footer, number keys and the
// keyboard accessory, sized together by BottomChromeBudget so the logging
// fields always keep their room above the keyboard.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:halo_widgets/halo_widgets.dart';

import '../home_navigation_rail.dart';
import '../home_view.dart';

import '../../services/connectivity_service.dart';
import '../offline_indicator.dart';
import '../peers_dialog.dart';
import '../station_config_dialog.dart';
import '../station_panel.dart' show equipmentStatusLabel;
import '../../services/bottom_chrome_squeezed.dart';

import '../../services/error_reporting_service.dart';
import '../../services/cat/cat_service.dart';
import '../../services/status_bar_service.dart';
import 'package:halo_i18n/halo_i18n.dart';

import '../../config/navigation.dart';
import '../../services/halo_services.dart';
import 'bottom_chrome_budget.dart';
import 'home_rail_state.dart';

/// Paints the modal barrier over one piece of bottom chrome, and takes its
/// pointers, while a dimming route is up.
///
/// The chrome is drawn OUTSIDE the Navigator — it owns the bottom of the
/// window across every route — so a dialog's own barrier stops at the routes
/// and leaves a lit, pressable footer beside a dimmed window, where a tap
/// opens a second dialog behind the first. Modal means modal.
///
/// [modalBarrierIsVisible] is the app's existing answer to "is something
/// dimming the window?" (it also drives the macOS traffic-light mask), so this
/// and the window chrome cannot disagree about it, and
/// [modalBarrierIsDismissible] carries the top route's own answer, so a dialog
/// that refuses barrier dismissal is not dismissed from down here either. The
/// pop goes through [navigatorKey] because this is drawn above the Navigator
/// and has no Navigator of its own to ask.
///
/// **Never a [ModalBarrier] here**, tempting as it is — the widget whose job
/// this is brings a [BlockSemantics], which drops everything painted BEFORE
/// it, and [HomeRailShell] draws the chrome after the routes. Measured: with
/// one in this slot, opening a dialog left the window with two semantics nodes
/// and none of the dialog's own. So the barrier is hand-rolled, and it takes
/// the chrome out of the semantics tree by covering ITSELF ([ExcludeSemantics]
/// around the child) rather than by blocking what it does not own. That
/// exclusion is not tidiness: with accessibility on, Flutter web hangs a DOM
/// element off every node and that element takes the click before any hit test
/// runs, so a scrim that only absorbed pointers would be clicked through into
/// the bar underneath.
class _ChromeScrim extends StatelessWidget {
  final Widget child;

  const _ChromeScrim({required this.child});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([modalBarrierIsVisible, modalBarrierIsDismissible]),
      builder: (context, child) {
        final scrimmed = modalBarrierIsVisible.value;
        return Stack(
          children: [
            ExcludeSemantics(excluding: scrimmed, child: child!),
            if (scrimmed)
              Positioned.fill(
                child: ExcludeSemantics(
                  child: GestureDetector(
                    // Opaque with no callback still absorbs, which is what a
                    // non-dismissible barrier has to do: the chrome under it
                    // must not take the tap either way.
                    behavior: HitTestBehavior.opaque,
                    onTap: modalBarrierIsDismissible.value ? () => navigatorKey.currentState?.maybePop() : null,
                    child: ColoredBox(color: haloBarrierColor(context)),
                  ),
                ),
              ),
          ],
        );
      },
      child: child,
    );
  }
}

@visibleForTesting
class StatusBarOverlay extends StatefulWidget {
  final HaLoServices services;
  final Widget child;

  const StatusBarOverlay({super.key, required this.services, required this.child});

  @override
  State<StatusBarOverlay> createState() => _StatusBarOverlayState();
}

class _StatusBarOverlayState extends State<StatusBarOverlay> {
  /// What the last frame's budget gave way on, so the console gets one line
  /// per transition rather than one per frame — this rebuilds on every
  /// progress tick of a sync.
  String? _lastSqueeze;

  /// How long a message stays up over a virtual keyboard before the footer
  /// slides away again.
  ///
  /// The band is permanent everywhere else, but over a keyboard it is taking
  /// its height from the field being typed into, so there it earns its place
  /// only while it has something new to say. The item is NOT cleared — it is
  /// still in `StatusBarService` and comes straight back with the keyboard,
  /// so nothing is lost by having read it late.
  static const _keyboardLinger = Duration(seconds: 5);

  Timer? _lingerTimer;
  bool _lingering = false;

  /// Whether the footer's message list is open. Held HERE rather than inside
  /// [StatusBarFooter] because an open list is modal: it puts a scrim over the
  /// rest of the window, and the widget that draws that scrim is a sibling of
  /// the footer, not a descendant of it. (The permanent statuses open a menu
  /// of their own, which brings its own modality and needs none of this.)
  bool _footerExpanded = false;

  /// The item list as it was when the linger last restarted. Compared rather
  /// than counted: a progress bar refreshing on one key is activity that
  /// should hold the bar up, and so is a message replaced in place, neither
  /// of which changes the count.
  String? _itemSignature;

  @override
  void initState() {
    super.initState();
    widget.services.statusBar.addListener(_onStatusBarChanged);
    _itemSignature = _signatureOf(widget.services.statusBar);
  }

  @override
  void dispose() {
    widget.services.statusBar.removeListener(_onStatusBarChanged);
    _lingerTimer?.cancel();
    super.dispose();
  }

  late final bool _gatoEnabled = widget.services.settings.experimentEnabled('gato') /* stored key, see experiments.yaml */;

  /// The permanent statuses, in the order they take the trailing edge of the
  /// bar.
  ///
  /// Built here rather than posted by whoever owns each state: this is the
  /// only place that can see them all, and their ORDER is a property of the
  /// bar. Connectivity comes first because it is the one that answers "why is
  /// nothing updating?".
  List<StatusBarPermaData> _permaStatuses(BuildContext context, bool offline) {
    return [
      StatusBarPermaData(
        key: 'connectivity',
        icon: offline ? MdiIcons.cloudOff : MdiIcons.cloudCheck,
        text: offline ? context.t.offline.statusOffline : context.t.offline.statusOnline,
        onTap: () => showOfflineDetail(
          navigatorKey: navigatorKey,
          onRetry: widget.services.syncEngine.retryNow,
          nextAttemptAt: () => widget.services.syncEngine.nextAttemptAt,
        ),
      ),
      // Only once there is something to count, and only under the experiment
      // that publishes the Peers panel this opens: an operator who has never
      // linked a device is not told "0 devices" — the feature is one they do
      // not use — and a status whose action lands on a panel Settings is
      // hiding is worse than no status.
      if (widget.services.settings.experimentEnabled('p2p') /* stored key, see experiments.yaml */ )
        for (final linked in [widget.services.peerService.linkedDeviceIds])
          if (linked.isNotEmpty)
            for (final connected in [linked.where(widget.services.peerService.hasSession).length])
              StatusBarPermaData(
                key: 'peers',
                icon: MdiIcons.lanConnect,
                // The badge is the LIVE count and the line is both numbers: at a
                // glance the question is "is my other device reachable right
                // now", and the total is what makes a 0 mean something.
                badge: '$connected',
                // Nothing reaching anything is a true state worth showing — a
                // peer dropping off is exactly when the operator looks — but it
                // is not one to draw at full strength beside a live one.
                muted: connected == 0,
                text: context.t.settings.peers.statusPerma(connected: connected, linked: linked.length),
                onTap: () {
                  final navigatorContext = navigatorKey.currentContext;
                  if (navigatorContext == null) {
                    // Two gestures deep — the menu opened, an entry chosen — so
                    // a silent no-op is the operator's action disappearing.
                    debugPrint('[status-bar] no navigator for the peers status');
                    return;
                  }
                  showPeersDialog(navigatorContext, widget.services);
                },
              ),
      if (_gatoEnabled) ...[
        // Whatever drives the VFO, local rig or peer's: the bar is where
        // "is it talking to me" is answered, and a peer pick going blank
        // here is that question left unanswered for the one radio the
        // operator is actually working through.
        for (final name in [widget.services.radio1Name])
          if (name != null)
            StatusBarPermaData(
              key: 'radio1',
              icon: MdiIcons.cat,
              // Name AND state, in the Station panel's own words
              // ([equipmentStatusLabel]): the name alone answers "which
              // rig", which is the question the operator already knows the
              // answer to — "is it talking to me" is the one they open the
              // bar for.
              //
              // A peer's rig has no EquipmentState to label, and the
              // question is the same one anyway: whether it is there.
              text: switch (widget.services.cat.radio1) {
                LocalRadio(:final uuid) => '$name: ${equipmentStatusLabel(context, widget.services.cat.stateFor(uuid))}',
                _ => '$name: ${widget.services.radio1IsLive ? t.settings.station.statusConnected : t.settings.station.peerRadioNotAvailable}',
              },
              // The Radio control's own quick-access pane, not the full
              // Station Configuration page — the same one tapping the
              // logging row's Radio chip opens, so the two ways in do not
              // land somewhere different.
              onTap: () {
                final navigatorContext = navigatorKey.currentContext;
                if (navigatorContext == null) {
                  // Two gestures deep — the menu opened, an entry chosen —
                  // so a silent no-op here is the operator's action
                  // disappearing. It means the chrome outlived the
                  // navigator, which is worth knowing about.
                  debugPrint('[status-bar] no navigator for the radio status');
                  return;
                }
                showStationConfigDialog(navigatorContext, widget.services);
              },
            ),
      ],
    ];
  }

  String _signatureOf(StatusBarService statusBar) => statusBar.items.map((item) => '${item.key}@${item.updatedAt.microsecondsSinceEpoch}').join(',');

  /// Restarts the linger whenever the ITEMS changed. The service also
  /// notifies for notices, which have their own stack and must not hold the
  /// footer up.
  void _onStatusBarChanged() {
    final signature = _signatureOf(widget.services.statusBar);
    if (signature == _itemSignature) return;
    _itemSignature = signature;
    _lingerTimer?.cancel();
    _lingerTimer = Timer(_keyboardLinger, () {
      if (mounted) setState(() => _lingering = false);
    });
    if (_lingering) return;
    _lingering = true;
    // Marking this element dirty during a build is refused by the framework —
    // and the service DOES notify during one (see `DockHost`'s notice
    // plumbing). Deferring a frame there rather than relying on the
    // `ListenableBuilder` below to rebuild for us: it listens to the same
    // service, but only a notification that reaches it AFTER this one shows
    // the flag, and a message posted from inside a build that has already
    // passed this element would simply never appear. Same shape as
    // `HomeRailState._set`.
    if (SchedulerBinding.instance.schedulerPhase == SchedulerPhase.persistentCallbacks) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() {});
      });
      return;
    }
    setState(() {});
  }

  /// Puts the message list away when this frame cannot show it — the band
  /// gone under a keyboard, the window too short to seat a footer, or the
  /// items down to the one that shows in full collapsed anyway.
  ///
  /// CLEARED, not masked. A flag left set behind a band that has gone away
  /// re-opens the list the moment the band returns — a scrim over the window
  /// the operator did not ask for and has no memory of asking for — and no
  /// gesture can correct it in the meantime, because the widget that would
  /// report the change is not on screen to be tapped.
  ///
  /// Deferred a frame because this is decided inside `build`.
  void _closeListIfUnopenable(bool listOpen, bool showFooter) {
    if (!_footerExpanded || (listOpen && showFooter)) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _footerExpanded) setState(() => _footerExpanded = false);
    });
  }

  /// Says out loud that the window could not seat all of the bottom chrome.
  ///
  /// Nothing else would: the pieces are simply absent, at the one moment the
  /// operator is looking at a field rather than at the chrome, and the setting
  /// that publishes the numbers row still reads ON. Reported from a post-frame
  /// callback because this is decided inside `build`, and reporting there is a
  /// side effect during layout.
  void _reportSqueeze(BottomChromeBudget bottom) {
    final gave = [if (!bottom.showFooter) 'the status footer', if (!bottom.showNumbersRow) 'the numbers row', if (!bottom.seatsNotice) 'a readable notice'];
    final detail = gave.isEmpty ? null : gave.join(' and ');
    if (detail == _lastSqueeze) return;
    _lastSqueeze = detail;
    if (detail == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ErrorReportingService.report(BottomChromeSqueezed('no room above the keyboard for $detail'), StackTrace.current, context: 'bottom-chrome');
    });
  }

  @override
  Widget build(BuildContext context) {
    // The offline state is a Stream rather than a Listenable, and it belongs
    // OUTSIDE the merged listenable below for a reason the budget makes
    // load-bearing: the indicator opens the footer on its own, so a change to
    // it changes how the bottom of the window is divided up, and a stale read
    // here would hand the notice room the footer has already taken.
    return StreamBuilder<bool>(
      stream: ConnectivityService.offlineChanges,
      initialData: ConnectivityService.isOffline,
      builder: (context, offlineSnapshot) => _buildChrome(context, offlineSnapshot.data ?? false),
    );
  }

  Widget _buildChrome(BuildContext context, bool offline) {
    return ListenableBuilder(
      // All three, because the budget below has to see the numbers row and the
      // home layer: whether a row is published and whether Quick Lookup is on
      // screen both change how much room the notice and the footer get, and
      // listening only to the status bar would leave that stale.
      // `cat` only when Station Configuration is on: it is a `late final` that
      // builds a whole CatService the first time it is touched, and an
      // operator without the experiment must not pay for one just so this can
      // ask it for a radio it cannot have.
      listenable: Listenable.merge([
        widget.services.statusBar,
        widget.services.keyboardAccessory,
        homeRail,
        // The open list's scrim stands down while a dialog is up — see it.
        modalBarrierIsVisible,
        // Both halves of the peer status: the linked devices it counts against
        // (this service caches them) and the live sessions the badge counts,
        // which change on their own as a link comes up or drops.
        widget.services.peerService,
        if (_gatoEnabled) widget.services.cat,
        // A peer's rig going away or coming back is this notifier's news
        // alone — CatService hears nothing of it, so the radio row would
        // keep saying "Not available" about a rig that is back.
        if (_gatoEnabled) widget.services.peerRemoteRadios,
      ]),
      builder: (context, _) {
        final statusBar = widget.services.statusBar;
        final items = [
          for (final item in statusBar.items)
            StatusBarItemData(
              key: item.key,
              icon: item.icon,
              title: item.title,
              text: item.text,
              progressValue: item.progressValue,
              isIndeterminateProgress: item.isIndeterminateProgress,
            ),
        ];
        final notices = [
          for (final notice in statusBar.activeNotices)
            StatusBarNoticeData(
              key: notice.key,
              icon: notice.icon,
              title: notice.title,
              text: notice.text,
              actions: [for (final action in notice.actions) StatusBarActionData(label: action.label, onTap: action.onTap)],
              createdAt: notice.createdAt,
            ),
        ];

        // This widget owns the bottom of the window while the on-screen
        // keyboard is up — it both RESERVES the keyboard's height and CONSUMES
        // the inset, and the two have to go together.
        //
        // Reserving: this Column's bottom edge is the WINDOW's
        // bottom edge and anything placed there is behind the keyboard. The
        // footer is chrome the operator needs precisely while typing (a
        // sync's progress,
        // a command's output), so instead the keyboard's height is held back
        // below the footer and the footer rides above it. The strip is painted
        // in the app-bar colour — the one the footer and the mobile numbers row
        // already use — so the chrome reads as continuing behind the keyboard
        // instead of flashing a gap during its animation.
        //
        // Consuming: everything below this point must NOT reserve the keyboard
        // again. `removeViewInsets` is what makes that true by construction
        // rather than by asking each descendant to remember. Without it the
        // inset is still in the MediaQuery the routes read, so every stock
        // `Scaffold` (only Home and Operation opt out of resizing) shrinks its
        // own body a second time, and anything padding by `viewInsets.bottom`
        // double-pads — measured as a form squeezed to a third of its height
        // with a keyboard-tall blank band above the keyboard.
        //
        // The two consumers that legitimately still need to know the keyboard
        // is up read the raw `FlutterView` instead (`virtualKeyboardIsUp`,
        // `LoggingControls._bottomReserve`), which this cannot and should not
        // hide from them.
        //
        // Not gated on platform: a desktop window simply reports no bottom
        // inset, while mobile WEB does report one (and the Home Scaffold opts
        // out of resizing there too, so nothing else would hold it back). An
        // iPad's hardware-keyboard accessory bar reports a small one, and
        // reserving for that is right as well — it obscures the bottom exactly
        // like a keyboard does, just less of it.
        final keyboardInset = MediaQuery.viewInsetsOf(context).bottom;

        // How much of the window the chrome below the app may take, divided
        // between the two pieces that can grow. If everything down here
        // sized itself against the WHOLE window independently — the notice at
        // 40% of it, the expanded footer at another 40%, the numbers row at
        // whatever it is — their sum could exceed the strip they share and
        // the Column would overflow, crushing the app to nothing. Capping
        // one piece just moves the overflow to the next; the
        // sum is the thing that has to be bounded, so it is worked out once,
        // here, by the only widget that can see all of them.
        // Over a virtual keyboard the footer is transient: it opens for a new
        // message and slides away once it has been read (see
        // [_keyboardLinger]). Everywhere else — every desktop window, and a
        // phone with the keyboard down — the band is permanent, so the bottom
        // edge of the app does not move as messages come and go.
        //
        // Hiding it is done by handing the widget an EMPTY list rather than by
        // dropping the widget: the footer animates its own collapse, and a
        // removed widget would just vanish.
        final keyboardUp = keyboardInset > 0;
        final footerHidden = keyboardUp && !_lingering;
        // The footer refuses to expand a list of one — a single message shows
        // in full collapsed — so the scrim has to answer to the same rule or
        // it outlives what it covers: dismiss one of two open messages and the
        // band snaps shut while a full-window barrier stays painted over a
        // window with nothing modal in it.
        final listOpen = _footerExpanded && !footerHidden && items.length > 1;
        final footerItems = footerHidden ? const <StatusBarItemData>[] : items;
        // The perma icons go with the items: over a keyboard the whole band
        // is borrowed space, and a row of icons is no more entitled to it
        // than a message is.
        final perma = footerHidden ? const <StatusBarPermaData>[] : _permaStatuses(context, offline);

        final accessory = widget.services.keyboardAccessory.value;
        final hasStatusItems = !keyboardUp || footerItems.isNotEmpty || perma.isNotEmpty;
        final bottom = BottomChromeBudget.of(
          windowHeight: MediaQuery.sizeOf(context).height,
          keyboardInset: keyboardInset,
          hasNumbersRow: accessory != null,
          hasStatusItems: hasStatusItems,
          numbersRowHeight: NumberKeys.heightOf(context),
          // The band's own safe area is part of what a drawn footer takes:
          // it holds the home indicator for the whole window (see
          // [footerHoldsBottomInset]), so a charge of the bar alone leaves
          // the notice and the expanded list a strip of an iPhone that is
          // already spent. Zero with the keyboard up, which is the only state
          // where this term decides whether the footer is drawn at all.
          footerHeight: StatusBarFooter.collapsedHeightOf(context) + MediaQuery.paddingOf(context).bottom,
          // Quick Lookup is chrome for the home layer and nothing else, so it
          // is charged exactly while that layer is showing — a view that owns
          // the window replaces it, and charging for it there would take the
          // room from the notice for a bar that is not on screen. Home draws
          // it itself; what is reserved here is the room it needs.
          //
          // The bar alone, with no safe area added: the home indicator's strip
          // belongs to whoever is drawn over it, and that is the footer
          // whenever there IS a strip to hold (see [footerHoldsBottomInset] —
          // it is the keyboard that takes the strip otherwise, and then the
          // safe area is zero anyway).
          homeChromeHeight: homeRail.homeChromeShowing ? HomeQuickLookup.heightOf(context) : 0,
          // One readable notice, floored the way the footer floors its own
          // expanded cap: the notice is the surface ErrorPolicy raises to, and
          // a share-of-what-is-left that works out to a few points renders the
          // error as a sliver nobody can read and nothing logs.
          noticeFloor: NoticeStack.minHeightOf(context),
        );
        _reportSqueeze(bottom);
        _closeListIfUnopenable(listOpen, bottom.showFooter);

        // A drawn footer paints over the bottom safe area and holds it with a
        // `SafeArea` of its own, so nothing ABOVE it may reserve that strip a
        // second time — a view that does leaves a band of its own background
        // between its last row and the footer. Whether the footer is DRAWN is
        // the whole condition: the widget holds the strip from outside its own
        // switcher, so an empty band still covers it and the two cannot
        // disagree for a frame. Passed to the shell rather than applied here
        // because the rail is the shell's child, not the routes': Quick Lookup
        // and the rail's Settings cap sit side by side across the foot of the
        // home layer and have to answer to this together.
        final footerHoldsBottomInset = bottom.showFooter;

        // The rail runs the full height beside this whole strip, so a status
        // item shortens the views and never the navigation.
        return MediaQuery.removeViewInsets(
          context: context,
          removeBottom: true,
          child: HomeRailShell(
            services: widget.services,
            routes: widget.child,
            bottomInsetHeldByChrome: footerHoldsBottomInset,
            // An open list is modal: the operator opened it to read it, and a
            // tap anywhere else means "put it away" rather than whatever that
            // spot would otherwise do. Painted, not invisible — a window that
            // silently eats one tap is worse than one that says why.
            // Nothing while a dialog is up. This layer is drawn ABOVE the
            // routes — dialogs included — so a list left holding it would
            // paint over the very dialog its own row just opened. The dialog
            // is the modal thing at that point, its own barrier covers the
            // window, and `_ChromeScrim` covers the bar; the list's scrim
            // comes back when it closes.
            scrim: listOpen && bottom.showFooter && !modalBarrierIsVisible.value
                // A real [ModalBarrier], and here it is the right widget where
                // in the chrome band it is the wrong one: the BlockSemantics
                // it brings drops what was painted BEFORE it, which inside
                // this Stack is the routes and the rail — exactly what it
                // covers — and leaves the band below untouched. That block is
                // load-bearing: with accessibility on, Flutter web hangs a DOM
                // element off every node and that element takes the click
                // before any hit test runs, so a scrim that only absorbed
                // POINTERS would be clicked straight through.
                ? ModalBarrier(color: haloBarrierColor(context), dismissible: true, onDismiss: () => setState(() => _footerExpanded = false))
                : null,
            chrome: [
              for (final piece in [
                if (notices.isNotEmpty)
                  NoticeStack(notices: notices, onDismiss: statusBar.dismissNotice, maxHeight: bottom.noticeMax, dismissLabel: context.t.common.dismiss),
                if (bottom.showFooter)
                  StatusBarFooter(
                    items: footerItems,
                    perma: perma,
                    showWhenEmpty: !keyboardUp,
                    // See [_closeListIfUnopenable]: the flag behind this is
                    // cleared rather than masked, so a list the band took away
                    // does not come back by itself when the band does.
                    expanded: listOpen,
                    onExpandedChanged: (expanded) => setState(() => _footerExpanded = expanded),
                    onDismiss: statusBar.clear,
                    maxExpandedHeight: bottom.footerMax,
                    dismissLabel: context.t.common.dismiss,
                  ),
              ])
                // Modal means modal. The chrome is drawn OUTSIDE the
                // Navigator (it owns the bottom of the window across every
                // route), so a dialog's own barrier stops at the routes and
                // leaves a lit, pressable footer beside a dimmed window —
                // where a tap opens a second dialog behind the first, or
                // dismisses a notice the operator cannot see.
                _ChromeScrim(child: piece),
            ],
            keyboard: [
              // The mobile numbers row, published by whichever field has focus
              // (KeyboardAccessoryController). Drawn HERE, below the footer and
              // directly on the keyboard: it reads as an extension of the
              // keyboard, so nothing may come between the two — and the footer
              // is status, which belongs above both. A route cannot achieve
              // that order itself, since the footer is one level up from it.
              //
              // Read straight off the controller rather than through a nested
              // builder: this whole subtree already rebuilds when it changes
              // (see the merged listenable above), and the budget must be
              // computed from the SAME value this renders — a nested builder
              // could show a row the budget above had not accounted for.
              if (accessory != null && bottom.showNumbersRow)
                NumberKeys(
                  onKey: accessory.onKey,
                  extraKey: accessory.extraKey,
                  vibrate: accessory.vibrate,
                  backgroundColor: Color(accessory.backgroundColor),
                  foregroundColor: Color(accessory.foregroundColor),
                ),
              if (keyboardInset > 0)
                SizedBox(
                  width: double.infinity,
                  height: keyboardInset,
                  child: ColoredBox(color: Theme.of(context).appBarTheme.backgroundColor ?? Theme.of(context).colorScheme.primary),
                ),
            ],
          ),
        );
      },
    );
  }
}
