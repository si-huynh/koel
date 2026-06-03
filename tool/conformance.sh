#!/usr/bin/env bash
# Per-package AG-UI conformance lane for `melos run conformance` (FR-G4),
# invoked via `melos exec` so the CWD is the package root (required for the
# package-relative fixture reads). Runs the `conformance`-tagged tests —
# `ConformanceRunner` driven against each backend adapter, replaying fixtures
# through a `MockClient` (offline: no backend container needed in CI).
#
# koel_agno is the first adapter wired (Story 5.3); langgraph (5.6) and
# copilotkit (5.9) extend this lane by adding their own `@Tags(['conformance'])`
# tests. Packages with no conformance tests yet are tolerated, exactly like
# tool/test_package.sh: empty dirs are not git-tracked, so a fresh CI checkout
# lacks them; `dart test --tags conformance` then exits 79 (files present, none
# matched) or 65 (no test/ dir) — both are "nothing to run here", not failures.
set -u

# Only packages that DECLARE the `conformance` tag (in their dart_test.yaml — the
# established tag-declaration convention, mirroring `perf`) participate. This
# keeps the lane quiet: without the gate, `dart test --tags conformance` prints
# "No tests match" + exits 79 in every adapter-less package. 5.6/5.9 opt in by
# declaring the tag.
if [ ! -f dart_test.yaml ] || ! grep -q "conformance" dart_test.yaml; then
  exit 0
fi

dart test --tags conformance
code=$?

# 79 = files present but none matched; 65 = no test/ dir. Both "nothing to run".
if [ "$code" -eq 0 ] || [ "$code" -eq 79 ] || [ "$code" -eq 65 ]; then
  exit 0
fi
exit "$code"
