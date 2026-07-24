import 'dart:async';
import 'dart:math' as math;
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
/// preview name derived from the URL (ham2k/app-halo-dist#234). Empty
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
    final dateLabel = when == null ? '' : '${_monthName(when.month)} ${when.day}';
    final subtitle = operation.refs.map((r) => r['name']).whereType<String>().join(' • ');

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
                          if (operation.title.isNotEmpty)
                            TextSpan(
                              text: ' ${operation.title}',
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

  String _monthName(int month) =>
      const ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'][month - 1];
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

class _HomeViewState extends State<HomeView> {
  bool _isFabExtended = true;

  /// Memoized: build now depends on MediaQuery.sizeOf (ShirtSize.of), so it
  /// reruns on every window-resize frame — watchAll() returns a NEW drift
  /// stream per call, and an inline `stream:` would make the StreamBuilder
  /// resubscribe (and re-run the SELECT) each of those frames.
  late final Stream<List<Operation>> _operationsStream = widget.services.operations.watchAll();

  /// The old dialog's modal barrier blocked a second tap while _newOperation
  /// was in flight; without it, a fast double-tap could create two
  /// operations before the pushed route starts absorbing pointer events.
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
      if (context.mounted) {
        // The guard stays up until the pushed route pops back to this
        // screen — the home screen remains hit-testable during the push
        // transition, so releasing right after push would reopen the
        // double-tap window the removed dialog's barrier used to close.
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
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
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
            // (issue #182) — a 3:1 flex split shrinks the trailing group
            // first and further, rather than shrinking both equally.
            Flexible(flex: 3, child: shrinkToFitText(Text(ham2kProductName))),
            if (ham2kEditionBadgeAsset != null || _devLabel.isNotEmpty) ...[
              const SizedBox(width: 10),
              Flexible(
                child: shrinkToFit(
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Edition badge (Regular has no badge).
                      if (ham2kEditionBadgeAsset != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 2),
                          // Zero-offset shadows read as a glow: black for Next, white for Dev.
                          child: Ham2kEditionBadge(height: 15, shadows: ham2kHeaderEditionBadgeShadows),
                        ),
                      // A free-form dev label (DEV_LABEL) — marks which dev build/session is running;
                      // absent in release builds.
                      if (_devLabel.isNotEmpty)
                        Text(
                          _devLabel,
                          style: TextStyle(
                            fontSize: 13,
                            fontStyle: FontStyle.italic,
                            color: (theme.appBarTheme.foregroundColor ?? theme.colorScheme.onPrimary)
                                .withValues(alpha: 0.8),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
        actions: [
          HeaderProfileLabel(settings: widget.services.settings),
          IconButton(
            tooltip: context.t.settings.title,
            icon: Icon(MdiIcons.cog),
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
        // from here (ham2k/app-halo-dist#205); PaneSafeArea's own
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
                    final pixels = notification.metrics.pixels;
                    if (pixels > 10 && _isFabExtended) {
                      setState(() {
                        _isFabExtended = false;
                      });
                    } else if (pixels <= 10 && !_isFabExtended) {
                      setState(() {
                        _isFabExtended = true;
                      });
                    }
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
                            // promise so agents can await it instead of sleeping
                            // (#239). Idempotent; only while the bridge is live.
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
                              // `snapshot.data ?? []` was what previously made
                              // OperationListPanel need to guess (via a fixed
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
                      // this Stack (ham2k/app-halo-dist#205).
                      Builder(
                        builder: (context) => Positioned(
                          // Clears the device's real bottom/right insets (home
                          // indicator, landscape cutout) so the FAB isn't drawn
                          // under them.
                          bottom: 16 + PaneSafeArea.bottomOf(context),
                          right: 16 + PaneSafeArea.rightOf(context),
                          child: AnimatedSize(
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeInOut,
                            child: Container(
                              height: 56,
                              width: _isFabExtended ? null : 56,
                              decoration: BoxDecoration(
                                color: theme.colorScheme.primaryContainer,
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
                                        Icon(MdiIcons.plus, color: theme.colorScheme.onPrimaryContainer),
                                        AnimatedSize(
                                          duration: const Duration(milliseconds: 300),
                                          curve: Curves.easeInOut,
                                          child: SizedBox(
                                            width: _isFabExtended ? null : 0,
                                            child: AnimatedOpacity(
                                              duration: const Duration(milliseconds: 300),
                                              curve: Curves.easeInOut,
                                              opacity: _isFabExtended ? 1.0 : 0.0,
                                              child: Padding(
                                                padding: const EdgeInsets.only(left: 8),
                                                child: Text(
                                                  context.t.home.newOperation,
                                                  maxLines: 1,
                                                  softWrap: false,
                                                  style: theme.textTheme.labelLarge?.copyWith(
                                                    color: theme.colorScheme.onPrimaryContainer,
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

/// The home view's right column on two-pane layouts: the operation list has
/// nothing useful to spend the extra width on, so it shows the wordmark and
/// version instead (issue #85).
class _BrandingPane extends StatelessWidget {
  const _BrandingPane();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      color: theme.colorScheme.surfaceContainerHighest,
      alignment: Alignment.center,
      // Centre the branding in the space above the keyboard (the pane extends
      // full height behind it, so the grey fills the gap); the padding is
      // inside the coloured Container, so the fill still reaches the bottom.
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
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
          const SizedBox(height: 16),
          // Just the release name, without the edition qualifier (the edition
          // is already shown by the badge SVG above) and without the build
          // detail line.
          VersionLabel(
            nameOnly: true,
            style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
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

class _HomeQuickLookupState extends State<HomeQuickLookup> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();

  String? _commandMessage;
  bool _isConfirmation = false;

  /// True while `_commandMessage` is a CommandInterpretation `error` — a
  /// recognized command that can't run here (e.g. SEED with no open
  /// operation). Rendered with an alert icon, and Enter keeps the typed
  /// input instead of executing or clearing.
  bool _isError = false;
  Map<String, dynamic>? _currentInterpretation;
  Timer? _commandDescribeDebounce;
  Timer? _executeMessageTimer;
  Timer? _lookupDebounce;

  String? _lookupFor;
  Map<String, dynamic>? _lookupResult;

  /// The last interpret() result retained for the field's space-restriction
  /// — deliberately separate from [_currentInterpretation], which resets
  /// synchronously on every keystroke (for the describe-message UI): the
  /// field's formatter must not snap back to denying spaces mid-command
  /// (ham2k/app-halo-dist#190). Same "retained interpretation" pattern as
  /// `logging_controls.dart`'s call field, scoped down to just spaces since
  /// this field otherwise accepts any character.
  Map<String, dynamic>? _retainedInterpretation;

  /// Matches text the space-denying formatter would leave untouched — see
  /// [_retainInterpretation].
  static final _noSpaceSafeText = RegExp(r'^\S*$');

  /// Folds a fresh interpret() result into [_retainedInterpretation]. A
  /// non-null result always replaces the previous one. A null result only
  /// clears it when the current text has no space the formatter would
  /// otherwise strip on the next keystroke — mirrors
  /// `logging_controls.dart`'s `_retainInterpretation`.
  void _retainInterpretation(Map<String, dynamic>? result) {
    if (result != null) {
      _retainedInterpretation = result;
    } else if (_noSpaceSafeText.hasMatch(_controller.text)) {
      _retainedInterpretation = null;
    }
  }

  /// Whether the field is mid-command free-text entry — spaces stay
  /// allowed. Two ways in, both requiring a retained command: it's still
  /// awaiting its parameters (`expectsParams`), or the text already holds a
  /// space the formatter would otherwise delete on the next keystroke.
  bool get _commandExpectsParams =>
      _retainedInterpretation != null &&
      (_retainedInterpretation!['expectsParams'] == true || !_noSpaceSafeText.hasMatch(_controller.text));

  /// Whether the retained command declared `mixedCase: true` (e.g. NOTE,
  /// whose parameter is free prose) — also keeps spaces allowed.
  bool get _commandMixedCase => _retainedInterpretation?['mixedCase'] == true;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onTextChanged);
    // The mobile numbers row shows only while this field has focus, so rebuild
    // as focus comes and goes (issue #27).
    _focusNode.addListener(_onFocusChanged);
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChanged);
    _controller.dispose();
    _focusNode.dispose();
    _commandDescribeDebounce?.cancel();
    _executeMessageTimer?.cancel();
    _lookupDebounce?.cancel();
    super.dispose();
  }

  void _onFocusChanged() {
    if (mounted) setState(() {});
  }

  /// Whether to float the mobile numbers row above the keyboard right now: the
  /// setting is on, we're on a phone/tablet, this field has focus, and a real
  /// on-screen keyboard is up. The >100px check ignores iOS's thin
  /// hardware-keyboard accessory bar (~45–55px) — matches LoggingControls'
  /// `_minKeyboardInset`. MediaQuery works here (the Home Scaffold doesn't
  /// resize, so it doesn't strip the inset), so this rebuilds on its own as
  /// the keyboard opens/closes.
  bool _shouldShowNumbersRow(MediaQueryData mq) =>
      isMobilePlatform &&
      widget.services.settings.showNumbersRow &&
      _focusNode.hasFocus &&
      mq.viewInsets.bottom > 100;

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

  void _onTextChanged() {
    final text = _controller.text.trim();

    _lookupDebounce?.cancel();
    _commandDescribeDebounce?.cancel();
    _executeMessageTimer?.cancel();
    _isConfirmation = false;
    _currentInterpretation = null;

    if (text.isEmpty) {
      setState(() {
        _lookupFor = null;
        _lookupResult = null;
        _commandMessage = null;
        _isError = false;
        _retainedInterpretation = null;
      });
      return;
    }

    setState(() {
      _commandMessage = null;
      _isError = false;
    });

    if (widget.services.extensions.ready) {
      _commandDescribeDebounce = Timer(const Duration(milliseconds: 150), () async {
        final result = await widget.services.extensions.interpretCommand(text);
        if (!mounted || _controller.text.trim() != text) return;
        setState(() {
          _currentInterpretation = result;
          _retainInterpretation(result);
          _isConfirmation = false;
          if (result != null && result['error'] is String) {
            _commandMessage = result['error'] as String;
            _isError = true;
          } else if (result != null && result['describe'] is String) {
            _commandMessage = result['describe'] as String;
            _isError = false;
          } else {
            _commandMessage = null;
            _isError = false;
          }
        });
      });
    }

    if (!looksLikeCallsign(text)) {
      setState(() {
        _lookupFor = null;
        _lookupResult = null;
      });
      return;
    }

    _lookupDebounce = Timer(const Duration(milliseconds: 300), () async {
      // No in-progress QSO/operation context on this quick-log/command bar
      // — QSO-scoped lookup hooks (e.g. POTA) simply find nothing to do.
      final result = await widget.services.extensions.lookupCall(text, qso: const {}, operation: const {});
      if (!mounted || _controller.text.trim() != text) return;
      setState(() {
        _lookupFor = text;
        _lookupResult = result;
      });
    });
  }

  Future<void> _submit() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    var interpretation = _currentInterpretation;
    if (interpretation == null) {
      interpretation = await widget.services.extensions.interpretCommand(text);
      if (!mounted || _controller.text.trim() != text) return; // stale — the field changed while awaiting
    }

    // A recognized command that can't run in this context (e.g. SEED with
    // no open operation) — present its error and keep the typed input for
    // editing; there's nothing to execute.
    if (interpretation != null && interpretation['error'] is String) {
      setState(() {
        _commandMessage = interpretation!['error'] as String;
        _isError = true;
        _isConfirmation = false;
      });
      return;
    }

    // A command still awaiting parameters (expectsParams) isn't complete —
    // leave the field as-is so the user can keep typing, rather than
    // treating it as executable (mirrors logging_controls.dart's _log()).
    if (interpretation != null && interpretation['expectsParams'] != true) {
      // The interpretation above may just be the debounce-time preview,
      // whose `commands` a hook like SEED deliberately left cheap/empty
      // (see CommandHook.interpret's `execute` doc) — re-interpret with
      // execute:true now that we're actually about to run it, so those
      // hooks generate the real commands instead of a stale preview's.
      final executable = await widget.services.extensions.interpretCommand(text, null, null, true);
      if (!mounted || _controller.text.trim() != text) return; // stale — the field changed while awaiting
      if (executable == null) return;

      // A command can also fail at execute time (mirrors _log() in
      // logging_controls.dart) — show the message and keep the typed input
      // instead of clearing the field as if it had succeeded.
      if (executable['error'] is String) {
        _executeMessageTimer?.cancel();
        setState(() {
          _commandMessage = executable['error'] as String;
          _isError = true;
          _isConfirmation = false;
        });
        return;
      }

      _controller.clear();
      _commandDescribeDebounce?.cancel();
      _executeMessageTimer?.cancel();

      final confirm = executable['confirm'];
      setState(() {
        _currentInterpretation = null;
        _retainedInterpretation = null;
        _isConfirmation = true;
        _isError = false;
        if (confirm is String) {
          _commandMessage = confirm;
          _executeMessageTimer = Timer(const Duration(seconds: 5), () {
            if (mounted) {
              setState(() {
                _commandMessage = null;
                _isConfirmation = false;
              });
            }
          });
        } else {
          _commandMessage = null;
          _isConfirmation = false;
        }
      });

      final commands = executable['commands'];
      if (commands is List) {
        await _dispatchActions(commands);
      }
    } else if (interpretation == null) {
      // Just clear search
      _controller.clear();
      setState(() {
        _lookupFor = null;
        _lookupResult = null;
        _commandMessage = null;
        _isError = false;
        _retainedInterpretation = null;
      });
    }
  }

  Future<void> _runCommandAction(String action, [Map<String, dynamic>? params]) =>
      runCommandAction(widget.services, this, action, params);

  Future<void> _dispatchActions(List<dynamic> actions) async {
    for (final action in actions) {
      if (action is! Map) continue;
      final map = action.cast<String, dynamic>();
      if (map.containsKey('updateSettings')) {
        final params = (map['updateSettings'] as Map).cast<String, dynamic>();
        if (params.containsKey('developerMode')) {
          await widget.services.settings.setDeveloperMode(params['developerMode'] as bool);
        }
      } else if (map.containsKey('syncAll')) {
        await _runCommandAction('syncAll');
      } else if (map['devNotice'] is Map) {
        await _runCommandAction('devNotice', (map['devNotice'] as Map).cast<String, dynamic>());
      } else if (map['devStatus'] is Map) {
        await _runCommandAction('devStatus', (map['devStatus'] as Map).cast<String, dynamic>());
      } else if (map['devProgress'] is Map) {
        await _runCommandAction('devProgress', (map['devProgress'] as Map).cast<String, dynamic>());
      } else if (map['devSplash'] is Map) {
        await _runCommandAction('devSplash');
      } else if (map['devOnboard'] is Map) {
        await _runCommandAction('devOnboard');
      } else if (map['reloadDataFiles'] is Map) {
        await _runCommandAction('reloadDataFiles', (map['reloadDataFiles'] as Map).cast<String, dynamic>());
      } else if (map['toggleExperiment'] is Map) {
        await _runCommandAction('toggleExperiment', (map['toggleExperiment'] as Map).cast<String, dynamic>());
      } else {
        // Nothing above recognized this action's key(s) — most likely a
        // command that's scoped to the logging panel (addQso, updateQso,
        // sendSpots, setCallField) matched here on the home screen's
        // operation-less quick search, or a new CommandAction field with no
        // matching branch here yet. Either way this must not fail silently:
        // see logging_controls.dart's own _dispatchActions and its
        // regression test for `reloadDataFiles` shipping without this
        // branch.
        debugPrint('[extensions] no dispatch branch for command action: ${map.keys}');
      }
    }
  }

  String? get _lookupLine {
    final result = _lookupResult;
    if (result == null || _lookupFor != _controller.text.trim()) return null;
    final guess = result['guess'] as Map<String, dynamic>? ?? const {};
    // A callsign note (issue #17) takes the name's slot outright rather
    // than joining it — same rule as the logging panel's _lookupLine
    // (packages/halo_widgets/lib/src/logging_controls.dart).
    final note = guess['note'] as String?;
    final parts = [
      (note != null && note.isNotEmpty) ? note : guess['name'],
      guess['location'],
      guess['country'],
      guess['grid'],
    ].whereType<String>().where((s) => s.isNotEmpty).toList();
    return parts.isEmpty ? null : parts.join(' • ');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final lookupLine = _lookupLine;

    final hasContent = _commandMessage != null || lookupLine != null;

    // The Home Scaffold no longer resizes for the keyboard, and the status
    // footer below now collapses to nothing, so this bar reserves the space
    // itself below the field (and the numbers row, when shown): the larger of
    // the keyboard inset and the bottom safe area. A MAX (not a sum) because
    // the keyboard, when up, already covers the home indicator. The bar's
    // Material fills that strip, so its teal both shows behind the keyboard and
    // forms the home-indicator strip when the keyboard is down.
    final mq = MediaQuery.of(context);
    final bottomReserve = math.max(mq.viewInsets.bottom, mq.viewPadding.bottom);
    final showNumbersRow = _shouldShowNumbersRow(mq);

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
                  if (_commandMessage != null)
                    Row(
                      children: [
                        if (_isError) ...[
                          Icon(resolveIconName('alert-circle'), size: 16, color: theme.colorScheme.onPrimary),
                          const SizedBox(width: 8),
                        ],
                        Expanded(
                          child: MarkdownBody(
                            data: _commandMessage!,
                            styleSheet: MarkdownStyleSheet.fromTheme(theme).copyWith(
                              p: theme.textTheme.bodyLarge?.copyWith(
                                color: _isConfirmation
                                    ? theme.colorScheme.onPrimary
                                    : theme.colorScheme.onPrimary.withValues(alpha: 0.85),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  if (_commandMessage == null && lookupLine != null)
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
              controller: _controller,
              focusNode: _focusNode,
              style: haloMonoStyle(context, fontSize: 15),
              textCapitalization: TextCapitalization.characters,
              inputFormatters: [
                if (isMobilePlatform) MobileDotToSlashFormatter(),
                // Spaces are only meaningful mid-command (a command's free-
                // text parameters, e.g. "NOTE hello") — otherwise they'd
                // just corrupt a callsign/command being typed
                // (ham2k/app-halo-dist#190).
                if (!_commandExpectsParams && !_commandMixedCase) FilteringTextInputFormatter.deny(RegExp(r'\s')),
                TextInputFormatter.withFunction(
                  (oldValue, newValue) => newValue.copyWith(text: newValue.text.toUpperCase()),
                ),
              ],
              decoration: InputDecoration(
                filled: true,
                fillColor: theme.colorScheme.surface,
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _controller.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () {
                          _controller.clear();
                        },
                      )
                    : null,
                hintText: context.t.home.quickLookup,
                isDense: true,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(24.0), borderSide: BorderSide.none),
              ),
              onSubmitted: (_) => _submit(),
            ),
          ),
          // The mobile numbers row (issue #27), same setting as the logging
          // panel — digits (plus one contextual "/"/".") a tap away while the
          // lookup field has focus. Sits just above the keyboard, which the
          // spacer below reserves.
          if (showNumbersRow)
            NumberKeys(
              onKey: _handleNumberKey,
              extraKey: _numbersRowExtraKey,
              vibrate: widget.services.settings.vibrateNumbersRow,
              backgroundColor: theme.appBarTheme.backgroundColor ?? theme.colorScheme.primary,
              foregroundColor: theme.appBarTheme.foregroundColor ?? theme.colorScheme.onPrimary,
            ),
          if (bottomReserve > 0) SizedBox(width: double.infinity, height: bottomReserve),
        ],
      ),
    );
  }
}
