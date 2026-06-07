#!/usr/bin/env bash
# tool/docs.sh — per-package `dart doc` BUILD gate for `melos run docs`
# (Story 9.6, FR-H6 / NFR-16). Runs `dart doc` once per v1.0.0 release package
# (CWD = the package root) and aggregates a single pass/fail with a per-package
# verdict line. Zero new dependency — a bash loop over the `dart` CLI already on
# PATH, mirroring tool/conformance.sh and tool/publish_dry_run.sh.
#
# Why a BUILD gate on top of the already-green analyze doc lint: the
# `public_member_api_docs: true` lint (green since 2.15 / 6.8 / 7.4) catches
# MISSING doc comments, but only the `dart doc` BUILD additionally surfaces
# broken `[reference]` links and malformed `///` example blocks that analyze
# passes. The 7.4 precedent hit exactly this: two `[MessageBubble]`
# comment_references that analyze accepted had to be demoted to code-spans
# because the build flagged them. NFR-16 ("per-package `dart doc` builds
# cleanly") requires the build, not just the lint.
#
# dart doc returns a non-zero exit on hard errors, but emits LINK/EXAMPLE
# problems as "warnings" while still exiting 0 — so an exit-code-only check is a
# silent no-op. We parse dart doc's own self-reported summary line
# ("Found N warnings and M errors.") and FAIL the gate unless BOTH are zero.
# This is the same self-reported-count cross-check publish_dry_run.sh uses, and
# the reason the Task-4 negative bite-check (a `[BrokenRef]` → warning → FAIL)
# actually trips.
#
# The ten == tool/verify_versioning.sh / tool/publish_dry_run.sh's release set.
# koel_devtools is EXCLUDED: it is post-1.0 (Epic 10), version 0.0.1,
# publish_to: none, and its `public_member_api_docs` doc gate is deliberately
# NOT enabled — running the build gate against it would be wrong.
set -euo pipefail

root="${MELOS_ROOT_PATH:-$(cd "$(dirname "$0")/.." && pwd)}"
cd "$root"

release_pkgs="koel koel_core koel_http koel_lints koel_test \
koel_agno koel_langgraph koel_runtime koel_flutter koel_widgets"

# dart doc output is a throwaway HTML tree — park it under .dart_tool (gitignored)
# so the build never pollutes the working tree or pubspec.lock.
out_root="$root/.dart_tool/koel_doc_build"

fail=0

for pkg in $release_pkgs; do
  dir="packages/$pkg"

  if out=$(cd "$dir" && dart doc --output "$out_root/$pkg" 2>&1); then
    # Exit 0 — but dart doc still reports link/example problems as "warnings"
    # while exiting 0, so parse the self-reported summary and require both 0.
    summary=$(printf '%s\n' "$out" | grep -E 'Found [0-9]+ warning.* and [0-9]+ error' | tail -1)
    warns=$(printf '%s\n' "$summary" | sed -nE 's/.*Found ([0-9]+) warning.* and [0-9]+ error.*/\1/p')
    errs=$(printf '%s\n' "$summary" | sed -nE 's/.*Found [0-9]+ warning.* and ([0-9]+) error.*/\1/p')
    if [ -n "${warns:-}" ] && [ "$warns" -eq 0 ] && [ -n "${errs:-}" ] && [ "$errs" -eq 0 ]; then
      echo "docs: PASS — $pkg (dart doc built clean: 0 warnings, 0 errors)"
    else
      echo "docs: FAIL — $pkg (dart doc reported ${warns:-?} warning(s) / ${errs:-?} error(s)):" >&2
      printf '%s\n' "$out" | grep -iE 'warning|error|unresolved|no library' >&2 || true
      fail=1
    fi
  else
    echo "docs: FAIL — $pkg (dart doc exited non-zero):" >&2
    printf '%s\n' "$out" >&2
    fail=1
  fi
done

if [ "$fail" -ne 0 ]; then
  echo "docs: one or more packages failed the dart doc build gate (see above)." >&2
  exit 1
fi
echo "docs: OK — all 10 release packages build clean under dart doc (0 warnings, 0 errors; NFR-16)."
