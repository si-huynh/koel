---
title: 'Story 2-16 — RunAgentInput.context as List<Context> (AG-UI conformance fix)'
type: 'bugfix'
created: '2026-06-06'
status: 'done'
baseline_commit: '9eefe4ab6204e375e7b91a7cb1caea754a3d4a3a'
context: ['{project-root}/_bmad-output/planning-artifacts/sprint-change-proposal-2026-06-06.md']
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** `RunAgentInput.context` is modeled as `Map<String, dynamic>` and the wire codec emits it verbatim, so an empty input serializes `"context": {}`. AG-UI defines `context` as `List<Context>` (each `Context = {description, value}`); a spec-compliant backend 422-rejects every koel request (live DEV `/agno-chat`: `{}` → 422 `list_type`, `[]` → 200). This is the sole outbound conformance defect and blocks koel talking to any conformant backend.

**Approach:** Introduce a first-class typed `Context` value object (freezed + json_serializable, mirroring `ToolDefinition`), retype `RunAgentInput.context` to `List<Context>` defaulting to `[]`, and emit it through the codec as a list of `toJson()` maps. Empty default fixes the 422 immediately; the typed element keeps the AG-UI surface first-class.

## Boundaries & Constraints

**Always:**
- `Context` mirrors `ToolDefinition` exactly: `@freezed` + `part '*.g.dart'` + `fromJson` factory + generated `toJson`; required `String description`, `String value`; deep-equality + `copyWith`.
- Codec emits `context` as a JSON **list** (`[]` when empty, never `{}`).
- `Context` is exported from the `koel_core` barrel next to `Message`/`ToolDefinition` (public 1.x contract).

**Ask First:**
- If the actual `ag-ui-protocol==0.1.10` `Context` field set differs from `{description, value}` (e.g. an optional/extra field) when verified at implementation — HALT before deviating from parity.

**Never:**
- No inbound/decode change (no `RunAgentInput.fromJson` — it ships freezed-without-json by design; codec stays encode-only).
- No transport/SSE change; no `List<Map<String,dynamic>>` (stringly-typed) shortcut.
- Do not invent a `RunAgentInput.context` row in CONFORMANCE.md — it has none (inbound-event-only); add a short outbound note instead.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Empty context (common path) | `RunAgentInput(threadId, runId)` | `encodeRunAgentInput(...)['context'] == []` (a `List`) | N/A |
| Populated context | `context: [Context(description: 'page', value: 'home')]` | `['context'] == [{'description':'page','value':'home'}]` | N/A |
| Round-trip | `Context.fromJson(c.toJson())` | structurally `==` original | N/A |
| Deep equality | two inputs, equal `List<Context>` | `==` and equal `hashCode` | N/A |

</frozen-after-approval>

## Code Map

- `packages/koel_core/lib/src/context/context.dart` -- NEW typed `Context` value object (mirror `tool_definition.dart`).
- `packages/koel_core/lib/src/tool/tool_definition.dart` -- precedent to copy (freezed + json_serializable shape).
- `packages/koel_core/lib/src/input/run_agent_input.dart` -- field retype; add `../context/context.dart` import.
- `packages/koel_core/lib/koel_core.dart` -- barrel; add `Context` export under the Input/message/tool group.
- `packages/koel_http/lib/src/wire/run_agent_input_codec.dart` -- codec line 27 → list-of-`toJson()`.
- `packages/koel_core/test/input/run_agent_input_test.dart` -- switch `context` fixtures to `List<Context>`.
- `packages/koel_core/test/context/context_test.dart` -- NEW round-trip + deep-equality test.
- `packages/koel_http/test/wire/run_agent_input_codec_test.dart` -- NEW codec test (none exists today; 422 regression guard).
- `packages/koel_core/CONFORMANCE.md` -- add short outbound note (not a row edit).
- `_bmad-output/implementation-artifacts/sprint-status.yaml` -- reopen epic-2, register 2-16.

## Tasks & Acceptance

**Execution:**
- [x] `packages/koel_core/lib/src/context/context.dart` -- create `@freezed Context {required String description, required String value}` with `part 'context.freezed.dart'`, `part 'context.g.dart'`, and `Context.fromJson`; dartdoc the AG-UI role. Verify field set vs ag-ui-protocol 0.1.10 (Ask First if it differs).
- [x] `packages/koel_core/lib/src/input/run_agent_input.dart` -- import `../context/context.dart`; change `@Default(<String, dynamic>{}) Map<String, dynamic> context,` → `@Default(<Context>[]) List<Context> context,`. (Class dartdoc already lists `[context]` as deep-compared — no wording change.)
- [x] `packages/koel_core/lib/koel_core.dart` -- add `export 'src/context/context.dart';` beside the `run_agent_input`/`message`/`tool_definition` exports.
- [x] `packages/koel_http/lib/src/wire/run_agent_input_codec.dart` -- `'context': input.context,` → `'context': [for (final c in input.context) c.toJson()],`.
- [x] run `melos run build` -- regenerate `context.freezed.dart`, `context.g.dart`, and `run_agent_input.freezed.dart`.
- [x] `packages/koel_core/test/context/context_test.dart` -- create: const construction, deep equality + `copyWith`, `fromJson(toJson())` round-trip (mirror `tool_definition_test.dart`).
- [x] `packages/koel_core/test/input/run_agent_input_test.dart` -- replace `context: const {'c': true}` with `context: const [Context(description: 'd', value: 'v')]`; fix the empty-default assertion (still `isEmpty`); keep deep-equality/copyWith assertions.
- [x] `packages/koel_http/test/wire/run_agent_input_codec_test.dart` -- create (RED first): assert empty input → `['context']` is `[]` (a `List`), and a populated `Context` serializes to `[{'description':..,'value':..}]`.
- [x] `packages/koel_core/CONFORMANCE.md` -- add a brief "Outbound request body" note: `RunAgentInput.context` is `List<Context>` (`Context = {description, value}`), conformant with ag-ui-protocol 0.1.10; cite SCP-2026-06-06.
- [x] `_bmad-output/implementation-artifacts/sprint-status.yaml` -- add `2-16-fix-runagentinput-context-list: <status>` under epic-2; flip `epic-2: done → in-progress` (→ `done` when 2-16 closes).

**Acceptance Criteria:**
- Given a `koel_core` consumer, when it imports the `koel_core` barrel, then `Context` is reachable without a `src/` path.
- Given a `RunAgentInput` carrying `List<Context>`, when two equal inputs are built, then they are `==` with equal `hashCode` (DeepCollectionEquality over `context`, parity with `messages`/`tools`).
- Given the full change, when `melos run build`, `melos run analyze`, `melos run test`, and `melos run format:check` run, then all are green with no codegen drift.

## Design Notes

`Context` is a 1:1 copy of the `ToolDefinition` shape (freezed + json_serializable) — required-`String` fields, generated `toJson`/`fromJson`. `RunAgentInput` stays freezed-**without**-json (serialization lives only in the codec), so the field change adds no `.g.dart` to `run_agent_input.dart`.

FYI (parity-decided, not a blocker): `Context` is a generic name on the public barrel one-way door; AG-UI parity names it `Context`, so consumers needing disambiguation use `import ... show`/prefixes. Not renamed.

## Verification

**Commands:**
- `melos run build` -- expected: regenerates freezed/json for `Context` + `RunAgentInput`; clean tree (no drift) after.
- `melos run analyze` -- expected: 0 issues (NFR-13 gate).
- `melos run test` -- expected: koel_core + koel_http green, including the new context + codec tests.
- `melos run format:check` -- expected: pass (hand-written Dart formatted).

**Manual checks:**
- Live re-verify (optional, post-merge): koel's real `encodeRunAgentInput` body (no spike shim) streams **200** from DEV `/agno-chat`.

## Suggested Review Order

**The contract change (start here)**

- The whole fix in one line: `context` is now a typed list, defaulted empty.
  [`run_agent_input.dart:38`](../../packages/koel_core/lib/src/input/run_agent_input.dart#L38)

- The new value type — a 1:1 mirror of `ToolDefinition` (freezed + json_serializable, required Strings).
  [`context.dart:13`](../../packages/koel_core/lib/src/context/context.dart#L13)

- One-way-door surface: `Context` joins the public barrel.
  [`koel_core.dart:61`](../../packages/koel_core/lib/koel_core.dart#L61)

**The wire fix (the actual 422)**

- Empty input now emits `[]`, never `{}` — the single line that unblocks every conformant backend.
  [`run_agent_input_codec.dart:27`](../../packages/koel_http/lib/src/wire/run_agent_input_codec.dart#L27)

**Tests & docs (peripherals)**

- Regression guard: asserts `context` serializes as a List (empty → `[]`).
  [`run_agent_input_codec_test.dart:7`](../../packages/koel_http/test/wire/run_agent_input_codec_test.dart#L7)

- `Context` round-trip + deep-equality, mirroring `tool_definition_test.dart`.
  [`context_test.dart:27`](../../packages/koel_core/test/context/context_test.dart#L27)

- Existing input test switched to `List<Context>` fixtures.
  [`run_agent_input_test.dart:42`](../../packages/koel_core/test/input/run_agent_input_test.dart#L42)

- Outbound-conformance note (added, not a row edit — the doc grades inbound events only).
  [`CONFORMANCE.md:43`](../../packages/koel_core/CONFORMANCE.md#L43)
