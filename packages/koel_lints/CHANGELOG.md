## 1.1.0

Foundation lock-step release with `koel_core` 1.1.0 (which adds
`ChatSession.regenerate()` and `ChatSession.updateState()`). No functional
changes in this package.

## 1.0.0

First stable release. The koel foundation (`koel_core` + `koel_http` +
`koel_lints`) ships lock-step at `1.0.0`, conformant to the AG-UI protocol
`release/2026-05-26` (commit `d74e2dfc1e11bebdff419c2cbd347c811555411d`).

- Protocol kernel (`koel_core`): the closed 28-type sealed `AgUiEvent` registry
  with the `UnknownAgUiEvent` forward-compat fallback, the sealed `KoelError`
  hierarchy, vendored RFC 6902 JSON Patch, the four-stage event pipeline
  (decode → verify → reduce → dispatch), the `ChatState` reducer, the interceptor
  chain, `SessionStorage`, and the `KoelClient` / `ChatSession` API.
- HTTP transport (`koel_http`): the framework-free SSE parser, `HttpAgent` native
  transport with cancellation propagation, chunk synthesis, connection-lifecycle
  hooks, and the interceptor suite (retry, auth, logging, event-trace, Sentry, PII
  redaction).
- Lint profile (`koel_lints`): the koel analysis ruleset built on the first-party
  `analysis_server_plugin`.
- Conformance: the `AgUiEvent_equal` structural-equality rule (byte-equal
  `Uint8List`) is finalized and pinned in `koel_core/CONFORMANCE.md`; the
  SC-1..SC-5 release gates (conformance, coverage, analyze, API stability, no
  vestigial code) are green.

<!-- koel_lints-specific (below the mirrored foundation summary) -->

- Enabled centrally at the workspace-root `analysis_options.yaml`; fires under
  `dart analyze` and IDEs in the native pub workspace. Requires Dart `>=3.11.0`;
  built against the pinned `analyzer 12.1.0` / `analysis_server_plugin 0.3.14`
  (the AI-5.9 stopgap — analyzer 12 lets `freezed` share the workspace
  resolution; bumps to analyzer 13 once stable `freezed` supports it).

## 0.0.1

- Initial scaffold.
- Built on the first-party `analysis_server_plugin` (asp). Enabled centrally at
  the workspace-root `analysis_options.yaml`; fires under `dart analyze` and
  IDEs in the native pub workspace.
- Requires Dart `>=3.11.0`; built against the pinned `analyzer 12.1.0` /
  `analysis_server_plugin 0.3.14` (the AI-5.9 analyzer-12 stopgap).
