// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// What the extension runtime says about the operation an Operation view has
// open: the activity controls its logging panel and map draw, the station's
// own entity, and the live rescore that keeps its scores current.

import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:halo_core/halo_core.dart';
import 'package:halo_i18n/halo_i18n.dart';

import '../../services/halo_services.dart';
import '../../services/hook_payloads.dart' show operationPayloadFor;
import '../../services/scoring_service.dart' show checkpointDigestOf;

/// Whether two operations' `refs` are the same list.
bool sameRefs(Object? a, Object? b) => jsonEncode(a) == jsonEncode(b);

/// The count and the checkpoint digest — every uuid with its stamp,
/// order-free — which is what a pass stamps its checkpoint with, so the two
/// agree about whether anything moved. An O(N) walk with no allocation, on a
/// path that runs on the UI isolate for every emission of a long log; the
/// Spots Panel takes the same value as its "has the log changed?" signal.
String logFingerprintFor(List<Qso> qsos) => '${qsos.length}:${checkpointDigestOf(qsos)}';

/// One per Operation view. Notifies when anything a build reads changes.
class OperationRuntimeState extends ChangeNotifier {
  OperationRuntimeState({
    required this.services,
    required this.currentOperation,
    required this.controlsOperation,
    this.rescoreDelay = const Duration(milliseconds: 750),
  });

  final HaLoServices services;

  /// The operation the view holds — read when a debounced rescore fires and
  /// when the first retitle runs, never captured earlier, so both act on the
  /// operation as it is by then.
  final Operation? Function() currentOperation;

  /// The operation the activity controls describe: the setup sheet's draft
  /// while one is open, else [currentOperation]. A fetch this state starts
  /// on its own asks about this one — the sheet can hold a ref the operator
  /// just added, and refreshing against the saved, ref-less operation would
  /// replace the draft's controls with the wrong set. Closing the sheet
  /// hands the draft to the view without another fetch, so a wrong set
  /// installed then stays.
  final Operation? Function() controlsOperation;

  /// How long the log has to sit still before a rescore runs.
  final Duration rescoreDelay;

  bool _disposed = false;

  /// The activities' controls for the logging panel.
  List<Map<String, dynamic>> get loggingControls => _loggingControls;
  List<Map<String, dynamic>> _loggingControls = const [];

  /// The operation's own controls (`operationControls`), for the Map tab's
  /// markers and outlines: a program declares its ACTIVATION type there and
  /// only its hunting type among [loggingControls], so the operation's own
  /// references find their icon and colour here and nowhere else.
  List<Map<String, dynamic>> _operationControls = const [];

  /// Both lists, the operation's first — built when either changes, so the
  /// map is handed the same list between them.
  List<Map<String, dynamic>> get mapControls => _mapControls;
  List<Map<String, dynamic>> _mapControls = const [];

  // [refreshControls] has three independent callers (a ref change, a draft
  // edit, a runtime-generation retry) that can overlap — bumped before each
  // fetch and checked on return, so a slower call started earlier can't
  // clobber a faster one that started later.
  int _controlsRequestId = 0;

  /// Whether the last [refreshControls] fetch failed — read by
  /// [runtimeRestarted] so a generation tick unrelated to any pending
  /// mismatch (any extension anywhere getting toggled restarts the whole
  /// runtime) doesn't cost every open operation a round trip for nothing.
  bool _loggingControlsStale = false;

  /// The same for [_operationControls]: the map's icons and colours, with no
  /// status of their own, retried with the logging controls.
  bool _operationControlsStale = false;

  /// The station's own DXCC entity, resolved once per operation load (not
  /// per QSO — the station call essentially never changes DXCC entity
  /// mid-operation) so the QSO row can tell a DX contact from a domestic
  /// one. `online: false` skips network lookup hooks (QRZ/HamDB), running
  /// only the local, no-network callsign-annotation step that's all this
  /// needs — see extensions/core/lookups/src/annotate.ts.
  String? get ourEntityPrefix => _ourEntityPrefix;
  String? _ourEntityPrefix;

  /// The station's own ITU region (1/2/3) and lowercase ISO country code
  /// — resolved alongside [ourEntityPrefix], from the same guess,
  /// and fed to LoggingControls' band-plan mode guess so it can prefer/
  /// exclude region- or country-scoped segments for where the operator
  /// actually is instead of guessing blind.
  int? get ourItuRegion => _ourItuRegion;
  int? _ourItuRegion;
  String? get ourCountryCode => _ourCountryCode;
  String? _ourCountryCode;

  /// The log as last seen by [qsosChanged].
  List<Qso> get latestQsos => _latestQsos;
  List<Qso> _latestQsos = const [];

  Timer? _rescoreDebounce;

  /// Whether a rescore is waiting out its debounce.
  @visibleForTesting
  bool get rescoreScheduled => _rescoreDebounce?.isActive ?? false;

  /// The QSO-set fingerprint the last completed rescore was computed from —
  /// deliberately built from `updatedAtMillis` (stamped on every real edit,
  /// Milestone A) and NOT `scoreCache`, so a rescore's own `score_cache`
  /// write re-emits the QSO stream with an unchanged fingerprint and can't
  /// trigger itself. Null until a rescore has actually run with the
  /// extension runtime available.
  String? _lastScoredFingerprint;

  bool _started = false;

  /// The saved operation changed, from [previous] (null on the first
  /// emission) to [operation].
  void operationChanged(Operation? previous, Operation operation) {
    // A saved change to the operation itself — a reference corrected, an
    // exchange edited — changes what every contact scores as, so it is a
    // rescore like a logged contact is. Only once one is held: on open the
    // log's first emission schedules the pass, and a second from here would
    // fold the whole log twice.
    if (previous != null && previous.updatedAtMillis != operation.updatedAtMillis) scheduleRescore();

    if (!_started) {
      _started = true;
      unawaited(_start(operation));
    } else {
      // Re-derive the extension-fed side state only when its input actually
      // changed — not on every counter/localData emission (a QSO add, a
      // rescore) — so this stays cheap.
      if (previous?.stationCall != operation.stationCall) {
        unawaited(resolveOurEntity(operation));
      }
      if (previous == null || !sameRefs(previous.data['refs'], operation.data['refs'])) {
        unawaited(refreshControls(operation));
        // Refs are what suggestOperationTitle reads
        // — no debounce needed, refs only change on a deliberate edit, unlike
        // the QSO list's rescore trigger below.
        unawaited(services.operationTitles.retitleOperation(operation));
      }
    }
  }

  /// One-time, extension-runtime-dependent setup: the runtime may still be
  /// booting when the operation first arrives, so this awaits it, then does
  /// the initial controls/entity-prefix resolve and kicks the first rescore.
  Future<void> _start(Operation operation) async {
    await services.extensions.start();
    if (_disposed) return;
    // Each read afresh where it is used, never the `operation` parameter:
    // boot (the await above) and the fetch below can each take long enough
    // for the operator to add a ref or change the station call, and whatever
    // answers that edit has already asked for the fresher result. Asked for
    // a stale snapshot AFTER it, the controls fetch would win the request-id
    // race with the old ref set and say nothing was stale, and the lookup,
    // finishing last, would leave the old call's entity; the title cache has
    // no ordering guard at all.
    //
    // Checked after every await: a view closed mid-boot would otherwise go on
    // to look up, retitle and schedule a rescore of an operation nobody has
    // open — the rescore on a timer [dispose] has already passed.
    await refreshControls(controlsOperation() ?? operation);
    if (_disposed) return;
    await resolveOurEntity(currentOperation() ?? operation);
    if (_disposed) return;
    unawaited(services.operationTitles.retitleOperation(currentOperation() ?? operation));
    // The extension runtime is ready now; a rescore scheduled before it was
    // (which no-op'd) never recorded a fingerprint, so this re-attempts it.
    scheduleRescore();
  }

  Future<void> refreshControls(Operation operation) async {
    final requestId = ++_controlsRequestId;
    final payload = operationPayloadFor(operation);
    // Both asked at once, awaited apart: a record `.wait` would wrap an
    // unexpected throw in a ParallelWaitError that ErrorPolicy cannot see
    // through.
    final loggingFuture = services.extensions.loggingControls(payload);
    final operationFuture = services.extensions.operationControls(payload);
    final result = await loggingFuture;
    final operationWide = await operationFuture;
    if (_disposed || requestId != _controlsRequestId) return;
    // A failed fetch keeps what the map already shows — unless it shows
    // nothing, when whatever extensions did answer beats no colours at all.
    // Retried with the logging controls below when the runtime comes back.
    _operationControlsStale = operationWide.loadFailed;
    if (!operationWide.loadFailed || _operationControls.isEmpty) _operationControls = operationWide.controls;
    // A fetch that failed says nothing about what the activities want, so the
    // panel keeps what it is already showing rather than blanking a live
    // logging panel because the runtime happened to be restarting.
    //
    // A REF CHANGE is what usually re-runs this, so a failure here is
    // typically a set that no longer matches the operation — the contest
    // just added has no exchange field, the POTA ref just removed still has
    // one. [runtimeRestarted] below is what corrects it once the runtime that
    // was restarting comes back up; without that retry, nothing would until
    // the operation is reopened. Keeping the mismatch quiet in the meantime
    // would leave the operator staring at the wrong fields with no account
    // of why.
    _loggingControlsStale = result.loadFailed;
    final keepLogging = result.loadFailed && _loggingControls.isNotEmpty;
    if (result.loadFailed) {
      services.statusBar.setMessage(key: 'operation:logging-controls-stale', text: t.operation.loggingControlsStale);
    } else {
      services.statusBar.clear('operation:logging-controls-stale');
    }
    if (!keepLogging) _loggingControls = result.controls;
    _mapControls = [..._operationControls, ..._loggingControls];
    notifyListeners();
  }

  Future<void> resolveOurEntity(Operation operation) async {
    final ourInfo = await services.extensions.lookupCall(
      // One callsign: the raw field can hold several, and a lookup of
      // "KI2D, W1AW" resolves nothing — leaving the operation with no entity,
      // no ITU region and no country, which the logging controls and the
      // scorers both read.
      operation.stationCalls.first,
      qso: const {},
      operation: operation.data,
      online: false,
    );
    final ourGuess = asQsonMap(ourInfo?['guess']);
    if (_disposed) return;
    _ourEntityPrefix = asQsonString(ourGuess?['entityPrefix']);
    _ourItuRegion = asQsonNum(ourGuess?['ituRegion'])?.toInt();
    _ourCountryCode = asQsonString(ourGuess?['countryCode']);
    notifyListeners();
  }

  /// Rescores under the new runtime, and retries [refreshControls] against
  /// [controlsOperation] once it is live again, but only when the last fetch
  /// actually failed — every runtime restart (any extension anywhere being
  /// toggled) ticks the generation, and most of those have nothing to do
  /// with this operation's controls.
  ///
  /// The rescore is unconditional: a tick invalidates every cached
  /// checkpoint ([ScoringService.liveResumeFor]), and until a pass under the
  /// new runtime folds the log, every call-info keystroke and spots refresh
  /// folds the whole log cold and the summaries show the old scorers'.
  void runtimeRestarted() {
    _lastScoredFingerprint = null;
    scheduleRescore();
    if (!_loggingControlsStale && !_operationControlsStale) return;
    final operation = controlsOperation();
    if (operation == null) return;
    unawaited(refreshControls(operation));
  }

  /// The log changed: any scoring-relevant change reschedules the rescore.
  void qsosChanged(List<Qso> qsos) {
    _latestQsos = qsos;
    scheduleRescore();
  }

  /// Debounced live rescore. Fires only when the fingerprint moves, and
  /// records it only once a rescore actually runs with a host — so an edit that arrives while the runtime is still booting
  /// isn't silently marked scored. The score-cache/localData writes a rescore
  /// makes flow back to the UI through the QSO and operation streams; neither
  /// perturbs the fingerprint (`local_data` carries no stamp), so there's no
  /// feedback loop.
  void scheduleRescore() {
    final fingerprint = '${currentOperation()?.updatedAtMillis}|${logFingerprintFor(_latestQsos)}';
    if (fingerprint == _lastScoredFingerprint) return;
    _rescoreDebounce?.cancel();
    _rescoreDebounce = Timer(rescoreDelay, () async {
      final operation = currentOperation();
      if (operation == null || services.extensions.host == null) {
        return; // not ready — retried on the next change, or when the runtime comes up
      }
      _lastScoredFingerprint = fingerprint;
      await services.scoring.rescoreOperation(operation);
    });
  }

  @override
  void dispose() {
    _disposed = true;
    _rescoreDebounce?.cancel();
    // Nothing retries for a closed view, so its notice would stay up with no
    // operation open. The key is every Operation view's: closing one stacked
    // over another that also failed takes the lower one's notice with it.
    if (_loggingControlsStale) services.statusBar.clear('operation:logging-controls-stale');
    super.dispose();
  }
}
