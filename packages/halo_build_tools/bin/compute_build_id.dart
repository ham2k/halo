// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// CI entry point for docs/releases.md §2.2: given the target main version,
// the build date, and a same-day sequence number, prints the canonical build
// id and its per-platform projections as JSON.
//
// Usage:
//   dart run bin/compute_build_id.dart \
//     --version-year=26 --version-month=8 --patch=0 \
//     --build-month=7 --build-day=29 --sequence=1 \
//     [--pre-release=N] [--pre-release-patch=N]

import 'dart:convert';
import 'dart:io';

import 'package:halo_build_tools/halo_build_tools.dart';

void main(List<String> arguments) {
  final args = _parseArgs(arguments);

  int require(String key) {
    final raw = args[key];
    if (raw == null) {
      stderr.writeln('Missing required --$key');
      exit(64);
    }
    return int.parse(raw);
  }

  final publicVersion = PublicVersion(
    main: MainVersion(year: require('version-year'), month: require('version-month')),
    patch: require('patch'),
    preRelease: args['pre-release'] == null ? null : int.parse(args['pre-release']!),
    preReleasePatch: args['pre-release-patch'] == null
        ? null
        : int.parse(args['pre-release-patch']!),
  );

  final buildId = BuildId(
    versionYear: publicVersion.main.year,
    versionMonth: publicVersion.main.month,
    buildMonth: require('build-month'),
    buildDay: require('build-day'),
    sequence: require('sequence'),
  );

  final platforms = PlatformVersions.project(publicVersion: publicVersion, buildId: buildId);

  stdout.writeln(
    const JsonEncoder.withIndent('  ').convert({
      'publicVersion': publicVersion.value,
      'buildId': buildId.value,
      'android': {
        'versionCode': platforms.androidVersionCode,
        'versionName': platforms.androidVersionName,
      },
      'ios': {
        'buildNumber': platforms.iosBuildNumber,
        'marketingVersion': platforms.iosMarketingVersion,
      },
      'macos': {
        'buildNumber': platforms.iosBuildNumber,
        'marketingVersion': platforms.iosMarketingVersion,
      },
      'windows': {'fileVersion': platforms.windowsFileVersion},
      'linux': {'packageVersion': platforms.linuxPackageVersion},
    }),
  );
}

Map<String, String> _parseArgs(List<String> arguments) {
  final result = <String, String>{};
  for (final arg in arguments) {
    if (!arg.startsWith('--') || !arg.contains('=')) {
      stderr.writeln('Expected --key=value, got "$arg"');
      exit(64);
    }
    final withoutPrefix = arg.substring(2);
    final splitAt = withoutPrefix.indexOf('=');
    result[withoutPrefix.substring(0, splitAt)] = withoutPrefix.substring(splitAt + 1);
  }
  return result;
}
