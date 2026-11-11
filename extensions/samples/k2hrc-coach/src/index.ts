// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MIT
//
// An assistant: no pane, no command, nothing for the operator to place. It is
// called about every open operation as a contact is logged and once a minute,
// and says what it notices on the FYI line under the call info.
//
// Two settings of its own, both off until the operator turns them on, change
// the app itself as an operation opens: the screen kept awake, and a layout
// the coach makes and switches to (src/setup.ts).
//
// What it leaves out: translation (see docs/extensions/localization.md), and
// any coaching past the one rule. A real coach would read the band too, mark
// a needed multiplier with `host.bandAnnotations.put`, or move the radio with
// `host.setRadio`.

import { defineExtension } from "@ham2k/extension-sdk"

import manifest from "../manifest.json"
import { RateCoach } from "./coach.ts"

defineExtension({
  ...manifest,
  onActivation({ registerHook }) {
    registerHook("assistant", { key: "k2hrc-coach", hook: RateCoach })
  },
})
