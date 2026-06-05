---
title: koel v1 — PRD Addendum
status: final
created: 2026-05-27
updated: 2026-05-28
companion_to: prd.md
---

# koel v1 — PRD Addendum

Technical depth that earned a place but did not fit the PRD body. The audit trail and override notes live in `.decision-log.md`, not here.

## A. Full Public API Signatures

The authoritative 1.x contract. The PRD body lists the names; this section pins the shapes.

### A.1 `koel_core`

```dart
// AbstractAgent — backend-bridge SPI. NOT for direct consumer use.
// Use KoelClient instead; AbstractAgent is what backend-bridge packages implement.
interface class AbstractAgent {
  /// Initiates a run. Returns the canonical event stream.
  /// Cancelling the subscription cancels the run.
  /// Adapters never throw KoelError — they emit RunErrorEvent.
  Stream<AgUiEvent> run(RunAgentInput input);
}

// KoelClient — top-level configuration. Wraps an AbstractAgent in interceptors + subscribers.
class KoelClient {
  KoelClient({
    required AbstractAgent agent,
    SessionStorage? sessionStorage,
    ChatStateReducer? reducer,
    List<Interceptor>? interceptors,
    List<AgentSubscriber>? subscribers,
    ErrorClassifier? errorClassifier,
    StateConflictResolver? stateConflictResolver,
    int devtoolsBufferSize = 1000,
    BackpressurePolicy backpressure = BackpressurePolicy.pauseUpstream,
  });

  ChatSession newSession({String? threadId, ChatState? initial});

  /// Power-user escape hatch (F-A2 layer 3): bypasses ChatSession, returns
  /// the event stream with interceptors + subscribers + pipeline applied
  /// but no reducer / no persistence / no controller binding.
  Stream<AgUiEvent> runRaw(RunAgentInput input);

  void dispose();
}

// RunAgentInput — wire payload.
class RunAgentInput {
  final String threadId;
  final String runId;
  final Map<String, dynamic> state;
  final List<Message> messages;
  final List<ToolDefinition> tools;
  final Map<String, dynamic> context;
  final Map<String, dynamic> forwardedProps;
  /// Opaque reasoning blobs to echo back so providers can replay reasoning.
  /// Keys are reasoning ids from prior runs; values are the byte blobs verbatim.
  final Map<String, Uint8List>? reasoningEcho;
  const RunAgentInput({...});
}

// ToolDefinition — what the agent is allowed to call.
class ToolDefinition {
  final String name;
  final String description;
  /// JSON Schema (Map<String, dynamic>) in v1. See OQ-Tool-Param-DSL.
  final Map<String, dynamic> parameters;
  const ToolDefinition({...});
}

// ChatSession — middle layer (F-A2 layer 2).
class ChatSession {
  String get threadId;
  ChatState get state;
  Stream<ChatState> get stream;
  Stream<AgUiEvent> get events;

  Future<void> send(String content, {List<ToolDefinition>? tools});
  void cancel();
  Future<void> clear();
  Future<void> persist();
  void dispose();
}

// ChatState — immutable. All collections are unmodifiable views.
@freezed
class ChatState with _$ChatState {
  const factory ChatState({
    @Default([]) List<Message> messages,
    Message? pendingMessage,
    @Default([]) List<ToolCall> pendingToolCalls,
    @Default({}) Map<String, dynamic> state,
    /// Carries reasoning encryptedValue blobs to be echoed in the next run.
    /// Keys are reasoning ids; values are byte blobs.
    @Default({}) Map<String, Uint8List> reasoningEcho,
    KoelError? error,
    @Default(RunPhase.idle) RunPhase phase,
  }) = _ChatState;
}

enum RunPhase { idle, running, stepRunning, error, cancelled }

// AgUiEvent — sealed union over all protocol events.
sealed class AgUiEvent { const AgUiEvent(); }

class RunStartedEvent extends AgUiEvent { ... }
class RunFinishedEvent extends AgUiEvent { ... }
class RunErrorEvent extends AgUiEvent { final KoelError error; ... }
class StepStartedEvent extends AgUiEvent { ... }
class StepFinishedEvent extends AgUiEvent { ... }
class TextMessageStartEvent extends AgUiEvent { ... }
class TextMessageContentEvent extends AgUiEvent { ... }
class TextMessageEndEvent extends AgUiEvent { ... }
class TextMessageChunkEvent extends AgUiEvent {
  final String? messageId;
  final String? role;
  final String? delta;
  ...
}
class ToolCallStartEvent extends AgUiEvent { ... }
class ToolCallArgsEvent extends AgUiEvent { ... }
class ToolCallEndEvent extends AgUiEvent { ... }
class ToolCallResultEvent extends AgUiEvent { ... }
class ToolCallChunkEvent extends AgUiEvent {
  final String? toolCallId;
  final String? toolCallName;
  final String? parentMessageId;
  final String? delta;
  ...
}
class StateSnapshotEvent extends AgUiEvent { ... }
class StateDeltaEvent extends AgUiEvent { final List<JsonPatchOp> patches; ... }
class MessagesSnapshotEvent extends AgUiEvent { ... }
class ActivitySnapshotEvent extends AgUiEvent { ... }
class ActivityDeltaEvent extends AgUiEvent { ... }
class ReasoningStartEvent extends AgUiEvent { ... }
class ReasoningEndEvent extends AgUiEvent { ... }
class ReasoningMessageStartEvent extends AgUiEvent { ... }
class ReasoningMessageContentEvent extends AgUiEvent { ... }
class ReasoningMessageEndEvent extends AgUiEvent { ... }
class ReasoningMessageChunkEvent extends AgUiEvent { ... }
class ReasoningEncryptedValueEvent extends AgUiEvent {
  /// Reasoning blob id used to round-trip via RunAgentInput.reasoningEcho.
  final String entityId;
  /// "tool-call" or "message" — which sub-stream of reasoning this attaches to.
  final String subtype;
  /// Opaque blob — round-trip verbatim, never inspect.
  /// Wire format is base64 string; codec layer decodes to bytes here AND
  /// preserves the original string on a sibling field so round-trip is bit-exact.
  final Uint8List encryptedValue;
  final String encryptedValueBase64;
  ...
}
class RawEvent extends AgUiEvent { final Map<String, dynamic> payload; ... }
class CustomEvent extends AgUiEvent { ... }
class UnknownAgUiEvent extends AgUiEvent {
  final String type;
  final Map<String, dynamic> rawJson;
  const UnknownAgUiEvent({required this.type, required this.rawJson});
}

// ChatStateReducer.
abstract class ChatStateReducer {
  ChatState reduce(ChatState state, AgUiEvent event);
}

class DefaultChatStateReducer implements ChatStateReducer { ... }
class ComposedReducer implements ChatStateReducer {
  ComposedReducer(List<ChatStateReducer> reducers);
}

// Interceptor.
abstract class Interceptor {
  Stream<AgUiEvent> intercept(InterceptorChain chain, RunAgentInput input);
}

class InterceptorChain {
  Stream<AgUiEvent> proceed(RunAgentInput input);
}

// KoelError — sealed. Adapters NEVER throw this; they emit RunErrorEvent carrying it.
// The Exception marker exists only so Future.catchError can catch programmer errors
// from synchronous constructor / setup paths (e.g. invalid Uri to KoelClient(...)).
sealed class KoelError implements Exception {
  String get message;
  KoelErrorCode get code;
  Object? get cause;
}

class TransportError extends KoelError { final int? statusCode; ... }
class ProtocolError extends KoelError { final String? eventType; ... }
class AgentError extends KoelError { final String? agentCode; ... }
class BusinessError extends KoelError { final Map<String, dynamic> details; ... }

// KoelErrorCode — typed vocabulary. Non-exhaustive in consumer code by convention;
// koel_lints does NOT mandate default on this enum because adapter-specific codes
// are expected to be added by extension.
enum KoelErrorCode {
  // transport
  transportTimeout, transportClosed, transportRefused, transportTlsFail,
  // protocol
  protocolUnknownEvent, protocolMalformed, protocolVersionDrift,
  // agent
  agentRefused, agentToolFailed, agentInternal,
  // business
  businessQuotaExceeded, businessRateLimited, businessAuth, businessForbidden,
  // catch-all
  unknown,
}

// ErrorClassifier — pluggable raw-exception-to-KoelError mapping.
abstract class ErrorClassifier {
  KoelError classify(Object raw, StackTrace? stack, RunAgentInput input);
}

class DefaultErrorClassifier implements ErrorClassifier {
  // Maps common HTTP / socket / TLS / JSON failures to KoelErrorCode.
  // Adapter packages can subclass to add backend-specific shapes.
}

// StateConflict — fired when STATE_DELTA references paths locally mutated since the last SNAPSHOT.
class StateConflict {
  final List<JsonPatchOp> incomingPatches;
  final Map<String, dynamic> localState;
  final Map<String, dynamic> snapshotState;
}

abstract class StateConflictResolver {
  Map<String, dynamic> resolve(StateConflict conflict);
}

class LastWriterWinsResolver implements StateConflictResolver { ... } // default

// SessionStorage.
abstract class SessionStorage {
  Future<void> save(String threadId, ChatState state);
  Future<ChatState?> load(String threadId);
  Future<void> delete(String threadId);
  Future<List<String>> listThreads();
}

class InMemorySessionStorage implements SessionStorage { ... }

// AgentSubscriber.
abstract class AgentSubscriber {
  void onRunStart(RunStartedEvent e) {}
  void onRunFinish(RunFinishedEvent e) {}
  void onRunError(RunErrorEvent e) {}
  void onStepStart(StepStartedEvent e) {}
  void onStepFinish(StepFinishedEvent e) {}
  void onTextChunk(TextMessageContentEvent e) {}
  void onToolCall(ToolCallStartEvent start, ToolCallEndEvent? end) {}
  void onToolResult(ToolCallResultEvent e) {}
  void onStateDelta(StateDeltaEvent e) {}
  void onReasoning(AgUiEvent e) {}
  void onUnknownEvent(UnknownAgUiEvent e) {}
}

// Backpressure.
enum BackpressurePolicy { dropOldest, dropNewest, pauseUpstream }
```

### A.1.bis `koel_lints`

Pure analyzer-plugin package — no runtime Dart API. Surfaces:

- `lib/koel.yaml` — canonical analyzer profile. Includes:
  - `exhaustive_switch_must_have_default: error` — fires on any `switch` over `AgUiEvent`, `KoelError`, or `MessageSegment` that lacks a `default:` branch.
  - `prefer_named_constructors_on_sealed_subtypes: warn` — optional code-clarity rule.
  - Inherits from `package:lints/recommended.yaml` so consumers get the lint baseline for free.

Consumer integration is a single line in `analysis_options.yaml`:
```yaml
include: package:koel_lints/koel.yaml
```
> _Erratum (SCP-2026-05-29): built on `analysis_server_plugin`, not `custom_lint`. The single-line `include:` is the custom_lint mechanism; under asp the rule is enabled via `plugins:` + `diagnostics:` at the analysis root. External-consumer distribution wording is reconciled in Story 9-7 after Epic-9 verification (Story 9-5)._

The lint rules themselves are implemented as a custom analyzer plugin in `lib/src/rules/`. CI for `koel_lints` includes a fixture-driven test that asserts the rules fire on intended violations and stay silent on intended-OK code.

### A.2 `koel_http`

```dart
class HttpAgent implements AbstractAgent {
  HttpAgent({
    required Uri url,
    http.Client? client,
    List<Interceptor>? interceptors,
    Duration connectTimeout = const Duration(seconds: 30),
    Duration readTimeout = const Duration(minutes: 5),
    RetryPolicy? retry,
    bool synthesizeChunks = true,
    void Function()? onConnect,
    void Function(Object)? onDisconnect,
    void Function(int attempt, Duration delay)? onReconnectAttempt,
  });

  @override
  Stream<AgUiEvent> run(RunAgentInput input);
}

class SseParser {
  Stream<AgUiEvent> parse(Stream<List<int>> bytes);
}

// Built-in interceptors.
class LoggingInterceptor implements Interceptor { LoggingInterceptor({Level level = Level.info}); }
class EventTraceInterceptor implements Interceptor { EventTraceInterceptor({required Sink<TraceEntry> sink}); }
class RetryInterceptor implements Interceptor {
  RetryInterceptor({
    int maxAttempts = 5,
    Duration baseDelay = const Duration(seconds: 1),
    Duration maxDelay = const Duration(seconds: 30),
    double jitter = 0.2,
    bool Function(Object error, int attempt)? shouldRetry,
  });
}
class AuthInterceptor implements Interceptor {
  AuthInterceptor({required Future<Map<String, String>> Function() headers});
}
class SentryBreadcrumbInterceptor implements Interceptor { ... } // default-OFF
class PIIRedactionInterceptor implements Interceptor {
  PIIRedactionInterceptor({required List<Pattern> patterns}); // default-OFF
}
```

### A.3 `koel_agno`

```dart
class AgnoAgent extends HttpAgent {
  AgnoAgent({
    required Uri baseURL, // POST baseURL/agno-chat
    String? token,
    http.Client? client,
    List<Interceptor>? interceptors, // prepended to default chain
    AgnoConversionOptions? conversion,
  });
}

class AgnoAuthInterceptor extends AuthInterceptor {
  AgnoAuthInterceptor({required String? token});
}
```

### A.4 `koel_langgraph`

```dart
class LangGraphAgent extends HttpAgent {
  LangGraphAgent({
    required Uri deploymentUrl,
    String? apiKey,
    http.Client? client,
    List<Interceptor>? interceptors,
  });

  // Surface-level interrupt resume (echoes MetaEvent back).
  Future<void> resume(String threadId, Map<String, dynamic> resumeValue);
}
```

### A.5 `koel_runtime`

> **Revised by SCP-2026-06-05 (D5 reversed).** CopilotKit dropped the GraphQL
> multipart transport (EOL ≤1.8.14); v2 (≥1.52) is native AG-UI over SSE
> (`POST {endpoint}/agent/{agentName}/run` → `text/event-stream`). So
> `CopilotRuntimeAgent` now **`extends HttpAgent`** (joins agno/langgraph) at full
> event-matrix fidelity — no GraphQL endpoint, no hand-rolled parser, no 7/28
> lossy surface.

```dart
class CopilotRuntimeAgent extends HttpAgent {
  CopilotRuntimeAgent({
    required Uri endpoint,        // CopilotKit runtime base, e.g. https://app/api/copilotkit
    required String agentName,    // the registered runtime agent to dispatch to
    String? authToken,
    http.Client? client,
  });

  @override
  Stream<AgUiEvent> run(RunAgentInput input);
}
```

### A.6 `koel_flutter`

```dart
class KoelChatController extends ChangeNotifier {
  KoelChatController({required ChatSession session});

  ChatState get state;
  bool get isStreaming;

  Future<void> send(String content);
  void cancel();
  Future<void> clear();
}

class KoelClientScope extends InheritedWidget {
  const KoelClientScope({required this.client, required super.child, super.key});
  final KoelClient client;
  static KoelClient of(BuildContext context);
}

class HiveSessionStorage implements SessionStorage {
  HiveSessionStorage({required String boxName});
}

class SecureSessionStorage implements SessionStorage {
  SecureSessionStorage({FlutterSecureStorage? storage});
}

class MessageContentParser {
  List<MessageSegment> parse(String content);
}

sealed class MessageSegment { const MessageSegment(); }
class TextSegment extends MessageSegment { final String text; ... }
class CodeBlockSegment extends MessageSegment {
  final String language;
  final String code;
}

class WidgetResolver {
  WidgetResolver(this._registry, {this.onUnknown});

  final Map<String, Widget Function(BuildContext, ToolCallEvent)> _registry;
  final Widget Function(BuildContext, ToolCallEvent)? onUnknown;

  Widget resolve(BuildContext context, ToolCallEvent toolCall);
}
```

### A.7 `koel_widgets`

```dart
class MessageBubble extends StatelessWidget { ... }
class ChatInput extends StatefulWidget { ... }
class FollowUpList extends StatelessWidget { ... }

class KoelTheme extends ThemeExtension<KoelTheme> {
  const KoelTheme({...});
  // Color slots, text styles, spacing tokens.
}
```

### A.8 `koel_devtools`

```dart
class DevToolsObserver implements AgentSubscriber {
  DevToolsObserver({int bufferSize = 1000});
  // Attach to KoelClient via client.subscribers.add(observer).
}
```

### A.9 `koel_test`

```dart
class MockAgent implements AbstractAgent {
  factory MockAgent.fromFixture(String name);
  factory MockAgent.fromEvents(List<AgUiEvent> events);
  MockAgent.programmatic(); // builder-pattern test agent
}

class FixtureLoader {
  static Future<List<AgUiEvent>> loadDojo(String eventType);
  static Future<List<AgUiEvent>> loadAgno(String scenario);
  static Future<List<AgUiEvent>> loadLangGraph(String scenario);
}

class ToolHandlerTestHarness {
  ToolHandlerTestHarness register(String name, ToolHandler handler);
  Future<ToolCallResultEvent> invoke(String name, Map<String, dynamic> args);
}

class ConformanceRunner {
  Future<ConformanceReport> runAgainst(AbstractAgent agent);
}
```

## B. Tech Choices & Rationales

### B.1 Dart 3 `sealed class` + mandatory-default lint over enums + visitors

**Choice.** Use Dart 3 `sealed class` for `AgUiEvent`, `KoelError`, `MessageSegment`. Pair with the `koel_lints` rule `exhaustive_switch_must_have_default` so that adding sealed subtypes — a normal AG-UI evolution — stays a semver-minor bump on koel's foundations.

**Rationale.** Pure sealed gives compile-time exhaustiveness but turns every protocol evolution into a major version bump — unacceptable for an SDK that must track upstream AG-UI cleanly. Pure unsealed gives minor-bump headroom but loses the exhaustiveness that makes the API self-documenting. The lint-mediated middle gives both: consumers who include `package:koel_lints/koel.yaml` get exhaustive-feel pattern matching with a forced `default:` branch that absorbs future events. Consumers who opt out accept that exhaustive switches may break on minor upgrades — documented prominently.

**Cost.** Drops Dart 2.x consumers — acceptable; Dart 3 has been the toolchain default for two years and no live AG-UI consumer is on Dart 2. Adds one foundation package (`koel_lints`) to maintain, weighed against major-bumping every time AG-UI adds an event.

### B.2 `freezed` for data classes

**Choice.** `freezed` for all immutable data classes — `ChatState`, `RunAgentInput`, `Message`, JSON-Patch ops. **Rationale.** Hand-written `==`, `hashCode`, `copyWith`, and JSON serialization across ~40 types is a maintenance graveyard. `freezed` is the ecosystem norm and integrates cleanly with `json_serializable`. **Cost.** Build-runner at the consumer is fine — koel itself runs it; consumers see only the generated immutable types on pub.

### B.3 Vendor-inline RFC 6902 implementation for state delta

**Choice.** Implement RFC 6902 strict-mode application inside `koel_core/lib/src/json_patch/` (~300 LOC). Do not depend on `package:json_patch`.

**Rationale.** The existing `package:json_patch` 3.0.0 was last published 4 years ago — incompatible with v1's zero-churn 1.x commitment (SC-4). RFC 6902 is a small, well-specified algorithm; implementing it inline is reviewable in one sitting and free of upstream-maintenance risk. Same logic as D.7's rejection of `package:sse`: when an external dependency is a small algorithm with churn risk, an internal implementation is the correct call. Aligns with the "read framework source" principle and keeps `koel_core`'s transitive dependency surface lean (counter-metric CM-3).

**Cost.** koel maintains the JSON Patch test suite (RFC 6902 fixtures) directly. The trade — one small algorithm to own indefinitely — is preferable to depending on a 4-year-stale upstream that could vanish without notice mid-1.x.

**Decided in `architecture.md` (Bonus decision after D8).**

### B.4 `package:http` over Dio

**Choice.** `package:http` (the official Dart client) inside `koel_http`, with `http.Client` injectable. **Rationale.** Official, no third-party churn risk, web-compatible. Dio adds dependency weight (CM-3) without justifying capability for koel's narrow use case. Consumers who *want* Dio wrap a Dio-backed `http.Client` via `http`'s `BaseClient` interface. **Cost.** Slightly less ergonomic SSE handling — koel ships its own `SseParser` over the raw byte stream.

### B.5 Melos monorepo

**Choice.** Melos manages the 10-package repo. **Rationale.** Dart-native and ecosystem-standard for Dart monorepos. Handles versioning, publishing, dependency hoisting, IDE integration. **Alternatives rejected.** Yarn workspaces (wrong ecosystem), pnpm (same), custom shell scripts (reinventing).

### B.6 `dart:io` HTTP for SSE, `package:web` for browser fallback

**Choice.** `koel_http` ships a layered transport: `dart:io` socket on native, browser `EventSource` (via `package:web`) on web. **Rationale.** SSE on Flutter web cannot rely on `dart:io`; the browser's `EventSource` is the native fallback. **Cost.** Two parser paths feeding the same `SseParser`. CI exercises both.

## C. Mechanism Decisions

### C.1 Event pipeline as pure-function stages (F-A11)

Inspired by CopilotKit's `@ag-ui/client` pipeline; stage order adjusted so cross-event verification runs after chunk synthesis. Wire-format sanity — the raw JSON shape of each event before it becomes an `AgUiEvent` — is enforced inside the SSE parser in `koel_http`, not here.

Stages, in order, each operating on `Stream<AgUiEvent>`:

1. **chunks** — synthesizes `TOOL_CALL_CHUNK` / `TEXT_MESSAGE_CHUNK` into `START` + `CONTENT/ARGS` + `END` triplets (opt-in, default ON via `HttpAgent.synthesizeChunks`). Runs **before** verify because verify checks the START/END pairing that chunks creates.
2. **verify** — structural and cross-event sanity: every `TOOL_CALL_END` has a matching `TOOL_CALL_START` with the same id; every `STATE_DELTA` carries valid RFC 6902 ops; every `REASONING_ENCRYPTED_VALUE` has both `Uint8List` and base64 string. Failures drop the offending event and emit `RunErrorEvent(ProtocolError)`.
3. **apply** — if a reducer is registered, folds the event into `ChatState` and resolves any `StateConflict` via the registered resolver.
4. **transform** — consumer-supplied stream transformers (custom telemetry, scrubbing).

Each stage is a `StreamTransformer<AgUiEvent, AgUiEvent>`. Composition is `events.transform(chunks).transform(verify).transform(apply).transform(transform)`. Order is locked. Stage internals are pure (no I/O); errors surface in-stream as `RunErrorEvent` carrying a `KoelError`.

**Interceptors vs. pipeline vs. subscribers.** Interceptors wrap the entire pipeline — they execute around the request and around the resulting `Stream<AgUiEvent>` setup, so each interceptor can substitute, transform, retry, or short-circuit the whole run. Subscribers fire **post-pipeline** on each event the consumer would have seen (post-transform). Under retry, interceptors re-execute and subscribers see each attempt — duplicates by design, so analytics can count attempts.

### C.2 Cancellation semantics (F-B3)

AG-UI provides no `RUN_CANCELLED` event and no client→server mid-run channel. Cancellation is TCP-close-only.

Mechanism:
- Consumer calls `cancel()` on the `Stream<AgUiEvent>` subscription.
- `koel_http` propagates to the underlying `http.Client` abort: `Client.close()` on the per-request client wrapper, or `HttpClientRequest.abort()` on `dart:io`.
- If the client implementation does not honor abort, the close is dropped silently. A single debug-level warning emits via `package:logging` on first observation, gated by a runtime-once flag.
- The session reducer produces `RunPhase.cancelled` immediately on the cancel call, regardless of TCP outcome.

The verified-client matrix lives in `koel_http/test/cancellation_test.dart`: default `http.Client()`, `IOClient`, browser `BrowserClient`, and custom interceptor-wrapped clients.

### C.3 Time-travel replay semantics (F-F7)

Replay re-applies the recorded event stream through the same reducer pipeline. Replay does **not** re-execute tool handlers. Implementation:

- `koel_devtools` snapshots every event into a bounded ring buffer sized by `devtoolsBufferSize`.
- "Replay from event N" rebuilds `ChatState` by folding the reducer over `events[0..N]`.
- A `ToolReplayContext` is published via `InheritedWidget` during replay; tool handlers that consult it opt out of side effects (`if (ToolReplayContext.of(context).isReplaying) return;`).
- Replay-unaware tool handlers execute normally during live mode; in replay mode their calls become no-op stubs that return the recorded result.

OQ-Replay-Side-Effects covers whether stronger isolation (e.g., an isolate-based replay sandbox) is needed; v1 ships the `ToolReplayContext` flag approach.

### C.4 JSON Lines trace export (F-F6)

```jsonl
{"_session": {"threadId": "abc", "runId": "xyz", "koelVersion": "1.0.0", "adapter": "koel_agno@1.0.0", "captured": "2026-05-27T10:00:00Z"}}
{"type": "RUN_STARTED", "timestamp": "...", "payload": {...}}
{"type": "TEXT_MESSAGE_START", "timestamp": "...", "payload": {...}}
...
{"type": "RUN_FINISHED", "timestamp": "...", "payload": {...}}
```

The first line is a metadata header (object with a `_session` key). Each subsequent line carries one event with a `timestamp` (ISO 8601) and `payload` (the wire-format event JSON). Re-importable in DevTools via "Load Trace".

### C.5 Backpressure (N-6)

`Stream<AgUiEvent>` is fed by an internal bounded buffer wrapping the raw HTTP byte stream. Policy:

- `pauseUpstream` (default) — `pause()` the underlying byte-stream subscription when the buffer fills. The TCP window closes; the backend pauses sending. Safe, but stalls UI updates.
- `dropOldest` — pop from the front when full. Loss-tolerant.
- `dropNewest` — reject incoming when full. Loss-tolerant.

Loss is logged at warning level with a counter. Consumers select policy via `KoelClient.backpressure`.

## D. Options Considered (Rejected Alternatives)

### D.1 Package layout — rejected: AG-UI / CopilotKit split-mirror

**Considered.** Mirror the AG-UI repo's split (`koel_protocol` + `koel_client` + `koel_encoder`) instead of the current `koel_core` + `koel_http`.
**Rejected.** AG-UI's split is JS-typical (protocol types vs client logic vs codec). The Dart-idiomatic split groups by *concern*: foundation types and reducers in `koel_core`, transport-specific code in `koel_http`. Mirroring AG-UI's structure would couple koel's evolution to AG-UI's repo organization and impose a one-time confusion tax on Flutter devs comparing against existing Dart SDKs (`dio`, `langchain_dart`).

### D.2 Generative UI — rejected: dedicated `koel_a2ui` package in v1

**Considered.** Ship `koel_a2ui` at v1, implementing the A2UI generative-UI spec as a first-class event family.
**Rejected.** AG-UI itself treats generative UI as a `TOOL_CALL_*` convention, not a first-class event family. `WidgetResolver` over tool-calls (F-E2) is sufficient for v1 and aligns with how AG-UI's reference TS implementation handles it. A2UI as a dedicated package becomes a v2 candidate if AG-UI promotes it to first-class.

### D.3 Adapter packages — rejected: state-management direct adapters

**Considered.** Ship `koel_bloc`, `koel_riverpod`, `koel_getx` at v1.
**Rejected.** Three packages of maintenance overhead that swing with every state-mgmt ecosystem fashion. `KoelChatController extends ChangeNotifier` (F-D4) is the lowest common denominator every state-mgmt framework integrates with in one line (`ChangeNotifierProvider`, `BlocProvider.value`, `Get.put`). The community can ship adapters; koel won't enshrine any.

### D.4 Transport — rejected: protobuf in v1

**Considered.** Ship `koel_proto` as a third transport.
**Rejected.** AG-UI's `@ag-ui/proto` is underdocumented: framing and `Content-Type` conventions are unclear, and no reference JS or Python implementation exercises it in production. v1 commits to two production transports — SSE and the GraphQL bridge. Protobuf is OQ-Protobuf-Codegen for v1.5/v2.

### D.5 Error model — rejected: Result-type / exception split

**Considered.** Return `Result<Stream<AgUiEvent>, KoelError>` from `AbstractAgent.run`, separating recoverable from exceptional errors.
**Rejected.** Dart's standard library has no Result type; introducing one creates ecosystem friction. AG-UI itself carries errors *inside* the event stream as `RUN_ERROR` (F-A5). Mirroring that — errors as events, exceptions reserved for programmer mistakes — is the natural fit.

### D.6 Reducer — rejected: mandatory reducer

**Considered.** Force consumers to subscribe via `ChatSession` only, hiding the raw `Stream<AgUiEvent>`.
**Rejected.** DevTools, telemetry, and custom adapters need the raw stream. The three-layer API (F-A2) preserves the power-user escape hatch at the minor cost of one extra method on `KoelClient`.

### D.7 SSE library — rejected: `package:sse` and `package:eventsource`

**Considered.** Use an existing SSE Dart package for parsing.
**Rejected.** `package:sse` targets Dart's `dwds` debug protocol, not generic SSE consumption. `package:eventsource` is unmaintained (last update over two years ago). `koel_http` ships its own minimal `SseParser` (~150 LOC), reviewable in one sitting and free of churn risk. Aligns with the "read framework source" principle.

## E. Reference Comparables

Each comparable is read for the lessons it teaches; none are copied wholesale.

| Comparable | What koel takes | What koel does not take |
|---|---|---|
| **`dio`** | Interceptor chain shape (`Interceptor.intercept(chain)` composition) | Singleton `Dio()` instance pattern; option-bag explosion; over-flexible response transformations |
| **`graphql_flutter`** | `InheritedWidget` for client injection; `ChangeNotifier`-backed query controllers | GraphQL-specific cache; reactive `Query` widget hierarchy |
| **`langchain_dart`** | Sealed message types; pure-function chain ergonomics; honest "this is alpha" README posture | Heavy abstract base classes; "everything is a chain" framing |
| **`firebase_*` family** | Per-product package split (`firebase_auth`, `firebase_storage`, …); plugin-platform-interface pattern for future native bridges | Massive transitive dep weight; opinionated initialization choreography |
| **`supabase_flutter`** | Clean `ChangeNotifier`-based session controller; auth state stream | URL-string-driven configuration; Postgres-specific coupling |
| **`anthropic_sdk_dart`** | Compact API surface; freezed-everywhere data classes | Single-package (no modular separation); no devtools |
| **community `ag_ui` 0.1.0** | Genre exists; pub.dev slot demonstrated | Single-package layout; missing reasoning/activity events; no Flutter widgets; no fixtures; no devtools — all things v1 koel must ship |
| **CopilotKit `@ag-ui/client`** | 4-stage pipeline (verify/chunks/apply/transform); AgentSubscriber callback bag; chunk synthesis; middleware composition pattern | GraphQL-mediated client; RxJS-heavy internals; per-framework packages (`react-core`, `vue`, `angular`); React-hook ergonomics |
| **CopilotKit `@copilotkit/web-inspector`** | DevTools panel taxonomy (Stream/History/Inspector/Network/Export) | Browser-embedded UI; CopilotKit-runtime-specific assumptions |

## F. Pipeline Stage Reference (concrete details)

### F.1 `verify` rules (runs **after** chunks synthesis)

Drop the offending event and emit `RunErrorEvent(ProtocolError)` if:

- `TOOL_CALL_END` arrives without a matching `TOOL_CALL_START` (same `toolCallId`).
- `TOOL_CALL_ARGS` arrives outside a START/END envelope.
- `STATE_DELTA.patches` is empty or contains invalid RFC 6902 ops.
- `TEXT_MESSAGE_*` events arrive without a `messageId`.
- `REASONING_ENCRYPTED_VALUE` is missing the base64 string sibling or the bytes round-trip does not match.

### F.2 `chunks` synthesis rules (runs **before** verify)

Wire names below match the AG-UI spec: `toolCallId`, `toolCallName`, `parentMessageId`, `delta`.

If `synthesizeChunks: true` (default):
- The first `TOOL_CALL_CHUNK` for a given `toolCallId` synthesizes a `ToolCallStartEvent(toolCallId: X, toolCallName: Y, parentMessageId: Z)`.
- Each subsequent `TOOL_CALL_CHUNK` synthesizes an incremental `ToolCallArgsEvent(toolCallId: X, delta: <delta>)`.
- A spec-supplied "complete" marker (the next non-chunk event or an explicit end signal) synthesizes a `ToolCallEndEvent(toolCallId: X)`.
- Mirror rules apply to `TEXT_MESSAGE_CHUNK` → START/CONTENT/END using `messageId` and `delta`.

### F.3 `apply` semantics

`reduce(state, event)` runs for every event after `chunks` and `verify`. The reducer is pure and returns a new `ChatState`. Do not mutate `state.messages`; rebuild lists each call. This keeps `ChatState` const-comparable and Riverpod-friendly.

### F.4 `transform` extensibility

Consumers register `StreamTransformer<AgUiEvent, AgUiEvent>` instances via `KoelClient.transforms`. Applied in registration order *after* `apply`, so transforms see the post-reduce stream. Used for PII redaction, language translation, custom telemetry, A/B test event tagging.

## G. Implementation Notes for `koel_devtools`

- The DevTools extension entry point follows the [official Flutter DevTools extension API](https://api.flutter.dev/flutter/dart-ui/devtools_extensions-library.html) (`devtools_extensions` package).
- `DevToolsObserver` is an `AgentSubscriber` registered against the user's `KoelClient`. It buffers events into the ring buffer and exposes them to the DevTools UI via the standard ExtensionAPI.
- Time-travel state is computed by re-folding the reducer over events `[0..N]`, cached per `N` to avoid recomputation on scrub.
- Trace export streams the ring buffer to a temp file and surfaces a "Download" action through the DevTools `File` API.

## H. Out-of-PRD: Future Work (Tracked, Not v1)

Explicit non-goals for v1, captured here so they don't get rediscovered later.

- **Future-1.** `koel_a2ui` — first-class A2UI generative UI package once AG-UI promotes A2UI to a first-class event family.
- **Future-2.** `koel_proto` — protobuf binary transport once AG-UI documents framing.
- **Future-3.** `koel_bloc` / `koel_riverpod` / `koel_getx` — direct state-management adapters, community-contributed under OQ-State-Mgmt-Governance.
- **Future-4.** Deep LangGraph interrupt-resume (stateful sub-tree resumption) once OQ-LangGraph-Graduation resolves.
- **Future-5.** Isolate-backed long-running tool handler execution.
- **Future-6.** Tool-call confirmation middleware (user-approval-gated tool execution).
- **Future-7.** Conformance test contribution back to the AG-UI repo as the cross-language conformance suite (currently AG-UI has only the Dojo; no formal conformance test runner exists in any language).

---

*This addendum captures depth the PRD body intentionally elides — the tone, voice, and qualitative ideas that the FR structure can silently drop. The decision log (`.decision-log.md`) is canonical for what was decided and why; this addendum is canonical for what was technical and how.*
