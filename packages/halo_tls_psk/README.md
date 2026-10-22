# halo_tls_psk

An asynchronous TLS 1.2 client for native Dart and Flutter, authenticated with
a pre-shared key. The app supplies raw key bytes and a UTF-8 identity. This
package has no radio protocol, credential storage, certificate fallback, or
external command dependency at runtime.

The K4 secure connection requires TLS-PSK, which Dart's
[`SecureSocket.connect`](https://api.dart.dev/dart-io/SecureSocket/connect.html)
does not expose. Mbed TLS supplies the TLS and cryptographic implementation;
our C shim exposes eight functions through `dart:ffi`, while Dart handles
asynchronous socket I/O. Building one pinned backend for all five native
targets avoids relying on different system TLS APIs or an installed OpenSSL
executable. Browser builds cannot open this TCP connection.

```dart
import 'dart:convert';
import 'dart:typed_data';
import 'package:halo_tls_psk/halo_tls_psk.dart';

final connection = await PskTlsConnection.connect(
  host: host,
  port: port,
  psk: Uint8List.fromList(utf8.encode(password)),
  identity: '',
  cancelled: cancelSignal,
);
final subscription = connection.data.listen(onBytes, onError: onError);
connection.send(requestBytes);
await connection.close();
await subscription.cancel();
```

`identity` is required, including an explicit empty string for the K4; there
is no default identity inherited from a test peer. `connect` completes only
after the authenticated handshake. Its deadline covers
DNS, TCP connection, and TLS negotiation. Completing `cancelled` cancels only a
pending connection attempt. A late socket is destroyed; after authentication,
the owner controls the connection through `close`.
`data` is a single-subscription stream; listening resumes input, and pausing or
canceling applies backpressure or closes the connection. `closed` always
completes normally; connection errors arrive through `connect` or `data`.
Calling `send` or `close` after closure is harmless. `close` flushes queued
application writes and `close_notify` within a one-second deadline, then frees
all state. Failed connection attempts and buffer overflow abort immediately.

`PskTlsException.code` contains one of `invalidConfiguration`,
`nativeUnavailable`, `nativeInitializationFailed`, `connectFailed`,
`handshakeFailed`, `timeout`, `connectionFailed`, `bufferLimit`, or `cancelled`.
`PskTlsCancelledException` is the cancellation subtype. Messages contain no
host, password, native diagnostic text, or peer-controlled content. A handshake
failure does not identify which of a wrong key, unsupported peer configuration,
or damaged handshake caused it.

## Pinned source and local patch

[`UPSTREAM.json`](UPSTREAM.json) pins Mbed TLS **3.6.7**, tag
`mbedtls-3.6.7`, commit
[`068ff080b369adfac81509f9b57b2afabaf82dc5`](https://github.com/Mbed-TLS/mbedtls/tree/068ff080b369adfac81509f9b57b2afabaf82dc5).
The build hook downloads the commit-pinned snapshot, verifies every selected
file's pristine SHA-256, applies the compatibility patch, and checks
the resulting hashes before compiling. Source is cached outside Git; the
manifest, patch, C shim, configuration and license notices remain tracked.
The archive is GitHub's generated commit snapshot, distinct from the official
`.tar.bz2` asset described in the
[upstream release](https://github.com/Mbed-TLS/mbedtls/releases/tag/mbedtls-3.6.7).
Its compressed/archive bytes are deliberately not pinned: GitHub may change
packaging metadata without changing source. The allowlisted file inventory,
pristine hashes, patch hash and patched-file hashes remain the integrity
boundary; an archive is cached only after all selected pristine files verify.

The selected upstream `include/` and `library/` trees compile with
[`halo_tls_config.h`](src/halo_tls_config.h). Preprocessor options restrict the
enabled implementation to this client; the build does not invoke upstream's
top-level build or download prebuilt native binaries.

We choose Apache-2.0 from upstream's dual Apache-2.0 OR GPL-2.0-or-later
license. The Dart wrapper and C shim use MPL-2.0. The package's tracked
[`LICENSE`](LICENSE) includes both the MPL terms and the Mbed TLS Apache
notice and terms; Flutter includes it in the application's license bundle.
Preserve upstream copyright notices and the notice identifying our modified
file in the cached source as well.

[`empty-psk-identity.patch`](patches/empty-psk-identity.patch) is the only
upstream change, to `library/ssl_tls.c`. HaLo's K4 client sends an empty
identity. The patch permits the zero-length identity in
[RFC 4279 §2](https://www.rfc-editor.org/rfc/rfc4279#section-2), retaining a
non-null allocation for Mbed TLS's ownership checks; it does not alter the
cryptographic operations. The manifest records both the patch hash and the
patched file hash. Reassess and, when possible, remove this patch during each
upstream update.

## Native implementation

The native client offers exactly these TLS 1.2 suites:

- `TLS_ECDHE_PSK_WITH_CHACHA20_POLY1305_SHA256`
- `TLS_ECDHE_PSK_WITH_AES_256_CBC_SHA384`

These are a subset of the K4 remote protocol's advertised suites. There is no
TLS 1.0/1.1/1.3, certificate authentication, renegotiation, session resumption,
or plaintext retry. The PSK is 1–256 bytes; identity is 0–128 UTF-8 bytes.
Mbed TLS seeds its DRBG from its OS entropy implementation. Native key storage
and temporary FFI key copies are zeroed when freed; the caller owns its input
key buffer.

The C shim is a memory-BIO state machine. Native calls never wait for a socket;
Dart owns asynchronous TCP I/O. Each native wire buffer is capped at 64 KiB,
the Dart wire input queue at 256 KiB, and unsent plaintext at 1 MiB. The wrapper
flushes one wire chunk at a time and pauses the socket when plaintext is
unobserved or the input queue reaches 128 KiB, resuming below 64 KiB. This
applies backpressure while a slow wire flush prevents input processing. The
hard queue bounds remain a defensive `bufferLimit` failure. EOF without TLS
`close_notify` reports a connection failure. Native state has explicit teardown
and finalizers as a last-resort cleanup.

## Native builds and source cache

The package's Dart build hook compiles the C shim and Mbed
TLS for the requested target. Dart and Flutter package the resulting native
asset; `@Native` bindings resolve its symbols. Native runs, tests and builds
use the hook automatically, including standalone tools. A separate host
library build, platform plugin wrapper or library-path override is unnecessary.
The target's normal C toolchain is required. Web builds skip native acquisition
and compilation.

Most targets use `native_toolchain_c`'s `CBuilder`. On Windows with MSVC,
the hook uses a small [package-local runner](hook/src/msvc_build.dart):
the SDK-compatible 0.19.2 toolchain invokes MSVC through `cmd.exe`, which
corrupts quoted defines and paths containing spaces. The runner invokes
`cl.exe` and `lib.exe` directly with UTF-16 response files containing all
source, include and output paths. Static archives use an exact object list,
and the shim records the BCrypt dependency for the final link. All source
and header inputs remain build dependencies.

The runner honors the compiler and developer-prompt configuration supplied
by Dart or Flutter. An explicitly supplied toolchain without a developer-prompt
script must already have its `INCLUDE` and `LIB` environment configured.
Without a supplied toolchain, it discovers the installed Visual Studio
C++ workload through `vswhere` and `VsDevCmd.bat`; it does not install tools.
No dependency overrides are required. When the pinned Flutter SDK can use
the upstream [direct MSVC invocation fix](https://pub.dev/packages/native_toolchain_c/versions/0.19.3/changelog),
reassess this runner and retain coverage for long paths, spaces, Unicode and
both link modes before removing it.

The source cache is shared across checkouts and survives `flutter clean`:

- macOS: `~/Library/Caches/ham2k/halo_tls_psk/mbedtls`
- Linux: `$XDG_CACHE_HOME/ham2k/halo_tls_psk/mbedtls`, or
  `~/.cache/ham2k/halo_tls_psk/mbedtls` when XDG is unset or relative
- Windows: `%LOCALAPPDATA%\ham2k\halo_tls_psk\mbedtls`, falling back to
  `%USERPROFILE%\AppData\Local\ham2k\halo_tls_psk\mbedtls`

It contains verified source, not credentials. A cold native build needs network
access to the pinned archive. Reusing a complete cache needs no download;
changing the source or patch pin requires a matching cache entry. Build outputs
are cached separately by Dart's hook infrastructure.
Every completed source cache hit is rehashed. A cache-wide lock serializes
publication and removes abandoned staging directories from interrupted runs;
verified entries and cached archives are retained. Corrupt completed entries
fail closed and must be removed explicitly before retrying.

To populate or verify the source cache without invoking native build hooks,
run the prefetch tool directly from the package directory:

```sh
cd packages/halo_tls_psk
flutter pub get
dart tool/prefetch.dart
dart tool/prefetch.dart --cache-dir /absolute/path/to/mbedtls-cache
dart tool/prefetch.dart --cache-dir /absolute/path/to/mbedtls-cache --offline
```

`--offline` prohibits downloads: a matching warm cache can be reused, while a
cold cache fails with an actionable error. Use the same cache
location for prefetch and the consuming build. An offline source cache does
not replace the Dart package cache, compiler, SDK or other platform build
dependencies. Preserve or prefetch it before working offline. An absent
extracted tree can be reconstructed offline from a cached archive, with the
same file and patch verification.

Configure the consuming Dart or Flutter package's `pubspec.yaml` to use that
cache and prohibit network acquisition:

```yaml
hooks:
  user_defines:
    halo_tls_psk:
      cache_dir: /absolute/path/to/mbedtls-cache
      offline: true
```

`cache_dir` also accepts a path relative to the consuming `pubspec.yaml`.
Omitting it uses the user's default cache; omitting `offline` permits a
download when needed. The prefetch command's flags configure that invocation
only, so the build-hook settings must select the same custom cache.

Hooks run before a native program starts, even if its chosen command only
replays saved data and never opens TLS. Such a command can therefore require
a source download and compilation on its first run. The direct prefetch
invocation above prepares source without compiling it.

## Tests

Use the repository's test runner:

```sh
./scripts/test.sh tls-psk cat
```

The hooks build the host native asset automatically. Interop tests require
**OpenSSL 3** as an independent local test peer. Set `HALO_TLS_TEST_OPENSSL`
when it is not on `PATH`; Homebrew OpenSSL locations are also detected on
macOS. Run `mise run setup` to check this prerequisite; see
[Development prerequisites](../../DEVELOPMENT.md#prerequisites) for installation.
OpenSSL is never used by the production library. Tests use a synthetic
key and OS-assigned loopback ports and cover both suites, empty identity,
fragmented records, authentication failure, shutdown, cancellation and bounded
queues. The full `./scripts/test.sh` remains the required gate.

On Windows, install Visual Studio's Desktop development with C++ workload
and the Windows SDK, then run from this package directory:

```sh
flutter pub get
dart run tool/validate_windows.dart
```

This invokes the actual Dart build hook, loads its native asset, and generates
a ClientHello in memory without connecting to a radio. On a cold build, hook output
identifies the compiler and response file; inspect those files when checking
compiler provenance. Test a checkout and source cache whose paths contain
spaces and non-ASCII characters, and verify both dynamic and static builds
when changing the Windows runner. The smoke tool checks x64 native loading
and Windows entropy use; it does not prove full Flutter app packaging,
other Windows architectures or radio authentication.

## Maintenance and security updates

Upstream publishes fixes through its [releases](https://github.com/Mbed-TLS/mbedtls/releases)
and [security advisories](https://mbed-tls.readthedocs.io/en/latest/security-advisories/),
with [community support](https://github.com/Mbed-TLS/mbedtls/blob/mbedtls-3.6.7/SUPPORT.md)
and a [private vulnerability reporting process](https://mbed-tls.readthedocs.io/en/latest/project/vulnerabilities/).
The 3.6.7 release states that the 3.6 LTS branch receives bug/security fixes
until **at least March 2027**. Recheck the current support policy when updating
and plan a version migration before upstream support ends. A major-version
migration requires separate API/configuration and packaging review.

There is no updater or advisory-monitoring job in this package. Shipping it
adds a manual dependency-maintenance responsibility: check upstream releases
and advisories before releases and when notified of a security issue, assess
the enabled configuration, import applicable fixes, test, and ship rebuilt
apps. An OS or Dart update does not replace this bundled library. Review the
upstream [security policy](https://github.com/Mbed-TLS/mbedtls/blob/mbedtls-3.6.7/SECURITY.md)
when changing compiler options and enabled ciphers.

### Update procedure

1. Select a maintained upstream release. Review its release notes, advisories,
   license changes and migration guidance, including whether the
   empty-identity patch is still needed.
2. Download the selected archive into a temporary directory. Verify its
   provenance against the upstream release/tag and full commit, then record
   a URL pinned to that commit. Review upstream's published release checksums
   when using an official release asset. Do not pin the compressed hash of a
   generated GitHub archive: packaging can change independently of source.
   Locally calculated file hashes pin reviewed bytes; they do not establish
   upstream authenticity by themselves. Review archive completeness when
   migrating major versions: Mbed TLS 4 adds a TF-PSA-Crypto submodule, so the
   current generated-snapshot acquisition is not sufficient unchanged.
3. Update the manifest's version, tag, commit, archive and selected file
   inventory. File hashes describe pristine bytes. Remove an obsolete patch
   or port it deliberately, preserving the modification notice; update its
   hash and resulting-file hashes separately. Review added or changed license
   notices and update the tracked package `LICENSE` as required.
4. Review `halo_tls_config.h`, `halo_tls.c` and the build hook against the new
   requirements, including platform compiler/linker options. Populate a new
   cache from the pinned archive and verify that offline reuse succeeds.
   Exercise missing, corrupt and incompatible cache entries as well.
5. Rebuild without stale native artifacts, run `./scripts/test.sh tls-psk cat`,
   then the full `./scripts/test.sh` gate. Build and exercise the final Flutter
   application on every supported native target. Verify native-asset packaging,
   release-mode symbol resolution, and Android ELF **and APK** alignment.
   Repeat K4 authentication/reconnect checks when TLS behavior changes.
6. Record the version, relevant advisories, validation and remaining gaps in
   the update PR, then distribute a full native app build through the normal
   release process. Updating the manifest, cache or Dart code alone cannot
   replace the backend in an installed app.

Hash and extraction checks establish the integrity of the selected source and
patch. They do not discover security advisories, assess license changes or
prove protocol compatibility. Host tests against OpenSSL do not establish K4
compatibility or platform app packaging; a successful cross-compile does not
verify runtime loading. These require the review and target checks above.
