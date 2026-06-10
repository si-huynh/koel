# Releasing koel

The publish runbook for the koel SDK — generalized after v1.1.0 from the
original v1.0.0 one-shot. This is the **owner (P1) go/no-go**: every step below
is reversible *until* the `dart pub publish` / `git tag` / `gh release create`
lines, which are **irreversible and outward-facing** — pub.dev archives are
permanent (retraction hides, never deletes). Do not run the publish lines as a
side effect of any automation. Run them only from a clean `main`, with the gate
checklist green, and with the `sihuynh.dev` verified publisher authenticated.

- **Release set:** the **ten** release packages. `koel_devtools` is **excluded**
  until its Epic 10 release (stays `publish_to: none`). `example/` is not a
  release package.

---

## 0. Pick the release shape and version

Two shapes, both DAG-safe because every intra-repo dep is a **caret range**
(`^X.Y.Z`, enforced by `verify:versioning`):

- **Foundation release** — changes land in `koel_core` / `koel_http` /
  `koel_lints` only. Bump **all three lock-step** (R-2 requires identical
  version strings; `koel_http`/`koel_lints` get a mirrored "lock-step, no
  functional changes" CHANGELOG entry when untouched). Publish **only the
  trio** — the seven dependents resolve the new foundation through their
  ranges. *(v1.1.0 was this shape.)*
- **Full release** — changes span adapters/glue or a breaking foundation bump
  forces new ranges. Bump every affected package, publish in the §3 DAG order,
  ending with the `koel` meta-package.

Version level is **semver, decided by the API surface, not by feel**: any new
public symbol ⇒ MINOR; breaking ⇒ MAJOR (and a range-widening sweep across
dependents); docs/internal-only ⇒ PATCH. `melos run api-diff` is the arbiter —
additive warnings mean the bump is at least minor.

Per release: bump `version:` in each released pubspec, prepend the CHANGELOG
entries, refresh the committed API baselines (`melos run api-diff -- --update`),
and land it all as one `release(vX.Y.Z): prepare …` commit on `main`.

## 1. Pre-publish checklist (the go/no-go gate)

Run from a clean `main` (`git status` clean, `git pull` current). Every line must
pass before publishing — PRD §5.1 SC-1..SC-5 + the supporting gates + the
six-workflow matrix (PRD §12 R-5).

```bash
melos run analyze            # SC-3 — 0 warnings across every package + asp plugin
melos run test:coverage      # SC-2 — foundations ≥90% line+branch; adapters/tooling ≥80%
melos run api-diff           # SC-4 — 0 breaking changes vs the committed baselines
melos run conformance        # SC-1 — ConformanceRunner green on agno/langgraph/runtime + real fixtures round-trip
melos run perf               # N-1..N-5 within band
melos run docs               # NFR-16 — dart doc 0 warnings / 0 errors on all 10
melos run format:check       # 0 files changed
melos run verify:versioning  # lock-step + ^X.Y.Z ranges + lints dev-only
melos run publish-dry        # strict 0-warning + koel_lints 2-item allowlist (run on a CLEAN tree)
```

- **SC-5 (no vestigial code):** confirm no `TODO` / commented-out blocks /
  unused exports in `package:koel_*`.
- **`pubspec.lock` 0-drift** + the workspace analyzer/codegen pins held (see
  AI-5.9: analyzer / freezed / analysis_server_plugin).
- **Six-workflow matrix green on the release commit** (all are real-bodied):
  `ci.yml`, `conformance.yml`, `perf-bench.yml`, `api-diff.yml`,
  `codegen-drift.yml`, `publish-dry-run.yml`.

> `publish-dry` warns on locally-modified **tracked** files ("checked-in files
> are modified in git"). That warning is a clean-tree artifact only — commit
> first, then it is 0-warning (and CI, on a fresh checkout, never sees it).

---

## 2. Authenticate the publisher

The packages publish under the **`sihuynh.dev`** verified publisher. Confirm the
active account before publishing:

```bash
dart pub token list          # or: dart pub login  (opens the OAuth flow)
```

---

## 3. Publish order (DAG-forced)

Publish **only the packages whose version changed**, in dependency order, so
every dependent resolves its koel deps as **published packages**, not path refs:

1. **`koel_lints`** — **first** (dependents reference it as a dev-dependency).
2. **`koel_core` + `koel_http`** — **lock-step**, identical version, mirrored
   CHANGELOGs.
3. The six dependents, when released (any order; each declares a **range**,
   not a pin): **`koel_test`, `koel_agno`, `koel_langgraph`, `koel_runtime`,
   `koel_flutter`, `koel_widgets`**.
4. **`koel`** meta-package — **last** (re-exports `koel_core` + `koel_http` +
   `koel_flutter`). A foundation-only release skips 3–4.

### Option A — melos (honors dependency order, full release)

`melos publish` walks the workspace in dependency order and runs a dry-run; add
`--no-dry-run` to actually push. It skips `publish_to: none` packages
(`koel_devtools`, `example`) automatically — but it publishes everything with a
version not yet on pub.dev, so prefer Option B for partial releases.

```bash
melos publish                 # final dry-run across the workspace (sanity)
melos publish --no-dry-run    # PUBLISHES — irreversible
```

### Option B — explicit per-package sequence (full control)

```bash
( cd packages/koel_lints  && dart pub publish )   # 1 — first
( cd packages/koel_core   && dart pub publish )   # 2 — lock-step
( cd packages/koel_http   && dart pub publish )   # 2 — lock-step
# full release only:
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

After the released packages are live on pub.dev:

```bash
git tag vX.Y.Z
git push origin vX.Y.Z

gh release create vX.Y.Z \
  --title "koel vX.Y.Z" \
  --notes-file <drafted-notes.md>
```

Notes lead with what changed and which packages moved; link the pub.dev pages
and the docs site. Attach the immutable baseline artifacts (5 perf + 9 API)
**when this release changed them** — a release that refreshed
`.api-baseline/*.json` or `test/perf/baselines/*.json` re-uploads the new
truth; one that didn't can point at the previous release's artifacts:

```bash
gh release upload vX.Y.Z \
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

## 5. Docs site

The docs site (`https://si-huynh.github.io/koel/`, Docusaurus — see
[`docs/ADR-001-docs-framework.md`](docs/ADR-001-docs-framework.md)) deploys
**automatically** via [`.github/workflows/docs-deploy.yml`](.github/workflows/docs-deploy.yml):
on every push to `main` touching `docs/**` it runs `npm --prefix docs ci && npm
--prefix docs run build` and publishes `docs/build` to GitHub Pages (Pages source
= GitHub Actions). The build enforces `onBrokenLinks: 'throw'`, so it is also the
docs-site link-integrity gate. To redeploy on demand: `gh workflow run
docs-deploy.yml`. No manual step is required at release time.

---

## 6. Post-publish verification

```bash
# Each released package shows the new version live (`dart pub info` does not
# exist — query the pub.dev API; the resolver-facing index can lag it by up to
# ~10 minutes, so a fresh-project resolve may briefly pick the prior version):
for p in koel_lints koel_core koel_http; do   # extend for a full release
  echo -n "$p latest: "
  curl -s "https://pub.dev/api/packages/$p" | jq -r .latest.version
done

# The quickstart resolves from a fresh Flutter project. `koel` re-exports
# koel_flutter, so it transitively pulls the Flutter SDK — use `flutter create`,
# NOT a pure-Dart `dart create -t console` template (which can't resolve it):
flutter create /tmp/koel_smoke && cd /tmp/koel_smoke
flutter pub add koel && flutter pub get
```

Re-confirm the six-workflow matrix is green on the release commit, and that
pub.dev renders each released package's README, CHANGELOG, and new version.

---

## Release history

- **v1.1.0** (2026-06-10) — foundation trio; adds `ChatSession.regenerate()` +
  `ChatSession.updateState()` to koel_core.
- **v1.0.0** (2026-06-08) — first stable release, all ten packages lock-step;
  replaced the `0.0.1-pre` name reservations under `sihuynh.dev`. Conformant to
  AG-UI `release/2026-05-26`
  (commit `d74e2dfc1e11bebdff419c2cbd347c811555411d`).
