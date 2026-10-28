// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0

import 'dart:typed_data';

import '../error_reporting_service.dart';
import '../settings_service.dart';
import '../status_bar_service.dart';
import 'cat_service.dart';
import 'cat_traffic_log.dart';
import 'equipment_details.dart';

/// DEVLOGCAT: turns [CatTrafficLog] on and off from the call field, carries a
/// recording across a restart, and sends it off the device when it ends.
///
/// Plain English and no i18n, like every DEV command's outcome.
class CatTrafficRecording {
  final CatTrafficLog log;
  final SettingsService _settings;

  /// Read only when a recording is sent, so that holding this never builds
  /// a [CatService] by itself.
  final CatService Function() _cat;
  final StatusBarService _statusBar;

  CatTrafficRecording(this.log, {required this._settings, required this._cat, required this._statusBar});

  /// Starts recording, or stops and sends what was recorded.
  ///
  /// Not gated on developer mode: it is run by operators whose rig misbehaves
  /// in ways nobody here can reproduce, and it changes nothing that is sent.
  ///
  /// A recording outlives ONE restart, so a rig that only misbehaves after a
  /// relaunch is still caught; the launch after that sends it
  /// ([resume]), so a forgotten recording ends on its own.
  Future<({String text, bool failed})?> toggle() async {
    if (log.active) {
      final path = log.path!;
      try {
        final recorded = await log.stop();
        if (recorded == null) return null;
        await _settings.setCatTrafficLogCarry(null);
        return (text: _send(recorded.path, recorded.bytes), failed: false);
      } catch (e, st) {
        ErrorReportingService.report(e, st, context: 'devlogcat:stop');
        // Left for the next launch to send rather than forgotten.
        await _settings.setCatTrafficLogCarry(path);
        return (text: 'Could not read the radio traffic log to send it — it is at $path', failed: true);
      }
    }
    final String? path;
    try {
      path = await log.start();
    } catch (e, st) {
      ErrorReportingService.report(e, st, context: 'devlogcat:start');
      return (text: 'Could not start recording radio traffic: $e', failed: true);
    }
    if (path == null) return (text: 'DEVLOGCAT needs the desktop or Android app — the web build has nowhere to keep the log', failed: true);
    await _settings.setCatTrafficLogCarry(path, resume: true);
    return (text: 'Recording radio traffic to $path — run DEVLOGCAT again to stop and send it', failed: false);
  }

  /// At launch, before the designated radio reconnects: picks a DEVLOGCAT
  /// recording back up for its one restart, or sends one whose restart is
  /// spent. Never throws — a log must not stand between an operator and
  /// their radio.
  Future<void> resume() async {
    final carry = _settings.catTrafficLogCarry;
    if (carry == null) return;
    try {
      if (carry.resume) {
        final path = await log.start(resumePath: carry.path);
        await _settings.setCatTrafficLogCarry(path);
        if (path == null) return;
        _statusBar.showNotice(
          key: 'devlogcat',
          icon: 'record-rec',
          title: 'Recording radio traffic',
          text: 'DEVLOGCAT is still recording, to $path. Run DEVLOGCAT to stop and send it — otherwise it is sent at the next launch.',
          persist: false,
        );
        return;
      }
      final bytes = await log.collect(carry.path);
      await _settings.setCatTrafficLogCarry(null);
      if (bytes == null) return;
      // Sent on the app's initiative rather than at a command, and carrying
      // the radios' setup, so it asks the same consent the first-success
      // radio report does (docs/design/telemetry.md § Radios).
      final text = _settings.consentAppData ? _send(carry.path, bytes) : 'Not sent, because sharing app data is off. The recording is at ${carry.path}';
      _statusBar.showNotice(key: 'devlogcat', icon: 'record-rec', title: 'Radio traffic recording ended', text: text, persist: false);
    } catch (e, st) {
      ErrorReportingService.report(
        e,
        st,
        context: 'devlogcat:resume',
        notice: ErrorNotice(
          _statusBar,
          key: 'devlogcat',
          icon: 'record-rec',
          title: 'Radio traffic recording ended',
          text: 'Could not pick the DEVLOGCAT recording back up or send it — it is at ${carry.path}',
        ),
      );
      // Ended here, once: a file that cannot be opened or read now would
      // otherwise fail again at every launch after.
      try {
        await _settings.setCatTrafficLogCarry(null);
      } catch (e, st) {
        ErrorReportingService.report(e, st, context: 'devlogcat:resume-clear');
      }
    }
  }

  /// Uploads a finished recording with the setup of every radio it may have
  /// talked to, and says where the file is either way — the copy on disk is
  /// the fallback when the upload never lands.
  String _send(String path, Uint8List bytes) {
    final cat = _cat();
    final setups = [
      for (final node in cat.nodes)
        if (cat.registry.typeFor(node.typeKey) case final type?) ...[
          ...equipmentSetupLines(node: node, type: type, state: cat.stateFor(node.uuid), registry: cat.registry),
          '',
        ],
    ];
    final filename = path.split(RegExp(r'[\\/]')).last;
    final uploaded = ErrorReportingService.diagnostic(
      title: 'DEVLOGCAT',
      body: ['${bytes.length} bytes recorded in $filename', '', ...setups].join('\n'),
      attachment: (filename: filename, bytes: bytes),
    );
    return uploaded && ErrorReportingService.reportingEnabled
        // "Sending", not "sent": the backend uploads in the background and
        // cannot say whether it landed.
        ? 'Sending the radio traffic log. A copy is at $path'
        : 'Could not send the radio traffic log — it is at $path';
  }
}
