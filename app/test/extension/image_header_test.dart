// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The header reader behind the preview pixel budget (image_header.dart). It
// reads what the bytes are, never what they are called, and answers nothing
// for what it cannot measure — a format it does not read, or a header cut
// short — so the budget refuses those rather than letting a decoder find out.

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:ham2k_logger/services/image_header.dart';

import '../support/image_headers.dart';

void main() {
  test('reads the five formats\' dimensions from their headers alone', () {
    expect(readImageHeader(pngHeader(640, 480)), (format: 'PNG', width: 640, height: 480));
    expect(readImageHeader(gifHeader(320, 200)), (format: 'GIF', width: 320, height: 200));
    expect(readImageHeader(gifHeader(320, 200, version: '87a')), (format: 'GIF', width: 320, height: 200));
    expect(readImageHeader(bmpHeader(800, 600)), (format: 'BMP', width: 800, height: 600));
    // A top-down bitmap declares its height negative; the old core header is 16-bit.
    expect(readImageHeader(bmpHeader(800, -600)), (format: 'BMP', width: 800, height: 600));
    expect(readImageHeader(bmpHeader(800, 600, headerSize: 12)), (format: 'BMP', width: 800, height: 600));
    // The decoder reads any header under 16 bytes the OS/2 way, and none under 12.
    expect(readImageHeader(bmpHeader(800, 600, headerSize: 13)), (format: 'BMP', width: 800, height: 600));
    expect(readImageHeader(bmpHeader(800, 600, headerSize: 11)), isNull);
    expect(readImageHeader(webpLossyHeader(1024, 768)), (format: 'WebP', width: 1024, height: 768));
    expect(readImageHeader(webpLosslessHeader(1024, 768)), (format: 'WebP', width: 1024, height: 768));
    expect(readImageHeader(webpExtendedHeader(16383, 16383)), (format: 'WebP', width: 16383, height: 16383));
    expect(readImageHeader(jpegHeader(1920, 1080)), (format: 'JPEG', width: 1920, height: 1080));
  });

  test('measures a PNG by its largest animation frame as well as its IHDR', () {
    // The trap: the engine's APNG decoder takes the canvas from an fcTL ahead
    // of the image data, and allocates every frame at its own size before
    // checking it against the canvas — so the IHDR alone says nothing.
    final signature = Uint8List.sublistView(pngHeader(1, 1), 0, 8);
    List<int> ihdr(int w, int h) => pngChunk('IHDR', [...be32(w), ...be32(h), 8, 6, 0, 0, 0]);
    final idat = pngChunk('IDAT', [0, 0, 0, 0]);
    final iend = pngChunk('IEND', []);
    expect(readImageHeader(Uint8List.fromList([...signature, ...ihdr(1, 1), ...apngFrame(16384, 16384), ...idat, ...iend])), (
      format: 'PNG',
      width: 16384,
      height: 16384,
    ));
    expect(readImageHeader(Uint8List.fromList([...signature, ...ihdr(100, 100), ...idat, ...apngFrame(50, 50), ...iend])), (
      format: 'PNG',
      width: 100,
      height: 100,
    ));
    expect(readImageHeader(Uint8List.fromList([...signature, ...ihdr(100, 100), ...idat, ...apngFrame(200, 50, sequence: 1), ...iend])), (
      format: 'PNG',
      width: 200,
      height: 100,
    ));
    // The IHDR comes first, or it is not a PNG the decoders read.
    expect(readImageHeader(Uint8List.fromList([...signature, ...idat, ...ihdr(100, 100)])), isNull);
  });

  test('grows a GIF\'s screen to its first frame, found past the colour table and the extension blocks', () {
    // The trap: the logical screen is the size a GIF claims, and the decoders
    // grow a screen smaller than the first frame to the frame rather than clip
    // it — so a 1 × 1 screen in front of a huge frame decodes to the frame,
    // and a reader that stops at the screen passes it.
    expect(readImageHeader(gifHeader(1, 1, frame: (left: 0, top: 0, width: 16383, height: 16383))), (format: 'GIF', width: 16383, height: 16383));
    expect(readImageHeader(gifHeader(100, 100, frame: (left: 90, top: 0, width: 20, height: 10))), (format: 'GIF', width: 110, height: 100));
    final blocks = [
      ...gifExtension(0xF9, [
        [0, 0, 0, 0],
      ]),
      ...gifExtension(0xFE, [ascii('a comment'), ascii('in two sub-blocks')]),
    ];
    expect(readImageHeader(gifHeader(1, 1, colorTableBits: 8, before: blocks, frame: (left: 0, top: 0, width: 5000, height: 5000))), (
      format: 'GIF',
      width: 5000,
      height: 5000,
    ));
    // Nothing to decode: no frame, or a block that is neither an extension nor a frame.
    expect(readImageHeader(Uint8List.sublistView(gifHeader(320, 200), 0, 13)), isNull);
    expect(readImageHeader(Uint8List.fromList([...Uint8List.sublistView(gifHeader(320, 200), 0, 13), 0x3B])), isNull);
    expect(readImageHeader(Uint8List.fromList([...Uint8List.sublistView(gifHeader(320, 200), 0, 13), 0x2C, 0, 0, 0, 0])), isNull);
  });

  test('walks a JPEG\'s segments to its frame header, whichever kind, and gives up where none can follow', () {
    // The trap: a camera's JPEG opens with APP segments — EXIF alone can run
    // to tens of kilobytes — and padding bytes before a marker are legal, so
    // a reader that expects the frame header at a fixed offset reads garbage.
    final before = [...jpegSegment(0xE0, 16), ...jpegSegment(0xE1, 40000), 0xFF, 0xFF, 0xD0, ...jpegSegment(0xC4, 12)];
    expect(readImageHeader(jpegHeader(300, 200, sof: 0xC2, before: before)), (format: 'JPEG', width: 300, height: 200));
    expect(readImageHeader(jpegHeader(300, 200, sof: 0xCF, before: before)), (format: 'JPEG', width: 300, height: 200));
    // A stuffed zero is data to the decoder, which scans on past it: the
    // frame header it then reads is the one this "segment" hides.
    final hidden = [0xFF, 0xC0, ...be16(17), 8, ...be16(65535), ...be16(65535), 3, 1, 0x22, 0, 2, 0x11, 1, 3, 0x11, 1];
    expect(readImageHeader(jpegHeader(16, 16, before: [0xFF, 0x00, ...be16(hidden.length + 2), ...hidden])), isNull);
    // A start of scan with no frame header before it, and bytes that are no marker at all.
    expect(readImageHeader(Uint8List.fromList([0xFF, 0xD8, ...jpegSegment(0xDA, 4), 0xFF, 0xC0, 0, 17, 8, 1, 44, 0, 200])), isNull);
    expect(readImageHeader(Uint8List.fromList([0xFF, 0xD8, 0x12, 0x34, 0, 0, 0, 0])), isNull);
    expect(readImageHeader(Uint8List.fromList([0xFF, 0xD8, 0xFF, 0xE0, 0xFF, 0xFF])), isNull, reason: 'a segment running past the end');
  });

  test('names the format by its signature, size or no size', () {
    // What the console says when the size cannot be read: the format the
    // bytes are, where there is one.
    expect(imageFormat(Uint8List.sublistView(pngHeader(1, 1), 0, 8)), 'PNG');
    expect(imageFormat(Uint8List.sublistView(pngHeader(1, 1), 0, 7)), isNull);
    expect(imageFormat(jpegHeader(1, 1)), 'JPEG');
    expect(imageFormat(Uint8List.fromList(ascii('BM'))), 'BMP');
    expect(imageFormat(Uint8List.sublistView(webpLossyHeader(1, 1), 0, 12)), 'WebP');
    expect(imageFormat(Uint8List.fromList(ascii('GIF89a'))), 'GIF');
    expect(imageFormat(Uint8List.fromList([0x49, 0x49, 0x2A, 0x00])), isNull);
    expect(imageFormat(Uint8List(0)), isNull);
  });

  test('answers nothing for a header cut short or a format it does not read', () {
    // The trap: a reader that returns the bytes it managed to read, or a
    // default size, lets the budget pass a file nothing has measured.
    expect(readImageHeader(Uint8List.sublistView(pngHeader(640, 480), 0, 23)), isNull);
    expect(readImageHeader(Uint8List.sublistView(gifHeader(320, 200), 0, 9)), isNull);
    expect(readImageHeader(Uint8List.sublistView(bmpHeader(800, 600), 0, 25)), isNull);
    expect(readImageHeader(Uint8List.sublistView(webpLossyHeader(1024, 768), 0, 29)), isNull);
    expect(readImageHeader(Uint8List.fromList([...ascii('RIFF'), ...le32(0), ...ascii('WEBP'), ...ascii('ALPH'), ...List.filled(14, 0)])), isNull);
    expect(readImageHeader(Uint8List.fromList([0x49, 0x49, 0x2A, 0x00, ...List.filled(28, 0)])), isNull, reason: 'TIFF');
    expect(readImageHeader(Uint8List.fromList([0, 0, 1, 0, ...List.filled(28, 0)])), isNull, reason: 'ICO');
    expect(readImageHeader(Uint8List(0)), isNull);
  });
}
