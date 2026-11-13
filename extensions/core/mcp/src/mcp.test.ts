// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MIT
import { test } from "node:test"
import assert from "node:assert/strict"
import type { AgentLinkArgs, HookContext, JSONValue } from "@ham2k/extension-sdk"
import { answer, PROTOCOL_VERSIONS, type Tool } from "./mcp.ts"

const ctx = {} as HookContext

const tools: Tool[] = [
  { name: "look", title: "Look", description: "", inputSchema: { type: "object" }, access: "watch", run: async () => ({ seen: true }) },
  { name: "tune", title: "Tune", description: "", inputSchema: { type: "object" }, access: "change", run: async (args) => ({ tuned: args.khz ?? null }) },
  {
    name: "broken",
    title: "Broken",
    description: "",
    inputSchema: { type: "object" },
    access: "watch",
    run: async () => {
      throw new Error("no radio")
    },
  },
]

function call(message: Record<string, JSONValue>, access: AgentLinkArgs["access"] = "change") {
  return answer({ connection: "c0", client: { name: "test" }, access, message }, ctx, { version: "0.1.0", tools })
}

test("initialize answers the version the client asked for when it speaks it, and its newest otherwise", async () => {
  const [known] = await call({ jsonrpc: "2.0", id: 1, method: "initialize", params: { protocolVersion: "2025-06-18" } })
  assert.equal((known.result as Record<string, JSONValue>).protocolVersion, "2025-06-18")
  const [unknown] = await call({ jsonrpc: "2.0", id: 2, method: "initialize", params: { protocolVersion: "1999-01-01" } })
  assert.equal((unknown.result as Record<string, JSONValue>).protocolVersion, PROTOCOL_VERSIONS[0])
})

// Answering a notification would put a stray response on the wire that the
// client never asked for, and some clients drop the connection over it.
test("a notification gets no answer", async () => {
  assert.deepEqual(await call({ jsonrpc: "2.0", method: "notifications/initialized" }), [])
})

test("an app allowed to watch is offered only the tools that read", async () => {
  const [watching] = await call({ jsonrpc: "2.0", id: 3, method: "tools/list" }, "watch")
  const names = ((watching.result as Record<string, JSONValue>).tools as Record<string, JSONValue>[]).map((t) => t.name)
  assert.deepEqual(names, ["look", "broken"])
  const [changing] = await call({ jsonrpc: "2.0", id: 4, method: "tools/list" }, "change")
  assert.equal(((changing.result as Record<string, JSONValue>).tools as unknown[]).length, 3)
})

// The list is not the boundary: an agent can call a tool by name without
// listing it, and a watch-only app calling one that changes things must be
// refused, in words it can pass on to the operator.
test("a change tool called by name from a watch-only app is refused, saying why", async () => {
  const [reply] = await call({ jsonrpc: "2.0", id: 5, method: "tools/call", params: { name: "tune", arguments: { khz: 14074 } } }, "watch")
  assert.equal(reply.result, undefined)
  assert.match(String((reply.error as Record<string, JSONValue>).message), /watch only/)
})

test("a tool's answer is text and structured content alike", async () => {
  const [reply] = await call({ jsonrpc: "2.0", id: 6, method: "tools/call", params: { name: "tune", arguments: { khz: 14074 } } })
  const result = reply.result as Record<string, JSONValue>
  assert.deepEqual(result.structuredContent, { tuned: 14074 })
  assert.deepEqual(JSON.parse(String((result.content as Record<string, JSONValue>[])[0].text)), { tuned: 14074 })
})

// MCP: a tool that fails is a result the model reads (isError), not a
// protocol error — a protocol error is the client's to handle, and the model
// never learns why its call did nothing.
test("a tool that throws answers isError with its message", async () => {
  const [reply] = await call({ jsonrpc: "2.0", id: 7, method: "tools/call", params: { name: "broken" } })
  const result = reply.result as Record<string, JSONValue>
  assert.equal(result.isError, true)
  assert.equal((result.content as Record<string, JSONValue>[])[0].text, "no radio")
})

test("an unknown method is -32601", async () => {
  const [reply] = await call({ jsonrpc: "2.0", id: 8, method: "resources/list" })
  assert.equal((reply.error as Record<string, JSONValue>).code, -32601)
})
