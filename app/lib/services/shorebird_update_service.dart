// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The Shorebird code-push implementation of [UpdateService] (docs/releases.md
// §4). On launch it checks the user-selected track (§4.3) and downloads any
// available Dart patch, which the Shorebird engine applies on the next restart.
//
// This is safe as the DEFAULT update service for every build: `shorebird release`
// builds carry the engine and patch; everything else — local `flutter build`,
// debug, tests, web — reports `isAvailable == false`, so every method no-ops
// exactly like [NoopUpdateService]. The `shorebird_code_push` import therefore
// stays confined to this file; the rest of the app sees only [UpdateService].
//
// We drive updates ourselves (shorebird.yaml is generated with
// `auto_update: false`) so the built-in updater — which only ever checks the
// `stable` track — can't fight a device that has opted into another track.

import 'package:flutter/foundation.dart';
import 'package:shorebird_code_push/shorebird_code_push.dart';

import 'settings_service.dart';
import 'update_service.dart';

class ShorebirdUpdateService implements UpdateService {
  ShorebirdUpdateService(this._settings, {ShorebirdUpdater? updater}) : _updater = updater ?? ShorebirdUpdater();

  final SettingsService _settings;
  final ShorebirdUpdater _updater;

  @override
  bool get isAvailable => _updater.isAvailable;

  /// The track the user has opted into (§4.3), as a Shorebird [UpdateTrack].
  /// `UpdateTrack` is a String extension type, so our custom track names
  /// ("bleeding-edge", "unstable") map through unchanged.
  UpdateTrack get _track => UpdateTrack(_settings.shorebirdTrack);

  @override
  Future<({bool resolved, int? number})> currentPatchNumber() async {
    // No engine: no code push exists, which is an answer.
    if (!_updater.isAvailable) return (resolved: true, number: null);
    try {
      return (resolved: true, number: (await _updater.readCurrentPatch())?.number);
    } on ReadPatchException catch (e) {
      // NOT null-as-none: this is the read failing, and reporting it as "no
      // push applied" would nag an install that is already current.
      debugPrint('[shorebird] readCurrentPatch failed: $e');
      return (resolved: false, number: null);
    }
  }

  @override
  Future<bool> checkAndApply() async {
    if (!_updater.isAvailable) return false;
    final track = _track;
    try {
      final status = await _updater.checkForUpdate(track: track);
      if (status != UpdateStatus.outdated) return false;
      await _updater.update(track: track);
      debugPrint('[shorebird] patch downloaded on "${track.name}" — restart to apply');
      return true;
    } on UpdateException catch (e) {
      // A failed check/download must never break app startup — just log it.
      debugPrint('[shorebird] update on "${track.name}" failed: ${e.message} (${e.reason.name})');
      return false;
    }
  }
}
