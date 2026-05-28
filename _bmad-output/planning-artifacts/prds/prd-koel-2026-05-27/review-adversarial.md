---
title: koel v1 PRD — Adversarial Review
status: draft
created: 2026-05-27
reviewer: cynical-reviewer-agent
scope: prd.md + addendum.md + .decision-log.md
---

# Adversarial Review — koel v1 PRD

This review takes the PRD at its word and then puts pressure on every claim. The PRD is well-written and disciplined; the findings below are about the places where good prose is doing work that the underlying specification has not yet earned. The "no deadline" stance softens some risks (you can grind through hard problems), but it does not soften the claims about *what v1 means* — the bar set in §5.1 has to actually be reachable, and several pieces of it are currently aspirational rather than specified.

Severity legend:
- **Critical** — claim is load-bearing for v1 success and the mechanism is hand-waved or self-contradicting. Without resolution, v1 cannot ship truthfully.
- **High** — claim looks reasonable but contains an unspecified hard subproblem, a hidden coupling, or an aspirational number. Likely to bite during implementation.
- **Medium** — soft spot in framing or test mechanism; needs sharpening but not architecturally fatal.
- **Low** — stylistic / wording issues that weaken the document's rigor.

---

## Critical Findings

### C-1. "100% AG-UI protocol conformance" has no anchor

**PRD claim.** §5.1 SC-1: *"100% AG-UI protocol conformance — every event in the captured fixture suite (3 backends × all event types) round-trips through `koel_core` + `koel_http` + adapter packages without loss."* Also §6.1 ("conformance verified against captured fixtures from three backends") and §F-G4 ("Conformance Test Suite").

**Cynical read.** This is conformance theater unless three things are pinned:
1. **Spec version.** "AG-UI" is described as a moving target (§11 says "AG-UI has no version negotiation, no version header, and no deprecation policy"). §F-A7 mentions "release/2026-05-26 baseline" once, in passing, inside the feature description — that is not promoted to the success criterion. SC-1 should reference an exact upstream commit / tag.
2. **Test mechanism.** "Round-trips without loss" is undefined. Round-trip of what — wire bytes? typed events? a normalized canonical form? If wire bytes, byte-equality across all 28 event types is nearly impossible because of `freezed`'s JSON serializer choices (field ordering, optional-field omission). If typed events, this only proves the parser handles what the parser produced — circular.
3. **Fixture truth.** Fixtures are captured *from* AG-UI dojo, agno, langgraph. If those three backends emit a non-spec-compliant variant, koel "conforms" to bug-for-bug rather than to spec. Addendum H.7 acknowledges no formal conformance suite exists in any language — meaning koel's fixtures *are* the de facto spec. That's not conformance; that's compatibility with three reference implementations.

**Sharper version.** SC-1 should read: *"Against AG-UI TypeScript SDK at commit `<SHA>` and spec doc at commit `<SHA>`: (a) every event type in the typed enumeration is exercised by ≥1 fixture from each backend that emits it; (b) the round-trip is `bytes → AgUiEvent → bytes_canonical` where `bytes_canonical` is `json.encode(event.toJson())` and we assert that `bytes_canonical` re-parses to the structurally-equal event (idempotent under one round-trip, not byte-equal to wire); (c) any event type the spec defines that no backend emits is exercised via a hand-crafted golden fixture."* Drop the word "conformance" until the bar above is met; until then it is "fixture round-trip parity."

### C-2. "Zero breaking changes in 1.x" + "AG-UI has no version negotiation" are in direct tension

**PRD claim.** §5.1 SC-4: *"Zero breaking changes to 1.x public surface after v1.0.0 publish."* §11 FC-2: *"Adding a new AG-UI event type to `koel_core` is a minor version bump… Consumers writing exhaustive `switch` statements on `AgUiEvent` would not be source-compatible across minor versions if they don't include `case UnknownAgUiEvent()`; this is documented in the migration guide."*

**Cynical read.** A sealed class is a closed set. Adding a subtype to a sealed class **is** a breaking change for any exhaustive switch, full stop. The PRD acknowledges this in FC-2 ("would not be source-compatible…") and then quietly classifies it as minor anyway, on the basis that "documented" makes it okay. It doesn't. SC-4 says *zero* breaking changes; FC-2 says "minor bumps will break exhaustive switches." These are mutually exclusive under any honest reading of Dart 3 sealed semantics. The escape hatch "include `case UnknownAgUiEvent()`" only works if the consumer wrote that case *and* if `UnknownAgUiEvent` is the only new subtype. The moment koel adds a typed `ReasoningStreamEvent` (because AG-UI did), an exhaustive switch that fell through `UnknownAgUiEvent` previously now hits a new typed subtype that the consumer didn't write a case for — that's a compile error in 1.x. This is the AG-UI spec's instability bleeding directly into koel's semver promise. The PRD has not chosen a side.

**Sharper version.** Pick one:
- **(a)** Drop sealed in favor of an enum + a sentinel `unknown` plus an extensible discriminator. Lose compile-time exhaustiveness, keep semver honesty.
- **(b)** Keep sealed and explicitly state: *"Adding event subtypes is a major version bump. koel's major version will track AG-UI's event-set growth; expect 2.0, 3.0 within the first 18 months."* This contradicts SC-4 — rewrite SC-4 to *"Zero breaking changes within a single 1.x.y line; AG-UI event-set additions trigger major bumps."*
- **(c)** Make the sealed family non-exhaustive via a documented "you must write `default:` or `case UnknownAgUiEvent _:`" idiom that koel actually enforces with a lint rule shipped in `koel_core/lib/lints/`. Then SC-4 holds *if and only if* consumers used the idiom.

Currently the PRD has option (c) in spirit but is calling it option (a) on the tin. Pick.

### C-3. `koel_runtime` GraphQL bridge is treated as peer to `koel_http`; it is not

**PRD claim.** §6.1: *"Both transports production-grade: SSE-over-HTTP (`koel_http`) and GraphQL-bridge-over-CopilotKit-Next.js-runtime (`koel_runtime`)."* §A.5 shows ~10 lines of API signature.

**Cynical read.** `koel_runtime` is one paragraph in §F-C3 and ~10 lines in the addendum. Behind that paragraph is:
- Implementing a streaming GraphQL client over `multipart/mixed` or `text/event-stream` (CopilotKit Next.js runtime uses streaming GraphQL, which is itself underspecified; the GraphQL-over-SSE convention is not standardized).
- A bidirectional translator from AG-UI's ~28 event types to/from CopilotKit's `generateCopilotResponse` GraphQL schema, which has its own message-typing, its own `actions` shape, its own state-sync mechanism that does *not* use RFC 6902 JSON Patch.
- Independent dependency on `package:graphql` (or "equivalent" — the PRD waves this off), which has its own SSE/streaming story that is not equivalent to `koel_http`'s.
- Conformance fixtures for this transport are not mentioned in F-G1 — fixtures are explicitly captured from dojo + agno + langgraph, all of which are AG-UI-native SSE. The CopilotKit Next.js runtime is not in the fixture set. So `koel_runtime` ships v1 with **zero captured conformance fixtures**.

The decision log shows the user pushed back against research advice to "skip GraphQL hop," and the PRD followed the user. That is a fine product decision, but the PRD is now treating `koel_runtime` as if it were the cheap sibling of `koel_http`. It is roughly equal in scope to `koel_core` + `koel_http` combined, because it is a second protocol stack pretending to be a transport adapter.

**Sharper version.** Either:
- Add `koel_runtime` to the lock-step foundations and call out that it is a separate protocol implementation, not "just another transport." Add a dedicated CopilotKit Next.js runtime fixture capture (4th source) to F-G1. Acknowledge the dependency on streaming-GraphQL conventions and pin which convention (`graphql-sse` vs `multipart/mixed`).
- Or move `koel_runtime` to v1.1 / v2 with a paragraph explaining that v1's "two production transports" is one transport plus a Next.js runtime adapter that is staged for v1.x.

The current framing implies these are symmetrical; they are not.

### C-4. The 4-stage pipeline + interceptor chain + AgentSubscriber overlap is unspecified

**PRD claim.** §F-A11 (4-stage pipeline: verify → chunks → apply → transform), §F-A4 (interceptor chain wrapping `Future<Stream<AgUiEvent>>`), §F-A10 (AgentSubscriber callbacks). Three event-observation mechanisms.

**Cynical read.** A consumer writing a logging concern now has *three* places to put it: as an `Interceptor`, as a `transform` stage, or as an `AgentSubscriber`. The PRD does not specify:
- **Order.** Does an interceptor see events before or after the 4-stage pipeline? §C.1 in addendum says the pipeline is `events.transform(verify).transform(chunks).transform(apply).transform(transform)` — but where does the interceptor chain sit relative to this? Interceptors wrap `RunAgentInput → Stream<AgUiEvent>`, so they see the stream *before* the pipeline runs (assuming pipeline is consumer-side). But that means `LoggingInterceptor` logs *pre-verify* events; if `verify` rejects an event, the interceptor already logged it. Inverted reasoning works equally; the PRD has not chosen.
- **Subscriber timing.** AgentSubscriber callbacks fire when, relative to interceptors and pipeline? If pre-pipeline, subscribers receive malformed events. If post-pipeline, devtools (a subscriber) cannot show invalid-event diagnostics — which the devtools network panel ostensibly should.
- **Idempotency.** Interceptors that retry (RetryInterceptor) re-execute the entire pipeline downstream of them. Does the AgentSubscriber fire twice on a retried run? Once per attempt? The PRD does not say.

This is a hidden coupling problem: three concepts presented as orthogonal observation hooks that are actually entangled at the pipeline-positioning level.

**Sharper version.** Add a sub-section in §7 or §C.1 that draws the full request lifecycle as a sequence:

```
RunAgentInput
  → Interceptor[0..N].intercept (each may short-circuit)
    → HttpAgent.run (network I/O)
      → SseParser (raw bytes → AgUiEvent)
        → verify → chunks → apply → transform
          → AgentSubscriber.on* callbacks (post-pipeline)
            → Stream<AgUiEvent> to consumer
```

And then explicitly nail: retries re-execute starting from where; subscribers see N events or N×retries events; interceptors are "outside" the pipeline (operate on the whole stream as a unit) while transforms are "inside" the pipeline (operate per-event). Until this sequence is in the PRD, the three concepts are pseudo-orthogonal — each one's design assumes the others' boundaries that have not been drawn.

### C-5. Time-travel replay safety is built on a flag, called "production-grade," and OQ-Replay-Side-Effects is the actual unresolved decision

**PRD claim.** §F-F3 ("Time-Travel Replay"), §F-F7 ("Replay Safety Semantics"). §C.3 in addendum describes the `ToolReplayContext` flag mechanism.

**Cynical read.** The replay safety model is:
- Replay re-applies events through the reducer (fine, reducer is pure).
- Replay does not re-execute tool handlers (fine in principle).
- Tool handlers that have side effects should check `ToolReplayContext.of(context).isReplaying` and no-op.

This is "we trust the consumer to know they're in replay." Every tool handler in the wild that does not check the flag will execute its side effect during replay. This includes the consumer's own code, the WidgetResolver-driven generative UI handlers, and anyone using koel via Bloc/Riverpod whose state mutations are routed through normal `notifyListeners` paths. The reducer is pure but the *application* is not — Riverpod providers, ChangeNotifier listeners, async StreamSubscriptions all fire during replay, and many of them have observable effects (network requests, analytics events, file I/O).

§15 lists this as OQ-Replay-Side-Effects: "Whether tool-handler side effects need a stronger isolation guarantee than the `replayed: true` flag." This is described as resolvable "during `koel_devtools` v1 implementation; affects DevTools time-travel semantics but not the core protocol." That is wrong on two counts:
1. It affects the WidgetResolver contract — generative UI widgets are rebuilt during replay, and if any of them are stateful or have effects, replay is unsafe. Architecture-level.
2. It affects whether `koel_devtools` can ship "production-grade time-travel" at all. If the answer is "we need an isolate-sandboxed replay path," that's a substantial implementation effort buried inside what currently reads like a v1 nice-to-have.

This is the classic "avoided hard problem" pattern: a feature listed as in-scope is gated on an open question that the PRD claims is non-blocking.

**Sharper version.** Either:
- Promote OQ-Replay-Side-Effects to a v1 ship gate. Resolve it before locking the F-F3 / F-F7 contract.
- Reframe time-travel replay as **state-replay only, not effect-replay.** The DevTools UI shows the reducer's state at each event; widgets are not rebuilt; the consumer app is paused while replay is active. This is much easier to ship truthfully but is a smaller feature than what the PRD describes.

Either way, the current text claims production-grade time-travel for a model that has known unsafety the PRD then asks the reader to ignore.

---

## High Findings

### H-1. Performance NFRs (N-1 through N-5) are all `[ASSUMPTION]` with no measurement methodology

**PRD claim.** §10.1: 10,000 events/sec SSE parse, <1ms p99 reducer, <50MB memory, <100ms cold-start, all on a "Pixel 4a class" reference device.

**Cynical read.** Every single number is tagged `[ASSUMPTION]`, which is honest, but the PRD does not say:
- How the measurement is performed (synthetic benchmark, real-fixture replay, end-to-end test app).
- Whether the numbers include or exclude `freezed`'s JSON deserialization, which dominates parser cost.
- What "single-stream" means at 10,000 events/sec — that is 100 microseconds per event for the full parse pipeline. On a Pixel 4a (Snapdragon 730G, 2.2GHz mid-range), 100µs is about 220k CPU cycles. The parse pipeline must do: SSE chunk reassembly, UTF-8 decode, `json.decode` (allocates a `Map<String, dynamic>`), `freezed.fromJson` (allocates the typed event, possibly with nested freezed children), then pipeline transforms. 220k cycles is tight for that on a mid-range ARM core.
- Reducer p99 <1ms includes the cost of constructing a new immutable `ChatState` with rebuilt `List<Message>` — addendum §F.3 explicitly mandates "rebuild lists each call" for Riverpod-friendliness. A chat with 1000 messages rebuilds a 1000-element list per event. At 10,000 events/sec that's ten million list copies per second. The numbers do not square.

The PRD acknowledges these are assumptions, but they are also load-bearing claims for the "premium production-grade" positioning. "Assumed-aspirational" is not a substitute for "measured."

**Sharper version.** Replace the absolute numbers with:
- A reference benchmark suite (`koel_http/test/perf/` is already mentioned — make it the source of truth).
- An NFR like "parse throughput must not regress more than 10% PR-over-PR" (regression-relative, not absolute).
- A single end-to-end SLO: "On the reference fixture (3 backends × largest fixture), end-to-end stream consumption finishes within 2× the wall-clock duration of the fixture's recorded SSE stream." That's a falsifiable bar tied to real data.

### H-2. Coverage tier (≥ 90% / ≥ 80% line coverage) is a metric, not a quality bar

**PRD claim.** §5.1 SC-2 and §10.4 N-12.

**Cynical read.** Line coverage is a famously weak signal. 90% line coverage on `koel_core` can be achieved by exercising every constructor and `toString` without ever testing semantically meaningful behavior. The PRD's other goals (sealed exhaustiveness, protocol verify rules, JSON Patch strict mode, reducer composition, interceptor ordering) are not measurable through line coverage. The actual quality bar — "every protocol invariant has at least one fixture that exercises both the happy and unhappy paths" — is undefined.

This is doubly suspect because `dart test` with `coverage` does not distinguish branch coverage from line coverage by default. The PRD does not specify which metric (line, branch, function) and which tool.

**Sharper version.** Replace the percentage gates with:
- "Every public symbol named in §9 must be exercised by at least one test." (mechanical, falsifiable)
- "Every `case` in every `switch` on `AgUiEvent` and `KoelError` in `koel_core` and `koel_http` must be reached by at least one fixture." (semantic)
- "Every `verify` rule in §F.1 must have a fixture that triggers it." (protocol-truth)

Line coverage remains a useful CI signal but should not be the *gate*.

### H-3. "No vestigial code" (SC-5, N-15) is a discipline assertion, not a v1 ship gate

**PRD claim.** §5.1 SC-5: *"No vestigial code. No `TODO`, no commented-out blocks, no 'just in case' parameters, no exports that no example uses."* §10.4 N-15: *"No public export without a corresponding example in `/example` or a documented use case in a guide."*

**Cynical read.** This is a value, not a gate. "Just in case parameters" is not detectable by tooling. "Exports that no example uses" requires example-coverage tooling that does not exist for Dart out of the box — the PRD lists this as a CI gate without naming the tool. Also: there are public exports listed in §9 that *cannot* have a meaningful example until the consumer is in a production context (e.g., `SecureSessionStorage`, `SentryBreadcrumbInterceptor`, `ConformanceRunner` against a community adapter that does not yet exist). The rule will either be cosmetically satisfied (write a no-op example) or quietly relaxed.

**Sharper version.** Make the rule mechanical: every public symbol is reachable through at least one `/example` smoke test that runs in CI (D-4 already mandates this). Drop "no just-in-case parameters" as a release gate — it is a code-review value, not a CI-enforceable claim.

### H-4. Hybrid versioning + `^X.Y.0` ranged deps will break in one specific scenario the PRD does not address

**PRD claim.** §F-H2 and §12 R-3: adapters depend on foundations via `^X.Y.0`; foundations release lock-step.

**Cynical read.** Pub's `^X.Y.0` resolves to `>=X.Y.0 <(X+1).0.0`. If `koel_core` 1.0.0 ships, then `koel_agno` 1.0.0 with `koel_core: ^1.0.0` works. Then `koel_core` 1.1.0 adds a new sealed subtype (per FC-2, allowed as minor). Now `koel_agno` 1.0.0 is still resolved against `koel_core` 1.1.0 in the consumer's app — but `koel_agno`'s internal `switch (event)` written against `koel_core` 1.0.0's event set does **not** include the new subtype. This is exactly the C-2 problem, but worse: the adapter version that consumers have pinned is now broken because the foundation's "additive minor" added a sealed case that an old adapter's exhaustive switch did not handle.

The hybrid-versioning story assumes additive minors are safe across the dependency boundary. With sealed classes, they are not.

**Sharper version.** Two options:
- Adapters must use only the non-exhaustive idiom (`case UnknownAgUiEvent _:` or `default:`) so foundation minors are safe.
- Adapter packages also lock-step with foundations on any minor that adds an event subtype. This breaks the "adapters version independently" property the PRD currently advertises.

Make the choice explicit in F-H2.

### H-5. Sample fixtures from "3 backends" — capture mechanism and stability are unspecified

**PRD claim.** §F-G1: *"Real SSE traces captured live from three reference backends — AG-UI dojo, agno, langgraph — covering every AG-UI event type."*

**Cynical read.** "Covering every AG-UI event type" is a strong claim. The AG-UI dojo is one app; agno's chat backend is another; langgraph deployments vary. The probability that all three reference backends collectively emit every one of the ~28 event types in their natural flows is low — `REASONING_ENCRYPTED_VALUE` is specific to certain LLM providers (Anthropic, OpenAI), `ACTIVITY_*` events may be agno-only, `CUSTOM` is by definition non-standardized. There will be event types with zero natural-flow fixtures. The PRD does not say what happens then: synthesize them? skip them? The §5.1 SC-1 claim depends on this.

Additionally: how are fixtures captured? A network proxy capturing live SSE? A test harness? The capture mechanism affects whether fixtures are reproducible, whether they include timing data, and whether a backend update breaks them. The PRD says fixtures are "updated when AG-UI spec releases" — but if the capture is from a live LangGraph deployment, the spec releasing does nothing; the deployment has to be re-run with the new spec.

**Sharper version.** Add to §F-G1:
- Capture method: dedicated capture harness (`koel_test/tool/capture/`) that posts a `RunAgentInput` and writes the raw SSE bytes to disk.
- Coverage matrix: a table mapping each AG-UI event type to which backend(s) emit it naturally. Event types no backend emits are hand-synthesized as "golden" fixtures with an explicit annotation.
- Refresh policy: fixtures are regenerated on each AG-UI minor; diffs are reviewed for spec compliance vs. backend behavior.

### H-6. Open Questions OQ-Koel-Trademark and OQ-AGUI-License "block v1.0.0 publish" but are not in the §5.1 ship gates

**PRD claim.** §15 lists OQ-Koel-Trademark and OQ-AGUI-License as blocking v1.0.0 publish. §5.1 SC-1..SC-5 lists the ship gates.

**Cynical read.** Either OQ-Koel-Trademark is a ship gate or it isn't. The PRD says it is, but §5.1 doesn't mention it. If trademark search returns a conflict in India IP or USPTO, v1 cannot ship under the name "koel." Renaming nine packages on pub.dev is non-trivial — pub.dev does not allow package renames; you publish a new package and deprecate the old. So a trademark conflict found *after* any pre-v1 alpha publish to pub.dev under `koel_*` slots is destructive.

This is a sequencing risk the PRD acknowledges in OQ but does not surface in the planning structure.

**Sharper version.** Add SC-6: *"Trademark search clear on 'koel' across USPTO, EUIPO, India IP."* Add a process note: trademark check happens *before* any package is published to pub.dev under `koel_*`, including alphas. Move this to a "Pre-publication gates" sub-section of §12.

### H-7. The "interrupt-resume" gradient on `koel_langgraph` is sleight of hand

**PRD claim.** §F-C2: *"Implements interrupt-resume at the surface level — pause-and-resume via `MetaEvent` echoback. Deep interrupt semantics (stateful tree resumption) deferred to v2."* §A.4 shows `Future<void> resume(String threadId, Map<String, dynamic> resumeValue);`.

**Cynical read.** What is "surface-level interrupt-resume" actually delivering? LangGraph's interrupt-resume is a stateful primitive: the graph pauses at a node, the client sends a resume value, the graph continues. "MetaEvent echoback" suggests koel echoes a meta event back to LangGraph and hopes — but the underlying LangGraph semantics require state-graph snapshot management on the server, which is not something the client can echoback its way out of.

If `koel_langgraph` v1 says "we support interrupt-resume" and what we actually support is "we can call POST resume with a value and let the server decide," that should be stated. The current phrasing implies a depth of capability the implementation will not have.

**Sharper version.** F-C2 should say: *"`LangGraphAgent.resume(threadId, resumeValue)` POSTs the resume value to LangGraph's resume endpoint and re-opens the SSE stream. Stateful sub-tree resumption, multi-step interrupt graphs, and client-side state management for paused graphs are **not** supported in v1."* Then OQ-LangGraph-Graduation can hold "what would be needed to support those."

---

## Medium Findings

### M-1. "Production-grade" used 6+ times, never defined

§6.1 ("Both transports production-grade", "Both backend adapters production-grade"), §3 ("production-grade"), §F-B1 ("Production-grade SSE consumer"). The phrase has no definition. Sharper: replace with the specific gate it implies, or add a glossary entry: *"production-grade means: meets all §5.1 ship gates **and** has been used in P1's downstream app for ≥ N weeks without bug reports against the package."*

### M-2. "30 minutes of reading" claim in §1 is unfalsifiable

§1: *"A Flutter developer landing on `koel_core` should feel, within thirty minutes of reading the public API: this was built by someone who reads framework source, not docs."* Sharper: remove or convert to a measurable doc-quality claim like "Quickstart in README runs end-to-end against `MockAgent.fromFixture('agno/text-only')` in under 5 minutes."

### M-3. Web platform support (N-11) is asserted, not specified

N-11 says all six Flutter platforms supported, "Web support requires SSE-over-XHR fallback if `dart:io` isn't available — verified in CI." Addendum B.6 mentions `package:web` and browser `EventSource`. The interaction between SSE-over-XHR (which is not standard — SSE on web uses `EventSource`, not XHR) is confused. EventSource has its own constraints (no custom request bodies — but AG-UI uses POST with a JSON body, which `EventSource` *cannot* send). This is a fundamental web-transport limitation the PRD has not addressed. Sharper: specify exactly how koel posts a `RunAgentInput` body and receives an SSE response on Flutter web. Likely answer: `fetch` with `body` and a streaming `ReadableStream` reader — not `EventSource`. This needs to be in the addendum.

### M-4. `koel_test`'s `ConformanceRunner` is exposed to community adapter authors with no spec'd contract

§F-G4 and A.9 show `ConformanceRunner.runAgainst(AbstractAgent agent) → ConformanceReport`. What does the report contain? What does "pass" mean? Is there a single boolean, a per-event-type table, a severity ranking? The PRD says community adapter authors can "verify their work" — verify against what? Sharper: define the `ConformanceReport` data class in the addendum and pin which fixtures the runner uses.

### M-5. Default-OFF telemetry (N-2, F-I2) needs a "no quiet on-switch" guarantee

§N-I2 says Sentry/PII redaction default-OFF, no silent telemetry. Good. But the PRD does not say what happens when a `KoelClient` is constructed with a `subscribers` list containing a third-party subscriber that *does* phone home. The intent is clear; the surface that protects it is not. Sharper: add to §F-I2: *"koel does not include any first-party network-exfiltration code outside of the protocol's own backend POST. Third-party subscribers are the consumer's responsibility; koel does not curate or sign a subscriber registry."*

### M-6. AgentSubscriber callback bag has wide-open mutability surface

Addendum §A.1 shows `AgentSubscriber` with no-default-implementation no-op callbacks. A subscriber can override any of ~11 callbacks. This is a wide surface for forward-compat: adding a new callback in 1.x is a breaking change to anyone who implements `AgentSubscriber` directly. Sharper: either provide a concrete `AbstractAgentSubscriber` base class with empty defaults that consumers extend (Dart 3 mixin style), or document explicitly that adding callbacks is allowed-additive in minors and consumers should use `extends` not `implements`.

### M-7. `forwardedProps` and `context` on `RunAgentInput` are `Map<String, dynamic>` with no typing strategy

§A.1 shows `RunAgentInput.context: Map<String, dynamic>` and `forwardedProps: Map<String, dynamic>`. These bypass the entire "type-safe sealed" story for the parts of the protocol where consumers actually need typing. Sharper: either provide a typed wrapper API (consumer-side `extension`-based) or note explicitly that these fields are intentional escape hatches and consumers are on their own for type safety, with a guide to safely typing them.

### M-8. Reasoning encrypted-value round-trip is hand-waved

§F-A9 says "carried verbatim as opaque `String`/`Uint8List`, never inspected or modified, and are echoed back on subsequent runs." Echoed back *where*? In the next `RunAgentInput`? Under what field? AG-UI's spec stores these in the message history typically — the addendum does not say how koel reconstructs the message history with these blobs intact across session persistence (Hive serialization of `Uint8List` — base64? raw bytes? round-trip integrity?). Sharper: a sub-section in §C explaining the round-trip path: capture in event → persist via `SessionStorage` → re-included in next `RunAgentInput.messages` → byte-for-byte identical on the wire. Verify in tests.

### M-9. "Frame budget below 16ms" (N-5) ignores 120Hz devices

§10.1 N-5 specifies 16ms frame budget. Modern Android/iOS phones run at 90/120Hz (8.3ms budget). "Reference device Pixel 4a" runs at 60Hz so 16ms is fine for that, but the claim "frame jank … below the 16ms budget on the reference device" embeds the reference device assumption silently. Sharper: state the framerate the budget is per — "60Hz reference; high-refresh-rate devices require proportionally tighter budgets and are not a v1 conformance gate."

### M-10. Docs site framework deferral is light schedule denial

§F-H6 / OQ-Docs-Framework: docs site framework "TBD." The docs site is needed for D-3 (Getting Started, Concepts, Recipes, API Reference, Migration, Adapter Cookbook). All of those need authoring effort that is decoupled from but parallel to code. The PRD treats this as a small open question; in reality, writing ~10 recipes + concept pages + adapter cookbook is a multi-week effort and is part of v1 ship. Sharper: estimate the docs effort explicitly and stage it alongside code in the epic plan; do not let "docs framework TBD" hide the fact that docs *content* is on the critical path.

---

## Low Findings

### L-1. §1 "best AG-UI protocol SDK on Flutter" is a survivorship-bias claim

§1 opens with "koel is the best AG-UI protocol SDK on Flutter." There is one other SDK (`ag_ui` 0.1.0) and it is "single-package, eight months stale." Being better than the only existing competitor is a low bar. Sharper: "koel is the reference Flutter SDK for the AG-UI protocol" — same intent, doesn't bait the comparison.

### L-2. "Brand: koel (Hindi for the singing cuckoo)" is a fact, not a feature

§F-H4 includes the brand name etymology in the feature list. Move to §1 or §16, not the feature spec.

### L-3. §F-A2 "80% path" vs "power-user access" — the 80/20 number is wholesale

The three-layer API uses "80% path" without a source for the 80%. Either drop the number or back it with "based on the API analysis in §D.6's `dio`/`graphql_flutter` comparison, the ergonomic middle layer covers ~80% of common consumer flows." Doesn't change anything load-bearing; cleaner prose.

### L-4. "Reading framework source, not docs" appears in CLAUDE.md and §1 — duplicated principle

§1's tagline restates the project principle from CLAUDE.md. Not wrong, just redundant within the PRD.

### L-5. Decision-log says "no user-journey section" but PRD §3 still describes personas in journey-ish prose

§3 P1/P2/P3 has a touch of "Wants a premium developer experience: discoverable API surface, no magic, clear error messages…" which is journey-ish. Could be terser given §3 says personas aren't journeys.

### L-6. §14 Counter-metrics "reviewed quarterly" — by whom?

No deadline = no quarterly cadence. Either drop "quarterly" or say "reviewed before each minor release."

### L-7. §F-B5 "Halves wire weight without burdening backend implementers" — claim of magnitude without measurement

"Halves wire weight" — for what payload mix? Sharper: drop the magnitude or back it with the fixture data.

### L-8. The `koel` meta-package's pub.dev "API" tab will be confusing

Re-export packages on pub.dev show their re-exports but score lower (lower dart-doc coverage on the meta package). The PRD does not mention this. Sharper: brief note in §F-H3 that the meta-package is intentionally low-API-surface and pub-score asymmetry is expected.

### L-9. `KoelClient.dispose()` is in the addendum but its semantics are unspecified

A.1 shows `void dispose();` on `KoelClient`. Does this cancel active sessions, close interceptor resources, flush session storage, call subscribers' onDispose? Standard Flutter `dispose` pattern is implied but should be spelled out.

### L-10. "MIT license" in N-NG categories but also in F-H5 as feature

License is both a non-goal-adjacent statement and a feature — appears twice. Pick a home.

---

## Summary

The PRD is in good shape as a vision document and as a feature inventory. As a *contract for v1 success*, it has four load-bearing soft spots that need to be hardened before downstream epic planning:

1. **Conformance** is not anchored to a spec version + commit + test mechanism (C-1).
2. **Semver + sealed classes + protocol evolution** are in mutual contradiction (C-2, H-4).
3. **`koel_runtime` is mis-scoped** — treated as a sibling transport, actually a second protocol implementation (C-3).
4. **Time-travel replay safety + WidgetResolver effects** are an unresolved hard problem hiding as an "open question" (C-5).

The performance NFRs (H-1), coverage tiers (H-2), and "no vestigial code" (H-3) are good values but weak gates — replace with mechanical, falsifiable bars. The pipeline/interceptor/subscriber overlap (C-4) needs one sequence diagram to disentangle the three observation surfaces.

Counts: **5 critical, 7 high, 10 medium, 10 low.**

The "no deadline" stance is the PRD's biggest asset — many of the above can be resolved by simply taking the time to specify them. None of the findings are existential. They are the difference between a v1 that the author can defend in code review against any cynic, and a v1 that survives a casual reading but fails under scrutiny.
