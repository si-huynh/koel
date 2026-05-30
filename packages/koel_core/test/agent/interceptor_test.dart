import 'dart:async';

import 'package:koel_core/src/agent/abstract_agent.dart';
import 'package:koel_core/src/agent/interceptor.dart';
import 'package:koel_core/src/error/error_classifier.dart';
import 'package:koel_core/src/error/koel_error.dart';
import 'package:koel_core/src/error/koel_error_code.dart';
import 'package:koel_core/src/event/ag_ui_event.dart';
import 'package:koel_core/src/input/run_agent_input.dart';
import 'package:test/test.dart';

// MockAgent (Story 3.1) does not exist yet, so the terminal agent is a private
// inline double that emits a fixed event sequence and optionally throws.
class _FixtureAgent implements AbstractAgent {
  _FixtureAgent(this._events, {this.onRun, this.throwAfterEmit});

  final List<AgUiEvent> _events;
  final void Function()? onRun;
  final Object? throwAfterEmit;

  @override
  Stream<AgUiEvent> run(RunAgentInput input) async* {
    onRun?.call();
    for (final event in _events) {
      yield event;
    }
    final toThrow = throwAfterEmit;
    if (toThrow != null) {
      throw toThrow;
    }
  }
}

/// Logs `enter` before delegating and `exit` once the delegated stream drains —
/// proving forward order and reverse unwind.
class _RecordingInterceptor implements Interceptor {
  _RecordingInterceptor(this.label, this.log);

  final String label;
  final List<String> log;

  @override
  Stream<AgUiEvent> intercept(
    InterceptorChain chain,
    RunAgentInput input,
  ) async* {
    log.add('$label enter');
    yield* chain.proceed(input);
    log.add('$label exit');
  }
}

/// Throws synchronously while building its stream — before any delegation.
class _ThrowingInterceptor implements Interceptor {
  _ThrowingInterceptor(this.error);

  final Object error;

  @override
  Stream<AgUiEvent> intercept(InterceptorChain chain, RunAgentInput input) {
    throw error;
  }
}

/// Maps the delegated stream — its transformation must reach the final events.
class _TransformingInterceptor implements Interceptor {
  _TransformingInterceptor(this.transform);

  final AgUiEvent Function(AgUiEvent) transform;

  @override
  Stream<AgUiEvent> intercept(InterceptorChain chain, RunAgentInput input) =>
      chain.proceed(input).map(transform);
}

/// A classifier that ignores the raw failure and stamps a fixed sentinel —
/// proves the injected classifier (not the default) is the one consulted.
class _SentinelClassifier implements ErrorClassifier {
  const _SentinelClassifier();

  @override
  KoelError classify(Object raw, StackTrace? stack, RunAgentInput input) =>
      const AgentError(message: 'sentinel', code: KoelErrorCode.agentRefused);
}

const _input = RunAgentInput(threadId: 't1', runId: 'r1');
const _started = RunStartedEvent(threadId: 't1', runId: 'r1');
const _finished = RunFinishedEvent(threadId: 't1', runId: 'r1');

void main() {
  group('InterceptorChain', () {
    test(
      'runs interceptors forward and unwinds in reverse around the agent',
      () async {
        final log = <String>[];
        final agent = _FixtureAgent(const [
          _started,
          _finished,
        ], onRun: () => log.add('agent run'));
        final chain = InterceptorChain(
          interceptors: [
            _RecordingInterceptor('A', log),
            _RecordingInterceptor('B', log),
            _RecordingInterceptor('C', log),
          ],
          agent: agent,
        );

        final events = await chain.proceed(_input).toList();

        expect(events, const [_started, _finished]);
        expect(log, const [
          'A enter',
          'B enter',
          'C enter',
          'agent run',
          'C exit',
          'B exit',
          'A exit',
        ]);
      },
    );

    test(
      'passes agent events through unchanged with no interceptors',
      () async {
        final chain = InterceptorChain(
          interceptors: const [],
          agent: _FixtureAgent(const [_started, _finished]),
        );

        expect(await chain.proceed(_input).toList(), const [
          _started,
          _finished,
        ]);
      },
    );

    test(
      'a synchronous throw from intercept short-circuits to a classified RunErrorEvent',
      () async {
        var agentRan = false;
        final chain = InterceptorChain(
          interceptors: [_ThrowingInterceptor(StateError('boom'))],
          agent: _FixtureAgent(const [_started], onRun: () => agentRan = true),
        );

        final events = await chain.proceed(_input).toList();

        expect(events, hasLength(1));
        final error = (events.single as RunErrorEvent).error;
        expect(error, isA<AgentError>());
        expect(error.code, KoelErrorCode.unknown);
        expect(
          agentRan,
          isFalse,
          reason: 'chain short-circuits before reaching the agent',
        );
      },
    );

    test(
      'an error surfaced mid-stream emits prior events then a RunErrorEvent',
      () async {
        final chain = InterceptorChain(
          interceptors: [_RecordingInterceptor('A', <String>[])],
          agent: _FixtureAgent(const [
            _started,
          ], throwAfterEmit: TimeoutException('slow')),
        );

        final events = await chain.proceed(_input).toList();

        expect(events, hasLength(2));
        expect(events.first, _started);
        final error = (events.last as RunErrorEvent).error;
        expect(error, isA<TransportError>());
        expect(error.code, KoelErrorCode.transportTimeout);
      },
    );

    test(
      'a thrown KoelError passes through the classifier unchanged (idempotent)',
      () async {
        const original = AgentError(
          message: 'tool failed',
          code: KoelErrorCode.agentToolFailed,
        );
        final chain = InterceptorChain(
          interceptors: const [],
          agent: _FixtureAgent(const [], throwAfterEmit: original),
        );

        final events = await chain.proceed(_input).toList();

        final error = (events.single as RunErrorEvent).error;
        expect(identical(error, original), isTrue);
        expect(error.code, KoelErrorCode.agentToolFailed);
      },
    );

    test(
      'a transforming interceptor changes the final emitted events',
      () async {
        final chain = InterceptorChain(
          interceptors: [
            _TransformingInterceptor(
              (_) =>
                  const RunStartedEvent(threadId: 't1', runId: 'transformed'),
            ),
          ],
          agent: _FixtureAgent(const [_started, _finished]),
        );

        final events = await chain.proceed(_input).toList();

        expect(events, hasLength(2));
        expect(
          events.every((e) => e is RunStartedEvent && e.runId == 'transformed'),
          isTrue,
        );
      },
    );

    test('uses the injected error classifier instead of the default', () async {
      final chain = InterceptorChain(
        interceptors: const [],
        agent: _FixtureAgent(const [], throwAfterEmit: StateError('x')),
        errorClassifier: const _SentinelClassifier(),
      );

      final events = await chain.proceed(_input).toList();

      final error = (events.single as RunErrorEvent).error;
      expect(error.code, KoelErrorCode.agentRefused);
    });

    test(
      'cancelling the subscription cancels the run without a RunErrorEvent',
      () async {
        var cancelled = false;
        final controller = StreamController<AgUiEvent>(
          onCancel: () => cancelled = true,
        );
        addTearDown(controller.close);
        final emitted = <AgUiEvent>[];
        final chain = InterceptorChain(
          interceptors: const [],
          agent: _StreamAgent(controller.stream),
        );

        final sub = chain.proceed(_input).listen(emitted.add);
        controller.add(_started);
        await Future<void>.delayed(Duration.zero);
        await sub.cancel();

        expect(
          cancelled,
          isTrue,
          reason: 'cancel propagates to the terminal stream',
        );
        expect(emitted, const [_started]);
        expect(emitted.whereType<RunErrorEvent>(), isEmpty);
      },
    );

    test(
      'an error from a never-closing source terminates with one RunErrorEvent',
      () async {
        // The existing mid-stream test uses an async* agent that closes after
        // throwing. This drives a source that surfaces an error and stays open
        // (then emits more), pinning that handleError's `add..close` is what
        // terminates the run — and that the still-open source is cancelled.
        var cancelled = false;
        final controller = StreamController<AgUiEvent>(
          onCancel: () => cancelled = true,
        );
        addTearDown(controller.close);
        final chain = InterceptorChain(
          interceptors: const [],
          agent: _StreamAgent(controller.stream),
        );

        final future = chain.proceed(_input).toList();
        controller
          ..add(_started)
          ..addError(TimeoutException('slow'))
          ..add(_finished); // after the error — must be dropped, never closed
        final events = await future;

        expect(events, hasLength(2));
        expect(events.first, _started);
        final error = (events.last as RunErrorEvent).error;
        expect(error, isA<TransportError>());
        expect(error.code, KoelErrorCode.transportTimeout);
        expect(
          cancelled,
          isTrue,
          reason: 'handleError closes the sink, cancelling the open source',
        );
      },
    );
  });
}

/// Agent backed by an externally-driven stream, for the cancellation test.
class _StreamAgent implements AbstractAgent {
  _StreamAgent(this._stream);

  final Stream<AgUiEvent> _stream;

  @override
  Stream<AgUiEvent> run(RunAgentInput input) => _stream;
}
