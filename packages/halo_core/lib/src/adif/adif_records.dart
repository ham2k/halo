// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0

import 'dart:convert';

import 'adif_parser.dart';

/// The records of an ADIF file, each written alone as
/// `<NAME:LENGTH>value … <EOR>`, with every field [omit] names left out —
/// what a push sends and hashes (docs/design/transfer.md §5).
///
/// Rewritten from the parsed fields rather than cut from the text, so one
/// contact always renders the same and its hash moves only when a field
/// does. A field's data type (`<QSO_DATE:8:D>`) is dropped: ADIF makes it
/// optional, and the field's name already says it. A name in [omit] matches case-insensitively, and one ending in `*`
/// matches every name it begins (`app_*`).
List<String> adifRecordsOf(String content, {List<String> omit = const []}) {
  final patterns = [for (final name in omit) name.toUpperCase()];
  bool omitted(String name) {
    final upper = name.toUpperCase();
    return patterns.any((p) => p.endsWith('*') ? upper.startsWith(p.substring(0, p.length - 1)) : upper == p);
  }

  return [
    for (final segment in parseAdifSegments(content))
      if (segment.type == AdifSegmentType.record)
        if ([
              for (final field in segment.fields)
                if (!omitted(field.name)) '<${field.name.toUpperCase()}:${utf8.encode(field.value).length}>${field.value}',
            ]
            case final fields when fields.isNotEmpty)
          '${fields.join(' ')} <EOR>',
  ];
}
