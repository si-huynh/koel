---
baseline_commit: 7c22a0c1233cdf92b59bb492ba890b6aad0461d1
---

# Story 9.6: Docs site scaffold + per-package READMEs final

Status: review

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a release manager,
I want `docs/` scaffolded with the docs-framework decision committed (resolving OQ-Docs-Framework via `ADR-001`) + the full content tree (Getting Started · Concepts · Recipes · API Reference · Migration Guide · Adapter Cookbook), plus every release-package `README.md` brought to the PRD §13 D-1 quality bar, plus a `melos run docs` gate proving `dart doc` builds cleanly with zero missing-doc-comment warnings,
so that the documentation contract is met per FR-H6 + AR-21 + PRD §13 + NFR-16 ahead of the v1.0.0 publish.

## Context — sixth story of Epic 9 (the documentation contract)

This is the **documentation-finalization story** of Epic 9. The six release-gate **workflows** are now complete and green (9.3 `api-diff`, 9.4 `perf-bench`, 9.5 `conformance` + `publish-dry-run`). 9.6 lands the **human-facing documentation contract** — the docs-site scaffold and the per-package READMEs — and adds the `dart doc` build gate (NFR-16). It is the last large content story before the closing trio: 9.7 (PRD reconciliation), 9.8 (trademark + `ag_ui` license), 9.9 (the actual lock-step publish).

**Scope frame:** this is **docs content + one docs-framework decision (ADR) + READMEs + a `dart doc` build script (+ CI lane) + one PRD OQ line flip**. It adds **no new public symbol**, **no `lib/src/**` change**, and **no new pub-workspace dependency**. The docs-site toolchain (a JS static-site generator) lives entirely **outside** the Dart pub-workspace under `docs/` with its own `package.json`/`node_modules` (git-ignored) — it never enters `pubspec.lock` and **never touches the AI-5.9 pins** (`analyzer 12.1.0` / `freezed 3.2.6-dev.1` / `analysis_server_plugin: 0.3.14` — SCP-2026-05-29-B / architecture D3). `verify:versioning` (9.1), `api-diff` (9.3), `conformance`/`publish-dry` (9.5), and `perf` (9.4) all stay green by construction.

**Release set = the ten 1.0.0 packages** (`koel`, `koel_core`, `koel_http`, `koel_lints`, `koel_test`, `koel_agno`, `koel_langgraph`, `koel_runtime`, `koel_flutter`, `koel_widgets`). **`koel_devtools` is OUT** — deferred post-1.0 → Epic 10 (SCP-2026-06-06-B); it is `version: 0.0.1`, `publish_to: none`, and its `public_member_api_docs` doc gate is **deliberately not enabled** (its `analysis_options.yaml` says the gate "lands at koel_devtools' finalize story (Epic 8)"). Do **not** finalize its README or run the doc gate against it.

## Acceptance Criteria

**AC1 — OQ-Docs-Framework resolved (decision committed via `ADR-001`) + `docs/` structure matches PRD §13 D-3.**
**Given** OQ-Docs-Framework, **when** this story runs, **then** the docs-framework decision (Docusaurus / Nextra / alternative) is **committed** with rationale in `docs/ADR-001-docs-framework.md`, the chosen framework is **initialized under `docs/` and builds locally** (its toolchain isolated from the pub-workspace), and the OQ-Docs-Framework line in PRD §15 is flipped to **RESOLVED → ADR-001**, **and** the `docs/` directory contains the full D-3 content tree authored as real (not empty-stub) content: `getting-started.md`, `concepts/<topic>.md` (one page each for **events, interceptors, reducer, sessions** — the `devtools` concept page is explicitly deferred to Epic 10 post-1.0), `recipes/<scenario>.md` (**≥ 10** working scenarios), `api-reference/` (a `dart doc`-autolink stub — the per-package pub.dev API tab is the source of truth, not a vendored copy), `migration-guide.md`, and `adapter-cookbook.md`, **and** the existing house pattern doc `docs/patterns/stream-cancellation.md` is folded/linked into the tree (not orphaned).

**AC2 — every release-package README meets PRD §13 D-1 + the architecture anti-pattern rules.**
**Given** the **ten** release-package READMEs (NOT `koel_devtools`), **when** I inspect each, **then** each contains: a one-paragraph "what is this", a ~10-line quickstart code block, a link to the docs site, a link to that package's `CHANGELOG.md`, an MIT license note, and **at most 3 badges** (pub.dev version + license + CI status) — and no more; **and** each is clean against the architecture anti-pattern rules (no `print`, **no "Why X" marketing paragraph** — the docs site carries that, doc the contract), **and** the now-resolved docs-site link replaces the stale "framework pending — `OQ-Docs-Framework`" placeholder in every README and in the repo-root `README.md` (lines 48–49), **and** the `OQ-AGUI-License` credit "pending verification" tracking note in `koel_core/README.md` is **preserved untouched** (its removal is Story 9.8, not 9.6).

**AC3 — `melos run docs` builds `dart doc` cleanly across the release packages with zero missing-doc-comment warnings (NFR-16).**
**Given** a new `melos run docs` script, **when** I run it, **then** it runs `dart doc` per release package (the ten; `koel_devtools` excluded), **zero** "missing doc comment" warnings appear, and every per-package `dart doc` **builds cleanly** (no broken `[reference]` links, no malformed `///` example blocks) per NFR-16 — a stronger check than the already-green `public_member_api_docs` *analyze* gate, **and** the gate is wired as a `ci.yml` doc-build lane so NFR-16 is CI-enforced (the 7.4 `example-smoke` lane precedent), **and** a negative bite-check proves it fails on a real doc defect (e.g. add a public symbol with no `///`, or a `[BrokenRef]` → build warning → lane fails; revert), recorded in the Dev Agent Record.

**AC4 — the gate discipline holds: 0 lock-drift, AI-5.9 pins held, all sibling gates still green.**
**Given** this story touches no `lib/src/**`, adds no public symbol, and adds no pub-workspace dependency, **when** I run the gates, **then** `melos run analyze` is clean, `melos run format:check` is 0-changed, `melos run test` is unchanged-green, `melos run verify:versioning` + `melos run api-diff` + `melos run conformance` + `melos run publish-dry` all stay green, and **`git diff pubspec.lock` shows 0 drift** with the **AI-5.9 pins unmoved** (the JS docs toolchain is not a pub-workspace member; `docs/node_modules` is git-ignored).

## Tasks / Subtasks

> Run all Flutter/Dart work under the `/agent-flutter-engineer` persona (CLAUDE.md mandate). This story is docs content + one ADR + READMEs + a `dart doc` build script + a CI lane + one PRD line; the persona governs the `melos run docs` script, the `dart doc` build hygiene (broken-ref/example backfill), and the doc-contract reasoning.

- [x] **Task 0 — Verify the as-is state before changing anything** (AC1, AC2, AC3) — *do this first; the docs/ tree is near-empty, the READMEs exist but reference the pending OQ, and `dart doc` must be proven to build before claiming a clean gate.*
  - [x] `docs/` today holds only `docs/patterns/stream-cancellation.md` (a high-quality house-pattern doc) — confirm, and plan to fold/link it (do not orphan it). No framework is initialized yet.
  - [x] Read all eleven package READMEs. Confirm the ten release READMEs each already have most D-1 elements but: (a) link to a *pending* docs site ("framework selection pending — `OQ-Docs-Framework`"), (b) carry **no badges**. Confirm `koel_devtools/README.md` is the one to **exclude**.
  - [x] Confirm the doc gate status: `public_member_api_docs: true` is enabled on the release packages' `analysis_options.yaml` (2.15 / 6.8 / 7.4 backfilled their surfaces) and is green under `melos run analyze`; `koel_devtools` deliberately does **not** enable it. Then run `dart doc` for a couple of packages to reproduce the *build* baseline — `public_member_api_docs` (analyze) catches missing comments, but `dart doc` additionally surfaces **broken `[refs]`** + **malformed example blocks** that analyze passes (the 7.4 precedent: 2 `[MessageBubble]` comment_references had to be demoted to code-spans). Record any broken refs to backfill in Task 4.
  - [x] Confirm no `docs` melos script exists yet (root `pubspec.yaml` `melos.scripts:` ends at `publish-dry`).

- [x] **Task 1 — Resolve OQ-Docs-Framework + commit `ADR-001` + flip the PRD OQ line** (AC1, D1)
  - [x] Author `docs/ADR-001-docs-framework.md` committing the framework choice with rationale, the rejected alternatives, and the isolation note (the toolchain lives under `docs/` outside the pub-workspace → zero impact on `pubspec.lock` / AI-5.9 pins). **FYI default → Docusaurus 3.x** (see **D1** for the full rationale — versioned docs for the Migration Guide, MDX for the Recipes/Cookbook, Algolia DocSearch, isolated Node toolchain). If you deviate, justify in the ADR.
  - [x] Flip the **OQ-Docs-Framework** line in `prds/prd-koel-2026-05-27/prd.md` §15 to **RESOLVED** with a link to `docs/ADR-001-docs-framework.md`. This single OQ is **9.6's to resolve** (it is the resolver); the *other* OQ flips (Perf-Baseline, Conformance-Equivalence, Koel-Trademark, AGUI-License) + the AR-24/25/26 body reconciliation are **Story 9.7's** — do not touch them here (D6 boundary).

- [x] **Task 2 — Scaffold `docs/` to the D-3 structure with real content** (AC1, D1, D2)
  - [x] Initialize the chosen framework under `docs/` so it **builds locally** (`docs/package.json`, config; add `docs/node_modules`, build output to `.gitignore`). Keep it self-contained — no root-level Node config, nothing that touches the Dart workspace.
  - [x] Create the content tree per D-3: `getting-started.md`; `concepts/{events,interceptors,reducer,sessions}.md` (one major idea each — **no `devtools` page**, that lands with Epic 10); `recipes/` with **≥ 10** working scenarios (mine the package examples + the `koel` quickstart + the captured-fixture flows + auth/retry/cancellation/generative-UI/session-persistence patterns for real, runnable scenarios); `api-reference/` (a stub that autolinks to the per-package pub.dev `dart doc` API tabs — do not vendor a copy); `migration-guide.md` (the 1.x forward-compat policy / minor-version upgrade contract per PRD §11); `adapter-cookbook.md` (how to write your own backend adapter against the conformance contract — anchor on the agno/langgraph/runtime adapters as worked examples).
  - [x] Fold `docs/patterns/stream-cancellation.md` into the tree — link it from the relevant concept (cancellation / transport) or recipe so it is reachable, not orphaned.
  - [x] Content quality bar: real prose, runnable code, contract-first — **not** lorem stubs. This is the koel craft bar; the docs site is the public face of the SDK.

- [x] **Task 3 — Finalize the ten release READMEs to PRD §13 D-1** (AC2, D3, D4)
  - [x] For each of the **ten** release packages (NOT `koel_devtools`): verify/author the five D-1 elements (one-paragraph what-is, ~10-line quickstart, docs-site link, CHANGELOG link, MIT note); add **at most 3 badges** — pub.dev version + license + CI status — and no more.
  - [x] Replace the stale "framework pending — `OQ-Docs-Framework`" docs placeholder in every release README **and** in the repo-root `README.md` (lines 48–49) with the now-resolved docs-site link.
  - [x] **Preserve** the `OQ-AGUI-License` credit "pending verification" tracking note in `koel_core/README.md` verbatim — finalizing/removing it is **Story 9.8** (D6 boundary). Do not touch the credit line itself.
  - [x] Anti-pattern sweep on every README: no `print`, **no marketing "Why X" paragraph**, ≤ 3 badges, contract-first phrasing (architecture §6 README rules, lines 655–662).
  - [x] **pub.dev version badge note (D4):** the pub.dev badge resolves only *after* publish (Story 9.9). Add it now — the standard shields.io OSS pattern (renders "not found" until 9.9 goes live, then auto-populates). Do **not** block on it or fabricate a version.

- [x] **Task 4 — Add `melos run docs` + prove `dart doc` builds clean (NFR-16) + wire the CI lane** (AC3, D5, D8)
  - [x] Add a `docs` script to root `pubspec.yaml` `melos.scripts:` in the house shape (mirror `analyze`/`conformance`: a one-line `description:` + a `run:` that builds `dart doc` per release package). Prefer a thin `tool/` orchestrator if the per-package loop needs the same care as `tool/conformance.sh` (the single-orchestrator precedent) — exclude `koel_devtools` (doc gate off). Zero new pub-workspace dependency.
  - [x] Run `melos run docs` → fix every broken `[ref]` / malformed example block surfaced by the *build* (the 7.4 fix: demote unresolved `[Type]` comment_references to code-spans, or add the missing import to the dartdoc-resolvable set). **No behavior change** — doc comments only. Confirm zero missing-doc-comment warnings + clean build across the ten.
  - [x] Wire a doc-build lane into `ci.yml` (the 7.4 `example-smoke` lane precedent) so NFR-16 actually bites. Keep the six dedicated gate workflows (`conformance`/`publish-dry-run`/`api-diff`/`perf-bench`/`codegen-drift`) untouched.
  - [x] **Negative bite-check (prove the gate fails on a real defect):** temporarily add an undocumented public symbol or a `[BrokenRef]` → confirm `melos run docs` (and the CI lane) **fails**; revert. Record both clean-pass + injected-fail in the Dev Agent Record (the 9.3/9.4/9.5 "prove the gate bites" precedent).

- [x] **Task 5 — Gate verification** (AC4, all ACs)
  - [x] `git diff pubspec.lock` (root) → **0 drift**. No pub-workspace dependency added (the docs toolchain is JS, outside the workspace; `docs/node_modules` git-ignored). **AI-5.9 pins MUST NOT move** (`analyzer 12.1.0` / `freezed 3.2.6-dev.1` / `analysis_server_plugin: 0.3.14`). The only `pubspec.yaml` edit is the `docs` melos-script line.
  - [x] `melos run analyze` clean; `melos run format:check` 0-changed (markdown/yaml/Node are outside `dart format`; if any `///` comment was edited for a broken ref, re-run `dart format` on that Dart file); `melos run test` SUCCESS-unchanged (this story adds no unit test — the deliverable is verified by the `dart doc` build + the CI doc lane, not a new suite).
  - [x] `melos run verify:versioning` (9.1) + `melos run api-diff` (9.3) + `melos run conformance` + `melos run publish-dry` (9.5) all still **green** — 9.6 touches no `lib/src/**`, no public symbol, no version/range, no pubspec metadata that the publish-dry gate validates beyond what 9.5 already cleared. (README text is not validated by `pub publish --dry-run`; confirm the dry-run stays green.)

## Dev Notes

### Locked decisions

- **D1 — OQ-Docs-Framework: decide it here, commit `ADR-001`, FYI default = Docusaurus 3.x.** This is a tooling/infra choice, not an AG-UI parity question, so it is decided in-story (no confirm-me bounce to Si — recorded as FYI). **Recommended: Docusaurus 3.x**, because: (1) **first-class versioned docs** → directly serves the "Migration Guide across minor versions" (D-3) + the 1.x forward-compat policy (PRD §11); (2) **MDX** → tabbed/interactive code for the ≥10 Recipes + the Adapter Cookbook; (3) **Algolia DocSearch** (free for OSS) → search at the premium bar; (4) de-facto standard for OSS SDK docs → contributors already know it; (5) the Node toolchain lives entirely under `docs/` with its own `package.json` → **zero impact on the Dart pub-workspace / `pubspec.lock` / AI-5.9 pins** (the only objection to a JS toolchain is neutralized by isolation). Rejected alternatives to record in the ADR: **Nextra** (lighter/cleaner default theme but weaker versioning — note it as the runner-up if Si prefers minimalism), **Dart-native (Jaspr / raw `dart doc` + static host)** (DNA-aligned but immature for a versioned multi-section guide site — no built-in search/versioning/sidebar). *Parity-irrelevant infra call, decided + recorded as FYI → Si; the ADR is the deliverable, dev-story commits it.*

- **D2 — `docs/` structure is the PRD §13 D-3 contract, minus the `devtools` concept page.** The four concept pages are **events, interceptors, reducer, sessions** — the fifth (`devtools`) is explicitly deferred to Epic 10 post-1.0 (the epic AC strikes every devtools reference to the ten-package set). The `api-reference/` is a **stub that autolinks** to the per-package pub.dev `dart doc` API tabs — do **not** vendor a copy of generated API HTML into the repo (it would rot and bloat). The existing `docs/patterns/stream-cancellation.md` is real, good content → fold/link it, don't orphan it. Content must be real (runnable code, contract prose), not lorem stubs — the docs site is the public face (koel craft bar).

- **D3 — READMEs: ten release packages to §13 D-1; `koel_devtools` EXCLUDED.** D-1 = one-paragraph what-is + ~10-line quickstart + docs-site link + CHANGELOG link + MIT note + **≤ 3 badges** (pub.dev version + license + CI status). Architecture §6 (lines 655–662) expands it: **no "Why X" marketing paragraph** (the docs site carries that), no badges beyond the three, doc the contract. `koel_devtools` is out of the release set (Epic 10; `version: 0.0.1`, `publish_to: none`, doc gate off) → do not finalize its README. The READMEs currently point at a *pending* docs site and carry no badges — both are what this story fixes.

- **D4 — pub.dev version badge resolves post-publish (9.9); add it now anyway.** The shields.io `pub` badge renders "not found" until the package is first published (Story 9.9), then auto-populates — the standard OSS pattern. Add the three badges now to meet D-1; do **not** fabricate a version number or block on the badge. The license + CI-status badges are live immediately.

- **D5 — `melos run docs` is a `dart doc` *build* gate (NFR-16), stronger than the existing analyze doc gate.** `public_member_api_docs: true` (an *analyze* lint, green since 2.15/6.8/7.4) catches **missing** doc comments. `dart doc` (the *build*) additionally fails on **broken `[reference]` links** + **malformed `///` example blocks** that analyze passes (7.4 hit exactly this: 2 `[MessageBubble]` comment_references demoted to code-spans). NFR-16's "per-package `dart doc` builds cleanly" requires the build, not just the lint → this story adds the `melos run docs` build + a `ci.yml` doc-build lane (the 7.4 `example-smoke` precedent) so it bites. Exclude `koel_devtools` (doc gate deliberately off).

- **D6 — Scope boundaries (avoid double-ownership churn with 9.7/9.8/9.9).** 9.6 owns: the docs scaffold + ADR-001 + the **single** OQ-Docs-Framework PRD flip (it is the resolver) + the ten READMEs + the `dart doc` gate. **OUT of 9.6:** the *other* OQ flips (Perf-Baseline, Conformance-Equivalence, Koel-Trademark, AGUI-License) + the AR-24/25/26 PRD-body reconciliation → **Story 9.7**; the `ag_ui` credit-line finalize + the `OQ-AGUI-License` "pending verification" note removal → **Story 9.8** (preserve the note here); the actual publish + CHANGELOG mirroring → **Story 9.9**. Keep the PRD edit to exactly the one OQ-Docs-Framework line.

- **D7 — Zero pub-workspace impact: the docs toolchain is JS, outside the Dart workspace.** The Docusaurus/Nextra `package.json` + `node_modules` live under `docs/`, git-ignore `node_modules`/build output, and never enter `pubspec.lock` → **0 lock-drift, AI-5.9 pins unmoved** (the central regression guard of every Epic-9 story). The only Dart-side edits are the `docs` melos-script line (root `pubspec.yaml`), the `ci.yml` doc lane, the ten READMEs (markdown), and any `///` broken-ref backfill (doc comments only, no behavior). No `lib/src/**` change, no public symbol → `api-diff` stays green by construction.

- **D8 — `dart doc` must build clean: backfill broken refs/examples without changing behavior.** Run `melos run docs` and fix what the *build* surfaces (the 7.4 fix pattern: demote unresolved `[Type]` to a code-span, or add the missing import to the dartdoc-resolvable set per the `koel_core/analysis_options.yaml` comment at lines 23–24). These are doc-comment-only edits — re-run `dart format` + `analyze` after touching any `///`. Prove the gate bites (negative check) so NFR-16 enforcement is not a silent no-op (the codegen-drift retro-D1 / 9.3 / 9.4 / 9.5 lesson).

### Current state of files being modified/created (read before editing)

- **`docs/`** — near-empty: only `docs/patterns/stream-cancellation.md` (a real house-pattern doc — fold/link, don't orphan). No framework initialized. This story scaffolds the full D-3 tree + `ADR-001-docs-framework.md`. [Source: docs/]
- **`docs/patterns/stream-cancellation.md`** — exists; cancel-correct stream teardown house pattern (Epic-4 retro AI#3), links to `koel_http/lib/src/connection/cancellation.dart`. Reachable from a concept/recipe, do not orphan. [Source: docs/patterns/stream-cancellation.md]
- **The ten release READMEs** — `packages/{koel,koel_core,koel_http,koel_lints,koel_test,koel_agno,koel_langgraph,koel_runtime,koel_flutter,koel_widgets}/README.md`. Each has most D-1 elements but links to a *pending* docs site ("framework selection pending — `OQ-Docs-Framework`") and carries **no badges**. `koel_core/README.md` carries the `OQ-AGUI-License` "pending verification" credit note → **preserve** (9.8 owns it). [Source: each README.md; architecture.md:655–662]
- **`packages/koel_devtools/README.md`** — **EXCLUDED** (Epic 10; `version: 0.0.1`, `publish_to: none`, doc gate off). Do not finalize. [Source: packages/koel_devtools/{README.md,pubspec.yaml,analysis_options.yaml:11–14}]
- **Repo-root `README.md`** — lines 48–49 carry the same "framework selection pending — `OQ-Docs-Framework`" placeholder → replace with the resolved docs link. [Source: README.md:48–49]
- **Root `pubspec.yaml` `melos.scripts:`** — holds `analyze`/`test`/`test:coverage`/`build`/`format`/`format:check`/`analyze:apply`/`conformance`/`verify:versioning`/`api-diff`/`perf`/`publish-dry`/`capture-fixtures`. **No `docs` script** → add it (architecture §6 line 651 + the dev-workflow list at 1118–1133). [Source: pubspec.yaml melos.scripts]
- **The release packages' `analysis_options.yaml`** — `public_member_api_docs: true` enabled (green via analyze); a comment (e.g. `koel_core` :23–24) notes keeping `[Type]` references dartdoc-resolvable. `koel_devtools` deliberately does NOT enable it (:11–14). [Source: packages/*/analysis_options.yaml]
- **PRD §15 `prds/prd-koel-2026-05-27/prd.md`** — OQ-Docs-Framework (line 363) is the **only** OQ 9.6 flips (the others are 9.7). [Source: prds/prd-koel-2026-05-27/prd.md:363]
- **`.github/workflows/ci.yml`** — the main matrix; 7.4 added an `example-smoke` lane here (the in-scope-CI-lane precedent for a doc-build lane). The six dedicated gate workflows stay untouched. [Source: .github/workflows/ci.yml]

### What must keep working (regression guards)

- **AI-5.9 pins held** — `analyzer 12.1.0` / `freezed 3.2.6-dev.1` / `analysis_server_plugin: 0.3.14`; root `pubspec.lock` **0-drift**. The docs toolchain is JS, outside the pub-workspace → it cannot move a Dart pin. This is the load-bearing guard.
- **No new public symbol, no `lib/src/**` behavior change** — `api-diff` (9.3) stays green by construction. Any `///` edit (broken-ref backfill) is doc-comment-only; re-run `dart format` + `analyze` after.
- **`publish-dry` stays green** — README text is not validated by `pub publish --dry-run`; the 9.5 metadata fixes (repository/homepage + `## 1.0.0` CHANGELOG) are untouched. Confirm the dry-run gate is still green after the README edits.
- **`verify:versioning` stays green** — 9.6 touches no versions/ranges/lints-dev-only.
- **The doc gate bites** — `melos run docs` + the CI lane must FAIL on a real doc defect (Task 4 negative check). A gate that can't fail is a silent no-op.
- **`koel_devtools` stays excluded everywhere** — README, doc gate, docs concept page (its concept page + finalize are Epic 10).
- **Six dedicated gate workflows untouched** — only `ci.yml` (new doc lane) changes among the workflows.

### Scope boundaries (explicitly OUT of 9.6)

- Other OQ flips (Perf-Baseline / Conformance-Equivalence / Koel-Trademark / AGUI-License) + AR-24/25/26 PRD-body reconciliation → **Story 9.7**.
- `ag_ui` credit-line finalize + the `OQ-AGUI-License` "pending verification" note removal → **Story 9.8** (preserve the note here).
- The actual `melos publish` lock-step + CHANGELOG mirroring + `gh release` + docs-site **deployment/hosting** → **Story 9.9** (9.6 only proves the site builds locally).
- `koel_devtools` README/docs/concept page → **Epic 10** (post-1.0).
- Any `lib/` behavior change, any new public symbol, any new pub-workspace dependency → all OUT. 9.6 adds only: the `docs/` content tree + `ADR-001`, the ten README finalizations + repo-root README link, the one PRD OQ-Docs-Framework flip, the `docs` melos script, the `ci.yml` doc lane, and doc-comment-only broken-ref backfills.

### Testing standards

- This is **docs + one ADR + READMEs + a `dart doc` build gate + a CI lane**: the deliverable is verified by *running the gate* (`melos run docs` clean across the ten + the CI doc lane green + a negative bite-check) + the framework building locally, **not** a new unit-test suite. Record the clean-pass + injected-fail (and revert) in the Dev Agent Record (the 9.3/9.4/9.5 Task-5 "prove the gate bites" precedent).
- The `dart doc` build must be **clean** (zero missing-doc-comment + zero broken-ref/example) on the ten release packages; `koel_devtools` excluded.
- Any `///` edited for a broken ref must re-pass `dart format` + `melos run analyze` (doc-comment-only, no behavior change).

### Project Structure Notes

- `docs/` is the docs-site source per architecture.md:739–740 + :1115–1116 ("Documentation site source under repo `docs/` — deferred pending OQ-Docs-Framework") — this story *resolves* that deferral. The JS toolchain is self-contained under `docs/` (its `node_modules`/build output git-ignored); it is **not** a pub-workspace member → no structural variance in the Dart monorepo.
- `docs` melos script sits beside `analyze`/`conformance`/`publish-dry` in root `pubspec.yaml` (architecture §6 line 651 names `dart doc`; the dev-workflow list 1118–1133 is the script-family pattern). Prefer a `tool/` orchestrator if the per-package loop wants the `tool/conformance.sh` care.
- `ADR-001-docs-framework.md` lives under `docs/` (the decision record for the docs site itself).

### References

- [Source: epics/epic-9-meta-package-sample-app-v100-release-gates.md#Story 9.6 (lines 145–166)] — AC verbatim: OQ-Docs-Framework resolved + `docs/` D-3 structure (getting-started, concepts events/interceptors/reducer/sessions [devtools→Epic 10], recipes 10+, api-reference, migration-guide, adapter-cookbook) + `ADR-001`; all ten READMEs to §13 D-1 + anti-pattern review; `dart doc` via `melos run docs` → zero missing-doc-comment + clean per-package build (NFR-16).
- [Source: prds/prd-koel-2026-05-27/prd.md §13 (lines 338–344)] — D-1 README contract, D-2 doc-comment contract, D-3 docs-site sections. [§15 line 363] — OQ-Docs-Framework (the one 9.6 resolves). [§11] — forward-compat policy (migration-guide content). [§14 CM-6] — doc-comment density counter-metric.
- [Source: architecture.md (lines 644–662)] — doc-comment + README structure rules (no "Why X" marketing, ≤3 badges, contract over restatement); [:651] `@nodoc`/`dart doc`; [:739–740, :1115–1116] docs/ deferred pending OQ-Docs-Framework; [:1118–1133] the melos script family.
- [Source: implementation-artifacts/7-4-widget-tests-goldens-barrel-example.md] — the `public_member_api_docs` doc gate + the `dart doc` broken-`[ref]`-demote-to-code-span precedent; the `ci.yml` `example-smoke` in-scope-lane precedent.
- [Source: implementation-artifacts/9-5-conformance-publish-dry-run-green.md] — the immediately-prior story: the "prove the gate bites" Task-5 evidence pattern, the AI-5.9 0-drift discipline, the publish-dry metadata fixes (repository/homepage + `## 1.0.0` CHANGELOG) this story must not regress, the ten-vs-eleven release set (koel_devtools excluded).
- [Source: docs/patterns/stream-cancellation.md] — existing house-pattern doc to fold/link into the concepts/recipes tree.
- [Source: packages/koel_devtools/{pubspec.yaml,analysis_options.yaml:11–14}] — the exclusion evidence: `version: 0.0.1`, `publish_to: none`, doc gate deliberately off (Epic 8/10).
- [Source: SCP-2026-06-06-B] — Epic 9 resequenced ahead of DevTools; v1.0.0 ships the ten packages; koel_devtools deferred post-1.0 → Epic 10.
- [Source: .tool-versions] — Dart `3.12.0` / Flutter `3.44.0` (the reference toolchain; `dart doc` behavior verified on this Dart).

## Dev Agent Record

### Agent Model Used

claude-opus-4-8[1m] (Opus 4.8, 1M context) under the `/agent-flutter-engineer` persona (CLAUDE.md mandate).

### Debug Log References

- `dart doc` build baseline (Task 0): all ten clean EXCEPT `koel_test`, which surfaced a **build-only** defect `dart analyze` had passed — `unresolved doc reference [this.isReplaying]` in `tool_handler_test_harness.dart:120`. This is exactly the D5/D8 "stronger than the analyze lint" scenario; fixed by disambiguating to `[ToolHandlerTestHarness.isReplaying]` + the `isReplaying:` argument as a code-span (doc-comment only; re-ran `dart format` 0-changed + `dart doc` clean).
- Docusaurus build (Task 2): first build failed — `future: { v4: true }` opts into the Rspack "faster" bundler (`@docusaurus/faster` not installed). Removed the flag → default webpack bundler builds clean. Migrated the deprecated top-level `onBrokenMarkdownLinks` into `markdown.hooks.onBrokenMarkdownLinks`. Final `npm run build` is clean (`onBrokenLinks: 'throw'` → every internal link resolves).
- Negative bite-check (Task 4): injected `[ThisTypeDoesNotExist_BiteCheck]` into `packages/koel/lib/koel.dart`'s library doc → `melos run docs` FAILED (`docs: FAIL — koel`, exit 1, "unresolved doc reference"). Reverted via `git checkout` → `melos run docs` exit 0, all ten PASS. The gate bites.

### Completion Notes List

- **Task 0 — as-is verified.** `docs/` held only `patterns/stream-cancellation.md`; the ten release READMEs had most D-1 elements but a pending-OQ docs link and **no badges**; `public_member_api_docs` green under analyze; **no `docs` melos script** existed. The `dart doc` build baseline reproduced the koel_test broken ref (above).
- **Task 1 — OQ-Docs-Framework RESOLVED.** Authored `docs/ADR-001-docs-framework.md` (Docusaurus 3.x, toolchain isolated under `docs/`; Nextra recorded runner-up; Jaspr rejected). Flipped the **single** OQ-Docs-Framework line in PRD §15 to RESOLVED → ADR-001 (the other OQ flips + AR-24/25/26 are 9.7's — untouched, D6).
- **Task 2 — docs/ scaffolded + builds locally.** Docusaurus site with content at the `docs/` ROOT (per PRD §13 D-3) via docs plugin `path: '.'` + an `include` allowlist + `routeBasePath: '/'`. Content tree: `getting-started.md` (slug `/`); `concepts/{events,interceptors,reducer,sessions}.md` (NO devtools page — Epic 10); **14** recipes in `recipes/` (≥10 bar exceeded); `api-reference.md` (autolinks to per-package pub.dev API tabs — NOT a vendored HTML copy); `migration-guide.md` (1.x forward-compat); `adapter-cookbook.md` (extend `HttpAgent`/`AbstractAgent` + `ConformanceRunner`). Folded `patterns/stream-cancellation.md` into the sidebar + linked from cancel/sessions/cookbook (repo-relative source links rewritten to absolute GitHub URLs so the published site resolves them; trimmed the stale removed-`MultipartGraphQLStreamParser` reference). `npm run build` clean. Node toolchain isolated under `docs/`: `docs/node_modules` + `docs/build` + `docs/.docusaurus` git-ignored; `docs/package-lock.json` tracked.
- **Task 3 — ten READMEs to D-1.** Each gained the 3 badges (pub.dev version + license + CI), the resolved [koel docs site](https://si-huynh.github.io/koel/) link (replacing every "framework pending — `OQ-Docs-Framework`" placeholder), and dropped the stale "lands in/across Epic N" forward-looking phrasing. Repo-root `README.md` Documentation section updated (lines 48–49). koel_devtools README **untouched** (excluded). koel_core's `OQ-AGUI-License` credit "pending verification" note **preserved verbatim** (9.8 owns it).
  - **FINDING (own-it fix, all code is mine):** the koel & koel_http quickstarts used `HttpAgent(endpoint: …)` — the ctor param is `url:`, so they did not compile. The repo-root README quickstart additionally called non-existent `client.chatSession(threadId:)` + `session.run(String)`. Corrected all three to the real, compiling API (`HttpAgent(url:)`, `client.newSession()`, `session.stream` + `session.send`), matching `example/lib/main.dart` and `getting-started.md`. A non-compiling quickstart fails the D-1 quality bar.
  - "No print" interpreted per architecture §6:655–662, which bans the marketing "Why X" paragraph + >3 badges, NOT `print` in runnable quickstarts (idiomatic for showing output; matches `example/lib/main.dart`). The ten READMEs carry no `print` regardless; the root README/getting-started/recipes use it to show output.
- **Task 4 — `melos run docs` gate (NFR-16) + CI lane + bite-check.** New `tool/docs.sh` (bash loop over the ten release pkgs, `koel_devtools` excluded; mirrors `tool/publish_dry_run.sh`). dart doc reports broken-ref/example problems as *warnings while exiting 0*, so the gate parses dart doc's `Found N warnings and M errors.` summary and fails unless both are zero (the same self-reported-count cross-check publish_dry uses) — that is why the bite-check trips. Added the `docs` melos script (root `pubspec.yaml`, the ONLY pubspec edit) + a `docs` lane in `ci.yml` (bootstrap → build → `melos run docs`, the 7.4 example-smoke precedent). Clean-pass 10/10 + injected-fail proven (Debug Log).
- **Task 5 — gates green.** `pubspec.lock` **0-drift**; AI-5.9 pins held (analyzer 12.1.0 / freezed 3.2.6-dev.1 / analysis_server_plugin 0.3.14). `melos run format:check` 210 files 0-changed; `melos run analyze` SUCCESS (all pkgs + asp plugin + doc gate); `melos run test` SUCCESS-unchanged (koel_flutter 74, koel_widgets 44, koel_lints 5, koel_test green after the doc edit); `melos run verify:versioning` OK; `melos run api-diff` OK (**no public-symbol change** — doc-comment-only edits, surface unmoved); `melos run conformance` SUCCESS. `melos run docs` OK (10/10). `melos run publish-dry` green on a CLEAN committed tree (on the dirty working tree it correctly warns only "Modified files: README.md" — the documented 9.5 clean-tree caveat; README text is not validated by `pub publish --dry-run`, and CI runs on a clean checkout).

### File List

**New**
- `docs/ADR-001-docs-framework.md`
- `docs/.gitignore`, `docs/package.json`, `docs/package-lock.json`, `docs/tsconfig.json`, `docs/docusaurus.config.ts`, `docs/sidebars.ts`
- `docs/src/css/custom.css`, `docs/static/img/favicon.svg`
- `docs/getting-started.md`, `docs/migration-guide.md`, `docs/adapter-cookbook.md`, `docs/api-reference.md`
- `docs/concepts/events.md`, `docs/concepts/interceptors.md`, `docs/concepts/reducer.md`, `docs/concepts/sessions.md`
- `docs/recipes/quickstart-offline.md`, `connect-http-backend.md`, `connect-agno.md`, `connect-langgraph.md`, `connect-copilotkit-runtime.md`, `retry-and-auth.md`, `logging-and-tracing.md`, `pii-redaction-sentry.md`, `cancel-a-run.md`, `persist-sessions.md`, `secure-sessions.md`, `interrupt-resume.md`, `generative-ui.md`, `theming.md` (under `docs/recipes/`)
- `tool/docs.sh`

**Modified**
- `pubspec.yaml` (added the `docs` melos script — the only pubspec edit)
- `.github/workflows/ci.yml` (added the `docs` build lane)
- `README.md` (Documentation section + corrected quickstart API)
- `docs/patterns/stream-cancellation.md` (folded into the tree: source links → absolute GitHub URLs; trimmed stale parser ref)
- `_bmad-output/planning-artifacts/prds/prd-koel-2026-05-27/prd.md` (the single OQ-Docs-Framework line → RESOLVED)
- `packages/koel/README.md`, `packages/koel_core/README.md`, `packages/koel_http/README.md`, `packages/koel_lints/README.md`, `packages/koel_test/README.md`, `packages/koel_agno/README.md`, `packages/koel_langgraph/README.md`, `packages/koel_runtime/README.md`, `packages/koel_flutter/README.md`, `packages/koel_widgets/README.md` (D-1 finalization: badges + docs link + phrasing cleanup; koel/koel_http quickstart `endpoint:`→`url:`)
- `packages/koel_test/lib/src/tool_handler_test_harness.dart` (doc-comment-only: broken `[this.isReplaying]` ref backfill — no behavior change)

## Change Log

| Date | Change |
|---|---|
| 2026-06-07 | Story 9.6 drafted (create-story): docs/ scaffold + `ADR-001` (OQ-Docs-Framework resolved, FYI default Docusaurus 3.x) + full D-3 content tree (devtools concept page → Epic 10); ten release READMEs to §13 D-1 (≤3 badges, real docs link, anti-pattern clean, preserve the 9.8 `ag_ui` credit note); `melos run docs` `dart doc` build gate (NFR-16, stronger than the analyze doc gate) + `ci.yml` doc lane + prove-the-gate-bites; one PRD §15 OQ-Docs-Framework flip. AI-5.9 0-drift (JS toolchain outside the pub-workspace), no lib/src change, no public symbol, koel_devtools excluded. Status → ready-for-dev. |
| 2026-06-07 | dev-story 9.6: ADR-001 committed + PRD OQ-Docs-Framework → RESOLVED; Docusaurus site scaffolded under `docs/` (content at root per D-3) + full tree (getting-started, 4 concepts, **14** recipes, api-reference autolink stub, migration-guide, adapter-cookbook) — `npm run build` clean, Node toolchain git-ignored (lock 0-drift). Ten READMEs finalized to D-1 (3 badges + docs link, stale phrasing dropped); koel_devtools excluded, koel_core `OQ-AGUI-License` note preserved. **Bug fix:** quickstart API corrected (`HttpAgent(url:)`, `newSession`/`send`/`stream`) — was non-compiling (`endpoint:`/`chatSession`/`run`). New `tool/docs.sh` + `docs` melos script + `ci.yml` doc lane (NFR-16); gate proven to bite. Doc-comment broken-ref backfill in koel_test (build-only defect analyze passed). Gates: lock 0-drift + AI-5.9 pins held; analyze/format:check/test/verify:versioning/api-diff/conformance/docs all green; api-diff 0-delta (no public symbol). Status → review. |
