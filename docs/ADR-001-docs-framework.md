# ADR-001 — Docs-site framework

- **Status:** Accepted (2026-06-07, Story 9.6)
- **Resolves:** `OQ-Docs-Framework` (PRD §15) — *"Docusaurus vs Nextra vs alternative for the dedicated docs site."*
- **Scope:** the public documentation site under `docs/` only. Not a Dart/runtime decision.

## Context

PRD §13 D-3 requires a multi-section guide site — Getting Started · Concepts ·
Recipes (≥10) · API Reference · Migration Guide · Adapter Cookbook — alongside
the per-package `dart doc` reference (pub.dev "API" tab) and the README quality
bar. The framework choice was deferred at PRD time as `OQ-Docs-Framework` with
the explicit note that it "does not block code work." Story 9.6 is the resolver:
it scaffolds the site, authors the content tree, and commits this decision.

The one real constraint is the load-bearing AI-5.9 pin set (`analyzer 12.1.0` /
`freezed 3.2.6-dev.1` / `analysis_server_plugin 0.3.14`, SCP-2026-05-29-B /
architecture D3). Any tool that enters the Dart pub-workspace risks moving those
pins. The docs site must therefore stay **outside** the pub-workspace.

## Decision

**Docusaurus 3.x**, with its Node/JS toolchain isolated entirely under `docs/`.

`docs/` is its own self-contained project: `docs/package.json`, its config, and
its `node_modules`/build output (both git-ignored). It is **not** a pub-workspace
member, never enters `pubspec.lock`, and cannot move a Dart pin — the only
objection to a JS toolchain is neutralized by isolation. The site builds locally
via `npm --prefix docs ci && npm --prefix docs run build`; deployment/hosting is
Story 9.9.

The content tree lives at the `docs/` root per PRD §13 D-3
(`getting-started.md`, `concepts/`, `recipes/`, `api-reference/`,
`migration-guide.md`, `adapter-cookbook.md`); the Docusaurus docs plugin is
pointed at `.` with the config/ADR/node artifacts excluded, so the authored
markdown paths match the PRD contract exactly rather than being buried under a
`docs/docs/` convention folder.

### Why Docusaurus

1. **First-class versioned docs.** Directly serves the "Migration Guide across
   minor versions" (D-3) and the 1.x forward-compat policy (PRD §11). Versioning
   is a built-in, not a bolt-on.
2. **MDX.** Tabbed/interactive code blocks for the ≥10 Recipes and the Adapter
   Cookbook — the right substrate for a worked-example-heavy SDK site.
3. **Algolia DocSearch** — free for OSS, crawled search at the premium bar.
4. **De-facto OSS-SDK standard.** Contributors already know the layout; lowers
   the barrier to doc PRs.
5. **Zero pub-workspace impact** — the isolation note above.

## Alternatives rejected

- **Nextra** — lighter, cleaner default theme, but weaker built-in versioning
  (the migration-guide-across-versions requirement is the deciding factor). It
  is the runner-up: a sound choice if minimalism is later preferred over
  versioning depth.
- **Dart-native (Jaspr, or raw `dart doc` + a static host)** — DNA-aligned (no
  JS toolchain at all) but immature for a versioned, multi-section guide site:
  no built-in search, versioning, or sidebar generation. `dart doc` *is* still
  the source of truth for the API reference — the site's `api-reference/`
  section autolinks to the per-package pub.dev API tabs rather than vendoring a
  copy. So this option is not fully discarded; it owns the API tier, just not
  the guide site.

## Consequences

- `docs/node_modules` and the Docusaurus build output are git-ignored; CI/9.9
  run `npm ci` from the committed `package-lock.json`.
- The Dart side is untouched: `pubspec.lock` stays 0-drift, the AI-5.9 pins do
  not move, and no `lib/src/**` or public symbol changes (`api-diff` green by
  construction).
- The separate `dart doc` *build* gate (`melos run docs`, NFR-16) is unaffected
  by this choice — it gates the per-package API reference, which is the pub.dev
  API tab the site links to, not the Docusaurus build.
- Story 9.9 owns the deploy (GitHub Pages at `https://si-huynh.github.io/koel/`)
  and the CHANGELOG mirroring; 9.6 only proves the site builds locally.
