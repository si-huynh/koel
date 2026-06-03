@TestOn('vm')
@Tags(['conformance'])
library;

import 'package:koel_core/koel_core.dart';
import 'package:koel_langgraph/koel_langgraph.dart';
import 'package:koel_test/koel_test.dart';
import 'package:test/test.dart';

import '_support.dart';

/// The minimal run input; the `MockClient` ignores it and replays a canned SSE.
RunAgentInput _input() => const RunAgentInput(threadId: 't', runId: 'r');

void main() {
  group('LangGraphAgent conformance (FR-G4)', () {
    // One entry per AG-UI type in all_event_types.jsonl (RUN_STARTED … CUSTOM).
    const typeCount = 28;

    // The 3 `*_CHUNK` convenience shapes are NOT reproduced verbatim by ANY
    // HTTP adapter: koel_http's default-on `synthesizeChunks` (Story 4.8,
    // http_agent.dart) normalizes them into their START/CONTENT/END triplets
    // *at the transport*, so the Epic-5 backends always see long form.
    // `LangGraphAgent` does not expose `synthesizeChunks` (Addendum A.4), so
    // 25/28 is its fixed contract — identical to `AgnoAgent`. A real LangGraph
    // backend never emits chunk shapes anyway (canonical `EventEncoder`,
    // CONTRACT.md), so this is the true backend-conformance surface, not a gap.
    const synthesizedChunkTypes = {
      'TEXT_MESSAGE_CHUNK',
      'TOOL_CALL_CHUNK',
      'REASONING_MESSAGE_CHUNK',
    };

    test('ConformanceRunner reproduces the 25 canonical AG-UI types verbatim '
        'through the inherited HttpAgent SSE parse; the 3 *_CHUNK shapes are '
        'transport-synthesized into long form (AC3)', () async {
      // The corpus carries both RUN_ERROR and RUN_FINISHED; HttpAgent yields a
      // wire RUN_ERROR verbatim (its "terminal RunErrorEvent" classifies only
      // transport/parser *throws*, not a parsed event), so every non-chunk
      // type reaches the runner. LangGraphAgent overrides only encodeBody/
      // errorClassifier — the response path is unreshaped HttpAgent behaviour.
      final client = sseClient(
        sseBody(await fixturePayloads('synthesized', 'all_event_types')),
      );

      final report = await const ConformanceRunner().runAgainst(
        LangGraphAgent(
          deploymentUrl: Uri.parse('http://host:8003/agent'),
          client: client,
        ),
      );

      // The 25 canonical types reproduce verbatim — zero failures among them.
      expect(
        report.passed,
        hasLength(typeCount - synthesizedChunkTypes.length),
      );
      expect(
        report.passed.toSet().intersection(synthesizedChunkTypes),
        isEmpty,
      );
      // The ONLY unmatched types are exactly the 3 synthesized chunk shapes —
      // proves they were normalized, not silently dropped, and that no 26th
      // type regressed.
      expect(
        report.failed.map((f) => f.eventType).toSet(),
        synthesizedChunkTypes,
      );
      expect(report.agentName, contains('LangGraphAgent'));
    });

    test(
      'LangGraphAgent replays the REAL captured langgraph text_only_run fixture '
      'verbatim (AC3 + FR-G1) — proves the inherited parse on real LangGraph '
      'wire',
      () async {
        // The fixture is a committed live capture (`make up-langgraph` →
        // `dart run tool/capture_fixtures.dart --backend=langgraph`); replaying
        // it through LangGraphAgent's inherited SSE parse must reproduce the
        // loader's typed events exactly. `fixtures_test.dart` hard-asserts the
        // fixture's presence, so this test depends on it unconditionally.
        final client = sseClient(
          sseBody(await fixturePayloads('langgraph', 'text_only_run')),
        );

        final events = await LangGraphAgent(
          deploymentUrl: Uri.parse('http://host:8003/agent'),
          client: client,
        ).run(_input()).toList();

        expect(events, await FixtureLoader.loadLangGraph('text_only_run'));
      },
    );
  });
}
