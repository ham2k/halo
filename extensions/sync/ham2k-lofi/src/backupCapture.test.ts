// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0

import assert from "node:assert/strict"
import { describe, it } from "node:test"

import { LoFiRequestError, LoFiUnusableResponseError, shouldCaptureToBackup, backupCaptureAlsoFailedMessage, backupCaptureFailure } from "./backupCapture.ts"

describe("shouldCaptureToBackup", () => {
  it("captures when host.fetch itself threw (not a LoFiRequestError at all)", () => {
    assert.equal(shouldCaptureToBackup(new Error("ClientException: Connection reset by peer")), true)
  })

  it("captures on a >=500 LoFi response", () => {
    assert.equal(shouldCaptureToBackup(new LoFiRequestError("LoFi request failed: HTTP 500", 500)), true)
    assert.equal(shouldCaptureToBackup(new LoFiRequestError("LoFi request failed: HTTP 503", 503)), true)
  })

  it("does NOT capture on a status LoFi deliberately returned", () => {
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

describe("backupCaptureAlsoFailedMessage", () => {
  it("starts with the exact prefix error_policy.dart's rule matches on", () => {
    // app/lib/services/error_policy.dart's `lofi-backup-capture-also-failed`
    // rule does `error.message.startsWith(...)` against this text -- a
    // change here without a matching change there silently stops
    // classifying the double-failure case at all.
    const message = backupCaptureAlsoFailedMessage(new Error("boom"), new Error("also boom"))
    assert.match(message, /^LoFi sync failed and the backup capture also failed:/)
  })

  it("includes both the original and the capture error message", () => {
    const message = backupCaptureAlsoFailedMessage(new LoFiRequestError("LoFi request failed: HTTP 503", 503), new Error("backup capture returned HTTP 500"))
    assert.match(message, /LoFi request failed: HTTP 503/)
    assert.match(message, /backup capture returned HTTP 500/)
  })

  it("stringifies a non-Error thrown value rather than losing it", () => {
    // captureToBackupService only ever throws real Errors, but sync()'s own
    // catch binds `e` from an arbitrary throw -- a non-Error original error
    // must not become "undefined" or crash the formatter.
    const message = backupCaptureAlsoFailedMessage("a plain string throw", 42)
    assert.match(message, /a plain string throw/)
    assert.match(message, /42/)
  })
})

// Without a failure block every HaLo capture reaches the backup service as
// `failure_reason: unknown`, and telling an outage from a phone in a dead spot
// means reconstructing it from Cloudflare's analytics after the fact.
describe("backupCaptureFailure", () => {
  it("reports a LoFi 5xx with the status LoFi actually returned", () => {
    assert.deepEqual(backupCaptureFailure(new LoFiRequestError("LoFi request failed: HTTP 503", 503)), { reason: "server_error", status: 503 })
  })

  it("tells a timeout from a connection that never opened, with no status for either", () => {
    // These are the strings host.fetch's failures reach the extension as: the
    // Dart exception's toString, forwarded by the host-call catch. A timeout is
    // a slow link; a ClientException is no link at all. Neither saw a reply, so
    // neither may carry a status -- a 504 here would read as a gateway failing.
    assert.deepEqual(backupCaptureFailure(new Error("TimeoutException after 0:00:15.000000: Future not completed")), { reason: "timeout", status: 0 })
    assert.deepEqual(
      backupCaptureFailure(
        new Error("ClientException with SocketException: Connection refused (OS Error: Connection refused, errno = 61), uri=https://lofi.ham2k.net/v1/sync"),
      ),
      { reason: "network", status: 0 },
    )
    assert.deepEqual(backupCaptureFailure(new Error("HandshakeException: Connection terminated during handshake")), { reason: "network", status: 0 })
  })

  it("does not call a reply it could not use a network failure", () => {
    // A captive portal answering 200 with HTML is the device's network, not
    // LoFi and not a dead link -- labelling it `network` would hide exactly
    // the case this block exists to diagnose.
    assert.deepEqual(backupCaptureFailure(new LoFiUnusableResponseError("LoFi returned HTTP 200 with an unparseable body", 200)), {
      reason: "bad_response",
      status: 200,
    })
    assert.deepEqual(backupCaptureFailure(new LoFiUnusableResponseError("LoFi sync returned an unrecognizable response (not a sync reply)")), {
      reason: "bad_response",
      status: 0,
    })
  })

  it("still captures an unusable reply", () => {
    // Giving it its own class must not take it out of the fallback.
    assert.equal(shouldCaptureToBackup(new LoFiUnusableResponseError("LoFi authentication failed", 401)), true)
  })
})
