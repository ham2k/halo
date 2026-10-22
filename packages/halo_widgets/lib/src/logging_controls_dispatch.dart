// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The logging panel's command-action dispatcher: every `CommandAction` a
// command hook returns, applied — the QSO-scoped ones against this panel's
// draft and controllers, the rest handed to the host. Its own file for size
// alone; it is part of the panel's library and reaches its state directly.

part of 'logging_controls.dart';

extension _ActionDispatch on _LoggingControlsState {
  Future<void> _dispatchActions(List<dynamic> actions, {bool skipOnlineLookup = false}) async {
    // QSOs added by this batch of actions (e.g. one SEED run) — handed to
    // enqueueAllLookups as a single batch once every action has been
    // dispatched, rather than queued one at a time as they're added. Skipped
    // entirely when [skipOnlineLookup] is set (SEED).
    final addedQsos = <Qso>[];
    for (final action in actions) {
      if (action is! Map) continue;
      final map = action.cast<String, dynamic>();

      if (map.containsKey('setVfo')) {
        final params = map['setVfo'] as Map;
        // A command's setVfo is already validated by the extension — push
        // it to radioService immediately rather than debouncing like raw
        // frequency typing. [QsoDraft.populate] suppresses the frequency listener's own
        // (debounced) push, which would otherwise also fire from the
        // controller text assignment below.
        _draft.populate(() {
          _setStateFromDispatch(() {
            final freq = params['freq'];
            final band = params['band'];
            final mode = params['mode'];
            if (freq is num) {
              _radio.setFrequency(freq.toDouble());
            } else if (band is String) {
              _radio.setBand(band);
            }
            if (mode is String) {
              // Resolved like every other mode REQUEST. The command is the last
              // path that reached here raw, and while editing an existing QSO
              // `_onRadioVfoChanged` returns early, so nothing downstream would
              // have corrected a generic `SSB` before it was logged.
              _radio.mode = _radio.resolveMode(mode);
            } else if (freq is num) {
              // HALO-32: the frequency command (typing "14285 " into the call
              // field) doesn't carry a mode of its own — guess it from the
              // band plan, same as typing directly into the Frequency field.
              // Unlike that field, this fires once per dispatched command with
              // a final, already-complete frequency — no mid-typing prefix to
              // guard against — so a null guess simply leaves `_radio.mode` alone.
              final guess = modeForFrequency(freq.toDouble(), ituRegion: widget.radio.ourItuRegion, countryCode: widget.radio.ourCountryCode);
              if (guess != null) _radio.applyModeGuess(guess);
            }
          });
        });
        if (params['freq'] is num || params['band'] is String || params['mode'] is String) {
          _radio.pushVfo();
        }
        // The command changed band/mode/freq under [QsoDraft.populate], which
        // suppressed the field listeners' own rescore — refresh the call-info
        // notices (New Band / New Mode / dupe) for the new radio state.
        _lookup.scheduleScore();
      } else if (map.containsKey('updateQso')) {
        final params = (map['updateQso'] as Map).cast<String, dynamic>();
        _setStateFromDispatch(() {
          _draft.extra.addAll(params);
        });
      } else if (map.containsKey('addQso')) {
        final params = (map['addQso'] as Map).cast<String, dynamic>();
        final qso = await widget.log.qsosRepository.add(widget.log.operation.uuid, await _decorated(params));
        widget.log.onLogged?.call(qso);
        // Command-added QSOs (e.g. SEED's batch) carry at most the fast
        // offline guess the extension attached itself as part of adding
        // them — collected here for a single trailing enqueueAllLookups
        // call once the whole batch of actions has been dispatched.
        addedQsos.add(qso);
      } else if (map['updateSettings'] is Map) {
        // A settings write is the app's, like every other named action; the
        // panel holds no settings engine of its own.
        await widget.commands.onCommandAction?.call('updateSettings', (map['updateSettings'] as Map).cast<String, dynamic>());
      } else if (map['setCallField'] is Map) {
        // Note expansion (`//KEY`, issue #17): the interpreted command
        // replaces the call field wholesale. Set text and selection in one
        // assignment so the cursor lands at the end, and let the ordinary
        // _onCallChanged path react (lookup, dupe, comma-list handling) —
        // exactly as if the expansion had been typed.
        final params = (map['setCallField'] as Map).cast<String, dynamic>();
        final text = params['text'] as String? ?? '';
        _callController.value = TextEditingValue(
          text: text,
          selection: TextSelection.collapsed(offset: text.length),
        );
        _callFocus.requestFocus();
      } else if (map['setTime'] is Map) {
        _time.applyCommand((map['setTime'] as Map).cast<String, dynamic>());
      } else if (map.containsKey('syncAll')) {
        await widget.commands.onCommandAction?.call('syncAll');
      } else if (map['purgeTests'] is Map) {
        await widget.commands.onCommandAction?.call('purgeTests', (map['purgeTests'] as Map).cast<String, dynamic>());
      } else if (map['sendSpots'] is Map || map['autoRespot'] is Map) {
        await _spotting.runCommandAction(map, qsos: widget.log.qsos, forward: widget.commands.onCommandAction);
      } else if (map['devNotice'] is Map) {
        await widget.commands.onCommandAction?.call('devNotice', (map['devNotice'] as Map).cast<String, dynamic>());
      } else if (map['devStatus'] is Map) {
        await widget.commands.onCommandAction?.call('devStatus', (map['devStatus'] as Map).cast<String, dynamic>());
      } else if (map['devProgress'] is Map) {
        await widget.commands.onCommandAction?.call('devProgress', (map['devProgress'] as Map).cast<String, dynamic>());
      } else if (map['devHammer'] is Map) {
        await widget.commands.onCommandAction?.call('devHammer', (map['devHammer'] as Map).cast<String, dynamic>());
      } else if (map['devSplash'] is Map) {
        await widget.commands.onCommandAction?.call('devSplash');
      } else if (map['devOnboard'] is Map) {
        await widget.commands.onCommandAction?.call('devOnboard');
      } else if (map['devTester'] is Map) {
        await widget.commands.onCommandAction?.call('devTester');
      } else if (map['devPopup'] is Map) {
        await widget.commands.onCommandAction?.call('devPopup');
      } else if (map['devTimeTravel'] is Map) {
        await widget.commands.onCommandAction?.call('devTimeTravel', (map['devTimeTravel'] as Map).cast<String, dynamic>());
      } else if (map['devBench'] is Map) {
        await widget.commands.onCommandAction?.call('devBench', (map['devBench'] as Map).cast<String, dynamic>());
      } else if (map['devLogCat'] is Map) {
        await widget.commands.onCommandAction?.call('devLogCat');
      } else if (map['devMapInfo'] is Map) {
        await widget.commands.onCommandAction?.call('devMapInfo');
      } else if (map['devIdle'] is Map) {
        await widget.commands.onCommandAction?.call('devIdle');
      } else if (map['reloadDataFiles'] is Map) {
        await widget.commands.onCommandAction?.call('reloadDataFiles', (map['reloadDataFiles'] as Map).cast<String, dynamic>());
      } else if (map['toggleExperiment'] is Map) {
        await widget.commands.onCommandAction?.call('toggleExperiment', (map['toggleExperiment'] as Map).cast<String, dynamic>());
      } else if (map['updateSetting'] is Map) {
        await widget.commands.onCommandAction?.call('updateSetting', (map['updateSetting'] as Map).cast<String, dynamic>());
      } else if (map['openSettings'] is Map) {
        await widget.commands.onCommandAction?.call('openSettings', (map['openSettings'] as Map).cast<String, dynamic>());
      } else if (map['navigate'] is Map) {
        await widget.commands.onCommandAction?.call('navigate', (map['navigate'] as Map).cast<String, dynamic>());
      } else if (map['updateOperation'] is Map) {
        // The uuid is added here because only this widget knows which
        // operation is open; the app owns the write, since the operator
        // callsign and the position land in different columns.
        await widget.commands.onCommandAction?.call('updateOperation', {
          ...(map['updateOperation'] as Map).cast<String, dynamic>(),
          'uuid': widget.log.operation.uuid,
        });
      } else if (map['markSegment'] is Map) {
        // Same shape as updateOperation: this widget names the open
        // operation, the app writes the event rows (and opens the location
        // screen for ROVERQTH).
        await widget.commands.onCommandAction?.call('markSegment', {...(map['markSegment'] as Map).cast<String, dynamic>(), 'uuid': widget.log.operation.uuid});
      } else if (map['setPower'] is Map) {
        // No QSO-scoped widget state of its own — same dispatch shape as
        // updateSetting/openSettings above, straight through to the app layer.
        await widget.commands.onCommandAction?.call('setPower', (map['setPower'] as Map).cast<String, dynamic>());
      } else if (map['setKeyerSpeed'] is Map) {
        // Same as setPower: radio1's keyer, nothing of this widget's.
        await widget.commands.onCommandAction?.call('setKeyerSpeed', (map['setKeyerSpeed'] as Map).cast<String, dynamic>());
      } else if (map['showKeyer'] is Map) {
        await widget.commands.onCommandAction?.call('showKeyer', null);
      } else if (map['setEnterSends'] is Map) {
        await widget.commands.onCommandAction?.call('setEnterSends', (map['setEnterSends'] as Map).cast<String, dynamic>());
      } else if (map['findInLog'] is Map) {
        // The host's Find bar over its own list — nothing of this widget's.
        await widget.commands.onCommandAction?.call('findInLog', (map['findInLog'] as Map).cast<String, dynamic>());
      } else {
        // Nothing above recognized this action's key(s) — most likely a new
        // CommandAction field was added to the SDK (extensions/sdk/src/types.ts)
        // without a matching branch here, which otherwise fails completely
        // silently: the command interprets fine and this method just no-ops.
        // See the regression test for `reloadDataFiles` shipping without this
        // branch, above.
        debugPrint('[extensions] no dispatch branch for command action: ${map.keys}');
      }
    }
    if (addedQsos.isNotEmpty && !skipOnlineLookup) {
      widget.lookups.enqueueAllLookups?.call(addedQsos);
    }
  }
}
