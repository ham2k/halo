// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Sound devices, playback and recording, through miniaudio on the desktop.
// Everywhere else — the web, which has no dart:ffi, and the mobile builds,
// which do not carry the plugin — [HaloAudio.isSupported] is false and
// nothing else here may be called.

export 'src/devices.dart';
export 'src/audio_stub.dart' if (dart.library.ffi) 'src/audio_ffi.dart';
