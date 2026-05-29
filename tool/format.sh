#!/usr/bin/env bash
# Format (or check) hand-written Dart across the workspace, excluding generated
# files (*.g.dart / *.freezed.dart / *.mocks.dart). Generated output is gitignored
# and already emitted in canonical form by build_runner, so the gate must never
# walk it — otherwise codegen churn can spuriously fail format:check (retro D2).
#
# Usage: tool/format.sh [check|write]   (default: write)
#
# Invoked from melos `format` / `format:check` via `run:` (root context) rather
# than `exec:` — melos `exec` interpolates `$(...)`/`$VAR` away, which would
# silently reduce the file list to empty and make the gate a no-op.
set -euo pipefail

mode="${1:-write}"

if [ "$mode" != "write" ] && [ "$mode" != "check" ]; then
  echo "format.sh: unknown mode '$mode' (expected 'write' or 'check')." >&2
  exit 2
fi

# Word-split is intentional and safe: no workspace Dart path contains spaces.
# (macOS ships bash 3.2 — no `mapfile` — so keep this POSIX-simple.)
files=$(
  find packages -name '*.dart' \
    ! -name '*.g.dart' ! -name '*.freezed.dart' ! -name '*.mocks.dart' \
    ! -path '*/.dart_tool/*' ! -path '*/build/*'
)

if [ -z "$files" ]; then
  echo "format.sh: no hand-written Dart files found." >&2
  exit 0
fi

if [ "$mode" = "check" ]; then
  # shellcheck disable=SC2086
  dart format --output=none --set-exit-if-changed $files
else
  # shellcheck disable=SC2086
  dart format $files
fi
