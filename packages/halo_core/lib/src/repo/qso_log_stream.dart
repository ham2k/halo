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

/// One listener's view of an operation's log — the state behind
/// `QsosRepository.watchForOperation`. [all] reads the whole log as the
/// repository orders it.
@internal
class QsoLogFollower {
  QsoLogFollower({required this.db, required this.ledger, required this.operationUuid, required this.includeDeleted, required this.all});

  final HaLoDatabase db;
  final QsoWriteLedger ledger;
  final String operationUuid;
  final bool includeDeleted;
  final Future<List<Qso>> Function() all;
  late final MultiStreamController<List<Qso>> out;

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

  void start(MultiStreamController<List<Qso>> listener) {
    out = listener;
    _cursor = ledger.end;
    _updates = db.tableUpdates(TableUpdateQuery.onTable(db.qsos)).listen((_) {
      _pending++;
      _pass();
    });
    out.onCancel = () {
      final updates = _updates;
      _updates = null;
      return updates?.cancel();
    };
    _pass();
  }

  /// Folds every pending update in, one pass per batch of them, until none
  /// is left. Updates that land during a read are taken up by the next
  /// iteration, so nothing is lost while a read is in flight.
  Future<void> _pass() async {
    if (_passing) return;
    _passing = true;
    try {
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
          out.add(next);
        } catch (e, st) {
          // The footprints of this pass are consumed, so the held list can no
          // longer be patched into the truth: the next update reads in full.
          _current = null;
          if (_updates != null) out.addError(e, st);
        }
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
