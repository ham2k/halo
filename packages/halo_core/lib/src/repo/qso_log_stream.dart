// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0

import 'dart:async';
import 'dart:math' as math;

import 'package:drift/drift.dart';
import 'package:meta/meta.dart';

import '../db/database.dart';
import '../models/models.dart';
import 'repo_support.dart';

/// Rows a log stream re-reads for one change before reading the whole log is
/// the cheaper move: the most a re-read decodes inline, without the isolate
/// hop a whole-log read pays anyway — and the size of the `IN` list, well
/// under SQLite's bound-variable limit.
const _patchLimit = qsoRowDecodeIsolateThreshold - 1;

/// Write footprints kept for the log streams still to consume them. A stream
/// further behind than this reads the log in full, so the bound costs nothing
/// in correctness; it only bounds the memory a starved listener can pin.
const _ledgerCapacity = 256;

/// The rows a write touched, filed under every operation whose log it can
/// change — the one a row joins and the one it leaves. A stream re-reads only
/// the rows filed under its own operation.
typedef QsoWriteFootprint = Map<String, Set<String>>;

/// What each write touched, in write order, for the patch step of
/// `QsosRepository.watchForOperation`: the operations whose log it can change
/// and the rows it wrote. A `null` footprint is a write that reaches every row.
///
/// Recorded INSIDE the write's transaction, as its last step, and only when
/// a statement actually reached a row. Both halves are load-bearing. Drift
/// dispatches a transaction's table update at commit, so the update a
/// stream wakes to always finds its footprint already here; and a stream
/// that sees the footprint before the commit has its re-read wait on the
/// transaction lock, so it never reads the rows ahead of the write. A
/// footprint recorded before the transaction, or after it, breaks one side
/// or the other: the stream re-reads stale rows and then takes the update
/// for a write it knows nothing about, and reads the whole log again. A
/// footprint for a statement that wrote no row has no update to pair with,
/// which the stream would count as one write it may later miss.
///
/// The pairing is by count: ONE footprint per dispatched table update. A
/// transaction dispatches once, and a nested transaction dispatches when it
/// closes (drift roots its update store at the database, not the enclosing
/// transaction), so a repository write inside another transaction still
/// pairs one to one — but two footprints under one dispatch, or one under
/// none, leave a stream owed an update it will pay to the next writer it
/// does not know. A full read settles that debt, so the damage is bounded
/// by the next one; it is still a silent drop until then.
@internal
class QsoWriteLedger {
  final _footprints = <QsoWriteFootprint?>[];
  var _base = 0;

  /// The position a new listener starts consuming from.
  int get end => _base + _footprints.length;

  /// Records what a write touched; `null` for a write that reaches every row.
  void record(QsoWriteFootprint? footprint) {
    _footprints.add(footprint);
    if (_footprints.length > _ledgerCapacity) {
      _footprints.removeAt(0);
      _base++;
    }
  }

  /// The footprints recorded since [cursor], or null when the ledger no
  /// longer reaches back that far.
  List<QsoWriteFootprint?>? since(int cursor) => cursor < _base ? null : _footprints.sublist(cursor - _base);
}

/// An operation's log, followed once for every listener that wants it — the
/// state behind `QsosRepository.watchForOperation`. [all] reads the whole log
/// as the repository orders it.
///
/// Shared, as drift's keyed query streams are: the Operation View subscribes
/// twice to one log (the list it shows and the rescore that watches it), and
/// a follower per listener would read and decode the log twice at open and
/// patch it twice per write. The first listener starts the follower, a later
/// one is replayed the list held so far, and the last to cancel stops it —
/// [onIdle] is how the repository learns to drop it.
@internal
class QsoLogFollower {
  QsoLogFollower({required this.db, required this.ledger, required this.operationUuid, required this.includeDeleted, required this.all, required this.onIdle});

  final HaLoDatabase db;
  final QsoWriteLedger ledger;
  final String operationUuid;
  final bool includeDeleted;
  final Future<List<Qso>> Function() all;
  final void Function() onIdle;
  final _listeners = <MultiStreamController<List<Qso>>>{};

  /// Listeners that attached while a pass was in flight. The list held then
  /// may predate the writes the pass is folding in — every update pending
  /// when they attached — so they are fed once the pass has drained, not by
  /// whichever iteration finishes first. A pass that failed instead leaves
  /// them the read: the failure was the earlier listeners' to hear.
  final _awaiting = <MultiStreamController<List<Qso>>>{};

  List<Qso>? _current;

  /// The ledger position consumed so far.
  int _cursor = 0;

  /// Footprints already folded in whose table update has yet to arrive. A
  /// pass can see a footprint before its transaction commits (the re-read
  /// then waits on the lock, so what it folds in is the committed row), and
  /// the update that follows is paid from here rather than read as a write
  /// the ledger missed.
  int _debt = 0;

  /// Table updates received and not yet passed over.
  int _pending = 0;
  bool _passing = false;

  /// Whether the initial read has been attempted. The loop below runs on
  /// updates once this is set: a read that throws must not be retried until
  /// the table changes, or a corrupt row spins the listener at database
  /// speed with an error per turn.
  bool _primed = false;
  StreamSubscription<Set<TableUpdate>>? _updates;

  void start() {
    _cursor = ledger.end;
    _updates = db.tableUpdates(TableUpdateQuery.onTable(db.qsos)).listen(
      (_) {
        _pending++;
        _pass();
      },
      // Started inside a transaction, the update stream is that transaction's
      // and closes with it; a follower that could never hear another update
      // must not stay shared. Stopping it sends the next listener to a fresh one.
      onDone: _stop,
    );
    _pass();
  }

  /// Adds a listener. One arriving while nothing is in flight is handed the
  /// list held so far; one arriving during a pass waits for the pass to
  /// drain, so a `.first` after an awaited write sees that write and every
  /// write queued behind it, as a fresh read would. One arriving after a read
  /// that failed — or during the pass that fails — gets a read of its own: the
  /// failure was the earlier listeners' to hear, and a table that never
  /// changes again would otherwise leave this one silent forever.
  void attach(MultiStreamController<List<Qso>> listener) {
    _listeners.add(listener);
    listener.onCancel = () {
      _listeners.remove(listener);
      _awaiting.remove(listener);
      if (_listeners.isEmpty) return _stop();
      return null;
    };
    final current = _current;
    if (current == null) {
      // No list held: the initial read is in flight and this listener is its
      // audience like the first — or it failed, and the read is this one's.
      if (!_passing && _primed) {
        _primed = false;
        _pass();
      }
      return;
    }
    if (_passing) {
      _awaiting.add(listener);
    } else {
      listener.add(current);
    }
  }

  Future<void> _stop() async {
    final updates = _updates;
    if (updates == null) return;
    // The entry leaves the map BEFORE the first await: a listener arriving
    // during the cancel must find no follower and start a fresh one.
    _updates = null;
    onIdle();
    await updates.cancel();
  }

  /// Folds every pending update in, one pass per batch of them, until none
  /// is left. Updates that land during a read are taken up by the next
  /// iteration, so nothing is lost while a read is in flight.
  Future<void> _pass() async {
    if (_passing) return;
    _passing = true;
    try {
      while (true) {
        while (_updates != null && (!_primed || _pending > 0)) {
          _primed = true;
          final triggered = _pending;
          _pending = 0;
          final footprints = ledger.since(_cursor);
          _cursor = ledger.end;
          try {
            final next = await _next(footprints, triggered);
            if (next == null || _updates == null) continue;
            _current = next;
            for (final listener in _listeners.toList()) {
              if (!_awaiting.contains(listener)) listener.add(next);
            }
          } catch (e, st) {
            // The footprints of this pass are consumed, so the held list can no
            // longer be patched into the truth: the next update reads in full.
            _current = null;
            if (_updates == null) continue;
            for (final listener in _listeners.toList()) {
              if (!_awaiting.contains(listener)) listener.addError(e, st);
            }
          }
        }
        if (_updates == null || _awaiting.isEmpty) break;
        final current = _current;
        if (current != null) {
          // Drained: what is held now reflects every update pending when they
          // attached, whether the last iteration emitted or not.
          for (final listener in _awaiting.toList()) {
            listener.add(current);
          }
          _awaiting.clear();
          break;
        }
        // The pass they waited on failed. The read is theirs now, outcome and
        // all — once, not until it succeeds.
        _awaiting.clear();
        _primed = false;
      }
    } finally {
      _passing = false;
    }
  }

  /// The log after [footprints] — null when nothing this listener shows has
  /// changed. [footprints] null means the ledger no longer reaches back to
  /// this listener's cursor.
  Future<List<Qso>?> _next(List<QsoWriteFootprint?>? footprints, int triggered) async {
    var unledgered = false;
    if (footprints == null) {
      _debt = 0;
    } else {
      final paid = math.min(triggered, _debt);
      _debt -= paid;
      final unpaid = triggered - paid;
      if (unpaid > footprints.length) {
        unledgered = true;
      } else {
        _debt += footprints.length - unpaid;
      }
    }
    final current = _current;
    if (current == null || footprints == null || unledgered || footprints.contains(null)) return _fresh();
    final touched = <String>{};
    for (final footprint in footprints) {
      touched.addAll(footprint![operationUuid] ?? const {});
    }
    if (touched.isEmpty) return null;
    if (touched.length > _patchLimit) return _fresh();
    // By uuid alone, not through the operation filter: a row that left this
    // view — deleted, or moved to another operation — has to be found so it
    // can be dropped, and one that entered it has to be found so it can be
    // placed.
    final rows = await (db.select(db.qsos)..where((q) => q.uuid.isIn(touched.toList()))).get();
    final fresh = [
      for (final qso in await qsosFromRows(rows))
        if (qso.operationUuid == operationUuid && (includeDeleted || !qso.deleted)) qso,
    ];
    return _patched(current, touched, fresh);
  }

  /// A whole-log read reconciles everything, so whatever debt was owed is
  /// settled by it: an update that then arrives for a footprint this read
  /// already covers reads as unledgered and costs one more full read, where
  /// a debt carried past a full read would instead pay for a stranger's
  /// update — a write outside the repository — and drop it.
  Future<List<Qso>> _fresh() {
    _debt = 0;
    return all();
  }

  /// [current] with [touched] rows replaced by [fresh] — in place when the
  /// row keeps its start time, re-placed by it otherwise — and the touched
  /// rows [fresh] no longer holds dropped.
  static List<Qso> _patched(List<Qso> current, Set<String> touched, List<Qso> fresh) {
    final placing = {for (final qso in fresh) qso.uuid: qso};
    final next = <Qso>[];
    for (final qso in current) {
      if (!touched.contains(qso.uuid)) {
        next.add(qso);
        continue;
      }
      final replacement = placing[qso.uuid];
      if (replacement != null && replacement.startAtMillis == qso.startAtMillis) {
        next.add(replacement);
        placing.remove(qso.uuid);
      }
    }
    // The same order as the query's `ORDER BY startAtMillis`: nulls first,
    // and a row placed after every row that starts no later than it, which
    // is where a contact logged just now lands — at the end, in one step.
    for (final qso in placing.values) {
      var at = next.length;
      while (at > 0 && _startsAfter(next[at - 1], qso)) {
        at--;
      }
      next.insert(at, qso);
    }
    return next;
  }

  static bool _startsAfter(Qso a, Qso b) {
    final x = a.startAtMillis;
    final y = b.startAtMillis;
    if (x == null) return false;
    if (y == null) return true;
    return x > y;
  }
}
