// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0

import 'package:halo_i18n/halo_i18n.dart';

import '../halo_services.dart';

/// The keyer's command actions — WPM, KEYER, and ESM/RUN/SP — for
/// [HaLoServices.handleCommandAction]. Null is success: the hook's own
/// `confirm` is the operator's feedback, and a message here would be a second
/// one saying the same thing.
CommandActionOutcome? keyerCommandAction(HaLoServices services, String action, Map<String, dynamic>? params) {
  switch (action) {
    case 'setKeyerSpeed':
      // WPM command ("20WPM"): straight to radio1's keyer. Unlike power
      // there is no app-side value to fall back on — the speed is the
      // radio's — so with nothing connected that can key, the command
      // fails out loud rather than confirming a change nothing heard.
      final wpm = params?['wpm'];
      if (wpm is! num) return null;
      // The hooks decline while the experiment is off, but an action can
      // still arrive — an interpretation computed before the flip, or an
      // extension of its own — and must not reach the radio quietly.
      if (!services.settings.experimentEnabled('keyer') /* stored key, see experiments.yaml */) {
        return (text: t.commands.keyerExperimentOff, failed: true);
      }
      return services.cat.setKeyerSpeed(wpm.round()) ? null : (text: t.commands.noCwKeyer, failed: true);
    case 'showKeyer':
      // KEYER / MACROS: the keyer area listens for this. With the
      // experiment off no area is mounted to hear it; with nothing that can
      // key there is nothing for it to do — say so rather than confirm.
      if (!services.settings.experimentEnabled('keyer') /* stored key, see experiments.yaml */) {
        return (text: t.commands.keyerExperimentOff, failed: true);
      }
      if (!services.cat.canKeyCw && !services.cat.canPlayVoice) return (text: t.commands.noKeyer, failed: true);
      // The area lives in an operation's logging panel; from Home there is
      // nothing to show, and confirming would be a lie.
      if (services.currentOperationContext == null) return (text: t.commands.keyerNeedsOperation, failed: true);
      services.cat.showKeyerArea();
      return null;
    case 'setEnterSends':
      // ESM / RUN / SP. Written whether or not anything can key right now —
      // it is how the operator wants Enter to behave once one does — but
      // said to be doing nothing when it would, rather than confirmed.
      if (!services.settings.experimentEnabled('keyer') /* stored key, see experiments.yaml */) {
        return (text: t.commands.keyerExperimentOff, failed: true);
      }
      if (!services.settings.experimentEnabled('esm') /* stored key, see experiments.yaml */) {
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
