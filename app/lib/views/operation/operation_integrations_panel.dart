// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Integrations Panel: Import ADIF; the extensions' integrations
// (docs/extensions/integrations.md), each switched on or off for this
// operation on this device; and "Listen for other apps" (HALO-306) — N1MM
// and WSJT-X UDP listeners that buffer captured QSOs until the operator
// decides whether to add them to this operation.
//
// A Modal Pane like the Exports panel (operation_export_panel.dart), for the
// same reason: a picker the operator visits briefly, not a place, presenting
// as a dialog on desktop and full-screen on phone from one route.

import 'dart:async';

import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show FilteringTextInputFormatter;
import 'package:halo_core/halo_core.dart';
import 'package:halo_widgets/halo_widgets.dart';

import 'package:halo_i18n/halo_i18n.dart';
import '../../services/halo_services.dart';
import '../../services/integration_service.dart';
import '../../services/panel_service.dart' show operationHookArgs;
import '../../services/watcher_service.dart';
import '../../settings/settings_target_dialog.dart' show showSettingsForKeys;
import '../../settings/watcher_settings_rows.dart';
import '../extensions_panel.dart';
import 'adif_import_flow.dart';

/// How long a gap between two captures has to be before the operator is
/// asked whether to include what came before it — long enough that a
/// contact's own QSO-to-QSO cadence never trips it, short enough to still
/// read as "since I started the other program".
const _captureGapThreshold = Duration(minutes: 30);

Future<void> showOperationIntegrationsPanel(BuildContext context, {required HaLoServices services, required Operation operation}) {
  final t = context.t;
  return showModalPane<void>(
    context,
    title: t.operation.import.integrationsTitle,
    closeLabel: t.common.close,
    // The rows scroll; the footer stays pinned under them, and its Done is
    // the way out — so no X in the header (see haloDialogFooterBand).
    scrollable: false,
    closeButton: false,
    builder: (_) => OperationIntegrationsPanel(services: services, operation: operation),
  );
}

class OperationIntegrationsPanel extends StatefulWidget {
  final HaLoServices services;
  final Operation operation;

  const OperationIntegrationsPanel({super.key, required this.services, required this.operation});

  @override
  State<OperationIntegrationsPanel> createState() => _OperationIntegrationsPanelState();
}

class _OperationIntegrationsPanelState extends State<OperationIntegrationsPanel> {
  /// The `StreamBuilder`'s latest snapshot, kept here because [_setReceiving]
  /// needs it synchronously when the switch is flipped — waiting on the next
  /// build would race the operator's own tap.
  List<InboundCaptureRow> _pending = const [];

  /// The operation as it stands: the integrations' switches are its
  /// `localData`, which each flip writes.
  late Operation _operation = widget.operation;
  StreamSubscription<Operation?>? _operationSub;

  @override
  void initState() {
    super.initState();
    _operationSub = widget.services.operations.watchOperation(widget.operation.uuid).listen((operation) {
      if (operation == null || !mounted) return;
      final previous = _operation;
      setState(() => _operation = operation);
      // Every write to the operation lands here, its local data moving with
      // each contact scored: an integration is asked again only when what it
      // describes moved, or its switch did.
      final moved = !const DeepCollectionEquality().equals(_describedOf(operation), _describedOf(previous));
      final catalog = widget.services.integrations.catalog;
      _describe(
        moved
            ? catalog
            : [...catalog.where((integration) => IntegrationService.isOnIn(integration, operation) != IntegrationService.isOnIn(integration, previous))],
      );
    });
    widget.services.integrations.addListener(_onIntegrationsChanged);
    _describe();
    // Web has no UDP sockets, so the listen feature is hidden there
    // entirely — nothing to react to.
    if (!isWebPlatform) {
      widget.services.settings.addListener(_onChanged);
      widget.services.inboundQsos.addListener(_onChanged);
    }
  }

  @override
  void dispose() {
    unawaited(_operationSub?.cancel());
    widget.services.integrations.removeListener(_onIntegrationsChanged);
    if (!isWebPlatform) {
      widget.services.settings.removeListener(_onChanged);
      widget.services.inboundQsos.removeListener(_onChanged);
    }
    super.dispose();
  }

  /// Per sender among the captures, whether its contacts are added on their
  /// own ([InboundQsoListenerService.addsOnItsOwn]); asked once per sender
  /// until a setting changes, not on every rebuild.
  final _addsOnItsOwn = <String, Future<bool>>{};

  Future<bool> _addsOnItsOwnFor(String? sender) =>
      sender == null ? Future.value(true) : _addsOnItsOwn[sender] ??= widget.services.inboundQsos.addsOnItsOwn(sender);

  void _onChanged() {
    _addsOnItsOwn.clear();
    if (mounted) setState(() {});
  }

  void _onIntegrationsChanged() {
    _describe();
    _onChanged();
  }

  /// What each integration on in this operation says of itself here, its
  /// hook's `describe`, by id; its own `description` until it answers, when
  /// it answers nothing, and while it is off.
  final _described = <String, String?>{};

  /// Per integration, bumped by each ask, so an answer about the operation or
  /// the settings as they were never lands over one about them as they are.
  /// One count for all would let each ask throw away the others' answers
  /// still on their way.
  final _asked = <String, int>{};

  /// What `describe` is handed of [operation], less its time range: that
  /// moves with every contact logged.
  static Map<String, dynamic> _describedOf(Operation operation) => operationHookArgs(operation)
    ..remove('startAtMillisMin')
    ..remove('startAtMillisMax');

  /// Asks each of [integrations] that is on in this operation what it would
  /// do here, and forgets what those off said: switching one on is what
  /// hands it the operation.
  void _describe([List<WatcherDefinition>? integrations]) {
    final operation = _operation;
    for (final integration in integrations ?? widget.services.integrations.catalog) {
      final id = integration.id;
      final ask = _asked[id] = (_asked[id] ?? 0) + 1;
      if (!IntegrationService.isOnIn(integration, operation)) {
        _described.remove(id);
        continue;
      }
      unawaited(
        widget.services.integrations.describe(integration, operation).then((line) {
          if (mounted && ask == _asked[id]) setState(() => _described[id] = line);
        }),
      );
    }
  }

  bool get _receiving => widget.services.inboundQsos.receivingOperationUuid == widget.operation.uuid;

  /// Adds the waiting captures [sender] sent to this operation and, when
  /// [always], every later one as it arrives.
  Future<void> _addFrom(String sender, {bool always = false}) async {
    final inboundQsos = widget.services.inboundQsos;
    if (always) await inboundQsos.allowSender(sender);
    await inboundQsos.addToOperation(widget.operation.uuid, [..._pending.where((row) => row.sender == sender)]);
  }

  Future<void> _discard(InboundCaptureRow row) async {
    await widget.services.inboundCaptures.discard([row.uuid]);
    final sender = row.sender;
    if (sender != null && !_pending.any((other) => other.uuid != row.uuid && other.sender == sender)) {
      widget.services.inboundQsos.dismissHeldNotice(sender);
    }
  }

  Future<void> _setReceiving(bool value) async {
    final inboundQsos = widget.services.inboundQsos;
    if (!value) {
      inboundQsos.stopReceivingFor(widget.operation.uuid);
      return;
    }

    // A held sender's captures stay held: they wait on their own tile.
    final backlog = [
      for (final row in _pending)
        if (await _addsOnItsOwnFor(row.sender)) row,
    ];
    if (!mounted) return;
    final toAddNow = await _resolveBacklog(backlog);
    if (toAddNow == null || !mounted) return; // the operator backed out of the gap dialog
    // Set BEFORE processing the backlog: a datagram arriving mid-await is
    // then already routed automatically, rather than landing in a buffer
    // this call is about to snapshot past.
    inboundQsos.setReceivingOperation(widget.operation.uuid);
    if (toAddNow.isNotEmpty) await inboundQsos.addToOperation(widget.operation.uuid, toAddNow);
  }

  /// Splits [pending] at its most recent gap over [_captureGapThreshold] and,
  /// if anything sits before that gap, asks the operator whether to include
  /// it too. Returns the rows to add now, or null if they backed out of the
  /// dialog entirely (as opposed to answering "just the recent ones", which
  /// returns a non-null, smaller list).
  Future<List<InboundCaptureRow>?> _resolveBacklog(List<InboundCaptureRow> pending) async {
    if (pending.isEmpty) return const [];
    final sorted = [...pending]..sort((a, b) => a.receivedAtMillis.compareTo(b.receivedAtMillis));

    var splitAt = 0;
    for (var i = 1; i < sorted.length; i++) {
      if (sorted[i].receivedAtMillis - sorted[i - 1].receivedAtMillis > _captureGapThreshold.inMilliseconds) {
        splitAt = i;
      }
    }
    if (splitAt == 0) return sorted;

    final older = sorted.sublist(0, splitAt);
    final recent = sorted.sublist(splitAt);
    final t = context.t.operation.import;
    final includeAll = await showHaloDialog<bool>(
      context: context,
      builder: (dialogContext) => HaloDialog(
        title: Text(t.gapDialogTitle),
        content: Text(t.gapDialogBody(count: older.length)),
        cancel: TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: Text(t.gapDialogRecentOnly)),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(t.gapDialogIncludeAll(count: sorted.length)),
          ),
        ],
      ),
    );
    if (includeAll == null) return null;
    return includeAll ? sorted : recent;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Rows to the pane's edges, contents inset — the settings list every
        // other list-shaped surface is (docs/design/user-interface.md
        // § Settings lists).
        Expanded(
          child: SettingsList(
            child: SectionedListView(
              padding: const EdgeInsets.only(bottom: Space.md),
              children: _rows(context),
            ),
          ),
        ),
        // Nothing here waits to be confirmed — every row acts as it is
        // worked — so the footer holds one way out, in the cancel slot. The
        // extensions behind the integrations sit at its leading edge, below
        // however many captures the list runs to.
        haloDialogFooterBand(
          context,
          // The tools slot is Expanded: unaligned, a lone button sits in
          // the middle of it.
          tools: Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton.icon(
              icon: const Icon(MdiIcons.puzzle),
              label: Text(context.t.operation.import.manageIntegrationExtensions),
              onPressed: () => unawaited(_manageIntegrationExtensions()),
            ),
          ),
          cancel: TextButton(onPressed: () => Navigator.of(context).maybePop(), child: Text(context.t.common.done)),
        ),
      ],
    );
  }

  /// The installed extensions that offer integrations. Switching one on or
  /// off restarts the runtime, which is what refreshes the rows here.
  Future<void> _manageIntegrationExtensions() => showModalPane<void>(
    context,
    title: context.t.activitiesView.manageExtensions,
    closeLabel: context.t.common.close,
    // The list scrolls; the footer stays pinned under it and its Done is the
    // way out — so no X in the header (see haloDialogFooterBand).
    scrollable: false,
    closeButton: false,
    builder: (_) => ExtensionsPanel(services: widget.services, onlyHook: HookCategories.integration, footer: true),
  );

  /// [integration]'s own settings, the rows Settings › Integrations holds
  /// for it: app-wide, though reached from one operation. What they changed
  /// may change what it says of itself.
  Future<void> _showIntegrationSettings(WatcherDefinition integration) async {
    await showSettingsForKeys(
      context,
      services: widget.services,
      keys: [
        for (final field in integration.formFields)
          if (field['key'] case final String key) watcherFieldRowKey(integration, key),
      ],
      title: integration.title,
    );
    if (mounted) _describe([integration]);
  }

  List<Widget> _rows(BuildContext context) {
    final t = context.t.operation.import;

    final importAdifRow = ListTile(
      leading: const Icon(MdiIcons.import),
      title: Text(t.importAdifAction),
      onTap: () => unawaited(pickAndImportAdif(context, services: widget.services, operation: widget.operation)),
    );

    final integrationRows = [
      for (final (_, offered) in watchersByExtension(widget.services.integrations.catalog, widget.services.extensions))
        for (final integration in offered)
          _IntegrationTile(
            integration: integration,
            described: _described[integration.id],
            on: IntegrationService.isOnIn(integration, _operation),
            onChanged: (on) => unawaited(widget.services.integrations.setOn(integration, _operation.uuid, on)),
            onSettings: integration.formFields.isEmpty ? null : () => unawaited(_showIntegrationSettings(integration)),
          ),
    ];

    // UDP sockets don't exist on web — there is nothing this feature could
    // ever do there, so it doesn't offer to.
    if (isWebPlatform) return [importAdifRow, ...integrationRows];

    final settings = widget.services.settings;
    final theme = Theme.of(context);
    final operationStationCall = widget.operation.stationCalls.length == 1 ? widget.operation.stationCalls.first : null;

    return [
      importAdifRow,
      ...integrationRows,
      ListTile(
        leading: Icon(settings.listenForOtherAppsEnabled ? MdiIcons.accessPointNetwork : MdiIcons.accessPointNetworkOff),
        title: Text(t.listenTitle),
        subtitle: Text(
          !settings.listenForOtherAppsEnabled
              ? t.listenDescriptionOff
              : switch ((settings.n1mmProtocolEnabled, settings.wsjtxProtocolEnabled)) {
                  (true, true) => t.listenDescriptionOnBoth,
                  (true, false) => t.listenDescriptionOnN1mm,
                  (false, true) => t.listenDescriptionOnWsjtx,
                  (false, false) => t.listenDescriptionOff,
                },
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Switch(value: settings.listenForOtherAppsEnabled, onChanged: (value) => unawaited(settings.setListenForOtherAppsEnabled(value))),
            IconButton(
              icon: Icon(MdiIcons.tune, semanticLabel: t.settingsButton),
              onPressed: () => unawaited(showListenSettingsDialog(context, services: widget.services)),
            ),
          ],
        ),
      ),
      // A capture insert failure means a QSO the source program will never
      // resend is sitting in a memory-only retry queue — the loudest thing
      // in this panel, for as long as it stays unresolved.
      if (widget.services.inboundQsos.captureError != null)
        Padding(
          padding: const EdgeInsets.fromLTRB(settingsRowInset, Space.md, settingsRowInset, 0),
          child: Text(
            t.captureFailed(error: widget.services.inboundQsos.captureError!),
            style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.error),
          ),
        ),
      // One StreamBuilder around everything below, rather than just around
      // the list: whether "Add to this operation" shows at all depends on
      // [rows], so a rebuild scoped only to the list would leave that row
      // stale the moment a capture arrives. Which puts the Captured QSOs band
      // inside it, out of the list's sight — so it cuts its own sections and
      // the list is told it holds slivers.
      SectionedSlivers(
        slivers: [
          StreamBuilder<List<InboundCaptureRow>>(
            stream: widget.services.inboundCaptures.watchPending(),
            builder: (context, snapshot) {
              final rows = snapshot.data ?? const <InboundCaptureRow>[];
              _pending = rows;
              // Hidden until there's real data to decide about — an operator who
              // hasn't started the other program yet has nothing to turn this on
              // FOR, and a toggle with nothing behind it just reads as broken.
              final showAddToOperation = _receiving || rows.isNotEmpty;

              final sorted = [...rows]..sort((a, b) => b.receivedAtMillis.compareTo(a.receivedAtMillis));
              final senders = {for (final row in rows) ?row.sender};
              return SliverMainAxisGroup(
                slivers: sectionSlivers(context, [
                  if (showAddToOperation)
                    SwitchListTile(
                      secondary: const Icon(MdiIcons.playlistCheck),
                      title: Text(t.addToOperationTitle),
                      subtitle: Text(_receiving ? t.addToOperationDescriptionOn : t.addToOperationDescriptionOff),
                      value: _receiving,
                      onChanged: (value) => unawaited(_setReceiving(value)),
                    ),
                  for (final sender in senders)
                    _HeldSenderTile(
                      key: ValueKey(sender),
                      sender: sender,
                      addsOnItsOwn: _addsOnItsOwnFor(sender),
                      onAdd: () => unawaited(_addFrom(sender)),
                      onAlwaysAdd: () => unawaited(_addFrom(sender, always: true)),
                    ),
                  SectionHeader(t.pendingSectionTitle),
                  if (sorted.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: settingsRowInset, vertical: Space.lg),
                      child: Text(t.pendingEmpty, style: theme.textTheme.bodyMedium),
                    )
                  else
                    for (final row in sorted) _CaptureTile(row: row, operationStationCall: operationStationCall, onDiscard: () => unawaited(_discard(row))),
                ]),
              );
            },
          ),
        ],
      ),
    ];
  }
}

/// An extension's integration: its switch for this operation, and its
/// settings when it has any.
class _IntegrationTile extends StatelessWidget {
  final WatcherDefinition integration;

  /// What it said of itself in this operation; null shows its `description`.
  final String? described;
  final bool on;
  final ValueChanged<bool> onChanged;
  final VoidCallback? onSettings;

  const _IntegrationTile({required this.integration, required this.described, required this.on, required this.onChanged, required this.onSettings});

  @override
  Widget build(BuildContext context) {
    final described = this.described;
    final description = integration.description;
    return ListTile(
      leading: Icon(resolveIconName(integration.icon, fallback: MdiIcons.connection)),
      title: Text(integration.title),
      // The answer is the extension's to word, asked as the operation moves:
      // held to two lines, a long one cannot push the switches down the
      // dialog.
      subtitle: described != null
          ? Text(described, maxLines: 2, overflow: TextOverflow.ellipsis)
          : description == null
          ? null
          : Text(description),
      onTap: () => onChanged(!on),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Switch(value: on, onChanged: onChanged),
          if (onSettings != null)
            IconButton(
              icon: Icon(MdiIcons.tune, semanticLabel: context.t.operation.import.integrationSettingsButton(title: integration.title)),
              onPressed: onSettings,
            ),
        ],
      ),
    );
  }
}

/// Captures another device on the network sent, waiting for the operator:
/// nothing says who sent a datagram, so they are not added on their own.
/// Nothing at all for a sender whose contacts are.
class _HeldSenderTile extends StatelessWidget {
  final String sender;
  final Future<bool> addsOnItsOwn;
  final VoidCallback onAdd;
  final VoidCallback onAlwaysAdd;

  const _HeldSenderTile({super.key, required this.sender, required this.addsOnItsOwn, required this.onAdd, required this.onAlwaysAdd});

  @override
  Widget build(BuildContext context) {
    final t = context.t.operation.import;
    return FutureBuilder<bool>(
      future: addsOnItsOwn,
      builder: (context, snapshot) {
        // Shown unless the answer is yes: a sender that cannot be placed
        // waits like a stranger.
        if (snapshot.data == true || (!snapshot.hasData && !snapshot.hasError)) return const SizedBox.shrink();
        return ListTile(
          leading: const Icon(MdiIcons.lanPending),
          title: Text(t.heldTitle(sender: sender)),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(t.heldBody),
              Wrap(
                spacing: Space.sm,
                children: [
                  TextButton(onPressed: onAdd, child: Text(t.heldAddAction)),
                  TextButton(onPressed: onAlwaysAdd, child: Text(t.heldAlwaysAction)),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _CaptureTile extends StatelessWidget {
  final InboundCaptureRow row;
  final String? operationStationCall;
  final VoidCallback onDiscard;

  const _CaptureTile({required this.row, required this.operationStationCall, required this.onDiscard});

  @override
  Widget build(BuildContext context) {
    final t = context.t.operation.import;
    final qso = row.qso;
    final their = (qso['their'] as Map?)?.cast<String, dynamic>() ?? const {};
    final our = asQsonMap(qso['our']) ?? const {};
    final call = asQsonString(their['call']) ?? '?';
    final band = asQsonString(qso['band']);
    final mode = asQsonString(qso['mode']);
    // Same check ADIF import uses (`qso_merge.dart`'s `foreignStationCalls`)
    // to warn about a call that doesn't match the operation it's landing in.
    final mismatch = operationStationCall != null && operationStationCall!.isNotEmpty && foreignStationCalls([qso], operationStationCall!).isNotEmpty;

    return ListTile(
      leading: mismatch ? Icon(MdiIcons.alertCircleOutline, color: Theme.of(context).colorScheme.error) : const Icon(MdiIcons.radio),
      title: Text([call, band, mode].whereType<String>().join(' · ')),
      subtitle: Text(mismatch ? t.stationMismatch(call: asQsonString(our['call']) ?? '?') : fmtTimeBetween(row.receivedAtMillis, nowMillis())),
      trailing: IconButton(
        icon: Icon(MdiIcons.closeCircleOutline, semanticLabel: t.discardAction),
        onPressed: onDiscard,
      ),
    );
  }
}

/// The tune icon's dialog. See [_ListenSettingsDialogBody] for the shape.
Future<void> showListenSettingsDialog(BuildContext context, {required HaLoServices services}) => showHaloDialog<void>(
  context: context,
  builder: (_) => _ListenSettingsDialogBody(services: services),
);

/// One row per protocol this app can listen to (currently N1MM's broadcast
/// and WSJT-X's multicast — a list rather than two hand-written sections, so
/// a third protocol is a data row, not a copy of the whole block). Each row
/// has its own enable switch, its own troubleshooting note directly under
/// its fields, and a status light that says whether the CURRENT address/port
/// is actually hearing anything.
///
/// A `StatefulWidget` rather than the plain builder every other dialog in
/// this file uses: the status lights have to keep re-evaluating "is that
/// timestamp still recent?" even when nothing new arrives — staleness decays
/// on its own, it isn't only ever announced by an event.
class _ListenSettingsDialogBody extends StatefulWidget {
  final HaLoServices services;

  const _ListenSettingsDialogBody({required this.services});

  @override
  State<_ListenSettingsDialogBody> createState() => _ListenSettingsDialogBodyState();
}

/// How long since the last datagram before a status light stops reading as
/// "hearing it" — generous relative to WSJT-X's own ~15s Heartbeat/Status
/// cadence and N1MM's on-change RadioInfo, so a light doesn't flicker red
/// between two normal messages.
const _recentDataWindow = Duration(seconds: 60);

class _ListenSettingsDialogBodyState extends State<_ListenSettingsDialogBody> {
  late final TextEditingController _n1mmPortController;
  late final TextEditingController _wsjtxPortController;
  late final TextEditingController _wsjtxGroupController;
  Timer? _ticker;

  // Set only by a failed Save attempt, so a field reads clean until the
  // operator actually tries to leave it invalid — not on every keystroke.
  String? _n1mmPortError;
  String? _wsjtxPortError;
  String? _wsjtxGroupError;

  @override
  void initState() {
    super.initState();
    final settings = widget.services.settings;
    _n1mmPortController = TextEditingController(text: settings.n1mmListenPort.toString());
    _wsjtxPortController = TextEditingController(text: settings.wsjtxListenPort.toString());
    _wsjtxGroupController = TextEditingController(text: settings.wsjtxMulticastGroup);
    _ticker = Timer.periodic(const Duration(seconds: 2), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _n1mmPortController.dispose();
    _wsjtxPortController.dispose();
    _wsjtxGroupController.dispose();
    super.dispose();
  }

  bool _recentlyReceived(int? lastReceivedAtMillis) => lastReceivedAtMillis != null && nowMillis() - lastReceivedAtMillis < _recentDataWindow.inMilliseconds;

  static int? _validPort(String text) {
    final port = int.tryParse(text.trim());
    return (port != null && port > 0 && port <= 65535) ? port : null;
  }

  /// A syntactically valid IPv4 dotted-quad — `InternetAddress(String)`
  /// requires a numeric address (it does not resolve hostnames), so this is
  /// what actually determines whether `joinMulticast`/the bind can succeed,
  /// not just "the field isn't empty".
  static bool _validAddress(String text) {
    final octets = text.trim().split('.');
    if (octets.length != 4) return false;
    return octets.every((o) {
      final n = int.tryParse(o);
      return n != null && n >= 0 && n <= 255;
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t.operation.import;
    final theme = Theme.of(context);
    final settings = widget.services.settings;
    final inboundQsos = widget.services.inboundQsos;

    Color connectedColor() => theme.brightness == Brightness.dark ? Colors.green.shade600 : Colors.green.shade700;

    // No hover tooltips in this app (docs/design/user-interface.md) — the
    // dot's color is the sighted signal, Semantics is the accessible one.
    Widget statusLight(bool active) => Semantics(
      label: active ? t.protocolStatusReceiving : t.protocolStatusNoData,
      child: Container(
        width: 10,
        height: 10,
        decoration: BoxDecoration(shape: BoxShape.circle, color: active ? connectedColor() : theme.colorScheme.error),
      ),
    );

    Widget protocolRow({
      required String protocolName,
      required bool enabled,
      required ValueChanged<bool> onEnabledChanged,
      required bool recentlyReceived,
      required String? bindError,
      required Widget addressField,
      required Widget portField,
      required String helpText,
    }) => Container(
      margin: const EdgeInsets.fromLTRB(Space.lg, 0, Space.lg, Space.md),
      padding: const EdgeInsets.all(Space.md),
      decoration: BoxDecoration(
        border: Border.all(color: theme.colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Switch(value: enabled, onChanged: onEnabledChanged),
              const SizedBox(width: Space.sm),
              Expanded(child: Text(protocolName, style: theme.textTheme.titleSmall)),
              statusLight(recentlyReceived),
            ],
          ),
          const SizedBox(height: Space.sm),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 3, child: addressField),
              const SizedBox(width: Space.sm),
              Expanded(flex: 2, child: portField),
            ],
          ),
          // A failed bind/join is otherwise invisible: the status light
          // reads identically red for "not started yet" and "will never
          // work as configured" without this line naming the reason.
          if (bindError != null) ...[
            const SizedBox(height: Space.sm),
            Text(
              t.protocolBindError(error: bindError),
              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.error),
            ),
          ],
          const SizedBox(height: Space.sm),
          Text(helpText, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
        ],
      ),
    );

    Widget portField(TextEditingController controller, String? errorText) => TextField(
      controller: controller,
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      decoration: InputDecoration(labelText: t.protocolPortLabel, errorText: errorText),
    );

    return HaloDialog(
      title: Text(t.settingsTitle),
      wide: true,
      contentPadding: const EdgeInsets.symmetric(vertical: Space.md),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          protocolRow(
            protocolName: t.n1mmProtocolName,
            enabled: settings.n1mmProtocolEnabled,
            onEnabledChanged: (value) {
              unawaited(settings.setN1mmProtocolEnabled(value));
              setState(() {});
            },
            recentlyReceived: _recentlyReceived(inboundQsos.n1mmLastReceivedAtMillis),
            bindError: inboundQsos.n1mmError,
            // Not editable: a broadcast listener binds every interface, so
            // there is no per-address setting to offer here — this is
            // display-only, matching the shape of the WSJT-X row below
            // rather than omitting the field. `InputDecorator` rather than a
            // disabled `TextField`: no controller to dispose for a value
            // that never changes.
            addressField: InputDecorator(
              decoration: InputDecoration(labelText: t.protocolAddressLabel, enabled: false),
              child: Text(t.n1mmAddressValue),
            ),
            portField: portField(_n1mmPortController, _n1mmPortError),
            helpText: t.helpN1mmSetup,
          ),
          protocolRow(
            protocolName: t.wsjtxProtocolName,
            enabled: settings.wsjtxProtocolEnabled,
            onEnabledChanged: (value) {
              unawaited(settings.setWsjtxProtocolEnabled(value));
              setState(() {});
            },
            recentlyReceived: _recentlyReceived(inboundQsos.wsjtxLastReceivedAtMillis),
            bindError: inboundQsos.wsjtxError,
            addressField: TextField(
              controller: _wsjtxGroupController,
              decoration: InputDecoration(labelText: t.protocolAddressLabel, errorText: _wsjtxGroupError),
            ),
            portField: portField(_wsjtxPortController, _wsjtxPortError),
            helpText: t.helpWsjtxSetup,
          ),
          if (settings.inboundSendersAllowed.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(Space.lg, Space.sm, Space.lg, 0),
              child: Text(t.allowedSendersTitle, style: theme.textTheme.titleSmall),
            ),
            for (final sender in settings.inboundSendersAllowed)
              ListTile(
                title: Text(sender),
                trailing: IconButton(
                  icon: Icon(MdiIcons.closeCircleOutline, semanticLabel: t.allowedSenderRemove(sender: sender)),
                  onPressed: () async {
                    await settings.setInboundSenderAllowed(sender, false);
                    if (mounted) setState(() {});
                  },
                ),
              ),
          ],
        ],
      ),
      cancel: TextButton(onPressed: () => Navigator.of(context).pop(), child: Text(context.t.common.cancel)),
      actions: [
        FilledButton(
          onPressed: () {
            final n1mmPort = _validPort(_n1mmPortController.text);
            final wsjtxPort = _validPort(_wsjtxPortController.text);
            final wsjtxGroupValid = _validAddress(_wsjtxGroupController.text);
            if (n1mmPort == null || wsjtxPort == null || !wsjtxGroupValid) {
              // Invalid input stays on screen with its error rather than
              // being silently dropped — the old value would otherwise
              // stay in effect with nothing telling the operator why.
              setState(() {
                _n1mmPortError = n1mmPort == null ? t.protocolPortInvalid : null;
                _wsjtxPortError = wsjtxPort == null ? t.protocolPortInvalid : null;
                _wsjtxGroupError = wsjtxGroupValid ? null : t.protocolAddressInvalid;
              });
              return;
            }
            unawaited(settings.setN1mmListenPort(n1mmPort));
            unawaited(settings.setWsjtxListenPort(wsjtxPort));
            unawaited(settings.setWsjtxMulticastGroup(_wsjtxGroupController.text.trim()));
            Navigator.of(context).pop();
          },
          child: Text(context.t.common.save),
        ),
      ],
    );
  }
}
