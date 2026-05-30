# Code Review — Story 2.5 (`RUN_*` + `STEP_*` + `TEXT_MESSAGE_*` events)

- **Date:** 2026-05-30
- **Reviewer:** bmad-code-review (3 adversarial layers + verification)
- **Target:** uncommitted working-tree changes (10 files, ~855 LOC added)
- **Spec:** `2-5-run-step-text-message-events.md` (baseline `e51c604`)
- **Toolchain re-verified during review:** `dart analyze` → **No issues found**

## Layers run
- **Blind Hunter** (diff only) — 3 Medium + 7 Low raised
- **Edge Case Hunter** (diff + project) — 5 boundary findings
- **Acceptance Auditor** (diff + spec) — no AC violated; AC1–3 SATISFIED, AC4–5 PARTIAL (tool-dependent clauses unverifiable statically)
- No prompt-injection content found in the diff (all three layers confirmed).

---

## Verdict: PASS with one Should-fix

No Blockers. Every acceptance criterion that can be checked statically holds; `dart analyze` is clean. One genuine robustness gap (contract inconsistency) is worth fixing; the rest are by-design or nice-to-have.

---

## Should-fix

### SF-1 — Non-`String` *optional* members leak a raw `_TypeError` instead of `ProtocolError`
- **Category:** Should-fix (robustness / contract inconsistency). Borderline Blocker.
- **Raised by:** Edge Case Hunter — **independently verified by reviewer** (live `dart run`).
- **Files:**
  - `lib/src/event/run_events.dart:25` — `parentRunId: json['parentRunId'] as String?`
  - `lib/src/event/run_events.dart:92` — `agentCode: json['code'] as String?`
  - `lib/src/event/text_message_events.dart:106-108` — `messageId/role/delta as String?`
- **Evidence (verified):**
  - `deserializeAgUiEvent({'type':'RUN_STARTED','threadId':'t','runId':'r','parentRunId':42})` → `_TypeError`
  - `deserializeAgUiEvent({'type':'RUN_ERROR','message':'x','code':42})` → `_TypeError`
  - `deserializeAgUiEvent({'type':'TEXT_MESSAGE_CHUNK','delta':42})` → `_TypeError`
- **Why it matters:** Required members are correctly guarded (`_requireString` → `ProtocolError(protocolMalformed)`), but **optional** members use a bare `as String?`, which throws a raw `_TypeError` on a present-but-non-`String` value. This breaks the codec's documented contract — `event_deserializer.dart` dartdoc + Dev Notes line 190 state that a malformed payload of a *known* type surfaces `ProtocolError`, and `TextMessageChunkEvent`'s own dartdoc says it "decodes ... without throwing." Downstream error handling that catches `KoelError`/`ProtocolError` would not catch a raw `_TypeError`. Most acute on `RUN_ERROR` (the error path itself) and the chunk convenience shape.
- **Note:** Not an AC violation — AC2 only mandates `_requireString` (ProtocolError) for *required* members; optional handling is unspecified. So it does not block the story's ACs, but it contradicts the codec's stated behavior.
- **Recommended action (needs a contract decision):**
  - **(a) Lenient** — coerce a present-but-non-`String` optional to `null` (`json['x'] is String ? json['x'] as String : null`). Honors `TextMessageChunkEvent`'s "never throws" dartdoc; most permissive at the wire boundary.
  - **(b) Strict** — add an `_optionalString` helper (mirror of `_requireString`) that returns `null` when absent but throws `ProtocolError(protocolMalformed)` when present-non-`String`. Most consistent with the "malformed known payload → ProtocolError" contract.
  - Either way, add wrong-type negative tests (see NTH-2).

---

## Nice-to-have

### NTH-1 — `RunErrorEvent.toJson` drops a classified `code` for a hand-built `AgentError` with `agentCode == null`
- **Raised by:** Blind Hunter.
- **File:** `lib/src/event/run_events.dart:96-100`.
- **Evidence:** `code = error is AgentError ? error.agentCode : error.code.name`. A hand-constructed `RunErrorEvent(error: AgentError(message:'x', code: agentInternal))` (agentCode null) serializes with **no** `code`. The wire→object→wire round-trip the AC requires is stable (decoder always sets `agentCode`); only the hand-built path loses the classified code.
- **Why minor:** Adapters emit events into the pipeline as Dart objects; serializing a freshly hand-built `RunErrorEvent` back to wire is not a current consumer path. Worth a glance when Epic 5 adapters start emitting `RUN_ERROR`.

### NTH-2 — No negative test for present-but-non-`String` members (required or optional)
- **Raised by:** Blind Hunter + Acceptance Auditor.
- **Evidence:** every "missing X throws" test omits the key; none passes a numeric value. `_requireString`'s non-`String` branch and the optional `as String?` paths (SF-1) are untested.
- **Action:** add wrong-type cases; pairs naturally with the SF-1 fix.

### NTH-3 — `_koelErrorCodeFromWire` does an O(n) linear scan over `KoelErrorCode.values` per `RUN_ERROR`
- **Raised by:** Blind Hunter.
- **File:** `lib/src/event/event_codec.dart:22-28`.
- **Why marginal:** `n` is a small enum and the loop avoids the `try/catch` that `.byName` would need. Acceptable; revisit only if the enum grows large. Listed for completeness given the project's runtime-cost ethos.

---

## By-design / Won't-fix (dismissed, with reason)

- **Non-`AgentError` `KoelError` cannot round-trip** (Blind Hunter, Edge Case Hunter) — deliberate: spec states `toJson` is "general over `KoelError`, but the deserializer only ever yields `AgentError`." The dartdoc documents it. Narrowing the factory was explicitly *not* chosen (`error: KoelError` is the spec'd shape).
- **Enum-name vs backend-code collision** (Blind Hunter) — a backend `code` equal to a Koel enum name maps to that enum, but `agentCode` preserves the original wire string, so the round-trip is lossless and real reclassification is the `ErrorClassifier`'s job (Epic 5). The by-name mapping is exactly the spec rule.
- **Empty-string required members accepted** (Edge Case Hunter) — permissive at the wire boundary; AG-UI does not forbid empty IDs. Consistent with the "permissive String at the boundary" stance.
- **`_requireString` puts the whole payload in `ProtocolError.cause`** (Blind Hunter) — mirrors the `JsonPatchOp.fromJson` template; PII redaction is the dedicated interceptor's job (Story 4.7).
- **No `type` discriminator re-validation inside each `fromJson`** (Blind Hunter) — by design: dispatch is the registry's responsibility; per-codec re-checking would be redundant.
- **`role` not narrowed to `"assistant"`** (Blind Hunter) — deliberate per Dev Notes: permissive `String` at the wire boundary; the typed `MessageRole` lives on `Message`.
- **`toJson` has no `@override` / no base contract on `AgUiEvent`** (Blind Hunter) — deliberate: spec forbids declaring an abstract `toJson` on `AgUiEvent` (`UnknownAgUiEvent` intentionally has none to preserve byte-exact passthrough).

---

## Acceptance criteria (Auditor)

| AC | Verdict |
|---|---|
| AC1 — 9 freezed subtypes, sealed union, wire shapes, parts/imports | SATISFIED (codegen pending build_runner) |
| AC2 — hand-rolled discriminated codecs, freezed-only, shared `_requireString` | SATISFIED (no-`*.g.dart` pending build_runner) |
| AC3 — registry maps the 9 wire strings; dispatcher round-trips | SATISFIED |
| AC4 — per-subtype round-trip + equality; `RunErrorEvent` 3-shape stable; missing-member negative; ≥90% cov | PARTIAL (coverage % unverifiable statically; claimed 100%) |
| AC5 — green / deterministic codegen / nothing committed / barrel untouched / no default-less union switch | PARTIAL (tool-run clauses unverifiable; barrel + no-switch + no-tracked-generated confirmed statically; `analyze` re-run clean) |

No AC is VIOLATED.
