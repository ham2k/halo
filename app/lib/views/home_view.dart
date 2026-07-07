import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:halo_core/halo_core.dart';
import 'package:halo_widgets/halo_widgets.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

import '../main.dart';
import 'operation_dialogs.dart';
import 'operation_view.dart';
import 'settings_view.dart';

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
        onTap: () => Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => OperationView(services: services, operationUuid: operation.uuid),
        )),
        onLongPress: () => confirmDeleteOperation(context, services.operations, operation),
        mouseCursor: SystemMouseCursors.click,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(
                child: Text.rich(
                  TextSpan(children: [
                    TextSpan(
                      text: operation.stationCall,
                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    if (operation.title.isNotEmpty)
                      TextSpan(
                        text: ' ${operation.title}',
                        style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                      ),
                  ]),
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
            ]),
            const SizedBox(height: 2),
            Row(children: [
              Expanded(
                child: Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
              ),
              Text(dateLabel, style: theme.textTheme.bodyMedium),
            ]),
          ]),
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

  const OperationListPanel({
    super.key,
    required this.services,
    required this.operations,
  });

  @override
  Widget build(BuildContext context) {
    if (operations.isEmpty) {
      return Container(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        child: const Center(child: Text('No operations yet. Create one to start logging.')),
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

  Future<void> _newOperation(BuildContext context) async {
    final callController = TextEditingController();
    final titleController = TextEditingController();

    final created = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('New operation'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: callController,
              autofocus: true,
              textCapitalization: TextCapitalization.characters,
              decoration: poloFieldDecoration(context, 'Station callsign'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: titleController,
              decoration: poloFieldDecoration(context, 'Title (optional)'),
              onSubmitted: (_) => Navigator.of(context).pop(true),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Create')),
        ],
      ),
    );

    if (created != true || callController.text.trim().isEmpty) return;
    final operation = await widget.services.operations.create(
      stationCall: callController.text.trim(),
      title: titleController.text.trim(),
    );
    if (context.mounted) {
      Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => OperationView(services: widget.services, operationUuid: operation.uuid),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        leadingWidth: isMacOSChromelessWindow ? 56 + macOSTrafficLightInset + macOSTrafficLightGap : null,
        leading: Padding(
          padding: EdgeInsets.fromLTRB(
            8 + (isMacOSChromelessWindow ? macOSTrafficLightInset + macOSTrafficLightGap : 0),
            8,
            8,
            8,
          ),
          child: Image.asset('assets/images/ham2k-logo.png'),
        ),
        // "Desktop Logger" / "Portable Logger" is the in-app main-screen
        // title — independent of the OS-level app name ("Ham2K Logger" on
        // desktop, "HaLo" on mobile; see macos/Runner/Configs/AppInfo.xcconfig,
        // ios/Runner/Info.plist, android's AndroidManifest.xml).
        title: Text(isWindowedPlatform ? 'Desktop Logger' : 'Portable Logger'),
        actions: [
          IconButton(
            tooltip: 'Settings',
            icon: Icon(MdiIcons.cog),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => SettingsView(services: widget.services)),
            ),
            mouseCursor: SystemMouseCursors.click,
          ),
        ],
      ),
      body: Column(
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
                      stream: widget.services.operations.watchAll(),
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
                                Icon(
                                  MdiIcons.plus,
                                  color: theme.colorScheme.onPrimaryContainer,
                                ),
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
                                          'New operation',
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
      });
      return;
    }

    setState(() {
      _commandMessage = null;
    });

    if (widget.services.extensions.ready) {
      _commandDescribeDebounce = Timer(const Duration(milliseconds: 150), () async {
        final result = await widget.services.extensions.interpretCommand(text);
        if (!mounted || _controller.text.trim() != text) return;
        setState(() {
          _currentInterpretation = result;
          _isConfirmation = false;
          if (result != null && result['describe'] is String) {
            _commandMessage = result['describe'] as String;
          } else {
            _commandMessage = null;
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
      final result = await widget.services.extensions.lookupCall(text);
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

    final interpretation = _currentInterpretation ?? await widget.services.extensions.interpretCommand(text);
    if (!mounted) return;

    if (interpretation != null) {
      _controller.clear();
      _commandDescribeDebounce?.cancel();
      _executeMessageTimer?.cancel();

      final confirm = interpretation['confirm'];
      setState(() {
        _currentInterpretation = null;
        _isConfirmation = true;
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

      final commands = interpretation['commands'];
      if (commands is List) {
        await _dispatchActions(commands);
      }
    } else {
      // Just clear search
      _controller.clear();
      setState(() {
        _lookupFor = null;
        _lookupResult = null;
        _commandMessage = null;
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
      }
    }
  }

  String? get _lookupLine {
    final result = _lookupResult;
    if (result == null || _lookupFor != _controller.text.trim()) return null;
    final location = [
      result['city'],
      result['state'],
    ].whereType<String>().where((s) => s.isNotEmpty).join(', ');
    final parts = [
      result['name'],
      location.isEmpty ? null : location,
      result['country'],
      result['grid'],
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
                    MarkdownBody(
                      data: _commandMessage!,
                      styleSheet: MarkdownStyleSheet.fromTheme(theme).copyWith(
                        p: theme.textTheme.bodyLarge?.copyWith(
                          color: _isConfirmation ? theme.colorScheme.secondary : theme.colorScheme.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  if (_commandMessage == null && lookupLine != null)
                    Row(
                      children: [
                        Icon(MdiIcons.accountSearch, size: 16, color: theme.colorScheme.primary),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            lookupLine,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.primary,
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
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: TextField(
              controller: _controller,
              focusNode: _focusNode,
              textCapitalization: TextCapitalization.characters,
              inputFormatters: [
                TextInputFormatter.withFunction(
                  (oldValue, newValue) => newValue.copyWith(
                    text: newValue.text.toUpperCase(),
                  ),
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
                hintText: 'Quick Lookup',
                isDense: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24.0),
                  borderSide: BorderSide.none,
                ),
              ),
              onSubmitted: (_) => _submit(),
            ),
          ),
        ],
      ),
    );
  }
}
