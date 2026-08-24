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
import 'dart:io' show FileSystemException, SocketException;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show MissingPluginException, PlatformException;
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_extension_host/halo_extension_host.dart' show ExtensionHostException;
import 'package:http/http.dart' show ClientException;

import 'package:ham2k_logger/services/cat/transport.dart' show CatConnectFailure;
// The io implementations directly, as cat_ic705_network_test.dart does: the
// conditional export resolves to the web stub under the analyzer, and these
// exceptions — the concrete CatUnreachable implementations this rule has to
// keep quiet — exist only on the socket/serial side.
import 'package:ham2k_logger/services/cat/transports/icom_network_transport_io.dart' show IcomLoginTimeout;
import 'package:ham2k_logger/services/cat/transports/serial_transport_io.dart' show SerialPortUnavailable;
import 'package:ham2k_logger/services/bottom_chrome_squeezed.dart';
import 'package:ham2k_logger/services/error_policy.dart';
import 'package:ham2k_logger/services/extension_service.dart' show MalformedSpotDataException, ScoringHookFailure;
import 'package:ham2k_logger/services/windows_webview.dart' show WindowsWebViewUnavailable;
import 'package:ham2k_logger/services/map_error_reporter.dart' show MapError;

ErrorDisposition dispositionFor(Object error, {FlutterErrorDetails? details}) =>
    ErrorPolicy.decide(error, details: details).disposition;

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
      expect(
        dispositionFor(FlutterError('A build function returned null.')),
        ErrorDisposition.notify,
      );
    });

    test('an exception of ours quoting the same message is NOT swallowed', () {
      // Only the two types the framework raises this as are exempt. A
      // wrapper of ours that re-throws with the framework's text attached
      // is a bug of ours, and matching by message alone would silence it.
      expect(
        dispositionFor(StateError('setState() or markNeedsBuild() called during build.')),
        ErrorDisposition.notify,
      );
    });
  });

  group('canRequestFocus assertion', () {
    // EditableText losing a race with its own disposal: a field is torn
    // down or disabled in the same frame something asks it to take focus.
    // The framework recovers by not moving focus; nothing is lost but a
    // caret, and there is nothing for the operator to do.
    test('is console-only', () {
      expect(
        dispositionFor(AssertionError("'_effectiveFocusNode.canRequestFocus': is not true.")),
        ErrorDisposition.logOnly,
      );
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
      expect(
        dispositionFor(const BottomChromeSqueezed('no room above the keyboard for the numbers row')),
        ErrorDisposition.logOnly,
      );
    });
  });

  group('connectivity backend unavailable', () {
    // connectivity_plus's Linux backend throws out of its own async stream
    // setup when NetworkManager's D-Bus service is missing — an escape no
    // subscription-side onError can reach, on systems (WSL, minimal
    // distros) where the app is otherwise fully functional.
    test('a DBus-shaped failure is console-only', () {
      expect(dispositionFor(DBusException('service unknown')), ErrorDisposition.logOnly);
      expect(
        dispositionFor(const SocketException('Connection failed, path = /run/dbus/system_bus_socket')),
        ErrorDisposition.logOnly,
      );
    });

    test('an ordinary network failure of ours is still loud', () {
      // Only the D-Bus transport is exempt: a real SocketException from an
      // app fetch must not ride along on the type alone.
      expect(
        dispositionFor(const SocketException('Connection refused, host example.com')),
        ErrorDisposition.notify,
      );
    });
  });

  group('web focus-traversal null (#271)', () {
    FlutterErrorDetails focusTraversalNull() => FlutterErrorDetails(
          exception: TypeError(),
          library: 'widgets library',
          context: ErrorDescription(
            'while dispatching notifications for WidgetsBindingObserver.didChangeViewFocus',
          ),
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

  group('extension host teardown', () {
    // dispose() fails every pending hook call with this exact message, and
    // disposal only happens on a runtime replacement (an extension toggle,
    // a restartOnChange commit, crash backoff, shutdown) — so every
    // subsystem with a call in flight (lookup, data files, sync) reports
    // the same expected teardown at once. Without this rule, toggling an
    // extension raises the "Something went wrong" notice for that churn.
    test('a hook call cut off by dispose() is console-only', () {
      expect(
        dispositionFor(ExtensionHostException('extension host disposed')),
        ErrorDisposition.logOnly,
      );
    });

    // The fail-fast for calls attempted between a crash and the backoff
    // restart. The crash itself reports once via extensions:restart; each
    // of these is a per-call duplicate of that known state.
    test('a hook call refused against a dead runtime is console-only', () {
      expect(
        dispositionFor(ExtensionHostException('extension runtime is dead (hook lookupService.lookupCallInfo not attempted)')),
        ErrorDisposition.logOnly,
      );
    });

    test('other host exceptions are still loud', () {
      // The exemption is the teardown races only. A timeout, a fetch
      // failure or a hook's own throw arrives as the same type and must
      // keep the default tier — those are the bugs worth seeing.
      expect(
        dispositionFor(ExtensionHostException('hook spots.fetchSpots timed out after 5000ms')),
        ErrorDisposition.notify,
      );
      // The disposed matcher is exact, not contains(): a message merely
      // embedding the text is some other failure quoting it.
      expect(
        dispositionFor(ExtensionHostException('wrapped: extension host disposed')),
        ErrorDisposition.notify,
      );
    });

    test('a foreign exception quoting the message is NOT swallowed', () {
      // Only the host's own exception type is exempt; matching by message
      // alone would let a wrapper of ours ride along.
      expect(dispositionFor(StateError('extension host disposed')), ErrorDisposition.notify);
      expect(dispositionFor(StateError('extension runtime is dead')), ErrorDisposition.notify);
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
        dispositionFor(WindowsWebViewUnavailable(
          PlatformException(code: '0', message: 'Cannot create WebViewEnvironment: Access is denied.'),
        )),
        ErrorDisposition.report,
      );
      expect(
        dispositionFor(const WindowsWebViewUnavailable(FileSystemException('Creation failed', r'C:\ProgramData'))),
        ErrorDisposition.report,
      );
      // The browser process never came up; indistinguishable to the operator
      // from a refusal, and handled the same way.
      expect(
        dispositionFor(WindowsWebViewUnavailable(TimeoutException('webview environment', const Duration(seconds: 30)))),
        ErrorDisposition.report,
      );
    });

    test('our own build being broken is still loud', () {
      // The cause is inspected rather than the wrapper alone because this is
      // the one failure that is OURS: a Windows build shipped without the
      // plugin registered fails for every user on every machine, and must not
      // hide inside a rule written for one operator's PC.
      expect(
        dispositionFor(WindowsWebViewUnavailable(MissingPluginException('no implementation found'))),
        ErrorDisposition.notify,
      );
      expect(dispositionFor(WindowsWebViewUnavailable(TypeError())), ErrorDisposition.notify);
    });

    test('the same platform failure outside the webview is still loud', () {
      // The wrapper IS the rule's scope. A PlatformException reaching the
      // policy from anywhere else has no webview to blame.
      expect(
        dispositionFor(PlatformException(code: '0', message: 'Cannot create WebViewEnvironment: Access is denied.')),
        ErrorDisposition.notify,
      );
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
        dispositionFor(const CatConnectFailure(
          'flexradio',
          SocketException('Connection failed (OS Error: No route to host, errno = 65), '
              'address = 10.0.0.66, port = 4992'),
        )),
        ErrorDisposition.logOnly,
      );
      expect(
        dispositionFor(CatConnectFailure('icom-network', TimeoutException('the radio did not answer: login'))),
        ErrorDisposition.logOnly,
      );
      // A transport's own account of the same thing, tagged CatUnreachable.
      expect(
        dispositionFor(const CatConnectFailure('ft891', SerialPortUnavailable('/dev/cu.usbserial', 'busy'))),
        ErrorDisposition.logOnly,
      );
      expect(
        dispositionFor(const CatConnectFailure('icom-network', IcomLoginTimeout())),
        ErrorDisposition.logOnly,
      );
    });

    test('a bug raised inside a connect attempt is still loud', () {
      // The reason the cause is inspected at all rather than the rule
      // matching every failed connect: our own code runs inside that try —
      // a bad config cast, a handshake step that gets its state wrong — and
      // those are bugs the rule must not take down with the radio.
      expect(dispositionFor(CatConnectFailure('flexradio', TypeError())), ErrorDisposition.notify);
      expect(
        dispositionFor(CatConnectFailure('icom-network', StateError('the radio sent a stream answer we do not understand'))),
        ErrorDisposition.notify,
      );
    });

    test('the same socket failure outside a connect attempt is still loud', () {
      // The wrapper IS the rule's scope. A SocketException reaching the
      // policy from anywhere else in the app has no radio to blame.
      expect(
        dispositionFor(const SocketException('Connection failed (OS Error: No route to host, errno = 65), '
            'address = 10.0.0.66, port = 4992')),
        ErrorDisposition.notify,
      );
    });
  });

  group('fetch transport transience', () {
    // A ClientException or TimeoutException from _hostFetch's own send()
    // call stringifies through the kernel into an ExtensionHostException
    // with that exception's toString() as its message — the caller (e.g.
    // SyncEngine's backoff loop) already retries, so this is worth
    // uploading in aggregate but not worth an operator notice.
    test('a connection reset is reported, not noticed', () {
      expect(
        dispositionFor(ExtensionHostException('ClientException: Connection reset by peer, uri=https://lofi.ham2k.net/v1/sync')),
        ErrorDisposition.report,
      );
    });

    test('other transport-layer failures are reported too', () {
      expect(
        dispositionFor(ExtensionHostException('ClientException: Connection refused, uri=https://lofi.ham2k.net/v1/sync')),
        ErrorDisposition.report,
      );
      expect(
        dispositionFor(ExtensionHostException('ClientException: Connection closed while receiving data, uri=https://lofi.ham2k.net/v1/sync')),
        ErrorDisposition.report,
      );
      expect(
        dispositionFor(ExtensionHostException('TimeoutException after 0:00:15.000000: Future not completed')),
        ErrorDisposition.report,
      );
    });

    test('a DNS lookup failure wrapped by http.IOClient is reported, not noticed', () {
      // http's IOClient wraps a socket-layer failure in its OWN subclass,
      // whose toString() reads "ClientException with $cause, ..." rather
      // than plain ClientException's "ClientException: $message" — a
      // format the prefix check must match too, or every DNS blip on a
      // captive portal or dead WiFi notifies the operator.
      expect(
        dispositionFor(ExtensionHostException("ClientException with SocketException: Failed host lookup: "
            "'lofi.ham2k.net' (OS Error: No address associated with hostname, errno = 7), "
            "uri=https://lofi.ham2k.net/v1/sync")),
        ErrorDisposition.report,
      );
    });

    test('a hook call timing out on its own is NOT swallowed', () {
      // Distinct from _hostFetch's transport timeout: a hook that simply
      // takes too long (spots.fetchSpots, say) throws its own message,
      // which does not start with "TimeoutException" — that's a real
      // extension-side hang, not TCP flakiness.
      expect(
        dispositionFor(ExtensionHostException('hook spots.fetchSpots timed out after 5000ms')),
        ErrorDisposition.notify,
      );
    });

    test('a foreign exception quoting the message is NOT swallowed', () {
      // Only the host's own exception type is exempt.
      expect(
        dispositionFor(StateError('ClientException: Connection reset by peer, uri=https://lofi.ham2k.net/v1/sync')),
        ErrorDisposition.notify,
      );
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
      final decision = ErrorPolicy.decide(ExtensionHostException(
        'LoFi sync failed and the backup capture also failed: LoFi request failed: HTTP 503 '
        '(capture error: backup capture returned HTTP 500)',
      ));
      expect(decision.rule?.id, 'lofi-backup-capture-also-failed');
      expect(decision.disposition, ErrorDisposition.notify);
    });

    test('an ordinary LoFi failure is NOT claimed by this rule', () {
      final decision = ErrorPolicy.decide(ExtensionHostException('LoFi request failed: HTTP 503'));
      expect(decision.rule, isNull);
      expect(decision.disposition, ErrorDisposition.notify);
    });
  });

  group('http client connection transience', () {
    // DataFileManager talks to package:http directly rather than through
    // hostFetch, so its connection failures reach the policy as a raw
    // ClientException, not an ExtensionHostException — a different rule
    // from fetch-transport-transient, matched on type alone since
    // ClientException has no other cause.
    test('a connection failure is reported, not noticed', () {
      expect(
        dispositionFor(ClientException('Connection reset by peer')),
        ErrorDisposition.report,
      );
    });

    test('a bare TimeoutException is NOT swallowed', () {
      // Deliberately excluded: _fetchAndDecode's headers/body timeouts throw
      // this bare, and it still has to reach friendlyDownloadError's own
      // translated message and downloadFile's CORS-preflight retry, both of
      // which only trigger on ClientException. TimeoutException is also too
      // generic a type to match on its own app-wide — see the sibling test
      // in the fetch-transport-transience group.
      expect(
        dispositionFor(TimeoutException('the radio did not answer: pkt4')),
        ErrorDisposition.notify,
      );
    });
  });

  group('malformed spot data', () {
    // The actual disposition check for extension_service.dart's validSpots():
    // hook_partition_test.dart only proves the STATUS BAR stayed empty, which
    // it always does on this path (report() never calls notify() — see
    // error_reporting_test.dart) regardless of which tier the rule assigns.
    // Reading the decision straight off ErrorPolicy is what actually catches
    // the rule being loosened to `notify` by accident.
    test('reported, not noticed — the operator cannot fix another extension\'s bug', () {
      expect(
        dispositionFor(MalformedSpotDataException('wwff', 'freq', '14285.0')),
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
      expect(
        dispositionFor(ScoringHookFailure('core', 'scoreCandidates', TimeoutException('hook timed out'))),
        ErrorDisposition.report,
      );
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
        context: ErrorDescription(
          'while dispatching notifications for WidgetsBindingObserver.didChangeViewFocus',
        ),
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
    final closed = StateError('This database or transaction runner has already been closed and may '
        'not be used anymore.');
    final remote = StateError('Tried to send Request (id = 18): StatementMethod.select: SELECT 1 '
        'with [] over isolate channel, but the connection was closed!');

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
}
