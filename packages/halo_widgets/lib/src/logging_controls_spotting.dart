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
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:halo_core/halo_core.dart';
import 'package:halo_i18n/halo_i18n.dart';

import 'call_info_summary.dart';
import 'hover_label.dart';
import 'icon_resolver.dart';
import 'logging_controls_types.dart';
import 'mdi_icons.g.dart';
import 'panel_model.dart';
import 'secondary_control_row.dart' show SecondaryControlSpec;
import 'spacing.dart';
import 'theme.dart';
import 'wall_clock.dart' show OncePerSecond;

/// What the model reads from the panel's live configuration — re-read on
/// every use, because the hooks, the edited QSO and the operation all change
/// under a mounted panel.
///
/// `notice` tells the operator why a spot or auto-respotting did not go ahead
/// when nothing on screen would: a typed command's, or auto-respotting
/// stopping on its own. The rest are the operator's Spotting settings
/// ([SpottingHooks]).
typedef SpottingConfig = ({
  SendSpot? sendSpot,
  SuggestSpotSources? suggestSpotSources,
  VfoStore? radioService,
  Qso? editingQso,
  Operation operation,
  ValueChanged<String>? notice,
  Duration respotInterval,
  bool autoRespotByDefault,
  bool pulseBeforeRespot,
  VoidCallback? onOpenSettings,
});

/// How a self-spot went: every source took it, some did, or none did.
enum SpotOutcome { allTook, someTook, noneTook }

/// The Spotting control's summary, button text and enabled state, resolved
/// once per build from the state machine in [SpottingControlModel.state].
typedef SpottingState = ({String summary, String buttonLabel, bool enabled, bool showComment});

/// A self-spot every source took — what an auto-respot repeats — the
/// operation it announced, and when it went out, on the real clock (see
/// [SpottingControlModel.respotGlow]).
typedef _SelfSpot = ({double freq, String? comment, String operationUuid, int atRealMillis});

/// How a self-spot went ([SpottingControlModel._spotSelf]): why it did not go
/// through, or the spot it recorded; [skipped] when every source skipped it,
/// which no source icon shows.
typedef _Spotted = ({String? failure, _SelfSpot? spot, bool skipped});

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

  /// How long a send's answers show: on the source icons, and fading from
  /// the chip's icon for a self-spot. Neither has an app-polo equivalent to
  /// diverge from — its SpotterControl only resets colors on the next send.
  static const Duration resultShownFor = Duration(minutes: 3);

  /// How long before a respot the chip's icon starts to glow.
  static const Duration respotGlowLead = Duration(minutes: 1);

  /// The pulse's stages, nearest the respot first: each runs until [left]
  /// remains, with that many [pulses] over its span — slow from twenty
  /// seconds out (about 2.2 s each), then one a second, then two a second
  /// for the last three. Whole pulses per stage keep the color at rest
  /// wherever the pace changes, and as the spot goes out: no jump.
  static const respotPulseStages = [(left: Duration(seconds: 3), pulses: 6), (left: Duration(seconds: 7), pulses: 4), (left: Duration(seconds: 20), pulses: 6)];

  /// How long before a respot the chip's icon and label pulse blue: the last
  /// moment to stop it, or to change frequency, before it goes out.
  static final Duration respotSoonLead = respotPulseStages.last.left;

  /// Comments that announce leaving or pausing rather than an ongoing
  /// activation, by their leading Q-code (`QRT`, `QRT, 73`, `QRX 5`):
  /// repeating one says something false, so a self-spot carrying one is never
  /// repeated, and a typed one ends auto-respotting.
  static final RegExp oneOffQCode = RegExp(r'^(QRT|QRX)\b', caseSensitive: false);

  /// Comments that announce arriving on a frequency (`QRV 20m`, `QSY/40m`):
  /// the station is on the air there, so the spot counts as a plain SPOT
  /// would — offered for, starting, or re-timing auto-respotting — but the
  /// repeats carry no comment, since "QSY" said again every few minutes is
  /// false.
  static final RegExp arrivalQCode = RegExp(r'^(QRV|QSY)\b', caseSensitive: false);

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
  late Duration _respotEvery;

  /// Whether [_respotEvery] is one RESPOT named, rather than the operator's
  /// setting.
  bool _intervalChosen = false;

  /// Whether a round is between its timer and its answers.
  bool _roundInFlight = false;
  Timer? _respotTimer;

  /// Fires as the next auto-respot comes within [respotGlowLead], so the
  /// chip redraws its icon every second only while it glows.
  Timer? _glowTimer;
  bool _glowing = false;

  /// Whether the next auto-respot is close enough for the chip to glow.
  bool get respotGlowing => _glowing;

  /// Fires as the next auto-respot comes within [respotSoonLead].
  Timer? _soonTimer;
  bool _soon = false;

  /// Whether the chip pulses now: the next auto-respot is within
  /// [respotSoonLead], and the operator has not turned the pulse off.
  bool get respotSoon => _soon && config().pulseBeforeRespot;

  /// The pulse in [respotSoonLead]: 0 the chip's own colors, 1 all blue,
  /// eased between. Read off the time left on the real clock, so the icon
  /// and the label — drawn separately — stay in step.
  double get respotPulse {
    final due = _respotDueRealMillis;
    if (!_soon || due == null) return 0;
    final left = due - realNowMillis();
    if (left <= 0) return 0;
    var from = 0;
    for (final stage in respotPulseStages) {
      final to = stage.left.inMilliseconds;
      if (left <= to) return (1 - math.cos(2 * math.pi * stage.pulses * (left - from) / (to - from))) / 2;
      from = to;
    }
    return 0;
  }

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

  /// The comment auto-respotting repeats, while it runs — the row shows it,
  /// in place of the comment field it cannot take.
  String? get respotComment => _autoRespotting ? _selfSpot?.comment : null;

  /// Whether auto-respotting is on. The panel ends it when the VFO leaves the
  /// spotted frequency ([followVfo]); disposing the panel (leaving the
  /// operation) ends it too, and nothing about it persists.
  bool get autoRespotting => _autoRespotting;

  /// How the last self-spot went, and when (real clock) — the chip's icon
  /// shows it for [resultShownFor], fading back to normal.
  SpotOutcome? _outcome;
  int _outcomeAtRealMillis = 0;
  Timer? _outcomeTimer;

  /// How the last self-spot went, while the chip still shows it.
  SpotOutcome? get outcome => _outcome;

  /// How strongly the chip shows [outcome]: 1 as it lands, fading to 0 over
  /// [resultShownFor].
  double get outcomeStrength {
    if (_outcome == null) return 0;
    return (1 - (realNowMillis() - _outcomeAtRealMillis) / resultShownFor.inMilliseconds).clamp(0.0, 1.0);
  }

  /// Shows [outcome] on the chip, null leaving it neutral and dropping an
  /// earlier spot's fading one — except while a QSO is open for editing,
  /// when the chip stands for spotting that QSO's station, and the station's
  /// own self-spot coloring it would read as that spot's answer. The source
  /// icons hold back for the same reason ([_post]).
  void _showOutcome(SpotOutcome? outcome) {
    if (config().editingQso != null) return;
    if (outcome == null) {
      _outcomeTimer?.cancel();
      _outcome = null;
      return notify();
    }
    _outcome = outcome;
    _outcomeAtRealMillis = realNowMillis();
    _outcomeTimer?.cancel();
    _outcomeTimer = Timer(resultShownFor, () {
      _outcome = null;
      notify();
    });
    notify();
  }

  /// How a spot went among the sources that did not skip it, or null — the
  /// chip neutral — when every one did: nothing went out, and nothing failed.
  /// Counted with the rest, a skip would turn a spot no source sent green.
  static SpotOutcome? _outcomeOf(List<Map<String, dynamic>> sources, Map<String, Map<String, dynamic>> results) {
    final answering = [
      for (final source in sources)
        if (!_skipped(results[_hookKey(source)])) source,
    ];
    if (answering.isEmpty) return null;
    final refused = _refusedBy(answering, results).length;
    if (refused == 0) return SpotOutcome.allTook;
    return refused < answering.length ? SpotOutcome.someTook : SpotOutcome.noneTook;
  }

  /// Whether [result] is a source declining a spot by its own rules (see
  /// `PostResult.skipped`): `skipped` without `ok` is still a failure.
  static bool _skipped(Map<String, dynamic>? result) => result?['ok'] == true && result?['skipped'] == true;

  /// The operator's auto-respot interval, held to what RESPOT may ask for.
  Duration get _interval {
    final every = config().respotInterval;
    if (every < minRespotInterval) return minRespotInterval;
    return every > maxRespotInterval ? maxRespotInterval : every;
  }

  @override
  void dispose() {
    _statusClearTimer?.cancel();
    _outcomeTimer?.cancel();
    _offerTimer?.cancel();
    _respotTimer?.cancel();
    _glowTimer?.cancel();
    _soonTimer?.cancel();
    commentController.dispose();
    commentFocus.dispose();
    super.dispose();
  }

  /// Resolves the control's summary/button text and enabled state per the
  /// issue's exact state machine (ham2k/halo-dist#10): no VFO frequency
  /// disables self-spotting; editing a QSO switches to spotting that QSO's
  /// station instead, only while it's recent enough. `summary` (the collapsed
  /// pill) stays short — "Self-spotting"/"Spotting", or the coarse
  /// auto-respot countdown — never the longer dynamic messages, which are
  /// reserved for the button inside the expanded panel.
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
      return (summary: _pillCountdown(), buttonLabel: t.loggingControls.spotAutoNext(time: _untilNextRespot()), enabled: true, showComment: false);
    }
    final summary = t.loggingControls.spottingSelfControl;
    if (vfoFreq == null) {
      return (summary: summary, buttonLabel: t.loggingControls.spotNoFreq, enabled: false, showComment: false);
    }
    if (_offeringRespot) {
      return (summary: summary, buttonLabel: t.loggingControls.spotAutoEvery(minutes: _interval.inMinutes), enabled: true, showComment: true);
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
  /// saw go out. SPOTLAST (`target: 'last'`) spots the most recent real
  /// (non-event) QSO, regardless of what's being edited — sent from here
  /// too, so the button shows it in flight and the icons colour by its
  /// answers. [qsos] is oldest-first (see `watchForOperation`), so the last
  /// real contact is `lastWhere`, not `firstWhere`.
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
      final failure = off ? null : await respotEvery(minutes is num ? minutes : null);
      return _reportRan('autoRespot', {'failure': ?failure}, forward);
    }
    final params = (action['sendSpots'] as Map).cast<String, dynamic>();
    final comment = params['comment'] as String?;
    if (params['target'] != 'last') {
      final freq = config().radioService?.vfoA.freq;
      final spotted = await _spotSelf(comment);
      final failure = spotted.failure ?? _autoStartAfter(spotted, comment, freq);
      return _reportRan('sendSpots', {'target': 'self', 'failure': ?failure}, forward);
    }
    final qso = qsos.cast<Qso?>().lastWhere((q) => q!.isRealContact, orElse: () => null);
    final failure = await _spotLast(qso, comment);
    return _reportRan('sendSpots', {'target': 'last', 'failure': ?failure}, forward);
  }

  /// SPOTLAST: spots [qso]'s station on every source offering it. Returns why
  /// it did not go through, or null.
  Future<String?> _spotLast(Qso? qso, String? comment) async {
    if (qso == null) return t.spotting.noQsoYet;
    // Said here, before [SpottingConfig.suggestSpotSources] offers nothing
    // for it and the operator reads that as no extension spotting at all.
    if (qso.hasIncompleteCall) return t.spotting.incompleteCall;
    final cfg = config();
    final suggest = cfg.suggestSpotSources;
    if (cfg.sendSpot == null || suggest == null) return t.spotting.nothingToSpot;
    final sources = await suggest(operation: cfg.operation.data, qso: qso.data);
    if (isDisposed) return null;
    if (sources.isEmpty) return t.spotting.nothingToSpot;
    final results = await _post(sources: sources, qso: qso.data, comment: comment);
    if (isDisposed) return null;
    if (results == null) return t.loggingControls.spotBusy;
    return spotFailureText(sources, results);
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
      if (_offeringRespot && commentController.text.trim().isEmpty) return _repeatSelfSpot(_interval);
    }
    await send();
  }

  /// Posts the spot. A self-spot every source took is offered for
  /// auto-respotting for [respotOfferWindow] — or, with the operator's
  /// auto-respot-by-default setting, starts it — unless it announces a
  /// one-off change ([oneOffQCode]).
  Future<void> send() async {
    final cfg = config();
    if (cfg.sendSpot == null || _sending) return;
    final comment = commentController.text.trim();
    final editingQso = cfg.editingQso;
    if (editingQso == null) {
      final freq = cfg.radioService?.vfoA.freq;
      final spotted = await _spotSelf(comment.isEmpty ? null : comment, onAnswered: commentController.clear);
      if (isDisposed) return;
      // Its source icons stay neutral: nothing else says the spot went
      // nowhere.
      if (spotted.skipped) return _notice(spotted.failure);
      // Why it did not start, not why the spot failed: a button spot's
      // failure shows on its source icons whatever this setting says.
      if (config().autoRespotByDefault) return _notice(_autoStartAfter(spotted, comment, freq));
      if (spotted.spot == null) return;
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
  /// not it goes through: the operator is leaving or pausing either way. Any
  /// other that every source took, with the VFO still on its frequency,
  /// becomes what auto-respotting repeats — an arrival ([arrivalQCode])
  /// without its comment — a running one re-timed from it.
  /// Returns why it did not go through, or the spot it recorded.
  Future<_Spotted> _spotSelf(String? comment, {VoidCallback? onAnswered}) async {
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
    if (freq == null) return (failure: t.spotting.setFrequencyFirst, spot: null, skipped: false);
    final suggest = cfg.suggestSpotSources;
    if (cfg.sendSpot == null || suggest == null) return (failure: t.spotting.nothingToSpot, spot: null, skipped: false);
    final sources = await suggest(operation: cfg.operation.data, qso: null);
    if (isDisposed) return (failure: null, spot: null, skipped: false);
    if (sources.isEmpty) return (failure: t.spotting.nothingToSpot, spot: null, skipped: false);
    final results = await _post(sources: sources, freq: freq, mode: vfo?.mode, comment: comment, onAnswered: onAnswered);
    if (isDisposed) return (failure: null, spot: null, skipped: false);
    if (results == null) return (failure: t.loggingControls.spotBusy, spot: null, skipped: false);
    final outcome = _outcomeOf(sources, results);
    _showOutcome(outcome);
    // Recorded, a spot nothing sent would be what auto-respotting repeats,
    // sending nothing every round under a chip saying "Auto re-spot".
    if (outcome == null) return (failure: _spotSkippedText(sources, results), spot: null, skipped: true);
    final failure = spotFailureText(sources, results);
    if (failure != null || _refusedBy(sources, results).isNotEmpty || _isOneOff(comment) || !_onFrequency(freq)) {
      return (failure: failure, spot: null, skipped: false);
    }
    final spot = (freq: freq, comment: _isArrival(comment) ? null : comment, operationUuid: cfg.operation.uuid, atRealMillis: realNowMillis());
    _selfSpot = spot;
    if (_autoRespotting) {
      _roundAtRealMillis = spot.atRealMillis;
      _retry.clear();
      _scheduleNext();
      notify();
    }
    return (failure: null, spot: spot, skipped: false);
  }

  /// With the auto-respot-by-default setting, starts auto-respotting on the
  /// self-spot just [spotted] — the button's, or a typed SPOT's — taken at
  /// [freq]. Returns why it did not start, which the operator is told: the
  /// setting promised it would. A one-off ([oneOffQCode]) is never expected
  /// to, and one already running was re-timed by the spot itself.
  String? _autoStartAfter(_Spotted spotted, String? comment, double? freq) {
    if (isDisposed || !config().autoRespotByDefault || _isOneOff(comment) || _autoRespotting) return null;
    if (spotted.spot != null) {
      _repeatSelfSpot(_interval);
      return null;
    }
    return freq != null && !_onFrequency(freq) ? t.loggingControls.spotAutoMoved : t.loggingControls.spotAutoNotStarted;
  }

  /// RESPOT: repeats the self-spot at the VFO every [minutes] (held between
  /// [minRespotInterval] and [maxRespotInterval], whatever an extension's
  /// action asks for), or at the operator's own interval with none — the one
  /// taken there already when there is one, timed from when it went out, or
  /// else one sent now. Returns why it could not start, or null.
  Future<String?> respotEvery([num? minutes]) async {
    // Clamped before it becomes a Duration: a huge number overflows one.
    final every = minutes == null ? _interval : Duration(seconds: (minutes.clamp(minRespotInterval.inMinutes, maxRespotInterval.inMinutes) * 60).round());
    final freq = config().radioService?.vfoA.freq;
    if (freq == null) return t.spotting.setFrequencyFirst;
    final spot = _ownSelfSpot;
    if (spot == null || !_onFrequency(spot.freq)) {
      final spotted = await _spotSelf(null);
      if (isDisposed) return null;
      if (spotted.failure != null) return spotted.failure;
      if (spotted.spot == null) return _onFrequency(freq) ? t.loggingControls.spotAutoNotStarted : t.loggingControls.spotAutoMoved;
    }
    _repeatSelfSpot(every, chosen: minutes != null);
    return null;
  }

  /// Turns auto-respotting on for [_selfSpot], the first round falling
  /// [every] after it went out — or, already on, re-times it to [every].
  /// [chosen] is an interval RESPOT named, which a change to the operator's
  /// setting leaves alone ([followIntervalSetting]).
  void _repeatSelfSpot(Duration every, {bool chosen = false}) {
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
    _intervalChosen = chosen;
    _scheduleNext();
    notify();
  }

  /// The operator's interval setting changed: a running auto-respot follows
  /// it at once, timed from its last round — the setting would otherwise
  /// show one interval while respots go out on another — unless RESPOT
  /// named its own. An owed retry or a wait for the radio keeps its 30 s,
  /// and a round still in flight schedules the next itself: rescheduled
  /// under it, a shorter interval would start a second round beside it.
  void followIntervalSetting() {
    if (!_autoRespotting || _intervalChosen || _respotEvery == _interval) return;
    _respotEvery = _interval;
    if (_retry.isEmpty && !_awaitingVfo && !_roundInFlight) _scheduleNext();
    notify();
  }

  void stopAutoRespotting() {
    _respotTimer?.cancel();
    _respotTimer = null;
    _glowTimer?.cancel();
    _glowing = false;
    _soonTimer?.cancel();
    _soon = false;
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

  /// Whole seconds until the next auto-respot, rounded up: 0 only once due.
  int get _secondsToRespot {
    final due = _respotDueRealMillis;
    return due == null ? 0 : ((due - realNowMillis()) / 1000).ceil().clamp(0, 1 << 30);
  }

  /// How long until the next auto-respot, as `m:ss` — the button counts it
  /// down. Rounded up, so it reads 0:01 rather than 0:00 until it goes.
  String _untilNextRespot() {
    final seconds = _secondsToRespot;
    return '${seconds ~/ 60}:${'${seconds % 60}'.padLeft(2, '0')}';
  }

  /// The collapsed chip's countdown, in coarse steps — whole minutes, then
  /// 30s, 15s, 10s, and the last five seconds one by one — each shown until
  /// the next step is reached, so the pill stays still and narrow while the
  /// expanded button carries the exact time. Due, with the round in flight,
  /// it names what it is doing rather than counting past zero.
  String _pillCountdown() {
    final seconds = _secondsToRespot;
    final l = t.loggingControls;
    if (seconds == 0) return l.spottingAutoControl;
    if (seconds > 30) return l.spotAutoInMinutes(minutes: (seconds / 60).ceil());
    if (seconds > 5) return l.spotAutoInSeconds(seconds: seconds > 15 ? 30 : (seconds > 10 ? 15 : 10));
    return l.spotAutoInCount(seconds: seconds);
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
    _respotTimer = Timer(after, () {
      // Due: the warning is over. Left on, the chip would redraw every
      // frame, showing nothing, for as long as the round's hooks take.
      _glowing = false;
      _soon = false;
      notify();
      unawaited(_respot());
    });
    _glowTimer?.cancel();
    _glowing = false;
    final untilGlow = after - respotGlowLead;
    _glowTimer = Timer(untilGlow.isNegative ? Duration.zero : untilGlow, () {
      _glowing = true;
      notify();
    });
    _soonTimer?.cancel();
    _soon = false;
    final untilSoon = after - respotSoonLead;
    _soonTimer = Timer(untilSoon.isNegative ? Duration.zero : untilSoon, () {
      _soon = true;
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
    // stop going out are what the chip saying "Auto re-spot" must not hide.
    if (vfoFreq == null) {
      if (_awaitingVfo) return _stopWith(t.loggingControls.spotAutoNoFreq);
      _awaitingVfo = true;
      return _scheduleRespot(respotRetry);
    }
    _awaitingVfo = false;
    // A manual send in flight: try again shortly.
    if (_sending) return _scheduleRespot(respotRetry);
    var finished = false;
    _roundInFlight = true;
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
          final outcome = _outcomeOf(targets, results);
          _showOutcome(outcome);
          // Spots that silently stop going out are what the chip saying
          // "Auto re-spot" must not hide.
          if (outcome == null) return _stopWith(_spotSkippedText(targets, results));
          _retry.addAll(_refusedBy(targets, results));
        } else {
          // The round as a whole: the sources that took it the first time
          // count, so a retry refused again is never worse than "some" — and
          // one every source retried skips leaves those first ones all the
          // round went to.
          final retried = _outcomeOf(targets, results) ?? (_outcome == SpotOutcome.someTook ? SpotOutcome.allTook : null);
          _showOutcome(retried == SpotOutcome.allTook || _outcome != SpotOutcome.someTook ? retried : SpotOutcome.someTook);
          // Refused twice, the round is lost for those sources: said once a
          // round, since the source icons alone are easy to miss.
          _notice(spotFailureText(targets, results));
        }
      }
      finished = true;
    } finally {
      _roundInFlight = false;
      // A hook that threw has no answer to retry on: stopping, and saying so,
      // beats a loop that keeps calling it or a chip that keeps saying "Auto
      // re-spot". The error itself goes on to the zone.
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

  /// Whether [comment] announces arriving on a frequency ([arrivalQCode]).
  static bool _isArrival(String? comment) => comment != null && arrivalQCode.hasMatch(comment.trim());

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
        // A source that skipped the spot by its own rules stays neutral: lit
        // would claim it went out, red would call a choice a failure.
        _status[hookKey] = result == null || _skipped(result) ? null : result['ok'] == true;
      }
      onAnswered?.call();
      notify();
      _statusClearTimer?.cancel();
      _statusClearTimer = Timer(resultShownFor, () {
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

/// What the operator is told about a spot every source skipped: each
/// source's own reason, or a general one when none gives any.
String _spotSkippedText(List<Map<String, dynamic>> sources, Map<String, Map<String, dynamic>> results) {
  final reasons = [
    for (final source in sources)
      if (results[source['hookKey'] as String? ?? '']?['message'] case final String message when message.trim().isNotEmpty) message.trim(),
  ];
  return reasons.isEmpty ? t.spotting.allSkipped : reasons.join('; ');
}

/// The Spotting control's expanded row: the comment field, the send button,
/// and one status icon per source on offer.
class SpottingControlFields extends StatelessWidget {
  const SpottingControlFields({super.key, required this.model, required this.state, required this.theme, required this.onPressed});

  final SpottingControlModel model;

  /// [SpottingControlModel.state], resolved once by the spec for both the
  /// chip's summary and this row.
  final SpottingState state;

  /// The panel's accent theme — the row is painted on it.
  final ThemeData theme;

  /// A press of the button is done with the comment — the panel puts the
  /// keyboard back where it belongs.
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final sources = model.sources;
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // What the respots say, shown where the comment goes but not
        // editable: a new comment is a new spot, which this row cannot send
        // while auto-respotting holds the button. Not [state.showComment],
        // so the focus ladder never lands on a field that takes no input.
        if (model.autoRespotting && model.config().editingQso == null)
          SizedBox(
            width: 160,
            child: TextFormField(
              // Keyed by the comment: the field holds its initial value, and
              // a respot of a newer spot must show that one's.
              key: ValueKey(('respotComment', model.respotComment)),
              initialValue: model.respotComment ?? '',
              enabled: false,
              style: haloMonoStyle(context, fontSize: 15, fontWeight: FontWeight.w500),
              decoration: poloFieldDecoration(context, t.loggingControls.spotComment, labelColor: theme.colorScheme.onTertiaryContainer),
            ),
          ),
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
          onPressed: state.enabled && !model.sending
              ? () {
                  onPressed();
                  unawaited(model.press());
                }
              : null,
          icon: model.sending ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(MdiIcons.handWave),
          // Counting down to the next auto-respot: re-read every second.
          label: model.autoRespotting ? OncePerSecond(builder: (_, _) => Text(model.state.buttonLabel)) : Text(state.buttonLabel),
        ),
        // Two source-status icons per column, wrapping into another column
        // to the right once a column fills up.
        for (var i = 0; i < sources.length; i += 2)
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final source in sources.skip(i).take(2))
                Padding(
                  padding: const EdgeInsets.only(left: Space.xs, top: Space.xxs, bottom: Space.xxs),
                  child: HoverLabel(
                    label: source['name'] as String? ?? source['hookKey'] as String? ?? '',
                    child: Icon(
                      resolveIconName(source['icon'] as String?, fallback: MdiIcons.radioTower),
                      size: 16,
                      // The open chip's colors: this row is painted on its
                      // fill, and they are the ones chosen to read on it.
                      color: switch (model.statusOf(source['hookKey'] as String? ?? '')) {
                        true => spotOutcomeColor(theme, SpotOutcome.allTook, selected: true),
                        false => spotOutcomeColor(theme, SpotOutcome.noneTook, selected: true),
                        null => theme.colorScheme.onTertiaryContainer,
                      },
                      shadows: glyphGlow(theme),
                    ),
                  ),
                ),
            ],
          ),
        if (model.config().onOpenSettings case final onOpenSettings?) ...[
          const SizedBox(width: Space.sm),
          Semantics(
            identifier: 'action.spottingSettings',
            // Icon-only, and the app shows no hover tooltips: this label is
            // the only accessible name it has.
            label: t.settings.spotting.title,
            button: true,
            child: InkWell(
              key: const ValueKey('spottingSettingsButton'),
              // Not one of the control's fields: a click's focus grab would
              // leave Tab with nowhere in the control to go from.
              canRequestFocus: false,
              onTap: onOpenSettings,
              child: Padding(
                padding: const EdgeInsets.all(Space.xs),
                child: Icon(MdiIcons.tune, size: 20, color: theme.colorScheme.onTertiaryContainer, shadows: glyphGlow(theme)),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// The Spotting chip's icon color for a self-spot's [outcome]: green when
/// every source took it, amber when some did, red when none did.
///
/// [selected] is the chip's own, for the same reason as `radioStatusColor`'s:
/// one color sits on two fills, and which of them is the darker flips between
/// light and dark mode. Every color here clears 3:1 on each fill its branch
/// paints on — the amber pair, and the blue pair editing a logged QSO swaps
/// in. No single yellow does on all of them, and the Radio chip's own pairs
/// fall under 3:1 on some.
Color spotOutcomeColor(ThemeData theme, SpotOutcome outcome, {required bool selected}) {
  if ((theme.brightness == Brightness.dark) != selected) {
    // light+selected or dark+unselected: the darker fills — light pastels.
    return switch (outcome) {
      SpotOutcome.allTook => const Color(0xFF81C784),
      SpotOutcome.someTook => const Color(0xFFFFD54F),
      SpotOutcome.noneTook => const Color(0xFFFF9E9E),
    };
  }
  // dark+selected or light+unselected: the lighter fills — dark, saturated.
  return switch (outcome) {
    SpotOutcome.allTook => const Color(0xFF005000),
    SpotOutcome.someTook => const Color(0xFF553F00),
    SpotOutcome.noneTook => const Color(0xFF900000),
  };
}

/// The color the Spotting chip's icon and label pulse toward in the last
/// [SpottingControlModel.respotSoonLead] before an auto-respot: an electric blue on the darker fills, a deep vivid
/// one on the lighter. Both clear 4.5:1 — it colors text, not just a glyph —
/// on every fill, the blue ones editing a logged QSO swaps in included.
Color respotSoonColor(ThemeData theme, {required bool selected}) =>
    (theme.brightness == Brightness.dark) != selected ? const Color(0xFF7DF9FF) : const Color(0xFF001C99);

/// The Spotting chip's glyph — the settings dialog's entry reads this too.
const spottingChipIcon = MdiIcons.handWave;

/// The Spotting chip and its expanded fields, read from [model]. [selected]
/// is the chip's own; see [spotOutcomeColor].
SecondaryControlSpec spottingControlSpec(SpottingControlModel model, ThemeData theme, {required bool selected, required VoidCallback onPressed}) {
  final state = model.state;
  final outcome = model.outcome;
  final soon = model.respotSoon ? respotSoonColor(theme, selected: selected) : null;
  return SecondaryControlSpec(
    key: 'spotting',
    icon: spottingChipIcon,
    summary: state.summary,
    liveSummary: model.autoRespotting ? () => model.state.summary : null,
    liveTint: soon == null ? null : (color: soon, strength: () => model.respotPulse),
    liveIconGlow: model.respotGlowing ? () => model.respotGlow : null,
    // The pulse outranks a fading outcome: it is the news that is about to
    // happen, not the one that already did.
    liveIconColor: soon != null || outcome == null
        ? null
        : (base) => Color.lerp(base, spotOutcomeColor(theme, outcome, selected: selected), model.outcomeStrength)!,
    expandedBuilder: (context) => SpottingControlFields(model: model, state: state, theme: theme, onPressed: onPressed),
  );
}
