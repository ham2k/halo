// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The Exports panel's sync and push section (docs/design/transfer.md §4):
// the operation's Ham2K Cloud Sync state, then a row per destination a
// `transfer` hook offers, each either done or with the button that sends
// what is due there. Behind EXP PUSH: the panel builds it only with that on, so
// with it off no hook is asked anything.

import 'package:flutter/material.dart';
import 'package:halo_i18n/halo_i18n.dart';
import 'package:halo_widgets/halo_widgets.dart';

import '../../services/error_reporting_service.dart';
import '../../services/halo_services.dart';
import '../../services/transfer_service.dart';

/// The services a scope pushes to, and the push running, if any. The
/// panel owns it, not the section: the section's header counts what is
/// pending while the section is closed, and a push outlives the section
/// being closed under it.
class PushServicesModel extends ChangeNotifier {
  PushServicesModel(this.services, this.scope, {this.onPushed, this.shown});

  /// Over [operationUuid]'s contacts, the operation read as stored on each
  /// load and push: a hook reads its status to decide what is due, and a
  /// push just changed it.
  PushServicesModel.forOperation(HaLoServices services, String operationUuid, {Future<void> Function()? onPushed, bool Function()? shown})
    : this(
        services,
        () async {
          final operation = await services.operations.get(operationUuid);
          return operation == null ? null : OperationPushScope(operation);
        },
        onPushed: onPushed,
        shown: shown,
      );

  final HaLoServices services;

  /// What the rows are for, read on each load and push; null when it is
  /// gone.
  final Future<PushScope?> Function() scope;

  /// After each push: what it wrote back also changed what Ham2K Cloud Sync
  /// owes.
  final Future<void> Function()? onPushed;

  /// Whether the rows are on screen, where a push's failure is told; when
  /// they are not, a status bar notice tells it instead.
  final bool Function()? shown;

  List<PushServiceStatus> rows = const [];

  /// Why the services could not be listed, when they could not.
  Object? loadError;

  /// The row being pushed ([PushServiceStatus.key]), and how far along it is.
  String? running;
  ({int done, int total})? progress;

  /// The last push's failure per row: its outcome, and what it threw if it
  /// stopped short.
  final Map<String, ({PushOutcome outcome, Object? error})> failures = {};

  bool _disposed = false;

  /// Which [load] is the current one: the one a push starts can finish
  /// before the one the panel opened with, and the older rows must not
  /// replace the newer.
  int _loadRequest = 0;

  int get pending => rows.where((r) => !r.completed).length;
  int get completed => rows.where((r) => r.completed).length;

  Future<void> load() async {
    final request = ++_loadRequest;
    try {
      final scope = await this.scope();
      if (scope == null || _disposed || request != _loadRequest) return;
      final rows = await services.transfers.servicesFor(scope);
      if (_disposed || request != _loadRequest) return;
      this.rows = rows;
      loadError = null;
    } catch (e, stack) {
      // The section's header says so, open or closed.
      ErrorReportingService.report(e, stack, context: 'transfer services', told: !_disposed);
      if (_disposed || request != _loadRequest) return;
      loadError = e;
    }
    notifyListeners();
  }

  /// Sends everything due to [row]'s destination, one suggestion after
  /// another.
  Future<void> push(PushServiceStatus row) async {
    if (row.destination == null) return;
    running = row.key;
    progress = (done: 0, total: row.toSend + row.toDelete);
    failures.remove(row.key);
    notifyListeners();
    final outcome = PushOutcome();
    try {
      final scope = await this.scope();
      if (scope == null) throw StateError('The operation is gone');
      await services.transfers.push(
        scope,
        row,
        outcome: outcome,
        onProgress: (done, total) {
          progress = (done: done, total: total);
          if (!_disposed) notifyListeners();
        },
      );
      if (outcome.failures.isNotEmpty) {
        final failure = (outcome: outcome, error: null);
        failures[row.key] = failure;
        // Refusals are the service's answers, not errors to upload; the row
        // tells them, or a notice when the row is out of sight.
        if (!_onScreen) {
          services.statusBar.showNotice(key: 'transfer:push:${row.key}', title: row.label, text: pushFailureText(t.operation.export.push, failure));
        }
      }
    } catch (e, stack) {
      final failure = (outcome: outcome, error: e);
      failures[row.key] = failure;
      // The row the operator pushed says what failed, beside what went
      // before it; out of sight (the section folded, the pane closed), a
      // notice says it.
      final onScreen = _onScreen;
      ErrorReportingService.report(
        e,
        stack,
        context: 'transfer push ${row.service}',
        told: onScreen,
        notice: onScreen
            ? null
            : ErrorNotice(services.statusBar, key: 'transfer:push:${row.key}', title: row.label, text: pushFailureText(t.operation.export.push, failure)),
      );
    }
    running = null;
    progress = null;
    if (_disposed) return;
    notifyListeners();
    try {
      await onPushed?.call();
    } catch (e, stack) {
      // The Cloud Sync row keeps its last counts; a refresh is all that failed.
      ErrorReportingService.report(e, stack, context: 'sync counts after a push');
    }
    await load();
  }

  bool get _onScreen => !_disposed && (shown?.call() ?? true);

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

/// The section's rows: [leading] (the Ham2K Cloud Sync row), when there is
/// one, then a row per service.
class OperationPushSection extends StatelessWidget {
  final PushServicesModel model;

  /// The Ham2K Cloud Sync row, over an operation's contacts.
  final Widget? leading;

  const OperationPushSection({super.key, required this.model, this.leading});

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: model,
    builder: (context, _) => SliverList.list(
      children: [
        ?leading,
        if (model.loadError case final error?)
          ListTile(
            leading: Icon(MdiIcons.cloudAlert),
            subtitle: Text(context.t.operation.export.push.loadFailed(error: ErrorReportingService.messageOf(error))),
          ),
        for (final row in model.rows) _row(context, row),
      ],
    ),
  );

  Widget _row(BuildContext context, PushServiceStatus row) {
    final t = context.t.operation.export.push;
    final running = model.running == row.key;
    final progress = model.progress;
    final failure = model.failures[row.key];
    final failureText = failure == null ? null : pushFailureText(t, failure);
    return ListTile(
      leading: Icon(MdiIcons.cloudUploadOutline),
      title: Text(row.label, style: const TextStyle(fontWeight: FontWeight.bold)),
      subtitle: running && progress != null
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(t.progress(done: formatNumber(progress.done), total: formatNumber(progress.total))),
                const SizedBox(height: Space.xs),
                LinearProgressIndicator(value: progress.total == 0 ? null : progress.done / progress.total),
              ],
            )
          : Text([_status(context, row), ?failureText].join('\n')),
      trailing: row.problem != null
          ? null
          : row.completed
          ? Icon(MdiIcons.checkCircle, color: connectedGreen(Theme.of(context)), semanticLabel: t.done)
          : FilledButton.tonal(
              onPressed: model.running == null ? () => model.push(row) : null,
              child: Text(t.button, semanticsLabel: t.buttonFor(name: row.label)),
            ),
    );
  }

  /// What is due and where it goes, or what the service already holds.
  String _status(BuildContext context, PushServiceStatus row) {
    final t = context.t.operation.export.push;
    if (row.problem case final problem?) return problem;
    final where = row.destination?.label;
    if (row.completed) {
      if (row.sent == 0) return t.nothingToSend;
      return where == null
          ? t.allSent(count: row.sent, n: formatNumber(row.sent))
          : t.allSentTo(count: row.sent, n: formatNumber(row.sent), destination: where);
    }
    return [
      if (row.toSend > 0)
        where == null
            ? t.toSend(count: row.toSend, n: formatNumber(row.toSend))
            : t.toSendTo(count: row.toSend, n: formatNumber(row.toSend), destination: where),
      if (row.toDelete > 0) t.toDelete(count: row.toDelete, n: formatNumber(row.toDelete)),
    ].join(' · ');
  }
}

/// What a push's [failure] says: what stopped it, and the contacts the
/// service refused.
String pushFailureText(Translations$operation$export$push$en t, ({PushOutcome outcome, Object? error}) failure) => [
  if (failure.error case final error?) error is PushTimedOut ? t.timedOut : t.pushFailed(error: ErrorReportingService.messageOf(error)),
  if (failure.outcome.failures.isNotEmpty)
    t.failed(count: failure.outcome.failures.length, n: formatNumber(failure.outcome.failures.length), error: failure.outcome.failures.values.first),
].join(' · ');
