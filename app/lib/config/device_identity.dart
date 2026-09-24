// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// What this device calls itself, for services that list a user's devices —
// the LoFi server's client records, and the "link <name>?" prompt another
// Ham2K app shows. Shaped like PoLo's so both apps' rows read alike there.
// Also the default peer device name, before the operator sets their own.

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';

/// [name] is the device's own user-facing name ("Michael's S23"), empty when
/// the platform has none. [description] is PoLo's `diagnostics.device` shape,
/// `manufacturer | model | name` ("samsung | kalama | Michael's S23"), with
/// whatever a platform can't answer left out.
typedef DeviceIdentity = ({String name, String description});

DeviceIdentity? _cached;

/// The [DeviceIdentity] once [deviceIdentity] has resolved it, for readers
/// that cannot wait — bootstrap resolves it before any of them run.
DeviceIdentity? get resolvedDeviceIdentity => _cached;

@visibleForTesting
set debugDeviceIdentity(DeviceIdentity? identity) => _cached = identity;

/// The [DeviceIdentity], resolved once per process. Never throws: a platform
/// that can't answer yields an empty identity, which callers replace with the
/// app's own name.
Future<DeviceIdentity> deviceIdentity() async {
  final cached = _cached;
  if (cached != null) return cached;
  final BaseDeviceInfo info;
  try {
    info = await DeviceInfoPlugin().deviceInfo;
  } catch (e) {
    debugPrint('[device-identity] unavailable: $e');
    return (name: '', description: '');
  }
  return _cached = identityFrom(info);
}

@visibleForTesting
DeviceIdentity identityFrom(BaseDeviceInfo info) {
  final (String name, List<String> parts) = switch (info) {
    // `board` is what PoLo's react-native-device-info reports as the device id.
    AndroidDeviceInfo i => (i.name, [i.manufacturer, i.board]),
    // Since iOS 16, without Apple's user-assigned-device-name entitlement,
    // `name` is just the model ("iPhone"), which names no one's device.
    IosDeviceInfo i => (i.name == i.model ? '' : i.name, ['Apple', i.utsname.machine]),
    MacOsDeviceInfo i => (i.computerName, ['Apple', i.model]),
    WindowsDeviceInfo i => (i.computerName, [i.productName]),
    LinuxDeviceInfo i => ('', [i.prettyName]),
    WebBrowserInfo i => ('', [i.browserName.name, i.platform ?? '']),
    _ => ('', <String>[]),
  };
  final trimmed = name.trim();
  return (name: trimmed, description: [...parts, trimmed].map((p) => p.trim()).where((p) => p.isNotEmpty).join(' | '));
}
