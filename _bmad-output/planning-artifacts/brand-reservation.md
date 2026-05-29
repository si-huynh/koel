# Brand reservation — pub.dev slot names

Traceability artifact for FR-H4 (brand & naming) and FR-I3 (trademark / license
gates). Tracks the eleven pub.dev package names reserved to the owner account
ahead of koel's first publish.

Brand: **koel** — Hindi for the singing cuckoo. No `agui_*` / `copilotkit_*`
piggyback names.

**Status: all 11 names reserved on 2026-05-29** via `0.0.1-pre` prerelease
placeholders (prereleases are unlisted from pub.dev search) and transferred to
the verified publisher **sihuynh.dev**. The throwaway placeholder sources were
removed after publishing — pub.dev permanently retains the published archives, so
the local copies were vestigial. See Evidence below.

> **Provenance caveat (code review 2026-05-29).** Story 1.6's AC4 floor was to
> ship this artifact with `status: pending`; the actual reservation is **not a
> dev-agent deliverable** (the agent cannot authenticate and publish to pub.dev).
> The reservation recorded here was **performed out-of-band by the human owner
> (Si Huynh)** and exceeds the AC on purpose. Because the placeholder sources
> were deleted and never committed, **this record is not independently
> verifiable from the committed tree** — the Evidence below is the owner's
> attestation. Confirm the slots on pub.dev / the publisher dashboard before
> relying on them for the v1.0.0 publish.

## Names to reserve (11)

| # | pub.dev name | Kind | Reservation status |
| --- | --- | --- | --- |
| 1 | `koel` | meta-package | ✅ reserved — `0.0.1-pre` (2026-05-29) |
| 2 | `koel_core` | foundation | ✅ reserved — `0.0.1-pre` (2026-05-29) |
| 3 | `koel_http` | transport | ✅ reserved — `0.0.1-pre` (2026-05-29) |
| 4 | `koel_lints` | analyzer plugin | ✅ reserved — `0.0.1-pre` (2026-05-29) |
| 5 | `koel_agno` | backend bridge | ✅ reserved — `0.0.1-pre` (2026-05-29) |
| 6 | `koel_langgraph` | backend bridge | ✅ reserved — `0.0.1-pre` (2026-05-29) |
| 7 | `koel_runtime` | backend bridge | ✅ reserved — `0.0.1-pre` (2026-05-29) |
| 8 | `koel_flutter` | Flutter glue | ✅ reserved — `0.0.1-pre` (2026-05-29) |
| 9 | `koel_widgets` | UI primitives | ✅ reserved — `0.0.1-pre` (2026-05-29) |
| 10 | `koel_devtools` | DevTools extension | ✅ reserved — `0.0.1-pre` (2026-05-29) |
| 11 | `koel_test` | test harness | ✅ reserved — `0.0.1-pre` (2026-05-29) |

## Reservation mechanism

pub.dev has no "reserve without publishing" flow. A name is claimed by publishing
a package from an authenticated account. To reserve without surfacing the names
in search, each slot was claimed with a **`0.0.1-pre` prerelease** placeholder —
a package whose only versions are prereleases is automatically unlisted from
pub.dev default search (no `DISCONTINUED` badge). Each placeholder was a minimal
standalone Dart package (pubspec with `version: 0.0.1-pre` + LICENSE + README +
CHANGELOG + a stub `lib/<name>.dart`, no `koel_*` interdependencies and no
`publish_to: none`), kept outside `packages/` so the real dev tree was never
touched; each passed `dart pub publish --dry-run` with 0 warnings before publish.
The placeholder sources were deleted after reservation (pub.dev retains the
published archives; they are reproducible from this description if ever needed).

## Release blockers (FR-I3) — still open

The names are reserved, but two gates remain open and **must be cleared before
the real implemented packages publish at v1.0.0**:

- **OQ-Koel-Trademark** — trademark clearance on "koel" beyond pub.dev name
  availability. Blocks v1.0.0. Owner: project lead. *(Names were reserved ahead
  of clearance as an accepted squatting-protection trade-off; if trademark fails,
  the reserved slots are forfeit.)*
- **OQ-AGUI-License** — license-compatibility verification of the community
  `ag_ui` 0.1.0 package, gating the first *published* README that credits it
  (the credit stub is in `packages/koel_core/README.md`). Cleared in Epic 9.

## Follow-ups (Epic 9 publish prep)

- ~~Transfer each package to the verified publisher~~ — **DONE 2026-05-29**: all
  11 transferred to publisher **sihuynh.dev**.
- Replace the `0.0.1-pre` placeholders with the real implemented packages at the
  v1.0.0 lock-step publish (Story 9.5 dry-run → 9.9 publish).
- Prereleases auto-retract is not needed; the real `1.0.0` stable release will
  supersede `0.0.1-pre` and make each package listed in search.

## Evidence

All eleven uploads returned `Successfully uploaded https://pub.dev/packages/<name>
version 0.0.1-pre` from the pub.dev server on 2026-05-29:

| pub.dev page | Version |
| --- | --- |
| https://pub.dev/packages/koel | 0.0.1-pre |
| https://pub.dev/packages/koel_core | 0.0.1-pre |
| https://pub.dev/packages/koel_http | 0.0.1-pre |
| https://pub.dev/packages/koel_lints | 0.0.1-pre |
| https://pub.dev/packages/koel_agno | 0.0.1-pre |
| https://pub.dev/packages/koel_langgraph | 0.0.1-pre |
| https://pub.dev/packages/koel_runtime | 0.0.1-pre |
| https://pub.dev/packages/koel_flutter | 0.0.1-pre |
| https://pub.dev/packages/koel_widgets | 0.0.1-pre |
| https://pub.dev/packages/koel_devtools | 0.0.1-pre |
| https://pub.dev/packages/koel_test | 0.0.1-pre |

(Pages may take up to ~10 minutes to appear after upload. Owner may attach
account-side screenshots here if a stronger receipt is wanted.)
