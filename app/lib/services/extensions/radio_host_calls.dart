// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0

import 'package:halo_extension_host/halo_extension_host.dart';

import 'extension_info.dart';
import '../panel_radio_service.dart';

/// The radio host calls and the manifest capabilities that gate them:
/// `requiresRadioRead` for `listRadios`/`readRadio`, `requiresRadioWrite` for
/// `tuneRadio`/`setRadioConnection`/`setRadioSpectrum`. Without the gate any installed bundle
/// could retune the rig or drop the CAT link from any hook, with nothing in
/// its manifest saying so.
///
/// `params['extensionKey']` is the caller's identity only because the kernel
/// stamps it (kernel.ts `IDENTITY_HOST_METHODS`); a method missing from that
/// list arrives carrying whatever the extension chose to write there.
class RadioHostCalls {
  static const _reads = {'listRadios', 'readRadio'};
  static const _writes = {'tuneRadio', 'setRadioConnection', 'setRadioSpectrum'};

  static bool handles(String method) => _reads.contains(method) || _writes.contains(method);

  /// Null on a host with no CAT service behind it: reads answer empty and
  /// commands are refused as `disconnected`.
  PanelRadioService? radio;

  CapabilityGrant _read = const CapabilityGrant();
  CapabilityGrant _write = const CapabilityGrant();

  /// Resolved once per runtime start, like the location allowlist. A write
  /// key is in both sets: a command answers with the radio's state.
  void allow(Iterable<ExtensionInfo> loaded) {
    _read = CapabilityGrant.among(loaded, (info) => info.requiresRadioRead || info.requiresRadioWrite);
    _write = CapabilityGrant.among(loaded, (info) => info.requiresRadioWrite);
  }

  /// Whether [extensionKey] may read the radio — and so be shown its
  /// spectrum, which the host draws for it without the data crossing.
  bool canRead(String? extensionKey) => _read.allows(extensionKey);

  Future<dynamic> handle(String method, Map<String, dynamic> params) async {
    final write = _writes.contains(method);
    final extensionKey = params['extensionKey'] as String?;
    if (!(write ? _write : _read).allows(extensionKey)) {
      throw ExtensionHostException(
        "$method blocked: extension '${extensionKey ?? 'unknown'}' does not declare "
        "${write ? 'requiresRadioWrite' : 'requiresRadioRead'}",
      );
    }
    const unavailable = {'accepted': false, 'reason': 'disconnected', 'state': null};
    return switch (method) {
      'listRadios' => radio?.list() ?? [],
      'readRadio' => radio?.read(params['id'] as String?),
      'setRadioConnection' => radio?.setConnection(params) ?? unavailable,
      'setRadioSpectrum' => radio?.setSpectrum(params) ?? unavailable,
      _ => await radio?.tune(params) ?? unavailable,
    };
  }
}
