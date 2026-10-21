// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The one place that decides what an exception deserves.
//
// Every error that reaches the app's global handling — the FlutterError
// chain, an explicit ErrorReportingService.report(), or a backend's own
// capture hook (app_dist's Sentry beforeSend, the only path an uncaught
// ASYNC error takes) — is classified here, exactly once, into an
// [ErrorDisposition]. Nothing else may hardcode a "but not this one"
// check: if an error is not worth a notice, or not worth uploading, that
// belongs in [ErrorPolicy.rules] with the reasoning attached, so the whole
// policy can be read in one screen and so every path applies the same one.
//
// The default is deliberately the loudest tier: an error nobody has
// classified is a bug we haven't seen yet, and it should be noisy.
//
// docs/design/error-reporting.md is the overview.

import 'dart:async' show TimeoutException;
import 'dart:io' show FileSystemException, IOException, SocketException;

import 'package:flutter/foundation.dart' show kDebugMode, kIsWeb, visibleForTesting;
import 'package:flutter/services.dart' show PlatformException;
import 'package:flutter/widgets.dart';
import 'package:halo_extension_host/halo_extension_host.dart' show ExtensionHostException, HookTimeoutException;
import 'package:halo_core/halo_core.dart'
    show
        DataFileImportShrank,
        LogFromNewerBuild,
        MalformedQsonDataException,
        N1mmCallHistoryUnavailable,
        SyncPayloadUnreadable,
        SyncPullStuck,
        SyncRecordsRejected,
        WriteRefused;
import 'package:http/http.dart' show ClientException;

import 'bottom_chrome_squeezed.dart' show BottomChromeSqueezed;
import 'cat/transport.dart' show CatConnectFailure, CatUnreachable;
import 'connectivity_service.dart' show ConnectivityService;
import 'peer/peer_link_types.dart' show PeerMediaDialFailure;
import 'extensions/catalog_service.dart' show CatalogRefused, CatalogUnreachable;
import 'data_file_manager.dart' show DataFileRemoveHookFailed, DataFileUnavailable;
import 'extensions/extension_catalog_migration.dart' show BundleWouldNotEvaluate, CatalogNotWired, UpgradeLeftNoRuntime;
import 'extensions/extension_chasing.dart' show ChasingHookFailure;
import 'extensions/extension_scoring.dart' show ScoringHookFailure;
import 'extensions/extension_service.dart' show ExtensionTimersSuspended, MalformedSpotDataException;
import 'windows_webview.dart' show WindowsWebViewUnavailable;
import 'map_error_reporter.dart' show MapError;
import 'app_storage.dart' show PreferencesFileUnreadable;
import 'unclean_quit.dart' show UncleanDatabaseQuit;
import 'website_panel_error.dart' show WebsitePanelError;

/// What the app does with an error, from quietest to loudest. Each tier
/// includes everything the ones above it do.
enum ErrorDisposition {
  /// Nothing at all — not even a console dump (bar one breadcrumb per
  /// session, so a developer staring at the console isn't misled into
  /// thinking the error never happened). For framework noise the operator
  /// can neither cause nor act on.
  ignore,

  /// Console only. A real problem worth seeing while developing, but one
  /// that can't reach — or can't matter in — the release build users run.
  logOnly,

  /// Console + upload to the crash backend. Worth knowing about in
  /// aggregate; not worth interrupting the operator over.
  report,

  /// Console + upload + the once-per-session "Something went wrong"
  /// notice. The default for anything unclassified.
  notify;

  bool get uploads => index >= ErrorDisposition.report.index;
  bool get notifies => this == ErrorDisposition.notify;
}

/// One classification rule: a matcher plus the disposition it assigns and
/// the reason it does, which is what gets printed to the console.
@immutable
class ErrorRule {
  /// Stable identifier, used in the console line and by the tests.
  final String id;

  /// Why this error gets this disposition — one line, aimed at whoever
  /// finds it in the console and wonders where their error went.
  final String reason;

  final ErrorDisposition disposition;

  /// Whether the console line is printed once per session rather than
  /// every time. Only sensible for [ErrorDisposition.ignore], where the
  /// noise is by definition high-frequency.
  final bool logOncePerSession;

  final bool Function(Object error, FlutterErrorDetails? details) matches;

  const ErrorRule({required this.id, required this.reason, required this.disposition, required this.matches, this.logOncePerSession = false});
}

/// The rule that claimed an error, if any, and what it decided.
@immutable
class ErrorDecision {
  final ErrorDisposition disposition;

  /// Null when no rule matched — i.e. the default [ErrorDisposition.notify].
  final ErrorRule? rule;

  const ErrorDecision(this.disposition, this.rule);
}

class ErrorPolicy {
  ErrorPolicy._();

  /// Set once the app has committed to quitting (main.dart's
  /// `shutdownOnExit`), which is the only moment the database is ever closed.
  /// Read by the `database-closed-on-exit` rule below: without this, the same
  /// "closed database" StateError raised MID-SESSION — a real defect — would
  /// be quietened along with the harmless ones.
  static bool appIsExiting = false;

  /// Pretend we are on web, for the tests — `kIsWeb` is a compile-time false in
  /// the VM the tests run in, so without this seam the one predicate that only
  /// ever fires on web could not be exercised at all.
  @visibleForTesting
  static bool? debugTreatAsWeb;

  /// Classify [error]. [details] is supplied only on the FlutterError path
  /// (a rule that needs the framework's own context can only match there);
  /// an async error or an explicit report() arrives without it.
  static ErrorDecision decide(Object error, {FlutterErrorDetails? details}) {
    for (final rule in rules) {
      if (rule.matches(error, details)) return ErrorDecision(rule.disposition, rule);
    }
    return const ErrorDecision(ErrorDisposition.notify, null);
  }

  /// Every exemption the app makes, in order. Anything not matched here is
  /// treated as a real, unknown error: logged, uploaded, and noticed.
  static final List<ErrorRule> rules = [
    ErrorRule(
      id: 'write-refused',
      reason:
          'the app declined a write rather than failing at one — a travelled clock over a '
          'record that is not test data (WritePolicy). An expected outcome with an operator-facing '
          'reason of its own, so it is never uploaded and never wears the generic "Something went '
          'wrong" notice; the reason is shown by ErrorReportingService.noticeWriteRefused. Reaching '
          'a global handler at all means a write site did not deal with its own refusal, which is '
          'what the console line is for',
      disposition: ErrorDisposition.logOnly,
      matches: (error, _) => error is WriteRefused,
    ),
    ErrorRule(
      id: 'sync-records-rejected',
      reason:
          'the sync server accepted the round but refused individual records (a guest editing '
          'an operation they do not own, a validation failure), or could not read some of what was '
          'sent at all. Worth knowing about in aggregate — '
          'it means data sitting on a device the server does not have — but "the server refused '
          'this QSO" names nothing the operator can do mid-contact, and the record stays dirty and '
          'keeps being offered, so the generic notice would recur against a state they cannot '
          'clear',
      disposition: ErrorDisposition.report,
      matches: (error, _) => error is SyncRecordsRejected || error is SyncPayloadUnreadable,
    ),
    ErrorRule(
      id: 'sync-pull-stuck-while-offline',
      reason:
          'a sync pull stuck on one request because no connection could be made, while the device '
          'is offline: in the field every request fails unchanged, so this is an activation, not a '
          'page the server cannot serve. Only '
          'connection failures: a timeout is how a page too large to arrive fails, offline verdict '
          'or not, so it keeps the rule below — a captive portal timing out is the price',
      disposition: ErrorDisposition.logOnly,
      matches: _isSyncPullStuckWhileOffline,
    ),
    ErrorRule(
      id: 'sync-pull-stuck',
      reason:
          'a sync pull has failed on the same request round after round while its page shrank, so '
          'the device is retrying a page it cannot download and holds less than the account. '
          'Uploaded under its own type because the timeout underneath reads exactly like a slow '
          'link; never noticed, because the operator can do nothing about it — what clears it is '
          'on the server',
      disposition: ErrorDisposition.report,
      matches: (error, _) => error is SyncPullStuck,
    ),
    ErrorRule(
      id: 'extensions-not-wired',
      reason:
          'the extension service was handed no catalog, so nothing can be fetched, adopted or '
          'restored. A wiring defect rather than a server that cannot '
          'be reached — which is what it looked like for as long as the two were folded together — '
          'so it is uploaded rather than noticed: the operator can do nothing about it, and the '
          'audience is whoever changes the service graph',
      disposition: ErrorDisposition.report,
      matches: (error, _) => error is CatalogNotWired,
    ),
    ErrorRule(
      id: 'bundle-would-not-evaluate',
      reason:
          'an installed extension the JS engine refused, now kept out of the runtime so the '
          'others can load. The operator is told in a notice and on the panel row, so it '
          'uploads without a notice — and it has to upload, because a refused bundle never loads '
          'again and its boot failure stops arriving under extensions:restart: the rate here is '
          'the only thing that tells one bad download from a release the catalog is serving '
          'broken to everybody',
      disposition: ErrorDisposition.report,
      matches: (error, _) => error is BundleWouldNotEvaluate,
    ),
    ErrorRule(
      id: 'upgrade-left-no-runtime',
      reason:
          'extensions that just arrived — pre-loaded, adopted or restored — left the runtime unable to '
          'start even with every bundle the boot named set aside. The operator is already told, '
          'so it is uploaded rather than noticed — what the backend adds is the RATE, which is the '
          'only way to tell one corrupt download from a bundle the catalog is shipping broken to '
          'everybody',
      disposition: ErrorDisposition.report,
      matches: (error, _) => error is UpgradeLeftNoRuntime,
    ),
    ErrorRule(
      id: 'web-focus-traversal-null',
      reason:
          'Flutter web focus-traversal null on view-focus change (ham2k/halo-dist#271); '
          'later ones are silent',
      disposition: ErrorDisposition.ignore,
      logOncePerSession: true,
      matches: _isWebFocusTraversalNull,
    ),
    ErrorRule(
      id: 'hot-restart-stale-object',
      reason:
          'a live object left behind by a hot reload/restart, whose class no longer has the '
          'field being read. A development artifact of the reload itself — nothing in the code is '
          'wrong and a cold start clears it, so it must not wear an operator notice or reach the '
          'backend. Debug builds only, so it can never quiet anything a user could see',
      disposition: ErrorDisposition.logOnly,
      matches: _isHotRestartStaleObject,
    ),
    ErrorRule(
      id: 'bottom-chrome-squeezed',
      reason:
          'the window is too short to seat all of the bottom chrome above the keyboard, so '
          'the status footer and then the numbers row gave way (BottomChromeBudget). The '
          'operator loses status while typing and cannot tell why, which is what this line is '
          'for — it is not something they can act on mid-contact',
      disposition: ErrorDisposition.logOnly,
      matches: _isBottomChromeSqueezed,
    ),
    ErrorRule(
      id: 'renderflex-overflow',
      reason: 'RenderFlex overflow: a debug-only layout warning, already marked on-screen',
      disposition: ErrorDisposition.logOnly,
      matches: _isRenderFlexOverflow,
    ),
    ErrorRule(
      id: 'web-semantics-node-map-inconsistent',
      reason:
          'the web engine left an orphan in its semantics node map: a debug-only assertion, '
          'over a tree only dev builds ask for',
      disposition: ErrorDisposition.logOnly,
      matches: _isWebSemanticsNodeMapInconsistent,
    ),
    ErrorRule(
      id: 'set-state-during-build',
      reason:
          'setState()/markNeedsBuild() during build: a build-ordering bug to fix locally, '
          'harmless to the operator',
      disposition: ErrorDisposition.logOnly,
      matches: _isSetStateDuringBuild,
    ),
    ErrorRule(
      id: 'focus-node-cannot-request-focus',
      reason: 'a focus node was asked for focus as it was being torn down; the framework recovers',
      disposition: ErrorDisposition.logOnly,
      matches: _isFocusNodeCanRequestFocusAssertion,
    ),
    ErrorRule(
      id: 'data-file-remove-hook-absent',
      reason:
          'removing a data file offers its extension an onRemoveRawData hook, and most do not '
          'implement one — the kernel answers "no hook registered", which is the ordinary case '
          'rather than a fault, and nothing the operator can act on mid-removal. Matched on that '
          'ONE answer and not on the wrapper: a hook that exists and threw left the extension\'s '
          'raw data behind, and falls through to the default tier where an unclassified failure '
          'belongs',
      disposition: ErrorDisposition.logOnly,
      matches: (error, _) => error is DataFileRemoveHookFailed && error.cause.toString().contains('no hook registered'),
    ),
    ErrorRule(
      id: 'extension-host-disposed',
      reason:
          'an in-flight hook call was cut off by a runtime replacement (extension toggle, '
          'restartOnChange, crash backoff, shutdown); callers redo the work against the new '
          'runtime or drop it by design',
      disposition: ErrorDisposition.logOnly,
      matches: _isExtensionHostDisposed,
    ),
    ErrorRule(
      id: 'extension-runtime-dead',
      reason:
          'a hook call against a crashed runtime, refused without waiting out its timeout; '
          'the crash itself is reported separately (extensions:restart)',
      disposition: ErrorDisposition.logOnly,
      matches: _isExtensionRuntimeDead,
    ),
    ErrorRule(
      id: 'hook-timed-out',
      reason:
          'a hook did not answer within the timeout its caller allowed (a slow upstream '
          'service, or an extension taking too long over a large local pass). Every caller '
          'already degrades on its own — a lookup returns nothing and the next keystroke asks '
          'again, a fan-out keeps the hooks that did answer — so there is nothing here for the '
          'operator to act on, and the "Something went wrong" notice fires once per SESSION: '
          'spending it on a slow callsign lookup means the next error that does matter arrives '
          'silently. Uploaded rather than dropped: the rate is what says whether a timeout is '
          'too tight or a hook is genuinely hung',
      disposition: ErrorDisposition.report,
      matches: (error, details) => error is HookTimeoutException,
    ),
    ErrorRule(
      id: 'connectivity-backend-unavailable',
      reason:
          "connectivity_plus's Linux backend needs NetworkManager over D-Bus; without it the "
          'plugin throws out of its own stream setup, unreachable by any onError of ours. The app '
          'degrades to no reconnect-resync',
      disposition: ErrorDisposition.logOnly,
      matches: _isConnectivityBackendUnavailable,
    ),
    ErrorRule(
      id: 'windows-webview-unavailable',
      reason:
          "Windows refused this app a webview (WebView2 missing, or its user data folder "
          'unwritable where the app was installed); the Map tab falls back to OpenStreetMap and the '
          'account login says it cannot sign in here, so there is nothing left for the operator to do',
      disposition: ErrorDisposition.report,
      matches: _isWindowsWebViewUnavailable,
    ),
    ErrorRule(
      id: 'cat-equipment-unreachable',
      reason:
          "a radio didn't answer a connect attempt (switched off, unplugged, already held by "
          'another program, or refusing the login); the equipment row says so and the retry loop '
          'keeps trying',
      disposition: ErrorDisposition.logOnly,
      matches: _isCatEquipmentUnreachable,
    ),
    ErrorRule(
      id: 'peer-media-unreachable',
      reason:
          'a peer refused or never answered the media link a screen pane dials (a firewall '
          'between the two, a peer that left mid-dial); the pane says "not connected" and '
          're-dials on its own, and a firewall between two peers is not a defect',
      disposition: ErrorDisposition.logOnly,
      matches: _isPeerMediaUnreachable,
    ),
    ErrorRule(
      id: 'keychain-cannot-enumerate',
      reason:
          'the keychain refused to list its items (errSecParam, -50). macOS answers that for '
          'a readAll against the FILE keychain this app has to use, so it is a property of the '
          'platform rather than a fault: the two callers that ask — copying an extension\'s '
          'secrets to its new key, and removing them on uninstall — fall back to the account '
          'names they can construct without a listing, and carry on. Logged rather than uploaded '
          'because it fires once per extension per migration and says the same thing every time, '
          'and the thing it says is already known',
      disposition: ErrorDisposition.logOnly,
      matches: _isKeychainCannotEnumerate,
    ),
    ErrorRule(
      id: 'keychain-locked',
      reason:
          'the keychain refused an operation (errSecInteractionNotAllowed) — it cannot serve '
          'one without an unlock it has no way to ask for. Usually a locked device with the app '
          'still working behind it, reading or writing a secret nobody asked it to touch just '
          'then: the CAT idle-retry loop reopening a radio, an extension fetching an account. '
          'That case resolves on the next unlock; a macOS session that can never prompt is '
          'refused for the length of the process, and neither is something the operator can act '
          'on mid-activation. Uploaded rather than dropped, because the rate is what says how '
          'often the app reaches for a secret it cannot have (for an extension account that is '
          'once per retry interval, not once per hook call — the host remembers a refusal, see '
          'AccountContextCache.unreadableRetry); never noticed, because the notice '
          'fires once per SESSION and would be spent on a background retry, leaving the next real '
          'error to arrive silently',
      disposition: ErrorDisposition.report,
      matches: _isKeychainLocked,
    ),
    ErrorRule(
      id: 'network-unreachable-while-offline',
      reason:
          'a network call failed to get an answer while the device is offline (no route, or '
          'nothing answering over the one there is); in the field that is the session\'s normal '
          'state rather than a defect, and uploading one event per retry per subsystem for the '
          'length of an activation would bury the online failures these types exist to surface',
      disposition: ErrorDisposition.logOnly,
      matches: _isNetworkErrorWhileOffline,
    ),
    ErrorRule(
      id: 'fetch-transport-transient',
      reason:
          "a host.fetch call failed at the transport layer (connection reset, refused or "
          'closed mid-body, or a fetch timeout) rather than anything our code did; worth seeing '
          'in aggregate, not worth an operator notice for a TCP blip the caller already retries',
      disposition: ErrorDisposition.report,
      matches: _isFetchTransportTransient,
    ),
    ErrorRule(
      id: 'lofi-backup-capture-also-failed',
      reason:
          'the ham2k-lofi extension already fell back to the standalone backup capture '
          'service on a LoFi outage, and that capture attempt also failed -- this device now '
          'holds the only copy of the payload, distinct from an ordinary LoFi failure (which '
          'still has a backup somewhere) and worth an operator notice',
      disposition: ErrorDisposition.notify,
      matches: _isLoFiBackupCaptureAlsoFailed,
    ),
    ErrorRule(
      id: 'http-client-connection-transient',
      reason:
          'a direct package:http call (DataFileManager and its siblings, not hostFetch) '
          'failed at the connection layer (DNS, refused, reset) rather than anything our code '
          'did; worth seeing in aggregate, not worth an operator notice for a caller that '
          'retries on its own schedule',
      disposition: ErrorDisposition.report,
      matches: _isHttpClientConnectionTransient,
    ),
    ErrorRule(
      id: 'data-file-unavailable',
      reason:
          "a data file's server did not answer in time, or answered with an error status; the "
          'offline data already on the device stays, the next pass tries again, and a refresh the '
          'operator asked for says so in its own notice — a background pass has nothing to act on. '
          'Uploaded because the rate per host says whether a source is dying or a timeout is too tight',
      disposition: ErrorDisposition.report,
      matches: (error, details) => error is DataFileUnavailable,
    ),
    ErrorRule(
      id: 'data-file-import-shrank',
      reason:
          'a data file mapped to far fewer rows than the device already holds. Unforced, the import '
          'was refused and the rows kept, and Offline Data says so; forced, the operator asked for it. '
          'Uploaded either way because only the rate says whether a source is serving short bodies '
          'or a mapper has broken',
      disposition: ErrorDisposition.report,
      matches: (error, details) => error is DataFileImportShrank,
    ),
    ErrorRule(
      id: 'n1mm-call-history-unavailable',
      reason:
          "N1MM's call history pages led to no file: no file matches the data file's stem, the "
          'download was refused, or a page changed shape. The offline data already on the device '
          'stays and a refresh the operator asked for says so in its own notice. Uploaded because '
          'the rate says whether N1MM changed its site, which breaks every n1mm-history: data file at once',
      disposition: ErrorDisposition.report,
      matches: (error, details) => error is N1mmCallHistoryUnavailable,
    ),
    ErrorRule(
      id: 'catalog-unreachable',
      reason:
          'the extension catalog did not answer (a connection failure or the request timeout), '
          'or answered with an error status, on a check the operator did not ask for; the '
          'service reports it only as a failure streak, so a dead catalog is seen in aggregate '
          'and a captive portal is not noticed',
      disposition: ErrorDisposition.report,
      matches: _isCatalogUnreachable,
    ),
    ErrorRule(
      id: 'map-offline',
      reason:
          'a map error raised while the device was offline; a field operation without '
          'coverage fails every tile and style fetch, and that is the normal state of an '
          'off-grid activation, not a defect',
      disposition: ErrorDisposition.logOnly,
      matches: _isMapErrorWhileOffline,
    ),
    ErrorRule(
      id: 'extension-timers-suspended',
      reason:
          "an extension's timers broke their budget and were stopped (extensions/sdk/src/timerQueue.ts): "
          'a defect in that one extension, whose hooks keep answering. Developer mode names it in a '
          'notice of its own, so this adds none; uploaded because in the field it is otherwise '
          'invisible — the operator sees a feature stop, and only the rate says whether a built-in '
          'extension is tripping its budget on real hardware',
      disposition: ErrorDisposition.report,
      matches: (error, details) => error is ExtensionTimersSuspended,
    ),
    ErrorRule(
      id: 'malformed-spot-data',
      reason:
          'a spots hook returned a field of the wrong type (extension_hook_api.dart\'s '
          'validSpots) — a defect in that one extension, not something the operator can act on, '
          'and the spot is already dropped so the panel\'s other sources are unaffected',
      disposition: ErrorDisposition.report,
      matches: (error, details) => error is MalformedSpotDataException,
    ),
    ErrorRule(
      id: 'malformed-qson-data',
      reason:
          'a QSON record reached storage carrying a field of the wrong type (qson_values.dart\'s '
          'normalizer) — the value is already coerced or dropped, so nothing is broken by the time '
          'this is raised; it is uploaded purely to name whatever WROTE it, which coercion alone '
          'would leave unknown',
      disposition: ErrorDisposition.report,
      matches: (error, details) => error is MalformedQsonDataException,
    ),
    ErrorRule(
      id: 'scoring-hook-failed',
      reason:
          'one scoring hook threw or timed out (extension_scoring.dart\'s ScoringHookFailure) '
          '— a defect in that extension, and nothing the operator can act on mid-activation; the '
          'pass drops that scorer\'s verdicts rather than keeping stale ones, so the board reads '
          'available rather than worked',
      disposition: ErrorDisposition.report,
      matches: (error, details) => error is ScoringHookFailure,
    ),
    ErrorRule(
      id: 'chasing-hook-failed',
      reason:
          'one chasing program threw, timed out or answered malformed claims '
          '(extension_chasing.dart\'s ChasingHookFailure) — a defect in that extension, and '
          'nothing the operator can act on; that program\'s claims for the batch are missing, so '
          'its checklist reads as less worked than it is',
      disposition: ErrorDisposition.report,
      matches: (error, details) => error is ChasingHookFailure,
    ),
    ErrorRule(
      id: 'website-panel-offline',
      reason:
          'a Web Site pane failed to load while the device was offline; a pane on a refresh '
          'interval retries on a schedule, so an off-grid activation fails every one of them — '
          'that is the absence of coverage, not a defect',
      disposition: ErrorDisposition.logOnly,
      matches: _isWebsitePanelErrorWhileOffline,
    ),
    ErrorRule(
      id: 'database-closed-on-exit',
      reason:
          'a write landed after the database was closed on the way out — usually a sync '
          'round or a peer event whose reply arrived during the quit, but the operator\'s own '
          'last edit counts too: once the close has run, no write of any origin has anywhere '
          'to go, and saying so in a notice the process outlives by milliseconds helps nobody',
      disposition: ErrorDisposition.logOnly,
      matches: _isDatabaseClosedOnExit,
    ),
    ErrorRule(
      id: 'unclean-database-quit',
      reason:
          'the PREVIOUS run could not finish closing the database, so writes it still had '
          'queued went with it. Uploaded rather than noticed: what was lost is already lost, a '
          'boot is the worst moment to hand someone a fright they cannot act on, and it is the '
          'rate across installs that says whether the quit path is sound',
      disposition: ErrorDisposition.report,
      matches: (error, details) => error is UncleanDatabaseQuit,
    ),
    ErrorRule(
      id: 'log-from-newer-build',
      reason:
          'the log on disk was written by a newer build and this one refuses to migrate it '
          'back down (halo_core\'s LogFromNewerBuild). The operator has ALREADY been told, at '
          'boot, in a notice naming both storage versions and the folder the log is in, so the '
          'generic notice on top of that would say strictly less. Console-only rather than '
          'uploaded because EVERY query throws this for as long as the app runs — a refused '
          'database refuses each stream rebuild, sync round and list read — and report() has no '
          'dedup, so uploading would send one session\'s worth of the same fact. The cost is '
          'that a downgrade in the field is now invisible to the backend; recovering that needs '
          'a once-per-session upload path, not a louder tier here. Matched through `within`, '
          'because a background-isolate open delivers this wrapped in a DriftRemoteException '
          'and a bare type test would quietly never fire',
      disposition: ErrorDisposition.logOnly,
      matches: (error, details) => LogFromNewerBuild.within(error) != null,
    ),
    ErrorRule(
      id: 'preferences-file-unreadable',
      reason:
          'the preferences file could not be parsed and was repaired at boot. Uploaded '
          'rather than noticed only because the operator has ALREADY been told, in a status '
          'notice that names what was lost and where the bad file went — the generic notice '
          'on top of it would say strictly less. The rate is what says whether the atomic '
          'write actually closed the window',
      disposition: ErrorDisposition.report,
      matches: (error, details) => error is PreferencesFileUnreadable,
    ),
  ];

  /// Flutter's own focus-traversal crash on web (ham2k/halo-dist#271),
  /// which this app drops on the floor.
  ///
  /// `ReadingOrderTraversalPolicy._pickNext` force-unwraps a directionality that
  /// legitimately comes back null when a transiently-defunct node is pulled into
  /// the sort, and `View.didChangeViewFocus` sorts EVERY traversable node in the
  /// view scope rather than just the active scope — so on web, where that fires
  /// on every browser focus change, the unsound `!` throws out of an observer.
  /// The framework catches it and the app carries on; the only thing it produces
  /// is a "Something went wrong" notice about a framework bug, on a screen the
  /// operator was only clicking into, that they can do nothing about.
  ///
  /// Narrow deliberately — three conditions, all of which must hold:
  ///
  ///  * **Web.** `handleViewFocusChanged` only reaches this path on the
  ///    multi-view embedder, so on every other platform this is dead code.
  ///  * **The framework's own literal context** for that dispatch
  ///    (`widgets/binding.dart`'s `'while dispatching notifications for
  ///    WidgetsBindingObserver.didChangeViewFocus'`), so no error raised
  ///    anywhere else is affected.
  ///  * **A null-check failure**, which is the specific unsound `!` in #271 and
  ///    not, say, a range error some future observer throws in the same place.
  ///
  /// The STACK is deliberately not matched: it names `focus_traversal.dart` in a
  /// debug build and is minified in a release one, so requiring it would make
  /// this work only where the noise matters least.
  ///
  /// This cannot hide a bug of ours. No observer in this app implements
  /// `didChangeViewFocus` — only Flutter's own `View` does — so nothing of ours
  /// can throw inside that dispatch. Delete this the day Flutter's `!` is fixed;
  /// #271 tracks the upstream side.
  static bool _isWebFocusTraversalNull(Object error, FlutterErrorDetails? details) {
    if (!(debugTreatAsWeb ?? kIsWeb)) return false;
    if (details == null) return false;
    if (!(details.context?.toString() ?? '').contains('WidgetsBindingObserver.didChangeViewFocus')) {
      return false;
    }
    if (error is TypeError) return true;
    // Belt and braces for the web runtime's own null-check type, whose identity
    // has moved between Dart versions; the message has not.
    final text = error.toString();
    return text.contains('Unexpected null value') || text.contains('Null check operator used on a null value');
  }

  /// Flutter's own "RenderFlex overflowed by N pixels" layout warning — a
  /// debug-only assertion (release builds clip silently and never throw
  /// this at all), thrown whenever a Row/Column's children don't fit,
  /// however minor the overflow. Real layout bugs worth fixing, but not
  /// worth a "Something went wrong" notice aimed at an operator who can't
  /// do anything about it, or an external report for something that
  /// literally cannot happen in the release build users run.
  /// Raised by `StatusBarOverlay` itself, once per transition, when the
  /// bottom chrome cannot all be seated above the on-screen keyboard.
  static bool _isBottomChromeSqueezed(Object error, FlutterErrorDetails? details) => error is BottomChromeSqueezed;

  static bool _isRenderFlexOverflow(Object error, FlutterErrorDetails? details) =>
      error is FlutterError && error.toString().contains('A RenderFlex overflowed by');

  /// The web engine's own check that every node it still holds is reachable
  /// from the root of the semantics tree, thrown when a subtree is replaced
  /// wholesale in one update and a leaf of the old one is left behind in the
  /// map (`_finalizeTree` walks the detached subtree to purge it, and misses
  /// a child whose parent was itself replaced). The orphan costs a DOM node
  /// and a map entry; nothing on screen changes.
  ///
  /// Two things bound it, and both have to hold for this to be quiet. The
  /// throw lives inside an `assert`, so no release build runs it. And the app
  /// only turns the accessibility tree on at all in dev (`main.dart`'s
  /// `ensureSemantics`, for agent tooling) — a user reaches this code only by
  /// switching accessibility on themselves, in a build where the assert is
  /// compiled out.
  ///
  /// Reproduced by the pinned `CollapsibleBand`s of the Settings pane, which
  /// enter the tree as siblings of the scroll group; upstream, it is the
  /// family of flutter/flutter#170753.
  static bool _isWebSemanticsNodeMapInconsistent(Object error, FlutterErrorDetails? details) =>
      (debugTreatAsWeb ?? kIsWeb) && error is StateError && error.message.contains('Semantics node map was inconsistent after update');

  /// A stale object stranded by a hot reload or hot restart: DDC reads a
  /// private Dart field off an instance whose class no longer declares it,
  /// and JavaScript answers `undefined` rather than throwing on the object
  /// itself. What surfaces is a `TypeError: Cannot read properties of
  /// undefined (reading 'Symbol(…)')`, usually from deep inside the
  /// framework — a stranded `Element` whose `_lifecycleState` has gone
  /// missing, say, which then fails an assert whose own message cannot be
  /// built either.
  ///
  /// Reported as a crash, it is noise of the worst kind: it names framework
  /// internals, points at no code, and the fix is a cold start. It says
  /// nothing about the build a user runs.
  ///
  /// Two guards keep it from quieting anything real. [kDebugMode], because a
  /// reload cannot happen in a profile or release build — where a JS TypeError
  /// naming a Dart symbol WOULD be a genuine compiler or interop bug, and
  /// stays loud. And the `Symbol(` in the message, which is what says the
  /// missing member is a private Dart field rather than an ordinary
  /// undefined-property mistake in interop code.
  static bool _isHotRestartStaleObject(Object error, FlutterErrorDetails? details) {
    if (!kDebugMode || !(debugTreatAsWeb ?? kIsWeb)) return false;
    // An extension's own JS crash reaches us wrapped, with the engine's
    // message quoted inside it — including, for extension code that touches
    // Symbol-keyed objects, one shaped exactly like this. That is an
    // extension author's real bug, in the dev cycle where they are hunting
    // it, so the wrapper is excluded rather than matched by its text.
    if (error is ExtensionHostException) return false;
    final text = error.toString();
    return text.contains('Cannot read properties of undefined') && text.contains("Symbol(");
  }

  /// "setState() or markNeedsBuild() called during build." — a framework
  /// assertion about the ORDER our own code touched a listener in, not
  /// about anything the operator did or can see: the frame still renders,
  /// with the stale value, and the next one is correct. Worth fixing when
  /// it shows up on a developer's console; not worth alarming an operator
  /// mid-contact, and not worth an upload, since the same misordering
  /// fires on every rebuild of that screen and would drown the real
  /// crashes in aggregate.
  ///
  /// Matched on the framework's own message, but only on the two types the
  /// framework raises it as — a FlutterError in debug, a plain assertion
  /// elsewhere. An exception of OURS that quotes the same text (a wrapper
  /// re-throwing it, say) has to stay loud, exactly as the RenderFlex rule
  /// above refuses a StateError carrying its message.
  ///
  /// The type check also has to come FIRST: `decide` runs every matcher
  /// against every error, from inside the error handler itself, and an
  /// arbitrary app object's toString() is not guaranteed not to throw —
  /// a second exception raised there would lose the original entirely.
  static bool _isSetStateDuringBuild(Object error, FlutterErrorDetails? details) {
    if (error is! FlutterError && error is! AssertionError) return false;
    return error.toString().contains('setState() or markNeedsBuild() called during build');
  }

  /// `'_effectiveFocusNode.canRequestFocus': is not true` — EditableText
  /// asserting that the node it is about to focus still can be focused.
  /// It loses that race whenever a field is disposed, disabled or replaced
  /// in the same frame something asks it to take focus (route pops, panel
  /// swaps, a form rebuilding under a keyboard event). The framework
  /// recovers by simply not moving focus; nothing is lost but a caret.
  ///
  /// Type first, then message — same reasoning as [_isSetStateDuringBuild].
  static bool _isFocusNodeCanRequestFocusAssertion(Object error, FlutterErrorDetails? details) {
    if (error is! FlutterError && error is! AssertionError) return false;
    return error.toString().contains('canRequestFocus');
  }

  /// `ExtensionHost.dispose()` fails every pending hook call with exactly
  /// this message. Disposal only happens on a runtime
  /// replacement — an extension enable/disable toggle, a `restartOnChange`
  /// settings commit, the crash-backoff replace, or app shutdown — so the
  /// caller that lost its call (a lookup, a data-file pass, a sync round)
  /// is about to find a fresh runtime, or none is needed again. Nothing
  /// for the operator to act on, and uploading it would bury real crashes
  /// under expected churn (every subsystem with a call in flight reports
  /// the same teardown at once).
  ///
  /// `DataFileManager` raises the same exception when it finds no host at
  /// all between a download and its import: the same restart, caught one
  /// await earlier.
  ///
  /// Matched on the exact message, and only on the host's own exception
  /// type: a wrapper of ours quoting the text stays loud.
  static bool _isExtensionHostDisposed(Object error, FlutterErrorDetails? details) {
    final cause = _hookCallCause(error);
    return cause is ExtensionHostException && cause.message == 'extension host disposed';
  }

  /// What a per-extension hook failure wraps, or [error] itself. Only the
  /// runtime-state rules look through the wrapper: a runtime replaced or
  /// crashed mid-pass fails EVERY scorer and program at once, and blaming each
  /// extension for it would upload one defect per extension for a state that
  /// is already reported. A timeout keeps the wrapper's own rule.
  static Object _hookCallCause(Object error) => switch (error) {
    ScoringHookFailure(:final cause) || ChasingHookFailure(:final cause) => cause,
    _ => error,
  };

  /// `ExtensionHost._send` refusing a call because the runtime already
  /// crashed ('extension runtime is dead (hook X not attempted)') — the
  /// fail-fast that spares the caller its full timeout. The crash that
  /// killed the runtime is reported once, with its real diagnostic, by
  /// ExtensionService's restart scheduling; every one of these is a
  /// duplicate of that already-known state, one per call attempted before
  /// the backoff restart lands.
  static bool _isExtensionRuntimeDead(Object error, FlutterErrorDetails? details) {
    final cause = _hookCallCause(error);
    return cause is ExtensionHostException && cause.message.startsWith('extension runtime is dead');
  }

  /// connectivity_plus's Linux backend connects to NetworkManager over D-Bus
  /// inside its stream's own async `onListen`, so on a system without it
  /// (WSL, systemd-networkd, minimal distros) the failure escapes as an
  /// unhandled async error that no subscription-side onError can catch.
  /// Matched by the error's identity: a DBusException (by type name — the
  /// dbus package is a transitive dependency this app doesn't import), or a
  /// SocketException aimed at a D-Bus socket path. Narrow enough that a
  /// real network failure of ours — never aimed at a dbus socket — cannot
  /// match.
  static bool _isConnectivityBackendUnavailable(Object error, FlutterErrorDetails? details) {
    if (error.runtimeType.toString() == 'DBusException') return true;
    return error is SocketException && error.toString().contains('dbus');
  }

  /// A connect attempt that failed because the equipment was not there to
  /// answer it — the everyday state of a station: the rig is off, the USB
  /// cable is out, another program holds the port, the rig refuses the
  /// login. None of it is a bug, and none of it is news to the operator: the
  /// equipment row is already red with this exact message, and the failure
  /// is what the row is FOR.
  ///
  /// Silencing it matters more than the single event suggests. CatService
  /// retries the designated radio on a backoff loop for as long as the app
  /// runs, so a rig left switched off doesn't upload one report — it uploads
  /// one every few minutes, all session, from every operator whose radio is
  /// not on, which is what would bury the crashes worth reading.
  ///
  /// Reaching this at all means [CatService]'s own catch wrapped the failure
  /// in a [CatConnectFailure], so nothing outside a connect attempt can
  /// match, however it reads. The CAUSE is then checked against the three
  /// shapes an absent or refusing rig produces:
  ///
  ///  * a [SocketException] — no route, refused, timed out, unknown host;
  ///  * a [TimeoutException] — the rig took the packets and never answered;
  ///  * a [CatUnreachable] — a transport's own account of the same thing (a
  ///    serial port that won't open, an Icom login refused or ignored).
  ///
  /// Anything else out of a transport stays loud: a TypeError on a config
  /// value, a StateError from a handshake step, a NoSuchMethodError in a
  /// driver are bugs of ours, and they are exactly what a rule matching "any
  /// failed connect" would swallow.
  /// The machine's refusal, not ours. The cause is inspected rather than the
  /// wrapper alone because our own code runs inside that try: a
  /// MissingPluginException means the Windows plugin isn't registered in the
  /// build we shipped, which is a packaging bug and must stay loud.
  static bool _isWindowsWebViewUnavailable(Object error, FlutterErrorDetails? details) {
    if (error is! WindowsWebViewUnavailable) return false;
    final cause = error.cause;
    return cause is PlatformException || cause is FileSystemException || cause is TimeoutException;
  }

  /// Apple's `errSecInteractionNotAllowed`, on any keychain operation the app
  /// makes — a read, and equally the writes behind [SettingsService]'s
  /// equipment secrets and an extension's stored session.
  static const _errSecInteractionNotAllowed = -25308;

  /// errSecParam. macOS answers it for a keychain LISTING against the file
  /// keychain, which is the only kind a Developer ID build may use.
  static const _errSecParam = -50;

  /// The one `code` flutter_secure_storage_darwin gives EVERY keychain
  /// failure, both of its throw sites. It carries no information about which
  /// failure this is — the `OSStatus` in `details` does that — but it is the
  /// only field tying the exception to the keychain at all, so matching it
  /// keeps another plugin's -25308 out. Should the plugin ever reword the
  /// literal, this rule stops matching and the error goes back to notifying,
  /// which is the safe direction to break in.
  static const _keychainFailureCode = 'Unexpected security result code';

  static bool _isKeychainLocked(Object error, FlutterErrorDetails? details) =>
      error is PlatformException &&
      error.code == _keychainFailureCode &&
      // `details` is dynamic and Dart reads -25308.0 == -25308 as true, so
      // the type comes first — on the VM. Web reads an integral double as an
      // int too, which costs nothing here: no web build has a keychain to
      // refuse anything.
      error.details is int &&
      error.details == _errSecInteractionNotAllowed;

  /// errSecParam, which macOS answers for a keychain `readAll` against the
  /// file keychain. Read off `details` like its sibling above, and for the
  /// same reason: the message is the platform's own wording, not ours to
  /// depend on.
  static bool _isKeychainCannotEnumerate(Object error, FlutterErrorDetails? details) =>
      error is PlatformException && error.code == _keychainFailureCode && error.details is int && error.details == _errSecParam;

  static bool _isCatEquipmentUnreachable(Object error, FlutterErrorDetails? details) {
    if (error is! CatConnectFailure) return false;
    final cause = error.cause;
    return cause is SocketException || cause is TimeoutException || cause is CatUnreachable;
  }

  /// `IOException` rather than the two shapes a refusal usually takes: a
  /// peer that closes mid-dial reaches `WebSocket.connect` as an
  /// `HttpException`, which is neither a `SocketException` nor a
  /// `WebSocketException` and is the rule's own headline case.
  static bool _isPeerMediaUnreachable(Object error, FlutterErrorDetails? details) {
    if (error is! PeerMediaDialFailure) return false;
    final cause = error.cause;
    return cause is IOException || cause is TimeoutException;
  }

  /// `_hostFetch`'s own transport call — `http.Client.send`, or either of
  /// the two `.timeout()`s wrapped around it — failing below the
  /// application layer: a `ClientException` (connection reset, refused, or
  /// closed mid-body) or the fetch's own `TimeoutException`. Both
  /// stringify through `_handleHostCall`'s catch-all into the
  /// `ExtensionHostException` this app sees. Only ONE case gets a
  /// same-call retry inside `_hostFetch` itself ("Failed host lookup"),
  /// because retrying anything else risks resending a non-idempotent POST
  /// after its body may already be in flight — everything else surfaces
  /// here instead, where the caller (SyncEngine's backoff loop, or
  /// whatever else called host.fetch) already tolerates it. An operator
  /// can't act on a TCP reset or a DNS lookup failure, and neither is a bug
  /// of ours.
  ///
  /// Matched by prefix on the wrapped exception's own class name, not by
  /// scanning for a substring anywhere in the message — a hook that
  /// legitimately throws its own "timed out" message (the sibling test in
  /// `_isExtensionRuntimeDead`'s group) must stay loud. Two prefixes cover
  /// `ClientException`: `package:http`'s `IOClient` wraps a socket-layer
  /// failure (DNS, connection refused mid-send) in its own subclass whose
  /// `toString()` reads `'ClientException with $cause, uri=$uri'` — a plain
  /// `http.ClientException` reads `'ClientException: $message'` — so both
  /// forms need matching or a "Failed host lookup" falls through to notify.
  static bool _isFetchTransportTransient(Object error, FlutterErrorDetails? details) => _isHostFetchTransport(error);

  static bool _isHostFetchTransport(Object error) {
    if (error is! ExtensionHostException) return false;
    return error.message.startsWith('ClientException:') || error.message.startsWith('ClientException with ') || error.message.startsWith('TimeoutException');
  }

  /// Whether [error] means the other end never answered — a timeout, or a
  /// connection that could not be made, was refused, or was reset — as
  /// opposed to one that answered with something we did not like.
  ///
  /// Public because it is not only a rule matcher: `SyncEngine` is the app's
  /// connectivity probe (see `ConnectivityService`), and what it needs to
  /// know about a failed round is exactly this question. A second copy of
  /// the answer over there would be a second definition of "the network is
  /// down", which is the thing that card exists to remove.
  ///
  /// Deliberately narrow to the two INTERNET-facing shapes: `hostFetch`,
  /// which reaches this app only ever wrapped in an [ExtensionHostException],
  /// and direct `package:http` callers. A bare `SocketException` is not here
  /// on purpose — peer sync's LAN transport throws those, and a BLE or LAN
  /// link failing is a real, reportable fault that has nothing to do with
  /// internet reachability (`peer_service.dart` keeps those apart for a
  /// related reason).
  /// A bare [TimeoutException] is likewise absent: it is thrown all over the
  /// app for waits that have no network in them.
  static bool isTransportFailure(Object error) => error is ClientException || _isHostFetchTransport(error);

  /// The prefix is `extensions/sync/ham2k-lofi/src/index.ts`'s `sync()`
  /// wrapping the original LoFi error when its own fallback capture to the
  /// backup service also throws -- deliberately distinct from any message
  /// [_isFetchTransportTransient] or a bare `LoFiRequestError` would produce,
  /// so this never accidentally shadows an ordinary LoFi failure.
  static bool _isLoFiBackupCaptureAlsoFailed(Object error, FlutterErrorDetails? details) {
    if (error is! ExtensionHostException) return false;
    return error.message.startsWith('LoFi sync failed and the backup capture also failed:');
  }

  /// Any direct `package:http` caller's own `Client.send()` failing below
  /// the application layer — `DataFileManager.downloadFile` is the one that
  /// reaches this app's global handling today (the others all catch their
  /// own failures locally); unlike `hostFetch`, which never reaches this app
  /// as anything but an [ExtensionHostException]. The type alone is narrow
  /// enough to match on — no message to go stale against, unlike
  /// [_isFetchTransportTransient] — because `http.ClientException` is never
  /// thrown for any reason OTHER than a failure sending or receiving the
  /// request; on web that includes a cross-origin block alongside a plain
  /// outage (see the doc comment on `friendlyDownloadError`), which is
  /// exactly why this app already shows the operator one hint covering both
  /// rather than trying to tell them apart — so `report`, not `logOnly`, to
  /// keep whichever one it was visible in aggregate.
  ///
  /// Deliberately NOT `TimeoutException`, which is too generic to match
  /// app-wide; a download's own timeout arrives wrapped, as a
  /// `DataFileUnavailable`.
  static bool _isHttpClientConnectionTransient(Object error, FlutterErrorDetails? details) => error is ClientException;

  /// [CatalogUnreachable] wrapping the transport failure CatalogService
  /// caught — a `ClientException`, the `TimeoutException` its own
  /// `.timeout()` threw, or a `dart:io` [IOException] IOClient hands up
  /// unwrapped (a TLS handshake refused, a socket reset) — or
  /// [CatalogRefused], a response with an error status. The wrappers are
  /// what keep this narrow: a bare TimeoutException stays loud everywhere
  /// else (see [_isHttpClientConnectionTransient]), and a 200 that could not
  /// be read is wrapped in neither.
  static bool _isCatalogUnreachable(Object error, FlutterErrorDetails? details) =>
      error is CatalogRefused ||
      (error is CatalogUnreachable && (error.cause is ClientException || error.cause is TimeoutException || error.cause is IOException));

  /// A [MapError] stamped offline at arrival. The stamp is the whole match:
  /// with no network there is nothing a map backend can fetch, so every
  /// style, tile and token check fails as a matter of course — on a summit
  /// or in a park that is the session's normal state, and uploading it
  /// would bury the online failures this type exists to surface. The same
  /// error raised ONLINE (a bad token, a style that won't parse, a layer
  /// bug of ours) matches nothing and uploads.
  /// A call that got no answer, raised while we already believe we have no
  /// internet. Both halves are the match, and each does necessary work:
  ///
  ///  * The SHAPE, so that an error which merely happened during an outage —
  ///    a parse bug, a bad token, anything the code got wrong — still uploads.
  ///    Being offline is not a licence to stop reporting our own defects.
  ///  * The STATE, so that the same timeout ONLINE keeps the `report`
  ///    disposition the two rules below give it. A TCP blip on a working
  ///    network is worth seeing in aggregate; the two-hundredth one on a
  ///    summit with no bars is not.
  ///
  /// `ConnectivityService.isOffline` starts false and only ever becomes true
  /// once something has actually failed to answer, so the window this
  /// quietens is one the app has already measured rather than assumed.
  static bool _isNetworkErrorWhileOffline(Object error, FlutterErrorDetails? details) => ConnectivityService.isOffline && isTransportFailure(error);

  /// The connection shapes of [isTransportFailure] — a lookup, a refusal, a
  /// reset — without its `TimeoutException`.
  static bool _isSyncPullStuckWhileOffline(Object error, FlutterErrorDetails? details) {
    if (error is! SyncPullStuck || !ConnectivityService.isOffline) return false;
    final cause = error.cause;
    return cause is ClientException ||
        (cause is ExtensionHostException && (cause.message.startsWith('ClientException:') || cause.message.startsWith('ClientException with ')));
  }

  static bool _isMapErrorWhileOffline(Object error, FlutterErrorDetails? details) => error is MapError && error.offline;

  static bool _isWebsitePanelErrorWhileOffline(Object error, FlutterErrorDetails? details) => error is WebsitePanelError && error.offline;

  static final _oncePerSessionLogged = <String>{};

  /// Print the console line [decision] calls for, if any. Returns whether
  /// anything was printed, so callers that also dump the error themselves
  /// (report()'s own line) don't double up.
  ///
  /// A quiet tier is the ONLY output a classified error gets — the handler
  /// returns before `FlutterError.presentError`, which is what would
  /// otherwise dump the stack. So [stackTrace] is printed with it: a
  /// logOnly rule exists because the bug is ours to fix locally, and the
  /// framework's message names the widget that suffered, never the call
  /// that did it. The ignore tier is the exception, deliberately: its whole
  /// point is that there is nothing there to fix.
  static bool logDecision(ErrorDecision decision, Object error, {StackTrace? stackTrace}) {
    final rule = decision.rule;
    if (rule == null) return false;
    if (rule.logOncePerSession) {
      if (!_oncePerSessionLogged.add(rule.id)) return true;
      debugPrint('[error-policy] ignoring ${rule.id}: ${rule.reason}');
      return true;
    }
    debugPrint(
      '[error-policy] ${rule.id} (${rule.disposition.name}, ${rule.reason}): $error'
      '${stackTrace == null ? '' : '\n$stackTrace'}',
    );
    return true;
  }

  /// Matches drift's post-close complaints, and only while quitting.
  ///
  /// Their timing is what makes them harmless, not their text: nothing but
  /// the exit hook ever closes the database, so mid-session these would mean
  /// something closed it that shouldn't have — which stays loud.
  ///
  /// The FIRST message is the one the shipped app raises, and the only one
  /// worth checking a change against: `driftDatabase()` runs SQLite on a
  /// background isolate, so a write past the close never reaches the executor
  /// that would raise either of the others — it fails at the isolate channel.
  /// The other two are the in-process shapes, which tests and any future
  /// same-isolate connection raise instead.
  ///
  /// drift's own `ConnectionClosedException` — a request already in flight
  /// when the channel closes — is deliberately NOT matched: it isn't exported
  /// from `package:drift`, and matching it by `toString()` would mean calling
  /// that on an object we haven't type-checked, which this file must never do
  /// (an app object whose `toString()` throws would take the error handler
  /// down with it).
  static bool _isDatabaseClosedOnExit(Object error, FlutterErrorDetails? details) {
    if (!appIsExiting || error is! StateError) return false;
    final message = error.message;
    return message.contains('over isolate channel, but the connection was closed') ||
        message.contains('re-open a database after closing it') ||
        message.contains('has already been closed');
  }

  /// Test seam: forget the once-per-session log state, the web override and
  /// the exiting flag. Not marked `@visibleForTesting` because
  /// ErrorReportingService's own reset calls it — that state belongs to a
  /// session, and tests reset a session through one door.
  static void resetForTesting() {
    _oncePerSessionLogged.clear();
    debugTreatAsWeb = null;
    appIsExiting = false;
  }
}
