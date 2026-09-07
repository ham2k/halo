// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Everything the OS hands the running app — a `com.ham2k*://` link, a
// `.h2kext` opened from the file manager — dispatched from one place. A link
// that cold-launches the app arrives before there is a navigator to open
// onto; every handler here waits for one instead of dropping it.

import 'dart:async';
import 'dart:io' show File;

import 'package:flutter/material.dart';
import 'package:halo_core/halo_core.dart';

import '../views/confirm_device_dialog.dart';
import '../views/operation_view.dart';
import '../views/extension_install_flow.dart';
import '../views/settings_view.dart';
import 'package:http/http.dart' as http;

import 'deep_link_service.dart';

import 'error_reporting_service.dart';
import 'installed_extensions.dart';
import 'status_bar_service.dart';
import '../i18n/strings.g.dart';

import '../config/navigation.dart';
import 'halo_services.dart';

/// Opens the "Confirm a device" pane for an incoming `link_client` deep
/// link — the QR code a device asking to join this account displays (see
/// [DeepLinkService.linkClientRequest]).
///
/// App-wide rather than owned by the Sync settings panel: the operator scans
/// that QR with a phone camera and the OS hands the link to whatever the app
/// happens to be showing, which is rarely Settings. A link arriving before
/// the first frame has no navigator to open onto and is dropped; the code
/// entry in the same pane is the way back from that.
/// A `.h2kext` opened from Finder installs the same way a picked one does.
///
/// Anything else the OS hands us is ignored rather than refused: this app is
/// registered for exactly one document type, so a file arriving here that is
/// not one is a platform oddity, not something to interrupt the operator about.
void listenForOpenedExtensionFiles(HaLoServices services) {
  services.openedFiles.openedFiles.listen((path) {
    if (!path.toLowerCase().endsWith('.h2kext')) {
      debugPrint('[open-file] ignoring $path');
      return;
    }
    openInstallExtension(services, Uri.file(path));
  }, onError: (Object e, StackTrace st) => ErrorReportingService.report(e, st, context: 'open-file'));
}

/// Every incoming `com.ham2k*://` link, dispatched in one place — see
/// [DeepLinkService] for the catalog. The order below is "during an
/// activation" before "during setup", which is also roughly how often each
/// arrives.
void listenForDeepLinks(HaLoServices services) {
  services.deepLinks.links.listen((uri) {
    final install = DeepLinkService.installExtensionRequest(uri);
    if (install != null) {
      openInstallExtension(services, install);
      return;
    }
    // The companion-app bridge, ahead of link_client only because these are
    // the links that arrive during an activation rather than during setup.
    final vfo = DeepLinkService.vfoRequest(uri);
    if (vfo != null) {
      _applyVfoDeepLink(services, vfo);
      return;
    }
    final linkedQso = DeepLinkService.qsoRequest(uri);
    if (linkedQso != null) {
      unawaited(_presentDeepLinkedQso(services, linkedQso));
      return;
    }
    final ourRefs = DeepLinkService.operationRequest(uri);
    if (ourRefs != null) {
      unawaited(_openDeepLinkedOperation(services, ourRefs));
      return;
    }
    final request = DeepLinkService.linkClientRequest(uri);
    if (request == null) return;
    // A device with no account of its own has nothing to admit anybody to,
    // and the pane would open only to report that. Says so where the
    // operator is looking instead — they just scanned a code and are owed
    // an answer either way.
    if (!services.settings.syncEnabled) {
      services.statusBar.showNotice(
        key: 'sync:link-request-needs-sync',
        icon: 'cloud-off',
        title: t.confirmDevice.needsSyncTitle,
        text: t.confirmDevice.needsSyncText,
        actions: [
          StatusBarAction(
            label: t.settings.syncPanel.openSettings,
            onTap: () => navigatorKey.currentState?.push(
              MaterialPageRoute(builder: (_) => SettingsView(services: services, initialPanel: 'sync')),
            ),
          ),
        ],
      );
      return;
    }
    _openConfirmDevicePane(services, request);
  }, onError: (Object e, StackTrace st) => ErrorReportingService.report(e, st, context: 'deep-link'));
}

/// How recent an operation has to be for an `/operation` link to reuse it
/// rather than start a new one. Matches app-polo's `RECENT_WINDOW_MS`: an
/// activation interrupted overnight is the same activation, and one from last
/// month is not.
const _deepLinkRecentWindow = Duration(hours: 48);

/// Puts the radio state a `/vfo` link reports into the app's own VFO.
///
/// Needs no navigator, and so is the one deep link that works during a cold
/// launch: it writes a service, not a screen.
void _applyVfoDeepLink(HaLoServices services, ({double? freqKHz, String? band, String? mode}) vfo) {
  services.radio.setVfo('vfoA', freq: vfo.freqKHz, band: vfo.band, mode: vfo.mode);
  services.track('deep_link_vfo', {});
}

/// Presents the QSO a `/qso` link proposes in the front-most operation — or,
/// with none open, in the most recent one.
///
/// The radio state travels with it, unlike a spot tap: a companion app sending
/// a QSO is reporting where this operator's radio IS (app-polo's
/// `_updatesVFO`), so the fields and the VFO must agree afterwards.
Future<void> _presentDeepLinkedQso(
  HaLoServices services,
  ({
    List<String> calls,
    double? freqKHz,
    String? band,
    String? mode,
    int? startAtMillis,
    List<({String key, String ref})> theirRefs,
  }) link,
) async {
  final resolved = await _deepLinkRefs(services, link.theirRefs, (types) => types.huntingType);
  if (link.freqKHz != null || link.band != null || link.mode != null) {
    services.radio.setVfo('vfoA', freq: link.freqKHz, band: link.band, mode: link.mode);
  }
  final outcome = await _deliverDeepLinkedQso(services, {
    // Comma-joined, which is HaLo's "one QSO per call" syntax — see
    // `DeepLinkService.qsoRequest`.
    'their': {'call': link.calls.join(',')},
    if (link.freqKHz != null) 'freq': link.freqKHz,
    if (link.band != null) 'band': link.band,
    if (link.mode != null) 'mode': link.mode,
    if (link.startAtMillis != null) 'startAtMillis': link.startAtMillis,
    'refs': resolved.refs,
  });
  // The contact landed, but not everything the link asked for came with it —
  // the operator is about to log a hunt that records fewer programs than the
  // sender named, and only they can tell the companion-app author.
  if (outcome == _DeepLinkOutcome.delivered && resolved.dropped.isNotEmpty) {
    _reportDroppedRefs(services, resolved);
  }
  services.track('deep_link_qso', {
    'outcome': outcome.name,
    'refsDropped': resolved.dropped.length,
  });
}

/// What became of a `/qso` link, so telemetry counts deliveries rather than
/// attempts and the caller knows whether to bother reporting anything else.
enum _DeepLinkOutcome { delivered, noOperation, noNavigator }

/// Tells the operator which references a link named that this device could
/// not place, and why.
///
/// A load failure and an unknown key are different sentences on purpose:
/// "your activity is unknown" is a confident claim about their setup, and
/// saying it because the runtime had not booted sends them hunting through
/// Manage Extensions for a problem that is not there.
void _reportDroppedRefs(HaLoServices services, ({List<Map<String, dynamic>> refs, List<String> dropped, bool loadFailed}) resolved) {
  final names = resolved.dropped.join(', ');
  services.statusBar.setMessage(
    key: 'deep-link:dropped-refs',
    text: resolved.loadFailed
        ? t.deepLink.activitiesUnavailable(refs: names)
        : t.deepLink.unknownActivities(refs: names),
  );
}

/// Hands [suggestion] to an operation's logging fields.
///
/// Prefers the operation already in front — pushing a second copy of a view
/// the operator is already looking at would bury their work under it. Only
/// with nothing open does this fall back to the most recent operation, which
/// is what a companion app assumes "the log" means.
///
/// The retry mirrors [openInstallExtension]'s: a link that cold-launches the
/// app arrives before the first frame, and dropping it silently leaves
/// whoever sent it with nothing at all.
Future<_DeepLinkOutcome> _deliverDeepLinkedQso(
  HaLoServices services,
  Map<String, dynamic> suggestion, {
  int attemptsLeft = 20,
}) async {
  final front = services.frontOperationContext;
  final suggest = front?.suggestQso;
  if (suggest != null) {
    suggest(suggestion);
    // The fields are filled, but behind Settings or a nested operation there
    // is nothing on screen to show for it — so the link looks dead unless we
    // say where the contact went. Not popped: whatever is on top may hold an
    // edit in progress, and a link is not permission to discard it.
    if (front?.isVisible?.call() == false) {
      services.statusBar.setMessage(key: 'deep-link:delivered-behind', text: t.deepLink.waitingInOperation);
    }
    return _DeepLinkOutcome.delivered;
  }
  final navigator = navigatorKey.currentState;
  if (navigator == null) {
    if (attemptsLeft <= 0) {
      // A navigator still absent five seconds after launch is our bug, not a
      // state to wait out — and the operator is owed an answer either way.
      ErrorReportingService.report(
        StateError('deep link dropped: no navigator after 5s'),
        StackTrace.current,
        context: 'deep-link',
      );
      return _DeepLinkOutcome.noNavigator;
    }
    Timer(const Duration(milliseconds: 250),
        () => unawaited(_deliverDeepLinkedQso(services, suggestion, attemptsLeft: attemptsLeft - 1)));
    // Not an outcome yet — the retry reports its own. Counting this as a
    // delivery is what would make the metric read 100% success forever.
    return _DeepLinkOutcome.noNavigator;
  }
  final operations = await services.operations.watchAll().first;
  if (operations.isEmpty) {
    // Nowhere to put it, and no operation to invent on a link's say-so: a
    // contact belongs to an activation the operator started. app-polo returns
    // silently here; saying so is the difference between a broken link and a
    // link that needs one thing first.
    services.statusBar.setMessage(key: 'deep-link:no-operation', text: t.deepLink.needsAnOperation);
    return _DeepLinkOutcome.noOperation;
  }
  // Re-read rather than reusing the one checked above: the database await
  // between them is long enough for a hot restart or a root rebuild to
  // deactivate that state, and pushing onto a dead navigator throws out of an
  // unawaited future.
  final target = navigatorKey.currentState;
  if (target == null) return _DeepLinkOutcome.noNavigator;
  target.push(MaterialPageRoute(
    builder: (_) => OperationView(
      services: services,
      operationUuid: operations.first.uuid,
      initialSuggestedQso: suggestion,
    ),
  ));
  return _DeepLinkOutcome.delivered;
}

/// Finds the recent operation activating exactly the references an
/// `/operation` link names, or creates one, and opens it.
///
/// Exact set matching, as in app-polo: a park-only request must not latch onto
/// a park-and-summit operation, and vice versa — those are distinct
/// activations, and reusing one for the other silently files the contacts
/// under the wrong award.
Future<void> _openDeepLinkedOperation(
  HaLoServices services,
  List<({String key, String ref})> pairs, {
  int attemptsLeft = 20,
}) async {
  if (navigatorKey.currentState == null) {
    if (attemptsLeft <= 0) {
      ErrorReportingService.report(
        StateError('deep link dropped: no navigator after 5s'),
        StackTrace.current,
        context: 'deep-link',
      );
      return;
    }
    Timer(const Duration(milliseconds: 250),
        () => unawaited(_openDeepLinkedOperation(services, pairs, attemptsLeft: attemptsLeft - 1)));
    return;
  }
  final resolved = await _deepLinkRefs(services, pairs, (types) => types.activationType);
  if (resolved.refs.isEmpty) {
    _reportDroppedRefs(services, resolved);
    return;
  }
  // Some resolved, some did not — and this is the dangerous half. `wanted`
  // below is built from what SURVIVED, so a truncated request would be
  // matched, and created, as a smaller activation than the one asked for:
  // exactly the cross-award filing `activationRefsMatch` exists to prevent.
  // Proceeding is the operator's call to undo; saying nothing is not.
  if (resolved.dropped.isNotEmpty) _reportDroppedRefs(services, resolved);

  final wanted = {for (final ref in resolved.refs) '${ref['type']}:${ref['ref']}'};
  final cutoff = nowMillis() - _deepLinkRecentWindow.inMilliseconds;
  final operations = await services.operations.watchAll().first;
  Operation? existing;
  for (final operation in operations) {
    final lastActive = operation.startAtMillisMax ?? operation.createdAtMillis ?? 0;
    if (lastActive < cutoff) continue;
    if (DeepLinkService.activationRefsMatch(operation.data['refs'], wanted)) {
      existing = operation;
      break;
    }
  }

  final uuid = existing?.uuid ?? await _createDeepLinkedOperation(services, resolved.refs);
  // Re-read: `_deepLinkRefs`, the operation query and `decorateRef`'s network
  // round trips are tens of seconds during which the state read at entry can
  // be deactivated.
  final navigator = navigatorKey.currentState;
  if (navigator == null) return;
  navigator.push(MaterialPageRoute(builder: (_) => OperationView(services: services, operationUuid: uuid)));
  services.track('deep_link_operation', {
    'created': existing == null,
    'refsDropped': resolved.dropped.length,
  });
}

/// Creates the operation an `/operation` link asked for, with its references
/// already decorated.
///
/// Decorating BEFORE the view mounts, rather than letting it fill in
/// afterwards: the view titles itself from the refs it finds
/// (`OperationTitleService`), so mounting on bare codes titles the operation
/// from them and only re-titles if something writes the names later.
Future<String> _createDeepLinkedOperation(HaLoServices services, List<Map<String, dynamic>> refs) async {
  final decorated = <Map<String, dynamic>>[];
  for (final ref in refs) {
    // An unnamed park is better than no operation, so a decoration that fails
    // costs that reference its name and nothing more.
    //
    // `decorateRef` already swallows ExtensionHostException itself and hands
    // the ref back unchanged, so a program that cannot reach its API never
    // arrives here. What does is the residue — a wrong-typed hook result, a
    // kernel ArgumentError — and those are OUR bugs, which a bare catch would
    // bury for good. Same split as activities_view.dart's.
    try {
      decorated.add(await services.extensions.decorateRef(ref));
    } catch (e, stack) {
      ErrorReportingService.report(e, stack, context: 'deep-link:decorate-ref');
      decorated.add(ref);
    }
  }
  final operation = await services.operations.create(
    stationCall: services.settings.activeProfile.operatorCall,
  );
  await services.operations
      .saveData(Operation(uuid: operation.uuid, data: {...operation.data, 'refs': decorated}));
  return operation.uuid;
}

/// A deep link's `key:ref` pairs as QSON refs, with [typeFor] choosing which
/// of the extension's two reference types applies — an operation ACTIVATES,
/// a QSO HUNTS.
///
/// A key no installed activity claims is skipped rather than guessed at (as
/// in app-polo): inventing `${key}Activation` would write a reference type
/// nothing scores, exports or recognizes.
///
/// `dropped` names the keys that got no type, and `loadFailed` says WHY they
/// did — the runtime could not be asked, versus nothing claims them. The two
/// are different sentences to the operator, and the caller must not report an
/// empty result as "you don't have that activity" when it never got to ask.
///
/// A non-empty `dropped` alongside a non-empty `refs` is a PARTIAL result,
/// which is the case worth care: the request has been silently narrowed, and
/// downstream set matching will honour the narrowed version.
Future<({List<Map<String, dynamic>> refs, List<String> dropped, bool loadFailed})> _deepLinkRefs(
  HaLoServices services,
  List<({String key, String ref})> pairs,
  String? Function(({String? activationType, String? huntingType}) types) typeFor,
) async {
  if (pairs.isEmpty) return (refs: const <Map<String, dynamic>>[], dropped: const <String>[], loadFailed: false);
  final types = await services.extensions.activityRefTypes();
  final refs = <Map<String, dynamic>>[];
  final dropped = <String>[];
  for (final pair in pairs) {
    final known = types.byKey[pair.key];
    final type = known == null ? null : typeFor(known);
    if (type == null) {
      dropped.add(pair.key);
      continue;
    }
    refs.add({'type': type, 'ref': pair.ref});
  }
  if (dropped.isNotEmpty) {
    debugPrint('[deep-link] no reference type for ${dropped.join(', ')} (loadFailed=${types.loadFailed})');
  }
  return (refs: refs, dropped: dropped, loadFailed: types.loadFailed);
}

/// Downloads the bundle a link named and offers to install it, once there is
/// a navigator to ask on.
///
/// The download happens INSIDE the install flow's read step, so a fetch that
/// fails is reported the same way an unreadable file is, and nothing is
/// written before the operator has seen where it came from and agreed. The
/// retry mirrors the link_client one: a deep link that cold-launches the app
/// arrives before the first frame, and dropping it silently leaves whoever
/// clicked it with nothing at all.
void openInstallExtension(HaLoServices services, Uri source, {int attemptsLeft = 20}) {
  final context = navigatorKey.currentContext;
  final store = services.extensions.installed;
  if (context == null || store == null) {
    if (attemptsLeft <= 0) {
      debugPrint('[deep-link] install_extension dropped: no navigator or store after 5s');
      return;
    }
    Timer(const Duration(milliseconds: 250),
        () => openInstallExtension(services, source, attemptsLeft: attemptsLeft - 1));
    return;
  }
  // A file the operator double-clicked is one they chose, exactly like one
  // picked through the button — so it names no source, and an update that
  // asks for nothing new goes through without a second dialog. Only a bundle
  // fetched from a link is attributed.
  final local = source.isScheme('file');
  unawaited(installExtensionFromBytes(
    context,
    store: store,
    read: local ? () => File(source.toFilePath()).readAsBytes() : () => _downloadBundle(source),
    from: local ? null : source.host,
    commit: services.extensions.installBundle,
  ).then((name) {
    if (name == null) return;
    services.track('extension_installed', {});
    services.statusBar.setMessage(key: 'extensions:installed', text: t.extensionsPanel.installedMessage(name: name));
  }));
}

/// Fetches a bundle, refusing anything implausibly large before it is held in
/// memory — the link naming it is not one this app chose to trust.
Future<List<int>> _downloadBundle(Uri source) async {
  final client = http.Client();
  try {
    var target = source;
    // Redirects followed by hand, because the point of demanding https is
    // that nobody on the path can rewrite what the consent screen describes —
    // and a client following redirects for us will happily walk https into
    // http and hand back the result as though it were the URL we asked for.
    for (var hop = 0; hop < 5; hop++) {
      final request = http.Request('GET', target)..followRedirects = false;
      final response = await client.send(request).timeout(const Duration(seconds: 30));
      final location = response.headers['location'];
      if (response.statusCode >= 300 && response.statusCode < 400 && location != null) {
        final next = target.resolve(location);
        if (next.scheme != 'https') {
          throw BundleException(BundleRejection.notAnArchive, t.extensionsPanel.downloadNotSecure);
        }
        target = next;
        continue;
      }
      if (response.statusCode != 200) {
        throw BundleException(BundleRejection.notAnArchive,
            t.extensionsPanel.downloadFailed(source: target.host, status: response.statusCode));
      }
      // Counted as it arrives. Reading the whole body first and measuring it
      // afterwards is a cap that has already let the thing it refuses into
      // memory.
      final bytes = <int>[];
      await for (final chunk in response.stream) {
        bytes.addAll(chunk);
        if (bytes.length > kMaxDownloadBytes) {
          throw BundleException(BundleRejection.tooLarge, t.extensionsPanel.downloadTooLarge);
        }
      }
      return bytes;
    }
    throw BundleException(BundleRejection.notAnArchive, t.extensionsPanel.downloadFailed(source: source.host, status: 310));
  } finally {
    client.close();
  }
}

/// Opens the pane once there is a navigator to open it onto.
///
/// A deep link that cold-launches the app arrives while the first frame is
/// still being built, and dropping it there is invisible to the operator:
/// for a QR request there is no code to fall back to typing, and no
/// Connection Requests row either, since a blank permission has no account
/// behind it for `pending_challenges` to count. Retries on the same cadence
/// the staleness nag uses for the same reason.
void _openConfirmDevicePane(
  HaLoServices services,
  ({String clientUuid, String challengeToken}) request, {
  int attemptsLeft = 20,
}) {
  final context = navigatorKey.currentContext;
  if (context == null) {
    if (attemptsLeft <= 0) {
      debugPrint('[deep-link] link_client dropped: no navigator after 5s');
      return;
    }
    Timer(const Duration(milliseconds: 250),
        () => _openConfirmDevicePane(services, request, attemptsLeft: attemptsLeft - 1));
    return;
  }
  unawaited(showConfirmDeviceDialog(
      context,
      findByCode: services.extensions.syncFindLinkRequest,
      findByClient: services.extensions.syncFindLinkRequestByClient,
      approve: services.extensions.syncApproveLinkRequest,
      clientUuid: request.clientUuid,
      challengeToken: request.challengeToken,
    ).then((linked) {
      // Re-read rather than reusing the context above: the pane was open
      // across an arbitrary stretch of the operator's attention.
      final messengerContext = navigatorKey.currentContext;
      if (linked != true || messengerContext == null) return;
      ScaffoldMessenger.of(messengerContext)
          .showSnackBar(SnackBar(content: Text(t.settings.syncPanel.deviceLinked)));
    }));
}
