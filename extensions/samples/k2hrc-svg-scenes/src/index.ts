// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MIT
import { defineExtension } from '@ham2k/extension-sdk'
import manifest from '../manifest.json' with { type: 'json' }
import { createScenePanels } from './scenes.ts'

defineExtension({
  ...manifest,
  onActivation({ registerHook }) {
    registerHook('panel', { key: manifest.key, hook: createScenePanels() })
  },
})
