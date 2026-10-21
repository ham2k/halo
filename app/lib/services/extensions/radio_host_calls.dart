// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0

import 'package:halo_extension_host/halo_extension_host.dart';

import 'extension_info.dart';
import '../panel_radio_service.dart';

/// The radio host calls and the manifest capabilities that gate them:
/// `requiresRadioRead` for `listRadios`/`readRadio`, `requiresRadioWrite` for
/// everything that commands one — settings, connection, scope, and keying
/// (CW, voice memories, PTT) — and `requiresRadioRaw` for `sendRadioRaw`, any
/// command in the radio's own protocol, which implies both. Without the gate
/// any installed bundle could retune the rig, drop the CAT link or key the
/// transmitter from any hook, with nothing in its manifest saying so.
///
/// `tuneRadio` is `setRadio`'s name through extension API 6, still answered
/// for bundles built against it.
///
/// `params['extensionKey']` is the caller's identity only because the kernel
/// stamps it (kernel.ts `IDENTITY_HOST_METHODS`); a method missing from that
/// list arrives carrying whatever the extension chose to write there.
class RadioHostCalls {
  static const _reads = {'listRadios', 'readRadio'};
  static const _writes = {
    'setRadio',
    'tuneRadio',
    'setRadioConnection',
    'setRadioSpectrum',
    'sendRadioCw',
    'playRadioVoice',
    'setRadioPtt',
    'stopRadioTransmit',
  };

  static const _raw = 'sendRadioRaw';

  static bool handles(String method) => _reads.contains(method) || _writes.contains(method) || method == _raw;

  /// Null on a host with no CAT service behind it: reads answer empty and
  /// commands are refused as `disconnected`.
  PanelRadioService? radio;

  CapabilityGrant _read = const CapabilityGrant();
  CapabilityGrant _write = const CapabilityGrant();
  CapabilityGrant _rawGrant = const CapabilityGrant();

  /// Resolved once per runtime start, like the location allowlist. A write
  /// key is in both sets: a command answers with the radio's state. A raw
  /// key is in all three: anything `setRadio` does, a raw command can.
  void allow(Iterable<ExtensionInfo> loaded) {
    bool raw(ExtensionInfo info) => info.requiresRadioRaw;
    bool write(ExtensionInfo info) => raw(info) || info.requiresRadioWrite;
    _read = CapabilityGrant.among(loaded, (info) => write(info) || info.requiresRadioRead);
    _write = CapabilityGrant.among(loaded, write);
    _rawGrant = CapabilityGrant.among(loaded, raw);
  }

  /// Whether [extensionKey] may read the radio — and so be shown its
  /// spectrum, which the host draws for it without the data crossing.
  bool canRead(String? extensionKey) => _read.allows(extensionKey);

  /// Whether [extensionKey] may command the radio — and so have a scene's
  /// spectrum move the radio's scope to follow the VFO.
  bool canWrite(String? extensionKey) => _write.allows(extensionKey);

  Future<dynamic> handle(String method, Map<String, dynamic> params) async {
    final extensionKey = params['extensionKey'] as String?;
    final (grant, name) = method == _raw
        ? (_rawGrant, 'requiresRadioRaw')
        : _writes.contains(method)
        ? (_write, 'requiresRadioWrite')
        : (_read, 'requiresRadioRead');
    if (!grant.allows(extensionKey)) {
      throw ExtensionHostException("$method blocked: extension '${extensionKey ?? 'unknown'}' does not declare $name");
    }
    const unavailable = {'accepted': false, 'reason': 'disconnected', 'state': null};
    return switch (method) {
      'listRadios' => radio?.list() ?? [],
      'readRadio' => radio?.read(params['id'] as String?),
      'setRadioConnection' => radio?.setConnection(params) ?? unavailable,
      'setRadioSpectrum' => radio?.setSpectrum(params) ?? unavailable,
      'sendRadioCw' => radio?.sendCw(params) ?? unavailable,
      'playRadioVoice' => radio?.playVoice(params) ?? unavailable,
      'setRadioPtt' => radio?.setPtt(params) ?? unavailable,
      'stopRadioTransmit' => radio?.stopTransmit(params) ?? unavailable,
      _raw => await radio?.sendRaw(params) ?? unavailable,
      _ => await radio?.set(params) ?? unavailable,
    };
  }
}
