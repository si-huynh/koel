import 'dart:async';
import 'dart:convert';

import 'package:koel_core/koel_core.dart';

import 'mock_agent.dart';

/// A `koel_test`-local tool-handler contract: one argument map in, one
/// JSON-encodable value out.
///
/// [FutureOr] lets a single signature accept both a synchronous handler
/// (`(args) => args['a'] + args['b']`) and an asynchronous one
/// (`(args) async => await something(args)`); [ToolHandlerTestHarness.invoke]
/// `await`s the return either way. The returned [Object?] is the *un-encoded*
/// value — the harness wraps it into the result event's `content` as
/// `jsonEncode({'value': <return>})`, so it must be JSON-encodable (a
/// non-encodable return surfaces `jsonEncode`'s error, a test-authoring bug).
///
/// Replay-awareness is **not** a parameter: a replay-aware handler closes over
/// its [ToolHandlerTestHarness] and reads [ToolHandlerTestHarness.isReplaying]
/// to skip side effects under replay while still returning the recorded value.
///
/// There is no kernel `ToolHandler` — `koel_core` transports and folds
/// tool-call *events* but never invokes a handler — so this typedef and its
/// runner live entirely in `koel_test`.
typedef ToolHandler = FutureOr<Object?> Function(Map<String, dynamic> args);

/// A fluent, `koel_test`-only builder that exercises a tool handler end-to-end
/// in ~5 lines: register a handler, invoke it, assert on the resulting
/// [ToolCallResultEvent] (FR-G3).
///
/// ```dart
/// final result = await ToolHandlerTestHarness()
///   .register('addTwo', (args) => args['a'] + args['b'])
///   .invoke('addTwo', {'a': 2, 'b': 3});
/// expect((jsonDecode(result.content) as Map<String, dynamic>)['value'], 5);
/// ```
///
/// **The harness runs the handler itself, then replays a canonical run.** The
/// kernel has no handler-execution path, and a [MockAgent] timeline is frozen
/// before `run()` — so [invoke] holds the `args`, calls the handler, encodes
/// its return into a `TOOL_CALL_RESULT`, assembles the
/// `RUN_STARTED → TOOL_CALL_START → TOOL_CALL_ARGS → TOOL_CALL_END →
/// TOOL_CALL_RESULT → RUN_FINISHED` sequence, and drives it through a **real**
/// [KoelClient.runRaw]. The `MockAgent`, the four-stage pipeline, and
/// [AgentSubscriber] dispatch are all real koel machinery — the harness is glue,
/// not a fake — so [observe]d subscribers see the run through the canonical
/// dispatch path.
///
/// A harness is **per-test**: it holds no `static` mutable state (FR-D3), and
/// its ids are derived from an instance counter, so independent harnesses never
/// collide.
final class ToolHandlerTestHarness {
  /// Creates an empty harness; chain [register]/[observe] before [invoke].
  ToolHandlerTestHarness();

  final Map<String, ToolHandler> _handlers = {};
  final List<AgentSubscriber> _observers = [];
  bool _isReplaying = false;
  int _callSeq = 0;

  /// Whether the in-flight handler is being invoked under a simulated replay.
  ///
  /// This is the **stub stand-in** for `ToolReplayContext.isReplaying` — the
  /// real `InheritedWidget` arrives in `koel_flutter` (Epic 6 Story 6.6) and
  /// full FR-F7 replay validation lands in `koel_devtools` (Epic 8 Story 8.7).
  /// A replay-aware test handler closes over this harness and reads this flag to
  /// gate its side effects:
  ///
  /// ```dart
  /// final harness = ToolHandlerTestHarness()
  ///   ..register('sendEmail', (args) {
  ///     if (!harness.isReplaying) sideEffects++; // skipped under replay
  ///     return {'sent': true};                   // recorded result still emitted
  ///   });
  /// await harness.invoke('sendEmail', {'to': 'x'}, isReplaying: true);
  /// ```
  ///
  /// Set by [invoke] around the handler call (via its `isReplaying:` argument)
  /// and reset to `false` once the handler returns — `false` at every other
  /// time.
  ///
  /// Because this is a single shared instance flag, it is meaningful only for a
  /// **single in-flight [invoke]**: a handler must let one [invoke] complete
  /// before starting the next on the same harness (see [invoke]'s single-invoke
  /// contract). A harness is per-test, so sequential `await`ed invokes are the
  /// expected — and only supported — usage.
  bool get isReplaying => _isReplaying;

  /// Registers [handler] under [name] and returns `this` for chaining.
  ///
  /// A duplicate [name] overwrites (last registration wins): a harness is
  /// per-test, so reuse of a name is the author's intent, not an error.
  ToolHandlerTestHarness register(String name, ToolHandler handler) {
    _handlers[name] = handler;
    return this;
  }

  /// Attaches [subscriber] to every subsequent [invoke] and returns `this` for
  /// chaining.
  ///
  /// On each [invoke] the observers are wired into the internal [KoelClient], so
  /// the subscriber sees `onToolCall(start, null)` and `onToolResult(result)`
  /// fire through the **real** post-pipeline dispatch path — proof the
  /// invocation is observable, not bypassed (AC2).
  ToolHandlerTestHarness observe(AgentSubscriber subscriber) {
    _observers.add(subscriber);
    return this;
  }

  /// Runs the handler registered under [name] with [args], replays the
  /// resulting tool call through a real [KoelClient], and returns the
  /// post-pipeline [ToolCallResultEvent].
  ///
  /// The handler's return is encoded under a `value` envelope:
  /// `content = jsonEncode({'value': <return>})`, so `addTwo`'s `5` becomes
  /// `'{"value":5}'`. Decode it test-side with
  /// `(jsonDecode(result.content) as Map<String, dynamic>)['value']`.
  ///
  /// When the `isReplaying:` argument is `true`, [ToolHandlerTestHarness.isReplaying]
  /// reads `true` for the duration of the handler call so a replay-aware handler
  /// can skip its side effect while still returning the recorded value.
  ///
  /// Throws [ArgumentError] (enumerating the registered names) when [name] has
  /// no handler — a typo'd name is a test-authoring mistake, not a runtime
  /// failure.
  ///
  /// **Single-invoke contract.** Run one [invoke] to completion (`await` it)
  /// before starting the next on the same harness. The replay flag behind
  /// [isReplaying] is shared instance state reset unconditionally when the
  /// handler returns, so overlapping invokes (e.g. `Future.wait`) or a handler
  /// that re-enters [invoke] would observe a clobbered flag. A harness is
  /// per-test; sequential awaited invokes are the supported usage.
  Future<ToolCallResultEvent> invoke(
    String name,
    Map<String, dynamic> args, {
    bool isReplaying = false,
  }) async {
    final handler = _handlers[name];
    if (handler == null) {
      throw ArgumentError.value(
        name,
        'name',
        'No handler registered for "$name". '
            'Registered: ${(_handlers.keys.toList()..sort()).join(', ')}',
      );
    }

    final n = _callSeq++;
    final toolCallId = 'harness-call-$n';
    final messageId = 'harness-result-$n';
    final threadId = 'harness-thread-$n';
    final runId = 'harness-run-$n';

    _isReplaying = isReplaying;
    final Object? raw;
    try {
      raw = await handler(args);
    } finally {
      _isReplaying = false;
    }
    final content = jsonEncode({'value': raw});

    final timeline = <AgUiEvent>[
      RunStartedEvent(threadId: threadId, runId: runId),
      ToolCallStartEvent(toolCallId: toolCallId, toolCallName: name),
      ToolCallArgsEvent(toolCallId: toolCallId, delta: jsonEncode(args)),
      ToolCallEndEvent(toolCallId: toolCallId),
      ToolCallResultEvent(
        messageId: messageId,
        toolCallId: toolCallId,
        content: content,
      ),
      RunFinishedEvent(threadId: threadId, runId: runId),
    ];

    final client = KoelClient(
      agent: MockAgent.fromEvents(timeline),
      subscribers: [..._observers],
    );
    try {
      final events = await client
          .runRaw(RunAgentInput(threadId: threadId, runId: runId))
          .toList();
      return events.whereType<ToolCallResultEvent>().single;
    } finally {
      client.dispose();
    }
  }
}
