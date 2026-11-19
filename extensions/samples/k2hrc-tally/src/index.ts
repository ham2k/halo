// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MIT
//
// An integration: the operator switches it on in the operations they want it
// in, from each operation's Integrations dialog. From then on it is told
// which contacts were logged, edited and deleted there, and keeps a tally of
// them on the FYI line under the call info.
//
// A real integration sends those contacts somewhere: a log service that
// takes each contact as it is logged, an online scoreboard, another program
// on the network. It would do that with `host.fetch` to the hosts its
// manifest's `domains` lists, where this one only counts.
//
// What it leaves out: translation (see docs/extensions/localization.md), and
// remembering the tally across a restart of the app. It starts again from
// zero each time it hears `open`.

import { defineExtension } from "@ham2k/extension-sdk"

import manifest from "../manifest.json"
import { SessionTally } from "./tally.ts"

defineExtension({
  ...manifest,
  onActivation({ registerHook }) {
    registerHook("integration", { key: "k2hrc-tally", hook: SessionTally })
  },
})
