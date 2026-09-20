// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Owns the app's single ExtensionHost instance (background isolate) and exposes
// domain-shaped calls on top of raw hook invocations. Boots asynchronously at
// app start; every caller must tolerate `ready == false` — a missing or
// broken extension runtime degrades features, never the core loop.

import 'dart:async';
import 'dart:collection';
import 'dart:convert';

import 'package:flutter/foundation.dart' show setEquals;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:halo_extension_host/halo_extension_host.dart';
// Prefixed alias of the same public library, so the forwarders below can
// reach the shared functions without recursing into themselves.
import 'package:halo_extension_host/halo_extension_host.dart' as priority;
import 'package:halo_core/halo_core.dart';
import 'catalog_service.dart';
import 'connectivity_service.dart';
import 'error_reporting_service.dart';
import 'export_type_registry.dart';
import 'extension_account_cache.dart';
import 'extension_info.dart';
import 'extension_keychain.dart';
import 'extension_messages.dart';
import 'extension_ref_results.dart';
import 'extension_catalog_migration.dart';
import 'extension_disabled_since.dart';
import 'extension_secrets.dart';
import 'installed_extensions.dart';
import 'preloaded_extensions.dart';
import 'location_service.dart';
import 'panel_service.dart';
import 'radio_host_calls.dart';
import 'settings_service.dart';
import 'spots_service.dart';
import 'status_bar_service.dart';
import 'package:halo_widgets/halo_widgets.dart';

import '../config/secrets.dart';
import '../config/dev_flags.dart';
import '../config/experiments.dart';
import '../config/dev_fixture.dart';
import '../config/user_agent.dart';
import '../config/version.dart';

import 'package:halo_i18n/halo_i18n.dart';
import '../config/navigation.dart';
import '../tools/backoff.dart';
import '../tools/activity_suggestions.dart';
import '../tools/qso_patch.dart';

// The types callers pair with the runtime: one import serves both.
export 'extension_info.dart';
export 'extension_ref_results.dart';

/// This device's LoFi identity: the Pusher channel to subscribe
/// to, and the signed token a webhook-relayed OAuth login embeds in its
/// `state` param. Returned by [ExtensionService.ensureLofiClientRegistered]
/// and [HaLoServices.connectLofiRealtime] alike.
typedef LofiClientRegistration = ({String pushChannelName, String webhookClientToken});

/// What the activity picker's search came back with, and whether it came back
/// at all. [allSourcesFailed] separates "no extension had a match" from "no
/// extension could answer" — identical empty lists that mean opposite things
/// to the operator.
typedef ActivitySuggestionResult = ({List<Map<String, dynamic>> suggestions, bool allSourcesFailed});

/// The control descriptors an activity fan-out produced, and whether any
/// source failed to answer. [loadFailed] separates "no extension declares
/// controls" from "an extension that does declare them could not answer" —
/// identical empty lists, and only the second may not be treated as the
/// operator's ref types being unknown. Without it a hook that throws or
/// times out is indistinguishable from its extension being uninstalled, and
/// `isUnknownRefType` says exactly that to the operator.
typedef ControlsResult = ({List<Map<String, dynamic>> controls, bool loadFailed});

/// How far a screen's [ControlsResult] fetch has got. A bool cannot express
/// [failed] — it only says "not loaded yet" — so a fetch that threw leaves a
/// two-state screen showing its loading placeholder forever, with the
/// unknown-ref treatment suppressed the whole time.
enum ControlsLoadState { loading, loaded, failed }

/// The QSON payload shape shared by every hook that takes a whole operation's
/// worth of QSOs in one coarse call (export, scoring, …) — `operation.data`
/// with `uuid` folded in, plus each QSO's raw QSON `data`.
///
/// The operator is RESOLVED here rather than left to `operation.data`, because
/// with a position set it lives in that position's own slot (see
/// [operatorCallFor]) and only this side knows which seat this device is in.
/// It is written under both names the extensions read:
/// `operation.operatorCall` for the REG1TEST/EDI writers, and
/// `operation.local.operatorCall` for the ADIF `OPERATORS` header — without
/// which those exports name nobody, or fall back to the station call.
///
/// `local` carries that one field and not the whole blob: `localData` also
/// holds the scoring cache and the title fragments, which have no business in
/// an export payload crossing the extension bridge.
Map<String, dynamic> qsonPayloadFor({required Operation operation, required List<Qso> qsos}) {
  final operatorCall = operatorCallFor(operation);
  return {
    'operation': {
      ...operation.data,
      'uuid': operation.uuid,
      'operatorCall': operatorCall,
      'local': {'operatorCall': operatorCall},
    },
    'qsos': [for (final qso in qsos) qso.data],
  };
}

/// What one `invokeHookAll` fan-out actually produced, split by outcome.
typedef HookPartition = ({
  List<Map<String, dynamic>> items,
  List<String> succeeded,
  List<String> unreachable,
  List<({String key, String? error})> failed,
});

/// The partition of a fan-out that never happened — no hooks ran, so nothing
/// succeeded and nothing is in trouble.
const HookPartition emptyHookPartition = (
  items: <Map<String, dynamic>>[],
  succeeded: <String>[],
  unreachable: <String>[],
  failed: <({String key, String? error})>[],
);

/// A spot from [hookKey] whose `their`/`freq`/`refs`/`spot` field — or
/// `their.call`/a `refs` entry, one level inside an otherwise right-typed
/// container — is the wrong type for spots_panel.dart's and
/// spots_service.dart's readers. The hook bridge enforces nothing about a JS
/// extension's declared TypeScript types at runtime, so a numeric-string API
/// field that slips past an extension's own coercion arrives here as a
/// `String` where every reader expects a `num`. Classified `report` in
/// [ErrorPolicy]: worth fixing in the offending extension, not worth the
/// operator's other, unaffected spot sources going quiet or a notice
/// interrupting them over it.
class MalformedSpotDataException implements Exception {
  MalformedSpotDataException(this.hookKey, this.field, this.value);
  final String hookKey;
  final String field;
  final Object? value;

  @override
  String toString() => 'MalformedSpotDataException: hook "$hookKey" field "$field" is ${value.runtimeType}';
}

/// A `scoring` hook that threw, timed out, or was unreachable — one scorer
/// failing a pass, never the pass itself. Classified `report` in
/// [ErrorPolicy]: a broken scorer is a defect in that extension, and there is
/// nothing the operator can do about it mid-activation, so it goes to the
/// crash backend without a notice.
///
/// What it costs is worth stating: the pass returns without that scorer's
/// verdicts, so on the spots board its contributions are simply ABSENT — no
/// duplicate strike from `core`, no multiplier accent from a contest scorer.
/// An absence looks like a quiet board rather than like a failure, which is
/// exactly why this reaches the backend rather than only the console.
class ScoringHookFailure implements Exception {
  ScoringHookFailure(this.scorerKey, this.method, this.cause);
  final String scorerKey;
  final String method;
  final Object cause;

  @override
  String toString() => 'ScoringHookFailure: scorer "$scorerKey" failed $method: $cause';
}

/// The [ErrorReportingService.reportIfRepeated] key for one scorer's failures
/// of one method. Per scorer AND per method so a contest scorer stuck on the
/// spots pass cannot mask the core scorer breaking on the logging one.
String _scorerFailureKey(String scorerKey, String method) => 'scoring:$scorerKey:$method';

/// Reports one scorer's failure to the crash backend, at most once per scorer
/// per method until it succeeds again — a pass runs every couple of minutes
/// for as long as an operation is open, so a scorer broken for a four-hour
/// activation is one event, not a hundred. [ErrorReportingService.recordSuccess]
/// on the answering path is what re-arms it, making a second event mean a
/// second outage.
void _reportScorerFailure(String scorerKey, String method, Object error, StackTrace stackTrace) {
  ErrorReportingService.reportIfRepeated(
    _scorerFailureKey(scorerKey, method),
    ScoringHookFailure(scorerKey, method, error),
    stackTrace,
    context: 'scoring:$scorerKey:$method',
    threshold: 1,
  );
}

/// The first top-level field on [spot] whose type spots_panel.dart's/
/// spots_service.dart's readers don't tolerate, or null if every field
/// present is shaped as expected. `their.call` and each `refs` entry are
/// checked one level deep — the two places a reader dereferences INTO an
/// already-right-typed container rather than just reading it.
String? _malformedSpotField(Map<String, dynamic> spot) {
  final their = spot['their'];
  if (their != null && their is! Map) return 'their';
  if (their is Map && their['call'] != null && their['call'] is! String) return 'their';

  final freq = spot['freq'];
  if (freq != null && freq is! num) return 'freq';

  final refs = spot['refs'];
  if (refs != null && refs is! List) return 'refs';
  if (refs is List && refs.any((r) => r is! Map)) return 'refs';

  final inner = spot['spot'];
  if (inner != null && inner is! Map) return 'spot';
  if (inner is Map && inner['timeInMillis'] != null && inner['timeInMillis'] is! num) return 'spot';

  return null;
}

/// Drops any spot [_malformedSpotField] flags, reporting the first one per
/// [hookKey] to the crash backend — see [MalformedSpotDataException]. A spot
/// missing a field outright is untouched; that is an ordinary absence the
/// readers already handle, not a bridge-contract violation. Public for
/// `hook_partition_test.dart`.
List<Map<String, dynamic>> validSpots(List<Map<String, dynamic>> items) {
  final valid = <Map<String, dynamic>>[];
  for (final spot in items) {
    final badField = _malformedSpotField(spot);
    if (badField != null) {
      final hookKey = spot['hookKey'] as String? ?? 'unknown';
      ErrorReportingService.reportIfRepeated(
        'getSpots:malformed:$hookKey',
        MalformedSpotDataException(hookKey, badField, spot[badField]),
        null,
        context: 'getSpots:malformed:$hookKey',
        threshold: 1,
      );
      continue;
    }
    valid.add(spot);
  }
  return valid;
}

/// Whether a hook's failure was the network rather than the service.
///
/// The markers are the ones `ErrorPolicy._isFetchTransportTransient` already
/// classifies on, matched the same way — by PREFIX, because a hook that
/// legitimately throws its own message mentioning a timeout must not be
/// mistaken for the transport dropping under it. `host.fetch` rejections
/// cross the bridge stringified and unwrapped, so a dead network arrives here
/// as `ClientException: Failed host lookup: '<host>'` — or, from IOClient's
/// own socket-wrapping subclass, `ClientException with Failed host lookup:
/// '…', uri=…` — so both prefixes need matching, same as the
/// ErrorPolicy rule this mirrors.
bool isTransportFailure(String? error) {
  if (error == null) return false;
  return error.startsWith('ClientException:') ||
      error.startsWith('ClientException with ') ||
      error.startsWith('SocketException:') ||
      error.startsWith('TimeoutException');
}

/// Splits a fan-out's settled entries into the list items each hook
/// contributed and the keys of the hooks that contributed nothing, by why.
///
/// A hook is in at most one of [HookPartition.unreachable] and
/// [HookPartition.failed], and the split is by what the operator should do:
/// nothing came back over the network (wait) versus the service answered and
/// refused (stop expecting spots). An operator told the wrong one goes
/// looking in the wrong place.
///
/// A transport failure is [HookPartition.unreachable], not a service error —
/// otherwise a device with no signal reports every healthy feed it has as
/// broken, which is the commonest way this fan-out fails and the one where
/// the advice matters most. A hook that doesn't implement the method at all
/// produces no entry — the kernel filters the roster before calling anything.
///
/// Each entry is read under its own guard: one malformed payload must not
/// discard what has already been learned about the others, including which of
/// them went quiet, which is the one thing a caller cannot re-derive.
HookPartition partitionHookEntries(List<Map<String, dynamic>> entries) {
  final items = <Map<String, dynamic>>[];
  final succeeded = <String>[];
  final unreachable = <String>[];
  final failed = <({String key, String? error})>[];
  for (final entry in entries) {
    try {
      final hookKey = entry['key'] as String?;
      if (hookKey == null) continue;
      final error = entry['error']?.toString();
      if (entry['ok'] == true) {
        succeeded.add(hookKey);
        if (entry['value'] is! List) continue;
        for (final item in (entry['value'] as List)) {
          if (item is Map) items.add({...item.cast<String, dynamic>(), 'hookKey': hookKey});
        }
      } else if (entry['timedOut'] == true || isTransportFailure(error)) {
        unreachable.add(hookKey);
      } else {
        failed.add((key: hookKey, error: error));
      }
    } catch (e) {
      debugPrint('[extensions] unreadable hook entry "${entry['key']}": $e');
    }
  }
  return (items: items, succeeded: succeeded, unreachable: unreachable, failed: failed);
}

/// The station call a SELF-spot is posted under: the operation's own
/// `stationCall` carrying the two suffixes the app applies centrally, rather
/// than in each activity extension — every one of them builds its spotted
/// call straight from `operation.stationCall`, so a rule left to them is a
/// rule the next spot extension forgets.
///
///  * A Test Operation reports `/TEST` (`KI2D/TEST`) rather than whatever
///    shorter suffix the operation itself uses (`KI2D/T`), so the spot reads
///    unambiguously to hunters. Every comma-separated call takes it.
///  * A multi-station operation — several operators logging one operation
///    under one station call, a device each — appends this device's `/OP<n>`
///    so the devices' spots stay distinguishable (`KI2D/OP1`, `KI2D/OP2`).
///    `n` is `localData['multiIdentifier']`, reaching this payload as
///    `operation['local']` (app-polo's `operation.local`); absent or empty
///    means a plain single-station operation. Only the FIRST of a
///    comma-separated call takes it, as in app-polo, where the additional
///    calls (`stationCallPlusArray`) are spotted bare.
///
/// Other-spots post the spotted station's OWN call, so neither rule reaches
/// them — see [ExtensionService.sendSpot].
String spotCallForSelfSpot(Map<String, dynamic> operation) {
  // Probed, not cast, like the identifier below: this operation blob crossed
  // the extension bridge, and a cast that throws here takes the spot with it.
  final stationCall = asQsonString(operation['stationCall']) ?? '';
  final withTest =
      Operation(uuid: '', data: operation).isTestOperation ? _spotCallForTestOperation(stationCall) : stationCall;
  final local = operation['local'];
  // `toString()`, not a cast: this arrives across the extension bridge, where
  // a number would throw inside the spot path and surface as a generic
  // "something went wrong" with nothing to say a spot had failed.
  final identifier = normalizedMultiIdentifier(local is Map ? (local['multiIdentifier']?.toString() ?? '') : '');
  if (identifier.isEmpty) return withTest;
  final calls = withTest.split(',');
  if (calls.first.trim().isEmpty) return withTest;
  calls[0] = '${calls.first.trim()}/OP$identifier';
  return calls.join(',');
}

/// Rewrites every comma-separated call's trailing `/T` to `/TEST` — see
/// [spotCallForSelfSpot]. A call already ending `/TEST` is left alone.
String _spotCallForTestOperation(String stationCall) => stationCall
    .split(',')
    .map((call) {
      final trimmed = call.trim().toUpperCase();
      return trimmed.endsWith('/T') ? '${trimmed.substring(0, trimmed.length - 2)}/TEST' : trimmed;
    })
    .join(',');

/// A template the renderer refused — see [ExtensionService.renderTemplate].
/// The message is the renderer's own, written for the operator who typed
/// the template.
class TemplateError implements Exception {
  final String message;
  const TemplateError(this.message);
  @override
  String toString() => message;
}

class ExtensionService implements PanelExtensionSource, PanelEventSource {
  ExtensionHost? _host;
  Future<void>? _starting;
  Timer? _restartTimer;
  int _restartAttempts = 0;

  /// The in-flight [_replaceRuntime] call, if any — [commitSettingsFieldValue]
  /// awaits this instead of bailing out when [host] is momentarily null
  /// mid-restart, so a commit that lands in that window still reaches the
  /// fresh runtime instead of silently no-oping.
  Future<void>? _restartFuture;

  /// Set by [shutdownForExit], never cleared: from then on nothing brings a
  /// runtime back, because a runtime alive while the VM tears down is the
  /// crash that method exists to prevent.
  bool _exiting = false;

  /// True when the last runtime start proceeded past the bounded activation
  /// wait without every extension's onActivation settling — hook
  /// registrations may be INCOMPLETE for this generation. Consumers that
  /// treat the hook set as authoritative (the data-file orphan purge) must
  /// check this and stand down rather than act on a partial picture.
  bool get activationIncomplete => _activationIncomplete;
  bool _activationIncomplete = false;
  ({String deviceKey, String operatorCall})? _lastSyncCredentials;

  static const _keychainAccountName = 'Ham2K Logger';

  /// Rows fetched for `getHistoryForCall` — the `call-history` lookup source
  /// only ever reads the single most recent match, so a small cap with room
  /// to skip past the QSO being re-enriched is plenty.
  static const _historyForCallLimit = 5;


  final _secureStorage = const FlutterSecureStorage(
    mOptions: MacOsOptions(
      // FILE keychain on macOS. The data-protection keychain needs the RESTRICTED
      // keychain-access-groups entitlement, which a Developer ID build can't
      // carry (no provisioning profile → spawn crash), so it fails every
      // save with errSecMissingEntitlement (-34018). The file keychain needs no
      // entitlement and works under the sandbox.
      // A future Mac App Store build has a profile and can switch back.
      usesDataProtectionKeychain: false,
      accountName: _keychainAccountName,
    ),
    iOptions: IOSOptions(
      accountName: _keychainAccountName,
    ),
  );

  /// Per-account iCloud Keychain sync flag (`kSecAttrSynchronizable`), keyed
  /// by account `kvKey`, as declared by each extension's `account` hook
  /// (`synchronizable`, default false). Resolved ONCE from the account
  /// definitions at runtime start (see [_refreshAccountSynchronizable], called
  /// from [_start], which also covers every restart) so that every read/write/
  /// delete for a given key uses the SAME flag: a synchronizable and a
  /// non-synchronizable item are DISTINCT keychain entries, so a mismatch
  /// would silently miss. An unknown key defaults to false — the fail-safe is
  /// "never accidentally sync". Only `account_creds_`/`account_session_` items
  /// consult this; secret settings fields stay device-local (the default).
  final Map<String, bool> _accountSynchronizable = {};

  /// The resolved flags, so a test can assert the boot-time refresh actually
  /// captured them. Nothing else observes this map directly — its effect is a
  /// keychain option on a platform tests don't run on — so without this the
  /// only provable symptom of the refresh failing is a log line.
  @visibleForTesting
  Map<String, bool> get accountSynchronizable => Map.unmodifiable(_accountSynchronizable);

  /// Completes once [_refreshAccountSynchronizable] has resolved the flags for
  /// the current runtime generation (or start failed) — reset per [_start],
  /// completed in its `finally`. Account access awaits this so an early lookup
  /// (the lookup queue gates on [ready], which flips true before the flags are
  /// cached) can't read a synchronizable account under the wrong flag and miss
  /// it. A fresh, never-started service leaves it pending, so
  /// [_accountKeychainOptions] only awaits it when a start is actually in play.
  Completer<void> _accountSyncReady = Completer<void>();

  /// True while [_refreshAccountSynchronizable] is in flight.
  ///
  /// The refresh asks the kernel for the account definitions, and the kernel
  /// answers by CALLING BACK into Dart (`getAccount`, to build the hook ctx for
  /// any account member that is a function). Without this flag that host call
  /// waits on [_accountSyncReady] — the completer the refresh itself is on its
  /// way to completing — and the two wait on each other until the hook times
  /// out. See [_accountKeychainOptions].
  bool _refreshingAccountSynchronizable = false;

  /// See [AccountContextCache] for what this is and the invariant every
  /// writer of an account item below keeps.
  final _accountItems = AccountContextCache();

  /// The bypass flag as a seam, so a test can pin that a read made while the
  /// flag refresh is in flight never lands in the cache.
  @visibleForTesting
  set debugRefreshingAccountSynchronizable(bool value) => _refreshingAccountSynchronizable = value;

  /// Rebuilds [_accountSynchronizable] from the current account definitions.
  /// Best-effort: a failure leaves accounts device-local, never crashes boot.
  Future<void> _refreshAccountSynchronizable() async {
    _refreshingAccountSynchronizable = true;
    try {
      final accounts = await getAccounts();
      // Couldn't ask (already logged by getAccounts). Leave whatever the last
      // successful refresh resolved in place rather than wiping it: on a
      // restart, stale flags still describe the accounts the user has, while
      // an empty map silently reads and writes every account under the
      // device-local default — the exact miss this cache exists to prevent.
      if (accounts == null) return;
      _accountSynchronizable
        ..clear()
        ..addEntries(accounts
            .where((a) => a['kvKey'] is String)
            .map((a) => MapEntry(a['kvKey'] as String, a['synchronizable'] == true)));
    } catch (e) {
      debugPrint('[extensions] refreshAccountSynchronizable failed: $e');
    } finally {
      _refreshingAccountSynchronizable = false;
    }
  }

  /// The complete keychain options for one account's items, matching the
  /// instance defaults but with the account's declared `synchronizable` flag.
  /// Per-call options REPLACE (don't merge with) the instance defaults, so
  /// the data-protection-keychain and account-name settings are repeated here.
  ///
  /// Awaits [_accountSyncReady] first (only while a start is in flight, so a
  /// never-started service doesn't hang) so the flag is resolved before the
  /// first read/write. Near-free once the flags are cached.
  ///
  /// macOS: a synchronizable item requires the data-protection keychain, but the
  /// app uses the FILE keychain on macOS (Developer ID can't carry the
  /// keychain-access-groups entitlement the data-protection keychain needs — see
  /// the instance default), so macOS accounts are never synchronizable and stay
  /// device-local. iOS always uses the data-protection keychain, so it syncs when
  /// the account declares it. Both keep `synchronizable` and
  /// `usesDataProtectionKeychain` from ever contradicting.
  /// [fromHostCall] marks the calls the extension runtime makes back into us
  /// while a hook is running. Those must never wait on [_accountSyncReady]
  /// during [_refreshAccountSynchronizable]: the refresh is what completes that
  /// completer, and it cannot finish until the hook it is waiting on returns —
  /// which cannot happen until this call does. Deliberately NOT a blanket
  /// bypass: direct Dart callers (a lookup firing as soon as [ready] flips)
  /// still wait, because getting them the right flag is the whole reason the
  /// gate exists.
  ///
  /// Bypassing yields the device-local defaults. Without the bypass the
  /// refresh deadlocks and times out, leaving the flag map empty for the
  /// whole session — so the bypass is never worse, and unlike the deadlock
  /// the flags are correct a moment later.
  Future<({MacOsOptions mOptions, IOSOptions iOptions})> _accountKeychainOptions(
    String kvKey, {
    bool fromHostCall = false,
  }) async {
    final wouldDeadlock = fromHostCall && _refreshingAccountSynchronizable;
    if (!wouldDeadlock && !_accountSyncReady.isCompleted && (_starting != null || _host != null)) {
      await _accountSyncReady.future;
    }
    final declared = _accountSynchronizable[kvKey] ?? false;
    return (
      mOptions: MacOsOptions(
        // File keychain on macOS (see the instance default), so accounts can't
        // be synchronizable here — kSecAttrSynchronizable requires the
        // data-protection keychain, which Developer ID can't use. macOS account
        // creds stay device-local; iOS (always data-protection) still syncs when
        // the account declares it.
        usesDataProtectionKeychain: false,
        accountName: _keychainAccountName,
        synchronizable: false,
      ),
      iOptions: IOSOptions(
        accountName: _keychainAccountName,
        synchronizable: declared,
      ),
    );
  }

  SettingsService? settings;
  LookupRepository? lookups;
  StatusBarService? statusBar;

  /// Back the `getOperation`/`getQsos` host calls (HookContext.getOperation/
  /// getQsos in the SDK). Optional like the other service references — a
  /// host without them (bench harnesses, focused tests) answers those calls
  /// with null/empty instead of failing.
  OperationsRepository? operations;
  QsosRepository? qsos;

  /// Backs the `getLocation` host call (SDK's `host.getLocation()`) — a
  /// one-shot device GPS fix for a command with no operation grid to fall
  /// back to. Optional like the other service references above.
  LocationService? location;

  /// The radio host calls, behind their manifest capabilities.
  final radioCalls = RadioHostCalls();

  /// Backs the `getSpotsForCall` host call (HookContext.getSpotsForCall),
  /// which the `spot-history` lookup hook reads. Optional like the other
  /// service references — a host without it answers with an empty list, so
  /// the hook simply contributes nothing.
  SpotsService? spots;

  /// Where a withdrawn built-in's twin is fetched from. Null before
  /// HaLoServices wires it, which simply means nothing is adopted.
  CatalogService? catalog;

  /// Who may call `getLocation` (manifest.json `requiresLocation`), resolved
  /// once at load time in [_start].
  CapabilityGrant _location = const CapabilityGrant();

  bool get ready => _host != null;
  ExtensionHost? get host => _host;

  Future<void> start() {
    if (_exiting) return Future.value();
    // Attached here rather than in a constructor: the service is built long
    // before any runtime exists, and this is the one path every start (and
    // every restart, through _start) goes through.
    if (!_clockListenerAttached) {
      _clockListenerAttached = true;
      AppClock.instance.addListener(_pushClockTravel);
    }
    return _starting ??= _start();
  }

  bool _clockListenerAttached = false;

  /// Every extension-declared account, or null when the extensions could not
  /// be asked at all — no runtime yet, a dead one, or the fan-out failing or
  /// timing out. That is deliberately distinct from an empty list ("asked,
  /// and nobody declares an account"): the two look identical to a caller but
  /// mean opposite things, and a caller that caches the answer must never
  /// cache a failure (see settings_view's `_accountsCache`). Failures are
  /// logged here rather than thrown, so a caller that has nothing better to do
  /// can still treat null as "no accounts" with `?? const []`.
  Future<List<Map<String, dynamic>>?> getAccounts() async {
    final host = this.host;
    if (host == null) return null;
    try {
      final entries = await host.invokeHookAll('account', method: 'getDefinition', timeout: const Duration(seconds: 2));
      final accounts = <Map<String, dynamic>>[];
      for (final entry in entries) {
        if (entry['ok'] == true && entry['value'] is Map) {
          accounts.add((entry['value'] as Map).cast<String, dynamic>());
        }
      }
      return accounts;
    } catch (e) {
      debugPrint('[extensions] getAccounts failed: $e');
      return null;
    }
  }

  /// Fans a call out to every hook in `category` via `invokeHookAll`,
  /// flattens each hook's returned list, and tags every item with
  /// `hookKey` — the hook's own registration key — so a later call can be
  /// routed back to the hook that offered it. Hooks that don't implement
  /// `method`, or whose call fails, are silently absent from the result
  /// (a failing source never poisons the others). Shared by `getExportOptions`
  /// and `getSpots`, which otherwise just differ by category/method/args.
  /// [partialOnTimeout] keeps the hooks that did answer when the shared
  /// budget expires, instead of discarding the lot — and names the ones that
  /// didn't in `unreachable`. Only worth setting where the hooks are
  /// independent contributors and some data beats none.
  ///
  /// `unreachable` and `failed` are separate buckets and a hook is in at most
  /// one — see [partitionHookEntries] for what divides them. Only `failed`
  /// feeds the failure streak: a call that never got out to the network says
  /// nothing about whether the code behind it is broken, so counting it would
  /// upload one report per source every time an operator drives out of range.
  ///
  /// `succeeded` names the hooks that answered at all. All three lists empty
  /// means the fan-out never happened — no host, or `invokeHookAll` itself
  /// throwing — which a caller cannot otherwise tell from every hook
  /// answering with nothing.
  Future<
      ({
        List<Map<String, dynamic>> items,
        List<String> succeeded,
        List<String> unreachable,
        List<String> failed
      })> _collectHookResults(
    String category, {
    required String method,
    required Object? args,
    required String debugLabel,
    bool partialOnTimeout = false,
    int failureThreshold = ErrorReportingService.repeatedFailureThreshold,
  }) async {
    final host = _host;
    if (host == null) {
      return (
        items: const <Map<String, dynamic>>[],
        succeeded: const <String>[],
        unreachable: const <String>[],
        failed: const <String>[],
      );
    }
    var parts = emptyHookPartition;
    try {
      parts = partitionHookEntries(await host.invokeHookAll(
        category,
        method: method,
        args: args,
        timeout: const Duration(seconds: 10),
        partialOnTimeout: partialOnTimeout,
      ));
    } catch (e) {
      debugPrint('[extensions] $debugLabel failed: $e');
    }
    // Keyed per call AND per hook: a broken `fetchSpots` must not be masked by
    // a healthy `suggestExportOptions`, nor one dead spot source by four live
    // ones. Paired with recordSuccess, per reportIfRepeated's own contract —
    // without it the streak only ever grows.
    for (final key in parts.succeeded) {
      ErrorReportingService.recordSuccess('$debugLabel:$key');
    }
    for (final failure in parts.failed) {
      // Said out loud, like the panel fan-out does. A hook throwing every
      // cycle — a spot API answering 503, say — otherwise loses its results
      // with nothing recorded anywhere on either side of the bridge, which
      // looks exactly like a source with nothing to offer.
      debugPrint('[extensions] $debugLabel hook "${failure.key}" failed: ${failure.error}');
      // The message is the hook's own, unprefixed: ErrorPolicy's transport
      // rules match on its FIRST characters (`ClientException:`), so a label
      // in front of it would silently opt every fetch failure out of the
      // classification written for it. The label belongs in `context`.
      ErrorReportingService.reportIfRepeated(
        '$debugLabel:${failure.key}',
        ExtensionHostException(failure.error ?? 'hook failed with no error'),
        null,
        context: '$debugLabel:${failure.key}',
        threshold: failureThreshold,
      );
    }
    return (
      items: parts.items,
      succeeded: parts.succeeded,
      unreachable: parts.unreachable,
      failed: [for (final f in parts.failed) f.key],
    );
  }

  /// Consecutive failures before a spot source is worth uploading, well above
  /// [ErrorReportingService.repeatedFailureThreshold].
  ///
  /// Sized for `getSpots`, the only fan-out here that repeats on a timer: at
  /// its two-minute cadence the default of 3 is six minutes, which an
  /// operator reaches by driving through a long tunnel. Ten cycles of a
  /// source erroring is a defect rather than the world being unreliable.
  ///
  /// Ten *cycles*, not twenty minutes: a hook that times out neither raises
  /// the count nor clears it, so a source that alternates errors with dead
  /// spots can take far longer than twenty minutes to get here. Deliberate —
  /// a timeout says nothing either way about whether the service is broken —
  /// but it means the count is not a clock.
  ///
  /// A hand-triggered fan-out keeps the default: ten consecutive Exports
  /// Panel opens is not a threshold anyone reaches, so borrowing this one
  /// would mean never reporting at all.
  static const _spotSourceFailureThreshold = 10;

  /// Every export option offered by every `export` hook (Exports Panel).
  /// Hooks that don't implement
  /// `suggestExportOptions` are silently absent from the list.
  Future<List<Map<String, dynamic>>> getExportOptions(Map<String, dynamic> args) async =>
      (await _collectHookResults(
        'export',
        method: 'suggestExportOptions',
        args: args,
        debugLabel: 'getExportOptions',
      ))
          .items;

  /// A shared type is listed once, using the highest-priority registration.
  Future<List<Map<String, dynamic>>> getExportTypes() async {
    final host = this.host;
    return host == null ? [] : collectExportTypes(host);
  }

  Future<List<Map<String, dynamic>>> exportTypeSettings(
    Map<String, dynamic> global,
    Map<String, dynamic> Function(String type) overrides,
  ) async {
    if (host == null) return [];
    final definitions = await getExportTypes();
    final result = await host!.invokeHook('template', key: 'templates', method: 'exportSettings', args: {
      'definitions': definitions,
      'global': global,
      'overrides': {for (final definition in definitions) definition['exportType'] as String: overrides(definition['exportType'] as String)},
    });
    return (result as List? ?? []).map((value) => Map<String, dynamic>.from(value as Map)).toList();
  }

  Future<List<Map<String, dynamic>>> prepareExports(Map<String, dynamic> args) async {
    final result = await host!.invokeHook('template', key: 'templates', method: 'prepareExports', args: args);
    return (result as List).map((value) => Map<String, dynamic>.from(value as Map)).toList();
  }

  /// Every `spots` hook currently willing to post a spot (Spotting
  /// control), each tagged with `hookKey` so a later
  /// `sendSpot` call can be routed back to it. Calls `isSelfSpotEnabled`
  /// when `qso` is omitted, `isOtherSpotEnabled` otherwise; hooks that don't
  /// implement the relevant method, or report `enabled: false`, are
  /// silently absent — same convention as `getExportOptions`.
  Future<List<Map<String, dynamic>>> suggestSpotSources({
    required Map<String, dynamic> operation,
    Map<String, dynamic>? qso,
  }) async {
    final host = _host;
    if (host == null) return const [];
    final method = qso == null ? 'isSelfSpotEnabled' : 'isOtherSpotEnabled';
    final args = qso == null ? {'operation': operation} : {'qso': qso};
    try {
      final entries = await host.invokeHookAll('spots', method: method, args: args, timeout: const Duration(seconds: 5));
      final sources = <Map<String, dynamic>>[];
      for (final entry in entries) {
        if (entry['ok'] != true || entry['value'] is! Map) continue;
        final value = (entry['value'] as Map).cast<String, dynamic>();
        if (value['enabled'] != true) continue;
        sources.add({...value, 'hookKey': entry['key']});
      }
      return sources;
    } catch (e) {
      debugPrint('[extensions] suggestSpotSources failed: $e');
      return const [];
    }
  }

  /// Every spot offered by every `spots` hook (Spots Panel),
  /// each tagged with `hookKey` so the panel can
  /// group/filter by source.
  ///
  /// Partial on timeout, unlike every other fan-out here: the sources are
  /// independent, so one unreachable feed must not cost the operator the
  /// spots the others already returned. `unreachable` and `failed` name the
  /// feeds nothing came back from and the ones that answered with an error,
  /// which is the difference between "nobody is activating" and "SOTAwatch
  /// didn't reply" — a distinction the spots alone cannot carry, since a
  /// feed that fails contributes no key to group by.
  ///
  /// `succeeded` names the feeds that answered at all, which is what tells a
  /// caller holding previous spots whether a source's silence is news. All
  /// three lists empty means the fan-out itself never ran — no extension
  /// host, or `invokeHookAll` throwing — and says nothing about any feed.
  Future<
      ({
        List<Map<String, dynamic>> items,
        List<String> succeeded,
        List<String> unreachable,
        List<String> failed
      })> getSpots() async {
    final parts = await _collectHookResults(
      'spots',
      method: 'fetchSpots',
      args: const {},
      debugLabel: 'getSpots',
      partialOnTimeout: true,
      failureThreshold: _spotSourceFailureThreshold,
    );
    return (
      items: validSpots(parts.items),
      succeeded: parts.succeeded,
      unreachable: parts.unreachable,
      failed: parts.failed,
    );
  }

  /// `{hookKey: sourceName}` for every `spots` hook, for the Spots Panel's
  /// source filter labels (e.g. `pota` -> "POTA.app"). `sourceName` is a
  /// plain data member on each hook, not a method — `invokeHookAll` returns
  /// it directly without an args/ctx round-trip, same as any other field
  /// access through the hook-call bridge.
  Future<Map<String, String>> getSpotSourceNames() async {
    final host = _host;
    if (host == null) return const {};
    try {
      final entries = await host.invokeHookAll('spots', method: 'sourceName', timeout: const Duration(seconds: 5));
      return {
        for (final entry in entries)
          if (entry['ok'] == true && entry['value'] is String) entry['key'] as String: entry['value'] as String,
      };
    } catch (e) {
      debugPrint('[extensions] getSpotSourceNames failed: $e');
      return const {};
    }
  }

  /// Posts a spot via every hook in `sources` (as returned by
  /// `suggestSpotSources`) concurrently — independent per-source calls, no
  /// ordering dependency between them. Returns `{hookKey: PostResult}` so
  /// the caller can color each source's status icon. `freq`/`mode` are only
  /// used for a self-spot (`qso == null`); spotting an existing QSO derives
  /// them from the QSO itself, JS-side.
  Future<Map<String, Map<String, dynamic>>> sendSpot({
    required List<Map<String, dynamic>> sources,
    required Map<String, dynamic> operation,
    Map<String, dynamic>? qso,
    double? freq,
    String? mode,
    String? comment,
    String? spotterCall,
  }) async {
    final host = _host;
    if (host == null) return const {};
    final method = qso == null ? 'postSelfSpot' : 'postOtherSpot';
    var spotOperation = operation;
    if (qso == null) {
      final spotCall = spotCallForSelfSpot(operation);
      if (spotCall != operation['stationCall']) spotOperation = {...operation, 'stationCall': spotCall};
    }
    final args = qso == null
        ? {'operation': spotOperation, 'freq': freq, 'mode': mode, 'comment': comment}
        : {'qso': qso, 'comment': comment, 'spotterCall': spotterCall};
    final entries = await Future.wait(sources.map((source) async {
      final hookKey = source['hookKey'] as String?;
      try {
        final result = await host.invokeHook(
          'spots',
          key: hookKey,
          method: method,
          args: args,
          timeout: const Duration(seconds: 15),
        ) as Map;
        return MapEntry(hookKey ?? '', result.cast<String, dynamic>());
      } catch (e) {
        return MapEntry(hookKey ?? '', <String, dynamic>{'ok': false, 'message': e.toString()});
      }
    }));
    for (final entry in entries) {
      debugPrint('[spots] $method via ${entry.key}: ${entry.value}');
      final userMessage = entry.value['userMessage'];
      if (userMessage is Map) {
        presentResultMessage(userMessage.cast<String, dynamic>(), ns: entry.key);
      }
    }
    return {for (final entry in entries) entry.key: entry.value};
  }

  Future<String> testCredentials(String accountKey, Map<String, String> credentials) async {
    final host = _host;
    if (host == null) return t.extensionService.runtimeNotReady;
    try {
      final dynamic res = await host.invokeHook(
        'account',
        key: accountKey,
        method: 'testCredentials',
        args: credentials,
        timeout: const Duration(seconds: 10),
      );
      return res is String ? res : res?.toString() ?? '';
    } catch (e) {
      return t.extensionService.testFailed(error: e);
    }
  }

  /// The credentials stored for [kvKey]: a map, `{}` when nothing is stored —
  /// and NULL when secure storage could not be reached at all.
  ///
  /// The distinction is the whole point. An empty map means "this account is not
  /// connected", which is a fact about the account; null means "we cannot know",
  /// which is a fact about the machine — a Linux box with no Secret Service
  /// running, a locked keyring. Collapsing the two would tell an operator
  /// they had been logged out, and invite them to log in again into a store that
  /// cannot keep it.
  ///
  /// Never let this throw: `_loadAccounts` would spin forever and the account
  /// dialog would render with no fields at all, because both read it before
  /// their own `setState`.
  Future<Map<String, String>?> getAccountCredentials(String kvKey) async {
    final o = await _accountKeychainOptions(kvKey);
    final String? raw;
    try {
      raw = await _secureStorage.read(key: 'account_creds_$kvKey', mOptions: o.mOptions, iOptions: o.iOptions);
    } catch (e, st) {
      // EVERYTHING, not just PlatformException: a build where the plugin failed
      // to register raises MissingPluginException, and catching only the former
      // would reopen the exact hang this exists to prevent — `_loadAccounts`
      // reads this before its own `setState`. `KeyringLocked` on Linux covers three
      // different situations anyway (no Secret Service, no default collection,
      // one that would not unlock), so nothing here claims which.
      debugPrint('[extensions] secure storage unavailable reading $kvKey: $e');
      ErrorReportingService.report(e, st, context: 'accounts:read-credentials');
      return null;
    }
    // The keychain answered, and what it holds may differ from the copy — a
    // failure that has since cleared, or a synced item from another device.
    // The session is unknown here, so the entry is evicted rather than
    // rewritten and the next host call rereads both.
    _accountItems.remove(kvKey);
    if (raw == null) return const {};
    try {
      return (jsonDecode(raw) as Map).cast<String, String>();
    } catch (_) {
      return const {};
    }
  }

  Future<void> setAccountCredentials(String kvKey, Map<String, String> credentials) async {
    final o = await _accountKeychainOptions(kvKey);
    final encoded = jsonEncode(credentials);
    await _secureStorage.write(
      key: 'account_creds_$kvKey',
      value: encoded,
      mOptions: o.mOptions,
      iOptions: o.iOptions,
    );
    // Any stored session was derived from the OLD credentials — e.g. OAuth
    // tokens refreshed from a previous login — and could keep acting as the
    // previous account if left behind.
    // A copy saying "no session" over a keychain that still holds the old
    // one would hide that leak until the next launch reads it back.
    if (await _deleteAccountItem('account_session_$kvKey', o)) {
      _accountItems[kvKey] = AccountItems(creds: encoded, session: null);
    } else {
      _accountItems.remove(kvKey);
    }
    // Fresh credentials must reach the very next hook call, not whatever
    // the kernel's context cache still holds.
    _host?.invalidateHookContext();
  }

  Future<void> clearAccount(String kvKey) async {
    final o = await _accountKeychainOptions(kvKey);
    await _deleteAccountItem('account_creds_$kvKey', o);
    await _deleteAccountItem('account_session_$kvKey', o);
    _accountItems.remove(kvKey);
    _host?.invalidateHookContext();
  }

  /// Best-effort keychain delete. Deleting an item that doesn't exist is
  /// fine everywhere except macOS 26, which reports it as
  /// errSecMissingEntitlement (-34018) instead of "not found" — so delete
  /// failures are logged, never thrown. Answers whether the delete went
  /// through, for a caller whose cached copy must not claim more than that.
  Future<bool> _deleteAccountItem(String key, ({MacOsOptions mOptions, IOSOptions iOptions}) o) async {
    try {
      await _secureStorage.delete(key: key, mOptions: o.mOptions, iOptions: o.iOptions);
      return true;
    } catch (e) {
      debugPrint('[extensions] keychain delete $key failed (ignored): $e');
      return false;
    }
  }

  /// The app clock's travel state, in the form the sandbox needs
  /// (docs/design/time.md §6).
  ClockTravelState _clockTravelState() {
    final clock = AppClock.instance;
    return ClockTravelState(
      anchorRealMillis: clock.anchorRealMillis,
      anchorVirtualMillis: clock.anchorVirtualMillis,
      speed: clock.speed,
    );
  }

  /// Pushes a CHANGE of travel into a running sandbox. Registered as an
  /// [AppClock] listener for the life of the service; a runtime that boots
  /// later gets the state through [ExtensionHost.start] instead, which is the
  /// only way to be in place before extensions activate.
  void _pushClockTravel() {
    final clock = _clockTravelState();
    final host = _host;
    if (host == null) {
      // No runtime to push into — the whole of a boot or a restart, which is
      // seconds of bundle loading and activation. Swallowing this leaves the
      // sandbox on a clock the app is not on for the LIFE of that runtime,
      // because a boot already snapshotted the state it started with and
      // nothing reconciles the two afterwards. The re-push at the end of
      // `_start` is what actually closes the window; this says so when it
      // happens.
      debugPrint('[extensions] clock travel not pushed: no runtime yet (re-pushed once it boots)');
      return;
    }
    host.setClockTravel(
      anchorRealMillis: clock.anchorRealMillis,
      anchorVirtualMillis: clock.anchorVirtualMillis,
      speed: clock.speed,
    );
  }

  /// Drops the kernel's cached HookContext so the next hook call sees fresh
  /// core state — call after mutating anything a HookContext carries
  /// (locale, theme, developer mode). No-op before the runtime is up.
  void invalidateHookContext() {
    // The command catalog's `describe` strings are localized by the hook
    // against that same context, so a stale cache would keep the palette in
    // the previous language after a locale switch (⌘⇧L).
    _commandCatalog = null;
    _host?.invalidateHookContext();
  }

  /// Every panel across every extension's `settingsPanel` registration, one
  /// entry per PANEL (not per registration — a Tier 2 hook's `getPanels()`
  /// can fan one registration out to several), sorted by `order`. Each
  /// entry is `{panelKey, hookKey, extensionKey, title, icon, order, kind}`
  /// — `hookKey` is what routes `getSettingsPanelDefinition`/action calls
  /// back to the right registered object; `panelKey` is what's passed as
  /// `args.panelKey`. They're equal for Tier 1; only a multi-panel Tier 2
  /// registration tells them apart.
  Future<List<Map<String, dynamic>>> getSettingsPanels() async {
    final host = this.host;
    if (host == null) return const [];
    try {
      final entries = await host.invokeHookAll('settingsPanel', method: 'getPanels', timeout: const Duration(seconds: 2));
      final panels = <Map<String, dynamic>>[];
      for (final entry in entries) {
        if (entry['ok'] == true && entry['value'] is Map) {
          panels.add((entry['value'] as Map).cast<String, dynamic>());
        }
      }
      panels.sort((a, b) => ((a['order'] as num?) ?? 0).compareTo((b['order'] as num?) ?? 0));
      return panels;
    } catch (e) {
      debugPrint('[extensions] getSettingsPanels failed: $e');
      return const [];
    }
  }

  /// Every panel every `panel` hook contributes, tagged with the `hookKey`
  /// that routes [renderPanel] back to it (see docs/extensions/hooks.md).
  /// Discovery only — nothing here renders anything, and a panel the
  /// operator has not put in a layout is never asked to.
  ///
  /// **Null means "could not ask"** — no runtime yet, or the call failed —
  /// as distinct from an empty list, which means the extensions genuinely
  /// offer no panels. Deliberately NOT [_collectHookResults], whose swallow
  /// to `const []` is right for an additive list (one missing export option
  /// degrades a menu) and wrong here: a caller reconciling a SAVED LAYOUT
  /// against this would read a failed call as "that panel no longer exists"
  /// and throw the operator's arrangement away.
  @override
  Future<List<Map<String, dynamic>>?> getExtensionPanels() async {
    // The getter, not the field, like every other hook call here — the field
    // is invisible to a subclass supplying its own host.
    final host = this.host;
    if (host == null) {
      debugPrint('[extensions] getExtensionPanels: no runtime yet');
      return null;
    }
    try {
      final entries = await host.invokeHookAll(
        'panel',
        method: 'getPanels',
        args: const <String, dynamic>{},
        timeout: const Duration(seconds: 10),
      );
      final results = <Map<String, dynamic>>[];
      for (final entry in entries) {
        // One hook failing is that hook's panels lost, not the catalog's —
        // but it still says so, unlike the whole call failing above.
        if (entry['ok'] != true) {
          debugPrint('[extensions] panel hook "${entry['key']}" getPanels failed: ${entry['error']}');
          continue;
        }
        if (entry['value'] is! List) {
          // A hook resolving with a single object rather than a list would
          // otherwise lose its panels with nothing said anywhere.
          debugPrint('[extensions] panel hook "${entry['key']}" getPanels did not return a list');
          continue;
        }
        for (final item in (entry['value'] as List)) {
          if (item is Map) results.add({...item.cast<String, dynamic>(), 'hookKey': entry['key']});
        }
      }
      return results;
    } catch (e) {
      debugPrint('[extensions] getExtensionPanels failed: $e');
      return null;
    }
  }

  /// One panel's content, right now. Returns null only when there is no
  /// runtime or the hook answered with something that isn't a document; a
  /// hook that throws or times out THROWS here, so the caller can tell "this
  /// panel has nothing to say" from "this panel is broken" and show the
  /// second as a panel-sized error.
  ///
  /// The timeout is short on purpose: this runs while the operator is
  /// looking at the pane, and a panel that can't answer promptly should say
  /// so rather than hold a repaint.
  @override
  Future<Map<String, dynamic>?> renderPanel({
    required String hookKey,
    required String panelKey,
    required Map<String, dynamic> args,
  }) async {
    final host = this.host;
    if (host == null) return null;
    try {
      final result = await host.invokeHook(
        'panel',
        key: hookKey,
        method: 'render',
        args: {...args, 'panelKey': panelKey},
        timeout: const Duration(seconds: 5),
      );
      if (result is! Map) return null;
      return result.cast<String, dynamic>();
    } catch (e) {
      debugPrint('[extensions] renderPanel($hookKey/$panelKey) failed: $e');
      rethrow;
    }
  }

  @override
  Future<Map<String, dynamic>?> panelEvent({
    required String hookKey,
    required String panelKey,
    required Map<String, dynamic> args,
  }) async {
    final host = this.host;
    if (host == null) throw StateError('Extension runtime unavailable');
    final result = await host.invokeHook('panel',
        key: hookKey, method: 'onEvent', args: {...args, 'panelKey': panelKey}, timeout: const Duration(seconds: 5));
    return result is Map ? result.cast<String, dynamic>() : null;
  }

  /// [template] rendered by the core `templates` extension's `template` hook
  /// (docs/extensions/templates.md), against [operation] and [qso] in the
  /// same shape the panels get — so `{{ qso.call }}` in a CW message means
  /// what it means in a pane. Returns the text, or throws a [TemplateError]
  /// carrying the renderer's own words for a template that does not parse.
  /// Null with no runtime, which callers treat as "nothing to send".
  Future<String?> renderTemplate(
    String template, {
    Map<String, dynamic>? operation,
    Map<String, dynamic>? qso,
    int? qsoCount,
    Map<String, dynamic>? log,
  }) async {
    final host = this.host;
    if (host == null) return null;
    final result = await host.invokeHook(
      'template',
      key: 'templates',
      method: 'render',
      args: {
        'template': template,
        'operation': ?operation,
        'qso': ?qso,
        'qsoCount': ?qsoCount,
        'log': ?log,
      },
      timeout: const Duration(seconds: 2),
    );
    if (result is! Map) return null;
    if (result['error'] case final String error) throw TemplateError(error);
    return result['text'] as String?;
  }

  /// [templates] rendered together against one context, in one crossing —
  /// `renderTemplate` for a list. One entry per template, in order: its
  /// text, or the renderer's own words for one that does not parse (the
  /// others still render). Null with no runtime.
  Future<List<({String? text, String? error})>?> renderTemplates(
    List<String> templates, {
    Map<String, dynamic>? operation,
    Map<String, dynamic>? qso,
    int? qsoCount,
  }) async {
    final host = this.host;
    if (host == null) return null;
    final result = await host.invokeHook(
      'template',
      key: 'templates',
      method: 'renderMany',
      args: {
        'templates': templates,
        'operation': ?operation,
        'qso': ?qso,
        'qsoCount': ?qsoCount,
      },
      timeout: const Duration(seconds: 2),
    );
    if (result is! Map || result['results'] is! List) return null;
    return [
      for (final entry in result['results'] as List)
        entry is Map ? (text: entry['text'] as String?, error: entry['error'] as String?) : (text: null, error: null),
    ];
  }

  /// A panel's own config values, keyed by field — the same declarative
  /// storage a Tier 1 settings panel's fields use, under the panel's id, so
  /// a panel's form needs no persistence code of its own.
  @override
  Future<Map<String, dynamic>> readPanelConfig({
    required String panelKey,
    required List<Map<String, dynamic>> fields,
  }) async {
    final values = <String, dynamic>{};
    for (final field in fields) {
      final key = field['key'] as String?;
      if (key == null) continue;
      final stored = await _readSettingsValue(
        panelKey: panelKey,
        fieldKey: key,
        isSecret: field['fieldType'] == 'secret',
      );
      if (stored != null) values[key] = stored;
    }
    return values;
  }

  /// The `FormDefinition` for one panel. For a Tier 1 (`kind: 'simple'`)
  /// panel, this is the ONLY bridge call in its whole lifecycle — every
  /// plain/secret field's live value is overlaid from Dart-owned storage
  /// right here, and every subsequent read/write/validate happens locally
  /// (see [commitSettingsFieldValue]/[validateSettingsField]), matching
  /// Tier 1's "no bridge call per keystroke" design. A Tier 2
  /// (`kind: 'dynamic'`) panel's other fields are already current as
  /// returned — that tier owns its own persistence, so nothing is
  /// overlaid for them. `fieldType: 'account'` fields are resolved here
  /// regardless of tier — neither tier can know live account connection
  /// status itself, since that's entirely host-owned (see AccountHook).
  Future<Map<String, dynamic>?> getSettingsPanelDefinition({
    required String hookKey,
    required String panelKey,
    required String kind,
  }) async {
    final host = this.host;
    if (host == null) return null;
    try {
      final result = await host.invokeHook(
        'settingsPanel',
        key: hookKey,
        method: 'getDefinition',
        args: {'panelKey': panelKey},
        timeout: const Duration(seconds: 5),
      );
      if (result is! Map) return null;
      final definition = Map<String, dynamic>.from(result);
      final elements = ((definition['elements'] as List?) ?? const []).map((e) => Map<String, dynamic>.from(e as Map)).toList();
      for (final el in elements) {
        if (el['type'] != 'field') continue;
        final fieldKey = el['key'] as String?;
        if (fieldKey == null) continue;
        if (el['fieldType'] == 'account') {
          final accountKey = (el['account'] as Map?)?['key'] as String?;
          if (accountKey != null) el['value'] = await _resolveAccountStatus(accountKey);
          continue;
        }
        if (kind != 'simple') continue;
        final stored = await _readSettingsValue(panelKey: panelKey, fieldKey: fieldKey, isSecret: el['fieldType'] == 'secret');
        if (stored != null) el['value'] = stored;
      }
      definition['elements'] = elements;
      return definition;
    } catch (e) {
      debugPrint('[extensions] getSettingsPanelDefinition failed: $e');
      return null;
    }
  }

  /// `{connected, label}` for a `fieldType: 'account'` field — `label` is
  /// only set when connected (a human-readable "Connected as X"). Guarded
  /// on its own: a credential-storage failure here must not take down the
  /// whole panel the way an unguarded exception bubbling up to
  /// [getSettingsPanelDefinition]'s own try/catch would.
  Future<Map<String, dynamic>> _resolveAccountStatus(String accountKey) async {
    try {
      final creds = await getAccountCredentials(accountKey);
      // Null is "we could not look", not "not connected" — say so, so an
      // extension's own UI can tell the difference too.
      if (creds == null) return {'connected': false, 'unavailable': true};
      if (creds.isEmpty) return {'connected': false};
      final identity = identityFromCredentials(creds);
      return {'connected': true, if (identity != null) 'label': t.extensionService.connectedAs(identity: identity)};
    } catch (e) {
      debugPrint('[extensions] _resolveAccountStatus failed for $accountKey: $e');
      return {'connected': false};
    }
  }

  /// Picks a human-readable identity out of a credentials map — the same
  /// priority (`username` then `email` then `login`) used everywhere in
  /// Settings that displays which account a set of stored credentials
  /// belongs to. OAuth accounts store tokens instead of a username, so as a
  /// last resort the OIDC id_token's identity claims are read from its JWT
  /// payload (no signature check needed — it came straight from the
  /// provider's token endpoint and is only used for display).
  static String? identityFromCredentials(Map<String, String> creds) {
    final direct = creds['username'] ?? creds['email'] ?? creds['login'];
    if (direct != null) return direct;
    final idToken = creds['idToken'];
    if (idToken == null) return null;
    try {
      final parts = idToken.split('.');
      if (parts.length != 3) return null;
      final payload = jsonDecode(utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))));
      if (payload is! Map) return null;
      return (payload['preferred_username'] ?? payload['email'] ?? payload['name']) as String?;
    } catch (_) {
      return null;
    }
  }

  /// Validates one field's value. Tier 1 checks `pattern`/`patternError`
  /// declaratively, entirely in Dart — no bridge call. Tier 2 forwards to
  /// its `validateField` hook method.
  Future<String?> validateSettingsField({
    required String kind,
    required String hookKey,
    required String panelKey,
    required Map<String, dynamic> field,
    required String fieldKey,
    required dynamic value,
    required Map<String, dynamic> state,
  }) async {
    if (kind == 'simple') {
      final pattern = field['pattern'] as String?;
      if (pattern == null || pattern.isEmpty) return null;
      try {
        if (RegExp(pattern).hasMatch(value?.toString() ?? '')) return null;
      } catch (e) {
        // A malformed pattern is an extension bug, not a user input error —
        // still can't let it crash the caller, which (unlike submit()'s own
        // validator call) doesn't wrap this in a try/catch on the on-blur path.
        debugPrint('[extensions] settingsPanel field "${field['key']}" has an invalid pattern "$pattern": $e');
        return t.extensionService.invalidFieldConfiguration;
      }
      return field['patternError'] as String? ?? t.extensionService.invalidValue;
    }
    final host = this.host;
    if (host == null) return null;
    try {
      final res = await host.invokeHook(
        'settingsPanel',
        key: hookKey,
        method: 'validateField',
        args: {'panelKey': panelKey, 'fieldKey': fieldKey, 'value': value, 'state': state},
      );
      return res as String?;
    } catch (e) {
      return t.extensionService.validationError(error: e);
    }
  }

  /// Commits one field's value after it's been accepted (validated, and for
  /// Tier 2, transformed). Tier 1 persists directly to Dart-owned storage —
  /// kv (SharedPreferences) normally, `FlutterSecureStorage` for
  /// `fieldType: 'secret'`. Tier 2 has no local persistence at all; the
  /// call is forwarded to `onChangeField` and the extension is responsible
  /// for storing it itself (e.g. its own `host.setSettings` — NOT
  /// `host.kvSet`, which is in-memory only).
  ///
  /// [restartOnChange] (the field's own `restartOnChange` attribute, see
  /// docs/extensions/settings.md's "Restarting the runtime after a Tier 2
  /// field commits") restarts the extension runtime once the commit above
  /// finishes, so `onActivation` re-runs and can pick up the new value via
  /// `getSettings()` — for a value nothing else re-reads on its own.
  Future<void> commitSettingsFieldValue({
    required String kind,
    required String hookKey,
    required String panelKey,
    required String fieldKey,
    required dynamic value,
    required Map<String, dynamic> state,
    bool isSecret = false,
    bool restartOnChange = false,
  }) async {
    if (kind == 'simple') {
      await _writeSettingsValue(panelKey: panelKey, fieldKey: fieldKey, value: value, isSecret: isSecret);
      settingsGeneration.value++;
      return;
    }
    // Wait out any in-flight restart before touching `host` — it's briefly
    // null while `_replaceRuntime` tears down and reboots. Without this, a
    // commit landing in that window bailed out below (host == null) without
    // ever calling onChangeField, silently dropping that edit rather than
    // just delaying it.
    final inFlightRestart = _restartFuture;
    if (inFlightRestart != null) await inFlightRestart;
    final host = this.host;
    if (host == null) return;
    // Counted so a pending debounce timer cannot restart the runtime UNDER
    // this commit's bridge call — disposing the host completes the pending
    // invokeHook with an exception and the edit would be silently dropped.
    // The timer waits for quiescence before restarting.
    _inFlightFieldCommits++;
    try {
      await host.invokeHook(
        'settingsPanel',
        key: hookKey,
        method: 'onChangeField',
        args: {'panelKey': panelKey, 'fieldKey': fieldKey, 'value': value, 'state': state},
      );
    } catch (e) {
      debugPrint('[extensions] settingsPanel onChangeField failed: $e');
      // Not restarted below: onChangeField is the extension's own persistence
      // call (e.g. host.setSettings) — if IT failed, the value never
      // actually saved, so restarting anyway would just re-run onActivation
      // against the same stale settings for no benefit.
      return;
    } finally {
      _inFlightFieldCommits--;
      if (_inFlightFieldCommits == 0) {
        _fieldCommitsIdle?.complete();
        _fieldCommitsIdle = null;
      }
    }
    settingsGeneration.value++;
    if (restartOnChange) await _debouncedRestartRuntime();
  }

  /// Bumped whenever an extension's own settings value is committed —
  /// neither path notifies [settings], since one writes straight to prefs
  /// and the other hands the value to the extension, so a panel showing
  /// that field has nothing else to learn the change from.
  ///
  /// The Settings panel mounts a panel's fields TWICE — once under Common
  /// Settings, once in the panel's own category — and without this the copy
  /// that did not commit keeps the old value and writes it back on the next
  /// interaction, silently reverting what the operator typed.
  final ValueNotifier<int> settingsGeneration = ValueNotifier(0);

  int _inFlightFieldCommits = 0;
  Completer<void>? _fieldCommitsIdle;

  Timer? _restartOnChangeDebounce;
  Completer<void>? _restartOnChangeCompleter;

  /// Coalesces a burst of `restartOnChange` commits (e.g. deleting or
  /// reordering several rows of an inline list field one at a time) into a
  /// SINGLE runtime restart once they settle, instead of tearing down and
  /// rebooting every OTHER loaded extension once per row action — a full
  /// [restartRuntime] is the existing, already-accepted cost of
  /// `restartOnChange` (the same one an extension enable/disable toggle
  /// pays), but nothing before call-notes' `customFiles` field exercised it
  /// from a rapid, un-awaited per-row UI action.
  Future<void> _debouncedRestartRuntime() {
    _restartOnChangeDebounce?.cancel();
    final completer = _restartOnChangeCompleter ??= Completer<void>();
    _restartOnChangeDebounce = Timer(const Duration(milliseconds: 400), () async {
      // A commit whose onChangeField round trip is still in flight when this
      // timer fires must finish before the restart tears the host down; the
      // loop re-checks because a waiting commit can itself be followed by
      // another within the same window.
      while (_inFlightFieldCommits > 0) {
        await (_fieldCommitsIdle ??= Completer<void>()).future;
      }
      // A commit that finished DURING that wait re-armed the timer onto this
      // same completer — but its write is already durable and the restart
      // below will read it, so that re-arm is redundant: absorb it. If a
      // parallel firing of this callback got here first, the completer no
      // longer matches and this one stands down.
      if (!identical(_restartOnChangeCompleter, completer)) return;
      _restartOnChangeCompleter = null;
      _restartOnChangeDebounce?.cancel();
      unawaited(restartRuntime().then(completer.complete, onError: completer.completeError));
    });
    return completer.future;
  }

  /// Transforms one field's value (Tier 2 only — Tier 1 fields never carry
  /// a transform, by construction of the `SettingsField` type).
  /// `transformField` is optional on `DynamicSettingsPanel` — a hook that
  /// doesn't implement it has nothing to distinguish "no transform
  /// declared" from "explicitly transformed to null" once the call comes
  /// back over the bridge (kernel.ts's generic dispatch has no per-field
  /// fallback the way the `form` category's kernel-side wrapper does), so
  /// a bare `null` result falls back to the original value rather than
  /// silently nulling out the field being committed.
  Future<dynamic> transformSettingsField({
    required String hookKey,
    required String panelKey,
    required String fieldKey,
    required dynamic value,
    required Map<String, dynamic> state,
  }) async {
    final host = this.host;
    if (host == null) return value;
    try {
      final result = await host.invokeHook(
        'settingsPanel',
        key: hookKey,
        method: 'transformField',
        args: {'panelKey': panelKey, 'fieldKey': fieldKey, 'value': value, 'state': state},
      );
      return result ?? value;
    } catch (e) {
      return value;
    }
  }

  /// Invokes a `FormActionElement`'s `method` (e.g. a "Test Connection" or
  /// "Clear Cache" button) against the panel's current state and returns
  /// the result string to show as a banner. `method` isn't a fixed hook
  /// method — it's resolved against whatever extra property the extension
  /// put on its registered panel object (see docs/extensions/settings.md's
  /// "The action element").
  Future<String?> runSettingsAction({
    required String hookKey,
    required String panelKey,
    required String method,
    required Map<String, dynamic> state,
  }) async {
    final host = this.host;
    if (host == null) return t.extensionService.runtimeNotReady;
    try {
      final res = await host.invokeHook(
        'settingsPanel',
        key: hookKey,
        method: method,
        args: {'panelKey': panelKey, 'state': state},
        timeout: const Duration(seconds: 10),
      );
      return res is String ? res : res?.toString();
    } catch (e) {
      return t.extensionService.actionFailed(error: e);
    }
  }

  Future<dynamic> _readSettingsValue({required String panelKey, required String fieldKey, required bool isSecret}) async {
    final raw = isSecret
        ? await _secureStorage.read(key: _settingsSecretStorageKey(panelKey, fieldKey))
        : settings?.prefs.getString(_settingsPrefsKey(panelKey, fieldKey));
    if (raw == null) return null;
    try {
      return jsonDecode(raw);
    } catch (_) {
      return raw;
    }
  }

  Future<void> _writeSettingsValue({required String panelKey, required String fieldKey, required dynamic value, required bool isSecret}) async {
    final encoded = jsonEncode(value);
    if (isSecret) {
      await _secureStorage.write(key: _settingsSecretStorageKey(panelKey, fieldKey), value: encoded);
      return;
    }
    await settings?.prefs.setString(_settingsPrefsKey(panelKey, fieldKey), encoded);
  }

  /// Forgets everything stored for one panel's own form.
  ///
  /// Only a panel INSTANCE is ever forgotten (see PanelService), so this is
  /// not a settings reset — it is a placement being thrown away along with
  /// what the operator put in it. Secrets go too: leaving a keychain entry
  /// behind for an id that will be handed to the next placement of the same
  /// panel is exactly the resurrection this exists to prevent.
  @override
  Future<void> forgetPanelConfig({required String panelKey, required List<Map<String, dynamic>> fields}) async {
    for (final field in fields) {
      final key = field['key'] as String?;
      if (key == null) continue;
      if (field['fieldType'] == 'secret') {
        await _secureStorage.delete(key: _settingsSecretStorageKey(panelKey, key));
      } else {
        await settings?.prefs.remove(_settingsPrefsKey(panelKey, key));
      }
    }
  }

  String _settingsPrefsKey(String panelKey, String fieldKey) => 'settingsPanel.$panelKey.$fieldKey';

  String _settingsSecretStorageKey(String panelKey, String fieldKey) => 'settingsPanel_secret_${panelKey}_$fieldKey';

  /// The LoFi app-attestation secret, injected at build time
  /// (`flutter build ... --dart-define=HAM2K_LOFI_SECRET=...`) — the same
  /// role as app-polo's `Config.HAM2K_LOFI_SECRET` from react-native-config.
  /// It identifies the *build* to the server, not the device (the device
  /// key does that); dev builds without the define fall back to the
  /// extension's 'no-secret' default, exactly like app-polo dev builds.
  static const _lofiSecret = String.fromEnvironment('HAM2K_LOFI_SECRET');

  /// Shared secret for the standalone LoFi backup capture service
  /// (`flutter build ... --dart-define=HAM2K_BACKUP_TOKEN=...`). Unset means
  /// the extension's fallback capture on a LoFi failure is a no-op — same
  /// shape as `_lofiSecret` going unset, just with "skip the feature" as the
  /// fallback instead of a shared dev default.
  static const _backupToken = String.fromEnvironment('HAM2K_BACKUP_TOKEN');

  /// Seeds the `ham2k-lofi` sync extension's device identity (a stable
  /// per-install key, generated once by `SettingsService.syncDeviceKey`),
  /// operator callsign, and build secret. Called both at boot and whenever
  /// Settings saves a new operator callsign. There's
  /// deliberately no `token` seeded here: the extension re-registers with
  /// the server on first use each run (the token is session-scoped, kept in
  /// the extension's own module state, same as app-polo's `GLOBAL.syncLoFiToken`
  /// being memory-only there too).
  Future<void> setSyncCredentials({required String deviceKey, required String operatorCall}) async {
    _lastSyncCredentials = (deviceKey: deviceKey, operatorCall: operatorCall); // replayed after a runtime restart
    await start();
    _host?.setKV('ham2k-lofi', 'key', deviceKey);
    _host?.setKV('ham2k-lofi', 'call', operatorCall);
    // What a device already on the account is asked to approve — PoLo's
    // confirmation dialog names it — so it says which app this is, not a
    // code name.
    _host?.setKV('ham2k-lofi', 'clientName', withEdition(ham2kAppName));
    if (_lofiSecret.isNotEmpty) _host?.setKV('ham2k-lofi', 'secret', _lofiSecret);
    if (_backupToken.isNotEmpty) _host?.setKV('ham2k-lofi', 'backupToken', _backupToken);
  }

  Future<void> _start() async {
    // Fresh gate per generation: account access blocks on it until the
    // synchronizable flags are resolved (or start fails), so an early lookup
    // can't read an account under the wrong sync flag. Completed in `finally`.
    _accountSyncReady = Completer<void>();
    // The flags the cache was read under may change with this generation.
    _accountItems.clear();
    try {
      final index = jsonDecode(await rootBundle.loadString('assets/extensions/index.json')) as Map<String, dynamic>;
      final kernelSource = await rootBundle.loadString('assets/extensions/${index['kernel']}');
      await loadAvailableExtensions(index: index);
      final available = availableExtensions;
      final bundles = <ExtensionBundle>[];
      final fetchAllowlists = <String, List<String>>{};
      final extensionSecrets = <String, Map<String, String>>{};
      final userAgentOverrides = <String>{};
      final loaded = <String>{};
      for (final info in available) {
        // Disabled (or experiment-gated) extensions are simply never
        // loaded — their hooks, settings panels, and commands are absent
        // until a re-enable restarts the runtime with them included.
        if (!isExtensionActive(info)) continue;
        loaded.add(info.key);
        bundles.add(ExtensionBundle(key: info.key, source: await _sourceFor(info)));
        // The manifest's declared network capabilities (`domains` and
        // `allowUserAgentOverride`; see extensions/build-config.mjs).
        fetchAllowlists[info.key] = info.domains;
        if (info.allowUserAgentOverride) userAgentOverrides.add(info.key);
        // Resolve what this extension is allowed to see, once, at load time —
        // the host then holds only that subset and needs no policy of its own.
        // A build without a value configured simply has none, and every
        // consumer degrades rather than failing: a fresh checkout must run.
        final visible = visibleSecretsFor(info, secrets);
        if (visible.isNotEmpty) extensionSecrets[info.key] = visible;
      }
      // Boot is a gating site too: an experiment can change between runs
      // (or an update can gate an extension that used to load), and nothing
      // else stamps disabledSince before the stale-data purge reads it —
      // without this, a gated-at-startup extension's purge grace clock
      // never starts.
      final settingsForStamps = settings;
      if (settingsForStamps != null) {
        await updateExtensionDisabledSince(
          settings: settingsForStamps, available: availableExtensions, isActive: isExtensionActive);
      }
      // The manifest's declared host-call capabilities (`requiresLocation`,
      // `requiresRadio*`; see extensions/build-config.mjs).
      final loadedInfos = available.where((info) => loaded.contains(info.key)).toList();
      _location = CapabilityGrant.among(loadedInfos, (info) => info.requiresLocation);
      radioCalls.allow(loadedInfos);
      // Pessimistic from the moment a host exists until its activations have
      // genuinely settled below, so a consumer reading it the instant `host`
      // goes non-null is not told the hook set is authoritative while
      // extensions are still registering into it. The data-file orphan purge
      // is what reads this; the panel catalog deliberately does NOT, because
      // a panel missing from an early read costs a placeholder that repairs
      // itself, while an extension's data purged on a partial one is gone.
      _activationIncomplete = true;
      final host = await ExtensionHost.start(
        kernelSource: kernelSource,
        extensions: bundles,
        onHostCall: _handleHostCall,
        fetchAllowlists: fetchAllowlists,
        secrets: extensionSecrets,
        // Resolve the UA resiliently: a missing native build number (headless
        // test host, or an early-boot platform channel not yet ready) must
        // not throw here and leave every extension dark.
        userAgent: await ham2kUserAgentOrFallback(),
        userAgentOverrides: userAgentOverrides,
        // Handed to the boot itself, not pushed after it returns: `start`
        // evaluates every bundle AND runs their activations, so a clock that
        // arrives afterwards has already missed them and an extension reading a
        // date while activating would bake in the real one. Covers restarts too
        // — _replaceRuntime routes back through here.
        clock: _clockTravelState(),
      );
      // The quit began while this boot was in flight: install it now and the
      // VM's teardown gets a live isolate — and the exit's own wait for this
      // boot may already have timed out, so nothing else would dispose it.
      if (_exiting) {
        await host.dispose();
        return;
      }
      _host = host;
      _loadedExtensionKeys = loaded;
      _host!.logs.listen((line) => debugPrint('[extensions] $line'));
      _host!.interpretationUpdates.listen(_interpretationUpdates.add);
      for (final line in _host!.logLines) {
        debugPrint('[extensions] $line');
      }
      // A crashed runtime (isolate death, worker crash) is replaced, not
      // mourned: DESIGN.md's contract is that extensions degrade, they
      // don't stay dark until app restart.
      _host!.fatalErrors.listen((error) => _scheduleRestart('runtime died: $error'));
      _restartAttempts = 0;
      // AFTER the runtime is up, and deliberately not awaited. Unzipping and
      // writing eight bundles — plus a keychain the platform may take its
      // time refusing — is seconds of work, and boot is behind a three-second
      // gate: done inline it spends the whole budget and the app arrives with
      // no extensions at all, which is what happens without this.
      //
      // So the first launch runs on what it already had and picks the
      // pre-loads up on the restart below, the same way an install does.
      unawaited(catchUpOnCatalogExtensions(this));
      // Every extension's onActivation has now genuinely settled — not just
      // been kicked off (kernel.ts's activateAll fires it fire-and-forget).
      // Without this await, a caller querying dataFile/settingsPanel hooks
      // right after start() returned could miss a registration an extension
      // makes only after its own internal await (call-notes' custom files
      // await host.getSettings() first). Bounded: a hung extension's
      // activation must degrade boot, not stall it forever.
      var settled = true;
      final booting = _host!;
      await booting.activated.timeout(const Duration(seconds: 5), onTimeout: () {
        debugPrint('[extensions] activation did not complete within 5s — continuing anyway');
        settled = false;
      });
      _activationIncomplete = !settled;
      if (!settled) {
        // The wait is bounded so a hung extension degrades boot instead of
        // stalling it — but nothing re-checks afterwards, so a slow device
        // that merely overran the cap would carry "the hook set is
        // incomplete" for the whole generation, and every consumer that
        // stands down on it (the data-file purge, the panel catalog) would
        // stay stood down for the session. Identity-checked: a runtime
        // replaced meanwhile owns this flag now.
        unawaited(booting.activated.then((_) {
          if (!identical(_host, booting)) return;
          debugPrint('[extensions] activation completed late; the hook set is whole after all');
          _activationIncomplete = false;
          runtimeGeneration.value++;
        }).catchError((_) {}));
      }
      // Re-pushed unconditionally, after the host is live: the `clock:` argument
      // above was read BEFORE loading the bundles, so a DEVTT during those
      // seconds would otherwise be lost (`_pushClockTravel` had no host to push
      // into) and this runtime would stay on the pre-boot clock for good.
      // Idempotent and cheap.
      _pushClockTravel();
      runtimeGeneration.value++;
      // Resolve each account's synchronizable flag; account access blocks on
      // _accountSyncReady (completed below) until this is done, so every
      // keychain op for a key uses a consistent flag. Covers restarts too:
      // _replaceRuntime routes back through start()/_start().
      await _refreshAccountSynchronizable();
    } catch (e) {
      debugPrint('[extensions] failed to start extension runtime: $e');
      // A transient boot failure (asset hiccup, engine init) must not leave
      // extensions off for the rest of the session ("_starting" memoizes),
      // so retry with backoff.
      _scheduleRestart('start failed: $e');
    } finally {
      // Never leave account access blocked, even if start threw before the
      // refresh ran — the empty cache then yields device-local defaults.
      if (!_accountSyncReady.isCompleted) _accountSyncReady.complete();
    }
  }

  /// One extension's JS, from wherever that extension came from.
  Future<String> _sourceFor(ExtensionInfo info) async {
    final dev = _devBundles[info.key];
    if (dev != null) return dev.source;
    if (info.isInstalled) return _requireInstalledStore().sourceFor(info.key);
    return rootBundle.loadString('assets/extensions/${info.file}');
  }

  /// Drops the memoized list and reads it again — after anything that changes
  /// what is installed.
  Future<void> reloadAvailableExtensions() async {
    _availableExtensions = null;
    await loadAvailableExtensions();
  }

  /// The catalog's copy of every withdrawn built-in the operator had ON.
  Future<({bool landed, bool complete})> adoptTwins() => adoptCatalogTwins(
      store: _installed, settings: settings, catalog: catalog, available: availableExtensions,
      isEnabled: isExtensionEnabled, recordInstall: _recordInstall, copySecrets: copyExtensionSecrets);

  /// Installs the `.h2kext` bundles the app ships (HALO-581), and answers
  /// whether anything landed — the caller re-reads the store when it did.
  ///
  /// Only under the catalog experiment: off it, the app runs its own
  /// extensions and pre-loading their catalog twins would put two of each in
  /// the panel, one of them switched off and unexplained.
  Future<bool> preloadShippedExtensions() async {
    final currentSettings = settings;
    final store = _installed;
    if (currentSettings == null || store == null) return false;
    if (!currentSettings.catalogExtensionsInUse) return false;
    return installShippedExtensions(
      store: store,
      settings: currentSettings,
      installedVersions: {for (final info in availableExtensions) if (info.isInstalled) info.key: info.version},
      recordInstall: (bundle, {required bool fresh}) => _recordInstall(bundle, fresh: fresh),
      copySecrets: copyExtensionSecrets,
    );
  }

  /// Installs an inspected `.h2kext` and reboots the runtime so it loads.
  ///
  /// The consent the operator gave belongs to the caller — this is the commit,
  /// and by here the asking has happened.
  Future<void> installBundle(InspectedBundle bundle) async {
    final store = _requireInstalledStore();
    // Asked BEFORE the write: afterwards the key is always there.
    final fresh = !await store.isInstalled(bundle.key);
    // Only on a FRESH install of catalog bytes: an update has its own state
    // already, and a file install of a `ham2k-` key never reaches here.
    final carried = fresh &&
        bundle.provenance != null &&
        await carryPredecessorRecords(
            key: bundle.key,
            settings: settings,
            // What the app SHIPS, not what it offers — see predecessorBuiltInKey.
          builtInKeys: {for (final i in availableExtensions) if (i.source == ExtensionSource.asset) i.key},
            copySecrets: copyExtensionSecrets);
    await store.install(bundle);
    // `fresh` drops a stale on/off choice; one just carried is not stale.
    await _recordInstall(bundle, fresh: fresh && !carried);
    _availableExtensions = null;
    await restartRuntime();
  }

  /// The settings an install touches. The provenance record is written for
  /// catalog bytes and cleared for any other: a file install of a key the
  /// catalog once served must not inherit the `ham2k-` waiver. A revocation
  /// of another version is over. And a catalog install of a key the store
  /// did not have — the built-in that moved to the catalog, switched off by
  /// the operator while it was built in — drops the operator's override and
  /// the disabled-since stamp so it runs; an UPDATE keeps both, because a
  /// switch the operator turned off is not a newer version's to turn on.
  Future<void> _recordInstall(InspectedBundle bundle, {required bool fresh}) async {
    final currentSettings = settings;
    if (currentSettings == null) return;
    final records = {...currentSettings.extensionInstalledFrom};
    final provenance = bundle.provenance;
    if (provenance == null) {
      if (records.remove(bundle.key) != null) await currentSettings.setExtensionInstalledFrom(records);
    } else {
      records[bundle.key] = provenance.toJson();
      await currentSettings.setExtensionInstalledFrom(records);
    }
    final revoked = currentSettings.extensionRevoked;
    if (revoked[bundle.key] != null && revoked[bundle.key]!['version'] != bundle.version) {
      revoked.remove(bundle.key);
      await currentSettings.setExtensionRevoked(revoked);
    }
    if (provenance == null || !fresh) return;
    final overrides = currentSettings.extensionOverrides;
    if (overrides.remove(bundle.key) != null) await currentSettings.setExtensionOverrides(overrides);
    final disabledSince = currentSettings.extensionDisabledSince;
    if (disabledSince.remove(bundle.key) != null) await currentSettings.setExtensionDisabledSince(disabledSince);
  }

  /// Removes an installed extension and reboots without it.
  ///
  /// Everything it stored goes with it — its settings group and the operator's
  /// enable/disable override — which is what makes this an uninstall rather
  /// than an update. Left behind, they come back silently on a reinstall: old
  /// credentials, and an extension that lands disabled with nothing to say
  /// why.
  Future<void> uninstallExtension(String key) async {
    await _requireInstalledStore().uninstall(key);
    await settings?.forgetExtension(key);
    await forgetExtensionKeychainItems(_secureStorage, key,
        deleteOne: (name) async => _deleteAccountItem(name, await _accountKeychainOptions(key)));
    _availableExtensions = null;
    statusBar?.clearNamespace(key);
    await restartRuntime();
  }

  /// Copies every keychain item [from] owned onto [to] — the keychain half
  /// of what `SettingsService.copyExtensionRecords` does for prefs, and what
  /// keeps an operator logged in when an extension changes its key.
  Future<void> copyExtensionSecrets({required String from, required String to}) =>
      copyExtensionKeychainItems(_secureStorage, from: from, to: to, copyOne: _copyAccountItem);

  /// Reads one account item and writes it under another name, each with the
  /// options its own key resolves to. The fallback the keychain copy uses
  /// where the platform will not enumerate — and it has to go through
  /// [_accountKeychainOptions], because an item written under one set of
  /// options is not found by a read issued with another.
  Future<void> _copyAccountItem(String from, String to) async {
    final fromKey = from.replaceFirst(RegExp(r'^account_(creds|session)_'), '');
    final toKey = to.replaceFirst(RegExp(r'^account_(creds|session)_'), '');
    final fromOptions = await _accountKeychainOptions(fromKey);
    final toOptions = await _accountKeychainOptions(toKey);
    if (await _secureStorage.read(key: to, mOptions: toOptions.mOptions, iOptions: toOptions.iOptions) != null) return;
    final value = await _secureStorage.read(key: from, mOptions: fromOptions.mOptions, iOptions: fromOptions.iOptions);
    if (value == null) return;
    await _secureStorage.write(key: to, value: value, mOptions: toOptions.mOptions, iOptions: toOptions.iOptions);
  }

  /// The installed store, or a failure that names what was missing. A bare `!`
  /// here reports "Null check operator used on a null value", which says
  /// nothing about extensions to whoever reads it.
  InstalledExtensions _requireInstalledStore() {
    final store = _installed;
    if (store == null) {
      throw StateError('no installed-extension store yet — loadAvailableExtensions has not run');
    }
    return store;
  }

  /// The extensions the build index declares, with their user-facing
  /// metadata — readable without booting (or evaluating) any JS, so the
  /// Extensions panel can list DISABLED extensions and still render when
  /// the runtime is down. Memoized; [index] lets [_start] reuse its own
  /// parse.
  Future<List<ExtensionInfo>> loadAvailableExtensions({Map<String, dynamic>? index}) async {
    if (_availableExtensions != null) return _availableExtensions!;
    final parsed = index ?? jsonDecode(await rootBundle.loadString('assets/extensions/index.json')) as Map<String, dynamic>;
    final fromAssets = [
      for (final entry in (parsed['extensions'] as List).cast<Map<String, dynamic>>()) ExtensionInfo.fromJson(entry),
    ];
    _hostSharedModules = ((parsed['sharedModules'] as Map?) ?? const {}).cast<String, String>();
    // Built from the asset index, because what an installed bundle may NOT
    // call itself is exactly what the app already ships.
    // Not on web: there is no store there, and a non-null one whose every
    // method refuses is a thing every caller has to remember about.
    final store = InstalledExtensions.isSupported
        ? (_installed ??= InstalledExtensions(
            // Read live, not captured, and only what the app is OFFERING: the
            // catalog experiment withdraws every non-core built-in, and the
            // bundle pre-loaded for `ham2k-lookup` is one the app also ships.
            builtInKeys: () => {for (final info in fromAssets) if (isBuiltInOffered(info)) info.key},
            hostSharedModules: _hostSharedModules,
            // Read live too: the record is written by installBundle and
            // cleared by uninstall, and the store outlives both.
            reservedPrefixAllowed: (String key) =>
                BundleProvenance.fromJson(settings?.extensionInstalledFrom[key])?.isReservedPrefixAllowed ?? false,
          ))
        : null;
    // A damaged store must not cost the operator the app's own extensions.
    var fromDisk = const <ExtensionInfo>[];
    try {
      fromDisk = await store?.list() ?? const [];
    } catch (e, stack) {
      // Reported, not merely logged. `list` already skips a single unreadable
      // extension, so anything reaching here is the STORE failing — every
      // installed extension gone at once, with the app otherwise behaving
      // normally. Deciding here that it doesn't matter is the ad-hoc policy
      // ErrorPolicy exists to prevent (docs/design/error-reporting.md).
      ErrorReportingService.report(e, stack, context: 'installed-extensions:list');
    }
    return _availableExtensions = mergeDevExtensions(
      [...fromAssets, ...fromDisk],
      [for (final entry in _devBundles.values) entry.info],
    );
  }

  /// The already-loaded metadata, or empty before [loadAvailableExtensions]
  /// first resolves.
  List<ExtensionInfo> get availableExtensions => _availableExtensions ?? const [];
  List<ExtensionInfo>? _availableExtensions;

  @visibleForTesting
  void debugSetAvailableExtensions(List<ExtensionInfo> extensions) => _availableExtensions = extensions;

  /// Stands in for what a real [_start] records, which a test's fake host
  /// never runs — so the generation's own keys can be exercised without
  /// booting a runtime.
  @visibleForTesting
  set debugLoadedExtensionKeys(Set<String> keys) => _loadedExtensionKeys = keys;

  /// Which extension keys the CURRENT runtime was started with — compared
  /// against the desired set to decide whether a toggle needs a restart.
  Set<String> _loadedExtensionKeys = const {};

  /// Installed `.h2kext` extensions (HALO-422). Null until the index has been
  /// read, since it needs the built-in keys and the host's shared-module
  /// versions to validate anything.
  InstalledExtensions? _installed;

  /// The store, once the extension index has been read. Null on web, and
  /// before the first [loadAvailableExtensions].
  InstalledExtensions? get installed => _installed;

  /// Supplies the store up front, so a test can point it at a directory of its
  /// own — the real one resolves through `appDataDirectory()`, which reaches a
  /// platform channel.
  @visibleForTesting
  set debugInstalledStore(InstalledExtensions store) => _installed = store;

  /// What this build's kernel carries, from index.json — the versions an
  /// installed bundle's `sharedDependencies` are checked against.
  Map<String, String> _hostSharedModules = const {};

  /// Extensions currently served by a dev server, by key: the built source and
  /// the manifest metadata that came with it. An entry here OVERRIDES the
  /// asset extension of the same key, which is what lets an author iterate on
  /// `pota` itself rather than only on something new.
  final Map<String, ({String source, ExtensionInfo info})> _devBundles = {};

  /// Whether [key] is currently being served by a dev server.
  bool isDevExtension(String key) => _devBundles.containsKey(key);

  /// Replaces the whole dev-served set and reboots the runtime. Used on
  /// connect and disconnect — both change WHICH extensions exist, which a
  /// per-extension reload cannot express.
  Future<void> setDevBundles(Map<String, ({String source, ExtensionInfo info})> bundles) async {
    _devBundles
      ..clear()
      ..addAll(bundles);
    _availableExtensions = null; // the index it was memoized from just changed
    await restartRuntime();
  }

  /// Swaps ONE dev extension's code in the running runtime — the hot path, on
  /// every save.
  ///
  /// Falls back to a full restart when the extension isn't loaded yet: a key
  /// the runtime has never seen has no hooks to replace, and its very
  /// existence changes what the app offers (an activity in Operation Setup, a
  /// settings panel), which only a reboot re-reads.
  Future<void> applyDevBundle(String key, {required String source, required ExtensionInfo info}) async {
    // Read BEFORE the insert below: what matters is how this key was loaded
    // into the RUNNING runtime, not what it is about to become.
    final previous = _devBundles[key];
    _devBundles[key] = (source: source, info: info);
    _availableExtensions = null;
    final host = _host;
    if (host == null ||
        !canHotSwapDevBundle(
          runtimeAlive: !host.isDead,
          alreadyLoaded: _loadedExtensionKeys.contains(key),
          alreadyDevServed: previous != null,
          capabilitiesUnchanged: previous != null && previous.info.sameStartTimeCapabilities(info),
        )) {
      await restartRuntime();
      return;
    }
    // The previous code's transient UI is nobody's to clear once its hooks are
    // gone — a progress bar it left behind would sit there for the session.
    statusBar?.clearNamespace(key);
    await host.reloadBundle(
      ExtensionBundle(key: key, source: source),
      domains: info.domains,
    );
    // Panels, settings panels and the command catalog are all cached against
    // this counter; the reloaded extension may contribute a different set.
    _commandCatalog = null;
    runtimeGeneration.value++;
  }

  /// Bumped after every successful runtime (re)start — panels listen to
  /// re-fetch extension-contributed content (settings panels, listings).
  @override
  final ValueNotifier<int> runtimeGeneration = ValueNotifier(0);

  /// A `command` hook pushed a later CommandInterpretation for an `input` it
  /// was already asked to interpret (SOLAR/WEATHER's fetch
  /// resolving after their own describe-preview call already returned).
  /// Owned by the service, not the current [_host]: a restart replaces
  /// [_host] but callers (LoggingControls) hold one subscription for the
  /// service's whole lifetime, so [_start] re-subscribes the fresh host into
  /// this same controller each time instead of handing out a new stream.
  final _interpretationUpdates = StreamController<Map<String, dynamic>>.broadcast();

  Stream<Map<String, dynamic>> get commandInterpretationUpdates => _interpretationUpdates.stream;

  /// Core extensions are always on; the rest follow the user's override,
  /// falling back to the build index's default — except a release the
  /// catalog revoked, which is off whatever the override says: the switch is
  /// the operator's intent, and the revocation is not theirs to undo. A null
  /// [settings] (tests, benches) resolves to defaults. Enabled is the user's
  /// intent only — whether the extension actually loads also requires
  /// [isExtensionAvailable].
  bool isExtensionEnabled(ExtensionInfo info) =>
      info.core || (!isExtensionRevoked(info) && (settings?.extensionOverrides[info.key] ?? info.enabledByDefault));

  /// Whether the INSTALLED version of [info] is one the catalog revoked
  /// (`SettingsService.extensionRevoked`). Judged by version, so the record
  /// stops mattering the moment another version is installed.
  bool isExtensionRevoked(ExtensionInfo info) {
    final version = info.version;
    return version != null && settings?.extensionRevoked[info.key]?['version'] == version;
  }

  /// Whether an extension the app SHIPS is one it currently offers.
  ///
  /// Core extensions always are — they are the app itself, and `ham2k-lofi`
  /// among them, so sync does not stop. Every other built-in is withdrawn
  /// while the catalog experiment is on (HALO-581): the point of that
  /// experiment is to run on what the catalog serves, and a built-in left
  /// loaded beside its catalog twin would register the same hooks and the
  /// same `ref:` types twice.
  ///
  /// Withdrawn, not forgotten. The entry stays in [availableExtensions] so
  /// that [updateExtensionDisabledSince] does not prune the operator's on/off
  /// choice for it, and so it comes back untouched when the experiment goes
  /// off.
  ///
  /// Nothing is withdrawn where there is no store to put anything in its
  /// place. On web an installed extension is a file on disk the platform does
  /// not have, so the pre-loads never land — and withdrawing the built-ins
  /// there would leave the app with the core extensions and nothing else.
  bool isBuiltInOffered(ExtensionInfo info) {
    if (info.source != ExtensionSource.asset || info.core) return true;
    if (!InstalledExtensions.isSupported) return true;
    // MIGRATED, not merely offered: an operator who deferred the upgrade, or
    // who was offline when it was offered, keeps every extension they had.
    // Withdrawing on the experiment alone is what left "Later" meaning "with
    // no extensions until you are next online".
    return !(settings?.catalogExtensionsInUse ?? false);
  }

  /// Whether [info] is an installed extension the app is currently doing
  /// itself — a pre-loaded `ham2k-pota` while the built-in `pota` is back.
  ///
  /// The mirror of [isBuiltInOffered], and the reason it has to exist: the
  /// experiment withdraws the built-ins, but turning it off does not withdraw
  /// what replaced them. Both would then load, both would register `ref:pota`,
  /// one of them would win by position, and the panel would list the same
  /// extension twice with no way to tell which is answering.
  ///
  /// Judged against the built-in actually being OFFERED, not merely shipped,
  /// so this stops applying by itself on the day the app stops carrying its
  /// own copy — which is where all of this is going.
  ///
  /// Withdrawn, not uninstalled. The bundle and everything it stored stay
  /// where they are, so turning the experiment back on picks it up mid-stride.
  bool isSupersededByBuiltIn(ExtensionInfo info) {
    if (info.source != ExtensionSource.installed) return false;
    // The same rule the carry uses, not the seven named renames alone: the
    // adoption installs up to thirty-three more under `ham2k-<builtin>`, and
    // `ham2k-lookup` is served under the name it already has. Judged by the
    // map only, every one of those loads BESIDE its restored built-in the
    // moment the experiment goes off — two bundles under one key for lookup,
    // and two registrations of `ref:wca` for the rest.
    final shipped = {for (final i in availableExtensions) if (i.source == ExtensionSource.asset) i.key};
    final replaces = shipped.contains(info.key) ? info.key : predecessorBuiltInKey(info.key, shipped);
    if (replaces == null) return false;
    return availableExtensions
        .any((other) => other.key == replaces && other.source == ExtensionSource.asset && isBuiltInOffered(other));
  }

  /// Whether [info] is offered at all: every experiment its manifest
  /// declares (experiments.yaml keys) must be enabled. An unavailable
  /// extension is hidden from the Extensions panel and never loaded, but
  /// its stored override is deliberately KEPT — one enabled before the
  /// experiment turned off comes back enabled when it turns on again. A
  /// null [settings] (tests, benches) resolves to available.
  bool isExtensionAvailable(ExtensionInfo info) {
    final currentSettings = settings;
    if (currentSettings == null) return true;
    if (!isBuiltInOffered(info)) return false;
    if (isSupersededByBuiltIn(info)) return false;
    return info.experiments.every(currentSettings.experimentEnabled);
  }

  /// Whether [info] actually loads: offered ([isExtensionAvailable]) AND
  /// switched on ([isExtensionEnabled]). Every load-set computation must go
  /// through this one predicate — a gate applied at only some sites makes
  /// the desired and loaded sets disagree, and then a needed restart
  /// silently never happens.
  bool isExtensionActive(ExtensionInfo info) => isExtensionAvailable(info) && isExtensionEnabled(info);

  /// Persists enable/disable choices and applies them by restarting the
  /// runtime with the filtered bundle set. The overrides land BEFORE any
  /// restart, so a quit mid-apply loses nothing.
  Future<void> setExtensionsEnabled(Map<String, bool> changes) async {
    final currentSettings = settings;
    if (currentSettings == null || changes.isEmpty) return;
    await currentSettings.setExtensionOverrides({...currentSettings.extensionOverrides, ...changes});
    await applyExtensionAvailability();
  }

  /// Recomputes which extensions should be loaded (overrides + experiment
  /// gates), re-stamps disabledSince, and restarts the runtime — but only
  /// when the effective set actually changes (and the runtime is up; a
  /// pending boot picks the fresh state up on its own). Call after flipping
  /// an experiment; most toggles gate nothing and return cheaply.
  Future<void> applyExtensionAvailability() async {
    final currentSettings = settings;
    if (currentSettings == null) return;
    // Every experiment flip lands here, and HookContext carries the enabled
    // set: without this, an EXP preview within the kernel cache's TTL of a
    // flip still offers the direction the flip just took.
    invalidateHookContext();
    await updateExtensionDisabledSince(
        settings: currentSettings, available: availableExtensions, isActive: isExtensionActive);
    final desired = {
      for (final info in availableExtensions)
        if (isExtensionActive(info)) info.key,
    };
    if (_host == null || setEquals(desired, _loadedExtensionKeys)) return;
    await restartRuntime();
  }

  Future<void> setExtensionEnabled(String key, bool enabled) => setExtensionsEnabled({key: enabled});

  /// The activated extensions of the LIVE runtime, with versions — served
  /// by the kernel's own `kernel-info` extension (the one place versions
  /// exist). Empty when the runtime is down.
  Future<List<Map<String, dynamic>>> listActiveExtensions() async {
    // `this.host`, not the field: mock-host test subclasses override the
    // getter.
    final host = this.host;
    if (host == null) return const [];
    try {
      final result = await host.invokeHook('runtime',
          key: 'kernel', method: 'listExtensions', timeout: const Duration(seconds: 2));
      return result is List ? result.cast<Map<dynamic, dynamic>>().map((e) => e.cast<String, dynamic>()).toList() : const [];
    } on ExtensionHostException catch (e) {
      debugPrint('[extensions] listActiveExtensions failed: $e');
      return const [];
    }
  }

  /// Schedules a full runtime replacement (dispose + fresh start + re-seed)
  /// with capped exponential backoff. Safe against double-triggering: a
  /// crash reports through more than one channel, and a restart may itself
  /// fail and re-schedule.
  void _scheduleRestart(String reason) {
    if (_restartTimer != null || _exiting) return;
    _restartAttempts++;
    final delay = exponentialBackoff(_restartAttempts, cap: const Duration(seconds: 32)); // 2s..32s, then flat
    debugPrint('[extensions] $reason — restarting runtime in ${delay.inSeconds}s (attempt $_restartAttempts)');
    // A crash-looping runtime is a single point of failure for lookups, data
    // files, spots, and scoring all at once — the same "app just isn't doing
    // the thing" symptom class sync's own silent failures had.
    ErrorReportingService.report(reason, StackTrace.current, context: 'extensions:restart (attempt $_restartAttempts)');
    _restartTimer = Timer(delay, () async {
      _restartTimer = null;
      // onlyIfDead: by the time the backoff fires the runtime may have
      // recovered on its own (a crash reports through several channels) —
      // don't replace a healthy host.
      await _replaceRuntime(onlyIfDead: true);
    });
  }

  /// Takes the runtime down for good, on the way out of the app.
  ///
  /// The host is the one isolate that lets native code call back into Dart
  /// (QuickJS's `send` is a `NativeCallable`), and the VM's teardown disables
  /// isolate creation BEFORE it kills the isolates still running: a callback
  /// in that window is a FATAL abort on the way out (HALO-394). Disposing the
  /// host frees the JS runtime, so nothing is left to call back.
  ///
  /// Terminal: [start] and the crash-backoff restart stand down from here on.
  /// A boot or replacement already in flight is waited for, then disposed; if
  /// the caller's budget runs out first, [_start] disposes what it booted,
  /// because it re-reads [_exiting] before installing the host.
  Future<void> shutdownForExit() async {
    _exiting = true;
    _restartTimer?.cancel();
    _restartTimer = null;
    final inFlight = _restartFuture ?? _starting;
    if (inFlight != null) {
      await inFlight.catchError((_) {});
    }
    // Through the getter, not the field: a service whose host is supplied
    // some other way still owns its shutdown.
    final old = host;
    _host = null;
    await old?.dispose();
  }

  /// Restarts a LIVE runtime deliberately — extension enable/disable
  /// toggles use this to apply the new bundle set. Any pending crash-backoff
  /// timer is superseded (the replacement it wanted is happening now).
  Future<void> restartRuntime() {
    _restartTimer?.cancel();
    _restartTimer = null;
    return _replaceRuntime(onlyIfDead: false);
  }

  /// The one runtime-replacement path: dispose + fresh [start] + re-seed of
  /// the in-memory sync KV. Serialized behind [_restartFuture] — a second
  /// call while one is already in flight returns the SAME future rather than
  /// racing a second replace, so every caller (including
  /// [commitSettingsFieldValue], which awaits [_restartFuture] directly to
  /// avoid reading [host] while it's momentarily null) observes one
  /// consistent completion.
  Future<void> _replaceRuntime({required bool onlyIfDead}) {
    final inFlight = _restartFuture;
    if (inFlight != null) return inFlight;
    final future = _doReplaceRuntime(onlyIfDead: onlyIfDead);
    _restartFuture = future;
    return future;
  }

  Future<void> _doReplaceRuntime({required bool onlyIfDead}) async {
    try {
      // A boot may already be in flight (e.g. setSyncCredentials calls
      // start()); replacing the host under it would leak a live runtime.
      final inFlight = _starting;
      if (inFlight != null) await inFlight;
      if (onlyIfDead && _host != null && !_host!.isDead) return; // recovered on its own

      final old = _host;
      _host = null;
      _starting = null;
      // The new runtime may carry a different set of extensions (this is the
      // path an enable/disable toggle takes), so their advertised commands
      // have to be re-read rather than served from the old set's cache.
      _commandCatalog = null;
      final dying = _loadedExtensionKeys;
      await old?.dispose();
      // AFTER the dispose, not before: the old host is alive across that
      // await, and a fetch finishing inside that window posts its progress
      // through a host call that would land after the sweep, re-creating the
      // orphan. What "returning" means is decided here, where the next
      // generation's set is known.
      clearGenerationStatus(
        statusBar: statusBar,
        dying: dying,
        returning: {for (final info in availableExtensions) if (isExtensionActive(info)) info.key},
      );
      await start();
      if (_host != null) {
        // The fresh runtime lost all seeded KV state (it's in-memory).
        final creds = _lastSyncCredentials;
        if (creds != null) {
          await setSyncCredentials(deviceKey: creds.deviceKey, operatorCall: creds.operatorCall);
        }
        debugPrint('[extensions] runtime restarted');
      }
    } finally {
      _restartFuture = null;
    }
  }

  /// [_handleHostCall] for tests — the runtime credential path has no other
  /// seam, and it is the one that decides what an extension believes.
  @visibleForTesting
  Future<dynamic> debugHandleHostCall(String method, Map<String, dynamic> params) => _handleHostCall(method, params);

  Future<dynamic> _handleHostCall(String method, Map<String, dynamic> params) async {
    if (RadioHostCalls.handles(method)) return radioCalls.handle(method, params);
    switch (method) {
      case 'getAccount':
        final kvKey = params['kvKey'] as String;
        final cached = _accountItems[kvKey];
        if (cached != null) return cached.toHostResult();
        // A read made through the deadlock bypass (below) used device-local
        // options, which may not be this account's — its answer must not
        // outlive the refresh that resolves the real flag.
        final provisional = _refreshingAccountSynchronizable;
        final o = await _accountKeychainOptions(kvKey, fromHostCall: true);
        // This is the path an extension actually uses at runtime, so it must
        // not lie: an unguarded throw here rejects the host call, the
        // kernel turns a rejection into `undefined` (sdk/src/kernel.ts), and the
        // extension reads that as a logged-out account — the same collapse
        // `getAccountCredentials` refuses to make. Saying `unavailable` instead
        // lets an extension tell "you are signed out" from "we could not look".
        try {
          final credsStr = await _secureStorage.read(key: 'account_creds_$kvKey', mOptions: o.mOptions, iOptions: o.iOptions);
          final sessionStr = await _secureStorage.read(key: 'account_session_$kvKey', mOptions: o.mOptions, iOptions: o.iOptions);
          final items = AccountItems(creds: credsStr, session: sessionStr);
          if (!provisional) _accountItems[kvKey] = items;
          return items.toHostResult();
        } catch (e, st) {
          debugPrint('[extensions] secure storage unavailable for host getAccount $kvKey: $e');
          ErrorReportingService.report(e, st, context: 'accounts:host-get-account');
          final failed = AccountItems.unreadable();
          if (!provisional) _accountItems[kvKey] = failed;
          return failed.toHostResult();
        }
      case 'setAccountSession':
        final kvKey = params['kvKey'] as String;
        final o = await _accountKeychainOptions(kvKey, fromHostCall: true);
        final session = params['session'] as Map<dynamic, dynamic>;
        final encoded = jsonEncode(session);
        await _secureStorage.write(
          key: 'account_session_$kvKey',
          value: encoded,
          mOptions: o.mOptions,
          iOptions: o.iOptions,
        );
        final current = _accountItems.current(kvKey);
        if (current == null) return null;
        // The write went through, so a remembered failure no longer holds;
        // the next hook call rereads both items.
        if (current.unavailable) {
          _accountItems.remove(kvKey);
        } else {
          _accountItems[kvKey] = AccountItems(creds: current.creds, session: encoded);
        }
        return null;
      case 'getSettings':
        // The full read view of the app's settings — resolved typed values
        // with defaults applied, so extensions never re-derive fallbacks.
        // Deliberately absent: credentials and accounts (those live in the
        // platform keychain via the account hook system, never in
        // SettingsService) and device identifiers.
        return {
          'developerMode': settings?.developerMode ?? false,
          'locale': settings?.locale ?? 'en',
          // Lets a hook whose effect must stay invisible until its own
          // experiment ships ungated check per-call, rather than hiding at
          // the whole-extension `manifest.experiments` grain (which would
          // also gate every other hook the same extension registers).
          'enabledExperiments': [
            for (final entry in (settings?.experimentStates ?? const {}).entries)
              if (entry.value is Map && (entry.value as Map)['enabled'] == true) entry.key,
          ],
          // The catalog itself, so a hook can resolve a typed key-or-alias
          // to one of those keys (the EXP preview says "Enable"/"Disable"
          // rather than "Toggle"). Private entries included: EXP accepts them.
          'experiments': [
            for (final experiment in await loadExperiments())
              {'key': experiment.key, 'name': experiment.name, 'aliases': experiment.aliases},
          ],
          // Machine-facing: extensions put this in ADIF PROGRAMID, a spot's
          // source, etc. — so the fixed, platform-agnostic "Ham2K Logger", not
          // the UI's platform-tailored name.
          'appName': ham2kMachineName,
          // 'dev' | 'next' | 'prod' — for a hook whose static config must
          // vary per build edition (e.g. SOTA's OAuth client).
          'edition': kEdition.name,
          'themeMode': settings?.themeMode.name ?? 'system',
          'fontScale': settings?.fontScale.name ?? 'normal',
          'distanceUnits': settings?.distanceUnits.name ?? 'kilometers',
          // The RESOLVED characters, not the preference name: an extension
          // parsing what an operator typed needs to know which mark is the
          // decimal, and "use the device's settings" is not an answer it
          // could act on. Read from the same singleton every Dart surface
          // reads, so a hook and the field beside it cannot disagree.
          'decimalSeparator': NumberFormatting.instance.decimalSeparator,
          'groupingSeparator': NumberFormatting.instance.groupingSeparator,
          // Resolved the same way, and for the same reason: a hook writing a
          // locator needs a number of characters, and "six" is not one.
          'gridPrecision': GridPrecision.current.digits,
          'syncEnabled': settings?.syncEnabled ?? false,
          'operatorCall': settings?.activeProfile.operatorCall ?? '',
          // The rest of the active profile — personal details a log generator
          // may need for a submission (Cabrillo headers, Field Day's section).
          // All optional and all free-form; an extension must cope with ''.
          'operatorName': settings?.activeProfile.operatorName ?? '',
          'operatorEmail': settings?.activeProfile.operatorEmail ?? '',
          'operatorClub': settings?.activeProfile.operatorClub ?? '',
          'operatorSection': settings?.activeProfile.operatorSection ?? '',
          'leftieMode': settings?.leftieMode ?? false,
          'dxFlags': settings?.dxFlags.name ?? 'dx',
          'showBearing': settings?.showBearing ?? false,
          'switchSentRcvd': settings?.switchSentRcvd ?? false,
          'jumpAfterRST': settings?.jumpAfterRST ?? false,
          'defaultReport': settings?.defaultReport ?? '',
          'defaultReportCW': settings?.defaultReportCW ?? '',
          'defaultReportFT8': settings?.defaultReportFT8 ?? '',
          'bands': settings?.enabledBands ?? SettingsService.defaultBands,
          'modes': settings?.enabledModes ?? SettingsService.defaultModes,
          'showRSTFields': settings?.showRSTFields ?? true,
          'showStateField': settings?.showStateField ?? false,
          'showGridField': settings?.showGridField ?? false,
          'showDeletedQSOs': settings?.showDeletedQSOs ?? false,
          'showQsoNumbers': settings?.showQsoNumbers ?? true,
          'consentAppData': settings?.consentAppData ?? false,
          'consentOpData': settings?.consentOpData ?? false,
          // Extension-owned groups, raw — every extension can read every
          // group (settings are not secrets); writes are another matter.
          'extensions': settings?.extensionSettingsGroups() ?? const {},
        };
      case 'setSettings':
        // Writes are namespaced to the calling extension's own group
        // (`extension_<ns>`), enforced here by the SDK-injected ns — an
        // extension can never write core settings or another extension's.
        final ns = params['ns'] as String?;
        final values = params['values'];
        if (ns == null || ns.isEmpty || values is! Map) {
          debugPrint('[extensions] setSettings: missing ns or values — ignored');
          return null;
        }
        await settings?.updateSettingsGroup('extension_$ns', values.cast<String, dynamic>());
        return null;
      case 'searchSettings':
        // SET/SHOW/HIDE, resolved app-side: the settings catalog, the current
        // values, the option lists and the commit routing all live here, so
        // the command hook asks rather than carrying its own copy (which is
        // exactly what goes stale in app-polo's hand-listed version).
        //
        // This re-enters the extension runtime to read every settingsPanel
        // while the calling command hook is still awaiting us. Safe: hook
        // calls are keyed by id with independent completers and no lock (see
        // halo_extension_host.dart's `_send`), so the nested call settles
        // while the outer one waits.
        final search = onSearchSettings;
        if (search == null) return {'found': false};
        return search(params['args'] as String? ?? '', params['kind'] as String?);
      case 'translate':
        final key = params['key'] as String;
        final value = t[key];
        return value is String ? value : null;
      case 'translateAll':
        final keys = (params['keys'] as List).cast<String>();
        return {
          for (final key in keys) key: (t[key] is String ? t[key] : null),
        };
      case 'getOperation':
        final uuid = params['uuid'] as String;
        final operation = await operations?.get(uuid);
        // Same shape as qsonPayloadFor's `operation`: the QSON with `uuid`
        // folded in.
        return operation == null ? null : {...operation.data, 'uuid': operation.uuid};
      case 'getQsos':
        final operationUuid = params['operationUuid'] as String;
        // Null — not an empty list — when the operation is unknown or this
        // host has no log access, so callers can tell "no such operation"
        // from "operation with no QSOs yet" (see HookContext.getQsos).
        if (operations == null || qsos == null) return null;
        if (await operations!.get(operationUuid) == null) return null;
        // One-shot read via the watch stream's first emission — the same
        // convention ScoringService/ExportService use. Excludes soft-deleted
        // records, keeps event markers; oldest first.
        final list = await qsos!.watchForOperation(operationUuid).first;
        return [for (final qso in list) qso.data];
      case 'getSpotsForCall':
        // Reads the already-fetched cache — never triggers a fetch. This
        // runs inside the per-keystroke lookup pipeline, where waiting on a
        // fan-out to every spot source's API would blow the lookup's own 8s
        // budget; an empty answer before the first refresh lands is the
        // correct trade.
        final call = params['call'] as String?;
        final maxAgeMinutes = params['maxAgeMinutes'];
        if (call == null || spots == null) return const <Map<String, dynamic>>[];
        return spots!.spotsForCall(
          call,
          maxAge: Duration(minutes: maxAgeMinutes is num ? maxAgeMinutes.toInt() : 30),
        );
      case 'getHistoryForCall':
        // Backs `call-history`'s `ctx.getHistoryForCall` — cross-operation,
        // unlike `getQsos`, so it reads `qsos` directly rather than through
        // an operation. `[]` (not null) when there's no log access, same as
        // `getSpotsForCall`'s empty-cache answer: there's no "unknown call"
        // this call needs to distinguish from "no history".
        //
        // Capped at [_historyForCallLimit] — the extension only ever reads
        // the single most recent match (a couple more give it room to skip
        // past the QSO it's re-enriching); a call worked hundreds of times
        // must not ship its whole history for that.
        final historyCall = params['call'] as String?;
        if (historyCall == null || qsos == null) return const <Map<String, dynamic>>[];
        final history = await qsos!.historyForCall(historyCall, limit: _historyForCallLimit);
        return [for (final qso in history) qso.data];
      case 'dbLookupSelectOne':
        final category = params['category'] as String;
        final key = params['key'] as String;
        final row = await lookups?.getLookup(category, key);
        return row == null
            ? null
            : {
                'category': row.category,
                'subCategory': row.subCategory,
                'key': row.key,
                'name': row.name,
                'data': row.data != null ? jsonDecode(row.data!) : null,
                'lat': row.lat,
                'lon': row.lon,
                'flags': row.flags,
              };
      case 'dbLookupSelectAll':
        final category = params['category'] as String;
        final query = params['query'] as String;
        final subCategory = params['subCategory'] as String?;
        final activeOnly = params['activeOnly'] as bool? ?? false;
        final list =
            await lookups?.queryLookups(category, query, subCategory: subCategory, activeOnly: activeOnly) ?? const [];
        return list
            .map((row) => {
                  'category': row.category,
                  'subCategory': row.subCategory,
                  'key': row.key,
                  'name': row.name,
                  'data': row.data != null ? jsonDecode(row.data!) : null,
                  'lat': row.lat,
                  'lon': row.lon,
                  'flags': row.flags,
                })
            .toList();
      case 'dbLookupSelectByLocation':
        final category = params['category'] as String;
        final lat = (params['lat'] as num).toDouble();
        final lon = (params['lon'] as num).toDouble();
        final delta = (params['delta'] as num).toDouble();
        final activeOnly = params['activeOnly'] as bool? ?? false;
        final list =
            await lookups?.queryLookupsByLocation(category, lat, lon, delta, activeOnly: activeOnly) ?? const [];
        return list
            .map((row) => {
                  'category': row.category,
                  'subCategory': row.subCategory,
                  'key': row.key,
                  'name': row.name,
                  'data': row.data != null ? jsonDecode(row.data!) : null,
                  'lat': row.lat,
                  'lon': row.lon,
                  'flags': row.flags,
                })
            .toList();
      case 'getLocation':
        // One-shot device GPS fix (SDK's `host.getLocation()`) — e.g. WEATHER
        // falling back to device location when there's no operation grid.
        // May prompt for location permission; null on any denial/failure.
        // Gated by the manifest's `requiresLocation` capability,
        // same allowlist shape as host.fetch's `domains`.
        final extensionKey = params['extensionKey'] as String?;
        if (!_location.allows(extensionKey)) {
          throw ExtensionHostException(
            "getLocation blocked: extension '${extensionKey ?? 'unknown'}' does not declare requiresLocation",
          );
        }
        final position = await location?.getCurrentPosition();
        return position == null ? null : {'latitude': position.latitude, 'longitude': position.longitude};
      case 'getVersionInfo':
        // Read-only build identity — no capability gate, unlike getLocation:
        // none of this is sensitive, same reasoning as getSettings.
        //
        // buildNumber is null on Dev, where kBuildNumber is the LAST RELEASE's
        // number rather than the running build's — the same suppression
        // views/version_label.dart and services/flags_service.dart apply, for
        // the same reason. Naming a build that isn't running is worse than
        // naming none: on Dev the SHA is the only true identity.
        return {
          'platform': platformName(),
          'edition': kEdition.name,
          'version': kPublicVersion,
          'versionName': kEditionVersionName,
          'buildNumber': kEdition == Edition.dev ? null : kBuildNumber,
          'gitSha': kGitSha,
        };
      case 'showForm':
        final formId = params['formId'] as String;
        final formDef = (params['form'] as Map).cast<String, dynamic>();
        final state = (params['state'] as Map? ?? const {}).cast<String, dynamic>();

        final context = navigatorKey.currentContext;
        if (context == null) {
          throw StateError('No active navigation context found');
        }

        final result = await showFormDialog(
          context,
          formDefinition: formDef,
          initialState: state,
          validator: (fieldKey, value, currentState) async {
            try {
              final res = await _host?.invokeHook(
                'form',
                key: formId,
                method: 'validateField',
                args: {
                  'formId': formId,
                  'fieldKey': fieldKey,
                  'value': value,
                  'state': currentState,
                },
              );
              return res as String?;
            } catch (e) {
              return t.extensionService.validationError(error: e);
            }
          },
          transformer: (fieldKey, value, currentState) async {
            try {
              final res = await _host?.invokeHook(
                'form',
                key: formId,
                method: 'transformField',
                args: {
                  'formId': formId,
                  'fieldKey': fieldKey,
                  'value': value,
                  'state': currentState,
                },
              );
              return res;
            } catch (_) {
              return value;
            }
          },
          onChange: (fieldKey, value, currentState) async {
            try {
              final res = await _host?.invokeHook(
                'form',
                key: formId,
                method: 'onChangeField',
                args: {
                  'formId': formId,
                  'fieldKey': fieldKey,
                  'value': value,
                  'state': currentState,
                },
              );
              if (res is Map) {
                return res.cast<String, dynamic>();
              }
              return null;
            } catch (_) {
              return null;
            }
          },
          developerMode: settings?.developerMode ?? false,
        );
        return result;
      case 'showMessage':
        presentResultMessage(params, ns: params['ns'] as String? ?? 'extensions');
        return null;
      case 'statusBarSetMessage':
        statusBar?.setMessage(
          key: _namespacedKey(params),
          icon: params['icon'] as String?,
          title: params['title'] as String?,
          text: params['text'] as String?,
        );
        return null;
      case 'statusBarSetProgress':
        statusBar?.setProgress(
          key: _namespacedKey(params),
          icon: params['icon'] as String?,
          title: params['title'] as String?,
          text: params['text'] as String?,
          value: (params['value'] as num?)?.toDouble(),
        );
        return null;
      case 'statusBarClear':
        statusBar?.clear(_namespacedKey(params));
        return null;
      case 'statusBarShowNotice':
        statusBar?.showNotice(
          key: _namespacedKey(params),
          icon: params['icon'] as String?,
          title: params['title'] as String?,
          text: params['text'] as String? ?? '',
          actions: noticeActionsFromJson(params['actions'], onOpenAccount: onOpenAccount),
        );
        return null;
      case 'statusBarDismissNotice':
        statusBar?.dismissNotice(_namespacedKey(params));
        return null;
      default:
        throw UnimplementedError('Host call method $method not implemented');
    }
  }

  /// Extension-supplied keys are prefixed with the calling extension's key so
  /// one extension's status bar items/notices can never collide with — or be
  /// cleared/dismissed by — another's. Same `ns` convention as `kvGet`/`kvSet`.
  String _namespacedKey(Map<String, dynamic> params) {
    final ns = params['ns'] as String;
    final key = params['key'] as String;
    return '$ns:$key';
  }

  /// Set by the app shell: opens an account's standalone dialog (Settings →
  /// Accounts) from anywhere — the handler behind declarative `account`
  /// actions (an extension's "reconnect your account" button).
  OpenAccount? onOpenAccount;

  /// See [presentExtensionResultMessage] — wired to this service's status bar
  /// and account opener, which its two callers here already have.
  void presentResultMessage(Map<String, dynamic> message, {String ns = 'extensions'}) =>
      presentExtensionResultMessage(message, statusBar: statusBar, onOpenAccount: onOpenAccount, ns: ns);

  /// Set by the app shell: backs the `searchSettings` host call, resolving a
  /// SET/SHOW/HIDE query against the settings catalog
  /// (settings_command.dart). Lives here as a callback rather than a service
  /// reference because answering it needs the whole [HaLoServices] graph —
  /// the settings registry, the system lists, and this service itself.
  /// Unset in harnesses, which then report no match rather than failing.
  Future<Map<String, dynamic>> Function(String args, String? kind)? onSearchSettings;

  /// Deterministic offline lookups: with `--dart-define=HALO_STUB_LOOKUPS=1`
  /// in a dev build, [lookupCall] returns a fixed canned result instead of
  /// invoking the (network/credentialed) lookup extensions. `debugEnvFlag`
  /// returns '' in release, so this can never engage there.
  static final bool stubLookups =
      debugEnvFlag(const String.fromEnvironment('HALO_STUB_LOOKUPS'), 'HALO_STUB_LOOKUPS').isNotEmpty;

  /// Runs the full lookup pipeline for one callsign — the hardcoded
  /// callsign-annotation pre-step plus every registered `lookup` hook
  /// (QRZ, HamDB, POTA, SOTA…), merged with locationScope-aware rules —
  /// entirely inside the JS runtime via the single `lookupService/core`
  /// hook (mirrors `ScoringService`'s "one coarse call in, everything back
  /// out" shape). `online: false` asks every hook to skip network access
  /// (for a fast local-data-only preview pass); `qso`/`operation` give
  /// QSO-scoped hooks (e.g. POTA) access to refs already on the in-progress
  /// QSO. Returns `{lookups: [...], guess: {...}}`, or null if the runtime
  /// isn't up or nothing came back.
  ///
  /// `recentContext: true` additionally runs the `recentContextLookup` hooks
  /// (spot history, and whatever else comes to describe what a station is
  /// doing right now). Only the logging panel's compose path sets it: those
  /// hooks' answers are meaningless for a saved QSO being re-enriched, for
  /// the spots board's own per-call annotation, or for the quick lookup
  /// dialog — and each of those fans out over far more callsigns than the
  /// one being typed.
  Future<Map<String, dynamic>?> lookupCall(
    String call, {
    required Map<String, dynamic> qso,
    required Map<String, dynamic> operation,
    bool online = true,
    bool recentContext = false,
  }) async {
    if (stubLookups) return call.length < 3 ? null : stubbedLookupResult(call);
    final host = _host;
    if (host == null || call.length < 3) return null;
    // One key for the whole pipeline, unlike _syncTransportCall's per-method
    // one: `lookupCallInfo` is a single coarse hook, so there is no
    // per-source failure to keep apart here.
    const streakKey = 'extensions:lookup-call';

    // While we believe we have no internet the pipeline still runs, but every
    // hook is asked to stay local — call history, call notes, cached data
    // files. That is the whole suspension: the operator keeps getting the
    // answers we already hold, and we stop spending an 8-second timeout per
    // keystroke's worth of debounce to learn the network is still down.
    //
    // Nothing is queued for later. A lookup for a call typed ten minutes ago
    // is worthless by the time it would land — the background enrichment
    // queue (`LookupQueueService`) is where a deferred lookup belongs, and it
    // holds its own entries.
    final reachable = online && !ConnectivityService.isOffline;

    try {
      final result = await host.invokeHook(
        'lookupService',
        key: 'core',
        method: 'lookupCallInfo',
        args: {
          'callInfo': {'call': call},
          'qso': qso,
          'operation': operation,
          'online': reachable,
          'recentContext': recentContext,
        },
        timeout: const Duration(seconds: 8),
      );
      ErrorReportingService.recordSuccess(streakKey);
      if (result is! Map) return null;
      return result.cast<String, dynamic>();
    } on ExtensionHostException catch (e, st) {
      // The lookup runs on a debounced keystroke, so an upstream service
      // that is merely slow or briefly down would otherwise upload one
      // event per callsign typed for the length of the session. The streak
      // is what distinguishes that from a lookup pipeline that answers
      // nothing at all, which is a defect and whose only other trace would
      // be somebody writing in about empty callsign details.
      debugPrint('[extensions] lookup failed: $e');
      ErrorReportingService.reportIfRepeated(streakKey, e, st);
      return null;
    }
  }

  /// `{hookKey: scope}` for every `scoring` hook. `scope` is a plain data
  /// member on each hook (same access pattern as `spots`' `sourceName`), either
  /// the string `'always'` or `{refTypes: [...]}`, so the core can decide which
  /// scorers an operation needs *before* invoking any of them — a user may have
  /// dozens of extensions enabled while an operation references a handful
  /// (docs/design/contests.md §5.1).
  Future<Map<String, dynamic>> getScoringScopes() async {
    final host = _host;
    if (host == null) return const {};
    try {
      final entries = await host.invokeHookAll('scoring', method: 'scope', timeout: const Duration(seconds: 5));
      return {
        for (final entry in entries)
          if (entry['ok'] == true && entry['value'] != null) entry['key'] as String: entry['value'],
      };
    } catch (e) {
      debugPrint('[extensions] getScoringScopes failed: $e');
      return const {};
    }
  }

  /// The scoring hook keys relevant to [operation], paired with the ref that
  /// selected each. An `'always'` scorer maps to a null ref; a ref-gated one is
  /// listed once per matching ref TYPE — two refs of one type are ONE
  /// invocation, carrying the first, so an operation running two events of the
  /// same contest scores only one of them.
  ///
  /// An `'always'` scorer is marked `fallback` and sorted last. It still runs —
  /// it is the only thing covering a QSO no ref-gated scorer claims, and its
  /// tallies are the operation's QSO count, DXCC and bands — but its per-QSO
  /// verdict yields to any other scorer that scored the same QSO (the merge in
  /// `ScoringService.rescoreOperation`, [scoreQso] and [scoreCandidates]).
  /// Core's rule is call+band+mode, which knows nothing about references, so
  /// beside an activity it contradicts it: a station worked at a second park is
  /// fresh credit to POTA and a duplicate to core, and the entry row can show
  /// only one. Ref-gated scorers do NOT yield to each other — a POTA activation
  /// during CQ WW gets both, which is the operator running both.
  /// [segments] resolves the operation's `break`/`start` overrides. Selection
  /// spans EVERY segment: a contest that only covers the back half of a log
  /// would never be invoked if this read the base operation alone
  /// (docs/design/contests.md §5.1.3). The ref handed back is the first
  /// occurrence — the harness re-resolves it per QSO from the segment-effective
  /// operation, so a segment that restates its setup still wins.
  ///
  /// [alsoRefTypes] selects a ref-gated scorer the operation itself doesn't
  /// name — the ref types found in the LOG and in whatever is being scored.
  /// Without it an operation that only HUNTS references (the ordinary POTA
  /// chaser, no activation ref) selects no activity scorer at all, so nothing
  /// but the core call/band/mode dupe rule applies to it: a station worked at
  /// one park reads as a duplicate when spotted at another
  /// (docs/design/activities.md §4).
  ///
  /// Matched against the scope's `huntingRefTypes` ONLY, never its `refTypes`.
  /// A contest's ref type also rides its QSOs — as exchange data (`{type:
  /// 'cqww', theirZone}`) — so matching `refTypes` here would re-select a
  /// contest that a `break` has already ended, or one removed from the
  /// operation outright, which is precisely what segments exist to prevent.
  ///
  /// Such a scorer is paired with a null ref, like an `'always'` one. There is
  /// no operation ref to hand it and none is invented: an activity reads the
  /// references it is ACTIVATING off the operation, not off this ref
  /// (`activityScoring.ts`'s `activationRefsOf`), so a hunt-only operation
  /// correctly earns no activation credit.
  ///
  /// app-polo instead gives every activity a `generalHuntingType` and runs all
  /// of them on every operation. That is affordable in-process and is not here:
  /// each scorer is a bridge crossing carrying the log. Matching on ref types
  /// actually present adds at most one scorer per type hunted, rather than one
  /// per installed activity.
  static List<Scorer> scorersFor(
    Map<String, dynamic> operation,
    Map<String, dynamic> scopes, {
    SegmentedOperation? segments,
    Set<String> alsoRefTypes = const {},
  }) =>
      priority.scorersFor(
        operation,
        scopes,
        segmentRefs: segments == null ? null : [for (final segment in segments.segments) segment.refs],
        alsoRefTypes: alsoRefTypes,
      );

  /// The activity reference types appearing on [qsos] — what an operation is
  /// HUNTING, as opposed to the refs on the operation itself, which is what it
  /// is activating. Feeds [scorersFor]'s `alsoRefTypes`.
  ///
  /// `Qso.data` is already decoded, so this is a map read per QSO rather than a
  /// parse; callers that hold the log (a rescore, the logging panel) pay
  /// nothing extra for it.
  static Set<String> huntedRefTypesOf(Iterable<Qso> qsos) => {
        for (final qso in qsos)
          for (final ref in qso.refs)
            if (ref['type'] case final String type) type,
      };

  /// The reference types on one QSO-shaped map — a candidate being scored,
  /// which is not a [Qso] yet (the callsign being typed, a spot).
  static Set<String> refTypesOf(Map<String, dynamic> qso) => priority.refTypesOf(qso);

  /// One scorer's batched pass over an operation's QSOs. [resumeFrom] hands back
  /// that scorer's cached end-of-log scoresheet so only [qsos] — a tail — needs
  /// replaying; omit it for a full pass.
  Future<Map<String, dynamic>?> scoreQsos({
    required String scorerKey,
    required Map<String, dynamic> args,
  }) async {
    final host = _host;
    if (host == null) return null;
    try {
      final result = await host.invokeHook(
        'scoring',
        key: scorerKey,
        method: 'scoreQsos',
        args: args,
        timeout: const Duration(seconds: 10),
      );
      return result is Map ? result.cast<String, dynamic>() : null;
    } catch (e, stackTrace) {
      // One contest's scorer blowing up must not cost the operation its core
      // scoring, so failures are per-scorer.
      _reportScorerFailure(scorerKey, 'scoreQsos', e, stackTrace);
      return null;
    }
  }

  /// Scores the single in-progress QSO — the callsign being typed, before
  /// Enter — for the logging panel's live call-info line. Returns
  /// `{notices, alerts}` of scoring keys (`duplicate`, `newBand`, `newMode`,
  /// `newDXCC`, `newState`, `newProvince`, plus whatever a contest scorer emits
  /// — the vocabulary is open), merged across every scorer relevant to the
  /// operation, or null
  /// when the runtime isn't up. Debounced on the caller's side.
  /// [excludeUuid] drops the record being edited so it can't flag itself as
  /// its own duplicate. [operation] must carry `uuid` (the hook reads the log
  /// via it) — pass the same uuid-folded shape command hooks get.
  ///
  /// [operation] is the CURRENT segment, not the base, so scorer selection
  /// follows what the operator is doing right now: a contest that ended at a
  /// break stops contributing pills, one that started at a break begins.
  /// [segments] (`SegmentedOperation.payload`, omitted when unsegmented) is
  /// what lets the hook fold the history under each QSO's own segment
  /// (docs/design/contests.md §5.1.3).
  ///
  /// [huntedRefTypes] are the activity types this operation has hunted —
  /// `Operation.localData['huntedRefTypes']`, cached by `ScoringService`. The
  /// candidate's OWN references are added to them here, so the first contact
  /// with a program still selects its scorer before any rescore has recorded
  /// it. Without either, an operation that activates nothing selects no
  /// activity scorer and the pills fall back to the core dupe rule alone (see
  /// [scorersFor]).
  Future<Map<String, dynamic>?> scoreQso({
    required Map<String, dynamic> operation,
    required Map<String, dynamic> qso,
    String? excludeUuid,
    List<Map<String, dynamic>>? segments,
    Set<String> huntedRefTypes = const {},
  }) async {
    // The public accessor rather than `_host`, as in [scoreCandidates]: the
    // priority merge below is the thing worth a test, and a private field
    // can't be stood in for. Identical in production — the getter returns
    // `_host`.
    final host = this.host;
    if (host == null) return null;

    final scorers = scorersFor(
      operation,
      await getScoringScopes(),
      alsoRefTypes: {...huntedRefTypes, ...refTypesOf(qso)},
    );
    if (scorers.isEmpty) return null;

    // Sorted by scorer key so the merged notice/alert order is stable —
    // invokeHookAll gives no ordering guarantee, and the call-info line builds
    // a dedupe signature by joining these lists.
    final notices = SplayTreeSet<String>();
    final alerts = SplayTreeSet<String>();
    var any = false;
    // The fallback scorer's own verdict, held back until every other scorer has
    // answered: once one of them has judged this QSO on the worked-before axis,
    // the fallback's judgement of it yields (see [Scorer],
    // [judgesWorkedBefore]).
    final fallbackNotices = SplayTreeSet<String>();
    final fallbackAlerts = SplayTreeSet<String>();
    var judgedByOther = false;

    await Future.wait(scorers.map((scorer) async {
      try {
        final result = await host.invokeHook(
          'scoring',
          key: scorer.key,
          method: 'scoreQso',
          args: {
            'operation': operation,
            'qso': qso,
            'excludeUuid': ?excludeUuid,
            'ref': ?scorer.ref,
            'segments': ?segments,
          },
          timeout: const Duration(seconds: 4),
        );
        if (result is! Map) return;
        any = true;
        if (!scorer.fallback && judgesWorkedBefore(result)) judgedByOther = true;
        (scorer.fallback ? fallbackNotices : notices)
            .addAll(((result['notices'] as List?) ?? const []).whereType<String>());
        (scorer.fallback ? fallbackAlerts : alerts)
            .addAll(((result['alerts'] as List?) ?? const []).whereType<String>());
      } catch (e, stackTrace) {
        // A scorer that FAILED judged nothing, so the fallback speaks for this
        // QSO after all rather than the row going bare.
        _reportScorerFailure(scorer.key, 'scoreQso', e, stackTrace);
      }
    }));

    if (!any) return null;
    if (judgedByOther) {
      notices.addAll(fallbackNotices.where((n) => !kWorkedBeforeNotices.contains(n)));
      alerts.addAll(fallbackAlerts.where((a) => !kWorkedBeforeAlerts.contains(a)));
    } else {
      notices.addAll(fallbackNotices);
      alerts.addAll(fallbackAlerts);
    }
    return {'notices': notices.toList(), 'alerts': alerts.toList()};
  }

  /// The same live judgement as [scoreQso], for many not-yet-logged candidates
  /// at once — the Spots Panel annotating every spot on screen against the
  /// operation's log. Returns `{candidateKey: {notices, alerts}}` merged across
  /// every scorer relevant to [operation], or null when NO pass happened — the
  /// runtime isn't up, or no scorer applies. A scorer that ran and failed is
  /// not that case: see the return below.
  ///
  /// One bridge crossing per scorer, not per candidate: the runtime folds the
  /// log once and scores every candidate against it (DESIGN.md §4). Calling
  /// [scoreQso] in a loop instead would cost a round-trip AND a whole-log fold
  /// per spot, which is why this exists.
  ///
  /// [candidates] is keyed by whatever the caller can match up afterwards —
  /// candidates have no uuid, since a spot is not a record. Keys absent from
  /// the result had nothing to report.
  ///
  /// [operationUuid] is taken separately and folded in here rather than left to
  /// the caller: it is how the hook reaches the log, and an [operation] map
  /// without it scores every candidate against an EMPTY log — no errors, no
  /// warnings, just nothing ever reported as a duplicate.
  /// [scoresheets] are `ScoringService`'s cached end-of-log scoresheets, keyed
  /// by scorer — `Operation.localData['scoring'][key]['scoresheet']`. Supplying
  /// them skips the whole-log fold each scorer would otherwise do, which on a
  /// long log is the dominant cost of a pass.
  ///
  /// Only pass them when the log has not moved since that cache was written: a
  /// scoresheet is a checkpoint, not a live view, so resuming from a stale one
  /// judges candidates against a log missing its most recent contacts. The
  /// caller knows which of the two it has; this cannot tell.
  Future<Map<String, Map<String, List<String>>>?> scoreCandidates({
    required Map<String, dynamic> operation,
    required String operationUuid,
    required Map<String, Map<String, dynamic>> candidates,
    List<Map<String, dynamic>>? segments,
    Map<String, dynamic>? scoresheets,
    Set<String> huntedRefTypes = const {},
  }) async {
    // The public accessor rather than `_host` directly: what this method sends
    // over the bridge is the thing worth a test, and a private field can't be
    // stood in for. Identical in production — the getter returns `_host`.
    final host = this.host;
    if (host == null || candidates.isEmpty) return null;

    final withUuid = {...operation, 'uuid': operationUuid};
    // The candidates' own references count as well as the log's: a station
    // worked bare who is now spotted at a park is a NEW reference, and a
    // log-only rule would leave that spot struck as a plain duplicate.
    final scorers = scorersFor(
      withUuid,
      await getScoringScopes(),
      alsoRefTypes: {
        ...huntedRefTypes,
        for (final candidate in candidates.values) ...refTypesOf(candidate),
      },
    );
    if (scorers.isEmpty) return null;

    final payload = [
      for (final entry in candidates.entries) {'key': entry.key, 'qso': entry.value},
    ];

    // Sorted like scoreQso's, so a candidate's merged notice order is stable
    // across refreshes and the panel's styling doesn't flicker between two
    // scorers' orderings.
    final merged = <String, ({SplayTreeSet<String> notices, SplayTreeSet<String> alerts})>{};
    // Per CANDIDATE, not per pass: the fallback yields only on the candidates
    // another scorer has judged on the worked-before axis (see [Scorer],
    // [judgesWorkedBefore]). A whole spots board answered with
    // `missingExchange` — which is what a VHF test says about every spot, since
    // a spot carries no exchange — has been judged on no such thing, and the
    // board would otherwise lose its dupe striking outright.
    final fallbackMerged = <String, ({SplayTreeSet<String> notices, SplayTreeSet<String> alerts})>{};
    final judgedByOther = <String>{};
    var any = false;
    // Tracked apart from [any] because the two mean opposite things to the
    // caller. No scorer answering can be a pass that had nothing to say, or a
    // runtime not up yet; a scorer FAILING is a verdict that should exist and
    // doesn't — and the board must not keep showing the last one it had.
    var failed = false;

    await Future.wait(scorers.map((scorer) async {
      try {
        final result = await host.invokeHook(
          'scoring',
          key: scorer.key,
          method: 'scoreCandidates',
          args: {
            'operation': withUuid,
            'candidates': payload,
            'ref': ?scorer.ref,
            'segments': ?segments,
            'resumeFrom': ?scoresheets?[scorer.key],
          },
          // Longer than scoreQso's: this folds the whole log once and then
          // scores every candidate, where that scores one.
          timeout: const Duration(seconds: 20),
        );
        if (result is! Map) return;
        any = true;
        ErrorReportingService.recordSuccess(_scorerFailureKey(scorer.key, 'scoreCandidates'));
        for (final entry in result.entries) {
          final key = entry.key;
          final value = entry.value;
          if (key is! String || value is! Map) continue;
          if (!scorer.fallback && judgesWorkedBefore(value)) judgedByOther.add(key);
          final target = scorer.fallback ? fallbackMerged : merged;
          final into = target.putIfAbsent(
            key,
            () => (notices: SplayTreeSet<String>(), alerts: SplayTreeSet<String>()),
          );
          into.notices.addAll(((value['notices'] as List?) ?? const []).whereType<String>());
          into.alerts.addAll(((value['alerts'] as List?) ?? const []).whereType<String>());
        }
      } catch (e, stackTrace) {
        // Per-scorer, like scoreQso: a contest scorer that throws must not cost
        // the spots their core dupe marking.
        failed = true;
        _reportScorerFailure(scorer.key, 'scoreCandidates', e, stackTrace);
      }
    }));

    // A failure returns the surviving scorers' verdicts — an EMPTY map when
    // the only scorer was the one that failed — rather than null. Null means
    // "no pass happened", which the panel answers by keeping the verdicts it
    // has; doing that here would leave a board struck through by a scorer that
    // is no longer running. Losing the strikes is the safe direction: an
    // un-struck worked spot costs a glance, a struck unworked one costs the
    // contact.
    if (!any && !failed) return null;
    for (final entry in fallbackMerged.entries) {
      final judged = judgedByOther.contains(entry.key);
      final notices = judged
          ? entry.value.notices.where((n) => !kWorkedBeforeNotices.contains(n))
          : entry.value.notices;
      final alerts = judged
          ? entry.value.alerts.where((a) => !kWorkedBeforeAlerts.contains(a))
          : entry.value.alerts;
      if (notices.isEmpty && alerts.isEmpty) continue;
      final into = merged.putIfAbsent(
        entry.key,
        () => (notices: SplayTreeSet<String>(), alerts: SplayTreeSet<String>()),
      );
      into.notices.addAll(notices);
      into.alerts.addAll(alerts);
    }
    return {
      for (final entry in merged.entries)
        if (entry.value.notices.isNotEmpty || entry.value.alerts.isNotEmpty)
          entry.key: {
            'notices': entry.value.notices.toList(),
            'alerts': entry.value.alerts.toList(),
          },
    };
  }

  /// Asks every registered `command` hook (priority order) to interpret the input command.
  /// Returns the first non-null interpretation result: `{describe, confirm, commands}`.
  /// Returns null when nothing matched, the input is empty, or the runtime isn't up.
  /// [execute] should be true only for the final call made right before
  /// actually running a complete interpretation — see CommandHook.interpret's
  /// `execute` doc (extensions/sdk/src/types.ts). Every other call (the
  /// typing-debounce describe preview) should leave it false.
  Future<Map<String, dynamic>?> interpretCommand(
    String input, [
    Map<String, dynamic>? operation,
    Map<String, dynamic>? qso,
    bool execute = false,
  ]) async {
    final host = _host;
    if (host == null || input.isEmpty) return null;
    try {
      final entries = await host.invokeHookAll(
        'command',
        method: 'interpret',
        args: {
          'input': input,
          'operation': ?operation,
          'qso': ?qso,
          if (execute) 'execute': true,
        },
        // The describe preview must stay snappy (it reruns on every
        // keystroke pause), but the one execute call is where hooks do
        // real work — SEED's log read + lookups, SOLAR/WEATHER's network
        // fetch — so it gets room to breathe instead of dying at 2s.
        timeout: execute ? const Duration(seconds: 30) : const Duration(seconds: 2),
      );
      for (final entry in entries) {
        if (entry['ok'] == true && entry['value'] is Map) {
          return (entry['value'] as Map).cast<String, dynamic>();
        }
      }
    } on ExtensionHostException catch (e) {
      debugPrint('[extensions] interpretCommand failed: $e');
      // At execute time the user pressed Enter on a recognized command —
      // returning null here would read as "no command matched" and the UI
      // would silently do nothing after a long wait (a hook exceeding its
      // timeout, e.g. a stalled SOLAR/WEATHER fetch, lands here). Surface
      // it through the same `error` channel a hook itself would use.
      if (execute) return {'error': t.extensionService.commandFailed};
    }
    return null;
  }

  /// Every command advertised by a `command` hook's optional `catalog()`, for
  /// the command dialog's browsable list — `{command, describe, params?,
  /// category?, needsOperation?, expectsParams?, suggest?}` per entry (see
  /// `CommandCatalogEntry`, extensions/sdk/src/types.ts).
  ///
  /// Cached, deliberately: unlike [interpretCommand] this is NOT per
  /// keystroke — the palette matches the typed text against these entries
  /// host-side, on plain strings. The cache is dropped whenever the runtime is
  /// replaced (extension enable/disable) or the hook context is invalidated
  /// (locale change), which are the only things that change the answer.
  ///
  /// Entries keep hook priority order, so a higher-priority extension's
  /// commands list first, matching which one would actually win `interpret`.
  Future<List<Map<String, dynamic>>> getCommandCatalog() async {
    final cached = _commandCatalog;
    if (cached != null) return cached;

    final host = this.host;
    if (host == null) return const [];
    try {
      final entries = await host.invokeHookAll('command', method: 'catalog', timeout: const Duration(seconds: 2));
      final catalog = <Map<String, dynamic>>[];
      for (final entry in entries) {
        // `catalog` is optional on CommandHook, so a hook that doesn't
        // implement it reports not-ok here — that's expected, not a failure.
        if (entry['ok'] != true || entry['value'] is! List) continue;
        for (final item in entry['value'] as List) {
          if (item is! Map) continue;
          final map = item.cast<String, dynamic>();
          // A malformed entry would render as a blank, unselectable row.
          if (map['command'] is! String || (map['command'] as String).isEmpty) continue;
          catalog.add(map);
        }
      }
      _commandCatalog = List.unmodifiable(catalog);
      return _commandCatalog!;
    } catch (e) {
      debugPrint('[extensions] getCommandCatalog failed: $e');
      // Not cached — a transient runtime failure shouldn't leave the palette
      // permanently empty for the rest of the session.
      return const [];
    }
  }

  /// [getCommandCatalog]'s cache. Null means "not read yet"; an empty list is
  /// a real answer (no hook advertises anything).
  List<Map<String, dynamic>>? _commandCatalog;

  /// Descriptors for controls activities want on the logging panel. `qso` is
  /// the in-progress QSO (including any `their.guess` from the callsign
  /// lookup pipeline) — pass it so an extension can key a QSO-scoped
  /// `placeholder`/`transforms` (e.g. a DXCC-derived reference prefix) off
  /// it; omit for a QSO-agnostic refresh (e.g. right after the operation loads).
  Future<ControlsResult> loggingControls(Map<String, dynamic> operationData, {Map<String, dynamic>? qso}) =>
      _collectControls('loggingControls', operationData, qso: qso);

  /// Descriptors for controls activities want in operation settings.
  Future<ControlsResult> operationControls(Map<String, dynamic> operationData, {Map<String, dynamic>? qso}) =>
      _collectControls('operationControls', operationData, qso: qso);

  /// The activity reference TYPES each installed extension registers, keyed by
  /// extension key: `pota` -> `(activationType: 'potaActivation',
  /// huntingType: 'pota')`. A deep link, and anything else naming an activity
  /// by its key, needs this to turn `pota:US-1234` into a real ref.
  ///
  /// Read off the `refList` control descriptors an activity ALREADY publishes
  /// rather than from a hook of its own: those descriptors are where an
  /// activity names its types, the control key is already namespaced by
  /// extension key (the same namespace the activity search's scope resolves
  /// to a hook through — the scope WORD itself comes from the type, see
  /// `activityScopeWord`), and a second declaration would be a second thing
  /// to keep in step. An operation control is an activation, a logging
  /// control is a hunt.
  ///
  /// Only extensions that are switched ON answer, because only they publish
  /// controls — matching app-polo, whose `findHooks('activity', {key})` sees
  /// registered hooks alone. A key nobody claims is absent here, and a caller
  /// skips that reference rather than inventing a type for it.
  ///
  /// [operationData] is passed through to the hooks, which may key a
  /// descriptor's placeholder off it; the ref TYPES never vary with it, so an
  /// empty map is a fine argument when there is no operation yet.
  ///
  /// `loadFailed` carries [ControlsResult]'s own distinction and MUST be
  /// honoured: an empty `byKey` with `loadFailed` set means "could not ask",
  /// not "nobody claims that key". Telling an operator their installed
  /// activity is unknown, because the runtime had not finished booting, is a
  /// confident false statement about their own setup.
  ///
  /// Awaits [start] first for exactly that reason. It memoizes the in-flight
  /// future, so a caller arriving mid-boot waits for the same start everyone
  /// else is waiting for rather than triggering a second one — and a deep
  /// link that cold-launches the app arrives before boot has finished.
  Future<({Map<String, ({String? activationType, String? huntingType})> byKey, bool loadFailed})>
      activityRefTypes({Map<String, dynamic> operationData = const {}}) async {
    await start();
    final results = await Future.wait([
      operationControls(operationData),
      loggingControls(operationData),
    ]);
    final activation = _refTypesByExtensionKey(results[0].controls);
    final hunting = _refTypesByExtensionKey(results[1].controls);
    return (
      byKey: {
        for (final key in {...activation.keys, ...hunting.keys})
          key: (activationType: activation[key], huntingType: hunting[key]),
      },
      loadFailed: results[0].loadFailed || results[1].loadFailed,
    );
  }

  /// The `refList` ref type each control descriptor carries, keyed by the
  /// extension key its control key is namespaced with (`pota/activation` ->
  /// `pota`). Controls that are not reference lists carry no type and are
  /// skipped.
  ///
  /// The first descriptor for a key wins. Every activity publishes exactly one
  /// `refList` per surface, so which one that is never comes up — if that ever
  /// stops being true, the tie needs a real rule rather than fan-out order.
  static Map<String, String> _refTypesByExtensionKey(List<Map<String, dynamic>> controls) {
    final types = <String, String>{};
    for (final control in controls) {
      final controlKey = (control['key'] as String?) ?? '';
      final extensionKey = controlKey.split('/').first;
      if (extensionKey.isEmpty || types.containsKey(extensionKey)) continue;
      final input = control['input'];
      if (input is! Map) continue;
      final refType = input['refType'];
      if (refType is String && refType.isNotEmpty) types[extensionKey] = refType;
    }
    return types;
  }

  /// Lets activities project data they own into generic QSON fields just
  /// before a QSO is written — a contest mirroring the exchange it keeps on
  /// its own ref into `their.exchange`, which is what the QSO row's exchange
  /// column and a plain ADIF export read. See `ActivityHook.processQsoBeforeSave`.
  ///
  /// Returns [qsoData] with every hook's patch merged in, unchanged if nothing
  /// contributed. Degrades silently: a hook that throws or times out must never
  /// cost the operator their QSO, so the save proceeds undecorated.
  ///
  /// Skipped when the operation carries no refs — ordinary logging is the
  /// common case and must not pay a bridge crossing per QSO for a hook only
  /// contests implement.
  Future<Map<String, dynamic>> decorateQsoBeforeSave(
    Map<String, dynamic> qsoData,
    Map<String, dynamic> operationData,
  ) async {
    final host = _host;
    if (host == null) return qsoData;
    final refs = operationData['refs'];
    if (refs is! List || refs.isEmpty) return qsoData;

    try {
      final entries = await host.invokeHookAll(
        'activity',
        method: 'processQsoBeforeSave',
        args: {'qso': qsoData, 'operation': operationData},
        // Saving blocks the operator's next QSO, so a stalled hook loses its
        // contribution rather than the log its pace.
        timeout: const Duration(seconds: 2),
      );
      var merged = qsoData;
      for (final entry in entries) {
        if (entry['ok'] != true || entry['value'] is! Map) continue;
        // The hook's own key is what lets a patch touch that extension's ref
        // and no other (see `mergeQsoPatch`). An entry with no key can still
        // project into `their`/`our`, but writes no ref at all.
        final owner = entry['key'];
        merged = mergeQsoPatch(
          merged,
          (entry['value'] as Map).cast<String, dynamic>(),
          owner: owner is String ? owner : '',
        );
      }
      return merged;
    } on ExtensionHostException catch (e) {
      debugPrint('[extensions] processQsoBeforeSave failed: $e');
      return qsoData;
    }
  }

  Future<ControlsResult> _collectControls(
    String method,
    Map<String, dynamic> operationData, {
    Map<String, dynamic>? qso,
  }) async {
    // Through the getter, not `_host`: a test subclass overrides `host`, and
    // reading the field behind it routes every such test down the no-host
    // path below without ever invoking a hook.
    final host = this.host;
    // No host is a failure, not an empty answer: the runtime is dead or
    // still starting (see ErrorPolicy's `extension-runtime-dead`), and the
    // operator's refs are no less real for it.
    if (host == null) return (controls: const <Map<String, dynamic>>[], loadFailed: true);
    try {
      final entries = await host.invokeHookAll(
        'activity',
        method: method,
        args: {'operation': operationData, 'qso': ?qso},
        // The timeout is ONE budget for the whole fan-out, so without this a
        // single slow extension discards the controls every other hook had
        // already returned — the operator loses POTA's fields because SOTA
        // is warming a cache. Activities are independent contributors here,
        // and the hooks that time out come back synthesized as ok:false,
        // which is what sets `loadFailed` and names them below. A partial
        // answer is safe precisely because it is no longer a silent one.
        partialOnTimeout: true,
      );
      final controls = <Map<String, dynamic>>[];
      var loadFailed = false;
      for (final entry in entries) {
        // `invokeHookAll` synthesizes {key, ok: false, error} precisely so a
        // caller can name the source rather than just notice an absence.
        if (entry['ok'] != true) {
          loadFailed = true;
          debugPrint('[extensions] $method: hook ${entry['key']} failed: ${entry['error']}');
          continue;
        }
        // A hook that answered with something other than a list contributed
        // nothing, but it ANSWERED — `partitionHookEntries` classifies the
        // same entry as a success, and the two must agree. The kernel wraps
        // every return as `value: (await …) ?? null`, so a hook that simply
        // falls off its end lands here; calling that a failure would show a
        // permanent "controls unavailable" notice for a legal no-op.
        //
        // A non-null one is still a shape bug worth an author seeing, though:
        // `[42]` below is named in the log, and silence here would make the
        // narrower mistake the harder one to find.
        final value = entry['value'];
        if (value is! List) {
          if (value != null) {
            debugPrint('[extensions] $method: hook ${entry['key']} answered ${value.runtimeType}, wanted a List');
          }
          continue;
        }
        for (final control in value) {
          // Per element, NOT `value.cast<Map>()`: that cast is lazy, so a bad
          // element throws its TypeError during `addAll` — past the
          // ExtensionHostException catch below, out through the unawaited
          // future the callers start in initState, leaving them stuck on
          // `loading` for the life of the screen.
          if (control is! Map) {
            loadFailed = true;
            debugPrint('[extensions] $method: hook ${entry['key']} returned a ${control.runtimeType} control');
            continue;
          }
          controls.add(control.cast<String, dynamic>());
        }
      }
      // Read, don't cast: `as num?` throws on `{'order': '1'}` — a string an
      // extension reading its own config produces easily — and it throws from
      // inside the comparator, which is the same escape route past the catch
      // below that the per-element check above exists to close.
      num orderOf(Map<String, dynamic> control) => control['order'] is num ? control['order'] as num : 0;
      controls.sort((a, b) => orderOf(a).compareTo(orderOf(b)));
      return (controls: controls, loadFailed: loadFailed);
    } on ExtensionHostException catch (e) {
      // A timeout with something salvageable behind it is handled above, by
      // `partialOnTimeout`. What reaches here is the whole fan-out failing —
      // a dead runtime, or a timeout with nothing settled — where there is
      // no partial answer to keep.
      debugPrint('[extensions] $method failed: $e');
      return (controls: const <Map<String, dynamic>>[], loadFailed: true);
    }
  }

  /// Candidate activities for the "add activity" search, merged across every
  /// `activity` hook and sorted by `distance / relevance` ascending — a more
  /// relevant hit (relevance is 0..1, higher is better) effectively counts
  /// as closer, so it doesn't lose out to a less relevant but nearer one
  /// (results missing a distance sort after ranked ones — an extension
  /// search hit with no location still surfaces). `location` comes from the
  /// operation's own coordinate, else the centre of its grid, else
  /// [fallbackLocation] (typically the
  /// device's current GPS position — see ActivitiesView) so nearby
  /// suggestions still work before the operation's location is set.
  /// `callsign` falls back from the operation's own settings to the
  /// operator's global default.
  /// [activityKeys] scopes the fan-out to the activity extensions serving one
  /// ref type (the search field's `pota:` prefix — usually one hook, two when
  /// a user-published extension serves the same type as a stock one) — those
  /// hooks alone are asked, rather than every hook's results being merged and
  /// then filtered, so an unrelated extension's slow search can't hold up a
  /// scoped one.
  /// [preferredKeys] is the softer form (a `pota ` prefix, no colon): everyone
  /// is still asked, but those hooks' results lead the list and they search
  /// for [preferredSearchTerm] — the box's text with the word stripped — while
  /// the others get [searchTerm] verbatim.
  /// Answers whether every source failed as well as the suggestions
  /// themselves: "nothing matched" and "every extension broke" are the same
  /// empty list, and only the second is worth telling the operator about.
  Future<ActivitySuggestionResult> suggestActivities(
    Map<String, dynamic> operationData, {
    String? searchTerm,
    GridLocation? fallbackLocation,
    List<String>? activityKeys,
    List<String>? preferredKeys,
    String? preferredSearchTerm,
  }) async {
    final host = _host;
    if (host == null) return (suggestions: const <Map<String, dynamic>>[], allSourcesFailed: false);

    // The operation's own coordinate first, then the centre of its grid: a
    // park two kilometres away and one eight kilometres away rank the same
    // from a square's centre, and this ordering is what the operator reads as
    // "nearby".
    final gridLocation = locationFromLatLon(operationData['lat'], operationData['lon']) ??
        gridToLocation(operationData['grid'] as String?) ??
        fallbackLocation;
    final callsign = (operationData['stationCall'] as String?)?.isNotEmpty == true
        ? operationData['stationCall'] as String
        : settings?.activeProfile.operatorCall;

    // `scoped` tells a hook its type alone is being asked for — the operator
    // picked its "Activity Types" row, or typed its word as a scope. A bare
    // scope and the nearby list both arrive with no search term, and an
    // extension that keeps itself out of the nearby list still has to answer
    // when it is the one being asked.
    Map<String, dynamic> argsSearchingFor(String? term, {bool scoped = false}) => {
          'operation': operationData,
          if (gridLocation != null) 'location': {'lat': gridLocation.latitude, 'lon': gridLocation.longitude},
          if (callsign != null && callsign.isNotEmpty) 'callsign': callsign,
          if (term != null && term.isNotEmpty) 'searchTerm': term,
          if (scoped) 'scoped': true,
        };

    try {
      if (activityKeys != null) {
        // Each hook asked on its own, wrapped in invokeHookAll's own
        // {key, ok, value} entry shape so the merge doesn't need a second
        // code path — and so one failing hook is one failed entry rather
        // than the whole scope's answer.
        final entries = await Future.wait([
          for (final key in activityKeys)
            host
                .invokeHook(
                  'activity',
                  key: key,
                  method: 'suggest',
                  args: argsSearchingFor(searchTerm, scoped: true),
                  timeout: const Duration(seconds: 5),
                )
                .then((value) => <String, dynamic>{'key': key, 'ok': true, 'value': value})
                .onError<ExtensionHostException>((e, _) {
              debugPrint('[extensions] scoped activity hook $key failed: $e');
              return <String, dynamic>{'key': key, 'ok': false, 'error': '$e'};
            }),
        ]);
        return (suggestions: mergeActivitySuggestions(entries), allSourcesFailed: allActivitySourcesFailed(entries));
      }

      // The preferred hooks are asked SEPARATELY because they search for
      // something else — the word stripped off the front — so their answers
      // to the everyone-else question are discarded below rather than merged.
      // A fan-out that never returned an entry is a failure with nothing to
      // count, so it contributes one — the caller has to be able to tell
      // "nobody could answer" from "nobody had anything".
      var fanOutFailed = false;
      final preferred = Future.wait([
        for (final key in preferredKeys ?? const <String>[])
          host
              .invokeHook(
                'activity',
                key: key,
                method: 'suggest',
                args: argsSearchingFor(preferredSearchTerm),
                timeout: const Duration(seconds: 5),
              )
              .then((value) => <String, dynamic>{'key': key, 'ok': true, 'value': value})
              // Precedence is only an ordering: when a preferred hook fails,
              // what the other extensions found is still the right answer.
              .onError<ExtensionHostException>((e, _) {
            debugPrint('[extensions] preferred activity hook $key failed: $e');
            return <String, dynamic>{'key': key, 'ok': false, 'error': '$e'};
          }),
      ]).then((entries) => [
            for (final entry in entries)
              if (entry['ok'] == true) entry,
          ]);

      // The fan-out is ONE message under ONE timeout, so its failure takes
      // every hook with it — but not the preferred one, asked separately and
      // quite possibly already answered. Each side therefore degrades on its
      // own, and only a search where both failed comes back empty.
      final everyone = host
          .invokeHookAll(
            'activity',
            method: 'suggest',
            args: argsSearchingFor(searchTerm),
            timeout: const Duration(seconds: 5),
          )
          .onError<ExtensionHostException>((e, _) {
        debugPrint('[extensions] activity suggestion fan-out failed: $e');
        fanOutFailed = true;
        return const [];
      });

      final results = await Future.wait([preferred, everyone]);
      final preferredSet = preferredKeys?.toSet() ?? const <String>{};
      final entries = [
        ...results[0],
        for (final entry in results[1])
          if (!preferredSet.contains(entry['key'])) entry,
      ];
      return (
        suggestions: mergeActivitySuggestions(entries, preferredKeys: preferredSet),
        allSourcesFailed: (fanOutFailed && entries.isEmpty) || allActivitySourcesFailed(entries),
      );
    } on ExtensionHostException catch (e) {
      debugPrint('[extensions] suggestActivities failed: $e');
      return (suggestions: const <Map<String, dynamic>>[], allSourcesFailed: true);
    }
  }


  /// The current LoFi account/device/client info, for display in Settings.
  /// Returns null if the runtime isn't up or the request failed (e.g. no
  /// network) — callers should treat that as "status unknown", not "no sync".
  ///
  /// Every fresh fetch also persists the snapshot into
  /// `settings.syncState['accountData']` — the static copy the declarative
  /// sync settings group displays, so building a settings schema never
  /// needs a network round-trip. Only this method (called from the Sync
  /// panel's refreshes and post-link flows) updates it.
  Future<Map<String, dynamic>?> syncAccountData() async {
    final host = _host;
    if (host == null) return null;
    try {
      final result = await host.invokeHook('syncTransport', method: 'getAccountData', args: const {});
      final data = result is Map ? result.cast<String, dynamic>() : null;
      final currentSettings = settings;
      if (data != null && currentSettings != null) {
        final state = currentSettings.syncState;
        // Only write (and notify) on a real change — the Sync panel
        // refreshes on every open.
        if (jsonEncode(state['accountData']) != jsonEncode(data)) {
          await currentSettings.setSyncState({...state, 'accountData': data});
        }
      }
      return data;
    } on ExtensionHostException catch (e) {
      debugPrint('[extensions] syncAccountData failed: $e');
      return null;
    }
  }

  /// Requests a link permission from the sync server: a pending challenge
  /// for [email] (or an immediate switch when this client already has a
  /// permission on that account), or — with null — a blank permission for
  /// QR-code linking. Server rejections (e.g. no account with that email)
  /// come back as `{'error': ..., 'error_status': ...}` in the map; null
  /// means the server couldn't be reached at all.
  Future<Map<String, dynamic>?> syncLinkClient(String? email) async {
    final host = _host;
    if (host == null) return null;
    try {
      final result = await host.invokeHook(
        'syncTransport',
        method: 'linkClient',
        args: {'email': ?email},
      );
      return result is Map ? result.cast<String, dynamic>() : null;
    } on ExtensionHostException catch (e) {
      debugPrint('[extensions] syncLinkClient failed: $e');
      return null;
    }
  }

  /// Requests a link-by-email challenge from the sync server. Returns null
  /// on failure; callers should surface that as "couldn't reach the server".
  Future<Map<String, dynamic>?> syncLinkClientWithEmail(String email) async {
    final host = _host;
    if (host == null) return null;
    try {
      final result = await host.invokeHook('syncTransport', method: 'linkClientWithEmail', args: {'email': email});
      return result is Map ? result.cast<String, dynamic>() : null;
    } on ExtensionHostException catch (e) {
      debugPrint('[extensions] syncLinkClientWithEmail failed: $e');
      return null;
    }
  }

  /// Sets the sync account's email address — a change, or the first claim
  /// on an anonymous account. The server records it as `pending_email` and
  /// mails a confirmation link; only following that link makes it the
  /// account's real address. [syncResendAccountEmail] mails it again.
  ///
  /// Both return `{'error': ..., 'error_status': ...}` for a rejection the
  /// operator can act on (the address is taken, nothing is pending), and
  /// null when the server couldn't be reached at all.
  Future<Map<String, dynamic>?> syncSetAccountEmail(String email) =>
      _syncTransportCall('setAccountEmail', {'email': email});

  Future<Map<String, dynamic>?> syncResendAccountEmail() => _syncTransportCall('resendAccountEmail', const {});

  /// Finds the pending link request a challenge code refers to — the
  /// confirming side of the flow [syncLinkClient] starts on the other
  /// device. Returns the server's `{'permissions': [...]}`; an expired or
  /// mistyped code simply yields an empty list.
  Future<Map<String, dynamic>?> syncFindLinkRequest(String challengeToken) =>
      _syncTransportCall('findLinkRequest', {'challenge_token': challengeToken});

  /// The same lookup for a request that arrived as a `link_client` deep
  /// link, which names the requesting device outright. Returns the server's
  /// `{'permission': ...}`, whose value is null when the link has expired.
  Future<Map<String, dynamic>?> syncFindLinkRequestByClient({
    required String clientUuid,
    required String challengeToken,
  }) =>
      _syncTransportCall('findLinkRequestByClient', {'client': clientUuid, 'challenge_token': challengeToken});

  /// Grants a link request: the other device joins this account.
  /// [challengeToken] is what binds an orphaned (QR/deep-link) permission to
  /// this account, so it must be passed back for those; a request raised by
  /// email is already attached and ignores it.
  Future<Map<String, dynamic>?> syncApproveLinkRequest({
    required String clientUuid,
    String? challengeToken,
  }) =>
      _syncTransportCall('approveLinkRequest', {
        'client': clientUuid,
        'challenge_token': ?challengeToken,
      });

  /// Shared shape of the account/linking calls above: null when the runtime
  /// isn't up or the host call failed, the server's map otherwise —
  /// including the `error`/`error_status` maps those endpoints return for
  /// rejections that belong to the UI flow rather than to error reporting.
  Future<Map<String, dynamic>?> _syncTransportCall(String method, Map<String, dynamic> args) async {
    final host = _host;
    if (host == null) return null;
    final streakKey = 'syncTransport:$method';
    try {
      final result = await host.invokeHook('syncTransport', method: method, args: args);
      ErrorReportingService.recordSuccess(streakKey);
      return result is Map ? result.cast<String, dynamic>() : null;
    } on ExtensionHostException catch (e, stackTrace) {
      // Every one of these is an operator waiting on a button they just
      // pressed. One failure is the network; the same one failing every
      // time is a defect whose only other trace would be somebody writing
      // in to say nothing happened. Keyed per method so a broken
      // approveLinkRequest isn't hidden by a healthy getAccountData.
      debugPrint('[extensions] $method failed: $e');
      ErrorReportingService.reportIfRepeated(streakKey, e, stackTrace, context: streakKey);
      return null;
    }
  }

  /// Ensures this device is registered with the sync server — independent
  /// of whether the operator has QSO sync enabled; registration
  /// establishes device identity and the realtime push channel, it never
  /// pushes log data. Returns null if the runtime isn't up or registration
  /// failed (e.g. no network) — callers should treat that as "not
  /// available yet", not as "sync is off".
  ///
  /// [refreshWebhookToken] makes this fetch a CURRENT webhook token instead of
  /// returning the cached one, at the cost of a round trip. Required of any
  /// caller putting that token in an OAuth `state`: it is a one-hour signed
  /// message, so a device registered longer ago than that carries one the
  /// relay refuses. Off by default because `pushChannelName` — what boot and
  /// operator-callsign changes come here for — never expires, and they must
  /// keep working offline.
  Future<LofiClientRegistration?> ensureLofiClientRegistered({bool refreshWebhookToken = false}) async {
    // Through the getter, not the `_host` field the neighbours read: the
    // getter is the seam a test can substitute, and what crosses it here —
    // the args map, matched by string on the JavaScript side — has no other
    // way to be checked.
    final host = this.host;
    if (host == null) return null;
    try {
      final result = await host.invokeHook('syncTransport',
          method: 'ensureClientRegistered', args: {'refreshWebhookToken': refreshWebhookToken});
      if (result is! Map) return null;
      final map = result.cast<String, dynamic>();
      final pushChannelName = map['push_channel_name'] as String?;
      final webhookClientToken = map['webhook_client_token'] as String?;
      if (pushChannelName == null || webhookClientToken == null) return null;
      return (pushChannelName: pushChannelName, webhookClientToken: webhookClientToken);
    } on ExtensionHostException catch (e) {
      debugPrint('[extensions] ensureLofiClientRegistered failed: $e');
      return null;
    }
  }

  /// Fetches this device's pending webhook events — the poll
  /// fallback, and how a caller retrieves the actual payload after a
  /// [HaLoServices.webhookEvents] Pusher ping (which intentionally carries
  /// only an id, never the sensitive payload).
  Future<List<Map<String, dynamic>>> fetchLofiWebhookEvents() async {
    final host = _host;
    if (host == null) return const [];
    try {
      final result = await host.invokeHook('syncTransport', method: 'fetchWebhookEvents', args: const {});
      final events = result is Map ? result['webhook_events'] : null;
      if (events is! List) return const [];
      return events.whereType<Map<dynamic, dynamic>>().map((e) => e.cast<String, dynamic>()).toList();
    } on ExtensionHostException catch (e) {
      debugPrint('[extensions] fetchLofiWebhookEvents failed: $e');
      return const [];
    }
  }

  /// Files a report the app composed itself — the equipment editor's radio
  /// report — as a real CaBo card, through whichever sync transport is
  /// registered. [kind] must be one of `idea`/`task`/`bug`; anything else is
  /// silently downgraded to `bug` server-side.
  ///
  /// Returns the card's ref on success (null when the server filed it but
  /// named no ref), or the failure as operator-facing text — including the
  /// refusal when no account is configured, which the transport owns so both
  /// this and the REPORT command refuse in the same words.
  ///
  /// A transport that predates `submitReport` (or no transport at all) is
  /// reported as an error rather than as a silent no-op: the operator has just
  /// written a report and pressed Send.
  Future<({String? ref, String? error})> submitReport({
    required String title,
    required String body,
    required String kind,
  }) async {
    final host = _host;
    if (host == null) {
      debugPrint('[extensions] submitReport: no runtime');
      return (ref: null, error: t.extensionService.reportUnavailable);
    }
    try {
      final result = await host.invokeHook(
        'syncTransport',
        method: 'submitReport',
        args: {'title': title, 'body': body, 'kind': kind},
        // The same room `interpretCommand` gives an executing command: this is
        // two round trips (device registration, then the report itself)
        // against a server that may be reached over a slow link.
        timeout: const Duration(seconds: 30),
      );
      if (result is! Map) {
        // A transport with no `submitReport` lands exactly here: the kernel's
        // callHookMethod returns a missing member as-is, so the hook resolves
        // ok with null rather than throwing. The operator's message cannot say
        // that, so the console has to — otherwise a hook renamed in a refactor
        // is an app that quietly stops accepting reports, in the field,
        // forever, with nothing anywhere to say why.
        debugPrint('[extensions] submitReport: transport answered ${result.runtimeType}, not a Map');
        return (ref: null, error: t.extensionService.reportUnavailable);
      }
      final error = result['error'];
      if (error is String && error.isNotEmpty) return (ref: null, error: error);
      final ref = result['ref'];
      return (ref: ref is String && ref.isNotEmpty ? ref : null, error: null);
    } on ExtensionHostException catch (e) {
      debugPrint('[extensions] submitReport failed: $e');
      return (ref: null, error: t.extensionService.reportUnavailable);
    }
  }

  /// Decorates a ref (park name, location…) via its `ref:<type>` handler.
  /// Returns the input unchanged if no handler answers.
  Future<Map<String, dynamic>> decorateRef(Map<String, dynamic> ref) async {
    final host = _host;
    final type = ref['type'] as String?;
    if (host == null || type == null) return ref;
    try {
      final decorated = await host.invokeHook('ref:$type', method: 'decorateRef', args: {'ref': ref});
      if (decorated is Map) return decorated.cast<String, dynamic>();
    } on ExtensionHostException catch (e) {
      debugPrint('[extensions] decorateRef failed: $e');
    }
    return ref;
  }

  /// Where a ref can be read about on the web, via its `ref:<type>` handler —
  /// the program's own page for it, or a contest's rules.
  ///
  /// Resolved for display and thrown away: nothing here is ever written back
  /// onto the operation's ref, so a program that changes its URLs takes effect
  /// with the extension rather than needing every saved operation rewritten.
  Future<RefLink?> linkForRef(Map<String, dynamic> ref) async {
    final host = _host;
    final type = ref['type'] as String?;
    if (host == null || type == null) return null;
    try {
      final result = await host.invokeHook('ref:$type', method: 'linkForRef', args: {'ref': ref});
      return refLinkFromHookResult(result, type: type);
    } on ExtensionHostException catch (e) {
      debugPrint('[extensions] linkForRef failed: $e');
      return null;
    }
  }

  /// Where a ref's own outline can be fetched as GeoJSON, via its `ref:<type>`
  /// handler — a summit's SOTA activation zone, a park's boundary.
  ///
  /// The hook only builds a URL; fetching and caching are the app's
  /// (GeoshapeService). Same disposable resolution as [linkForRef]: nothing is
  /// written back onto the ref, so a program that moves its files takes effect
  /// with the extension.
  Future<RefGeojson?> geojsonUrlForRef(Map<String, dynamic> ref) async {
    final host = _host;
    final type = ref['type'] as String?;
    if (host == null || type == null) return null;
    try {
      final result = await host.invokeHook('ref:$type', method: 'geojsonUrlForRef', args: {'ref': ref});
      return refGeojsonFromHookResult(result, type: type);
    } on ExtensionHostException catch (e) {
      debugPrint('[extensions] geojsonUrlForRef failed: $e');
      return null;
    }
  }
}

/// Whether a dev-loop reload of one extension can be swapped into the running
/// runtime, or whether the runtime has to be restarted around it.
///
/// [alreadyDevServed] is the one that is easy to leave out and expensive to get
/// wrong. Build secrets are resolved ONCE, when the runtime starts, and a
/// reload deliberately does not re-resolve them — so an extension whose slot
/// was filled from the app's own assets is holding the secrets that come with
/// that, and swapping dev code into it hands them over. The reachable path is
/// not exotic: an extension that fails its FIRST build is left out of the dev
/// server's index, so the app loads that key from assets, and the author's next
/// successful save is a reload of a key that already holds real credentials
/// (HALO-425). Restarting re-resolves them against the dev provenance, which is
/// the only thing that makes them absent.
///
/// [capabilitiesUnchanged] covers the manifest flags a reload cannot carry:
/// `domains` travels with the bundle, but the rest are start-time allowlists
/// in the host ([ExtensionInfo.sameStartTimeCapabilities]).
@visibleForTesting
bool canHotSwapDevBundle({
  required bool runtimeAlive,
  required bool alreadyLoaded,
  required bool alreadyDevServed,
  required bool capabilitiesUnchanged,
}) =>
    runtimeAlive && alreadyLoaded && alreadyDevServed && capabilitiesUnchanged;

/// The extensions the app offers with a dev server connected: each [dev] entry
/// REPLACES the asset extension of the same key — which is what lets an author
/// iterate on `pota` itself rather than only on something new — and a dev
/// extension with a key nothing ships is appended.
///
/// Asset order is preserved, so connecting a dev server does not reshuffle the
/// Extensions panel under the operator. Two dev entries claiming one key cannot
/// happen: they arrive from a map keyed by exactly that.
List<ExtensionInfo> mergeDevExtensions(List<ExtensionInfo> fromAssets, List<ExtensionInfo> dev) {
  if (dev.isEmpty) return fromAssets;
  final byKey = {for (final info in dev) info.key: info};
  final unplaced = {...byKey.keys}..removeAll(fromAssets.map((info) => info.key));
  return [
    for (final info in fromAssets) byKey[info.key] ?? info,
    for (final key in unplaced) byKey[key]!,
  ];
}
