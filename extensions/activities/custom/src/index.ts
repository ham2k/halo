// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Custom Activity — the escape hatch for a program HaLo has no extension for.
// A regional castles award, a club's one-off event, a scheme that exists only
// on a forum post: you name it yourself and the log carries it as SIG/MY_SIG
// like any other.
//
// It is the only activity with nothing to search. Every other one resolves a
// typed reference against a downloaded list; here the operator IS the list, so
// there is no `suggest`, no `dataFile`, and no lookup — and consequently no
// validation beyond "not empty". A reference nobody publishes cannot be wrong.
//
// It also does no scoring, matching app-polo: an activation threshold belongs
// to a program, and this one has none. Contacts are recorded and exported, not
// counted.
//
// ONE activation reference, where app-polo allows several. See
// docs/design/activities.md §3.6 — the multi-reference form control that would
// take is core work, and nothing in the ADIF output depends on it: MY_SIG_INFO
// carries one reference in either app. Hunting is unaffected — a QSO still
// records as many custom references as the other station gives.

import { activityExportHook, defineExtension } from "@ham2k/extension-sdk"
import type { HookContext, JSONValue, Ref, TitleSuggestion } from "@ham2k/extension-sdk"

import { tFor } from "./i18n.ts"

import manifest from "../manifest.json" with { type: "json" }

const ACTIVATION_TYPE = "customActivation"
const HUNTING_TYPE = "custom"

/// The label a bare reference gets when the operator named no program. "Custom
/// XY-1234" reads as a reference in an unnamed scheme, which is what it is.
const FALLBACK_PROGRAM = "Custom"

function refsOfType(source: Record<string, unknown> | undefined, type: string): Ref[] {
  const refs = (source?.refs ?? []) as Ref[]
  return Array.isArray(refs) ? refs.filter((ref) => ref?.type === type) : []
}

function textOf(value: unknown): string {
  return typeof value === "string" ? value.trim() : ""
}

/// The operator fills in a program and a reference separately, but the rest of
/// the app addresses a reference by its `ref` string — so that is the pair,
/// joined. "COTA XY-1234" with a program, "XY-1234" without.
function refStringFor(program: string, reference: string): string {
  return [program, reference].filter((part) => part).join(" ")
}

/// Where the bare reference lives, which differs by ref type and MUST NOT fall
/// back from one to the other.
///
/// An ACTIVATION ref is composed: `mySigInfo` holds the reference and `ref`
/// holds the joined "COTA XY-1234". A HUNTED ref is typed as a single string in
/// the logging control, so `ref` is all there is.
///
/// Reading `ref` as a fallback for an activation looks harmless and is not: the
/// edit path hands back `{...existing, ...formResult}` (activities_view.dart),
/// so a re-save carries the ALREADY-JOINED `ref` back in. With `mySigInfo`
/// cleared, the program is then joined onto it a second time — "COTA COTA
/// XY-1234" — and compounds on every subsequent save, into MY_SIG_INFO and the
/// submitted log with it.
function referenceOf(ref: Ref): string {
  return ref.type === ACTIVATION_TYPE ? textOf((ref as Record<string, unknown>).mySigInfo) : textOf(ref.ref)
}

const refHandler = {
  /// Anything non-empty. There is deliberately no pattern: the whole point of
  /// this activity is the programs whose reference shapes HaLo does not know.
  async validateRef({ ref }: { ref: Ref }, _ctx: HookContext) {
    const normalized = textOf(ref.ref)
    return { valid: normalized.length > 0, normalized }
  },

  async decorateRef({ ref }: { ref: Ref }, _ctx: HookContext): Promise<Ref> {
    const program = textOf((ref as Record<string, unknown>).mySig)
    const reference = referenceOf(ref)
    const name = textOf(ref.name)
    const shortLabel = refStringFor(program || FALLBACK_PROGRAM, reference)
    return {
      ...ref,
      ref: refStringFor(program, reference),
      name,
      program: program || undefined,
      label: name ? `${shortLabel}: ${name}` : shortLabel,
      shortLabel,
    }
  },

  /// Only the activation type titles an operation. Unlike the castle awards
  /// this shares no reference space with anything, so there is no single-hook
  /// dispatch to lose — and a HUNTED reference must never retitle the
  /// operation, since it describes where the OTHER station was.
  async suggestOperationTitle({ ref }: { ref: Ref }, _ctx: HookContext): Promise<TitleSuggestion | null> {
    if (ref.type !== ACTIVATION_TYPE) return null
    const reference = referenceOf(ref)
    if (!reference) return null
    return { at: reference, subtitle: textOf(ref.name) || undefined }
  },
}

const activityHook = {
  async operationControls(_args: { operation: Record<string, JSONValue>; qso?: Record<string, JSONValue> }, ctx: HookContext) {
    const t = tFor(ctx)
    return [
      {
        key: "custom/activation",
        label: t("activationControl"),
        icon: manifest.icon,
        color: manifest.accentColor,
        order: 10,
        optionType: "optional",
        input: {
          kind: "form",
          refType: ACTIVATION_TYPE,
          form: {
            title: t("setupLabel"),
            elements: [
              // Labelled with their ADIF field names on purpose: the operator
              // choosing this activity is by definition working outside the
              // programs HaLo knows, and what they usually need to get right is
              // what the award's log checker will read.
              {
                type: "field",
                fieldType: "text",
                key: "mySig",
                label: t("programLabel"),
                placeholder: t("programPlaceholder"),
              },
              {
                type: "field",
                fieldType: "text",
                key: "mySigInfo",
                label: t("referenceLabel"),
                placeholder: t("referencePlaceholder"),
              },
              {
                type: "field",
                fieldType: "text",
                key: "name",
                label: t("nameLabel"),
                placeholder: t("namePlaceholder"),
              },
            ],
          },
        },
      },
    ]
  },

  /// The hunting side, offered only while actually activating — a custom
  /// reference for the other station means nothing without one of your own to
  /// name the program, since SIG is taken from the activation (see below).
  async loggingControls({ operation }: { operation: Record<string, JSONValue>; qso?: Record<string, JSONValue> }, ctx: HookContext) {
    if (refsOfType(operation, ACTIVATION_TYPE).length === 0) return []
    const t = tFor(ctx)
    return [
      {
        key: "custom/hunting",
        label: t("huntingControl"),
        icon: manifest.icon,
        color: manifest.accentColor,
        order: 10,
        optionType: "optional",
        allowsMultiple: true,
        input: {
          kind: "refList",
          refType: HUNTING_TYPE,
          placeholder: t("huntingPlaceholder"),
        },
      },
    ]
  },

  // No `suggest`: there is no list to search. The activity is added from the
  // Activity Types list and configured by the form above.
}

const adifFieldsHook = {
  /// One record per hunted reference, mirroring the n-fer rule the other
  /// programs follow: a contact that credits two of the other station's
  /// references is submitted as two records.
  ///
  /// SIG comes from the ACTIVATION's program, not the hunted reference — that
  /// is app-polo's rule and it is the right one here, because the hunted
  /// reference is typed as a bare string with no program of its own. It is also
  /// why the control above only appears while activating.
  async fieldCombinationsForOneQSO(
    { qso, operation }: { qso: Record<string, unknown>; operation: Record<string, unknown> },
    _ctx: HookContext,
  ): Promise<{ name: string; value: string }[][]> {
    const activationRef = refsOfType(operation, ACTIVATION_TYPE)[0]
    if (!activationRef) return []

    const program = textOf((activationRef as Record<string, unknown>).mySig)
    const reference = referenceOf(activationRef)

    // BOTH halves or neither: a program name with no reference names nothing,
    // and — since the exporter writes each field once, first hook to answer it
    // wins — a lone MY_SIG would take the name away from the POTA park also
    // being activated and leave POTA's MY_SIG_INFO under it, claiming the park
    // for whatever the operator typed here. The fields on this form are two
    // free-text boxes and either can be left empty.
    const mine: { name: string; value: string }[] =
      program && reference
        ? [
            { name: "MY_SIG", value: program },
            { name: "MY_SIG_INFO", value: reference },
          ]
        : []

    const huntedRefs = refsOfType(qso, HUNTING_TYPE)
    if (huntedRefs.length === 0) return [mine]

    return huntedRefs.map((huntedRef) => {
      const huntedReference = textOf(huntedRef.ref)
      if (!program || !huntedReference) return [...mine]
      return [...mine, { name: "SIG", value: program }, { name: "SIG_INFO", value: huntedReference }]
    })
  },
}

defineExtension({
  ...manifest,
  onActivation({ registerHook }) {
    registerHook(`ref:${ACTIVATION_TYPE}`, { hook: refHandler, key: "custom" })
    registerHook(`ref:${HUNTING_TYPE}`, { hook: refHandler, key: "custom-hunting" })
    registerHook("activity", { hook: activityHook, key: "custom" })
    registerHook("adifFields", { hook: adifFieldsHook, key: "custom" })
    // No `adifImport`, deliberately. Every other activity keys its import on a
    // constant SIG value; here SIG is whatever program name the operator typed,
    // so there is nothing to match — and a hook that claimed every SIG would
    // add a spurious `custom` ref to every POTA and SOTA record it saw.
    //
    // "Claim the SIG values no other program claimed" is the rule that works,
    // and it is not expressible here: `adifImport` hooks run independently and
    // additively, so none of them can know what the others took. Only the
    // importer sees every hook's answer at once, so only the importer could
    // implement it — it does not today, and a log of custom references
    // therefore imports with no references at all.
    //
    // No `scoring` and no `spots`: app-polo's custom activity has neither, and
    // there is no program to spot to.
    registerHook("export", {
      hook: activityExportHook({
        key: "custom",
        label: FALLBACK_PROGRAM,
        activationType: ACTIVATION_TYPE,
        icon: manifest.icon,
      }),
      key: "custom",
    })
  },
})
