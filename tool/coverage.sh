#!/usr/bin/env bash
# Per-package coverage gate for `melos run test:coverage`. Generalizes the inline
# koel_core block (Story 2.15) so every finalized package checks its own NFR-12
# tier with one shared script (the repo already factors tool/format.sh /
# tool/test_package.sh this way).
#
# Usage: tool/coverage.sh <package-path> <min-line%> <min-branch%>
#   e.g. tool/coverage.sh packages/koel_core 90 90
#        tool/coverage.sh packages/koel_test 80 80
#
# Generated files are excluded via the package's coverage_options.yaml, honored
# by format_coverage's --check-ignore. Perf benches are excluded by tag.
set -euo pipefail

pkg="${1:?usage: coverage.sh <package-path> <min-line%> <min-branch%>}"
min_line="${2:?missing <min-line%>}"
min_branch="${3:?missing <min-branch%>}"

cd "$pkg"
dart test --exclude-tags=perf --coverage=coverage --branch-coverage
format_coverage --lcov --in=coverage --out=coverage/lcov.info --report-on=lib --check-ignore

# awk reads thresholds via -v so the same body serves every tier. branch=100
# when a package emits no BRDA rows (no branches to miss is not a failure).
awk -F: -v pkg="$pkg" -v minl="$min_line" -v minb="$min_branch" '
  /^LF:/{lf+=$2} /^LH:/{lh+=$2}
  /^BRDA:/{split($2,a,","); brf++; if(a[4]!="-" && a[4]+0>0) brh++}
  END{
    line=(lf>0)?100*lh/lf:0; branch=(brf>0)?100*brh/brf:100;
    printf("%s coverage — line=%.2f%% (%d/%d) branch=%.2f%% (%d/%d)\n",pkg,line,lh,lf,branch,brh,brf);
    if(line<minl){printf("FAIL: %s line coverage %.2f%% < %d%% (NFR-12)\n",pkg,line,minl); exit 1}
    if(branch<minb){printf("FAIL: %s branch coverage %.2f%% < %d%% (NFR-12)\n",pkg,branch,minb); exit 1}
  }' coverage/lcov.info
