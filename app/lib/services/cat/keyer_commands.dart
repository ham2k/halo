// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0

import 'package:halo_i18n/halo_i18n.dart';

import '../../views/app_shell/home_rail_state.dart';
import '../halo_services.dart';

/// The keyer's command actions — WPM, KEYER, and ESM — for
/// [HaLoServices.handleCommandAction]. Null is success: the hook's own
/// `confirm` is the operator's feedback, and a message here would be a second
/// one saying the same thing.
CommandActionOutcome? keyerCommandAction(HaLoServices services, String action, Map<String, dynamic>? params) {
  switch (action) {
    case 'setKeyerSpeed':
      // WPM command ("20WPM"): straight to the keyer of the operator's
      // radio — under SO2R, the set they are in. Unlike power
      // there is no app-side value to fall back on — the speed is the
      // radio's — so with nothing connected that can key, the command
      // fails out loud rather than confirming a change nothing heard.
      final wpm = params?['wpm'];
      if (wpm is! num) return null;
      return services.cat.setKeyerSpeed(wpm.round()) ? null : (text: t.commands.noCwKeyer, failed: true);
    case 'showKeyer':
      // The command dialog can sit over Chasing. A full page covering Home
      // puts Chasing's logging panel out of reach. Its keyer pill follows
      // what the station has configured while its sets can change separately.
      final operationContext = services.currentOperationContext;
      final chasing =
          operationContext == null &&
          homeRail.destination == HomeDestination.chase &&
          homeRail.homeChromeShowing &&
          services.settings.experimentEnabled('chase') /* stored key, see experiments.yaml */;
      final cat = services.cat;
      final canOpen = chasing ? cat.hasKeyer : cat.canKeyCw || cat.canPlayVoice;
      if (!canOpen) return (text: t.commands.noKeyer, failed: true);
      if (operationContext == null && !chasing) return (text: t.commands.keyerNeedsOperation, failed: true);
      cat.openKeyerControl();
      return null;
    case 'setEnterSends':
      // ESM. Written whether or not anything can key right now —
      // it is how the operator wants Enter to behave once one does — but
      // said to be doing nothing when it would, rather than confirmed.
      if (!services.settings.experimentEnabled('esm') /* stored key, see experiments.yaml */ ) {
        return (text: t.commands.esmExperimentOff, failed: true);
      }
      services.cat.setEnterSends(on: params?['on'] as bool?, running: params?['running'] as bool?);
      if (services.cat.enterSends.value.on && !services.cat.canKeyCw && !services.cat.canPlayVoice) {
        return (text: t.commands.noKeyer, failed: true);
      }
      return null;
  }
  return null;
}
