---
title: koel v1 PRD — Protocol & Architecture Reconciliation
status: draft
created: 2026-05-27
companion_to: prd.md, addendum.md
sources:
  - discovery-ag-ui-spec.md (AG-UI release/2026-05-26 baseline)
  - discovery-copilotkit.md (CopilotKit architecture extract)
---

# Reconcile-Spec: PRD vs. Research

Cross-walks every protocol & architecture claim in `prd.md` + `addendum.md` against the two discovery extracts. Verdict header up front; full evidence below.

---

## Verdict

**Faithful with minor gaps.** No spec drift. The PRD honors the protocol surface and the CopilotKit pattern adoption/rejection split that the research recommended. Three minor issues:

1. **Counted-but-untyped event names in addendum §A.1.** `TextMessageChunkEvent` and `ToolCallChunkEvent` are typed, but the addendum gives them no fields and no separate spec entry — they need explicit `messageId?`, `role?`, `delta?` (text) and `toolCallId?`, `toolCallName?`, `parentMessageId?`, `delta?` (tool) per the spec extract §3.
2. **Spec ambiguity silently picked.** `verify` rule F.1 ("`REASONING_ENCRYPTED_VALUE` carries non-`Uint8List` payload" → drop + ProtocolError) commits to a wire shape the spec does not pin down — see §4 below.
3. **Spec count vs. addendum count.** Spec extract enumerates ~28 distinct event types; the addendum lists 28 concrete subtypes + `UnknownAgUiEvent` = 29 classes. Math checks out; document the 28/29 distinction in the changelog so consumers writing exhaustive switches don't think we're hiding one.

No spec rejection (RxJS, GraphQL hop, per-framework split, parameter DSL) was accidentally re-adopted. No event type from the spec extract is unrepresentable in `AgUiEvent`.

---

## 1. Event Coverage (PRD F-A7 vs. spec extract §3)

Spec extract enumerates **28 distinct event types** (lifecycle 5 + text 4 + tool 5 + state 3 + activity 2 + reasoning 7 + special 2 = 28). Cross-walked against addendum §A.1:

| Category | Spec event | Addendum class | Status |
|---|---|---|---|
| Lifecycle (5) | `RUN_STARTED` | `RunStartedEvent` | OK |
| | `RUN_FINISHED` | `RunFinishedEvent` | OK |
| | `RUN_ERROR` | `RunErrorEvent` | OK (carries `KoelError`) |
| | `STEP_STARTED` | `StepStartedEvent` | OK |
| | `STEP_FINISHED` | `StepFinishedEvent` | OK |
| Text (4) | `TEXT_MESSAGE_START` | `TextMessageStartEvent` | OK |
| | `TEXT_MESSAGE_CONTENT` | `TextMessageContentEvent` | OK |
| | `TEXT_MESSAGE_END` | `TextMessageEndEvent` | OK |
| | `TEXT_MESSAGE_CHUNK` | `TextMessageChunkEvent` | **Gap-1: fields elided** |
| Tool (5) | `TOOL_CALL_START` | `ToolCallStartEvent` | OK |
| | `TOOL_CALL_ARGS` | `ToolCallArgsEvent` | OK |
| | `TOOL_CALL_END` | `ToolCallEndEvent` | OK |
| | `TOOL_CALL_RESULT` | `ToolCallResultEvent` | OK |
| | `TOOL_CALL_CHUNK` | `ToolCallChunkEvent` | **Gap-1: fields elided** |
| State (3) | `STATE_SNAPSHOT` | `StateSnapshotEvent` | OK |
| | `STATE_DELTA` | `StateDeltaEvent` (typed `List<JsonPatchOp>`) | OK |
| | `MESSAGES_SNAPSHOT` | `MessagesSnapshotEvent` | OK |
| Activity (2) | `ACTIVITY_SNAPSHOT` | `ActivitySnapshotEvent` | OK |
| | `ACTIVITY_DELTA` | `ActivityDeltaEvent` | OK |
| Reasoning (7) | `REASONING_START` | `ReasoningStartEvent` | OK |
| | `REASONING_END` | `ReasoningEndEvent` | OK |
| | `REASONING_MESSAGE_START` | `ReasoningMessageStartEvent` | OK |
| | `REASONING_MESSAGE_CONTENT` | `ReasoningMessageContentEvent` | OK |
| | `REASONING_MESSAGE_END` | `ReasoningMessageEndEvent` | OK |
| | `REASONING_MESSAGE_CHUNK` | `ReasoningMessageChunkEvent` | OK |
| | `REASONING_ENCRYPTED_VALUE` | `ReasoningEncryptedValueEvent` | OK (see §4) |
| Special (2) | `RAW` | `RawEvent` | OK |
| | `CUSTOM` | `CustomEvent` | OK |

**Count:** 28 spec events → 28 typed `AgUiEvent` subtypes + 1 `UnknownAgUiEvent` forward-compat fallback. **No missing events. No extras.**

**Gap-1 (minor).** Addendum §A.1 elides the field lists for `TextMessageChunkEvent` and `ToolCallChunkEvent` (`...`). Per spec extract §3, these convenience events carry **optional** versions of the corresponding START/CONTENT fields (`messageId?`, `role?`, `delta?` for text; `toolCallId?`, `toolCallName?`, `parentMessageId?`, `delta?` for tool). The chunk-synthesis stage (F-B5, addendum §F.2) reads `id`, `name`, `args`, `complete` from `TOOL_CALL_CHUNK` — those four field names diverge from the spec's wire names (`toolCallId`, `toolCallName`, `delta`). Either the addendum §F.2 description is using shorthand for the typed Dart field names (acceptable) or the typed class will mismatch the wire — needs a one-line clarification at story time.

**Deprecated `THINKING_*` events.** Research extract §A flags `THINKING_START`/`THINKING_END`/`THINKING_TEXT_MESSAGE_*` as deprecated for 1.0.0 removal, superseded by `REASONING_*`. PRD correctly ships only `REASONING_*`. Faithful.

---

## 2. Forward-Compatibility Policy (PRD §11 vs. spec extract §9)

Spec extract §9: **"None codified. No version field, no `Sec-AGUI-Version` header, no capability negotiation. New event types added by rolling forward; clients that don't recognize an event type can fall back to RAW."** Spec extract §11 calls out the Dart SDK must implement permissive decoder.

PRD §11 / FC-1 — every wire event checked against `koel_core` registry; unrecognized → `UnknownAgUiEvent(type, rawJson)` surfaced via `AgentSubscriber.onUnknownEvent`. FC-2 — adding event type = minor bump (with exhaustive-switch caveat documented). FC-3 — manual tracking of upstream TS releases. FC-4 — breaking protocol changes = major bump.

**Verdict: faithful.** The PRD posture is more disciplined than the spec mandates (the spec just says "fall back to RAW"; koel adds a structured `UnknownAgUiEvent` that's actually pattern-matchable). Sound choice — keeps the sealed-switch ergonomic story honest.

**Spec-ambiguity-picked.** Spec extract §9 says "fall back to `RAW`" for unknown events. PRD picks `UnknownAgUiEvent` (distinct from `RawEvent`). Defensible: `RAW` in the spec is for vendor passthrough events the agent *deliberately* surfaces (per spec §3 "Special" — `{event, source?}`); `UnknownAgUiEvent` is for events the *client* doesn't recognize. Conflating them would silently swallow a vendor-passthrough as "unknown" or vice versa. Keep the distinction; just make sure the migration guide explains the difference.

---

## 3. State Sync (PRD F-A8 + addendum B.3 vs. spec extract §7)

Spec extract §7: RFC 6902 JSON Patch (`add`/`replace`/`remove`/`move`/`copy`/`test`). Reference impl uses `fast-json-patch`. **Last-writer-wins implied. No CRDT.** Conflict resolution is the app's responsibility ("implement strategies for resolving conflicting updates").

PRD F-A8: `STATE_DELTA` events carry RFC 6902 patches; `koel_core` applies them strict-mode via `package:json_patch`. No CRDT, no merge resolution. Exposes a `StateConflict` hook for consumers who care. Addendum B.3: chose existing `package:json_patch`, don't reimplement, AG-UI specifies LWW, conflict is consumer's problem.

**Verdict: faithful.** Lib choice (`package:json_patch`) is sound — the research extract §A appendix specifically recommends it (`koel should depend on a JSON Patch package (json_patch on pub.dev) rather than reimplement`).

**Minor.** PRD mentions a `StateConflict` hook in F-A8 prose; addendum §A.1 does not surface it in the typed API. Two readings: (a) it's an `AgentSubscriber` callback that just hasn't been added yet; (b) it's a stream-side event. Worth pinning at story time so it doesn't drift into vestigial.

---

## 4. Reasoning `encryptedValue` (PRD F-A9 + addendum A.1 vs. spec extract §3 + key-ambiguity #8)

Spec extract §3 (Reasoning row): `REASONING_ENCRYPTED_VALUE` carries opaque `encryptedValue` for providers like Anthropic/OpenAI that mandate zero-retention CoT round-tripping; `subtype: "tool-call" | "message"`, `entityId`. Spec extract Key-Ambiguities #8: opaque round-trip data — must be preserved verbatim in message history or providers reject.

PRD F-A9: carried verbatim as opaque `String`/`Uint8List`, never inspected or modified, echoed back on subsequent runs. Addendum §A.1: `ReasoningEncryptedValueEvent.encryptedValue` typed as `Uint8List`.

**Verdict: faithful in intent. Spec ambiguity silently picked, defensibly.**

**The silent pick:** Spec extract does not pin the wire shape of `encryptedValue` — only that it is "opaque." Reference TS schema (per CopilotKit research extract appendix) treats it as a string in JSON. PRD F-A9 says `String`/`Uint8List`. Addendum locks to `Uint8List`. Addendum §F.1 `verify` rule then drops the event if it is "not `Uint8List`."

Two reads of this:
- **Defensible (likely intent):** wire is base64 string; codec layer decodes to `Uint8List` before `verify`; verify just asserts the codec succeeded. Round-trip re-encodes to base64 on the way out. Round-trip semantics preserved bit-for-bit.
- **Drift risk:** if a vendor (e.g. a future provider extension) ships `encryptedValue` as a JSON object or pre-decoded structure, the verify-rule drop would corrupt the round-trip.

**Recommendation at story time:** pin a one-sentence note in the addendum that `encryptedValue` is base64-decoded *at the codec*, and that the wire value (the original string) is preserved alongside the `Uint8List` for verbatim re-emission. The "never inspect or modify" promise (F-A9) sits at the wire, not at the decoded `Uint8List`.

`subtype` and `entityId` fields from the spec are not surfaced in the addendum's class declaration (it's `...`). Need to be added to honor the spec extract §3.

---

## 5. Cancellation (PRD F-B3 + addendum C.2 vs. spec extract §4 + key-ambiguity #3)

Spec extract §4: **"Cancellation: closing the SSE connection is the de-facto cancel signal. No `RUN_CANCELLED` event. No client→server mid-run signal channel."** Key-Ambiguity #3: Flutter SDK must wire `Stream` cancellation to underlying HTTP client abort cleanly (`http_client_conformance_tests` says some impls don't).

PRD F-B3: `StreamSubscription.cancel()` propagates to HTTP-level abort closing TCP. If abort not honored, silent drop with single debug-level warning emitted once per process. Addendum C.2: documented mechanism (subscription → `Client.close()` / `HttpClientRequest.abort()`); fallback silent-drop with `package:logging` once-flag; session reducer produces `RunPhase.cancelled` immediately regardless of TCP outcome; verified-against matrix (`http.Client()`, `IOClient`, `BrowserClient`, custom-wrapped) in `cancellation_test.dart`.

**Verdict: faithful, with concrete mitigation for the research-flagged risk.** The "abort may not honor" branch is exactly the Dart-ecosystem hazard the research called out; PRD addresses it with the once-warning + reducer-state-immediately-cancelled pattern. Sound.

---

## 6. CopilotKit Pattern Adoption (PRD F-A10/A11, F-B5 vs. research §2/§4/§A)

Research recommends adopting:

- **4-stage pipeline (verify → chunks → apply → transform).** Research §A "Implementation tricks worth stealing" #3 (`verify`) + #1 (chunk synthesis) + research §10 references `verify/apply/transform`. PRD F-A11 + addendum C.1 specify the same four stages in the same order. Stages are `StreamTransformer`s, pure. **Faithful — including the order.**

- **AgentSubscriber callback bag.** Research §2 / §10: `AgentSubscriber` is a hook bag (`onEvent`, `onMessage`, `onStateMutation`) — interface with default empty methods. PRD F-A10 + addendum §A.1 `AgentSubscriber` exposes `onRunStart`, `onRunFinish`, `onRunError`, `onStepStart`, `onStepFinish`, `onTextChunk`, `onToolCall`, `onToolResult`, `onStateDelta`, `onReasoning`, `onUnknownEvent`. All with default empty bodies. **Faithful.** Coverage of callbacks is broader than the research sketch (more granular), which is fine — empty defaults compose.

- **Chunk synthesis.** Research §A trick #1: TEXT_MESSAGE_CHUNK / TOOL_CALL_CHUNK → START/CONTENT/END synthesis, halves wire size. PRD F-B5 + addendum §F.2 implements this; default ON via `HttpAgent.synthesizeChunks: true`. **Faithful.**

- **Content negotiation.** Research §A trick #4: `Accept` header content-negotiation between SSE-JSON and protobuf so JSON-only v1 doesn't paint into a corner. PRD §6.2 / NG4 / OQ-Protobuf-Codegen: protobuf deferred to v1.5/v2; v1 ships SSE+JSON. Addendum B.6 specifies `dart:io` + `package:web` browser fallback for `koel_http`. **Faithful structurally** — the `Accept` negotiation door isn't bolted shut; the `HttpAgent` setting an `Accept: text/event-stream` header today doesn't preclude a future `application/vnd.ag-ui+proto` opt-in.

- **`abortController` semantics.** Research §2 implications: "Abort = `CancelableOperation` or explicit `cancel()` on the returned subscription." PRD F-B3 picks the subscription-cancel route over `CancelableOperation`. Defensible — `Stream` is the primary API surface; adding `CancelableOperation` doubles the cancellation vocabulary for no payoff.

- **`Stream` over RxJS.** Research §2 implications: "Pure `Stream`, not RxJS." PRD addendum §A.1 `AbstractAgent.run` returns `Stream<AgUiEvent>`. No `rxdart` in the public surface. **Faithful.** (Addendum doesn't mention `rxdart` even as internal; if `koel_client` later wants replay/multicast for devtools, the research note about "for the 5% reach for `rxdart` *inside* `koel_client` only — never leak it across the API surface" still applies.)

---

## 7. CopilotKit Patterns to NOT Mirror (research §1/§5/§4 vs. PRD §6.2 + addendum D.1/D.3/D.4)

Research recommended **NOT** mirroring:

| Anti-pattern | Why research rejected | PRD posture | Verdict |
|---|---|---|---|
| **GraphQL hop in JS-style** (`runtime-client-gql` between browser and runtime) | Browser-to-server-to-agent indirection serves CopilotKit's React-runtime split, not us | PRD ships `koel_runtime` as a **consumer-side bridge** to an existing CopilotKit Next.js runtime that *already speaks GraphQL*. It is not an internal GraphQL piping layer between koel packages. | **Faithful** — distinction is sound (see §8 below) |
| **RxJS-heavy client internals** | Dart `Stream` covers 95% natively | `Stream<AgUiEvent>` throughout addendum §A. No `rxdart` mention. | **Faithful** |
| **Per-framework packages** (`react-core`, `vue`, `angular`, `react-native`) | Flutter is one platform; we split by concern, not framework | PRD §7 architecture table — koel packages split by *concern* (protocol, http, flutter glue, widgets, devtools, testing, adapters per backend, runtime bridge). No `koel_react`-style framework parallels. NG7 explicitly defers `koel_bloc`/`koel_riverpod`/`koel_getx` to community. | **Faithful** |
| **Custom parameter DSL for tools** | Recreates Zod poorly; Dart has codegen and `JsonSchema` literals | PRD F-E2 / addendum §A.6 `WidgetResolver` operates on `ToolCallEvent`s (typed). No equivalent of `useCopilotAction.parameters: [{name, type: "string", ...}]` DSL exists in the public surface. **`ToolDefinition`** appears in `RunAgentInput.tools` (addendum §A.1) without a parameter-DSL spec, leaving the door open for either `JsonSchema` literal + freezed-codegen (research Option A) or a thin DSL (research Option B). | **Faithful in spirit; under-specified.** The tool-parameter shape is a story-time decision the PRD intentionally elides. Worth a `[ASSUMPTION]` marker like F-B3/F-B5 have, or at least an OQ entry. |

---

## 8. `koel_runtime` GraphQL Bridge — Distinction Sanity-Check

The risk: PRD ships `koel_runtime` with a GraphQL transport (F-C3), and the research extract told us to *avoid* CopilotKit's GraphQL hop. Are these the same thing?

**No.** Two different layers:

- **CopilotKit's internal GraphQL hop** = browser → `@copilotkit/runtime-client-gql` → `@copilotkit/runtime` (Node) → AG-UI agent. Three hops where two could suffice; designed for React's runtime split. *This is what the research said to avoid.*
- **koel_runtime** = Flutter app → CopilotKit Next.js runtime (which is itself a server, and only speaks GraphQL on its external API). One hop. The GraphQL is the *backend's external protocol*, not an internal koel detour.

The research extract itself acknowledges this distinction at §1 "Implications for koel": `koel_runtime` is "**Optional. Most Flutter apps will talk to a TS/Python runtime they don't own. Ship a Dart server adapter only if there's a clear use case.**" PRD includes `koel_runtime` as an *external-server adapter* (same row as `koel_agno`, `koel_langgraph`), not as a piped internal layer. Defensible.

**One nit.** PRD §6.1 G-1 says "both transports (SSE-over-HTTP and GraphQL-bridge-over-CopilotKit-Next.js-runtime)" — listing GraphQL as a "transport" alongside SSE could read as if it's a peer protocol option. It's not: it's a *backend bridge*. Rewording at story time would prevent confusion (e.g., "SSE-over-HTTP transport + one consumer-side bridge to the CopilotKit GraphQL runtime").

---

## 9. Conformance Approach (PRD F-G4 + F-G1 vs. spec extract §10 + research §8)

Spec extract §10: "**No formal conformance suite.** No 'AG-UI Test Kit', no normative test vectors." AG-UI Dojo is the de-facto reference (a Next.js viewer, not automated). For koel: build our own + cross-check against `@ag-ui/encoder` / `@ag-ui/proto` outputs.

Research §8: "Major opportunity. Build `koel_testing` as a public conformance fixture suite." Captured real event streams, goldens for `state`/`messages`, fake transports, shippable to other AG-UI SDK authors.

PRD F-G1: captured SSE fixtures from three backends (AG-UI dojo, agno, langgraph) covering every event type + key flows, JSON Lines with metadata header, updated when AG-UI releases. F-G4: `ConformanceRunner.runAgainst(AbstractAgent)` — runs fixtures against any `AbstractAgent`, used internally for `koel_agno`/`koel_langgraph`/`koel_runtime`, publicly runnable for community adapter authors. Addendum H.7 future-work item: "Conformance test contribution back to the AG-UI repo as the cross-language conformance suite."

**Verdict: faithful and ambitious.** Three notes:

1. PRD doesn't mention the research's "cross-check serialization against `@ag-ui/encoder` and `@ag-ui/proto` outputs" idea. That's a separate (smaller) test category — wire-format codec parity, not behavioral conformance. Worth adding as a sub-feature or test category under F-G4, so the JSON we *emit* matches the TS reference byte-for-byte (where possible).
2. "Updated when AG-UI spec releases" (F-G1) is a maintenance commitment that needs an owner — covered implicitly by FC-3 ("koel tracks the upstream AG-UI TypeScript SDK release stream manually") but worth linking the two FRs.
3. Spec extract §11 calls out that the existing Dart SDK (`ag_ui` 0.1.0) covers only ~16 events; the conformance suite should explicitly include the *delta* (reasoning, activity, encrypted reasoning) so koel's distinguishing coverage is verifiable.

---

## 10. Generative UI (PRD F-E2 vs. spec extract §6 + research §6)

Spec extract §6: "No dedicated event family — convention is '**generative UI = tool calls the frontend treats as render directives**' plus `ACTIVITY_SNAPSHOT`/`ACTIVITY_DELTA` for frontend-only structured UI." No registry of component schemas. **Flutter SDK must offer a widget-resolver pattern (string → `WidgetBuilder`).**

Research §6: mirror both mechanisms (action-render + a2ui-renderer) but invest harder in mechanism 1. `KoelTool.builder` for mechanism 1 (just a widget builder). `koel_generative_ui` package for mechanism 2 (interpret agent-emitted widget trees with extensible registry). Be wary of full DSL.

PRD F-E2: `WidgetResolver` in `koel_flutter`: `Map<String, Widget Function(BuildContext, ToolCallEvent)>` resolves tool name → Widget. Unresolved → `UnknownGenerativeUI` placeholder (consumer-overridable). Addendum §A.6 typed shape matches. PRD §6.2 NG5: `koel_a2ui` deferred to v2. Addendum D.2 documents the rejection of v1 `koel_a2ui` (spec treats generative UI as a `TOOL_CALL_*` convention; `WidgetResolver` is sufficient).

**Verdict: faithful.** PRD ships mechanism 1 (the Flutter widget-builder) explicitly in v1 and defers mechanism 2 (declarative tree interpreter) to v2. Research recommended both with priority on mechanism 1; PRD goes one step further and defers mechanism 2 entirely. Sound — better to ship a tight v1 than two half-baked generative-UI surfaces.

**Minor.** F-E2 carries an `[ASSUMPTION]` marker on "exact signature pending review; intent locked." Addendum §A.6 actually pins the signature. Resolve at next PRD pass — either drop the assumption marker (intent + signature are both locked) or downgrade the addendum to "proposed signature" until P1 reviews.

**Spec ambiguity silently picked.** Spec extract §6 also flags `ACTIVITY_SNAPSHOT`/`ACTIVITY_DELTA` as part of the generative-UI story (frontend-only structured UI for progress bars, checklists). PRD covers the event types (F-A7) but the addendum doesn't sketch how the reducer / `WidgetResolver` handles them. Likely intent: `ActivitySnapshotEvent` and `ActivityDeltaEvent` flow through the reducer into `ChatState.state` (or a dedicated `activities` slot), and consumers handle them with regular widget code, not the `WidgetResolver`. Worth a one-paragraph addendum entry at story time so the activity-event surface isn't accidentally vestigial.

---

## 11. Other Spec Ambiguities the PRD Picks (Consolidated)

| Spec ambiguity | PRD pick | Defensible? |
|---|---|---|
| Resumability via `threadId` / `ResumeEntry` — no normative replay protocol | PRD picks **client-side replay-from-snapshot**: `SessionStorage` persists `ChatState` including in-progress messages with `isComplete: false` (F-D1); reconnect emits `ConnectionResumed` `MetaEvent` (F-B4). No server-side resume protocol assumed. | Yes — matches spec extract Key-Ambiguity #2's stated approach. |
| Cancellation channel: "TCP close only" | PRD picks **subscription-cancel → HTTP abort**, with reducer emitting `RunPhase.cancelled` immediately regardless of TCP outcome | Yes — explicit; deals with the abort-not-honored hazard. |
| Tool-result return path: "current-run TOOL_CALL_RESULT" vs "next-run ToolMessage" | PRD events include `ToolCallResultEvent` for current-run (addendum §A.1) and `RunAgentInput.messages: List<Message>` supports next-run ToolMessage shape (addendum §A.1). Both flows present. | Yes — matches spec extract Key-Ambiguity #7 ("SDK should expose both flows clearly"). |
| WebSocket / proto transport | PRD: **v1 SSE+JSON only**; protobuf deferred (OQ-Protobuf-Codegen); WebSocket not in scope | Yes — matches research §4 ("No WebSocket in MVP. SSE over HTTP/2 is the path of least resistance"). |
| Reasoning `encryptedValue` wire shape | PRD: `Uint8List` (decoded). See §4 above. | Yes, with caveat that round-trip must preserve the original wire string. |
| `RAW` vs `UnknownAgUiEvent` distinction | PRD: separate types. See §2 above. | Yes — `RAW` is agent-intentional vendor passthrough; `UnknownAgUiEvent` is client-detected drift. |

---

## 12. Action Items (Minor, Story-Time)

These are issues to fold into the next PRD pass or the first implementation story. None block PRD finalization.

1. **§A.1 chunk events:** flesh out `TextMessageChunkEvent` and `ToolCallChunkEvent` field declarations to match spec extract §3 (optional `messageId`/`role`/`delta` etc.).
2. **§A.1 `ReasoningEncryptedValueEvent`:** add `subtype: "tool-call" | "message"` and `entityId` fields per spec extract §3. Pin that the `Uint8List` is the decoded form and the wire string is preserved verbatim for round-trip.
3. **§F.2 chunk synthesis:** reconcile field names (`id`/`name`/`args`/`complete`) with spec wire names (`toolCallId`/`toolCallName`/`delta`) — one-line shorthand-vs-wire clarification.
4. **F-A8 `StateConflict` hook:** surface it in addendum §A.1 (likely as an `AgentSubscriber` callback) or drop it from F-A8 prose.
5. **F-G4 codec parity:** add "cross-check serialized JSON against `@ag-ui/encoder` reference output" as a conformance sub-feature.
6. **Activity events:** one paragraph in addendum on how `ACTIVITY_SNAPSHOT`/`ACTIVITY_DELTA` flow through the reducer (separate from `WidgetResolver`) so the events aren't vestigial.
7. **§6.1 G-1 wording:** "GraphQL-bridge" is a *backend bridge*, not a *transport*. Reword to prevent confusion with SSE-as-transport.
8. **Tool parameter DSL:** mark the choice (`JsonSchema` literal + freezed-codegen vs runtime-Map-based handler) as an OQ or `[ASSUMPTION]`. Currently silent.
9. **F-E2 `[ASSUMPTION]` marker:** resolve — addendum §A.6 already pins the signature; either drop the marker or downgrade the addendum entry.

---

*End of reconciliation. No spec drift. Three minor field-level documentation gaps. The CopilotKit-pattern adopt/reject split honored cleanly. The four spec ambiguities the PRD picks are all defensible and called out above.*
