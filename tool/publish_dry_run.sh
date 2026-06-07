#!/usr/bin/env bash
# tool/publish_dry_run.sh — per-package `dart pub publish --dry-run` gate for
# `melos run publish-dry` (Story 9.5, FR-I1 / PRD §12 R-5). Runs the dry-run once
# per v1.0.0 release package (CWD = the package root) and aggregates a single
# pass/fail with a per-package verdict line in the job log. Zero new dependency —
# a bash loop over the `dart` CLI already on PATH, mirroring tool/conformance.sh
# and tool/verify_versioning.sh.
#
# Strict by default (D3): `dart pub publish --dry-run` treats warnings as fatal
# (exit 65; `--ignore-warnings` → 0), so ANY publishability warning fails the
# gate — publish-readiness is not allowed to rot silently. Nine of the ten run
# strict; they must be 0-warning.
#
# koel_lints is the ONE documented exception (D4): it carries exactly two
# warnings that are MANDATED, not fixable. It runs with --ignore-warnings (real
# errors STILL block) AND the strict output is asserted to contain no warning
# beyond those two — so a NEW koel_lints warning still trips the gate:
#   1. `lib/main.dart` "name should match package" — lib/main.dart is the
#      analysis_server_plugin-MANDATED entrypoint (the analysis server generates
#      code importing lib/main.dart + its top-level `plugin` var); renaming it
#      breaks the plugin loader. Unfixable by rename.
#   2. `analysis_server_plugin` "constraint too tight" — the `0.3.14` exact pin
#      is the deliberate analyzer-12 stopgap (architecture D3 / SCP-2026-05-29-B /
#      AI-5.9); loosening it lets analyzer-13 in and re-opens the freezed↔asp
#      conflict the pin exists to prevent. Must NOT loosen.
#
# The ten == tool/verify_versioning.sh's release set (koel_devtools deferred
# post-1.0 per SCP-2026-06-06-B; the repo-root example/ is not a release pkg).
# Run LOCALLY from a CLEAN git tree: `dart pub publish --dry-run` warns on
# MODIFIED checked-in (tracked) files — NOT on untracked files — and the strict
# lane would (correctly) fail on that transient warning. CI runs on a clean
# checkout so it never fires there.
set -euo pipefail

root="${MELOS_ROOT_PATH:-$(cd "$(dirname "$0")/.." && pwd)}"
cd "$root"

release_pkgs="koel koel_core koel_http koel_lints koel_test \
koel_agno koel_langgraph koel_runtime koel_flutter koel_widgets"

# The two koel_lints warnings allowlisted in D4 — matched against the SPECIFIC
# warning phrasing (not the bare dependency name) so a THIRD, new warning that
# merely mentions analysis_server_plugin is never silently tolerated. Both
# substrings sit on pub's `* ` bullet line (verified, Dart 3.12.0):
#   "* The name of \"lib/main.dart\", \"main\", should match the name of the package…"
#   "* Your dependency on \"analysis_server_plugin\" should allow more than one version…"
lints_allow_1="should match the name of the package"
lints_allow_2="should allow more than one version"

fail=0

for pkg in $release_pkgs; do
  dir="packages/$pkg"

  if [ "$pkg" = "koel_lints" ]; then
    # Pass 1 — errors still block even with warnings ignored: a non-zero exit
    # here is a real publish ERROR, never one of the allowlisted warnings.
    if ! err=$(cd "$dir" && dart pub publish --dry-run --ignore-warnings 2>&1); then
      echo "publish-dry: FAIL — koel_lints has a real publish error (beyond the 2 allowlisted warnings):" >&2
      printf '%s\n' "$err" >&2
      fail=1
      continue
    fi
    # Pass 2 — strict, to enumerate the warnings; assert ONLY the two allowlisted
    # remain (a new warning's bullet would not match either substring).
    out=$(cd "$dir" && dart pub publish --dry-run 2>&1) || true
    unexpected=$(printf '%s\n' "$out" | grep -E '^\* ' | grep -vE "$lints_allow_1|$lints_allow_2" || true)
    # Cross-check pub's self-reported count ("Package has N warnings.") so a future
    # bullet-format change — which would make the grep above match nothing — can't
    # silently pass a NEW warning. Belt-and-suspenders against the substring match.
    warn_count=$(printf '%s\n' "$out" | sed -nE 's/^Package has ([0-9]+) warning.*/\1/p' | tail -1)
    if [ -n "$unexpected" ] || { [ -n "$warn_count" ] && [ "$warn_count" -gt 2 ]; }; then
      echo "publish-dry: FAIL — koel_lints emitted a warning OUTSIDE the 2-item D4 allowlist:" >&2
      [ -n "$unexpected" ] && printf '%s\n' "$unexpected" >&2
      { [ -n "$warn_count" ] && [ "$warn_count" -gt 2 ]; } && \
        echo "  (pub reports $warn_count warnings — the D4 allowlist permits at most 2)" >&2
      fail=1
    else
      echo "publish-dry: PASS — koel_lints (2 allowlisted warnings: asp lib/main.dart entrypoint + analyzer-12 pin)"
    fi
    continue
  fi

  # The other nine run STRICT: any warning → exit 65 → FAIL.
  if out=$(cd "$dir" && dart pub publish --dry-run 2>&1); then
    echo "publish-dry: PASS — $pkg (0 warnings)"
  else
    echo "publish-dry: FAIL — $pkg (dart pub publish --dry-run reported issues):" >&2
    printf '%s\n' "$out" >&2
    fail=1
  fi
done

if [ "$fail" -ne 0 ]; then
  echo "publish-dry: one or more packages failed the dry-run gate (see above)." >&2
  exit 1
fi
echo "publish-dry: OK — all 10 release packages pass dart pub publish --dry-run (9 strict 0-warning + koel_lints 2-item D4 allowlist)."
