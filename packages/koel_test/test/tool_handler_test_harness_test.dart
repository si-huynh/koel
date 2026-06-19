import 'dart:convert';

import 'package:koel_core/koel_core.dart';
import 'package:koel_test/koel_test.dart';
import 'package:test/test.dart';

/// A recording [AgentSubscriber] for the observability assertion — captures the
/// tool-call start and result events it sees through real dispatch.
final class _RecordingSubscriber extends AgentSubscriber {
  final List<ToolCallStartEvent> starts = [];
  final List<ToolCallResultEvent> results = [];

  @override
  void onToolCall(ToolCallStartEvent start, ToolCallEndEvent? end) =>
      starts.add(start);

  @override
  void onToolResult(ToolCallResultEvent e) => results.add(e);
}

void main() {
  group('ToolHandlerTestHarness', () {
    test('register → invoke runs the handler and returns a result event whose '
        'decoded content carries the value (AC1/AC2)', () async {
      final result = await ToolHandlerTestHarness()
          .register('addTwo', (args) => args['a'] + args['b'])
          .invoke('addTwo', {'a': 2, 'b': 3});

      expect(result, isA<ToolCallResultEvent>());
      expect((jsonDecode(result.content) as Map<String, dynamic>)['value'], 5);
      // Harness-generated ids thread through the post-pipeline event.
      expect(result.toolCallId, isNotEmpty);
      expect(result.toolCallId, startsWith('harness-call-'));
      expect(result.messageId, startsWith('harness-result-'));
    });

    test('the invocation is observable via an attached AgentSubscriber through '
        'real KoelClient dispatch (AC2)', () async {
      final subscriber = _RecordingSubscriber();
      final result = await ToolHandlerTestHarness()
          .register('addTwo', (args) => args['a'] + args['b'])
          .observe(subscriber)
          .invoke('addTwo', {'a': 2, 'b': 3});

      expect(subscriber.starts, hasLength(1));
      expect(subscriber.starts.single.toolCallName, 'addTwo');
      expect(subscriber.results, hasLength(1));
      // The observed result is the same event the caller received.
      expect(subscriber.results.single.toolCallId, result.toolCallId);
    });

    test('under replay the side effect is skipped while the recorded result '
        'still emits (AC3)', () async {
      var sideEffects = 0;
      late final ToolHandlerTestHarness harness;
      harness = ToolHandlerTestHarness()
        ..register('sendEmail', (args) {
          if (!harness.isReplaying) sideEffects++;
          return {'sent': true};
        });

      final result = await harness.invoke('sendEmail', {
        'to': 'x',
      }, isReplaying: true);

      expect(sideEffects, 0);
      expect((jsonDecode(result.content) as Map<String, dynamic>)['value'], {
        'sent': true,
      });
    });

    test('without replay the same handler runs its side effect — proving the '
        'gate is real (AC3 mirror)', () async {
      var sideEffects = 0;
      late final ToolHandlerTestHarness harness;
      harness = ToolHandlerTestHarness()
        ..register('sendEmail', (args) {
          if (!harness.isReplaying) sideEffects++;
          return {'sent': true};
        });

      await harness.invoke('sendEmail', {'to': 'x'});

      expect(sideEffects, 1);
      // The flag is reset after the handler returns.
      expect(harness.isReplaying, isFalse);
    });

    test(
      'an async handler is awaited and its return encoded (FutureOr)',
      () async {
        final result = await ToolHandlerTestHarness()
            .register('seven', (args) async => 7)
            .invoke('seven', const {});

        expect(
          (jsonDecode(result.content) as Map<String, dynamic>)['value'],
          7,
        );
      },
    );

    test('an unknown tool name throws ArgumentError enumerating the registered '
        'names', () {
      final harness = ToolHandlerTestHarness().register('addTwo', (args) => 0);

      expect(
        harness.invoke('nope', const {}),
        throwsA(
          isA<ArgumentError>().having(
            (e) => e.message,
            'message',
            contains('addTwo'),
          ),
        ),
      );
    });
  });
}
