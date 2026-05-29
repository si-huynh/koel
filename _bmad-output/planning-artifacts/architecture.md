---
stepsCompleted: [1, 2, 3, 4, 5, 6, 7, 8]
lastStep: 8
status: 'complete'
completedAt: '2026-05-28'
inputDocuments:
  - _bmad-output/planning-artifacts/prds/prd-koel-2026-05-27/prd.md
  - _bmad-output/planning-artifacts/prds/prd-koel-2026-05-27/addendum.md
  - _bmad-output/planning-artifacts/briefs/brief-koel-2026-05-27/brief.md
workflowType: 'architecture'
project_name: 'koel'
user_name: 'Si Huynh'
date: '2026-05-28'
---

# Architecture Decision Document — koel

_This document builds collaboratively through step-by-step discovery. Sections are appended as we work through each architectural decision together._

## Project Context Analysis

### Project type
SDK / Dart-Flutter library implementing the AG-UI protocol. Not an application. Architectural
concerns are: package boundaries, API surface discipline (one-way doors), codegen pipeline,
testing layers, web vs native transport divergence, CI/release mechanics, and DevTools
extension wiring. Concerns absent by design: hosting, database schemas, auth, deployment
topology, multi-tenancy.

### Requirements Overview

**Functional Requirements (~50 across 9 groups).** Trục kiến trúc:
- Group A — Protocol kernel (`koel_core`): `AbstractAgent.run() → Stream<AgUiEvent>`, sealed
  `AgUiEvent` (~28 subtypes + `UnknownAgUiEvent`), 4-stage pipeline (chunks → verify → apply
  → transform), interceptor chain, sealed `KoelError` + `KoelErrorCode` + `ErrorClassifier`,
  `AgentSubscriber` callback bag.
- Group B — Transport (`koel_http`): `HttpAgent`, `SseParser`, 6 built-in interceptors,
  cancellation propagation, reconnect+backoff, chunk synthesis, web/native split.
- Group C — Backend adapters (`koel_agno`, `koel_langgraph`, `koel_runtime`): SSE-over-HTTP
  primary plus GraphQL bridge for the CopilotKit Next.js runtime.
- Group D-E — Flutter glue (`koel_flutter`, `koel_widgets`): `KoelChatController extends
  ChangeNotifier`, `KoelClientScope` `InheritedWidget`, session storage adapters,
  `WidgetResolver` generative-UI host, M3/Cupertino widget primitives.
- Group F — DevTools (`koel_devtools`): live stream, time-travel replay (bounded ring buffer),
  tool-call inspector, network panel, JSON Lines trace export — ships as a Flutter DevTools
  extension.
- Group G — Testing (`koel_test`): captured fixtures from 4 reference backends, `MockAgent`,
  tool-handler harness, `ConformanceRunner`.
- Group H-I — Distribution: 10 publishable packages on pub.dev, hybrid versioning, CI/CD
  matrix, default-OFF telemetry.

**Non-Functional Requirements (architecturally binding):**
- Regression-relative perf SLOs (N-1..N-5) — bench harness must exist before v1.0.0; CI
  gates per-PR at >10% regression on SSE parse throughput, reducer latency, memory, cold
  start, and streaming frame jank.
- Bounded buffer + configurable backpressure (N-6) — `pauseUpstream` default propagates
  TCP-window close to the backend.
- Cancellation determinism <50 ms (N-8) — TCP-close-only semantics, fallback silent-drop
  with one-shot debug warning when the underlying client does not honor abort.
- Six Flutter platforms (N-11) — web requires SSE-over-XHR fallback (no `dart:io`).
- Coverage tiers (N-12) — foundations ≥90% line+branch, adapters ≥80%, generated files
  excluded, per-PR patch coverage ≥85%.
- Forward-compat policy (FC-1..FC-4) — sealed-union minor bumps are safe only because
  `koel_lints` enforces consumer-side `default:` branches. The lint plugin is an
  architectural artifact, not just tooling.

### Scale & Complexity

- Primary domain: Dart/Flutter SDK + protocol implementation
- Complexity level: medium-to-high for an SDK (low for an application). Driven by:
  10 packages × codegen × custom analyzer plugin × DevTools extension × multi-backend
  conformance × web/native transport split.
- Estimated architectural components: ~80-120 module-level units across the 10 packages
  plus ~5 supporting subsystems (codegen orchestration, fixture-capture pipeline,
  CI/release matrix, perf-benchmark harness, API-surface-diff tool).

### Technical Constraints & Dependencies

**Hard constraints (PRD §7, §11, §12; Addendum B):**
- Dart 3.0+ floor; Flutter 3.10+ floor on Flutter packages.
- Foundations (`koel_core` + `koel_http` + `koel_lints`) release lock-step with identical
  semver. Backends and Flutter packages depend via `^X.Y.0` ranges.
- Public API is one-way door: zero breaking changes within 1.x; rename/signature change
  forces 2.0.0.
- AG-UI has no version negotiation — architecture is defensive (`UnknownAgUiEvent` plus
  lint-mediated exhaustive-switch protection).
- Wire-format sanity (raw JSON shape per SSE event) lives in `koel_http`'s `SseParser`,
  not in the `koel_core` pipeline. The pipeline only sees typed `AgUiEvent` instances.
- No auto-isolate spawning; consumers wrap `KoelClient` in `Isolate.run` themselves.

**Pinned tech (Addendum B):**
- `freezed` for immutable data; `package:json_patch` for RFC 6902; `package:http` (not
  Dio); Melos for monorepo; `dart:io` socket on native + `package:web` EventSource on web.

**External dependency anchors:**
- AG-UI spec `release/2026-05-26` — pinned commit SHA in `koel_core/CONFORMANCE.md` at
  v1.0.0 publish.
- 4 reference backends (AG-UI dojo, agno, langgraph, CopilotKit Next.js runtime) for
  fixture capture.
- Flutter DevTools extension API (`devtools_extensions` package).

### Cross-Cutting Concerns Identified

1. **Codegen orchestration.** `freezed` + `json_serializable` + custom analyzer plugin
   (`koel_lints`) must compose cleanly with Melos build pipeline. Consumers see only
   generated output on pub.dev.
2. **4-stage event pipeline.** Defined in `koel_core`, wired by `koel_http`, observed by
   `koel_devtools`, exercised by `koel_test`. Stage order is locked.
3. **Interceptor framework.** Contract in `koel_core`; 6 built-ins ship in `koel_http`.
   Retry semantics interact with subscribers (subscribers see each retry attempt by design).
4. **Sealed error hierarchy + ErrorClassifier.** Defined in `koel_core`; each adapter
   subclasses `DefaultErrorClassifier` to map backend-specific error shapes. Adapters
   never throw `KoelError` — they emit `RunErrorEvent` carrying it.
5. **Conformance fixture pipeline.** Build/release prerequisite, not runtime. Capture
   script (4 backends → JSON Lines) must be re-runnable when AG-UI spec releases.
   `koel_test`'s `FixtureLoader` consumes; `ConformanceRunner` exercises.
6. **Web vs native transport divergence.** Shared `SseParser`; split byte-stream source:
   `dart:io` socket on native vs browser `EventSource` on web. CI exercises both paths.
7. **DevTools extension wiring.** `koel_devtools` ships `DevToolsObserver implements
   AgentSubscriber`. Replay semantics gate tool-handler side effects via `ToolReplayContext`
   `InheritedWidget`. Separate package, shared lifecycle with `KoelClient`.
8. **Multi-isolate boundary.** Not auto-spawned; consumer-controlled. But `ChatState`
   must remain const-comparable (Riverpod-friendly), so reducer purity is an
   architectural contract.
9. **Backpressure.** Default `pauseUpstream` propagates TCP-window close; alternatives
   `dropOldest`/`dropNewest` logged at warning level with counter. Policy at `KoelClient`,
   implementation in `koel_http` bounded buffer.
10. **CI matrix.** 10 packages × 6 platforms × (analyze + test + coverage + conformance
    + dry-run publish + perf benchmark + API surface diff). Total CI runtime tracked as
    counter-metric CM-5.

## Project Scaffolding Approach

### Why this section is not "Starter Template"

koel is a multi-package Dart/Flutter SDK monorepo, not an app. There is no
`create-koel-sdk` equivalent; the PRD has already committed to Melos (Addendum B.5).
The architecturally relevant question is: how do we bootstrap 10 packages with
consistent conventions without carrying generated boilerplate that violates the
"every line earns its place" bar?

### Options Considered

**Option 1 — Manual scaffold via `dart create --template=package` + `flutter create
--template=package`**
- Pros: zero tool dependency; intentional structure; matches the craft-over-velocity
  ethos; allows `koel_lints` (analyzer plugin) to use its own non-standard structure
  via `analysis_server_plugin` (entry `lib/main.dart`; see D3).
- Cons: repetitive across 10 packages; risk of convention drift (mitigated by
  `koel_lints` enforcement and CI checks).

**Option 2 — `very_good_cli` (`very_good create dart_pkg | flutter_pkg`)**
- Pros: VGV's premium-Dart baseline (analysis_options strict, coverage setup, README
  skeleton, CI scaffolding) is the industry reference.
- Cons (decisive): bundles `package:very_good_analysis`, which conflicts with
  `koel_lints` (koel ships its own lint baseline — two cannot coexist coherently).
  VGV CI templates target single-package or single-app; koel needs a 10 × 6
  platforms × perf-bench + API-diff matrix that would be rewritten end-to-end.
  Generated README/changelog do not match koel's documentation quality bar
  (PRD §13 D-1).

**Option 3 — Custom-authored `mason` brick**
- Pros: codifies conventions; deterministic regeneration.
- Cons: requires authoring the brick before a reference package exists. Conventions
  are not yet stable enough to encode. Over-engineering for a 10-package one-off.

**Option 4 — Hybrid: manual bootstrap, defer brick**
- Bootstrap the first 2-3 packages manually (`koel_core`, `koel_http`, one backend
  adapter). Let conventions stabilize. Codify only if the remaining 7 packages
  would benefit — and likely via a thin `tool/scaffold.dart` rather than a mason
  brick.

### Selected: Option 4 (manual + Melos; defer scaffolding tool)

**Rationale:** koel ships its own `koel_lints` package, which makes `very_good_cli`'s
bundled analysis baseline an active conflict, not a neutral default. CI shape is too
specific (perf benchmarks, API surface diff, multi-platform conformance) for any
external template to be a starting point worth keeping. Manual scaffolding via the
official Dart/Flutter package templates produces minimum-viable structure that we
extend deliberately. Conventions get codified into a tool only after they have
proven themselves on the first 2-3 packages — not before.

### Initialization commands

```bash
# 1. Workspace root — Dart pub workspace + Melos config
mkdir koel && cd koel
git init
# Initialize pubspec_overrides + workspace pubspec.yaml manually
# (no CLI for this — it is ~15 lines)

# 2. Bootstrap Melos (Dart 3.6.0+ required for pub workspaces; recommend 3.9.0+)
dart pub global activate melos 7.8.0
# Create melos.yaml at repo root manually (workspace member globs, scripts)

# 3. Scaffold each Dart-only package (koel_core, koel_http, koel_lints,
#    koel_agno, koel_langgraph, koel_runtime, koel_test, koel meta)
cd packages
dart create --template=package koel_core
dart create --template=package koel_http
# ... etc.

# 4. koel_lints — analyzer plugin; structure is custom (analysis_server_plugin:
#    entry lib/main.dart, not standard package template — see D3)
dart create --template=package koel_lints
# Then restructure: lib/main.dart (Plugin entry) + lib/src/rules/ following asp conventions

# 5. Scaffold each Flutter package (koel_flutter, koel_widgets, koel_devtools)
flutter create --template=package koel_flutter
flutter create --template=package koel_widgets
flutter create --template=package koel_devtools
# koel_devtools also requires devtools_extensions package wiring (see
#   architecture decisions in step-05)

# 6. Run melos bootstrap to link workspace
melos bootstrap
```

### Architectural Decisions Implied by This Approach

- **Workspace root**: pub workspaces (Dart 3.6.0+) + Melos 7.8.0 orchestration.
- **PRD update required**: §10.3 N-9 Dart SDK floor moves from 3.0+ to **3.9.0+**
  (Melos 7.x recommended; pub-workspace minimum is 3.6.0+). Decision deferred to
  step-04, but flagged here.
- **Per-package `pubspec.yaml`**: hand-authored; foundation packages declare exact
  dev dependencies (`freezed`, `build_runner`, `json_serializable`, `test`,
  `coverage`); backend bridges declare ranged dependencies on foundations
  (`^X.Y.0`) per PRD §12 R-3.
- **Lint enablement** lives in the **workspace-root** `analysis_options.yaml` (asp
  `plugins:` + `diagnostics:`, per D3); the `koel_lints` profile `lib/koel.yaml`
  itself extends `package:lints/recommended.yaml`. Bootstrap order: `koel_lints` is
  installed via path dependency during initial development, package dependency at
  first publish.
- **No `package:very_good_analysis`** dependency anywhere. Removed if `dart create`
  added it by default.
- **`koel_devtools` Flutter package** additionally depends on `devtools_extensions`
  for the extension API (per Addendum G).
- **Scaffolding tool decision deferred to v0.x**: once conventions stabilize across
  the first 2-3 packages, evaluate whether a thin `tool/scaffold.dart` script
  benefits the remaining packages. Mason brick is unlikely to pay off at 10-package
  scale.

**Note:** Workspace initialization and per-package scaffolding will be the first
implementation stories. The `koel_lints` package must be functional early (even as
a stub) because every other package's `analysis_options.yaml` includes its profile.

## Core Architectural Decisions

### Decisions made by PRD / Addendum (not re-decided)

Already locked in PRD §7-12 and Addendum B: 10-package monorepo via Melos;
`freezed` for data classes; `package:http` (not Dio); `package:json_patch` (RFC 6902);
sealed `AgUiEvent` + `KoelError`; 4-stage event pipeline (chunks → verify → apply →
transform); interceptor chain + 6 built-ins; `AgentSubscriber` callbacks; hybrid
versioning (foundations lock-step + backends ranged); `ChangeNotifier` LCD Flutter
binding; state-mgmt agnostic; `dart:io` socket + `package:web` browser split for SSE;
no auto-isolate spawn.

This step records only decisions that remained open after the PRD / Addendum.

### D1 — Dart SDK floor

**Decision:** Dart 3.10.0+ _(raised from 3.9.0+ via correct-course SCP-2026-05-29)_
**Rationale:** The D3 `analysis_server_plugin` toolchain requires `analyzer >=13`
(in-SDK asp shipped with Dart 3.10 / Flutter 3.38), and `pubspec.lock` already
resolves `sdks.dart: ">=3.10.0"` (transitively forced) — so 3.10.0 is the real
floor and pinning lower invites `pub get` failure. This **closes retro
Discovery-D4** (the `.tool-versions 3.9.0` vs lock `>=3.10.0` contradiction). Melos
7.x is satisfied (its floor is 3.6.0+). The 2026 Dart consumer base on < 3.10 is
not materially present per PRD §16 falsifier.
**Contributor / CI pin:** `.tool-versions` pins **Dart 3.12 / Flutter 3.44**
(unchanged). Per **correct-course SCP-2026-05-29-B** the workspace resolves at
**`analyzer 12.1.0`** (`analysis_server_plugin 0.3.14` + `freezed 3.2.6-dev.1`) so
that build-time codegen and the analysis-time plugin coexist in one pub-workspace
resolution; the analyzer-12 plugin is **verified to load + fire on the Dart-3.12
(analyzer-13) analysis server**. Re-verify this skew on any Dart SDK bump. Declared
floor stays `>=3.10.0`. (Was `asp 0.3.15` + `analyzer 13.0.0` under SCP-2026-05-29;
returns there via the D2/D3 upgrade trigger when stable `freezed` supports analyzer 13.)
**PRD update required:** §10.3 N-9 changes from "Dart 3.0+" to "Dart 3.10.0+".
**Affects:** every package's `pubspec.yaml` SDK constraint; `.tool-versions`; CI
`setup-dart` pin.

### D2 — `freezed` major version

**Decision:** `freezed: 3.2.6-dev.1` + `freezed_annotation: ^3.1.0` (build_runner-based)
_(amended from `^3.2.5` via correct-course **SCP-2026-05-29-B**)_.
**Rationale:** Dart macros stalled; freezed has not adopted them. Codegen path is
mature; consumer build_runner integration is the established norm. The exact
pre-release pin is a **documented stopgap**: no _stable_ `freezed` supports
`analyzer 13` (stable caps `<11`), but `freezed 3.2.6-dev.1` supports `analyzer 12`,
which lets it share one workspace resolution with `koel_lints` once D3's plugin is
held at analyzer 12 (validated end-to-end: bootstrap + codegen + lint all green).
**Upgrade trigger (exit):** when a _stable_ `freezed` supports `analyzer >= 13`,
bump in lockstep with D3 — `freezed → stable`, `analysis_server_plugin → 0.3.15`,
`analyzer → ^13.0.0`, `analyzer_testing → 0.2.6` — then re-bootstrap + re-test.
**Affects:** every package with data classes (`koel_core`, `koel_flutter`).

### D3 — `koel_lints` analyzer plugin technology

**Decision:** Build `koel_lints` on `analysis_server_plugin: 0.3.14` +
`analyzer: ^12.0.0` (`analyzer_testing: 0.2.5`) _(reversed from `custom_lint 0.8.1`
via correct-course SCP-2026-05-29; analyzer **13 → 12 stopgap** via SCP-2026-05-29-B
so the plugin shares one workspace resolution with `freezed` — see D2 upgrade
trigger. The **rule source is unchanged**: the analyzer 12/13 `AnalysisRule` API is
source-compatible and all `koel_lints` tests pass on analyzer 12)_.
**Rationale:** The originally-chosen `custom_lint` is non-viable on two independent
grounds: (1) `invertase/dart_custom_lint` was **archived 2026-03-24** — dead
upstream; (2) it **structurally fails on koel's native pub workspace** — its
plugin path resolves rules via a per-member `.dart_tool/package_config.json` that
pub workspaces never create, so the principal rule fires only in `koel_lints`'s own
unit tests, never on consumer source (CLI or IDE — both empirically confirmed
broken). `analysis_server_plugin` is the **first-party** replacement (Dart team),
runs inside the analysis server (no separate process, no temp `pub get` hack), is
**workspace-native by construction**, and integrates directly into `dart analyze`
+ IDEs. The rule ports mechanically (same AST, same type-name keying) and is
**proven to fire** via the official `analyzer_testing` harness (2/2). It requires
removing `custom_lint`/`custom_lint_builder` workspace-wide (custom_lint pins
`analyzer 8.4.0`), which frees `analyzer → 13` + `asp → 0.3.15` (ties into D1).
**Affects:** `koel_lints` layout — plugin entry **must** be `lib/main.dart` (asp
discovery convention; see Convention §2 exception note), rules under
`lib/src/rules/`, tests via `analyzer_testing` (`AnalysisRuleTest`) + a `dart
analyze` integration check; consumer wiring moves to a **single workspace-root**
`analysis_options.yaml` (asp `plugins:` + `diagnostics:`), not per-package
`include:` (see G-3 / Story 1.7).

### D4 — SSE web transport: browser `EventSource` vs hand-rolled fetch+ReadableStream

**Decision:** Hand-rolled fetch + ReadableStream via `package:web` on the web target.
**Rationale (decisive):** Browser `EventSource` API forbids custom request headers.
AG-UI authentication is Bearer-token over the `Authorization` header (PRD F-B2
`AuthInterceptor`). Using `EventSource` would silently break `AuthInterceptor` on
web — a non-starter given the framework promises auth works uniformly across
platforms. Hand-rolled fetch + ReadableStream preserves full header control and
reuses the existing `SseParser` (hand-authored per Addendum D.7) and `RetryInterceptor`
reconnect logic.
**Affects:** `koel_http` ships two transport implementations (`dart:io` socket native
+ `package:web` fetch+ReadableStream browser) sharing one `SseParser`. CI matrix
exercises both paths.

### D5 — `koel_runtime` GraphQL client

**Decision:** Hand-rolled HTTP+JSON parser; no GraphQL client library dependency.
**Rationale:** CopilotKit Next.js runtime serves `generateCopilotResponse` via HTTP
@defer/multipart streaming (not WebSocket subscriptions). `package:graphql` 5.2.4
brings cache, ObservableQuery, WebSocketLink — none of which koel_runtime needs.
`package:gql` plus the `gql_link` ecosystem still pulls a multi-package dependency
tree for one mutation. Hand-rolled implementation (~200 LOC: POST + multipart-stream
parse + AG-UI event translation) is reviewable in one sitting and free of churn risk
— same logic as Addendum D.7's rejection of `package:sse`.
**Affects:** `koel_runtime` ships a `MultipartGraphQLStreamParser` analog to
`koel_http`'s `SseParser`. Zero third-party GraphQL dependency.

### D6 — DevTools extension UI technology

**Decision:** Flutter web (only option supported by `devtools_extensions` 0.5.1).
**Rationale:** `devtools_extensions` exclusively supports Flutter web extensions
embedded via iFrame; HTML+CSS is not an option. Decision is forced by upstream.
**Affects:** `koel_devtools` build adds a Flutter web compile to the CI matrix;
bundle size tracked as part of CM-5 build-time counter-metric.

### D7 — API surface diff tool (SC-4 / N-14 CI gate)

**Decision:** `dart_apitool: ^0.23.1`, run per-package in CI matrix.
**Rationale:** Direct fit for "zero breaking changes after 1.0.0" — analyzes
public API and diffs against a baseline. Used by Very Good Ventures and Flutter
team. Alternatives (hand-rolled grep over `dart doc` output) are fragile and
under-cover edge cases (extension methods, sealed subtypes, default parameter
changes).
**Affects:** CI workflow includes `dart_apitool extract` step per package on every
PR, diffed against the published v1.x.y baseline. Diff failure blocks merge.

### D8 — Fixture storage location

**Decision:** Bundle JSON Lines fixtures inside `koel_test/lib/src/fixtures/*.jsonl`
as package assets.
**Rationale:** Estimated payload is ~50 KB compressed (4 backends × ~28 event types ×
~5 scenarios × ~500 B/event). Pub.dev tarball limit is 10 MB; impact is negligible.
Bundled fixtures give consumers ergonomic offline use:
`MockAgent.fromFixture('text_only_run')` works with zero additional setup.
Externalizing fixtures (Git submodule, separate pub.dev package, GitHub-release
download) trades 50 KB for bootstrap friction — wrong trade for the scale.
**Affects:** `koel_test/lib/src/fixtures/` directory structure; `FixtureLoader`
reads via `package:` asset URI; fixture-capture pipeline emits directly into this
location.

### Bonus — `json_patch` staleness concern (raised as PRD addendum)

`package:json_patch` 3.0.0 was last published 4 years ago. For a production v1 SDK
committing to "zero churn," this is a material risk.

**Decision:** Vendor inline. Implement RFC 6902 strict-mode application inside
`koel_core/lib/src/json_patch/` (~300 LOC). Same justification as Addendum D.7
rejecting `package:sse`: when an external dependency is a small algorithm with
churn risk, an internal implementation is the correct call. Aligns with the "read
framework source" principle.
**Affects:** `koel_core` removes `json_patch` dependency; ships `JsonPatch.apply`,
`JsonPatchOp` types, and an internal test suite mirroring RFC 6902 fixtures.
**PRD update required:** Addendum B.3 (currently selects `package:json_patch`)
updates to reflect the vendor-inline decision.

### Decision Priority & Implementation Sequence

**Critical (block first implementation story):**
- D1 (SDK floor) — sets `pubspec.yaml` constraint everywhere
- D3 (analysis_server_plugin) — `koel_lints` is path-dependency for every other package
- D6 (Flutter web for DevTools) — forces CI matrix shape

**Important (shape package internals):**
- D2 (freezed 3.x), D4 (web SSE transport), D5 (GraphQL hand-roll), D7 (dart_apitool),
  D8 (fixture bundling), Bonus (json_patch vendor-inline)

**Cross-component dependencies:**
- D3 must publish before any other package can adopt the analyzer profile
  (path-dependency during development, package-dependency after first publish).
- D4 + D6 expand CI matrix: web platform compile required for `koel_http`,
  `koel_devtools`, `koel_flutter`, `koel_widgets`.
- D5 isolates `koel_runtime` from `koel_http`'s SSE transport — independent CI lane.
- Bonus (json_patch vendor-inline) removes one transitive dependency from `koel_core`,
  improving CM-3 dependency weight.

### Deferred decisions (impl-time, not architectural)

- Benchmark harness specifics (`package:benchmark_harness` vs hand-rolled timing)
- Coverage aggregation script (`melos run coverage` shape)
- GitHub Actions job matrix shape (per-package vs single melos-orchestrated)
- Web vs native trace persistence implementation in `koel_devtools` export
- Specific `package:web` API surface (EventSource not used; fetch + ReadableStream used)

## Implementation Patterns & Consistency Rules

These rules bind every contributor (human + AI agent) and resolve the small choices
that, left implicit, cause drift across the 10-package surface. None override the
PRD or Addendum; they fill the gaps.

### 1. Naming & file layout

**Dart filename:** `snake_case.dart`. No exceptions.
- ✅ `chat_state.dart`, `http_agent.dart`, `koel_chat_controller.dart`
- ❌ `chatState.dart`, `ChatState.dart`, `chat-state.dart`

**Generated files:** colocated next to source; gitignored, CI-verified.
- `chat_state.dart` ↔ `chat_state.freezed.dart` ↔ `chat_state.g.dart`
- `.gitignore` excludes `*.g.dart`, `*.freezed.dart`, `*.mocks.dart` at the repo
  root.
- CI runs `melos run build && git diff --exit-code` to guarantee committed sources
  produce no codegen diff. A drift fails the build with the offending diff.
- **Why gitignore, not commit:** Flutter ecosystem default; pub.dev publish process
  injects generated files into the tarball anyway, so consumers always get them.
  Committing inflates review noise (~3-4× line count per freezed class) and creates
  merge conflicts. The CI verification step closes the "silent codegen drift" gap
  that commit-all is sometimes used to address.

**Class & type naming (Effective Dart):**
- `UpperCamelCase` for types, including acronyms: `HttpAgent` not `HTTPAgent`,
  `KoelClient` not `KOELClient`, `SseParser` not `SSEParser`.
- `lowerCamelCase` for methods, getters, parameters, local variables.
- `SCREAMING_SNAKE_CASE` is **not** used; even constants are `lowerCamelCase` per
  Effective Dart (e.g., `defaultBufferSize`, not `DEFAULT_BUFFER_SIZE`).
- Private members prefix with `_` (`_internalBuffer`).

**koel-specific naming:**
- Sealed-subtype types end in their family suffix: `*Event` for `AgUiEvent` subtypes
  (`RunStartedEvent`, `ToolCallChunkEvent`); `*Error` for `KoelError` subtypes
  (`TransportError`, `AgentError`); `*Segment` for `MessageSegment` subtypes.
- Interceptor classes end in `Interceptor` (`AuthInterceptor`, `RetryInterceptor`).
- Subscriber implementations end in `Subscriber` or `Observer` (`DevToolsObserver`).
- Backend-adapter agents end in `Agent` (`AgnoAgent`, `LangGraphAgent`,
  `CopilotRuntimeAgent`).

**Test files:** `*_test.dart`. Mirrors the source-file path one-to-one under `test/`.
- Source: `lib/src/parser/sse_parser.dart`
- Test: `test/parser/sse_parser_test.dart`

**Fixture files:** `*.jsonl`, `snake_case` name describing the scenario.
- ✅ `text_only_run.jsonl`, `tool_call_with_state_delta.jsonl`,
  `reasoning_with_encrypted_value.jsonl`
- ❌ `TextOnlyRun.jsonl`, `tool-call-with-state-delta.jsonl`

### 2. Public/private discipline

**Barrel file = 1.x contract.** Every package has exactly one barrel file at
`lib/<package_name>.dart` that re-exports the public API. Nothing outside the
barrel is part of the public contract.
- ✅ `lib/koel_core.dart` exports `lib/src/event/ag_ui_event.dart`,
  `lib/src/agent/abstract_agent.dart`, etc.
- ❌ Consumers importing `package:koel_core/src/event/ag_ui_event.dart` directly —
  this is a private path even though Dart does not enforce it; documented as
  "private" in `lib/koel_core.dart` header comment.

**`lib/src/` is private** by convention. CI lint (custom rule in `koel_lints`)
flags any consumer-side import from another package's `src/` path. The internal
test for `dart_apitool` (D7) ignores `src/` symbols.

**Barrel hygiene:**
- One export per symbol; no `export 'src/foo.dart' show A, B, C, D, E` walls of
  text. Group by domain with section comments.
- No `export 'src/foo.dart' hide _Internal` patterns — if it should be hidden,
  it stays private.
- Re-exports of upstream packages (e.g., `koel` meta re-exporting `koel_core`)
  use `export 'package:koel_core/koel_core.dart';` — one line per re-exported
  barrel, never deep paths.

**Meta-package `koel`:** re-exports `koel_core` + `koel_http` + `koel_flutter`
only. Does not re-export `koel_lints` (consumed via analyzer config), backend
adapters (consumers pick), or `koel_widgets` / `koel_devtools` / `koel_test`.

**Exception — `koel_lints` has no Dart barrel.** `koel_lints` is an analyzer-plugin
package, not a consumable library: no one `import`s it. Under `analysis_server_plugin`
(D3) its plugin entry **must** be `lib/main.dart` (asp's discovery convention), and
its consumer-facing surface is the analyzer profile `lib/koel.yaml` — not a
`lib/koel_lints.dart` barrel. It is therefore exempt from the single-barrel rule
(already flagged non-standard via AR-2 / G-3).

### 3. Type & data conventions

**Immutability default:** `freezed` for any type with > 1 field that crosses
package boundaries or persists. Hand-written immutables only for trivial wrappers
(e.g., a one-field `ThreadId`).

**Sealed switches always have `default:` arms.** Enforced by `koel_lints` rule
`exhaustive_switch_must_have_default` on `AgUiEvent`, `KoelError`, `MessageSegment`.
The `default:` arm logs at debug level and either swallows (for events) or rethrows
with a wrapping `UnknownError` (for errors).

```dart
// ✅ Correct
switch (event) {
  case RunStartedEvent e: handleStart(e);
  case RunFinishedEvent e: handleFinish(e);
  // ... other known cases
  default:
    log.fine('Ignoring unhandled event: ${event.runtimeType}');
}

// ❌ Wrong — linter rejects
switch (event) {
  case RunStartedEvent e: handleStart(e);
  case RunFinishedEvent e: handleFinish(e);
}
```

**`const` everywhere it compiles.** Constructor `const` by default; data-class
instances `const`-constructed when literals.

**`copyWith` is the only mutation path** on immutable types. No setters on freezed
data; if a field must change post-construction, it's a code-smell — surface a
fresh value through the reducer.

**Collections in data classes:** `List` / `Map` / `Set`, always unmodifiable views
on read (`List.unmodifiable`, `Map.unmodifiable`). `freezed` types use `IList` /
`IMap` from `package:fast_immutable_collections` only if profiling shows hot-path
copy cost — default to plain unmodifiable lists.

**JSON serialization wire conventions:**
- AG-UI wire uses `camelCase` keys (per TS reference impl). Dart code also uses
  `camelCase`. No `snake_case` ↔ `camelCase` translation layer.
- `json_serializable` config (`build.yaml`) sets `field_rename: none`. Explicit
  per-field `@JsonKey(name: 'wireKey')` only when wire name diverges (rare).
- Unknown wire keys are preserved in `UnknownAgUiEvent.rawJson` verbatim.

**Const-comparable `ChatState`** (architectural contract from cross-cutting #8):
the default `ChatStateReducer` must always return a fresh instance via `copyWith`;
never mutate in place. Verified by a reducer-purity test in `koel_test`.

### 4. Stream & async conventions

**Stream multiplicity:**
- `Stream<AgUiEvent>` from `AbstractAgent.run()` is **single-listener** by default.
  Multi-consumer use cases route through `KoelClient` + `AgentSubscriber` (the
  designed broadcast point), not by wrapping in `Stream.asBroadcastStream()`.
- `Stream<ChatState>` from `ChatSession.stream` **is** broadcast — multiple UI
  widgets can listen.

**Cancellation:**
- Cancellation propagates via `StreamSubscription.cancel()`. Consumers calling
  `cancel()` on `ChatSession` cancel the underlying agent stream subscription,
  which propagates to HTTP abort per F-B3.
- No `cancellation tokens`; Dart's `StreamSubscription` is the cancellation
  primitive.

**No auto-isolate.** SDK runs on the caller's isolate. If a consumer wants
isolate isolation for the reducer or parser, they wrap `KoelClient` themselves
via `Isolate.run`. Documented in concept doc; PRD §10.1 N-5.

**`Future` vs `async/await`:** prefer `async/await` for readability; explicit
`Future.then` chains only when composition genuinely benefits.

**No `print`.** Use `package:logging` exclusively; log levels:
- `Level.FINE` (debug): per-event tracing, cancellation TCP-abort drops
- `Level.INFO`: connection lifecycle (open, close, reconnect attempt)
- `Level.WARNING`: backpressure overflow, retry exhaustion, single debug
  warnings (e.g., abort-not-honored)
- `Level.SEVERE`: protocol violations the SDK cannot recover from; always
  paired with `RunErrorEvent` emission

### 5. Error handling

**Adapters never throw `KoelError`.** Adapters (`HttpAgent`, `AgnoAgent`,
`LangGraphAgent`, `CopilotRuntimeAgent`, `MockAgent`) emit a `RunErrorEvent` into
the stream. The Exception marker on `KoelError` exists only for synchronous
programmer errors (invalid `Uri` in constructors), caught via `Future.catchError`.

```dart
// ✅ Correct — adapter emits, never throws
Stream<AgUiEvent> run(RunAgentInput input) async* {
  try {
    yield* _doRun(input);
  } catch (e, s) {
    final classified = errorClassifier.classify(e, s, input);
    yield RunErrorEvent(error: classified);
  }
}

// ❌ Wrong — throwing breaks the contract
Stream<AgUiEvent> run(RunAgentInput input) async* {
  if (input.threadId.isEmpty) throw TransportError(...);
  // ...
}
```

**`ErrorClassifier` per adapter.** Each backend adapter subclasses
`DefaultErrorClassifier` to map backend-specific failure shapes to
`KoelErrorCode` values. Generic transport/network errors fall back to the default
classifier.

**Error messages:** sentence-cased, no trailing period when treated as data
(e.g., `KoelError.message`); sentence-cased ending with period for log strings.
Never include user-controlled data unescaped in error messages.

**No silent catches.** `catch (_) {}` is banned. Every catch either rethrows,
classifies into `KoelError`, or logs at `WARNING`+ with a stated reason.

### 6. Documentation & testing

**Doc comments:** `///` triple-slash, never `/** */`.
- Every public symbol has a doc comment per PRD §13 D-2.
- Structure: one-line summary, blank line, contract details (what it represents
  + when to use + when not + error cases), blank line, `///` example block or
  `[See also: ...]` link.
- No "what this method does" — names already say. Doc the **contract**.

**`@nodoc` tag:** any public symbol intentionally hidden from `dart doc` output
(rare; usually means it should be private). Triggers a `koel_lints` warning to
encourage privatization instead.

**README structure** (PRD §13 D-1, expanded):
1. One-paragraph "what is this"
2. Quickstart code block (~10 lines)
3. Link to docs site
4. Link to CHANGELOG.md
5. MIT license note
- No badges section beyond pub.dev version + license + CI status (max 3 badges).
- No "Why X" marketing paragraph; the docs site carries that.

**Tests:**
- Mirror source path: `lib/src/foo/bar.dart` ↔ `test/foo/bar_test.dart`.
- Use `package:test` (`test()`, `group()`, `expect()`). No alternative frameworks.
- One top-level `group(<ClassName>, () { ... })` per test file.
- Async tests return `Future`; never use `fakeAsync` unless deterministic time
  control is the test's subject.
- No flaky tests. A test that occasionally fails is a bug, not a property —
  fix or delete.
- Coverage tier per package per PRD §10.4 N-12; generated files (`*.g.dart`,
  `*.freezed.dart`, `*.mocks.dart`) excluded from coverage via the
  `coverage_options.yaml` per-package ignore list.

**Examples (`/example`):**
- One `example/` per package. Runnable as `dart run example/main.dart` (Dart
  packages) or `flutter run example/lib/main.dart` (Flutter packages).
- Smoke-tested in CI: every example compiles and (for non-interactive ones) runs
  to completion without throwing.

### Enforcement summary

**Automated (CI-enforced):**
- `dart analyze` clean with `package:koel_lints/koel.yaml` profile
- `exhaustive_switch_must_have_default` on `AgUiEvent`/`KoelError`/`MessageSegment`
- `dart_apitool` diff against published baseline
- Coverage thresholds per package
- Example smoke tests
- `dart format --set-exit-if-changed`
- `melos run build && git diff --exit-code` (codegen-drift check)

**Convention (review-enforced):**
- Single barrel file per package
- `lib/src/` private discipline (no external import of internal paths)
- Doc comment quality (contract over restatement)
- README structure
- Test-file mirroring

**Anti-patterns to reject in review:**
- `print(...)` calls
- `catch (_) {}` silent catches
- Throwing `KoelError` from adapters
- `export 'src/foo.dart' hide _X` patterns
- `late` variables outside clear init-once cases
- Multi-paragraph doc comments restating code
- Mocking the entire `AbstractAgent` instead of using `MockAgent` from `koel_test`
- Adding a new dependency without justifying it in the PR description (per CM-3)

## Project Structure & Boundaries

### Repository root layout

```
koel/
├── README.md                          # repo intro + monorepo navigation
├── CONTRIBUTING.md                    # monorepo workflow (per F-H1)
├── LICENSE                            # MIT (per-package copy also under each pkg)
├── CHANGELOG.md                       # release-coordination notes only
├── CONFORMANCE.md                     # AG-UI spec commit SHA pin (per SC-1)
├── BENCHMARKS.md                      # reference device profile (per §10.1)
├── melos.yaml                         # Melos workspace + scripts (build, test, perf)
├── pubspec.yaml                       # Dart pub workspace root (Dart 3.10.0+)
├── analysis_options.yaml              # asp plugins: + diagnostics: (enables koel rule for all members)
├── .gitignore                         # *.g.dart, *.freezed.dart, *.mocks.dart, build/, .dart_tool/
├── .github/
│   └── workflows/
│       ├── ci.yml                     # main matrix: 10 packages × 6 platforms
│       ├── conformance.yml            # AG-UI conformance suite (uses koel_test)
│       ├── perf-bench.yml             # regression-relative SLOs (N-1..N-5)
│       ├── api-diff.yml               # dart_apitool surface diff (D7)
│       ├── codegen-drift.yml          # melos run build && git diff --exit-code
│       └── publish-dry-run.yml        # per-package pub publish --dry-run
├── tool/                              # repo-level scripts (not part of any pkg)
│   ├── capture_fixtures.dart          # fixture-capture pipeline (4 backends → JSONL)
│   ├── verify_api_surface.dart        # dart_apitool wrapper
│   └── perf/
│       └── run_benchmarks.dart        # cross-package perf bench orchestrator
├── docs/                              # docs site source (framework: OQ-Docs-Framework)
│   └── (deferred until OQ resolved)
├── example/                           # repo-level quickstart sample app (uses `koel`)
│   ├── pubspec.yaml
│   ├── lib/main.dart                  # generic chat scenario (no business domain)
│   └── README.md
├── _bmad-output/                      # planning artifacts (out of SDK scope)
└── packages/
    ├── koel/                          # meta-package (re-exports core + http + flutter)
    ├── koel_core/                     # foundation: events, pipeline, errors, state
    ├── koel_http/                     # transport: HttpAgent, SseParser, interceptors
    ├── koel_lints/                    # analyzer plugin (analysis_server_plugin based)
    ├── koel_agno/                     # backend bridge: Agno
    ├── koel_langgraph/                # backend bridge: LangGraph
    ├── koel_runtime/                  # backend bridge: CopilotKit Next.js runtime
    ├── koel_flutter/                  # Flutter glue: controller, scope, storage
    ├── koel_widgets/                  # UI primitives: M3 + Cupertino
    ├── koel_devtools/                 # DevTools extension + observer
    └── koel_test/                     # fixtures, MockAgent, ConformanceRunner
```

### Per-package layout: `koel_core` (template for standard Dart packages)

```
packages/koel_core/
├── CHANGELOG.md
├── LICENSE                            # MIT (per-package copy)
├── README.md                          # quickstart + docs link (per §13 D-1)
├── CONFORMANCE.md                     # AG-UI commit SHA pin (only koel_core)
├── pubspec.yaml
├── analysis_options.yaml              # (optional) per-pkg base lints; koel rule enabled at workspace root
├── build.yaml                         # freezed + json_serializable config
├── lib/
│   ├── koel_core.dart                 # ← barrel = 1.x public contract
│   └── src/                           # private; CI flags cross-pkg imports here
│       ├── agent/
│       │   ├── abstract_agent.dart        # F-A1, F-A2
│       │   ├── agent_subscriber.dart      # F-A10
│       │   └── interceptor.dart           # F-A4
│       ├── client/
│       │   ├── koel_client.dart           # F-D3 (multi-client, non-singleton)
│       │   └── chat_session.dart          # F-A2 middle layer
│       ├── event/
│       │   ├── ag_ui_event.dart           # sealed root
│       │   ├── run_events.dart            # RUN_*
│       │   ├── step_events.dart           # STEP_*
│       │   ├── text_message_events.dart   # TEXT_MESSAGE_* + CHUNK
│       │   ├── tool_call_events.dart      # TOOL_CALL_* + CHUNK
│       │   ├── state_events.dart          # STATE_SNAPSHOT / DELTA, MESSAGES_SNAPSHOT
│       │   ├── activity_events.dart       # ACTIVITY_*
│       │   ├── reasoning_events.dart      # REASONING_* incl. ENCRYPTED_VALUE (F-A9)
│       │   ├── raw_event.dart             # RAW
│       │   ├── custom_event.dart          # CUSTOM
│       │   └── unknown_event.dart         # F-A6 forward-compat fallback
│       ├── error/
│       │   ├── koel_error.dart            # sealed; F-A5
│       │   ├── koel_error_code.dart       # typed vocabulary enum
│       │   └── error_classifier.dart      # default + pluggable
│       ├── state/
│       │   ├── chat_state.dart            # freezed; F-D2 contract
│       │   ├── chat_state_reducer.dart    # interface + DefaultChatStateReducer
│       │   ├── composed_reducer.dart      # F-D2 composition
│       │   └── state_conflict.dart        # F-A8 + LastWriterWinsResolver
│       ├── pipeline/                      # F-A11 — 4-stage pipeline
│       │   ├── chunks_stage.dart          # synthesize START/CONTENT/END from CHUNK
│       │   ├── verify_stage.dart          # cross-event sanity (Addendum F.1)
│       │   ├── apply_stage.dart           # fold into ChatState
│       │   └── transform_stage.dart       # consumer-supplied transformers
│       ├── json_patch/                    # vendor-inline (Bonus decision)
│       │   ├── json_patch.dart            # RFC 6902 strict-mode apply
│       │   └── json_patch_op.dart         # add/remove/replace/move/copy/test
│       ├── session/
│       │   ├── session_storage.dart       # abstract (F-D1)
│       │   └── in_memory_session_storage.dart
│       ├── tool/
│       │   └── tool_definition.dart       # JSON Schema params (OQ-Tool-Param-DSL)
│       └── input/
│           └── run_agent_input.dart       # wire payload incl. reasoningEcho
├── test/                              # mirrors lib/src/ path-for-path
│   ├── agent/
│   ├── client/
│   ├── event/
│   ├── error/
│   ├── state/
│   ├── pipeline/
│   ├── json_patch/                    # mirrors RFC 6902 fixtures
│   ├── session/
│   ├── tool/
│   ├── input/
│   ├── reducer_purity_test.dart       # convention #3 verification
│   └── perf/
│       ├── reducer_bench.dart         # N-2 baseline
│       └── cold_start_bench.dart      # N-4 baseline
└── example/
    └── main.dart                      # smallest possible runnable consumer
```

### Per-package variations

**`koel_http`** — transport split:
```
lib/src/
├── http_agent.dart                    # F-B1
├── sse_parser.dart                    # framework-free, ~150 LOC
├── transport/
│   ├── native_transport.dart          # dart:io socket (mobile/desktop)
│   └── web_transport.dart             # package:web fetch + ReadableStream (D4)
├── interceptors/
│   ├── logging_interceptor.dart       # F-B2
│   ├── event_trace_interceptor.dart
│   ├── retry_interceptor.dart         # F-B4 exponential backoff
│   ├── auth_interceptor.dart          # Bearer + custom headers
│   ├── sentry_breadcrumb_interceptor.dart   # default-OFF (F-I2)
│   └── pii_redaction_interceptor.dart       # default-OFF
└── connection/
    ├── lifecycle.dart                 # F-B6 onConnect/onDisconnect hooks
    └── reconnect_policy.dart          # F-B4
test/perf/sse_parse_bench.dart         # N-1 baseline
```

**`koel_lints`** — non-standard structure (`analysis_server_plugin`; D3):
```
packages/koel_lints/
├── lib/
│   ├── koel.yaml                      # ← consumer analyzer profile (external surface)
│   ├── main.dart                      # ← asp Plugin entry: register(PluginRegistry)
│   │                                  #   → registry.registerLintRule(...)
│   └── src/
│       └── rules/
│           ├── exhaustive_switch_must_have_default.dart   # F-A12 principal rule
│           │                                              #   AnalysisRule + LintCode(ERROR)
│           └── prefer_named_constructors_on_sealed_subtypes.dart   # optional
└── test/
    ├── exhaustive_switch_asp_test.dart   # analyzer_testing — AnalysisRuleTest (server-free)
    └── dart_analyze_integration/         # `dart analyze` server-plugin integration check
```
Lint enablement lives in the **workspace-root** `analysis_options.yaml` (asp
`plugins:` + `diagnostics:`), not per-package `include:` (see G-3 / Story 1.7).

**`koel_agno` / `koel_langgraph` / `koel_runtime`** — backend bridges:
```
lib/src/
├── <name>_agent.dart                  # AgnoAgent / LangGraphAgent / CopilotRuntimeAgent
├── <name>_auth_interceptor.dart       # adapter-specific (e.g., AgnoAuthInterceptor)
├── conversion/
│   └── message_conversion.dart        # backend-shape ↔ AG-UI conversion
├── error/
│   └── <name>_error_classifier.dart   # extends DefaultErrorClassifier
└── (koel_runtime only) multipart_graphql_stream_parser.dart   # D5 hand-roll
```

**`koel_flutter`**:
```
lib/src/
├── controller/
│   └── koel_chat_controller.dart      # F-D4 ChangeNotifier binding
├── scope/
│   └── koel_client_scope.dart         # F-D5 InheritedWidget
├── session_storage/
│   ├── hive_session_storage.dart
│   └── secure_session_storage.dart    # flutter_secure_storage backed
├── message/
│   ├── message_content_parser.dart    # F-E1 markdown code-block split
│   ├── message_segment.dart           # sealed
│   ├── text_segment.dart
│   └── code_block_segment.dart
└── generative_ui/
    ├── widget_resolver.dart           # F-E2
    └── tool_replay_context.dart       # F-F7 replay-safety InheritedWidget
test/perf/
├── chat_session_memory_bench.dart     # N-3
└── streaming_jank_bench.dart          # N-5
```

**`koel_widgets`**:
```
lib/src/
├── theme/
│   └── koel_theme.dart                # ThemeExtension<KoelTheme>
├── bubble/
│   ├── message_bubble.dart            # M3 + Cupertino variants
│   ├── material_bubble.dart
│   └── cupertino_bubble.dart
├── input/
│   └── chat_input.dart                # auto-grow + attachment slot
└── follow_up/
    └── follow_up_list.dart
```

**`koel_devtools`** — package + nested DevTools extension UI:
```
packages/koel_devtools/
├── pubspec.yaml
├── extension/
│   └── devtools/
│       ├── config.yaml                # devtools_extensions registration
│       └── build/                     # built Flutter web app (gitignored)
├── lib/                               # consumer-facing observer package
│   ├── koel_devtools.dart             # barrel
│   └── src/
│       ├── observer/
│       │   ├── devtools_observer.dart # implements AgentSubscriber
│       │   └── ring_buffer.dart       # bounded; F-F3 (default 1000)
│       ├── replay/
│       │   ├── replay_state.dart      # re-fold reducer over events[0..N]
│       │   └── replay_context.dart    # ToolReplayContext propagation
│       └── export/
│           ├── jsonl_writer.dart      # F-F6 export
│           ├── jsonl_reader.dart      # round-trip re-import
│           └── session_header.dart    # _session metadata line
├── tool/extension_ui/                 # Flutter web app — the actual UI
│   ├── pubspec.yaml                   # depends on koel_devtools + devtools_extensions
│   ├── lib/
│   │   ├── main.dart
│   │   ├── panels/
│   │   │   ├── stream_panel.dart      # F-F2 live event stream
│   │   │   ├── history_panel.dart     # F-F3 time-travel
│   │   │   ├── inspector_panel.dart   # F-F4 tool-call inspector
│   │   │   ├── network_panel.dart     # F-F5 HTTP-level
│   │   │   └── export_panel.dart      # F-F6 JSONL export
│   │   └── widgets/
│   │       └── event_row.dart
│   └── web/index.html
└── test/
    ├── observer/
    ├── replay/
    └── export/
```

**`koel_test`** — fixtures bundled (D8):
```
lib/
├── koel_test.dart                     # barrel
└── src/
    ├── mock_agent.dart                # F-G2
    ├── fixture_loader.dart            # asset URI reader
    ├── tool_handler_test_harness.dart # F-G3
    ├── conformance_runner.dart        # F-G4
    ├── conformance_report.dart        # result type
    └── fixtures/                      # bundled per D8
        ├── dojo/
        │   ├── text_only_run.jsonl
        │   ├── tool_call_basic.jsonl
        │   ├── state_delta.jsonl
        │   ├── reasoning_with_encrypted_value.jsonl
        │   └── ... (one per event type × scenario)
        ├── agno/
        ├── langgraph/
        └── copilotkit_runtime/
```

**`koel` meta-package** — re-exports only:
```
packages/koel/
├── pubspec.yaml                       # depends on koel_core, koel_http, koel_flutter
├── README.md                          # the quickstart README
└── lib/
    └── koel.dart                      # one barrel: 3 re-exports, ~5 LOC total
```

### Feature → location mapping

| Feature group | Primary location | Cross-package touch |
|---|---|---|
| F-A1..A3 (atomic client, 3-layer API, hybrid stream/state) | `koel_core/lib/src/client/`, `agent/` | — |
| F-A4 (interceptor chain) | `koel_core/lib/src/agent/interceptor.dart` | `koel_http/lib/src/interceptors/` (built-ins) |
| F-A5 (sealed errors) | `koel_core/lib/src/error/` | each adapter's `*_error_classifier.dart` |
| F-A6 (UnknownAgUiEvent) | `koel_core/lib/src/event/unknown_event.dart` | `koel_http/lib/src/sse_parser.dart` (deserialization fallback) |
| F-A7 (full event coverage) | `koel_core/lib/src/event/*_events.dart` | — |
| F-A8 (JSON Patch state) | `koel_core/lib/src/json_patch/` (vendor-inline) + `state/state_conflict.dart` | — |
| F-A9 (reasoning encryptedValue round-trip) | `koel_core/lib/src/event/reasoning_events.dart` + `input/run_agent_input.dart` | — |
| F-A10 (AgentSubscriber) | `koel_core/lib/src/agent/agent_subscriber.dart` | `koel_devtools/lib/src/observer/devtools_observer.dart` |
| F-A11 (4-stage pipeline) | `koel_core/lib/src/pipeline/` | wired by `koel_http`; observed by `koel_devtools` |
| F-A12 (koel_lints rules) | `koel_lints/lib/src/rules/` | every consumer's `analysis_options.yaml` |
| F-B1..B6 (HTTP transport) | `koel_http/lib/src/` | `koel_agno`, `koel_langgraph` extend `HttpAgent` |
| F-C1..C3 (backend bridges) | `koel_agno/`, `koel_langgraph/`, `koel_runtime/` (own packages) | each captures fixtures into `koel_test/lib/src/fixtures/<backend>/` |
| F-D1..D5 (Flutter glue) | `koel_flutter/lib/src/` | `koel_widgets` consumes; `koel_devtools` consumes |
| F-E1..E4 (message + generative UI + theming) | `koel_flutter/lib/src/message/`, `generative_ui/` + `koel_widgets/lib/src/` | — |
| F-F1..F7 (DevTools) | `koel_devtools/extension/`, `tool/extension_ui/`, `lib/src/` | observes `koel_core` via subscriber API |
| F-G1..G4 (testing) | `koel_test/` | exercised by every other package's test suite |
| F-H1..H6 (distribution) | repo root `melos.yaml`, `.github/workflows/`, per-package `README.md` | — |
| F-I1..I3 (CI/hygiene) | `.github/workflows/` | — |

### Architectural boundaries

**Package dependency graph (DAG):**

```
koel_lints  ─── (analyzer-only; no runtime deps from other pkgs)
                Consumed via analysis_options.yaml include.

koel_core   ─── (foundation; depends on nothing koel-internal)
            ↑
            ├── koel_http (foundation)
            │       ↑
            │       ├── koel_agno
            │       └── koel_langgraph
            │
            ├── koel_runtime (independent of koel_http per D5)
            │
            ├── koel_flutter
            │       ↑
            │       ├── koel_widgets
            │       └── koel_devtools
            │
            └── koel_test (test-only; depended on as dev_dependency)

koel (meta) ─── re-exports koel_core + koel_http + koel_flutter
```

**Foundation lock-step boundary:** `koel_core` + `koel_http` + `koel_lints` ship
together with identical semver. A change to any one bumps all three. Backend
bridges and Flutter packages depend on these via `^X.Y.0` ranges (per R-3).

**Adapter boundary (`AbstractAgent` contract):** the SPI between `koel_core` and
backend bridges. Backend bridges implement `AbstractAgent.run()`. They never
import `koel_core/src/` paths — only the barrel.

**Pipeline boundary:** the 4 stages are pure functions invoked by `KoelClient`.
Stages do not know about transport, persistence, or UI. `koel_http` is responsible
for delivering typed `AgUiEvent` instances to the pipeline; `koel_core` is
responsible for everything after.

**DevTools boundary:** `koel_devtools` is **observation-only**. It consumes
`AgentSubscriber` callbacks and never mutates `KoelClient` state. The DevTools
extension UI (Flutter web app under `tool/extension_ui/`) communicates with the
host app's `DevToolsObserver` via the standard `devtools_extensions` ExtensionAPI
— iFrame-isolated, no shared memory.

**Codegen boundary:** `build.yaml` per package; build_runner runs per package.
Generated files never cross package boundaries (no `*.g.dart` in one package
imports another package's `src/`).

### Integration points

**Internal communication (within process):**
- `KoelClient` → `AbstractAgent.run()` → typed `Stream<AgUiEvent>`
- Pipeline stages → chained `StreamTransformer`
- `AgentSubscriber` callbacks: post-pipeline, fired per event consumer would see
- `ChatSession.stream` → `Stream<ChatState>` (broadcast, multi-listener)
- `KoelChatController.notifyListeners()` → Flutter widget tree rebuild

**External integrations:**
- Backend adapters → HTTP/SSE (4 backends): `koel_http` + adapter-specific endpoints
- DevTools extension → Flutter DevTools host (iFrame postMessage via `devtools_extensions`)
- Session storage → `Hive` / `flutter_secure_storage` / in-memory (consumer-pluggable)
- Telemetry (opt-in) → `Sentry` via `SentryBreadcrumbInterceptor` (default-OFF)

**Data flow:**

```
backend SSE → SseParser → typed Stream<AgUiEvent>
            → interceptor chain (wrapped around the stream)
            → pipeline (chunks → verify → apply → transform)
            → subscribers fire (parallel, observation-only)
            → ChatSession.stream emits ChatState
            → KoelChatController.notifyListeners()
            → Flutter widgets rebuild
```

### File organization patterns

- **Configuration files** live at the package root (`pubspec.yaml`,
  `analysis_options.yaml`, `build.yaml`, `CHANGELOG.md`, `README.md`,
  `LICENSE`). Repo root has the workspace-level equivalents.
- **Source code** under `lib/src/` (private) with a single barrel at
  `lib/<package_name>.dart` (public 1.x contract).
- **Tests** mirror `lib/src/` path-for-path under `test/`. Perf benches under
  `test/perf/`.
- **Examples** in `example/` per package (`example/main.dart` for Dart packages,
  `example/lib/main.dart` for Flutter packages). Repo-level `example/` is the
  quickstart sample app using the `koel` meta-package.
- **Static assets** only in `koel_test/lib/src/fixtures/` (JSONL fixtures).
- **Documentation site** source under repo `docs/` (deferred pending
  OQ-Docs-Framework).

### Development workflow integration

- **Bootstrap:** `melos bootstrap` links workspace packages via pub workspaces.
- **Codegen:** `melos run build` invokes `build_runner build` per package; CI
  follows with `git diff --exit-code` for the drift gate.
- **Test:** `melos run test` per-package; `melos run test:coverage` for the
  coverage tier check.
- **Conformance:** `melos run conformance` runs `ConformanceRunner` against
  every backend adapter using captured fixtures.
- **Perf bench:** `melos run perf` runs all `test/perf/*_bench.dart` and compares
  to baseline (CI-gated per N-1..N-5).
- **API diff:** `melos run api-diff` runs `dart_apitool` per package.
- **Publish dry-run:** `melos run publish-dry` runs `pub publish --dry-run` per
  package.
- **Release:** `melos version` then `melos publish` per the hybrid versioning
  policy in PRD §12.

## Architecture Validation Results

### Coherence Validation ✅

**Decision Compatibility:** All architectural decisions (D1-D8 + Bonus) are
internally consistent. None contradicts the PRD/Addendum substantively; three
items require PRD reconciliation as documented updates (not conflicts):

1. **D1 → PRD §10.3 N-9.** Dart SDK floor moves from "Dart 3.0+" to "Dart 3.9.0+"
   (Melos 7.x recommended; pub-workspace minimum 3.6.0+).
2. **PRD §10.3 N-10 (derived from D1).** Flutter SDK floor must move from
   "Flutter 3.10+" to whichever Flutter version ships with Dart 3.9+ (approximately
   Flutter 3.27+). Verify exact version when PRD update lands.
3. **Bonus → PRD Addendum B.3.** Replace "Use existing `package:json_patch`" with
   "Vendor inline under `koel_core/lib/src/json_patch/`" using the same rationale
   as Addendum D.7's rejection of `package:sse`: 4-year staleness is incompatible
   with v1 zero-churn commitment.

**Pattern Consistency:** Implementation patterns (Step 5) directly support every
architectural decision. Examples: D3 (`analysis_server_plugin`) is the mechanism that
enforces the convention §3 sealed-switch default-branch rule; D7 (`dart_apitool`)
enforces the convention §2 barrel-as-public-contract rule; convention §5
(adapter-never-throws) is the contract D5's hand-rolled GraphQL parser must
honor.

**Structure Alignment:** Project structure (Step 6) materializes every
boundary the PRD/Addendum + Steps 4-5 commit to. Feature-to-location map covers
all 50+ features without gaps.

### Requirements Coverage Validation ✅

**Functional Requirements (Groups A-I):** Every FR is mapped to a specific
`lib/src/<subpath>/` location in the feature → location table. No orphan FRs.

**Non-Functional Requirements:**

| NFR | Architectural answer | Status |
|---|---|---|
| N-1 SSE parse throughput | `koel_http/test/perf/sse_parse_bench.dart` | ✅ |
| N-2 Reducer latency | `koel_core/test/perf/reducer_bench.dart` | ✅ |
| N-3 Memory footprint | `koel_flutter/test/perf/chat_session_memory_bench.dart` | ✅ |
| N-4 Cold start | `koel_core/test/perf/cold_start_bench.dart` | ✅ |
| N-5 Frame budget | `koel_flutter/test/perf/streaming_jank_bench.dart` | ✅ |
| N-6 Backpressure | `koel_http` bounded buffer + `KoelClient.backpressure` config | ✅ |
| N-7 Reconnect/retry | `RetryInterceptor` + `connection/reconnect_policy.dart` | ✅ |
| N-8 Cancellation <50ms | Convention §4 + `AbortController` on web (G-1 gap addressed below) | ⚠️ |
| N-9 Dart SDK floor | D1 raises to 3.9.0+ | ✅ (PRD update pending) |
| N-10 Flutter SDK floor | Derived from D1 (≈ 3.27+) | ⚠️ PRD update pending |
| N-11 Six platforms | D4 web transport + D6 Flutter web DevTools | ✅ |
| N-12 Coverage tiers | Enforcement summary + Melos script | ✅ |
| N-13 `dart analyze` clean | Enforcement summary | ✅ |
| N-14 Semver discipline | D7 (`dart_apitool`) | ✅ |
| N-15 Surface minimalism | Convention §2 + example smoke tests | ✅ |
| N-16 No comments stating code | Convention §6 | ✅ |

### Implementation Readiness Validation ✅

**Decision Completeness:** All D1-D8 + Bonus decisions documented with pinned
versions (D1: Dart 3.10.0+; D2: freezed 3.2.6-dev.1 (analyzer-12 stopgap, SCP-2026-05-29-B); D3: analysis_server_plugin 0.3.14 + analyzer 12.0.0 (stopgap → 0.3.15/13 via D2 upgrade trigger);
D4: package:web fetch+ReadableStream; D5: hand-rolled; D6: devtools_extensions
0.5.1; D7: dart_apitool 0.23.1; D8: bundled).

**Structure Completeness:** Repo root + 11 per-package layouts + feature-to-
location map + dependency DAG + data-flow diagram. All directories and key files
named.

**Pattern Completeness:** 6 convention categories cover naming, public/private
discipline, type/data conventions, stream/async conventions, error handling,
documentation/testing. Enforcement split between CI-gated and review-gated with
explicit anti-patterns list.

### Gap Analysis Results

**Critical Gaps:** None. Architecture is implementable as-is.

**Important Gaps (smooth implementation; address before first story):**
- **G-1. Web `fetch` cancellation mechanism.** D4 uses hand-rolled
  fetch+ReadableStream. Convention §4 (cancellation) does not spell out
  `AbortController` as the web transport's cancellation primitive. Add to
  convention §4 and to `koel_http/lib/src/transport/web_transport.dart` doc
  contract.
- **G-2. DevTools extension build pipeline.** `tool/extension_ui/` is the
  Flutter web source; built output ships in `extension/devtools/build/`. Build
  step not in `melos.yaml` script list. Add `melos run build:devtools` that
  runs `flutter build web` in `tool/extension_ui/` and copies to
  `extension/devtools/build/`. Wire into the `koel_devtools` publish flow.
- **G-3. `koel_lints` self-include exception.** The koel rule is enabled at the
  workspace-root `analysis_options.yaml` (asp `plugins:` + `diagnostics:`, per D3),
  but `koel_lints` must not lint itself. Use a minimal local
  `analysis_options.yaml` that extends `package:lints/recommended.yaml` only (and is
  excluded from the root plugin's diagnostics). Document in package README.

**Minor Gaps (defer to v0.x):**
- **G-4.** Fixture-capture pipeline internals (per OQ-Fixtures-Source spike).
- **G-5.** OQ-Docs-Framework still open; architecture defers.
- **G-6.** Coverage exclusion mechanism — use `--exclude` flags via
  `format_coverage` in Melos script; not a separate config file.

### Validation Issues Addressed

G-1 / G-2 / G-3 are addendums to existing sections, not redesigns:
- G-1: append a paragraph to Implementation Patterns §4
- G-2: append a Melos script line to Project Structure → Development Workflow
- G-3: append a one-line note under `koel_lints` package variation

These are documentation cleanups, not architectural changes. They will land as
edits to this document during the first PR rather than blocking implementation.

### Architecture Completeness Checklist

**Requirements Analysis**
- [x] Project context thoroughly analyzed
- [x] Scale and complexity assessed
- [x] Technical constraints identified
- [x] Cross-cutting concerns mapped

**Architectural Decisions**
- [x] Critical decisions documented with versions
- [x] Technology stack fully specified
- [x] Integration patterns defined
- [x] Performance considerations addressed (regression-relative bench harness)

**Implementation Patterns**
- [x] Naming conventions established
- [x] Structure patterns defined
- [x] Communication patterns specified
- [x] Process patterns documented (error handling, async, logging)

**Project Structure**
- [x] Complete directory structure defined
- [x] Component boundaries established
- [x] Integration points mapped
- [x] Requirements to structure mapping complete

### Architecture Readiness Assessment

**Overall Status:** READY FOR IMPLEMENTATION

All 16 checklist items pass. No critical gaps. The 3 PRD reconciliation items
(D1 → N-9, derived N-10, Bonus → Addendum B.3) are documentation updates, not
architectural rework — they reflect decisions made here that the PRD docs need
to absorb. The 3 important gaps (G-1, G-2, G-3) are addendum paragraphs to land
during the first implementation PR.

**Confidence Level:** High. The decisions are anchored to the PRD's existing
craft commitments; the deviations (vendor-inline json_patch, hand-roll multipart
GraphQL, raise Dart floor) all strengthen rather than weaken those commitments.

**Key Strengths:**
- Every architectural decision traces back to a PRD requirement or Addendum
  rationale; no orphan choices.
- `koel_lints` doubles as architectural artifact (forward-compat policy) and
  CI enforcement of conventions — single mechanism, multiple wins.
- Hand-rolled choices (json_patch vendor, GraphQL multipart, fetch+ReadableStream
  on web) consistently apply the Addendum D.7 reasoning ("small algorithm with
  churn risk → internal implementation"). The architecture is self-consistent
  on the "read framework source" principle.
- Convention enforcement is mechanically split (CI-gated vs. review-gated) with
  no overlap and no underlap.

**Areas for Future Enhancement (v1.x +):**
- Direct state-management adapters (`koel_bloc`, `koel_riverpod`, `koel_getx`)
  per OQ-State-Mgmt-Governance.
- `koel_a2ui` first-class generative UI package if AG-UI promotes A2UI to a
  first-class event family.
- Protobuf transport (`koel_proto`) per OQ-Protobuf-Codegen.
- Deep LangGraph interrupt-resume per OQ-LangGraph-Graduation.
- Isolate-backed long tool handlers; tool-call confirmation middleware.
- Conformance test suite contributed back upstream to AG-UI as the canonical
  cross-language conformance harness.

### Implementation Handoff

**AI Agent Guidelines:**
- Follow all architectural decisions exactly as documented in Sections
  "Core Architectural Decisions" + "Implementation Patterns" + "Project
  Structure".
- Treat `koel_lints` profile as the authoritative source for code-level rules;
  CI gate is the source of truth.
- Respect the package DAG; never introduce reverse dependencies.
- Refer to PRD + Addendum for protocol/feature specifications; refer to this
  document for *how* to implement them.

**First Implementation Priority (block order):**
1. Repo bootstrap: pub workspace + Melos 7.8.0 config + `.gitignore` + `.github/`
   workflows skeleton.
2. `koel_lints` skeleton: ship `lib/koel.yaml` profile (extending
   `package:lints/recommended.yaml`) + the principal rule on `analysis_server_plugin`
   (entry `lib/main.dart`), enabled via the workspace-root `analysis_options.yaml`
   from day one. Path dependency during dev; switch to package dependency at first
   publish.
3. `koel_core` foundation: events, errors, pipeline, reducer, vendor-inline
   `json_patch`.
4. `koel_test`: `MockAgent` from a single synthesized fixture; conformance
   runner stub. Captured fixtures land later (OQ-Fixtures-Source spike).
5. `koel_http`: `HttpAgent` + `SseParser` (native transport first; web
   transport second).
6. Backend bridges in any order: `koel_agno`, `koel_langgraph`, `koel_runtime`.
7. `koel_flutter` → `koel_widgets` → `koel_devtools` → `koel` meta-package.

**PRD reconciliation tasks (parallel to first implementation PR):**
1. Update PRD §10.3 N-9 to "Dart 3.9.0+".
2. Update PRD §10.3 N-10 to Flutter version that ships Dart 3.9+ (verify exact
   number).
3. Update PRD Addendum B.3 to "vendor-inline" with D.7-style rationale.
