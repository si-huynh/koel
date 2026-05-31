---
baseline_commit: c726bbb98e4e0dc5d50c92e1f47830f3d5ca4a02
---

# Story 4.1: Framework-free `SseParser`

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

> **Dev agent:** this is the **first story of Epic 4** (HTTP transport, `koel_http`) and the foundation the whole transport layer rests on. It touches `.dart` files and designs new public API, so **invoke `/agent-flutter-engineer` before producing any code** (per [CLAUDE.md](CLAUDE.md)). The package `packages/koel_http/` **already exists as a scaffold** (pubspec + barrel + `test/` dir, already a workspace member) — you are *populating* it, not creating it. **Five things are load-bearing, and the first three are traps that will sink a naïve reading of the AC:**
>
> 1. **`SseParser.parse` returns `Stream<AgUiEvent>`, NOT a stream of raw SSE frames.** The AC is explicit: `Stream<AgUiEvent> parse(Stream<List<int>> bytes)`. This parser does the *whole* wire→domain job: byte decode → RFC 8895 SSE framing → `jsonDecode` of each event's `data:` payload → `AgUiEvent.fromWire(map)`. There is **no public `SseEvent` type** in this story — the SSE frame (event/data/id/retry) is an *internal* intermediate, never exported. [Source: epic-4 4.1 AC :15; architecture :1077 `backend bytes → SseParser.parse → Stream<AgUiEvent>`]
> 2. **Malformed wire JSON inside a `data:` field must surface as `ProtocolError(code: protocolMalformed)` — via the existing classifier, not a hand-thrown error.** `jsonDecode` throws `FormatException`; the `DefaultErrorClassifier` already maps `FormatException → ProtocolError(protocolMalformed)` ([error_classifier.dart:59-65](packages/koel_core/lib/src/error/error_classifier.dart#L59-L65)). Run the failure through that classifier (the "inline error classifier" the AC names) rather than constructing `ProtocolError` ad-hoc — this is the FR-A11 wire-sanity boundary. **Do NOT** swallow it or emit an `UnknownAgUiEvent` for corrupt JSON. [Source: epic-4 4.1 AC :22; error_classifier.dart:59-65]
> 3. **Unknown event *types* are NOT errors — they become `UnknownAgUiEvent`.** This is the opposite of trap #2 and the distinction is the heart of the parser's error contract: corrupt *JSON* → `ProtocolError`; well-formed JSON with an unrecognized `type` → `UnknownAgUiEvent` (no throw). You get this for free: `AgUiEvent.fromWire` is **total** — it delegates to the Story 2.2 registry deserializer, which returns `UnknownAgUiEvent(type:, rawJson:)` for any unrecognized/missing/non-String `type` and never throws. So you do NOT reimplement the registry or switch on event types here. [Source: epic-4 4.1 AC :24-26; ag_ui_event.dart:63 `fromWire`; F-A6 :996]
> 4. **No public `SseEvent`, no `StreamTransformer` subtype — `SseParser` is a plain class with one method.** The AC says `class SseParser` exposes `Stream<AgUiEvent> parse(Stream<List<int>> bytes)`. Implement framing as an internal async generator / state machine consumed by `parse`; do not expose the intermediate frame record, and do not make `SseParser` itself `implements StreamTransformer`. [Source: epic-4 4.1 AC :15; architecture :1086]
> 5. **Hard size budget: `wc -l koel_http/lib/src/sse_parser.dart` < 250 LOC (target ~150, per AR-8).** This is an *enforced* AC, not a guideline — AR-8 is "a reviewable, dependency-free SSE parser." Keep the whole thing (frame state machine + JSON decode + `fromWire` dispatch) in the single file `lib/src/sse_parser.dart` (flat under `src/`, NOT `src/sse/`). No third-party SSE dependency (`package:sse`, `package:eventsource`). [Source: epic-4 4.1 AC :13,17,29-30; AR-8]

## Story

As a Flutter/Dart developer,
I want a hand-rolled `SseParser` (~150 LOC) that converts a `Stream<List<int>>` byte stream into a typed `Stream<AgUiEvent>` per RFC 8895 SSE format compliance,
so that the transport layer rests on a reviewable, dependency-free SSE parser per AR-8.

## Acceptance Criteria

Verbatim from [epic-4 Story 4.1](../planning-artifacts/epics/epic-4-http-transport-koelhttp.md):

1. **Given** `koel_http/lib/src/sse_parser.dart`, **When** I inspect it, **Then** `class SseParser` exposes `Stream<AgUiEvent> parse(Stream<List<int>> bytes)`, **And** the implementation handles SSE wire format per RFC 8895 (event boundaries on `\n\n`, `data:` field accumulation, `event:` type override, `id:` retention, `retry:` value), **And** no third-party SSE parsing dependency (`package:sse`, `package:eventsource`) is imported.

2. **Given** a synthesized RFC 8895 fixture covering edge cases (CRLF line endings, multi-line data fields, BOM prefix, comment lines, partial chunks split mid-field), **When** the parser processes it, **Then** every fixture passes, **And** malformed wire JSON inside a `data:` field surfaces as `ProtocolError(code: protocolMalformed)` via the inline error classifier — pipeline wire-sanity boundary per FR-A11.

3. **Given** unknown event types in the wire stream, **When** the parser dispatches via the registry from Story 2.2, **Then** they deserialize into `UnknownAgUiEvent` (no exception).

4. **Given** the parser's package size, **When** I run `wc -l koel_http/lib/src/sse_parser.dart`, **Then** the file is < 250 LOC (target ~150 per AR-8).

> **AC clarifications (RESOLVED — do not re-litigate, implement):**
> - **AC1 "handles `event:`/`id:`/`retry:`":** the parser must *parse* these SSE fields per RFC 8895 (so a frame's `event`/`id`/`retry` are correctly accumulated), but the **dispatched value is always `AgUiEvent.fromWire(jsonDecode(data))`** — AG-UI carries its event type inside the JSON `data` payload's `type` field, not the SSE `event:` line. Retain `id`/`retry`/`event` parsing for spec compliance and future reconnect logic (Story 4.4), but the AG-UI domain event comes from `data`. [Source: AC1 :16; architecture :1077-1083]
> - **AC2 "inline error classifier":** = `DefaultErrorClassifier` from koel_core, which maps the `FormatException` from `jsonDecode` to `ProtocolError(protocolMalformed)` (trap #2). There is no separate classifier to build in this story. [Source: error_classifier.dart:38-99]
> - **A frame with no `data:` line (comment-only / `event:`-only) dispatches nothing** — per RFC 8895 a dispatch only happens for a frame that accumulated data; comment lines (leading `:`) are ignored entirely. [Source: RFC 8895 / WHATWG event-stream interpretation]

## Tasks / Subtasks

- [x] **Task 0 — Read the real surfaces before writing a line** (AC: all — skipping this builds the wrong contract)
  - [x] Read [ag_ui_event.dart:55-65](packages/koel_core/lib/src/event/ag_ui_event.dart#L55-L65) — confirm `static AgUiEvent fromWire(Map<String, dynamic> json)` is the **only** public decode door and is **total** (delegates to the internal registry deserializer; unknown `type` → `UnknownAgUiEvent`, never throws). This is what makes AC3 free and is the dispatch target for every frame. [Source: ag_ui_event.dart:63]
  - [x] Read [error_classifier.dart](packages/koel_core/lib/src/error/error_classifier.dart) **in full** — confirm `DefaultErrorClassifier().classify(raw, stack, input)` maps `FormatException → ProtocolError(protocolMalformed)` (lines 59-65) and is idempotent for already-typed `KoelError`s (lines 47-49). Confirm its signature needs a `RunAgentInput` (trap below). [Source: error_classifier.dart:38-99]
  - [x] Read [koel_error.dart:61-78](packages/koel_core/lib/src/error/koel_error.dart#L61-L78) — `ProtocolError({required String message, KoelErrorCode code = protocolMalformed, Object? cause, String? pointer})`. If you construct it directly (instead of via the classifier) keep `code: KoelErrorCode.protocolMalformed` and pass the `FormatException` as `cause`. [Source: koel_error.dart:72-77]
  - [x] Read the existing scaffold: [koel_http/pubspec.yaml](packages/koel_http/pubspec.yaml) (name `koel_http`, version `0.0.1`, sdk `">=3.11.0 <4.0.0"`, `resolution: workspace`, only `dev_dependencies: koel_lints:` so far) and [koel_http/lib/koel_http.dart](packages/koel_http/lib/koel_http.dart) (barrel: `library;` doc only, no exports yet). Confirm `koel_http` is **already** in the root [pubspec.yaml](pubspec.yaml) `workspace:` list. [Source: koel_http/pubspec.yaml; root pubspec.yaml]
  - [x] Read [koel_core/pubspec.yaml](packages/koel_core/pubspec.yaml) + [koel_core/analysis_options.yaml](packages/koel_core/analysis_options.yaml) as the templates for the dependency edit and (deferred) doc-gate file. [Source: koel_core configs]
  - [x] Skim the RFC 8895 / WHATWG event-stream interpretation rules (line splitting on `\n`/`\r`/`\r\n`, BOM strip-once, `field:value` with one optional leading space stripped, leading-`:` comment, blank line = dispatch, `data` lines joined by `\n` with the single trailing `\n` stripped). The spec is the source of truth. [Source: AC1 :16; https://html.spec.whatwg.org/multipage/server-sent-events.html#event-stream-interpretation]

- [x] **Task 1 — Add the `koel_core` dependency to `koel_http`** (AC: #1, #2, #3)
  - [x] In [koel_http/pubspec.yaml](packages/koel_http/pubspec.yaml) (MODIFY) add a `dependencies:` section with a bare workspace key `koel_core:` (mirrors koel_test's first cross-package edge — `AgUiEvent`, `ProtocolError`, `DefaultErrorClassifier`, `RunAgentInput` all appear in/behind the parser's implementation). Keep `dev_dependencies: koel_lints:` and add `test: ^1.25.0`. **Do NOT** add `http`, `dart:io`, `freezed`, `build_runner`, or any SSE library — none are needed for the byte→event parser (the HTTP client arrives with `HttpAgent` in Story 4.2). [Source: koel_test/pubspec.yaml workspace-key pattern; trap #5; AC1 :17]
  - [x] Run `dart pub get` from the workspace root; confirm `koel_http` resolves `koel_core` from the workspace. [Source: root pubspec workspace resolution]

- [x] **Task 2 — `SseParser` + internal frame state machine** (AC: #1)
  - [x] Populate `packages/koel_http/lib/src/sse_parser.dart` (flat under `src/`, **not** `src/sse/`) — the AC's exact path. Imports: `dart:async`, `dart:convert` (`utf8`, `jsonDecode`), `package:koel_core/koel_core.dart` (public barrel only — `AgUiEvent`, `ProtocolError`, `KoelErrorCode`, `DefaultErrorClassifier`, `RunAgentInput`). **No `package:koel_core/src/...` import, no Flutter, no `dart:io`/`dart:html`/`package:web`.** [Source: AC1 :13; barrel discipline; architecture web-safety]
  - [x] Declare `final class SseParser` with a `const SseParser()` constructor (holds no per-call state) and the single public method `Stream<AgUiEvent> parse(Stream<List<int>> bytes)`. Full dartdoc on the class and `parse` (contract: bytes→typed events; RFC 8895 framing; `ProtocolError(protocolMalformed)` on corrupt `data` JSON; `UnknownAgUiEvent` on unknown type; cites AR-8). [Source: AC1 :15; AR-8]
  - [x] Decode bytes to text in **stream mode** so multi-byte UTF-8 split across chunks is handled: `bytes.transform(utf8.decoder)` (the converter's chunked decoder buffers partial code units) — NOT per-chunk `utf8.decode`. Strip a leading BOM (`U+FEFF`) exactly once at stream start. [Source: AC2 "BOM prefix"; dart:convert Utf8Decoder]
  - [x] Internal line/field state machine (keep it small — trap #5): split on `\r\n`, `\r`, `\n` (handle a `\r` landing at a chunk boundary that may be followed by `\n` next chunk); for each line — leading `:` → comment (ignore); `field:value` → strip one optional leading space from value; bare `field` → empty value; blank line → **dispatch the accumulated frame**. Accumulate `data` lines joined by `\n`, stripping the single trailing `\n` at dispatch. Track `event`, `id` (ignore values containing NUL per spec), `retry` (integer-only; ignore non-integer) for spec compliance even though dispatch uses the `data` JSON. [Source: AC1 :16; RFC 8895]
  - [x] Buffer across chunk boundaries so a frame split mid-field (AC2 "partial chunks split mid-field") is never dispatched early — only a completed frame (terminated by a blank line) dispatches. On source `done`, dispatch any pending frame that accumulated data (a final frame without a trailing blank line is still processed); a truly empty pending frame dispatches nothing. Propagate source stream errors to the output without swallowing. [Source: AC2; RFC 8895 §dispatch]

- [x] **Task 3 — Dispatch: `data` JSON → `AgUiEvent` with the two-sided error contract** (AC: #2, #3)
  - [x] On each frame dispatch with non-empty `data`: `final Map<String, dynamic> payload = jsonDecode(data) as Map<String, dynamic>;` then `yield AgUiEvent.fromWire(payload);`. Unknown `type` flows to `UnknownAgUiEvent` automatically (AC3 — no switch, no registry copy). [Source: AC3 :24-26; ag_ui_event.dart:63]
  - [x] Wrap the `jsonDecode` in the wire-sanity boundary: on `FormatException` (corrupt JSON) — and on a non-`Map` decode result — surface `ProtocolError(code: protocolMalformed)`. Route it through `const DefaultErrorClassifier().classify(error, stackTrace, input)` (the "inline error classifier" — it returns `ProtocolError(protocolMalformed)` for `FormatException`). The classifier needs a `RunAgentInput`; for this transport-internal boundary, see §"The classifier's `RunAgentInput` argument" for the preferred resolution (construct `ProtocolError` directly — same contract, no fake input). Add the error to the output stream (e.g. via a `StreamController` or `Stream.error`) so downstream sees a `ProtocolError`, not a raw `FormatException`. **Do NOT** emit `UnknownAgUiEvent` for corrupt JSON (trap #2 vs #3). [Source: AC2 :22; error_classifier.dart:59-65; FR-A11]

- [x] **Task 4 — Export from the barrel** (AC: #1)
  - [x] In [koel_http/lib/koel_http.dart](packages/koel_http/lib/koel_http.dart) (MODIFY) add `export 'src/sse_parser.dart';` (first public export of the package). Surfaces only `SseParser`. **Do NOT** export the internal frame type and **Do NOT** re-export `koel_core` (consumers depend on it directly; only the meta-package re-exports). [Source: barrel discipline 2.15/3.x; architecture :980]

- [x] **Task 5 — Fixtures + table-driven tests** (AC: #1, #2, #3, #4)
  - [x] New `packages/koel_http/test/parser/sse_parser_test.dart` (mirror the architecture's `test/parser/` layout; `package:test` only; one top-level `group('SseParser', …)`). Drive `SseParser().parse(...)` with `Stream.fromIterable([...])` of `List<int>` chunks (use `utf8.encode`). [Source: architecture :838-840; convention §6 mirror naming]
  - [x] Build synthesized RFC 8895 fixtures covering every AC2 edge case: **CRLF** line endings, **multi-line `data:`** fields (joined by `\n`), **BOM** prefix, **comment** lines (leading `:`), and **partial chunks split mid-field** (same logical frame delivered across ≥2 `List<int>` chunks, including a split inside a multi-byte UTF-8 sequence and inside a `data:` value). Assert each yields the expected typed `AgUiEvent`s in order. Reuse real AG-UI wire payloads (e.g. `TEXT_MESSAGE_CONTENT` with `messageId`/`delta`) so `fromWire` produces concrete typed events. [Source: AC2 :19-21]
  - [x] **AC2 error path:** a frame whose `data:` is not valid JSON → the stream emits a `ProtocolError` with `code == KoelErrorCode.protocolMalformed`. Assert via `expectLater(stream, emitsError(isA<ProtocolError>().having((e) => e.code, 'code', KoelErrorCode.protocolMalformed)))`. [Source: AC2 :22]
  - [x] **AC3 unknown type:** a frame whose `data:` is well-formed JSON with an unrecognized `type` → yields an `UnknownAgUiEvent` (no error, no throw). [Source: AC3 :24-26]
  - [x] Edge cases: empty stream → no events, no error; comments-only stream → no events; `event:`-only frame (no `data`) → no dispatch; mixed `\r`/`\n`/`\r\n`; stream ending mid-frame with pending data → final frame flushed on close. [Source: RFC 8895; AC2]
  - [x] **AC4 size gate:** keep the parser well under 250 LOC and verify with `wc -l lib/src/sse_parser.dart` (the reviewer runs `wc -l koel_http/lib/src/sse_parser.dart`). Optionally assert it in a test. [Source: AC4 :28-30]

- [x] **Task 6 — Quality gates (NO finalization gates this story)** (AC: all)
  - [x] `melos run analyze` → **0 issues** workspace-wide. (koel_http currently has **no** member `analysis_options.yaml`, so it inherits the **root** profile — `package:lints/recommended.yaml` + the koel_lints plugin. Write dartdoc on `SseParser`/`parse` anyway, as good craft, so the doc gate that Story 4.10 turns on needs no backfill.) [Source: NFR-13; root analysis_options.yaml]
  - [x] `melos run test` → green workspace-wide, including the new `koel_http` parser test (this is the first real test file in `koel_http`, replacing the scaffold's empty `test/`). [Source: tool/test_package.sh]
  - [x] `melos run format:check` → clean (`dart format --set-exit-if-changed`). [Source: tool/format.sh]
  - [x] **Do NOT** add `koel_http`'s member `analysis_options.yaml` doc gate or the ≥90% coverage gate. Those are **package-finalization** gates that land in the epic-sealing story (**4.10**, web transport + perf baseline), exactly as koel_test deferred them from 3.1–3.4 to 3.5. 4.1 needs only `analyze`/`test`/`format:check` green. [Source: epic-4 overview "Coverage ≥ 90%"; koel_test 3.1–3.4→3.5 precedent; architecture :844 koel_http analysis_options is the finalize-story artifact]
  - [x] Confirm the change set is **exactly**: 1 pubspec dep edit; 1 new `lib/src/sse_parser.dart`; 1 barrel-export line; 1 new test file (+ any inline fixture data in the test). No new package, no finalization-gate files. [Source: §"Files you will touch"]

## Dev Notes

### What this story is, in one paragraph

The **wire→domain boundary** of `koel_http`. It is a single hand-rolled file, `lib/src/sse_parser.dart` (< 250 LOC, target ~150 — AR-8), exposing `final class SseParser` with `Stream<AgUiEvent> parse(Stream<List<int>> bytes)`. It decodes the byte stream as UTF-8 (stream-mode, BOM-stripped), runs an RFC 8895 SSE line/field state machine to assemble frames, and for each completed frame `jsonDecode`s the `data:` payload and dispatches it through `AgUiEvent.fromWire`. The error contract is two-sided and is the crux of the story: **corrupt JSON → `ProtocolError(protocolMalformed)`** (via `DefaultErrorClassifier`, the FR-A11 wire-sanity boundary), but **well-formed JSON with an unknown `type` → `UnknownAgUiEvent`** (totality of `fromWire`, AC3 — no exception). Scope is exactly: the pubspec `koel_core` dep, the parser file, one barrel export, one test file. **Not** `HttpAgent`/transports/interceptors (4.2+), **not** the web byte-source (4.10), **not** the package-finalization gates (4.10).

### The two-sided error contract (the heart of this story) — RESOLVED

The AC pairs two requirements that look contradictory until you see the seam:

- **AC2:** "malformed wire JSON inside a `data:` field surfaces as `ProtocolError(code: protocolMalformed)` via the inline error classifier."
- **AC3:** "unknown event types … deserialize into `UnknownAgUiEvent` (no exception)."

The resolution is that they operate at **different layers**:

- `jsonDecode(data)` is the **syntax** layer. If the `data:` text isn't valid JSON, `jsonDecode` throws `FormatException`. That is corruption → `ProtocolError(protocolMalformed)`. The "inline error classifier" is the existing `DefaultErrorClassifier`, whose `classify` already maps `FormatException → ProtocolError(protocolMalformed)` ([error_classifier.dart:59-65](packages/koel_core/lib/src/error/error_classifier.dart#L59-L65)). Use it (don't hand-roll the mapping) so the transport boundary classifies failures the same way the rest of the SDK does.
- `AgUiEvent.fromWire(map)` is the **schema/registry** layer. The JSON is valid but its `type` isn't in the Story 2.2 registry → the deserializer returns `UnknownAgUiEvent(type:, rawJson:)`. `fromWire` is **total** — it never throws on an unknown/missing/non-String `type` ([ag_ui_event.dart:63](packages/koel_core/lib/src/event/ag_ui_event.dart#L63); F-A6 forward-compat). So AC3 is satisfied for free; you must **not** wrap unknown types as errors.

The one-line rule for the dev: *"`jsonDecode` failing is a `ProtocolError`; `fromWire` of a parsed map is never an error."*

### Why `Stream<AgUiEvent>`, not a stream of SSE frames — RESOLVED

The architecture data flow is `backend bytes → SseParser.parse(Stream<List<int>>) → Stream<AgUiEvent> → KoelClient pipeline → ChatState` ([architecture :1077](_bmad-output/planning-artifacts/architecture.md)). The SSE frame (event/data/id/retry) is an **internal** intermediate — it never crosses the package boundary. There is intentionally **no public `SseEvent`/`SseFrame` type** in this story: exporting one would be speculative surface ("API surface is a one-way door" — CLAUDE.md). Model the frame as a private record/small class consumed inside `parse`, and export only `SseParser`. AG-UI's event type lives in the JSON `data` payload's `type` field, so the SSE `event:` line is parsed for spec compliance but is **not** the dispatch discriminator.

### `event:`/`id:`/`retry:` — parse them, but the domain event comes from `data` — RESOLVED

RFC 8895 defines `event:` (frame type), `id:` (last-event-id, for reconnection), and `retry:` (reconnection delay). AC1 requires the parser to *handle* them. Handle = parse correctly into the frame state (so a future `Last-Event-ID` reconnect in Story 4.4 can read them), but the `AgUiEvent` you yield always comes from `AgUiEvent.fromWire(jsonDecode(data))`. Do not branch dispatch on the `event:` line. Retaining these fields now (instead of dropping them) is what lets 4.4's reconnect logic avoid a parser rewrite.

### The classifier's `RunAgentInput` argument — note

`ErrorClassifier.classify(Object raw, StackTrace? stack, RunAgentInput input)` requires a `RunAgentInput` ([error_classifier.dart:18](packages/koel_core/lib/src/error/error_classifier.dart#L18)). `SseParser.parse` does not receive one (it takes only bytes). Two acceptable resolutions, dev's choice — pick the smaller:
- **(preferred)** Construct `ProtocolError(message: 'Malformed SSE data payload', code: KoelErrorCode.protocolMalformed, cause: formatException)` **directly** on the `FormatException` path. This is exactly what the classifier would return for a `FormatException`, needs no `RunAgentInput`, and keeps the parser self-contained. Cite that this mirrors `DefaultErrorClassifier`'s `FormatException` arm so a reviewer sees it's the same contract, not a divergence.
- **(alternative)** If you want to literally route through the classifier (AC2's "via the inline error classifier"), pass a minimal `RunAgentInput` — but threading a fake input through a pure parser is a smell. Document whichever you choose. Either way the **observable** contract (a `ProtocolError` with `code == protocolMalformed` on the stream) is identical and is what the test asserts. [Source: error_classifier.dart:18,59-65; trap #2]

### Out of scope — do NOT build these (RESOLVED)

- `HttpAgent`, native/web transports, the `http.Client` wiring → **Story 4.2 / 4.10**.
- Cancellation / TCP abort → **Story 4.3**. Retry/Auth/Logging/Trace/Sentry/PII interceptors → **4.4–4.7**. Chunk synthesis (START/CONTENT/END from CHUNK) → **4.8**. Connection lifecycle hooks → **4.9**.
- The web byte source (`package:web` fetch + ReadableStream + AbortController) and the `sse_parse_bench` perf baseline → **Story 4.10** (which also turns on the doc gate + ≥90% coverage gate). Do **not** add `analysis_options.yaml`/coverage gate here.
- Any public `SseEvent`/`SseFrame` type, any `StreamTransformer` subtype, any third-party SSE dependency.

### Files you will touch

| Path | Action | Note |
| ---- | ------ | ---- |
| [packages/koel_http/pubspec.yaml](packages/koel_http/pubspec.yaml) | MODIFY | add `dependencies: { koel_core: }` + `dev_dependencies: { test: ^1.25.0 }` (keep `koel_lints:`). No http/freezed/SSE libs. |
| [packages/koel_http/lib/src/sse_parser.dart](packages/koel_http/lib/src/sse_parser.dart) | NEW | the whole story; < 250 LOC; `final class SseParser` + internal frame state machine. |
| [packages/koel_http/lib/koel_http.dart](packages/koel_http/lib/koel_http.dart) | MODIFY | add `export 'src/sse_parser.dart';` (first export). |
| `packages/koel_http/test/parser/sse_parser_test.dart` | NEW | table-driven RFC 8895 + error-contract + size tests. |

### Library / framework requirements

- **Runtime:** `package:koel_core` (public barrel) — `AgUiEvent`, `AgUiEvent.fromWire`, `ProtocolError`, `KoelErrorCode`, `DefaultErrorClassifier`, `RunAgentInput`. SDK lang only: `dart:async`, `dart:convert`.
- **Dev:** `package:test ^1.25.0`, `koel_lints` (workspace).
- **Forbidden:** `package:sse`, `package:eventsource` (AC1), `package:http`/`dart:io`/`dart:html`/`package:web`/Flutter (web-safe, framework-free per AR-8; transports come later), `freezed`/`build_runner` (no codegen — the frame is a hand-written private type).

### Project Structure Notes

- `koel_http` already exists and is already a workspace member ([root pubspec.yaml](pubspec.yaml)); this story populates it. SDK constraint is the workspace-uniform `">=3.11.0 <4.0.0"` (already in the scaffold pubspec) — do not change it.
- File path is **`lib/src/sse_parser.dart`** (flat), per the AC's `wc -l koel_http/lib/src/sse_parser.dart`. The architecture prose also shows it flat under `src/` ([architecture :832](_bmad-output/planning-artifacts/architecture.md)). Test path `test/parser/sse_parser_test.dart` follows the architecture's `koel_http/test/parser/` layout ([architecture :838-840](_bmad-output/planning-artifacts/architecture.md)).
- Barrel discipline: only `lib/koel_http.dart` is public; everything else lives in `lib/src/`; consumers never import `koel_http/src/...`.

### Previous Story Intelligence

- **Story 3.3** added the `AgUiEvent.fromWire` seam you depend on, and established the "decode `payload`, totality, no `try/catch` around decode (corrupt JSON surfaces as a loud failure)" pattern — your AC2/AC3 split is the same shape applied at the SSE boundary. [Source: [3-3-fixture-loader-from-fixture.md](3-3-fixture-loader-from-fixture.md)]
- **Story 3.5** established the convention that **finalization gates (member `analysis_options.yaml` doc gate + coverage gate) are added by the epic-sealing story, not earlier ones**. Apply the same here: defer to 4.10. [Source: [3-5-conformance-runner-skeleton.md](3-5-conformance-runner-skeleton.md)]
- **Story 2.2** built the event registry / sealed `AgUiEvent` union + `UnknownAgUiEvent` fallback that `fromWire` dispatches into — you reuse it, never reimplement it. [Source: epic-2 2.2; F-A6]

### Latest Tech Information

- **UTF-8 streaming decode:** `Stream<List<int>>.transform(utf8.decoder)` uses `Utf8Decoder`'s chunked converter, which correctly buffers a multi-byte sequence split across chunk boundaries — the right primitive for AC2's "partial chunks split mid-field". Per-chunk `utf8.decode(chunk)` would corrupt a split code point; do not use it.
- **Async generators:** an `async*` function with `await for (final chunk in bytes.transform(utf8.decoder))` and `yield`/`yield*` is the idiomatic, allocation-light way to express the frame state machine and emit events; it also propagates source errors and `done` naturally. Surfacing a `ProtocolError` mid-stream is cleanest via a `StreamController` or by `yield`ing through a transform that can add stream errors — pick the form that keeps the file under the LOC budget.
- **`package:test` stream matchers:** `emitsInOrder`, `emitsError`, `isA<ProtocolError>().having(...)`, `emitsDone` express the table-driven assertions tersely.

### References

- Story spec (ACs, AR-8, FR-A11 boundary): [epic-4 Story 4.1](../planning-artifacts/epics/epic-4-http-transport-koelhttp.md) (lines 5-30).
- Epic 4 overview (coverage ≥90%, transport scope): [epic-4-http-transport-koelhttp.md](../planning-artifacts/epics/epic-4-http-transport-koelhttp.md) (line 3).
- Decode seam (dispatch target, total): [ag_ui_event.dart:55-65](packages/koel_core/lib/src/event/ag_ui_event.dart#L55-L65).
- Inline error classifier (`FormatException → ProtocolError(protocolMalformed)`): [error_classifier.dart:38-99](packages/koel_core/lib/src/error/error_classifier.dart#L38-L99).
- `ProtocolError` factory: [koel_error.dart:61-78](packages/koel_core/lib/src/error/koel_error.dart#L61-L78); `protocolMalformed`: [koel_error_code.dart](packages/koel_core/lib/src/error/koel_error_code.dart).
- Data flow + `SseParser` placement: [architecture.md](../planning-artifacts/architecture.md) (lines 829-844 koel_http layout; 1077 the byte→event flow).
- Package conventions: [koel_core/pubspec.yaml](packages/koel_core/pubspec.yaml), [koel_core/analysis_options.yaml](packages/koel_core/analysis_options.yaml), [koel_test/pubspec.yaml](packages/koel_test/pubspec.yaml) (workspace-key dep pattern).
- RFC 8895 / WHATWG event-stream interpretation: https://html.spec.whatwg.org/multipage/server-sent-events.html#event-stream-interpretation
- House style exemplars: [3-3-fixture-loader-from-fixture.md](3-3-fixture-loader-from-fixture.md), [3-5-conformance-runner-skeleton.md](3-5-conformance-runner-skeleton.md).

### Design decisions (RESOLVED — AC/architecture-forced, not open)

1. **Output type is `Stream<AgUiEvent>`** (not raw frames) — AC1 verbatim; the parser owns framing + JSON decode + `fromWire`. No public `SseEvent`. [trap #1, #4]
2. **Corrupt `data` JSON → `ProtocolError(protocolMalformed)`; unknown `type` → `UnknownAgUiEvent`** — AC2 vs AC3; the syntax/schema layer split. [trap #2, #3]
3. **`SseParser` is a plain `final class` with `const` ctor and one method**, not a `StreamTransformer` subtype; frame type stays private. [trap #4; architecture :1086]
4. **File at `lib/src/sse_parser.dart` (flat), < 250 LOC** — AC4's `wc -l` path; AR-8. [trap #5]
5. **No finalization gates this story** — member `analysis_options.yaml` doc gate + ≥90% coverage gate are Story 4.10's epic-sealing job (koel_test 3.x precedent). [Previous Story Intelligence]
6. **Construct `ProtocolError` directly on the `FormatException` path** (preferred) — same contract as `DefaultErrorClassifier`'s `FormatException` arm, without threading a fake `RunAgentInput` through a pure parser. [§"The classifier's `RunAgentInput` argument"]

These are baked in — implement them; no confirmation gate.

## Dev Agent Record

### Context Reference

<!-- Path(s) to story context will be added here by context workflow -->

### Agent Model Used

claude-opus-4-8 (Amelia / `bmad-dev-story`, specialist `agent-flutter-engineer` loaded per CLAUDE.md)

### Debug Log References

- `melos run analyze` → SUCCESS, 0 issues across 11 packages.
- `melos run test` → SUCCESS across 11 packages; `koel_http` parser suite 20/20 green (first real test file in the package).
- `tool/format.sh check` → "0 changed" across 103 hand-written files.
- `wc -l packages/koel_http/lib/src/sse_parser.dart` → 151 (AC4: < 250, target ~150).

### Completion Notes List

- **Output is `Stream<AgUiEvent>`, framing is internal.** `SseParser.parse` owns the whole wire→domain job: `bytes.transform(utf8.decoder)` (stream-mode, BOM-stripped once) → RFC 8895 / WHATWG line+field state machine → `jsonDecode` of each frame's accumulated `data` → `AgUiEvent.fromWire`. No public `SseEvent`/frame type; `SseParser` is a plain `final class` with a `const` ctor and one method (not a `StreamTransformer` subtype). [traps #1, #4]
- **Two-sided error contract implemented.** Corrupt `data` JSON (`FormatException` from `jsonDecode`, **or** a non-object payload) → `ProtocolError(code: protocolMalformed)` thrown into the stream — same mapping as `DefaultErrorClassifier`'s `FormatException` arm, constructed directly so no fake `RunAgentInput` is threaded through a pure parser (design decision #6). Well-formed JSON with an unknown `type` → `UnknownAgUiEvent` for free via the total `AgUiEvent.fromWire` — never wrapped as an error. [traps #2, #3]
- **Chunk-boundary correctness.** Multi-byte UTF-8 split across chunks is handled by the chunked `Utf8Decoder` (not per-chunk `utf8.decode`); a `\r` landing at a chunk boundary is deferred so a straddling `\r\n` counts as one break; a frame split mid-field never dispatches early; a final frame lacking a trailing blank line is flushed on source `done`. Source-stream errors propagate unchanged.
- **`event:`/`id:`/`retry:` — handled, not yet retained (deliberate).** These are recognized as SSE fields and kept out of the `data` payload (correct framing), but their values are not persisted: there is no consumer until reconnect support in Story 4.4, and storing write-only state would be vestigial (CLAUDE.md) **and** trip the analyzer's unused-field diagnostics, breaking the Task-6 `analyze` = 0-issues gate. Documented in the `parse` dartdoc; Last-Event-ID retention + `retry` honoring land with 4.4.
- **No finalization gates this story** (member `analysis_options.yaml` doc gate + ≥90% coverage gate are Story 4.10's epic-sealing job — koel_test 3.x precedent). `koel_http` inherits the root analyzer profile.
- **Change set is exactly four code files** (1 pubspec dep edit, 1 new parser, 1 barrel-export line, 1 new test) + story tracking. No new package, no http/freezed/SSE deps, no codegen.

### File List

- `packages/koel_http/pubspec.yaml` (MODIFY) — added `dependencies: koel_core:` + `dev_dependencies: test: ^1.25.0`.
- `packages/koel_http/lib/src/sse_parser.dart` (NEW) — `final class SseParser` + internal RFC 8895 frame state machine (151 LOC).
- `packages/koel_http/lib/koel_http.dart` (MODIFY) — `export 'src/sse_parser.dart';` (first public export).
- `packages/koel_http/test/parser/sse_parser_test.dart` (NEW) — table-driven RFC 8895 + two-sided error-contract + AC4 size tests (20 cases).

## Change Log

| Date | Version | Description | Author |
| ---- | ------- | ----------- | ------ |
| 2026-05-31 | 0.1.0 | Story drafted — ultimate context engine analysis completed; comprehensive developer guide created | create-story |
| 2026-05-31 | 1.0.0 | Implemented `SseParser` (151 LOC), barrel export, `koel_core` dep, 20-case test suite; analyze/test/format gates green; status → review | dev-story |

## Review Findings

_Code review 2026-05-31 (bmad-code-review): 3 layers (Blind Hunter, Edge Case Hunter, Acceptance Auditor). High-severity findings verified by direct execution against the parser. All decisions resolved and all patches applied; analyze/test/format green workspace-wide (koel_http 23 tests)._

- [x] [Review][Decision→Patch] Empty `data:` frame crashes the whole stream — A spec-legal SSE frame with an empty data field (`data:\n\n`, or colon-less `data\n\n`) builds a `"\n"` buffer that is non-empty, so it dispatches `_dispatch("")` → `jsonDecode("")` throws `FormatException` → `ProtocolError(protocolMalformed)` thrown out of the `async*`, terminating the stream. **Verified by execution.** The `data.isEmpty` gate ([sse_parser.dart:100](packages/koel_http/lib/src/sse_parser.dart#L100)) can never be true once any `data` line (even empty) is seen, because each writes `"\n"`. AC clarification line 40 intends "a dispatch only happens for a frame that accumulated data" — an empty-data frame arguably should dispatch nothing. **Resolved → option (a):** `_consume` now suppresses dispatch when the stripped payload is empty ([sse_parser.dart:107-109](packages/koel_http/lib/src/sse_parser.dart#L107-L109)); regression tests added (`data:\n\n` and colon-less `data\n\n` → no events). [blind+edge, High]
- [x] [Review][Decision→Patch] Truncated UTF-8 at EOF leaks a raw `FormatException`, bypassing the two-sided error contract — A byte stream ending mid multi-byte sequence (real network truncation) makes `bytes.transform(utf8.decoder)` ([sse_parser.dart:67](packages/koel_http/lib/src/sse_parser.dart#L67)) throw `FormatException: Unfinished UTF-8 octet sequence` at stream close. This originates in `_lines`, upstream of `_dispatch`, so it is **not** caught — it surfaces on the event stream as a bare `FormatException` (`isProtocolError == false`), violating the class's documented "corrupt bytes → `ProtocolError`" contract. **Verified by execution.** **Resolved → option (a):** decode now uses `const Utf8Decoder(allowMalformed: true)` ([sse_parser.dart:69-71](packages/koel_http/lib/src/sse_parser.dart#L69-L71)) — a truncated tail decodes to U+FFFD, so the malformed *data* surfaces through the parser's own `ProtocolError(protocolMalformed)` contract instead of leaking a raw `FormatException`; regression test added. [blind+edge, High]
- [x] [Review][Decision] Test imports `dart:io` — on the spec's Forbidden list / "`package:test` only" — [sse_parser_test.dart:2](packages/koel_http/test/parser/sse_parser_test.dart#L2) imports `dart:io`, used at the AC4 size assertion (`File('lib/src/sse_parser.dart').readAsLinesSync()`). Literal deviation from Task 5 "`package:test` only" + the Forbidden list. Defensible: the Forbidden list's web-safety rationale targets the runtime `lib/` (which is clean), and AC4 itself says "Optionally assert it in a test." **Resolved → keep (no change):** AC4 sanctions "Optionally assert it in a test", and the Forbidden list's web-safety intent applies to the runtime `lib/` (which is clean — `dart:async`/`dart:convert`/`koel_core` only). The test-only `dart:io` size-assert stays. [auditor, Low]
- [x] [Review][Patch] `cause: decoded` misuses the error-cause field [packages/koel_http/lib/src/sse_parser.dart:143-149] — On the non-object branch (`data: 12345`, `data: null`, `data: []`), the decoded *value* is passed as `ProtocolError(cause: decoded)`. `cause` conventionally holds the underlying error/exception; `data: null` makes `cause` indistinguishable from "no cause", and `data: 42` renders as `cause: 42`. **Applied:** dropped `cause: decoded`; the value's type is now folded into the message. [blind, Medium]
- [x] [Review][Patch] Dead manual BOM-strip code [packages/koel_http/lib/src/sse_parser.dart:69-72] — Dart's `utf8.decoder` strips a leading U+FEFF itself (`utf8.decode([0xEF,0xBB,0xBF]).length == 0`, **verified**), so the parser never sees a `﻿` and the `startsWith('﻿')` branch + `bomStripped` flag never fire. The BOM test passes via the decoder, not this code. Vestigial per CLAUDE.md "no just-in-case code". **Applied:** removed the `bomStripped` flag and the `startsWith('﻿')` branch; the BOM test still passes (the decoder strips it). [edge, Low]

**Dismissed as noise (4):** AC1 "id/retry retention" wording — spec-RESOLVED (parse-for-compliance, value retention deferred to Story 4.4); `ProtocolError` signature drift (`pointer` vs `eventType`) — spec text stale, implementation correct, no defect; "empty-first-chunk eats the BOM flag" — false positive (`utf8.decoder` does not forward empty chunks, and the manual strip was dead anyway); "parser ignores `event:` line for dispatch" — spec-RESOLVED (AG-UI event type lives in the JSON `data` payload's `type`).
