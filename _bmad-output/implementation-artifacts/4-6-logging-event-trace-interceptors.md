---
baseline_commit: c8de5e91141dcb7073b703854c96d67652fc3e19
---

# Story 4.6: `LoggingInterceptor` + `EventTraceInterceptor`

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

> **Dev agent:** this is **Story 4.6 of Epic 4** (HTTP transport, `koel_http`). It ships the SDK's two **observability** interceptors — `LoggingInterceptor` (human-readable run logging via `package:logging`) and `EventTraceInterceptor` (structured `TraceEntry` capture into a consumer `Sink`) — plus the **new freezed `TraceEntry` value type + `TracePhase` enum**. It touches `.dart` files and the interceptor/stream seam, so **invoke `/agent-flutter-engineer` before producing any code** (per [CLAUDE.md](CLAUDE.md)). `packages/koel_http/` already ships `SseParser` (4.1), `HttpAgent` + the transport seam (4.2), the `abortOnCancel` watchdog + the process-once abort-not-honored `Level.WARNING` (4.3), the `RetryInterceptor` engine (4.4), and the `AuthInterceptor` (4.5). **Seven things are load-bearing — the first three are traps that will sink a naïve reading of the AC:**
>
> 1. **`TraceEntry` is the FIRST codegen in `koel_http` — the AC says "freezed type", so you must introduce the freezed toolchain to this package.** Every other koel value type is freezed (e.g. [`RunAgentInput`](packages/koel_core/lib/src/input/run_agent_input.dart) — `@freezed`, `part 'x.freezed.dart'`), but `koel_http` has been **codegen-free** through 4.1–4.5. AC1 (line 158) freezes `TraceEntry` as **"a freezed type"** — so add `freezed_annotation: ^3.1.0` (dep) + `build_runner: ^2.4.0` + `freezed: 3.2.6-dev.1` (dev), the **exact SCP-2026-05-29-B-approved pins** mirrored from [koel_core/pubspec.yaml](packages/koel_core/pubspec.yaml#L8-L21). **No `json_serializable`** — `TraceEntry` is an in-process Dart type written to a `Sink`, never serialized to the wire (freezed-**without**-json, the `RunAgentInput` precedent). Run codegen with `dart run build_runner build` (the workspace `melos run build_runner` task — **NOT** `--delete-conflicting-outputs`, removed/no-op per the SCP side-finding); commit the generated `trace_entry.freezed.dart`. [Source: AC :158; addendum.md:313; SCP-2026-05-29-B §3,§4; run_agent_input.dart:1-44]
> 2. **`LoggingInterceptor.level` is an emission THRESHOLD over fixed architecture-§4 per-category levels — NOT a single level every record logs at.** This is the central LoggingInterceptor trap. AC3 (lines 161-163) tests `LoggingInterceptor(level: Level.fine)` and asserts **per-event tracing appears at `Level.fine`** — proving per-event is **always** `FINE` (architecture §4 line 588), not "whatever you pass". So each lifecycle category logs at its **fixed §4 level** and `level` gates which records emit (`if (categoryLevel >= level) log.log(categoryLevel, …)`). Default `Level.info` ⇒ lifecycle (INFO) shows, per-event (FINE) is suppressed; `Level.fine` ⇒ everything shows. [Source: AC :149-164; architecture.md:587-592]
> 3. **The cancellation drop log is `Level.fine` PER CANCELLED RUN — the "exactly once per process" in the AC is the SEPARATE 4.3 abort-not-honored `WARNING`, which this story does NOT touch.** AC3 line 164 reads "cancellation drops log at `Level.fine` exactly once per process" — that phrasing **conflates two distinct logs**. Architecture §4 (line 588) is the authority: `Level.FINE` = "per-event tracing, **cancellation TCP-abort drops**" with **no** once-per-process qualifier. The once-per-process log is the abort-not-honored `Level.WARNING` already shipped in [cancellation.dart](packages/koel_http/lib/src/connection/cancellation.dart) (4.3) — whose own dartdoc says *"The normal per-event cancellation trace is `Level.FINE` and belongs to the `LoggingInterceptor` (Story 4.6), not here."* **RESOLVED:** the `LoggingInterceptor` logs the cancellation drop at `FINE` **once per cancelled run**; do **NOT** add a process-once gate, and do **NOT** modify `cancellation.dart`'s WARNING. [Source: architecture.md:588; cancellation.dart:13-18; AC :164]
> 4. **To observe cancellation, the `LoggingInterceptor` must wrap the delegated stream in a `StreamController` (the `abortOnCancel` shape) — a `StreamTransformer`/`.map` CANNOT see `cancel()`.** Logging needs request-start, response-start (first event), per-event, completion (`onDone`), error (`onError`), **and cancellation** (`onCancel`). Only a controller's `onCancel` exposes cancellation; `StreamTransformer.fromHandlers` has no cancel handler. Mirror [`abortOnCancel`](packages/koel_http/lib/src/connection/cancellation.dart)'s `onListen`/`onPause`/`onResume`/`onCancel` wrapper, forwarding cancel to the upstream subscription so the **4.3 sub-50ms abort invariant (NFR-8) is preserved** (logging must be transparent to teardown). [Source: cancellation.dart:50-95; interceptor.dart:64-67]
> 5. **The class is `EventTraceInterceptor` (A.2-verbatim), NOT `TraceSinkInterceptor`.** A LOW-severity API review ([review-api-and-completeness.md §2.3](_bmad-output/planning-artifacts/prds/prd-koel-2026-05-27/review-api-and-completeness.md)) *proposed* renaming it; that rename was **never adopted** — the canonical [Addendum A.2](_bmad-output/planning-artifacts/prds/prd-koel-2026-05-27/addendum.md#L313) and the epic both still say `EventTraceInterceptor({required Sink<TraceEntry> sink})` at file `event_trace_interceptor.dart`. Implement the A.2 name; do not re-litigate. [Source: addendum.md:313; epic-4 :157; review-api §2.3]
> 6. **Both interceptors are `final class … implements Interceptor` — neither has an Epic-5 subclass (unlike `AuthInterceptor`).** Only `AuthInterceptor`/`HttpAgent` are intentionally non-`final` (Epic-5 `AgnoAuthInterceptor`/`AgnoAgent` extend them). No `Agno*Logging`/`*Trace` subclass exists in the addendum, so mirror [`RetryInterceptor`](packages/koel_http/lib/src/interceptors/retry_interceptor.dart#L41) — `final class`. [Source: retry_interceptor.dart:41; addendum.md:345-360]
> 7. **Neither interceptor is auto-wired into `HttpAgent`'s default chain — that is OUT OF SCOPE.** The epic *overview* line 3 calls Logging/EventTrace "default-ON", but (a) **no 4.6 AC** wires them into [`HttpAgent.run`](packages/koel_http/lib/src/http_agent.dart#L105-L129) (which auto-prepends only `RetryInterceptor`, and only when `retry` is set), and (b) `EventTraceInterceptor` **cannot** be auto-constructed — it requires a consumer `Sink<TraceEntry>`. Build the interceptor classes + `TraceEntry`; consumers add them to `interceptors:` themselves. Default-chain composition (if ever desired) is a later/`KoelClient` concern, not this story. [Source: http_agent.dart:105-129; epic-4 ACs :149-164]

## Story

As a Flutter/Dart developer,
I want `LoggingInterceptor` for human-readable run logging at configurable levels plus `EventTraceInterceptor` for structured `TraceEntry` capture into a `Sink`,
so that observability ships in the base SDK per FR-B2.

## Acceptance Criteria

Verbatim from [epic-4 Story 4.6](_bmad-output/planning-artifacts/epics/epic-4-http-transport-koelhttp.md) (lines 141-164):

1. **Given** `koel_http/lib/src/interceptors/logging_interceptor.dart`, **When** I inspect it, **Then** the constructor accepts `LoggingInterceptor({Level level = Level.info})` per Addendum A.2, **And** every run lifecycle event (request start, response start, per-event tail, completion, error) logs at the configured level via `package:logging`, **And** no `print` calls appear anywhere in the package per architecture convention §4.

2. **Given** `koel_http/lib/src/interceptors/event_trace_interceptor.dart`, **When** I inspect it, **Then** the constructor matches `EventTraceInterceptor({required Sink<TraceEntry> sink})`, **And** `TraceEntry` is a freezed type with `timestamp`, `event`, `phase` (request/event/response/error), and `runDuration`, **And** every `AgUiEvent` flowing through the chain produces a `TraceEntry` written to the sink.

3. **Given** a `LoggingInterceptor` at `Level.fine`, **When** I run an SSE session and inspect the logs, **Then** per-event tracing appears at `Level.fine` per architecture §4 log-level table, **And** cancellation drops log at `Level.fine` exactly once per process per FR-B3.

> **AC clarifications (RESOLVED — do not re-litigate, implement):**
>
> - **AC1 surface:** the public ctor is `LoggingInterceptor({Level level = Level.INFO})` (one optional named param, `Level` from `package:logging`). `final class LoggingInterceptor implements Interceptor` at `lib/src/interceptors/logging_interceptor.dart`, **exported from the barrel** ([koel_http.dart](packages/koel_http/lib/koel_http.dart)). [Source: addendum.md:312; trap #6]
> - **AC1 — the A.2/epic `Level.info` is a SPEC TYPO; the real constant is `Level.INFO` (uppercase).** `package:logging` exposes only uppercase `Level` constants — `Level.FINE` (500), `Level.INFO` (800), `Level.WARNING` (900), `Level.SEVERE` (1000) ([package:logging/src/level.dart:39-51]). There is **no** `Level.info` — a verbatim copy of the addendum/epic signature `Level.info` **will not compile**. Use `Level.INFO` everywhere (matches `architecture.md`'s `Level.FINE`/`Level.INFO`/`Level.WARNING`/`Level.SEVERE` and `cancellation.dart`). [Source: package:logging/src/level.dart:33-51; addendum.md:312; architecture.md:587-592]
> - **AC1 "logs at the configured level" = THRESHOLD, not uniform level (trap #2):** each lifecycle category logs at its **fixed architecture-§4 level**; `level` is the **minimum** that emits. The exact mapping (RESOLVED — Dev Notes table): request-start/response-start/completion → `INFO`; per-event tail + cancellation drop → `FINE`; terminal error → `SEVERE` for `ProtocolError`, `WARNING` for every other `KoelError`. Default `Level.info` shows lifecycle + errors, hides per-event. [Source: architecture.md:587-592; AC :152]
> - **AC1 "no `print`":** assert by a repo grep gate in the test/task (`! grep -rn 'print(' packages/koel_http/lib`), and use `package:logging` exclusively. The package already depends on `logging: ^1.3.0` (4.3). [Source: architecture.md:587; pubspec.yaml]
> - **AC1 "every lifecycle event logs":** drive a fixture run through `LoggingInterceptor(level: Level.fine)` with a captured `Logger.root.onRecord` listener; assert records for request-start (INFO), response-start (INFO), ≥1 per-event (FINE), completion (INFO). At default `Level.info`, assert per-event (FINE) records are **absent**. [Source: AC :152; trap #2]
> - **AC2 surface + `TraceEntry` shape:** ctor **A.2-verbatim** `EventTraceInterceptor({required Sink<TraceEntry> sink})` (note: `Sink`, **not** `StreamSink` — the synchronous `dart:core` `Sink<T>` with `add`/`close`). `TraceEntry` is **freezed** (trap #1) with exactly `DateTime timestamp`, `AgUiEvent? event` (**nullable** — null for the request/response lifecycle markers), `TracePhase phase`, `Duration runDuration`. `enum TracePhase { request, event, response, error }`. [Source: AC :157-159; addendum.md:313]
> - **AC2 "every `AgUiEvent` produces a `TraceEntry`":** the load-bearing assertion. Replay an Epic-3 fixture (e.g. `text_only_run`) through `EventTraceInterceptor(sink: collector)`; assert the collector received **one `phase: event` entry per emitted `AgUiEvent`** (count + order match the raw stream), bracketed by one `phase: request` (at run start, `event: null`) and one `phase: response` (on graceful completion, `event: null`). A `RunErrorEvent` in the stream produces a `phase: error` entry (carrying that event) **instead of** `event` — so every event still produces exactly one entry. [Source: AC :158-159; Dev Notes "Phase mapping"]
> - **AC3 per-event at FINE + cancellation drop (traps #2/#3/#4):** construct `LoggingInterceptor(level: Level.fine)`, run a **slow** loopback SSE stream (reuse the [cancellation_test.dart](packages/koel_http/test/cancellation_test.dart) slow-server pattern), assert ≥1 `FINE` per-event record appears; then **cancel** the subscription mid-stream and assert **one** `FINE` cancellation-drop record for that run. The drop is **per-run** (not process-once — trap #3); `cancellation.dart`'s separate process-once WARNING is untouched. [Source: AC :161-164; architecture.md:588]
> - **OUT OF SCOPE (RESOLVED — do NOT build):** auto-wiring either interceptor into `HttpAgent`'s default chain (trap #7); `SentryBreadcrumbInterceptor`/`PIIRedactionInterceptor` (Story 4.7 — both default-OFF); chunk synthesis (4.8); `onConnect`/`onDisconnect` lifecycle hooks (4.9); web transport (4.10); the member `analysis_options.yaml` doc gate + ≥90% coverage gate (epic-sealing **Story 4.10**); any `koel_core` change; logging/tracing of **auth headers or tokens** (interceptors see the event stream + `input`, not request headers — but never log secret-bearing `forwardedProps` either). [Source: epic-4 :166-271; 4-5 out-of-scope precedent]

## Tasks / Subtasks

- [x] **Task 0 — Read the real surfaces before writing a line** (AC: all — skipping this builds the wrong seam)
  - [x] Re-read [interceptor.dart](packages/koel_core/lib/src/agent/interceptor.dart) **in full** — the `Interceptor` contract (the `TimingInterceptor` dartdoc example at lines 29-40 is the `.map`-observe pattern; you need MORE than `.map` for cancel — trap #4), and `InterceptorChain.proceed` (stream errors become a terminal `RunErrorEvent`; cancellation is transparent — lines 64-67). [Source: interceptor.dart:1-137]
  - [x] Read [cancellation.dart](packages/koel_http/lib/src/connection/cancellation.dart) **in full** — `abortOnCancel`'s `StreamController` wrapper (`onListen`/`onPause`/`onResume`/`onCancel`, lines 50-95) is the **shape to mirror** for `LoggingInterceptor`'s cancel observation (trap #4); the process-once WARNING (lines 13-18, 96-115) is the abort-not-honored log this story does **not** touch (trap #3). [Source: cancellation.dart:1-115]
  - [x] Read [retry_interceptor.dart](packages/koel_http/lib/src/interceptors/retry_interceptor.dart) (head, lines 1-60) — house structure: `final class … implements Interceptor`, exhaustive dartdoc, A.2-verbatim ctor with `assert`s, `package:koel_core` barrel import. Mirror this shape (trap #6). [Source: retry_interceptor.dart:1-60]
  - [x] Read [run_agent_input.dart](packages/koel_core/lib/src/input/run_agent_input.dart) (lines 1-44) — the **freezed-without-json** pattern (`@freezed`, `part 'x.freezed.dart'`, `const factory … = _X`, imports `package:freezed_annotation`). Replicate it for `TraceEntry` (trap #1). [Source: run_agent_input.dart:1-44]
  - [x] Read architecture §4 log-level table ([architecture.md:587-592](_bmad-output/planning-artifacts/architecture.md)) — the **fixed per-category levels** that drive trap #2's threshold model. [Source: architecture.md:587-592]
  - [x] Read [http_agent.dart](packages/koel_http/lib/src/http_agent.dart#L105-L129) — confirm `run` auto-prepends **only** `RetryInterceptor`; neither observability interceptor is wired (trap #7). [Source: http_agent.dart:105-129]

- [x] **Task 1 — `TraceEntry` + `TracePhase` (the freezed value type)** (AC: #2)
  - [x] Add the freezed toolchain to [packages/koel_http/pubspec.yaml](packages/koel_http/pubspec.yaml) (MODIFY): `dependencies: freezed_annotation: ^3.1.0`; `dev_dependencies: build_runner: ^2.4.0`, `freezed: 3.2.6-dev.1` — the **exact SCP-2026-05-29-B pins** mirrored from [koel_core/pubspec.yaml](packages/koel_core/pubspec.yaml#L8-L21). **No `json_serializable`/`json_annotation`** (no wire JSON — trap #1). Add a comment noting this is koel_http's first codegen and why (TraceEntry must be freezed per AC2). [Source: trap #1; SCP-2026-05-29-B §4]
  - [x] In [packages/koel_http/lib/src/interceptors/trace_entry.dart](packages/koel_http/lib/src/interceptors/trace_entry.dart) (NEW — co-located with its interceptor) declare `enum TracePhase { request, event, response, error }` and `@freezed abstract class TraceEntry with _$TraceEntry { const factory TraceEntry({required DateTime timestamp, required TracePhase phase, required Duration runDuration, AgUiEvent? event}) = _TraceEntry; }` with `part 'trace_entry.freezed.dart';`, importing `package:freezed_annotation/freezed_annotation.dart` + `package:koel_core/koel_core.dart` (for `AgUiEvent`). Exhaustive dartdoc: what each `TracePhase` means, why `event` is nullable (request/response markers carry none), and that `runDuration` is elapsed-since-run-start. [Source: AC :157-159; trap #1]
  - [x] Run `dart run build_runner build` (or `melos run build_runner`) → commit `trace_entry.freezed.dart`. **No `--delete-conflicting-outputs`** (SCP side-finding: removed/no-op). [Source: SCP-2026-05-29-B §2]

- [x] **Task 2 — `EventTraceInterceptor`** (AC: #2)
  - [x] In [packages/koel_http/lib/src/interceptors/event_trace_interceptor.dart](packages/koel_http/lib/src/interceptors/event_trace_interceptor.dart) (NEW) declare `final class EventTraceInterceptor implements Interceptor` with the **A.2-verbatim** ctor `EventTraceInterceptor({required Sink<TraceEntry> sink})` (synchronous `dart:core` `Sink`, not `StreamSink` — trap #5 names the class, this clarifies the param). [Source: addendum.md:313]
  - [x] `intercept(chain, input)`: capture `final start = DateTime.now();` at run start; emit `TraceEntry(phase: request, event: null, timestamp: start, runDuration: Duration.zero)` to the sink **on first listen** (use a `StreamController` wrapper `onListen`, OR — acceptable simpler form — write it synchronously at `intercept` entry since the run stream is single-subscription and always listened; prefer onListen for accurate `start`). Then wrap `chain.proceed(input)` so each emitted `AgUiEvent` writes one entry: `phase: error` if `event is RunErrorEvent`, else `phase: event`; on graceful `onDone` write one `phase: response` (`event: null`). Each entry: `timestamp: DateTime.now()`, `runDuration: DateTime.now().difference(start)`. [Source: AC :158-159; Dev Notes "Phase mapping"]
  - [x] No `level` gating, no `package:logging` here (EventTrace is structured machine-readable, the complement to Logging). No cancel-entry requirement (AC2 is event/request/response/error only — keep it lean; a cancel just stops with no `response` entry). Cancellation must still propagate transparently — if you use a controller, forward cancel to upstream (don't strand it). [Source: AC :157-159; interceptor.dart:64-67]
  - [x] Exhaustive dartdoc: the `Sink` contract (consumer owns/closes their sink — this interceptor only `add`s, it does **not** `close` the consumer's sink), the phase mapping, `DateTime.now()` rationale, and the Logging-vs-Trace distinction ("human-readable dev logs" vs "structured export to your observability backend"). [Source: review-api §2.3 documentation note]

- [x] **Task 3 — `LoggingInterceptor`** (AC: #1, #3)
  - [x] In [packages/koel_http/lib/src/interceptors/logging_interceptor.dart](packages/koel_http/lib/src/interceptors/logging_interceptor.dart) (NEW) declare `final class LoggingInterceptor implements Interceptor` with the ctor `LoggingInterceptor({Level level = Level.INFO})` (`Level` from `package:logging` — **`Level.INFO` uppercase**, the A.2 `Level.info` is a typo, AC1 clarification). Hold a private `Logger` (e.g. `Logger('koel_http.logging')`) and the `level` threshold. [Source: addendum.md:312; package:logging/src/level.dart:45]
  - [x] Implement the **threshold-over-fixed-levels** model (trap #2): a private `_emit(Level categoryLevel, String message)` that calls `_log.log(categoryLevel, message)` **only when** `categoryLevel >= _level`. Lifecycle category → fixed level per the Dev Notes "Log-level mapping" table (request-start/response-start/completion = INFO; per-event = FINE; cancellation drop = FINE; terminal error = SEVERE for `ProtocolError` else WARNING). [Source: architecture.md:587-592; trap #2]
  - [x] Observe the full lifecycle via a `StreamController` wrapper mirroring [`abortOnCancel`](packages/koel_http/lib/src/connection/cancellation.dart#L50-L95) (trap #4): log request-start synchronously / on first listen; on first event log response-start (INFO) then per-event (FINE) for it and every subsequent event; classify a `RunErrorEvent` / stream error to the error level; on `onDone` log completion (INFO); on `onCancel` log the cancellation drop (FINE, **per-run** — trap #3) and forward `cancel()` to the upstream subscription (preserve NFR-8 — logging is transparent to teardown). [Source: cancellation.dart:50-95; AC :152,164]
  - [x] The terminal-error level uses a `switch` over the `KoelError` subtypes (`ProtocolError` → SEVERE, default → WARNING). **This switch MUST have a `default`** — the `koel_lints` `exhaustive_switch_must_have_default` rule ([rules/](packages/koel_lints/lib/src/rules/exhaustive_switch_must_have_default.dart)) is an ERROR-severity lint. [Source: koel_lints; architecture.md:525-535]
  - [x] **No `print`** anywhere (AC1). Do **not** log full secret-bearing content at INFO — log event *types* / ids at INFO lifecycle; full per-event detail is `FINE` (dev opt-in). PII redaction (4.7) composes **before** this interceptor for consumers who need it. Never log `input.forwardedProps` (it may carry the reserved auth-headers key from 4.5). [Source: architecture.md:587; 4-5 trap #2]
  - [x] Exhaustive dartdoc: the threshold model + the level table, the cancellation-drop-per-run semantics (and that it is NOT the 4.3 process-once WARNING), and the "no secrets" note. [Source: traps #2/#3]

- [x] **Task 4 — Barrel exports** (AC: #1, #2)
  - [x] In [koel_http.dart](packages/koel_http/lib/koel_http.dart) (MODIFY) add (grouped with the existing interceptor exports, alphabetical): `export 'src/interceptors/event_trace_interceptor.dart';`, `export 'src/interceptors/logging_interceptor.dart';`, `export 'src/interceptors/trace_entry.dart';`. `LoggingInterceptor`, `EventTraceInterceptor`, `TraceEntry`, `TracePhase` are all public API (A.2). [Source: koel_http.dart:1-8; addendum.md:312-313]

- [x] **Task 5 — Tests** (AC: #1, #2, #3)
  - [x] New `packages/koel_http/test/logging_interceptor_test.dart` (`package:test`; reuse the [http_agent_test.dart](packages/koel_http/test/http_agent_test.dart) + [cancellation_test.dart](packages/koel_http/test/cancellation_test.dart) helper style — ephemeral loopback `HttpServer`, `addTearDown`, `koel_test` `FixtureLoader` for fixture bodies):
    - [x] **AC1 surface:** `LoggingInterceptor()` is an `Interceptor`; default `level == Level.info`.
    - [x] **AC1 lifecycle (level: fine):** capture `Logger.root.onRecord` (set `Logger.root.level = Level.ALL`; `addTearDown` to restore); run a fixture session through `LoggingInterceptor(level: Level.fine)`; assert records for request-start (INFO), response-start (INFO), ≥1 per-event (FINE), completion (INFO), and **no `print`** (grep gate, Task 6).
    - [x] **AC1 threshold (level: info):** same run at default `Level.info`; assert FINE per-event records are **absent**, INFO lifecycle records **present**.
    - [x] **AC1 error level:** drive a terminal `RunErrorEvent(ProtocolError)` (via a `_StubAgent` — mirror [retry_interceptor_test.dart:65-79](packages/koel_http/test/retry_interceptor_test.dart#L65-L79)) and assert a SEVERE record; a `TransportError` terminal → WARNING record.
    - [x] **AC3 per-event FINE + cancellation drop:** slow loopback SSE stream; `LoggingInterceptor(level: Level.fine)`; assert ≥1 FINE per-event; cancel mid-stream; assert **one** FINE cancellation-drop record for the run. [Source: AC :161-164; cancellation_test.dart]
  - [x] New `packages/koel_http/test/event_trace_interceptor_test.dart`:
    - [x] **AC2 surface + freezed:** `EventTraceInterceptor(sink: …)` is an `Interceptor`; `TraceEntry` has value equality + `copyWith` (freezed): two equal-field entries are `==`; `copyWith(phase: …)` works.
    - [x] **AC2 every event → entry:** a `List<TraceEntry>`-backed collector `Sink`; replay a `text_only_run` fixture; assert exactly one `phase: event` entry per emitted `AgUiEvent` (count + order), one leading `phase: request` (event null), one trailing `phase: response` (event null); `runDuration` is monotonically non-decreasing.
    - [x] **AC2 error phase:** a stub stream yielding a `RunErrorEvent` → that event surfaces as a single `phase: error` entry (not `event`).
  - [x] `dart:io` in **test** files is fine (web-safety governs `lib/` only — 4.1–4.5 precedent). Keep delays tiny. Re-run both suites under `--test-randomize-ordering-seed=random`. [Source: 4-5 Task 5]

- [x] **Task 6 — Quality gates (NO finalization gates this story)** (AC: all)
  - [x] `melos run build_runner` → `trace_entry.freezed.dart` regenerates clean (codegen-drift gate); commit it. [Source: pubspec.yaml:39-42]
  - [x] `melos run analyze` → **0 issues** workspace-wide. Watch the `exhaustive_switch_must_have_default` rule on the error-level switch (Task 3). [Source: NFR-13]
  - [x] `! grep -rn 'print(' packages/koel_http/lib` → no matches (AC1 "no `print`"). [Source: AC :153; architecture.md:587]
  - [x] `melos run test` → green workspace-wide, including the two new suites and the unchanged `http_agent_test`/`retry_interceptor_test`/`auth_interceptor_test`/`cancellation_test`/`sse_parser_test`. [Source: tool/test]
  - [x] `melos run format:check` → clean (generated files excluded per tool/format.sh). [Source: tool/format]
  - [x] **`dart_apitool` API-diff is NOT a concern:** no `koel_core` change; `LoggingInterceptor`/`EventTraceInterceptor`/`TraceEntry`/`TracePhase` are additive `koel_http` symbols (no published baseline yet). [Source: 4-5 Task 6; api-diff.yml]
  - [x] **Do NOT** add koel_http's member `analysis_options.yaml` doc gate or the ≥90% coverage gate — those are **package-finalization** gates that land in epic-sealing **Story 4.10** (4.1–4.5 precedent). Write full dartdoc anyway so 4.10's doc gate needs no backfill. [Source: epic-4 overview; 4-5 Task 6]

### Review Findings

> Code review 2026-06-01 (Blind Hunter + Edge Case Hunter + Acceptance Auditor). Acceptance Auditor: **all 3 ACs, 7 traps, 10 decisions PASS**. 8 findings dismissed as noise/false-positive/spec-resolved. 3 patch findings below.

- [x] [Review][Patch] `EventTraceInterceptor.onError` không set `errored = true` — đường safety-net `error → onDone` phát thừa một `TraceEntry(phase: response)` sau lỗi (lệch với `LoggingInterceptor` vốn set `errored` trong `onError`). Fix 1-dòng để nhất quán. [packages/koel_http/lib/src/interceptors/event_trace_interceptor.dart] (LOW)
- [x] [Review][Patch] `EventTraceInterceptor` không phòng vệ khi consumer `Sink.add` ném — sink lỗi (đầy/đóng/hỏng) làm rớt event downstream hoặc phá vỡ setup run; trace là side-channel, phải trong suốt với run (đúng dartdoc "side channel" + nguyên tắc CLAUDE.md "design for what users can't misuse"). Bọc `_sink.add` best-effort. [packages/koel_http/lib/src/interceptors/event_trace_interceptor.dart] (MEDIUM)
- [x] [Review][Patch] Thông điệp per-event FINE dựng eager trên hot path — `_emit(Level.FINE, 'event: ${event.runtimeType}')` build chuỗi + `runtimeType` cho **mọi** event kể cả khi dưới ngưỡng (default `Level.INFO` → bị bỏ). Trên SSE stream lưu lượng cao là chi phí lặp lại không cần (nguyên tắc "budget-phone runtime"). Lazy message hoặc gate trước khi dựng chuỗi. [packages/koel_http/lib/src/interceptors/logging_interceptor.dart] (LOW)

## Dev Notes

### What this story is, in one paragraph

The two **observability** interceptors of the base SDK. `LoggingInterceptor` writes human-readable run logs to `package:logging` at architecture-§4 levels, gated by a single `level` threshold — so a consumer sets `Level.fine` to see per-event tracing in dev and `Level.info` (default) for quiet lifecycle-only logs in prod. `EventTraceInterceptor` is its structured complement: it writes a `TraceEntry` to a consumer-supplied `Sink<TraceEntry>` for every event flowing through the chain (plus request/response/error lifecycle markers), feeding an observability backend or DevTools (Epic 8). The new freezed `TraceEntry` (`timestamp`, `event`, `phase`, `runDuration`) is koel_http's **first codegen**. Both interceptors are pure, `final class`, framework-free, and compose into the chain like 4.4/4.5 — neither is auto-wired into `HttpAgent`. Scope is **the two interceptors + `TraceEntry`/`TracePhase` only**: no Sentry/PII (4.7), no default-chain wiring (trap #7), no finalization gates (4.10).

### Log-level mapping (RESOLVED — architecture §4 is the authority; trap #2)

`LoggingInterceptor.level` is the **emission threshold**; each category logs at its **fixed** level. `_emit(categoryLevel, msg)` calls `_log.log(categoryLevel, msg)` iff `categoryLevel >= _level`.

| Lifecycle category | Fixed level (§4) | Shown at default `Level.info`? |
| --- | --- | --- |
| request start | `Level.INFO` | yes |
| response start (first event) | `Level.INFO` | yes |
| completion (graceful `onDone`) | `Level.INFO` | yes |
| per-event tail (each `AgUiEvent`) | `Level.FINE` | **no** (shown at `Level.fine`) |
| cancellation drop (`onCancel`) | `Level.FINE` | **no** (shown at `Level.fine`) |
| terminal error — `ProtocolError` | `Level.SEVERE` | yes |
| terminal error — other `KoelError` | `Level.WARNING` | yes |

[Source: architecture.md:587-592 — `FINE`: per-event tracing + cancellation drops; `INFO`: connection lifecycle; `WARNING`: single debug warnings/retry exhaustion; `SEVERE`: unrecoverable protocol violations.]

### Cancellation drop: per-run FINE, NOT the 4.3 process-once WARNING (RESOLVED — trap #3)

Two distinct cancellation logs exist; the AC line 164 conflates them:

| Log | Level | Cadence | Owner | This story? |
| --- | --- | --- | --- | --- |
| Cancellation drop trace | `FINE` | **per cancelled run** | `LoggingInterceptor` (4.6) | **build it** |
| Abort-not-honored warning | `WARNING` | **once per process** | `cancellation.dart` (4.3) | **do not touch** |

[cancellation.dart](packages/koel_http/lib/src/connection/cancellation.dart) already says: *"The normal per-event cancellation trace is `Level.FINE` and belongs to the `LoggingInterceptor` (Story 4.6), not here."* Do not add a process-once gate to the LoggingInterceptor; do not modify `cancellation.dart`. [Source: cancellation.dart:13-18,96-115; architecture.md:588]

### Observing cancellation needs a controller wrapper (RESOLVED — trap #4)

The `Interceptor` dartdoc's `.map` example observes events but **not** `cancel()`. To log request-start / response-start / per-event / completion / error / **cancellation**, wrap `chain.proceed(input)` in a `StreamController` mirroring [`abortOnCancel`](packages/koel_http/lib/src/connection/cancellation.dart#L50-L95):

```
intercept(chain, input):
  _emit(INFO, 'run started …')                 // request start
  final controller = StreamController<AgUiEvent>(sync: true)
  StreamSubscription? sub
  controller.onListen = () {
    sub = chain.proceed(input).listen(
      (event) { firstEvent? _emit(INFO,'response start'); _emit(FINE,'event …'); if (event is RunErrorEvent) _emit(<sev>,'…'); controller.add(event); },
      onError: (e,s) { _emit(<sev>, '…'); controller.addError(e,s); },
      onDone:  () { _emit(INFO,'completed'); controller.close(); },
    )
  }
  controller..onPause = sub.pause ..onResume = sub.resume
  controller.onCancel = () { _emit(FINE,'cancelled — dropping connection'); return sub?.cancel(); }  // forward cancel → NFR-8 preserved
  return controller.stream
```

Forwarding `cancel()` to `sub` keeps the 4.3 sub-50ms abort invariant intact — logging must be transparent to teardown. [Source: cancellation.dart:50-95; interceptor.dart:64-67]

### Phase mapping for `EventTraceInterceptor` (RESOLVED — defensible reading of an underspecified AC)

AC2 mandates the enum has `request/event/response/error` and that **every `AgUiEvent` produces one `TraceEntry`**. The interceptor sees only the event stream + `input` (no HTTP-level request/response), so phases map to **run lifecycle position**:

- `request` — one entry at run start (on first listen), `event: null`, `runDuration: Duration.zero`.
- `event` — one entry per emitted non-error `AgUiEvent` (the bulk; the load-bearing AC2 assertion).
- `error` — one entry for a `RunErrorEvent` (carrying it) — emitted **instead of** `event`, so every event still yields exactly one entry.
- `response` — one entry on graceful completion (`onDone`), `event: null`.

This exercises all four enum values across happy-path (request + N×event + response) and failure (request + …event… + error) runs. [Source: AC :158-159]

### Why freezed for `TraceEntry`, and where it lives (RESOLVED — trap #1)

| Approach | AC2 "freezed type"? | Boilerplate | Toolchain cost | Verdict |
| --- | --- | --- | --- | --- |
| **freezed in `koel_http` (CHOSEN)** | ✓ | none (generated `==`/`hashCode`/`copyWith`/`toString`) | adds build_runner+freezed (workspace pins already proven) | matches AC + every koel value type; codegen already in CI |
| Hand-rolled immutable class | ✗ (violates AC literal) | ~40 LOC of `==`/`hashCode`/`copyWith` | none | rejected — contradicts AC2 *and* adds more lines than freezed |
| `TraceEntry` in `koel_core` | ✓ | none | trips `dart_apitool` (frozen kernel) | rejected — it's an HTTP/observability type, not protocol |

`TraceEntry` is freezed-**without**-json (no wire serialization — written to an in-process `Sink`), the [`RunAgentInput`](packages/koel_core/lib/src/input/run_agent_input.dart) precedent. It lives in `koel_http/lib/src/interceptors/trace_entry.dart` beside its interceptor (the architecture file tree keeps interceptors flat; no `observability/` dir exists). koel_http gains the freezed toolchain (first time) at the **exact SCP-2026-05-29-B pins**. [Source: trap #1; SCP-2026-05-29-B; addendum.md:313]

### `EventTraceInterceptor` name (RESOLVED — trap #5)

The canonical [Addendum A.2 line 313](_bmad-output/planning-artifacts/prds/prd-koel-2026-05-27/addendum.md#L313) and the epic both name the class `EventTraceInterceptor` (file `event_trace_interceptor.dart`). A LOW-severity API review *proposed* `TraceSinkInterceptor` ([review-api §2.3](_bmad-output/planning-artifacts/prds/prd-koel-2026-05-27/review-api-and-completeness.md)); it was never adopted into A.2. Implement `EventTraceInterceptor`. Carry the review's **documentation** suggestion forward (dartdoc the Logging-vs-Trace distinction), not the rename. [Source: addendum.md:313; review-api §2.3]

### Out of scope — do NOT build these (RESOLVED)

- **Auto-wiring into `HttpAgent`'s default chain** → trap #7. `HttpAgent.run` prepends only `RetryInterceptor`; `EventTraceInterceptor` can't be auto-built (needs a `Sink`). Consumers add these to `interceptors:`. [Source: http_agent.dart:105-129]
- **`SentryBreadcrumbInterceptor` / `PIIRedactionInterceptor`** → **Story 4.7** (both default-OFF). No Sentry, no redaction here. [Source: epic-4 :166-190]
- **Chunk synthesis** → 4.8; **`onConnect`/`onDisconnect`** → 4.9; **web transport** → 4.10. [Source: epic-4 :192-271]
- **Any `koel_core` change** → none. `TraceEntry`/interceptors are additive `koel_http` symbols. [Source: trap #1]
- **Member `analysis_options.yaml` doc gate + ≥90% coverage gate** → **Story 4.10** (epic-sealing). [Source: 4-1…4-5 precedent]
- **Logging/tracing of auth headers or tokens** → never. Interceptors see events + `input`, not request headers; never log `input.forwardedProps` (carries 4.5's reserved auth-headers key). [Source: 4-5 trap #2; architecture §5]

### Files you will touch

| Path | Action | Note |
| --- | --- | --- |
| [packages/koel_http/pubspec.yaml](packages/koel_http/pubspec.yaml) | MODIFY | add `freezed_annotation: ^3.1.0` (dep) + `build_runner: ^2.4.0` / `freezed: 3.2.6-dev.1` (dev) — SCP-2026-05-29-B pins; **no** json_serializable. First codegen in koel_http. |
| [packages/koel_http/lib/src/interceptors/trace_entry.dart](packages/koel_http/lib/src/interceptors/trace_entry.dart) | NEW | `enum TracePhase {request,event,response,error}` + `@freezed abstract class TraceEntry` (`timestamp`, `phase`, `runDuration`, nullable `event`); `part 'trace_entry.freezed.dart'`. |
| `packages/koel_http/lib/src/interceptors/trace_entry.freezed.dart` | NEW (generated) | `dart run build_runner build`; committed. |
| [packages/koel_http/lib/src/interceptors/event_trace_interceptor.dart](packages/koel_http/lib/src/interceptors/event_trace_interceptor.dart) | NEW | `final class EventTraceInterceptor implements Interceptor`; A.2 ctor `{required Sink<TraceEntry> sink}`; per-event + request/response/error entries. |
| [packages/koel_http/lib/src/interceptors/logging_interceptor.dart](packages/koel_http/lib/src/interceptors/logging_interceptor.dart) | NEW | `final class LoggingInterceptor implements Interceptor`; A.2 ctor `{Level level = Level.info}`; threshold-over-§4-levels; controller wrapper for cancel observation. |
| [packages/koel_http/lib/koel_http.dart](packages/koel_http/lib/koel_http.dart) | MODIFY | export the three new files (interceptors + trace_entry). |
| `packages/koel_http/test/logging_interceptor_test.dart` | NEW | AC1 surface/lifecycle/threshold/error-level + AC3 per-event FINE + cancellation drop. |
| `packages/koel_http/test/event_trace_interceptor_test.dart` | NEW | AC2 surface/freezed + every-event-→-entry + error phase. |

### Library / framework requirements

- **Runtime:** `package:koel_core` (barrel) — `Interceptor`, `InterceptorChain`, `AgUiEvent`, `RunErrorEvent`, `RunAgentInput`, `KoelError` + subtypes (`ProtocolError`, `TransportError`, …); `package:logging ^1.3.0` (already a dep, 4.3 — `Logger`, `Level`); `package:freezed_annotation ^3.1.0` (**new** — `@freezed`); SDK `dart:async` (`StreamController`, `StreamSubscription`), `dart:core` (`DateTime`, `Duration`, `Sink`).
- **Dev:** `package:build_runner ^2.4.0` + `package:freezed 3.2.6-dev.1` (**new** codegen toolchain — SCP pins); `package:test ^1.25.0`; `dart:io` (test-only loopback `HttpServer`); `koel_test` (workspace, `FixtureLoader` for fixture bodies); `koel_lints` (workspace). No `fake_async`.
- **Forbidden in `lib/`:** `dart:io`/`dart:html`/`package:web` (both interceptors are platform-neutral — they transform the event stream, no platform library); Flutter; `json_serializable`/`json_annotation` (TraceEntry isn't wire-serialized); any third-party logging/telemetry SDK (Sentry is 4.7). **No `print`** (AC1). Error messages / logs carry **no secrets** (no token, no raw `forwardedProps`). [Source: architecture.md:587; CLAUDE.md]

### Project Structure Notes

- All changes stay within `koel_http`; **no koel_core change**. SDK constraint stays `">=3.11.0 <4.0.0"`; no member `analysis_options.yaml` (gates are 4.10's).
- `koel_http` becomes a **codegen package** for the first time — the workspace `melos run build_runner` codegen-drift gate ([pubspec.yaml:39-42](pubspec.yaml)) now covers it; CI already runs it. `tool/format.sh` already excludes generated files.
- `logging_interceptor.dart` / `event_trace_interceptor.dart` are the **third and fourth** interceptors in `lib/src/interceptors/` after `retry_interceptor.dart` (4.4) and `auth_interceptor.dart` (4.5); `trace_entry.dart` co-locates there ([architecture.md:836-842](_bmad-output/planning-artifacts/architecture.md)).
- Barrel discipline: all four new public symbols exported. New tests sit flat in `test/` beside the existing suites.

### Previous Story Intelligence

- **Story 4.3** built [`abortOnCancel`](packages/koel_http/lib/src/connection/cancellation.dart) — the `StreamController` wrapper shape this story mirrors for cancel observation (trap #4) — and the process-once abort-not-honored `WARNING` that this story must **not** duplicate (trap #3). Its dartdoc explicitly defers the FINE per-event cancellation trace to "Story 4.6". [Source: cancellation.dart:13-18,50-115]
- **Story 4.4** established `final class … implements Interceptor` + the `_StubAgent` test fixture for injecting typed terminal events without a server ([retry_interceptor_test.dart:65-79](packages/koel_http/test/retry_interceptor_test.dart#L65-L79)) — reuse it for the AC1 error-level test and the AC2 error-phase test. [Source: 4-4; retry_interceptor.dart:41]
- **Story 4.5** kept koel_http codegen-free and `koel_core` untouched (no API-diff trip); this story breaks the codegen-free streak **deliberately** (AC2's freezed `TraceEntry`) but keeps `koel_core` untouched. It also established the secret-free discipline (no token in messages) — extend it to logs (no header/`forwardedProps` logging). [Source: 4-5 Dev Notes; trap #1]
- **Story 2.9** built `InterceptorChain` whose `proceed` converts stream errors to a terminal `RunErrorEvent` and treats cancellation as transparent — the mechanism both interceptors observe (a `RunErrorEvent` value is what you classify for the error phase/level). [Source: interceptor.dart:102-127]
- **House style** (3.x, 4.1–4.5): `final`/`sealed` where possible, `const` ctors, exhaustive dartdoc, table-driven `package:test`, tight change sets, composition over config, pure transforms over hidden state, no finalization gates until the epic-sealing story. [Source: `git log`; 4-5 :195]

### Latest Tech Information

- **freezed `3.2.6-dev.1` at analyzer 12 (SCP-2026-05-29-B):** the workspace is pinned to analyzer 12 so `freezed` and `analysis_server_plugin` (koel_lints) coexist in one pub-workspace resolution. Use the **exact** pins; the dev pre-release is a documented stopgap with a clear exit (stable freezed supporting analyzer ≥13). Codegen command is `dart run build_runner build` — **drop** `--delete-conflicting-outputs` (removed/no-op in the resolved build_runner). [Source: SCP-2026-05-29-B §2,§3,§4]
- **`package:logging` levels:** `Level.FINE` (500) < `Level.INFO` (800) < `Level.WARNING` (900) < `Level.SEVERE` (1000). `Logger.log(level, msg)` emits a `LogRecord`; the root logger filters by `Logger.root.level`. The interceptor's own `level` is an **independent** application-side threshold (trap #2) — gate before calling `_log.log`. Tests capture via `Logger.root.onRecord` after setting `Logger.root.level = Level.ALL`. [Source: package:logging 1.3.0]
- **`Sink<T>` vs `StreamSink<T>`:** A.2 uses the synchronous `dart:core` `Sink<T>` (`add(T)` / `close()`) — not `StreamSink`. The interceptor only `add`s; the **consumer owns and closes** their sink (document this — don't `close` it on run completion, the sink may outlive one run). [Source: addendum.md:313; dart:core]
- **`DateTime.now()` in interceptors:** the `Interceptor` contract dartdoc itself uses `DateTime.now()` ([interceptor.dart:31-37](packages/koel_core/lib/src/agent/interceptor.dart)); it is idiomatic for a timing/trace interceptor. (The `Date.now()` ban is the Workflow JS sandbox, not Dart.) Tests assert phase/count/ordering and `runDuration` monotonicity, not exact wall-clock values. [Source: interceptor.dart:29-40]
- **No `dart_apitool` exposure:** `koel_core` is unchanged; the four new symbols are additive to `koel_http` (no published baseline). Adding `freezed_annotation` as a dependency has no API-surface effect. [Source: api-diff.yml; 4-5]

### References

- Story spec (ACs, A.2 signatures, `TraceEntry` shape): [epic-4 Story 4.6](_bmad-output/planning-artifacts/epics/epic-4-http-transport-koelhttp.md) (lines 141-164); canonical ctors `LoggingInterceptor({Level level = Level.info})` + `EventTraceInterceptor({required Sink<TraceEntry> sink})`: [addendum.md §A.2](_bmad-output/planning-artifacts/prds/prd-koel-2026-05-27/addendum.md#L312-L313).
- Log-level authority: architecture §4 ([architecture.md:587-592](_bmad-output/planning-artifacts/architecture.md)); no-`print` rule (architecture.md:587); exhaustive-switch lint precedent ([architecture.md:525-535](_bmad-output/planning-artifacts/architecture.md)); interceptor file tree ([architecture.md:836-842](_bmad-output/planning-artifacts/architecture.md)).
- Interceptor contract + chain error/cancel policy: [interceptor.dart:1-137](packages/koel_core/lib/src/agent/interceptor.dart).
- Cancel-observation shape + the process-once WARNING NOT to touch: [cancellation.dart](packages/koel_http/lib/src/connection/cancellation.dart).
- freezed pattern to replicate: [run_agent_input.dart:1-44](packages/koel_core/lib/src/input/run_agent_input.dart) + [koel_core/pubspec.yaml:8-21](packages/koel_core/pubspec.yaml) (pins); the toolchain decision: [SCP-2026-05-29-B](_bmad-output/planning-artifacts/sprint-change-proposal-2026-05-29-analyzer12-freezed.md).
- Default-chain (only retry auto-wired): [http_agent.dart:105-129](packages/koel_http/lib/src/http_agent.dart).
- Test exemplars (loopback SSE server, helpers, `_StubAgent`, slow-server cancel): [http_agent_test.dart](packages/koel_http/test/http_agent_test.dart), [retry_interceptor_test.dart](packages/koel_http/test/retry_interceptor_test.dart), [cancellation_test.dart](packages/koel_http/test/cancellation_test.dart).
- `EventTraceInterceptor` vs `TraceSinkInterceptor` (rename proposed, not adopted): [review-api-and-completeness.md §2.3](_bmad-output/planning-artifacts/prds/prd-koel-2026-05-27/review-api-and-completeness.md).

### Design decisions (RESOLVED — AC/architecture-forced, not open)

1. **`TraceEntry` is freezed-without-json in `koel_http`** — AC2-mandated; koel_http's first codegen at the SCP-2026-05-29-B pins; lives beside its interceptor. [trap #1]
2. **`LoggingInterceptor.level` is an emission threshold over fixed §4 per-category levels** — not a uniform level. [trap #2; architecture.md:587-592]
3. **Cancellation drop logs at `FINE` per cancelled run** — NOT process-once; the 4.3 abort-not-honored `WARNING` is separate and untouched. [trap #3]
4. **Cancellation is observed via a `StreamController` wrapper (abortOnCancel shape), forwarding cancel upstream** — preserves NFR-8. [trap #4]
5. **Class is `EventTraceInterceptor` (A.2), not `TraceSinkInterceptor`** — the rename was proposed (LOW) and not adopted. [trap #5]
6. **Both interceptors are `final class`** — no Epic-5 subclass. [trap #6]
7. **Neither interceptor is auto-wired into `HttpAgent`'s default chain** — no AC requires it; EventTrace needs a consumer sink. [trap #7]
8. **`EventTraceInterceptor` does not `close` the consumer's `Sink`** — the consumer owns it. [Sink contract]
9. **Error level: `ProtocolError` → SEVERE, other `KoelError` → WARNING**, via a `default`-bearing switch (koel_lints). [architecture.md:587-592; exhaustive_switch rule]
10. **No `print`, no secrets in logs, no `koel_core` change, no finalization gates (4.10)**. [AC1; architecture §5; 4-5 precedent]

These are baked in — implement them; no confirmation gate.

## Dev Agent Record

### Context Reference

<!-- Path(s) to story context will be added here by context workflow -->

### Agent Model Used

claude-opus-4-8[1m] (Opus 4.8, 1M context) — via `/agent-flutter-engineer` (implement mode).

### Debug Log References

- `dart pub get` — resolved clean at analyzer 12 (the SCP-2026-05-29-B workspace pins held; freezed `3.2.6-dev.1` + analysis_server_plugin coexist).
- `dart run build_runner build` (koel_http) — generated `trace_entry.freezed.dart` (first codegen in koel_http).
- `melos exec --depends-on=build_runner -- "dart run build_runner build"` — clean across all 3 codegen packages, `wrote 0 outputs` (no drift; koel_http now in the sweep).
- `melos exec -- "dart analyze ."` — **0 issues** workspace-wide.
- `! grep -rn 'print(' packages/koel_http/lib` — no matches (AC1 no-`print` gate).
- `bash tool/format.sh check` — clean (after one `format.sh write` pass; generated files excluded).
- Full workspace test sweep (`tool/test_package.sh`) — green: koel_http **68** (incl. the two new suites, 8 new tests, run under `--test-randomize-ordering-seed=random`), koel_core 575, koel_lints 5, koel_test, others — all pass.

### Completion Notes List

- **All 3 ACs satisfied.** AC1 — `LoggingInterceptor({Level level = Level.INFO})`, every lifecycle category logs at its fixed §4 level gated by the `level` threshold, no `print`. AC2 — `EventTraceInterceptor({required Sink<TraceEntry> sink})`, freezed `TraceEntry(timestamp, phase, runDuration, event?)` + `enum TracePhase {request, event, response, error}`, one entry per `AgUiEvent` bracketed by request/response markers. AC3 — per-event tracing at `Level.FINE`, cancellation drop at `Level.FINE` once per cancelled run.
- **All 7 traps honored:** (1) freezed-without-json `TraceEntry`, koel_http's first codegen at the SCP pins; (2) `level` is a threshold over fixed per-category §4 levels, not uniform; (3) cancellation drop is per-run FINE — `cancellation.dart`'s process-once WARNING untouched; (4) both interceptors use the `abortOnCancel`-shaped `StreamController` wrapper, forwarding `cancel()` upstream (NFR-8 preserved); (5) class is `EventTraceInterceptor` (A.2), not `TraceSinkInterceptor`; (6) both `final class … implements Interceptor`; (7) neither auto-wired into `HttpAgent`'s chain.
- **Resolved AC1 spec typo:** used `Level.INFO` (uppercase) — `package:logging` exposes no `Level.info`; the addendum/epic `Level.info` would not compile.
- **Design refinement (defensible reading):** on the error path, the trailing `onDone` is suppressed — a run that emits a terminal `RunErrorEvent` produces `request + …event… + error` (LoggingInterceptor: no "completed" INFO; EventTraceInterceptor: no `response` marker), matching the Dev Notes phase-mapping. A graceful run produces `request + N×event + response`/`…completed`.
- **`level` kept private** (no public getter): A.2 specifies one named param only, mirroring the dev-notes "hold a private `Logger` + the `level` threshold." Default-level behavior is proven by the AC1 threshold test, not a field read.
- **Generated `trace_entry.freezed.dart` is NOT committed** — `*.freezed.dart`/`*.g.dart` are gitignored repo-wide ([.gitignore:6-7](.gitignore)); koel_core/koel_test generated files aren't tracked either. The project convention is regeneration via the `melos run build` codegen-drift gate in CI (already runs; now covers koel_http). This supersedes the story's "commit the generated file" line, which predates checking the repo policy.
- **No finalization gates added** (per-member `analysis_options.yaml` doc gate, ≥90% coverage) — those land in epic-sealing Story 4.10. Full dartdoc written on all four new public symbols so 4.10's doc gate needs no backfill.
- **No `koel_core` change; no `dart_apitool` exposure** — the four new symbols are additive `koel_http` API.

### File List

- `packages/koel_http/pubspec.yaml` (MODIFY) — added `freezed_annotation: ^3.1.0` (dep), `build_runner: ^2.4.0` + `freezed: 3.2.6-dev.1` (dev); koel_http's first codegen toolchain (SCP-2026-05-29-B pins).
- `packages/koel_http/lib/src/interceptors/trace_entry.dart` (NEW) — `enum TracePhase` + freezed `TraceEntry`.
- `packages/koel_http/lib/src/interceptors/trace_entry.freezed.dart` (NEW, generated; gitignored — regenerated by CI).
- `packages/koel_http/lib/src/interceptors/event_trace_interceptor.dart` (NEW) — `final class EventTraceInterceptor`.
- `packages/koel_http/lib/src/interceptors/logging_interceptor.dart` (NEW) — `final class LoggingInterceptor`.
- `packages/koel_http/lib/koel_http.dart` (MODIFY) — barrel-exported the three new files (4 public symbols).
- `packages/koel_http/test/logging_interceptor_test.dart` (NEW) — AC1 surface/lifecycle/threshold/error-level + AC3 per-event FINE + cancellation drop.
- `packages/koel_http/test/event_trace_interceptor_test.dart` (NEW) — AC2 surface/freezed + every-event-→-entry + error phase.

## Change Log

| Date | Change |
| --- | --- |
| 2026-06-01 | Story 4.6 implemented — `LoggingInterceptor` + `EventTraceInterceptor` + freezed `TraceEntry`/`TracePhase`; koel_http's first codegen. All 3 ACs satisfied; workspace analyze/format/test green. Status → review. |
