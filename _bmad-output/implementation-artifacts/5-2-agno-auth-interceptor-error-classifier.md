---
baseline_commit: 1ecd17b3be46469dcb39c1eb94802b60680c2485
---

# Story 5.2: `koel_agno` — Default-ON `AgnoAuthInterceptor` + `AgnoErrorClassifier`

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a Flutter/Dart developer,
I want `AgnoAuthInterceptor` default-ON injecting the configured Bearer token plus `AgnoErrorClassifier` mapping agno-specific HTTP status codes to `KoelErrorCode`,
so that auth and error reporting work out-of-the-box for agno backends per FR-C1 + AR-20.

## Acceptance Criteria

> AC1–AC4 are the epic's stated criteria for Story 5.2. **AC5 (the `HttpAgent` error-classifier seam) and AC7 (flipping 5.1's token no-op test) are mandated by the Story 5.1 hand-off** — 5.1's Dev Notes explicitly recorded that "5.2 will add an overridable error-classifier hook" and pinned the `token` param as a no-op that 5.2 consumes. **AC6 folds in two planned deferral closures** the 5.1 hand-off named for this story (the Story 4.5 `401 → businessAuth` mapping and the Story 2.3 `DefaultErrorClassifier` name-asymmetry note). All three are 5.2 scope by decision, not invention — the same pattern 5.1 used for its AC4/AC5 additions.

**AC1 — `AgnoAuthInterceptor` (epic-stated; FR-C1, Addendum A.3).**
**Given** `packages/koel_agno/lib/src/agno_auth_interceptor.dart`,
**When** I inspect it,
**Then** `class AgnoAuthInterceptor extends AuthInterceptor` with constructor `AgnoAuthInterceptor({required String? token})` per Addendum A.3,
**And** when `token == null` the interceptor is a no-op (open dev deployments — no `Authorization` header reaches the wire),
**And** when `token` is non-null, the outgoing request carries `Authorization: Bearer <token>`.

**AC2 — default-ON wiring (epic-stated).**
**Given** `AgnoAgent(baseURL: …, token: 'abc')` constructed **without** an explicit interceptor list,
**When** a run executes,
**Then** the `Bearer abc` header is present on the outgoing request (verified by request inspection via `MockClient`),
**And** the `AgnoAuthInterceptor` is automatically **prepended** to the chain (outermost among the adapter defaults), so a user-supplied inner `AuthInterceptor` in `interceptors:` can still override the token (inner-wins merge — see Dev Notes),
**And** the token never appears in the request **body** (it rides the header only, stripped from `forwardedProps` before encoding — the 5.1 body-leak guard still holds).

**AC3 — `AgnoErrorClassifier` status-code mappings + default registration (epic-stated, scoped to evidence-backed codes).**
**Given** `packages/koel_agno/lib/src/error/agno_error_classifier.dart`,
**When** I inspect it,
**Then** `class AgnoErrorClassifier extends DefaultErrorClassifier` overrides `classify(...)` to map agno-meaningful **HTTP statuses** — `401 → businessAuth`, `403 → businessForbidden`, `429 → businessRateLimited` — recognized off the already-wrapped `TransportError.statusCode` (the non-2xx transport path wraps the status into `TransportError(statusCode:)` before classification — see Dev Notes),
**And** every non-status failure delegates to the **native** `transportErrorClassifier()` (NOT bare `super.classify`), preserving koel_http's socket/TLS wrapper refinement (a connection-refused on the native agno path must still classify `transportRefused`, not slip to `unknown`),
**And** `AgnoAgent` registers it by default via the AC5 seam,
**And** the agno-specific **JSON error-envelope → `agentRefused`/`agentInternal`** mapping named in the epic is **explicitly deferred to Story 5.3** (the agno agent-error envelope is uncharacterized — `koel_backend` SPIKE Q3 ran text-only under the mock-LLM; building a speculative envelope parser now would violate CLAUDE.md "no just-in-case"). The deferral is recorded in the classifier dartdoc + the story's deferral log.

**AC4 — OQ-Agno-Auth resolved → default-ON stays (epic-stated, baked RESOLVED).**
**Given** the OQ-Agno-Auth spike result (per PRD §15) — **already resolved** in `koel_backend` (agno `2.6.10`'s AG-UI route enforces **zero auth**: CORS only, no Bearer check),
**When** I inspect the default behavior,
**Then** the default-ON behavior **stays** (the assumption is harmless, not confirmed-required: open agno ignores the `Authorization` header, so a default-ON Bearer is a safe client convention and `token` is optional),
**And** the rationale ("agno ignores the token unless the deployment adds an opt-in check; default-ON is a harmless convention") is documented in the `AgnoAuthInterceptor` dartdoc now; the package-README sentence the AC mentions is folded into Story 5.3's package finalization (mirrors 5.1 deferring README/`analysis_options.yaml` polish to the 5.3 sealer).

**AC5 — `HttpAgent` error-classifier seam (Story 5.1 hand-off; mirror of 5.1 AC4 `encodeBody`).**
**Given** `packages/koel_http/lib/src/http_agent.dart`,
**When** I inspect `HttpAgent`,
**Then** the error-classifier selection is exposed as an overridable `@protected` seam (recommended: `@protected ErrorClassifier errorClassifier() => transportErrorClassifier();`) that `run` calls in place of the hardcoded `errorClassifier: transportErrorClassifier()` ([http_agent.dart:157](packages/koel_http/lib/src/http_agent.dart#L157)),
**And** `koel_http` exports `transportErrorClassifier()` from its barrel so a cross-package subclass can compose on top of the native classifier,
**And** `AgnoAgent` overrides the seam to return `AgnoErrorClassifier()`,
**And** `koel_http`'s existing `test:coverage` gate (≥90% line + branch) stays green after the change.

**AC6 — deferral closures folded in (Story 5.1 hand-off).**
**Given** the Story 4.5 + Story 2.3 deferrals the 5.1 Dev Notes routed to 5.2,
**When** I inspect the change,
**Then** the `401 → businessAuth` status mapping (the status-code-aware refinement the koel_core `DefaultErrorClassifier` dartdoc and Story 4.5 deferred to "Epic 4/5 adapter subclasses") is realized in `AgnoErrorClassifier` (closes the 4.5 line for agno),
**And** the Story 2.3 deferral is closed: a regression test locks the documented caveat that a renamed/private runtime type name (e.g. a class whose `runtimeType.toString()` is not the bare `SocketException`) routes to `AgentError(unknown)` via `DefaultErrorClassifier`'s name-switch, **and** the `is`-catches-subclasses vs name-switch-does-not asymmetry is noted in the `DefaultErrorClassifier` dartdoc.

**AC7 — 5.1's token no-op test flips; no contradictory assertion remains (Story 5.1 hand-off, Epic-4-retro Action Item #2).**
**Given** the Story 5.1 test asserting `AgnoAgent(token: 'secret-xyz')` emits **no** `Authorization` header ([agno_agent_test.dart:182-199](packages/koel_agno/test/agno_agent_test.dart#L182-L199)),
**When** I inspect the suite after this story,
**Then** that assertion is **flipped** to assert the `Bearer secret-xyz` header **is** present (token now consumed), the body-leak guard is kept, and a separate `token == null` no-op test is added,
**And** the `// Consumed in Story 5.2 … pinned no-op here.` comment on `AgnoAgent.token` is removed/updated (the field is now consumed), so no stale "no-op" claim survives.

## Tasks / Subtasks

- [x] **Task 1 — `HttpAgent` error-classifier seam (AC5). DO THIS FIRST** (mirror of 5.1's "seam-first" sequencing — open the override point before building the agno consumer that needs it).
  - [x] Confirm the source reality: `HttpAgent.run` hardcodes `errorClassifier: transportErrorClassifier()` at [http_agent.dart:157](packages/koel_http/lib/src/http_agent.dart#L157); a cross-package subclass has no override point for the classifier. (`transportErrorClassifier()` is the per-platform factory — native `TransportErrorClassifier`, web `DefaultErrorClassifier` stub — resolved via conditional import in [error/error_classifier.dart](packages/koel_http/lib/src/error/error_classifier.dart).)
  - [x] Add `@protected ErrorClassifier errorClassifier() => transportErrorClassifier();` to `HttpAgent`, with a member dartdoc (koel_http's `public_member_api_docs` gate applies). Change `run`'s `InterceptorChain(... errorClassifier: transportErrorClassifier())` → `errorClassifier: errorClassifier()`. The default path is unchanged (every existing run still calls it) — this is additive + a one-line swap, exactly like 5.1's `encodeBody`.
  - [x] Export the factory so adapters can compose on it: add `export 'src/error/error_classifier.dart';` to [packages/koel_http/lib/koel_http.dart](packages/koel_http/lib/koel_http.dart). (`ErrorClassifier`/`DefaultErrorClassifier` are already exported by `koel_core`; only the `transportErrorClassifier()` factory is missing from a consumer's reach.)
  - [x] Run `bash tool/coverage.sh packages/koel_http 90 90 with_chrome` — the default `errorClassifier()` path is already exercised by every error test in `http_agent_test.dart`; confirm the gate stays green.
- [x] **Task 2 — `AgnoAuthInterceptor` (AC1).**
  - [x] Create `packages/koel_agno/lib/src/agno_auth_interceptor.dart`. `class AgnoAuthInterceptor extends AuthInterceptor` with `AgnoAuthInterceptor({required String? token})` (Addendum A.3 surface — `token` is `required` but nullable).
  - [x] Forward to `super(headers: () async => token == null ? const <String, String>{} : {'Authorization': 'Bearer $token'})`. Null token → empty header map → `AuthInterceptor` writes an empty reserved map → transport adds no `Authorization` (true no-op). Non-null → `Bearer <token>`. Do **not** reimplement the header-injection plumbing — `AuthInterceptor` already owns the `forwardedProps[transportHeadersKey]` seam, secret-free error wrapping, and per-retry re-resolution (see [auth_interceptor.dart](packages/koel_http/lib/src/interceptors/auth_interceptor.dart)).
  - [x] Dartdoc: state the default-ON rationale (AC4) — agno enforces zero auth, so a default Bearer is a harmless client convention; the deployment must add an opt-in check to enforce it. Cite SPIKE Q1.
  - [x] Unit-test (`agno_auth_interceptor_test.dart`): `token: null` → no `Authorization` header on the captured request; `token: 'abc'` → `Authorization: Bearer abc`. Drive via the same `MockClient` request-capture pattern as `agno_agent_test.dart`.
- [x] **Task 3 — `AgnoErrorClassifier` (AC3, AC6).**
  - [x] Create `packages/koel_agno/lib/src/error/agno_error_classifier.dart`. `final class AgnoErrorClassifier extends DefaultErrorClassifier` with an injectable inner classifier defaulting to the native one: `AgnoErrorClassifier({ErrorClassifier? inner}) : _inner = inner ?? transportErrorClassifier();`.
  - [x] Override `classify(Object raw, StackTrace? stack, RunAgentInput input)`:
    ```dart
    @override
    KoelError classify(Object raw, StackTrace? stack, RunAgentInput input) {
      // The non-2xx transport path wraps the status into TransportError(statusCode:)
      // BEFORE classification, and DefaultErrorClassifier passes a typed KoelError
      // through idempotently — so map the agno-meaningful statuses here, FIRST.
      if (raw is TransportError && raw.statusCode != null) {
        switch (raw.statusCode!) {
          case 401:
            return BusinessError(
              message: 'Authentication required or invalid',
              code: KoelErrorCode.businessAuth,
              cause: raw,
            );
          case 403:
            return BusinessError(
              message: 'Access forbidden',
              code: KoelErrorCode.businessForbidden,
              cause: raw,
            );
          case 429:
            return BusinessError(
              message: 'Rate limited',
              code: KoelErrorCode.businessRateLimited,
              cause: raw,
            );
        }
      }
      // Everything else → the NATIVE transport classifier (socket/TLS refinement),
      // NOT bare super.classify — see the "single most important finding" dev note.
      return _inner.classify(raw, stack, input);
    }
    ```
  - [x] **Critical — delegate to `_inner`, not `super`.** A bare `super.classify` (DefaultErrorClassifier) matches socket exceptions by runtime-type *name* and cannot see through `package:http`'s `_ClientSocketException` wrapper, so a connection-refused on the real native agno path would slip to `unknown` — a regression vs. a plain `HttpAgent`. Delegating fall-through to `transportErrorClassifier()` (native `TransportErrorClassifier`, `is`-based) preserves the Epic-4 AC4 refinement. (`extends DefaultErrorClassifier` satisfies the epic AC's type contract and the Story 2.3 "adapter subclass of DefaultErrorClassifier" framing; the inner-delegate is what makes it correct on the native path.)
  - [x] **Do not** build a JSON error-envelope parser (`agentRefused`/`agentInternal`) — the agno agent-error envelope is uncharacterized (SPIKE Q3). Record the deferral in the classifier dartdoc pointing to Story 5.3's live capture.
  - [x] Unit-test (`error/agno_error_classifier_test.dart`): `TransportError(statusCode: 401)` → `BusinessError(businessAuth)`; `403` → `businessForbidden`; `429` → `businessRateLimited`; a non-mapped status (e.g. `500`) and a non-`TransportError` failure delegate unchanged; **and** assert the socket-refinement is preserved — a raw `SocketException` (or a `MockClient` throwing one) classifies `transportRefused` through `AgnoErrorClassifier`, not `unknown`.
- [x] **Task 4 — wire `AgnoAgent` default-ON (AC2, AC5, AC7).**
  - [x] In [agno_agent.dart](packages/koel_agno/lib/src/agno_agent.dart): change the constructor so `interceptors` is a plain `List<Interceptor>? interceptors` param (no longer `super.interceptors`), and pass to super: `interceptors: [AgnoAuthInterceptor(token: token), ...?interceptors]`. Keep `super.client` as-is (still forwarded untouched — mixing a `super.client` formal with an explicit `super(url:…, interceptors:…)` is analyzer-clean, as 5.1 proved). The `token` field stays (`this.token`), now **consumed** in the super-call — remove the `// Consumed in Story 5.2 … pinned no-op here.` comment and update the field dartdoc.
  - [x] Override the AC5 seam: `@override ErrorClassifier errorClassifier() => AgnoErrorClassifier();`.
  - [x] Update `agno_agent_test.dart`: **flip** the token no-op test (AC7) — `token: 'secret-xyz'` now asserts `Authorization: Bearer secret-xyz` IS present (keep the body-leak guard `expect(request.body, isNot(contains('secret-xyz')))`). Add a `token: null` → no-`Authorization` test. Add an integration test that a 401 SSE response through `AgnoAgent` surfaces a terminal `RunErrorEvent(BusinessError(businessAuth))` (drive a non-2xx `MockClient`, classify via the wired `AgnoErrorClassifier`).
- [x] **Task 5 — exports + Story 2.3 deferral fold-in (AC6).**
  - [x] Export the new public surface from [koel_agno.dart](packages/koel_agno/lib/koel_agno.dart): `AgnoAuthInterceptor`, `AgnoErrorClassifier` (both are documented public API — Addendum A.3 lists `AgnoAuthInterceptor`).
  - [x] Close the Story 2.3 deferral: add a regression test to [koel_core/test/error/error_classifier_test.dart](packages/koel_core/test/error/error_classifier_test.dart) asserting a class whose `runtimeType.toString()` is **not** the bare `SocketException`/`HandshakeException`/`HttpException`/`ClientException` (e.g. a local `class _RenamedSocketException implements Exception {}`) routes to `AgentError(unknown)` via `DefaultErrorClassifier` — locking the documented name-match caveat. Add one sentence to `DefaultErrorClassifier`'s dartdoc noting the `is` arms catch subclasses while the `runtimeType` name-switch does not (the asymmetry). Keep this minimal and additive — koel_core's `lib/` behavior is unchanged (test + doc only).
  - [x] Run `dart analyze packages/koel_agno packages/koel_http packages/koel_core` → exit 0 (NFR-13).
- [ ] **Out of scope for 5.2 — record, do not implement:** captured agno fixtures + `ConformanceRunner` green + the `test:coverage` gate entry for koel_agno + package-finalization `analysis_options.yaml` + the README default-ON sentence (all **Story 5.3**, the agno-group sealer); the JSON error-envelope → `agentRefused`/`agentInternal` mapping (Story 5.3, needs a captured error fixture); the koel_core "throwing `ErrorClassifier` escapes the invariant" hardening (Story 2.14 deferral — separate, not triggered here).

### Review Findings

> Code review 2026-06-03 (`bmad-code-review`, 3-layer adversarial). **Acceptance Auditor: PASS on all of AC1–AC7** — no spec violations. Remaining items are quality/edge-case only.

- [x] [Review][Patch] Treat empty/whitespace token as a no-op [packages/koel_agno/lib/src/agno_auth_interceptor.dart:25-30] — **FIXED**: gate is now `token == null || token.trim().isEmpty`; dartdoc updated; regression test (`'' `/`'   '` → no `Authorization` header) added to `agno_auth_interceptor_test.dart`. (resolved from decision; edge, Medium)
- [x] [Review][Patch] Self-restating parenthetical in `AgnoAgent` constructor dartdoc [packages/koel_agno/lib/src/agno_agent.dart:21-23] — **FIXED**: redundant "(inner keys win)" removed. (blind, Low)
- [x] [Review][Defer] "inner wins" override merge is case-sensitive + an inner empty map leaves the default header intact [packages/koel_http/lib/src/interceptors/auth_interceptor.dart] — deferred, pre-existing. A caller-supplied inner `AuthInterceptor` only overrides when its header key casing byte-matches `'Authorization'`; a lowercase `'authorization'` produces two distinct map entries and wire precedence is then `http`'s call, so the default token can ride alongside the override. Same root cause already logged in `deferred-work.md` from the 4-5-auth-interceptor review (case-sensitive merge in the sealed `_TransportTerminal`/`AuthInterceptor`). (blind+edge, Medium)
- [x] [Review][Defer] `token` captured in a long-lived closure with no disposal/rotation seam [packages/koel_agno/lib/src/agno_auth_interceptor.dart:31-36] — deferred, pre-existing. The secret stays resident for the interceptor's lifetime and is re-interpolated per run/retry. This matches the base `AuthInterceptor` fixed-closure pattern; koel has no interceptor-disposal mechanism, so a dispose seam is an architectural decision beyond this story. (blind, Medium)

> Dismissed as noise (3): (a) `AgnoErrorClassifier extends DefaultErrorClassifier` never calls `super` → AC3 + Dev Notes *mandate* exactly this (type contract + native-delegate); (b) 401→`businessAuth` "drops" the status code → it is preserved on `BusinessError.cause` by design; (c) `errorClassifier()` re-invoked per `run()` → the override returns `const AgnoErrorClassifier()`, effectively free.

## Dev Notes

### The single most important finding: `AgnoErrorClassifier` must delegate to the **native** classifier, not bare `super`

The epic AC says `AgnoErrorClassifier extends DefaultErrorClassifier`. Taken literally — `extends DefaultErrorClassifier`, then `super.classify(...)` for the fall-through — this **regresses the native error path**. Here is why, source-verified:

- `AgnoAgent` runs over koel_http's native transport. The Epic-4 AC4 refinement [`TransportErrorClassifier`](packages/koel_http/lib/src/error/io_error_classifier.dart) exists *because* `package:http`'s `IOClient` rethrows a `dart:io` `SocketException` **wrapped** in a private `_ClientSocketException` whose `runtimeType` is neither `SocketException` nor `ClientException`. koel_core's `DefaultErrorClassifier` matches those types by **name** (`runtimeType.toString()`) to stay web-safe ([error_classifier.dart:69](packages/koel_core/lib/src/error/error_classifier.dart#L69)), so it **misses the wrapper** → a real connection-refused slips to `KoelErrorCode.unknown`.
- `TransportErrorClassifier` fixes this with real `is SocketException`/`is TlsException` checks (it is allowed to import `dart:io`). If `AgnoErrorClassifier` bypasses it (`super` = bare base), every native socket/TLS failure on the agno path regresses to `unknown`.

**Resolution (baked in):** `AgnoErrorClassifier extends DefaultErrorClassifier` (honors the AC type contract + the Story 2.3 "adapter subclass of DefaultErrorClassifier" framing) **but holds an inner classifier defaulting to `transportErrorClassifier()`** and delegates all non-agno failures to it — composition over inheritance (CLAUDE.md). The `io_error_classifier.dart` dartdoc already anticipates exactly this: *"Epic-5 status-code-aware classifiers refine it further."* `TransportErrorClassifier` is `final` + behind a conditional import (web-absent), so it cannot be `extend`ed portably — the inner-delegate is the portable composition. This mirrors how 5.1 reconciled the epic's speculative "convert agno's message shape" against the source truth (agno is native AG-UI).

### How an HTTP status reaches the classifier (so the 401 mapping works)

A non-2xx response is **not** a thrown `http` exception — koel_http's `_TransportTerminal.run` detects it and throws a typed `TransportError(code: transportClosed, statusCode: <code>)` ([http_agent.dart:247-267](packages/koel_http/lib/src/http_agent.dart#L247-L267)). That `TransportError` flows into `InterceptorChain`'s classifier. `DefaultErrorClassifier.classify` is **idempotent** for already-typed `KoelError`s (`if (raw is KoelError) return raw;` — [error_classifier.dart:47](packages/koel_core/lib/src/error/error_classifier.dart#L47)). So `AgnoErrorClassifier` must inspect `raw is TransportError && raw.statusCode == 401` **before** that passthrough and remap to `BusinessError(businessAuth)`. The `statusCode` field is populated precisely for this (`TransportError.statusCode`, [koel_error.dart:57-62](packages/koel_core/lib/src/error/koel_error.dart#L57-L62)). This is the realization of the `401 → businessAuth` refinement that [error_classifier.dart:33-37](packages/koel_core/lib/src/error/error_classifier.dart#L33-L37) and the Story 4.5 deferral both routed to "Epic 4/5 adapter subclasses" (closes AC6's 4.5 line).

### Default-ON wiring + interceptor ordering (AC2)

`AgnoAgent` prepends its auth interceptor: `super(interceptors: [AgnoAuthInterceptor(token: token), ...?interceptors])`. Ordering decision (resolved, not left open):

- **AgnoAuthInterceptor is outermost** among the adapter defaults. The `AuthInterceptor` merge is **inner-wins**: each interceptor merges `{...prior, ...resolved}` so the **last to run (innermost)** writes the winning keys ([auth_interceptor.dart:81-90](packages/koel_http/lib/src/interceptors/auth_interceptor.dart#L81-L90)). Putting the agno default **outermost** means a user who passes their own inner `AuthInterceptor` in `interceptors:` **wins** → the default token is user-overridable ("design for what users can't misuse"). This matches the AC's "automatically prepended" wording. (The Addendum A.3 inline comment "`interceptors` // prepended to default chain" is informal and order-ambiguous; the AC + the inner-wins semantics settle it as auth-outermost.)
- On retry, `HttpAgent.run` prepends `RetryInterceptor` outermost ([http_agent.dart:142-153](packages/koel_http/lib/src/http_agent.dart#L142-L153)), so it re-runs the whole chain — including `AgnoAuthInterceptor` — on each reconnect: the token re-resolves per attempt, the token-refresh hook works for free.
- The token still must not reach the **body**: `_TransportTerminal` strips `forwardedProps[transportHeadersKey]` before encoding ([http_agent.dart:197-219](packages/koel_http/lib/src/http_agent.dart#L197-L219)). The 5.1 body-leak guard test (`isNot(contains('secret-xyz'))`) stays valid and should be kept in the flipped AC7 test.

### `token` is now consumed — flip 5.1's no-op pin (AC7)

Story 5.1 accepted `token` but pinned it as a tested no-op (Epic-4-retro Action Item #2 — a forward-looking param must be stored-and-used *or* test-pinned). 5.2 is the "used" half: `AgnoAuthInterceptor(token: token)` consumes it. The 5.1 test at [agno_agent_test.dart:182-199](packages/koel_agno/test/agno_agent_test.dart#L182-L199) currently asserts **no** `Authorization` header for `token: 'secret-xyz'`; leaving it would **fail the build**. Flip it to assert `Bearer secret-xyz` is present, keep the body-leak guard, and add a `token: null` no-op test. Remove the stale `// Consumed in Story 5.2 … pinned no-op here.` comment on the field.

### OQ-Agno-Auth is resolved — default-ON stays (AC4)

The epic AC4 reads as if the spike were pending. It is **resolved** (epic-5-prep-plan Q1, source-verified against `agno==2.6.10`): agno's AG-UI route enforces **zero auth** (CORS only; no Bearer verification). So default-ON `AgnoAuthInterceptor` is a **harmless client convention** — open agno ignores the header, `token` is optional, and a deployment that wants enforcement adds its own opt-in middleware (which returns 401/403, which `AgnoErrorClassifier` now maps). Per the "no CYA open questions" rule: this is decided and baked into the `AgnoAuthInterceptor` dartdoc now; the package-README sentence the AC names is part of Story 5.3's package finalization (koel_agno has no README/`analysis_options.yaml` yet — 5.1 deferred those to the 5.3 sealer).

### Existing-code contracts that must not break (read before editing `http_agent.dart`)

- The AC5 change is **additive + one-line**: add `@protected errorClassifier()` and swap the hardcoded arg in `run` ([http_agent.dart:154-159](packages/koel_http/lib/src/http_agent.dart#L154-L159)). `run` builds the `InterceptorChain` synchronously; `errorClassifier()` is called once at assembly, same as the old hardcoded call — no laziness/cancel implications. Touch nothing else in `run` or `_TransportTerminal`.
- **Adapters never throw `KoelError`** (architecture ARCH-597): every failure reaches the consumer as a terminal `RunErrorEvent`. `AgnoErrorClassifier` returns a `KoelError` (never throws — the `ErrorClassifier.classify` contract: [error_classifier.dart:16-18](packages/koel_core/lib/src/error/error_classifier.dart#L16-L18)); `InterceptorChain` turns it into the terminal event. Do **not** add try/catch in `AgnoErrorClassifier` or `AgnoAgent`.
- koel_http and koel_core are `done`, sealed, ≥90%-covered packages. Modifying them here is **sanctioned** (AC5 is the 5.1-hand-off seam; AC6's 2.3 fold-in is test+dartdoc only). Keep changes additive and re-run koel_http's coverage gate.

### Source tree (what to touch)

```
packages/koel_agno/
├── lib/
│   ├── koel_agno.dart                          # UPDATE: export AgnoAuthInterceptor + AgnoErrorClassifier
│   └── src/
│       ├── agno_agent.dart                     # UPDATE: prepend AgnoAuthInterceptor (default-ON); override errorClassifier(); token now consumed (drop no-op comment)
│       ├── agno_auth_interceptor.dart          # NEW: AgnoAuthInterceptor extends AuthInterceptor (Task 2)
│       └── error/
│           └── agno_error_classifier.dart      # NEW: AgnoErrorClassifier extends DefaultErrorClassifier, inner-delegate (Task 3)
└── test/
    ├── agno_agent_test.dart                    # UPDATE: flip token test → Bearer present; add token-null + 401→businessAuth integration
    ├── agno_auth_interceptor_test.dart         # NEW: null=no-op / non-null=Bearer (AC1)
    └── error/
        └── agno_error_classifier_test.dart     # NEW: 401/403/429 maps + socket-refinement preserved + envelope deferred (AC3)

packages/koel_http/
├── lib/
│   ├── koel_http.dart                          # UPDATE: export src/error/error_classifier.dart (transportErrorClassifier)
│   └── src/http_agent.dart                     # UPDATE: add @protected errorClassifier() seam; route run() through it (AC5)

packages/koel_core/                             # AC6 — Story 2.3 deferral fold-in (test + dartdoc only)
├── lib/src/error/error_classifier.dart         # UPDATE: add is/name asymmetry note to DefaultErrorClassifier dartdoc
└── test/error/error_classifier_test.dart       # UPDATE: add renamed/private-name → unknown regression test
```
Adapter-package layout per architecture §ARCH-871 (`error/<x>_error_classifier.dart`, `<x>_auth_interceptor.dart` at `src/` root — matches the epic AC paths exactly). Adapter agents/interceptors end in `Agent`/`Interceptor`/`Classifier`.

### Testing standards

- **Harness pattern** (mirror [agno_agent_test.dart](packages/koel_agno/test/agno_agent_test.dart) from 5.1): `MockClient` (`package:http/testing.dart`) to **capture** the outgoing request (assert `Authorization` present/absent, body has no token) and to **replay** SSE / a non-2xx status. Reuse `koel_test` synthesized fixtures for happy-path SSE; for the classifier, a `MockClient` returning a 401 status (or unit-feeding a `TransportError(statusCode: 401)` straight into `AgnoErrorClassifier.classify`) is enough.
- `@TestOn('vm')` — koel_agno is offline/VM (no web transport; the `with_chrome` arg is koel_http-specific). The socket-refinement test needs the native path: a raw `SocketException` thrown from a `MockClient` exercises the `_inner` delegate's `is` check on the VM.
- Coverage: `koel_agno` target ≥80% line+branch (adapter tier, SC-2/NFR-12) — but the **gate enforcement + `tool/coverage.sh packages/koel_agno 80 80` entry land in Story 5.3** (the sealer). Write thoroughly-covered code now; don't add the gate wiring. koel_http's gate (≥90%) **is** enforced now (AC5) — run it.
- Do not add `analysis_options.yaml` to koel_agno yet (finalization → 5.3). koel_http's `public_member_api_docs` gate **does** apply to the new `errorClassifier()` — give it a proper member dartdoc.

### Latest technical / wire facts (source-verified, not web-guessed)

The agno wire contract is verified in the sibling `../koel_backend` repo (more authoritative than any web doc — it is source-read + docker-probed):
- `agno == 2.6.10`. AG-UI route: **zero built-in auth** (CORS only). Opt-in auth middleware (when a deployment adds it) returns **401/403**. → drives AC3's `401 → businessAuth`, `403 → businessForbidden`.
- `429` (rate-limit) is the standard HTTP convention → `businessRateLimited`; not agno-specific but the natural mapping for the `KoelErrorCode.businessRateLimited` slot.
- The native **agent-error envelope is uncharacterized** (agno ran text-only under the mock-LLM in the spike) → JSON-envelope→`agentRefused`/`agentInternal` is **Story 5.3** work (live capture). No `http` / dependency bump needed (still `http: ^1.6.0`).

### References

- [Source: _bmad-output/planning-artifacts/epics/epic-5-backend-bridges-koelagno-koellanggraph-koelruntime.md#Story-5.2] — story ACs (AgnoAuthInterceptor, AgnoErrorClassifier, default registration, OQ-Agno-Auth).
- [Source: _bmad-output/planning-artifacts/prds/prd-koel-2026-05-27/addendum.md#A.3] — exact `AgnoAuthInterceptor({required String? token})` signature + `interceptors` "prepended to default chain" note.
- [Source: _bmad-output/implementation-artifacts/5-1-agno-agent-message-conversion.md] — the hand-off mandating 5.2's error-classifier seam + the deferral fold-ins; the `token` no-op pin to flip; the `encodeBody` seam pattern to mirror.
- [Source: _bmad-output/implementation-artifacts/epic-5-prep-plan.md] — SPIKE Q1 (agno zero-auth → default-ON stays), Q3 (error envelope uncharacterized → 5.3), build sequence 5.1→5.2→5.3.
- [Source: _bmad-output/implementation-artifacts/deferred-work.md] — Story 4.5 (status→`businessAuth` belongs to adapter subclass) + Story 2.3 (DefaultErrorClassifier name-asymmetry regression fixture, line 174) deferrals folded into AC6.
- [Source: packages/koel_http/lib/src/http_agent.dart] — `run`'s hardcoded `errorClassifier:` (AC5 seam); non-2xx `TransportError(statusCode:)` throw; auth-key strip; RetryInterceptor prepend.
- [Source: packages/koel_http/lib/src/error/io_error_classifier.dart + error_classifier.dart] — `TransportErrorClassifier` (`final`, socket/TLS `is` refinement) + `transportErrorClassifier()` factory to export and compose on.
- [Source: packages/koel_http/lib/src/interceptors/auth_interceptor.dart] — subclass-ready `AuthInterceptor` (`headers` closure seam, inner-wins merge, secret-free error wrap).
- [Source: packages/koel_core/lib/src/error/error_classifier.dart] — `ErrorClassifier`/`DefaultErrorClassifier` (idempotent KoelError passthrough; name-match caveat; dartdoc anticipating 401/403/429 at adapter subclasses).
- [Source: packages/koel_core/lib/src/error/koel_error.dart + koel_error_code.dart] — `TransportError.statusCode`, `BusinessError`, and `businessAuth`/`businessForbidden`/`businessRateLimited` codes.
- [Source: ../koel_backend/backends/agno/CONTRACT.md] — authoritative agno wire contract (zero auth, 401/403 opt-in, `agno==2.6.10`).

### Project Structure Notes

- `koel_agno` was filled by 5.1 (`agno_agent.dart`, `conversion/message_conversion.dart`, tests). 5.2 adds the `agno_auth_interceptor.dart` + `error/agno_error_classifier.dart` siblings and updates the agent + barrel. No new package.
- Modifying `koel_http` (AC5 seam + barrel export) and `koel_core` (AC6 dartdoc + test) — both `done`/sealed — is **expected and sanctioned**: AC5 is the Story-5.1-hand-off resolution; AC6 closes named deferrals. Keep koel_http additive and re-run its coverage gate; koel_core touches only a dartdoc sentence + a test (no `lib/` behavior change).
- Hybrid versioning unchanged from 5.1: all packages pre-1.0 `version: 0.0.1, publish_to: none`; bare workspace dep keys are correct. koel_agno already depends on `koel_core` + `koel_http` + `http` (no pubspec change needed — `transportErrorClassifier` arrives via the existing `koel_http` dep once exported).

## Dev Agent Record

### Agent Model Used

claude-opus-4-8 (Opus 4.8, 1M context) — via `/bmad-dev-story`, `/agent-flutter-engineer` specialist loaded for all Dart work.

### Debug Log References

- `dart analyze packages/koel_agno packages/koel_http packages/koel_core` → **No issues found!** (NFR-13).
- `bash tool/coverage.sh packages/koel_http 90 90 with_chrome` → line=94.58% (436/461), branch=92.15% (176/191), exit 0 — AC5 seam keeps the gate green.
- `bash tool/coverage.sh packages/koel_agno 80 80` → line=100.00% (42/42), branch=100.00% (23/23) — well above the ≥80 adapter target (gate *wiring* deferred to 5.3).
- `dart run melos test` (full workspace) → SUCCESS: koel_core 576 (+1 new 2.3 regression), koel_http 97, koel_lints 5, koel_agno 34 — no regression.
- `bash tool/format.sh check` → clean.

### Completion Notes List

- **Implementation Plan (seam-first, red→green→refactor).** Built the AC5 error-classifier seam in `HttpAgent` first (mirror of 5.1's encodeBody sequencing), exported `transportErrorClassifier()` so adapters can compose on it, then layered `AgnoAuthInterceptor` (Task 2) → `AgnoErrorClassifier` (Task 3) → default-ON wiring + seam override + token-flip (Task 4) → exports + 2.3 deferral closure (Task 5).
- **AC5 seam is one additive method + a one-line swap.** `HttpAgent.errorClassifier()` (`@protected`, dartdoc'd for `public_member_api_docs`) defaults to `transportErrorClassifier()`; `run` calls it instead of the hardcoded arg. koel_http barrel now exports `src/error/error_classifier.dart`. Touched nothing else in `run`/`_TransportTerminal`; the call site is synchronous at chain-assembly, identical to before.
- **The headline correctness finding — delegate to native, not bare `super`.** `AgnoErrorClassifier extends DefaultErrorClassifier` (honors the AC type contract) but holds an inner classifier defaulting to `transportErrorClassifier()` and delegates all non-status failures to it. A bare `super.classify` would regress the native path: a `package:http`-wrapped `SocketException` (matched by *name* in the base) would slip to `unknown` instead of `transportRefused`. A regression test asserts the refinement is preserved.
- **Status mappings off `TransportError.statusCode`.** The non-2xx transport path wraps the status into `TransportError(statusCode:)` *before* classification, and `DefaultErrorClassifier` passes typed `KoelError`s through idempotently — so the override inspects `raw is TransportError && raw.statusCode != null` FIRST and remaps 401→`businessAuth` / 403→`businessForbidden` / 429→`businessRateLimited` via an exhaustive `switch` expression (`_ => null` falls through to the delegate). JSON agent-error envelope → `agentRefused`/`agentInternal` deferred to 5.3 (envelope uncharacterized — SPIKE Q3).
- **Default-ON wiring + ordering.** `AgnoAgent` prepends `AgnoAuthInterceptor(token: token)` outermost (`interceptors: [AgnoAuthInterceptor(token: token), ...?interceptors]`). Outermost-default + inner-wins merge makes the default token user-overridable — proven by a test where a caller's inner `AuthInterceptor` wins. `token: null` → no-op (no `Authorization`).
- **`token` flipped from no-op to consumed (AC7).** 5.1's "emits no Authorization header" test is replaced by the AC2 default-ON tests (`Bearer secret-xyz` present; body still leak-free); the `// pinned no-op` field comment is gone. Closes Epic-4-retro Action Item #2 for this param (it is now stored-AND-used).
- **2.3 deferral closed.** koel_core gains a regression test (`RenamedSocketException implements SocketException` → `AgentError(unknown)`, locking the name-match caveat) + a dartdoc sentence on the `is`-vs-name asymmetry. Test + doc only — no koel_core `lib/` behavior change.
- **Out of scope (recorded, not built):** captured agno fixtures + `ConformanceRunner` + koel_agno coverage-gate wiring + finalization `analysis_options.yaml` + README default-ON sentence (Story 5.3); JSON error-envelope mapping (5.3, needs a real error fixture); the koel_core "throwing ErrorClassifier" hardening (Story 2.14).

### File List

- `packages/koel_http/lib/src/http_agent.dart` — **MODIFIED**: added `@protected ErrorClassifier errorClassifier()` seam (default `transportErrorClassifier()`); routed `run`'s `InterceptorChain` through it (AC5).
- `packages/koel_http/lib/koel_http.dart` — **MODIFIED**: export `src/error/error_classifier.dart` (`transportErrorClassifier`) for cross-package composition (AC5).
- `packages/koel_agno/lib/src/agno_auth_interceptor.dart` — **NEW**: `AgnoAuthInterceptor extends AuthInterceptor` — Bearer from `token`, null=no-op (AC1, AC4 default-ON rationale).
- `packages/koel_agno/lib/src/error/agno_error_classifier.dart` — **NEW**: `AgnoErrorClassifier extends DefaultErrorClassifier` — 401/403/429 maps, inner-delegate to native classifier, envelope deferred (AC3, AC6).
- `packages/koel_agno/lib/src/agno_agent.dart` — **MODIFIED**: prepend default-ON `AgnoAuthInterceptor`; override `errorClassifier()`; `token` now consumed (no-op comment removed) (AC2, AC5, AC7).
- `packages/koel_agno/lib/koel_agno.dart` — **MODIFIED**: export `AgnoAuthInterceptor` + `AgnoErrorClassifier`.
- `packages/koel_agno/test/agno_auth_interceptor_test.dart` — **NEW**: null no-op / non-null Bearer (AC1).
- `packages/koel_agno/test/error/agno_error_classifier_test.dart` — **NEW**: 401/403/429 maps, socket-refinement preserved, unmapped/non-Transport delegation (AC3, AC6).
- `packages/koel_agno/test/agno_agent_test.dart` — **MODIFIED**: flipped token no-op test → default-ON Bearer present + null no-op + user-override + 401→businessAuth end-to-end (AC2, AC7).
- `packages/koel_core/lib/src/error/error_classifier.dart` — **MODIFIED**: dartdoc note on the `is`-vs-name asymmetry (AC6, Story 2.3 deferral).
- `packages/koel_core/test/error/error_classifier_test.dart` — **NEW test + helper**: `RenamedSocketException` → `unknown` regression locking the name-match caveat (AC6, Story 2.3 deferral).

## Change Log

| Date | Version | Description | Author |
|------|---------|-------------|--------|
| 2026-06-03 | 0.1 | Story drafted — default-ON `AgnoAuthInterceptor` + `AgnoErrorClassifier` (status-code mappings) + `HttpAgent` error-classifier seam (5.1 hand-off) + 4.5/2.3 deferral fold-ins + 5.1 token-no-op flip. Status → ready-for-dev. | Bob (SM) |
| 2026-06-03 | 0.2 | Implemented Story 5.2: AC5 error-classifier seam (`HttpAgent.errorClassifier()` + barrel export); `AgnoAuthInterceptor` (default-ON, null no-op); `AgnoErrorClassifier` (401/403/429 maps, native-delegate, envelope→5.3); default-ON wiring + token flip (AC7); koel_core 2.3 deferral closure. All ACs satisfied; koel_http coverage green (94.58%/92.15%); koel_agno 100%/100%; full workspace regression green. Status → review. | Amelia (Dev) |
