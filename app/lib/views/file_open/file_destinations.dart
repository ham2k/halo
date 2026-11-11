// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The places a file can go whatever is on screen, and the start of file
// routing: files the OS opens and command-line arguments into the router.

import 'dart:async';
import 'dart:io' show File;

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:halo_i18n/halo_i18n.dart';

import '../../config/navigation.dart' show navigatorKey;
import '../../services/error_reporting_service.dart';
import '../../services/halo_services.dart';
import '../../services/sets/cw_message_set_category.dart';
import '../../services/sets/voice_message_set_category.dart';
import '../app_shell/home_rail_state.dart';
import '../extension_install_flow.dart';
import '../qson_import_flow.dart';
import '../sets/set_manager_pane.dart' show importSetFile;
import '../settings/keyboard_shortcuts_panel.dart' show keyboardShortcutSets;
import 'file_kind.dart';
import 'file_router.dart';

/// The Logs view's ADIF import — offered by the view itself while it shows,
/// and by [_logsAdif] from anywhere else.
const logsAdifDestinationId = 'adif:logs';

const extensionInstallDestinationId = 'extension:install';

/// A QSON file as a new operation — as PoLo or this app's Developer Mode
/// exports one.
FileDestination qsonFileDestination(HaLoServices services) => FileDestination(
  id: 'qson:operation',
  label: () => t.fileOpen.importAsOperation,
  kind: HaloFileKind.qson,
  open: (context, file) => runQsonImport(context, services, file: file),
);

/// Routes files the OS opens, and [launchArguments] that name one, through
/// a new [FileRouter].
///
/// Windows and Linux hand an opened document to a FRESH process as an
/// argument, so there is no callback to wait for — it is simply already
/// here. On Windows a second launch forwards its arguments to the running
/// instance, where they arrive as opened files.
void startFileRouting(HaLoServices services, List<String> launchArguments) {
  final router = FileRouter.start(globals: () => _globals(services));
  void open(String path) {
    // Windows forwards a second launch's every argument here, flags and links
    // included; only a file is the operator's to hear about. A link is
    // app_links' to handle, and a catalog install link ends in `.h2kext`
    // too. A one-letter scheme is a drive (`C:\…`), not a link.
    if ((Uri.tryParse(path)?.scheme.length ?? 0) > 1) {
      debugPrint('[open-file] ignoring link $path');
      return;
    }
    if (fileKindOfName(path) == null && !File(path).existsSync()) {
      debugPrint('[open-file] ignoring $path');
      return;
    }
    router.open(XFile(path));
  }

  services.openedFiles.openedFiles.listen(open, onError: (Object e, StackTrace st) => ErrorReportingService.report(e, st, context: 'open-file'));
  launchArguments.forEach(open);
}

List<FileDestination> _globals(HaLoServices services) => [
  FileDestination(
    id: extensionInstallDestinationId,
    label: () => t.fileOpen.installExtension,
    kind: HaloFileKind.extension,
    open: (context, file) => _installExtension(context, services, file),
  ),
  FileDestination(
    id: 'sets:keys',
    label: () => t.fileOpen.importKeyboardShortcuts,
    kind: HaloFileKind.keyBindings,
    open: (context, file) => importSetFile(context, keyboardShortcutSets(context, services), file),
  ),
  FileDestination(
    id: 'sets:cw',
    label: () => t.fileOpen.importCwMessages,
    kind: HaloFileKind.cwMessages,
    open: (context, file) => importSetFile(context, CwMessageSetCategory(services.settings), file),
  ),
  FileDestination(
    id: 'sets:voice',
    label: () => t.fileOpen.importVoiceMessages,
    kind: HaloFileKind.voiceMessages,
    open: (context, file) => importSetFile(context, VoiceMessageSetCategory(services.settings, services.cat), file),
  ),
  FileDestination(id: logsAdifDestinationId, label: () => t.fileOpen.importIntoLogs, kind: HaloFileKind.adif, open: (context, file) => _logsAdif(file)),
  qsonFileDestination(services),
];

/// The same install as the Extensions panel's button: the bundle inspected,
/// the consent screen shown, nothing written before the operator agrees.
Future<void> _installExtension(BuildContext context, HaLoServices services, XFile file) async {
  // A bundle that cold-launches the app can arrive before the store exists.
  var store = services.extensions.installed;
  for (var attempt = 0; store == null && attempt < 20; attempt++) {
    await Future<void>.delayed(const Duration(milliseconds: 250));
    store = services.extensions.installed;
  }
  if (store == null || !context.mounted) {
    debugPrint('[open-file] ${file.name} not installed: no extension store after 5s');
    return;
  }
  final name = await installExtensionFromBytes(
    context,
    store: store,
    read: file.readAsBytes,
    commit: commitThroughInstaller(services),
    replacedSource: services.extensions.replacedSource,
    isBusy: services.extensionInstaller.isActive,
  );
  if (name != null) services.track('extension_installed', {});
}

/// Brings up the Logs view and hands it the file, since the import there
/// belongs to the view: it takes the table down while it writes.
///
/// Back to Home first, as the command bar's Go Home does — Logs is one of
/// Home's destinations — and then through [HomeRailState.leaveTo], so a
/// destination with work to settle is asked before it is left; one that
/// refuses keeps the operator where they are and the file goes nowhere.
Future<void> _logsAdif(XFile file) async {
  navigatorKey.currentState?.popUntil((route) => route.isFirst);
  await homeRail.leaveTo(HomeDestination.logs);
  final logs = await FileSuggestions.waitFor(logsAdifDestinationId);
  if (logs == null || !logs.context.mounted) return;
  await logs.destination.open(logs.context, file);
}
