@TestOn('vm')
@Tags(['conformance'])
library;

import 'package:koel_agno/koel_agno.dart';
import 'package:koel_core/koel_core.dart';
import 'package:koel_test/koel_test.dart';
import 'package:test/test.dart';

import '_support.dart';

/// The minimal run input; the `MockClient` ignores it and replays a canned SSE.
RunAgentInput _input() => const RunAgentInput(threadId: 't', runId: 'r');

void main() {
  group('AgnoAgent conformance (FR-G4)', () {
    // One entry per AG-UI type in all_event_types.jsonl (RUN_STARTED … CUSTOM).
    const typeCount = 28;

    // The 3 `*_CHUNK` convenience shapes are NOT reproduced verbatim by ANY
    // HTTP adapter: koel_http's default-on `synthesizeChunks` (Story 4.8,
    // http_agent.dart:65-75) normalizes them into their START/CONTENT/END
    // triplets *at the transport*, so the Epic-5 backends always see long form.
    // `AgnoAgent` does not expose `synthesizeChunks` (Addendum A.3), so 25/28 is
    // its fixed contract — the prep-plan's documented "25/28, 3 chunk-variants
    // synthesizable koel-side". A real agno backend never emits chunk shapes
    // anyway (canonical `EventEncoder`, CONTRACT.md), so this is the true
    // backend-conformance surface, not a gap.
    const synthesizedChunkTypes = {
      'TEXT_MESSAGE_CHUNK',
      'TOOL_CALL_CHUNK',
      'REASONING_MESSAGE_CHUNK',
    };

    test('ConformanceRunner reproduces the 25 canonical AG-UI types verbatim '
        'through the inherited HttpAgent SSE parse; the 3 *_CHUNK shapes are '
        'transport-synthesized into long form (AC5)', () async {
      // The corpus carries both RUN_ERROR and RUN_FINISHED; HttpAgent yields a
      // wire RUN_ERROR verbatim (its "terminal RunErrorEvent" classifies only
      // transport/parser *throws*, not a parsed event), so every non-chunk
      // type reaches the runner. AgnoAgent overrides only encodeBody/
      // errorClassifier — the response path is unreshaped HttpAgent behaviour.
      final client = sseClient(
        sseBody(await fixturePayloads('synthesized', 'all_event_types')),
      );

      final report = await const ConformanceRunner().runAgainst(
        AgnoAgent(baseURL: Uri.parse('http://host:8002'), client: client),
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
      expect(report.agentName, contains('AgnoAgent'));
    });

    test(
      'AgnoAgent replays the REAL captured agno text_only_run fixture verbatim '
      '(AC5 + FR-G1) — proves the inherited parse on real agno wire',
      () async {
        // The fixture is a committed live capture (`make up-agno` →
        // `dart run tool/capture_fixtures.dart --backend=agno`); replaying it
        // through AgnoAgent's inherited SSE parse must reproduce the loader's
        // typed events exactly. `fixtures_test.dart` hard-asserts the fixture's
        // presence, so this test depends on it unconditionally (no skip).
        final client = sseClient(
          sseBody(await fixturePayloads('agno', 'text_only_run')),
        );

        final events = await AgnoAgent(
          baseURL: Uri.parse('http://host:8002'),
          client: client,
        ).run(_input()).toList();

        expect(events, await FixtureLoader.loadAgno('text_only_run'));
      },
    );
  });
}
