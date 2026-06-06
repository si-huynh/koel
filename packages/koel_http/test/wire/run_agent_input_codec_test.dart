import 'package:koel_core/koel_core.dart';
import 'package:koel_http/src/wire/run_agent_input_codec.dart';
import 'package:test/test.dart';

void main() {
  group('encodeRunAgentInput context', () {
    test('empty context encodes as an empty List, never a Map (422 guard)', () {
      // Regression: AG-UI types `context` as `List<Context>`. A spec-compliant
      // backend 422-rejects `"context": {}`; the empty default must serialize
      // to `[]`. See SCP-2026-06-06.
      const input = RunAgentInput(threadId: 't', runId: 'r');
      final body = encodeRunAgentInput(input);
      expect(body['context'], isA<List<dynamic>>());
      expect(body['context'], isEmpty);
    });

    test(
      'populated context encodes as a list of {description, value} maps',
      () {
        const input = RunAgentInput(
          threadId: 't',
          runId: 'r',
          context: [Context(description: 'page', value: 'home')],
        );
        final body = encodeRunAgentInput(input);
        expect(body['context'], [
          {'description': 'page', 'value': 'home'},
        ]);
      },
    );
  });
}
