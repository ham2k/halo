// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// ErrorPolicy is the single place that decides what an exception deserves,
// so what matters here is (a) the DEFAULT is the loudest tier — an error
// nobody has classified is a bug we haven't seen yet, and silence would
// hide it — and (b) each exemption is narrow enough that it cannot swallow
// a real bug of ours that merely looks similar.
//
// The delivery of those decisions (which console line, which handler stops
// where, what the operator sees) is error_reporting_test.dart's job.

import 'dart:async' show TimeoutException;
import 'dart:io' show FileSystemException, HandshakeException, HttpException, SocketException, WebSocketException;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show MissingPluginException, PlatformException;
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_extension_host/halo_extension_host.dart' show ExtensionHostException, HookTimeoutException;
import 'package:http/http.dart' show ClientException;

import 'package:ham2k_logger/services/cat/transport.dart' show CatConnectFailure;
import 'package:ham2k_logger/services/peer/peer_link_types.dart' show PeerMediaDialFailure;
import 'package:ham2k_logger/services/extensions/catalog_service.dart' show CatalogRefused, CatalogUnreachable;
// The io implementations directly, as cat_ic705_network_test.dart does: the
// conditional export resolves to the web stub under the analyzer, and these
// exceptions — the concrete CatUnreachable implementations this rule has to
// keep quiet — exist only on the socket/serial side.
import 'package:ham2k_logger/services/cat/transports/icom_network_transport_io.dart' show IcomLoginTimeout;
import 'package:ham2k_logger/services/cat/transports/serial_transport_io.dart' show SerialPortUnavailable;
import 'package:ham2k_logger/services/bottom_chrome_squeezed.dart';
import 'package:ham2k_logger/services/error_policy.dart';
import 'package:halo_core/halo_core.dart'
    show DataFileImportShrank, LogFromNewerBuild, MalformedQsonDataException, QsonFieldType, QsonTypeViolation, SyncPullStuck;
import 'package:ham2k_logger/services/extensions/extension_chasing.dart' show ChasingHookFailure;
import 'package:ham2k_logger/services/extensions/extension_scoring.dart' show ScoringHookFailure;
import 'package:ham2k_logger/services/extensions/extension_service.dart' show ExtensionTimersSuspended, MalformedSpotDataException;
import 'package:ham2k_logger/services/windows_webview.dart' show WindowsWebViewUnavailable;
import 'package:ham2k_logger/services/map_error_reporter.dart' show MapError;
import 'package:ham2k_logger/services/data_file_manager.dart' show DataFileRemoveHookFailed, DataFileUnavailable, DataFileWait;
import 'package:ham2k_logger/services/extensions/extension_catalog_migration.dart' show CatalogNotWired, UpgradeLeftNoRuntime;

ErrorDisposition dispositionFor(Object error, {FlutterErrorDetails? details}) => ErrorPolicy.decide(error, details: details).disposition;

/// An error whose toString() throws — the shape a matcher must survive.
class _HostileError implements Exception {
  @override
  String toString() => throw StateError('toString() failed too');
}

/// Stands in for the dbus package's exception, which the rule matches by
/// TYPE NAME because the app never imports that package — so this class
/// must carry the real one's exact name for its runtimeType to print the
/// same.
class DBusException implements Exception {
  final String message;
  DBusException(this.message);
}

List<String> capturedPrints(void Function() body) {
  final lines = <String>[];
  final previous = debugPrint;
  debugPrint = (message, {wrapWidth}) => lines.add(message ?? '');
  try {
    body();
  } finally {
    debugPrint = previous;
  }
  return lines;
}

void main() {
  setUp(ErrorPolicy.resetForTesting);

  group('the default', () {
    test('an unclassified error is logged, uploaded AND noticed', () {
      final decision = ErrorPolicy.decide(StateError('boom'));
      expect(decision.rule, isNull, reason: 'nothing should have claimed it');
      expect(decision.disposition, ErrorDisposition.notify);
      expect(decision.disposition.uploads, isTrue);
      expect(decision.disposition.notifies, isTrue);
    });

    test('classifying never touches an arbitrary error beyond its type', () {
      // decide() runs every matcher against every error, from INSIDE the
      // error handler — where a second exception would lose the original
      // and, on the async path, re-enter the handler that raised it. So no
      // rule may call toString() on an object it hasn't type-checked
      // first; an app object whose toString() throws is rare but real
      // (a `late` field read during teardown is enough).
      expect(() => ErrorPolicy.decide(_HostileError()), returnsNormally);
      expect(dispositionFor(_HostileError()), ErrorDisposition.notify);
    });

    test('the tiers are ordered quietest to loudest', () {
      // Callers branch on `uploads`/`notifies` rather than on the enum
      // itself, so a new tier inserted in the wrong place would silently
      // change what gets uploaded.
      expect(ErrorDisposition.ignore.uploads, isFalse);
      expect(ErrorDisposition.logOnly.uploads, isFalse);
      expect(ErrorDisposition.report.uploads, isTrue);
      expect(ErrorDisposition.report.notifies, isFalse);
      expect(ErrorDisposition.notify.uploads, isTrue);
      expect(ErrorDisposition.notify.notifies, isTrue);
    });
  });

  group('setState()/markNeedsBuild() during build', () {
    // A misordering in OUR code, but one the operator never sees: the frame
    // still renders (with the stale value) and the next one is correct. It
    // also repeats on every rebuild of the offending screen, so uploading it
    // would bury real crashes. Console-only: loud where it can be fixed.
    final message = FlutterError(
      'setState() or markNeedsBuild() called during build.\n'
      'This HomeView widget cannot be marked as needing to build because the framework is already building widgets.',
    );

    test('is console-only — never uploaded, never noticed', () {
      expect(dispositionFor(message), ErrorDisposition.logOnly);
    });

    test('is recognized off the FlutterError path too', () {
      // The same assertion can surface from a notifyListeners() inside an
      // async gap, where there are no FlutterErrorDetails to inspect.
      expect(dispositionFor(message, details: null), ErrorDisposition.logOnly);
    });

    test('a different framework error about building is still loud', () {
      expect(dispositionFor(FlutterError('A build function returned null.')), ErrorDisposition.notify);
    });

    test('an exception of ours quoting the same message is NOT swallowed', () {
      // Only the two types the framework raises this as are exempt. A
      // wrapper of ours that re-throws with the framework's text attached
      // is a bug of ours, and matching by message alone would silence it.
      expect(dispositionFor(StateError('setState() or markNeedsBuild() called during build.')), ErrorDisposition.notify);
    });
  });

  group('canRequestFocus assertion', () {
    // EditableText losing a race with its own disposal: a field is torn
    // down or disabled in the same frame something asks it to take focus.
    // The framework recovers by not moving focus; nothing is lost but a
    // caret, and there is nothing for the operator to do.
    test('is console-only', () {
      expect(dispositionFor(AssertionError("'_effectiveFocusNode.canRequestFocus': is not true.")), ErrorDisposition.logOnly);
    });

    test('a plain error merely mentioning focus is still loud', () {
      expect(dispositionFor(StateError('focus node disposed')), ErrorDisposition.notify);
      // Only the framework's own assertion is exempt: an ordinary exception
      // of ours that happens to quote the field name must not ride along.
      expect(dispositionFor(StateError('canRequestFocus went wrong')), ErrorDisposition.notify);
    });
  });

  group('bottom chrome squeezed', () {
    // The window is too short to seat all of the bottom chrome above the
    // keyboard, so the footer and then the numbers row gave way. The operator
    // cannot act on that mid-contact and a notice about a notice not fitting
    // would be absurd — but it must not be silent either, or "the numbers row
    // doesn't work on my phone" has nothing behind it.
    test('is console-only — never uploaded, never noticed', () {
      expect(dispositionFor(const BottomChromeSqueezed('no room above the keyboard for the numbers row')), ErrorDisposition.logOnly);
    });
  });

  group('connectivity backend unavailable', () {
    // connectivity_plus's Linux backend throws out of its own async stream
    // setup when NetworkManager's D-Bus service is missing — an escape no
    // subscription-side onError can reach, on systems (WSL, minimal
    // distros) where the app is otherwise fully functional.
    test('a DBus-shaped failure is console-only', () {
      expect(dispositionFor(DBusException('service unknown')), ErrorDisposition.logOnly);
      expect(dispositionFor(const SocketException('Connection failed, path = /run/dbus/system_bus_socket')), ErrorDisposition.logOnly);
    });

    test('an ordinary network failure of ours is still loud', () {
      // Only the D-Bus transport is exempt: a real SocketException from an
      // app fetch must not ride along on the type alone.
      expect(dispositionFor(const SocketException('Connection refused, host example.com')), ErrorDisposition.notify);
    });
  });

  group('web focus-traversal null (#271)', () {
    FlutterErrorDetails focusTraversalNull() => FlutterErrorDetails(
      exception: TypeError(),
      library: 'widgets library',
      context: ErrorDescription('while dispatching notifications for WidgetsBindingObserver.didChangeViewFocus'),
    );

    test('is the only rule that drops an error entirely', () {
      ErrorPolicy.debugTreatAsWeb = true;
      expect(dispositionFor(TypeError(), details: focusTraversalNull()), ErrorDisposition.ignore);
    });

    test('needs the framework context, which an async error can never carry', () {
      ErrorPolicy.debugTreatAsWeb = true;
      expect(dispositionFor(TypeError()), ErrorDisposition.notify);
    });
  });

  group('web semantics node map inconsistency', () {
    // The engine dumps both trees into the message; only the first line is
    // stable, and it is what the rule matches on.
    StateError inconsistentMap() => StateError('Semantics node map was inconsistent after update:\n\nBEFORE: ...\n\nAFTER: ...\n');

    test('is console-only — the assert it comes from is compiled out of every build a user runs', () {
      ErrorPolicy.debugTreatAsWeb = true;
      expect(dispositionFor(inconsistentMap()), ErrorDisposition.logOnly);
    });

    test('the same StateError off web stays loud', () {
      // Only the web engine keeps a semantics node map; a native build
      // raising this text is something else wearing a familiar sentence.
      ErrorPolicy.debugTreatAsWeb = false;
      expect(dispositionFor(inconsistentMap()), ErrorDisposition.notify);
    });

    test('an unrelated StateError on web stays loud', () {
      ErrorPolicy.debugTreatAsWeb = true;
      expect(dispositionFor(StateError('Bad state: no element')), ErrorDisposition.notify);
    });
  });

  group('a hot reload/restart stranding a live object', () {
    // What DDC actually reports when a private Dart field is read off an
    // instance whose class no longer declares it — the framework's own
    // `Element._lifecycleState`, in the case that motivated this.
    Object staleFieldTypeError() => _JsTypeErrorStub("TypeError: Cannot read properties of undefined (reading 'Symbol(_lifecycleState)')");

    test('is console-only — the fix is a cold start, not anything an operator can do', () {
      ErrorPolicy.debugTreatAsWeb = true;
      expect(dispositionFor(staleFieldTypeError()), ErrorDisposition.logOnly);
    });

    test('the same TypeError off web stays loud', () {
      // Native has no DDC and no undefined: a Dart field read there either
      // works or throws about the object itself, so this shape of message
      // could only be something else entirely.
      ErrorPolicy.debugTreatAsWeb = false;
      expect(dispositionFor(staleFieldTypeError()), ErrorDisposition.notify);
    });

    test("an extension's own JS crash, quoted through the host wrapper, is still loud", () {
      // The wrapper carries the engine's message verbatim, so extension code
      // that touches Symbol-keyed objects produces this exact shape — and it
      // is a real bug of theirs, not a leftover of ours.
      ErrorPolicy.debugTreatAsWeb = true;
      expect(
        dispositionFor(ExtensionHostException("TypeError: Cannot read properties of undefined (reading 'Symbol(Symbol.iterator)')")),
        ErrorDisposition.notify,
      );
    });

    test('an ordinary undefined-property failure, with no Dart field named, is still loud', () {
      // Interop code reading a property that genuinely is not there is a bug
      // in our code; only the `Symbol(` — a private Dart member — says the
      // object itself is a leftover.
      ErrorPolicy.debugTreatAsWeb = true;
      expect(dispositionFor(_JsTypeErrorStub("TypeError: Cannot read properties of undefined (reading 'features')")), ErrorDisposition.notify);
    });
  });

  group('extension host teardown', () {
    // dispose() fails every pending hook call with this exact message, and
    // disposal only happens on a runtime replacement (an extension toggle,
    // a restartOnChange commit, crash backoff, shutdown) — so every
    // subsystem with a call in flight (lookup, data files, sync) reports
    // the same expected teardown at once. Without this rule, toggling an
    // extension raises the "Something went wrong" notice for that churn.
    test('a hook call cut off by dispose() is console-only', () {
      expect(dispositionFor(ExtensionHostException('extension host disposed')), ErrorDisposition.logOnly);
    });

    // The fail-fast for calls attempted between a crash and the backoff
    // restart. The crash itself reports once via extensions:restart; each
    // of these is a per-call duplicate of that known state.
    test('a hook call refused against a dead runtime is console-only', () {
      expect(dispositionFor(ExtensionHostException('extension runtime is dead (hook lookupService.lookupCallInfo not attempted)')), ErrorDisposition.logOnly);
    });

    test('other host exceptions are still loud', () {
      // The exemption is the teardown races only. A hook's own throw
      // arrives as the same type and must keep the default tier — those
      // are the bugs worth seeing. The timeout text without the timeout
      // TYPE is some other failure quoting it, not the host's own timeout.
      expect(dispositionFor(ExtensionHostException('hook spots.fetchSpots timed out after 5000ms')), ErrorDisposition.notify);
      // The disposed matcher is exact, not contains(): a message merely
      // embedding the text is some other failure quoting it.
      expect(dispositionFor(ExtensionHostException('wrapped: extension host disposed')), ErrorDisposition.notify);
    });

    test('a foreign exception quoting the message is NOT swallowed', () {
      // Only the host's own exception type is exempt; matching by message
      // alone would let a wrapper of ours ride along.
      expect(dispositionFor(StateError('extension host disposed')), ErrorDisposition.notify);
      expect(dispositionFor(StateError('extension runtime is dead')), ErrorDisposition.notify);
    });
  });

  group('a hook that timed out', () {
    // The lookup pipeline is the loud case: it runs on a debounced
    // keystroke, so one slow upstream turns every few characters typed
    // into a "Something went wrong". Nothing is lost that the operator
    // could act on — the lookup returns nothing and the next keystroke
    // asks again — but the rate is worth having, hence report not logOnly.
    test('reported, not noticed', () {
      final decision = ErrorPolicy.decide(HookTimeoutException('hook lookupService.lookupCallInfo timed out after 8000ms'));
      expect(decision.disposition, ErrorDisposition.report);
      expect(decision.rule?.id, 'hook-timed-out');
    });

    // The matcher does not unwrap. A scoring timeout arrives wrapped in
    // ScoringHookFailure and must keep ITS rule, which is what carries the
    // reasoning about a board that reads available rather than worked.
    test('a timeout wrapped in another exception keeps that rule', () {
      final decision = ErrorPolicy.decide(ScoringHookFailure('core', 'scoreCandidates', HookTimeoutException('hook scoring.scoreCandidates timed out')));
      expect(decision.rule?.id, 'scoring-hook-failed');
    });

    // A program that times out has failed its batch, not the operator: it is
    // reported, never noticed, like a scorer.
    test('a chasing timeout keeps the chasing rule', () {
      final decision = ErrorPolicy.decide(ChasingHookFailure('dxcc', 'claimsForQsos', HookTimeoutException('hook chasing.claimsForQsos timed out')));
      expect(decision.rule?.id, 'chasing-hook-failed');
      expect(decision.disposition, ErrorDisposition.report);
    });

    // A crashed or replaced runtime fails every scorer and program in the
    // pass at once. Reported per extension, one crash would upload as a
    // defect in each of them.
    test('a hook failure caused by a dead or replaced runtime keeps the runtime rule, for scoring and chasing alike', () {
      final dead = ExtensionHostException('extension runtime is dead (hook chasing.claimsForQsos not attempted)');
      expect(ErrorPolicy.decide(ChasingHookFailure('dxcc', 'claimsForQsos', dead)).rule?.id, 'extension-runtime-dead');
      expect(ErrorPolicy.decide(ScoringHookFailure('core', 'scoreQsos', dead)).rule?.id, 'extension-runtime-dead');
      expect(
        ErrorPolicy.decide(ChasingHookFailure('dxcc', 'claimsForQsos', ExtensionHostException('extension host disposed'))).rule?.id,
        'extension-host-disposed',
      );
    });

    // Matched on the type alone. A hook that throws its OWN "timed out"
    // message is an extension defect, and stays at the default tier.
    test('a hook throwing its own timeout message is still loud', () {
      expect(dispositionFor(ExtensionHostException('lookupCallInfo: the QRZ request timed out')), ErrorDisposition.notify);
    });
  });

  group('a sync pull stuck on one request', () {
    // It carries the timeout that failed it. Classified by that cause it would
    // land in hook-timed-out beside every slow link — the very blur the type
    // exists to undo — and a notice would point the operator at a fault only
    // the server can clear.
    test('reported under its own rule, not noticed', () {
      final decision = ErrorPolicy.decide(
        SyncPullStuck(
          backfilling: false,
          limit: 743,
          position: const {
            'qsos': {'from': 0, 'cursor': false},
          },
          pushing: 0,
          cause: HookTimeoutException('hook syncTransport.sync timed out after 30000ms'),
        ),
      );
      expect(decision.disposition, ErrorDisposition.report);
      expect(decision.rule?.id, 'sync-pull-stuck');
    });

    // The same timeout unwrapped is one slow round, which is what hook-timed-out is for.
    test('a bare sync timeout keeps its own rule', () {
      expect(ErrorPolicy.decide(HookTimeoutException('hook syncTransport.sync timed out after 30000ms')).rule?.id, 'hook-timed-out');
    });
  });

  group('windows webview unavailable', () {
    // The whole point of the fallback: on a machine where WebView2 won't
    // start, the map quietly becomes OpenStreetMap and the account login says
    // it can't sign in there. Without this rule the default tier applies and
    // the operator ALSO gets "Something went wrong" — about a Windows
    // component, from an app that has already handled it. Uploading still
    // matters: the HRESULT is the only evidence of why a given machine fails.
    test("the platform's refusal is uploaded but not put on screen", () {
      expect(
        // Verbatim from the plugin when the user data folder is unwritable.
        dispositionFor(WindowsWebViewUnavailable(PlatformException(code: '0', message: 'Cannot create WebViewEnvironment: Access is denied.'))),
        ErrorDisposition.report,
      );
      expect(dispositionFor(const WindowsWebViewUnavailable(FileSystemException('Creation failed', r'C:\ProgramData'))), ErrorDisposition.report);
      // The browser process never came up; indistinguishable to the operator
      // from a refusal, and handled the same way.
      expect(dispositionFor(WindowsWebViewUnavailable(TimeoutException('webview environment', const Duration(seconds: 30)))), ErrorDisposition.report);
    });

    test('our own build being broken is still loud', () {
      // The cause is inspected rather than the wrapper alone because this is
      // the one failure that is OURS: a Windows build shipped without the
      // plugin registered fails for every user on every machine, and must not
      // hide inside a rule written for one operator's PC.
      expect(dispositionFor(WindowsWebViewUnavailable(MissingPluginException('no implementation found'))), ErrorDisposition.notify);
      expect(dispositionFor(WindowsWebViewUnavailable(TypeError())), ErrorDisposition.notify);
    });

    test('the same platform failure outside the webview is still loud', () {
      // The wrapper IS the rule's scope. A PlatformException reaching the
      // policy from anywhere else has no webview to blame.
      expect(dispositionFor(PlatformException(code: '0', message: 'Cannot create WebViewEnvironment: Access is denied.')), ErrorDisposition.notify);
    });
  });

  group('cat equipment unreachable', () {
    // The everyday state of a station: the rig is off, or the cable is out,
    // or another program holds it. CatService retries the designated radio
    // for the whole session, so without this rule ONE switched-off radio
    // means a notice on the operator's screen and an upload every few
    // minutes until they turn it on.
    test('a radio that is not answering is console-only', () {
      expect(
        // Verbatim from a Flex left switched off at launch.
        dispositionFor(
          const CatConnectFailure(
            'flexradio',
            SocketException(
              'Connection failed (OS Error: No route to host, errno = 65), '
              'address = 10.0.0.66, port = 4992',
            ),
          ),
        ),
        ErrorDisposition.logOnly,
      );
      expect(dispositionFor(CatConnectFailure('icom-network', TimeoutException('the radio did not answer: login'))), ErrorDisposition.logOnly);
      // A transport's own account of the same thing, tagged CatUnreachable.
      expect(dispositionFor(const CatConnectFailure('ft891', SerialPortUnavailable('/dev/cu.usbserial', 'busy'))), ErrorDisposition.logOnly);
      expect(dispositionFor(const CatConnectFailure('icom-network', IcomLoginTimeout())), ErrorDisposition.logOnly);
    });

    test('a bug raised inside a connect attempt is still loud', () {
      // The reason the cause is inspected at all rather than the rule
      // matching every failed connect: our own code runs inside that try —
      // a bad config cast, a handshake step that gets its state wrong — and
      // those are bugs the rule must not take down with the radio.
      expect(dispositionFor(CatConnectFailure('flexradio', TypeError())), ErrorDisposition.notify);
      expect(dispositionFor(CatConnectFailure('icom-network', StateError('the radio sent a stream answer we do not understand'))), ErrorDisposition.notify);
    });

    test('the same socket failure outside a connect attempt is still loud', () {
      // The wrapper IS the rule's scope. A SocketException reaching the
      // policy from anywhere else in the app has no radio to blame.
      expect(
        dispositionFor(
          const SocketException(
            'Connection failed (OS Error: No route to host, errno = 65), '
            'address = 10.0.0.66, port = 4992',
          ),
        ),
        ErrorDisposition.notify,
      );
    });
  });

  group('peer media unreachable', () {
    // The view reports through the failure streak, which asks this policy
    // before counting: a firewall between two peers is not a defect, so the
    // refusal neither uploads nor spends the streak's one report.
    test('a peer that refuses or never answers the media link is console-only', () {
      for (final cause in <Object>[
        const SocketException('Connection refused'),
        const WebSocketException("Connection to 'ws://10.0.0.2:41000/media' was not upgraded to websocket"),
        // A peer that closes mid-dial: what the real socket raises, and
        // neither of the two shapes above.
        const HttpException('Connection closed before full header was received'),
        TimeoutException('peer dial to 10.0.0.2:41000 timed out'),
      ]) {
        expect(dispositionFor(PeerMediaDialFailure('device-b', cause)), ErrorDisposition.logOnly, reason: '$cause');
      }
    });

    test('a bug raised by the dial is still loud', () {
      // The reason the cause is inspected rather than the rule matching the
      // wrapper outright: the dial goes through an injectable PeerNetwork,
      // and an implementation throwing out of its own state is a defect
      // that the pane shows as the same "not connected" as a firewall.
      expect(dispositionFor(PeerMediaDialFailure('device-b', StateError('lost its own state'))), ErrorDisposition.notify);
    });
  });

  group('fetch transport transience', () {
    // A ClientException or TimeoutException from _hostFetch's own send()
    // call stringifies through the kernel into an ExtensionHostException
    // with that exception's toString() as its message — the caller (e.g.
    // SyncEngine's backoff loop) already retries, so this is worth
    // uploading in aggregate but not worth an operator notice.
    test('a connection reset is reported, not noticed', () {
      expect(dispositionFor(ExtensionHostException('ClientException: Connection reset by peer, uri=https://lofi.ham2k.net/v1/sync')), ErrorDisposition.report);
    });

    test('other transport-layer failures are reported too', () {
      expect(dispositionFor(ExtensionHostException('ClientException: Connection refused, uri=https://lofi.ham2k.net/v1/sync')), ErrorDisposition.report);
      expect(
        dispositionFor(ExtensionHostException('ClientException: Connection closed while receiving data, uri=https://lofi.ham2k.net/v1/sync')),
        ErrorDisposition.report,
      );
      expect(dispositionFor(ExtensionHostException('TimeoutException after 0:00:15.000000: Future not completed')), ErrorDisposition.report);
    });

    test('a DNS lookup failure wrapped by http.IOClient is reported, not noticed', () {
      // http's IOClient wraps a socket-layer failure in its OWN subclass,
      // whose toString() reads "ClientException with $cause, ..." rather
      // than plain ClientException's "ClientException: $message" — a
      // format the prefix check must match too, or every DNS blip on a
      // captive portal or dead WiFi notifies the operator.
      expect(
        dispositionFor(
          ExtensionHostException(
            "ClientException with SocketException: Failed host lookup: "
            "'lofi.ham2k.net' (OS Error: No address associated with hostname, errno = 7), "
            "uri=https://lofi.ham2k.net/v1/sync",
          ),
        ),
        ErrorDisposition.report,
      );
    });

    test('a hook call timing out is not claimed by THIS rule', () {
      // Distinct from _hostFetch's transport timeout: a hook that simply
      // takes too long throws its own message, which does not start with
      // "TimeoutException". The real one carries the host's timeout type
      // and lands on `hook-timed-out`; the same text on a bare host
      // exception is some other failure quoting it, and stays loud.
      expect(ErrorPolicy.decide(HookTimeoutException('hook spots.fetchSpots timed out after 5000ms')).rule?.id, 'hook-timed-out');
      expect(dispositionFor(ExtensionHostException('hook spots.fetchSpots timed out after 5000ms')), ErrorDisposition.notify);
    });

    test('a foreign exception quoting the message is NOT swallowed', () {
      // Only the host's own exception type is exempt.
      expect(dispositionFor(StateError('ClientException: Connection reset by peer, uri=https://lofi.ham2k.net/v1/sync')), ErrorDisposition.notify);
    });
  });

  group('lofi backup capture also failing', () {
    // sync()'s catch block in extensions/sync/ham2k-lofi/src/index.ts
    // prefixes the original LoFi error with this exact text when its own
    // fallback capture to the backup service also throws. Asserted via the
    // rule id, not just the disposition -- this rule's disposition happens
    // to equal the default (notify), so a disposition-only assertion could
    // pass even if the message never actually matched.
    test('is classified by its own rule, not folded into the unmatched default', () {
      final decision = ErrorPolicy.decide(
        ExtensionHostException(
          'LoFi sync failed and the backup capture also failed: LoFi request failed: HTTP 503 '
          '(capture error: backup capture returned HTTP 500)',
        ),
      );
      expect(decision.rule?.id, 'lofi-backup-capture-also-failed');
      expect(decision.disposition, ErrorDisposition.notify);
    });

    test('an ordinary LoFi failure is NOT claimed by this rule', () {
      final decision = ErrorPolicy.decide(ExtensionHostException('LoFi request failed: HTTP 503'));
      expect(decision.rule, isNull);
      expect(decision.disposition, ErrorDisposition.notify);
    });
  });

  group('catalog unreachable', () {
    // CatalogService reports a dead catalog through a failure streak, and the
    // streak's third strike lands here. Its own wrapper type is what lets a
    // TimeoutException stay quiet on THIS path while the bare one stays loud
    // everywhere else (the sibling test in the http-client group).
    final url = Uri.parse('https://catalog.ham2k.net/api/v1/updates');

    test('a connection failure, a timeout, or a dart:io failure on the catalog is reported, not noticed', () {
      // IOClient hands a TLS handshake or socket failure up unwrapped, so
      // the cause is not always a ClientException; matched on
      // ClientException alone, a refused handshake on the six-hourly check
      // would notify the operator about a server they never asked about.
      for (final cause in [ClientException('connection refused'), TimeoutException('5s'), HandshakeException('tls'), const SocketException('reset')]) {
        final decision = ErrorPolicy.decide(CatalogUnreachable(url, cause));
        expect(decision.rule?.id, 'catalog-unreachable', reason: '$cause');
        expect(decision.disposition, ErrorDisposition.report, reason: '$cause');
      }
    });

    test('an error status on the catalog is reported, not noticed', () {
      // A challenge page or a maintenance response in front of the six-hourly
      // check. Unclassified, the default notify puts a notice in front of an
      // operator who asked for nothing.
      final decision = ErrorPolicy.decide(CatalogRefused(url, 503));
      expect(decision.rule?.id, 'catalog-unreachable');
      expect(decision.disposition, ErrorDisposition.report);
    });

    test('the wrapper does not launder anything else — a non-transport cause stays loud', () {
      expect(dispositionFor(CatalogUnreachable(url, const FormatException('not json'))), ErrorDisposition.notify);
    });
  });

  group('http client connection transience', () {
    // DataFileManager talks to package:http directly rather than through
    // hostFetch, so its connection failures reach the policy as a raw
    // ClientException, not an ExtensionHostException — a different rule
    // from fetch-transport-transient, matched on type alone since
    // ClientException has no other cause.
    test('a connection failure is reported, not noticed', () {
      expect(dispositionFor(ClientException('Connection reset by peer')), ErrorDisposition.report);
    });

    test('a bare TimeoutException is NOT swallowed', () {
      // Too generic a type to match on its own app-wide — see the sibling
      // test in the fetch-transport-transience group. A download's timeout
      // is quietened through its own wrapper (the data-file group below).
      expect(dispositionFor(TimeoutException('the radio did not answer: pkt4')), ErrorDisposition.notify);
    });
  });

  group('a data file refresh', () {
    // The boot and reconnect passes refresh data files nobody asked about;
    // unclassified, a slow or failing server there puts "Something went
    // wrong" in front of the operator on every boot. An attended refresh names the failure in its own
    // notice, so none of these needs the policy's.
    test('that timed out is reported, not noticed', () {
      final decision = ErrorPolicy.decide(const DataFileUnavailable.timedOut('pota-all-parks', 'pota.app', DataFileWait.headers));
      expect(decision.rule?.id, 'data-file-unavailable');
      expect(decision.disposition, ErrorDisposition.report);
    });

    test('answered with an error status is reported, not noticed', () {
      expect(dispositionFor(const DataFileUnavailable.status('pota-all-parks', 'pota.app', 503)), ErrorDisposition.report);
    });

    test('refused as far smaller than the stored data is reported, not noticed', () {
      final decision = ErrorPolicy.decide(const DataFileImportShrank('pota-all-parks', imported: 0, existing: 95000));
      expect(decision.rule?.id, 'data-file-import-shrank');
      expect(decision.disposition, ErrorDisposition.report);
    });

    test('forced through anyway is reported too', () {
      expect(dispositionFor(const DataFileImportShrank('pota-all-parks', imported: 0, existing: 95000, forced: true)), ErrorDisposition.report);
    });
  });

  group('malformed spot data', () {
    // The actual disposition check for extension_hook_api.dart's validSpots():
    // hook_partition_test.dart only proves the STATUS BAR stayed empty, which
    // it always does on this path (report() never calls notify() — see
    // error_reporting_test.dart) regardless of which tier the rule assigns.
    // Reading the decision straight off ErrorPolicy is what actually catches
    // the rule being loosened to `notify` by accident.
    test('reported, not noticed — the operator cannot fix another extension\'s bug', () {
      expect(dispositionFor(MalformedSpotDataException('wwff', 'freq', '14285.0')), ErrorDisposition.report);
    });
  });

  group('extension timers suspended', () {
    // Reported, never noticed by the policy: developer mode has its own notice
    // naming the extension, and the operator cannot act on either. Loosened to
    // `notify`, every suspension would spend the session's one error notice.
    test('reported, not noticed', () {
      expect(dispositionFor(const ExtensionTimersSuspended('pota', 'budget')), ErrorDisposition.report);
    });
  });

  group('malformed QSON data', () {
    // Uploaded, never noticed: by the time this is raised the value has
    // already been parsed or dropped and the record stored, so there is
    // nothing for the operator to act on — it exists only to name whatever
    // WROTE a bool mode, which read-side coercion alone leaves unknown.
    // Loosening it to `notify` would put a notice in front of an operator
    // for a peer app's defect, on every wrong-typed field that syncs in.
    test('reported, not noticed — nothing is broken by the time it is raised', () {
      expect(
        dispositionFor(MalformedQsonDataException('qsos:mergeFromSync', const QsonTypeViolation('mode', QsonFieldType.string, 'bool'))),
        ErrorDisposition.report,
      );
    });
  });

  group('a scoring hook that failed', () {
    // Uploaded because the failure is INVISIBLE where it lands: the pass
    // returns without that scorer's verdicts, so a broken `core` shows as a
    // board where nothing is struck — which looks exactly like a board of
    // fresh spots. Not noticed, because an operator mid-activation can do
    // nothing about an extension's defect.
    test('reported, not noticed', () {
      expect(dispositionFor(ScoringHookFailure('core', 'scoreCandidates', TimeoutException('hook timed out'))), ErrorDisposition.report);
    });
  });

  group('a keychain locked by the device', () {
    // Verbatim from flutter_secure_storage_darwin, both its throw sites: one
    // generic `code` for every keychain failure, the OSStatus in `details`,
    // and the status rendered again into the message. A rule reading the
    // message, or reading `details` as anything but an int, matches nothing a
    // device ever sends — and this reconstruction is the only thing standing
    // between that mistake and a green suite.
    PlatformException keychainFailure(int status, String message) =>
        PlatformException(code: 'Unexpected security result code', message: 'Code: $status, Message: $message', details: status);

    // The trap: catching a keychain refusal at the call site does NOT keep it
    // quiet. Both call sites that meet this one (SettingsService's equipment
    // secret, the extension host's account) already catch it and hand it to
    // report(), which raises no notice of its own — but in a dist build
    // Sentry's beforeSend re-runs the policy over every captured exception
    // and notifies there, so an unclassified refusal still spends the
    // session's one notice on a background retry.
    test('is reported, never noticed', () {
      final error = keychainFailure(-25308, 'User interaction is not allowed.');
      expect(ErrorPolicy.decide(error).rule?.id, 'keychain-locked');
      expect(dispositionFor(error), ErrorDisposition.report);
    });

    // A refusal to LIST is a different thing from a refusal to read: macOS
    // answers errSecParam for a readAll against the file keychain, always,
    // so it is a property of the platform and not a fault. Both callers fall
    // back to the names they can construct and carry on, and uploading one
    // event per extension per migration would say the same known thing
    // several times a launch.
    test('a keychain that will not enumerate is logged, not uploaded', () {
      final error = keychainFailure(-50, 'One or more parameters passed to a function were not valid.');
      expect(ErrorPolicy.decide(error).rule?.id, 'keychain-cannot-enumerate');
      expect(dispositionFor(error), ErrorDisposition.logOnly);
    });

    // The rule has to stay a hole exactly one status wide. -34018 is a
    // missing entitlement — our signing, our bug, and the one keychain
    // failure a broadened match would swallow while looking correct.
    test('a missing entitlement stays loud', () {
      final error = keychainFailure(-34018, "A required entitlement isn't present.");
      expect(ErrorPolicy.decide(error).rule, isNull);
      expect(dispositionFor(error), ErrorDisposition.notify);
    });

    test('a PlatformException carrying no status stays loud', () {
      expect(dispositionFor(PlatformException(code: 'error', message: 'boom')), ErrorDisposition.notify);
    });

    // The `code` is what ties the exception to the keychain at all: -25308 is
    // only errSecInteractionNotAllowed coming from Security.framework, and
    // another plugin numbering its own failures must not inherit the
    // exemption by landing on the same integer.
    test("another plugin's -25308 stays loud", () {
      expect(dispositionFor(PlatformException(code: 'error', details: -25308)), ErrorDisposition.notify);
    });

    // `details` is dynamic and Dart reads -25308.0 == -25308 as true, so the
    // rule checks the type before the value. A double is the only shape that
    // can prove it — a String would be rejected by the `==` alone, and would
    // pass just as well with the type check deleted.
    //
    // Sound to assert here only because this file runs on the VM: `is int`
    // answers true for an integral double on web, and scripts/test.sh's
    // browser step compiles one named file, which is not this one.
    test('a double that merely equals the status stays loud', () {
      expect(dispositionFor(PlatformException(code: 'Unexpected security result code', details: -25308.0)), ErrorDisposition.notify);
    });
  });

  group('map errors while offline', () {
    // The offline stamp is the whole discriminator: a device without
    // coverage fails every style and tile fetch as a matter of course (the
    // normal state of an off-grid activation), while the same error online
    // is the evidence HALO-214 exists to collect.
    test('an offline-stamped map error is console-only', () {
      const error = MapError.raw(backend: 'web', kind: 'gl-error', message: 'Failed to fetch', offline: true);
      final decision = ErrorPolicy.decide(error);
      expect(decision.rule?.id, 'map-offline');
      expect(decision.disposition, ErrorDisposition.logOnly);
    });

    test('the same error online stays loud', () {
      // An expired token, a style that won't parse, a layer bug of ours —
      // all arrive online, and quieting them would make a blank map
      // evidence-free again.
      const error = MapError.raw(backend: 'web', kind: 'gl-error', message: 'Failed to fetch', offline: false);
      expect(ErrorPolicy.decide(error).rule, isNull);
      expect(dispositionFor(error), ErrorDisposition.notify);
    });
  });

  group('console logging', () {
    test('an unclassified error prints nothing of its own', () {
      // Its console dump is the framework's / report()'s job; a policy line
      // for it would just be a duplicate.
      expect(ErrorPolicy.logDecision(ErrorPolicy.decide(StateError('boom')), 'boom'), isFalse);
    });

    test('a once-per-session rule stops printing after the first', () {
      ErrorPolicy.debugTreatAsWeb = true;
      final details = FlutterErrorDetails(
        exception: TypeError(),
        context: ErrorDescription('while dispatching notifications for WidgetsBindingObserver.didChangeViewFocus'),
      );
      final decision = ErrorPolicy.decide(TypeError(), details: details);
      final lines = capturedPrints(() {
        ErrorPolicy.logDecision(decision, 'x');
        ErrorPolicy.logDecision(decision, 'x');
      });
      expect(lines, hasLength(1), reason: 'this fires on every browser focus change');
      expect(lines.single, contains('web-focus-traversal-null'));
    });

    test('an ordinary quiet rule prints every time, with its reason', () {
      final decision = ErrorPolicy.decide(FlutterError('A RenderFlex overflowed by 13 pixels on the right.'));
      final lines = capturedPrints(() {
        ErrorPolicy.logDecision(decision, 'x');
        ErrorPolicy.logDecision(decision, 'x');
      });
      expect(lines, hasLength(2));
      expect(lines.first, contains('renderflex-overflow'));
      expect(lines.first, contains('logOnly'), reason: 'the console has to say where the error went');
    });

    test('a quiet rule prints the stack, which nothing else will', () {
      // The handler returns before FlutterError.presentError for a quiet
      // tier, so this line is the ONLY output the error gets. Without the
      // stack, a set-state-during-build report names the widget that
      // suffered and never the call that did it — which is the one thing
      // needed to fix it.
      final error = FlutterError('setState() or markNeedsBuild() called during build.');
      final decision = ErrorPolicy.decide(error);
      final stack = StackTrace.fromString('#0  OperationView.build (operation_view.dart:120:5)');
      final lines = capturedPrints(() => ErrorPolicy.logDecision(decision, error, stackTrace: stack));
      expect(lines.single, contains('operation_view.dart:120:5'));
    });
  });

  group('a database closed on the way out', () {
    // Hand-copied from drift, and therefore proof of nothing about the
    // wording: what the SHIPPED connection type raises is pinned in
    // shutdown_on_exit_test.dart, against a real background isolate. These
    // two exist to pin the SCOPING below — that the exemption turns on the
    // quit and not on the message.
    final reopen = StateError(
      "Can't re-open a database after closing it. Please create a new database connection and open "
      'that instead.',
    );
    final closed = StateError(
      'This database or transaction runner has already been closed and may '
      'not be used anymore.',
    );
    final remote = StateError(
      'Tried to send Request (id = 18): StatementMethod.select: SELECT 1 '
      'with [] over isolate channel, but the connection was closed!',
    );

    test('is console-only once the app has committed to quitting', () {
      // Nothing else closes the database, so the quit is the only moment a
      // sync round or a peer event can lose this race — and an upload blaming
      // sync for a write that had nowhere to go is noise, not a defect.
      ErrorPolicy.appIsExiting = true;
      expect(dispositionFor(reopen), ErrorDisposition.logOnly);
      expect(dispositionFor(closed), ErrorDisposition.logOnly);
      expect(dispositionFor(remote), ErrorDisposition.logOnly);
    });

    test('mid-session, the same error is still loud', () {
      // The timing is the entire exemption. Something closing the database
      // while the app is running is a defect of ours, and quietening it on
      // the message alone would hide exactly that.
      expect(dispositionFor(reopen), ErrorDisposition.notify);
      expect(dispositionFor(closed), ErrorDisposition.notify);
      expect(dispositionFor(remote), ErrorDisposition.notify);
    });

    test('an unrelated StateError during the quit stays loud', () {
      ErrorPolicy.appIsExiting = true;
      expect(dispositionFor(StateError('boom')), ErrorDisposition.notify);
    });
  });

  group('a data file clean-up hook', () {
    test('that was never implemented is console-only', () {
      // Most extensions implement no onRemoveRawData, and the kernel answers
      // "no hook registered" for every one of them. Unclassified, the default
      // tier would upload it AND put "Something went wrong" on screen for an
      // extension that is behaving exactly as intended.
      expect(dispositionFor(DataFileRemoveHookFailed('parks', Exception('no hook registered for dataFile/parks'))), ErrorDisposition.logOnly);
    });

    test('that exists and THREW is still loud', () {
      // The hook ran and failed half way, so raw data it meant to delete is
      // still on disk. Quietening the whole wrapper — rather than the one
      // answer that means "absent" — would classify an unknown failure down
      // to silence, which is what the default tier exists to prevent.
      expect(dispositionFor(DataFileRemoveHookFailed('parks', Exception('TypeError: rows is not iterable'))), ErrorDisposition.notify);
    });
  });

  group('the extension graph left unwired', () {
    test('reports a missing catalog without a notice', () {
      // Nothing the operator can act on, and the audience is whoever changes
      // the service graph. Unclassified, it would wear a notice.
      expect(dispositionFor(const CatalogNotWired()), ErrorDisposition.report);
    });

    test('an upgrade that left no runtime at all reports too', () {
      // The operator is already told in as many words; what the backend adds
      // is the rate, which is how one corrupt download is told from a bundle
      // the catalog ships broken to everybody.
      expect(dispositionFor(const UpgradeLeftNoRuntime()), ErrorDisposition.report);
    });
  });

  group('a log written by a newer build', () {
    test('is console-only, because boot has already said more', () {
      // The generic "Something went wrong" would REPLACE a notice that names
      // both storage versions and the folder the log is in — so quietening
      // this one is what keeps the specific message the only thing shown.
      // And a refused database refuses EVERY query, so a tier that uploads
      // would send one session's worth of the same fact.
      expect(dispositionFor(const LogFromNewerBuild(storage: 14, understood: 13)), ErrorDisposition.logOnly);
    });

    test('a StateError merely quoting the same words is still loud', () {
      // The refusal used to BE a StateError with this sentence in it. A rule
      // that matched the text would keep quietening any error that happens
      // to read the same, long after the type stopped being one.
      expect(
        dispositionFor(
          StateError(
            'This log was written by a newer version of Ham2K Logger '
            '(storage v14; this build understands v13)',
          ),
        ),
        ErrorDisposition.notify,
      );
    });
  });
}

/// Stands in for the JS `TypeError` DDC raises on web: the policy matches it
/// by message, and no Dart type in the VM the tests run in carries one.
class _JsTypeErrorStub {
  final String message;

  const _JsTypeErrorStub(this.message);

  @override
  String toString() => message;
}
