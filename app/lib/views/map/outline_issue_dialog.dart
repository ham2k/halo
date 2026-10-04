// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// An operator's report that a reference's outline is wrong, from the credit
// line under a map's outlines. Sent as a diagnostic (ErrorReportingService),
// so it reaches whoever maintains the outlines with the reference, the
// document it came from, and where the operator was looking.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:halo_core/halo_core.dart';
import 'package:halo_i18n/halo_i18n.dart';
import 'package:halo_widgets/halo_widgets.dart';

import '../../services/error_reporting_service.dart';
import 'map_marker_data.dart';
import 'map_zoom_controller.dart';
import 'ref_shapes.dart';

/// One outline an operator can report: the reference it outlines, by the
/// marker id the map knows it by, and the document it was drawn from.
typedef OutlineIssueCandidate = ({String refId, String label, String? sourceName, String? sourceUrl});

enum OutlineIssueSeverity { minor, major }

typedef OutlineIssue = ({OutlineIssueCandidate outline, OutlineIssueSeverity severity, String explanation});

/// Where the operator was when they reported it — what a reviewer needs to
/// see the outline as they saw it.
typedef OutlineIssueContext = ({MapCameraSettled? camera, GridLocation? operatorLocation, String? operatorGrid});

/// Every reference [shapes] outlines, once each, in the order the map draws
/// them — only those with a piece inside [within] when given, so the list is
/// what the operator can see rather than every outline the map has loaded.
/// [keep] stays whether in view or not: the reference selected on the map.
/// An activation radius is no outline: it is drawn from the reference's own
/// coordinate, with no document behind it for a report to name.
List<OutlineIssueCandidate> outlineIssueCandidates(List<MapShapeData> shapes, {MapViewBounds? within, String? keep}) {
  final seen = <String>{};
  return [
    for (final shape in shapes)
      if (!shape.isActivationRadius && (within == null || markerIdOfShape(shape) == keep || _inView(shape, within)) && seen.add(markerIdOfShape(shape)))
        (refId: markerIdOfShape(shape), label: shape.refLabel ?? markerIdOfShape(shape), sourceName: shape.sourceName, sourceUrl: shape.sourceUrl),
  ];
}

/// Whether any of [shape]'s box falls inside [view]. [view]'s west past its
/// east is a view across the antimeridian.
bool _inView(MapShapeData shape, MapViewBounds view) {
  var south = double.infinity, north = double.negativeInfinity, west = double.infinity, east = double.negativeInfinity;
  for (final ring in shape.rings) {
    for (final p in ring) {
      south = p.latitude < south ? p.latitude : south;
      north = p.latitude > north ? p.latitude : north;
      west = p.longitude < west ? p.longitude : west;
      east = p.longitude > east ? p.longitude : east;
    }
  }
  if (north < view.south || south > view.north) return false;
  return view.west <= view.east ? east >= view.west && west <= view.east : east >= view.west || west <= view.east;
}

/// The report's title: severity first, so a list of them sorts itself.
String outlineIssueTitle(OutlineIssue issue) =>
    'Outline issue (${issue.severity == OutlineIssueSeverity.major ? 'big deal' : 'minor nit'}): ${issue.outline.label}';

/// The report's body. Plain English and fixed field names, not the operator's
/// language: it is read by whoever fixes the outline, not shown back.
String outlineIssueBody(OutlineIssue issue, OutlineIssueContext where) {
  final camera = where.camera;
  String at(double latitude, double longitude) => '${latitude.toStringAsFixed(5)}, ${longitude.toStringAsFixed(5)}';
  return [
    'Reference: ${issue.outline.label} (${issue.outline.refId})',
    'Severity: ${issue.severity == OutlineIssueSeverity.major ? 'big deal' : 'minor nit'}',
    'Source: ${issue.outline.sourceName ?? 'unknown'}',
    'Outline: ${issue.outline.sourceUrl ?? 'unknown'}',
    if (camera != null) ...[
      'Map centre: ${at(camera.camera.latitude, camera.camera.longitude)}, zoom ${camera.camera.zoom.toStringAsFixed(1)}',
      'Map view: ${at(camera.bounds.south, camera.bounds.west)} to ${at(camera.bounds.north, camera.bounds.east)}',
    ],
    if (where.operatorLocation case final location?)
      'Operator: ${where.operatorGrid ?? locationToGrid6(location.latitude, location.longitude)} (${at(location.latitude, location.longitude)})',
    '',
    issue.explanation.trim(),
  ].join('\n');
}

/// Asks which outline, how bad, and what is wrong, then sends it — telling
/// the operator whether it left the device. [preselectedRefId] is the
/// reference whose card is open, if any.
Future<void> reportOutlineIssue(
  BuildContext context, {
  required List<MapShapeData> shapes,
  String? preselectedRefId,
  required OutlineIssueContext Function() where,
}) async {
  // What is in view; all of them when the map has been panned clear of every
  // outline, rather than a dialog with nothing to pick.
  final view = where().camera?.bounds;
  final inView = outlineIssueCandidates(shapes, within: view, keep: preselectedRefId);
  final candidates = inView.isNotEmpty ? inView : outlineIssueCandidates(shapes);
  if (candidates.isEmpty) return;
  final issue = await showHaloDialog<OutlineIssue>(
    context: context,
    // Not by a stray tap or Esc: what the operator wrote would go with it.
    // Cancel is the way out.
    barrierDismissible: false,
    builder: (_) => OutlineIssueDialog(candidates: candidates, preselectedRefId: preselectedRefId),
  );
  if (issue == null) return;
  // Sent before the mounted check: the map closing while the dialog was up
  // must not drop a report the operator pressed Send on.
  final title = outlineIssueTitle(issue);
  final body = outlineIssueBody(issue, where());
  // Only a backend that took it counts — and "sending", not "sent": the
  // upload runs in the background and cannot say whether it landed.
  final sending = ErrorReportingService.diagnostic(title: title, body: body) && ErrorReportingService.reportingEnabled;
  if (!context.mounted) return;
  final t = context.t.map.outlineIssue;
  final messenger = ScaffoldMessenger.maybeOf(context);
  Future<void> copy() async {
    // Said either way: a copy that failed quietly leaves them pasting
    // nothing, the report gone with the dialog.
    try {
      await Clipboard.setData(ClipboardData(text: '$title\n\n$body'));
      messenger?.showSnackBar(haloSnackBar(t.copied));
    } catch (_) {
      messenger?.showSnackBar(haloSnackBar(t.notCopied));
    }
  }

  messenger?.showSnackBar(
    sending
        ? haloSnackBar(t.sending)
        // Kept for them to send another way, rather than lost with the dialog.
        : haloSnackBar(t.notSent, actionLabel: t.copy, onAction: copy),
  );
}

class OutlineIssueDialog extends StatefulWidget {
  const OutlineIssueDialog({super.key, required this.candidates, this.preselectedRefId});

  final List<OutlineIssueCandidate> candidates;
  final String? preselectedRefId;

  @override
  State<OutlineIssueDialog> createState() => _OutlineIssueDialogState();
}

class _OutlineIssueDialogState extends State<OutlineIssueDialog> {
  final _explanation = TextEditingController();

  /// The reference field's text: what the operator types to filter the list,
  /// and the chosen reference's label once one is picked.
  final _reference = TextEditingController();
  String? _refId;
  OutlineIssueSeverity? _severity;

  @override
  void initState() {
    super.initState();
    // The open card's reference, or the only one there is; otherwise the
    // operator picks — a guess here would file the report against the wrong
    // park.
    final ids = [for (final c in widget.candidates) c.refId];
    _refId = ids.contains(widget.preselectedRefId) ? widget.preselectedRefId : (ids.length == 1 ? ids.single : null);
    _explanation.addListener(() => setState(() {}));
    _reference.addListener(() {
      // The chosen reference is whichever one the field names — typed away
      // from, nothing is; typed back to, or arrowed onto without Enter, it
      // is. Send files against what the field shows, never a stale pick.
      // Only on a change: DropdownMenu writes the field while it builds.
      final named = _named(_reference.text);
      if (named != _refId) setState(() => _refId = named);
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Built once, not per build: a new list resets the menu's filter to
    // everything whenever the dialog rebuilds, such as on each keystroke
    // in the explanation.
    final small = Theme.of(context).textTheme.bodySmall;
    _entries = [
      for (final candidate in widget.candidates)
        DropdownMenuEntry(
          value: candidate.refId,
          label: candidate.label,
          trailingIcon: candidate.sourceName == null ? null : Text(candidate.sourceName!, style: small),
        ),
    ];
  }

  late List<DropdownMenuEntry<String>> _entries;

  /// The reference [text] names, if exactly one does; the current choice
  /// when it is among several sharing that label.
  String? _named(String text) {
    final ids = [
      for (final c in widget.candidates)
        if (c.label == text) c.refId,
    ];
    return ids.length == 1 ? ids.single : (ids.contains(_refId) ? _refId : null);
  }

  @override
  void dispose() {
    _explanation.dispose();
    _reference.dispose();
    super.dispose();
  }

  bool get _complete => _refId != null && _severity != null && _explanation.text.trim().isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final t = context.t.map.outlineIssue;
    final theme = Theme.of(context);
    final heading = theme.textTheme.labelMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant);
    return HaloDialog(
      title: Text(t.title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(t.reference, style: heading),
          const SizedBox(height: Space.xs),
          // Searchable: the Activities map can have dozens of outlines up,
          // and typing a code or a name finds one.
          DropdownMenu<String>(
            controller: _reference,
            initialSelection: _refId,
            expandedInsets: EdgeInsets.zero,
            menuHeight: dropdownMenuMaxHeight(context),
            trailingIcon: dropdownTrailingIcon,
            selectedTrailingIcon: dropdownSelectedTrailingIcon,
            enableFilter: true,
            requestFocusOnTap: true,
            leadingIcon: Icon(MdiIcons.magnify),
            onSelected: (id) => setState(() => _refId = id),
            dropdownMenuEntries: _entries,
          ),
          const SizedBox(height: Space.md),
          Text(t.severity, style: heading),
          const SizedBox(height: Space.xs),
          SegmentedButton<OutlineIssueSeverity>(
            segments: [
              ButtonSegment(value: OutlineIssueSeverity.minor, label: Text(t.minor)),
              ButtonSegment(value: OutlineIssueSeverity.major, label: Text(t.major)),
            ],
            // Nothing chosen until the operator chooses: a default would be
            // the answer most reports carried whether it was meant or not.
            emptySelectionAllowed: true,
            selected: {?_severity},
            onSelectionChanged: (selected) => setState(() => _severity = selected.firstOrNull),
          ),
          const SizedBox(height: Space.md),
          TextField(
            controller: _explanation,
            minLines: 3,
            maxLines: 6,
            keyboardType: TextInputType.multiline,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              labelText: t.explanation,
              hintText: t.explanationHint,
              hintStyle: TextStyle(color: theme.colorScheme.onSurface.withValues(alpha: 0.38)),
            ),
          ),
        ],
      ),
      cancel: TextButton(onPressed: () => Navigator.of(context).pop(), child: Text(context.t.common.cancel)),
      actions: [
        FilledButton(
          onPressed: _complete
              ? () => Navigator.of(
                  context,
                ).pop<OutlineIssue>((outline: widget.candidates.firstWhere((c) => c.refId == _refId), severity: _severity!, explanation: _explanation.text))
              : null,
          child: Text(t.send),
        ),
      ],
    );
  }
}
