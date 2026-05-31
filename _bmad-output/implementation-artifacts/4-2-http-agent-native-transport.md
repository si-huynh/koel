---
baseline_commit: de8393428f908db387228dea9cf654439f9e665b
---

# Story 4.2: `HttpAgent implements AbstractAgent` with native transport

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

> **Dev agent:** this is **Story 4.2 of Epic 4** (HTTP transport, `koel_http`). It builds directly on Story 4.1's `SseParser` and turns `koel_http` into a real transport: the first `AbstractAgent` that talks to a network. It touches `.dart` files and designs the package's central public type, so **invoke `/agent-flutter-engineer` before producing any code** (per [CLAUDE.md](CLAUDE.md)). `packages/koel_http/` already exists and already ships `SseParser` (Story 4.1) — you are *adding* `HttpAgent`, the wire codec, and the transport seam. **Seven things are load-bearing, and the first four are traps that will sink a naïve reading of the AC:**
>
> 1. **`RunAgentInput` has NO JSON codec — you must write it.** `run()` "posts the input as JSON" (AC :43), but `RunAgentInput` in koel_core deliberately ships *no* `toJson` ([run_agent_input.dart:22-24](packages/koel_core/lib/src/input/run_agent_input.dart#L22-L24): *"the wire codec needs a base64 `Uint8List` converter and lands with the transport that posts this payload (Epic 4, `koel_http`)"*). **This story is where that codec lands.** It is hand-written in `koel_http` (a free function / extension, not codegen). `Message` and `ToolDefinition` already have generated `toJson()` (json_serializable — [message.dart:4](packages/koel_core/lib/src/message/message.dart#L4), [tool_definition.dart](packages/koel_core/lib/src/tool/tool_definition.dart)); you compose those. The one field needing special handling is `reasoningEcho` (`Map<String, Uint8List>?`) → base64-encode each blob. [Source: AC :43; run_agent_input.dart:22-24]
> 2. **`RetryPolicy` and `package:http` do not exist yet — the verbatim constructor will not compile until you add them.** The Addendum A.2 / AC signature references `http.Client? client` and `RetryPolicy? retry`. **`package:http` is not a dependency of any package yet** (verified: zero `package:http/http` imports in the monorepo) and **no `RetryPolicy` type exists** (verified). You must: add `http: ^1.6.0` to `koel_http/pubspec.yaml`, and define a minimal `RetryPolicy` value type (its *behavior* — backoff/jitter/reconnect — is Story 4.4; here it is a data holder so the constructor compiles and 4.4 fills in the engine). [Source: AC :42; addendum A.2; grep verification]
> 3. **The native byte stream comes from `http.Client.send()`, NOT a raw `dart:io` socket you hand-roll.** D4 ([architecture.md:335](`_bmad-output/planning-artifacts/architecture.md`)) says "native = `dart:io` socket" — but the idiomatic realization is `package:http`'s `IOClient` (the default `http.Client()` on the VM), whose `send(BaseRequest) → StreamedResponse` exposes `.stream` as a **live, unbuffered** `Stream<List<int>>` — exactly what `SseParser.parse` consumes. **Do NOT** reach for `dart:io HttpClient` directly in 4.2: `http.Client` is the injectable seam the constructor demands (`http.Client? client`), it is what tests inject (`MockClient`), and it *is* the dart:io path on native. The reason web needs a *separate* hand-rolled transport (Story 4.10) is precisely that `package:http`'s `BrowserClient` buffers the whole body (breaking SSE streaming) — which is why this story is **native-only** and web is a stub. [Source: AC :35,47; D4 architecture.md:325-337; trap context]
> 4. **Reuse the done `InterceptorChain` (Story 2.9) for the error contract — do NOT hand-roll a `try/catch` adapter.** The error-handling AC (:54-57: connection failure → `RunErrorEvent(TransportError)`, "no uncaught exception escapes the stream") is satisfied *for free* by `InterceptorChain.proceed`: it already wraps a terminal agent's stream errors into a single terminal `RunErrorEvent` via an `ErrorClassifier` ([interceptor.dart:88-119](packages/koel_core/lib/src/agent/interceptor.dart#L88-L119)). And `DefaultErrorClassifier` already maps `SocketException → transportRefused`, `HandshakeException → transportTlsFail`, `HttpException`/`ClientException → transportClosed`, `TimeoutException → transportTimeout` **by runtime-type name** ([error_classifier.dart:38-99](packages/koel_core/lib/src/error/error_classifier.dart#L38-L99)). So `run()` = build an `InterceptorChain` around a private transport-terminal `AbstractAgent`, and `.proceed(input)`. This also wires the `interceptors` constructor param with one line. [Source: AC :54-57; interceptor.dart:88-119; error_classifier.dart:38-99]
> 5. **`HttpAgent` is `class HttpAgent implements AbstractAgent` — NOT `final`.** `AgnoAgent extends HttpAgent` and `LangGraphAgent extends HttpAgent` in Epic 5 (Addendum A.3 — `class AgnoAgent extends HttpAgent`). The class must be open for subclassing, and its transport/codec seams reachable by subclasses (protected, not private-to-instance where a subclass needs them). [Source: addendum A.3; architecture.md:1003 "`koel_agno`, `koel_langgraph` extend `HttpAgent`"]
> 6. **Conditional-import transport seam: io / web / stub, selected at compile time.** AC :48 + Story 4.10's AC mandate `transport/io_transport.dart` + `transport/web_transport.dart` + `transport/transport_stub.dart` with the platform decision via `dart.library.io` vs `dart.library.js_interop`. In 4.2: `io_transport.dart` is real (native, via `http.Client.send`), `web_transport.dart` is a **stub that throws `UnsupportedError`** (real impl = Story 4.10), `transport_stub.dart` is the default fallback. A common interface lets `HttpAgent` consume either uniformly. (The architecture tree calls the native file `native_transport.dart`; see the RESOLVED note — standardize on `io_transport.dart` to match the conditional-import idiom Story 4.10 builds on.) [Source: AC :45-48; epic-4 4.10 :252-255; architecture.md:833-835]
> 7. **The constructor is a one-way door — build it complete, implement behaviors incrementally.** The full Addendum A.2 signature must appear verbatim (it is an AC), but five params are owned by *later* stories: `retry`/`onReconnectAttempt` → 4.4, `synthesizeChunks` → 4.8, `onConnect`/`onDisconnect` → 4.9. Per Story 4.1's precedent, **accept them in the constructor but do not store them as dead fields** (an unused field trips no lint only if it is genuinely read — write-only state is vestigial per CLAUDE.md and the analyzer's `unused_field`). Document each as "consumed in Story 4.X." Used-in-4.2 params: `url`, `client`, `interceptors`, `connectTimeout`, `readTimeout`. [Source: AC :42; 4-1 dev note :204; CLAUDE.md "no vestigial code"]

## Story

As a Flutter/Dart developer,
I want `HttpAgent` connecting to any AG-UI SSE endpoint via injectable `http.Client` (native `dart:io` path first; web transport in Story 4.10),
so that consumer code reads `HttpAgent(url: …)` and immediately gets a streaming `AbstractAgent` per FR-B1 + AR-7.

## Acceptance Criteria

Verbatim from [epic-4 Story 4.2](../planning-artifacts/epics/epic-4-http-transport-koelhttp.md):

1. **Given** `koel_http/lib/src/http_agent.dart`, **When** I inspect the constructor, **Then** it matches Addendum A.2: `HttpAgent({required Uri url, http.Client? client, List<Interceptor>? interceptors, Duration connectTimeout = const Duration(seconds: 30), Duration readTimeout = const Duration(minutes: 5), RetryPolicy? retry, bool synthesizeChunks = true, void Function()? onConnect, void Function(Object)? onDisconnect, void Function(int attempt, Duration delay)? onReconnectAttempt})`, **And** `run(RunAgentInput input)` posts the input as JSON, streams the response through `SseParser`, applies chunk synthesis if enabled, and yields the typed `Stream<AgUiEvent>`.

2. **Given** `koel_http/lib/src/transport/native_transport.dart`, **When** I inspect it, **Then** it uses `dart:io` `HttpClient` for byte streaming on non-web platforms, **And** the platform decision is governed by conditional imports (`io_transport.dart` + `web_transport.dart` with stub).

3. **Given** an `HttpAgent` pointed at a local synthesized SSE server, **When** a run executes, **Then** every event emits as a typed `AgUiEvent` matching the wire fixtures from Epic 3.

4. **Given** a connection failure (refused / TLS / timeout), **When** the agent runs, **Then** the failure surfaces as `RunErrorEvent(TransportError)` with the correct `KoelErrorCode` from Story 2.8, **And** no uncaught exception escapes the stream.

> **AC clarifications (RESOLVED — do not re-litigate, implement):**
>
> - **AC1 "applies chunk synthesis if enabled":** the constructor accepts `synthesizeChunks` (verbatim, default `true`), but the **synthesis transform itself is Story 4.8** ("Chunk synthesis (START/CONTENT/END from CHUNK)"). koel_core's `chunksStage` is **private** kernel machinery (not on the koel_core barrel — verified) so it cannot be reused here; 4.8 builds koel_http's own. In **4.2**, leave the `synthesizeChunks` param accepted-and-documented (consumed in 4.8); do **not** store a dead field or a no-op seam. The downstream pipeline's `chunksStage` (inside `KoelClient`) still synthesizes for consumers who run `HttpAgent` through a `KoelClient`, so 4.2's omission is invisible end-to-end. [Source: AC :43; epic-4 4.8 :192-213; koel_core barrel — chunksStage not exported]
> - **AC2 file name:** AC2 names `transport/native_transport.dart` (line 45) but in the same breath specifies conditional imports over `io_transport.dart` + `web_transport.dart` (line 48); the architecture tree ([architecture.md:834](`_bmad-output/planning-artifacts/architecture.md`)) also says `native_transport.dart`. **RESOLVED → use `io_transport.dart`** (+ `web_transport.dart` + `transport_stub.dart` + a `transport.dart` selector). This is the conditional-import-idiomatic naming that maps to `dart.library.io`/`dart.library.js_interop` and that **Story 4.10's AC explicitly builds on** ([epic-4 4.10 :252-255](../planning-artifacts/epics/epic-4-http-transport-koelhttp.md)). The "native_transport.dart" naming is stale architecture-tree drift; see the end-note flagged for the architecture doc. [Source: AC :45-48 vs epic-4 4.10 :252-255]
> - **AC2 "uses `dart:io` `HttpClient`":** realized through `package:http`'s `IOClient` (the default `http.Client()` on the VM wraps `dart:io HttpClient`). `io_transport.dart` is the *only* file in koel_http allowed to be native-coupled; it must NOT be imported on web (the conditional selector guarantees this). Do not hand-roll a raw `dart:io HttpClient` — see trap #3. [Source: AC :47; D4]
> - **AC3 "local synthesized SSE server":** stand up an in-process HTTP server (`HttpServer.bind('127.0.0.1', 0)` from `dart:io`, in the **test** file — `dart:io` in tests is fine, web-safety governs `lib/` only, per 4.1's review precedent) that replays the Epic 3 synthesized fixtures as a `text/event-stream` body. Assert the typed `AgUiEvent`s emitted match the fixtures. Reuse `koel_test`'s fixtures rather than re-synthesizing. [Source: AC :50-52; 4-1 review finding on test `dart:io`]
> - **AC4 "correct `KoelErrorCode` from Story 2.8":** `SocketException`/connection-refused → `transportRefused`; TLS → `transportTlsFail`; timeout → `transportTimeout`; mid-stream close / non-2xx → `transportClosed`. These come from `DefaultErrorClassifier`'s name-based matching ([error_classifier.dart:69-93](packages/koel_core/lib/src/error/error_classifier.dart#L69-L93)) when you route errors through `InterceptorChain` (trap #4). A non-2xx response is not an exception — your transport terminal must detect it and throw `TransportError(code: transportClosed, statusCode: …)` itself. [Source: AC :56; error_classifier.dart:38-99; koel_error.dart TransportError.statusCode]

## Tasks / Subtasks

- [x] **Task 0 — Read the real surfaces before writing a line** (AC: all — skipping this builds the wrong contract)
  - [x] Read [abstract_agent.dart](packages/koel_core/lib/src/agent/abstract_agent.dart) — `abstract interface class AbstractAgent` with the single method `Stream<AgUiEvent> run(RunAgentInput input)` (non-nullable return; single-subscription; adapters emit `RunErrorEvent`, never throw). This is the contract `HttpAgent implements`. [Source: abstract_agent.dart:10-14]
  - [x] Read [interceptor.dart](packages/koel_core/lib/src/agent/interceptor.dart) **in full** — `abstract class Interceptor { Stream<AgUiEvent> intercept(InterceptorChain chain, RunAgentInput input); }` and `InterceptorChain({required List<Interceptor> interceptors, required AbstractAgent agent, ErrorClassifier errorClassifier = const DefaultErrorClassifier()})` with `Stream<AgUiEvent> proceed(RunAgentInput input)`. Note `proceed` (lines 88-119): a **synchronous** throw while building the stream → `Stream.value(RunErrorEvent)`; a **stream-borne** error → a transformer converts it to a terminal `RunErrorEvent` and closes. This is your whole error contract (trap #4). [Source: interceptor.dart:41-137]
  - [x] Read [error_classifier.dart](packages/koel_core/lib/src/error/error_classifier.dart) **in full** — `DefaultErrorClassifier.classify` maps by `runtimeType.toString()` (web-safe, no `dart:io` import in koel_core): `SocketException→transportRefused`, `HandshakeException→transportTlsFail`, `HttpException`/`ClientException→transportClosed`, `TimeoutException→transportTimeout`, `FormatException→protocolMalformed`, else `unknown`. Idempotent for already-typed `KoelError`. [Source: error_classifier.dart:38-99]
  - [x] Read [koel_error.dart](packages/koel_core/lib/src/error/koel_error.dart) `TransportError` — `const factory TransportError({required String message, required KoelErrorCode code, Object? cause, int? statusCode})`; and [koel_error_code.dart](packages/koel_core/lib/src/error/koel_error_code.dart) transport arm: `transportTimeout, transportClosed, transportRefused, transportTlsFail`. [Source: koel_error.dart; koel_error_code.dart]
  - [x] Read [run_agent_input.dart](packages/koel_core/lib/src/input/run_agent_input.dart) **in full** — 8 fields (`threadId`, `runId` required; `state`/`messages`/`tools`/`context`/`forwardedProps` defaulted; `reasoningEcho` nullable `Map<String,Uint8List>`). **No `toJson`** (line 22-24 says the codec lands here). [Source: run_agent_input.dart:26-41]
  - [x] Read [message.dart](packages/koel_core/lib/src/message/message.dart) + [tool_definition.dart](packages/koel_core/lib/src/tool/tool_definition.dart) — both use json_serializable (`part '*.g.dart'`, `factory X.fromJson`), so both have generated **instance `toJson()`**. Confirm by checking `message.g.dart` exposes `_$MessageToJson`. You compose these in the input codec (Task 2). [Source: message.dart:4,45; tool_definition.dart:23]
  - [x] Read the existing scaffold you extend: [koel_http/pubspec.yaml](packages/koel_http/pubspec.yaml) (`dependencies: koel_core:`, `dev_dependencies: koel_lints:, test: ^1.25.0` — **no `http` yet**) and [koel_http/lib/koel_http.dart](packages/koel_http/lib/koel_http.dart) (`export 'src/sse_parser.dart';` only). Read [sse_parser.dart](packages/koel_http/lib/src/sse_parser.dart) — `final class SseParser` with `const SseParser()` + `Stream<AgUiEvent> parse(Stream<List<int>> bytes)`. This is the stream you feed transport bytes into. [Source: 4-1 File List; koel_http scaffold]
  - [x] Read the AG-UI wire contract: [discovery-ag-ui-spec.md:20-22](../planning-artifacts/prds/prd-koel-2026-05-27/discovery-ag-ui-spec.md) — `POST /` · `Content-Type: application/json` · `Accept: text/event-stream` · body = `RunAgentInput` JSON `{threadId, runId, state, messages, tools, context, forwardedProps}` (camelCase, verbatim). Response is `text/event-stream`. [Source: discovery-ag-ui-spec.md:20-22,92-93]

- [x] **Task 1 — Add `http` dependency** (AC: #1, #2, #3)
  - [x] In [koel_http/pubspec.yaml](packages/koel_http/pubspec.yaml) (MODIFY) add `http: ^1.6.0` under `dependencies:` (latest stable; verified on pub.dev). Keep `koel_core:` (bare workspace key) and the existing `dev_dependencies`. Add **no** web packages yet (`package:web` is Story 4.10). [Source: AC :42; trap #2; pub.dev http 1.6.0]
  - [x] Run `dart pub get` from the workspace root; confirm `koel_http` resolves `http` and `koel_core`. [Source: root pubspec workspace resolution]

- [x] **Task 2 — `RunAgentInput` → JSON wire codec** (AC: #1)
  - [x] New `packages/koel_http/lib/src/wire/run_agent_input_codec.dart` (a free function or extension — **not** codegen; `RunAgentInput` is freezed-without-json by design). Produce `Map<String, dynamic>` with camelCase keys matching the AG-UI shape: `threadId`, `runId`, `state`, `messages` (`.map((m) => m.toJson())`), `tools` (`.map((t) => t.toJson())`), `context`, `forwardedProps`. [Source: discovery-ag-ui-spec.md:92-93; message/tool toJson]
  - [x] `reasoningEcho` (`Map<String, Uint8List>?`): when non-null **and** non-empty, emit `reasoningEcho: { id: base64Encode(blob) }` (using `base64Encode` from `dart:convert`); **omit the key entirely when null/empty** (it is a koel extension, not in the AG-UI normative body — a backend that doesn't understand it ignores it). This is the "base64 `Uint8List` converter" the koel_core comment defers to this transport. [Source: run_agent_input.dart:22-24; trap #1]
  - [x] The HTTP body is `jsonEncode(codec(input))`. Do **not** add a `fromJson` (decode of `RunAgentInput` is not needed — the client only *posts* it; events come back via `SseParser`). [Source: AC :43; YAGNI / one-way-door]

- [x] **Task 3 — Transport seam: common interface + conditional imports** (AC: #2)
  - [x] New `packages/koel_http/lib/src/transport/transport.dart` — declare a package-private common interface, e.g.:
    ```dart
    abstract interface class Transport {
      /// Opens the SSE connection: POSTs [body] to [url] with [headers],
      /// fires when response headers arrive, and exposes the live byte stream.
      Future<TransportResponse> connect(Uri url, {required List<int> body, required Map<String, String> headers, required Duration connectTimeout, required Duration readTimeout, http.Client? client});
    }
    ```
    with a small `TransportResponse` carrying `int statusCode` + `Stream<List<int>> body` (+ a close/abort handle reserved for Story 4.3 — accept the handle now only if you *use* it in 4.2; otherwise 4.3 adds it). Plus a factory `Transport createTransport()` selected by conditional import:
    ```dart
    import 'transport_stub.dart'
        if (dart.library.io) 'io_transport.dart'
        if (dart.library.js_interop) 'web_transport.dart';
    ```
    [Source: AC :48; epic-4 4.10 :252-255; trap #6]
  - [x] New `packages/koel_http/lib/src/transport/io_transport.dart` (real) — implements `Transport` via the injectable `http.Client` (default `http.Client()` → `IOClient` on the VM). Build a POST `http.Request` (or `StreamedRequest`) with the JSON body + `Content-Type: application/json` + `Accept: text/event-stream` headers; `client.send(request)` → `StreamedResponse`; expose `response.statusCode` + `response.stream` (live `Stream<List<int>>`). Apply `connectTimeout` to the `send` future; `readTimeout` to inter-byte idle (or document it as enforced in 4.3 if idle-timeout needs the abort handle). Must define `Transport createTransport()`. [Source: AC :47; trap #3]
  - [x] New `packages/koel_http/lib/src/transport/web_transport.dart` (**stub**) — define `Transport createTransport() => throw UnsupportedError('Web transport lands in Story 4.10');` (or a `Transport` whose `connect` throws). No `package:web` import yet. A doc comment cites Story 4.10 + Gap G-1 (`AbortController`). [Source: epic-4 4.10 :238-255; architecture.md:1198-1202]
  - [x] New `packages/koel_http/lib/src/transport/transport_stub.dart` (default fallback) — `Transport createTransport() => throw UnsupportedError('No transport for this platform');`. [Source: conditional-import idiom]

- [x] **Task 4 — `HttpAgent`** (AC: #1, #3, #4)
  - [x] New `packages/koel_http/lib/src/http_agent.dart` — `class HttpAgent implements AbstractAgent` (**not `final`** — `AgnoAgent`/`LangGraphAgent` extend it, trap #5). Constructor matches Addendum A.2 **verbatim** (AC1). Store only the params 4.2 consumes: `url`, `client`, `interceptors`, `connectTimeout`, `readTimeout`. Accept `retry`/`synthesizeChunks`/`onConnect`/`onDisconnect`/`onReconnectAttempt` with a doc note naming their owning story (4.4/4.8/4.9); do **not** store them as dead fields (trap #7). Imports: `package:http/http.dart` (as `http`), `package:koel_core/koel_core.dart` (barrel only), `transport/transport.dart`, `wire/run_agent_input_codec.dart`. **No `dart:io`/`dart:html`/`package:web` in this file** — platform coupling lives only in `io_transport.dart`/`web_transport.dart`. [Source: AC :42; addendum A.2; trap #5,#7]
  - [x] `RetryPolicy`: define a minimal value type in `packages/koel_http/lib/src/connection/reconnect_policy.dart` (architecture's home for it — [architecture.md:840](`_bmad-output/planning-artifacts/architecture.md`)) so the constructor's `RetryPolicy? retry` compiles. Fields mirror what 4.4 needs (`maxAttempts`, `baseDelay`, `maxDelay`, `jitter`) — **but do not implement backoff/reconnect here** (4.4). Keep it a plain immutable data holder with a `const` ctor + dartdoc pointing to Story 4.4. Export it from the barrel (it is a public constructor param type → one-way door). [Source: trap #2; AC :42; architecture.md:840]
  - [x] `run(RunAgentInput input)`: compose via the done `InterceptorChain` (trap #4):
    ```dart
    @override
    Stream<AgUiEvent> run(RunAgentInput input) => InterceptorChain(
          interceptors: _interceptors,
          agent: _TransportTerminal(this),   // private AbstractAgent doing POST+SSE
          errorClassifier: const DefaultErrorClassifier(),
        ).proceed(input);
    ```
    The private `_TransportTerminal.run()` is `async*`: encode body (`jsonEncode(codec(input))`), `createTransport().connect(...)`, on non-2xx `throw TransportError(code: transportClosed, statusCode: r.statusCode, message: …)`, then `yield* const SseParser().parse(r.body)`. Any `SocketException`/`HandshakeException`/`TimeoutException`/`ClientException`/`FormatException` thrown by the transport or parser propagates as a stream error → `InterceptorChain` converts it to a terminal `RunErrorEvent(classified)`. **Nothing escapes uncaught** (AC4). [Source: AC :43,54-57; interceptor.dart:88-119; sse_parser.dart]
  - [x] Full dartdoc on `HttpAgent` + `run` (contract: posts JSON, streams via `SseParser`, errors as `RunErrorEvent(TransportError)`; native-only, web is 4.10; cites FR-B1, AR-7). [Source: convention §3 doc discipline]

- [x] **Task 5 — Export from the barrel** (AC: #1)
  - [x] In [koel_http/lib/koel_http.dart](packages/koel_http/lib/koel_http.dart) (MODIFY) add `export 'src/http_agent.dart';` and `export 'src/connection/reconnect_policy.dart';` (the `RetryPolicy` type is a public ctor param). **Do NOT** export the transport files, the codec, or `_TransportTerminal` (internal). **Do NOT** re-export `koel_core` or `package:http` (consumers depend on them directly; only the meta-package re-exports). [Source: barrel discipline 2.15; 4-1 Task 4]

- [x] **Task 6 — Tests** (AC: #1, #2, #3, #4)
  - [x] New `packages/koel_http/test/http_agent_test.dart` (mirror `lib/src/http_agent.dart`; `package:test`; one top-level `group('HttpAgent', …)`). [Source: architecture.md:655-665 mirror naming]
  - [x] **AC3 happy path against a local SSE server:** in the test, `HttpServer.bind('127.0.0.1', 0)` (`dart:io` in *tests* is allowed — see AC3 clarification), respond `200` with `Content-Type: text/event-stream` and a body replaying Epic 3 synthesized wire fixtures (reuse `koel_test` fixtures, don't re-synthesize). Point `HttpAgent(url: Uri.parse('http://127.0.0.1:$port'))` at it; assert `run(input)` yields the expected typed `AgUiEvent`s in order, matching the fixtures. Tear the server down in `tearDown`. [Source: AC :50-52]
  - [x] **AC1 body shape:** assert the server received `POST`, `Content-Type: application/json`, `Accept: text/event-stream`, and a body that `jsonDecode`s to the expected `{threadId, runId, …}` map (including a base64 `reasoningEcho` round-trip when set). [Source: AC :43; discovery-ag-ui-spec.md:20-22]
  - [x] **AC4 error contract (use injected `MockClient` / a failing server):**
    - connection refused (point at a closed port, or a `MockClient` throwing `SocketException`) → stream emits `RunErrorEvent` whose `error` is `TransportError(code: transportRefused)`; assert via `emitsThrough`/`emits(isA<RunErrorEvent>().having((e)=>e.error.code, 'code', KoelErrorCode.transportRefused))`. **No thrown exception escapes** (the stream completes normally after the error event).
    - non-2xx (server responds `500`) → `RunErrorEvent(TransportError(code: transportClosed, statusCode: 500))`.
    - timeout (`connectTimeout` very small against a stalling server, or `MockClient` that delays) → `TransportError(code: transportTimeout)`.
    - (TLS path may be asserted via a `MockClient` throwing a `HandshakeException`-named error → `transportTlsFail`.)
    [Source: AC :54-57; error_classifier.dart:69-93]
  - [x] **Interceptor wiring smoke test:** a trivial pass-through `Interceptor` in `interceptors:` is invoked during a run (proves the chain is wired). [Source: AC :42 interceptors param; interceptor.dart]
  - [x] Use `package:http`'s `MockClient` (from `package:http/testing.dart`) for the no-real-socket cases; the local `HttpServer` for the real-stream happy path. [Source: package:http testing]

- [x] **Task 7 — Quality gates (NO finalization gates this story)** (AC: all)
  - [x] `melos run analyze` → **0 issues** workspace-wide. (`koel_http` inherits the **root** profile — `package:lints/recommended.yaml` + the koel_lints plugin; it has no member `analysis_options.yaml`. Write full dartdoc anyway so Story 4.10's doc gate needs no backfill.) Watch the **unused-field trap** (trap #7): if you stored a deferred param you don't read, the analyzer fails — accept-but-don't-store instead. [Source: NFR-13; root analysis_options.yaml; 4-1 :204]
  - [x] `melos run test` → green workspace-wide, including the new `koel_http` agent suite. [Source: tool/test_package.sh]
  - [x] `melos run format:check` → clean. [Source: tool/format.sh]
  - [x] **Do NOT** add `koel_http`'s member `analysis_options.yaml` doc gate or the ≥90% coverage gate — those are **package-finalization** gates that land in the epic-sealing story (**4.10**), exactly as 4.1 deferred them. 4.2 needs only `analyze`/`test`/`format:check` green. [Source: epic-4 overview; 4-1 design decision #5; architecture.md koel_http analysis_options is the finalize-story artifact]

## Dev Notes

### What this story is, in one paragraph

The story that turns `koel_http` from "a parser" into "a transport." It adds `HttpAgent` — `class HttpAgent implements AbstractAgent` — that POSTs a `RunAgentInput` as JSON to an AG-UI SSE endpoint, streams the response bytes through Story 4.1's `SseParser`, and yields a typed `Stream<AgUiEvent>`. Three sub-pieces make it work: (1) the **`RunAgentInput` → JSON wire codec** koel_core deliberately deferred to "the transport that posts this payload" (base64 for `reasoningEcho`); (2) a **conditional-import transport seam** (`io_transport.dart` real, `web_transport.dart`/`transport_stub.dart` stubs) so native streams via `http.Client.send` today and web swaps in `package:web` fetch in Story 4.10; (3) **`run()` composed over the done `InterceptorChain`**, which gives the AC4 error contract (`RunErrorEvent(TransportError)`, nothing uncaught) and the `interceptors` param for free. Scope is native-only. **Not** retry/backoff (4.4), auth/logging/trace/sentry/pii interceptor *implementations* (4.4–4.7), chunk synthesis transform (4.8), lifecycle-hook firing (4.9), TCP-abort cancellation (4.3), web transport (4.10), or the package-finalization gates (4.10).

### The injectable-`http.Client` ↔ native-`dart:io` seam (RESOLVED — the design crux)

The constructor exposes `http.Client? client`; the architecture (D4) says native uses a "`dart:io` socket." These are the **same thing**: on the VM, the default `http.Client()` is an `IOClient` backed by `dart:io HttpClient`, and `IOClient.send(request)` returns a `StreamedResponse` whose `.stream` is the **live, unbuffered** `HttpClientResponse` byte stream — precisely the `Stream<List<int>>` `SseParser.parse` wants. So:

- `io_transport.dart` does `client.send(post)` and hands `response.stream` to the agent. The injected `client` is the seam for tests (`MockClient`) and for backends.
- **Web cannot do this**: `package:http`'s `BrowserClient` uses XHR and **buffers the entire body** before completing `send` — fatal for an infinite SSE stream. That is the whole reason Story 4.10 hand-rolls a separate `package:web` fetch + `ReadableStream` transport instead of reusing `http.Client`. This is why 4.2 is native-only and `web_transport.dart` is a stub.

Do **not** hand-roll a raw `dart:io HttpClient` in 4.2 — it would duplicate what `IOClient` gives you and break the `http.Client? client` injectability the AC demands.

### Why `RunAgentInput` has no codec, and where base64 fits (RESOLVED)

koel_core ships `RunAgentInput` as freezed-**without**-json on purpose ([run_agent_input.dart:22-24](packages/koel_core/lib/src/input/run_agent_input.dart#L22-L24)): the wire codec "needs a base64 `Uint8List` converter and lands with the transport that posts this payload (Epic 4, `koel_http`)." That transport is this story. `Message`/`ToolDefinition` *do* have generated `toJson()` (json_serializable), so the codec is mostly composition; the only bespoke part is `reasoningEcho: Map<String, Uint8List>?` → `{id: base64Encode(bytes)}`, omitted when null/empty. `reasoningEcho` is a **koel extension** — it is not one of the seven AG-UI-normative body fields ([discovery-ag-ui-spec.md:92-93](../planning-artifacts/prds/prd-koel-2026-05-27/discovery-ag-ui-spec.md)) — so a backend that doesn't recognize it simply ignores it. No `fromJson` is needed (the client posts but never decodes `RunAgentInput`).

### The error contract is free if you use `InterceptorChain` (RESOLVED)

AC4 ("connection failure → `RunErrorEvent(TransportError)`, no uncaught exception escapes") looks like it needs a careful `try/catch` adapter (architecture §5 convention, [architecture.md:597-618](`_bmad-output/planning-artifacts/architecture.md`)). It doesn't — Story 2.9's `InterceptorChain.proceed` already does exactly this: it wraps a terminal agent's stream errors into a single terminal `RunErrorEvent` via an `ErrorClassifier` ([interceptor.dart:88-119](packages/koel_core/lib/src/agent/interceptor.dart#L88-L119)), and `DefaultErrorClassifier` maps the transport exception families by name ([error_classifier.dart:69-93](packages/koel_core/lib/src/error/error_classifier.dart#L69-L93)). So `run()` = `InterceptorChain(interceptors: _interceptors, agent: _TransportTerminal(this), errorClassifier: const DefaultErrorClassifier()).proceed(input)`. This single composition satisfies AC4 **and** wires the `interceptors` param **and** means Stories 4.4–4.7 only add interceptor *classes*, never re-plumb the chain. The one error the transport must raise itself is **non-2xx** (an HTTP 500 is not a thrown exception): the terminal checks `statusCode` and throws `TransportError(code: transportClosed, statusCode: …)`, which the classifier passes through idempotently.

> Note on a subtlety: `koel_core`'s `DefaultErrorClassifier` matches `SocketException`/`HandshakeException`/`HttpException` by `runtimeType.toString()` (it cannot `import 'dart:io'` — it stays web-safe). `package:http` throws `ClientException` for many network failures (already mapped → `transportClosed`); a `MockClient` you write can throw a `SocketException` directly to exercise `transportRefused`. If you find a real-world transport failure that classifies to `unknown`, do **not** patch `koel_core` — koel_http may later ship its own `ErrorClassifier` subclass (the status-code-aware one is a koel_agno/Epic-5 concern). For 4.2, `DefaultErrorClassifier` is correct.

### Constructor is a one-way door; behaviors arrive incrementally (RESOLVED)

The full Addendum A.2 signature is an AC — write it verbatim now. But five params are owned by later stories:

| Param | Owning story | 4.2 treatment |
| ----- | ------------ | ------------- |
| `retry` (`RetryPolicy?`) | 4.4 (backoff/jitter/reconnect) | Define minimal `RetryPolicy` data type so it compiles; accept param; do not store/wire |
| `synthesizeChunks` | 4.8 (CHUNK→START/CONTENT/END) | Accept param; do not store/wire (koel_core `chunksStage` is private; 4.8 builds koel_http's own) |
| `onConnect` / `onDisconnect` | 4.9 (lifecycle hooks) | Accept params; do not store/wire |
| `onReconnectAttempt` | 4.4 (fires on retry) | Accept param; do not store/wire |

Per Story 4.1's precedent ([4-1 :204](4-1-framework-free-sse-parser.md)): storing write-only state is vestigial (CLAUDE.md "no just-in-case code") **and** trips the analyzer's `unused_field`, breaking the Task-7 `analyze=0` gate. Accepting an unused *named constructor param* is **not** flagged by `package:lints/recommended` (there is no unused-constructor-param lint in that set), so the verbatim signature is analyzer-clean even with five params deferred. Document each deferred param with `/// Consumed in Story 4.X.`

### Out of scope — do NOT build these (RESOLVED)

- Retry / exponential backoff / jitter / reconnect / `onReconnectAttempt` firing / `ConnectionResumed` → **Story 4.4**. (`RetryPolicy` is *defined* here only so the ctor compiles.)
- `AuthInterceptor`, `LoggingInterceptor`, `EventTraceInterceptor`, `SentryBreadcrumbInterceptor`, `PIIRedactionInterceptor` *implementations* + the default-ON chain → **Stories 4.4–4.7**. (4.2 wires the chain *mechanism*; it ships **zero** built-in interceptors.)
- Chunk synthesis transform (`synthesizeChunks` behavior) → **Story 4.8**.
- `onConnect`/`onDisconnect` firing + `connection/lifecycle.dart` DevTools subsystem → **Story 4.9**.
- Cancellation / `StreamSubscription.cancel()` → TCP abort < 50 ms → **Story 4.3** (the `TransportResponse` abort handle may be reserved but only if 4.2 actually uses it).
- Web transport (`package:web` fetch + ReadableStream + AbortController) + perf baseline → **Story 4.10** (which also turns on the doc gate + ≥90% coverage gate). `web_transport.dart` is a throwing stub here.
- The `koel_http` member `analysis_options.yaml` doc gate and the coverage gate → **Story 4.10**.

### Files you will touch

| Path | Action | Note |
| ---- | ------ | ---- |
| [packages/koel_http/pubspec.yaml](packages/koel_http/pubspec.yaml) | MODIFY | add `http: ^1.6.0` to `dependencies` (keep `koel_core:`). |
| `packages/koel_http/lib/src/http_agent.dart` | NEW | `class HttpAgent implements AbstractAgent` (non-final); verbatim A.2 ctor; `run` over `InterceptorChain`. |
| `packages/koel_http/lib/src/wire/run_agent_input_codec.dart` | NEW | hand-written `RunAgentInput`→`Map` (base64 `reasoningEcho`); no codegen. |
| `packages/koel_http/lib/src/transport/transport.dart` | NEW | `Transport` interface + `TransportResponse` + conditional-import `createTransport()` selector. |
| `packages/koel_http/lib/src/transport/io_transport.dart` | NEW | real native impl via `http.Client.send`. |
| `packages/koel_http/lib/src/transport/web_transport.dart` | NEW | **stub** — throws `UnsupportedError` (real in 4.10). |
| `packages/koel_http/lib/src/transport/transport_stub.dart` | NEW | default-platform fallback stub. |
| `packages/koel_http/lib/src/connection/reconnect_policy.dart` | NEW | minimal `RetryPolicy` data type (behavior in 4.4). |
| [packages/koel_http/lib/koel_http.dart](packages/koel_http/lib/koel_http.dart) | MODIFY | add `export 'src/http_agent.dart';` + `export 'src/connection/reconnect_policy.dart';`. |
| `packages/koel_http/test/http_agent_test.dart` | NEW | local-SSE-server happy path + `MockClient` error matrix + body-shape + interceptor smoke. |

### Library / framework requirements

- **Runtime:** `package:http ^1.6.0` (`Client`, `Request`/`StreamedRequest`, `StreamedResponse`, `IOClient` via default `http.Client()`); `package:koel_core` (barrel) — `AbstractAgent`, `RunAgentInput`, `AgUiEvent`, `Interceptor`, `InterceptorChain`, `DefaultErrorClassifier`, `TransportError`, `KoelErrorCode`, `RunErrorEvent`; `SseParser` (own package). SDK lang: `dart:convert` (`jsonEncode`, `base64Encode`), `dart:async`. `dart:io` **only** inside `io_transport.dart`.
- **Dev:** `package:test ^1.25.0`, `package:http/testing.dart` (`MockClient`), `dart:io` (test-only `HttpServer`), `koel_lints` (workspace).
- **Forbidden in `lib/` (web-safety, framework-free):** `dart:io`/`dart:html`/`package:web` **anywhere except** `io_transport.dart` (native, behind the conditional import) and the *future* `web_transport.dart`; Flutter; `freezed`/`build_runner` (no codegen — the codec and `RetryPolicy` are hand-written); any SSE library (`package:sse`, `package:eventsource`). `http_agent.dart` itself imports **no** platform library.

### Project Structure Notes

- `koel_http` is already a workspace member ([root pubspec.yaml](pubspec.yaml)); SDK constraint stays the workspace-uniform `">=3.11.0 <4.0.0"`. No member `analysis_options.yaml` (inherits root; the doc/coverage gates are Story 4.10's).
- New subdirs `lib/src/transport/`, `lib/src/connection/`, `lib/src/wire/` match the architecture's `koel_http` tree ([architecture.md:829-846](`_bmad-output/planning-artifacts/architecture.md`)). `sse_parser.dart` stays flat under `src/` (4.1).
- Barrel discipline: only `lib/koel_http.dart` is public; transports, codec, and `_TransportTerminal` stay in `lib/src/` and are never exported.

### Previous Story Intelligence

- **Story 4.1** built `SseParser` (`const SseParser().parse(Stream<List<int>>) → Stream<AgUiEvent>`) — you feed it the transport byte stream; it owns RFC 8895 framing, `jsonDecode`, `AgUiEvent.fromWire`, and the two-sided error contract (corrupt JSON → `ProtocolError(protocolMalformed)`; unknown type → `UnknownAgUiEvent`). You reuse it verbatim; never re-parse SSE. 4.1 also established: **defer finalization gates to the epic-sealing story (4.10)**, and **test-only `dart:io` is acceptable** (the web-safety rule governs `lib/`). [Source: [4-1-framework-free-sse-parser.md](4-1-framework-free-sse-parser.md):199-232]
- **Story 2.9** built `Interceptor` + `InterceptorChain` (the error-classifying composition you reuse for `run()`). **Story 2.8** built the `KoelError` hierarchy + `KoelErrorCode` (the transport codes AC4 names). **Story 2.14** built `KoelClient`, which wires *its own* InterceptorChain around the agent — independent of `HttpAgent`'s transport-level chain; do not conflate them. [Source: epic-2 2.8/2.9/2.14; koel_client.dart:126]
- **Recent commits** (4.1, 3.5, 3.4, 3.3): house style is `final class`/sealed where possible, `const` ctors, exhaustive dartdoc, table-driven `package:test`, tight change sets, no codegen unless freezed types demand it. `HttpAgent` is an intentional exception to `final` (subclassed by Epic-5 backends). [Source: `git log`]

### Latest Tech Information

- **`package:http` 1.6.0** (latest stable, verified pub.dev): `Client.send(BaseRequest) → Future<StreamedResponse>`; `StreamedResponse.stream` is a single-subscription `Stream<List<int>>` delivered incrementally on native (`IOClient`). `MockClient`/`MockClient.streaming` (from `package:http/testing.dart`) fake responses without a socket — use `MockClient.streaming` for SSE-style chunked bodies and a throwing `MockClient` for the refused/timeout/TLS error cases.
- **Streaming caveat (the reason for D4):** `BrowserClient` (web) sets `responseType=''`/uses XHR and resolves `send` only after the full body — it does **not** stream. Confirmed-by-design that web needs the Story 4.10 hand-rolled fetch transport; do not attempt web via `package:http` here.
- **Timeouts:** apply `connectTimeout` to the `client.send(...)` future via `.timeout(connectTimeout)` (throws `TimeoutException` → `transportTimeout`). A true inter-byte `readTimeout` needs to watch the response stream and abort idle connections — if that requires the abort handle that Story 4.3 introduces, document `readTimeout` as accepted-and-stored-but-enforced-in-4.3 rather than faking it.
- **`dart:io HttpServer` for the happy-path test:** `await HttpServer.bind(InternetAddress.loopbackIPv4, 0)`, then on each request set `response.headers.contentType = ContentType('text','event-stream')`, write the fixture frames, and `await response.close()`. Bind to port `0` for a free ephemeral port; read it from `server.port`.

### References

- Story spec (ACs, signature, transport, error contract): [epic-4 Story 4.2](../planning-artifacts/epics/epic-4-http-transport-koelhttp.md) (lines 32-57).
- Epic 4 overview (coverage ≥90%, six interceptors, transport split): [epic-4-http-transport-koelhttp.md](../planning-artifacts/epics/epic-4-http-transport-koelhttp.md) (line 3).
- Addendum A.2 canonical `HttpAgent` + interceptor signatures: [addendum.md](../planning-artifacts/prds/prd-koel-2026-05-27/addendum.md) (§A.2, lines 286-330); A.3 `AgnoAgent extends HttpAgent` (lines 332+).
- `AbstractAgent` contract: [abstract_agent.dart:10-14](packages/koel_core/lib/src/agent/abstract_agent.dart#L10-L14).
- `Interceptor`/`InterceptorChain` (error→RunErrorEvent): [interceptor.dart:41-137](packages/koel_core/lib/src/agent/interceptor.dart#L41-L137).
- `DefaultErrorClassifier` (transport-exception → KoelErrorCode by name): [error_classifier.dart:38-99](packages/koel_core/lib/src/error/error_classifier.dart#L38-L99).
- `TransportError` + transport `KoelErrorCode`s: [koel_error.dart](packages/koel_core/lib/src/error/koel_error.dart), [koel_error_code.dart](packages/koel_core/lib/src/error/koel_error_code.dart).
- `RunAgentInput` (no codec — codec lands here): [run_agent_input.dart:22-41](packages/koel_core/lib/src/input/run_agent_input.dart#L22-L41); `Message`/`ToolDefinition` `toJson`: [message.dart:45](packages/koel_core/lib/src/message/message.dart#L45), [tool_definition.dart:23](packages/koel_core/lib/src/tool/tool_definition.dart#L23).
- `SseParser` (the byte→event sink): [sse_parser.dart:28-58](packages/koel_http/lib/src/sse_parser.dart#L28-L58).
- AG-UI wire shape (`POST /`, headers, body fields): [discovery-ag-ui-spec.md:20-22,92-93](../planning-artifacts/prds/prd-koel-2026-05-27/discovery-ag-ui-spec.md).
- `koel_http` tree + D4 web/native split: [architecture.md](../planning-artifacts/architecture.md) (lines 325-337 D4; 829-846 koel_http layout; 1077-1087 data flow; 1198-1202 Gap G-1 web cancellation).
- House-style exemplar: [4-1-framework-free-sse-parser.md](4-1-framework-free-sse-parser.md).

### Design decisions (RESOLVED — AC/architecture-forced, not open)

1. **Native byte stream = `http.Client.send().stream`** (default `http.Client()` = `IOClient`); the `client` param is the injectable seam. No raw `dart:io HttpClient`. [crux seam]
2. **`RunAgentInput` JSON codec is hand-written in koel_http** (base64 `reasoningEcho`, omitted when null); no `fromJson`. [trap #1]
3. **`run()` composed over the done `InterceptorChain`** — satisfies the AC4 error contract + wires `interceptors` in one expression; only non-2xx is thrown explicitly (`TransportError(transportClosed, statusCode:)`). [trap #4]
4. **`HttpAgent` is `class … implements AbstractAgent`, NOT `final`** — Epic-5 backends extend it. [trap #5]
5. **Transport files `io_transport.dart` (real) / `web_transport.dart` (stub) / `transport_stub.dart` + `transport.dart` selector**, conditional import on `dart.library.io` vs `dart.library.js_interop`. (Resolves AC2's in-line naming drift toward Story 4.10's names.) [trap #6, AC2 clarification]
6. **Full A.2 constructor verbatim; `retry`/`synthesizeChunks`/`onConnect`/`onDisconnect`/`onReconnectAttempt` accepted but not stored** (consumed in 4.4/4.8/4.9). `RetryPolicy` *defined* (minimal) so the ctor compiles. [trap #2, #7]
7. **Add `http: ^1.6.0`; native-only; `web_transport.dart` throws.** [trap #3, #6]
8. **No finalization gates this story** — member `analysis_options.yaml` doc gate + ≥90% coverage gate are Story 4.10's epic-sealing job (4.1 precedent). [Previous Story Intelligence]

These are baked in — implement them; no confirmation gate.

## Dev Agent Record

### Context Reference

<!-- Path(s) to story context will be added here by context workflow -->

### Agent Model Used

claude-opus-4-8[1m] (via `/agent-flutter-engineer` specialist)

### Debug Log References

- `dart pub get` — `http: ^1.6.0` + `koel_test` (dev) resolved cleanly into the workspace.
- `dart analyze lib` (koel_http) → No issues found (verified before tests).
- `melos run analyze` → 0 issues across all 11 packages.
- `melos run format:check` → 2 files reformatted (`http_agent_test.dart`, `io_transport.dart`), then clean.
- `melos run test` → all packages green (koel_http agent suite: 10 tests).

### Completion Notes List

- **Wire codec (Task 2):** `encodeRunAgentInput` is a hand-written free function (no codegen) composing the generated `Message.toJson()`/`ToolDefinition.toJson()`; camelCase AG-UI keys; `reasoningEcho` base64-encoded and **omitted entirely** when null/empty (koel extension, not normative). No `fromJson` (client only posts). Confirmed `_$MessageToJson`/`_$ToolDefinitionToJson` exist and the public `toJson()` is on the freezed mixins before composing.
- **Transport seam (Task 3):** conditional import `transport_stub.dart` / `io_transport.dart` (`dart.library.io`) / `web_transport.dart` (`dart.library.js_interop`), mirroring `package:http`'s own `client.dart` pattern (`Transport()` factory → `createTransport()`). `io_transport.dart` is the sole native-coupled file in `lib/`; web + stub throw `UnsupportedError`. `transport.dart` carries the `Transport` interface + minimal `TransportResponse` (statusCode + live byte stream; abort handle deferred to 4.3 per its own note).
- **`io_transport` lifecycle:** an injected `http.Client` is consumer-owned (reused, never closed here); a client the transport creates itself (null injection) is closed exactly once on stream teardown — drained, errored, or cancelled — via a single-subscription `StreamController` wrapper that preserves pause/resume. No socket leak on the `HttpAgent(url: …)` one-liner path.
- **`readTimeout` enforced for real (not deferred):** `response.stream.timeout(readTimeout)` gives a true inter-byte idle bound — a gap surfaces `TimeoutException` → `transportTimeout`, and the downstream error-cancel propagation tears the connection (and owned client) down. No Story-4.3 abort handle needed, so it is implemented rather than faked. `connectTimeout` bounds `client.send().timeout(...)`.
- **`HttpAgent` (Task 4):** `class HttpAgent implements AbstractAgent` (deliberately **not** `final` — Epic-5 backends extend it). Verbatim Addendum A.2 constructor; only `url`/`client`/`interceptors`/`connectTimeout`/`readTimeout` stored; `retry`/`synthesizeChunks`/`onConnect`/`onDisconnect`/`onReconnectAttempt` accepted-but-not-stored with inline `// Consumed in Story 4.X` notes (no dead fields → no `unused_field`; unused ctor params are not lint-flagged). `run()` is one expression over the done `InterceptorChain` around a private `_TransportTerminal`, which yields the whole AC4 error contract + wires `interceptors` for free. The terminal throws `TransportError(transportClosed, statusCode:)` only for non-2xx (not an exception); all other failures propagate as stream errors the chain classifies. No platform import in `http_agent.dart`.
- **AC2 naming (RESOLVED in story):** used `io_transport.dart` (not the stale `native_transport.dart`) to match the conditional-import idiom Story 4.10 builds on.
- **Chunk synthesis (AC1 "if enabled"):** `synthesizeChunks` accepted; the synthesis transform is Story 4.8 (koel_core's `chunksStage` is private kernel machinery, not reusable here). No dead field/no-op seam — invisible end-to-end because `KoelClient`'s pipeline still synthesizes for consumers running `HttpAgent` through it.
- **Tests (Task 6):** local `HttpServer` replays 3 Epic-3 synthesized fixtures (`text_only_run`, `tool_call_basic`, `all_event_types`) — events asserted equal to `FixtureLoader.loadSynthesized(...)` (true round-trip, both decode the same payloads). Body-shape test asserts POST + `application/json` + `text/event-stream` + base64 `reasoningEcho`, plus a null-omission case. AC4 matrix via injected `MockClient`: refused (`SocketException`)→`transportRefused`, TLS (`HandshakeException`)→`transportTlsFail`, non-2xx (500)→`transportClosed`+statusCode, connect-timeout→`transportTimeout`; each asserts `.toList()` completes (nothing uncaught). Interceptor smoke test proves the chain is wired.
- **No finalization gates this story** (member `analysis_options.yaml` doc gate + ≥90% coverage gate are Story 4.10's), matching the 4.1 precedent. Full dartdoc written anyway so 4.10's doc gate needs no backfill.

### File List

- `packages/koel_http/pubspec.yaml` — MODIFY (added `http: ^1.6.0` to `dependencies`; `koel_test` to `dev_dependencies` for fixture reuse)
- `packages/koel_http/lib/koel_http.dart` — MODIFY (export `http_agent.dart` + `connection/reconnect_policy.dart`)
- `packages/koel_http/lib/src/http_agent.dart` — NEW (`HttpAgent` + private `_TransportTerminal`)
- `packages/koel_http/lib/src/wire/run_agent_input_codec.dart` — NEW (hand-written `RunAgentInput` → JSON, base64 `reasoningEcho`)
- `packages/koel_http/lib/src/transport/transport.dart` — NEW (`Transport` interface + `TransportResponse` + conditional `createTransport()` selector)
- `packages/koel_http/lib/src/transport/io_transport.dart` — NEW (real native transport via `http.Client.send`)
- `packages/koel_http/lib/src/transport/web_transport.dart` — NEW (throwing stub; real impl Story 4.10)
- `packages/koel_http/lib/src/transport/transport_stub.dart` — NEW (default-platform throwing fallback)
- `packages/koel_http/lib/src/connection/reconnect_policy.dart` — NEW (minimal `RetryPolicy` data holder; behavior Story 4.4)
- `packages/koel_http/lib/src/error/error_classifier.dart` — NEW (review) — conditional-import seam exposing `transportErrorClassifier()`; platform-free
- `packages/koel_http/lib/src/error/error_classifier_stub.dart` — NEW (review) — non-native fallback → `DefaultErrorClassifier`
- `packages/koel_http/lib/src/error/io_error_classifier.dart` — NEW (review) — `TransportErrorClassifier` (`dart:io` `is` checks; sees through `_ClientSocketException`) + native factory
- `packages/koel_http/lib/src/http_agent.dart` — MODIFY (review) — wire `transportErrorClassifier()`; drain body on non-2xx before throw
- `packages/koel_http/lib/src/transport/io_transport.dart` — MODIFY (review) — nullable subscription guard
- `packages/koel_http/test/http_agent_test.dart` — NEW + MODIFY (review) — SSE-server happy path + body shape + error matrix + interceptor smoke; refused test de-masked to real loopback `IOClient`; added `readTimeout` idle-gap test

## Change Log

| Date | Version | Description | Author |
| ---- | ------- | ----------- | ------ |
| 2026-05-31 | 0.1.0 | Story drafted — ultimate context engine analysis completed; comprehensive developer guide created | create-story |
| 2026-05-31 | 0.2.0 | Implemented `HttpAgent` + wire codec + conditional-import transport seam (io real / web+stub throwing) + minimal `RetryPolicy`; `run()` composed over `InterceptorChain`; 10-test suite (AC1/AC3/AC4 + interceptor wiring); analyze/format/test green workspace-wide. Status → review. | dev-story |
| 2026-05-31 | 0.3.0 | Adversarial code review (Blind Hunter + Edge Case Hunter + Acceptance Auditor). 1 decision-needed, 3 patch, 2 defer, 5 dismissed. Two verified correctness defects against AC4. | bmad-code-review |
| 2026-05-31 | 0.4.0 | Applied all 4 patches: koel_http `TransportErrorClassifier` behind a `dart.library.io` seam (real-IOClient connection-refused now → `transportRefused`, AC4 truly satisfied); drain body on non-2xx (socket-leak fix); nullable subscription guard; de-masked refused test + new `readTimeout` idle-gap test. analyze/format/test green workspace-wide (koel_http 35 tests). Status → done. | bmad-code-review |

### Review Findings

_Adversarial review 2026-05-31 (3 layers). Baseline `de83934`. Both correctness findings verified against `package:http` 1.6.0 source + `DefaultErrorClassifier`, not speculation._

- [x] [Review][Patch] **(RESOLVED → approach a; FIXED) Real native connection-refused mis-classifies to `unknown`/`AgentError`, not `transportRefused`/`TransportError` (AC4 gap)** — _Fix: added `TransportErrorClassifier extends DefaultErrorClassifier` (`lib/src/error/io_error_classifier.dart`) using real `is SocketException`/`is TlsException` checks, behind a `dart.library.io` conditional-import seam (`error_classifier.dart` selector + `error_classifier_stub.dart` fallback) so `http_agent.dart` stays platform-free; `run()` now builds the chain over `transportErrorClassifier()`. De-masked the refused test to a real loopback ECONNREFUSED through the default `IOClient` — it now exercises (and passes through) the `_ClientSocketException` wrapper._ — On the real native path the injected/default `IOClient` catches a `SocketException` and rethrows it as `_ClientSocketException` (http 1.6.0 `io_client.dart:226-227`; concrete `runtimeType` = `"_ClientSocketException"`). `DefaultErrorClassifier` switches on the *exact* `raw.runtimeType.toString()` (`error_classifier.dart:69-89`), so both `'SocketException'` and `'ClientException'` miss → `default` → `AgentError(KoelErrorCode.unknown)`. AC4 requires `RunErrorEvent(TransportError(transportRefused))`. The AC4 test (`http_agent_test.dart:177`) throws a **raw** `SocketException` via `MockClient`, which matches by name and masks the gap. TLS is unaffected (`HandshakeException` is not wrapped by `IOClient`). The spec's Dev Note ("`DefaultErrorClassifier` is correct for 4.2") is falsified by this wrapper. _Decision required: (a) ship a koel_http `ErrorClassifier` subclass using real `is SocketException`/`is HandshakeException` checks (koel_http may import `dart:io`/`package:http`); (b) re-wrap in `io_transport`'s catch into typed `TransportError` before it reaches the classifier; or (c) accept the gap, defer to a later story, and de-mask the test so it stops giving false confidence._
- [x] [Review][Patch] **(FIXED) Non-2xx response leaks the owned `http.Client`/socket** [packages/koel_http/lib/src/http_agent.dart:122; packages/koel_http/lib/src/transport/io_transport.dart:46-99] — _Fix: `_TransportTerminal.run` now `await response.body.drain<void>()` (errors swallowed deliberately, with the throw as the reported path) before throwing on non-2xx, driving the transport's owned-client teardown._ — With a default (owned) client and a non-2xx status, `IoTransport.connect` returns the `_closingOnTeardown`-wrapped body without inspecting status; `_TransportTerminal.run` then throws `TransportError` **before** `yield* parse(response.body)`, so the wrapped stream is never subscribed → `onListen`/`onCancel` never fire → `closeClient()` never runs → the IOClient socket/connection pool leaks on every error response (401/404/429/500…). Untested: the non-2xx test injects a `MockClient` (buffered, owned==false branch). Fix: drain/cancel `response.body` before throwing on non-2xx (e.g. `await response.body.drain<void>().catchError((_) {})`).
- [x] [Review][Patch] **(FIXED) `late StreamSubscription` unguarded against a synchronous `onListen` throw** [packages/koel_http/lib/src/transport/io_transport.dart:69,88-96] — _Fix: changed `late StreamSubscription` to a nullable field with `?.` guards in `onPause`/`onResume`/`onCancel`, removing the `LateInitializationError` masking path._ — `subscription` is `late`, assigned inside `onListen` after `source.listen(...)`. If that listen throws synchronously, `subscription` is never assigned, yet `onCancel`/`onPause`/`onResume` access it → `LateInitializationError` masks the real error. Low likelihood with http's async stream, but cheap to harden (guard with the existing `closed` flag or a nullable subscription).
- [x] [Review][Patch] **(FIXED) `readTimeout` inter-byte idle path has no test** [packages/koel_http/test/http_agent_test.dart] — _Fix: added an AC4 test where a loopback server flushes headers + an SSE keepalive comment then stalls; the inter-byte gap trips `response.stream.timeout(readTimeout)` → terminal `RunErrorEvent(transportTimeout)`._ — The story claims `readTimeout` is "enforced for real" via `response.stream.timeout(readTimeout)`, but the only `transportTimeout` assertion is driven by `connectTimeout`. Add a stalling-byte-stream test so the inter-byte idle bound is locked by a test, not by inspection.
- [x] [Review][Defer] **`connectTimeout` orphans an in-flight `send()` on an injected client** [packages/koel_http/lib/src/transport/io_transport.dart:38-57] — deferred: when `connectTimeout` fires, `Future.timeout` does not cancel the underlying `send()`; for an owned client the catch closes it, but an injected client's request is left in flight with no active abort. The abort handle is explicitly Story 4.3's concern (`transport.dart:48-49`).
- [x] [Review][Defer] **Trap #5 subclass-reachability: `_client`/`_interceptors` are library-private** [packages/koel_http/lib/src/http_agent.dart] — deferred: Epic-5 cross-package subclasses (`AgnoAgent`/`LangGraphAgent` in their own packages) cannot reach the transport seam (`_`-privacy is library-scoped; Dart has no `protected`). No 4.2 AC requires it; revisit the extension surface when those backends actually land.

_Dismissed as noise (5): deferred ctor params not stored as fields (by design — trap #7, documented, analyzer-clean); `readTimeout` per-event idle reset (intended & documented semantics); base64 `reasoningEcho` >255 corruption / empty-map omission (`Uint8List` guarantees bytes; omit-when-empty is spec-mandated); `client.close()` fire-and-forget error swallow (acceptable); web/stub transports throw at runtime not compile time (deliberate stub)._
