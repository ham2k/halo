// Copyright ©️ 2026 Robert Jackson <me@rwjblue.com>
// SPDX-License-Identifier: MPL-2.0
@DefaultAsset('package:halo_tls_psk/src/native_tls.dart')
library;

import 'dart:ffi';
import 'dart:typed_data';
import 'package:ffi/ffi.dart';
import 'errors.dart';

const tlsChunkSize = 16384;
const tlsWantRead = -1;
const tlsWantWrite = -2;
const tlsPeerClosed = -3;

typedef _CreateNative = Pointer<Void> Function(Pointer<Uint8>, Size, Pointer<Uint8>, Size);
typedef _FreeNative = Void Function(Pointer<Void>);
typedef _BufferNative = Int32 Function(Pointer<Void>, Pointer<Uint8>, Size);
typedef _StateNative = Int32 Function(Pointer<Void>);

@Native<_CreateNative>(symbol: 'halo_tls_new')
external Pointer<Void> _create(Pointer<Uint8> psk, int pskLength, Pointer<Uint8> identity, int identityLength);

@Native<_FreeNative>(symbol: 'halo_tls_free')
external void _free(Pointer<Void> handle);

@Native<_BufferNative>(symbol: 'halo_tls_feed')
external int _feed(Pointer<Void> handle, Pointer<Uint8> bytes, int length);

@Native<_BufferNative>(symbol: 'halo_tls_drain')
external int _drain(Pointer<Void> handle, Pointer<Uint8> bytes, int length);

@Native<_BufferNative>(symbol: 'halo_tls_read')
external int _read(Pointer<Void> handle, Pointer<Uint8> bytes, int length);

@Native<_BufferNative>(symbol: 'halo_tls_write')
external int _write(Pointer<Void> handle, Pointer<Uint8> bytes, int length);

@Native<_StateNative>(symbol: 'halo_tls_handshake')
external int _handshake(Pointer<Void> handle);

@Native<_StateNative>(symbol: 'halo_tls_close_notify')
external int _closeNotify(Pointer<Void> handle);

// Symbol resolution is lazy, so importing replay code does not load TLS.
final _handleFinalizer = _loadHandleFinalizer();
NativeFinalizer _loadHandleFinalizer() {
  try {
    // Resolve the entire ABI here so a missing/stale library produces the same
    // safe error as an unavailable one, before any native state is allocated.
    final freePointer = Native.addressOf<NativeFunction<_FreeNative>>(_free);
    final _ = (
      Native.addressOf<NativeFunction<_CreateNative>>(_create),
      Native.addressOf<NativeFunction<_BufferNative>>(_feed),
      Native.addressOf<NativeFunction<_BufferNative>>(_drain),
      Native.addressOf<NativeFunction<_BufferNative>>(_read),
      Native.addressOf<NativeFunction<_BufferNative>>(_write),
      Native.addressOf<NativeFunction<_StateNative>>(_handshake),
      Native.addressOf<NativeFunction<_StateNative>>(_closeNotify),
    );
    return NativeFinalizer(freePointer);
  } on ArgumentError {
    throw const PskTlsException('nativeUnavailable');
  }
}

/// Owns one native TLS state. Calls only perform bounded memory/crypto work;
/// socket I/O belongs to Dart, never a blocking native recv or send.
class NativeTls implements Finalizable {
  static final _scratchFinalizer = NativeFinalizer(calloc.nativeFree);
  final Pointer<Void> _handle;
  final _scratch = calloc<Uint8>(tlsChunkSize);
  bool _disposed = false;

  NativeTls._(this._handle, NativeFinalizer handleFinalizer) {
    handleFinalizer.attach(this, _handle, detach: this);
    _scratchFinalizer.attach(this, _scratch.cast(), detach: this);
  }

  factory NativeTls(Uint8List psk, Uint8List identity) {
    final handleFinalizer = _handleFinalizer;
    final key = calloc<Uint8>(psk.length);
    final id = calloc<Uint8>(identity.isEmpty ? 1 : identity.length);
    try {
      key.asTypedList(psk.length).setAll(0, psk);
      id.asTypedList(identity.length).setAll(0, identity);
      final handle = _create(key, psk.length, id, identity.length);
      if (handle == nullptr) throw const PskTlsException('nativeInitializationFailed');
      return NativeTls._(handle, handleFinalizer);
    } finally {
      key.asTypedList(psk.length).fillRange(0, psk.length, 0);
      id.asTypedList(identity.length).fillRange(0, identity.length, 0);
      calloc.free(key);
      calloc.free(id);
    }
  }

  void _ensureOpen() {
    if (_disposed) throw StateError('NativeTls is disposed');
  }

  void _checkInput(Uint8List bytes) {
    _ensureOpen();
    if (bytes.length > tlsChunkSize) throw RangeError.range(bytes.length, 0, tlsChunkSize, 'bytes.length');
  }

  int handshake() {
    _ensureOpen();
    return _handshake(_handle);
  }

  int closeNotify() {
    _ensureOpen();
    return _closeNotify(_handle);
  }

  int feed(Uint8List bytes) {
    _checkInput(bytes);
    _scratch.asTypedList(bytes.length).setAll(0, bytes);
    return _feed(_handle, _scratch, bytes.length);
  }

  int write(Uint8List bytes) {
    _checkInput(bytes);
    _scratch.asTypedList(bytes.length).setAll(0, bytes);
    return _write(_handle, _scratch, bytes.length);
  }

  Uint8List drain() {
    _ensureOpen();
    final length = _drain(_handle, _scratch, tlsChunkSize);
    return Uint8List.fromList(_scratch.asTypedList(length));
  }

  ({int status, Uint8List? bytes}) read() {
    _ensureOpen();
    final status = _read(_handle, _scratch, tlsChunkSize);
    return (status: status, bytes: status > 0 ? Uint8List.fromList(_scratch.asTypedList(status)) : null);
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _handleFinalizer.detach(this);
    _scratchFinalizer.detach(this);
    _free(_handle);
    _scratch.asTypedList(tlsChunkSize).fillRange(0, tlsChunkSize, 0);
    calloc.free(_scratch);
  }
}
