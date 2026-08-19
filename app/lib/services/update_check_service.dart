// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Extension point for what the About panel's "Check for Updates" row
// actually checks (see update_check_row.dart). Shorebird and Sparkle/
// WinSparkle are distribution-specific mechanisms — app_dist supplies a real
// implementation that checks both (see runHaLoApp's own doc comment in
// main.dart for how distribution-only services get injected) — the OSS
// default here only knows about the one mechanism that needs no
// distribution-specific backend at all: comparing this build's baked-in git
// SHA against a deployed build_sha.txt (BuildFreshnessService), which only
// ever applies to a plain web deploy of this repo.
//
// Distinct from [UpdateService] (update_service.dart): that's Shorebird's own
// narrow check-and-apply-a-patch contract; this is the more general "what
// should the About panel's status row report right now" contract, which a
// real implementation may consult [UpdateService] (among other things) to
// answer.

import 'package:flutter/foundation.dart' show kIsWeb;

import '../config/version.dart' show kGitSha;
import 'build_freshness_service.dart';
import 'status_bar_service.dart';
import 'update_service.dart';

/// What the "Check for Updates" row should tell the user. Kept generic
/// (rather than exposing which specific mechanism fired) so any
/// implementation — OSS or distribution-specific — can report through the
/// same small set of outcomes, each already mapped to its own existing
/// updates.* i18n string in update_check_row.dart.
enum UpdateCheckOutcome { upToDate, updateAvailable, restartToApply, reloadToUpdate }

abstract class UpdateCheckService {
  /// Subclasses [extend] rather than implement, so they inherit
  /// [updateDestination]'s default instead of each restating "nowhere to go".
  const UpdateCheckService();

  /// Whether there's anything at all worth checking on this build/platform.
  /// [updates] is passed in (rather than held) since it's HaLoServices' own
  /// Shorebird-backed [UpdateService], constructed alongside everything else
  /// in bootstrap() — an implementation that doesn't care about Shorebird is
  /// free to ignore it.
  bool isApplicable({required UpdateService updates});

  Future<UpdateCheckOutcome> check({required UpdateService updates, required StatusBarService statusBar});

  /// Where to send the operator to act on the update the last [check]
  /// reported, or null when there is nowhere to send them — either because
  /// nothing is available, or because the mechanism handles the whole job
  /// itself. Sparkle and WinSparkle are the latter: they present their own
  /// download-and-install UI, so the row must NOT also offer a link.
  ///
  /// Only meaningful straight after a [check]; an implementation answers from
  /// what that call found rather than by looking again.
  Future<Uri?> updateDestination() async => null;
}

/// The OSS default: a plain web-deploy build-SHA freshness check. No-op
/// (never applicable) everywhere else, since Shorebird/Sparkle backends are
/// distribution-specific and not meaningful to check for in this repo alone.
class WebFreshnessUpdateCheckService extends UpdateCheckService {
  const WebFreshnessUpdateCheckService();

  @override
  bool isApplicable({required UpdateService updates}) => kIsWeb && kGitSha.isNotEmpty;

  @override
  Future<UpdateCheckOutcome> check({required UpdateService updates, required StatusBarService statusBar}) async {
    final result = await BuildFreshnessService(statusBar: statusBar).check();
    return result == BuildCheckResult.updateAvailable ? UpdateCheckOutcome.reloadToUpdate : UpdateCheckOutcome.upToDate;
  }
}
