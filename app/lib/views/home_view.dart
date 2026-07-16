import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:halo_core/halo_core.dart';
import 'package:halo_widgets/halo_widgets.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

import '../main.dart';
import '../services/settings_service.dart';
import 'operation_dialogs.dart';
import 'operation_view.dart';
import 'settings_view.dart';
import 'version_label.dart';
import '../i18n/strings.g.dart';

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
        onLongPress: () => confirmDeleteOperation(context, services.operations, operation),
        mouseCursor: SystemMouseCursors.click,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
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
                            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
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
                    child: Text('${operation.qsoCount}', style: theme.textTheme.labelLarge),
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

  const OperationListPanel({super.key, required this.services, required this.operations});

  @override
  Widget build(BuildContext context) {
    if (operations.isEmpty) {
      return Container(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        child: Center(child: Text(context.t.home.emptyList)),
      );
    }
    return Container(
      // Shows through below the last row when there aren't enough
      // operations to fill the screen.
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: ListView.separated(
        itemCount: operations.length,
        separatorBuilder: (context, index) => const Divider(),
        itemBuilder: (context, index) => _OperationRow(services: services, operation: operations[index]),
      ),
    );
  }
}

class HomeView extends StatefulWidget {
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

  Future<void> _newOperation(BuildContext context) async {
    final callController = TextEditingController();
    final titleController = TextEditingController();

    final created = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.t.home.newOperation),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: callController,
              autofocus: true,
              textCapitalization: TextCapitalization.characters,
              decoration: poloFieldDecoration(context, context.t.home.stationCallsign),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: titleController,
              decoration: poloFieldDecoration(context, context.t.home.titleOptional),
              onSubmitted: (_) => Navigator.of(context).pop(true),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: Text(context.t.common.cancel)),
          FilledButton(onPressed: () => Navigator.of(context).pop(true), child: Text(context.t.common.create)),
        ],
      ),
    );

    if (created != true || callController.text.trim().isEmpty) return;
    final operation = await widget.services.operations.create(
      stationCall: callController.text.trim(),
      title: titleController.text.trim(),
    );
    if (context.mounted) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => OperationView(services: widget.services, operationUuid: operation.uuid),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        leadingWidth: isMacOSChromelessWindow ? 48 + macOSTrafficLightClearance(context) : null,
        leading: Padding(
          padding: EdgeInsets.fromLTRB(
            8 + (isMacOSChromelessWindow ? macOSTrafficLightClearance(context) : 0),
            8,
            8,
            8,
          ),
          child: SvgPicture.asset('assets/images/ham2k-wordmark.svg', width: 22, height: 22),
        ),
        // "Desktop Logger" / "Portable Logger" is the in-app main-screen
        // title — independent of the OS-level app name ("Ham2K Logger" on
        // desktop, "HaLo" on mobile; see macos/Runner/Configs/AppInfo.xcconfig,
        // ios/Runner/Info.plist, android's AndroidManifest.xml).
        title: Text(isWindowedPlatform ? context.t.home.titleDesktop : context.t.home.title),
        actions: [
          IconButton(
            tooltip: context.t.settings.title,
            icon: Icon(MdiIcons.cog),
            onPressed: () =>
                Navigator.of(context).push(MaterialPageRoute(builder: (_) => SettingsView(services: widget.services))),
            mouseCursor: SystemMouseCursors.click,
          ),
          const SizedBox(width: 8),
        ],
      ),
      // Two-pane on L+ (docs/design/layouts.md): the list column keeps the
      // ideal pane width and the branding pane takes the rest. Single-pane
      // sizes pass a null secondary so the list subtree stays mounted (and
      // keeps its scroll position) across a live resize.
      body: ResizableSplitView(
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
                          final operations = snapshot.data ?? const <Operation>[];
                          return OperationListPanel(services: widget.services, operations: operations);
                        },
                      ),
                    ),
                    Positioned(
                      bottom: 16,
                      right: 16,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                        height: 56,
                        width: _isFabExtended ? 168 : 56,
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
                                    child: Container(
                                      width: _isFabExtended ? 104 : 0,
                                      alignment: Alignment.center,
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
                  ],
                ),
              ),
            ),
            HomeQuickLookup(services: widget.services),
          ],
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
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SvgPicture.asset('assets/images/ham2k-wordmark.svg', width: 180),
          const SizedBox(height: 4),
          // The wordmark graphic already says "Ham2K", so per the branding
          // rules (docs/design/user-interface.md) only "Logger" / "Portable
          // Logger" goes below it.
          Text(
            isWindowedPlatform ? 'Logger' : 'Portable Logger',
            style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 16),
          VersionLabel(
            prefix: 'Version ',
            style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
        ],
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

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    _commandDescribeDebounce?.cancel();
    _executeMessageTimer?.cancel();
    _lookupDebounce?.cancel();
    super.dispose();
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

      _controller.clear();
      _commandDescribeDebounce?.cancel();
      _executeMessageTimer?.cancel();

      final confirm = executable['confirm'];
      setState(() {
        _currentInterpretation = null;
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
      });
    }
  }

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
        await widget.services.handleCommandAction('syncAll');
      } else if (map['devNotice'] is Map) {
        await widget.services.handleCommandAction('devNotice', (map['devNotice'] as Map).cast<String, dynamic>());
      } else if (map['devStatus'] is Map) {
        await widget.services.handleCommandAction('devStatus', (map['devStatus'] as Map).cast<String, dynamic>());
      } else if (map['devProgress'] is Map) {
        await widget.services.handleCommandAction('devProgress', (map['devProgress'] as Map).cast<String, dynamic>());
      } else if (map['reloadDataFiles'] is Map) {
        await widget.services.handleCommandAction(
          'reloadDataFiles',
          (map['reloadDataFiles'] as Map).cast<String, dynamic>(),
        );
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

    return Material(
      elevation: 8,
      color: theme.appBarTheme.backgroundColor ?? theme.colorScheme.surface,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (hasContent)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_commandMessage != null)
                    Row(
                      children: [
                        if (_isError) ...[
                          Icon(resolveIconName('alert-circle-outline'), size: 16, color: theme.colorScheme.onPrimary),
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
            padding: EdgeInsets.fromLTRB(
              16,
              8,
              16,
              MediaQuery.paddingOf(context).bottom > 8.0 ? MediaQuery.paddingOf(context).bottom : 8.0,
            ),
            child: TextField(
              controller: _controller,
              focusNode: _focusNode,
              style: haloMonoStyle(context, fontSize: 15),
              textCapitalization: TextCapitalization.characters,
              inputFormatters: [
                if (isMobilePlatform) MobileDotToSlashFormatter(),
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
        ],
      ),
    );
  }
}
