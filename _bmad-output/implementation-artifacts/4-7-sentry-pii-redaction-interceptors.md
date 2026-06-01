---
baseline_commit: 6a96d2f6a58f663ec9c7594bb15353d7d141a6f0
---

# Story 4.7: `SentryBreadcrumbInterceptor` + `PIIRedactionInterceptor` (both default-OFF)

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

> **Dev agent:** this is **Story 4.7 of Epic 4** (HTTP transport, `koel_http`). It ships the SDK's two **opt-in privacy/observability** interceptors — `SentryBreadcrumbInterceptor` (per-event Sentry breadcrumbs, **default-OFF**) and `PIIRedactionInterceptor` (scrubs matching text in the event stream before it reaches subscribers/reducer, **default-OFF**) — closing the six-interceptor set (Logging/EventTrace/Retry/Auth ship default-ON, these two default-OFF). It touches `.dart` files and the interceptor/stream seam, so **invoke `/agent-flutter-engineer` before producing any code** (per [CLAUDE.md](CLAUDE.md)). `packages/koel_http/` already ships `SseParser` (4.1), `HttpAgent` + the transport seam (4.2), the `abortOnCancel` watchdog (4.3), `RetryInterceptor` (4.4), `AuthInterceptor` (4.5), and `LoggingInterceptor`/`EventTraceInterceptor`/`TraceEntry` (4.6 — koel_http's first codegen). **Eight things are load-bearing — the first four are traps that will sink a naïve reading of the AC:**
>
> 1. **`sentry: ^9.21.0` becomes koel_http's FIRST third-party RUNTIME dependency — hard-linked, yet the interceptor is default-OFF.** AC1 (epic line 176) says breadcrumbs emit "via `sentry: ^9.x` (or equivalent stable)"; current stable is **9.21.0** (the pure-Dart `sentry` package — **NOT** `sentry_flutter`: koel_http is framework-free). Add `sentry: ^9.21.0` to `dependencies`. **"Default-OFF" does NOT mean "soft/optional dep"** — it means the interceptor is *not* in `HttpAgent`'s default chain and emits *nothing* unless the consumer (a) adds it to `interceptors:` **and** (b) has called `Sentry.init`. The dep's mere presence ships no telemetry (AC3 proves it). Do **NOT** try to make `sentry` an optional/soft dependency, split a `koel_sentry` package, or hide it behind reflection — that is over-engineering for one ~40-LOC leaf interceptor the architecture explicitly places in koel_http. Bake the hard dep. [Source: epic-4 :176; architecture.md:841,1075; pub.dev sentry 9.21.0]
> 2. **PII redaction scope = free-text CONTENT fields ONLY — NEVER structural identifiers.** AC4 names `TextMessageContentEvent.delta` and "other text-bearing payloads". The redactable surface is the **message/tool/reasoning text family** (deltas + tool-result content). You must **NOT** scrub `messageId`/`toolCallId`/`role`/`stepName`/`name`/`activityType` — redacting a `messageId` breaks the reducer's delta-correlation (Story 2.12 keys deltas by `messageId`) and would corrupt the `RetryInterceptor`'s `ConnectionResumed` `CustomEvent` marker. Redaction transforms what the **human reads**, not what the **protocol routes on**. [Source: AC :179-190; text_message_events.dart:47-50; retry_interceptor.dart:29-34; reducer Story 2.12]
> 3. **`AgUiEvent` is `sealed` + every subtype is `@freezed` — redact via `copyWith`, and the dispatch `switch` MUST have a `default`.** Pattern-match the event type, `copyWith(delta: scrubbed)` / `copyWith(content: scrubbed)` the text field, pass every non-text event through unchanged. The `switch` over the sealed union **must carry a `default:`** — the `koel_lints` `exhaustive_switch_must_have_default` rule ([rules/](packages/koel_lints/lib/src/rules/exhaustive_switch_must_have_default.dart)) is ERROR-severity. [Source: ag_ui_event.dart; architecture.md:525-535; addendum.md:483]
> 4. **Both interceptors are a pure `.map` over `chain.proceed(input)` — do NOT copy 4.6's `StreamController` wrapper.** 4.6's `LoggingInterceptor`/`EventTraceInterceptor` needed a controller to observe `onCancel`/`onDone`/first-listen. **4.7 needs neither.** Redaction is a stateless per-event transform; a breadcrumb is a per-event side-effect. The `Interceptor` contract's own `.map` example ([interceptor.dart:29-40](packages/koel_core/lib/src/agent/interceptor.dart)) is exactly the shape — and `.map` is cancel-transparent (the chain forwards cancel to the delegated stream beneath). Reaching for a controller here is unnecessary complexity. [Source: interceptor.dart:29-40,64-67]
> 5. **A Sentry breadcrumb must carry NO message text / PII — only event TYPE + structural ids.** A breadcrumb embedding the assistant's `delta` would ship chat content to Sentry — a privacy leak that contradicts the very privacy posture this story ships. Breadcrumbs carry `category: 'koel.event'`, `message: <wire/runtime type>`, and `data:` limited to structural ids (`messageId`/`toolCallId`/`runId`). Never the text content; never `input.forwardedProps` (carries 4.5's reserved auth-headers key). This is the same secret-free discipline as 4.5/4.6, applied to the telemetry sink. [Source: architecture §5; 4-5 trap #2; 4-6 Task 3]
> 6. **Telemetry/redaction is a side channel — it must never break a run.** If a consumer registers `SentryBreadcrumbInterceptor` but never called `Sentry.init`, `HubAdapter().addBreadcrumb` is a no-op (disabled hub) and must not throw. Wrap `addBreadcrumb` best-effort (mirror [`EventTraceInterceptor`'s `write`](packages/koel_http/lib/src/interceptors/event_trace_interceptor.dart#L67-L73)) so a Sentry failure is swallowed, never surfaced into the stream. Redaction is total/pure and cannot fail, but the breadcrumb path can. [Source: event_trace_interceptor.dart:64-73; interceptor.dart:64-67]
> 7. **Both are `final class … implements Interceptor` — no Epic-5 subclass.** Only `AuthInterceptor`/`HttpAgent` are intentionally non-`final` (Epic-5 `AgnoAuthInterceptor`/`AgnoAgent` extend them). No `Agno*Sentry`/`*Redaction` subclass exists in the addendum, so mirror [`RetryInterceptor`](packages/koel_http/lib/src/interceptors/retry_interceptor.dart#L41) / `EventTraceInterceptor` — `final class`. [Source: retry_interceptor.dart:41; addendum.md:326-329]
> 8. **`List<Pattern>` = `RegExp` OR `String` (both implement `dart:core` `Pattern`).** The A.2 ctor is `PIIRedactionInterceptor({required List<Pattern> patterns})`. `String.replaceAll(Pattern, String)` accepts any `Pattern`, so `text.replaceAll(pattern, '[REDACTED]')` works for both a `RegExp` (AC4's `RegExp(r'\b\d{4}-\d{4}-\d{4}-\d{4}\b')`) and a literal `String`. Replacement is **exactly** `[REDACTED]` (AC4 literal). [Source: addendum.md:327-328; AC :190; dart:core Pattern]

## Story

As a Flutter/Dart developer,
I want default-OFF observability and privacy interceptors that consumers opt into explicitly,
so that no silent telemetry ships and PII redaction is configurable per FR-B2 + FR-I2.

## Acceptance Criteria

Verbatim from [epic-4 Story 4.7](_bmad-output/planning-artifacts/epics/epic-4-http-transport-koelhttp.md) (lines 166-190):

1. **Given** `koel_http/lib/src/interceptors/sentry_breadcrumb_interceptor.dart`, **When** I inspect it, **Then** the class implements `Interceptor` and emits per-event Sentry breadcrumbs via `sentry: ^9.x` (or equivalent stable) when explicitly registered, **And** no Sentry traffic emits unless the consumer adds the interceptor to `KoelClient.interceptors`.

2. **Given** `koel_http/lib/src/interceptors/pii_redaction_interceptor.dart`, **When** I inspect the constructor, **Then** it matches Addendum A.2: `PIIRedactionInterceptor({required List<Pattern> patterns})`, **And** the interceptor scrubs matching content in `TextMessageContentEvent.delta` and other text-bearing payloads before they reach subscribers / reducer.

3. **Given** neither interceptor is registered (default `KoelClient` setup), **When** a run executes, **Then** no Sentry call is made and no PII redaction applies (verified by inspecting raw event stream content) per FR-I2.

4. **Given** a `PIIRedactionInterceptor` configured with `[RegExp(r'\b\d{4}-\d{4}-\d{4}-\d{4}\b')]` and a synthesized fixture carrying a fake credit-card-number string in message content, **When** the run executes through the interceptor, **Then** the consumer-visible event stream's text content is redacted with `[REDACTED]`.

> **AC clarifications (RESOLVED — do not re-litigate, implement):**
>
> - **AC1 surface.** `final class SentryBreadcrumbInterceptor implements Interceptor` at `lib/src/interceptors/sentry_breadcrumb_interceptor.dart`, **barrel-exported**. The A.2 ctor body is `{ ... }` (unspecified) — RESOLVED to `SentryBreadcrumbInterceptor({Hub? hub})` defaulting to `HubAdapter()` (the public sentry forwarder to the ambient hub). The `Hub?` seam exists for **testability** (inject a recorder) and is the idiomatic sentry-dart injection point; it is NOT a feature flag. [Source: addendum.md:326; trap #1]
> - **AC1 "via `KoelClient.interceptors`"** is the *eventual* registration path (Epic-6 `KoelClient`); in koel_http today the registration path is `HttpAgent(interceptors: [...])`. Both mean the same thing: the interceptor is in the chain only because the consumer put it there. No 4.7 AC wires it into `HttpAgent`'s default chain (which auto-prepends only `RetryInterceptor`). [Source: http_agent.dart:105-129; trap #1]
> - **AC1 "per-event breadcrumbs".** On each `AgUiEvent` the run yields, add **one** `Breadcrumb` (`category: 'koel.event'`, `message: <event wire/runtime type>`, `level: SentryLevel.info`, `data:` = structural ids only — trap #5). A terminal `RunErrorEvent` is just another event in the stream — `.map` catches it; optionally tag it at `SentryLevel.error`. **No** message text / `delta` / `content` / `forwardedProps` in any breadcrumb. [Source: epic-4 :176; trap #5]
> - **AC2 surface + redaction targets.** ctor **A.2-verbatim** `PIIRedactionInterceptor({required List<Pattern> patterns})`. Redact these free-text content fields (trap #2 — and ONLY these), applying every pattern via `value.replaceAll(pattern, '[REDACTED]')`: `TextMessageContentEvent.delta`, `ToolCallArgsEvent.delta`, `ToolCallResultEvent.content`, `ReasoningMessageContentEvent.delta`, and the optional `delta` of the chunk variants (`TextMessageChunkEvent.delta`, `ToolCallChunkEvent.delta`, `ReasoningMessageChunkEvent.delta`) when non-null. Leave `CustomEvent.value` untouched (structured app data / reserved markers, not chat content). Every other event passes through unchanged. [Source: AC :181-182; text_message_events.dart, tool_call_events.dart, reasoning_events.dart; trap #2]
> - **AC4 exact contract.** Pattern list `[RegExp(r'\b\d{4}-\d{4}-\d{4}-\d{4}\b')]`; a `TextMessageContentEvent` whose `delta` contains `4111-1111-1111-1111` (or similar) emerges from the interceptor with that substring replaced by the literal `[REDACTED]`. Assert against the **consumer-visible** (post-interceptor) stream. [Source: AC :188-190]
> - **AC3 default-off proof.** With neither interceptor registered, replay a fixture and assert (a) the text content is byte-identical to the raw wire payload (no redaction) and (b) no breadcrumb is added (no `SentryBreadcrumbInterceptor` in the chain ⇒ trivially zero Sentry calls). [Source: AC :184-186; FR-I2]
> - **OUT OF SCOPE (RESOLVED — do NOT build):** auto-wiring either interceptor into `HttpAgent`'s default chain (trap #1/#6); chunk synthesis (Story 4.8); `onConnect`/`onDisconnect`/`onReconnectAttempt` lifecycle hooks (4.9); web transport + perf baseline (4.10); the per-member `analysis_options.yaml` doc gate + ≥90% coverage gate (epic-sealing **Story 4.10**); any `koel_core` change (redaction reads existing event types — no new fields); the `KoelClient.transforms` post-reduce `StreamTransformer` redaction path ([architecture.md:656](_bmad-output/planning-artifacts/architecture.md) — a *different* mechanism, Epic-6; this story is the pre-pipeline interceptor); calling `Sentry.init` (the consumer's app does that). [Source: epic-4 :192-271; architecture.md:656; 4-6 out-of-scope precedent]

## Tasks / Subtasks

- [x] **Task 0 — Read the real surfaces before writing a line** (AC: all — skipping this builds the wrong seam)
  - [x] Re-read [interceptor.dart](packages/koel_core/lib/src/agent/interceptor.dart) **lines 25-67** — the `.map` example (trap #4 is exactly this shape) and the chain's error/cancel policy: stream errors become a terminal `RunErrorEvent`, cancellation is transparent. [Source: interceptor.dart:25-67]
  - [x] Read [event_trace_interceptor.dart](packages/koel_http/lib/src/interceptors/event_trace_interceptor.dart) **lines 64-73** — the best-effort `write` (side channel must never break the run); mirror it for `addBreadcrumb` (trap #6). Note it used a controller for *lifecycle* observation — you do **not** need that (trap #4). [Source: event_trace_interceptor.dart:44-141]
  - [x] Read [auth_interceptor.dart](packages/koel_http/lib/src/interceptors/auth_interceptor.dart) **lines 39-69** — the secret-free discipline (`forwardedProps` carries the reserved auth-headers key; never log/breadcrumb it) and the `final`/`non-final` rationale (trap #5/#7). [Source: auth_interceptor.dart:39-69]
  - [x] Read [retry_interceptor.dart](packages/koel_http/lib/src/interceptors/retry_interceptor.dart) **lines 1-60** — house structure: `final class … implements Interceptor`, exhaustive dartdoc, A.2-verbatim ctor with `assert`s. Mirror this shape. [Source: retry_interceptor.dart:1-60]
  - [x] Skim the text-bearing event definitions to confirm trap #2's field list: [text_message_events.dart:47-50,107-128](packages/koel_core/lib/src/event/text_message_events.dart), [tool_call_events.dart:45-52,103-156](packages/koel_core/lib/src/event/tool_call_events.dart), [reasoning_events.dart:86-94,147-153](packages/koel_core/lib/src/event/reasoning_events.dart). Confirm every subtype is `@freezed` (so `copyWith` exists). [Source: trap #2/#3]
  - [x] Read [http_agent.dart](packages/koel_http/lib/src/http_agent.dart#L105-L129) — confirm `run` auto-prepends **only** `RetryInterceptor`; neither 4.7 interceptor is wired (trap #1). [Source: http_agent.dart:105-129]

- [x] **Task 1 — `sentry` dependency** (AC: #1)
  - [x] Add `sentry: ^9.21.0` to `dependencies:` in [packages/koel_http/pubspec.yaml](packages/koel_http/pubspec.yaml) (MODIFY) — the pure-Dart sentry SDK (NOT `sentry_flutter`; koel_http is framework-free). Add a comment: koel_http's first third-party runtime dep; default-OFF interceptor; ships no telemetry unless registered + `Sentry.init`-ed (trap #1). [Source: pub.dev sentry 9.21.0; trap #1]
  - [x] `dart pub get` resolves clean at the analyzer-12 workspace pins (SCP-2026-05-29-B). If sentry 9.21.0 pulls an analyzer that conflicts with the freezed `3.2.6-dev.1` / analysis_server_plugin pin, **stop and report** — do not bump the workspace analyzer to resolve it (that reopens SCP-2026-05-29-B). [Source: SCP-2026-05-29-B; 4-6 Latest Tech]

- [x] **Task 2 — `PIIRedactionInterceptor`** (AC: #2, #4)
  - [x] In [packages/koel_http/lib/src/interceptors/pii_redaction_interceptor.dart](packages/koel_http/lib/src/interceptors/pii_redaction_interceptor.dart) (NEW) declare `final class PIIRedactionInterceptor implements Interceptor` with the **A.2-verbatim** ctor `PIIRedactionInterceptor({required List<Pattern> patterns})` (store as an unmodifiable copy). Optional `assert(patterns.isNotEmpty, ...)` is defensible (an empty list is a no-op redactor — a likely misconfiguration). [Source: addendum.md:327-328]
  - [x] `intercept(chain, input)` returns `chain.proceed(input).map(_redact)` — pure transform, no controller (trap #4). A private `String _scrub(String text)` folds every pattern: `var out = text; for (final p in _patterns) out = out.replaceAll(p, '[REDACTED]'); return out;`. [Source: trap #4/#8; AC :190]
  - [x] `_redact(AgUiEvent e)` is a `switch` over the sealed union (trap #3) that `copyWith`s the scrubbed field for each redaction target (trap #2 list) and returns `e` unchanged in the `default:` (and for null optional deltas — only scrub when non-null). The `default:` is mandatory (`exhaustive_switch_must_have_default`). [Source: trap #2/#3; AC :181-182]
  - [x] Exhaustive dartdoc: the redaction surface (which fields, and **why structural ids are excluded** — trap #2), that it is a pre-pipeline interceptor distinct from the Epic-6 `KoelClient.transforms` post-reduce path ([architecture.md:656](_bmad-output/planning-artifacts/architecture.md)), that `Pattern` accepts both `RegExp` and `String`, and that redaction is total/pure (cannot fail). [Source: architecture.md:656; trap #2/#8]

- [x] **Task 3 — `SentryBreadcrumbInterceptor`** (AC: #1)
  - [x] In [packages/koel_http/lib/src/interceptors/sentry_breadcrumb_interceptor.dart](packages/koel_http/lib/src/interceptors/sentry_breadcrumb_interceptor.dart) (NEW) declare `final class SentryBreadcrumbInterceptor implements Interceptor` with ctor `SentryBreadcrumbInterceptor({Hub? hub}) : _hub = hub ?? HubAdapter();` (`Hub`/`HubAdapter`/`Breadcrumb`/`SentryLevel` from `package:sentry/sentry.dart`). [Source: addendum.md:326; trap #1]
  - [x] `intercept(chain, input)` returns `chain.proceed(input).map((event) { _breadcrumb(event); return event; })` — per-event side effect, pure pass-through, no controller (trap #4). [Source: interceptor.dart:29-40; trap #4]
  - [x] `_breadcrumb(AgUiEvent event)` builds a `Breadcrumb(category: 'koel.event', message: <event wire/runtime type>, level: <info, or error for RunErrorEvent>, data: <structural ids only — messageId/toolCallId/runId where present; NEVER delta/content/forwardedProps>)` and calls `_hub.addBreadcrumb(crumb)` **best-effort** (try/catch swallow — trap #6, mirror EventTraceInterceptor). A disabled hub (no `Sentry.init`) is a silent no-op. [Source: trap #5/#6; event_trace_interceptor.dart:67-73]
  - [x] Exhaustive dartdoc: default-OFF semantics (not in the default chain; emits nothing until registered AND `Sentry.init`-ed; even then breadcrumbs only ship attached to a captured Sentry event — no standalone network traffic, reinforcing "no silent telemetry"); the **no-PII-in-breadcrumbs** rule (trap #5); the `Hub?` test seam; that consumers init/own Sentry. [Source: trap #1/#5; FR-I2]

- [x] **Task 4 — Barrel exports** (AC: #1, #2)
  - [x] In [koel_http.dart](packages/koel_http/lib/koel_http.dart) (MODIFY) add (grouped with the existing interceptor exports, alphabetical): `export 'src/interceptors/pii_redaction_interceptor.dart';` and `export 'src/interceptors/sentry_breadcrumb_interceptor.dart';`. Both classes are public API (A.2). The export of `sentry_breadcrumb_interceptor.dart` transitively re-exports nothing of sentry's surface — keep the file's `sentry` import non-`export`ed. [Source: koel_http.dart:1-12; addendum.md:326-328]

- [x] **Task 5 — Tests** (AC: #1, #2, #3, #4)
  - [x] New `packages/koel_http/test/pii_redaction_interceptor_test.dart` (`package:test`; reuse the [retry_interceptor_test.dart](packages/koel_http/test/retry_interceptor_test.dart) `_StubAgent` + fixture-payload helpers, OR drive an in-test `Stream<AgUiEvent>` through a chain):
    - [x] **AC2 surface:** `PIIRedactionInterceptor(patterns: [RegExp('x')])` is an `Interceptor`.
    - [x] **AC4 redaction (the load-bearing test):** run a stream containing `TextMessageContentEvent(messageId: 'm', delta: 'card 4111-1111-1111-1111 ok')` through `PIIRedactionInterceptor(patterns: [RegExp(r'\b\d{4}-\d{4}-\d{4}-\d{4}\b')])`; assert the emitted event's `delta == 'card [REDACTED] ok'` **and** `messageId == 'm'` (structural id untouched — trap #2).
    - [x] **Other text fields:** assert `ToolCallArgsEvent.delta`, `ToolCallResultEvent.content`, `ReasoningMessageContentEvent.delta`, and a chunk variant's `delta` are scrubbed; assert `CustomEvent`, `RunStartedEvent`, `TextMessageStartEvent` (ids/role) pass through **unchanged** (trap #2).
    - [x] **Multi-pattern + String pattern:** two patterns (one `RegExp`, one literal `String`) both apply; non-matching text is identical.
  - [x] New `packages/koel_http/test/sentry_breadcrumb_interceptor_test.dart`:
    - [x] **AC1 surface:** `SentryBreadcrumbInterceptor()` is an `Interceptor`; constructs with and without an injected `Hub`.
    - [x] **AC1 per-event breadcrumb:** inject a recording `Hub` (a thin `implements Hub` fake capturing `addBreadcrumb`, **or** `Sentry.init` with a `beforeBreadcrumb` recorder + no-op transport and `addTearDown(Sentry.close)`); replay a `text_only_run` fixture; assert one breadcrumb per emitted event, each with `category: 'koel.event'` and **no** `delta`/`content` in `message`/`data` (trap #5).
    - [x] **No-init safety (trap #6):** with the default `HubAdapter()` and Sentry **not** initialized, a full run completes normally and emits no error (best-effort no-op).
  - [x] **AC3 default-off:** in either suite, replay a fixture through a chain with **no** 4.7 interceptor; assert text content is byte-identical to the raw payload and (Sentry suite) the recording hub saw zero breadcrumbs. [Source: AC :184-186]
  - [x] `dart:io` in **test** files is fine (web-safety governs `lib/` only — 4.1–4.6 precedent). Re-run both suites under `--test-randomize-ordering-seed=random`. [Source: 4-6 Task 5]

- [x] **Task 6 — Quality gates (NO finalization gates this story)** (AC: all)
  - [x] `melos run build_runner` (or `melos run build`) → no codegen drift (4.7 adds **no** freezed types — redaction reads existing event `copyWith`; this task only confirms the existing `trace_entry.freezed.dart` still regenerates clean). [Source: 4-6 Task 6]
  - [x] `melos run analyze` → **0 issues** workspace-wide. Watch `exhaustive_switch_must_have_default` on the redaction `switch` (Task 2). [Source: NFR-13]
  - [x] `! grep -rn 'print(' packages/koel_http/lib` → no matches (architecture §4 no-`print`). [Source: architecture.md:587]
  - [x] `melos run test` → green workspace-wide, including the two new suites and the unchanged 4.1–4.6 suites. [Source: tool/test]
  - [x] `melos run format:check` → clean. [Source: tool/format]
  - [x] **`dart_apitool` API-diff is NOT a concern:** no `koel_core` change; the two new classes are additive `koel_http` symbols (no published baseline). [Source: 4-6 Task 6; api-diff.yml]
  - [x] **Do NOT** add koel_http's member `analysis_options.yaml` doc gate or the ≥90% coverage gate — those are **package-finalization** gates that land in epic-sealing **Story 4.10**. Write full dartdoc anyway so 4.10 needs no backfill. [Source: epic-4 overview; 4-6 Task 6]

## Review Findings

> Code review 2026-06-01 (adversarial: Blind Hunter + Edge Case Hunter + Acceptance Auditor). Acceptance Auditor found **zero** AC/trap/scope violations — implementation is fully spec-conformant. All surviving findings concern **robustness of the privacy primitive beyond the spec-locked happy path** (the SDK's "design against misuse" DNA), not spec compliance.

- [x] **[Review][Decision→Patch] PII redactor's pattern-fold mishandles adversarial / empty-match patterns** [pii_redaction_interceptor.dart:100-145] — RESOLVED (harden now). The spec-mandated fold `for (p in patterns) text = text.replaceAll(p, '[REDACTED]')` had three live-verified sharp edges: (1) an empty-match `RegExp` (`\d*`) injected the marker between every char → `[REDACTED]h[REDACTED]e…`; (2) a later pattern re-matched *inside* an earlier `[REDACTED]` → `card [[REDACTED]ACTED]`; (3) overlapping patterns were order-dependent → `['foo','foobar']` over `foobar` leaked `bar`. **Fix:** rewrote `_scrub` as a single pass over the *original* text via `Pattern.allMatches`, dropping empty matches and coalescing overlapping spans — order-independent, marker-safe, empty-match-safe. 3 new robustness tests pin all three.
- [x] **[Review][Decision→Patch] Empty `patterns` list silently disables redaction in release builds** [pii_redaction_interceptor.dart:60-65] — RESOLVED (fail-closed). `assert(patterns.isNotEmpty)` is stripped in AOT/release → an empty list constructed a fail-**open** redactor shipping cleartext silently. **Fix:** upgraded to `throw ArgumentError.value(...)` so the guard survives release builds; test updated to expect `ArgumentError`.
- [x] **[Review][Defer] Breadcrumb message uses `runtimeType.toString()`** [sentry_breadcrumb_interceptor.dart:206] — deferred, spec-conformant. Under `dart2js`/AOT obfuscation (`--obfuscate`) type names mangle, so the breadcrumb's only identifying field degrades to opaque symbols in obfuscated release builds. Spec explicitly allowed `runtimeType` (AC1 "event wire/runtime type"); observability-only, no correctness impact.

**Dismissed as noise (4 — verified false positives):** chunk events carry no unscrubbed PII fields besides `delta` (`toolCallName` is routing/identity, test-asserted pass-through); the `try/on Object` around `unawaited(addBreadcrumb)` is necessary-and-sufficient (guards a non-conformant hub returning `null` synchronously); breadcrumb-vs-event ordering is preserved (`Scope._addBreadCrumbSync` appends synchronously before the first `await`); `event.error.code.name` cannot null-deref (`error` is `required KoelError`, `code` non-nullable).

## Dev Notes

### What this story is, in one paragraph

The two **opt-in** interceptors that complete koel_http's six-interceptor set. `SentryBreadcrumbInterceptor` adds one Sentry breadcrumb per `AgUiEvent` (event type + structural ids only — never content) to the ambient Sentry hub, so a consumer who runs Sentry gets AG-UI run context attached to their captured errors — **default-OFF**, emitting nothing unless registered. `PIIRedactionInterceptor` runs every consumer-supplied `Pattern` against the free-text content fields of the event stream (message/tool/reasoning deltas + tool-result content), replacing matches with `[REDACTED]` **before** events reach subscribers or the reducer — **default-OFF**. Both are pure, `final class`, framework-free, and compose into the chain like 4.4/4.5/4.6 via a plain `.map` (no controller). Scope is **the two interceptors only**: no Sentry init (consumer's job), no `koel_core` change, no default-chain wiring, no finalization gates (4.10).

### Redaction surface (RESOLVED — trap #2; the "other text-bearing payloads")

`AgUiEvent` is `sealed`; redact via a `switch` that `copyWith`s the scrubbed field, `default:` passes through. **Redact (free-text content):**

| Event | Field | Note |
| --- | --- | --- |
| `TextMessageContentEvent` | `delta` | the explicit AC4 target |
| `ToolCallArgsEvent` | `delta` | streamed tool arguments may carry user PII |
| `ToolCallResultEvent` | `content` | tool output text |
| `ReasoningMessageContentEvent` | `delta` | model reasoning text |
| `TextMessageChunkEvent` | `delta?` | scrub only when non-null (chunk path) |
| `ToolCallChunkEvent` | `delta?` | scrub only when non-null |
| `ReasoningMessageChunkEvent` | `delta?` | scrub only when non-null |

**Do NOT redact (structural / non-content):** `messageId`, `toolCallId`, `parentMessageId`, `role`, `stepName`, `name`, `activityType`, `threadId`/`runId`, `CustomEvent.value` (structured app data + reserved markers like `RetryInterceptor`'s `ConnectionResumed`), `ReasoningEncryptedValueEvent.encryptedValueBase64` (already encrypted — scrubbing is harmful and pointless). Redacting any of these breaks reducer correlation or protocol routing. [Source: text_message_events.dart, tool_call_events.dart, reasoning_events.dart, custom_event.dart; retry_interceptor.dart:29-34]

### Why a pure `.map`, not 4.6's controller wrapper (RESOLVED — trap #4)

4.6 wrapped `chain.proceed` in a `StreamController` because `LoggingInterceptor`/`EventTraceInterceptor` had to observe **lifecycle** events `.map` can't see — first-listen (`request` marker), graceful `onDone` (`response` marker), and `onCancel` (the FINE drop). **4.7 has no such requirement:** redaction is a stateless per-event function, a breadcrumb is a per-event side effect, and a terminal `RunErrorEvent` is itself an event the `.map` sees. The `Interceptor` contract's own example is a `.map` ([interceptor.dart:29-40](packages/koel_core/lib/src/agent/interceptor.dart)), and `.map` is cancel-transparent (the chain forwards cancel to the delegated stream — interceptor.dart:64-67). Use `.map`. A controller here is dead complexity. [Source: interceptor.dart:29-67; event_trace_interceptor.dart:52-141]

### Sentry breadcrumb shape + the no-PII rule (RESOLVED — trap #5)

```
Breadcrumb(
  category: 'koel.event',
  message: event.runtimeType.toString(),   // or the AG-UI wire type — type, NOT content
  level: event is RunErrorEvent ? SentryLevel.error : SentryLevel.info,
  data: { 'messageId'/'toolCallId'/'runId': <when present> },   // structural ids only
)
```

A breadcrumb that embedded `delta`/`content` would leak chat content to Sentry — exactly the privacy failure this story exists to prevent. Breadcrumbs are added to the hub but **only transmitted** when the consumer's app later captures a Sentry event/exception — so even registered + initialized, this interceptor produces no standalone network traffic (reinforces "no silent telemetry"). Wrap `addBreadcrumb` best-effort (trap #6): a disabled/throwing hub must never disrupt the run. [Source: architecture §5; 4-5 trap #2; sentry-dart Breadcrumb]

### default-OFF = not wired + emits nothing unless registered (RESOLVED — trap #1/#6)

"default-OFF" is enforced structurally, not by a flag: `HttpAgent.run` auto-prepends only `RetryInterceptor` ([http_agent.dart:105-129](packages/koel_http/lib/src/http_agent.dart)), so neither 4.7 interceptor is in any default chain. A consumer opts in by adding it to `interceptors:`. AC3 proves it: a default run makes zero Sentry calls and applies zero redaction. Adding `sentry` to pubspec ships no telemetry — telemetry needs registration **and** `Sentry.init` (the consumer's app). [Source: http_agent.dart:105-129; AC :184-186]

### Why `sentry` is a hard dependency (RESOLVED — trap #1)

| Approach | AC1 "via sentry"? | Dep weight | Verdict |
| --- | --- | --- | --- |
| **Hard `sentry: ^9.21.0` dep in koel_http (CHOSEN)** | ✓ | one pure-Dart pkg, pulled transitively | matches AC + architecture file-tree; default-OFF means zero runtime cost unless used |
| Optional/soft dep (conditional import / reflection) | ✗ (no clean Dart path) | nil | rejected — Dart has no optional-dependency mechanism for a typed API; would force a stringly-typed shim |
| Separate `koel_sentry` package | ✓ | nil for koel_http | rejected — over-engineering for one ~40-LOC leaf interceptor; the architecture explicitly places it in `koel_http/lib/src/interceptors/` |

The addendum's "massive transitive dep weight" critique (line 621, firebase) targets *opinionated multi-package families with init choreography* — not one optional leaf interceptor. `sentry` (pure Dart, no Flutter, no native) is acceptable. [Source: architecture.md:841,1075; addendum.md:621; pub.dev]

### Files you will touch

| Path | Action | Note |
| --- | --- | --- |
| [packages/koel_http/pubspec.yaml](packages/koel_http/pubspec.yaml) | MODIFY | add `sentry: ^9.21.0` (dep) — koel_http's first third-party runtime dep; default-OFF. |
| [packages/koel_http/lib/src/interceptors/pii_redaction_interceptor.dart](packages/koel_http/lib/src/interceptors/pii_redaction_interceptor.dart) | NEW | `final class PIIRedactionInterceptor implements Interceptor`; A.2 ctor `{required List<Pattern> patterns}`; `.map` + `copyWith` redaction over the content-field family. |
| [packages/koel_http/lib/src/interceptors/sentry_breadcrumb_interceptor.dart](packages/koel_http/lib/src/interceptors/sentry_breadcrumb_interceptor.dart) | NEW | `final class SentryBreadcrumbInterceptor implements Interceptor`; ctor `{Hub? hub}`; per-event best-effort breadcrumb (type + ids only). |
| [packages/koel_http/lib/koel_http.dart](packages/koel_http/lib/koel_http.dart) | MODIFY | barrel-export the two new files. |
| `packages/koel_http/test/pii_redaction_interceptor_test.dart` | NEW | AC2 surface + AC4 redaction + other-fields + structural-untouched + multi-pattern. |
| `packages/koel_http/test/sentry_breadcrumb_interceptor_test.dart` | NEW | AC1 surface + per-event breadcrumb (recording hub) + no-init safety + AC3 default-off. |

### Library / framework requirements

- **Runtime:** `package:koel_core` (barrel) — `Interceptor`, `InterceptorChain`, the sealed `AgUiEvent` + its `@freezed` subtypes (`TextMessageContentEvent`, `ToolCallArgsEvent`, `ToolCallResultEvent`, `ReasoningMessageContentEvent`, the chunk events, `RunErrorEvent`, `CustomEvent`), `RunAgentInput`; `package:sentry ^9.21.0` (**new** — `Hub`, `HubAdapter`, `Breadcrumb`, `SentryLevel`); SDK `dart:core` (`Pattern`, `String.replaceAll`), `dart:async` (`Stream.map`).
- **Dev:** `package:test ^1.25.0`; `koel_test` (workspace, `FixtureLoader`); `koel_lints` (workspace). Existing `build_runner`/`freezed` toolchain stays (4.6) but 4.7 adds **no** new generated types.
- **Forbidden in `lib/`:** `dart:io`/`dart:html`/`package:web` (both interceptors are platform-neutral pure stream transforms); Flutter / `sentry_flutter` (koel_http is framework-free — use pure `sentry`); any text content / token / `forwardedProps` in a breadcrumb (trap #5); **no `print`**. [Source: architecture.md:587; CLAUDE.md]

### Project Structure Notes

- All changes stay within `koel_http`; **no koel_core change** (redaction uses existing event `copyWith`). SDK constraint stays `">=3.11.0 <4.0.0"`; no member `analysis_options.yaml` (gates are 4.10's).
- `pii_redaction_interceptor.dart` / `sentry_breadcrumb_interceptor.dart` are the **fifth and sixth** interceptors in `lib/src/interceptors/`, after retry (4.4), auth (4.5), logging + event_trace (4.6) — completing the file tree at [architecture.md:836-842](_bmad-output/planning-artifacts/architecture.md).
- Barrel discipline: both new public classes exported; sentry's surface is **not** re-exported. New tests sit flat in `test/` beside the existing suites.

### Previous Story Intelligence

- **Story 4.6** built the controller-wrapper pattern for *lifecycle* observation and the best-effort `write` for a faulty consumer sink ([event_trace_interceptor.dart:64-73](packages/koel_http/lib/src/interceptors/event_trace_interceptor.dart)). 4.7 reuses the **best-effort side-channel** discipline for `addBreadcrumb` (trap #6) but **not** the controller (trap #4 — a `.map` suffices). It also kept `koel_core` untouched and added no finalization gates — same here. [Source: 4-6 Dev Notes]
- **Story 4.5** established the secret-free discipline (no token in errors; `forwardedProps` carries the reserved auth-headers key) — extend it to breadcrumbs (no content, no `forwardedProps` — trap #5). It also set the `final` vs non-`final` rule (only Auth/HttpAgent are non-final for Epic-5). [Source: auth_interceptor.dart:39-69; 4-5 trap #2]
- **Story 4.4** established `final class … implements Interceptor` + the `_StubAgent` fixture for injecting typed events without a server ([retry_interceptor_test.dart:65-79](packages/koel_http/test/retry_interceptor_test.dart#L65-L79)) — reuse `_StubAgent` (or a plain in-test `Stream<AgUiEvent>`) for the redaction + breadcrumb tests. Its `ConnectionResumed` `CustomEvent` is precisely the marker redaction must NOT touch (trap #2). [Source: retry_interceptor.dart:29-41]
- **Story 2.9** built `InterceptorChain` whose `proceed` converts stream errors to a terminal `RunErrorEvent` and treats cancellation as transparent — so a `.map` transform is safe and complete (the error is an event you see; cancel forwards beneath). [Source: interceptor.dart:25-67]
- **House style** (3.x, 4.1–4.6): `final`/`sealed` where possible, `const` ctors, exhaustive dartdoc, table-driven `package:test`, tight change sets, composition over config, pure transforms over hidden state, no finalization gates until the epic-sealing story. [Source: `git log`; 4-6 :233]

### Latest Tech Information

- **`sentry` (pure Dart) `9.21.0`** is current stable (pub.dev, publisher `sentry.io`, 160/160 pub points). Use `package:sentry`, **not** `sentry_flutter` (that pulls Flutter — koel_http is framework-free). Public API used: `Hub` (abstract), `HubAdapter()` (forwards to the ambient/current hub — the default seam), `Breadcrumb({String? message, String? category, SentryLevel? level, Map<String,dynamic>? data, ...})`, `SentryLevel` (`info`/`error`/…), `Hub.addBreadcrumb(Breadcrumb, {Hint?})`. Breadcrumbs accumulate on the hub and ship only when a Sentry event is captured. A non-initialized hub no-ops `addBreadcrumb`. [Source: pub.dev sentry 9.21.0; sentry-dart docs]
- **Testing Sentry without a backend:** either inject a thin `implements Hub` recorder via the `Hub?` ctor seam, or `await Sentry.init((o) { o.dsn = '<fake>'; o.beforeBreadcrumb = (crumb, hint) { recorded.add(crumb); return crumb; }; })` with `addTearDown(() => Sentry.close())` and run through the default `HubAdapter()`. The `beforeBreadcrumb` callback is public and fires for every `addBreadcrumb`. Prefer the injected-`Hub` recorder if implementing the (large) `Hub` interface proves heavy — a focused fake overriding only `addBreadcrumb` and `noSuchMethod`-ing the rest is acceptable. [Source: sentry-dart SentryOptions.beforeBreadcrumb]
- **`Pattern` (`dart:core`):** the interface implemented by both `RegExp` and `String`. `String.replaceAll(Pattern from, String to)` accepts either, so one code path handles regex and literal patterns. Replacement is the literal `'[REDACTED]'` (AC4). [Source: dart:core; AC :190]
- **No `dart_apitool` exposure:** `koel_core` unchanged; the two new symbols are additive to `koel_http` (no published baseline). Adding `sentry` as a dependency has no koel API-surface effect (not re-exported). [Source: api-diff.yml; 4-6]

### References

- Story spec (ACs, A.2 signatures): [epic-4 Story 4.7](_bmad-output/planning-artifacts/epics/epic-4-http-transport-koelhttp.md) (lines 166-190); canonical ctors `SentryBreadcrumbInterceptor implements Interceptor { ... }` + `PIIRedactionInterceptor({required List<Pattern> patterns})`: [addendum.md §A.2](_bmad-output/planning-artifacts/prds/prd-koel-2026-05-27/addendum.md#L326-L329).
- Interceptor contract + `.map` example + chain error/cancel policy: [interceptor.dart:25-67](packages/koel_core/lib/src/agent/interceptor.dart).
- Side-channel best-effort + final-class precedent: [event_trace_interceptor.dart](packages/koel_http/lib/src/interceptors/event_trace_interceptor.dart), [retry_interceptor.dart:41](packages/koel_http/lib/src/interceptors/retry_interceptor.dart).
- Secret-free discipline + reserved `forwardedProps` key: [auth_interceptor.dart:39-69](packages/koel_http/lib/src/interceptors/auth_interceptor.dart).
- Text-bearing event fields (redaction targets): [text_message_events.dart](packages/koel_core/lib/src/event/text_message_events.dart), [tool_call_events.dart](packages/koel_core/lib/src/event/tool_call_events.dart), [reasoning_events.dart](packages/koel_core/lib/src/event/reasoning_events.dart).
- File tree (interceptors), telemetry integration point, no-`print`, exhaustive-switch lint, transforms-vs-interceptor distinction: [architecture.md:836-842,1075,587,525-535,656](_bmad-output/planning-artifacts/architecture.md).
- Default-chain (only retry auto-wired): [http_agent.dart:105-129](packages/koel_http/lib/src/http_agent.dart).
- Test exemplars (`_StubAgent`, fixture payloads, loopback server): [retry_interceptor_test.dart](packages/koel_http/test/retry_interceptor_test.dart).
- `sentry` 9.21.0 dependency rationale: SCP-2026-05-29-B (analyzer-12 pins must hold after adding sentry) — [sprint-change-proposal-2026-05-29-analyzer12-freezed.md](_bmad-output/planning-artifacts/sprint-change-proposal-2026-05-29-analyzer12-freezed.md).

### Design decisions (RESOLVED — AC/architecture-forced, not open)

1. **`sentry: ^9.21.0` is a hard koel_http runtime dependency** (pure Dart, not `sentry_flutter`); default-OFF means zero telemetry unless registered + `Sentry.init`-ed. [trap #1]
2. **PII redaction targets free-text content fields ONLY** (message/tool/reasoning deltas + tool-result content + non-null chunk deltas); structural ids/roles/`CustomEvent.value`/encrypted values are never touched. [trap #2]
3. **Redaction dispatches via a `switch` over the sealed `AgUiEvent` with a mandatory `default:`**, `copyWith`-ing the scrubbed field. [trap #3; koel_lints]
4. **Both interceptors are a pure `.map` over `chain.proceed(input)`** — no `StreamController` wrapper (unlike 4.6). [trap #4]
5. **Breadcrumbs carry event type + structural ids only — never content/tokens/`forwardedProps`.** [trap #5]
6. **The breadcrumb path is best-effort** (swallowed try/catch); a disabled/throwing hub never disrupts the run. Redaction is total/pure and cannot fail. [trap #6]
7. **Both are `final class`** — no Epic-5 subclass. [trap #7]
8. **`List<Pattern>` handles `RegExp` and `String` uniformly via `replaceAll`; replacement is the literal `[REDACTED]`.** [trap #8]
9. **Neither is auto-wired into `HttpAgent`'s default chain** (default-OFF is structural, not a flag). [trap #1/#6]
10. **No `koel_core` change; no `Sentry.init`; no `KoelClient.transforms` path; no finalization gates (4.10).** [out-of-scope]

These are baked in — implement them; no confirmation gate.

## Dev Agent Record

### Context Reference

<!-- Path(s) to story context will be added here by context workflow -->

### Agent Model Used

claude-opus-4-8[1m] (Opus 4.8, 1M context) — via `/agent-flutter-engineer` (implement mode).

### Debug Log References

- `dart pub get` — resolved clean at analyzer **12.1.0** (the SCP-2026-05-29-B workspace pins held; `sentry 9.21.0` pulls no `analyzer` edge, so freezed `3.2.6-dev.1` + analysis_server_plugin are undisturbed).
- `dart analyze` (koel_http, then `melos run analyze`) — **0 issues** workspace-wide. The redaction switch's final `_ => event` satisfies `exhaustive_switch_must_have_default`.
- `! grep -rn 'print(' packages/koel_http/lib` — no matches.
- `melos run build` — codegen clean; koel_http regenerated only the existing `trace_entry.freezed.dart` (4.7 adds no new freezed types).
- `bash tool/format.sh check` — clean (after one `dart format` pass on the two new test files).
- `dart test --exclude-tags=perf --test-randomize-ordering-seed=random` (koel_http) — **79** pass (68 from 4.6 + **11 new**: 6 PII + 5 Sentry).
- Full `melos run test`: green except one flaky timeout in the **pre-existing 4.3** `cancellation_test.dart` (a sub-50ms TCP-teardown assertion with a 2s window) under concurrent cross-package CPU load — passes **3/3 in isolation**, and is not on any 4.7 code path (`sentry` is imported by nothing there; both new interceptors are pure `.map` not in that test's chain). Not a regression.

### Completion Notes List

- **All 4 ACs satisfied.** AC1 — `final class SentryBreadcrumbInterceptor implements Interceptor`, one content-free breadcrumb per event via the ambient/injected `Hub`, nothing emitted unless registered. AC2 — `PIIRedactionInterceptor({required List<Pattern> patterns})`, scrubs the text-content family. AC3 — with neither registered, content is byte-identical and zero breadcrumbs recorded. AC4 — a card-number `RegExp` rewrites `TextMessageContentEvent.delta` to `[REDACTED]` while `messageId` is untouched.
- **All 8 traps honored:** (1) `sentry: ^9.21.0` hard dep, analyzer-12 pin intact; (2) redaction targets free-text content only — structural ids/`CustomEvent.value`/encrypted blob untouched (proven by the same-instance pass-through test); (3) `switch` over the sealed `AgUiEvent` with the mandatory `_ => event` default; (4) both interceptors are a pure `.map` — no `StreamController` wrapper; (5) breadcrumbs carry event type + (for errors) `code` only, never content/`forwardedProps`; (6) breadcrumb dispatch is fire-and-forget best-effort — a throwing/uninitialised hub never disrupts the run (test-proven); (7) both `final class`; (8) `List<Pattern>` handles `RegExp` and `String` via `replaceAll`, replacement is the literal `[REDACTED]`.
- **Breadcrumb payload kept deliberately content-free:** `message: event.runtimeType.toString()`, `category: 'koel.event'`, `level: error` for `RunErrorEvent` (with `data: {'code': …}`) else `info`. No per-event `data` for non-error events — the leanest leak-proof shape (rather than a 28-arm id-extraction switch that would duplicate the union for marginal correlation value).
- **`PIIRedactionInterceptor` asserts non-empty `patterns`** — an empty list is a no-op redactor, almost always a misconfiguration (test-covered).
- **No `koel_core` change; no `dart_apitool` exposure** — the two new symbols are additive `koel_http` API; `sentry` is a dependency, not re-exported.
- **No finalization gates added** (per-member `analysis_options.yaml` doc gate, ≥90% coverage) — those land in epic-sealing Story 4.10. Full dartdoc written on both new public classes so 4.10's doc gate needs no backfill.

### File List

- `packages/koel_http/pubspec.yaml` (MODIFY) — added `sentry: ^9.21.0` (dep); koel_http's first third-party runtime dependency.
- `packages/koel_http/lib/src/interceptors/pii_redaction_interceptor.dart` (NEW) — `final class PIIRedactionInterceptor`.
- `packages/koel_http/lib/src/interceptors/sentry_breadcrumb_interceptor.dart` (NEW) — `final class SentryBreadcrumbInterceptor`.
- `packages/koel_http/lib/koel_http.dart` (MODIFY) — barrel-exported the two new files.
- `packages/koel_http/test/pii_redaction_interceptor_test.dart` (NEW) — AC2 surface + AC4 redaction + content-family + structural pass-through + multi-pattern + AC3 default-off.
- `packages/koel_http/test/sentry_breadcrumb_interceptor_test.dart` (NEW) — AC1 surface/per-event breadcrumb + error-level/code + throwing/uninitialised-hub safety + AC3 default-off.

## Change Log

| Date | Change |
| --- | --- |
| 2026-06-01 | Story 4.7 implemented — `SentryBreadcrumbInterceptor` + `PIIRedactionInterceptor` (both default-OFF); `sentry: ^9.21.0` added as koel_http's first third-party runtime dep. All 4 ACs satisfied; 11 new tests; workspace analyze/format/build/test green (koel_http 79). Status → review. |
