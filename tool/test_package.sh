#!/usr/bin/env bash
# Per-package test runner for `melos run test` (invoked via `melos exec`, so the
# CWD is the package root — required for the package-relative fixture reads in
# full_event_sweep_test.dart / rfc6902_conformance_test.dart, deferred-work.md
# :158). Excludes the perf benches (baseline tooling, not unit tests).
#
# A scaffold package with no tests yet is treated as success; every real
# failure is propagated. There are two distinct "no tests" outcomes and BOTH
# must be tolerated — empty dirs are not git-tracked, so a fresh CI checkout
# (actions/checkout) lacks them entirely:
#   * absent / empty `test/` dir            -> `dart test` exits 65
#   * `test/` has *_test.dart but 0 ran     -> `dart test` exits 79
# The exit-code check lives here, not inline in melos.scripts, because melos
# interpolates `$?` at script-expansion time before the shell can evaluate it.
set -u

# Skip cleanly when the package has no test files at all — covers the
# fresh-checkout case where the empty `test/` dir does not exist (dart test
# would otherwise exit 65 and fail the whole `melos run test` sweep).
if [ ! -d test ] || [ -z "$(ls -A test 2>/dev/null)" ]; then
  exit 0
fi

dart test --exclude-tags=perf
code=$?

# 0 = passed; 79 = test files present but none matched (e.g. all perf-tagged);
# 65 = no test/ dir or it is empty (no suites to load). All three are "nothing
# to run here", not a failure.
if [ "$code" -eq 0 ] || [ "$code" -eq 79 ] || [ "$code" -eq 65 ]; then
  exit 0
fi
exit "$code"
