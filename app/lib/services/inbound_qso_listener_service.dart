// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Listens for another logging program's QSOs on the network and buffers them
// until the operator decides whether to add them to an operation's log — see
// "Listen for other apps" (HALO-306). Two DIFFERENT protocols, both
// started and stopped together off one setting:
//   - N1MM Logger+'s UDP broadcast: a `<contactinfo>` XML datagram once per
//     QSO logged. `<contactreplace>`/delete messages are not handled — see
//     `n1mm_contact_info.dart`'s header.
//   - WSJT-X's own UDP protocol: multicast, binary, a "QSO Logged" message
//     once the operator accepts its Log QSO dialog — see
//     `wsjtx_qso_logged.dart`'s header. NOT a variant of N1MM's protocol,
//     despite both existing to answer the same operator need.
//
// App-wide, like the buffer it fills (`InboundCaptures`): the listener starts
// and stops with `SettingsService.listenForOtherAppsEnabled`, independent of
// which operation is open. Routing a capture INTO an operation's log is a
// second, separate decision — [receivingOperationUuid] — since the buffer
// exists specifically so captures survive while no operation wants them yet.

import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:halo_core/halo_core.dart';

import 'cat/transports/udp_broadcast.dart';
import 'error_reporting_service.dart';
import 'lookup_queue_service.dart';
import 'settings_service.dart';
import 'udp_multicast.dart';

class InboundQsoListenerService extends ChangeNotifier {
  final SettingsService settings;
  final InboundCaptureRepository captures;
  final QsosRepository qsos;
  final OperationsRepository operations;
  final LookupQueueService lookupQueue;

  InboundQsoListenerService({
    required this.settings,
    required this.captures,
    required this.qsos,
    required this.operations,
    required this.lookupQueue,
  }) {
    settings.addListener(_onSettingsChanged);
    _onSettingsChanged();
  }

  StreamSubscription<Uint8List>? _n1mmSubscription;
  int? _n1mmBoundPort;

  StreamSubscription<Uint8List>? _wsjtxSubscription;
  int? _wsjtxBoundPort;
  String? _wsjtxBoundGroup;

  /// When each protocol last delivered ANY datagram — not just a QSO. This
  /// is what the settings dialog's status light reads: RadioInfo/Heartbeat
  /// chatter proves the network path and the configured address/port are
  /// right even on a day nobody has logged a contact yet, which a QSO-only
  /// signal couldn't tell the operator.
  int? n1mmLastReceivedAtMillis;
  int? wsjtxLastReceivedAtMillis;

  /// Why binding/joining failed, if it did — e.g. the port is already held
  /// by another program, or the configured address doesn't parse. `.report`
  /// (called alongside setting this) only logs and uploads; it never shows
  /// anything on screen, so without this field a failed bind was completely
  /// silent — a status light that never turns green looks identical to
  /// "nothing has arrived yet" and "this is broken and will never work".
  /// Cleared on the next (re)start attempt, successful or not, so a stale
  /// error doesn't linger after the operator fixes the setting that caused it.
  String? n1mmError;
  String? wsjtxError;

  /// The operation currently receiving captures as they arrive, or null if
  /// none is. Set by the Imports panel when the operator turns "add to this
  /// operation" on, cleared when they turn it off or the operation view
  /// closes. Only one operation can receive at a time: the ask is "if the
  /// operator switches operations, we stop adding QSOs", which a single slot
  /// gives for free, without needing a stack that tracks every open
  /// OperationView.
  String? receivingOperationUuid;

  void setReceivingOperation(String? operationUuid) {
    if (receivingOperationUuid == operationUuid) return;
    receivingOperationUuid = operationUuid;
    notifyListeners();
  }

  /// Stops receiving for [operationUuid] specifically — a closing
  /// OperationView must not clear a DIFFERENT operation's receiver that took
  /// over after it opened.
  void stopReceivingFor(String operationUuid) {
    if (receivingOperationUuid == operationUuid) setReceivingOperation(null);
  }

  void _onSettingsChanged() {
    final on = settings.listenForOtherAppsEnabled;
    if (on && settings.n1mmProtocolEnabled) {
      if (_n1mmBoundPort != settings.n1mmListenPort) _startN1mm();
    } else {
      _stopN1mm();
    }
    if (on && settings.wsjtxProtocolEnabled) {
      if (_wsjtxBoundPort != settings.wsjtxListenPort || _wsjtxBoundGroup != settings.wsjtxMulticastGroup) {
        _startWsjtx();
      }
    } else {
      _stopWsjtx();
    }
  }

  void _startN1mm() {
    _stopN1mm();
    final port = settings.n1mmListenPort;
    _n1mmBoundPort = port;
    debugPrint('[inbound-qso] binding N1MM UDP broadcast on port $port');
    _n1mmSubscription = udpBroadcastDatagrams(port: port).listen(
      _onN1mmDatagram,
      onError: (Object e, StackTrace st) {
        debugPrint('[inbound-qso] N1MM listen error on port $port: $e');
        ErrorReportingService.report(e, st, context: 'InboundQsoListenerService:listenN1mm');
        n1mmError = e.toString();
        notifyListeners();
      },
    );
  }

  void _stopN1mm() {
    _n1mmSubscription?.cancel();
    _n1mmSubscription = null;
    _n1mmBoundPort = null;
    // Also runs at the start of every (re)start attempt, so a stale error
    // never survives past the next bind — successful or not.
    if (n1mmError != null) {
      n1mmError = null;
      notifyListeners();
    }
  }

  void _startWsjtx() {
    _stopWsjtx();
    final port = settings.wsjtxListenPort;
    final group = settings.wsjtxMulticastGroup;
    _wsjtxBoundPort = port;
    _wsjtxBoundGroup = group;
    debugPrint('[inbound-qso] listening for WSJT-X on $group:$port');
    _wsjtxSubscription = udpMulticastDatagrams(port: port, multicastGroup: group).listen(
      _onWsjtxDatagram,
      onError: (Object e, StackTrace st) {
        debugPrint('[inbound-qso] WSJT-X listen error on $group:$port: $e');
        ErrorReportingService.report(e, st, context: 'InboundQsoListenerService:listenWsjtx');
        wsjtxError = e.toString();
        notifyListeners();
      },
    );
  }

  void _stopWsjtx() {
    _wsjtxSubscription?.cancel();
    _wsjtxSubscription = null;
    _wsjtxBoundPort = null;
    _wsjtxBoundGroup = null;
    if (wsjtxError != null) {
      wsjtxError = null;
      notifyListeners();
    }
  }

  void _onN1mmDatagram(Uint8List data) {
    // Not `notifyListeners()`: WSJT-X's sibling handler below can fire many
    // times a second during heavy decode traffic, and the Imports panel
    // rebuilding on every one of those (nobody displays this field there)
    // would be pure waste. The settings dialog's status light polls this
    // field on its own timer instead of listening for it.
    n1mmLastReceivedAtMillis = nowMillis();
    final N1mmContactInfo? info;
    try {
      info = parseN1mmContactInfo(utf8.decode(data, allowMalformed: true));
    } catch (e, st) {
      ErrorReportingService.report(e, st, context: 'InboundQsoListenerService:parseN1mm');
      return;
    }
    // Every OTHER datagram N1MM broadcasts lands here too (RadioInfo,
    // lookupinfo, ...) — ignored silently rather than logged per-datagram,
    // since N1MM sends RadioInfo on an interval and would otherwise spam
    // the console for as long as listening stays on.
    if (info == null) return;
    _log('N1MM', info.qso);
    unawaited(_captureRaw(source: n1mmSource, dedupeKey: n1mmDedupeKey(info), qso: info.qso));
  }

  void _onWsjtxDatagram(Uint8List data) {
    // See the note on `_onN1mmDatagram` — deliberately not `notifyListeners()`.
    wsjtxLastReceivedAtMillis = nowMillis();
    final WsjtxQsoLogged? info;
    try {
      info = parseWsjtxQsoLogged(data);
    } catch (e, st) {
      ErrorReportingService.report(e, st, context: 'InboundQsoListenerService:parseWsjtx');
      return;
    }
    // Every other WSJT-X message (Heartbeat, Status, Decode, ...) lands here
    // too — WSJT-X sends Status/Decode continuously while it's running, so
    // this is silent for the same reason N1MM's RadioInfo is.
    if (info == null) return;
    _log('WSJT-X', info.qso);
    unawaited(_captureRaw(source: wsjtxSource, dedupeKey: wsjtxDedupeKey(info), qso: info.qso));
  }

  void _log(String source, Map<String, dynamic> qso) {
    final their = qso['their'] as Map<String, dynamic>;
    debugPrint('[inbound-qso] captured ($source) ${their['call']} on ${qso['band']}/${qso['mode']}');
  }

  Future<void> _captureRaw({required String source, required String dedupeKey, required Map<String, dynamic> qso}) async {
    final row = await captures.capture(source: source, dedupeKey: dedupeKey, qsoData: qso);
    // A resent duplicate datagram for a capture already added is returned
    // by `capture()` as the SAME existing row, `addedToOperation` included —
    // routing it through `addToOperation` again would log the QSO twice.
    if (row.addedToOperation != null) return;
    final receiving = receivingOperationUuid;
    if (receiving != null) await addToOperation(receiving, [row]);
  }

  /// Adds [rows] to [operationUuid]'s log, applying the operation's own
  /// station call regardless of what each capture recorded (the same policy
  /// ADIF import uses — `qsoForStation` in `qso_merge.dart`), running the
  /// normal online lookup on whatever succeeded, and marking those rows
  /// added — even if a later row in the batch throws, via `finally`, so a
  /// QSO that fails partway through a large "add the whole backlog" batch
  /// leaves only the rows that never got written still pending, rather than
  /// re-adding (duplicating) every row that already landed the next time
  /// this runs. One batched `markAdded`/`enqueueAll` call for the whole
  /// batch, not one per row — a large backlog would otherwise trigger a
  /// reactive `watchPending` re-run (and an Imports panel rebuild) for
  /// every single row.
  Future<List<Qso>> addToOperation(String operationUuid, List<InboundCaptureRow> rows) async {
    final pending = rows.where((r) => r.addedToOperation == null).toList();
    if (pending.isEmpty) return const [];
    final operation = await operations.get(operationUuid);
    final stationCall =
        operation != null && operation.stationCalls.length == 1 ? operation.stationCalls.first : null;

    final added = <Qso>[];
    final addedUuids = <String>[];
    try {
      for (final row in pending) {
        final data = (stationCall == null || stationCall.isEmpty) ? row.qso : qsoForStation(row.qso, stationCall);
        final qso = await qsos.add(operationUuid, data);
        added.add(qso);
        addedUuids.add(row.uuid);
      }
    } finally {
      if (addedUuids.isNotEmpty) await captures.markAdded(addedUuids, operationUuid);
      if (added.isNotEmpty) lookupQueue.enqueueAll(added, force: false);
    }
    return added;
  }

  @override
  void dispose() {
    settings.removeListener(_onSettingsChanged);
    _stopN1mm();
    _stopWsjtx();
    super.dispose();
  }
}

const n1mmSource = 'n1mm';
const wsjtxSource = 'wsjtx';
