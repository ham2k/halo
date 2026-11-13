// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The pictures a scene shows (docs/design/panel-scenes.md § Images): its
// extension's own `assets/` files, `data:` URIs, and `https://` addresses on
// the hosts it declares, fetched under the rule every request an extension
// causes is held to (extension_requests.dart). An address on any other host
// is never requested: looking at a pane would otherwise send it, outside
// what the extension told the operator it reaches.

import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:halo_widgets/halo_widgets.dart' show MdiIcons;
import 'package:http/http.dart' as http;

import '../../../services/extensions/extension_service.dart';
import '../../../services/extensions/installed_extensions.dart';
import 'scene_model.dart' show sceneImageMaxBytes;

/// The most pixels a scene image is decoded to on either side. The bytes cap
/// alone admits a PNG of a few kilobytes that decodes to hundreds of
/// megabytes.
const sceneImageMaxSide = 4096;

/// How long an https picture has to arrive, whole: past it the request is
/// dropped, and the picture is asked for again as a failed one is.
const sceneImageFetchTimeout = Duration(seconds: 30);

/// Where a scene's images come from.
abstract interface class SceneImages {
  /// Who the images are for, as the console names them.
  String get name;

  /// The picture [source] names, when it is decoded already: a pane shown
  /// again draws it in its first frame rather than the one after.
  ui.Image? loaded(String source);

  /// The picture [source] names, decoded; throws why when it cannot be had.
  Future<ui.Image> load(String source);

  /// Says [asked], a [load] of [source], is no longer wanted. A picture
  /// still under way that nothing wants any more is dropped, its download
  /// with it.
  void release(String source, Future<ui.Image> asked);
}

/// Why a scene image cannot be had, for the extension's author.
class SceneImageUnavailable implements Exception {
  final String message;
  const SceneImageUnavailable(this.message);

  @override
  String toString() => message;
}

/// An https picture's answer when it is not the picture.
class SceneImageStatus implements Exception {
  final int status;
  const SceneImageStatus(this.status);

  /// Whether asking again may get the picture: the host busy or failing,
  /// rather than saying the picture is not there for the app.
  bool get passing => status == 408 || status == 429 || status >= 500;

  @override
  String toString() => 'HTTP $status';
}

bool _isHttps(String source) => Uri.tryParse(source)?.scheme == 'https';

/// Whether [error], [source]'s failure, may pass: an https picture that
/// did not arrive, or that its host could not give just then. One refused
/// for what it is (too large, not a picture, not there) is refused the same
/// way every time.
bool _mayPass(String source, Object error) =>
    _isHttps(source) && (error is TimeoutException || (error is SceneImageStatus && error.passing) || error is http.ClientException);

/// The [SceneImages] of the scene below: the extension that rendered it.
class SceneImageScope extends InheritedWidget {
  final SceneImages? images;

  const SceneImageScope({super.key, required this.images, required super.child});

  static SceneImages? of(BuildContext context) => context.dependOnInheritedWidgetOfExactType<SceneImageScope>()?.images;

  @override
  bool updateShouldNotify(SceneImageScope old) => old.images != images;
}

/// One extension's scene images: its own `assets/` from [store] (null for a
/// bundle with none, a built-in or a dev-served one), and the hosts its
/// [grant] admits.
class ExtensionSceneImages implements SceneImages {
  final String extensionKey;
  final InstalledExtensions? store;
  final ExtensionNetworkGrant grant;
  final ExtensionClientFactory clients;
  final Duration fetchTimeout;

  /// The [store]'s generation of the extension's files: a new bundle's
  /// pictures are new pictures, however they are named.
  final int _generation;

  ExtensionSceneImages({
    required this.extensionKey,
    required this.store,
    required this.grant,
    this.clients = defaultExtensionClient,
    this.fetchTimeout = sceneImageFetchTimeout,
  }) : _generation = store?.assetGeneration(extensionKey) ?? 0;

  @override
  String get name => extensionKey;

  /// Decoded pictures kept across every scene, the most recently asked for
  /// first to stay, to this many bytes, their pixels and their keys (a
  /// `data:` URI's key is the picture again): past it the oldest goes, and is
  /// read again when next shown.
  @visibleForTesting
  static int keptBytes = 256 * 1024 * 1024;
  static final _cache = <String, _Kept>{};

  @visibleForTesting
  static void debugForget() => _cache.clear();

  // An https picture is kept under the grant it was fetched with: one the
  // grant no longer admits is asked of the grant again, and refused.
  String _key(String source) => '$extensionKey\n$_generation\n${_isHttps(source) ? '${grant.developerMode} ${grant.domains.join(',')}' : ''}\n$source';

  /// The entry under [key], made the most recently asked for.
  static _Kept? _touch(String key) {
    final kept = _cache.remove(key);
    if (kept != null) _cache[key] = kept;
    return kept;
  }

  @override
  ui.Image? loaded(String source) => _touch(_key(source))?.decoded;

  @override
  Future<ui.Image> load(String source) {
    final key = _key(source);
    final kept = _touch(key);
    if (kept != null) {
      if (kept.decoded == null) kept.waiting++;
      return kept.image;
    }
    final done = Completer<ui.Image>();
    final entry = _Kept(done.future, key.length);
    _cache[key] = entry;
    _trim();
    _load(source, entry).then(
      (image) {
        if (identical(_cache[key], entry)) {
          entry.decoded = image;
          _trim();
        }
        done.complete(image);
      },
      // A failure is not kept: the next showing asks again.
      onError: (Object e, StackTrace stack) {
        if (identical(_cache[key], entry)) _cache.remove(key);
        done.completeError(e, stack);
      },
    );
    return done.future;
  }

  @override
  void release(String source, Future<ui.Image> asked) {
    final key = _key(source);
    final kept = _cache[key];
    if (kept == null || !identical(kept.image, asked) || kept.decoded != null || --kept.waiting > 0) return;
    _cache.remove(key);
    kept.abort?.call();
  }

  static void _trim() {
    var total = _cache.values.fold(0, (sum, e) => sum + e.bytes);
    while (total > keptBytes && _cache.length > 1) {
      total -= _cache.remove(_cache.keys.first)!.bytes;
    }
  }

  Future<ui.Image> _load(String source, _Kept entry) async => decodeSceneImage(await _bytes(source, entry));

  Future<Uint8List> _bytes(String source, _Kept entry) async {
    if (source.startsWith('data:')) {
      final data = Uri.parse(source).data;
      if (data == null) throw const FormatException('not a data: URI');
      final bytes = data.contentAsBytes();
      if (bytes.length > sceneImageMaxBytes) throw FormatException('${bytes.length} bytes, at most $sceneImageMaxBytes');
      return bytes;
    }
    final uri = Uri.parse(source);
    if (uri.scheme == 'https') return _fetch(uri, entry);
    final store = this.store;
    if (store == null) throw const SceneImageUnavailable('no assets/ to read from: a built-in or dev-served extension has none');
    final bytes = await store.readAsset(extensionKey, Uri.decodeFull(uri.path));
    if (bytes == null) throw SceneImageUnavailable('not in the bundle, or more than $sceneImageMaxBytes bytes');
    return bytes;
  }

  /// [uri]'s bytes, through a client that sends only what [grant] admits,
  /// stopping past [sceneImageMaxBytes], and dropped after [fetchTimeout] or
  /// when [entry] is no longer wanted.
  Future<Uint8List> _fetch(Uri uri, _Kept entry) {
    final client = ExtensionClient(grant, clients: clients);
    final done = Completer<Uint8List>();
    late final Timer watchdog;
    void drop(Object why) {
      if (!done.isCompleted) done.completeError(why);
      watchdog.cancel();
      client.close();
    }

    watchdog = Timer(fetchTimeout, () => drop(TimeoutException('no picture within ${fetchTimeout.inSeconds} s', fetchTimeout)));
    entry.abort = () => drop(const SceneImageUnavailable('no longer shown'));
    Future<Uint8List> read() async {
      final response = await client.send(http.Request('GET', uri));
      if (response.statusCode != 200) throw SceneImageStatus(response.statusCode);
      final out = BytesBuilder(copy: false);
      await for (final chunk in response.stream) {
        out.add(chunk);
        if (out.length > sceneImageMaxBytes) throw FormatException('more than $sceneImageMaxBytes bytes');
      }
      return out.takeBytes();
    }

    read()
        .then(
          (bytes) {
            if (!done.isCompleted) done.complete(bytes);
          },
          onError: (Object e, StackTrace stack) {
            if (!done.isCompleted) done.completeError(e, stack);
          },
        )
        .whenComplete(() {
          entry.abort = null;
          watchdog.cancel();
          client.close();
        });
    return done.future;
  }

  @override
  bool operator ==(Object other) =>
      other is ExtensionSceneImages &&
      other.extensionKey == extensionKey &&
      identical(other.store, store) &&
      other._generation == _generation &&
      other.grant.developerMode == grant.developerMode &&
      listEquals(other.grant.domains, grant.domains);

  @override
  int get hashCode => Object.hash(extensionKey, store, _generation, grant.developerMode, Object.hashAll(grant.domains));
}

/// A picture [ExtensionSceneImages] keeps: while it loads, how many have
/// asked for it, and how to drop its download.
class _Kept {
  _Kept(this.image, this._keyBytes);

  final Future<ui.Image> image;
  final int _keyBytes;
  ui.Image? decoded;
  int waiting = 1;
  VoidCallback? abort;

  int get bytes => _keyBytes + (decoded == null ? 0 : decoded!.width * decoded!.height * 4);
}

/// The scene images of the panels [extensionKey], as the runtime stamped it,
/// registered: its own `assets/` when it is installed, and the hosts its
/// manifest declares. Null for a panel no extension owns.
SceneImages? sceneImagesFor(ExtensionService extensions, String? extensionKey) {
  if (extensionKey == null) return null;
  final info = extensions.owningExtensionOf(extensionKey);
  return ExtensionSceneImages(
    extensionKey: info?.key ?? extensionKey,
    store: info?.isInstalled == true ? extensions.installed : null,
    grant: extensions.networkGrantFor(extensionKey),
  );
}

/// [bytes] as a picture, refused before it is decoded when either side
/// would be more than [maxSide]: the header says how large, and decoding it
/// to find out is what the cap is there to spare. The app's own read of the
/// header takes the same four formats everywhere; where the decoder says
/// what it read too, its size is held to the cap as well, so a file cannot
/// show the check one size and the decoder another. A browser build's
/// decoder does not say.
Future<ui.Image> decodeSceneImage(Uint8List bytes, {int maxSide = sceneImageMaxSide}) async {
  void hold(({int width, int height})? size) {
    if (size == null) throw const FormatException('not a PNG, JPEG, GIF or WebP this app reads');
    if (size.width > maxSide || size.height > maxSide) throw FormatException('${size.width}×${size.height} pixels, at most $maxSide a side');
  }

  hold(sceneImageSize(bytes));
  if (kIsWeb) {
    final codec = await ui.instantiateImageCodec(bytes);
    try {
      return (await codec.getNextFrame()).image;
    } finally {
      codec.dispose();
    }
  }
  final buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
  ui.ImageDescriptor? descriptor;
  ui.Codec? codec;
  try {
    try {
      descriptor = await ui.ImageDescriptor.encoded(buffer);
    } on Exception catch (e) {
      throw FormatException('not a picture this app reads: $e');
    }
    hold((width: descriptor.width, height: descriptor.height));
    codec = await descriptor.instantiateCodec();
    return (await codec.getNextFrame()).image;
  } finally {
    codec?.dispose();
    descriptor?.dispose();
    buffer.dispose();
  }
}

/// The pixel size a PNG, GIF, JPEG or WebP's header declares, read as a
/// decoder reads it; null for anything else, or a header cut short.
@visibleForTesting
({int width, int height})? sceneImageSize(Uint8List b) {
  final data = ByteData.sublistView(b);
  bool at(int offset, List<int> magic) {
    if (b.length < offset + magic.length) return false;
    for (var i = 0; i < magic.length; i++) {
      if (b[offset + i] != magic[i]) return false;
    }
    return true;
  }

  ({int width, int height})? size(int width, int height) => width > 0 && height > 0 ? (width: width, height: height) : null;
  if (at(0, const [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]) && at(12, 'IHDR'.codeUnits) && b.length >= 24) {
    return size(data.getUint32(16), data.getUint32(20));
  }
  if ((at(0, 'GIF87a'.codeUnits) || at(0, 'GIF89a'.codeUnits)) && b.length >= 13) return _gifSize(b, data);
  if (at(0, 'RIFF'.codeUnits) && at(8, 'WEBP'.codeUnits)) {
    if (at(12, 'VP8 '.codeUnits) && b.length >= 30) return size(data.getUint16(26, Endian.little) & 0x3FFF, data.getUint16(28, Endian.little) & 0x3FFF);
    if (at(12, 'VP8L'.codeUnits) && b.length >= 25) {
      final bits = data.getUint32(21, Endian.little);
      return size((bits & 0x3FFF) + 1, ((bits >> 14) & 0x3FFF) + 1);
    }
    if (at(12, 'VP8X'.codeUnits) && b.length >= 31) {
      return size((data.getUint32(24, Endian.little) & 0xFFFFFF) + 1, (data.getUint32(27, Endian.little) & 0xFFFFFF) + 1);
    }
    return null;
  }
  if (at(0, const [0xFF, 0xD8])) return _jpegSize(b, data);
  return null;
}

/// A GIF's size: its screen, grown to its first frame where the frame
/// reaches past it, as a decoder grows it.
({int width, int height})? _gifSize(Uint8List b, ByteData data) {
  var width = data.getUint16(6, Endian.little);
  var height = data.getUint16(8, Endian.little);
  var i = 13;
  if (b[10] & 0x80 != 0) i += 3 << ((b[10] & 7) + 1);
  while (i < b.length) {
    switch (b[i]) {
      case 0x21: // an extension: its label, then sub-blocks to an empty one
        i += 2;
        while (i < b.length && b[i] != 0) {
          i += b[i] + 1;
        }
        i++;
      case 0x2C: // the first frame
        if (i + 9 > b.length) return null;
        width = math.max(width, data.getUint16(i + 1, Endian.little) + data.getUint16(i + 5, Endian.little));
        height = math.max(height, data.getUint16(i + 3, Endian.little) + data.getUint16(i + 7, Endian.little));
        return width > 0 && height > 0 ? (width: width, height: height) : null;
      default:
        return null;
    }
  }
  return null;
}

/// A JPEG's size, from its first frame header, walking the markers as a
/// decoder does: one with no length (a restart, TEM, a second SOI) is two
/// bytes, and anything between markers is skipped.
({int width, int height})? _jpegSize(Uint8List b, ByteData data) {
  var i = 2;
  while (i + 1 < b.length) {
    if (b[i] != 0xFF) {
      i++;
      continue;
    }
    final marker = b[i + 1];
    if (marker == 0xFF) {
      i++;
      continue;
    }
    if (marker == 0x00 || marker == 0x01 || (marker >= 0xD0 && marker <= 0xD8)) {
      i += 2;
      continue;
    }
    if (marker == 0xD9 || i + 4 > b.length) return null;
    // SOF0 to SOF15, less DHT (C4), JPG (C8) and DAC (CC).
    if (marker >= 0xC0 && marker <= 0xCF && marker != 0xC4 && marker != 0xC8 && marker != 0xCC) {
      if (i + 9 > b.length) return null;
      final width = data.getUint16(i + 7);
      final height = data.getUint16(i + 5);
      return width > 0 && height > 0 ? (width: width, height: height) : null;
    }
    i += 2 + data.getUint16(i + 2);
  }
  return null;
}

/// Says on the console why [source]'s picture is not shown: the extension's
/// to fix, so never the operator's.
void _report(SceneImages? from, String source, Object error) {
  final shown = source.length > 80 ? '${source.substring(0, 77)}…' : source;
  final why = from == null ? 'no extension owns this panel' : '$error';
  // A browser refuses a host that does not allow the app to read it with no reason given.
  final cors = kIsWeb && error is http.ClientException && _isHttps(source) ? ' (in a browser, the host must allow it: CORS)' : '';
  debugPrint('[panels] ${from?.name ?? 'scene'}: scene image not shown: $shown: $why$cors');
}

/// The pictures a scene shows, by slot (an image layer, a map's image by its
/// id), from the [SceneImages] above it as they load. A slot shows nothing
/// until its picture has loaded, and nothing while it cannot be had; given a
/// new source, it shows the picture it had until the new one arrives, so a
/// picture that changes its address does not blink out. A failure is said on
/// the console once a source; an https one that may pass (it timed out, or
/// the host was busy or failing) is asked for again after [retryAfter], the
/// others only when the scene's images change.
class SceneImageLoader {
  SceneImageLoader(this.onLoaded, {this.retryAfter = const Duration(minutes: 1)});

  final VoidCallback onLoaded;
  final Duration retryAfter;
  final _slots = <Object, String>{};
  final _held = <Object, ui.Image>{};
  final _images = <String, ui.Image>{};
  final _asked = <String>{};
  final _pending = <String, Future<ui.Image>>{};
  final _failed = <String>{};
  final _reported = <String>{};
  final _retries = <String, Timer>{};
  SceneImages? _from;

  /// Bumped when the images come from elsewhere: an answer for an earlier
  /// generation is dropped. Not the [SceneImages] itself, which a rebuild
  /// replaces with an equal one while its loads are under way.
  int _generation = 0;

  /// Called from build: asks for each source of [slots] not yet asked of
  /// [from], and lets go of the pictures of any no longer among them.
  void want(SceneImages? from, Map<Object, String> slots) {
    if (from != _from) {
      _forget((_) => true);
      _generation++;
      _reported.clear();
    }
    _from = from;
    _slots
      ..clear()
      ..addAll(slots);
    _held.removeWhere((slot, _) => !slots.containsKey(slot));
    final wanted = slots.values.toSet();
    _forget((source) => !wanted.contains(source));
    for (final source in wanted) {
      if (!_asked.add(source)) continue;
      if (from == null) {
        _fail(source);
        if (_reported.add(source)) _report(null, source, 'none');
        continue;
      }
      if (from.loaded(source) case final image?) {
        _images[source] = image;
        _failed.remove(source);
        continue;
      }
      final generation = _generation;
      final asked = _pending[source] = from.load(source);
      asked.then(
        (image) {
          if (generation != _generation || !identical(_pending[source], asked)) return;
          _pending.remove(source);
          _images[source] = image;
          _failed.remove(source);
          _hold();
          onLoaded();
        },
        onError: (Object e) {
          if (generation != _generation || !identical(_pending[source], asked)) return;
          _pending.remove(source);
          _fail(source);
          if (_reported.add(source)) _report(from, source, e);
          onLoaded();
          if (_mayPass(source, e)) {
            _retries.remove(source)?.cancel();
            _retries[source] = Timer(retryAfter, () {
              _retries.remove(source);
              if (generation != _generation || !_asked.remove(source)) return;
              onLoaded();
            });
          }
        },
      );
    }
    _hold();
  }

  /// Each slot whose picture is in takes it as the one it shows meanwhile.
  void _hold() {
    for (final MapEntry(key: slot, value: source) in _slots.entries) {
      if (_images[source] case final image?) _held[slot] = image;
    }
  }

  void _fail(String source) {
    _failed.add(source);
    _held.removeWhere((slot, _) => _slots[slot] == source);
  }

  void _forget(bool Function(String source) which) {
    for (final source in _asked.where(which).toList()) {
      _asked.remove(source);
      _images.remove(source);
      _failed.remove(source);
      _retries.remove(source)?.cancel();
      if (_pending.remove(source) case final asked?) _from?.release(source, asked);
    }
  }

  /// The picture [slot] shows.
  ui.Image? operator [](Object slot) {
    final source = _slots[slot];
    if (source == null || _failed.contains(source)) return null;
    return _images[source] ?? _held[slot];
  }

  /// Whether [slot]'s picture could not be had, last it was asked for.
  bool failed(Object slot) => _failed.contains(_slots[slot]);

  void dispose() {
    _forget((_) => true);
    _generation++;
    _slots.clear();
    _held.clear();
  }
}

/// An image layer's picture, filling its box as [fit] says: nothing while it
/// loads, and a broken-image mark when it cannot be had, as an svg layer
/// that does not parse shows.
class SceneImageView extends StatefulWidget {
  final String source;
  final BoxFit fit;

  const SceneImageView({super.key, required this.source, required this.fit});

  @override
  State<SceneImageView> createState() => _SceneImageViewState();
}

class _SceneImageViewState extends State<SceneImageView> {
  late final _loader = SceneImageLoader(() {
    if (mounted) setState(() {});
  });

  @override
  void dispose() {
    _loader.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _loader.want(SceneImageScope.of(context), {0: widget.source});
    final image = _loader[0];
    if (image == null && _loader.failed(0)) return const Center(child: Icon(MdiIcons.imageBroken));
    return RawImage(image: image, fit: widget.fit);
  }
}
