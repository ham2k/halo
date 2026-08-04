#!/usr/bin/env python3
# Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
# SPDX-License-Identifier: MPL-2.0
#
# Single source of truth for the app's icon fonts and name->codepoint data:
# the icon projects' own npm packages, pinned below. Everything downstream
# (bundled TTFs, the resolveIconName lookup tables, the MdiIcons const class,
# and the extension icon-name validation in halo_build_tools) derives from
# the vendored glyphmap JSONs in tool/data/, vendored as a pair with the
# fonts from one package version and proven against each font's cmap on
# every generate() run.
#
# Both pins are terminal releases: MDI is finished at 7.4.47 (the project is
# in maintenance) and Font Awesome 6 Free ends at 6.7.2. The name sets match
# what app-polo ships via @react-native-vector-icons 13.1.2 (which repackages
# these same upstreams; RNVI adds one synthetic 'blank' entry with no glyph
# in either font), so extension icon names stay portable between PoLo and
# HaLo. Because the MDI table (@mdi/svg) and font (@mdi/font) are still two
# artifacts of one release, generate() proves the pairing by parsing the
# TTF cmap and failing on any table codepoint the font lacks.
#
# Usage:
#   python3 tool/update_icons.py            # regenerate Dart from tool/data/
#   python3 tool/update_icons.py --fetch    # re-vendor fonts + glyphmaps from
#                                           # npm first, then regenerate

import io
import json
import re
import sys
import tarfile
import urllib.request
from pathlib import Path

MDI_VERSION = "7.4.47"
FA_VERSION = "6.7.2"

TOOL_DIR = Path(__file__).resolve().parent
DATA_DIR = TOOL_DIR / "data"
LIB_SRC = TOOL_DIR.parent / "lib" / "src"
REPO_ROOT = TOOL_DIR.parents[2]
FONTS_DIR = REPO_ROOT / "app" / "assets" / "fonts"

MDI_GLYPHMAP = DATA_DIR / "mdi_glyphmap.json"
FA_GLYPHMAP = DATA_DIR / "fa6_solid_glyphmap.json"

# Dart reserved words that a camelCased icon name could collide with; such a
# name gets an 'Icon' suffix ('null' -> nullIcon). Anything unexpected fails
# the run so the naming policy stays a deliberate choice.
DART_RESERVED = {
    "assert", "break", "case", "catch", "class", "const", "continue",
    "default", "do", "else", "enum", "extends", "false", "final", "finally",
    "for", "if", "in", "is", "new", "null", "rethrow", "return", "super",
    "switch", "this", "throw", "true", "try", "var", "void", "while", "with",
}


def npm_tarball(package, version):
    bare = package.rsplit("/", 1)[-1]
    url = f"https://registry.npmjs.org/{package}/-/{bare}-{version}.tgz"
    print(f"Fetching {url}")
    with urllib.request.urlopen(url) as resp:
        return tarfile.open(fileobj=io.BytesIO(resp.read()), mode="r:gz")


def extract(tar, member):
    data = tar.extractfile(f"package/{member}")
    if data is None:
        sys.exit(f"Member {member} missing from tarball")
    return data.read()


def fetch():
    DATA_DIR.mkdir(exist_ok=True)

    with npm_tarball("@mdi/svg", MDI_VERSION) as tar:
        meta = json.loads(extract(tar, "meta.json"))
    mdi_icons = {e["name"]: int(e["codepoint"], 16) for e in meta}
    MDI_GLYPHMAP.write_text(json.dumps({
        "source": f"@mdi/svg@{MDI_VERSION} meta.json; font from @mdi/font@{MDI_VERSION}",
        "fontFamily": "MaterialDesignIcons",
        "icons": dict(sorted(mdi_icons.items())),
    }, indent=1) + "\n")
    print(f"Wrote {MDI_GLYPHMAP} ({len(mdi_icons)} icons)")

    with npm_tarball("@mdi/font", MDI_VERSION) as tar:
        ttf = extract(tar, "fonts/materialdesignicons-webfont.ttf")
    (FONTS_DIR / "MaterialDesignIcons.ttf").write_bytes(ttf)
    print(f"Wrote MaterialDesignIcons.ttf ({len(ttf)} bytes)")

    with npm_tarball("@fortawesome/fontawesome-free", FA_VERSION) as tar:
        families = json.loads(extract(tar, "metadata/icon-families.json"))
        fa_ttf = extract(tar, "webfonts/fa-solid-900.ttf")
    fa_icons = {}
    for name, entry in families.items():
        for style in entry.get("familyStylesByLicense", {}).get("free", []):
            if style.get("family") == "classic" and style.get("style") == "solid":
                fa_icons[name] = int(entry["unicode"], 16)
    FA_GLYPHMAP.write_text(json.dumps({
        "source": f"@fortawesome/fontawesome-free@{FA_VERSION} icon-families.json (free classic solid); font fa-solid-900.ttf",
        "fontFamily": "FontAwesome6Solid",
        "icons": dict(sorted(fa_icons.items())),
    }, indent=1) + "\n")
    print(f"Wrote {FA_GLYPHMAP} ({len(fa_icons)} icons)")
    (FONTS_DIR / "FontAwesome6Solid.ttf").write_bytes(fa_ttf)
    print(f"Wrote FontAwesome6Solid.ttf ({len(fa_ttf)} bytes)")


def font_codepoints(ttf_path):
    """The set of codepoints mapped by a TTF's cmap (formats 4 and 12) —
    enough to prove every glyphmap entry has a glyph, without fontTools."""
    import struct

    data = ttf_path.read_bytes()
    (num_tables,) = struct.unpack(">H", data[4:6])
    cmap_off = None
    for i in range(num_tables):
        rec = 12 + 16 * i
        tag = data[rec:rec + 4]
        if tag == b"cmap":
            (cmap_off,) = struct.unpack(">I", data[rec + 8:rec + 12])
            break
    if cmap_off is None:
        sys.exit(f"{ttf_path}: no cmap table")

    (subtable_count,) = struct.unpack(">H", data[cmap_off + 2:cmap_off + 4])
    codepoints = set()
    for i in range(subtable_count):
        rec = cmap_off + 4 + 8 * i
        (offset,) = struct.unpack(">I", data[rec + 4:rec + 8])
        sub = cmap_off + offset
        (fmt,) = struct.unpack(">H", data[sub:sub + 2])
        if fmt == 4:
            (seg_x2,) = struct.unpack(">H", data[sub + 6:sub + 8])
            ends = struct.unpack(f">{seg_x2 // 2}H", data[sub + 14:sub + 14 + seg_x2])
            starts_off = sub + 16 + seg_x2
            starts = struct.unpack(f">{seg_x2 // 2}H", data[starts_off:starts_off + seg_x2])
            for start, end in zip(starts, ends):
                if start != 0xFFFF:
                    codepoints.update(range(start, end + 1))
        elif fmt == 12:
            (n_groups,) = struct.unpack(">I", data[sub + 12:sub + 16])
            for g in range(n_groups):
                grec = sub + 16 + 12 * g
                start, end, _ = struct.unpack(">III", data[grec:grec + 12])
                codepoints.update(range(start, end + 1))
    return codepoints


def check_font_coverage(glyphmap, ttf_name):
    ttf = FONTS_DIR / ttf_name
    missing = sorted(n for n, cp in glyphmap["icons"].items() if cp not in font_codepoints(ttf))
    if missing:
        sys.exit(
            f"{ttf_name} lacks glyphs for {len(missing)} table entries "
            f"(font/table pair out of sync): {', '.join(missing[:10])}..."
        )
    print(f"{ttf_name}: all {len(glyphmap['icons'])} table codepoints present in cmap")


def const_name(icon_name):
    parts = icon_name.split("-")
    name = parts[0] + "".join(p.capitalize() for p in parts[1:])
    if name in DART_RESERVED:
        name += "Icon"
    if not re.fullmatch(r"[a-zA-Z][a-zA-Z0-9]*", name):
        sys.exit(f"Icon name {icon_name!r} maps to invalid Dart identifier {name!r}")
    return name


def generate():
    mdi = json.loads(MDI_GLYPHMAP.read_text())
    fa = json.loads(FA_GLYPHMAP.read_text())

    check_font_coverage(mdi, "MaterialDesignIcons.ttf")
    check_font_coverage(fa, "FontAwesome6Solid.ttf")

    header = [
        "// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>",
        "// SPDX-License-Identifier: MPL-2.0",
        "//",
        "// GENERATED FILE — do not edit by hand.",
        "// Regenerate with: python3 tool/update_icons.py",
        "//",
        f"// Source: {mdi['source']} ({len(mdi['icons'])} icons),",
        f"// {fa['source']} ({len(fa['icons'])} icons).",
        "",
    ]

    codepoints = list(header)
    codepoints.append("const Map<String, int> mdiCodepoints = {")
    for name, cp in mdi["icons"].items():
        codepoints.append(f"  {json.dumps(name)}: {cp},")
    codepoints.append("};")
    codepoints.append("")
    codepoints.append("const Map<String, int> faSolidCodepoints = {")
    for name, cp in fa["icons"].items():
        codepoints.append(f"  {json.dumps(name)}: {cp},")
    codepoints.append("};")
    codepoints.append("")
    (LIB_SRC / "icon_codepoints.g.dart").write_text("\n".join(codepoints))
    print(f"Wrote icon_codepoints.g.dart ({len(mdi['icons'])} MDI + {len(fa['icons'])} FA solid)")

    consts = list(header)
    consts += [
        "import 'package:flutter/widgets.dart';",
        "",
        "/// Every Material Design Icon as a const, named by camelCasing the",
        "/// canonical hyphenated MDI name ('pine-tree' -> pineTree; a name that",
        "/// collides with a Dart reserved word gets an Icon suffix). Core code",
        "/// uses these consts so the analyzer catches a bad icon; the string",
        "/// lookup in resolveIconName is for extension-supplied data only.",
        "class MdiIcons {",
        "  MdiIcons._();",
        "",
    ]
    names = {}
    for name, cp in mdi["icons"].items():
        dart_name = const_name(name)
        if dart_name in names:
            sys.exit(f"Const name collision: {name!r} and {names[dart_name]!r} both map to {dart_name}")
        names[dart_name] = name
        consts.append(f"  static const IconData {dart_name} = IconData({hex(cp)}, fontFamily: 'MaterialDesignIcons');")
    consts.append("}")
    consts.append("")
    (LIB_SRC / "mdi_icons.g.dart").write_text("\n".join(consts))
    print(f"Wrote mdi_icons.g.dart ({len(names)} consts)")


def main():
    if "--fetch" in sys.argv[1:]:
        fetch()
    elif not (MDI_GLYPHMAP.exists() and FA_GLYPHMAP.exists()):
        sys.exit("Vendored glyphmaps missing from tool/data/ — run with --fetch first.")
    generate()


if __name__ == "__main__":
    main()
