// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Re-stamps THIS checkout's lib/config/version.dart with a fresh expiration
// for the given edition — `dart run tool/stamp_expiration.dart <edition>`,
// run from app/ by the CI patch scripts (app_dist/ci/patch-*.sh) just
// before `shorebird patch`. A patch ships "current as of today", so its
// expiration clock restarts at patch-build time; without this, an install
// kept current via patches would nag from the original release's date —
// possibly with nothing newer to download. Build-time only: the rewrite is
// deliberately NOT committed (the patch plane is a moving tag, not a
// ledger). Horizons live in halo_build_tools' expirationDateForBuild, the
// same function `halo-ops release` stamps with.

import 'dart:io';

import 'package:halo_build_tools/halo_build_tools.dart';

void main(List<String> args) {
  final edition = args.length == 1 ? editionFromName(args.single) : null;
  if (edition == null) {
    stderr.writeln('usage: dart run tool/stamp_expiration.dart <dev|next|prod>');
    exit(2);
  }
  final file = File('lib/config/version.dart');
  final date = expirationDateForBuild(edition, DateTime.now().toUtc());
  file.writeAsStringSync(rewriteExpirationDate(file.readAsStringSync(), edition, date));
  stdout.writeln('Stamped ${edition.name} expiration: $date');
}
