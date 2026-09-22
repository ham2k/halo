// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The single source of truth for downloadable-artifact naming (docs/releases.md
// §2.2), emitting the two base strings each platform's CI builds on:
//
//   HALO_COMPACT_BASE=halo-next-26.8.1-alpha1-(73)          <- artifacts archive + machine files
//   HALO_FULL_BASE=Ham2K Logger (Next) 26.8.1-alpha1 (73)   <- human-facing files inside it
//
// CI appends the platform/descriptor/extension: compact + "-windows.zip", or
// full + " Installer.exe" / ".dmg" / " macOS.zip". The naming logic lives in
// halo_build_tools (artifact_name.dart) so it is unit tested; this is a thin CLI
// wrapper. Edition comes from the first CLI arg (dev|next|prod) so CI can pass
// the one it is building; it falls back to kEdition for a local run. Pure Dart —
// runs under `dart run` without Flutter.
// ignore_for_file: avoid_print — a build script; stdout is the interface.

import 'package:halo_build_tools/halo_build_tools.dart';
import 'package:ham2k_logger/config/version.dart';

void main(List<String> args) {
  final editionArg = args.isNotEmpty ? args.first : kEdition.name;
  final edition = Edition.values.firstWhere((e) => e.name == editionArg, orElse: () => Edition.dev);

  print('HALO_COMPACT_BASE=${compactName(edition: edition, version: kPublicVersionInfo, build: kBuildNumber)}');
  print('HALO_FULL_BASE=${fullName(edition: edition, version: kPublicVersionInfo, build: kBuildNumber)}');
}
