#!/usr/bin/env bash
# Per-package test runner for `melos run test` (invoked via `melos exec`, so the
# CWD is the package root — required for the package-relative fixture reads in
# full_event_sweep_test.dart / rfc6902_conformance_test.dart, deferred-work.md
# :158). Excludes the perf benches (baseline tooling, not unit tests).
#
# A scaffold package with no tests yet is treated as success; every real failure
# is propagated. The two "nothing to run" outcomes, by runner (verified on Dart
# 3.12 / Flutter 3.44, AI-6.2 2026-06-06):
#   * absent / empty `test/` dir   -> `dart test` exits 65; `flutter test` exits
#     1 ("Test directory \"test\" not found.") — NOT 65. Exit 1 is
#     indistinguishable from a real failure, so this case MUST be caught before
#     the runner: the guard below is load-bearing for the Flutter branch.
#   * `test/` has *_test.dart, 0 matched the filter (e.g. all `perf`-tagged) ->
#     BOTH `dart test` and `flutter test` exit 79 ("No tests match ...").
# The exit-code check lives here, not inline in melos.scripts, because melos
# interpolates `$?` at script-expansion time before the shell can evaluate it.
set -u

# Skip cleanly when the package has no test files at all — covers the
# fresh-checkout case where the empty `test/` dir is not git-tracked (so it does
# not exist on a CI `actions/checkout`). Essential for the Flutter branch, which
# otherwise exits 1 (not a tolerated code) on a missing `test/` dir.
if [ ! -d test ] || [ -z "$(ls -A test 2>/dev/null)" ]; then
  exit 0
fi

# A package needs `flutter test` iff it pulls the Flutter SDK — its tests bind
# `flutter_test`, which `dart test` cannot load (no engine binding). That SDK
# pull shows up as a block-form `sdk: flutter` value line under `flutter:`
# (runtime dep) or `flutter_test:` / `integration_test:` (dev dep); all three
# require the engine, so any of them routes here. Anchor to the indented YAML
# value line (`^<indent>sdk: flutter$`) rather than a bare `grep "sdk: flutter"`
# substring, so a `sdk: flutter` mention inside a comment or description string
# can never mis-route a pure-Dart package. (Verified: no pure-Dart koel package
# contains the line; koel_widgets/koel_devtools gain it the moment they add the
# `flutter_test` dev-dep their first widget test requires.)
if grep -qE '^[[:space:]]*sdk:[[:space:]]+flutter[[:space:]]*$' pubspec.yaml; then
  flutter test --exclude-tags=perf
else
  dart test --exclude-tags=perf
fi
code=$?

# 0 = passed; 79 = test files present but none matched the filter (both runners).
# 65 = `dart test` with no/empty `test/` dir (the Flutter equivalent, exit 1, is
# pre-empted by the guard above, so 65 is the dart-only tail). All are "nothing
# to run here", not a failure.
if [ "$code" -eq 0 ] || [ "$code" -eq 79 ] || [ "$code" -eq 65 ]; then
  exit 0
fi
exit "$code"
