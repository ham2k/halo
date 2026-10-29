// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Headers of encoded raster images, built byte by byte with the dimensions a
// test wants declared: what `readImageHeader` reads, and no pixel data behind
// them — a header is all a size check may look at.

import 'dart:typed_data';

List<int> be16(int v) => [(v >> 8) & 0xFF, v & 0xFF];
List<int> be32(int v) => [(v >> 24) & 0xFF, (v >> 16) & 0xFF, (v >> 8) & 0xFF, v & 0xFF];
List<int> le16(int v) => [v & 0xFF, (v >> 8) & 0xFF];
List<int> le24(int v) => [v & 0xFF, (v >> 8) & 0xFF, (v >> 16) & 0xFF];
List<int> le32(int v) => [v & 0xFF, (v >> 8) & 0xFF, (v >> 16) & 0xFF, (v >> 24) & 0xFF];
List<int> ascii(String s) => s.codeUnits;

/// A chunk: its data's length, [type], [data], and a CRC of zeros, which no header read checks.
List<int> pngChunk(String type, List<int> data) => [...be32(data.length), ...ascii(type), ...data, 0, 0, 0, 0];

/// An animation control chunk, then a frame control chunk declaring [frameWidth] × [frameHeight].
List<int> apngFrame(int frameWidth, int frameHeight, {int sequence = 0}) => [
  ...pngChunk('acTL', [...be32(1), ...be32(0)]),
  ...pngChunk('fcTL', [...be32(sequence), ...be32(frameWidth), ...be32(frameHeight), ...be32(0), ...be32(0), 0, 1, 0, 100, 0, 0]),
];

/// Signature, then the IHDR chunk: length, type, width, height, bit depth, colour type, compression, filter, interlace.
Uint8List pngHeader(int width, int height) =>
    Uint8List.fromList([0x89, ...ascii('PNG'), 0x0D, 0x0A, 0x1A, 0x0A, ...be32(13), ...ascii('IHDR'), ...be32(width), ...be32(height), 8, 6, 0, 0, 0]);

/// Signature, the logical screen descriptor, a global colour table of
/// 2^[colorTableBits] entries when that is not zero, [before] (extension
/// blocks), then the first image descriptor: the screen's size and origin
/// unless [frame] says otherwise.
Uint8List gifHeader(
  int width,
  int height, {
  String version = '89a',
  int colorTableBits = 0,
  List<int> before = const [],
  ({int left, int top, int width, int height})? frame,
}) => Uint8List.fromList([
  ...ascii('GIF$version'),
  ...le16(width),
  ...le16(height),
  colorTableBits == 0 ? 0 : 0x80 | (colorTableBits - 1),
  0,
  0,
  if (colorTableBits > 0) ...List.filled(3 << colorTableBits, 0),
  ...before,
  0x2C,
  ...le16(frame?.left ?? 0),
  ...le16(frame?.top ?? 0),
  ...le16(frame?.width ?? width),
  ...le16(frame?.height ?? height),
  0,
]);

/// A GIF extension block: the introducer, [label], each sub-block led by its length, and the terminator.
List<int> gifExtension(int label, List<List<int>> subBlocks) => [
  0x21,
  label,
  for (final s in subBlocks) ...[s.length, ...s],
  0,
];

/// File header, then a DIB header of [headerSize] bytes: 16-bit dimensions
/// under 16 (the OS/2 header is 12), or 32-bit ones ([height] negative for
/// top-down) from 16 up.
Uint8List bmpHeader(int width, int height, {int headerSize = 40}) => Uint8List.fromList([
  ...ascii('BM'),
  ...le32(0),
  0,
  0,
  0,
  0,
  ...le32(14 + headerSize),
  ...le32(headerSize),
  if (headerSize < 16) ...[
    ...le16(width),
    ...le16(height),
    ...le16(1),
    ...le16(24),
  ] else ...[
    ...le32(width),
    ...le32(height),
    ...le16(1),
    ...le16(32),
    ...List.filled(24, 0),
  ],
]);

/// RIFF container, then a lossy `VP8 ` chunk: frame tag, start code, 14-bit width and height with the scale bits set.
Uint8List webpLossyHeader(int width, int height) => Uint8List.fromList([
  ...ascii('RIFF'),
  ...le32(0),
  ...ascii('WEBP'),
  ...ascii('VP8 '),
  ...le32(0),
  0,
  0,
  0,
  0x9D,
  0x01,
  0x2A,
  ...le16(width | 0xC000),
  ...le16(height | 0xC000),
]);

/// RIFF container, then a `VP8L` chunk: signature, then width and height minus one in 14 bits each.
Uint8List webpLosslessHeader(int width, int height) => Uint8List.fromList([
  ...ascii('RIFF'),
  ...le32(0),
  ...ascii('WEBP'),
  ...ascii('VP8L'),
  ...le32(0),
  0x2F,
  ...le32((width - 1) | ((height - 1) << 14)),
  0,
  0,
  0,
  0,
  0,
]);

/// RIFF container, then a `VP8X` chunk: flags, reserved bytes, the canvas minus one in 24 bits each.
Uint8List webpExtendedHeader(int width, int height) =>
    Uint8List.fromList([...ascii('RIFF'), ...le32(0), ...ascii('WEBP'), ...ascii('VP8X'), ...le32(10), 0x10, 0, 0, 0, ...le24(width - 1), ...le24(height - 1)]);

/// A marker segment: marker, length counting itself, [payload] zero bytes.
List<int> jpegSegment(int marker, int payload) => [0xFF, marker, ...be16(payload + 2), ...List.filled(payload, 0)];

/// Start of image, [before] (other segments and standalone markers), then a
/// frame header of kind [sof] declaring [height] and [width], three components.
Uint8List jpegHeader(int width, int height, {int sof = 0xC0, List<int> before = const []}) =>
    Uint8List.fromList([0xFF, 0xD8, ...before, 0xFF, sof, ...be16(17), 8, ...be16(height), ...be16(width), 3, 1, 0x22, 0, 2, 0x11, 1, 3, 0x11, 1]);
