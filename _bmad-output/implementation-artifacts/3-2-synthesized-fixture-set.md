---
baseline_commit: 8c26147
---

# Story 3.2: Synthesized fixture set + storage layout

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

> **Dev agent:** this story writes **data, not logic** — JSONL fixture files + a backend-organized directory tree + a structural-validation test. It is the second `koel_test` story and the substrate Stories 3.3 (`FixtureLoader`/`fromFixture`), 3.4 (`ToolHandlerTestHarness`), and 3.5 (`ConformanceRunner`) all consume. The one `.dart` file you write is a **test** (Dart code → **invoke `/agent-flutter-engineer` before producing it**, per CLAUDE.md). Five things are load-bearing, and four are *non-obvious traps*:
> 1. **The `payload` of every event line MUST be byte-shape-identical to the matching line in `koel_core/test/event/full_event_sweep.jsonl`.** That file is the *only* set of wire-format JSON proven to round-trip through the real (internal) codec (`full_event_sweep_test.dart` asserts it). Author your `payload`s by copying those 28 lines — do **not** invent field names. See §"The canonical wire reference".
> 2. **The wire deserializer is INTERNAL** (`deserializeAgUiEvent`/`eventTypeRegistry` live in `koel_core/lib/src/event/event_deserializer.dart` and are **deliberately not exported** from the public barrel — the barrel comment says so :32). So this story's test **cannot** decode `payload → AgUiEvent`; it validates **JSON structure only**. Semantic decoding is **Story 3.3's** problem (and 3.3 will have to solve the internal-codec-access wall — *not your concern here, do not pre-solve it*). See §"What the test can and cannot assert".
> 3. **`koel_test` is a PURE DART package — no Flutter SDK dep.** So the AC's "`flutter.assets:`" arm does **not** apply; the **"`package:` URI relative-path resolution (Dart packages)"** arm does. **Do NOT add a `flutter:`/`flutter.assets:` stanza** — files under `lib/` are package-URI-addressable and ship in the published tarball *automatically* for a Dart package. Adding a Flutter stanza to a non-Flutter package is wrong and may break resolution. See §"The pubspec 'asset' AC — already satisfied".
> 4. **`publish_to: none` stays.** Every package in the monorepo is `publish_to: none` today (they flip to publishable at Epic 9 Story 9.9 lock-step publish). AC3's "bundled in the published tarball" is about the *bundling mechanism* (lib/ ships), not about publishing now. **Do not touch `publish_to`.** See §"Out of scope".
> 5. **Determinism — no `DateTime.now()`, no `Random`, anywhere.** These are static hand-authored files; every `timestamp`, `threadId`, `runId`, `captured`, `messageId` is a **fixed literal** you type. Tests assert on them; a live clock would make the fixtures non-reproducible (flakiness is a bug per convention §6). See §"Determinism".

## Story

As an OSS contributor,
I want `koel_test/lib/src/fixtures/` to ship JSONL synthesized fixtures covering every AG-UI event type and key scenarios under a backend-organized layout (`synthesized/`, `dojo/`, `agno/`, `langgraph/`, `copilotkit_runtime/`),
so that early epics (Epic 4 `koel_http`) can test against canonical fixtures before real backend captures arrive in Epic 5 per FR-G1 + AR-13.

## Acceptance Criteria

Verbatim from [epic-3 Story 3.2](../planning-artifacts/epics/epic-3-test-harness-conformance-koeltest.md):

1. **Given** `koel_test/lib/src/fixtures/`, **When** I list the directory, **Then** five subdirectories exist: `synthesized/`, `dojo/`, `agno/`, `langgraph/`, `copilotkit_runtime/`, **And** `synthesized/` contains at minimum one fixture per AG-UI event type plus core scenarios: `text_only_run.jsonl`, `tool_call_basic.jsonl`, `state_delta_basic.jsonl`, `reasoning_with_encrypted_value.jsonl`, `error_path.jsonl`, `cancellation.jsonl`.

2. **Given** any synthesized JSONL fixture, **When** I read the first line, **Then** it is the `_session` metadata header per Addendum C.4 with `koelVersion`, `adapter`, `captured`, `threadId`, `runId`, and a `synthesized: true` marker, **And** subsequent lines each carry one event with `timestamp` (ISO 8601) + `payload` (wire-format JSON).

3. **Given** `koel_test/pubspec.yaml`, **When** I inspect it, **Then** the fixtures directory is declared under `flutter.assets:` (Flutter packages) or referenced via `package:` URI relative path resolution (Dart packages), **And** the assets are bundled in the published tarball.

4. **Given** the backend subdirectories `dojo/`, `agno/`, `langgraph/`, `copilotkit_runtime/`, **When** I list each, **Then** each carries a `.placeholder` file with a doc comment naming Epic 5 stories that populate it, **And** no real captured fixtures exist yet (real captures land in Stories 5.3, 5.6, 5.9).

## Tasks / Subtasks

- [x] **Task 1 — Create the five-subdirectory fixture tree** (AC: #1, #4)
  - [x] Under `packages/koel_test/lib/src/fixtures/`, create five subdirectories: `synthesized/`, `dojo/`, `agno/`, `langgraph/`, `copilotkit_runtime/`. This is the architecture-pinned location (architecture :968 `fixtures/  # bundled per D8`; the tree at :969-977 names exactly these backend dirs). [Source: architecture.md :958-977; D8 :371-383]
  - [x] Git does not track empty directories — the `.placeholder` files (Task 4) and the synthesized `.jsonl` files (Tasks 2-3) make every directory non-empty, so all five survive the commit. Do **not** add `.gitkeep` (the `.placeholder` is the intentional marker for the four backend dirs). [Source: AC4; git empty-dir behavior]

- [x] **Task 2 — Author the `_session` header contract + a shared header for every synthesized fixture** (AC: #2)
  - [x] Every synthesized JSONL file's **first line** is a `_session` metadata header per Addendum C.4. The object has a single top-level `_session` key whose value carries **exactly** these fields (AC2 names them): `koelVersion`, `adapter`, `captured`, `threadId`, `runId`, and the `synthesized: true` marker. [Source: AC2; Addendum C.4 :553-563; FR-G1 :187 "synthesized fixtures with `synthesized: true` in the metadata header"]
  - [x] Bake these **fixed literal** values (RESOLVED — see §"Determinism" + §"Design decisions"):
    - `"koelVersion": "0.0.1"` — the current monorepo version (every package is `0.0.1` today). Static literal, not a runtime read; updated by hand if AG-UI spec releases (F-G1 "Updated when AG-UI spec releases").
    - `"adapter": "synthesized"` — these are hand-synthesized, not captured from a backend (real captures use `"koel_agno@1.0.0"`-style strings, C.4 :556). The `"synthesized"` adapter string pairs with the `synthesized: true` marker.
    - `"captured": "2026-05-26T00:00:00.000Z"` — a fixed ISO-8601 UTC anchor (the AG-UI `release/2026-05-26` date, which CONFORMANCE.md pins in Story 3.5). Same literal in every synthesized header.
    - `"synthesized": true` — the marker.
    - `"threadId"` / `"runId"` — **per-fixture deterministic** strings derived from the file name, e.g. `text_only_run.jsonl` → `"threadId": "synth-text-only-run"`, `"runId": "synth-text-only-run-1"`. The header's `threadId`/`runId` MUST match the `RUN_STARTED`/`RUN_FINISHED` payloads in that same file (a self-consistent run bracket — the reducer keys run phase off them; see §"Self-consistency"). [Source: 3-1 §"Builder ID determinism"; chat_state_reducer RunPhase (Story 2.12)]
  - [x] Header line shape (single line, no trailing newline issues — each fixture is newline-delimited JSON, one object per physical line):
    ```jsonl
    {"_session":{"koelVersion":"0.0.1","adapter":"synthesized","captured":"2026-05-26T00:00:00.000Z","threadId":"synth-text-only-run","runId":"synth-text-only-run-1","synthesized":true}}
    ```

- [x] **Task 3 — Author the synthesized event-line fixtures** (AC: #1, #2)
  - [x] **Event-line shape (RESOLVED).** Every line after the header is one event: `{"type": <wire-type mirror>, "timestamp": <ISO 8601>, "payload": <full wire-format JSON>}`. The `payload` is the complete wire object (it **includes** its own `type` field — it is exactly what the codec deserializes); the top-level `type` mirrors `payload.type` for human/DevTools readability. This matches Addendum C.4's example shape (:557-560). Story 3.3's `FixtureLoader` will decode `line['payload']`. [Source: AC2; Addendum C.4 :553-563]
    ```jsonl
    {"type":"RUN_STARTED","timestamp":"2026-05-26T00:00:00.000Z","payload":{"type":"RUN_STARTED","threadId":"synth-text-only-run","runId":"synth-text-only-run-1"}}
    ```
  - [x] **Timestamps are fixed + monotonic per file.** Start each fixture at `2026-05-26T00:00:00.000Z` and increment by a fixed step (e.g. +100 ms) per event line: `…00.000Z`, `…00.100Z`, `…00.200Z`, … No `DateTime.now()`. ISO-8601 with millis + `Z`. [Source: AC2 "timestamp (ISO 8601)"; §"Determinism"]
  - [x] **Author the six required named core scenarios** (verbatim file names from AC1), each a coherent run bracket (`RUN_STARTED` … terminal), payloads copied from the canonical reference (§"The canonical wire reference"):
    - `text_only_run.jsonl` — `RUN_STARTED` → `TEXT_MESSAGE_START` → `TEXT_MESSAGE_CONTENT` → `TEXT_MESSAGE_END` → `RUN_FINISHED`. (The smallest happy path; 3.3 AC asserts `chatSession.state.messages.last.content` replays from this one.)
    - `tool_call_basic.jsonl` — `RUN_STARTED` → `TOOL_CALL_START` → `TOOL_CALL_ARGS` → `TOOL_CALL_END` → `TOOL_CALL_RESULT` → `RUN_FINISHED`.
    - `state_delta_basic.jsonl` — `RUN_STARTED` → `STATE_SNAPSHOT` → `STATE_DELTA` → `RUN_FINISHED`. Use a **non-empty** RFC-6902 patch in the `STATE_DELTA` payload (the sweep's `"delta":[]` is empty; a basic delta should mutate state so 3.3/3.5 can assert a downstream `ChatState` change). A single `add`/`replace` op against the prior `STATE_SNAPSHOT` is enough, e.g. `{"type":"STATE_DELTA","delta":[{"op":"replace","path":"/count","value":2}]}` (verify the op field name — `delta` vs `patches` — against `StateDeltaEvent.toJson()`; the sweep line is the source of truth). [Source: full_event_sweep.jsonl `STATE_DELTA`; json_patch_op.dart]
    - `reasoning_with_encrypted_value.jsonl` — `RUN_STARTED` → `REASONING_START` → `REASONING_MESSAGE_START` → `REASONING_MESSAGE_CONTENT` → `REASONING_MESSAGE_END` → `REASONING_ENCRYPTED_VALUE` → `REASONING_END` → `RUN_FINISHED`. The `REASONING_ENCRYPTED_VALUE` payload's `encryptedValue` is a base64 string (`"AAAA"` in the sweep) — the F-A9 round-trip type. [Source: full_event_sweep.jsonl `REASONING_*`; FR-G1 "reasoning incl. encryptedValue round-trip"]
    - `error_path.jsonl` — `RUN_STARTED` → `TEXT_MESSAGE_START` → `TEXT_MESSAGE_CONTENT` → `RUN_ERROR`. The in-band error event (adapters never throw — `RunErrorEvent` is the error channel, architecture §5 / 3-1 §"Error channel"). **No `RUN_FINISHED`** — the error terminates the run.
    - `cancellation.jsonl` — `RUN_STARTED` → `TEXT_MESSAGE_START` → `TEXT_MESSAGE_CONTENT` (→ … truncated). A run bracket **opened but never closed**: no `RUN_FINISHED`, no `RUN_ERROR`. Models a mid-stream cancellation / connection-close (the TCP-close analog from 3.1 AC3) as a static truncated prefix. [Source: 3-1 AC3; FR-G1 "cancellation"]
  - [x] **Guarantee full event-type coverage** (AC1 "at minimum one fixture per AG-UI event type"). The six scenarios above do not naturally include every one of the 28 registered wire types (the orphans: `STEP_STARTED`, `STEP_FINISHED`, `TEXT_MESSAGE_CHUNK`, `TOOL_CALL_CHUNK`, `MESSAGES_SNAPSHOT`, `ACTIVITY_SNAPSHOT`, `ACTIVITY_DELTA`, `REASONING_MESSAGE_CHUNK`, `RAW`, `CUSTOM`). Ship one additional coverage fixture:
    - `all_event_types.jsonl` — the canonical coverage sweep: **one event line per registered wire type** (28 lines), wrapped in the trace envelope, with a `_session` header. This is the direct analog of `koel_core/test/event/full_event_sweep.jsonl` (copy its 28 `payload`s verbatim, wrap each as `{"type","timestamp","payload"}`). This single fixture is what makes "one fixture per event type" literally true and gives Story 3.5's `ConformanceRunner` a clean per-type driver. [Source: AC1; full_event_sweep.jsonl; epic-3 3.5 "drives the agent through every event-type scenario in synthesized/ … records pass/fail per event type" :117]
  - [x] **Self-consistency within each fixture.** Within one file, every `messageId` pairs its `*_START`/`*_CONTENT`/`*_END`, every `toolCallId` pairs its `TOOL_CALL_START`/`…_ARGS`/`…_END`/`…_RESULT`, and the run bracket shares one `threadId`/`runId` matching the `_session` header. `messageId`s are non-empty (the verify stage drops empty-`messageId` text events — 3-1 trap #2). Deterministic literal ids: `msg-1`, `tc-1`, etc. [Source: 3-1 §"Builder ID determinism"; pipeline/verify_stage.dart:84-103; chat_state_reducer keying (Story 2.12)]

- [x] **Task 4 — Backend-dir `.placeholder` files naming the Epic 5 populating stories** (AC: #4)
  - [x] In each of `dojo/`, `agno/`, `langgraph/`, `copilotkit_runtime/`, add a `.placeholder` file with a doc comment naming the **exact** Epic 5 story that captures real fixtures into it. No real captured fixtures exist yet. [Source: AC4; epic-3 3.2 AC "real captures land in Stories 5.3, 5.6, 5.9"; epic-5 story headings]
    - `agno/.placeholder` → **Story 5.3** (`koel_agno` — Captured fixtures + ConformanceRunner green).
    - `langgraph/.placeholder` → **Story 5.6** (`koel_langgraph` — Fixtures + ErrorClassifier + ConformanceRunner green).
    - `copilotkit_runtime/.placeholder` → **Story 5.9** (`koel_runtime` — Fixtures + dojo fallback + ConformanceRunner green).
    - `dojo/.placeholder` → **Story 5.9** (the dojo backend is captured via the "dojo fallback" of 5.9). [Source: epic-5 :196 "Story 5.9: koel_runtime — Fixtures + dojo fallback"]
  - [x] `.placeholder` content (a plain UTF-8 text file; the leading `#` is a human doc comment, not code — these dirs hold data, not Dart):
    ```
    # Real <backend> protocol fixtures land here in Epic 5 Story <N> (<story title>).
    # Captured live from a real <backend> backend per FR-G1; until then this directory
    # is intentionally empty of fixtures. Do not hand-author captures here — synthesized
    # fixtures live in ../synthesized/.
    ```

- [x] **Task 5 — Confirm the pubspec bundling AC (NO Flutter stanza)** (AC: #3)
  - [x] **Make no change to `pubspec.yaml` for asset bundling.** `koel_test` is a pure Dart package (its `pubspec.yaml` has no `flutter:` section and no `flutter` SDK dependency — verified). For a Dart package, **all files under `lib/` are bundled in the published tarball automatically and are addressable via `package:koel_test/src/fixtures/...` URI resolution** — this is the AC3 "`package:` URI relative path resolution (Dart packages)" arm. There is nothing to declare. [Source: AC3; pubspec.yaml (no flutter dep); D8 :381 "FixtureLoader reads via `package:` asset URI"]
  - [x] **Do NOT** add a `flutter:`/`flutter.assets:` stanza. That arm of the AC is for Flutter packages (`koel_flutter`, `koel_widgets`); applying it here would require adding the Flutter SDK dependency — a scope-violating, wrong change for a framework-free package. If a `flutter.assets:` stanza is ever needed it is a future concern for whichever package consumes fixtures *through `rootBundle`* — not this story, not this package. [Source: §"The pubspec 'asset' AC"; architecture "framework-free core"]
  - [x] **Do NOT** change `publish_to: none`. See §"Out of scope".

- [x] **Task 6 — Structural-validation test** (AC: #1, #2)
  - [x] New `packages/koel_test/test/fixtures_test.dart` (`package:test` only — convention §6). It reads the fixtures from disk via `File('lib/src/fixtures/...')`; under `melos run test` the CWD is the package root (proven pattern — `koel_core/test/event/full_event_sweep_test.dart:16` reads `File('test/event/full_event_sweep.jsonl')` the same way; `tool/test_package.sh` sets CWD = package root). [Source: full_event_sweep_test.dart:13-17; pubspec.yaml :30 "CWD = package root for fixture reads"]
  - [x] **AC1 (structure):** assert the five subdirectories exist; assert `synthesized/` contains the six required named files **plus** `all_event_types.jsonl`.
  - [x] **AC2 (header):** for every `synthesized/*.jsonl`, `jsonDecode` the first line, assert it has a single `_session` key, and that the `_session` object contains all six required fields (`koelVersion`, `adapter`, `captured`, `threadId`, `runId`, `synthesized`) with `synthesized == true`.
  - [x] **AC2 (event lines):** for every subsequent line, assert it `jsonDecode`s to a map with `type` (String), `timestamp` (String — parses via `DateTime.parse`), and `payload` (Map). Assert `payload['type'] == line['type']` (the mirror invariant). Do **NOT** attempt to decode `payload → AgUiEvent` — the codec is internal and unreachable from the public barrel (see trap #2). [Source: §"What the test can and cannot assert"]
  - [x] **AC1 (coverage):** assert the **union** of `type` values across all `synthesized/*.jsonl` event lines equals the full set of 28 registered wire types. The registry is internal, so hard-code the 28 type strings as a frozen `const Set<String>` in the test (they are stable protocol constants; list them from §"The 28 registered wire types"). A coverage gap then fails loudly with the missing type named. [Source: §"What the test can and cannot assert"; full_event_sweep.jsonl 28-type set]
  - [x] **AC2 (well-formed JSONL):** assert no fixture has a blank/whitespace-only line and that every non-header line round-trips `jsonDecode → jsonEncode → jsonDecode` to an equal map (catches trailing-comma / malformed-JSON authoring slips early).

- [x] **Task 7 — Quality gates** (AC: all)
  - [x] `melos run analyze` → **0 issues** workspace-wide (the new test file must not introduce diagnostics; the `.jsonl`/`.placeholder` data files are not analyzed). [Source: NFR-13]
  - [x] `melos run test` → green, including the new `koel_test` `fixtures_test.dart` alongside the existing `mock_agent_test.dart`. [Source: 2-15/3-1 melos test wiring]
  - [x] `dart format --set-exit-if-changed .` (via `melos run format:check`) → clean. Only the new `.dart` test file is formatted; `.jsonl`/`.placeholder` files are not Dart and are untouched by `dart format`. [Source: convention; tool/format.sh]
  - [x] Confirm **no `koel_core` change** and **no other package change** — this story is additive in `koel_test` only (data files + one test). [Source: §"Files you will touch"]
  - [x] **Do NOT** add a `koel_test/analysis_options.yaml` doc-gate or coverage-threshold wiring — `koel_test`'s ≥80% coverage gate (NFR-12) is **Story 3.5's** AC (the epic-sealing story), not 3.2's. [Source: epic-3 3.5 coverage AC; 3-1 Task 6 precedent]

### Review Findings

> Code review 2026-05-31 (Blind Hunter + Edge Case Hunter + Acceptance Auditor). **No AC violation and no data/correctness defect** — the 7 shipped fixtures + 4 placeholders are spec-compliant and the auditor + the throwaway codec check confirm the payloads are wire-correct. Every finding below hardens the **test** (`fixtures_test.dart`), the guardian of the corpus Stories 3.3/3.5 build on, to lock spec-stated invariants it currently under-enforces.

- [x] [Review][Patch] `_session` field check is presence-only, not set-equality — Task 2 mandates "exactly these fields" but the test loops `containsKey` (a future 7th field passes); auditor recommends `expect(session.keys.toSet(), equals(requiredSessionFields))` [packages/koel_test/test/fixtures_test.dart:161-167]
- [x] [Review][Patch] Header↔`RUN_STARTED` id agreement unchecked — §Self-consistency requires `_session.threadId/runId` equal the run-bracket payload ids (3.3 keys run phase off them); test never asserts it, so header/event drift goes undetected [packages/koel_test/test/fixtures_test.dart:176-204]
- [x] [Review][Patch] Timestamp monotonicity never asserted — Task 3 says timestamps are "fixed + monotonic per file"; the test parses each `timestamp` but never checks it strictly increases down the file [packages/koel_test/test/fixtures_test.dart:188-193]
- [x] [Review][Patch] "No blank line" guard misses truly-empty lines — `l.isNotEmpty && l.trim().isEmpty` only flags whitespace-only; a genuinely empty (`""`) mid-file line is excluded and silently dropped by `linesOf`, so the spec's "no blank/whitespace-only line" is under-enforced [packages/koel_test/test/fixtures_test.dart:143]
- [x] [Review][Patch] `as Map<String,dynamic>` casts throw raw `CastError` on non-object JSON — a bare-array/scalar line (header or event) crashes opaquely instead of failing with a named structural assertion [packages/koel_test/test/fixtures_test.dart:153,160,180,194]
- [x] [Review][Patch] No non-emptiness guard on the fixture set or per-fixture — an empty file crashes opaquely on `linesOf(...).first`, a header-only file passes every format test while contributing zero coverage (silent gap); add `expect(synthesizedFixtures(), isNotEmpty)` + per-fixture `lines.length > 1` [packages/koel_test/test/fixtures_test.dart:86-90,151,178,210]
- [x] [Review][Patch] Tautological round-trip assertion — `jsonDecode(jsonEncode(decoded)) == decoded` is always true for any `jsonDecode` output, so it catches nothing beyond the preceding `jsonDecode(line)`; dead weight per "every line earns its place" (remove, or it adds false confidence) [packages/koel_test/test/fixtures_test.dart:182-186]

**Dismissed as noise (4):** coverage-by-union "proves nothing about core scenarios" (Design Decision #4 *mandates* union coverage via `all_event_types.jsonl`); `all_event_types.jsonl` "impossible lifecycle" (it is the type-coverage sweep, the analog of `full_event_sweep.jsonl` — deliberately not a coherent run); `header.keys equals(['_session'])` "brittle" (correctly enforces the single-top-level-key contract); uppercase-`.JSONL` skipped (gold-plating; corpus is lowercase `.jsonl` by convention).

**Resolution (2026-05-31):** all 7 patches applied to `fixtures_test.dart` — test count 7 → 10 (added: non-empty fixture-set guard, header↔run-bracket id agreement, timestamp monotonicity). No fixture/data change was needed (data was already correct). Gates green: `dart analyze` workspace-wide SUCCESS, `koel_test` 26/26 (16 `mock_agent` + 10 `fixtures`), `dart format` clean. Status → done.

## Dev Notes

### What this story is, in one paragraph
The **fixture substrate** for `koel_test`. It ships a backend-organized directory tree (`synthesized/` + four backend dirs) and a set of **hand-synthesized JSONL fixtures** under `synthesized/` covering every AG-UI event type and the six canonical scenarios, each fixture a newline-delimited trace: a `_session` metadata header line (Addendum C.4) followed by `{type, timestamp, payload}` event lines. The four backend dirs carry only `.placeholder` files until Epic 5 captures real traces. There is **no new Dart class** — Story 3.3 (`FixtureLoader` + `MockAgent.fromFixture`) is what *reads* these files; this story only *produces* them (plus a structural-validation test). Scope is exactly: the directory tree, the synthesized fixtures, the placeholders, the (no-op) pubspec confirmation, and the test. [Source: epic-3 3.2 :26-52; architecture :958-977; D8 :371-383]

### The canonical wire reference (the heart of this story)
`koel_core/test/event/full_event_sweep.jsonl` is **28 lines, one per registered wire type**, and `koel_core/test/event/full_event_sweep_test.dart` *proves* every line deserializes to a typed (non-`Unknown`) subtype and round-trips through `toJson()`. **Those 28 lines are the canonical `payload` shapes.** Author your fixture `payload`s by copying the matching line and adapting only the *values* (ids, text) — never the *field names*. This is the single most important guardrail: it is how you produce wire-correct JSON without access to the internal codec. The 28 lines, verbatim from the sweep:

```jsonl
{"type":"RUN_STARTED","threadId":"t","runId":"r"}
{"type":"RUN_FINISHED","threadId":"t","runId":"r"}
{"type":"RUN_ERROR","message":"boom"}
{"type":"STEP_STARTED","stepName":"s"}
{"type":"STEP_FINISHED","stepName":"s"}
{"type":"TEXT_MESSAGE_START","messageId":"m","role":"assistant"}
{"type":"TEXT_MESSAGE_CONTENT","messageId":"m","delta":"d"}
{"type":"TEXT_MESSAGE_END","messageId":"m"}
{"type":"TEXT_MESSAGE_CHUNK"}
{"type":"TOOL_CALL_START","toolCallId":"tc1","toolCallName":"search"}
{"type":"TOOL_CALL_ARGS","toolCallId":"tc1","delta":"{\"q\":"}
{"type":"TOOL_CALL_END","toolCallId":"tc1"}
{"type":"TOOL_CALL_RESULT","messageId":"m1","toolCallId":"tc1","content":"ok"}
{"type":"TOOL_CALL_CHUNK"}
{"type":"STATE_SNAPSHOT","snapshot":{"count":1}}
{"type":"STATE_DELTA","delta":[]}
{"type":"MESSAGES_SNAPSHOT","messages":[]}
{"type":"ACTIVITY_SNAPSHOT","messageId":"m","activityType":"checklist","content":{}}
{"type":"ACTIVITY_DELTA","messageId":"m","activityType":"checklist","patch":[]}
{"type":"REASONING_START","messageId":"r"}
{"type":"REASONING_END","messageId":"r"}
{"type":"REASONING_MESSAGE_START","messageId":"r","role":"reasoning"}
{"type":"REASONING_MESSAGE_CONTENT","messageId":"r","delta":"d"}
{"type":"REASONING_MESSAGE_END","messageId":"r"}
{"type":"REASONING_MESSAGE_CHUNK"}
{"type":"REASONING_ENCRYPTED_VALUE","entityId":"e","subtype":"message","encryptedValue":"AAAA"}
{"type":"RAW","event":{"k":1},"source":"acme"}
{"type":"CUSTOM","name":"predictive_state","value":{"x":1}}
```

> Two payloads worth re-reading against source before you ship: `STATE_DELTA` (`delta` vs `patches` field name, and the RFC-6902 op shape — `state_delta_basic.jsonl` needs a **non-empty** delta, so confirm the op object shape against `StateDeltaEvent.toJson()` / `json_patch_op.dart`) and `TOOL_CALL_ARGS` (the `delta` value is a *JSON-string fragment*, note the escaped quotes). [Source: full_event_sweep.jsonl; lib/src/event/*_events.dart toJson]

### The 28 registered wire types (the coverage contract)
The frozen set the Task-6 coverage test asserts against (the union of `synthesized/` event types must equal this exactly):

`RUN_STARTED`, `RUN_FINISHED`, `RUN_ERROR`, `STEP_STARTED`, `STEP_FINISHED`, `TEXT_MESSAGE_START`, `TEXT_MESSAGE_CONTENT`, `TEXT_MESSAGE_END`, `TEXT_MESSAGE_CHUNK`, `TOOL_CALL_START`, `TOOL_CALL_ARGS`, `TOOL_CALL_END`, `TOOL_CALL_RESULT`, `TOOL_CALL_CHUNK`, `STATE_SNAPSHOT`, `STATE_DELTA`, `MESSAGES_SNAPSHOT`, `ACTIVITY_SNAPSHOT`, `ACTIVITY_DELTA`, `REASONING_START`, `REASONING_END`, `REASONING_MESSAGE_START`, `REASONING_MESSAGE_CONTENT`, `REASONING_MESSAGE_END`, `REASONING_MESSAGE_CHUNK`, `REASONING_ENCRYPTED_VALUE`, `RAW`, `CUSTOM`. [Source: full_event_sweep.jsonl; eventTypeRegistry (internal — `event_deserializer.dart`)]

`all_event_types.jsonl` carries all 28; the six scenarios then add realistic multi-event flows (and re-cover the common types). Coverage is satisfied by the union — you do **not** need 28 separate one-event files.

### What the test can and cannot assert (RESOLVED — codec is internal)
The public barrel `package:koel_core/koel_core.dart` **does not export** `deserializeAgUiEvent` or `eventTypeRegistry` — the barrel comment is explicit: *"The wire-side deserializer (event_deserializer.dart) stays internal — consumers receive typed events from the stream"* (koel_core.dart :30-33). `koel_test` must import only the public barrel (dog-fooding the 1.x surface, per 2-15 / 3-1). Therefore:
- **CAN assert** (structural, no codec): directory shape; `_session` header presence + required fields; every event line is `{type, timestamp, payload}` with `payload['type'] == type`; `timestamp` parses; full 28-type coverage against a hard-coded frozen set; well-formed JSONL.
- **CANNOT assert** here: that a `payload` decodes to a specific typed `AgUiEvent`, or that it replays correctly through the pipeline. That semantic validation is **Story 3.3's** job — and 3.3 will have to decide how `FixtureLoader` reaches deserialization (a new public `koel_core` API, or some other seam). **Do not pre-solve 3.3's codec-access problem in this story.** The byte-shape-identical-to-`full_event_sweep` discipline (above) is what guarantees your payloads are *actually* decodable when 3.3 arrives. [Source: koel_core.dart :30-33; 3-1 barrel-discipline note]

### The pubspec "asset" AC — already satisfied, change nothing (RESOLVED)
AC3 offers two arms: `flutter.assets:` *(Flutter packages)* **OR** `package:` URI resolution *(Dart packages)*. `koel_test` is a **Dart package** (no `flutter:` section, no Flutter SDK dep). For a Dart package, everything under `lib/` is (a) shipped in the published tarball automatically and (b) addressable as `package:koel_test/src/fixtures/...` — which is precisely the second arm. **The AC is satisfied by placing the fixtures under `lib/src/fixtures/` (Task 1); no pubspec edit is required.** Adding a `flutter.assets:` stanza is the **wrong** arm and would force a Flutter SDK dependency onto a framework-free package — a regression. D8 confirms the mechanism: *"FixtureLoader reads via `package:` asset URI"* (:381). [Source: AC3; D8 :371-383; pubspec.yaml]

### Determinism (no clock, no RNG)
These are static authored files. Every `timestamp`, `captured`, `threadId`, `runId`, `messageId`, `toolCallId` is a **fixed literal you type**. No `DateTime.now()`, no `Random` — the fixtures must be byte-identical across machines and runs so 3.3/3.5 tests can assert on them (flakiness is a bug, convention §6). This mirrors the same discipline Story 3.1's `MockAgentBuilder` enforced (counter-based ids, fixed defaults). [Source: convention §6 "no flaky tests"; 3-1 §"Builder ID determinism"]

### Self-consistency (so 3.3/3.5 replay cleanly)
Each fixture is replayed verbatim by `MockAgent.fromFixture` (Story 3.3) through the real pipeline. For the reducer (Story 2.12) and verify stage (Story 2.11) to produce well-formed `ChatState`:
- The run bracket (`RUN_STARTED`/`RUN_FINISHED`) shares one `threadId`/`runId`, equal to the `_session` header's pair.
- `TEXT_MESSAGE_*` triples share one **non-empty** `messageId` (verify stage drops empty-`messageId` text events — 3-1 trap #2).
- `TOOL_CALL_*` events for one call share one `toolCallId`.
- `error_path` / `cancellation` deliberately omit `RUN_FINISHED` (negative / truncated paths) — that is intentional, not a coherence bug. [Source: pipeline/verify_stage.dart:84-103; chat_state_reducer (Story 2.12); 3-1 §"Verbatim replay"]

### Out of scope — do NOT build these (RESOLVED)
- **`FixtureLoader`, `MockAgent.fromFixture(name)`, the typed `FixtureSession`** — **Story 3.3**. This story produces files; 3.3 reads them. Do not write a loader, do not add `fromFixture`. [Source: epic-3 3.3 :54-75]
- **Any `flutter:`/`flutter.assets:` stanza or Flutter SDK dependency** — wrong arm of AC3 for a Dart package (§"The pubspec 'asset' AC"). [Source: AC3]
- **Changing `publish_to: none`** — every monorepo package is `publish_to: none` until Epic 9 Story 9.9 (lock-step publish). AC3's "published tarball" is about the bundling *mechanism*, not publishing now. [Source: all packages' pubspecs; epic-9 9.9]
- **Real backend captures in `dojo/`/`agno/`/`langgraph/`/`copilotkit_runtime/`** — Stories 5.3 / 5.6 / 5.9. Only `.placeholder` files here. [Source: AC4; epic-5]
- **`ConformanceRunner`, `CONFORMANCE.md`, `tool/capture_fixtures.dart`, `ToolHandlerTestHarness`** — Stories 3.4 / 3.5. [Source: epic-3]
- **`koel_test` package-finalization gates** (member `analysis_options.yaml` doc gate, coverage-threshold) — **Story 3.5** (epic-sealing). 3.2 needs only `analyze`/`test`/`format:check` green. [Source: epic-3 3.5; 3-1 Task 6]
- **Any `koel_core` change** — 3.2 is additive in `koel_test` only. [Source: §"Files you will touch"]

### Files you will touch
| Path | Action | Note |
|------|--------|------|
| `packages/koel_test/lib/src/fixtures/synthesized/text_only_run.jsonl` | **NEW** | Core scenario (Task 3). |
| `packages/koel_test/lib/src/fixtures/synthesized/tool_call_basic.jsonl` | **NEW** | Core scenario (Task 3). |
| `packages/koel_test/lib/src/fixtures/synthesized/state_delta_basic.jsonl` | **NEW** | Core scenario, **non-empty** delta (Task 3). |
| `packages/koel_test/lib/src/fixtures/synthesized/reasoning_with_encrypted_value.jsonl` | **NEW** | Core scenario, F-A9 (Task 3). |
| `packages/koel_test/lib/src/fixtures/synthesized/error_path.jsonl` | **NEW** | Core scenario, in-band `RUN_ERROR`, no `RUN_FINISHED` (Task 3). |
| `packages/koel_test/lib/src/fixtures/synthesized/cancellation.jsonl` | **NEW** | Core scenario, truncated run (Task 3). |
| `packages/koel_test/lib/src/fixtures/synthesized/all_event_types.jsonl` | **NEW** | 28-type coverage sweep (Task 3). |
| `packages/koel_test/lib/src/fixtures/dojo/.placeholder` | **NEW** | Names Epic 5 Story 5.9 (Task 4). |
| `packages/koel_test/lib/src/fixtures/agno/.placeholder` | **NEW** | Names Epic 5 Story 5.3 (Task 4). |
| `packages/koel_test/lib/src/fixtures/langgraph/.placeholder` | **NEW** | Names Epic 5 Story 5.6 (Task 4). |
| `packages/koel_test/lib/src/fixtures/copilotkit_runtime/.placeholder` | **NEW** | Names Epic 5 Story 5.9 (Task 4). |
| `packages/koel_test/test/fixtures_test.dart` | **NEW** | Structural validation, AC1+AC2+coverage (Task 6). |

**Do NOT touch:** any `packages/koel_core/**`; any other package; `packages/koel_test/pubspec.yaml` (no asset stanza needed — §"The pubspec 'asset' AC"); `packages/koel_test/lib/koel_test.dart` barrel (no new public symbol — fixtures are data, the loader is 3.3); `koel_test`'s `README.md`/`CHANGELOG.md`/`LICENSE`; the root `pubspec.yaml` melos scripts.

### Library / framework requirements
- **No new dependencies.** The test uses `dart:io` (`File`/`Directory`) + `dart:convert` (`jsonDecode`/`jsonEncode`) + `package:test` (already a dev-dep from 3.1). No `freezed`/`build_runner` (no codegen — no Dart type declared). [Source: koel_test/pubspec.yaml; 3-1 Task 1]
- **`package:test` only** for the test (convention §6). [Source: architecture §6 :654-661]
- **The fixtures themselves consume no Dart API** — they are wire-format JSON whose shapes mirror `koel_core`'s event `toJson()` output, proven by `full_event_sweep.jsonl`. [Source: §"The canonical wire reference"]

### Project Structure Notes
- `packages/koel_test/lib/src/fixtures/` is the architecture-pinned location (architecture :968 + tree :969-977; D8 :373). Fixtures live under `lib/` precisely so they ship in the Dart-package tarball and resolve via `package:` URI. [Source: architecture :958-977; D8]
- The backend-dir names (`dojo/`, `agno/`, `langgraph/`, `copilotkit_runtime/`) match the architecture tree exactly and the F-C* feature map's "captures fixtures into `koel_test/lib/src/fixtures/<backend>/`" (:1004). [Source: architecture :969-977, :1004]
- `synthesized/` is the new subdir for hand-authored fixtures (FR-G1 / SC-1 "event types no backend emits today use hand-synthesized fixtures with `synthesized: true`"). [Source: FR-G1 :187; SC-1 :63]
- `test/fixtures_test.dart` is `koel_test`'s second test file (after 3.1's `mock_agent_test.dart`); the package's `test/` dir already exists. [Source: 3-1 File List]

### Previous Story Intelligence
- **3.1 (`MockAgent`)** — established that `koel_test` imports the **public barrel** `package:koel_core/koel_core.dart` (never `src/`), that determinism is mandatory (counter-based ids, no clock/RNG), and that `messageId` must be non-empty (verify stage drops empties). All three carry directly into authoring these fixtures. 3.1 also confirmed the `test/` dir + `melos run test` wiring works for `koel_test`. [Source: 3-1 §"Builder ID determinism", §"Verbatim replay", File List]
- **2.8 (full event sweep)** — created `full_event_sweep.jsonl` + its round-trip test. That file is this story's wire-format ground truth (one proven line per type). The wrapping into `{type, timestamp, payload}` is the only transform. [Source: full_event_sweep_test.dart; reducer_bench.dart:44]
- **2.12 (`ChatState` reducer)** / **2.11 (`verifyStage`)** — define what "self-consistent fixture" means (keyed by `messageId`/`toolCallId`, run-bracket phase tracking, empty-`messageId` drop). The §"Self-consistency" rules above come from these. [Source: chat_state_reducer.dart; verify_stage.dart:84-103]

### Git Intelligence Summary
Recent commits open Epic 3: `feat(story-3.1): MockAgent foundation — programmatic builder + fromEvents` @ `8c26147` (current HEAD / this story's baseline). 3.2 is the **first commit to add data files under `koel_test/lib/src/fixtures/`** and the first `.jsonl` assets the package ships. Expected footprint: 7 new `.jsonl` files under `synthesized/`, 4 `.placeholder` files, 1 new test file. **Zero `koel_core` change, zero new dependency, zero pubspec edit, zero new public Dart symbol.** Suggested commit: `feat(story-3.2): synthesized fixture set + backend-organized storage layout`. [Source: git log 8c26147; epic-3 3.2]

### Latest Tech Information
- **JSON Lines (JSONL/NDJSON)** — one JSON value per physical line, `\n`-separated, no enclosing array. Read with `File(...).readAsLinesSync()` (the proven pattern in `full_event_sweep_test.dart`). Author with a final newline at EOF or not — `readAsLinesSync` filters blanks; the test guards against accidental blank lines anyway. [Source: full_event_sweep_test.dart:14-17]
- **Dart package asset addressing** — files under `lib/` of a pub package are reachable from another package as `package:<name>/<path-under-lib>` and are included in `pub publish` tarballs by default; nothing under `lib/` is excluded unless `.pubignore`/`.gitignore` lists it (koel_test's `.gitignore` excludes only `.dart_tool/`, `pubspec.lock`, `doc/api/` — fixtures are safe). [Source: koel_test/.gitignore; D8 :381]
- **ISO-8601 timestamps** — `DateTime.parse` accepts `2026-05-26T00:00:00.000Z`; use UTC (`Z`) + millis for unambiguous, deterministic literals. [Source: AC2; dart:core DateTime.parse]

### References
- [epic-3 Story 3.2 spec + ACs; 3.1 (MockAgent) / 3.3 (FixtureLoader, fromFixture) / 3.4 (harness) / 3.5 (conformance, coverage gate) scope fences](../planning-artifacts/epics/epic-3-test-harness-conformance-koeltest.md)
- [epic-5 Story 5.3 / 5.6 / 5.9 — the stories that capture real fixtures into agno/ langgraph/ copilotkit_runtime/ + dojo/](../planning-artifacts/epics/epic-5-backend-bridges-koelagno-koellanggraph-koelruntime.md)
- [Addendum C.4 :553-563 — the `_session` header + `{type, timestamp, payload}` JSONL trace format (F-F6)](../planning-artifacts/prds/prd-koel-2026-05-27/addendum.md)
- [PRD FR-G1 :187 (captured + synthesized fixtures, `synthesized: true` marker); SC-1 :63 (conformance, every event type ≥1 fixture); FR-G2 :188 (MockAgent.fromFixture — Story 3.3)](../planning-artifacts/prds/prd-koel-2026-05-27/prd.md)
- [architecture.md D8 :371-383 (fixture bundling under lib/src/fixtures/, package: URI); :958-977 (koel_test layout tree, backend dirs); :1004 (F-C* captures into fixtures/<backend>/)](../planning-artifacts/architecture.md)
- [koel_core/test/event/full_event_sweep.jsonl — the 28-line canonical wire-format reference (copy payloads from here)](../../packages/koel_core/test/event/full_event_sweep.jsonl)
- [koel_core/test/event/full_event_sweep_test.dart:13-17 — the File('...')-from-package-root fixture-read pattern + round-trip proof](../../packages/koel_core/test/event/full_event_sweep_test.dart)
- [koel_core/lib/koel_core.dart :30-33 — the barrel does NOT export the wire deserializer (why this story's test is structural-only)](../../packages/koel_core/lib/koel_core.dart)
- [koel_test/pubspec.yaml — pure Dart package, no flutter dep (why no flutter.assets stanza); publish_to: none (don't change)](../../packages/koel_test/pubspec.yaml)
- [3-1-mock-agent-foundation.md — determinism, verbatim replay, non-empty messageId, barrel discipline carried into fixture authoring](3-1-mock-agent-foundation.md)

### Design decisions (RESOLVED — AC/architecture-forced, not open)
Baked in so the dev has zero ambiguity. No confirmation gate.
1. **Event-line format is `{type, timestamp, payload}`** where `payload` is the full wire JSON (including its own `type`), and top-level `type` mirrors `payload.type`. Matches Addendum C.4; 3.3's loader reads `line['payload']`.
2. **Payloads are copied byte-shape-identical from `full_event_sweep.jsonl`** (the only codec-proven wire JSON). Adapt values, never field names.
3. **`_session` header values are fixed literals:** `koelVersion: "0.0.1"`, `adapter: "synthesized"`, `captured: "2026-05-26T00:00:00.000Z"`, `synthesized: true`, plus per-fixture `threadId`/`runId` matching that file's run bracket.
4. **Coverage = the union of all `synthesized/` event types equals the 28 registered wire types**, guaranteed by `all_event_types.jsonl` (the 28-line sweep) + the six scenarios. Not 28 separate files.
5. **No pubspec change.** `koel_test` is a pure Dart package → AC3's `package:` URI arm is satisfied by `lib/src/fixtures/` placement; **no `flutter.assets:` stanza, no Flutter dep.** `publish_to: none` unchanged.
6. **The test is structural-only** — the wire codec is internal/unexported, so it validates JSON shape + header + coverage, never `payload → AgUiEvent` decoding (that's 3.3). Coverage asserts against a hard-coded frozen 28-type set.
7. **Determinism — no `DateTime.now()`/`Random`.** Fixed timestamps (monotonic +100 ms per line from `2026-05-26T00:00:00.000Z`), fixed ids.
8. **The four backend dirs carry only `.placeholder` files** naming their Epic 5 populating story (agno→5.3, langgraph→5.6, copilotkit_runtime+dojo→5.9). No real captures.
9. **Six core scenarios are coherent runs** (run bracket shared ids, paired message/tool ids); `error_path` ends on `RUN_ERROR` and `cancellation` is a truncated prefix — both deliberately omit `RUN_FINISHED`.
10. **Package-finalization gates (doc/coverage) are Story 3.5, not 3.2.** 3.2 needs only `analyze`/`test`/`format:check` green.

## Dev Agent Record

### Agent Model Used

claude-opus-4-8 (Opus 4.8, 1M context) via `/bmad-dev-story`; Dart test produced under the `agent-flutter-engineer` specialist (implement mode), per CLAUDE.md.

### Debug Log References

- `dart test test/fixtures_test.dart` — RED first (7 failures: `PathNotFoundException` on `lib/src/fixtures/synthesized/`, missing dirs/files) → GREEN after authoring fixtures (7/7 passed).
- **Adversarial wire-correctness check (throwaway, not shipped):** a temporary `koel_core/test/_tmp_fixture_verify_test.dart` (legal `src/` import inside its own package) read every synthesized fixture and ran `deserializeAgUiEvent(payload)` through the **real internal codec** — **58/58 payloads decoded to typed, non-`Unknown` events**. The shipped `fixtures_test.dart` stays structural-only (the codec is unexported from `koel_core`'s public barrel — trap #2); this throwaway proved the `payload` shapes are genuinely wire-correct, then was deleted.
- `melos run analyze` → all 11 packages "No issues found!".
- `dart test` (koel_test) → 23/23 passed (16 `mock_agent_test` + 7 `fixtures_test`); `melos run test` → green workspace-wide (koel_core 572, koel_test 23, koel_lints 5; scaffolds tolerated).
- `melos run format:check` → clean after `melos run format` rewrapped the new `fixtures_test.dart` (long const-set / chained-iterable lines).

### Completion Notes List

- **Payloads copied byte-shape-identical from `koel_core/test/event/full_event_sweep.jsonl`** (the only codec-proven wire JSON) and wrapped in the `{type, timestamp, payload}` trace envelope per Addendum C.4. The throwaway codec check (above) confirmed all 58 decode — the fixtures are not just structurally valid JSON, they are *semantically* decodable wire format.
- **`STATE_DELTA` op shape source-verified** before authoring `state_delta_basic.jsonl`: wire key is `delta` (a JSON array of RFC-6902 ops), Dart field is `patches` (`state_events.dart:54,:58-60`); the op object is `{"op":"replace","path":"/count","value":2}` (`json_patch_op.dart:107-111`). Used a **non-empty** delta so 3.3/3.5 can assert a downstream `ChatState` mutation (the sweep's `delta:[]` is empty).
- **Determinism honoured** — every `timestamp`/`captured`/`threadId`/`runId`/`messageId`/`toolCallId` is a fixed literal (no `DateTime.now()`/`Random`). Timestamps are monotonic +100 ms from `2026-05-26T00:00:00.000Z` (seconds roll over correctly in `all_event_types.jsonl` at line 11: `…01.000Z`).
- **Self-consistency** — each of the six scenarios shares one `threadId`/`runId` across its run bracket (matching the `_session` header), pairs its `messageId`/`toolCallId` sub-sequences, and uses non-empty ids (verify-stage drop guard). `error_path` terminates on in-band `RUN_ERROR` and `cancellation` is a truncated prefix — both deliberately omit `RUN_FINISHED`.
- **Coverage** — `all_event_types.jsonl` (28 lines, one per registered wire type) + the six scenarios make the union of synthesized event types exactly the 28-type registry; the coverage test asserts this against a frozen `const Set` (registry is internal, so hard-coded — fails loudly naming any missing/unexpected type).
- **No pubspec change (AC3 satisfied by placement).** `koel_test` is a pure Dart package → AC3's `package:` URI arm; `lib/src/fixtures/` files ship in the tarball automatically. **No `flutter:`/`flutter.assets:` stanza added, no Flutter dep, `publish_to: none` untouched.**
- **Scope honoured** — no `FixtureLoader`, no `MockAgent.fromFixture`, no `ConformanceRunner`, no barrel export (fixtures are data — the loader is Story 3.3), no package-finalization gates (Story 3.5). **Zero `koel_core` change, zero new dependency, zero new public Dart symbol.**

### File List

- `packages/koel_test/lib/src/fixtures/synthesized/text_only_run.jsonl` — NEW: core scenario (happy text path).
- `packages/koel_test/lib/src/fixtures/synthesized/tool_call_basic.jsonl` — NEW: core scenario (tool call lifecycle).
- `packages/koel_test/lib/src/fixtures/synthesized/state_delta_basic.jsonl` — NEW: core scenario (snapshot + non-empty RFC-6902 delta).
- `packages/koel_test/lib/src/fixtures/synthesized/reasoning_with_encrypted_value.jsonl` — NEW: core scenario (F-A9 encryptedValue round-trip).
- `packages/koel_test/lib/src/fixtures/synthesized/error_path.jsonl` — NEW: core scenario (in-band `RUN_ERROR`, no `RUN_FINISHED`).
- `packages/koel_test/lib/src/fixtures/synthesized/cancellation.jsonl` — NEW: core scenario (truncated run, no terminal event).
- `packages/koel_test/lib/src/fixtures/synthesized/all_event_types.jsonl` — NEW: 28-type coverage sweep (payloads verbatim from full_event_sweep.jsonl).
- `packages/koel_test/lib/src/fixtures/dojo/.placeholder` — NEW: names Epic 5 Story 5.9 (dojo fallback).
- `packages/koel_test/lib/src/fixtures/agno/.placeholder` — NEW: names Epic 5 Story 5.3.
- `packages/koel_test/lib/src/fixtures/langgraph/.placeholder` — NEW: names Epic 5 Story 5.6.
- `packages/koel_test/lib/src/fixtures/copilotkit_runtime/.placeholder` — NEW: names Epic 5 Story 5.9.
- `packages/koel_test/test/fixtures_test.dart` — NEW: structural validation (layout, `_session` header, `{type,timestamp,payload}` shape, 28-type coverage, well-formed JSONL) — 7 tests.

## Change Log

| Date       | Change                                                                                          |
|------------|-------------------------------------------------------------------------------------------------|
| 2026-05-31 | Implemented Story 3.2 — synthesized fixture set (6 core scenarios + 28-type coverage sweep) under a backend-organized layout, with `.placeholder`s naming the Epic 5 capture stories and a structural-validation test. All ACs satisfied; analyze/test/format gates green; all 58 payloads verified decodable through the real codec. No `koel_core`/pubspec/barrel change. Status → review. |
