// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// api-lofi rejects in two different shapes, and the client only ever saw
// one of them. These pin the shapes against the real controllers, because
// the cost of getting it wrong is not a crash — it's the operator being
// told "LoFi request failed: HTTP 422" and having no idea their address was
// simply already in use.

import assert from 'node:assert/strict'
import { describe, it } from 'node:test'

import { LoFiRequestError } from './backupCapture.ts'
import {
  isRecognizableSyncResponse,
  isUnparseableBody,
  loFiErrorMessage,
  normalizedEmail,
  REPORTS_PATH,
  reportFailureMessage,
} from './errors.ts'

describe('loFiErrorMessage', () => {
  it('reads the top-level error the permission endpoints render', () => {
    // Api::V1::PermissionsController#update, "Permission not found".
    assert.equal(loFiErrorMessage({ error: 'Permission not found' }), 'Permission not found')
  })

  it('reads the nested errors.details the account endpoints render', () => {
    // Api::V1::AccountsController#update renders `account_errors:
    // @account.errors.details`, with no top-level `error` at all — the
    // shape that used to fall through to "HTTP 422".
    assert.equal(
      loFiErrorMessage({
        account_errors: { pending_email: [{ error: 'in use by another account', msg: 'in_use', suggested_action: 'link' }] },
      }),
      'in use by another account',
    )
  })

  it('reads a resend with nothing pending', () => {
    // Api::V1::AccountsController#resend_email's hand-built body.
    assert.equal(
      loFiErrorMessage({ account_errors: { pending_email: [{ error: 'no pending email', msg: 'blank' }] } }),
      'no pending email',
    )
  })

  it('matches on the _errors suffix, not a hard-coded key', () => {
    assert.equal(
      loFiErrorMessage({ permission_errors: { status: [{ error: 'is not included in the list' }] } }),
      'is not included in the list',
    )
  })

  it('prefers a top-level error when both are present', () => {
    assert.equal(loFiErrorMessage({ error: 'the point', account_errors: { a: [{ error: 'noise' }] } }), 'the point')
  })

  it('returns undefined rather than a made-up message', () => {
    // The caller falls back to naming the HTTP status, which is honest.
    // Inventing prose here would put words in the server's mouth.
    assert.equal(loFiErrorMessage({}), undefined)
    assert.equal(loFiErrorMessage({ error: '' }), undefined)
    assert.equal(loFiErrorMessage({ account_errors: {} }), undefined)
    assert.equal(loFiErrorMessage({ account_errors: { pending_email: [] } }), undefined)
    assert.equal(loFiErrorMessage({ account_errors: 'nope' }), undefined)
    assert.equal(loFiErrorMessage({ account_errors: { pending_email: [{ msg: 'blank' }] } }), undefined)
  })
})

describe('normalizedEmail', () => {
  it('matches the server-side normalization', () => {
    // Account#normalize_email downcases and strips before storing, so a
    // capitalized address would otherwise read back as a rejected one.
    assert.equal(normalizedEmail('  SD@Ham2K.com '), 'sd@ham2k.com')
  })

  it('never lets two absent values compare equal', () => {
    // This is the trap: the verification in setAccountEmail compares a
    // missing `pending_email` against what was sent, and `undefined ===
    // undefined` would turn a dropped field into a confirmed change.
    assert.equal(normalizedEmail(undefined), undefined)
    assert.equal(normalizedEmail(null as never), undefined)
    assert.equal(normalizedEmail('   '), undefined)
    assert.equal(normalizedEmail(42 as never), undefined)
  })
})

describe('isRecognizableSyncResponse', () => {
  // The trap: a proxy or maintenance page answering 200-with-HTML parses to
  // `{}`, which has no `error` field — without this predicate the engine
  // marks the pushed batch synced on a reply the server never wrote, and
  // those QSOs never push again.
  it('rejects the {} an unparseable 2xx body produces', () => {
    assert.equal(isRecognizableSyncResponse({}), false)
  })

  it('accepts a normal sync reply (SyncController#sync always renders success/meta/account)', () => {
    assert.equal(isRecognizableSyncResponse({ success: true, meta: {}, account: { uuid: 'a' } }), true)
  })

  it('accepts a cooldown reply, which still carries success and meta counts', () => {
    assert.equal(isRecognizableSyncResponse({ success: true, meta: { qsos: { records_left: 3 } } }), true)
  })

  it('accepts a reply carrying only one of the expected keys, so a server that trims its response does not read as an outage', () => {
    assert.equal(isRecognizableSyncResponse({ meta: {} }), true)
    assert.equal(isRecognizableSyncResponse({ account: { uuid: 'a' } }), true)
  })
})

describe('isUnparseableBody', () => {
  // The trap: a proxy's 200-with-HTML parses to {}, which endpoints read as
  // a valid empty reply and persist over good data (the account snapshot).
  it('flags HTML and other garbage', () => {
    assert.equal(isUnparseableBody('<html><body>Maintenance</body></html>'), true)
    assert.equal(isUnparseableBody('Bad gateway'), true)
  })

  it('lets real JSON and genuinely empty replies through', () => {
    assert.equal(isUnparseableBody('{"success":true}'), false)
    assert.equal(isUnparseableBody('{}'), false)
    assert.equal(isUnparseableBody(''), false)
    assert.equal(isUnparseableBody('  '), false)
  })
})

describe('reportFailureMessage', () => {
  const needsAccount = 'A report needs your LoFi account'

  // The trap: a device with sync switched on but never linked registers as a
  // client just fine, so every gate before the POST passes and the server
  // answers 404. Without the mapping the operator is told "HTTP 404" about
  // an account they could link in a minute.
  it('answers the account refusal for the 404 an accountless client gets', () => {
    assert.equal(
      reportFailureMessage(new LoFiRequestError('LoFi request failed: HTTP 404', 404, REPORTS_PATH), needsAccount),
      needsAccount,
    )
  })

  // The trap: `request()` registers this client on the way through, so a
  // wrong `server` — or anything that isn't a LoFi server — answers 404 from
  // `v1/client` INSIDE the same try. Read by status alone that becomes "link
  // this device", sending the operator to a screen that cannot help and
  // discarding the only words that named the real problem.
  it('leaves a registration 404 saying what it said, so a wrong server is not read as an unlinked device', () => {
    assert.equal(
      reportFailureMessage(new LoFiRequestError('LoFi registration failed: HTTP 404', 404, 'v1/client'), needsAccount),
      'LoFi registration failed: HTTP 404',
    )
    // Synthesized here rather than received, so it names no endpoint — and
    // it already says the thing this mapping exists to say.
    assert.equal(
      reportFailureMessage(new LoFiRequestError('This device is not linked to an account', 404), needsAccount),
      'This device is not linked to an account',
    )
  })

  it('keeps a rejection\'s own words, so an outage is not blamed on the account', () => {
    assert.equal(
      reportFailureMessage(
        new LoFiRequestError('LoFi request failed: in use by another account', 422, REPORTS_PATH),
        needsAccount,
      ),
      'LoFi request failed: in use by another account',
    )
    assert.equal(reportFailureMessage(new Error('Connection refused'), needsAccount), 'Connection refused')
    assert.equal(reportFailureMessage('bare string', needsAccount), 'bare string')
  })
})
