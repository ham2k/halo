// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Which secondary controls the logging panel's strip can hold, in what
// order, and which of them the operator has hidden — the catalog the strip
// is assembled from and the settings dialog edits. Descriptors carry just
// enough for the dialog and the ordering (key/icon/label/mandatory); the
// actual `SecondaryControlSpec` (live summary + expanded-input builder) is
// only built, by the panel, for controls that end up visible.

import 'package:flutter/material.dart';
import 'package:halo_i18n/halo_i18n.dart';

import 'halo_dialog.dart';
import 'icon_resolver.dart';
import 'logging_controls_operator.dart' show operatorChipIcon;
import 'logging_controls_radio.dart' show powerChipIcon;
import 'logging_controls_spotting.dart' show spottingChipIcon;
import 'logging_controls_time.dart' show timeChipIcon;
import 'mdi_icons.g.dart';
import 'modal_pane.dart' show showHaloDialog;
import 'qso_edit_pane.dart' show moreChipIcon, notesChipIcon;
import 'spacing.dart';

/// One secondary control as the settings dialog and the ordering see it.
class ControlDescriptor {
  final String key;
  final IconData icon;
  final String label;

  /// Time and Radio — can't be hidden, so the settings dialog shows their
  /// checkbox permanently checked and disabled.
  final bool mandatory;

  /// Off until the operator asks for it. The operator's own decision is
  /// recorded the moment they save the settings dialog — which always
  /// writes the full order — so "this key is not in `controlOrder` yet" is
  /// what distinguishes "never decided" from "decided against", and is why
  /// a default-hidden control needs no second stored set of its own.
  final bool defaultHidden;

  /// For a control whose default follows the OPERATION rather than the
  /// install — whether it is in the row until the operator decides
  /// otherwise. Null for every other control. The decision, once made, is
  /// the operator's for every operation: off in the hidden set, on as
  /// [shownMarker] in the saved order.
  final bool? autoShown;

  /// For a chip contributed by an activity: the control it belongs to, which
  /// the panel builds the chip from. Null for the built-in controls.
  final Map<String, dynamic>? activityControl;

  const ControlDescriptor({
    required this.key,
    required this.icon,
    required this.label,
    this.mandatory = false,
    this.defaultHidden = false,
    this.autoShown,
    this.activityControl,
  });
}

/// The saved-order entry recording that the operator turned an
/// [ControlDescriptor.autoShown] control ON. The order is the one store that
/// can hold it: the hidden set records the opposite decision, and the order
/// ignores a key no control has, so nothing else reads this as a control.
String shownMarker(String key) => '+$key';

/// What the catalog reads from the panel's live configuration.
typedef ControlCatalogConfig = ({
  /// The Radio chip's glyph, as its model resolves it for the rig in use.
  IconData radioIcon,

  /// Power lives on the VFO ([Vfo.power]); without a store the control would
  /// edit nothing, so it is not offered at all.
  bool hasPowerStore,

  /// The operation has several station calls, or an operator apart from its
  /// one call ([operatorControlOffered]) — the Operator control's default.
  /// Without either it has nothing to say, and stays out of the row unless
  /// the operator has asked for it.
  bool offersOperator,

  /// Both a way to suggest spot sources and a way to send.
  bool canSpot,

  /// The operation's activity controls; only `refList` ones contribute a
  /// secondary chip (`text` controls are primary fields).
  Iterable<Map<String, dynamic>> activityControls,

  /// The operator's saved order and hidden set, as stored.
  List<String> controlOrder,
  Set<String> hiddenControlKeys,

  /// Spotting after the activity references rather than before them — see
  /// [ControlStripSettings.spottingAfterReferences].
  bool spottingAfterReferences,

  /// The app's own controls ([ControlStripSettings.hostControls]), placed
  /// right after Radio.
  List<ControlDescriptor> hostControls,
});

/// The strip's catalog. See the file comment.
class SecondaryControlCatalog {
  SecondaryControlCatalog({required this.config});

  final ControlCatalogConfig Function() config;

  /// Every control this operation offers, in the order the strip would show
  /// them to a fresh install.
  List<ControlDescriptor> descriptors() => _descriptors(config());

  /// Each public entry point reads the configuration ONCE and hands the
  /// snapshot down, so one call can never pair descriptors from one
  /// configuration with the order or the hidden set of another.
  List<ControlDescriptor> _descriptors(ControlCatalogConfig config) => [
    ControlDescriptor(key: 'time', icon: timeChipIcon, label: t.loggingControls.timeControl, mandatory: true),
    ControlDescriptor(key: 'radio', icon: config.radioIcon, label: t.loggingControls.radioControl, mandatory: true),
    ...config.hostControls,
    ControlDescriptor(key: 'operator', icon: operatorChipIcon, label: t.loggingControls.operatorControl, autoShown: config.offersOperator),
    if (config.hasPowerStore) ControlDescriptor(key: 'power', icon: powerChipIcon, label: t.loggingControls.powerControl, defaultHidden: true),
    if (config.canSpot && !config.spottingAfterReferences) ControlDescriptor(key: 'spotting', icon: spottingChipIcon, label: t.loggingControls.spottingControl),
    for (final control in config.activityControls)
      if ((control['input'] as Map?)?['kind'] == 'refList')
        ControlDescriptor(
          key: control['key'] as String,
          icon: resolveIconName(control['icon'] as String?),
          label: (control['label'] as String?) ?? control['key'] as String,
          activityControl: control,
        ),
    if (config.canSpot && config.spottingAfterReferences) ControlDescriptor(key: 'spotting', icon: spottingChipIcon, label: t.loggingControls.spottingControl),
    // Beside More, and off until the operator has been asked: a note
    // per contact is a thing few operators keep, and the ones who do
    // know to go looking for it. The More pane edits the same value for
    // everyone else.
    ControlDescriptor(key: 'notes', icon: notesChipIcon, label: t.loggingControls.notesControl, defaultHidden: true),
    ControlDescriptor(key: 'more', icon: moreChipIcon, label: t.loggingControls.more),
  ];

  /// Whether this control stays out of the row. A [ControlDescriptor
  /// .defaultHidden] control is out until the operator has been asked —
  /// which the saved order records, since the settings dialog writes every
  /// key it offered whether or not it was checked.
  bool isHidden(ControlDescriptor descriptor) => _isHidden(config(), descriptor);

  bool _isHidden(ControlCatalogConfig config, ControlDescriptor descriptor) {
    if (descriptor.mandatory) return false;
    if (config.hiddenControlKeys.contains(descriptor.key)) return true;
    if (descriptor.autoShown case final shown?) return !shown && !config.controlOrder.contains(shownMarker(descriptor.key));
    return descriptor.defaultHidden && !config.controlOrder.contains(descriptor.key);
  }

  /// The saved order, filtered to keys that still exist and de-duplicated,
  /// with any remaining known keys slotted in where the descriptor list puts
  /// them — so a fresh install (empty order) or a newly-added control both
  /// land in their intended place.
  ///
  /// Slotted rather than appended: every operator who has ever saved the
  /// settings dialog has a stored order, and appending puts a new control
  /// at the very end of the row — past More — however deliberately the
  /// descriptor list placed it beside its neighbour. A key with no earlier
  /// descriptor already in the order still goes last, which is what the
  /// append did for all of them.
  List<String> effectiveOrder() {
    final config = this.config();
    return _effectiveOrder(config, _descriptors(config));
  }

  List<String> _effectiveOrder(ControlCatalogConfig config, List<ControlDescriptor> descriptors) {
    final allKeys = descriptors.map((d) => d.key).toSet();
    final order = <String>[];
    for (final key in config.controlOrder) {
      if (allKeys.contains(key) && !order.contains(key)) order.add(key);
    }
    for (final (index, descriptor) in descriptors.indexed) {
      if (order.contains(descriptor.key)) continue;
      // Immediately after the nearest preceding descriptor that IS placed —
      // walking backwards, so a run of new keys keeps its own relative order.
      var insertAt = order.length;
      for (var previous = index - 1; previous >= 0; previous--) {
        final at = order.indexOf(descriptors[previous].key);
        if (at >= 0) {
          insertAt = at + 1;
          break;
        }
      }
      order.insert(insertAt, descriptor.key);
    }
    return order;
  }

  /// The controls in the row, in row order.
  List<ControlDescriptor> visibleControls() {
    final config = this.config();
    final descriptors = _descriptors(config);
    final byKey = {for (final d in descriptors) d.key: d};
    return [
      for (final key in _effectiveOrder(config, descriptors))
        if (byKey[key] case final descriptor? when !_isHidden(config, descriptor)) descriptor,
    ];
  }

  /// The keys of [visibleControls].
  List<String> visibleKeys() => [for (final d in visibleControls()) d.key];

  /// Whether the Power control is in the row: offered by this operation, and
  /// not hidden.
  bool get powerVisible {
    final config = this.config();
    return _descriptors(config).any((d) => d.key == 'power' && !_isHidden(config, d));
  }

  /// What the settings dialog starts from. The stored hidden set FIRST, and
  /// kept whole: the descriptors are what this operation offers, so
  /// rebuilding the set from them alone would drop a control hidden while
  /// some other activity was running — saving the dialog here would then
  /// un-hide it everywhere. On top of that, the never-decided default-hidden
  /// controls, which must arrive unchecked; saving is what turns that into a
  /// recorded decision.
  ({List<ControlDescriptor> descriptors, List<String> order, Set<String> hidden}) settingsDraft() {
    final config = this.config();
    final descriptors = _descriptors(config);
    return (
      descriptors: descriptors,
      order: _effectiveOrder(config, descriptors),
      hidden: {
        ...config.hiddenControlKeys,
        for (final descriptor in descriptors)
          if (_isHidden(config, descriptor)) descriptor.key,
      },
    );
  }

  /// What the settings dialog stores, from the [draft] it opened on and the
  /// [order] and [hidden] it ends with. An [ControlDescriptor.autoShown]
  /// control whose checkbox is where the draft put it keeps whatever was stored for it, decided or not:
  /// saving the dialog to move Notes on an operation where Operator is off by
  /// default must not hide it on the operations where it is on. One the
  /// operator ticked or unticked is decided, for every operation.
  (List<String>, Set<String>) settingsResult(
    ({List<ControlDescriptor> descriptors, List<String> order, Set<String> hidden}) draft,
    List<String> order,
    Set<String> hidden,
  ) {
    final config = this.config();
    final resultOrder = [...order];
    final resultHidden = {...hidden};
    for (final descriptor in draft.descriptors) {
      if (descriptor.autoShown == null) continue;
      final key = descriptor.key;
      final shown = !hidden.contains(key);
      final toggled = shown == draft.hidden.contains(key);
      final off = toggled ? !shown : config.hiddenControlKeys.contains(key);
      final pinned = toggled ? shown : config.controlOrder.contains(shownMarker(key));
      if (off) {
        resultHidden.add(key);
      } else {
        resultHidden.remove(key);
      }
      if (pinned) resultOrder.add(shownMarker(key));
    }
    return (resultOrder, resultHidden);
  }
}

/// The show/hide + reorder dialog over [catalog]. Resolves to the order and
/// the hidden set to store, or null when cancelled.
Future<(List<String>, Set<String>)?> showControlSettingsDialog(BuildContext context, SecondaryControlCatalog catalog) {
  final draft = catalog.settingsDraft();
  final byKey = {for (final d in draft.descriptors) d.key: d};
  var order = draft.order;
  var hidden = draft.hidden;

  return showHaloDialog<(List<String>, Set<String>)>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (dialogContext, setDialogState) => HaloDialog(
        title: Text(t.loggingControls.controlSettings),
        // The ReorderableListView scrolls itself, so the shell must not:
        // nesting two scrollables on one axis leaves the inner list with no
        // scroll extent, and a drag toward the edge has nothing to
        // auto-scroll. `wide` because this carries a list, not a prompt.
        scrollable: false,
        wide: true,
        content: SizedBox(
          width: 360,
          child: ReorderableListView(
            shrinkWrap: true,
            buildDefaultDragHandles: false,
            onReorderItem: (oldIndex, newIndex) => setDialogState(() {
              final reordered = List<String>.from(order);
              final key = reordered.removeAt(oldIndex);
              reordered.insert(newIndex, key);
              order = reordered;
            }),
            children: [
              for (final (index, key) in order.indexed)
                if (byKey[key] case final descriptor?)
                  ListTile(
                    key: ValueKey(key),
                    leading: ReorderableDragStartListener(index: index, child: const Icon(MdiIcons.dragHorizontalVariant)),
                    title: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(descriptor.icon, size: 18),
                        const SizedBox(width: Space.lg),
                        Text(descriptor.label),
                      ],
                    ),
                    trailing: Checkbox(
                      value: descriptor.mandatory || !hidden.contains(key),
                      onChanged: descriptor.mandatory
                          ? null
                          : (checked) => setDialogState(() {
                              final updated = Set<String>.from(hidden);
                              if (checked == true) {
                                updated.remove(key);
                              } else {
                                updated.add(key);
                              }
                              hidden = updated;
                            }),
                    ),
                  ),
            ],
          ),
        ),
        cancel: TextButton(onPressed: () => Navigator.of(dialogContext).pop(), child: Text(t.common.cancel)),
        actions: [FilledButton(onPressed: () => Navigator.of(dialogContext).pop(catalog.settingsResult(draft, order, hidden)), child: Text(t.common.save))],
      ),
    ),
  );
}
