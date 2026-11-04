// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The images in markdown an extension wrote: its own, and nothing else.
//
// An image tag in an extension's panel, notice or settings text would
// otherwise be a request to whatever host it names, made just by the
// operator looking at it — a tracking pixel, or a way round the `domains`
// the extension declared. So an image draws only when it fetches nothing:
// a file from the extension's own `assets/`, as installed, or a `data:` URI.
// Everything else is its alt text, as it is in any markdown with no
// MarkdownImages above it.

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:halo_widgets/halo_widgets.dart';
import 'package:path/path.dart' as p;

import '../services/extensions/extension_service.dart';
import '../services/extensions/installed_extensions.dart';
import '../services/extensions/settings_placement.dart';

/// [child]'s markdown drawing the images of the extension [extensionKey]:
/// its own `assets/` files from [store], and `data:` images. A null [store]
/// — no installed store yet, or a built-in extension, which has no `assets/`
/// — still draws its `data:` images.
class ExtensionMarkdownImages extends StatelessWidget {
  const ExtensionMarkdownImages({super.key, required this.store, required this.extensionKey, required this.child});

  final InstalledExtensions? store;
  final String extensionKey;
  final Widget child;

  /// [child] drawing the images of the extension that owns [owner] — a hook
  /// key (`pota_activity`), a sub-extension's (`pota-all-parks`) or the
  /// extension's own. With no such extension, [child] as it is: its images
  /// are their alt text.
  static Widget owning(ExtensionService? extensions, String? owner, {required Widget child}) {
    final images = extensionImagesFor(extensions, owner);
    return images == null ? child : MarkdownImages(builder: images, child: child);
  }

  @override
  Widget build(BuildContext context) => MarkdownImages(builder: extensionMarkdownImageBuilder(store, extensionKey), child: child);
}

/// The image builder for markdown the extension that owns [owner] wrote, or
/// null when no extension owns it — the [ExtensionMarkdownImages.owning] of
/// a dialog, which builds its own route where no widget above reaches.
MarkdownSizedImageBuilder? extensionImagesFor(ExtensionService? extensions, String? owner) {
  if (extensions == null || owner == null) return null;
  final info = owningExtension(owner, extensions.availableExtensions, (ExtensionInfo info) => info.key);
  if (info == null) return null;
  return extensionMarkdownImageBuilder(info.isInstalled ? extensions.installed : null, info.key);
}

/// One builder per store, key and install of it, kept: a markdown parses
/// again when its builder changes, which a fresh one every build would do
/// on every build, and an update of the extension must.
final _builders = Expando<Map<String, MarkdownSizedImageBuilder>>();
final _storelessBuilders = <String, MarkdownSizedImageBuilder>{};

/// The image builder behind [ExtensionMarkdownImages].
MarkdownSizedImageBuilder extensionMarkdownImageBuilder(InstalledExtensions? store, String extensionKey) {
  final builders = store == null ? _storelessBuilders : (_builders[store] ??= {});
  final memoKey = '$extensionKey#${store?.assetGeneration(extensionKey) ?? 0}';
  final kept = builders[memoKey];
  if (kept != null) return kept;
  builders.removeWhere((key, _) => key.startsWith('$extensionKey#'));
  return builders[memoKey] = _builder(store, extensionKey);
}

MarkdownSizedImageBuilder _builder(InstalledExtensions? store, String extensionKey) => (config) {
  final uri = config.uri;
  if (uri.scheme == 'data') {
    final data = uri.data;
    final format = data == null ? null : _formatOfMime(data.mimeType);
    if (data == null || format == null) return markdownAltText(config);
    final bytes = _dataBytes(uri.toString(), data);
    if (bytes == null) return markdownAltText(config);
    return _image(bytes, format, config, extensionKey);
  }
  // Only a bare relative path can name the bundle: `assets/logo.png`, never
  // `https://…`, `//host/…` or `file:…`.
  if (uri.hasScheme || uri.hasAuthority || store == null) return markdownAltText(config);
  final String path;
  try {
    path = Uri.decodeFull(uri.path);
  } on FormatException {
    // `assets/%FF.png`: an escape that is no character, so no file.
    return markdownAltText(config);
  }
  final format = _formatOfPath(path);
  if (format == null || InstalledExtensions.assetEntryName(path) == null) return markdownAltText(config);
  return FutureBuilder<Uint8List?>(
    future: store.readAsset(extensionKey, path),
    initialData: store.readAssetNow(extensionKey, path),
    builder: (context, snapshot) {
      final bytes = snapshot.data;
      if (bytes != null) return _image(bytes, format, config, extensionKey);
      // An error stays the alt text while the next read is pending, rather
      // than blinking out and back on every render of a failing store.
      if (snapshot.hasError || snapshot.connectionState == ConnectionState.done) return markdownAltText(config);
      // Holds the size the markdown asked for while it reads, so the text
      // below does not jump when the image arrives.
      return SizedBox(width: config.width, height: config.height);
    },
  );
};

enum _Format { raster, svg }

_Format? _formatOfMime(String mime) => switch (mime.toLowerCase()) {
  'image/png' || 'image/jpeg' || 'image/gif' || 'image/webp' => _Format.raster,
  'image/svg+xml' => _Format.svg,
  _ => null,
};

_Format? _formatOfPath(String path) => switch (p.posix.extension(path).toLowerCase()) {
  '.png' || '.jpg' || '.jpeg' || '.gif' || '.webp' => _Format.raster,
  '.svg' => _Format.svg,
  _ => null,
};

/// A `data:` image's bytes, decoded once and kept as the same bytes so the
/// image cache knows it again on the next render; null when they do not
/// decode or are too large to draw.
Uint8List? _dataBytes(String source, UriData data) {
  final cached = _dataImages.remove(source);
  if (cached != null) return _dataImages[source] = cached;
  final Uint8List bytes;
  try {
    bytes = data.contentAsBytes();
  } on FormatException {
    return null;
  }
  if (bytes.length > kMaxAssetImageBytes) return null;
  if (_dataImages.length >= _dataImageEntries) _dataImages.remove(_dataImages.keys.first);
  return _dataImages[source] = bytes;
}

final _dataImages = <String, Uint8List>{};

/// How many `data:` images are kept decoded. They are already in the
/// markdown's own text, so this bounds a copy, not a read.
const _dataImageEntries = 32;

Widget _image(Uint8List bytes, _Format format, MarkdownImageConfig config, String extensionKey) {
  Widget alt(BuildContext context, Object error, StackTrace? stack) {
    // The author's file, almost always, so nothing is reported — but the
    // console says which, or a broken PNG reads just like a wrong path.
    debugPrint('[extensions] $extensionKey: could not draw ${config.uri}: $error');
    return markdownAltText(config);
  }

  final image = switch (format) {
    // Gapless: a pane redrawn with new bytes for the same file keeps the
    // last frame up rather than blanking while it decodes.
    _Format.raster => Image.memory(bytes, width: config.width, height: config.height, gaplessPlayback: true, errorBuilder: alt),
    _Format.svg => SvgPicture.memory(bytes, width: config.width, height: config.height, errorBuilder: alt),
  };
  final label = config.alt;
  return label == null || label.isEmpty
      ? image
      : Semantics(
          label: label,
          image: true,
          child: ExcludeSemantics(child: image),
        );
}
