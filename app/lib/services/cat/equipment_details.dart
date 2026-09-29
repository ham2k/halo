// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// What the app knows about one configured piece of equipment, written out for
// a human to read: the pairing, every non-secret config value under the label
// the operator saw it by, and whatever the platform can say about the serial
// port behind it.
//
// THE ONLY CODE THAT SHIPS A CONFIG VALUE OFF THE MACHINE, and it has two
// callers with two different privacy models. The equipment report
// (equipment_report.dart) sends it to a CaBo card because the operator wrote a
// report and pressed Send. The first-success report (cat_service.dart, via
// HaLoServices) sends it to the crash backend on the app's own initiative, and
// so is gated on `consentAppData` — see docs/design/telemetry.md § Radios,
// which owns the distinction. Anything added here reaches both.

import 'package:flutter/foundation.dart';

import 'drivers/poll_config.dart';
import 'equipment.dart';
import 'equipment_registry.dart';
import 'transports/serial_transport_config.dart';

/// The pairing and its settings, as the block both reports carry.
///
/// [state] is what the row currently shows. A caller reporting a success
/// passes the state that proves it; the manual report passes whatever the
/// operator is looking at, error and all.
List<String> equipmentSetupLines({
  required EquipmentNode node,
  required EquipmentType type,
  required EquipmentState state,
  required EquipmentRegistry registry,
}) {
  final lines = [
    '- Configured as: ${type.model.name} (`${type.key}`)',
    '- Connection: ${type.transportLabel}',
    '- Driver: `${type.driver.key}`',
    ...configLines(node, type, registry),
    ...effectiveSettingLines(node, type),
    ...serialPortLines(node, type),
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
  ];
  // Hoisted: this enumerates ports, and libserialport opens each one to read
  // its descriptors. Inside the comprehension it would do that per LINE.
  final serial = selectedPortSerial(node, type);
  return [for (final line in lines) redactSerialNumber(line, serial)];
}

/// The adapter's own serial number taken out of a line, wherever it appears.
///
/// Not just the field that names it. **macOS builds the device node out of
/// it** — `cu.usbserial-00F8E1EB0` is one CP2105's serial with a port digit
/// on the end — so a report that merely dropped the `serial …` detail would
/// still carry it in the port's name, in the picker label quoted beside it,
/// and in the `- Port:` config line. One rule applied to every finished line
/// is the only version of this that cannot be defeated by adding a line
/// somewhere else later.
///
/// A short serial is left alone. Some adapters answer `1` or `A`, and
/// redacting that would eat a character out of unrelated words while hiding
/// nothing — a value that short identifies no particular device anyway.
String redactSerialNumber(String line, String? serialNumber) {
  var redacted = line;
  if (serialNumber != null && serialNumber.length >= _redactableSerialLength) {
    redacted = redacted.replaceAll(serialNumber, _serialPlaceholder);
  }
  // AND STRUCTURALLY, whether or not a serial could be read — because the
  // case this report is composed in is the case where it CANNOT be. macOS
  // probes each descriptor by opening the port, a busy port refuses, and the
  // busiest port on the machine is the one this app's own CAT session is
  // holding: the radio that just started working. serial_transport_io.dart
  // caches that empty answer for half a minute, so `serialNumber` is null
  // exactly here, while the device NODE still spells the serial out. Keyed
  // off the node's shape instead, which needs nothing read from the port.
  return redacted.replaceAllMapped(_usbNodeIdentifier, (match) => '${match[1]}$_serialPlaceholder');
}

/// `cu.usbserial-01AF7D0E1` / `cu.usbmodem14201` — the prefix macOS builds a
/// node from, and the device-identifying tail it appends. The tail carries
/// the port index on the end of the serial, so redacting it costs the
/// ordinal too; the ordinal is worth less than the fingerprint is worth
/// hiding, and the picker's own "port N of M" says it where it is known.
///
/// The separator is optional and may be a SPACE. A port whose descriptors
/// were all refused gets a name derived from its node — dashes out, words
/// capitalised — so the very line most in need of redacting is the one where
/// `usbserial-01AF7D0E1` has already become `Usbserial 01AF7D0E1`. Matching
/// only the hyphen would sail straight past it.
final _usbNodeIdentifier = RegExp(r'(usb(?:serial|modem)[-_ ]?)([A-Za-z0-9]+)', caseSensitive: false);

const _serialPlaceholder = '<serial>';

/// Below this many characters a serial is not a fingerprint, and redacting it
/// would corrupt the line around it.
const _redactableSerialLength = 4;

/// The serial number of the port this node is configured on, or null when
/// there isn't one, the platform doesn't report it, or asking throws.
///
/// A second enumeration, and deliberately so: [serialPortLines] does its own,
/// and merging them would hand this file a ports list to thread through every
/// helper for one string. Enumeration is not free — libserialport opens each
/// port to read descriptors — but a report is composed once, by hand or by a
/// radio that just started working, and never in a loop.
String? selectedPortSerial(EquipmentNode node, EquipmentType type) {
  final transport = type.transport;
  if (transport is! SerialTransportConfig) return null;
  final selected = SerialTransportConfig.serialPort(node.config);
  if (selected.isEmpty) return null;
  try {
    for (final port in transport.availablePorts) {
      if (port.name == selected) return port.serialNumber;
    }
  } catch (e) {
    // Same reasoning as [serialPortLines]: a rig misbehaving while a report
    // is composed must never cost the report. Returning null here only means
    // nothing is redacted — and a platform that cannot enumerate is one that
    // told us no serial number to begin with.
    debugPrint('[report] serial enumeration failed while redacting: $e');
  }
  return null;
}

/// The radio's own settings, labelled the way the editor labels them.
///
/// Credentials are excluded by DECLARATION, never by name, and the question is
/// asked of the WHOLE CATALOGUE rather than of the pairing this node is on.
/// That distinction is the registry's own, and `allSecretFields` states why:
/// the editor renders every variant's fields at once, so a node bound to a
/// transport with no credentials can still be carrying the password belonging
/// to the transport beside it. "What does this connection need?" is the
/// pairing's question; "may this leave the device?" is the catalogue's.
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
List<String> configLines(EquipmentNode node, EquipmentType type, EquipmentRegistry registry) {
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
          if (option is Map && option['value'] != null && option['label'] is String && option['label'] != '') '${option['value']}': option['label'] as String,
      };
    }
  }

  return [
    for (final entry in node.config.entries)
      if (!secrets.contains(entry.key) && !_statedByEffect.contains(entry.key) && entry.value != null && '${entry.value}'.isNotEmpty)
        '- ${labels[entry.key] ?? entry.key}: '
            '${_shownValue('${entry.value}', optionLabels[entry.key])}',
  ];
}

/// Keys [effectiveSettingLines] states as what the connection DOES, so the
/// stored value would only repeat it — or, absent, say nothing at all.
const _statedByEffect = {serialRtsHighConfigKey, serialDtrHighConfigKey, pollIntervalConfigKey};

/// The settings most operators never touch, as the connection applies them —
/// stated whether or not the node stores them. A blank or absent value means
/// a default the reader of a report cannot see, and "the radio answers
/// nothing" is so often a control line or a poll rate that leaving it to be
/// inferred would cost the report its point.
List<String> effectiveSettingLines(EquipmentNode node, EquipmentType type) {
  final lines = <String>[];
  if (type.transport is SerialTransportConfig) {
    final target = type.targetFor(node.config);
    String level(String key) => target[key] == true ? 'held high' : 'low';
    lines.add('- Control lines: RTS ${level(serialRtsHighConfigKey)}, DTR ${level(serialDtrHighConfigKey)}');
  }
  // The driver's own elements, not the pairing's: those carry the fallback
  // this driver means by a blank, and asking them enumerates no ports.
  final Map<String, dynamic>? pollField;
  try {
    pollField = type.driver
        .configElements(overrides: type.overrides, restrictions: type.restrictions)
        .where((e) => e['key'] == pollIntervalConfigKey)
        .firstOrNull;
  } catch (e) {
    debugPrint('[report] ${type.key}: driver elements unavailable ($e)');
    return lines;
  }
  if (pollField != null) {
    final fallback = Duration(milliseconds: int.tryParse('${pollField['placeholder']}') ?? 0);
    final config = type.driverConfig(node.config);
    final interval = idlePollIntervalFor(config, fallback: fallback);
    final chosen = idlePollIntervalFor(config, fallback: Duration.zero) != Duration.zero;
    lines.add('- Idle poll: ${interval.inMilliseconds} ms${chosen ? '' : ' (default)'}');
  }
  return lines;
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
/// CP2105 or an FT232. The adapter's SERIAL NUMBER is deliberately not here
/// and is stripped from every line by [redactSerialNumber] — it fingerprints
/// one physical device, and nothing a report answers needs that. Two of the
/// same adapter are therefore indistinguishable in a report, which is the
/// price. Whatever descriptor text the picker's label did NOT already
/// show follows — on macOS the label is often the bare device name, because
/// reading a descriptor there means opening the port and that fails.
///
/// Says so when the port is not in the enumeration at all, rather than going
/// quiet: "the app cannot see the port" is the answer to a large share of the
/// reports this feature exists to collect, and silence there reads exactly
/// like a port that was found and had nothing to say.
List<String> serialPortLines(EquipmentNode node, EquipmentType type) {
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
