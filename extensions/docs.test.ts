// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MIT
//
// The extension docs (docs/extensions/*.md) describe the SDK's public surface
// for an author with the package from npm, and ship inside that package and
// on catalog.ham2k.net. These tests hold the pages to the surface and to the
// voice docs/design/extension-docs.md sets:
//
//   - every host call, hook category, manifest field, hook-context field,
//     scene control kind and radio value is named on the page that owns it,
//     so a surface change cannot merge without its sentence;
//   - every API level up to the current one has its row in packaging.md,
//     and no page names a level the SDK does not have;
//   - the settings sections the pages list are the packer's;
//   - every page is shipped in the package or named as one that stays out;
//   - every relative link resolves and every anchor names a heading, by the
//     slug rules the catalog renders with;
//   - the prose stays free of the agent-notes voice the rewrite removed:
//     dates, issue references, status emoji, history, comparisons with other
//     apps, and the app's own source paths.
//
// A failure here names the page and what it lacks. The fix is a sentence on
// that page, never an exemption here.

import assert from "node:assert/strict"
import { existsSync, readdirSync, readFileSync } from "node:fs"
import { dirname, join, resolve } from "node:path"
import test from "node:test"
import { fileURLToPath } from "node:url"
import ts from "typescript"

import { HOOK_CATEGORIES } from "./sdk/src/hookCategories.ts"
import { H2KEXT_API_VERSION, SETTINGS_SECTIONS } from "./tools/h2kext.mjs"

const here = dirname(fileURLToPath(import.meta.url))
const docsDir = resolve(here, "../docs/extensions")
const sdkSrc = join(here, "sdk/src")

/// Pages that are deliberately not in the npm package: the one for people
/// working in this repository, and the agents file, which the SDK build ships
/// at the package root as AGENTS.md instead.
const NOT_IN_PACKAGE = ["in-repo.md", "agents.md"]

/// The one page allowed to name this repository's own files.
const MAY_NAME_REPO_PATHS = ["in-repo.md"]

const pages: Record<string, string> = Object.fromEntries(
  readdirSync(docsDir)
    .filter((name) => name.endsWith(".md"))
    .sort()
    .map((name) => [name, readFileSync(join(docsDir, name), "utf8")]),
)

function page(name: string): string {
  const text = pages[name]
  assert.ok(text !== undefined, `docs/extensions/${name} is missing`)
  return text
}

// ---------------------------------------------------------------------------
// Reading the SDK's surface from its source, so the list the docs are held to
// is the one `dist/index.d.ts` is built from rather than a copy kept here.

function sourceFile(name: string): ts.SourceFile {
  const path = join(sdkSrc, name)
  return ts.createSourceFile(path, readFileSync(path, "utf8"), ts.ScriptTarget.Latest, true)
}

function isDeprecated(node: ts.Node): boolean {
  return ts.getJSDocTags(node).some((tag) => tag.tagName.text === "deprecated")
}

/// The members of `interface <name>`, by name.
function interfaceMembers(sf: ts.SourceFile, name: string): string[] {
  const members: string[] = []
  sf.forEachChild((node) => {
    if (ts.isInterfaceDeclaration(node) && node.name.text === name) {
      for (const member of node.members) {
        if ((ts.isPropertySignature(member) || ts.isMethodSignature(member)) && member.name && ts.isIdentifier(member.name) && !isDeprecated(member)) {
          members.push(member.name.text)
        }
      }
    }
  })
  assert.ok(members.length > 0, `interface ${name} not found in ${sf.fileName}`)
  return members
}

/// The string literals of `type <name> = "a" | "b" | …`.
function unionLiterals(sf: ts.SourceFile, name: string): string[] {
  const literals: string[] = []
  sf.forEachChild((node) => {
    if (ts.isTypeAliasDeclaration(node) && node.name.text === name && ts.isUnionTypeNode(node.type)) {
      for (const member of node.type.types) {
        if (ts.isLiteralTypeNode(member) && ts.isStringLiteral(member.literal)) literals.push(member.literal.text)
      }
    }
  })
  assert.ok(literals.length > 0, `type ${name} not found in ${sf.fileName}`)
  return literals
}

/// The methods of `export const <name> = { … }`, nested objects as
/// `outer.inner`, deprecated aliases left out.
function objectMethods(sf: ts.SourceFile, name: string): string[] {
  const methods: string[] = []
  const walk = (object: ts.ObjectLiteralExpression, prefix: string) => {
    for (const property of object.properties) {
      if (!property.name || !ts.isIdentifier(property.name) || isDeprecated(property)) continue
      const key = prefix + property.name.text
      if (ts.isMethodDeclaration(property)) methods.push(key)
      else if (ts.isPropertyAssignment(property) && ts.isObjectLiteralExpression(property.initializer)) walk(property.initializer, `${key}.`)
      else if (ts.isPropertyAssignment(property) && (ts.isArrowFunction(property.initializer) || ts.isFunctionExpression(property.initializer)))
        methods.push(key)
    }
  }
  sf.forEachChild((node) => {
    if (!ts.isVariableStatement(node)) return
    for (const declaration of node.declarationList.declarations) {
      if (
        ts.isIdentifier(declaration.name) &&
        declaration.name.text === name &&
        declaration.initializer &&
        ts.isObjectLiteralExpression(declaration.initializer)
      ) {
        walk(declaration.initializer, "")
      }
    }
  })
  assert.ok(methods.length > 0, `const ${name} not found in ${sf.fileName}`)
  return methods
}

/// Whether `text` names `token` inside a code span, as a page names a call,
/// a field or a key.
function namesInCode(text: string, token: string): boolean {
  const escaped = token.replace(/[.*+?^${}()|[\]\\]/g, "\\$&")
  return new RegExp("`[^`\\n]*(?<![\\w])" + escaped + "(?![\\w])[^`\\n]*`").test(text)
}

function assertNamed(pageName: string, tokens: string[], what: string): void {
  const text = page(pageName)
  const missing = tokens.filter((token) => !namesInCode(text, token))
  assert.deepEqual(missing, [], `${pageName} does not name ${what}: ${missing.join(", ")}`)
}

// ---------------------------------------------------------------------------
// The surface

test("every host call is on the host API page", () => {
  const methods = objectMethods(sourceFile("index.ts"), "host")
  assertNamed(
    "host.md",
    methods.map((m) => m.split(".").pop()!),
    "these host calls",
  )
  assertNamed(
    "host.md",
    objectMethods(sourceFile("index.ts"), "hooks").map((m) => `hooks.${m}`),
    "these in-runtime calls",
  )
})

test("every hook category is in the category table", () => {
  assertNamed("hooks.md", [...HOOK_CATEGORIES], "these categories")
})

test("every manifest field and grant is on the manifest page", () => {
  assertNamed("manifest.md", interfaceMembers(sourceFile("types.ts"), "ExtensionManifest"), "these manifest fields")
})

test("every hook-context field is on the host API page", () => {
  assertNamed("host.md", interfaceMembers(sourceFile("types.ts"), "HookContext"), "these hook-context fields")
})

test("every scene control kind and live radio value is on the scenes page", () => {
  const sf = sourceFile("panelScene.ts")
  assertNamed("scenes.md", unionLiterals(sf, "PanelSceneControlKind"), "these control kinds")
  assertNamed("scenes.md", unionLiterals(sf, "PanelSceneRadioValue"), "these radio values")
  assertNamed("scenes.md", unionLiterals(sf, "PanelSceneRadioString"), "these radio strings")
})

test("every API level has its row, and no page names a level the SDK lacks", () => {
  const table = page("packaging.md")
  for (let level = 1; level <= H2KEXT_API_VERSION; level++) {
    assert.match(table, new RegExp(`^\\| ${level} \\| .+\\|$`, "m"), `packaging.md's API table has no row for level ${level}`)
  }
  for (const [name, text] of Object.entries(pages)) {
    for (const match of text.matchAll(/\bAPI (\d+)\b/g)) {
      const level = Number(match[1])
      assert.ok(level >= 1 && level <= H2KEXT_API_VERSION, `${name} names API ${level}; the SDK describes up to ${H2KEXT_API_VERSION}`)
    }
  }
})

test("the settings sections the pages list are the packer's", () => {
  const sections = [...SETTINGS_SECTIONS.preferred, ...SETTINGS_SECTIONS.other]
  assertNamed("settings.md", sections, "these settings sections")
  assertNamed("manifest.md", sections, "these settings sections")
})

// ---------------------------------------------------------------------------
// The set, and its links

function shippedDocs(): string[] {
  const build = readFileSync(join(here, "sdk/build.mjs"), "utf8")
  const block = /const shippedDocs = \[([\s\S]*?)\]/.exec(build)
  assert.ok(block, "sdk/build.mjs has no shippedDocs list")
  return [...block[1].matchAll(/"([^"]+)"/g)].map((m) => m[1])
}

test("every page is shipped in the SDK package, or named as one that stays out", () => {
  const shipped = shippedDocs()
  for (const name of shipped) assert.ok(pages[name], `sdk/build.mjs ships ${name}, which does not exist`)
  const expected = [...shipped, ...NOT_IN_PACKAGE].sort()
  assert.deepEqual(Object.keys(pages), expected, "docs/extensions holds pages the SDK build neither ships nor names as left out")
})

/// GitHub's slugger, as the catalog renders headings: everything that is not a
/// letter, mark, digit, connector, hyphen or space is dropped, spaces become
/// hyphens, and a repeated heading gets -1, -2, …
const NOT_SLUG = /[^\p{L}\p{M}\p{Nd}\p{Nl}\p{Pc}\- ]/gu

function headingSlugs(markdown: string): Set<string> {
  const seen = new Map<string, number>()
  const slugs = new Set<string>()
  for (const line of outsideFences(markdown)) {
    const m = /^ {0,3}#{1,6}[ \t]+(.*?)(?:[ \t]+#+)?[ \t]*$/.exec(line)
    if (!m) continue
    const text = (m[1] ?? "").replace(/\[([^\]]*)\]\([^)]*\)/g, "$1")
    const base = text.toLowerCase().replace(NOT_SLUG, "").replace(/ /g, "-")
    let slug = base
    while (seen.has(slug)) {
      const n = (seen.get(base) ?? 0) + 1
      seen.set(base, n)
      slug = `${base}-${n}`
    }
    seen.set(slug, 0)
    slugs.add(slug)
  }
  return slugs
}

/// The lines outside fenced code blocks; fence lines and their contents come
/// back empty, so line numbers stay aligned.
function outsideFences(markdown: string): string[] {
  let fence: string | null = null
  return markdown.split("\n").map((line) => {
    const open = /^ {0,3}(`{3,}|~{3,})/.exec(line)?.[1]
    if (fence === null) {
      if (open === undefined) return line
      fence = open
      return ""
    }
    if (open !== undefined && open[0] === fence[0] && open.length >= fence.length) fence = null
    return ""
  })
}

test("every relative link resolves and every anchor names a heading", () => {
  const slugs = Object.fromEntries(Object.entries(pages).map(([name, text]) => [name, headingSlugs(text)]))
  const problems: string[] = []
  for (const [name, text] of Object.entries(pages)) {
    outsideFences(text).forEach((line, index) => {
      const at = `${name}:${index + 1}`
      for (const match of line.matchAll(/\]\((?!https?:|#|mailto:)([^)\s]+)\)/g)) {
        const [path, anchor] = match[1].split("#")
        if (path.startsWith("..")) {
          if (!existsSync(resolve(docsDir, path))) problems.push(`${at}: ${match[1]} does not exist`)
          continue
        }
        const target = path.replace(/^\.\//, "")
        if (!pages[target]) problems.push(`${at}: ${match[1]} is not a page`)
        else if (anchor && !slugs[target].has(anchor)) problems.push(`${at}: no heading for ${match[1]}`)
      }
      for (const match of line.matchAll(/\]\(#([^)]+)\)/g)) {
        if (!slugs[name].has(match[1])) problems.push(`${at}: no heading for #${match[1]}`)
      }
      // The two link forms the SDK build's rewriter cannot follow, which would
      // ship as dead relative paths.
      if (/\]\((?!https?:|#|mailto:)[^)\s]+\s+[^)]*\)/.test(line)) problems.push(`${at}: a link with a title`)
      if (/^\[[^\]]+\]:\s*(?!https?:|#|mailto:)\S+/.test(line)) problems.push(`${at}: a reference-style link definition`)
    })
  }
  assert.deepEqual(problems, [])
})

// ---------------------------------------------------------------------------
// The voice

/// The prose of a page: what is left once fenced blocks and inline code are
/// gone, since an example may legitimately carry a date or a path.
function prose(markdown: string): string {
  return outsideFences(markdown)
    .join("\n")
    .replace(/`[^`\n]*`/g, "")
}

const VOICE_RULES: { name: string; pattern: RegExp; why: string }[] = [
  { name: "a date", pattern: /\b20\d\d-\d\d-\d\d\b/, why: "the pages describe the version beside them, not a moment" },
  { name: "an issue or card reference", pattern: /\bHALO-\d+\b|halo-dist#\d+|(?<![\w#&])#\d{1,5}\b/, why: "a reader of the package has no tracker" },
  { name: "a comparison with another app", pattern: /\b(PoLo|app-polo|web-lofi|polo)\b/i, why: "the pages describe this app" },
  { name: "a status marker", pattern: /[✅🔜🚧⏳]/u, why: "every page describes what ships" },
  {
    name: "history",
    pattern: /\b(used to|previously|historically|not yet implemented|TODO|FIXME)\b|Implemented by:/,
    why: "state the rule as it stands; git blame holds the history",
  },
]

const REPO_PATH = {
  name: "a path into this repository",
  pattern: /\bapp\/(lib|test)\/|\bpackages\/halo_|\.dart\b|\bextensions\/core\//,
  why: "an author with the package cannot read this repository",
}

test("the pages keep the authors' voice", () => {
  const problems: string[] = []
  for (const [name, text] of Object.entries(pages)) {
    assert.match(text, /^# \S/, `${name} does not start with its title`)
    const body = prose(text)
    const rules = MAY_NAME_REPO_PATHS.includes(name) ? VOICE_RULES : [...VOICE_RULES, REPO_PATH]
    for (const rule of rules) {
      const match = rule.pattern.exec(body)
      if (match) {
        const line = body.slice(0, match.index).split("\n").length
        problems.push(`${name}:${line} has ${rule.name} (${JSON.stringify(match[0])}): ${rule.why}`)
      }
    }
  }
  assert.deepEqual(problems, [])
})
