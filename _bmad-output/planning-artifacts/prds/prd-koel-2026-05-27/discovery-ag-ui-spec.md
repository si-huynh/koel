# AG-UI Protocol — SDK Implementer's Discovery

**Date:** 2026-05-27
**For:** koel — Flutter/Dart SDK implementing AG-UI in full
**Sources:** [docs.ag-ui.com](https://docs.ag-ui.com/), [github.com/ag-ui-protocol/ag-ui](https://github.com/ag-ui-protocol/ag-ui), CopilotKit blog, pub.dev

> This document captures the AG-UI protocol surface as of the **release/2026-05-26** tag. Where the docs are silent, ambiguity is flagged inline with **[AMBIGUOUS]**.

---

## 1. Spec Version & Status

- **No semantic protocol version exists.** AG-UI ships under date-stamped GitHub release tags. Latest is `release/2026-05-26` (May 26, 2026), 1,928 commits on `main`, 13.9k stars, MIT license.
- TypeScript packages (`@ag-ui/core`, `@ag-ui/client`, `@ag-ui/encoder`, `@ag-ui/proto`) are versioned independently on npm; the **protocol itself has no version negotiation, no version header, no capability advertisement**.
- Status: **actively evolving** — reasoning events, activity events, and binary/proto encoding are recent additions; community SDKs (Dart, Kotlin, Go, Java, Rust, Ruby, C++) lag behind TS/Python reference implementations.
- **[AMBIGUOUS]** No documented deprecation policy, no SemVer guarantee, no spec freeze date. The "protocol" effectively == the TS reference SDK at HEAD.

## 2. Transport

- **Default:** HTTP POST + Server-Sent Events (SSE) response stream. Single request, long-lived response.
- **Request:** `POST /` (path is app-defined) · `Content-Type: application/json` · `Accept: text/event-stream` · body = `RunAgentInput` JSON.
- **Response:** `Content-Type: text/event-stream`. Each event is JSON-serialized and emitted as one SSE `data:` frame by the reference `EventEncoder`.
- **Binary encoding:** parallel protobuf wire format exists (`@ag-ui/proto` package, `.proto` definitions under `sdks/typescript/packages/proto/src/proto/`). Marketed for high-performance/space-efficient transport. **[AMBIGUOUS]** Content-Type, framing, and negotiation mechanism not documented; must read TS source.
- **WebSockets & webhooks:** mentioned as "supported through middleware" but no normative spec — transport-agnostic by design.
- **No transport negotiation.** Client picks endpoint; server picks encoding. Mismatches fail silently or with HTTP errors.
- **Authentication & CORS:** out-of-scope. SDKs configure headers (e.g. `Authorization`) per request — see TS `HttpAgent` constructor.

## 3. Event Types — Full Enumeration

All events inherit `BaseEvent`:

```ts
type BaseEvent = { type: EventType; timestamp?: number; rawEvent?: any }
```

Wire string values are SCREAMING_SNAKE (e.g. `"RUN_STARTED"`). Reference: `sdks/typescript/packages/core/src/events.ts`.

### Lifecycle (5)
| Type | Required fields |
|---|---|
| `RUN_STARTED` | `threadId`, `runId`, `parentRunId?`, `input?: RunAgentInput` |
| `RUN_FINISHED` | `threadId`, `runId`, `result?: any` |
| `RUN_ERROR` | `message: string`, `code?: string` |
| `STEP_STARTED` | `stepName: string` |
| `STEP_FINISHED` | `stepName: string` (must match prior start) |

### Text Message (4)
| Type | Fields |
|---|---|
| `TEXT_MESSAGE_START` | `messageId`, `role: "assistant"` |
| `TEXT_MESSAGE_CONTENT` | `messageId`, `delta: string` |
| `TEXT_MESSAGE_END` | `messageId` |
| `TEXT_MESSAGE_CHUNK` | `messageId?`, `role?`, `delta?` — convenience that auto-expands to start/content/end |

### Tool Call (5)
| Type | Fields |
|---|---|
| `TOOL_CALL_START` | `toolCallId`, `toolCallName`, `parentMessageId?` |
| `TOOL_CALL_ARGS` | `toolCallId`, `delta: string` (JSON fragment — concatenate to reconstruct) |
| `TOOL_CALL_END` | `toolCallId` |
| `TOOL_CALL_RESULT` | `messageId`, `toolCallId`, `content: string`, `role?: "tool"` |
| `TOOL_CALL_CHUNK` | `toolCallId?`, `toolCallName?`, `parentMessageId?`, `delta?` |

### State Management (3)
| Type | Fields |
|---|---|
| `STATE_SNAPSHOT` | `snapshot: any` — full state replace |
| `STATE_DELTA` | `delta: any[]` — RFC 6902 JSON Patch ops |
| `MESSAGES_SNAPSHOT` | `messages: Message[]` — full history replay |

### Activity (frontend-only structured UI) (2)
| Type | Fields |
|---|---|
| `ACTIVITY_SNAPSHOT` | `messageId`, `activityType`, `content: Record<string,any>`, `replace?: boolean` |
| `ACTIVITY_DELTA` | `messageId`, `activityType`, `patch: any[]` (RFC 6902) |

### Reasoning (chain-of-thought) (7)
`REASONING_START`, `REASONING_MESSAGE_START`, `REASONING_MESSAGE_CONTENT`, `REASONING_MESSAGE_END`, `REASONING_MESSAGE_CHUNK`, `REASONING_END`, `REASONING_ENCRYPTED_VALUE` (carries opaque `encryptedValue` for providers like Anthropic/OpenAI that mandate zero-retention CoT round-tripping; `subtype: "tool-call" | "message"`, `entityId`).

### Special (2)
| Type | Fields |
|---|---|
| `RAW` | `event: any`, `source?: string` — passthrough of vendor events |
| `CUSTOM` | `name: string`, `value: any` — app-specific extension |

**Total: ~28 distinct event types** (CopilotKit's "17 event types" blog is outdated and predates reasoning + activity additions).

## 4. Lifecycle Model

```
Client                                                Agent (server)
  │  POST /  RunAgentInput { threadId, runId, state,  │
  │          messages, tools, context, forwardedProps}│
  ├─────────────────────────────────────────────────► │
  │                                                   │
  │           SSE: RUN_STARTED                        │
  │ ◄─────────────────────────────────────────────────┤
  │           SSE: TEXT_MESSAGE_START                 │
  │           SSE: TEXT_MESSAGE_CONTENT (delta)*      │
  │           SSE: TOOL_CALL_START                    │
  │           SSE: TOOL_CALL_ARGS (delta)*            │
  │           SSE: TOOL_CALL_END                      │
  │           SSE: STATE_DELTA (JSON Patch)*          │
  │           SSE: RUN_FINISHED  (or RUN_ERROR)       │
  │ ◄─────────────────────────────────────────────────┤
  │           [connection closes]                     │
```

- **threadId** = conversation identity (persistent across runs). **runId** = single execution within a thread. `parentRunId` enables sub-agent/nested runs.
- A *new* run starts a *new* HTTP POST. Multiple concurrent runs per thread are possible (separate connections), each with unique `runId`.
- **Resumability:** **[AMBIGUOUS]** Docs reference resuming via `threadId` and a `ResumeEntry`/`ResumeStatus` type exists in TS schemas, but no normative event sequence is documented for reconnecting mid-run. SSE's `Last-Event-ID` header is **not** standardized here. SDKs must implement client-side replay-from-snapshot.
- **Cancellation:** **[AMBIGUOUS]** Closing the SSE connection is the de-facto cancel signal. No `RUN_CANCELLED` event. No client→server mid-run signal channel.

## 5. Tool Calls

- **Tools declared by frontend**, passed in `RunAgentInput.tools[]`. Shape: `{ name, description, parameters: JSONSchema }`.
- **Frontend tools are the norm** (not backend) — gives the UI control over what the agent can do. (Backend tools also exist within agent frameworks but are invisible to AG-UI.)
- **Streaming invocation:** `TOOL_CALL_START` → N × `TOOL_CALL_ARGS` (concat `delta` to form JSON args string) → `TOOL_CALL_END`.
- **Result return:** client executes the tool, then on the *next* run includes a `ToolMessage` in `messages[]` (`role: "tool"`, `toolCallId`, `content`). The agent may also emit `TOOL_CALL_RESULT` itself when it executes a backend tool.
- **Sync model.** Agent typically pauses (via interrupt) for frontend-tool results; encrypted reasoning events (`REASONING_ENCRYPTED_VALUE`) carry provider-mandated CoT across the round-trip.
- **Generative UI = tools.** Agent calls a "render component X with props Y" tool; frontend treats the tool call as a render directive instead of executing logic. No dedicated event family — **generative UI is a convention layered on `TOOL_CALL_*`**.

## 6. Generative UI

- No dedicated event family — convention is "**generative UI = tool calls the frontend treats as render directives**" plus `ACTIVITY_SNAPSHOT`/`ACTIVITY_DELTA` for frontend-only structured UI elements (progress bars, checklists) that never reach the agent.
- Oracle/CopilotKit also promote **A2UI (Agent-to-UI)** and **Open Agent Spec** as higher-level component-description layers riding on AG-UI; not part of the core spec.
- **[AMBIGUOUS]** No registry of component schemas, no required props contract — entirely app-defined. Flutter SDK must offer a widget-resolver pattern (string → `WidgetBuilder`).

## 7. State Diff / State Sync

- **Bidirectional shared state**, `state: any` in `RunAgentInput`, mutated by agent via:
  - `STATE_SNAPSHOT` — full replace (cold start, resync)
  - `STATE_DELTA` — RFC 6902 JSON Patch array (add/replace/remove/move/copy/test). Reference impl uses `fast-json-patch`.
- **Last-writer-wins** semantics implied; no CRDT, no vector clocks. Conflict resolution is **app's responsibility** — docs explicitly say "implement strategies for resolving conflicting updates."
- Frontend writes state by including it in the next `RunAgentInput.state`. No mid-run upstream state-patch channel.
- **[AMBIGUOUS]** "Predictive state" mentioned in marketing, not formalized in spec.

## 8. Errors

- **Protocol errors:** `RUN_ERROR` event (`message`, optional `code`). Then the run terminates. No structured error taxonomy.
- **Tool errors:** carried on `ToolMessage` via `error?` field (TS schema), or `TOOL_CALL_RESULT.content` containing error payload by convention. **[AMBIGUOUS]** No standard error shape.
- **Transport errors:** HTTP status codes + SSE connection drops. SDKs handle reconnect/backoff themselves.
- **Validation errors:** SDK-local (e.g. unknown event type) — Dart SDK exposes `ValidationError`.

## 9. Backwards Compatibility / Versioning

- **None codified.** No version field on requests/responses, no `Sec-AGUI-Version` header, no capability negotiation.
- New event types are added by extending the TS reference and rolling forward. Clients that don't recognize an event type can fall back to `RAW`.
- **Implication for koel:** must implement a permissive decoder (skip unknown events without crash) and track upstream TS SDK releases manually.

## 10. Conformance

- **No formal conformance suite.** No "AG-UI Test Kit", no normative test vectors.
- **AG-UI Dojo** (`apps/dojo/`) is the de-facto reference — a Next.js viewer showcasing per-framework scenarios (chat, tool calls, generative UI, shared state, HITL) in 50-200 LOC examples. Useful as behavior reference, not as automated conformance.
- TS SDK has Vitest unit tests; Python SDK has pytest. Each is the source of truth for its language.
- **For koel:** build our own conformance harness against the dojo's scenarios + cross-check serialization against `@ag-ui/encoder` and `@ag-ui/proto` outputs.

## 11. Reference Implementations

| SDK | Path / Package | Status |
|---|---|---|
| **TypeScript** | `@ag-ui/core`, `client`, `encoder`, `proto`, `cli` (npm) | **Reference**, most complete |
| **Python** | `sdks/python` | First-class, used by Pydantic AI, agno, LangGraph adapters |
| **Kotlin** | `sdks/community/kotlin` | Community |
| **Java** | `sdks/community/java` | Community |
| **Go** | `sdks/community/go` | Community |
| **C++** | `sdks/community/c++` | Community |
| **Rust** | `sdks/community/rust` | Community |
| **Ruby** | `sdks/community/ruby` | Community |
| **Dart** | `sdks/community/dart` + [`ag_ui` 0.1.0 on pub.dev](https://pub.dev/packages/ag_ui) | **Community — protocol only, no Flutter widgets, ~16 events (pre-reasoning/activity), no proto, no WebSocket** |
| .NET, Nim | — | In progress |

**The Dart slot is wide open for koel.** Existing `ag_ui` v0.1.0 is single-package, low-effort, 6 likes, 907 downloads, 8 months stale — covers core protocol but lacks reasoning, activity, binary encoding, Flutter widgets, and any HITL/state ergonomics. See GitHub issue [#434 "Dart SDK"](https://github.com/ag-ui-protocol/ag-ui/issues/434).

## 12. Adapters

All under `integrations/` in the monorepo:

| Adapter | Bridges |
|---|---|
| **langgraph** | LangGraph state graphs → AG-UI events. Maps LangGraph nodes to runs/steps, channel updates to `STATE_DELTA`, tool nodes to `TOOL_CALL_*`. |
| **agno** | Agno agents (Python). Streaming text/tools/state mapped to AG-UI. |
| **ag2** | AG2 (formerly AutoGen). Multi-agent group-chats → AG-UI via `parentRunId` nesting. |
| **mastra** | Mastra (TypeScript agent framework). |
| **crew-ai**, **langchain**, **langroid**, **llama-index** | LLM framework bridges. |
| **pydantic-ai**, **microsoft-agent-framework**, **adk-middleware** (Google ADK), **aws-strands**, **vercel-ai-sdk**, **watsonx**, **claude-agent-sdk** | First-party + community framework bridges. |
| **a2a** | A2A (Agent-to-Agent) interop. |
| **agent-spec** | Open Agent Spec / A2UI generative-UI layer. |
| **server-starter**, **server-starter-all-features** | Boilerplate "empty agent" servers — useful as koel test fixtures. |

Each adapter is **server-side** — translates a framework's native event stream into AG-UI events. koel is purely a **client**; it doesn't need to ship adapters, but `server-starter-all-features` is the natural fixture target for our test suite.

---

## Key Ambiguities for SDK Design (consolidated)

1. **No version negotiation** — koel must define its own "supported event types" surface and fail-open on unknowns.
2. **Resumability is implicit** — no normative replay protocol. We choose: cache last `STATE_SNAPSHOT` + `MESSAGES_SNAPSHOT` and replay locally on reconnect.
3. **Cancellation = connection close** — Flutter SDK must wire `Stream` cancellation to underlying HTTP client abort cleanly (`http_client_conformance_tests` says some impls don't).
4. **Binary/proto transport** is underdocumented — initial koel release should be SSE+JSON; proto can follow.
5. **Generative UI contract is app-defined** — koel can win by shipping an opinionated, type-safe `WidgetResolver` API that other SDKs lack.
6. **No conformance suite** — we build one, run it against `server-starter-all-features`, and contribute back.
7. **Tool-result return path** mixes "current-run `TOOL_CALL_RESULT`" with "next-run `ToolMessage` in input" — both valid; SDK should expose both flows clearly.
8. **Reasoning encryption** (`REASONING_ENCRYPTED_VALUE`) is opaque round-trip data — must be preserved verbatim in message history or providers reject.
