import 'package:koel_core/src/agent/abstract_agent.dart';
import 'package:koel_core/src/event/ag_ui_event.dart';
import 'package:koel_core/src/input/run_agent_input.dart';
import 'package:test/test.dart';

/// Proves the SPI is implementable: a test double `implements AbstractAgent`
/// and returns a well-typed `Stream<AgUiEvent>` whose subscription completes.
class _FakeAgent implements AbstractAgent {
  @override
  Stream<AgUiEvent> run(RunAgentInput input) => const Stream<AgUiEvent>.empty();
}

void main() {
  group('AbstractAgent', () {
    test(
      'an implementer satisfies the contract and the stream completes',
      () async {
        final AbstractAgent agent = _FakeAgent();
        final stream = agent.run(
          const RunAgentInput(threadId: 't1', runId: 'r1'),
        );
        expect(stream, isA<Stream<AgUiEvent>>());
        expect(await stream.toList(), isEmpty);
      },
    );
  });
}
