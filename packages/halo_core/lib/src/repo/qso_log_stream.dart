// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0

import 'dart:async';
import 'dart:math' as math;

import 'package:drift/drift.dart';
import 'package:meta/meta.dart';

import '../db/database.dart';
import '../models/models.dart';
import 'qso_log.dart';
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

  /// Beside each footprint: whether its write touched only what a row caches
  /// for this device (its scores), and none of the contact itself.
  final _cacheOnly = <bool>[];
  var _base = 0;

  /// Tells this ledger's positions from another's. A repository made again —
  /// a test's, a restored database's — starts counting from zero, and a
  /// position it never issued must read as unknown, not as a place in it.
  final _epoch = _ledgers++;
  static var _ledgers = 0;

  /// The position a new listener starts consuming from.
  int get end => _base + _footprints.length;

  /// [end] as a token for a reader outside this process's Dart code — the
  /// extension runtime — which holds it between calls and hands it back.
  String get cursor => '$_epoch:$end';

  /// The position [cursor] names, or null when this ledger never issued it.
  int? positionOf(String? cursor) {
    final parts = cursor?.split(':');
    if (parts == null || parts.length != 2 || parts[0] != '$_epoch') return null;
    final position = int.tryParse(parts[1]);
    return position == null || position > end ? null : position;
  }

  /// Records what a write touched; `null` for a write that reaches every row.
  /// [cacheOnly] marks a write of what a row caches and nothing else.
  void record(QsoWriteFootprint? footprint, {bool cacheOnly = false}) {
    _footprints.add(footprint);
    _cacheOnly.add(cacheOnly);
    if (_footprints.length > _ledgerCapacity) {
      _footprints.removeAt(0);
      _cacheOnly.removeAt(0);
      _base++;
    }
  }

  /// The footprints recorded since [cursor], or null when the ledger no
  /// longer reaches back that far.
  ///
  /// [contentOnly] leaves out the cache-only writes, for a reader that holds
  /// the contacts and not their scores: a rescore caches a verdict on every
  /// contact, and counting that as a change would hand such a reader the
  /// whole log after every one. A log stream must not leave them out — it
  /// shows the scores, and pairs one footprint with each table update.
  List<QsoWriteFootprint?>? since(int cursor, {bool contentOnly = false}) {
    if (cursor < _base) return null;
    final from = cursor - _base;
    return [
      for (var i = from; i < _footprints.length; i++)
        if (!contentOnly || !_cacheOnly[i]) _footprints[i],
    ];
  }
}

/// The rows [footprints] name under [operationUuid], read again: [touched],
/// every uuid named, and [fresh], those of them still in the operation's log
/// as [includeDeleted] reads it — so a touched row missing from [fresh] has
/// left it, deleted or moved to another operation. Null when only a whole
/// read will do: a footprint that reached every row, or more than [limit]
/// rows to read.
///
/// By uuid alone, not through the operation filter: a row that left the log
/// has to be found to be known gone, and one that joined it to be placed.
@internal
Future<({Set<String> touched, List<Qso> fresh})?> rereadTouched(
  HaLoDatabase db,
  List<QsoWriteFootprint?> footprints,
  String operationUuid, {
  required bool includeDeleted,
  required int limit,
}) async {
  if (footprints.contains(null)) return null;
  final touched = {for (final footprint in footprints) ...?footprint![operationUuid]};
  if (touched.isEmpty) return (touched: touched, fresh: const <Qso>[]);
  if (touched.length > limit) return null;
  final rows = await (db.select(db.qsos)..where((q) => q.uuid.isIn(touched.toList()))).get();
  return (
    touched: touched,
    fresh: [
      for (final qso in await qsosFromRows(rows))
        if (qso.operationUuid == operationUuid && (includeDeleted || !qso.deleted)) qso,
    ],
  );
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

  QsoLog? _current;

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
  Future<QsoLog?> _next(List<QsoWriteFootprint?>? footprints, int triggered) async {
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
    if (current == null || footprints == null || unledgered) return _fresh();
    final reread = await rereadTouched(db, footprints, operationUuid, includeDeleted: includeDeleted, limit: _patchLimit);
    if (reread == null) return _fresh();
    if (reread.touched.isEmpty) return null;
    return _patched(current, reread.touched, reread.fresh);
  }

  /// A whole-log read reconciles everything, so whatever debt was owed is
  /// settled by it: an update that then arrives for a footprint this read
  /// already covers reads as unledgered and costs one more full read, where
  /// a debt carried past a full read would instead pay for a stranger's
  /// update — a write outside the repository — and drop it.
  Future<QsoLog> _fresh() async {
    _debt = 0;
    final rows = await all();
    return QsoLog(rows, digest: qsoLogDigestOf(rows), unstamped: qsoLogUnstampedOf(rows));
  }

  /// [current] with [touched] rows replaced by [fresh] — in place when the
  /// row keeps its start time, re-placed by it otherwise — and the touched
  /// rows [fresh] no longer holds dropped. The digest and the unstamped
  /// count follow the same moves: a replaced or dropped row leaves them, a
  /// fresh row joins.
  static QsoLog _patched(QsoLog current, Set<String> touched, List<Qso> fresh) {
    final placing = {for (final qso in fresh) qso.uuid: qso};
    final next = <Qso>[];
    var digest = current.digest;
    var unstamped = current.unstamped;
    void leaves(Qso qso) {
      if (qso.deleted) return;
      digest -= qsoDigestTerm(qso);
      if (qso.updatedAtMillis == null) unstamped--;
    }

    void joins(Qso qso) {
      if (qso.deleted) return;
      digest += qsoDigestTerm(qso);
      if (qso.updatedAtMillis == null) unstamped++;
    }

    for (final qso in current) {
      if (!touched.contains(qso.uuid)) {
        next.add(qso);
        continue;
      }
      leaves(qso);
      final replacement = placing[qso.uuid];
      if (replacement != null && replacement.startAtMillis == qso.startAtMillis) {
        next.add(replacement);
        placing.remove(qso.uuid);
        joins(replacement);
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
      joins(qso);
    }
    return QsoLog(next, digest: digest, unstamped: unstamped);
  }

  static bool _startsAfter(Qso a, Qso b) {
    final x = a.startAtMillis;
    final y = b.startAtMillis;
    if (x == null) return false;
    if (y == null) return true;
    return x > y;
  }
}
