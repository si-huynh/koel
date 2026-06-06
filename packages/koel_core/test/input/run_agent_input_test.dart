import 'dart:typed_data';

import 'package:koel_core/src/context/context.dart';
import 'package:koel_core/src/input/run_agent_input.dart';
import 'package:koel_core/src/message/message.dart';
import 'package:koel_core/src/tool/tool_definition.dart';
import 'package:test/test.dart';

void main() {
  group('RunAgentInput', () {
    test(
      'const construction with required ids and defaulted empty collections',
      () {
        const input = RunAgentInput(threadId: 't1', runId: 'r1');
        expect(input.threadId, 't1');
        expect(input.runId, 'r1');
        expect(input.state, isEmpty);
        expect(input.messages, isEmpty);
        expect(input.tools, isEmpty);
        expect(input.context, isEmpty);
        expect(input.forwardedProps, isEmpty);
        expect(input.reasoningEcho, isNull);
      },
    );

    test(
      'deep equality across state/messages/tools/context/forwardedProps',
      () {
        RunAgentInput build() => RunAgentInput(
          threadId: 't1',
          runId: 'r1',
          state: const {'k': 1},
          messages: [
            Message(
              id: 'm1',
              role: MessageRole.user,
              content: 'hi',
              timestamp: DateTime.utc(2026, 5, 29),
            ),
          ],
          tools: const [ToolDefinition(name: 'lookup', description: 'd')],
          context: const [Context(description: 'page', value: 'home')],
          forwardedProps: const {'f': 'v'},
        );
        expect(build(), equals(build()));
        expect(build().hashCode, equals(build().hashCode));
        expect(build(), isNot(equals(build().copyWith(state: const {'k': 2}))));
      },
    );

    test(
      'byte-deep equality on reasoningEcho (distinct Uint8List, same bytes)',
      () {
        final a = RunAgentInput(
          threadId: 't1',
          runId: 'r1',
          reasoningEcho: {
            'k': Uint8List.fromList([1, 2, 3]),
          },
        );
        final b = RunAgentInput(
          threadId: 't1',
          runId: 'r1',
          reasoningEcho: {
            'k': Uint8List.fromList([1, 2, 3]),
          },
        );
        expect(
          identical(a.reasoningEcho!['k'], b.reasoningEcho!['k']),
          isFalse,
        );
        expect(a, equals(b));
        expect(a.hashCode, equals(b.hashCode));

        final c = RunAgentInput(
          threadId: 't1',
          runId: 'r1',
          reasoningEcho: {
            'k': Uint8List.fromList([1, 2, 4]),
          },
        );
        expect(a, isNot(equals(c)));
      },
    );

    test('copyWith updates one field and leaves others identical', () {
      const input = RunAgentInput(threadId: 't1', runId: 'r1');
      final updated = input.copyWith(runId: 'r2');
      expect(updated.runId, 'r2');
      expect(updated.threadId, input.threadId);
      expect(updated.state, input.state);
    });
  });
}
