---
baseline_commit: 1c8a6d45cbe5b2a5b6f16144ab5d79e37337e4b9
---

# Story 4.4: `RetryInterceptor` exponential backoff + jitter + `ConnectionResumed` MetaEvent

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

> **Dev agent:** this is **Story 4.4 of Epic 4** (HTTP transport, `koel_http`). It adds the **retry/reconnect engine**: a public `RetryInterceptor` that re-runs a failed run with exponential backoff + ±20% jitter (default max 5 reconnect attempts), emits a `ConnectionResumed` marker on a successful reconnect, surfaces a terminal `TransportError(transportClosed)` on exhaustion, and respects a `shouldRetry` predicate. It also makes `HttpAgent`'s currently-**accepted-but-ignored** `retry:`/`onReconnectAttempt:` params **live** (both prior-story dartdocs explicitly say "→ Story 4.4"). It touches `.dart` files and the interceptor/transport seam, so **invoke `/agent-flutter-engineer` before producing any code** (per [CLAUDE.md](CLAUDE.md)). `packages/koel_http/` already ships `SseParser` (4.1), `HttpAgent` + the transport seam (4.2), and the cancellation `abortOnCancel` watchdog (4.3). **Seven things are load-bearing, and the first three are traps that will sink a naïve reading of the AC:**
>
> 1. **`chain.proceed(input)` does NOT throw on failure — it emits a terminal `RunErrorEvent` *value* and then closes.** This is THE central trap. The `InterceptorChain.proceed` transformer converts *every* downstream throw/stream-error into a trailing `RunErrorEvent` and closes the stream normally ([interceptor.dart:113-126](packages/koel_core/lib/src/agent/interceptor.dart#L113-L126)). So `RetryInterceptor` will **never** see a Dart `throw` to `catch` — it must **watch the delegated stream for a terminal `RunErrorEvent`**, decide retry from `RunErrorEvent.error` (a typed `KoelError`), and either **suppress-and-re-subscribe** or **forward**. A naïve `try { await for (...) } catch` retry loop will never fire because nothing throws. [Source: interceptor.dart:102-127; ag_ui_event RunErrorEvent]
> 2. **Retry = re-call `chain.proceed(input)` again — each call is a fresh re-POST / reconnect; subscribers see each attempt by design.** The chain is an immutable cursor: the `chain` handed to your `intercept` is already advanced one step ([interceptor.dart:135-136](packages/koel_core/lib/src/agent/interceptor.dart#L135-L136)), and calling its `proceed(input)` again re-invokes the rest of the chain + the terminal `_TransportTerminal` → a brand-new HTTP connection. A partial first attempt may have already delivered `RunStartedEvent` + content before erroring; the re-run delivers a **fresh** `RunStartedEvent…`. That duplication is **accepted** — architecture §"Cross-Cutting Concerns" #3: *"Retry semantics interact with subscribers (subscribers see each retry attempt by design)"* ([architecture.md:109](_bmad-output/planning-artifacts/architecture.md)). The `ConnectionResumed` `CustomEvent` is the seam marker between attempts; do **not** try to de-dup or resume mid-stream (base AG-UI/SSE has no resume token). [Source: architecture.md:108-109; interceptor.dart:102-136]
> 3. **`ConnectionResumed` is NOT a new event type — it is a `CustomEvent(name: "koel.connection_resumed")`.** The story TITLE and FR-B4 say "`ConnectionResumed` `MetaEvent`", but the AC body is explicit: *"modeled as a `CustomEvent` with `name: "koel.connection_resumed"` so it rides the existing sealed `AgUiEvent` union without expanding the protocol surface"* ([epic-4 :105](_bmad-output/planning-artifacts/epics/epic-4-http-transport-koelhttp.md#L105)). There is **no** `MetaEvent` / `ConnectionResumed` class anywhere in `koel_core` (verified — the sealed union is closed; adding a subtype is a protocol-surface change this story must NOT make). Use [`CustomEvent`](packages/koel_core/lib/src/event/custom_event.dart) verbatim. [Source: AC :103-106; custom_event.dart:19-40; epic-4 :85]
> 4. **`HttpAgent.retry` + `HttpAgent.onReconnectAttempt` are this story's to wire — they are dead params today.** [http_agent.dart:65,69](packages/koel_http/lib/src/http_agent.dart#L59-L71) accepts `RetryPolicy? retry` and `void Function(int, Duration)? onReconnectAttempt` and **drops them on the floor** (the ctor body only stores `client`/`interceptors`). Both the [reconnect_policy.dart:1-8](packages/koel_http/lib/src/connection/reconnect_policy.dart#L1-L8) dartdoc (*"the backoff/jitter/reconnect engine that consumes these fields — and the `onReconnectAttempt`/`ConnectionResumed` wiring — lands in **Story 4.4**"*) and the [http_agent.dart:56-58](packages/koel_http/lib/src/http_agent.dart#L53-L58) dartdoc (*"[retry]/[onReconnectAttempt] → Story 4.4"*) name this story. So 4.4 = **(a)** the public `RetryInterceptor` engine **+ (b)** `HttpAgent` building one from `retry:` and bridging `onReconnectAttempt` into it. [Source: http_agent.dart:53-71; reconnect_policy.dart:1-30]
> 5. **`RetryInterceptor`'s constructor is frozen by Addendum A.2 — it has NO `onReconnectAttempt` param.** A.2's signature is exactly `RetryInterceptor({int maxAttempts = 5, Duration baseDelay = const Duration(seconds: 1), Duration maxDelay = const Duration(seconds: 30), double jitter = 0.2, bool Function(Object error, int attempt)? shouldRetry})` ([addendum.md:314-322](_bmad-output/planning-artifacts/prds/prd-koel-2026-05-27/addendum.md)). `onReconnectAttempt` lives on **`HttpAgent`**, not here. The bridge (trap #4) therefore needs an **`@internal` injection seam** — a second `@internal RetryInterceptor.forAgent({…, void Function(int, Duration)? onReconnectAttempt})` named constructor (NOT exported from the barrel) that `HttpAgent` uses. `package:meta` is already a dep (4.3). The public ctor stays A.2-verbatim with the observer unset. [Source: addendum.md:314-322; cancellation.dart:5 (meta already imported)]
> 6. **`maxAttempts` counts RETRIES (reconnects), not total attempts — the initial connection is attempt 0.** NFR-7: *"Maximum 5 **reconnect** attempts on transient failure"* ([prd.md:304](_bmad-output/planning-artifacts/prds/prd-koel-2026-05-27/prd.md#L304)). Reconcile the two AC scenarios precisely: "fails 3 times then succeeds → **3 retries**, `onReconnectAttempt` invoked **3 times**" means *initial fails → retry#1 fails → retry#2 fails → retry#3 succeeds* (3 retries used). "**6 consecutive failures** (above the default **5-attempt cap**)" means *initial + 5 retries all fail = 6 failures → cap exhausted → terminal error*. So: a failure schedules retry _N_ (1-based) while _N ≤ maxAttempts_; the _(maxAttempts+1)_-th failure exhausts. [Source: AC :97-110; prd.md:304; F-B4 prd.md:150]
> 7. **The `RetryInterceptor` is OUTERMOST relative to `AuthInterceptor` — Retry must re-run Auth on each attempt (sets up Story 4.5 token-refresh).** When `HttpAgent` auto-builds the retry interceptor from `retry:`, **prepend** it (index 0) so the chain is `[retry, …userInterceptors]`. Retry's `proceed(input)` then re-invokes `AuthInterceptor.intercept` on every reconnect → each attempt re-fetches headers. Story 4.5 AC4 ("first attempt 401s … second attempt carries the refreshed token") depends on this ordering. Forward order runs `[A,B,C]` as `A→B→C→agent` ([interceptor.dart:13-16](packages/koel_core/lib/src/agent/interceptor.dart#L13-L16)), so outermost = lowest index. [Source: interceptor.dart:13-22,135-136; epic-4 Story 4.5 :137-139]

## Story

As a Flutter/Dart developer,
I want `RetryInterceptor` with exponential backoff (default 1s → 30s, ±20% jitter, max 5 attempts) and emission of `ConnectionResumed` `MetaEvent` on reconnect,
so that transient failures recover automatically per FR-B4 + NFR-7.

## Acceptance Criteria

Verbatim from [epic-4 Story 4.4](_bmad-output/planning-artifacts/epics/epic-4-http-transport-koelhttp.md) (lines 85-114):

1. **Given** `koel_http/lib/src/interceptors/retry_interceptor.dart`, **When** I inspect the constructor, **Then** it matches Addendum A.2: `RetryInterceptor({int maxAttempts = 5, Duration baseDelay = const Duration(seconds: 1), Duration maxDelay = const Duration(seconds: 30), double jitter = 0.2, bool Function(Object error, int attempt)? shouldRetry})`.

2. **Given** an unstable endpoint that fails 3 times then succeeds, **When** the agent runs with `RetryInterceptor` in the chain, **Then** 3 retries occur with delays computed by exponential backoff + ±20% jitter, **And** the eventual run succeeds, **And** `onReconnectAttempt` is invoked 3 times with the correct attempt number and computed delay.

3. **Given** a successful reconnect mid-stream, **When** the next event arrives, **Then** the event stream emits a `ConnectionResumed` event (modeled as a `CustomEvent` with `name: "koel.connection_resumed"` so it rides the existing sealed `AgUiEvent` union without expanding the protocol surface) immediately before the next domain event per FR-B4, **And** the consumer can render UI state reflecting reconnection.

4. **Given** 6 consecutive failures (above the default 5-attempt cap), **When** the agent runs, **Then** the stream emits `RunErrorEvent(TransportError(code: KoelErrorCode.transportClosed))` with the underlying cause attached.

5. **Given** a `shouldRetry` callback returning `false` for `KoelErrorCode.businessAuth`, **When** an auth failure occurs, **Then** no retry attempts execute (the failure surfaces immediately).

> **AC clarifications (RESOLVED — do not re-litigate, implement):**
>
> - **AC1 surface:** the public ctor is **A.2-verbatim** — five named params, `jitter` is a **`double`** (the fraction, default `0.2`), not the `bool` on `RetryPolicy`. The class lives at the AC-named path `lib/src/interceptors/retry_interceptor.dart` (the file `interceptors/` dir does not exist yet — create it) and is **exported from the barrel** ([koel_http.dart](packages/koel_http/lib/koel_http.dart)) since `RetryInterceptor` is public API (A.2). [Source: addendum.md:314-322; architecture.md:836-839]
> - **AC2 "the agent runs with `RetryInterceptor` in the chain" + "`onReconnectAttempt` invoked":** the canonical path is `HttpAgent(url: …, retry: RetryPolicy(maxAttempts: 3, baseDelay: <tiny>), onReconnectAttempt: cb)` — the agent builds the engine from `retry:` and bridges `cb` into it (trap #4/#5). `onReconnectAttempt(attempt, delay)` fires **once per retry**, with `attempt` the 1-based retry index and `delay` the **actual jittered** `Duration` waited. Assert the delay is within `[base·(1−jitter), base·(1+jitter)]` for that step. Use a **tiny `baseDelay`** (e.g. `Duration(milliseconds: 1-5)`) so the suite stays fast; do not assert wall-clock equality. [Source: AC :97-101; trap #4/#6]
> - **AC3 "immediately before the next domain event":** emit the `ConnectionResumed` `CustomEvent` **lazily** — only when the *re-subscribed* attempt yields its first event (proof the reconnect actually produced data), prepended to that event. A retry whose connection also fails immediately yields **no** `ConnectionResumed` (it did not resume) — it just triggers the next retry. `value` carries `{'attempt': <retry index>}` (structured, koel-namespaced; koel does not interpret it — [custom_event.dart:10-11](packages/koel_core/lib/src/event/custom_event.dart#L10-L11)). Expose the name as a `static const` (no magic string). [Source: AC :103-106; custom_event.dart]
> - **AC4 exhaustion shape:** after the `(maxAttempts+1)`-th failure, emit a **fresh** `RunErrorEvent(TransportError(message: …, code: KoelErrorCode.transportClosed, cause: <last attempt's KoelError>))` — the underlying cause is the last failure (trap #6). This **replaces** the last raw error's code with `transportClosed` (the "retries exhausted" terminal). Contrast AC5: a **non-retryable** error is forwarded **unchanged**. [Source: AC :108-110; koel_error.dart:51-63]
> - **AC5 default `shouldRetry`:** when no `shouldRetry` is supplied, the default retries **only `TransportError`** (all four transport codes are transient) and **never** retries `BusinessError`/`ProtocolError`/`AgentError` (so `businessAuth`, a `BusinessError`, surfaces immediately). A supplied `shouldRetry(error, attempt)` receives the typed `KoelError` as `error` (it `is BusinessError && error.code == KoelErrorCode.businessAuth`) and the 1-based attempt; returning `false` short-circuits — the original `RunErrorEvent` forwards immediately, no backoff. [Source: AC :112-114; koel_error_code.dart:47-58; error_classifier.dart:38-99]
> - **AC5 — do NOT build 401→`businessAuth` classification (scope trap):** koel_http currently classifies a non-2xx as `TransportError(transportClosed)` ([http_agent.dart:138-142](packages/koel_http/lib/src/http_agent.dart#L138-L142)) and its [`TransportErrorClassifier`](packages/koel_http/lib/src/error/io_error_classifier.dart) only refines socket/TLS shapes — **status-code-aware classification (401→`businessAuth`) is Epic 5**, explicitly *not* this story ([io_error_classifier.dart:31-34](packages/koel_http/lib/src/error/io_error_classifier.dart#L31-L34); error_classifier.dart:33-37). So AC5 must **inject** the `BusinessError(businessAuth)` directly — build an `InterceptorChain(interceptors: [RetryInterceptor(shouldRetry: …)], agent: <stub AbstractAgent that emits `RunErrorEvent(BusinessError(code: businessAuth))`>)` (or throws it) and assert no retry. Reaching for HTTP-status classification here is the wrong approach. [Source: io_error_classifier.dart:31-60; http_agent.dart:127-143]

## Tasks / Subtasks

- [x] **Task 0 — Read the real surfaces before writing a line** (AC: all — skipping this builds the wrong contract)
  - [x] Re-read [interceptor.dart](packages/koel_core/lib/src/agent/interceptor.dart) **in full** — the `Interceptor` contract (call `proceed` exactly once or substitute; MAY wrap the returned stream) and `InterceptorChain.proceed` (lines 102-136): **errors become a terminal `RunErrorEvent` value, never a throw** (trap #1); the chain is an immutable advanced cursor reusable across multiple `proceed` calls (trap #2). [Source: interceptor.dart:1-137]
  - [x] Re-read [http_agent.dart](packages/koel_http/lib/src/http_agent.dart) — the dead `retry:`/`onReconnectAttempt:` params (lines 65,69) and `run()` building the chain (lines 92-97). You will prepend the auto-built retry interceptor here. [Source: http_agent.dart:43-98]
  - [x] Re-read [reconnect_policy.dart](packages/koel_http/lib/src/connection/reconnect_policy.dart) — `RetryPolicy` data holder (defaults **3** attempts / **500ms** / 30s / **bool** jitter). Note the **field/default mismatch** vs `RetryInterceptor` (5 / 1s / 30s / **double** jitter) — Task 5 maps `RetryPolicy → RetryInterceptor` (bool `jitter` → `0.2` or `0.0`). [Source: reconnect_policy.dart:9-30; addendum.md:314-322]
  - [x] Read [custom_event.dart](packages/koel_core/lib/src/event/custom_event.dart) — `CustomEvent({required String name, required Object? value})`; `value` deep-compared, always emitted. This is `ConnectionResumed` (trap #3). [Source: custom_event.dart:19-40]
  - [x] Read [koel_error.dart](packages/koel_core/lib/src/error/koel_error.dart) (`TransportError`/`BusinessError` subtypes) + [koel_error_code.dart](packages/koel_core/lib/src/error/koel_error_code.dart) (`transportClosed`, `businessAuth`, the four transport codes) + [run_events.dart:87-119](packages/koel_core/lib/src/event/run_events.dart#L87-L119) (`RunErrorEvent({required KoelError error})`). The default `shouldRetry` and the exhaustion shape read these. [Source: koel_error.dart:28-122; koel_error_code.dart:13-63]
  - [x] Read [cancellation.dart](packages/koel_http/lib/src/connection/cancellation.dart) — the **controller + watchdog `Timer` + cancel-correct teardown** pattern (lines 50-102). The retry interceptor's stream wrapper mirrors this: a `StreamController` whose `onCancel` cancels the live attempt **and** any pending backoff `Timer`; pause/resume forwarded. [Source: cancellation.dart:50-102]
  - [x] Read FR-B4 ([prd.md:150](_bmad-output/planning-artifacts/prds/prd-koel-2026-05-27/prd.md#L150)) + NFR-7 ([prd.md:304](_bmad-output/planning-artifacts/prds/prd-koel-2026-05-27/prd.md#L304)) + architecture §Cross-Cutting #3 ([architecture.md:108-109](_bmad-output/planning-artifacts/architecture.md)) — the canonical contract: exponential 1s→30s, ±20% jitter, max 5 reconnects, `ConnectionResumed` on reconnect, subscribers see each attempt by design. [Source: prd.md:150,304; architecture.md:108-109]

- [x] **Task 1 — Pure backoff schedule (unit-testable, no I/O)** (AC: #2)
  - [x] Add a pure, deterministic backoff function — `@visibleForTesting Duration retryBackoff(int attempt, {required Duration baseDelay, required Duration maxDelay, required double jitter, required Random random})` — in [retry_interceptor.dart](packages/koel_http/lib/src/interceptors/retry_interceptor.dart) (NEW). Formula: `base = min(maxDelay, baseDelay * 2^(attempt-1))`; `delay = base * (1 + (random.nextDouble()*2 - 1) * jitter)`; clamp to `>= Duration.zero`. `attempt` is 1-based. Implemented with integer-microsecond doubling (clamps at maxDelay before overflow), avoiding float `pow`. [Source: AC :99; prd.md:150]
  - [x] Inject `Random` so a **seeded** `Random(n)` in tests makes delays deterministic; production uses `Random()`. Keep the function side-effect-free (no `Timer`, no `await`). [Source: house style — pure functions > hidden state]
  - [x] Unit-test it directly: `retryBackoff(1)` ≈ baseDelay, `(2)` ≈ 2·base, clamps at `maxDelay` for large attempts, and every result ∈ `[base·(1−jitter), base·(1+jitter)]`. [Source: AC :99]

- [x] **Task 2 — `RetryInterceptor` (the engine)** (AC: #1, #2, #3, #4, #5)
  - [x] In [retry_interceptor.dart](packages/koel_http/lib/src/interceptors/retry_interceptor.dart) (NEW) declare `final class RetryInterceptor implements Interceptor` with the **A.2-verbatim** public ctor (trap #5; AC1). Add the **`@internal RetryInterceptor.forAgent({…, void Function(int attempt, Duration delay)? onReconnectAttempt})`** named ctor for the `HttpAgent` bridge (NOT barrel-exported). Add `static const String connectionResumedEventName = 'koel.connection_resumed';`. [Source: addendum.md:314-322; trap #5]
  - [x] `intercept(chain, input)` returns a `StreamController`-backed stream (mirror [cancellation.dart:50-83](packages/koel_http/lib/src/connection/cancellation.dart#L50-L83)) that drives the **attempt loop**:
    1. Subscribe to `chain.proceed(input)` (attempt _N_, starting 0). Forward every non-terminal event downstream. On the **first** event of a *reconnect* attempt (_N ≥ 1_), prepend the `ConnectionResumed` `CustomEvent(name: connectionResumedEventName, value: {'attempt': N})` (AC3, lazy — trap #3 / AC3 clarification).
    2. On a terminal **`RunErrorEvent`** (trap #1): hold it; decide retry = `N < maxAttempts && shouldRetry(error.error, N+1)` (default `shouldRetry` = `error is TransportError`). If retry → compute `retryBackoff(N+1, …)`, invoke the bridged `onReconnectAttempt?.call(N+1, delay)`, wait the delay via a **cancellable `Timer`**, then re-subscribe `chain.proceed(input)` as attempt _N+1_ (do **not** forward the held error). If no retry → see step 3/4.
    3. **Exhausted** (`N == maxAttempts`, retryable): emit `RunErrorEvent(TransportError(message: 'Reconnect attempts exhausted after ${maxAttempts} retries', code: KoelErrorCode.transportClosed, cause: <held error's KoelError>))` then close (AC4 — trap #6 / AC4 clarification).
    4. **Non-retryable** (`shouldRetry` false): forward the **original** held `RunErrorEvent` unchanged, then close (AC5). Decision order is `!shouldRetry → forward unchanged` **before** the exhaustion check, so a non-retryable error on the last attempt forwards unchanged rather than being rewritten to `transportClosed`.
    5. On normal completion (downstream `onDone` with no held error) → close. [Source: AC :97-114; interceptor.dart:102-127]
  - [x] **Cancellation correctness:** the controller's `onCancel` cancels the live attempt subscription **and** cancels any pending backoff `Timer` (a cancel during the wait window must abort the wait and never reconnect, guarded by a `cancelled` flag the timer callback checks); `onPause`/`onResume` forward to the live subscription. The cancel-return path only returns the inner `cancel()` (which bottoms out in `abortOnCancel`, never blocking) — no extra `await` (4.3 invariant). [Source: cancellation.dart:64-81; AC — cancel must stay sub-50ms (NFR-8, Story 4.3)]
  - [x] Default `shouldRetry`: a top-level/private `bool _retryTransient(Object error, int attempt) => error is TransportError;` — all four transport codes are transient; `BusinessError`(`businessAuth`)/`ProtocolError`/`AgentError` are not retried. Document why `businessAuth` is excluded (AC5). [Source: AC :112-114; koel_error.dart:51-122]

- [x] **Task 3 — Export `RetryInterceptor` from the barrel** (AC: #1)
  - [x] In [koel_http.dart](packages/koel_http/lib/koel_http.dart) (MODIFY) add `export 'src/interceptors/retry_interceptor.dart';`. The `@internal forAgent` ctor and `retryBackoff` stay non-public-API by annotation, not by hiding (analyzer enforces `@internal`/`@visibleForTesting`). Keep `RetryPolicy`/`HttpAgent`/`SseParser` exports. [Source: koel_http.dart:1-6; A.2 RetryInterceptor is public]

- [x] **Task 4 — Wire `HttpAgent.retry` + `onReconnectAttempt`** (AC: #2, #4)
  - [x] In [http_agent.dart](packages/koel_http/lib/src/http_agent.dart) (MODIFY) store `retry`/`onReconnectAttempt` as fields. In `run()`, when `retry != null`, build `RetryInterceptor.forAgent(maxAttempts: retry.maxAttempts, baseDelay: retry.baseDelay, maxDelay: retry.maxDelay, jitter: retry.jitter ? 0.2 : 0.0, onReconnectAttempt: _onReconnectAttempt)` and **prepend** it to `_interceptors` (outermost — trap #7): `interceptors: [if (retry != null) retryInterceptor, ..._interceptors]`. Update the ctor dartdoc (drop the "→ Story 4.4" deferral for `retry`/`onReconnectAttempt`; keep it for `synthesizeChunks`→4.8, `onConnect`/`onDisconnect`→4.9). [Source: http_agent.dart:53-97; trap #4/#7; reconnect_policy.dart:9-17 (bool→double jitter mapping)]
  - [x] **Do not** double-apply retry: if a consumer passes both `retry:` AND an explicit `RetryInterceptor` in `interceptors:`, both run (nested) — that is the consumer's choice; document it but do not de-dup. [Source: composition > magic; CLAUDE.md]

- [x] **Task 5 — Refresh `RetryPolicy` dartdoc + map note** (AC: #1)
  - [x] In [reconnect_policy.dart](packages/koel_http/lib/src/connection/reconnect_policy.dart) (MODIFY) update the dartdoc: the engine now exists (Story 4.4); `RetryPolicy` is the `HttpAgent(retry:)` convenience config that maps to a `RetryInterceptor` (bool `jitter` → `0.2`/`0.0` fraction). **Keep the existing field defaults** (3/500ms/30s/bool) — they are a shipped 4.2 public-surface choice; the canonical 5/1s/0.2 default belongs to the standalone `RetryInterceptor()` per A.2. Note the two entry points and their distinct defaults. [Source: reconnect_policy.dart:1-30; addendum.md:314-322; CLAUDE.md API one-way-door]

- [x] **Task 6 — `retry_interceptor_test.dart` (all 5 AC scenarios)** (AC: #1, #2, #3, #4, #5)
  - [x] New `packages/koel_http/test/retry_interceptor_test.dart` (`package:test`; reuse [http_agent_test.dart](packages/koel_http/test/http_agent_test.dart) helper style — ephemeral loopback `HttpServer`, `addTearDown`, `_input()`). [Source: http_agent_test.dart:14-68]
  - [x] **AC1 surface:** assert the public ctor compiles with all-default and all-explicit args; `jitter` is a `double`. (A compile-level/shape test; the behavior tests cover the rest.) [Source: AC :93-95]
  - [x] **AC2 fail-3-then-succeed:** a flaky SSE server (a counter-driven `HttpServer` that returns 500 — or closes the socket — for the first 3 requests, then replays a real fixture body). Run via `HttpAgent(url, retry: RetryPolicy(maxAttempts: 3, baseDelay: Duration(milliseconds: 2)), onReconnectAttempt: record)`. Assert: the run **succeeds** (terminal `RunFinishedEvent`, no terminal error), `onReconnectAttempt` recorded **exactly 3** entries with `attempt` ∈ {1,2,3} and each `delay` within the jitter band for its step. [Source: AC :97-101]
  - [x] **AC3 ConnectionResumed:** assert the success stream from AC2 contains a `CustomEvent(name: 'koel.connection_resumed')` positioned **immediately before** the first domain event of the recovered attempt (and **none** appears before the very first attempt). [Source: AC :103-106]
  - [x] **AC4 exhaustion:** a server that **always** fails; run with `maxAttempts: 5` (default) over a tiny `baseDelay`. Drive 6 failures; assert the **terminal** event is `RunErrorEvent` whose `error is TransportError && error.code == KoelErrorCode.transportClosed` with `cause` non-null (the last failure). [Source: AC :108-110]
  - [x] **AC5 shouldRetry=false:** build `InterceptorChain(interceptors: [RetryInterceptor(shouldRetry: (e, n) => !(e is BusinessError && e.code == KoelErrorCode.businessAuth))], agent: _StubAgent(() => RunErrorEvent(BusinessError(message: 'auth', code: KoelErrorCode.businessAuth))))` and subscribe `chain.proceed(_input())`. Assert **zero** retries (the stub records exactly one run) and the **original** `BusinessError` surfaces immediately, unchanged. **Inject the error via the stub agent — do NOT add 401→businessAuth status classification** (AC5 clarification; Epic-5 scope). A small `_StubAgent implements AbstractAgent` emitting a single terminal event is the right fixture. [Source: AC :112-114; io_error_classifier.dart:31-34]
  - [x] **Backoff unit test** (Task 1): seeded `Random`, assert the schedule + jitter band + `maxDelay` clamp directly. [Source: AC :99]
  - [x] `dart:io` in the **test** file is fine (web-safety governs `lib/` only — 4.1/4.2/4.3 precedent). Keep delays tiny; the whole suite runs in well under a second. [Source: 4-3 Task 5]

- [x] **Task 7 — Quality gates (NO finalization gates this story)** (AC: all)
  - [x] `melos run analyze` → **0 issues** workspace-wide. Watch for `unused_element` on the `@internal forAgent` ctor / `retryBackoff` if you stage them before wiring — wire or omit (CLAUDE.md "no vestigial code"). [Source: NFR-13]
  - [x] `melos run test` → green workspace-wide, including the new `retry_interceptor_test.dart` and the unchanged `http_agent_test.dart`/`cancellation_test.dart`/`sse_parser_test.dart`. Re-ran the retry suite under `--test-randomize-ordering-seed=random` (timers/loops are order-sensitive). [Source: tool/test_package.sh; 4-3 review]
  - [x] `melos run format:check` → clean. [Source: tool/format.sh]
  - [x] **Do NOT** add koel_http's member `analysis_options.yaml` doc gate or the ≥ 90 % coverage gate — those are **package-finalization** gates that land in the epic-sealing **Story 4.10** (4.1/4.2/4.3 precedent). Wrote full dartdoc anyway so 4.10's doc gate needs no backfill. [Source: epic-4 overview; 4-3 Task 6]

## Dev Notes

### What this story is, in one paragraph

The story that makes `HttpAgent` **recover from transient failures**. Story 4.2 wired the run over an `InterceptorChain`; 4.3 made cancel prompt. 4.4 adds the first interceptor with real control flow: a `RetryInterceptor` that, when a run terminates in a retryable `RunErrorEvent`, waits an exponential-backoff + jittered delay and **re-runs the whole downstream** (a fresh re-POST / reconnect), up to `maxAttempts` reconnects. On a reconnect that produces data it injects a `ConnectionResumed` `CustomEvent` so the UI can show "reconnected"; on exhaustion it emits a terminal `TransportError(transportClosed)` carrying the last cause; a `shouldRetry` predicate (default: transport errors only) gates which failures retry. It **also** makes `HttpAgent`'s long-dead `retry:`/`onReconnectAttempt:` params live by auto-building a `RetryInterceptor.forAgent(...)` and prepending it (outermost, so it re-runs auth on each attempt — Story 4.5's hook). Scope is **the retry engine + its agent wiring only**: no web transport, no lifecycle hooks beyond `onReconnectAttempt`, no chunk synthesis, no logging interceptor.

### The retry mechanism — re-subscribe, don't re-plumb (RESOLVED — the design crux)

`Interceptor.intercept(chain, input)` may **wrap** the stream `chain.proceed(input)` returns, or **substitute** its own. `RetryInterceptor` substitutes a controller-backed stream that internally **re-calls `chain.proceed(input)`** per attempt:

```
intercept(chain, input):
  attempt = 0
  loop:
    sub = chain.proceed(input).listen(...)      // fresh reconnect each loop
      onEvent e:
        if attempt >= 1 and first-event-of-this-attempt:
          downstream.add(ConnectionResumed(attempt))   // AC3, lazy
        if e is RunErrorEvent:
          held = e; sub.cancel()                        // terminal error → decide
          if attempt < maxAttempts and shouldRetry(held.error, attempt+1):
            delay = retryBackoff(attempt+1, ...)
            onReconnectAttempt?(attempt+1, delay)        // AC2 (bridged from HttpAgent)
            timer = Timer(delay, () { attempt++; <re-enter loop> })   // cancellable
          else if attempt >= maxAttempts:
            downstream.add(RunErrorEvent(TransportError(transportClosed, cause: held.error)))  // AC4
            downstream.close()
          else:
            downstream.add(held); downstream.close()     // AC5 (non-retryable, unchanged)
        else:
          downstream.add(e)
      onDone: downstream.close()                         // success
```

Key correctness points, all RESOLVED:
- **`RunErrorEvent` is a value, not a throw** (trap #1). Watch the stream; never `try/catch` for retry.
- **Each `chain.proceed(input)` is a fresh reconnect** (trap #2). The advanced `chain` is reusable and immutable.
- **`ConnectionResumed` is lazy** — emitted on the first event of a *reconnect* attempt, so a reconnect that fails immediately produces none.
- **Cancellation:** `onCancel` cancels the live `sub` **and** the pending backoff `timer`; nothing is awaited on the cancel-return path (4.3 invariant; keeps NFR-8's <50ms cancel intact through this interceptor). A cancel mid-backoff must not reconnect.
- **Backpressure:** forward `onPause`/`onResume` to the live `sub` (mirror [cancellation.dart:64-69](packages/koel_http/lib/src/connection/cancellation.dart#L64-L69)).

### `maxAttempts` semantics — a worked table (RESOLVED — trap #6)

`maxAttempts` = max **retries** after the initial connection (NFR-7 "Maximum 5 reconnect attempts"). The _(maxAttempts+1)_-th failure exhausts.

| `maxAttempts` | initial | retry 1 | retry 2 | retry 3 | … | outcome |
| --- | --- | --- | --- | --- | --- | --- |
| 3 (AC2) | fail | fail | fail | **success** | — | run succeeds, 3 retries, `onReconnectAttempt` ×3 |
| 5 (default, AC4) | fail | fail | fail | fail | fail→**fail (6th)** | exhausted → `TransportError(transportClosed)` |

`onReconnectAttempt(attempt, delay)` fires when scheduling retry _attempt_ (1-based), with `delay` the actual jittered wait.

### `ConnectionResumed` is a `CustomEvent`, not a new type (RESOLVED — trap #3)

There is **no** `MetaEvent`/`ConnectionResumed` class in `koel_core` and you must **not** add one (the `AgUiEvent` union is `sealed` — a new subtype is a protocol-surface change, forward-compat policy FC-2). Use `CustomEvent(name: RetryInterceptor.connectionResumedEventName /* 'koel.connection_resumed' */, value: {'attempt': n})`. koel does not interpret `name`/`value`; the consumer matches the name to render a "reconnected" affordance. [Source: epic-4 :105; custom_event.dart:1-40; koel_error.dart:16-23 on `sealed` forward-compat]

### The two retry entry points (RESOLVED — trap #4/#5)

| Entry point | Defaults | Drives `onReconnectAttempt`? | `shouldRetry`? |
| --- | --- | --- | --- |
| `HttpAgent(retry: RetryPolicy(...))` | RetryPolicy's (3 / 500ms / bool jitter) → mapped | **Yes** (bridged via `forAgent`) | default only |
| `HttpAgent(interceptors: [RetryInterceptor(...)])` | A.2's (5 / 1s / 0.2) | No (engine has no public observer — A.2) | yes (ctor param) |

Both compose; a consumer wanting `shouldRetry` uses the explicit interceptor; one wanting the agent callback uses `retry:`. The `@internal forAgent` ctor is the only bridge between an `HttpAgent` callback and the engine — it is **not** barrel-exported, so consumers cannot reach it. [Source: addendum.md:289-322; reconnect_policy.dart:1-30]

### Out of scope — do NOT build these (RESOLVED)

- **Web transport / `BrowserClient` retry** → all retry logic is transport-agnostic (it re-runs the chain); web's *connection* lands in **Story 4.10**. Nothing platform-specific here; `retry_interceptor.dart` imports **no** `dart:io`. [Source: epic-4 Story 4.10]
- **`onConnect`/`onDisconnect` lifecycle hooks** → **Story 4.9**. A cancelled or retried run must **not** fire `onDisconnect` as an error here (those params stay dead until 4.9). Only `onReconnectAttempt` is wired this story. [Source: http_agent.dart:56-58; epic-4 Story 4.9 :215-236]
- **`AuthInterceptor` / token-refresh-on-retry** → **Story 4.5**. This story only guarantees the **ordering** (retry outermost) that 4.5 relies on. [Source: epic-4 Story 4.5 :116-139]
- **`LoggingInterceptor` / `EventTraceInterceptor`** → **Story 4.6** (a retry attempt is not logged here). **Chunk synthesis** → **4.8**. [Source: epic-4 :141-165,192-213]
- **Changing `RunPhase`/reducer for reconnect** → none. Subscribers see each attempt's events by design ([architecture.md:109](_bmad-output/planning-artifacts/architecture.md)); the reducer already maps `RunStartedEvent → RunPhase.running` idempotently ([chat_state_reducer.dart:71-74](packages/koel_core/lib/src/state/chat_state_reducer.dart#L71-L74)). No koel_core change. [Source: architecture.md:108-109; chat_state_reducer.dart:71-87]
- **Member `analysis_options.yaml` doc gate + ≥ 90 % coverage gate** → **Story 4.10** (epic-sealing). [Source: 4-1/4-2/4-3 precedent]

### Files you will touch

| Path | Action | Note |
| --- | --- | --- |
| [packages/koel_http/lib/src/interceptors/retry_interceptor.dart](packages/koel_http/lib/src/interceptors/retry_interceptor.dart) | NEW | `RetryInterceptor` (A.2 public ctor + `@internal forAgent`); `connectionResumedEventName`; pure `@visibleForTesting retryBackoff(...)`; default `_retryTransient`. Create the `interceptors/` dir. |
| [packages/koel_http/lib/src/http_agent.dart](packages/koel_http/lib/src/http_agent.dart) | MODIFY | store + wire `retry`/`onReconnectAttempt`; prepend `RetryInterceptor.forAgent(...)` (outermost) when `retry != null`; ctor dartdoc drops the 4.4 deferral. |
| [packages/koel_http/lib/src/connection/reconnect_policy.dart](packages/koel_http/lib/src/connection/reconnect_policy.dart) | MODIFY | dartdoc: engine now exists; map note (bool→double jitter); keep field defaults. |
| [packages/koel_http/lib/koel_http.dart](packages/koel_http/lib/koel_http.dart) | MODIFY | `export 'src/interceptors/retry_interceptor.dart';`. |
| `packages/koel_http/test/retry_interceptor_test.dart` | NEW | AC1 surface + AC2 fail-3-succeed/onReconnectAttempt + AC3 ConnectionResumed + AC4 exhaustion + AC5 shouldRetry=false + backoff unit test. |

### Library / framework requirements

- **Runtime:** `package:koel_core` (barrel) — `Interceptor`, `InterceptorChain`, `AgUiEvent`, `CustomEvent`, `RunErrorEvent`, `KoelError`/`TransportError`/`BusinessError`, `KoelErrorCode`, `RunAgentInput`, `AbstractAgent`; `package:http ^1.6.0` (only via `HttpAgent`/transport — `retry_interceptor.dart` itself needs no `http`); `package:meta ^1.16.0` (`@internal`, `@visibleForTesting`) — already a dep; `package:logging` — **not** used here (logging is Story 4.6). SDK: `dart:async` (`StreamController`/`StreamSubscription`/`Timer`), `dart:math` (`Random`, `min`, `pow`). **No new dependency.**
- **Dev:** `package:test ^1.25.0`, `package:http/testing.dart` (`MockClient` for the AC5 injected-error path), `dart:io` (test-only `HttpServer`/`IOClient`), `koel_test` (workspace, fixtures for the recovered-run body), `koel_lints` (workspace). `fake_async` is **not** introduced — tiny real `baseDelay` + jitter-band assertions keep the suite fast and deterministic (seeded `Random` for the unit test).
- **Forbidden in `lib/` (web-safety, framework-free):** `dart:io`/`dart:html`/`package:web` anywhere in `retry_interceptor.dart` (it is platform-neutral — retry re-runs the chain, not a socket); Flutter; `freezed`/`build_runner` (no codegen — the interceptor is a plain `final class`, `CustomEvent` is already generated in koel_core); any SSE/retry library. **No `print`.** [Source: architecture.md:587; CLAUDE.md]

### Project Structure Notes

- All changes stay within `koel_http`; **no koel_core change** (AC3 uses the existing `CustomEvent`; AC4 the existing `TransportError`; the reducer is untouched). SDK constraint stays `">=3.11.0 <4.0.0"`; no member `analysis_options.yaml` (gates are 4.10's).
- New `lib/src/interceptors/` dir matches the architecture file tree ([architecture.md:836-839](_bmad-output/planning-artifacts/architecture.md)); `retry_interceptor.dart` is the first of the six interceptors to land there (logging/auth/trace/sentry/pii follow in 4.5-4.7).
- Barrel discipline: `RetryInterceptor` IS public (A.2) → exported. `retryBackoff`/`forAgent` are package-internal by annotation (`@visibleForTesting`/`@internal`), reachable from the same-package test via the `src/` path import, never from a consumer.
- New test `test/retry_interceptor_test.dart` sits flat beside `test/http_agent_test.dart`/`test/cancellation_test.dart`.

### Previous Story Intelligence

- **Story 4.3** built `cancellation.dart` — the **controller + watchdog-`Timer` + cancel-correct teardown** pattern this story mirrors for the backoff timer + attempt subscription ([cancellation.dart:50-102](packages/koel_http/lib/src/connection/cancellation.dart#L50-L102)). It also established that **a cancel-return path must never `await`** transport teardown (NFR-8); the retry interceptor sits *above* `abortOnCancel`, so cancel still threads through to the live attempt's `response.abort()`. Added `meta`/`logging` deps (you reuse `meta`, not `logging`). [Source: [4-3 Dev Agent Record](4-3-cancellation-propagation.md)]
- **Story 4.2** built `HttpAgent` over `InterceptorChain` and reserved `retry:`/`onReconnectAttempt:` as accepted-but-ignored params for **this** story ([http_agent.dart:53-71](packages/koel_http/lib/src/http_agent.dart#L53-L71)); `RetryPolicy` is its pure data holder ([reconnect_policy.dart](packages/koel_http/lib/src/connection/reconnect_policy.dart)). `HttpAgent` stays the intentional non-`final` exception (Epic-5 subclasses). [Source: [4-2](4-2-http-agent-native-transport.md); reconnect_policy.dart:1-8]
- **Story 2.9** built `InterceptorChain` whose `proceed` **converts every error to a terminal `RunErrorEvent` value** and forwards cancel as a plain pipe ([interceptor.dart:102-127](packages/koel_core/lib/src/agent/interceptor.dart#L102-L127)). This is exactly why retry watches for `RunErrorEvent` rather than catching a throw (trap #1). [Source: interceptor.dart:60-137]
- **House style** (4.1/4.2/4.3, 3.x): `final class`/sealed where possible, `const` ctors, exhaustive dartdoc, table-driven `package:test`, tight change sets, no codegen, no finalization gates until the epic-sealing story, pure functions over hidden state. [Source: `git log`; 4-3 :175]

### Latest Tech Information

- **`dart:math` `Random`:** `Random([seed])` — a seeded `Random(7)` gives a reproducible `nextDouble()` sequence for the deterministic backoff unit test; production `RetryInterceptor` uses `Random()`. `pow(2, n)` returns `num` — cast/`toInt()` the exponent math, or compute the multiplier in `double` and clamp via `Duration(microseconds: …)`. Prefer integer-microsecond math to avoid float drift in the `Duration`.
- **`StreamController` re-subscription:** a single `StreamController` (the downstream the consumer holds) can front **many** sequential inner subscriptions (one per attempt) — only one inner `sub` is live at a time; cancel the previous before re-subscribing. This is the standard "retrying stream" shape; `async*` + `await for` is the WRONG tool (it strands cancel and can't inject `ConnectionResumed` cleanly — the same lesson 4.3 hit with `SseParser`). Use the explicit controller.
- **`Timer` cancellation:** hold the backoff `Timer` in a field; `onCancel` calls `timer?.cancel()`. A fired-then-cancelled timer is a no-op; a cancel during the wait must flip a guard so the scheduled re-subscribe does not run.
- **`CustomEvent` equality:** `value: {'attempt': n}` is deep-compared by freezed — two `ConnectionResumed`s with equal attempt maps are `==`. Tests can assert by `name` (and optionally `value['attempt']`). [Source: custom_event.dart:13-18]
- **Timing-test realism:** with `baseDelay: 2ms`, 5 retries total ≈ 2+4+8+16+32 = 62ms of backoff — fast. Assert `onReconnectAttempt` **counts** and per-step **jitter bands**, not wall-clock equality (CI scheduling jitter dwarfs a 2ms timer).

### References

- Story spec (ACs, A.2 signature, ConnectionResumed-as-CustomEvent, exhaustion shape, shouldRetry): [epic-4 Story 4.4](_bmad-output/planning-artifacts/epics/epic-4-http-transport-koelhttp.md) (lines 85-114); canonical `RetryInterceptor` ctor: [addendum.md §A.2](_bmad-output/planning-artifacts/prds/prd-koel-2026-05-27/addendum.md) (lines 314-322).
- Requirements: FR-B4 ([prd.md:150](_bmad-output/planning-artifacts/prds/prd-koel-2026-05-27/prd.md#L150)), NFR-7 ([prd.md:304](_bmad-output/planning-artifacts/prds/prd-koel-2026-05-27/prd.md#L304)), F-B6 hooks ([prd.md:152](_bmad-output/planning-artifacts/prds/prd-koel-2026-05-27/prd.md#L152)); "subscribers see each retry by design" ([architecture.md:108-109](_bmad-output/planning-artifacts/architecture.md)); interceptor naming + log levels ([architecture.md:464,589-590](_bmad-output/planning-artifacts/architecture.md)); file tree ([architecture.md:836-845](_bmad-output/planning-artifacts/architecture.md)).
- The interceptor contract + error-to-`RunErrorEvent` conversion (trap #1) + immutable-chain re-`proceed` (trap #2): [interceptor.dart:1-137](packages/koel_core/lib/src/agent/interceptor.dart).
- `CustomEvent` (ConnectionResumed): [custom_event.dart](packages/koel_core/lib/src/event/custom_event.dart). Error types: [koel_error.dart:28-122](packages/koel_core/lib/src/error/koel_error.dart), [koel_error_code.dart:13-63](packages/koel_core/lib/src/error/koel_error_code.dart), `RunErrorEvent` [run_events.dart:87-119](packages/koel_core/lib/src/event/run_events.dart#L87-L119).
- Wiring seam (dead params to make live): [http_agent.dart:53-98](packages/koel_http/lib/src/http_agent.dart#L53-L98); `RetryPolicy`: [reconnect_policy.dart:1-30](packages/koel_http/lib/src/connection/reconnect_policy.dart).
- Pattern to mirror (controller + watchdog timer + cancel-correct teardown): [cancellation.dart:50-102](packages/koel_http/lib/src/connection/cancellation.dart).
- Test exemplar (loopback SSE server, helpers, style): [http_agent_test.dart](packages/koel_http/test/http_agent_test.dart); reducer idempotency on duplicate `RunStarted`: [chat_state_reducer.dart:71-87](packages/koel_core/lib/src/state/chat_state_reducer.dart#L71-L87).

### Design decisions (RESOLVED — AC/architecture-forced, not open)

1. **Retry = re-`proceed`, watching for a terminal `RunErrorEvent` value** (not catching a throw) — the chain converts errors to values. [trap #1]
2. **Each `chain.proceed(input)` re-run is a fresh reconnect; duplicate lifecycle events are by design** (architecture.md:109); `ConnectionResumed` marks the seam, no mid-stream resume. [trap #2]
3. **`ConnectionResumed` = `CustomEvent(name: 'koel.connection_resumed', value: {'attempt': n})`** — no new `AgUiEvent` subtype (sealed union, FC-2). [trap #3]
4. **Story 4.4 wires `HttpAgent.retry` + `onReconnectAttempt`** (both prior dartdocs say so) via an **`@internal RetryInterceptor.forAgent(...)`** ctor; public ctor stays A.2-verbatim with no observer. [trap #4/#5]
5. **`maxAttempts` = max retries (reconnects); the (maxAttempts+1)-th failure exhausts** → terminal `TransportError(transportClosed, cause: lastError)`. [trap #6; AC4]
6. **Default `shouldRetry` retries only `TransportError`**; `businessAuth` (BusinessError) surfaces immediately; non-retryable errors forward **unchanged** (only exhaustion rewrites the code). [AC5; AC4]
7. **Auto-built retry is prepended (outermost)** so it re-runs `AuthInterceptor` on each attempt — Story 4.5's token-refresh hook. [trap #7]
8. **Pure, seeded-`Random`-injectable `retryBackoff` + tiny-delay tests; no `fake_async`.** [Task 1/6]
9. **No new dependency; `retry_interceptor.dart` is platform-neutral** (no `dart:io`); no `print`/`logging` (4.6). [lib requirements]
10. **No finalization gates** — analyze/test/format green only; doc + ≥90% coverage gates are 4.10's. [4-1/4-2/4-3 precedent]

These are baked in — implement them; no confirmation gate.

## Dev Agent Record

### Context Reference

<!-- Path(s) to story context will be added here by context workflow -->

### Agent Model Used

claude-opus-4-8[1m] (via `/bmad-dev-story` + `/agent-flutter-engineer` specialist)

### Debug Log References

- `melos run analyze` → 0 issues workspace-wide.
- `melos run test` → green workspace-wide (koel_core 575, koel_http 50, koel_lints 5, all packages SUCCESS).
- `dart test test/retry_interceptor_test.dart --test-randomize-ordering-seed=random` → 7/7 pass.
- `melos run format:check` → clean (0 changed after applying `dart format`).

### Completion Notes List

- **Retry = watch for a terminal `RunErrorEvent` value, re-call `chain.proceed(input)`** — never a `try/catch`, because `InterceptorChain.proceed` converts every downstream throw/stream-error into a trailing `RunErrorEvent` value (trap #1). The engine substitutes a single `StreamController` (`sync: true`, mirroring `cancellation.dart`) that fronts one inner subscription per attempt.
- **`maxAttempts` counts reconnects** (trap #6): initial connection is attempt 0; the `(maxAttempts+1)`-th failure exhausts → terminal `TransportError(transportClosed, cause: <last KoelError>)`. Decision order is `!shouldRetry → forward unchanged` **before** the exhaustion rewrite, so a non-retryable error is never rewritten to `transportClosed`.
- **`ConnectionResumed` = `CustomEvent(name: 'koel.connection_resumed', value: {'attempt': N})`** (trap #3), emitted **lazily** on the first *domain* event of a reconnect attempt — an attempt that fails before yielding data emits none. Exposed as `RetryInterceptor.connectionResumedEventName` (no magic string). No new `AgUiEvent` subtype; the sealed union is untouched.
- **Public ctor is A.2-verbatim** (5 named params, `double jitter`, no observer); the `HttpAgent` bridge uses a second `@internal RetryInterceptor.forAgent(... onReconnectAttempt)` ctor — not barrel-exported, so consumers cannot reach it (trap #4/#5).
- **`HttpAgent` prepends the auto-built retry interceptor (outermost)** when `retry != null` so reconnects re-run every user interceptor — the ordering Story 4.5 token-refresh relies on (trap #7). Bool `RetryPolicy.jitter` maps to the engine's fraction (`true → 0.2`, `false → 0.0`).
- **Cancellation-correct:** `onCancel` cancels the live attempt subscription **and** any pending backoff `Timer`; a `cancelled` guard stops a fired-but-pending timer from reconnecting. The cancel-return path adds no `await` beyond the inner `cancel()` (which bottoms out in `abortOnCancel`), preserving the 4.3 sub-50ms invariant.
- **`retryBackoff` is a pure, `@visibleForTesting`, `Random`-injectable** top-level function using integer-microsecond doubling that clamps at `maxDelay` before any int64 overflow (no float `pow`). Default `shouldRetry` (`_retryTransient`) retries **only** `TransportError`; `businessAuth`/protocol/agent errors surface immediately.
- **Scope held:** no web transport, no `onConnect`/`onDisconnect`, no `AuthInterceptor`, no logging, no koel_core change, no finalization gates (doc/coverage are Story 4.10). `retry_interceptor.dart` imports no `dart:io` — platform-neutral.

### File List

- `packages/koel_http/lib/src/interceptors/retry_interceptor.dart` (NEW) — `RetryInterceptor` engine (A.2 public ctor + `@internal forAgent`), `connectionResumedEventName`, pure `@visibleForTesting retryBackoff`, default `_retryTransient`.
- `packages/koel_http/lib/src/http_agent.dart` (MODIFY) — store + wire `retry`/`onReconnectAttempt`; prepend `RetryInterceptor.forAgent(...)` outermost in `run()`; ctor dartdoc drops the 4.4 deferral.
- `packages/koel_http/lib/src/connection/reconnect_policy.dart` (MODIFY) — dartdoc: engine now exists; two-entry-point/jitter-mapping note; field defaults unchanged.
- `packages/koel_http/lib/koel_http.dart` (MODIFY) — `export 'src/interceptors/retry_interceptor.dart';`.
- `packages/koel_http/test/retry_interceptor_test.dart` (NEW) — AC1 surface + AC2 fail-3-succeed/onReconnectAttempt×3 + AC3 ConnectionResumed + AC4 exhaustion + AC5 shouldRetry=false + backoff unit tests (7 tests).

## Change Log

| Date | Version | Description | Author |
| ---- | ------- | ----------- | ------ |
| 2026-05-31 | 0.1.0 | Story drafted — ultimate context engine analysis completed; comprehensive developer guide created | create-story |
| 2026-05-31 | 1.0.0 | Implemented `RetryInterceptor` (backoff + jitter + `ConnectionResumed`), wired `HttpAgent.retry`/`onReconnectAttempt`, refreshed `RetryPolicy` dartdoc, barrel export, 7-test suite. All 5 ACs satisfied; analyze/test/format green workspace-wide. Status → review. | dev-story |

## Review Findings

> Adversarial code review 2026-05-31 (Blind Hunter + Edge Case Hunter + Acceptance Auditor). All 5 ACs / 7 traps / 10 design decisions PASS (auditor). Analyze clean, 7/7 tests green. Findings below are robustness hardening; the two callback-hang and input-validation items are *empirically reproduced*, not theoretical.

- [x] [Review][Patch] A throwing user `shouldRetry` or `onReconnectAttempt` hangs the stream forever [packages/koel_http/lib/src/interceptors/retry_interceptor.dart:128,142] — **FIXED:** `shouldRetry` throw → `controller..addError..close()` (terminal `RunErrorEvent` via the chain transformer); `onReconnectAttempt` throw → swallowed. Added 2 regression tests. — Both callbacks run inside the inner subscription's `onData` handler, *outside* the chain transformer's error coverage (it wraps only the delegated downstream, not this interceptor's own listener body). A synchronous throw escapes to the zone as an uncaught error and `controller` is never closed → the consumer's `await for`/`toList()` blocks indefinitely. **Reproduced** via probe: both `shouldRetry`-throws and `onReconnectAttempt`-throws ⇒ `HUNG (never closed)`. Both are reachable public-API paths (`RetryInterceptor(shouldRetry:)`, `HttpAgent(onReconnectAttempt:)`). Recommended fix: guard the decision block — a `shouldRetry` throw routes to `controller..addError(e,s)..close()` (the outer chain transformer converts it to a terminal `RunErrorEvent`, honoring the kernel invariant); an `onReconnectAttempt` throw is swallowed (a fire-and-forget observer must not abort a recoverable run). Source: blind+edge.
- [x] [Review][Patch] No defensive `assert`s on constructor inputs [packages/koel_http/lib/src/interceptors/retry_interceptor.dart:49-57,67-76] — **FIXED:** added `assert(maxAttempts >= 0)`, `assert(!baseDelay.isNegative)`, `assert(jitter >= 0)` to both ctors (signature-preserving). — Neither ctor validates inputs. `maxAttempts < 0` makes `attempt < maxAttempts` instantly false → the first transient failure is silently rewritten to `transportClosed("after -1 retries")` with **zero** reconnects; `baseDelay <= Duration.zero` → a tight reconnect loop (bounded only by `maxAttempts`); `jitter` outside `[0,1]` distorts the band (negative inverts it, >1 can drive the factor negative — clamped to 0). No crash today (the `micros < 0 ? 0` guard saves negatives), but this violates the house principle "design for what users *can't* misuse." Fix: add `assert(maxAttempts >= 0)`, `assert(!baseDelay.isNegative)`, `assert(jitter >= 0)` to both ctors (asserts are zero-cost in release and preserve the A.2-verbatim signature). Source: edge.
- [x] [Review][Patch] `maxDelay` field dartdoc overstates the clamp [packages/koel_http/lib/src/interceptors/retry_interceptor.dart:90-91] — **FIXED:** reworded — the doubled *base* step is clamped; the jittered delay may exceed `maxDelay` by the jitter fraction. — The field doc says "Upper bound each backoff delay is clamped to," but jitter is applied *after* the clamp (the spec formula clamps `base`, then scales by `1±jitter`), so the effective max delay is `maxDelay·(1+jitter)` (e.g. 36s for a 30s cap at ±20%). The *code matches the spec* (Task 1 formula); only the prose is imprecise. Fix: reword to say the doubled *base step* is clamped to `maxDelay` and the jittered delay may exceed it by the jitter fraction. Source: blind+edge.
- [x] [Review][Defer] Multi-recovery (multiple `ConnectionResumed` markers) is untested [packages/koel_http/test/retry_interceptor_test.dart] — deferred. The engine correctly emits one resume marker per *recovered* reconnect, so a flap (recover → fail → recover) emits several; behavior is correct-by-design but only the single-recovery case (`hasLength(1)`) is covered. A follow-up test (recover-fail-recover) would pin the multi-marker contract. Not blocking.
