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
import 'dart:io' show FileSystemException, SocketException;

import 'package:flutter/foundation.dart' show kIsWeb, visibleForTesting;
import 'package:flutter/services.dart' show PlatformException;
import 'package:flutter/widgets.dart';
import 'package:halo_extension_host/halo_extension_host.dart' show ExtensionHostException;

import 'cat/transport.dart' show CatConnectFailure, CatUnreachable;
import 'windows_webview.dart' show WindowsWebViewUnavailable;
import 'map_error_reporter.dart' show MapError;

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

  const ErrorRule({
    required this.id,
    required this.reason,
    required this.disposition,
    required this.matches,
    this.logOncePerSession = false,
  });
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
      id: 'web-focus-traversal-null',
      reason: 'Flutter web focus-traversal null on view-focus change (ham2k/halo-dist#271); '
          'later ones are silent',
      disposition: ErrorDisposition.ignore,
      logOncePerSession: true,
      matches: _isWebFocusTraversalNull,
    ),
    ErrorRule(
      id: 'renderflex-overflow',
      reason: 'RenderFlex overflow: a debug-only layout warning, already marked on-screen',
      disposition: ErrorDisposition.logOnly,
      matches: _isRenderFlexOverflow,
    ),
    ErrorRule(
      id: 'set-state-during-build',
      reason: 'setState()/markNeedsBuild() during build: a build-ordering bug to fix locally, '
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
      id: 'extension-host-disposed',
      reason: 'an in-flight hook call was cut off by a runtime replacement (extension toggle, '
          'restartOnChange, crash backoff, shutdown); callers redo the work against the new '
          'runtime or drop it by design',
      disposition: ErrorDisposition.logOnly,
      matches: _isExtensionHostDisposed,
    ),
    ErrorRule(
      id: 'extension-runtime-dead',
      reason: 'a hook call against a crashed runtime, refused without waiting out its timeout; '
          'the crash itself is reported separately (extensions:restart)',
      disposition: ErrorDisposition.logOnly,
      matches: _isExtensionRuntimeDead,
    ),
    ErrorRule(
      id: 'connectivity-backend-unavailable',
      reason: "connectivity_plus's Linux backend needs NetworkManager over D-Bus; without it the "
          'plugin throws out of its own stream setup, unreachable by any onError of ours. The app '
          'degrades to no reconnect-resync',
      disposition: ErrorDisposition.logOnly,
      matches: _isConnectivityBackendUnavailable,
    ),
    ErrorRule(
      id: 'windows-webview-unavailable',
      reason: "Windows refused this app a webview (WebView2 missing, or its user data folder "
          'unwritable where the app was installed); the Map tab falls back to OpenStreetMap and the '
          'account login says it cannot sign in here, so there is nothing left for the operator to do',
      disposition: ErrorDisposition.report,
      matches: _isWindowsWebViewUnavailable,
    ),
    ErrorRule(
      id: 'cat-equipment-unreachable',
      reason: "a radio didn't answer a connect attempt (switched off, unplugged, already held by "
          'another program, or refusing the login); the equipment row says so and the retry loop '
          'keeps trying',
      disposition: ErrorDisposition.logOnly,
      matches: _isCatEquipmentUnreachable,
    ),
    ErrorRule(
      id: 'fetch-transport-transient',
      reason: "a host.fetch call failed at the transport layer (connection reset, refused or "
          'closed mid-body, or a fetch timeout) rather than anything our code did; worth seeing '
          'in aggregate, not worth an operator notice for a TCP blip the caller already retries',
      disposition: ErrorDisposition.report,
      matches: _isFetchTransportTransient,
    ),
    ErrorRule(
      id: 'map-offline',
      reason: 'a map error raised while the device was offline; a field operation without '
          'coverage fails every tile and style fetch, and that is the normal state of an '
          'off-grid activation, not a defect',
      disposition: ErrorDisposition.logOnly,
      matches: _isMapErrorWhileOffline,
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
  static bool _isRenderFlexOverflow(Object error, FlutterErrorDetails? details) =>
      error is FlutterError && error.toString().contains('A RenderFlex overflowed by');

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
  /// Matched on the exact message, and only on the host's own exception
  /// type: a wrapper of ours quoting the text stays loud.
  static bool _isExtensionHostDisposed(Object error, FlutterErrorDetails? details) =>
      error is ExtensionHostException && error.message == 'extension host disposed';

  /// `ExtensionHost._send` refusing a call because the runtime already
  /// crashed ('extension runtime is dead (hook X not attempted)') — the
  /// fail-fast that spares the caller its full timeout. The crash that
  /// killed the runtime is reported once, with its real diagnostic, by
  /// ExtensionService's restart scheduling; every one of these is a
  /// duplicate of that already-known state, one per call attempted before
  /// the backoff restart lands.
  static bool _isExtensionRuntimeDead(Object error, FlutterErrorDetails? details) =>
      error is ExtensionHostException && error.message.startsWith('extension runtime is dead');

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

  static bool _isCatEquipmentUnreachable(Object error, FlutterErrorDetails? details) {
    if (error is! CatConnectFailure) return false;
    final cause = error.cause;
    return cause is SocketException || cause is TimeoutException || cause is CatUnreachable;
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
  /// can't act on a TCP reset, and it isn't a bug of ours.
  ///
  /// Matched by prefix on the wrapped exception's own class name, not by
  /// scanning for a substring anywhere in the message — a hook that
  /// legitimately throws its own "timed out" message (the sibling test in
  /// `_isExtensionRuntimeDead`'s group) must stay loud.
  static bool _isFetchTransportTransient(Object error, FlutterErrorDetails? details) {
    if (error is! ExtensionHostException) return false;
    return error.message.startsWith('ClientException:') || error.message.startsWith('TimeoutException');
  }

  /// A [MapError] stamped offline at arrival. The stamp is the whole match:
  /// with no network there is nothing a map backend can fetch, so every
  /// style, tile and token check fails as a matter of course — on a summit
  /// or in a park that is the session's normal state, and uploading it
  /// would bury the online failures this type exists to surface. The same
  /// error raised ONLINE (a bad token, a style that won't parse, a layer
  /// bug of ours) matches nothing and uploads.
  static bool _isMapErrorWhileOffline(Object error, FlutterErrorDetails? details) =>
      error is MapError && error.offline;

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
    debugPrint('[error-policy] ${rule.id} (${rule.disposition.name}, ${rule.reason}): $error'
        '${stackTrace == null ? '' : '\n$stackTrace'}');
    return true;
  }

  /// Test seam: forget the once-per-session log state and the web override.
  /// Not marked `@visibleForTesting` because ErrorReportingService's own
  /// reset calls it — that state belongs to a session, and tests reset a
  /// session through one door.
  static void resetForTesting() {
    _oncePerSessionLogged.clear();
    debugTreatAsWeb = null;
  }
}
