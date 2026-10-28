// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// What keys CW and what plays phone messages, as pickers — on the Station
// panel's keying lines and atop each keyer's message editor, so the choice
// is made the same way wherever the operator meets it.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:halo_i18n/halo_i18n.dart';
import 'package:halo_widgets/halo_widgets.dart';

import '../services/cat/equipment.dart';
import '../services/halo_services.dart';
import '../services/peer/peer_station_radios.dart';
import '../services/settings_service.dart';
import 'station_rows.dart';
import 'voice_messages_dialog.dart' show peerDeviceLabel, showComputerVoiceSettingsDialog;

/// The keys a station can pick between: a paddle on the desk, or what keys
/// for the app — a keyer, or a radio whose CAT can.
List<EquipmentNode> keyNodes(HaLoServices services) {
  final cat = services.cat;
  return [
    for (final node in cat.nodes)
      if (cat.typeFor(node)?.category == kCategoryKey) node,
    if (services.settings.experimentEnabled('keyer') /* stored key, see experiments.yaml */ ) ...cat.keyerCandidates,
  ];
}

/// The key in use. NOT behind the keyer experiment: choosing which key a
/// contact is logged with is ordinary station info. Only the peer's key
/// among its choices is. [filled] for a picker on a dialog's band.
Widget cwKeyPicker(BuildContext context, HaLoServices services, {required List<EquipmentNode> keys, required String label, bool filled = false}) {
  final st = context.t.settings.station;
  final cat = services.cat;
  final keyerExperiment = services.settings.experimentEnabled('keyer') /* stored key, see experiments.yaml */;
  // The peer whose radio drives the VFO, when one does: its own key is
  // what keys for this operator unless they pick otherwise (HALO-585).
  final peer = cat.followedPeerRadio;
  return DesignationDropdown(
    key: ValueKey('${cat.designatedFor(kCategoryKey)}:${cat.peerKeyIsInUse}'),
    label: label,
    nodes: keys,
    filled: filled,
    // The peer's key is a default, so nothing is stored for it — and a
    // picker reading the stored value alone would say None while F1 keys
    // over the link.
    selected: peer != null && cat.peerKeyIsInUse && cat.peerOffersCwKeying ? peerRadioValue(peer) : cat.designatedFor(kCategoryKey),
    // A radio in this list is its keyer, not the radio.
    displayName: (node) => cat.typeFor(node)?.category == kCategoryTransceiver ? st.keyViaRadio(radio: cat.displayNameFor(node)) : cat.displayNameFor(node),
    noneLabel: st.noneSelected,
    // The peer whose radio drives the VFO keys for this operator unless
    // they say otherwise — offered here so saying otherwise can be undone.
    // Only while it OFFERS keying: a device that keys nothing is not a key.
    extras: [
      if (keyerExperiment && peer != null && cat.peerOffersCwKeying)
        (value: peerRadioValue(peer), label: st.keyOnDevice(device: peer.deviceName.isEmpty ? peer.deviceId : peer.deviceName)),
    ],
    onChanged: (uuid) => unawaited(cat.setDesignated(kCategoryKey, uuid)),
  );
}

/// The CW keyer's options: not built yet, so offered disabled.
Widget cwKeyingOptionsButton(BuildContext context) =>
    IconButton(icon: Icon(MdiIcons.tune, semanticLabel: context.t.settings.station.cwKeyingOptions), onPressed: null);

/// Where radio1's phone messages come from — none, its own memories where
/// it has some, or recordings on this computer where this device can play
/// them — and, beside it while the computer plays them, the button to its
/// sound devices and delays. A source that is not on offer here reads as
/// None, not as a choice the menu cannot show. A peer's radio plays what its
/// own station picked, so the pick is shown and not offered.
({Widget picker, List<Widget> controls}) phoneKeyingParts(BuildContext context, HaLoServices services, {bool filled = false}) {
  final st = context.t.settings.station;
  final cat = services.cat;
  final radio = cat.voiceKeyingNode;
  final local = cat.voiceMessagesAreLocal;
  final offersRadio = local && cat.radio1OffersVoiceMemories;
  final offersComputer = local && cat.computerVoiceAudio != null;
  final shown = switch (services.settings.voiceKeyingSource) {
    _ when !local => VoiceKeyingSource.radio,
    VoiceKeyingSource.radio when offersRadio => VoiceKeyingSource.radio,
    VoiceKeyingSource.computer when offersComputer => VoiceKeyingSource.computer,
    _ => VoiceKeyingSource.none,
  };
  final radioName = !local ? peerDeviceLabel(cat.followedPeerRadio) : (radio == null ? null : cat.displayNameFor(radio));
  final decoration = poloFieldDecoration(context, st.phoneKeying);
  return (
    picker: DropdownButtonFormField<VoiceKeyingSource>(
      key: ValueKey('phoneKeying:$shown:$local'),
      isExpanded: true,
      initialValue: shown,
      icon: dropdownTrailingIcon,
      decoration: filled ? decoration.copyWith(filled: true, fillColor: Theme.of(context).colorScheme.surface) : decoration,
      menuMaxHeight: dropdownMenuMaxHeight(context),
      items: [
        if (local) DropdownMenuItem(value: VoiceKeyingSource.none, child: Text(st.phoneKeyingNone)),
        if ((offersRadio || !local) && radioName != null)
          DropdownMenuItem(
            value: VoiceKeyingSource.radio,
            child: Text(st.phoneKeyingRadio(radio: radioName), overflow: TextOverflow.ellipsis),
          ),
        if (offersComputer) DropdownMenuItem(value: VoiceKeyingSource.computer, child: Text(st.phoneKeyingComputer)),
      ],
      onChanged: !local ? null : (source) => source == null ? null : unawaited(cat.selectVoiceKeyingSource(source)),
    ),
    controls: [
      if (shown == VoiceKeyingSource.computer)
        IconButton(
          icon: Icon(MdiIcons.tune, semanticLabel: st.computerVoiceSettings),
          onPressed: radio == null ? null : () => showComputerVoiceSettingsDialog(context, services),
        ),
    ],
  );
}
