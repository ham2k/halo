// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Transports open connections and move bytes. They know nothing about what
// those bytes mean — that's a driver's job (see driver.dart, and the
// transport/driver split in docs/design/cat.md).

import 'dart:async';
import 'dart:typed_data';

/// Cancels an in-flight [EquipmentTransport.connect].
///
/// Dart has no `AbortController`, and `Socket.connect(..., timeout:)`
/// returns a future that can't be cancelled — so without an explicit token
/// a superseded attempt holds its socket for the whole handshake timeout.
/// app-polo's note on why that's not merely untidy: "some radios don't take
/// kindly to two overlapping connection attempts hitting them at once."
///
/// This is in `connect`'s signature from the first commit on purpose;
/// retrofitting it across every transport is what cost polo a hardening pass.
class CatCancelToken {
  final _completer = Completer<void>();

  bool get isCancelled => _completer.isCompleted;

  /// Completes when [cancel] is called, never with an error. Transports
  /// race this against their connect.
  Future<void> get whenCancelled => _completer.future;

  void cancel() {
    if (!_completer.isCompleted) _completer.complete();
  }
}

/// Thrown when an attempt is cancelled — by a newer connect, or by a
/// disconnect. Callers treat it as a clean exit, not a failure worth
/// reporting to the user.
class CatCancelledException implements Exception {
  const CatCancelledException();

  @override
  String toString() => 'Superseded by a newer connection attempt';
}

/// Marks a [EquipmentTransport.connect] failure that is about the equipment
/// rather than about this app: a rig switched off, a port another program
/// holds, a login the rig refuses. A transport must NOT use it for a failure
/// it cannot explain — `ErrorPolicy`'s `cat-equipment-unreachable` rule keeps
/// these out of the crash backend and off the operator's screen, so anything
/// tagged with it is silent by design.
abstract class CatUnreachable implements Exception {}

/// Why a serial port could not be opened, as far as the transport can tell.
///
/// Declared here rather than beside either transport because the two —
/// `serial_transport_io.dart` and `serial_transport_web.dart` — never compile
/// into the same binary, and [CatService] has to classify a failure from
/// whichever one it got. A shared type is what lets it do that with an `is`
/// test instead of matching a class name.
enum SerialFailure {
  /// Nothing is at that port: unplugged since it was picked, or a path that
  /// named something else entirely.
  missing,

  /// Another program holds it — WSJT-X, fldigi and rigctld are the usual
  /// three, and the one an operator is least likely to guess at.
  busy,

  /// The OS refused: a macOS sandbox without the `device.serial`
  /// entitlement, a Web Serial grant revoked, a Linux user outside `dialout`.
  denied,

  /// Anything the transport could not place. Keeps its own words rather than
  /// being translated into a guess.
  other,
}

/// A serial open that failed, with [failure] saying which of the causes it
/// was — see [SerialFailure]. Implemented by both serial transports.
abstract class SerialPortProblem implements CatUnreachable {
  SerialFailure get failure;
}

/// A failed connect, tagged with the equipment type it was aimed at.
///
/// [CatService] wraps every throw out of [EquipmentTransport.connect] in this
/// before reporting it, because provenance is what `ErrorPolicy` needs to
/// tell a rig that is switched off — a SocketException, retried on a loop for
/// as long as the app runs — from the same exception type escaping anywhere
/// else in the app. Only the report is wrapped: the equipment row still shows
/// the underlying failure's own words.
class CatConnectFailure implements Exception {
  final String typeKey;
  final Object cause;

  const CatConnectFailure(this.typeKey, this.cause);

  @override
  String toString() => 'Connecting to $typeKey failed: $cause';
}

/// What handling a `type: 'action'` element (see [EquipmentTransport.runAction])
/// can produce. Deliberately not `halo_widgets`' own `FormActionResult` —
/// this layer speaks CAT/config, not the UI package, the same way
/// [EquipmentTransport.configElements] returns plain maps shaped for
/// FormRenderer without importing it. The UI layer translates.
class EquipmentActionResult {
  final String? message;
  final Map<String, dynamic>? fieldUpdates;

  const EquipmentActionResult({this.message, this.fieldUpdates});
}

/// A live byte pipe to one piece of equipment.
abstract class EquipmentConnection {
  /// Raw chunks as they arrive. NOT framed — a driver must handle a frame
  /// split across two chunks itself.
  Stream<Uint8List> get data;

  /// Completes when the connection is gone, for any reason.
  Future<void> get closed;

  /// Writes bytes. Never throws: drivers call this from unguarded timers,
  /// and a write to an already-dead socket must not blow up inside a timer
  /// callback. [closed] is what tells anyone the connection is gone.
  void send(List<int> bytes);

  Future<void> close();
}

abstract class EquipmentTransport {
  const EquipmentTransport();

  /// Stable id referenced by [EquipmentType.transportKey], e.g. `tcp`.
  String get key;

  /// False for a transport whose [connect] throws unconditionally on this
  /// platform — the TCP and Icom-network stubs on web, which have no raw
  /// sockets. True by default; only a platform stub overrides it. Used to
  /// keep the equipment list from offering (or discovery from probing for)
  /// a radio the operator could never actually connect.
  bool get isSupportedOnThisPlatform => true;

  /// Opens a connection to [target] — this transport's own [targetFor]
  /// output.
  ///
  /// Throws [CatCancelledException] if [cancel] fires first; any other
  /// throw is a real connection failure. A raw `SocketException` or
  /// `TimeoutException` is understood as the equipment's own doing; tag
  /// anything else it caused with [CatUnreachable]. Untagged, a failure is
  /// treated as a bug of ours and reported as such.
  Future<EquipmentConnection> connect(Map<String, dynamic> target, {required CatCancelToken cancel});

  /// Config keys whose values are credentials, kept in the platform
  /// keychain instead of the plain config blob. Empty for a transport that
  /// needs none — most do.
  Set<String> get secretFields => const {};

  /// Async prep [configElements] may need before it can render — no-op by
  /// default. [configElements] itself stays synchronous (every existing
  /// caller relies on that), so a transport whose fields depend on
  /// something async — the web serial transport's already-granted device
  /// list, fetched via `navigator.serial.getPorts()` — does that fetch
  /// here and caches it, rather than [configElements] returning a
  /// `Future` and rippling that through every transport, driver, and the
  /// registry self-check.
  Future<void> prepareConfigElements() async {}

  /// FormRenderer elements for this transport's own connection parameters
  /// (host, port, serial port picker, baud rate…). Nothing device-specific
  /// — that's [EquipmentDriver.configElements].
  ///
  /// [overrides] and [restrictions] come from the equipment definition,
  /// keyed by field key. A key this transport doesn't recognize is
  /// silently ignored — it belongs to the driver instead. [overrides]
  /// means "hardcode this value and don't show the field at all";
  /// [restrictions] means "narrow what the field would otherwise offer"
  /// (e.g. a subset of baud rates). Prefill defaults aren't a parameter
  /// here — [EquipmentType.defaultConfig] feeds the form's initial state
  /// directly, without either owner needing to know about it.
  List<Map<String, dynamic>> configElements({Map<String, dynamic> overrides = const {}, Map<String, dynamic> restrictions = const {}}) => const [];

  /// Per-field version, for the editor. Null for a key this transport
  /// doesn't own.
  String? validateField(String key, dynamic value, Map<String, dynamic> config) => null;

  /// Every config key this transport reads, whether or not it shows a
  /// field for it. Defaults to exactly the keys [configElements] declares
  /// as fields — override this too if a key is read straight out of the
  /// config (never shown, never optional) rather than collected through a
  /// field, so a typo'd [EquipmentType.overrides]/`restrictions` key still
  /// gets caught instead of silently doing nothing.
  Set<String> get recognizedConfigKeys => configElements().where((e) => e['type'] == 'field').map((e) => e['key'] as String).toSet();

  /// Turns the merged config (submitted values plus the definition's
  /// [EquipmentType.overrides]) into what [connect] needs. Identity by
  /// default — a transport with nothing to reshape just uses the config
  /// as-is.
  Map<String, dynamic> targetFor(Map<String, dynamic> config) => config;

  /// True when the field that says where the device is — a serial port, a
  /// host — is blank. An operator may add a radio before they have the cable
  /// or the address, so the editor saves it without one and the connection
  /// layer leaves it alone rather than failing at it on every retry.
  bool isUnconfigured(Map<String, dynamic> config) => false;

  /// A one-line "where is it" fragment for the equipment list — e.g.
  /// `192.168.1.5:4992` or `/dev/cu.usbserial @ 4800`. Empty by default.
  String describeTarget(Map<String, dynamic> config) => '';

  /// Handles a `type: 'action'` element this transport declared in
  /// [configElements] — e.g. the web serial transport's "add a USB
  /// device" button. That can't be a plain field: authorizing a new
  /// device needs a direct user gesture and opens the browser's own
  /// native picker, not something a declarative field can drive. Null
  /// (the default) for a transport with no actions of its own, or for a
  /// key this transport didn't declare.
  Future<EquipmentActionResult?> runAction(String actionKey, String method, Map<String, dynamic> state) async => null;
}
