// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The release notes overlay, shown once per new release over the app.
// DEVSPLASH forces it.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:halo_widgets/halo_widgets.dart';

import '../release_overlay.dart';
import '../../config/release_notes.dart';
import '../../config/version.dart';

import '../../services/halo_services.dart';

/// Shows `ReleaseOverlayView` once per new `kPublicVersion`, on top of the
/// whole app (same one-integration-point wrapping as `StatusBarOverlay`
/// below, which it wraps). Gated on `SettingsService.lastSeenReleaseVersion`
/// (release_notes.dart, settings_service.dart) — dismissing it persists
/// `kPublicVersion` there, so it won't show again until the next release.
class ReleaseOverlayGate extends StatefulWidget {
  final HaLoServices services;
  final Widget child;

  const ReleaseOverlayGate({super.key, required this.services, required this.child});

  @override
  State<ReleaseOverlayGate> createState() => _ReleaseOverlayGateState();
}

class _ReleaseOverlayGateState extends State<ReleaseOverlayGate> {
  ReleaseNotesEntry? _pending;

  @override
  void initState() {
    super.initState();
    _checkForNewRelease();
    widget.services.devSplashTrigger.addListener(_showDevSplash);
  }

  @override
  void dispose() {
    widget.services.devSplashTrigger.removeListener(_showDevSplash);
    super.dispose();
  }

  Future<void> _checkForNewRelease() async {
    // First run: onboarding is showing (see OnboardingGate) and marks this
    // version seen on dismissal — don't stack "what's new" behind it.
    if (!widget.services.settings.defaultProfileCallsignDefined) return;
    if (widget.services.settings.lastSeenReleaseVersion == kPublicVersion) return;
    final notes = await loadReleaseNotes();
    ReleaseNotesEntry? current;
    for (final entry in notes) {
      if (entry.version == kPublicVersion) {
        current = entry;
        break;
      }
    }
    if (current == null || !mounted) return;
    setState(() => _pending = current);
  }

  /// DEVSPLASH (dev-commands extension) — always shows the newest release's
  /// notes, ignoring `lastSeenReleaseVersion` entirely (unlike
  /// `_checkForNewRelease`), since the whole point is re-previewing it on
  /// demand.
  Future<void> _showDevSplash() async {
    final notes = await loadReleaseNotes();
    if (notes.isEmpty || !mounted) return;
    // The newest entry whatever the running version — and the overlay's header
    // names the RUNNING build (version_label.dart), not this entry, so on a
    // build that has moved past the newest notes the preview shows this
    // version over that release's changes.
    setState(() => _pending = notes.first);
  }

  void _dismiss() {
    widget.services.settings.setLastSeenReleaseVersion(kPublicVersion);
    setState(() => _pending = null);
  }

  @override
  Widget build(BuildContext context) {
    final pending = _pending;
    return Stack(children: [widget.child, if (pending != null) _buildOverlay(context, pending)]);
  }

  /// Same shirt-size logic as halo_widgets' Modal Panes
  /// (packages/halo_widgets/lib/src/modal_pane.dart): full screen on
  /// XS/S, a centered pane-sized modal over the home screen on L/XL. This
  /// overlay isn't a pushed route and keeps its own full-bleed photo
  /// design rather than `ModalPaneRoute`'s AppBar/dialog-card chrome, so
  /// the presentation split is reimplemented here instead of reusing
  /// `showModalPane` directly. The wide-mode chrome itself is shared with
  /// the About screen's photo modal — see `wideModalChrome`.
  Widget _buildOverlay(BuildContext context, ReleaseNotesEntry release) {
    if (!ShirtSize.of(context).isTwoPane) {
      return ReleaseOverlayView(release: release, onDismiss: _dismiss);
    }
    return Positioned.fill(
      child: wideModalChrome(
        context: context,
        onDismiss: _dismiss,
        child: ReleaseOverlayView(release: release, onDismiss: _dismiss),
      ),
    );
  }
}
