// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// A round whose reply names a different account than the one this device
// last synced with: the device was re-registered under another account
// mid-stream. Nothing in that reply is merged or marked synced; the change is
// asked about, like a fresh link — unless there is nothing to reconcile, or
// it is the one change the app said to expect.
//
// That expectation is [SyncEngine.replacedAccountKey]: the account this
// device is about to leave involuntarily, because its sync identity was lost
// (a keychain item that could not be carried over) and the server answers an
// identity it does not know with a brand-new, empty account. The next change
// away from that account into an empty one is adopted with
// [SyncAccountChoice.combine] and reported through
// [SyncEngine.onAccountReplaced]: asking would offer to combine this device's
// log into, or wipe it for, an account nobody chose, while sync stood still.
// Every other account change is asked about, empty or not.

part of 'sync_engine.dart';

extension _AccountChange on SyncEngine {
  /// [state] and [generation] are the round's own, from before its network call.
  Future<void> _settleAccountChange(Map<String, dynamic> state, String responseAccountUuid, int generation) async {
    final lastAccount = state['lastSyncAccountUUID'] as String?;
    final replacing = lastAccount != null && state[SyncEngine.replacedAccountKey] == lastAccount;
    // Asked BEFORE the pending state is written: a check that fails would
    // otherwise leave the change pending, and a pending change is never
    // looked at again, only asked about.
    final replacedByEmpty = replacing && await _isEmptyAccount(responseAccountUuid);
    if (generation != _generation) return _abandonRound();
    await settings.setState({...settings.state, 'pendingAccountUUID': responseAccountUuid});
    final adopt = replacedByEmpty || await _canAdoptAccountSilently();
    if (adopt) {
      // The banner went live the moment the pending state was written, so the
      // operator may have answered it while that check was awaiting.
      if (generation != _generation) return _abandonRound();
      // Refused (travel started while the round was on the network): don't
      // leave a pending account behind, or the operator is asked to
      // combine-or-wipe for an account that needed no question asked. The
      // replaced account stays named, for the round that can adopt.
      if (!await resolveAccountChange(SyncAccountChoice.combine)) {
        await settings.setState({...settings.state, 'pendingAccountUUID': null});
        return;
      }
    }
    // Spent by the first change away from it, adopted or asked about: a later
    // change is the operator's own. Reported only as what it is, the new and
    // empty account: an empty log adopts any account silently, and one that
    // already holds QSOs is not the one the server made for this device.
    if (replacing) {
      await settings.setState({...settings.state, SyncEngine.replacedAccountKey: null});
      if (replacedByEmpty) onAccountReplaced?.call(lastAccount, responseAccountUuid);
    }
  }

  /// Whether [accountUuid] is the account this client is on now and holds no
  /// QSOs, by the server's `contacts` — what the operator would call their log,
  /// the count the app's own displays read — or, from a server that predates
  /// it, `total`, which counts deletions too and so errs toward asking.
  Future<bool> _isEmptyAccount(String accountUuid) async {
    final data = await _callTransport(Hooks.syncTransportGetAccountData, const {});
    final current = data['current_account'];
    final qsos = data['qsos'];
    return current is Map && current['uuid'] == accountUuid && qsos is Map && (qsos['contacts'] ?? qsos['total']) == 0;
  }
}
