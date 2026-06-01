#!/usr/bin/env bash
# Per-package coverage gate for `melos run test:coverage`. Generalizes the inline
# koel_core block (Story 2.15) so every finalized package checks its own NFR-12
# tier with one shared script (the repo already factors tool/format.sh /
# tool/test_package.sh this way).
#
# Usage: tool/coverage.sh <package-path> <min-line%> <min-branch%> [with_chrome]
#   e.g. tool/coverage.sh packages/koel_core 90 90
#        tool/coverage.sh packages/koel_test 80 80
#        tool/coverage.sh packages/koel_http 90 90 with_chrome
#
# Generated files are excluded via the package's coverage_options.yaml, honored
# by format_coverage's --check-ignore. Perf benches are excluded by tag.
#
# The optional 4th arg `with_chrome` (Story 4.10) adds a headless-Chrome coverage
# pass — for koel_http, whose web transport (web_transport.dart) is selected by a
# conditional import and is NEVER loaded on the VM, so a VM-only pass reports it
# as 0% and sinks the gate. The browser `@TestOn('browser')` suite covers it for
# real. Merge mechanics (the part that is NOT a naive concat):
#   * The two passes are formatted into SEPARATE lcov files. A file loaded on
#     BOTH platforms (e.g. an interceptor the browser test imports transitively
#     but whose own tests are `@TestOn('vm')`) appears in both — covered on the
#     VM, 0% on Chrome — and the per-platform line tables differ, so format_
#     coverage cannot union them. Concatenating + summing would double-count the
#     file and let the 0%-on-Chrome phantom tank the number.
#   * LINE coverage therefore dedups per source file, keeping the record with the
#     MOST hit lines — i.e. the platform that actually exercised the file (Chrome
#     for web_transport.dart, the VM for everything else). Union of real
#     coverage, no phantom misses.
#   * BRANCH coverage comes from the VM pass ONLY (`--branch-coverage` is a
#     VM-only flag; Chrome coverage is line-only), so the branch gate stays
#     scoped to the VM-coverable surface, exactly as intended.
set -euo pipefail

pkg="${1:?usage: coverage.sh <package-path> <min-line%> <min-branch%> [with_chrome]}"
min_line="${2:?missing <min-line%>}"
min_branch="${3:?missing <min-branch%>}"
with_chrome="${4:-}"

cd "$pkg"
rm -rf coverage coverage_chrome
dart test --exclude-tags=perf --coverage=coverage --branch-coverage
format_coverage --lcov --in=coverage --out=coverage/lcov.info --report-on=lib --check-ignore

# `line_lcov` holds the records the LINE gate dedups over; `branch_lcov` is always
# the VM pass (the only one with BRDA rows). Without with_chrome they are the same
# file, so koel_core/koel_test are byte-for-byte unaffected.
line_lcov=coverage/lcov.info
branch_lcov=coverage/lcov.info
if [ "$with_chrome" = "with_chrome" ]; then
  dart test -p chrome --exclude-tags=perf --coverage=coverage_chrome
  format_coverage --lcov --in=coverage_chrome --out=coverage_chrome/lcov.info --report-on=lib --check-ignore
  line_lcov=coverage/merged.info
  cat coverage/lcov.info coverage_chrome/lcov.info > "$line_lcov"
fi

# LINE: dedup per SF keeping the max-hit record (drops the 0%-on-the-other-platform
# phantom); BRANCH: sum BRDA from the VM lcov only. Thresholds via -v so the same
# body serves every tier; branch=100 when a package emits no BRDA rows.
awk -F: -v pkg="$pkg" -v minl="$min_line" -v minb="$min_branch" \
  -v branch_lcov="$branch_lcov" '
  # --- line pass: first FILE arg (the line lcov, possibly merged) ---
  FNR==NR{
    if($1=="SF"){file=$2; rlf=0; rlh=0}
    else if($1=="LF"){rlf=$2}
    else if($1=="LH"){rlh=$2}
    else if($0=="end_of_record" && (!(file in seen) || rlh>blh[file])){
      blf[file]=rlf; blh[file]=rlh; seen[file]=1
    }
    next
  }
  # --- branch pass: the VM lcov (second FILE arg) ---
  $1=="BRDA"{split($2,a,","); brf++; if(a[4]!="-" && a[4]+0>0) brh++}
  END{
    for(f in seen){lf+=blf[f]; lh+=blh[f]}
    line=(lf>0)?100*lh/lf:0; branch=(brf>0)?100*brh/brf:100;
    printf("%s coverage — line=%.2f%% (%d/%d) branch=%.2f%% (%d/%d)\n",pkg,line,lh,lf,branch,brh,brf);
    if(line<minl){printf("FAIL: %s line coverage %.2f%% < %d%% (NFR-12)\n",pkg,line,minl); exit 1}
    if(branch<minb){printf("FAIL: %s branch coverage %.2f%% < %d%% (NFR-12)\n",pkg,branch,minb); exit 1}
  }' "$line_lcov" "$branch_lcov"
