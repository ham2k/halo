// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0

import 'package:flutter_test/flutter_test.dart';
import 'package:ham2k_logger/services/deep_link_service.dart';

void main() {
  group('vfoRequest', () {
    test('reads a frequency in Hz and leaves the band to be derived', () {
      final vfo = DeepLinkService.vfoRequest(Uri.parse('com.ham2k:///vfo?frequency=14250000&mode=SSB'));
      expect(vfo?.freqKHz, 14250);
      expect(vfo?.mode, 'SSB');
      expect(vfo?.band, isNull);
    });

    test('drops a band sent alongside a frequency', () {
      // The band must be DERIVED from the frequency, not read beside it: a
      // sender that fills both from stale state would otherwise tune 20m and
      // label the QSO 40m. Both params are present precisely so passing
      // `params['band']` straight through fails here.
      final vfo = DeepLinkService.vfoRequest(Uri.parse('com.ham2k:///vfo?frequency=14250000&band=40m'));
      expect(vfo?.freqKHz, 14250);
      expect(vfo?.band, isNull);
    });

    test('reads a frequency in kHz, which outranks the Hz spelling', () {
      // app-polo's doc comment claims `frequency` wins; its code reads `freq`
      // first, and the companion apps were built against the code.
      final vfo = DeepLinkService.vfoRequest(Uri.parse('com.ham2k:///vfo?freq=7185&frequency=14250000'));
      expect(vfo?.freqKHz, 7185);
    });

    test('takes an explicit band only when no frequency was sent', () {
      final vfo = DeepLinkService.vfoRequest(Uri.parse('com.ham2k:///vfo?band=20m&mode=cw'));
      expect(vfo?.band, '20m');
      expect(vfo?.freqKHz, isNull);
      expect(vfo?.mode, 'CW');
    });

    test('accepts the two-slash form a relayed link arrives in', () {
      expect(DeepLinkService.vfoRequest(Uri.parse('com.ham2k://vfo?freq=7185'))?.freqKHz, 7185);
    });

    test('answers null for a link naming no part of a VFO', () {
      // Not an empty VFO write: a link that says nothing must leave the
      // operator's radio state exactly where it was.
      expect(DeepLinkService.vfoRequest(Uri.parse('com.ham2k:///vfo')), isNull);
      expect(DeepLinkService.vfoRequest(Uri.parse('com.ham2k:///vfo?mode=')), isNull);
    });

    test('answers null for another app’s scheme, and for another command', () {
      expect(DeepLinkService.vfoRequest(Uri.parse('com.example:///vfo?freq=7185')), isNull);
      expect(DeepLinkService.vfoRequest(Uri.parse('com.ham2k:///qso?freq=7185')), isNull);
    });
  });

  group('qsoRequest', () {
    test('carries the station, the radio state and the timestamp', () {
      final qso = DeepLinkService.qsoRequest(Uri.parse('com.ham2k:///qso?their.call=n0call&frequency=7200000&mode=cw&startAtMillis=1750000000000'));
      expect(qso?.calls, ['N0CALL']);
      expect(qso?.freqKHz, 7200);
      expect(qso?.mode, 'CW');
      expect(qso?.startAtMillis, 1750000000000);
    });

    test('reads a multi-operator activation as a list of calls', () {
      // The caller comma-joins these back into the call field, where HaLo
      // logs one QSO per call. Splitting here is what catches a list that is
      // only punctuation before it reaches the field.
      final qso = DeepLinkService.qsoRequest(Uri.parse('com.ham2k:///qso?their.call=KI2D, kc6x'));
      expect(qso?.calls, ['KI2D', 'KC6X']);
    });

    test('keeps a portable callsign whole once the URI has decoded it', () {
      final qso = DeepLinkService.qsoRequest(Uri.parse('com.ham2k:///qso?their.call=S5%2FKC6X%2FP'));
      expect(qso?.calls, ['S5/KC6X/P']);
    });

    test('reads hunted references as key/ref pairs, types unresolved', () {
      final qso = DeepLinkService.qsoRequest(Uri.parse('com.ham2k:///qso?their.call=N0CALL&their.refs=pota:US-1234,sota:W6%2FCT-006'));
      // The key is the EXTENSION's, not a ref type: `pota` still has to become
      // `pota`/`potaActivation` via the host before anything is logged.
      expect(qso?.theirRefs, [(key: 'pota', ref: 'US-1234'), (key: 'sota', ref: 'W6/CT-006')]);
    });

    test('answers null without a station to work', () {
      // Frequency alone is a /vfo link's job; treating it as a QSO would put
      // an empty contact in front of the operator.
      expect(DeepLinkService.qsoRequest(Uri.parse('com.ham2k:///qso?frequency=7200000')), isNull);
      expect(DeepLinkService.qsoRequest(Uri.parse('com.ham2k:///qso?their.call=%20,')), isNull);
    });
  });

  group('operationRequest', () {
    test('reads the references an activation is for', () {
      final refs = DeepLinkService.operationRequest(Uri.parse('com.ham2k:///operation?our.refs=pota:US-1234,sota:W6%2FCT-006'));
      expect(refs, [(key: 'pota', ref: 'US-1234'), (key: 'sota', ref: 'W6/CT-006')]);
    });

    test('answers null rather than proposing an operation with no references', () {
      // find-or-create on an empty ref list would match, or create, an
      // arbitrary operation and open it.
      expect(DeepLinkService.operationRequest(Uri.parse('com.ham2k:///operation')), isNull);
      expect(DeepLinkService.operationRequest(Uri.parse('com.ham2k:///operation?our.refs=pota:')), isNull);
    });
  });

  group('refPairsIn', () {
    test('splits on the first colon, so a reference may contain one', () {
      expect(DeepLinkService.refPairsIn('gma:DL/AL-001:2'), [(key: 'gma', ref: 'DL/AL-001:2')]);
    });

    test('drops entries with no key, and keeps the order written', () {
      expect(DeepLinkService.refPairsIn(':US-1234,pota:US-1,sota:W6/CT-006'), [(key: 'pota', ref: 'US-1'), (key: 'sota', ref: 'W6/CT-006')]);
    });

    test('leaves the reference exactly as sent', () {
      // Normalizing a code here would decide what `validateRef` exists to
      // decide, and would do it without the owning extension's regex.
      expect(DeepLinkService.refPairsIn('pota:us-1234'), [(key: 'pota', ref: 'us-1234')]);
    });
  });
}
