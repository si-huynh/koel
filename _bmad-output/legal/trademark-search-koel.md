# "koel" — trademark search audit trail

Audit-trail artifact for **OQ-Koel-Trademark** (PRD §15) and **F-I3** (trademark
hygiene), gating the v1.0.0 publish. Story 9.8.

## Scope

A brand conflict for an **SDK / developer tool** only arises in the relevant
goods/services classes:

- **Nice Class 9** — downloadable software / computer programs.
- **Nice Class 42** — software design & development, SaaS, computer services.

"koel" is a common word (the Asian koel, a cuckoo; also a given name and the
Indian brand **KOEL** = Kirloskar Oil Engines), so the registries carry many
marks in **unrelated** classes (engines, apparel, food, care products). Those are
**not** conflicts. This search targets Class 9 / Class 42.

## Status: ⚠️ OPEN — owner/counsel action required before v1.0.0 publish

The dev-agent automated search **could not complete an authoritative
registered-mark query** of Class 9/42 (the official portals are not
machine-accessible — see Limitations), and a **same-name open-source software
project** ("Koel", a music-streaming server) surfaced as a real naming/common-law
consideration. No *registered* software-class "koel" trademark was found in the
reachable sources, but absence-of-evidence here is **not** clearance. Final
go/no-go is the owner's legal call (P1), consistent with `brand-reservation.md`'s
provenance caveat (the pub.dev name reservation was likewise an out-of-band owner
act; "names were reserved ahead of clearance as an accepted squatting-protection
trade-off — slots are forfeit if trademark fails").

## Searches performed (2026-06-08)

| Registry | Portal | Outcome |
|---|---|---|
| **USPTO** | https://tmsearch.uspto.gov/ | Portal is a JS single-page app — returns no machine-readable results to automated fetch (header only). TSDR (https://tsdr.uspto.gov/) requires a known serial/registration number. **Not completable by the agent.** |
| **EUIPO** | https://euipo.europa.eu/eSearch/ | eSearch plus is a JS app behind a query form — not machine-fetchable. **Not completable by the agent.** |
| **India IP** | https://ipindiaonline.gov.in/tmrpublicsearch/ | Public search is a JS/form portal (CAPTCHA-gated) — not machine-fetchable. **Not completable by the agent.** |
| Aggregators (Trademarkia, Justia) | trademarkia.com, trademarks.justia.com | **HTTP 403** to automated fetch — block bots. **Not completable by the agent.** |
| Web search (corroboration only) | general web | Surfaced the landscape below; web search is **not** an authoritative trademark-register query. |

## Findings from reachable sources (corroborative, non-authoritative)

1. **Same-name software project — "Koel" (music-streaming server).** A
   well-known FOSS project named **Koel** exists in the software space
   (https://koel.dev, https://github.com/koel/koel, "Koel Player" on the Apple
   App Store). It surfaced **no trademark registration in reachable sources** and
   is a **different product domain** (self-hosted music streaming, not an AG-UI agent
   SDK), but the name collision *within software* is a genuine common-law /
   discoverability consideration the owner must weigh. **Not a registered-mark
   conflict on the evidence found, but flagged as the most material signal.**

2. **India — "KOEL" / "Koel Care" / "Koel xl mega" (Kirloskar Oil Engines Ltd).**
   Strong existing Indian brand, but in **engine / power-generation classes**
   (≈ Class 7), **not** software Class 9/42. **Not a conflict** for an SDK.

3. **USPTO / EUIPO Class 9 / 42 "koel" software mark.** **None surfaced** in
   reachable sources — but this reflects the agent's inability to query the
   authoritative registers, **not** a confirmed clean result.

## Method/scope note (honesty guard)

This is a **public registered-mark search attempt**, not legal clearance and not
a legal opinion. It does not cover: full common-law / unregistered use, phonetic
or design-mark equivalents, or counsel's risk assessment. Web search ≠ register
query. A confident "no Class 9/42 conflict" requires the authoritative-portal
searches, which only the owner (or counsel) can complete interactively.

## Recommended owner action before v1.0.0 publish (P1)

1. Run the three portal searches manually (USPTO `tmsearch.uspto.gov`, EUIPO
   `eSearch plus`, India IP public search), filtered to **Class 9 + Class 42**,
   and append the screenshots / serial numbers here as the authoritative record.
2. Weigh the **Koel music-app** name overlap (different domain, no registration
   found) for v1.0.0 brand risk — likely acceptable (distinct goods, no
   registration surfaced), but
   it is the owner's call to record.
3. On a clean authoritative result, flip **OQ-Koel-Trademark → RESOLVED** in
   PRD §15 (this story flips only `OQ-AGUI-License`, which cleared cleanly).

## Cross-references

- PRD §15 `OQ-Koel-Trademark` — remains **OPEN** (this record); blocks v1.0.0.
- F-I3 (trademark & license hygiene); F-H4 (brand & naming — "koel").
- `../planning-artifacts/brand-reservation.md` — F-I3 release blockers + owner-task provenance caveat.
- `_bmad-output/legal/ag_ui-license-verification.md` — the companion gate (CLEARED).
