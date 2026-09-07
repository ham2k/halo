// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The tester notes overlay, shown once per new Dev/Next build over the app.
// DEVTESTER forces it.

import 'dart:async';

import 'package:flutter/material.dart';

import '../tester_overlay.dart';
import '../../config/dev_flags.dart';
import '../../config/release_notes.dart';
import '../../config/tester_notes.dart';
import '../../config/version.dart';

import '../../services/halo_services.dart';

/// Shows `TesterOverlayView` on the Dev and Next editions whenever
/// `kBuildNumber` has advanced past `SettingsService.lastSeenTesterBuild`
/// and the build carries no explicit `DEV_LABEL`, listing every tester-notes
/// entry in between (tester_notes.dart, tester_overlay.dart). Outermost of
/// the startup gates — it paints above the onboarding flow too, so even a
/// fresh install leads with the caution warning. Dismissing persists
/// `kBuildNumber`, so it won't show again until the next build with notes.
///
/// Because AGENTS.md has every `flutter run` pass a `DEV_LABEL`, the organic
/// path below is unreachable in normal development, and DEVTESTER exercises
/// only `_showDevTester` (no `lastSeen` filtering, no stamping). Checking a
/// change to the pending-entry filter or to stamp-on-dismiss means running
/// once WITHOUT the label; nothing else reaches that code before a tester's
/// real build does.
class TesterOverlayGate extends StatefulWidget {
  final HaLoServices services;
  final Widget child;

  const TesterOverlayGate({super.key, required this.services, required this.child});

  @override
  State<TesterOverlayGate> createState() => _TesterOverlayGateState();
}

class _TesterOverlayGateState extends State<TesterOverlayGate> {
  List<TesterNotesEntry>? _pending;
  ReleaseNotesEntry? _release;

  /// Whether the current showing is the organic once-per-build one — only
  /// that one stamps `lastSeenTesterBuild` on dismissal. A DEVTESTER
  /// preview must not consume the real overlay (DEVONBOARD's `_firstRun`
  /// rationale).
  bool _organicShowing = false;

  @override
  void initState() {
    super.initState();
    _checkForNewBuild();
    widget.services.devTesterTrigger.addListener(_showDevTester);
  }

  @override
  void dispose() {
    widget.services.devTesterTrigger.removeListener(_showDevTester);
    super.dispose();
  }

  Future<void> _checkForNewBuild() async {
    // Testers-only: prod users get the release overlay, never this one.
    if (kEdition == Edition.prod) return;
    // A build carrying a DEV_LABEL is somebody's working copy, not a tester's:
    // the overlay would cover the app on every cold start of the thing they
    // are working on, and dismissing it would burn the once-per-build showing
    // a real tester should get. Only the explicit label counts — a web
    // preview derives its own from the URL, and those ARE handed to testers.
    // DEVTESTER still previews the overlay on demand.
    if (debugEnvFlag(const String.fromEnvironment('DEV_LABEL'), 'DEV_LABEL').isNotEmpty) return;
    final lastSeen = widget.services.settings.lastSeenTesterBuild;
    if (lastSeen >= kBuildNumber) return;
    final notes = await loadTesterNotes();
    // The release cut numbers an entry and bumps kBuildNumber in one commit,
    // so an entry above this build means someone hand-typed a number the
    // tooling would never write — this build still shouldn't promise it.
    final pending = notes.where((entry) => entry.build > lastSeen && entry.build <= kBuildNumber).toList();
    if (pending.isEmpty || !mounted) return;
    // Shown before the backdrop resolves — onboarding mounts synchronously
    // beneath this gate, and every await here extends the window where a
    // fresh install sees it flash before the tester overlay covers it. The
    // photo crossfades in when it arrives, same as everywhere else.
    _organicShowing = true;
    setState(() => _pending = pending);
    final release = await _loadBackdrop();
    if (release != null && mounted && _pending != null) setState(() => _release = release);
  }

  /// DEVTESTER (dev-commands extension) — shows every entry up to the
  /// current build, ignoring the edition and `lastSeenTesterBuild` gates
  /// entirely, for re-previewing the overlay on demand (DEVSPLASH's
  /// sibling). Falls back to the whole file when nothing is ≤ the current
  /// build — the command has already confirmed in the UI, so it must never
  /// no-op. Notes accumulated since the last cut are NOT previewable here:
  /// they live under tester-notes.yaml's `upcoming` key, which the parser
  /// drops until a release names it.
  Future<void> _showDevTester() async {
    // Same edition guard as the organic path — a prod build has no
    // business rendering tester-only content, dev command or not.
    if (kEdition == Edition.prod) return;
    final notes = await loadTesterNotes();
    var pending = notes.where((entry) => entry.build <= kBuildNumber).toList();
    if (pending.isEmpty) pending = notes;
    if (pending.isEmpty || !mounted) return;
    // A preview must never stamp — even one that lands while the organic
    // showing is on screen and replaces its content.
    _organicShowing = false;
    setState(() => _pending = pending);
    final release = await _loadBackdrop();
    if (release != null && mounted && _pending != null) setState(() => _release = release);
  }

  /// The newest release's entry, for the overlay's backdrop photo — or null.
  /// Tolerant the same way onboarding is: a broken/missing release-notes
  /// asset just means no photo (the view falls back to a flat color), not a
  /// broken overlay.
  Future<ReleaseNotesEntry?> _loadBackdrop() async {
    try {
      final notes = await loadReleaseNotes();
      return notes.isNotEmpty ? notes.first : null;
    } catch (error, stackTrace) {
      debugPrint('[tester-overlay] release notes unavailable: $error\n$stackTrace');
      return null;
    }
  }

  void _dismiss() {
    if (_organicShowing) widget.services.settings.setLastSeenTesterBuild(kBuildNumber);
    _organicShowing = false;
    setState(() => _pending = null);
  }

  @override
  Widget build(BuildContext context) {
    final pending = _pending;
    return Stack(
      children: [
        widget.child,
        if (pending != null) _buildOverlay(context, pending),
      ],
    );
  }

  /// Always full screen, even on wide layouts — the same presentation choice
  /// as `OnboardingGate` (not `ReleaseOverlayGate`'s centered modal): the
  /// two overlays can show back-to-back on a fresh install, and switching
  /// chrome between them would read as a glitch.
  Widget _buildOverlay(BuildContext context, List<TesterNotesEntry> entries) {
    return Positioned.fill(
      child: TesterOverlayView(entries: entries, release: _release, onDismiss: _dismiss),
    );
  }
}
