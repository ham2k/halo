// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MIT
//
// The MCP endpoint behind the agent link (docs/design/agent-link.md): the
// server half of MCP's JSON-RPC, over the messages the app hands the
// `agentLink` hook one at a time. Tools come from `tools.ts`; this file knows
// the protocol and nothing about the station.

import type { AgentLinkArgs, HookContext, JSONValue } from "@ham2k/extension-sdk"

type Message = Record<string, JSONValue>
type Access = AgentLinkArgs["access"]

/// A tool's answer that asks the app to hold the request rather than send
/// it: the app sends [value] after [seconds], unless asking again, with
/// [args] in place of the call's arguments, answers otherwise first. It asks
/// again each time this extension's assistant has observed something
/// (docs/design/agent-link.md § Events).
export class Hold {
  readonly value: JSONValue
  readonly seconds: number
  readonly args: Record<string, JSONValue>

  constructor(value: JSONValue, seconds: number, args: Record<string, JSONValue>) {
    this.value = value
    this.seconds = seconds
    this.args = args
  }
}

/// Where a reply carries its hold, for the app to find and take off.
export const HOLD_META_KEY = "ham2k/hold"

/// One tool, as `tools/list` describes it and `tools/call` runs it.
export interface Tool {
  name: string
  title: string
  description: string
  inputSchema: Record<string, JSONValue>
  /// `watch` tools read; `change` tools act, and are offered only to an app
  /// the operator let make changes.
  access: Access
  run(args: Record<string, JSONValue>, ctx: HookContext): Promise<JSONValue | Hold>
}

/// The protocol versions this endpoint speaks, newest first. A client asking
/// for one of them gets it; any other gets the newest, and decides.
export const PROTOCOL_VERSIONS = ["2025-11-25", "2025-06-18", "2025-03-26", "2024-11-05"]

const INSTRUCTIONS =
  "You are connected to Ham2K Logger, an amateur radio logging app, while its operator is on the air. " +
  "Read what the station is doing with the tools, and call wait_for_events in a loop to follow what the operator does. " +
  "Speak to the operator with post_fyi for a short line they read while operating, and show_notice only for what needs their attention. " +
  "The operator decided whether you may also make changes; when you may, change only what helps them log, and say what you changed. " +
  "You fill in a contact; the operator logs it."

export interface EndpointOptions {
  version: string
  tools: Tool[]
}

/// Answers one message: the replies to send back, none for a notification.
export async function answer(args: AgentLinkArgs, ctx: HookContext, options: EndpointOptions): Promise<Message[]> {
  const { message, access } = args
  const id = message.id
  const method = message.method
  // A response or a notification from the client asks nothing back.
  if (id === undefined || id === null || typeof method !== "string") return []
  const params = (isObject(message.params) ? message.params : {}) as Record<string, JSONValue>
  try {
    return [{ jsonrpc: "2.0", id, result: await dispatch(method, params, access, ctx, options) }]
  } catch (e) {
    if (e instanceof RpcError) return [{ jsonrpc: "2.0", id, error: { code: e.code, message: e.message } }]
    return [{ jsonrpc: "2.0", id, error: { code: -32603, message: String((e as Error)?.message ?? e) } }]
  }
}

class RpcError extends Error {
  readonly code: number

  constructor(code: number, message: string) {
    super(message)
    this.code = code
  }
}

async function dispatch(method: string, params: Record<string, JSONValue>, access: Access, ctx: HookContext, options: EndpointOptions): Promise<JSONValue> {
  switch (method) {
    case "initialize": {
      const asked = params.protocolVersion
      return {
        protocolVersion: typeof asked === "string" && PROTOCOL_VERSIONS.includes(asked) ? asked : PROTOCOL_VERSIONS[0],
        capabilities: { tools: { listChanged: false } },
        serverInfo: { name: "ham2k-logger", title: "Ham2K Logger", version: options.version },
        instructions: INSTRUCTIONS,
      }
    }
    case "ping":
      return {}
    case "tools/list":
      return { tools: offered(options.tools, access).map(describe) }
    case "tools/call": {
      const name = params.name
      const tool = offered(options.tools, access).find((t) => t.name === name)
      if (!tool) {
        // A change tool asked for by an app allowed only to watch is refused
        // in the words the agent can pass on, not as an unknown tool.
        const exists = options.tools.some((t) => t.name === name)
        throw new RpcError(-32602, exists ? `The operator allowed this app to watch only; ${String(name)} makes changes` : `No tool named ${String(name)}`)
      }
      const toolArgs = (isObject(params.arguments) ? params.arguments : {}) as Record<string, JSONValue>
      checkArguments(tool, toolArgs)
      try {
        const answer = await tool.run(toolArgs, ctx)
        const value = answer instanceof Hold ? answer.value : answer
        const result: Record<string, JSONValue> = {
          content: [{ type: "text", text: JSON.stringify(value) }],
          ...(isObject(value) ? { structuredContent: value } : {}),
        }
        if (answer instanceof Hold) result._meta = { [HOLD_META_KEY]: { seconds: answer.seconds, arguments: answer.args } }
        return result
      } catch (e) {
        // A tool that fails is an answer the agent reads and can act on,
        // per MCP, not a protocol error.
        return { content: [{ type: "text", text: String((e as Error)?.message ?? e) }], isError: true }
      }
    }
    default:
      throw new RpcError(-32601, `Method not found: ${method}`)
  }
}

/// Holds [args] to the tool's schema: a missing argument, one of the wrong
/// type, or one the tool does not take is refused by name. Read leniently
/// instead, `"undefined"` becomes a callsign searched for, and a list sent
/// as a string becomes "every one".
function checkArguments(tool: Tool, args: Record<string, JSONValue>): void {
  const required = Array.isArray(tool.inputSchema.required) ? (tool.inputSchema.required as string[]) : []
  for (const name of required) if (args[name] === undefined) throw new RpcError(-32602, `${tool.name} needs \`${name}\``)
  // A schema that lists no properties says nothing about them.
  if (!isObject(tool.inputSchema.properties)) return
  const properties = tool.inputSchema.properties as Record<string, Record<string, JSONValue>>
  for (const [name, value] of Object.entries(args)) {
    const schema = properties[name]
    if (!schema) throw new RpcError(-32602, `${tool.name} takes no \`${name}\``)
    if (!fits(value, schema)) throw new RpcError(-32602, `${tool.name}: \`${name}\` must be ${describeType(schema)}`)
  }
}

function fits(value: JSONValue, schema: Record<string, JSONValue>): boolean {
  if (Array.isArray(schema.enum) && !schema.enum.includes(value)) return false
  switch (schema.type) {
    case "string":
      return typeof value === "string"
    case "number":
      return typeof value === "number" && Number.isFinite(value)
    case "boolean":
      return typeof value === "boolean"
    case "object":
      return isObject(value)
    case "array": {
      const items = isObject(schema.items) ? (schema.items as Record<string, JSONValue>) : null
      return Array.isArray(value) && (!items || value.every((item) => fits(item, items)))
    }
    default:
      return true
  }
}

function describeType(schema: Record<string, JSONValue>): string {
  if (Array.isArray(schema.enum)) return `one of ${schema.enum.join(", ")}`
  if (schema.type === "array" && isObject(schema.items)) return `a list of ${String((schema.items as Record<string, JSONValue>).type)}s`
  return `a ${String(schema.type)}`
}

function offered(tools: Tool[], access: Access): Tool[] {
  return access === "change" ? tools : tools.filter((t) => t.access === "watch")
}

function describe(tool: Tool): Message {
  return {
    name: tool.name,
    title: tool.title,
    description: tool.description,
    inputSchema: tool.inputSchema,
    annotations: { readOnlyHint: tool.access === "watch" },
  }
}

function isObject(value: unknown): value is Record<string, JSONValue> {
  return typeof value === "object" && value !== null && !Array.isArray(value)
}
