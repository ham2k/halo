// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The dev bridge's way to press any control: through the semantics tree, by
// the stable identifier a widget carries (`semanticId`) or by its label.
// Synthetic pointer input is the alternative, and it is the unreliable one:
// on web Flutter stacks full-size semantics containers over the buttons, so a
// browser tool's hit test lands on the container, and on native there is no
// outside input at all.

import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';

/// Held for the app's lifetime once taken: dropping it would turn the tree
/// off again under the next call.
SemanticsHandle? _handle;

/// Builds the semantics tree if nothing has asked for it yet — native builds
/// keep it off until an assistive technology does.
///
/// The wait is bounded: a hidden or minimised window draws no frames, so
/// the one the tree is built in may never come. [_tappable] then finds no
/// tree and says so.
Future<void> _ensureSemantics() async {
  if (SemanticsBinding.instance.semanticsEnabled) return;
  _handle ??= SemanticsBinding.instance.ensureSemantics();
  SchedulerBinding.instance.scheduleFrame();
  await SchedulerBinding.instance.endOfFrame.timeout(const Duration(seconds: 5), onTimeout: () {});
}

typedef _Target = ({SemanticsOwner owner, SemanticsNode node, String identifier, String label});

/// The tappable nodes on screen, in tree order. A node merged into its
/// parent is skipped — its parent carries its label and its action — and so
/// is one flagged hidden, which is how the tree marks a node clipped out of
/// view, built ahead in a scroll cache, or squeezed to no size.
///
/// `semanticId` puts its identifier on a node of its own, with the control
/// it names as a descendant, so a tappable node takes the identifier of the
/// nearest node above it that has one — unless a tappable node comes in
/// between: a button inside an identified row is not the row.
///
/// Throws a [StateError] when no view has a semantics tree.
List<_Target> _tappable() {
  final found = <_Target>[];
  void walk(SemanticsOwner owner, SemanticsNode node, String inherited) {
    var passDown = inherited;
    if (!node.isMergedIntoParent) {
      final data = node.getSemanticsData();
      final identifier = data.identifier.isNotEmpty ? data.identifier : inherited;
      if (data.hasAction(SemanticsAction.tap) && !data.flagsCollection.isHidden) {
        found.add((owner: owner, node: node, identifier: identifier, label: data.label.replaceAll('\n', ' ')));
        passDown = '';
      } else {
        passDown = identifier;
      }
    }
    node.visitChildren((child) {
      walk(owner, child, passDown);
      return true;
    });
  }

  var built = false;
  for (final view in RendererBinding.instance.renderViews) {
    final owner = view.owner?.semanticsOwner;
    final root = owner?.rootSemanticsNode;
    if (owner != null && root != null) {
      built = true;
      walk(owner, root, '');
    }
  }
  // Without this, no tree reads as an empty screen: "nothing matches".
  if (!built) throw StateError('the semantics tree is not built — is the app window hidden or minimised?');
  return found;
}

Map<String, dynamic> _describe(_Target target) => {if (target.identifier.isNotEmpty) 'identifier': target.identifier, 'label': target.label};

/// Every control [tapTarget] can reach right now.
Future<List<Map<String, dynamic>>> tapTargets() async {
  await _ensureSemantics();
  return [for (final target in _tappable()) _describe(target)];
}

/// Taps the one control [target] names: an exact identifier, else an exact
/// label, else a label containing it (case-insensitive). The first rule
/// that matches anything decides, and it has to match exactly one control.
Future<Map<String, dynamic>> tapTarget(String target) async {
  await _ensureSemantics();
  final all = _tappable();
  final wanted = target.trim().toLowerCase();
  final rules = <bool Function(_Target)>[
    (t) => t.identifier == target,
    (t) => t.label.trim().toLowerCase() == wanted,
    (t) => t.label.toLowerCase().contains(wanted),
  ];
  for (final rule in rules) {
    final matches = all.where(rule).toList();
    if (matches.isEmpty) continue;
    if (matches.length > 1) {
      return {
        'error': '"$target" matches ${matches.length} controls',
        'matches': [for (final match in matches.take(10)) _describe(match)],
      };
    }
    final match = matches.single;
    match.owner.performAction(match.node.id, SemanticsAction.tap);
    return {'tapped': _describe(match)};
  }
  return {'error': 'nothing on screen matches "$target"'};
}
