## 1.1.0

- NEW: `ChatSession.regenerate()` — regenerates the answer to the last user
  turn with CopilotKit `reloadMessages` parity: truncates the committed
  transcript back to (and including) the last user message (original id
  preserved for server-side dedupe-by-id history merges), clears in-flight
  transients (`pendingMessage`, `pendingToolCalls` — `setMessages`
  replace-the-transcript semantics), and re-runs the agent **without**
  appending a new user message, so the old answer is replaced, not duplicated.
  No-op when the transcript has no user turn. Like `send()`, it does not guard
  against an in-flight run — callers gate on their own streaming state.
- NEW: `ChatSession.updateState(Map<String, dynamic> patch)` — shallow-merges
  a patch into the shared agent `ChatState.state` mid-session and re-emits, so
  the next run carries it in `RunAgentInput.state` without recreating the
  session. Mirrors CopilotKit `agent.setState({ ...agent.state, ...patch })`.
- INTERNAL: the run machinery shared by `send()` and `regenerate()` is
  extracted into a private `_run()`; `send()` behavior is unchanged.

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

## 0.0.1

- Initial scaffold.
