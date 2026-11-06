// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0

part of 'cat_keying.dart';

/// A send SO2R holds for the other radio ([CatKeying.waiting]): a CW
/// message's text or a memory's number, and whether a repeat chain sent it.
class WaitingSend {
  WaitingSend._(this.sequence, {this.text, this.memory, this.then = const [], required this.repeat, required this.messageOne, required this.send});

  /// When it was held, across both keyers — the oldest goes first.
  final int sequence;
  final String? text;
  final int? memory;

  /// The memories that follow [memory] in the same turn, under its key.
  final List<int> then;
  final bool repeat;

  /// Whether it is message 1 — what a callsign entered over it stops
  /// ([CatKeying.stopMessageOne]).
  final bool messageOne;

  /// Sends it, once the other radio is quiet.
  final void Function() send;
}
