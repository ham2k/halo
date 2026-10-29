// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0

import 'dart:math' as math;
import 'dart:typed_data';

/// The pixel size an encoded raster image declares in its header, and which
/// format the header is: `PNG`, `JPEG`, `GIF`, `WebP` or `BMP`.
typedef ImageHeader = ({String format, int width, int height});

/// Which of the five formats [b] begins as, by its signature alone, or null:
/// what [readImageHeader] goes on to read, and the name for a header it then
/// cannot finish.
String? imageFormat(Uint8List b) {
  if (b.isNotEmpty && b[0] == 0x89 && _ascii(b, 1, 'PNG\r\n\x1A\n')) return 'PNG';
  if (_ascii(b, 0, 'GIF87a') || _ascii(b, 0, 'GIF89a')) return 'GIF';
  if (_ascii(b, 0, 'BM')) return 'BMP';
  if (_ascii(b, 0, 'RIFF') && _ascii(b, 8, 'WEBP')) return 'WebP';
  if (b.length >= 2 && b[0] == 0xFF && b[1] == 0xD8) return 'JPEG';
  return null;
}

/// Reads [b]'s header without decoding anything: the point is to know how
/// large a bitmap decoding would make before any is made, and a decoder
/// answers that question only by making it. The format is what the bytes
/// begin with, never what a MIME type claims. Null for what cannot be
/// measured — a format [imageFormat] does not name, or one it names whose
/// header is cut short, a JPEG with no frame header before its scan or with
/// data where a marker belongs, a GIF with no frame — so that a caller
/// holding images to a size refuses those.
ImageHeader? readImageHeader(Uint8List b) {
  final d = ByteData.sublistView(b);
  switch (imageFormat(b)) {
    case 'PNG':
      return _png(b, d);
    case 'GIF':
      return b.length < 13 ? null : _gif(b, d);
    case 'BMP':
      if (b.length < 26) return null;
      final headerSize = d.getUint32(14, Endian.little);
      if (headerSize < 12) return null;
      // A DIB header under 16 bytes is the old OS/2 one, read with 16-bit
      // dimensions; every later one 32-bit, the height negative for a top-down
      // bitmap.
      if (headerSize < 16) {
        return (format: 'BMP', width: d.getUint16(18, Endian.little), height: d.getUint16(20, Endian.little));
      }
      return (format: 'BMP', width: d.getInt32(18, Endian.little).abs(), height: d.getInt32(22, Endian.little).abs());
    case 'WebP':
      return b.length < 30 ? null : _webp(b, d);
    case 'JPEG':
      return _jpeg(b, d);
    default:
      return null;
  }
}

/// The IHDR's size, and no smaller than any animation frame's: the engine's
/// own APNG decoder takes the canvas from an `fcTL` ahead of the image data
/// and allocates each frame at its own declared size before checking it
/// against the canvas, so a 1 × 1 IHDR in front of a 16,384 × 16,384 frame
/// decodes to the frame. Walks every chunk there is; the IHDR comes first or
/// it is not a PNG.
ImageHeader? _png(Uint8List b, ByteData d) {
  int? width, height;
  var i = 8;
  while (i + 8 <= b.length) {
    if (_ascii(b, i + 4, 'IHDR')) {
      if (i + 16 > b.length) return null;
      width = math.max(width ?? 0, d.getUint32(i + 8));
      height = math.max(height ?? 0, d.getUint32(i + 12));
    } else if (_ascii(b, i + 4, 'fcTL')) {
      if (i + 20 > b.length) break;
      width = math.max(width ?? 0, d.getUint32(i + 12));
      height = math.max(height ?? 0, d.getUint32(i + 16));
    } else if (_ascii(b, i + 4, 'IEND')) {
      break;
    }
    if (width == null) return null;
    i += 12 + d.getUint32(i); // Length, type, data, CRC.
  }
  return width == null ? null : (format: 'PNG', width: width, height: height!);
}

/// The three chunk kinds a WebP may open with, each carrying the size its own way.
ImageHeader? _webp(Uint8List b, ByteData d) {
  if (_ascii(b, 12, 'VP8 ') && b[23] == 0x9D && b[24] == 0x01 && b[25] == 0x2A) {
    // Lossy: 14 bits of width and of height after the frame's start code.
    return (format: 'WebP', width: d.getUint16(26, Endian.little) & 0x3FFF, height: d.getUint16(28, Endian.little) & 0x3FFF);
  }
  if (_ascii(b, 12, 'VP8L') && b[20] == 0x2F) {
    // Lossless: 14 bits of width minus one, then 14 of height minus one.
    final bits = d.getUint32(21, Endian.little);
    return (format: 'WebP', width: (bits & 0x3FFF) + 1, height: ((bits >> 14) & 0x3FFF) + 1);
  }
  if (_ascii(b, 12, 'VP8X')) {
    // Extended: the canvas, 24 bits each, minus one.
    return (format: 'WebP', width: _uint24(b, 24) + 1, height: _uint24(b, 27) + 1);
  }
  return null;
}

/// The logical screen, grown to the first frame where that reaches past it:
/// the decoders — the Skia codec and the browsers' alike — grow a screen
/// smaller than its first frame rather than clip the frame, so a 1 × 1 screen
/// in front of a 16,383 × 16,383 frame decodes to the frame. Walks the global
/// colour table and the extension blocks to the first image descriptor;
/// nothing to walk to is nothing to decode.
ImageHeader? _gif(Uint8List b, ByteData d) {
  var width = d.getUint16(6, Endian.little), height = d.getUint16(8, Endian.little);
  final packed = b[10];
  var i = 13 + (packed & 0x80 != 0 ? 3 << ((packed & 0x07) + 1) : 0);
  while (i < b.length) {
    switch (b[i]) {
      case 0x2C:
        if (i + 9 > b.length) return null;
        width = math.max(width, d.getUint16(i + 1, Endian.little) + d.getUint16(i + 5, Endian.little));
        height = math.max(height, d.getUint16(i + 3, Endian.little) + d.getUint16(i + 7, Endian.little));
        return (format: 'GIF', width: width, height: height);
      case 0x21:
        i += 2; // The introducer and the label; then the sub-blocks, each led by its length, to a zero.
        while (i < b.length && b[i] != 0) {
          i += 1 + b[i];
        }
        i++;
      default:
        return null;
    }
  }
  return null;
}

/// Walks the segments from the start-of-image marker to the first frame
/// header (SOF0–SOF15, less the tables and extensions that share the range)
/// and reads its height and width. Gives up at the start of scan, where a
/// frame header should already have been, and at anything not a marker.
ImageHeader? _jpeg(Uint8List b, ByteData d) {
  var i = 2;
  while (i + 4 <= b.length) {
    if (b[i] != 0xFF) return null;
    final marker = b[i + 1];
    if (marker == 0xFF) {
      i++; // A fill byte before the marker.
      continue;
    }
    // A stuffed zero between segments is data to the decoder, which scans on
    // to the next marker; the two walks would part here.
    if (marker == 0x00) return null;
    if (marker == 0xD8 || marker == 0x01 || (marker >= 0xD0 && marker <= 0xD7)) {
      i += 2; // Markers that carry no segment.
      continue;
    }
    if (marker == 0xD9 || marker == 0xDA) return null;
    final length = d.getUint16(i + 2);
    if (length < 2) return null;
    final frameHeader = marker >= 0xC0 && marker <= 0xCF && marker != 0xC4 && marker != 0xC8 && marker != 0xCC;
    if (frameHeader) {
      if (i + 9 > b.length) return null;
      return (format: 'JPEG', width: d.getUint16(i + 7), height: d.getUint16(i + 5));
    }
    i += 2 + length;
  }
  return null;
}

bool _ascii(Uint8List b, int at, String text) {
  if (at + text.length > b.length) return false;
  for (var i = 0; i < text.length; i++) {
    if (b[at + i] != text.codeUnitAt(i)) return false;
  }
  return true;
}

int _uint24(Uint8List b, int at) => b[at] | (b[at + 1] << 8) | (b[at + 2] << 16);
