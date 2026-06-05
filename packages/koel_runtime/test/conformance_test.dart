@TestOn('vm')
@Tags(['conformance'])
library;

import 'package:koel_runtime/koel_runtime.dart';
import 'package:koel_test/koel_test.dart';
import 'package:test/test.dart';

import '_support.dart';

void main() {
  group('CopilotRuntimeAgent conformance (FR-G4) — full matrix, no 7/28', () {
    // One entry per AG-UI type in all_event_types.jsonl (RUN_STARTED … CUSTOM).
    const typeCount = 28;

    // The 3 `*_CHUNK` convenience shapes are NOT reproduced verbatim by ANY
    // HTTP adapter: koel_http's default-on `synthesizeChunks` (Story 4.8)
    // normalizes them into their START/CONTENT/END triplets *at the transport*,
    // so the Epic-5 backends always see long form. `CopilotRuntimeAgent` (like
    // `AgnoAgent`) does not expose `synthesizeChunks`, so 25/28 is its fixed
    // contract — the SAME full canonical surface agno/langgraph prove, versus the
    // legacy GraphQL bridge's lossy 7/28 (the headline of SCP-2026-06-05). The
    // 25 reproduced types include exactly the ones the GraphQL bridge dropped:
    // STATE_DELTA, RUN_ERROR, STEP_STARTED/FINISHED, CUSTOM, MESSAGES_SNAPSHOT,
    // REASONING_*.
    const synthesizedChunkTypes = {
      'TEXT_MESSAGE_CHUNK',
      'TOOL_CALL_CHUNK',
      'REASONING_MESSAGE_CHUNK',
    };

    test('ConformanceRunner reproduces the 25 canonical AG-UI types verbatim '
        'through the inherited HttpAgent SSE parse; the 3 *_CHUNK shapes are '
        'transport-synthesized into long form (AC3)', () async {
      // The synthesized corpus replayed as SSE — the full-matrix proof needs no
      // live backend: CopilotRuntimeAgent is a transparent HttpAgent passthrough.
      // RUN_ERROR rides the wire verbatim (the agent's "terminal RunErrorEvent"
      // classifies only transport/parser *throws*, not a parsed event), so every
      // non-chunk type reaches the runner. (Real captured v2 fixtures + the
      // conformance.yml lane swap are Story 5.11.)
      final client = sseClient(
        sseBody(await fixturePayloads('synthesized', 'all_event_types')),
      );

      final report = await const ConformanceRunner().runAgainst(
        CopilotRuntimeAgent(
          endpoint: Uri.parse('http://host:8005/api/copilotkit'),
          agentName: 'koel_scripted',
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
      // proves they were normalized, not silently dropped, and no 26th regressed.
      expect(
        report.failed.map((f) => f.eventType).toSet(),
        synthesizedChunkTypes,
      );
      expect(report.agentName, contains('CopilotRuntimeAgent'));
    });
  });
}
