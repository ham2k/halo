// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The outward hook calls: every per-category wrapper that turns a raw
// `invokeHook`/`invokeHookAll` into a domain-shaped answer, and the result
// types and readers those answers are built with.

part of 'extension_service.dart';

/// What the activity picker's search came back with, and whether it came back
/// at all. [allSourcesFailed] separates "no extension had a match" from "no
/// extension could answer" — identical empty lists that mean opposite things
/// to the operator. [someSourcesFailed] says at least one could not: with
/// nothing found, the one that failed may be the one holding the answer.
typedef ActivitySuggestionResult = ({List<Map<String, dynamic>> suggestions, bool allSourcesFailed, bool someSourcesFailed});

/// The control descriptors an activity fan-out produced, and whether any
/// source failed to answer. [loadFailed] separates "no extension declares
/// controls" from "an extension that does declare them could not answer" —
/// identical empty lists, and only the second may not be treated as the
/// operator's ref types being unknown. Without it a hook that throws or
/// times out is indistinguishable from its extension being uninstalled, and
/// `isUnknownRefType` says exactly that to the operator.
typedef ControlsResult = ({List<Map<String, dynamic>> controls, bool loadFailed});

/// The descriptor field naming the extension that supplied a control. The
/// host writes it as the fan-out answers, over anything the extension put
/// there: the control's own `key` is the extension's to choose, and a
/// catalog `ham2k-pota` keys its controls `pota/…`, so the key cannot say
/// which extension to ask or to name.
const controlExtensionKeyField = 'extensionKey';

/// The extension that supplied [control], or empty for a descriptor that did
/// not come through the fan-out.
String controlExtensionKey(Map<String, dynamic> control) => control[controlExtensionKeyField] as String? ?? '';

/// How far a screen's [ControlsResult] fetch has got. A bool cannot express
/// [failed] — it only says "not loaded yet" — so a fetch that threw leaves a
/// two-state screen showing its loading placeholder forever, with the
/// unknown-ref treatment suppressed the whole time.
enum ControlsLoadState { loading, loaded, failed }

/// What one `invokeHookAll` fan-out actually produced, split by outcome.
typedef HookPartition = ({List<Map<String, dynamic>> items, List<String> succeeded, List<String> unreachable, List<({String key, String? error})> failed});

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

/// A callsign lookup answered a field of the wrong type, dropped by
/// [normalizeLookupResult] on the way out of [ExtensionService.lookupCall].
/// The guess is the lookup pipeline's merged answer, so this names the field
/// and never the extension that wrote it; and the type, never the value,
/// since guesses carry names and notes. Classified `report` in [ErrorPolicy]:
/// the rest of the answer still reaches the operator.
class MalformedLookupDataException implements Exception {
  MalformedLookupDataException(this.violation);
  final QsonTypeViolation violation;

  @override
  String toString() => 'MalformedLookupDataException: $violation';
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
  final withTest = Operation(uuid: '', data: operation).isTestOperation ? _spotCallForTestOperation(stationCall) : stationCall;
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

/// One reference's answer from its `ref:<type>` handler — see
/// [ExtensionService.refHookAnswers]. Not [asked] when the ref carries no
/// type a handler could be found by; [ok] with the handler's [value] when it
/// answered; asked but not ok when it threw, ran out of time, or there was no
/// runtime to ask — and [noHandler] as well when no program registers its
/// type, which is an answer about the reference rather than a failure.
typedef RefHookAnswer = ({bool asked, bool ok, bool noHandler, Object? value});

/// A template the renderer refused — see [ExtensionService.renderTemplate].
/// The message is the renderer's own, written for the operator who typed
/// the template.
class TemplateError implements Exception {
  final String message;
  const TemplateError(this.message);
  @override
  String toString() => message;
}

mixin _ExtensionHookApi {
  // Owned by the class or by another part of this library.
  ExtensionHost? get host;

  /// Hands [lines] to [extensionKey]'s `cluster.onLines` hook — the lines a
  /// node sent since the last batch, for an extension that subscribed.
  Future<void> deliverClusterLines(String extensionKey, List<Map<String, dynamic>> lines) async {
    await host?.invoke(Hooks.clusterOnLines, key: extensionKey, args: {'lines': lines}, timeout: const Duration(seconds: 5));
  }

  SettingsService? get settings;
  StatusBarService? get statusBar;
  List<ExtensionInfo> get availableExtensions;
  Map<String, dynamic> _attributedCommand(Map<String, dynamic> interpretation, String? extensionKey);
  String _describedByOwner(String describe, String? extensionKey);
  bool get activationIncomplete;
  void invalidateHookContext();
  Future<void> start();
  void presentResultMessage(Map<String, dynamic> message, {String ns});

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
  Future<({List<Map<String, dynamic>> items, List<String> succeeded, List<String> unreachable, List<String> failed})> _collectHookResults(
    HookRef hook, {
    required Object? args,
    required String debugLabel,
    bool partialOnTimeout = false,
    int failureThreshold = ErrorReportingService.repeatedFailureThreshold,
  }) async {
    final host = this.host;
    if (host == null) {
      return (items: const <Map<String, dynamic>>[], succeeded: const <String>[], unreachable: const <String>[], failed: const <String>[]);
    }
    var parts = emptyHookPartition;
    try {
      parts = partitionHookEntries(await host.invokeAll(hook, args: args, timeout: const Duration(seconds: 10), partialOnTimeout: partialOnTimeout));
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
    return (items: parts.items, succeeded: parts.succeeded, unreachable: parts.unreachable, failed: [for (final f in parts.failed) f.key]);
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
      (await _collectHookResults(Hooks.exportSuggestExportOptions, args: args, debugLabel: 'getExportOptions')).items;

  /// A shared type is listed once, using the highest-priority registration.
  Future<List<Map<String, dynamic>>> getExportTypes() async {
    final host = this.host;
    return host == null ? [] : collectExportTypes(host);
  }

  Future<List<Map<String, dynamic>>> exportTypeSettings(Map<String, dynamic> global, Map<String, dynamic> Function(String type) overrides) async {
    if (host == null) return [];
    final definitions = await getExportTypes();
    final result = await host!.invoke(
      Hooks.templateExportSettings,
      key: 'templates',
      args: {
        'definitions': definitions,
        'global': global,
        'overrides': {for (final definition in definitions) definition['exportType'] as String: overrides(definition['exportType'] as String)},
      },
    );
    return (result as List? ?? []).map((value) => Map<String, dynamic>.from(value as Map)).toList();
  }

  Future<List<Map<String, dynamic>>> prepareExports(Map<String, dynamic> args) async {
    final result = await host!.invoke(Hooks.templatePrepareExports, key: 'templates', args: args);
    return (result as List).map((value) => Map<String, dynamic>.from(value as Map)).toList();
  }

  /// Every `spots` hook currently willing to post a spot (Spotting
  /// control), each tagged with `hookKey` so a later
  /// `sendSpot` call can be routed back to it. Calls `isSelfSpotEnabled`
  /// when `qso` is omitted, `isOtherSpotEnabled` otherwise; hooks that don't
  /// implement the relevant method, or report `enabled: false`, are
  /// silently absent — same convention as `getExportOptions`.
  Future<List<Map<String, dynamic>>> suggestSpotSources({required Map<String, dynamic> operation, Map<String, dynamic>? qso}) async {
    final host = this.host;
    if (host == null) return const [];
    // Every poster would send the call as typed, `?` and all, to a network
    // other operators chase from.
    if (qsonHasIncompleteCall(qso)) return const [];
    // No source is even asked to self-spot an operation that rules it out.
    if (qso == null && !Operation.dataAllows(operation, Operation.selfSpottingKey)) return const [];
    final hook = qso == null ? Hooks.spotsIsSelfSpotEnabled : Hooks.spotsIsOtherSpotEnabled;
    final args = qso == null ? {'operation': operation} : {'qso': qso};
    try {
      final entries = await host.invokeAll(hook, args: args, timeout: const Duration(seconds: 5));
      final sources = <Map<String, dynamic>>[];
      for (final entry in entries) {
        if (entry['ok'] != true || entry['value'] is! Map) continue;
        final value = (entry['value'] as Map).cast<String, dynamic>();
        if (value['enabled'] != true) continue;
        sources.add({...value, 'hookKey': entry['key']});
      }
      if (sources.isEmpty) return sources;
      // What the Spotting control names each source's icon with.
      final names = await getSpotSourceNames();
      return [
        for (final source in sources) {...source, 'name': ?names[source['hookKey']]},
      ];
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
  Future<({List<Map<String, dynamic>> items, List<String> succeeded, List<String> unreachable, List<String> failed})> getSpots() async {
    final parts = await _collectHookResults(
      Hooks.spotsFetchSpots,
      args: const {},
      debugLabel: 'getSpots',
      partialOnTimeout: true,
      failureThreshold: _spotSourceFailureThreshold,
    );
    return (items: validSpots(parts.items), succeeded: parts.succeeded, unreachable: parts.unreachable, failed: parts.failed);
  }

  /// `{hookKey: sourceName}` for every `spots` hook, for the Spots Panel's
  /// source filter labels (e.g. `pota` -> "POTA.app"). `sourceName` is a
  /// plain data member on each hook, not a method — `invokeHookAll` returns
  /// it directly without an args/ctx round-trip, same as any other field
  /// access through the hook-call bridge.
  Future<Map<String, String>> getSpotSourceNames() async {
    final host = this.host;
    if (host == null) return const {};
    try {
      final entries = await host.invokeAll(Hooks.spotsSourceName, timeout: const Duration(seconds: 5));
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
  ///
  /// The mode that goes out is [displayMode]'s, not the stored sideband: a
  /// spot is read by other operators, so it is a display, and the sideband a
  /// band runs is what the frequency beside it already says. The one that
  /// contradicts the band is spelled out, because that is the fact a reader
  /// cannot derive. Both paths are normalized here rather than in every
  /// poster — the other-spot path never carries a `mode` argument at all, so
  /// it is the QSO copy sent JS-side that has to be corrected.
  Future<Map<String, Map<String, dynamic>>> sendSpot({
    required List<Map<String, dynamic>> sources,
    required Map<String, dynamic> operation,
    Map<String, dynamic>? qso,
    double? freq,
    String? mode,
    String? comment,
    String? spotterCall,
  }) async {
    final host = this.host;
    if (host == null) return const {};
    final hook = qso == null ? Hooks.spotsPostSelfSpot : Hooks.spotsPostOtherSpot;
    var spotOperation = operation;
    var spotQso = qso;
    if (qso == null) {
      final spotCall = spotCallForSelfSpot(operation);
      if (spotCall != operation['stationCall']) spotOperation = {...operation, 'stationCall': spotCall};
    } else {
      // Probed, not cast, like [spotCallForSelfSpot] above: this QSO blob
      // crossed the extension bridge, and a cast that throws here is outside
      // the per-source guard below, so it takes every source's spot with it.
      final spotMode = displayMode(asQsonString(qso['mode']), freqKHz: asQsonNum(qso['freq'])?.toDouble(), band: asQsonString(qso['band']));
      if (spotMode != qso['mode']) spotQso = {...qso, 'mode': spotMode};
    }
    final args = qso == null
        ? {
            'operation': spotOperation,
            // No band to fall back on, and none needed: both entry points
            // refuse a self-spot with no frequency, and every poster requires
            // one. Were that to loosen, a picked band with a deliberate far
            // sideband would fold to `SSB` — the one case that must not.
            'freq': freq,
            'mode': displayMode(mode, freqKHz: freq),
            'comment': comment,
          }
        : {'qso': spotQso, 'comment': comment, 'spotterCall': spotterCall};
    final entries = await Future.wait(
      sources.map((source) async {
        final hookKey = source['hookKey'] as String?;
        try {
          final result = await host.invoke(hook, key: hookKey, args: args, timeout: const Duration(seconds: 15)) as Map;
          return MapEntry(hookKey ?? '', result.cast<String, dynamic>());
        } catch (e) {
          return MapEntry(hookKey ?? '', <String, dynamic>{'ok': false, 'message': e.toString()});
        }
      }),
    );
    for (final entry in entries) {
      debugPrint('[spots] ${hook.method} via ${entry.key}: ${entry.value}');
      final userMessage = entry.value['userMessage'];
      if (userMessage is Map) {
        presentResultMessage(userMessage.cast<String, dynamic>(), ns: entry.key);
      }
    }
    return {for (final entry in entries) entry.key: entry.value};
  }

  /// [template] rendered by the core `templates` extension's `template` hook
  /// (docs/extensions/templates.md), against [operation] and [qso] in the
  /// same shape the panels get — so `{{ qso.call }}` in a CW message means
  /// what it means in a pane. Returns the text, or throws a [TemplateError]
  /// carrying the renderer's own words for a template that does not parse.
  /// Null with no runtime, which callers treat as "nothing to send".
  ///
  /// [keyer] is `{messages, current?}` — the keyer's messages for
  /// `keyer.msgN`, and which one this is, so it can't include itself.
  Future<String?> renderTemplate(
    String template, {
    Map<String, dynamic>? operation,
    Map<String, dynamic>? qso,
    int? qsoCount,
    Map<String, dynamic>? log,
    Map<String, dynamic>? keyer,
  }) async {
    final host = this.host;
    if (host == null) return null;
    final result = await host.invoke(
      Hooks.templateRender,
      key: 'templates',
      args: {'template': template, 'operation': ?operation, 'qso': ?qso, 'qsoCount': ?qsoCount, 'log': ?log, 'keyer': ?keyer},
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
    Map<String, dynamic>? keyer,
  }) async {
    final host = this.host;
    if (host == null) return null;
    final result = await host.invoke(
      Hooks.templateRenderMany,
      key: 'templates',
      args: {'templates': templates, 'operation': ?operation, 'qso': ?qso, 'qsoCount': ?qsoCount, 'keyer': ?keyer},
      timeout: const Duration(seconds: 2),
    );
    if (result is! Map || result['results'] is! List) return null;
    return [
      for (final entry in result['results'] as List)
        entry is Map ? (text: entry['text'] as String?, error: entry['error'] as String?) : (text: null, error: null),
    ];
  }

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
    String? streakKey,
  }) => _lookupCall(call, qso: qso, operation: operation, online: online, recentContext: recentContext, streakKey: streakKey, despiteAssistance: false);

  /// [lookupCall], going online even for an operation without assistance —
  /// only for a pass the operator confirmed after being warned (Lookup All
  /// QSOs; `confirmLookupDespiteAssistance`). Everything else still applies:
  /// [online], and the connectivity gate.
  Future<Map<String, dynamic>?> lookupCallDespiteAssistance(
    String call, {
    required Map<String, dynamic> qso,
    required Map<String, dynamic> operation,
    bool online = true,
    bool recentContext = false,
    String? streakKey,
  }) => _lookupCall(call, qso: qso, operation: operation, online: online, recentContext: recentContext, streakKey: streakKey, despiteAssistance: true);

  Future<Map<String, dynamic>?> _lookupCall(
    String call, {
    required Map<String, dynamic> qso,
    required Map<String, dynamic> operation,
    required bool online,
    required bool recentContext,
    required String? streakKey,
    required bool despiteAssistance,
  }) async {
    if (ExtensionService.stubLookups) return call.length < 3 ? null : stubbedLookupResult(call);
    final host = this.host;
    if (host == null || call.length < 3) return null;
    // One key for the whole pipeline, unlike _syncTransportCall's per-method
    // one: `lookupCallInfo` is a single coarse hook, so there is no
    // per-source failure to keep apart here. A caller that fans out over many
    // calls at once (the spot board) passes its own [streakKey], so a burst
    // it caused does not read as the operator's lookup failing.
    streakKey ??= 'extensions:lookup-call';

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
    //
    // An operation without assistance (`Operation.assistance`) is asked the
    // same way, for good: an online source is outside information, while the
    // local answers are the operator's own. The background enrichment of
    // logged contacts takes that local pass as its answer too.
    final reachable = online && !ConnectivityService.isOffline && (despiteAssistance || Operation.dataAllows(operation, Operation.assistanceKey));

    try {
      final result = await host.invoke(
        Hooks.lookupServiceLookupCallInfo,
        key: 'core',
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
      return _normalizedLookup(result);
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

  /// [lookupCall] for each of [requests], in ONE crossing under one budget:
  /// one answer per request, in order, null where that lookup did not answer.
  ///
  /// For a caller looking up many callsigns at once — the spot board. Called
  /// one by one, a board of a few hundred calls is a few hundred crossings
  /// arriving together, each running every lookup hook, and the database
  /// queries behind them (call history) queue up until everything else that
  /// reads the database waits seconds behind them — the activity search's
  /// nearby parks among them.
  ///
  /// A failure counts toward [streakKey] once per batch, and only when the
  /// batch answered nothing — `lookupCall`'s "the pipeline answers nothing at
  /// all". A batch with one straggler among answers is a busy engine, not a
  /// broken pipeline, and counting it would hold the streak past its one
  /// report so a real outage later reports nothing.
  ///
  /// No partials on a timeout: narrating a batch puts every answer on the
  /// bridge twice, on every batch, to salvage some answers only when one
  /// times out — and a batch that times out is asked again on the board's
  /// next refresh. It fails whole, as the [HookTimeoutException] ErrorPolicy
  /// tracks timeouts by.
  Future<List<Map<String, dynamic>?>> lookupCalls(
    List<({String call, Map<String, dynamic> qso})> requests, {
    required Map<String, dynamic> operation,
    bool online = true,
    required String streakKey,
  }) async {
    if (ExtensionService.stubLookups) return [for (final r in requests) r.call.length < 3 ? null : stubbedLookupResult(r.call)];
    final host = this.host;
    final asked = [
      for (final (i, request) in requests.indexed)
        if (request.call.length >= 3) i,
    ];
    final answers = List<Map<String, dynamic>?>.filled(requests.length, null);
    if (host == null || asked.isEmpty) return answers;
    final reachable = online && !ConnectivityService.isOffline;

    try {
      final entries = await host.invokeHookBatch([
        for (final i in asked)
          Hooks.lookupServiceLookupCallInfo.withArgs({
            'callInfo': {'call': requests[i].call},
            'qso': requests[i].qso,
            'operation': operation,
            'online': reachable,
            'recentContext': false,
          }, key: 'core'),
      ], timeout: const Duration(seconds: 8));
      final failed = [
        for (final entry in entries)
          if (entry['ok'] != true) entry,
      ];
      for (final (n, entry) in entries.indexed) {
        if (entry['ok'] == true) answers[asked[n]] = _normalizedLookup(entry['value']);
      }
      if (failed.length < entries.length) ErrorReportingService.recordSuccess(streakKey);
      if (failed.isNotEmpty) {
        final summary = '${failed.length} of ${entries.length} batched lookups failed: ${failed.first['error']}';
        debugPrint('[extensions] $summary');
        if (failed.length == entries.length) ErrorReportingService.reportIfRepeated(streakKey, ExtensionHostException(summary), null);
      }
    } on ExtensionHostException catch (e, st) {
      debugPrint('[extensions] batched lookup failed: $e');
      ErrorReportingService.reportIfRepeated(streakKey, e, st);
    }
    return answers;
  }

  /// A lookup hook's raw answer as callers read it, with each malformed field
  /// dropped and reported. Null for an answer that is not a map.
  Map<String, dynamic>? _normalizedLookup(Object? result) {
    if (result is! Map) return null;
    final violations = <QsonTypeViolation>[];
    final answer = normalizeLookupResult(result.cast<String, dynamic>(), violations: violations);
    for (final violation in violations) {
      ErrorReportingService.reportIfRepeated(
        'lookupCall:malformed:${violation.path}',
        MalformedLookupDataException(violation),
        null,
        context: 'lookupCall:malformed',
        threshold: 1,
      );
    }
    return answer;
  }

  /// `{hookKey: scope}` for every `scoring` hook. `scope` is a plain data
  /// member on each hook (same access pattern as `spots`' `sourceName`), either
  /// the string `'always'` or `{refTypes: [...]}`, so the core can decide which
  /// scorers an operation needs *before* invoking any of them — a user may have
  /// dozens of extensions enabled while an operation references a handful
  /// (docs/design/contests.md §5.1).
  Future<Map<String, dynamic>> getScoringScopes() async {
    final host = this.host;
    if (host == null) return const {};
    try {
      final entries = await host.invokeAll(Hooks.scoringScope, timeout: const Duration(seconds: 5));
      return {
        for (final entry in entries)
          if (entry['ok'] == true && entry['value'] != null) entry['key'] as String: entry['value'],
      };
    } catch (e) {
      debugPrint('[extensions] getScoringScopes failed: $e');
      return const {};
    }
  }

  /// Asks every registered `command` hook (priority order) to interpret the input command.
  /// Returns the first non-null interpretation result: `{describe, confirm, commands}`.
  /// Returns null when nothing matched, the input is empty, or the runtime isn't up.
  /// [execute] should be true only for the final call made right before
  /// actually running a complete interpretation — see CommandHook.interpret's
  /// `execute` doc (extensions/sdk/src/types.ts). Every other call (the
  /// typing-debounce describe preview) should leave it false.
  Future<Map<String, dynamic>?> interpretCommand(String input, [Map<String, dynamic>? operation, Map<String, dynamic>? qso, bool execute = false]) async {
    final host = this.host;
    if (host == null || input.isEmpty) return null;
    try {
      final entries = await host.invokeAll(
        Hooks.commandInterpret,
        args: {'input': input, 'operation': ?operation, 'qso': ?qso, if (execute) 'execute': true},
        // The describe preview must stay snappy (it reruns on every
        // keystroke pause), but the one execute call is where hooks do
        // real work — SEED's log read + lookups, SOLAR/WEATHER's network
        // fetch — so it gets room to breathe instead of dying at 2s.
        timeout: execute ? const Duration(seconds: 30) : const Duration(seconds: 2),
      );
      for (final entry in entries) {
        if (entry['ok'] == true && entry['value'] is Map) {
          return _attributedCommand((entry['value'] as Map).cast<String, dynamic>(), entry['extensionKey'] as String?);
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
    // Developer mode decides which entries exist (the DEV commands, GO DEV),
    // and nothing that flips it drops this cache — so a list kept from the
    // other mode is stale, and so is the hook context it was built from.
    final developerMode = settings?.developerMode ?? false;
    if (_commandCatalog != null && _commandCatalogDeveloperMode != developerMode) invalidateHookContext();
    final cached = _commandCatalog;
    if (cached != null) return cached;

    final host = this.host;
    if (host == null) return const [];
    try {
      // A runtime is published before its extensions finish activating — at
      // boot, and again whenever it is replaced, which the preloaded-extension
      // catch-up does seconds after launch. A hook not registered yet is
      // simply not asked, so a read then comes back partial or empty, and
      // caching it leaves the palette without those commands for the session.
      // Not waited on again once boot has given up on it: every open would
      // otherwise stall for the full wait.
      var whole = true;
      if (activationIncomplete) {
        whole = false;
      } else {
        await host.activated.timeout(
          const Duration(seconds: 5),
          onTimeout: () {
            debugPrint('[extensions] getCommandCatalog: activation did not settle within 5s — serving what answers, uncached');
            whole = false;
          },
        );
      }
      final entries = await host.invokeAll(Hooks.commandCatalog, timeout: const Duration(seconds: 2));
      final catalog = <Map<String, dynamic>>[];
      for (final entry in entries) {
        // Only hooks that implement `catalog` are asked at all, so a not-ok
        // entry is one that threw — its commands are missing from this list.
        if (entry['ok'] != true) {
          debugPrint('[extensions] command catalog ${entry['key']} failed: ${entry['error']}');
          whole = false;
          continue;
        }
        if (entry['value'] is! List) continue;
        for (final item in entry['value'] as List) {
          if (item is! Map) continue;
          final map = {...item.cast<String, dynamic>()};
          // A malformed entry would render as a blank, unselectable row.
          if (map['command'] is! String || (map['command'] as String).isEmpty) continue;
          // The palette shows this text beside the app's own: a third-party
          // command's says whose it is.
          if (map['describe'] case final String describe when describe.isNotEmpty) {
            map['describe'] = _describedByOwner(describe, entry['extensionKey'] as String?);
          }
          // The palette matches every keystroke against these: one extension
          // sending a bare string here would break search for all of them.
          if (map['keywords'] case final List<dynamic> keywords) {
            map['keywords'] = keywords.whereType<String>().toList();
          } else {
            map.remove('keywords');
          }
          catalog.add(map);
        }
      }
      final answer = List<Map<String, dynamic>>.unmodifiable(catalog);
      // Served but not kept when it may not be the current runtime's whole
      // list — activation unsettled, a hook that threw, or the runtime
      // replaced during the read — so the next open asks again.
      if (whole && identical(host, this.host)) {
        _commandCatalog = answer;
        _commandCatalogDeveloperMode = developerMode;
      }
      return answer;
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

  /// The developer mode [_commandCatalog] was read under.
  bool? _commandCatalogDeveloperMode;

  /// Descriptors for controls activities want on the logging panel. `qso` is
  /// the in-progress QSO (including any `their.guess` from the callsign
  /// lookup pipeline) — pass it so an extension can key a QSO-scoped
  /// `placeholder`/`transforms` (e.g. a DXCC-derived reference prefix) off
  /// it; omit for a QSO-agnostic refresh (e.g. right after the operation loads).
  Future<ControlsResult> loggingControls(Map<String, dynamic> operationData, {Map<String, dynamic>? qso}) =>
      _collectControls(Hooks.activityLoggingControls, operationData, qso: qso);

  /// Descriptors for controls activities want in operation settings.
  Future<ControlsResult> operationControls(Map<String, dynamic> operationData, {Map<String, dynamic>? qso}) =>
      _collectControls(Hooks.activityOperationControls, operationData, qso: qso);

  /// The activity reference TYPES each running extension publishes, keyed by
  /// the activity's word and by the extension's key: `pota` and `ham2k-pota`
  /// -> `(activationType: 'potaActivation', huntingType: 'pota')`. A deep
  /// link, and anything else naming an activity, needs this to turn
  /// `pota:US-1234` into a real ref.
  ///
  /// Read off the `refList` control descriptors an activity ALREADY publishes
  /// rather than from a hook of its own: those descriptors are where an
  /// activity names its types, and a second declaration would be a second
  /// thing to keep in step. An operation control is an activation, a logging
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
  Future<({Map<String, ({String? activationType, String? huntingType})> byKey, bool loadFailed})> activityRefTypes({
    Map<String, dynamic> operationData = const {},
  }) async {
    await start();
    final results = await Future.wait([operationControls(operationData), loggingControls(operationData)]);
    final activation = _refTypesByActivityKey(results[0].controls);
    final hunting = _refTypesByActivityKey(results[1].controls);
    return (
      byKey: {
        for (final key in {...activation.keys, ...hunting.keys}) key: (activationType: activation[key], huntingType: hunting[key]),
      },
      loadFailed: results[0].loadFailed || results[1].loadFailed,
    );
  }

  /// The `refList` ref type each control descriptor carries, keyed by the
  /// extension that supplied it (`ham2k-pota`) and by the type's
  /// [activityScopeWord] (`pota`) — the word a deep link names an activity
  /// by, which is app-polo's activity key and not any extension's. Controls
  /// that are not reference lists carry no type and are skipped.
  ///
  /// The first descriptor for a key wins. Every activity publishes exactly one
  /// `refList` per surface, so an extension's own key never ties — if that
  /// ever stops being true, the tie needs a real rule rather than fan-out
  /// order. A word does tie when two extensions serve one type, and the first
  /// of them answers a deep link naming it.
  static Map<String, String> _refTypesByActivityKey(List<Map<String, dynamic>> controls) {
    final types = <String, String>{};
    for (final control in controls) {
      final input = control['input'];
      if (input is! Map) continue;
      final refType = input['refType'];
      if (refType is! String || refType.isEmpty) continue;
      for (final key in [controlExtensionKey(control), activityScopeWord(refType)]) {
        if (key.isNotEmpty) types.putIfAbsent(key, () => refType);
      }
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
  Future<Map<String, dynamic>> decorateQsoBeforeSave(Map<String, dynamic> qsoData, Map<String, dynamic> operationData) async {
    final host = this.host;
    if (host == null) return qsoData;
    final refs = operationData['refs'];
    if (refs is! List || refs.isEmpty) return qsoData;

    try {
      final entries = await host.invokeAll(
        Hooks.activityProcessQsoBeforeSave,
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
        merged = mergeQsoPatch(merged, (entry['value'] as Map).cast<String, dynamic>(), owner: owner is String ? owner : '');
      }
      return merged;
    } on ExtensionHostException catch (e) {
      debugPrint('[extensions] processQsoBeforeSave failed: $e');
      return qsoData;
    }
  }

  Future<ControlsResult> _collectControls(HookRef hook, Map<String, dynamic> operationData, {Map<String, dynamic>? qso}) async {
    final host = this.host;
    // No host is a failure, not an empty answer: the runtime is dead or
    // still starting (see ErrorPolicy's `extension-runtime-dead`), and the
    // operator's refs are no less real for it.
    if (host == null) return (controls: const <Map<String, dynamic>>[], loadFailed: true);
    try {
      final entries = await host.invokeAll(
        hook,
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
          debugPrint('[extensions] ${hook.method}: hook ${entry['key']} failed: ${entry['error']}');
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
            debugPrint('[extensions] ${hook.method}: hook ${entry['key']} answered ${value.runtimeType}, wanted a List');
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
            debugPrint('[extensions] ${hook.method}: hook ${entry['key']} returned a ${control.runtimeType} control');
            continue;
          }
          controls.add({...control.cast<String, dynamic>(), controlExtensionKeyField: entry['key']});
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
      debugPrint('[extensions] ${hook.method} failed: $e');
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
  /// a user-published extension serves the same type as a stock one) or to
  /// one extension by its key (`ham2k-pota:`) — those hooks alone are asked,
  /// rather than every hook's results being merged and then filtered, so an
  /// unrelated extension's slow search can't hold up a scoped one.
  /// [preferredKeys] is the softer form (a `pota` word, no colon): everyone
  /// is still asked, but those hooks' results lead the list and they search
  /// for [preferredSearchTerm] — or, with none, are asked as a scope for
  /// their own list — while the others get [searchTerm].
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
    ({double south, double west, double north, double east})? searchWithin,
  }) async {
    final host = this.host;
    if (host == null) return (suggestions: const <Map<String, dynamic>>[], allSourcesFailed: false, someSourcesFailed: false);

    // The operation's own coordinate first, then the centre of its grid: a
    // park two kilometres away and one eight kilometres away rank the same
    // from a square's centre, and this ordering is what the operator reads as
    // "nearby".
    final gridLocation = locationFromLatLon(operationData['lat'], operationData['lon']) ?? gridToLocation(operationData['grid'] as String?) ?? fallbackLocation;
    final callsign = (operationData['stationCall'] as String?)?.isNotEmpty == true
        ? operationData['stationCall'] as String
        : settings?.activeProfile.operatorCall;

    // `scoped` tells a hook its type alone is being asked for — the operator
    // picked its "Activity Types" row, or typed its word as a scope. A bare
    // scope and the nearby list both arrive with no search term, and an
    // extension that keeps itself out of the nearby list still has to answer
    // when it is the one being asked.
    // A view's centre stands in for the operation's place: extensions measure
    // and rank from `location`, and one that predates `bounds` answers with
    // what is nearest the middle of the view rather than of somewhere else.
    final searchCenter = switch (searchWithin) {
      (:final south, :final west, :final north, :final east) => GridLocation(
        (south + north) / 2,
        west <= east ? (west + east) / 2 : ((west + east + 360) / 2 + 180) % 360 - 180,
      ),
      null => null,
    };

    Map<String, dynamic> argsSearchingFor(String? term, {bool scoped = false}) => {
      'operation': operationData,
      if (searchCenter ?? gridLocation case final at?) 'location': {'lat': at.latitude, 'lon': at.longitude},
      if (searchWithin case (:final south, :final west, :final north, :final east)) 'bounds': {'south': south, 'west': west, 'north': north, 'east': east},
      if (callsign != null && callsign.isNotEmpty) 'callsign': callsign,
      if (term != null && term.isNotEmpty) 'searchTerm': term,
      if (scoped) 'scoped': true,
    };

    // A search run [searchWithin] a map's view still reports each result's
    // distance from the operation's own place: that is the distance its card
    // shows, and "12 km" from wherever the map happened to be is no answer.
    List<Map<String, dynamic>> measured(List<Map<String, dynamic>> suggestions) {
      if (searchWithin == null) return suggestions;
      return [
        for (final suggestion in suggestions)
          {
            for (final entry in suggestion.entries)
              if (entry.key != 'distance') entry.key: entry.value,
            if ((
                  gridLocation,
                  locationFromLatLon(suggestion['lat'], suggestion['lon']) ??
                      gridToLocation(suggestion['grid'] is String ? suggestion['grid'] as String : null),
                )
                case (final from?, final to?))
              'distance': distanceOnEarthKm(from, to),
          },
      ];
    }

    try {
      if (activityKeys != null) {
        final entries = await _activityBatch(host, activityKeys, argsSearchingFor(searchTerm, scoped: true), 'scoped');
        final suggestions = measured(mergeActivitySuggestions(entries));
        _noticeActivitySourcesFailed(_failedActivityKeys(entries), found: suggestions.isNotEmpty);
        return (suggestions: suggestions, allSourcesFailed: allActivitySourcesFailed(entries), someSourcesFailed: entries.any((entry) => entry['ok'] != true));
      }

      // The preferred hooks are asked SEPARATELY because they may search for
      // something else — for nothing at all, as a scope, when the word stood
      // alone — so their answers to the everyone-else question are discarded
      // below rather than merged.
      // A fan-out that never returned an entry is a failure with nothing to
      // count, so it contributes one — the caller has to be able to tell
      // "nobody could answer" from "nobody had anything".
      var fanOutFailed = false;
      // A word standing alone asked the preferred hooks for their own list,
      // as a scope does, so every one of them failing fails the search the
      // way a failed scope would — what the others found for the word as
      // text is not the list that was asked for.
      final ownList = preferredSearchTerm == null && (preferredKeys?.isNotEmpty ?? false);
      var ownListFailed = false;
      var preferredFailedKeys = const <String>[];
      final preferred = _activityBatch(host, preferredKeys ?? const [], argsSearchingFor(preferredSearchTerm, scoped: ownList), 'preferred')
          // Precedence is otherwise only an ordering: when a preferred hook
          // fails, what the other extensions found is still the right answer.
          .then((entries) {
            ownListFailed = ownList && allActivitySourcesFailed(entries);
            preferredFailedKeys = _failedActivityKeys(entries);
            return [
              for (final entry in entries)
                if (entry['ok'] == true) entry,
            ];
          })
          .onError<ExtensionHostException>((e, _) {
            debugPrint('[extensions] preferred activity hooks failed: $e');
            ownListFailed = ownList;
            preferredFailedKeys = [...?preferredKeys];
            return const <Map<String, dynamic>>[];
          });

      // The fan-out is ONE message under ONE timeout. Partials are kept, so
      // one slow hook costs only its own answer: without them, a POTA stuck
      // behind a busy database throws away what every other extension found.
      // The preferred hooks, asked separately, degrade on their own as well.
      final everyone = host
          .invokeAll(Hooks.activitySuggest, args: argsSearchingFor(searchTerm), timeout: const Duration(seconds: 5), partialOnTimeout: true)
          .then((entries) {
            for (final entry in entries) {
              if (entry['ok'] != true) debugPrint('[extensions] activity hook ${entry['key']} failed: ${entry['error']}');
            }
            return entries;
          })
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
      final suggestions = measured(mergeActivitySuggestions(entries, preferredKeys: preferredSet));
      final failedKeys = [...preferredFailedKeys, ..._failedActivityKeys(entries), if (fanOutFailed) _everyOtherActivity];
      _noticeActivitySourcesFailed(failedKeys, found: suggestions.isNotEmpty);
      return (
        suggestions: suggestions,
        allSourcesFailed: ownListFailed || (fanOutFailed && entries.isEmpty) || allActivitySourcesFailed(entries),
        someSourcesFailed: failedKeys.isNotEmpty,
      );
    } on ExtensionHostException catch (e) {
      debugPrint('[extensions] suggestActivities failed: $e');
      return (suggestions: const <Map<String, dynamic>>[], allSourcesFailed: true, someSourcesFailed: true);
    }
  }

  static List<String> _failedActivityKeys(List<Map<String, dynamic>> entries) => [
    for (final entry in entries)
      if (entry['ok'] != true)
        if (entry['key'] case final String key) key,
  ];

  /// Stands in for the extensions a fan-out that failed as a whole never
  /// named — it has no roster to name them from.
  static const _everyOtherActivity = '*';

  /// When each activity extension's failure was last shown in the status bar.
  final Map<String, int> _activityFailureShownAt = {};

  static const activityFailureNoticeEvery = Duration(minutes: 10);

  /// Names, in the status bar, the activity extensions that did not answer a
  /// search that still found something: the sheet shows the results it has,
  /// and nothing else says the list may be short. A search that found
  /// nothing says so in the sheet itself. Each extension at most once every
  /// [activityFailureNoticeEvery] — the search runs on every pause in typing
  /// and every pan of the map, and one that stays down would post on each.
  void _noticeActivitySourcesFailed(List<String> keys, {required bool found}) {
    if (!found || keys.isEmpty) return;
    final now = realNowMillis();
    bool shownLately(String key) => switch (_activityFailureShownAt[key]) {
      final shown? => now - shown < activityFailureNoticeEvery.inMilliseconds,
      null => false,
    };
    final due = [
      for (final key in keys.toSet())
        if (!shownLately(key)) key,
    ];
    if (due.isEmpty) return;
    for (final key in due) {
      _activityFailureShownAt[key] = now;
    }
    final names = [for (final key in due) availableExtensions.where((info) => info.key == key).firstOrNull?.effectiveShortName ?? key];
    statusBar?.setMessage(
      key: 'activity-search:failed',
      icon: 'alert-circle',
      text: due.contains(_everyOtherActivity)
          ? t.extensionService.activitySearchSomeSourcesFailed
          : t.extensionService.activitySearchSourcesFailed(names: names.join(', ')),
      dismissAfter: const Duration(seconds: 10),
    );
  }

  /// `suggest` on each of [keys]' activity hooks, in one batch: one entry per
  /// key, in [ExtensionHost.invokeHookAll]'s `{key, ok, value}` shape so the merge needs no
  /// second code path — one failing hook is one failed entry, never the whole
  /// answer. [label] names the search in the console.
  Future<List<Map<String, dynamic>>> _activityBatch(ExtensionHost host, List<String> keys, Map<String, dynamic> args, String label) async {
    final answers = await host.invokeHookBatch(
      [for (final key in keys) Hooks.activitySuggest.withArgs(args, key: key)],
      timeout: const Duration(seconds: 5),
      partialOnTimeout: true,
    );
    final entries = [
      for (final (i, key) in keys.indexed) <String, dynamic>{...answers[i], 'key': key},
    ];
    for (final entry in entries) {
      if (entry['ok'] != true) debugPrint('[extensions] $label activity hook ${entry['key']} failed: ${entry['error']}');
    }
    return entries;
  }

  /// Decorates a ref (park name, location…) via its `ref:<type>` handler.
  /// Returns the input unchanged if no handler answers.
  Future<Map<String, dynamic>> decorateRef(Map<String, dynamic> ref) async => (await decorateRefs([ref])).single;

  /// [decorateRef] for every ref in [refs], in ONE crossing: one answer per
  /// ref, in order, each the ref as it came in when its handler did not answer.
  Future<List<Map<String, dynamic>>> decorateRefs(List<Map<String, dynamic>> refs) async {
    final answers = await refHookAnswers(refs, RefMethod.decorateRef);
    return [
      for (final (i, answer) in answers.indexed)
        if (answer.ok && answer.value is Map) (answer.value! as Map).cast<String, dynamic>() else refs[i],
    ];
  }

  /// Where each ref in [refs] can be read about on the web, via its
  /// `ref:<type>` handler — the program's own page for it, or a contest's
  /// rules — in ONE crossing, in order.
  ///
  /// Resolved for display and thrown away: nothing here is ever written back
  /// onto the operation's ref, so a program that changes its URLs takes effect
  /// with the extension rather than needing every saved operation rewritten.
  Future<List<RefLink?>> linkForRefs(List<Map<String, dynamic>> refs) async {
    final answers = await refHookAnswers(refs, RefMethod.linkForRef);
    return [for (final (i, answer) in answers.indexed) answer.ok ? refLinkFromHookResult(answer.value, type: '${refs[i]['type']}') : null];
  }

  /// Where each ref's own outline can be fetched as GeoJSON, via its
  /// `ref:<type>` handler — a summit's SOTA activation zone, a park's boundary
  /// — in ONE crossing, in order. Each says whether its program answered at
  /// all, because "no outline" is a fact worth remembering and "could not ask"
  /// is one worth asking again; a type no program registers has no outline.
  ///
  /// The hook only builds a URL; fetching and caching are the app's
  /// (GeoshapeService). Same disposable resolution as [linkForRefs]: nothing
  /// is written back onto the ref, so a program that moves its files takes
  /// effect with the extension.
  Future<List<RefGeojsonAnswer>> geojsonUrlsForRefs(List<Map<String, dynamic>> refs) async {
    final answers = await refHookAnswers(refs, RefMethod.geojsonUrlForRef);
    return [
      for (final (i, answer) in answers.indexed)
        (
          source: answer.ok ? refGeojsonFromHookResult(answer.value, type: '${refs[i]['type']}') : null,
          answered: answer.ok || !answer.asked || answer.noHandler,
        ),
    ];
  }

  /// [method] on every ref's `ref:<type>` handler in one [ExtensionHost.invokeHookBatch],
  /// with [extraArgs] beside each call's `ref`: one [RefHookAnswer] per ref,
  /// in order.
  ///
  /// One budget for the whole batch, and partial: a handler that has not
  /// answered when it runs out — or that threw, or that nothing registers, or
  /// that has no runtime to answer in — costs its own ref the answer and no
  /// other. A budget per ref would make a caller looping over N refs wait up to
  /// N budgets, one after another.
  Future<List<RefHookAnswer>> refHookAnswers(List<Map<String, dynamic>> refs, RefMethod method, {Map<String, dynamic> extraArgs = const {}}) async {
    // Checked per ref, not cast: a malformed ref costs its own answer, never
    // the rest of the list's.
    final asked = <int>[];
    for (final (i, ref) in refs.indexed) {
      if (ref['type'] is String) {
        asked.add(i);
      } else if (ref['type'] != null) {
        debugPrint('[extensions] ${method.name}: ref ${ref['ref']} has a ${ref['type'].runtimeType} type, not a String — not asked');
      }
    }
    final answers = <RefHookAnswer>[for (final ref in refs) (asked: ref['type'] is String, ok: false, noHandler: false, value: null)];
    final host = this.host;
    if (host == null || asked.isEmpty) return answers;
    try {
      final entries = await host.invokeHookBatch([
        for (final i in asked) Hooks.ref(refs[i]['type'] as String, method).withArgs({...extraArgs, 'ref': refs[i]}),
      ], partialOnTimeout: true);
      for (final (j, i) in asked.indexed) {
        final entry = entries[j];
        if (entry['ok'] == true) {
          answers[i] = (asked: true, ok: true, noHandler: false, value: entry['value']);
        } else if (entry['noHandler'] == true) {
          answers[i] = (asked: true, ok: false, noHandler: true, value: null);
        } else {
          debugPrint('[extensions] ${method.name}(ref:${refs[i]['type']}) failed: ${entry['error']}');
        }
      }
    } on ExtensionHostException catch (e) {
      debugPrint('[extensions] ${method.name} failed: $e');
    }
    return answers;
  }
}
