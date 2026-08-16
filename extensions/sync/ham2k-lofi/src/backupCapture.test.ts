// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0

import assert from 'node:assert/strict'
import { describe, it } from 'node:test'

import { LoFiRequestError, shouldCaptureToBackup, backupCaptureAlsoFailedMessage } from './backupCapture.ts'

describe('shouldCaptureToBackup', () => {
  it('captures when host.fetch itself threw (not a LoFiRequestError at all)', () => {
    assert.equal(shouldCaptureToBackup(new Error('ClientException: Connection reset by peer')), true)
  })

  it('captures on a >=500 LoFi response', () => {
    assert.equal(shouldCaptureToBackup(new LoFiRequestError('LoFi request failed: HTTP 500', 500)), true)
    assert.equal(shouldCaptureToBackup(new LoFiRequestError('LoFi request failed: HTTP 503', 503)), true)
  })

  it('does NOT capture on a status LoFi deliberately returned', () => {
    // A 400/401/403/404/429 is this client's problem, not an outage -- LoFi
    // answered and said no. Capturing here would flood the backup service
    // with every rejected request rather than only genuine unreachability.
    for (const status of [400, 401, 403, 404, 422, 429]) {
      assert.equal(
        shouldCaptureToBackup(new LoFiRequestError(`LoFi request failed: HTTP ${status}`, status)),
        false,
        `status ${status} should not trigger a capture`,
      )
    }
  })
})

describe('backupCaptureAlsoFailedMessage', () => {
  it('starts with the exact prefix error_policy.dart\'s rule matches on', () => {
    // app/lib/services/error_policy.dart's `lofi-backup-capture-also-failed`
    // rule does `error.message.startsWith(...)` against this text -- a
    // change here without a matching change there silently stops
    // classifying the double-failure case at all.
    const message = backupCaptureAlsoFailedMessage(new Error('boom'), new Error('also boom'))
    assert.match(message, /^LoFi sync failed and the backup capture also failed:/)
  })

  it('includes both the original and the capture error message', () => {
    const message = backupCaptureAlsoFailedMessage(
      new LoFiRequestError('LoFi request failed: HTTP 503', 503),
      new Error('backup capture returned HTTP 500'),
    )
    assert.match(message, /LoFi request failed: HTTP 503/)
    assert.match(message, /backup capture returned HTTP 500/)
  })

  it('stringifies a non-Error thrown value rather than losing it', () => {
    // captureToBackupService only ever throws real Errors, but sync()'s own
    // catch binds `e` from an arbitrary throw -- a non-Error original error
    // must not become "undefined" or crash the formatter.
    const message = backupCaptureAlsoFailedMessage('a plain string throw', 42)
    assert.match(message, /a plain string throw/)
    assert.match(message, /42/)
  })
})
