// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0

import 'package:halo_extension_host/halo_extension_host.dart';

import 'extension_info.dart';
import 'panel_radio_service.dart';

/// The radio host calls and the manifest capabilities that gate them:
/// `requiresRadioRead` for `listRadios`/`readRadio`, `requiresRadioWrite` for
/// `tuneRadio`/`setRadioConnection`. Without the gate any installed bundle
/// could retune the rig or drop the CAT link from any hook, with nothing in
/// its manifest saying so.
///
/// `params['extensionKey']` is the caller's identity only because the kernel
/// stamps it (kernel.ts `IDENTITY_HOST_METHODS`); a method missing from that
/// list arrives carrying whatever the extension chose to write there.
class RadioHostCalls {
  static const _reads = {'listRadios', 'readRadio'};
  static const _writes = {'tuneRadio', 'setRadioConnection'};

  static bool handles(String method) => _reads.contains(method) || _writes.contains(method);

  /// Null on a host with no CAT service behind it: reads answer empty and
  /// commands are refused as `disconnected`.
  PanelRadioService? radio;

  Set<String> _readAllowlist = const {};
  Set<String> _writeAllowlist = const {};

  /// Resolved once per runtime start, like the location allowlist. A write
  /// key is in both sets: a command answers with the radio's state.
  void allow(Iterable<ExtensionInfo> loaded) {
    _readAllowlist = {
      for (final info in loaded)
        if (info.requiresRadioRead || info.requiresRadioWrite) info.key,
    };
    _writeAllowlist = {
      for (final info in loaded)
        if (info.requiresRadioWrite) info.key,
    };
  }

  Future<dynamic> handle(String method, Map<String, dynamic> params) async {
    final write = _writes.contains(method);
    final extensionKey = params['extensionKey'] as String?;
    if (!capabilityAllows(write ? _writeAllowlist : _readAllowlist, extensionKey)) {
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
      _ => await radio?.tune(params) ?? unavailable,
    };
  }
}

/// Whether [extensionKey] — or its bundle, for a sub-extension like
/// `pota-all-parks` — is in a manifest-capability [allowlist]. The prefix rule
/// mirrors the one `ExtensionHost` applies to `domains`.
bool capabilityAllows(Set<String> allowlist, String? extensionKey) {
  if (extensionKey == null) return false;
  if (allowlist.contains(extensionKey)) return true;
  return allowlist.any((key) => extensionKey.startsWith('$key-') || extensionKey.startsWith('${key}_'));
}
