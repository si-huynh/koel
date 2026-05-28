# Epic 8: DevTools Extension — `koel_devtools`

Developer opens Flutter DevTools and sees a live `AgUiEvent` stream, time-travel replay through a configurable ring buffer (default 1000), tool-call inspector, network panel, and JSON Lines trace export/import. `DevToolsObserver implements AgentSubscriber`, never mutates `KoelClient` state. Replay re-folds the reducer; tool handlers no-op via `ToolReplayContext.isReplaying`. Flutter web extension UI under `tool/extension_ui/` builds via `melos run build:devtools` and ships in the package. Coverage ≥ 80%.

## Story 8.1: `DevToolsObserver implements AgentSubscriber` + bounded ring buffer

As a Flutter developer,
I want `DevToolsObserver` implementing `AgentSubscriber` snapshotting every event into a bounded ring buffer (default 1000, configurable via `KoelClient.devtoolsBufferSize`),
So that the observation surface is observation-only and never mutates `KoelClient` state per FR-F1 + FR-F3 + AR-11.

**Acceptance Criteria:**

**Given** `packages/koel_devtools/lib/src/observer/devtools_observer.dart`,
**When** I inspect the class,
**Then** `class DevToolsObserver implements AgentSubscriber` exists with `DevToolsObserver({int bufferSize = 1000})` constructor per Addendum A.8,
**And** every event-family callback (`onRunStart`, `onTextChunk`, `onToolCall`, …) appends the event into an internal `RingBuffer<AgUiEvent>`.

**Given** `packages/koel_devtools/lib/src/observer/ring_buffer.dart`,
**When** I inspect it,
**Then** the ring buffer is a fixed-capacity FIFO with O(1) append and bounded memory,
**And** its property-based test confirms invariants (capacity never exceeded, oldest event evicted on overflow, `toList()` returns events in insertion order).

**Given** a configured `KoelClient(devtoolsBufferSize: 500, subscribers: [DevToolsObserver()])`,
**When** I drive 1000 events through it,
**Then** the buffer holds exactly the last 500 events,
**And** no state in `KoelClient` is mutated by the observer (verified by deep-equality check on `client` state pre/post run with vs without the observer attached).

## Story 8.2: `devtools_extensions: 0.5.1` registration + Flutter web extension skeleton

As a Flutter developer,
I want `extension/devtools/config.yaml` registering the koel DevTools extension per `devtools_extensions: 0.5.1` plus the Flutter web app skeleton under `tool/extension_ui/`,
So that Flutter DevTools auto-discovers koel when `koel_devtools` is present in pubspec per FR-F1 + AR-11.

**Acceptance Criteria:**

**Given** `packages/koel_devtools/extension/devtools/config.yaml`,
**When** I inspect it,
**Then** it conforms to the `devtools_extensions: 0.5.1` schema declaring extension name + entry point + supported DevTools version range.

**Given** `packages/koel_devtools/tool/extension_ui/`,
**When** I list it,
**Then** a Flutter web app scaffold exists with `pubspec.yaml` depending on `koel_devtools` + `devtools_extensions`,
**And** `lib/main.dart` is the iFrame-embedded entry-point wiring per the DevTools extension lifecycle,
**And** `web/index.html` exists.

**Given** `melos.yaml`,
**When** I inspect scripts,
**Then** `melos run build:devtools` is defined per AR-23 (G-2) — runs `flutter build web` in `tool/extension_ui/` and copies the build artifacts into `extension/devtools/build/` (gitignored per architecture).

**Given** a downstream consumer adding `koel_devtools` to its pubspec,
**When** the consumer opens Flutter DevTools against a running app,
**Then** a "koel" tab appears in the DevTools UI (manual verification documented in the package README).

## Story 8.3: Stream panel (live event stream + filter + search + jump-to-event)

As a Flutter developer,
I want the Stream panel in DevTools rendering a real-time scrolling list of `AgUiEvent`s with filter-by-type, full-text search, and jump-to-event,
So that I can observe a live run in detail per FR-F2.

**Acceptance Criteria:**

**Given** `tool/extension_ui/lib/panels/stream_panel.dart`,
**When** I inspect it,
**Then** the panel subscribes to the host app's `DevToolsObserver` ring buffer via the `devtools_extensions` ExtensionAPI (iFrame postMessage; no shared memory per architecture's DevTools boundary),
**And** renders an `EventRow` widget per event with type, summary, timestamp.

**Given** filter chips for each event type family (RUN_*, TEXT_*, TOOL_CALL_*, STATE_*, REASONING_*, …),
**When** I toggle a chip,
**Then** the visible list filters to that family only,
**And** the filter state persists across DevTools panel switches.

**Given** a search box,
**When** I type a substring,
**Then** matching events highlight + the list filters to matches,
**And** an empty search restores the full list.

**Given** a "jump-to-event" feature,
**When** I click an event in the timeline,
**Then** the History panel (Story 8.4) navigates to that event's state.

## Story 8.4: History panel (time-travel replay)

As a Flutter developer,
I want the History panel re-folding the reducer over events `[0..N]` and displaying the resulting `ChatState` snapshot, with step-backward / step-forward navigation,
So that I can scrub through a session and inspect state at any point per FR-F3 + Addendum C.3.

**Acceptance Criteria:**

**Given** `packages/koel_devtools/lib/src/replay/replay_state.dart`,
**When** I inspect it,
**Then** it exposes `ChatState computeAt(int n)` re-folding the reducer over the ring buffer's `events[0..n]`,
**And** caches results per `n` to avoid recomputation on repeated scrub.

**Given** `tool/extension_ui/lib/panels/history_panel.dart`,
**When** I inspect it,
**Then** it renders a timeline of events with step-backward / step-forward / jump-to-N controls,
**And** the right-pane shows the `ChatState` at the selected event (pretty-printed JSON view).

**Given** a session with 100 events,
**When** I scrub forward and backward,
**Then** the displayed state stays consistent with re-folding,
**And** tool handlers do NOT re-execute during replay (verified via Story 8.7 + integration test).

## Story 8.5: Inspector + Network panels

As a Flutter developer,
I want the Inspector panel (tool-call tree view with name, args, result, latency, error) and the Network panel (HTTP-level inspection — request headers, response headers, connection lifecycle, retries),
So that I can drill into tool execution and transport behavior per FR-F4 + FR-F5.

**Acceptance Criteria:**

**Given** `tool/extension_ui/lib/panels/inspector_panel.dart`,
**When** I inspect it,
**Then** the panel renders a tree view of every tool call in the current session pulled from the `DevToolsObserver`'s buffered events,
**And** each tree node expands to show args (pretty JSON), result (pretty JSON or error), and latency (start-to-end ms).

**Given** a tool-call with an error,
**When** I expand it,
**Then** the error's `KoelErrorCode` + message + cause display.

**Given** `tool/extension_ui/lib/panels/network_panel.dart`,
**When** I inspect it,
**Then** the panel surfaces HTTP-level metadata from `HttpAgent` lifecycle hooks (Story 4.9) — request headers, response headers, connection open/close, retry attempts with delay,
**And** correlates events to retry boundaries.

## Story 8.6: Export panel + JSONL writer/reader + `_session` header round-trip

As a Flutter developer,
I want the Export panel writing the ring buffer to JSONL with the `_session` header per Addendum C.4 format and a round-trip re-import,
So that I can save a session for offline debugging and load it back into DevTools per FR-F6 + Addendum C.4.

**Acceptance Criteria:**

**Given** `packages/koel_devtools/lib/src/export/jsonl_writer.dart`,
**When** I inspect it,
**Then** the writer streams the ring buffer to a `Sink<String>` with the first line being the `_session` header (`{"_session": {"threadId": ..., "runId": ..., "koelVersion": ..., "adapter": ..., "captured": ...}}`),
**And** subsequent lines each carry one event with `timestamp` (ISO 8601) + `payload`.

**Given** `packages/koel_devtools/lib/src/export/jsonl_reader.dart`,
**When** I inspect it,
**Then** the reader parses the JSONL back into `FixtureSession` + `List<AgUiEvent>`,
**And** the round-trip `write → read` produces structurally-equal data.

**Given** the Export panel,
**When** I click "Download Trace",
**Then** the browser downloads a `.jsonl` file via the DevTools `File` API per Addendum G.

**Given** the Export panel "Load Trace" action,
**When** I select an exported JSONL file,
**Then** the Stream + History panels populate from the loaded data.

## Story 8.7: Replay safety + `melos run build:devtools` + extension build CI

As a Flutter developer,
I want `ToolReplayContext.isReplaying = true` propagating during replay so tool handlers can no-op side effects, plus `melos run build:devtools` wired + the extension Flutter-web build integrated into CI,
So that replay is safe by default and the extension UI ships as part of the package per FR-F7 + AR-23 (G-2).

**Acceptance Criteria:**

**Given** the History panel performing a replay,
**When** the replay computes via `ReplayState.computeAt(n)`,
**Then** the replay path wraps the reducer execution in a `ToolReplayContext` (using the InheritedWidget from Story 6.6) where `isReplaying: true`,
**And** any tool handler in the consumer app that checks `ToolReplayContext.of(context).isReplaying` becomes a no-op for side effects per Addendum C.3.

**Given** a tool handler that does NOT check the replay context,
**When** replay invokes it,
**Then** the handler runs but its result is replaced with the recorded result from the ring buffer (the handler call becomes a "no-op stub" returning the recorded value per Addendum C.3),
**And** the actual side effect (if any) of the unaware handler is documented as a known limitation tracked by OQ-Replay-Side-Effects.

**Given** `melos run build:devtools` (added in Story 8.2),
**When** the script runs in CI as part of `publish-dry-run.yml`,
**Then** it compiles the extension web app and copies output to `extension/devtools/build/` successfully,
**And** the published `koel_devtools` tarball includes the built extension assets.

**Given** the package overall,
**When** I run `melos run test:coverage`,
**Then** coverage ≥ 80% per NFR-12,
**And** `dart analyze` exits 0 per NFR-13,
**And** `dart_apitool extract` produces a baseline diffable in Epic 9.

---
