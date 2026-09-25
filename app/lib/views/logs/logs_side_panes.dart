// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The Logs view's Info and Map panes, both scoped to the selected QSO.

part of '../logs_view.dart';

/// Resolves a QSO's own [Operation] live, for panels (map, call info) that
/// want its real grid rather than a placeholder — [Operation.grid] is the
/// QTH fallback when a QSO has none of its own, so a synthetic empty
/// Operation would silently drop that fallback. A loose QSO's
/// `operationUuid` is `''`, which matches no row either way, so the same
/// synthetic fallback covers it without a separate branch.
class _QsoOperationBuilder extends StatelessWidget {
  final HaLoServices services;
  final String operationUuid;
  final Widget Function(BuildContext context, Operation operation) builder;

  const _QsoOperationBuilder({required this.services, required this.operationUuid, required this.builder});

  @override
  Widget build(BuildContext context) => StreamBuilder<Operation?>(
    stream: services.operations.watchOperation(operationUuid),
    builder: (context, snapshot) => builder(context, snapshot.data ?? Operation(uuid: operationUuid, data: const {})),
  );
}

/// The info panel: no selection shows the filter's aggregate QSO count. A QSO
/// selected shows that QSO's counterparty looked up, the same [CallInfoPanel]
/// the operation view shows while composing/editing — fetched here directly
/// (`services.extensions.lookupCall`) since there is no `LoggingControls`
/// around to have already resolved it.
class _LogsInfoPanel extends StatefulWidget {
  final HaLoServices services;
  final int totalCount;
  final Qso? selected;

  const _LogsInfoPanel({required this.services, required this.totalCount, required this.selected});

  @override
  State<_LogsInfoPanel> createState() => _LogsInfoPanelState();
}

class _LogsInfoPanelState extends State<_LogsInfoPanel> {
  // Two separate trackers, not one: [_requestedFor] is set synchronously so
  // a second call before the first resolves doesn't fire a duplicate lookup;
  // [_resolvedFor] only advances once a result (or failure) actually lands,
  // and is what `build` checks for the spinner. A single shared tracker set
  // synchronously would read as "resolved" before the request is even in
  // flight, since `didUpdateWidget` runs before `build` in the same pass —
  // the spinner branch would never show, and the previous callsign's guess
  // and lookups would stay on screen, mislabeled under the new callsign, until the
  // network call happens to return.
  String? _requestedFor;
  String? _resolvedFor;
  Map<String, dynamic>? _guess;
  List<Map<String, dynamic>> _lookups = const [];

  @override
  void initState() {
    super.initState();
    _maybeLookup();
  }

  @override
  void didUpdateWidget(_LogsInfoPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    _maybeLookup();
  }

  void _maybeLookup() {
    final call = widget.selected?.theirCall;
    // Cleared on deselect, not left pointing at the last request — otherwise
    // reselecting the SAME callsign (after deselecting before its lookup
    // resolved) reads as already-requested and never fires again, leaving
    // `_resolvedFor` permanently behind and the spinner up for good.
    if (call == null) {
      _requestedFor = null;
      return;
    }
    if (call == _requestedFor) return;
    _requestedFor = call;
    widget.services.extensions
        .lookupCall(call, qso: const {}, operation: const {})
        .then(
          (result) {
            if (!mounted || widget.selected?.theirCall != call) return;
            setState(() {
              _resolvedFor = call;
              _guess = result?['guess'] as Map<String, dynamic>?;
              _lookups = asQsonList(result?['lookups'])?.whereType<Map<String, dynamic>>().toList() ?? const [];
            });
          },
          onError: (Object e, StackTrace stack) {
            ErrorReportingService.report(e, stack, context: 'logsInfoPanel:lookupCall');
            if (!mounted || widget.selected?.theirCall != call) return;
            // Cleared, not left at the previous callsign's values — a failed
            // lookup under the new callsign must not go on showing the old one's.
            setState(() {
              _resolvedFor = call;
              _guess = null;
              _lookups = const [];
            });
          },
        );
  }

  @override
  Widget build(BuildContext context) {
    final selected = widget.selected;
    if (selected == null) {
      final t = context.t.loggingControls.info;
      final countLabel = widget.totalCount == 1 ? t.qsoCountOne : t.qsoCountOther(count: formatNumber(widget.totalCount));
      return Center(child: Text(countLabel));
    }
    if (_resolvedFor != selected.theirCall) {
      return const Center(child: CircularProgressIndicator());
    }
    return _QsoOperationBuilder(
      services: widget.services,
      operationUuid: selected.operationUuid,
      builder: (context, operation) =>
          CallInfoPanel(operation: operation, services: widget.services, call: selected.theirCall, guess: _guess, lookups: _lookups),
    );
  }
}

/// The map panel — the selected QSO's own location and nothing else plotted.
/// [MapPanel] already draws a great-circle line from a QSO's counterpart grid
/// to its resolved QTH (`qso.our.grid`, falling back to the operation's) for
/// every QSO it's handed; a one-element list is exactly the "just this
/// contact" case; that fallback is why this fetches the QSO's real
/// [Operation] rather than a placeholder.
class _LogsMapPanel extends StatelessWidget {
  final HaLoServices services;
  final Qso? selected;

  const _LogsMapPanel({required this.services, required this.selected});

  @override
  Widget build(BuildContext context) {
    final qso = selected;
    if (qso == null) {
      return Center(child: Text(context.t.home.logs.mapNoSelection));
    }
    return _QsoOperationBuilder(
      services: services,
      operationUuid: qso.operationUuid,
      builder: (context, operation) => MapPanel(operation: operation, qsos: [qso], settings: services.settings),
    );
  }
}
