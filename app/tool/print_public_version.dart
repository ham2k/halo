// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Prints the app's public version string (kPublicVersion, e.g. `26.7.0-pre1`)
// to stdout — the single source of truth in lib/config/version.dart (§2.3), for
// CI to name release artifacts. Pure Dart (version.dart only imports
// halo_build_tools), so it runs under `dart run` without the Flutter toolchain.
// ignore_for_file: avoid_print — a build script; stdout is the interface.
import 'package:ham2k_logger/config/version.dart';

void main() => print(kPublicVersion);
