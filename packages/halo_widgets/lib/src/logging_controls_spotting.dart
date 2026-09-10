// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The Spotting control: posting a spot to whichever `spots` hooks offer it —
// a self-spot at the VFO's frequency while composing, or a spot of the
// station in an existing QSO while it is still recent enough to be worth
// one (ham2k/halo-dist#10). [SpottingControlModel] holds the comment, the
// sources on offer and the per-source outcome of the last send on behalf of
// `LoggingControls`; [SpottingControlFields] draws the expanded row.

import 'dart:async';

import 'package:flutter/material.dart';

import 'package:halo_core/halo_core.dart';

import 'call_info_summary.dart';
import 'icon_resolver.dart';
import 'logging_controls_types.dart';
import 'mdi_icons.g.dart';
import 'panel_model.dart';
import 'spacing.dart';
import 'theme.dart';

/// What the model reads from the panel's live configuration — re-read on
/// every use, because the hooks, the edited QSO and the operation all change
/// under a mounted panel.
typedef SpottingConfig = ({
  SendSpot? sendSpot,
  SuggestSpotSources? suggestSpotSources,
  VfoStore? radioService,
  Qso? editingQso,
  Operation operation,
  String? spottingLabel,
  String? spottingSelfLabel,
  String Function(String freq)? spotSelfLabel,
  String Function(String call, String freq)? spotOtherLabel,
  String Function(String call)? spotTooLateLabel,
  String? spotNoFreqLabel,
});

/// The Spotting control's summary, button text and enabled state, resolved
/// once per build from the state machine in [SpottingControlModel.state].
typedef SpottingState = ({String summary, String buttonLabel, bool enabled, bool showComment});

/// The Spotting control's state. See the file comment.
class SpottingControlModel extends ChangeNotifier with PanelModel {
  SpottingControlModel({required this.config});

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


  @override
  void dispose() {
    _statusClearTimer?.cancel();
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
      final summary = cfg.spottingLabel ?? 'Spotting';
      if (tooOld) {
        return (
          summary: summary,
          buttonLabel: cfg.spotTooLateLabel?.call(call) ?? 'Too late to spot $call',
          enabled: false,
          showComment: false,
        );
      }
      final freqLabel = editingQso.freq == null ? '' : fmtFreq(editingQso.freq!);
      return (
        summary: summary,
        buttonLabel: cfg.spotOtherLabel?.call(call, freqLabel) ?? 'Spot $call at $freqLabel',
        enabled: true,
        showComment: true,
      );
    }

    final summary = cfg.spottingSelfLabel ?? 'Self-spotting';
    final vfoFreq = cfg.radioService?.vfoA.freq;
    if (vfoFreq == null) {
      return (
        summary: summary,
        buttonLabel: cfg.spotNoFreqLabel ?? 'First set a frequency to spot',
        enabled: false,
        showComment: false,
      );
    }
    final freqLabel = fmtFreq(vfoFreq);
    return (
      summary: summary,
      buttonLabel: cfg.spotSelfLabel?.call(freqLabel) ?? 'Self-spot at $freqLabel',
      enabled: true,
      showComment: true,
    );
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

  /// Posts the spot to every source on offer, and colours each source's icon
  /// by its answer for three minutes.
  Future<void> send() async {
    final cfg = config();
    final sendSpot = cfg.sendSpot;
    if (sendSpot == null || _sending) return;
    final editingQso = cfg.editingQso;
    final vfo = cfg.radioService?.vfoA;
    // Snapshot the sources being spotted now — they can be reset and
    // repopulated by the panel (e.g. the user switches to editing a
    // different QSO) while this send is still in flight, and the
    // status-coloring below must key off what was actually sent, not
    // whatever [sources] holds once the await resolves.
    final sentSources = _sources;
    // Colors from a previous attempt would misread as THIS attempt's
    // results while the send is in flight — back to neutral gray first.
    _sending = true;
    _status.clear();
    notify();
    try {
      final comment = commentController.text.trim();
      final results = await sendSpot(
        sources: sentSources,
        operation: operationPayload,
        qso: editingQso?.data,
        freq: editingQso == null ? vfo?.freq : null,
        mode: editingQso == null ? vfo?.mode : null,
        comment: comment.isEmpty ? null : comment,
      );
      if (isDisposed) return;
      for (final source in sentSources) {
        final hookKey = source['hookKey'] as String? ?? '';
        final result = results[hookKey];
        _status[hookKey] = result == null ? null : result['ok'] == true;
      }
      commentController.clear();
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
    } finally {
      if (!isDisposed) {
        _sending = false;
        notify();
      }
    }
  }
}

/// The Spotting control's expanded row: the comment field, the send button,
/// and one status icon per source on offer.
class SpottingControlFields extends StatelessWidget {
  const SpottingControlFields({
    super.key,
    required this.model,
    required this.state,
    required this.theme,
    required this.colors,
    required this.commentHint,
  });

  final SpottingControlModel model;

  /// [SpottingControlModel.state], resolved once by the spec for both the
  /// chip's summary and this row.
  final SpottingState state;

  /// The panel's accent theme — the row is painted on it.
  final ThemeData theme;
  final HaLoColors colors;
  final String commentHint;

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
              decoration: poloFieldDecoration(context, commentHint, labelColor: theme.colorScheme.onTertiaryContainer),
            ),
          ),
        const SizedBox(width: Space.sm),
        FilledButton.icon(
          style: FilledButton.styleFrom(
            backgroundColor: theme.colorScheme.tertiaryContainer,
            foregroundColor: theme.colorScheme.onTertiaryContainer,
            disabledBackgroundColor: theme.colorScheme.tertiaryContainer.withValues(alpha: 0.4),
          ),
          onPressed: state.enabled && !model.sending ? model.send : null,
          icon: model.sending
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(MdiIcons.handWave),
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
