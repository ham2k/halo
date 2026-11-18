// Copyright ©️ 2026 Robert Jackson <me@rwjblue.com>
// SPDX-License-Identifier: MPL-2.0

import 'dart:convert';

import 'package:halo_i18n/halo_i18n.dart';

import '../transport.dart';
import 'config_field_helpers.dart';

const echocatTransportKey = 'echocat';
const echocatPairingKey = 'echocatPairing';
const echocatAddressKey = 'echocatAddress';

typedef EchocatEndpoint = ({Uri uri, String? fingerprint});

abstract class EchocatTransportConfig extends EquipmentTransport {
  const EchocatTransportConfig();

  @override
  String get key => echocatTransportKey;

  @override
  Set<String> get secretFields => const {echocatPairingKey};

  @override
  bool isUnconfigured(Map<String, dynamic> config) => blankInConfig(config, echocatAddressKey);

  @override
  String describeTarget(Map<String, dynamic> config) => stringFromConfig(config, echocatAddressKey);

  @override
  List<Map<String, dynamic>> configElements({Map<String, dynamic> overrides = const {}, Map<String, dynamic> restrictions = const {}}) => [
    if (!overrides.containsKey(echocatPairingKey))
      {
        'type': 'field',
        'fieldType': 'secret',
        'key': echocatPairingKey,
        'label': t.settings.station.echocatPairingLink,
        'description': t.settings.station.echocatPairingHelp,
      },
  ];

  @override
  Map<String, dynamic> targetFor(Map<String, dynamic> config) => {echocatPairingKey: stringFromConfig(config, echocatPairingKey)};

  Future<EchocatCredentials> pair(String link);
}

/// Parses the link copied from POTACAT's Pair my device dialog. A private
/// address is usable only with the certificate fingerprint in that link.
/// POTACAT builds the link and its certificate fields here.
/// https://github.com/Waffleslop/POTACAT/blob/a4529819facc4035016c941590d77ed2c9cd553c/main.js#L49767-L49783
({String token, List<EchocatEndpoint> endpoints})? parseEchocatPairingLink(String input) {
  final link = Uri.tryParse(input.trim());
  if (link == null || link.scheme != 'potacat' || link.host != 'pair' || link.path.isNotEmpty) return null;
  final Map<String, String> params;
  try {
    params = link.queryParameters;
  } on FormatException {
    return null;
  }
  final token = params['token'];
  if (token == null || token.isEmpty || token.length > 512) return null;

  final pin = _fingerprint(params['fp']);
  final lan = _endpointUri(params['host']);
  final tailscale = params['tsHost'];
  final ts = tailscale == null ? null : _endpointUri(tailscale.startsWith('wss://') ? tailscale : 'wss://$tailscale');
  final publicTailscale = params['tsCertPublic'] == '1';
  final endpoints = <EchocatEndpoint>{
    if (lan != null && (pin != null || (publicTailscale && _isTailscale(lan))))
      (uri: lan.hasPort ? lan : lan.replace(port: 443), fingerprint: publicTailscale && _isTailscale(lan) ? null : pin),
    if (ts != null && _isTailscale(ts) && (publicTailscale || pin != null))
      (uri: ts.hasPort ? ts : ts.replace(port: lan?.hasPort == true ? lan!.port : 7300), fingerprint: publicTailscale ? null : pin),
  }.toList();
  return endpoints.isEmpty ? null : (token: token, endpoints: endpoints);
}

Uri? _endpointUri(String? value) {
  if (value == null) return null;
  final uri = Uri.tryParse(value);
  if (uri == null ||
      uri.scheme != 'wss' ||
      uri.host.isEmpty ||
      uri.userInfo.isNotEmpty ||
      (uri.path.isNotEmpty && uri.path != '/') ||
      uri.hasQuery ||
      uri.hasFragment ||
      (uri.hasPort && (uri.port < 1 || uri.port > 65535))) {
    return null;
  }
  return uri.replace(path: '/');
}

bool _isTailscale(Uri uri) => uri.host.toLowerCase().endsWith('.ts.net');

String? _fingerprint(Object? value) {
  final pin = (value is String ? value : '').replaceAll(':', '').toLowerCase();
  return RegExp(r'^[a-f0-9]{64}$').hasMatch(pin) ? pin : null;
}

/// The durable device token and its allowed destinations are written
/// together to one keychain entry. The one-time link is never saved.
class EchocatCredentials {
  final String token;
  final List<EchocatEndpoint> endpoints;

  const EchocatCredentials(this.token, this.endpoints);

  String get address => endpoints.first.uri.authority;

  String encode() => jsonEncode({
    'token': token,
    'endpoints': [
      for (final endpoint in endpoints) {'url': endpoint.uri.toString(), 'fingerprint': endpoint.fingerprint},
    ],
  });

  static EchocatCredentials? decode(String input) {
    try {
      if (jsonDecode(input) case {'token': final String token, 'endpoints': final List<dynamic> endpoints} when token.isNotEmpty) {
        final decoded = <EchocatEndpoint>[];
        for (final endpoint in endpoints) {
          if (endpoint case {'url': final String url, 'fingerprint': final Object? fingerprint}) {
            final uri = _endpointUri(url);
            final pin = _fingerprint(fingerprint);
            if (uri != null && uri.hasPort && (pin != null || (fingerprint == null && _isTailscale(uri)))) {
              decoded.add((uri: uri, fingerprint: pin));
            }
          }
        }
        if (decoded.isNotEmpty) return EchocatCredentials(token, decoded);
      }
    } on FormatException {
      return null;
    }
    return null;
  }
}

class EchocatFailure implements CatUnreachable {
  final String message;
  const EchocatFailure(this.message);

  @override
  String toString() => message;
}
