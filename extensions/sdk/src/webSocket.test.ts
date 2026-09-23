// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MIT
//
// `host.webSocket` — the browser-shaped object the SDK builds over the
// kernel's socket surface. The host's own rules (allowlist, schemes, identity,
// caps) are tested against a real server in
// packages/halo_extension_host/test/web_socket_test.dart; these cover what
// only the wrapper decides: readyState, the order callbacks fire in, and that a
// refused socket fails the way a browser's does instead of throwing.

import { describe, it, beforeEach } from "node:test"
import assert from "node:assert/strict"

interface Call {
  method: string
  params: Record<string, unknown>
}

// A stand-in kernel: records host calls, and delivers socket events the way
// the real one does — through the listener registered under the id.
let calls: Call[]
let listeners: Map<number, (event: Record<string, unknown>) => unknown>
let refuseOpen: string | null
let refuseClose: string | null
;(globalThis as Record<string, unknown>).__polo = {
  hostCall(method: string, params: Record<string, unknown>) {
    calls.push({ method, params })
    if (method === "webSocketOpen" && refuseOpen) return Promise.reject(new Error(refuseOpen))
    if (method === "webSocketClose" && refuseClose) return Promise.reject(new Error(refuseClose))
    return Promise.resolve(null)
  },
  registerSocket(listener: (event: Record<string, unknown>) => unknown) {
    const id = listeners.size + 1
    listeners.set(id, listener)
    return id
  },
  socketEvent(socketId: number, eventJson: string) {
    listeners.get(socketId)?.(JSON.parse(eventJson))
  },
  log() {},
}

const { host } = await import("./index.ts")

function deliver(socketId: number, event: Record<string, unknown>) {
  listeners.get(socketId)!(event)
}

const settle = () => new Promise((resolve) => setImmediate(resolve))

describe("host.webSocket", () => {
  beforeEach(() => {
    calls = []
    listeners = new Map()
    refuseOpen = null
    refuseClose = null
  })

  it("asks the host to connect under the id its listener was registered with", () => {
    host.webSocket("wss://stream.example.com/feed", { protocols: ["v1"] })

    // The listener must exist before the request goes out, or an `open` the
    // host sends promptly would arrive for an id nothing is listening on.
    assert.equal(listeners.size, 1)
    assert.deepEqual(calls, [{ method: "webSocketOpen", params: { socketId: 1, url: "wss://stream.example.com/feed", protocols: ["v1"] } }])
  })

  it("moves through the browser's readyStates as the host reports them", () => {
    const socket = host.webSocket("wss://stream.example.com/feed")
    const seen: string[] = []
    socket.onopen = () => seen.push(`open ${socket.readyState}`)
    socket.onmessage = (e) => seen.push(`message ${e.data}`)
    socket.onclose = (e) => seen.push(`close ${e.code} ${e.wasClean} ${socket.readyState}`)
    assert.equal(socket.readyState, 0)

    deliver(1, { type: "open", protocol: "v1" })
    deliver(1, { type: "message", data: "hello" })
    deliver(1, { type: "close", code: 1000, reason: "", wasClean: true })

    assert.equal(socket.protocol, "v1")
    assert.deepEqual(seen, ["open 1", "message hello", "close 1000 true 3"])
  })

  it("refuses to send before the socket opens, as a browser does", () => {
    // A send the host would refuse anyway, but asynchronously and into a log:
    // throwing here puts the mistake where the extension can see it.
    const socket = host.webSocket("wss://stream.example.com/feed")
    assert.throws(() => socket.send("too early"), /not open/)
    assert.equal(calls.length, 1)

    deliver(1, { type: "open" })
    socket.send("now")
    assert.deepEqual(calls[1], { method: "webSocketSend", params: { socketId: 1, data: "now" } })
  })

  it("a refused socket reports error then close, and never throws", async () => {
    refuseOpen = "webSocket blocked: 'evil.example.com' is not in extension 'x's declared webSockets"
    const socket = host.webSocket("wss://evil.example.com/")
    const seen: string[] = []
    socket.onerror = (e) => seen.push(`error ${e.message}`)
    socket.onclose = (e) => seen.push(`close ${e.code} ${e.wasClean}`)

    await settle()

    assert.deepEqual(seen, [`error ${refuseOpen}`, "close 1006 false"])
    assert.equal(socket.readyState, 3)
  })

  it("close() checks its code at the caller and goes to closing once", () => {
    const socket = host.webSocket("wss://stream.example.com/feed")
    deliver(1, { type: "open" })

    assert.throws(() => socket.close(1001), /1000 or 3000-4999/)
    assert.equal(socket.readyState, 1, "a refused close must leave the socket open")

    socket.close(4000, "done")
    socket.close()
    assert.equal(socket.readyState, 2)
    assert.deepEqual(
      calls.filter((c) => c.method === "webSocketClose"),
      [{ method: "webSocketClose", params: { socketId: 1, code: 4000, reason: "done" } }],
    )
  })

  it("a close asked for while connecting is not undone by the open that follows", () => {
    // The host can still report `open` for a socket closed mid-handshake. An
    // extension tearing down must not see onopen fire — its handler would
    // send a subscribe on a socket it has already let go of.
    const socket = host.webSocket("wss://stream.example.com/feed")
    let opened = false
    socket.onopen = () => (opened = true)
    socket.close()

    deliver(1, { type: "open" })

    assert.equal(socket.readyState, 2)
    assert.equal(opened, false)
  })

  it("close() refuses what the host would, so the socket is never left closing", () => {
    const socket = host.webSocket("wss://stream.example.com/feed")
    deliver(1, { type: "open" })

    assert.throws(() => socket.close(3000.5), /1000 or 3000-4999/)
    assert.throws(() => socket.close(1000, "é".repeat(62)), /123 UTF-8 bytes/)
    assert.equal(socket.readyState, 1)
    socket.close(1000, "é".repeat(61))
    assert.equal(socket.readyState, 2)
  })

  it("a close the host refuses anyway returns the socket to open", async () => {
    refuseClose = "webSocket: close code must be 1000 or 3000-4999"
    const socket = host.webSocket("wss://stream.example.com/feed")
    deliver(1, { type: "open" })

    socket.close(1000)
    await settle()

    // Still connected on the host: "closing" here would refuse every send on a
    // live connection, with no close event ever coming to end it.
    assert.equal(socket.readyState, 1)
  })

  it("an oversized send throws at the caller rather than failing into a log", () => {
    const socket = host.webSocket("wss://stream.example.com/feed")
    deliver(1, { type: "open" })

    assert.throws(() => socket.send("x".repeat(1024 * 1024 + 1)), /too big/)
    assert.throws(() => socket.send(new Uint8Array(1024 * 1024 + 1)), /too big/)
    assert.equal(calls.filter((c) => c.method === "webSocketSend").length, 0)
  })

  it("binary frames cross as base64 and arrive as an ArrayBuffer", () => {
    const socket = host.webSocket("wss://stream.example.com/feed")
    const received: unknown[] = []
    socket.onmessage = (e) => received.push(e.data)
    deliver(1, { type: "open" })

    // A view into the middle of a larger buffer: sending the whole buffer
    // instead of the view's window is the classic mistake.
    const backing = Uint8Array.from([9, 1, 2, 3, 9])
    socket.send(new Uint8Array(backing.buffer, 1, 3))
    deliver(1, { type: "message", binary: "AQID" })

    assert.deepEqual(calls[1], { method: "webSocketSend", params: { socketId: 1, binary: "AQID" } })
    assert.ok(received[0] instanceof ArrayBuffer)
    assert.deepEqual([...new Uint8Array(received[0] as ArrayBuffer)], [1, 2, 3])
  })
})
