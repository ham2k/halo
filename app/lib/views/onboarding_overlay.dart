// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// First-run onboarding (Issue #43): the release overlay's look — full-bleed
// release photo, brand mark, credits — but the bottom band walks the
// app-polo onboarding steps (Welcome → Callsign → Activities → Data &
// Privacy) instead of showing release notes. Shown by `_OnboardingGate` in
// main.dart whenever the default profile has NEVER had a callsign set
// (undefined — an explicit '' from a previous Skip counts as set, see
// SettingsService.defaultProfileCallsignDefined). Both Skip and Done write
// the callsign (possibly '') so the overlay never re-triggers.

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:halo_widgets/halo_widgets.dart';

import '../config/release_notes.dart';
import '../i18n/strings.g.dart';
import '../main.dart';
import '../services/settings_service.dart';
import 'ham2k_logo.dart';
import 'release_overlay.dart' show overlayCreditsText, overlayCreditsStyle, overlayVersionLabelStyle;

// Matches release_overlay.dart's fixed light-panel palette — this overlay
// also sits over a photo and never follows dark mode.
const _photoFallbackColor = Color(0xFFBCE9FF);
const _bandColor = Colors.white;
// The Welcome step keeps the band small and translucent (the photo is the
// star); Continue animates to the taller, more opaque working state, same
// collapsed/expanded band language as the release overlay.
const _bandOpacityCollapsed = 0.35;
const _bandOpacityExpanded = 0.85;
const _bandHeightFactorCollapsed = 0.28;
const _bandHeightFactorExpanded = 0.55;
const _bandAnimationDuration = Duration(milliseconds: 250);

/// The expanded band never renders shorter than this — on windows too short
/// to give it (an iPad landscape with the virtual keyboard up), the band
/// grows toward — and if needed past — the photo and logo, which simply
/// slide under it: the controls win.
const _bandMinExpandedHeight = 360.0;

/// Below this available height the brand mark shrinks.
const _compactHeightThreshold = 540.0;

/// The collapsed (Welcome) band still needs room for its title, body, and
/// button row.
const _bandMinCollapsedHeight = 190.0;

enum _OnboardingStep { welcome, callsign, activities, consent }

class OnboardingOverlayView extends StatefulWidget {
  final HaLoServices services;

  /// The release entry providing the background photo — the same imagery
  /// the release overlay uses (null falls back to a plain color).
  final ReleaseNotesEntry? release;

  final VoidCallback onDone;

  const OnboardingOverlayView({super.key, required this.services, required this.release, required this.onDone});

  @override
  State<OnboardingOverlayView> createState() => _OnboardingOverlayViewState();
}

class _OnboardingOverlayViewState extends State<OnboardingOverlayView> {
  var _step = _OnboardingStep.welcome;

  /// Whether the last step change moved forward — steers the slide
  /// transition's direction (forward: new step enters from the right).
  var _movedForward = true;
  final _callsignController = TextEditingController();

  /// Navigation is ignored while a slide is in flight: reversing
  /// mid-transition would give AnimatedSwitcher an outgoing entry with the
  /// SAME key as the incoming one, and both would classify as incoming in
  /// the transition builder — two copies of the step sliding over each
  /// other.
  bool _navLocked = false;
  Timer? _navLockTimer;

  void _goTo(_OnboardingStep step) {
    if (_navLocked || step == _step) return;
    _navLocked = true;
    _navLockTimer = Timer(_bandAnimationDuration, () => _navLocked = false);
    setState(() {
      _movedForward = step.index > _step.index;
      _step = step;
    });
  }

  /// Enter anywhere acts like the step's primary button (Continue/Next/
  /// Done). A HardwareKeyboard handler — the same app-level hook main.dart
  /// uses for the zoom keys — rather than a focus-chain shortcut, because
  /// most steps have no focusable field and primary focus stays on the
  /// route scope beneath this modal overlay. Returning true also stops the
  /// event from reaching the callsign field's IME, so onSubmitted (kept for
  /// the mobile soft keyboard) can't double-fire.
  bool _handleKeyEvent(KeyEvent event) {
    if (event is! KeyDownEvent) return false;
    final key = event.logicalKey;
    if (key != LogicalKeyboardKey.enter && key != LogicalKeyboardKey.numpadEnter) return false;
    _primaryAction();
    return true;
  }

  void _primaryAction() {
    switch (_step) {
      case _OnboardingStep.welcome:
        _goTo(_OnboardingStep.callsign);
      case _OnboardingStep.callsign:
        _nextFromCallsign();
      case _OnboardingStep.activities:
        _goTo(_OnboardingStep.consent);
      case _OnboardingStep.consent:
        _finish();
    }
  }

  // app-polo's onboarding defaults: POTA pre-checked, the rest off;
  // usage-data consent pre-checked, operation-data off.
  bool _pota = true;
  bool _sota = false;
  bool _consentAppData = true;
  bool _consentOpData = false;

  @override
  void initState() {
    super.initState();
    // Drop whatever held focus beneath the overlay (a DEVONBOARD re-show
    // can arrive over a focused call field, whose own Enter shortcut would
    // fire alongside _handleKeyEvent) — matches first-run conditions, where
    // nothing is focused yet.
    FocusManager.instance.primaryFocus?.unfocus();
    HardwareKeyboard.instance.addHandler(_handleKeyEvent);
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_handleKeyEvent);
    _navLockTimer?.cancel();
    _callsignController.dispose();
    super.dispose();
  }

  /// Skip (from Welcome): mark the callsign as explicitly empty — but only
  /// when it was never answered, so a DEVONBOARD preview (or a Back after
  /// the callsign step already wrote a value) can't wipe a real callsign —
  /// and finish.
  Future<void> _skip() async {
    if (!widget.services.settings.defaultProfileCallsignDefined) {
      await widget.services.settings.setProfileOperatorCall(SettingsService.defaultProfileId, '');
    }
    widget.onDone();
  }

  Future<void> _nextFromCallsign() async {
    final value = _callsignController.text.trim().toUpperCase();
    // app-polo's easter egg: typing DEVMODE (or KONAMI) turns on developer
    // mode instead of advancing.
    if (value == 'DEVMODE' || value == 'KONAMI') {
      await widget.services.settings.setDeveloperMode(true);
      _callsignController.clear();
      return;
    }
    try {
      // Written even when empty — that's what marks onboarding as answered
      // (see defaultProfileCallsignDefined). Goes through HaLoServices so
      // sync credentials pick the callsign up too.
      await widget.services.setOperatorCall(value);
      // The moment onboarding counts as answered, the remaining steps'
      // current (default) choices are persisted too — abandoning the app
      // mid-flow must not leave them unwritten, since onboarding never
      // re-offers. Done overwrites them with the final toggles.
      await _persistChoices();
    } catch (e) {
      // The profile write happens first inside setOperatorCall; a keychain
      // or extension-bridge failure seeding sync credentials must not
      // strand the user on this step (credentials re-seed at next boot).
      debugPrint('[onboarding] persisting callsign step failed: $e');
    }
    _goTo(_OnboardingStep.activities);
  }

  Future<void> _persistChoices() async {
    final settings = widget.services.settings;
    // Nothing consumes the activity picks yet — stored in each extension's
    // own settings group (the same place host.setSettings writes) so the
    // extensions can honor them when activity toggling lands.
    await settings.updateSettingsGroup('extension_pota', {'enabled': _pota});
    await settings.updateSettingsGroup('extension_sota', {'enabled': _sota});
    await settings.updateSettingsGroup(SettingsService.privacyGroup, {
      'consentAppData': _consentAppData,
      'consentOpData': _consentOpData,
    });
  }

  Future<void> _finish() async {
    await _persistChoices();
    widget.onDone();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final versionLabelStyle = overlayVersionLabelStyle(theme);
    final creditsStyle = overlayCreditsStyle(theme);
    final release = widget.release;
    final caption = release?.photoCaption ?? '';
    final expanded = _step != _OnboardingStep.welcome;

    return Material(
      color: _photoFallbackColor,
      child: LayoutBuilder(
        builder: (context, constraints) {
          // The keyboard (iPad landscape being the worst case) eats into
          // the height the band may use; the band itself lifts above it.
          // viewInsets are window-relative, but in the wide modal this view
          // is a centered card whose bottom floats above the window's — the
          // gap between the two comes off the inset first.
          final windowHeight = MediaQuery.sizeOf(context).height;
          final cardBottomGap = math.max(0.0, (windowHeight - constraints.maxHeight) / 2);
          final keyboardInset = math.max(0.0, MediaQuery.viewInsetsOf(context).bottom - cardBottomGap);
          final available = math.max(0.0, constraints.maxHeight - keyboardInset);
          final compact = available < _compactHeightThreshold;

          // Expanded, the band takes its share of the available height but
          // never less than its minimum — on short windows that means
          // covering the photo and even the logo entirely: the step's
          // controls always win.
          final expandedHeight = math.min(available, math.max(available * _bandHeightFactorExpanded, _bandMinExpandedHeight));
          final collapsedHeight = math.min(available, math.max(available * _bandHeightFactorCollapsed, _bandMinCollapsedHeight));
          final bandHeight = expanded ? expandedHeight : collapsedHeight;
          final bandOpacity = expanded ? _bandOpacityExpanded : _bandOpacityCollapsed;

          // On Welcome, a tap anywhere moves to the first question — the
          // step's own buttons keep their handlers, which win over this
          // outer one (same barrier/card split as the release overlay).
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _step == _OnboardingStep.welcome ? () => _goTo(_OnboardingStep.callsign) : null,
            child: Stack(
            fit: StackFit.expand,
            children: [
              if (release != null)
                Positioned.fill(
                  child: Image.asset(
                    release.imageAssetPath,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => const ColoredBox(color: _photoFallbackColor),
                  ),
                ),
              SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 16),
                      Center(child: Ham2kBrandMark(logoWidth: compact ? 90 : 140, showShadow: true)),
                      const SizedBox(height: 8),
                      overlayCreditsText(context.t.startScreen.credits, creditsStyle),
                      if (release != null) ...[
                        const SizedBox(height: 4),
                        Text(release.name, textAlign: TextAlign.center, style: versionLabelStyle),
                      ],
                    ],
                  ),
                ),
              ),
              // Caption + band in one bottom column, same as the release
              // overlay: the caption fades away as the band expands over the
              // photo, and the whole column sits above the keyboard.
              Positioned(
                left: 0,
                right: 0,
                bottom: keyboardInset,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (caption.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
                        child: AnimatedOpacity(
                          duration: _bandAnimationDuration,
                          curve: Curves.easeInOut,
                          opacity: expanded ? 0 : 1,
                          child: Text(
                            caption,
                            textAlign: TextAlign.center,
                            style: creditsStyle.copyWith(fontFamily: 'RobotoMono', fontSize: creditsStyle.fontSize! * 0.85),
                          ),
                        ),
                      ),
                    AnimatedContainer(
                      duration: _bandAnimationDuration,
                      curve: Curves.easeInOut,
                      height: bandHeight,
                      color: _bandColor.withValues(alpha: bandOpacity),
                      // Material (not just the animated color) so the step's
                      // tiles and switches paint their ink on the band.
                      child: Material(
                        type: MaterialType.transparency,
                        child: SafeArea(
                          top: false,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                            // Steps slide horizontally: forward navigation
                            // enters from the right (and exits left), Back
                            // the mirror image. StackFit.expand keeps both
                            // children band-sized during the transition;
                            // ClipRect keeps the slide inside the band.
                            child: AnimatedSwitcher(
                              duration: _bandAnimationDuration,
                              switchInCurve: Curves.easeInOut,
                              switchOutCurve: Curves.easeInOut,
                              layoutBuilder: (currentChild, previousChildren) => ClipRect(
                                child: Stack(
                                  fit: StackFit.expand,
                                  children: [...previousChildren, if (currentChild != null) currentChild],
                                ),
                              ),
                              transitionBuilder: (child, animation) {
                                final incoming = child.key == ValueKey(_step);
                                final fromRight = incoming == _movedForward;
                                return SlideTransition(
                                  position: Tween(begin: Offset(fromRight ? 1 : -1, 0), end: Offset.zero).animate(animation),
                                  child: child,
                                );
                              },
                              child: KeyedSubtree(key: ValueKey(_step), child: _buildStep(theme)),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildStep(ThemeData theme) {
    final s = context.t.onboarding;
    final titleStyle = theme.textTheme.titleLarge?.copyWith(
      fontFamily: 'RobotoSlab',
      fontWeight: FontWeight.bold,
      color: Colors.black,
    );
    final bodyStyle = theme.textTheme.bodyMedium?.copyWith(
      fontSize: (theme.textTheme.bodyMedium?.fontSize ?? 14) * 1.2,
      color: Colors.black,
    );

    switch (_step) {
      case _OnboardingStep.welcome:
        return _stepScaffold(
          title: Text(isWindowedPlatform ? s.welcomeTitleDesktop : s.welcomeTitle, style: titleStyle),
          body: Text(s.welcomeBody, style: bodyStyle),
          secondaryLabel: s.skip,
          onSecondary: _skip,
          primaryLabel: s.kContinue,
          onPrimary: () => _goTo(_OnboardingStep.callsign),
        );
      case _OnboardingStep.callsign:
        return _stepScaffold(
          title: Text(s.callsignTitle, style: titleStyle),
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(s.callsignBody, style: bodyStyle),
              const SizedBox(height: 16),
              TextField(
                controller: _callsignController,
                autofocus: true,
                textCapitalization: TextCapitalization.characters,
                inputFormatters: const [UpperCaseTextFormatter()],
                style: const TextStyle(fontFamily: 'RobotoMono', color: Colors.black),
                decoration: InputDecoration(
                  labelText: s.callsignLabel,
                  hintText: 'N0CALL',
                  border: const OutlineInputBorder(),
                ),
                onSubmitted: (_) => _nextFromCallsign(),
              ),
            ],
          ),
          secondaryLabel: s.back,
          onSecondary: () => _goTo(_OnboardingStep.welcome),
          primaryLabel: s.next,
          onPrimary: _nextFromCallsign,
        );
      case _OnboardingStep.activities:
        return _stepScaffold(
          title: Text(s.activitiesTitle, style: titleStyle),
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(s.activitiesBody, style: bodyStyle),
              const SizedBox(height: 8),
              SwitchListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: Text(s.activityPota, style: bodyStyle?.copyWith(fontWeight: FontWeight.bold)),
                value: _pota,
                onChanged: (v) => setState(() => _pota = v),
              ),
              SwitchListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: Text(s.activitySota, style: bodyStyle?.copyWith(fontWeight: FontWeight.bold)),
                value: _sota,
                onChanged: (v) => setState(() => _sota = v),
              ),
              const SizedBox(height: 8),
              Text(s.activitiesFooter, style: bodyStyle?.copyWith(fontSize: (bodyStyle.fontSize ?? 16) * 0.8)),
            ],
          ),
          secondaryLabel: s.back,
          onSecondary: () => _goTo(_OnboardingStep.callsign),
          primaryLabel: s.kContinue,
          onPrimary: () => _goTo(_OnboardingStep.consent),
        );
      case _OnboardingStep.consent:
        return _stepScaffold(
          title: Text(s.consentTitle, style: titleStyle),
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(s.consentUsageBody, style: bodyStyle),
              SwitchListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: Text(s.consentUsageLabel, style: bodyStyle?.copyWith(fontWeight: FontWeight.bold)),
                value: _consentAppData,
                onChanged: (v) => setState(() => _consentAppData = v),
              ),
              const SizedBox(height: 8),
              Text(s.consentOperationBody, style: bodyStyle),
              SwitchListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: Text(s.consentOperationLabel, style: bodyStyle?.copyWith(fontWeight: FontWeight.bold)),
                value: _consentOpData,
                onChanged: (v) => setState(() => _consentOpData = v),
              ),
            ],
          ),
          secondaryLabel: s.back,
          onSecondary: () => _goTo(_OnboardingStep.activities),
          primaryLabel: s.done,
          onPrimary: _finish,
        );
    }
  }

  Widget _stepScaffold({
    required Widget title,
    required Widget body,
    required String secondaryLabel,
    required VoidCallback onSecondary,
    required String primaryLabel,
    required VoidCallback onPrimary,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        title,
        const SizedBox(height: 12),
        Expanded(child: SingleChildScrollView(child: body)),
        const SizedBox(height: 8),
        Row(
          children: [
            TextButton(onPressed: onSecondary, child: Text(secondaryLabel)),
            const Spacer(),
            FilledButton(onPressed: onPrimary, child: Text(primaryLabel)),
          ],
        ),
      ],
    );
  }
}
