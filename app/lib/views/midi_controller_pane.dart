// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// A MIDI controller node's editor: its name, its device, and which control
// drives what (docs/design/cat.md § MIDI controllers). Its own pane rather
// than the equipment form: Learn writes the mapping the moment a control
// moves, and the form saves back the config it was opened with.

import 'package:flutter/material.dart';
import 'package:halo_i18n/halo_i18n.dart';
import 'package:halo_widgets/halo_widgets.dart';

import '../services/cat/equipment.dart';
import '../services/halo_services.dart';
import '../services/midi/midi_codec.dart';
import '../services/midi/midi_controller.dart';
import '../services/midi/midi_mapping.dart';
import '../services/midi/midi_service.dart';
import '../services/midi/midi_targets.dart';
import 'settings/keyboard_shortcuts_panel.dart' show keyCommandTitle;

Future<void> showMidiControllerPane(BuildContext context, {required HaLoServices services, required String nodeUuid, required VoidCallback onRemove}) {
  final node = services.cat.nodeFor(nodeUuid);
  return showModalPane<void>(
    context,
    title: node == null ? context.t.settings.station.models.midiController : services.cat.displayNameFor(node),
    closeLabel: context.t.common.close,
    scrollable: false,
    builder: (_) => _MidiControllerPane(services: services, nodeUuid: nodeUuid, onRemove: onRemove),
  );
}

String midiTargetLabel(BuildContext context, MidiTarget target) {
  final l = context.t.settings.station.midi.targets;
  return switch (target.action) {
    MidiAction.vfoCoarse => l.vfoCoarse,
    MidiAction.vfoFine => l.vfoFine,
    MidiAction.ptt => l.ptt,
    MidiAction.power => l.power,
    MidiAction.wpm => l.wpm,
    MidiAction.bandUp => l.bandUp,
    MidiAction.bandDown => l.bandDown,
    MidiAction.modeNext => l.modeNext,
    MidiAction.passbandLow => l.passbandLow,
    MidiAction.passbandHigh => l.passbandHigh,
    MidiAction.afGain => l.afGain,
    MidiAction.rfGain => l.rfGain,
    MidiAction.mute => l.mute,
    MidiAction.message => l.message(n: target.message!),
    MidiAction.stop => l.stop,
  };
}

String midiControlLabel(BuildContext context, MidiControl control) {
  final l = context.t.settings.station.midi.control;
  return switch (control.kind) {
    MidiControlKind.cc => l.cc(number: control.number, channel: control.channel),
    MidiControlKind.note => l.note(number: control.number, channel: control.channel),
    MidiControlKind.pb => l.pb(channel: control.channel),
  };
}

String midiIgnoredText(BuildContext context, MidiIgnored reason) {
  final l = context.t.settings.station.midi.ignored;
  return switch (reason) {
    MidiIgnored.noRadio => l.noRadio,
    MidiIgnored.so2rOff => l.so2rOff,
    MidiIgnored.dataMode => l.dataMode,
    MidiIgnored.keyingOff => l.keyingOff,
    MidiIgnored.noPtt => l.noPtt,
    MidiIgnored.notPhone => l.notPhone,
    MidiIgnored.keyedElsewhere => l.keyedElsewhere,
    MidiIgnored.unsupported => l.unsupported,
    MidiIgnored.noMovement => l.noMovement,
    MidiIgnored.muteNeedsAf => l.muteNeedsAf,
  };
}

class _MidiControllerPane extends StatefulWidget {
  final HaLoServices services;
  final String nodeUuid;
  final VoidCallback onRemove;

  const _MidiControllerPane({required this.services, required this.nodeUuid, required this.onRemove});

  @override
  State<_MidiControllerPane> createState() => _MidiControllerPaneState();
}

/// Notifies when the node itself changes — its name, its config — and not
/// on the radio readings that make up most of CatService's notifications:
/// the pane's three dozen rows would otherwise rebuild on every poll.
class _NodeWatch extends ChangeNotifier {
  final HaLoServices services;
  final String uuid;
  EquipmentNode? _seen;

  _NodeWatch(this.services, this.uuid) : _seen = services.cat.nodeFor(uuid) {
    services.cat.addListener(_check);
  }

  void _check() {
    final node = services.cat.nodeFor(uuid);
    if (identical(node, _seen)) return;
    _seen = node;
    notifyListeners();
  }

  @override
  void dispose() {
    services.cat.removeListener(_check);
    super.dispose();
  }
}

class _MidiControllerPaneState extends State<_MidiControllerPane> {
  late final _name = TextEditingController(text: _node?.name ?? '');
  late final _watch = _NodeWatch(widget.services, widget.nodeUuid);

  EquipmentNode? get _node => widget.services.cat.nodeFor(widget.nodeUuid);
  MidiService get _midi => widget.services.midi;

  @override
  void dispose() {
    _saveName();
    // A row left learning would swallow the next message after the pane is
    // gone, with nothing on screen to say why a knob did nothing.
    if (_midi.learning.value?.nodeUuid == widget.nodeUuid) _midi.cancelLearn();
    _watch.dispose();
    _name.dispose();
    super.dispose();
  }

  void _saveName() {
    final node = _node;
    final name = _name.text.trim();
    if (node == null || name.isEmpty || name == node.name) return;
    widget.services.cat.updateNode(node.copyWith(name: name));
  }

  void _write(Map<String, dynamic> Function(Map<String, dynamic> config) change) {
    final node = _node;
    if (node == null) return;
    widget.services.cat.updateNode(node.copyWith(config: change(node.config)));
  }

  @override
  Widget build(BuildContext context) {
    final services = widget.services;
    return ListenableBuilder(
      listenable: Listenable.merge([_watch, _midi, _midi.devices, _midi.learning, services.settings]),
      builder: (context, _) {
        final node = _node;
        if (node == null) return const SizedBox.shrink();
        final mapping = MidiMapping.fromConfig(node.config);
        final m = context.t.settings.station.midi;
        final theme = Theme.of(context);
        final note = theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurface.withValues(alpha: 0.8));
        final so2r = services.settings.experimentEnabled('so2r') /* stored key, see experiments.yaml */;
        final keying = services.settings.experimentEnabled('keyer') /* stored key, see experiments.yaml */;
        List<Widget> rows(bool Function(MidiTarget) which) => [
          for (final target in midiTargets)
            if (which(target)) _TargetRow(services: services, watch: _watch, target: target, nodeUuid: node.uuid, mapping: mapping, write: _write),
        ];
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              color: haloDialogBandColorAt(context),
              padding: const EdgeInsets.fromLTRB(Space.xxl, Space.md, Space.xxl, Space.xl),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: _name,
                    decoration: poloFieldDecoration(context, m.name).copyWith(filled: true, fillColor: theme.colorScheme.surface),
                    onSubmitted: (_) => _saveName(),
                  ),
                  const SizedBox(height: Space.md),
                  RowSelectField(
                    label: m.device,
                    value: mapping.device,
                    placeholder: m.deviceNone,
                    rows: [
                      for (final name in _midi.devices.value) SelectRow(value: name, name: name, icon: 'midi'),
                      if (mapping.device case final saved? when !_midi.devices.value.contains(saved))
                        SelectRow(
                          value: saved,
                          name: m.deviceMissing(name: saved),
                        ),
                    ],
                    onChanged: (value) => _write((config) => {...config, midiDeviceConfigKey: value}),
                  ),
                  const SizedBox(height: Space.md),
                  Text(_statusText(context, node.uuid), style: note),
                  const SizedBox(height: Space.sm),
                  ValueListenableBuilder(
                    valueListenable: _midi.monitorFor(node.uuid),
                    builder: (context, line, _) => Text('${m.lastMessage}: ${line == null ? m.lastNone : _monitorText(context, line)}', style: note),
                  ),
                  if (!keying) ...[const SizedBox(height: Space.sm), Text(m.keyingNeedsExperiment, style: note)],
                ],
              ),
            ),
            Flexible(
              child: SettingsList(
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SectionHeader(m.sectionRadioA),
                      ...rows((t) => t.radio == 'A'),
                      SectionHeader(m.sectionRadioB, subtitle: so2r ? null : Text(m.radioBNeedsSo2r)),
                      ...rows((t) => t.radio == 'B'),
                      SectionHeader(m.sectionKeying),
                      ...rows((t) => t.radio == null),
                      ListTile(
                        leading: Icon(MdiIcons.trashCanOutline, color: theme.colorScheme.error),
                        title: Text(context.t.settings.station.remove, style: TextStyle(color: theme.colorScheme.error)),
                        // Closed before the confirmation, as the equipment
                        // form's Remove is: the question is about the
                        // controller, not this pane.
                        onTap: () {
                          Navigator.of(context).pop();
                          widget.onRemove();
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  String _statusText(BuildContext context, String uuid) {
    final m = context.t.settings.station.midi;
    return switch (_midi.statusFor(uuid)) {
      MidiDeviceStatus.noDevice => m.statusNoDevice,
      MidiDeviceStatus.waiting || MidiDeviceStatus.connecting => m.statusWaiting,
      MidiDeviceStatus.connected => m.statusConnected,
      MidiDeviceStatus.unavailable => m.statusUnavailable,
      MidiDeviceStatus.failed => m.statusFailed(message: _midi.failureFor(uuid) ?? ''),
    };
  }

  String _monitorText(BuildContext context, MidiMonitorLine line) {
    final message = line.message;
    final sent = '${midiControlLabel(context, message.control)} = ${message.raw}';
    final outcome = line.outcome;
    if (outcome == null) {
      final m = context.t.settings.station.midi;
      return '$sent → ${line.shortcut == null ? m.notMapped : m.shortcut(command: keyCommandTitle(context.t, line.shortcut!))}';
    }
    final label = midiTargetLabel(context, outcome.target);
    final radio = outcome.target.radio == null ? '' : ' ${outcome.target.radio}';
    final what = outcome.ignored != null ? ': ${midiIgnoredText(context, outcome.ignored!)}' : (outcome.value == null ? '' : ' ${outcome.value}');
    return '$sent → $label$radio$what';
  }
}

class _TargetRow extends StatelessWidget {
  final HaLoServices services;
  final Listenable watch;
  final MidiTarget target;
  final String nodeUuid;
  final MidiMapping mapping;
  final void Function(Map<String, dynamic> Function(Map<String, dynamic> config) change) write;

  const _TargetRow({required this.services, required this.watch, required this.target, required this.nodeUuid, required this.mapping, required this.write});

  MidiService get midi => services.midi;

  /// Whether the row has options for its settings dialog.
  bool get _hasOptions => target.kind == MidiTargetKind.encoder || target.action == MidiAction.ptt;

  @override
  Widget build(BuildContext context) {
    final m = context.t.settings.station.midi;
    final theme = Theme.of(context);
    final learning = midi.learning.value;
    final isLearning = learning != null && learning.nodeUuid == nodeUuid && learning.targetId == target.id;
    final control = mapping.controls[target.id];
    final String subtitle;
    if (isLearning && learning.refused != null) {
      subtitle = switch (learning.refused!) {
        MidiTargetKind.button => m.needsButton,
        MidiTargetKind.encoder => m.needsEncoder,
        MidiTargetKind.fader => m.needsFader,
      };
    } else if (isLearning) {
      subtitle = m.learning;
    } else {
      subtitle = control == null ? m.unmapped : midiControlLabel(context, control);
    }
    final label = midiTargetLabel(context, target);
    // A ListTile, so the row takes the list's own inset (SettingsList) and
    // lines up with the section header above it.
    return ListTile(
      title: Row(
        children: [
          Flexible(child: Text(label)),
          if (_hasOptions)
            IconButton(
              visualDensity: VisualDensity.compact,
              icon: Icon(MdiIcons.cogOutline, size: 18, semanticLabel: m.settingsFor(target: label)),
              onPressed: () => _showOptions(context, label),
            ),
        ],
      ),
      subtitle: Text(subtitle, style: isLearning ? TextStyle(color: theme.colorScheme.primary) : null),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (control != null && !isLearning)
            IconButton(
              icon: Icon(MdiIcons.closeCircleOutline, semanticLabel: m.clear),
              onPressed: () => write((config) => MidiMapping.assign(config, target.id, null)),
            ),
          const SizedBox(width: Space.sm),
          FilledButton.tonal(onPressed: () => midi.toggleLearn(nodeUuid, target.id), child: Text(isLearning ? context.t.common.cancel : m.learn)),
        ],
      ),
    );
  }

  /// The row's options, applied as they change — Done only closes.
  Future<void> _showOptions(BuildContext context, String label) => showHaloDialog<void>(
    context: context,
    builder: (context) => HaloDialog(
      title: Text(label),
      content: ListenableBuilder(
        listenable: watch,
        builder: (context, _) {
          final node = services.cat.nodeFor(nodeUuid);
          if (node == null) return const SizedBox.shrink();
          final fields = _optionFields(context, MidiMapping.fromConfig(node.config));
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final (i, field) in fields.indexed) ...[if (i > 0) const SizedBox(height: Space.lg), field],
            ],
          );
        },
      ),
      cancel: TextButton(onPressed: () => Navigator.of(context).pop(), child: Text(context.t.common.done)),
    ),
  );

  List<Widget> _optionFields(BuildContext context, MidiMapping mapping) {
    final m = context.t.settings.station.midi;
    return [
      if (target.kind == MidiTargetKind.encoder)
        RowSelectField(
          label: m.coding,
          value: mapping.codingFor(target.id).name,
          rows: [for (final coding in MidiEncoderCoding.values) SelectRow(value: coding.name, name: _codingLabel(context, coding))],
          onChanged: (value) => write((config) => MidiMapping.setOption(config, target.id, midiOptCoding, value!)),
        ),
      if (target.tunes || target.action == MidiAction.passbandLow || target.action == MidiAction.passbandHigh) ...[
        _stepField(context, mapping, m.step, cw: false),
        _stepField(context, mapping, m.stepCw, cw: true),
      ],
      if (target.action == MidiAction.ptt)
        RowSelectField(
          label: m.pttMode,
          value: mapping.pttToggles(target.id) ? midiPttToggle : midiPttHold,
          rows: [
            SelectRow(value: midiPttHold, name: m.pttHold),
            SelectRow(value: midiPttToggle, name: m.pttToggle),
          ],
          onChanged: (value) => write((config) => MidiMapping.setOption(config, target.id, midiOptPtt, value!)),
        ),
    ];
  }

  Widget _stepField(BuildContext context, MidiMapping mapping, String label, {required bool cw}) => RowSelectField(
    label: label,
    value: mapping.stepFor(target, cw: cw),
    rows: [for (final hz in midiStepChoices) SelectRow(value: hz, name: midiStepLabel(hz))],
    onChanged: (value) => write((config) => MidiMapping.setOption(config, target.id, cw ? midiOptStepCw : midiOptStepPhone, value!)),
  );

  static String _codingLabel(BuildContext context, MidiEncoderCoding coding) {
    final c = context.t.settings.station.midi.codings;
    return switch (coding) {
      MidiEncoderCoding.relative => c.relative,
      MidiEncoderCoding.twos => c.twos,
      MidiEncoderCoding.offset64 => c.offset64,
      MidiEncoderCoding.sign => c.sign,
      MidiEncoderCoding.absolute => c.absolute,
    };
  }
}
