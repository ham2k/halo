// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The two catalogue entries that are not a radio but a PATH to one: a program
// the operator already runs, which owns the rig's port and answers for it.
// The app talks to the program and never to the radio, and knows nothing
// about which radio is behind it.
//
// Their own file because they are their own shelf in the Add dialog
// (`softwareIntermediaryModelKeys`, equipment_brands.dart), and because each
// carries a block of troubleshooting prose about a daemon rather than a rig.

import 'package:halo_i18n/halo_i18n.dart';

import 'drivers/flrig_driver.dart';
import 'drivers/rigctld_driver.dart';
import 'equipment.dart';
import 'equipment_registry.dart';
import 'transports/tcp_transport.dart';

const _flrigTcpKey = 'flrig-tcp';
const _rigctldTcpKey = 'rigctld-tcp';

/// Any radio Hamlib has a backend for, through a `rigctld` daemon the
/// operator already runs — the app connects to the daemon, never to the
/// radio. No discoverer: rigctld announces nothing, so it is always typed
/// in by address, defaulting to the same machine.
const rigctldModel = EquipmentModel(
  key: 'rigctld',
  category: kCategoryTransceiver,
  name: _rigctldName,
  suggestedName: _rigctldNodeName,
  variants: [
    EquipmentVariant(
      key: _rigctldTcpKey,
      driver: RigctldDriver(),
      transport: TcpTransport(),
      defaultConfig: {'host': '127.0.0.1', 'port': RigctldDriver.defaultPort},
      // The failure this pairing actually produces is a refused or
      // unanswered connection, and every cause lives outside the app: the
      // daemon isn't running, is listening only on localhost, or is on
      // another port.
      notes: _rigctldTcpNotes,
    ),
  ],
);

String _rigctldName() => t.settings.station.models.rigctld;
String _rigctldNodeName() => t.settings.station.models.rigctldNodeName;

List<Map<String, dynamic>> _rigctldTcpNotes() => [
      {
        'type': 'markdown',
        'collapsible': true,
        'title': t.settings.station.troubleshootingNotes,
        'text': '**${t.settings.station.rigctldTroubleshootingTitle}**\n\n'
            '${t.settings.station.rigctldTroubleshooting}',
      },
    ];

/// Any radio flrig has a definition for, through an flrig instance the
/// operator already runs — the app connects to flrig's XML-RPC server,
/// never to the radio. No discoverer: flrig announces nothing, so it is
/// always typed in by address, defaulting to the same machine.
const flrigModel = EquipmentModel(
  key: 'flrig',
  category: kCategoryTransceiver,
  name: _flrigName,
  suggestedName: _flrigNodeName,
  variants: [
    EquipmentVariant(
      key: _flrigTcpKey,
      driver: FlrigDriver(),
      transport: TcpTransport(),
      defaultConfig: {'host': '127.0.0.1', 'port': FlrigDriver.defaultPort},
      // The failure this pairing actually produces is a refused or
      // unanswered connection, and every cause lives outside the app: flrig
      // isn't running, its server is on another port, or it can't reach the
      // radio.
      notes: _flrigTcpNotes,
    ),
  ],
);

String _flrigName() => t.settings.station.models.flrig;
String _flrigNodeName() => t.settings.station.models.flrigNodeName;

List<Map<String, dynamic>> _flrigTcpNotes() => [
      {
        'type': 'markdown',
        'collapsible': true,
        'title': t.settings.station.troubleshootingNotes,
        'text': '**${t.settings.station.flrigTroubleshootingTitle}**\n\n'
            '${t.settings.station.flrigTroubleshooting}',
      },
    ];
