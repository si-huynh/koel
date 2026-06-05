# Epic 9: Meta-Package, Sample App & v1.0.0 Release Gates

`dart pub add koel` produces the working quickstart path. Sample app at the repo root demonstrates end-to-end. All 6 CI workflows green. PRD reconciliation tasks committed. Trademark + `ag_ui` license gates resolved. v1.0.0 published lock-step on `koel_core` + `koel_http` + `koel_lints`; other packages versioned independently against `^1.0.0` ranges. Baseline perf artifacts published as release assets.

## Story 9.1: `koel` meta-package re-exports + hybrid versioning ranges

As a Flutter developer,
I want `dart pub add koel` producing a working SDK installation by re-exporting `koel_core` + `koel_http` + `koel_flutter` with hybrid-versioning ranged dependencies (`^X.Y.0`),
So that the quickstart path is one package add per FR-H3 + FR-H2.

**Acceptance Criteria:**

**Given** `packages/koel/lib/koel.dart`,
**When** I inspect the barrel,
**Then** it contains exactly three `export 'package:<name>/<name>.dart';` lines — `koel_core`, `koel_http`, `koel_flutter` — per Addendum + architecture §2,
**And** the file is ≤ 6 LOC total.

**Given** `packages/koel/pubspec.yaml`,
**When** I inspect dependencies,
**Then** `koel_core: ^1.0.0`, `koel_http: ^1.0.0`, `koel_flutter: ^1.0.0` are declared with proper version ranges per FR-H2,
**And** `koel_lints` is NOT a runtime dependency (consumers integrate it via `analysis_options.yaml` separately) per FR-H3.

**Given** the foundation lock-step constraint,
**When** I check `koel_core` + `koel_http` + `koel_lints` pubspec versions before publish,
**Then** all three carry identical `1.0.0` versions per FR-H2 + PRD §12 R-2.

**Given** the backend bridges + Flutter + widgets + devtools + test packages,
**When** I check their pubspec dependency on `koel_core`,
**Then** each declares a `^1.0.0` range (NOT a tight `1.0.0` pin) per FR-H2 + PRD §12 R-3,
**And** an internal CI step asserts the convention before each publish.

## Story 9.2: Repo-root sample app via `koel` meta-package

As a Flutter developer,
I want a repo-root `example/` Flutter app consuming `koel` meta-package and demonstrating the quickstart end-to-end (generic chat scenario, zero business domain) across all six platforms,
So that pub.dev visitors see a real working entrypoint per FR-H3 + AR-22 + PRD §13 D-5.

**Acceptance Criteria:**

**Given** repo-root `example/`,
**When** I inspect the structure,
**Then** it is a Flutter app with `pubspec.yaml` depending on `koel` meta-package (path dependency during dev, package dependency post-publish),
**And** `lib/main.dart` shows a `MaterialApp` with a single chat screen using `KoelChatController` + `KoelClientScope` + `MessageBubble` + `ChatInput`,
**And** the app uses `MockAgent.fromFixture('text_only_run')` from `koel_test` (dev_dependency) for offline demo,
**And** the README.md describes how to swap `MockAgent` for `AgnoAgent`/`LangGraphAgent`/`CopilotRuntimeAgent`.

**Given** `.github/workflows/ci.yml`,
**When** I extend the matrix,
**Then** every platform job runs `flutter build` against the example app and asserts the build succeeds across iOS, Android, web, macOS, Windows, Linux per NFR-11 + AR-22.

**Given** the sample app demoed by a human,
**When** the demoer follows the README,
**Then** the chat surface renders + the mock conversation streams visibly,
**And** zero business-domain content appears (per AR-22 + PRD §13 D-5).

## Story 9.3: `dart_apitool` wiring + per-package baseline + CI gate

As a release manager,
I want `dart_apitool: ^0.23.1` wired in `api-diff.yml` extracting an API surface per package and diffing against the published v1.x.y baseline,
So that NFR-14 (zero breaking changes after 1.0.0) is mechanically enforced per AR-12 + D7.

**Acceptance Criteria:**

**Given** `tool/verify_api_surface.dart`,
**When** I inspect it,
**Then** it wraps `dart_apitool` per-package and writes per-package baselines into `_bmad-output/api-baselines/<package>-<version>.json`.

**Given** `.github/workflows/api-diff.yml` (now complete from skeleton in Story 1.5),
**When** the workflow runs on every PR,
**Then** the action runs `tool/verify_api_surface.dart --extract` per package + diffs against the published baseline,
**And** any breaking signature/removal change blocks merge with a clear diff in the PR comment,
**And** additions (new public symbols) pass through with a warning logged.

**Given** v1.0.0 baseline capture,
**When** the release is published,
**Then** the baseline JSON files are committed to `_bmad-output/api-baselines/` for every package,
**And** subsequent v1.x publishes update the baseline as a separate PR step.

## Story 9.4: Perf baselines published as release artifacts + `BENCHMARKS.md`

As a release manager,
I want `BENCHMARKS.md` finalized with the reference device profile + v1.0.0 baseline numbers for N-1..N-5 published as release artifacts,
So that NFR-1..NFR-5 regression-relative SLOs become CI-enforceable per OQ-Perf-Baseline + AR-15 + AR-21.

**Acceptance Criteria:**

**Given** repo-root `BENCHMARKS.md`,
**When** I inspect it,
**Then** it documents the reference device profile (CPU model, RAM, Dart VM flags, Flutter version),
**And** lists the five benchmarks (sse_parse_bench, reducer_bench, chat_session_memory_bench, cold_start_bench, streaming_jank_bench) with measurement methodology + acceptable ranges.

**Given** `.github/workflows/perf-bench.yml` (now complete from skeleton in Story 1.5),
**When** the workflow runs on every PR,
**Then** all five baselines execute on the CI reference device,
**And** any > 10% regression vs the v1.0.0 baseline blocks merge per NFR-1..NFR-5.

**Given** the v1.0.0 publish,
**When** the GitHub release is created,
**Then** the five baseline JSON files are attached as release artifacts (immutable reference),
**And** `BENCHMARKS.md` links them.

**Given** OQ-Perf-Baseline pending in PRD §15,
**When** v1.0.0 publishes,
**Then** the OQ is marked RESOLVED in the PRD via the reconciliation in Story 9.7.

## Story 9.5: `conformance.yml` + `publish-dry-run.yml` complete green

> **Gate (SCP-2026-06-05):** `CopilotRuntimeAgent` here is the **v2 native-AG-UI/SSE**
> agent (full matrix) from Epic-5 stories 5.10–5.11 — NOT the removed legacy GraphQL
> bridge. v1.0.0 must not publish until 5.10–5.11 land, so CopilotKit ships at full
> fidelity (no lossy 7/28 adapter). 9.2's sample-app README likewise references the
> v2 `CopilotRuntimeAgent`.

As a release manager,
I want `conformance.yml` running `ConformanceRunner` against all three backends using captured fixtures + `publish-dry-run.yml` running `pub publish --dry-run` per package,
So that conformance + publish-readiness are continuously enforced per FR-I1 + PRD §12 R-5.

**Acceptance Criteria:**

**Given** `.github/workflows/conformance.yml`,
**When** I inspect the workflow,
**Then** it runs the `ConformanceRunner` against `AgnoAgent`, `LangGraphAgent`, `CopilotRuntimeAgent` using the captured fixtures from Epic 5,
**And** the workflow fails when any adapter has any conformance failure.

**Given** `.github/workflows/publish-dry-run.yml`,
**When** the workflow runs on every PR + on every push to main,
**Then** it executes `dart pub publish --dry-run` per package across all eleven packages,
**And** any error (missing required pubspec fields, deprecated lints, file inclusion mistakes) blocks merge.

**Given** all six workflows (`ci.yml`, `conformance.yml`, `perf-bench.yml`, `api-diff.yml`, `codegen-drift.yml`, `publish-dry-run.yml`),
**When** I check the latest commit on main,
**Then** every workflow is green,
**And** the green-state is required for v1.0.0 publish per PRD §12 R-5.

## Story 9.6: Docs site scaffold + per-package READMEs final

As a release manager,
I want `docs/` scaffolded with framework decision (resolving OQ-Docs-Framework) + Getting Started + Concepts (one page per major idea) + Recipes + Migration Guide + Adapter Cookbook structure, plus every package README at PRD §13 D-1 quality bar,
So that documentation contract is met per FR-H6 + AR-21 + PRD §13.

**Acceptance Criteria:**

**Given** OQ-Docs-Framework resolved (Docusaurus vs Nextra vs alternative — decision committed),
**When** I inspect `docs/`,
**Then** the directory structure matches PRD §13 D-3: `getting-started.md`, `concepts/<topic>.md` (one per major idea — events, interceptors, reducer, sessions, devtools), `recipes/<scenario>.md` (10+ scenarios), `api-reference/` (`dart doc` output stub or auto-link), `migration-guide.md`, `adapter-cookbook.md`,
**And** the framework decision rationale is documented in `docs/ADR-001-docs-framework.md`.

**Given** every package's `README.md`,
**When** I inspect each,
**Then** all eleven packages meet PRD §13 D-1: one-paragraph "what is this", 10-line quickstart, link to docs site, link to CHANGELOG, MIT license note, at most 3 badges (pub.dev version + license + CI status),
**And** all README content is reviewed for the architecture's anti-pattern rules (no `print`, no marketing paragraphs in README, doc the contract).

**Given** every public symbol across all packages,
**When** I run `dart doc` at the repo root via `melos run docs`,
**Then** zero "missing doc comment" warnings appear,
**And** the per-package `dart doc` outputs build cleanly per NFR-16.

## Story 9.7: PRD/Addendum reconciliation (AR-24, AR-25, AR-26)

As a release manager,
I want the three PRD reconciliation tasks committed alongside v1.0.0,
So that the PRD body matches what shipped — Dart 3.9.0+ floor, Flutter floor, vendor-inline RFC 6902 per AR-24 + AR-25 + AR-26.

**Acceptance Criteria:**

**Given** `_bmad-output/planning-artifacts/prds/prd-koel-2026-05-27/prd.md` §10.3,
**When** I check N-9,
**Then** the wording is updated from "Dart 3.0+" to "Dart 3.9.0+" with the rationale "Melos 7.x recommended; pub-workspace minimum 3.6.0+; architecture D1" appended per AR-24.

**Given** the same PRD §10.3 N-10,
**When** I check the Flutter floor,
**Then** the wording is updated from "Flutter 3.10+" to the exact Flutter version shipping Dart 3.9+ (verified — approximately Flutter 3.27+ per AR-25),
**And** the rationale references D1.

**Given** `_bmad-output/planning-artifacts/prds/prd-koel-2026-05-27/addendum.md` §B.3,
**When** I check the JSON Patch entry,
**Then** it reads "Vendor inline under `koel_core/lib/src/json_patch/`" with the D.7-style rationale (4-year-stale upstream incompatible with zero-churn 1.x commitment) per AR-26,
**And** matches the implementation in Story 2.7.

**Given** the PRD's Open Questions section,
**When** I check OQ-Perf-Baseline + OQ-Conformance-Equivalence + OQ-Koel-Trademark + OQ-AGUI-License,
**Then** each is marked RESOLVED with a link to the resolving artifact (Story 9.4, Story 2.6 + Story 3.5 anchor, Story 9.8, Story 9.8).

## Story 9.8: Trademark check + `ag_ui` license verification

As a release manager,
I want the "koel" trademark verified beyond pub.dev (USPTO, EU IPO, India IP) + the community `ag_ui` 0.1.0 license-compatibility verified (MIT confirmation) ahead of v1.0.0 publish,
So that the brand + credit-line gates are met per FR-I3 + OQ-Koel-Trademark + OQ-AGUI-License.

**Acceptance Criteria:**

**Given** trademark search records,
**When** I check USPTO + EU IPO + India IP,
**Then** no conflicting "koel" trademark in software / developer-tools class exists,
**And** the search records are committed to `_bmad-output/legal/trademark-search-koel.md` as audit trail per FR-I3 + OQ-Koel-Trademark.

**Given** community `ag_ui` 0.1.0's LICENSE file,
**When** I verify it,
**Then** it is confirmed MIT-licensed (or compatible),
**And** the verification record is committed to `_bmad-output/legal/ag_ui-license-verification.md` per OQ-AGUI-License.

**Given** `koel_core/README.md`,
**When** I inspect the credit-line,
**Then** the one-line credit to `ag_ui` 0.1.0 is finalized (no longer a stub) per FR-H4,
**And** the "pending verification" note from Story 1.6 is removed.

## Story 9.9: v1.0.0 lock-step publish + ranged dependent publishes + `CONFORMANCE.md` finalize

As a release manager,
I want v1.0.0 published lock-step on `koel_core` + `koel_http` + `koel_lints` followed by independent `^1.0.0`-ranged publishes for the seven dependent packages, with `CONFORMANCE.md` recording the pinned AG-UI commit SHA + mirrored CHANGELOGs on the foundations,
So that v1.0.0 ships per PRD §12 + FR-H2.

**Acceptance Criteria:**

**Given** `koel_core/CONFORMANCE.md`,
**When** I check the spec pin,
**Then** the AG-UI `release/2026-05-26` commit SHA is recorded as the literal hash (not placeholder) per SC-1 + Story 3.5.

**Given** the publish order,
**When** I execute `melos publish` orchestrated per PRD §12,
**Then** `koel_lints` publishes first (so subsequent packages can depend on it as a package, not path),
**And** `koel_core` + `koel_http` publish second + third in lock-step with identical `1.0.0` versions per PRD §12 R-2,
**And** the seven dependent packages publish next: `koel_test`, `koel_agno`, `koel_langgraph`, `koel_runtime`, `koel_flutter`, `koel_widgets`, `koel_devtools`, then `koel` meta-package last,
**And** every dependent declares `koel_core: ^1.0.0` (NOT a tight pin) per PRD §12 R-3.

**Given** the CHANGELOGs on `koel_core` + `koel_http` + `koel_lints`,
**When** I diff them,
**Then** the v1.0.0 entries are mirrored (same change summary across foundations) per PRD §12 R-2.

**Given** every Success Criteria gate in PRD §5.1 (SC-1, SC-2, SC-3, SC-4, SC-5),
**When** I check each before publish,
**Then** every gate is green (conformance round-trip, coverage tiers, analyze clean, dart_apitool baseline established, no vestigial code per CI script).

**Given** the v1.0.0 GitHub release,
**When** I check the release artifacts,
**Then** all five baseline JSON files from Story 9.4 are attached,
**And** the release notes link to `CONFORMANCE.md`, `BENCHMARKS.md`, the docs site, and the per-package CHANGELOGs.
