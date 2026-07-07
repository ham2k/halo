#!/usr/bin/env python3
# Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
# SPDX-License-Identifier: MPL-2.0
#
# Regenerates lib/src/icon_codepoints.g.dart from the glyphmap JSON files
# that ship inside @react-native-vector-icons packages (name -> codepoint),
# the same source app-polo's own icon rendering uses. Re-run this whenever
# those npm packages are upgraded in app-polo to pick up new/renamed icons.
#
# Usage: python3 tool/generate_icon_codepoints.py

import json
import sys
from pathlib import Path

APP_POLO_NODE_MODULES = Path(__file__).resolve().parents[4] / "app-polo" / "node_modules"
MDI_GLYPHMAP = APP_POLO_NODE_MODULES / "@react-native-vector-icons/material-design-icons/glyphmaps/MaterialDesignIcons.json"
FA_SOLID_GLYPHMAP = APP_POLO_NODE_MODULES / "@react-native-vector-icons/fontawesome6/glyphmaps/FontAwesome6_solid.json"

OUTPUT = Path(__file__).resolve().parents[1] / "lib" / "src" / "icon_codepoints.g.dart"


def load_glyphmap(path):
    with open(path) as f:
        return json.load(f)


def emit_map(buffer, dart_name, entries):
    buffer.append(f"const Map<String, int> {dart_name} = {{")
    for name, codepoint in sorted(entries.items()):
        buffer.append(f"  {json.dumps(name)}: {codepoint},")
    buffer.append("};")
    buffer.append("")


def main():
    if not MDI_GLYPHMAP.exists() or not FA_SOLID_GLYPHMAP.exists():
        sys.exit(
            f"Missing glyphmap source(s). Expected:\n  {MDI_GLYPHMAP}\n  {FA_SOLID_GLYPHMAP}\n"
            "Run `npm install` in ../app-polo first (its node_modules is the source of truth)."
        )

    mdi = load_glyphmap(MDI_GLYPHMAP)
    fa_solid = load_glyphmap(FA_SOLID_GLYPHMAP)

    buffer = [
        "// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>",
        "// SPDX-License-Identifier: MPL-2.0",
        "//",
        "// GENERATED FILE — do not edit by hand.",
        "// Regenerate with: python3 tool/generate_icon_codepoints.py",
        "//",
        f"// Source: @react-native-vector-icons/material-design-icons ({len(mdi)} icons),",
        f"// @react-native-vector-icons/fontawesome6 solid style ({len(fa_solid)} icons).",
        "",
    ]
    emit_map(buffer, "mdiCodepoints", mdi)
    emit_map(buffer, "faSolidCodepoints", fa_solid)

    OUTPUT.write_text("\n".join(buffer))
    print(f"Wrote {OUTPUT} ({len(mdi)} MDI + {len(fa_solid)} FA solid icons)")


if __name__ == "__main__":
    main()
