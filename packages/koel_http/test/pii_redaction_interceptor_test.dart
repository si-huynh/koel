import 'dart:async';

import 'package:koel_core/koel_core.dart';
import 'package:koel_http/koel_http.dart';
import 'package:test/test.dart';

/// A minimal run payload — these tests assert on redacted content, not body.
RunAgentInput _input() => const RunAgentInput(threadId: 't', runId: 'r');

/// A terminal agent emitting a fixed list of events per run — feeds the chain
/// without a server.
class _StubAgent implements AbstractAgent {
  _StubAgent(this._events);
  final List<AgUiEvent> _events;

  @override
  Stream<AgUiEvent> run(RunAgentInput input) =>
      Stream<AgUiEvent>.fromIterable(_events);
}

/// Runs [events] through a chain wrapping [interceptor] (or none) and collects
/// the consumer-visible output.
Future<List<AgUiEvent>> _run(
  List<AgUiEvent> events, {
  Interceptor? interceptor,
}) {
  final chain = InterceptorChain(
    interceptors: interceptor == null ? const [] : [interceptor],
    agent: _StubAgent(events),
  );
  return chain.proceed(_input()).toList();
}

void main() {
  group('PIIRedactionInterceptor', () {
    test('is an Interceptor; rejects an empty pattern list (AC2 surface)', () {
      expect(
        PIIRedactionInterceptor(patterns: [RegExp('x')]),
        isA<Interceptor>(),
      );
      // An empty list is a fail-open redactor — rejected via ArgumentError (not
      // an assert) so the guard survives release/AOT builds.
      expect(
        () => PIIRedactionInterceptor(patterns: const []),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('redacts a card number in TextMessageContentEvent.delta, leaves the '
        'messageId untouched (AC4)', () async {
      final out = await _run(
        const [
          TextMessageContentEvent(
            messageId: 'm1',
            delta: 'my card 4111-1111-1111-1111 please',
          ),
        ],
        interceptor: PIIRedactionInterceptor(
          patterns: [RegExp(r'\b\d{4}-\d{4}-\d{4}-\d{4}\b')],
        ),
      );

      final e = out.single as TextMessageContentEvent;
      expect(e.delta, 'my card [REDACTED] please');
      expect(e.messageId, 'm1', reason: 'structural id must not be scrubbed');
    });

    test('scrubs every text-content field across the event family', () async {
      final pattern = RegExp('secret');
      final out = await _run(const [
        TextMessageContentEvent(messageId: 'm', delta: 'a secret here'),
        ToolCallArgsEvent(toolCallId: 't', delta: '{"q":"secret"}'),
        ToolCallResultEvent(
          messageId: 'm',
          toolCallId: 't',
          content: 'secret result',
        ),
        ReasoningMessageContentEvent(messageId: 'r', delta: 'thinking secret'),
        TextMessageChunkEvent(delta: 'chunk secret'),
        ToolCallChunkEvent(delta: 'args secret'),
        ReasoningMessageChunkEvent(delta: 'reason secret'),
      ], interceptor: PIIRedactionInterceptor(patterns: [pattern]));

      expect((out[0] as TextMessageContentEvent).delta, 'a [REDACTED] here');
      expect((out[1] as ToolCallArgsEvent).delta, '{"q":"[REDACTED]"}');
      expect((out[2] as ToolCallResultEvent).content, '[REDACTED] result');
      expect(
        (out[3] as ReasoningMessageContentEvent).delta,
        'thinking [REDACTED]',
      );
      expect((out[4] as TextMessageChunkEvent).delta, 'chunk [REDACTED]');
      expect((out[5] as ToolCallChunkEvent).delta, 'args [REDACTED]');
      expect((out[6] as ReasoningMessageChunkEvent).delta, 'reason [REDACTED]');
    });

    test('passes structural / non-content events through unchanged', () async {
      const events = [
        RunStartedEvent(threadId: 't', runId: 'r'),
        TextMessageStartEvent(messageId: 'm', role: 'assistant'),
        ToolCallStartEvent(toolCallId: 't', toolCallName: 'lookup_secret'),
        CustomEvent(name: 'koel.connection_resumed', value: {'attempt': 1}),
        TextMessageChunkEvent(messageId: 'm'), // null delta — nothing to scrub
      ];
      final out = await _run(
        events,
        interceptor: PIIRedactionInterceptor(patterns: [RegExp('secret')]),
      );

      // Identity is preserved (no copyWith) for events with no redactable text —
      // including a tool *name* containing the pattern and a null-delta chunk.
      for (var i = 0; i < events.length; i++) {
        expect(out[i], same(events[i]));
      }
    });

    test('applies multiple patterns, RegExp and String alike', () async {
      final out = await _run(
        const [TextMessageContentEvent(messageId: 'm', delta: 'foo 12-34 bar')],
        interceptor: PIIRedactionInterceptor(
          patterns: [RegExp(r'\d{2}-\d{2}'), 'foo'],
        ),
      );
      expect(
        (out.single as TextMessageContentEvent).delta,
        '[REDACTED] [REDACTED] bar',
      );
    });

    // Robustness of the single-pass scrubber against adversarial patterns —
    // surfaced by code review (the naive replaceAll fold corrupted these).
    test('overlapping patterns redact order-independently', () async {
      // 'foo' ⊂ 'foobar': the whole token must be redacted regardless of which
      // pattern is listed first (the old fold leaked 'bar' for one ordering).
      Future<String> deltaFor(List<Pattern> patterns) async {
        final out = await _run(const [
          TextMessageContentEvent(messageId: 'm', delta: 'foobar baz'),
        ], interceptor: PIIRedactionInterceptor(patterns: patterns));
        return (out.single as TextMessageContentEvent).delta;
      }

      expect(await deltaFor(['foo', 'foobar']), '[REDACTED] baz');
      expect(await deltaFor(['foobar', 'foo']), '[REDACTED] baz');
    });

    test('a pattern cannot re-match an inserted [REDACTED] marker', () async {
      // Matching the original text means 'RED' finds nothing in 'card 1234';
      // the old fold produced 'card [[REDACTED]ACTED]'.
      final out = await _run(
        const [TextMessageContentEvent(messageId: 'm', delta: 'card 1234 end')],
        interceptor: PIIRedactionInterceptor(patterns: [RegExp(r'\d+'), 'RED']),
      );
      expect(
        (out.single as TextMessageContentEvent).delta,
        'card [REDACTED] end',
      );
    });

    test(
      'an empty-matching pattern redacts only its non-empty matches',
      () async {
        // `\d*` matches the empty string everywhere; the old fold spliced the
        // marker between every character. Only the real digit run must be scrubbed.
        final out = await _run(const [
          TextMessageContentEvent(messageId: 'm', delta: 'ab12cd'),
        ], interceptor: PIIRedactionInterceptor(patterns: [RegExp(r'\d*')]));
        expect((out.single as TextMessageContentEvent).delta, 'ab[REDACTED]cd');
      },
    );

    test(
      'default-off: no interceptor leaves content byte-identical (AC3)',
      () async {
        const original = TextMessageContentEvent(
          messageId: 'm',
          delta: 'card 4111-1111-1111-1111',
        );
        final out = await _run(const [original]);
        expect(out.single, same(original));
        expect((out.single as TextMessageContentEvent).delta, original.delta);
      },
    );
  });
}
