// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Which "this install is out of date" signal, if any, deserves the user's
// attention right now (docs/releases.md §4.6). Three signals answer that same
// question, and evaluated independently they can all fire on one launch —
// stacking two dialogs and a notice on someone trying to log a contact:
//
//   code-push floor   below a server-declared minimum   remedy: restart
//   expired build     past its expiration horizon       remedy: new binary
//   newer release     a newer binary exists             remedy: new binary
//
// Kept pure, UI-free and clock-injectable so the ranking can be tested without
// a widget tree, a network, or an updater — StalenessService gathers the facts
// and owns the presenting.

import 'package:halo_build_tools/halo_build_tools.dart' show isNewerRelease;

/// The staleness signals, **declared most severe first** — `Enum.index` IS the
/// ranking, so adding one in the middle re-ranks deliberately rather than by
/// accident.
///
/// The code-push floor outranks the two binary signals because its remedy is
/// the cheapest and the most certain: the fix is already on the device, or one
/// launch away. Telling someone to go download a binary when a restart would
/// do is worse advice, not more urgent advice.
enum StalenessSignal { codePushFloor, expiredBuild, newerRelease }

/// How hard a verdict presses. The tier is a property of the signal, not of
/// how long it has been ignored: nothing here escalates on its own.
enum StalenessTier {
  /// Status-bar notice — dismissible, easy to ignore, no interruption.
  notice,

  /// A dialog. Still always offers "Ignore for now": there is no hard gate on
  /// any platform, because a user mid-activation must always reach the log.
  nag,
}

extension StalenessSignalTier on StalenessSignal {
  StalenessTier get tier => switch (this) {
    StalenessSignal.codePushFloor => StalenessTier.nag,
    StalenessSignal.expiredBuild => StalenessTier.nag,
    // Stays a notice, as it ships today. A newer binary existing is not
    // worth interrupting a contact for.
    StalenessSignal.newerRelease => StalenessTier.notice,
  };
}

/// Whether this install sits below [floor] on the code-push plane.
///
/// [resolved] is the whole point of this signature: a code-push number that
/// could not be read is NOT the same fact as "no code push applied", and
/// collapsing the two (`currentPatchNumber() ?? 0`) nags an operator who is
/// already up to date, with no action available that would make it stop.
/// Unknown therefore returns false — silent — and the read costs nothing to
/// retry on the next launch.
///
/// [updaterAvailable] false means there is no code-push plane at all (web,
/// debug, a local `flutter build`), so a floor cannot apply.
bool isBelowCodePushFloor({required bool updaterAvailable, required bool resolved, required int? codePush, required int? floor}) {
  if (floor == null) return false; // declaring a floor is always an explicit act
  if (!updaterAvailable || !resolved) return false;
  return (codePush ?? 0) < floor;
}

/// Whether [latest] is worth telling the user about, given the newest version
/// they have already dismissed.
///
/// [dismissed] is the durable high-water mark: dismiss `26.9.0` and only
/// `26.9.1`+ ever notifies again. That persistence is deliberate and differs
/// from the other two signals — see [rankStaleness].
bool isReleaseWorthAnnouncing({required String currentVersion, required String? latest, required String? dismissed}) {
  if (latest == null || latest.isEmpty) return false;
  if (!isNewerRelease(current: currentVersion, available: latest)) return false;
  if (dismissed != null && !isNewerRelease(current: dismissed, available: latest)) return false;
  return true;
}

/// The single most severe signal currently true, or null when the install is
/// not stale in any way this knows about.
///
/// Deliberately returns ONE. Presenting the top signal and staying silent
/// about the rest is what stops two dialogs stacking on one launch — and the
/// suppressed ones are not lost, they surface once the more severe one is
/// resolved.
///
/// Dismissal is NOT considered here: this answers "what is wrong", and
/// StalenessService answers "should we say so again yet". Keeping them apart
/// is what lets the dismissal policies differ per signal — the newer-release
/// mark persists across launches while the other two return every launch —
/// without the ranking having to know about any of that.
StalenessSignal? rankStaleness({required bool belowCodePushFloor, required bool buildExpired, required bool releaseWorthAnnouncing}) {
  if (belowCodePushFloor) return StalenessSignal.codePushFloor;
  if (buildExpired) return StalenessSignal.expiredBuild;
  if (releaseWorthAnnouncing) return StalenessSignal.newerRelease;
  return null;
}

/// How long a dismissed verdict stays quiet within one session.
///
/// A launch-only nag never re-appears for the operator most likely to be on a
/// stale build: a field laptop left running for days. Six hours is long enough
/// not to hound someone through an activation, short enough that a multi-day
/// session sees it again.
const kStalenessQuietPeriod = Duration(hours: 6);

/// Whether a verdict dismissed at [dismissedAt] may be shown again as of
/// [now]. A never-dismissed signal ([dismissedAt] null) is always showable.
///
/// Wall-clock, deliberately: the requirement is "about six hours", and a
/// timestamp survives sleep and backgrounding, which no `Timer` does.
bool mayPresentAgain({required DateTime? dismissedAt, required DateTime now}) {
  if (dismissedAt == null) return true;
  return !now.isBefore(dismissedAt.add(kStalenessQuietPeriod));
}

/// The code-push floor declared for [build] by the flags channel, or null when
/// none is set.
///
/// Keyed by build because Shorebird's counter restarts at 1 for every release:
/// after a mid-month rebuild two live binaries carry independent counters, so a
/// bare push number names nothing on its own. Build numbers come from one
/// shared monotonic counter across editions, so Next and Regular keys cannot
/// collide.
///
/// Tolerant of what a hand-edited JSON file actually contains — a malformed
/// entry yields no floor rather than an exception, because failing open here
/// means "no nag" and failing closed would mean a broken flags file nagging
/// every install at once.
int? codePushFloorFor(Object? minCodePush, int build) {
  if (minCodePush is! Map) return null;
  final raw = minCodePush['$build'];
  if (raw is int) return raw;
  // isFinite first: toInt() THROWS on infinity and NaN, and this parses a
  // value a person typed into a JSON file on a server during an incident.
  if (raw is num) return raw.isFinite ? raw.toInt() : null;
  if (raw is String) return int.tryParse(raw);
  return null;
}
