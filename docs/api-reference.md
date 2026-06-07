---
id: api-reference
title: API Reference
---

# API Reference

The authoritative, always-current API reference for every koel package is the
**pub.dev "API" tab**, generated from the in-source `dart doc` comments on each
release. We deliberately **do not** vendor a copy of the generated HTML here — a
checked-in copy rots and bloats, while the pub.dev tab is regenerated on every
publish and versioned per release.

Every public symbol carries a doc comment (enforced by the
`public_member_api_docs` analyzer lint) and every package builds clean under
`dart doc` (the `melos run docs` gate, NFR-16), so the reference is complete by
construction.

## Per-package reference

| Package | What it covers | API reference |
| --- | --- | --- |
| `koel` | The meta-package (re-exports core + http + flutter) | [pub.dev/documentation/koel](https://pub.dev/documentation/koel/latest/) |
| `koel_core` | Protocol kernel: events, errors, pipeline, reducer, client | [pub.dev/documentation/koel_core](https://pub.dev/documentation/koel_core/latest/) |
| `koel_http` | `HttpAgent`, SSE parser, transport interceptors | [pub.dev/documentation/koel_http](https://pub.dev/documentation/koel_http/latest/) |
| `koel_flutter` | Controller, scope, session storage, content parser, resolver | [pub.dev/documentation/koel_flutter](https://pub.dev/documentation/koel_flutter/latest/) |
| `koel_widgets` | Themeable chat UI primitives | [pub.dev/documentation/koel_widgets](https://pub.dev/documentation/koel_widgets/latest/) |
| `koel_test` | `MockAgent`, fixtures, conformance runner | [pub.dev/documentation/koel_test](https://pub.dev/documentation/koel_test/latest/) |
| `koel_lints` | The analyzer plugin + lint profile | [pub.dev/documentation/koel_lints](https://pub.dev/documentation/koel_lints/latest/) |
| `koel_agno` | Agno backend bridge | [pub.dev/documentation/koel_agno](https://pub.dev/documentation/koel_agno/latest/) |
| `koel_langgraph` | LangGraph backend bridge | [pub.dev/documentation/koel_langgraph](https://pub.dev/documentation/koel_langgraph/latest/) |
| `koel_runtime` | CopilotKit runtime (v2 native-SSE) bridge | [pub.dev/documentation/koel_runtime](https://pub.dev/documentation/koel_runtime/latest/) |

> The links resolve once the packages are first published (Story 9.9). Until
> then, run `dart doc` locally in any package — or `melos run docs` from the repo
> root to build all ten at once.

## Generating it locally

```bash
# all ten release packages, the NFR-16 build gate:
melos run docs

# or one package's HTML reference:
cd packages/koel_core && dart doc
```
