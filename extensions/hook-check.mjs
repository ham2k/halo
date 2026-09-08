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
// Two rules, and they are deliberately different:
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
// Runs over the built bundles, so it belongs after the build rather than
// beside the manifest's field validation in build-config.mjs.

import { readFile } from 'node:fs/promises'
import { join } from 'node:path'
import vm from 'node:vm'

/// What the runtime gives a bundle, reduced to what evaluating and activating
/// one touches. Extensions read settings at activation and list rows to build
/// their controls; everything else answers null, which is what an extension
/// already has to tolerate (`host.secret()` in the dev loop, an absent lookup
/// table before its data file syncs).
///
/// A new extension that needs more than this fails the check rather than
/// skipping it — teach the stub the shape, here.
function hostCallStub(method) {
  if (method === 'getSettings') return {}
  if (method.startsWith('dbLookup')) return []
  return null
}

const hostCall = async (method) => hostCallStub(method)

/// Enough HookContext for a control listing: the labels come from `ctx.locale`.
const hookContext = { locale: 'en', online: false, settings: {}, operation: {} }

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
  vm.runInContext(await readFile(join(outDir, 'kernel.js'), 'utf8'), context, { filename: 'kernel.js' })
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
  vm.runInContext(await readFile(join(outDir, `${key}.js`), 'utf8'), context, { filename: `${key}.js` })

  const categories = new Set()
  const activityHooks = []
  for (const definition of definitions) {
    await definition.onActivation({
      hostCall,
      registerHook: (category, params) => {
        categories.add(category)
        if (category === 'activity') activityHooks.push(params.hook)
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
  const operation = { uuid: 'check', refs: refTypes.map((type) => ({ type, ref: 'TEST-0001' })) }
  const args = { operation, qso: { their: { call: 'W1AW' } } }
  const controlled = new Set()
  for (const hook of activityHooks) {
    // An activation ref is named by an operation-level control, a hunting ref
    // by a per-QSO one. Either clears the row, so both count.
    for (const method of ['operationControls', 'loggingControls']) {
      if (typeof hook[method] !== 'function') continue
      for (const control of (await hook[method](args, hookContext)) ?? []) {
        const type = control?.input?.refType
        if (typeof type === 'string') controlled.add(type)
      }
    }
  }
  return controlled
}

/// Checks every extension bundle's manifest against what its code registers,
/// throwing with every problem at once — a build that reported them one run
/// at a time would be fixed one run at a time.
export async function checkHooksAgainstManifests({ bundles, outDir }) {
  const sharedModules = await sharedModulesFrom(outDir)
  const problems = []

  for (const bundle of bundles) {
    if (bundle.kind !== 'extension') continue
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

    const declaredPlain = declared.filter((hook) => !hook.startsWith('ref:'))
    const registeredPlain = [...categories].filter((category) => !category.startsWith('ref:'))
    const missing = registeredPlain.filter((category) => !declaredPlain.includes(category)).sort()
    const phantom = declaredPlain.filter((category) => !registeredPlain.includes(category)).sort()
    if (missing.length) {
      problems.push(`${manifestPath}: registers ${missing.join(', ')} but does not list ${missing.length > 1 ? 'them' : 'it'} in "hooks"`)
    }
    if (phantom.length) {
      problems.push(`${manifestPath}: lists ${phantom.join(', ')} in "hooks" but never registers ${phantom.length > 1 ? 'them' : 'it'}`)
    }

    const declaredRefTypes = declared.filter((hook) => hook.startsWith('ref:')).map((hook) => hook.slice(4))
    if (declaredRefTypes.length) {
      const controlled = await controlledRefTypes(activityHooks, declaredRefTypes)
      const uncontrolled = declaredRefTypes.filter((type) => !controlled.has(type)).sort()
      if (uncontrolled.length) {
        problems.push(
          `${manifestPath}: lists ${uncontrolled.map((t) => `ref:${t}`).join(', ')} in "hooks", but publishes no control for ` +
            `${uncontrolled.length > 1 ? 'those types' : 'that type'} — the host would offer to enable this extension for such a ` +
            `reference and the row would stay red. Drop the entr${uncontrolled.length > 1 ? 'ies' : 'y'} if the hook only ` +
            `resolves or decorates the reference; the registration itself can stay.`,
        )
      }
    }
  }

  if (problems.length) {
    throw new Error(
      `manifest "hooks" does not match what the code registers:\n  - ${problems.join('\n  - ')}\n` +
        `  (docs/extensions/README.md — "hooks" is what the host reads for a disabled extension.)`,
    )
  }
}
