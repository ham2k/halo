// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The Dart end of screen capture (HALO-369) — the producer half of the
// `remote` experiment. Everything real happens natively; this is the seam,
// and the place where "this platform cannot do it" is a plain answer rather
// than an exception nobody catches.
//
// macOS is the only producer today (macos/Runner/ScreenCaptureChannel.swift).
// Windows follows via Windows.Graphics.Capture; Linux is out (the app ships
// as an AppImage and window-level picking does not exist on wlroots), and
// iOS/Android would each need a second app target. Every platform with a
// peer link can still VIEW — see RemoteScreenPanel.
//
// Frames arrive already packed as PeerScreenFrame wire bytes, so a producer
// forwards the buffer it is handed straight to a viewer's media link without
// unpacking and repacking it ten times a second.

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:halo_core/halo_core.dart';

/// Whether this device may capture, and if not, why not — so the settings
/// panel can say which of the three it is instead of showing an empty list.
enum ScreenCaptureAvailability {
  /// This platform has no capture implementation.
  unsupportedPlatform,

  /// The platform has one, but this OS version is too old for it.
  unsupportedVersion,

  available,
}

/// Whether the OS will let this app see other windows.
enum ScreenCapturePermission {
  granted,

  /// Not granted — which covers both "never asked" and "refused", because
  /// macOS does not distinguish them to the app.
  denied,
}

/// A capture that ended without being asked to. Carries the OS's own words:
/// the operator revoking Screen Recording and the shared window closing both
/// arrive this way, and a viewer staring at a frozen pane cannot tell either
/// of them from a slow network.
class ScreenCaptureStopped {
  final String sourceId;
  final String reason;

  const ScreenCaptureStopped(this.sourceId, this.reason);
}

class ScreenCaptureException implements Exception {
  final String message;

  /// The native side's code — `unsupported`, `timeout`, `unavailable`,
  /// `capture`, `arguments`.
  final String? code;

  const ScreenCaptureException(this.message, {this.code});

  @override
  String toString() => 'ScreenCaptureException($code): $message';
}

class ScreenCaptureService {
  static const _methods = MethodChannel('ham2k/screen_capture');

  /// Binary codec, not the standard one: the native side hands over packed
  /// frame bytes and nothing here needs them turned into a Dart map first.
  static const _frames = BasicMessageChannel<ByteData?>(
    'ham2k/screen_capture/frames',
    BinaryCodec(),
  );

  ScreenCaptureService() {
    if (!isSupportedPlatform) return;
    _frames.setMessageHandler((message) async {
      if (message == null || _frameController.isClosed) return null;
      _frameController.add(message.buffer.asUint8List(
        message.offsetInBytes,
        message.lengthInBytes,
      ));
      return null;
    });
    _methods.setMethodCallHandler((call) async {
      if (call.method == 'captureStopped') {
        final args = (call.arguments as Map?)?.cast<String, dynamic>() ?? const {};
        final id = args['id'];
        if (id is String && id.isNotEmpty && !_stoppedController.isClosed) {
          _stoppedController.add(ScreenCaptureStopped(
            id,
            (args['reason'] as String?) ?? 'The capture ended',
          ));
        }
      }
      return null;
    });
  }

  final _frameController = StreamController<Uint8List>.broadcast();
  final _stoppedController = StreamController<ScreenCaptureStopped>.broadcast();

  /// Packed [PeerScreenFrame] bytes, one event per captured frame, for every
  /// source currently running. A consumer that only wants one source reads
  /// [PeerScreenFrame.sourceIdOf] rather than decoding.
  Stream<Uint8List> get frames => _frameController.stream;

  Stream<ScreenCaptureStopped> get stopped => _stoppedController.stream;

  /// Whether a capture implementation exists for this platform at all.
  /// Const-foldable and safe to call anywhere, unlike [availability], which
  /// asks the OS.
  static bool get isSupportedPlatform => !kIsWeb && defaultTargetPlatform == TargetPlatform.macOS;

  Future<ScreenCaptureAvailability> availability() async {
    if (!isSupportedPlatform) return ScreenCaptureAvailability.unsupportedPlatform;
    final available = await _invoke<bool>('available') ?? false;
    return available
        ? ScreenCaptureAvailability.available
        : ScreenCaptureAvailability.unsupportedVersion;
  }

  /// What the OS says right now.
  ///
  /// macOS caches this answer for the life of the PROCESS: once it has said
  /// denied it keeps saying denied, even after the operator grants the
  /// permission in System Settings. Polling therefore never observes the
  /// change — the UI must tell the operator to relaunch, not offer a Retry
  /// that cannot work.
  Future<ScreenCapturePermission> permission() async {
    if (!isSupportedPlatform) return ScreenCapturePermission.denied;
    final state = await _invoke<String>('permission');
    return state == 'granted' ? ScreenCapturePermission.granted : ScreenCapturePermission.denied;
  }

  /// Asks the OS to prompt. Returns the permission as it stood BEFORE the
  /// prompt — the dialog is drawn by another process and outlives this call,
  /// so a false here means "was not granted", never "the operator said no".
  Future<void> requestPermission() async {
    if (!isSupportedPlatform) return;
    await _invoke<bool>('requestPermission');
  }

  /// Everything this device could offer. Throws [ScreenCaptureException] on
  /// a missing permission or on the enumeration timing out, so the caller
  /// can distinguish those from an honestly empty machine.
  Future<List<PeerScreenSource>> listSources() async {
    if (!isSupportedPlatform) return const [];
    final raw = await _invoke<List<Object?>>('listSources') ?? const [];
    return [
      for (final entry in raw) ?PeerScreenSource.from(entry),
    ];
  }

  /// Starts (or restarts, at new terms) one source. Restarting is how a
  /// viewer changes size or rate, so this is deliberately idempotent on
  /// [sourceId] rather than refusing a second call.
  Future<void> start(
    String sourceId, {
    int maxWidth = 1280,
    int fps = 10,
    double quality = 0.6,
  }) async {
    if (!isSupportedPlatform) {
      throw const ScreenCaptureException('This device cannot share its screen', code: 'unsupported');
    }
    await _invoke<void>('start', {
      'id': sourceId,
      'maxWidth': maxWidth,
      'fps': fps,
      'quality': quality,
    });
  }

  /// One still of [sourceId], JPEG, or null when it cannot be had — the
  /// window closed, the OS did not answer in time, or this platform has no
  /// capture at all. Null rather than a throw: the picker draws a tile
  /// without a picture, which is a better answer than a dialog of errors.
  Future<Uint8List?> thumbnail(String sourceId, {int maxWidth = 320}) async {
    if (!isSupportedPlatform) return null;
    try {
      return await _invoke<Uint8List>('thumbnail', {'id': sourceId, 'maxWidth': maxWidth});
    } on ScreenCaptureException {
      return null;
    }
  }

  Future<void> stop(String sourceId) async {
    if (!isSupportedPlatform) return;
    await _invoke<void>('stop', {'id': sourceId});
  }

  Future<void> stopAll() async {
    if (!isSupportedPlatform) return;
    await _invoke<void>('stopAll');
  }

  Future<void> dispose() async {
    await stopAll();
    await _frameController.close();
    await _stoppedController.close();
  }

  /// One place where a platform-channel failure becomes a typed one.
  ///
  /// `MissingPluginException` is folded in with the rest deliberately: it is
  /// what a build whose runner predates this channel answers, which for the
  /// caller is the same fact as an old macOS — this device cannot capture.
  Future<T?> _invoke<T>(String method, [Map<String, dynamic>? arguments]) async {
    try {
      return await _methods.invokeMethod<T>(method, arguments);
    } on PlatformException catch (e) {
      throw ScreenCaptureException(e.message ?? 'Screen capture failed', code: e.code);
    } on MissingPluginException {
      throw const ScreenCaptureException(
        'This build cannot share its screen',
        code: 'unsupported',
      );
    }
  }
}
