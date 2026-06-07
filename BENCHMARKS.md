# koel performance benchmarks

The regression-relative performance SLOs (NFR-1..NFR-5) that `perf-bench.yml`
enforces on every PR and push to `main`. Each is a `test/perf/*_bench.dart`
harness with a shared record-or-gate contract: it measures one metric, compares
it to a committed baseline captured **on the reference device**, and fails the CI
job if the metric regresses past the metric's band. This file is the contract —
the device, the metrics, the methodology, and the bands — not a marketing sheet.

## 1. Reference-device profile

| | |
|---|---|
| Runner | GitHub-hosted `ubuntu-latest` (the `perf-bench.yml` runner) |
| Toolchain | Flutter `3.44.0` / Dart `3.12.0` (`.tool-versions`, via `subosito/flutter-action@v2`) |
| Codegen | `melos run build` regenerates `koel_core`'s `*.freezed.dart` before the benches compile |
| Runners | `dart test --tags perf` (koel_core, koel_http) · `flutter test --tags perf` on `flutter_tester`, a host VM with `dart:io` (koel_flutter) |
| Invocation | `tool/perf/run_benchmarks.dart` (`melos run perf`), CWD = each bench's package root |

The reference device is defined as **this CI runner class**, because it is the
only device that runs the gate on every PR (PRD §10.1 mandates each SLO be
measured "on the CI reference device profile" but names no device; the
architecture puts `perf-bench.yml` on the standard CI runner).

### Shared-runner variance caveat (read before trusting an absolute number)

GitHub-hosted runners are **not a fixed CPU** — successive jobs land on different
hardware generations, and a job can be CPU-contended. So the *absolute* numbers
below are a snapshot of one runner instance; what the gate enforces is a
*relative* regression against a baseline captured on the same runner **class**.
Measured run-to-run, with **no code change**, on the reference device (Story 9.4
Task 5):

| metric | observed spread (no code change) |
|---|---|
| N-1 sse_parse | ~4.0–4.7 µs/event (~17%) |
| N-2 reducer | ~1.4–1.6 µs/event (~7–13%) |
| N-3 chat_session_memory (peak) | ~4.4–13.7 MB (~3×) |
| N-4 cold_start | ~37–69 µs (~22% typical, up to ~86% on a contended runner) |
| N-5 streaming_jank | ~2.55–3.16 ms (up to ~24%) |

The gate bands (below) are sized **above** each metric's observed shared-runner
variance, so the gate does not false-trip on runner jitter, while still biting a
real regression (an algorithmic change is many ×, not tens of %). The PRD's flat
"> 10%" is the default for a *fixed* reference device; on a shared runner it is
empirically too tight for these absolute-time metrics, so the bands are widened
and documented here rather than left to flake (a flaky gate is worthless). A
dedicated self-hosted fixed reference device — which would permit much tighter
bands — is a possible post-1.0 hardening, not a v1.0.0 blocker.

## 2. The five benchmarks

### N-1 — SSE parse throughput (NFR-1)

- **File:** [`packages/koel_http/test/perf/sse_parse_bench.dart`](packages/koel_http/test/perf/sse_parse_bench.dart)
- **Gated metric:** `p99_micros_per_event` (µs per event, lower is better)
- **Workload:** the richest synthesized fixture (`all_event_types`, every AG-UI
  event kind) framed as `data: <json>\n\n` and repeated to a multi-thousand-event
  stream; `SseParser.parse` drains it to completion. 50 warm-up sweeps, 300 timed
  sweeps; the p99 of the per-event time. Throughput (events/sec = `1e6 / µs`) is
  logged as the derived human figure.
- **v1.0.0 baseline:** `4.731` µs/event (≈ 211k events/sec) · **band: +50%**

### N-2 — Reducer fold (NFR-2)

- **File:** [`packages/koel_core/test/perf/reducer_bench.dart`](packages/koel_core/test/perf/reducer_bench.dart)
- **Gated metric:** `p99_micros_per_event` (µs per event, lower is better)
- **Workload:** `DefaultChatStateReducer.reduce` folded over the 28-event sweep
  (`test/event/full_event_sweep.jsonl`). 500 warm-up sweeps, 3000 timed sweeps;
  the p99 of the per-event time. A single `reduce` is sub-microsecond, so the
  fold is timed via `Stopwatch.elapsedTicks ÷ frequency` (fractional µs) — **not**
  `elapsedMicroseconds`, which floors the whole-sweep duration to an integer µs
  and could record `0.0` on fast hardware, silently disabling the gate.
- **v1.0.0 baseline:** `1.455` µs/event · **band: +50%**

### N-3 — Single-session memory footprint (NFR-3)

- **File:** [`packages/koel_flutter/test/perf/chat_session_memory_bench.dart`](packages/koel_flutter/test/perf/chat_session_memory_bench.dart)
- **Gated metric:** `peak_rss_growth_bytes` (bytes above the warmed floor, lower is better)
- **Workload:** drive a fresh `KoelClient → ChatSession → KoelChatController` to
  completion over a fixed, large streaming run (2000 content deltas + a tool-call
  round), repeatedly. 8 warm-up runs, then a GC settle to establish a stable
  post-warmup resident floor, then 150 measured runs tracking the **peak**
  `ProcessInfo.currentRss` above that floor.
- **Why peak, not a per-run delta:** a fully-disposed session retains ≈ 0, so the
  per-run RSS delta is dominated by GC timing — on Linux (which returns freed
  pages to the OS) the *median* per-run delta is even **negative**, which makes a
  multiplicative gate meaningless. The peak working-set growth is positive,
  MB-scale, and is exactly what a real leak inflates (a session that failed to
  release its history would climb the resident set run-over-run).
- **Band rationale (honest limits):** the peak swung ~4.4–13.7 MB (~3×) on the
  reference device from old-space GC nondeterminism. The **+300%** band clears
  that swing from the committed baseline while still biting a genuine multi-MB
  leak (tens of MB over the 150 runs). **Sub-MB footprint creep is below RSS
  resolution on a shared runner and is *not* claimed to be caught** — that needs
  a fixed device / heap-level instrumentation (post-1.0).
- **v1.0.0 baseline:** `10522624` bytes (≈ 10.0 MiB) · **band: +300%**

### N-4 — Client cold-start latency (NFR-4)

- **File:** [`packages/koel_core/test/perf/cold_start_bench.dart`](packages/koel_core/test/perf/cold_start_bench.dart)
- **Gated metric:** `p99_micros` (µs, lower is better)
- **Workload:** the interval from `KoelClient(...)` construction to a live
  `StreamSubscription` on the post-pipeline event stream, against an empty agent;
  a fresh client per iteration, disposed after each measurement. 300 warm-up, 3000
  timed; the p99.
- **Band rationale:** cold-start is a tiny absolute interval (~37 µs), so
  shared-runner CPU-generation variance dominates it (37–45 µs across normal jobs,
  69 µs on a contended runner — all with no code change). The **+100%** band is
  honest about a sub-50 µs metric's noise floor on a shared runner while still
  biting a doubled init path.
- **v1.0.0 baseline:** `37.0` µs · **band: +100%**

### N-5 — Streaming UI-thread work (NFR-5)

- **File:** [`packages/koel_flutter/test/perf/streaming_jank_bench.dart`](packages/koel_flutter/test/perf/streaming_jank_bench.dart)
- **Gated metric:** `p99_frame_micros` (µs of synchronous per-delta work, lower is better)
- **Workload:** a continuous fixed-length stream of `TEXT_MESSAGE_CONTENT` deltas
  driven through a `KoelChatController`-bound `AnimatedBuilder`; a fake clock
  advances exactly one frame per `pump`, so each `pump` folds one delta → notifies
  → rebuilds, and the `Stopwatch` captures that synchronous work. 50 warm-up, 500
  measured; the p99. The count of deltas exceeding the 16 ms frame budget is
  logged.
- **Synchronous-work proxy (not GPU raster):** `flutter_tester` has no real GPU,
  so this measures the **UI-thread work per event** that would consume a frame's
  budget — a deliberate host proxy. Literal real-device frame-raster timing during
  continuous streaming is the post-1.0 device matrix (AR-17), **not** covered here.
- **v1.0.0 baseline:** `2798.0` µs · **band: +50%**

## 3. Release artifacts

The five committed baseline JSONs are the **immutable v1.0.0 perf reference**:

- [`packages/koel_http/test/perf/baselines/sse_parse_bench.json`](packages/koel_http/test/perf/baselines/sse_parse_bench.json)
- [`packages/koel_core/test/perf/baselines/reducer_bench.json`](packages/koel_core/test/perf/baselines/reducer_bench.json)
- [`packages/koel_core/test/perf/baselines/cold_start_bench.json`](packages/koel_core/test/perf/baselines/cold_start_bench.json)
- [`packages/koel_flutter/test/perf/baselines/chat_session_memory_bench.json`](packages/koel_flutter/test/perf/baselines/chat_session_memory_bench.json)
- [`packages/koel_flutter/test/perf/baselines/streaming_jank_bench.json`](packages/koel_flutter/test/perf/baselines/streaming_jank_bench.json)

They are **designated as v1.0.0 GitHub release artifacts**: the v1.0.0 release
(Story 9.9) attaches these five files via `gh release upload`, so the published
numbers have a permanent release-asset URL alongside their committed repo path.
9.4 captures, commits, gates against, and designates them; the actual attachment
runs at publish (nothing is published pre-1.0).

## 4. How to run

```sh
melos run perf              # the gate: run all five under KOEL_PERF_GATE
melos run perf -- --update  # recapture all five baselines (KOEL_PERF_UPDATE)
```

Run a single bench directly (CWD = its package root, `--tags perf`):

```sh
cd packages/koel_core && dart test test/perf/reducer_bench.dart --tags perf
```

**Recapturing the v1.0.0 baselines on the reference device** (do not hand-edit the
JSONs — they must come from a real reference-device run): trigger the
`perf-bench.yml` **capture** lane (`workflow_dispatch`), which runs
`melos run perf -- --update` on `ubuntu-latest` and uploads the regenerated
baselines as the `perf-baselines-reference-device` build artifact. Download it and
commit the five JSONs in a reviewed PR (CI never auto-commits a baseline). This is
the mechanism a v1.x baseline refresh and the Story 9.9 publish both use.
