# `ag_ui` 0.1.0 — license-compatibility verification

Audit-trail artifact resolving **OQ-AGUI-License** (PRD §15) and gating the first
*published* `koel_core` README that credits the community `ag_ui` package
(F-H4 credit, F-I3 license hygiene). Story 9.8.

## Conclusion

The community **`ag_ui` 0.1.0** package is **MIT-licensed** — fully compatible
with koel's MIT (F-H5). The standard MIT permission grant allows the
inspired-by/credit acknowledgement koel ships with **no copyleft obligation** and
**no attribution requirement beyond** the courtesy credit already present in
`packages/koel_core/README.md`. **Cleared to publish.**

koel is a clean-slate rewrite that does **not** copy, fork, or depend on `ag_ui`
source — no package depends on `ag_ui` (verified: `grep -rn "ag_ui"
packages/*/pubspec.yaml` → no match). The credit is a courtesy acknowledgement of
the genre's first Dart attempt, not a derivative-work attribution; even so, MIT
would permit either.

## Evidence

Verified **2026-06-08**. `ag_ui` 0.1.0 is the latest (and only) published version
(released ~8 months prior).

| Source | URL | Finding |
|---|---|---|
| pub.dev package page | https://pub.dev/packages/ag_ui | License reported **MIT**; source repo `https://github.com/mattsp1290/ag-ui`; latest = 0.1.0 |
| pub.dev license tab (LICENSE bundled in the **published 0.1.0 archive** — the authoritative artifact) | https://pub.dev/packages/ag_ui/license | **MIT**, standard unmodified boilerplate; copyright line `Copyright (c) 2025` |
| Source-repo LICENSE (corroboration) | https://github.com/mattsp1290/ag-ui (`LICENSE`) | **MIT**, standard unmodified boilerplate; copyright line `Copyright (c) 2025` |

**Adversarial cross-check performed:** the LICENSE in the published 0.1.0 archive
(pub.dev license tab) was compared against the source-repo LICENSE — both are the
standard, unmodified MIT text and agree. The published archive is the
authoritative artifact for the credit decision; the repo corroborates it.

## Nuance (does not affect compatibility)

The upstream MIT copyright line reads **`Copyright (c) 2025`** with **no
copyright holder named** — an upstream quirk (typical MIT names a holder, e.g.
"Copyright (c) 2025 <Name>"). This omission is the upstream author's, does **not**
affect MIT-compatibility or koel's right to credit the package, and koel copies
no `ag_ui` code so no MIT notice-retention obligation attaches to koel.

## Cross-references

- PRD §15 `OQ-AGUI-License` — RESOLVED by this record.
- F-H4 (`koel_core` README credit to `ag_ui` 0.1.0); F-H5 (all packages MIT).
- `packages/koel_core/README.md` — finalized credit (the Story-1.6 "pending
  verification" note removed in Story 9.8).
- `../planning-artifacts/brand-reservation.md` — F-I3 release blockers (this is the second of the two).
