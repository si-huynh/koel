@TestOn('vm')
@Tags(['conformance'])
library;

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:koel_core/koel_core.dart';
import 'package:koel_runtime/koel_runtime.dart';
import 'package:koel_runtime/src/conversion/graphql_event_conversion.dart';
import 'package:koel_test/koel_test.dart';
import 'package:test/test.dart';

import '_support.dart';

/// The full GraphQL endpoint a configured agent POSTs to (used verbatim).
final _endpoint = Uri.parse('http://localhost:8004/api/copilotkit');

/// The registered runtime agent the conformance drive dispatches to.
const _agentName = 'koel_scripted';

/// A `MockClient` replaying [events] as the multipart-GraphQL response a
/// successful run receives — authored via the 5.7 reverse path
/// ([eventsToGraphQLParts]) so the wire is an independent oracle, not the agent's
/// own output.
http.Client _replay(List<AgUiEvent> events) => MockClient(
  (request) async => http.Response.bytes(
    multipartBytes(eventsToGraphQLParts(events)),
    200,
    headers: {'content-type': 'multipart/mixed; boundary="-"'},
  ),
);

void main() {
  group('CopilotRuntimeAgent conformance (FR-G4)', () {
    // The exactly-7 GraphQL-representable AG-UI types. `CopilotRuntimeAgent` is a
    // LOSSY GraphQL bridge, not a native-AG-UI passthrough like AgnoAgent/
    // LangGraphAgent (25/28): `graphql_event_conversion.dart` frames ONLY the
    // four GraphQL message-output shapes the runtime emits, so only these 7 of
    // the corpus's 28 types can ride the multipart wire. The other 19 have no
    // GraphQL representation (eventsToGraphQLParts ArgumentErrors on them) — the
    // dojo captures + synthesized corpus carry the full 25/28 matrix instead.
    const representable = <String>{
      'TEXT_MESSAGE_START',
      'TEXT_MESSAGE_CONTENT',
      'TEXT_MESSAGE_END',
      'TOOL_CALL_START',
      'TOOL_CALL_ARGS',
      'TOOL_CALL_END',
      'STATE_SNAPSHOT',
    };

    // The remaining 21 of the 28 corpus types. The 19 non-representable types are
    // never served → `actual: null` failures; RUN_STARTED/RUN_FINISHED ARE
    // emitted (the agent's envelope, 5.8 AC3) but with the runner's
    // `conformance-thread`/`conformance-run` ids, which freezed-`==`-diverge from
    // the corpus's `t`/`r` → divergent failures. Named exactly (RESOLVED #5),
    // the copilotkit analog of agno's "25/28, the 3 *_CHUNK named exactly".
    const nonRepresentable = <String>{
      'RUN_STARTED',
      'RUN_FINISHED',
      'RUN_ERROR',
      'STEP_STARTED',
      'STEP_FINISHED',
      'TEXT_MESSAGE_CHUNK',
      'TOOL_CALL_RESULT',
      'TOOL_CALL_CHUNK',
      'STATE_DELTA',
      'MESSAGES_SNAPSHOT',
      'ACTIVITY_SNAPSHOT',
      'ACTIVITY_DELTA',
      'REASONING_START',
      'REASONING_END',
      'REASONING_MESSAGE_START',
      'REASONING_MESSAGE_CONTENT',
      'REASONING_MESSAGE_END',
      'REASONING_MESSAGE_CHUNK',
      'REASONING_ENCRYPTED_VALUE',
      'RAW',
      'CUSTOM',
    };

    /// Filters [corpus] to the events whose AG-UI type is GraphQL-representable —
    /// the subset `eventsToGraphQLParts` can frame (it ArgumentErrors on the
    /// rest). Order-preserving, so each START precedes its CONTENT/END.
    List<AgUiEvent> representableSubset(List<AgUiEvent> corpus) => corpus
        .where(
          (e) =>
              e is TextMessageStartEvent ||
              e is TextMessageContentEvent ||
              e is TextMessageEndEvent ||
              e is ToolCallStartEvent ||
              e is ToolCallArgsEvent ||
              e is ToolCallEndEvent ||
              e is StateSnapshotEvent,
        )
        .toList();

    test('reports the exact 7/28 representable partition — the 7 message types '
        'pass, the other 21 fail (RESOLVED #5)', () async {
      final corpus = await FixtureLoader.loadSynthesized('all_event_types');
      final client = _replay(representableSubset(corpus));

      final report = await const ConformanceRunner().runAgainst(
        CopilotRuntimeAgent(
          graphqlEndpoint: _endpoint,
          agentName: _agentName,
          client: client,
        ),
      );

      // The 7 GraphQL-representable types reproduce verbatim through the
      // reverse→forward round-trip.
      expect(report.passed.toSet(), representable);
      // The other 21 fail — the 19 unserved (actual: null) + the two divergent
      // lifecycle events.
      expect(report.failed.map((f) => f.eventType).toSet(), nonRepresentable);
      expect(report.agentName, contains('CopilotRuntimeAgent'));
    });

    test('Test B — replays the REAL captured copilotkit_runtime text_only_run '
        'through CopilotRuntimeAgent (AC4 + FR-G1)', () async {
      // The fixture is a committed live capture (`make up-copilotkit` →
      // `dart run tool/capture_fixtures.dart --backend=copilotkit_runtime`);
      // `fixtures_test.dart` hard-asserts its presence, so this loads and
      // asserts unconditionally (the transient capture-presence guard is gone).
      final fixture = await FixtureLoader.loadCopilotkitRuntime(
        'text_only_run',
      );

      // The fixture is the agent's full run incl. its RUN_STARTED/RUN_FINISHED
      // envelope; only the parser-derived middle is GraphQL-representable, so
      // strip the lifecycle pair before re-framing (eventsToGraphQLParts
      // ArgumentErrors on them) — the agent re-synthesizes them from the input.
      final inner = fixture
          .where((e) => e is! RunStartedEvent && e is! RunFinishedEvent)
          .toList();
      final client = _replay(inner);

      final events = await CopilotRuntimeAgent(
        graphqlEndpoint: _endpoint,
        agentName: _agentName,
        client: client,
      ).run(const RunAgentInput(threadId: 't', runId: 'r')).toList();

      expect(events, fixture);
    });
  });
}
