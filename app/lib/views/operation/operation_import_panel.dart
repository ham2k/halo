// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Imports Panel: Import ADIF, and "Listen for other apps" (HALO-306) — N1MM
// and WSJT-X UDP listeners that buffer captured QSOs until the operator
// decides whether to add them to this operation.
//
// A Modal Pane like the Exports panel (operation_export_panel.dart), for the
// same reason: a picker the operator visits briefly, not a place, presenting
// as a dialog on desktop and full-screen on phone from one route.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show FilteringTextInputFormatter;
import 'package:halo_core/halo_core.dart';
import 'package:halo_widgets/halo_widgets.dart';

import 'package:halo_i18n/halo_i18n.dart';
import '../../services/halo_services.dart';
import 'adif_import_flow.dart';

/// How long a gap between two captures has to be before the operator is
/// asked whether to include what came before it — long enough that a
/// contact's own QSO-to-QSO cadence never trips it, short enough to still
/// read as "since I started the other program".
const _captureGapThreshold = Duration(minutes: 30);

Future<void> showOperationImportPanel(
  BuildContext context, {
  required HaLoServices services,
  required Operation operation,
}) {
  final t = context.t;
  return showModalPane<void>(
    context,
    title: t.operation.import.title,
    closeLabel: t.common.close,
    // The rows scroll; the footer stays pinned under them, and its Done is
    // the way out — so no X in the header (see haloDialogFooterBand).
    scrollable: false,
    closeButton: false,
    builder: (_) => OperationImportPanel(services: services, operation: operation),
  );
}

class OperationImportPanel extends StatefulWidget {
  final HaLoServices services;
  final Operation operation;

  const OperationImportPanel({super.key, required this.services, required this.operation});

  @override
  State<OperationImportPanel> createState() => _OperationImportPanelState();
}

class _OperationImportPanelState extends State<OperationImportPanel> {
  /// The `StreamBuilder`'s latest snapshot, kept here because [_setReceiving]
  /// needs it synchronously when the switch is flipped — waiting on the next
  /// build would race the operator's own tap.
  List<InboundCaptureRow> _pending = const [];

  @override
  void initState() {
    super.initState();
    // Web has no UDP sockets, so the listen feature is hidden there
    // entirely — nothing to react to.
    if (!isWebPlatform) {
      widget.services.settings.addListener(_onChanged);
      widget.services.inboundQsos.addListener(_onChanged);
    }
  }

  @override
  void dispose() {
    if (!isWebPlatform) {
      widget.services.settings.removeListener(_onChanged);
      widget.services.inboundQsos.removeListener(_onChanged);
    }
    super.dispose();
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  bool get _receiving => widget.services.inboundQsos.receivingOperationUuid == widget.operation.uuid;

  Future<void> _setReceiving(bool value) async {
    final inboundQsos = widget.services.inboundQsos;
    if (!value) {
      inboundQsos.stopReceivingFor(widget.operation.uuid);
      return;
    }

    final toAddNow = await _resolveBacklog(_pending);
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
        cancel: TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: Text(t.gapDialogRecentOnly),
        ),
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
        // worked — so the footer holds one way out, in the cancel slot.
        haloDialogFooterBand(
          context,
          cancel: TextButton(
            onPressed: () => Navigator.of(context).maybePop(),
            child: Text(context.t.common.done),
          ),
        ),
      ],
    );
  }

  List<Widget> _rows(BuildContext context) {
    final t = context.t.operation.import;

    final importAdifRow = ListTile(
      leading: const Icon(MdiIcons.import),
      title: Text(t.importAdifAction),
      onTap: () => unawaited(pickAndImportAdif(context, services: widget.services, operation: widget.operation)),
    );

    // UDP sockets don't exist on web — there is nothing this feature could
    // ever do there, so it doesn't offer to.
    if (isWebPlatform) return [importAdifRow];

    final settings = widget.services.settings;
    final theme = Theme.of(context);
    final operationStationCall =
        widget.operation.stationCalls.length == 1 ? widget.operation.stationCalls.first : null;

    return [
      importAdifRow,
      ListTile(
        leading:
            Icon(settings.listenForOtherAppsEnabled ? MdiIcons.accessPointNetwork : MdiIcons.accessPointNetworkOff),
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
            Switch(
              value: settings.listenForOtherAppsEnabled,
              onChanged: (value) => unawaited(settings.setListenForOtherAppsEnabled(value)),
            ),
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
      // stale the moment a capture arrives.
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
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (showAddToOperation)
                SwitchListTile(
                  secondary: const Icon(MdiIcons.playlistCheck),
                  title: Text(t.addToOperationTitle),
                  subtitle: Text(_receiving ? t.addToOperationDescriptionOn : t.addToOperationDescriptionOff),
                  value: _receiving,
                  onChanged: (value) => unawaited(_setReceiving(value)),
                ),
              SectionHeader(t.pendingSectionTitle),
              if (sorted.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: settingsRowInset, vertical: Space.lg),
                  child: Text(t.pendingEmpty, style: theme.textTheme.bodyMedium),
                )
              else
                for (final row in sorted)
                  _CaptureTile(
                    row: row,
                    operationStationCall: operationStationCall,
                    onDiscard: () => unawaited(widget.services.inboundCaptures.discard([row.uuid])),
                  ),
            ],
          );
        },
      ),
    ];
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
    final mismatch = operationStationCall != null &&
        operationStationCall!.isNotEmpty &&
        foreignStationCalls([qso], operationStationCall!).isNotEmpty;

    return ListTile(
      leading: mismatch
          ? Icon(MdiIcons.alertCircleOutline, color: Theme.of(context).colorScheme.error)
          : const Icon(MdiIcons.radio),
      title: Text([call, band, mode].whereType<String>().join(' · ')),
      subtitle: Text(
        mismatch
            ? t.stationMismatch(call: asQsonString(our['call']) ?? '?')
            : fmtTimeBetween(row.receivedAtMillis, nowMillis()),
      ),
      trailing: IconButton(
        icon: Icon(MdiIcons.closeCircleOutline, semanticLabel: t.discardAction),
        onPressed: onDiscard,
      ),
    );
  }
}

/// The tune icon's dialog. See [_ListenSettingsDialogBody] for the shape.
Future<void> showListenSettingsDialog(
  BuildContext context, {
  required HaLoServices services,
}) =>
    showHaloDialog<void>(context: context, builder: (_) => _ListenSettingsDialogBody(services: services));

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

  bool _recentlyReceived(int? lastReceivedAtMillis) =>
      lastReceivedAtMillis != null && nowMillis() - lastReceivedAtMillis < _recentDataWindow.inMilliseconds;

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
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: active ? connectedColor() : theme.colorScheme.error,
            ),
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
    }) =>
        Container(
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
              Text(
                helpText,
                style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
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
        ],
      ),
      cancel: TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: Text(context.t.common.cancel),
      ),
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
