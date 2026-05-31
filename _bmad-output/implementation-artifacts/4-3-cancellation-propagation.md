---
baseline_commit: d7741d7cafe277cd7055ba42deff4e1c3b2501d5
---

# Story 4.3: Cancellation propagation with TCP abort

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

> **Dev agent:** this is **Story 4.3 of Epic 4** (HTTP transport, `koel_http`). It turns `HttpAgent` (Story 4.2) from "streams until done/error" into "streams until done/error **or the consumer cancels**" — with a measured < 50 ms TCP abort, a silent-drop fallback for clients that ignore abort, and a one-shot warning. It touches `.dart` files and the package's transport seam, so **invoke `/agent-flutter-engineer` before producing any code** (per [CLAUDE.md](CLAUDE.md)). `packages/koel_http/` already ships `SseParser` (4.1) and `HttpAgent` + the conditional-import transport seam (4.2). You are **not** building new transport plumbing — you are making the existing cancel path *fast, explicit, and observable*. **Six things are load-bearing, and the first three are traps that will sink a naïve reading of the AC:**
>
> 1. **Cancellation ALREADY propagates end-to-end — do NOT re-plumb it.** The chain built in 4.2/2.9 carries `cancel()` from the consumer's `Stream<AgUiEvent>` down to the transport byte stream *for free*: consumer cancels `HttpAgent.run()` → `InterceptorChain`'s transformer is a **plain pipe** that forwards cancel untouched ([interceptor.dart:116-117](packages/koel_core/lib/src/agent/interceptor.dart#L116-L117)) → `_TransportTerminal.run()` is `async*` paused on `yield* SseParser().parse(response.body)`, and cancelling an `async*` generator on a `yield*` cancels the inner stream → `SseParser`'s stream cancels its upstream → `response.body` subscription cancels → on the **owned**-client path `_closingOnTeardown.onCancel` already calls `client.close()` ([io_transport.dart:97-100](packages/koel_http/lib/src/transport/io_transport.dart#L97-L100)). **The mechanism exists.** This story adds the *guarantee* (measured < 50 ms), the *injected-client* abort, the *silent-drop* guard, and the *abort-not-honored warning* — it does **not** rebuild the propagation path. [Source: AC :67-71; interceptor.dart:116-117; io_transport.dart:64-102]
> 2. **`package:http`'s `http.Client` does NOT expose `HttpClientRequest.abort()` — and you must NOT rewrite the transport to raw `dart:io` to reach it.** AC1 names "`HttpClientRequest.abort()` (`dart:io`) **or** `Client.close()`" — note the **or**. You only reach `HttpClientRequest.abort()` by hand-rolling a raw `dart:io HttpClient`, which Story 4.2 deliberately rejected: it would break the `http.Client? client` injectability AC **and** AC2's verified-client matrix (which tests `IOClient`, `BrowserClient`, and a wrapped client — all `package:http` types). Addendum C.2 gives the two as **alternatives** ([addendum.md:536](../planning-artifacts/prds/prd-koel-2026-05-27/addendum.md)): on the `package:http` native path the abort primitive is **`Client.close()` on the per-request (owned) client** + **subscription-cancel on the live response stream** (on `IOClient`, cancelling the response-stream subscription destroys the socket → TCP close). `HttpClientRequest.abort()` is the *web/raw* alternative — **not** this story's path. Keep `io_transport.dart` on `package:http`. [Source: AC :69; addendum.md:530-540; 4-2 trap #3]
> 3. **`RunPhase.cancelled` is ALREADY produced by `ChatSession.cancel()` (Story 2.14) — koel_http has NO reducer; do NOT re-implement it.** AC4 ("reducer → `ChatState.phase == RunPhase.cancelled` regardless of TCP outcome") is satisfied by the existing session seam: `ChatSession.cancel()` calls `_sub?.cancel()` (which fires the transport abort via trap #1) **and** synchronously `_emit(copyWith(phase: RunPhase.cancelled))` — *regardless of any TCP outcome* ([chat_session.dart:114-122](packages/koel_core/lib/src/client/chat_session.dart#L114-L122)). The reducer **never invents** `cancelled`; the session synthesizes it (there is no cancel *event* — [chat_state.dart:14-17](packages/koel_core/lib/src/state/chat_state.dart#L14-L17)). AC4 is therefore an **end-to-end verification** (wire `HttpAgent` into a `KoelClient`/`ChatSession`, `send`, `cancel`, assert phase), **not** new state logic in `koel_http`. [Source: AC :81-83; chat_session.dart:114-122; chat_state.dart:14-17]
> 4. **`package:logging` is a NEW dependency — no package uses it yet.** Verified: zero `package:logging` imports and zero `logging:` pubspec entries across the monorepo. The abort-not-honored warning (AC3) is the first use. Add `logging: ^1.3.0` (latest stable) to `koel_http/pubspec.yaml` `dependencies`. Architecture §4 mandates `package:logging` exclusively — **no `print`** ([architecture.md:587](../planning-artifacts/architecture.md)). [Source: AC :79; architecture.md:587-593; grep verification]
> 5. **The warning is `Level.WARNING`, runtime-once, emits exactly once per process — and is a DIFFERENT log from the normal cancellation drop.** Architecture §4's log table is explicit: `Level.FINE` = "per-event tracing, **cancellation TCP-abort drops**" (the *normal* case, owned by Story 4.6's `LoggingInterceptor`); `Level.WARNING` = "single debug **warnings (e.g., abort-not-honored)**" ([architecture.md:588-591](../planning-artifacts/architecture.md)). This story emits **only** the exceptional `Level.WARNING` abort-not-honored warning, gated by a **library-private mutable flag** flipped on first emission so it logs once per process across many cancellations (AC3). Do **not** emit a per-cancellation `Level.FINE` trace here — that is Story 4.6. [Source: AC :79; architecture.md:587-593]
> 6. **`BrowserClient` cannot run on the VM — its matrix row defers to Story 4.10.** AC2 lists `BrowserClient`, but it imports `package:web`/`dart:html` (un-loadable on the VM) **and** koel_http's `web_transport.dart` is a throwing stub until Story 4.10, which owns web transport + `AbortController` ↔ `cancel()` (< 50 ms, AR-23 / Gap G-1 — [epic-4 4.10 :246-251](../planning-artifacts/epics/epic-4-http-transport-koelhttp.md), [architecture.md:1198-1202](../planning-artifacts/architecture.md)). **RESOLVED:** `cancellation_test.dart`'s matrix covers the native-reachable clients (default `http.Client()`, explicit `IOClient`, custom interceptor-wrapped client); the `BrowserClient`/web-AbortController row is a documented `// Story 4.10 (G-1)` deferral, not a native test. [Source: AC :73-75; epic-4 4.10 :246-251; architecture.md:1198-1202]

## Story

As a Flutter/Dart developer,
I want `StreamSubscription.cancel()` on the event stream to propagate to an HTTP-level abort (TCP close) within < 50 ms, with a silent-drop fallback + single debug warning for clients not honoring abort,
so that consumer-initiated cancellation satisfies AG-UI's TCP-close-only cancellation semantics per FR-B3 + NFR-8 + Addendum C.2.

## Acceptance Criteria

Verbatim from [epic-4 Story 4.3](../planning-artifacts/epics/epic-4-http-transport-koelhttp.md) (lines 59-83):

1. **Given** an `HttpAgent` connected to a long-running SSE stream (one event per 100 ms), **When** the consumer cancels the subscription mid-stream, **Then** the underlying `HttpClientRequest.abort()` (`dart:io`) or `Client.close()` invokes within 50 ms, **And** no further events emit after cancellation, **And** the time between `cancel()` call and TCP-close observation < 50 ms per NFR-8 (measured by test).

2. **Given** the verified-client matrix `koel_http/test/cancellation_test.dart`, **When** I run it, **Then** it asserts cancel propagation against: default `http.Client()`, `IOClient`, browser `BrowserClient`, and a custom interceptor-wrapped client.

3. **Given** a `MockHttpClient` that intentionally does not honor `close()`, **When** the consumer cancels, **Then** `koel_http` falls back to silent drop with one `Level.WARNING` log via `package:logging` per the runtime-once flag (verified the warning emits exactly once per process across multiple cancellation events with that client) per Addendum C.2.

4. **Given** the cancellation, **When** the reducer processes the subsequent state, **Then** `ChatState.phase == RunPhase.cancelled` regardless of TCP outcome per FR-A11 + Addendum C.2.

> **AC clarifications (RESOLVED — do not re-litigate, implement):**
>
> - **AC1 "`HttpClientRequest.abort()` … or `Client.close()`":** on the `package:http` native path you have **`Client.close()`** (owned/per-request client) and **response-stream-subscription cancel** (which on `IOClient` destroys the socket → TCP close). `HttpClientRequest.abort()` is unreachable through `package:http`'s `http.Client` and is the *web/raw* alternative — **not** built here (trap #2). The "< 50 ms TCP-close observation" is measured **server-side**: a loopback `HttpServer` notes when its request connection closes after the consumer's `cancel()` (the deterministic, transport-agnostic observation point); an instrumented owned/wrapped client may additionally record the `close()` timestamp. [Source: AC :69-71; addendum.md:536]
> - **AC1 "no further events emit after cancellation":** this is the **silent-drop guarantee** and must hold *even for a client that ignores abort*. Achieve it by interposing a koel_http-owned teardown wrapper around the live byte stream (extend 4.2's `_closingOnTeardown` to cover the **injected**-client path too — currently injected streams return `bounded` raw, [io_transport.dart:46-51](packages/koel_http/lib/src/transport/io_transport.dart#L46-L51)). Once `onCancel` fires, the wrapper's controller is torn down so nothing forwards downstream — independent of whether the socket actually closed. [Source: AC :70; io_transport.dart:46-51,64-102]
> - **AC2 matrix scope:** `default http.Client()` + explicit `IOClient` + custom interceptor-wrapped client run natively; **`BrowserClient` defers to Story 4.10** (trap #6). The "custom interceptor-wrapped client" is an **`http.Client` decorator** (a `BaseClient` subclass delegating `send` to an inner client) — **not** a koel `Interceptor`; assert cancel still propagates through the decorator. [Source: AC :73-75; epic-4 4.10]
> - **AC3 "MockHttpClient that does not honor `close()`":** model it as an `http.Client` whose response body is a long-lived stream that keeps emitting (or whose `close()` is a no-op) so abort has no effect on the upstream. koel_http detects non-honoring (the upstream did not terminate within the abort budget after `onCancel`), **silent-drops** (controller already torn down → consumer sees nothing more), and logs the **single** `Level.WARNING` gated by the runtime-once flag. The test drives **multiple** cancellations through that client and asserts **exactly one** record was emitted process-wide (capture via `Logger.root.onRecord`). [Source: AC :77-79; architecture.md:590-591]
> - **AC4 verification:** koel_http already depends on `koel_core`, so test end-to-end: `KoelClient(agent: HttpAgent(url: …)).newSession()`, `session.send(...)` against a long-running loopback SSE server, `session.cancel()`, then assert the emitted `ChatState.phase == RunPhase.cancelled` (read via `session.stream` or `session.state`). The phase is set by the session seam **regardless of TCP outcome** — assert it holds even against the non-honoring client. Do **not** add reducer/phase logic to koel_http (trap #3). [Source: AC :81-83; chat_session.dart:56,114-122; koel_client.dart:62-72,153]

## Tasks / Subtasks

- [x] **Task 0 — Read the real surfaces before writing a line** (AC: all — skipping this builds the wrong contract)
  - [x] Re-read [io_transport.dart](packages/koel_http/lib/src/transport/io_transport.dart) **in full** — the owned-client teardown wrapper `_closingOnTeardown` (lines 64-102): a `sync` `StreamController`, nullable `subscription`, `closeClient()` once-guard, and `onCancel: () { closeClient(); return subscription?.cancel(); }`. **Injected** clients bypass this wrapper and return `bounded` raw (line 49). This asymmetry is what AC1's silent-drop guarantee forces you to close. [Source: io_transport.dart:31-102]
  - [x] Re-read [transport.dart](packages/koel_http/lib/src/transport/transport.dart) — the `Transport` interface + `TransportResponse` (statusCode + live `body`). Note the dartdoc on `TransportResponse` (lines 45-49): *"a connection abort/close handle (for sub-50ms cancellation) is Story 4.3's concern and is added when that story actually uses it."* **This story adds it.** [Source: transport.dart:45-59]
  - [x] Re-read [http_agent.dart](packages/koel_http/lib/src/http_agent.dart) — `_TransportTerminal.run()` (lines 109-145): `async*`, `Transport().connect(...)`, non-2xx throw + drain, then `yield* const SseParser().parse(response.body)`. The cancel-on-`yield*` propagation (trap #1) flows through here. [Source: http_agent.dart:104-146]
  - [x] Read [interceptor.dart](packages/koel_core/lib/src/agent/interceptor.dart) lines 60-137 — confirm `proceed`'s transformer is a plain pipe that forwards cancel untouched ("There is no `RunErrorEvent` on cancel — a cancelled run is not a failed one", lines 65-67). This is why cancel reaches your transport without you wiring anything in the chain. [Source: interceptor.dart:60-137]
  - [x] Read [chat_session.dart](packages/koel_core/lib/src/client/chat_session.dart) lines 56-122 — `send()` subscribes `agent.run(input)`; `cancel()` does `_sub?.cancel()` **then** `_emit(copyWith(phase: RunPhase.cancelled))` **then** `_complete()`. This is AC4, already built. Read `KoelClient.newSession` ([koel_client.dart:153](packages/koel_core/lib/src/client/koel_client.dart#L153)) for the test wiring. [Source: chat_session.dart:56-122; koel_client.dart:153]
  - [x] Read [chat_state.dart](packages/koel_core/lib/src/state/chat_state.dart) lines 11-33 — `RunPhase.cancelled` exists; "the reducer never invents `cancelled` itself — the cancellation seam sets it." Do not duplicate. [Source: chat_state.dart:11-33]
  - [x] Read Addendum C.2 ([addendum.md:530-540](../planning-artifacts/prds/prd-koel-2026-05-27/addendum.md)) + architecture §4 cancellation ([architecture.md:573-593](../planning-artifacts/architecture.md)) — the canonical contract: `cancel()` → `Client.close()` **or** `HttpClientRequest.abort()`; non-honoring → silent drop + one runtime-once-gated `package:logging` warning; reducer → `RunPhase.cancelled` immediately. [Source: addendum.md:530-540; architecture.md:573-593]

- [x] **Task 1 — Add `package:logging` dependency** (AC: #3)
  - [x] In [koel_http/pubspec.yaml](packages/koel_http/pubspec.yaml) (MODIFY) add `logging: ^1.3.0` under `dependencies:` (verify latest stable on pub.dev at implementation time). Keep `koel_core:`, `http: ^1.6.0`, and the existing `dev_dependencies`. This is the **first** `package:logging` use in the monorepo. [Source: trap #4; architecture.md:587]
  - [x] Run `dart pub get` from the workspace root; confirm `koel_http` resolves `logging`. [Source: root pubspec workspace resolution]

- [x] **Task 2 — Add the abort handle to the transport seam** (AC: #1, #2)
  - [x] In [transport.dart](packages/koel_http/lib/src/transport/transport.dart) (MODIFY) add an abort primitive to `TransportResponse`, e.g. `final Future<void> Function() abort;` (a zero-arg async close/abort handle the consumer-cancel path invokes for an *explicit, prompt* TCP teardown rather than relying solely on implicit subscription-cancel). Update the dartdoc (replace the "added in Story 4.3" deferral note with the real contract: "calling [abort] closes the underlying connection — `Client.close()` on an owned client, response-subscription cancel on an injected one; idempotent; safe after the stream is already done"). Web (Story 4.10) will supply `AbortController.abort()` here. [Source: AC :69; transport.dart:45-59; addendum.md:536]
  - [x] Keep the interface forward-compatible: the abort handle is what `web_transport.dart` (4.10) populates with `AbortController.abort()`, so its shape must not assume `dart:io`. A `Future<void> Function()` is platform-neutral. [Source: epic-4 4.10 :246-251]

- [x] **Task 3 — Make `io_transport` abort fast, explicit, and symmetric** (AC: #1, #2, #3)
  - [x] In [io_transport.dart](packages/koel_http/lib/src/transport/io_transport.dart) (MODIFY) **wrap the injected-client path too** — currently only the owned path goes through `_closingOnTeardown` ([io_transport.dart:47-49](packages/koel_http/lib/src/transport/io_transport.dart#L47-L49)); the injected path returns `bounded` raw, so on cancel there is no koel-owned controller to guarantee silent-drop. Generalize the wrapper so **every** response (owned or injected) is wrapped: on cancel it cancels the internal upstream subscription (→ socket teardown on honoring clients) and, **only when owned**, also `client.close()`. [Source: AC :70; io_transport.dart:46-102]
  - [x] Expose an `abort` callback from `connect()` that the wrapper closes over — cancel the internal subscription + (owned) close the client. Populate `TransportResponse.abort` with it. Make it **idempotent** (reuse the existing `closed` once-guard) and **prompt** (no awaits before the cancel/close calls fire, so the < 50 ms budget is met). [Source: AC :69-71; io_transport.dart:73-78]
  - [x] **Non-honoring detection + silent drop + warn-once:** after `abort`/`onCancel` fires, if the upstream subscription does not terminate within the abort budget (the upstream keeps the socket alive / keeps delivering bytes), guarantee silent-drop (the torn-down controller forwards nothing) and emit the **single** `Level.WARNING` via a `Logger` (e.g. `Logger('koel_http.cancellation')`), gated by a **library-private** `bool` flipped on first emission. Choose a deterministic detection signal (e.g. the internal subscription's `cancel()` future does not complete within the budget, or bytes arrive post-cancel) and document it; keep the timer/race off the consumer's `onCancel` return path so cancel completion is not delayed. [Source: AC :77-79; architecture.md:590-591]
  - [x] Preserve all 4.2 invariants: single-subscription, pause/resume pass-through (backpressure to socket), no double-close, no socket leak on owned-client teardown (drain/error/cancel all close exactly once). Do **not** regress the `readTimeout` inter-byte idle bound or the non-2xx drain. [Source: io_transport.dart:60-102; 4-2 review fixes]

- [x] **Task 4 — Wire consumer-cancel to the abort handle in `HttpAgent`** (AC: #1, #4)
  - [x] In [http_agent.dart](packages/koel_http/lib/src/http_agent.dart) (MODIFY) make `_TransportTerminal.run()` invoke `response.abort()` when its own subscription is cancelled, so the TCP teardown is **explicit and prompt** rather than depending only on the implicit `yield*` cancel reaching the socket. Idiomatic shape: replace the bare `yield* SseParser().parse(response.body)` with a small wrapper (e.g. a `StreamController`/`StreamTransformer` whose `onCancel` calls `response.abort()` then cancels the parse subscription) — mirror koel_core's `buildStage` controller pattern ([stage_support.dart:40-76](packages/koel_core/lib/src/pipeline/stage_support.dart#L40-L76)) for cancel/backpressure correctness. Keep `http_agent.dart` **platform-free** (no `dart:io`); the abort handle is already platform-neutral from Task 2. [Source: AC :69-71; stage_support.dart:40-76; 4-2 trap: no platform import in http_agent.dart]
  - [x] Verify the non-2xx path (already drains, [http_agent.dart:126-142](packages/koel_http/lib/src/http_agent.dart#L126-L142)) and the happy/error paths still hold — the cancel wrapper must not swallow the terminal `RunErrorEvent` or alter wire-order on a normal run. [Source: http_agent.dart:109-145]
  - [x] **AC4 needs no koel_http change** — confirm by the integration test (Task 5) that `ChatSession.cancel()` flips to `RunPhase.cancelled`. If a code change in koel_http were required for AC4, you have mis-read trap #3. [Source: chat_session.dart:114-122]

- [x] **Task 5 — `cancellation_test.dart` (the verified-client matrix + timing + fallback + phase)** (AC: #1, #2, #3, #4)
  - [x] New `packages/koel_http/test/cancellation_test.dart` (the AC2-named file; `package:test`; mirror the existing `http_agent_test.dart` helper style — ephemeral loopback `HttpServer`, `addTearDown`). [Source: AC :73; http_agent_test.dart helpers]
  - [x] **Long-running SSE server helper:** a loopback `HttpServer` that writes one SSE event per 100 ms and **keeps the connection open**, exposing a `Future`/`Completer` that completes when the server observes the request connection close (the < 50 ms TCP-close measurement point). [Source: AC :67-71]
  - [x] **AC1 timing:** start a run, cancel the subscription mid-stream (after ≥1 event), assert (a) no further events arrive after cancel, and (b) the server-observed connection-close happens within 50 ms of `cancel()` (`Stopwatch`). Allow a small CI-tolerance margin but keep the assertion meaningful (< 50 ms target per NFR-8). [Source: AC :67-71; NFR-8]
  - [x] **AC2 matrix:** parameterize the cancel-propagation assertion over `[default http.Client(), IOClient(), <wrapped client>]`. The wrapped client is a `BaseClient` decorator delegating `send` to an inner `IOClient` (assert cancel still reaches the socket through it). Add a **`BrowserClient` row deferred** with a comment citing Story 4.10 / Gap G-1 (do not instantiate it natively). [Source: AC :73-75; trap #6]
  - [x] **AC3 fallback:** a non-honoring `http.Client` (e.g. `MockClient.streaming` returning a stream that keeps emitting / whose close is a no-op). Drive **multiple** cancellations through it; assert the consumer sees **no events after cancel** each time (silent drop), and that **exactly one** `Level.WARNING` record was captured **process-wide** via `Logger.root.onRecord` (the runtime-once flag). Reset the captured log between unrelated tests but **not** the process-once flag (its once-ness is the assertion). [Source: AC :77-79]
  - [x] **AC4 phase:** `KoelClient(agent: HttpAgent(url: <long-running server>)).newSession()`; `session.send('hi')`; await ≥1 state; `session.cancel()`; assert the emitted `ChatState.phase == RunPhase.cancelled`. Repeat against the non-honoring client to prove "regardless of TCP outcome". [Source: AC :81-83; koel_client.dart:153; chat_session.dart:56,118]
  - [x] `dart:io` in the **test** file is fine (web-safety governs `lib/` only — 4.1/4.2 precedent). [Source: 4-2 AC3 clarification]

- [x] **Task 6 — Quality gates (NO finalization gates this story)** (AC: all)
  - [x] `melos run analyze` → **0 issues** workspace-wide. Watch for an `unused_field`/`unused_element` trap if you stage abort scaffolding you do not yet read — wire it or omit it (CLAUDE.md "no vestigial code"). [Source: NFR-13]
  - [x] `melos run test` → green workspace-wide, including the new `cancellation_test.dart` and the unchanged `http_agent_test.dart`/`sse_parser_test.dart`. [Source: tool/test_package.sh]
  - [x] `melos run format:check` → clean. [Source: tool/format.sh]
  - [x] **Do NOT** add koel_http's member `analysis_options.yaml` doc gate or the ≥ 90 % coverage gate — those are **package-finalization** gates that land in the epic-sealing **Story 4.10** (4.1/4.2 precedent). Write full dartdoc anyway so 4.10's doc gate needs no backfill. [Source: epic-4 overview; 4-1/4-2 design decisions]

## Dev Notes

### What this story is, in one paragraph

The story that makes `HttpAgent` cancellable *for real*. Story 4.2 already wired the cancel *path* (consumer `cancel()` → `yield*` → byte-stream subscription cancel → owned-client close), but only the owned-client branch tears down explicitly, the timing is unmeasured, an injected client's response stream returns raw with no koel-owned silent-drop guard, and there is no fallback for a client that ignores abort. Story 4.3 adds four things and **no new plumbing**: (1) an **abort handle** on `TransportResponse` that `io_transport` populates (owned → `Client.close()`, injected → response-subscription cancel) and that web (4.10) will fill with `AbortController.abort()`; (2) **`HttpAgent` invokes that handle** on consumer-cancel for a prompt, explicit, **< 50 ms** TCP abort (measured server-side); (3) a **silent-drop guarantee** by wrapping *every* response (owned + injected) in a koel-owned teardown controller so no event ever emits after cancel — even from a non-honoring client; (4) a **one-shot `Level.WARNING`** (runtime-once-gated, `package:logging`) when abort is not honored. AC4 (`RunPhase.cancelled`) is **already** delivered by `ChatSession.cancel()` (Story 2.14) and is only *verified* end-to-end here. Scope is **native-only**; the `BrowserClient`/web-`AbortController` matrix row is **Story 4.10**.

### The cancel path already exists — this story refines it (RESOLVED — the design crux)

Do not re-build propagation. The full chain, top to bottom:

1. Consumer cancels the subscription to `HttpAgent.run(input)`.
2. `InterceptorChain.proceed`'s transformer is a **plain pipe** — cancel forwards untouched, no `RunErrorEvent` on cancel ([interceptor.dart:65-67,116-117](packages/koel_core/lib/src/agent/interceptor.dart#L65-L117)).
3. `_TransportTerminal.run()` is `async*`, paused on `yield* SseParser().parse(response.body)`; cancelling the generator cancels the inner (`SseParser`) stream.
4. `SseParser` cancels its upstream → the transport `response.body` subscription cancels.
5. On the **owned** path, `_closingOnTeardown.onCancel` already `client.close()`s ([io_transport.dart:97-100](packages/koel_http/lib/src/transport/io_transport.dart#L97-L100)).

What 4.3 changes: make step 3 *also* call `response.abort()` (explicit + prompt, not waiting for the implicit cancel to reach the socket through 2 stream layers), and make step 4's wrapper cover the **injected** path so silent-drop is guaranteed regardless of client behavior. The timing budget (< 50 ms) is about removing latency from this path — keep the abort calls synchronous-ish (no awaits in front of them) so the socket teardown is initiated immediately on `onCancel`.

### Why not raw `dart:io HttpClient` / `HttpClientRequest.abort()` (RESOLVED)

AC1 names `HttpClientRequest.abort()`, but that handle lives on `dart:io`'s raw request object, which `package:http`'s `IOClient` **hides**. Reaching it means abandoning `package:http` for a hand-rolled `dart:io HttpClient` — which **breaks** Story 4.2's `http.Client? client` injectability AC and **AC2's own matrix** (which tests `IOClient`, `BrowserClient`, wrapped clients — all `package:http` abstractions). Addendum C.2 lists the two abort primitives as **alternatives** ("`Client.close()` … *or* `HttpClientRequest.abort()`", [addendum.md:536](../planning-artifacts/prds/prd-koel-2026-05-27/addendum.md)). On the `package:http` path you use `Client.close()` (owned) + response-subscription cancel (injected, which destroys the `IOClient` socket → TCP close). `HttpClientRequest.abort()` is the **web/raw** alternative and is **Story 4.10**'s concern (via `AbortController`). Stay on `package:http`.

### `RunPhase.cancelled` is already done (RESOLVED — do NOT duplicate)

`ChatSession.cancel()` ([chat_session.dart:114-122](packages/koel_core/lib/src/client/chat_session.dart#L114-L122)) is the cancellation *seam* the reducer dartdoc refers to:

```dart
void cancel() {
  _sub?.cancel();                                    // → transport abort (this story)
  _emit(_state.copyWith(phase: RunPhase.cancelled)); // AC4, synchronous, TCP-outcome-independent
  _complete();
}
```

The reducer **never** produces `cancelled` from an event — there is no `RUN_CANCELLED` event ([chat_state.dart:14-17](packages/koel_core/lib/src/state/chat_state.dart#L14-L17)). So AC4 is an **integration assertion** in koel_http (it depends on koel_core): build a `KoelClient` over `HttpAgent`, `send`, `cancel`, assert phase. **No reducer/phase code belongs in koel_http.** If you find yourself adding `RunPhase` logic to `koel_http`, stop — you have mis-read this.

### Silent drop + the one-shot warning (RESOLVED — the only genuinely new behavior)

Two distinct logs, do not conflate (architecture §4, [architecture.md:587-593](../planning-artifacts/architecture.md)):

| Case | Level | Owner |
| ---- | ----- | ----- |
| Normal cancellation TCP-abort drop (per-event trace) | `Level.FINE` | **Story 4.6** (`LoggingInterceptor`) — *not here* |
| Abort **not honored** by the client (fallback) | `Level.WARNING` | **This story** |

The fallback path: a client whose `close()`/subscription-cancel does not actually tear down the upstream (it keeps the socket alive / keeps emitting). koel_http cannot force such a client to release a socket, so it (a) **silent-drops** — the koel-owned teardown controller is closed on `onCancel`, so nothing reaches the (already-gone) consumer regardless of upstream behavior; (b) emits **one** `Level.WARNING` (`Logger('koel_http.cancellation')`, message naming "client did not honor abort"), gated by a **library-private** `var _abortNotHonoredWarned = false;` flipped on first emission so it logs **once per process** across any number of cancellations (AC3's "runtime-once flag"). Pick a deterministic non-honoring signal (the internal subscription's `cancel()` future not completing within the abort budget, or post-cancel bytes) and keep the detection **off** the consumer's `onCancel`-return path so the consumer's `cancel()` completes promptly. Test it by driving multiple cancellations through one non-honoring client and asserting `Logger.root.onRecord` captured exactly one `WARNING`.

### Out of scope — do NOT build these (RESOLVED)

- **Web transport cancellation** (`package:web` fetch + `ReadableStream` + `AbortController.abort()` ↔ `cancel()`, < 50 ms) + the `BrowserClient` matrix row → **Story 4.10** (AR-23 / Gap G-1). `web_transport.dart` stays a throwing stub; the `TransportResponse.abort` handle you add is the seam it will fill.
- **`RunPhase.cancelled` / reducer / session logic** → already **Story 2.14** ([chat_session.dart:118-122](packages/koel_core/lib/src/client/chat_session.dart#L118-L122)); only *verify* here.
- **Per-event `Level.FINE` cancellation trace** + `LoggingInterceptor`/`EventTraceInterceptor` → **Story 4.6**. This story emits only the exceptional `Level.WARNING` abort-not-honored log.
- **Retry / reconnect / backoff** → **Story 4.4**; **chunk synthesis** → **4.8**; **lifecycle hooks** (`onConnect`/`onDisconnect`/`onReconnectAttempt`) → **4.4/4.9**. Cancellation must not fire `onDisconnect` as an error (a cancelled run is not a failed one — [interceptor.dart:65-67](packages/koel_core/lib/src/agent/interceptor.dart#L65-L67)); those hooks are unwired until 4.9 anyway.
- **Member `analysis_options.yaml` doc gate + ≥ 90 % coverage gate** → **Story 4.10** (epic-sealing).

### Files you will touch

| Path | Action | Note |
| ---- | ------ | ---- |
| [packages/koel_http/pubspec.yaml](packages/koel_http/pubspec.yaml) | MODIFY | add `logging: ^1.3.0` to `dependencies` (first `package:logging` use in the monorepo). |
| [packages/koel_http/lib/src/transport/transport.dart](packages/koel_http/lib/src/transport/transport.dart) | MODIFY | add `Future<void> Function() abort` to `TransportResponse`; replace the "Story 4.3 concern" deferral dartdoc with the real abort contract. |
| [packages/koel_http/lib/src/transport/io_transport.dart](packages/koel_http/lib/src/transport/io_transport.dart) | MODIFY | wrap **injected** path too; expose idempotent prompt `abort` (owned → `client.close()`, both → cancel internal sub); non-honoring detection → silent-drop + one-shot `Level.WARNING`. |
| [packages/koel_http/lib/src/http_agent.dart](packages/koel_http/lib/src/http_agent.dart) | MODIFY | `_TransportTerminal.run()` invokes `response.abort()` on consumer-cancel (cancel-correct wrapper over the parse stream); stays platform-free. |
| [packages/koel_http/lib/src/transport/web_transport.dart](packages/koel_http/lib/src/transport/web_transport.dart) | MAYBE MODIFY | only if the new `TransportResponse.abort` shape requires the stub's doc/signature to mention the 4.10 `AbortController` fill; otherwise untouched (still throws). |
| `packages/koel_http/test/cancellation_test.dart` | NEW | long-running SSE server + AC1 timing + AC2 client matrix + AC3 fallback/warn-once + AC4 phase via `ChatSession`. |

### Library / framework requirements

- **Runtime:** `package:http ^1.6.0` (`Client.close()`, `StreamedResponse.stream`, `BaseClient` for the wrapped-client matrix row, `IOClient`); `package:logging ^1.3.0` (`Logger`, `Level.WARNING`) — **new**; `package:koel_core` (barrel) — `AbstractAgent`, `RunAgentInput`, `AgUiEvent`, `InterceptorChain`, `KoelClient`, `ChatSession`, `ChatState`, `RunPhase`; `SseParser` (own package). SDK: `dart:async` (`StreamController`/`StreamSubscription`/`Timer`), `dart:io` **only** inside `io_transport.dart`.
- **Dev:** `package:test ^1.25.0`, `package:http/testing.dart` (`MockClient`/`MockClient.streaming`), `dart:io` (test-only `HttpServer` + `IOClient`), `koel_test` (workspace, fixtures), `koel_lints` (workspace).
- **Forbidden in `lib/` (web-safety, framework-free):** `dart:io`/`dart:html`/`package:web` anywhere except `io_transport.dart` (behind the conditional import); Flutter; `freezed`/`build_runner` (no codegen — the abort handle is a plain function field); any SSE library. `http_agent.dart` and `transport.dart` import **no** platform library. **No `print`** — `package:logging` only ([architecture.md:587](../planning-artifacts/architecture.md)).

### Project Structure Notes

- All changes stay within `koel_http`; **no koel_core change** (AC4 is already satisfied there — trap #3). SDK constraint stays `">=3.11.0 <4.0.0"`; no member `analysis_options.yaml` (inherits root; gates are 4.10's).
- The abort handle on `TransportResponse` is the cross-platform seam: native fills it (this story), web fills it with `AbortController.abort()` (Story 4.10). Keep its type platform-neutral (`Future<void> Function()`), not a `dart:io` type.
- New test file `test/cancellation_test.dart` is AC2-named verbatim; it sits beside `test/http_agent_test.dart` (flat under `test/`, not under `test/parser/`).
- Barrel discipline unchanged: transports/codec stay in `lib/src/`, never exported; `TransportResponse.abort` is internal (not on the public barrel).

### Previous Story Intelligence

- **Story 4.2** built `HttpAgent`, the conditional-import transport seam, `io_transport`'s owned-client `_closingOnTeardown` (drain/error/cancel → close once, pause/resume preserved), and the `TransportErrorClassifier` (native `is`-checks behind a `dart.library.io` seam). It **reserved** the `TransportResponse` abort handle for this story ([transport.dart:45-49](packages/koel_http/lib/src/transport/transport.dart#L45-L49)) and explicitly left cancellation/TCP-abort to 4.3 ([4-2 :169](4-2-http-agent-native-transport.md)). Its review fixed a non-2xx socket leak (drain before throw) and a `late`→nullable subscription guard — **do not regress** either when you generalize the wrapper. [Source: [4-2 Dev Notes + Review Findings](4-2-http-agent-native-transport.md)]
- **Story 2.14** built `KoelClient`/`ChatSession`; `ChatSession.cancel()` already flips to `RunPhase.cancelled` synchronously, TCP-outcome-independent — **AC4 is theirs, you verify it** ([chat_session.dart:114-122](packages/koel_core/lib/src/client/chat_session.dart#L114-L122)).
- **Story 2.9** built `InterceptorChain` whose `proceed` transformer forwards cancel as a plain pipe — "a cancelled run is not a failed one" (no `RunErrorEvent` on cancel). The cancel path reaches your transport with no chain wiring. [Source: [interceptor.dart:65-137](packages/koel_core/lib/src/agent/interceptor.dart#L65-L137)]
- **House style** (4.1/4.2, 3.x): `final class`/sealed where possible, `const` ctors, exhaustive dartdoc, table-driven `package:test`, tight change sets, no codegen, no finalization gates until the epic-sealing story. `HttpAgent` stays the intentional non-`final` exception (Epic-5 subclasses). [Source: `git log`; 4-2 :204]

### Latest Tech Information

- **`package:http` 1.6.0:** on `IOClient`, cancelling the subscription to `StreamedResponse.stream` destroys the underlying `dart:io` socket → TCP close (this is the injected-client abort primitive). `Client.close()` on an owned/per-request client force-closes its connection pool. `BaseClient` is the supertype to subclass for the AC2 "custom interceptor-wrapped client" decorator (override `send` to delegate). `MockClient.streaming` (from `package:http/testing.dart`) yields a controllable streamed body for the non-honoring fallback case. `BrowserClient` is web-only (un-loadable on the VM) — defer (trap #6).
- **`package:logging` 1.3.x:** `Logger('name').warning('…')` emits a `LogRecord` at `Level.WARNING`; capture in tests via `Logger.root.onRecord.listen(...)` (set `hierarchicalLoggingEnabled`/`Logger.root.level` as needed). No global side effects beyond the records stream — safe in a test process. The runtime-once flag is your own library-private `bool`, not a `logging` feature.
- **`dart:io HttpServer` long-running SSE for the timing test:** `await HttpServer.bind(InternetAddress.loopbackIPv4, 0)`; on request, set `text/event-stream`, then `Timer.periodic(Duration(milliseconds: 100), …)` writing `data: {...}\n\n` + `await response.flush()`; observe the connection close via the write throwing / `response.done` completing after the client aborts — complete a `Completer` with a `Stopwatch` reading to measure cancel→close latency. Bind to port 0 for an ephemeral port. [Source: AC :67-71; http_agent_test.dart `_sseServer` pattern]
- **Timing budget realism:** loopback TCP teardown is sub-millisecond; the 50 ms budget is generous. The risk to the budget is **latency in the cancel path**, not the network — so ensure `onCancel` initiates `abort()`/`close()` with no preceding `await`. Keep any non-honoring-detection timer *parallel* to (not blocking) the cancel return.

### References

- Story spec (ACs, < 50 ms, matrix, fallback, phase): [epic-4 Story 4.3](../planning-artifacts/epics/epic-4-http-transport-koelhttp.md) (lines 59-83).
- Cancellation contract: [addendum.md §C.2](../planning-artifacts/prds/prd-koel-2026-05-27/addendum.md) (lines 530-540); architecture §4 cancellation + log-level table: [architecture.md:573-593](../planning-artifacts/architecture.md); Gap G-1 (web `AbortController`, deferred to 4.10): [architecture.md:1198-1202](../planning-artifacts/architecture.md).
- Existing transport seam (what you extend): [transport.dart:20-59](packages/koel_http/lib/src/transport/transport.dart#L20-L59), [io_transport.dart:19-107](packages/koel_http/lib/src/transport/io_transport.dart#L19-L107).
- `HttpAgent` + `_TransportTerminal`: [http_agent.dart:42-146](packages/koel_http/lib/src/http_agent.dart#L42-L146).
- Cancel-forwarding interceptor chain: [interceptor.dart:60-137](packages/koel_core/lib/src/agent/interceptor.dart#L60-L137); cancel/backpressure-correct controller pattern to mirror: [stage_support.dart:40-76](packages/koel_core/lib/src/pipeline/stage_support.dart#L40-L76).
- AC4 seam (already built): [chat_session.dart:56,114-122](packages/koel_core/lib/src/client/chat_session.dart#L114-L122); `RunPhase`: [chat_state.dart:11-33](packages/koel_core/lib/src/state/chat_state.dart#L11-L33); `KoelClient.newSession`: [koel_client.dart:153](packages/koel_core/lib/src/client/koel_client.dart#L153).
- Test exemplar (loopback SSE server, helpers, style): [http_agent_test.dart](packages/koel_http/test/http_agent_test.dart).
- House-style exemplars: [4-2-http-agent-native-transport.md](4-2-http-agent-native-transport.md), [4-1-framework-free-sse-parser.md](4-1-framework-free-sse-parser.md).

### Design decisions (RESOLVED — AC/architecture-forced, not open)

1. **Cancel propagation is reused, not rebuilt** — `yield*` + the plain-pipe `InterceptorChain` transformer already carry cancel to the socket; 4.3 adds explicit prompt abort + silent-drop + warn-once on top. [trap #1]
2. **Abort via `package:http` (`Client.close()` owned + response-subscription cancel injected), NOT raw `dart:io HttpClient.abort()`** — the matrix and 4.2's injectable-client AC forbid abandoning `package:http`; Addendum C.2 lists the two as alternatives. [trap #2]
3. **`TransportResponse` gains a platform-neutral `Future<void> Function() abort`** — io fills it now; web fills it with `AbortController.abort()` in 4.10. [Task 2; epic-4 4.10]
4. **Every response (owned + injected) is wrapped in a koel-owned teardown controller** so silent-drop holds regardless of client behavior — generalizing 4.2's owned-only `_closingOnTeardown`. [trap #1; AC1 clarification]
5. **`RunPhase.cancelled` is verified, not implemented** — `ChatSession.cancel()` (2.14) owns it; koel_http adds no reducer/phase code. [trap #3]
6. **One `Level.WARNING`, library-private runtime-once flag, abort-not-honored only** — distinct from the normal `Level.FINE` cancellation drop (Story 4.6). `package:logging` is a new dep. [trap #4, #5]
7. **`BrowserClient`/web row deferred to Story 4.10** (G-1); native matrix = default `http.Client()` + `IOClient` + wrapped `BaseClient`. [trap #6]
8. **No finalization gates** — analyze/test/format green only; doc + ≥90% coverage gates are 4.10's. [4-1/4-2 precedent]

These are baked in — implement them; no confirmation gate.

## Dev Agent Record

### Context Reference

<!-- Path(s) to story context will be added here by context workflow -->

### Agent Model Used

claude-opus-4-8[1m] (via `/agent-flutter-engineer` specialist)

### Debug Log References

- `dart pub get` — `logging: ^1.3.0` resolved cleanly into the workspace (first `package:logging` consumer in the monorepo).
- `dart analyze packages/koel_http/lib` → No issues found (verified before tests).
- **Transport-teardown probe** (throwaway): with the owned default client, a consumer `cancel()` drives a real socket teardown — the loopback server's next `flush()` threw `StateError` at ~66 ms (one 25 ms tick + RST round-trip). Confirms `IOClient.close()` (http 1.6.0 uses `force: true`, [io_client.dart:243]) + response-subscription cancel ([io_client.dart:199]) genuinely close the socket, but `HttpResponse.done` does **not** fire on client abort — so AC1's tight `<50ms` is measured on the koel-side abort *invocation* (instrumented client), and the real TCP teardown is asserted separately via the server's write-failure (generous bound).
- `melos run analyze` → 0 issues across all 9 packages.
- `melos run format:check` → 116 files, 0 changed (2 files formatted during dev, then clean).
- `melos run test` → green workspace-wide; `koel_http` 43 tests (35 prior + 8 new cancellation). New suite re-run 5× — stable (abort-invocation latency is sub-millisecond synchronous stream-cancel, far inside the 50 ms budget).

### Completion Notes List

- **No new propagation plumbing (trap #1).** Cancel already threads consumer → `InterceptorChain` (plain pipe) → `_TransportTerminal` `async*` `yield*` → `SseParser` → transport. 4.3 adds an *explicit, prompt* abort on top because `SseParser.parse` is `async*` + `await for`, which **strands cancel** (the codebase's own `buildStage` dartdoc flags this) — relying on cancel threading through it would blow the 50 ms budget.
- **`TransportResponse.abort` handle (Task 2).** Added a platform-neutral `Future<void> Function() abort` to `TransportResponse` (the seam 4.2 reserved). Native fills it; web (Story 4.10) will fill it with `AbortController.abort()`. `web_transport.dart`/`transport_stub.dart` were **not** touched — they throw `UnsupportedError` before ever constructing a `TransportResponse`.
- **`io_transport` generalized (Task 3).** 4.2 wrapped only the *owned*-client byte stream (to close the client on teardown); 4.3 wraps **every** path in a private `_Connection` that owns the response subscription, so `abort` and the silent-drop guarantee work regardless of who owns the `http.Client`. `abort()` cancels the live subscription (→ `IOClient` destroys the socket = TCP close) and closes a self-created client; idempotent via the existing once-guard; the returned future settles when the cancel does (the honoring signal). Non-2xx drain + `readTimeout` idle bound + owned-client-close-once (the 4.2 review fixes) all preserved.
- **`abortOnCancel` + budget watchdog (Task 3/4).** New platform-free `lib/src/connection/cancellation.dart`. `_TransportTerminal.run()` now `yield* abortOnCancel(SseParser().parse(response.body), response.abort)`. On consumer cancel it fires `response.abort()` immediately and cancels its own forwarding — **neither awaited on the cancel-return path**, so a client that ignores abort cannot hang the consumer's `cancel()`. A fire-and-forget `Timer(50ms)` races the teardown; if it stalls past the budget, one `Level.WARNING` (`Logger('koel_http.cancellation')`) emits, gated by a library-private `_abortNotHonoredWarned` flag → **once per process** (AC3). An honoring client settles fast → timer cancelled → no warning, no lingering timer.
- **`RunPhase.cancelled` is verified, not implemented (trap #3).** No koel_core / reducer change — `ChatSession.cancel()` (Story 2.14) already flips the phase synchronously. AC4 tests wire `HttpAgent` into a `KoelClient`/`ChatSession` end-to-end and assert `state.phase == RunPhase.cancelled`, with **both** an honoring server and the non-honoring client (proving "regardless of TCP outcome").
- **AC1 timing measured deterministically.** An `_InstrumentedClient` (which doubles as the AC2 wrapped-client row) records the elapsed of a test-owned `Stopwatch` the instant koel aborts (response-subscription cancel / `close()`); asserted `< 50 ms` — literally AC1's "`Client.close()` invokes within 50 ms". A separate owned-client test asserts the server's writes fail (real TCP teardown).
- **AC2 matrix.** Native-reachable rows covered: default `http.Client()`, explicit `IOClient`, custom interceptor-wrapped client. The `BrowserClient` / web-`AbortController` row is a documented deferral to **Story 4.10** (G-1) — `BrowserClient` is un-loadable on the VM and web transport is a throwing stub until then.
- **No finalization gates this story** (member `analysis_options.yaml` doc gate + ≥90 % coverage gate are Story 4.10's), matching the 4.1/4.2 precedent. Full dartdoc written anyway.

### File List

- `packages/koel_http/pubspec.yaml` — MODIFY (added `logging: ^1.3.0` — first `package:logging` consumer in the monorepo; review patch added `meta: ^1.16.0` — first `package:meta` consumer, for `@visibleForTesting`)
- `packages/koel_http/lib/src/transport/transport.dart` — MODIFY (added `Future<void> Function() abort` to `TransportResponse` + contract dartdoc)
- `packages/koel_http/lib/src/transport/io_transport.dart` — MODIFY (generalized teardown into a private `_Connection` wrapping **every** path; exposes idempotent prompt `abort`)
- `packages/koel_http/lib/src/connection/cancellation.dart` — NEW (`abortOnCancel` stream wrapper + 50 ms abort-budget watchdog + runtime-once `Level.WARNING`; review patch added `@visibleForTesting resetAbortNotHonoredWarning()` for deterministic AC3 assertion)
- `packages/koel_http/lib/src/http_agent.dart` — MODIFY (`_TransportTerminal.run()` wraps the parsed stream in `abortOnCancel`, firing `response.abort()` on consumer cancel)
- `packages/koel_http/test/cancellation_test.dart` — NEW (AC1 abort-timing + real-teardown; AC2 client matrix; AC3 silent-drop + one-shot warning; AC4 `RunPhase.cancelled`)

## Change Log

| Date | Version | Description | Author |
| ---- | ------- | ----------- | ------ |
| 2026-05-31 | 0.1.0 | Story drafted — ultimate context engine analysis completed; comprehensive developer guide created | create-story |
| 2026-05-31 | 0.2.0 | Implemented cancellation propagation: `TransportResponse.abort` handle + generalized `io_transport` `_Connection` teardown + `abortOnCancel` watchdog (silent-drop + one-shot `Level.WARNING`) wired into `_TransportTerminal`; `logging` dep added. 8-test `cancellation_test.dart` (AC1 timing+teardown / AC2 client matrix / AC3 fallback / AC4 phase). analyze/format/test green workspace-wide (koel_http 43 tests). Status → review. | dev-story |

## Review Findings

**Code review 2026-05-31** — 3 adversarial layers (Blind Hunter / Edge Case Hunter / Acceptance Auditor). All four ACs verified satisfied; analyze/format/test green. Triage: **1 decision-needed, 0 patch, 2 deferred, 8 dismissed** (false positives or spec-mandated by design).

- [x] [Review][Patch] AC3 "exactly one WARNING" is coupled to test declaration order via the process-global once-flag — **RESOLVED** (decision → patch, Si chose hardening). Added `@visibleForTesting resetAbortNotHonoredWarning()` ([cancellation.dart](../../packages/koel_http/lib/src/connection/cancellation.dart)) — production never resets the gate, so the annotation makes the analyzer reject any non-test caller (the once-per-process contract is now *enforced*, not just documented per spec). The AC3 test imports the internal `src/connection/cancellation.dart` (same-package) and calls the reset at its start, so `expect(warnings, hasLength(1))` is deterministic regardless of which test trips the gate first. Verified: 8/8 pass in default order **and** 3× `--test-randomize-ordering-seed=random`. Added `meta: ^1.16.0` (first monorepo use, for the annotation).
- [x] [Review][Defer] Non-honoring teardown future + live upstream subscription retained per cancellation [cancellation.dart:62-67,90] — deferred, inherent to a client that won't release its socket (koel cannot force it); minor unbounded retention only under a pathological non-honoring client.
- [x] [Review][Defer] Non-2xx drain can hang on an *active* (non-idle) error body [http_agent.dart:134] — deferred, pre-existing from Story 4.2; `readTimeout` bounds only the inter-byte idle case, not a byte-flood. Not introduced by 4.3.
