// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The service graph: one lazily-built bundle, handed to every screen by
// constructor. Constructor injection over a container is deliberate — the
// database is the source of truth and the fields below cost nothing until
// touched (DESIGN.md §6, main.dart). Also home to the command-action switch,
// which acts on the whole graph and so lives beside it.

import 'dart:async';

import 'package:intl/intl.dart';
import 'package:intl/number_symbols.dart';

import 'package:flutter/foundation.dart' show kIsWeb, setEquals;
// Prefixed separately from the AppExitResponse import above: some import in
// this file's graph makes the bare name `TextDirection` resolve to something
// without an `.ltr` getter, so the real dart:ui one needs this to be reached
// unambiguously.
import 'dart:ui' as dart_ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:halo_core/halo_core.dart';
import 'package:halo_extension_host/halo_extension_host.dart' show HookCalls;
import 'package:halo_widgets/halo_widgets.dart';

import '../tools/contest_bench.dart';
import '../tools/operation_title.dart';
import '../views/operation_dialogs.dart';
import '../views/operation/operation_location_screen.dart';
import '../views/settings_view.dart';
import '../views/cw_messages_dialog.dart';
import '../views/voice_messages_dialog.dart';
import '../views/settings/accounts_panel.dart';
import '../views/notice_actions.dart';
import '../views/extension_install_flow.dart' show updateAllFromCatalog;
import '../config/experiments.dart';
import '../config/secrets.dart';

import 'extensions/catalog_service.dart';
import 'panel_radio_service.dart';
import 'deep_link_service.dart';
import 'export_service.dart';
import 'connectivity_service.dart';
import 'error_policy.dart';

import 'error_reporting_service.dart';
import 'extensions/extension_dev_client.dart';
import 'extensions/extension_installer.dart';
import 'extensions/extension_service.dart';
import 'opened_files_service.dart';
import 'geoshape_service.dart';
import 'cat/equipment.dart' show EquipmentNode, EquipmentStatus, kCategoryTransceiver;
import 'cat/cat_service.dart';
import 'cat/cat_traffic_log.dart';
import 'cat/cat_traffic_recording.dart';
import 'cat/keyer_commands.dart';
import 'cat/equipment_details.dart';
import 'cat/radio_proof.dart';
import 'peer/ble/peer_ble.dart';
import 'peer/peer_channels.dart';
import 'peer/peer_drafts.dart';
import 'peer/serial_claims.dart';
import 'peer/peer_account_tag.dart';
import 'peer/peer_screen_views.dart';
import 'peer/peer_remote_radios.dart';
import 'peer/peer_screens.dart';
import 'peer/peer_service.dart';
import 'inbound_qso_listener_service.dart';
import 'cat_server/cat_server_rig.dart';
import 'cat_server/cat_server_service.dart';
import 'location_service.dart';
import 'lookup_queue_service.dart';
import 'metrics_service.dart';
import 'panel_service.dart';
import 'purchase_service.dart';
import 'pusher_service.dart';
import 'radio_service.dart';
import 'operation_title_service.dart';
import 'scoring_service.dart';
import 'settings_service.dart';
import 'spots_service.dart';
import 'status_bar_service.dart';
import 'web_popup.dart';
import '../settings/core_settings_groups.dart';
import '../settings/settings_command.dart';
import '../settings/settings_registry.dart';
import '../settings/settings_target_dialog.dart';
import '../settings/system_lists.dart';
import 'update_check_service.dart';
import 'staleness_service.dart';
import 'update_service.dart';
import 'data_file_manager.dart';
import 'flags_service.dart';
import 'package:halo_i18n/halo_i18n.dart';

import '../config/navigation.dart';
import 'dev_overlay_trigger.dart';
import 'status_bar_hammer.dart';
import 'wake_lock_service.dart';
import 'sibling_apps_service.dart';

/// One open Operation View's contribution to the ⌘K dialog's context — see
/// [HaLoServices.openOperationContext].
class OperationCommandContext {
  OperationCommandContext(this.uuid);

  final String uuid;

  /// The operation QSON with `uuid` folded in, once it has loaded.
  Map<String, dynamic>? operation;

  /// This operation's logging panel dispatcher, while one is mounted.
  CommandActionsDispatcher? dispatch;

  /// Puts a QSON-shaped suggestion into this operation's logging fields — the
  /// same prefill a tapped spot performs (`OperationView`'s `_suggestQso`).
  ///
  /// Here rather than as a [CommandActionsDispatcher] action because a
  /// suggestion is not a command: it arrives from outside the operation
  /// entirely (a `/qso` deep link), carries refs and radio state together, and
  /// must reach the view even when no logging panel is mounted to dispatch
  /// through — which is exactly when [dispatch] is null.
  void Function(Map<String, dynamic> qso)? suggestQso;

  /// Whether this operation is the route the operator is actually looking at.
  /// False with Settings, or a nested operation, pushed over it — where a
  /// suggestion still lands correctly but nothing on screen shows it.
  bool Function()? isVisible;
}

/// The core services bundle passed down to screens.
class HaLoServices {
  final HaLoDatabase db;
  final SettingsService settings;
  final ExtensionService extensions;
  final MetricsService metrics;
  final PurchaseService purchases;
  final UpdateService updates;
  final UpdateCheckService updateCheck;

  /// Every local write fans out to BOTH consumers, and both repositories get
  /// the same lambda — a third repository wired to only one of them would
  /// leave that consumer silently behind on those writes. `notifyChanged` is
  /// a no-op on each until it has something to do (sync disabled, or no
  /// operation being shared), so this costs nothing when neither is running.
  void _onLocalWrite() {
    syncEngine.notifyChanged();
    peerOutbox.notifyChanged();
  }

  late final OperationsRepository operations = OperationsRepository(
    db,
    onChange: _onLocalWrite,
    // The latest segment follows a local edit to what it restates: a rover
    // who sets a new square through the Location screen after a BREAK would
    // otherwise keep scoring from the break's old one (contests.md §5.1.3).
    onLocalSave: (before, after) async {
      final override = segmentOverrideOf(after.data);
      if (before == null || segmentOverrideDiffers(before.data, after.data)) {
        // The segment's contacts follow its station call, unasked: the
        // segment states which station was on the air for that stretch, so a
        // contact inside it cannot say otherwise. The FIRST call — several
        // live in the field as one string, and a contact holds one (HALO-507).
        await qsos.restampSegmentStationCall(after.uuid, after.stationCalls.first);
      }
      // On EVERY local save, not only one that moves a segment key: a row's
      // description is composed from the operation's title, which an edit to
      // anything the title reads can change. An unsegmented log costs one
      // query here; only a segmented one pays the extension fan-out per row.
      await qsos.restampSegments(after.uuid, override, describe: (kind, rowOverride) => segmentDescription(after, rowOverride, kind: kind));
    },
  );
  late final SequencesRepository sequences = SequencesRepository(db);
  late final QsosRepository qsos = QsosRepository(db, onChange: _onLocalWrite, sequences: sequences);

  /// Files the OS asked this app to open — a double-clicked `.h2kext`
  /// (HALO-422). Lazy: nothing listens until something wires it up.
  late final OpenedFilesService openedFiles = OpenedFilesService();

  /// The app end of the extension dev loop
  /// (docs/extensions/development.md). Lazy, and inert until someone turns it
  /// on in Developer settings and types a server address — an operator who
  /// never writes an extension pays nothing for it.
  late final ExtensionDevClient extensionDev = ExtensionDevClient(extensions: extensions);

  /// The peer-sync outbox (HALO-310). Owned here rather than inside
  /// [peerService] because the repositories' `onChange` reaches it on every
  /// local write, including while nothing is being shared — when it does
  /// nothing at all.
  late final PeerOutbox peerOutbox = PeerOutbox(db);

  /// LAN peer device sync. Binds nothing until the master switch turns it
  /// on, so a lazy `late final` that nobody touches costs an operator who
  /// never uses this exactly nothing.
  final PeerService? _peerServiceOverride;
  late final PeerService peerService =
      _peerServiceOverride ??
      PeerService(
        db: db,
        outbox: peerOutbox,
        operations: operations,
        qsos: qsos,
        localDeviceId: settings.peerDeviceId,
        localDeviceName: settings.peerDeviceName,
        // Null on web. Constructing the gateway touches no radio; only the
        // Bluetooth sub-switch wakes it.
        bleGateway: createPeerBleGateway(),
      );

  /// Routes the sessions' ephemeral channel (GPS, CAT next) between
  /// [peerService] and the app services that produce and consume it. Its
  /// construction is what plugs the channel in, so [updatePeerSharing]
  /// touches it before starting anything — lazily, like the service itself.
  late final PeerChannels peerChannels = PeerChannels(
    peers: peerService,
    location: location,
    radio: radio,
    // Both halves of screen sharing, constructed only when the experiment
    // is on: touching either lazy field is what registers a native channel
    // handler and what makes this router route those messages at all.
    screens: settings.experimentEnabled('remote') ? peerScreens : null,
    views: settings.experimentEnabled('remote') ? peerScreenViews : null,
    // Gated on p2p rather than on `remote`: this is peer sync's own live
    // logging view, not screen sharing.
    drafts: settings.experimentEnabled('p2p') /* stored key, see experiments.yaml */ ? peerDrafts : null,
    claims: settings.experimentEnabled('p2p') /* stored key, see experiments.yaml */ ? serialClaims : null,
    station: cat,
    remoteRadios: peerRemoteRadios,
  );

  /// The radios the PEERS are offering (HALO-416), for the Station panel's
  /// main-VFO picker. Not experiment-gated the way the screen halves are:
  /// the CAT bridge rides peer sync itself, and an empty holder is exactly
  /// what a build with no peers has.
  late final PeerRemoteRadios peerRemoteRadios = PeerRemoteRadios();

  /// Whether whatever drives `vfoA` will act on a tune right now — a local
  /// rig with a session up, or a peer that is offering the picked radio.
  ///
  /// One place because several surfaces ask it, and a peer answered
  /// differently by any one of them is a rig the app claims to be following
  /// and then is not: the Radio chip's red/green, the status bar's radio
  /// entry, and Avoid Zero Beat, which turns itself off wherever nothing
  /// will act on the offset. Something DOES act for a peer —
  /// `PeerChannels._onRadioChanged` forwards an operator's move as `catSet`
  /// — so a peer reading "not connected" tunes the far rig exactly zero
  /// beat, which is the failure that setting exists to prevent.
  ///
  /// Reads [cat], which builds CatService on first touch.
  bool get radio1IsLive => switch (cat.radio1) {
    LocalRadio(:final uuid) => cat.stateFor(uuid).status == EquipmentStatus.connected,
    PeerRadio(:final selection) => peerRemoteRadios.find(selection.deviceId, selection.radioId) != null,
    null => false,
  };

  /// What to call whatever drives `vfoA`, or null when there is nothing to
  /// call it — a peer's remembered name is all there is while that device is
  /// away, and a pick made as a peer dropped carries none at all.
  ///
  /// Null rather than the raw id: this is also what a logged QSO's rig field
  /// is filled from, and an id there is worse than an empty field. A row
  /// that would otherwise render blank falls back to the id itself.
  String? get radio1Name => switch (cat.radio1) {
    LocalRadio(:final uuid) => switch (cat.nodeFor(uuid)) {
      final node? => cat.displayNameFor(node),
      null => null,
    },
    PeerRadio(:final selection) => selection.radioName.isEmpty ? null : selection.radioName,
    null => null,
  };

  /// The producer half of screen sharing (HALO-369). Lazy like the rest, and
  /// for a stronger reason than most: constructing it registers the native
  /// capture channel's handlers, and an install that never turns the
  /// experiment on should never so much as name ScreenCaptureKit.
  late final PeerScreens peerScreens = PeerScreens(settings: settings, peers: peerService);

  /// What every operating position sharing the open operation is composing
  /// (HALO-395) — this device's own block included. Lazy like the rest: an
  /// install that never turns the experiment on never constructs it, and
  /// `PeerChannels` then has nowhere to route a `qsoDraft`.
  late final PeerDrafts peerDrafts = PeerDrafts(peers: peerService);

  /// The contest serial numbers this device holds while composing, against
  /// its peers' (HALO-476). Lazy like the rest: the panel only asks for it
  /// while sharing drafts, and falls back to `peek` otherwise. Unlike the
  /// drafts it crosses Bluetooth links too: a claim is a few hundred bytes,
  /// and a position on BLE left out of the round could only ever learn of a
  /// collision from the log. In the round, an idle link acks well inside
  /// the cap; one congested by a sync batch lets the claimant show at the
  /// cap and turns the collision, if there is one, into the conflict mark.
  late final SerialClaims serialClaims = SerialClaims(
    localDeviceId: peerService.localDeviceId,
    peek: sequences.peek,
    livePeers: () => [
      for (final deviceId in peerService.peers.keys)
        if (peerService.hasSession(deviceId)) deviceId,
    ],
    send: (deviceId, message) => peerService.sendEphemeralTo(deviceId, message, allowBle: true),
    onCommittedConflict: (operationUuid, request, number) => unawaited(qsos.markSerialConflict(operationUuid, request, number)),
  );

  /// The viewer half — what this device's peers offer, and what its Remote
  /// Screen panes are watching (HALO-369).
  late final PeerScreenViews peerScreenViews = PeerScreenViews(
    peers: peerService,
    // Its own producer, so a pane here can show a screen THIS device shares.
    screens: peerScreens,
    localName: t.settings.peers.screenThisDevice,
  );

  late final LookupRepository lookups = LookupRepository(db);

  /// Reference outlines (a SOTA activation zone and the like), fetched on
  /// demand and cached on the device. Lazy like the rest: an operator who
  /// never opens the Activities map never builds one.
  late final GeoshapeService geoshapes = GeoshapeService(extensions: extensions, lookups: lookups);
  late final InboundCaptureRepository inboundCaptures = InboundCaptureRepository(db);
  final ExportService? _exportsOverride;
  late final ExportService exports = _exportsOverride ?? ExportService(extensions: extensions, qsos: qsos, settings: settings);
  late final ScoringService scoring = ScoringService(extensions: extensions, qsos: qsos, operations: operations);

  /// The panel catalog a customizable view arranges (docs/design/layouts.md).
  /// Lazy like the rest: nothing asks the extensions for panels until a view
  /// that can hold one is actually built.
  late final PanelService panels = PanelService(extensions);
  late final OperationTitleService operationTitles = OperationTitleService(extensions: extensions, operations: operations);

  /// Deletes a Test Operation for real, QSOs included — see
  /// `OperationsRepository.purge`. Never call for a non-test operation:
  /// `operation_dialogs.dart`'s delete confirmation and PURGETESTS are the
  /// only two callers, and both check `Operation.isTestOperation` first.
  Future<void> purgeOperation(String uuid) async {
    // One transaction: a crash or throw between the two writes must never
    // leave the operation tombstoned while its QSOs are still live, or vice
    // versa — the orphan would then survive every future purge round, since
    // nothing revisits an operation once it isn't dirty.
    await db.transaction(() async {
      await operations.purge(uuid);
      await qsos.purgeForOperation(uuid);
    });
  }

  Future<bool> undeleteOperation(String uuid) => undeleteOperationWithQsos(db: db, operations: operations, qsos: qsos, uuid: uuid);

  /// The operator confirmed the "these were removed elsewhere" prompt
  /// ([watchReceivedTestOperationPurges] below) for [uuids] — hard-deletes them and
  /// their QSOs. Unlike [purgeOperation], these were never purged on this
  /// device; `operations.eligibleReceivedPurges` is what actually decides
  /// which of [uuids] still qualify (re-checked against the database, not
  /// trusted from whatever was on screen when the operator tapped confirm).
  ///
  /// Isolated per operation, like `_runPurgeTests` (command_actions.dart)'s own loop, but ALSO
  /// atomic per operation (`db.transaction`): the operator confirmed
  /// removing potentially several at once, and one throwing must not
  /// silently strand the rest — nor, within a single operation, delete its
  /// QSOs and then fail before the operation row goes too (or the reverse).
  /// A transaction is what makes "delete QSOs, then the operation row"
  /// order actually safe instead of just less likely to go wrong: without
  /// it, a failure between the two steps still leaves exactly the stranded
  /// state this exists to prevent.
  ///
  /// Returns both `eligible` (how many of [uuids] were still real
  /// candidates — the rest were dropped legitimately, e.g. the
  /// callsign-edit escape hatch fired between listing and confirming) and
  /// `removed` (how many of those actually succeeded). A caller comparing
  /// `removed` against `uuids.length` instead of `eligible` would read a
  /// clean run full of legitimate drops as a batch of failures.
  Future<({int eligible, int removed})> confirmReceivedTestOperationPurges(Iterable<String> uuids) async {
    final eligibleUuids = await operations.eligibleReceivedPurges(uuids);
    var removedCount = 0;
    for (final uuid in eligibleUuids) {
      try {
        await db.transaction(() async {
          await qsos.hardDeleteAllForOperation(uuid);
          await operations.hardDeleteOperation(uuid);
        });
        removedCount++;
      } catch (e, st) {
        ErrorReportingService.report(e, st, context: 'confirmReceivedTestOperationPurges:$uuid');
      }
    }
    return (eligible: eligibleUuids.length, removed: removedCount);
  }

  late final RadioService radio = _buildRadioService();

  /// The VFO store, with the one-time migration of the operator's stated
  /// power into it. Power used to live in `SettingsService.currentPower`
  /// (Station Configuration's field wrote it); it now rides on the VFO with
  /// frequency and mode, where every surface reads it. The old key is left
  /// where it is rather than deleted — nothing writes it any more, and it is
  /// the only record of the value for an operator who hasn't set one since.
  RadioService _buildRadioService() {
    final service = RadioService(settings.prefs);
    final legacy = settings.currentPower;
    if (service.vfoA.power == null && legacy != null) service.setVfo('vfoA', power: legacy);
    return service;
  }

  // Station equipment and CAT control (docs/design/cat.md). Lazy: built on
  // first touch.
  /// Injectable like [_exportsOverride], so a test can hand in a CatService
  /// built over a fake transport — the real one can only reach `connected`
  /// through hardware.
  final CatService? _catOverride;
  late final CatService cat = (_catOverride ?? (CatService(settings, radio: radio, onTrack: track)..onRadioProven = reportWorkingRadio))
    ..trafficLog = catTrafficLog;

  /// DEVLOGCAT's recorder. Injectable so a test can record into memory
  /// instead of the data folder.
  final CatTrafficLog catTrafficLog;

  /// DEVLOGCAT itself — see [CatTrafficRecording].
  late final CatTrafficRecording catTraffic = CatTrafficRecording(catTrafficLog, settings: settings, cat: () => cat, statusBar: statusBar);
  late final PanelRadioService panelRadio = PanelRadioService(cat, radio);

  /// Injectable like [_exportsOverride]: `permissionDenied` and `unavailable`
  /// are reachable only by denying an OS permission or losing a GPS fix, so a
  /// widget test of what those states put on screen has no other way in.
  final LocationService? _locationOverride;
  late final LocationService location = _locationOverride ?? LocationService();

  /// Injectable like [_exportsOverride]: the real one reads
  /// `AppLinks().uriLinkStream`, a platform channel with no implementation
  /// under `flutter test`, so a redirect coming back from the OS is
  /// otherwise unreachable — and the OAuth login it completes is the one
  /// flow whose happy path exists nowhere else.
  final DeepLinkService? _deepLinksOverride;
  late final DeepLinkService deepLinks = _deepLinksOverride ?? DeepLinkService();

  /// The other Ham2K loggers on this device, for the link-across
  /// offer in onboarding and Settings › Switch Accounts.
  final SiblingAppsService? _siblingAppsOverride;
  late final SiblingAppsService siblingApps = _siblingAppsOverride ?? SiblingAppsService();

  /// Push app key plus either a host or a cluster for the realtime client —
  /// public,
  /// non-secret values (every Pusher client SDK ships them this way), but
  /// still build-time configured like SOTA's OAuth client id
  /// (config/secrets.dart) since they point at whichever LoFi
  /// deployment this build talks to. Empty in a checkout that hasn't filled
  /// them in: [pusher] is then null and every realtime feature falls back
  /// to its polling path rather than crashing.
  /// Injectable so a test can drive the realtime path over a fake socket —
  /// the real one only ever exists in a build whose secrets name a Pusher
  /// deployment, which no test has.
  final PusherService? _pusherOverride;
  late final PusherService? pusher = _pusherOverride ?? _pusherFromSecrets();

  /// LoFi is migrating off Pusher onto Ham2K's own fan-out service, which
  /// speaks the same protocol on purpose (LOFI-47). A build names one or the
  /// other: `PUSHER_HOST` for ours, `PUSHER_CLUSTER` for Pusher's. Ours wins
  /// where a checkout has filled in both, so moving a build across is one line
  /// in secrets.dart.
  PusherService? _pusherFromSecrets() {
    final key = secrets['PUSHER_KEY'];
    if (key?.isEmpty ?? true) return null;

    final host = secrets['PUSHER_HOST'];
    if (host?.isNotEmpty ?? false) return PusherService(appKey: key!, host: host);

    final cluster = secrets['PUSHER_CLUSTER'];
    if (cluster?.isEmpty ?? true) return null;

    return PusherService(appKey: key!, cluster: cluster);
  }

  /// Registers this device with the sync server — independent of QSO sync
  /// being enabled, deliberately — and, once that succeeds,
  /// subscribes the realtime client to its push channel. Safe to call
  /// repeatedly (boot, and every [setOperatorCall]):
  /// `ensureLofiClientRegistered` is idempotent, and re-subscribing an
  /// already-subscribed channel is a no-op ([PusherService.subscribe]).
  ///
  /// Returns the registration so a caller that also needs it directly (e.g.
  /// `_doOAuth`, for the `webhookClientToken` its `state` param carries) can
  /// go through this one place rather than re-registering by hand.
  Future<LofiClientRegistration?> connectLofiRealtime({bool refreshWebhookToken = false}) async {
    final registration = await extensions.ensureLofiClientRegistered(refreshWebhookToken: refreshWebhookToken);
    if (registration != null) pusher?.subscribe(registration.pushChannelName);
    return registration;
  }

  /// Webhook-relay events on this device's push channel — an
  /// OAuth flow waiting on a provider redirect listens here for
  /// the ping, then calls [ExtensionService.fetchLofiWebhookEvents] for the
  /// payload (the push itself only ever carries an event id, never the
  /// sensitive payload — deliberately).
  Stream<PusherEvent> get webhookEvents => pusher?.events.where((e) => e.event == 'webhook_event') ?? const Stream.empty();
  final DataFileManager? _dataFilesOverride;
  late final DataFileManager dataFiles =
      _dataFilesOverride ??
      DataFileManager(
        lookups: lookups,
        extensions: extensions,
        prefs: settings.prefs,
        statusBar: statusBar,
        offlineChanges: ConnectivityService.offlineChanges,
        isOffline: () => ConnectivityService.isOffline,
        dataRevision: dataRevision,
      );

  /// [DataFileManager.dataRevision], held here so a view can listen without
  /// building the manager: reading [dataFiles] before the first runtime start
  /// has finished makes the manager hear that start as a replacement, and
  /// run a second raw import and an attended sync beside the boot's own. An
  /// overriding manager keeps its own notifier, so this one never ticks.
  final ValueNotifier<int> dataRevision = ValueNotifier<int>(0);
  late final StatusBarService statusBar = StatusBarService(settings.prefs);

  /// Holds the device awake while the logging view is in use or a sync is
  /// moving, when the operator has asked for it (see WakeLockService).
  late final WakeLockService wakeLock = WakeLockService(settings);

  /// Where a focused field publishes the mobile numbers row, so
  /// `StatusBarOverlay` can draw it below the status footer and directly on
  /// the keyboard — an order no single route can produce for itself.
  final KeyboardAccessoryController keyboardAccessory = KeyboardAccessoryController();

  /// Spots fetched once and shared by the Spots Panel and the `spot-history`
  /// lookup hook. Idle until something subscribes (see SpotsService).
  late final SpotsService spots = SpotsService(
    fetchSpots: extensions.getSpots,
    isOffline: () => ConnectivityService.isOffline,
    offlineChanges: ConnectivityService.offlineChanges,
  );

  final LookupQueueService? _lookupQueueOverride;
  late final LookupQueueService lookupQueue =
      _lookupQueueOverride ??
      LookupQueueService(
        lookup: extensions.lookupCall,
        qsos: qsos,
        operations: operations,
        statusBar: statusBar,
        lookupReady: () => extensions.ready,
        isOffline: () => ConnectivityService.isOffline,
        offlineChanges: ConnectivityService.offlineChanges,
      );

  /// See `InboundQsoListenerService`: listens for another logging program's
  /// QSOs (N1MM's UDP broadcast protocol) and buffers them until an operator
  /// adds them to an operation's log. Lazy like the rest, but
  /// [maybeStartInboundQsoListener] forces it into existence at boot when
  /// the setting is already on — a `late final` nobody has touched yet would
  /// otherwise never bind the socket, even though the operator turned
  /// listening on in a previous session.
  final InboundQsoListenerService? _inboundQsosOverride;
  late final InboundQsoListenerService inboundQsos =
      _inboundQsosOverride ??
      InboundQsoListenerService(
        settings: settings,
        captures: inboundCaptures,
        qsos: qsos,
        operations: operations,
        lookupQueue: lookupQueue,
        statusBar: statusBar,
      );

  /// Touches [inboundQsos] if listening is already enabled, so a setting
  /// left on from a previous session resumes without the operator having to
  /// open the Imports panel first. A no-op otherwise: nothing should bind a
  /// UDP port on every boot for a feature nobody turned on.
  void maybeStartInboundQsoListener() {
    if (settings.listenForOtherAppsEnabled) inboundQsos;
  }

  /// The emulated CAT server other programs drive the Main VFO radio
  /// through (docs/design/cat.md § CAT server). Lazy like [inboundQsos]:
  /// Settings touches it to show the server's status, and
  /// [maybeStartCatServer] once the settings ask for one.
  late final CatServerService catServer = CatServerService(
    settings: settings,
    rig: StationCatServerRig(cat: cat, radio: radio, peerRadios: peerRemoteRadios),
  );

  /// Starts the CAT server once the settings ask for one — at boot for one
  /// left on, or later when the experiment is turned on over a protocol
  /// already picked. The service follows the settings from then on; before
  /// it exists nothing would, and a server the operator turned on would not
  /// answer until Settings happened to be opened. Binds nothing, and builds
  /// nothing, for an operator who never turns it on.
  void maybeStartCatServer() => whenCatServerWanted(settings, () => catServer);

  /// Resumes peer sync when the switch was left on in a previous session —
  /// the same reason [maybeStartInboundQsoListener] exists: a `late final`
  /// nobody has touched yet would otherwise never start, even though the
  /// operator turned it on.
  void maybeStartPeerSync() {
    if (settings.experimentEnabled('p2p') /* stored key, see experiments.yaml */ && settings.peerSyncEnabled) {
      updatePeerSharing();
    }
  }

  /// Server-driven feature flags + notices for the active profile callsign
  /// (see FlagsService). Refreshed at boot and whenever the callsign changes
  /// via [setOperatorCall] — not per operation. The callsign is annotated
  /// through the extension runtime's offline lookup to derive the DXCC entity
  /// used to pick per-entity/per-call flag files.
  /// Injectable like [_exportsOverride]: the real one fetches from the flags
  /// server on every refresh, and a widget test of what the operator's
  /// callsign ranks (the catalog section) needs `operatorGeo` without that.
  final FlagsService? _flagsOverride;
  late final FlagsService flags =
      _flagsOverride ??
      FlagsService(
        statusBar: statusBar,
        annotate: (call) async {
          final result = await extensions.lookupCall(call, qso: const {}, operation: const {}, online: false);
          final guess = result?['guess'];
          return guess is Map ? guess.cast<String, dynamic>() : null;
        },
        onNoticeAction: handleNoticeAction,
        prefs: settings.prefs,
        onTrack: track,
        staleness: staleness,
      );

  /// The extension catalog (services/extensions/catalog_service.dart). Built at
  /// construction, because [_wireExtensions] hands it to the extension
  /// service there; every request it makes is still lazy.
  /// Injectable like [_exportsOverride], so a test hands in one over a
  /// MockClient rather than reaching catalog.ham2k.net.
  final CatalogService? _catalogOverride;
  late final CatalogService catalog = _catalogOverride ?? CatalogService(settings: settings);

  /// The unattended "is anything installed out of date" check, started once
  /// the runtime is up (bootstrap) and re-run on resume. Only ever tells —
  /// every install still asks — except for a revoked release, which it puts
  /// on record and unloads, apart from the operator's own switch.
  late final CatalogUpdateCheck catalogUpdateCheck = CatalogUpdateCheck(
    catalog: catalog,
    settings: settings,
    statusBar: statusBar,
    installed: () => extensions.availableExtensions,
    inUse: (info) => !extensions.isSupersededByBuiltIn(info),
    applyAvailability: extensions.applyExtensionAvailability,
    openExtensions: () => openSettingsPanel('extensions'),
    updateAll: _updateAllFromNotice,
  );

  /// Every install in flight, and its footer progress — see
  /// services/extensions/extension_installer.dart.
  late final ExtensionInstaller extensionInstaller = ExtensionInstaller(statusBar: statusBar);

  /// The update notice's Update all: the panel's own path, over the
  /// navigator — this sits above any screen that could lend a context.
  Future<void> _updateAllFromNotice(List<CatalogEntry> entries, Set<String> named) async {
    final context = navigatorKey.currentContext;
    if (context == null || !context.mounted) {
      debugPrint('[extensions] Update all pressed with no navigator to confirm it on');
      return;
    }
    await updateAllFromCatalog(context, services: this, entries: entries, named: named);
  }

  /// Decides whether this install is out of date and, if so, says it exactly
  /// once (services/staleness.dart ranks the three signals). Fed by [flags]
  /// after each refresh and re-checked on resume.
  late final StalenessService staleness = StalenessService(
    statusBar: statusBar,
    navigatorKey: navigatorKey,
    prefs: settings.prefs,
    updates: updates,
    onNoticeAction: handleNoticeAction,
  );

  /// Named option vocabularies for `options: "$name"` settings
  /// declarations (see settings/system_lists.dart).
  late final SystemLists systemLists = SystemLists();

  /// The declarative settings groups (docs in settings/settings_registry.dart)
  /// rendered by the Settings panel. Extension panels aren't registered
  /// here — that panel composes them from
  /// [ExtensionService.getSettingsPanels] at build time (the runtime boots
  /// asynchronously).
  late final SettingsRegistry settingsRegistry = SettingsRegistry()
    ..register(GeneralSettingsGroup(settings, extensions))
    ..register(LoggingSettingsGroup(settings))
    ..register(
      RadioSettingsGroup(
        settings,
        catServer: () => catServer,
        openCwKeyer: (context) => showCwMessagesDialog(context, this),
        openPhoneKeyer: (context) => showVoiceMessagesDialog(context, this),
        // A peer's radio counts: it is listed with the station's own, and a
        // phone driving one uses every CAT and keyer setting there is.
        hasTransceivers: () =>
            cat.nodes.any((node) => cat.typeFor(node)?.category == kCategoryTransceiver) || cat.radio1 is PeerRadio || peerRemoteRadios.all.isNotEmpty,
        inventory: () => Listenable.merge([cat, peerRemoteRadios]),
      ),
    )
    ..register(MapSettingsGroup(settings))
    ..register(PrivacySettingsGroup(settings))
    ..register(ExportsSettingsGroup(settings, extensions))
    ..register(SyncSettingsGroup(settings, onToggle: setSyncEnabled));

  /// One open Operation View's command context, for the ⌘K dialog: the
  /// operation as command hooks expect it, plus the logging panel's action
  /// dispatcher while one is mounted.
  ///
  /// These live on a STACK rather than in a single slot, because open
  /// operations nest — the palette can open operation B from inside operation
  /// A. A slot cleared on dispose leaves A silently context-less after B pops,
  /// even though A's logging panel is still mounted and visible; a stack
  /// simply reveals A's entry again. Entries are removed by identity, so the
  /// same operation opened twice is two independent entries.
  final List<OperationCommandContext> _operationStack = [];

  /// The front-most open operation, as the `{...operation.data, 'uuid': …}`
  /// map command hooks expect (the uuid is what lets them reach
  /// `ctx.getOperation` / `ctx.getQsos`; see `logging_controls.dart`'s
  /// `_operationDataForCommands`). Null wherever no operation is open: Home,
  /// Settings.
  ///
  /// The ⌘K command dialog reads this so operation-scoped commands (SEED,
  /// NOTE, SPOT) run against the open operation instead of coming back with
  /// their "needs an open operation" error. It exists because the operation is
  /// otherwise route-local state inside `OperationView`, which a global
  /// keyboard shortcut has no path to. When the app grows real multi-window
  /// support (docs/design/user-interface.md, "Future directions"), this
  /// becomes per-window rather than app-wide.
  Map<String, dynamic>? get currentOperationContext => _operationStack.isEmpty ? null : _operationStack.last.operation;

  /// The front-most logging panel's `CommandAction` dispatcher, or null when
  /// no operation is open.
  ///
  /// The QSO-scoped actions — `setVfo`, `addQso`, `updateQso`,
  /// `setCallField`, `sendSpots` — can only be applied by the widget that owns
  /// the in-progress QSO and its controllers. Without this a "20M" run from
  /// the ⌘K dialog interprets fine, returns `setVfo`, and then silently does
  /// nothing. Routing the whole batch through here instead makes a command
  /// from the palette behave exactly as if it had been typed into the call
  /// field — `LoggingControls`' dispatcher handles the app-scoped actions too.
  CommandActionsDispatcher? get currentCommandDispatch => _operationStack.isEmpty ? null : _operationStack.last.dispatch;

  /// The front-most open operation's stack entry, or null when none is open.
  ///
  /// How a `/qso` deep link reaches the operation the operator is already in
  /// rather than pushing a second copy of it. The whole entry, not just its
  /// `suggestQso`, because the caller also has to ask whether that operation
  /// is the visible route before deciding what to tell the operator. Same
  /// stack, same reasoning as [currentCommandDispatch].
  OperationCommandContext? get frontOperationContext => _operationStack.isEmpty ? null : _operationStack.last;

  /// Where a command action's message goes: the command bar that is running a
  /// command right now, on its own response line, rather than the status bar
  /// (see [runCommandAction]). Returns whether it could show it.
  ///
  /// A sink here rather than a parameter because a command bar does NOT
  /// dispatch most commands itself: with an operation open the whole action
  /// batch goes to the front-most logging panel ([currentCommandDispatch]),
  /// whose own handler is the one that ends up calling [runCommandAction]. So
  /// the message comes back through code the bar never touches, and this is
  /// the only thing they share.
  ///
  /// Set for the duration of ONE command's dispatch by `CommandEngine`, not
  /// for a bar's lifetime: every action's message arrives inside that awaited
  /// window, and a slot held open longer catches messages from commands typed
  /// somewhere else entirely — a SPOT started in the call field, answering
  /// seconds later on a palette that has since opened, blanking the card and
  /// dismissing itself over a command the operator never typed there.
  bool Function(String message, {bool failed})? commandResponseSink;

  /// Registers a newly opened Operation View and returns its entry, which the
  /// caller fills in as its operation loads and must pass back to
  /// [closeOperationContext] on dispose.
  OperationCommandContext openOperationContext(String uuid) {
    final entry = OperationCommandContext(uuid);
    _operationStack.add(entry);
    updatePeerSharing();
    return entry;
  }

  /// Removes [entry] by identity, so a disposing view can never take a
  /// still-live one's place with it.
  void closeOperationContext(OperationCommandContext entry) {
    _operationStack.remove(entry);
    updatePeerSharing();
  }

  /// Tells peer sync what to share: the front-most open operation while the
  /// master switch is on, nothing otherwise.
  ///
  /// Driven off [_operationStack] rather than hooked into OperationView's
  /// initState/dispose because the stack already gets nesting right — opening
  /// operation B from inside A and popping back reveals A again, where a
  /// dispose-clears-the-slot hook would have left A silently un-shared.
  ///
  /// Does NOT touch [peerService] while the feature has never been switched
  /// on, so an operator who does not use this never constructs it and never
  /// binds a socket. [_peerSyncTouched] latches once it has, so turning the
  /// switch back OFF still reaches the service to tear everything down.
  void updatePeerSharing() {
    // The experiment gate sits here rather than only on the settings panel:
    // this is the ONE path that starts discovery, binds a socket or opens a
    // link, so gating it means an install without the experiment is not
    // merely missing the UI — it is not on the network at all.
    final wanted = settings.experimentEnabled('p2p') /* stored key, see experiments.yaml */ && settings.peerSyncEnabled;
    // [_peerSyncTouched] latches so turning the experiment (or the switch)
    // back OFF still reaches the service to tear everything down, while an
    // install that never turned it on never constructs it at all.
    if (!wanted && !_peerSyncTouched) return;
    _peerSyncTouched = true;
    final front = _operationStack.isEmpty ? null : _operationStack.last.uuid;
    // Re-read every time: the name is editable and callsign-derived, so a
    // value captured once at construction goes stale on a rename or on the
    // first callsign the operator sets.
    peerService.localDeviceName = settings.peerDeviceName;
    // A hint for the Peers panel, and deliberately not what the picker
    // reads: it crosses once per session and names no radio, while
    // `catOffer` is live and does. Configuration rather than link state for
    // exactly that reason — read once at hello, "a rig is connected right
    // now" would say whatever happened to be true the moment the pair formed
    // and never correct itself.
    peerService.localCapabilities = () => [if (cat.nodes.any((node) => cat.typeFor(node)?.category == kCategoryTransceiver)) 'cat'];
    peerService.localAccountTag = () => peerAccountTag(settings);
    // A peer link is expected to come and go — a device carried out of
    // range, a park with no WiFi — so both edges are news the operator can
    // act on, and neither is an error. Keyed per device so two peers do not
    // overwrite each other's message, and both self-dismiss: the footer is
    // where the operator glances, not something they should have to tidy.
    peerService.onPeerConnectionChanged = (deviceId, deviceName, {required connected}) {
      statusBar.setMessage(
        key: 'peer:$deviceId',
        icon: connected ? 'lan-connect' : 'lan-disconnect',
        text: connected ? t.settings.peers.statusConnected(device: deviceName) : t.settings.peers.statusLost(device: deviceName),
        dismissAfter: StatusBarService.completedDismissDelay,
      );
    };
    // Touched for its side effect: the lazy field's construction is what
    // wires the ephemeral channel, and a session established before that
    // would drop its GPS snapshot into an unplugged callback.
    peerChannels;
    unawaited(peerService.setEnabled(wanted));
    unawaited(peerService.setBleEnabled(settings.peerBleEnabled));
    unawaited(peerService.setOpenOperation(front));

    // Screen sharing (HALO-369) rides on top of peer sharing: with no
    // session there is nothing to carry an offer, so it ends whenever peer
    // sharing does. Its gate sits HERE for the same reason p2p's does —
    // this is the one path that can leave a capture running, and an install
    // without the experiment must not hold a Screen Recording grant open.
    // The latch mirrors [_peerSyncTouched]: once the feature has been wanted
    // it stays reachable to be torn down. It does NOT keep [peerScreens]
    // unconstructed — the router builds it whenever the experiment is on,
    // and so does opening the Peers panel; the experiment is what gates the
    // native channel, not this.
    final wantsScreens = wanted && settings.experimentEnabled('remote') /* stored key, see experiments.yaml */ && settings.peerScreenShareEnabled;
    if (wantsScreens || _peerScreensTouched) {
      _peerScreensTouched = true;
      if (wantsScreens) {
        // Nothing else populates the OS source list, and what this device
        // OFFERS is that list intersected with what the operator picked — so
        // without this a relaunch announces nothing at all, however many
        // sources are still ticked, until someone opens the settings panel.
        unawaited(peerScreens.ensureSourcesFresh());
      } else {
        unawaited(peerScreens.stopAll());
      }
    }

    // With sharing off there is no block for this device and nothing true
    // left to say about anyone else's: every draft held was read against an
    // operation this device is no longer in. Reached through the same latch,
    // so switching OFF still tears down what switching on built.
    if (!wanted && settings.experimentEnabled('p2p') /* stored key, see experiments.yaml */ ) {
      peerDrafts.clearLocal();
      // And the numbers held: the panel stops asking this source the moment
      // sharing is off, so nothing else would ever let them go.
      serialClaims.releaseAll();
    }
  }

  bool _peerSyncTouched = false;
  bool _peerScreensTouched = false;

  /// Attaches (or detaches) a logging panel's dispatcher to the innermost open
  /// entry for [uuid]. Looked up rather than passed down so the logging panel
  /// needs nothing new beyond the services and operation it already has.
  void setCommandDispatchFor(String uuid, CommandActionsDispatcher? dispatch) {
    for (final entry in _operationStack.reversed) {
      if (entry.uuid == uuid) {
        entry.dispatch = dispatch;
        return;
      }
    }
  }

  /// Fires on DEVSPLASH (`handleCommandAction`'s `devSplash` case) —
  /// `_ReleaseOverlayGateState` listens for this to force-show the release
  /// overlay on demand, bypassing its normal once-per-version gate.
  final DevOverlayTrigger devSplashTrigger = DevOverlayTrigger();

  /// DEVONBOARD's counterpart: `_OnboardingGateState` listens for this to
  /// force-show the onboarding overlay, bypassing its callsign-undefined
  /// gate.
  final DevOverlayTrigger devOnboardTrigger = DevOverlayTrigger();

  /// DEVTESTER: `_TesterOverlayGateState` listens for this to force-show the
  /// tester overlay, bypassing its edition and last-seen-build gates.
  final DevOverlayTrigger devTesterTrigger = DevOverlayTrigger();

  /// The dirty-flag sync loop (DESIGN.md §4) — batching and bookkeeping stay
  /// here in Dart; only the network call crosses into the `ham2k-lofi`
  /// extension via `_syncTransportCall`.
  late final SyncEngine syncEngine = SyncEngine(
    operations: operations,
    qsos: qsos,
    transport: _syncTransportCall,
    settings: settings,
    log: debugPrint,
    onProgress: _showSyncProgress,
    onPushBacklog: wakeLock.onPushBacklog,
    onError: ErrorReportingService.report,
    onAuthError: _showSyncAuthNotice,
    // Sync doubles as the app's connectivity probe: it is the one request the
    // app makes on its own schedule whatever else is suspended, and its
    // success is what declares us back online. It is also the one
    // subsystem NOT suspended while offline, for the same reason — everything
    // else is waiting on it.
    onReachability: (reached) {
      ConnectivityService.reportProbe(reached: reached);
      ConnectivityService.reportService('sync', label: t.offline.syncService, reached: reached);
    },
    onProbeStopped: ConnectivityService.stopProbing,
    isTransportFailure: ErrorPolicy.isTransportFailure,
  );

  /// Status-bar item key for backfill progress; the Sync settings panel
  /// renders the same item inline (see `views/settings/sync_panel.dart`).
  static const syncProgressStatusKey = 'sync_backfill_progress';

  /// Stable key so a later rejection replaces rather than stacks, and a
  /// round that finally succeeds can clear it.
  static const syncAuthNoticeKey = 'sync:auth';

  /// Opens Settings at [panel] — how a notice's button reaches the screen that
  /// can act on what it reported.
  void openSettingsPanel(String panel) => navigatorKey.currentState?.push(
    MaterialPageRoute<void>(
      builder: (_) => SettingsView(services: this, initialPanel: panel),
    ),
  );

  /// The server has rejected this device's registration for several rounds
  /// running (SyncEngine's [SyncEngine.authErrorNotifyThreshold]) — not a
  /// transient blip, so it's worth surfacing. The likely fix is on the
  /// user's end (e.g. the callsign on file no longer matches the server's
  /// expected format), so the action opens Sync settings directly rather
  /// than just naming the problem.
  void _showSyncAuthNotice(String message, {int? status}) {
    statusBar.showNotice(
      key: syncAuthNoticeKey,
      icon: 'cloud-off',
      title: t.settings.syncPanel.authIssueTitle,
      text: t.settings.syncPanel.authIssueText,
      actions: [StatusBarAction(label: t.settings.syncPanel.openSettings, onTap: () => openSettingsPanel('sync'))],
    );
  }

  /// Surfaces backfill progress in the footer. Backfill can take a while on
  /// a large account (the server cooldown-gates fetch rounds), so without
  /// this the app looks idle while history is still arriving. Completion
  /// pushes the bar to 1.0, which StatusBarService auto-clears shortly
  /// after.
  void _showSyncProgress(SyncProgress progress) {
    wakeLock.onBackfillProgress(progress);
    final total = (progress.qsosTotal ?? 0) + (progress.operationsTotal ?? 0);
    if (!progress.backfilling) {
      // Only announce completion if progress was actually shown: a fresh
      // empty account completes backfill on its first round, and "history
      // downloaded" out of nowhere would just confuse.
      if (statusBar.items.any((item) => item.key == syncProgressStatusKey)) {
        statusBar.setProgress(key: syncProgressStatusKey, icon: 'cloud-sync', title: 'Sync', text: 'Account history downloaded', value: 1.0);
      }
      return;
    }
    if (total <= 0) return;
    final left = (progress.qsosLeft ?? 0) + (progress.operationsLeft ?? 0);
    final done = (total - left).clamp(0, total);
    final qsoTotal = progress.qsosTotal ?? 0;
    final qsoDone = (qsoTotal - (progress.qsosLeft ?? 0)).clamp(0, qsoTotal);
    statusBar.setProgress(
      key: syncProgressStatusKey,
      icon: 'cloud-sync',
      title: 'Syncing in progress…',
      text: qsoTotal > 0 ? '${formatNumber(qsoDone)} of ${formatNumber(qsoTotal)} QSOs' : '${formatNumber(done)} of ${formatNumber(total)} records',
      value: done / total,
    );
  }

  /// DEVHAMMER's status-bar churn (see StatusBarHammer).
  late final StatusBarHammer statusBarHammer = StatusBarHammer(statusBar);

  HaLoServices(
    this.db,
    this.settings, {
    ExtensionService? extensions,
    MetricsService? metrics,
    PurchaseService? purchases,
    UpdateService? updates,
    UpdateCheckService? updateCheck,
    DataFileManager? dataFiles,
    LookupQueueService? lookupQueue,
    ExportService? exports,
    CatService? cat,
    CatTrafficLog? catTrafficLog,
    PusherService? pusher,
    LocationService? location,
    InboundQsoListenerService? inboundQsos,
    PeerService? peerService,
    DeepLinkService? deepLinks,
    SiblingAppsService? siblingApps,
    CatalogService? catalog,
    FlagsService? flags,
  }) : _catOverride = cat,
       catTrafficLog = catTrafficLog ?? CatTrafficLog(),
       _catalogOverride = catalog,
       _flagsOverride = flags,
       _deepLinksOverride = deepLinks,
       _siblingAppsOverride = siblingApps,
       _peerServiceOverride = peerService,
       _inboundQsosOverride = inboundQsos,
       _locationOverride = location,
       _pusherOverride = pusher,
       extensions = extensions ?? ExtensionService(),
       metrics = metrics ?? const NoopMetricsService(),
       purchases = purchases ?? const NoopPurchaseService(),
       // Defaults to no-op so tests (which construct HaLoServices directly)
       // never touch the Shorebird FFI; bootstrap() injects the real
       // ShorebirdUpdateService for the running app.
       updates = updates ?? const NoopUpdateService(),
       // Defaults to the web-only build-SHA check; app_dist's main_dist.dart
       // injects a real Shorebird+Sparkle-aware implementation (see
       // update_check_service.dart).
       updateCheck = updateCheck ?? const WebFreshnessUpdateCheckService(),
       _dataFilesOverride = dataFiles,
       _lookupQueueOverride = lookupQueue,
       // A widget test of the Exports panel can't use the real one: its
       // option listing awaits a drift stream's `.first`, which never
       // resolves under `testWidgets` (see operation_export_panel_test).
       _exportsOverride = exports {
    _wireExtensions();
    // Time travel is developer-mode-only, and this is the ONE place that can
    // see developer mode go off no matter which surface turned it off (DEVMODE,
    // the Settings toggle, a settings command). Leaving the clock travelled
    // after it goes off would strand a non-developer app on a fake clock with
    // no visible way back.
    settings.addListener(_enforceTimeTravelGate);
    // Same reasoning, and the same one place: a Number Formatting change can
    // arrive from the Settings picker or from a settings command, and every
    // package reads the answer out of one process-wide singleton. Applied
    // here at construction too, so the very first frame formats correctly
    // rather than repainting once the listener happens to fire.
    //
    // The listener is enough on its own: a settings listener only marks the
    // tree dirty, so the rebuild happens on the NEXT frame and the singleton
    // is already updated whichever order the listeners ran in.
    settings.addListener(_applyNumberFormatting);
    _applyNumberFormatting();
  }

  /// Hands the extension service everything it reaches back through.
  ///
  /// A METHOD, not a stretch of the constructor body, and that is the whole
  /// point: several of these fields have a same-named constructor parameter
  /// holding the test override, which is null in every production build and
  /// shadows the field inside the constructor. Wiring one of those up from
  /// there silently hands over the null — nothing reaches the service, and
  /// the feature behind it simply never happens. Parameters are out of scope
  /// here, so every bare name below is the field.
  void _wireExtensions() {
    extensions.settings = settings;
    extensions.lookups = lookups;
    extensions.statusBar = statusBar;
    extensions.operations = operations;
    extensions.qsos = qsos;
    extensions.location = location;
    extensions.radioCalls.radio = panelRadio;
    extensions.spots = spots;
    extensions.catalog = catalog;
    extensions.onOpenAccount = (key, {subkey}) => unawaited(showAccountDialogByKey(this, key, subkey: subkey));
    extensions.onSearchSettings = (args, kind) => searchSettingsForCommand(this, args: args, kind: kind);
  }

  /// Resolves the operator's Number Formatting choice into the two characters
  /// [NumberFormatting] hands to every package.
  ///
  /// Runs at construction and on every settings change. NOT on a device
  /// region change while the app is running — nothing observes
  /// `didChangeLocales`, so under [NumberFormatStyle.locale] that is picked
  /// up at the next launch.
  ///
  /// halo_core is pure Dart and cannot do this itself — it has neither the
  /// device locale nor ICU. The explicit choices are spelled out rather than
  /// looked up: "period" and "comma" ARE definitions, and routing them
  /// through a locale would make them depend on that locale's data being
  /// bundled. Only [NumberFormatStyle.locale] asks intl anything.
  void _applyNumberFormatting() {
    switch (settings.numberFormatStyle) {
      case NumberFormatStyle.period:
        NumberFormatting.instance.configure(decimal: '.', grouping: ',', locale: 'en_US');
      case NumberFormatStyle.comma:
        // de_DE only for intl's benefit — formatNumber groups through it, and
        // grouping is not every three digits everywhere.
        NumberFormatting.instance.configure(decimal: ',', grouping: '.', locale: 'de_DE');
      case NumberFormatStyle.locale:
        final tag = dart_ui.PlatformDispatcher.instance.locale.toString();
        NumberSymbols? symbols;
        try {
          symbols = NumberFormat.decimalPattern(tag).symbols;
        } catch (e, stack) {
          // intl has no symbols for this tag — `verifiedLocale` throws rather
          // than degrading, so this branch is reachable on a real device (it
          // ships 313 locales; `mi`, `ceb`, `tt`, `ba`, `sah` are not among
          // them). `catch`, NOT `on Exception`: what it throws is an
          // ArgumentError, which is an Error — an `on Exception` clause here
          // catches nothing at all and the throw escapes the HaLoServices
          // constructor on the way to the first frame.
          //
          // Reported as well as logged. Falling back is the right behaviour
          // (this runs on the way to the first frame, and US conventions beat
          // a crash), but an operator who silently gets the wrong separators
          // has no way to tell that from the setting simply working — and
          // neither would we.
          debugPrint('[numberFormatting] no number symbols for "$tag", using US conventions: $e');
          ErrorReportingService.report(e, stack, context: 'settings:numberFormat:$tag');
        }
        // Outside the try, so its own rejection is never mistaken for a
        // missing locale. A locale that groups with a non-breaking space
        // (fr, ru) keeps it: coercing that to a comma would contradict what
        // the device shows everywhere else.
        final applied = symbols != null && NumberFormatting.instance.configure(decimal: symbols.DECIMAL_SEP, grouping: symbols.GROUP_SEP, locale: tag);
        if (!applied) {
          NumberFormatting.instance.configure(decimal: '.', grouping: ',', locale: 'en_US');
        }
    }
  }

  StreamSubscription<List<Operation>>? _receivedPurgesSub;

  /// Test Operations purged on another device only tombstone here on
  /// receipt (`OperationsRepository.mergeFromPeer`/`mergeFromSync` — in
  /// practice from a peer, since LoFi removes a purge rather than relaying
  /// it) — this is what turns
  /// that into an actual prompt to remove them for real, once the operator
  /// says so. Reactive rather than tied to a specific sync callback: it
  /// fires on the app's own boot (a leftover from before this device was
  /// last open) just as readily as on a live sync round.
  ///
  /// NOT started from the constructor: a `HaLoServices` built for a widget
  /// test never calls this, same as `syncEngine.start()` — a live drift
  /// stream subscription that outlives the test's `pumpAndSettle` is exactly
  /// the trap `operation_export_panel_test.dart`'s own doc comment warns
  /// about, and this app-wide watch would otherwise hang every single test
  /// that constructs `HaLoServices`, not just the one that needs a real
  /// stream. The real app calls this once, from `bootstrap()`, alongside
  /// `syncEngine.start()`.
  void watchReceivedTestOperationPurges() {
    _receivedPurgesSub ??= operations.watchReceivedPurgesPending().listen(_onReceivedPurgesPending);
  }

  static const _receivedPurgesNoticeKey = 'testOperations:receivedPurges';

  /// The uuid set the notice currently reflects, so a `watch()` re-emission
  /// with the SAME pending operations (any unrelated write to `operations`
  /// re-fires the stream, not just a change to this query's result) doesn't
  /// re-show the notice and silently undo an operator's dismissal of it.
  Set<String> _lastReceivedPurgesShown = const {};

  void _onReceivedPurgesPending(List<Operation> pending) {
    final uuids = pending.map((op) => op.uuid).toSet();
    if (uuids.isEmpty) {
      _lastReceivedPurgesShown = const {};
      statusBar.dismissNotice(_receivedPurgesNoticeKey);
      return;
    }
    if (setEquals(uuids, _lastReceivedPurgesShown)) return;
    _lastReceivedPurgesShown = uuids;
    statusBar.showNotice(
      key: _receivedPurgesNoticeKey,
      icon: 'flask-outline',
      text: t.commands.receivedPurgesPending(count: pending.length),
      // Not persisted: `StatusBarNotice.persist`'s own doc says why — its
      // actions can't survive a restart, so a persisted copy would come
      // back forever as a dead husk with no working Review button once
      // this session ends.
      persist: false,
      actions: [StatusBarAction(label: t.commands.receivedPurgesReview, onTap: () => _confirmReceivedPurgesFromNotice(pending))],
    );
  }

  /// `pending` is a snapshot from when the notice was built; the dialog
  /// itself only asks the operator, and `confirmReceivedTestOperationPurges`
  /// re-validates every uuid against the database before deleting anything
  /// — see its own doc for why that matters (the callsign-edit escape
  /// hatch racing this).
  void _confirmReceivedPurgesFromNotice(List<Operation> pending) {
    statusBar.dismissNotice(_receivedPurgesNoticeKey);
    final context = navigatorKey.currentContext;
    if (context == null) {
      // Only reachable by tapping the status-bar action with no navigator up
      // at all — logged so "I tapped Review and nothing happened" has a
      // trail, matching `_openConfirmDevicePane`'s (deep_link_router.dart) treatment of the same gap.
      debugPrint('[testOperations] receivedPurges review dropped: no navigator context');
      return;
    }
    // Nothing below this line has run yet, so re-showing here is always
    // correct: `pending` is exactly what's still on the database whenever
    // this fires before a genuine removal.
    void reArmNotice() {
      _lastReceivedPurgesShown = const {};
      _onReceivedPurgesPending(pending);
    }

    unawaited(
      confirmReceivedTestOperationPurgesDialog(context, pending).then((confirmed) async {
        if (confirmed != true) {
          // The dismiss above already ran; without this, cancelling — the
          // common case, an operator tapping Review to look and backing out —
          // leaves the notice gone for the rest of the session, same as an
          // unhandled throw would.
          reArmNotice();
          return;
        }
        try {
          final result = await confirmReceivedTestOperationPurges(pending.map((op) => op.uuid));
          // Against `eligible`, not `pending.length`: some of `pending` can be
          // legitimately gone already (the callsign-edit escape hatch fired
          // between listing and confirming) without anything having failed.
          final text = result.removed == result.eligible
              ? t.commands.testOperationsPurged(count: result.removed)
              : t.commands.receivedPurgesSomeFailed(removed: result.removed, total: result.eligible);
          statusBar.setMessage(key: 'commandAction', text: text);
        } catch (e, st) {
          // `eligibleReceivedPurges` itself failing (not one of the per-uuid
          // deletes, which `confirmReceivedTestOperationPurges` already
          // isolates) — nothing was removed, so `pending` is still exactly
          // accurate.
          ErrorReportingService.report(e, st, context: 'confirmReceivedPurgesFromNotice');
          reArmNotice();
          statusBar.setMessage(key: 'commandAction', text: t.commands.receivedPurgesFailed);
        }
      }),
    );
  }

  void _enforceTimeTravelGate() {
    if (!AppClock.instance.isTravelling || settings.developerMode) return;
    // Said out loud: every clock, QSO default and spot age in the app jumps, and
    // the only visible cause is a developer-mode toggle several screens away.
    final was = AppClock.instance.travelLabel;
    statusBar.showNotice(
      key: 'clock:timeTravelEnded',
      icon: 'clock-check',
      title: 'Back to real time',
      text: 'Leaving developer mode ended time travel${was == null ? '' : ' ($was)'}.',
      persist: false,
    );
    // Guarded, not bare `unawaited`: the clock is reset FIRST inside, so a throw
    // later in the sequence (the status item, the heartbeat, restarting sync)
    // would otherwise surface only as an unhandled async error and leave the
    // chip on screen over a clock that is no longer travelling.
    unawaited(
      _endTimeTravel().catchError((Object e, StackTrace stack) {
        ErrorReportingService.report(e, stack, context: 'clock:end-time-travel');
      }),
    );
  }

  /// The ONE gate for analytics: forwards to
  /// [metrics] only while the user's "Share app usage data" consent is on.
  /// Every instrumentation site calls this — never metrics.logEvent
  /// directly — so consent is checked live at each event, and turning the
  /// setting off silences tracking immediately. Event names and property
  /// keys follow app-polo's set (docs/design/telemetry.md).
  void track(String event, [Map<String, Object?> properties = const {}]) {
    if (!settings.consentAppData) return;
    metrics.logEvent(event, properties: properties);
  }

  /// Uploads what a radio was configured with, the first time it proves it
  /// can read a frequency and a mode (docs/design/telemetry.md § Radios).
  ///
  /// Why this and not the `radio_connected` event beside it: that one is a
  /// count. It says a pairing reached `connected`, which a rig that holds a
  /// session and answers nothing also does — and it carries the catalogue key
  /// only, so it can never say WHICH port, speed or CI-V address got a
  /// generic driver talking. That is the whole question the catalogue's
  /// defaults are guessing at.
  ///
  /// Three gates, all of them deliberate:
  ///
  ///  * `consentAppData`, checked live here rather than at startup, exactly as
  ///    [track] checks it — this ships the radio's configuration, including a
  ///    USB adapter's serial number, and an operator who turns the setting off
  ///    has turned this off with it.
  ///  * a persisted mark per radio AND per configuration (radio_proof.dart),
  ///    so this is not a per-launch upload — and so that changing a port or a
  ///    baud rate to get a rig talking re-arms it, that change being the most
  ///    useful thing an operator could tell us.
  ///  * [ErrorReportingService.reportingEnabled], since an OSS build has no
  ///    backend to send to and would otherwise write a mark for a report that
  ///    never left.
  ///
  /// Best-effort throughout. A radio that works is the news; a report about it
  /// that fails is not worth a notice, and never worth the connection.
  void reportWorkingRadio(EquipmentNode node) {
    if (!settings.consentAppData || !ErrorReportingService.reportingEnabled) return;
    unawaited(() async {
      try {
        if (isRadioProven(settings.prefs, node, cat.registry)) return;
        final type = cat.registry.typeFor(node.typeKey);
        if (type == null) return;
        // ANDROID lists its ports through a MethodChannel round-trip, cached
        // by this hook and by nothing else — and a radio reconnected at boot
        // never opens the equipment editor that normally calls it. Without
        // this the body reads "not among the 0 port(s) the app can see", and
        // the mark written below makes that the only report this
        // configuration ever sends.
        await type.transport.prepareConfigElements();
        final lines = equipmentSetupLines(node: node, type: type, state: cat.stateFor(node.uuid), registry: cat.registry);
        // Titled by the pairing, so Sentry groups every operator's IC-705 on
        // one issue and the bodies underneath are the shack-by-shack detail.
        // The node's own name stays OUT of the title for the same reason: an
        // operator's label for their rig would mint an issue per shack.
        if (!ErrorReportingService.diagnostic(title: 'Radio working: ${type.key}', body: lines.join('\n'))) {
          // The backend refused it, so nothing was reported: leaving the mark
          // unwritten is what lets the next launch try again.
          return;
        }
        await markRadioProven(settings.prefs, node, cat.registry);
      } catch (e, st) {
        ErrorReportingService.report(e, st, context: 'cat:report-working-radio');
      }
    }());
  }

  /// Sets the sync device identity + operator callsign in one call. Writes
  /// to the default profile — the
  /// Callsign settings panel edits that one; sync follows the ACTIVE
  /// profile's callsign (the same profile until multi-profile lands).
  Future<void> setOperatorCall(String call) async {
    await settings.setProfileOperatorCall(SettingsService.defaultProfileId, call);
    final deviceKey = await settings.ensureSyncDeviceKey();
    if (deviceKey != null) {
      await extensions.setSyncCredentials(deviceKey: deviceKey, operatorCall: settings.activeProfile.operatorCall);
      // Independent of QSO sync being enabled — see connectLofiRealtime's
      // doc comment. Not awaited, same reasoning as the flags
      // refresh below.
      unawaited(connectLofiRealtime());
    }
    // Flags are callsign-specific — refresh them (a no-op if the callsign
    // didn't actually change). Not awaited: the callsign edit shouldn't block
    // on a network round-trip.
    unawaited(flags.refreshForCall(settings.activeProfile.operatorCall));
  }

  /// The status bar's key for the time-travel indicator — public so the widget
  /// test can find the item rather than matching on its text.
  static const timeTravelStatusKey = 'clock:timeTravel';

  /// A run in flight. DEVBENCH yields to the event loop on every contact, so
  /// the palette stays usable and a second run can be started on top of the
  /// first — two Test Operations interleaving their inserts and rescores
  /// through one database, each timing the other's load, which corrupts the
  /// slope this tool exists to report. They also share the `devbench` status
  /// key, so whichever finishes first clears the other's progress. DEVHAMMER
  /// guards the same way for the same reason.
  bool _benchmarking = false;

  /// How often the DEVBENCH progress bar advances, in contacts. The bench runs
  /// on the UI isolate, so every repaint is time the run is not measuring the
  /// thing it exists to measure — and at the default 100-QSO size a per-contact
  /// bar would be pure overhead for a run that finishes in a second anyway.
  static const _benchProgressEvery = 100;

  /// DEVBENCH: log a synthetic contest into a throwaway Test Operation and
  /// report what each phase cost as the log grew (HALO-119).
  ///
  /// The developer-mode gate is re-checked here rather than trusted from the
  /// command hook. The hook's own check keeps the command from existing for an
  /// ordinary operator, but this writes thousands of contacts and purges an
  /// operation, and a gate that matters does not live only in the sandbox —
  /// the same reasoning as [_travelTime]'s.
  Future<CommandActionOutcome?> _runContestBench(Map<String, dynamic>? params) async {
    if (!settings.developerMode) {
      return (text: 'DEVBENCH needs developer mode', failed: true);
    }
    if (_benchmarking) return (text: 'A benchmark is already running', failed: true);

    // Read defensively and BEFORE the flag is raised. A command action is raw
    // JSON from any hook, template or third-party extension — the SDK's
    // `qsoCount?: number` is a compile-time claim, not a runtime one — so a
    // string here would throw a cast error, and anything that throws between
    // raising the flag and entering the try leaves it raised for the session,
    // refusing every later run.
    //
    // Clamped rather than trusted for the same reason: a zero would run no
    // contacts, close no bands, and hand the report an "expected growth" of
    // -1.0x, nonsense carrying the confidence of a measurement.
    final requested = params?['qsoCount'];
    final qsoCount = (requested is num ? requested.toInt() : 100).clamp(1, 20000);

    _benchmarking = true;

    // A determinate bar from the start: a run of a few thousand contacts takes
    // long enough that an operator with no feedback has no way to tell it from
    // a hang. Updated every `_benchProgressEvery` contacts rather than every
    // one — repainting the bar per contact would have the bench measuring the
    // repaints as much as the work.
    statusBar.setProgress(key: 'devbench', icon: 'speedometer', title: 'Benchmarking', text: '0 of $qsoCount QSOs', value: 0);
    try {
      final result = await runContestBench(
        qsos: qsos,
        operations: operations,
        extensions: extensions,
        scoring: scoring,
        qsoCount: qsoCount,
        purge: purgeOperation,
        onProgress: (done, total) {
          if (done % _benchProgressEvery != 0 && done != total) return;
          statusBar.setProgress(key: 'devbench', icon: 'speedometer', title: 'Benchmarking', text: '$done of $total QSOs', value: done / total);
        },
      );

      // On screen: the notice card renders markdown tables, so the operator
      // gets the shape rather than a number they would have to trust. Not
      // persisted, because the copy action is the point and an action cannot
      // survive into notice history.
      statusBar.showNotice(
        key: 'devbench:result',
        icon: 'speedometer',
        title: 'Benchmark: $qsoCount QSOs',
        text: result.markdownSummary,
        persist: false,
        actions: [
          StatusBarAction(
            label: 'Copy details',
            onTap: () => unawaited(Clipboard.setData(ClipboardData(text: result.plainReport))),
          ),
        ],
      );

      // And a copy off the device, so a slow phone's numbers can be read
      // without the phone. Not an exception: nothing went wrong, and the
      // reporting backend keeps this out of the crash stream.
      final uploaded = ErrorReportingService.diagnostic(title: 'DEVBENCH', body: result.plainReport);

      // A build with no reporting backend keeps the numbers on the device, and
      // an operator told nothing would reasonably believe they are retrievable
      // from it. DEVSENTRY draws the same distinction.
      //
      // It cannot promise the upload LANDED. The Sentry backend fires its
      // capture unawaited, so `uploaded` only catches a backend that throws
      // synchronously, and `reportingEnabled` stays true even when that
      // backend's own init failed. Copy details is the answer to both, which
      // is why the notice carries it.
      final sent = uploaded && ErrorReportingService.reportingEnabled ? '' : ' (local only)';
      return (text: '${result.headline}$sent', failed: false);
    } on BenchCleanupFailed catch (error, stackTrace) {
      // The one outcome that leaves the log dirty, so it says so instead of
      // being reported as an ordinary failure.
      ErrorReportingService.report(error, stackTrace, context: 'devbench:cleanup');
      return (text: 'Benchmark left its test operation behind — run PURGETESTS to remove it', failed: true);
    } on BenchNotConfigured catch (error) {
      // The operator's to fix, so it is NOT reported: an unconfigured run is
      // not a defect, and uploading it would put it in the crash stream.
      return (text: '$error', failed: true);
    } catch (error, stackTrace) {
      ErrorReportingService.report(error, stackTrace, context: 'devbench');
      return (text: 'Benchmark failed: $error', failed: true);
    } finally {
      _benchmarking = false;
      statusBar.clear('devbench');
    }
  }

  /// DEVTT: moves the app clock (docs/design/time.md).
  ///
  /// Both gates live here rather than in the command hook, because neither the
  /// sync account nor developer mode is visible from inside the extension
  /// sandbox — and because the sync account gate is the one thing in this
  /// feature that protects real user data, so it belongs where it cannot be
  /// bypassed by a different caller of the action.
  Future<CommandActionOutcome?> _travelTime(Map<String, dynamic>? params) async {
    if (params?['reset'] == true) {
      if (!AppClock.instance.isTravelling) return (text: 'The clock is already on real time', failed: false);
      await _endTimeTravel();
      return (text: 'Back to real time', failed: false);
    }

    if (!settings.developerMode) {
      return (text: 'Time travel needs developer mode', failed: true);
    }

    // Deliberately no sync-account gate: what the account is called says
    // nothing about what this session can damage, because `WritePolicy` admits
    // only test data while the clock is travelled. Keying on the account would
    // also mean reading `syncState['accountData']`, a cache refreshed only when
    // the operator opens Settings › Sync — a check that fails closed on absence
    // but open on staleness, which is the wrong way round for anything standing
    // between a dev tool and somebody's real log.

    // Applied BEFORE anything is changed on its behalf: `travel` refuses an
    // out-of-range offset or speed, and a refusal that had already switched
    // something off would leave that thing off with no travel to undo.
    final deltaMillis = (params?['deltaMillis'] as num?)?.toInt() ?? 0;
    final speed = (params?['speed'] as num?)?.toDouble();
    ClockListenerException? notFollowed;
    try {
      AppClock.instance.travel(
        delta: Duration(milliseconds: deltaMillis),
        speed: speed,
      );
    } on ArgumentError catch (e) {
      // Validation, which runs before any mutation: nothing moved.
      return (text: 'Time travel refused: ${e.message}', failed: true);
    } on ClockListenerException catch (e, stack) {
      // A listener threw (the sandbox push, the UI heartbeat). The clock HAS
      // moved — so everything below still has to happen, most of all the status
      // indicator: a travelled clock nobody can see is the one failure
      // docs/design/time.md §4 says must not be possible. Only the report at the
      // end differs.
      ErrorReportingService.report(e.cause, stack, context: 'clock:travel-listener');
      notFollowed = e;
    }

    // Nothing to switch off: SyncEngine's own `_mayRun` check now refuses every
    // path while the clock is travelled, including a round already on a timer.

    // Subscribing here rather than at construction: WallClock arms no timer
    // until something listens, so an app that never travels pays nothing.
    if (!_travelStatusTicking) {
      _travelStatusTicking = true;
      WallClock.seconds.addListener(_refreshTimeTravelStatus);
    }
    _refreshTimeTravelStatus();
    final now = 'Clock now ${_utcStamp(nowUtc())}${_travelSuffix()}';
    if (notFollowed != null) {
      return (text: '$now — but ${notFollowed.cause}', failed: true);
    }
    return (text: now, failed: false);
  }

  bool _travelStatusTicking = false;

  /// What the status item last said, so an unchanged label costs nothing.
  String? _travelStatusText;

  /// Keeps the status-bar item showing how far the clock is from real time and
  /// how fast it is running.
  ///
  /// Re-read once per second rather than posted once, because the offset GROWS:
  /// `DEVTT 100x` sets no offset at all, and a snapshot would sit at "at 100x"
  /// for the whole session while the clock ran days ahead. Posting only on a
  /// CHANGE is what keeps that affordable — every post notifies the whole
  /// status bar, and at 1x with a fixed offset the label never changes, so an
  /// ordinary travelled session is silent after the first one.
  void _refreshTimeTravelStatus() {
    final label = AppClock.instance.liveTravelLabel;
    if (label == _travelStatusText) return;
    _travelStatusText = label;
    if (label == null) {
      statusBar.clear(timeTravelStatusKey);
      return;
    }
    statusBar.setMessage(
      key: timeTravelStatusKey,
      icon: 'clock-fast',
      // Everything in the TITLE, with no separate `text`. The collapsed footer
      // — the always-visible one — renders `title ?? text`, so a title of
      // "Time travel" with the offset in `text` reads as a bare "Time travel"
      // until someone expands the bar, which is the one place this item must not
      // need. Phrased to read as one line: "Time travel +5m at 100x",
      // "Time travel at 100x", "Time travel +2h".
      title: 'Time travel $label',
    );
  }

  /// Returns to real time and undoes everything travel imposed.
  Future<void> _endTimeTravel() async {
    try {
      AppClock.instance.reset();
    } on ClockListenerException catch (e, stack) {
      // The clock IS back on real time — reset mutates before notifying — so
      // everything below still has to run, exactly as on the travel path. Left
      // to propagate, it would strand the status item on screen over an
      // untravelled clock and never restart sync.
      ErrorReportingService.report(e.cause, stack, context: 'clock:end-travel-listener');
    }
    if (_travelStatusTicking) {
      _travelStatusTicking = false;
      WallClock.seconds.removeListener(_refreshTimeTravelStatus);
    }
    _travelStatusText = null;
    statusBar.clear(timeTravelStatusKey);
    // The engine stopped rescheduling itself while travelling, so nothing would
    // pick it up again on its own.
    syncEngine.start();
    watchReceivedTestOperationPurges();
  }

  String _travelSuffix() {
    final label = AppClock.instance.travelLabel;
    return label == null ? '' : ' ($label)';
  }

  /// `2026-08-11 14:03z` — a UTC stamp to the minute, which is the precision a
  /// logger's operator thinks in.
  static String _utcStamp(DateTime utc) => '${utc.toIso8601String().substring(0, 16).replaceFirst('T', ' ')}z';

  /// Returns false when the request was REFUSED — callers must not report or
  /// record a change that did not happen (see `_toggleSync`, which would
  /// otherwise fire a `sync_enabled` analytics event and install an account
  /// watcher for a sync that is off).
  Future<bool> setSyncEnabled(bool enabled) async {
    await settings.setSyncEnabled(enabled);
    if (!enabled) return true;
    // Boot skips credential setup when the keyring is locked
    // (ensureSyncDeviceKey returns null), so starting the engine now without a
    // device key would run sync unauthenticated. If boot never established the
    // key, re-attempt here (a null result isn't cached, so this retries secure
    // storage) and only start once we actually have credentials.
    if (settings.syncDeviceKey == null) {
      final deviceKey = await settings.ensureSyncDeviceKey();
      if (deviceKey == null) {
        debugPrint('[sync] enabled but secure storage is unavailable — not starting sync');
        // The SETTING is on (written above, and the no-keyring banner explains
        // itself); only the engine could not start. Not a refusal.
        return true;
      }
      await extensions.setSyncCredentials(deviceKey: deviceKey, operatorCall: settings.activeProfile.operatorCall);
      unawaited(connectLofiRealtime());
    }
    syncEngine.start();
    watchReceivedTestOperationPurges();
    return true;
  }

  /// Handles a named command action from the call field — the `dev-commands`
  /// extension's DEVNOTICE/DEVSTATUS/DEVPROGRESS/RELOAD and friends.
  /// (`SYNCALL` and PURGETESTS are intercepted in [runCommandAction] instead:
  /// both must confirm with the operator before doing anything irreversible,
  /// which needs a BuildContext this switch deliberately runs without.)
  /// Returns a message for the caller to show in a SnackBar, or null for
  /// nothing — the dev-command cases return null since their `confirm` text
  /// already shows in the call field, and the status bar item itself is the
  /// visible result.
  Future<CommandActionOutcome?> handleCommandAction(String action, [Map<String, dynamic>? params]) async {
    track('command_executed', {'command': action});
    switch (action) {
      case 'reloadDataFiles':
        final p = params ?? const {};
        final target = (p['target'] as String?)?.toUpperCase();
        if (target == null) return null;
        // Downloading + reprocessing can take a while (tens of thousands
        // of CSV rows through the extension bridge) — don't block the
        // call-field's command flow on it. Each matched data file already
        // reports its own transient progress/completion in the status bar
        // (see DataFileManager), so no separate summary is shown here.
        unawaited(
          dataFiles
              .syncAllDataFiles(force: true, categoryFilter: target == 'ALL' ? null : target)
              .then((matched) {
                if (matched == 0) {
                  statusBar.setProgress(
                    key: 'command:reloadDataFiles',
                    text: t.commands.noDataFilesMatched(target: target),
                    value: 1.0,
                  );
                }
              })
              .catchError((Object e) {
                // Belt-and-suspenders: syncAllDataFiles already isolates each data
                // file's own errors, but this still needs to fail loud (not just
                // silently drop the failure) for anything unexpected that slips
                // past that per-entry try/catch.
                debugPrint('[data-file] reloadDataFiles failed: $e');
                statusBar.setProgress(
                  key: 'command:reloadDataFiles',
                  text: t.commands.reloadFailed(error: e),
                  value: 1.0,
                );
              }),
        );
        return (text: target == 'ALL' ? t.commands.reloadingAll : t.commands.reloadingTarget(target: target), failed: false);
      case 'devNotice':
        final p = params ?? const {};
        final devNoticeKey =
            p['key'] as String? ??
            // Real: a uniqueness token, and a clock moved BACKWARD can hand back
            // an instant already used — replacing an unrelated notice instead of
            // adding one, from the command whose job is testing notices.
            'devNotice-${realNowUtc().microsecondsSinceEpoch}';
        statusBar.showNotice(
          key: 'command:devNotice:$devNoticeKey',
          icon: p['icon'] as String?,
          title: p['title'] as String?,
          text: p['text'] as String? ?? '',
        );
        return null;
      case 'devStatus':
        final p = params ?? const {};
        final devStatusKey = p['key'] as String? ?? 'devStatus';
        statusBar.setMessage(key: 'command:devStatus:$devStatusKey', icon: p['icon'] as String?, title: p['title'] as String?, text: p['text'] as String?);
        return null;
      case 'devProgress':
        final p = params ?? const {};
        final percent = p['percent'] as num?;
        statusBar.setProgress(
          key: 'command:devProgress',
          icon: p['icon'] as String?,
          title: p['title'] as String?,
          value: percent == null ? null : percent.toDouble() / 100,
        );
        return null;
      case 'devHammer':
        // Normally no text of our own — the extension's `confirm` says it, in
        // English, like every other dev command's (dev-commands carries no
        // i18n). The exception is a run already in flight: the confirmation is
        // printed before this returns, so staying quiet would tell the tester
        // it is hammering while nothing happens — and a tester who sees no
        // churn concludes the churn stopped provoking the bug.
        if (statusBarHammer.running) return (text: 'DEVHAMMER is already running', failed: true);
        unawaited(statusBarHammer.run((params?['seconds'] as num?)?.toInt() ?? StatusBarHammer.defaultSeconds));
        return null;
      case 'devSplash':
        devSplashTrigger.trigger();
        return null;
      case 'devOnboard':
        devOnboardTrigger.trigger();
        return null;
      case 'devTester':
        devTesterTrigger.trigger();
        return null;
      case 'devTimeTravel':
        return _travelTime(params);
      case 'devPopup':
        if (!kIsWeb) return (text: 'DEVPOPUP is web-only', failed: true);
        return openPopupWindow() ? (text: 'Opened in a standalone window', failed: false) : (text: 'Popup blocked — allow popups for this site', failed: true);
      case 'devSentry':
        // DEVSENTRY [message]: push a synthetic error through the real
        // reporting pipeline to verify the Sentry wiring end to end.
        // Deliberately report(), not throw — the point is testing upload
        // + feedback, not exercising the error UI (DEVNOTICE covers that).
        final message = (params?['message'] as String? ?? 'test message').trim();
        ErrorReportingService.report(StateError('DEVSENTRY: $message'), StackTrace.current, context: 'devsentry');
        return (text: ErrorReportingService.reportingEnabled ? t.commands.sentryTestSent : t.commands.sentryTestLocalOnly, failed: false);
      case 'devBench':
        return _runContestBench(params);
      case 'devLogCat':
        return catTraffic.toggle();
      case 'devMapInfo':
        final show = !settings.devMapInfo;
        await settings.setDevMapInfo(show);
        return (text: show ? 'Maps show their zoom and viewport size' : 'Map info hidden', failed: false);
      case 'sendSpots':
        return _sendSpot(params ?? const {});
      case 'toggleExperiment':
        // EXP <key-or-alias>: the command hook only parsed; resolving the
        // token against the catalog and flipping the stored state happens
        // here, and the returned message is the user's only feedback.
        final token = (params?['token'] as String? ?? '').trim();
        if (token.isEmpty) return null;
        final experiment = findExperiment(await loadExperiments(), token);
        if (experiment == null) {
          return (text: t.commands.unknownExperiment(token: token.toUpperCase()), failed: true);
        }
        final enabled = !settings.experimentEnabled(experiment.key);
        await settings.setExperimentEnabled(experiment.key, enabled);
        // The availability pass may restart the extension runtime (an
        // experiment revealing or hiding gated extensions) — don't hold
        // the command's feedback on it.
        unawaited(extensions.applyExtensionAvailability());
        return (text: enabled ? t.commands.experimentEnabled(name: experiment.name) : t.commands.experimentDisabled(name: experiment.name), failed: false);
      case 'updateSetting':
        // SET/SHOW/HIDE: the hook already resolved the key and coerced the
        // value through `searchSettings`, so this only writes. Returns null on
        // success — the hook's own `confirm` is the user's feedback; a message
        // here would be a second one saying the same thing. A non-null return
        // is therefore always a failure the hook couldn't have known about
        // (an extension field's validator rejecting the value).
        final settingKey = params?['key'] as String?;
        if (settingKey == null || settingKey.isEmpty) return null;
        final rejected = await applySettingCommand(this, key: settingKey, value: params?['value']);
        return rejected == null ? null : (text: rejected, failed: true);
      case 'updateSettings':
        // DEVMODE typed into the call field. The ⌘K dialog's engine writes the
        // same key itself; the panel forwards it here, holding no settings
        // engine of its own. Null: the command's own confirm is the feedback.
        if (params?['developerMode'] case final bool on) await settings.setDeveloperMode(on);
        return null;
      case 'updateOperation':
        return _updateOperation(params ?? const {});
      case 'markSegment':
        return _markSegment(params ?? const {});
      case 'setPower':
        // POWER command (e.g. "5W" typed into the call field): the same
        // write the Station Configuration Power field and the Power logging
        // control make — the app's VFO, which CAT forwards to radio1's
        // session if one is connected. Returns null on success for the same
        // reason as updateSetting: the hook's own confirm already told the
        // operator.
        final watts = params?['watts'] as num?;
        if (watts == null) return null;
        radio.setVfo('vfoA', power: watts);
        return null;
      case 'setKeyerSpeed' || 'showKeyer' || 'setEnterSends':
        return keyerCommandAction(this, action, params);
      case 'openSettings':
        // The setting can't be typed on one line (multiselect, account,
        // secret), the operator named it without a value, or the query
        // matched several equally well — all three want the settings form
        // rather than a guess.
        final context = navigatorKey.currentContext;
        if (context == null) return null;
        final keys = (params?['keys'] as List?)?.whereType<String>().toList() ?? const <String>[];
        if (keys.isEmpty) return null;
        unawaited(showSettingsForKeys(context, services: this, keys: keys, title: params?['title'] as String? ?? t.settings.title));
        return null;
      default:
        return null;
    }
  }

  /// OPER / POSITION: writes one edit to the open operation. The hook parsed
  /// the text and its own `confirm` already told the operator what is
  /// happening, so success returns null, exactly as `updateSetting` does —
  /// a non-null return is a failure the hook could not have known about.
  ///
  /// The two fields deliberately go to different places: the operator
  /// callsign is the operation's own data and syncs with it, while the
  /// position names THIS device and must not (see `spotCallForSelfSpot`).
  Future<CommandActionOutcome?> _updateOperation(Map<String, dynamic> params) async {
    final uuid = asQsonString(params['uuid']) ?? '';
    final operation = uuid.isEmpty ? null : await operations.get(uuid);
    if (operation == null) return (text: t.commands.noOperationOpen, failed: true);

    // The position lands first, and the operator goes into the slot it names.
    // Both writes are guarded on the change — a local_data write rebuilds the
    // Operation View (see the details dialog's own write), and a data write
    // pushes a revision to every other device — and the operator's guard reads
    // the DESTINATION seat, not the one this device is leaving: a command
    // carrying both fields would otherwise compare against the old seat's
    // operator and skip a write the new seat needs.
    // Trimmed and uppercased at the boundary, like the details dialog: this
    // is public SDK surface (`updateOperation`), and a value arriving with
    // stray space would never equal the trimmed slot it is compared against —
    // so every repeat of the same command would push another revision.
    final operatorCall = params['operatorCall']?.toString().trim().toUpperCase();
    final raw = params['multiIdentifier']?.toString();
    final multiIdentifier = raw == null ? null : normalizedMultiIdentifier(raw);
    if (multiIdentifier != null && multiIdentifier != multiIdentifierFor(operation)) {
      await operations.updateLocalData(operation.uuid, {multiIdentifierKey: multiIdentifier});
    }
    if (operatorCall != null) {
      final key = operatorCallKeyFor(multiIdentifier ?? multiIdentifierFor(operation));
      final seatOperatorCall = (asQsonString(operation.data[key]) ?? '').trim();
      if (operatorCall != seatOperatorCall) {
        await operations.saveData(Operation(uuid: operation.uuid, data: {...operation.data, key: operatorCall}));
      }
    }
    return null;
  }

  /// What a segment row says in the list — polo's `describeOperation`: each
  /// ref's title fragments, then "at `<grid>`", joined with " • " ("for ARRL
  /// 10G Sep • POTA: US-1000 • at FN21rm"). Stored on the row rather than
  /// composed at render, so a synced row reads the same on a device without
  /// the extension that named the ref.
  /// Null when the references could not all be asked — the runtime is down,
  /// or a hook threw. A truncated phrase must not be PERSISTED as though it
  /// were the whole truth: it would replace a good description on a restamp,
  /// and no later pass recomposes it. The row falls back to what it can
  /// render from its own override instead (`EventRow`).
  Future<String?> segmentDescription(Operation operation, Map<String, dynamic> override, {required String kind}) async {
    final resolved = Operation(uuid: operation.uuid, data: {...operation.data, ...override});
    final result = await operationTitles.suggestForRefs(resolved);
    if (result == null || !result.complete) return null;
    return segmentDescriptionFor(t, result.suggestions, resolved.displayGrid, kind: kind);
  }

  /// START / BREAK / STOP / ROVERQTH: writes the segment boundary the scoring
  /// model reads (docs/design/contests.md §5.1.3). A `break` row states what
  /// is true for the stretch that FOLLOWS it, and the base operation is only
  /// a default under the segments, not an accumulator — so a log getting its
  /// first break also gets a `start` at its top holding what the contacts so
  /// far were made under; otherwise, the moment the base moves, they would
  /// all silently move with it. `stop` moves an existing stop row to now
  /// rather than stacking a second one, as polo does.
  ///
  /// With `setLocation` (ROVERQTH) the Location screen opens afterwards, and
  /// what it returns is saved onto the operation; `onLocalSave` then restamps
  /// the break just written, which is how the new stretch resolves to the
  /// new square. A cancelled screen leaves a break restating the old
  /// location, which scores exactly as before.
  ///
  /// Returns null on success — the hook's own `confirm` already told the
  /// operator what is happening, as `updateOperation` does.
  Future<CommandActionOutcome?> _markSegment(Map<String, dynamic> params) async {
    final kind = asQsonString(params['kind']) ?? '';
    if (kind != 'start' && kind != 'break' && kind != 'stop') {
      // Only a malformed extension action reaches this, so it must name the
      // real fault rather than borrow the no-operation message.
      return (text: t.commands.unknownSegmentKind(kind: kind), failed: true);
    }
    final uuid = asQsonString(params['uuid']) ?? '';
    final operation = uuid.isEmpty ? null : await operations.get(uuid);
    if (operation == null) return (text: t.commands.noOperationOpen, failed: true);

    // Event rows only: the whole log would be decoded to read a handful of
    // them, and the one thing needed from the contacts is the earliest time.
    final events = await qsos.eventsForOperation(operation.uuid);
    final override = segmentOverrideOf(operation.data);
    // `kind` decides the wording: a break says what is NOW true, a start (or
    // the start a first break has to open) states it plainly.
    final description = await segmentDescription(operation, override, kind: kind);
    final startDescription = kind == 'start' ? description : await segmentDescription(operation, override, kind: 'start');
    final hasStart = events.any((q) => q.eventKind == 'start');
    final hasSegment = events.any((q) => eventKindOpensSegment(q.eventKind));

    Future<void> addStart() async {
      final firstAt = await qsos.firstContactMillis(operation.uuid);
      await qsos.addEvent(
        operation.uuid,
        kind: 'start',
        atMillis: firstAt == null ? nowMillis() : firstAt - 1000,
        operation: override,
        description: startDescription,
      );
    }

    switch (kind) {
      case 'start':
        // Reported, not silent: the operator asked to mark the start NOW,
        // and the row that exists sits at the top of the log with an older
        // timestamp. A bare success would read as though it had moved.
        if (hasStart) return (text: t.commands.operationAlreadyStarted, failed: true);
        await addStart();
      case 'break':
        if (!hasSegment) await addStart();
        await qsos.addEvent(operation.uuid, kind: 'break', atMillis: nowMillis(), operation: override, description: description);
      case 'stop':
        Qso? previous;
        for (final q in events) {
          if (q.eventKind == 'stop') previous = q;
        }
        if (previous == null) {
          await qsos.addEvent(operation.uuid, kind: 'stop', atMillis: nowMillis(), operation: override, description: description);
        } else {
          await qsos.update(
            Qso(
              uuid: previous.uuid,
              operationUuid: previous.operationUuid,
              data: {
                ...previous.data,
                'startAtMillis': nowMillis(),
                // The override is being restated, so a description that
                // could not be composed in full is CLEARED rather than kept:
                // the old line would describe the stretch this row no longer
                // states (see [segmentDescription]).
                'event': {...?previous.event, 'operation': override, 'description': description}
                  ..removeWhere((key, value) => key == 'description' && value == null),
              },
            ),
          );
        }
    }

    if (params['setLocation'] != true) return null;
    final context = navigatorKey.currentContext;
    // The hook's confirm already said "now set your new location". Going
    // quiet here would leave the operator holding that promise while the
    // next stretch scores from the old square.
    if (context == null || !context.mounted) return (text: t.commands.couldNotOpenLocation, failed: true);
    final patch = await showHaloDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => OperationLocationScreen(services: this, operation: operation),
    );
    if (patch == null) return null;
    // The counters and local data ride along: `rescoreOperation` reads
    // `localData['huntedRefTypes']` to decide whether to write, and an
    // operation rebuilt without it looks uncached every time — a local_data
    // write, and the Operation View rebuild behind it, on every ROVERQTH.
    final updated = Operation(
      uuid: operation.uuid,
      data: {...operation.data, ...patch},
      qsoCount: operation.qsoCount,
      startAtMillisMin: operation.startAtMillisMin,
      startAtMillisMax: operation.startAtMillisMax,
      localData: operation.localData,
    );
    await operations.saveData(updated);
    unawaited(scoring.rescoreOperation(updated));
    return null;
  }

  /// Backs both the Spotting control's send button and the SPOT/QRV/QRT/
  /// QSY/QRX/SPOTLAST-family commands (`logging_controls.dart`'s
  /// `_dispatchActions`, which already resolved *who* gets spotted —
  /// this only posts and summarizes the per-source result).
  Future<CommandActionOutcome?> _sendSpot(Map<String, dynamic> params) async {
    final operation = (params['operation'] as Map?)?.cast<String, dynamic>() ?? const {};
    final qso = (params['qso'] as Map?)?.cast<String, dynamic>();
    final target = params['target'] as String? ?? 'self';
    if (target == 'last' && qso == null) return (text: t.spotting.noQsoYet, failed: true);
    final freq = (params['freq'] as num?)?.toDouble();
    if (qso == null && freq == null) return (text: t.spotting.setFrequencyFirst, failed: true);

    final sources = await extensions.suggestSpotSources(operation: operation, qso: qso);
    if (sources.isEmpty) return (text: t.spotting.nothingToSpot, failed: true);

    final results = await extensions.sendSpot(
      sources: sources,
      operation: operation,
      qso: qso,
      freq: freq,
      mode: params['mode'] as String?,
      comment: params['comment'] as String?,
      spotterCall: settings.activeProfile.operatorCall,
    );

    // Only failures get a notice — a successful spot already shows in the
    // Spotting control's per-source status icons, and a "Spotted on X" text
    // notice on top of that is a confirmation nobody asked to acknowledge.
    // A refusal still has to surface: it's bad news the operator needs to
    // see, since the icon alone is easy to miss. Distinct from every source
    // failing: no result at all (every hookKey missing from `results`) means
    // the spot never went anywhere, which is its own failure to report.
    var anyResult = false;
    final failures = <String>[];
    for (final source in sources) {
      final hookKey = source['hookKey'] as String? ?? '?';
      final result = results[hookKey];
      if (result == null) continue;
      anyResult = true;
      if (result['ok'] != true) {
        failures.add(t.spotting.spotFailed(source: hookKey, message: (result['message'] as Object?) ?? t.spotting.unknownError));
      }
    }
    if (!anyResult) return (text: t.spotting.notSent, failed: true);
    if (failures.isEmpty) return null;
    return (text: failures.join('; '), failed: true);
  }

  Future<Map<String, dynamic>> _syncTransportCall(HookRef hook, Map<String, dynamic> args) async {
    final host = extensions.host;
    // Not an error - the extension host is still loading. On a cold start the
    // first periodic round can fire before it is up, and every other consumer
    // (scoring, operation titles, export) already treats that as a no-op.
    // Throwing a plain StateError here made each launch count a sync failure
    // and file a crash report for a race that clears in seconds.
    if (host == null) throw const SyncTransportNotReady();
    final result = await host.invoke(hook, args: args, timeout: const Duration(seconds: 30));
    return (result as Map).cast<String, dynamic>();
  }
}

/// What a command action had to say about what it did, and whether that is
/// bad news.
///
/// The two travel together because the destination has to tell them apart:
/// "Spotted on POTA" and "POTA: 503" reach the same line, and rendered alike
/// the second reads as the first. Only the action knows which it is —
/// `updateSetting` returns text ONLY on failure, while `syncAll` returns it
/// either way — so the classification is made where that is known and carried
/// from there, never guessed from the wording downstream.
typedef CommandActionOutcome = ({String text, bool failed});
