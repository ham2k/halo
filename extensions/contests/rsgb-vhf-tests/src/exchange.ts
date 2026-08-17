// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The grid half is identical to r1-vhf-tests' (every RSGB event also sends a
// 6-character grid) and re-exported from there rather than duplicated.
// Separate from index.ts so this can be unit-tested: index.ts calls
// `defineExtension` at import time, so nothing in it is reachable from
// `node --test`.

export { GRID_PATTERN, guessedGrid, trimmedGrid } from "../../r1-vhf-tests/src/exchange.ts"
