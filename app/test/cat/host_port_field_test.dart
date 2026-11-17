// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Which field a `host:port` pasted into a network pairing's Host lands its
// port in. The form splits the paste only toward the field the host element
// names, so the trap is naming the wrong one: a pairing that stores its port
// under its own key (`udpPort`) would have the paste fill a `port` the form
// never shows, and an Icom login would take the serial port for the control
// port the address actually names.

import 'package:flutter_test/flutter_test.dart';
import 'package:ham2k_logger/services/cat/transport.dart';
import 'package:ham2k_logger/services/cat/transports/icom_network_transport.dart';
import 'package:ham2k_logger/services/cat/transports/icom_network_transport_config.dart';
import 'package:ham2k_logger/services/cat/transports/tcp_transport.dart';
import 'package:ham2k_logger/services/cat/transports/udp_transport.dart';

Object? portFieldOf(EquipmentTransport transport, {Map<String, dynamic> overrides = const {}}) =>
    transport.configElements(overrides: overrides).firstWhere((element) => element['key'] == 'host')['portField'];

void main() {
  test('a host sends its port to the port field its own pairing shows', () {
    expect(portFieldOf(const TcpTransport()), 'port');
    expect(portFieldOf(const TcpTransport(portConfigKey: 'tcpPort')), 'tcpPort');
    expect(portFieldOf(const UdpTransport(portConfigKey: 'udpPort')), 'udpPort');
    expect(portFieldOf(const IcomNetworkTransport()), IcomNetworkTransportConfig.controlPortConfigKey);
  });

  test('an entry that fixes the port leaves the paste whole', () {
    // With no port field on screen, splitting would silently drop the port
    // the operator pasted.
    expect(portFieldOf(const TcpTransport(), overrides: {'port': 4992}), isNull);
    expect(portFieldOf(const IcomNetworkTransport(), overrides: {IcomNetworkTransportConfig.controlPortConfigKey: 50001}), isNull);
  });

  group('an Icom control port moved off the factory one', () {
    const icom = IcomNetworkTransport();
    const control = IcomNetworkTransportConfig.controlPortConfigKey;
    const serial = IcomNetworkTransportConfig.serialPortConfigKey;

    test('takes a factory serial port to the one after it', () {
      // A port forward carries the pair; a serial port left on 50002 logs in
      // on the control port and then never answers.
      expect(icom.fieldChanged(control, 60001, config: {control: 60001, serial: 50002}), {serial: 60002});
      // A node saved before the port fields existed is on the factory pair.
      expect(icom.fieldChanged(control, 60001, config: {control: 60001}), {serial: 60002});
    });

    test('leaves a serial port the operator set', () {
      expect(icom.fieldChanged(control, 60001, config: {control: 60001, serial: 61002}), isNull);
    });

    test('back on the factory port, or on no port, moves nothing', () {
      expect(icom.fieldChanged(control, 50001, config: {control: 50001, serial: 50002}), isNull);
      expect(icom.fieldChanged(control, null, config: {serial: 50002}), isNull);
      expect(icom.fieldChanged(control, 65535, config: {serial: 50002}), isNull, reason: 'no port after it');
    });
  });
}
