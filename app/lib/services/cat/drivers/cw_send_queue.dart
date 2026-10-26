// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Feeds a message to a radio's keyer in pieces the radio's CAT command can
// hold, paced by how long each piece takes to key at the current speed.
//
// Neither CAT dialect says when its keyer is free again: CI-V's 0x17 takes
// 30 characters and NAKs a second one while the first is still going out,
// and Yaesu's memory playback has no "busy" to read at all. So the only
// way to send `CQ CQ CQ DE N0DEV N0DEV N0DEV K` (31 characters) is to send
// what fits, wait out its Morse duration, and send the rest — which is what
// this does, for both drivers, from the PARIS timing every keyer uses.
//
// Pure in its arithmetic: the split and the duration are plain functions a
// test can pin, and the queue itself only owns the one Timer between
// chunks.

import 'dart:async';

/// The speed pacing assumes until the radio has said what its keyer runs at.
const defaultCwSpeedWpm = 20;

/// What both keyers accept, in the elements a duration is computed from.
/// Not the whole Morse alphabet: a character missing here is DROPPED before
/// it reaches the radio, because what an IC-7300 or an FTDX10 does with a
/// character its keyer has no code for is not documented anywhere.
const morseElements = <String, String>{
  'A': '.-',
  'B': '-...',
  'C': '-.-.',
  'D': '-..',
  'E': '.',
  'F': '..-.',
  'G': '--.',
  'H': '....',
  'I': '..',
  'J': '.---',
  'K': '-.-',
  'L': '.-..',
  'M': '--',
  'N': '-.',
  'O': '---',
  'P': '.--.',
  'Q': '--.-',
  'R': '.-.',
  'S': '...',
  'T': '-',
  'U': '..-',
  'V': '...-',
  'W': '.--',
  'X': '-..-',
  'Y': '-.--',
  'Z': '--..',
  '0': '-----',
  '1': '.----',
  '2': '..---',
  '3': '...--',
  '4': '....-',
  '5': '.....',
  '6': '-....',
  '7': '--...',
  '8': '---..',
  '9': '----.',
  '.': '.-.-.-',
  ',': '--..--',
  '?': '..--..',
  '/': '-..-.',
  '=': '-...-',
  '+': '.-.-.',
  '-': '-....-',
  '@': '.--.-.',
};

/// [text] uppercased, with every character the keyers cannot send removed
/// and runs of whitespace collapsed to one space. Empty when nothing
/// sendable remains.
String sanitizeCwText(String text) {
  final buffer = StringBuffer();
  var pendingSpace = false;
  for (final char in text.toUpperCase().split('')) {
    if (char.trim().isEmpty) {
      pendingSpace = buffer.isNotEmpty;
      continue;
    }
    if (!morseElements.containsKey(char)) continue;
    if (pendingSpace) buffer.write(' ');
    pendingSpace = false;
    buffer.write(char);
  }
  return buffer.toString();
}

/// [text] (already sanitized) cut into pieces of at most [maxLength]
/// characters, on word boundaries wherever a word fits, so a chunk never
/// ends mid-callsign and the pause between chunks lands where a word gap
/// belongs anyway. A single word longer than [maxLength] is cut where it
/// must be.
List<String> splitCwText(String text, int maxLength) {
  assert(maxLength > 0);
  final chunks = <String>[];
  var current = '';
  for (final word in text.split(' ')) {
    if (word.isEmpty) continue;
    if (word.length > maxLength) {
      if (current.isNotEmpty) chunks.add(current);
      current = '';
      for (var i = 0; i < word.length; i += maxLength) {
        chunks.add(word.substring(i, i + maxLength > word.length ? word.length : i + maxLength));
      }
      continue;
    }
    if (current.isEmpty) {
      current = word;
    } else if (current.length + 1 + word.length <= maxLength) {
      current = '$current $word';
    } else {
      chunks.add(current);
      current = word;
    }
  }
  if (current.isNotEmpty) chunks.add(current);
  return chunks;
}

/// How long the keyer takes to send [text] at [wpm], PARIS timing: a dit is
/// `1200 / wpm` ms, a dah three dits, one dit between elements, three
/// between characters, seven between words — and seven more at the end, so
/// the next chunk follows this one by exactly the word gap the split put
/// there.
Duration cwDuration(String text, int wpm) {
  final ditMs = 1200 / wpm;
  var dits = 0;
  var first = true;
  for (final char in text.split('')) {
    if (char == ' ') {
      // Replaces the three-dit character gap the previous character was
      // followed by with a seven-dit word gap.
      dits += 4;
      continue;
    }
    final elements = morseElements[char];
    if (elements == null) continue;
    if (!first) dits += 3;
    first = false;
    for (var i = 0; i < elements.length; i++) {
      if (i > 0) dits += 1;
      dits += elements[i] == '-' ? 3 : 1;
    }
  }
  dits += 7;
  return Duration(milliseconds: (dits * ditMs).round());
}

/// What is going out right now, for a surface that shows it: the message
/// as keyed, and when each of its characters is expected to finish, from the
/// moment the message started. Estimated from the same PARIS arithmetic the
/// pacing uses — the radio reports nothing about its progress.
class CwSendProgress {
  /// Which message this is — the same across the reports one message gets
  /// as the queue behind it changes, so a surface animating through it
  /// knows a re-report is not a new start. Two identical texts pressed in
  /// a row are two ids.
  final int id;

  /// The sanitized message, every character of which is an entry in
  /// [characterEnds].
  final String text;

  /// When character `i` finishes keying, measured from the message's start.
  final List<Duration> characterEnds;

  /// The messages waiting behind this one, in order — shown as soon as they
  /// are pressed, not once they start.
  final List<String> pending;

  /// [pending]'s ids, in the same order — what [CwSendQueue.dropPending]
  /// takes, so dropping one names it rather than its position.
  final List<int> pendingIds;

  /// How many characters the keyer itself has reported keyed — a Winkeyer
  /// echoes each one. Null from a CAT keyer, which reports nothing, leaving
  /// [characterEnds] as the only guide.
  final int? sentCount;

  const CwSendProgress({
    required this.id,
    required this.text,
    required this.characterEnds,
    this.pending = const [],
    this.pendingIds = const [],
    this.sentCount,
  });

  /// When the last character finishes — the whole message's length.
  Duration get total => characterEnds.isEmpty ? Duration.zero : characterEnds.last;

  /// How many characters have finished [elapsed] into the message.
  int sentAt(Duration elapsed) {
    var count = 0;
    while (count < characterEnds.length && characterEnds[count] <= elapsed) {
      count++;
    }
    return count;
  }
}

/// [cwDuration]'s per-character view: when each character of [text]
/// (already sanitized) finishes at [wpm], from the start. The character
/// gap that follows a character is charged to the NEXT one, so a character
/// reads as sent the moment its last element ends — a space is the seven-dit
/// word gap, charged to itself.
List<Duration> cwCharacterEnds(String text, int wpm) {
  final ditMs = 1200 / wpm;
  final ends = <Duration>[];
  var dits = 0;
  var pendingGap = 0;
  for (final char in text.split('')) {
    if (char == ' ') {
      // The word gap replaces the character gap: 7 in place of 3.
      dits += 7;
      pendingGap = 0;
      ends.add(Duration(milliseconds: (dits * ditMs).round()));
      continue;
    }
    final elements = morseElements[char];
    if (elements == null) continue;
    dits += pendingGap;
    for (var i = 0; i < elements.length; i++) {
      if (i > 0) dits += 1;
      dits += elements[i] == '-' ? 3 : 1;
    }
    pendingGap = 3;
    ends.add(Duration(milliseconds: (dits * ditMs).round()));
  }
  return ends;
}

/// One message as enqueued: its chunks, and the text a progress report
/// names it by.
class _Message {
  final int id;
  final String text;
  final List<String> chunks;
  _Message(this.id, this.text, this.chunks);
}

/// The queue one [CwKeyerSession] owns — see this file's header.
class CwSendQueue {
  /// The most characters one CAT command may carry.
  final int maxChunkLength;

  /// Puts one chunk on the wire.
  final void Function(String chunk) send;

  /// The keyer's current speed, or null while the radio has not said.
  final int? Function() speedWpm;

  /// Told what message is going out as each one starts, again whenever the
  /// queue behind it changes, and null when the queue falls silent —
  /// cleared or drained.
  final void Function(CwSendProgress? progress)? onProgress;

  int _nextId = 1;

  final _pending = <_Message>[];

  /// The message whose chunks are going out, and how many of them are still
  /// to be sent.
  _Message? _current;
  int _currentChunkIndex = 0;
  Timer? _timer;

  CwSendQueue({required this.maxChunkLength, required this.send, required this.speedWpm, this.onProgress});

  /// A chunk is estimated to still be keying, whether or not more wait
  /// behind it.
  bool get sending => _timer != null;

  /// Queues [text] after whatever is already going out. Nothing sendable in
  /// it, nothing happens.
  void enqueue(String text) {
    final sanitized = sanitizeCwText(text);
    final chunks = splitCwText(sanitized, maxChunkLength);
    if (chunks.isEmpty) return;
    _pending.add(_Message(_nextId++, sanitized, chunks));
    if (_timer == null) {
      _sendNext();
    } else {
      // Already keying: the new message shows up behind the current one
      // right away, rather than when its turn comes.
      _reportCurrent();
    }
  }

  /// [_current]'s timeline at the speed in force when it started — kept so
  /// a re-report for a changed queue does not recompute (and possibly move)
  /// the timeline a surface is already animating through.
  List<Duration> _currentEnds = const [];

  void _reportCurrent() {
    final current = _current;
    if (current == null) return;
    onProgress?.call(
      CwSendProgress(
        id: current.id,
        text: current.text,
        characterEnds: _currentEnds,
        pending: [for (final m in _pending) m.text],
        pendingIds: [for (final m in _pending) m.id],
      ),
    );
  }

  void _sendNext() {
    final current = _current;
    if (current == null || _currentChunkIndex >= current.chunks.length) {
      if (_pending.isEmpty) {
        _current = null;
        _timer = null;
        onProgress?.call(null);
        return;
      }
      _current = _pending.removeAt(0);
      _currentChunkIndex = 0;
      _currentEnds = cwCharacterEnds(_current!.text, speedWpm() ?? defaultCwSpeedWpm);
      // Reported once its first chunk is keying: a listener the report
      // wakes reads [sending], which is false until that chunk's timer is
      // set — and a message starting is the only report a short one makes.
      _sendNext();
      _reportCurrent();
      return;
    }
    final chunk = current.chunks[_currentChunkIndex++];
    send(chunk);
    _timer = Timer(cwDuration(chunk, speedWpm() ?? defaultCwSpeedWpm), _sendNext);
  }

  /// Drops the waiting message with [id] (from [CwSendProgress.pendingIds])
  /// and re-reports. An id no longer waiting — it started, or was dropped
  /// already — drops nothing: the queue moved on before the tap landed.
  void dropPending(int id) {
    final before = _pending.length;
    _pending.removeWhere((m) => m.id == id);
    if (_pending.length != before) _reportCurrent();
  }

  /// Drops everything not yet on the radio — the waiting messages AND the
  /// current message's chunks still to be written — but leaves the chunk
  /// the radio is keying to its estimated end, for a protocol that cannot
  /// interrupt it (Yaesu): the report keeps saying what is still going
  /// out, and nothing further is written behind it.
  void dropAllPending() {
    final current = _current;
    if (current == null) return;
    _pending.clear();
    _currentChunkIndex = current.chunks.length;
    _reportCurrent();
  }

  /// Drops everything still waiting. What is on the radio already is the
  /// caller's problem — see [CwKeyerSession.stopCw].
  void clear() {
    final wasSending = _timer != null;
    _pending.clear();
    _current = null;
    _currentChunkIndex = 0;
    _timer?.cancel();
    _timer = null;
    if (wasSending) onProgress?.call(null);
  }
}
