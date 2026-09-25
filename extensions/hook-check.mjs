// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// A manifest's `hooks` list is metadata the Dart host acts on WITHOUT running
// any JS — a disabled extension's bundle is never evaluated, so the host can
// only know what it offers from `index.json` (docs/extensions/README.md). That
// makes the list load-bearing and, on its own, unverified: nothing stops it
// from naming a hook the code never registers, or missing one it does.
//
// This closes that by asking the code. Each built bundle is evaluated against
// a recording stand-in for the kernel and activated, so the answer comes from
// the REAL `registerHook` path rather than a parse of the source — which could
// not see a hook registered from a loop or a template key
// (`registerHook(`ref:${TYPE}`)`) anyway.
//
// Three rules, and they are deliberately different:
//
//   - A PLAIN category (`activity`, `spots`, `dataFile`…) must match exactly,
//     both ways. The host uses these to decide what an extension is.
//
//   - A `ref:<type>` entry must publish a CONTROL for that type. This one is
//     one-directional on purpose: an activity may legitimately register a
//     `ref:` handler for a type it merely resolves or decorates (WCA answers
//     for English and Belgian castle references; WWBOTA for the legacy UKBOTA
//     ones) and must NOT declare those, because the host reads the list to
//     offer enabling a switched-off extension when an operation carries such a
//     ref — and an offer that leads to no control leaves the row exactly as
//     red as it was.
//
//   - A `ref:<type>/<code>` entry claims a LEGACY reference under someone
//     else's type — `ref:qp/ny` for the New York party, which publishes
//     `ref:nyqp`. It is not a control claim, so the rule is different again:
//     the manifest must declare exactly one plain `ref:<type>`, which is what
//     the legacy reference is rewritten into, and must not also declare the
//     legacy type plainly (that would already handle it).
//
// Runs over the built bundles, so it belongs after the build rather than
// beside the manifest's field validation in build-config.mjs.

import { readFile } from "node:fs/promises"
import { join } from "node:path"
import vm from "node:vm"

/// What the runtime gives a bundle, reduced to what evaluating and activating
/// one touches. Extensions read settings at activation and list rows to build
/// their controls; everything else answers null, which is what an extension
/// already has to tolerate (`host.secret()` in the dev loop, an absent lookup
/// table before its data file syncs).
///
/// A new extension that needs more than this fails the check rather than
/// skipping it — teach the stub the shape, here.
function hostCallStub(method) {
  if (method === "getSettings") return {}
  if (method.startsWith("dbLookup")) return []
  return null
}

const hostCall = async (method) => hostCallStub(method)

/// Enough HookContext for a control listing: the labels come from `ctx.locale`.
const hookContext = { locale: "en", online: false, settings: {}, operation: {} }

function sandboxFor(kernelStub) {
  const sandbox = {
    // The kernel routes console to the host; nothing here reads the output.
    console: { log() {}, warn() {}, error() {} },
    // The QuickJS host's bridge primitive. The kernel logs through it while
    // being evaluated, so it has to exist before the first line runs.
    sendMessage: () => {},
    __polo: kernelStub,
  }
  sandbox.globalThis = sandbox
  return vm.createContext(sandbox)
}

/// The real kernel, evaluated once — only to borrow the shared libraries it
/// publishes. Extension bundles resolve `@ham2k/lib-*` through
/// `__polo.sharedModules` (build-config.mjs externalizes them), so a stub that
/// did not carry them could not evaluate a single bundle.
async function sharedModulesFrom(outDir) {
  const context = sandboxFor(undefined)
  vm.runInContext(await readFile(join(outDir, "kernel.js"), "utf8"), context, { filename: "kernel.js" })
  return context.__polo.sharedModules
}

/// Evaluates and activates one bundle, returning what it registered:
/// the hook categories, and the ref types it publishes a control for.
async function inspectBundle({ key, outDir, sharedModules }) {
  const definitions = []
  const context = sandboxFor({
    defineExtension: (definition) => definitions.push(definition),
    hostCall,
    log: () => {},
    invokeLocal: async () => [],
    invokeLocalSequential: async () => [],
    updateInterpretation: () => {},
    getAccountKvKey: (extensionKey) => extensionKey,
    registerDynamicForm: () => {},
    unregisterDynamicForm: () => {},
    host: { showForm: async () => null },
    sharedModules,
    sharedVersions: {},
  })
  vm.runInContext(await readFile(join(outDir, `${key}.js`), "utf8"), context, { filename: `${key}.js` })

  const categories = new Set()
  const activityHooks = []
  for (const definition of definitions) {
    await definition.onActivation({
      hostCall,
      // Accepted and never fired: this check reads what an extension
      // registers, and a timer it sets while activating is not a failure.
      timers: { set: () => 0, clear: () => {} },
      registerHook: (category, params) => {
        categories.add(category)
        if (category === "activity") activityHooks.push(params.hook)
      },
    })
  }
  return { categories, activityHooks }
}

/// The ref types [activityHooks] offer a control for, given an operation
/// carrying [refTypes].
///
/// The operation carries a ref of EVERY declared type at once, because a
/// hunting control is commonly offered only while the operation is also
/// activating (custom/index.ts returns none without an activation ref) — one
/// type at a time would report a control the extension does publish as absent.
async function controlledRefTypes(activityHooks, refTypes) {
  const operation = { uuid: "check", refs: refTypes.map((type) => ({ type, ref: "TEST-0001" })) }
  const args = { operation, qso: { their: { call: "W1AW" } } }
  // type -> the control kinds publishing it, and the set of `<type>/<prefix>`
  // claims every control declares in `alsoHandles`. Both are what a manifest
  // entry has to be backed by: a claim nothing publishes is an offer that
  // cannot clear the row it was offered for.
  const controlled = new Map()
  const alsoHandled = new Set()
  for (const hook of activityHooks) {
    // An activation ref is named by an operation-level control, a hunting ref
    // by a per-QSO one. Either clears the row, so both count.
    for (const method of ["operationControls", "loggingControls"]) {
      if (typeof hook[method] !== "function") continue
      for (const control of (await hook[method](args, hookContext)) ?? []) {
        for (const claim of control?.input?.alsoHandles ?? []) {
          if (typeof claim === "string") alsoHandled.add(claim.toLowerCase())
        }
        const type = control?.input?.refType
        if (typeof type !== "string") continue
        if (!controlled.has(type)) controlled.set(type, new Set())
        controlled.get(type).add(control?.input?.kind)
      }
    }
  }
  return { controlled, alsoHandled }
}

/// Checks every extension bundle's manifest against what its code registers,
/// throwing with every problem at once — a build that reported them one run
/// at a time would be fixed one run at a time.
export async function checkHooksAgainstManifests({ bundles, outDir }) {
  const sharedModules = await sharedModulesFrom(outDir)
  const problems = []

  for (const bundle of bundles) {
    if (bundle.kind !== "extension") continue
    const declared = bundle.manifest.hooks ?? []
    const manifestPath = `${bundle.key}/manifest.json`

    let inspected
    try {
      inspected = await inspectBundle({ key: bundle.key, outDir, sharedModules })
    } catch (e) {
      problems.push(
        `${bundle.key}: could not be evaluated or activated, so its manifest cannot be checked — ${e.message}\n` +
          `    If the extension is sound, the stand-in host in hook-check.mjs needs the shape it asked for.`,
      )
      continue
    }
    const { categories, activityHooks } = inspected

    const declaredPlain = declared.filter((hook) => !hook.startsWith("ref:"))
    const registeredPlain = [...categories].filter((category) => !category.startsWith("ref:"))
    const missing = registeredPlain.filter((category) => !declaredPlain.includes(category)).sort()
    const phantom = declaredPlain.filter((category) => !registeredPlain.includes(category)).sort()
    if (missing.length) {
      problems.push(`${manifestPath}: registers ${missing.join(", ")} but does not list ${missing.length > 1 ? "them" : "it"} in "hooks"`)
    }
    if (phantom.length) {
      problems.push(`${manifestPath}: lists ${phantom.join(", ")} in "hooks" but never registers ${phantom.length > 1 ? "them" : "it"}`)
    }

    const declaredRefs = declared.filter((hook) => hook.startsWith("ref:")).map((hook) => hook.slice(4))
    // A qualified claim (`ref:qp/ny`) is about a LEGACY reference the
    // extension answers under another name, so it is not a control claim and
    // is checked by its own rules below.
    const declaredRefTypes = declaredRefs.filter((entry) => !entry.includes("/"))
    const qualified = declaredRefs.filter((entry) => entry.includes("/"))
    // Shape first: the app reads `ref:<type>/<code>` and nothing else, so a
    // half-written entry (`ref:qp/`, `ref:/ny`) or one with a second slash
    // matches no reference at all — the extension would ship a claim that
    // does nothing and the operator's legacy row would stay red, which is
    // the very failure this file exists to catch.
    const malformed = qualified.filter((q) => q.split("/").length !== 2 || q.split("/").some((half) => !half)).sort()
    if (malformed.length) {
      problems.push(
        `${manifestPath}: lists ${malformed.map((q) => `"ref:${q}"`).join(", ")} in "hooks". A qualified claim is ` +
          `"ref:<type>/<code>" with both halves present and one slash; nothing else is read as one.`,
      )
    }
    const { controlled, alsoHandled } = await controlledRefTypes(activityHooks, declaredRefTypes)
    if (qualified.length) {
      // A qualified claim is a promise to ANSWER for a reference filed under
      // someone else's type, and the control is what answers. Declaring the
      // claim without publishing it is the same failure the plain rule below
      // catches: the host offers this extension for a red row, the operator
      // installs it, and the row stays exactly as red as it was.
      //
      // Nothing is rewritten by any of this, so there is no rule here about
      // what the reference becomes, and none about the target being codeless:
      // the reference keeps its own type and its own code, and the control
      // reads and writes it where it lies.
      const unbacked = qualified.filter((q) => !alsoHandled.has(q.toLowerCase())).sort()
      if (unbacked.length) {
        problems.push(
          `${manifestPath}: lists ${unbacked.map((q) => `"ref:${q}"`).join(", ")} in "hooks", but no control declares ` +
            `${unbacked.length > 1 ? "them" : "it"} in "alsoHandles" — the host would offer this extension for such a ` +
            `reference and the row would stay red. Add the claim to the control's input, or drop the entry.`,
        )
      }
    }
    // And the other way round, checked whether or not the manifest claims
    // anything: a control that answers for a reference the manifest does not
    // claim is never OFFERED for it, so the operator with that row is never
    // told this extension would fix it. Outside the branch above deliberately
    // — a manifest that claims NOTHING is exactly where this goes wrong.
    const undeclared = [...alsoHandled].filter((claim) => !qualified.some((q) => q.toLowerCase() === claim)).sort()
    if (undeclared.length) {
      problems.push(
        `${manifestPath}: publishes a control handling ${undeclared.map((q) => `"${q}"`).join(", ")} but does not list ` +
          `${undeclared.map((q) => `"ref:${q}"`).join(", ")} in "hooks" — nothing would offer this extension for such a ` +
          `reference, so the control that answers it is never reached.`,
      )
    }
    if (declaredRefTypes.length) {
      const uncontrolled = declaredRefTypes.filter((type) => !controlled.has(type)).sort()
      if (uncontrolled.length) {
        problems.push(
          `${manifestPath}: lists ${uncontrolled.map((t) => `ref:${t}`).join(", ")} in "hooks", but publishes no control for ` +
            `${uncontrolled.length > 1 ? "those types" : "that type"} — the host would offer to enable this extension for such a ` +
            `reference and the row would stay red. Drop the entr${uncontrolled.length > 1 ? "ies" : "y"} if the hook only ` +
            `resolves or decorates the reference; the registration itself can stay.`,
        )
      }
    }
  }

  if (problems.length) {
    throw new Error(
      `manifest "hooks" does not match what the code registers:\n  - ${problems.join("\n  - ")}\n` +
        `  (docs/extensions/README.md — "hooks" is what the host reads for a disabled extension.)`,
    )
  }
}
