// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Global error capture: backend upload when one is injected, local
// logging and a StatusBar notice always — as far as [ErrorPolicy] allows.
// WHAT an error deserves is decided there and only there (see
// services/error_policy.dart); this file is the plumbing that carries the
// decision out to the console, the backend and the StatusBar.
//
// Vendor-specific reporting code (Sentry, DSN handling, …) lives entirely in
// app_dist, behind the [ErrorReportingBackend] interface — this file only
// knows the generic shape. The OSS app runs with no backend at all (see
// [NoopErrorReportingBackend]); a real one is injected via [run]'s `backend`
// parameter, mirroring MetricsService/runHaLoApp.
//
// Static rather than a HaLoServices member on purpose: the hooks must be
// installed around runApp(), long before bootstrap() has built any
// services. The StatusBar surface attaches later via [attachStatusBar]
// (errors before that point are logged/uploaded but produce no notice).
//
// User context (callsign, LoFi account id, log file path) flows through [attachSettings]
// the same way: SettingsService already notifyListeners on a callsign
// change, an account link/switch, and the consent toggle itself, so one
// listener here re-evaluates on every trigger without duplicating this
// logic at each call site. Only the identifying fields are gated behind
// SettingsService.consentAppData ("Share Usage Data") — reporting itself
// (this file, and a real backend's crash uploads) is NOT consent-gated,
// unlike app-polo's own Sentry integration, which disables Sentry entirely
// without consent. Cleared (every field null) the moment consent is off, so
// a prior opt-in's value can't linger in the backend's own scope.

import 'dart:async';

import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:flutter/widgets.dart';

import 'package:halo_core/halo_core.dart';
import 'package:halo_extension_host/halo_extension_host.dart' show ExtensionHostException;
import 'package:halo_i18n/halo_i18n.dart';

import '../config/version.dart' show Edition, kEdition;
import 'error_policy.dart';
import 'error_reporting_backend.dart';
import '../views/error_tile.dart';
import 'settings_service.dart';
import 'status_bar_service.dart';

class ErrorReportingService {
  ErrorReportingService._();

  static ErrorReportingBackend _backend = const NoopErrorReportingBackend();

  /// Whether a real backend is active (vs. the OSS no-op default). Local
  /// logging and notices happen either way.
  static bool get reportingEnabled => _backend is! NoopErrorReportingBackend;

  static StatusBarService? _statusBar;
  static bool _noticeShown = false;

  /// Wraps ALL of app startup — main() puts its entire body inside [body],
  /// including WidgetsFlutterBinding.ensureInitialized() and runApp(), so
  /// that binding, bootstrap and app all live in the same zone (a split
  /// would trip Flutter's zone-mismatch warning, and root-zone errors would
  /// escape capture on web, where async errors reach the zone handler
  /// rather than PlatformDispatcher.onError).
  ///
  /// [backend] takes ownership of [startBody] if it can (e.g. Sentry's own
  /// guarded zone); if it can't (no backend, or its own init failed before
  /// ever starting the body), [startBody] runs in our own runZonedGuarded
  /// instead, so uncaught async errors are logged and noticed (but don't
  /// take the session down) on every platform, including web.
  static Future<void> run(FutureOr<void> Function() body, {ErrorReportingBackend? backend}) async {
    _backend = backend ?? const NoopErrorReportingBackend();
    var bodyStarted = false;
    FutureOr<void> startBody() {
      bodyStarted = true;
      _installLocalHooks();
      return body();
    }

    final tookOwnership = await _backend.run(startBody);
    if (tookOwnership || bodyStarted) return;

    runZonedGuarded(
      () {
        startBody();
      },
      (error, stackTrace) {
        // Uncaught async error with no backend (or its init broken): log +
        // notice. Reaching a zone handler means it never propagates, so a
        // stray async error can't take down a logging session mid-contact.
        if (error is WriteRefused) noticeWriteRefused(error);
        final decision = ErrorPolicy.decide(error);
        if (!decision.disposition.uploads) {
          ErrorPolicy.logDecision(decision, error, stackTrace: stackTrace);
          return;
        }
        debugPrint('[error-reporting] uncaught async error: $error\n$stackTrace');
        if (decision.disposition.notifies) notify(error, stackTrace);
      },
    );
  }

  /// Report a caught error explicitly (e.g. bootstrap() failures that are
  /// already surfaced by BootErrorScreen). Always logs locally; uploads via
  /// the active backend unless [ErrorPolicy] classifies it as noise, so a
  /// known-harmless error stays out of the backend however it was caught.
  ///
  /// [notice] is the caller's own words for a failure of something the
  /// operator asked for, shown whatever the policy decides; [told] says the
  /// caller already told the operator its own way (a snackbar). Either one
  /// keeps the generic [notify] notice off this error: it would say strictly
  /// less, on top. Neither changes the upload, which is the policy's alone.
  ///
  /// A failure is uploaded once, however many catches report it on its way
  /// up: a catch that reports and rethrows, under one that reports what
  /// reaches it, would otherwise upload the same failure twice. "The same
  /// failure" is the same error object WITH the same trace object, which a
  /// rethrow carries along — the object alone is not enough, because a
  /// `const` exception is one object however many times it is thrown.
  static void report(Object error, StackTrace? stackTrace, {String? context, ErrorNotice? notice, bool told = false}) {
    if (notice != null || told) _mark(_told, error);
    _upload(error, stackTrace, context: context);
    // After the upload, so a notice that cannot be shown never costs it.
    if (notice != null) _showErrorNotice(notice, error, stackTrace);
  }

  static void _upload(Object error, StackTrace? stackTrace, {String? context}) {
    if (_markable(error) && stackTrace != null) {
      if (identical(_reported[error], stackTrace)) {
        debugPrint('[error-reporting] ${context ?? 'caught'}: already reported: $error');
        return;
      }
      _reported[error] = stackTrace;
    }
    debugPrint('[error-reporting] ${context ?? 'caught'}: $error\n${stackTrace ?? ''}');
    if (error is WriteRefused) noticeWriteRefused(error);
    final decision = ErrorPolicy.decide(error);
    if (!decision.disposition.uploads) {
      ErrorPolicy.logDecision(decision, error);
      return;
    }
    _backend.captureException(error, stackTrace, context: context);
  }

  /// Records a lightweight breadcrumb the active backend can attach to
  /// whatever it captures next — including a native crash (crashpad on
  /// desktop), which never runs through [report] or any Dart error hook at
  /// all. Always logs locally; unlike [report] there is no [ErrorPolicy] to
  /// consult, since nothing is being reported yet.
  ///
  /// Call sites include a `dispose()` right before `super.dispose()` tears
  /// down a native platform view — the exact teardown this exists to shed
  /// light on — so a *synchronous* backend failure here must never
  /// propagate: doing so would skip that teardown and produce the very
  /// corruption this is meant to help diagnose. An asynchronous one is not
  /// caught here (same as any other unawaited backend call) and can still
  /// reach [run]'s fallback zone.
  static void breadcrumb(String message, {String? category}) {
    debugPrint('[breadcrumb]${category != null ? ' $category:' : ''} $message');
    try {
      _backend.addBreadcrumb(message, category: category);
    } catch (error, stackTrace) {
      debugPrint('[breadcrumb] backend threw, ignoring: $error\n$stackTrace');
    }
  }

  /// Names the radio the app is driving on every later report — see
  /// [ErrorReportingBackend.updateEquipmentContext]. Swallows a synchronous
  /// backend failure for the same reason [breadcrumb] does: this rides along
  /// with a radio connecting, and a reporting backend that cannot take a tag
  /// must not take the connection down with it.
  static void updateEquipmentContext({String? radio}) {
    try {
      _backend.updateEquipmentContext(radio: radio);
    } catch (error, stackTrace) {
      debugPrint('[equipment-context] backend threw, ignoring: $error\n$stackTrace');
    }
  }

  /// Uploads a diagnostic report the operator asked for — see
  /// [ErrorReportingBackend.captureDiagnostic]. Swallows a SYNCHRONOUS backend
  /// failure for the same reason [breadcrumb] does: the operator is waiting on
  /// a result, and a reporting backend that cannot send must not take the
  /// result down with it.
  ///
  /// An asynchronous one is not caught here — the real backend's upload is
  /// unawaited — and can still reach [run]'s fallback zone, exactly as
  /// [breadcrumb]'s can. So a failed upload may surface as an ordinary error
  /// notice moments after the operator was told the run succeeded.
  /// Returns whether the backend took it. A caller that tells the operator
  /// their report left the device must not say so on the strength of
  /// [reportingEnabled] alone: that is a configuration flag, and a backend
  /// that threw leaves the only copy on screen behind a notice they are about
  /// to dismiss.
  static bool diagnostic({required String title, required String body, DiagnosticAttachment? attachment}) {
    debugPrint('[diagnostic] $title\n$body');
    try {
      _backend.captureDiagnostic(title: title, body: body, attachment: attachment);
      return true;
    } catch (error, stackTrace) {
      debugPrint('[diagnostic] backend threw, ignoring: $error\n$stackTrace');
      return false;
    }
  }

  /// Consecutive failures per [reportIfRepeated] key. Process-wide and
  /// never persisted: "stuck" is a claim about this session.
  static final Map<String, int> _failureStreaks = {};

  /// How many consecutive failures make a call worth reporting.
  static const repeatedFailureThreshold = 3;

  /// Reports [error] only once the same [key] has failed
  /// [repeatedFailureThreshold] times in a row, and only on the attempt that
  /// reaches that count.
  ///
  /// For a recoverable call the operator triggers by hand, a single failure
  /// is almost always the world being unreliable — a tunnel, a captive
  /// portal, a server restarting — and uploading it tells nobody anything
  /// they can act on. The same call failing every single time is a defect,
  /// and without this its only trace is a support message describing a
  /// button that did nothing.
  ///
  /// Firing exactly AT the threshold rather than at-or-above it is the
  /// point: a permanently broken call would otherwise just trade a flood of
  /// single failures for a flood of streak reports. [recordSuccess] is what
  /// makes the count mean "stuck right now" instead of "unlucky a few times
  /// over a long session" — pair the two on every call site, or the streak
  /// only ever grows.
  ///
  /// A failure [ErrorPolicy] keeps quiet neither advances the streak nor
  /// resets it: known noise is not evidence of being stuck, and it is not a
  /// success either. Counted, it would spend the one report at the threshold
  /// on an error nobody uploads and leave every later defect on the key
  /// silent until a success — which a call that fails quietly by nature
  /// (a screen pane dialling a firewalled peer, a catalog fetch with no
  /// internet) may not see for the rest of the session. The call site's own
  /// console line is the only trace a quiet failure leaves here — every
  /// site prints one, and a new site must too. So "in a row" in the report
  /// means loud failures since the last success: a rule that depends on
  /// state (offline, then not) can put a quiet stretch between them.
  static void reportIfRepeated(String key, Object error, StackTrace? stackTrace, {String? context, int threshold = repeatedFailureThreshold}) {
    if (!ErrorPolicy.decide(error).disposition.uploads) return;
    final streak = (_failureStreaks[key] ?? 0) + 1;
    _failureStreaks[key] = streak;
    if (streak != threshold) return;
    report(error, stackTrace, context: '${context ?? key} (failed $streak times in a row)');
  }

  /// Clears [key]'s streak — call on every success of a call that reports
  /// through [reportIfRepeated].
  static void recordSuccess(String key) {
    _failureStreaks.remove(key);
  }

  @visibleForTesting
  static void resetFailureStreaks() => _failureStreaks.clear();

  /// [key]'s current streak — what a test reads for the count a call site
  /// left behind.
  @visibleForTesting
  static int failureStreak(String key) => _failureStreaks[key] ?? 0;

  /// Called once bootstrap() has services; from then on the first runtime
  /// error of the session also posts a dismissible StatusBar notice.
  static void attachStatusBar(StatusBarService statusBar) {
    _statusBar = statusBar;
  }

  /// Keeps the backend's user context (callsign, LoFi account id, and the
  /// log's [databasePath]) in step with [settings] for the rest of the
  /// session — see file header.
  static void attachSettings(SettingsService settings, {String? databasePath}) {
    _updateUserContext(settings, databasePath);
    settings.addListener(() => _updateUserContext(settings, databasePath));
  }

  static void _updateUserContext(SettingsService settings, String? databasePath) {
    if (!settings.consentAppData) {
      _backend.updateUserContext();
      return;
    }
    final call = settings.activeProfile.operatorCall;
    final accountData = settings.syncState['accountData'] as Map?;
    final accountId = (accountData?['current_account'] as Map?)?['uuid'] as String?;
    _backend.updateUserContext(callsign: call.isEmpty ? null : call, accountId: accountId, databasePath: databasePath);
  }

  static void _installLocalHooks() {
    // Framework errors (widget build/layout/paint). A real backend's own
    // handler, when active, is already in this chain; preserve it.
    final previousOnError = FlutterError.onError;
    FlutterError.onError = (details) {
      // A refused write reaching the framework handler is a write attempted
      // from a build or gesture callback. Its reason goes on screen, and the
      // policy still decides everything else — it is the only thing that may.
      final refusal = details.exception;
      if (refusal is WriteRefused) noticeWriteRefused(refusal);
      final decision = ErrorPolicy.decide(details.exception, details: details);
      // Below the upload tier the chain stops here: no framework dump, no
      // backend capture (previousOnError is where a real backend's hook
      // lives), no notice — only whatever line the policy asks for.
      if (!decision.disposition.uploads) {
        ErrorPolicy.logDecision(decision, details.exception, stackTrace: details.stack);
        return;
      }
      if (previousOnError != null) {
        previousOnError(details);
      } else {
        FlutterError.presentError(details);
      }
      if (decision.disposition.notifies) notify(details.exception, details.stack);
    };

    // Replace Flutter's grey/red box with the compact branded tile; the
    // failed widget's slot shows the tile, the rest of the app keeps
    // working (see views/error_tile.dart).
    ErrorWidget.builder = (details) => HaLoErrorTile(details: details);
  }

  /// Show a refused write as its own notice, carrying the reason.
  ///
  /// Separate from [notify] on both counts that matter: it is not
  /// once-per-session, because a refusal is a thing the operator can act on
  /// and then hit again; and it says WHY rather than "Something went wrong",
  /// because "Add /T to the station callsign" is the whole point. Keyed, so
  /// repeats replace rather than stack.
  ///
  /// Here rather than at the write sites: `WritePolicy` guards a dozen of
  /// them across the app and two packages, and a refusal surfaced at eleven of
  /// them is a silent no-op at the twelfth.
  static void noticeWriteRefused(WriteRefused refusal) {
    final statusBar = _statusBar;
    if (statusBar == null) {
      // Bootstrap, a widget test, a headless run. Saying nothing here is how a
      // refused write becomes indistinguishable from one that succeeded.
      debugPrint('[write-policy] refused with no status bar to say so: ${refusal.reason}');
      return;
    }
    scheduleMicrotask(() {
      statusBar.showNotice(key: 'write-policy:refused', icon: 'clock-alert', title: 'Change not saved', text: refusal.reason, persist: false);
    });
  }

  /// Queue the once-per-session StatusBar notice (if the bar is attached).
  /// Public so a backend (app_dist) can feed its own captured events (e.g.
  /// Sentry's beforeSend, the only path for an uncaught async error, which
  /// [_installLocalHooks] never sees) into the same throttle. Deferred to a
  /// microtask: this is called from inside error handlers, which for widget
  /// errors means mid build/layout — and showNotice()'s notifyListeners()
  /// would then trip "markNeedsBuild() called during build" and throw from
  /// within the error handler itself. The throttle flag is set synchronously
  /// so concurrent errors can't double-post.
  static void notify(Object error, StackTrace? stackTrace) {
    final statusBar = _statusBar;
    if (statusBar == null || _noticeShown || _isMarked(_told, error)) return;
    _noticeShown = true;
    // resolveIconName expects a Material Design Icons name (kebab-case) or an
    // fa- prefixed FontAwesome one — a Flutter Icons constant name like
    // 'error_outline' (a different set entirely) matches neither and silently
    // falls back to the puzzle-piece placeholder.
    //
    // Not persisted: its whole point is the "Copy details" action, which
    // can't survive a restart (a VoidCallback isn't serializable), and its
    // text says nothing on its own — persisting it anyway just leaves a
    // dead, button-less copy of a past error sitting in the footer
    // indefinitely, with no way to act on it or learn what it even was.
    _postErrorNotice(
      statusBar,
      key: 'error-reporting:first-error',
      icon: 'alert-circle',
      title: 'Something went wrong',
      text: noticeText(error, stackTrace),
      error: error,
      stackTrace: stackTrace,
      persist: false,
      defer: true,
    );
  }

  /// Shows [notice] for [error] — its own text, or the error's message. Kept
  /// in history unless the caller says otherwise: unlike [notify]'s, its text
  /// names the failure, which still says something once "Copy details" is
  /// gone after a restart.
  ///
  /// Shown at once rather than deferred like [notify]'s: a caller that awaits
  /// the failure and then reads the bar must find it there. A listener that
  /// throws is the notifier's to catch; a bar already disposed is caught
  /// here, so the caller's own catch still finishes.
  static void _showErrorNotice(ErrorNotice notice, Object error, StackTrace? stackTrace) {
    try {
      _postErrorNotice(
        notice.statusBar,
        key: notice.key,
        icon: notice.icon,
        title: notice.title,
        text: notice.text ?? messageOf(error),
        error: error,
        stackTrace: stackTrace,
        persist: notice.persist,
        defer: false,
      );
    } catch (e) {
      debugPrint('[error-reporting] could not show ${notice.key}: $e');
    }
  }

  /// Posts an error notice carrying "Copy details" for [error] and its trace.
  ///
  /// [defer] posts it from a microtask, as [notify] needs: it runs inside the
  /// framework's error handler, mid build or layout. The details are built
  /// now either way: a lazily described FlutterError can name elements that
  /// are unmounted by the time a microtask runs.
  static void _postErrorNotice(
    StatusBarService statusBar, {
    required String key,
    required String icon,
    required String? title,
    required String text,
    required Object error,
    required StackTrace? stackTrace,
    required bool persist,
    required bool defer,
  }) {
    final details = '$error\n\n${stackTrace ?? ''}';
    void post() {
      statusBar.showNotice(
        key: key,
        icon: icon,
        title: title,
        text: text,
        actions: [
          StatusBarAction(
            label: t.common.copyDetails,
            onTap: () => unawaited(Clipboard.setData(ClipboardData(text: details))),
          ),
        ],
        persist: persist,
      );
    }

    if (defer) {
      scheduleMicrotask(post);
    } else {
      post();
    }
  }

  /// [error]'s message as an operator reads it: without the type name an
  /// extension failure or a plain `Exception` puts in front of it, which says
  /// nothing to anyone but whoever opens "Copy details".
  static String messageOf(Object error) {
    if (error is ExtensionHostException) return error.message;
    final text = '$error';
    return text.startsWith('Exception: ') ? text.substring('Exception: '.length) : text;
  }

  /// The trace each error was last uploaded with — see [report].
  ///
  /// Beside it, errors the operator was already told about by the caller.
  /// That one is by the object alone: a backend hands [notify] a trace it
  /// re-parsed, never the one reported. So a `const` exception a caller told
  /// the operator about keeps the generic notice off its later throws too.
  ///
  /// An object an [Expando] cannot key (a string, a number) is never marked,
  /// and simply reports each time.
  static Expando<StackTrace> _reported = Expando();
  static Expando<bool> _told = Expando();

  static bool _markable(Object error) => error is! String && error is! num && error is! bool && error is! Record;
  static void _mark(Expando<bool> marks, Object error) {
    if (_markable(error)) marks[error] = true;
  }

  static bool _isMarked(Expando<bool> marks, Object error) => _markable(error) && marks[error] == true;

  /// The body of the [notify] notice. An operator gets reassurance and the
  /// first line of what failed — enough to say which thing went wrong in a
  /// support message; a Dev build gets the error itself and where it was
  /// raised, because the person running one is the person who will fix it,
  /// and "Copy details" plus a paste is a round trip for a line that fits on
  /// the card.
  @visibleForTesting
  static String noticeText(Object error, StackTrace? stackTrace, {Edition edition = kEdition}) {
    if (edition != Edition.dev) {
      final reassurance = reportingEnabled
          ? 'An unexpected error occurred and was reported. The app should keep working; restart if anything looks off.'
          : 'An unexpected error occurred. The app should keep working; restart if anything looks off.';
      // A string is a backend's own label for an event with no error object
      // behind it ("Reported error"), not a failure's message.
      if (error is String) return reassurance;
      // A query string is where a request carries its key or token, and an
      // operator may screenshot the footer into a support thread.
      var what = messageOf(error).trim().split('\n').first.replaceAllMapped(_queryString, (m) => '${m[1]}?…');
      if (what.length > 160) what = '${what.substring(0, 160)}…';
      return what.isEmpty ? reassurance : '$reassurance\n\n$what';
    }
    var message = '$error'.trim();
    // Framework errors can run to dozens of lines; the full text is one tap
    // away on "Copy details".
    final lines = message.split('\n');
    if (lines.length > 3) message = '${lines.take(3).join('\n')}\n…';
    if (message.length > 400) message = '${message.substring(0, 400)}…';
    final frame = _firstOwnFrame(stackTrace);
    return frame == null ? message : '$message\n\nat $frame';
  }

  static final _queryString = RegExp(r'(\w+://[^\s?]+)\?[^\s,)]*');

  // `package:` on the VM, `packages/` in a web debug build's trace.
  static final _ownFrame = RegExp(r'packages?[:/](ham2k_logger|halo_\w+)/');

  /// The innermost stack frame in our own code — the app or one of its
  /// `halo_*` packages — the frame's line as the trace prints it, minus its
  /// `#N` index.
  /// Framework and SDK frames above it name where the throw landed, not the
  /// call of ours that caused it.
  static String? _firstOwnFrame(StackTrace? stackTrace) {
    if (stackTrace == null) return null;
    for (final line in '$stackTrace'.split('\n')) {
      if (!_ownFrame.hasMatch(line)) continue;
      return line.replaceFirst(RegExp(r'^#\d+\s+'), '').trim();
    }
    return null;
  }

  /// Test seam: forget the attached status bar, notice throttle, and backend
  /// (and the policy's own once-per-session state, which rides along with a
  /// session the same way).
  @visibleForTesting
  static void resetForTesting() {
    _statusBar = null;
    _noticeShown = false;
    _reported = Expando();
    _told = Expando();
    _backend = const NoopErrorReportingBackend();
    ErrorPolicy.resetForTesting();
  }
}

/// A caller's own notice for a failure it reports — see
/// [ErrorReportingService.report]. Keyed, so a repeat replaces it.
class ErrorNotice {
  final StatusBarService statusBar;
  final String key;
  final String? title;

  /// The body; the error's own message ([ErrorReportingService.messageOf])
  /// when null.
  final String? text;
  final String icon;

  /// Kept in the notice history, as [StatusBarService.showNotice] keeps one
  /// by default; its "Copy details" action does not survive a restart.
  final bool persist;

  const ErrorNotice(this.statusBar, {required this.key, this.title, this.text, this.icon = 'alert-circle', this.persist = true});
}
