# Sprint Change Proposal — RunAgentInput.context must be a List (SCP-2026-06-06)

- **Date:** 2026-06-06
- **Author:** Amelia (Developer) + Si Huynh (Project Lead)
- **Trigger:** Downstream koel consumer (TPS mobile, story AI.1 koel↔/agno-chat spike) hit **HTTP 422** on the very first real run — *"koel gửi `context` sai kiểu so với chuẩn AG-UI."*
- **Evidence:** Live DEV `/agno-chat` (agno 2.4.0 + ag-ui-protocol 0.1.10) returned `422 {"type":"list_type","loc":["body","context"],"msg":"Input should be a valid list","input":{}}`. Same body with `"context": []` streamed **200** (full AG-UI sequence incl. `detected_tickers`). Proof + audits in `…/tps/mobile/_bmad-output/planning-artifacts/ai-1-spike-findings.md` (§3.4, §5).
- **Scope class:** **Minor–Moderate** (one contract field type + its codec; pre-v1.0.0, no published API; spans Epic 2 model + Epic 4 codec).
- **Decision:** **Direct Adjustment** — model `RunAgentInput.context` as `List<Context>` with a new typed `Context {description, value}` value object (AG-UI-faithful). **Home: reopen Epic 2 with corrective Story 2-16** (folds the trivial Epic-4 codec line).

## 1. Issue Summary

`RunAgentInput.context` is modeled as `Map<String, dynamic>` (`run_agent_input.dart:37`,
`@Default(<String, dynamic>{})`) and the wire codec emits it verbatim
(`run_agent_input_codec.dart:27` → `'context': input.context`), so an empty input
serializes `"context": {}`. The AG-UI protocol defines `RunAgentInput.context` as a
**`List<Context>`** (each `Context = {description, value}`); `ag_ui.core`'s Pydantic
model validates it as a list. A spec-compliant backend therefore **422-rejects every
koel request** — koel cannot talk to any conformant AG-UI backend until this is fixed.

This is a **protocol-conformance defect in shipped contract code** (Epic 2 `done`),
surfaced only when the first external consumer pointed koel at a real backend. It is
**the sole outbound deviation** — a two-axis audit (2026-06-06) found everything else
conformant.

## 2. Impact Analysis

- **Conformance audit (2026-06-06, koel‑wide):**
  - *Outbound:* **1 blocker** — `context` (this defect). `threadId/runId/state/messages/
    tools/forwardedProps` casing ✅, `Message`/`ToolDefinition` shapes ✅, `reasoningEcho`
    extension safe ✅.
  - *Inbound:* **perfect** — all 28 `AgUiEvent` types decode, wire-key remaps
    (`snapshot→state`, `delta→patches`, `event→payload`) intentional, `UnknownAgUiEvent`
    fallback total. **No inbound change needed.**
- **Architecture** — `architecture.md` does not type `context` (lists the field name
  only), so no diagram/decision reversal; add a one-line note that `context` is
  `List<Context>` per AG-UI. No ADR impact.
- **Epic 2 (`done`) — reopen.** `RunAgentInput` (Story 2-1) gains a typed `Context`
  and a `List<Context> context`. Story 2-1's AC line ("carries fields … `context` …")
  is unchanged in *names* but now type-pinned.
- **Epic 4 (`done`) — touched, trivial.** `run_agent_input_codec.dart` context line
  becomes `[for (final c in input.context) c.toJson()]`. No transport/SSE change.
- **Epics 5/6/7 — none.** Backend bridges (agno/langgraph/runtime) build `RunAgentInput`
  but never populate `context` (empty `[]` is the common path); response-side fixtures
  (5-3 agno conformance) are unaffected (request body is not fixtured).
- **`packages/koel_core/CONFORMANCE.md`** — update the `RunAgentInput` row: `context:
  List<Context>` (was implicitly Map). 
- **API break:** `context`'s type changes `Map → List<Context>`. **Pre-v1.0.0, no
  published consumers** → zero deprecation cost. (The TPS mobile spike currently shims
  this via `_SpikeAgnoAgent.encodeBody`; once 2-16 lands, the shim is deleted.)

## 3. Recommended Approach (chosen)

**Direct Adjustment, typed.** Introduce a first-class `Context` value object rather than
`List<Map<String,dynamic>>`, matching koel's "typed AG-UI surface" DNA and the existing
`Message`/`ToolDefinition` precedent (freezed + json_serializable). Empty default `[]`
fixes the 422 immediately; the typed element makes future context-passing first-class.

- **Effort:** small — one new tiny value type + one field type change + one codec line +
  test updates. Mirrors `ToolDefinition` exactly.
- **Risk:** low — additive type, no transport/decode change, no published API; behavior
  verified against live DEV (`[]` → 200).
- **Why typed over `List<Map>`:** AG-UI fidelity, deep-equality parity with the other
  collection fields, and no stringly-typed wire shape leaking into `ChatState`/inputs.

## 4. Detailed Change Proposals

### 4.1 New `Context` value type — `packages/koel_core/lib/src/context/context.dart`
```dart
@freezed
abstract class Context with _$Context {
  const factory Context({
    required String description,
    required String value,
  }) = _Context;
  factory Context.fromJson(Map<String, dynamic> json) => _$ContextFromJson(json);
}
```
> ⚠️ Verify the exact field set against `ag-ui-protocol==0.1.10` `Context` at
> implementation (spec: `{description, value}`). Export from the `koel_core` barrel
> next to `Message`/`ToolDefinition`.

### 4.2 `RunAgentInput.context` type — `run_agent_input.dart:37`
```
OLD:  @Default(<String, dynamic>{}) Map<String, dynamic> context,
NEW:  @Default(<Context>[]) List<Context> context,
```
Update the two dartdoc references (lines 13, 29) — `context` participates in
`DeepCollectionEquality` exactly as `messages`/`tools` (no wording change needed beyond
the type).

### 4.3 Wire codec — `run_agent_input_codec.dart:27`
```
OLD:  'context': input.context,
NEW:  'context': [for (final c in input.context) c.toJson()],
```
Codec dartdoc (line 17) already says context is part of the camelCase body — no change.

### 4.4 Tests
- `koel_core` `test/input/run_agent_input_test.dart` — switch `context` fixtures to
  `List<Context>`; keep deep-equality + copyWith assertions; add a `Context` round-trip.
- New `koel_core` `test/context/context_test.dart` — `toJson`/`fromJson` round-trip.
- `koel_http` codec test — assert `encodeRunAgentInput(...)['context']` is a **List**
  (regression guard for the 422: empty → `[]`, never `{}`).

### 4.5 `packages/koel_core/CONFORMANCE.md`
- `RunAgentInput.context` row → `List<Context>` (`Context = {description, value}`),
  conformant with ag-ui-protocol 0.1.10. Note SCP-2026-06-06 as the source.

### 4.6 sprint-status.yaml
- `epic-2: done → in-progress` (reopen; → done when 2-16 completes).
- Add `2-16-fix-runagentinput-context-list: backlog` (Epic 2; folds the Epic-4 codec
  line + CONFORMANCE doc; ref SCP-2026-06-06).

## 5. Implementation Handoff

**Minor–Moderate scope → DEV (direct).** No PM/Architect replan; pre-v1.0.0 contract fix.

1. Apply 4.5/4.6 doc + status edits; create **Story 2-16** from §4.1–§4.4.
2. `create-story 2-16` → `dev-story` (RED: codec test asserting `context` is a List) →
   `build_runner` (freezed/json for `Context` + `RunAgentInput`) → `melos analyze`/`test`.
3. **Success criteria:**
   - `encodeRunAgentInput` emits `"context": []` for empty input (was `{}`); typed
     `Context` round-trips; all koel gates green.
   - Live re-verify: koel's real body (no shim) streams **200** from DEV `/agno-chat`.
   - Downstream: TPS mobile AI.1 deletes the `_SpikeAgnoAgent` context shim once koel
     ships the fix (note added to `ai-1-spike-findings.md` §3.4 / §10).
4. **Out of scope (recorded, not this SCP):** OI-1 token-expiry can't be observed on DEV
   (BE-AI guest fallback) — a *backend/consumer* matter for TPS AI.8, not koel.
