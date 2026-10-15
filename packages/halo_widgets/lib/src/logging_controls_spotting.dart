// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The Spotting control: posting a spot to whichever `spots` hooks offer it —
// a self-spot at the VFO's frequency while composing, or a spot of the
// station in an existing QSO while it is still recent enough to be worth
// one (ham2k/halo-dist#10). [SpottingControlModel] holds the comment, the
// sources on offer, the per-source outcome of the last send and
// auto-respotting on behalf of `LoggingControls`;
// [SpottingControlFields] draws the expanded row.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:halo_core/halo_core.dart';
import 'package:halo_i18n/halo_i18n.dart';

import 'call_info_summary.dart';
import 'icon_resolver.dart';
import 'logging_controls_types.dart';
import 'mdi_icons.g.dart';
import 'panel_model.dart';
import 'secondary_control_row.dart' show SecondaryControlSpec;
import 'spacing.dart';
import 'theme.dart';

/// What the model reads from the panel's live configuration — re-read on
/// every use, because the hooks, the edited QSO and the operation all change
/// under a mounted panel.
///
/// `notice` tells the operator why a spot or auto-respotting did not go ahead
/// when nothing on screen would: a typed command's, or auto-respotting
/// stopping on its own.
typedef SpottingConfig = ({
  SendSpot? sendSpot,
  SuggestSpotSources? suggestSpotSources,
  VfoStore? radioService,
  Qso? editingQso,
  Operation operation,
  ValueChanged<String>? notice,
});

/// The Spotting control's summary, button text and enabled state, resolved
/// once per build from the state machine in [SpottingControlModel.state].
typedef SpottingState = ({String summary, String buttonLabel, bool enabled, bool showComment});

/// A self-spot every source took — what an auto-respot repeats — the
/// operation it announced, and when it went out, on the real clock (see
/// [SpottingControlModel.respotGlow]).
typedef _SelfSpot = ({double freq, String? comment, String operationUuid, int atRealMillis});

/// The Spotting control's state. See the file comment.
class SpottingControlModel extends ChangeNotifier with PanelModel {
  SpottingControlModel({required this.config}) {
    // Enter in the comment field sends. The Send button has no FocusNode of
    // its own — Tab never reaches it, the same accepted gap the main Log
    // button has (logging-fields.md) — so Enter here is the substitute, the
    // way Enter from any main field reaches Log. Ignored rather than handled,
    // so the ladder's handler on the control still closes it afterwards —
    // except while another spot (an auto-respot) is in flight: this one
    // cannot go, so the operator is told and the control stays open with
    // the comment for another go.
    commentFocus.onKeyEvent = (node, event) {
      if ((event is KeyDownEvent || event is KeyRepeatEvent) &&
          (event.logicalKey == LogicalKeyboardKey.enter || event.logicalKey == LogicalKeyboardKey.numpadEnter) &&
          state.enabled) {
        if (_sending) {
          if (event is KeyDownEvent) _notice(t.loggingControls.spotBusy);
          return KeyEventResult.handled;
        }
        unawaited(press());
      }
      return KeyEventResult.ignored;
    };
  }

  /// The panel's configuration as it stands right now.
  final SpottingConfig Function() config;

  /// UI-level policy, not a per-source value: how recently a QSO must have
  /// started for the button to offer spotting it at all. This is deliberately
  /// NOT part of `SpotEligibility` — no spots source today needs a different
  /// tolerance (POTA is the only `postOtherSpot` implementation; SOTA has no
  /// posting support yet, see DESIGN notes on ham2k/halo-dist#10), so
  /// making it hook-reported would be speculative. Revisit if a second
  /// source ever needs its own window.
  static const Duration staleAfter = Duration(minutes: 5);

  /// How often auto-respotting repeats a self-spot, unless RESPOT asked for
  /// another interval.
  static const Duration respotInterval = Duration(minutes: 10);

  /// The shortest interval RESPOT may ask for: the spots go to public
  /// clusters, and an extension's action is held to it like a typed one.
  static const Duration minRespotInterval = Duration(minutes: 5);

  /// The longest: past it a spot has aged off every cluster anyway, and a
  /// `Timer` on the web fires at once for anything past 2^31 ms.
  static const Duration maxRespotInterval = Duration(minutes: 60);

  /// How soon the sources that refused an auto-respot are asked again — once,
  /// and only those: the ones that took it wait for the next round, or a
  /// refusal anywhere would spot the rest every thirty seconds, and a source
  /// that keeps refusing would be asked 120 times an hour.
  static const Duration respotRetry = Duration(seconds: 30);

  /// How far, in kHz, the VFO may sit from a spotted frequency and still be
  /// on it — CAT reports to the hertz, and a nudge of the dial is not a QSY.
  static const double sameFrequencyTolerance = 0.5;

  /// How long the button offers auto-respotting after a self-spot, before it
  /// goes back to offering a plain one (app-polo's window).
  static const Duration respotOfferWindow = Duration(seconds: 10);

  /// How long before a respot the chip's icon starts to glow.
  static const Duration respotGlowLead = Duration(minutes: 1);

  /// Comments that announce a one-off change rather than an ongoing
  /// activation, by their leading Q-code (`QRT`, `QRT, 73`, `QSY/40m`):
  /// repeating one says something false, so a self-spot carrying one is never
  /// repeated, and a typed one ends auto-respotting.
  static final RegExp oneOffQCode = RegExp(r'^(QRV|QRT|QSY|QRX)\b', caseSensitive: false);

  final commentController = TextEditingController();
  final commentFocus = FocusNode();

  /// Which `spots` hooks currently offer self- or other-spotting, for the
  /// control's icon row — shown before sending, not just after.
  List<Map<String, dynamic>> _sources = const [];
  List<Map<String, dynamic>> get sources => _sources;

  /// hookKey → ok / failed / neutral (null), for the last send.
  final Map<String, bool?> _status = {};
  bool? statusOf(String hookKey) => _status[hookKey];

  Timer? _statusClearTimer;
  bool _sending = false;
  bool get sending => _sending;

  /// The last self-spot every source took, while auto-respotting can still
  /// repeat it.
  _SelfSpot? _selfSpot;

  bool _offeringRespot = false;
  Timer? _offerTimer;

  bool _autoRespotting = false;
  Duration _respotEvery = respotInterval;
  Timer? _respotTimer;

  /// Fires as the next auto-respot comes within [respotGlowLead], so the
  /// chip redraws its icon every second only while it glows.
  Timer? _glowTimer;
  bool _glowing = false;

  /// Whether the next auto-respot is close enough for the chip to glow.
  bool get respotGlowing => _glowing;

  /// When the next auto-respot is due, on the real clock: it paces a real
  /// request, and [_respotTimer] counts real time whatever the app clock is
  /// travelled to.
  int? _respotDueRealMillis;

  /// When the current round of auto-respots went out (real clock), and which
  /// sources refused it and are owed their one retry.
  int _roundAtRealMillis = 0;
  final Set<String> _retry = {};

  /// Whether the last round found the VFO with no frequency, and is waiting
  /// out its one retry for the radio to come back.
  bool _awaitingVfo = false;

  /// Whether auto-respotting is on. The panel ends it when the VFO leaves the
  /// spotted frequency ([followVfo]); disposing the panel (leaving the
  /// operation) ends it too, and nothing about it persists.
  bool get autoRespotting => _autoRespotting;

  @override
  void dispose() {
    _statusClearTimer?.cancel();
    _offerTimer?.cancel();
    _respotTimer?.cancel();
    _glowTimer?.cancel();
    commentController.dispose();
    commentFocus.dispose();
    super.dispose();
  }

  /// Resolves the control's summary/button text and enabled state per the
  /// issue's exact state machine (ham2k/halo-dist#10): no VFO frequency
  /// disables self-spotting; editing a QSO switches to spotting that QSO's
  /// station instead, only while it's recent enough. `summary` (the collapsed
  /// pill) is always one of the two short, fixed labels —
  /// "Self-spotting"/"Spotting" — never the longer dynamic messages, which
  /// are reserved for the button inside the expanded panel.
  SpottingState get state {
    final cfg = config();
    final editingQso = cfg.editingQso;
    if (editingQso != null) {
      final call = asQsonString(asQsonMap(editingQso.data['their'])?['call']) ?? '?';
      final ageMillis = editingQso.startAtMillis == null ? null : nowMillis() - editingQso.startAtMillis!;
      final tooOld = ageMillis == null || ageMillis > staleAfter.inMilliseconds;
      final summary = t.loggingControls.spottingControl;
      // No source is offered for it (`suggestSpotSources`), so an enabled
      // button would send to nobody and say nothing.
      if (editingQso.hasIncompleteCall) {
        return (summary: summary, buttonLabel: t.spotting.incompleteCall, enabled: false, showComment: false);
      }
      if (tooOld) {
        return (summary: summary, buttonLabel: t.loggingControls.spotTooLate(call: call), enabled: false, showComment: false);
      }
      final freqLabel = editingQso.freq == null ? '' : fmtFreq(editingQso.freq!);
      return (summary: summary, buttonLabel: t.loggingControls.spotOtherAt(call: call, freq: freqLabel), enabled: true, showComment: true);
    }

    final vfoFreq = cfg.radioService?.vfoA.freq;
    if (_autoRespotting) {
      return (summary: t.loggingControls.spottingAutoControl, buttonLabel: t.loggingControls.spotAutoStop, enabled: true, showComment: false);
    }
    final summary = t.loggingControls.spottingSelfControl;
    if (vfoFreq == null) {
      return (summary: summary, buttonLabel: t.loggingControls.spotNoFreq, enabled: false, showComment: false);
    }
    if (_offeringRespot) {
      return (summary: summary, buttonLabel: t.loggingControls.spotAutoEvery(minutes: respotInterval.inMinutes), enabled: true, showComment: true);
    }
    final freqLabel = fmtFreq(vfoFreq);
    return (summary: summary, buttonLabel: t.loggingControls.spotSelfAt(freq: freqLabel), enabled: true, showComment: true);
  }

  /// The operation as a spot sees it: its shared data plus `local`, this
  /// device's own — where the multi-station identifier that turns `KI2D` into
  /// `KI2D/OP1` lives. Mirrors app-polo's `operation.local`;
  /// `ExtensionService.spotCallForSelfSpot` is what reads it.
  ///
  /// Only the identifier, not the whole of `localData`: the scoring cache and
  /// the title fragments live there too, and neither belongs on the wire to
  /// every spot extension on every spot.
  Map<String, dynamic> get operationPayload {
    final operation = config().operation;
    return {
      ...operation.data,
      'local': {'multiIdentifier': operation.localData['multiIdentifier']},
    };
  }

  /// Drops the sources and the last send's outcome — the QSO context changed
  /// under them. The caller refreshes and rebuilds.
  void forgetSources() {
    _sources = const [];
    _status.clear();
  }

  /// Re-asks the hooks which sources offer spotting for the current context.
  Future<void> refreshSources() async {
    final suggest = config().suggestSpotSources;
    if (suggest == null) return;
    final cfg = config();
    final sources = await suggest(operation: cfg.operation.data, qso: cfg.editingQso?.data);
    if (isDisposed) return;
    _sources = sources;
    notify();
  }

  /// The spotting command actions, which the panel hands over whole.
  ///
  /// `sendSpots` (SPOT and the Q-codes): a self-spot is this control's own,
  /// sent as the button's is, so what auto-respotting repeats is a spot it
  /// saw go out. SPOTLAST (`target: 'last'`) resolves *who* gets spotted
  /// here — the command hook only parsed text into a target — and the spot
  /// itself is the app's ([forward]): the most recent real (non-event) QSO,
  /// regardless of what's being edited. [qsos] is oldest-first (see
  /// `watchForOperation`), so the last real contact is `lastWhere`, not
  /// `firstWhere`.
  ///
  /// `autoRespot` (RESPOT) runs this control's own auto-respotting, so the
  /// chip, the button and the respots are one, however it was started.
  ///
  /// Either goes on to the app ([forward]) once run, with why it could not go
  /// ahead, if it could not: the app answers a command where it was typed —
  /// the command bar's own line, which a notice here would land behind — in
  /// place of its confirmation, and counts it.
  Future<void> runCommandAction(Map<String, dynamic> action, {required List<Qso> qsos, required CommandActionHandler? forward}) async {
    if (action['autoRespot'] case final Map<dynamic, dynamic> params) {
      final minutes = params['minutes'];
      // 0 is RESPOT 0: off, as OFF is.
      final off = params['off'] == true || (minutes is num && minutes <= 0);
      if (off) stopAutoRespotting();
      final failure = off ? null : await respotEvery(minutes is num ? minutes : respotInterval.inMinutes);
      return _reportRan('autoRespot', {'failure': ?failure}, forward);
    }
    final params = (action['sendSpots'] as Map).cast<String, dynamic>();
    final comment = params['comment'] as String?;
    if (params['target'] != 'last') {
      final failure = (await _spotSelf(comment)).failure;
      return _reportRan('sendSpots', {'target': 'self', 'failure': ?failure}, forward);
    }
    final qso = qsos.cast<Qso?>().lastWhere((q) => q!.isRealContact, orElse: () => null);
    await forward?.call('sendSpots', {'operation': operationPayload, 'target': 'last', if (qso != null) 'qso': qso.data, 'comment': ?comment});
  }

  /// A command this control ran, on to the app; with no app to answer it,
  /// its failure is a notice here.
  Future<void> _reportRan(String action, Map<String, dynamic> outcome, CommandActionHandler? forward) async {
    if (forward == null) return _notice(outcome['failure'] as String?);
    await forward(action, outcome);
  }

  void _notice(String? text) {
    if (text != null && !isDisposed) config().notice?.call(text);
  }

  /// The button: stops auto-respotting while it runs, starts it while it is
  /// on offer, and otherwise sends a spot.
  Future<void> press() async {
    if (_sending) return;
    if (config().editingQso == null) {
      if (_autoRespotting) return stopAutoRespotting();
      // A comment typed while it is on offer is a new spot, not a yes to
      // repeating the last one.
      if (_offeringRespot && commentController.text.trim().isEmpty) return _repeatSelfSpot(respotInterval);
    }
    await send();
  }

  /// Posts the spot. A self-spot every source took is offered for
  /// auto-respotting for [respotOfferWindow], unless it announces a one-off
  /// change ([oneOffQCode]).
  Future<void> send() async {
    final cfg = config();
    if (cfg.sendSpot == null || _sending) return;
    final comment = commentController.text.trim();
    final editingQso = cfg.editingQso;
    if (editingQso == null) {
      final spotted = await _spotSelf(comment.isEmpty ? null : comment, onAnswered: commentController.clear);
      if (isDisposed || spotted.spot == null) return;
      _offeringRespot = true;
      _offerTimer?.cancel();
      _offerTimer = Timer(respotOfferWindow, () {
        if (isDisposed) return;
        _offeringRespot = false;
        notify();
      });
      notify();
      return;
    }
    // [sources] as they are now: the panel can reset and repopulate them (the
    // user switches to editing a different QSO) while this send is in flight,
    // and the status icons must key off what was actually sent.
    await _post(sources: _sources, qso: editingQso.data, comment: comment.isEmpty ? null : comment, onAnswered: commentController.clear);
  }

  /// Sends a self-spot at the VFO — the button's, a typed one's, RESPOT's —
  /// to every source offering one.
  ///
  /// A one-off announcement ([oneOffQCode]) ends auto-respotting whether or
  /// not it goes through: the operator is leaving or moving either way. Any
  /// other that every source took, with the VFO still on its frequency,
  /// becomes what auto-respotting repeats, a running one re-timed from it.
  /// Returns why it did not go through, or the spot it recorded.
  Future<({String? failure, _SelfSpot? spot})> _spotSelf(String? comment, {VoidCallback? onAnswered}) async {
    // An offer standing from an earlier spot would repeat that one, or —
    // after a one-off — nothing at all.
    _withdrawOffer();
    if (_isOneOff(comment)) {
      _selfSpot = null;
      if (_autoRespotting) stopAutoRespotting();
    }
    final cfg = config();
    final vfo = cfg.radioService?.vfoA;
    final freq = vfo?.freq;
    if (freq == null) return (failure: t.spotting.setFrequencyFirst, spot: null);
    final suggest = cfg.suggestSpotSources;
    if (cfg.sendSpot == null || suggest == null) return (failure: t.spotting.nothingToSpot, spot: null);
    final sources = await suggest(operation: cfg.operation.data, qso: null);
    if (isDisposed) return (failure: null, spot: null);
    if (sources.isEmpty) return (failure: t.spotting.nothingToSpot, spot: null);
    final results = await _post(sources: sources, freq: freq, mode: vfo?.mode, comment: comment, onAnswered: onAnswered);
    if (isDisposed) return (failure: null, spot: null);
    if (results == null) return (failure: t.loggingControls.spotBusy, spot: null);
    final failure = spotFailureText(sources, results);
    if (failure != null || _refusedBy(sources, results).isNotEmpty || _isOneOff(comment) || !_onFrequency(freq)) {
      return (failure: failure, spot: null);
    }
    final spot = (freq: freq, comment: comment, operationUuid: cfg.operation.uuid, atRealMillis: realNowMillis());
    _selfSpot = spot;
    if (_autoRespotting) {
      _roundAtRealMillis = spot.atRealMillis;
      _retry.clear();
      _scheduleNext();
      notify();
    }
    return (failure: null, spot: spot);
  }

  /// RESPOT: repeats the self-spot at the VFO every [minutes] (held between
  /// [minRespotInterval] and [maxRespotInterval], whatever an extension's
  /// action asks for) — the one taken there already when there is one, timed
  /// from when it went out, or else one sent now. Returns why it could not
  /// start, or null.
  Future<String?> respotEvery(num minutes) async {
    // Clamped before it becomes a Duration: a huge number overflows one.
    final every = Duration(seconds: (minutes.clamp(minRespotInterval.inMinutes, maxRespotInterval.inMinutes) * 60).round());
    final freq = config().radioService?.vfoA.freq;
    if (freq == null) return t.spotting.setFrequencyFirst;
    final spot = _ownSelfSpot;
    if (spot == null || !_onFrequency(spot.freq)) {
      final spotted = await _spotSelf(null);
      if (isDisposed) return null;
      if (spotted.failure != null) return spotted.failure;
      if (spotted.spot == null) return _onFrequency(freq) ? t.loggingControls.spotAutoNotStarted : t.loggingControls.spotAutoMoved;
    }
    _repeatSelfSpot(every);
    return null;
  }

  /// Turns auto-respotting on for [_selfSpot], the first round falling
  /// [every] after it went out — or, already on, re-times it to [every].
  void _repeatSelfSpot(Duration every) {
    final spot = _ownSelfSpot;
    if (spot == null) return;
    _withdrawOffer();
    if (!_autoRespotting) {
      _roundAtRealMillis = spot.atRealMillis;
      _retry.clear();
      _awaitingVfo = false;
    }
    _autoRespotting = true;
    _respotEvery = every;
    _scheduleNext();
    notify();
  }

  void stopAutoRespotting() {
    _respotTimer?.cancel();
    _respotTimer = null;
    _glowTimer?.cancel();
    _glowing = false;
    _respotDueRealMillis = null;
    _retry.clear();
    _awaitingVfo = false;
    _autoRespotting = false;
    notify();
  }

  /// [_selfSpot], unless another operation's: a panel handed another
  /// operation must not announce this one's frequency and comment as its.
  _SelfSpot? get _ownSelfSpot {
    final spot = _selfSpot;
    return spot != null && spot.operationUuid == config().operation.uuid ? spot : null;
  }

  void _withdrawOffer() {
    _offerTimer?.cancel();
    _offeringRespot = false;
  }

  /// Auto-respotting stopping on its own, which the operator is told: the chip
  /// changing is easy to miss, and they would go on believing spots go out.
  void _stopWith(String notice) {
    stopAutoRespotting();
    _notice(notice);
  }

  /// Whether the VFO is on [freq], within [sameFrequencyTolerance].
  bool _onFrequency(double freq) {
    final vfoFreq = config().radioService?.vfoA.freq;
    return vfoFreq != null && (vfoFreq - freq).abs() <= sameFrequencyTolerance;
  }

  /// The VFO moved: a respot would announce a frequency the operator has
  /// left, and an offer to start one would too. A VFO that reports no
  /// frequency (a radio reconnecting) has not moved.
  void followVfo() {
    final spotted = _selfSpot?.freq;
    if (spotted == null || config().radioService?.vfoA.freq == null || _onFrequency(spotted)) return;
    _selfSpot = null;
    _withdrawOffer();
    if (_autoRespotting) {
      _stopWith(t.loggingControls.spotAutoLeftFreq);
    } else {
      notify();
    }
  }

  /// The chip icon's glow: none until [respotGlowLead] before the next
  /// auto-respot, then rising to full strength as it comes due.
  double get respotGlow {
    final due = _respotDueRealMillis;
    if (due == null) return 0;
    final remaining = due - realNowMillis();
    final lead = respotGlowLead.inMilliseconds;
    if (remaining >= lead) return 0;
    return (1 - remaining / lead).clamp(0.0, 1.0);
  }

  void _scheduleRespot(Duration after) {
    _respotTimer?.cancel();
    _respotDueRealMillis = realNowMillis() + after.inMilliseconds;
    _respotTimer = Timer(after, () => unawaited(_respot()));
    _glowTimer?.cancel();
    _glowing = false;
    final untilGlow = after - respotGlowLead;
    _glowTimer = Timer(untilGlow.isNegative ? Duration.zero : untilGlow, () {
      _glowing = true;
      notify();
    });
  }

  /// The owed retry in [respotRetry], or else the next round [_respotEvery]
  /// after the last.
  void _scheduleNext() {
    if (_retry.isNotEmpty) return _scheduleRespot(respotRetry);
    final wait = _roundAtRealMillis + _respotEvery.inMilliseconds - realNowMillis();
    _scheduleRespot(Duration(milliseconds: wait < 0 ? 0 : wait));
  }

  /// A round: [_selfSpot] to every source on offer — or, owed a retry, to
  /// the sources that refused the round, once.
  Future<void> _respot() async {
    final spot = _selfSpot;
    if (isDisposed || !_autoRespotting || spot == null) return;
    final cfg = config();
    final suggest = cfg.suggestSpotSources;
    if (cfg.operation.uuid != spot.operationUuid) return _stopWith(t.loggingControls.spotAutoStopped);
    if (cfg.sendSpot == null || suggest == null) return _stopWith(t.spotting.nothingToSpot);
    final vfoFreq = cfg.radioService?.vfoA.freq;
    if (vfoFreq != null && !_onFrequency(spot.freq)) return followVfo();
    // A reconnecting radio says nothing about where it is: it gets one retry
    // to come back, and then the operator is told — spots that silently
    // stop going out are what the chip saying "Auto spots" must not hide.
    if (vfoFreq == null) {
      if (_awaitingVfo) return _stopWith(t.loggingControls.spotAutoNoFreq);
      _awaitingVfo = true;
      return _scheduleRespot(respotRetry);
    }
    _awaitingVfo = false;
    // A manual send in flight: try again shortly.
    if (_sending) return _scheduleRespot(respotRetry);
    var finished = false;
    try {
      // Asked afresh, with no QSO: the panel's own [sources] are another
      // spot's while a QSO is open for editing.
      final sources = await suggest(operation: cfg.operation.data, qso: null);
      if (isDisposed || !_autoRespotting) return;
      if (sources.isEmpty) return _stopWith(t.spotting.nothingToSpot);
      final retrying = _retry.isNotEmpty;
      final targets = retrying
          ? [
              for (final source in sources)
                if (_retry.contains(_hookKey(source))) source,
            ]
          : sources;
      if (!retrying) _roundAtRealMillis = realNowMillis();
      _retry.clear();
      if (targets.isNotEmpty) {
        final results = await _post(sources: targets, freq: spot.freq, mode: cfg.radioService?.vfoA.mode, comment: spot.comment);
        // A manual send got in first: its sources are owed the round.
        if (results == null) {
          _retry.addAll(targets.map(_hookKey));
        } else if (!retrying) {
          _retry.addAll(_refusedBy(targets, results));
        } else {
          // Refused twice, the round is lost for those sources: said once a
          // round, since the source icons alone are easy to miss.
          _notice(spotFailureText(targets, results));
        }
      }
      finished = true;
    } finally {
      // A hook that threw has no answer to retry on: stopping, and saying so,
      // beats a loop that keeps calling it or a chip that keeps saying "Auto
      // spots". The error itself goes on to the zone.
      if (!isDisposed && _autoRespotting) {
        if (finished) {
          _scheduleNext();
          notify();
        } else {
          _stopWith(t.loggingControls.spotAutoStopped);
        }
      }
    }
  }

  static String _hookKey(Map<String, dynamic> source) => source['hookKey'] as String? ?? '';

  /// The sources among [sources] that did not take a spot — refused, or never
  /// answered.
  static Set<String> _refusedBy(List<Map<String, dynamic>> sources, Map<String, Map<String, dynamic>> results) => {
    for (final source in sources)
      if (results[_hookKey(source)]?['ok'] != true) _hookKey(source),
  };

  /// Whether [comment] announces a one-off change ([oneOffQCode]).
  static bool _isOneOff(String? comment) => comment != null && oneOffQCode.hasMatch(comment.trim());

  /// Posts one spot to [sources], and colours each source's icon by its answer
  /// for three minutes — a self-spot's only while the row shows self-spotting,
  /// or its answers would paint the icons of the QSO open for editing. Returns
  /// the answers, or null — sending nothing — while another spot is in
  /// flight: two at once would each clear the other's colours, and the first
  /// to land would re-enable the button.
  Future<Map<String, Map<String, dynamic>>?> _post({
    required List<Map<String, dynamic>> sources,
    Map<String, dynamic>? qso,
    double? freq,
    String? mode,
    String? comment,
    VoidCallback? onAnswered,
  }) async {
    final sendSpot = config().sendSpot;
    if (_sending) return null;
    if (sendSpot == null) return const {};
    // Colors from a previous attempt would misread as THIS attempt's
    // results while the send is in flight — back to neutral gray first.
    bool paints() => qso != null || config().editingQso == null;
    _sending = true;
    if (paints()) _status.clear();
    notify();
    try {
      final results = await sendSpot(sources: sources, operation: operationPayload, qso: qso, freq: freq, mode: mode, comment: comment);
      if (isDisposed) return results;
      if (!paints()) {
        onAnswered?.call();
        return results;
      }
      for (final source in sources) {
        final hookKey = _hookKey(source);
        final result = results[hookKey];
        _status[hookKey] = result == null ? null : result['ok'] == true;
      }
      onAnswered?.call();
      notify();
      _statusClearTimer?.cancel();
      // Explicit 3-minute color-clear (no app-polo equivalent to diverge
      // from — its own SpotterControl only resets colors on the next
      // attempt).
      _statusClearTimer = Timer(const Duration(minutes: 3), () {
        if (isDisposed) return;
        _status.clear();
        notify();
      });
      return results;
    } finally {
      if (!isDisposed) {
        _sending = false;
        notify();
      }
    }
  }
}

/// What the operator is told about a spot that did not go through, or null
/// when it did. Only failures are told: a successful spot already shows in
/// the Spotting control's per-source status icons, and a "Spotted on X"
/// notice on top of that is a confirmation nobody asked to acknowledge. A
/// refusal has to surface, since the icon alone is easy to miss — and no
/// answer from any source means the spot never went anywhere, which is its
/// own failure.
String? spotFailureText(List<Map<String, dynamic>> sources, Map<String, Map<String, dynamic>> results) {
  var anyResult = false;
  final failures = <String>[];
  for (final source in sources) {
    final hookKey = source['hookKey'] as String? ?? '?';
    final result = results[hookKey];
    if (result == null) continue;
    anyResult = true;
    if (result['ok'] != true) {
      failures.add(t.spotting.spotFailed(source: hookKey, message: (result['message'] as Object?) ?? t.spotting.unknownError));
    }
  }
  if (!anyResult) return t.spotting.notSent;
  return failures.isEmpty ? null : failures.join('; ');
}

/// The Spotting control's expanded row: the comment field, the send button,
/// and one status icon per source on offer.
class SpottingControlFields extends StatelessWidget {
  const SpottingControlFields({super.key, required this.model, required this.state, required this.theme, required this.colors});

  final SpottingControlModel model;

  /// [SpottingControlModel.state], resolved once by the spec for both the
  /// chip's summary and this row.
  final SpottingState state;

  /// The panel's accent theme — the row is painted on it.
  final ThemeData theme;
  final HaLoColors colors;

  @override
  Widget build(BuildContext context) {
    final sources = model.sources;
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        if (state.showComment)
          SizedBox(
            width: 160,
            child: TextField(
              controller: model.commentController,
              focusNode: model.commentFocus,
              // Explicitly mixed-case, like Name/Notes: a spot comment is
              // free prose for other operators, not logging data.
              style: haloMonoStyle(context, fontSize: 15, fontWeight: FontWeight.w500),
              decoration: poloFieldDecoration(context, t.loggingControls.spotComment, labelColor: theme.colorScheme.onTertiaryContainer),
            ),
          ),
        const SizedBox(width: Space.sm),
        FilledButton.icon(
          style: FilledButton.styleFrom(
            backgroundColor: theme.colorScheme.tertiaryContainer,
            foregroundColor: theme.colorScheme.onTertiaryContainer,
            disabledBackgroundColor: theme.colorScheme.tertiaryContainer.withValues(alpha: 0.4),
          ),
          onPressed: state.enabled && !model.sending ? model.press : null,
          icon: model.sending ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(MdiIcons.handWave),
          label: Text(state.buttonLabel),
        ),
        // Up to 3 source-status icons per column, wrapping into another
        // column to the right once a column fills up.
        for (var i = 0; i < sources.length; i += 3)
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final source in sources.skip(i).take(3))
                Padding(
                  padding: const EdgeInsets.only(left: Space.xs, top: Space.xxs, bottom: Space.xxs),
                  child: Icon(
                    resolveIconName(source['icon'] as String?, fallback: MdiIcons.radioTower),
                    size: 16,
                    color: switch (model.statusOf(source['hookKey'] as String? ?? '')) {
                      true => colors.important,
                      false => theme.colorScheme.error,
                      null => theme.colorScheme.onTertiaryContainer,
                    },
                    shadows: glyphGlow(theme),
                  ),
                ),
            ],
          ),
      ],
    );
  }
}

/// The Spotting chip's glyph — the settings dialog's entry reads this too.
const spottingChipIcon = MdiIcons.handWave;

/// The Spotting chip and its expanded fields, read from [model].
SecondaryControlSpec spottingControlSpec(SpottingControlModel model, ThemeData theme, HaLoColors colors) {
  final state = model.state;
  return SecondaryControlSpec(
    key: 'spotting',
    icon: spottingChipIcon,
    summary: state.summary,
    liveIconGlow: model.respotGlowing ? () => model.respotGlow : null,
    expandedBuilder: (context) => SpottingControlFields(model: model, state: state, theme: theme, colors: colors),
  );
}
