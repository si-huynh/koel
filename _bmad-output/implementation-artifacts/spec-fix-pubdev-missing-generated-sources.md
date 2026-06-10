---
title: 'Fix broken pub.dev releases — ship generated Dart files in archives'
type: 'bugfix'
created: '2026-06-10'
status: 'in-progress'
context: ['{project-root}/RELEASING.md']
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** Root `.gitignore` excludes `*.g.dart`/`*.freezed.dart`, and `dart pub publish` honors `.gitignore` — so every published archive with codegen shipped without its generated part files. koel_core 1.1.0 (~15 broken parts), koel_http 1.1.0 (1), and koel_test 1.0.0 (1, verified by downloading the archive) are uncompilable for hosted consumers (TPS app: 42 analyzer errors). pub.dev is immutable → supersede with patch releases.

**Approach:** Maintainer decision (final): commit generated files to git so git state == published state. Republish koel_core 1.1.1 + koel_http 1.1.1 + koel_lints 1.1.1 (lock-step trio per RELEASING.md R-2; lints is packaging-unaffected, mirrored entry) + koel_test 1.0.1. Add a pre-publish gate asserting generated files appear in the dry-run file list, plus a real committed-vs-regenerated drift check in CI.

## Boundaries & Constraints

**Always:** Zero API change — `ChatSession.regenerate()`/`updateState()` ship unchanged; api-diff against committed baselines must stay clean. Publish order per runbook: koel_lints → koel_core + koel_http → koel_test. All publish gates (analyze, test, format:check, api-diff, publish-dry, verify:versioning) green before any `dart pub publish`.

**Ask First:** Retracting any existing pub.dev version (current plan: supersede only, no retraction).

**Never:** No `.pubignore` route. No build_runner step in the publish flow as the primary fix. No bump/publish of unaffected packages beyond the lock-step rule (koel_agno, koel, koel_flutter, koel_langgraph, koel_runtime, koel_widgets stay — audited: no codegen parts in their lib/). Do not loosen the koel_lints asp `0.3.14` pin or touch the D4 allowlist semantics.

</frozen-after-approval>

## Code Map

- `.gitignore:8-9` -- delete `*.g.dart` + `*.freezed.dart` (keep `*.mocks.dart`: zero such files exist; test-only if ever added)
- `packages/{koel_core,koel_http,koel_test}/lib/**` -- 17 generated files to track (15+1+1, match build_runner output)
- `packages/{koel_core,koel_http,koel_lints}/pubspec.yaml` -- version → 1.1.1; `koel_test/pubspec.yaml` → 1.0.1
- `packages/*/CHANGELOG.md` (4) -- packaging-fix entries; lints = mirrored lock-step entry
- `tool/publish_dry_run.sh` -- NEW assertion: every `part '….freezed.dart'/'….g.dart'` in lib/ must appear in the dry-run file list
- `.github/workflows/codegen-drift.yml` -- add committed-vs-regenerated `git diff --exit-code` after first build (current job only checks determinism; comments self-document the no-op)
- `tool/format.sh`, `packages/*/analysis_options.yaml` -- already exclude generated files; no change, verify only
- `RELEASING.md` -- add generated-files-in-archive assertion to §1 gate; record v1.1.1 in history

## Tasks & Acceptance

**Execution:**
- [ ] `.gitignore` -- remove lines 8–9 -- root cause
- [ ] all codegen pkgs -- `dart run build_runner build --delete-conflicting-outputs`, `git add` outputs -- regenerate fresh, track
- [ ] verify -- every `part` directive in `packages/*/lib` resolves to a tracked file -- no orphan parts
- [ ] 4 pubspecs + 4 CHANGELOGs -- bump + entries -- supersede broken versions
- [ ] `tool/publish_dry_run.sh` -- generated-file-list assertion -- the gate that was missing
- [ ] `.github/workflows/codegen-drift.yml` -- drift check vs committed files -- prevent regression
- [ ] `RELEASING.md` -- gate note + history entry -- runbook stays truth
- [ ] run full gate suite, commit `release(v1.1.1)`, tag, publish 4 packages, `gh release create`
- [ ] scratch consumer outside repo: hosted-only `koel_core ^1.1.1` + `koel_http ^1.1.1` + `koel_agno ^1.0.0` → `dart analyze` 0 errors; spot-check `ChatState.phase`, `CustomEvent.name`

**Acceptance Criteria:**
- Given the release commit, when `git ls-files 'packages/*/lib/**' | grep -E '\.(freezed|g)\.dart$'` runs, then it lists all 17 generated files (== build_runner output).
- Given `melos run publish-dry`, when it runs on the clean release commit, then it passes AND the koel_core/koel_http/koel_test file lists include their generated files.
- Given a fresh hosted-only consumer on 1.1.1/1.0.1, when `dart pub get && dart analyze` runs, then 0 errors.
- Given the koel test suites, when run post-change, then green (koel_core 597 baseline) — packaging only, no behavior change.

## Spec Change Log

## Verification

**Commands:**
- `melos run analyze && melos run format:check && melos run verify:versioning && melos run api-diff` -- expected: all pass, 0 breaking
- `melos run publish-dry` -- expected: PASS lines incl. new generated-file assertions
- `melos exec --depends-on=build_runner -- dart test` (or `melos run test:coverage`) -- expected: green, koel_core 597
- post-publish: `curl -s https://pub.dev/api/packages/koel_core | jq -r .latest.version` → `1.1.1` (+ http 1.1.1, lints 1.1.1, test 1.0.1)
