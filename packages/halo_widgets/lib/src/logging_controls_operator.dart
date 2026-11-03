// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The Operator control: who is at the key, and — on an operation run under
// several station calls — which of them are on the air.
//
// While a contact is being COMPOSED it speaks for the operation: the
// operator typed here and the calls checked here are what the next contacts
// are stamped with (`qsoWithOperator`, `qsoWithStationCalls`), so they are
// written to the operation, which syncs ([LogHooks.operationsRepository]).
// While a SAVED contact is open it speaks for that contact alone, through the
// draft's `our` overrides, and the operation is left as it was — that is how
// one contact's calls or operator are corrected without moving the rest.
//
// The list of calls itself (Edit list) is always the operation's, and a
// change there counts from the next contact on: every contact that does not
// list its calls yet is stamped with the ones it was made under before the
// new list is written (`QsosRepository.freezeStationCalls`).

import 'dart:async';

import 'package:flutter/material.dart';

import 'package:halo_core/halo_core.dart';
import 'package:halo_i18n/halo_i18n.dart';

import 'halo_dialog.dart';
import 'mdi_icons.g.dart';
import 'modal_pane.dart' show showHaloDialog;
import 'panel_model.dart';
import 'secondary_control_row.dart';
import 'spacing.dart';
import 'text_formatters.dart';
import 'theme.dart';

const operatorChipIcon = MdiIcons.account;

/// Whether [operation] has anything for the Operator control to say: several
/// station calls, or an operator other than the one station call. A plain
/// operation run by its own callsign holder has neither, and the strip
/// leaves the control out entirely.
bool operatorControlOffered(Operation operation) {
  if (operation.stationCalls.length > 1) return true;
  final operatorCall = operatorCallFor(operation).toUpperCase();
  return operatorCall.isNotEmpty && operatorCall != operation.stationCalls.first;
}

/// What the model reads from the panel, re-read on every use.
typedef OperatorControlConfig = ({
  Operation operation,
  Qso? editingQso,

  /// The draft's `our` overrides ([QsoDraft.ourExtra]) — written here while a
  /// saved contact is open.
  Map<String, dynamic> ourExtra,

  /// Null leaves the operation as it is — the control still edits an open
  /// contact.
  OperationsRepository? operations,
  QsosRepository qsos,

  /// The operation's rows, event rows included — what an open contact's
  /// segment is read from ([LogHooks.qsos]).
  List<Qso> log,

  /// A write that failed — the panel's own report, in the info area and to
  /// the host.
  void Function(Object error, StackTrace stack) onWriteFailed,
});

/// The Operator control's state. See the file comment.
class OperatorControlModel extends ChangeNotifier with PanelModel {
  OperatorControlModel({required this.config}) {
    focusNode.addListener(_onFocusChanged);
  }

  final OperatorControlConfig Function() config;

  final operatorController = TextEditingController();
  final focusNode = FocusNode();

  bool get _editing => config().editingQso != null;

  Map<String, dynamic> get _contactOur => asQsonMap(config().editingQso?.data['our']) ?? const {};

  /// Several station calls: the control holds a checkbox per call rather
  /// than an Operator field. With several calls there is no one operator —
  /// the Operation Details dialog clears it for the same reason.
  bool get multiCall => config().operation.stationCalls.length > 1;

  /// The calls a checkbox is offered for: the operation's, and — on an open
  /// contact — any it lists, or its segment ran under, that the operation no
  /// longer names, so such a call can still be taken off the contact.
  List<String> get calls {
    final listed = config().operation.stationCalls;
    if (!_editing) return listed;
    final seen = {...listed};
    return [
      ...listed,
      for (final call in [...?_contactCalls, ..._segmentCalls])
        if (seen.add(call)) call,
    ];
  }

  List<String>? get _contactCalls => stationCallsOfOur({..._contactOur, ...config().ourExtra});

  /// The calls of the segment the open contact was made in — what a contact
  /// listing none of its own was made under. The operation's current calls
  /// would be wrong for a contact made before a `break` changed them.
  List<String> get _segmentCalls {
    final config = this.config();
    if (!identical(config.log, _segmentedLog) || !identical(config.operation, _segmentedOperation)) {
      _segmentedLog = config.log;
      _segmentedOperation = config.operation;
      _segmented = SegmentedOperation.from(operation: config.operation.data, qsos: config.log);
    }
    final calls = splitStationCalls(asQsonString(_segmented!.effectiveAt(config.editingQso?.startAtMillis)['stationCall']) ?? '');
    return calls.first.isEmpty ? config.operation.stationCalls : calls;
  }

  // The segments, resolved once per log and operation rather than on every
  // build of the strip.
  List<Qso>? _segmentedLog;
  Operation? _segmentedOperation;
  SegmentedOperation? _segmented;

  /// The calls checked: on the air now, or those the open contact was made
  /// under.
  List<String> get checked {
    final operation = config().operation;
    if (_editing) return _contactCalls ?? _segmentCalls;
    _settle();
    final pending = _pendingOff;
    if (pending == null) return onAirStationCalls(operation);
    final on = [
      for (final call in operation.stationCalls)
        if (!pending.contains(call)) call,
    ];
    return on.isEmpty ? operation.stationCalls : on;
  }

  /// What the last tap marked off, and the operator typed while composing,
  /// shown until the panel is handed an operation at least as new as this
  /// control's last write: read off the operation it still holds, a second
  /// tap would undo the first, and a contact logged would carry the old
  /// operator.
  Set<String>? _pendingOff;
  String? _typedOperator;

  /// Writes queued or running, and the stamp of the last one stored.
  int _inFlight = 0;
  int? _landedAt;

  /// Drops what is pending once the operation has caught up with it.
  void _settle() {
    final landed = _landedAt;
    if (_inFlight > 0 || landed == null || (config().operation.updatedAtMillis ?? 0) < landed) return;
    _pendingOff = null;
    _typedOperator = null;
    _landedAt = null;
  }

  /// The writes, one after another: each reads the operation the one
  /// before it stored, so none of them puts back what an earlier one changed.
  Future<void> _writes = Future.value();

  /// What the contact being composed carries ahead of the operation: the
  /// operator typed into the field, and the calls a tap just checked or
  /// unchecked, while their write has not reached the operation the panel
  /// holds. Empty when there is nothing pending — or while a saved contact
  /// is open, which carries its own.
  Map<String, dynamic> get ourForNewContact {
    if (_editing) return const {};
    _settle();
    final typed = _typedOperator;
    final calls = _pendingOff == null ? null : checked;
    return {
      'operatorCall': ?typed,
      if (calls != null) ...{ourStationCallsKey: calls, 'call': calls.first},
    };
  }

  /// The operator as the control shows it: the operation's, or the open
  /// contact's own.
  String get _operatorCall {
    if (!_editing) {
      _settle();
      return _typedOperator ?? operatorCallFor(config().operation);
    }
    final ours = {..._contactOur, ...config().ourExtra};
    return (asQsonString(ours['operatorCall']) ?? '').trim();
  }

  /// The chip: how many calls are checked, the one call when only one is,
  /// or the operator.
  String get summary {
    if (multiCall) {
      final on = checked;
      return on.length == 1 ? on.first : t.loggingControls.stationCallsOnAir(count: on.length);
    }
    final operatorCall = _operatorCall;
    return operatorCall.isEmpty ? t.loggingControls.operatorControl : operatorCall;
  }

  /// Writes the field from what the control speaks for — on opening, and
  /// whenever the entry under an open control is replaced.
  void seed() {
    if (focusNode.hasFocus) return;
    operatorController.text = _operatorCall;
  }

  /// Checks or unchecks [call]. The last checked call stays checked: a
  /// contact made under no call belongs in no submission.
  void toggle(String call, bool on) {
    final current = checked;
    final next = [
      for (final listed in calls)
        if (listed == call ? on : current.contains(listed)) listed,
    ];
    if (next.isEmpty) return;
    // Nowhere to write: the tap would show a change nothing stores.
    if (!_editing && config().operations == null) return;
    if (_editing) {
      config().ourExtra
        ..[ourStationCallsKey] = next
        ..['call'] = next.first;
    } else {
      _pendingOff = {
        for (final listed in calls)
          if (!next.contains(listed)) listed,
      };
      // This one call's change, over the off-list as STORED: a whole list as
      // this panel saw it would put back a call another device, or the other
      // SO2R set, took off a moment ago.
      // Refused — null — when another device or set already took every other
      // call off: the last one on the air stays on.
      unawaited(
        _save((data) {
          final stored = Operation(uuid: '', data: data);
          final off = {...stationCallsOffFor(stored)};
          on ? off.remove(call) : off.add(call);
          if (stored.stationCalls.every(off.contains)) return null;
          return withStationCallsOff(data, off);
        }),
      );
    }
    notify();
  }

  /// The field as it is typed. An open contact's operator follows it, like
  /// Notes, so the save that follows carries it. While composing it reaches
  /// the operation once the field is left, and the contact being composed
  /// carries it until that write is back ([ourForNewContact]).
  void onOperatorChanged(String value) {
    final typed = value.trim().toUpperCase();
    if (!_editing) {
      _typedOperator = typed;
      notify();
      return;
    }
    final stored = (asQsonString(_contactOur['operatorCall']) ?? '').trim().toUpperCase();
    if (typed == stored) {
      config().ourExtra.remove('operatorCall');
    } else {
      config().ourExtra['operatorCall'] = typed;
    }
    notify();
  }

  /// The operation's operator is written once the field is left — not per
  /// keystroke, which would sync every letter to every device.
  ///
  /// Only what was typed while composing is written — even when the field is
  /// left by opening a saved contact, or it would stamp the next contacts
  /// without the operation ever storing it. Whatever else the field holds
  /// when it is left — an open contact's operator, after that contact was
  /// saved and the entry wiped under the focused field — goes back to what
  /// the control now speaks for, never onto the operation.
  void _onFocusChanged() {
    if (focusNode.hasFocus || isDisposed) return;
    _settle();
    final typed = _typedOperator;
    if (typed != null) {
      if (typed == operatorCallFor(config().operation).toUpperCase()) {
        _typedOperator = null;
      } else if (config().operations != null) {
        unawaited(_save((data) => {...data, operatorCallKeyFor(multiIdentifierFor(config().operation)): typed}));
      }
    }
    if (typed == null || _editing) operatorController.text = _operatorCall;
  }

  /// Whether Edit list can store what it edits — offered only then.
  bool get canEditList => config().operations != null;

  /// Edit list: the operation's calls, changed from the next contact on.
  /// Stored even if the panel went away while the dialog was open: the
  /// operator pressed Save.
  ///
  /// What the dialog added and removed is applied to the list as STORED, not
  /// its result written whole: the dialog opened on the list the panel held,
  /// and a call another device added or removed since would be undone.
  Future<void> editList(BuildContext context) async {
    final shown = config().operation.stationCalls;
    final result = await showStationCallsDialog(context, shown);
    if (result == null) return;
    await _save((data) {
      final stored = Operation(uuid: '', data: data).stationCalls;
      final calls = [
        for (final call in stored)
          if (call.isNotEmpty && (result.contains(call) || !shown.contains(call))) call,
        for (final call in result)
          if (!stored.contains(call)) call,
      ];
      return calls.isEmpty ? null : withStationCalls(data, calls);
    }, freeze: true);
  }

  /// Writes the operation through [edit], after every write already queued,
  /// over the operation as STORED — not the one the panel was last handed,
  /// which lags a write just made. With [freeze], the contacts that list no
  /// calls are first stamped with the calls they were made under — and if
  /// that fails, nothing is written: a list changed over an unstamped log
  /// hands the new calls every contact in it.
  ///
  /// [edit] returning null writes nothing, and what is pending goes back to
  /// what the operation says.
  Future<void> _save(Map<String, dynamic>? Function(Map<String, dynamic> data) edit, {bool freeze = false}) {
    final config = this.config();
    final operations = config.operations;
    if (operations == null) return Future.value();
    final uuid = config.operation.uuid;
    Future<void> write() async {
      try {
        final operation = await operations.get(uuid);
        // Gone — purged, or deleted on another device: nothing to write, and
        // nothing pending will ever be handed back to settle.
        if (operation == null) {
          _dropPending();
          return;
        }
        final edited = edit({...operation.data});
        if (edited == null) {
          _dropPending();
          return;
        }
        if (freeze) await config.qsos.freezeStationCalls(uuid, operation.data);
        // Read before the save, which stamps the row at or after it: the
        // operation the panel is handed back is ours once it is this new.
        final savedFrom = realNowMillis();
        await operations.saveData(Operation(uuid: uuid, data: edited));
        _landedAt = savedFrom;
      } catch (e, stack) {
        _dropPending();
        // Reported whether or not the panel is still there: a write that
        // failed after the operator left the screen is still a failure.
        config.onWriteFailed(e, stack);
      } finally {
        _inFlight--;
        notify();
      }
    }

    _inFlight++;
    // write() reports its own failures; past its catch only the report itself
    // or a notify could throw. The queue must not stop at one, or nothing this
    // panel changes would be stored again.
    return _writes = _writes.catchError((Object _) {}).then((_) => write());
  }

  /// The control goes back to showing what the operation says.
  /// Never into a field being typed in ([seed]): the operator's next
  /// keystrokes would land in text they did not type.
  void _dropPending() {
    _pendingOff = null;
    _typedOperator = null;
    if (!isDisposed) seed();
  }

  /// A typed operator not yet written is written now: the field that would
  /// have been left goes away with the panel, and the operation would never
  /// learn it. The write survives the panel, like Edit list's.
  @override
  void dispose() {
    final typed = _typedOperator;
    if (typed != null && typed != operatorCallFor(config().operation).toUpperCase() && config().operations != null) {
      final key = operatorCallKeyFor(multiIdentifierFor(config().operation));
      unawaited(_save((data) => {...data, key: typed}));
    }
    focusNode
      ..removeListener(_onFocusChanged)
      ..dispose();
    operatorController.dispose();
    super.dispose();
  }
}

/// The Operator control's spec.
SecondaryControlSpec operatorControlSpec(OperatorControlModel model, ThemeData theme) {
  return SecondaryControlSpec(
    key: 'operator',
    icon: operatorChipIcon,
    summary: model.summary,
    expandedBuilder: (context) => _OperatorControls(model: model, theme: theme),
  );
}

class _OperatorControls extends StatelessWidget {
  const _OperatorControls({required this.model, required this.theme});

  final OperatorControlModel model;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    final onStrip = theme.colorScheme.onTertiaryContainer;
    // One call: the operator, and no list to edit — a second call is added
    // in Operation Details, where the operator is cleared with it.
    if (!model.multiCall) {
      return SizedBox(
        width: 160,
        child: TextField(
          controller: model.operatorController,
          focusNode: model.focusNode,
          style: haloMonoStyle(context, fontSize: 15, fontWeight: FontWeight.w500),
          decoration: poloFieldDecoration(context, t.loggingControls.operatorField, labelColor: onStrip),
          textCapitalization: TextCapitalization.characters,
          inputFormatters: const [UpperCaseTextFormatter()],
          autocorrect: false,
          onChanged: model.onOperatorChanged,
        ),
      );
    }
    // No builder of its own: the model's notify rebuilds the whole panel,
    // and this with it.
    final checked = model.checked;
    final scheme = theme.colorScheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // The calls on a ground of their own, scrolling sideways when they
        // outgrow the strip, and Edit list beside them rather than among
        // them, where it would scroll away with the calls.
        Flexible(
          child: DecoratedBox(
            // The logging controls' own ground, the one their fields sit on.
            decoration: BoxDecoration(color: scheme.tertiaryContainer, borderRadius: BorderRadius.circular(6)),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: Space.xs),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final call in model.calls)
                    _CallCheckbox(call: call, value: checked.contains(call), color: onStrip, onChanged: (on) => model.toggle(call, on)),
                ],
              ),
            ),
          ),
        ),
        if (model.canEditList) ...[
          const SizedBox(width: Space.xs),
          IconButton(
            onPressed: () => model.editList(context),
            icon: Icon(MdiIcons.playlistEdit, color: onStrip, semanticLabel: t.loggingControls.editStationCalls),
          ),
        ],
      ],
    );
  }
}

class _CallCheckbox extends StatelessWidget {
  const _CallCheckbox({required this.call, required this.value, required this.color, required this.onChanged});

  final String call;
  final bool value;
  final Color color;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => onChanged(!value),
      borderRadius: BorderRadius.circular(4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Checkbox(value: value, onChanged: (on) => onChanged(on ?? false)),
          Text(
            call,
            style: haloMonoStyle(context, fontSize: 15, fontWeight: FontWeight.w500).copyWith(color: color),
          ),
          const SizedBox(width: Space.xs),
        ],
      ),
    );
  }
}

/// The station calls editor behind Edit list: remove a call, add one. Returns
/// the new list, or null when cancelled or left as it was.
Future<List<String>?> showStationCallsDialog(BuildContext context, List<String> calls) {
  return showHaloDialog<List<String>>(
    context: context,
    builder: (context) => _StationCallsDialog(
      initial: [
        for (final call in calls)
          if (call.isNotEmpty) call,
      ],
    ),
  );
}

class _StationCallsDialog extends StatefulWidget {
  const _StationCallsDialog({required this.initial});

  final List<String> initial;

  @override
  State<_StationCallsDialog> createState() => _StationCallsDialogState();
}

class _StationCallsDialogState extends State<_StationCallsDialog> {
  late final List<String> _calls = [...widget.initial];
  final _addController = TextEditingController();

  @override
  void dispose() {
    _addController.dispose();
    super.dispose();
  }

  void _add() {
    final typed = splitStationCalls(_addController.text).where((call) => call.isNotEmpty && !_calls.contains(call));
    setState(() {
      _calls.addAll(typed);
      _addController.clear();
    });
  }

  bool get _changed => _calls.length != widget.initial.length || _calls.indexed.any((entry) => widget.initial[entry.$1] != entry.$2);

  @override
  Widget build(BuildContext context) {
    final l = t.loggingControls;
    return HaloDialog(
      title: Text(l.stationCallsTitle),
      content: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l.stationCallsHint, style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: Space.sm),
            for (final call in _calls)
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: Text(call, style: haloMonoStyle(context, fontSize: 15, fontWeight: FontWeight.w500)),
                trailing: IconButton(
                  icon: Icon(MdiIcons.close, semanticLabel: l.stationCallsRemove(call: call)),
                  // The last call stays: an operation is always run under one.
                  onPressed: _calls.length < 2 ? null : () => setState(() => _calls.remove(call)),
                ),
              ),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _addController,
                    autofocus: true,
                    decoration: poloFieldDecoration(context, l.stationCallsAdd),
                    textCapitalization: TextCapitalization.characters,
                    inputFormatters: const [UpperCaseTextFormatter()],
                    autocorrect: false,
                    onSubmitted: (_) => _add(),
                  ),
                ),
                const SizedBox(width: Space.sm),
                TextButton(onPressed: _add, child: Text(l.stationCallsAddButton)),
              ],
            ),
          ],
        ),
      ),
      cancel: TextButton(onPressed: () => Navigator.of(context).pop(), child: Text(t.common.cancel)),
      actions: [
        FilledButton(
          // A call still sitting in the field is one the operator meant to add.
          onPressed: () {
            _add();
            Navigator.of(context).pop(_changed ? _calls : null);
          },
          child: Text(t.common.save),
        ),
      ],
    );
  }
}
