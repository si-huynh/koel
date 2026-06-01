---
baseline_commit: d050d0d31335ada85013e5739ad0d7752df350ac
---

# Story 4.5: `AuthInterceptor` (Bearer + custom headers via async callback)

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

> **Dev agent:** this is **Story 4.5 of Epic 4** (HTTP transport, `koel_http`). It adds the **first interceptor that influences the outgoing HTTP request**: a public `AuthInterceptor` that takes an **async header-builder callback** (`Future<Map<String, String>> Function()`), invokes it per run/attempt, and makes the resolved headers (Bearer token, custom headers) ride the outgoing POST. It touches `.dart` files and the interceptor/transport seam, so **invoke `/agent-flutter-engineer` before producing any code** (per [CLAUDE.md](CLAUDE.md)). `packages/koel_http/` already ships `SseParser` (4.1), `HttpAgent` + the transport seam (4.2), the cancellation `abortOnCancel` watchdog (4.3), and the `RetryInterceptor` engine + `HttpAgent.retry`/`onReconnectAttempt` wiring (4.4). **Six things are load-bearing, and the first two are traps that will sink a naïve reading of the AC:**
>
> 1. **An `Interceptor` can ONLY transform `RunAgentInput → Stream<AgUiEvent>` — it has NO direct path to the HTTP request headers, and `_TransportTerminal` currently HARD-CODES them.** This is THE central trap. `Interceptor.intercept(chain, input)` sees only the `RunAgentInput` and the event stream; the actual POST is built deep inside [`_TransportTerminal.run`](packages/koel_http/lib/src/http_agent.dart#L141-L154) with **`const {'Content-Type': …, 'Accept': …}`** headers. There is no seam today for an interceptor to add `Authorization`. The interceptor contract dartdoc explicitly says the **auth pattern transforms `input` first** ([interceptor.dart:20-22](packages/koel_core/lib/src/agent/interceptor.dart#L20-L22)) — so the resolved headers must **ride on the `RunAgentInput`** to reach the transport. [Source: interceptor.dart:18-22; http_agent.dart:141-154]
> 2. **`forwardedProps` is serialized into the POST BODY — so the carrier is `forwardedProps` under a koel-RESERVED key that `_TransportTerminal` extracts and STRIPS before encoding.** `encodeRunAgentInput` writes `forwardedProps` straight into the wire body ([run_agent_input_codec.dart:28](packages/koel_http/lib/src/wire/run_agent_input_codec.dart#L28)). A bearer token placed there naïvely would **leak into the request body** (a security defect) *and* duplicate into the header. The RESOLVED design (your seam decision): `AuthInterceptor` writes resolved headers to `input.forwardedProps[AuthInterceptor.transportHeadersKey]` via `copyWith`; `_TransportTerminal` reads that reserved key, **removes it from a copy of `forwardedProps` before `encodeRunAgentInput`** (so it NEVER hits the wire), and merges the headers into the request — **protocol headers (`Content-Type`/`Accept`) listed LAST so auth can never clobber them.** The codec stays pure (no auth knowledge); the strip lives in the transport. **No `koel_core` change** — `RunAgentInput` is untouched, so the `dart_apitool` API-diff gate ([api-diff.yml](.github/workflows/api-diff.yml)) is not tripped. [Source: run_agent_input_codec.dart:20-42; http_agent.dart:141-154; seam decision §"The header-injection seam"]
> 3. **The async callback's THROW must surface as `RunErrorEvent(BusinessError(code: businessAuth))` — and the chain classifier does this for free IF you throw a typed `KoelError`.** `DefaultErrorClassifier.classify` is **idempotent for already-typed errors** — `if (raw is KoelError) return raw;` ([error_classifier.dart:43-49](packages/koel_core/lib/src/error/error_classifier.dart#L43-L49)). So `AuthInterceptor` must catch the consumer callback's throw and re-throw a `BusinessError(message: …, code: KoelErrorCode.businessAuth, cause: <original>)` **through the stream**; the chain transformer converts that stream error to a terminal `RunErrorEvent(BusinessError(businessAuth))` ([interceptor.dart:113-126](packages/koel_core/lib/src/agent/interceptor.dart#L113-L126)). Do **not** build 401→`businessAuth` status classification here (that is Epic 5 — see AC4 clarification). [Source: error_classifier.dart:43-49; interceptor.dart:113-126; koel_error_code.dart:54-55]
> 4. **"Once per run OR once per retry attempt, configurable" is achieved by ORDERING, not a ctor param.** A.2 freezes the surface to exactly `AuthInterceptor({required Future<Map<String, String>> Function() headers})` — **no** `perAttempt` flag. The "configurable" knob is **composition**: `HttpAgent` prepends the auto-built `RetryInterceptor` **outermost** ([http_agent.dart:106-122](packages/koel_http/lib/src/http_agent.dart#L106-L122) — Story 4.4 trap #7), so the chain is `[retry, …auth…]`. On each reconnect, `retry` re-calls `chain.proceed(input)`, which re-runs `AuthInterceptor.intercept` → the callback **re-fires per attempt** (token refresh, AC4). With no retry configured, `intercept` runs once → **once per run**. koel's "composition > config" DNA. [Source: addendum.md:323-324; http_agent.dart:106-122; CLAUDE.md]
> 5. **Token-refresh-on-retry works on the CURRENT classifier — a 401 surfaces as `TransportError(transportClosed)`, which the DEFAULT `shouldRetry` already retries.** koel_http classifies any non-2xx as `TransportError(transportClosed, statusCode: 401)` today ([http_agent.dart:158-173](packages/koel_http/lib/src/http_agent.dart#L158-L173)); status-aware `401→businessAuth` is **Epic 5** ([error_classifier.dart:33-37](packages/koel_core/lib/src/error/error_classifier.dart#L33-L37)). The default `RetryInterceptor.shouldRetry` retries **all** `TransportError` ([retry_interceptor.dart:250](packages/koel_http/lib/src/interceptors/retry_interceptor.dart#L250)). So a plain `HttpAgent(retry: RetryPolicy(...), interceptors: [AuthInterceptor(...)])` already retries the 401, re-runs auth (trap #4), and re-POSTs with the fresh token. AC4's "RetryInterceptor configured to retry on 401" is satisfied by the **default** policy; no custom `shouldRetry` is required (you MAY pass one for intent clarity). [Source: http_agent.dart:158-173; retry_interceptor.dart:246-250; 4-4 AC4 clarification]
> 6. **Resolution is async but `intercept` returns a Stream synchronously — use `Stream.fromFuture(_resolve()).asyncExpand(...)`, NOT `async*`.** The callback is a `Future`; `intercept` must await it then delegate. `Stream.fromFuture(_resolve()).asyncExpand((h) => chain.proceed(input.copyWith(...)))` is single-subscription, **cancel-correct** (a cancel during the `_resolve()` await cancels the source and `chain.proceed` is never called → no transport opens; a cancel during the inner stream forwards to `chain.proceed` → bottoms out in `abortOnCancel`, preserving NFR-8), and routes a `_resolve()` throw as a stream error the chain classifies. There is no timer and no multi-subscription here, so the explicit `StreamController` ceremony 4.4 needed is **not** warranted. [Source: 4-3/4-4 cancel invariant; abortOnCancel; AC clarifications]

## Story

As a Flutter/Dart developer,
I want `AuthInterceptor` accepting an async header-builder callback (e.g., for token refresh),
so that auth schemes — Bearer, custom headers, token refresh — compose cleanly into the chain per FR-B2.

## Acceptance Criteria

Verbatim from [epic-4 Story 4.5](_bmad-output/planning-artifacts/epics/epic-4-http-transport-koelhttp.md) (lines 116-139):

1. **Given** `koel_http/lib/src/interceptors/auth_interceptor.dart`, **When** I inspect the constructor, **Then** it matches Addendum A.2: `AuthInterceptor({required Future<Map<String, String>> Function() headers})`, **And** the callback is invoked once per run (or once per retry attempt within a single run, configurable).

2. **Given** an `AuthInterceptor` with a callback returning `{'Authorization': 'Bearer abc123'}`, **When** a run executes, **Then** the outgoing HTTP request carries that header verbatim.

3. **Given** an async callback that throws, **When** the run starts, **Then** the chain emits `RunErrorEvent(BusinessError(code: KoelErrorCode.businessAuth))` with the underlying cause.

4. **Given** a token-refresh scenario where the first attempt 401s and the callback returns a fresh token, **When** combined with `RetryInterceptor` configured to retry on 401, **Then** the second attempt carries the refreshed token and the run succeeds.

> **AC clarifications (RESOLVED — do not re-litigate, implement):**
>
> - **AC1 surface:** the public ctor is **A.2-verbatim** — one required named param `headers` of type `Future<Map<String, String>> Function()`. The class is a `final class AuthInterceptor implements Interceptor` at the AC-named path `lib/src/interceptors/auth_interceptor.dart` (the `interceptors/` dir already exists from 4.4) and is **exported from the barrel** ([koel_http.dart](packages/koel_http/lib/koel_http.dart)) — `AuthInterceptor` is public API (A.2) and Epic-5's `AgnoAuthInterceptor extends AuthInterceptor` ([addendum.md:345-346](_bmad-output/planning-artifacts/prds/prd-koel-2026-05-27/addendum.md)). "**configurable** per-run vs per-attempt" is the **ordering** knob (trap #4), **not** a ctor param. [Source: addendum.md:323-324,345-346; architecture.md:840]
> - **AC1 "callback invoked once per run / per attempt":** test BOTH. Without retry: a counter the callback increments equals **1** after one `run().toList()`. With retry that recovers after N failures: the counter equals **N+1** (initial + N reconnects) because retry (outermost) re-runs auth each attempt (trap #4). [Source: AC :127; trap #4; 4-4 trap #7]
> - **AC2 "carries that header verbatim" + the no-leak invariant:** assert the loopback server's received request has `request.headers.value('Authorization') == 'Bearer abc123'`. **ALSO assert (security):** the decoded request **body**'s `forwardedProps` does **NOT** contain the reserved key (`AuthInterceptor.transportHeadersKey`) — the token never leaks to the wire (trap #2). Protocol headers (`Content-Type`/`Accept`) remain intact and are NOT overridable by auth (they are merged last). [Source: AC :129-131; trap #2]
> - **AC3 throwing callback → `BusinessError(businessAuth)`:** the consumer callback throws *any* `Object`; `AuthInterceptor` wraps it as `BusinessError(message: <fixed, no secret>, code: KoelErrorCode.businessAuth, cause: <original throw>)` and surfaces it as a stream error, which the chain classifier passes through (trap #3) to a terminal `RunErrorEvent`. Assert the single terminal event is `RunErrorEvent` whose `error is BusinessError && error.code == KoelErrorCode.businessAuth` and `error.cause` is the original throw. **No transport connection opens** (resolution fails before `chain.proceed`), so a `_StubAgent` terminal (mirror [retry_interceptor_test.dart:65-79](packages/koel_http/test/retry_interceptor_test.dart#L65-L79)) is the right fixture — do **not** stand up a server. [Source: AC :133-135; error_classifier.dart:43-49]
> - **AC4 token-refresh:** drive a flaky loopback server that returns **401** until it sees `Authorization: Bearer fresh`, then replays a real fixture body (200). The callback is a closure that returns `{'Authorization': 'Bearer stale'}` on its first call and `{'Authorization': 'Bearer fresh'}` thereafter. Run via `HttpAgent(url, retry: RetryPolicy(maxAttempts: 2, baseDelay: Duration(milliseconds: 2)), interceptors: [AuthInterceptor(headers: cb)])`. Assert: the run **succeeds** (terminal `RunFinishedEvent`, no terminal error), the server's **second** request carried `Bearer fresh`, and the callback fired **2** times. The **default** retry policy retries the 401 (it surfaces as `TransportError(transportClosed)` — trap #5); you MAY pass an explicit `shouldRetry: (e, _) => e is TransportError && e.statusCode == 401` to make the intent legible, but it is not required. [Source: AC :137-139; trap #5; http_agent.dart:158-173]
> - **AC4 — do NOT build 401→`businessAuth` classification (scope trap, shared with 4.4):** status-code-aware classification is **Epic 5** ([io_error_classifier.dart:31-34](packages/koel_http/lib/src/error/io_error_classifier.dart#L31-L34); error_classifier.dart:33-37). This story relies on the *existing* `transportClosed`-for-non-2xx behavior; it does not add status refinement. [Source: io_error_classifier.dart:31-60; error_classifier.dart:33-37]

## Tasks / Subtasks

- [x] **Task 0 — Read the real surfaces before writing a line** (AC: all — skipping this builds the wrong seam)
  - [x] Re-read [interceptor.dart](packages/koel_core/lib/src/agent/interceptor.dart) **in full** — the `Interceptor` contract (call `proceed` exactly once, MAY transform `input` first — the *auth* pattern), and `InterceptorChain.proceed` (lines 102-127): a stream error becomes a terminal `RunErrorEvent` via the classifier (trap #3); the chain is an immutable advanced cursor (trap #4 — retry re-`proceed`s through auth). [Source: interceptor.dart:1-137]
  - [x] Re-read [http_agent.dart](packages/koel_http/lib/src/http_agent.dart) — `_TransportTerminal.run` (lines 141-184) builds the POST with **hard-coded** `const` headers (trap #1) and `encodeRunAgentInput(input)` (line 143); `run()` prepends the retry interceptor **outermost** (lines 106-122) so auth re-runs per attempt (trap #4). You will modify `_TransportTerminal` to extract+strip the reserved header key and merge auth headers. [Source: http_agent.dart:104-184]
  - [x] Read [run_agent_input_codec.dart](packages/koel_http/lib/src/wire/run_agent_input_codec.dart) — `forwardedProps` is serialized into the body (line 28); `reasoningEcho` is the precedent for a koel-extension the codec treats specially. The reserved transport-headers key must be stripped **before** this runs (trap #2). [Source: run_agent_input_codec.dart:20-42]
  - [x] Read [run_agent_input.dart](packages/koel_core/lib/src/input/run_agent_input.dart) — `forwardedProps` is `@Default(<String, dynamic>{}) Map<String, dynamic>`, mutate via `copyWith` only; freezed deep-compares it. This is the carrier (trap #2); **do not modify this file** (no koel_core change). [Source: run_agent_input.dart:26-41]
  - [x] Read [error_classifier.dart](packages/koel_core/lib/src/error/error_classifier.dart) — `classify` returns an already-typed `KoelError` unchanged (lines 43-49); this is why throwing a `BusinessError(businessAuth)` through the stream is the correct AC3 mechanism (trap #3). [Source: error_classifier.dart:38-99]
  - [x] Read [koel_error.dart](packages/koel_core/lib/src/error/koel_error.dart) (`BusinessError({required message, required code, Object? cause, ...})`) + [koel_error_code.dart](packages/koel_core/lib/src/error/koel_error_code.dart) (`businessAuth`) + [run_events.dart](packages/koel_core/lib/src/event/run_events.dart) (`RunErrorEvent({required KoelError error})`). [Source: koel_error.dart:105-122; koel_error_code.dart:54-55]
  - [x] Read FR-B2 (`AuthInterceptor`) + architecture §D4 ([architecture.md:328-333](_bmad-output/planning-artifacts/architecture.md)) — the reason web (Story 4.10) uses fetch over `EventSource` is **so `AuthInterceptor` headers work uniformly**; your `forwardedProps`-key seam is transport-agnostic, so 4.10's `web_transport` will read the same reserved key (forward-compat, out of scope here). [Source: architecture.md:328-333; addendum.md:323-324]

- [x] **Task 1 — `AuthInterceptor` (the interceptor)** (AC: #1, #2, #3)
  - [x] In [auth_interceptor.dart](packages/koel_http/lib/src/interceptors/auth_interceptor.dart) (NEW) declare `final class AuthInterceptor implements Interceptor` with the **A.2-verbatim** ctor `AuthInterceptor({required Future<Map<String, String>> Function() headers})` (AC1). [Source: addendum.md:323-324]
  - [x] Add `static const String transportHeadersKey = 'koel.transport.headers';` — the koel-namespaced reserved `forwardedProps` key the transport extracts and strips (trap #2). Public so Epic-5 adapters and the transport share one constant (no magic string). Document it as transport-internal: written by `AuthInterceptor`, consumed+stripped by `HttpAgent`'s transport, **never on the wire**. [Source: trap #2; seam decision]
  - [x] Implement `intercept(chain, input)` as `Stream.fromFuture(_resolve()).asyncExpand((resolved) => chain.proceed(input.copyWith(forwardedProps: {...input.forwardedProps, transportHeadersKey: <merge of any existing reserved map + resolved>})))` (trap #6). Merge so stacked `AuthInterceptor`s compose (later wins on key collision): read `input.forwardedProps[transportHeadersKey]` (a `Map<String, String>?` if a prior auth ran), spread it, then spread `resolved`. [Source: trap #2/#6]
  - [x] `_resolve()`: `try { return await headers(); } catch (e, s) { Error.throwWithStackTrace(BusinessError(message: 'Authentication header resolution failed', code: KoelErrorCode.businessAuth, cause: e), s); }` — wrap ANY throw as the typed `businessAuth` failure (trap #3). The message is **fixed and secret-free** (architecture §5: error messages never embed user-controlled/secret input). [Source: AC :133-135; error_classifier.dart:43-49; koel_error.dart:31-34]
  - [x] Exhaustive dartdoc: the async-callback contract, the once-per-run/per-attempt-by-ordering note (trap #4), the `transportHeadersKey` round-trip + no-wire-leak guarantee, and the `businessAuth`-on-throw behavior. `final class` (no subclass-from-outside — but Epic-5 `AgnoAuthInterceptor extends AuthInterceptor`, so it must be **extensible**: use `class`, NOT `final class`, mirroring `HttpAgent`'s intentional non-`final` for Epic-5 subclassing). [Source: addendum.md:345-346; http_agent.dart:41-44 (the non-final precedent)]

- [x] **Task 2 — Wire the transport header seam in `_TransportTerminal`** (AC: #2)
  - [x] In [http_agent.dart](packages/koel_http/lib/src/http_agent.dart) (MODIFY) `_TransportTerminal.run`: before encoding, extract `final injected = input.forwardedProps[AuthInterceptor.transportHeadersKey];`. When non-null, build `authHeaders = (injected as Map).cast<String, String>()` and a `wireInput = input.copyWith(forwardedProps: {...input.forwardedProps}..remove(AuthInterceptor.transportHeadersKey))`; when null, `authHeaders = const {}` and `wireInput = input`. Encode `wireInput` (NOT `input`) so the reserved key never reaches the body (trap #2). [Source: http_agent.dart:141-154; trap #2]
  - [x] Change the request `headers:` from the `const {…}` to `{...authHeaders, 'Content-Type': 'application/json', 'Accept': 'text/event-stream'}` — **protocol headers last** so auth can add `Authorization`/custom headers but can never clobber `Content-Type`/`Accept` (a clobbered `Accept` would break SSE). [Source: trap #2; http_agent.dart:146-150]
  - [x] Import `interceptors/auth_interceptor.dart` in `http_agent.dart` for the `transportHeadersKey` constant (it already imports `interceptors/retry_interceptor.dart`). No new public surface on `HttpAgent`. [Source: http_agent.dart:1-13]

- [x] **Task 3 — Keep the codec pure (defense-in-depth comment only)** (AC: #2)
  - [x] In [run_agent_input_codec.dart](packages/koel_http/lib/src/wire/run_agent_input_codec.dart) (MODIFY) add a one-line dartdoc/comment near the `forwardedProps` line: koel-reserved transport keys (e.g. `AuthInterceptor.transportHeadersKey`) are stripped by `_TransportTerminal` **before** this codec runs, so they never reach the wire; the codec itself does not special-case them. **No logic change** — the strip lives in the transport (Task 2), keeping the codec auth-agnostic. [Source: run_agent_input_codec.dart:20-29; trap #2]

- [x] **Task 4 — Export `AuthInterceptor` from the barrel** (AC: #1)
  - [x] In [koel_http.dart](packages/koel_http/lib/koel_http.dart) (MODIFY) add `export 'src/interceptors/auth_interceptor.dart';` (keep alphabetical/grouped with `retry_interceptor`). `AuthInterceptor` IS public API (A.2). The `transportHeadersKey` rides along as a documented public `static const`. [Source: koel_http.dart:1-6; addendum.md:323-324]

- [x] **Task 5 — `auth_interceptor_test.dart` (all 4 AC scenarios + no-leak)** (AC: #1, #2, #3, #4)
  - [x] New `packages/koel_http/test/auth_interceptor_test.dart` (`package:test`; reuse the [http_agent_test.dart](packages/koel_http/test/http_agent_test.dart) helper style — `_sseServer`/`_sseBody`/`_fixturePayloads`/`_serverUri`/`_input`, ephemeral loopback `HttpServer`, `addTearDown`). [Source: http_agent_test.dart:14-68]
  - [x] **AC1 surface + invocation count:** assert `AuthInterceptor(headers: () async => const {})` is an `Interceptor`. Drive one no-retry run with a callback that increments a counter; assert counter == **1** (once per run). [Source: AC :125-127]
  - [x] **AC2 header verbatim + no wire leak:** a loopback server that captures `request.headers.value('Authorization')` AND the decoded body. Run `HttpAgent(url, interceptors: [AuthInterceptor(headers: () async => {'Authorization': 'Bearer abc123'})])`. Assert: captured `Authorization == 'Bearer abc123'`; `Content-Type`/`Accept` unchanged; the body's `forwardedProps` does **NOT** contain `AuthInterceptor.transportHeadersKey` (security). [Source: AC :129-131; trap #2]
  - [x] **AC3 throwing callback:** `AuthInterceptor(headers: () async => throw StateError('no token'))` over an `InterceptorChain(interceptors: [auth], agent: _StubAgent(...))` (transport-free — resolution fails first). Assert the single terminal event is `RunErrorEvent` whose `error is BusinessError && error.code == KoelErrorCode.businessAuth`, and `error.cause is StateError`. [Source: AC :133-135; retry_interceptor_test.dart:65-79]
  - [x] **AC4 token-refresh-on-retry:** flaky server returns 401 until `Authorization == 'Bearer fresh'`, then replays a `text_only_run` fixture (200). Callback returns `Bearer stale` then `Bearer fresh`. Run `HttpAgent(url, retry: RetryPolicy(maxAttempts: 2, baseDelay: Duration(milliseconds: 2)), interceptors: [AuthInterceptor(headers: cb)])`. Assert: run succeeds (`RunFinishedEvent`, no terminal `RunErrorEvent`), the server's 2nd request carried `Bearer fresh`, callback fired **2** times (per-attempt re-auth — also covers AC1's per-attempt clause). [Source: AC :137-139; trap #4/#5]
  - [x] `dart:io` in the **test** file is fine (web-safety governs `lib/` only — 4.1/4.2/4.3/4.4 precedent). Keep delays tiny; the whole suite runs well under a second. [Source: 4-4 Task 6]

- [x] **Task 6 — Quality gates (NO finalization gates this story)** (AC: all)
  - [x] `melos run analyze` → **0 issues** workspace-wide. Watch for `unused_*` if you stage the constant before wiring — wire or omit (CLAUDE.md "no vestigial code"). [Source: NFR-13]
  - [x] `melos run test` → green workspace-wide, including the new `auth_interceptor_test.dart` and the unchanged `http_agent_test.dart`/`retry_interceptor_test.dart`/`cancellation_test.dart`/`sse_parser_test.dart`. Re-run the auth suite under `--test-randomize-ordering-seed=random`. [Source: tool/test; 4-4 review]
  - [x] `melos run format:check` → clean. [Source: tool/format]
  - [x] **`dart_apitool` API-diff is NOT a concern:** no `koel_core` public surface changes (trap #2 — `RunAgentInput` untouched); `AuthInterceptor` is an *additive* `koel_http` public symbol. [Source: api-diff.yml; trap #2]
  - [x] **Do NOT** add koel_http's member `analysis_options.yaml` doc gate or the ≥ 90 % coverage gate — those are **package-finalization** gates that land in the epic-sealing **Story 4.10** (4.1-4.4 precedent). Write full dartdoc anyway so 4.10's doc gate needs no backfill. [Source: epic-4 overview; 4-4 Task 7]

### Review Findings

_Adversarial code review 2026-06-01 (Blind Hunter + Edge Case Hunter + Acceptance Auditor). Acceptance Auditor: all 4 ACs + 10 RESOLVED decisions + out-of-scope list PASS. Edge Case Hunter verified-by-code and refuted several Blind Hunter findings (cancellation, retry accumulation, protocol-clobber on the default client) — those are dismissed below._

- [x] [Review][Decision→Patch] Reserved transport-key type collision lands in `AgentError(unknown)` — **RESOLVED (user chose harden): applied.** `transportHeadersKey` is a PUBLIC documented constant; if a non-`AuthInterceptor` caller or an Epic-5 adapter parks a non-`Map` value (or a `Map` with non-`String` values) under it, the old `(injected as Map).cast<String, String>()` in `_TransportTerminal.run` threw a raw `TypeError` mid-stream → `DefaultErrorClassifier` default arm → mislabeled `AgentError(unknown)` 'Unclassified failure'. **Fix:** `_TransportTerminal.run` now guards `injected is! Map<String, String>` and throws a typed `AgentError(message: 'Reserved transport-headers key carried a non-Map<String, String> value', code: unknown)` (secret-free, no `cause` — the value could carry a token); the classifier passes the typed error through to a precise terminal `RunErrorEvent`. ([http_agent.dart:150-166](packages/koel_http/lib/src/http_agent.dart#L150-L166)) (sources: blind+edge)
- [x] [Review][Patch] Missing test for stacked `AuthInterceptor` composition + other uncovered branches — **applied.** Added 3 tests to [auth_interceptor_test.dart](packages/koel_http/test/auth_interceptor_test.dart): (1) stacked `AuthInterceptor`s compose, outer (later) wins on collision, both unique headers ride, reserved key still stripped from body; (2) foreign non-Map reserved value → typed `AgentError(unknown)` with precise message, no transport opens (covers the hardening above); (3) lowercase `accept`/`content-type` from the callback cannot clobber protocol headers (proves protocol-last end-to-end with the real http client). Suite now 8 tests, green under `--test-randomize-ordering-seed=random`. _Not added (low ROI / refuted): cancellation-during-`_resolve()` (asyncExpand semantics + 4.3 cancellation_test already cover it) and empty-map-strip (behaviorally identical to the asserted non-empty case)._
- [x] [Review][Defer] Protocol-header clobber-protection lives in the http client's case-insensitive map, not koel's own merge [http_agent.dart:165](packages/koel_http/lib/src/http_agent.dart#L165) — deferred, forward-looking. koel builds `{...authHeaders, 'Content-Type': …, 'Accept': …}` in a case-SENSITIVE Dart map, so a lowercase `accept` from a callback survives as a distinct key; protocol headers win on the wire only because `http`'s `BaseRequest.headers` is case-insensitive and the protocol keys are inserted last (verified against http 1.6.0). Safe with the default transport; a hypothetical case-sensitive custom client could put both `accept` and `Accept` on the wire and break SSE. Not reachable with current code.

## Dev Notes

### What this story is, in one paragraph

The story that lets a consumer **authenticate every run** by composing an interceptor instead of configuring the agent. `AuthInterceptor` takes an async header-builder (`Future<Map<String, String>> Function()`) — a closure that can mint a Bearer token, read a keychain, or refresh on demand — invokes it per attempt, and threads the resolved headers onto the outgoing POST. The hard part is the **seam**: an `Interceptor` only transforms `RunAgentInput → Stream`, but the POST headers are built inside `_TransportTerminal`. The resolved design carries the headers on `input.forwardedProps` under a koel-reserved key, which `_TransportTerminal` extracts and **strips before encoding the body** (so the token never leaks to the wire), then merges into the request — protocol headers winning. A throwing callback becomes a terminal `RunErrorEvent(BusinessError(businessAuth))`. Token-refresh-on-retry falls out for free: 4.4 prepends `RetryInterceptor` outermost, so each reconnect re-runs auth and re-mints the token. Scope is **the auth interceptor + its transport seam only**: no `AgnoAuthInterceptor` (Epic 5), no 401→`businessAuth` status classification (Epic 5), no web transport (4.10), no logging/sentry (4.6/4.7).

### The header-injection seam (RESOLVED — the design crux)

An `Interceptor.intercept(chain, input)` cannot reach the HTTP request — it sees only `RunAgentInput` and the event stream. The carrier from interceptor → transport is therefore the `RunAgentInput` itself (the interceptor contract dartdoc names this "the auth pattern: transform `input` first"). `forwardedProps` is the natural free-form bag, but it is serialized into the body, so the token is carried under a **koel-reserved key** and **stripped before encoding**:

```
AuthInterceptor.intercept(chain, input):
  return Stream.fromFuture(_resolve()).asyncExpand((resolved) =>
    chain.proceed(input.copyWith(forwardedProps: {
      ...input.forwardedProps,
      transportHeadersKey: { ...?existingReserved(input), ...resolved },  // never on wire
    })));

_TransportTerminal.run(input):                       // runs after auth, inside the chain
  injected   = input.forwardedProps[AuthInterceptor.transportHeadersKey]
  authHeaders= injected == null ? {} : (injected as Map).cast<String,String>()
  wireInput  = injected == null ? input
             : input.copyWith(forwardedProps: {...input.forwardedProps}..remove(key))
  body       = encode(wireInput)                      // reserved key STRIPPED → no leak
  headers    = { ...authHeaders, 'Content-Type': …, 'Accept': … }   // protocol wins
```

Key correctness points, all RESOLVED:
- **The token never reaches the wire body** — `_TransportTerminal` encodes `wireInput` (reserved key removed), not `input` (trap #2). The AC2 test asserts this directly.
- **Protocol headers are merged last** — auth may add `Authorization` / custom headers but can never clobber `Content-Type`/`Accept` (a clobbered `Accept` breaks SSE).
- **The codec stays auth-agnostic** — the strip lives in the transport, not the codec; the codec only gains a comment (Task 3).
- **No koel_core change** — `RunAgentInput` is untouched; `forwardedProps`/`copyWith` already exist. No `dart_apitool` diff, no freezed regen.
- **Cancellation-correct** — `Stream.fromFuture(...).asyncExpand(...)` forwards cancel to `chain.proceed` (→ `abortOnCancel`); a cancel during `_resolve()` opens no transport (trap #6). The 4.3 sub-50ms invariant holds.

### Why `forwardedProps`-reserved-key over the alternatives (RESOLVED — the seam decision)

| Approach | koel_core change? | Wire leak? | Magic? | Verdict |
| --- | --- | --- | --- | --- |
| **`forwardedProps` reserved key + strip (CHOSEN)** | No | No (stripped) | No | Self-contained in `koel_http`; matches the "auth transforms input" contract; no API-diff trip |
| New non-wire field on `RunAgentInput` | **Yes** (frozen kernel; API-diff gate; freezed regen) | No | No | Rejected — couples the protocol kernel to an HTTP concern |
| Zone values | No | No | **Yes** (hidden state) | Rejected — violates "explicit lifecycle > magic / pure functions > hidden state" |

The reserved key is exposed as a documented public `static const AuthInterceptor.transportHeadersKey` so it is a legible contract (Epic-5 adapters and the web transport in 4.10 read the same constant), not a magic string. [Source: seam decision; interceptor.dart:18-22; CLAUDE.md]

### Once-per-run vs once-per-attempt — by ordering, not config (RESOLVED — trap #4)

A.2 has no `perAttempt` flag. The behavior is set by where auth sits relative to retry:

| Composition | Callback fires | Mechanism |
| --- | --- | --- |
| `interceptors: [AuthInterceptor(...)]`, no `retry:` | **once per run** | `intercept` runs once |
| `HttpAgent(retry: ..., interceptors: [AuthInterceptor(...)])` | **once per attempt** | `HttpAgent` prepends retry **outermost**; each reconnect re-`proceed`s through auth (4.4 trap #7) |

This is the AC1 "configurable" clause and the AC4 token-refresh mechanism, both for free from 4.4's wiring. [Source: http_agent.dart:106-122; addendum.md:323-324]

### `BusinessError(businessAuth)` on throw — classifier passthrough (RESOLVED — trap #3)

`AuthInterceptor` wraps any callback throw as a typed `BusinessError(code: businessAuth, cause: <original>)` and re-throws it through the stream via `Error.throwWithStackTrace`. The chain transformer routes the stream error to `classifier.classify`, which returns an already-typed `KoelError` unchanged ([error_classifier.dart:43-49](packages/koel_core/lib/src/error/error_classifier.dart#L43-L49)) → terminal `RunErrorEvent(BusinessError(businessAuth))`. Do **not** emit `RunErrorEvent` yourself (let the chain own the terminal contract), and do **not** rely on status-code classification (Epic 5). The message is fixed and secret-free (architecture §5). [Source: error_classifier.dart:38-99; interceptor.dart:113-126]

### Out of scope — do NOT build these (RESOLVED)

- **`AgnoAuthInterceptor extends AuthInterceptor`** → **Epic 5** (Story 5.2). This story only guarantees `AuthInterceptor` is **extensible** (`class`, not `final class`) so 5.2 can subclass it. [Source: addendum.md:345-346; epic-5 5.2]
- **401→`businessAuth` HTTP-status classification** → **Epic 5**. A 401 here surfaces as `TransportError(transportClosed, statusCode: 401)` and that is sufficient for AC4 (default retry retries it). [Source: error_classifier.dart:33-37; io_error_classifier.dart:31-34]
- **Web transport header flow** → **Story 4.10**. The seam is transport-agnostic; `web_transport` will read the same `transportHeadersKey`. Nothing platform-specific here — `auth_interceptor.dart` imports **no** `dart:io`. [Source: architecture.md:328-333; epic-4 Story 4.10]
- **`LoggingInterceptor`/`EventTraceInterceptor`** → **4.6**; **Sentry/PII** → **4.7**; **chunk synthesis** → **4.8**; **`onConnect`/`onDisconnect`** → **4.9**. No logging of headers/tokens here. [Source: epic-4 :141-236]
- **Any `koel_core` change** (a new `RunAgentInput` field, a new error code) → none. The seam is `forwardedProps` + an existing `businessAuth` code. [Source: seam decision]
- **Member `analysis_options.yaml` doc gate + ≥ 90 % coverage gate** → **Story 4.10** (epic-sealing). [Source: 4-1/4-2/4-3/4-4 precedent]

### Files you will touch

| Path | Action | Note |
| --- | --- | --- |
| [packages/koel_http/lib/src/interceptors/auth_interceptor.dart](packages/koel_http/lib/src/interceptors/auth_interceptor.dart) | NEW | `class AuthInterceptor implements Interceptor` (A.2 ctor, **not** `final` — Epic-5 subclasses); `static const transportHeadersKey`; `Stream.fromFuture(_resolve()).asyncExpand(...)`; `_resolve()` wraps throw → `BusinessError(businessAuth)`. |
| [packages/koel_http/lib/src/http_agent.dart](packages/koel_http/lib/src/http_agent.dart) | MODIFY | `_TransportTerminal.run`: extract + **strip** `transportHeadersKey` from a `forwardedProps` copy before encoding; merge `authHeaders` into request headers (protocol last). Import `interceptors/auth_interceptor.dart`. No `HttpAgent` public-surface change. |
| [packages/koel_http/lib/src/wire/run_agent_input_codec.dart](packages/koel_http/lib/src/wire/run_agent_input_codec.dart) | MODIFY | Comment only: reserved transport keys are stripped by the transport before encoding; codec stays auth-agnostic. |
| [packages/koel_http/lib/koel_http.dart](packages/koel_http/lib/koel_http.dart) | MODIFY | `export 'src/interceptors/auth_interceptor.dart';`. |
| `packages/koel_http/test/auth_interceptor_test.dart` | NEW | AC1 surface+count + AC2 header-verbatim/no-leak + AC3 throw→businessAuth + AC4 token-refresh-on-retry. |

### Library / framework requirements

- **Runtime:** `package:koel_core` (barrel) — `Interceptor`, `InterceptorChain`, `AgUiEvent`, `RunAgentInput` (+ `copyWith`/`forwardedProps`), `RunErrorEvent`, `BusinessError`, `KoelError`, `KoelErrorCode`; `package:http ^1.6.0` (only via the transport — `auth_interceptor.dart` itself needs no `http`); SDK `dart:async` (`Stream.fromFuture`, `asyncExpand`). **No new dependency.** `package:meta` is **not** needed (no `@internal` bridge — unlike 4.4, the seam is `forwardedProps`, and `transportHeadersKey` is intentionally public). `package:logging` — **not** used (logging is 4.6).
- **Dev:** `package:test ^1.25.0`, `dart:io` (test-only loopback `HttpServer`), `koel_test` (workspace, `text_only_run` fixture for the recovered-run body), `koel_lints` (workspace). No `fake_async` (tiny real `baseDelay`; counts/asserts, not wall-clock).
- **Forbidden in `lib/` (web-safety, framework-free):** `dart:io`/`dart:html`/`package:web` anywhere in `auth_interceptor.dart` (it is platform-neutral — it only transforms `input`); Flutter; `freezed`/`build_runner` (no codegen — plain `class`); any auth/OAuth library. **No `print`.** Error messages carry **no secrets** (no token echoed into `BusinessError.message`). [Source: architecture.md:587; CLAUDE.md]

### Project Structure Notes

- All changes stay within `koel_http`; **no koel_core change** (the seam is `forwardedProps` + existing `businessAuth`). SDK constraint stays `">=3.11.0 <4.0.0"`; no member `analysis_options.yaml` (gates are 4.10's).
- `auth_interceptor.dart` is the **second** interceptor in `lib/src/interceptors/` after `retry_interceptor.dart` (4.4); logging/trace/sentry/pii follow in 4.6-4.7 ([architecture.md:836-842](_bmad-output/planning-artifacts/architecture.md)).
- Barrel discipline: `AuthInterceptor` (and its `transportHeadersKey`) IS public (A.2) → exported. The transport seam reads the public constant — no `src/`-path coupling beyond the existing intra-package import in `http_agent.dart`.
- New test `test/auth_interceptor_test.dart` sits flat beside `test/retry_interceptor_test.dart`/`test/http_agent_test.dart`/`test/cancellation_test.dart`.

### Previous Story Intelligence

- **Story 4.4** prepends the auto-built `RetryInterceptor` **outermost** ([http_agent.dart:106-122](packages/koel_http/lib/src/http_agent.dart#L106-L122)) *expressly so retry re-runs auth on each attempt* — its Dev Notes call out "Story 4.5's token-refresh hook" (trap #7). 4.5 consumes that ordering directly: AC4 needs no new wiring. 4.4 also established the `_StubAgent` test fixture for injecting typed terminal errors without a server ([retry_interceptor_test.dart:65-79](packages/koel_http/test/retry_interceptor_test.dart#L65-L79)) — reuse it for AC3. [Source: 4-4 Dev Agent Record; retry_interceptor_test.dart]
- **Story 4.2** built `_TransportTerminal` with **hard-coded** `const` request headers ([http_agent.dart:146-150](packages/koel_http/lib/src/http_agent.dart#L146-L150)) and the `encodeRunAgentInput` codec ([run_agent_input_codec.dart](packages/koel_http/lib/src/wire/run_agent_input_codec.dart)). 4.5 turns those const headers into a merge point and teaches the transport to strip the reserved key before encoding. `HttpAgent` stays the intentional non-`final` exception (Epic-5 subclasses) — mirror that for `AuthInterceptor`. [Source: 4-2; http_agent.dart:41-44,141-184]
- **Story 2.9** built `InterceptorChain` whose `proceed` converts every error to a terminal `RunErrorEvent` value and whose classifier passes a typed `KoelError` through unchanged — the mechanism AC3 relies on ([interceptor.dart:102-127](packages/koel_core/lib/src/agent/interceptor.dart#L102-L127); [error_classifier.dart:43-49](packages/koel_core/lib/src/error/error_classifier.dart#L43-L49)). [Source: 2-9; interceptor.dart]
- **House style** (4.1-4.4, 3.x): `final`/`sealed` where possible (but `class` where Epic-5 must subclass), `const` ctors, exhaustive dartdoc, table-driven `package:test`, tight change sets, no codegen, no finalization gates until the epic-sealing story, composition over config, pure transforms over hidden state. [Source: `git log`; 4-4 :205]

### Latest Tech Information

- **`Stream.fromFuture` + `asyncExpand`:** `Stream.fromFuture(f)` is single-subscription and emits `f`'s value (or routes its error to the stream). `asyncExpand((v) => innerStream)` is single-subscription, awaits/forwards backpressure, and **forwards `cancel` to the inner stream** — the correct primitive for "await a value, then delegate to a stream" with no `async*` cancel-stranding. A cancel before the future completes cancels the source and never builds the inner stream (no transport opens). [Source: dart:async]
- **`Error.throwWithStackTrace(error, stack)`:** re-throws `error` preserving the original `stack` (Dart ≥ 2.16) — use it in `_resolve()` so the `BusinessError` carries the callback's original stack for diagnostics, with `cause` holding the original throw object. [Source: dart:core]
- **`Map.cast<String, String>()`:** the reserved-key value is stored as `Map<String, String>` (runtime type preserved through `forwardedProps`'s `Map<String, dynamic>` — never JSON round-tripped), so `(injected as Map).cast<String, String>()` is a safe view in `_TransportTerminal`. [Source: dart:core]
- **`forwardedProps` deep-equality:** freezed deep-compares `forwardedProps`, so injecting the reserved key changes input identity (expected); the stripped `wireInput` differs from `input` by exactly that key. [Source: run_agent_input.dart:11-17]
- **No `dart_apitool` exposure:** `RunAgentInput` is unchanged, so the koel_core baseline ([packages/koel_core/.api-baseline/koel_core.json](packages/koel_core/.api-baseline/koel_core.json)) is untouched; `AuthInterceptor` is additive to koel_http (no published baseline yet). [Source: api-diff.yml]

### References

- Story spec (ACs, A.2 signature, throw→businessAuth, token-refresh): [epic-4 Story 4.5](_bmad-output/planning-artifacts/epics/epic-4-http-transport-koelhttp.md) (lines 116-139); canonical `AuthInterceptor` ctor: [addendum.md §A.2](_bmad-output/planning-artifacts/prds/prd-koel-2026-05-27/addendum.md) (lines 323-324); `AgnoAuthInterceptor` (Epic-5 subclass): addendum.md:345-346.
- Requirements: FR-B2 (`AuthInterceptor`); web-needs-fetch-for-auth rationale ([architecture.md:328-333](_bmad-output/planning-artifacts/architecture.md)); interceptor naming ([architecture.md:464](_bmad-output/planning-artifacts/architecture.md)); file tree ([architecture.md:836-842](_bmad-output/planning-artifacts/architecture.md)); interceptors-transform-input ([architecture.md:528](_bmad-output/planning-artifacts/architecture.md)).
- The interceptor contract + error-to-`RunErrorEvent` + classifier passthrough (traps #1/#3): [interceptor.dart:1-137](packages/koel_core/lib/src/agent/interceptor.dart), [error_classifier.dart:38-99](packages/koel_core/lib/src/error/error_classifier.dart).
- The seam to modify (hard-coded headers + codec): [http_agent.dart:141-184](packages/koel_http/lib/src/http_agent.dart), [run_agent_input_codec.dart](packages/koel_http/lib/src/wire/run_agent_input_codec.dart); the carrier: [run_agent_input.dart:26-41](packages/koel_core/lib/src/input/run_agent_input.dart).
- Retry ordering that re-runs auth per attempt (trap #4): [http_agent.dart:104-128](packages/koel_http/lib/src/http_agent.dart#L104-L128); [retry_interceptor.dart:246-250](packages/koel_http/lib/src/interceptors/retry_interceptor.dart).
- Error types: [koel_error.dart:105-122](packages/koel_core/lib/src/error/koel_error.dart) (`BusinessError`), [koel_error_code.dart:54-55](packages/koel_core/lib/src/error/koel_error_code.dart) (`businessAuth`).
- Test exemplars (loopback SSE server, helpers, `_StubAgent`, flaky-server pattern): [http_agent_test.dart](packages/koel_http/test/http_agent_test.dart), [retry_interceptor_test.dart](packages/koel_http/test/retry_interceptor_test.dart).

### Design decisions (RESOLVED — AC/architecture-forced, not open)

1. **Header seam = `forwardedProps[AuthInterceptor.transportHeadersKey]`, stripped by `_TransportTerminal` before encoding** — self-contained in koel_http, no wire leak, no koel_core change, no zone magic. [seam decision; trap #2]
2. **Resolved headers ride on `input.copyWith(forwardedProps: …)`; `_TransportTerminal` merges them with protocol headers LAST** (auth can't clobber `Content-Type`/`Accept`). [trap #2]
3. **The codec stays auth-agnostic** — strip lives in the transport; codec gains a comment only. [Task 3]
4. **Async resolution via `Stream.fromFuture(_resolve()).asyncExpand(...)`** — single-subscription, cancel-correct (NFR-8 preserved), no `async*`, no `StreamController` ceremony. [trap #6]
5. **A throw → `BusinessError(code: businessAuth, cause: original)` re-thrown through the stream; the chain classifier passthrough makes the terminal `RunErrorEvent(BusinessError(businessAuth))`** — no manual `RunErrorEvent`, no status classification. Message carries no secret. [trap #3; AC3]
6. **Once-per-run vs once-per-attempt is composition (ordering vs `RetryInterceptor`), not a ctor param** — A.2 has exactly one param. [trap #4; AC1]
7. **Token-refresh-on-retry uses the existing `transportClosed`-for-401 + default `shouldRetry`** — no custom predicate required; 4.4's outermost-retry ordering re-runs auth. [trap #5; AC4]
8. **`AuthInterceptor` is `class` (not `final class`)** so Epic-5 `AgnoAuthInterceptor` can extend it — mirroring `HttpAgent`'s intentional non-`final`. [addendum.md:345-346]
9. **`transportHeadersKey` is a documented public `static const`** (no magic string; shared by the transport and Epic-5/4.10). [seam decision]
10. **No new dependency, no `dart:io` in `auth_interceptor.dart`** (platform-neutral); no `print`/`logging` (4.6); no finalization gates (4.10). [lib requirements]

These are baked in — implement them; no confirmation gate.

## Dev Agent Record

### Context Reference

<!-- Path(s) to story context will be added here by context workflow -->

### Agent Model Used

claude-opus-4-8[1m] (Opus 4.8, 1M context) — via `/agent-flutter-engineer` (implement mode).

### Debug Log References

- `melos run analyze` → 0 issues workspace-wide (11 packages).
- `dart test test/auth_interceptor_test.dart --test-randomize-ordering-seed=random` → +5 all passed.
- `melos run test` → green workspace-wide (incl. `koel_http` 57 tests: new auth suite + unchanged http_agent/retry/cancellation/sse_parser).
- `melos run format:check` → 0 changed (after `dart format` on the new test file).

### Completion Notes List

- Implemented the header-injection seam exactly as the RESOLVED design dictates: `AuthInterceptor.intercept` parks resolved headers on `input.forwardedProps[transportHeadersKey]` via `copyWith`; `_TransportTerminal.run` extracts the reserved key, encodes a **stripped** copy of `forwardedProps` (token never on the wire body), and merges auth headers with **protocol headers last** (`Content-Type`/`Accept` can't be clobbered).
- `AuthInterceptor` is `class` (not `final`) so Epic-5's `AgnoAuthInterceptor` can `extend` it; `transportHeadersKey` is a documented public `static const` shared by the transport (and forward-compatible with 4.10's web transport).
- Async resolution via `Stream.fromFuture(_resolve()).asyncExpand(...)` — single-subscription, cancel-correct (a cancel during resolution opens no transport), no `async*`, no `StreamController` ceremony.
- A throwing callback is wrapped (via `Error.throwWithStackTrace`) as `BusinessError(code: businessAuth, cause: <original>)` with a fixed, secret-free message and surfaced through the stream; the chain classifier's typed-error passthrough turns it into the single terminal `RunErrorEvent`. No manual `RunErrorEvent`, no 401-status classification (Epic 5).
- Token-refresh-on-retry falls out of 4.4's outermost-retry ordering: the default `shouldRetry` retries the 401 (surfaced as `TransportError(transportClosed)`), re-runs auth, and re-POSTs with the fresh token. No custom predicate required.
- **No `koel_core` change** — `RunAgentInput` untouched, so the `dart_apitool` API-diff gate is not tripped. Codec stays auth-agnostic (comment only). No new dependency; no `dart:io` in `auth_interceptor.dart`.

### File List

- `packages/koel_http/lib/src/interceptors/auth_interceptor.dart` (NEW) — `class AuthInterceptor implements Interceptor`; `transportHeadersKey`; `intercept` + `_resolve`.
- `packages/koel_http/lib/src/http_agent.dart` (MODIFY) — `_TransportTerminal.run` extracts + strips the reserved key before encoding, merges auth headers (protocol last); imports `interceptors/auth_interceptor.dart`.
- `packages/koel_http/lib/src/wire/run_agent_input_codec.dart` (MODIFY) — defense-in-depth comment only (reserved keys stripped by the transport; codec stays auth-agnostic).
- `packages/koel_http/lib/koel_http.dart` (MODIFY) — `export 'src/interceptors/auth_interceptor.dart';`.
- `packages/koel_http/test/auth_interceptor_test.dart` (NEW) — AC1 surface+count, AC2 header-verbatim/no-leak, AC3 throw→businessAuth, AC4 token-refresh-on-retry.

## Change Log

| Date | Change |
| --- | --- |
| 2026-05-31 | Story 4.5 implemented: `AuthInterceptor` (async header-builder) + `forwardedProps` reserved-key transport seam (strip-before-encode, protocol headers last); barrel export; codec comment; 5-scenario test suite. All ACs satisfied; analyze/test/format green. Status → review. |
| 2026-06-01 | Code review (Blind Hunter + Edge Case Hunter + Acceptance Auditor): all 4 ACs + 10 RESOLVED decisions PASS. 2 patches applied — (1) hardened `_TransportTerminal.run` reserved-key type guard → typed `AgentError(unknown)` instead of raw `TypeError`→vague bucket; (2) +3 tests (stacked compose, type-collision hardening, lowercase protocol-clobber). 1 defer (protocol-protection leans on http client case-insensitivity — not reachable today). analyze/format/test green workspace-wide (koel_http 60/60). Status → done. |
