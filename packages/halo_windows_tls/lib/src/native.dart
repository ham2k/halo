// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The Windows call behind recovery.dart, through FFI. It blocks, so callers
// run it off their isolate.
//
// Windows does not ship every root certificate up front. It downloads one
// the first time something on the machine asks Windows to verify a chain
// that ends there. Dart verifies with its own BoringSSL against a copy of
// the stores it takes when a SecurityContext is created, so it never asks
// Windows, and a root nothing else on the machine has needed stays missing.
// The usual hand-run workaround (PowerShell's Invoke-WebRequest to the host)
// works because .NET does ask Windows; [chainWindowsVerifies] does the same
// from here, without starting a process.

import 'dart:ffi';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';

typedef _WinHttpOpenNative = Pointer<Void> Function(Pointer<Utf16> agent, Uint32 accessType, Pointer<Utf16> proxy, Pointer<Utf16> bypass, Uint32 flags);
typedef _WinHttpOpen = Pointer<Void> Function(Pointer<Utf16> agent, int accessType, Pointer<Utf16> proxy, Pointer<Utf16> bypass, int flags);
typedef _WinHttpConnectNative = Pointer<Void> Function(Pointer<Void> session, Pointer<Utf16> server, Uint16 port, Uint32 reserved);
typedef _WinHttpConnect = Pointer<Void> Function(Pointer<Void> session, Pointer<Utf16> server, int port, int reserved);
typedef _WinHttpOpenRequestNative =
    Pointer<Void> Function(
      Pointer<Void> connect,
      Pointer<Utf16> verb,
      Pointer<Utf16> objectName,
      Pointer<Utf16> version,
      Pointer<Utf16> referrer,
      Pointer<Pointer<Utf16>> acceptTypes,
      Uint32 flags,
    );
typedef _WinHttpOpenRequest =
    Pointer<Void> Function(
      Pointer<Void> connect,
      Pointer<Utf16> verb,
      Pointer<Utf16> objectName,
      Pointer<Utf16> version,
      Pointer<Utf16> referrer,
      Pointer<Pointer<Utf16>> acceptTypes,
      int flags,
    );
typedef _WinHttpSetTimeoutsNative = Int32 Function(Pointer<Void> handle, Int32 resolve, Int32 connect, Int32 send, Int32 receive);
typedef _WinHttpSetTimeouts = int Function(Pointer<Void> handle, int resolve, int connect, int send, int receive);
typedef _WinHttpSendRequestNative =
    Int32 Function(
      Pointer<Void> request,
      Pointer<Utf16> headers,
      Uint32 headersLength,
      Pointer<Void> optional,
      Uint32 optionalLength,
      Uint32 totalLength,
      UintPtr context,
    );
typedef _WinHttpSendRequest =
    int Function(Pointer<Void> request, Pointer<Utf16> headers, int headersLength, Pointer<Void> optional, int optionalLength, int totalLength, int context);
typedef _WinHttpQueryOptionNative = Int32 Function(Pointer<Void> handle, Uint32 option, Pointer<Void> buffer, Pointer<Uint32> bufferLength);
typedef _WinHttpQueryOption = int Function(Pointer<Void> handle, int option, Pointer<Void> buffer, Pointer<Uint32> bufferLength);
typedef _WinHttpCloseHandleNative = Int32 Function(Pointer<Void> handle);
typedef _WinHttpCloseHandle = int Function(Pointer<Void> handle);
typedef _CertFreeCertificateChainNative = Void Function(Pointer<_CertChainContext> chain);
typedef _CertFreeCertificateChain = void Function(Pointer<_CertChainContext> chain);
typedef _GetLastErrorNative = Uint32 Function();
typedef _GetLastError = int Function();

const _winHttpAccessTypeAutomaticProxy = 4;
const _winHttpFlagSecure = 0x00800000;
const _winHttpOptionServerCertChainContext = 147;
const _timeoutMs = 5000;

/// Windows' own request to a server went no further than [call], which
/// left [code] (a Win32 or WinHTTP error; 12175 when Windows refused the
/// server's certificate itself).
///
/// [code] is read once the call has returned to Dart, and the VM may have
/// set the thread's last error again on the way: it says where to look in a
/// report, and nothing branches on it.
class WindowsRequestFailed implements Exception {
  WindowsRequestFailed(this.call, this.code);

  final String call;
  final int code;

  @override
  String toString() => 'WindowsRequestFailed: $call failed with error $code';
}

final class _CertContext extends Struct {
  @Uint32()
  external int dwCertEncodingType;
  external Pointer<Uint8> pbCertEncoded;
  @Uint32()
  external int cbCertEncoded;
  external Pointer<Void> pCertInfo;
  external Pointer<Void> hCertStore;
}

final class _CertChainElement extends Struct {
  @Uint32()
  external int cbSize;
  external Pointer<_CertContext> pCertContext;
}

final class _CertSimpleChain extends Struct {
  @Uint32()
  external int cbSize;
  @Uint32()
  external int dwErrorStatus;
  @Uint32()
  external int dwInfoStatus;
  @Uint32()
  external int cElement;
  external Pointer<Pointer<_CertChainElement>> rgpElement;
}

final class _CertChainContext extends Struct {
  @Uint32()
  external int cbSize;
  @Uint32()
  external int dwErrorStatus;
  @Uint32()
  external int dwInfoStatus;
  @Uint32()
  external int cChain;
  external Pointer<Pointer<_CertSimpleChain>> rgpChain;
}

/// The DER bytes of the chain Windows verified [host]:[port]'s certificate
/// with: every certificate but the server's own, its root last.
///
/// One HEAD request through WinHTTP has Windows verify the server's chain,
/// downloading a missing root on the way, and a missing intermediate too when
/// the server leaves one out. A request that went through means Windows
/// accepted the chain for a TLS server with this name — its usage
/// restrictions and the certificates it has disallowed included — so these
/// are exactly the certificates this host needs, and nothing Windows would
/// not trust for it is taken on. The HTTP answer itself does not matter: a
/// server that answers HEAD with an error has still passed the handshake.
///
/// Throws [WindowsRequestFailed] when the request does not get that far,
/// Windows refusing the server too among the reasons, and an ArgumentError
/// when a DLL or a symbol cannot be resolved.
List<Uint8List> chainWindowsVerifies(String host, int port, String userAgent) {
  final winhttp = DynamicLibrary.open('winhttp.dll');
  final crypt32 = DynamicLibrary.open('crypt32.dll');
  final open = winhttp.lookupFunction<_WinHttpOpenNative, _WinHttpOpen>('WinHttpOpen');
  final connect = winhttp.lookupFunction<_WinHttpConnectNative, _WinHttpConnect>('WinHttpConnect');
  final openRequest = winhttp.lookupFunction<_WinHttpOpenRequestNative, _WinHttpOpenRequest>('WinHttpOpenRequest');
  final setTimeouts = winhttp.lookupFunction<_WinHttpSetTimeoutsNative, _WinHttpSetTimeouts>('WinHttpSetTimeouts');
  final sendRequest = winhttp.lookupFunction<_WinHttpSendRequestNative, _WinHttpSendRequest>('WinHttpSendRequest');
  final queryOption = winhttp.lookupFunction<_WinHttpQueryOptionNative, _WinHttpQueryOption>('WinHttpQueryOption');
  final close = winhttp.lookupFunction<_WinHttpCloseHandleNative, _WinHttpCloseHandle>('WinHttpCloseHandle');
  final freeChain = crypt32.lookupFunction<_CertFreeCertificateChainNative, _CertFreeCertificateChain>('CertFreeCertificateChain');
  final lastError = DynamicLibrary.open('kernel32.dll').lookupFunction<_GetLastErrorNative, _GetLastError>('GetLastError', isLeaf: true);
  Never fail(String call) => throw WindowsRequestFailed(call, lastError());

  return using((arena) {
    final session = open(userAgent.toNativeUtf16(allocator: arena), _winHttpAccessTypeAutomaticProxy, nullptr, nullptr, 0);
    if (session == nullptr) fail('WinHttpOpen');
    try {
      setTimeouts(session, _timeoutMs, _timeoutMs, _timeoutMs, _timeoutMs);
      final connection = connect(session, host.toNativeUtf16(allocator: arena), port, 0);
      if (connection == nullptr) fail('WinHttpConnect');
      try {
        final request = openRequest(
          connection,
          'HEAD'.toNativeUtf16(allocator: arena),
          '/'.toNativeUtf16(allocator: arena),
          nullptr,
          nullptr,
          nullptr,
          _winHttpFlagSecure,
        );
        if (request == nullptr) fail('WinHttpOpenRequest');
        try {
          // Fails, among other reasons, when Windows refuses the chain.
          if (sendRequest(request, nullptr, 0, nullptr, 0, 0, 0) == 0) fail('WinHttpSendRequest');

          final slot = arena<Pointer<_CertChainContext>>();
          final length = arena<Uint32>()..value = sizeOf<Pointer<_CertChainContext>>();
          if (queryOption(request, _winHttpOptionServerCertChainContext, slot.cast(), length) == 0) fail('WinHttpQueryOption');
          final chain = slot.value;
          if (chain == nullptr) throw WindowsRequestFailed('WinHttpQueryOption', 0);
          try {
            return _issuersOf(chain.ref);
          } finally {
            freeChain(chain);
          }
        } finally {
          close(request);
        }
      } finally {
        close(connection);
      }
    } finally {
      close(session);
    }
  });
}

/// Every certificate in [chain] but the server's own, which comes first.
/// The final simple chain ends with the root Windows anchored it on.
List<Uint8List> _issuersOf(_CertChainContext chain) {
  final issuers = <Uint8List>[];
  for (var c = 0; c < chain.cChain; c++) {
    final simple = chain.rgpChain[c].ref;
    for (var e = c == 0 ? 1 : 0; e < simple.cElement; e++) {
      final cert = simple.rgpElement[e].ref.pCertContext;
      if (cert != nullptr) issuers.add(Uint8List.fromList(cert.ref.pbCertEncoded.asTypedList(cert.ref.cbCertEncoded)));
    }
  }
  return issuers;
}
