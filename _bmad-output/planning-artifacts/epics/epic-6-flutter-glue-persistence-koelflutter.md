# Epic 6: Flutter Glue & Persistence — `koel_flutter`

Developer can wrap a `ChatSession` in `KoelChatController extends ChangeNotifier` and integrate into any state-management framework (Bloc/Riverpod/GetX/Provider/setState) with one line. `KoelClientScope` publishes the client down the widget tree. `HiveSessionStorage` + `SecureSessionStorage` persist + restore conversations including partial messages. `MessageContentParser` splits assistant strings. `WidgetResolver` hosts generative UI on `TOOL_CALL_*` events. Verified across all six Flutter platforms. Memory + streaming-jank baselines captured. Coverage ≥ 90%.

## Story 6.1: `KoelChatController extends ChangeNotifier`

As a Flutter developer,
I want `KoelChatController` wrapping a `ChatSession` with synchronous `state` getter + `isStreaming` getter + `send`/`cancel`/`clear` methods + `notifyListeners()` on state change,
So that I can integrate koel into any state-management framework (Bloc, Riverpod, GetX, Provider, `setState`) with one line per FR-D4.

**Acceptance Criteria:**

**Given** `packages/koel_flutter/lib/src/controller/koel_chat_controller.dart`,
**When** I inspect the constructor,
**Then** it matches Addendum A.6: `KoelChatController({required ChatSession session})`,
**And** the controller subscribes to `session.stream` on construction and unsubscribes on `dispose()`,
**And** every state change triggers `notifyListeners()`.

**Given** the public surface,
**When** I inspect it,
**Then** `ChatState get state` (synchronous read), `bool get isStreaming` (true while `state.phase == RunPhase.running` or `stepRunning`), `Future<void> send(String content)`, `void cancel()`, `Future<void> clear()` all exist per Addendum A.6.

**Given** an integration test wrapping the controller in `ChangeNotifierProvider` (provider package) + an `AnimatedBuilder` listening to it,
**When** the session emits `TextMessageContentEvent`s,
**Then** the widget rebuilds with the accumulating message text,
**And** `isStreaming` flips from `false` → `true` on send and back to `false` on `RunFinishedEvent`.

**Given** integration tests for each state-management framework (Bloc via `BlocProvider.value` adapter; Riverpod via `ChangeNotifierProvider`; GetX via `Get.put`; plain `setState` via `AnimatedBuilder`),
**When** I run them,
**Then** all five integrations pass without modification to the controller.

## Story 6.2: `KoelClientScope extends InheritedWidget`

As a Flutter developer,
I want `KoelClientScope` publishing a `KoelClient` down the widget tree with `KoelClientScope.of(context)` lookup,
So that descendant widgets resolve the client without service-locator or `get_it` per FR-D5.

**Acceptance Criteria:**

**Given** `packages/koel_flutter/lib/src/scope/koel_client_scope.dart`,
**When** I inspect it,
**Then** `class KoelClientScope extends InheritedWidget` with `const KoelClientScope({required this.client, required super.child, super.key})` per Addendum A.6,
**And** `static KoelClient of(BuildContext context)` returns the nearest ancestor's client,
**And** `updateShouldNotify(KoelClientScope old) => client != old.client`.

**Given** a widget tree with `KoelClientScope(client: ..., child: MaterialApp(...))`,
**When** a descendant `Widget` calls `KoelClientScope.of(context)`,
**Then** the correct client returns,
**And** swapping the scope's `client` field rebuilds dependent widgets exactly once.

**Given** a descendant calling `KoelClientScope.of(context)` with no ancestor scope,
**When** the call executes,
**Then** a `FlutterError` is thrown with a remediation message ("Wrap your app in a KoelClientScope").

## Story 6.3: `HiveSessionStorage`

As a Flutter developer,
I want `HiveSessionStorage implements SessionStorage` persisting `ChatState` (including partial in-progress messages with `isComplete: false`) into a Hive box,
So that conversations survive app restarts per FR-D1.

**Acceptance Criteria:**

**Given** `packages/koel_flutter/lib/src/session_storage/hive_session_storage.dart`,
**When** I inspect it,
**Then** `HiveSessionStorage({required String boxName})` exists per Addendum A.6,
**And** save/load/delete/listThreads are implemented against a Hive box,
**And** `ChatState` serialization uses freezed's `toJson()` / `fromJson()`.

**Given** an in-progress `ChatState` (mid-stream, `phase == RunPhase.running`, `pendingMessage` populated),
**When** I `save(...)` then `load(...)`,
**Then** the reloaded state carries `pendingMessage` with the same content and `isComplete: false` (or equivalent marker per Addendum FR-D1 specification),
**And** consumer UI can render the partial message as such.

**Given** a Hive type-adapter regression scenario,
**When** I deserialize a `ChatState` written by koel_flutter v1.0.0 against the v1.0.0 schema,
**Then** it loads correctly (no type-mismatch error).

## Story 6.4: `SecureSessionStorage` via `flutter_secure_storage`

As a Flutter developer,
I want `SecureSessionStorage implements SessionStorage` backed by `flutter_secure_storage` for encrypted-at-rest conversation persistence,
So that consumers needing PII protection get a drop-in storage with the same API as Hive per FR-D1.

**Acceptance Criteria:**

**Given** `packages/koel_flutter/lib/src/session_storage/secure_session_storage.dart`,
**When** I inspect the constructor,
**Then** it matches Addendum A.6: `SecureSessionStorage({FlutterSecureStorage? storage})`,
**And** default `storage` is `FlutterSecureStorage()` with platform defaults.

**Given** save → load round-trip across multiple threadIds,
**When** I exercise it on each platform CI lane,
**Then** every threadId loads exactly the persisted state,
**And** `delete(threadId)` removes both the thread's content and the index entry,
**And** `listThreads()` returns the current set.

**Given** platform-specific quirks (iOS keychain access on cold start, Android KeyStore on factory reset, web fallback to localStorage),
**When** integration tests run on each platform,
**Then** behavior is documented in the package README per platform (per architecture's N-11 documented caveats).

## Story 6.5: `MessageContentParser` + sealed `MessageSegment`

As a Flutter developer,
I want `MessageContentParser` splitting assistant message strings into `List<MessageSegment>` (sealed: `TextSegment | CodeBlockSegment`) with markdown-fenced code-block detection,
So that I can render mixed prose + code without inline parsing logic per FR-E1.

**Acceptance Criteria:**

**Given** `packages/koel_flutter/lib/src/message/message_content_parser.dart`,
**When** I inspect it,
**Then** `class MessageContentParser` exposes `List<MessageSegment> parse(String content)`,
**And** `sealed class MessageSegment` has subtypes `TextSegment(text: String)` and `CodeBlockSegment(language: String, code: String)` per Addendum A.6,
**And** the `koel_lints` rule `exhaustive_switch_must_have_default` fires on switches over `MessageSegment` without default (verified by integration test).

**Given** a content string containing prose + three fenced code blocks of different languages,
**When** I parse it,
**Then** the output is an alternating list of `TextSegment` / `CodeBlockSegment` instances preserving language hints,
**And** unfenced backticks (inline code) stay inside `TextSegment` (only fenced blocks split out per PRD §6.1 / FR-E1 deferral of rich content).

**Given** edge cases (empty string, code block at start, code block at end, unclosed code block, nested-language hint with no body),
**When** the parser runs,
**Then** every case produces a well-formed output and a property-based test on 500 random markdown-ish strings never crashes.

## Story 6.6: `WidgetResolver` + `ToolReplayContext` `InheritedWidget`

As a Flutter developer,
I want `WidgetResolver` mapping tool-call name → Flutter Widget builder with `onUnknown` fallback, plus `ToolReplayContext` published via `InheritedWidget` so handlers consult it during DevTools replay,
So that generative UI on `TOOL_CALL_*` events composes safely with the DevTools replay path per FR-E2 + FR-F7.

**Acceptance Criteria:**

**Given** `packages/koel_flutter/lib/src/generative_ui/widget_resolver.dart`,
**When** I inspect it,
**Then** `class WidgetResolver` matches Addendum A.6 — constructor takes a `Map<String, Widget Function(BuildContext, ToolCallEvent)>` registry + optional `onUnknown` builder,
**And** `Widget resolve(BuildContext context, ToolCallEvent toolCall)` returns the registered builder's widget or the `onUnknown` fallback (defaulting to a built-in `UnknownGenerativeUI` placeholder).

**Given** a registered resolver for tool-call name `"chart"` with a builder returning a chart widget,
**When** a `ToolCallStartEvent(toolCallName: "chart")` arrives,
**Then** the resolver returns the chart widget,
**And** the chart widget renders without errors in a test surface.

**Given** an unregistered tool-call name `"unknown"`,
**When** I resolve it,
**Then** the `onUnknown` fallback (or `UnknownGenerativeUI` default) renders.

**Given** `packages/koel_flutter/lib/src/generative_ui/tool_replay_context.dart`,
**When** I inspect it,
**Then** `class ToolReplayContext extends InheritedWidget` exposes `final bool isReplaying` + `static ToolReplayContext of(BuildContext)` per FR-F7 + Addendum C.3,
**And** when wrapped around the widget tree during replay (Epic 8), descendant handlers can read `isReplaying: true` and skip side effects.

## Story 6.7: Six-platform CI verification + smoke tests

As a release manager,
I want `koel_flutter` smoke tests running on all six Flutter platforms (iOS, Android, web, macOS, Windows, Linux) in CI verifying the integration flow,
So that platform-divergence regressions surface immediately per NFR-11.

**Acceptance Criteria:**

**Given** `.github/workflows/ci.yml` (extended here),
**When** I inspect the matrix,
**Then** six platform jobs exist: iOS (macOS runner + Xcode), Android (Linux + Android SDK), web (Linux + Chrome headless), macOS, Windows, Linux,
**And** each job runs `flutter test integration_test/` for `koel_flutter`.

**Given** `packages/koel_flutter/integration_test/`,
**When** I inspect it,
**Then** at least one smoke test wires a `KoelClientScope(client: ...)` with a `MockAgent.fromFixture('text_only_run')`, a `KoelChatController`, and a minimal Flutter widget consuming `controller.state.messages`,
**And** the test passes on every platform lane.

**Given** platform-specific caveats (e.g., `flutter_secure_storage` keychain access on iOS simulator),
**When** I inspect package README,
**Then** documented per architecture's NFR-11 "documented per-platform caveats" clause.

## Story 6.8: Memory + streaming-jank perf baselines + dartdoc + barrel

As a release manager,
I want `chat_session_memory_bench.dart` and `streaming_jank_bench.dart` capturing v1.0.0 baselines + every public symbol with contract-form dartdoc + finalized barrel `lib/koel_flutter.dart`,
So that NFR-3 + NFR-5 regression-relative SLOs are enforceable and 1.x contract is sealed per AR-15 + AR-21.

**Acceptance Criteria:**

**Given** `packages/koel_flutter/test/perf/chat_session_memory_bench.dart`,
**When** I run it,
**Then** baseline RSS-delta numbers under the CI reference device profile are captured into `baselines/chat_session_memory_bench.json`,
**And** subsequent runs fail when regression > 10% per NFR-3.

**Given** `packages/koel_flutter/test/perf/streaming_jank_bench.dart`,
**When** I run it,
**Then** baseline streaming-jank numbers (frames under 16 ms budget vs over) are captured into `baselines/streaming_jank_bench.json`,
**And** subsequent runs fail when regression > 10% per NFR-5.

**Given** every public symbol in `lib/koel_flutter.dart`,
**When** I run `dart doc`,
**Then** the barrel exports exactly the surface listed in PRD §9 / Addendum A.6,
**And** every exported class/method/getter carries a contract-form dartdoc per NFR-16,
**And** `dart_apitool extract` produces a baseline diffable in Epic 9.

**Given** the package overall,
**When** I run `melos run test:coverage`,
**Then** coverage ≥ 90% per NFR-12 (foundation tier per architecture),
**And** `dart analyze` exits 0 per NFR-13.

---
