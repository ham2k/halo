// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The Custom Activity — the escape hatch for a program HaLo has no extension
// for. Nothing here can be checked against a published list, so what the tests
// have to pin down is the ADIF the operator ends up submitting: an award's log
// checker reads MY_SIG/MY_SIG_INFO and SIG/SIG_INFO, and a wrong one is a
// rejected activation the operator finds out about weeks later.
//
// Three rules carry the weight, all of them app-polo's:
//   - SIG is the ACTIVATION's program, not the hunted reference's. A hunted
//     reference is typed as a bare string and has no program of its own.
//   - a contact crediting several of the other station's references is
//     submitted as one record each, like a POTA n-fer.
//   - the hunting control only exists while activating, because of the first
//     rule.

import 'package:flutter_test/flutter_test.dart';
import 'package:halo_extension_host/halo_extension_host.dart';

import 'support/bundles.dart';

void main() {
  requireBundles();

  Future<ExtensionHost> start() => sharedHost(['custom'], onHostCall: nullHostCall);

  Map<String, dynamic> activation({String? program = 'COTA', String reference = 'XY-1234', String name = ''}) => {
        'refs': [
          {
            'type': 'customActivation',
            if (program != null) 'mySig': program,
            'mySigInfo': reference,
            if (name.isNotEmpty) 'name': name,
          },
        ],
      };

  Map<String, dynamic> qsoHunting(List<String> refs) => {
        'refs': [for (final ref in refs) {'type': 'custom', 'ref': ref}],
      };

  /// The ADIF a record would carry, one list per record written.
  Future<List<Map<String, String>>> adif(
    ExtensionHost host, {
    required Map<String, dynamic> operation,
    Map<String, dynamic> qso = const {'refs': []},
  }) async {
    final sets = await host.invokeHook('adifFields',
        key: 'custom',
        method: 'fieldCombinationsForOneQSO',
        args: {'qso': qso, 'operation': operation},
        timeout: const Duration(seconds: 10)) as List;
    return sets
        .map((set) => {
              for (final field in (set as List).cast<Map>())
                field['name'] as String: field['value'] as String,
            })
        .toList();
  }

  group('what the log checker reads', () {
    test('an activation with no contacts to a reference is one record', () async {
      final host = await start();
      final records = await adif(host, operation: activation());

      expect(records, hasLength(1));
      expect(records.single, {'MY_SIG': 'COTA', 'MY_SIG_INFO': 'XY-1234'});
    });

    test('a contact to one of their references adds SIG from OUR program', () async {
      // The rule most easily got wrong: SIG names the PROGRAM, and the only
      // place a program is written down is our own activation. Taking it from
      // the hunted reference would leave SIG empty on every record.
      final host = await start();
      final records = await adif(host, operation: activation(), qso: qsoHunting(['AB-9']));

      expect(records, hasLength(1));
      expect(records.single, {
        'MY_SIG': 'COTA',
        'MY_SIG_INFO': 'XY-1234',
        'SIG': 'COTA',
        'SIG_INFO': 'AB-9',
      });
    });

    test('a contact crediting two of their references is submitted twice', () async {
      // Same contact, one record per reference — the n-fer rule the other
      // programs follow. Both records still name our own activation.
      final host = await start();
      final records = await adif(host, operation: activation(), qso: qsoHunting(['AB-9', 'CD-7']));

      expect(records, hasLength(2));
      expect(records.map((r) => r['SIG_INFO']), ['AB-9', 'CD-7']);
      expect(records.every((r) => r['MY_SIG_INFO'] == 'XY-1234'), isTrue);
      expect(records.every((r) => r['SIG'] == 'COTA'), isTrue);
    });

    test('an unnamed program writes no SIG rather than an empty one', () async {
      // The program field is optional. An empty MY_SIG in a submitted file is
      // worse than an absent one: it reads as a claim about a program named "".
      final host = await start();
      final records = await adif(host, operation: activation(program: null), qso: qsoHunting(['AB-9']));

      expect(records.single.containsKey('MY_SIG'), isFalse);
      expect(records.single.containsKey('SIG'), isFalse);
      expect(records.single['MY_SIG_INFO'], 'XY-1234');
      expect(records.single['SIG_INFO'], 'AB-9');
    });

    test('no activation means this extension claims nothing', () async {
      // An operation that isn't a custom activation must not have custom fields
      // written into it just because the extension is enabled.
      final host = await start();
      expect(await adif(host, operation: const {'refs': []}), isEmpty);
    });
  });

  group('the controls', () {
    test('the hunting control appears only while activating', () async {
      // Directly load-bearing rather than cosmetic: SIG is taken from the
      // activation, so a hunted reference recorded without one would export a
      // SIG_INFO with no SIG to name the program it belongs to.
      final host = await start();

      final without = await host.invokeHook('activity',
          key: 'custom',
          method: 'loggingControls',
          args: {'operation': const {'refs': []}},
          timeout: const Duration(seconds: 10)) as List;
      expect(without, isEmpty);

      final with_ = await host.invokeHook('activity',
          key: 'custom',
          method: 'loggingControls',
          args: {'operation': activation()},
          timeout: const Duration(seconds: 10)) as List;
      expect(with_, hasLength(1));
      expect((with_.single as Map)['allowsMultiple'], isTrue);
    });

    test('the operation control is a three-field form on the activation ref', () async {
      // The whole point of choosing `kind: 'form'`: the operator gets the three
      // labelled fields app-polo has, saved onto the ref by the core.
      final host = await start();
      final controls = await host.invokeHook('activity',
          key: 'custom',
          method: 'operationControls',
          args: {'operation': const {'refs': []}},
          timeout: const Duration(seconds: 10)) as List;

      final input = (controls.single as Map)['input'] as Map;
      expect(input['kind'], 'form');
      expect(input['refType'], 'customActivation');
      final keys = ((input['form'] as Map)['elements'] as List).map((e) => (e as Map)['key']);
      expect(keys, ['mySig', 'mySigInfo', 'name']);
    });
  });

  group('how a reference reads', () {
    test('the program and reference become one addressable string', () async {
      final host = await start();
      final ref = await host.invokeHook('ref:customActivation',
          key: 'custom',
          method: 'decorateRef',
          args: {
            'ref': {'type': 'customActivation', 'mySig': 'COTA', 'mySigInfo': 'XY-1234', 'name': 'XYZ Castle'},
          },
          timeout: const Duration(seconds: 10)) as Map;

      expect(ref['ref'], 'COTA XY-1234');
      expect(ref['shortLabel'], 'COTA XY-1234');
      expect(ref['label'], 'COTA XY-1234: XYZ Castle');
    });

    test('re-saving does not compound the program onto the reference', () async {
      // decorateRef runs on EVERY save, not just the first, and the edit path
      // hands back `{...existing, ...formResult}` — so the already-joined `ref`
      // comes back in. Reading it as a fallback for the activation's reference
      // joined the program on a second time and compounded from there:
      //   "COTA XY-1234" → "COTA COTA XY-1234" → "COTA COTA COTA XY-1234"
      // straight into MY_SIG_INFO and the submitted log. An activation's
      // reference lives ONLY in mySigInfo.
      final host = await start();

      Future<Map<String, dynamic>> decorate(Map<String, dynamic> ref) async =>
          (await host.invokeHook('ref:customActivation', key: 'custom', method: 'decorateRef',
                  args: {'ref': ref}, timeout: const Duration(seconds: 10)) as Map)
              .cast<String, dynamic>();

      var ref = await decorate({'type': 'customActivation', 'mySig': 'COTA', 'mySigInfo': 'XY-1234'});
      expect(ref['ref'], 'COTA XY-1234');

      // Saved again unchanged — the common case, and idempotent before too.
      ref = await decorate({...ref, 'mySig': 'COTA', 'mySigInfo': 'XY-1234'});
      expect(ref['ref'], 'COTA XY-1234');

      // Saved with the Reference field cleared: the case that compounded.
      ref = await decorate({...ref, 'mySig': 'COTA', 'mySigInfo': ''});
      expect(ref['ref'], 'COTA', reason: 'the program alone, not re-joined onto the old value');
      ref = await decorate({...ref, 'mySig': 'COTA', 'mySigInfo': ''});
      expect(ref['ref'], 'COTA', reason: 'and it stays put however often it is saved');
    }, timeout: const Timeout(Duration(seconds: 60)));

    test('a hunted reference keeps reading its own ref, however often it is saved', () async {
      // The other half of the same rule: a hunted ref is typed as a single
      // string, so `ref` IS its reference and must keep round-tripping.
      final host = await start();
      var ref = (await host.invokeHook('ref:custom', key: 'custom-hunting', method: 'decorateRef',
              args: {'ref': {'type': 'custom', 'ref': 'AB-9'}},
              timeout: const Duration(seconds: 10)) as Map)
          .cast<String, dynamic>();
      expect(ref['ref'], 'AB-9');

      ref = (await host.invokeHook('ref:custom', key: 'custom-hunting', method: 'decorateRef',
              args: {'ref': ref}, timeout: const Duration(seconds: 10)) as Map)
          .cast<String, dynamic>();
      expect(ref['ref'], 'AB-9');
      expect(ref['shortLabel'], 'Custom AB-9');
    }, timeout: const Timeout(Duration(seconds: 60)));

    test('a hunted reference never retitles the operation', () async {
      // It describes where the OTHER station was. Titling the operation with it
      // would claim their activation as ours.
      final host = await start();
      final hunted = await host.invokeHook('ref:custom',
          key: 'custom-hunting',
          method: 'suggestOperationTitle',
          args: {
            'ref': {'type': 'custom', 'ref': 'AB-9'},
          },
          timeout: const Duration(seconds: 10));
      expect(hunted, isNull);

      final ours = await host.invokeHook('ref:customActivation',
          key: 'custom',
          method: 'suggestOperationTitle',
          args: {
            'ref': {'type': 'customActivation', 'mySig': 'COTA', 'mySigInfo': 'XY-1234', 'name': 'XYZ Castle'},
          },
          timeout: const Duration(seconds: 10)) as Map;
      expect(ours['at'], 'XY-1234');
      expect(ours['subtitle'], 'XYZ Castle');
    });

    test('an empty reference is the only thing that fails validation', () async {
      // Deliberately permissive: this activity exists for the programs whose
      // reference shapes HaLo does not know, so a pattern here would reject the
      // very references it was added to carry.
      final host = await start();
      Future<bool> valid(String ref) async => ((await host.invokeHook('ref:customActivation',
              key: 'custom',
              method: 'validateRef',
              args: {
                'ref': {'type': 'customActivation', 'ref': ref},
              },
              timeout: const Duration(seconds: 10)) as Map)['valid'] as bool);

      expect(await valid('XY-1234'), isTrue);
      expect(await valid('anything at all'), isTrue);
      expect(await valid('   '), isFalse);
      expect(await valid(''), isFalse);
    });
  });
}
