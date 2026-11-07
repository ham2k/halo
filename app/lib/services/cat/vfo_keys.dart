// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The VFO keys — the `vfo.*` commands, a fine or coarse step up or down —
// as the Operation and Chasing views hear them
// (docs/design/keyboard-shortcuts.md).

import 'package:flutter/services.dart' show KeyDownEvent, KeyEvent, LogicalKeyboardKey;
import 'package:halo_core/halo_core.dart' show superModeForMode;
import 'package:halo_i18n/halo_i18n.dart';
import 'package:halo_widgets/halo_widgets.dart';

import '../midi/midi_codec.dart' show midiStepFrequency;
import '../radio_service.dart';
import '../status_bar_service.dart';

final _arrows = {LogicalKeyboardKey.arrowUp, LogicalKeyboardKey.arrowDown, LogicalKeyboardKey.arrowLeft, LogicalKeyboardKey.arrowRight};

const _commands = [
  (id: vfoFineUpCommandId, up: true, coarse: false),
  (id: vfoFineDownCommandId, up: false, coarse: false),
  (id: vfoCoarseUpCommandId, up: true, coarse: true),
  (id: vfoCoarseDownCommandId, up: false, coarse: true),
];

/// A VFO key, for a view that logs — Operation, Chasing — while it is the
/// front-most route: tunes VFO [vfo], with or without a radio connected,
/// since the VFO is what the next contact logs. True when [event] was one.
///
/// None of them tunes while a logged contact is loaded ([qsoLoaded]): the
/// panel shows that contact, not the VFO, so a tune there would move the
/// radio unseen, and ⌥↑/⌥↓ page the list instead. An arrow key, whatever its
/// modifiers, stays the field's in any text field but the main logging
/// fields ([focusInFreeText]) — a note, the Find bar — and a control's that
/// steps on it ([ArrowKeysOwner]). Everywhere else it is the VFO's, and the
/// logging fields hear that it was taken ([takeKeyEvent]) rather than move
/// the caret or select as well. Taken even with no frequency to step from, saying so on
/// the status bar: paging instead would surprise.
bool onVfoKey(KeyEvent event, {required RadioService radio, required StatusBarService statusBar, required String vfo, required bool qsoLoaded}) {
  final bindings = keyBindings.value;
  for (final command in _commands) {
    if (bindings.claim(command.id, event) == null) continue;
    if (qsoLoaded) return false;
    if (_arrows.contains(event.logicalKey) && (focusInFreeText() || ArrowKeysOwner.hasFocus())) return false;
    takeKeyEvent(event);
    // Said once a press: a held key's repeats would restate it each time.
    if (!stepVfoByKey(radio, vfo, up: command.up, coarse: command.coarse) && event is KeyDownEvent) {
      statusBar.setMessage(
        key: 'vfo-keys:no-frequency',
        icon: 'keyboard',
        text: t.operation.vfoKeysNoFrequency,
        dismissAfter: StatusBarService.completedDismissDelay,
      );
    }
    return true;
  }
  return false;
}

/// One key press's step in [mode], in Hz. CW and the data modes step a
/// tenth as far as phone: their signals sit that much closer together.
int vfoKeyStepHz(String? mode, {required bool coarse}) {
  final narrow = switch (superModeForMode(mode)) {
    'CW' || 'Digital' => true,
    _ => false,
  };
  final fine = narrow ? 10 : 100;
  return coarse ? fine * 10 : fine;
}

/// Tunes VFO [key] one step up or down, landing on the step's grid as a MIDI
/// knob does ([midiStepFrequency]): a 100 Hz press up from 7 074 037 Hz lands
/// on 7 074 100, not 7 074 137. From the operator's tune while it is
/// held, so presses in a row add up before the radio answers; from the
/// radio's own report while a band picked by name has left no frequency —
/// only a report on that band, since one from a radio since disconnected or
/// left would tune the VFO back to a band the operator moved off. False with
/// nothing to step from.
bool stepVfoByKey(RadioService radio, String key, {required bool up, required bool coarse}) {
  final vfo = radio.vfo(key), real = radio.realVfo(key);
  final onBand = vfo.band == null || real.band == vfo.band;
  final freqKHz = vfo.freq ?? (onBand ? real.freq : null);
  if (freqKHz == null || freqKHz <= 0) return false;
  final step = vfoKeyStepHz(vfo.mode ?? (onBand ? real.mode : null), coarse: coarse);
  final hz = midiStepFrequency((freqKHz * 1000).round(), up ? 1 : -1, step);
  if (hz <= 0) return false;
  // Not `dial`, as a MIDI knob is: a press lands on its grid, a target as
  // exact as a typed one, which Smart VFO Snap settling it as a turn would
  // move off.
  radio.setVfo(key, freq: hz / 1000);
  return true;
}
