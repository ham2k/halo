// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// "It worked, here's my rig" — the report an operator files from the
// equipment editor about the radio they actually own (HALO-69).
//
// It exists because the catalogue's generic entries are deliberately vague:
// "Yaesu - Generic" reaches most of the line, and the app has no way to learn
// which radio is on the other end of the cable. Only the operator knows, and
// only they know whether it worked.
//
// The manufacturer and model are PREFILLED but not asserted: the driver's
// family name and whatever the operator called this equipment are the app's
// best guesses, offered as a head start in fields they are expected to
// correct. What the app is actually sure of goes in the body instead, where
// it cannot be mistaken for the operator's answer.
//
// The card goes through the same POST v1/reports the REPORT command uses (see
// the ham2k-lofi extension's `submitReport`), which owns the account gate and
// appends who/where/what-build.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:halo_widgets/halo_widgets.dart';

import '../i18n/strings.g.dart';
import '../main.dart';
import '../services/cat/equipment.dart';
import '../services/cat/equipment_registry.dart';
import '../services/cat/transports/serial_transport_config.dart';
import '../tools/form_chrome_labels.dart';

/// What the operator says happened, and what that makes the card.
///
/// The words that reach the CaBo card are English whatever the app's locale
/// is: they are the title's classifier, read by whoever triages the board,
/// and a wall of titles in mixed languages is a board nobody can scan. The
/// operator's own prose is of course left exactly as they wrote it.
enum _Outcome {
  /// Nothing to fix, so not a bug: a confirmation that a pairing works is a
  /// piece of work — marking the driver hardware-verified, or adding the real
  /// model to the catalogue.
  works(titleWord: 'works', kind: 'task'),
  issues(titleWord: 'works with issues', kind: 'bug'),
  fails(titleWord: 'does not work', kind: 'bug');

  final String titleWord;
  final String kind;

  const _Outcome({required this.titleWord, required this.kind});

  static _Outcome? byName(Object? value) {
    for (final outcome in values) {
      if (outcome.name == value) return outcome;
    }
    return null;
  }
}

/// The card a report becomes, before the extension adds its context block.
typedef EquipmentReport = ({String title, String body, String kind});

/// Asks for the report, then files it. Opens OVER the equipment editor and
/// leaves it standing — reporting a radio must not cost the edits in the pane
/// behind it.
Future<void> showEquipmentReportDialog(
  BuildContext context, {
  required HaLoServices services,
  required EquipmentNode node,
  required EquipmentType type,
  required EquipmentState state,
}) async {
  final st = context.t.settings.station;

  final values = await showFormPane(
    context,
    formDefinition: {
      'title': st.reportTitle,
      'elements': [
        {'type': 'markdown', 'text': st.reportIntro},
        {
          'type': 'field',
          'fieldType': 'text',
          'key': 'manufacturer',
          'label': st.reportManufacturer,
          'description': st.reportManufacturerDescription,
        },
        {
          'type': 'field',
          'fieldType': 'text',
          'key': 'model',
          'label': st.reportModel,
          'description': st.reportModelDescription,
        },
        {
          'type': 'field',
          'fieldType': 'radio',
          'key': 'outcome',
          'label': st.reportOutcome,
          'options': [
            {'value': _Outcome.works.name, 'label': st.reportOutcomeWorks},
            {'value': _Outcome.issues.name, 'label': st.reportOutcomeIssues},
            {'value': _Outcome.fails.name, 'label': st.reportOutcomeFails},
          ],
        },
        {
          'type': 'field',
          'fieldType': 'multiline',
          'key': 'comments',
          'label': st.reportComments,
          'placeholder': st.reportCommentsPlaceholder,
        },
        {
          'type': 'field',
          'fieldType': 'multiline',
          'key': 'hints',
          'label': st.reportHints,
          'placeholder': st.reportHintsPlaceholder,
        },
      ],
    },
    initialState: {...equipmentReportPrefill(node, type), 'comments': '', 'hints': ''},
    validator: (key, value, values) async => switch (key) {
      'manufacturer' when (value as String? ?? '').trim().isEmpty => st.reportManufacturerRequired,
      'model' when (value as String? ?? '').trim().isEmpty => st.reportModelRequired,
      // A radio group with nothing chosen: the title needs the word and the
      // kind needs the verdict, so there is no reasonable way to file this.
      'outcome' when _Outcome.byName(value) == null => st.reportOutcomeRequired,
      _ => null,
    },
    labels: formRendererLabelsFor(context.t, saveLabel: st.reportSend),
  );
  if (values == null || !context.mounted) return;

  await showHaloDialog<void>(
    context: context,
    // While the POST is in flight this dialog has no buttons, so the barrier
    // is the only thing an impatient operator can touch — and dismissing it
    // would throw away the one answer they are waiting for. The form pane has
    // already closed, so everything they wrote is gone with it: a failure
    // nobody sees is a report they believe was filed and was not.
    barrierDismissible: false,
    builder: (context) => _ReportSubmissionDialog(
      services: services,
      report: buildEquipmentReport(
        values: values,
        node: node,
        type: type,
        state: state,
        registry: services.cat.registry,
      ),
    ),
  );
}

/// The app's best guess at which radio this is, as a head start for the two
/// identity fields.
///
/// The driver family's FIRST WORD for the manufacturer, and the equipment's
/// own name for the model — an operator who renamed "Icom - Generic" to
/// "IC-7300" has already answered the second question.
///
/// A model named after a real radio states its own manufacturer, and that is
/// used when it does. The derivation below is the fallback for the generics
/// and the bridges, which have no brand to state.
///
/// It takes the first word because `driver.name` names a protocol family, and
/// everything after the brand is the protocol: "Icom (CI-V)", "Kenwood
/// (CAT)", "Yaesu FT-891". Cutting there leaves the brand alone WHENEVER the
/// family is a brand — which is exactly the assumption a declared
/// manufacturer exists to escape, since a QRP Labs QMX rides the Kenwood
/// driver and would otherwise arrive labelled Kenwood. The two bridges have
/// no brand to leave — "Hamlib", "flrig" — and that is the honest answer for
/// them: what the app talked to really was the bridge, and whatever radio
/// sits behind it is the operator's to name.
///
/// Neither guess is asserted anywhere. What the app is actually sure of goes
/// in the body, under its own labels, where it cannot be confused with what
/// the operator said.
///
/// The outcome is deliberately absent: every default is an answer put in the
/// operator's mouth, and it is the one field the whole report turns on.
@visibleForTesting
Map<String, dynamic> equipmentReportPrefill(EquipmentNode node, EquipmentType type) => {
      'manufacturer': type.manufacturer ?? type.driver.name.split(RegExp(r'\s')).first,
      'model': node.name,
    };

/// The operator's answers plus everything the app knows about the radio it
/// was talking to, as one card.
///
/// Pure and exported so it can be tested without a form: the value of this
/// feature is entirely in what reaches the card, and none of it is visible
/// on screen to catch by eye.
@visibleForTesting
EquipmentReport buildEquipmentReport({
  required Map<String, dynamic> values,
  required EquipmentNode node,
  required EquipmentType type,
  required EquipmentState state,
  required EquipmentRegistry registry,
}) {
  final manufacturer = (values['manufacturer'] as String? ?? '').trim();
  final model = (values['model'] as String? ?? '').trim();
  final comments = (values['comments'] as String? ?? '').trim();
  final hints = (values['hints'] as String? ?? '').trim();
  // No fallback. The form refuses to submit without a verdict, so arriving
  // here without one means the validator and this builder disagree about the
  // field — and a card titled with a verdict nobody gave is worse than no
  // card, because on the board it is indistinguishable from one they did.
  final outcome = _Outcome.byName(values['outcome']);
  if (outcome == null) {
    throw ArgumentError.value(values['outcome'], 'outcome', 'a radio report needs a verdict');
  }

  final body = [
    if (comments.isNotEmpty) ...[comments, ''],
    if (hints.isNotEmpty) ...['**Troubleshooting hints**', '', hints, ''],
    '**What the app was set up with**',
    '',
    // A list, not bare lines: consecutive lines collapse into one paragraph
    // in markdown, and this block is read as a table of facts.
    '- Reported as: $manufacturer $model — ${outcome.titleWord}',
    '- Configured as: ${type.model.name} (`${type.key}`)',
    '- Connection: ${type.transportLabel}',
    '- Driver: `${type.driver.key}`',
    ..._configLines(node, type, registry),
    ..._serialPortLines(node, type),
    '- Status: ${state.status.name}',
    // The raw exception's own words when the row shows a translated
    // stand-in instead — a developer triaging this needs the address, port
    // or errno a friendly message drops.
    if (state.error != null) '- Error: ${state.errorDetail ?? state.error}',
    // The devMode readout — what a driver worked out about the rig it was
    // talking to (a Kenwood's learned IF offset, say). Meaningless to the
    // operator, which is why it is normally hidden, and exactly what a
    // report about that rig is for.
    if (state.diagnostic != null) '- Diagnostic: ${state.diagnostic}',
  ].join('\n');

  return (
    title: [manufacturer, model, outcome.titleWord].where((part) => part.isNotEmpty).join(' '),
    body: body,
    kind: outcome.kind,
  );
}

/// The radio's own settings, labelled the way the editor labels them.
///
/// Credentials are excluded by DECLARATION, never by name, and the question is
/// asked of the WHOLE CATALOGUE rather than of the pairing this node is on.
/// That distinction is the registry's own, and `allSecretFields` states why:
/// the editor renders every variant's fields at once, so a node bound to a
/// transport with no credentials can still be carrying the password belonging
/// to the transport beside it. "What does this connection need?" is the
/// pairing's question; "may this leave the device?" is the catalogue's, and
/// this is the only code that ships a config value off the machine.
///
/// A key is dropped if any pairing calls it a secret or renders it as a secret
/// field. Either test alone covers the shipped catalogue; the second is what
/// keeps a credential added later out of reports from the moment it exists,
/// rather than until someone remembers this function.
///
/// Labels come from the node's own pairing — the wording the operator saw.
/// So do the VALUES of picker fields: a stored `COM8` identifies nothing,
/// while the option the operator picked reads "COM8 — CP2105 Dual USB to
/// UART Bridge". A value no option matches — a port since unplugged — falls
/// back to the raw one, which is still the truth about the config.
List<String> _configLines(EquipmentNode node, EquipmentType type, EquipmentRegistry registry) {
  final secrets = {...registry.allSecretFields};
  for (final candidate in registry.types) {
    for (final element in _elementsOf(candidate)) {
      final key = element['key'];
      if (key is String && element['fieldType'] == 'secret') secrets.add(key);
    }
  }

  final labels = <String, String>{};
  final optionLabels = <String, Map<String, String>>{};
  for (final element in _elementsOf(type)) {
    final key = element['key'];
    if (key is! String) continue;
    final label = element['label'];
    if (label is String && label.isNotEmpty) labels[key] = label;
    final options = element['options'];
    if (options is List) {
      optionLabels[key] = {
        for (final option in options)
          if (option is Map && option['value'] != null && option['label'] is String && option['label'] != '')
            '${option['value']}': option['label'] as String,
      };
    }
  }

  return [
    for (final entry in node.config.entries)
      if (!secrets.contains(entry.key) && entry.value != null && '${entry.value}'.isNotEmpty)
        '- ${labels[entry.key] ?? entry.key}: '
            '${_shownValue('${entry.value}', optionLabels[entry.key])}',
  ];
}

/// A pairing's form elements, or none when asking for them throws.
///
/// Asking is not free and not safe: a serial pairing's elements come from a
/// live enumeration, which opens each port to read its descriptors. This runs
/// while composing a report the operator has already written and can no
/// longer get back — the form pane closed when they pressed Send — so a rig
/// misbehaving at exactly the moment it is being reported must cost a label,
/// never the report.
///
/// Secrets survive an empty answer: the exclusion set starts from
/// [EquipmentRegistry.allSecretFields], which every transport DECLARES, and
/// this scan only adds the ones a form renders as secret without declaring
/// them. A key that reaches the card because both routes failed at once would
/// need a transport that neither declares its credential nor can list its
/// fields.
List<Map<String, dynamic>> _elementsOf(EquipmentType type) {
  try {
    return type.configElements();
  } catch (e) {
    debugPrint('[report] ${type.key}: config elements unavailable ($e)');
    return const [];
  }
}

/// A picker's value the way the operator saw it, without losing the value.
///
/// A label that already contains the stored value replaces it outright — a
/// serial port's label is `COM8 — CP2105 …`, and printing the name twice on
/// one line reads as a mistake. A label that does not keeps the value beside
/// it: `switchLayout` renders as a translated, count-interpolated sentence,
/// and a card that says only "8 antennas, 1 radio" — in the operator's
/// language — cannot be turned into a change to anything.
String _shownValue(String raw, Map<String, String>? optionLabels) {
  final label = optionLabels?[raw];
  if (label == null) return raw;
  return label.contains(raw) ? label : '$label (`$raw`)';
}

/// What the app can see of the chosen serial port, beyond its own name.
///
/// The identifiers first: two adapters can carry the same description and
/// differ only in VID:PID, which is what says whether a report is about a
/// CP2105 or an FT232, and the serial number is what tells two of the same
/// adapter apart. Whatever descriptor text the picker's label did NOT already
/// show follows — on macOS the label is often the bare device name, because
/// reading a descriptor there means opening the port and that fails.
///
/// Says so when the port is not in the enumeration at all, rather than going
/// quiet: "the app cannot see the port" is the answer to a large share of the
/// reports this feature exists to collect, and silence there reads exactly
/// like a port that was found and had nothing to say.
List<String> _serialPortLines(EquipmentNode node, EquipmentType type) {
  final transport = type.transport;
  if (transport is! SerialTransportConfig) return const [];

  final selected = SerialTransportConfig.serialPort(node.config);
  if (selected.isEmpty) return const [];

  final List<SerialPortOption> ports;
  try {
    ports = transport.availablePorts;
  } catch (e) {
    // A live hardware scan, run while composing a report the operator has
    // already written and can no longer get back — the form pane closed when
    // they pressed Send. libserialport opens each port to read its
    // descriptors, so a throw here is a real possibility and losing the
    // report to it is the one outcome worse than a missing detail line.
    debugPrint('[report] serial enumeration failed while building a report: $e');
    return ['- Port details: enumeration failed ($e)'];
  }

  for (final port in ports) {
    if (port.name != selected) continue;
    final label = port.label;
    final details = [
      if (port.serialNumber != null && port.serialNumber!.isNotEmpty) 'serial ${port.serialNumber}',
      if (port.vendorId != null && port.productId != null) 'USB ${_usbId(port.vendorId!)}:${_usbId(port.productId!)}',
      for (final text in [port.description, port.manufacturer, port.productName])
        if (text != null && text.isNotEmpty && !label.contains(text)) text,
    ];
    // One line, bullet-separated: consecutive lines would collapse into an
    // unpunctuated run-on in markdown, same as the block around it.
    return details.isEmpty ? const [] : ['- Port details: ${details.join(' • ')}'];
  }
  return ['- Port details: `$selected` is not among the ${ports.length} port(s) the app can see'];
}

/// The four-digit hex a USB id is written as everywhere it is looked up —
/// `10c4:ea60`, not `4292:59984`.
String _usbId(int value) => value.toRadixString(16).padLeft(4, '0');

/// Sends the report and says what happened. Nothing to fill in — it starts
/// working the moment it opens, because the operator has already pressed Send
/// on the form behind it.
class _ReportSubmissionDialog extends StatefulWidget {
  final HaLoServices services;
  final EquipmentReport report;

  const _ReportSubmissionDialog({required this.services, required this.report});

  @override
  State<_ReportSubmissionDialog> createState() => _ReportSubmissionDialogState();
}

class _ReportSubmissionDialogState extends State<_ReportSubmissionDialog> {
  /// Null while in flight. Held as the raw answer rather than as a formatted
  /// sentence so the wording is built in [build] under the surrounding locale,
  /// like every other string in this file — a message composed off the global
  /// translations renders in whichever language the app booted in.
  ({String? ref, String? error})? _result;

  @override
  void initState() {
    super.initState();
    unawaited(_submit());
  }

  Future<void> _submit() async {
    final result = await widget.services.extensions.submitReport(
      title: widget.report.title,
      body: widget.report.body,
      kind: widget.report.kind,
    );
    // This dialog cannot be dismissed while the call is in flight, so being
    // unmounted here means the whole route stack went — there is nobody left
    // to tell. The console still gets it: a failure with no surface anywhere
    // is how a report nobody filed looks exactly like one that was.
    if (!mounted) {
      if (result.error != null) debugPrint('[report] radio report failed unseen: ${result.error}');
      return;
    }
    setState(() => _result = result);
  }

  @override
  Widget build(BuildContext context) {
    final st = context.t.settings.station;
    final result = _result;

    return PopScope(
      // Escape and the system back button reach past a non-dismissible
      // barrier; the barrier alone would leave two ways to throw the answer
      // away and close only one of them.
      canPop: result != null,
      child: HaloDialog(
        title: Text(st.reportTitle),
        content: result == null
            ? Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
                  const SizedBox(width: Space.lg),
                  Flexible(child: Text(st.reportSending)),
                ],
              )
            : Text(switch (result) {
                (:final error?, ref: _) => st.reportFailed(error: error),
                (:final ref?, error: _) => st.reportSent(ref: ref),
                _ => st.reportSentNoRef,
              }),
        // The report has already been sent by the time this shows, so this is
        // a way out rather than a confirm: Done, plain, in the cancel slot.
        cancel: result == null
            ? null
            : TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(context.t.common.done),
              ),
      ),
    );
  }
}
