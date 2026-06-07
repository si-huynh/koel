#!/usr/bin/env bash
# Hybrid-versioning convention gate for `melos run verify:versioning` (Story 9.1,
# FR-H2 / PRD §12 R-2..R-3). Asserts the v1.0.0 release set obeys three rules and
# exits non-zero with a clear message on any violation. bash + awk, zero new
# dependency — mirrors tool/format.sh / tool/coverage.sh.
#
# The TEN release packages are checked; koel_devtools (Epic 10, post-1.0) and the
# koel_widgets/example app are deliberately EXCLUDED — they are not in the v1.0.0
# lock-step and may keep bare workspace keys at 0.0.1 (proven to resolve fine
# against 1.0.0 siblings — Story 9.1 D2).
#
# Rules:
#   1. Lock-step (R-2): koel_core, koel_http, koel_lints carry an IDENTICAL
#      `version:` string.
#   2. Ranged, not pinned, not bare (FR-H2/R-3): every intra-repo dependency
#      (a key named `koel` or `koel_*`) under `dependencies:`/`dev_dependencies:`
#      has a value matching `^X.Y.Z`. Bare keys and tight pins (`1.0.0`) fail.
#   3. koel_lints is never runtime (AC2/FR-H3): it appears only under
#      `dev_dependencies:`, never `dependencies:`.
set -euo pipefail

root="${MELOS_ROOT_PATH:-$(cd "$(dirname "$0")/.." && pwd)}"
cd "$root"

release_pkgs="koel koel_core koel_http koel_lints koel_test \
koel_agno koel_langgraph koel_runtime koel_flutter koel_widgets"

fail=0

# --- Rule 1: foundation lock-step versions (R-2) ---
ver() { grep -m1 -E '^version:' "packages/$1/pubspec.yaml" | sed 's/^version:[[:space:]]*//'; }
core_v=$(ver koel_core); http_v=$(ver koel_http); lints_v=$(ver koel_lints)
if [ "$core_v" != "$http_v" ] || [ "$core_v" != "$lints_v" ]; then
  echo "verify_versioning: FAIL — foundation lock-step broken (R-2): koel_core=$core_v koel_http=$http_v koel_lints=$lints_v (must be identical)" >&2
  fail=1
fi

# --- Rules 2 & 3: per-package intra-repo dep ranges + lints-never-runtime ---
# Section-aware scan: a column-0 key (`dependencies:`/`dev_dependencies:`/other)
# sets the active section; a 2-space-indented `koel`/`koel_*` key inside a deps
# section is an intra-repo edge whose value is then validated. Block-form deps
# (`flutter:` + `sdk: flutter`) never match the koel-prefixed key regex.
for pkg in $release_pkgs; do
  awk -v pkg="$pkg" '
    /^[A-Za-z_]+:/ {
      if ($1 == "dependencies:") section="runtime";
      else if ($1 == "dev_dependencies:") section="dev";
      else section="";
      next
    }
    section != "" && /^[[:space:]]+koel(_[a-z]+)?:/ {
      line=$0; sub(/[[:space:]]*#.*/, "", line)
      key=line; sub(/:.*/, "", key); gsub(/[[:space:]]/, "", key)
      val=line; sub(/^[^:]*:[[:space:]]*/, "", val); gsub(/[[:space:]]/, "", val)
      if (key == "koel_lints" && section == "runtime") {
        printf("verify_versioning: FAIL — %s: koel_lints is a RUNTIME dependency (must be dev-only, AC2/FR-H3)\n", pkg) > "/dev/stderr"; rc=1
      }
      if (val == "") {
        printf("verify_versioning: FAIL — %s: intra-repo dep `%s` is a BARE key (must be ^X.Y.Z, FR-H2)\n", pkg, key) > "/dev/stderr"; rc=1
      } else if (val !~ /^\^[0-9]+\.[0-9]+\.[0-9]+$/) {
        printf("verify_versioning: FAIL — %s: intra-repo dep `%s: %s` is not a caret range (pin/bare, must be ^X.Y.Z)\n", pkg, key, val) > "/dev/stderr"; rc=1
      }
    }
    END { exit rc+0 }
  ' "packages/$pkg/pubspec.yaml" || fail=1
done

if [ "$fail" -ne 0 ]; then
  echo "verify_versioning: versioning convention violated (see failures above)." >&2
  exit 1
fi
echo "verify_versioning: OK — foundation lock-step ($core_v) + ranged intra-repo deps across 10 release packages + koel_lints dev-only."
