# Epic 4: HTTP Transport — `koel_http`

Developer can connect a `KoelClient` to any AG-UI-compliant SSE endpoint over both native (`dart:io`) and web (`package:web` fetch + ReadableStream + AbortController) transport. Six built-in interceptors compose into the chain — Logging/EventTrace/Retry/Auth ship default-ON, Sentry/PII default-OFF. Cancellation propagates < 50 ms. Reconnect with exponential backoff + jitter (max 5 attempts). Chunk synthesis ON by default. Coverage ≥ 90%. SSE parse-throughput baseline captured.

## Story 4.1: Framework-free `SseParser`

As a Flutter/Dart developer,
I want a hand-rolled `SseParser` (~150 LOC) that converts a `Stream<List<int>>` byte stream into typed `Stream<AgUiEvent>` per RFC 8895 SSE format compliance,
So that the transport layer rests on a reviewable, dependency-free SSE parser per AR-8.

**Acceptance Criteria:**

**Given** `koel_http/lib/src/sse_parser.dart`,
**When** I inspect it,
**Then** `class SseParser` exposes `Stream<AgUiEvent> parse(Stream<List<int>> bytes)`,
**And** the implementation handles SSE wire format per RFC 8895 (event boundaries on `\n\n`, `data:` field accumulation, `event:` type override, `id:` retention, `retry:` value),
**And** no third-party SSE parsing dependency (`package:sse`, `package:eventsource`) is imported.

**Given** a synthesized RFC 8895 fixture covering edge cases (CRLF line endings, multi-line data fields, BOM prefix, comment lines, partial chunks split mid-field),
**When** the parser processes it,
**Then** every fixture passes,
**And** malformed wire JSON inside a `data:` field surfaces as `ProtocolError(code: protocolMalformed)` via the inline error classifier — pipeline wire-sanity boundary per FR-A11.

**Given** unknown event types in the wire stream,
**When** the parser dispatches via the registry from Story 2.2,
**Then** they deserialize into `UnknownAgUiEvent` (no exception).

**Given** the parser's package size,
**When** I run `wc -l koel_http/lib/src/sse_parser.dart`,
**Then** the file is < 250 LOC (target ~150 per AR-8).

## Story 4.2: `HttpAgent implements AbstractAgent` with native transport

As a Flutter/Dart developer,
I want `HttpAgent` connecting to any AG-UI SSE endpoint via injectable `http.Client` (native `dart:io` path first; web transport in Story 4.10),
So that consumer code reads `HttpAgent(url: …)` and immediately gets a streaming `AbstractAgent` per FR-B1 + AR-7.

**Acceptance Criteria:**

**Given** `koel_http/lib/src/http_agent.dart`,
**When** I inspect the constructor,
**Then** it matches Addendum A.2: `HttpAgent({required Uri url, http.Client? client, List<Interceptor>? interceptors, Duration connectTimeout = const Duration(seconds: 30), Duration readTimeout = const Duration(minutes: 5), RetryPolicy? retry, bool synthesizeChunks = true, void Function()? onConnect, void Function(Object)? onDisconnect, void Function(int attempt, Duration delay)? onReconnectAttempt})`,
**And** `run(RunAgentInput input)` posts the input as JSON, streams the response through `SseParser`, applies chunk synthesis if enabled, and yields the typed `Stream<AgUiEvent>`.

**Given** `koel_http/lib/src/transport/native_transport.dart`,
**When** I inspect it,
**Then** it uses `dart:io` `HttpClient` for byte streaming on non-web platforms,
**And** the platform decision is governed by conditional imports (`io_transport.dart` + `web_transport.dart` with stub).

**Given** an `HttpAgent` pointed at a local synthesized SSE server,
**When** a run executes,
**Then** every event emits as a typed `AgUiEvent` matching the wire fixtures from Epic 3.

**Given** a connection failure (refused / TLS / timeout),
**When** the agent runs,
**Then** the failure surfaces as `RunErrorEvent(TransportError)` with the correct `KoelErrorCode` from Story 2.8,
**And** no uncaught exception escapes the stream.

## Story 4.3: Cancellation propagation with TCP abort

As a Flutter/Dart developer,
I want `StreamSubscription.cancel()` on the event stream to propagate to an HTTP-level abort (TCP close) within < 50 ms, with a silent-drop fallback + single debug warning for clients not honoring abort,
So that consumer-initiated cancellation satisfies AG-UI's TCP-close-only cancellation semantics per FR-B3 + NFR-8 + Addendum C.2.

**Acceptance Criteria:**

**Given** an `HttpAgent` connected to a long-running SSE stream (one event per 100 ms),
**When** the consumer cancels the subscription mid-stream,
**Then** the underlying `HttpClientRequest.abort()` (`dart:io`) or `Client.close()` invokes within 50 ms,
**And** no further events emit after cancellation,
**And** the time between `cancel()` call and TCP-close observation < 50 ms per NFR-8 (measured by test).

**Given** the verified-client matrix `koel_http/test/cancellation_test.dart`,
**When** I run it,
**Then** it asserts cancel propagation against: default `http.Client()`, `IOClient`, browser `BrowserClient`, and a custom interceptor-wrapped client.

**Given** a `MockHttpClient` that intentionally does not honor `close()`,
**When** the consumer cancels,
**Then** `koel_http` falls back to silent drop with one `Level.WARNING` log via `package:logging` per the runtime-once flag (verified the warning emits exactly once per process across multiple cancellation events with that client) per Addendum C.2.

**Given** the cancellation,
**When** the reducer processes the subsequent state,
**Then** `ChatState.phase == RunPhase.cancelled` regardless of TCP outcome per FR-A11 + Addendum C.2.

## Story 4.4: `RetryInterceptor` exponential backoff + jitter + `ConnectionResumed` MetaEvent

As a Flutter/Dart developer,
I want `RetryInterceptor` with exponential backoff (default 1s → 30s, ±20% jitter, max 5 attempts) and emission of `ConnectionResumed` `MetaEvent` on reconnect,
So that transient failures recover automatically per FR-B4 + NFR-7.

**Acceptance Criteria:**

**Given** `koel_http/lib/src/interceptors/retry_interceptor.dart`,
**When** I inspect the constructor,
**Then** it matches Addendum A.2: `RetryInterceptor({int maxAttempts = 5, Duration baseDelay = const Duration(seconds: 1), Duration maxDelay = const Duration(seconds: 30), double jitter = 0.2, bool Function(Object error, int attempt)? shouldRetry})`.

**Given** an unstable endpoint that fails 3 times then succeeds,
**When** the agent runs with `RetryInterceptor` in the chain,
**Then** 3 retries occur with delays computed by exponential backoff + ±20% jitter,
**And** the eventual run succeeds,
**And** `onReconnectAttempt` is invoked 3 times with the correct attempt number and computed delay.

**Given** a successful reconnect mid-stream,
**When** the next event arrives,
**Then** the event stream emits a `ConnectionResumed` event (modeled as a `CustomEvent` with `name: "koel.connection_resumed"` so it rides the existing sealed `AgUiEvent` union without expanding the protocol surface) immediately before the next domain event per FR-B4,
**And** the consumer can render UI state reflecting reconnection.

**Given** 6 consecutive failures (above the default 5-attempt cap),
**When** the agent runs,
**Then** the stream emits `RunErrorEvent(TransportError(code: KoelErrorCode.transportClosed))` with the underlying cause attached.

**Given** a `shouldRetry` callback returning `false` for `KoelErrorCode.businessAuth`,
**When** an auth failure occurs,
**Then** no retry attempts execute (the failure surfaces immediately).

## Story 4.5: `AuthInterceptor` (Bearer + custom headers via async callback)

As a Flutter/Dart developer,
I want `AuthInterceptor` accepting an async header-builder callback (e.g., for token refresh),
So that auth schemes — Bearer, custom headers, token refresh — compose cleanly into the chain per FR-B2.

**Acceptance Criteria:**

**Given** `koel_http/lib/src/interceptors/auth_interceptor.dart`,
**When** I inspect the constructor,
**Then** it matches Addendum A.2: `AuthInterceptor({required Future<Map<String, String>> Function() headers})`,
**And** the callback is invoked once per run (or once per retry attempt within a single run, configurable).

**Given** an `AuthInterceptor` with a callback returning `{'Authorization': 'Bearer abc123'}`,
**When** a run executes,
**Then** the outgoing HTTP request carries that header verbatim.

**Given** an async callback that throws,
**When** the run starts,
**Then** the chain emits `RunErrorEvent(BusinessError(code: KoelErrorCode.businessAuth))` with the underlying cause.

**Given** a token-refresh scenario where the first attempt 401s and the callback returns a fresh token,
**When** combined with `RetryInterceptor` configured to retry on 401,
**Then** the second attempt carries the refreshed token and the run succeeds.

## Story 4.6: `LoggingInterceptor` + `EventTraceInterceptor`

As a Flutter/Dart developer,
I want `LoggingInterceptor` for human-readable run logging at configurable levels plus `EventTraceInterceptor` for structured `TraceEntry` capture into a `Sink`,
So that observability ships in the base SDK per FR-B2.

**Acceptance Criteria:**

**Given** `koel_http/lib/src/interceptors/logging_interceptor.dart`,
**When** I inspect it,
**Then** the constructor accepts `LoggingInterceptor({Level level = Level.info})` per Addendum A.2,
**And** every run lifecycle event (request start, response start, per-event tail, completion, error) logs at the configured level via `package:logging`,
**And** no `print` calls appear anywhere in the package per architecture convention §4.

**Given** `koel_http/lib/src/interceptors/event_trace_interceptor.dart`,
**When** I inspect it,
**Then** the constructor matches `EventTraceInterceptor({required Sink<TraceEntry> sink})`,
**And** `TraceEntry` is a freezed type with `timestamp`, `event`, `phase` (request/event/response/error), and `runDuration`,
**And** every `AgUiEvent` flowing through the chain produces a `TraceEntry` written to the sink.

**Given** a `LoggingInterceptor` at `Level.fine`,
**When** I run an SSE session and inspect the logs,
**Then** per-event tracing appears at `Level.fine` per architecture §4 log-level table,
**And** cancellation drops log at `Level.fine` exactly once per process per FR-B3.

## Story 4.7: `SentryBreadcrumbInterceptor` + `PIIRedactionInterceptor` (both default-OFF)

As a Flutter/Dart developer,
I want default-OFF observability and privacy interceptors that consumers opt into explicitly,
So that no silent telemetry ships and PII redaction is configurable per FR-B2 + FR-I2.

**Acceptance Criteria:**

**Given** `koel_http/lib/src/interceptors/sentry_breadcrumb_interceptor.dart`,
**When** I inspect it,
**Then** the class implements `Interceptor` and emits per-event Sentry breadcrumbs via `sentry: ^9.x` (or equivalent stable) when explicitly registered,
**And** no Sentry traffic emits unless the consumer adds the interceptor to `KoelClient.interceptors`.

**Given** `koel_http/lib/src/interceptors/pii_redaction_interceptor.dart`,
**When** I inspect the constructor,
**Then** it matches Addendum A.2: `PIIRedactionInterceptor({required List<Pattern> patterns})`,
**And** the interceptor scrubs matching content in `TextMessageContentEvent.delta` and other text-bearing payloads before they reach subscribers / reducer.

**Given** neither interceptor is registered (default `KoelClient` setup),
**When** a run executes,
**Then** no Sentry call is made and no PII redaction applies (verified by inspecting raw event stream content) per FR-I2.

**Given** a `PIIRedactionInterceptor` configured with `[RegExp(r'\b\d{4}-\d{4}-\d{4}-\d{4}\b')]` and a synthesized fixture carrying a fake credit-card-number string in message content,
**When** the run executes through the interceptor,
**Then** the consumer-visible event stream's text content is redacted with `[REDACTED]`.

## Story 4.8: Chunk synthesis (START/CONTENT/END from CHUNK)

As a Flutter/Dart developer,
I want chunk synthesis ON by default in `HttpAgent.synthesizeChunks` so `TOOL_CALL_CHUNK` and `TEXT_MESSAGE_CHUNK` are normalized to START/CONTENT/END triplets before the verify stage,
So that downstream pipeline + reducer only handle the long form per FR-B5 + Addendum F.2.

**Acceptance Criteria:**

**Given** `HttpAgent(synthesizeChunks: true)` (default),
**When** a wire stream of `TOOL_CALL_CHUNK` events arrives,
**Then** the first chunk for a given `toolCallId` synthesizes `ToolCallStartEvent` with `toolCallId`, `toolCallName`, `parentMessageId`,
**And** subsequent chunks synthesize `ToolCallArgsEvent(toolCallId, delta)`,
**And** the trailing "complete" marker synthesizes `ToolCallEndEvent(toolCallId)`,
**And** the same rules apply to `TEXT_MESSAGE_CHUNK` → START/CONTENT/END using `messageId` + `delta`.

**Given** `HttpAgent(synthesizeChunks: false)`,
**When** the same wire stream arrives,
**Then** raw `ToolCallChunkEvent` and `TextMessageChunkEvent` instances pass through unchanged.

**Given** the verify stage from Story 2.11 running downstream,
**When** synthesized triplets feed it,
**Then** verify rules pass for matched START/END pairs and fail when synthesis is wrong (regression-tested via property-based synthesis-correctness test).

## Story 4.9: Connection lifecycle hooks

As a Flutter/Dart developer,
I want `onConnect`, `onDisconnect`, `onReconnectAttempt` callbacks on `HttpAgent` for transport-level visibility,
So that DevTools (Epic 8) and custom observers attach to connection events per FR-B6.

**Acceptance Criteria:**

**Given** an `HttpAgent` constructed with all three callbacks,
**When** a run successfully connects, executes, and finishes,
**Then** `onConnect` fires exactly once on response-headers-received,
**And** `onDisconnect` fires exactly once on stream close (graceful or error) with the `Object?` cause if error,
**And** `onReconnectAttempt` does not fire (no retry occurred).

**Given** a transient failure triggering 2 retries before success,
**When** the run executes,
**Then** `onConnect` fires once per successful connection (3 total),
**And** `onReconnectAttempt(attempt, delay)` fires twice with the computed delays.

**Given** these hooks attached to the lifecycle subsystem at `koel_http/lib/src/connection/lifecycle.dart`,
**When** Epic 8 wires `DevToolsObserver`,
**Then** the observer subscribes to these hooks without needing access to private state.

## Story 4.10: Web transport (`package:web` fetch + ReadableStream + AbortController) + perf baseline

As a Flutter/Dart developer,
I want the Flutter web transport implemented via `package:web` fetch + ReadableStream + AbortController (NOT `EventSource`), sharing the `SseParser` from Story 4.1, with CI matrix exercising both native + web paths and the `sse_parse_bench` baseline captured,
So that the SDK works uniformly across all six platforms with full `AuthInterceptor` header support per AR-9 + NFR-11 + NFR-1.

**Acceptance Criteria:**

**Given** `koel_http/lib/src/transport/web_transport.dart`,
**When** I inspect it,
**Then** it uses `package:web` fetch + ReadableStream (NOT `EventSource`) per AR-9,
**And** custom request headers (including `Authorization`) flow through correctly to the request (verified by a browser integration test against a mock server),
**And** `AbortController` ties to `StreamSubscription.cancel()` for cancellation propagation per AR-23 (G-1) — < 50 ms abort same as native.

**Given** `koel_http/lib/src/transport/io_transport.dart` + `web_transport.dart` + `transport_stub.dart`,
**When** I inspect the conditional imports,
**Then** the platform decision uses `dart.library.io` vs `dart.library.html`/`dart.library.js_interop` to select the impl,
**And** the imported transport type satisfies a common interface so `HttpAgent` consumes either uniformly.

**Given** the CI matrix in `ci.yml` (extended here from Story 1.5),
**When** the workflow runs,
**Then** Linux + macOS native jobs execute the native transport tests,
**And** a separate Flutter-web job runs the web transport tests against a headless browser,
**And** both pass on every PR per NFR-11.

**Given** `koel_http/test/perf/sse_parse_bench.dart`,
**When** I run it,
**Then** baseline events-per-second throughput numbers are captured under the CI reference device profile and written to `baselines/sse_parse_bench.json`,
**And** subsequent runs fail when regression > 10% per NFR-1.

**Given** the `koel_http` package overall,
**When** I run `melos run test:coverage`,
**Then** line + branch coverage ≥ 90% per NFR-12,
**And** `dart analyze` exits 0 per NFR-13.

---
