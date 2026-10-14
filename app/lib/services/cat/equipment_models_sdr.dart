// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// SDR receivers that show a radio's spectrum — docs/design/cat.md § SDR
// receivers. Behind `EXP FALL`: offered from the Add dialog's "Other
// Equipment" rows only while it is on, hence [EquipmentModel.hiddenFromCatalog].
//
// None of these has been on the bench.

import 'package:halo_i18n/halo_i18n.dart';

import 'drivers/rtl_tcp_driver.dart';
import 'drivers/sdr_spectrum.dart';
import 'equipment.dart';
import 'equipment_registry.dart';
import 'transports/tcp_transport.dart';

/// A new receiver follows whichever radio is Main, on its own antenna.
const _sdrDefaults = {'port': rtlTcpDefaultPort, sdrRadioConfigKey: sdrRadioMain, sdrTuningConfigKey: 'independent'};

/// SDRplay's RSPs reach the network through rsp_tcp, which speaks rtl_tcp's
/// protocol. Its rates are the RSP's own; the RTL2832U's direct sampling
/// means nothing to it.
const _rspTcpDriver = RtlTcpDriver(rates: [2000000, 4000000], directSampling: false);

const rtlSdrModel = EquipmentModel(
  key: 'rtl-sdr',
  category: kCategorySdr,
  name: _rtlSdrName,
  hiddenFromCatalog: true,
  variants: [EquipmentVariant(key: 'rtl-sdr-rtltcp', driver: RtlTcpDriver(), transport: TcpTransport(), defaultConfig: _sdrDefaults, notes: _rtlTcpNotes)],
);

String _rtlSdrName() => t.settings.station.models.rtlSdr;

/// An RTL-SDR under Nooelec's name: the same chip, the same server.
const nesdrModel = EquipmentModel(
  key: 'nesdr',
  category: kCategorySdr,
  name: _nesdrName,
  manufacturer: 'Nooelec',
  hiddenFromCatalog: true,
  variants: [EquipmentVariant(key: 'nesdr-rtltcp', driver: RtlTcpDriver(), transport: TcpTransport(), defaultConfig: _sdrDefaults, notes: _rtlTcpNotes)],
);

String _nesdrName() => t.settings.station.models.nesdr;

const sdrplayModel = EquipmentModel(
  key: 'sdrplay',
  category: kCategorySdr,
  name: _sdrplayName,
  manufacturer: 'SDRplay',
  hiddenFromCatalog: true,
  variants: [EquipmentVariant(key: 'sdrplay-rsptcp', driver: _rspTcpDriver, transport: TcpTransport(), defaultConfig: _sdrDefaults, notes: _rspTcpNotes)],
);

String _sdrplayName() => t.settings.station.models.sdrplay;

/// Every SDR model, in the order the Add dialog offers them.
const sdrModels = [rtlSdrModel, nesdrModel, sdrplayModel];

List<Map<String, dynamic>> _rtlTcpNotes() => [
  {'type': 'markdown', 'collapsible': true, 'title': t.settings.station.troubleshootingNotes, 'text': t.settings.station.rtlTcpNotes},
];

List<Map<String, dynamic>> _rspTcpNotes() => [
  {'type': 'markdown', 'collapsible': true, 'title': t.settings.station.troubleshootingNotes, 'text': t.settings.station.rspTcpNotes},
];
