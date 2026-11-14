// Copyright ©️ 2026 Robert Jackson <me@rwjblue.com>
// SPDX-License-Identifier: MPL-2.0

import 'package:halo_i18n/halo_i18n.dart';

import 'k4_receiver_codec.dart';

const k4ReceiverConfigKey = 'receiver';
const k4ReceiverValues = ['main', 'sub'];

String k4ReceiverLabel(Object? value) => parseK4Receiver(value) == K4Receiver.sub ? t.settings.station.k4ReceiverSub : t.settings.station.k4ReceiverMain;

String? describeK4Receiver(Map<String, dynamic> config, Map<String, dynamic> overrides, {bool suffix = false}) =>
    overrides.containsKey(k4ReceiverConfigKey) ? null : '${suffix ? ' · ' : ''}${k4ReceiverLabel(config[k4ReceiverConfigKey])}';
