// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The MaterialApp: theme, locale and density for the whole window, the
// keyboard shortcuts that belong to no one screen, and the overlay gates
// stacked over the home view.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:halo_core/halo_core.dart' show DevLog;
import 'package:halo_widgets/halo_widgets.dart';

import '../command_dialog.dart';
import '../command_engine.dart' show CommandTextOutcome, runCommandText;
import '../home_view.dart';
import '../tester_overlay.dart';
import '../../config/dev_bridge.dart';

import '../../services/command_actions.dart';
import '../../services/settings_service.dart';
import '../../services/status_bar_service.dart';
import '../../services/window_chrome_service.dart';
import 'package:halo_i18n/halo_i18n.dart';

import '../../config/navigation.dart';
import '../../services/halo_services.dart';
import 'home_rail_state.dart';
import 'onboarding_gate.dart';
import 'extension_upgrade_gate.dart';
import 'release_overlay_gate.dart';
import 'status_bar_overlay.dart';
import 'tester_overlay_gate.dart';

class HaLoApp extends StatefulWidget {
  final HaLoServices services;

  const HaLoApp({super.key, required this.services});

  @override
  State<HaLoApp> createState() => _HaLoAppState();
}

class _HaLoAppState extends State<HaLoApp> {
  // Held as a field (not rebuilt per frame) so its route count survives
  // MaterialApp rebuilds; drives `modalBarrierIsVisible` for the window-chrome
  // mask. See navigatorObservers below.
  final _modalBarrierObserver = ModalBarrierRouteObserver();

  /// Whether the ⌘K command dialog is currently up, so a second ⌘K closes it
  /// instead of opening another one over it.
  bool _commandDialogOpen = false;

  // iOS never delivers ⌘-letter chords to HardwareKeyboard below — UIKit's
  // key-command discovery intercepts them first — so AppDelegate.swift
  // registers native UIKeyCommands for the same combos and forwards them
  // here instead.
  static const _keyCommandChannel = MethodChannel('ham2k/key_commands');

  // The channel only holds one handler at a time, so whichever State set it
  // last has to be the only one that clears it — otherwise an older
  // instance's dispose() can null out a newer instance's handler. Same
  // identity-check shape as the DevBridge guard in dispose() below.
  static _HaLoAppState? _keyCommandHandlerOwner;

  @override
  void initState() {
    super.initState();
    widget.services.keyBindingsService;
    HardwareKeyboard.instance.addHandler(_handleKeyEvent);
    _keyCommandHandlerOwner = this;
    _keyCommandChannel.setMethodCallHandler(_handleNativeKeyCommand);
    if (DevBridge.instance.installed) {
      DevBridge.instance.openCommandBarHandler = _openCommandDialog;
      DevBridge.instance.closeCommandBarHandler = _closeCommandDialog;
    }
  }

  @override
  void dispose() {
    _densityMessageTimer?.cancel();
    _commandBlockedTimer?.cancel();
    HardwareKeyboard.instance.removeHandler(_handleKeyEvent);
    if (identical(_keyCommandHandlerOwner, this)) {
      _keyCommandChannel.setMethodCallHandler(null);
      _keyCommandHandlerOwner = null;
    }
    if (DevBridge.instance.openCommandBarHandler == _openCommandDialog) {
      DevBridge.instance.openCommandBarHandler = null;
      DevBridge.instance.closeCommandBarHandler = null;
    }
    super.dispose();
  }

  /// One `run` call per native UIKeyCommand in AppDelegate.swift: a command
  /// id or bound command text sent by [KeyBindingsService], or one of the
  /// names AppDelegate.swift's own list sends.
  Future<void> _handleNativeKeyCommand(MethodCall call) async {
    if (call.method != 'run' || keyChordRecording.value) return;
    final id = switch (call.arguments as String) {
      'commandDialog' => 'app.commandDialog',
      'themeToggle' => 'app.toggleTheme',
      'localeToggle' => 'app.toggleLanguage',
      'zoomIn' => 'app.fontScaleUp',
      'zoomOut' => 'app.fontScaleDown',
      'zoomReset' => 'app.fontScaleReset',
      final id => id,
    };
    if (id.startsWith(textCommandPrefix)) {
      unawaited(_runCommandText(id.substring(textCommandPrefix.length)));
    } else {
      _runAppCommand(id);
    }
  }

  /// The window height the density ladder actually sees: the real height
  /// divided by the UI scale.
  ///
  /// `LayoutDensityScope` sits INSIDE `UiScale` and so reads an already-
  /// divided `MediaQuery` (docs/design/ui-scaling.md rule 4). This handler's
  /// context is above that wrapper, where the height is still the raw window,
  /// so the division has to be redone here — without it a zoomed-in operator
  /// would step from a density they aren't actually looking at.
  double get _densityLadderHeight => MediaQuery.sizeOf(context).height / widget.services.settings.fontScale.scaleFactor;

  void _stepDensity({required bool denser}) {
    final settings = widget.services.settings;
    final next = settings.densityPreference.stepped(height: _densityLadderHeight, denser: denser);
    if (next == null) {
      _announceDensity(settings.densityPreference, atLimit: true);
      return;
    }
    settings.setDensityPreference(next);
    _announceDensity(next);
  }

  Timer? _densityMessageTimer;
  Timer? _commandBlockedTimer;
  static const _commandBlockedKey = 'commandDialog:blocked';
  static const _densityMessageKey = 'layoutDensity';

  /// Names the density the operator just landed on, in the status bar.
  ///
  /// Not decoration: the shortcut can legitimately change the stored
  /// preference without changing the layout — a roomier pick on a window too
  /// short for it is stored but clamped by [DensityPreference.resolve]'s
  /// ceiling — and a key that appears to do nothing reads as broken. The
  /// message is the only place that difference is visible.
  void _announceDensity(DensityPreference preference, {bool atLimit = false}) {
    final effective = preference.resolve(_densityLadderHeight);
    final settingLabel = context.t['settings.layoutDensityOpts.${preference.name}'] as String;
    final effectiveLabel = context.t['settings.layoutDensityOpts.${effective.name}'] as String;

    // The SETTING leads, always: the shortcut's job is to move the setting,
    // and on Auto — or when the ceiling clamps a pick — the density in force
    // is not the same thing. Naming only one of the two leaves the operator
    // unable to tell which they just changed.
    final detail = switch (preference) {
      _ when preference != DensityPreference.auto && preference.name != effective.name => context.t.settings.layoutDensityClamped(effective: effectiveLabel),
      _ when atLimit => context.t.settings.layoutDensityAtLimit,
      DensityPreference.auto => effectiveLabel,
      _ => null,
    };
    final text = detail == null ? settingLabel : '$settingLabel — $detail';

    widget.services.statusBar.setMessage(key: _densityMessageKey, icon: 'arrow-collapse-vertical', title: context.t.settings.layoutDensity, text: text);
    _densityMessageTimer?.cancel();
    _densityMessageTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) widget.services.statusBar.clear(_densityMessageKey);
    });
  }

  /// Opens the ⌘K dialog, unless it's already up. Shared by the shortcut and
  /// the dev bridge (which exists because synthetic modifier combos can't
  /// reach the Flutter canvas — see DevBridge).
  void _openCommandDialog({String? initialText}) {
    if (_commandDialogOpen) return;
    // Not over a top modal pane, such as the operation setup sheet: the
    // dialog's Go home pops straight past one, and such a pane commits its
    // edit only when it closes itself.
    final statusBar = widget.services.statusBar;
    if (TopModalPaneRoute.anyOpen) {
      // Gone again after a moment, and as soon as the dialog opens: notices
      // otherwise stay until dismissed, and this one is only true while the
      // pane is up.
      statusBar.showNotice(key: _commandBlockedKey, icon: 'keyboard-off', text: t.commandDialog.blockedByPane, persist: false);
      _commandBlockedTimer?.cancel();
      _commandBlockedTimer = Timer(StatusBarService.completedDismissDelay, () => statusBar.dismissNotice(_commandBlockedKey));
      unawaited(SystemSound.play(SystemSoundType.alert));
      // The dev bridge's caller otherwise sees only a dialog that never opened.
      DevLog.instance.log('commandDialog', {'blocked': 'topModalPane'});
      return;
    }
    _commandBlockedTimer?.cancel();
    statusBar.dismissNotice(_commandBlockedKey);
    final context = navigatorKey.currentContext;
    if (context == null) return;
    _commandDialogOpen = true;
    unawaited(showCommandDialog(context, widget.services, initialText: initialText).whenComplete(() => _commandDialogOpen = false));
  }

  void _closeCommandDialog() {
    if (!_commandDialogOpen) return;
    navigatorKey.currentState?.pop();
  }

  /// A second ⌘K while the dialog is open closes it rather than stacking a
  /// second copy on top of the first.
  void _toggleCommandDialog() {
    if (_commandDialogOpen) {
      _closeCommandDialog();
    } else {
      _openCommandDialog();
    }
  }

  void _toggleTheme() {
    final settings = widget.services.settings;
    settings.setThemeMode(toggledThemeMode(settings.themeMode, WidgetsBinding.instance.platformDispatcher.platformBrightness));
  }

  void _toggleLocale() {
    final settings = widget.services.settings;
    final newLocale = LocaleSettings.currentLocale == AppLocale.es ? 'en' : 'es';
    settings.setLocale(newLocale);
    applyLocaleSetting(newLocale);
    widget.services.extensions.invalidateHookContext();
  }

  bool _handleKeyEvent(KeyEvent event) {
    // The tester overlay owns the keyboard while covering the app. Its own
    // Focus node can't block this handler (HardwareKeyboard dispatches
    // ahead of the focus tree), and acting here would fire chords into
    // chrome the overlay hides — ⌘K would open the command dialog invisibly
    // beneath it and steal its focus.
    if (testerOverlayCovering.value || keyChordRecording.value) return false;
    if (event is! KeyDownEvent) return false;

    final bindings = keyBindings.value;
    for (final id in _appCommands) {
      if (bindings.match(id, event) case final chord?) return !bindings.yieldsToField(id, chord, event) && _runAppCommand(id);
    }
    if (bindings.textCommandFor(event) case (:final text, :final chord)) {
      if (bindings.yieldsToField(textCommandId(text), chord, event)) return false;
      unawaited(_runCommandText(text));
      return true;
    }
    return false;
  }

  /// The commands [_runAppCommand] runs, in the order a key is tried
  /// against them.
  static final _appCommands = [
    for (final spec in keyCommandSpecs)
      if (spec.id.startsWith('app.')) spec.id,
  ];

  /// Runs the app-wide command [id]; false for an id that is not one.
  bool _runAppCommand(String id) {
    final settings = widget.services.settings;
    switch (id) {
      case 'app.commandDialog':
        _toggleCommandDialog();
      case 'app.toggleTheme':
        _toggleTheme();
      case 'app.toggleLanguage':
        _toggleLocale();
      // Layout Density sits on the Font Scale keys one modifier up by
      // default: the two are the same question — how much fits on screen —
      // so an operator reaching for one is already thinking about the other.
      case 'app.densityDenser' || 'app.densityLooser':
        _stepDensity(denser: id == 'app.densityDenser');
      case 'app.densityAuto':
        // Back to Auto, not to Normal: Auto is the default, and "reset" here
        // means "stop overriding" rather than "pick the middle rung".
        settings.setDensityPreference(DensityPreference.auto);
        _announceDensity(DensityPreference.auto);
      case 'app.fontScaleUp':
        unawaited(settings.increaseFontScale());
      case 'app.fontScaleDown':
        unawaited(settings.decreaseFontScale());
      case 'app.fontScaleReset':
        unawaited(settings.setFontScale(FontScale.normal));
      default:
        return false;
    }
    return true;
  }

  /// Runs command text a key is bound to; a command in it still waiting for
  /// its text opens the command dialog with that command typed.
  Future<void> _runCommandText(String text) async {
    final services = widget.services;
    final (:outcome, text: stoppedAt) = await runCommandText(
      services,
      text,
      (action, params) => runCommandAction(services, action, params, navigatorKey.currentContext),
    );
    if (outcome == CommandTextOutcome.needsParams && mounted) _openCommandDialog(initialText: '$stoppedAt ');
  }

  /// The template editors' sample preview. A method, not a closure in
  /// [build]: its tear-offs are equal across rebuilds, and a new closure on
  /// every settings change would read to each preview on screen as a new
  /// renderer, rendering it again.
  Future<String?> _previewTemplate(String template, Map<String, dynamic> sample) => widget.services.extensions.renderTemplate(
    template,
    operation: (sample['operation'] as Map?)?.cast<String, dynamic>(),
    qso: (sample['qso'] as Map?)?.cast<String, dynamic>(),
    log: (sample['log'] as Map?)?.cast<String, dynamic>(),
    qsoCount: 25,
  );

  @override
  Widget build(BuildContext context) {
    // Rebuilds when Settings changes themeMode or fontScale, so toggling it in the
    // Settings screen takes effect immediately rather than needing a restart.
    return AnimatedBuilder(
      animation: widget.services.settings,
      builder: (context, _) => MaterialApp(
        // Android task-switcher card title / web tab title — matches each
        // platform's own OS-level app name (see isWindowedPlatform's other
        // uses: macos/Runner/Configs/AppInfo.xcconfig "Ham2K Logger",
        // android's AndroidManifest.xml label "HaLo").
        title: isWindowedPlatform ? 'Ham2K Logger' : 'HaLo',
        navigatorKey: navigatorKey,
        navigatorObservers: [_modalBarrierObserver, homeRouteObserver, homeRailRouteObserver],
        locale: TranslationProvider.of(context).locale.formattingLocale,
        supportedLocales: formattingLocales,
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        theme: buildHaLoTheme(Brightness.light),
        darkTheme: buildHaLoTheme(Brightness.dark),
        themeMode: widget.services.settings.themeMode,
        debugShowCheckedModeBanner: false,
        home: HomeView(services: widget.services),
        builder: (context, child) {
          if (child == null) return const SizedBox.shrink();
          child = TemplateEditorScope(preview: _previewTemplate, child: child);
          final scale = widget.services.settings.fontScale.scaleFactor;

          // One knob scales the WHOLE interface (UiScale, halo_widgets) — not
          // just text and icons but every layout dimension, uniformly, so
          // ordinary widget code stays scale-agnostic and proportions never
          // drift. The base theme's dimensions are unchanged; UiScale does the
          // scaling.
          //
          // The native macOS traffic lights float over the AppBar and stay a
          // fixed system size, so they center in the on-screen header
          // height = the base AppBar height scaled by UiScale below (see
          // WindowChromeService; deduped, so calling it every build is fine).
          // The header height is density-resolved, so both the snap and the
          // native traffic-light report happen in `_LayoutDensityFromWindow`
          // below — the first place the rung is known.
          //
          // The window's resize floor is the S-size layout width plus room for
          // the native window controls that float over the header (traffic
          // lights / caption buttons), so neither the S content nor the
          // controls is ever squeezed (desktopMinimumWindowSize; layouts.md).
          WindowChromeService.reportMinimumSize(desktopMinimumWindowSize(scale));

          // Full-screen toggles change the traffic-light clearance the
          // headers reserve (macOSTrafficLightClearance → 0 while the
          // buttons live in the system's auto-hiding overlay). The scope is
          // the delivery mechanism — see MacOSFullScreenScope's own comment.
          // On chromeless Windows/Linux the caption buttons are
          // Flutter-drawn and float over every route's header from here —
          // the same "window chrome above app content" role the native
          // traffic lights play on macOS. Headers reserve trailing room via
          // windowsCaptionClearance. On macOS the native traffic lights
          // already float there; we overlay a same-colored mask beneath them
          // (MacOSTrafficLightMask) so header content animating through the
          // top-left corner doesn't flash out around the buttons.
          Widget content = child;
          if (isWindowsChromelessWindow || isLinuxChromelessWindow) {
            content = Stack(
              children: [
                content,
                const Positioned(top: 0, right: 0, child: WindowsCaptionButtons()),
              ],
            );
          } else if (isMacOSChromelessWindow) {
            content = Stack(
              children: [
                content,
                const Positioned(top: 0, left: 0, child: MacOSTrafficLightMask()),
              ],
            );
          }

          // The app shows NO hover labels (docs/design/user-interface.md).
          // Our own buttons simply don't set one, but Flutter's built-ins
          // (BackButton, CloseButton, PopupMenuButton, Chip's delete icon)
          // supply their own from MaterialLocalizations and take no parameter
          // to turn it off — so the rule is enforced here, for the whole app
          // at once, instead of being re-litigated per widget. Accessible
          // names live on `Icon(semanticLabel:)`, which this does not touch.
          return TooltipVisibility(
            visible: false,
            child: ValueListenableBuilder<bool>(
              valueListenable: macOSWindowIsFullScreen,
              builder: (context, isFullScreen, _) => MacOSFullScreenScope(
                isFullScreen: isFullScreen,
                child: UiScale(
                  scale: scale,
                  // INSIDE UiScale, deliberately: the density ladder reads
                  // the divided height, so a large font scale genuinely
                  // fits less and reaches for a tighter layout sooner —
                  // the same bargain ShirtSize makes on width
                  // (docs/design/ui-scaling.md rule 4). Reading the real
                  // window height here would leave the operator who zoomed
                  // in with a sparse layout that no longer fits.
                  child: _LayoutDensityFromWindow(
                    settings: widget.services.settings,
                    scale: scale,
                    // Outermost of the startup gates: the tester overlay
                    // paints above even the onboarding flow — a tester's
                    // fresh install gets the caution warning before
                    // anything else.
                    child: TesterOverlayGate(
                      services: widget.services,
                      child: OnboardingGate(
                        services: widget.services,
                        child: ReleaseOverlayGate(
                          services: widget.services,
                          // Innermost of the startup gates. Its offer is
                          // a dialog on the Navigator below, so the release
                          // notes (an overlay above it) paint over the
                          // offer on a launch that has both; the offer
                          // waits underneath and returns next launch if
                          // it is dismissed unseen.
                          child: ExtensionUpgradeGate(
                            services: widget.services,
                            child: StatusBarOverlay(services: widget.services, child: content),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Publishes the app-wide [LayoutDensity], resolved from the window's height
/// and the operator's [DensityPreference].
///
/// A separate widget rather than an expression inline in the builder so it
/// rebuilds on a window resize without dragging the whole `MaterialApp`
/// builder with it: `MediaQuery.sizeOf` is read HERE, so only this subtree is
/// marked dirty when the height changes.
///
/// Reads `MediaQuery.sizeOf(context).height`, which below `UiScale` is the
/// divided height — and which does NOT shrink when the on-screen keyboard
/// opens (`StatusBarOverlay` consumes that inset on the way down; see
/// home_view.dart's note). That is the intended behaviour: the whole UI
/// reflowing every time the keyboard appears would be worse than the tight
/// fit it would relieve, and it is the same call `onboarding_overlay.dart`
/// makes for its own compact threshold.
class _LayoutDensityFromWindow extends StatefulWidget {
  final SettingsService settings;
  final double scale;
  final Widget child;

  const _LayoutDensityFromWindow({required this.settings, required this.scale, required this.child});

  @override
  State<_LayoutDensityFromWindow> createState() => _LayoutDensityFromWindowState();
}

class _LayoutDensityFromWindowState extends State<_LayoutDensityFromWindow> {
  LayoutDensity _density = LayoutDensity.normal;

  /// Seeded from the ladder's own `normal` rung rather than Flutter's
  /// `kToolbarHeight` (56): the two disagree, and stating the default twice is
  /// how they drift. Never painted — `didChangeDependencies` resolves before
  /// the first build — but it is what any earlier read would get.
  double _toolbarHeight = LayoutMetrics.normal.chromeHeight;

  /// The derived theme, rebuilt only when the height it derives from moves.
  ///
  /// `ThemeData.copyWith` copies around a hundred fields, and this widget
  /// depends on `MediaQuery.sizeOf` — so without the cache a window drag
  /// pays for a full copy, and a full `ThemeData ==` in the inherited theme's
  /// updateShouldNotify, on every frame. The height only changes at a band
  /// boundary, so almost every one of those frames is answered from here.
  ThemeData? _derivedTheme;
  ThemeData? _derivedFrom;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _resolve();
  }

  @override
  void didUpdateWidget(covariant _LayoutDensityFromWindow oldWidget) {
    super.didUpdateWidget(oldWidget);
    // The preference lives in a service, not in the widget, so a settings
    // change arrives as a rebuild from the AnimatedBuilder above rather than
    // as a dependency change.
    _resolve();
  }

  /// Resolves the density and the header height, and tells the native window
  /// chrome about the latter.
  ///
  /// Deliberately NOT in `build`: `reportTitleBarHeight` crosses a platform
  /// channel, and `build` has to stay free of side effects — the framework
  /// may call it speculatively or more than once per frame, and this widget
  /// depends on `MediaQuery.sizeOf`, so it rebuilds on every resize frame.
  void _resolve() {
    final density = widget.settings.densityPreference.resolve(MediaQuery.sizeOf(context).height);

    // The header's bottom edge is a color boundary against the body, so it has
    // to land on the device pixel grid: inside UiScale one logical pixel is
    // `scale × devicePixelRatio` device pixels, and 48 × 0.85 × 2.0 = 81.6 is
    // not a whole one — the leftover antialiases into the content below as a
    // hairline seam. Snapped ONCE here and pushed into the theme, so every
    // AppBar in the app inherits it and the seam can't come back view by view.
    //
    // The DENSITY-RESOLVED value is what gets snapped, not the base constant:
    // snapping 48 and swapping in a shorter header downstream would put the
    // seam straight back at every non-1.0 font scale.
    final toolbarHeight = PixelGrid.of(context).snap(density.metrics.chromeHeight);

    // Plain assignment, no setState: both callers are immediately followed
    // by a build, and marking dirty from didChangeDependencies would only
    // schedule a second one.
    if (toolbarHeight != _toolbarHeight) _derivedTheme = null;
    _density = density;
    _toolbarHeight = toolbarHeight;

    // The same snapped height the headers actually render at, scaled back to
    // real pixels, so the fixed-size native traffic lights stay centered in
    // it. Reported from here rather than above UiScale because the density is
    // not known up there and the value would be stale the moment the operator
    // changed it. Deduped inside the service.
    WindowChromeService.reportTitleBarHeight(toolbarHeight * widget.scale);
  }

  @override
  Widget build(BuildContext context) {
    final base = Theme.of(context);
    if (_derivedTheme == null || !identical(base, _derivedFrom)) {
      _derivedFrom = base;
      _derivedTheme = base.copyWith(appBarTheme: base.appBarTheme.copyWith(toolbarHeight: _toolbarHeight));
    }
    return LayoutDensityScope(
      density: _density,
      child: Theme(data: _derivedTheme!, child: widget.child),
    );
  }
}
