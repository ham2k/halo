// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// A radio's audio in its equipment editor (docs/design/audio.md): hearing it
// in HaLo, talking through HaLo, and how far behind its audio may fall.
// Beside the station panel rather than in it, which is at its size budget.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:halo_audio/halo_audio.dart' show AudioDevice, HaloAudio, HaloAudioException, matchAudioDevice;
import 'package:halo_i18n/halo_i18n.dart';
import 'package:halo_widgets/halo_widgets.dart';

import '../services/audio/radio_audio.dart';
import '../services/cat/driver.dart' show EquipmentDriver;
import '../services/cat/cat_service.dart';
import '../services/cat/equipment.dart' show EquipmentNode;
import 'station_rows.dart' show CurrentRowFrame;
import '../services/halo_services.dart';

/// Offered under the experiment, where this device has the audio engine,
/// for a driver whose sessions carry the audio. Whether the radio is heard
/// in HaLo, and whether the operator talks through it, is each set's
/// (`StationPanel`'s set details): a radio of several receivers has one
/// editor and a choice per receiver. Where HaLo plays what it hears is the
/// operator's, not a radio's: their headphones, for every radio.
class RadioAudioEditorFields {
  RadioAudioEditorFields(HaLoServices services, EquipmentDriver driver, this._config) {
    hears = radioAudioAvailable(services.settings) && driver.carriesReceiveAudio;
  }

  final Map<String, dynamic> _config;
  late final bool hears;

  /// Under More: rarely touched once it suits the network the radio is
  /// reached over.
  List<Map<String, dynamic>> more(BuildContext context) {
    final st = context.t.settings.station;
    return [
      if (hears)
        {
          'type': 'field',
          'fieldType': 'select',
          'key': receiveAudioDelayConfigKey,
          'label': st.receiveAudioDelay,
          'description': st.receiveAudioDelayDescription,
          'options': [
            {'value': 40, 'label': st.receiveAudioDelay40},
            {'value': 100, 'label': st.receiveAudioDelay100},
            {'value': 250, 'label': st.receiveAudioDelay250},
            {'value': 500, 'label': st.receiveAudioDelay500},
          ],
        },
    ];
  }

  /// The delay shown as what an unset one does, rather than as no choice.
  Map<String, dynamic> get initial => {if (hears && _config[receiveAudioDelayConfigKey] == null) receiveAudioDelayConfigKey: receiveAudioDelayDefault};
}

/// The station's audio mixing in Current Configuration, once any radio's
/// audio goes through this computer ([CatRadioAudioChoices.radiosThroughComputer]):
/// folded under its row, the overall volume, each radio's level in the mix,
/// and the output every radio plays on and the microphone.
class AudioMixingRow extends StatelessWidget {
  const AudioMixingRow({super.key, required this.services});

  final HaLoServices services;

  @override
  Widget build(BuildContext context) {
    final st = context.t.settings.station;
    final cat = services.cat;
    // Folded, the row still says what is muted: a mute is kept across
    // launches, and a station that comes back silent says why on its face.
    final mutedRadios = [
      for (final radio in _bySet(cat))
        if (cat.mixMuted(radio.uuid)) _mixName(context, cat, radio),
    ];
    final muted = cat.mixVolumeMuted
        ? st.audioMixAllMuted
        : mutedRadios.isEmpty
        ? null
        : st.audioMixMuted(names: mutedRadios.join(', '));
    return CurrentRowFrame(
      child: ListTile(
        leading: const Icon(MdiIcons.tuneVertical, size: 24),
        title: Text(st.audioMixing, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: muted == null ? null : Text(muted, style: TextStyle(color: Theme.of(context).colorScheme.error)),
      ),
    );
  }

  /// A radio's name in the mix: by its set and the radio's own name, as the
  /// operator tells the radios they work apart ("A: RadioRoom"), the
  /// receiver on it left out. Only the sets' radios are in the mix.
  static String _mixName(BuildContext context, CatService cat, EquipmentNode radio) =>
      context.t.settings.station.audioMixRadioInSet(set: cat.setOfRadio(radio.uuid) ?? '', name: cat.displayNameFor(radio));

  /// The radios in the mix, set A's first.
  static List<EquipmentNode> _bySet(CatService cat) => [
    for (final radio in cat.radiosThroughComputer)
      if (cat.heardThroughComputer(radio.uuid)) radio,
  ]..sort((a, b) => (cat.isRadio1(a.uuid) ? 0 : 1).compareTo(cat.isRadio1(b.uuid) ? 0 : 1));

  /// Folded under the row: the overall volume, each radio's level, then
  /// where the mix plays and the microphone it takes.
  static List<Widget> details(BuildContext context, HaLoServices services, {required EdgeInsets inset}) {
    final cat = services.cat;
    Widget padded(Widget child) => Padding(padding: EdgeInsets.fromLTRB(inset.left, 0, inset.right, Space.md), child: child);
    return [
      padded(
        _MixSlider(
          label: context.t.settings.station.audioVolume,
          strong: true,
          muted: cat.mixVolumeMuted,
          onMuted: (muted) => unawaited(cat.setMixVolumeMuted(muted)),
          value: cat.mixVolume,
          onChanged: (volume) => unawaited(cat.setMixVolume(volume)),
          onChangeEnd: (volume) => unawaited(cat.setMixVolume(volume, store: true)),
        ),
      ),
      for (final radio in _bySet(cat))
        padded(
          _MixSlider(
            label: _mixName(context, cat, radio),
            muted: cat.mixMuted(radio.uuid),
            onMuted: (muted) => unawaited(cat.setMixMuted(radio.uuid, muted)),
            value: cat.mixLevel(radio.uuid),
            onChanged: (level) => unawaited(cat.setMixLevel(radio.uuid, level)),
            onChangeEnd: (level) => unawaited(cat.setMixLevel(radio.uuid, level, store: true)),
          ),
        ),
      padded(
        Row(
          spacing: Space.md,
          children: [
            Expanded(child: StationAudioDevicePicker.output(services: services)),
            Expanded(child: StationAudioDevicePicker.microphone(services: services)),
          ],
        ),
      ),
    ];
  }
}

/// A level in the mix: the slider filling the row's first half, so every
/// slider starts and ends where the others do, then its mute, then its name.
/// [strong] is the overall volume, over the radios' own.
class _MixSlider extends StatelessWidget {
  const _MixSlider({
    required this.label,
    required this.muted,
    required this.onMuted,
    required this.value,
    required this.onChanged,
    required this.onChangeEnd,
    this.strong = false,
  });

  final String label;
  final bool strong;

  /// Muted, the slider keeps its value: what it comes back at, once the
  /// button or a move of the slider unmutes it.
  final bool muted;
  final ValueChanged<bool> onMuted;
  final double value;
  final ValueChanged<double> onChanged;
  final ValueChanged<double> onChangeEnd;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        // Dimmed while muted, and moving it unmutes it: a level moved and
        // not heard reads as a mixer that does nothing.
        child: Opacity(
          opacity: muted ? 0.4 : 1,
          child: Slider(
            value: value,
            onChanged: (level) {
              if (muted) onMuted(false);
              onChanged(level);
            },
            onChangeEnd: onChangeEnd,
            semanticFormatterCallback: (v) => '$label ${(v * 100).round()}%',
          ),
        ),
      ),
      IconButton(
        icon: Icon(
          muted ? MdiIcons.volumeOff : MdiIcons.volumeHigh,
          semanticLabel: muted ? context.t.settings.station.audioUnmute(name: label) : context.t.settings.station.audioMute(name: label),
        ),
        color: muted ? Theme.of(context).colorScheme.error : null,
        onPressed: () => onMuted(!muted),
      ),
      Expanded(
        child: Text(
          label,
          style: strong ? const TextStyle(fontWeight: FontWeight.bold) : null,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    ],
  );
}

/// The operator's microphone, or their headphones, picked from the devices
/// this computer has: one each, since the operator speaks into one
/// microphone and hears every radio in one pair of headphones.
class StationAudioDevicePicker extends StatefulWidget {
  const StationAudioDevicePicker.microphone({super.key, required this.services}) : output = false;
  const StationAudioDevicePicker.output({super.key, required this.services}) : output = true;

  final HaLoServices services;
  final bool output;

  @override
  State<StationAudioDevicePicker> createState() => _StationAudioDevicePickerState();
}

class _StationAudioDevicePickerState extends State<StationAudioDevicePicker> {
  static const _default = '';
  static const _missing = '\u0000missing';
  var _devices = const <AudioDevice>[];

  /// The system would not list its devices: a stored one is then not known
  /// to be missing, only not listed, and says so.
  var _unlisted = false;

  @override
  void initState() {
    super.initState();
    try {
      _devices = widget.output ? HaloAudio.playbackDevices() : HaloAudio.captureDevices();
    } on HaloAudioException {
      // The system default is still pickable.
      _unlisted = true;
    }
  }

  @override
  Widget build(BuildContext context) {
    final st = context.t.settings.station;
    final cat = widget.services.cat;
    final stored = widget.output ? cat.operatorHeadphones : cat.operatorMicrophone;
    final found = stored == null ? null : matchAudioDevice(_devices, id: stored.id, name: stored.name);
    final value = stored == null ? _default : (found?.id ?? _missing);
    return DropdownButtonFormField<String>(
      key: ValueKey('${widget.output ? 'output' : 'microphone'}:$value'),
      isExpanded: true,
      initialValue: value,
      icon: dropdownTrailingIcon,
      decoration: poloFieldDecoration(context, widget.output ? st.audioOutput : st.microphone),
      menuMaxHeight: dropdownMenuMaxHeight(context),
      items: [
        DropdownMenuItem(
          value: _default,
          child: Text(widget.output ? st.audioOutputDefault : st.microphoneDefault, overflow: TextOverflow.ellipsis),
        ),
        if (value == _missing)
          DropdownMenuItem(
            value: _missing,
            child: Text(
              _unlisted
                  ? st.audioDevicesUnlisted(name: stored?.name ?? stored?.id ?? '')
                  : st.receiveAudioOutputMissing(name: stored?.name ?? stored?.id ?? ''),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        for (final device in _devices)
          DropdownMenuItem(
            value: device.id,
            child: Text(device.name, overflow: TextOverflow.ellipsis),
          ),
      ],
      onChanged: (id) {
        if (id == null || id == _missing) return;
        final device = id == _default ? null : _devices.where((d) => d.id == id).firstOrNull;
        final saved = widget.output ? cat.setOperatorHeadphones(device) : cat.setOperatorMicrophone(device);
        unawaited(saved.then((_) => mounted ? setState(() {}) : null));
      },
    );
  }
}
