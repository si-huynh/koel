---
baseline_commit: b1e0f0dfa4a21c17281e07e0677469479848e2a2 # feat(story-2.3) — HEAD at story creation
---

# Story 2.4: Vendor-inline RFC 6902 JSON Patch implementation

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a Flutter/Dart developer,
I want `koel_core/lib/src/json_patch/` to ship a strict-mode RFC 6902 implementation — `JsonPatch.apply` plus a sealed `JsonPatchOp` union covering `add`/`remove`/`replace`/`move`/`copy`/`test` — with **no external dependency**,
so that `STATE_DELTA` events apply deterministically and the SDK stays free of the stale `package:json_patch` per AR-6 / architecture Bonus decision.

**Why this story ships before the event subtypes.** `StateDeltaEvent.patches: List<JsonPatchOp>` (Story 2.6) and the `apply` pipeline stage's STATE_DELTA fold (Story 2.11) and the `DefaultChatStateReducer`'s `STATE_*` handling (Story 2.12) all consume the `JsonPatchOp` type + `JsonPatch.apply` defined here. Landing the patch engine now means those later stories reference a stable, conformance-tested foundation instead of stubbing placeholders — the same "no churn-inducing stubs" discipline Stories 2.1/2.2/2.3 held.

**Scope reality check.** This story ships the `JsonPatchOp` value types + the `JsonPatch.apply` engine + the RFC 6902 conformance suite. It does **NOT** ship `StateDeltaEvent` or any event subtype (2.6), the verify-stage rule that drops empty-patch STATE_DELTA (2.11), the `apply` pipeline stage that *folds* patches into `ChatState` (2.11/2.12), `StateConflict`/`LastWriterWinsResolver` (2.13), or the barrel export (2.15). The errors it throws reuse the **already-shipped** `ProtocolError` from Story 2.3 — no new error type.

## Acceptance Criteria

**AC1 — `json_patch/` directory ships the two files: engine + sealed op union**
**Given** `koel_core/lib/src/json_patch/`,
**When** I list the directory,
**Then** `json_patch.dart` (exposing `static Object? JsonPatch.apply(Object? document, List<JsonPatchOp> patches)`) and `json_patch_op.dart` (sealed `JsonPatchOp` with concrete `AddOp`/`RemoveOp`/`ReplaceOp`/`MoveOp`/`CopyOp`/`TestOp` subtypes) both exist,
**And** every `JsonPatchOp` subtype is **freezed-generated** (structural `==`/`hashCode`/`copyWith`) using the freezed-3.x "subtype `extends` a hand-written sealed parent via a private `._()` ctor" idiom proven by `KoelError` (2.3) and `UnknownAgUiEvent` (2.2) — verified by running `build_runner`, not assumed,
**And** the sealed parent carries a hand-written `factory JsonPatchOp.fromJson(Map<String, dynamic> json)` that dispatches on the `op` discriminator, and an abstract `Map<String, dynamic> toJson()` each subtype implements (no `json_serializable` / no `*.g.dart` — discriminated unions are hand-rolled, same freezed-only posture as `KoelError`).

**AC2 — `package:json_patch` stays absent (AR-6 / Bonus)**
**Given** `koel_core/pubspec.yaml`,
**When** I inspect dependencies and dev_dependencies,
**Then** `package:json_patch` does NOT appear (it never has — this AC is "keep it that way"; the only new code is first-party),
**And** no new third-party dependency is added by this story (the engine is pure `dart:core` + the in-package `ProtocolError`/`KoelErrorCode`).

**AC3 — official RFC 6902 conformance fixture set passes**
**Given** the official RFC 6902 conformance fixtures vendored into `koel_core/test/json_patch/rfc6902_fixtures/` (the canonical `json-patch/json-patch-tests` suite — `tests.json` + `spec_tests.json`, pinned to a recorded commit SHA, with provenance + license noted — see Dev Notes "Fixture provenance"),
**When** I run `dart test test/json_patch/`,
**Then** every non-`disabled` fixture passes — success fixtures (`expected`) produce the expected document; error fixtures (`error`) throw `ProtocolError`; covering add, remove, replace, move, copy, test ops, nested paths, array-index manipulation, the `-` end-of-array token, JSON Pointer escaping (`~0`/`~1`), and the negative cases (invalid path, target-doesn't-exist, type mismatch, failed `test`, out-of-range index),
**And** line + branch coverage on `koel_core/lib/src/json_patch/` is **≥ 95%** (`dart test --coverage` → `format_coverage`; see Dev Notes "Coverage gate").

**AC4 — invalid patch ops throw the Story-2.3 `ProtocolError(protocolMalformed)`; `apply` is non-mutating + atomic**
**Given** an invalid patch operation (remove/replace/test/move/copy against a non-existent path, a failed `test`, an out-of-range or non-integer array index, an unknown `op`, or a missing required member like `path`/`value`/`from`),
**When** `JsonPatch.apply` is called,
**Then** it throws a `ProtocolError(code: KoelErrorCode.protocolMalformed)` constructed from the **existing** Story-2.3 error type (no new error class),
**And** the caller's input `document` is **never mutated** — `apply` operates on a deep copy and, on any op failure, throws with the caller's object structurally untouched (atomicity: a partially-applied patch is never observable; this guards the reducer-purity contract Story 2.12 will assert),
**And** on full success `apply` returns the new document and the original input remains structurally equal to its pre-call value.

**AC5 — repo stays green; codegen produces the freezed part; nothing committed**
**Given** the workspace after this story lands,
**When** I run the toolchain,
**Then** `cd packages/koel_core && dart run build_runner build` produces `json_patch_op.freezed.dart` next to source with no errors **and no `*.g.dart`** (freezed-only — see AC1),
**And** `cd packages/koel_core && dart test` passes (existing 54 + the new json_patch tests),
**And** `melos run analyze` exits 0 across the workspace (NFR-13) — including the `koel_lints` plugin, with **no** default-less `switch` over `JsonPatchOp` introduced into the analyzed tree (see Dev Notes "koel_lints + JsonPatchOp"),
**And** `melos run format:check` exits 0 (generated output already excluded by `tool/format.sh`),
**And** `git status` / `git ls-files '*.freezed.dart' '*.g.dart'` shows no generated files staged or tracked (gitignored at repo root; CI's `codegen-drift` gate verifies determinism),
**And** the barrel `lib/koel_core.dart` is **not** touched (frozen until Story 2.15).

## Tasks / Subtasks

- [x] **Task 1 — sealed `JsonPatchOp` + six freezed subtypes + `fromJson`/`toJson` (AC1)** — red → green → refactor
  - [x] RED: `test/json_patch/json_patch_op_test.dart` — per subtype assert: (a) `const` construction with its members; (b) `isA<JsonPatchOp>()`; (c) **structural equality** (two equal-field instances `==` + equal `hashCode`; differ on any field → `!=`; deep equality on `value: Object?` for nested Map/List — relies on freezed's `DeepCollectionEquality`, do **not** hand-write `==`); (d) `copyWith`; (e) `JsonPatchOp.fromJson({...})` round-trips to the right subtype with members populated, and `op.toJson()` reproduces the wire map (`{'op': 'add', 'path': '/a', 'value': 1}` ⇄ `AddOp(path:'/a', value:1)`). Add negative cases: `fromJson` with unknown `op`, missing `path`, missing `value` (for add/replace/test), missing `from` (for move/copy) each throws `ProtocolError(protocolMalformed)`. Confirm RED.
  - [x] GREEN: implement `lib/src/json_patch/json_patch_op.dart` as a **single library** mirroring the `koel_error.dart` layout: `import 'package:freezed_annotation/...'` + `import '../error/koel_error.dart'` + `import '../error/koel_error_code.dart'` + `part 'json_patch_op.freezed.dart';`. Hand-write `sealed class JsonPatchOp { const JsonPatchOp(); factory JsonPatchOp.fromJson(Map<String,dynamic> json) {…dispatch on json['op']…}; Map<String,dynamic> toJson(); }`. Then the six freezed subtypes, each `@freezed abstract class AddOp extends JsonPatchOp with _$AddOp { const AddOp._() : super(); const factory AddOp({required String path, Object? value}) = _AddOp; @override Map<String,dynamic> toJson() => {'op':'add','path':path,'value':value}; }` (the private `._()` ctor is what lets you add the `toJson` method body and `extends` the sealed parent — see Dev Notes "freezed idiom"). Member shapes per RFC: `add{path,value}`, `remove{path}`, `replace{path,value}`, `move{from,path}`, `copy{from,path}`, `test{path,value}`. Run `dart run build_runner build`; make tests pass. **Verify** the generated part satisfies the parent (don't assume — retro lesson A1).
  - [x] REFACTOR: contract-form dartdoc (convention §6) on `JsonPatchOp` (what it is; that it is the typed RFC 6902 op consumed by `StateDeltaEvent` in 2.6 and applied by `JsonPatch.apply`; the `fromJson` discriminator contract; that `value: Object?` carries an arbitrary JSON value compared deeply) and one line per subtype (which RFC op + member meaning, incl. `from` for move/copy).

- [x] **Task 2 — RFC 6901 JSON Pointer resolver (internal helper) (AC1/AC4)** — red → green
  - [x] RED: `test/json_patch/json_pointer_test.dart` — assert: empty `""` → whole document; `/foo` → member; `/foo/0` → array element; `-` is the end-of-array token (resolved only by `add`); unescaping order **`~1`→`/` first, then `~0`→`~`** (so `/a~1b` ⇒ key `a/b`, `/m~0n` ⇒ key `m~n`) per RFC 6901 §4; reference into a missing parent → signals "not found" (not a crash); array index validation — reject leading-zero (`01`), non-integer, and negative indices. Confirm RED.
  - [x] GREEN: a small pointer utility in its own `lib/src/json_patch/json_pointer.dart` (package-visible so the unit test reaches it via a `src/` import, **never added to the barrel** — the actual public surface, frozen until 2.15). Provides `parseJsonPointer` (tokenize + unescape), `parseArrayIndex` (index validation), `endOfArrayToken`, and `resolvePointer` (read-walk returning the `missing` sentinel, never a crash). **Does not** throw raw `FormatException`/`RangeError`; the only throw is `ProtocolError(protocolMalformed)` for a syntactically-invalid pointer, and the apply engine (Task 3) translates all semantic failures.

- [x] **Task 3 — `JsonPatch.apply` strict-mode engine, all six ops, atomic + non-mutating (AC1/AC4)** — red → green → refactor
  - [x] RED: `test/json_patch/json_patch_apply_test.dart` — hand-written cases for each op (positive + the documented error path), plus: (a) **non-mutation** — pass a `Map`, capture a deep snapshot, run a patch that succeeds, assert the *input* still equals the snapshot and the *returned* doc has the change (apply returns a new tree); (b) **atomicity** — a 3-op patch whose 2nd op fails throws `ProtocolError` and leaves the input structurally unchanged (no partial apply observable); (c) `move` into its own descendant (`from` is a proper prefix of `path`) → `ProtocolError`; (d) `test` numeric/string/array/object equality incl. a failing `test`; (e) `add` with `-` appends; `add` to an existing object key replaces; `add` to array index shifts; `add` to root `""` replaces whole doc. Confirm RED.
  - [x] GREEN: implement `lib/src/json_patch/json_patch.dart` → `class JsonPatch { const JsonPatch._(); static Object? apply(Object? document, List<JsonPatchOp> patches) {…} }`. **Deep-copy** `document` first (recursive clone of Map/List; scalars are immutable) — the engine mutates only the copy; return it. Fold each op left-to-right; on the first failure throw `ProtocolError(message:'…', code: KoelErrorCode.protocolMalformed, cause: op)` — the copy is discarded, the caller's input is pristine. Op semantics (RFC 6902 §4, strict): `add` (insert/replace; `-` append; index ≤ length else error; parent must exist), `remove` (target must exist), `replace` (target must exist; = remove+add), `move` (`from` exists; `from` not a proper prefix of `path`; remove-then-add), `copy` (`from` exists; deep-copy value then add), `test` (deep-equal `value` at `path` else error). See Dev Notes "RFC 6902 strict-mode semantics" for the full table.
  - [x] REFACTOR: contract-form dartdoc on `JsonPatch.apply` (one-line; when-to-use — "applying a `STATE_DELTA`'s patches to a state map"; when-not — "this never partially applies; on any failure it throws and your input is untouched"; error case — `ProtocolError(protocolMalformed)`; example). Note in the dartdoc that AG-UI state is a JSON object so callers pass a `Map<String,dynamic>` and cast the `Object?` result; the engine accepts `Object?` to pass the full RFC conformance suite (whose roots include arrays/scalars).

- [x] **Task 4 — RFC 6902 conformance fixtures + harness + ≥95% coverage (AC3)** — green
  - [x] Vendor the canonical `json-patch/json-patch-tests` fixtures (`tests.json` + `spec_tests.json`) into `test/json_patch/rfc6902_fixtures/`, pinned to commit `2a928f9044aad35c74e2788d498bcf2c6b91adea`. Added `rfc6902_fixtures/PROVENANCE.md` recording source repo URL, commit SHA, retrieval date (2026-05-30), and the upstream license (Apache-2.0).
  - [x] `test/json_patch/rfc6902_conformance_test.dart` — loads each fixture file, iterates entries, **skips** any with `disabled: true`, and for each: parses `patch` via `JsonPatchOp.fromJson`, then — `expected` ⇒ asserts `JsonPatch.apply(doc, ops)` deep-equals `expected` (via the `equals` matcher); `error` ⇒ asserts parse-or-apply throws `ProtocolError`. All 108 non-disabled entries (112 − 4 disabled) pass.
  - [x] Ran `dart test --coverage` + `coverage:format_coverage` (`--package=.`, pub-workspace layout) scoped to `lib/src/json_patch` excluding generated `*.freezed.dart`: **99.35% line coverage** (153/154 — the only miss is the uninstantiable `JsonPatch._()` private ctor, uncoverable by design). Every op branch, dispatch arm, index-validation guard, and error path is exercised by the conformance corpus + hand-written apply tests, so branch coverage is effectively complete; standard `dart test --coverage` collects line hits only.

- [x] **Task 5 — Definition-of-done validation (AC2/AC5)**
  - [x] `grep json_patch packages/koel_core/pubspec.yaml` → no `package:json_patch` line (AC2). No new third-party dep added.
  - [x] `cd packages/koel_core && dart run build_runner build` → exits 0, emits `json_patch_op.freezed.dart` and **no** `*.g.dart`. Re-run → 0 outputs (deterministic; codegen-drift green).
  - [x] `cd packages/koel_core && dart test` → 241 green (existing 54 + 187 new json_patch).
  - [x] `melos run analyze` → SUCCESS across all 12 packages (NFR-13). The `JsonPatchOp` `switch` in `apply` is exhaustive with **no** `default:` — `JsonPatchOp` is not in koel_lints' `_sealedNames`, confirmed by the green analyze.
  - [x] `melos run format:check` → exits 0.
  - [x] `git ls-files '*.freezed.dart' '*.g.dart'` → empty. Barrel `lib/koel_core.dart` untouched (frozen until 2.15). No CI changes, no `StateDeltaEvent`/pipeline/reducer/`StateConflict`, no `json_serializable` on `JsonPatchOp`, no new error subtype (reused `ProtocolError`).
  - [x] Updated File List + Completion Notes + Change Log; recorded cross-story handoffs (2.6 `StateDeltaEvent.patches: List<JsonPatchOp>` + wire round-trip via `fromJson`/`toJson`; 2.11/2.12 the apply-stage/reducer fold that *calls* `JsonPatch.apply`; 2.13 `StateConflict.incomingPatches: List<JsonPatchOp>`).

## Dev Notes

### What this story is — and is not
- **Is:** the sealed `JsonPatchOp` union (parent + six freezed subtypes with `fromJson`/`toJson`), the `JsonPatch.apply` strict-mode RFC 6902 engine, an internal RFC 6901 JSON Pointer resolver, and the official conformance suite at ≥95% coverage.
- **Is not:** `StateDeltaEvent`/any event subtype (2.6), the verify-stage empty-patch drop (2.11), the apply *pipeline stage* / reducer that *folds* patches into `ChatState` (2.11/2.12), `StateConflict`/`LastWriterWinsResolver` (2.13), the barrel export (2.15), or any new error type (reuse 2.3's `ProtocolError`). Do **not** stub these — placeholders invite churn (the discipline 2.1/2.2/2.3 held).

### Vendor-inline is the architecture's explicit call (AR-6 / Bonus)
`package:json_patch` 3.0.0 was last published ~4 years ago; for a "zero-churn" v1 SDK that is a material risk. The architecture's **Bonus decision** (architecture.md lines 385–398) is: *vendor inline, ~300 LOC, strict-mode RFC 6902 under `koel_core/lib/src/json_patch/`*, removing the dependency and shipping `JsonPatch.apply` + `JsonPatchOp` + an internal RFC-6902-mirroring test suite. This is the same "small algorithm with churn risk → implement in-house" rationale that rejected `package:sse` (Addendum D.7) and aligns with the "read framework source" principle. **Do not** add the dependency back to satisfy any AC.

### freezed idiom — reuse 2.3 verbatim (do not reinvent)
The sealed-parent + freezed-subtype shape is identical to `KoelError` (Story 2.3, `lib/src/error/koel_error.dart` — read it). The one new wrinkle is the **custom `toJson` method + `fromJson` factory** on a freezed type without `json_serializable`:
```dart
// json_patch_op.dart  (one sealed library)
import 'package:freezed_annotation/freezed_annotation.dart';
import '../error/koel_error.dart';
import '../error/koel_error_code.dart';

part 'json_patch_op.freezed.dart';

sealed class JsonPatchOp {
  const JsonPatchOp();

  /// Dispatch on the RFC 6902 `op` discriminator. Throws
  /// [ProtocolError]`(protocolMalformed)` on unknown op or missing member.
  factory JsonPatchOp.fromJson(Map<String, dynamic> json) {
    final op = json['op'];
    String req(String k) => json.containsKey(k)
        ? json[k] as String
        : throw ProtocolError(
            message: 'JSON Patch op missing required member: $k',
            code: KoelErrorCode.protocolMalformed, cause: json);
    Object? reqValue() => json.containsKey('value')
        ? json['value']
        : throw ProtocolError(
            message: 'JSON Patch op missing required member: value',
            code: KoelErrorCode.protocolMalformed, cause: json);
    return switch (op) {
      'add'     => AddOp(path: req('path'), value: reqValue()),
      'remove'  => RemoveOp(path: req('path')),
      'replace' => ReplaceOp(path: req('path'), value: reqValue()),
      'move'    => MoveOp(from: req('from'), path: req('path')),
      'copy'    => CopyOp(from: req('from'), path: req('path')),
      'test'    => TestOp(path: req('path'), value: reqValue()),
      _ => throw ProtocolError(
            message: 'Unknown JSON Patch op: $op',
            code: KoelErrorCode.protocolMalformed, cause: json),
    };
  }

  Map<String, dynamic> toJson();
}

@freezed
abstract class AddOp extends JsonPatchOp with _$AddOp {
  const AddOp._() : super();           // private ctor enables `extends` + custom methods
  const factory AddOp({required String path, Object? value}) = _AddOp;

  @override
  Map<String, dynamic> toJson() => {'op': 'add', 'path': path, 'value': value};
}
// RemoveOp{path}, ReplaceOp{path,value}, MoveOp{from,path},
// CopyOp{from,path}, TestOp{path,value} follow the same shape.
```
- The `const SubType._() : super();` private constructor is what lets a freezed class **both** `extends` the hand-written sealed parent **and** carry a custom `toJson` body (freezed 3.x). Proven by `KoelError`/`UnknownAgUiEvent`. **Verify with `build_runner`, do not assume** (retro A1).
- Deep structural equality on `value: Object?` (nested Map/List) falls out of freezed's `const DeepCollectionEquality()` — the same mechanism behind `RunAgentInput.reasoningEcho` (2.1), `UnknownAgUiEvent.rawJson` (2.2), `BusinessError.details` (2.3). Do **not** hand-write `==`/`hashCode`.
- **Why hand-rolled (de)serialization, not `json_serializable`:** RFC 6902 is a *discriminated union* keyed on `op`; `json_serializable` does not model that cleanly, and `KoelError` already set the freezed-only (no `*.g.dart`) precedent for koel_core union types. `fromJson`/`toJson` here are ~6 trivial maps. (Note: `fromJson`/`toJson` belong to `JsonPatchOp` itself — they are this story's type, not a 2.6 concern; 2.6 simply *consumes* them when (de)serializing `StateDeltaEvent.patches`.)

### RFC 6902 strict-mode semantics (the conformance suite probes every row)
Apply to a **deep copy**; on any violation throw `ProtocolError(protocolMalformed)`; never partially apply.

| Op | Required members | Success rule | Throws `ProtocolError` when |
|----|------------------|--------------|------------------------------|
| `add` | `path`, `value` | Object key: insert/replace. Array index `i` (0 ≤ i ≤ len): insert+shift. `-`: append. `""` (root): replace whole doc. | Parent path missing; array index > len; non-integer/leading-zero index |
| `remove` | `path` | Object: delete key. Array: delete+shift. | Target path does not exist |
| `replace` | `path`, `value` | = remove + add at same path (target must pre-exist). | Target path does not exist |
| `move` | `from`, `path` | Remove value at `from`, add it at `path`. | `from` missing; `from` is a *proper prefix* of `path` (can't move into own child) |
| `copy` | `from`, `path` | Deep-copy value at `from`, add it at `path`. | `from` missing |
| `test` | `path`, `value` | Deep-equal the value at `path` to `value` (strings, numbers, ordered arrays, unordered objects, null). | Value at `path` ≠ `value`, or `path` missing |

- **JSON Pointer (RFC 6901):** `""` = whole doc; `/` separates tokens; unescape **`~1`→`/` first, then `~0`→`~`**. Array tokens must be a non-negative decimal with **no leading zeros** (`0`, `12` ok; `01`, `-1`, `1.0`, `a` → error); `-` is the end-of-array token, valid only as the final token of an `add` (and `move`/`copy` target).
- **Atomicity / non-mutation:** the engine clones the input, mutates the clone, and returns it; on failure it throws and discards the clone — the caller's `document` is structurally untouched. This is the contract Story 2.12's reducer-purity test depends on (`reduce(s, e)` must not mutate `s.state`). Do not take shortcuts that mutate the input in place.
- **Number equality in `test`:** the suite includes cases like `1` vs `1.0`; follow the json-patch-tests expectations (Dart's `1 == 1.0` is `true`, but `DeepCollectionEquality` on the raw decoded JSON may differ — write the `test` comparison to match the fixtures and document the rule you chose in Completion Notes).

### Fixture provenance (OSS hygiene — Epic 1/9 brand-license discipline)
The canonical, de-facto-standard RFC 6902 conformance corpus is **`json-patch/json-patch-tests`** on GitHub (`tests.json` = community edge cases, `spec_tests.json` = the RFC's own §A examples). Vendor both files under `test/json_patch/rfc6902_fixtures/`, **pin a specific commit SHA**, and record source URL + SHA + retrieval date + upstream license in a `PROVENANCE.md` beside them. (koel is a premium OSS SDK with active brand/license diligence — see Epic 1 Story 1.6 / `brand-reservation.md`; vendored test data needs a paper trail for the Epic 9 publish-readiness gate.) Fixture schema per entry: `{ "comment"?, "doc", "patch", "expected"? | "error"?, "disabled"? }` — `expected` ⇒ success path; `error` (string) ⇒ must-throw path; `disabled: true` ⇒ skip; absence of both `expected`/`error` follows the suite convention (no-op / doc unchanged) — handle and document explicitly.

### koel_lints + `JsonPatchOp` (don't trip `melos run analyze`)
`koel_lints`' `exhaustive_switch_must_have_default` keys on a fixed name set: `_sealedNames = {'AgUiEvent', 'KoelError', 'MessageSegment'}` (`packages/koel_lints/lib/src/rules/exhaustive_switch_must_have_default.dart`). **`JsonPatchOp` is NOT in that set**, so a `switch` over it does not require a `default:` — and you should **not** add it to `_sealedNames` (out of scope; `JsonPatchOp` is an internal apply-engine type, not a consumer-facing forward-compat surface like the events/errors). Separately, beware the analyzer's own `unreachable_switch_default`: the `fromJson` dispatch uses a `switch` *expression* with a `_ =>` arm over a `String` (`op`) — that is fine (non-exhaustive domain). Do not write a default-less `switch` *statement* over a `JsonPatchOp` value in the analyzed tree.

### Public surface & signature rationale
- **`JsonPatch.apply(Object? document, List<JsonPatchOp> patches) → Object?`** — accepts/returns `Object?` (not `Map<String,dynamic>`) so the engine passes the full RFC conformance suite, whose document roots include arrays and scalars and whose root `""` operations change the top-level type. AG-UI `STATE_*` payloads are JSON objects, so the reducer (2.12) passes a `Map<String,dynamic>` and casts the result — note this in the dartdoc. Expose `apply` as a `static` on a non-instantiable `class JsonPatch { const JsonPatch._(); }` (no instance state; mirror how `DefaultErrorClassifier` is a plain class but `JsonPatch` is a pure function holder).
- The internal JSON Pointer resolver stays **private** to the library (not exported, not in the barrel) — it is an implementation detail of `apply`.

### Project Structure Notes
- Files land exactly at the architecture-specified paths (architecture.md lines 797–799, 814): `lib/src/json_patch/json_patch.dart` (RFC 6902 strict-mode apply), `lib/src/json_patch/json_patch_op.dart` (the six op subtypes). Tests mirror path-for-path under `test/json_patch/` with `rfc6902_fixtures/` holding the vendored corpus (architecture line 814 "mirrors RFC 6902 fixtures").
- **Naming:** `snake_case.dart` files; `UpperCamelCase` types (`JsonPatch`, `JsonPatchOp`, `AddOp`…); `lowerCamelCase` members. No `print`, no `catch (_) {}` (architecture §3/§5).
- **Barrel deferred:** do **not** export to `lib/koel_core.dart` — it is the frozen 1.x contract finalized in Story 2.15 (where the `dart_apitool` baseline is taken). In-package tests import `src/` paths directly (legal; the `lib/src/` privacy rule bans only *cross-package* `src/` imports — convention §2).
- **Existing scaffold (do not regress):** `koel_core/pubspec.yaml` already carries `freezed_annotation: ^3.1.0`, `json_annotation: ^4.12.0`, dev-deps `freezed: 3.2.6-dev.1` + `json_serializable: ^6.8.0` + `build_runner` + `test` + path `koel_lints:`. `build.yaml` sets `json_serializable.field_rename: none`. **No pubspec or build.yaml changes are needed** (no new deps; `JsonPatchOp` uses only `freezed_annotation` + the in-package `ProtocolError`/`KoelErrorCode`). The workspace-root `analysis_options.yaml` enables the `koel_lints` plugin; `koel_core` carries no local `analysis_options.yaml`.

### Toolchain (carried from Stories 2.1–2.3 — unchanged, do not modify)
- freezed `3.2.6-dev.1` + `freezed_annotation ^3.1.0`; analyzer pinned to 12 across the workspace (analyzer-12 stopgap, SCP-2026-05-29-B / architecture D2 + D3) so freezed and `analysis_server_plugin 0.3.14` coexist in one pub-workspace resolution. Dart 3.12 / Flutter 3.44 (`.tool-versions`). SDK floor `>=3.11.0` (pubspec).
- CI is already codegen-aware (Story 2.1): `ci.yml` runs `melos run build` before `analyze`/`test`; `codegen-drift.yml` is a real determinism gate; `format:check` excludes generated output (`*.freezed.dart`/`*.g.dart`/`*.mocks.dart` via `tool/format.sh`). **This story adds no CI work.**
- Run tests via `dart test` directly in `packages/koel_core` (`melos run test` remains a Story 2.15 stub). Generated files gitignored at repo root (`.gitignore` lines 6–7: `*.g.dart`, `*.freezed.dart`).

### Coverage gate (AC3 — ≥95%, the only hard coverage AC in Epic 2 so far)
Unlike 2.3 (where ≥90% was deferred to 2.5/2.15), **2.4 gates at ≥95% line + branch on `lib/src/json_patch/`**. The conformance corpus covers most positive/negative behavior; backfill hand-written tests for any defensive branch the fixtures miss (e.g. the `fromJson` unknown-op arm, a leading-zero index guard, the `move`-into-descendant guard). Measure with `dart test --coverage` + `format_coverage` scoped to `--report-on=lib/src/json_patch`.

### Git intelligence (recent work patterns to follow)
- `b1e0f0d feat(story-2.3)` — immediate predecessor; the sealed-parent + freezed-subtype idiom, the `ProtocolError(protocolMalformed)` type you throw here, freezed-only (no `*.g.dart`) posture, and the seeded-`Random` in-house property-test style. **Reuse all of these.**
- `3a6e54d feat(story-2.2)` — `UnknownAgUiEvent` established the private-`._()`-ctor `extends` pattern and `DeepCollectionEquality`; the `event_deserializer.dart` registry dispatch is the analogue of your `JsonPatchOp.fromJson` discriminator (read it for the dispatch style).
- `e944807 feat(story-2.1)` — codegen pipeline + the `abstract class … with _$X` freezed idiom origin.
- Commit style: Conventional Commits scoped `feat(story-2.4): …`. Do not commit generated files.

### References
- [Source: _bmad-output/planning-artifacts/epics/epic-2-protocol-kernel-koelcore.md#Story 2.4] — story statement + ACs (authoritative for scope); cross-story consumers (2.6 `StateDeltaEvent.patches`, 2.11/2.12 fold, 2.13 `StateConflict`).
- [Source: _bmad-output/planning-artifacts/architecture.md#Bonus — json_patch staleness concern (lines 385–398)] — the vendor-inline decision, ~300 LOC, strict-mode RFC 6902, no dependency (AR-6).
- [Source: _bmad-output/planning-artifacts/architecture.md (lines 797–799, 814)] — exact file paths: `lib/src/json_patch/json_patch.dart` + `json_patch_op.dart`; `test/json_patch/` mirrors RFC 6902 fixtures.
- [Source: _bmad-output/planning-artifacts/architecture.md (lines 91, 251, 998 F-A8)] — `json_patch` (vendor-inline) backs F-A8 JSON-Patch state; consumed by `state/state_conflict.dart` (2.13).
- [Source: _bmad-output/planning-artifacts/architecture.md#3. Type & data conventions (lines 513–546)] — freezed for >1-field immutables; `const` everywhere; `copyWith`-only mutation; reducer/apply must not mutate input.
- [Source: packages/koel_core/lib/src/error/koel_error.dart] — the `ProtocolError(message, code, cause, eventType?)` type this story throws (no new error type); the sealed-parent + freezed-subtype idiom to mirror.
- [Source: packages/koel_core/lib/src/event/ag_ui_event.dart + event_deserializer.dart] — the freezed sealed-union + discriminator-dispatch precedent for `JsonPatchOp` + `fromJson`.
- [Source: packages/koel_core/pubspec.yaml + build.yaml + .gitignore] — current deps/codegen config (no change needed); generated-file gitignore at root.
- [Source: packages/koel_lints/lib/src/rules/exhaustive_switch_must_have_default.dart] — `_sealedNames = {'AgUiEvent','KoelError','MessageSegment'}`; `JsonPatchOp` is deliberately NOT included.
- [Source: _bmad-output/implementation-artifacts/2-3-sealed-koel-error-hierarchy.md] — predecessor; freezed-only posture, "verify build_runner don't assume" (retro A1), barrel/CI deferral discipline, in-house property testing.
- [Reference: json-patch/json-patch-tests (GitHub) — `tests.json` + `spec_tests.json`] — the canonical RFC 6902 conformance corpus to vendor (pin a SHA; record provenance + license).
- [Reference: RFC 6902 (JSON Patch) + RFC 6901 (JSON Pointer)] — normative op + pointer semantics (escaping, array tokens, `-` end-of-array, atomicity).

## Review Findings

_Code review 2026-05-30 (3 adversarial layers: Blind Hunter, Edge Case Hunter, Acceptance Auditor). Acceptance Auditor: all 5 ACs PASS. Findings below are robustness/contract-fidelity gaps surfaced beyond the ACs._

- [x] [Review][Patch] Non-String map keys escape the `ProtocolError` contract — `_deepCopy` did `entry.key as String`, so a `document` carrying a `Map` with non-String keys threw a raw `TypeError` (not `ProtocolError`). Decision (Si): **harden**. Fixed: `_deepCopy` now validates each key `is String` and throws `ProtocolError(protocolMalformed)` on a non-String key. Wire pipeline never triggered it (`fromJson`/`jsonDecode` yield `Map<String,dynamic>`); this is defense-in-depth for programmatically-built documents. Test added (`json_patch_apply_test.dart`: "a document with a non-String map key throws"). [json_patch.dart:75]
- [x] [Review][Patch] Overflow array-index token threw raw `FormatException` instead of `ProtocolError` [json_patch/json_pointer.dart:53] — confirmed: `apply({'a':[1]}, [AddOp(path:'/a/99999999999999999999', …)])` escaped `FormatException: Positive input exceeds the limit of integer`. Reachable from wire data; web-safety hazard (dart2js `int` is double-backed). Fixed: `parseArrayIndex` now returns `int.tryParse(token)` (null on overflow → caught by existing `index == null` guards). Tests added (`json_pointer_test.dart` overflow → null; `json_patch_apply_test.dart` apply → throwsMalformed).
- [x] [Review][Patch] Conformance harness did not implement the documented no-op convention [json_patch/rfc6902_conformance_test.dart] — `else` branch always asserted `result == equals(entry['expected'])`, mis-asserting `result == null` for any future entry lacking both `expected`/`error`. Moot at pinned SHA `2a928f9` (zero such entries) but contradicted the documented no-op (doc-unchanged) convention. Fixed: success branch now asserts `equals(containsKey('expected') ? expected : doc)`.

**Dismissed as noise (recorded for traceability):** (1) "move is non-atomic" — false at the API boundary: `apply` deep-copies the input up front and discards the half-applied copy on throw; covered by `json_patch_apply_test.dart` "a failing op leaves the caller input structurally unchanged". (2) `_deepEquals` treats `1 == 1.0` — RFC 6902 §4.6 numeric-value equality, documented in Completion Notes; `NaN` is not representable in JSON. (3) Untested-but-correct behaviors (copy-into-descendant permitted, `move` no-op when `from == path`, `-` rejected as a read index) — all RFC-conformant; coverage is a nice-to-have, not a defect.

## Dev Agent Record

### Agent Model Used

claude-opus-4-8[1m] (Opus 4.8, 1M context) — via the `/agent-flutter-engineer` specialist persona (Implement mode).

### Debug Log References

- `dart test` (koel_core baseline) → 54 passing before implementation.
- Task 1: `json_patch_op_test.dart` → RED (type undefined) → `build_runner build` emitted `json_patch_op.freezed.dart` only (**no** `*.g.dart`) → 28 green.
- Task 2: `json_pointer_test.dart` → RED → 19 green. `/~01` unescape verified (`~1` then `~0` order → `~1`).
- Task 3: `json_patch_apply_test.dart` → RED → 32 green. `dart analyze` clean — the exhaustive `JsonPatchOp` switch needs no `default:` (koel_lints doesn't key on `JsonPatchOp`).
- Task 4: fetched `json-patch/json-patch-tests` @ `2a928f9` (tests.json + spec_tests.json); `rfc6902_conformance_test.dart` → 108/108 non-disabled entries green on first run. Coverage on `lib/src/json_patch/` (excl. generated) = 99.35% line.
- `dart run build_runner build` re-run → wrote 0 outputs (deterministic; codegen-drift green).
- `melos run analyze` → SUCCESS (12 packages). `melos run format:check` → 0 changed (after one `dart format` pass + one brace fix on a formatter-reflowed early-return).
- `dart test` (final) → 241 passing (54 existing + 187 new: 28 op + 19 pointer + 32 apply + 108 conformance).

### Completion Notes List

- **Scope held exactly.** Shipped `JsonPatchOp` (sealed + 6 freezed subtypes with hand-rolled `fromJson`/`toJson`), the `JsonPatch.apply` strict-mode engine, the internal `json_pointer.dart` resolver, and the RFC 6902 conformance suite. No `StateDeltaEvent`/event subtype, no pipeline/verify stage, no reducer, no `StateConflict`, no barrel export, no CI change, no `json_serializable` on ops, no new error type. Reused Story 2.3's `ProtocolError(protocolMalformed)` for every failure.
- **freezed-3.x sealed-subtype idiom reused verbatim from 2.2/2.3.** Each op is `@freezed abstract class X extends JsonPatchOp with _$X` + `const X._() : super();`. The private `._()` ctor is also what lets each subtype carry a hand-written `@override Map<String,dynamic> toJson()` body. Verified by running `build_runner`, not assumed (retro A1). `value: Object?` compares deeply via freezed's `DeepCollectionEquality`.
- **`fromJson` discriminator + no `*.g.dart`.** `JsonPatchOp.fromJson` switches on `op` and throws `ProtocolError(protocolMalformed)` for unknown op / missing required member (`path`/`value`/`from`). A present-but-`null` `value` is preserved (RFC distinguishes "absent" from "JSON null") via `containsKey('value')`. Freezed-only posture confirmed: only `json_patch_op.freezed.dart` generated.
- **Pointer resolver placement (design call).** The story sketched the pointer util as library-private inside `json_patch.dart`, but the RED step wanted a *separate* `json_pointer_test.dart` exercising it directly — library-private (`_`-prefixed) symbols aren't reachable cross-file. Resolved by giving it its own `lib/src/json_patch/json_pointer.dart` with package-visible symbols (`parseJsonPointer`, `parseArrayIndex`, `endOfArrayToken`, `resolvePointer`, `missing` sentinel), tested via a `src/` import and **never added to the barrel** (the real public surface, frozen until 2.15). Same posture as `event_deserializer.dart`.
- **`missing` sentinel** distinguishes "reference absent" from "present-but-JSON-null" — `resolvePointer` returns `null` for a real null and `identical(x, missing)` for not-found, so `test`/`move`/`copy` correctly reject missing targets while accepting null values.
- **Atomicity + non-mutation honored.** `apply` deep-copies the document first, mutates only the copy, and on any op failure throws — the caller's object graph is never touched (verified: a 3-op patch failing on op 2 leaves the input structurally equal; the returned tree is a distinct object graph). This is the contract Story 2.12's reducer-purity test will rely on.
- **`test`-op number equality.** `_deepEquals` is hand-rolled (no `package:collection` dep — keeps `koel_core` dependency-free) with scalar comparison via Dart `==`, so `1 == 1.0` is equal. The conformance suite's "Comparing Strings and Numbers" (spec A.15) and leading-zero cases pass; the 4 `disabled` upstream entries are skipped (they probe impl-specific behavior the RFC leaves open).
- **Root-targeting ops.** `add`/`replace` at `path: ""` replace the whole document (engine signature is `Object?` for this reason); `remove` at `""` throws (no meaningful semantics) — matches the conformance corpus.
- **Formatter interaction.** `dart format` reflowed one `_replace` early-return into a brace-less two-line `if`, tripping `curly_braces_in_flow_control_structures`; fixed by moving the explanatory comment above the guard so it stays a short one-liner. Final `format:check` + `analyze` both green.
- **Cross-story handoffs:** 2.6 consumes `StateDeltaEvent.patches: List<JsonPatchOp>` and round-trips them via `JsonPatchOp.fromJson`/`toJson`; 2.11/2.12's apply stage + `DefaultChatStateReducer` *call* `JsonPatch.apply` to fold STATE_DELTA into `ChatState`; 2.13's `StateConflict.incomingPatches` is `List<JsonPatchOp>`.

### File List

- `packages/koel_core/lib/src/json_patch/json_patch_op.dart` (new) — sealed `JsonPatchOp` + `AddOp`/`RemoveOp`/`ReplaceOp`/`MoveOp`/`CopyOp`/`TestOp` freezed subtypes + `fromJson`/`toJson`.
- `packages/koel_core/lib/src/json_patch/json_patch_op.freezed.dart` (new, generated, gitignored) — freezed `==`/`hashCode`/`copyWith`.
- `packages/koel_core/lib/src/json_patch/json_pointer.dart` (new) — RFC 6901 `parseJsonPointer`/`parseArrayIndex`/`resolvePointer` + `endOfArrayToken`/`missing` (package-visible, not barrelled).
- `packages/koel_core/lib/src/json_patch/json_patch.dart` (new) — `JsonPatch.apply` strict-mode RFC 6902 engine.
- `packages/koel_core/test/json_patch/json_patch_op_test.dart` (new) — 28 tests (construction, structural/deep equality, copyWith, fromJson/toJson round-trip, negative parse cases).
- `packages/koel_core/test/json_patch/json_pointer_test.dart` (new) — 19 tests (tokenize/unescape order, index validation, resolve + missing sentinel).
- `packages/koel_core/test/json_patch/json_patch_apply_test.dart` (new) — 32 tests (each op positive+negative, non-mutation, atomicity, root ops, malformed pointer).
- `packages/koel_core/test/json_patch/rfc6902_conformance_test.dart` (new) — official corpus harness (108 entries).
- `packages/koel_core/test/json_patch/rfc6902_fixtures/tests.json` (new, vendored @ `2a928f9`) — community edge-case corpus.
- `packages/koel_core/test/json_patch/rfc6902_fixtures/spec_tests.json` (new, vendored @ `2a928f9`) — RFC 6902 Appendix A corpus.
- `packages/koel_core/test/json_patch/rfc6902_fixtures/PROVENANCE.md` (new) — source/SHA/date/license (Apache-2.0) record.
- `_bmad-output/implementation-artifacts/sprint-status.yaml` (modified) — 2-4 → in-progress → review.

### Change Log

- 2026-05-30 — Implemented Story 2.4: vendor-inline RFC 6902 JSON Patch in `koel_core` — sealed `JsonPatchOp` (6 freezed ops, `fromJson`/`toJson`), strict-mode `JsonPatch.apply` (atomic, non-mutating), RFC 6901 pointer resolver, and the official `json-patch/json-patch-tests` conformance suite (108/108 non-disabled, vendored @ `2a928f9`, Apache-2.0). 187 new tests, 241 total green; 99.35% line coverage on `lib/src/json_patch/`; `melos analyze`/`format:check` green; freezed-only codegen, deterministic; no `package:json_patch`, no new dep. Status → review.
