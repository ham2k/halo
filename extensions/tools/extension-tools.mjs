#!/usr/bin/env node
// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MIT
//
// The package's own command, so it runs with nothing installed first:
//
//   npx @ham2k/extension-tools dev
//   npx @ham2k/extension-tools init w7abc-notes
//
// npx runs the bin named after the package, and the package has one per
// command; this one hands its arguments to the command named first.

import { realpathSync } from "node:fs"
import { fileURLToPath, pathToFileURL } from "node:url"

export const COMMANDS = {
  init: "./h2kext-init.mjs",
  dev: "./h2kext-dev.mjs",
  pack: "./h2kext-pack.mjs",
  publish: "./h2kext-publish.mjs",
}

export const USAGE = `usage: extension-tools <${Object.keys(COMMANDS).join("|")}> [--help]

Runs h2kext-<command> with the arguments after it:

  init     start an extension in the current directory
  dev      serve it to a running app, rebuilding as you save
  pack     package a built extension as a .h2kext
  publish  upload one to the Ham2K extension catalog`

/// Runs the command [argv] names. Each command runs as its own bin does: its
/// file is imported with `process.argv` set as if it had been started
/// directly, so it reads its arguments and exits as it always does.
export async function run(argv) {
  const [command, ...rest] = argv
  const file = Object.hasOwn(COMMANDS, command ?? "") ? COMMANDS[command] : null
  if (!file) {
    if (command === undefined || command === "--help" || command === "-h") {
      console.log(USAGE)
      return command === undefined ? 2 : 0
    }
    console.error(`extension-tools: unknown command ${command}\n\n${USAGE}`)
    return 2
  }
  const path = fileURLToPath(new URL(file, import.meta.url))
  process.argv = [process.argv[0], path, ...rest]
  await import(pathToFileURL(path).href)
  return null
}

if (process.argv[1] && import.meta.url === pathToFileURL(realpathSync(process.argv[1])).href) {
  const code = await run(process.argv.slice(2))
  if (code !== null) process.exit(code)
}
