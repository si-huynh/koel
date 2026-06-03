---
baseline_commit: f533232b90bc3021c254b3bad6c839ccf8d3c5fc
---

# Story 5.3: `koel_agno` — Captured fixtures + ConformanceRunner green

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->
<!-- 2026-06-03 (dev-story): COMPLETE — all tasks/subtasks done. Si ran the live
     agno capture; the real `synthesized: false` fixture landed, the round-trip
     test asserts (no skip), all gates green. Status → review. -->


## Story

As an OSS contributor,
I want real captured fixtures from a running agno backend covering what agno actually emits, plus `ConformanceRunner` running green against `AgnoAgent`, plus the agno-group package finalization (coverage gate, analyzer config, conformance CI lane),
so that the conformance contract is verified end-to-end per FR-G1 (real captured) + FR-G4 (complete green) and the agno bridge is shippable.

## Acceptance Criteria

> **This is the agno-group SEALER story.** It folds in three categories of work beyond the epic's stated 5.3 criteria, each by prior-story decision, not invention:
> 1. **Finalization deferrals** that 5.1 + 5.2 explicitly routed here — the `tool/coverage.sh packages/koel_agno 80 80` gate entry, `analysis_options.yaml`, `coverage_options.yaml`, and the README default-ON auth sentence (5.2 AC4). 5.1/5.2 Dev Notes both name "Story 5.3, the agno-group sealer" as the owner.
> 2. **The 3.3 + 3.5 deferral cluster** (corrupt-line → fixture-naming `FormatException` guard) — the prep-plan (`epic-5-prep-plan.md` step 3) mandates "Fold the corrupt-line → fixture-naming `FormatException` guard here … trigger now active" because live captures can finally produce partial/truncated lines.
> 3. **A source-verified deviation from the epic's literal AC1** — the epic asks for six scenarios captured with `synthesized: false`. The reference-backend CONTRACT (`../koel_backend/backends/agno/CONTRACT.md`, source-read + docker-probed) proves agno + the shared mock-LLM emits **only the text-run event chain**; tool-call / state-delta / reasoning / native-error / cancellation are **not natively emittable**. AC2 resolves this with the epic's **own dojo-fallback rule** (Story 5.9: "events the backend cannot emit fall back to synthesized fixtures with `synthesized: true`"). This is a decision baked RESOLVED with evidence — see Dev Notes "The honest fixture matrix".

**AC1 — `tool/capture_fixtures.dart --backend=agno` real body (epic-stated; AR-14, FR-G1).**
**Given** the scaffold at [tool/capture_fixtures.dart](tool/capture_fixtures.dart) that today only prints `wired in Epic 5 Story 5.3` for `--backend=agno`,
**When** an operator runs `dart run tool/capture_fixtures.dart --backend=agno [--base-url=<url>] [--token=<t>]` against a live `make up-agno` deployment (default `--base-url=http://localhost:8002`),
**Then** the tool POSTs `RunAgentInput` scenario bodies to `baseURL/agno-chat` (camelCase JSON, `Content-Type: application/json`, `Accept: text/event-stream`), reads the SSE response, and writes JSONL fixture(s) under `packages/koel_test/lib/src/fixtures/agno/` in the exact `{type, timestamp, payload}` envelope the existing synthesized fixtures use (header line first, one event per line),
**And** it stays **zero-dependency `dart:io`** (no `package:args`/`package:http`) — matching the existing scaffold's contract (a repo tool resolves only against the workspace root),
**And** the one documented nondeterministic field — `messageId` (UUID4, per `CONTRACT.md` SPIKE-MOCK, the *only* varying field) — is **normalized to a stable token** (e.g. the first distinct `messageId` → `msg-0`, next → `msg-1`) so the captured event lines are byte-stable golden artifacts on re-capture,
**And** the agno backend version is read live from `GET baseURL/status` (`{"version":"2.6.10",…}`) and stamped into the `_session` header (see AC3),
**And** when the backend is unreachable the tool exits non-zero with an actionable message naming the `make up-agno` prerequisite (no silent empty fixture).

**AC2 — captured agno fixtures land with honest `synthesized` provenance (epic-stated AC1, reconciled to backend reality; FR-G1 + the Story-5.9 dojo-fallback rule).**
**Given** the agno wire surface frozen in `CONTRACT.md` (agno + mock-LLM natively emits **only** `RUN_STARTED → TEXT_MESSAGE_START → TEXT_MESSAGE_CONTENT×N → TEXT_MESSAGE_END → RUN_FINISHED`),
**When** the capture runs,
**Then** `packages/koel_test/lib/src/fixtures/agno/text_only_run.jsonl` is a **real capture** — `_session.synthesized: false`, `_session.adapter: "koel_agno@<pubspec-version>"`, `_session.backendVersion: "agno==2.6.10"` — and `FixtureLoader.loadAgno('text_only_run')` decodes it to the canonical text-run `AgUiEvent` sequence,
**And** the scenarios agno cannot natively emit (tool-call, state-delta, reasoning + `encryptedValue`, native agent-error envelope, cancellation) are **not fabricated as `synthesized: false`** — they are covered by the all-event-types conformance corpus (AC5) and the existing `synthesized/` scenario fixtures the AgnoAgent replay tests already reuse; **any** agno-namespaced fixture authored for these instead carries `_session.synthesized: true` (honest provenance, per the Story-5.9 fallback rule),
**And** the deviation from the epic's literal "six scenarios, all `synthesized: false`" is recorded in the capture tool's dartdoc + this story's Dev Notes with the `CONTRACT.md` evidence (no silent scope reduction),
**And** the placeholder at `packages/koel_test/lib/src/fixtures/agno/.placeholder` is removed once at least one real fixture lands (or kept only if the directory would otherwise be git-empty).

**AC3 — `FixtureSession` records the backend version (koel_test additive; needed by the epic's "agno backend version recorded").**
**Given** [packages/koel_test/lib/src/fixture_loader.dart](packages/koel_test/lib/src/fixture_loader.dart) `FixtureSession` carries six provenance fields and **no slot for a backend version**,
**When** I inspect it after this story,
**Then** `FixtureSession` gains an **optional** `String? backendVersion` field, read in `fromJson` as a non-required key (absent → `null`), so the seven existing synthesized fixtures (which omit it) still parse unchanged,
**And** real agno captures populate it (`"agno==2.6.10"`) while synthesized fixtures leave it `null`,
**And** a unit test in `fixture_loader_test.dart` locks both: a header with `backendVersion` parses it; a header without it yields `null` (backward-compat regression).

**AC4 — corrupt event-line → fixture-naming `FormatException` guard (3.3 + 3.5 deferral cluster; trigger now active per prep-plan).**
**Given** the unguarded `payload` decode in `FixtureLoader._load` ([fixture_loader.dart:160-166](packages/koel_test/lib/src/fixture_loader.dart#L160-L166)) and the identical decode in `ConformanceRunner._loadExpectedCorpus` ([conformance_runner.dart:112-120](packages/koel_test/lib/src/conformance_runner.dart#L112-L120)) — both today surface an **opaque `TypeError`** with no fixture/line context when an event line is valid JSON but missing a `payload` key, has a non-object `payload`, a non-`String` `type`, or is itself not a JSON object,
**When** such a line is encountered (now reachable because live captures can produce partial/truncated lines),
**Then** both sites throw a **`FormatException` naming the fixture and the offending line** (an envelope-shape guard) instead of the bare `TypeError`,
**And** unit tests in `fixture_loader_test.dart` + `conformance_runner_test.dart` cover each corrupt shape (missing `payload`, non-object `payload`, non-`String` `type`, non-object line),
**And** the change is **additive to the failure message only** — well-formed fixtures decode exactly as before (the 7 synthesized fixtures + all existing tests stay green),
**And** the matching entries in [deferred-work.md](_bmad-output/implementation-artifacts/deferred-work.md) (story-3.3 line ~231, story-3.5 line ~237) are marked **CLOSED** with a pointer to this story.

**AC5 — `ConformanceRunner` green against `AgnoAgent` (epic-stated; FR-G4).**
**Given** a conformance test in **`packages/koel_agno/test/`** (koel_agno already has `koel_test` as a dev-dep),
**When** it runs `await const ConformanceRunner().runAgainst(AgnoAgent(baseURL: …, client: mockClient))` where `mockClient` is a `MockClient` (`package:http/testing.dart`) serving the **`all_event_types` corpus re-framed as agno SSE** (`data: <payload>\n\n`, exactly the `_sseBody`/`_fixturePayloads` helpers already in `agno_agent_test.dart`),
**Then** `report.failed` is **empty** and `report.passed` has length **28** (every AG-UI type), proving `AgnoAgent`'s **inherited** `HttpAgent` transport + SSE parse reproduces every event type — `AgnoAgent` overrides only `encodeBody`/`errorClassifier`, never the response path, so the corpus round-trips unreshaped (agno emits canonical AG-UI per `CONTRACT.md`),
**And** a second test asserts the **real** captured fixture round-trips: `AgnoAgent(client: mockClient-serving-the-agno-text_only_run-SSE).run(input)` emits exactly `await FixtureLoader.loadAgno('text_only_run')`,
**And** the conformance test file is tagged `@Tags(['conformance'])` so the CI lane (AC6) can select it.

**AC6 — conformance CI lane real (epic-stated; extends Story 1.5's `conformance.yml` skeleton).**
**Given** [.github/workflows/conformance.yml](.github/workflows/conformance.yml) is today a green-by-default `placeholder` job (`echo "Wired in Epic 5"`),
**When** I inspect it after this story,
**Then** the placeholder job is replaced by a real job that bootstraps the workspace (`melos bootstrap` → `melos run build`) and runs the agno conformance lane **offline** (`MockClient` replay — the backend is **not** needed in CI; capture is a one-time operator step),
**And** the lane is invoked through a new `melos run conformance` script (per architecture §"`melos run conformance` runs `ConformanceRunner` … using captured fixtures") that runs the `conformance`-tagged tests per adapter package and tolerates packages with none yet (mirroring `tool/test_package.sh`'s no-test tolerance) — the structured extension point Stories 5.6 (langgraph) and 5.9 (copilotkit) plug into,
**And** the workflow stays scoped to what exists now (only koel_agno has a conformance test) without breaking when the other adapters are empty.

**AC7 — koel_agno package finalization (sealer; deferred from 5.1 + 5.2).**
**Given** koel_agno today has **no** `analysis_options.yaml`, **no** `coverage_options.yaml`, **no** `test:coverage` gate entry, and a README whose auth story is unwritten,
**When** I inspect the package after this story,
**Then** `packages/koel_agno/analysis_options.yaml` exists, **mirroring koel_http/koel_test's sealer config** — `include: ../../analysis_options.yaml` (inherits root `recommended.yaml` + the koel_lints plugin), **no `plugins:`** (per Story 1.7 it is root-only — `plugins_in_inner_options`), and layers `public_member_api_docs: true` + `comment_references: true` (the member-doc gate now turns on for koel_agno's public surface),
**And** `packages/koel_agno/coverage_options.yaml` exists for consistency (the `**/*.freezed.dart`/`**/*.g.dart`/`**/*.mocks.dart` ignore list — koel_agno has no codegen today, so it is a forward-safe no-op honored by `format_coverage --check-ignore`),
**And** the root `test:coverage` melos script ([pubspec.yaml:32-38](pubspec.yaml#L32-L38)) gains the line `bash "$MELOS_ROOT_PATH/tool/coverage.sh" packages/koel_agno 80 80` (adapter tier, ≥80%, no `with_chrome` — koel_agno is VM-only/offline), and its `description` is updated to mention koel_agno,
**And** `packages/koel_agno/README.md` gains the **default-ON auth sentence** deferred from Story 5.2 AC4: that `AgnoAuthInterceptor` is default-ON as a harmless client convention because stock agno enforces zero auth (OQ-Agno-Auth resolved — open agno ignores the `Authorization` header; a deployment adds its own check to enforce it), and that `token` is therefore optional,
**And** turning on `public_member_api_docs` surfaces **no** undocumented public symbol (every exported `AgnoAgent`/`AgnoAuthInterceptor`/`AgnoErrorClassifier`/`AgnoConversionOptions`/`agnoMessageToWire` member already carries a dartdoc from 5.1/5.2 — verify, backfill only if the gate fires).

**AC8 — gates green (epic-stated; NFR-12, NFR-13).**
**Given** all of the above,
**When** I run the workspace gates,
**Then** `bash tool/coverage.sh packages/koel_agno 80 80` reports **line + branch ≥ 80%** (NFR-12; the 5.1/5.2 code already sits at 100/100 — keep it ≥80 with the new conformance/replay tests),
**And** `melos run conformance` is **green** (agno lane zero failures),
**And** `dart analyze packages/koel_agno packages/koel_test` exits **0** (NFR-13) — including the new `analysis_options.yaml` member-doc gate,
**And** `dart run melos test` (full workspace) shows **no regression** across koel_core / koel_http / koel_test / koel_agno (the AC3 + AC4 koel_test changes must not break the 3.x suites),
**And** `bash tool/format.sh check` is clean.

## Tasks / Subtasks

- [x] **Task 1 — koel_test substrate first (AC3 + AC4). DO THIS FIRST** (the capture tool + conformance tests depend on it; mirror 5.1/5.2's "open the seam before the consumer" sequencing).
  - [x] **AC3 — `FixtureSession.backendVersion`.** Added `final String? backendVersion;` + non-`required` ctor param; `fromJson` reads it optionally (`session['backendVersion'] == null ? null : require<String>('backendVersion')` — absent → null; present-but-wrong-typed → ArgumentError, consistent with the required fields). Dartdoc'd. Six required fields untouched.
  - [x] AC3 test (`fixture_loader_test.dart`): `FixtureSession.fromJson` (directly constructible) with `backendVersion` parses it; without → `null`; wrong-typed → `throwsArgumentError`.
  - [x] **AC4 — corrupt-line guard.** **Deviation from the subtask's "prefer a local guard per site":** lifted a single shared `decodeFixtureEvent` into a new internal file `packages/koel_test/lib/src/fixture_envelope.dart` instead. Rationale: a per-site duplicate is **not unit-testable** (both sites read fixed assets via `package:` URI — a corrupt line can't be staged without polluting the shipped fixtures and racing `fixtures_test`). One shared `src/` helper is DRY **and** directly testable from `test/` (same-package `src/` import, no `meta`/`@visibleForTesting` needed). `FixtureLoader._load` routes through it; well-formed path unchanged.
  - [x] **AC4 — same guard in `ConformanceRunner._loadExpectedCorpus`** routes through `decodeFixtureEvent` (corpus-naming source). Dropped the now-unused `dart:convert` import.
  - [x] AC4 tests: `fixture_loader_test.dart` (fixture-named source: non-object line / missing payload / non-object payload / non-String type + happy path) + `conformance_runner_test.dart` (corpus-named source). All via the shared helper — no fixture staging.
  - [x] Closed the two `deferred-work.md` entries (story-3.3, story-3.5) with a "**CLOSED by Story 5.3 (AC4)**" note.
  - [x] `bash tool/coverage.sh packages/koel_test 80 80` → line=95.60% (174/182), branch=92.54% (62/67) — gate stays green; 53 tests pass.

- [x] **Task 2 — `tool/capture_fixtures.dart --backend=agno` real body (AC1, AC2).** Code complete + validated; Si ran the live capture — the real fixture landed.
  - [x] Replaced the `agno` branch with a real capture path; kept the scaffold's arg-parse + the other three backends' "wired in …" stubs (langgraph 5.6, dojo/copilotkit 5.9) untouched. Zero-dep `dart:io`/`dart:convert` — `HttpClient` POST + `GET /status`, `LineSplitter` SSE framing.
  - [x] Added `--base-url` (default `http://localhost:8002`) and `--token` (optional) via a generalized `_option(args, name)` helper (`--flag=value` / `--flag value`).
  - [x] `text_only_run` capture: POST the canonical `RunAgentInput`, parse `data: <json>` SSE frames, write `{type, timestamp, payload}` lines + the `_session` header. `messageId` normalized (stable first-seen remap → `msg-0…`); version read from `GET /status` → `backendVersion: agno==2.6.10`. **Validated end-to-end against a throwaway mock agno server** (6 events, `msg-0` remap, monotonic timestamps, well-formed envelope); the mock-derived file was deleted (never committed — it is not a real capture).
  - [x] `<v>` = `0.0.1` (real koel_agno pubspec version), not the epic's `0.1.0` — noted in the tool dartdoc.
  - [x] `SocketException` (unreachable) → exit 1 with `cannot reach agno at <url> — run \`make up-agno\` in ../koel_backend first.`; non-200 / empty stream → exit 1 via `_CaptureFailure`; no partial fixture written. Smoke-tested all error/stub paths (exit 2 bad args, exit 1 unreachable, exit 0 langgraph stub).
  - [x] Dartdoc'd the AC2 deviation (agno is text-run-only per `CONTRACT.md`; other types ride the conformance corpus + Story-5.9 fallback).
  - [x] **Operator step (Si) — DONE:** Si ran `make up-agno` + `dart run tool/capture_fixtures.dart --backend=agno`. Captured `agno/text_only_run.jsonl` — a genuine live capture (deltas spell "Hello from the koel_backend deterministic mock LLM.", the real CONTRACT.md mock-LLM text; `synthesized: false`, `backendVersion: agno==2.6.10`, `messageId` → `msg-0`). The presence-guarded round-trip test now **asserts** (no skip) and passes.
  - [x] Removed `packages/koel_test/lib/src/fixtures/agno/.placeholder`; updated `koel_test/test/fixtures_test.dart` — the "each backend dir holds only `.placeholder`, no captures" invariant now iterates `pendingCaptureDirs` ({dojo, langgraph, copilotkit_runtime}), plus a new "agno graduated" test asserting the real `synthesized:false` capture + no placeholder.

- [x] **Task 3 — AgnoAgent conformance + real-capture replay tests (AC5).**
  - [x] Added `packages/koel_agno/test/conformance_test.dart` (`@Tags(['conformance'])`, `@TestOn('vm')`) + `packages/koel_agno/dart_test.yaml` declaring the `conformance` tag. **Extracted the shared helpers to `test/_support.dart`** (`fixturePayloads`/`sseBody`/`sseClient`) — two files now use them, so per the story's "shared file once two test files need them"; refactored `agno_agent_test.dart` to import it (dropped its duplicated `_fixturePayloads`/`_sseBody`, kept the request-capturing `_capturingClient`).
  - [x] Test 1 — **CORRECTED from the AC's literal "zero failures / 28" to the evidence-backed 25/28.** See Debug Log "Chunk-synthesis finding": koel_http's default-on `synthesizeChunks` ([http_agent.dart:65-75](packages/koel_http/lib/src/http_agent.dart#L65-L75), Story 4.8) normalizes the 3 `*_CHUNK` shapes into START/CONTENT/END at the transport, so `AgnoAgent` (which doesn't expose the flag — Addendum A.3) reproduces the **25 canonical types verbatim** and the 3 chunk shapes are synthesized away. The test asserts `passed` has 25 and `failed` is **exactly** `{TEXT_MESSAGE_CHUNK, TOOL_CALL_CHUNK, REASONING_MESSAGE_CHUNK}` (proves synthesized-not-dropped + no 26th-type regression). This is the prep-plan's own documented "25/28, 3 chunk-variants synthesizable koel-side"; a real agno backend never emits chunk shapes anyway (canonical `EventEncoder`, CONTRACT.md).
  - [x] Test 2 (real-capture round-trip): serves the **agno** `text_only_run` payloads as SSE, asserts `AgnoAgent(...).run(input)` equals `FixtureLoader.loadAgno('text_only_run')`. **Presence-guarded** — `markTestSkipped` with the capture command when the fixture isn't committed yet (activates the moment Si's capture lands); skips cleanly today (docker unavailable in the dev env).
  - [x] Confirmed `runAgainst` drives `agent.run` **directly**: the corpus's `RUN_ERROR` rides through verbatim (HttpAgent's "terminal RunErrorEvent" classifies only transport/parser *throws*), so every non-chunk type reaches the runner.

- [x] **Task 4 — conformance CI lane + `melos run conformance` (AC6).**
  - [x] Added a `conformance` melos script (`exec: bash tool/conformance.sh`) + `tool/conformance.sh` — runs the `conformance`-tagged tests per package, gated on the package declaring the tag in `dart_test.yaml` (keeps the lane quiet: no "No tests match" ERROR noise in adapter-less packages) and tolerating exit 79/65 like `test_package.sh`. 5.6/5.9 opt in by declaring their tag.
  - [x] Replaced `conformance.yml`'s `placeholder` job with a real `conformance` job: checkout → `setup-dart sdk: 3.12.0` → `melos 7.8.0` → `melos bootstrap` → `melos run build` (freezed `ConformanceReport`) → `melos run conformance`. Mirrors `ci.yml`; triggers + `permissions` preserved.
  - [x] Verified offline — `melos run conformance` runs only koel_agno (+1 pass, ~1 skip), SUCCESS, no backend container. Updated the `capture-fixtures` melos description (agno live + new flags).

- [x] **Task 5 — koel_agno finalization (AC7).**
  - [x] Added `packages/koel_agno/analysis_options.yaml` — koel_http sealer shape (no `plugins:`, `include: ../../analysis_options.yaml`, generated-file `exclude`, `public_member_api_docs: true` + `comment_references: true`).
  - [x] Added `packages/koel_agno/coverage_options.yaml` (standard generated-file ignore list; forward-safe — no codegen today).
  - [x] Wired `bash tool/coverage.sh packages/koel_agno 80 80` into the root `test:coverage` script + updated its description (adapter tier ≥80%).
  - [x] Added the README "Authentication" note (default-ON `AgnoAuthInterceptor`; OQ-Agno-Auth resolved → `token` optional; 401/403 mapping reference).
  - [x] `dart analyze packages/koel_agno` → **0**. The new `comment_references` gate surfaced 5 pre-existing latent doc-refs (`[AgnoAgent]` not imported + `[token]`/`[input]` not in scope, in 5.2's `agno_auth_interceptor.dart` + a test helper) → fixed (backticks / corrected param name), not suppressed. Coverage 100%/100%.

- [x] **Task 6 — gates + close-out (AC8).**
  - [x] `bash tool/coverage.sh packages/koel_agno 80 80` → 100/100. koel_test → 95.58/92.54. Full `melos run test:coverage`: core 98.85/97.87, http 94.58/92.15, test 95.58/92.54, agno 100/100 — all green.
  - [x] `melos run conformance` → green (agno +1 / ~1 skip). `melos run analyze` → 0 across all 11 packages. `melos run test` → green (one koel_http `cancellation_test` wall-clock flake on first run, passes in isolation 10/10 + on retry — documented flake, not a regression; koel_http untouched). `bash tool/format.sh check` → clean.
  - [x] Closed the 3.3 + 3.5 `deferred-work.md` entries (Task 1); recorded the 3 new 5.3 deferrals (operator-gated real capture; agno error-envelope still-deferred; the 25/28 chunk-synthesis finding for 5.6/5.9).

- [ ] **Out of scope for 5.3 — record, do not implement:** the agno **native agent-error envelope → `agentRefused`/`agentInternal`** mapping in `AgnoErrorClassifier` **unless** a real agno error envelope is actually captured (see Dev Notes "The error-envelope question" — if `make up-agno` yields no SSE `RUN_ERROR` envelope, the 5.2 deferral **stays deferred**, no speculative parser per CLAUDE.md; if a real envelope *is* captured, implementing its mapping becomes in-scope and closes the 5.2 deferral); langgraph + copilotkit fixtures/conformance (Stories 5.4–5.9); the koel_http case-sensitive header-merge fix + interceptor-disposal seam (5.2 deferrals — architectural, not triggered here); the koel_core "throwing `ErrorClassifier` escapes the invariant" hardening (Story 2.14 deferral).

### Review Findings (code review 2026-06-03)

> Three adversarial layers (Blind Hunter / Edge Case Hunter / Acceptance Auditor) ran clean against the AC surface — **all 8 ACs Met**, every documented deviation (25/28 chunk-synthesis, shared `decodeFixtureEvent`, `0.0.1` vs `0.1.0`) judged sound and evidence-backed. 12 raw observations dismissed as verified-handled / not-a-bug / pre-existing sanctioned convention. The two refactored decode loops and the 25/28 `failed`-set assertion were explicitly re-verified as correct (not gaps). Surviving items below.

- [x] [Review][Patch] **Remove the now-vestigial `markTestSkipped` guard from the round-trip test** [koel_agno/test/conformance_test.dart] — (decision resolved 2026-06-03 → remove). **FIXED:** dropped the `resolved/existsSync → markTestSkipped` branch + the now-unused `dart:io`/`dart:isolate` imports; the test asserts unconditionally. Verified: `dart test --tags conformance` → +2 (no skip), `dart analyze packages/koel_agno` → 0.

- [x] [Review][Patch] **Capture tool leaks `HttpClient` + prints a raw stack trace on any unexpected throw** [tool/capture_fixtures.dart] — `_captureAgno`'s `try` caught only `SocketException`/`_CaptureFailure`; a non-object `/status` body, a scheme-less `--base-url`, or an exotic SSE frame escaped both → leaked socket + bare stack trace. **FIXED:** moved `exit(1)` *after* a `finally { client.close(force: true) }` (since `dart:io exit()` skips `finally`), collapsed the catches into a `failure` string, and added a catch-all that turns any unexpected throw into an actionable operator line. No speculative SSE-spec parsing added (per CLAUDE.md "no just-in-case"). Verified: scheme-less `--base-url` → actionable message + `exit 1` (was a raw trace); unreachable still → the `make up-agno` message; bad-backend still `exit 2`.

- [x] [Review][Defer] **`_normalizeMessageIds` normalizes only `messageId`, not `toolCallId`** [tool/capture_fixtures.dart:801-814] — deferred, latent. Correct for the text-only run agno emits today (no tool events), but the function is generic over `payloads`; if reused for a tool-call capture in Stories 5.6/5.9, `toolCallId` (also UUID4 per AG-UI) would not be remapped → non-byte-stable golden. Not triggered by 5.3's scope.

## Dev Notes

### The honest fixture matrix (the AC2 decision, baked RESOLVED with evidence)

The epic's literal AC1 asks for **six** scenarios captured under `agno/*.jsonl` with `synthesized: false`. That is contradicted by the source-verified, docker-probed backend contract — and the resolution is the epic's **own rule from Story 5.9**, applied early.

Evidence (`../koel_backend/backends/agno/CONTRACT.md`, SPIKE-AGNO + SPIKE-MOCK, 2026-06-02):
- agno's AG-UI route streams **canonical AG-UI SSE via `ag_ui.encoder.EventEncoder`** — no reshape. `AgnoAgent` therefore needs **no** response-path override (5.1 proved agno is native AG-UI; `AgnoAgent` overrides only `encodeBody`/`errorClassifier`).
- The shared mock-LLM emits **fixed text tokens** → agno produces **only** `RUN_STARTED → TEXT_MESSAGE_START → TEXT_MESSAGE_CONTENT×N → TEXT_MESSAGE_END → RUN_FINISHED`. The CONTRACT's event-type matrix marks tool-call / state-delta / reasoning / error / cancellation **"NOT native"**.
- The **only** nondeterministic field across two captures is `messageId` (UUID4) — every other field (`threadId`/`runId` echoed, content fixed) is stable. So normalizing `messageId` makes `text_only_run` a true golden artifact.

Decision (per "no CYA open questions" + "Confirmed needs adversarial evidence" — decide and bake, with the community/contract evidence cited):
1. **`text_only_run` is the real capture** (`synthesized: false`, `backendVersion: "agno==2.6.10"`). It is the FR-G1 "real captured from a running agno backend" deliverable — and it is genuinely what agno emits.
2. **Full AG-UI type conformance (FR-G4)** is proven by `ConformanceRunner.runAgainst(AgnoAgent + MockClient serving all_event_types)` (AC5) — the corpus exercises every type through AgnoAgent's **inherited** parse path. This is the right altitude: conformance is a property of the **adapter's transport+parse**, not of any one backend's emit set.
3. **No fabricated `synthesized: false` fixtures** for types agno can't emit. If an agno-namespaced fixture is ever authored for those scenarios, it carries `synthesized: true` (the Story-5.9 dojo-fallback rule). This is more honest than minting "agno" fixtures agno never produced (CLAUDE.md "every line earns its place", "no just-in-case").

This mirrors exactly how 5.1 reconciled the epic's speculative "convert agno's message shape" against the source truth (agno is native AG-UI), and how 5.2 deferred the speculative envelope parser to a real capture.

### The error-envelope question (closes or re-defers the 5.2 deferral — empirically)

Story 5.2 deferred the agno JSON error-envelope → `agentRefused`/`agentInternal` mapping to "Story 5.3's live capture" (SPIKE Q3: the native agent-error envelope is uncharacterized). 5.3 is where the empirical answer arrives:
- agno **auth** failures are **HTTP 401/403** (status codes, already mapped by `AgnoErrorClassifier` in 5.2) — **not** SSE `RUN_ERROR` events. They do not produce an event-stream fixture.
- Whether agno emits a native **SSE `RUN_ERROR` envelope** on an agent-side failure is **unknown** (the mock-LLM never errors). During capture, **attempt** to drive agno into an agent error (e.g. a malformed/oversized input) and observe the SSE. **If** a real `RUN_ERROR` envelope appears → capture it (`agno/error_path.jsonl`, `synthesized: false`), implement its `agentRefused`/`agentInternal` mapping in `AgnoErrorClassifier` (closing the 5.2 deferral against real evidence), and add a classifier test. **If not** → record the finding ("agno surfaces errors as HTTP status only; no SSE agent-error envelope under the mock-LLM") and the 5.2 deferral **stays deferred** — do **not** build a speculative envelope parser (CLAUDE.md "no just-in-case"; memory: ["Confirmed" needs adversarial evidence]). Either outcome is a clean, evidence-backed close-out — not a gap.

### How the conformance green actually works (AC5 — the mechanism, source-verified)

`ConformanceRunner.runAgainst(AbstractAgent)` ([conformance_runner.dart](packages/koel_test/lib/src/conformance_runner.dart)) loads its **own** corpus (`synthesized/all_event_types.jsonl`, 28 types) and drives `agent.run(RunAgentInput(threadId:'conformance-thread', runId:'conformance-run'))` directly, matching emitted events to the corpus by `runtimeType` + freezed `==`. For `AgnoAgent`:
- `AgnoAgent extends HttpAgent`; `run` is inherited. The injected `client` (a `MockClient`) intercepts the POST and returns a canned SSE `Response`. So the test must make the `MockClient` serve **the 28-type corpus re-framed as SSE** — the corpus payloads piped through `_sseBody(...)`. `AgnoAgent`'s SSE parse (inherited, unreshaped) then emits all 28 → `report.failed` empty.
- This is the **same** `MockClient`/`_fixturePayloads`/`_sseBody` pattern already proven in [agno_agent_test.dart:166-180](packages/koel_agno/test/agno_agent_test.dart#L166-L180) (which replays `text_only_run`/`tool_call_basic` through AgnoAgent and asserts equality). 5.3 just points it at `all_event_types` and runs it through `ConformanceRunner` instead of a bare `.toList()` compare. Low risk — the parse path is unchanged koel_http behavior.
- **A wire `RUN_ERROR` in the corpus does NOT terminate the AgnoAgent stream — source-verified, this is the one thing to not second-guess.** `all_event_types.jsonl` carries both `RUN_ERROR` and `RUN_FINISHED` (each type once). `HttpAgent.run` yields parsed events verbatim via `yield* abortOnCancel(connection.track(events), response.abort)` ([http_agent.dart:312](packages/koel_http/lib/src/http_agent.dart#L312)); the "terminal `RunErrorEvent`" language in its dartdoc ([http_agent.dart:36,132,170](packages/koel_http/lib/src/http_agent.dart#L36)) refers **only** to a *transport/parser failure* being classified into a `RunErrorEvent` by the `InterceptorChain` — **not** to a successfully-parsed wire `RUN_ERROR` event. The chain's error classifier fires on **thrown** errors, never on a parsed `RunErrorEvent`. So a wire `RUN_ERROR` rides through as a plain emitted `AgUiEvent`, and all 28 types reach `ConformanceRunner`. (If this assumption were ever false, the test would fail loudly with a missing-type failure naming `RUN_FINISHED` — not silently.)
- The conformance test lives in **`koel_agno/test/`**, not `koel_test/test/` — `koel_test` must not depend on `koel_agno` (layering: koel_test is Epic 3, koel_agno is Epic 5 and dev-depends on koel_test). koel_agno already has `koel_test` as a dev-dep (`FixtureLoader` + `ConformanceRunner` reachable).

### Existing-code contracts that must not break

- **koel_test is a `done`, ≥80%-covered, sealed package.** AC3 (additive optional field) + AC4 (failure-message-only guard) are **sanctioned** here: AC3 is required by the epic's "backend version recorded" with no existing slot; AC4's trigger ("live captures can produce partial/truncated lines") is **now active** per the prep-plan, which explicitly routes the 3.3/3.5 cluster here. Keep both **strictly additive** — the 7 synthesized fixtures and the entire 3.x suite must stay green. Re-run koel_test's gate.
- **`tool/capture_fixtures.dart` is a repo tool**, outside every package's coverage scope (no pubspec, zero-dep `dart:io`). It does not count toward koel_agno's 80% — koel_agno's coverage comes from its `lib/` exercised by `test/`. Keep the tool zero-dep (the scaffold's contract; a repo tool resolves only against the workspace root).
- **Adapters never throw `KoelError`** (ARCH: every failure reaches the consumer as a terminal `RunErrorEvent`). The conformance/replay tests assert emitted events; they must not expect a thrown error from `AgnoAgent.run`.
- **`plugins:` is root-only** (Story 1.7 — `plugins_in_inner_options`). koel_agno's new `analysis_options.yaml` declares **no** `plugins:`; it only `include:`s the root and layers doc lints. This is not a 1.7 reversal — it is the exact koel_http/koel_test sealer pattern.

### `_session` header shape (real agno capture)

```json
{"_session":{"koelVersion":"0.0.1","adapter":"koel_agno@0.0.1","captured":"<ISO-8601 capture instant>","threadId":"t","runId":"r","synthesized":false,"backendVersion":"agno==2.6.10"}}
```
vs. the existing synthesized header (unchanged, `backendVersion` absent → parses to `null`):
```json
{"_session":{"koelVersion":"0.0.1","adapter":"synthesized","captured":"2026-05-26T00:00:00.000Z","threadId":"t","runId":"r","synthesized":true}}
```
`adapter` carries the **adapter** version (`koel_agno@0.0.1`); `backendVersion` carries the **backend** version (`agno==2.6.10`) — two distinct facts, hence the new field. Use koel_agno's real pubspec version (`0.0.1`); the epic's `0.1.0` literal is pre-1.0 drift (the 5.1/5.2 dev notes echoed it; truth wins).

### Source tree (what to touch)

```
tool/
└── capture_fixtures.dart                # UPDATE: real --backend=agno body (Task 2); other 3 backends stay stubbed

packages/koel_test/
├── lib/src/
│   ├── fixture_loader.dart              # UPDATE: FixtureSession.backendVersion (AC3) + corrupt-line guard in _load (AC4)
│   └── conformance_runner.dart          # UPDATE: corrupt-corpus-line guard in _loadExpectedCorpus (AC4)
├── lib/src/fixtures/agno/
│   ├── .placeholder                     # DELETE once text_only_run.jsonl lands
│   └── text_only_run.jsonl              # NEW: real capture (synthesized:false), via Task 2 + Si's make up-agno
└── test/
    ├── fixture_loader_test.dart         # UPDATE: backendVersion parse/null + corrupt-line FormatException (AC3, AC4)
    └── conformance_runner_test.dart     # UPDATE: corrupt-corpus-line FormatException (AC4)

packages/koel_agno/
├── analysis_options.yaml                # NEW: sealer config (mirror koel_http) — no plugins:, doc gate on (AC7)
├── coverage_options.yaml                # NEW: standard generated-file ignore list (AC7)
├── README.md                            # UPDATE: default-ON auth sentence (AC7, 5.2 deferral)
├── lib/src/error/agno_error_classifier.dart   # UPDATE *only if* a real error envelope is captured (see Dev Notes)
└── test/
    └── conformance_test.dart            # NEW: ConformanceRunner green + real-capture round-trip, @Tags(['conformance']) (AC5)

.github/workflows/conformance.yml        # UPDATE: placeholder → real agno conformance job (AC6)
pubspec.yaml                             # UPDATE: melos test:coverage += koel_agno gate; NEW melos `conformance` script (AC6, AC7)

_bmad-output/implementation-artifacts/deferred-work.md   # UPDATE: close 3.3 + 3.5 corrupt-line entries (AC4)
```
Adapter/test layout per architecture §ARCH (adapter conformance test in the adapter package's `test/`; fixtures bundled in koel_test per D8).

### Testing standards

- **Harness:** reuse the `agno_agent_test.dart` pattern — `MockClient` (`package:http/testing.dart`) to serve canned SSE, `_fixturePayloads`/`_sseBody` to frame fixtures as `data: <json>\n\n`. `@TestOn('vm')` (koel_agno is offline/VM; the agno conformance lane needs no Chrome). Tag the conformance file `@Tags(['conformance'])`.
- **koel_test corrupt-line tests:** stage crafted JSONL (a temp file via `Directory.systemTemp`, or feed a crafted corpus line) and assert `throwsA(isA<FormatException>())` whose `message` names the fixture/line. Check how the 3.3/3.5 tests stage inputs and mirror that exact convention (do not invent a new fixture-staging style).
- **Coverage:** koel_agno ≥80% line+branch (adapter tier, NFR-12) — the gate is **enforced now** (AC7 wiring). The capture tool is out of scope (repo tool). koel_test stays ≥80% after the AC3/AC4 lib changes — run its gate too.
- **No `analysis_options.yaml` suppressions:** if the new member-doc gate fires, backfill the dartdoc — do not disable the rule.

### Latest technical / wire facts (source-verified, not web-guessed)

From `../koel_backend` (authoritative — source-read + docker-probed, more reliable than any web doc):
- `agno == 2.6.10`, `ag-ui-protocol == 0.1.18`. Route `POST /agno-chat`; SSE `text/event-stream; charset=utf-8`; request/response **camelCase**; canonical AG-UI via `EventEncoder` (no reshape).
- Auth: agno has **zero built-in auth** (CORS only); 401 (missing/malformed header) / 403 (wrong token) come from koel_backend's **opt-in** FastAPI dependency (`AGNO_AUTH_TOKEN`). `/status` is always open and reports the version (`{"status":"ok","framework":"agno","version":"2.6.10"}`).
- The single nondeterministic field is `messageId` (UUID4/message). `make up-agno` (port 8002) + the shared mock-LLM make the text run otherwise byte-deterministic — `scripts/capture-twice-diff.sh` exits 0 after normalizing `messageId`.
- No dependency bump: capture tool is zero-dep `dart:io`; koel_agno stays on `http: ^1.6.0`.

### References

- [Source: _bmad-output/planning-artifacts/epics/epic-5-backend-bridges-koelagno-koellanggraph-koelruntime.md#Story-5.3] — story ACs (captured fixtures, ConformanceRunner green, coverage ≥80%) + the Story-5.9 dojo-fallback rule reused by AC2.
- [Source: _bmad-output/implementation-artifacts/epic-5-prep-plan.md] — step 3 (fill `capture_fixtures.dart --backend=agno`; Si runs `make up-agno`; `MockHttpClient` offline replay; **fold the 3.3/3.5 FormatException guard here, trigger now active**); Q3 (error envelope → 5.3 live capture).
- [Source: ../koel_backend/backends/agno/CONTRACT.md] — authoritative agno wire contract (route, auth 401/403, camelCase SSE, `agno==2.6.10`, `messageId` sole nondeterministic field, text-run-only emit surface).
- [Source: _bmad-output/implementation-artifacts/5-2-agno-auth-interceptor-error-classifier.md] — the 5.2 deferrals routed here: JSON error-envelope mapping (Task 3 / AC3), README default-ON sentence (AC4), coverage-gate wiring + `analysis_options.yaml` (Dev Notes "Out of scope → 5.3").
- [Source: _bmad-output/implementation-artifacts/5-1-agno-agent-message-conversion.md] — finalization deferrals to the "5.3 sealer" (coverage gate, `analysis_options.yaml`); agno-is-native-AG-UI reconciliation precedent.
- [Source: packages/koel_test/lib/src/conformance_runner.dart] — `runAgainst(AbstractAgent)` drives `agent.run` directly against `all_event_types.jsonl`; `_loadExpectedCorpus` cast site (AC4).
- [Source: packages/koel_test/lib/src/fixture_loader.dart] — `FixtureSession` (AC3 field add), `loadAgno`, `_load` cast site (AC4 guard).
- [Source: packages/koel_agno/test/agno_agent_test.dart] — the `MockClient`/`_fixturePayloads`/`_sseBody` harness AC5 reuses; the 401→businessAuth end-to-end test.
- [Source: packages/koel_http/analysis_options.yaml + packages/koel_test/coverage_options.yaml] — the sealer `analysis_options.yaml`/`coverage_options.yaml` shape AC7 mirrors.
- [Source: pubspec.yaml#L32-L56] — root `melos.scripts` (`test:coverage` to extend; `capture-fixtures` already wired; new `conformance` script).
- [Source: .github/workflows/conformance.yml + ci.yml] — the placeholder to replace (AC6) + the step shape to mirror.
- [Source: _bmad-output/implementation-artifacts/deferred-work.md#story-3.3 + #story-3.5] — the corrupt-line → fixture-naming `FormatException` cluster AC4 closes.
- [Source: _bmad-output/planning-artifacts/architecture.md §"melos run conformance" + §"Conformance fixture pipeline"] — the `melos run conformance` lane (AC6) + capture-pipeline-as-build-prerequisite framing.

### Project Structure Notes

- koel_agno was filled by 5.1 (`agno_agent.dart`, `conversion/`, tests) + 5.2 (`agno_auth_interceptor.dart`, `error/agno_error_classifier.dart`). 5.3 adds **no new `lib/` source** to koel_agno unless a real error envelope is captured — it adds the conformance test, the two finalization config files, the README sentence, and the gate wiring. The real Dart work is the **capture tool** (`tool/`) + the **koel_test substrate** (AC3/AC4).
- Modifying koel_test (`done`, sealed) is **sanctioned**: AC3 is epic-required (no existing version slot), AC4's trigger is now active (prep-plan). Both additive; re-run koel_test's gate.
- Hybrid versioning unchanged: koel_agno `version: 0.0.1, publish_to: none`; bare workspace dep keys. No pubspec dep change (capture tool is zero-dep; `FixtureLoader`/`ConformanceRunner` already arrive via the existing `koel_test` dev-dep).

## Dev Agent Record

### Agent Model Used

claude-opus-4-8 (Opus 4.8, 1M context) — via `/bmad-dev-story`, `/agent-flutter-engineer` specialist loaded for all Dart work.

### Debug Log References

- **Chunk-synthesis finding (the one real surprise — shaped AC5).** First conformance run failed: 25/28 types passed, the 3 `*_CHUNK` variants returned `actual: null`. Root cause source-verified: `HttpAgent.synthesizeChunks` defaults `true` ([http_agent.dart:65-75,117-121](packages/koel_http/lib/src/http_agent.dart#L65-L121)) and normalizes `*_CHUNK` → `START/CONTENT/END` at the transport; `AgnoAgent` doesn't expose the flag (Addendum A.3), so it can never emit chunk shapes verbatim. This matches the prep-plan's "25/28, 3 chunk-variants synthesizable koel-side" and is the correct backend-conformance surface (real agno emits canonical `EventEncoder` output, never chunk shapes). AC5's literal "zero failures / 28" was optimistic; the test asserts the evidence-backed 25/28 with the 3 chunk types named exactly. Logged for 5.6/5.9 in deferred-work.md.
- **Capture tool validated end-to-end without a live backend.** docker not running in the dev env (`docker info` fails; `:8002` refused). Drove `tool/capture_fixtures.dart --backend=agno` against a throwaway mock agno server emitting the exact CONTRACT.md SSE (with two UUID `messageId`s): 6 events captured, `messageId` → `msg-0`, monotonic timestamps, `_session` header correct (`adapter: koel_agno@0.0.1`, `synthesized: false`, `backendVersion: agno==2.6.10`). Mock-derived file **deleted** (never committed — not a real capture). Error paths smoke-tested: exit 2 (bad/missing `--backend`), exit 1 (unreachable, with the `make up-agno` message), exit 0 (langgraph stub).
- `melos run analyze` → No issues found! across all 11 packages (NFR-13). The new koel_agno `comment_references` gate surfaced 5 pre-existing latent doc-refs (5.2 code) → fixed, not suppressed.
- `melos run test:coverage` → koel_core 98.85%/97.87%, koel_http 94.58%/92.15%, koel_test 95.58%/92.54%, koel_agno **100.00%/100.00%** (NFR-12, all tiers green).
- `melos run conformance` → koel_agno conformance lane green (test 1 passes; test 2 skips pending the operator capture). `melos run test` → green (one koel_http `cancellation_test` wall-clock `<50ms` flake on the parallel first run — passes 10/10 in isolation + on retry; documented flake, koel_http untouched). `tool/format.sh check` → clean.

### Completion Notes List

- **COMPLETE — all tasks/subtasks done, all gates green.** Si ran the live capture (`make up-agno` → `dart run tool/capture_fixtures.dart --backend=agno`); the real `synthesized: false` `agno/text_only_run.jsonl` landed (deltas spell the CONTRACT.md mock-LLM text — a genuine live capture, not the dev-env mock). The presence-guarded round-trip test now asserts (no skip) and passes — FR-G1 "real captured" satisfied. `.placeholder` removed; `fixtures_test` invariant updated.
- **Task 1 (koel_test substrate).** `FixtureSession.backendVersion` (optional, backward-compatible). Corrupt-line guard lifted to a single shared `decodeFixtureEvent` (`fixture_envelope.dart`) used by both `FixtureLoader._load` and `ConformanceRunner._loadExpectedCorpus` — **deviated** from the story's "local guard per site" because a per-site duplicate isn't unit-testable (both read fixed assets via `package:` URI; a corrupt line can't be staged without polluting shipped fixtures + racing `fixtures_test`). One shared `src/` helper is DRY and directly testable. Closed the 3.3 + 3.5 deferrals.
- **Task 2 (capture tool).** Zero-dep `dart:io`/`dart:convert`; `HttpClient` POST + `GET /status`; `messageId` normalization for golden stability; `_endpoint` mirrors `AgnoAgent`'s trailing-slash-safe derivation; actionable `SocketException`/non-200/empty-stream failures. Validated against a mock server (then deleted the artifact). **The real fixture is the operator step.**
- **Task 3 (conformance).** Shared `test/_support.dart` (`fixturePayloads`/`sseBody`/`sseClient`); refactored `agno_agent_test.dart` onto it. Conformance test asserts the **25/28** contract (see Debug Log). Real-capture round-trip test is presence-guarded (`markTestSkipped` with the capture command) — activates when Si commits the fixture.
- **Task 4 (CI lane).** `melos run conformance` + `tool/conformance.sh` (gated on `dart_test.yaml` tag declaration → quiet logs); `conformance.yml` real job (offline, MockClient). 5.6/5.9 extend by declaring their tag.
- **Task 5 (finalization).** `analysis_options.yaml` (doc gate on) + `coverage_options.yaml` + coverage-gate wiring + README auth note. Fixed the doc-refs the gate surfaced.
- **Operator step DONE by Si.** Live capture committed; `.placeholder` removed; `fixtures_test.dart` invariant updated; the round-trip test asserts (no skip). The deferred-work operator entry is closed; the agno **error-envelope** entry stays open (a separate future capture of an error path — agno's auth errors are HTTP 401/403, already mapped; an SSE `RUN_ERROR` envelope was not characterized).

### File List

- `packages/koel_test/lib/src/fixture_envelope.dart` — **NEW**: shared `decodeFixtureEvent` corrupt-line guard (AC4).
- `packages/koel_test/lib/src/fixture_loader.dart` — **MODIFIED**: `FixtureSession.backendVersion` (AC3); `_load` routes events through `decodeFixtureEvent` (AC4).
- `packages/koel_test/lib/src/conformance_runner.dart` — **MODIFIED**: `_loadExpectedCorpus` routes through `decodeFixtureEvent` (AC4); dropped unused `dart:convert`.
- `packages/koel_test/test/fixture_loader_test.dart` — **MODIFIED**: `backendVersion` parse/null/wrong-type (AC3) + corrupt-line FormatException group (AC4).
- `packages/koel_test/test/conformance_runner_test.dart` — **MODIFIED**: corpus-naming FormatException test (AC4).
- `packages/koel_test/lib/src/fixtures/agno/text_only_run.jsonl` — **NEW (captured by Si)**: real live agno capture, `synthesized: false`, `backendVersion: agno==2.6.10` (AC1, AC2, FR-G1).
- `packages/koel_test/lib/src/fixtures/agno/.placeholder` — **DELETED**: superseded by the real capture (AC2).
- `packages/koel_test/test/fixtures_test.dart` — **MODIFIED**: `pendingCaptureDirs` invariant + "agno graduated" assertion (AC2).
- `tool/capture_fixtures.dart` — **MODIFIED**: real `--backend=agno` body (AC1, AC2).
- `packages/koel_agno/test/conformance_test.dart` — **NEW**: ConformanceRunner 25/28 + presence-guarded real-capture round-trip (AC5).
- `packages/koel_agno/test/_support.dart` — **NEW**: shared `fixturePayloads`/`sseBody`/`sseClient` test helpers (AC5).
- `packages/koel_agno/test/agno_agent_test.dart` — **MODIFIED**: refactored onto `_support.dart` (dropped duplicated helpers).
- `packages/koel_agno/dart_test.yaml` — **NEW**: declares the `conformance` tag (AC5/AC6).
- `packages/koel_agno/analysis_options.yaml` — **NEW**: sealer config, member-doc gate on (AC7).
- `packages/koel_agno/coverage_options.yaml` — **NEW**: generated-file ignore list (AC7).
- `packages/koel_agno/lib/src/agno_auth_interceptor.dart` — **MODIFIED**: doc-refs the `comment_references` gate surfaced (AC7).
- `packages/koel_agno/test/agno_auth_interceptor_test.dart` — **MODIFIED**: corrected a stale doc-ref (AC7).
- `packages/koel_agno/README.md` — **MODIFIED**: default-ON Authentication note (AC7, 5.2 deferral).
- `tool/conformance.sh` — **NEW**: per-package conformance lane for `melos run conformance` (AC6).
- `.github/workflows/conformance.yml` — **MODIFIED**: placeholder → real offline agno conformance job (AC6).
- `pubspec.yaml` — **MODIFIED**: `conformance` melos script; koel_agno coverage gate in `test:coverage`; `capture-fixtures` description (AC4/AC6/AC7).
- `_bmad-output/implementation-artifacts/deferred-work.md` — **MODIFIED**: closed 3.3 + 3.5 entries; recorded 3 new 5.3 deferrals.

## Change Log

| Date | Version | Description | Author |
|------|---------|-------------|--------|
| 2026-06-03 | 0.1 | Story drafted — agno-group sealer: real `capture_fixtures.dart --backend=agno` body, honest fixture matrix (text-run real / others via corpus + Story-5.9 fallback rule), `FixtureSession.backendVersion`, 3.3/3.5 corrupt-line `FormatException` guard, `ConformanceRunner` green against `AgnoAgent`, conformance.yml lane + `melos run conformance`, koel_agno finalization (coverage gate, analysis_options, coverage_options, README default-ON sentence). Status → ready-for-dev. | Bob (SM) |
| 2026-06-03 | 0.2 | Implemented 5.3 (all code green): `FixtureSession.backendVersion` + shared `decodeFixtureEvent` corrupt-line guard (closes 3.3/3.5); real `capture_fixtures.dart --backend=agno` body (validated vs mock, golden `messageId` normalization); conformance test asserting the evidence-backed **25/28** contract (3 `*_CHUNK` shapes are koel_http `synthesizeChunks`-normalized — AC5's literal 28 corrected) + presence-guarded real-capture round-trip; `melos run conformance` + offline `conformance.yml`; koel_agno finalization (analysis_options/coverage_options/coverage-gate/README). All gates green. Status `in-progress` pending the live capture. | Amelia (Dev) |
| 2026-06-03 | 1.0 | Si ran the live capture — real `agno/text_only_run.jsonl` landed (`synthesized: false`, `backendVersion: agno==2.6.10`, CONTRACT.md mock-LLM text). `.placeholder` removed; `fixtures_test.dart` invariant updated (`pendingCaptureDirs` + agno-graduated assertion); round-trip test now asserts (no skip). Final gates: analyze 0 (11 pkgs), coverage agno 100/100 + test 95.58/92.54, conformance +2 green, format clean. **Status → review.** | Amelia (Dev) |
