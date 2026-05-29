---
baseline_commit: 3a6e54db569549638049fa081abf30884b6007eb
---

# Story 2.3: Sealed `KoelError` hierarchy + `KoelErrorCode` enum + `DefaultErrorClassifier`

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a Flutter/Dart developer,
I want the sealed error model — `KoelError` with `TransportError | ProtocolError | AgentError | BusinessError` subtypes, the `KoelErrorCode` typed-vocabulary enum, and a `DefaultErrorClassifier` mapping raw failures to typed errors,
so that consumer code pattern-matches errors exhaustively (lint-enforced `default:` branch) and adapters classify backend-specific failures per FR-A5.

**Why this story ships before the event subtypes.** `RunErrorEvent.error: KoelError` (Story 2.5) and the verify stage's `RunErrorEvent(ProtocolError(...))` emission (Story 2.11), plus `JsonPatch.apply`'s `ProtocolError(protocolMalformed)` throw (Story 2.4), all consume the `KoelError` types defined here. Landing the error model now means those later stories reference a stable foundation instead of stubbing placeholders — the same "no churn-inducing stubs" discipline Stories 2.1 and 2.2 held.

**Scope reality check.** This story ships the error *types* + the *classifier*. It does **not** ship `RunErrorEvent` (Story 2.5), the verify-stage drop rules that *emit* `RunErrorEvent(ProtocolError)` (Story 2.11), `JsonPatch.apply` (Story 2.4), or wire JSON (de)serialization of `KoelError` (that arrives with `RunErrorEvent` in Story 2.5). The classifier *constructs* `KoelError` instances directly from raw exceptions; nothing here round-trips through JSON.

## Acceptance Criteria

**AC1 — sealed `KoelError` root + four concrete subtypes (single library)**
**Given** `koel_core/lib/src/error/koel_error.dart`,
**When** I inspect it,
**Then** `sealed class KoelError implements Exception` is declared with a `const` constructor and three abstract getters — `String get message`, `KoelErrorCode get code`, `Object? get cause`,
**And** `TransportError`, `ProtocolError`, `AgentError`, `BusinessError` are declared in this same file as concrete subtypes (a sealed type can only be extended within its own library — see Dev Notes "sealed-across-files trap, resolved"), each carrying its specialization field per Addendum A.1: `TransportError.statusCode: int?`, `ProtocolError.eventType: String?`, `AgentError.agentCode: String?`, `BusinessError.details: Map<String, dynamic>`,
**And** every subtype is freezed-generated (structural `==`/`hashCode`/`copyWith`) using the freezed-3.x "subtype `extends` a hand-written sealed parent via a private constructor" pattern proven by `UnknownAgUiEvent` in Story 2.2 — verified by running `build_runner`, not assumed.

**AC2 — `KoelErrorCode` typed-vocabulary enum**
**Given** `koel_core/lib/src/error/koel_error_code.dart`,
**When** I inspect the enum,
**Then** it lists exactly the codes from Addendum A.1, grouped by family: `transportTimeout`, `transportClosed`, `transportRefused`, `transportTlsFail`, `protocolUnknownEvent`, `protocolMalformed`, `protocolVersionDrift`, `agentRefused`, `agentToolFailed`, `agentInternal`, `businessQuotaExceeded`, `businessRateLimited`, `businessAuth`, `businessForbidden`, `unknown` (15 values),
**And** the enum lives in its own file (it is not part of the sealed library — enums need no `part` arrangement),
**And** no `koel_lints` `default:` mandate applies to this enum (the rule targets the sealed *class* `KoelError`, not this enum — adapter packages extend the code vocabulary by convention; see Dev Notes).

**AC3 — `ErrorClassifier` interface + web-safe `DefaultErrorClassifier`**
**Given** `koel_core/lib/src/error/error_classifier.dart`,
**When** I inspect it,
**Then** `abstract class ErrorClassifier` declares `KoelError classify(Object raw, StackTrace? stack, RunAgentInput input)`,
**And** `DefaultErrorClassifier implements ErrorClassifier` maps common Dart failures to the correct `KoelErrorCode` — `TimeoutException → TransportError(transportTimeout)`, `FormatException → ProtocolError(protocolMalformed)`, and the `dart:io`/`package:http` failure shapes `SocketException`, `HandshakeException`, `HttpException`, `ClientException` matched **without importing `dart:io` or `package:http`** (koel_core is web-safe and HTTP-free — see Dev Notes "web-safe classifier: the #1 trap of this story"),
**And** any unhandled raw type maps to a `KoelError` carrying `KoelErrorCode.unknown` (subtype per the recommendation in Dev Notes "the `unknown` bucket"),
**And** `classify` **never throws** — every input, including a thrown `String`/`int`/arbitrary `Object`, returns a non-null typed `KoelError`.

**AC4 — property-based classifier coverage + lint-enforced exhaustive switch**
**Given** a property-based test feeding ≥ 50 varied raw exception instances (a deterministic, seeded generator — no new dependency; see Dev Notes),
**When** the classifier runs on each,
**Then** every output is a non-null `KoelError` whose `code` is a `KoelErrorCode` value and whose `cause` references the original raw object,
**And** a consumer-style `switch` over `KoelError` written **with** a `default:` arm analyzes clean under `package:koel_lints` (the rule already keys on the `KoelError` type name — see Dev Notes; the *negative* case — a `default:`-less switch firing the error — is owned by Story 2.8's end-to-end validation and must **not** be introduced into koel_core's analyzed tree here, or `melos run analyze` breaks).

**AC5 — repo stays green; codegen produces the freezed part; nothing committed**
**Given** the workspace after this story lands,
**When** I run the toolchain,
**Then** `cd packages/koel_core && dart run build_runner build` produces `koel_error.freezed.dart` next to source with no errors **and no `*.g.dart`** (no `json_serializable` on errors — see Dev Notes "serialization scope"),
**And** `cd packages/koel_core && dart test` passes (existing 25 + the new error/classifier tests),
**And** `melos run analyze` exits 0 across the workspace (NFR-13),
**And** `melos run format:check` exits 0 (Story 2.1's `tool/format.sh` already excludes generated output),
**And** `git status` shows no `*.freezed.dart`/`*.g.dart` staged or tracked (gitignored per convention §1; CI's `codegen-drift` gate verifies determinism).

## Tasks / Subtasks

- [x] **Task 1 — `KoelErrorCode` enum (AC2)** — do this first; the types and classifier both reference it
  - [x] Create `packages/koel_core/lib/src/error/koel_error_code.dart` with the 15-value enum, grouped by `// transport` / `// protocol` / `// agent` / `// business` / `// catch-all` comment bands matching Addendum A.1's ordering exactly.
  - [x] Contract-form dartdoc on the enum (convention §6): one-line summary; that it is the typed vocabulary; that — unlike `KoelError` — consumer `switch`es over this enum are **not** lint-mandated to carry `default:`, because adapters extend the code space by convention (Addendum A.1 comment); cross-ref `[KoelError]`.
  - [x] No standalone test for a bare enum; it is exercised through the classifier tests (Task 4).

- [x] **Task 2 — sealed `KoelError` + four freezed subtypes (AC1)** — red → green → refactor
  - [x] RED: `test/error/koel_error_test.dart` — assert, per subtype: (a) `const` construction with `message` + `code` + the subtype's specialization field, `cause` optional; (b) `isA<KoelError>()` **and** `isA<Exception>()`; (c) the three base getters (`message`/`code`/`cause`) read back the constructed values; (d) **structural equality**: two instances with equal fields are `==` and share `hashCode`, differing on any field → `!=`; (e) `copyWith` updates one field, leaves others identical. Confirm RED before implementing.
  - [x] GREEN: implement `lib/src/error/koel_error.dart` as a **single library**: `import 'koel_error_code.dart';` + `part 'koel_error.freezed.dart';`, the hand-written `sealed class KoelError implements Exception { const KoelError(); String get message; KoelErrorCode get code; Object? get cause; }`, then the four freezed subtypes each as `@freezed abstract class TransportError extends KoelError with _$TransportError { const TransportError._() : super(); const factory TransportError({required String message, required KoelErrorCode code, Object? cause, int? statusCode}) = _TransportError; }` (and analogously `ProtocolError.eventType`, `AgentError.agentCode`, `BusinessError.details` — `details` defaults to `const {}` if you make it non-nullable, or keep `required`). Run `dart run build_runner build`; make tests pass. **Verify** the generated subtype fields satisfy the parent's abstract getters (the "abstract-getter-vs-freezed-field" check — see Dev Notes; do not assume, run the generator).
  - [x] REFACTOR: contract-form dartdoc per convention §6 on `KoelError` (what it represents; the "adapters NEVER throw this — they emit `RunErrorEvent` carrying it; the `Exception` marker exists only for synchronous programmer-error paths like an invalid `Uri` to `KoelClient(...)`" contract from Addendum A.1 / architecture §5; that `switch`es over it are `koel_lints`-enforced exhaustive) and on each subtype (when it is the right classification; what its specialization field means). Keep the `sealed`-restricts-subtyping rationale.

- [x] **Task 3 — `ErrorClassifier` + web-safe `DefaultErrorClassifier` (AC3)** — red → green → refactor
  - [x] RED: `test/error/error_classifier_test.dart` — for each mapping in the Dev Notes table, construct the raw exception (use real `TimeoutException`/`FormatException` from `dart:async`/`dart:core`; for the `dart:io`/`package:http` shapes, see the test note in Dev Notes "testing the web-safe matcher") and assert `classify(raw, null, <a minimal RunAgentInput>)` returns the expected subtype + `code`, with `cause == raw`. Add a case asserting a thrown `String`, an `int`, and an `ArgumentError` each yield a non-null `KoelError(code: unknown)` and **do not throw**. Confirm RED.
  - [x] GREEN: implement `lib/src/error/error_classifier.dart`: the `abstract class ErrorClassifier` with `classify(Object raw, StackTrace? stack, RunAgentInput input)`, then `DefaultErrorClassifier`. Match `dart:io`/`package:http` shapes by **runtime type name** (`raw.runtimeType.toString()`) — never by importing those types (see Dev Notes). Handle `TimeoutException`/`FormatException` by real `is` checks (those packages are web-universal). All-else → the `unknown` mapping.
  - [x] REFACTOR: contract-form dartdoc on `ErrorClassifier` (pluggable seam; "adapters subclass `DefaultErrorClassifier` to add backend-specific shapes" per architecture §5; cross-ref the per-adapter classifiers arriving in Epic 5) and `DefaultErrorClassifier` (what it covers; that it is web-safe / `dart:io`-free by design; the type-name-matching caveat). Apply the error-message convention: sentence-cased, **no trailing period** (these are data, not log lines), never interpolate user-controlled data unescaped (architecture §5).

- [x] **Task 4 — property-based coverage + positive lint switch (AC4)** — red → green
  - [x] In `test/error/error_classifier_test.dart`, add a property-based block: a deterministic seeded generator (`Random(<fixed seed>)`) that draws ≥ 50 instances from a fixed pool of raw failure shapes (the mapped ones + several deliberately-unmapped ones like `StateError`, `ArgumentError`, a thrown `String`, a thrown `int`, a custom `Exception`). Assert each `classify(...)` output is non-null, `code` is a `KoelErrorCode`, and `cause` is the input. Use a `switch (result) { case TransportError(): … case ProtocolError(): … case AgentError(): … default: … }` **with a `default:` arm** to bucket/verify — this is the "consumer switch over `KoelError`" that AC4 wants to analyze clean under `koel_lints`. (Note: the switch is deliberately *non-exhaustive* — see Completion Notes "tooling tension".)
  - [x] Confirm `melos run analyze` stays 0 (the positive switch carries `default:`; do **not** add a `default:`-less switch anywhere in the analyzed tree — that negative end-to-end belongs to Story 2.8).

- [x] **Task 5 — Definition-of-done validation (AC5)**
  - [x] `cd packages/koel_core && dart run build_runner build` → exits 0, emits `koel_error.freezed.dart` (and **no** `koel_error.g.dart` / no `*.g.dart` for the error types).
  - [x] `cd packages/koel_core && dart test` → all green (existing 25 + new error/classifier tests = 53 total).
  - [x] `melos run analyze` → exits 0 across the workspace (NFR-13).
  - [x] `melos run format:check` → exits 0.
  - [x] `git status` / `git ls-files '*.freezed.dart' '*.g.dart'` → no generated files staged/tracked.
  - [x] **Do not** populate `lib/koel_core.dart` (barrel frozen until Story 2.15). **Do not** add CI changes (codegen-aware since 2.1). **Do not** create `RunErrorEvent`, the verify stage, `JsonPatch`, or any event subtype. **Do not** add `json_serializable` to the error types.
  - [x] Update File List + Completion Notes + Change Log; record cross-story handoffs (2.4 `JsonPatch.apply` throws `ProtocolError(protocolMalformed)`; 2.5 `RunErrorEvent.error: KoelError` + KoelError wire JSON; 2.8 negative-case exhaustive-switch end-to-end; Epic 5 per-adapter `DefaultErrorClassifier` subclasses).

## Dev Notes

### What this story is — and is not
- **Is:** the sealed `KoelError` union (parent + four freezed subtypes), the `KoelErrorCode` enum, and the `ErrorClassifier` interface + web-safe `DefaultErrorClassifier`.
- **Is not:** `RunErrorEvent` or any event subtype (2.5–2.8), the verify stage that *emits* `RunErrorEvent(ProtocolError)` (2.11), `JsonPatch.apply` (2.4), `KoelError` wire (de)serialization (lands with `RunErrorEvent` in 2.5), `AgentSubscriber.onRunError` wiring (2.10), or the barrel/perf/coverage finalize (2.15). Do **not** stub any of these — placeholders invite churn (the discipline 2.1/2.2 held).

### Web-safe classifier: the #1 trap of this story
`koel_core` **must not import `dart:io` or `package:http`.** It is the framework-free, six-platform kernel; web has no `dart:io` (architecture line 59: *"web requires SSE-over-XHR fallback (no `dart:io`)"*; `dart:io` socket usage is confined to `koel_http`'s native transport, D4). The epic AC lists `SocketException`, `HandshakeException`, `HttpException` (all `dart:io`) and `ClientException` (`package:http`) under `DefaultErrorClassifier` — which lives in `koel_core`. Importing those types to `is`-check them would break every web build and violate the kernel's platform contract.

**Resolution (web-safe, zero-dependency): match by runtime type name.**
```dart
KoelError classify(Object raw, StackTrace? stack, RunAgentInput input) {
  if (raw is TimeoutException) {            // dart:async — web-universal, real `is` check
    return TransportError(message: 'Request timed out', code: KoelErrorCode.transportTimeout, cause: raw);
  }
  if (raw is FormatException) {             // dart:core — web-universal, real `is` check
    return ProtocolError(message: 'Malformed payload', code: KoelErrorCode.protocolMalformed, cause: raw);
  }
  switch (raw.runtimeType.toString()) {     // dart:io / package:http — matched by NAME, never imported
    case 'SocketException':
      return TransportError(message: 'Connection failed', code: KoelErrorCode.transportRefused, cause: raw);
    case 'HandshakeException':
      return TransportError(message: 'TLS handshake failed', code: KoelErrorCode.transportTlsFail, cause: raw);
    case 'HttpException':
    case 'ClientException':
      return TransportError(message: 'Transport closed', code: KoelErrorCode.transportClosed, cause: raw);
    default:
      return AgentError(message: 'Unclassified failure', code: KoelErrorCode.unknown, cause: raw);
  }
}
```
- This satisfies the epic AC **verbatim** (`DefaultErrorClassifier` *does* handle those shapes) while honoring koel_core's no-`dart:io`/no-`package:http` constraint and adding **no dependency** (project ethos: no needless deps).
- Type-name matching is the pragmatic standard for framework-free error classification that must run on web. The brittleness (a future SDK rename of `SocketException`) is acceptable for these long-stable types; **document the caveat** in the `DefaultErrorClassifier` dartdoc.
- The richer, status-code-aware mapping (HTTP 429 → `businessRateLimited`, 401 → `businessAuth`, 403 → `businessForbidden`) is **not** this story's job — it belongs to `koel_http`/adapter subclasses of `DefaultErrorClassifier` (Epic 4/5), which *can* import `dart:io` and inspect status codes. The base classifier maps raw Dart exception *shapes* only.

> This is the strongest candidate for a clarifying-question discussion (see end of story). The alternative — splitting the `dart:io` mappings out of `koel_core` into a `koel_http` subclass — would contradict the epic AC's explicit "`DefaultErrorClassifier` ships handling … `SocketException`, `HandshakeException` …". The story honors the epic (these stay in `koel_core`) via the web-safe name-match.

### The `unknown` bucket — a recommendation + a flagged inconsistency
The epic mandates unhandled raw types → `KoelErrorCode.unknown`. But `classify` returns a `sealed KoelError`, so a *subtype* must be chosen, and the hierarchy is exactly `Transport | Protocol | Agent | Business` — none is an obvious home for "we couldn't classify this."
- **Recommendation (use this unless the clarifying answer says otherwise):** `AgentError(code: KoelErrorCode.unknown)`. Rationale: transport/protocol/business are domains the classifier *positively* identifies from the exception shape; anything it cannot identify is, from the SDK's vantage, an opaque failure at the agent-execution boundary — `AgentError` is the least-wrong bucket. The `code` (`unknown`) and the subtype are orthogonal, so this is consistent.
- **Flagged inconsistency:** architecture §3 (line ~522) says a default `switch` arm over errors *"rethrows with a wrapping `UnknownError`"* — implying a 5th subtype `UnknownError` that neither Addendum A.1 nor the epic AC declares. This is a doc inconsistency, not a green-light to add a type: **do not introduce `UnknownError`** (out of AC scope). It is raised as a clarifying question for the team to reconcile (architecture §3 ↔ Addendum A.1).

### Sealed-across-files trap, resolved (and why subtypes share one file here)
A `sealed` type can only be `extends`-ed within its own *library*. Story 2.2 hit this: `UnknownAgUiEvent` in a separate file had to become `part of 'ag_ui_event.dart'`. **For this story it's simpler:** the epic AC1 puts all four subtypes in `koel_error.dart` itself, so they are in the same library as `sealed class KoelError` by construction — no `part 'subtype.dart'` gymnastics needed. The only `part` directive is `part 'koel_error.freezed.dart';` (freezed emits one shared part per library root). Layout:
```dart
// koel_error.dart  (the whole sealed library)
import 'package:freezed_annotation/freezed_annotation.dart';
import 'koel_error_code.dart';

part 'koel_error.freezed.dart';

sealed class KoelError implements Exception {
  const KoelError();
  String get message;
  KoelErrorCode get code;
  Object? get cause;
}

@freezed
abstract class TransportError extends KoelError with _$TransportError {
  const TransportError._() : super();
  const factory TransportError({
    required String message,
    required KoelErrorCode code,
    Object? cause,
    int? statusCode,
  }) = _TransportError;
}
// ProtocolError (eventType: String?), AgentError (agentCode: String?),
// BusinessError (details: Map<String, dynamic>) follow the same shape.
```
- `const SubType._() : super();` is the freezed-3.x private constructor that lets a freezed class `extend` a hand-written parent (proven by `UnknownAgUiEvent` in 2.2; the analogue of 2.1's `AbstractAgent` trap). **Verify with `build_runner`, do not assume** (retro lesson A1).
- **Abstract-getter check:** the parent declares `message`/`code`/`cause` as abstract; each subtype's freezed factory supplies same-named fields, so the generated `_$SubType` mixin satisfies them. Confirm this compiles after the *first* `build_runner` run before writing more subtypes — if freezed objects to the abstract-getter overlap, that's the signal to adjust (it should not, given the field names match).
- Structural deep equality on `BusinessError.details: Map<String, dynamic>` falls out of freezed's `const DeepCollectionEquality()` — the exact mechanism behind `RunAgentInput.reasoningEcho` (2.1) and `UnknownAgUiEvent.rawJson` (2.2). Do not hand-write `==`/`hashCode`.

### Serialization scope (errors are freezed-only here — no `*.g.dart`)
Do **not** add `json_serializable`/`fromJson`/`toJson` to the error types in this story. Wire (de)serialization of `KoelError` is needed only when `RunErrorEvent` lands (Story 2.5) and can be designed then alongside the `RUN_ERROR` wire shape. Here the classifier *constructs* errors from raw exceptions — there is no JSON path. So `koel_error.dart` generates **`koel_error.freezed.dart` only, no `koel_error.g.dart`** (same freezed-only posture as `RunAgentInput`/`UnknownAgUiEvent`). This also keeps the `cause: Object?` field — which often holds a non-serializable exception — out of any premature JSON contract.

### `KoelErrorCode` is NOT lint-mandated (but `KoelError` is)
`koel_lints`' `exhaustive_switch_must_have_default` already keys on the *type name* `KoelError` (`packages/koel_lints/lib/src/rules/exhaustive_switch_must_have_default.dart` → `_sealedNames = {'AgUiEvent', 'KoelError', 'MessageSegment'}`). So the moment `KoelError` exists, a consumer `switch` over it without `default:` fires — **no koel_lints change is needed** for AC4. The enum `KoelErrorCode` is deliberately *not* in `_sealedNames`: Addendum A.1 states adapter packages extend the code vocabulary by convention, so mandating `default:` on the enum would be wrong. Don't touch `koel_lints`.
- **AC4 scope, precisely:** demonstrate a *positive* exhaustive `switch` over `KoelError` (with `default:`) analyzing clean — the property test's bucketing switch is exactly this. The *negative* case (a `default:`-less switch firing `error` severity end-to-end) is **Story 2.8's** job and must not enter koel_core's analyzed tree here, or `melos run analyze` (AC5) breaks. koel_lints' own fixture test already proves the rule fires generically.

### Property-based test without a new dependency
Stories 2.1 (`reasoningEcho` deep-equality) and 2.7 (planned 100-random-byte round-trip) do property-style testing in-house with `package:test` only — match that. Use a fixed-seed `Random(<seed>)` to draw ≥ 50 instances from a hardcoded pool of raw failure shapes (the mapped types + several unmapped: `StateError`, `ArgumentError`, custom `Exception`, thrown `String`, thrown `int`). Deterministic seed = reproducible failures. **Do not** add `package:glados`/`fast_check`/etc. — no new dep.

### Testing the web-safe matcher
The classifier matches `dart:io` shapes by name, so the *test* needs instances whose `runtimeType.toString()` equals `'SocketException'` etc. Two options — pick whichever keeps the test web-runnable:
- **Test-only `dart:io` import** in `test/error/error_classifier_test.dart` to construct real `SocketException`/`HandshakeException`/`HttpException` (tests run on the VM, where `dart:io` exists; the *library* stays clean — only the test file imports it). This is the simplest and most realistic.
- If you want the test itself web-runnable, define tiny fakes whose class name matches (e.g. a `class SocketException implements Exception {}` in the test) — but the VM-side real-import approach is preferred for fidelity. `ClientException` (`package:http`) is *not* a koel_core dep; construct a fake named `ClientException` in the test, or assert the name-match path via a minimal stand-in. Document the choice in Completion Notes.

### Error-message conventions (architecture §5)
`KoelError.message` strings are **data**: sentence-cased, **no trailing period**. (Log-line strings — not these — get a trailing period.) Never interpolate user-controlled data unescaped into a message. Keep messages short and classification-focused (e.g. `'Connection failed'`, `'TLS handshake failed'`, `'Malformed payload'`).

### Project Structure Notes
- Files land exactly at the architecture-specified paths (architecture §"Per-package layout: koel_core", lines ~783–786): `lib/src/error/koel_error.dart` (sealed; F-A5), `lib/src/error/koel_error_code.dart` (typed vocabulary), `lib/src/error/error_classifier.dart` (default + pluggable). Tests mirror path-for-path under `test/error/` (convention §1 / §6).
- **Naming:** `snake_case.dart` files; `*Error` suffix on the sealed subtypes (`TransportError`, …) per convention §1 / architecture line ~462; `UpperCamelCase` types; `lowerCamelCase` enum members + getters. No `print`, no `catch (_) {}`.
- **Barrel deferred:** do **not** export to `lib/koel_core.dart` — it is the frozen 1.x contract finalized in Story 2.15 (where the `dart_apitool` baseline is taken). Tests import `src/` paths directly (legal for in-package tests; the `lib/src/` privacy rule only bans *cross-package* `src/` imports — convention §2).
- **Existing scaffold (do not regress):** `koel_core/pubspec.yaml` already carries `freezed_annotation: ^3.1.0`, `json_annotation: ^4.12.0`, dev-deps `freezed: 3.2.6-dev.1` + `json_serializable: ^6.8.0` + `build_runner` + `test` + path `koel_lints:`. `build.yaml` already sets `json_serializable.field_rename: none`. **No pubspec or build.yaml changes are needed** (no new deps; the error types use only `freezed_annotation` + the in-package `KoelErrorCode`; `RunAgentInput` is already present for the `classify` signature). The workspace-root `analysis_options.yaml` enables the `koel_lints` plugin; `koel_core` carries no local `analysis_options.yaml`.

### Toolchain (carried from Stories 2.1/2.2 — unchanged, do not modify)
- freezed `3.2.6-dev.1` + `freezed_annotation ^3.1.0`; analyzer pinned to 12 across the workspace (analyzer-12 stopgap, SCP-2026-05-29-B / architecture D2 + D3) so freezed and `analysis_server_plugin 0.3.14` coexist in one pub-workspace resolution. Dart 3.12 / Flutter 3.44 (`.tool-versions`).
- CI is already codegen-aware (Story 2.1): `ci.yml` runs `melos run build` before `analyze`/`test`; `codegen-drift.yml` is a real determinism gate; `format:check` excludes generated output. **This story adds no CI work.**
- Run tests via `dart test` directly in `packages/koel_core` (`melos run test` remains a Story 2.15 stub). Coverage ≥90% (NFR-12) is **not** an AC here (first gates in 2.5/2.6, finalized in 2.15) — still write thorough tests.

### Git intelligence (recent work patterns to follow)
- `3a6e54d feat(story-2.2)` — the immediate predecessor: established the freezed-3.x sealed-subtype idiom (`extends` parent via private `._()` ctor), the classic single-library `part` layout, `DeepCollectionEquality` deep-equality, and the freezed-only (no `*.g.dart`) posture for non-wire types. **Reuse all of these** — do not reinvent.
- `e944807 feat(story-2.1)` — foundation contracts + codegen pipeline; `RunAgentInput` (the `classify` arg) and the `abstract class … with _$X` freezed idiom originate here.
- `7ac485e chore(story-1.7)` — `koel_lints` migrated to `analysis_server_plugin`; the rule that enforces AC4 is the output of this work.
- Commit style: Conventional Commits scoped `feat(story-2.3): …`. Do not commit generated files.

### References
- [Source: _bmad-output/planning-artifacts/epics/epic-2-protocol-kernel-koelcore.md#Story 2.3] — story statement + ACs (authoritative for scope).
- [Source: _bmad-output/planning-artifacts/prds/prd-koel-2026-05-27/addendum.md#A.1 (lines 187–225)] — canonical `sealed class KoelError implements Exception` (getters `message`/`code`/`cause`), the four subtypes + specialization fields (`statusCode`/`eventType`/`agentCode`/`details`), the `KoelErrorCode` 15-value enum + its grouping, and `abstract class ErrorClassifier` / `DefaultErrorClassifier`.
- [Source: _bmad-output/planning-artifacts/prds/prd-koel-2026-05-27/prd.md#§8 Group A — F-A5] — sealed error hierarchy surfaced via `RUN_ERROR`; adapters never throw, they emit. [#§8 F-A12 + #§11] — `exhaustive_switch_must_have_default` on `AgUiEvent`/`KoelError`/`MessageSegment`; forward-compat policy.
- [Source: _bmad-output/planning-artifacts/architecture.md#5. Error handling (lines 595–630)] — adapters never throw; `Exception` marker is for synchronous programmer errors only; `ErrorClassifier` per adapter subclasses `DefaultErrorClassifier`; error-message conventions (sentence-case, no trailing period as data, no unescaped user data); no silent catches.
- [Source: _bmad-output/planning-artifacts/architecture.md#3. Type & data conventions (lines 513–546)] — freezed for >1-field cross-boundary immutables; `const` everywhere; `copyWith`-only mutation; the `default:`-arm rule (and the §3 "wrapping `UnknownError`" line ~522 to reconcile — see Dev Notes).
- [Source: _bmad-output/planning-artifacts/architecture.md (lines 59, 92, 116, D4 ~327–336)] — six-platform / no-`dart:io`-in-kernel constraint; `dart:io` socket confined to `koel_http` native transport. **The web-safe-classifier trap is grounded here.**
- [Source: _bmad-output/planning-artifacts/architecture.md#Per-package layout: koel_core (lines 783–786)] — `lib/src/error/`: `koel_error.dart` (F-A5), `koel_error_code.dart`, `error_classifier.dart`.
- [Source: packages/koel_lints/lib/src/rules/exhaustive_switch_must_have_default.dart] — `_sealedNames = {'AgUiEvent', 'KoelError', 'MessageSegment'}`: the rule already covers `KoelError` by name; no koel_lints change needed.
- [Source: packages/koel_core/lib/src/event/ag_ui_event.dart + unknown_event.dart] — the freezed-3.x sealed-subtype idiom + single-library `part` layout to mirror for `koel_error.dart`.
- [Source: packages/koel_core/lib/src/message/message.dart, packages/koel_core/lib/src/input/run_agent_input.dart, packages/koel_core/pubspec.yaml, packages/koel_core/build.yaml] — established freezed idiom, the `RunAgentInput` arg type for `classify`, and the current dep/codegen config (no changes needed).
- [Source: _bmad-output/implementation-artifacts/2-2-sealed-ag-ui-event-root.md] — the just-completed predecessor: sealed-across-files resolution (classic parts), freezed subtype via private `._()` ctor, `DeepCollectionEquality`, freezed-only posture, "verify build_runner, don't assume" (retro A1), barrel/coverage deferral, no-CI-change discipline.

## Dev Agent Record

### Agent Model Used

claude-opus-4-8[1m] (Opus 4.8, 1M context) — via `/agent-flutter-engineer` specialist persona.

### Debug Log References

- `dart test` (koel_core baseline) → 25 passing before implementation.
- `dart run build_runner build` → emitted `koel_error.freezed.dart` only; **no** `koel_error.g.dart` (freezed-only posture confirmed). Clean re-run wrote 0 outputs → codegen deterministic (codegen-drift gate green).
- `dart analyze` (koel_core) → surfaced the lint/analyzer tension on exhaustive switches (see Completion Notes); resolved → "No issues found!".
- `melos run analyze` → SUCCESS across all 12 packages.
- `melos run format:check` → 0 changed after one `dart format` pass on `koel_error_test.dart`.
- `dart test` (final) → 53 passing (25 existing + 28 new: 18 error + 10 classifier/property).

### Completion Notes List

- **Scope held exactly.** Shipped the error *types* + classifier only. No `RunErrorEvent`, no verify stage, no `JsonPatch`, no event subtype, no `json_serializable` on errors, no barrel export, no CI change, no pubspec/build.yaml change. The existing scaffold already carried every dep needed.
- **Freezed-3.x sealed-subtype idiom reused verbatim from Story 2.2.** Each subtype is `@freezed abstract class X extends KoelError with _$X` + `const X._() : super();` private ctor. The abstract-getter-vs-freezed-field overlap (`message`/`code`/`cause` declared abstract on the parent, supplied as fields by each subtype's factory) compiled with no freezed objection — verified by running the generator, not assumed (retro lesson A1).
- **`unknown` bucket → `AgentError(code: unknown)`** per the Dev Notes recommendation. Did **not** introduce the `UnknownError` 5th subtype that architecture §3 line ~522 implies — that doc inconsistency is flagged for the team to reconcile (architecture §3 ↔ Addendum A.1), not silently resolved by adding an out-of-AC type.
- **Web-safe classifier (#1 trap) honored.** `error_classifier.dart` imports only `dart:async` (for the real `TimeoutException` `is` check) + the in-package error types. `dart:io`/`package:http` shapes (`SocketException`/`HandshakeException`/`HttpException`/`ClientException`) matched by `raw.runtimeType.toString()` — no `dart:io`/`package:http` import, no new dep, no web-build break. Caveat (future SDK rename slips to `unknown`) documented in `DefaultErrorClassifier` dartdoc.
- **`classify` never throws** — verified for thrown `String`/`int`/`ArgumentError`/arbitrary `Object`: each returns a non-null `AgentError(unknown)` with `cause == raw`.
- **Testing the web-safe matcher:** chose the VM-real-import option — `test/error/error_classifier_test.dart` imports `dart:io` (test-only) to construct genuine `SocketException`/`HandshakeException`/`HttpException`; the *library* stays `dart:io`-free. `ClientException` (not a koel_core dep) is a local fake class whose name matches the runtime-name path. This is realistic and VM-faithful; the library's web-safety is unaffected since only the test imports `dart:io`.
- **Property test, zero new dep:** seeded `Random(0xC0FFEE)` draws 60 instances (≥ 50 required) from a 13-shape pool (mapped + unmapped: `StateError`/`ArgumentError`/`CustomException`/thrown `String`/`int`/`double`/map). Each output asserted non-null, `code` a `KoelErrorCode`, `cause` the input.
- **Tooling tension resolved (AC4/AC5).** `koel_lints`' `exhaustive_switch_must_have_default` fires on *any* default-less switch over `KoelError` (by design, FC-2), while the Dart analyzer fires `unreachable_switch_default` when a `default:` follows *exhaustive* cases. The only form satisfying both — and the forward-compat-correct consumer pattern — is a **non-exhaustive** switch that handles known arms and routes the rest through `default:`/`_`. Both consumer switches in the tests (the property-test bucketing statement and the `koel_error_test` pattern-match expression) use this form. **Handoff to Story 2.8:** the *negative* case (a default-less switch firing the lint end-to-end) is owned there and was deliberately kept out of koel_core's analyzed tree.
- **Cross-story handoffs recorded:** 2.4 `JsonPatch.apply` throws `ProtocolError(protocolMalformed)`; 2.5 adds `RunErrorEvent.error: KoelError` + the KoelError wire JSON codec (deferred here intentionally — `cause: Object?` often non-serializable); 2.8 owns the negative exhaustive-switch end-to-end; Epic 5 adds per-adapter `DefaultErrorClassifier` subclasses with status-code-aware mapping (429→rateLimited, 401→auth, 403→forbidden).

### File List

- `packages/koel_core/lib/src/error/koel_error_code.dart` (new) — 15-value `KoelErrorCode` enum.
- `packages/koel_core/lib/src/error/koel_error.dart` (new) — sealed `KoelError` + `TransportError`/`ProtocolError`/`AgentError`/`BusinessError`.
- `packages/koel_core/lib/src/error/koel_error.freezed.dart` (new, generated, gitignored) — freezed `==`/`hashCode`/`copyWith`.
- `packages/koel_core/lib/src/error/error_classifier.dart` (new) — `ErrorClassifier` interface + web-safe `DefaultErrorClassifier`.
- `packages/koel_core/test/error/koel_error_test.dart` (new) — 18 subtype tests (construction, type membership, structural equality, copyWith, consumer switch).
- `packages/koel_core/test/error/error_classifier_test.dart` (new) — 11 tests (mapped shapes, unknown-bucket never-throws, KoelError idempotency round-trip, seeded property-based coverage).
- `_bmad-output/implementation-artifacts/sprint-status.yaml` (modified) — 2-3 → in-progress → review.

### Change Log

- 2026-05-29 — Implemented Story 2.3: sealed `KoelError` hierarchy (4 freezed subtypes) + `KoelErrorCode` (15 values) + web-safe `DefaultErrorClassifier`. 28 new tests, 53 total green; `melos analyze`/`format:check` green; freezed-only codegen, deterministic. Status → review.
- 2026-05-29 — Code review (3-layer adversarial): AC1–AC5 PASS. Resolved 2 decision-needed (1a: keep `AgentError(unknown)`; 2a: made `classify` idempotent for `KoelError` inputs via `if (raw is KoelError) return raw;` + round-trip test). 1 deferred (name-match regression fixture → Epic 4/5), 11 dismissed. 54 tests green; `melos analyze`/`format:check` green. Status → done.

## Review Findings

_Code review 2026-05-29 — 3-layer adversarial (Blind Hunter + Edge Case Hunter + Acceptance Auditor). Auditor verdict: AC1–AC5 **PASS**, toolchain re-verified green (build_runner 0-output rerun, `dart analyze` clean, 53 tests passing, no generated files tracked). The two items below are design decisions, not AC violations._

- [x] [Review][Decision] `unknown` bucket maps every unclassified failure to `AgentError` — a local `StateError`/`ArgumentError`/thrown `String`/`int` becomes `AgentError(code: unknown)`, labelling a non-agent failure as agent-origin. This is the substance behind the already-flagged architecture §3 (`UnknownError` 5th subtype) ↔ Addendum A.1 reconciliation. **RESOLVED (1a): keep `AgentError(unknown)`** per the Dev Notes recommendation; no code change. The architecture §3 ↔ Addendum A.1 doc reconciliation remains a team item (already flagged in Completion Notes), not a code defect. [error_classifier.dart:84]
- [x] [Review][Patch] `classify` made idempotent for `KoelError` inputs — a `KoelError` (e.g. the `ProtocolError` Story 2.4's `JsonPatch.apply` will **throw**) re-fed into `classify` was double-wrapped into `AgentError(code: unknown, cause: <original>)`, discarding the typed code/subtype. **APPLIED (2a): added `if (raw is KoelError) return raw;` guard** at the head of `classify` + a round-trip-identity test. `dart analyze`/`melos analyze`/`format:check` green; `dart test` → 54 passing. [error_classifier.dart:42]
- [x] [Review][Defer] Name-match path has no regression fixture for renamed/private-impl class names + subclass asymmetry — `is TimeoutException`/`is FormatException` catch subclasses, but the `runtimeType.toString()` switch matches only exact bare names, so a subclass or private-impl name (`_SocketException`) silently routes to `unknown`. Real `dart:io` types pass today (tests confirm), but no test locks the documented caveat. Refinement (status-code-aware mapping) is already scope-deferred to Epic 4/5 adapter classifiers. [error_classifier.dart:61] — deferred, scope-bounded by spec
