// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The app applies a placement's patches to the scene it shows, as the kernel
// applies them to the scene it last sent (extensions/sdk/src/scenePatch.ts):
// the two apart, the next render is compared with a scene the app does not
// have, and the operator is shown one the extension never rendered. So each
// step does here exactly what it does there, a patch shares what it did not
// touch — which is what lets the parser skip reading it again — and one that
// cannot apply is refused whole, naming the step, never applied in part.

import 'package:flutter_test/flutter_test.dart';
import 'package:ham2k_logger/views/operation/panel_scene/scene_model.dart';
import 'package:ham2k_logger/views/operation/panel_scene/scene_patch.dart';

Map<String, dynamic> marker(String id, [double lat = 0]) => {'id': id, 'lat': lat, 'lon': 0};

Map<String, dynamic> scene(List<Object> markers) => {
  'version': 1,
  'width': 300,
  'height': 200,
  'values': {'zoom': 2},
  'layers': [
    {'id': 'bg', 'x': 0, 'y': 0, 'width': 300, 'height': 200, 'svg': '<svg xmlns="http://www.w3.org/2000/svg"/>'},
  ],
  'controls': [
    {'id': 'map', 'kind': 'map', 'label': 'Map', 'x': 0, 'y': 0, 'width': 300, 'height': 200, 'markers': markers},
  ],
};

List<String> idsOf(Map<dynamic, dynamic> doc) => [for (final m in ((doc['controls'] as List).first as Map)['markers'] as List) (m as Map)['id'] as String];

void main() {
  test('each step does as it says', () {
    final before = scene([marker('a'), marker('b')]);
    List<String> after(List<Object> steps) => idsOf(patchScene(before, steps));
    expect(
      after([
        {
          'insert': ['controls', 'map', 'markers'],
          'value': marker('n'),
          'before': 'b',
        },
      ]),
      ['a', 'n', 'b'],
    );
    expect(
      after([
        {
          'set': ['controls', 'map', 'markers', 'n'],
          'value': marker('n'),
        },
      ]),
      ['a', 'b', 'n'],
    );
    expect(
      after([
        {
          'remove': ['controls', 'map', 'markers', 'a'],
        },
      ]),
      ['b'],
    );
    final merged = patchScene(before, [
      {
        'merge': ['controls', 'map'],
        'value': {'label': 'Contacts', 'markers': null},
      },
    ]);
    final control = (merged['controls'] as List).first as Map;
    expect(control['label'], 'Contacts');
    expect(control.containsKey('markers'), isFalse, reason: 'a null field is removed');
  });

  test('a patch shares everything it did not touch, and the scene it patched is left as it was', () {
    final before = scene([marker('a'), marker('b')]);
    final after = patchScene(before, [
      {
        'merge': ['controls', 'map', 'markers', 'b'],
        'value': {'lat': 5},
      },
    ]);
    Map<dynamic, dynamic> mapOf(Map<dynamic, dynamic> doc) => (doc['controls'] as List).first as Map;
    expect(identical(after['layers'], before['layers']), isTrue);
    expect(identical((mapOf(after)['markers'] as List).first, (mapOf(before)['markers'] as List).first), isTrue);
    expect(identical(mapOf(after), mapOf(before)), isFalse);
    expect(((mapOf(before)['markers'] as List)[1] as Map)['lat'], 0);
    final scene0 = PanelScene(before);
    final scene1 = PanelScene(after, previous: scene0);
    expect(identical(scene1.layers.first, scene0.layers.first), isTrue, reason: 'read once');
    expect(identical(scene1.controls.first.map!.markers.first, scene0.controls.first.map!.markers.first), isTrue, reason: 'read once');
    expect(scene1.controls.first.map!.markers[1].lat, 5);
  });

  // Many steps through one list copy it once: copied for each, a patch of a
  // thousand markers copies four thousand a thousand times.
  test('steps through the same list copy it once, and find their items by id however it has changed', () {
    final before = scene([for (var i = 0; i < 100; i++) marker('m$i')]);
    final after = patchScene(before, [
      for (var i = 0; i < 100; i += 2)
        {
          'remove': ['controls', 'map', 'markers', 'm$i'],
        },
      {
        'insert': ['controls', 'map', 'markers'],
        'value': marker('x'),
        'before': 'm51',
      },
      {
        'merge': ['controls', 'map', 'markers', 'm99'],
        'value': {'lat': 9},
      },
    ]);
    expect(idsOf(after), [
      for (var i = 1; i < 100; i += 2) ...[if (i == 51) 'x', 'm$i'],
    ]);
    expect(((((after['controls'] as List).first as Map)['markers'] as List).last as Map)['lat'], 9);
  });

  test('a step that cannot apply is refused, naming it', () {
    final before = scene([marker('a')]);
    for (final (steps, said) in <(List<Object>, String)>[
      (
        [
          {
            'set': ['controls', 'nope', 'label'],
            'value': 'x',
          },
        ],
        'step 1: controls › nope is not there',
      ),
      (
        [
          {
            'insert': ['controls', 'map', 'markers'],
            'value': marker('a'),
          },
        ],
        'already has a',
      ),
      (
        [
          {
            'set': ['controls', 'map', 'markers', 'a'],
            'value': marker('b'),
          },
        ],
        'with the id a',
      ),
      (
        [
          {
            'remove': ['values', 'missing'],
          },
        ],
        'is not there',
      ),
      (
        [
          {
            'merge': ['width'],
            'value': {'a': 1},
          },
        ],
        'not an object to merge into',
      ),
      (
        [
          {
            'set': ['values', 'zoom'],
            'value': 3,
          },
          {'set': <String>[], 'value': <String, dynamic>{}},
        ],
        'step 2: a step names a place',
      ),
      (
        [
          {
            'set': ['values'],
            'value': 1,
            'remove': ['values'],
          },
        ],
        'one of set, merge, remove or insert',
      ),
      (
        [
          {
            'set': ['strings', '__proto__'],
            'value': 'x',
          },
        ],
        'names no __proto__',
      ),
    ]) {
      expect(() => patchScene(before, steps), throwsA(isA<FormatException>().having((e) => e.message, 'message', contains(said))));
    }
  });
}
