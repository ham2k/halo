// Copyright ©️ 2026 Robert Jackson <me@rwjblue.com>
// SPDX-License-Identifier: MPL-2.0

import '../transport.dart';
import 'echocat_transport_config.dart';

class EchocatTransport extends EchocatTransportConfig {
  const EchocatTransport();

  @override
  bool get isSupportedOnThisPlatform => false;

  @override
  Future<EchocatCredentials> pair(String link) async => throw UnsupportedError('ECHOCAT pairing requires native TLS support');

  @override
  Future<EquipmentConnection> connect(Map<String, dynamic> target, {required CatCancelToken cancel}) async =>
      throw UnsupportedError('ECHOCAT pairing requires native TLS support');
}
