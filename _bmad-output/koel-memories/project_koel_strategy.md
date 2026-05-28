---
name: project-koel-strategy
description: koel is a passion-driven, premium OSS Flutter/Dart SDK implementing the AG-UI agent-UI protocol — built for craft, not adoption metrics
metadata:
  type: project
---

`koel` is a standalone, independent OSS Flutter package family that implements the AG-UI agent-UI protocol. It is publishable to pub.dev and has zero coupling to any specific consumer codebase.

**Brand: `koel`** (Hindi for the singing cuckoo bird — distinctive, short, available across all `koel_*` variants on pub.dev, no trademark exposure). Package family: `koel_core`, `koel_http`, `koel_agno`, `koel_langgraph`, `koel_runtime`, `koel_flutter`, `koel_widgets`, `koel_devtools`, `koel_test`, plus a `koel` meta-package re-exporting the common surface.

**Design defaults driven by OSS positioning:**
- Package consumers are unknown — cannot assume Bloc, injectable, Freezed, Retrofit, or any one state mgmt.
- API must work across state-management choices (Bloc, Riverpod, GetX, Provider, plain `setState`).
- No coupling to any specific app or framework outside the AG-UI protocol stack.
- Semver and public API stability matter — every export is a long-term contract.
- Docs, examples, and a sample-app deliverable are required, not nice-to-haves.
- Reference comparables: `dio`, `graphql_flutter`, `langchain_dart`, `firebase_*`, `supabase_flutter`, `anthropic_sdk_dart`, the existing community `ag_ui` v0.1.0.

**OSS positioning philosophy** (user, 2026-05-27): *"hàng tốt thì user sẽ biết đến thôi"* — quality over discoverability. Do not optimize naming, README, or package boundaries for SEO / pub.dev score. Make the implementation excellent and let it earn its audience. The brand-new name `koel` was chosen explicitly over SEO-friendly names like `agui_*`. Marketing investment is acceptable cost for the right brand.

**Core motivation** (user, 2026-05-27): *"Mình build cái này vì đam mê và muốn đem lại cho cộng đồng 1 Flutter SDK AG UI tốt nhất, những thứ còn lại không quan trọng. Ví dụ không ai sử dụng hoặc không ai đóng góp thì mình cũng học được nhiều thứ."* This is a passion project, not a ROI/adoption optimization. Success criteria = craftsmanship and learning, NOT downloads, stars, contributors, or production usage. Risk-mitigation discussions should be reframed as "engineering hygiene" rather than "risk-avoidance" — mitigations live in the codebase because they're best practice, not because failure scenarios scare us.

**How to apply trade-offs:** Prioritize "the right way to build it" over "the safe way to ship it." Slow path to v1 is acceptable. Feature-completeness beats time-to-market. Code quality beats marketing reach. The user is not measuring this project by external metrics.

**Project scope boundary** (user, 2026-05-27): The koel project (repo, packages, docs, examples, fixtures) contains zero references to any specific consumer codebase or business domain. Example apps use generic chat scenarios — no securities/finance/Vietnamese-stock-market themes or any other domain branding. Any specific app consuming koel does so as a downstream OSS consumer, with all app-specific concerns wired at the app layer, not inside koel.

**Design DNA articulated during brainstorming:**

> *"Infra deep, business out. Modular by discipline, opinionated about cross-cutting craftsmanship, agnostic about everything else."*

- Deep on infra: interceptors (auth/retry/log), reducer, sealed error hierarchy, devtools, storage adapter
- Out of business: tool handler safety, UI rendering, domain rules, auxiliary REST endpoints
- Modular: 9 packages with clear single-responsibility boundaries
- Premium positioning: brand-new name, DevTools extension, time-travel replay, conformance test fixtures
- Forward-compatible: discriminated unions for protocol evolution, semver discipline, adapter interfaces

**Reference to original brainstorming output:** A full 20-idea design dataset was produced during the 2026-05-27 brainstorming session, covering public API shape, cross-cutting infrastructure, modular packaging, identity & branding, philosophy, and forward-compat strategy. That dataset (with concept + novelty rationale per idea, action checklist, and decision tree) lives in the source project's `_bmad-output/brainstorming/` folder and should be considered the authoritative design reference for koel v1.
