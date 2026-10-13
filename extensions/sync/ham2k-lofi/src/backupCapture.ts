// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The reasoning behind sync()'s backup-capture fallback (LoFiRequestError,
// what counts as "LoFi can't be trusted with this payload", the message a
// double-failure throws) -- split from index.ts only so it's testable
// without booting the extension host, the same way errors.ts and report.ts
// are. The actual host.fetch/host.kv wiring stays in index.ts.

/// A non-2xx server reply, kept distinct from plain Errors so linkClient
/// can turn "the server said no" (with its status) into flow data while
/// genuine transport failures keep propagating.
export class LoFiRequestError extends Error {
  status: number
  /// The endpoint that answered, when one did — `v1/reports`, `v1/client`.
  /// A status alone does not say what was refused, and the same code means
  /// different things per endpoint: a 404 from `v1/reports` is an
  /// accountless client, a 404 from `v1/client` is a server that isn't LoFi.
  /// Undefined for a rejection this client synthesized rather than received.
  path?: string
  constructor(message: string, status: number, path?: string) {
    super(message)
    this.status = status
    this.path = path
  }
}

/// A reply that arrived but can't be used: a 2xx proxy or captive-portal page
/// instead of JSON, a 2xx that isn't a sync reply, a token LoFi keeps
/// refusing. Not a LoFiRequestError, so sync's backup capture still fires;
/// its own class so the capture says something answered rather than calling
/// it a network failure. `status` is 0 where the throw site doesn't have it.
export class LoFiUnusableResponseError extends Error {
  status: number
  constructor(message: string, status = 0) {
    super(message)
    this.status = status
  }
}

/// What the backup service is told about why LoFi failed this payload —
/// `failure: {reason, status}` on `/v1/capture`, stored and tagged on its
/// Sentry report (api-lofi `backup-service/README.md`). `status` is the HTTP
/// status actually received, 0 when nothing answered.
export interface BackupCaptureFailure {
  reason: "server_error" | "bad_response" | "timeout" | "network"
  status: number
}

/// Sorts an error sync() is about to capture for. A host.fetch failure
/// reaches the extension as a plain Error carrying the Dart exception's
/// toString (halo_extension_host.dart's host-call catch, kernel.ts
/// hostResponse): a timeout is dart:async's `TimeoutException after ...`, and
/// everything else from host.fetch — package:http's `ClientException`, a TLS
/// `HandshakeException` — is a request that never got an answer.
export function backupCaptureFailure(error: unknown): BackupCaptureFailure {
  if (error instanceof LoFiRequestError) return { reason: "server_error", status: error.status }
  if (error instanceof LoFiUnusableResponseError) return { reason: "bad_response", status: error.status }
  const message = error instanceof Error ? error.message : String(error)
  if (message.startsWith("TimeoutException")) return { reason: "timeout", status: 0 }
  return { reason: "network", status: 0 }
}

/// Whether a LoFi sync failure means LoFi can't be trusted with this payload
/// right now (host.fetch itself threw, or LoFi answered but failed
/// server-side) versus a status LoFi actually and deliberately returned
/// (400/401/403/404/429/...), which is this client's problem, not an outage,
/// and must not trigger a capture.
export function shouldCaptureToBackup(error: unknown): boolean {
  return !(error instanceof LoFiRequestError) || error.status >= 500
}

/// The message `sync` throws when the backup capture ALSO fails, after the
/// original LoFi failure already triggered it. `error_policy.dart`'s
/// `lofi-backup-capture-also-failed` rule matches this exact prefix -- a
/// change here needs a matching change there.
export function backupCaptureAlsoFailedMessage(originalError: unknown, captureError: unknown): string {
  const originalMessage = originalError instanceof Error ? originalError.message : String(originalError)
  const captureMessage = captureError instanceof Error ? captureError.message : String(captureError)
  return `LoFi sync failed and the backup capture also failed: ${originalMessage} (capture error: ${captureMessage})`
}
