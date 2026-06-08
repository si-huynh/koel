# Releasing koel v1.0.0

The lock-step publish runbook for the koel SDK. This is the **owner (P1)
go/no-go**: every step below is reversible *until* the `dart pub publish` /
`git tag` / `gh release create` lines, which are **irreversible and
outward-facing** — pub.dev archives are permanent (retraction hides, never
deletes). Do not run the publish lines as a side effect of any automation. Run
them only from a clean `main`, with the SC gate checklist green, and with the
`sihuynh.dev` verified publisher authenticated.

- **Scope:** the **ten** release packages. `koel_devtools` is **excluded**
  (deferred post-1.0 → Epic 10; stays `version: 0.0.1` + `publish_to: none`).
  `example/` is not a release package.
- **Versions are already set** to `1.0.0` (Story 9.1) — `melos version` is a
  no-op; do **not** re-bump.

---

## 1. Pre-publish checklist (the go/no-go gate)

Run from a clean `main` (`git status` clean, `git pull` current). Every line must
pass before publishing — this is PRD §5.1 SC-1..SC-5 + the supporting gates +
the six-workflow matrix (PRD §12 R-5).

```bash
melos run analyze            # SC-3 — 0 warnings across every package + asp plugin
melos run test:coverage      # SC-2 — foundations ≥90% line+branch; adapters/tooling ≥80%
melos run api-diff           # SC-4 — 0 breaking changes vs the 9 committed baselines
melos run conformance        # SC-1 — ConformanceRunner green on agno/langgraph/runtime + real fixtures round-trip
melos run perf               # N-1..N-5 within band
melos run docs               # NFR-16 — dart doc 0 warnings / 0 errors on all 10
melos run format:check       # 0 files changed
melos run verify:versioning  # lock-step + ^1.0.0 ranges + lints dev-only
melos run publish-dry        # 9 strict 0-warning + koel_lints 2-item allowlist (run on a CLEAN tree)
```

- **SC-5 (no vestigial code):** confirm no `TODO` / commented-out blocks /
  unused exports in `package:koel_*` (built no-vestigial throughout — a
  confirmation, not a cleanup).
- **`pubspec.lock` 0-drift** + **AI-5.9 pins held**: analyzer `12.1.0` /
  freezed `3.2.6-dev.1` / analysis_server_plugin `0.3.14`.
- **Six-workflow matrix green on the release commit** (all are real-bodied):
  `ci.yml`, `conformance.yml`, `perf-bench.yml`, `api-diff.yml`,
  `codegen-drift.yml`, `publish-dry-run.yml`.

> `publish-dry` warns on locally-modified **tracked** files ("checked-in files
> are modified in git"). That warning is a clean-tree artifact only — commit
> first, then it is 0-warning (and CI, on a fresh checkout, never sees it).

---

## 2. Authenticate the publisher

The ten packages publish under the **`sihuynh.dev`** verified publisher. Confirm
the active account before publishing:

```bash
dart pub token list          # or: dart pub login  (opens the OAuth flow)
```

Each `1.0.0` publish **replaces the `0.0.1-pre` name reservation** currently held
under `sihuynh.dev` (deferred-work.md:194) with the real first stable release.

---

## 3. Publish order (DAG-forced)

The dependency DAG forces the order so every dependent resolves its koel deps as
**published packages**, not path refs:

1. **`koel_lints`** — **first** (dependents reference it as a dev-dependency; it
   must exist on pub.dev before they publish).
2. **`koel_core` + `koel_http`** — **lock-step**, identical `1.0.0`, mirrored
   CHANGELOGs.
3. The six dependents (any order; each declares `koel_core: ^1.0.0`, a **range**,
   not a pin): **`koel_test`, `koel_agno`, `koel_langgraph`, `koel_runtime`,
   `koel_flutter`, `koel_widgets`**.
4. **`koel`** meta-package — **last** (re-exports `koel_core` + `koel_http` +
   `koel_flutter`).

`koel_devtools` joins in its post-1.0 Epic 10 release — **not** here.

### Option A — melos (honors dependency order)

`melos publish` walks the workspace in dependency order and runs a dry-run; add
`--no-dry-run` to actually push. It skips `publish_to: none` packages
(`koel_devtools`, `example`) automatically.

```bash
melos publish                 # final dry-run across the workspace (sanity)
melos publish --no-dry-run    # PUBLISHES — irreversible
```

### Option B — explicit per-package sequence (full control)

```bash
( cd packages/koel_lints  && dart pub publish )   # 1 — first
( cd packages/koel_core   && dart pub publish )   # 2 — lock-step
( cd packages/koel_http   && dart pub publish )   # 2 — lock-step
( cd packages/koel_test       && dart pub publish )   # 3
( cd packages/koel_agno       && dart pub publish )   # 3
( cd packages/koel_langgraph  && dart pub publish )   # 3
( cd packages/koel_runtime    && dart pub publish )   # 3
( cd packages/koel_flutter    && dart pub publish )   # 3
( cd packages/koel_widgets    && dart pub publish )   # 3
( cd packages/koel        && dart pub publish )   # 4 — last
```

Each `dart pub publish` prompts for confirmation; there is no quiet mass-publish.

---

## 4. Tag + GitHub release

After all ten are live on pub.dev:

```bash
git tag v1.0.0
git push origin v1.0.0

gh release create v1.0.0 \
  --title "koel v1.0.0" \
  --notes-file - <<'NOTES'
<paste the drafted notes from §5>
NOTES

# Attach the immutable baseline artifacts (5 perf + 9 API):
gh release upload v1.0.0 \
  packages/koel_http/test/perf/baselines/sse_parse_bench.json \
  packages/koel_core/test/perf/baselines/reducer_bench.json \
  packages/koel_flutter/test/perf/baselines/chat_session_memory_bench.json \
  packages/koel_core/test/perf/baselines/cold_start_bench.json \
  packages/koel_flutter/test/perf/baselines/streaming_jank_bench.json \
  packages/koel/.api-baseline/koel.json \
  packages/koel_core/.api-baseline/koel_core.json \
  packages/koel_http/.api-baseline/koel_http.json \
  packages/koel_test/.api-baseline/koel_test.json \
  packages/koel_agno/.api-baseline/koel_agno.json \
  packages/koel_langgraph/.api-baseline/koel_langgraph.json \
  packages/koel_runtime/.api-baseline/koel_runtime.json \
  packages/koel_flutter/.api-baseline/koel_flutter.json \
  packages/koel_widgets/.api-baseline/koel_widgets.json
```

---

## 5. Drafted release notes (v1.0.0)

```markdown
# koel v1.0.0

The first stable release of koel — a premium Dart/Flutter client for the
AG-UI protocol, conformant to AG-UI `release/2026-05-26`
(commit `d74e2dfc1e11bebdff419c2cbd347c811555411d`).

## Foundation (lock-step 1.0.0)
- **koel_core** — the protocol kernel: closed 28-type sealed `AgUiEvent`
  registry, sealed `KoelError` hierarchy, vendored RFC 6902 JSON Patch, the
  four-stage event pipeline (decode → verify → reduce → dispatch), the
  `ChatState` reducer, the interceptor chain, `SessionStorage`, and the
  `KoelClient` / `ChatSession` API.
- **koel_http** — framework-free SSE transport: SSE parser, `HttpAgent` with
  cancellation propagation, chunk synthesis, connection-lifecycle hooks, and the
  interceptor suite (retry, auth, logging, event-trace, Sentry, PII redaction).
- **koel_lints** — the koel analysis ruleset on the first-party
  `analysis_server_plugin`.

## Backend adapters & glue
- **koel_test** — mock agent, fixtures, fixture loader, tool-handler harness,
  and the `ConformanceRunner`.
- **koel_agno** / **koel_langgraph** / **koel_runtime** — agno, LangGraph, and
  CopilotKit-runtime (native AG-UI/SSE v2) adapters.
- **koel_flutter** — `KoelChatController`, `KoelClientScope`, Hive + secure
  session storage, message-content parser, generative-UI widget resolver.
- **koel_widgets** — themeable chat primitives: `KoelTheme`, `MessageBubble`,
  `ChatInput`, `FollowUpList`.
- **koel** — single-import meta-package (`koel_core` + `koel_http` +
  `koel_flutter`).

## Conformance & performance
- Conformance: [`CONFORMANCE.md`](packages/koel_core/CONFORMANCE.md) —
  `AgUiEvent_equal` byte-equal rule, pinned AG-UI release SHA.
- Benchmarks: [`BENCHMARKS.md`](BENCHMARKS.md) — N-1..N-5 baselines (attached).

## Links
- Docs: https://si-huynh.github.io/koel/
- Changelogs: koel_core / koel_http / koel_lints (mirrored 1.0.0 notes).

Install: `dart pub add koel`
```

Adjust the package links to their pub.dev URLs once live
(`https://pub.dev/packages/<name>`).

---

## 6. Docs site

The docs site (`https://si-huynh.github.io/koel/`, Docusaurus — see
[`docs/ADR-001-docs-framework.md`](docs/ADR-001-docs-framework.md)) deploys
**automatically** via [`.github/workflows/docs-deploy.yml`](.github/workflows/docs-deploy.yml):
on every push to `main` touching `docs/**` it runs `npm --prefix docs ci && npm
--prefix docs run build` and publishes `docs/build` to GitHub Pages (Pages source
= GitHub Actions). The build enforces `onBrokenLinks: 'throw'`, so it is also the
docs-site link-integrity gate. To redeploy on demand: `gh workflow run
docs-deploy.yml`. No manual step is required at release time — the site went live
2026-06-08.

---

## 7. Post-publish verification

```bash
# Each package shows 1.0.0 live:
for p in koel koel_core koel_http koel_lints koel_test koel_agno \
         koel_langgraph koel_runtime koel_flutter koel_widgets; do
  echo "== $p =="; dart pub info "$p" 2>/dev/null | head -1 || true
done

# The quickstart resolves from a fresh Flutter project. `koel` re-exports
# koel_flutter, so it transitively pulls the Flutter SDK — use `flutter create`,
# NOT a pure-Dart `dart create -t console` template (which can't resolve it):
flutter create /tmp/koel_smoke && cd /tmp/koel_smoke
flutter pub add koel && flutter pub get
```

Re-confirm the six-workflow matrix is green on the release commit, and that
pub.dev renders each package's README, CHANGELOG, and `1.0.0` version.
