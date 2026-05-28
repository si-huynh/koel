# Discovery: CopilotKit architecture reference for koel

Author: research agent
Date: 2026-05-27
Purpose: Extract CopilotKit's architecture so the koel PRD can decide which patterns to mirror, adapt for Flutter, or skip.

Two upstream repos matter:

- **CopilotKit** — `github.com/CopilotKit/CopilotKit` — opinionated React/Angular/Vue stack + Node/Express runtime.
- **AG-UI protocol** — `github.com/ag-ui-protocol/ag-ui` — the wire protocol and reference TS/Python client/server SDKs. CopilotKit consumes AG-UI; it does not *own* the protocol code.

When koel implements "AG-UI on Flutter", the closest analogue is *not* `@copilotkit/react-core`. It is `@ag-ui/client` (TS) and `ag-ui-protocol/python` (Py). CopilotKit's React layer is one consumer on top of that — koel's Flutter widgets will be a peer consumer, not a port.

---

## 1. Package boundaries

### CopilotKit `/packages/*` (TS, pnpm + Nx)

| Package | What it owns |
|---|---|
| `@copilotkit/shared` | Common types, message schema, utility code shared by runtime + react-core. |
| `@copilotkit/runtime` | Node/Express/Hono server. Receives GraphQL requests from the browser, talks to LLM provider adapters and to AG-UI agents, multiplexes events back as a stream. Files: `packages/runtime/src/{service-adapters,agents,graphql,lib}`. |
| `@copilotkit/runtime-client-gql` | Browser-side GraphQL client that talks to `runtime`. The hop between `react-core` and the network. |
| `@copilotkit/react-core` | React hooks + context: `useCoAgent`, `useCopilotChat`, `useCopilotAction`, `useCopilotReadable`, `useCoAgentStateRender`, `useLangGraphInterrupt`, `useHumanInTheLoop`. State store lives in `CopilotKitProvider`. Files: `packages/react-core/src/{hooks,context,v2}`. |
| `@copilotkit/react-ui` | Drop-in chat widgets: `CopilotChat`, `CopilotSidebar`, `CopilotPopup`. Tailwind-based. |
| `@copilotkit/react-textarea` | AI-augmented `<textarea>` (autocomplete, edit-in-place). Niche. |
| `@copilotkit/react-native` | Recently added — React Native port of react-core/react-ui. Existence proof that the runtime+protocol layers are platform-agnostic. |
| `@copilotkit/angular` / `@copilotkit/vue` | Same hook semantics, framework-idiomatic wrappers. |
| `@copilotkit/sdk-js` | Framework-neutral JS SDK; the LangGraph integration helper class `LangGraphAGUIAgent` lives here. |
| `@copilotkit/a2ui-renderer` | Declarative generative-UI renderer. Agent emits a tree spec, this package turns it into React nodes. |
| `@copilotkit/web-inspector` | **DevTools.** A floating in-app inspector for AG-UI events, frontend tools, hooks. Source: `packages/web-inspector/src/{components,lib,types}`. |
| `@copilotkit/voice` | Voice I/O. |
| `@copilotkit/agentcore-runner` / `sqlite-runner` | Local runners for AWS Bedrock AgentCore and SQLite persistence. |
| `@copilotkit/tailwind-config`, `tsconfig`, `typescript-config` | Internal build/style configs. Boilerplate. |

### AG-UI `/sdks/typescript/packages/*`

| Package | What it owns |
|---|---|
| `@ag-ui/core` | Event enum, Zod schemas for all 30+ event types, `RunAgentInput`, `Message`, `State`, `Interrupt`, `AgentCapabilities`, error classes (`AGUIError`, `AGUIConnectNotImplementedError`). File: `sdks/typescript/packages/core/src/events.ts`. |
| `@ag-ui/encoder` | Wire encoding. SSE (default) or protobuf based on `Accept` header. File: `sdks/typescript/packages/encoder/src/encoder.ts`. |
| `@ag-ui/proto` | Protobuf message definitions. |
| `@ag-ui/client` | The runtime engine. `AbstractAgent` base class, `HttpAgent`, middleware system, `verify`/`apply`/`transform`/`compact`/`chunks`/`interrupts` pipeline. RxJS-based. Files: `sdks/typescript/packages/client/src/`. |
| `@ag-ui/cli` | Scaffolding. |

AG-UI `/integrations/*`: one folder per agent framework (`langgraph`, `crew-ai`, `agno`, `pydantic-ai`, `mastra`, `microsoft-agent-framework`, `aws-strands`, `llama-index`, `ag2`, `langchain`, `a2a`, `vercel-ai-sdk`, `claude-agent-sdk`, `watsonx`). Each provides a thin adapter that converts the framework's native events to AG-UI events.

### Implications for koel (9-package map)

Proposed correspondence to koel's 9 Dart packages:

| koel package (proposed) | Direct analogue | Notes |
|---|---|---|
| `koel_protocol` | `@ag-ui/core` + `@ag-ui/encoder` + `@ag-ui/proto` | Pure-Dart event schemas (sealed classes), JSON + protobuf codecs, no Flutter dependency. |
| `koel_client` | `@ag-ui/client` (`AbstractAgent`, `HttpAgent`, middleware, verify/apply pipeline) | Stream-based, no RxJS — pure `Stream<Event>`. Pure Dart. |
| `koel_runtime` | `@copilotkit/runtime` service-adapter layer | Optional. Most Flutter apps will talk to a TS/Python runtime they don't own. Ship a Dart server adapter only if there's a clear use case. |
| `koel_flutter` | `@copilotkit/react-core` | `ChangeNotifier`/`ValueListenable`-based controllers — the Flutter parallel to React hooks. State-mgmt-agnostic. |
| `koel_widgets` | `@copilotkit/react-ui` | Pre-built `KoelChat`, `KoelSidebar`. Material+Cupertino variants. |
| `koel_generative_ui` | `@copilotkit/a2ui-renderer` | Spec-driven widget tree builder. |
| `koel_devtools` | `@copilotkit/web-inspector` | Flutter DevTools extension + in-app overlay. **Differentiator.** |
| `koel_testing` | (no direct analogue — distributed across `__tests__` dirs) | Conformance fixtures, fake transports, `pumpAgent` helpers. **Differentiator.** |
| `koel_langgraph` (or similar) | `@copilotkit/sdk-js` LangGraphAGUIAgent | Thin client helpers for the most common backend topology. Optional. |

The biggest divergence: CopilotKit splits along *framework* (react-core, angular, vue, react-native, voice). koel splits along *concern* (protocol, client, flutter, widgets, generative_ui, devtools, testing). Flutter is one platform — we don't need react/angular/vue parallels.

---

## 2. Runtime architecture and adapter contract

### What CopilotKit does

The `runtime` package sits between the browser and the agent. Two pluggable interfaces:

**(A) `CopilotServiceAdapter`** — adapts an LLM provider when CopilotKit's "BuiltInAgent" handles orchestration. Source: `packages/runtime/src/service-adapters/service-adapter.ts`:

```ts
interface CopilotServiceAdapter {
  provider?: string;
  model?: string;
  name?: string;
  process(req: CopilotRuntimeChatCompletionRequest): Promise<CopilotRuntimeChatCompletionResponse>;
  getLanguageModel?(): LanguageModel; // for Vercel ai SDK
}
```

Subfolders: `anthropic/`, `openai/`, `google/`, `groq/`, `bedrock/`, `langchain/`, `unify/`, `empty/` (the `ExperimentalEmptyAdapter` no-op), `experimental/`. Each exports a concrete `*Adapter` class.

**(B) AG-UI `AbstractAgent`** — when the agent runs externally (LangGraph, CrewAI, Agno, etc.), CopilotKit treats it as a remote AG-UI agent. The contract lives in AG-UI, not CopilotKit. Source: `sdks/typescript/packages/client/src/agent/agent.ts`:

```ts
abstract class AbstractAgent {
  agentId?: string;
  threadId: string;
  messages: Message[];
  state: State;
  isRunning: boolean;
  pendingInterrupts: Interrupt[];
  subscribers: AgentSubscriber[];
  abstract run(input: RunAgentInput): Observable<BaseEvent>;
  runAgent(parameters?, subscriber?): Promise<RunAgentResult>;
  abortRun(): void;
  clone(): AbstractAgent;
}
```

`HttpAgent extends AbstractAgent` POSTs `RunAgentInput` as JSON, sets `Accept: text/event-stream`, and pipes the SSE stream through `transformHttpEventStream`. Every framework integration in `/integrations/*` is just a subclass: `LangGraphAgent`, `AgnoAgent`, `PydanticAIAgent`, etc.

### Implications for koel

- **Two adapter layers, not one.** Mirror this split exactly.
  - `ServiceAdapter` (Dart): for the rare app that uses koel's Dart runtime *and* wants to swap LLM providers. Anthropic/OpenAI/Bedrock/Groq adapters.
  - `Agent` (Dart): the protocol-level abstraction. `abstract class Agent` with `Stream<AgUiEvent> run(RunAgentInput input)`. `HttpAgent extends Agent`. Subclasses per integration if needed.
- **Pure `Stream`, not RxJS.** AG-UI client uses RxJS `Observable<BaseEvent>` heavily. Dart's `Stream` covers 95% of it natively; for the 5% (replay, multicast) reach for `rxdart` *inside* `koel_client` only — never leak it across the API surface.
- **Abort = `CancelableOperation` or explicit `cancel()`** on the returned subscription. Mirror `abortController` semantics but use Dart-native primitives.
- **Subscribers pattern.** AG-UI's `AgentSubscriber` is a hook bag (`onEvent`, `onMessage`, `onStateMutation`). Dart: an interface with default empty methods, or a record of optional callbacks. Powers devtools without coupling.

---

## 3. Client-side state management

### What CopilotKit does

The `CopilotKitProvider` (in `react-core/src/v2`) owns a global store. Hooks read/write slices of it.

| Hook | Purpose | Returns |
|---|---|---|
| `useCoAgent<T>({ name, initialState })` | Bidirectional state-sync with a named backend agent | `{ name, nodeName, state, setState, running, start, stop, run }` |
| `useCopilotChat()` | Headless chat controller | `{ messages, appendMessage, reload, isLoading, ... }` |
| `useCopilotChatHeadless_c()` | Lower-level headless variant | Raw chat primitives |
| `useCopilotAction({ name, parameters, handler, render })` | Register a frontend tool / generative-UI renderer | void |
| `useCopilotReadable({ description, value })` | Expose app state read-only to the agent | void |
| `useCoAgentStateRender({ name, render })` | Render a component each time agent state changes (for streaming progress) | void |
| `useLangGraphInterrupt(handler)` | Handle LangGraph `interrupt()` calls (human-in-the-loop) | void |
| `useHumanInTheLoop({ name, render, parameters })` | Render an approval dialog mid-run, agent waits for response | void |
| `useFrontendTool({ name, ... })` | Newer, narrower alternative to `useCopilotAction` (tool-only, no UI render) | void |
| `useCopilotChatSuggestions(...)` | Generated suggestion chips | void |
| `useRenderToolCall(...)` | Custom UI for an in-flight tool call | void |

The conceptual model: a **runtime-client object** in context (`useCopilotRuntimeClient`), an **agent registry** keyed by name, a **message log** per thread, and a **frontend-tool registry** that the runtime queries to know what tools to expose.

### Implications for koel

The 1-to-1 hook port is a trap. Hooks compose differently in React than `InheritedWidget` + controllers do in Flutter. Translation:

- **`KoelKitWidget` (root `InheritedWidget`)** — analogue to `CopilotKitProvider`. Owns the agent registry, message store, frontend-tool registry.
- **`AgentController<T>` extends `ChangeNotifier`** — analogue to `useCoAgent`. Construct once per agent name. Exposes `state`, `running`, `nodeName`, `start()`, `stop()`, `run()`, `setState()`. Use with `ValueListenableBuilder` / Riverpod `ChangeNotifierProvider` / `provider` / raw `AnimatedBuilder` — koel stays state-mgmt agnostic.
- **`ChatController` extends `ChangeNotifier`** — analogue to `useCopilotChat`. Owns `List<Message> messages`, `appendMessage`, `reload`, `isStreaming`.
- **Frontend tools register declaratively** via `KoelTool` widgets in the tree (parallel to `useCopilotAction` calls). On mount/unmount they register/unregister with the inherited registry. `KoelTool.builder` for the `render` slot.
- **`useCopilotReadable` → `KoelReadable`** widget: any state in the tree the agent can see.
- **`useCoAgentStateRender` → `AgentStateBuilder<T>`** widget: `Widget Function(BuildContext, T state, String? nodeName)`.
- **Human-in-the-loop** is the most novel pattern — agent run pauses on `interrupt`, frontend renders, user resolves, run resumes. Map to `Future<Resolution> Function(InterruptArgs args)` callback registered against a name. Don't lean on `showDialog` — let consumers choose their UI.

Critical: do **not** try to make `state` reactive via a magic proxy (React's `setState` works because React owns rendering). Use explicit `setState({...})` calls that emit `STATE_DELTA` events.

---

## 4. Transport

### What CopilotKit / AG-UI does

- **Wire format:** SSE by default (`Content-Type: text/event-stream`, `data: ${json}\n\n`). Protobuf available via content-negotiation (`Accept: application/vnd.ag-ui+proto`). Source: `sdks/typescript/packages/encoder/src/encoder.ts`.
- **HTTP method:** POST to a single URL with `RunAgentInput` JSON body. Response is the SSE stream.
- **Cancellation:** standard `AbortController` on the fetch.
- **No WebSocket in the reference HTTP agent.** Other AG-UI integrations (e.g. WebSocketAgent in community) exist but SSE+POST is the canonical path.
- **No reconnect / backoff in the client core.** The `verify` pipeline emits `AGUIError` on protocol violation. Network failures bubble up — apps decide retry policy.
- **`transformHttpEventStream`** parses the SSE stream into typed events, runs them through `verify` (sequence sanity-check), `chunks` (chunk → start/content/end synthesis), `apply` (state/message mutation), `legacy` (back-compat shims for older event shapes).
- **`compareVersions`** at handshake — `AbstractAgent.maxVersion` is read from `package.json` and used to negotiate protocol version.

### Implications for koel

- **Use `http` package + `Stream<List<int>>` SSE parser.** Don't depend on `dio` in `koel_protocol`; let consumers inject their own client (factory `HttpClient Function()`).
- **Backpressure-aware parser.** SSE parsing in Dart is fiddly with multi-byte UTF-8 across chunks — pull `package:eventflux` or implement carefully with `Utf8Decoder(allowMalformed: false)`.
- **First-class `cancel()`** on the run handle. Forward to the underlying `http.Client.close()` / `Dio.cancelToken`.
- **Backoff/retry is a `koel_client` middleware, not core.** Composable interceptor (see §10).
- **Protobuf is optional.** Ship JSON+SSE in MVP; add `koel_protobuf` as a separate package later if real perf data demands it. Don't pay the `protoc_plugin` codegen cost prematurely.
- **No WebSocket in MVP.** AG-UI agrees, and SSE over HTTP/2 is the path of least resistance through corporate proxies.

---

## 5. Tool handlers

### What CopilotKit does

`useCopilotAction({ name, description, parameters, handler, render, renderAndWaitForResponse })`:

- **`parameters`** — array of `{ name, type, description?, required?, enum?, attributes? }`. Type is a string literal: `"string" | "number" | "boolean" | "object" | "string[]" | ...`. Nested objects use `attributes`.
- **No Zod at this layer.** Despite Zod being used heavily inside `@ag-ui/core` for *event* schemas, frontend-tool parameters use this custom JSON-schema-ish DSL. CopilotKit infers TS types from the schema via heavy conditional types (look at `use-copilot-action.ts` generics).
- **`handler({ ...args })`** returns sync or `Promise<any>`. Return value becomes the tool result event.
- **`render({ args, status, result, respond })`** is the generative-UI hook — renders during the tool call. `status` ∈ `"inProgress" | "executing" | "complete"`. `args` is partial during streaming.
- **`renderAndWaitForResponse`** — render a UI, agent pauses until `respond(value)` is called. Used for confirmations.
- **`"*"` catch-all** action name renders any unknown tool call.

Registration is *implicit* — calling the hook in render registers the tool; unmount unregisters.

### Implications for koel

- **Don't recreate Zod.** Dart already has the patterns:
  - Option A (recommended): `JsonSchema` literal + `freezed`/`json_serializable`-generated `fromJson` for the `args` type. Type-safety via codegen.
  - Option B (lighter): keep CopilotKit's parameter-array DSL; provide a `dart_mappable` or runtime-Map-based handler signature.
- **Three handler shapes**, matching CK:
  ```dart
  KoelTool<TArgs>({
    required String name,
    String? description,
    required JsonSchema parameters,
    FutureOr<Object?> Function(TArgs args)? handler,
    Widget Function(BuildContext, ToolCallState<TArgs>)? builder,
    Future<Object?> Function(BuildContext, TArgs args)? builderAndAwaitResponse,
  })
  ```
- **Tool call streaming.** AG-UI streams `TOOL_CALL_ARGS` deltas; the builder must accept partial args (e.g. `Map<String, dynamic>` with `complete: bool`). Match CK's `status` enum.
- **Catch-all `"*"`** is a useful escape hatch; keep it.

---

## 6. Generative UI

### What CopilotKit does

Two distinct mechanisms, often confused:

1. **Action `render`** (above) — React component lives in user code, runs *each event* during the tool call. The agent picked what tool to call; the *frontend* picked what to render. Frontend-driven generative UI.

2. **`a2ui-renderer`** — agent emits a declarative widget spec (a JSON tree of components + props). Renderer interprets it on the client. Agent-driven generative UI. Files: `packages/a2ui-renderer`. Used via `useCoAgentStateRender` or a dedicated component.

Plus the related `useCoAgentStateRender({ render: ({ state, nodeName }) => ... })` — render arbitrary UI per agent state snapshot. Streaming progress dashboards live here.

### Implications for koel

- **Mirror both mechanisms — but invest harder in mechanism 1.** Flutter app developers want to ship hand-crafted widgets, not interpret JSON.
- **`KoelTool.builder`** = mechanism 1. Just a widget builder, no special machinery.
- **`koel_generative_ui` package** = mechanism 2. Interpret agent-emitted widget trees. Define an extensible registry: `KoelComponentRegistry.register('chart', (spec) => MyChart(spec))`. Ship a minimal default set (Text, Column, Row, Card, Button, TextField).
- **Be wary of going full DSL.** A JSON-tree-to-Widget interpreter that supports arbitrary layouts becomes a competitor to `flutter_widget_from_html` / `rfw`. Constrain scope: pre-registered components only, no expression evaluation, no logic.
- **`AgentStateBuilder<T>`** widget for `useCoAgentStateRender`. Single `Widget Function(BuildContext, T, String? nodeName)` callback.

---

## 7. DevTools

### What CopilotKit does

`@copilotkit/web-inspector` — an in-app floating panel with:

- **AG-UI event log** (every event with timestamp, type, payload).
- **Hook explorer** — which hooks are mounted, their args, their values.
- **Frontend tools panel** — what tools are registered, their schemas, recent invocations.
- **Error panel** — the `tool_handler_failed` and friends with stack traces.
- Hot-reloads with the app (no separate window/devtools instance).

Plus a VS Code extension (separate, less mature) and references to an "AG-UI Event Inspector" in docs.

### Implications for koel

- **This is koel's biggest user-experience differentiator.** Flutter has DevTools (Dart VM Service Protocol-based) as a separate window — Brian Egan's Redux DevTools precedent shows it works. Ship both:
  - **In-app overlay** (`KoelInspectorOverlay`) — toggled by a debug-only floating button, like `flutter_inspector`'s widget tree button. Zero-config in debug builds.
  - **DevTools extension** (`devtools_extensions` package) — a tab in the official Flutter DevTools that shows the same data, post-mortem-friendly.
- **Time-travel.** Record event stream, scrub backward, replay forward. Out of scope for v1 but the event-stream architecture makes it cheap to add — design `koel_client` so the event stream is observable by a subscriber that records to a ring buffer.
- **Hot reload safety.** All controllers must survive hot reload (don't capture closures over disposed agents).

---

## 8. Conformance / fixtures

### What CopilotKit does

- **No dedicated conformance suite at the protocol level.** Each AG-UI integration in `/integrations/*` has its own tests against its framework.
- `@ag-ui/client/__tests__/` has unit tests for `verify`, `apply`, `transform`, chunks — these double as informal protocol fixtures.
- `showcase/` directory contains per-framework demo apps used for parity testing manually.
- No published conformance JSON-fixture corpus.

### Implications for koel

**Major opportunity.** Build `koel_testing` as a public conformance fixture suite:

- **Captured real event streams** from LangGraph, CrewAI, Agno, Pydantic AI, OpenAI tools — stored as `.jsonl` files in `koel_testing/fixtures/`.
- **Goldens** asserting `state` and `messages` after replay.
- **Fake transports** — `FakeAgent` that emits a scripted event sequence; `pumpAgent` helper for widget tests.
- **`koel_testing` is shippable to other AG-UI SDK authors** (Python, Rust, Kotlin). Lock-in for koel: koel's tests become the reference. This is a strategic moat the React stack lacks.

---

## 9. Error model

### What CopilotKit / AG-UI does

- **`@ag-ui/core` exports `AGUIError` and `AGUIConnectNotImplementedError`.** Two concrete classes, not a sealed union. (Reference: import line in `agent.ts`.)
- **`RUN_ERROR` event** carries a structured error payload in the protocol.
- **No retry/backoff at protocol level** — client surfaces the error and ends the run.
- **CopilotKit-side codes are stringly-typed** — e.g. `tool_handler_failed`. Docs reference these by string.
- **Errors flow through the same RxJS stream as events** — consumers receive them as terminal events on the `Observable<BaseEvent>`.

### Implications for koel

- **Sealed `KoelError` hierarchy.** Dart `sealed class` (Dart 3+) — exhaustive `switch` in consumer code:
  ```dart
  sealed class KoelError implements Exception {}
  final class KoelProtocolError extends KoelError { /* malformed event */ }
  final class KoelTransportError extends KoelError { /* network */ }
  final class KoelRunError extends KoelError { /* RUN_ERROR event */ }
  final class KoelToolHandlerError extends KoelError { /* tool threw */ }
  final class KoelInterruptUnresolvedError extends KoelError {}
  ```
- **`Stream<AgUiEvent>` carries errors via `.addError`** — Dart-idiomatic, equivalent to Observable error. Consumers `.handleError`.
- **`Result<T, KoelError>` for terminal `runAgent()` return** — but only at the outer API; inside the stream, errors flow as stream errors.
- **No automatic retry in core.** Provide an opt-in `RetryMiddleware` (next section).
- **Carry an `errorCode` string field** matching CopilotKit's codes (`tool_handler_failed`, etc.) for cross-SDK consistency with the wire protocol.

---

## 10. Cross-cutting: middleware, interceptors, auth

### What CopilotKit / AG-UI does

- **AG-UI `@ag-ui/client/src/middleware`** — a real, documented middleware system:
  - `Middleware` base class with `wrap(next)` semantics.
  - `MiddlewareFunction` for closure-style middlewares.
  - Shipped: `FilterToolCallsMiddleware`, `BackwardCompatibility_0_0_39/45/47` (version shims).
  - Per-run mutation hooks via `AgentSubscriber`.
- **HTTP headers** — `HttpAgent.headers` is a plain `Record<string, string>`; that's where auth tokens go. `requestInit()` is overridable for custom auth (mTLS, signed requests).
- **No formal auth abstraction in core.** Apps build it.
- **CopilotKit runtime side has more** — `runtime/src/lib` has `properties` for forwarded request context, used to plumb user identity.

### Implications for koel

- **First-class middleware.** Dart functional pattern is easy:
  ```dart
  typedef KoelMiddleware = Stream<AgUiEvent> Function(
    RunAgentInput input,
    Stream<AgUiEvent> Function(RunAgentInput) next,
  );
  ```
  Compose with `Iterable<KoelMiddleware>.fold`. Ship out of the box:
  - `RetryMiddleware({ maxAttempts, backoff })` — opt-in retry.
  - `LoggingMiddleware` — verbose log of events.
  - `RecordingMiddleware` — captures for devtools/time-travel.
  - `AuthMiddleware({ tokenProvider })` — injects `Authorization` header from a `Future<String> Function()` (refreshable).
  - `FilterToolCallsMiddleware` (parity).
- **Headers via builder pattern.** `Agent(url: ..., headersBuilder: () async => {...})` — refresh on every run, supports OAuth token rotation.
- **`AgentSubscriber` parity** — interface for cross-cutting concerns that need *every* event (devtools, analytics).
- **Threading & isolates.** Long-running agents that crunch state deltas can starve the UI thread. Consider running the `apply`/`verify` pipeline on a `compute()` isolate boundary for large `STATE_SNAPSHOT` payloads. Benchmark before doing this — Dart's JSON parsing on the main thread is usually fine for <1 MB snapshots.

---

## Appendix A: AG-UI event taxonomy (current as of upstream main)

From `sdks/typescript/packages/core/src/events.ts`:

- **Lifecycle:** `RUN_STARTED`, `RUN_FINISHED`, `RUN_ERROR`, `STEP_STARTED`, `STEP_FINISHED`
- **Text:** `TEXT_MESSAGE_START`, `TEXT_MESSAGE_CONTENT`, `TEXT_MESSAGE_END`, `TEXT_MESSAGE_CHUNK`
- **Tools:** `TOOL_CALL_START`, `TOOL_CALL_ARGS`, `TOOL_CALL_END`, `TOOL_CALL_CHUNK`, `TOOL_CALL_RESULT`
- **State:** `STATE_SNAPSHOT`, `STATE_DELTA`, `MESSAGES_SNAPSHOT`, `ACTIVITY_SNAPSHOT`, `ACTIVITY_DELTA`
- **Reasoning:** `REASONING_START`, `REASONING_END`, `REASONING_MESSAGE_START`, `REASONING_MESSAGE_CONTENT`, `REASONING_MESSAGE_END`, `REASONING_MESSAGE_CHUNK`, `REASONING_ENCRYPTED_VALUE`
- **Deprecated (1.0.0 removal):** `THINKING_START`, `THINKING_END`, `THINKING_TEXT_MESSAGE_*` — superseded by `REASONING_*`. koel ships only the new names.
- **Special:** `RAW`, `CUSTOM`

`STATE_DELTA` payload is **JSON Patch (RFC 6902)** — koel should depend on a JSON Patch package (`json_patch` on pub.dev) rather than reimplement.

## Appendix B: Reference file paths

CopilotKit:
- `packages/runtime/src/service-adapters/service-adapter.ts` — `CopilotServiceAdapter` interface
- `packages/runtime/src/agents/langgraph/` — LangGraph agent integration
- `packages/react-core/src/hooks/use-coagent.ts` — bidirectional agent state hook
- `packages/react-core/src/hooks/use-copilot-action.ts` — frontend tool registration
- `packages/react-core/src/v2/` — current-generation provider + `useAgent` primitive
- `packages/web-inspector/src/` — devtools panel
- `packages/a2ui-renderer/` — declarative generative UI

AG-UI:
- `sdks/typescript/packages/core/src/events.ts` — event enum + Zod schemas
- `sdks/typescript/packages/encoder/src/encoder.ts` — SSE / protobuf encoding
- `sdks/typescript/packages/client/src/agent/agent.ts` — `AbstractAgent` base
- `sdks/typescript/packages/client/src/agent/http.ts` — `HttpAgent` (SSE consumer)
- `sdks/typescript/packages/client/src/middleware/` — middleware system
- `sdks/typescript/packages/client/src/{verify,apply,transform,chunks,compact,interrupts}/` — event pipeline stages

## Appendix C: Implementation tricks worth stealing

1. **Chunk → start/content/end synthesis.** `@ag-ui/client/src/chunks/` accepts agents that emit only `TEXT_MESSAGE_CHUNK` (no start/end) and synthesizes the start/end boundaries downstream. Halves wire size for verbose providers. Steal for `koel_client`.
2. **Version-negotiation backward-compat shims** as named middleware (`BackwardCompatibility_0_0_39`, `_45`, `_47`). Lets koel evolve without breaking older agents — and the shims live in *one place*, not scattered.
3. **`verify` stage.** A pure-function pipeline stage that asserts event-sequence sanity (e.g. `TOOL_CALL_END` only after `TOOL_CALL_START` for the same id) and emits `AGUIError` otherwise. Catches malformed-agent bugs immediately instead of corrupting state. Cheap, high value.
4. **`Accept` header content-negotiation** between SSE-JSON and protobuf. Lets koel ship JSON-only v1 and add protobuf later without breaking clients — same endpoint, just upgrade `Accept`.
5. **`structuredClone_` everywhere.** AG-UI deep-clones config maps on agent construction to prevent caller mutation. Dart equivalent: `jsonDecode(jsonEncode(map))` for simple maps, or just lean on immutable `freezed` types. The discipline matters.

