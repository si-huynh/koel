---
baseline_commit: e51c604b6b80fa39037ea2fe4f8da45c26bb1e12 # feat(story-2.4) — HEAD at story creation
---

# Story 2.5: `RUN_*` + `STEP_*` + `TEXT_MESSAGE_*` event subtypes

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a Flutter/Dart developer,
I want typed event subtypes for the lifecycle and text-message families — `RunStartedEvent`, `RunFinishedEvent`, `RunErrorEvent`, `StepStartedEvent`, `StepFinishedEvent`, `TextMessageStartEvent`, `TextMessageContentEvent`, `TextMessageEndEvent`, `TextMessageChunkEvent` — joined into the sealed `AgUiEvent` union and wired into the deserializer registry,
so that pattern matching on the run lifecycle and streaming text is exhaustive and forward-compat per FR-A7.

**Why this story now.** Story 2.2 shipped the sealed `AgUiEvent` root + `UnknownAgUiEvent` fallback + an **empty** `eventTypeRegistry`; Story 2.3 shipped the `KoelError` union that `RunErrorEvent.error: KoelError` consumes; Story 2.4 shipped `JsonPatchOp` with the hand-rolled, discriminator-keyed freezed-union codec idiom these events reuse. 2.5 is the **first** story to add concrete typed members to the `AgUiEvent` union — it establishes the per-event codec template that Stories 2.6 (`TOOL_CALL_*`/`STATE_*`/`MESSAGES_SNAPSHOT`), 2.7 (`ACTIVITY_*`/`REASONING_*`), and 2.8 (`RAW`/`CUSTOM` + 28-event sweep) replicate. Get the pattern right once, here.

**Scope reality check.** This story ships the **9 event subtypes** (3 RUN, 2 STEP, 4 TEXT_MESSAGE) as freezed-immutable members of the sealed `AgUiEvent` union, their hand-rolled `type`-discriminated `fromJson`/`toJson` codecs, and their registration in `eventTypeRegistry`. It does **NOT** ship: chunk synthesis (the `TEXT_MESSAGE_CHUNK → START/CONTENT/END` expansion is the `chunks` pipeline stage in Story 2.11), verify-stage semantic rules (missing-`messageId` drop, START/END pairing — Story 2.11 / Addendum F.1), the reducer's text-accumulation/phase handling (Story 2.12), the `DefaultErrorClassifier`-driven emission of `RunErrorEvent` from adapters (Story 2.3 shipped the classifier; adapters use it in Epic 5), the remaining 19 event types (2.6–2.8), or the barrel export (frozen until 2.15). `RunErrorEvent` reuses the **already-shipped** `KoelError`/`KoelErrorCode` from Story 2.3 — no new error type.

## Acceptance Criteria

**AC1 — three event files ship the 9 freezed subtypes, joined to the sealed union**
**Given** `koel_core/lib/src/event/run_events.dart`, `step_events.dart`, and `text_message_events.dart`,
**When** I inspect them,
**Then** each file is a `part of 'ag_ui_event.dart'` and defines its family's concrete subclasses of `AgUiEvent` — `run_events.dart`: `RunStartedEvent`, `RunFinishedEvent`, `RunErrorEvent`; `step_events.dart`: `StepStartedEvent`, `StepFinishedEvent`; `text_message_events.dart`: `TextMessageStartEvent`, `TextMessageContentEvent`, `TextMessageEndEvent`, `TextMessageChunkEvent`,
**And** every subtype is freezed-generated (`@freezed abstract class X extends AgUiEvent with _$X` + `const X._() : super();` + `const factory X(...) = _X;`) using the sealed-parent + private-`._()`-ctor idiom proven by `UnknownAgUiEvent` (2.2), `KoelError` (2.3), and `JsonPatchOp` (2.4) — verified by running `build_runner`, not assumed (retro A1),
**And** the field shapes match the AG-UI `release/2026-05-26` wire format per the table in Dev Notes "Wire-format field shapes" (e.g. `RunStartedEvent{threadId, runId, parentRunId?}`, `TextMessageContentEvent{messageId, delta}`, `TextMessageChunkEvent{messageId?, role?, delta?}`),
**And** `RunErrorEvent` carries `final KoelError error` consuming the Story-2.3 `KoelError` type (no new error class),
**And** `ag_ui_event.dart` adds `part 'run_events.dart';`, `part 'step_events.dart';`, `part 'text_message_events.dart';` (plus the shared-codec part per AC2) and the imports `'../error/koel_error.dart'` + `'../error/koel_error_code.dart'` that `RunErrorEvent` needs.

**AC2 — hand-rolled, `type`-discriminated codecs; freezed-only (no `*.g.dart` for events)**
**Given** the codec wiring,
**When** I inspect it,
**Then** each subtype carries a hand-written `Map<String, dynamic> toJson()` whose first entry is its wire discriminator (`'type': 'RUN_STARTED'`, `'TEXT_MESSAGE_CONTENT'`, …) followed by its fields, omitting absent optionals (`if (parentRunId != null) 'parentRunId': parentRunId`),
**And** each subtype's wire→object decode is exposed as a `fromJson` usable as an `AgUiEvent Function(Map<String, dynamic>)` registry value (see Dev Notes "Codec placement: static method vs top-level function" for the freezed-safe form to confirm via build_runner),
**And** **no** `json_serializable` is applied to any event subtype and **no** `*.g.dart` is produced for the event family — the freezed-only posture `KoelError`/`JsonPatchOp` established for union members (json_serializable stays reserved for leaf value types like `Message`/`RunAgentInput`/`ToolDefinition`),
**And** a shared private codec helper (`_requireString` throwing `ProtocolError(protocolMalformed)` on a missing/non-`String` required member, mirroring `JsonPatchOp.fromJson`) lives in one place reused by all three families — `koel_core/lib/src/event/event_codec.dart` as a `part of 'ag_ui_event.dart'`.

**AC3 — `eventTypeRegistry` maps all 9 wire types to their concrete subtype; dispatcher round-trips**
**Given** `koel_core/lib/src/event/event_deserializer.dart`,
**When** I inspect `eventTypeRegistry`,
**Then** it maps exactly these nine wire strings to their decoders: `RUN_STARTED`, `RUN_FINISHED`, `RUN_ERROR`, `STEP_STARTED`, `STEP_FINISHED`, `TEXT_MESSAGE_START`, `TEXT_MESSAGE_CONTENT`, `TEXT_MESSAGE_END`, `TEXT_MESSAGE_CHUNK` (the map is no longer empty),
**And** `deserializeAgUiEvent(wireJson)` produces the correct concrete subtype with all fields populated for each of the nine families given sample wire JSON,
**And** for every sample, `deserializeAgUiEvent(event.toJson())` re-dispatches to the **same** concrete subtype, structurally equal to the original (the `type` discriminator on `toJson` makes the event re-routable — this is what Story 2.8's full-sweep round-trip will rely on).

**AC4 — round-trip + structural-equality tests per subtype; `RunErrorEvent`↔`KoelError` mapping is round-trip-stable**
**Given** the test suite under `koel_core/test/event/`,
**When** I run `dart test test/event/`,
**Then** every one of the nine subtypes has at least one positive deserialization test (wire JSON → typed event, fields asserted) **and** one round-trip test (`X.fromJson(e.toJson())` — or `deserializeAgUiEvent(e.toJson())` — structurally equals `e`, leaning on freezed's generated `==`),
**And** `RunErrorEvent` round-trips cleanly across all three wire shapes — `{message, code:"agentInternal"}` (a `KoelErrorCode` name), `{message}` (no `code`), and `{message, code:"RATE_LIMIT"}` (a non-enum backend string) — per the mapping rule in Dev Notes "RunErrorEvent ↔ KoelError" (decode to `AgentError`, map `code` to `KoelErrorCode` by name with `unknown` fallback, preserve the original wire string in `agentCode`),
**And** a negative test confirms a missing required member (e.g. `TEXT_MESSAGE_START` without `messageId`) throws `ProtocolError(protocolMalformed)` from the Story-2.3 type,
**And** line + branch coverage on the new event sources (excluding generated `ag_ui_event.freezed.dart`) is **≥ 90%** per NFR-12.

**AC5 — repo stays green; codegen deterministic; nothing committed; barrel untouched**
**Given** the workspace after this story lands,
**When** I run the toolchain,
**Then** `cd packages/koel_core && dart run build_runner build` regenerates `ag_ui_event.freezed.dart` (now covering the 9 new subtypes) with **no** new `*.g.dart` for events, and a re-run writes 0 outputs (deterministic; `codegen-drift` green),
**And** `cd packages/koel_core && dart test` passes (existing 241 + the new event tests),
**And** `melos run analyze` exits 0 across all packages including `koel_lints` — with **no** default-less `switch` over `AgUiEvent` introduced into the analyzed tree (`AgUiEvent` **is** in koel_lints' `_sealedNames`; the deserializer uses a `Map` lookup and the codecs read getters — neither is a `switch` over the union; see Dev Notes "koel_lints + AgUiEvent"),
**And** `melos run format:check` exits 0,
**And** `git ls-files '*.freezed.dart' '*.g.dart'` shows nothing staged/tracked, and the barrel `lib/koel_core.dart` is **not** touched (frozen until 2.15).

## Tasks / Subtasks

- [x] **Task 1 — shared event codec helpers + `event_codec.dart` part (AC2)** — red → green → refactor
  - [x] RED: folded into the per-family tests (Tasks 2–4); `_requireString` is library-private so its `ProtocolError(protocolMalformed)` behavior is asserted through each subtype's `fromJson` negative case. Confirmed RED (helpers + types undefined).
  - [x] GREEN: added `koel_core/lib/src/event/event_codec.dart` as `part of 'ag_ui_event.dart';` with `String _requireString(...)` (throws `ProtocolError(protocolMalformed)` on missing/non-String member, mirroring `JsonPatchOp.fromJson`'s `req`) and `KoelErrorCode _koelErrorCodeFromWire(Object? raw)` (name→enum match over `KoelErrorCode.values`, else `unknown`). Added `import '../error/koel_error.dart';` + `import '../error/koel_error_code.dart';` to `ag_ui_event.dart`.
  - [x] REFACTOR: one-line dartdoc on each helper marking it internal codec glue. `build_runner` confirms the helpers compile inside the library.

- [x] **Task 2 — `run_events.dart`: `RunStartedEvent` + `RunFinishedEvent` + `RunErrorEvent` (AC1/AC2/AC4)** — red → green → refactor
  - [x] RED: `test/event/run_events_test.dart` — per subtype: const construction, `isA<AgUiEvent>()`/`isA<X>()`, structural equality (`==` + `hashCode`; differ on any field → `!=`), `copyWith`, `fromJson` with fields asserted, dual round-trip via `X.fromJson(e.toJson())` **and** `deserializeAgUiEvent(e.toJson())`. `RunErrorEvent`: the three AC4 wire shapes each round-trip; `error is AgentError`, `error.code`, `error.agentCode` asserted. Negatives: missing `threadId`/`runId`/`message` → `ProtocolError(protocolMalformed)`. Confirmed RED.
  - [x] GREEN: implemented `RunStartedEvent{threadId, runId, parentRunId?}`, `RunFinishedEvent{threadId, runId, result: Object?}`, `RunErrorEvent{error: KoelError}`. Each has a `static fromJson` + hand-written `toJson` (discriminator first; absent optionals omitted). `RunErrorEvent.fromJson` decodes to `AgentError`; `toJson` emits `code` via the null-aware element `'code': ?code` where `code = error is AgentError ? error.agentCode : error.code.name`. `build_runner` confirms the generated parts satisfy `extends AgUiEvent` (retro A1).
  - [x] REFACTOR: contract-form dartdoc on each subtype — lifecycle role + (for `RunErrorEvent`) the explicit note that adapters **emit** it, the deserializer canonicalizes `{message, code?}` to an `AgentError` ("least-wrong home"), and backend reclassification is the `ErrorClassifier`'s job in Epic 5.

- [x] **Task 3 — `step_events.dart`: `StepStartedEvent` + `StepFinishedEvent` (AC1/AC2/AC4)** — red → green → refactor
  - [x] RED: `test/event/step_events_test.dart` — construction, `isA`, structural equality, `copyWith`, `fromJson` (asserts `stepName`), dual round-trip, missing-`stepName` negative → `ProtocolError(protocolMalformed)`. Confirmed RED.
  - [x] GREEN: `StepStartedEvent{stepName}` (`STEP_STARTED`), `StepFinishedEvent{stepName}` (`STEP_FINISHED`); `fromJson` via `_requireString(json, 'stepName')`; `toJson` emits discriminator + `stepName`. `build_runner`; green.
  - [x] REFACTOR: dartdoc notes `STEP_FINISHED.stepName` must match the prior `STEP_STARTED` — a cross-event invariant enforced by 2.11's verify stage, not here.

- [x] **Task 4 — `text_message_events.dart`: Start/Content/End/Chunk (AC1/AC2/AC4)** — red → green → refactor
  - [x] RED: `test/event/text_message_events_test.dart` — per subtype: construction, `isA`, structural equality, `copyWith`, `fromJson`, dual round-trip. Negatives: missing `messageId` (Start) and missing `delta` (Content) → `ProtocolError`. `TextMessageChunkEvent`: empty `{'type':'TEXT_MESSAGE_CHUNK'}` decodes to all-`null` without throwing and round-trips; partial chunk omits absent optionals. Confirmed RED.
  - [x] GREEN: `TextMessageStartEvent{messageId, role}`, `TextMessageContentEvent{messageId, delta}`, `TextMessageEndEvent{messageId}`, `TextMessageChunkEvent{messageId?, role?, delta?}`. Required decode via `_requireString`; optionals via `json[k] as String?`. `toJson` emits discriminator + present fields (chunk omits null optionals). `build_runner`; green.
  - [x] REFACTOR: dartdoc — Start/Content/End are the canonical long form; `TextMessageChunkEvent` is the convenience shape the `chunks` stage (2.11) expands; 2.5 ships only the typed value, the expansion + "must carry `messageId`" verify rule (Addendum F.1) are 2.11.

- [x] **Task 5 — register all 9 in `eventTypeRegistry` + dispatcher integration tests (AC3/AC5)** — red → green
  - [x] RED: extended `test/event/event_deserializer_test.dart` — `eventTypeRegistry.keys` is exactly the nine wire strings; `deserializeAgUiEvent(sample)` yields the right subtype for each; unknown type still falls back to `UnknownAgUiEvent` (2.2 regression guard). Confirmed RED (stale `isEmpty` assertion failed).
  - [x] GREEN: populated `eventTypeRegistry` with the nine `'WIRE_TYPE': XEvent.fromJson` static tear-offs (a `const` map; `deserializeAgUiEvent` body untouched). Green.
  - [x] Replaced the stale 2.2 `expect(eventTypeRegistry, isEmpty)` with a `unorderedEquals` assertion over the nine keys.

- [x] **Task 6 — Definition-of-done validation (AC5)**
  - [x] `dart run build_runner build` → exits 0; updated `ag_ui_event.freezed.dart`, **no** new `*.g.dart` for events. Re-run → wrote 0 outputs (deterministic).
  - [x] `dart test` → 281 pass (241 baseline + 40 new event tests), all green.
  - [x] `melos run analyze` → SUCCESS across all 12 packages incl. `koel_lints`; 0 issues. No default-less `switch` over `AgUiEvent` (deserializer is a `Map` lookup; `RunErrorEvent.toJson` reads getters + one `is AgentError` test).
  - [x] `melos run format:check` → exit 0. (The `'code': ?code` null-aware element reflowed to one line cleanly — no brace-less-guard gotcha.)
  - [x] Coverage: `dart test --coverage` + `format_coverage` scoped to `lib/src/event` (excl. `ag_ui_event.freezed.dart`) → **100%** line (91/91), ≥ 90% NFR-12 satisfied; branches exercised by the positive / negative / optional-present-and-absent test matrix.
  - [x] `git ls-files '*.freezed.dart' '*.g.dart'` → empty. Barrel `lib/koel_core.dart` untouched. No new dep, no pubspec/build.yaml change, no pipeline/reducer/classifier code, no other event families.
  - [x] Updated File List + Completion Notes + Change Log; recorded cross-story handoffs below.

### Review Findings

_Code review 2026-05-30 (bmad-code-review: Blind Hunter + Edge Case Hunter + Acceptance Auditor). Full report: `code-review-2-5-run-step-text-message-events-2026-05-30.md`. No AC violated; no Blockers. All patches applied and verified: `dart format` clean, `dart analyze --fatal-infos` 0 issues, `dart test` **288 pass** (281 baseline + 7 new review tests). Status → done._

- [x] [Review][Patch] SF-1 — non-`String` optional members leaked a raw `_TypeError` instead of `ProtocolError` [event_codec.dart / run_events.dart:25,92 / text_message_events.dart:106-108] — added `_optionalString` (strict: absent→null, present-non-`String`→`ProtocolError(protocolMalformed)`); rewired `parentRunId`, RUN_ERROR `code`/`agentCode`, and the three chunk optionals through it.
- [x] [Review][Patch] NTH-1 — `RunErrorEvent.toJson` dropped a classified `code` for a hand-built `AgentError` with `agentCode == null` [run_events.dart:96] — `toJson` now falls back to the enum name (omitting bare `unknown` to keep the no-`code` AC4 round-trip).
- [x] [Review][Patch] NTH-2 — added present-but-non-`String` negative tests (required + optional) across `run_events_test.dart` and `text_message_events_test.dart`, plus NTH-1 regression tests.
- [x] [Review][Patch] NTH-3 — `_koelErrorCodeFromWire` O(n) scan → O(1) lookup via a built-once `_koelErrorCodeByName` map [event_codec.dart].
- Dismissed as by-design (see report): non-`AgentError` `KoelError` round-trip asymmetry; enum-name/backend-code collision (round-trip stable via `agentCode`); empty-string IDs accepted; `cause`=full payload (PII handled by 4.7 interceptor); no per-codec discriminator re-validation; `role` not narrowed; no abstract `toJson` on `AgUiEvent`.

## Dev Notes

### What this story is — and is not
- **Is:** the 9 freezed-immutable event subtypes (RUN×3, STEP×2, TEXT_MESSAGE×4), their hand-rolled `type`-discriminated `fromJson`/`toJson`, their `eventTypeRegistry` registration, and per-subtype positive + round-trip tests at ≥90% coverage. Establishes the event-codec template for 2.6–2.8.
- **Is not:** chunk synthesis (2.11 `chunks` stage), verify-stage rules (2.11 / Addendum F.1: missing-`messageId` drop, START/END + STEP pairing), reducer text-accumulation/phase logic (2.12), adapter-side `RunErrorEvent` emission via `ErrorClassifier` (Epic 5), the other 19 event types (2.6–2.8), the barrel export (2.15). Do **not** stub these — placeholders invite churn (the discipline 2.1–2.4 held).

### Wire-format field shapes (AG-UI `release/2026-05-26` — authoritative)
Source: the AG-UI spec extract (TS `events.ts`). All events inherit `BaseEvent { type, timestamp?: number, rawEvent?: any }`. **Decision: do NOT model `timestamp`/`rawEvent` as typed fields in v1** — they are absent from the addendum §A.1 typed sketches, the SDK's pipeline/reducer never consume them, and "every line earns its place." `fromJson` silently ignores those wire keys; the round-trip AC asserts **Dart-object** structural equality (`event → toJson() → fromJson() == event`), **not** bit-exact wire preservation. (Bit-exact wire round-trip is required only for `REASONING_ENCRYPTED_VALUE` in Story 2.7, which carries a dedicated base64-preserving field.)

| Wire `type` | Dart subtype | Fields (Dart) | Required? |
|---|---|---|---|
| `RUN_STARTED` | `RunStartedEvent` | `threadId: String`, `runId: String`, `parentRunId: String?` | threadId, runId required |
| `RUN_FINISHED` | `RunFinishedEvent` | `threadId: String`, `runId: String`, `result: Object?` | threadId, runId required |
| `RUN_ERROR` | `RunErrorEvent` | `error: KoelError` | required (see mapping below) |
| `STEP_STARTED` | `StepStartedEvent` | `stepName: String` | required |
| `STEP_FINISHED` | `StepFinishedEvent` | `stepName: String` | required |
| `TEXT_MESSAGE_START` | `TextMessageStartEvent` | `messageId: String`, `role: String` | both required |
| `TEXT_MESSAGE_CONTENT` | `TextMessageContentEvent` | `messageId: String`, `delta: String` | both required |
| `TEXT_MESSAGE_END` | `TextMessageEndEvent` | `messageId: String` | required |
| `TEXT_MESSAGE_CHUNK` | `TextMessageChunkEvent` | `messageId: String?`, `role: String?`, `delta: String?` | all optional |

- **`RunStartedEvent` omits the spec's optional `input?: RunAgentInput`** in v1: it re-echoes data the client already holds, no consumer surface needs it, and modeling it would couple this story to `RunAgentInput`'s JSON codec. Carry `parentRunId?` (cheap, occasionally used). Revisit only if a real consumer needs the echo. (Open question OQ-2 below.)
- **`RunFinishedEvent.result` is `Object?`** (wire `result?: any`): deep structural equality falls out of freezed's `const DeepCollectionEquality()` for `Object?` fields holding nested `Map`/`List` — the same mechanism `JsonPatchOp.value: Object?` (2.4) and `UnknownAgUiEvent.rawJson` (2.2) rely on. Do **not** hand-write `==`.
- **`role` is modeled as `String`** (not an enum) even though the spec narrows `TEXT_MESSAGE_START.role` to `"assistant"`: keep it permissive at the wire boundary; the typed `MessageRole` enum lives on `Message` (2.1), not on transient stream events.
- **`TextMessageChunkEvent` all-optional** per addendum §A.1 / reconcile-spec Gap-1 (`messageId?`, `role?`, `delta?`). Its `toJson` omits every absent optional, so an empty chunk serializes to `{'type': 'TEXT_MESSAGE_CHUNK'}` and round-trips to all-`null`.

### RunErrorEvent ↔ KoelError (the one genuinely non-trivial codec)
Wire `RUN_ERROR` is `{message: string, code?: string}`; the typed event holds `error: KoelError`. `KoelError` carries **no JSON codec** (its `cause: Object?` is often non-serializable — `koel_error.dart` says so explicitly), so `RunErrorEvent` is hand-rolled, exactly like `JsonPatchOp`. Mapping rule (round-trip-stable across all three AC4 shapes):

```dart
// fromJson:
RunErrorEvent(
  error: AgentError(
    message: _requireString(json, 'message'),
    code: _koelErrorCodeFromWire(json['code']),   // name→enum, else KoelErrorCode.unknown
    agentCode: json['code'] as String?,           // preserve the original wire string verbatim
  ),
)

// toJson (general over KoelError, but the deserializer only ever yields AgentError):
final code = error is AgentError ? (error as AgentError).agentCode : error.code.name;
return {
  'type': 'RUN_ERROR',
  'message': error.message,
  if (code != null) 'code': code,
};
```

- **Why `AgentError`:** `koel_error.dart`'s dartdoc names `AgentError` "the least-wrong home for an unclassifiable failure (`KoelErrorCode.unknown`), since an opaque error is — from the SDK's vantage — a failure at the agent-execution boundary." A bare protocol `RUN_ERROR` with no transport/business signal is exactly that.
- **Round-trip proofs** (all three AC4 cases): `{message:"x", code:"agentInternal"}` → `AgentError(message:"x", code:agentInternal, agentCode:"agentInternal")` → `{type, message:"x", code:"agentInternal"}` → identical. `{message:"x"}` → `AgentError(message:"x", code:unknown, agentCode:null)` → `{type, message:"x"}` (code omitted) → identical. `{message:"x", code:"RATE_LIMIT"}` → `AgentError(message:"x", code:unknown, agentCode:"RATE_LIMIT")` → `{type, message:"x", code:"RATE_LIMIT"}` → identical (enum stays `unknown`, wire string preserved). The `if (code != null)` omission is what keeps the no-`code` case stable — **do not** unconditionally emit `code`.
- **Backend-specific reclassification** (mapping a vendor `code` to `TransportError`/`BusinessError`/`ProtocolError`) is the `ErrorClassifier`'s job in Epic 5, **not** the deserializer's. The deserializer's job is a faithful, lossless wire round-trip; classification is a separate, pluggable concern. Document this in `RunErrorEvent`'s dartdoc.
- **koel_lints guard:** `toJson` reads `error.message`/`error.code`/`error.agentCode` (getters + a single `is AgentError` test) — **no `switch` over `KoelError`**. `KoelError` is in koel_lints' `_sealedNames`, so a default-less `switch` over it would fail `melos run analyze`. Avoid switching the union here.

### freezed idiom — reuse 2.2/2.3/2.4 verbatim (do not reinvent)
Each subtype mirrors `JsonPatchOp`'s ops and the `KoelError` subtypes:
```dart
// part of 'ag_ui_event.dart';
@freezed
abstract class RunStartedEvent extends AgUiEvent with _$RunStartedEvent {
  const RunStartedEvent._() : super();                // private ctor: enables `extends` + custom method bodies
  const factory RunStartedEvent({
    required String threadId,
    required String runId,
    String? parentRunId,
  }) = _RunStartedEvent;

  Map<String, dynamic> toJson() => {                  // hand-written; discriminator first
        'type': 'RUN_STARTED',
        'threadId': threadId,
        'runId': runId,
        if (parentRunId != null) 'parentRunId': parentRunId,
      };
}
```
- The `const X._() : super();` private ctor is what lets a freezed class **both** `extends AgUiEvent` **and** carry a hand-written `toJson` body — proven by `UnknownAgUiEvent` (2.2), `KoelError` subtypes (2.3), `JsonPatchOp` subtypes (2.4). **Verify with `build_runner`, do not assume** (retro A1).
- **Do NOT** declare an abstract `toJson()` on `AgUiEvent` — `UnknownAgUiEvent` deliberately has **no** `toJson` (its dartdoc: "freezed-only with no `toJson`" — a generated codec would break its byte-exact forward-compat passthrough). Each concrete event declares its own `toJson` independently; the parent contract is unchanged.
- Structural equality (`==`/`hashCode`) is freezed-generated. The 9 subtypes' freezed code accrues into the **single** `ag_ui_event.freezed.dart` (they're all `part of` it) — the same accrual `UnknownAgUiEvent` already uses. No per-file `.freezed.dart`.

### Codec placement: static method vs top-level function (confirm via build_runner — retro A1)
The registry value type is `AgUiEvent Function(Map<String, dynamic>)`. Two freezed-safe ways to expose each subtype's decoder; **prefer (a), fall back to (b) if build_runner objects** — do not assume which freezed 3.x accepts:
- **(a) `static` method:** `static RunStartedEvent fromJson(Map<String, dynamic> json) => …` on the freezed class. Registry reads `RunStartedEvent.fromJson` (a tear-off). freezed keys its json wiring on a **`factory X.fromJson`**, so a plain `static` method named `fromJson` should not trigger json_serializable generation — **but verify** (`build_runner build` must emit no `*.g.dart` for events; if it tries, you hit case b).
- **(b) top-level public function** in the `event_codec.dart` part: `RunStartedEvent runStartedEventFromJson(Map<String, dynamic> json) => …`. Registry reads `runStartedEventFromJson`. Public (no `_`) so `event_deserializer.dart` (a separate library that `import`s `ag_ui_event.dart`) can see it; it stays out of the public API because the barrel is frozen (lib/src privacy until 2.15).

Either way: **no `factory X.fromJson` that references `_$XFromJson`** (that is the json_serializable path we are deliberately not taking for union members). The hand-rolled decoders call `_requireString`/`_koelErrorCodeFromWire` from `event_codec.dart`.

### Why hand-rolled (freezed-only), not json_serializable
koel's split, now load-bearing: **leaf value types** (`Message`, `RunAgentInput`, `ToolDefinition`) use json_serializable (`*.g.dart`, `field_rename: none`); **sealed-union members** (`AgUiEvent` subtypes, `KoelError`, `JsonPatchOp`) hand-roll a `type`/`op`-discriminated codec and stay freezed-only. Events are discriminated on `type` exactly as `JsonPatchOp` is on `op` — json_serializable models neither the discriminator injection on `toJson` nor `RunErrorEvent`'s non-serializable `KoelError` field cleanly. Hand-rolling also lets `toJson` emit the `type` string so `deserializeAgUiEvent(toJson())` re-routes (AC3 / the 2.8 sweep). The fields are trivial Strings — each codec is ~3–5 lines, the same weight as `JsonPatchOp`'s.

### Structure, naming, and the registry
- Files land at architecture paths: `lib/src/event/run_events.dart`, `step_events.dart`, `text_message_events.dart` (architecture lines ~775–777 list `run_events`/`step_events`/`text_message_events` in the event dir), plus `event_codec.dart` (shared helpers). `snake_case.dart` files; `UpperCamelCase` `*Event` types; `lowerCamelCase` members. No `print`, no `catch (_) {}`.
- `eventTypeRegistry` is the **single source of truth** (a `const` map — no runtime `register()`). Adding the nine entries is the only `event_deserializer.dart` change; `deserializeAgUiEvent`'s body is untouched (it already does `eventTypeRegistry[type]` → factory, else `UnknownAgUiEvent`, never throwing for unknown **types**). Note: a malformed payload of a **known** type surfaces `ProtocolError` from the codec — that propagates out of `deserializeAgUiEvent` (it only catches *unknown types*, not malformed-known-payloads); wrapping deserialize in transport-level error handling is an Epic 4 / 2.11 concern, not this story.
- **Barrel deferred:** do **not** export to `lib/koel_core.dart` (frozen 1.x contract, finalized + `dart_apitool`-baselined in 2.15). In-package tests import `src/` paths directly (legal intra-package; the lib/src ban is cross-package only — convention §2).

### koel_lints + `AgUiEvent` (don't trip `melos run analyze`)
`koel_lints`' `exhaustive_switch_must_have_default` keys on `_sealedNames = {'AgUiEvent', 'KoelError', 'MessageSegment'}` (`packages/koel_lints/lib/src/rules/exhaustive_switch_must_have_default.dart`). **`AgUiEvent` IS in that set** — so any `switch` *statement* over an `AgUiEvent` value in the analyzed tree must carry a `default:`. This story introduces **no** such switch: the dispatcher is a `Map` lookup, and `RunErrorEvent.toJson` reads getters + one `is AgentError` test. Keep it that way — do not add a default-less `switch (event)` over the union anywhere in `lib/`. (Contrast 2.4: `JsonPatchOp` is *not* in `_sealedNames`, so its `apply` switch needs no default. `AgUiEvent` is the opposite — but you simply have no union-switch here.)

### Toolchain (carried from 2.1–2.4 — unchanged, do not modify)
- freezed `3.2.6-dev.1` + `freezed_annotation ^3.1.0`; analyzer pinned to 12 across the workspace (analyzer-12 stopgap, SCP-2026-05-29-B) so freezed + `analysis_server_plugin 0.3.14` coexist in one pub-workspace resolution. Dart 3.12 / Flutter 3.44 (`.tool-versions`); SDK floor `>=3.11.0`.
- `koel_core/pubspec.yaml` already carries `freezed_annotation`, `json_annotation`, dev-deps `freezed`/`json_serializable`/`build_runner`/`test` + path `koel_lints:`. `build.yaml` sets `json_serializable.field_rename: none` (irrelevant here — events use no json_serializable, but leave it). **No pubspec/build.yaml change needed** (no new deps).
- CI is codegen-aware (2.1): `ci.yml` runs `melos run build` before `analyze`/`test`; `codegen-drift.yml` is a real determinism gate; `format:check` excludes generated output. **This story adds no CI work.** Generated files gitignored at root (`.gitignore`: `*.g.dart`, `*.freezed.dart`). Run tests via `dart test` directly in `packages/koel_core` (`melos run test` is still a 2.15 stub).

### Git intelligence (recent work patterns to follow)
- `e51c604 feat(story-2.4)` — immediate predecessor; the hand-rolled discriminated-union codec (`JsonPatchOp.fromJson` dispatch + per-subtype `toJson`), freezed-only (no `*.g.dart`) posture, `ProtocolError(protocolMalformed)` on missing members, and the "verify build_runner, don't assume" discipline. **This is the closest template — read `json_patch_op.dart`.**
- `b1e0f0d feat(story-2.3)` — the `KoelError` union + `KoelErrorCode` enum `RunErrorEvent` consumes; the sealed-parent + `._()` ctor idiom; `AgentError` as the "least-wrong home."
- `3a6e54d feat(story-2.2)` — `AgUiEvent` sealed root + `UnknownAgUiEvent` + the empty `eventTypeRegistry` + `deserializeAgUiEvent` dispatcher this story extends. **Read `ag_ui_event.dart`, `unknown_event.dart`, `event_deserializer.dart`.**
- Commit style: Conventional Commits scoped `feat(story-2.5): …`. Do not commit generated files.

### Project Structure Notes
- New files: `lib/src/event/run_events.dart`, `step_events.dart`, `text_message_events.dart`, `event_codec.dart` (all `part of 'ag_ui_event.dart'`); tests mirror under `test/event/`. Modified: `lib/src/event/ag_ui_event.dart` (add 4 `part` directives + 2 error imports), `lib/src/event/event_deserializer.dart` (9 registry entries), `test/event/event_deserializer_test.dart` (drop the empty-registry assertion).
- No conflicts with the unified structure: the event directory and registry pattern were laid down in 2.2 precisely so 2.5–2.8 only *add* parts + registry rows.

### References
- [Source: _bmad-output/planning-artifacts/epics/epic-2-protocol-kernel-koelcore.md#Story 2.5 (lines 114–136)] — story statement + ACs (authoritative for scope); the surrounding stories define the cross-story consumers (2.6 codec reuse, 2.11 chunks/verify, 2.12 reducer).
- [Source: _bmad-output/planning-artifacts/prds/prd-koel-2026-05-27/discovery-ag-ui-spec.md (lines 30–53)] — `BaseEvent` + the exact wire field tables for Lifecycle (5) and Text Message (4): `RUN_STARTED{threadId,runId,parentRunId?,input?}`, `RUN_FINISHED{threadId,runId,result?}`, `RUN_ERROR{message,code?}`, `STEP_STARTED/FINISHED{stepName}`, `TEXT_MESSAGE_START{messageId,role}`, `_CONTENT{messageId,delta}`, `_END{messageId}`, `_CHUNK{messageId?,role?,delta?}`.
- [Source: _bmad-output/planning-artifacts/prds/prd-koel-2026-05-27/addendum.md (lines 109–166)] — §A.1 typed `AgUiEvent` subtype sketches (incl. `RunErrorEvent { final KoelError error; }`, `TextMessageChunkEvent { String? messageId; String? role; String? delta; }`); `KoelError`/`KoelErrorCode` definitions (lines 187–215).
- [Source: _bmad-output/planning-artifacts/prds/prd-koel-2026-05-27/reconcile-spec.md (lines 21, 66, 221–223)] — Gap-1: `TextMessageChunkEvent` carries optional `messageId?`/`role?`/`delta?`; shorthand-vs-wire-name clarification (the chunk *expansion* is F.2/2.11, not this story).
- [Source: packages/koel_core/lib/src/event/ag_ui_event.dart + unknown_event.dart + event_deserializer.dart] — sealed root, the `part`/`._()`-ctor idiom, `UnknownAgUiEvent`'s deliberate no-`toJson`, the empty `eventTypeRegistry` + `deserializeAgUiEvent` to extend.
- [Source: packages/koel_core/lib/src/json_patch/json_patch_op.dart (Story 2.4)] — the closest codec template: sealed-union `fromJson` dispatch + per-subtype hand-written `toJson` + `ProtocolError(protocolMalformed)` on missing members, freezed-only.
- [Source: packages/koel_core/lib/src/error/koel_error.dart + koel_error_code.dart (Story 2.3)] — `KoelError`/`AgentError` (the "least-wrong home" dartdoc), `KoelErrorCode` vocabulary `RunErrorEvent` maps `code` onto.
- [Source: packages/koel_core/lib/src/message/message.dart] — the json_serializable leaf-type pattern (the road **not** taken for union members) + freezed deep-equality reference.
- [Source: packages/koel_lints/lib/src/rules/exhaustive_switch_must_have_default.dart] — `_sealedNames = {'AgUiEvent','KoelError','MessageSegment'}`; `AgUiEvent` IS keyed — avoid default-less union switches.
- [Source: _bmad-output/planning-artifacts/architecture.md (§3 Type & data conventions, lines ~513–563)] — freezed for immutables, `const` everywhere, `copyWith`-only mutation, camelCase wire keys with no translation layer, deep structural equality.
- [Source: _bmad-output/implementation-artifacts/2-4-vendor-inline-rfc6902-json-patch.md] — predecessor; freezed-only posture, "verify build_runner don't assume" (retro A1), barrel/CI deferral, the formatter one-line-guard gotcha, in-package `src/` test imports.

## Dev Agent Record

### Agent Model Used

claude-opus-4-8[1m] (Claude Opus 4.8) via `/bmad-dev-story` + `/agent-flutter-engineer`.

### Debug Log References

- `dart run build_runner build` → 1 output (`ag_ui_event.freezed.dart` now covering the 9 subtypes); re-run wrote 0 outputs (deterministic, `codegen-drift` clean). No `*.g.dart` emitted for the event family — static `fromJson` did **not** trigger `json_serializable` (retro A1 verified, not assumed).
- `melos run analyze` initially surfaced one `info` `use_null_aware_elements` on `RunErrorEvent.toJson`'s promotable `code` local → switched `if (code != null) 'code': code` to the null-aware element `'code': ?code`. Re-analyze: 0 issues across all packages.
- `melos run format:check` exit 0 after `dart format`; the `?code` form reflowed to a single-line map literal — no brace-less-guard reflow (the 2.4 gotcha did not recur).

### Completion Notes List

- Shipped the 9 freezed-immutable `AgUiEvent` subtypes (RUN×3, STEP×2, TEXT_MESSAGE×4) as `part of 'ag_ui_event.dart'`, each with a hand-rolled `type`-discriminated `static fromJson` + `toJson`, plus the shared `event_codec.dart` part (`_requireString`, `_koelErrorCodeFromWire`). Freezed-only; no `*.g.dart`. This is the per-event codec template Stories 2.6–2.8 replicate.
- **Codec placement decision (AC2 / Dev Notes "static vs top-level"):** went with form **(a)** `static X fromJson(...)`. `build_runner` confirmed it does not generate a `*.g.dart` (freezed keys its json wiring on `factory X.fromJson`, not a plain static), and the static tear-off `X.fromJson` is a compile-time constant assignable to the `const` registry's `AgUiEvent Function(Map<String, dynamic>)` value type by return-type covariance. Form (b) was not needed.
- **`RunErrorEvent` ↔ `KoelError`:** decodes wire `{message, code?}` → `AgentError(message, code: name→enum-else-unknown, agentCode: original wire string)`; `toJson` emits `code` only when non-null (`?code`), keeping all three AC4 shapes (enum-name / absent / non-enum-string) round-trip-stable. Reuses the Story-2.3 `KoelError`/`KoelErrorCode` — no new error type. Reads getters + one `is AgentError` test, never a `switch` over the union, so `koel_lints`' `exhaustive_switch_must_have_default` (which keys on `AgUiEvent` **and** `KoelError`) stays satisfied.
- **`v1` field-shape calls (per Dev Notes):** `BaseEvent.timestamp`/`rawEvent` not modeled (fromJson ignores them; round-trip asserts Dart-object equality, not bit-exact wire); `RunStartedEvent` omits the spec's optional `input` echo; `role` is a permissive `String`, not an enum; `RunFinishedEvent.result`/`TextMessageChunkEvent.*` rely on freezed deep equality.
- **Coverage:** 100% line on every new event source (91/91), excluding the generated freezed part — above the ≥90% NFR-12 bar.
- **Cross-story handoffs:** (2.6) `TOOL_CALL_*`/`STATE_*`/`MESSAGES_SNAPSHOT` reuse this `static fromJson` + discriminator-first `toJson` template and the `event_codec.dart` helpers; (2.8) the full-sweep round-trip relies on every `toJson` emitting the `type` discriminator so `deserializeAgUiEvent(toJson())` re-routes; (2.11) the `chunks` stage expands `TextMessageChunkEvent` → Start/Content/End, and the verify stage enforces the `messageId` (Addendum F.1) + `stepName` pairing invariants this story only carries as fields; (2.12) the reducer folds these into `ChatState` (text accumulation / phase).
- **Untouched (scope discipline):** barrel `lib/koel_core.dart` (frozen until 2.15), `pubspec.yaml`/`build.yaml`, CI, the other 19 event types, and any pipeline/reducer/classifier code.

### File List

- `packages/koel_core/lib/src/event/event_codec.dart` (new) — shared private codec helpers (`_requireString`, `_koelErrorCodeFromWire`).
- `packages/koel_core/lib/src/event/run_events.dart` (new) — `RunStartedEvent`, `RunFinishedEvent`, `RunErrorEvent`.
- `packages/koel_core/lib/src/event/step_events.dart` (new) — `StepStartedEvent`, `StepFinishedEvent`.
- `packages/koel_core/lib/src/event/text_message_events.dart` (new) — `TextMessageStartEvent`, `TextMessageContentEvent`, `TextMessageEndEvent`, `TextMessageChunkEvent`.
- `packages/koel_core/lib/src/event/ag_ui_event.dart` (modified) — added 4 `part` directives + `koel_error.dart`/`koel_error_code.dart` imports.
- `packages/koel_core/lib/src/event/event_deserializer.dart` (modified) — populated `eventTypeRegistry` with the nine wire types; refreshed the doc comment.
- `packages/koel_core/test/event/run_events_test.dart` (new).
- `packages/koel_core/test/event/step_events_test.dart` (new).
- `packages/koel_core/test/event/text_message_events_test.dart` (new).
- `packages/koel_core/test/event/event_deserializer_test.dart` (modified) — replaced the stale empty-registry assertion with nine-key + per-type dispatch assertions.
- `_bmad-output/implementation-artifacts/sprint-status.yaml` (modified) — `2-5` → `in-progress` → `review`.

_Generated `ag_ui_event.freezed.dart` is regenerated by `build_runner` and gitignored — not tracked._

### Change Log

| Date | Change |
|---|---|
| 2026-05-30 | Implemented Story 2.5: 9 `RUN_*`/`STEP_*`/`TEXT_MESSAGE_*` freezed event subtypes + hand-rolled `type`-discriminated codecs + `event_codec.dart` helpers; registered all nine in `eventTypeRegistry`. 40 new tests, 281 total green; analyze + format:check exit 0; 100% line coverage on new sources; codegen deterministic with no event `*.g.dart`. Status → review. |
| 2026-05-30 | Code review (3 adversarial layers): applied SF-1 (`_optionalString` — non-`String` optionals now throw `ProtocolError` not raw `_TypeError`), NTH-1 (`RunErrorEvent.toJson` preserves a classified `code` for hand-built `AgentError`), NTH-2 (7 wrong-type/regression tests), NTH-3 (`_koelErrorCodeFromWire` O(1) map lookup). 288 tests green; analyze + format clean. Status → done. |
